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

// -Video Modes Tag- : See --special
char *DriverUsage="\
Option         Value   Description\n\
--pal          {0|1}   Use PAL timing.\n\
--newppu       {0|1}   Enable the new PPU core. (WARNING: May break savestates)\n\
--inputcfg     d       Configures input device d on startup.\n\
--input(1,2)   d       Set which input device to emulate for input 1 or 2.\n\
                         Devices:  gamepad zapper powerpad.0 powerpad.1 arkanoid\n\
--input(3,4)   d       Set the famicom expansion device to emulate for input(3, 4)\n\
                         Devices: quizking hypershot mahjong toprider ftrainer\n\
                         familykeyboard oekakids arkanoid shadow bworld 4player\n\
--gamegenie    {0|1}   Enable emulated Game Genie.\n\
--frameskip    x       Set # of frames to skip per emulated frame.\n\
--xres         x       Set horizontal resolution for full screen mode.\n\
--yres         x       Set vertical resolution for full screen mode.\n\
--autoscale    {0|1}   Enable autoscaling in fullscreen. \n\
--keepratio    {0|1}   Keep native NES aspect ratio when autoscaling. \n\
--(x/y)scale   x       Multiply width/height by x. \n\
                         (Real numbers >0 with OpenGL, otherwise integers >0).\n\
--(x/y)stretch {0|1}   Stretch to fill surface on x/y axis (OpenGL only).\n\
--bpp       {8|16|32}  Set bits per pixel.\n\
--opengl       {0|1}   Enable OpenGL support.\n\
--fullscreen   {0|1}   Enable full screen mode.\n\
--noframe      {0|1}   Hide title bar and window decorations.\n\
--special      {1-4}   Use special video scaling filters\n\
                         (1 = hq2x 2 = Scale2x 3 = NTSC 2x 4 = hq3x 5 = Scale3x)\n\
--palette      f       Load custom global palette from file f.\n\
--sound        {0|1}   Enable sound.\n\
--soundrate    x       Set sound playback rate to x Hz.\n\
--soundq      {0|1|2}  Set sound quality. (0 = Low 1 = High 2 = Very High)\n\
--soundbufsize x       Set sound buffer size to x ms.\n\
--volume      {0-256}  Set volume to x.\n\
--soundrecord  f       Record sound to file f.\n\
--playmov      f       Play back a recorded FCM/FM2/FM3 movie from filename f.\n\
--pauseframe   x       Pause movie playback at frame x.\n\
--ripsubs      f       Convert movie's subtitles to srt\n\
--subtitles    {0,1}   Enable subtitle display\n\
--fourscore    {0,1}   Enable fourscore emulation\n\
--no-config    {0,1}   Use default config file and do not save\n\
--net          s       Connect to server 's' for TCP/IP network play.\n\
--port         x       Use TCP/IP port x for network play.\n\
--user         x       Set the nickname to use in network play.\n\
--pass         x       Set password to use for connecting to the server.\n\
--netkey       s       Use string 's' to create a unique session for the game loaded.\n\
--players      x       Set the number of local players.\n\
--rp2mic       {0,1}   Replace Port 2 Start with microphone (Famicom).\n\
--nogui                Don't load the GTK GUI";


// these should be moved to the man file
//--nospritelim  {0|1}   Disables the 8 sprites per scanline limitation.\n
//--trianglevol {0-256}  Sets Triangle volume.\n
//--square1vol  {0-256}  Sets Square 1 volume.\n
//--square2vol  {0-256}  Sets Square 2 volume.\n
//--noisevol	{0-256}  Sets Noise volume.\n
//--pcmvol	  {0-256}  Sets PCM volume.\n
//--lowpass	  {0|1}   Enables low-pass filter if x is nonzero.\n
//--doublebuf	{0|1}   Enables SDL double-buffering if x is nonzero.\n
//--slend	  {0-239}   Sets the last drawn emulated scanline.\n
//--ntsccolor	{0|1}   Emulates an NTSC TV's colors.\n
//--hue		   x	  Sets hue for NTSC color emulation.\n
//--tint		  x	  Sets tint for NTSC color emulation.\n
//--slstart	{0-239}   Sets the first drawn emulated scanline.\n
//--clipsides	{0|1}   Clips left and rightmost 8 columns of pixels.\n

static void ShowUsage(char *prog) {
  printf("\nUsage is as follows:\n%s <options> filename\n\n",prog);
  puts(DriverUsage);
  puts("");
  //	printf("Compiled with SDL version %d.%d.%d\n", SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL );
  //		const SDL_version* v = SDL_Linked_Version();
  //	printf("Linked with SDL version %d.%d.%d\n", v->major, v->minor, v->patch);
}

/**
 * Loads a game, given a full path/filename.  The driver code must be
 * initialized after the game is loaded, because the emulator code
 * provides data necessary for the driver code(number of scanlines to
 * render, what virtual input devices to use, etc.).
 */
int LoadGame(const char *path) {
#if 0
  CloseGame();
  if(!FCEUI_LoadGame(path, 1)) {
    return 0;
  }
  ParseGIInput(GameInfo);
  RefreshThrottleFPS();

  if(!DriverInitialize(GameInfo)) {
    return(0);
  }
	
  // Set NTSC (1 = pal)
  FCEUI_SetVidSystem(0);

  isloaded = 1;

  return 1;
#endif
}

/**
 * Closes a game.  Frees memory, and deinitializes the drivers.
 */
int CloseGame() {
#if 0
  std::string filename;

  if(!isloaded) {
    return(0);
  }
  FCEUI_CloseGame();
  DriverKill();
  isloaded = 0;
  GameInfo = 0;

  InputUserActiveFix();
  return(1);
#endif
}

void FCEUD_Update(uint8 *XBuf, int32 *Buffer, int Count);

static void DoFun(int frameskip) {
#if 0
  uint8 *gfx;
  int32 *sound;
  int32 ssize;
  static int fskipc = 0;
  static int opause = 0;

#ifdef FRAMESKIP
  fskipc = (fskipc + 1) % (frameskip + 1);
#endif

  if(NoWaiting) {
    gfx = 0;
  }
  FCEUI_Emulate(&gfx, &sound, &ssize, fskipc);
  FCEUD_Update(gfx, sound, ssize);

  if(opause!=FCEUI_EmulationPaused()) {
    opause=FCEUI_EmulationPaused();
    SilenceSound(opause);
  }
#endif
}


/**
 * Initialize all of the subsystem drivers: video, audio, and joystick.
 */
static int DriverInitialize(FCEUGI *gi) {
#if 0
  if(InitVideo(gi) < 0) return 0;
  inited|=4;

  if(InitSound())
    inited|=1;

  if(InitJoysticks())
    inited|=2;

  int fourscore=0;
  g_config->getOption("SDL.FourScore", &fourscore);
  eoptions &= ~EO_FOURSCORE;
  if(fourscore)
    eoptions |= EO_FOURSCORE;

  InitInputInterface();
  return 1;
#endif
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
    ShowUsage(argv[0]);
    return -1;
  }

  if (argc != 2) {
    fprintf(stderr, "Need a ROM on the command line, and nothing else.");
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
  FCEUI_SetVidSystem(0);

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
