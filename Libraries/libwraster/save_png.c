/* save_png.c - save PNG image
 *
 * Raster graphics library
 *
 * Copyright (c) 2023 Window Maker Team
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#include <config.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <png.h>

#include "wraster.h"
#include "imgformat.h"

/*
 * Save RImage to PNG image
 */
Bool RSavePNG(RImage *img, const char *filename, char *title)
{
  FILE *file;
  png_structp png_ptr;
  png_infop png_info_ptr;
  png_bytep png_row;
  RColor pixel;
  int x, y;
  int width = img->width;
  int height = img->height;

  file = fopen(filename, "wb");
  if (file == NULL) {
    RErrorCode = RERR_OPEN;
    return False;
  }

  /* Initialize write structure */
  png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (png_ptr == NULL) {
    fclose(file);
    RErrorCode = RERR_NOMEMORY;
    return False;
  }

  /* Initialize info structure */
  png_info_ptr = png_create_info_struct(png_ptr);
  if (png_info_ptr == NULL) {
    fclose(file);
    RErrorCode = RERR_NOMEMORY;
    return False;
  }

  /* Setup Exception handling */
  if (setjmp(png_jmpbuf(png_ptr))) {
    fclose(file);
    RErrorCode = RERR_INTERNAL;
    return False;
  }

  png_init_io(png_ptr, file);

  /* Write header (8 bit colour depth) */
  png_set_IHDR(png_ptr, png_info_ptr, width, height, 8, PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
               PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);

  /* Set title if any */
  if (title) {
    png_text title_text;
    title_text.compression = PNG_TEXT_COMPRESSION_NONE;
    title_text.key = "Title";
    title_text.text = title;
    png_set_text(png_ptr, png_info_ptr, &title_text, 1);
  }

  png_write_info(png_ptr, png_info_ptr);

  /* Allocate memory for one row (3 bytes per pixel - RGB) */
  png_row = (png_bytep)malloc(3 * width * sizeof(png_byte));

  /* Write image data */
  for (y = 0; y < height; y++) {
    for (x = 0; x < width; x++) {
      png_byte *ptr;

      RGetPixel(img, x, y, &pixel);
      ptr = &(png_row[x * 3]);
      ptr[0] = pixel.red;
      ptr[1] = pixel.green;
      ptr[2] = pixel.blue;
    }
    png_write_row(png_ptr, png_row);
  }

  /* End write */
  png_write_end(png_ptr, NULL);

  /* Clean */
  fclose(file);
  if (png_info_ptr != NULL)
    png_free_data(png_ptr, png_info_ptr, PNG_FREE_ALL, -1);
  if (png_ptr != NULL)
    png_destroy_write_struct(&png_ptr, (png_infopp)NULL);
  if (png_row != NULL)
    free(png_row);

  return True;
}