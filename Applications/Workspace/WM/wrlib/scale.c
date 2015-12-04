/* scale.c - image scaling
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
#include <X11/Xlib.h>
#include <math.h>
#include <assert.h>

#include "wraster.h"
#include "scale.h"

/*
 *----------------------------------------------------------------------
 * RScaleImage--
 * 	Creates a scaled copy of an image.
 *
 * Returns:
 * 	The new scaled image.
 *
 *----------------------------------------------------------------------
 */
RImage *RScaleImage(RImage * image, unsigned new_width, unsigned new_height)
{
	int ox;
	int px, py;
	register int x, y, t;
	int dx, dy;
	unsigned char *s;
	unsigned char *d;
	RImage *img;

	if (image == NULL)
		return NULL;

	if (new_width == image->width && new_height == image->height)
		return RCloneImage(image);

	img = RCreateImage(new_width, new_height, image->format == RRGBAFormat);

	if (!img)
		return NULL;

	/* fixed point math idea taken from Imlib by
	 * Carsten Haitzler (Rasterman) */
	dx = (image->width << 16) / new_width;
	dy = (image->height << 16) / new_height;

	py = 0;

	d = img->data;

	if (image->format == RRGBAFormat) {
		for (y = 0; y < new_height; y++) {
			t = image->width * (py >> 16);

			s = image->data + (t << 2);	/* image->data+t*4 */

			ox = 0;
			px = 0;
			for (x = 0; x < new_width; x++) {
				px += dx;

				*(d++) = *(s);
				*(d++) = *(s + 1);
				*(d++) = *(s + 2);
				*(d++) = *(s + 3);

				t = (px - ox) >> 16;
				ox += t << 16;

				s += t << 2;	/* t*4 */
			}
			py += dy;
		}
	} else {
		for (y = 0; y < new_height; y++) {
			t = image->width * (py >> 16);

			s = image->data + (t << 1) + t;	/* image->data+t*3 */

			ox = 0;
			px = 0;
			for (x = 0; x < new_width; x++) {
				px += dx;

				*(d++) = *(s);
				*(d++) = *(s + 1);
				*(d++) = *(s + 2);

				t = (px - ox) >> 16;
				ox += t << 16;

				s += (t << 1) + t;	/* t*3 */
			}
			py += dy;
		}
	}

	return img;
}

/*
 * Filtered Image Rescaling code copy/pasted from
 * Graphics Gems III
 * Public Domain 1991 by Dale Schumacher
 */

/*
 *	filter function definitions
 */
#define	box_support		(0.5)

static double box_filter(double t)
{
	if ((t > -0.5) && (t <= 0.5))
		return (1.0);
	return (0.0);
}

#define	triangle_support	(1.0)

static double triangle_filter(double t)
{
	if (t < 0.0)
		t = -t;
	if (t < 1.0)
		return (1.0 - t);
	return (0.0);
}

#define	bell_support		(1.5)

static double bell_filter(double t)  /* box (*) box (*) box */
{
	if (t < 0)
		t = -t;
	if (t < .5)
		return (.75 - (t * t));
	if (t < 1.5) {
		t = (t - 1.5);
		return (.5 * (t * t));
	}
	return (0.0);
}

#define	B_spline_support	(2.0)

static double B_spline_filter(double t)   /* box (*) box (*) box (*) box */
{
	double tt;

	if (t < 0)
		t = -t;
	if (t < 1) {
		tt = t * t;
		return ((.5 * tt * t) - tt + (2.0 / 3.0));
	} else if (t < 2) {
		t = 2 - t;
		return ((1.0 / 6.0) * (t * t * t));
	}
	return (0.0);
}

static double sinc(double x)
{
	/*
	 * The original code did this:
	 *   if (x != 0) ...
	 * This code is unsafe, it should be:
	 *   if (fabs(x) > EPSILON) ...
	 *
	 * But the call to fabs is already done in the *ONLY* function
	 * that call sinc: 'Lanczos3_filter'
	 *
	 * The goal was to avoid a Divide-by-0 error, now we also
	 * avoid a +/-inf result too
	 */
	x *= WM_PI;
	if (x > 1.0E-9)
		return (sin(x) / x);
	return (1.0);
}

#define	Lanczos3_support	(3.0)

static double Lanczos3_filter(double t)
{
	if (t < 0)
		t = -t;
	if (t < 3.0)
		return (sinc(t) * sinc(t / 3.0));
	return (0.0);
}

#define	Mitchell_support	(2.0)

#define	B	(1.0 / 3.0)
#define	C	(1.0 / 3.0)

static double Mitchell_filter(double t)
{
	double tt;

	tt = t * t;
	if (t < 0)
		t = -t;
	if (t < 1.0) {
		t = (((12.0 - 9.0 * B - 6.0 * C) * (t * tt))
		     + ((-18.0 + 12.0 * B + 6.0 * C) * tt)
		     + (6.0 - 2 * B));
		return (t / 6.0);
	} else if (t < 2.0) {
		t = (((-1.0 * B - 6.0 * C) * (t * tt))
		     + ((6.0 * B + 30.0 * C) * tt)
		     + ((-12.0 * B - 48.0 * C) * t)
		     + (8.0 * B + 24 * C));
		return (t / 6.0);
	}
	return (0.0);
}

static double (*filterf)(double) = Mitchell_filter;
static double fwidth = Mitchell_support;

void wraster_change_filter(RScalingFilter type)
{
	switch (type) {
	case RBoxFilter:
		filterf = box_filter;
		fwidth = box_support;
		break;
	case RTriangleFilter:
		filterf = triangle_filter;
		fwidth = triangle_support;
		break;
	case RBellFilter:
		filterf = bell_filter;
		fwidth = bell_support;
		break;
	case RBSplineFilter:
		filterf = B_spline_filter;
		fwidth = B_spline_support;
		break;
	case RLanczos3Filter:
		filterf = Lanczos3_filter;
		fwidth = Lanczos3_support;
		break;
	default:
	case RMitchellFilter:
		filterf = Mitchell_filter;
		fwidth = Mitchell_support;
		break;
	}
}

/*
 *	image rescaling routine
 */

typedef struct {
	int pixel;
	double weight;
} CONTRIB;

typedef struct {
	int n;			/* number of contributors */
	CONTRIB *p;		/* pointer to list of contributions */
} CLIST;

/* clamp the input to the specified range */
#define CLAMP(v,l,h)    ((v)<(l) ? (l) : (v) > (h) ? (h) : v)

/* return of calloc is not checked if NULL in the function below! */
RImage *RSmoothScaleImage(RImage * src, unsigned new_width, unsigned new_height)
{
	CLIST *contrib;			/* array of contribution lists */
	RImage *tmp;		/* intermediate image */
	double xscale, yscale;	/* zoom scale factors */
	int i, j, k;		/* loop variables */
	int n;			/* pixel number */
	double center, left, right;	/* filter calculation variables */
	double width, fscale;	/* filter calculation variables */
	double rweight, gweight, bweight;
	RImage *dst;
	unsigned char *p;
	unsigned char *sp;
	int sch = src->format == RRGBAFormat ? 4 : 3;

	dst = RCreateImage(new_width, new_height, False);

	/* create intermediate image to hold horizontal zoom */
	tmp = RCreateImage(dst->width, src->height, False);
	xscale = (double)new_width / (double)src->width;
	yscale = (double)new_height / (double)src->height;

	/* pre-calculate filter contributions for a row */
	contrib = (CLIST *) calloc(new_width, sizeof(CLIST));
	if (xscale < 1.0) {
		width = fwidth / xscale;
		fscale = 1.0 / xscale;
		for (i = 0; i < new_width; ++i) {
			contrib[i].n = 0;
			contrib[i].p = (CONTRIB *) calloc((int) ceil(width * 2 + 1), sizeof(CONTRIB));
			center = (double)i / xscale;
			left = ceil(center - width);
			right = floor(center + width);
			for (j = left; j <= right; ++j) {
				rweight = center - (double)j;
				rweight = (*filterf) (rweight / fscale) / fscale;
				if (j < 0) {
					n = -j;
				} else if (j >= src->width) {
					n = (src->width - j) + src->width - 1;
				} else {
					n = j;
				}
				k = contrib[i].n++;
				contrib[i].p[k].pixel = n * sch;
				contrib[i].p[k].weight = rweight;
			}
		}
	} else {

		for (i = 0; i < new_width; ++i) {
			contrib[i].n = 0;
			contrib[i].p = (CONTRIB *) calloc((int) ceil(fwidth * 2 + 1), sizeof(CONTRIB));
			center = (double)i / xscale;
			left = ceil(center - fwidth);
			right = floor(center + fwidth);
			for (j = left; j <= right; ++j) {
				rweight = center - (double)j;
				rweight = (*filterf) (rweight);
				if (j < 0) {
					n = -j;
				} else if (j >= src->width) {
					n = (src->width - j) + src->width - 1;
				} else {
					n = j;
				}
				k = contrib[i].n++;
				contrib[i].p[k].pixel = n * sch;
				contrib[i].p[k].weight = rweight;
			}
		}
	}

	/* apply filter to zoom horizontally from src to tmp */
	p = tmp->data;

	for (k = 0; k < tmp->height; ++k) {
		CONTRIB *pp;

		sp = src->data + src->width * k * sch;

		for (i = 0; i < tmp->width; ++i) {
			rweight = gweight = bweight = 0.0;

			pp = contrib[i].p;

			for (j = 0; j < contrib[i].n; ++j) {
				rweight += sp[pp[j].pixel] * pp[j].weight;
				gweight += sp[pp[j].pixel + 1] * pp[j].weight;
				bweight += sp[pp[j].pixel + 2] * pp[j].weight;
			}
			*p++ = CLAMP(rweight, 0, 255);
			*p++ = CLAMP(gweight, 0, 255);
			*p++ = CLAMP(bweight, 0, 255);
		}
	}

	/* free the memory allocated for horizontal filter weights */
	for (i = 0; i < new_width; ++i) {
		free(contrib[i].p);
	}
	free(contrib);

	/* pre-calculate filter contributions for a column */
	contrib = (CLIST *) calloc(dst->height, sizeof(CLIST));
	if (yscale < 1.0) {
		width = fwidth / yscale;
		fscale = 1.0 / yscale;
		for (i = 0; i < dst->height; ++i) {
			contrib[i].n = 0;
			contrib[i].p = (CONTRIB *) calloc((int) ceil(width * 2 + 1), sizeof(CONTRIB));
			center = (double)i / yscale;
			left = ceil(center - width);
			right = floor(center + width);
			for (j = left; j <= right; ++j) {
				rweight = center - (double)j;
				rweight = (*filterf) (rweight / fscale) / fscale;
				if (j < 0) {
					n = -j;
				} else if (j >= tmp->height) {
					n = (tmp->height - j) + tmp->height - 1;
				} else {
					n = j;
				}
				k = contrib[i].n++;
				contrib[i].p[k].pixel = n * 3;
				contrib[i].p[k].weight = rweight;
			}
		}
	} else {
		for (i = 0; i < dst->height; ++i) {
			contrib[i].n = 0;
			contrib[i].p = (CONTRIB *) calloc((int) ceil(fwidth * 2 + 1), sizeof(CONTRIB));
			center = (double)i / yscale;
			left = ceil(center - fwidth);
			right = floor(center + fwidth);
			for (j = left; j <= right; ++j) {
				rweight = center - (double)j;
				rweight = (*filterf) (rweight);
				if (j < 0) {
					n = -j;
				} else if (j >= tmp->height) {
					n = (tmp->height - j) + tmp->height - 1;
				} else {
					n = j;
				}
				k = contrib[i].n++;
				contrib[i].p[k].pixel = n * 3;
				contrib[i].p[k].weight = rweight;
			}
		}
	}

	/* apply filter to zoom vertically from tmp to dst */
	sp = malloc(tmp->height * 3);

	for (k = 0; k < new_width; ++k) {
		CONTRIB *pp;

		p = dst->data + k * 3;

		/* copy a column into a row */
		{
			int i;
			unsigned char *p, *d;

			d = sp;
			for (i = tmp->height, p = tmp->data + k * 3; i-- > 0; p += tmp->width * 3) {
				*d++ = *p;
				*d++ = *(p + 1);
				*d++ = *(p + 2);
			}
		}
		for (i = 0; i < new_height; ++i) {
			rweight = gweight = bweight = 0.0;

			pp = contrib[i].p;

			for (j = 0; j < contrib[i].n; ++j) {
				rweight += sp[pp[j].pixel] * pp[j].weight;
				gweight += sp[pp[j].pixel + 1] * pp[j].weight;
				bweight += sp[pp[j].pixel + 2] * pp[j].weight;
			}
			*p = CLAMP(rweight, 0, 255);
			*(p + 1) = CLAMP(gweight, 0, 255);
			*(p + 2) = CLAMP(bweight, 0, 255);
			p += new_width * 3;
		}
	}
	free(sp);

	/* free the memory allocated for vertical filter weights */
	for (i = 0; i < dst->height; ++i) {
		free(contrib[i].p);
	}
	free(contrib);

	RReleaseImage(tmp);

	return dst;
}
