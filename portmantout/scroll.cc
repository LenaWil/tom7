// Scroll a text file (the portmantout) 

#include <vector>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <deque>

#include "util.h"
#include "timer.h"
#include "threadutil.h"
#include "arcfour.h"
#include "randutil.h"
#include "base/logging.h"
#include "textsvg.h"
#include "base/stringprintf.h"
#include "image.h"

using namespace std;

#define FONTWIDTH 9
#define FONTOLAP 1
#define FONTHEIGHT 16

#define NUMFRAMES (45 * 30)

#define SCREENWIDTH 1920
#define SCREENHEIGHT 1080

std::mutex print_mutex;
#define Printf(fmt, ...) do {		\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);

#define CHECKMARK "\xF2"
#define ESC "\xF3"
#define HEART "`"
// "\xF4"

#define FONTCHARS " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789--=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" CHECKMARK ESC HEART


int main() {
  string port = Util::ReadFile("portmantout.txt");
  
  ImageRGBA *font = ImageRGBA::Load("font.png");

  static constexpr int CHARSWIDE = 240;
  const double gridheight = port.size() / (double)CHARSWIDE;
  const double maxscroll = gridheight * (FONTHEIGHT - 2) + SCREENHEIGHT;

  for (int i = 0; i < 18; i++) {
    port +=
      "                                                                 "
      "                                                                 "
      "                                                                 "
      "                                             ";
  }

  port +=
    "                                                                 "
    "                                                                 "
    "   " HEART "                              ";

  port +=
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                                                                                                                                                                                                                "
"                                                          +-----------------------------------------------------------+                                                                                                                         "
"                                                          |                                                           |                                                                                                                         "
"                                                          |     http://tom7.org/portmantout/              @tom7       |                                                                                                                         "
"                                                          |     ^                                         ^           |                                                                                                                         "
"                                                          |    interweb                                twitterverse   |                                                                                                                         "
"                                                          |                                                           |                                                                                                                         "
"                                                          +-----------------------------------------------------------+                                                                                                                         ";

  // Init font.
  
  string chars = FONTCHARS;
  
  int fontx[255] = {0};
  for (unsigned int i = 0; i < chars.size(); i++) {
    int idx = (uint8)chars[i];
    fontx[idx] = i * FONTWIDTH;
  }

  vector<int> colors;
  colors.reserve(port.size());
  ArcFour rc("scroll");
  for (int i = 0; i < port.size(); i++) {
    colors.push_back(RandTo(&rc, 6));
  }

  ParallelComp(NUMFRAMES,
	       [font, &fontx, &port, &colors, maxscroll](int f) {

      ImageRGBA *frame = new ImageRGBA(SCREENWIDTH, SCREENHEIGHT);
      for (int i = 0; i < SCREENWIDTH * SCREENHEIGHT; i++) {
	frame->rgba[i * 4 + 0] = 40;
	frame->rgba[i * 4 + 1] = 0;
	frame->rgba[i * 4 + 2] = 20;
	frame->rgba[i * 4 + 3] = 255;
      }

      // In pixels.
      int scrollpos = int((f / (double)NUMFRAMES) * maxscroll);

      // Just draw the whole thing, it's simpler.
      int portheight = port.size() / CHARSWIDE + 1;
      for (int y = 0; y < portheight; y++) {
	// screen space
	int sy = (y * (FONTHEIGHT - 2)) - scrollpos;
	// Quick skips.
	if (sy < -FONTHEIGHT) continue;
	if (sy > SCREENHEIGHT) continue;

	// Draw the whole line...
	for (int x = 0; x < CHARSWIDE; x++) {
	  int idx = y * CHARSWIDE + x;
	  if (idx >= 0 && idx < port.size()) {
	    int ch = port[idx];
	    int color = colors[idx];
	    frame->Blit(*font, fontx[ch], FONTHEIGHT * color,
			FONTWIDTH, FONTHEIGHT,
			x * (FONTWIDTH - 1),
			sy);
	  }
	}
      }

      frame->Save(StringPrintf("scroll-%d.png", f));
      if (f % 10 == 0) {
	Printf("Wrote %d.\n", f);
      }

      delete frame;
    }, 24);
}
