#ifndef __DRIVER_H_
#define __DRIVER_H_

#include <stdio.h>
#include <string>
#include <iosfwd>

#include "types.h"
#include "git.h"
#include "file.h"

FILE *FCEUD_UTF8fopen(const char *fn, const char *mode);
inline FILE *FCEUD_UTF8fopen(const std::string &n, const char *mode) { return FCEUD_UTF8fopen(n.c_str(),mode); }
EMUFILE_FILE* FCEUD_UTF8_fstream(const char *n, const char *m);
inline EMUFILE_FILE* FCEUD_UTF8_fstream(const std::string &n, const char *m) { return FCEUD_UTF8_fstream(n.c_str(),m); }
ArchiveScanRecord FCEUD_ScanArchive(std::string fname);

//mbg 7/23/06
const char *FCEUD_GetCompilerString();

//This makes me feel dirty for some reason.
void FCEU_printf(char *format, ...);
#define FCEUI_printf FCEU_printf

//Video interface
void FCEUD_SetPalette(uint8 index, uint8 r, uint8 g, uint8 b);
void FCEUD_GetPalette(uint8 i,uint8 *r, uint8 *g, uint8 *b);

//Displays an error.  Can block or not.
void FCEUD_PrintError(const char *s);
void FCEUD_Message(const char *s);

void FCEUI_ResetNES();
void FCEUI_PowerNES();

void FCEUI_NTSCSELHUE();
void FCEUI_NTSCSELTINT();
void FCEUI_NTSCDEC();
void FCEUI_NTSCINC();
void FCEUI_GetNTSCTH(int *tint, int *hue);
void FCEUI_SetNTSCTH(int n, int tint, int hue);

void FCEUI_SetInput(int port, ESI type, void *ptr, int attrib);
void FCEUI_SetInputFC(ESIFC type, void *ptr, int attrib);

//tells the emulator whether a fourscore is attached
void FCEUI_SetInputFourscore(bool attachFourscore);
//tells whether a fourscore is attached
bool FCEUI_GetInputFourscore();
//tells whether the microphone is used
bool FCEUI_GetInputMicrophone();

// 0 to keep 8-sprites limitation, 1 to remove it
void FCEUI_DisableSpriteLimitation(int a);

void FCEUI_SetRenderPlanes(bool sprites, bool bg);
void FCEUI_GetRenderPlanes(bool& sprites, bool& bg);

//name=path and file to load.  returns null if it failed
// These are exactly the same; make just one. -tom7
FCEUGI *FCEUI_LoadGame(const char *name, int OverwriteVidMode);
FCEUGI *FCEUI_LoadGameVirtual(const char *name, int OverwriteVidMode);

// general purpose emulator initialization. returns true if successful
bool FCEUI_Initialize();

// Emulates a frame.
void FCEUI_Emulate(uint8 **, int32 **, int32 *, int);

// Closes currently loaded game
void FCEUI_CloseGame();

// Deallocates all allocated memory.  Call after FCEUI_Emulate() returns.
void FCEUI_Kill();

// Set video system a=0 NTSC, a=1 PAL
void FCEUI_SetVidSystem(int a);

//Convenience function; returns currently emulated video system(0=NTSC, 1=PAL).
int FCEUI_GetCurrentVidSystem(int *slstart, int *slend);

#ifdef FRAMESKIP
/* Should be called from FCEUD_BlitScreen().  Specifies how many frames
   to skip until FCEUD_BlitScreen() is called.  FCEUD_BlitScreenDummy()
   will be called instead of FCEUD_BlitScreen() when when a frame is skipped.
*/
void FCEUI_FrameSkip(int x);
#endif

//First and last scanlines to render, for ntsc and pal emulation.
void FCEUI_SetRenderedLines(int ntscf, int ntscl, int palf, int pall);

//Sets up sound code to render sound at the specified rate, in samples
//per second.  Only sample rates of 44100, 48000, and 96000 are currently supported.
//If "Rate" equals 0, sound is disabled.
void FCEUI_Sound(int Rate);
void FCEUI_SetSoundVolume(uint32 volume);
void FCEUI_SetTriangleVolume(uint32 volume);
void FCEUI_SetSquare1Volume(uint32 volume);
void FCEUI_SetSquare2Volume(uint32 volume);
void FCEUI_SetNoiseVolume(uint32 volume);
void FCEUI_SetPCMVolume(uint32 volume);

void FCEU_DispMessage(char *format, int disppos, ...);
#define FCEUI_DispMessage FCEU_DispMessage

void FCEUI_NMI();
void FCEUI_IRQ();

void FCEUI_SetLowPass(int q);

void FCEUI_VSUniToggleDIPView();
void FCEUI_VSUniToggleDIP(int w);
uint8 FCEUI_VSUniGetDIPs();
void FCEUI_VSUniSetDIP(int w, int state);
void FCEUI_VSUniCoin();

void FCEUI_FDSInsert();
void FCEUI_FDSSelect();

int FCEUI_DatachSet(const uint8 *rcode);

// toggles the paused bit (bit0) for EmulationPaused. caused
// FCEUD_DebugUpdate() to fire if the emulation pauses
void FCEUI_ToggleEmulationPause();

///called when the emulator closes a game
void FCEUD_OnCloseGame();

void FCEUI_FrameAdvance();
void FCEUI_FrameAdvanceEnd();

///A callback that the emu core uses to poll the state of a given emulator command key
typedef int TestCommandState(int cmd);

///signals the driver to perform a file open GUI operation
void FCEUD_CmdOpen();

//new merge-era driver routines here:

enum EFCEUI {
  FCEUI_STOPAVI, FCEUI_QUICKSAVE, FCEUI_QUICKLOAD, FCEUI_SAVESTATE, FCEUI_LOADSTATE,
  FCEUI_NEXTSAVESTATE,FCEUI_PREVIOUSSAVESTATE,FCEUI_VIEWSLOTS,
  FCEUI_STOPMOVIE, FCEUI_RECORDMOVIE, FCEUI_PLAYMOVIE,
  FCEUI_OPENGAME, FCEUI_CLOSEGAME,
  FCEUI_TASEDITOR,
  FCEUI_RESET, FCEUI_POWER, FCEUI_PLAYFROMBEGINNING, FCEUI_EJECT_DISK, FCEUI_SWITCH_DISK
};

// checks whether an EFCEUI is valid right now
bool FCEU_IsValidUI(EFCEUI ui);

#endif

