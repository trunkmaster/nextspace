/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2014 Window Maker Team
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
 *  with this program; if not, write to the Free Software Foundation
 */

/* Many part of code are ripped of an example from JX's site */

#include "config.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <X11/Xlib.h>
#include <X11/Xatom.h>

#include "WindowMaker.h"
#include "dock.h"
#include "xdnd.h"
#include "workspace.h"


static Atom _XA_XdndAware;
static Atom _XA_XdndEnter;
static Atom _XA_XdndLeave;
static Atom _XA_XdndDrop;
static Atom _XA_XdndPosition;
static Atom _XA_XdndStatus;
static Atom _XA_XdndActionCopy;
static Atom _XA_XdndSelection;
static Atom _XA_XdndFinished;
static Atom _XA_XdndTypeList;
static Atom _XA_WINDOWMAKER_XDNDEXCHANGE;
static Atom supported_typelist;
static Atom selected_typelist;

void wXDNDInitializeAtoms(void)
{
	_XA_XdndAware = XInternAtom(dpy, "XdndAware", False);
	_XA_XdndEnter = XInternAtom(dpy, "XdndEnter", False);
	_XA_XdndLeave = XInternAtom(dpy, "XdndLeave", False);
	_XA_XdndDrop = XInternAtom(dpy, "XdndDrop", False);
	_XA_XdndPosition = XInternAtom(dpy, "XdndPosition", False);
	_XA_XdndStatus = XInternAtom(dpy, "XdndStatus", False);
	_XA_XdndActionCopy = XInternAtom(dpy, "XdndActionCopy", False);
	_XA_XdndSelection = XInternAtom(dpy, "XdndSelection", False);
	_XA_XdndFinished = XInternAtom(dpy, "XdndFinished", False);
	_XA_XdndTypeList = XInternAtom(dpy, "XdndTypeList", False);
	_XA_WINDOWMAKER_XDNDEXCHANGE = XInternAtom(dpy, "_WINDOWMAKER_XDNDEXCHANGE", False);

	supported_typelist = XInternAtom(dpy, "text/uri-list", False);
}

void wXDNDMakeAwareness(Window window)
{
	long int xdnd_version = XDND_VERSION;
	XChangeProperty(dpy, window, _XA_XdndAware, XA_ATOM, 32,
					PropModeAppend, (unsigned char *)&xdnd_version, 1);
}

static void wXDNDDecodeURI(char *uri)
{
	char *last = uri + strlen(uri);
	while (uri < last-2) {
		if (*uri == '%') {
			int h;
			if (sscanf(uri+1, "%2X", &h) != 1)
				break;
			*uri = h;
			memmove(uri+1, uri+3, last - (uri+2));
			last -= 2;
		}
		uri++;
	}
}

Bool wXDNDProcessSelection(XEvent *event)
{
	WScreen *scr = wScreenForWindow(event->xselection.requestor);
	char *retain;
	Atom ret_type;
	int ret_format;
	unsigned long ret_item;
	unsigned long remain_byte;
	char *delme;
	XEvent xevent;
	Window selowner = XGetSelectionOwner(dpy, _XA_XdndSelection);

	XGetWindowProperty(dpy, event->xselection.requestor,
			   _XA_WINDOWMAKER_XDNDEXCHANGE,
			   0, 65536, True, selected_typelist, &ret_type, &ret_format,
			   &ret_item, &remain_byte, (unsigned char **)&delme);

	/*send finished */
	memset(&xevent, 0, sizeof(xevent));
	xevent.xany.type = ClientMessage;
	xevent.xany.display = dpy;
	xevent.xclient.window = selowner;
	xevent.xclient.message_type = _XA_XdndFinished;
	xevent.xclient.format = 32;
	XDND_FINISHED_TARGET_WIN(&xevent) = event->xselection.requestor;
	XSendEvent(dpy, selowner, 0, 0, &xevent);

	/*process dropping */
	if (delme) {
		WMArray *items;
		WMArrayIterator iter;
		int length, str_size;
		int total_size = 0;
		char *tmp;

		scr->xdestring = delme;
		items = WMCreateArray(4);
		retain = wstrdup(scr->xdestring);
		XFree(scr->xdestring);	/* since xdestring was created by Xlib */

		length = strlen(retain);

		/* search in string */
		while (length--) {
			if (retain[length] == '\r') {	/* useless char, nuke it */
				retain[length] = 0;
			}
			if (retain[length] == '\n') {
				str_size = strlen(&retain[length + 1]);
				if (str_size) {
					WMAddToArray(items, wstrdup(&retain[length + 1]));
					total_size += str_size + 3;	/* reserve for " \"\"" */
					/* this is nonsense -- if (length)
					   WMAppendArray(items, WMCreateArray(1)); */
				}
				retain[length] = 0;
			}
		}
		/* final one */
		WMAddToArray(items, wstrdup(retain));
		total_size += strlen(retain) + 3;
		wfree(retain);

		/* now pack new string */
		scr->xdestring = wmalloc(total_size);
		scr->xdestring[0] = 0;	/* empty string */
		WM_ETARETI_ARRAY(items, tmp, iter) {
			/* only supporting file: URI objects */
			if (!strncmp(tmp, "file://", 7)) {
				/* drag-and-drop file name format as per the spec is encoded as an URI */
				wXDNDDecodeURI(&tmp[7]);
				strcat(scr->xdestring, " \"");
				strcat(scr->xdestring, &tmp[7]);
				strcat(scr->xdestring, "\"");
			}
			wfree(tmp);
		}
		WMFreeArray(items);
		if (scr->xdestring[0])
			wDockReceiveDNDDrop(scr, event);
		wfree(scr->xdestring);	/* this xdestring is not from Xlib (no XFree) */
	}

	return True;
}

static Bool isAwareXDND(Window window)
{
	Atom actual;
	int format;
	unsigned long count, remaining;
	unsigned char *data = 0;

	if (!window)
		return False;
	XGetWindowProperty(dpy, window, _XA_XdndAware,
			   0, 0x8000000L, False, XA_ATOM, &actual, &format, &count, &remaining, &data);
	if (actual != XA_ATOM || format != 32 || count == 0 || !data) {
		if (data)
			XFree(data);
		return False;
	}
	if (data)
		XFree(data);
	return True;
}

static Bool acceptXDND(Window window)
{
	WScreen *scr = wScreenForWindow(window);
	WDock *dock;
	int icon_pos, i;

	icon_pos = -1;
	dock = scr->dock;
	if (dock) {
		for (i = 0; i < dock->max_icons; i++) {
			if (dock->icon_array[i]
			    && dock->icon_array[i]->icon->core->window == window) {
				icon_pos = i;
				break;
			}
		}
	}
	if (icon_pos < 0) {
		dock = scr->workspaces[scr->current_workspace]->clip;
		if (dock) {
			for (i = 0; i < dock->max_icons; i++) {
				if (dock->icon_array[i]
				    && dock->icon_array[i]->icon->core->window == window) {
					icon_pos = i;
					break;
				}
			}
		}
	}
	if (icon_pos < 0)
		return False;

	if (isAwareXDND(dock->icon_array[icon_pos]->icon->icon_win))
		return False;

	if (dock->icon_array[icon_pos]->dnd_command != NULL)
		return True;

	return False;
}

static void wXDNDGetTypeList(Display *dpy, Window window)
{
	Atom type, *a;
	Atom *typelist;
	int format, i;
	unsigned long count, remaining;
	unsigned char *data = NULL;

	XGetWindowProperty(dpy, window, _XA_XdndTypeList,
						0, 0x8000000L, False, XA_ATOM,
						&type, &format, &count, &remaining, &data);

	if (type != XA_ATOM || format != 32 || count == 0 || !data) {
		if (data)
			XFree(data);
		wwarning(_("wXDNDGetTypeList failed = %ld"), _XA_XdndTypeList);
		return;
	}

	typelist = malloc((count + 1) * sizeof(Atom));
	a = (Atom *) data;
	for (i = 0; i < count; i++) {
		typelist[i] = a[i];
		if (typelist[i] == supported_typelist) {
			selected_typelist = typelist[i];
			break;
		}
	}
	typelist[count] = 0;
	XFree(data);
	free(typelist);
}

Bool wXDNDProcessClientMessage(XClientMessageEvent *event)
{
	if (event->message_type == _XA_XdndEnter) {

		if (XDND_ENTER_THREE_TYPES(event)) {
			selected_typelist = XDND_ENTER_TYPE(event, 0);
		} else {
			wXDNDGetTypeList(dpy, XDND_ENTER_SOURCE_WIN(event));
			/*
			char *name = XGetAtomName(dpy, selected_typelist);
			fprintf(stderr, "Get %s\n",name);
			XFree(name);
			*/
		}
		return True;
	} else if (event->message_type == _XA_XdndLeave) {
		return True;
	} else if (event->message_type == _XA_XdndDrop) {
		if (XDND_DROP_SOURCE_WIN(event) == XGetSelectionOwner(dpy, _XA_XdndSelection)) {
			XConvertSelection(dpy, _XA_XdndSelection, selected_typelist,
					  _XA_WINDOWMAKER_XDNDEXCHANGE, event->window, CurrentTime);
		}
		return True;
	} else if (event->message_type == _XA_XdndPosition) {
		XEvent xevent;
		Window srcwin = XDND_POSITION_SOURCE_WIN(event);
		if (selected_typelist == supported_typelist) {
			memset(&xevent, 0, sizeof(xevent));
			xevent.xany.type = ClientMessage;
			xevent.xany.display = dpy;
			xevent.xclient.window = srcwin;
			xevent.xclient.message_type = _XA_XdndStatus;
			xevent.xclient.format = 32;

			XDND_STATUS_TARGET_WIN(&xevent) = event->window;
			XDND_STATUS_WILL_ACCEPT_SET(&xevent, acceptXDND(event->window));
			XDND_STATUS_WANT_POSITION_SET(&xevent, True);
			XDND_STATUS_RECT_SET(&xevent, 0, 0, 0, 0);
			XDND_STATUS_ACTION(&xevent) = _XA_XdndActionCopy;

			XSendEvent(dpy, srcwin, 0, 0, &xevent);
		}
		return True;
	}
	return False;
}
