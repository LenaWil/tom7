
#ifndef __MOTIFS_H
#define __MOTIFS_H

#include <vector>
#include <map>

#include "tasbot.h"
#include "../cc-lib/arcfour.h"

struct Motifs {
  // Create empty.
  Motifs();

  static Motifs *LoadFromFile(const std::string &filename);

  // Does not save checkpoints.
  void SaveToFile(const std::string &filename) const;

  void AddInputs(const vector<uint8> &inputs);

  // Returns a motif uniformly at random.
  // Linear time.
  const vector<uint8> &RandomMotif();

  // Returns one according to current weights.
  // Linear time.
  const vector<uint8> &RandomWeightedMotif();

  const vector<uint8> &RandomMotifWith(ArcFour *rc);
  const vector<uint8> &RandomWeightedMotifWith(ArcFour *rc);

  vector< vector<uint8> > AllMotifs() const;

  bool IsMotif(const vector<uint8> &inputs);

  // Increment a counter (just used for diagnostics) that says
  // how many times this motif was picked.
  void Pick(const vector<uint8> &inputs);

  // Returns a modifiable double for the input,
  // or NULL if it has been added with AddInputs (etc.).
  double *GetWeightPtr(const vector<uint8> &inputs);

  // Save the current weights at the frame number (assumed
  // to be monotonically increasing), so that they can be
  // drawn with DrawSVG.
  void Checkpoint(int framenum);

  void SaveHTML(const string &filename) const;

private:
  struct Info {
  Info() : weight(0.0), picked(0) {}
  Info(double w) : weight(w), picked(0) {}
    double weight;
    int picked;
    // Optional, for diagnostics.
    vector< pair<int, double> > history;
  };

  struct Resorted;
  static bool WeightDescending(const Resorted &a, const Resorted &b);

  // XXX accessors or something?
  typedef map<vector<uint8>, Info> Weighted;
  Weighted motifs;
  ArcFour rc;

  NOT_COPYABLE(Motifs);
};

#endif
