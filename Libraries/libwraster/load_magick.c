/* load_magick.c - load image file using ImageMagick
 *
 * Raster graphics library
 *
 * Copyright (c) 2014 Window Maker Team
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

#include <wand/MagickWand.h>

#include "wraster.h"
#include "imgformat.h"


static int RInitMagickIfNeeded(void);


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

	/* Create a wand */
	m_wand = NewMagickWand();

	/* set the default background as transparent */
	bg_wand = NewPixelWand();
	PixelSetColor(bg_wand, "none");
	MagickSetBackgroundColor(m_wand, bg_wand);

	/* Read the input image */
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
		mrc = MagickExportImagePixels(m_wand, 0, 0, (size_t)w, (size_t)h, "RGB", CharPixel, ptr);
	else
		mrc = MagickExportImagePixels(m_wand, 0, 0, (size_t)w, (size_t)h, "RGBA", CharPixel, ptr);

	if (mrc == MagickFalse) {
		RErrorCode = RERR_BADIMAGEFILE;
		RReleaseImage(image);
		image = NULL;
		goto bye;
	}

bye:
	/* Tidy up */
	DestroyPixelWand(bg_wand);
	MagickClearException(m_wand);
	DestroyMagickWand(m_wand);

	return image;
}

/* Track the state of the library in memory */
static enum {
	MW_NotReady,
	MW_Ready
} magick_state;

/*
 * Initialise MagickWand, but only if it was not already done
 *
 * Return ok(0) when MagickWand is usable and fail(!0) if not usable
 */
static int RInitMagickIfNeeded(void)
{
	if (magick_state == MW_NotReady) {
		MagickWandGenesis();
		magick_state = MW_Ready;
	}

	return 0;
}

void RReleaseMagick(void)
{
	if (magick_state == MW_Ready) {
		MagickWandTerminus();
		magick_state = MW_NotReady;
	}
}
