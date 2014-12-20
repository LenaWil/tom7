
#include "emulator.h"

#include <string>
#include <vector>
#include <memory>
#include <sys/time.h>

#include "base/logging.h"
#include "test-util.h"
#include "arcfour.h"
#include "rle.h"
#include "simplefm2.h"

struct Game {
  string cart;
  vector<uint8> inputs;
  uint64 after_load;
  uint64 after_inputs;
  uint64 after_random;
};

int64 TimeUsec() {
  // XXX solution for win32.
  // (Actually this currently compiles on mingw64!)
  timeval tv;
  gettimeofday(&tv, nullptr);
  return tv.tv_sec * 1000000LL + tv.tv_usec;
}

static void RunGameSerially(const Game &game) {
  printf("Testing %s...\n" , game.cart.c_str());
# define CHECK_RAM(field) do {			   \
    uint64 cx = emu->RamChecksum();		   \
    CHECK_EQ(cx, (field))			   \
      << "\nExpected ram to be " << #field << " = "  \
      << (field) << " but got " << cx;		   \
  } while(0)

  std::unique_ptr<Emulator> emu{Emulator::Create(game.cart)};
  CHECK(emu.get() != nullptr) << game.cart.c_str();
  CHECK_RAM(game.after_load);

  for (uint8 b : game.inputs) emu->StepFull(b);
  CHECK_RAM(game.after_inputs);

  ArcFour rc(game.cart);
  rc.Discard(1024);
  uint8 b = 0;

  for (int i = 0; i < 10000; i++) {
    if (rc.Byte() < 210) {
      // Keep b the same as last round.
    } else {
      switch (rc.Byte() % 20) {
      case 0:
      default:
	b = INPUT_R;
	break;
      case 1:
	b = INPUT_U;
	break;
      case 2:
	b = INPUT_D;
	break;
      case 3:
      case 11:
	b = INPUT_R | INPUT_A;
	break;
      case 4:
      case 12:
	b = INPUT_R | INPUT_B;
	break;
      case 5:
      case 13:
	b = INPUT_R | INPUT_B | INPUT_A;
	break;
      case 6:
      case 14:
	b = INPUT_A;
	break;
      case 7:
      case 15:
	b = INPUT_B;
	break;
      case 8:
	b = 0;
	break;
      case 9:
	b = rc.Byte() & (~(INPUT_T | INPUT_S));
	break;
      case 10:
	b = rc.Byte();
      }
    }
    emu->StepFull(b);
  }
  CHECK_RAM(game.after_random);
}

int main() {

  // First, ensure that we have preserved the single-threaded
  // behavior.

  Game escape{
    "escape.nes",
    RLE::Decompress({
      49, 0, 3, 8, 68, 0, 3, 8, 120, 0, 22, 128, 86, 0, 27, 128, 16, 129, 
      12, 128, 11, 130, 11, 128, 1, 0, 13, 64, 1, 0, 8, 128, 11, 129, 9,
      128, 9, 129, 14, 128, 2, 0, 8, 64, 0, 0, 2, 128, 2, 0, 12, 130, 128,
      0, 128, 0, 128, 0, 27, 0, 27, 128, 23, 130, 12, 128, 8, 0, 4, 128, 21,
      129, 11, 64, 14, 128, 16, 130, 23, 128, 16, 64, 2, 0, 8, 128, 24, 130,
	13, 128, 25, 2, 128, 0, 128, 0, 128, 0, 2, 0, 28, 128, 0, 0}),
    204558985997460734ULL,
    6838541238215755706ULL,
    14453325089239387428ULL,
    };

  Game karate{
    "karate.nes",
    RLE::Decompress({
      49, 0, 3, 8, 68, 0, 3, 8, 120, 0, 22, 128, 86, 0, 27, 128, 16, 129, 
      12, 128, 11, 130, 11, 128, 1, 0, 13, 64, 1, 0, 8, 128, 11, 129, 9,
      128, 9, 129, 14, 128, 2, 0, 8, 64, 0, 0, 2, 128, 2, 0, 12, 130, 128,
      0, 128, 0, 128, 0, 27, 0, 27, 128, 23, 130, 12, 128, 8, 0, 4, 128, 21,
      129, 11, 64, 14, 128, 16, 130, 23, 128, 16, 64, 2, 0, 8, 128, 24, 130,
      13, 128, 25, 2, 128, 0, 128, 0, 128, 0, 2, 0, 28, 128, 0, 0}),
      0x2d6bd505ffe24feULL,
      0x38cff7186cda146fULL,
      0x8ae8299e61234c95ULL,
      };

  Game mario{
    "mario.nes",
    RLE::Decompress({
      68, 0, 0, 8, 43, 0, 10, 2, 37, 130, 2, 2, 83, 0, 2, 128, 118,
      130, 13, 131, 7, 130, 30, 2, 9, 130, 10, 131, 0, 3, 72, 2, 5,
      130, 5, 2, 11, 130, 18, 131, 13, 130, 91, 131, 18, 130, 18, 131,
      19, 130, 20, 131, 30, 130, 41, 131, 39, 130, 35, 131, 0, 130, 7,
      2, 49, 130, 26, 2, 12, 130, 10, 131, 15, 130, 23, 2, 4, 130, 6,
      2, 15, 130, 2, 2, 9, 3, 0, 2, 2, 66, 19, 64, 26, 0, 9, 2, 2, 3,
      16, 67, 2, 3, 12, 2, 6, 66, 16, 2, 14, 3, 24, 67, 10, 3, 9, 2,
      1, 66, 6, 67, 12, 66, 7, 2, 17, 130, 8, 128, 12, 0, 55, 128, 6,
      0, 10, 128, 26, 130, 22, 131, 0, 129, 2, 128, 4, 130, 2, 128, 0,
      0, 5, 2, 21, 0, 6, 2, 3, 0, 5, 2, 6, 0, 5, 2, 9, 0, 6, 128, 124,
      130, 8, 131, 45, 130, 25, 131, 48, 130, 17, 131, 13, 130, 22,
      131, 21, 130, 2, 2, 22, 130, 32, 131, 1, 130, 15, 2, 6, 130, 10,
      2, 12, 3, 1, 131, 10, 130, 5, 2, 15, 130, 17, 131, 5, 130, 5,
      131, 4, 130, 3, 131, 19, 130, 1, 128, 2, 0, 1, 2, 15, 130, 19,
      131, 1, 130, 0, 128, 3, 0, 5, 2, 4, 0, 7, 2, 2, 0, 5, 2, 2, 0,
      4, 2, 2, 0, 5, 2, 2, 0, 5, 2, 2, 0, 5, 2, 1, 0, 7, 2, 20, 0, 7,
      128, 45, 130, 18, 131, 21, 130, 30, 131, 15, 130, 20, 131, 25,
      130, 63, 131, 3, 130, 1, 128, 128, 0, 128, 0, 128, 0, 128, 0,
      128, 0, 128, 0, 128, 0, 128, 0, 128, 0, 1, 0, 46, 128, 16, 0, 6,
      128, 5, 130, 36, 131, 25, 130, 27, 131, 32, 130, 6, 2, 0, 130,
      23, 131, 17, 130, 69, 2, 18, 130, 14, 131, 45, 130, 49, 2, 92,
      0}),
      204558985997460734ULL,
      187992912212093401ULL,
      16444816755826868158ULL,
      };

  const int64 start_us = TimeUsec();

  RunGameSerially(mario);

  for (int i = 0; i < 3; i++) {
    RunGameSerially(escape);
  }

  RunGameSerially(karate);
  RunGameSerially(karate);
  RunGameSerially(escape);

  const int64 end_us = TimeUsec();
  const int64 elapsed_us = end_us - start_us;
  printf("Took %.2f ms\n", elapsed_us / 1000.0);

  return 0;
}
