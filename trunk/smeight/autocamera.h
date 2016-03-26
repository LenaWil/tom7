
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
  static constexpr int NUM_EMULATORS = 16;
  
  // Since emulator startup is a little expensive, this keeps
  // around an emulator instance (pass the cartridge filename).
  explicit AutoCamera(const string &game) {
    printf("Creating %d emulators for AutoCamera...\n", NUM_EMULATORS);
    for (int i = 0; i < NUM_EMULATORS; i++) {
      emus.push_back(Emulator::Create(game));
    }
  }

  ~AutoCamera() {
    for (Emulator *emu : emus) delete emu;
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
  struct XYSprite {
    // Index of the sprite that this appears to be.
    int sprite_idx;
    // If true, then sprite location lags the memory location
    // by one frame (this seems typical).
    bool oldmem;
    // Memory locations that had the same x value as the sprite,
    // perhaps lagged by a frame, along with the offset (mem[addr] +
    // offset = sprite_x). Always nonempty.
    vector<pair<uint16, int>> xmems;
    // Same, but for y coordinates.
    vector<pair<uint16, int>> ymems;
  };
  
  // Returns a vector of sprite indices that meet the criteria. Only
  // xmems will be filled in.
  vector<XYSprite> GetXSprites(const vector<uint8> &uncompressed_state,
			       int *num_frames);

  // Upgrade a set of sprites with only x coordinates to ones with
  // both x and y coordinates. 
  vector<XYSprite> FindYCoordinates(const vector<uint8> &uncompressed_state,
				    int x_num_frames,
				    const vector<XYSprite> &xsprites);

  // Must have x and y coordinates filled in, i.e. after FindYCoordinates.
  //
  // Filter memory locations for consequentiality. Some memory locations
  // are derived from others, perhaps without even reading their values.
  // This coarse check tries modifying the values at the addresses to
  // see if that even does anything. If resulting sprite data and memories
  // are the same as if we didn't modify them, then these can't be the
  // "real" representation of the player's location.
  //
  // Returns only sprites that still have both x and y memory candidates.
  // This can remove all sprites if we failed to find consequential
  // coordinates in RAM (for example, we may have found a screen position
  // that is derived from some "real" physical position by adding the
  // scroll offset?)
  vector<XYSprite> FilterForConsequentiality(
      const vector<uint8> &uncompressed_state,
      int x_num_frames,
      const vector<XYSprite> &xysprites);
  
#if 0  
  // Follow up GetXSprite for side-view games with gravity.
  vector<XYSprite> GetYSpriteGravity(const vector<uint8> &uncompressed_state,
				     int x_num_frames,
				     const vector<XSprite> &xsprites);
#endif

  vector<Emulator *> emus;
};

#endif
