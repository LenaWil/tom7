#ifndef __MARKOV_CONTROLLER_H
#define __MARKOV_CONTROLLER_H

#include "pftwo.h"

#include <unordered_map>
#include "../cc-lib/arcfour.h"

struct MarkovController {
  uint8 InputInDomain() const;
  uint8 RandomNext(uint8 current, ArcFour *rc) const;
  
  // The inputs are treated cyclically.
  MarkovController(const vector<uint8> &inputs);

 private:
  uint8 input_in_domain = 0;
  // For an input in the domain, all the inputs that could follow it,
  // along with the associated nonzero probability mass. The uint32s
  // in a row all add to 2^32-1.
  unordered_map<uint8, vector<pair<uint32, uint8>>> matrix;
};

#endif
