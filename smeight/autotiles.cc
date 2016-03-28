
#include "autotiles.h"

#include "../fceulib/emulator.h"
#include "../fceulib/cart.h"
#include "../fceulib/ppu.h"

#include "autocamera.h"

// These are NES constants.
static constexpr int TILESW = 32;
static constexpr int TILESH = 30;

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

vector<AutoTiles::Tile> AutoTiles::
GetTileInfo(Emulator *emu,
	    bool is_top,
	    const vector<AutoCamera::XYSprite> &cams) {
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

  struct Experiment {
    // Big tile coordinates.
    int x;
    int y;
    uint32 tileval;
  };
  
  vector<Experiment> experiments;

  // Fill in all the tiles.
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
	experiments.push_back(Experiment{x, y, tileval});
	// Should come back and fill this one in, but mark it
	// as unknown since that is its current status.
	ret[idx].solidity = UNKNOWN;
      } else {
	ret[idx].solidity = it->second ? SOLID : OPEN;
      }
    }
  }

  return ret;
}
