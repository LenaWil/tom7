#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <iomanip>
#include <fstream>
#include <limits.h>
#include <stdarg.h>

#include "emufile.h"
#include "version.h"
#include "types.h"
#include "utils/endian.h"
#include "palette.h"
#include "input.h"
#include "fceu.h"
#include "driver.h"
#include "state.h"
#include "file.h"
#include "video.h"
#include "movie.h"
#include "fds.h"

#include "utils/guid.h"
#include "utils/memory.h"
#include "utils/xstring.h"
#include <sstream>

using namespace std;

//TODO - remove the synchack stuff from the replay gui and require it to be put into the fm2 file
//which the user would have already converted from fcm
//also cleanup the whole emulator version bullshit in replay. we dont support that old stuff anymore

//todo - better error handling for the compressed savestate

//todo - consider a MemoryBackedFile class..
//..a lot of work.. instead lets just read back from the current fcm

//todo - could we, given a field size, over-read from an inputstream and then parse out an integer?
//that would be faster than several reads, perhaps.

// this should not be set unless we are in MOVIEMODE_RECORD!

uint32 cur_input_display = 0;

char curMovieFilename[512] = {0};

// ----------------------------------------------------------------------------
MovieRecord::MovieRecord() {
  commands = 0;
  *(uint32*)&joysticks = 0;
  memset(zappers, 0, sizeof(zappers));
}

void MovieRecord::clear() {
  commands = 0;
  *(uint32*)&joysticks = 0;
  memset(zappers, 0, sizeof(zappers));
}

void MovieRecord::Clone(MovieRecord& sourceRec) {
  *(uint32*)&joysticks = *(uint32*)(&(sourceRec.joysticks));
  memcpy(this->zappers, sourceRec.zappers, sizeof(zappers));
  this->commands = sourceRec.commands;
}

MovieData::MovieData()
	: emuVersion(FCEU_VERSION_NUMERIC)
	, palFlag(false)
	, PPUflag(false)
	, rerecordCount(0)
	, binaryFlag(false)
	, loadFrameCount(-1) {
  memset(&romChecksum,0,sizeof(MD5DATA));
}

// the main interaction point between the emulator and the movie system.
// either dumps the current joystick state or loads one state from the movie
// TODO - just do this at the call site.
void FCEUMOV_AddInputState() {
  extern uint8 joy[4];
  memcpy(&cur_input_display,joy,4);
}
