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

std::vector<int> subtitleFrames;		//Frame numbers for subtitle messages
std::vector<string> subtitleMessages;	//Messages of subtitles

bool subtitlesOnAVI = false;
bool autoMovieBackup = false; //Toggle that determines if movies should be backed up automatically before altering them
bool freshMovie = false;	  //True when a movie loads, false when movie is altered.  Used to determine if a movie has been altered since opening
bool movieFromPoweron = true;

static int _currCommand = 0;

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

//sometimes we accidentally produce movie stop signals while we're trying to do other things with movies..
bool suppressMovieStop=false;

//----movie engine main state
EMOVIEMODE movieMode = MOVIEMODE_INACTIVE;

//this should not be set unless we are in MOVIEMODE_RECORD!
//FILE* fpRecordingMovie = 0;
EMUFILE* osRecordingMovie = NULL;

int currFrameCounter;
uint32 cur_input_display = 0;
int pauseframe = -1;
bool movie_readonly = true;
bool fullSaveStateLoads = false;	//Option for loading a savestates full contents in read+write mode instead of up to the frame count in the savestate (useful as a recovery option)

SFORMAT FCEUMOV_STATEINFO[]={
	{ &currFrameCounter, 4|FCEUSTATE_RLSB, "FCNT"},
	{ 0 }
};

char curMovieFilename[512] = {0};
MovieData currMovieData;
MovieData defaultMovieData;
int currRerecordCount;

void MovieData::clearRecordRange(int start, int len)
{
	for(int i=0;i<len;i++)
	{
		records[i+start].clear();
	}
}

void MovieData::insertEmpty(int at, int frames)
{
	if (at == -1)
	{
		records.resize(records.size() + frames);
	} else
	{
		records.insert(records.begin() + at, frames, MovieRecord());
	}
}

void MovieData::cloneRegion(int at, int frames)
{
	if (at < 0) return;

	records.insert(records.begin() + at, frames, MovieRecord());

	for(int i = 0; i < frames; i++)
		records[i + at].Clone(records[i + at + frames]);
}
// ----------------------------------------------------------------------------
MovieRecord::MovieRecord()
{
	commands = 0;
	*(uint32*)&joysticks = 0;
	memset(zappers, 0, sizeof(zappers));
}

void MovieRecord::clear()
{
	commands = 0;
	*(uint32*)&joysticks = 0;
	memset(zappers, 0, sizeof(zappers));
}

bool MovieRecord::Compare(MovieRecord& compareRec)
{
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
	if(this->command_reset() != compareRec.command_reset()) return false;
	if(this->command_power() != compareRec.command_power()) return false;
	if(this->command_fds_insert() != compareRec.command_fds_insert()) return false;
	if(this->command_fds_select() != compareRec.command_fds_select()) return false;

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
	for(int bit=7;bit>=0;bit--)
	{
		int bitmask = (1<<bit);
		char mnemonic = mnemonics[bit];
		//if the bit is set write the mnemonic
		if(joystate & bitmask)
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
	for(int i=0;i<8;i++)
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
	if(md->fourscore)
	{
		parseJoy(is,joysticks[0]); is->fgetc(); //eat the pipe
		parseJoy(is,joysticks[1]); is->fgetc(); //eat the pipe
		parseJoy(is,joysticks[2]); is->fgetc(); //eat the pipe
		parseJoy(is,joysticks[3]); is->fgetc(); //eat the pipe
	}
	else
	{
		for(int port=0;port<2;port++)
		{
			if(md->ports[port] == SI_GAMEPAD)
				parseJoy(is, joysticks[port]);
			else if(md->ports[port] == SI_ZAPPER)
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
	if(is->eof()) return false;

	if(md->fourscore)
	{
		is->fread((char*)&joysticks,4);
	}
	else
	{
		for(int port=0;port<2;port++)
		{
			if(md->ports[port] == SI_GAMEPAD)
				joysticks[port] = (uint8)is->fgetc();
			else if(md->ports[port] == SI_ZAPPER)
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
	if(md->fourscore)
	{
		for(int i=0;i<4;i++)
			os->fwrite(&joysticks[i],sizeof(joysticks[i]));
	}
	else
	{
		for(int port=0;port<2;port++)
		{
			if(md->ports[port] == SI_GAMEPAD)
				os->fwrite(&joysticks[port],sizeof(joysticks[port]));
			else if(md->ports[port] == SI_ZAPPER)
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

void MovieRecord::dump(MovieData* md, EMUFILE* os, int index)
{
	//dump the misc commands
	//*os << '|' << setw(1) << (int)commands;
	os->fputc('|');
	putdec<uint8,1,true>(os,commands);

	//a special case: if fourscore is enabled, dump four gamepads
	if(md->fourscore)
	{
		os->fputc('|');
		dumpJoy(os,joysticks[0]); os->fputc('|');
		dumpJoy(os,joysticks[1]); os->fputc('|');
		dumpJoy(os,joysticks[2]); os->fputc('|');
		dumpJoy(os,joysticks[3]); os->fputc('|');
	}
	else
	{
		for(int port=0;port<2;port++)
		{
			os->fputc('|');
			if(md->ports[port] == SI_GAMEPAD)
				dumpJoy(os, joysticks[port]);
			else if(md->ports[port] == SI_ZAPPER)
			{
				putdec<uint8,3,true>(os,zappers[port].x); os->fputc(' ');
				putdec<uint8,3,true>(os,zappers[port].y); os->fputc(' ');
				putdec<uint8,1,true>(os,zappers[port].b); os->fputc(' ');
				putdec<uint8,1,true>(os,zappers[port].bogo); os->fputc(' ');
				putdec<uint64,20,false>(os,zappers[port].zaphit);
			}
		}
		os->fputc('|');
	}

	//(no fcexp data is logged right now)
	os->fputc('|');

	//each frame is on a new line
	os->fputc('\n');
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
	if(key == "FDS")
		installInt(val,fds);
	else if(key == "NewPPU")
		installBool(val,PPUflag);
	else if(key == "version")
		installInt(val,version);
	else if(key == "emuVersion")
		installInt(val,emuVersion);
	else if(key == "rerecordCount")
		installInt(val,rerecordCount);
	else if(key == "palFlag")
		installBool(val,palFlag);
	else if(key == "romFilename")
		romFilename = val;
	else if(key == "romChecksum")
		StringToBytes(val,&romChecksum,MD5DATA::size);
	else if(key == "guid")
		guid = FCEU_Guid::fromString(val);
	else if(key == "fourscore")
		installBool(val,fourscore);
	else if(key == "microphone")
		installBool(val,microphone);
	else if(key == "port0")
		installInt(val,ports[0]);
	else if(key == "port1")
		installInt(val,ports[1]);
	else if(key == "port2")
		installInt(val,ports[2]);
	else if(key == "binary")
		installBool(val,binaryFlag);
	else if(key == "comment")
	  (void)0; // stripped -tom7
	else if (key == "subtitle")
	  (void)0; // stripped -tom7
	else if(key == "savestate")
	{
		int len = Base64StringToBytesLength(val);
		if(len == -1) len = HexStringToBytesLength(val); // wasn't base64, try hex
		if(len >= 1)
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

int MovieData::dump(EMUFILE *os, bool binary)
{
	int start = os->ftell();
	os->fprintf("version %d\n", version);
	os->fprintf("emuVersion %d\n", emuVersion);
	os->fprintf("rerecordCount %d\n", rerecordCount);
	os->fprintf("palFlag %d\n" , (palFlag?1:0) );
	os->fprintf("romFilename %s\n" , romFilename.c_str() );
	os->fprintf("romChecksum %s\n" , BytesToString(romChecksum.data,MD5DATA::size).c_str() );
	os->fprintf("guid %s\n" , guid.toString().c_str() );
	os->fprintf("fourscore %d\n" , (fourscore?1:0) );
	os->fprintf("microphone %d\n" , (microphone?1:0) );
	os->fprintf("port0 %d\n" , ports[0] );
	os->fprintf("port1 %d\n" , ports[1] );
	os->fprintf("port2 %d\n" , ports[2] );
	os->fprintf("FDS %d\n" , fds?1:0 );
	os->fprintf("NewPPU %d\n" , PPUflag?1:0 );

	if(binary)
		os->fprintf("binary 1\n" );

	if(savestate.size())
		os->fprintf("savestate %s\n" , BytesToString(&savestate[0],savestate.size()).c_str() );

	if (this->loadFrameCount >= 0)
		os->fprintf("length %d\n" , this->loadFrameCount);

	if(binary)
	{
		//put one | to start the binary dump
		os->fputc('|');
		for(int i=0;i<(int)records.size();i++)
			records[i].dumpBinary(this, os, i);
	} else
	{
		for(int i=0;i<(int)records.size();i++)
			records[i].dump(this, os, i);
	}

	int end = os->ftell();
	return end-start;
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
	if(pauseframe && currFrameCounter+1 == pauseframe)
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
	if(movieData.fourscore)
		recordsize += 4; //4 joysticks
	else
	{
		for(int i=0;i<2;i++)
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
	for(int i=0;i<numRecords;i++)
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
		if(!strncmp(fcmbuf,"FCM",3)) {
			FCEU_PrintError("FCM File format is no longer supported. Please use Tools > Convert FCM");
			return false;
		}
	}

	//movie must start with "version 3"
	char buf[9];
	curr = fp->ftell();
	fp->fread(buf,9);
	fp->fseek(curr,SEEK_SET);
	if(fp->fail()) return false;
	if(memcmp(buf,"version 3",9))
		return false;

	std::string key,value;
	enum {
		NEWLINE, KEY, SEPARATOR, VALUE, RECORD, COMMENT, SUBTITLE
	} state = NEWLINE;
	bool bail = false;
	bool iswhitespace, isrecchar, isnewline;
	int c;
	for(;;)
	{
		if(size--<=0) goto bail;
		c = fp->fgetc();
		if(c == -1)
			goto bail;
		iswhitespace = (c==' '||c=='\t');
		isrecchar = (c=='|');
		isnewline = (c==10||c==13);
		if(isrecchar && movieData.binaryFlag && !stopAfterHeader)
		{
			LoadFM2_binarychunk(movieData, fp, size);
			return true;
		} else if (isnewline && movieData.loadFrameCount == movieData.records.size())
			// exit prematurely if loaded the specified amound of records
			return true;
		switch(state) {
		case NEWLINE:
			if(isnewline) goto done;
			if(iswhitespace) goto done;
			if(isrecchar)
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
			if(iswhitespace) goto doseparator;
			if(isnewline) goto commit;
			key += c;
			break;
		case SEPARATOR:
			doseparator:
			state = SEPARATOR;
			if(isnewline) goto commit;
			if(!iswhitespace) goto dovalue;
			break;
		case VALUE:
			dovalue:
			state = VALUE;
			if(isnewline) goto commit;
			value += c;
		default:;
		}
		goto done;

		bail:
		bail = true;
		if(state == VALUE) goto commit;
		goto done;
		commit:
		movieData.installValue(key,value);
		state = NEWLINE;
		done: ;
		if(bail) break;
	}

	return true;
}

/// Stop movie playback.
static void StopPlayback() {
	movieMode = MOVIEMODE_INACTIVE;
}

// Stop movie playback without closing the movie.
static void FinishPlayback()
{
	extern int closeFinishedMovie;
	if (closeFinishedMovie)
		StopPlayback();
	else
	{
		FCEU_DispMessage("Movie finished playing.",0);
		movieMode = MOVIEMODE_FINISHED;
	}
}

static void closeRecordingMovie()
{
	if(osRecordingMovie)
	{
		delete osRecordingMovie;
		osRecordingMovie = 0;
	}
}

/// Stop movie recording
static void StopRecording()
{
	FCEU_DispMessage("Movie recording stopped.",0);
	movieMode = MOVIEMODE_INACTIVE;

	closeRecordingMovie();
}

void FCEUI_StopMovie()
{
	if(suppressMovieStop)
		return;

	if(movieMode == MOVIEMODE_PLAY || movieMode == MOVIEMODE_FINISHED)
		StopPlayback();
	else if(movieMode == MOVIEMODE_RECORD)
		StopRecording();

	curMovieFilename[0] = 0;			//No longer a current movie filename
	freshMovie = false;					//No longer a fresh movie loaded
}

void poweron(bool shouldDisableBatteryLoading)
{
	//// make a for-movie-recording power-on clear the game's save data, too
	//extern char lastLoadedGameName [2048];
	//extern int disableBatteryLoading, suppressAddPowerCommand;
	//suppressAddPowerCommand=1;
	//if(shouldDisableBatteryLoading) disableBatteryLoading=1;
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
	//if(shouldDisableBatteryLoading) disableBatteryLoading=0;
	//suppressAddPowerCommand=0;

	extern int disableBatteryLoading;
	disableBatteryLoading = 1;
	PowerNES();
	disableBatteryLoading = 0;
}

void FCEUMOV_CreateCleanMovie()
{
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
void FCEUMOV_ClearCommands()
{
	_currCommand = 0;
}

bool FCEUMOV_FromPoweron()
{
	return movieFromPoweron;
}
bool MovieData::loadSavestateFrom(std::vector<uint8>* buf)
{
  EMUFILE_MEMORY ms(buf);
  return FCEUSS_LoadFP(&ms,SSLOADPARAM_BACKUP, NULL);
}

void MovieData::dumpSavestateTo(std::vector<uint8>* buf, int compressionLevel) {
  EMUFILE_MEMORY ms(buf);
  FCEUSS_SaveMS(&ms, compressionLevel, NULL);
  ms.trim();
}

static void openRecordingMovie(const char* fname) {
	osRecordingMovie = FCEUD_UTF8_fstream(fname, "wb");
	if(!osRecordingMovie)
		FCEU_PrintError("Error opening movie output file: %s",fname);
	strcpy(curMovieFilename, fname);
}

//the main interaction point between the emulator and the movie system.
//either dumps the current joystick state or loads one state from the movie
void FCEUMOV_AddInputState() {
  if(movieMode == MOVIEMODE_PLAY)
    {
      //stop when we run out of frames
      if(currFrameCounter >= (int)currMovieData.records.size())
	{
	  FinishPlayback();
	  //tell all drivers to poll input and set up their logical states
	  for(int port=0;port<2;port++)
	    joyports[port].driver->Update(port,joyports[port].ptr,joyports[port].attrib);
	  portFC.driver->Update(portFC.ptr,portFC.attrib);
	}
      else
	{
	  MovieRecord* mr = &currMovieData.records[currFrameCounter];

	  //reset and power cycle if necessary
	  if(mr->command_power())
	    PowerNES();
	  if(mr->command_reset())
	    ResetNES();
	  if(mr->command_fds_insert())
	    FCEU_FDSInsert();
	  if(mr->command_fds_select())
	    FCEU_FDSSelect();

	  joyports[0].load(mr);
	  joyports[1].load(mr);
	}

      //pause the movie at a specified frame
      if(FCEUMOV_ShouldPause() && FCEUI_EmulationPaused()==0)
	{
	  FCEUI_ToggleEmulationPause();
	  FCEU_DispMessage("Paused at specified movie frame",0);
	}

    }
  else if(movieMode == MOVIEMODE_RECORD)
    {
      MovieRecord mr;

      joyports[0].log(&mr);
      joyports[1].log(&mr);
      mr.commands = _currCommand;
      _currCommand = 0;

      //Adelikat: in normal mode, this is done at the time of loading a savestate in read+write mode
      //If the user chooses it can be delayed to here
      if (fullSaveStateLoads && (currFrameCounter < (int)currMovieData.records.size()))
	currMovieData.truncateAt(currFrameCounter);

      mr.dump(&currMovieData, osRecordingMovie,currMovieData.records.size());	// to disk

      currMovieData.records.push_back(mr);
    }

  currFrameCounter++;

  extern uint8 joy[4];
  memcpy(&cur_input_display,joy,4);
}


//TODO
void FCEUMOV_AddCommand(int cmd) {
	// do nothing if not recording a movie
	if(movieMode != MOVIEMODE_RECORD && movieMode != MOVIEMODE_TASEDITOR)
		return;

	//NOTE: EMOVIECMD matches FCEUNPCMD_RESET and FCEUNPCMD_POWER
	//we are lucky (well, I planned it that way)

        #if 0   
	// broke this to deprecate netplay constants -tom7
	switch(cmd) {
		case FCEUNPCMD_FDSINSERT: cmd = MOVIECMD_FDS_INSERT; break;
		case FCEUNPCMD_FDSSELECT: cmd = MOVIECMD_FDS_SELECT; break;
	}
	#endif

	_currCommand |= cmd;
}

int FCEUMOV_WriteState(EMUFILE* os) {
	//we are supposed to dump the movie data into the savestate
	if(movieMode == MOVIEMODE_RECORD || movieMode == MOVIEMODE_PLAY || movieMode == MOVIEMODE_FINISHED)
		return currMovieData.dump(os, true);
	else return 0;
}

// returns
int CheckTimelines(MovieData& stateMovie, MovieData& currMovie) {
	// end_frame = min(urrMovie.records.size(), stateMovie.records.size(), currFrameCounter)
	int end_frame = currMovie.records.size();
	if (end_frame > (int)stateMovie.records.size())
		end_frame = stateMovie.records.size();
	if (end_frame > currFrameCounter)
		end_frame = currFrameCounter;

	for (int x = 0; x < end_frame; x++)
	{
		if (!stateMovie.records[x].Compare(currMovie.records[x]))
			return x;
	}
	// no mismatch found
	return -1;
}


static bool load_successful;

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
  if(!LoadFM2(tempMovieData, is, size, false)) {
    is->fseek((uint32)curr+size,SEEK_SET);
    return false;
  }

  //----------------
  //complex TAS logic for loadstate
  //fully conforms to the savestate logic documented in the Laws of TAS
  //http://tasvideos.org/LawsOfTAS/OnSavestates.html
  //----------------

  /*
    Playback or Recording + Read-only

    * Check that GUID of movie and savestate-movie must match or else error
    o on error: a message informing that the savestate doesn't belong to this movie. This is a GUID mismatch error. Give user a choice to load it anyway.
    + failstate: if use declines, loadstate attempt canceled, movie can resume as if not attempted if user has backup savstates enabled else stop movie
    * Check that movie and savestate-movie are in same timeline. If not then this is a wrong timeline error.
    o on error: a message informing that the savestate doesn't belong to this movie
    + failstate: loadstate attempt canceled, movie can resume as if not attempted if user has backup savestates enabled else stop movie
    * Check that savestate-movie is not greater than movie. If it's greater then this is a future event error and is not allowed in read-only
    o on error: message informing that the savestate is from a frame after the last frame of the movie
    + failstate - loadstate attempt cancelled, movie can resume if user has backup savesattes enabled, else stop movie
    * Check that savestate framcount <= savestate movie length. If not this is a post-movie savestate and is not allowed in read-only
    o on error: message informing that the savestate is from a frame after the last frame of the savestated movie
    + failstate - loadstate attempt cancelled, movie can resume if user has backup savesattes enabled, else stop movie
    * All error checks have passed, state will be loaded
    * Movie contained in the savestate will be discarded
    * Movie is now in Playback mode

    Playback, Recording + Read+write

    * Check that GUID of movie and savestate-movie must match or else error
    o on error: a message informing that the savestate doesn't belong to this movie. This is a GUID mismatch error. Give user a choice to load it anyway.
    + failstate: if use declines, loadstate attempt canceled, movie can resume as if not attempted (stop movie if resume fails)canceled, movie can resume if backup savestates enabled else stopmovie
    * Check that savestate framcount <= savestate movie length. If not this is a post-movie savestate
    o on post-movie: See post-movie event section.
    * savestate passed all error checks and will now be loaded in its entirety and replace movie (note: there will be no truncation yet)
    * current framecount will be set to savestate framecount
    * on the next frame of input, movie will be truncated to framecount
    o (note: savestate-movie can be a future event of the movie timeline, or a completely new timeline and it is still allowed)
    * Rerecord count of movie will be incremented
    * Movie is now in record mode

    Post-movie savestate event

    * Whan a savestate is loaded and is determined that the savestate-movie length is less than the savestate framecount then it is a post-movie savestate. These occur when a savestate was made during Movie Finished mode.
    * If read+write, the entire savestate movie will be loaded and replace current movie.
    * If read-only, the savestate movie will be discarded
    * Mode will be switched to Move Finished
    * Savestate will be loaded
    * Current framecount changes to savestate framecount
    * User will have control of input as if Movie inactive mode
    */

  if(movieMode == MOVIEMODE_PLAY || movieMode == MOVIEMODE_RECORD || 
     movieMode == MOVIEMODE_FINISHED) {
    //handle moviefile mismatch
    if(tempMovieData.guid != currMovieData.guid) {
      //mbg 8/18/08 - this code  can be used to turn the error message into an OK/CANCEL
#if defined(WIN32) && !defined(NOWINSTUFF)

      std::string msg = "There is a mismatch between savestate's movie and current movie.\ncurrent: " + currMovieData.guid.toString() + "\nsavestate: " + tempMovieData.guid.toString() + "\n\nThis means that you have loaded a savestate belonging to a different movie than the one you are playing now.\n\nContinue loading this savestate anyway?";
      extern HWND pwindow;
      int result = MessageBox(pwindow,msg.c_str(),"Error loading savestate",MB_OKCANCEL);
      if(result == IDCANCEL) {
	  if (!backupSavestates) //If backups are disabled we can just resume normally since we can't restore so stop movie and inform user
	    {
	      FCEU_PrintError("Unable to restore backup, movie playback stopped.");
	      FCEUI_StopMovie();
	    }

	  return false;
	}
#else
      if (!backupSavestates) //If backups are disabled we can just resume normally since we can't restore so stop movie and inform user
	{
	  FCEU_PrintError("Mismatch between savestate's movie and current movie.\ncurrent: %s\nsavestate: %s\nUnable to restore backup, movie playback stopped.\n",currMovieData.guid.toString().c_str(),tempMovieData.guid.toString().c_str());
	  FCEUI_StopMovie();
	}
      else
	FCEU_PrintError("Mismatch between savestate's movie and current movie.\ncurrent: %s\nsavestate: %s\n",currMovieData.guid.toString().c_str(),tempMovieData.guid.toString().c_str());

      return false;
#endif
    }

    closeRecordingMovie();

    if (movie_readonly)
      {
	// currFrameCounter at this point represents the savestate framecount
	int frame_of_mismatch = CheckTimelines(tempMovieData, currMovieData);
	if (frame_of_mismatch >= 0)
	  {
	    // Wrong timeline, do apprioriate logic here
	    if (!backupSavestates)	//If backups are disabled we can just resume normally since we can't restore so stop movie and inform user
	      {
		FCEU_PrintError("Error: Savestate not in the same timeline as movie!\nFrame %d branches from current timeline\nUnable to restore backup, movie playback stopped.", frame_of_mismatch);
		FCEUI_StopMovie();
	      } else
	      FCEU_PrintError("Error: Savestate not in the same timeline as movie!\nFrame %d branches from current timeline", frame_of_mismatch);
	    return false;
	  } else if (movieMode == MOVIEMODE_FINISHED
		     && currFrameCounter > (int)currMovieData.records.size()
		     && currMovieData.records.size() == tempMovieData.records.size())
	  {
	    // special case (in MOVIEMODE_FINISHED mode)
	    // allow loading post-movie savestates that were made after finishing current movie

	  } else if (currFrameCounter > (int)currMovieData.records.size())
	  {
	    // this is future event state, don't allow it
	    //TODO: turn frame counter to red to get attention
	    if (!backupSavestates)	//If backups are disabled we can just resume normally since we can't restore so stop movie and inform user
	      {
		FCEU_PrintError("Error: Savestate is from a frame (%d) after the final frame in the movie (%d). This is not permitted.\nUnable to restore backup, movie playback stopped.", currFrameCounter, currMovieData.records.size()-1);
		FCEUI_StopMovie();
	      } else
	      FCEU_PrintError("Savestate is from a frame (%d) after the final frame in the movie (%d). This is not permitted.", currFrameCounter, currMovieData.records.size()-1);
	    return false;
	  } else if (currFrameCounter > (int)tempMovieData.records.size())
	  {
	    // this is post-movie savestate, don't allow it
	    //TODO: turn frame counter to red to get attention
	    if (!backupSavestates)	//If backups are disabled we can just resume normally since we can't restore so stop movie and inform user
	      {
		FCEU_PrintError("Error: Savestate is from a frame (%d) after the final frame in the savestated movie (%d). This is not permitted.\nUnable to restore backup, movie playback stopped.", currFrameCounter, tempMovieData.records.size()-1);
		FCEUI_StopMovie();
	      } else
	      FCEU_PrintError("Savestate is from a frame (%d) after the final frame in the savestated movie (%d). This is not permitted.", currFrameCounter, tempMovieData.records.size()-1);
	    return false;
	  } else
	  {
	    // Finally, this is a savestate file for this movie
	    movieMode = MOVIEMODE_PLAY;
	  }
      }
    else //Read + write
      {
	if (currFrameCounter > (int)tempMovieData.records.size())
	  {
	    //This is a post movie savestate, handle it differently
	    //Replace movie contents but then switch to movie finished mode
	    currMovieData = tempMovieData;
	    openRecordingMovie(curMovieFilename);
	    currMovieData.dump(osRecordingMovie, false/*currMovieData.binaryFlag*/);
	    FinishPlayback();
	  }
	else
	  {
	    //truncate before we copy, just to save some time, unless the user selects a full copy option
	    if (!fullSaveStateLoads) 
	      tempMovieData.truncateAt(currFrameCounter); //we can only assume this here since we have checked that the frame counter is not greater than the movie data
	    currMovieData = tempMovieData;

	    currRerecordCount++;

	    currMovieData.rerecordCount = currRerecordCount;
	    openRecordingMovie(curMovieFilename);
	    currMovieData.dump(osRecordingMovie, false/*currMovieData.binaryFlag*/);
	    movieMode = MOVIEMODE_RECORD;

	  }
      }
  }

  load_successful = true;

  return true;
}

void FCEUMOV_PreLoad(void) {
	load_successful=0;
}

bool FCEUMOV_PostLoad(void) {
	if(movieMode == MOVIEMODE_INACTIVE || movieMode == MOVIEMODE_TASEDITOR)
		return true;
	else
		return load_successful;
}

void FCEUI_CreateMovieFile(std::string fn)
{
	MovieData md = currMovieData;							//Get current movie data
	EMUFILE* outf = FCEUD_UTF8_fstream(fn, "wb");		//open/create file
	md.dump(outf,false);									//dump movie data
	delete outf;											//clean up, delete file object
}

void FCEUI_MakeBackupMovie(bool dispMessage)
{
	//This function generates backup movie files
	string currentFn;					//Current movie fillename
	string backupFn;					//Target backup filename
	string tempFn;						//temp used in back filename creation
	stringstream stream;
	int x;								//Temp variable for string manip
	bool exist = false;					//Used to test if filename exists
	bool overflow = false;				//Used for special situation when backup numbering exceeds limit

	currentFn = curMovieFilename;		//Get current moviefilename
	backupFn = curMovieFilename;		//Make backup filename the same as current moviefilename
	x = backupFn.find_last_of(".");		 //Find file extension
	backupFn = backupFn.substr(0,x);	//Remove extension
	tempFn = backupFn;					//Store the filename at this point
	for (unsigned int backNum=0;backNum<999;backNum++) //999 = arbituary limit to backup files
	{
		stream.str("");					 //Clear stream
		if (backNum > 99)
			stream << "-" << backNum;	 //assign backNum to stream
		else if (backNum <=99 && backNum >= 10)
			stream << "-0";				//Make it 010, etc if two digits
		else
			stream << "-00" << backNum;	 //Make it 001, etc if single digit
		backupFn.append(stream.str());	 //add number to bak filename
		backupFn.append(".bak");		 //add extension

		exist = CheckFileExists(backupFn.c_str());	//Check if file exists

		if (!exist)
			break;						//Yeah yeah, I should use a do loop or something
		else
		{
			backupFn = tempFn;			//Before we loop again, reset the filename

			if (backNum == 999)			//If 999 exists, we have overflowed, let's handle that
			{
				backupFn.append("-001.bak"); //We are going to simply overwrite 001.bak
				overflow = true;		//Flag that we have exceeded limit
				break;					//Just in case
			}
		}
	}
	FCEUI_CreateMovieFile(backupFn);

	//TODO, decide if fstream successfully opened the file and print error message if it doesn't

	if (dispMessage)	//If we should inform the user
	{
		if (overflow)
			FCEUI_DispMessage("Backup overflow, overwriting %s",0,backupFn.c_str()); //Inform user of overflow
		else
			FCEUI_DispMessage("%s created",0,backupFn.c_str()); //Inform user of backup filename
	}
}

