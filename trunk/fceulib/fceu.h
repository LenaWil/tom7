#ifndef _FCEUH
#define _FCEUH

#include "types.h"
#include "git.h"

// XXX
#include <string>
#include "stringprintf.h"

#include "git.h"

#include "fc.h"

typedef void (*writefunc)(FC *, uint32 A, uint8 V);
typedef uint8 (*readfunc)(FC *, uint32 A);

static constexpr int newppu = 0;

// TODO(tom7): Fix this junk. These have to take a Fceulib object.
#define DECLFR(x) uint8 x (FC *fc, uint32 A)
#define DECLFR_FORWARD fc, A
#define DECLFR_RET uint8
#define DECLFR_ARGS FC *fc, uint32 A

#define DECLFW(x) void x (FC *fc, uint32 A, uint8 V)
#define DECLFW_RET void
#define DECLFW_FORWARD fc, A, V
#define DECLFW_ARGS FC *fc, uint32 A, uint8 V

enum GI {
  GI_RESETM2 = 1,
  GI_POWER = 2,
  GI_CLOSE = 3,
  GI_RESETSAVE = 4,
};

enum EFCEUI {
  FCEUI_RESET, FCEUI_POWER, 
  FCEUI_EJECT_DISK, FCEUI_SWITCH_DISK
};

struct CartInterface;
struct MapInterface;

struct FCEU {
  explicit FCEU(FC *fc);
  ~FCEU();
  
  void SetReadHandler(int32 start, int32 end, readfunc func);

  void SetWriteHandler(int32 start, int32 end, writefunc func);
  writefunc GetWriteHandler(int32 a);
  readfunc GetReadHandler(int32 a);

  void FCEU_CloseGame();
  void FCEU_ResetVidSys();
  bool FCEUI_Initialize();

  // Weird thing only used in Barcode game, but probably still working.
  int FCEUI_DatachSet(const uint8 *rcode);

  // Emulates a frame.
  void FCEUI_Emulate(int video_and_sound_flags);

  void ResetMapping();
  void ResetNES();
  void PowerNES();

  // Set video system a=0 NTSC, a=1 PAL
  void FCEUI_SetVidSystem(int a);

  //name=path and file to load.  returns null if it failed
  FCEUGI *FCEUI_LoadGame(const char *name, int OverwriteVidMode);

  // Used by some boards to do delayed memory writes, etc.
  uint64 timestampbase = 0ULL;

  // PERF: Allocate dynamically based on mapper? -tom7
  #define GAME_MEM_BLOCK_SIZE 131072

  // Basic RAM of the system. RAM has size 0x800.
  // GameMemBlock has size GAME_MEM_BLOCK_SIZE, though most games
  // don't use all of it.
  uint8 *RAM = nullptr;
  uint8 *GameMemBlock = nullptr;

  // Current frame buffer. 256x256
  uint8 *XBuf = nullptr;
  uint8 *XBackBuf = nullptr;

  // TODO(tom7): Move these to the modules where they're defined.
  // Hooks for reading and writing from memory locations. Each one
  // is a function pointer.
  readfunc ARead[0x10000];
  writefunc BWrite[0x10000];

  void (*GameInterface)(FC *fc, GI h) = nullptr;
  void (*GameStateRestore)(FC *fc, int version) = nullptr;

  FCEUGI *GameInfo = nullptr;

  // XXX This used to be part of the FSettings object, which have
  // all become constant, but this one is modified when loading
  // certain carts, so probably can't be a compile-time constant.
  // It's not used in many places, though. Looks like it could be
  // interpreted as "default_pal".
  // TODO: Reconcile with PAL variable.
  int fsettings_pal = 0;
  uint8 PAL = 0;

  void SetNESDeemph(uint8 d, int force);

  // checks whether an EFCEUI is valid right now
  bool FCEU_IsValidUI(EFCEUI ui);

  // Cart interface, which can be set by either the ines or unif
  // loading code. It has to be in a shared location rather than
  // a member of (both of) those, because mapper code needs to
  // be able to find itself from a FC pointer (e.g. within a
  // DECLFW handler).
  //
  // If this is deleted, make sure it is set to nullptr.
  CartInterface *cartiface = nullptr;
  // Same idea, for old-style _init mappers. Maybe could just use
  // CartInterface here too, but the code is a maze of twisty
  // passages, so it's safer to just separate them. (The right cleanup
  // is to port all old-style mappers to new-style, anyway.)
  MapInterface *mapiface = nullptr;
  
private:
  readfunc *AReadG = nullptr;
  writefunc *BWriteG = nullptr;

  void ResetGameLoaded();

  FC *fc = nullptr;
};

// Stateless stuff that should probably be in its own header..
void FCEU_PrintError(const char *format, ...);
void FCEU_printf(const char *format, ...);
// Initialize memory to stripes of 0xFF and 0x00.
void FCEU_InitMemory(uint8 *ptr, uint32 size);

#define JOY_A   1
#define JOY_B   2
#define JOY_SELECT      4
#define JOY_START       8
#define JOY_UP  0x10
#define JOY_DOWN        0x20
#define JOY_LEFT        0x40
#define JOY_RIGHT       0x80

#endif
