
#ifndef __MOTIFS_H
#define __MOTIFS_H

#include "tasbot.h"
#include "../cc-lib/arcfour.h"

struct Motifs {
  // Create empty.
  Motifs();

  static Motifs *LoadFromFile(const std::string &filename);

  void SaveToFile(const std::string &filename) const;

  void AddInputs(const vector<uint8> &inputs);

  // Returns a motif uniformly at random.
  // Linear time.
  const vector<uint8> &RandomMotif();

  // Returns one according to current weights.
  // Linear time.
  const vector<uint8> &RandomWeightedMotif();

  vector< vector<uint8> > AllMotifs() const;

private:

  // XXX accessors or something?
  typedef map<vector<uint8>, double> Weighted;
  Weighted motifs;
  ArcFour rc;

  NOT_COPYABLE(Motifs);
};

#endif
