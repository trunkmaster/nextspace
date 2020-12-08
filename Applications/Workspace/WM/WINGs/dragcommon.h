#ifndef __WORKSPACE_WM_WDRAGCOMMON__
#define __WORKSPACE_WM_WDRAGCOMMON__

#include <CoreFoundation/CFArray.h>
#include <WMcore/data.h>

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

/* We need to define these structure first because they are used in W_Screen
 * below. The rest of drag-related stuff if after because it needs W_Screen
 */
#ifndef XDND_VERSION
#define XDND_VERSION 3L
#endif

typedef struct W_DraggingInfo {
  unsigned char protocolVersion; /* version supported on the other side */
  Time timestamp;

  Atom sourceAction;
  Atom destinationAction;

  struct W_DragSourceInfo *sourceInfo;    /* infos needed by source */
  struct W_DragDestinationInfo *destInfo; /* infos needed by destination */
} W_DraggingInfo;

typedef struct W_DraggingInfo WMDraggingInfo;

/* links a label to a dnd operation. */
typedef struct W_DragOperationtItem WMDragOperationItem;

typedef struct W_DragSourceProcs {
  CFMutableArrayRef (*dropDataTypes)(WMView *self);
  WMDragOperationType (*wantedDropOperation)(WMView *self);
  CFMutableArrayRef (*askedOperations)(WMView *self);
  Bool (*acceptDropOperation)(WMView *self, WMDragOperationType operation);
  void (*beganDrag)(WMView *self, WMPoint *point);
  void (*endedDrag)(WMView *self, WMPoint *point, Bool deposited);
  WMData* (*fetchDragData)(WMView *self, char *type);
  /*Bool (*ignoreModifierKeysWhileDragging)(WMView *view);*/
} WMDragSourceProcs;
  
typedef struct W_DragDestinationProcs {
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

typedef struct W_DragOperationItem {
  WMDragOperationType type;
  char* text;
} W_DragOperationItem;

typedef void* W_DndState(WMView *destView, XClientMessageEvent *event,
                         WMDraggingInfo *info);

typedef struct W_DragSourceInfo {
  WMView *sourceView;
  Window destinationWindow;
  W_DndState *state;
  WMSelectionProcs *selectionProcs;
  Window icon;
  WMPoint imageLocation;
  WMPoint mouseOffset; /* mouse pos in icon */
  Cursor dragCursor;
  WMRect noPositionMessageZone;
  Atom firstThreeTypes[3];
} W_DragSourceInfo;

typedef struct W_DragDestinationInfo {
  WMView *destView;
  WMView *xdndAwareView;
  Window sourceWindow;
  W_DndState *state;
  Bool sourceActionChanged;
  CFMutableArrayRef sourceTypes;
  CFMutableArrayRef requiredTypes;
  Bool typeListAvailable;
  CFMutableArrayRef dropDatas;
} W_DragDestinationInfo;

/* -- Functions -- */

void W_HandleDNDClientMessage(WMView *toplevel, XClientMessageEvent *event);

Atom W_OperationToAction(WMScreen *scr, WMDragOperationType operation);

WMDragOperationType W_ActionToOperation(WMScreen *scr, Atom action);

void W_FreeDragOperationItem(void* item);

Bool W_SendDnDClientMessage(Display *dpy, Window win, Atom message,
                            unsigned long data1, unsigned long data2,
                            unsigned long data3, unsigned long data4,
                            unsigned long data5);

void W_DragSourceStartTimer(WMDraggingInfo *info);

void W_DragSourceStopTimer(void);

void W_DragSourceStateHandler(WMDraggingInfo *info, XClientMessageEvent *event);

void W_DragDestinationStartTimer(WMDraggingInfo *info);

void W_DragDestinationStopTimer(void);

void W_DragDestinationStoreEnterMsgInfo(WMDraggingInfo *info, WMView *toplevel,
                                        XClientMessageEvent *event);

void W_DragDestinationStorePositionMsgInfo(WMDraggingInfo *info,
                                           WMView *toplevel,
                                           XClientMessageEvent *event);

void W_DragDestinationCancelDropOnEnter(WMView *toplevel, WMDraggingInfo *info);

void W_DragDestinationStateHandler(WMDraggingInfo *info,
                                   XClientMessageEvent *event);

void W_DragDestinationInfoClear(WMDraggingInfo *info);

void W_FreeViewXdndPart(WMView *view);

/* ---[ WINGs/dragcommon.c ]---------------------------------------------- */

CFMutableArrayRef WMCreateDragOperationArray(int initialSize);

WMDragOperationItem* WMCreateDragOperationItem(WMDragOperationType type,
                                               char* text);

WMDragOperationType WMGetDragOperationItemType(WMDragOperationItem* item);

char* WMGetDragOperationItemText(WMDragOperationItem* item);

#endif
