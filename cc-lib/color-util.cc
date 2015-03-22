
#include "color-util.h"

// static
void ColorUtil::HSVToRGB(float h, float s, float v,
			 float *r, float *g, float *b) {
  if (s == 0.0f) {
    *r = v;
    *g = v;
    *b = v;
  } else {
    float hue = h * 6.0f;
    int fh = (int)hue;
    float var_1 = v * (1 - s);
    float var_2 = v * (1 - s * (hue - fh));
    float var_3 = v * (1 - s * (1 - (hue - fh)));

    float red, green, blue;

    switch (fh) {
    case 0:  red = v;      green = var_3;  blue = var_1; break;
    case 1:  red = var_2;  green = v;      blue = var_1; break;
    case 2:  red = var_1;  green = v;      blue = var_3; break;
    case 3:  red = var_1;  green = var_2;  blue = v;     break;
    case 4:  red = var_3;  green = var_1;  blue = v;     break;
    default: red = v;      green = var_1;  blue = var_2; break;
    }

    *r = red;
    *g = green;
    *b = blue;
  }
}
