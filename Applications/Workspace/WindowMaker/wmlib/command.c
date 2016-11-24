/* command.c - WindowMaker commands
 *
 * WMlib - WindowMaker application programming interface
 *
 * Copyright (C) 1997-2003 Alfredo K. Kojima
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

#include <X11/Xlib.h>
#include <stdlib.h>

#include "WMaker.h"
#include "app.h"

static Atom getwmfunc(Display * dpy)
{
	return XInternAtom(dpy, "_WINDOWMAKER_WM_FUNCTION", False);
}

void WMHideApplication(WMAppContext * app)
{
	XEvent event;

	event.xclient.type = ClientMessage;
	event.xclient.message_type = getwmfunc(app->dpy);
	event.xclient.format = 32;
	event.xclient.display = app->dpy;
	event.xclient.window = app->main_window;
	event.xclient.data.l[0] = WMFHideApplication;
	event.xclient.data.l[1] = 0;
	event.xclient.data.l[2] = 0;
	event.xclient.data.l[3] = 0;
	XSendEvent(app->dpy, RootWindow(app->dpy, app->screen_number), False,
		   SubstructureNotifyMask | SubstructureRedirectMask, &event);
}

void WMHideOthers(WMAppContext * app)
{
	XEvent event;

	event.xclient.type = ClientMessage;
	event.xclient.message_type = getwmfunc(app->dpy);
	event.xclient.format = 32;
	event.xclient.display = app->dpy;
	event.xclient.window = app->main_window;
	event.xclient.data.l[0] = WMFHideOtherApplications;
	event.xclient.data.l[1] = 0;
	event.xclient.data.l[2] = 0;
	event.xclient.data.l[3] = 0;
	XSendEvent(app->dpy, RootWindow(app->dpy, app->screen_number), False,
		   SubstructureNotifyMask | SubstructureRedirectMask, &event);
}

void WMSetWindowAttributes(Display * dpy, Window window, GNUstepWMAttributes * attributes)
{
	Atom atom;

	atom = XInternAtom(dpy, "_GNUSTEP_WM_ATTR", False);
	XChangeProperty(dpy, window, atom, atom, 32, PropModeReplace,
			(unsigned char *)attributes, sizeof(GNUstepWMAttributes) / sizeof(CARD32));
}
