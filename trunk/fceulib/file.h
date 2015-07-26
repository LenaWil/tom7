#ifndef _FCEU_FILE_H_
#define _FCEU_FILE_H_

#include <string>
#include <iostream>
#include "types.h"
#include "emufile.h"

struct FceuFile {
  FceuFile();
  ~FceuFile();

  // the stream you can use to access the data
  // std::iostream *stream;
  EMUFILE *stream = nullptr;

  // the name of the file, or the logical name of the file within the archive
  std::string filename;

  // the size of the file
  int size = 0;

  enum {
    READ, WRITE, READWRITE
  } mode;
};

FceuFile *FCEU_fopen(const std::string &path, const char *mode, const char *ext);
int FCEU_fclose(FceuFile*);
uint64 FCEU_fread(void *ptr, size_t size, size_t nmemb, FceuFile*);
int FCEU_fseek(FceuFile*, long offset, int whence);
int FCEU_read32le(uint32 *Bufo, FceuFile*);
int FCEU_fgetc(FceuFile*);
uint64 FCEU_fgetsize(FceuFile*);

// XXX This whole thing can probably be deleted. -tom7
// Broke MakeFName into separate functions where it remained. -tom7
std::string FCEU_MakeSaveFilename();
std::string FCEU_MakeFDSFilename();
std::string FCEU_MakeFDSROMFilename();
std::string FCEU_MakePaletteFilename();

#endif
