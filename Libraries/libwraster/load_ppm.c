/* ppm.c - load PPM image from file
 *
 * Raster graphics library
 *
 * Copyright (c) 1997-2003 Alfredo K. Kojima
 * Copyright (c) 2014-2021 Window Maker Team
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

#include <X11/Xlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>

#include "wraster.h"
#include "imgformat.h"
#include "wr_i18n.h"

/*
 * fileio.c - routines to read elements based on Netpbm
 *
 * Copyright (C) 1988 by Jef Poskanzer.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation.  This software is provided "as is" without express or
 * implied warranty.
 */

char pm_getc(FILE *const fileP, const char *filename)
{
  int ich;
  char ch;

  ich = getc(fileP);
  if (ich == EOF)
    fprintf(stderr, _("wrlib: EOF / read error reading a byte from PPM file \"%s\"\n"), filename);
  ch = (char)ich;

  if (ch == '#') {
    do {
      ich = getc(fileP);
      if (ich == EOF)
        fprintf(stderr, _("wrlib: EOF / read error reading a byte from PPM file \"%s\"\n"),
                filename);
      ch = (char)ich;
    } while (ch != '\n' && ch != '\r');
  }
  return ch;
}

unsigned char pm_getrawbyte(FILE *const file, const char *filename)
{
  int iby;

  iby = getc(file);
  if (iby == EOF)
    fprintf(stderr, _("wrlib: EOF / read error reading a byte from PPM file \"%s\"\n"), filename);
  return (unsigned char)iby;
}

int pm_getuint(FILE *const ifP, const char *filename)
{
  char ch;
  unsigned int i;

  do {
    ch = pm_getc(ifP, filename);
  } while (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r');

  if (ch < '0' || ch > '9') {
    fprintf(stderr,
            _("wrlib: junk in PPM file \"%s\", expected an unsigned integer but got 0x%02X\n"),
            filename, (int)ch);
    return -1;
  }

  i = 0;
  do {
    unsigned int const digitVal = ch - '0';

    if (i > INT_MAX / 10) {
      fprintf(stderr,
              _("wrlib: ASCII decimal integer in PPM file \"%s\" is too large to be processed\n"),
              filename);
      return -1;
    }

    i *= 10;

    if (i > INT_MAX - digitVal) {
      fprintf(stderr,
              _("wrlib: ASCII decimal integer in PPM file \"%s\" is too large to be processed\n"),
              filename);
      return -1;
    }

    i += digitVal;

    ch = pm_getc(ifP, filename);
  } while (ch >= '0' && ch <= '9');

  return i;
}
/* end of fileio.c re-used code */
/******************************************************************************************/

/* PGM: support for portable graymap ascii and binary encoding */
static RImage *load_graymap(FILE *file, int w, int h, int max, int raw, const char *filename)
{
  RImage *image;
  unsigned char *ptr;
  int x, y;

  if (raw != '2' && raw != '5') {
    RErrorCode = RERR_BADFORMAT;
    return NULL;
  }

  image = RCreateImage(w, h, 0);
  if (!image) {
    RErrorCode = RERR_NOMEMORY;
    return NULL;
  }

  if (max < 256) {
    ptr = image->data;
    if (raw == '2') {
      int val;

      for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
          val = pm_getuint(file, filename);

          if (val > max || val < 0) {
            RErrorCode = RERR_BADIMAGEFILE;
            RReleaseImage(image);
            return NULL;
          }

          val = val * 255 / max;
          *(ptr++) = val;
          *(ptr++) = val;
          *(ptr++) = val;
        }
      }
    } else {
      if (raw == '5') {
        char *buf;

        buf = malloc(w + 1);
        if (!buf) {
          RErrorCode = RERR_NOMEMORY;
          RReleaseImage(image);
          return NULL;
        }
        for (y = 0; y < h; y++) {
          if (!fread(buf, w, 1, file)) {
            free(buf);
            RErrorCode = RERR_BADIMAGEFILE;
            RReleaseImage(image);
            return NULL;
          }

          for (x = 0; x < w; x++) {
            *(ptr++) = buf[x];
            *(ptr++) = buf[x];
            *(ptr++) = buf[x];
          }
        }
        free(buf);
      }
    }
  }
  return image;
}

/* PPM: support for portable pixmap ascii and binary encoding */
static RImage *load_pixmap(FILE *file, int w, int h, int max, int raw, const char *filename)
{
  RImage *image;
  int i;
  unsigned char *ptr;

  if (raw != '3' && raw != '6') {
    RErrorCode = RERR_BADFORMAT;
    return NULL;
  }

  image = RCreateImage(w, h, 0);
  if (!image) {
    RErrorCode = RERR_NOMEMORY;
    return NULL;
  }

  ptr = image->data;
  if (max < 256) {
    if (raw == '3') {
      int x, y, val;

      for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
          for (i = 0; i < 3; i++) {
            val = pm_getuint(file, filename);

            if (val > max || val < 0) {
              RErrorCode = RERR_BADIMAGEFILE;
              RReleaseImage(image);
              return NULL;
            }

            val = val * 255 / max;
            *(ptr++) = val;
          }
        }
      }
    } else if (raw == '6') {
      char buf[3];

      i = 0;
      while (i < w * h) {
        if (fread(buf, 1, 3, file) != 3) {
          RErrorCode = RERR_BADIMAGEFILE;
          RReleaseImage(image);
          return NULL;
        }

        *(ptr++) = buf[0];
        *(ptr++) = buf[1];
        *(ptr++) = buf[2];
        i++;
      }
    }
  }
  return image;
}

/* PBM: support for portable bitmap ascii and binary encoding */
static RImage *load_bitmap(FILE *file, int w, int h, int max, int raw, const char *filename)
{
  RImage *image;
  int val;
  unsigned char *ptr;

  if (raw != '1' && raw != '4') {
    RErrorCode = RERR_BADFORMAT;
    return NULL;
  }

  image = RCreateImage(w, h, 0);
  if (!image) {
    RErrorCode = RERR_NOMEMORY;
    return NULL;
  }

  ptr = image->data;
  if (raw == '1') {
    int i = 0;

    while (i < w * h) {
      val = pm_getuint(file, filename);

      if (val > max || val < 0) {
        RErrorCode = RERR_BADIMAGEFILE;
        RReleaseImage(image);
        return NULL;
      }

      val = (val == 0) ? 255 : 0;
      *(ptr++) = val;
      *(ptr++) = val;
      *(ptr++) = val;
      i++;
    }
  } else {
    if (raw == '4') {
      unsigned char buf;
      int bitshift;
      int x, y;

      for (y = 0; y < h; y++) {
        bitshift = -1;
        for (x = 0; x < w; x++) {
          if (bitshift == -1) {
            buf = pm_getrawbyte(file, filename);
            bitshift = 7;
          }
          val = (buf >> bitshift) & 1;
          val = (val == 0) ? 255 : 0;
          --bitshift;
          *(ptr++) = val;
          *(ptr++) = val;
          *(ptr++) = val;
        }
      }
    }
  }
  return image;
}

RImage *RLoadPPM(const char *file_name)
{
  FILE *file;
  RImage *image = NULL;
  char buffer[256];
  int w, h, m;
  int type;

  file = fopen(file_name, "rb");
  if (!file) {
    RErrorCode = RERR_OPEN;
    return NULL;
  }

  /* get signature */
  if (!fgets(buffer, 255, file)) {
    RErrorCode = RERR_BADIMAGEFILE;
    fclose(file);
    return NULL;
  }

  /* accept bitmaps, pixmaps or graymaps */
  if (buffer[0] != 'P' || (buffer[1] < '1' || buffer[1] > '6')) {
    RErrorCode = RERR_BADFORMAT;
    fclose(file);
    return NULL;
  }

  type = buffer[1];

  /* skip comments */
  while (1) {
    if (!fgets(buffer, 255, file)) {
      RErrorCode = RERR_BADIMAGEFILE;
      fclose(file);
      return NULL;
    }

    if (buffer[0] != '#')
      break;
  }

  /* get size */
  if (sscanf(buffer, "%i %i", &w, &h) != 2 || w < 1 || h < 1) {
    /* Short file */
    RErrorCode = RERR_BADIMAGEFILE;
    fclose(file);
    return NULL;
  }

  if (type != '1' && type != '4') {
    if (!fgets(buffer, 255, file)) {
      RErrorCode = RERR_BADIMAGEFILE;
      fclose(file);
      return NULL;
    }
    /* get max value */
    if (sscanf(buffer, "%i", &m) != 1 || m < 1) {
      /* Short file */
      RErrorCode = RERR_BADIMAGEFILE;
      fclose(file);
      return NULL;
    }
  } else {
    m = 1;
  }

  if (type == '1' || type == '4') {
    /* Portable Bit Map: P1 is for 'plain' (ascii, rare), P4 for 'regular' (binary) */
    image = load_bitmap(file, w, h, m, type, file_name);
  } else if (type == '2' || type == '5') {
    /* Portable Gray Map: P2 is for 'plain' (ascii, rare), P5 for 'regular' (binary) */
    image = load_graymap(file, w, h, m, type, file_name);
  } else if (type == '3' || type == '6') {
    /* Portable Pix Map: P3 is for 'plain' (ascii, rare), P6 for 'regular' (binary) */
    image = load_pixmap(file, w, h, m, type, file_name);
  }

  fclose(file);
  return image;
}
