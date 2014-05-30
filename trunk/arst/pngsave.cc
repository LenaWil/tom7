/* 
   This file only:

   Gingerly plucked from the GPL "Tux Paint"
   Copyright (c) 2004 by Bill Kendrick
         and (c) 2004,2013 by Tom Murphy VII 


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

/* set this to 0 if mysterious crashes in
   libpng (VC version > 6.0) */
#define USE_SETJMP 0

typedef unsigned char uint8;

bool PngSave::SaveAlpha(const std::string &filename,
                        int width, int height,
                        const unsigned char *rgba) {
  FILE *fi = fopen(filename.c_str(), "wb");
  if (!fi) return false;


  png_text text_ptr[4];

  png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, 
						NULL, NULL, NULL);
  if (png_ptr == NULL) {
    png_destroy_write_struct(&png_ptr, (png_infopp) NULL);
    fclose(fi);
    return false;
  }

  png_infop info_ptr = png_create_info_struct(png_ptr);
  if (info_ptr == NULL) {
    png_destroy_write_struct(&png_ptr, (png_infopp) NULL);
    fclose(fi);
    return false;
  }

  #if USE_SETJMP
  if (setjmp(png_jmpbuf(png_ptr))) {
    png_destroy_write_struct(&png_ptr, (png_infopp) NULL);
    fclose(fi);
    return false;
  }
  #endif

  png_init_io(png_ptr, fi);

  png_set_filter(png_ptr, 0, PNG_ALL_FILTERS);
  // png_set_compression_level(png_ptr, Z_BEST_COMPRESSION);

  png_set_IHDR(png_ptr, info_ptr, 
	       /* dimensions */
	       width, height,
	       /* bit depth */
	       8,
	       /* color type */
	       PNG_COLOR_TYPE_RGB_ALPHA,
	       /* interlace type */
	       PNG_INTERLACE_NONE,
	       /* compression type - no options */
	       PNG_COMPRESSION_TYPE_DEFAULT,
	       /* filter method */
	       PNG_FILTER_TYPE_DEFAULT);
	       
  png_set_sRGB_gAMA_and_cHRM(png_ptr, info_ptr,
			     PNG_sRGB_INTENT_PERCEPTUAL);

  /* Set headers */

  int hdrcount = 0;

  text_ptr[hdrcount].key = (png_charp) "Software";
  text_ptr[hdrcount].text = (png_charp) "pngsave.cc";
  text_ptr[hdrcount].compression = PNG_TEXT_COMPRESSION_NONE;
  hdrcount++;


  png_set_text(png_ptr, info_ptr, text_ptr, hdrcount);

  png_write_info(png_ptr, info_ptr);



  /* Save the picture: */
  static int bpp = 4;

  uint8 **png_rows =
    (uint8 **)malloc(sizeof(uint8 *) * height);

  for (int y = 0; y < height; y++) {
    png_rows[y] = (uint8 *)malloc(sizeof(uint8) * bpp * width);

    for (int x = 0; x < width; x++) {
      png_rows[y][x * bpp + 0] = rgba[y * width * bpp + x * bpp + 0];
      png_rows[y][x * bpp + 1] = rgba[y * width * bpp + x * bpp + 1];
      png_rows[y][x * bpp + 2] = rgba[y * width * bpp + x * bpp + 2];
      png_rows[y][x * bpp + 3] = rgba[y * width * bpp + x * bpp + 3];
    }
  }

  png_write_image(png_ptr, png_rows);

  for (int y = 0; y < height; y++)
    free(png_rows[y]);

  free(png_rows);


  png_write_end(png_ptr, NULL);

  png_destroy_write_struct(&png_ptr, &info_ptr);
  fclose(fi);

  return true;
}
