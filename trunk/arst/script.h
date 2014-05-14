
#ifndef __SCRIPT_H
#define __SCRIPT_H

#include <string>
#include <vector>
using namespace std;

// Tells us what words are where. Based on samples in the movie. Data
// structure is a series of non-overlapping partitions, which always
// cover the entire movie. A partition can either contain a string
// (meaning some word spoken in that range) or the empty string
// (assertion that there are no words in that range) or "*" meaning
// that it's unknown. The last chunk is assumed to cover the range
// out until infinity.
struct Line {
  Line(int sample, const string &s) : sample(sample), s(s) {}
  int sample;
  string s;
  bool Unknown() const { return s == "*"; }
};

struct ScriptStats {
  int num_words;
  int num_silent;
  int num_unknown;
  // By number of samples.
  double fraction_labeled;
  double fraction_silent;
  double fraction_words;
};

struct Script {
  // Never empty; lines[0].sample == 0.
  vector<Line> lines;

  static Script *Load(int max_samples,
                      const string &filename);
  static Script *FromString(int max_samples,
                            const string &contents);
  // Whole movie is "*".
  static Script *Empty(int max_samples);

  // Get the sample field from the next line, or max_samples if
  // it's the last one.
  int GetEnd(int idx);
  // Get the size in samples, GetEnd(idx) - lines[idx].sample.
  int GetSize(int idx);

  int GetLineIdx(int f);
  Line *GetLine(int f);

  // Insert a split at the given sample.
  // Succeeds, returning true, unless the split would be zero-length.
  // (Linear time in the number of lines.)
  bool Split(int sample);

  void Save(const string &filename);

  void DebugPrint();

  // Linear time.
  ScriptStats ComputeStats();

 private:
  int max_samples;
  int GetLineIdxRec(int f, int lb, int ub);
  // Use factory; this doesn't initialize elt 0.
  explicit Script(int ms) : max_samples(ms) {}
};

#endif
