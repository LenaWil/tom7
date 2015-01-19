/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
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

#ifndef _X6502H

#include "x6502struct.h"

#include "tracing.h"

extern X6502 X;

void X6502_Debug(void (*CPUHook)(X6502 *),
		 uint8 (*ReadHook)(X6502 *, unsigned int),
		 void (*WriteHook)(X6502 *, unsigned int, uint8));

void X6502_RunDebug(int32 cycles);
#define X6502_Run(x) X6502_RunDebug(x)
//------------

extern uint32 timestamp;

#define N_FLAG  0x80
#define V_FLAG  0x40
#define U_FLAG  0x20
#define B_FLAG  0x10
#define D_FLAG  0x08
#define I_FLAG  0x04
#define Z_FLAG  0x02
#define C_FLAG  0x01

extern void (*MapIRQHook)(int a);

#define NTSC_CPU 1789772.7272727272727272
#define PAL_CPU  1662607.125

#define FCEU_IQEXT      0x001
#define FCEU_IQEXT2     0x002
/* ... */
#define FCEU_IQRESET    0x020
#define FCEU_IQNMI2  0x040  // Delayed NMI, gets converted to *_IQNMI
#define FCEU_IQNMI  0x080
#define FCEU_IQDPCM     0x100
#define FCEU_IQFCOUNT   0x200
#define FCEU_IQTEMP     0x800

void X6502_Init();
void X6502_Reset();
void X6502_Power();

void TriggerNMI();
void TriggerNMI2();

uint8 X6502_DMR(uint32 A);
void X6502_DMW(uint32 A, uint8 V);

// XXX PERF
// void X6502_IRQBegin(int w);
void X6502_IRQBegin_Wrapper(const std::string &where, int w);
#define MKSTRING(s) #s
#define X6502_IRQBegin(w) X6502_IRQBegin_Wrapper(FCEU_StringPrintf(__FILE__ ":%d",__LINE__), (w))

void X6502_IRQEnd(int w);

#define _X6502H
#endif
