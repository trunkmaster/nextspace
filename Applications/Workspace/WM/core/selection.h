/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
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

#ifndef __WORKSPACE_WM_WSELECTION__
#define __WORKSPACE_WM_WSELECTION__

typedef void WMSelectionCallback(WMView *view, Atom selection, Atom target,
                                 Time timestamp, void *cdata, WMData *data);

Bool WMCreateSelectionHandler(WMView *view, Atom selection, Time timestamp,
                              WMSelectionProcs *procs, void *cdata);

void WMDeleteSelectionHandler(WMView *view, Atom selection, Time timestamp);

Bool WMRequestSelection(WMView *view, Atom selection, Atom target,
                        Time timestamp, WMSelectionCallback *callback,
                        void *cdata);

void W_HandleSelectionEvent(XEvent *event);

#endif /* __WORKSPACE_WM_WSELECTION__ */
