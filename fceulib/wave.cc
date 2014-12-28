#include <stdio.h>
#include <stdlib.h>

#include "types.h"
#include "fceu.h"

#include "driver.h"
#include "sound.h"
#include "wave.h"

static FILE *soundlog=0;
static long wsize;

/* Checking whether the file exists before wiping it out is left up to the
   reader..err...I mean, the driver code, if it feels so inclined(I don't feel
   so).
*/
void FCEU_WriteWaveData(int32 *Buffer, int Count) {
  int16 *temp = (int16*)alloca(Count*2);

  int16 *dest;
  int x;

#if !defined(WIN32) || defined(NOWINSTUFF)
  if(!soundlog) return;
#else
  if(!soundlog && !FCEUI_AviIsRecording()) return;
#endif

  dest=temp;
  x=Count;

  //mbg 7/28/06 - we appear to be guaranteeing little endian
  while(x--) {
    int16 tmp=*Buffer;

    *(uint8 *)dest=(((uint16)tmp)&255);
    *(((uint8 *)dest)+1)=(((uint16)tmp)>>8);
    dest++;
    Buffer++;
  }
  if(soundlog)
    wsize+=fwrite(temp,1,Count*sizeof(int16),soundlog);

}
