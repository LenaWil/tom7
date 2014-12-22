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
FCEUFILE* FCEUD_OpenArchiveIndex(ArchiveScanRecord& asr, std::string& fname, int innerIndex);
FCEUFILE* FCEUD_OpenArchive(ArchiveScanRecord& asr, std::string& fname, std::string* innerFilename);
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

bool FCEUI_BeginWaveRecord(const char *fn);
int FCEUI_EndWaveRecord(void);

void FCEUI_ResetNES(void);
void FCEUI_PowerNES(void);

void FCEUI_NTSCSELHUE(void);
void FCEUI_NTSCSELTINT(void);
void FCEUI_NTSCDEC(void);
void FCEUI_NTSCINC(void);
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

void FCEUI_UseInputPreset(int preset);


//New interface functions

//0 to order screen snapshots numerically(0.png), 1 to order them file base-numerically(smb3-0.png).
//this variable isn't used at all, snap is always name-based
//void FCEUI_SetSnapName(bool a);

//0 to keep 8-sprites limitation, 1 to remove it
void FCEUI_DisableSpriteLimitation(int a);

void FCEUI_SetRenderPlanes(bool sprites, bool bg);
void FCEUI_GetRenderPlanes(bool& sprites, bool& bg);

//name=path and file to load.  returns null if it failed
FCEUGI *FCEUI_LoadGame(const char *name, int OverwriteVidMode);

//same as FCEUI_LoadGame, except that it can load from a tempfile.
//name is the logical path to open; archiveFilename is the archive which contains name
FCEUGI *FCEUI_LoadGameVirtual(const char *name, int OverwriteVidMode);

//general purpose emulator initialization. returns true if successful
bool FCEUI_Initialize();

//Emulates a frame.
void FCEUI_Emulate(uint8 **, int32 **, int32 *, int);

//Closes currently loaded game
void FCEUI_CloseGame(void);

//Deallocates all allocated memory.  Call after FCEUI_Emulate() returns.
void FCEUI_Kill(void);

//Set video system a=0 NTSC, a=1 PAL
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

//Sets the base directory(save states, snapshots, etc. are saved in directories below this directory.
void FCEUI_SetBaseDirectory(std::string const & dir);

//Tells FCE Ultra to copy the palette data pointed to by pal and use it.
//Data pointed to by pal needs to be 64*3 bytes in length.
void FCEUI_SetPaletteArray(uint8 *pal);

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

int FCEUI_SelectState(int, int);
extern void FCEUI_SelectStateNext(int);

//"fname" overrides the default save state filename code if non-NULL.
void FCEUI_SaveState(const char *fname);
void FCEUI_LoadState(const char *fname);

void FCEUD_SaveStateAs(void);
void FCEUD_LoadStateFrom(void);

//at the minimum, you should call FCEUI_SetInput, FCEUI_SetInputFC, and FCEUI_SetInputFourscore
//you may also need to maintain your own internal state
void FCEUD_SetInput(bool fourscore, bool microphone, ESI port0, ESI port1, ESIFC fcexp);


void FCEUD_MovieReplayFrom(void);

void FCEUI_SaveSnapshot(void);
void FCEUI_SaveSnapshotAs(void);
void FCEU_DispMessage(char *format, int disppos, ...);
#define FCEUI_DispMessage FCEU_DispMessage

//.rom
// These are file types for FCEU_GetPath. Probably don't need it. -tom7
#define FCEUIOD_ROMS    0       //Roms
#define FCEUIOD_NV      1       //NV = nonvolatile. save data.
#define FCEUIOD_STATES  2       //savestates
#define FCEUIOD_FDSROM  3       //disksys.rom
#define FCEUIOD_SNAPS   4       //screenshots
#define FCEUIOD_CHEATS  5       //cheats
#define FCEUIOD_MOVIES  6       //.fm2 files
#define FCEUIOD_MEMW    7       //memory watch fiels
#define FCEUIOD_BBOT    8       //basicbot, obsolete
#define FCEUIOD_MACRO   9       //macro files - old TASEdit v0.1 paradigm, not implemented, probably obsolete
#define FCEUIOD_INPUT   10      //input presets
#define FCEUIOD_AVI             11      //default file for avi output
#define FCEUIOD__COUNT  12      //base directory override?

void FCEUI_SetDirOverride(int which, char *n);

void FCEUI_NMI(void);
void FCEUI_IRQ(void);
// uint16 FCEUI_Disassemble(void *XA, uint16 a, char *stringo);
void FCEUI_GetIVectors(uint16 *reset, uint16 *irq, uint16 *nmi);

// uint32 FCEUI_CRC32(uint32 crc, uint8 *buf, uint32 len);

void FCEUI_ToggleTileView(void);
void FCEUI_SetLowPass(int q);

void FCEUI_NSFSetVis(int mode);
int FCEUI_NSFChange(int amount);
int FCEUI_NSFGetInfo(uint8 *name, uint8 *artist, uint8 *copyright, int maxlen);

void FCEUI_VSUniToggleDIPView(void);
void FCEUI_VSUniToggleDIP(int w);
uint8 FCEUI_VSUniGetDIPs(void);
void FCEUI_VSUniSetDIP(int w, int state);
void FCEUI_VSUniCoin(void);

void FCEUI_FDSInsert(void); //mbg merge 7/17/06 changed to void fn(void) to make it an EMUCMDFN
//int FCEUI_FDSEject(void);
void FCEUI_FDSSelect(void);

int FCEUI_DatachSet(const uint8 *rcode);

///returns a flag indicating whether emulation is paused
int FCEUI_EmulationPaused();
///returns a flag indicating whether a one frame step has been requested
int FCEUI_EmulationFrameStepped();
///clears the framestepped flag. use it after youve stepped your one frame
void FCEUI_ClearEmulationFrameStepped();
///sets the EmulationPaused flags
void FCEUI_SetEmulationPaused(int val);
///toggles the paused bit (bit0) for EmulationPaused. caused FCEUD_DebugUpdate() to fire if the emulation pauses
void FCEUI_ToggleEmulationPause();

//indicates whether input aids should be drawn (such as crosshairs, etc; usually in fullscreen mode)
bool FCEUD_ShouldDrawInputAids();

///called when the emulator closes a game
void FCEUD_OnCloseGame(void);

void FCEUI_FrameAdvance(void);
void FCEUI_FrameAdvanceEnd(void);

//AVI Output
int FCEUI_AviBegin(const char* fname);
void FCEUI_AviEnd(void);
void FCEUI_AviVideoUpdate(const unsigned char* buffer);
void FCEUI_AviSoundUpdate(void* soundData, int soundLen);
bool FCEUI_AviIsRecording();
bool FCEUI_AviEnableHUDrecording();
void FCEUI_SetAviEnableHUDrecording(bool enable);
bool FCEUI_AviDisableMovieMessages();
void FCEUI_SetAviDisableMovieMessages(bool disable);

void FCEUD_AviRecordTo(void);
void FCEUD_AviStop(void);

///A callback that the emu core uses to poll the state of a given emulator command key
typedef int TestCommandState(int cmd);

int FCEUD_ShowStatusIcon(void);
void FCEUD_ToggleStatusIcon(void);
void FCEUD_HideMenuToggle(void);

///signals the driver to perform a file open GUI operation
void FCEUD_CmdOpen(void);

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

#endif //__DRIVER_H_
