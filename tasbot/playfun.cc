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

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  Emulator::Initialize("mario.nes");

  vector<uint8> solution = SimpleFM2::ReadInputs("mario.fm2");
  vector<uint8> movie;

  size_t start = 0;
  while (start < solution.size()) {
    Emulator::Step(solution[start]);
    movie.push_back(solution[start]);
    if (solution[start] != 0) break;
    start++;
  }

  printf("Skipped %ld frames until first keypress.\n", start);

  WeightedObjectives *objectives =
    WeightedObjectives::LoadFromFile("mario.objectives");
  CHECK(objectives);
  fprintf(stderr, "Loaded %d objective functions\n", objectives->Size());

  // PERF basis?

  fprintf(stderr, "Starting...\n");

  // Let's just try a greedy version for the lols.
  // At every state we just try the input that increases the
  // most objective functions.

  vector<uint8> current_state;
  vector<uint8> current_memory;

  // 10,000 is about enough to run out the clock, fyi
  static const int NUMFRAMES = 22000;
  for (int framenum = 0; framenum < NUMFRAMES; framenum++) {

    // Save our current state so we can try many different branches.
    Emulator::Save(&current_state);    
    GetMemory(&current_memory);

    static const uint8 buttons[] = { 0, INPUT_A, INPUT_B, INPUT_A | INPUT_B };
    static const uint8 dirs[] = { 0, INPUT_R, INPUT_U, INPUT_L, INPUT_D,
				  INPUT_R | INPUT_U, INPUT_L | INPUT_U,
				  INPUT_R | INPUT_D, INPUT_L | INPUT_D };

    vector<uint8> inputs;
    for (int b = 0; b < sizeof(buttons); b++) {
      for (int d = 0; d < sizeof(dirs); d++) {
	uint8 input = buttons[b] | dirs[d];
	inputs.push_back(input);
      }
    }
    
    // To break ties.
    Shuffle(&inputs);

    double best_score = -1;
    uint8 best_input = 0;
    for (int i = 0; i < inputs.size(); i++) {
      // (Don't restore for first one; it's already there)
      if (i != 0) Emulator::Load(&current_state);
      Emulator::Step(inputs[i]);

      vector<uint8> new_memory;
      GetMemory(&new_memory);
      double score = objectives->GetNumLess(current_memory, new_memory);
      if (score > best_score) {
	best_score = score;
	best_input = inputs[i];
      }
    }

    printf("Best was %f: %s\n", 
	   best_score,
	   SimpleFM2::InputToString(best_input).c_str());

    // PERF maybe could save best state?
    Emulator::Load(&current_state);
    Emulator::Step(best_input);
    movie.push_back(best_input);
  }

  SimpleFM2::WriteInputs("mario-playfun.fm2", "mario.nes",
			 // XXX
			 "base64:jjYwGG411HcjG/j9UOVM3Q==",
                         movie);

  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();
  return 0;
}
