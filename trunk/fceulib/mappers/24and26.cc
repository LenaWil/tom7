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

#include "mapinc.h"

static void (*sfun[3])(void);

#define vrctemp mapbyte1[0]
#define VPSG2 mapbyte3
#define VPSG mapbyte2

static void DoSQV1(void);
static void DoSQV2(void);
static void DoSawV(void);

static int swaparoo;

static int acount=0;

static void KonamiIRQHook(int a) {
  static constexpr int LCYCS = 341;
  //  #define LCYCS ((227*2)+1)
  if (fceulib__ines.iNESIRQa) {
    acount+=a*3;
    while (acount >= LCYCS) {
      acount-=LCYCS;
      fceulib__ines.iNESIRQCount++;
      if (fceulib__ines.iNESIRQCount==0x100) {
	X.IRQBegin(FCEU_IQEXT);
	fceulib__ines.iNESIRQCount=IRQLatch;
      }
    }
  }
}

static DECLFW(VRC6SW) {
  A&=0xF003;
  if (A>=0x9000 && A<=0x9002) {
    VPSG[A&3]=V;
    if (sfun[0]) sfun[0]();
  } else if (A>=0xa000 && A<=0xa002) {
    VPSG[4|(A&3)]=V;
    if (sfun[1]) sfun[1]();
  } else if (A>=0xb000 && A<=0xb002) {
    VPSG2[A&3]=V;
    if (sfun[2]) sfun[2]();
  }
}

static DECLFW(Mapper24_write) {
  if (swaparoo)
    A=(A&0xFFFC)|((A>>1)&1)|((A<<1)&2);
  if (A>=0x9000 && A<=0xb002) {
    VRC6SW(A,V);
    return;
  }
  A&=0xF003;
  //        if (A>=0xF000) printf("%d, %d, $%04x:$%02x\n",scanline,timestamp,A,V);
  switch (A&0xF003) {
  case 0x8000:ROM_BANK16(0x8000,V);break;
  case 0xB003:
    switch (V&0xF) {
    case 0x0:fceulib__ines.MIRROR_SET2(1);break;
    case 0x4:fceulib__ines.MIRROR_SET2(0);break;
    case 0x8:fceulib__ines.onemir(0);break;
    case 0xC:fceulib__ines.onemir(1);break;
    }
    break;
  case 0xC000:ROM_BANK8(0xC000,V);break;
  case 0xD000:VROM_BANK1(0x0000,V);break;
  case 0xD001:VROM_BANK1(0x0400,V);break;
  case 0xD002:VROM_BANK1(0x0800,V);break;
  case 0xD003:VROM_BANK1(0x0c00,V);break;
  case 0xE000:VROM_BANK1(0x1000,V);break;
  case 0xE001:VROM_BANK1(0x1400,V);break;
  case 0xE002:VROM_BANK1(0x1800,V);break;
  case 0xE003:VROM_BANK1(0x1c00,V);break;
  case 0xF000:IRQLatch=V;
    //acount=0;
    break;
  case 0xF001:fceulib__ines.iNESIRQa=V&2;
    vrctemp=V&1;
    if (V&2) {
      fceulib__ines.iNESIRQCount=IRQLatch;
      acount=0;
    }
    X.IRQEnd(FCEU_IQEXT);
    break;
  case 0xf002:fceulib__ines.iNESIRQa=vrctemp;
    X.IRQEnd(FCEU_IQEXT);break;
  case 0xF003:break;
  }
}

static int32 CVBC[3];
static int32 vcount[3];
static int32 dcount[2];

static inline void DoSQV(int x) {
  int32 V;
  int32 amp=(((VPSG[x<<2]&15)<<8)*6/8)>>4;
  int32 start,end;

  start=CVBC[x];
  end=(SOUNDTS<<16)/fceulib__sound.soundtsinc;
  if (end<=start) return;
  CVBC[x]=end;

  if (VPSG[(x<<2)|0x2]&0x80) {
    if (VPSG[x<<2]&0x80) {
      for (V=start;V<end;V++)
	fceulib__sound.Wave[V>>4]+=amp;
    } else {
      int32 thresh=(VPSG[x<<2]>>4)&7;
      int32 freq=((VPSG[(x<<2)|0x1]|((VPSG[(x<<2)|0x2]&15)<<8))+1)<<17;
      for (V=start;V<end;V++) {
	/* Greater than, not >=.  Important. */
	if (dcount[x]>thresh)
	  fceulib__sound.Wave[V>>4]+=amp;
	vcount[x]-=fceulib__sound.nesincsize;
	/* Should only be <0 in a few circumstances. */
	while (vcount[x]<=0) {
	  vcount[x]+=freq;
	  dcount[x]=(dcount[x]+1)&15;
	}
      }
    }
  }
}

static void DoSQV1(void)
{
 DoSQV(0);
}

static void DoSQV2(void)
{
 DoSQV(1);
}

static void DoSawV(void) {
  int32 start=CVBC[2];
  int32 end=(SOUNDTS<<16)/fceulib__sound.soundtsinc;
  if (end<=start) return;
  CVBC[2]=end;

  if (VPSG2[2]&0x80) {
    static int32 saw1phaseacc=0;
    uint32 freq3;
    static uint8 b3=0;
    static int32 phaseacc=0;
    static uint32 duff=0;

    freq3=(VPSG2[1]+((VPSG2[2]&15)<<8)+1);

    for (int V=start;V<end;V++) {
      saw1phaseacc-=fceulib__sound.nesincsize;
      if (saw1phaseacc<=0) {
	int32 t;
	do {
	  t=freq3;
	  t<<=18;
	  saw1phaseacc+=t;
	  phaseacc+=VPSG2[0]&0x3f;
	  b3++;
	  if (b3==7) {
	    b3=0;
	    phaseacc=0;
	  }
	} while (saw1phaseacc<=0);

	duff=(((phaseacc>>3)&0x1f)<<4)*6/8;
      }
      fceulib__sound.Wave[V>>4]+=duff;
    }
  }
}

static inline void DoSQVHQ(int x) {
  const int32 amp=((VPSG[x<<2]&15)<<8)*6/8;

  if (VPSG[(x<<2)|0x2]&0x80) {
    if (VPSG[x<<2]&0x80) {
      for (uint32 V=CVBC[x];V<SOUNDTS;V++)
	fceulib__sound.WaveHi[V]+=amp;
    } else {
      const int32 thresh=(VPSG[x<<2]>>4)&7;
      for (uint32 V=CVBC[x];V<SOUNDTS;V++) {
	if (dcount[x]>thresh)        /* Greater than, not >=.  Important. */
	  fceulib__sound.WaveHi[V]+=amp;
	vcount[x]--;
	/* Should only be <0 in a few circumstances. */
	if (vcount[x]<=0) {
	  vcount[x]=(VPSG[(x<<2)|0x1]|((VPSG[(x<<2)|0x2]&15)<<8))+1;
	  dcount[x]=(dcount[x]+1)&15;
	}
      }
    }
  }
  CVBC[x]=SOUNDTS;
}

static void DoSQV1HQ(void)
{
 DoSQVHQ(0);
}

static void DoSQV2HQ(void)
{
 DoSQVHQ(1);
}

static void DoSawVHQ(void)
{
 static uint8 b3=0;
 static int32 phaseacc=0;
 uint32 V; //mbg merge 7/17/06 made uint32

 if (VPSG2[2]&0x80)
 {
  for (V=CVBC[2];V<SOUNDTS;V++)
  {
   fceulib__sound.WaveHi[V]+=(((phaseacc>>3)&0x1f)<<8)*6/8;
   vcount[2]--;
   if (vcount[2]<=0)
   {
    vcount[2]=(VPSG2[1]+((VPSG2[2]&15)<<8)+1)<<1;
    phaseacc+=VPSG2[0]&0x3f;
    b3++;
    if (b3==7)
    {
     b3=0;
     phaseacc=0;
   }

   }
  }
 }
 CVBC[2]=SOUNDTS;
}


void VRC6Sound(int Count)
{
    int x;

    DoSQV1();
    DoSQV2();
    DoSawV();
    for (x=0;x<3;x++)
     CVBC[x]=Count;
}

void VRC6SoundHQ(void)
{
    DoSQV1HQ();
    DoSQV2HQ();
    DoSawVHQ();
}

void VRC6SyncHQ(int32 ts) {
 for (int x=0;x<3;x++) CVBC[x]=ts;
}

static void VRC6_ESI(void) {
  fceulib__sound.GameExpSound.RChange=VRC6_ESI;
  fceulib__sound.GameExpSound.Fill=VRC6Sound;
  fceulib__sound.GameExpSound.HiFill=VRC6SoundHQ;
  fceulib__sound.GameExpSound.HiSync=VRC6SyncHQ;

  memset(CVBC,0,sizeof(CVBC));
  memset(vcount,0,sizeof(vcount));
  memset(dcount,0,sizeof(dcount));
  if (FCEUS_SNDRATE) {
    if (FCEUS_SOUNDQ>=1) {
      sfun[0]=DoSQV1HQ;
      sfun[1]=DoSQV2HQ;
      sfun[2]=DoSawVHQ;
    } else {
      sfun[0]=DoSQV1;
      sfun[1]=DoSQV2;
      sfun[2]=DoSawV;
    }
  } else {
    memset(sfun,0,sizeof(sfun));
  }
}

void Mapper24_init(void)
{
        SetWriteHandler(0x8000,0xffff,Mapper24_write);
        VRC6_ESI();
        X.MapIRQHook=KonamiIRQHook;
        swaparoo=0;
}

void Mapper26_init(void)
{
        SetWriteHandler(0x8000,0xffff,Mapper24_write);
        VRC6_ESI();
        X.MapIRQHook=KonamiIRQHook;
        swaparoo=1;
}

void NSFVRC6_Init(void)
{
        VRC6_ESI();
        SetWriteHandler(0x8000,0xbfff,VRC6SW);
}
