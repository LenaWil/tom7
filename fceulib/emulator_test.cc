
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
  CHECK(emu.get() != nullptr);
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

  const int64 start_us = TimeUsec();
  for (int i = 0; i < 10; i++) {
    RunGameSerially(escape);
  }

  const int64 end_us = TimeUsec();
  const int64 elapsed_us = end_us - start_us;
  printf("Took %.2f ms\n", elapsed_us / 1000.0);


#if 0
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
      

  RunGameSerially(karate);
  RunGameSerially(karate);
#endif

  // TODO: Include escape.nes
  
  return 0;
}
