#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <zlib.h>
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

extern MovieData currMovieData;

#define MOVIE_VERSION 3

enum EMOVIE_FLAG {
  MOVIE_FLAG_NONE = 0,

  // an ARCHAIC flag which means the movie was recorded from a soft reset.
  // WHY would you do this?? do not create any new movies with this flag
  MOVIE_FLAG_FROM_RESET = (1<<1),

  MOVIE_FLAG_PAL = (1<<2),

  // movie was recorded from poweron. the alternative is from a savestate (or from reset)
  MOVIE_FLAG_FROM_POWERON = (1<<3),
  
  // set in newer version, used for old movie compatibility
  // TODO - only use this flag to print a warning that the sync might be bad
  // so that we can get rid of the sync hack code
  MOVIE_FLAG_NOSYNCHACK = (1<<4)
};

struct MOVIE_INFO {
  int movie_version;					// version of the movie format in the file
  uint32 num_frames;
  uint32 rerecord_count;
  bool poweron, pal, nosynchack, ppuflag;
  //mbg 6/21/08 - this flag isnt used anymore.. but maybe one day we
  //can scan it out of the first record in the movie file
  bool reset;
  uint32 emu_version_used;				// 9813 = 0.98.13
  MD5DATA md5_of_rom_used;
  std::string name_of_rom_used;

  // these are always stripped -tom7
  std::vector<std::string> comments;
  std::vector<std::string> subtitles;
};


// Not used in here (used to be set to 0-4 by some UI function) but several
// other modules import it.
int input_display = 0;

extern char FileBase[];

// Function declarations------------------------
static void poweron(bool shouldDisableBatteryLoading);

//TODO - remove the synchack stuff from the replay gui and require it to be put into the fm2 file
//which the user would have already converted from fcm
//also cleanup the whole emulator version bullshit in replay. we dont support that old stuff anymore

//todo - better error handling for the compressed savestate

//todo - consider a MemoryBackedFile class..
//..a lot of work.. instead lets just read back from the current fcm

//todo - could we, given a field size, over-read from an inputstream and then parse out an integer?
//that would be faster than several reads, perhaps.

//----movie engine main state - made degenerate by tom7
static constexpr EMOVIEMODE movieMode = MOVIEMODE_INACTIVE;

//this should not be set unless we are in MOVIEMODE_RECORD!

int currFrameCounter;
uint32 cur_input_display = 0;
int pauseframe = -1;

const SFORMAT FCEUMOV_STATEINFO[] = {
  { &currFrameCounter, 4|FCEUSTATE_RLSB, "FCNT" },
  { 0 }
};

char curMovieFilename[512] = {0};
MovieData currMovieData;
MovieData defaultMovieData;
int currRerecordCount;

void MovieData::clearRecordRange(int start, int len) {
  for (int i=0;i<len;i++) {
    records[i+start].clear();
  }
}

void MovieData::insertEmpty(int at, int frames) {
  if (at == -1) {
    records.resize(records.size() + frames);
  } else {
    records.insert(records.begin() + at, frames, MovieRecord());
  }
}

void MovieData::cloneRegion(int at, int frames) {
	if (at < 0) return;

	records.insert(records.begin() + at, frames, MovieRecord());

	for (int i = 0; i < frames; i++)
		records[i + at].Clone(records[i + at + frames]);
}
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

bool MovieRecord::Compare(MovieRecord& compareRec) {
  //Joysticks, Zappers, and commands

  if (this->commands != compareRec.commands)
    return false;
  if ((*(uint32*)&(this->joysticks)) != (*(uint32*)&(compareRec.joysticks)))
    return false;
  if (memcmp(this->zappers, compareRec.zappers, sizeof(zappers)))
    return false;
  return true;
}
void MovieRecord::Clone(MovieRecord& sourceRec)
{
	*(uint32*)&joysticks = *(uint32*)(&(sourceRec.joysticks));
	memcpy(this->zappers, sourceRec.zappers, sizeof(zappers));
	this->commands = sourceRec.commands;
}

const char MovieRecord::mnemonics[8] = {'A','B','S','T','U','D','L','R'};

void MovieRecord::dumpJoy(EMUFILE* os, uint8 joystate) {
  // these are mnemonics for each joystick bit.
  // since we usually use the regular joypad, these will be more helpful.
  // but any character other than ' ' or '.' should count as a set bit
  // maybe other input types will need to be encoded another way..
  for (int bit=7;bit>=0;bit--) {
      int bitmask = (1<<bit);
      char mnemonic = mnemonics[bit];
      //if the bit is set write the mnemonic
      if (joystate & bitmask)
	os->fwrite(&mnemonic,1);
      else //otherwise write an unset bit
	write8le('.',os);
    }
}

void MovieRecord::parseJoy(EMUFILE* is, uint8& joystate) {
  char buf[8];
  is->fread(buf,8);
  joystate = 0;
  for (int i=0;i<8;i++) {
    joystate <<= 1;
    joystate |= ((buf[i]=='.'||buf[i]==' ')?0:1);
  }
}

void MovieRecord::parse(MovieData* md, EMUFILE* is) {
  //by the time we get in here, the initial pipe has already been extracted

  //extract the commands
  commands = uint32DecFromIstream(is);
  //*is >> commands;
  is->fgetc(); //eat the pipe

  //a special case: if fourscore is enabled, parse four gamepads
  if (md->fourscore) {
    parseJoy(is,joysticks[0]); is->fgetc(); //eat the pipe
    parseJoy(is,joysticks[1]); is->fgetc(); //eat the pipe
    parseJoy(is,joysticks[2]); is->fgetc(); //eat the pipe
    parseJoy(is,joysticks[3]); is->fgetc(); //eat the pipe
  } else {
    for (int port=0;port<2;port++)
      {
	if (md->ports[port] == SI_GAMEPAD)
	  parseJoy(is, joysticks[port]);
	else if (md->ports[port] == SI_ZAPPER)
	  {
	    zappers[port].x = uint32DecFromIstream(is);
	    zappers[port].y = uint32DecFromIstream(is);
	    zappers[port].b = uint32DecFromIstream(is);
	    zappers[port].bogo = uint32DecFromIstream(is);
	    zappers[port].zaphit = uint64DecFromIstream(is);
	  }

	is->fgetc(); //eat the pipe
      }
  }

  //(no fcexp data is logged right now)
  is->fgetc(); //eat the pipe

  //should be left at a newline
}


bool MovieRecord::parseBinary(MovieData* md, EMUFILE* is)
{
	commands = (uint8)is->fgetc();

	//check for eof
	if (is->eof()) return false;

	if (md->fourscore)
	{
		is->fread((char*)&joysticks,4);
	}
	else
	{
		for (int port=0;port<2;port++)
		{
			if (md->ports[port] == SI_GAMEPAD)
				joysticks[port] = (uint8)is->fgetc();
			else if (md->ports[port] == SI_ZAPPER)
			{
				zappers[port].x = (uint8)is->fgetc();
				zappers[port].y = (uint8)is->fgetc();
				zappers[port].b = (uint8)is->fgetc();
				zappers[port].bogo = (uint8)is->fgetc();
				read64le(&zappers[port].zaphit,is);
			}
		}
	}

	return true;
}


void MovieRecord::dumpBinary(MovieData* md, EMUFILE* os, int index) {
  write8le(commands,os);
  if (md->fourscore) {
    for (int i=0;i<4;i++)
      os->fwrite(&joysticks[i],sizeof(joysticks[i]));
  } else {
    for (int port=0;port<2;port++) {
      if (md->ports[port] == SI_GAMEPAD)
	os->fwrite(&joysticks[port],sizeof(joysticks[port]));
      else if (md->ports[port] == SI_ZAPPER) {
	write8le(zappers[port].x,os);
	write8le(zappers[port].y,os);
	write8le(zappers[port].b,os);
	write8le(zappers[port].bogo,os);
	write64le(zappers[port].zaphit, os);
      }
    }
  }
}

MovieData::MovieData()
	: version(MOVIE_VERSION)
	, emuVersion(FCEU_VERSION_NUMERIC)
	, palFlag(false)
	, PPUflag(false)
	, rerecordCount(0)
	, binaryFlag(false)
	, loadFrameCount(-1)
	, microphone(false) {
	memset(&romChecksum,0,sizeof(MD5DATA));
}

void MovieData::truncateAt(int frame) {
  records.resize(frame);
}

void MovieData::installValue(std::string& key, std::string& val) {
  // todo - use another config system, or drive this from a little data
  // structure. because this is gross
  if (key == "FDS")
    installInt(val,fds);
  else if (key == "NewPPU")
    installBool(val,PPUflag);
  else if (key == "version")
    installInt(val,version);
  else if (key == "emuVersion")
    installInt(val,emuVersion);
  else if (key == "rerecordCount")
    installInt(val,rerecordCount);
  else if (key == "palFlag")
    installBool(val,palFlag);
  else if (key == "romFilename")
    romFilename = val;
  else if (key == "romChecksum")
    StringToBytes(val,&romChecksum,MD5DATA::size);
  else if (key == "guid")
    guid = FCEU_Guid::fromString(val);
  else if (key == "fourscore")
    installBool(val,fourscore);
  else if (key == "microphone")
    installBool(val,microphone);
  else if (key == "port0")
    installInt(val,ports[0]);
  else if (key == "port1")
    installInt(val,ports[1]);
  else if (key == "port2")
    installInt(val,ports[2]);
  else if (key == "binary")
    installBool(val,binaryFlag);
  else if (key == "comment")
    (void)0; // stripped -tom7
  else if (key == "subtitle")
    (void)0; // stripped -tom7
  else if (key == "savestate")
    {
      int len = Base64StringToBytesLength(val);
      if (len == -1) len = HexStringToBytesLength(val); // wasn't base64, try hex
      if (len >= 1)
	{
	  savestate.resize(len);
	  StringToBytes(val,&savestate[0],len); // decodes either base64 or hex
	}
    }
  else if (key == "length")
    {
      installInt(val, loadFrameCount);
    }
}

static void poweron(bool shouldDisableBatteryLoading) {
  //// make a for-movie-recording power-on clear the game's save data, too
  //extern char lastLoadedGameName [2048];
  //extern int disableBatteryLoading, suppressAddPowerCommand;
  //suppressAddPowerCommand=1;
  //if (shouldDisableBatteryLoading) disableBatteryLoading=1;
  //suppressMovieStop=true;
  //{
  //	//we need to save the pause state through this process
  //	int oldPaused = EmulationPaused;

  //	// NOTE:  this will NOT write an FCEUNPCMD_POWER into the movie file
  //	FCEUGI* gi = FCEUI_LoadGame(lastLoadedGameName, 0);
  //	assert(gi);
  //	PowerNES();

  //	EmulationPaused = oldPaused;
  //}
  //suppressMovieStop=false;
  //if (shouldDisableBatteryLoading) disableBatteryLoading=0;
  //suppressAddPowerCommand=0;

  extern int disableBatteryLoading;
  disableBatteryLoading = 1;
  PowerNES();
  disableBatteryLoading = 0;
}

// the main interaction point between the emulator and the movie system.
// either dumps the current joystick state or loads one state from the movie
// TODO - just do this at the call site.
void FCEUMOV_AddInputState() {
  currFrameCounter++;

  extern uint8 joy[4];
  memcpy(&cur_input_display,joy,4);
}


//TODO
void FCEUMOV_AddCommand(int cmd) {
  return;
}

static bool load_successful;

void FCEUMOV_PreLoad(void) {
  load_successful=0;
}

bool FCEUMOV_PostLoad(void) {
  // Movie mode always inactive now; simplified:
  return true;
}

