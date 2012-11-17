/*
  Library interface to FCEUX.

  Ideally this would be a proper class (really no reason not to),
  but because FCEUX uses loads of global variables, this has
  to be treated as a singleton.
*/

#ifndef __EMULATOR_H
#define __EMULATOR_H

#include <vector>
#include <string>

#include "fceu/types.h"

using namespace std;

struct Emulator {
  // Returns false upon error. Only initialize once.
  static bool Initialize(const string &romfile);
  // Calls some internal FCEUX stuff, probably not necessary.
  static void Shutdown();

  static void Save(vector<uint8> *out);
  static void Load(const vector<uint8> &in);

  // Make one emulator step with the given input.
  // Bits from MSB to LSB are
  //    RLDUTSBA (Right, Left, Down, Up, sTart, Select, B, A)
  static void Step(uint8 inputs);

  // Returns 64-bit checksum (based on MD5, endianness-dependent)
  // of RAM (only). Note there are other important bits of state.
  static uint64 RamChecksum();
};


#endif
