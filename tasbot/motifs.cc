
#include "motifs.h"

#include <algorithm>
#include <set>
#include <string>
#include <iostream>
#include <sstream>

#include "tasbot.h"

Motifs::Motifs() {}

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
    char w[128] = {0};
    sprintf(w, "%f", it->second);
    string s = w;
    s += InputsToString(inputs);
    out += s + "\n";
  }
  printf("%s\n", out.c_str());
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
    }
  }

  if (!current.empty()) {
    motifs[current] += 1.0;
  }
}
