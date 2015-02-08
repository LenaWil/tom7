#ifndef __PPU_H
#define __PPU_H

#include "state.h"

void FCEUPPU_Reset();
void FCEUPPU_Power();
int FCEUPPU_Loop(int skip);

void FCEUPPU_LineUpdate();
void FCEUPPU_SetVideoSystem(int w);

extern void (*PPU_hook)(uint32 A);
extern void (*GameHBIRQHook)(), (*GameHBIRQHook2)();

/* For cart.c and banksw.h, mostly */
extern uint8 NTARAM[0x800],*vnapage[4];
extern uint8 PPUNTARAM;
extern uint8 PPUCHRRAM;

void FCEUPPU_SaveState();
void FCEUPPU_LoadState(int version);

// 0 to keep 8-sprites limitation, 1 to remove it
void FCEUI_DisableSpriteLimitation(int a);

extern int scanline;
extern int g_rasterpos;
extern uint8 PPU[4];

extern const SFORMAT FCEUPPU_STATEINFO[];

#endif
