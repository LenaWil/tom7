
#include "test-util.h"
#include <cstdlib>

inline string ReadFile(const string &s) {
  if (s == "") return "";

  FILE * f = fopen(s.c_str(), "rb");
  if (!f) return "";
  fseek(f, 0, SEEK_END);
  int size = ftell(f);
  fseek(f, 0, SEEK_SET);

  char * ss = (char*)malloc(size);
  fread(ss, 1, size, f);

  fclose(f);

  string ret = string(ss, size);
  free(ss);

  return ret;
}

vector<string> ReadFileToLines(const string &f) {
  return SplitToLines(ReadFile(f));
}

vector<string> SplitToLines(const string &s) {
  vector<string> v;
  string line;
  // PERF don't need to do so much copying.
  for (size_t i = 0; i < s.size(); i++) {
    if (s[i] == '\r')
      continue;
    else if (s[i] == '\n') {
      v.push_back(line);
      line.clear();
    } else {
      line += s[i];
    }
  }
  return v;
}

string Chop(string &line) {
  for (int i = 0; i < line.length(); i ++) {
    if (line[i] != ' ') {
      string acc;
      for(int j = i; j < line.length(); j ++) {
	if (line[j] == ' ') {
	  line = line.substr(j, line.length() - j);
	  return acc;
	} else acc += line[j];
      }
      line = "";
      return acc;
    }
  }
  /* all whitespace */
  line = "";
  return "";
}

string LoseWhiteL(const string &s) {
  for (unsigned int i = 0; i < s.length(); i ++) {
    switch(s[i]) {
    case ' ':
    case '\n':
    case '\r':
    case '\t':
      /* keep going ... */
      break;
    default:
      return s.substr(i, s.length() - i);
    }
  }
  /* all whitespace */
  return "";
}
