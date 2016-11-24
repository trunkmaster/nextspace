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

/*
 * Functions to load and save RImage from/to file in a specific file format
 *
 * These functions are for WRaster library's internal use only, please use
 * the RLoadImage function defined in 'wraster.h'
 */

#ifndef IMGFORMAT_INTERNAL_H
#define IMGFORMAT_INTERNAL_H


typedef enum {
	IM_ERROR   = -1,
	IM_UNKNOWN =  0,
	IM_XPM     =  1,
	IM_TIFF    =  2,
	IM_PNG     =  3,
	IM_PPM     =  4,
	IM_JPEG    =  5,
	IM_GIF     =  6,
	IM_WEBP    =  7
} WRImgFormat;

/* How many image types we have. */
/* Increase this when adding new image types! */
#define IM_TYPES    7

/*
 * Function for Loading in a specific format
 */
RImage *RLoadPPM(const char *file);

RImage *RLoadXPM(RContext *context, const char *file);

#ifdef USE_TIFF
RImage *RLoadTIFF(const char *file, int index);
#endif

#ifdef USE_PNG
RImage *RLoadPNG(RContext *context, const char *file);
#endif

#ifdef USE_JPEG
RImage *RLoadJPEG(const char *file);
#endif

#ifdef USE_GIF
RImage *RLoadGIF(const char *file, int index);
#endif

#ifdef USE_WEBP
RImage *RLoadWEBP(const char *file);
#endif

#ifdef USE_MAGICK
RImage *RLoadMagick(const char *file_name);

void RReleaseMagick(void);
#endif

/*
 * Function for Saving in a specific format
 */
Bool RSaveXPM(RImage *image, const char *file);


/*
 * Function to terminate properly
 */
void RReleaseCache(void);


#endif
