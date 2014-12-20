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

#ifndef WIN32
#include <stdint.h>
#endif

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <zlib.h>

#include "types.h"
#include "video.h"
#include "fceu.h"
#include "file.h"
#include "utils/memory.h"
#include "utils/crc32.h"
#include "state.h"
#include "movie.h"
#include "palette.h"
#include "input.h"
#include "vsuni.h"
#include "drawing.h"
#include "driver.h"

#ifdef WIN32
#ifndef NOWINSTUFF
#include "drivers/win/common.h" //For DirectX constants
#include "drivers/win/input.h"
#endif
#endif

uint8 *XBuf=NULL;
uint8 *XBackBuf=NULL;
int ClipSidesOffset=0;	//Used to move displayed messages when Clips left and right sides is checked
static uint8 *xbsave=NULL;

GUIMESSAGE guiMessage;
GUIMESSAGE subtitleMessage;

//for input display
extern int input_display;
extern uint32 cur_input_display;

bool oldInputDisplay = false;

void FCEU_KillVirtualVideo(void)
{
	//mbg merge TODO 7/17/06 temporarily removed
	//if(xbsave)
	//{
	// free(xbsave);
	// xbsave=0;
	//}
	//if(XBuf)
	//{
	//UnmapViewOfFile(XBuf);
	//CloseHandle(mapXBuf);
	//mapXBuf=NULL;
	//}
	//if(XBackBuf)
	//{
	// free(XBackBuf);
	// XBackBuf=0;
	//}
}

/**
* Return: Flag that indicates whether the function was succesful or not.
*
* TODO: This function is Windows-only. It should probably be moved.
**/
int FCEU_InitVirtualVideo(void)
{
	if(!XBuf)		/* Some driver code may allocate XBuf externally. */
		/* 256 bytes per scanline, * 240 scanline maximum, +16 for alignment,
		*/

		if(!(XBuf= (uint8*) (FCEU_malloc(256 * 256 + 16))) ||
			!(XBackBuf= (uint8*) (FCEU_malloc(256 * 256 + 16))))
		{
			return 0;
		}

		xbsave = XBuf;

		if( sizeof(uint8*) == 4 )
		{
			uintptr_t m = (uintptr_t)XBuf;
			m = ( 8 - m) & 7;
			XBuf+=m;
		}

		memset(XBuf,128,256*256); //*240);
		memset(XBackBuf,128,256*256);

		return 1;
}

void snapAVI()
{
	//Update AVI
	if(!FCEUI_EmulationPaused())
		FCEUI_AviVideoUpdate(XBuf);
}

void FCEU_DispMessageOnMovie(char *format, ...)
{
	va_list ap;

	va_start(ap,format);
	vsnprintf(guiMessage.errmsg,sizeof(guiMessage.errmsg),format,ap);
	va_end(ap);

	guiMessage.howlong = 180;
	guiMessage.isMovieMessage = true;
	guiMessage.linesFromBottom = 0;

	if (FCEUI_AviIsRecording() && FCEUI_AviDisableMovieMessages())
		guiMessage.howlong = 0;
}

void FCEU_DispMessage(char *format, int disppos=0, ...)
{
	va_list ap;

	va_start(ap,disppos);
	vsnprintf(guiMessage.errmsg,sizeof(guiMessage.errmsg),format,ap);
	va_end(ap);
	// also log messages
	char temp[2048];
	va_start(ap,disppos);
	vsnprintf(temp,sizeof(temp),format,ap);
	va_end(ap);
	strcat(temp, "\n");
	FCEU_printf(temp);

	guiMessage.howlong = 180;
	guiMessage.isMovieMessage = false;

	guiMessage.linesFromBottom = disppos;
}

void FCEU_ResetMessages()
{
	guiMessage.howlong = 0;
	guiMessage.isMovieMessage = false;
	guiMessage.linesFromBottom = 0;
}

uint32 GetScreenPixel(int x, int y, bool usebackup) {

	uint8 r,g,b;

	if (((x < 0) || (x > 255)) || ((y < 0) || (y > 255)))
		return -1;

	if (usebackup)
		FCEUD_GetPalette(XBackBuf[(y*256)+x],&r,&g,&b);
	else
		FCEUD_GetPalette(XBuf[(y*256)+x],&r,&g,&b);


	return ((int) (r) << 16) | ((int) (g) << 8) | (int) (b);
}

int GetScreenPixelPalette(int x, int y, bool usebackup) {

	if (((x < 0) || (x > 255)) || ((y < 0) || (y > 255)))
		return -1;

	if (usebackup)
		return XBackBuf[(y*256)+x] & 0x3f;
	else
		return XBuf[(y*256)+x] & 0x3f;

}

uint64 FCEUD_GetTime(void);
uint64 FCEUD_GetTimeFreq(void);

