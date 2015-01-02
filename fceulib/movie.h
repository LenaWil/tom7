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

private:
  void Clone(MovieRecord& sourceRec);
  void clear();
};


extern char curMovieFilename[512];
//--------------------------------------------------

#endif
