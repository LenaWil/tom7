
#include "autocamera.h"

#include <unordered_set>

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

static string AddrOffset(pair<uint16, int> p) {
  if (p.second > 0) {
    return StringPrintf("%04x+%d", p.first, p.second);
  } else if (p.second < 0) {
    return StringPrintf("%04x-%d", p.first, -p.second);
  } else {
    return StringPrintf("%04x", p.first);
  }
}

namespace {
struct InputGenerator {
  explicit InputGenerator(int id) : id(id) {}

  uint8 Next() {
    i++;
    switch (id) {
    case 0: return 0;
    case 1: return INPUT_L;
    case 2: return INPUT_R;
    case 3: return INPUT_U;
    case 4: return INPUT_D;
    case 5: return INPUT_A;
    case 6: return INPUT_B;
    case 7: return (i >> 2) & 1 ? INPUT_A : 0;
    case 8: return (i >> 3) & 1 ? 0 : INPUT_A;
    case 9: return INPUT_L | INPUT_U | ((i >> 3) & 1 ? INPUT_A : INPUT_B);
    case 10: return INPUT_R | INPUT_U | ((i >> 3) & 1 ? INPUT_B : INPUT_A);
    case 11: return ((i >> 3) & 1 ? INPUT_L : INPUT_R) |
	((i >> 2) & 1 ? INPUT_U : INPUT_D);
    default: {
      int x = id - 10;
      // In the general case, randomly combine some streams based on
      // input bits.
      uint8 out = 0;
      if (x & 1) out |= (i % 6 < 3) ? INPUT_L : 0;
      if (x & 2) out |= (i % 10 < 5) ? INPUT_R : 0;
      if (x & 4) out |= (i % 8 < 4) ? INPUT_U : 0;
      if (x & 8) out |= (i % 8 > 4) ? INPUT_D : 0;
      if (x & 16) out |= (i % 3 > 1) ? INPUT_A : 0;
      if (x & 32) out |= (i % 5 > 2) ? INPUT_B : 0;
      if (x & 64) out ^= INPUT_B;
      if (x & 128) out ^= INPUT_A;
      return out;
    }
    }
  }
  
  const int id;
  uint32 i = 0;
};
}

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

	// Maybe allow constant offsets here?
	auto FindMems = [left_x, none_x, right_x](const vector<uint8> &lm,
						  const vector<uint8> &nm,
						  const vector<uint8> &rm) {
	  vector<pair<uint16, int>> mems;
	  for (uint16 i = 0; i < lm.size(); i++) {
	    if (left_x == lm[i] && none_x == nm[i] && right_x == rm[i]) {
	      // Note: Always using offset of zero here.
	      mems.push_back({i, 0});
	    }
	  }
	  return mems;
	};

	vector<pair<uint16, int>> mems = FindMems(lmem, nmem, rmem);
	if (false && !mems.empty()) {
	  // XXX do ANY games work this way? See if we can simplify
	  // it away. (This can cause false positives, too, in cases
	  // where we just "luck into" two consecutive frames with the
	  // same pixel values?)
	  printf("[%d]    Good! Now mems:", frames);
	  for (pair<uint16, int> m : mems) printf(" %d", m.first);
	  printf("\n");
	  ret.push_back(XYSprite{s, false, mems, {}});
	  
	} else {
	  vector<pair<uint16, int>> omems = FindMems(lomem, nomem, romem);

	  if (!omems.empty()) {
	    printf("[%d]    Good! Old mems:", frames);
	    for (pair<uint16, int> m : omems) printf(" %d", m.first);
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

vector<AutoCamera::XYSprite> AutoCamera::FindYCoordinates(
    const vector<uint8> &uncompressed_state,
    int x_num_frames,
    const vector<XYSprite> &sprites) {

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
    InputGenerator gen{seq};
    for (int i = 0; i < SEQ_LEN; i++) stepper.Step(gen.Next());
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
  
  vector<XYSprite> withy;
  // Now whittle down x memory locations.
  for (const XYSprite &sprite : sprites) {
    int s = sprite.sprite_idx;
    XYSprite newsprite;
    for (const pair<uint16, int> xaddr : sprite.xmems) {
      // Check every science.
      for (const Science &science : sciences) {
	int mem_x = (int)science.mem[xaddr.first] + xaddr.second;
	int sprite_x = science.oam[s * 4 + 3];
	if (mem_x != sprite_x) {
	  printf("Sprite %d xmem %d eliminated since "
		 "mem_x+%d = %d and sprite_x = %d\n", s, xaddr.first,
		 xaddr.second, mem_x, sprite_x);
	  goto fail_xaddr;
	}
      }

      // OK, keep it!
      newsprite.xmems.push_back(xaddr);
     
    fail_xaddr:;
    }
   
    if (!newsprite.xmems.empty()) {
      // Try y locations too...

      for (uint16 yaddr = 0; yaddr < 2048; yaddr++) {
	// We're solving for offset such that mem[yaddr] + offset = sprite.
	// Offset may be signed. We don't have a candidate offset until
	// our first comparison.
	bool have_offset = false;
	int offset = 0;
	for (const Science &science : sciences) {
	  // Promote to integer from uint8 so that w can do signed
	  // comparison.
	  const int actual_mem_y = science.mem[yaddr];
	  const int sprite_y = science.oam[s * 4 + 0];

	  const int this_offset = sprite_y - actual_mem_y;
	  if (!have_offset) {
	    have_offset = true;
	    offset = this_offset;
	  }
	  
	  if (this_offset != offset) {
	    if (true && yaddr == 0x84) { // Known zelda y
	      printf("Sprite %d ymem %d (offset %d) eliminated since "
		     "mem_y = %02x and sprite_y = %02x (so offset %d)\n",
		     s, yaddr, offset,
		     actual_mem_y, sprite_y, this_offset);
	    }
	    goto fail_yaddr;
	  }
	}

	newsprite.ymems.push_back({yaddr, offset});

      fail_yaddr:;
      }

      if (!newsprite.ymems.empty()) {
	printf("Sprite %d has x candidates:", s);
	for (auto xaddr : newsprite.xmems)
	  printf(" %s", AddrOffset(xaddr).c_str());
	printf("\n          and y candidates:");
	for (auto yaddr : newsprite.ymems)
	  printf(" %s", AddrOffset(yaddr).c_str());
	printf("\n");
	newsprite.sprite_idx = s;
	newsprite.oldmem = lagmem;
	withy.push_back(newsprite);
      } else {
	printf("Sprite %d eliminted since there are no ymems left.\n", s);
      }
    } else {
      printf("Sprite %d eliminated since there are no xmems left.\n", s);
    }
  }
  
  vector<XYSprite> ret;
  // Next, filter memory locations that are just source data for
  // the OAMDMA copy. Because the DMA has to be from a source address
  // of the form 0x##00-0x##FF.
  // (Note, we could actually intercept the OAMDMA write in the emulator;
  // it's not hard. But maybe prettier to do it this way?)

  for (const XYSprite &sprite : withy) {
    XYSprite newsprite;
    auto FilterByOAM = [&sciences, &sprite](
	const vector<pair<uint16, int>> &addrs,
	int oam_byte,
	vector<pair<uint16, int>> *out) {

      // Test a single addr.
      auto OK = [&sciences, &sprite, oam_byte](pair<uint16, int> addr) {
	// Wouldn't make sense for it to have an offset; OAMDMA doesn't
	// modify anything.
	if (addr.second != 0) return true;
	// Quick filter: The address would have to match the corresponding
	// coordinate in sprite data. Also, computes the DMA root address,
	// which we need for the full check anyway.
	uint16 dma_root = addr.first & ~0xFF;
	if (addr.first != dma_root + sprite.sprite_idx * 4 + oam_byte) {
	  // This coordinate of this sprite could not have come from
	  // a DMA involving this address.
	  return true;
	}

	printf("%s-coord at addr %04x for sprite %d may be from DMA "
	       "starting at %04x?\n", oam_byte ? "x" : "y",
	       addr.first, sprite.sprite_idx, dma_root);

	// If it aligns with potential DMA, check if sprite data
	// matches a DMA at that address. If so, reject.
	for (const Science &science : sciences) {
	  for (int i = 0; i < 256; i++) {
	    // PERF memcmp
	    if (science.mem[dma_root + i] != science.oam[i]) {
	      printf("But mem[%04x] = %2x whereas oam[%2x] = %2x.\n",
		     dma_root + i, science.mem[dma_root + i],
		     i, science.oam[i]);
	      return true;
	    }
	  }
	}

	// All science is consistent.
	printf("Rejected %s-coord for sprite %d at %04x because it "
	       "is consistent with just being DMA.\n",
	       oam_byte ? "x" : "y", sprite.sprite_idx, addr.first);
	return false;
      };

      for (const auto addr : addrs)
	if (OK(addr))
	  out->push_back(addr);
    };

    FilterByOAM(sprite.xmems, 3, &newsprite.xmems);
    FilterByOAM(sprite.ymems, 0, &newsprite.ymems);

    if (!newsprite.xmems.empty() && !newsprite.ymems.empty()) {
      printf("Sprite %d has x candidates:", sprite.sprite_idx);
      for (auto xaddr : newsprite.xmems)
	printf(" %s", AddrOffset(xaddr).c_str());
      printf("\n          and y candidates:");
      for (auto yaddr : newsprite.ymems)
	printf(" %s", AddrOffset(yaddr).c_str());
      printf("\n");

      newsprite.sprite_idx = sprite.sprite_idx;
      newsprite.oldmem = lagmem;
      ret.push_back(newsprite);
    }
  }
  
  return ret;
}

vector<AutoCamera::XYSprite> AutoCamera::FilterForCausality(
    const vector<uint8> &uncompressed_state,
    int x_num_frames,
    const vector<XYSprite> &sprites) {

  // To do this, we'll pick a memory location m and try to
  // eliminate it because it is "caused" by other memory
  // locations. We'll do that by modifying (only) it, then
  // emulating a frame and seeing that it does not have the
  // modified value (i.e., that its value is the same as
  // if we did not modify it).
  //
  // This procedure can eliminate a sprite, by proving that its
  // position is actually derived from other memory locations.

  // To start, we want to generate a bunch of emulator states
  // so that we can run the experiments above in a bunch of
  // different scenarios.

  static constexpr int NUM_EXPERIMENTS = NUM_EMULATORS;
  static_assert(NUM_EXPERIMENTS <= NUM_EMULATORS, "assumed exclusive emu");
  
  vector<vector<uint8>> savestates;
  savestates.resize(NUM_EXPERIMENTS);
  
  auto OneExperiment =
    [this, &uncompressed_state, x_num_frames, &savestates](int id) {
    Emulator *emu = emus[id];
    emu->LoadUncompressed(uncompressed_state);
    const int nframes = x_num_frames + 12;
    InputGenerator gen{id};
    for (int i = 0; i < nframes; i++) emu->StepFull(gen.Next(), 0);
    emu->SaveUncompressed(&savestates[id]);
  };
  
  UnParallelComp(NUM_EXPERIMENTS, OneExperiment, 4);

  vector<bool> known_consequential(2048, false);
  vector<bool> known_inconsequential(2048, false);
  
  // PERF this could be parallelized..
  // Now, pick candidate memory locations.
  for (const XYSprite &sprite : sprites) {
    auto Consequential = [this, &savestates, &sprite,
			  &known_consequential, &known_inconsequential](
	pair<uint16, int> addr) {
      if (known_consequential[addr.first]) {
	printf("Already decided %04x is consequential.\n", addr.first);
	return true;
      }
      if (known_inconsequential[addr.first]) {
	printf("Already decided %04x is inconsequential.\n", addr.first);
	return false;
      }
      for (const vector<uint8> &save : savestates) {
	Emulator *emu = emus[0];
	// Perform the experiment.
	
	// First, the control:
	emu->LoadUncompressed(save);
	// Run with no input. The stimulus is the changing of
	// the memory location.
	emu->StepFull(0, 0);
	emu->StepFull(0, 0);

	// PERF The control OAM will be the same every time;
	// compute it when computing savestates.
	vector<uint8> ctrl_oam = OAM(emu);
	vector<uint8> ctrl_mem = emu->GetMemory();
	
	// Same, but modifying the memory location:
	emu->LoadUncompressed(save);
	// How to pick the value to set? We should avoid
	// putting it off screen, or generally near the edges
	// of the screen, because that could trigger issues.
	uint8 *ram = emu->GetFC()->fceu->RAM;
	const uint8 oldval = ram[addr.first];
	const uint8 newval = (oldval <= 128) ? oldval + 64 : oldval - 64;

	// Note this bypasses any RAM hooks, but I think that's
	// the right thing to do.
	ram[addr.first] = newval;
	
	emu->StepFull(0, 0);
	emu->StepFull(0, 0);
	vector<uint8> expt_oam = OAM(emu);
	vector<uint8> expt_mem = emu->GetMemory();

	if (ctrl_oam != expt_oam ||
	    ctrl_mem != expt_mem) {
	  known_consequential[addr.first] = true;
	  return true;
	}
      }
      known_inconsequential[addr.first] = true;
      return false;
    };
    
    for (pair<uint16, int> xaddr : sprite.xmems) {
      if (!Consequential(xaddr)) {
	printf("sprite %d: x address %s is inconsequential\n",
	       sprite.sprite_idx, AddrOffset(xaddr).c_str());
      }
    }
      
    for (pair<uint16, int> yaddr : sprite.ymems) {
      if (!Consequential(yaddr)) {
	printf("sprite %d: y address %s is inconsequential\n",
	       sprite.sprite_idx, AddrOffset(yaddr).c_str());
      }
    }
  }
  
  vector<XYSprite> ret;
  for (const XYSprite &sprite : sprites) {
    XYSprite newsprite;
    newsprite.sprite_idx = sprite.sprite_idx;
    newsprite.oldmem = sprite.oldmem;
    for (auto addr : sprite.xmems) {
      if (!known_inconsequential[addr.first]) {
	newsprite.xmems.push_back(addr);
      }
    }
    for (auto addr : sprite.ymems) {
      if (!known_inconsequential[addr.first]) {
	newsprite.ymems.push_back(addr);
      }
    }

    if (!newsprite.xmems.empty() &&
	!newsprite.ymems.empty()) {
      printf("Sprite %d survived consequentiality.\n"
	     "   x:", newsprite.sprite_idx);
      for (const auto addr : newsprite.xmems)
	printf(" %s", AddrOffset(addr).c_str());
      printf("\n   y:");
      for (const auto addr : newsprite.ymems)
	printf(" %s", AddrOffset(addr).c_str());
      printf("\n");
      
      ret.push_back(newsprite);
    }
  }

  return ret;
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
