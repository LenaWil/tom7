// Sound filtering code.

#include <math.h>
#include <stdio.h>
#include "types.h"

#include "sound.h"
#include "x6502.h"
#include "fceu.h"
#include "filter.h"
#include "fsettings.h"

// Maybe should be called "fcoeffs.inc" -tom7
#include "fcoeffs.h"

void Filter::SexyFilter2(int32 *in, int32 count) {
  while (count--) {
    const int64 dropcurrent = ((*in<<16)-sexyfilter2_acc)>>3;

    sexyfilter2_acc += dropcurrent;
    *in = sexyfilter2_acc >> 16;
    in++;
  }
}

void Filter::SexyFilter(int32 *in, int32 *out, int32 count) {
  int32 mul1,mul2,vmul;

  mul1=(94<<16)/FCEUS_SNDRATE;
  mul2=(24<<16)/FCEUS_SNDRATE;
  vmul=(FCEUS_SOUNDVOLUME<<16)*3/4/100;

  /* TODO: Increase volume in low quality sound rendering code itself */
  if (FCEUS_SOUNDQ) vmul/=4;
  else vmul*=2;

  while (count) {
    int64 ino=(int64)*in*vmul;
    sexyfilter_acc1+=((ino-sexyfilter_acc1)*mul1)>>16;
    sexyfilter_acc2+=((ino-sexyfilter_acc1-sexyfilter_acc2)*mul2)>>16;
    //printf("%d ",*in);
    *in=0;
    {
      int32 t = (sexyfilter_acc1-ino+sexyfilter_acc2)>>16;
      //if(t>32767 || t<-32768) printf("Flow: %d\n",t);
      if (t>32767) t=32767;
      if (t<-32768) t=-32768;
      *out=t;
    }
    in++;
    out++;
    count--;
  }
}

/* Returns number of samples written to out. */
/* leftover is set to the number of samples that need to be copied
   from the end of in to the beginning of in. */

/* This filtering code assumes that almost all input values stay below 32767.
   Do not adjust the volume in the wlookup tables and the expansion sound
   code to be higher, or you *might* overflow the FIR code.
*/

int32 Filter::NeoFilterSound(int32 *in, int32 *out, uint32 inlen, int32 *leftover) {
  // Used outside loops -tom7
  uint32 x;
  int32 *outsave=out;
  int32 count=0;

  const uint32 max=(inlen-1)<<16;

  if (FCEUS_SOUNDQ==2) {
    for (x = mrindex;x<max;x+=mrratio) {
      int32 acc=0,acc2=0;
      const int32 *S = &in[(x>>16)-SQ2NCOEFFS];
      const int32 *D = sq2coeffs;

      for (unsigned int c = SQ2NCOEFFS; c; c--) {
	acc+=(S[c]**D)>>6;
	acc2+=(S[1+c]**D)>>6;
	D++;
      }

      acc=((int64)acc*(65536-(x&65535))+(int64)acc2*(x&65535))>>(16+11);
      *out=acc;
      out++;
      count++;
    }
  } else {
    for (x=mrindex;x<max;x+=mrratio) {
      int32 acc=0,acc2=0;
      const int32 *S=&in[(x>>16)-NCOEFFS];
      const int32 *D=coeffs;

      for (unsigned int c=NCOEFFS; c; c--) {
	acc+=(S[c]**D)>>6;
	acc2+=(S[1+c]**D)>>6;
	D++;
      }

      acc=((int64)acc*(65536-(x&65535))+(int64)acc2*(x&65535))>>(16+11);
      *out=acc;
      out++;
      count++;
    }
  }

  mrindex = x - max;

  if (FCEUS_SOUNDQ==2) {
    mrindex+=SQ2NCOEFFS*65536;
    *leftover=SQ2NCOEFFS+1;
  } else {
    mrindex+=NCOEFFS*65536;
    *leftover=NCOEFFS+1;
  }

  if (fceulib__sound.GameExpSound.NeoFill)
    fceulib__sound.GameExpSound.NeoFill(outsave,count);

  SexyFilter(outsave,outsave,count);
  if (FCEUS_LOWPASS)
    SexyFilter2(outsave,count);
  return count;
}

void Filter::MakeFilters(int32 rate) {
  const int32 *tabs[6]={C44100NTSC,C44100PAL,C48000NTSC,C48000PAL,C96000NTSC,
			C96000PAL};
  const int32 *sq2tabs[6]={SQ2C44100NTSC,SQ2C44100PAL,SQ2C48000NTSC,SQ2C48000PAL,
			   SQ2C96000NTSC,SQ2C96000PAL};

  const uint32 nco = FCEUS_SOUNDQ == 2 ? SQ2NCOEFFS : NCOEFFS;

  mrindex=(nco+1)<<16;
  mrratio=(fceulib__fceu.PAL?(int64)(PAL_CPU*65536):(int64)(NTSC_CPU*65536))/rate;

  const int idx = (fceulib__fceu.PAL?1:0)|(rate==48000?2:0)|(rate==96000?4:0);
  const int32 *tmp = (FCEUS_SOUNDQ == 2) ? sq2tabs[idx] : tabs[idx];

  if (FCEUS_SOUNDQ==2)
    for (int32 x = 0; x < SQ2NCOEFFS>>1; x++)
      sq2coeffs[x]=sq2coeffs[SQ2NCOEFFS-1-x]=tmp[x];
  else
    for (int32 x = 0; x < NCOEFFS>>1; x++)
      coeffs[x]=coeffs[NCOEFFS-1-x]=tmp[x];
}

Filter fceulib__filter;
