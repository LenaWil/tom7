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

FceuFile::FceuFile() {}

FceuFile::~FceuFile() {
  delete stream;
}

uint64 FCEU_ftell(FceuFile *fp) {
  return fp->stream->ftell();
}

// XXX: Get rid of "ext" param.
FceuFile *FCEU_fopen(const std::string &path,
		     const char *mode, const char *ext) {
  // XXX simplify away; see below
  bool read = (string)mode == "rb";
  bool write = (string)mode == "wb";
  if (!read && !write) {
    FCEU_PrintError("invalid file open mode specified "
		    "(only wb and rb are supported)");
    return 0;
  }

  // This is weird -- the only supported mode is read, and write always fails?
  // (Probably because of archives? But that means we can probably just get
  // rid of mode at all call sites. But FDS tries "wb"...)
  // -tom7
  if (!read) {
    return nullptr;
  }

  // if the archive contained no files, try to open it the old fashioned way
  EMUFILE_FILE* fp = FCEUD_UTF8_fstream(path,mode);
  if (!fp || (fp->get_fp() == nullptr)) {
    return 0;
  }

  // Here we used to try zip files. -tom7

  // open a plain old file
  FceuFile *fceufp = new FceuFile();
  fceufp->filename = path;
  fceufp->stream = fp;
  FCEU_fseek(fceufp,0,SEEK_END);
  fceufp->size = FCEU_ftell(fceufp);
  FCEU_fseek(fceufp,0,SEEK_SET);

  return fceufp;
}

int FCEU_fclose(FceuFile *fp) {
  delete fp;
  return 1;
}

uint64 FCEU_fread(void *ptr, size_t size, size_t nmemb, FceuFile *fp) {
  return fp->stream->fread((char*)ptr,size*nmemb);
}

int FCEU_fseek(FceuFile *fp, long offset, int whence) {
  fp->stream->fseek(offset,whence);
  return FCEU_ftell(fp);
}

int FCEU_read32le(uint32 *Bufo, FceuFile *fp) {
  return read32le(Bufo, fp->stream);
}

int FCEU_fgetc(FceuFile *fp) {
  return fp->stream->fgetc();
}

uint64 FCEU_fgetsize(FceuFile *fp) {
  return fp->size;
}

// TODO(tom7): We should probably not let this thing save battery backup
// files; they should be serialized as part of the state at most.
//
// These are currently producing dummy names like ".sav" always. Don't
// let fceulib save!
string FCEU_MakeSaveFilename() {
  return ".sav";
}

string FCEU_MakeFDSFilename() {
  return ".fds";
}

string FCEU_MakeFDSROMFilename() {
  return "disksys.rom";
}

string FCEU_MakePaletteFilename() {
  return ".pal";
}
