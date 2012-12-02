
#ifndef __MOTIFS_H
#define __MOTIFS_H

#include "tasbot.h"

struct Motifs {
  // Create empty.
  Motifs();

  static Motifs *LoadFromFile(const std::string &filename);

  void SaveToFile(const std::string &filename) const;

  void AddInputs(const vector<uint8> &inputs);

 private:
  typedef map<vector<uint8>, double> Weighted;
  Weighted motifs;

  NOT_COPYABLE(Motifs);
};

#endif
