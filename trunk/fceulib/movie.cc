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

#ifdef WIN32
#ifndef NOWINSTUFF
#include <windows.h>
#include "./drivers/win/common.h"
#include "./drivers/win/window.h"
extern void AddRecentMovieFile(const char *filename);

#include "./drivers/win/taseditor.h"
extern bool emulator_must_run_taseditor;
#endif
#endif

using namespace std;

#define MOVIE_VERSION 3

enum EMOVIE_FLAG {
	MOVIE_FLAG_NONE = 0,

	//an ARCHAIC flag which means the movie was recorded from a soft reset.
	//WHY would you do this?? do not create any new movies with this flag
	MOVIE_FLAG_FROM_RESET = (1<<1),

	MOVIE_FLAG_PAL = (1<<2),

	//movie was recorded from poweron. the alternative is from a savestate (or from reset)
	MOVIE_FLAG_FROM_POWERON = (1<<3),

	// set in newer version, used for old movie compatibility
	//TODO - only use this flag to print a warning that the sync might be bad
	//so that we can get rid of the sync hack code
	MOVIE_FLAG_NOSYNCHACK = (1<<4)
};

struct MOVIE_INFO {
  int movie_version;					// version of the movie format in the file
  uint32 num_frames;
  uint32 rerecord_count;
  bool poweron, pal, nosynchack, ppuflag;
  //mbg 6/21/08 - this flag isnt used anymore.. but maybe one day we can scan it out of the first record in the movie file
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

bool autoMovieBackup = false; //Toggle that determines if movies should be backed up automatically before altering them
bool movieFromPoweron = true;

// Function declarations------------------------
void poweron(bool shouldDisableBatteryLoading);

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
bool movie_readonly = true;
bool fullSaveStateLoads = false;	//Option for loading a savestates full contents in read+write mode instead of up to the frame count in the savestate (useful as a recovery option)

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

	/*
	if (this->joysticks != compareRec.joysticks)
		return false;

	//if new commands are ever recordable, they need to be added here if we go with this method
	if (this->command_reset() != compareRec.command_reset()) return false;
	if (this->command_power() != compareRec.command_power()) return false;
	if (this->command_fds_insert() != compareRec.command_fds_insert()) return false;
	if (this->command_fds_select() != compareRec.command_fds_select()) return false;

	if (this->zappers[0].x != compareRec.zappers[0].x) return false;
	if (this->zappers[0].y != compareRec.zappers[0].y) return false;
	if (this->zappers[0].zaphit != compareRec.zappers[0].zaphit) return false;
	if (this->zappers[0].b != compareRec.zappers[0].b) return false;
	if (this->zappers[0].bogo != compareRec.zappers[0].bogo) return false;

	if (this->zappers[1].x != compareRec.zappers[1].x) return false;
	if (this->zappers[1].y != compareRec.zappers[1].y) return false;
	if (this->zappers[1].zaphit != compareRec.zappers[1].zaphit) return false;
	if (this->zappers[1].b != compareRec.zappers[1].b) return false;
	if (this->zappers[1].bogo != compareRec.zappers[1].bogo) return false;
	*/

	return true;
}
void MovieRecord::Clone(MovieRecord& sourceRec)
{
	*(uint32*)&joysticks = *(uint32*)(&(sourceRec.joysticks));
	memcpy(this->zappers, sourceRec.zappers, sizeof(zappers));
	this->commands = sourceRec.commands;
}

const char MovieRecord::mnemonics[8] = {'A','B','S','T','U','D','L','R'};

void MovieRecord::dumpJoy(EMUFILE* os, uint8 joystate)
{
	//these are mnemonics for each joystick bit.
	//since we usually use the regular joypad, these will be more helpful.
	//but any character other than ' ' or '.' should count as a set bit
	//maybe other input types will need to be encoded another way..
	for (int bit=7;bit>=0;bit--)
	{
		int bitmask = (1<<bit);
		char mnemonic = mnemonics[bit];
		//if the bit is set write the mnemonic
		if (joystate & bitmask)
			os->fwrite(&mnemonic,1);
		else //otherwise write an unset bit
			write8le('.',os);
	}
}

void MovieRecord::parseJoy(EMUFILE* is, uint8& joystate)
{
	char buf[8];
	is->fread(buf,8);
	joystate = 0;
	for (int i=0;i<8;i++)
	{
		joystate <<= 1;
		joystate |= ((buf[i]=='.'||buf[i]==' ')?0:1);
	}
}

void MovieRecord::parse(MovieData* md, EMUFILE* is)
{
	//by the time we get in here, the initial pipe has already been extracted

	//extract the commands
	commands = uint32DecFromIstream(is);
	//*is >> commands;
	is->fgetc(); //eat the pipe

	//a special case: if fourscore is enabled, parse four gamepads
	if (md->fourscore)
	{
		parseJoy(is,joysticks[0]); is->fgetc(); //eat the pipe
		parseJoy(is,joysticks[1]); is->fgetc(); //eat the pipe
		parseJoy(is,joysticks[2]); is->fgetc(); //eat the pipe
		parseJoy(is,joysticks[3]); is->fgetc(); //eat the pipe
	}
	else
	{
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


void MovieRecord::dumpBinary(MovieData* md, EMUFILE* os, int index)
{
	write8le(commands,os);
	if (md->fourscore)
	{
		for (int i=0;i<4;i++)
			os->fwrite(&joysticks[i],sizeof(joysticks[i]));
	}
	else
	{
		for (int port=0;port<2;port++)
		{
			if (md->ports[port] == SI_GAMEPAD)
				os->fwrite(&joysticks[port],sizeof(joysticks[port]));
			else if (md->ports[port] == SI_ZAPPER)
			{
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
	, microphone(false)
{
	memset(&romChecksum,0,sizeof(MD5DATA));
}

void MovieData::truncateAt(int frame)
{
	records.resize(frame);
}

void MovieData::installValue(std::string& key, std::string& val)
{
	//todo - use another config system, or drive this from a little data structure. because this is gross
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

int FCEUMOV_GetFrame(void)
{
	return currFrameCounter;
}

int FCEUI_GetLagCount(void)
{
	return lagCounter;
}

bool FCEUI_GetLagged(void)
{
	if (lagFlag)
		return true;
	else
		return false;
}
void FCEUI_SetLagFlag(bool value)
{
	lagFlag = (value) ? 1 : 0;
}

bool FCEUMOV_ShouldPause(void)
{
	if (pauseframe && currFrameCounter+1 == pauseframe)
	{
		pauseframe = 0;
		return true;
	}
	else
	{
		return false;
	}
}

EMOVIEMODE FCEUMOV_Mode()
{
	return movieMode;
}

bool FCEUMOV_Mode(EMOVIEMODE modemask)
{
	return (movieMode&modemask)!=0;
}

bool FCEUMOV_Mode(int modemask)
{
	return FCEUMOV_Mode((EMOVIEMODE)modemask);
}

static void LoadFM2_binarychunk(MovieData& movieData, EMUFILE* fp, int size)
{
	int recordsize = 1; //1 for the command
	if (movieData.fourscore)
		recordsize += 4; //4 joysticks
	else
	{
		for (int i=0;i<2;i++)
		{
			switch(movieData.ports[i])
			{
			case SI_GAMEPAD: recordsize++; break;
			case SI_ZAPPER: recordsize+=12; break;
			}
		}
	}

	//find out how much remains in the file
	int curr = fp->ftell();
	fp->fseek(0,SEEK_END);
	int end = fp->ftell();
	int flen = end-curr;
	fp->fseek(curr,SEEK_SET);

	//the amount todo is the min of the limiting size we received and the remaining contents of the file
	int todo = std::min(size, flen);

	int numRecords = todo/recordsize;
	if (movieData.loadFrameCount!=-1 && movieData.loadFrameCount<numRecords)
		numRecords=movieData.loadFrameCount;

	movieData.records.resize(numRecords);
	for (int i=0;i<numRecords;i++)
	{
		movieData.records[i].parseBinary(&movieData,fp);
	}
}

//yuck... another custom text parser.
bool LoadFM2(MovieData& movieData, EMUFILE* fp, int size, bool stopAfterHeader) {
	// if there's no "binary" tag in the movie header, consider it as a movie in text format
	movieData.binaryFlag = false;
	// Non-TASEditor projects consume until EOF
	movieData.loadFrameCount = -1;

	std::ios::pos_type curr = fp->ftell();

	if (!stopAfterHeader)
	{
		// first, look for an fcm signature
		char fcmbuf[3];
		fp->fread(fcmbuf,3);
		fp->fseek(curr,SEEK_SET);
		if (!strncmp(fcmbuf,"FCM",3)) {
			FCEU_PrintError("FCM File format is no longer supported. Please use Tools > Convert FCM");
			return false;
		}
	}

	//movie must start with "version 3"
	char buf[9];
	curr = fp->ftell();
	fp->fread(buf,9);
	fp->fseek(curr,SEEK_SET);
	if (fp->fail()) return false;
	if (memcmp(buf,"version 3",9))
		return false;

	std::string key,value;
	enum {
		NEWLINE, KEY, SEPARATOR, VALUE, RECORD, COMMENT, SUBTITLE
	} state = NEWLINE;
	bool bail = false;
	bool iswhitespace, isrecchar, isnewline;
	int c;
	for (;;)
	{
		if (size--<=0) goto bail;
		c = fp->fgetc();
		if (c == -1)
			goto bail;
		iswhitespace = (c==' '||c=='\t');
		isrecchar = (c=='|');
		isnewline = (c==10||c==13);
		if (isrecchar && movieData.binaryFlag && !stopAfterHeader) {
			LoadFM2_binarychunk(movieData, fp, size);
			return true;
		} else if (isnewline && movieData.loadFrameCount == movieData.records.size()) {
			// exit prematurely if loaded the specified amound of records
			return true;
		}
		switch (state) {
		case NEWLINE:
			if (isnewline) goto done;
			if (iswhitespace) goto done;
			if (isrecchar)
				goto dorecord;
			//must be a key
			key = "";
			value = "";
			goto dokey;
			break;
		case RECORD:
			{
				dorecord:
				if (stopAfterHeader) return true;
				int currcount = movieData.records.size();
				movieData.records.resize(currcount+1);
				int preparse = fp->ftell();
				movieData.records[currcount].parse(&movieData, fp);
				int postparse = fp->ftell();
				size -= (postparse-preparse);
				state = NEWLINE;
				break;
			}

		case KEY:
			dokey: //dookie
			state = KEY;
			if (iswhitespace) goto doseparator;
			if (isnewline) goto commit;
			key += c;
			break;
		case SEPARATOR:
			doseparator:
			state = SEPARATOR;
			if (isnewline) goto commit;
			if (!iswhitespace) goto dovalue;
			break;
		case VALUE:
			dovalue:
			state = VALUE;
			if (isnewline) goto commit;
			value += c;
		default:;
		}
		goto done;

		bail:
		bail = true;
		if (state == VALUE) goto commit;
		goto done;
		commit:
		movieData.installValue(key,value);
		state = NEWLINE;
		done: ;
		if (bail) break;
	}

	return true;
}

void poweron(bool shouldDisableBatteryLoading) {
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

void FCEUMOV_CreateCleanMovie() {
  currMovieData = MovieData();
  currMovieData.palFlag = FCEUI_GetCurrentVidSystem(0,0)!=0;
  currMovieData.romFilename = FileBase;
  currMovieData.romChecksum = GameInfo->MD5;
  currMovieData.guid.newGuid();
  currMovieData.fourscore = FCEUI_GetInputFourscore();
  currMovieData.microphone = FCEUI_GetInputMicrophone();
  currMovieData.ports[0] = joyports[0].type;
  currMovieData.ports[1] = joyports[1].type;
  currMovieData.ports[2] = portFC.type;
  currMovieData.fds = isFDS;
  currMovieData.PPUflag = (newppu != 0);
}

bool FCEUMOV_FromPoweron() {
  return movieFromPoweron;
}

//the main interaction point between the emulator and the movie system.
//either dumps the current joystick state or loads one state from the movie
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

// TODO: Should be able to kill this? -tom7
bool FCEUMOV_ReadState(EMUFILE* is, uint32 size) {
  load_successful = false;

  if (!movie_readonly) {
    if (currMovieData.loadFrameCount >= 0) {
      movie_readonly = true;
    }
    if (FCEU_isFileInArchive(curMovieFilename)) {
      //a little rule: cant load states in read+write mode with a movie from an archive.
      //so we are going to switch it to readonly mode in that case
      FCEU_PrintError("Cannot loadstate in Read+Write with movie from archive. Movie is now Read-Only.");
      movie_readonly = true;
    }
  }

  MovieData tempMovieData = MovieData();
  std::ios::pos_type curr = is->ftell();
  if (!LoadFM2(tempMovieData, is, size, false)) {
    is->fseek((uint32)curr+size,SEEK_SET);
    return false;
  }

  load_successful = true;

  return true;
}

void FCEUMOV_PreLoad(void) {
  load_successful=0;
}

bool FCEUMOV_PostLoad(void) {
  // Movie mode always inactive now; simplified:
  return true;
}

