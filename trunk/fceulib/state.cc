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
  // Note: these will crash if fceulib__ is not initialized first. FIX
  if (state_initialized) return;
  sfcpu = {
    { &fceulib__.X->reg_PC, 2|FCEUSTATE_RLSB, "PC\0" },
    { &fceulib__.X->reg_A, 1, "A\0\0" },
    { &fceulib__.X->reg_P, 1, "P\0\0" },
    { &fceulib__.X->reg_X, 1, "X\0\0" },
    { &fceulib__.X->reg_Y, 1, "Y\0\0" },
    { &fceulib__.X->reg_S, 1, "S\0\0" },
    { &fceulib__.fceu->RAM, 0x800 | FCEUSTATE_INDIRECT, "RAM" },
    { 0 },
  };

  sfcpuc = {
    { &fceulib__.X->jammed, 1, "JAMM" },
    { &fceulib__.X->IRQlow, 4|FCEUSTATE_RLSB, "IQLB" },
    { &fceulib__.X->tcount, 4|FCEUSTATE_RLSB, "ICoa" },
    { &fceulib__.X->count,  4|FCEUSTATE_RLSB, "ICou" },
    { &fceulib__.fceu->timestampbase, 
      sizeof (fceulib__.fceu->timestampbase) | FCEUSTATE_RLSB, "TSBS" },
    // alternative to the "quick and dirty hack"
    { &fceulib__.X->reg_PI, 1, "MooP" },
    // This was not included in FCEUltra, but I can't see any
    // reason why it shouldn't be (it's updated with each memory
    // read and used by some boards), and execution diverges if
    // it's not saved/restored. (See "Skull & Crossbones" around
    // FCEUlib revision 2379.)
    { &fceulib__.X->DB, 1, "DBDB" },
    { 0 }
  };

  state_initialized = true;
}

int State::SubWrite(EMUFILE* os, const SFORMAT *sf) {
  uint32 acc=0;

  TRACE_SCOPED_STAY_ENABLED_IF(false);

  while (sf->v) {
    if (sf->s==~0) {
      // Link to another struct
      const uint32 tmp = SubWrite(os,(const SFORMAT *)sf->v);

      if (!tmp)
	return 0;
      acc+=tmp;
      sf++;
      continue;
    }

    // 8 bytes for tag + size
    acc += 8;
    acc += sf->s&(~FCEUSTATE_FLAGS);

    //Are we writing or calculating the size of this block?
    if (os) {
      os->fwrite(sf->desc,4);
      write32le(sf->s&(~FCEUSTATE_FLAGS),os);
      
      TRACE_SCOPED_ENABLE_IF(sf->desc[0] == 'P' && sf->desc[1] == 'C');
      TRACEF("%s for %d", sf->desc, sf->s & ~FCEUSTATE_FLAGS);

      if (sf->s&FCEUSTATE_INDIRECT)
	TRACEA(*(uint8 **)sf->v, sf->s&(~FCEUSTATE_FLAGS));
      else
	TRACEA((uint8 *)sf->v, sf->s&(~FCEUSTATE_FLAGS));


#ifndef LSB_FIRST
      if (sf->s&FCEUSTATE_RLSB)
	FlipByteOrder((uint8*)sf->v,sf->s&(~FCEUSTATE_FLAGS));
#endif

      if (sf->s&FCEUSTATE_INDIRECT)
	os->fwrite(*(char **)sf->v,sf->s&(~FCEUSTATE_FLAGS));
      else
	os->fwrite((char*)sf->v,sf->s&(~FCEUSTATE_FLAGS));

      //Now restore the original byte order.
#ifndef LSB_FIRST
      if (sf->s&FCEUSTATE_RLSB)
	FlipByteOrder((uint8*)sf->v,sf->s&(~FCEUSTATE_FLAGS));
#endif
    }
    sf++;
  }

  return acc;
}

int State::WriteStateChunk(EMUFILE* os, int type, const SFORMAT *sf) {
  os->fputc(type);
  int bsize = SubWrite((EMUFILE*)0,sf);
  write32le(bsize,os);
  // TRACEF("Write %s etc. sized %d", sf->desc, bsize);

  if (!SubWrite(os,sf)) {
    return 5;
  }
  return bsize + 5;
}

const SFORMAT *State::CheckS(const SFORMAT *sf, uint32 tsize, char *desc) {
  while (sf->v) {
    if (sf->s==~0) {
      // Link to another SFORMAT structure.
		  
      if (const SFORMAT *tmp = CheckS((const SFORMAT *)sf->v, tsize, desc))
	return tmp;
      sf++;
      continue;
    }
    if (!memcmp(desc,sf->desc,4)) {
      if (tsize!=(sf->s&(~FCEUSTATE_FLAGS)))
	return(0);
      return sf;
    }
    sf++;
  }
  return nullptr;
}
			      
bool State::ReadStateChunk(EMUFILE* is, const SFORMAT *sf, int size) {
  int temp = is->ftell();

  while (is->ftell()<temp+size) {
    uint32 tsize;
    char toa[4];
    if (is->fread(toa,4)<4)
      return false;

    read32le(&tsize,is);

    if (const SFORMAT *tmp = CheckS(sf,tsize,toa)) {
      if (tmp->s&FCEUSTATE_INDIRECT)
	is->fread(*(char **)tmp->v,tmp->s&(~FCEUSTATE_FLAGS));
      else
	is->fread((char *)tmp->v,tmp->s&(~FCEUSTATE_FLAGS));

#ifndef LSB_FIRST
      if (tmp->s&FCEUSTATE_RLSB)
	FlipByteOrder((uint8*)tmp->v,tmp->s&(~FCEUSTATE_FLAGS));
#endif
    } else {
      is->fseek(tsize,SEEK_CUR);
    }
  }
  return true;
}

bool State::ReadStateChunks(EMUFILE* is, int32 totalsize) {
  InitState();
  uint32 size;
  bool ret=true;
  bool warned=false;

  while (totalsize > 0) {
    int t = is->fgetc();
    if (t==EOF) break;
    if (!read32le(&size,is)) break;
    totalsize -= size + 5;

    switch (t) {
    case 1:
      if (!ReadStateChunk(is,sfcpu.data(),size))
	ret=false;
      break;
    case 3:
      if (!ReadStateChunk(is,fceulib__.ppu->FCEUPPU_STATEINFO(),size))
	ret=false;
      break;
    case 4:
      if (!ReadStateChunk(is,fceulib__.input->FCEUINPUT_STATEINFO(),size))
	ret=false;
      break;
    case 7:
      fprintf(stderr, "This used to be mid-movie recording. -tom7.\n");
      abort();
      break;
    case 0x10:
      if (!ReadStateChunk(is,SFMDATA,size))
	ret=false;
      break;
    case 5:
      if (!ReadStateChunk(is,fceulib__.sound->FCEUSND_STATEINFO(),size))
	ret=false;
      break;
    case 6:
      is->fseek(size,SEEK_CUR);
      break;
    case 8:
      // load back buffer
      {
	if (is->fread((char*)fceulib__.fceu->XBackBuf,size) != size)
	  ret = false;
      }
      break;
    case 2:
      if (!ReadStateChunk(is,sfcpuc.data(),size))
	ret=false;
      break;
    default:
      // for somebody's sanity's sake, at least warn about it:
      // XXX should probably just abort here since we don't try to provide
      // save-state compatibility. -tom7
      if (!warned) {
	char str[256];
	sprintf(str, "Warning: Found unknown save chunk of type %d.\n"
		"This could indicate the save state is corrupted\n"
		"or made with a different (incompatible) emulator version.", t);
	FCEUD_PrintError(str);
	warned=true;
      }
      //if (fseek(st,size,SEEK_CUR)<0) goto endo;break;
      is->fseek(size,SEEK_CUR);
    }
  }

  return ret;
}

// Simplified save that does not compress.
bool State::FCEUSS_SaveRAW(std::vector<uint8> *out) {
  InitState();
  EMUFILE_MEMORY os(out);

  uint32 totalsize = 0;

  fceulib__.ppu->FCEUPPU_SaveState();
  fceulib__.sound->FCEUSND_SaveState();
  totalsize = WriteStateChunk(&os,1,sfcpu.data());
  totalsize += WriteStateChunk(&os,2,sfcpuc.data());
  TRACEF("PPU:");
  totalsize += WriteStateChunk(&os,3,fceulib__.ppu->FCEUPPU_STATEINFO());
  TRACEV(*out);
  totalsize += WriteStateChunk(&os,4,fceulib__.input->FCEUINPUT_STATEINFO());
  // TRACEV(*out);
  totalsize += WriteStateChunk(&os,5,fceulib__.sound->FCEUSND_STATEINFO());
  // TRACEV(*out);

  if (SPreSave) SPreSave(fc);
  // This allows other parts of the system to hook into things to be
  // saved. It is indeed used for "WRAM", "LATC", "BUSC". -tom7
  // TRACEF("SFMDATA:");
  totalsize += WriteStateChunk(&os,0x10,SFMDATA);
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

bool State::FCEUSS_LoadRAW(std::vector<uint8> *in) {
  EMUFILE_MEMORY is(in);

  int totalsize = is.size();
  // Assume current version; memory only.
  int stateversion = FCEU_VERSION_NUMERIC;

  bool success = (ReadStateChunks(&is, totalsize) != 0);

  if (fceulib__.fceu->GameStateRestore != nullptr) {
    fceulib__.fceu->GameStateRestore(&fceulib__, stateversion);
  }

  if (success) {
    fceulib__.ppu->FCEUPPU_LoadState(stateversion);
    fceulib__.sound->FCEUSND_LoadState(stateversion);
    return true;
  } else {
    return false;
  }
}

void State::ResetExState(void (*PreSave)(FC *), void (*PostSave)(FC *)) {
  for (int x = 0; x < SFEXINDEX; x++) {
    free(SFMDATA[x].desc);
  }
  // adelikat, 3/14/09: had to add this to clear out the size
  // parameter. NROM(mapper 0) games were having savestate
  // crashes if loaded after a non NROM game because the size
  // variable was carrying over and causing savestates to save
  // too much data
  SFMDATA[0].s = 0;

  SPreSave = PreSave;
  SPostSave = PostSave;
  SFEXINDEX = 0;
}

void State::AddExStateReal(void *v, uint32 s, int type,
			   char *desc, const char *src) {
  if (s == ~0) {
    const SFORMAT *sf = (const SFORMAT*)v;
    map<string, bool> names;
    while (sf->v) {
      char tmp[5] = {0};
      memcpy(tmp,sf->desc,4);
      std::string desc = tmp;
      if (names.find(desc) != names.end()) {
	fprintf(stderr, "SFORMAT with duplicate key: %s\n", desc.c_str());
	abort();
      }
      names[desc] = true;
      sf++;
    }
  }

  if (desc != nullptr) {
    // PERF: n^2 paranoia. Should rewrite this to keep a regular
    // std::map or something.
    for (int i = 0; i < SFEXINDEX; i++) {
      if (SFMDATA[i].desc != nullptr &&
	  0 == strcmp(SFMDATA[i].desc, desc)) {
	fprintf(stderr, "AddExState: The key '%s' was registered twice.\n"
		"Second was from %s.\n",
		desc, src);
	abort();
      }
    }

    SFMDATA[SFEXINDEX].desc=(char *)FCEU_malloc(strlen(desc)+1);
    strcpy(SFMDATA[SFEXINDEX].desc,desc);
  } else {
    SFMDATA[SFEXINDEX].desc = nullptr;
  }
  SFMDATA[SFEXINDEX].v = v;
  SFMDATA[SFEXINDEX].s = s;
  if (type) SFMDATA[SFEXINDEX].s |= FCEUSTATE_RLSB;
  if (SFEXINDEX < SFMDATA_SIZE-1) {
    SFEXINDEX++;
  } else {
    fprintf(stderr, "Error in AddExState: SFEXINDEX overflow.\n"
	    "Somebody made SFMDATA_SIZE too small.\n");
    abort();
  }
  // End marker.
  SFMDATA[SFEXINDEX].v = 0;
}

State::State(FC *fc) : fc(fc) {}
