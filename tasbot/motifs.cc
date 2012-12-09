
#include "motifs.h"

#include <algorithm>
#include <set>
#include <string>
#include <iostream>
#include <sstream>

#include "tasbot.h"
#include "../cc-lib/arcfour.h"

Motifs::Motifs() : rc("motifs") {}

static string InputsToString(const vector<uint8> &inputs) {
  string s;
  for (int i = 0; i < inputs.size(); i++) {
    char d[64] = {0};
    sprintf(d, "%s%d", (i ? " " : ""), inputs[i]);
    s += d;
  }
  return s;
}

Motifs *Motifs::LoadFromFile(const string &filename) {
  Motifs *mm = new Motifs;
  vector<string> lines = Util::ReadFileToLines(filename);
  for (int i = 0; i < lines.size(); i++) {
    stringstream ss(lines[i], stringstream::in);
    double d;
    ss >> d;
    vector<uint8> inputs;
    while (!ss.eof()) {
      int i;
      ss >> i;
      inputs.push_back((uint8)i);
    }

    printf("MOTIF: %f | %s\n", d, InputsToString(inputs).c_str());
    mm->motifs.insert(make_pair(inputs, d));  
  }

  return mm;
}

void Motifs::SaveToFile(const string &filename) const {
  string out;
  for (Weighted::const_iterator it = motifs.begin(); 
       it != motifs.end(); ++it) {
    const vector<uint8> &inputs = it->first;
    string s = StringPrintf("%f ", it->second);
    s += InputsToString(inputs);
    out += s + "\n";
  }
  // printf("%s\n", out.c_str());
  printf("Wrote %lld motifs to %s.\n", motifs.size(), filename.c_str());
  Util::WriteFile(filename, out);
}

void Motifs::AddInputs(const vector<uint8> &inputs) {
  // Right now, just chunk into 10-input parts.
  static const int CHUNK_SIZE = 10;
  vector<uint8> current;

  for (int i = 0; i < inputs.size(); i++) {
    current.push_back(inputs[i]);
    if (current.size() == CHUNK_SIZE) {
      motifs[current] += 1.0;
      current.clear();
    }
  }

  if (!current.empty()) {
    motifs[current] += 1.0;
  }
}

static uint32 RandomInt32(ArcFour *rc) {
  uint32 b = rc->Byte();
  b = (b << 8) | rc->Byte();
  b = (b << 8) | rc->Byte();
  b = (b << 8) | rc->Byte();
  return b;
}

// Random double in [0,1]. Note precision issues.
static double RandomDouble(ArcFour *rc) {
  return (double)RandomInt32(rc) / (double)(uint32)0xFFFFFFFF;
}

vector< vector<uint8> > Motifs::AllMotifs() const {
  vector< vector<uint8> > motifvec;
  for (Weighted::const_iterator it = motifs.begin();
       it != motifs.end(); ++it) {
    motifvec.push_back(it->first);
  }
  return motifvec;
}

const vector<uint8> &Motifs::RandomMotif() {
  const vector<uint8> *res = NULL;
  uint32 best = ~0;

  CHECK(!motifs.empty());
  for (Weighted::const_iterator it = motifs.begin();
       it != motifs.end(); ++it) {
    uint32 thisone = RandomInt32(&rc);
    if (res == NULL || thisone < best) {
      best = thisone;
      res = &it->first;
    }
  }

  return *res;
}

// Note there are several fancy ways to do this, but I
// have seen them have numerical stability problems in
// practice. I'm favoring correctness and simplicity
// here.
const vector<uint8> &Motifs::RandomWeightedMotif() {
  double totalweight = 0;
  // PERF: Could cache this.
  for (Weighted::const_iterator it = motifs.begin();
       it != motifs.end(); ++it) {
    totalweight += it->second;
  }

  // "index" into the continuous bins
  double sample = RandomDouble(&rc) * totalweight;
  
  for (Weighted::const_iterator it = motifs.begin();
       it != motifs.end(); ++it) {
    if (sample <= it->second) {
      return it->first;
    }
    sample -= it->second;
  }
  
  // Arbitrarily award roundoff errors to the first one.
  printf("roundoff error of %f in RandomWeightedMotif\n", sample);
  CHECK(!motifs.empty());
  return motifs.begin()->first;
}
