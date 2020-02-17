/* color.c - color stuff (rgb -> hsv convertion etc.)
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
#include <X11/Xlib.h>

#include <assert.h>

#include "wraster.h"

#define MIN(a,b)	((a)<(b) ? (a) : (b))
#define MAX(a,b)	((a)>(b) ? (a) : (b))

#define MIN3(a,b,c)	MIN(MIN(a,b), c)
#define MAX3(a,b,c)	MAX(MAX(a,b), c)

void RHSVtoRGB(const RHSVColor * hsv, RColor * rgb)
{
	int h = hsv->hue % 360;
	int s = hsv->saturation;
	int v = hsv->value;
	int i, f;
	int p, q, t;

	if (s == 0) {
		rgb->red = rgb->green = rgb->blue = v;
		return;
	}
	i = h / 60;
	f = h % 60;
	p = v * (255 - s) / 255;
	q = v * (255 - s * f / 60) / 255;
	t = v * (255 - s * (60 - f) / 60) / 255;

	switch (i) {
	case 0:
		rgb->red = v;
		rgb->green = t;
		rgb->blue = p;
		break;
	case 1:
		rgb->red = q;
		rgb->green = v;
		rgb->blue = p;
		break;
	case 2:
		rgb->red = p;
		rgb->green = v;
		rgb->blue = t;
		break;
	case 3:
		rgb->red = p;
		rgb->green = q;
		rgb->blue = v;
		break;
	case 4:
		rgb->red = t;
		rgb->green = p;
		rgb->blue = v;
		break;
	case 5:
		rgb->red = v;
		rgb->green = p;
		rgb->blue = q;
		break;
	}
}

void RRGBtoHSV(const RColor * rgb, RHSVColor * hsv)
{
	int h, s, v;
	int max = MAX3(rgb->red, rgb->green, rgb->blue);
	int min = MIN3(rgb->red, rgb->green, rgb->blue);

	v = max;

	if (max == 0)
		s = 0;
	else
		s = (max - min) * 255 / max;

	if (s == 0)
		h = 0;
	else {
		int rc, gc, bc;

		rc = (max - rgb->red) * 255 / (max - min);
		gc = (max - rgb->green) * 255 / (max - min);
		bc = (max - rgb->blue) * 255 / (max - min);

		if (rgb->red == max) {
			h = ((bc - gc) * 60 / 255);
		} else if (rgb->green == max) {
			h = 2 * 60 + ((rc - bc) * 60 / 255);
		} else {
			h = 4 * 60 + ((gc - rc) * 60 / 255);
		}
		if (h < 0)
			h += 360;
	}

	hsv->hue = h;
	hsv->saturation = s;
	hsv->value = v;
}
