#include "wave.h"

#include <cstdio>
#include <cstdlib>

#include "base/logging.h"

using uint16 = uint16_t;
using int16 = int16_t;

WaveFile::WaveFile(const string &filename, int r) : wsize(0) {
  outfile = fopen(filename.c_str(), "wb");
  CHECK(outfile);

  /* Write the header. */
  fputs("RIFF", outfile);
  fseek(outfile, 4, SEEK_CUR);  // Skip size
  fputs("WAVEfmt ", outfile);

  fputc(0x10, outfile);
  fputc(0, outfile);
  fputc(0, outfile);
  fputc(0, outfile);

  fputc(1, outfile);     // PCM
  fputc(0, outfile);

  fputc(1, outfile);     // Monophonic
  fputc(0, outfile);

  fputc(r&0xFF, outfile);
  fputc((r>>8)&0xFF, outfile);
  fputc((r>>16)&0xFF, outfile);
  fputc((r>>24)&0xFF, outfile);
  r<<=1;
  fputc(r&0xFF, outfile);
  fputc((r>>8)&0xFF, outfile);
  fputc((r>>16)&0xFF, outfile);
  fputc((r>>24)&0xFF, outfile);
  fputc(2, outfile);
  fputc(0, outfile);
  fputc(16, outfile);
  fputc(0, outfile);

  fputs("data", outfile);
  fseek(outfile, 4, SEEK_CUR);
}

void WaveFile::Write(const vector<int16> &vec) {
  CHECK(outfile);
  for (int i = 0; i < vec.size(); i++) {
    uint16 tmp = vec[i];
    CHECK(EOF != fputc(tmp & 255, outfile));
    CHECK(EOF != fputc(tmp >> 8, outfile));
    wsize += 2;
  }
}

WaveFile::~WaveFile() {
  if (outfile != NULL) {
    Close();
  }
}

void WaveFile::Close() {
 CHECK(outfile);

 long s = ftell(outfile) - 8;
 fseek(outfile, 4, SEEK_SET);
 fputc(s&0xFF, outfile);
 fputc((s>>8)&0xFF, outfile);
 fputc((s>>16)&0xFF, outfile);
 fputc((s>>24)&0xFF, outfile);

 fseek(outfile, 0x28, SEEK_SET);
 s = wsize;
 fputc(s&0xFF, outfile);
 fputc((s>>8)&0xFF, outfile);
 fputc((s>>16)&0xFF, outfile);
 fputc((s>>24)&0xFF, outfile);

 fclose(outfile);
 outfile = NULL;
 wsize = 0;
}
