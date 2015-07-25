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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include <string.h>
#include "share.h"
#include "fkb.h"

#define FKB_F1 0x01
#define FKB_F2 0x02
#define FKB_F3 0x03
#define FKB_F4 0x04
#define FKB_F5 0x05
#define FKB_F6 0x06
#define FKB_F7 0x07
#define FKB_F8 0x08
#define FKB_1 0x09
#define FKB_2 0x0A
#define FKB_3 0x0B
#define FKB_4 0x0C
#define FKB_5 0x0D
#define FKB_6 0x0E
#define FKB_7 0x0F
#define FKB_8 0x10
#define FKB_9 0x11
#define FKB_0 0x12
#define FKB_MINUS 0x13
#define FKB_CARET 0x14
#define FKB_BACKSLASH 0x15
#define FKB_STOP 0x16
#define FKB_ESCAPE 0x17
#define FKB_Q 0x18
#define FKB_W 0x19
#define FKB_E 0x1A
#define FKB_R 0x1B
#define FKB_T 0x1C
#define FKB_Y 0x1D
#define FKB_U 0x1E
#define FKB_I 0x1F
#define FKB_O 0x20
#define FKB_P 0x21
#define FKB_AT 0x22
#define FKB_BRACKETLEFT 0x23
#define FKB_RETURN 0x24
#define FKB_CONTROL 0x25
#define FKB_A 0x26
#define FKB_S 0x27
#define FKB_D 0x28
#define FKB_F 0x29
#define FKB_G 0x2A
#define FKB_H 0x2B
#define FKB_J 0x2C
#define FKB_K 0x2D
#define FKB_L 0x2E
#define FKB_SEMICOLON 0x2F
#define FKB_COLON 0x30
#define FKB_BRACKETRIGHT 0x31
#define FKB_KANA 0x32
#define FKB_LEFTSHIFT 0x33
#define FKB_Z 0x34
#define FKB_X 0x35
#define FKB_C 0x36
#define FKB_V 0x37
#define FKB_B 0x38
#define FKB_N 0x39
#define FKB_M 0x3A
#define FKB_COMMA 0x3B
#define FKB_PERIOD 0x3C
#define FKB_SLASH 0x3D
#define FKB_UNDERSCORE 0x3E
#define FKB_RIGHTSHIFT 0x3F
#define FKB_GRAPH 0x40
#define FKB_SPACE 0x41
#define FKB_CLEAR 0x42
#define FKB_INSERT 0x43
#define FKB_DELETE 0x44
#define FKB_UP 0x45
#define FKB_LEFT 0x46
#define FKB_RIGHT 0x47
#define FKB_DOWN 0x48

#define AK2(x, y) ((FKB_##x) | (FKB_##y << 8))
#define AK(x) FKB_##x

static uint8 bufit[0x49];
static uint8 ksmode;
static uint8 ksindex;

static uint16 matrix[9][2][4] = {
    {{AK(F8), AK(RETURN), AK(BRACKETLEFT), AK(BRACKETRIGHT)},
     {AK(KANA), AK(RIGHTSHIFT), AK(BACKSLASH), AK(STOP)}},
    {{AK(F7), AK(AT), AK(COLON), AK(SEMICOLON)},
     {AK(UNDERSCORE), AK(SLASH), AK(MINUS), AK(CARET)}},
    {{AK(F6), AK(O), AK(L), AK(K)}, {AK(PERIOD), AK(COMMA), AK(P), AK(0)}},
    {{AK(F5), AK(I), AK(U), AK(J)}, {AK(M), AK(N), AK(9), AK(8)}},
    {{AK(F4), AK(Y), AK(G), AK(H)}, {AK(B), AK(V), AK(7), AK(6)}},
    {{AK(F3), AK(T), AK(R), AK(D)}, {AK(F), AK(C), AK(5), AK(4)}},
    {{AK(F2), AK(W), AK(S), AK(A)}, {AK(X), AK(Z), AK(E), AK(3)}},
    {{AK(F1), AK(ESCAPE), AK(Q), AK(CONTROL)},
     {AK(LEFTSHIFT), AK(GRAPH), AK(1), AK(2)}},
    {{AK(CLEAR), AK(UP), AK(RIGHT), AK(LEFT)},
     {AK(DOWN), AK(SPACE), AK(DELETE), AK(INSERT)}},
};

static void FKB_Write(uint8 v) {
  v >>= 1;
  if (v & 2) {
    if ((ksmode & 1) && !(v & 1)) ksindex = (ksindex + 1) % 9;
  }
  ksmode = v;
}

static uint8 FKB_Read(FC *fc, int w, uint8 ret) {
  // printf("$%04x, %d, %d\n",w+0x4016,ksindex,ksmode&1);
  if (w) {
    int x;

    ret &= ~0x1E;
    for (x = 0; x < 4; x++)
      if (bufit[matrix[ksindex][ksmode & 1][x] & 0xFF] ||
          bufit[matrix[ksindex][ksmode & 1][x] >> 8]) {
        ret |= 1 << (x + 1);
      }
    ret ^= 0x1E;
  }
  return (ret);
}

static void FKB_Strobe() {
  ksmode = 0;
  ksindex = 0;
  // printf("strobe\n");
}

static void FKB_Update(void *data, int arg) {
  memcpy(bufit + 1, data, 0x48);
}

static INPUTCFC FKB = {FKB_Read, FKB_Write, FKB_Strobe, FKB_Update, 0, 0};

INPUTCFC *FCEU_InitFKB() {
  memset(bufit, 0, sizeof(bufit));
  ksmode = ksindex = 0;
  return &FKB;
}
