
#include "autocamera.h"

#include "../fceulib/emulator.h"
#include "../fceulib/simplefm2.h"

#include "../cc-lib/threadutil.h"
#include "../fceulib/ppu.h"


#if 0
// OAM is Object Attribute Memory, which is sprite data.
static vector<uint8> OAM(Emulator *emu) {
  const PPU *ppu = emu->GetFC()->ppu;
  vector<uint8> oam;
  oam.resize(256);
  memcpy(oam.data(), ppu->SPRAM, 256);
  return oam;
};
#endif

vector<AutoCamera::XSprite> AutoCamera::GetXSprite(
    const vector<uint8> &start, int *num_frames) { 

  // Use three emulators. In emu1, we hold only L, in emu2,
  // we press nothing, in emu3, only R.
  emu1->LoadUncompressed(start);
  emu2->LoadUncompressed(start);
  emu3->LoadUncompressed(start);
  
  // "Old memory" from the previous frame. We use this because
  // it's common (universal?) for sprite memory to 
  vector<uint8> lomem = emu1->GetMemory();
  vector<uint8> nomem = emu2->GetMemory();
  vector<uint8> romem = emu3->GetMemory();

  // We look inreasingly deep until satisfying the constraints,
  // up to 45 frames.
  for (int frames = 1; frames < 45; frames++) {

    emu1->Step(INPUT_L, 0);
    const uint8 *left = emu1->GetFC()->ppu->SPRAM;
    
    emu2->Step(0, 0);
    const uint8 *none = emu2->GetFC()->ppu->SPRAM;

    emu3->Step(INPUT_R, 0);
    const uint8 *right = emu3->GetFC()->ppu->SPRAM;

    // Now, see if any sprite has the property we want, which is
    // that left_x < none_x < right_x.

    vector<uint8> lmem = emu1->GetMemory();
    vector<uint8> nmem = emu2->GetMemory();
    vector<uint8> rmem = emu3->GetMemory();
    
    vector<XSprite> ret;
    for (int s = 0; s < 64; s++) {
      const uint8 left_y = left[s * 4 + 0];
      const uint8 none_y = none[s * 4 + 0];
      const uint8 right_y = right[s * 4 + 0];
      // Skip sprites that are off screen; these can't be the
      // player. (Of course, we could have just fallen into a
      // pit. We mean they can't be the player if everything is
      // going correctly.)
      // We don't skip sprites that are clipped (in the left column)
      // even if the clip mask is set, because it seems normal to
      // allow the player to walk off the left edge of the screen.
      if (left_y >= 240 || none_y >= 240 || right_y >= 240) continue;

      // XXX test that the y values are equal? That would be the most
      // robust, but of course isn't true if we initiate autocamera
      // while jumping or falling, etc.

      const uint8 left_x = left[s * 4 + 3];
      const uint8 none_x = none[s * 4 + 3];
      const uint8 right_x = right[s * 4 + 3];
	
      if (left_x < none_x && none_x < right_x) {
	printf("[%d] Sprite %d could be player! %d < %d < %d\n",
	       frames, s, left_x, none_x, right_x);
	// Also insist that there is memory address for which
	// the sprite x value matches in all three branches.

	auto FindMems = [left_x, none_x, right_x](const vector<uint8> &lm,
						  const vector<uint8> &nm,
						  const vector<uint8> &rm) {
	  vector<int> mems;
	  for (int i = 0; i < lm.size(); i++) {
	    if (left_x == lm[i] && none_x == nm[i] && right_x == rm[i]) {
	      mems.push_back(i);
	    }
	  }
	  return mems;
	};

	vector<int> mems = FindMems(lmem, nmem, rmem);
	if (!mems.empty()) {
	  // XXX do ANY games work this way? See if we can simplify
	  // it away.
	  printf("[%d]    Good! Now mems:", frames);
	  for (int m : mems) printf(" %d", m);
	  printf("\n");
	  ret.push_back(XSprite{s, false, mems});
	  
	} else {
	  vector<int> omems = FindMems(lomem, nomem, romem);

	  if (!omems.empty()) {
	    printf("[%d]    Good! Old mems:", frames);
	    for (int m : omems) printf(" %d", m);
	    printf("\n");
	    ret.push_back(XSprite{s, true, omems});
	  }
	}
      }
    }

    if (!ret.empty()) {
      *num_frames = frames;
      return ret;
    }

    // Shift current memory to previous.
    lomem.swap(lmem);
    nomem.swap(nmem);
    romem.swap(rmem);
  }

  return {};
}
