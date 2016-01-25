#include "n-markov-controller.h"

#include "pftwo.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/randutil.h"

NMarkovController::History NMarkovController::HistoryInDomain() const {
  return history_in_domain;
}

// Avoid dependency on SimpleFM2 just for error messages.
static string InputToString(uint8 input) {
  char f[9] = {0};
  static const char gamepad[] = "RLDUTSBA";
  for (int j = 0; j < 8; j++) {
    f[j] = (input & (1 << (7 - j))) ? gamepad[j] : '.';
  }
  return (string)f;
}

static string HistoryString(int n, NMarkovController::History h) {
  vector<uint8> out;
  for (int i = 0; i < n; i++) {
    out.push_back((uint8)(h & 0xFF));
    h >>= 8;
  }

  string res;
  for (int i = out.size() - 1; i >= 0; i--) {
    if (!res.empty()) res += ", ";
    res += InputToString(out[i]);
  }
  return res;
}

uint8 NMarkovController::RandomNext(History cur, ArcFour *rc) const {
  auto it = matrix.find(cur);
  if (it == matrix.end()) {
    // The way we use this, it should be impossible, right?
    // XXX We can't just return history_in_domain because it is potentially
    // many sybmols. What we should do is emit symbols that get us back
    // into the history_in_domain state.
    // CHECK(false) << "History " << cur << " is not represented:\n" <<
    // HistoryString(n, cur);
    // return history_in_domain;

    // XXX this assumes 0^n is in the input, which is typical. But
    // we should do something that guarantees it.
    return 0;
  }

  const auto &row = it->second;
  uint32 r = Rand32(rc);
  for (int i = 0; ; i++) {
    const auto &e = row[i];
    if (r <= e.first) return e.second;
    r -= e.first;
  }

  LOG(FATAL) << "Impossible.";
}

static uint64 MakeHistoryBitmask(int n) {
  uint64 ret = 0ULL;
  while (n--) {
    ret <<= 8;
    ret |= 0xFF;
  }
  return ret;
}

NMarkovController::History NMarkovController::Push(
    History h, uint8 next) const {
  // Use bitmask last in case n is actually 0.
  return ((h << 8) | next) & history_bitmask;
}

NMarkovController::NMarkovController(const vector<uint8> &v, int n)
  : n(n), history_bitmask(MakeHistoryBitmask(n)) {
  CHECK(n >= 0 && n <= 8) << "The history must fit in a uint64, so "
    "only up to 8 states are supported.";
  
  CHECK(!v.empty());

  // We treat the input cyclically, so make the history_in_domain be
  // the very end of the input. This means that a generator initialized
  // with this history has a chance of outputting the beginning of our
  // training data, which seems like an important property. We also
  // use this to correctly initialize the transition counting below.

  // This is a bit awkward because v may be smaller than the history
  // size.
  history_in_domain = 0ULL;
  for (int i = 0; i < n; i++) {
    // Nominally, start n away from the end of the vector.
    // (e.g. vector has 1 element, n is 1, then idx 0), but
    // add the current offset from that start point, i.
    int idx = v.size() - n + i;
    // But wrap around.
    while (idx < 0) idx += v.size();
    CHECK(idx < v.size());
    history_in_domain = Push(history_in_domain, v[idx]);
  }

  // Rows for each history state, with next symbol and count.
  map<History, unordered_map<uint8, int>> transitions;

  {
    // This is initialized to have the correct value to observe
    // the first input.
    History h = history_in_domain;
    // Each input gets trained on exactly once.
    for (int i = 0; i < v.size(); i++) {
      const uint8 dst = v[i % v.size()];
      transitions[h][dst]++;
      h = Push(h, dst);
    }
    
    CHECK(h == history_in_domain) <<
      "Bug. Expected h to be the history_in_domain sequence, which "
      "is the very tail of the input:\n  " <<
      HistoryString(n, history_in_domain) <<
      "\nbut h is actually this:\n  " <<
      HistoryString(n, h) << "\n";
  }

  // Total number of transitions in each row.
  map<History, int> totals;
  for (const auto &row : transitions) {
    for (const auto &p : row.second) {
      totals[row.first] += p.second;
    }
  }

  // Now put each nonempty row into the matrix.
  for (const auto &transition_row : transitions) {
    const History h = transition_row.first;
    CHECK(totals[h] > 0) << "Bug; should be sparse.";

    vector<pair<uint32, uint8>> row;

    uint32 leftover = ~0U;
    const double scale = leftover;
    const double total = totals[h];
    const unordered_map<uint8, int> &dests = transition_row.second;
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
    matrix[h] = std::move(row);
  }

  // PERF -- sanity check
  for (const auto &p : matrix) {
    uint32 sum = 0U;
    for (const auto &q : p.second) {
      sum += q.first;
    }
    CHECK(sum == 0xFFFFFFFF);
  }
  
  CHECK(matrix.find(history_in_domain) != matrix.end());
}

void NMarkovController::Stats() const {
  map<int, int> counts;
  for (const auto &row : matrix) {
    counts[(int)row.second.size()]++;
  }
  
  fprintf(stderr,
	  "NMarkovController with n=%d.\n"
	  "There are %d distinct states of length n.\n"
	  "Of those, %d are singletons.\n",
	  n, (int)matrix.size(), counts[1]);

  for (const auto &c : counts) {
    fprintf(stderr, "%d destinations: %d rows\n", c.first, c.second);
  }
}
