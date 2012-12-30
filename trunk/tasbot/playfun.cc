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

#define GAME "mario"
#define MOVIE "mario-cleantom.fm2"
#define FASTFORWARD 256  // XXX cheats! -- should be 0

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
  
#if 0
  ArcFour rc("Umake colors");
  vector<string> colors;
  for (int i = 0; i < dists.back().immediates.size(); i++) {
    colors.push_back(RandomColor(&rc));
  }
#endif

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

  void Go() {

    vector<uint8> current_state;
    vector<uint8> current_memory;

    vector< vector<uint8> > nexts = motifvec;

    int64 iters = 0;
    for (;; iters++) {

      // Save our current state so we can try many different branches.
      Emulator::SaveUncompressed(&current_state);    
      Emulator::GetMemory(&current_memory);

      // XXX should be a weighted shuffle.
      Shuffle(&nexts);

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

	double negative_score = AvoidBadFutures(new_memory);

	Emulator::LoadUncompressed(&new_state);
	double positive_score = SeekGoodFutures(new_memory);

	double future_score = negative_score + positive_score;
	double score = immediate_score + future_score;

	distribution.immediates.push_back(immediate_score);
	distribution.positives.push_back(positive_score);	
	distribution.negatives.push_back(negative_score);
	distribution.norms.push_back(norm_score);

	if (score > best_score) {
	  best_score = score;
	  best_immediate = immediate_score;
	  best_future = future_score;
	  best_idx = i;
	}
	
      }
      distribution.chosen_idx = best_idx;
      distributions.push_back(distribution);

      printf("%8d best score %.4f (%.4f + %.4f future):\n", 
	     movie.size(),
	     best_score, best_immediate, best_future);

      // This is very likely to be cached now.
      Emulator::LoadUncompressed(&current_state);
      for (int j = 0; j < nexts[best_idx].size(); j++) {
	Commit(nexts[best_idx][j]);
      }

      if (iters % 10 == 0) {
	printf("                     - writing -\n");
	SimpleFM2::WriteInputs(GAME "-playfun-backtrack-progress.fm2",
			       GAME ".nes",
			       // XXX
			       "base64:Ww5XFVjIx5aTe5avRpVhxg==",
			       // "base64:jjYwGG411HcjG/j9UOVM3Q==",
			       movie);
	SaveDistributionSVG(distributions, GAME "-playfun-scores.svg");
	objectives->SaveSVG(memories, GAME "-playfun-backtrack.svg");
	Emulator::PrintCacheStats();
	printf("                     (wrote)\n");
      }
    }
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
  PlayFun pf;

  fprintf(stderr, "Starting...\n");

  pf.Go();

  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();
  return 0;
}
