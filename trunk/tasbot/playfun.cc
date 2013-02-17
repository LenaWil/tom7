/* Tries playing a game (deliberately not customized to any particular
   ROM) using an objective function learned by learnfun. 

   This is the second iteration. It attempts to fix a problem with the
   first (playfun-nobacktrack) which is that although the objective
   functions all obviously tank when the player dies, the algorithm
   can't see far enough ahead (or something ..?) to avoid taking a
   path with such an awful score. Here we explicitly keep checkpoints
   so that we can backtrack a significant amount if things seem
   hopeless.

   We also keep track of a range of values for the objective functions
   so that we have some sense of their absolute values, not just their
   relative ones.
*/

#include <unistd.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "tasbot.h"

#include "fceu/utils/md5.h"
#include "config.h"
#include "fceu/driver.h"
#include "fceu/drivers/common/args.h"
#include "fceu/state.h"
#include "basis-util.h"
#include "emulator.h"
#include "fceu/fceu.h"
#include "fceu/types.h"
#include "simplefm2.h"
#include "weighted-objectives.h"
#include "motifs.h"
#include "../cc-lib/arcfour.h"
#include "util.h"
#include "../cc-lib/textsvg.h"

#if MARIONET
#include "SDL.h"
#include "SDL_net.h"
#endif

#define GAME "mario"
#define MOVIE "mario-cleantom.fm2"
#define FASTFORWARD 256  // XXX cheats! -- should be 0

// This is the factor that determines how quickly a motif changes
// weight. When a motif is chosen because it yields the best future,
// we check its immediate effect on the state (normalized); if an
// increase, then we divide its weight by alpha. If a decrease, then
// we multiply. Should be a value in (0, 1] but usually around 0.8.
#define ALPHA 0.8

static const double WIDTH = 1024.0;
static const double HEIGHT = 1024.0;

struct Scoredist {
  Scoredist() : startframe(0), chosen_idx() {}
  explicit Scoredist(int startframe) : startframe(startframe),
				       chosen_idx(0) {}
  int startframe;
  vector<double> immediates;
  vector<double> positives;
  vector<double> negatives;
  vector<double> norms;
  int chosen_idx;
};

// XXX needs a style to distinguish imm/pos/neg/norm
static string DrawDots(const string &color, double xf,
		       const vector<double> &values, double maxval, 
		       int chosen_idx) {
  // CHECK(colors.size() == values.size());
  vector<double> sorted = values;
  std::sort(sorted.begin(), sorted.end());
  string out;
  for (int i = 0; i < values.size(); i++) {
    int size = values.size();
    int sorted_idx = 
      lower_bound(sorted.begin(), sorted.end(), values[i]) - sorted.begin();
    double opacity = 1.0;
    if (sorted_idx < 0.1 * size || sorted_idx > 0.9 * size) {
      opacity = 0.2;
    } else if (sorted_idx < 0.2 * size || sorted_idx > 0.8 * size) {
      opacity = 0.4;
    } else if (sorted_idx < 0.3 * size || sorted_idx > 0.7 * size) {
      opacity = 0.8;
    } else if (sorted_idx == size / 2) {
      opacity = 1.0;
    }
    out += StringPrintf("<circle cx=\"%s\" cy=\"%s\" r=\"%d\" "
			"opacity=\"%.1f\" "
			"fill=\"%s\" />",
			Coord(xf * WIDTH).c_str(), 
			Coord(HEIGHT * (1.0 - (values[i] / maxval))).c_str(),
			(i == chosen_idx) ? 10 : 4,
			opacity,
			color.c_str());
    // colors[i].c_str());
  }
  return out += "\n";
}

static void SaveDistributionSVG(const vector<Scoredist> &dists,
				const string &filename) {
  // Add slop for radii.
  string out = TextSVG::Header(WIDTH + 12, HEIGHT + 12);
  
  // immediates, positives, negatives all are in same value space
  double maxval = 0.0;
  for (int i = 0; i < dists.size(); i++) {
    const Scoredist &dist = dists[i];
    maxval =
      VectorMax(VectorMax(VectorMax(maxval, dist.negatives),
			  dist.positives),
		dist.immediates);
  }
  
  int totalframes = dists.back().startframe;
  
  for (int i = 0; i < dists.size(); i++) {
    const Scoredist &dist = dists[i];
    double xf = dist.startframe / (double)totalframes;
    out += DrawDots("#33A", xf, dist.immediates, maxval, dist.chosen_idx);
    out += DrawDots("#090", xf, dist.positives, maxval, dist.chosen_idx);
    out += DrawDots("#A33", xf, dist.negatives, maxval, dist.chosen_idx);
    out += DrawDots("#000", xf, dist.norms, 1.0, dist.chosen_idx);
  }

  // XXX args?
  out += SVGTickmarks(WIDTH, totalframes, 50.0, 20.0, 12.0);

  out += TextSVG::Footer();
  Util::WriteFile(filename, out);
  printf("Wrote distributions to %s.\n", filename.c_str());
}

struct PlayFun {
  PlayFun() : watermark(0), rc("playfun") {
    Emulator::Initialize(GAME ".nes");
    objectives = WeightedObjectives::LoadFromFile(GAME ".objectives");
    CHECK(objectives);
    fprintf(stderr, "Loaded %d objective functions\n", objectives->Size());

    motifs = Motifs::LoadFromFile(GAME ".motifs");
    CHECK(motifs);

    Emulator::ResetCache(100000, 10000);

    motifvec = motifs->AllMotifs();

    // PERF basis?

    solution = SimpleFM2::ReadInputs(MOVIE);

    size_t start = 0;
    bool saw_input = false;
    while (start < solution.size()) {
      Commit(solution[start]);
      watermark++;
      saw_input = saw_input || solution[start] != 0;
      if (start > FASTFORWARD && saw_input) break;
      start++;
    }

    CHECK(start > 0 && "Currently, there needs to be at least "
	  "one observation to score.");

    printf("Skipped %ld frames until first keypress/ffwd.\n", start);
  }

  void Commit(uint8 input) {
    Emulator::CachingStep(input);
    movie.push_back(input);
    // PERF
    vector<uint8> mem;
    Emulator::GetMemory(&mem);
    memories.push_back(mem);
    objectives->Observe(mem);
  }

  
  // Fairly unprincipled attempt.

  // All of these are the same size:

  // PERF. Shouldn't really save every memory, but
  // we're using it for drawing SVG for now...
  // The nth element contains the memory after playing
  // the nth input in the movie. The initial memory
  // is not stored.
  vector< vector<uint8> > memories;
  // Contains the movie we record.
  vector<uint8> movie;

  // Index below which we should not backtrack (because it
  // contains pre-game menu stuff, for example).
  int watermark;


  // XXX should probably have AvoidLosing and TryWinning.
  // This looks for the min over random play in the future,
  // so tries to avoid getting us screwed.
  //
  // Look fairly deep into the future playing randomly. 
  // DESTROYS THE STATE.
  double AvoidBadFutures(const vector<uint8> &base_memory) {
    // XXX should be based on motif size
    // XXX should learn it somehow? this is tuned by hand
    // for mario.
    // was 10, 50
    static const int DEPTHS[] = { 20, 75 };
    // static const int NUM = 2;
    vector<uint8> base_state;
    Emulator::SaveUncompressed(&base_state);

    double total = 1.0;
    for (int i = 0; i < (sizeof (DEPTHS) / sizeof (int)); i++) {
      if (i) Emulator::LoadUncompressed(&base_state);
      for (int d = 0; d < DEPTHS[i]; d++) {
	const vector<uint8> &m = motifs->RandomWeightedMotif();
	for (int x = 0; x < m.size(); x++) {
	  Emulator::CachingStep(m[x]);

	  // PERF inside the loop -- scary!
	  vector<uint8> future_memory;
	  Emulator::GetMemory(&future_memory);
	  // XXX min? max?
	  if (i || d || x) {
	    total = min(total, 
			objectives->Evaluate(base_memory, future_memory));
	  } else {
	    total = objectives->Evaluate(base_memory, future_memory);
	  }

	}
      }

      // total += objectives->Evaluate(base_memory, future_memory);
    }

    // We're allowed to destroy the current state, so don't
    // restore.
    return total;
  }

  // DESTROYS THE STATE
  double SeekGoodFutures(const vector<uint8> &base_memory) {
    // XXX should be based on motif size
    // XXX should learn it somehow? this is tuned by hand
    // for mario.
    // was 10, 50
    static const int DEPTHS[] = { 30, 30, 50 };
    // static const int NUM = 2;
    vector<uint8> base_state;
    Emulator::SaveUncompressed(&base_state);

    double total = 1.0;
    for (int i = 0; i < (sizeof (DEPTHS) / sizeof (int)); i++) {
      if (i) Emulator::LoadUncompressed(&base_state);
      for (int d = 0; d < DEPTHS[i]; d++) {
	const vector<uint8> &m = motifs->RandomWeightedMotif();
	for (int x = 0; x < m.size(); x++) {
	  Emulator::CachingStep(m[x]);

	}
      }

      // PERF inside the loop -- scary!
      vector<uint8> future_memory;
      Emulator::GetMemory(&future_memory);

      if (i) {
	total = max(total, 
		    objectives->Evaluate(base_memory, future_memory));
      } else {
	total = objectives->Evaluate(base_memory, future_memory);
      }

      // total += objectives->Evaluate(base_memory, future_memory);
    }

    // We're allowed to destroy the current state, so don't
    // restore.
    return total;
  }

  struct Future {
    vector<uint8> inputs;
  };

  static const int NFUTURES = 10;
  static const int FUTURELENGTH = 300;

  // DESTROYS THE STATE
  double ScoreByFuture(const Future &future,
		       const vector<uint8> &base_memory,
		       const vector<uint8> &base_state) {
    for (int i = 0; i < future.inputs.size() && i < FUTURELENGTH; i++) {
      Emulator::CachingStep(future.inputs[i]);
    }

    vector<uint8> future_memory;
    Emulator::GetMemory(&future_memory);

    return objectives->Evaluate(base_memory, future_memory);
  }

  #if MARIONET

  string IPString(const IPaddress &ip) {
    return StringPrintf("%d.%d.%d.%d:%d",
			255 & ip.host,
			255 & (ip.host >> 8),
			255 & (ip.host >> 16),
			255 & (ip.host >> 24),
			ip.port);
  }

  void Helper(int port) {
    IPaddress ip;
    TCPsocket server;
    if (SDLNet_ResolveHost(&ip, NULL, port) == -1) {
      printf("SDLNet_ResolveHost: %s\n", SDLNet_GetError());
      abort();
    }

    server = SDLNet_TCP_Open(&ip);
    if (!server) {
      printf("SDLNet_TCP_Open: %s\n", SDLNet_GetError());
      abort();
    }

    TCPsocket peer;
    for (;;) {
      if ((peer = SDLNet_TCP_Accept(server))) {
	IPaddress *peer_ip = SDLNet_TCP_GetPeerAddress(peer);
	if (peer_ip == NULL) {
	  printf("SDLNet_TCP_GetPeerAddress: %s\n", SDLNet_GetError());
	  abort();
	}
	fprintf(stderr, "[%d] Got connection from %s.\n",
		port, IPString(*peer_ip).c_str());

      } 
    }
  }
  #endif

  // Main loop for the master, or when compiled without MARIONET support.
  void Master() {

    vector<uint8> current_state;
    vector<uint8> current_memory;

    vector< vector<uint8> > nexts = motifvec;

    // This version of the algorithm looks like this. At some point in
    // time, we have the set of motifs we might play next. We'll
    // evaluate all of those. We also have a series of possible
    // futures that we're considering. At each step we play our
    // candidate motif (ignoring that many steps as in the future --
    // but note that for each future, there should be some motif that
    // matches its head). Then we play all the futures. The motif with the
    // best overall score is chosen; we chop the head off each future,
    // and add a random motif to its end.
    //
    // XXX recycling futures...
    vector<Future> futures;

    int64 iters = 0;
    for (;; iters++) {

      motifs->Checkpoint(movie.size());

      if (futures.size() < NFUTURES)
	futures.resize(NFUTURES);
      // Make sure we have enough futures with enough data in.
      for (int i = 0; i < NFUTURES; i++) {
	while (futures[i].inputs.size() < FUTURELENGTH) {
	  const vector<uint8> &m = motifs->RandomWeightedMotif();
	  for (int x = 0; x < m.size(); x++) {
	    futures[i].inputs.push_back(m[x]);
	  }
	}
      }

      // Save our current state so we can try many different branches.
      Emulator::SaveUncompressed(&current_state);    
      Emulator::GetMemory(&current_memory);

      // XXX should be a weighted shuffle.
      // XXX does it even matter that they're shuffled any more?
      Shuffle(&nexts);

      // Total score across all motifs for each future.
      vector<double> futuretotals(NFUTURES, 0.0);

      double best_score = 0.0;
      double best_future = 0.0, best_immediate = 0.0;
      int best_idx = 0;
      Scoredist distribution(movie.size());
      for (int i = 0; i < nexts.size(); i++) {
	if (i != 0) Emulator::LoadUncompressed(&current_state);	

	// Take steps.
	for (int j = 0; j < nexts[i].size(); j++)
	  Emulator::CachingStep(nexts[i][j]);

	vector<uint8> new_memory;
	Emulator::GetMemory(&new_memory);

	vector<uint8> new_state;
	Emulator::SaveUncompressed(&new_state);

	double immediate_score =
	  // objectives->GetNormalizedValue(new_memory);
	  objectives->Evaluate(current_memory, new_memory);

	// PERF unused except for drawing
	double norm_score = objectives->GetNormalizedValue(new_memory);

	double best_future_score = -9999999.0;
	double worst_future_score = 9999999.0;

	static const int NUM_FAKE_FUTURES = 1;
	// Synthetic future where we keep holding the last
	// button pressed.
	Future fakefuture_hold;
	for (int z = 0; z < FUTURELENGTH; z++) {
	  fakefuture_hold.inputs.push_back(nexts[i].back());
	}

	futures.push_back(fakefuture_hold);

	double futures_score = 0.0;
	for (int f = 0; f < futures.size(); f++) {
	  if (f != 0) Emulator::LoadUncompressed(&new_state);
	  double future_score = ScoreByFuture(futures[f], 
					      new_memory, new_state);
	  futuretotals[f] += future_score;
	  futures_score += future_score;
	  if (future_score > best_future_score) 
	    best_future_score = future_score;
	  if (future_score < worst_future_score)
	    worst_future_score = future_score;
	}
	futures.resize(futures.size() - NUM_FAKE_FUTURES);

	double score = immediate_score + futures_score;

	distribution.immediates.push_back(immediate_score);
	distribution.positives.push_back(futures_score);	
	distribution.negatives.push_back(worst_future_score);
	distribution.norms.push_back(norm_score);

	if (score > best_score) {
	  best_score = score;
	  best_immediate = immediate_score;
	  best_future = futures_score;
	  best_idx = i;
	}
      }
      distribution.chosen_idx = best_idx;
      distributions.push_back(distribution);

      // Chop the head off each future.
      const int choplength = nexts[best_idx].size();
      for (int i = 0; i < futures.size(); i++) {
	vector<uint8> newf;
	for (int j = choplength; j < futures[i].inputs.size(); j++) {
	  newf.push_back(futures[i].inputs[j]);
	}
	futures[i].inputs.swap(newf);
      }

      // Discard the future with the worst total.
      double worst_total = futuretotals[0];
      int worst_idx = 0;
      for (int i = 1; i < futuretotals.size(); i++) {
	if (worst_total < futuretotals[i]) {
	  worst_total = futuretotals[i];
	  worst_idx = i;
	}
      }

      // Delete it by swapping.
      if (worst_idx != futures.size() - 1) {
	futures[worst_idx] = futures[futures.size() - 1];
      }
      futures.resize(futures.size() - 1);

      // It'll be replaced the next time around the loop.

      printf("%8d best score %.4f (%.4f + %.4f future) worst %d\n", 
	     movie.size(),
	     best_score, best_immediate, best_future,
	     worst_idx);

      // This is very likely to be cached now.
      Emulator::LoadUncompressed(&current_state);
      for (int j = 0; j < nexts[best_idx].size(); j++) {
	Commit(nexts[best_idx][j]);
      }

      // Now, if the motif we used was a local improvement
      // to the score, reweight it.
      {
	motifs->Pick(nexts[best_idx]);
	vector<uint8> new_memory;
	Emulator::GetMemory(&new_memory);
	double oldval = objectives->GetNormalizedValue(current_memory);
	double newval = objectives->GetNormalizedValue(new_memory);
	double *weight = motifs->GetWeightPtr(nexts[best_idx]);
	if (weight == NULL) {
	  printf(" * ERROR * Used a motif that doesn't exist?\n");
	} else {
	  if (newval > oldval) {
	    // Increases its weight.
	    *weight /= ALPHA;
	  } else {
	    // Decreases its weight.
	    *weight *= ALPHA;
	  }
	}
      }


      if (iters % 10 == 0) {
	SaveDiagnostics(futures);
      }
    }
  }

  void SaveDiagnostics(const vector<Future> &futures) {
    printf("                     - writing -\n");
    SimpleFM2::WriteInputs(GAME "-playfun-backtrack-progress.fm2",
			   GAME ".nes",
			   "base64:jjYwGG411HcjG/j9UOVM3Q==",
			   movie);
    for (int i = 0; i < futures.size(); i++) {
      vector<uint8> fmovie = movie;
      for (int j = 0; j < futures[i].inputs.size(); j++) {
	fmovie.push_back(futures[i].inputs[j]);
	SimpleFM2::WriteInputs(StringPrintf(GAME "-playfun-future-%d.fm2",
					    i),
			       GAME ".nes",
			       "base64:jjYwGG411HcjG/j9UOVM3Q==",
			       fmovie);
      }
    }
    printf("Wrote %d movie(s).\n", futures.size() + 1);

    SaveDistributionSVG(distributions, GAME "-playfun-scores.svg");
    objectives->SaveSVG(memories, GAME "-playfun-backtrack.svg");
    motifs->SaveHTML(GAME "-playfun-motifs.html");
    Emulator::PrintCacheStats();
    printf("                     (wrote)\n");
  }

  // For making SVG.
  vector<Scoredist> distributions;

  // Used to ffwd to gameplay.
  vector<uint8> solution;

  ArcFour rc;
  WeightedObjectives *objectives;
  Motifs *motifs;
  vector< vector<uint8> > motifvec;
};

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  #if MARIONET
  fprintf(stderr, "Init SDL\n");

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(0) >= 0);
  CHECK(SDLNet_Init() >= 0);
  fprintf(stderr, "SDL initialized OK.\n");
  #endif

  PlayFun pf;

  #if MARIONET
  if (argc >= 3 && 0 == strcmp(argv[1], "--helper")) {
    int port = atoi(argv[2]);
    if (!port) {
      fprintf(stderr, "Expected port number after --helper.\n");
      abort();
    }
    fprintf(stderr, "Starting helper on port %d...\n", port);
    pf.Helper(port);
  } else {
    pf.Master();
  }
  #else
  pf.Master();
  #endif

  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();

  #if MARIONET
  SDLNet_Quit();
  SDL_Quit();
  #endif
  return 0;
}
