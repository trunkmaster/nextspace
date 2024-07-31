/* tiff.c - load TIFF image from file
 *
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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <tiff.h>
#include <tiffio.h>
#include <tiffvers.h>

#include <config.h>
#include "wraster.h"

typedef struct {
  uint16_t numImages;   /* number of images in tiff */
  uint16_t imageNumber; /* number of current image */
  uint32_t subfileType;
  uint32_t width;
  uint32_t height;
  uint16_t bitsPerSample;   /* number of bits per data channel */
  uint16_t samplesPerPixel; /* number of channels per pixel */
  uint16_t planarConfig;    /* meshed or separate */
  uint16_t photoInterp;     /* photometric interpretation of bitmap data, */
  uint16_t compression;
  uint16_t extraSamples; /* Alpha */
  int assocAlpha;
  int quality; /* compression quality (for jpeg) 1 to 255 */
  int error;
  float xdpi;
  float ydpi;
  char isBigEndian; /* meaningful only for 16 & 32 bit depths */
  char is16Bit;
  char is32Bit;
} RTiffInfo;

/* Read some information about the image. Note that currently we don't
   determine numImages. */
static RTiffInfo *RTiffGetInfo(TIFF *tif)
{
  RTiffInfo *info = NULL;
  uint16_t *sample_info = NULL;

  if (tif == NULL) {
    return NULL;
  }

  info = malloc(sizeof(RTiffInfo));
  memset(info, 0, sizeof(RTiffInfo));
  // if (imageNumber >= 0) {
  //   if (TIFFSetDirectory(image, imageNumber) == 0)
  //     return NULL;
  //   info->imageNumber = imageNumber;
  // }

  info->imageNumber = 0;

  TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &info->width);
  TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &info->height);
  TIFFGetField(tif, TIFFTAG_COMPRESSION, &info->compression);
  if (info->compression == COMPRESSION_JPEG)
    TIFFGetField(tif, TIFFTAG_JPEGQUALITY, &info->quality);
  TIFFGetField(tif, TIFFTAG_SUBFILETYPE, &info->subfileType);
  TIFFGetField(tif, TIFFTAG_EXTRASAMPLES, &info->extraSamples, &sample_info);
  info->extraSamples = (info->extraSamples == 1 && ((sample_info[0] == EXTRASAMPLE_ASSOCALPHA) ||
                                                    (sample_info[0] == EXTRASAMPLE_UNASSALPHA)));
  info->assocAlpha = (info->extraSamples == 1 && sample_info[0] == EXTRASAMPLE_ASSOCALPHA);

  /* If the following tags aren't present then use the TIFF defaults. */
  TIFFGetFieldDefaulted(tif, TIFFTAG_BITSPERSAMPLE, &info->bitsPerSample);
  TIFFGetFieldDefaulted(tif, TIFFTAG_SAMPLESPERPIXEL, &info->samplesPerPixel);
  TIFFGetFieldDefaulted(tif, TIFFTAG_PLANARCONFIG, &info->planarConfig);

  /* If TIFFTAG_PHOTOMETRIC is not present then assign a reasonable default.
     `The TIFF 5.0 specification doesn't give a default. */
  if (!TIFFGetField(tif, TIFFTAG_PHOTOMETRIC, &info->photoInterp)) {
    switch (info->samplesPerPixel) {
      case 1:
        info->photoInterp = PHOTOMETRIC_MINISBLACK;
        break;
      case 3:
      case 4:
        info->photoInterp = PHOTOMETRIC_RGB;
        break;
      default:
        TIFFError(TIFFFileName(tif), "Missing needed \"PhotometricInterpretation\" tag");
        return NULL;
    }
    TIFFError(TIFFFileName(tif), "No \"PhotometricInterpretation\" tag, assuming %s\n",
              info->photoInterp == PHOTOMETRIC_RGB ? "RGB" : "min-is-black");
  }

  // resolution
  {
    uint16_t resolution_unit;
    float xres, yres;
    if (TIFFGetField(tif, TIFFTAG_XRESOLUTION, &xres) &&
        TIFFGetField(tif, TIFFTAG_YRESOLUTION, &yres)) {
      TIFFGetFieldDefaulted(tif, TIFFTAG_RESOLUTIONUNIT, &resolution_unit);
      if (resolution_unit == 2)  // Inch
      {
        info->xdpi = xres;
        info->ydpi = yres;
      } else if (resolution_unit == 3)  // Centimeter
      {
        info->xdpi = xres * 2.54;
        info->ydpi = yres * 2.54;
      }
    }
  }

  return info;
}

RImage *RLoadTIFF(const char *file, int index)
{
  RImage *image = NULL;
  TIFF *tif;
  RTiffInfo *info = NULL;
  int i;
#if TIFFLIB_VERSION < 20210416
  uint32 *data, *ptr;
#else
  uint32_t *data, *ptr;
#endif

  tif = TIFFOpen(file, "r");
  if (!tif)
    return NULL;

  /* seek index */
  i = index;
  while (i > 0) {
    if (!TIFFReadDirectory(tif)) {
      RErrorCode = RERR_BADINDEX;
      TIFFClose(tif);
      return NULL;
    }
    i--;
  }

  /* get info */
  info = RTiffGetInfo(tif);

  if (info->width < 1 || info->height < 1) {
    RErrorCode = RERR_BADIMAGEFILE;
    TIFFClose(tif);
    return NULL;
  }

  /* read data */
#if TIFFLIB_VERSION < 20210416
  ptr = data = (uint32 *)_TIFFmalloc(width * height * sizeof(uint32));
#else
  ptr = data = (uint32_t *)_TIFFmalloc(info->width * info->height * sizeof(uint32_t));
#endif

  if (!data) {
    RErrorCode = RERR_NOMEMORY;
  } else {
    image = RCreateImage(info->width, info->height, info->extraSamples);
    if (!TIFFReadRGBAImageOriented(tif, info->width, info->height, data, ORIENTATION_TOPLEFT, 0)) {
      RErrorCode = RERR_BADIMAGEFILE;
      RReleaseImage(image);
      image = NULL;
    } else if (data) {
      memcpy(image->data, data, info->width * info->height * sizeof(uint32_t));
    }
    _TIFFfree(ptr);
  }

  TIFFClose(tif);

  return image;
}

#if 0
static RImage *convert_data(unsigned char *data, RTiffInfo *info)
{
  RImage *image = NULL;
  int ch;
  unsigned char *r, *g, *b, *a;

  /* convert data */
  image = RCreateImage(info->width, info->height, info->extraSamples);

  if (info->extraSamples)
    ch = 4;
  else
    ch = 3;

  if (image) {
    int x, y;

    r = image->data;
    g = image->data + 1;
    b = image->data + 2;
    a = image->data + 3;

    /* data seems to be stored upside down */
    data += info->width * (info->height - 1);
    for (y = 0; y < info->height; y++) {
      for (x = 0; x < info->width; x++) {
        *(r) = (*data) & 0xff;
        *(g) = (*data >> 8) & 0xff;
        *(b) = (*data >> 16) & 0xff;

        if (info->extraSamples) {
          *(a) = (*data >> 24) & 0xff;

          if (info->assocAlpha && (*a > 0)) {
            *r = (*r * 255) / *(a);
            *g = (*g * 255) / *(a);
            *b = (*b * 255) / *(a);
          }

          a += 4;
        }

        r += ch;
        g += ch;
        b += ch;
        data++;
      }
      data -= 2 * info->width;
    }
  }
}
#endif
