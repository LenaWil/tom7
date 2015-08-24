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

#ifndef __STATE_H
#define __STATE_H

#include <vector>
#include <unordered_set>
#include <array>

#include "types.h"

#include "fc.h"

// XXX
#include "base/logging.h"

using SKEY = std::array<char, 4>;

struct SFORMAT {
  // a void* to the data or a void** to the data
  void *v;

  // size, plus flags
  // Also, if this is ~0, then that means that it's actually a link
  // to another SFORMAT structure. Gross.
  uint32 s;
  
  // Four-byte description; should be printable ASCII or \0. No
  // terminating nul byte!
  SKEY desc;

  SFORMAT(void *v, uint32 s, const char *key) :
    v(v), s(s) {
    // PERF
    CHECK(strlen(key) == 4) << "\nMust be exactly 4 bytes: " << key;
    // Discrepancy between C++11 and C++14 prevents using
    // brace initialization in initializer.
    // desc = {key[0], key[1], key[2], key[3]};
    desc[0] = key[0];
    desc[1] = key[1];
    desc[2] = key[2];
    desc[3] = key[3];
  }
  SFORMAT(void *v, uint32 s, SKEY desc) :
    v(v), s(s), desc(desc) {}
};

inline SKEY MakeSKEY(const char arr[4]) {
  SKEY k;
  k[0] = arr[0];
  k[1] = arr[1];
  k[2] = arr[2];
  k[3] = arr[3];
  return k;
}

struct HashDesc {
  size_t operator ()(const SKEY &a) const {
    size_t res = 0;
    res <<= 8; res |= a[0];
    res <<= 8; res |= a[1];
    res <<= 8; res |= a[2];
    res <<= 8; res |= a[3];
    return res;
  }
};

struct EqDesc {
  bool operator ()(const SKEY &a, const SKEY &b) const {
    return a[0] == b[0] &&
      a[1] == b[1] &&
      a[2] == b[2] &&
      a[3] == b[3];
  }
};

struct State {
  explicit State(FC *fc);

  // Tom 7's simplified versions. These should only be used for in-memory saves!
  bool FCEUSS_SaveRAW(std::vector<uint8> *out);
  bool FCEUSS_LoadRAW(std::vector<uint8> *in);

  // I think these add additional locations to the set of saved memories.
  void ResetExState(void (*PreSave)(FC *),void (*PostSave)(FC *));

  void AddExVec(const std::vector<SFORMAT> &formats);

  // Here, the size should be the real size (no flags), and the flags
  // should be passed separately.
  void AddExStateReal(void *v, uint32 s, int flags,
		      SKEY desc, const char *src);
  #define STRINGIFY_LINE_2(x) #x
  #define STRINGIFY_LINE(x) STRINGIFY_LINE_2(x)
  #define AddExState(v, s, t, d) \
    AddExStateReal(v, s, t, MakeSKEY(d), __FILE__ ":" STRINGIFY_LINE(__LINE__) )
 private:

  int SubWrite(EMUFILE *os, const std::vector<SFORMAT> &sf);

  int WriteStateChunk(EMUFILE* os, int type, const std::vector<SFORMAT> &sf);

  const SFORMAT *CheckS(const std::vector<SFORMAT> &sf,
			uint32 tsize, SKEY desc);
  bool ReadStateChunk(EMUFILE* is, const std::vector<SFORMAT> &sf, int size);
  bool ReadStateChunks(EMUFILE* is, int32 totalsize);
  
  void (*SPreSave)(FC *) = nullptr;
  void (*SPostSave)(FC *) = nullptr;

  // static constexpr int SFMDATA_SIZE = 64;
  // SFMDATA is dynamically allocated; its desc fields should be
  // deleted with delete [].
  // SFORMAT SFMDATA[SFMDATA_SIZE] = {};
  // int SFEXINDEX = 0;
  std::vector<SFORMAT> sfmdata;
  // This is just to prevent duplicate keys, which would be
  // disastrous.
  // PERF: If all of the data were in a hash map, we could
  // avoid the linear time CheckS.
  std::unordered_set<SKEY, HashDesc, EqDesc> used_keys;
  
  // XXX Can probably init in constructor?
  bool state_initialized = false;
  std::vector<SFORMAT> sfcpu, sfcpuc;
  void InitState();

  FC *fc = nullptr;
};
  
// indicates that the value is a multibyte integer that needs to be
// put in the correct byte order
#define FCEUSTATE_RLSB            0x80000000

// Got rid of this since it was only used for RAM, and not necessary
// there. -tom7
// void*v is actually a void** which will be indirected before reading
// #define FCEUSTATE_INDIRECT            0x40000000
// all FCEUSTATE flags together so that we can mask them out and get
// the size
#define FCEUSTATE_FLAGS (FCEUSTATE_RLSB /*|FCEUSTATE_INDIRECT */)

#endif
