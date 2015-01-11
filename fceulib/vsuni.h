#ifndef __VSUNI_H
#define __VSUNI_H

void FCEU_VSUniPower(void);
void FCEU_VSUniCheck(uint64 md5partial, int *, uint8 *);
void FCEU_VSUniDraw(uint8 *XBuf);

void FCEU_VSUniToggleDIP(int);  /* For movies and netplay */
void FCEU_VSUniCoin(void);
void FCEU_VSUniSwap(uint8 *j0, uint8 *j1);

void FCEUI_VSUniToggleDIPView();
void FCEUI_VSUniSetDIP(int w, int state);

extern SFORMAT FCEUVSUNI_STATEINFO[];

#endif
