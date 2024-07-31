/*
 * Raster graphics library
 *
 * Copyright (c) 1997-2003 Alfredo K. Kojima
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

#include <string.h>
#include <X11/Xlib.h>

#include "config.h"
#include "wraster.h"
#include "imgformat.h"
#include "convert.h"
#include "wr_i18n.h"

void RBevelImage(RImage *image, int bevel_type)
{
  RColor color;
  RColor cdelta;
  int w, h;

  if (image->width < 3 || image->height < 3)
    return;

  w = image->width;
  h = image->height;
  if (bevel_type > 0) { /* raised */
    /* top */
    cdelta.alpha = 0;
    cdelta.red = cdelta.green = cdelta.blue = 80;
    ROperateLine(image, RAddOperation, 0, 0, w - 1, 0, &cdelta);
    if (bevel_type == RBEV_RAISED3 && w > 3)
      ROperateLine(image, RAddOperation, 1, 1, w - 3, 1, &cdelta);

    /* left */
    ROperateLine(image, RAddOperation, 0, 1, 0, h - 1, &cdelta);
    if (bevel_type == RBEV_RAISED3 && h > 3)
      ROperateLine(image, RAddOperation, 1, 2, 1, h - 3, &cdelta);

    /* bottom */
    color.alpha = 255;
    color.red = color.green = color.blue = 0;
    cdelta.red = cdelta.green = cdelta.blue = 40;
    if (bevel_type == RBEV_RAISED2 || bevel_type == RBEV_RAISED3) {
      ROperateLine(image, RSubtractOperation, 0, h - 2, w - 3, h - 2, &cdelta);
      RDrawLine(image, 0, h - 1, w - 1, h - 1, &color);
    } else {
      ROperateLine(image, RSubtractOperation, 0, h - 1, w - 1, h - 1, &cdelta);
    }

    /* right */
    if (bevel_type == RBEV_RAISED2 || bevel_type == RBEV_RAISED3) {
      ROperateLine(image, RSubtractOperation, w - 2, 0, w - 2, h - 2, &cdelta);
      RDrawLine(image, w - 1, 0, w - 1, h - 2, &color);
    } else {
      ROperateLine(image, RSubtractOperation, w - 1, 0, w - 1, h - 2, &cdelta);
    }
  } else { /* sunken */
    cdelta.alpha = 0;
    cdelta.red = cdelta.green = cdelta.blue = 40;
    ROperateLine(image, RSubtractOperation, 0, 0, w - 1, 0, &cdelta); /* top */
    ROperateLine(image, RSubtractOperation, 0, 1, 0, h - 1, &cdelta); /* left */
    cdelta.red = cdelta.green = cdelta.blue = 80;
    ROperateLine(image, RAddOperation, 0, h - 1, w - 1, h - 1, &cdelta); /* bottom */
    ROperateLine(image, RAddOperation, w - 1, 0, w - 1, h - 2, &cdelta); /* right */
  }
}

void RFillImage(RImage *image, const RColor *color)
{
  unsigned char *d = image->data;
  unsigned lineSize;
  int i;

  if (image->format == RRGBAFormat) {
    for (i = 0; i < image->width; i++) {
      *d++ = color->red;
      *d++ = color->green;
      *d++ = color->blue;
      *d++ = color->alpha;
    }
    lineSize = image->width * 4;
    for (i = 1; i < image->height; i++, d += lineSize) {
      memcpy(d, image->data, lineSize);
    }
  } else {
    for (i = 0; i < image->width; i++) {
      *d++ = color->red;
      *d++ = color->green;
      *d++ = color->blue;
    }
    lineSize = image->width * 3;
    for (i = 1; i < image->height; i++, d += lineSize) {
      memcpy(d, image->data, lineSize);
    }
  }
}

void RClearImage(RImage *image, const RColor *color)
{
  unsigned char *d = image->data;
  unsigned lineSize;
  int i;

  if (color->alpha == 255) {
    if (image->format == RRGBAFormat) {
      for (i = 0; i < image->width; i++) {
        *d++ = color->red;
        *d++ = color->green;
        *d++ = color->blue;
        *d++ = 0xff;
      }
      lineSize = image->width * 4;
      for (i = 1; i < image->height; i++, d += lineSize) {
        memcpy(d, image->data, lineSize);
      }
    } else {
      for (i = 0; i < image->width; i++) {
        *d++ = color->red;
        *d++ = color->green;
        *d++ = color->blue;
      }
      lineSize = image->width * 3;
      for (i = 1; i < image->height; i++, d += lineSize) {
        memcpy(d, image->data, lineSize);
      }
    }
  } else {
    int bytes = image->width * image->height;
    int alpha, nalpha, r, g, b, s;

    alpha = color->alpha;
    r = color->red * alpha;
    g = color->green * alpha;
    b = color->blue * alpha;
    nalpha = 255 - alpha;

    s = (image->format == RRGBAFormat) ? 4 : 3;

    for (i = 0; i < bytes; i++, d += s) {
      d[0] = (((int)d[0] * nalpha) + r) / 256;
      d[1] = (((int)d[1] * nalpha) + g) / 256;
      d[2] = (((int)d[2] * nalpha) + b) / 256;
    }
  }
}

static inline unsigned char clip(int c)
{
  if (c > 255)
    c = 255;
  return (unsigned char)c;
}

void RLightImage(RImage *image, const RColor *color)
{
  unsigned char *d = image->data;
  unsigned char *dd;
  int alpha, r, g, b, s;

  s = (image->format == RRGBAFormat) ? 4 : 3;
  dd = d + s * image->width * image->height;

  r = color->red;
  g = color->green;
  b = color->blue;

  alpha = color->alpha;

  if (r == 0 && g == 0 && b == 0) {
    for (; d < dd; d += s) {
      d[0] = clip(((int)d[0] * alpha) / 128);
      d[1] = clip(((int)d[1] * alpha) / 128);
      d[2] = clip(((int)d[2] * alpha) / 128);
    }
  } else {
    for (; d < dd; d += s) {
      d[0] = clip((((int)d[0] * alpha) + r) / 128);
      d[1] = clip((((int)d[1] * alpha) + g) / 128);
      d[2] = clip((((int)d[2] * alpha) + b) / 128);
    }
  }
}

const char *RMessageForError(int errorCode)
{
  switch (errorCode) {
    case RERR_NONE:
      return _("no error");

    case RERR_OPEN:
      return _("could not open file");

    case RERR_READ:
      return _("error reading from file");

    case RERR_WRITE:
      return _("error writing to file");

    case RERR_NOMEMORY:
      return _("out of memory");

    case RERR_NOCOLOR:
      return _("out of color cells");

    case RERR_BADIMAGEFILE:
      return _("invalid or corrupted image file");

    case RERR_BADFORMAT:
      return _("image format is not supported");

    case RERR_BADINDEX:
      return _("file does not contain requested image index");

    case RERR_BADVISUALID:
      return _("request for an invalid Visual ID");

    case RERR_STDCMAPFAIL:
      return _("failed to create X standard colormap");

    case RERR_XERROR:
      return _("internal X error");

    default:
    case RERR_INTERNAL:
      return _("internal error");
  }
}

#ifdef I18N
/*
 * Setup internationalization on startup
 *
 * For historical reason, the WRaster library does not have a function that
 * user is supposed to call to initialise the library. Because we need to do
 * some stuff now, we rely on the compiler attribute to tell this function
 * has to be called automatically when library is loaded.
 */
void WLIB_CONSTRUCTOR(RStartup)(void)
{
  const char *locale_path;

  locale_path = getenv("NLSPATH");
  if (locale_path == NULL)
    locale_path = LOCALEDIR;

  bindtextdomain("WRaster", locale_path);
}
#endif

/*
 * cleaning third-party libs at shutdown
 */
void RShutdown(void)
{
#ifdef USE_MAGICK
  RReleaseMagick();
#endif
  RReleaseCache();
  r_destroy_conversion_tables();
}
