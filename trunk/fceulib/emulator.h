/*
  Library interface to FCEUX. This is an attempt to proper encapsulation
  of the emulator so that there can be multiple instances at once and
  they can run in separate threads, but I haven't succeded at that yet;
  if you create multiple instances of this object they will trample on
  each other and cause undefined behavior.
*/

#ifndef __EMULATOR_H
#define __EMULATOR_H

#include <vector>
#include <string>

#include "types.h"

#include "fc.h"

using namespace std;

struct FCEUGI;
struct Emulator {
  static constexpr int AUDIO_SAMPLE_RATE = 44100;

  // Returns nullptr (or aborts) on error. Upon success, returns
  // a new-ly allocated instance.
  static Emulator *Create(const string &romfile);

  ~Emulator();
  
  // Serialize the state to the vector, allowing it to be restored
  // with Load. This version may use compression to minimize the
  // state size; for a much faster version, use SaveUncompressed.
  void Save(vector<uint8> *out);
  void Load(const vector<uint8> &in);

  // Make one emulator step with the given input.
  // Bits from MSB to LSB are
  //    RLDUTSBA (Right, Left, Down, Up, sTart, Select, B, A)
  //
  // Consider StepFull if you want video or CachingStep if you
  // are doing search and might execute this same step again.
  void Step(uint8 controller1, uint8 controller2);

  // Copy the 0x800 bytes of RAM.
  void GetMemory(vector<uint8> *mem);
  vector<uint8> GetMemory();

  // Fancy stuff.

  // Same, but run the video and sound code as well. This is slower,
  // but allows calling GetImage and GetSound.
  void StepFull(uint8 controller1, uint8 controller2);

  // Get image. StepFull must have been called to produce this frame,
  // or else who knows what's in there? (Note that restoring a state
  // will not necessarily restore the image.) Size is 256 x 256 pixels,
  // 4 color channels (bytes) per pixel in RGBA order, though only
  // 240 pixels high contain anything interesting.
  void GetImage(vector<uint8> *rgba) const;
  vector<uint8> GetImage() const;
  // Same, but Alpha, Red, Green, Blue.
  void GetImageARGB(vector<uint8> *abgr) const;
  vector<uint8> GetImageARGB() const;
  
  // Get sound. StepFull must have been called to produce this wave.
  // The result is a vector of signed 16-bit samples, mono.
  void GetSound(vector<int16> *wav);

  // Returns 64-bit checksum (based on MD5, endianness-dependent)
  // of RAM (only). Note there are other important bits of state.
  uint64 RamChecksum();
  // Same, of the RGBA image. We only look at 240 scanlines here.
  uint64 ImageChecksum();

  // States often only differ by a small amount, so a way to reduce
  // their entropy is to diff them against a representative savestate.
  // This gets an uncompressed basis for the current state, which can
  // be used in the SaveEx and LoadEx routines.
  void GetBasis(vector<uint8> *out);

  // Save and load uncompressed. The memory will always be the same
  // size (Save and SaveEx may compress, which makes their output
  // significantly smaller), but this is the fastest in terms of CPU.
  void SaveUncompressed(vector<uint8> *out);
  vector<uint8> SaveUncompressed();
  void LoadUncompressed(const vector<uint8> &in);

  // Save and load with a basis vector. The vector can contain anything, and
  // doesn't even have to be the same length as an uncompressed save state,
  // but a state needs to be loaded with the same basis as it was saved.
  // basis can be NULL, and then these behave the same as Save/Load.
  void SaveEx(const vector<uint8> *basis, vector<uint8> *out);
  void LoadEx(const vector<uint8> *basis, const vector<uint8> &in);

  // Get the X Scroll offset from the PPU.
  // This may be confused by games that are not actuall horizontally
  // scrolling or that do something funny like change the scroll position
  // during scanlines.
  uint32 GetXScroll() const;
  
  // XXXXX debugging only.
  FC *GetFC() { return fc; }
  
 protected:
  // Use factory method.
  Emulator(FC *fc);

 private:
  bool DriverInitialize(FCEUGI *gi);
  bool LoadGame(const string &path);

  FC *fc = nullptr;
  
  // Joystick data. I think used for both controller 0 and 1. Part of
  // the "API". TODO: Move into FCEU or input object?
  uint32 joydata = 0;

  // Maybe we should consider supporting cloning, actually.
  Emulator(const Emulator &) = delete;
  Emulator &operator =(const Emulator &) = delete;
};


#endif
