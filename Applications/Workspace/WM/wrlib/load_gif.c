/* gif.c - load GIF image from file
 *
 * Raster graphics library
 *
 * Copyright (c) 1998-2003 Alfredo K. Kojima
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

#include <gif_lib.h>

#include "wraster.h"
#include "imgformat.h"

static int InterlacedOffset[] = { 0, 4, 2, 1 };
static int InterlacedJumps[] = { 8, 8, 4, 2 };

/*
 * Partially based on code in gif2rgb from giflib, by Gershon Elber.
 */
RImage *RLoadGIF(const char *file, int index)
{
	RImage *image = NULL;
	unsigned char *cptr;
	GifFileType *gif = NULL;
	GifPixelType *buffer = NULL;
	int i, j, k;
	int width, height;
	GifRecordType recType;
	ColorMapObject *colormap;
	unsigned char rmap[256], gmap[256], bmap[256];
	int gif_error;

	if (index < 0)
		index = 0;

	/* default error message */
	RErrorCode = RERR_BADINDEX;

#if USE_GIF == 4
	gif = DGifOpenFileName(file);
#else /* USE_GIF == 5 */
	gif = DGifOpenFileName(file, &gif_error);
#endif

	if (!gif) {
#if USE_GIF == 4
		gif_error = GifLastError();
#endif
		switch (gif_error) {
		case D_GIF_ERR_OPEN_FAILED:
			RErrorCode = RERR_OPEN;
			break;
		case D_GIF_ERR_READ_FAILED:
			RErrorCode = RERR_READ;
			break;
		default:
			RErrorCode = RERR_BADIMAGEFILE;
			break;
		}
		return NULL;
	}

	if (gif->SWidth < 1 || gif->SHeight < 1) {
#if (USE_GIF == 5) && (GIFLIB_MINOR >= 1)
		DGifCloseFile(gif, NULL);
#else
		DGifCloseFile(gif);
#endif
		RErrorCode = RERR_BADIMAGEFILE;
		return NULL;
	}

	colormap = gif->SColorMap;
	i = 0;

	do {
		int extCode;
		GifByteType *extension;

		if (DGifGetRecordType(gif, &recType) == GIF_ERROR)
			goto giferr;

		switch (recType) {
		case IMAGE_DESC_RECORD_TYPE:
			if (i++ != index)
				break;

			if (DGifGetImageDesc(gif) == GIF_ERROR)
				goto giferr;

			width = gif->Image.Width;
			height = gif->Image.Height;

			if (gif->Image.ColorMap)
				colormap = gif->Image.ColorMap;

			/* the gif specs talk about a default colormap, but it
			 * doesnt say what the heck is this default colormap
			 * Render anything */
			if (colormap) {
				for (j = 0; j < colormap->ColorCount; j++) {
					rmap[j] = colormap->Colors[j].Red;
					gmap[j] = colormap->Colors[j].Green;
					bmap[j] = colormap->Colors[j].Blue;
				}
			}

			buffer = malloc(width * sizeof(GifPixelType));
			if (!buffer) {
				RErrorCode = RERR_NOMEMORY;
				goto bye;
			}

			image = RCreateImage(width, height, False);
			if (!image)
				goto bye;

			if (gif->Image.Interlace) {
				int l, pelsPerLine;

				if (RRGBAFormat == image->format)
					pelsPerLine = width * 4;
				else
					pelsPerLine = width * 3;

				for (j = 0; j < 4; j++) {
					for (k = InterlacedOffset[j]; k < height; k += InterlacedJumps[j]) {
						if (DGifGetLine(gif, buffer, width) == GIF_ERROR)
							goto giferr;

						cptr = image->data + (k * pelsPerLine);
						for (l = 0; l < width; l++) {
							int pixel = buffer[l];
							*cptr++ = rmap[pixel];
							*cptr++ = gmap[pixel];
							*cptr++ = bmap[pixel];
						}
					}
				}
			} else {
				cptr = image->data;
				for (j = 0; j < height; j++) {
					if (DGifGetLine(gif, buffer, width) == GIF_ERROR)
						goto giferr;

					for (k = 0; k < width; k++) {
						int pixel = buffer[k];
						*cptr++ = rmap[pixel];
						*cptr++ = gmap[pixel];
						*cptr++ = bmap[pixel];
						if (RRGBAFormat == image->format)
							cptr++;
					}
				}
			}
			break;

		case EXTENSION_RECORD_TYPE:
			/* skip all extension blocks */
			if (DGifGetExtension(gif, &extCode, &extension) == GIF_ERROR)
				goto giferr;

			while (extension)
				if (DGifGetExtensionNext(gif, &extension) == GIF_ERROR)
					goto giferr;

			break;

		default:
			break;
		}
	} while (recType != TERMINATE_RECORD_TYPE && i <= index);

	/* yuck! */
	goto did_not_get_any_errors;
 giferr:
#if USE_GIF == 4
	switch (GifLastError()) {
	case D_GIF_ERR_OPEN_FAILED:
		RErrorCode = RERR_OPEN;
		break;
	case D_GIF_ERR_READ_FAILED:
		RErrorCode = RERR_READ;
		break;
	default:
		RErrorCode = RERR_BADIMAGEFILE;
		break;
	}
#else
	/* With gif_lib v5 there's no way to know what went wrong */
	RErrorCode = RERR_BADIMAGEFILE;
#endif
 bye:
	if (image)
		RReleaseImage(image);
	image = NULL;
 did_not_get_any_errors:

	if (buffer)
		free(buffer);

	if (gif)
#if (USE_GIF == 5) && (GIFLIB_MINOR >= 1)
		DGifCloseFile(gif, NULL);
#else
		DGifCloseFile(gif);
#endif

	return image;
}
