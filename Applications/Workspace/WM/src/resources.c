/* resources.c - manage X resources (colors etc)
 *
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "wconfig.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <wraster.h>

#include "WindowMaker.h"
#include "texture.h"
#include "resources.h"
#include "screen.h"

int wGetColorForColormap(Colormap colormap, const char *color_name, XColor *color)
{
	if (!XParseColor(dpy, colormap, color_name, color)) {
		wwarning(_("could not parse color \"%s\""), color_name);
		return False;
	}
	if (!XAllocColor(dpy, colormap, color)) {
		wwarning(_("could not allocate color \"%s\""), color_name);
		return False;
	}
	return True;
}

int wGetColor(WScreen *scr, const char *color_name, XColor *color)
{
	return wGetColorForColormap(scr->w_colormap, color_name, color);
}

void wFreeColor(WScreen * scr, unsigned long pixel)
{
	if (pixel != scr->white_pixel && pixel != scr->black_pixel) {
		unsigned long colors[1];

		colors[0] = pixel;
		XFreeColors(dpy, scr->w_colormap, colors, 1, 0);
	}
}
