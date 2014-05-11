
#ifndef __SCRIPT_H
#define __SCRIPT_H

#include <string>
#include <vector>
using namespace std;

// Tells us what words are where. Based on frames in the movie. Data
// structure is a series of non-overlapping partitions, which always
// cover the entire movie. A partition can either contain a string
// (meaning some word spoken in that range) or the empty string
// (assertion that there are no words in that range) or "*" meaning
// that it's unknown. The last chunk is assumed to cover the range
// out until infinity.
struct DLL;
struct Script {
  DLL *parts;

  static Script *Load(const string &filename);
  static Script *FromString(const string &contents);
  // Whole movie is "*".
  static Script *Empty();

  void Save(const string &filename);

  void DebugPrint();

 private:
  Script() : parts(NULL) {}
};

// Doubly-linked list.
struct DLL {
  DLL(int frame,
      const string &s,
      DLL *prev,
      DLL *next) : s(s), prev(prev), next(next) {}
  int frame;
  string s;
  DLL *prev, *next;

  static DLL *Insert(int frame, const string &s, DLL **after);
};


#endif
