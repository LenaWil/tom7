
#include "autocamera.h"

#include "../fceulib/emulator.h"
#include "../fceulib/simplefm2.h"

#include "../cc-lib/threadutil.h"
#include "../fceulib/ppu.h"


bool AutoCamera::GetPlayerSprite(const vector<uint8> &start, int *sprite_idx) {

  // OAM is Object Attribute Memory, which is sprite data.
  auto OAM = [](Emulator *emu) {
    const PPU *ppu = emu->GetFC()->ppu;
    vector<uint8> oam;
    oam.resize(256);
    memcpy(oam.data(), ppu->SPRAM, 256);
    return oam;
  };

  emu1->LoadUncompressed(start);
  emu2->LoadUncompressed(start);
  emu3->LoadUncompressed(start);
  
  for (int frames = 1; frames < 45; frames++) {
    // Generate three sprite vectors, one where we hold only L for
    // n frames, one where we press nothing, and one where we hold
    // only R for n frames.
    emu1->Step(INPUT_L, 0);
    // vector<uint8> left = OAM(emu1.get());
    const uint8 *left = emu1->GetFC()->ppu->SPRAM;
    
    emu2->Step(0, 0);
    // vector<uint8> none = OAM(emu2.get());
    const uint8 *none = emu2->GetFC()->ppu->SPRAM;

    emu3->Step(INPUT_R, 0);
    // vector<uint8> right = OAM(emu3.get());
    const uint8 *right = emu3->GetFC()->ppu->SPRAM;

    // Now, see if any sprite has the property we want, which is
    // that left_x < none_x < right_x.

    int found_sprite = -1;
    for (int s = 0; s < 64; s++) {
      const uint8 left_y = left[s * 4 + 0];
      const uint8 none_y = none[s * 4 + 0];
      const uint8 right_y = right[s * 4 + 0];
      // Skip sprites that are off screen; these can't be the
      // player. (Of course, we could have just fallen into a
      // pit. We mean they can't be the player if everything is
      // going correctly.)
      if (left_y >= 240 || none_y >= 240 || right_y >= 240) continue;
      // XXX also eliminate sprites that are in the first column or
      // whatever when the sprite clipping flags are set. It
      // wouldn't be that weird for some sprites to have values that
      // change, like if some engines only need K sprites and then
      // reserve bytes after that (that get incidentally DMA'd but
      // have fixed invalid sprite offsets) for other game facts.

      // XXX test that the y values are equal? That would be
      // the most robust, but of course isn't true when jumping or
      // falling, etc.
	
      const uint8 left_x = left[s * 4 + 3];
      const uint8 none_x = none[s * 4 + 3];
      const uint8 right_x = right[s * 4 + 3];
	
      if (left_x < none_x && none_x < right_x) {
	found_sprite = s;
	printf("[%d] Sprite %d is player! %d < %d < %d\n",
	       frames, s, left_x, none_x, right_x);
      }
    }
    if (found_sprite != -1) {
      *sprite_idx = found_sprite;
      return true;
    }
  }

  return false;
}
