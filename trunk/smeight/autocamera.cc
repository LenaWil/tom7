
#include "autocamera.h"

#include "../fceulib/emulator.h"
#include "../fceulib/simplefm2.h"

#include "../cc-lib/threadutil.h"
#include "../fceulib/ppu.h"

// OAM is Object Attribute Memory, which is sprite data.
static vector<uint8> OAM(Emulator *emu) {
  const PPU *ppu = emu->GetFC()->ppu;
  vector<uint8> oam;
  oam.resize(256);
  memcpy(oam.data(), ppu->SPRAM, 256);
  return oam;
};

vector<AutoCamera::XYSprite> AutoCamera::GetXSprites(
    const vector<uint8> &start, int *num_frames) { 

  Emulator *lemu = emus[0], *nemu = emus[1], *remu = emus[2];

  // Use three emulators. In lemu, we hold only L, in nemu,
  // we press nothing, in remu, only R.
  lemu->LoadUncompressed(start);
  nemu->LoadUncompressed(start);
  remu->LoadUncompressed(start);
  
  // "Old memory" from the previous frame. We use this because it's
  // common (universal?) for sprite memory to be copied early in the
  // frame and but then updated later, so that the sprite values lag
  // behind memory values by 1 frame.
  vector<uint8> lomem = lemu->GetMemory();
  vector<uint8> nomem = nemu->GetMemory();
  vector<uint8> romem = remu->GetMemory();

  // We look inreasingly deep until satisfying the constraints,
  // up to 45 frames.
  for (int frames = 1; frames < 45; frames++) {

    lemu->Step(INPUT_L, 0);
    const uint8 *left = lemu->GetFC()->ppu->SPRAM;
    
    nemu->Step(0, 0);
    const uint8 *none = nemu->GetFC()->ppu->SPRAM;

    remu->Step(INPUT_R, 0);
    const uint8 *right = remu->GetFC()->ppu->SPRAM;

    // Now, see if any sprite has the property we want, which is
    // that left_x < none_x < right_x.

    vector<uint8> lmem = lemu->GetMemory();
    vector<uint8> nmem = nemu->GetMemory();
    vector<uint8> rmem = remu->GetMemory();
    
    vector<XYSprite> ret;
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

      // XXX should take scroll into account when testing >, right?
      // But for the camera we want to know the memory locations that
      // yield screen position.
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
	if (false && !mems.empty()) {
	  // XXX do ANY games work this way? See if we can simplify
	  // it away. (This can cause false positives, too, in cases
	  // where we just "luck into" two consecutive frames with the
	  // same pixel values?)
	  printf("[%d]    Good! Now mems:", frames);
	  for (int m : mems) printf(" %d", m);
	  printf("\n");
	  ret.push_back(XYSprite{s, false, mems, {}});
	  
	} else {
	  vector<int> omems = FindMems(lomem, nomem, romem);

	  if (!omems.empty()) {
	    printf("[%d]    Good! Old mems:", frames);
	    for (int m : omems) printf(" %d", m);
	    printf("\n");
	    ret.push_back(XYSprite{s, true, omems, {}});
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

void AutoCamera::FindYCoordinates(const vector<uint8> &uncompressed_state,
				  int x_num_frames,
				  vector<XYSprite> *sprites) {

  // make parameter, or decide that this can always be assumed.
  const bool lagmem = true;
  
  // We're going to run a bunch of different experiments to get
  // our science data. The goal here is to have a number of memories
  // paired with sprite data, from which we can mine correlations.

  struct Science {
    // 2k of NES memory synced to the sprite data. This is from
    // the previous frame if sprite data are lagged.
    vector<uint8> mem;
    vector<uint8> oam;
  };

  vector<Science> sciences;
  static constexpr int NUM_SEQ = 12;
  const int SEQ_LEN = x_num_frames + 8;
  // Pre-allocate so that individual threads can save their data.
  sciences.resize(NUM_SEQ * SEQ_LEN);

  struct Stepper {
    Stepper(bool lagmem,
	    vector<Science> &sciences,
	    int SEQ_LEN,
	    Emulator *emu, int seq_num) :
      lagmem(lagmem),
      sciences(sciences), SEQ_LEN(SEQ_LEN),
      emu(emu), seq_num(seq_num) {
      prev_mem = emu->GetMemory();
    }

    void Step(uint8 input) {
      CHECK(offset < SEQ_LEN);
      emu->StepFull(input, 0);
      Science *science = &sciences[seq_num * SEQ_LEN + offset];
      vector<uint8> now_mem = emu->GetMemory();
      if (lagmem) {
	science->mem = prev_mem;
      } else {
	science->mem = now_mem;
      }

      science->oam = OAM(emu);
      // Shift memory to previous.
      prev_mem.swap(now_mem);
      
      offset++;
    }

    const bool lagmem;
    vector<Science> &sciences;
    const int SEQ_LEN;
    // Assumes exclusive access.
    Emulator *emu;
    const int seq_num;
    int offset = 0;
    vector<uint8> prev_mem;
  };
  
  auto OneSeq = [this, lagmem, &sciences, SEQ_LEN, &uncompressed_state,
		 x_num_frames](int seq) {
    Emulator *emu = emus[seq];
    emu->LoadUncompressed(uncompressed_state);
    Stepper stepper(lagmem, sciences, SEQ_LEN, emu, seq);

    switch (seq) {
    case 0:
      // Do nothing.
      for (int i = 0; i < SEQ_LEN; i++) stepper.Step(0);
      break;
    case 1:
      // Left only
      for (int i = 0; i < SEQ_LEN; i++) stepper.Step(INPUT_L);
      break;
    case 2:
      // Right only
      for (int i = 0; i < SEQ_LEN; i++) stepper.Step(INPUT_R);
      break;
    case 3:
      // Up only
      for (int i = 0; i < SEQ_LEN; i++) stepper.Step(INPUT_U);
      break;
    case 4:
      // Down only
      for (int i = 0; i < SEQ_LEN; i++) stepper.Step(INPUT_D);
      break;

    case 5:
      // A only
      for (int i = 0; i < SEQ_LEN; i++) stepper.Step(INPUT_A);
      break;

    case 6:
      // B only
      for (int i = 0; i < SEQ_LEN; i++) stepper.Step(INPUT_B);
      break;

    case 7:
      // Alternate A and nothing, 4 frame period
      for (int i = 0; i < SEQ_LEN; i++)
	stepper.Step((i >> 2) & 1 ? INPUT_A : 0);
      break;

    case 8:
      // Alternate A and nothing, 8 frame period, offset
      for (int i = 0; i < SEQ_LEN; i++)
	stepper.Step((i >> 3) & 1 ? 0 : INPUT_A);
      break;

    case 9:
      // Crazy 1
      for (int i = 0; i < SEQ_LEN; i++)
	stepper.Step(INPUT_L | INPUT_U | ((i >> 3) & 1 ? INPUT_A : INPUT_B));
      break;

    case 10:
      // Crazy 2
      for (int i = 0; i < SEQ_LEN; i++)
	stepper.Step(INPUT_R | INPUT_U | ((i >> 3) & 1 ? INPUT_B : INPUT_A));
      break;

    default:
    case 11:
      // Alternate up and down, left and right
      for (int i = 0; i < SEQ_LEN; i++)
	stepper.Step(((i >> 3) & 1 ? INPUT_L : INPUT_R) |
		     ((i >> 2) & 1 ? INPUT_U : INPUT_D));
      break;
    }
  };

  // PERF parallelize.
  UnParallelComp(NUM_SEQ, OneSeq, 4);

  // PERF Debug only -- make sure everything was filled in.
  for (const Science &s : sciences) {
    CHECK(s.mem.size() == 2048);
    CHECK(s.oam.size() == 256);
  }

  printf("Filtering on %d sciences (%.2f MB)...\n",
	 (int)sciences.size(),
	 (sciences.size() * (2048 + 256)) / (1024.0 * 1024.0));
  
  vector<XYSprite> ret;
  // Now whittle down x memory locations.
  for (const XYSprite &sprite : *sprites) {
    int s = sprite.sprite_idx;
    XYSprite newsprite;
    for (int xaddr : sprite.xmems) {
      // Check every science.
      for (const Science &science : sciences) {
	const uint8 mem_x = science.mem[xaddr];
	const uint8 sprite_x = science.oam[s * 4 + 3];
	if (mem_x != sprite_x) {
	  printf("Sprite %d xmem %d eliminated since "
		 "mem_x = %02x and sprite_x = %02x\n", s, xaddr,
		 mem_x, sprite_x);
	  goto fail_xaddr;
	}
      }

      // OK, keep it!
      newsprite.xmems.push_back(xaddr);
     
    fail_xaddr:;
    }
   
    if (!newsprite.xmems.empty()) {
      // Try y locations too...

      for (int yaddr = 0; yaddr < 2048; yaddr++) {
	bool eliminated = false;
	for (const Science &science : sciences) {
	  const uint8 mem_y = science.mem[yaddr];
	  const uint8 sprite_y = science.oam[s * 4 + 0];
	  if (mem_y != sprite_y) {
	    if (false && yaddr == 0x84) { // Known zelda y
	      printf("Sprite %d ymem %d eliminated since "
		     "mem_y = %02x and sprite_y = %02x\n", s, yaddr,
		     mem_y, sprite_y);
	    }
	    // goto fail_yaddr;
	    eliminated = true;
	  }
	}

	if (!eliminated)
	  newsprite.ymems.push_back(yaddr);

      fail_yaddr:;
      }

      if (!newsprite.ymems.empty()) {
	printf("Sprite %d has x candidates:", s);
	for (int xaddr : newsprite.xmems) printf(" %d", xaddr);
	printf("\n          and y candidates:");
	for (int yaddr : newsprite.ymems) printf(" %d", yaddr);
	printf("\n");
	newsprite.sprite_idx = s;
	newsprite.oldmem = lagmem;
	ret.push_back(newsprite);
      } else {
	printf("Sprite %d eliminted since there are no ymems left.\n", s);
      }
    } else {
      printf("Sprite %d eliminated since there are no xmems left.\n", s);
    }
  }
  
  sprites->swap(ret);
}


#if 0
vector<AutoCamera::XSprite> AutoCamera::GetXYSpriteGravity(
    const vector<uint8> &uncompressed_state,
    int x_num_frames,
    const vector<XSprite> &xsprites) {

  // We need some candidate sprites to do this.
  if (xsprites.empty()) return {};

  // We assume a side-scrolling game with gravity. This time,
  // we take sprites that appear to be under the control of the
  // player, and try to find their y coordinates in RAM (by value).
  // 
  // We then  ... move the player and drop him
  
  lemu->LoadUncompressed(start);
  nemu->LoadUncompressed(start);
  remu->LoadUncompressed(start);
  
}
#endif
