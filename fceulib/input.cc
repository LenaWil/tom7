/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 1998 BERO
*  Copyright (C) 2002 Xodnizel
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include <string>
#include <ostream>
#include <string.h>

#include "types.h"
#include "x6502.h"

#include "fceu.h"
#include "sound.h"
#include "netplay.h"
#include "movie.h"
#include "state.h"
#include "input/zapper.h"
#include "input.h"
#include "vsuni.h"
#include "fds.h"
#include "driver.h"

void FCEU_DoSimpleCommand(int cmd);
void FCEU_QSimpleCommand(int cmd);

enum EMUCMD {
	EMUCMD_POWER=0,
	EMUCMD_RESET,
	EMUCMD_PAUSE,
	EMUCMD_FRAME_ADVANCE,
	EMUCMD_HIDE_MENU_TOGGLE,
	//fixed: current command key handling handle only command table record index with
	//the same as cmd enumerarot index, or else does wrong key mapping, fixed it but placed this enum here anyway
	//...i returned it back.
	//adelikat, try to find true cause of problem before reversing it
	EMUCMD_EXIT,

	EMUCMD_SPEED_SLOWEST,
	EMUCMD_SPEED_SLOWER,
	EMUCMD_SPEED_NORMAL,
	EMUCMD_SPEED_FASTER,
	EMUCMD_SPEED_FASTEST,
	EMUCMD_SPEED_TURBO,
	EMUCMD_SPEED_TURBO_TOGGLE,

	EMUCMD_SAVE_SLOT_0,
	EMUCMD_SAVE_SLOT_1,
	EMUCMD_SAVE_SLOT_2,
	EMUCMD_SAVE_SLOT_3,
	EMUCMD_SAVE_SLOT_4,
	EMUCMD_SAVE_SLOT_5,
	EMUCMD_SAVE_SLOT_6,
	EMUCMD_SAVE_SLOT_7,
	EMUCMD_SAVE_SLOT_8,
	EMUCMD_SAVE_SLOT_9,
	EMUCMD_SAVE_SLOT_NEXT,
	EMUCMD_SAVE_SLOT_PREV,
	EMUCMD_SAVE_STATE,
	EMUCMD_SAVE_STATE_AS,
	EMUCMD_SAVE_STATE_SLOT_0,
	EMUCMD_SAVE_STATE_SLOT_1,
	EMUCMD_SAVE_STATE_SLOT_2,
	EMUCMD_SAVE_STATE_SLOT_3,
	EMUCMD_SAVE_STATE_SLOT_4,
	EMUCMD_SAVE_STATE_SLOT_5,
	EMUCMD_SAVE_STATE_SLOT_6,
	EMUCMD_SAVE_STATE_SLOT_7,
	EMUCMD_SAVE_STATE_SLOT_8,
	EMUCMD_SAVE_STATE_SLOT_9,
	EMUCMD_LOAD_STATE,
	EMUCMD_LOAD_STATE_FROM,
	EMUCMD_LOAD_STATE_SLOT_0,
	EMUCMD_LOAD_STATE_SLOT_1,
	EMUCMD_LOAD_STATE_SLOT_2,
	EMUCMD_LOAD_STATE_SLOT_3,
	EMUCMD_LOAD_STATE_SLOT_4,
	EMUCMD_LOAD_STATE_SLOT_5,
	EMUCMD_LOAD_STATE_SLOT_6,
	EMUCMD_LOAD_STATE_SLOT_7,
	EMUCMD_LOAD_STATE_SLOT_8,
	EMUCMD_LOAD_STATE_SLOT_9,

	EMUCMD_SCRIPT_RELOAD,

	EMUCMD_AVI_RECORD_AS,
	EMUCMD_AVI_STOP,

	EMUCMD_FDS_EJECT_INSERT,
	EMUCMD_FDS_SIDE_SELECT,

	EMUCMD_VSUNI_COIN,
	EMUCMD_VSUNI_TOGGLE_DIP_0,
	EMUCMD_VSUNI_TOGGLE_DIP_1,
	EMUCMD_VSUNI_TOGGLE_DIP_2,
	EMUCMD_VSUNI_TOGGLE_DIP_3,
	EMUCMD_VSUNI_TOGGLE_DIP_4,
	EMUCMD_VSUNI_TOGGLE_DIP_5,
	EMUCMD_VSUNI_TOGGLE_DIP_6,
	EMUCMD_VSUNI_TOGGLE_DIP_7,
	EMUCMD_VSUNI_TOGGLE_DIP_8,
	EMUCMD_VSUNI_TOGGLE_DIP_9,
	EMUCMD_MISC_AUTOSAVE,
	EMUCMD_MISC_SHOWSTATES,
	EMUCMD_MISC_USE_INPUT_PRESET_1,
	EMUCMD_MISC_USE_INPUT_PRESET_2,
	EMUCMD_MISC_USE_INPUT_PRESET_3,
	EMUCMD_MISC_DISPLAY_BG_TOGGLE,
	EMUCMD_MISC_DISPLAY_OBJ_TOGGLE,

	//Currently Windows only------
	EMUCMD_MISC_OPENTASEDITOR,
	EMUCMD_TOOL_OPENMEMORYWATCH,
	EMUCMD_TOOL_OPENCHEATS,
	EMUCMD_TOOL_OPENDEBUGGER,
	EMUCMD_TOOL_OPENHEX,
	EMUCMD_TOOL_OPENPPU,
	EMUCMD_TOOL_OPENTRACELOGGER,
	EMUCMD_TOOL_OPENCDLOGGER,
	//----------------------------
	EMUCMD_FRAMEADV_SKIPLAG,
	//Currently only windows (but sdl could easily add onto these)
	EMUCMD_OPENROM,
	EMUCMD_CLOSEROM,
	EMUCMD_RELOAD,
	//-----------------------------
	EMUCMD_MISC_DISPLAY_MOVIESUBTITLES,
	EMUCMD_MISC_UNDOREDOSAVESTATE,

	EMUCMD_TOOL_OPENNTVIEW,
	EMUCMD_RERECORD_DISPLAY_TOGGLE,
	//-----------------------------

	EMUCMD_MAX
};

enum EMUCMDTYPE {
  EMUCMDTYPE_MISC=0,
  EMUCMDTYPE_SPEED,
  EMUCMDTYPE_STATE,
  EMUCMDTYPE_MOVIE,
  EMUCMDTYPE_SOUND,
  EMUCMDTYPE_AVI,
  EMUCMDTYPE_FDS,
  EMUCMDTYPE_VSUNI,
  EMUCMDTYPE_TOOL,  //All Tools type are currenty windows only programs

  EMUCMDTYPE_MAX
};

typedef void EMUCMDFN(void);

enum EMUCMDFLAG {
  EMUCMDFLAG_NONE = 0,
  EMUCMDFLAG_TASEDITOR = 1,
};

struct EMUCMDTABLE {
  int cmd;
  int type;
  EMUCMDFN* fn_on;
  EMUCMDFN* fn_off;
  int state;
  char* name;
  int flags; //EMUCMDFLAG
};

//it is easier to declare these input drivers extern here than include a bunch of files
//-------------
extern INPUTC *FCEU_InitZapper(int w);
extern INPUTC *FCEU_InitPowerpadA(int w);
extern INPUTC *FCEU_InitPowerpadB(int w);
extern INPUTC *FCEU_InitArkanoid(int w);

extern INPUTCFC *FCEU_InitArkanoidFC(void);
extern INPUTCFC *FCEU_InitSpaceShadow(void);
extern INPUTCFC *FCEU_InitFKB(void);
extern INPUTCFC *FCEU_InitSuborKB(void);
extern INPUTCFC *FCEU_InitHS(void);
extern INPUTCFC *FCEU_InitMahjong(void);
extern INPUTCFC *FCEU_InitQuizKing(void);
extern INPUTCFC *FCEU_InitFamilyTrainerA(void);
extern INPUTCFC *FCEU_InitFamilyTrainerB(void);
extern INPUTCFC *FCEU_InitOekaKids(void);
extern INPUTCFC *FCEU_InitTopRider(void);
extern INPUTCFC *FCEU_InitBarcodeWorld(void);
//---------------

//global lag variables
char lagFlag;
//-------------

static uint8 joy_readbit[2];
uint8 joy[4]={0,0,0,0}; //HACK - should be static but movie needs it
static uint8 LastStrobe;

bool replaceP2StartWithMicrophone = false;

//This function is a quick hack to get the NSF player to use emulated gamepad input.
uint8 FCEU_GetJoyJoy(void) {
  return joy[0] | joy[1] | joy[2] | joy[3];
}

extern uint8 coinon;

//set to true if the fourscore is attached
static bool FSAttached = false;

// Joyports are where the emulator looks to find input during simulation.
// They're set by FCEUI_SetInput. Each joyport knows its index (w), type,
// and pointer to data. I think the data pointer for two gamepads is usually
// the same. -tom7
//
// Ultimately these get copied into joy[4]. I don't know which is which
// (see the confusing UpdateGP below) but it seems joy[0] is the least significant
// byte of the pointer. -tom7
JOYPORT joyports[2] = { JOYPORT(0), JOYPORT(1) };
FCPORT portFC;

static DECLFR(JPRead)
{
	lagFlag = 0;
	uint8 ret=0;
	static bool microphone = false;

	ret|=joyports[A&1].driver->Read(A&1);

	// Test if the port 2 start button is being pressed.
	// On a famicom, port 2 start shouldn't exist, so this removes it.
	// Games can't automatically be checked for NES/Famicom status,
	// so it's an all-encompassing change in the input config menu.
	if ((replaceP2StartWithMicrophone) && (A&1) && (joy_readbit[1] == 4)) {
	// Nullify Port 2 Start Button
	ret&=0xFE;
	}

	if(portFC.driver)
		ret = portFC.driver->Read(A&1,ret);

	// Not verified against hardware.
	if (replaceP2StartWithMicrophone) {
		if (joy[1]&8) {
			microphone = !microphone;
			if (microphone) {
				ret|=4;
			}
		} else {
			microphone = false;
		}
	}

	ret|=X.DB&0xC0;

	return(ret);
}

static DECLFW(B4016)
{
	if(portFC.driver)
		portFC.driver->Write(V&7);

	for(int i=0;i<2;i++)
		joyports[i].driver->Write(V&1);

	if((LastStrobe&1) && (!(V&1)))
	{
		//old comment:
		//This strobe code is just for convenience.  If it were
		//with the code in input / *.c, it would more accurately represent
		//what's really going on.  But who wants accuracy? ;)
		//Seriously, though, this shouldn't be a problem.
		//new comment:

		//mbg 6/7/08 - I guess he means that the input drivers could track the strobing themselves
		//I dont see why it is unreasonable here.
		for(int i=0;i<2;i++)
			joyports[i].driver->Strobe(i);
		if(portFC.driver)
			portFC.driver->Strobe();
	}
	LastStrobe=V&0x1;
}

//a main joystick port driver representing the case where nothing is plugged in
static INPUTC DummyJPort={0,0,0,0,0,0};
//and an expansion port driver for the same ting
static INPUTCFC DummyPortFC={0,0,0,0,0,0};


//--------4 player driver for expansion port--------
static uint8 F4ReadBit[2];
static void StrobeFami4(void)
{
	F4ReadBit[0]=F4ReadBit[1]=0;
}

static uint8 ReadFami4(int w, uint8 ret)
{
	ret&=1;

	ret |= ((joy[2+w]>>(F4ReadBit[w]))&1)<<1;
	if(F4ReadBit[w]>=8) ret|=2;
	else F4ReadBit[w]++;

	return(ret);
}

static INPUTCFC FAMI4C={ReadFami4,0,StrobeFami4,0,0,0};
//------------------

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


static uint8 ReadGPVS(int w)
{
	uint8 ret=0;

	if(joy_readbit[w]>=8)
		ret=1;
	else
	{
		ret = ((joy[w]>>(joy_readbit[w]))&1);
		if(!fceuindbg)
			joy_readbit[w]++;
	}
	return ret;
}

static void UpdateGP(int w, void *data, int arg) {
  if(w==0) {
    joy[0] = *(uint32 *)joyports[0].ptr;;
    joy[2] = *(uint32 *)joyports[0].ptr >> 16;
  } else {
    joy[1] = *(uint32 *)joyports[1].ptr >> 8;
    joy[3] = *(uint32 *)joyports[1].ptr >> 24;
  }
}

static void LogGP(int w, MovieRecord* mr)
{
	if(w==0)
	{
		mr->joysticks[0] = joy[0];
		mr->joysticks[2] = joy[2];
	}
	else
	{
		mr->joysticks[1] = joy[1];
		mr->joysticks[3] = joy[3];
	}
}

static void LoadGP(int w, MovieRecord* mr)
{
	if(w==0)
	{
		joy[0] = mr->joysticks[0];
		if(FSAttached) joy[2] = mr->joysticks[2];
	}
	else
	{
		joy[1] = mr->joysticks[1];
		if(FSAttached) joy[3] = mr->joysticks[3];
	}
}


//basic joystick port driver
static uint8 ReadGP(int w)
{
	uint8 ret;

	if(joy_readbit[w]>=8)
		ret = ((joy[2+w]>>(joy_readbit[w]&7))&1);
	else
		ret = ((joy[w]>>(joy_readbit[w]))&1);
	if(joy_readbit[w]>=16) ret=0;
	if(!FSAttached)
	{
		if(joy_readbit[w]>=8) ret|=1;
	}
	else
	{
		if(joy_readbit[w]==19-w) ret|=1;
	}
	if(!fceuindbg)
		joy_readbit[w]++;
	return ret;
}

static void StrobeGP(int w)
{
	joy_readbit[w]=0;
}

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^6


static INPUTC GPC={ReadGP,0,StrobeGP,UpdateGP,0,0,LogGP,LoadGP};
static INPUTC GPCVS={ReadGPVS,0,StrobeGP,UpdateGP,0,0,LogGP,LoadGP};

void FCEU_DrawInput(uint8 *buf)
{
	for(int pad=0;pad<2;pad++)
		joyports[pad].driver->Draw(pad,buf,joyports[pad].attrib);
	if(portFC.driver)
		portFC.driver->Draw(buf,portFC.attrib);
}


void FCEU_UpdateInput(void)
{
	//tell all drivers to poll input and set up their logical states
	if(!FCEUMOV_Mode(MOVIEMODE_PLAY))
	{
		for(int port=0;port<2;port++)
			joyports[port].driver->Update(port,joyports[port].ptr,joyports[port].attrib);
		portFC.driver->Update(portFC.ptr,portFC.attrib);
	}

	if(GameInfo->type==GIT_VSUNI)
		if(coinon) coinon--;

	FCEUMOV_AddInputState();

	//TODO - should this apply to the movie data? should this be displayed in the input hud?
	if(GameInfo->type==GIT_VSUNI)
		FCEU_VSUniSwap(&joy[0],&joy[1]);
}

static DECLFR(VSUNIRead0)
{
	lagFlag = 0;
	uint8 ret=0;

	ret|=(joyports[0].driver->Read(0))&1;

	ret|=(vsdip&3)<<3;
	if(coinon)
		ret|=0x4;
	return ret;
}

static DECLFR(VSUNIRead1)
{
	lagFlag = 0;
	uint8 ret=0;

	ret|=(joyports[1].driver->Read(1))&1;
	ret|=vsdip&0xFC;
	return ret;
}



//calls from the ppu;
//calls the SLHook for any driver that needs it
void InputScanlineHook(uint8 *bg, uint8 *spr, uint32 linets, int final)
{
	for(int port=0;port<2;port++)
		joyports[port].driver->SLHook(port,bg,spr,linets,final);
	portFC.driver->SLHook(bg,spr,linets,final);
}

//binds JPorts[pad] to the driver specified in JPType[pad]
static void SetInputStuff(int port) {
  switch(joyports[port].type) {
    case SI_GAMEPAD:
      if(GameInfo->type==GIT_VSUNI)
	joyports[port].driver = &GPCVS;
      else
	joyports[port].driver= &GPC;
      break;
    case SI_ARKANOID:
      joyports[port].driver=FCEU_InitArkanoid(port);
      break;
    case SI_ZAPPER:
      joyports[port].driver=FCEU_InitZapper(port);
      break;
    case SI_POWERPADA:
      joyports[port].driver=FCEU_InitPowerpadA(port);
      break;
    case SI_POWERPADB:
      joyports[port].driver=FCEU_InitPowerpadB(port);
      break;
    case SI_NONE:
      joyports[port].driver=&DummyJPort;
      break;
    default:;
    }
}

static void SetInputStuffFC() {
  switch(portFC.type) {
  case SIFC_NONE:
    portFC.driver=&DummyPortFC;
    break;
  case SIFC_ARKANOID:
    portFC.driver=FCEU_InitArkanoidFC();
    break;
  case SIFC_SHADOW:
    portFC.driver=FCEU_InitSpaceShadow();
    break;
  case SIFC_OEKAKIDS:
    portFC.driver=FCEU_InitOekaKids();
    break;
  case SIFC_4PLAYER:
    portFC.driver=&FAMI4C;
    memset(&F4ReadBit,0,sizeof(F4ReadBit));
    break;
  case SIFC_FKB:
    portFC.driver=FCEU_InitFKB();
    break;
  case SIFC_SUBORKB:
    portFC.driver=FCEU_InitSuborKB();
    break;
  case SIFC_HYPERSHOT:
    portFC.driver=FCEU_InitHS();
    break;
  case SIFC_MAHJONG:
    portFC.driver=FCEU_InitMahjong();
    break;
  case SIFC_QUIZKING:
    portFC.driver=FCEU_InitQuizKing();
    break;
  case SIFC_FTRAINERA:
    portFC.driver=FCEU_InitFamilyTrainerA();
    break;
  case SIFC_FTRAINERB:
    portFC.driver=FCEU_InitFamilyTrainerB();
    break;
  case SIFC_BWORLD:
    portFC.driver=FCEU_InitBarcodeWorld();
    break;
  case SIFC_TOPRIDER:
    portFC.driver=FCEU_InitTopRider();
    break;
  default:;
  }
}

void FCEUI_SetInput(int port, ESI type, void *ptr, int attrib) {
  joyports[port].attrib = attrib;
  joyports[port].type = type;
  joyports[port].ptr = ptr;
  SetInputStuff(port);
}

void FCEUI_SetInputFC(ESIFC type, void *ptr, int attrib) {
  portFC.attrib = attrib;
  portFC.type = type;
  portFC.ptr = ptr;
  SetInputStuffFC();
}


//initializes the input system to power-on state
void InitializeInput(void) {
  memset(joy_readbit,0,sizeof(joy_readbit));
  memset(joy,0,sizeof(joy));
  LastStrobe = 0;

  if(GameInfo->type==GIT_VSUNI) {
    SetReadHandler(0x4016,0x4016,VSUNIRead0);
    SetReadHandler(0x4017,0x4017,VSUNIRead1);
  } else {
    SetReadHandler(0x4016,0x4017,JPRead);
  }

  SetWriteHandler(0x4016,0x4016,B4016);

  //force the port drivers to be setup
  SetInputStuff(0);
  SetInputStuff(1);
  SetInputStuffFC();
}


bool FCEUI_GetInputFourscore() {
  return FSAttached;
}

bool FCEUI_GetInputMicrophone() {
  return replaceP2StartWithMicrophone;
}

void FCEUI_SetInputFourscore(bool attachFourscore) {
  FSAttached = attachFourscore;
}

//mbg 6/18/08 HACK
extern ZAPPER ZD[2];
SFORMAT FCEUCTRL_STATEINFO[]={
  { joy_readbit,	2, "JYRB"},
  { joy,		4, "JOYS"},
  { &LastStrobe,	1, "LSTS"},
  { &ZD[0].bogo,	1, "ZBG0"},
  { &ZD[1].bogo,	1, "ZBG1"},
  { &lagFlag,		1, "LAGF"},
  { &lagCounter,	4, "LAGC"},
  { &currFrameCounter,  4, "FRAM"},
  { 0 }
};


void FCEUI_FDSSelect(void) {
	if(!FCEU_IsValidUI(FCEUI_SWITCH_DISK))
		return;

	FCEU_DispMessage("Command: Switch disk side", 0);
	FCEU_QSimpleCommand(FCEUNPCMD_FDSSELECT);
}

void FCEUI_FDSInsert(void) {
	if(!FCEU_IsValidUI(FCEUI_EJECT_DISK))
		return;

	FCEU_DispMessage("Command: Insert/Eject disk", 0);
	FCEU_QSimpleCommand(FCEUNPCMD_FDSINSERT);
}

void FCEUI_VSUniToggleDIP(int w)
{
	FCEU_QSimpleCommand(FCEUNPCMD_VSUNIDIP0 + w);
}

void FCEUI_VSUniCoin(void)
{
	FCEU_QSimpleCommand(FCEUNPCMD_VSUNICOIN);
}

//Resets the frame counter if movie inactive and rom is reset or power-cycle
static void ResetFrameCounter()
{
extern EMOVIEMODE movieMode;
	if(movieMode == MOVIEMODE_INACTIVE)
		currFrameCounter = 0;
}

//Resets the NES
void FCEUI_ResetNES(void)
{
	if(!FCEU_IsValidUI(FCEUI_RESET))
		return;

	FCEU_DispMessage("Command: Soft reset", 0);
	FCEU_QSimpleCommand(FCEUNPCMD_RESET);
	ResetFrameCounter();
}

//Powers off the NES
void FCEUI_PowerNES(void)
{
	if(!FCEU_IsValidUI(FCEUI_POWER))
		return;

	FCEU_DispMessage("Command: Power switch", 0);
	FCEU_QSimpleCommand(FCEUNPCMD_POWER);
	ResetFrameCounter();
}

void FCEU_DoSimpleCommand(int cmd) {
  switch(cmd) {
  case FCEUNPCMD_FDSINSERT: FCEU_FDSInsert();break;
  case FCEUNPCMD_FDSSELECT: FCEU_FDSSelect();break;
  case FCEUNPCMD_VSUNICOIN: FCEU_VSUniCoin(); break;
  case FCEUNPCMD_VSUNIDIP0:
  case FCEUNPCMD_VSUNIDIP0+1:
  case FCEUNPCMD_VSUNIDIP0+2:
  case FCEUNPCMD_VSUNIDIP0+3:
  case FCEUNPCMD_VSUNIDIP0+4:
  case FCEUNPCMD_VSUNIDIP0+5:
  case FCEUNPCMD_VSUNIDIP0+6:
  case FCEUNPCMD_VSUNIDIP0+7:	FCEU_VSUniToggleDIP(cmd - FCEUNPCMD_VSUNIDIP0);break;
  case FCEUNPCMD_POWER: PowerNES();break;
  case FCEUNPCMD_RESET: ResetNES();break;
  }
}

void FCEU_QSimpleCommand(int cmd) {
  if(!FCEUMOV_Mode(MOVIEMODE_TASEDITOR)) {
    // TAS Editor will do the command himself
    FCEU_DoSimpleCommand(cmd);
  }
  if(FCEUMOV_Mode(MOVIEMODE_RECORD|MOVIEMODE_TASEDITOR)) {
    // I broke this function btw -tom7
    FCEUMOV_AddCommand(cmd);
  }
}
