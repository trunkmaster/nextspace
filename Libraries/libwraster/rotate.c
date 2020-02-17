/* rotate.c - image rotation
 *
 * Raster graphics library
 *
 * Copyright (c) 2000-2003 Alfredo K. Kojima
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

#include <X11/Xlib.h>

#include "wraster.h"
#include "rotate.h"

#include <math.h>


static RImage *rotate_image_90(RImage *source);
static RImage *rotate_image_270(RImage *source);
static RImage *rotate_image_any(RImage *source, float angle);


RImage *RRotateImage(RImage *image, float angle)
{
	/*
	 * Angle steps below this value would represent a rotation
	 * of less than 1 pixel for a 4k wide image, so not worth
	 * bothering the difference. That makes it a perfect
	 * candidate for an Epsilon when trying to compare angle
	 * to known values
	 */
	static const float min_usable_angle = 0.00699F;

	angle = fmod(angle, 360.0);
	if (angle < 0.0F)
		angle += 360.0F;

	if (angle < min_usable_angle) {
		/* Rotate by 0 degree */
		return RCloneImage(image);

	} else if ((angle > 90.0F - min_usable_angle) &&
				  (angle < 90.0F + min_usable_angle)) {
		return rotate_image_90(image);

	} else if ((angle > 180.0F - min_usable_angle) &&
				  (angle < 180.0F + min_usable_angle)) {
		return wraster_rotate_image_180(image);

	} else if ((angle > 270.0F - min_usable_angle) &&
				  (angle < 270.0F + min_usable_angle)) {
		return rotate_image_270(image);

	} else {
		return rotate_image_any(image, angle);
	}
}

static RImage *rotate_image_90(RImage *source)
{
	RImage *target;
	int nwidth, nheight;
	int x, y;

	nwidth = source->height;
	nheight = source->width;

	target = RCreateImage(nwidth, nheight, (source->format != RRGBFormat));
	if (!target)
		return NULL;

	if (source->format == RRGBFormat) {
		unsigned char *optr, *nptr;

		optr = source->data;
		for (x = nwidth; x; x--) {
			nptr = target->data + 3 * (x - 1);
			for (y = nheight; y; y--) {
				nptr[0] = *optr++;
				nptr[1] = *optr++;
				nptr[2] = *optr++;

				nptr += 3 * nwidth;
			}
		}

	} else {
		unsigned char *optr, *nptr;

		optr = source->data;
		for (x = nwidth; x; x--) {
			nptr = target->data + 4 * (x - 1);
			for (y = nheight; y; y--) {
				nptr[0] = *optr++;
				nptr[1] = *optr++;
				nptr[2] = *optr++;
				nptr[3] = *optr++;

				nptr += 4 * nwidth;
			}
		}
	}

	return target;
}

RImage *wraster_rotate_image_180(RImage *source)
{
	RImage *target;
	int nwidth, nheight;
	int x, y;

	nwidth = source->width;
	nheight = source->height;

	target = RCreateImage(nwidth, nheight, (source->format != RRGBFormat));
	if (!target)
		return NULL;

	if (source->format == RRGBFormat) {
		unsigned char *optr, *nptr;

		optr = source->data;
		nptr = target->data + nwidth * nheight * 3 - 3;

		for (y = 0; y < nheight; y++) {
			for (x = 0; x < nwidth; x++) {
				nptr[0] = optr[0];
				nptr[1] = optr[1];
				nptr[2] = optr[2];

				optr += 3;
				nptr -= 3;
			}
		}

	} else {
		unsigned char *optr, *nptr;

		optr = source->data;
		nptr = target->data + nwidth * nheight * 4 - 4;

		for (y = nheight * nwidth - 1; y >= 0; y--) {
			nptr[0] = optr[0];
			nptr[1] = optr[1];
			nptr[2] = optr[2];
			nptr[3] = optr[3];

			optr += 4;
			nptr -= 4;
		}
	}

	return target;
}

static RImage *rotate_image_270(RImage *source)
{
	RImage *target;
	int nwidth, nheight;
	int x, y;

	nwidth = source->height;
	nheight = source->width;

	target = RCreateImage(nwidth, nheight, (source->format != RRGBFormat));
	if (!target)
		return NULL;

	if (source->format == RRGBFormat) {
		unsigned char *optr, *nptr;

		optr = source->data;
		for (x = nwidth; x; x--) {
			nptr = target->data + 3 * nwidth * nheight - x * 3;
			for (y = nheight; y; y--) {
				nptr[0] = *optr++;
				nptr[1] = *optr++;
				nptr[2] = *optr++;

				nptr -= 3 * nwidth;
			}
		}

	} else {
		unsigned char *optr, *nptr;

		optr = source->data;
		for (x = nwidth; x; x--) {
			nptr = target->data + 4 * nwidth * nheight - x * 4;
			for (y = nheight; y; y--) {
				nptr[0] = *optr++;
				nptr[1] = *optr++;
				nptr[2] = *optr++;
				nptr[3] = *optr++;

				nptr -= 4 * nwidth;
			}
		}
	}

	return target;
}

/*
 * Image rotation through Bresenham's line algorithm:
 *
 * If a square must be rotate by angle a, like in:
 *  _______
 * |    B  |
 * |   /4\ |
 * |  /3 8\|
 * | /2 7 /|
 * |A1 6 / |      A_______B
 * | \5 / a| <--- |1 2 3 4|
 * |__C/_)_|      |5 6 7 8|
 *                C-------
 *
 * for each point P1 in the line from C to A
 *	for each point P2 in the perpendicular line starting at P1
 *		get pixel from the source and plot at P2
 *		increment pixel location from source
 *
 */

#if 0
static void
copyLine(int x1, int y1, int x2, int y2, int nwidth, int format, unsigned char *dst, unsigned char **src)
{
	unsigned char *s = *src;
	int dx, dy;
	int xi, yi;
	int offset;
	int dpr, dpru, p;

	dx = abs(x2 - x1);
	dy = abs(y2 - y1);

	if (x1 > x2)
		xi = -1;
	else
		xi = 1;
	if (y1 > y2)
		yi = -1;
	else
		yi = 1;

	if (dx >= dy) {

		dpr = dy << 1;
		dpru = dpr - (dx << 1);
		p = dpr - dx;

		while (dx-- >= 0) {
			/* fetch and draw the pixel */
			offset = (x1 + y1 * nwidth) << 2;
			dst[offset++] = *s++;
			dst[offset++] = *s++;
			dst[offset++] = *s++;
			if (format == RRGBAFormat)
				dst[offset++] = *s++;
			else
				dst[offset++] = 255;

			/* calc next step */
			if (p > 0) {
				x1 += xi;
				y1 += yi;
				p += dpru;
			} else {
				x1 += xi;
				p += dpr;
			}
		}
	} else {

		dpr = dx << 1;
		dpru = dpr - (dy << 1);
		p = dpr - dy;

		while (dy-- >= 0) {
			/* fetch and draw the pixel */
			offset = (x1 + y1 * nwidth) << 2;
			dst[offset++] = *s++;
			dst[offset++] = *s++;
			dst[offset++] = *s++;
			if (format == RRGBAFormat)
				dst[offset++] = *s++;
			else
				dst[offset++] = 255;

			/* calc next step */
			if (p > 0) {
				x1 += xi;
				y1 += yi;
				p += dpru;
			} else {
				y1 += yi;
				p += dpr;
			}
		}
	}

	*src = s;
}
#endif

static RImage *rotate_image_any(RImage *source, float angle)
{
	(void) angle;
	puts("NOT FULLY IMPLEMENTED");
	return RCloneImage(source);
#if 0
	RImage *img;
	int nwidth, nheight;
	int x1, y1;
	int x2, y2;
	int dx, dy;
	int xi, yi;
	int xx, yy;
	unsigned char *src, *dst;
	int dpr, dpru, p;

	/* only 180o for now */
	if (angle > 180.0F)
		angle -= 180.0F;

	angle = (angle * WM_PI) / 180.0;

	nwidth = ceil(abs(cos(angle) * image->width))
	    + ceil(abs(cos(WM_PI / 2 - angle) * image->width));

	nheight = ceil(abs(sin(angle) * image->height))
	    + ceil(abs(cos(WM_PI / 2 - angle) * image->height));

	img = RCreateImage(nwidth, nheight, True);
	if (!img)
		return NULL;

	src = image->data;
	dst = img->data;

	x1 = floor(abs(cos(WM_PI / 2 - angle) * image->width));
	y1 = 0;

	x2 = 0;
	y2 = floor(abs(sin(WM_PI / 2 - angle) * image->width));

	xx = floor(abs(cos(angle) * image->height)) - 1;
	yy = nheight - 1;

	printf("%ix%i, %i %i     %i %i %i\n", nwidth, nheight, x1, y1, x2, y2, (int)((angle * 180.0) / WM_PI));

	dx = abs(x2 - x1);
	dy = abs(y2 - y1);

	if (x1 > x2)
		xi = -1;
	else
		xi = 1;
	if (y1 > y2)
		yi = -1;
	else
		yi = 1;

	if (dx >= dy) {
		dpr = dy << 1;
		dpru = dpr - (dx << 1);
		p = dpr - dx;

		while (dx-- >= 0) {

			copyLine(x1, y1, xx, yy, nwidth, image->format, dst, &src);

			/* calc next step */

			if (p > 0) {
				x1 += xi;
				y1 += yi;
				xx += xi;
				yy += yi;
				p += dpru;
			} else {
				x1 += xi;
				xx += xi;
				p += dpr;
			}
		}
	} else {
		dpr = dx << 1;
		dpru = dpr - (dy << 1);
		p = dpr - dy;

		while (dy-- >= 0) {
			xx = abs(x1 * sin(angle * WM_PI / 180.0));
			yy = abs(y1 * cos(angle * WM_PI / 180.0));

			copyLine(x1, y1, xx, yy, nwidth, image->format, dst, &src);

			/* calc next step */
			if (p > 0) {
				x1 += xi;
				y1 += yi;
				p += dpru;
			} else {
				y1 += yi;
				p += dpr;
			}
		}
	}

	return img;
#endif
}
