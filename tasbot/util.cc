#include "util.h"

string SVGTickmarks(double width, double maxx, double span,
		    double tickheight, double tickfont) {
  string out;
  bool longone = true;
  for (double x = 0.0; x < maxx; x += span) {
    double xf = x / maxx;
    out += 
      StringPrintf("  <polyline fill=\"none\" opacity=\"0.5\""
		   " stroke=\"#000000\""
		   " stroke-width=\"1\" points=\"%f,0 %f,%f\" />\n",
		   width * xf, width * xf, 
		   longone ? tickheight * 2 : tickheight);
    if (longone)
      out += StringPrintf("<text x=\"%f\" y=\"%f\" font-size=\"%f\">"
			  "<tspan fill=\"#000000\">%d</tspan>"
			  "</text>\n",
			  width * xf + 3.0, 2.0 * tickheight + 2.0,
			  tickfont, (int)x);

    longone = !longone;
  }
  return out;
}
