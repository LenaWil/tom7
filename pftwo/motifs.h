
#ifndef __MOTIFS_H
#define __MOTIFS_H

#include <vector>
#include <map>
#include <string>

#include "pftwo.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/randutil.h"
// #include "util.h"

struct Motifs {
  // Create empty.
  Motifs();

  static Motifs *LoadFromFile(const std::string &filename);

  // Does not save checkpoints.
  void SaveToFile(const std::string &filename) const;

  void AddInputs(const std::vector<uint8> &inputs);

  // Returns a motif uniformly at random.
  // Linear time.
  const std::vector<uint8> &RandomMotif();

  // Returns one according to current weights.
  // Linear time.
  const std::vector<uint8> &RandomWeightedMotif();

  const std::vector<uint8> &RandomMotifWith(ArcFour *rc);
  const std::vector<uint8> &RandomWeightedMotifWith(ArcFour *rc);

  // Returns NULL if none can be found.
  template<class Container>
  const std::vector<uint8> *RandomWeightedMotifNotIn(const Container &c);

  // Return the total weight, which allows a single weight to
  // be interpreted as a fraction of the total (for example
  // for capping weights.)
  double GetTotalWeight() const;

  std::vector< std::vector<uint8> > AllMotifs() const;

  bool IsMotif(const std::vector<uint8> &inputs);

  // Increment a counter (just used for diagnostics) that says
  // how many times this motif was picked.
  void Pick(const std::vector<uint8> &inputs);

  // Returns a modifiable double for the input,
  // or NULL if it has been added with AddInputs (etc.).
  double *GetWeightPtr(const std::vector<uint8> &inputs);

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
    std::vector< pair<int, double> > history;
  };

  struct Resorted;
  static bool WeightDescending(const Resorted &a, const Resorted &b);

  // XXX accessors or something?
  typedef std::map<std::vector<uint8>, Info> Weighted;
  Weighted motifs;
  ArcFour rc;

  NOT_COPYABLE(Motifs);
};


// Template implementations follow.

// See the related methods in the .cc file for commentary.
template<class Container>
const std::vector<uint8> *Motifs::RandomWeightedMotifNotIn(const Container &c) {
  double totalweight = 0.0;
  for (Weighted::const_iterator it = motifs.begin();
       it != motifs.end(); ++it) {
    if (c.find(it->first) == c.end()) {
      totalweight += it->second.weight;
    }
  }

  // "index" into the continuous bins
  double sample = RandDouble(&rc) * totalweight;

  for (Weighted::const_iterator it = motifs.begin();
       it != motifs.end(); ++it) {
    if (c.find(it->first) == c.end()) {
      if (sample <= it->second.weight) {
        return &it->first;
      }
      sample -= it->second.weight;
    }
  }

  return NULL;
}


#endif
