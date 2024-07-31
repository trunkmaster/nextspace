/* save.c - save image to file
 *
 * Raster graphics library
 *
 * Copyright (c) 1998-2003 Alfredo K. Kojima
 * Copyright (c) 2013-2023 Window Maker Team
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

#include "config.h"

#include <X11/Xlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string.h>

#include "wraster.h"
#include "imgformat.h"

Bool RSaveImage(RImage *image, const char *filename, const char *format)
{
  return RSaveTitledImage(image, filename, format, NULL);
}

Bool RSaveTitledImage(RImage *image, const char *filename, const char *format, char *title)
{
  if (strcmp(format, "XPM") != 0) {
    RErrorCode = RERR_BADFORMAT;
    return False;
  }
  return RSaveXPM(image, filename);
#ifdef USE_PNG
  if (strcasecmp(format, "PNG") == 0)
    return RSavePNG(image, filename, title);
#endif
#ifdef USE_JPEG
  if (strcasecmp(format, "JPG") == 0)
    return RSaveJPEG(image, filename, title);

  if (strcasecmp(format, "JPEG") == 0)
    return RSaveJPEG(image, filename, title);
#endif
  if (strcasecmp(format, "XPM") == 0)
    return RSaveXPM(image, filename);

  RErrorCode = RERR_BADFORMAT;
  return False;
}