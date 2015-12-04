/*
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

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <stdlib.h>
#include <string.h>

#include "WindowMaker.h"
#include "wcore.h"


/*----------------------------------------------------------------------
 * wCoreCreateTopLevel--
 * 	Creates a toplevel window used for icons, menus and dialogs.
 *
 * Returns:
 * 	The created window.
 *--------------------------------------------------------------------- */
WCoreWindow *wCoreCreateTopLevel(WScreen *screen, int x, int y, int width, int height, int bwidth, int depth, Visual *visual, Colormap colormap, WMPixel border_pixel)
{
	WCoreWindow *core;
	int vmask;
	XSetWindowAttributes attribs;

	core = wmalloc(sizeof(WCoreWindow));

	vmask = CWBorderPixel | CWCursor | CWEventMask | CWOverrideRedirect | CWColormap;
	attribs.override_redirect = True;
	attribs.cursor = wPreferences.cursor[WCUR_NORMAL];
	attribs.background_pixmap = None;
	attribs.background_pixel = screen->black_pixel;
	attribs.border_pixel = border_pixel;
	attribs.event_mask = SubstructureRedirectMask | ButtonPressMask |
			     ButtonReleaseMask | ButtonMotionMask |
			     ExposureMask | EnterWindowMask | LeaveWindowMask;

	attribs.colormap = colormap;

	if (wPreferences.use_saveunders) {
		vmask |= CWSaveUnder;
		attribs.save_under = True;
	}

	core->window = XCreateWindow(dpy, screen->root_win, x, y, width, height,
				     bwidth, depth, CopyFromParent, visual, vmask, &attribs);
	core->width = width;
	core->height = height;
	core->screen_ptr = screen;
	core->descriptor.self = core;

	XClearWindow(dpy, core->window);
	XSaveContext(dpy, core->window, w_global.context.client_win, (XPointer) & core->descriptor);

	return core;
}

/*----------------------------------------------------------------------
 * wCoreCreate--
 * 	Creates a brand new child window.
 * 	The window will have a border width of 0 and color is black.
 *
 * Returns:
 * 	A initialized core window structure.
 *
 * Side effects:
 * 	A window context for the created window is saved.
 *
 * Notes:
 * 	The event mask is initialized to a default value.
 *--------------------------------------------------------------------- */
WCoreWindow *wCoreCreate(WCoreWindow *parent, int x, int y, int width, int height)
{
	WCoreWindow *core;
	int vmask;
	XSetWindowAttributes attribs;

	core = wmalloc(sizeof(WCoreWindow));

	vmask = CWBorderPixel | CWCursor | CWEventMask | CWColormap;
	attribs.cursor = wPreferences.cursor[WCUR_NORMAL];
	attribs.background_pixmap = None;
	attribs.background_pixel = parent->screen_ptr->black_pixel;
	attribs.event_mask = KeyPressMask | KeyReleaseMask | ButtonPressMask |
			     ButtonReleaseMask | ButtonMotionMask |
			     ExposureMask | EnterWindowMask | LeaveWindowMask;
	attribs.colormap = parent->screen_ptr->w_colormap;
	core->window = XCreateWindow(dpy, parent->window, x, y, width, height, 0,
			  parent->screen_ptr->w_depth, CopyFromParent,
			  parent->screen_ptr->w_visual, vmask, &attribs);

	core->width = width;
	core->height = height;
	core->screen_ptr = parent->screen_ptr;
	core->descriptor.self = core;

	XSaveContext(dpy, core->window, w_global.context.client_win, (XPointer) & core->descriptor);
	return core;
}

void wCoreDestroy(WCoreWindow * core)
{
	if (core->stacking)
		wfree(core->stacking);

	XDeleteContext(dpy, core->window, w_global.context.client_win);
	XDestroyWindow(dpy, core->window);
	wfree(core);
}

void wCoreConfigure(WCoreWindow * core, int req_x, int req_y, int req_w, int req_h)
{
	XWindowChanges xwc;
	unsigned int mask;

	mask = CWX | CWY;
	xwc.x = req_x;
	xwc.y = req_y;

	if (req_w <= 0)
		req_w = core->width;

	if (req_h <= 0)
		req_h = core->height;

	if (req_w != core->width || req_h != core->height) {
		mask |= CWWidth | CWHeight;
		xwc.width = req_w;
		xwc.height = req_h;
		core->width = req_w;
		core->height = req_h;
	}
	XConfigureWindow(dpy, core->window, mask, &xwc);
}
