
/* Writes a WAV file containing NES sound. Only supports
   16-bit mono audio at a sample rate of XXX. This code
   is mostly the same as fceu/wave.* but wrapped in a
   class. */

#include "tasbot.h"


struct WaveFile {
  // Opens the file.
  explicit WaveFile(const string &filename);
  ~WaveFile();

  // Also closed on destruction, but this makes it explicit.
  void Close();

  void Write(const vector<int16> &vec);

 private:
  FILE *outfile;
  long wsize;
};
