#ifndef __MOVIE_H_
#define __MOVIE_H_

#include <vector>
#include <map>
#include <string>
#include <ostream>
#include <stdlib.h>

#include "state.h"
#include "input/zapper.h"
#include "utils/guid.h"
#include "utils/md5.h"
#include "utils/fixedarray.h"

void FCEUMOV_AddInputState();

// XXX moviemode is always inactive now. simplify -tom7
enum EMOVIEMODE {
  MOVIEMODE_INACTIVE = 1,
  MOVIEMODE_RECORD = 2,
  MOVIEMODE_PLAY = 4,
  MOVIEMODE_TASEDITOR = 8,
  MOVIEMODE_FINISHED = 16
};

enum EMOVIECMD {
  MOVIECMD_RESET = 1,
  MOVIECMD_POWER = 2,
  MOVIECMD_FDS_INSERT = 4,
  MOVIECMD_FDS_SELECT = 8
};

class MovieData;
class MovieRecord {
public:
	MovieRecord();
	FixedArray<uint8,4> joysticks;

	struct {
		uint8 x,y,b,bogo;
		uint64 zaphit;
	} zappers[2];

	//misc commands like reset, etc.
	//small now to save space; we might need to support more commands later.
	//the disk format will support up to 64bit if necessary
	uint8 commands;
	bool command_reset() { return (commands&MOVIECMD_RESET)!=0; }
	bool command_power() { return (commands&MOVIECMD_POWER)!=0; }
	bool command_fds_insert() { return (commands&MOVIECMD_FDS_INSERT)!=0; }
	bool command_fds_select() { return (commands&MOVIECMD_FDS_SELECT)!=0; }

	void toggleBit(int joy, int bit)
	{
		joysticks[joy] ^= mask(bit);
	}

	void setBit(int joy, int bit)
	{
		joysticks[joy] |= mask(bit);
	}

	void clearBit(int joy, int bit)
	{
		joysticks[joy] &= ~mask(bit);
	}

	void setBitValue(int joy, int bit, bool val)
	{
		if(val) setBit(joy,bit);
		else clearBit(joy,bit);
	}

	bool checkBit(int joy, int bit)
	{
		return (joysticks[joy] & mask(bit))!=0;
	}

	bool Compare(MovieRecord& compareRec);
	void Clone(MovieRecord& sourceRec);
	void clear();

	void parse(MovieData* md, EMUFILE* is);
	bool parseBinary(MovieData* md, EMUFILE* is);

	void dumpBinary(MovieData* md, EMUFILE* os, int index);
	void parseJoy(EMUFILE* is, uint8& joystate);
	void dumpJoy(EMUFILE* os, uint8 joystate);

	static const char mnemonics[8];

private:
	int mask(int bit) { return 1<<bit; }
};

class MovieData {
 public:
  MovieData();
  // Default Values: MovieData::MovieData()

  int version;
  int emuVersion;
  int fds;
  //todo - somehow force mutual exclusion for poweron and reset (with an error in the parser)
  bool palFlag;
  bool PPUflag;
  MD5DATA romChecksum;
  std::string romFilename;
  std::vector<uint8> savestate;
  std::vector<MovieRecord> records;
  // Always empty now -tom7
  std::vector<std::string> comments;
  std::vector<std::string> subtitles;
  int rerecordCount;
  FCEU_Guid guid;

  //was the frame data stored in binary?
  bool binaryFlag;
  // TAS Editor project files contain additional data after input
  int loadFrameCount;

  //which ports are defined for the movie
  int ports[3];
  //whether fourscore is enabled
  bool fourscore;
  //whether microphone is enabled
  bool microphone;

  int getNumRecords() { return records.size(); }

  class TDictionary : public std::map<std::string,std::string> {
  public:
    bool containsKey(std::string key) {
      return find(key) != end();
    }

    void tryInstallBool(std::string key, bool& val) {
      if(containsKey(key))
	val = atoi(operator [](key).c_str())!=0;
    }

    void tryInstallString(std::string key, std::string& val) {
      if(containsKey(key))
	val = operator [](key);
    }

    void tryInstallInt(std::string key, int& val) {
      if(containsKey(key))
	val = atoi(operator [](key).c_str());
    }

  };

  void truncateAt(int frame);

  void clearRecordRange(int start, int len);
  void insertEmpty(int at, int frames);
  void cloneRegion(int at, int frames);

private:
  void installInt(std::string& val, int& var) {
    var = atoi(val.c_str());
  }

  void installBool(std::string& val, bool& var) {
    var = atoi(val.c_str())!=0;
  }
};


extern char curMovieFilename[512];
//--------------------------------------------------

// extern const SFORMAT FCEUMOV_STATEINFO[];

#endif
