
#include "emulator.h"

#include <string>
#include <vector>
#include <memory>
#include <sys/time.h>
#include <sstream>
#include <unistd.h>
#include <cstdio>

#include "base/logging.h"
#include "test-util.h"
#include "arcfour.h"
#include "rle.h"
#include "simplefm2.h"
#include "base/stringprintf.h"
#include "stb_image_write.h"

#include "tracing.h"

static constexpr uint64 kEveryGameUponLoad =
  204558985997460734ULL;

// Don't change these here! I've had serious bugs from unintentionally
// leaving this in make_comprehensive mode. There are command line
// flags for all of them.
static bool FULL = false;
static bool COMPREHENSIVE = false;
static bool MAKE_COMPREHENSIVE = false;

struct Game {
  string cart;
  vector<uint8> inputs;
  uint64 after_load;
  uint64 after_inputs;
  uint64 after_random;
  uint64 image_after_inputs;
  uint64 image_after_random;
  string random_seed = "randoms";
  Game(const string &c, const vector<uint8> &i,
       uint64 al, uint64 ai, uint64 ar,
       uint64 iai, uint64 iar) :
    cart(c), inputs(i), after_load(al), 
    after_inputs(ai), after_random(ar),
    image_after_inputs(iai), image_after_random(iar) {}
  Game(const string &c, const vector<uint8> &i,
       uint64 al, uint64 ai, uint64 ar,
       uint64 iai, uint64 iar,
       const string &seed) :
    cart(c), inputs(i), after_load(al), 
    after_inputs(ai), after_random(ar),
    image_after_inputs(iai), image_after_random(iar),
    random_seed(seed) {}
};

static int64 TimeUsec() {
  // XXX solution for win32.
  // (Actually this currently compiles on mingw64!)
  timeval tv;
  gettimeofday(&tv, nullptr);
  return tv.tv_sec * 1000000LL + tv.tv_usec;
}

struct InputStream {
  InputStream(const string &seed, int length) {
    v.reserve(length);
    ArcFour rc(seed);
    rc.Discard(1024);

    uint8 b = 0;

    for (int i = 0; i < length; i++) {
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
      v.push_back(b);
    }
  }

  vector<uint8> v;

  decltype(v.begin()) begin() { return v.begin(); }
  decltype(v.end()) end() { return v.end(); }
};

struct Collage {
  static constexpr int NUMW = 10;
  static constexpr int NUMH = 6;
  static constexpr int WIDTH = 256 * 10;
  static constexpr int HEIGHT = 240 * 6;

  const string filename_base;
  int file_number = 0;
  int nextx = 0;
  int nexty = 0;
  vector<uint8> cur;
  explicit Collage(string prefix) : filename_base(prefix + "collage") {
    cur.reserve(WIDTH * HEIGHT * 4);
    for (int i = 0; i < WIDTH * HEIGHT; i++) {
      cur.push_back(0);
      cur.push_back(0);
      cur.push_back(0);
      cur.push_back(0xFF);
    }
  }
  
  void Push(const vector<uint8> &screen) {
    CHECK(cur.size() == WIDTH * HEIGHT * 4);
    CHECK(screen.size() >= 256 * 240 * 4);
    CHECK(nextx < NUMW);
    CHECK(nexty < NUMH);

    // Given pixel coordinates, write the RGBA tuple.
    auto Write4 = [this, &screen](int sx, int sy, int dx, int dy) {
      int sp = sx * 4 + sy * 256 * 4;
      int dp = dx * 4 + dy * WIDTH * 4;
      CHECK(dp >= 0 && dp + 3 < cur.size()) << dp << " " << cur.size();
      CHECK(sp >= 0 && sp + 3 < screen.size());
      cur[dp + 0] = screen[sp + 0];
      cur[dp + 1] = screen[sp + 1];
      cur[dp + 2] = screen[sp + 2];
      cur[dp + 3] = screen[sp + 3];
    };
    for (int srcx = 0; srcx < 256; srcx++) {
      for (int srcy = 0; srcy < 240; srcy++) {
	int dstx = nextx * 256 + srcx;
	int dsty = nexty * 240 + srcy;
	Write4(srcx, srcy, dstx, dsty);
      }
    }

    nextx++;
    if (nextx >= NUMW) {
      nextx = 0;
      nexty++;
      if (nexty >= NUMH) {
	Flush();
      }
    }
  }

  // Only writes an image if there are any.
  void Flush() {
    if (nextx > 0 || nexty > 0) {
      // XXX write image.
      string filename = 
	StringPrintf("%s-%d.png", filename_base.c_str(), file_number);
      stbi_write_png(filename.c_str(), WIDTH, HEIGHT, 4, cur.data(),
		     4 * WIDTH);
      fprintf(stderr, "Flushed %d-image collage to %s.\n",
	      nextx + nexty * NUMW,
	      filename.c_str());
      file_number++;
    }
    nextx = 0;
    nexty = 0;
  }

};

struct SerialResult {
  uint64 after_inputs = 0ULL;
  uint64 after_random = 0ULL;
  uint64 image_after_inputs = 0ULL;
  uint64 image_after_random = 0ULL;
  // Only in FULL+ mode.
  vector<uint8> final_image;
};

static SerialResult RunGameSerially(const Game &game) {
  printf("Testing %s...\n" , game.cart.c_str());
# define CHECK_RAM(field) do {                       \
    const uint64 cx = emu->RamChecksum();            \
    CHECK_EQ(cx, (field))                            \
      << "\nExpected ram to be " << #field << " = "  \
      << (field) << "\nbut got " << cx;               \
  } while(0)

  // Once we've collected the states, we have not just the checksums
  // but the actual RAMs (in full mode), so we can print better
  // diagnostic messages. The argument i is the index into checksums
  // and actual_rams.
  // XXX TODO: Also check screenshots at each step.
# define CHECK_RAM_STEP(i) do {                                 \
    const int idx = (i);                                        \
    CHECK(idx >= 0);                                            \
    CHECK(idx < checksums.size());                              \
    CHECK(!FULL || idx < actual_rams.size());                   \
    const uint64 cx = emu->RamChecksum();                       \
    if (cx != checksums[idx]) {                                 \
      fprintf(stderr, "Bad RAM checksum at step %d (%s). "      \
              "Expected\n %llu\nbut got %llu.\n", idx, #i,      \
              checksums[idx], cx);                              \
      if (FULL) {                                               \
        const vector<uint8> mem = emu->GetMemory();             \
        CHECK(mem.size() == 0x800);                             \
        CHECK(actual_rams[idx].size() == 0x800);                \
        vector<string> mismatches;                              \
        for (int j = 0; j < 0x800; j++) {                       \
          if (mem[j] != actual_rams[idx][j]) {                  \
            mismatches.push_back(                               \
                 StringPrintf("@%d %02x!=%02x",                 \
                              j, mem[j],                        \
                              actual_rams[idx][j]));            \
          }                                                     \
        }                                                       \
        fprintf(stderr, "Total of %d byte mismatch(es):\n",     \
                (int)mismatches.size());                        \
        for (int j = 0; j < mismatches.size(); j++) {           \
          fprintf(stderr, "%s%s", mismatches[j].c_str(),        \
                  j < mismatches.size() - 1 ? ", " : "!");      \
          if (j > 20) {                                         \
            fprintf(stderr, "..."); break;                      \
          }                                                     \
        }                                                       \
        fprintf(stderr, "\n");                                  \
      } else {                                                  \
        fprintf(stderr, "Run with --full to see details.\n");   \
      }                                                         \
      TRACEF("(crashed)");					\
      abort();                                                  \
    }                                                           \
  } while (0)
  
  TRACEF("RunGameSerially %s.", game.cart.c_str());

  // Save files are being successfully written and loaded now. TODO(twm):
  // Need to make the emulator not secretly touch the filesystem. These
  // should just be part of the savestate feature.
  if (0 == unlink(".sav")) {
    fprintf(stderr, "NOTE: Removed .sav file before RunGameSerially.\n");
  }

  if (0 == remove(".sav")) {
    fprintf(stderr, "NOTE: Removed .sav file (C++ style).\n");
  }

  CHECK(!ExistsFile(".sav")) << "\nJust tried to unlink this. "
    "Is another process using it?";

  // save[i] and checksum[i] represent the state right before
  // input[i] is issued. Note we don't have save/checksum for
  // the final state.
  vector<vector<uint8>> saves;
  vector<vector<uint8>> compressed_saves;
  vector<uint64> checksums;
  // Only populated in FULL mode.
  vector<vector<uint8>> actual_rams;
  // Only populated in FULL mode.
  vector<vector<uint8>> images;
  vector<uint8> inputs;
  std::unique_ptr<Emulator> emu{Emulator::Create(game.cart)};

  if (emu.get() == nullptr) {
    printf("FAILED LOADING!\n");
    return SerialResult{};
  }

  CHECK(emu.get() != nullptr) << game.cart.c_str();
  CHECK_RAM(game.after_load);
  TRACEF("after_load %llu.", emu->RamChecksum());

  vector<uint8> basis;
  emu->GetBasis(&basis);

  auto StepMaybeTraced = [&emu](uint8 b) {
    const uint64 cx = emu->RamChecksum();
    // This is debugging task specific. Copy and paste the target
    // in here!
    const bool match = false;
    TRACEF(".. %llu", cx);
    TRACE_SCOPED_ENABLE_IF(match);
    if (match) {
      fprintf(stderr, "Enabling tracing because of ram match %llu.\n", cx);
      TRACEF("RAM match %llu so tracing input [%s].",
	     cx,
	     SimpleFM2::InputToString(b).c_str());
    }
    emu->StepFull(b);
  };

  int step_counter = 0;
  auto SaveAndStep = [&StepMaybeTraced, &step_counter,
		      &game, &emu, &saves, &inputs, &checksums,
                      &actual_rams, &images,
		      &compressed_saves, &basis](uint8 b) {
    TRACEF("Step %d: %s", step_counter, SimpleFM2::InputToString(b).c_str());
    step_counter++;
    vector<uint8> save;
    emu->SaveUncompressed(&save);
    TRACEF("Saved.");
    TRACEV(save);

    saves.push_back(std::move(save));
    if (FULL) {
      vector<uint8> compressed_save;
      emu->SaveEx(&compressed_save, &basis);
      compressed_saves.push_back(compressed_save);
    }
    inputs.push_back(b);
    const uint64 csum = emu->RamChecksum();
    CHECK(csum != 0ULL) << checksums.size() << " " << game.cart;
    checksums.push_back(csum);
    if (FULL) {
      actual_rams.push_back(emu->GetMemory());
      images.push_back(emu->GetImage());
    }
    StepMaybeTraced(b);
  };

  for (uint8 b : game.inputs) SaveAndStep(b);
  const uint64 ret1 = emu->RamChecksum();
  const uint64 iret1 = emu->ImageChecksum();
  if (!MAKE_COMPREHENSIVE) {
    CHECK_RAM(game.after_inputs);
    CHECK_EQ(game.image_after_inputs, iret1) << iret1;
  }
  TRACEF("after_inputs %llu.", emu->RamChecksum());

  fprintf(stderr, "Random inputs:\n");
  // TRACE_SWITCH("forward-trace.bin");
  for (uint8 b : InputStream("randoms", 10000)) SaveAndStep(b);
  // This is checked by the comprehensive driver, or should be.
  const uint64 ret2 = emu->RamChecksum();
  const uint64 iret2 = emu->ImageChecksum();
  if (!MAKE_COMPREHENSIVE) {
    CHECK_RAM(game.after_random);
    CHECK_EQ(game.image_after_random, iret2) << iret2;
  }
  // TRACEF("after_random %llu.", emu->RamChecksum());

  if (FULL) {
    // Go backwards to avoid just accidentally having the correct
    // internal state on account of just replaying all the frames in
    // order!
    fprintf(stderr, "Running frames backwards:\n");
    // TRACE_SWITCH("backward-trace.bin");
    for (int i = saves.size() - 2; i >= 0; i--) {
      // fprintf(stderr, "%d -> %d: ", i, i + 1);
      emu->LoadUncompressed(&saves[i]);
      CHECK_RAM_STEP(i);
      // fprintf(stderr, "(ram starts %llu)\n", emu->RamChecksum());
      CHECK(i + 1 < saves.size());
      CHECK(i + 1 < inputs.size());
      StepMaybeTraced(inputs[i]);
      CHECK_RAM_STEP(i + 1);
    }
  }

  // Now jump around and make sure that we are able to save and
  // restore state correctly (at least, such that the behavior is
  // the same as last time).
  ArcFour rc("retries");
  auto Rand = [&rc](int max) {
    uint64 b =
      rc.Byte() << 24 |
      rc.Byte() << 16 |
      rc.Byte() << 8 |
      rc.Byte();
    // printf("%lld", b);
    return b % max;
  };

  auto DoSeekSpan = [&emu, &saves, &checksums, &inputs, 
		     &actual_rams, &StepMaybeTraced](int seekto, int dist) {
    // fprintf(stderr, "seekto %d dist %d\n", seekto, dist);
    emu->LoadUncompressed(&saves[seekto]);
    CHECK_RAM(checksums[seekto]);
    for (int j = 0; j < dist; j++) {
      if (seekto + j + 1 < saves.size()) {
	// fprintf(stderr, "  [ram %llu] Stepping to idx %d...\n", 
	//         emu->RamChecksum(), seekto + j);
        StepMaybeTraced(inputs[seekto + j]);
        CHECK_RAM(checksums[seekto + j + 1]);
      }
    }
  };

  #if 0
  // In basketball.nes.
  fprintf(stderr, "Reproduce failure:\n");
  TRACE_SWITCH("testcase-trace.bin");
  for (const auto &p : {pair<int, int>{5941, 1}, {8437, 2}})
    DoSeekSpan(p.first, p.second);

  fprintf(stderr, "XXX failed to reproduce failure...\n");
  abort();
  #endif

  fprintf(stderr, "Random seeks:\n");
  for (int i = 0; i < 500; i++) {
    const int seekto = Rand(saves.size());
    const int dist = Rand(5) + 1;
    DoSeekSpan(seekto, dist);
  }

  if (FULL) {
    fprintf(stderr, "Random seeks (compressed):\n");
    for (int i = 0; i < 500; i++) {
      const int seekto = Rand(saves.size());
      // fprintf(stderr, "iter %d seekto %d\n", i, seekto);
      emu->LoadEx(&compressed_saves[seekto], &basis);
      CHECK_RAM(checksums[seekto]);
      const int dist = Rand(5) + 1;
      for (int j = 0; j < dist; j++) {
        if (seekto + j + 1 < saves.size()) {
          emu->StepFull(inputs[seekto + j]);
          CHECK_RAM(checksums[seekto + j + 1]);
        }
      }
    }
  }

  fprintf(stderr, "OK.\n");
  // XXX probably don't need separate ret1, ret2 now?
  SerialResult sr;
  sr.after_inputs = ret1;
  sr.after_random = ret2;
  sr.image_after_inputs = iret1;
  sr.image_after_random = iret2;
  if (FULL && images.size() > 0) {
    sr.final_image = std::move(images[images.size() - 1]);
  }

  fprintf(stderr, "Returning...\n");
  return sr;
}

int main(int argc, char **argv) {
  int modulus = 1;
  int my_index = 0;
  string output_file;
  string romdir = "roms/";
  bool write_collage = true;
  
  for (int i = 1; i < argc; i++) {
    string arg = argv[i];
    if (arg == "--full" || arg == "-full") {
      FULL = true;
    } else if (arg == "--output-file") {
      COMPREHENSIVE = true;
      MAKE_COMPREHENSIVE = true;
      CHECK(i + 1 < argc);
      i++;
      output_file = argv[i];
    } else if (arg == "--comprehensive" || arg == "-comprehensive") {
      CHECK(output_file.empty()) << "--output-file implies "
	"make-comprehensive mode, which is not what --comprehensive does.";
      FULL = true;
      COMPREHENSIVE = true;
      MAKE_COMPREHENSIVE = false;
    } else if (arg == "--modulus") {
      CHECK(i + 1 < argc);
      i++;
      modulus = atoi(argv[i]);
    } else if (arg == "--index") {
      CHECK(i + 1 < argc);
      i++;
      my_index = atoi(argv[i]);
    } else if (arg == "--romdir") {
      CHECK(i + 1 < argc);
      i++;
      romdir = argv[i];
      CHECK(!romdir.empty());
      if (romdir[romdir.size() - 1] != '/') romdir += '/';
    } else if (arg == "--nocollage") {
      write_collage = false;
    }
  }
  if (COMPREHENSIVE) { 
    if (MAKE_COMPREHENSIVE) {
      fprintf(stderr, "Generating comprehensive file to %s!\n",
	      output_file.c_str());
    } else {
      fprintf(stderr, "Running COMPREHENSIVE tests!\n");
    }
  } else if (FULL) {
    fprintf(stderr, "Running FULL tests.\n");
  } else {
    fprintf(stderr, "Running 'fast' tests.\n");
  }

  if (modulus != 1) {
    CHECK(COMPREHENSIVE) << "modulus is only allowed in COMPREHENSIVE mode.";
    CHECK(!MAKE_COMPREHENSIVE) << "this would have to make writes to the "
      "same file from multiple processes, so it's not implemented yet.";
    CHECK(modulus > 1);
    CHECK(my_index >= 0);
    CHECK(my_index < modulus);
    fprintf(stderr, "This will be index %d mod %d.\n", my_index, modulus);
  }

  // First, ensure that we have preserved the single-threaded
  // behavior.

  // Regression -- Tengen cart wasn't saving all its state.
  Game skull{
    "skull.nes",
    RLE::Decompress({ 101, 0, 4, 2, 3, 3, 2, 1, 50, 0, }),
    kEveryGameUponLoad,
    17813153070445949947ULL,
    4140614200917092591ULL,
    10140109344488695766ULL,
    16099682408657503265ULL,
    };

  Game ubasketball{
    "ubasketball.nes",
    RLE::Decompress({ 101, 0, 4, 2, 3, 3, 2, 1, 50, 0, }),
    kEveryGameUponLoad,
    18168214949483867499ULL,
    13068962115749660119ULL,
    14414055657961427423ULL,
    7065287229454446029ULL,
    romdir + "Ultimate Basketball.nes",
    };

  Game dw4{
    "dw4.nes",
    RLE::Decompress({ 101, 0, 4, 2, 3, 3, 2, 1, 50, 0, }),
    kEveryGameUponLoad,
    17780988614441753110ULL,
    17294606533189464509ULL,
    3449178001205003427ULL,
    8743565477689764097ULL,
    };

  Game banditkings{
    "banditkings.nes",
    RLE::Decompress({ 101, 0, 4, 2, 3, 3, 2, 1, 50, 0, }),
    kEveryGameUponLoad,
    17831801454501511911ULL,
    5379627193232254395ULL,
    8713712655585395193ULL,
    11782439179331509265ULL,
    };

  // MMC5 test
  Game castlevania3{
    "castlevania3.nes",
    RLE::Decompress({ 101, 0, 4, 2, 3, 3, 2, 1, 50, 0, }),
    kEveryGameUponLoad,
    14818299322749207898ULL,
    8640140690401464515ULL,
    5263006926096009458ULL,
    8020098881039396417ULL,
    };

  Game escape{
    "escape.nes",
    RLE::Decompress({
      49, 0, 3, 8, 68, 0, 3, 8, 120, 0, 22, 128, 86, 0, 27, 128, 16, 129, 
      12, 128, 11, 130, 11, 128, 1, 0, 13, 64, 1, 0, 8, 128, 11, 129, 9,
      128, 9, 129, 14, 128, 2, 0, 8, 64, 0, 0, 2, 128, 2, 0, 12, 130, 128,
      0, 128, 0, 128, 0, 27, 0, 27, 128, 23, 130, 12, 128, 8, 0, 4, 128, 21,
      129, 11, 64, 14, 128, 16, 130, 23, 128, 16, 64, 2, 0, 8, 128, 24, 130,
      13, 128, 25, 2, 128, 0, 128, 0, 128, 0, 2, 0, 28, 128, 0, 0}),
    kEveryGameUponLoad,
    6838541238215755706ULL,
    6819303093664748341ULL,
    5472225341269592085ULL,
    8472434954456589132ULL,
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
      kEveryGameUponLoad,
      0x38cff7186cda146fULL,
      1841694725427045113ULL,
      14673076006826236492ULL,
      17726519025766227181ULL,
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
      kEveryGameUponLoad,
      187992912212093401ULL,
      6695545142227306073ULL,
      9151232040160770956ULL,
      7043606518024981793ULL,
      };

  Game arkanoid{
    "arkanoid.nes",
    RLE::Decompress({
      86, 0, 0, 8, 128, 0, 128, 0, 128, 0, 128, 0, 90, 0, 4, 128, 85, 0, 4, 1,
      39, 0, 4, 128, 17, 0, 5, 128, 20, 0, 4, 64, 9, 0, 5, 64, 4, 0, 14, 64,
      10, 0, 5, 64, 4, 0, 5, 64, 21, 0, 5, 128, 5, 0, 3, 128, 8, 0, 3, 128,
      10, 0, 4, 128, 9, 0, 4, 128, 4, 0, 30, 128, 1, 0, 32, 64, 15, 0, 13,
      128, 0, 0, 10, 64, 10, 0, 7, 64, 0, 0, 5, 128, 3, 0, 6, 64, 6, 0, 3,
      128, 9, 0, 4, 64, 15, 0, 5, 128, 3, 0, 12, 64, 1, 0, 22, 128, 4, 0, 3,
      64, 20, 0, 8, 64, 1, 0, 3, 128, 9, 0, 4, 64, 18, 0, 19, 128, 7, 0, 2,
      64, 11, 0, 3, 128, 10, 0, 2, 128, 8, 0, 4, 128, 22, 0, 6, 128, 0, 0, 31,
      64, 2, 0, 4, 128, 26, 0, 32, 128, 0, 0, 8, 64, 6, 0, 6, 64, 20, 0, 19,
      64, 4, 0, 4, 64, 8, 0, 3, 64, 3, 0, 7, 128, 6, 0, 5, 128, 3, 0, 4, 128,
      8, 0, 3, 128, 39, 0, 22, 128, 9, 0, 7, 64, 39, 0, 18, 64, 10, 0, 23,
      128, 14, 0, 26, 64, 12, 0, 10, 128, 14, 0, 7, 64, 96, 0, 5, 128, 20, 0,
      6, 64, 3, 0, 3, 64, 9, 0, 4, 128, 7, 0, 5, 128, 3, 0, 4, 128, 14, 0, 4,
      128, 27, 0, 10, 128, 32, 0, 54, 64, 0, 0, 23, 128, 11, 0, 7, 64, 17, 0,
      4, 128, 57, 0, 3, 128, 20, 0, 6, 64, 6, 0, 5, 64, 2, 0, 5, 64, 7, 0, 14,
      128, 2, 0, 22, 128, 7, 0, 22, 64, 3, 0, 8, 64, 7, 0, 16, 128, 0, 0, 37,
      64, 8, 0, 38, 128, 38, 0, 15, 64, 17, 0, 17, 128, 21, 0, 2, 64, 7, 0, 7,
      64, 5, 0, 2, 64, 5, 0, 4, 64, 4, 0, 3, 64, 41, 0, 17, 128, 2, 0, 7, 128,
      9, 0, 0, 1, 4, 65, 3, 64, 6, 65, 5, 64, 5, 65, 5, 64, 6, 65, 0, 64, 1,
      0, 5, 1, 3, 0, 3, 1, 1, 129, 1, 128, 0, 0, 5, 1, 0, 0, 1, 128, 5, 129,
      1, 128, 5, 129, 2, 128, 4, 129, 130, 1, 0, 64, 5, 65, 2, 64, 1, 65, 0,
      1, 2, 129, 2, 128, 5, 129, 2, 128, 6, 129, 9, 128, 6, 65, 9, 64, 4, 65,
      0, 1, 2, 0, 6, 1, 2, 0, 0, 64, 6, 65, 0, 64, 1, 0, 6, 1, 0, 0, 2, 64, 2,
      65, 2, 1, 1, 0, 0, 64, 4, 65, 129, 1, 0, 8, 128, 6, 129, 2, 128, 5, 129,
      1, 128, 4, 129, 0, 1, 3, 0, 2, 1, 2, 129, 2, 128, 1, 0, 0, 64, 5, 65, 3,
      64, 5, 65, 2, 64, 5, 65, 2, 64, 13, 65, 0, 64, 2, 0, 19, 128, 5, 129, 2,
      128, 5, 129, 0, 128, 3, 0, 3, 1, 3, 65, 6, 64, 16, 0, 0, 1, 4, 65, 0, 1,
      3, 0, 6, 1, 3, 128, 5, 129, 3, 128, 2, 129, 0, 1, 1, 65, 5, 64, 7, 65,
      1, 64, 5, 65, 3, 64, 4, 65, 1, 64, 5, 65, 4, 64, 0, 65, 1, 1, 2, 129, 4,
      128, 4, 129, 2, 128, 4, 129, 2, 128, 4, 129, 2, 128, 4, 129, 3, 128, 5,
      129, 2, 128, 0, 129, 4, 1, 2, 0, 4, 1, 2, 0, 4, 1, 1, 0, 1, 64, 5, 65,
      2, 64, 5, 65, 21, 64, 1, 0, 28, 128, 5, 129, 2, 128, 4, 129, 0, 1, 2, 0,
      4, 1, 2, 0, 4, 1, 2, 0, 3, 1, 2, 0, 4, 1, 2, 0, 3, 1, 2, 0, 4, 65, 1,
      64, 5, 65, 6, 64, 0, 0, 17, 128, 1, 0, 7, 1, 2, 0, 4, 1, 3, 0, 4, 65,
      31, 64, 0, 0, 5, 1, 0, 65, 5, 64, 4, 65, 0, 64, 2, 0, 4, 1, 2, 0, 4, 1,
      1, 0, 0, 128, 4, 129, 2, 0, 4, 1, 0, 0, 1, 64, 3, 65, 0, 1, 2, 0, 4, 1,
      2, 0, 4, 1, 2, 0, 5, 1, 1, 0, 4, 1, 2, 0, 4, 1, 2, 0, 3, 1, 3, 0, 3, 1,
      2, 0, 3, 1, 2, 0, 3, 1, 2, 0, 4, 1, 2, 0, 3, 1, 2, 0, 4, 1, 1, 0, 5, 1,
      3, 0, 5, 1, 0, 129, 21, 128, 128, 0, 128, 0, 41, 0, 12, 128, 15, 0, 3,
      128, 20, 0, 2, 64, 7, 0, 2, 64, 13, 0, 5, 1, 17, 0, 4, 128, 8, 0, 3,
      128, 24, 0, 5, 64, 13, 0, 5, 64, 3, 0, 6, 64, 2, 0, 5, 64, 4, 0, 5, 64,
      28, 0, 12, 128, 9, 0, 6, 128, 3, 0, 5, 128, 128, 0, 26, 0, 6, 64, 47, 0,
      4, 64, 63, 0, 2, 128, 14, 0, 30, 64, 9, 0, 17, 128, 4, 0, 7, 128, 24, 0,
      29, 64, 3, 0, 41, 128, 22, 0, 7, 128, 38, 0, }),
      kEveryGameUponLoad,
      17404343783895927036ULL,
      18130621035109203977ULL,
      8087545054192083934ULL,
      13007242309738173365ULL,
      };

  // XXX Uses battery-backed NVROM. Do something more hygienic than simply
  // unlinking ".sav" before the test.
  Game kirby{
    "kirby.nes",
      RLE::Decompress({
      101, 0, 4, 2, 3, 3, 2, 1, 13, 0, 5, 4, 6, 0, 5, 8, 69, 0, 5, 8, 39, 0,
      6, 8, 56, 0, 5, 8, 112, 0, 6, 8, 94, 0, 8, 64, 9, 0, 1, 2, 4, 130, 2,
      128, 0, 0, 10, 64, 3, 0, 8, 64, 1, 0, 7, 128, 0, 0, 6, 64, 1, 0, 3, 128,
      30, 0, 11, 64, 9, 0, 8, 16, 8, 0, 7, 2, 72, 0, 13, 128, 2, 130, 7, 2,
      20, 0, 2, 128, 11, 132, 9, 128, 6, 130, 5, 128, 0, 0, 5, 1, 2, 129, 9,
      128, 9, 0, 10, 128, 24, 129, 10, 128, 16, 130, 99, 128, 20, 129, 3, 1,
      1, 3, 58, 2, 11, 0, 31, 32, 0, 160, 44, 128, 5, 0, 53, 2, 12, 0, 9, 1,
      42, 2, 5, 0, 22, 128, 24, 130, 75, 128, 56, 130, 19, 128, 47, 130, 1,
      128, 31, 130, 0, 128, 5, 0, 8, 32, 2, 0, 67, 128, 4, 129, 2, 131, 33,
      130, 25, 128, 4, 129, 4, 131, 66, 130, 41, 128, 17, 129, 8, 128, 66,
      130, 4, 128, 4, 0, 14, 1, 4, 3, 23, 2, 8, 130, 27, 128, 31, 130, 6, 128,
      6, 129, 2, 128, 7, 129, 1, 128, 6, 129, 2, 128, 33, 129, 1, 128, 1, 144,
      13, 16, 10, 17, 2, 16, 6, 17, 3, 16, 7, 17, 1, 16, 4, 144, 19, 128, 7,
      129, 13, 128, 7, 130, 44, 128, 5, 129, 129, 1, 3, 37, 2, 12, 0, 72, 128,
      20, 0, 54, 16, 3, 0, 61, 128, 96, 130, 0, 2, 1, 0, 26, 32, 2, 160, 29,
      128, 12, 129, 2, 131, 29, 130, 23, 128, 33, 144, 37, 128, 9, 130, 55,
      128, 12, 0, 44, 2, 0, 130, 2, 128, 73, 130, 0, 131, 57, 129, 19, 131,
      60, 129, 12, 128, 18, 130, 26, 146, 5, 144, 6, 128, 37, 144, 2, 128, 6,
      144, 19, 128, 7, 130, 40, 128, 2, 130, 38, 2, 1, 34, 29, 32, 52, 128,
      34, 130, 54, 128, 13, 144, 24, 128, 8, 144, 2, 128, 9, 144, 2, 128, 11,
      130, 14, 128, 9, 144, 4, 128, 8, 144, 3, 128, 6, 144, 3, 128, 9, 144,
      41, 128, 7, 130, 8, 144, 9, 128, 10, 144, 34, 128, 4, 130, 57, 128, 4,
      130, 37, 2, 1, 34, 14, 32, 2, 160, 57, 128, 7, 144, 10, 128, 9, 144, 38,
      128, 7, 130, 43, 128, 14, 0, 16, 64, 0, 80, 13, 16, 47, 0, 103, 128, 10,
      144, 2, 128, 39, 130, 2, 128, 1, 0, 39, 2, 0, 130, 128, 128, 9, 128, 3,
      130, 59, 2, 21, 0, 44, 32, 5, 0, 48, 2, 3, 0, 68, 128, 13, 144, 2, 128,
      8, 144, 3, 128, 8, 129, 58, 128, 3, 160, 24, 32, 20, 160, 4, 128, 0,
      160, 20, 32, 5, 160, 12, 128, 2, 160, 8, 32, 9, 96, 9, 98, 7, 96, 2, 64,
      4, 0, 35, 128, 29, 144, 3, 128, 8, 144, 3, 128, 9, 144, 2, 128, 26, 144,
      2, 128, 6, 144, 1, 146, 4, 130, 1, 2, 26, 0, 1, 18, 6, 146, 9, 144, 2,
      128, 12, 0, 4, 2, 7, 130, 26, 128, 1, 130, 38, 2, 3, 130, 22, 128, 4,
      160, 18, 32, 2, 160, 80, 128, 7, 0, }),
      kEveryGameUponLoad,
      5937014762881028957ULL,
      10450299151185393612ULL,
      10437697934907677179ULL,
      15120013139071261080ULL,
      };

  const int64 start_us = TimeUsec();

  TRACE_DISABLE();

  Collage collage(modulus == 1 ? "" : StringPrintf("%d.", my_index));
  auto RunGameToCollage = [&collage, write_collage](const Game &game) {
    SerialResult sr = RunGameSerially(game);
    if (write_collage) {
      if (!sr.final_image.empty()) {
	collage.Push(sr.final_image);
      }
    }
    return sr;
  };

  TRACE_ENABLE();

  // Only run the intro tests for the first index in
  // sharded comprehensive mode.
  if (!MAKE_COMPREHENSIVE && my_index == 0) { 
    RunGameToCollage(dw4);

    RunGameToCollage(karate);
    RunGameToCollage(mario);
    RunGameToCollage(arkanoid);
    RunGameToCollage(escape);
    RunGameToCollage(skull);
    RunGameToCollage(escape);

    RunGameToCollage(ubasketball);
    RunGameToCollage(castlevania3);
    RunGameToCollage(banditkings);
    RunGameToCollage(kirby);
  }
 
  if (write_collage)
    collage.Flush();

  if (COMPREHENSIVE) {
    printf("Now COMPREHENSIVE tests.\n");
    vector<string> romlines = ReadFileToLines(romdir + "roms.txt");
    const string id = 
      (modulus == 1) ? "" : StringPrintf("(%d|%d) ", my_index, modulus);
    // We write this each time we run the comprehensive test because
    // it's so expensive anyway.
    output_file = output_file.empty() ?
      StringPrintf("comprehensive-%d-of-%d.txt",
		   my_index, modulus) : output_file;
    
    FILE *out = fopen(output_file.c_str(), "wb");
    CHECK(out != nullptr) << "Unable to open file " << output_file;
    for (int line_num = 0; line_num < romlines.size(); line_num++) {
      if (line_num % modulus != my_index) continue;
      string line = romlines[line_num];
      string a = Chop(line);
      string b = Chop(line);
      string c = Chop(line);
      string d = Chop(line);
      string filename = LoseWhiteL(line);

      if (!filename.empty()) {
        uint64 after_inputs, after_random,
	  image_after_inputs, image_after_random;
        stringstream(a) >> after_inputs;
        stringstream(b) >> after_random;
	stringstream(c) >> image_after_inputs;
	stringstream(d) >> image_after_random;
        Game game{
          romdir + filename,
            RLE::Decompress({ 101, 0, 4, 2, 3, 3, 2, 1, 50, 0, }),
            kEveryGameUponLoad,
            after_inputs,
            after_random,
	    image_after_inputs,
	    image_after_random,
            };
        const SerialResult sr = RunGameToCollage(game);
        fprintf(out, "%llu %llu %llu %llu %s\n", 
		sr.after_inputs, sr.after_random,
		sr.image_after_inputs, sr.image_after_random,
                filename.c_str());
        fflush(out);
        fprintf(stderr, "%sDid %d/%d = %.1f%%.\n",
		id.c_str(),
                line_num + 1, (int)romlines.size(),
                (line_num + 1) * 100. / romlines.size());
	// In this case we've already aborted (unless
	// MAKE_COMPREHENSIVE is set).
	if (sr.after_inputs != after_inputs ||
	    sr.after_random != after_random ||
	    sr.image_after_inputs != image_after_inputs ||
	    sr.image_after_random != image_after_random) {
	  fprintf(stderr, "(Note, didn't match last time: %s)\n",
		  filename.c_str());
	}
      }
    }
    fclose(out);
    if (write_collage) {
      collage.Flush();
    }
  }

  const int64 end_us = TimeUsec();
  const int64 elapsed_us = end_us - start_us;
  printf("Took %.2f ms\n", elapsed_us / 1000.0);

  return 0;
}
