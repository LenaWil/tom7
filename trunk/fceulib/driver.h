#ifndef __DRIVER_H_
#define __DRIVER_H_

#include <stdio.h>
#include <string>
#include <iosfwd>

#include "types.h"
#include "git.h"
#include "file.h"

FILE *FCEUD_UTF8fopen(const char *fn, const char *mode);
inline FILE *FCEUD_UTF8fopen(const std::string &n, const char *mode) { 
  return FCEUD_UTF8fopen(n.c_str(),mode); 
}
EMUFILE_FILE* FCEUD_UTF8_fstream(const char *n, const char *m);
inline EMUFILE_FILE* FCEUD_UTF8_fstream(const std::string &n, const char *m) {
  return FCEUD_UTF8_fstream(n.c_str(),m); 
}

const char *FCEUD_GetCompilerString();

// This makes me feel dirty for some reason.
void FCEU_printf(char *format, ...);

// Video interface
void FCEUD_SetPalette(uint8 index, uint8 r, uint8 g, uint8 b);
void FCEUD_GetPalette(uint8 i,uint8 *r, uint8 *g, uint8 *b);

//Displays an error.  Can block or not.
void FCEUD_PrintError(const char *s);

#ifdef FRAMESKIP
/* Should be called from FCEUD_BlitScreen().  Specifies how many frames
   to skip until FCEUD_BlitScreen() is called.  FCEUD_BlitScreenDummy()
   will be called instead of FCEUD_BlitScreen() when when a frame is skipped.
*/
void FCEUI_FrameSkip(int x);
#endif

//First and last scanlines to render, for ntsc and pal emulation.
void FCEUI_SetRenderedLines(int ntscf, int ntscl, int palf, int pall);

void FCEUI_VSUniToggleDIP(int w);
uint8 FCEUI_VSUniGetDIPs();
void FCEUI_VSUniCoin();

int FCEUI_DatachSet(const uint8 *rcode);

//new merge-era driver routines here:

enum EFCEUI {
  FCEUI_RESET, FCEUI_POWER, 
  FCEUI_EJECT_DISK, FCEUI_SWITCH_DISK
};

// checks whether an EFCEUI is valid right now
bool FCEU_IsValidUI(EFCEUI ui);

#endif

