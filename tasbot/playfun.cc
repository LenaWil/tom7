/* Searches for solutions to Karate Kid. */

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

#define GAME "punchout"

// Get the hashcode for the current state. This is based just on RAM.
// XXX should include registers too, right?
static uint64 GetHashCode() {
#if 0
  uint64 a = 0xDEADBEEFCAFEBABEULL,
    b = 0xDULL,
    c = 0xFFFF000073731919ULL;
  for (int i = 0; i < 0x800; i++) {
    do { uint64 t = a; a = b; b = c; c = t; } while(0);
    switch (i) {
    // Bytes that are ignored...
    case 0x036E: // Contains the input byte for that frame. Ignore.

      break;
    default:
      a += (RAM[i] * 31337);
      b ^= 0xB00BFACEFULL;
      c *= 0x1234567ULL;
      c = (c >> 17) | (c << (64 - 17));
      a ^= c;
    }
  }
  return a + b + c;
#endif

#if 0
  md5_context md;
  md5_starts(&md);
  md5_update(&md, RAM, 0x036E);
  md5_update(&md, RAM + 0x036F, 0x800 - 0x36F);
  uint8 digest[16];
  md5_finish(&md, digest);

  return *(uint64*)&digest;
#endif

  vector<uint8> ss;
  Emulator::GetBasis(&ss);
  md5_context md;
  md5_starts(&md);
  md5_update(&md, &ss[0], ss.size());
  uint8 digest[16];
  md5_finish(&md, digest);


  uint64 res = 0;
  for (int i = 0; i < 8; i++) {
    res <<= 8;
    res |= 255 & digest[i];
  }
  return res;
}

// Magic "game location" address.
// See addresses.txt
static uint32 GetLoc() {
  return (RAM[0x0080] << 24) |
    (RAM[0x0081] << 16) |
    (RAM[0x0082] << 8) |
    (RAM[0x0083]);
}

// Initialized at startup.
static vector<uint8> *basis = NULL;

template<class T>
static void Shuffle(vector<T> *v) {
  static uint64 h = 0xCAFEBABEDEADBEEFULL;
  for (int i = 0; i < v->size(); i++) {
    h *= 31337;
    h ^= 0xFEEDFACE;
    h = (h >> 17) | (h << (64 - 17));
    h -= 911911911911;
    h *= 65537;
    h ^= 0x3141592653589ULL;

    int j = h % v->size();
    if (i != j) {
      swap((*v)[i], (*v)[j]);
    }
  }
}

static void GetMemory(vector<uint8> *mem) {
  // PERF!
  mem->clear();
  for (int i = 0; i < 0x800; i++) {
    mem->push_back((uint8)RAM[i]);
  }
}

struct PlayFun {
  PlayFun() : rc("playfun") {
    Emulator::Initialize(GAME ".nes");
    objectives = WeightedObjectives::LoadFromFile(GAME ".objectives");
    CHECK(objectives);
    fprintf(stderr, "Loaded %d objective functions\n", objectives->Size());

    motifs = Motifs::LoadFromFile(GAME ".motifs");
    CHECK(motifs);

    for (Motifs::Weighted::const_iterator it = motifs->motifs.begin();
	 it != motifs->motifs.end(); ++it) {
      motifvec.push_back(it->first);
    }

    // PERF basis?

    solution = SimpleFM2::ReadInputs("punchouttom.fm2");

    size_t start = 0;
    while (start < solution.size()) {
      Emulator::Step(solution[start]);
      movie.push_back(solution[start]);
      if (solution[start] != 0) break;
      start++;
    }

    printf("Skipped %ld frames until first keypress.\n", start);
  }

  const vector<uint8> &RandomMotif() {
    uint32 b = 0;
    b = (b << 8) | rc.Byte();
    b = (b << 8) | rc.Byte();
    b = (b << 8) | rc.Byte();

    return motifvec[b % motifvec.size()];
  }

  // Look fairly deep into the future playing randomly. 
  // DESTROYS THE STATE.
  double ScoreByRandomFuture(const vector<uint8> &base_memory) {
    static const int DEPTH = 10;
    static const int NUM = 2;
    vector<uint8> base_state;
    Emulator::Save(&base_state);

    double total = 0.0;
    for (int i = 0; i < NUM; i++) {
      if (i) Emulator::Load(&base_state);
      for (int d = 0; d < DEPTH; d++) {
	const vector<uint8> &m = RandomMotif();
	for (int x = 0; x < m.size(); x++) {
	  Emulator::Step(m[x]);
	}
      }

      vector<uint8> future_memory;
      GetMemory(&future_memory);
      total += objectives->GetNumLess(base_memory, future_memory);
    }

    // We're allowed to destroy the current state, so don't
    // restore.
    return total;
  }

#if 0
  // Search all different sequences of motifs of length 'depth'.
  // Choose the one with the highest score.
  void ExhaustiveMotifSearch(int depth) {
    vector<uint8> current_state, current_memory;
    Emulator::Save(&current_state);
    GetMemory(&current_memory);

  }
#endif

  void Greedy() {
    // Let's just try a greedy version for the lols.
    // At every state we just try the input that increases the
    // most objective functions.

    vector<uint8> current_state;
    vector<uint8> current_memory;

    vector< vector<uint8> > nexts;
    for (Motifs::Weighted::const_iterator it = motifs->motifs.begin();
	 it != motifs->motifs.end(); ++it) {
      // XXX ignores weights
      nexts.push_back(it->first);
    }

    // 10,000 is about enough to run out the clock, fyi
    // XXX not frames, #motifs
    static const int NUMFRAMES = 10000;
    for (int framenum = 0; framenum < NUMFRAMES; framenum++) {

      // Save our current state so we can try many different branches.
      Emulator::Save(&current_state);    
      GetMemory(&current_memory);

      // To break ties.
      Shuffle(&nexts);

      double best_score = -999999999.0;
      double best_future, best_immediate;
      vector<uint8> *best_input = &nexts[0];
      for (int i = 0; i < nexts.size(); i++) {
	// (Don't restore for first one; it's already there)
	if (i != 0) Emulator::Load(&current_state);
	for (int j = 0; j < nexts[i].size(); j++)
	  Emulator::Step(nexts[i][j]);

	vector<uint8> new_memory;
	GetMemory(&new_memory);
	double immediate_score =
	  objectives->GetNumLess(current_memory, new_memory);
	double future_score = ScoreByRandomFuture(new_memory);

	double score = immediate_score + future_score;

	if (score > best_score) {
	  best_score = score;
	  best_immediate = immediate_score;
	  best_future = future_score;
	  best_input = &nexts[i];
	}
      }

      printf("%8d best score %.2f (%.2f + %.2f future):\n", 
	     movie.size(),
	     best_score, best_immediate, best_future);
      // SimpleFM2::InputToString(best_input).c_str());

      // PERF maybe could save best state?
      Emulator::Load(&current_state);
      for (int j = 0; j < best_input->size(); j++) {
	Emulator::Step((*best_input)[j]);
	movie.push_back((*best_input)[j]);
      }

      if (framenum % 10 == 0) {
	SimpleFM2::WriteInputs(GAME "-playfun-motif-progress.fm2", GAME ".nes",
			       // XXX
			       "base64:Ww5XFVjIx5aTe5avRpVhxg==",
			       // "base64:jjYwGG411HcjG/j9UOVM3Q==",
			       movie);
	printf("                     (wrote)\n");
      }
    }

    SimpleFM2::WriteInputs(GAME "-playfun-motif-final.fm2", GAME ".nes",
			   // XXX
			   "base64:Ww5XFVjIx5aTe5avRpVhxg==",
			   // "base64:jjYwGG411HcjG/j9UOVM3Q==",
			   movie);
  }

  // Used to ffwd to gameplay.
  vector<uint8> solution;
  // Contains the movie we record.
  vector<uint8> movie;

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

  pf.Greedy();

  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();
  return 0;
}
