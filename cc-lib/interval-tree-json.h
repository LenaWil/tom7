
#ifndef __INTERVAL_TREE_JSON
#define __INTERVAL_TREE_JSON

#include <map>
#include <utility>
#include <vector>
#include <functional>

#include "interval-tree.h"


template<class Idx, class T, class Bisect = IntervalDefaultBisect<Idx>>
struct IntervalTreeJSON {
  using string = std::string;
  using IT = IntervalTree<Idx, T, Bisect>;
  using Interval = typename IT::Interval;
  using Node = typename IT::Node;
  IntervalTreeJSON(const IntervalTree<Idx, T, Bisect> &tree,
		   const std::function<string(const Idx &idx)> &idxjs,
		   const std::function<string(const T &t)> &tjs,
		   int max_depth) : tree(tree), 
				    idxjs(idxjs), 
				    tjs(tjs), 
				    max_depth(max_depth) {}

  // A faithful representation of the interval tree as a JS expression
  // (not actual JSON). The template arguments are callable (e.g.
  // lambdas or std::function), computing a JS expression string from
  // an Idx and the T type, respectively.
  string ToJSON() const {
    std::vector<string> decls;
    string s = ToJSONRec(&decls, 0, tree.root);
    if (decls.size() == 0) {
      return s;
    } else {
      string out = "(function(){\n";
      for (const string &d : decls) {
	out += d;
      }
      out += "return ";
      out += s;
      out += ";}())";
      return out;
    }
  }

  string ToJSONRec(std::vector<string> *decls,
		   int depth,
		   const Node *n) const {
    if (n == nullptr) return "null";
    string ret = (string)"{c:" + idxjs(n->center);

    auto Subtree = [this, &ret, decls, depth](const string &field,
					      const Node *t) {
      if (t != nullptr) {
	ret += (string)"," + field + ":";
	ret += ToJSONRec(decls, depth + 1, t);
      }
    };

    Subtree("l", n->left);
    Subtree("r", n->right);

    auto Intervals =
      [this, &ret](const string &field,
		   const std::multimap<Idx, Interval *> &mmap) {
      ret += (string)"," + field + ":[";
      bool first = true;
      for (const auto &p : mmap) {
	if (!first) ret += ",";
	ret += (string)"{s:" + idxjs(p.second->start) +
	  ",e:" + idxjs(p.second->end) + ",t:" + tjs(p.second->t) +
	  "}";
	first = false;
      }
      ret += "]";
    };
    Intervals("b", n->by_begin);
    Intervals("e", n->by_end);

    ret += "}";
    
    if ((depth % max_depth) == (max_depth - 1)) {
      // PERF could use base 26 (etc.) but watch out for clashes
      // with keywords, builtins, etc.
      string var = (string)"o" + std::to_string(decls->size());
      decls->push_back((string)"var " + var + "=" + ret + ";\n");
      return var;
    } else {
      return ret;
    }
  }

  string ToCompactJSON(const std::function<Idx(const Idx &l,
					       const Idx &r)> minus) const {
    std::vector<string> decls;
    string s = ToCompactJSONRec(&decls, minus, 0, tree.root);
    if (decls.size() == 0) {
      return s;
    } else {
      string out = "(function(){\n";
      for (const string &d : decls) {
	out += d;
      }
      out += "return ";
      out += s;
      out += ";}())";
      return out;
    }
  }

  // format is an array [l, center, by_begin, r],
  // where by_begin is an array of two-element arrays [start, end],
  // sorted by start position. The 't' data are not represented at
  // all.
  string ToCompactJSONRec(std::vector<string> *decls, 
			  const std::function<Idx(const Idx &l,
						  const Idx &r)> minus,
			  int depth,
			  const Node *n) const {
    if (n == nullptr) return "null";
    string ret = "[";
    ret += ToCompactJSONRec(decls, minus, depth + 1, n->left);
    ret += (string)"," + idxjs(n->center) + ",[";

    bool first = true;
    for (const auto &p : n->by_begin) {
      if (!first) ret += ",";
      Idx len = minus(p.second->end, p.second->start);
      ret += (string)"[" + idxjs(p.second->start) +
	"," + idxjs(len) + "]";
      first = false;
    }
    ret += "],";

    ret += ToCompactJSONRec(decls, minus, depth + 1, n->right);
    ret += "]";

    if ((depth % max_depth) == (max_depth - 1)) {
      // PERF could use base 26 (etc.) but watch out for clashes
      // with keywords, builtins, etc.
      string var = (string)"o" + std::to_string(decls->size());
      decls->push_back((string)"var " + var + "=" + ret + ";\n");
      return var;
    } else {
      return ret;
    }
  }
  
 private:
  const IT &tree;
  const std::function<string(const Idx &idx)> idxjs;
  const std::function<string(const T &t)> tjs;
  const int max_depth;  

  IntervalTreeJSON() = delete;
  IntervalTreeJSON(const IntervalTreeJSON &other) = delete;
};


#endif
