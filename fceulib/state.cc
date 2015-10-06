/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 2002 Xodnizel
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

//  TODO: Add (better) file io error checking

#include <string>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <vector>
#include <fstream>
#include <map>

#include "version.h"
#include "types.h"
#include "x6502.h"
#include "fceu.h"
#include "sound.h"
#include "utils/endian.h"
#include "utils/memory.h"
#include "utils/xstring.h"
#include "file.h"
#include "fds.h"
#include "state.h"
#include "ppu.h"
#include "input.h"
#include "zlib.h"
#include "driver.h"

#include "tracing.h"

using namespace std;

void State::InitState() {
  if (state_initialized) return;
  sfcpu = {
      {&fc->X->reg_PC, 2 | FCEUSTATE_RLSB, "rgPC"},
      {&fc->X->reg_A, 1, "regA"},
      {&fc->X->reg_P, 1, "regP"},
      {&fc->X->reg_X, 1, "regX"},
      {&fc->X->reg_Y, 1, "regY"},
      {&fc->X->reg_S, 1, "regS"},
      {fc->fceu->RAM, 0x800, "RAMM"},
  };

  sfcpuc = {
      {&fc->X->jammed, 1, "JAMM"},
      {&fc->X->IRQlow, 4 | FCEUSTATE_RLSB, "IQLB"},
      {&fc->X->tcount, 4 | FCEUSTATE_RLSB, "ICoa"},
      {&fc->X->count, 4 | FCEUSTATE_RLSB, "ICou"},
      {&fc->fceu->timestampbase,
       sizeof(fc->fceu->timestampbase) | FCEUSTATE_RLSB, "TSBS"},
      // alternative to the "quick and dirty hack"
      {&fc->X->reg_PI, 1, "MooP"},
      // This was not included in FCEUltra, but I can't see any
      // reason why it shouldn't be (it's updated with each memory
      // read and used by some boards), and execution diverges if
      // it's not saved/restored. (See "Skull & Crossbones" around
      // FCEUlib revision 2379.)
      {&fc->X->DB, 1, "DBDB"},
  };

  state_initialized = true;
}

// Write the vector to the output file. If the file pointer is
// null, just return the size.
int State::SubWrite(EMUFILE *os, const vector<SFORMAT> &sf) {
  uint32 acc = 0;

  TRACE_SCOPED_STAY_ENABLED_IF(false);

  for (const SFORMAT &f : sf) {
    CHECK(f.s != ~0);
    #if 0
    if (sf->s == ~0) {
      // Link to another struct
      const uint32 tmp = SubWrite(os, (const SFORMAT *)sf->v);

      if (!tmp) return 0;
      acc += tmp;
      sf++;
      continue;
    }
    #endif
    
    // 8 bytes for tag + size
    acc += 8;
    acc += f.s & (~FCEUSTATE_FLAGS);

    // Are we writing or calculating the size of this block?
    if (os != nullptr) {
      os->fwrite(f.desc.data(), 4);
      write32le(f.s & (~FCEUSTATE_FLAGS), os);

      // TRACE_SCOPED_ENABLE_IF(f.desc[2] == 'P' && f.desc[3] == 'C');
      // TRACEF("%s for %d", f.desc, f.s & ~FCEUSTATE_FLAGS);

      TRACEA((uint8 *)f.v, f.s & (~FCEUSTATE_FLAGS));

#ifndef LSB_FIRST
      // TODO: Copy the data instead of byte-swapping in place. -tom7
      if (f.s & FCEUSTATE_RLSB)
        FlipByteOrder((uint8 *)f.v, f.s & (~FCEUSTATE_FLAGS));
#endif

      os->fwrite((char *)f.v, f.s & (~FCEUSTATE_FLAGS));

// Now restore the original byte order.
#ifndef LSB_FIRST
      if (f.s & FCEUSTATE_RLSB)
        FlipByteOrder((uint8 *)f.v, f.s & (~FCEUSTATE_FLAGS));
#endif
    }
  }

  return acc;
}

// Write all the sformats to the output file.
int State::WriteStateChunk(EMUFILE *os, int type,
			   const vector<SFORMAT> &sf) {
  os->fputc(type);
  int bsize = SubWrite(nullptr, sf);
  write32le(bsize, os);
  // TRACEF("Write %s etc. sized %d", sf->desc, bsize);

  if (!SubWrite(os, sf)) {
    return 5;
  }
  return bsize + 5;
}

// Find the SFORMAT structure with the name 'desc', if any.
const SFORMAT *State::CheckS(const vector<SFORMAT> &sf,
			     uint32 tsize, SKEY desc) {
  for (const SFORMAT &f : sf) {
    CHECK(f.s != ~0);
    if (f.desc == desc) {
      if (tsize != (f.s & (~FCEUSTATE_FLAGS))) return nullptr;
      return &f;
    }
  }
  return nullptr;
}

bool State::ReadStateChunk(EMUFILE *is,
			   const vector<SFORMAT> &sf, int size) {
  int temp = is->ftell();
  
  while (is->ftell() < temp + size) {
    uint32 tsize;
    SKEY toa;
    if (is->fread(toa.data(), 4) < 4) return false;

    read32le(&tsize, is);

    if (const SFORMAT *tmp = CheckS(sf, tsize, toa)) {
      is->fread((char *)tmp->v, tmp->s & (~FCEUSTATE_FLAGS));

#ifndef LSB_FIRST
      if (tmp->s & FCEUSTATE_RLSB)
        FlipByteOrder((uint8 *)tmp->v, tmp->s & (~FCEUSTATE_FLAGS));
#endif
    } else {
      is->fseek(tsize, SEEK_CUR);
    }
  }
  return true;
}

bool State::ReadStateChunks(EMUFILE *is, int32 totalsize) {
  InitState();
  uint32 size;
  bool ret = true;
  bool warned = false;

  while (totalsize > 0) {
    int t = is->fgetc();
    if (t == EOF) break;
    if (!read32le(&size, is)) break;
    totalsize -= size + 5;

    switch (t) {
      case 1:
        if (!ReadStateChunk(is, sfcpu, size)) ret = false;
        break;
      case 3:
        if (!ReadStateChunk(is, fc->ppu->FCEUPPU_STATEINFO(), size))
          ret = false;
        break;
      case 4:
        if (!ReadStateChunk(is, fc->input->FCEUINPUT_STATEINFO(), size))
          ret = false;
        break;
      case 7:
        fprintf(stderr, "This used to be mid-movie recording. -tom7.\n");
        abort();
        break;
      case 0x10:
        if (!ReadStateChunk(is, sfmdata, size)) ret = false;
        break;
      case 5:
        if (!ReadStateChunk(is, fc->sound->FCEUSND_STATEINFO(), size))
          ret = false;
        break;
      case 6: is->fseek(size, SEEK_CUR); break;
      case 8:
        // load back buffer
        {
          if (is->fread((char *)fc->fceu->XBackBuf, size) != size) ret = false;
        }
        break;
      case 2:
        if (!ReadStateChunk(is, sfcpuc, size)) ret = false;
        break;
      default:
        // for somebody's sanity's sake, at least warn about it:
        // XXX should probably just abort here since we don't try to provide
        // save-state compatibility. -tom7
        if (!warned) {
          char str[256];
          sprintf(str,
                  "Warning: Found unknown save chunk of type %d.\n"
                  "This could indicate the save state is corrupted\n"
                  "or made with a different (incompatible) emulator version.",
                  t);
          FCEUD_PrintError(str);
          warned = true;
        }
        // if (fseek(st,size,SEEK_CUR)<0) goto endo;break;
        is->fseek(size, SEEK_CUR);
    }
  }

  return ret;
}

// Simplified save that does not compress.
bool State::FCEUSS_SaveRAW(std::vector<uint8> *out) {
  InitState();
  EMUFILE_MEMORY os(out);

  uint32 totalsize = 0;

  fc->ppu->FCEUPPU_SaveState();
  fc->sound->FCEUSND_SaveState();
  totalsize = WriteStateChunk(&os, 1, sfcpu);
  totalsize += WriteStateChunk(&os, 2, sfcpuc);
  //  TRACEF("PPU:");
  totalsize += WriteStateChunk(&os, 3, fc->ppu->FCEUPPU_STATEINFO());
  // TRACEV(*out);
  totalsize += WriteStateChunk(&os, 4, fc->input->FCEUINPUT_STATEINFO());
  totalsize += WriteStateChunk(&os, 5, fc->sound->FCEUSND_STATEINFO());

  if (SPreSave) SPreSave(fc);
  // This allows other parts of the system to hook into things to be
  // saved. It is indeed used for "WRAM", "LATC", "BUSC". -tom7
  // M probably stands for Mapper, but I also use it in input, at least.
  //
  // TRACEF("SFMDATA:");
  totalsize += WriteStateChunk(&os, 0x10, sfmdata);
  // TRACEV(*out);
  // Was just spre, but that seems wrong -tom7
  if (SPreSave && SPostSave) SPostSave(fc);

  // save the length of the file
  const int len = os.size();

  // PERF shrink to fit?

  // sanity check: len and totalsize should be the same
  if (len != totalsize) {
    FCEUD_PrintError("sanity violation: len != totalsize");
    return false;
  }

  return true;
}

bool State::FCEUSS_LoadRAW(const std::vector<uint8> &in) {
  EMUFILE_MEMORY_READONLY is{in};

  int totalsize = is.size();
  // Assume current version; memory only.
  int stateversion = FCEU_VERSION_NUMERIC;

  bool success = (ReadStateChunks(&is, totalsize) != 0);

  if (fc->fceu->GameStateRestore != nullptr) {
    fc->fceu->GameStateRestore(fc, stateversion);
  }

  if (success) {
    fc->ppu->FCEUPPU_LoadState(stateversion);
    fc->sound->FCEUSND_LoadState(stateversion);
    return true;
  } else {
    return false;
  }
}

void State::ResetExState(void (*PreSave)(FC *), void (*PostSave)(FC *)) {

  // If this needs to happen, it's a bug in the way the savestate
  // system is being used. Fix it! It's not even really possible to
  // do this hack in the reimplementation.
  #if 0 
  // adelikat, 3/14/09: had to add this to clear out the size
  // parameter. NROM(mapper 0) games were having savestate
  // crashes if loaded after a non NROM game because the size
  // variable was carrying over and causing savestates to save
  // too much data
  SFMDATA[0].s = 0;
  #endif
  
  SPreSave = PreSave;
  SPostSave = PostSave;
  sfmdata.clear();
}

void State::AddExVec(const vector<SFORMAT> &vec) {
  for (const SFORMAT &sf : vec) {
    int flags = sf.s & FCEUSTATE_FLAGS;
    AddExStateReal(sf.v, sf.s & ~FCEUSTATE_FLAGS, flags, sf.desc,
		   "via AddExVec");
  }
}

void State::AddExStateReal(void *v, uint32 s, int type, SKEY desc,
                           const char *src) {
  // PERF: n^2. Use a map/set.
  for (const SFORMAT &sf : sfmdata) {
    if (sf.desc == desc) {
      fprintf(stderr, "SFORMAT with duplicate key: %c%c%c%c\n"
	      "Second called from %s\n",
	      desc[0], desc[1], desc[2], desc[3],
	      src);
      abort();
    }
  }
  
  CHECK(s != ~0);
  #if 0
  if (s == ~0) {
    const SFORMAT *sf = (const SFORMAT *)v;
    map<string, bool> names;
    while (sf->v) {
      char tmp[5] = {0};
      memcpy(tmp, sf->desc, 4);
      std::string descr = tmp;
      if (names.find(descr) != names.end()) {
        fprintf(stderr, "SFORMAT with duplicate key: %s\n", descr.c_str());
        abort();
      }
      names[descr] = true;
      sf++;
    }
  }
  #endif

  // impossible now
  // CHECK(desc != nullptr);
  
  #if 0
  if (desc != nullptr) {
    // PERF: n^2 paranoia. Should rewrite this to keep a regular
    // std::map or something.
    for (int i = 0; i < SFEXINDEX; i++) {
      if (SFMDATA[i].desc != nullptr &&
          // TODO: Sometimes we use strcmp and sometimes memcmp, but
          // these strings also have 0s in them...
          0 == strcmp(SFMDATA[i].desc, desc)) {
        fprintf(stderr,
                "AddExState: The key '%s' was registered twice.\n"
                "Second was from %s.\n",
                desc, src);
        abort();
      }
    }
  }
  #endif
    
  SFORMAT sf{v, s, desc};
  if (type) sf.s |= FCEUSTATE_RLSB;
  sfmdata.push_back(sf);
}

State::State(FC *fc) : fc(fc) {}
