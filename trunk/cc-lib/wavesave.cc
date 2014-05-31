
// This code follows the structure of sml-lib/files/wave.sml mostly, to
// facilitate making them feature-compatible.

#include "wavesave.h"

#include <string>
#include <vector>
#include <utility>

using namespace std;

// Definitely would be useful to be able to write 24-bit or 32-bit waves..
#define BITS_PER_SAMPLE 16

typedef unsigned char uint8;

namespace {
struct Info {
  int databytes;
  int formatsize;
  int blockalign;
  int bytespersec;
  int nchannels;
  int nframes;
  int bits;
};

// Deduced by template from input arg.
struct Format {
  Format(int b, int c, int f) : bps(b), nchannels(c), nframes(f) {}
  int bps;
  int nchannels;
  int nframes;
};
}

template<class T>
static Format GetFormat(const T &samples);

template<>
Format GetFormat(const vector<pair<float, float>> &samples) {
  return Format(BITS_PER_SAMPLE, 2, samples.size());
}

static Info GetInfo(const Format &f, int samplespersec) {
  int databytes = (f.bps / 8) * f.nchannels * f.nframes;
  int blockalign = f.nchannels * (f.bps / 8);

  Info info;
  info.databytes = databytes;
  info.formatsize = 16;
  info.blockalign = blockalign;
  info.bytespersec = samplespersec * blockalign;
  info.nchannels = f.nchannels;
  info.nframes = f.nframes;
  info.bits = f.bps;
  return info;
}

static int BytesNeeded(const Format &f, int samplerate) {
  Info info = GetInfo(f, samplerate);
  return 
    /* RIFF + size + WAVE */
    4 + 4 + 4 +
    /* actual bytes plus riff header */
    (info.formatsize + 8) +
    /* actual bytes plus riff header */
    (info.databytes + 8);
}

// Prevent dependency on util.
static bool util_WriteFileBytes(const string &fn,
				const vector<unsigned char> &bytes) {
  FILE * f = fopen(fn.c_str(), "wb");
  if (!f) return false;

  /* XXX check failure */
  fwrite(&bytes[0], 1, bytes.size(), f);

  fclose(f);

  return true;
}

// Write the header, including the data chunk header.
static void WriteHeader(const Format &format, int rate,
			vector<uint8> *bytes) {
  auto wb = [&bytes](uint8 b) { bytes->push_back(b); };
  auto wid = [&wb](const char *s) {
    wb(s[0]);
    wb(s[1]);
    wb(s[2]);
    wb(s[3]);
  };
  /* Write in LSB always. */
  auto w32 = [&wb](unsigned int i) {
    wb(i & 255);
    wb((i >> 8) & 255);
    wb((i >> 16) & 255);
    wb((i >> 24) & 255);
  };
  auto w16 = [&wb](int i) {
    wb(i & 255);
    wb((i >> 8) & 255);
  };
  
  Info info = GetInfo(format, rate);
  int bytesneeded = BytesNeeded(format, rate);

  /* RIFF header */
  wid("RIFF");
  /* minus RIFF, WAVE */
  w32(bytesneeded - 8);
  wid("WAVE");
  /* Format header. Note space in string: */
  wid("fmt ");
  w32(info.formatsize);
  /* compression code 1 = PCM */
  w16(1);
  w16(info.nchannels);
  w32(rate);
  w32(info.bytespersec);
  w16(info.blockalign);
  w16(BITS_PER_SAMPLE);
  /* no extra format bytes */
  /* w16(0); */
  wid("data");
  w32(info.databytes);
}

template<class T>
void WriteData(const T& samples, vector<uint8> *bytes);

template<>
void WriteData(const vector<pair<float, float>> &samples,
	       vector<uint8> *bytes) {
  auto w16 = [&bytes](int i) {
    bytes->push_back((uint8)(i & 255));
    bytes->push_back((uint8)((i >> 8) & 255));
  };
  
  for (int i = 0; i < samples.size(); i++) {
    const pair<float, float> &p = samples[i];
    int left = p.first * 32767.0;
    int right = p.second * 32767.0;
    w16(left);
    w16(right);
  }
}

bool WaveSave::SaveStereo(const string &filename,
			  const vector<pair<float, float>> &samples,
			  int samplerate) {
  Format format = GetFormat(samples);
  vector<uint8> bytes;
  bytes.reserve(BytesNeeded(format, samplerate));

  WriteHeader(format, samplerate, &bytes);
  WriteData(samples, &bytes);

  return util_WriteFileBytes(filename, bytes);
}
