/*
Copyright (C) 2009-2010 DeSmuME team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

// These are thread compatible. -tom7

// don't use emufile for files bigger than 2GB! you have been warned!
// some day this will be fixed.

#ifndef __EMUFILE_H
#define __EMUFILE_H

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <vector>
#include <algorithm>
#include <string>
#include <stdarg.h>
#include <utility>

#include "types.h"

class EMUFILE {
 protected:
  bool failbit = false;

 public:
  EMUFILE() {}

  virtual ~EMUFILE() {}

  bool fail(bool unset = false) {
    bool ret = failbit;
    if (unset) unfail();
    return ret;
  }
  void unfail() { failbit = false; }

  bool eof() { return size() == ftell(); }

  size_t fread(void* ptr, size_t bytes) { return _fread(ptr, bytes); }

  void unget() { fseek(-1, SEEK_CUR); }

  virtual FILE* get_fp() = 0;

  virtual int fprintf(const char* format, ...) = 0;

  virtual int fgetc() = 0;
  virtual int fputc(int c) = 0;

  virtual size_t _fread(void* ptr, size_t bytes) = 0;

  // removing these return values for now so we can find any code that
  // might be using them and make sure they handle the return values
  // correctly
  virtual void fwrite(const void* ptr, size_t bytes) = 0;

  void write64le(uint64* val);
  void write64le(uint64 val);
  size_t read64le(uint64* val);
  uint64 read64le();
  void write32le(uint32* val);
  void write32le(int32* val) { write32le((uint32*)val); }
  void write32le(uint32 val);
  size_t read32le(uint32* val);
  size_t read32le(int32* val);
  uint32 read32le();
  void write16le(uint16* val);
  void write16le(int16* val) { write16le((uint16*)val); }
  void write16le(uint16 val);
  size_t read16le(int16* Bufo);
  size_t read16le(uint16* val);
  uint16 read16le();
  void write8le(uint8* val);
  void write8le(uint8 val);
  size_t read8le(uint8* val);
  uint8 read8le();
  void writedouble(double* val);
  void writedouble(double val);
  double readdouble();
  size_t readdouble(double* val);

  virtual int fseek(int offset, int origin) = 0;

  virtual int ftell() = 0;
  virtual int size() = 0;
  virtual void fflush() = 0;

  virtual void truncate(int32 length) = 0;
};

class EMUFILE_MEMORY : public EMUFILE {
 protected:
  std::vector<uint8>* vec;
  bool ownvec;
  int32 pos, len;

  void reserve(uint32 amt) {
    if (vec->size() < amt) vec->resize(amt);
  }

 public:
  EMUFILE_MEMORY(std::vector<uint8>* underlying)
      : vec(underlying),
        ownvec(false),
        pos(0),
        len((int32)underlying->size()) {}
  explicit EMUFILE_MEMORY(uint32 preallocate)
      : vec(new std::vector<uint8>()), ownvec(true), pos(0), len(0) {
    vec->resize(preallocate);
    len = preallocate;
  }
  EMUFILE_MEMORY()
      : vec(new std::vector<uint8>()), ownvec(true), pos(0), len(0) {
    vec->reserve(1024);
  }

  EMUFILE_MEMORY(void* buf, int32 size)
      : vec(new std::vector<uint8>()), ownvec(true), pos(0), len(size) {
    vec->resize(size);
    if (size != 0) memcpy(&vec->front(), buf, size);
  }

  ~EMUFILE_MEMORY() override {
    if (ownvec) delete vec;
  }

  virtual void truncate(int32 length) {
    vec->resize(length);
    len = length;
    if (pos > length) pos = length;
  }

  uint8* buf() {
    if (size() == 0) reserve(1);
    return &(*vec)[0];
  }

  std::vector<uint8>* get_vec() { return vec; };

  FILE* get_fp() override { return nullptr; }

  int fprintf(const char* format, ...) override {
    va_list argptr;
    va_start(argptr, format);

    // we don't generate straight into the buffer because it will null
    // terminate (one more byte than we want)
    int amt = vsnprintf(0, 0, format, argptr);
    char* tempbuf = new char[amt + 1];

    va_end(argptr);
    va_start(argptr, format);
    vsprintf(tempbuf, format, argptr);

    fwrite(tempbuf, amt);
    delete[] tempbuf;

    va_end(argptr);
    return amt;
  };

  int fgetc() override {
    uint8 temp;

    // need an optimized codepath
    // if(_fread(&temp,1) != 1)
    //      return EOF;
    // else return temp;
    uint32 remain = len - pos;
    if (remain < 1) {
      failbit = true;
      return -1;
    }
    temp = buf()[pos];
    pos++;
    return temp;
  }

  int fputc(int c) override {
    uint8 temp = (uint8)c;
    // TODO
    // if(fwrite(&temp,1)!=1) return EOF;
    fwrite(&temp, 1);

    return 0;
  }

  size_t _fread(void* ptr, size_t bytes) override;

  // removing these return values for now so we can find any code that
  // might be using them and make sure they handle the return values
  // correctly

  void fwrite(const void* ptr, size_t bytes) override {
    reserve(pos + (int32)bytes);
    memcpy(buf() + pos, ptr, bytes);
    pos += (int32)bytes;
    len = std::max(pos, len);
  }

  int fseek(int offset, int origin) override {
    // work differently for read-only...?
    switch (origin) {
      case SEEK_SET: pos = offset; break;
      case SEEK_CUR: pos += offset; break;
      case SEEK_END: pos = size() + offset; break;
      default: assert(false);
    }
    reserve(pos);
    return 0;
  }

  int ftell() override { return pos; }

  void fflush() override {}

  void set_len(int32 length) {
    len = length;
    if (pos > length) pos = length;
  }

  void trim() { vec->resize(len); }

  int size() override { return (int)len; }
};

class EMUFILE_MEMORY_READONLY : public EMUFILE {
 protected:
  const std::vector<uint8>* vec;
  int32 pos, len;

 public:
  EMUFILE_MEMORY_READONLY(const std::vector<uint8>& underlying)
      : vec(&underlying), pos(0), len((int32)underlying.size()) {}

  void truncate(int32 length) override { abort(); }

  const uint8* buf() { return vec->data(); }

  const std::vector<uint8>* get_vec() { return vec; };

  FILE* get_fp() override { return nullptr; }

  int fprintf(const char* format, ...) override { abort(); }

  int fgetc() override {
    uint32 remain = len - pos;
    if (remain < 1) {
      failbit = true;
      return -1;
    }
    uint8 temp = (*vec)[pos];
    pos++;
    return temp;
  }

  int fputc(int c) override { abort(); }

  size_t _fread(void* ptr, size_t bytes) override;

  // removing these return values for now so we can find any code that
  // might be using them and make sure they handle the return values
  // correctly

  void fwrite(const void* ptr, size_t bytes) override { abort(); }

  int fseek(int offset, int origin) override {
    switch (origin) {
      case SEEK_SET: pos = offset; break;
      case SEEK_CUR: pos += offset; break;
      case SEEK_END: pos = size() + offset; break;
      default: abort();
    }
    return 0;
  }

  int ftell() override { return pos; }

  void fflush() override {}

  void set_len(int32 length) { abort(); }

  void trim() { abort(); }

  int size() override { return (int)len; }
};

class EMUFILE_FILE : public EMUFILE {
 protected:
  FILE* fp;
  std::string fname;
  char mode[16];

 private:
  void open(const char* fname, const char* mode);

 public:
  EMUFILE_FILE(const std::string& fname, const char* mode) {
    open(fname.c_str(), mode);
  }
  EMUFILE_FILE(const char* fname, const char* mode) { open(fname, mode); }

  ~EMUFILE_FILE() override {
    if (nullptr != fp) fclose(fp);
  }

  FILE* get_fp() override { return fp; }

  bool is_open() { return fp != nullptr; }

  void truncate(int32 length) override;

  int fprintf(const char* format, ...) override {
    va_list argptr;
    va_start(argptr, format);
    int ret = ::vfprintf(fp, format, argptr);
    va_end(argptr);
    return ret;
  };

  int fgetc() override { return ::fgetc(fp); }
  int fputc(int c) override { return ::fputc(c, fp); }

  size_t _fread(void* ptr, size_t bytes) override {
    size_t ret = ::fread((void*)ptr, 1, bytes, fp);
    if (ret < bytes) failbit = true;
    return ret;
  }

  // removing these return values for now so we can find any code that
  // might be using them and make sure they handle the return values
  // correctly

  void fwrite(const void* ptr, size_t bytes) override {
    size_t ret = ::fwrite((void*)ptr, 1, bytes, fp);
    if (ret < bytes) failbit = true;
  }

  int fseek(int offset, int origin) override {
    return ::fseek(fp, offset, origin);
  }

  int ftell() override { return (uint32)::ftell(fp); }

  int size() override {
    int oldpos = ftell();
    fseek(0, SEEK_END);
    int len = ftell();
    fseek(oldpos, SEEK_SET);
    return len;
  }

  void fflush() override { ::fflush(fp); }
};

#endif
