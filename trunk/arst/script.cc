#include "script.h"
#include "arst.h"

Script *Script::Load(const string &filename) {
  return FromString(Util::ReadFile(filename));
}

Script *Script::FromString(const string &contents) {
  vector<string> lines = Util::SplitToLines(contents);
  Script *s = new Script;

  int lastframe = -1;
  for (int i = 0; i < lines.size(); i++) {
    string line = lines[i];
    int frame = atoi(Util::chop(line).c_str());
    Util::losewhitel(line);
    CHECK(frame > lastframe);
    s->lines.push_back(Line(frame, line));
    lastframe = frame;
  }

  return s;
}

Script *Script::Empty() {
  // Easy, just one big unknown chunk.
  Script *s = new Script;
  s->lines.push_back(Line(0, "*"));
  return s;
}

void Script::Save(const string &filename) {
  string contents;
  for (int i = 0; i < lines.size(); i++) {
    contents += StringPrintf("%d %s\n",
			     lines[i].frame,
			     lines[i].s.c_str());
  }
  Util::WriteFile(filename, contents);
}

void Script::DebugPrint() {
  for (int i = 0; i < lines.size(); i++) {
    printf("[%d] %d %s\n",
	   i,
	   lines[i].frame,
	   lines[i].s.c_str());
  }
}
