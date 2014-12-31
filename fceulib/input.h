#ifndef _INPUT_H_
#define _INPUT_H_

#include <ostream>

#include "git.h"
#include "state.h"

class MovieRecord;

//MBG TODO - COMBINE THESE INPUTC AND INPUTCFC

//The interface for standard joystick port device drivers
struct INPUTC {
  // these methods call the function pointers (or not, if they are null)
  uint8 Read(int w) { if(_Read) return _Read(w); else return 0; }
  void Write(uint8 w) { if(_Write) _Write(w); }
  void Strobe(int w) { if(_Strobe) _Strobe(w); }
  void Update(int w, void *data, int arg) { if(_Update) _Update(w,data,arg); }
  void SLHook(int w, uint8 *bg, uint8 *spr, uint32 linets, int final) { if(_SLHook) _SLHook(w,bg,spr,linets,final); }
  void Draw(int w, uint8 *buf, int arg) { if(_Draw) _Draw(w,buf,arg); }
  void Log(int w, MovieRecord* mr) { if(_Log) _Log(w,mr); }
  void Load(int w, MovieRecord* mr) { if(_Load) _Load(w,mr); }

  uint8 (*_Read)(int w);
  void (*_Write)(uint8 v);
  void (*_Strobe)(int w);
  // update will be called if input is coming from the user. refresh
  // your logical state from user input devices
  void (*_Update)(int w, void *data, int arg);
  void (*_SLHook)(int w, uint8 *bg, uint8 *spr, uint32 linets, int final);
  void (*_Draw)(int w, uint8 *buf, int arg);

  // log is called when you need to put your logical state into a
  // movie record for recording
  void (*_Log)(int w, MovieRecord* mr);
  // load will be called if input is coming from a movie. refresh your
  // logical state from a movie record
  void (*_Load)(int w, MovieRecord* mr);
};

//The interface for the expansion port device drivers
struct INPUTCFC {
  //these methods call the function pointers (or not, if they are null)
  uint8 Read(int w, uint8 ret) { if(_Read) return _Read(w,ret); else return ret; }
  void Write(uint8 v) { if(_Write) _Write(v); }
  void Strobe() { if(_Strobe) _Strobe(); }
  void Update(void *data, int arg) { if(_Update) _Update(data,arg); }
  void SLHook(uint8 *bg, uint8 *spr, uint32 linets, int final) { 
    if(_SLHook) _SLHook(bg,spr,linets,final); 
  }
  void Draw(uint8 *buf, int arg) { if(_Draw) _Draw(buf,arg); }
  void Log(MovieRecord* mr) { if(_Log) _Log(mr); }
  void Load(MovieRecord* mr) { if(_Load) _Load(mr); }

  uint8 (*_Read)(int w, uint8 ret);
  void (*_Write)(uint8 v);
  void (*_Strobe)();
  // update will be called if input is coming from the user. refresh
  // your logical state from user input devices
  void (*_Update)(void *data, int arg);
  void (*_SLHook)(uint8 *bg, uint8 *spr, uint32 linets, int final);
  void (*_Draw)(uint8 *buf, int arg);

  // log is called when you need to put your logical state into a movie record for recording
  void (*_Log)(MovieRecord* mr);

  // load will be called if input is coming from a movie. refresh your logical state from a movie record
  void (*_Load)(MovieRecord* mr);
};

struct JOYPORT {
  explicit JOYPORT(int w) : w(w) {}

  int w;
  int attrib;
  ESI type;
  void* ptr = nullptr;
  INPUTC* driver = nullptr;

  void log(MovieRecord* mr) { driver->Log(w, mr); }
  void load(MovieRecord* mr) { driver->Load(w, mr); }
};

struct FCPORT {
  int attrib;
  ESIFC type;
  void* ptr;
  INPUTCFC* driver;
};

// Used in movie too. -tom7
extern JOYPORT joyports[2];
extern FCPORT portFC;

void FCEU_DrawInput(uint8 *buf);
void FCEU_UpdateInput(void);
void InitializeInput(void);
void FCEU_UpdateBot(void);
extern void (*PStrobe[2])(void);

//called from PPU on scanline events.
extern void InputScanlineHook(uint8 *bg, uint8 *spr, uint32 linets, int final);

extern unsigned int lagCounter;
extern bool lagCounterDisplay;
extern char lagFlag;
extern bool turbo;
void LagCounterReset();

extern int input_display;

extern const SFORMAT FCEUINPUT_STATEINFO[];

#endif //_INPUT_H_
