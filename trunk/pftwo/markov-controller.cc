#include "markov-controller.h"

#include "pftwo.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/randutil.h"

uint8 MarkovController::InputInDomain() const {
  return input_in_domain;
}

uint8 MarkovController::RandomNext(uint8 cur, ArcFour *rc) const {
  auto it = matrix.find(cur);
  if (it == matrix.end()) return input_in_domain;

  const auto &row = it->second;
  uint32 r = Rand32(rc);
  for (int i = 0; ; i++) {
    const auto &e = row[i];
    if (r <= e.first) return e.second;
    r -= e.first;
  }
  // (Impossible)
  return input_in_domain;
}

MarkovController::MarkovController(const vector<uint8> &v) {
  CHECK(!v.empty());
  input_in_domain = v[0];

  vector<unordered_map<uint8, int>> transitions;
  transitions.resize(256);

  for (int i = 0; i < v.size(); i++) {
    const int j = (i + 1) % v.size();
    const uint8 src = v[i];
    const uint8 dst = v[j];
    
    transitions[src][dst]++;
  }

  // Total number of transitions in each row.
  vector<int> totals(256, 0);
  for (int i = 0; i < 256; i++) {
    for (const auto &p : transitions[i]) {
      totals[i] += p.second;
    }
  }

  // Now put each nonempty row into the matrix.
  for (int i = 0; i < 256; i++) {
    if (totals[i] > 0) {
      vector<pair<uint32, uint8>> row;

      uint32 leftover = ~0;
      const double scale = leftover;
      const double total = totals[i];
      const unordered_map<uint8, int> &dests =
	transitions[i];
      CHECK(!dests.empty());
      const int num_dests = dests.size();
      
      for (const auto &p : dests) {
	if (row.size() == num_dests - 1) {
	  // Make sure it adds exactly to ~0 by using the leftover
	  // value in the last slot.
	  if (leftover > 0) row.push_back({leftover, p.first});
	} else {
	  const double frac = p.second / total;
	  // Truncates (rounding down) -- this way can never use
	  // up more than the leftover value.
	  const uint32 mass = frac * scale;
	  if (mass > 0) row.push_back({mass, p.first});

	  CHECK(mass <= leftover);
	  leftover -= mass;
	}
      }
      
      // PERF: Sorting here will make "indexing" into the probability
      // mass more efficient, but doesn't affect correctness.
      matrix[(uint8)i] = std::move(row);
    }
  }

  CHECK(matrix.find(input_in_domain) != matrix.end());
}
