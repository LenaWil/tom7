#include <string>

/* how often to show progress (default) */
#define PROGRESS_TICKS 100

/* XXX these color constants depend on byte order, right? */
#define PROGRESS_DONECOLOR 0xFF99CCAA
#define PROGRESS_RESTCOLOR 0xFF555555
#define PROGRESS_BACKCOLOR 0xFF000000

struct progress {
  /* 
     drawbar(epoch, int n, int tot, msg, ticks);

     draws a progress bar.
     this just overwrites what's on the screen.
     tot is the total number of items.
     n is the current item.
     msg is displayed along with the bar.
       (might be several lines, separated by \n)
     the bar is drawn every 'ticks' ticks.
     epoch is a pointer to the tick at which the bar should
     be drawn next. (It is automatically updated by calling,
     but should be initialized to an appropriate future tick.)
   */
  static void drawbar(void *, int n, int tot, const string &,
		      const int ticks = PROGRESS_TICKS);
};
