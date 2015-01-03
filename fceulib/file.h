#ifndef _FCEU_FILE_H_
#define _FCEU_FILE_H_

#include <string>
#include <iostream>
#include "types.h"
#include "emufile.h"

struct FCEUFILE {
  //the stream you can use to access the data
  //std::iostream *stream;
  EMUFILE *stream = nullptr;

  //the name of the file, or the logical name of the file within the archive
  std::string filename;

  // a weirdly derived value.. maybe a path to a file, or maybe
  // a path to a file which doesnt exist but which is in an
  // archive in the same directory
  std::string logicalPath;

  //the filename of the archive (maybe "" if it is not in an archive)
  std::string archiveFilename;

  //a the path to the filename, possibly using | to get into the archive
  std::string fullFilename;

  //the number of files that were in the archive
  int archiveCount = -1;

  //the index of the file within the archive
  int archiveIndex;

  //the size of the file
  int size;

  //whether the file is contained in an archive
  bool isArchive() { return archiveCount > 0; }

  FCEUFILE() {}

  ~FCEUFILE() {
    delete stream;
  }

  enum {
    READ, WRITE, READWRITE
  } mode;
};

struct FCEUARCHIVEFILEINFO_ITEM {
  std::string name;
  uint32 size, index;
};

class FCEUARCHIVEFILEINFO : public std::vector<FCEUARCHIVEFILEINFO_ITEM> {
public:
  void FilterByExtension(const char** ext);
};

struct ArchiveScanRecord {
  ArchiveScanRecord() {}
  ArchiveScanRecord(int _type, int _numFiles) {
    type = _type;
    numFilesInArchive = _numFiles;
  }
  int type = -1;

  //be careful: this is the number of files in the archive.
  //the size of the files variable might be different.
  int numFilesInArchive = 0;

  FCEUARCHIVEFILEINFO files;

  bool isArchive() { return type != -1; }
};


FCEUFILE *FCEU_fopen(const char *path, char *mode, char *ext, int index=-1,
		     const char** extensions = 0);
int FCEU_fclose(FCEUFILE*);
uint64 FCEU_fread(void *ptr, size_t size, size_t nmemb, FCEUFILE*);
int FCEU_fseek(FCEUFILE*, long offset, int whence);
int FCEU_read32le(uint32 *Bufo, FCEUFILE*);
int FCEU_fgetc(FCEUFILE*);
uint64 FCEU_fgetsize(FCEUFILE*);

// Initializes the local base name, from which we derive .sav and .pal, etc.
void GetFileBase(const char *f);

// Broke MakeFName into separate functions where it remained. -tom7
std::string FCEU_MakeSaveFilename();
std::string FCEU_MakeFDSFilename();
std::string FCEU_MakeFDSROMFilename();
std::string FCEU_MakePaletteFilename();

#endif
