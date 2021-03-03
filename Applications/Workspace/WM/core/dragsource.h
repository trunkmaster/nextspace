/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
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

#ifndef __WORKSPACE_WM_WDRAGSOURCE__
#define __WORKSPACE_WM_WDRAGSOURCE__

void WMSetViewDragImage(WMView* view, WMPixmap *dragImage);

void WMReleaseViewDragImage(WMView* view);

void WMSetViewDragSourceProcs(WMView *view, WMDragSourceProcs *procs);

Bool WMIsDraggingFromView(WMView *view);

void WMDragImageFromView(WMView *view, XEvent *event);

/* Create a drag handler, associating drag event masks with dragEventProc */
void WMCreateDragHandler(WMView *view, WMEventProc *dragEventProc, void *clientData);

void WMDeleteDragHandler(WMView *view, WMEventProc *dragEventProc, void *clientData);

/* set default drag handler for view */
void WMSetViewDraggable(WMView *view, WMDragSourceProcs *procs, WMPixmap *dragImage);

void WMUnsetViewDraggable(WMView *view);

#endif /* __WORKSPACE_WM_WDRAGSOURCE__ */
