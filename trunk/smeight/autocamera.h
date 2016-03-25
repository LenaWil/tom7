
#ifndef __AUTOCAMERA_H
#define __AUTOCAMERA_H

#include "smeight.h"

#include <memory>
#include <string>
#include <vector>

#include "../fceulib/emulator.h"
#include "../fceulib/simplefm2.h"

#include "../cc-lib/threadutil.h"
#include "../fceulib/ppu.h"

// Tries to automatically determine the camera, which is the
// set of memory locations that determine the player's position
// on the screen (x, y) and angle (a). It also chooses between
// two viewtypes, TOP (e.g. Zelda) and SIDE (e.g. Mario).
//
// Things to think about:
//  - A game like Gradius may look like "TOP" simply because
//    up and down work, and there's no gravity. Might need
//    a third view type for this? PPU scrolling may be the
//    right way to distinguish.
struct AutoCamera {
  // Since emulator startup is a little expensive, this keeps
  // around an emulator instance (pass the cartridge filename).
  explicit AutoCamera(const string &game) {
    emu1.reset(Emulator::Create(game));
    emu2.reset(Emulator::Create(game));
    emu3.reset(Emulator::Create(game));
  }

  // TODO: Make the search procedure use multiple threads.
  //
  // All of this is predicated on the idea that there should
  // be some sprite on screen that corresponds to the player
  // (obviously not all games obey this idea, but it's even
  // true for Nintendo Tetris even though they could have just
  // used the PPU BG). Furthermore, we assume that this sprite
  // uses a consistent slot (of the 64 sprite indices):
  //   - This seems like it'd be a reasonable developement
  //     practice, since most games are going to have lots of
  //     special cases for the player.
  //   - The player is usually made of multiple sprites, and
  //     it's likely that when the player is flipped horizontally
  //     or vertically, the sprite slots may switch. Have to
  //     either fuse sprites, allow slop, or relax this assumption.
  //   - Most games are going to use OAM DMA to write all sprites
  //     at once from main memory. If that's true, there will also
  //     be a clearly corresponding memory location for the player's
  //     position in RAM. We could intercept the OAMDMA address to
  //     find this. Allegedly, some games cycle through destination
  //     addresses to alleviate sprite priority conflicts (rotating
  //     instead causes them to flicker).
  //
  // First step is to find a sprite that corresponds to the player.
  // We assume the player is in some "general position" (i.e., not
  // standing against a wall, or dead). Note that in games that
  // scroll, this "wall" could actually just be the edge of the scroll
  // window, beyond which the screen scrolls rather than the player's
  // sprite moving, so this is important. (We could artificially try
  // to get in general position by repeating the search after
  // pressing left for a little bit to get away from a wall to our
  // right, etc.) Then we send left and right controller signals
  // to try to find a sprite whose x position is changing in response
  // to our controls. Since many games model the player velocity,
  // pressing left may not immediately move left. So, we iteratively
  // try left/right for one frame, two frames, three frames, etc.

  // Sprite that may be under control of the player.
  struct XSprite {
    // Index of the sprite that this appears to be.
    int sprite_idx;
    // If true, then sprite location lags the memory location
    // by one frame (this seems typical).
    bool oldmem;
    // Memory locations that had the same x value as the sprite,
    // perhaps lagged by a frame.
    vector<int> xmems;
  };

  // Returns a vector of sprite indices that meet the criteria.
  vector<XSprite> GetXSprite(const vector<uint8> &uncompressed_state,
			     int *num_frames);
  
  std::unique_ptr<Emulator> emu1, emu2, emu3;
};

#endif
