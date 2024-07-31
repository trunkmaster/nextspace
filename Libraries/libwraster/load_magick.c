/* load_magick.c - load image file using ImageMagick
 *
 * Raster graphics library
 *
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
#include <string.h>
#include <wand/magick_wand.h>
#include "wraster.h"
#include "imgformat.h"

// #ifdef USE_MAGICK
// #if USE_MAGICK < 7
// #include <wand/magick_wand.h>
// #else
// #include <MagickWand/MagickWand.h>
// #endif
// #endif

// static int RInitMagickIfNeeded(void);

/*
RImage *RLoadMagick(const char *file_name)
{
        RImage *image = NULL;
        unsigned char *ptr;
        unsigned long w,h;
        MagickWand *m_wand = NULL;
        MagickBooleanType mrc;
        MagickBooleanType hasAlfa;
        PixelWand *bg_wand = NULL;

        if (RInitMagickIfNeeded()) {
                RErrorCode = RERR_BADFORMAT;
                return NULL;
        }

        // Create a wand
        m_wand = NewMagickWand();

        // set the default background as transparent
        bg_wand = NewPixelWand();
        PixelSetColor(bg_wand, "none");
        MagickSetBackgroundColor(m_wand, bg_wand);


        // Read the input image
        if (!MagickReadImage(m_wand, file_name)) {
                RErrorCode = RERR_BADIMAGEFILE;
                goto bye;
        }

        w = MagickGetImageWidth(m_wand);
        h = MagickGetImageHeight(m_wand);

        hasAlfa = MagickGetImageAlphaChannel(m_wand);

        image = RCreateImage(w, h, (unsigned int) hasAlfa);
        if (!image) {
                RErrorCode = RERR_NOMEMORY;
                goto bye;
        }

        ptr = image->data;
        if (hasAlfa == MagickFalse)
                mrc = MagickExportImagePixels(m_wand, 0, 0, (size_t)w, (size_t)h, "RGB", CharPixel,
ptr); else mrc = MagickExportImagePixels(m_wand, 0, 0, (size_t)w, (size_t)h, "RGBA", CharPixel,
ptr);

        if (mrc == MagickFalse) {
                RErrorCode = RERR_BADIMAGEFILE;
                RReleaseImage(image);
                image = NULL;
                goto bye;
        }

bye:
        // Tidy up
        DestroyPixelWand(bg_wand);
        MagickClearException(m_wand);
        DestroyMagickWand(m_wand);

        return image;
}
*/

RImage *RLoadMagick(const char *file_name)
{
  RImage *image = NULL;
  unsigned char *ptr;
  unsigned long w, h;
  MagickWand *magick_wand = NULL;
  PixelWand *background = NULL;
  MagickBool is_success;
  MagickBool is_opaque;

  //   if (RInitMagickIfNeeded()) {
  //     RErrorCode = RERR_BADFORMAT;
  //     return NULL;
  //   }

  fprintf(stderr, "RLoadMagick: %s\n", file_name);

  InitializeMagick(NULL);

  /* Create a wand */
  magick_wand = NewMagickWand();

  /* Read the input image */
  if (MagickReadImage(magick_wand, file_name) != MagickPass) {
    RErrorCode = RERR_BADIMAGEFILE;
    fprintf(stderr, "failed to read image at path: %s\n", file_name);
    goto bye;
  }

  /* set the default background as transparent */
  background = NewPixelWand();
  PixelSetColor(background, "none");
  MagickSetImageBackgroundColor(magick_wand, background);
  DestroyPixelWand(background);

  w = MagickGetImageWidth(magick_wand);
  h = MagickGetImageHeight(magick_wand);

  fprintf(stderr, "w: %lu, h: %lu\n", w, h);

  is_success = MagickIsOpaqueImage(magick_wand, &is_opaque);

  image = RCreateImage(w, h, !is_opaque);
  if (!image) {
    RErrorCode = RERR_NOMEMORY;
    goto bye;
  }

  fprintf(stderr, "RCreateImage()\n");

  ptr = image->data;
  if (is_opaque == MagickTrue) {
    is_success =
        MagickGetImagePixels(magick_wand, 0, 0, (size_t)w, (size_t)h, "RGB", CharPixel, ptr);
    fprintf(stderr, "MagickGetImagePixels: %d, opaque\n", is_success);
  } else {
    is_success =
        MagickGetImagePixels(magick_wand, 0, 0, (size_t)w, (size_t)h, "RGBA", CharPixel, ptr);
    fprintf(stderr, "MagickGetImagePixels: %d, alpha\n", is_success);
  }

  if (!is_success) {
    RErrorCode = RERR_BADIMAGEFILE;
    RReleaseImage(image);
    image = NULL;
    goto bye;
  }

  fprintf(stderr, "END\n");

bye:
  /* Tidy up */
  DestroyMagickWand(magick_wand);
  fprintf(stderr, "DestroyMagickWand\n");
  // MagickClearException(magick_wand);

  return image;
}

/* Track the state of the library in memory */
// static enum {
// 	MW_NotReady,
// 	MW_Ready
// } magick_state;

/*
 * Initialise MagickWand, but only if it was not already done
 *
 * Return ok(0) when MagickWand is usable and fail(!0) if not usable
 */
// static int RInitMagickIfNeeded(void)
// {
//   if (magick_state == MW_NotReady) {
//     MagickWandGenesis();
//     magick_state = MW_Ready;
//   }

//   return 0;
// }

void RReleaseMagick(void)
{
  // if (magick_state == MW_Ready) {
  // 	MagickWandTerminus();
  // 	magick_state = MW_NotReady;
  // }
}
