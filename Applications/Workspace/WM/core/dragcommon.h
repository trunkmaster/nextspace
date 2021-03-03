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

#ifndef __WORKSPACE_WM_WDRAGCOMMON__
#define __WORKSPACE_WM_WDRAGCOMMON__

#include <CoreFoundation/CFArray.h>
#include <core/wdata.h>
#include <core/drawing.h>

/* drag operations */
typedef enum {
  WDOperationNone = 0,
  WDOperationCopy,
  WDOperationMove,
  WDOperationLink,
  WDOperationAsk,
  WDOperationPrivate
} WMDragOperationType;

typedef struct WMSelectionProcs {
  WMData* (*convertSelection)(WMView *view, Atom selection, Atom target,
                              void *cdata, Atom *type);
  void (*selectionLost)(WMView *view, Atom selection, void *cdata);
  void (*selectionDone)(WMView *view, Atom selection, Atom target,
                        void *cdata);
} WMSelectionProcs;

/* We need to define these structure first because they are used in WMScreen
 * below. The rest of drag-related stuff if after because it needs WMScreen
 */
#ifndef XDND_VERSION
#define XDND_VERSION 3L
#endif

typedef struct WMDraggingInfo {
  unsigned char protocolVersion; /* version supported on the other side */
  Time timestamp;
  
  Atom sourceAction;
  Atom destinationAction;
  
  struct WMDragSourceInfo      *sourceInfo; /* infos needed by source */
  struct WMDragDestinationInfo *destInfo;   /* infos needed by destination */
} WMDraggingInfo;

typedef struct WMDragSourceProcs {
  CFMutableArrayRef (*dropDataTypes)(WMView *self);
  WMDragOperationType (*wantedDropOperation)(WMView *self);
  CFMutableArrayRef (*askedOperations)(WMView *self);
  Bool (*acceptDropOperation)(WMView *self, WMDragOperationType operation);
  void (*beganDrag)(WMView *self, WMPoint *point);
  void (*endedDrag)(WMView *self, WMPoint *point, Bool deposited);
  WMData* (*fetchDragData)(WMView *self, char *type);
  /*Bool (*ignoreModifierKeysWhileDragging)(WMView *view);*/
} WMDragSourceProcs;
  
typedef struct WMDragDestinationProcs {
  void (*prepareForDragOperation)(WMView *self);
  CFMutableArrayRef (*requiredDataTypes)(WMView *self, WMDragOperationType request,
                                         CFMutableArrayRef sourceDataTypes);
  WMDragOperationType (*allowedOperation)(WMView *self,
                                          WMDragOperationType request,
                                          CFMutableArrayRef sourceDataTypes);
  Bool (*inspectDropData)(WMView *self, CFMutableArrayRef dropData);
  void (*performDragOperation)(WMView *self, CFMutableArrayRef dropData,
                               CFMutableArrayRef operations, WMPoint *dropLocation);
  void (*concludeDragOperation)(WMView *self);
} WMDragDestinationProcs;

/* links a label to a dnd operation. */
typedef struct WMDragOperationItem {
  WMDragOperationType type;
  char* text;
} WMDragOperationItem;

typedef void* WMDndState(WMView *destView, XClientMessageEvent *event,
                         WMDraggingInfo *info);

typedef struct WMDragSourceInfo {
  WMView *sourceView;
  Window destinationWindow;
  WMDndState *state;
  WMSelectionProcs *selectionProcs;
  Window icon;
  WMPoint imageLocation;
  WMPoint mouseOffset; /* mouse pos in icon */
  Cursor dragCursor;
  WMRect noPositionMessageZone;
  Atom firstThreeTypes[3];
} WMDragSourceInfo;

typedef struct WMDragDestinationInfo {
  WMView *destView;
  WMView *xdndAwareView;
  Window sourceWindow;
  WMDndState *state;
  Bool sourceActionChanged;
  CFMutableArrayRef sourceTypes;
  CFMutableArrayRef requiredTypes;
  Bool typeListAvailable;
  CFMutableArrayRef dropDatas;
} WMDragDestinationInfo;

/* -- Functions -- */

void WMHandleDNDClientMessage(WMView *toplevel, XClientMessageEvent *event);

Atom WMOperationToAction(WMScreen *scr, WMDragOperationType operation);

WMDragOperationType WMActionToOperation(WMScreen *scr, Atom action);

void WMFreeDragOperationItem(void* item);

Bool WMSendDnDClientMessage(Display *dpy, Window win, Atom message,
                            unsigned long data1, unsigned long data2,
                            unsigned long data3, unsigned long data4,
                            unsigned long data5);

void WMDragSourceStartTimer(WMDraggingInfo *info);

void WMDragSourceStopTimer(void);

void WMDragSourceStateHandler(WMDraggingInfo *info, XClientMessageEvent *event);

void WMDragDestinationStartTimer(WMDraggingInfo *info);

void WMDragDestinationStopTimer(void);

void WMDragDestinationStoreEnterMsgInfo(WMDraggingInfo *info, WMView *toplevel,
                                        XClientMessageEvent *event);

void WMDragDestinationStorePositionMsgInfo(WMDraggingInfo *info,
                                           WMView *toplevel,
                                           XClientMessageEvent *event);

void WMDragDestinationCancelDropOnEnter(WMView *toplevel, WMDraggingInfo *info);

void WMDragDestinationStateHandler(WMDraggingInfo *info,
                                   XClientMessageEvent *event);

void WMDragDestinationInfoClear(WMDraggingInfo *info);

void WMFreeViewXdndPart(WMView *view);

CFMutableArrayRef WMCreateDragOperationArray(int initialSize);

WMDragOperationItem* WMCreateDragOperationItem(WMDragOperationType type,
                                               char* text);

WMDragOperationType WMGetDragOperationItemType(WMDragOperationItem* item);

char* WMGetDragOperationItemText(WMDragOperationItem* item);

#endif /* __WORKSPACE_WM_WDRAGCOMMON__ */
