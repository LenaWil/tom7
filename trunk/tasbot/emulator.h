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
  // Doesn't modify its argument.
  static void Load(vector<uint8> *in);

  // Make one emulator step with the given input.
  // Bits from MSB to LSB are
  //    RLDUTSBA (Right, Left, Down, Up, sTart, Select, B, A)
  static void Step(uint8 inputs);

  // Returns 64-bit checksum (based on MD5, endianness-dependent)
  // of RAM (only). Note there are other important bits of state.
  static uint64 RamChecksum();

  // Fancy stuff. States often only differ by a small amount, so a way
  // to reduce their entropy is to diff them against a representative
  // savestate. This gets an uncompressed basis for the current state,
  // which can be used in the SaveEx and LoadEx routines.
  static void GetBasis(vector<uint8> *out);

  // Save and load with a basis vector. The vector can contain anything, and
  // doesn't even have to be the same length as an uncompressed save state,
  // but a state needs to be loaded with the same basis as it was saved.
  static void SaveEx(vector<uint8> *out, const vector<uint8> &basis);
  static void LoadEx(vector<uint8> *in, const vector<uint8> &basis);
};


#endif
