#ifndef _VIDEO_H_
#define _VIDEO_H_

// These two are important -- this is where the current screen
// contents is stored. -tom7
extern uint8 *XBuf;
extern uint8 *XBackBuf;


int FCEU_InitVirtualVideo(void);
void FCEU_KillVirtualVideo(void);

extern int ClipSidesOffset;
extern struct GUIMESSAGE
{
	//countdown for gui messages
	int howlong;

	//the current gui message
	char errmsg[110];

	//indicates that the movie should be drawn even on top of movies
	bool isMovieMessage;

	//in case of multiple lines, allow one to move the message
	int linesFromBottom;

} guiMessage;

extern GUIMESSAGE subtitleMessage;

#endif
