#ifndef _VIDEO_H_
#define _VIDEO_H_

// These two are important -- this is where the current screen
// contents is stored. -tom7
extern uint8 *XBuf;
extern uint8 *XBackBuf;


int FCEU_InitVirtualVideo(void);
void FCEU_KillVirtualVideo(void);

extern int ClipSidesOffset;

#endif
