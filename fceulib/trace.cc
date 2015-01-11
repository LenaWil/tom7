
#include "trace.h"
#include "stringprintf.h"

#include <stdarg.h>

#include <cstdio>
#include <utility>

using namespace std;

using uint8 = uint8_t;
using uint32 = uint32_t;
using uint64 = uint64_t;

// RLE compression and decompression from cc-lib.
namespace {
struct RLE {
  typedef uint8_t uint8;
  static constexpr uint8 DEFAULT_CUTOFF = 128;

  static vector<uint8> Compress(const vector<uint8> &in);
  // Aborts if encoding is invalid.
  static vector<uint8> Decompress(const vector<uint8> &in);

  // Same, but give the maximum anti-run length; this trades off the
  // efficiency of representing runs with the efficiency of represting
  // anti-runs (with all of the left-over lengths). Encoding and
  // decoding must agree on this value. Note that since a run or
  // anti-run of length 0 is strictly wasteful (of the next byte),
  // we treat every value as a run or anti-run of length value+1.
  static vector<uint8> CompressEx(const vector<uint8> &in,
				  uint8 run_cutoff);
  // Returns true on success, clears and modifies out to contain the
  // decoded bytes. On failure, out will be in a valid but unspecified
  // state.
  static bool DecompressEx(const vector<uint8> &in,
			   uint8 run_cutoff,
			   vector<uint8> *out);
};

// static
constexpr uint8 RLE::DEFAULT_CUTOFF;

// static
vector<uint8> RLE::Compress(const vector<uint8> &in) {
  return CompressEx(in, 128);
}

// static
vector<uint8> RLE::Decompress(const vector<uint8> &in) {
  vector<uint8> out;
  if (!DecompressEx(in, 128, &out)) abort();
  return out;
}

// static
vector<uint8> RLE::CompressEx(const vector<uint8> &in,
			      uint8 run_cutoff) {
  // No idea how big this needs to be until we compress...
  // (There are lower bounds like in.size() / 128 but it's
  // hard to imagine that being useful.
  vector<uint8> out;

  const int max_run_length = (int)run_cutoff + 1;
  // Note that we always encode an antirun of length 1 as a run of
  // length 1 (control byte 0), so it is possible that there may be no
  // antiruns allowed if this evaluates to 1 because run_cutoff is
  // 255.
  const int max_antirun_length = (int)(255 - run_cutoff) + 1;

  for (int i = 0; i < in.size(); /* in loop */) {
    // Greedy: Grab the longest prefix of bytes that are the same,
    // up to max_run_length.
    const uint8 target = in[i];
    // We already know that we have a run of at least length 1 and
    // that this is legal.
    int run_length = 1;
    while (run_length < max_run_length &&
	   i + run_length < in.size() &&
	   in[i + run_length] == target) {
      run_length++;
    }

    if (run_length > 1) {
      // printf("at %d, Run of %dx%d\n", i, target, run_length);
      const uint8 control = run_length - 1;
      out.push_back(control);
      out.push_back(target);

      i += run_length;
    } else {
      // The next two bytes are not the same, but we don't want to
      // include the second byte in the anti-run unless the one
      // following IT is also different (otherwise it should be part
      // of a run). Increase the size of the anti_run up to our
      // maximum, or until BEFORE we see a pair of bytes that are the
      // same.
      int anti_run_length = 1;
      while (anti_run_length < max_antirun_length &&
	     i + anti_run_length + 1 < in.size() &&
	     in[i + anti_run_length] != 
	     in[i + anti_run_length + 1]) {
	anti_run_length++;
      }

      if (anti_run_length == 1) {
	const uint8 control = 0;
	out.push_back(control);
	out.push_back(target);
	i++;
      } else {
	const uint8 control = (anti_run_length - 1) + run_cutoff;
	out.reserve(out.size() + anti_run_length + 1);
	out.push_back(control);
	for (int a = 0; a < anti_run_length; a++) {
	  out.push_back(in[i]);
	  i++;
	}
      }
    }
  }
  return out;
}

bool RLE::DecompressEx(const vector<uint8> &in,
		       uint8 run_cutoff,
		       vector<uint8> *out) {
  out->clear();
  
  for (int i = 0; i < in.size(); /* in loop */) {
    const uint8 control = in[i];
    i++;
    if (control <= run_cutoff) {
      // If less than the run cutoff, we treat it as a run.
      const int run_length = control + 1;
      
      if (i >= in.size()) {
	return false;
      }
      
      const uint8 b = in[i];
      i++;
      out->reserve(out->size() + run_length);
      for (int j = 0; j < run_length; j++)
	out->push_back(b);

    } else {
      // run_cutoff may be e.g. 100, but we know from the if that the
      // control is strictly greater than the cutoff, so (control -
      // run_cutoff) is strictly greater than 0. We never need an
      // anti-run of length 0 (pointless) or 1 (same as run of 1,
      // represented as 0) so we code starting at 2.
      const int antirun_length = control - run_cutoff + 1;
      
      if (i + antirun_length >= in.size()) {
	return false;
      }

      out->reserve(out->size() + antirun_length);
      
      for (int j = 0; j < antirun_length; j++) {
	out->push_back(in[i]);
	i++;
      }
    }
  }

  return true;
};

}  // namespace

// Doesn't work??
#if 0
void Traces::TraceF(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  string traced = StringPrintf(fmt, ap);
  va_end(ap);

  TraceString(traced);
}
#endif

void Traces::TraceString(const string &s) {
  Trace t(STRING);
  t.data_string = s;
  Write(t);
}

void Traces::TraceMemory(const vector<uint8> &v) {
  Trace t(MEMORY);
  t.data_memory = v;
  Write(t);
}

Traces::Traces() {
  fp = fopen("trace.bin", "wb");
  if (fp == nullptr) {
    fprintf(stderr, "Unable to open trace file.\n");
    abort();
  }
}

void Traces::Write(const Trace &t) {
  auto Write32 = [this](uint32 w) {
    for (int i = 0; i < 4; i++) {
      fputc(w & 255, this->fp);
      w >>= 8;
    }
  };
  
  auto Write64 = [this](uint64 w) {
    for (int i = 0; i < 8; i++) {
      fputc(w & 255, this->fp);
      w >>= 8;
    }
  };

  auto Write8 = [this](uint8 w) {
    fputc(w, this->fp);
  };

  // Each record starts with a tag byte.
  Write8(t.type);
  switch (t.type) {
  case STRING:
    Write32(t.data_string.size());
    for (char c : t.data_string)
      Write8((uint8)c);
    break;
  case MEMORY: {
    vector<uint8> encoded = RLE::Compress(t.data_memory);
    Write32(encoded.size());
    for (uint8 w : encoded)
      Write8(w);
    break;
  }
  case NUMBER:
    Write64(t.data_number);
    break;
  default:
    fprintf(stderr, "Can't write unknown trace type %d\n", (int)t.type);
    abort();
  }
  // We also always have a newline, just to make paging through the
  // (binary) file simpler.
  Write8('\n');
  fflush(fp);
}

// static
vector<Traces::Trace> Traces::ReadFromFile(const string &filename) {
  vector<Trace> out;
  FILE *fp = fopen(filename.c_str(), "rb");

  auto Read8 = [&fp](uint8 *w) -> bool {
    int c = fgetc(fp);
    if (c == EOF) return false;
    *w = c & 255;
    return true;
  };

  auto Read32 = [&Read8](uint32 *w) {
    uint32 out = 0u;
    for (int i = 0; i < 4; i++) {
      out <<= 8;
      uint8 a;
      if (!Read8(&a)) return false;
      out |= a;
    }
    *w = out;
    return true;
  };

  auto Read64 = [&Read8](uint64 *w) {
    uint64 out = 0u;
    for (int i = 0; i < 8; i++) {
      out <<= 8;
      uint8 a;
      if (!Read8(&a)) return false;
      out |= a;
    }
    *w = out;
    return true;
  };

  static_assert(sizeof (char) == sizeof (uint8), 
		"Assumed in this code.");
  uint8 tag;
  while (Read8(&tag)) {
    Trace t((TraceType)tag);
    switch (tag) {
    case STRING: {
      uint32 len;
      if (!Read32(&len)) {
	fprintf(stderr, "Incomplete string record.\n");
	abort();
      }
      t.data_string.resize(len);
      for (int i = 0; i < len; i++) {
	if (!Read8((uint8*)&t.data_string[i])) {
	  fprintf(stderr, "Incomplete string.\n");
	  abort();
	}
      }
      break;
    }
    case MEMORY: {
      uint32 len;
      if (!Read32(&len)) {
	fprintf(stderr, "Incomplete memory record.\n");
	abort();
      }
      t.data_memory.resize(len);
      for (int i = 0; i < len; i++) {
	if (!Read8(&t.data_memory[i])) {
	  fprintf(stderr, "Incomplete memory.\n");
	  abort();
	}
      }
      break;
    }
    case NUMBER:
      if (!Read64(&t.data_number)) {
	fprintf(stderr, "Incomplete number.\n");
	abort();
      }
      break;
    }

    uint8 newline;
    if (!Read8(&newline) || newline != '\n') {
      fprintf(stderr, "Expected record-terminating newline.\n");
      abort();
    }

    out.push_back(std::move(t));
  }
  
  return out;
}
