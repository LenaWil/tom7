#ifndef _FCEUH
#define _FCEUH

#include "git.h"

// XXX
#include <string>
#include "stringprintf.h"

static constexpr bool fceuindbg = false;
static constexpr int newppu = 0;

// TODO(tom7): Fix this junk. These have to take a Fceulib object.
#define DECLFR(x) uint8 x (uint32 A)
#define DECLFR_FORWARD A
#define DECLFR_RET uint8
#define DECLFR_ARGS uint32 A

#define DECLFW(x) void x (uint32 A, uint8 V)
#define DECLFW_RET void
#define DECLFW_FORWARD A, V
#define DECLFW_ARGS uint32 A, uint8 V

void FCEU_MemoryRand(uint8 *ptr, uint32 size);
void SetReadHandler(int32 start, int32 end, readfunc func);
#if 0
#define SetReadHandler(start, end, func) \
  SetReadHandler_Wrapped(FCEU_StringPrintf(__FILE__ ":%s:%d = %s",	\
					   __func__, __LINE__, #func),	\
                         start, end, func)
void SetReadHandler_Wrapped(const std::string &what, 
			    int32 start, int32 end, readfunc func);
#endif

void SetWriteHandler(int32 start, int32 end, writefunc func);
writefunc GetWriteHandler(int32 a);
readfunc GetReadHandler(int32 a);

void FCEU_CloseGame();
void FCEU_ResetVidSys();
bool FCEUI_Initialize();

// Emulates a frame.
void FCEUI_Emulate(uint8 **, int32 **, int32 *, int);

// Deallocates all allocated memory.  Call after FCEUI_Emulate() returns.
void FCEUI_Kill();

void ResetMapping();
void ResetNES();
void PowerNES();

// Set video system a=0 NTSC, a=1 PAL
void FCEUI_SetVidSystem(int a);
// Returns currently emulated video system(0=NTSC, 1=PAL).
int FCEUI_GetCurrentVidSystem(int *slstart, int *slend);

//name=path and file to load.  returns null if it failed
// These are exactly the same; make just one. -tom7
FCEUGI *FCEUI_LoadGame(const char *name, int OverwriteVidMode);
FCEUGI *FCEUI_LoadGameVirtual(const char *name, int OverwriteVidMode);

// TODO(tom7): Move these to the modules where they're defined.
extern uint64 timestampbase;

#define GAME_MEM_BLOCK_SIZE 131072

// Basic RAM of the system. RAM has size 0x800.
// GameMemBlock has the size above, though most games don't use
// all of it.
extern uint8 *RAM;
extern uint8 *GameMemBlock;

// Current frame buffer. 256x256
extern uint8 *XBuf;
extern uint8 *XBackBuf;

// Hooks for reading and writing from memory locations. Each one
// is a function pointer.
extern readfunc ARead[0x10000];
extern writefunc BWrite[0x10000];

enum GI {
  GI_RESETM2 = 1,
  GI_POWER = 2,
  GI_CLOSE = 3,
  GI_RESETSAVE = 4,
};

extern void (*GameInterface)(GI h);
extern void (*GameStateRestore)(int version);


#include "git.h"
extern FCEUGI *GameInfo;
extern int GameAttributes;

extern uint8 PAL;

struct FCEUS {
  int PAL;
  // Master volume.
  int SoundVolume;
  int TriangleVolume;
  int Square1Volume;
  int Square2Volume;
  int NoiseVolume;
  int PCMVolume;

  // The currently selected first and last rendered scanlines.
  int FirstSLine;
  int LastSLine;

  // Driver-supplied user-selected first and last rendered scanlines.
  // Usr*SLine[0] is for NTSC, Usr*SLine[1] is for PAL.
  int UsrFirstSLine[2];
  int UsrLastSLine[2];

  uint32 SndRate;
  int soundq;
  int lowpass;
};

extern FCEUS FSettings;

void FCEU_PrintError(char *format, ...);
void FCEU_printf(char *format, ...);

void SetNESDeemph(uint8 d, int force);
void FCEU_PutImage();
#ifdef FRAMESKIP
void FCEU_PutImageDummy();
#endif

extern uint8 Exit;
extern uint8 vsdip;

#define JOY_A   1
#define JOY_B   2
#define JOY_SELECT      4
#define JOY_START       8
#define JOY_UP  0x10
#define JOY_DOWN        0x20
#define JOY_LEFT        0x40
#define JOY_RIGHT       0x80
#endif

#define ARRAY_SIZE(a) (sizeof(a)/sizeof(a[0]))

/// returns a flag indicating whether emulation is paused
int FCEUI_EmulationPaused();
