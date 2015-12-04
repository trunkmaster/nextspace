/* draw.c - pixel plotting, line drawing
 *
 * Raster graphics library
 *
 * Copyright (c) 1998-2003 Dan Pascu
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

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "wraster.h"

#define MIN(a,b)	((a) < (b) ? (a) : (b))
#define MAX(a,b)	((a) > (b) ? (a) : (b))

/*
 * Returns the color of the pixel at coordinates (x, y) in "color".
 */
Bool RGetPixel(RImage * image, int x, int y, RColor * color)
{
	int ofs;

	assert(image != NULL);
	if (x < 0 || x >= image->width || y < 0 || y >= image->height)
		return False;

	if (image->format == RRGBAFormat) {
		ofs = (y * image->width + x) * 4;
		color->red = image->data[ofs++];
		color->green = image->data[ofs++];
		color->blue = image->data[ofs++];
		color->alpha = image->data[ofs];
	} else {
		ofs = (y * image->width + x) * 3;
		color->red = image->data[ofs++];
		color->green = image->data[ofs++];
		color->blue = image->data[ofs];
		/* If the image does not have alpha channel, we consider alpha 255 */
		color->alpha = 255;
	}

	return True;
}

void RPutPixel(RImage *image, int x, int y, const RColor *color)
{
	unsigned char *ptr;

	assert(image != NULL);
	assert(color != NULL);
	if (x < 0 || x >= image->width || y < 0 || y >= image->height)
		return;

	if (image->format == RRGBAFormat) {
		ptr = image->data + (y * image->width + x) * 4;
	} else {
		ptr = image->data + (y * image->width + x) * 3;
	}

	if (color->alpha == 255) {
		*ptr++ = color->red;
		*ptr++ = color->green;
		*ptr++ = color->blue;
		if (image->format == RRGBAFormat) {
			*ptr = 255;
		}
	} else {
		register int alpha, nalpha, r, g, b;

		r = color->red;
		g = color->green;
		b = color->blue;
		alpha = color->alpha;
		nalpha = 255 - alpha;

		*ptr = (((int)*ptr * nalpha) + (r * alpha)) / 256;
		ptr++;
		*ptr = (((int)*ptr * nalpha) + (g * alpha)) / 256;
		ptr++;
		*ptr = (((int)*ptr * nalpha) + (b * alpha)) / 256;
		ptr++;
		if (image->format == RRGBAFormat) {
			*ptr = alpha + ((int)*ptr * nalpha) / 256;
		}
	}
}

static void operatePixel(RImage *image, int ofs, RPixelOperation operation, const RColor *color)
{
	unsigned char *sr, *sg, *sb, *sa;
	register int alpha, nalpha, tmp;
	int hasAlpha = image->format == RRGBAFormat;

	alpha = color->alpha;
	nalpha = 255 - alpha;

	sr = image->data + ofs * (hasAlpha ? 4 : 3);
	sg = image->data + ofs * (hasAlpha ? 4 : 3) + 1;
	sb = image->data + ofs * (hasAlpha ? 4 : 3) + 2;
	sa = image->data + ofs * (hasAlpha ? 4 : 3) + 3;

	switch (operation) {
	case RClearOperation:
		*sr = 0;
		*sg = 0;
		*sb = 0;
		if (hasAlpha)
			*sa = 0;
		break;
	case RCopyOperation:
		*sr = color->red;
		*sg = color->green;
		*sb = color->blue;
		if (hasAlpha)
			*sa = color->alpha;
		break;
	case RNormalOperation:
		if (color->alpha == 255) {
			*sr = color->red;
			*sg = color->green;
			*sb = color->blue;
			if (hasAlpha)
				*sa = 255;
		} else {
			*sr = (((int)*sr * nalpha) + ((int)color->red * alpha)) / 256;
			*sg = (((int)*sg * nalpha) + ((int)color->green * alpha)) / 256;
			*sb = (((int)*sb * nalpha) + ((int)color->blue * alpha)) / 256;
			*sa = alpha + ((int)*sa * nalpha) / 256;
		}
		break;
	case RAddOperation:
		tmp = color->red + *sr;
		*sr = MIN(255, tmp);
		tmp = color->green + *sg;
		*sg = MIN(255, tmp);
		tmp = color->blue + *sb;
		*sb = MIN(255, tmp);
		if (hasAlpha)
			*sa = MIN(*sa, color->alpha);
		break;
	case RSubtractOperation:
		tmp = *sr - color->red;
		*sr = MAX(0, tmp);
		tmp = *sg - color->green;
		*sg = MAX(0, tmp);
		tmp = *sb - color->blue;
		*sb = MAX(0, tmp);
		if (hasAlpha)
			*sa = MIN(*sa, color->alpha);
		break;
	}
}

void ROperatePixel(RImage *image, RPixelOperation operation, int x, int y, const RColor *color)
{
	int ofs;

	assert(image != NULL);
	assert(color != NULL);
	assert(x >= 0 && x < image->width);
	assert(y >= 0 && y < image->height);

	ofs = y * image->width + x;

	operatePixel(image, ofs, operation, color);
}

void RPutPixels(RImage *image, const RPoint *points, int npoints, RCoordinatesMode mode, const RColor *color)
{
	register int x, y, i;

	assert(image != NULL);
	assert(points != NULL);

	x = y = 0;

	for (i = 0; i < npoints; i++) {
		if (mode == RAbsoluteCoordinates) {
			x = points[i].x;
			y = points[i].y;
		} else {
			x += points[i].x;
			y += points[i].y;
		}
		RPutPixel(image, x, y, color);
	}
}

void ROperatePixels(RImage *image, RPixelOperation operation,
                    const RPoint *points, int npoints, RCoordinatesMode mode,
                    const RColor *color)
{
	register int x, y, i;

	assert(image != NULL);
	assert(points != NULL);

	x = y = 0;

	for (i = 0; i < npoints; i++) {
		if (mode == RAbsoluteCoordinates) {
			x = points[i].x;
			y = points[i].y;
		} else {
			x += points[i].x;
			y += points[i].y;
		}
		ROperatePixel(image, operation, x, y, color);
	}
}

static Bool clipLineInRectangle(int xmin, int ymin, int xmax, int ymax, int *x1, int *y1, int *x2, int *y2)
{
#define TOP	(1<<0)
#define BOT	(1<<1)
#define LEF	(1<<2)
#define RIG	(1<<3)
#define CHECK_OUT(X,Y)	(((Y) > ymax ? TOP : ((Y) < ymin ? BOT : 0))\
    | ((X) > xmax ? RIG : ((X) < xmin ? LEF : 0)))

	int ocode1, ocode2, ocode;
	int accept = 0;
	int x, y;

	ocode1 = CHECK_OUT(*x1, *y1);
	ocode2 = CHECK_OUT(*x2, *y2);

	for (;;) {
		if (!ocode1 && !ocode2) {	/* completely inside */
			accept = 1;
			break;
		} else if (ocode1 & ocode2) {
			break;
		}

		if (ocode1)
			ocode = ocode1;
		else
			ocode = ocode2;

		if (ocode & TOP) {
			x = *x1 + (*x2 - *x1) * (ymax - *y1) / (*y2 - *y1);
			y = ymax;
		} else if (ocode & BOT) {
			x = *x1 + (*x2 - *x1) * (ymin - *y1) / (*y2 - *y1);
			y = ymin;
		} else if (ocode & RIG) {
			y = *y1 + (*y2 - *y1) * (xmax - *x1) / (*x2 - *x1);
			x = xmax;
		} else {	/* //if (ocode & LEF) { */
			y = *y1 + (*y2 - *y1) * (xmax - *x1) / (*x2 - *x1);
			x = xmin;
		}

		if (ocode == ocode1) {
			*x1 = x;
			*y1 = y;
			ocode1 = CHECK_OUT(x, y);
		} else {
			*x2 = x;
			*y2 = y;
			ocode2 = CHECK_OUT(x, y);
		}
	}

	return accept;
}

/*
 * This routine is a generic drawing routine, based on Bresenham's line
 * drawing algorithm.
 */
static int genericLine(RImage *image, int x0, int y0, int x1, int y1, const RColor *color,
                       RPixelOperation operation, int polyline)
{
	int i, err, du, dv, du2, dv2, uofs, vofs, last;

	assert(image != NULL);

	if (!clipLineInRectangle(0, 0, image->width - 1, image->height - 1, &x0, &y0, &x1, &y1))
		return True;

	if (x0 < x1) {
		du = x1 - x0;
		uofs = 1;
	} else {
		du = x0 - x1;
		uofs = -1;
	}
	if (y0 < y1) {
		dv = y1 - y0;
		vofs = image->width;
	} else {
		dv = y0 - y1;
		vofs = -image->width;
	}

	if (du < dv) {
		/* Swap coordinates between them, so that always du>dv */
		i = du;
		du = dv;
		dv = i;
		i = uofs;
		uofs = vofs;
		vofs = i;
	}

	err = 0;
	du2 = du << 1;
	dv2 = dv << 1;
	last = (polyline) ? du - 1 : du;

	if (color->alpha == 255 || operation == RCopyOperation) {
		unsigned char *ptr;

		if (image->format == RRGBAFormat)
			i = (y0 * image->width + x0) * 4;
		else
			i = (y0 * image->width + x0) * 3;
		ptr = image->data + i;

		for (i = 0; i <= last; i++) {
			/* Draw the pixel */
			*ptr = color->red;
			*(ptr + 1) = color->green;
			*(ptr + 2) = color->blue;
			if (image->format == RRGBAFormat)
				*(ptr + 3) = 255;

			/* Compute error for NeXT Step */
			err += dv2;
			if (err >= du) {
				if (image->format == RRGBAFormat)
					ptr += vofs * 4;
				else
					ptr += vofs * 3;
				err -= du2;
			}
			if (image->format == RRGBAFormat)
				ptr += uofs * 4;
			else
				ptr += uofs * 3;
		}
	} else {
		register int ofs = y0 * image->width + x0;

		for (i = 0; i <= last; i++) {
			/* Draw the pixel */
			operatePixel(image, ofs, operation, color);

			/* Compute error for NeXT Step */
			err += dv2;
			if (err >= du) {
				ofs += vofs;
				err -= du2;
			}
			ofs += uofs;
		}
	}

	return True;
}

int RDrawLine(RImage * image, int x0, int y0, int x1, int y1, const RColor * color)
{
	return genericLine(image, x0, y0, x1, y1, color, RNormalOperation, False);
}

int ROperateLine(RImage *image, RPixelOperation operation, int x0, int y0, int x1, int y1, const RColor *color)
{
	return genericLine(image, x0, y0, x1, y1, color, operation, False);
}

void RDrawLines(RImage *image, const RPoint *points, int npoints, RCoordinatesMode mode, const RColor *color)
{
	register int x1, y1, x2, y2, i;

	assert(points != NULL);

	if (npoints == 0)
		return;

	x1 = points[0].x;
	y1 = points[0].y;
	x2 = y2 = 0;

	for (i = 1; i < npoints - 1; i++) {
		if (mode == RAbsoluteCoordinates) {
			x2 = points[i].x;
			y2 = points[i].y;
		} else {
			x2 += points[i - 1].x;
			y2 += points[i - 1].y;
		}
		/* Don't draw pixels at junction points twice */
		genericLine(image, x1, y1, x2, y2, color, RNormalOperation, True);
		x1 = x2;
		y1 = y2;
	}
	i = npoints - 1;	/* last point */
	if (mode == RAbsoluteCoordinates) {
		x2 = points[i].x;
		y2 = points[i].y;
	} else {
		x2 += points[i - 1].x;
		y2 += points[i - 1].y;
	}
	i = (points[0].x == x2 && points[0].y == y2 && npoints > 1);
	genericLine(image, x1, y1, x2, y2, color, RNormalOperation, i);
}

void ROperateLines(RImage *image, RPixelOperation operation,
                   const RPoint *points, int npoints, RCoordinatesMode mode,
                   const RColor *color)
{
	register int x1, y1, x2, y2, i;

	assert(points != NULL);

	if (npoints == 0)
		return;

	x1 = points[0].x;
	y1 = points[0].y;
	x2 = y2 = 0;

	for (i = 1; i < npoints - 1; i++) {
		if (mode == RAbsoluteCoordinates) {
			x2 = points[i].x;
			y2 = points[i].y;
		} else {
			x2 += points[i - 1].x;
			y2 += points[i - 1].y;
		}
		/* Don't draw pixels at junction points twice */
		genericLine(image, x1, y1, x2, y2, color, operation, True);
		x1 = x2;
		y1 = y2;
	}
	i = npoints - 1;	/* last point */
	if (mode == RAbsoluteCoordinates) {
		x2 = points[i].x;
		y2 = points[i].y;
	} else {
		x2 += points[i - 1].x;
		y2 += points[i - 1].y;
	}
	i = (points[0].x == x2 && points[0].y == y2 && npoints > 1);
	genericLine(image, x1, y1, x2, y2, color, operation, i);
}

void ROperateRectangle(RImage *image, RPixelOperation operation, int x0, int y0, int x1, int y1, const RColor *color)
{
	int y;

	for (y = y0; y <= y1; y++) {
		genericLine(image, x0, y, x1, y, color, operation, False);
	}
}

void RDrawSegments(RImage *image, const RSegment *segs, int nsegs, const RColor *color)
{
	register int i;

	assert(segs != NULL);

	for (i = 0; i < nsegs; i++) {
		genericLine(image, segs->x1, segs->y1, segs->x2, segs->y2, color, RNormalOperation, False);
		segs++;
	}
}

void ROperateSegments(RImage *image, RPixelOperation operation, const RSegment *segs, int nsegs, const RColor *color)
{
	register int i;

	assert(segs != NULL);

	for (i = 0; i < nsegs; i++) {
		genericLine(image, segs->x1, segs->y1, segs->x2, segs->y2, color, operation, False);
		segs++;
	}
}
