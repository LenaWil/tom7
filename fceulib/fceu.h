#ifndef _FCEUH
#define _FCEUH

static constexpr bool fceuindbg = false;
extern int newppu;

// TODO(tom7): Fix this junk. These have to take a Fceulib object.
#define DECLFR(x) uint8 x (uint32 A)
#define DECLFR_FORWARD A
#define DECLFR_RET uint8
#define DECLFR_ARGS uint32 A

#define DECLFW(x) void x (uint32 A, uint8 V)
#define DECLFW_FORWARD A, V
#define DECLFW_ARGS uint32 A, uint8 V

void FCEU_MemoryRand(uint8 *ptr, uint32 size);
void SetReadHandler(int32 start, int32 end, readfunc func);
void SetWriteHandler(int32 start, int32 end, writefunc func);
writefunc GetWriteHandler(int32 a);
readfunc GetReadHandler(int32 a);

// int AllocGenieRW(void);
// void FlushGenieRW(void);

void FCEU_ResetVidSys(void);
bool FCEUI_Initialize();

void ResetMapping(void);
void ResetNES(void);
void PowerNES(void);

char *FCEUI_GetAboutString();

// TODO(tom7): Move these to the modules where they're defined.
extern uint64 timestampbase;
extern uint32 MMC5HackVROMMask;
extern uint8 *MMC5HackExNTARAMPtr;
extern int MMC5Hack;
extern uint8 *MMC5HackVROMPTR;
extern uint8 MMC5HackCHRMode;
extern uint8 MMC5HackSPMode;
extern uint8 MMC50x5130;
extern uint8 MMC5HackSPScroll;
extern uint8 MMC5HackSPPage;


#define GAME_MEM_BLOCK_SIZE 131072

extern  uint8  *RAM;            //shared memory modifications
extern  uint8  *GameMemBlock;   //shared memory modifications
extern int EmulationPaused;

extern readfunc ARead[0x10000];
extern writefunc BWrite[0x10000];

enum GI {
        GI_RESETM2      =1,
        GI_POWER =2,
        GI_CLOSE =3,
        GI_RESETSAVE = 4
};

extern void (*GameInterface)(GI h);
extern void (*GameStateRestore)(int version);


#include "git.h"
extern FCEUGI *GameInfo;
extern int GameAttributes;

extern uint8 PAL;

struct FCEUS {
  int PAL;
  int NetworkPlay;
  int SoundVolume;                //Master volume
  int TriangleVolume;
  int Square1Volume;
  int Square2Volume;
  int NoiseVolume;
  int PCMVolume;

  //the currently selected first and last rendered scanlines.
  int FirstSLine;
  int LastSLine;

  //the number of scanlines in the currently selected configuration
  int TotalScanlines() { return LastSLine - FirstSLine + 1; }

  //Driver-supplied user-selected first and last rendered scanlines.
  //Usr*SLine[0] is for NTSC, Usr*SLine[1] is for PAL.
  int UsrFirstSLine[2];
  int UsrLastSLine[2];

  uint32 SndRate;
  int soundq;
  int lowpass;
};

extern FCEUS FSettings;

bool CheckFileExists(const char* filename);     //Receives a filename (fullpath) and checks to see if that file exists

void FCEU_PrintError(char *format, ...);
void FCEU_printf(char *format, ...);

void SetNESDeemph(uint8 d, int force);
void FCEU_PutImage(void);
#ifdef FRAMESKIP
void FCEU_PutImageDummy(void);
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

///returns a flag indicating whether emulation is paused
int FCEUI_EmulationPaused();
