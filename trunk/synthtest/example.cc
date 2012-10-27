// Courtesy Tuomas Tonteri,
// http://sci.tuomastonteri.fi/programming/cplus
// "All code in this tree is public domain."

#define OPENGL 1

#include "display.h"
#include "SDL.h"

int main(int argc, char **argv)
{
  // X,Y,visible,PBO,OpenGL
  Display* d = new Display(640,480,true,false,true);

  // Main loop

  float* framebuffer = (float*)d->Lock(); // Note this framebuffer MUST only be written into when using PBO

  // Put a red dot at left top corner
  framebuffer[0]=1.0f;
  framebuffer[1]=0.0f;
  framebuffer[2]=0.0f;
  framebuffer[3]=1.0f; // Alpha channel

  d->UnLock();

  d->Update_Display(1.0f); // Give the maximun pixel brightness in framebuffer so things can be scaled to 0..1

  // Main loop end

  SDL_Delay(10000);

  delete d;
  return 0;
}

/*
A GPU vertex shader:

void main(void)
{
  gl_Position = ftransform();
  gl_TexCoord[0] = gl_MultiTexCoord0;
}
*/

#if 0
And pixel shader:

uniform sampler2D tex;
uniform float maxlum;
uniform float texsize; // half of texture size

void main(void)
{
  vec4 color = texture2D(tex,gl_TexCoord[0].st);

#define EXPOSURE -10.0
  // From RGB HDR to RGB 0..1
  for (int i=0;i<3;i++)
    color[i] = color[3] * ( color[i]/maxlum );
  //color[i] = color[3] * ( 1.0 - exp2( EXPOSURE * color[i] / maxlum ) ); // tone mapping

  // Dithering
  bool evenx = fract(gl_TexCoord[0].s * texsize) < 0.5;
  bool eveny = fract(gl_TexCoord[0].t * texsize) < 0.5;

#define MUL 1.0 / (2.0*255.0*5.0)
  if (evenx && eveny)
    for (int i=0;i<3;i++)
      color[i]-=MUL;
  else if (evenx && !eveny)
    for (int i=0;i<3;i++)
      color[i]-=4.0*MUL;
  else if (!evenx && eveny)
    for (int i=0;i<3;i++)
      color[i]-=3.0*MUL;
  else
    for (int i=0;i<3;i++)
      color[i]-=2.0*MUL;

#define EXP 1.0 / 2.4
#define a 0.055
#define b (1.0 + a)

  // From linear RGB to sRGB
  for (int i=0;i<3;i++)
    {
      if (color[i] < 0.0031308)
	color[i] = 12.92 * color[i];
      else
	color[i] = b * pow ( color[i] , EXP ) - a;
    }

  gl_FragColor = color;
}
#endif
