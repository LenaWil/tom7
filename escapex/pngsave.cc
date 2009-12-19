/* 
   This file only:

   Gingerly plucked from the GPL "Tux Paint"
   Copyright (c) 2004 by Bill Kendrick
         and (c) 2004 by Tom Murphy VII 


  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA	 
   
*/

#include <stdlib.h>
#include <stdio.h>
#include <png.h>
#include "pngsave.h"
#include "sdlutil.h"

/* set this to 0 if mysterious crashes in
   libpng (VC version > 6.0) */
#define USE_JMPBUF 0

int pngsave::save(const string & fname, 
		  SDL_Surface * surf,
		  bool alpha) {

  png_structp png_ptr;
  png_infop info_ptr;
  png_text text_ptr[4];
  unsigned char ** png_rows;
  Uint8 r, g, b, a;
  int x, y, count;
  int bpp = alpha?4:3;
  
  FILE * fi = fopen(fname.c_str(), "wb");
  if (!fi) return 0;

  
  png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (png_ptr == NULL) {
    fclose(fi);
    png_destroy_write_struct(&png_ptr, (png_infopp) NULL);

    fprintf(stderr, "\nError: Couldn't save the image!\n%s\n\n", 
	    fname.c_str());

    return 0;
  } else {
    info_ptr = png_create_info_struct(png_ptr);
    if (info_ptr == NULL) {
      fclose(fi);
      png_destroy_write_struct(&png_ptr, (png_infopp) NULL);

      fprintf(stderr, "\nError: Couldn't save the image!\n%s\n\n", 
	      fname.c_str());

      return 0;
    } else {
      if (USE_JMPBUF && setjmp(png_jmpbuf(png_ptr))) {
	fclose(fi);
	png_destroy_write_struct(&png_ptr, (png_infopp) NULL);

	fprintf(stderr, "\nError: Couldn't save the image!\n%s\n\n", 
		fname.c_str());
  
	return 0;
      } else {
	png_init_io(png_ptr, fi);

	info_ptr->width = surf->w;
	info_ptr->height = surf->h;
	info_ptr->bit_depth = 8;
	info_ptr->color_type = 
	  alpha?PNG_COLOR_TYPE_RGB_ALPHA:PNG_COLOR_TYPE_RGB;
	info_ptr->interlace_type = 1;
	info_ptr->valid = 0;

	/* Set headers */

	count = 0;

	text_ptr[count].key = "Software";
	/* XXX make arguments? */
	text_ptr[count].text = "pngsave.cc";
	text_ptr[count].compression = PNG_TEXT_COMPRESSION_NONE;
	count++;

	      
	png_set_text(png_ptr, info_ptr, text_ptr, count);
			      
	png_write_info(png_ptr, info_ptr);



	/* Save the picture: */

	png_rows = (unsigned char**) malloc(sizeof(char *) * surf->h);

	for (y = 0; y < surf->h; y++) {
	  png_rows[y] = (unsigned char *)malloc(sizeof(char) * bpp * surf->w);

	  /* locking here because malloc may make system calls  --tom */
	  sdlutil::slock(surf);

	  for (x = 0; x < surf->w; x++) {
	    SDL_GetRGBA(sdlutil::getpixel(surf, x, y), 
			surf->format, &r, &g, &b, &a);

	    png_rows[y][x * bpp + 0] = r;
	    png_rows[y][x * bpp + 1] = g;
	    png_rows[y][x * bpp + 2] = b;
	    if (alpha) png_rows[y][x * bpp + 3] = a;
	  }

	  sdlutil::sulock(surf);
	}
        
	png_write_image(png_ptr, png_rows);

	for (y = 0; y < surf->h; y++)
	  free(png_rows[y]);

	free(png_rows);

	png_write_end(png_ptr, NULL);

	png_destroy_write_struct(&png_ptr, &info_ptr);
	fclose(fi);

	return 1;
      }
    }
  }
}
