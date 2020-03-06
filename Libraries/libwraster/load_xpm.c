/* xpm.c - load XPM image from file using libXpm
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

#include <X11/Xlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <X11/xpm.h>

#include "wraster.h"
#include "imgformat.h"

static RImage *create_rimage_from_xpm(RContext *context, XpmImage xpm)
{
	Display *dpy = context->dpy;
	Colormap cmap = context->cmap;
	RImage *image;
	unsigned char *color_table[4];
	unsigned char *data;
	int i;
	int *p;

	if (xpm.height < 1 || xpm.width < 1) {
		RErrorCode = RERR_BADIMAGEFILE;
		return NULL;
	}

	if (xpm.colorTable == NULL) {
		RErrorCode = RERR_BADIMAGEFILE;
		return NULL;
	}
	image = RCreateImage(xpm.width, xpm.height, True);
	if (!image)
		return NULL;

	/* make color table */
	for (i = 0; i < 4; i++) {
		color_table[i] = malloc(xpm.ncolors * sizeof(unsigned char));
		if (!color_table[i]) {
			for (i = i - 1; i >= 0; i--) {
				if (color_table[i])
					free(color_table[i]);
			}
			RReleaseImage(image);
			RErrorCode = RERR_NOMEMORY;
			return NULL;
		}
	}

	for (i = 0; i < xpm.ncolors; i++) {
		XColor xcolor;
		char *color = NULL;

		if (xpm.colorTable[i].c_color)
			color = xpm.colorTable[i].c_color;
		else if (xpm.colorTable[i].g_color)
			color = xpm.colorTable[i].g_color;
		else if (xpm.colorTable[i].g4_color)
			color = xpm.colorTable[i].g4_color;
		else if (xpm.colorTable[i].m_color)
			color = xpm.colorTable[i].m_color;
		else if (xpm.colorTable[i].symbolic)
			color = xpm.colorTable[i].symbolic;

		if (!color) {
			color_table[0][i] = 0xbe;
			color_table[1][i] = 0xbe;
			color_table[2][i] = 0xbe;
			color_table[3][i] = 0xff;
			continue;
		}

		if (strncmp(color, "None", 4) == 0) {
			color_table[0][i] = 0;
			color_table[1][i] = 0;
			color_table[2][i] = 0;
			color_table[3][i] = 0;
			continue;
		}
		if (XParseColor(dpy, cmap, color, &xcolor)) {
			color_table[0][i] = xcolor.red >> 8;
			color_table[1][i] = xcolor.green >> 8;
			color_table[2][i] = xcolor.blue >> 8;
			color_table[3][i] = 0xff;
		} else {
			color_table[0][i] = 0xbe;
			color_table[1][i] = 0xbe;
			color_table[2][i] = 0xbe;
			color_table[3][i] = 0xff;
		}
	}
	/* convert pixmap to RImage */
	p = (int *)xpm.data;
	data = image->data;
	for (i = 0; i < xpm.width * xpm.height; i++, p++) {
		*(data++) = color_table[0][*p];
		*(data++) = color_table[1][*p];
		*(data++) = color_table[2][*p];
		*(data++) = color_table[3][*p];
	}
	for (i = 0; i < 4; i++)
		free(color_table[i]);
	return image;
}

static int is_xpm_error(int status)
{
	if (status == XpmSuccess)
		return 0;

	switch (status) {
	case XpmOpenFailed:
		RErrorCode = RERR_OPEN;
		break;
	case XpmFileInvalid:
		RErrorCode = RERR_BADIMAGEFILE;
		break;
	case XpmNoMemory:
		RErrorCode = RERR_NOMEMORY;
		break;
	default:
		RErrorCode = RERR_BADIMAGEFILE;
		break;
	}
	return 1;
}

RImage *RGetImageFromXPMData(RContext *context, char **xpmData)
{
	RImage *image;
	XpmImage xpm;
	int status;

	status = XpmCreateXpmImageFromData(xpmData, &xpm, (XpmInfo *) NULL);
	if (is_xpm_error(status))
		return NULL;

	image = create_rimage_from_xpm(context, xpm);
	XpmFreeXpmImage(&xpm);
	return image;
}

RImage *RLoadXPM(RContext *context, const char *file)
{
	RImage *image;
	XpmImage xpm;
	int status;

	status = XpmReadFileToXpmImage((char *)file, &xpm, (XpmInfo *) NULL);
	if (is_xpm_error(status))
		return NULL;

	image = create_rimage_from_xpm(context, xpm);
	XpmFreeXpmImage(&xpm);
	return image;
}
