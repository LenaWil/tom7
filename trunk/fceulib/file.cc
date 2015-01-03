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

#include <stdio.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fstream>

#ifndef WIN32
#include <zlib.h>
#endif

#include "types.h"
#include "file.h"
#include "utils/endian.h"
#include "utils/memory.h"
#include "utils/md5.h"
#include "driver.h"
#include "types.h"
#include "fceu.h"
#include "state.h"
#include "driver.h"
#include "utils/xstring.h"

using namespace std;

// From movie. Get rid of it. -tom7
char curMovieFilename[512] = {0};

bool bindSavestate = true;	//Toggle that determines if a savestate filename will include the movie filename
static string BaseDirectory;
static char FileExt[2048];	//Includes the . character, as in ".nes"
char FileBase[2048];
static char FileBaseDirectory[2048];

string FCEU_MakeIpsFilename(FileBaseInfo fbi) {
  char ret[FILENAME_MAX] = "";
  sprintf(ret,"%s" PSS "%s%s.ips",fbi.filebasedirectory.c_str(),fbi.filebase.c_str(),fbi.ext.c_str());
  return ret;
}

// Can probably go. -tom7
static void FCEU_SplitArchiveFilename(string src, string& archive, 
				      string& file, string& fileToOpen) {
  size_t pipe = src.find_first_of('|');
  if (pipe == string::npos) {
    archive = "";
    file = src;
    fileToOpen = src;
  } else {
    archive = src.substr(0,pipe);
    file = src.substr(pipe+1);
    fileToOpen = archive;
  }
}

FileBaseInfo CurrentFileBase() {
	return FileBaseInfo(FileBaseDirectory,FileBase,FileExt);
}

FileBaseInfo DetermineFileBase(const char *f) {

	char drv[PATH_MAX], dir[PATH_MAX], name[PATH_MAX], ext[PATH_MAX];
	splitpath(f,drv,dir,name,ext);

        if (dir[0] == 0) strcpy(dir,".");

	return FileBaseInfo((string)drv + dir,name,ext);

}

inline FileBaseInfo DetermineFileBase(const string& str) { return DetermineFileBase(str.c_str()); }

FCEUFILE *FCEU_fopen(const char *path, char *mode, char *ext, int index, 
		     const char **extensions) {
  FCEUFILE *fceufp=0;

  bool read = (string)mode == "rb";
  bool write = (string)mode == "wb";
  if ((read&&write) || (!read&&!write)) {
    FCEU_PrintError("invalid file open mode specified (only wb and rb are supported)");
    return 0;
  }

  string archive,fname,fileToOpen;
  FCEU_SplitArchiveFilename(path,archive,fname,fileToOpen);

  // This is weird -- the only supported mode is read, and write always fails?
  // -tom7
  if (!read) {
    return nullptr;
  }

  ArchiveScanRecord asr = FCEUD_ScanArchive(fileToOpen);
  asr.files.FilterByExtension(extensions);
  if (asr.isArchive()) {
    // Archive files are no longer supported. -tom7
    return nullptr;
  }

  //if the archive contained no files, try to open it the old fashioned way
  EMUFILE_FILE* fp = FCEUD_UTF8_fstream(fileToOpen,mode);
  if (!fp || (fp->get_fp() == NULL)) {
    return 0;
  }

  // Here we used to try zip files. -tom7

  // And here we used to try gzip. -tom7
  {
    uint32 magic;

    // XXX can just skip these gets right? fseek
    // is putting us back at the beginning?
    magic = fp->fgetc();
    magic|=fp->fgetc()<<8;
    magic|=fp->fgetc()<<16;
    fp->fseek(0,SEEK_SET);
  }

  // open a plain old file
  fceufp = new FCEUFILE();
  fceufp->filename = fileToOpen;
  fceufp->logicalPath = fileToOpen;
  fceufp->fullFilename = fileToOpen;
  fceufp->archiveIndex = -1;
  fceufp->stream = fp;
  FCEU_fseek(fceufp,0,SEEK_END);
  fceufp->size = FCEU_ftell(fceufp);
  FCEU_fseek(fceufp,0,SEEK_SET);

  return fceufp;
}

int FCEU_fclose(FCEUFILE *fp)
{
	delete fp;
	return 1;
}

uint64 FCEU_fread(void *ptr, size_t size, size_t nmemb, FCEUFILE *fp)
{
	return fp->stream->fread((char*)ptr,size*nmemb);
}

uint64 FCEU_fwrite(void *ptr, size_t size, size_t nmemb, FCEUFILE *fp)
{
	fp->stream->fwrite((char*)ptr,size*nmemb);
	//todo - how do we tell how many bytes we wrote?
	return nmemb;
}

int FCEU_fseek(FCEUFILE *fp, long offset, int whence)
{
	fp->stream->fseek(offset,whence);

	return FCEU_ftell(fp);
}

uint64 FCEU_ftell(FCEUFILE *fp)
{
	return fp->stream->ftell();
}

int FCEU_read16le(uint16 *val, FCEUFILE *fp)
{
	return read16le(val,fp->stream);
}

int FCEU_read32le(uint32 *Bufo, FCEUFILE *fp)
{
	return read32le(Bufo, fp->stream);
}

int FCEU_fgetc(FCEUFILE *fp)
{
	return fp->stream->fgetc();
}

uint64 FCEU_fgetsize(FCEUFILE *fp)
{
	return fp->size;
}

int FCEU_fisarchive(FCEUFILE *fp)
{
	if (fp->archiveIndex==0) return 0;
	else return 1;
}

// Retrieves the movie filename from curMovieFilename (for adding to
// savestate and auto-save files)
static string GetMfn() {
  string movieFilenamePart;
  extern char curMovieFilename[512];
  if (*curMovieFilename) {
    char drv[PATH_MAX], dir[PATH_MAX], name[PATH_MAX], ext[PATH_MAX];
    splitpath(curMovieFilename,drv,dir,name,ext);
    movieFilenamePart = string(".") + name;
  }
  return movieFilenamePart;
}

/// Updates the base directory
void FCEUI_SetBaseDirectory(string const & dir) {
  BaseDirectory = dir;
}

// Default directories for various things. Should be able to get
// rid of this -tom7
static char *odirs[FCEUIOD__COUNT]={0,};

void FCEUI_SetDirOverride(int which, char *n) {
  //	FCEU_PrintError("odirs[%d]=%s->%s", which, odirs[which], n);
  if (which < FCEUIOD__COUNT) {
    odirs[which] = n;
  }
}

string FCEU_GetPath(int type) {
  char ret[FILENAME_MAX];
  switch(type) {
  case FCEUMKF_STATE:
    if (odirs[FCEUIOD_STATES])
      return (odirs[FCEUIOD_STATES]);
    else
      return BaseDirectory + PSS + "fcs";
    break;
  case FCEUMKF_MEMW:
    if (odirs[FCEUIOD_MEMW])
      return (odirs[FCEUIOD_MEMW]);
    else
      return "";	//adelikat: 03/02/09 - return null so it defaults to last directory used
    //return BaseDirectory + PSS + "tools";
    break;
    //adelikat: TODO: this no longer exist and could be removed (but that would require changing a lot of other directory arrays
  case FCEUMKF_BBOT:
    if (odirs[FCEUIOD_BBOT])
      return (odirs[FCEUIOD_BBOT]);
    else
      return BaseDirectory + PSS + "tools";
    break;
  case FCEUMKF_ROMS:
    if (odirs[FCEUIOD_ROMS])
      return (odirs[FCEUIOD_ROMS]);
    else
      return "";	//adelikat: removing base directory return, should return null it goes to last used directory
    break;
  case FCEUMKF_INPUT:
    if (odirs[FCEUIOD_INPUT])
      return (odirs[FCEUIOD_INPUT]);
    else
      return BaseDirectory + PSS + "tools";
    break;
  case FCEUMKF_AVI:
    if (odirs[FCEUIOD_AVI])
      return (odirs[FCEUIOD_AVI]);
    else
      return "";		//adelikat - 03/02/09 - if no override, should return null and allow the last directory to be used intead
				//return BaseDirectory + PSS + "tools";
    break;
  case FCEUMKF_TASEDITOR:
    return BaseDirectory + PSS + "tools";

  }

  return ret;
}

string FCEU_MakePath(int type, const char* filebase) {
  char ret[FILENAME_MAX];

  switch(type) {
  case FCEUMKF_STATE:
    if (odirs[FCEUIOD_STATES])
      return (string)odirs[FCEUIOD_STATES] + PSS + filebase;
    else
      return BaseDirectory + PSS + "fcs" + PSS + filebase;
    break;
  }
  return ret;
}

string FCEU_MakeFName(int type, int id1, const char *cd1) {
  char ret[FILENAME_MAX] = "";
  struct stat tmpstat;
  string mfnString;
  const char* mfn;	// the movie filename

  switch(type) {
  case FCEUMKF_STATE:
    {
      if (bindSavestate)
	mfnString = GetMfn();
      else
	mfnString = "";

      if (mfnString.length() <= MAX_MOVIEFILENAME_LEN) {
	mfn = mfnString.c_str();
      } else {
	//This caps the movie filename length before adding it to the savestate filename.
	//This helps prevent possible crashes from savestate filenames of excessive length.
	mfnString = mfnString.substr(0, MAX_MOVIEFILENAME_LEN);
	mfn = mfnString.c_str();
      }

      if (odirs[FCEUIOD_STATES]) {
	sprintf(ret,"%s" PSS "%s%s.fc%d",
		odirs[FCEUIOD_STATES],
		FileBase,mfn,id1);
      } else {
	sprintf(ret,"%s" PSS "fcs" PSS 
		"%s%s.fc%d",
		BaseDirectory.c_str(),
		FileBase,mfn,id1);
      }
      if (stat(ret,&tmpstat)==-1) {
	if (odirs[FCEUIOD_STATES]) {
	  sprintf(ret,"%s" PSS "%s%s.fc%d",odirs[FCEUIOD_STATES],FileBase,mfn,id1);
	} else {
	  sprintf(ret,"%s" PSS "fcs" PSS "%s%s.fc%d",BaseDirectory.c_str(),FileBase,mfn,id1);
	}
      }
    }
    break;
  case FCEUMKF_SNAP:
    if (odirs[FCEUIOD_SNAPS])
      sprintf(ret,"%s" PSS "%s-%d.%s",odirs[FCEUIOD_SNAPS],FileBase,id1,cd1);
    else
      sprintf(ret,"%s" PSS "snaps" PSS "%s-%d.%s",BaseDirectory.c_str(),FileBase,id1,cd1);
    break;
  case FCEUMKF_FDS:
    if (odirs[FCEUIOD_NV])
      sprintf(ret,"%s" PSS "%s.fds",odirs[FCEUIOD_NV],FileBase);
    else
      sprintf(ret,"%s" PSS "sav" PSS "%s.fds",BaseDirectory.c_str(),FileBase);
    break;
  case FCEUMKF_SAV:
    if (odirs[FCEUIOD_NV])
      sprintf(ret,"%s" PSS "%s.%s",odirs[FCEUIOD_NV],FileBase,cd1);
    else
      sprintf(ret,"%s" PSS "sav" PSS "%s.%s",BaseDirectory.c_str(),FileBase,cd1);
    if (stat(ret,&tmpstat)==-1)
      {
	if (odirs[FCEUIOD_NV])
	  sprintf(ret,"%s" PSS "%s.%s",odirs[FCEUIOD_NV],FileBase,cd1);
	else
	  sprintf(ret,"%s" PSS "sav" PSS "%s.%s",BaseDirectory.c_str(),FileBase,cd1);
      }
    break;
  case FCEUMKF_AUTOSTATE:
    mfnString = GetMfn();
    mfn = mfnString.c_str();
    if (odirs[FCEUIOD_STATES])
      {
	sprintf(ret,"%s" PSS "%s%s-autosave%d.fcs",odirs[FCEUIOD_STATES],FileBase,mfn,id1);
      }
    else
      {
	sprintf(ret,"%s" PSS "fcs" PSS "%s%s-autosave%d.fcs",BaseDirectory.c_str(),FileBase,mfn,id1);
      }
    if (stat(ret,&tmpstat)==-1)
      {
	if (odirs[FCEUIOD_STATES])
	  {
	    sprintf(ret,"%s" PSS "%s%s-autosave%d.fcs",odirs[FCEUIOD_STATES],FileBase,mfn,id1);
	  }
	else
	  {
	    sprintf(ret,"%s" PSS "fcs" PSS "%s%s-autosave%d.fcs",BaseDirectory.c_str(),FileBase,mfn,id1);
	  }
      }
    break;
  case FCEUMKF_CHEAT:
    if (odirs[FCEUIOD_CHEATS])
      sprintf(ret,"%s" PSS "%s.cht",odirs[FCEUIOD_CHEATS],FileBase);
    else
      sprintf(ret,"%s" PSS "cheats" PSS "%s.cht",BaseDirectory.c_str(),FileBase);
    break;
  case FCEUMKF_GGROM:sprintf(ret,"%s" PSS "gg.rom",BaseDirectory.c_str());break;
  case FCEUMKF_FDSROM:
    if (odirs[FCEUIOD_FDSROM])
      sprintf(ret,"%s" PSS "disksys.rom",odirs[FCEUIOD_FDSROM]);
    else
      sprintf(ret,"%s" PSS "disksys.rom",BaseDirectory.c_str());
    break;
  case FCEUMKF_PALETTE:sprintf(ret,"%s" PSS "%s.pal",BaseDirectory.c_str(),FileBase);break;
  case FCEUMKF_STATEGLOB:
    if (odirs[FCEUIOD_STATES])
      sprintf(ret,"%s" PSS "%s*.fc?",odirs[FCEUIOD_STATES],FileBase);
    else
      sprintf(ret,"%s" PSS "fcs" PSS "%s*.fc?",BaseDirectory.c_str(),FileBase);
    break;
  }

  //convert | to . for archive filenames.
  return mass_replace(ret,"|",".");
}

void GetFileBase(const char *f) {
  FileBaseInfo fbi = DetermineFileBase(f);
  strcpy(FileBase,fbi.filebase.c_str());
  strcpy(FileBaseDirectory,fbi.filebasedirectory.c_str());
}

bool FCEU_isFileInArchive(const char *path) {
  bool isarchive = false;
  FCEUFILE* fp = FCEU_fopen(path,"rb",0,0);
  if (fp) {
    isarchive = fp->isArchive();
    delete fp;
  }
  return isarchive;
}



void FCEUARCHIVEFILEINFO::FilterByExtension(const char** ext) {
  if (!ext) return;
  int count = size();
  for (int i=count-1;i>=0;i--) {
    string fext = getExtension((*this)[i].name.c_str());
    const char** currext = ext;
    while (*currext) {
      if (fext == *currext)
	goto ok;
      currext++;
    }
    this->erase(begin()+i);
  ok:;
  }
}
