
#include "autotiles.h"

#include "../fceulib/emulator.h"
#include "../fceulib/cart.h"
#include "../fceulib/ppu.h"
#include "../fceulib/simplefm2.h"

#include "autocamera.h"

// These are NES constants.
static constexpr int TILESW = 32;
static constexpr int TILESH = 30;

using XYSprite = AutoCamera::XYSprite;

// FYI: This is not a good hash function at all.
static uint64 Checksum(const uint64 *data, int num_words) {
  uint64 a = 0x12345678ULL, b = ~0xABCDEFULL;
  for (uint64 i = 0; i < (uint64)num_words; i++) {
    const uint64 w = data[i];
    a *= 65537ULL;
    a ^= (w >> 32) << 27;
    a += i;
    b = (b >> 13) | (b << (64 - 13));
    b ^= w & 0xFFFFFF;
    b += 0xBEEFFACEDEADF00D;
    
    const uint64 t = a;
    a = b;
    b = t;
  }

  return a ^ b;
}

// Run f on (thread_id, i) for i in [0, num - 1]. thread_id is
// always in [0, max_concurrency - 1] and two concurrent f calls
// will always have distinct thread ids.
//
// This maybe could go in threadutil (it's based on something in
// there), but not clear if it's general purpose enough. Here we
// use thread ids to grab a thread-local emulator.
template<class F>
static void ParallelIdx(int num,
			const F &f,
			int max_concurrency) {
  max_concurrency = std::min(num, max_concurrency);
  // Need at least one thread for correctness.
  CHECK(max_concurrency >= 1);
  std::mutex index_m;
  int next_index = 0;

  std::vector<std::thread> threads;
  threads.reserve(max_concurrency);
  for (int thread_id = 0; thread_id < max_concurrency; thread_id++) {
    // Thread applies f repeatedly until there are no more indices.
    auto th = [&index_m, &next_index, num, &f, thread_id]() {
      for (;;) {
	index_m.lock();
	if (next_index == num) {
	  // All done. Don't increment counter so that other threads can
	  // notice this too.
	  index_m.unlock();
	  return;
	}
	int my_index = next_index++;
	index_m.unlock();

	// Do work, not holding mutex.
	(void)f(thread_id, my_index);
      }
    };

    threads.emplace_back(th);
  }
  // Now just wait for them all to finish.
  for (std::thread &t : threads) t.join();
}

// Drop-in serial replacement for debugging, etc.
template<class F>
static void UnParallelIdx(int num, const F &f, int max_concurrency_ignored) {
  for (int i = 0; i < num; i++) (void)f(0, i);
}

// static
uint64 AutoTiles::TilesCRC(const Emulator *emu) {
  const PPU *ppu = emu->GetFC()->ppu;
  const uint8 ppu_ctrl = ppu->PPU_values[0];
   
  // BG pattern table can be at 0 or 0x1000, depending on control bit.
  const uint32 bg_pat_addr = (ppu_ctrl & (1 << 4)) ? 0x1000 : 0x0000;
  const uint8 *vram = &emu->GetFC()->cart->
    VPage[bg_pat_addr >> 10][bg_pat_addr];

  // 256 tiles, each 16 bytes (8x8 bits + 8x8 bits for 2bpp color)
  static constexpr int NUM_BYTES = 256 * 16;
  static_assert(0 == NUM_BYTES % 8, "assuming we can use 64-bit words");
  static constexpr int NUM_64BIT = NUM_BYTES / 8;

  const uint64 *vram64 = (const uint64*)vram;
  return Checksum(vram64, NUM_64BIT);
}


// Check that we have left/right control of the sprite at the
// current frame. Return the number of frames we held before
// seeing a change to its x coordinate.
//
// XXX when walking left and right, consider forcing the y
// coordinate to be the same each time, for games with gravity.
static bool HaveLRControl(Emulator *emu,
			  const vector<uint8> &start,
			  const AngleRule &left_angle,
			  const AngleRule &right_angle,
			  int *nframes,
			  const XYSprite &sprite) {
  emu->LoadUncompressed(start);
  const uint8 *spram = emu->GetFC()->ppu->SPRAM;
  const uint8 startx = spram[sprite.sprite_idx * 4 + 3];
  const uint8 starty = spram[sprite.sprite_idx * 4 + 0];
  
  printf("Sprite %d starts at %02x/%02x.\n", sprite.sprite_idx,
	 startx, starty);

  // Could try braking the player first?
  uint8 *ram = emu->GetFC()->fceu->RAM;

  // XXX consider scroll pos!
  
  // Face right.
  // ram[right_angle.memory_location] = right_angle.value;
  // Try walking right.
  auto WalkRight = [emu, startx, &sprite]() {
    for (int i = 0; i < 12; i++) {
      emu->StepFull(INPUT_R, 0);
      const uint8 *spram = emu->GetFC()->ppu->SPRAM;
      const uint8 nowx = spram[sprite.sprite_idx * 4 + 3];
      if (nowx > startx + 1) { return i + 1; }
    }
    return 0;
  };

  const int walkright = WalkRight();

  if (!walkright) {
    printf("Can't walk right.\n");
    return false;
  }

  emu->LoadUncompressed(start);
  
  // Face left.
  // ram[left_angle.memory_location] = left_angle.value;
  // Try walking left.
  auto WalkLeft = [emu, startx, &sprite]() {
    for (int i = 0; i < 12; i++) {
      emu->StepFull(INPUT_L, 0);
      const uint8 *spram = emu->GetFC()->ppu->SPRAM;
      const uint8 nowx = spram[sprite.sprite_idx * 4 + 3];
      if (nowx < startx - 1) { return i + 1; }
    }
    return 0;
  };

  const int walkleft = WalkLeft();

  if (!walkleft) {
    printf("Can't walk left.\n");
    return false;
  }

  *nframes = max(walkleft, walkright);
  
  return true;
}

namespace {
struct Experiment {
  // Big tile coordinates.
  int x;
  int y;
  uint32 tileval;
  AutoTiles::Solidity result;
};
}

static void TestSolidity(Emulator *emu,
			 const vector<uint8> &savestate,
			 Experiment *expt,
			 const AngleRule &left_angle,
			 const AngleRule &right_angle,
			 const XYSprite &sprite,
			 int nframes) {
  emu->LoadUncompressed(savestate);

  // Ok, finally, a test of a single tile on-screen for solidity.
  // We've established that in the current emulator state the player
  // is able to move left and right by pressing INPUT_L and INPUT_R,
  // and assume that the sprite has consequential memory locations,
  // so we can warp it around.

  // There are lots of ways to do this, because clipping works
  // differently in different games. Should perhaps try several methods
  // and vote, but the simplest is to place the player (assume 16x16)
  // exactly adjacent to the tile, facing it, and try to walk into the
  // tile.

  // Complications! Walking to the left is easiest, because we can assume
  // more about the tile grid than sprites (so we put the sprite's 0 column
  // against the tile's right edge). But this is no good for the right
  // column of tiles on the screen, so we need to support both.

  const int tile_8x8x = expt->x << 1;
  const int tile_8x8y = expt->y << 1;
  // Upper-left corner (pixel) of this tile on the screen.
  const int tile_px = tile_8x8x << 3;
  const int tile_py = tile_8x8y << 3;

  // Want to be slightly outside the tile, since some games check the
  // collision as you first start to touch the tile (and push you
  // back?) rather than once you are inside it.
  const int next_column = tile_px + 16; // + 1;

  // We just fail the experiment for now. Good chance that this quadtile
  // is covered elsewhere on the screen, in fact.
  if (next_column >= 256)
    return;

  uint8 *ram = emu->GetFC()->fceu->RAM;
  uint8 *spram = emu->GetFC()->ppu->SPRAM;
  
  // Face left.
  // ram[left_angle.memory_location] = left_angle.value;

  // Place player at the desired location.
  // Might as well set the sprite location (?).
  // Would maybe be useful to set the oam dma src as well,
  // though it should probably get overwritten from the memory
  // location?
  // spram[sprite.sprite_idx * 4 + 3] = next_column;
  // spram[sprite.sprite_idx * 4 + 3] = tile_py;
  for (const pair<uint16, int> xaddr : sprite.xmems) {
    int offset_val = next_column - xaddr.second;
    // Can't do the experiment if the offset memory can't
    // place us in this location.
    if (offset_val < 0 || offset_val > 255)
      return;
    ram[xaddr.first] = offset_val;
  }

  for (const pair<uint16, int> yaddr : sprite.ymems) {
    int offset_val = tile_py; // - yaddr.second;
    if (offset_val < 0 || offset_val > 255)
      return;
    ram[yaddr.first] = offset_val;
  }

  // Now try walking left (establishes baseline).
  for (int i = 0; i < nframes; i++) {
    emu->StepFull(INPUT_L, 0);
  }

  const uint8 xmiddle = spram[sprite.sprite_idx * 4 + 3];

  // Now keep walking left to see if we can keep going.
  for (int i = 0; i < nframes; i++) {
    emu->StepFull(INPUT_L, 0);
  }

  
  if (spram[sprite.sprite_idx * 4 + 3] < xmiddle) {
    // printf("%d,%d Not solid! %2x < %2x ?< %02x\n", expt->x, expt->y,
    // spram[sprite.sprite_idx * 4 + 3], xmiddle, next_column);
    // SaveEmulatorImage(emu, StringPrintf("open-%d-%d.png", expt->x, expt->y));
    expt->result = AutoTiles::OPEN;
  } else {
    // printf("%d,%d Solid!\n", expt->x, expt->y);
    // SaveEmulatorImage(emu, StringPrintf("solid-%d-%d.png", expt->x, expt->y));
    expt->result = AutoTiles::SOLID;
  }
}

vector<AutoTiles::Tile> AutoTiles::
GetTileInfo(Emulator *emu,
	    const AngleRule &left_angle, const AngleRule &right_angle,
	    bool is_top,
	    const vector<XYSprite> &sprites) {
  PPU *ppu = emu->GetFC()->ppu;
  const uint8 *nametable = ppu->NTARAM;

  const uint32 xscroll = emu->GetXScroll();

  const int coarse_scroll_div8 = (xscroll & ~15) >> 3;

  Tileset *tileset = nullptr;
  {
    const uint64 crc = TilesCRC(emu);
    auto it = tilesets.find(crc);
    if (it == tilesets.end()) {
      printf("Allocating new tileset for %llu...\n", crc);
      tileset = new Tileset;
      tilesets[crc] = tileset;
    } else {
      tileset = it->second;
    }
  }
  
  
  vector<Tile> ret;
  ret.resize((TILESW >> 1) * (TILESH >> 1));
  
  vector<Experiment> experiments;

  // Fill in all the tiles, using existing knowledge of the tile quads
  // if we have them, else queueing up those experiments.
  for (int y = 0; y < (TILESH >> 1); y ++) {
    const int yy = y << 1;
    for (int x = 0; x < (TILESW >> 1); x ++) {
      const int xx = ((x << 1) + coarse_scroll_div8) % (TILESW * 2);

      uint32 tileval = 0;
      for (int sy = 0; sy < 2; sy++) {
	for (int sx = 0; sx < 2; sx++) {
	  int srctx = xx + sx;
	  int srcty = yy + sy;
	  tileval <<= 8;
	  tileval |=
	    (srctx & 32) ?
	    nametable[0x400 + srcty * TILESW + (srctx & 31)] :
	    nametable[srcty * TILESW + srctx];
	}
      }

      const int idx = y * (TILESW >> 1) + x;
      ret[idx].fourtiles = tileval;

      auto it = tileset->is_solid.find(tileval);
      if (it == tileset->is_solid.end()) {
	experiments.push_back(Experiment{x, y, tileval, UNKNOWN});
	// Should come back and fill this one in, but mark it
	// as unknown since that is its current status.
	ret[idx].solidity = UNKNOWN;
      } else {
	ret[idx].solidity = it->second ? SOLID : OPEN;
      }
    }
  }

  // Now, run experiments to test solidity, if necessary (and
  // possible).
  if (!experiments.empty() &&
      !sprites.empty() &&
      left_angle.Valid() && right_angle.Valid()) {
    printf("%d experiments to do.\n", (int)experiments.size());
    // Choose the 0th sprite arbitrarily.
    const XYSprite &sprite = sprites[0];

    uint8 *ram = emu->GetFC()->fceu->RAM;
    uint8 *spram = emu->GetFC()->ppu->SPRAM;
    int xloc = ram[sprite.xmems[0].first];
    int yloc = ram[sprite.ymems[0].first];
    int xsloc = spram[sprite.sprite_idx * 4 + 3];
    int ysloc = spram[sprite.sprite_idx * 4 + 0];
    printf("mem: %d,%d  spr: %d,%d\n", xloc, yloc, xsloc, ysloc);

    // if (xloc % 8 != 0) return ret;
    
    // First of all, we need to be in a state where we have
    // control of the player. If we're not, there's no
    // point in trying experiments.
    vector<uint8> save = emu->SaveUncompressed();

    
    int nframes;
    if (HaveLRControl(emus[0], save, left_angle, right_angle,
		      &nframes, sprite)) {
      printf("Have control in %d frames!\n", nframes);
      
      auto DoExperiment = [this, &experiments, &save,
			   &left_angle, &right_angle, &sprite,
			   nframes](int thread_id, int expt_idx) {
	// Run one experiment, in parallel.

	// XXX First test if this tileset has already been done?

	Emulator *emu = emus[thread_id];
	Experiment *expt = &experiments[expt_idx];
	TestSolidity(emu, save, expt,
		     left_angle, right_angle, sprite, nframes);
      };

      if (experiments.size() < 20) {
	UnParallelIdx(experiments.size(), DoExperiment, NUM_EMULATORS);
      } else {
	// PERF can use fewer emulators when fewer tiles...
	ParallelIdx(experiments.size(), DoExperiment, NUM_EMULATORS);
      }

      int num_solid = 0, num_open = 0;
      
      // Now promote the experiments into the cache.
      for (const Experiment &expt : experiments) {
	if (expt.result != UNKNOWN) {
	  const int idx = expt.y * (TILESW >> 1) + expt.x;
	  ret[idx].solidity = expt.result;
	  // There may be many results for the tile. Maybe get
	  // consensus?
	  // tileset->is_solid[expt.tileval] = expt.result == SOLID;
	  if (expt.result == SOLID) num_solid++;
	  else if (expt.result == OPEN) num_open++;
	}
      }

      // (If we remapped a bunch of tiles, write out an image.)
      if (experiments.size() > 120) {
	vector<uint8> rgba;
	rgba.resize((TILESW >> 1) * (TILESH >> 1) * 4);
	// XXX do!
      }

      printf("In this experiment, %d solid, %d open.\n",
	     num_solid, num_open);
      printf("mem: %d,%d  spr: %d,%d\n", xloc, yloc, xsloc, ysloc);
      
    } else {
      printf("Can't experiment; no control.\n");
    }
  }
  
  return ret;
}
