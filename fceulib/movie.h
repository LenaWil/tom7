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

  void Clone(MovieRecord& sourceRec);
  void clear();
private:
};

class MovieData {
 public:
  MovieData();
  // Default Values: MovieData::MovieData()

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
};


extern char curMovieFilename[512];
//--------------------------------------------------

#endif
