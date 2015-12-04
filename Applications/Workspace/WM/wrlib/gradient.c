/* gradient.c - renders gradients
 *
 * Raster graphics library
 *
 * Copyright (c) 1997-2003 Alfredo K. Kojima
 * Copyright (c) 1998-2003 Dan Pascu
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

#include "wraster.h"

static RImage *renderHGradient(unsigned width, unsigned height, int r0, int g0, int b0, int rf, int gf, int bf);
static RImage *renderVGradient(unsigned width, unsigned height, int r0, int g0, int b0, int rf, int gf, int bf);
static RImage *renderDGradient(unsigned width, unsigned height, int r0, int g0, int b0, int rf, int gf, int bf);

static RImage *renderMHGradient(unsigned width, unsigned height, RColor ** colors, int count);
static RImage *renderMVGradient(unsigned width, unsigned height, RColor ** colors, int count);
static RImage *renderMDGradient(unsigned width, unsigned height, RColor ** colors, int count);

RImage *RRenderMultiGradient(unsigned width, unsigned height, RColor **colors, RGradientStyle style)
{
	int count;

	count = 0;
	while (colors[count] != NULL)
		count++;

	if (count > 2) {
		switch (style) {
		case RHorizontalGradient:
			return renderMHGradient(width, height, colors, count);
		case RVerticalGradient:
			return renderMVGradient(width, height, colors, count);
		case RDiagonalGradient:
			return renderMDGradient(width, height, colors, count);
		}
	} else if (count > 1) {
		return RRenderGradient(width, height, colors[0], colors[1], style);
	} else if (count > 0) {
		return RRenderGradient(width, height, colors[0], colors[0], style);
	}
	assert(0);
	return NULL;
}

RImage *RRenderGradient(unsigned width, unsigned height, const RColor *from, const RColor *to, RGradientStyle style)
{
	switch (style) {
	case RHorizontalGradient:
		return renderHGradient(width, height, from->red, from->green,
				       from->blue, to->red, to->green, to->blue);
	case RVerticalGradient:
		return renderVGradient(width, height, from->red, from->green,
				       from->blue, to->red, to->green, to->blue);

	case RDiagonalGradient:
		return renderDGradient(width, height, from->red, from->green,
				       from->blue, to->red, to->green, to->blue);
	}
	assert(0);
	return NULL;
}

/*
 *----------------------------------------------------------------------
 * renderHGradient--
 * 	Renders a horizontal linear gradient of the specified size in the
 * RImage format with a border of the specified type.
 *
 * Returns:
 * 	A 24bit RImage with the gradient (no alpha channel).
 *
 * Side effects:
 * 	None
 *----------------------------------------------------------------------
 */
static RImage *renderHGradient(unsigned width, unsigned height, int r0, int g0, int b0, int rf, int gf, int bf)
{
	int i;
	long r, g, b, dr, dg, db;
	unsigned lineSize = width * 3;
	RImage *image;
	unsigned char *ptr;

	image = RCreateImage(width, height, False);
	if (!image) {
		return NULL;
	}
	ptr = image->data;

	r = r0 << 16;
	g = g0 << 16;
	b = b0 << 16;

	dr = ((rf - r0) << 16) / (int)width;
	dg = ((gf - g0) << 16) / (int)width;
	db = ((bf - b0) << 16) / (int)width;
	/* render the first line */
	for (i = 0; i < width; i++) {
		*(ptr++) = (unsigned char)(r >> 16);
		*(ptr++) = (unsigned char)(g >> 16);
		*(ptr++) = (unsigned char)(b >> 16);
		r += dr;
		g += dg;
		b += db;
	}

	/* copy the first line to the other lines */
	for (i = 1; i < height; i++) {
		memcpy(&(image->data[i * lineSize]), image->data, lineSize);
	}
	return image;
}

static inline unsigned char *renderGradientWidth(unsigned char *ptr, unsigned width, unsigned char r, unsigned char g, unsigned char b)
{
	int i;

	for (i = width / 4; i--;) {
		*ptr++ = r;
		*ptr++ = g;
		*ptr++ = b;

		*ptr++ = r;
		*ptr++ = g;
		*ptr++ = b;

		*ptr++ = r;
		*ptr++ = g;
		*ptr++ = b;

		*ptr++ = r;
		*ptr++ = g;
		*ptr++ = b;
	}
	switch (width % 4) {
	case 3:
		*ptr++ = r;
		*ptr++ = g;
		*ptr++ = b;
	case 2:
		*ptr++ = r;
		*ptr++ = g;
		*ptr++ = b;
	case 1:
		*ptr++ = r;
		*ptr++ = g;
		*ptr++ = b;
	}
	return ptr;
}

/*
 *----------------------------------------------------------------------
 * renderVGradient--
 *      Renders a vertical linear gradient of the specified size in the
 * RImage format with a border of the specified type.
 *
 * Returns:
 *      A 24bit RImage with the gradient (no alpha channel).
 *
 * Side effects:
 *      None
 *----------------------------------------------------------------------
 */
static RImage *renderVGradient(unsigned width, unsigned height, int r0, int g0, int b0, int rf, int gf, int bf)
{
	int i;
	long r, g, b, dr, dg, db;
	RImage *image;
	unsigned char *ptr;

	image = RCreateImage(width, height, False);
	if (!image) {
		return NULL;
	}
	ptr = image->data;

	r = r0 << 16;
	g = g0 << 16;
	b = b0 << 16;

	dr = ((rf - r0) << 16) / (int)height;
	dg = ((gf - g0) << 16) / (int)height;
	db = ((bf - b0) << 16) / (int)height;

	for (i = 0; i < height; i++) {
		ptr = renderGradientWidth(ptr, width, r >> 16, g >> 16, b >> 16);
		r += dr;
		g += dg;
		b += db;
	}
	return image;
}

/*
 *----------------------------------------------------------------------
 * renderDGradient--
 *      Renders a diagonal linear gradient of the specified size in the
 * RImage format with a border of the specified type.
 *
 * Returns:
 *      A 24bit RImage with the gradient (no alpha channel).
 *
 * Side effects:
 *      None
 *----------------------------------------------------------------------
 */

static RImage *renderDGradient(unsigned width, unsigned height, int r0, int g0, int b0, int rf, int gf, int bf)
{
	RImage *image, *tmp;
	int j;
	float a, offset;
	unsigned char *ptr;

	if (width == 1)
		return renderVGradient(width, height, r0, g0, b0, rf, gf, bf);
	else if (height == 1)
		return renderHGradient(width, height, r0, g0, b0, rf, gf, bf);

	image = RCreateImage(width, height, False);
	if (!image) {
		return NULL;
	}

	tmp = renderHGradient(2 * width - 1, 1, r0, g0, b0, rf, gf, bf);
	if (!tmp) {
		RReleaseImage(image);
		return NULL;
	}

	ptr = tmp->data;

	a = ((float)(width - 1)) / ((float)(height - 1));
	width = width * 3;

	/* copy the first line to the other lines with corresponding offset */
	for (j = 0, offset = 0.0; j < width * height; j += width) {
		memcpy(&(image->data[j]), &ptr[3 * (int)offset], width);
		offset += a;
	}

	RReleaseImage(tmp);
	return image;
}

static RImage *renderMHGradient(unsigned width, unsigned height, RColor ** colors, int count)
{
	int i, j, k;
	long r, g, b, dr, dg, db;
	unsigned lineSize = width * 3;
	RImage *image;
	unsigned char *ptr;
	unsigned width2;

	assert(count > 2);

	image = RCreateImage(width, height, False);
	if (!image) {
		return NULL;
	}
	ptr = image->data;

	if (count > width)
		count = width;

	if (count > 1)
		width2 = width / (count - 1);
	else
		width2 = width;

	k = 0;

	r = colors[0]->red << 16;
	g = colors[0]->green << 16;
	b = colors[0]->blue << 16;

	/* render the first line */
	for (i = 1; i < count; i++) {
		dr = ((int)(colors[i]->red - colors[i - 1]->red) << 16) / (int)width2;
		dg = ((int)(colors[i]->green - colors[i - 1]->green) << 16) / (int)width2;
		db = ((int)(colors[i]->blue - colors[i - 1]->blue) << 16) / (int)width2;
		for (j = 0; j < width2; j++) {
			*ptr++ = (unsigned char)(r >> 16);
			*ptr++ = (unsigned char)(g >> 16);
			*ptr++ = (unsigned char)(b >> 16);
			r += dr;
			g += dg;
			b += db;
			k++;
		}
		r = colors[i]->red << 16;
		g = colors[i]->green << 16;
		b = colors[i]->blue << 16;
	}
	for (j = k; j < width; j++) {
		*ptr++ = (unsigned char)(r >> 16);
		*ptr++ = (unsigned char)(g >> 16);
		*ptr++ = (unsigned char)(b >> 16);
	}

	/* copy the first line to the other lines */
	for (i = 1; i < height; i++) {
		memcpy(&(image->data[i * lineSize]), image->data, lineSize);
	}
	return image;
}

static RImage *renderMVGradient(unsigned width, unsigned height, RColor ** colors, int count)
{
	int i, j, k;
	long r, g, b, dr, dg, db;
	unsigned lineSize = width * 3;
	RImage *image;
	unsigned char *ptr, *tmp;
	unsigned height2;

	assert(count > 2);

	image = RCreateImage(width, height, False);
	if (!image) {
		return NULL;
	}
	ptr = image->data;

	if (count > height)
		count = height;

	if (count > 1)
		height2 = height / (count - 1);
	else
		height2 = height;

	k = 0;

	r = colors[0]->red << 16;
	g = colors[0]->green << 16;
	b = colors[0]->blue << 16;

	for (i = 1; i < count; i++) {
		dr = ((int)(colors[i]->red - colors[i - 1]->red) << 16) / (int)height2;
		dg = ((int)(colors[i]->green - colors[i - 1]->green) << 16) / (int)height2;
		db = ((int)(colors[i]->blue - colors[i - 1]->blue) << 16) / (int)height2;

		for (j = 0; j < height2; j++) {
			ptr = renderGradientWidth(ptr, width, r >> 16, g >> 16, b >> 16);
			r += dr;
			g += dg;
			b += db;
			k++;
		}
		r = colors[i]->red << 16;
		g = colors[i]->green << 16;
		b = colors[i]->blue << 16;
	}

	if (k < height) {
		tmp = ptr;
		ptr = renderGradientWidth(ptr, width, r >> 16, g >> 16, b >> 16);
		for (j = k + 1; j < height; j++) {
			memcpy(ptr, tmp, lineSize);
			ptr += lineSize;
		}
	}

	return image;
}

static RImage *renderMDGradient(unsigned width, unsigned height, RColor ** colors, int count)
{
	RImage *image, *tmp;
	float a, offset;
	int j;
	unsigned char *ptr;

	assert(count > 2);

	if (width == 1)
		return renderMVGradient(width, height, colors, count);
	else if (height == 1)
		return renderMHGradient(width, height, colors, count);

	image = RCreateImage(width, height, False);
	if (!image) {
		return NULL;
	}

	if (count > width)
		count = width;
	if (count > height)
		count = height;

	if (count > 2)
		tmp = renderMHGradient(2 * width - 1, 1, colors, count);
	else
		tmp = renderHGradient(2 * width - 1, 1, colors[0]->red << 8,
				      colors[0]->green << 8, colors[0]->blue << 8,
				      colors[1]->red << 8, colors[1]->green << 8, colors[1]->blue << 8);

	if (!tmp) {
		RReleaseImage(image);
		return NULL;
	}
	ptr = tmp->data;

	a = ((float)(width - 1)) / ((float)(height - 1));
	width = width * 3;

	/* copy the first line to the other lines with corresponding offset */
	for (j = 0, offset = 0; j < width * height; j += width) {
		memcpy(&(image->data[j]), &ptr[3 * (int)offset], width);
		offset += a;
	}
	RReleaseImage(tmp);
	return image;
}

RImage *RRenderInterwovenGradient(unsigned width, unsigned height,
				  RColor colors1[2], int thickness1, RColor colors2[2], int thickness2)
{
	int i, k, l, ll;
	long r1, g1, b1, dr1, dg1, db1;
	long r2, g2, b2, dr2, dg2, db2;
	RImage *image;
	unsigned char *ptr;

	image = RCreateImage(width, height, False);
	if (!image) {
		return NULL;
	}
	ptr = image->data;

	r1 = colors1[0].red << 16;
	g1 = colors1[0].green << 16;
	b1 = colors1[0].blue << 16;

	r2 = colors2[0].red << 16;
	g2 = colors2[0].green << 16;
	b2 = colors2[0].blue << 16;

	dr1 = ((colors1[1].red - colors1[0].red) << 16) / (int)height;
	dg1 = ((colors1[1].green - colors1[0].green) << 16) / (int)height;
	db1 = ((colors1[1].blue - colors1[0].blue) << 16) / (int)height;

	dr2 = ((colors2[1].red - colors2[0].red) << 16) / (int)height;
	dg2 = ((colors2[1].green - colors2[0].green) << 16) / (int)height;
	db2 = ((colors2[1].blue - colors2[0].blue) << 16) / (int)height;

	for (i = 0, k = 0, l = 0, ll = thickness1; i < height; i++) {
		if (k == 0)
			ptr = renderGradientWidth(ptr, width, r1 >> 16, g1 >> 16, b1 >> 16);
		else
			ptr = renderGradientWidth(ptr, width, r2 >> 16, g2 >> 16, b2 >> 16);

		if (++l == ll) {
			if (k == 0) {
				k = 1;
				ll = thickness2;
			} else {
				k = 0;
				ll = thickness1;
			}
			l = 0;
		}
		r1 += dr1;
		g1 += dg1;
		b1 += db1;

		r2 += dr2;
		g2 += dg2;
		b2 += db2;
	}
	return image;
}
