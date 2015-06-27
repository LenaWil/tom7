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
#include "state.h"
#include "input/zapper.h"
#include "input.h"
#include "vsuni.h"
#include "fds.h"
#include "driver.h"

#include "tracing.h"

// These are from netplay and should be killed
#define FCEUNPCMD_RESET   0x01
#define FCEUNPCMD_POWER   0x02

#define FCEUNPCMD_VSUNICOIN     0x07
#define FCEUNPCMD_VSUNIDIP0	0x08
#define FCEUNPCMD_FDSINSERTx	0x10
#define FCEUNPCMD_FDSINSERT	0x18
#define FCEUNPCMD_FDSSELECT	0x1A

#define FCEUNPCMD_LOADSTATE     0x80

#define FCEUNPCMD_SAVESTATE     0x81 /* Sent from server to client. */
#define FCEUNPCMD_LOADCHEATS	0x82
#define FCEUNPCMD_TEXT		0x90

//it is easier to declare these input drivers extern here than include a bunch of files
//-------------
extern INPUTC *FCEU_InitZapper(int w);
extern INPUTC *FCEU_InitPowerpadA(int w);
extern INPUTC *FCEU_InitPowerpadB(int w);
extern INPUTC *FCEU_InitArkanoid(int w);

extern INPUTCFC *FCEU_InitArkanoidFC();
extern INPUTCFC *FCEU_InitSpaceShadow();
extern INPUTCFC *FCEU_InitFKB();
extern INPUTCFC *FCEU_InitSuborKB();
extern INPUTCFC *FCEU_InitHS();
extern INPUTCFC *FCEU_InitMahjong();
extern INPUTCFC *FCEU_InitQuizKing();
extern INPUTCFC *FCEU_InitFamilyTrainerA();
extern INPUTCFC *FCEU_InitFamilyTrainerB();
extern INPUTCFC *FCEU_InitOekaKids();
extern INPUTCFC *FCEU_InitTopRider();
extern INPUTCFC *FCEU_InitBarcodeWorld();
//---------------

Input fceulib__input;

static constexpr bool replaceP2StartWithMicrophone = false;

//This function is a quick hack to get the NSF player to use emulated gamepad input.
uint8 Input::FCEU_GetJoyJoy() {
  return joy[0] | joy[1] | joy[2] | joy[3];
}

//mbg 6/18/08 HACK
// XXX no. move into input if we need to.
extern ZAPPER ZD[2];
Input::Input() : stateinfo {
  { joy_readbit,	2, "JYRB"},
  { joy,		4, "JOYS"},
  { &LastStrobe,	1, "LSTS"},
  { &ZD[0].bogo,	1, "ZBG0"},
  { &ZD[1].bogo,	1, "ZBG1"},
  { 0 },
} {
  TRACEF("Constructing input object..");
  // Constructor body.

  // This is a mess -- maybe these things could be std::function, or maybe all
  // the different inputs could be members of Input or trampoline through it.
  GPC = INPUTC{
    [](int i) { return fceulib__input.ReadGP(i);},
    0,
    [](int i) { return fceulib__input.StrobeGP(i);},
    [](int i, void *data, int arg) { return fceulib__input.UpdateGP(i, data, arg);},
    0,
    0,
    [](int i, MovieRecord *mr) { return fceulib__input.LogGP(i, mr);},
    [](int i, MovieRecord *mr) { return fceulib__input.LoadGP(i, mr);},
  };

  GPCVS = INPUTC{
    [](int i) { return fceulib__input.ReadGPVS(i);},
    0,
    [](int i) { return fceulib__input.StrobeGP(i);},
    [](int i, void *data, int arg) { return fceulib__input.UpdateGP(i, data, arg);},
    0,
    0,
    [](int i, MovieRecord *mr) { return fceulib__input.LogGP(i, mr);},
    [](int i, MovieRecord *mr) { return fceulib__input.LoadGP(i, mr);},
  };

  FAMI4C = INPUTCFC{
    [](int i, uint8 ret) { return fceulib__input.ReadFami4(i, ret); },
    0,
    []() { return fceulib__input.StrobeFami4(); },
    0,
    0,
    0
  };
}

static DECLFR(JPRead) {
  return fceulib__input.JPRead_Direct(DECLFR_FORWARD);
}

DECLFR_RET Input::JPRead_Direct(DECLFR_ARGS) {
  uint8 ret = 0;

  ret|=joyports[A&1].driver->Read(A&1);

  // Test if the port 2 start button is being pressed.
  // On a famicom, port 2 start shouldn't exist, so this removes it.
  // Games can't automatically be checked for NES/Famicom status,
  // so it's an all-encompassing change in the input config menu.
  if (replaceP2StartWithMicrophone && (A&1) && joy_readbit[1] == 4) {
    // Nullify Port 2 Start Button
    ret&=0xFE;
  }

  if (portFC.driver)
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

  ret |= X.DB & 0xC0;

  return ret;
}

static DECLFW(B4016) {
  return fceulib__input.B4016_Direct(DECLFW_FORWARD);
}

void Input::B4016_Direct(DECLFW_ARGS) {
  if (portFC.driver)
    portFC.driver->Write(V&7);

  for (int i=0;i<2;i++)
    joyports[i].driver->Write(V & 1);

  if ((LastStrobe & 1) && !(V & 1)) {
    //old comment:
    //This strobe code is just for convenience.  If it were
    //with the code in input / *.c, it would more accurately represent
    //what's really going on.  But who wants accuracy? ;)
    //Seriously, though, this shouldn't be a problem.
    //new comment:

    //mbg 6/7/08 - I guess he means that the input drivers could track the strobing themselves
    //I dont see why it is unreasonable here.
    for (int i=0;i<2;i++)
      joyports[i].driver->Strobe(i);
    if (portFC.driver)
      portFC.driver->Strobe();
  }
  LastStrobe = V & 0x1;
}

//--------4 player driver for expansion port--------
void Input::StrobeFami4() {
  F4ReadBit[0] = F4ReadBit[1] = 0;
}

uint8 Input::ReadFami4(int w, uint8 ret) {
  ret&=1;

  ret |= ((fceulib__input.joy[2+w]>>(F4ReadBit[w]))&1)<<1;
  if (F4ReadBit[w] >= 8) ret |= 2;
  else F4ReadBit[w]++;

  return ret;
}

//------------------

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


uint8 Input::ReadGPVS(int w) {
  uint8 ret=0;

  if (joy_readbit[w]>=8) {
    ret=1;
  } else {
    ret = (joy[w] >> joy_readbit[w]) & 1;
    joy_readbit[w]++;
  }
  return ret;
}

void Input::UpdateGP(int w, void *data, int arg) {
  if (w == 0) {
    joy[0] = *(uint32 *)joyports[0].ptr;
    joy[2] = *(uint32 *)joyports[0].ptr >> 16;
  } else {
    joy[1] = *(uint32 *)joyports[1].ptr >> 8;
    joy[3] = *(uint32 *)joyports[1].ptr >> 24;
  }
}

void Input::LogGP(int w, MovieRecord* mr) {
  if (w==0) {
    mr->joysticks[0] = joy[0];
    mr->joysticks[2] = joy[2];
  } else {
    mr->joysticks[1] = joy[1];
    mr->joysticks[3] = joy[3];
  }
}

void Input::LoadGP(int w, MovieRecord* mr) {
  if (w==0) {
    joy[0] = mr->joysticks[0];
    if (FSAttached) joy[2] = mr->joysticks[2];
  } else {
    joy[1] = mr->joysticks[1];
    if (FSAttached) joy[3] = mr->joysticks[3];
  }
}

// basic joystick port driver
uint8 Input::ReadGP(int w) {
  uint8 ret;

  if (joy_readbit[w]>=8) {
    ret = (joy[2+w]>>(joy_readbit[w]&7)) & 1;
  } else {
    ret = (joy[w]>>(joy_readbit[w])) & 1;
  }
  if (joy_readbit[w]>=16) ret=0;
  if (!FSAttached) {
    if (joy_readbit[w]>=8) ret |= 1;
  } else {
    if (joy_readbit[w]==19-w) ret |= 1;
  }
  joy_readbit[w]++;
  return ret;
}

void Input::StrobeGP(int w) {
  joy_readbit[w] = 0;
}

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^6

void Input::FCEU_DrawInput(uint8 *buf) {
  for (int pad=0; pad < 2; pad++)
    joyports[pad].driver->Draw(pad,buf,joyports[pad].attrib);
  if (portFC.driver)
    portFC.driver->Draw(buf,portFC.attrib);
}

void Input::FCEU_UpdateInput() {
  TRACECALL();
  //tell all drivers to poll input and set up their logical states
  for (int port=0;port<2;port++) {
    if (joyports[port].driver)
      joyports[port].driver->Update(port,joyports[port].ptr,joyports[port].attrib);
  }
  if (portFC.driver)
    portFC.driver->Update(portFC.ptr,portFC.attrib);


  if (fceulib__fceu.GameInfo->type==GIT_VSUNI)
    if (fceulib__vsuni.coinon) fceulib__vsuni.coinon--;

  // This saved it for display, and copied it from the movie if playing. Don't
  // need that any more as it's driven externally. -tom7
  // FCEUMOV_AddInputState();

  //TODO - should this apply to the movie data? should this be displayed in the input hud?
  if (fceulib__fceu.GameInfo->type==GIT_VSUNI)
    fceulib__vsuni.FCEU_VSUniSwap(&joy[0],&joy[1]);
}

static DECLFR(VSUNIRead0) {
  return fceulib__input.VSUNIRead0_Direct(DECLFR_FORWARD);
}

DECLFR_RET Input::VSUNIRead0_Direct(DECLFR_ARGS) {
  uint8 ret=0;

  ret |= joyports[0].driver->Read(0) & 1;

  ret |= (fceulib__vsuni.vsdip & 3) << 3;
  if (fceulib__vsuni.coinon)
    ret |= 0x4;
  return ret;
}

static DECLFR(VSUNIRead1) {
  return fceulib__input.VSUNIRead1_Direct(DECLFR_FORWARD);
}

DECLFR_RET Input::VSUNIRead1_Direct(DECLFR_ARGS) {
  uint8 ret=0;

  ret|=(joyports[1].driver->Read(1))&1;
  ret|=fceulib__vsuni.vsdip & 0xFC;
  return ret;
}

// calls from the ppu;
// calls the SLHook for any driver that needs it
void Input::InputScanlineHook(uint8 *bg, uint8 *spr, uint32 linets, int final) {
  TRACECALL();
  for (int port = 0; port < 2; port++)
    joyports[port].driver->SLHook(port,bg,spr,linets,final);
  portFC.driver->SLHook(bg,spr,linets,final);
}

// binds JPorts[pad] to the driver specified in JPType[pad]
void Input::SetInputStuff(int port) {
  switch (joyports[port].type) {
  case SI_GAMEPAD:
    if (fceulib__fceu.GameInfo->type==GIT_VSUNI)
      joyports[port].driver = &GPCVS;
    else
      joyports[port].driver = &GPC;
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

void Input::SetInputStuffFC() {
  TRACEF("portfc type %d", portFC.type);
  switch (portFC.type) {
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

void Input::FCEUI_SetInput(int port, ESI type, void *ptr, int attrib) {
  joyports[port].attrib = attrib;
  joyports[port].type = type;
  joyports[port].ptr = ptr;
  SetInputStuff(port);
}

void Input::FCEUI_SetInputFC(ESIFC type, void *ptr, int attrib) {
  portFC.attrib = attrib;
  portFC.type = type;
  portFC.ptr = ptr;
  SetInputStuffFC();
}


// initializes the input system to power-on state
void Input::InitializeInput() {
  memset(joy_readbit,0,sizeof(joy_readbit));
  memset(joy,0,sizeof(joy));
  LastStrobe = 0;

  if (fceulib__fceu.GameInfo->type==GIT_VSUNI) {
    fceulib__fceu.SetReadHandler(0x4016,0x4016,VSUNIRead0);
    fceulib__fceu.SetReadHandler(0x4017,0x4017,VSUNIRead1);
  } else {
    fceulib__fceu.SetReadHandler(0x4016,0x4017,JPRead);
  }

  fceulib__fceu.SetWriteHandler(0x4016,0x4016,B4016);

  //force the port drivers to be setup
  SetInputStuff(0);
  SetInputStuff(1);
  SetInputStuffFC();
}


bool Input::FCEUI_GetInputFourscore() {
  return FSAttached;
}

bool Input::FCEUI_GetInputMicrophone() {
  return replaceP2StartWithMicrophone;
}

void Input::FCEUI_SetInputFourscore(bool attachFourscore) {
  FSAttached = attachFourscore;
}

void Input::FCEUI_FDSSelect() {
  if (!fceulib__fceu.FCEU_IsValidUI(FCEUI_SWITCH_DISK))
    return;

  fprintf(stderr, "Command: Switch disk side");
  FCEU_DoSimpleCommand(FCEUNPCMD_FDSSELECT);
}

void Input::FCEUI_FDSInsert() {
  if (!fceulib__fceu.FCEU_IsValidUI(FCEUI_EJECT_DISK))
    return;

  fprintf(stderr, "Command: Insert/Eject disk");
  FCEU_DoSimpleCommand(FCEUNPCMD_FDSINSERT);
}

void Input::FCEUI_VSUniToggleDIP(int w) {
  FCEU_DoSimpleCommand(FCEUNPCMD_VSUNIDIP0 + w);
}

void Input::FCEUI_VSUniCoin() {
  FCEU_DoSimpleCommand(FCEUNPCMD_VSUNICOIN);
}

// Resets the NES
void Input::FCEUI_ResetNES() {
  if (!fceulib__fceu.FCEU_IsValidUI(FCEUI_RESET))
    return;

  fprintf(stderr, "Command: Soft reset");
  FCEU_DoSimpleCommand(FCEUNPCMD_RESET);
}

// Powers off the NES
void Input::FCEUI_PowerNES() {
  if (!fceulib__fceu.FCEU_IsValidUI(FCEUI_POWER))
    return;

  fprintf(stderr, "Command: Power switch");
  FCEU_DoSimpleCommand(FCEUNPCMD_POWER);
}

void Input::FCEU_DoSimpleCommand(int cmd) {
  switch (cmd) {
  case FCEUNPCMD_FDSINSERT: fceulib__fds.FCEU_FDSInsert(); break;
  case FCEUNPCMD_FDSSELECT: fceulib__fds.FCEU_FDSSelect(); break;
  case FCEUNPCMD_VSUNICOIN: fceulib__vsuni.FCEU_VSUniCoin(); break;
  case FCEUNPCMD_VSUNIDIP0:
  case FCEUNPCMD_VSUNIDIP0+1:
  case FCEUNPCMD_VSUNIDIP0+2:
  case FCEUNPCMD_VSUNIDIP0+3:
  case FCEUNPCMD_VSUNIDIP0+4:
  case FCEUNPCMD_VSUNIDIP0+5:
  case FCEUNPCMD_VSUNIDIP0+6:
  case FCEUNPCMD_VSUNIDIP0+7: 
    fceulib__vsuni.FCEU_VSUniToggleDIP(cmd - FCEUNPCMD_VSUNIDIP0);
    break;
  case FCEUNPCMD_POWER: fceulib__fceu.PowerNES(); break;
  case FCEUNPCMD_RESET: fceulib__fceu.ResetNES(); break;
  }
}
