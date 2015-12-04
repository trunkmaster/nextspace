/* event.c - WindowMaker event handler
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

#include <stdlib.h>
#include <stdio.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include "WMaker.h"
#include "app.h"
#include "menu.h"

static Atom _XA_WINDOWMAKER_MENU = 0;

enum {
	wmSelectItem = 1
};

static wmMenuEntry *findEntry(WMMenu * menu, int tag)
{
	wmMenuEntry *entry = menu->first;

	while (entry) {
		if (entry->tag == tag) {
			return entry;
		}
		if (entry->cascade) {
			wmMenuEntry *tmp;
			tmp = findEntry(entry->cascade, tag);
			if (tmp)
				return tmp;
		}
		entry = entry->next;
	}
	return NULL;
}

static void wmHandleMenuEvents(WMAppContext * app, XEvent * event)
{
	wmMenuEntry *entry;

	switch (event->xclient.data.l[1]) {
	case wmSelectItem:
		entry = findEntry(app->main_menu, event->xclient.data.l[2]);
		if (entry && entry->callback) {
			(*entry->callback) (entry->clientData, event->xclient.data.l[2], event->xclient.data.l[0]);
		}
		break;
	}
}

int WMProcessEvent(WMAppContext * app, XEvent * event)
{
	int proc = False;
	if (!_XA_WINDOWMAKER_MENU) {
		_XA_WINDOWMAKER_MENU = XInternAtom(app->dpy, "_WINDOWMAKER_MENU", False);
	}
	switch (event->type) {
	case ClientMessage:
		if (event->xclient.format == 32
		    && event->xclient.message_type == _XA_WINDOWMAKER_MENU
		    && event->xclient.window == app->main_window) {
			wmHandleMenuEvents(app, event);
			proc = True;
		}
	}
	return proc;
}
