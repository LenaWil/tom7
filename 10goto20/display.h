// Courtesy Tuomas Tonteri,
// http://sci.tuomastonteri.fi/programming/cplus
// "All code in this tree is public domain."

#ifndef _DISPLAY_H
#define _DISPLAY_H

#include "SDL.h"
#include <cmath>

#ifdef OPENGL
#include <GL/glew.h>
#endif

/** Display */
class Display
{
 private:
  SDL_Surface *screen;

  int X; ///< X-size
  int Y; ///< Y-size

#ifdef OPENGL
  GLuint texture;
  GLuint displaylist;
  GLuint pbo;
#endif

  bool opengl; // Whether to use OpenGL or fall back to SDL software surface
  bool on; // Whether to create visible framebuffer or not
  bool usepbo; // Use pixel buffer objects

  float* framebuffer;

 public:

#ifdef OPENGL
  GLuint sp,vs,fs;
#endif

  ~Display()
    {
      SDL_FreeSurface(screen);
      delete [] framebuffer;

      if (on && opengl)
        {
#ifdef OPENGL
          glDeleteTextures(1, &texture);
          if (usepbo)
            glDeleteBuffers(1, &pbo);
#endif
        }
    }

  /** Set window caption */
  void set_caption(const char* caption)
  {
    SDL_WM_SetCaption(caption,caption);
  }

 private:

#ifdef OPENGL

  static int int_log2 (int val) {
    int log = 0;
    while ((val >>= 1) != 0)
      log++;
    return log;
  }

  void printLog(GLuint obj)
  {
    int infologLength = 0;
    char infoLog[1024];

    if (glIsShader(obj))
      glGetShaderInfoLog(obj, 1024, &infologLength, infoLog);
    else
      glGetProgramInfoLog(obj, 1024, &infologLength, infoLog);

    if (infologLength > 0)
      printf("%s\n", infoLog);
  }

  char *file2string(const char *path)
  {
    FILE *fd;
    long len,
      r;
    char *str;

    if (!(fd = fopen(path, "r")))
      {
        fprintf(stderr, "Can't open file '%s' for reading\n", path);
        return NULL;
      }

    fseek(fd, 0, SEEK_END);
    len = ftell(fd);

    printf("File '%s' is %ld long\n", path, len);

    fseek(fd, 0, SEEK_SET);

    if (!(str = (char*)malloc(len * sizeof(char))))
      {
        fprintf(stderr, "Can't malloc space for '%s'\n", path);
        return NULL;
      }

    r = fread(str, sizeof(char), len, fd);

    str[r - 1] = '\0'; /* Shader sources have to term with null */

    fclose(fd);

    return str;
  }

#endif

 public:

  void Initialize_SDL()
  {
    if ( SDL_Init(SDL_INIT_VIDEO) < 0 )
      {
        fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
        exit(1);
      }

    atexit(SDL_Quit);

    const SDL_VideoInfo* info;
    info = SDL_GetVideoInfo();

    Uint32 rmask, gmask, bmask, amask;

#if SDL_BYTEORDER == SDL_BIG_ENDIAN
    rmask = 0xff000000;
    gmask = 0x00ff0000;
    bmask = 0x0000ff00;
    amask = 0x000000ff;
#else
    rmask = 0x000000ff;
    gmask = 0x0000ff00;
    bmask = 0x00ff0000;
    amask = 0xff000000;
#endif

    if (on)
      screen = SDL_SetVideoMode(X, Y, info->vfmt->BitsPerPixel, NULL);
    else
      screen = SDL_CreateRGBSurface(SDL_SWSURFACE, X, Y, 32, rmask, gmask, bmask, amask);
  }

  Display(int X, int Y, bool on, bool pbo, bool opengl)
    {
      Display::usepbo = pbo;
      Display::opengl = opengl;
      Display::X=X;
      Display::Y=Y;
      Display::on=on;

      framebuffer = new float[4*X*Y];

      if (opengl && on)
        {
          bool opengl_success;
          opengl_success = Initialize_GL();
          if (!opengl_success) // Fall back to software
            {
              Display::opengl=false;
              Initialize_SDL();
            }
        }
      else
        Initialize_SDL();
    }

  bool Initialize_GL()
  {
#ifdef OPENGL
    if ( SDL_Init(SDL_INIT_VIDEO) < 0 )
      {
        fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
        exit(1);
      }


    Uint32 oglflags = SDL_OPENGL;
    const SDL_VideoInfo *info;
    info = SDL_GetVideoInfo();

    SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );

    screen = SDL_SetVideoMode(X, Y, info->vfmt->BitsPerPixel, oglflags);
    if ( screen == NULL )
      {
        fprintf(stderr, "Unable to set video-mode: %s\n",
                SDL_GetError());
        exit(1);
      }

    glClearColor (0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glFlush();

    printf("Initializing glew\n");
    glewInit();

    if (GLEW_VERSION_2_0)
      fprintf(stderr, "INFO: OpenGL 2.0 supported, proceeding\n");
    else
      {
        fprintf(stderr, "INFO: OpenGL 2.0 not supported. Reverting to software display.\n");
        SDL_Quit();
        return false;
      }

    const GLchar *vsSource = file2string("gammacorrection.vert");
    const GLchar *fsSource = file2string("gammacorrection.frag");

    vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &vsSource, NULL);
    glCompileShader(vs);
    printLog(vs);

    fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &fsSource, NULL);
    glCompileShader(fs);
    printLog(fs);

    delete vsSource;
    delete fsSource;

    sp = glCreateProgram();
    glAttachShader(sp, vs);
    glAttachShader(sp, fs);
    glLinkProgram(sp);
    printLog(sp);

    glUseProgram(sp);

    glViewport(0,0,X,Y);
    glMatrixMode (GL_PROJECTION);
    glDeleteTextures(1,&texture);
    glGenTextures(1,&texture);
    glBindTexture(GL_TEXTURE_2D,texture);
    // No borders
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    // No bilinear filtering of texture
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

    // To get 2^n texture
    int texsize=2 << int_log2((X-1) > (Y-1) ? (X-1) : (Y-1));
    //std::cout << "OpenGL texture size: " << texsize << std::endl;

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, texsize, texsize, 0, GL_RGBA, GL_FLOAT, NULL);

    glShadeModel (GL_FLAT);
    glDisable (GL_DEPTH_TEST);
    glDisable (GL_LIGHTING);
    glDisable(GL_CULL_FACE);
    glEnable(GL_TEXTURE_2D);
    glMatrixMode (GL_MODELVIEW);
    glLoadIdentity ();

    if (glIsList(displaylist))
      glDeleteLists(displaylist, 1);

    float tex_width  = float(X) / float(texsize);
    float tex_height = float(Y) / float(texsize);

    displaylist = glGenLists(1);

    glNewList(displaylist, GL_COMPILE);
    glBegin(GL_QUADS);
    // lower left
    glTexCoord2f(0,tex_height); glVertex2f(-1.0f,-1.0f);
    // lower right
    glTexCoord2f(tex_width,tex_height); glVertex2f(1.0f, -1.0f);
    // upper right
    glTexCoord2f(tex_width,0); glVertex2f(1.0f, 1.0f);
    // upper left
    glTexCoord2f(0,0); glVertex2f(-1.0f, 1.0f);
    glEnd();
    glEndList();

    if (usepbo)
      {
        glGenBuffers(1, &pbo);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo);
      }

    GLint loc = glGetUniformLocation(sp, "texsize");
    glUniform1f(loc, float(texsize)/2.0f);
#endif
    return true;
  }

  /** Upload PBO to GPU texture and draw the texture to framebuffer as quad */
  void Update_Display(float maxlum)
  {
    if (opengl && on)
      {
#ifdef OPENGL
        GLint loc = glGetUniformLocation(sp, "maxlum");
        glUniform1f(loc, maxlum);

        if (usepbo)
          glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, screen->w, screen->h, GL_RGBA, GL_FLOAT, 0);
        else
          glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, screen->w, screen->h, GL_RGBA, GL_FLOAT, framebuffer);

        GLenum error;
        error = glGetError();
        if (error != GL_NO_ERROR)
          fprintf(stderr, (char*)gluErrorString(error));

        glCallList(displaylist);
        SDL_GL_SwapBuffers();

#endif
      }
    else // Software fallback, only 32-bit display mode support implemented
      {
        Uint8 *buffer = (Uint8*)screen->pixels;

        switch (screen->format->BytesPerPixel)
          {
          case 4:

#pragma omp parallel for schedule(static,1)
            for (int i=0;i<X*Y;i++)
              {
                int start = 4*i;

                if (framebuffer[start+3] == 0.0f)
                  for (int j=0;j<3;j++)
                    buffer[start+j]=0;
                else
                  // Gamma 2.2 correction
                  for (int j=0;j<3;j++)
                    buffer[start+j] = 255.0f * pow(framebuffer[start+j]/maxlum,1.0f/2.2f);
              }

            break;
          default:
            fprintf(stderr, "Only 32-bit display mode supported.\n");
            exit(0);
          }

        SDL_Flip(screen);
      }
  }

  /** Lock PBO for access */
#ifdef OPENGL
  GLvoid* Lock()
#else
    void* Lock()
#endif
    {
#ifdef OPENGL
      if (on && opengl && usepbo)
        {
          glBufferData(GL_PIXEL_UNPACK_BUFFER,4*screen->w*screen->h*sizeof(float),NULL, GL_DYNAMIC_DRAW);
          return glMapBuffer(GL_PIXEL_UNPACK_BUFFER, GL_WRITE_ONLY);
        }
      else
        return framebuffer;
#else
      return framebuffer;
#endif
    }

  /** Unlock PBO */
  void UnLock()
  {
#ifdef OPENGL
    if (on && opengl && usepbo)
      glUnmapBuffer(GL_PIXEL_UNPACK_BUFFER);
#endif
  }

};
#endif
