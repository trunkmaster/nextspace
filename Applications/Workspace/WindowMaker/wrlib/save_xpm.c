/* nxpm.c - load "normalized" XPM image
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

#include <config.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <errno.h>

#include "wraster.h"
#include "imgformat.h"

/*
 * Restricted support for XPM images.
 *
 * The images must be in the following "normalized" format:
 *
 *
 * line   	content
 * 1	        signature comment
 * 2		ignored ( normally "static char *xpm[] = {" )
 * 3		"width height color_count chars" where chars is 1 or 2
 * 4	        color definitions. Only c values with #rrggbb or #rrrrggggbbb
 *			format OR None
 * n		data
 *
 * - no comments or blank lines are allowed, except for the signature
 * - all lines must have at most 256 characters
 * - no white spaces allowed at left of each line
 */

typedef struct XPMColor {
	unsigned char red;
	unsigned char green;
	unsigned char blue;
	int index;
	struct XPMColor *next;
} XPMColor;

#define I2CHAR(i)	((i)<12 ? (i)+'0' : ((i)<38 ? (i)+'A'-12 : (i)+'a'-38))
#define CINDEX(xpmc)	(((unsigned)(xpmc)->red)<<16|((unsigned)(xpmc)->green)<<8|((unsigned)(xpmc)->blue))

static XPMColor *lookfor(XPMColor * list, int index)
{
	if (!list)
		return NULL;

	for (; list != NULL; list = list->next) {
		if (CINDEX(list) == index)
			return list;
	}
	return NULL;
}

/*
 * Looks for the color in the colormap and inserts if it is not found.
 *
 * list is a binary search list. The unbalancing problem is just ignored.
 *
 * Returns False on error
 */
static Bool addcolor(XPMColor ** list, unsigned r, unsigned g, unsigned b, int *colors)
{
	XPMColor *tmpc;
	XPMColor *newc;
	int index;

	index = r << 16 | g << 8 | b;

	tmpc = lookfor(*list, index);

	if (tmpc)
		return True;

	newc = malloc(sizeof(XPMColor));

	if (!newc) {

		RErrorCode = RERR_NOMEMORY;

		return False;
	}

	newc->red = r;
	newc->green = g;
	newc->blue = b;
	newc->next = *list;
	*list = newc;

	(*colors)++;

	return True;
}

static char *index2str(char *buffer, int index, int charsPerPixel)
{
	int i;

	for (i = 0; i < charsPerPixel; i++) {
		buffer[i] = I2CHAR(index & 63);
		index >>= 6;
	}
	buffer[i] = 0;

	return buffer;
}

static void outputcolormap(FILE * file, XPMColor * colormap, int charsPerPixel)
{
	int index;
	char buf[128];

	if (!colormap)
		return;

	for (index = 0; colormap != NULL; colormap = colormap->next, index++) {
		colormap->index = index;
		fprintf(file, "\"%s c #%02x%02x%02x\",\n",
			index2str(buf, index, charsPerPixel), colormap->red, colormap->green, colormap->blue);
	}
}

static void freecolormap(XPMColor * colormap)
{
	XPMColor *tmp;

	while (colormap) {
		tmp = colormap->next;
		free(colormap);
		colormap = tmp;
	}
}

/* save routine is common to internal support and library support */
Bool RSaveXPM(RImage * image, const char *filename)
{
	FILE *file;
	int x, y;
	int colorCount = 0;
	int charsPerPixel;
	XPMColor *colormap = NULL;
	XPMColor *tmpc;
	int i;
	int ok = 0;
	unsigned char *r, *g, *b, *a;
	char transp[16];
	char buf[128];

	file = fopen(filename, "wb+");
	if (!file) {
		RErrorCode = RERR_OPEN;
		return False;
	}

	fprintf(file, "/* XPM */\n");

	fprintf(file, "static char *image[] = {\n");

	r = image->data;
	g = image->data + 1;
	b = image->data + 2;
	if (image->format == RRGBAFormat)
		a = image->data + 3;
	else
		a = NULL;

	/* first pass: make colormap for the image */
	if (a)
		colorCount = 1;
	for (y = 0; y < image->height; y++) {
		for (x = 0; x < image->width; x++) {
			if (!a || *a > 127) {
				if (!addcolor(&colormap, *r, *g, *b, &colorCount)) {
					goto uhoh;
				}
			}
			if (a) {
				r += 4;
				g += 4;
				b += 4;
				a += 4;
			} else {
				r += 3;
				g += 3;
				b += 3;
			}
		}
	}

	charsPerPixel = 1;
	while ((1 << charsPerPixel * 6) < colorCount)
		charsPerPixel++;

	/* write header info */
	fprintf(file, "\"%i %i %i %i\",\n", image->width, image->height, colorCount, charsPerPixel);

	/* write colormap data */
	if (a) {
		for (i = 0; i < charsPerPixel; i++)
			transp[i] = ' ';
		transp[i] = 0;

		fprintf(file, "\"%s c None\",\n", transp);
	}

	outputcolormap(file, colormap, charsPerPixel);

	r = image->data;
	g = image->data + 1;
	b = image->data + 2;
	if (image->format == RRGBAFormat)
		a = image->data + 3;
	else
		a = NULL;

	/* write data */
	for (y = 0; y < image->height; y++) {

		fprintf(file, "\"");

		for (x = 0; x < image->width; x++) {

			if (!a || *a > 127) {
				tmpc = lookfor(colormap, (unsigned)*r << 16 | (unsigned)*g << 8 | (unsigned)*b);

				fprintf(file, "%s", index2str(buf, tmpc->index, charsPerPixel));
			} else {
				fprintf(file, "%s", transp);
			}

			if (a) {
				r += 4;
				g += 4;
				b += 4;
				a += 4;
			} else {
				r += 3;
				g += 3;
				b += 3;
			}
		}

		if (y < image->height - 1)
			fprintf(file, "\",\n");
		else
			fprintf(file, "\"};\n");
	}

	ok = 1;
 uhoh:
	errno = 0;
	fclose(file);
	if (ok && errno == ENOSPC) {
		RErrorCode = RERR_WRITE;
	}

	freecolormap(colormap);

	return ok ? True : False;
}
