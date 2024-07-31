/* save_jpeg.c - save JPEG image
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
#include <jpeglib.h>

#include "wraster.h"
#include "imgformat.h"

/*
 *  Save RImage to JPEG image
 */

Bool RSaveJPEG(RImage *img, const char *filename, char *title)
{
  FILE *file;
  int x, y, img_depth;
  char *buffer;
  RColor pixel;
  struct jpeg_compress_struct cinfo;
  struct jpeg_error_mgr jerr;
  JSAMPROW row_pointer;

  file = fopen(filename, "wb");
  if (!file) {
    RErrorCode = RERR_OPEN;
    return False;
  }

  if (img->format == RRGBAFormat)
    img_depth = 4;
  else
    img_depth = 3;

  /* collect separate RGB values to a buffer */
  buffer = malloc(sizeof(char) * 3 * img->width * img->height);
  for (y = 0; y < img->height; y++) {
    for (x = 0; x < img->width; x++) {
      RGetPixel(img, x, y, &pixel);
      buffer[y * img->width * 3 + x * 3 + 0] = (char)(pixel.red);
      buffer[y * img->width * 3 + x * 3 + 1] = (char)(pixel.green);
      buffer[y * img->width * 3 + x * 3 + 2] = (char)(pixel.blue);
    }
  }

  /* Setup Exception handling */
  cinfo.err = jpeg_std_error(&jerr);

  /* Initialize cinfo structure */
  jpeg_create_compress(&cinfo);
  jpeg_stdio_dest(&cinfo, file);

  cinfo.image_width = img->width;
  cinfo.image_height = img->height;
  cinfo.input_components = 3;
  cinfo.in_color_space = JCS_RGB;

  jpeg_set_defaults(&cinfo);
  jpeg_set_quality(&cinfo, 85, TRUE);
  jpeg_start_compress(&cinfo, TRUE);

  /* Set title if any */
  if (title)
    jpeg_write_marker(&cinfo, JPEG_COM, (const JOCTET *)title, strlen(title));

  while (cinfo.next_scanline < cinfo.image_height) {
    row_pointer = (JSAMPROW)&buffer[cinfo.next_scanline * img_depth * img->width];
    jpeg_write_scanlines(&cinfo, &row_pointer, 1);
  }

  jpeg_finish_compress(&cinfo);

  /* Clean */
  free(buffer);
  fclose(file);

  return True;
}