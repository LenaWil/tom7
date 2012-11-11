#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <limits.h>
#include <math.h>

#include "config.h"

#include "fceu/driver.h"
// #include "fceu/drivers/common/config.h"
#include "fceu/drivers/common/args.h"

#include "fceu/drivers/common/cheat.h"
#include "fceu/fceu.h"
#include "fceu/movie.h"
#include "fceu/version.h"

// #include "fceu/drivers/common/configSys.h"
#include "fceu/oldmovie.h"
#include "fceu/types.h"

extern double g_fpsScale;

int CloseGame(void);

static int inited = 0;

int eoptions=0;

static void DriverKill(void);
static int DriverInitialize(FCEUGI *gi);

static int noconfig;

// Joystick data. I think used for both controller 0 and 1. Part of
// the "API".
static uint32 joydata = 0;

/**
 * Loads a game, given a full path/filename.  The driver code must be
 * initialized after the game is loaded, because the emulator code
 * provides data necessary for the driver code(number of scanlines to
 * render, what virtual input devices to use, etc.).
 */
int LoadGame(const char *path) {
  CloseGame();
  if(!FCEUI_LoadGame(path, 1)) {
    return 0;
  }

  // Here we used to do ParseGIInput, which allows the gameinfo
  // to override our input config, or something like that. No
  // weird stuff. Skip it.

  // RefreshThrottleFPS();

  if(!DriverInitialize(GameInfo)) {
    return(0);
  }
	
  // Set NTSC (1 = pal)
  FCEUI_SetVidSystem(GIV_NTSC);

  return 1;
}

/**
 * Closes a game.  Frees memory, and deinitializes the drivers.
 */
int CloseGame() {
  FCEUI_CloseGame();
  DriverKill();
  GameInfo = 0;
  return 1;
}

void FCEUD_Update(uint8 *XBuf, int32 *Buffer, int Count);

static void DoFun(int frameskip) {
  uint8 *gfx;
  int32 *sound;
  int32 ssize;
  static int fskipc = 0;
  static int opause = 0;

#ifdef FRAMESKIP
  fskipc = (fskipc + 1) % (frameskip + 1);
#endif

  gfx = 0;
  FCEUI_Emulate(&gfx, &sound, &ssize, fskipc);
  FCEUD_Update(gfx, sound, ssize);

  uint8 v = RAM[0x0009];
  uint8 s = RAM[0x000B];  // Should be 77.
  fprintf(stderr, "%02x %02x\n", v, s);

  // uint8 FCEUI_MemSafePeek(uint16 A);
  // void FCEUI_MemPoke(uint16 a, uint8 v, int hl);

//  if(opause!=FCEUI_EmulationPaused()) {
//    opause=FCEUI_EmulationPaused();
//    SilenceSound(opause);
//  }
}


/**
 * Initialize all of the subsystem drivers: video, audio, and joystick.
 */
static int DriverInitialize(FCEUGI *gi) {
  // Used to init video. I think it's safe to skip.

  // Here we initialized sound. Assuming it's safe to skip,
  // because of an early return if config turned it off.

  // Used to init joysticks. Don't care about that.

  // No fourscore support.
  // eoptions &= ~EO_FOURSCORE;

  // Why do both point to the same joydata? -tom
  FCEUI_SetInput (0, SI_GAMEPAD, &joydata, 0);
  FCEUI_SetInput (1, SI_GAMEPAD, &joydata, 0);

  FCEUI_SetInputFourscore (false);
  return 1;
}

/**
 * Shut down all of the subsystem drivers: video, audio, and joystick.
 */
static void DriverKill() {
#if 0
  if (!noconfig)
    g_config->save();

  if(inited&2)
    KillJoysticks();
  if(inited&4)
    KillVideo();
  if(inited&1)
    KillSound();
  inited=0;
#endif
}

/**
 * Update the video, audio, and input subsystems with the provided
 * video (XBuf) and audio (Buffer) information.
 */
void FCEUD_Update(uint8 *XBuf, int32 *Buffer, int Count) {
#if 0
  extern int FCEUDnetplay;

  int ocount = Count;
  // apply frame scaling to Count
  Count = (int)(Count / g_fpsScale);
  if(Count) {
    int32 can=GetWriteSound();
    static int uflow=0;
    int32 tmpcan;

    // don't underflow when scaling fps
    if(can >= GetMaxSound() && g_fpsScale==1.0) uflow=1;	/* Go into massive underflow mode. */

    if(can > Count) can=Count;
    else uflow=0;

    WriteSound(Buffer,can);

    //if(uflow) puts("Underflow");
    tmpcan = GetWriteSound();
    // don't underflow when scaling fps
    if(g_fpsScale>1.0 || ((tmpcan < Count*0.90) && !uflow)) {
      if(XBuf && (inited&4) && !(NoWaiting & 2))
	BlitScreen(XBuf);
      Buffer+=can;
      Count-=can;
      if(Count) {
	if(NoWaiting) {
	  can=GetWriteSound();
	  if(Count>can) Count=can;
	  WriteSound(Buffer,Count);
	} else {
	  while(Count>0) {
	    WriteSound(Buffer,(Count<ocount) ? Count : ocount);
	    Count -= ocount;
	  }
	}
      }
    } //else puts("Skipped");
    else if(!NoWaiting && FCEUDnetplay && (uflow || tmpcan >= (Count * 1.8))) {
      if(Count > tmpcan) Count=tmpcan;
      while(tmpcan > 0) {
	//	printf("Overwrite: %d\n", (Count <= tmpcan)?Count : tmpcan);
	WriteSound(Buffer, (Count <= tmpcan)?Count : tmpcan);
	tmpcan -= Count;
      }
    }

  } else {
    if(!NoWaiting && (!(eoptions&EO_NOTHROTTLE) || FCEUI_EmulationPaused()))
      while (SpeedThrottle())
	{
	  FCEUD_UpdateInput();
	}
    if(XBuf && (inited&4)) {
      BlitScreen(XBuf);
    }
  }
  FCEUD_UpdateInput();
  //if(!Count && !NoWaiting && !(eoptions&EO_NOTHROTTLE))
  // SpeedThrottle();
  //if(XBuf && (inited&4))
  //{
  // BlitScreen(XBuf);
  //}
  //if(Count)
  // WriteSound(Buffer,Count,NoWaiting);
  //FCEUD_UpdateInput();
#endif
}

/**
 * Opens a file to be read a byte at a time.
 */
EMUFILE_FILE* FCEUD_UTF8_fstream(const char *fn, const char *m)
{
  std::ios_base::openmode mode = std::ios_base::binary;
  if(!strcmp(m,"r") || !strcmp(m,"rb"))
    mode |= std::ios_base::in;
  else if(!strcmp(m,"w") || !strcmp(m,"wb"))
    mode |= std::ios_base::out | std::ios_base::trunc;
  else if(!strcmp(m,"a") || !strcmp(m,"ab"))
    mode |= std::ios_base::out | std::ios_base::app;
  else if(!strcmp(m,"r+") || !strcmp(m,"r+b"))
    mode |= std::ios_base::in | std::ios_base::out;
  else if(!strcmp(m,"w+") || !strcmp(m,"w+b"))
    mode |= std::ios_base::in | std::ios_base::out | std::ios_base::trunc;
  else if(!strcmp(m,"a+") || !strcmp(m,"a+b"))
    mode |= std::ios_base::in | std::ios_base::out | std::ios_base::app;
  return new EMUFILE_FILE(fn, m);
  //return new std::fstream(fn,mode);
}

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  int error, frameskip;

  fprintf(stderr, "Starting " FCEU_NAME_AND_VERSION "...\n");

  // (Here's where SDL was initialized.)

  // Initialize the configuration system
  InitConfig();
  if (!global_config) {
    return -1;
  }

  // initialize the infrastructure
  error = FCEUI_Initialize();
  if (error != 1) {
    fprintf(stderr, "Error initializing.\n");
    return -1;
  }

  if (argc != 2) {
    fprintf(stderr, "Need a ROM on the command line, and nothing else.\n");
    return -1;
  }
  
  const char *romfile = argv[1];

  std::string s;

  // (init video was here.)
  // I don't think it's necessary -- just sets up the SDL window and so on.

  // (input config was here.) InputCfg(string value of --inputcfg)

  // UpdateInput(g_config) was here.
  // This is just a bunch of fancy stuff to choose which controllers we have
  // and what they're mapped to.
  // I think the important functions are FCEUD_UpdateInput()
  // and FCEUD_SetInput
  // Calling FCEUI_SetInputFC ((ESIFC) CurInputType[2], InputDPtr, attrib);
  //   and FCEUI_SetInputFourscore ((eoptions & EO_FOURSCORE) != 0);
	
  // No HUD recording to AVI.
  FCEUI_SetAviEnableHUDrecording(false);

  // No Movie messages.
  FCEUI_SetAviDisableMovieMessages(false);

  // defaults
  const int ntsccol = 0, ntsctint = 56, ntschue = 72;
  FCEUI_SetNTSCTH(ntsccol, ntsctint, ntschue);

  // Set NTSC (1 = pal)
  FCEUI_SetVidSystem(GIV_NTSC);

  FCEUI_SetGameGenie(0);

  // Default. Sound thing.
  FCEUI_SetLowPass(0);

  // Default.
  FCEUI_DisableSpriteLimitation(1);

  // Defaults.
  const int scanlinestart = 0, scanlineend = 239;

  // What is this? -tom7
#if DOING_SCANLINE_CHECKS
  for(int i = 0; i < 2; x++) {
    if(srendlinev[x]<0 || srendlinev[x]>239) srendlinev[x]=0;
    if(erendlinev[x]<srendlinev[x] || erendlinev[x]>239) erendlinev[x]=239;
  }
#endif

  FCEUI_SetRenderedLines(scanlinestart + 8, scanlineend - 8, 
			 scanlinestart, scanlineend);


  {
    extern int input_display, movieSubtitles;
    input_display = 0;
    extern int movieSubtitles;
    movieSubtitles = 0;
  }

  // Load the game.
  if (1 != LoadGame(romfile)) {
    DriverKill();
    return -1;
  }


  // Default.
  newppu = 0;

  // Default.
  frameskip = 0;

  // loop playing the game

  while(GameInfo)
    DoFun(frameskip);

  CloseGame();

  // exit the infrastructure
  FCEUI_Kill();
  return 0;
}

/**
 * Get the time in ticks.
 */
uint64 FCEUD_GetTime() {
  //	return SDL_GetTicks();
  abort();
  return 0;
}

/**
 * Get the tick frequency in Hz.
 */
uint64 FCEUD_GetTimeFreq(void) {
  // SDL_GetTicks() is in milliseconds
  return 1000;
}
