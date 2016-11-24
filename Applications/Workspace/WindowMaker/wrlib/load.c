/* load.c - load image from file
 *
 * Raster graphics library
 *
 * Copyright (c) 1997-2003 Alfredo K. Kojima
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

#include <config.h>

#include <errno.h>
#include <X11/Xlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string.h>
#include <time.h>
#include <assert.h>

#include "wraster.h"
#include "imgformat.h"


typedef struct RCachedImage {
	RImage *image;
	char *file;
	time_t last_modif;	/* last time file was modified */
	time_t last_use;	/* last time image was used */
} RCachedImage;

/*
 * Number of image to keep in the cache
 */
static int RImageCacheSize = -1;

#define IMAGE_CACHE_DEFAULT_NBENTRIES	  8
#define IMAGE_CACHE_MAXIMUM_NBENTRIES	256

/*
 * Max. size of image (in pixels) to store in the cache
 */
static int RImageCacheMaxImage = -1;	/* 0 = any size */

#define IMAGE_CACHE_DEFAULT_MAXPIXELS	(64 * 64)
#define IMAGE_CACHE_MAXIMUM_MAXPIXELS	(256 * 256)


static RCachedImage *RImageCache;


static WRImgFormat identFile(const char *path);


char **RSupportedFileFormats(void)
{
	static char *tmp[IM_TYPES + 2];
	int i = 0;

	/* built-in */
	tmp[i++] = "XPM";
	/* built-in PNM here refers to anymap format: PPM, PGM, PBM */
	tmp[i++] = "PNM";
	/*
	 * PPM is a just a sub-type of PNM, but it has to be in the list
	 * for compatibility with legacy programs that may expect it but
	 * not the new PNM type
	 */
	tmp[i++] = "PPM";
#ifdef USE_TIFF
	tmp[i++] = "TIFF";
#endif
#ifdef USE_PNG
	tmp[i++] = "PNG";
#endif
#ifdef USE_JPEG
	tmp[i++] = "JPEG";
#endif
#ifdef USE_GIF
	tmp[i++] = "GIF";
#endif
#ifdef USE_WEBP
	tmp[i++] = "WEBP";
#endif
	tmp[i] = NULL;

	return tmp;
}

static void init_cache(void)
{
	char *tmp;

	tmp = getenv("RIMAGE_CACHE");
	if (!tmp || sscanf(tmp, "%i", &RImageCacheSize) != 1)
		RImageCacheSize = IMAGE_CACHE_DEFAULT_NBENTRIES;
	if (RImageCacheSize < 0)
		RImageCacheSize = 0;
	if (RImageCacheSize > IMAGE_CACHE_MAXIMUM_NBENTRIES)
		RImageCacheSize = IMAGE_CACHE_MAXIMUM_NBENTRIES;

	tmp = getenv("RIMAGE_CACHE_SIZE");
	if (!tmp || sscanf(tmp, "%i", &RImageCacheMaxImage) != 1)
		RImageCacheMaxImage = IMAGE_CACHE_DEFAULT_MAXPIXELS;
	if (RImageCacheMaxImage < 0)
		RImageCacheMaxImage = 0;
	if (RImageCacheMaxImage > IMAGE_CACHE_MAXIMUM_MAXPIXELS)
		RImageCacheMaxImage = IMAGE_CACHE_MAXIMUM_MAXPIXELS;

	if (RImageCacheSize > 0) {
		RImageCache = malloc(sizeof(RCachedImage) * RImageCacheSize);
		if (RImageCache == NULL) {
			printf("wrlib: out of memory for image cache\n");
			return;
		}
		memset(RImageCache, 0, sizeof(RCachedImage) * RImageCacheSize);
	}
}

void RReleaseCache(void)
{
	int i;

	if (RImageCacheSize > 0) {
		for (i = 0; i < RImageCacheSize; i++) {
			if (RImageCache[i].file) {
				RReleaseImage(RImageCache[i].image);
				free(RImageCache[i].file);
			}
		}
		free(RImageCache);
		RImageCache = NULL;
		RImageCacheSize = -1;
	}
}

RImage *RLoadImage(RContext *context, const char *file, int index)
{
	RImage *image = NULL;
	int i;
	struct stat st;

	assert(file != NULL);

	if (RImageCacheSize < 0)
		init_cache();

	if (RImageCacheSize > 0) {

		for (i = 0; i < RImageCacheSize; i++) {
			if (RImageCache[i].file && strcmp(file, RImageCache[i].file) == 0) {

				if (stat(file, &st) == 0 && st.st_mtime == RImageCache[i].last_modif) {
					RImageCache[i].last_use = time(NULL);

					return RCloneImage(RImageCache[i].image);

				} else {
					free(RImageCache[i].file);
					RImageCache[i].file = NULL;
					RReleaseImage(RImageCache[i].image);
				}
			}
		}
	}

	switch (identFile(file)) {
	case IM_ERROR:
		return NULL;

	case IM_UNKNOWN:
#ifdef USE_MAGICK
		/* generic file format support using ImageMagick
		 * BMP, PCX, PICT, SVG, ...
		 */
		image = RLoadMagick(file);
		break;
#else
		RErrorCode = RERR_BADFORMAT;
		return NULL;
#endif

	case IM_XPM:
		image = RLoadXPM(context, file);
		break;

#ifdef USE_TIFF
	case IM_TIFF:
		image = RLoadTIFF(file, index);
		break;
#endif				/* USE_TIFF */

#ifdef USE_PNG
	case IM_PNG:
		image = RLoadPNG(context, file);
		break;
#endif				/* USE_PNG */

#ifdef USE_JPEG
	case IM_JPEG:
		image = RLoadJPEG(file);
		break;
#endif				/* USE_JPEG */

#ifdef USE_GIF
	case IM_GIF:
		image = RLoadGIF(file, index);
		break;
#endif				/* USE_GIF */

#ifdef USE_WEBP
	case IM_WEBP:
		image = RLoadWEBP(file);
		break;
#endif				/* USE_WEBP */

	case IM_PPM:
		image = RLoadPPM(file);
		break;

	default:
		RErrorCode = RERR_BADFORMAT;
		return NULL;
	}

	/* store image in cache */
	if (RImageCacheSize > 0 && image &&
	    (RImageCacheMaxImage == 0 || RImageCacheMaxImage >= image->width * image->height)) {
		time_t oldest = time(NULL);
		int oldest_idx = 0;
		int done = 0;

		for (i = 0; i < RImageCacheSize; i++) {
			if (!RImageCache[i].file) {
				RImageCache[i].file = malloc(strlen(file) + 1);
				strcpy(RImageCache[i].file, file);
				RImageCache[i].image = RCloneImage(image);
				RImageCache[i].last_modif = st.st_mtime;
				RImageCache[i].last_use = time(NULL);
				done = 1;
				break;
			} else {
				if (oldest > RImageCache[i].last_use) {
					oldest = RImageCache[i].last_use;
					oldest_idx = i;
				}
			}
		}

		/* if no slot available, dump least recently used one */
		if (!done) {
			free(RImageCache[oldest_idx].file);
			RReleaseImage(RImageCache[oldest_idx].image);
			RImageCache[oldest_idx].file = malloc(strlen(file) + 1);
			strcpy(RImageCache[oldest_idx].file, file);
			RImageCache[oldest_idx].image = RCloneImage(image);
			RImageCache[oldest_idx].last_modif = st.st_mtime;
			RImageCache[oldest_idx].last_use = time(NULL);
		}
	}

	return image;
}

char *RGetImageFileFormat(const char *file)
{
	switch (identFile(file)) {
	case IM_XPM:
		return "XPM";

#ifdef USE_TIFF
	case IM_TIFF:
		return "TIFF";
#endif				/* USE_TIFF */

#ifdef USE_PNG
	case IM_PNG:
		return "PNG";
#endif				/* USE_PNG */

#ifdef USE_JPEG
	case IM_JPEG:
		return "JPEG";
#endif				/* USE_JPEG */

#ifdef USE_GIF
	case IM_GIF:
		return "GIF";
#endif				/* USE_GIF */

#ifdef USE_WEBP
	case IM_WEBP:
		return "WEBP";
#endif				/* USE_WEBP */

	case IM_PPM:
		return "PPM";

	default:
		return NULL;
	}
}

static WRImgFormat identFile(const char *path)
{
	FILE *file;
	unsigned char buffer[32];
	size_t nread;

	assert(path != NULL);

	for (;;) {
		file = fopen(path, "rb");
		if (file != NULL)
			break;
		if (errno != EINTR) {
			RErrorCode = RERR_OPEN;
			return IM_ERROR;
		}
	}

	nread = fread(buffer, 1, sizeof(buffer), file);
	if (nread < sizeof(buffer) || ferror(file)) {
		fclose(file);
		RErrorCode = RERR_READ;
		return IM_ERROR;
	}
	fclose(file);

	/* check for XPM */
	if (strncmp((char *)buffer, "/* XPM */", 9) == 0)
		return IM_XPM;

	/* check for TIFF */
	if ((buffer[0] == 'I' && buffer[1] == 'I' && buffer[2] == '*' && buffer[3] == 0)
	    || (buffer[0] == 'M' && buffer[1] == 'M' && buffer[2] == 0 && buffer[3] == '*'))
		return IM_TIFF;

	/*
	 * check for PNG
	 *
	 * The signature is defined in the PNG specifiation:
	 * http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html
	 * it is valid for v1.0, v1.1, v1.2 and ISO version
	 */
	if (buffer[0] == 137 && buffer[1] == 80 && buffer[2] == 78 && buffer[3] == 71 &&
	    buffer[4] ==  13 && buffer[5] == 10 && buffer[6] == 26 && buffer[7] == 10)
		return IM_PNG;

	/* check for PBM or PGM or PPM */
	if (buffer[0] == 'P' && (buffer[1] > '0' && buffer[1] < '7') && (buffer[2] == 0x0a || buffer[2] == 0x20 || buffer[2] == 0x09 || buffer[2] == 0x0d))
		return IM_PPM;

	/* check for JPEG */
	if (buffer[0] == 0xff && buffer[1] == 0xd8)
		return IM_JPEG;

	/* check for GIF */
	if (buffer[0] == 'G' && buffer[1] == 'I' && buffer[2] == 'F' && buffer[3] == '8' &&
	    (buffer[4] == '7' ||  buffer[4] == '9') && buffer[5] == 'a')
		return IM_GIF;

	/* check for WEBP */
	if (buffer[0]  == 'R' && buffer[1]  == 'I' && buffer[2]  == 'F' && buffer[3]  == 'F' &&
	    buffer[8]  == 'W' && buffer[9]  == 'E' && buffer[10] == 'B' && buffer[11] == 'P' &&
	    buffer[12] == 'V' && buffer[13] == 'P' && buffer[14] == '8' &&
	    (buffer[15] == ' '       /* Simple File Format (Lossy) */
	     || buffer[15] == 'L'    /* Simple File Format (Lossless) */
	     || buffer[15] == 'X'))  /* Extended File Format */
		return IM_WEBP;

	return IM_UNKNOWN;
}
