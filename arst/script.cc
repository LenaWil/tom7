#include "script.h"
#include "arst.h"

Script *Script::Load(int ms, const string &filename) {
  return FromString(ms, Util::ReadFile(filename));
}

Script *Script::FromString(int ms, const string &contents) {
  vector<string> lines = Util::SplitToLines(contents);
  Script *s = new Script(ms);

  int lastsample = -1;
  for (int i = 0; i < lines.size(); i++) {
    string line = lines[i];
    int sample = atoi(Util::chop(line).c_str());
    line = Util::losewhitel(line);
    CHECK(sample > lastsample);
    s->lines.push_back(Line(sample, line));
    lastsample = sample;
  }

  return s;
}

Script *Script::Empty(int ms) {
  // Easy, just one big unknown chunk.
  Script *s = new Script(ms);
  s->lines.push_back(Line(0, "*"));
  return s;
}

void Script::Save(const string &filename) {
  string contents;
  for (int i = 0; i < lines.size(); i++) {
    contents += StringPrintf("%d %s\n",
			     lines[i].sample,
			     lines[i].s.c_str());
  }
  Util::WriteFile(filename, contents);
}

void Script::DebugPrint() {
  for (int i = 0; i < lines.size(); i++) {
    printf("[%d] %d %s\n",
	   i,
	   lines[i].sample,
	   lines[i].s.c_str());
  }
}

// find line matching f in indices [lb, ub).
int Script::GetLineIdxRec(int f, int lb, int ub) {
  CHECK(lb < ub);
  int idx = ((ub - lb) >> 1) + lb;
  CHECK(idx < lines.size());

  int ival_low = lines[idx].sample;
  int ival_high = (idx == lines.size() - 1) ? 0x7FFFFFFE :
    lines[idx + 1].sample;
  if (f < ival_low) {
    return GetLineIdxRec(f, lb, idx);
  } else if (f >= ival_high) {
    return GetLineIdxRec(f, idx + 1, ub);
  } else {
    // In this interval.
    return idx;
  }
}

int Script::GetLineIdx(int f) {
  CHECK(f >= 0);
  return GetLineIdxRec(f, 0, lines.size());
}

Line *Script::GetLine(int f) {
  return &lines[GetLineIdx(f)];
}

bool Script::Split(int sample) {
  CHECK(sample >= 0);
  int idx = GetLineIdx(sample);
  if (lines[idx].sample == sample)
    return false;
  lines.insert(lines.begin() + idx + 1,
	       Line(sample, "*"));
  return true;
}

int Script::GetEnd(int idx) {
  if (idx + 1 < lines.size())
    return lines[idx + 1].sample;
  else
    return max_samples;
}

int Script::GetSize(int idx) {
  return GetEnd(idx) - lines[idx].sample;
}

ScriptStats Script::ComputeStats() {
  int num_words = 0, num_silent = 0, num_unknown = 0;
  double samples_labeled = 0.0,
    samples_silent = 0.0,
    samples_words = 0.0;

  for (int i = 0; i < lines.size(); i++) {
    const Line &line = lines[i];
    int len = (i + 1 < lines.size()) ?
      lines[i + 1].sample - line.sample :
      max_samples - line.sample;
    if (line.Unknown()) {
      num_unknown++;
    } else {
      samples_labeled += len;
      if (line.s.empty()) {
	num_silent++;
	samples_silent += len;
      } else {
	num_words++;
	samples_words += len;
      }
    }
  }

  ScriptStats stats;
  stats.num_words = num_words;
  stats.num_silent = num_silent;
  stats.num_unknown = num_unknown;
  stats.fraction_labeled = samples_labeled / max_samples;
  stats.fraction_silent = samples_silent / max_samples;
  stats.fraction_words = samples_words / max_samples;
  return stats;
}
