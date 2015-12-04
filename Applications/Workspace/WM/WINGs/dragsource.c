
#include "wconfig.h"
#include "WINGsP.h"

#include <X11/Xatom.h>
#include <X11/cursorfont.h>
#ifdef USE_XSHAPE
#include <X11/extensions/shape.h>
#endif

#define XDND_DESTINATION_RESPONSE_MAX_DELAY 10000
#define MIN_X_MOVE_OFFSET 5
#define MIN_Y_MOVE_OFFSET 5
#define MAX_SLIDEBACK_ITER 15

#define XDND_PROPERTY_FORMAT 32
#define XDND_ACTION_DESCRIPTION_FORMAT 8

#define XDND_DEST_VERSION(dragInfo) dragInfo->protocolVersion
#define XDND_SOURCE_INFO(dragInfo) dragInfo->sourceInfo
#define XDND_DEST_WIN(dragInfo) dragInfo->sourceInfo->destinationWindow
#define XDND_SOURCE_ACTION(dragInfo) dragInfo->sourceAction
#define XDND_DEST_ACTION(dragInfo) dragInfo->destinationAction
#define XDND_SOURCE_VIEW(dragInfo) dragInfo->sourceInfo->sourceView
#define XDND_SOURCE_STATE(dragInfo) dragInfo->sourceInfo->state
#define XDND_SELECTION_PROCS(dragInfo) dragInfo->sourceInfo->selectionProcs
#define XDND_DRAG_ICON(dragInfo) dragInfo->sourceInfo->icon
#define XDND_MOUSE_OFFSET(dragInfo) dragInfo->sourceInfo->mouseOffset
#define XDND_DRAG_CURSOR(dragInfo) dragInfo->sourceInfo->dragCursor
#define XDND_DRAG_ICON_POS(dragInfo) dragInfo->sourceInfo->imageLocation
#define XDND_NO_POS_ZONE(dragInfo) dragInfo->sourceInfo->noPositionMessageZone
#define XDND_TIMESTAMP(dragInfo) dragInfo->timestamp
#define XDND_3_TYPES(dragInfo) dragInfo->sourceInfo->firstThreeTypes
#define XDND_SOURCE_VIEW_STORED(dragInfo) dragInfo->sourceInfo != NULL \
    && dragInfo->sourceInfo->sourceView != NULL

static WMHandlerID dndSourceTimer = NULL;

static void *idleState(WMView * srcView, XClientMessageEvent * event, WMDraggingInfo * info);
static void *dropAllowedState(WMView * srcView, XClientMessageEvent * event, WMDraggingInfo * info);
static void *finishDropState(WMView * srcView, XClientMessageEvent * event, WMDraggingInfo * info);

#ifdef XDND_DEBUG
static const char *stateName(W_DndState * state)
{
	if (state == NULL)
		return "no state defined";

	if (state == idleState)
		return "idleState";

	if (state == dropAllowedState)
		return "dropAllowedState";

	if (state == finishDropState)
		return "finishDropState";

	return "unknown state";
}
#endif

static WMScreen *sourceScreen(WMDraggingInfo * info)
{
	return W_VIEW_SCREEN(XDND_SOURCE_VIEW(info));
}

static void endDragProcess(WMDraggingInfo * info, Bool deposited)
{
	WMView *view = XDND_SOURCE_VIEW(info);
	WMScreen *scr = W_VIEW_SCREEN(XDND_SOURCE_VIEW(info));

	/* free selection handler while view exists */
	WMDeleteSelectionHandler(view, scr->xdndSelectionAtom, CurrentTime);
	wfree(XDND_SELECTION_PROCS(info));

	if (XDND_DRAG_CURSOR(info) != None) {
		XFreeCursor(scr->display, XDND_DRAG_CURSOR(info));
		XDND_DRAG_CURSOR(info) = None;
	}

	if (view->dragSourceProcs->endedDrag != NULL) {
		/* this can destroy source view (with a "move" action for example) */
		view->dragSourceProcs->endedDrag(view, &XDND_DRAG_ICON_POS(info), deposited);
	}

	/* clear remaining draggging infos */
	wfree(XDND_SOURCE_INFO(info));
	XDND_SOURCE_INFO(info) = NULL;
}

/* ----- drag cursor ----- */
static void initDragCursor(WMDraggingInfo * info)
{
	WMScreen *scr = sourceScreen(info);
	XColor cursorFgColor, cursorBgColor;

	/* green */
	cursorFgColor.red = 0x4500;
	cursorFgColor.green = 0xb000;
	cursorFgColor.blue = 0x4500;

	/* white */
	cursorBgColor.red = 0xffff;
	cursorBgColor.green = 0xffff;
	cursorBgColor.blue = 0xffff;

	XDND_DRAG_CURSOR(info) = XCreateFontCursor(scr->display, XC_left_ptr);
	XRecolorCursor(scr->display, XDND_DRAG_CURSOR(info), &cursorFgColor, &cursorBgColor);

	XFlush(scr->display);
}

static void recolorCursor(WMDraggingInfo * info, Bool dropIsAllowed)
{
	WMScreen *scr = sourceScreen(info);

	if (dropIsAllowed) {
		XDefineCursor(scr->display, scr->rootWin, XDND_DRAG_CURSOR(info));
	} else {
		XDefineCursor(scr->display, scr->rootWin, scr->defaultCursor);
	}

	XFlush(scr->display);
}

/* ----- end of drag cursor ----- */

/* ----- selection procs ----- */
static WMData *convertSelection(WMView * view, Atom selection, Atom target, void *cdata, Atom * type)
{
	WMScreen *scr;
	WMData *data;
	char *typeName;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) selection;
	(void) cdata;

	scr = W_VIEW_SCREEN(view);
	typeName = XGetAtomName(scr->display, target);

	*type = target;

	if (view->dragSourceProcs->fetchDragData != NULL) {
		data = view->dragSourceProcs->fetchDragData(view, typeName);
	} else {
		data = NULL;
	}

	if (typeName != NULL)
		XFree(typeName);

	return data;
}

static void selectionLost(WMView * view, Atom selection, void *cdata)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) view;
	(void) selection;
	(void) cdata;

	wwarning(_("XDND selection lost during drag operation..."));
}

static void selectionDone(WMView * view, Atom selection, Atom target, void *cdata)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) view;
	(void) selection;
	(void) target;
	(void) cdata;

#ifdef XDND_DEBUG
	printf("selection done\n");
#endif
}

/* ----- end of selection procs ----- */

/* ----- visual part ----- */

static Window makeDragIcon(WMScreen * scr, WMPixmap * pixmap)
{
	Window window;
	WMSize size;
	unsigned long flags;
	XSetWindowAttributes attribs;

	if (!pixmap) {
		pixmap = scr->defaultObjectIcon;
	}

	size = WMGetPixmapSize(pixmap);

	flags = CWSaveUnder | CWBackPixmap | CWOverrideRedirect | CWColormap;
	attribs.save_under = True;
	attribs.background_pixmap = pixmap->pixmap;
	attribs.override_redirect = True;
	attribs.colormap = scr->colormap;

	window = XCreateWindow(scr->display, scr->rootWin, 0, 0, size.width,
			       size.height, 0, scr->depth, InputOutput, scr->visual, flags, &attribs);

#ifdef USE_XSHAPE
	if (pixmap->mask) {
		XShapeCombineMask(scr->display, window, ShapeBounding, 0, 0, pixmap->mask, ShapeSet);
	}
#endif

	return window;
}

static void slideWindow(Display * dpy, Window win, int srcX, int srcY, int dstX, int dstY)
{
	double x, y, dx, dy;
	int i;
	int iterations;

	iterations = WMIN(MAX_SLIDEBACK_ITER, WMAX(abs(dstX - srcX), abs(dstY - srcY)));

	x = srcX;
	y = srcY;

	dx = (double)(dstX - srcX) / iterations;
	dy = (double)(dstY - srcY) / iterations;

	for (i = 0; i <= iterations; i++) {
		XMoveWindow(dpy, win, x, y);
		XFlush(dpy);

		wusleep(800);

		x += dx;
		y += dy;
	}
}

static int getInitialDragImageCoord(int viewCoord, int mouseCoord, int viewSize, int iconSize)
{
	if (iconSize >= viewSize) {
		/* center icon coord on view */
		return viewCoord - iconSize / 2;
	} else {
		/* try to center icon on mouse pos */

		if (mouseCoord - iconSize / 2 <= viewCoord)
			/* if icon was centered on mouse, it would be off view
			   thus, put icon left (resp. top) side
			   at view (resp. top) side */
			return viewCoord;

		else if (mouseCoord + iconSize / 2 >= viewCoord + viewSize)
			/* if icon was centered on mouse, it would be off view
			   thus, put icon right (resp. bottom) side
			   at view right (resp. bottom) side */
			return viewCoord + viewSize - iconSize;

		else
			return mouseCoord - iconSize / 2;
	}

}

static void initDragImagePos(WMView * view, WMDraggingInfo * info, XEvent * event)
{
	WMSize iconSize = WMGetPixmapSize(view->dragImage);
	WMSize viewSize = WMGetViewSize(view);
	WMPoint viewPos;
	Window foo;

	XTranslateCoordinates(W_VIEW_SCREEN(view)->display,
			      WMViewXID(view), W_VIEW_SCREEN(view)->rootWin,
			      0, 0, &(viewPos.x), &(viewPos.y), &foo);

	/* set icon pos */
	XDND_DRAG_ICON_POS(info).x =
	    getInitialDragImageCoord(viewPos.x, event->xmotion.x_root, viewSize.width, iconSize.width);

	XDND_DRAG_ICON_POS(info).y =
	    getInitialDragImageCoord(viewPos.y, event->xmotion.y_root, viewSize.height, iconSize.height);

	/* set mouse offset relative to icon */
	XDND_MOUSE_OFFSET(info).x = event->xmotion.x_root - XDND_DRAG_ICON_POS(info).x;
	XDND_MOUSE_OFFSET(info).y = event->xmotion.y_root - XDND_DRAG_ICON_POS(info).y;
}

static void refreshDragImage(WMView * view, WMDraggingInfo * info)
{
	WMScreen *scr = W_VIEW_SCREEN(view);

	XMoveWindow(scr->display, XDND_DRAG_ICON(info), XDND_DRAG_ICON_POS(info).x, XDND_DRAG_ICON_POS(info).y);
}

static void startDragImage(WMView * view, WMDraggingInfo * info, XEvent * event)
{
	WMScreen *scr = W_VIEW_SCREEN(view);

	XDND_DRAG_ICON(info) = makeDragIcon(scr, view->dragImage);
	initDragImagePos(view, info, event);
	refreshDragImage(view, info);
	XMapRaised(scr->display, XDND_DRAG_ICON(info));

	initDragCursor(info);
}

static void endDragImage(WMDraggingInfo * info, Bool slideBack)
{
	WMView *view = XDND_SOURCE_VIEW(info);
	Display *dpy = W_VIEW_SCREEN(view)->display;

	if (slideBack) {
		WMPoint toLocation;
		Window foo;

		XTranslateCoordinates(W_VIEW_SCREEN(view)->display,
				      WMViewXID(view), W_VIEW_SCREEN(view)->rootWin,
				      0, 0, &(toLocation.x), &(toLocation.y), &foo);

		slideWindow(dpy, XDND_DRAG_ICON(info),
			    XDND_DRAG_ICON_POS(info).x, XDND_DRAG_ICON_POS(info).y, toLocation.x, toLocation.y);
	}

	XDestroyWindow(dpy, XDND_DRAG_ICON(info));
}

/* ----- end of visual part ----- */

/* ----- messages ----- */

/* send a DnD message to the destination window */
static Bool
sendDnDClientMessage(WMDraggingInfo * info, Atom message,
		     unsigned long data1, unsigned long data2, unsigned long data3, unsigned long data4)
{
	Display *dpy = sourceScreen(info)->display;
	Window srcWin = WMViewXID(XDND_SOURCE_VIEW(info));
	Window destWin = XDND_DEST_WIN(info);

	if (!W_SendDnDClientMessage(dpy, destWin, message, srcWin, data1, data2, data3, data4)) {
		/* drop failed */
		recolorCursor(info, False);
		endDragImage(info, True);
		endDragProcess(info, False);
		return False;
	}

	return True;
}

static Bool sendEnterMessage(WMDraggingInfo * info)
{
	WMScreen *scr = sourceScreen(info);
	unsigned long version;

	if (XDND_DEST_VERSION(info) > 2) {
		if (XDND_DEST_VERSION(info) < XDND_VERSION)
			version = XDND_DEST_VERSION(info);
		else
			version = XDND_VERSION;
	} else {
		version = 3;
	}

	return sendDnDClientMessage(info, scr->xdndEnterAtom, (version << 24) | 1,	/* 1: support of type list */
				    XDND_3_TYPES(info)[0], XDND_3_TYPES(info)[1], XDND_3_TYPES(info)[2]);
}

static Bool sendPositionMessage(WMDraggingInfo * info, WMPoint * mousePos)
{
	WMScreen *scr = sourceScreen(info);
	WMRect *noPosZone = &(XDND_NO_POS_ZONE(info));

	if (noPosZone->size.width != 0 || noPosZone->size.height != 0) {
		if (mousePos->x < noPosZone->pos.x || mousePos->x > (noPosZone->pos.x + noPosZone->size.width)
		    || mousePos->y < noPosZone->pos.y || mousePos->y > (noPosZone->pos.y + noPosZone->size.height)) {
			/* send position if out of zone defined by destination */
			return sendDnDClientMessage(info, scr->xdndPositionAtom,
						    0,
						    mousePos->x << 16 | mousePos->y,
						    XDND_TIMESTAMP(info), XDND_SOURCE_ACTION(info));
		}

		/* Nothing to send, always succeed */
		return True;

	}

	/* send position on each move */
	return sendDnDClientMessage(info, scr->xdndPositionAtom,
				    0,
				    mousePos->x << 16 | mousePos->y,
				    XDND_TIMESTAMP(info), XDND_SOURCE_ACTION(info));
}

static Bool sendLeaveMessage(WMDraggingInfo * info)
{
	WMScreen *scr = sourceScreen(info);

	return sendDnDClientMessage(info, scr->xdndLeaveAtom, 0, 0, 0, 0);
}

static Bool sendDropMessage(WMDraggingInfo * info)
{
	WMScreen *scr = sourceScreen(info);

	return sendDnDClientMessage(info, scr->xdndDropAtom, 0, XDND_TIMESTAMP(info), 0, 0);
}

/* ----- end of messages ----- */

static Atom *getTypeAtomList(WMScreen * scr, WMView * view, int *count)
{
	WMArray *types;
	Atom *typeAtoms;
	int i;

	types = view->dragSourceProcs->dropDataTypes(view);

	if (types != NULL) {
		*count = WMGetArrayItemCount(types);
		if (*count > 0) {
			typeAtoms = wmalloc((*count) * sizeof(Atom));
			for (i = 0; i < *count; i++) {
				typeAtoms[i] = XInternAtom(scr->display, WMGetFromArray(types, i), False);
			}

			/* WMFreeArray(types); */
			return typeAtoms;
		}

		/* WMFreeArray(types); */
	}

	*count = 1;
	typeAtoms = wmalloc(sizeof(Atom));
	*typeAtoms = None;

	return typeAtoms;
}

static void registerDropTypes(WMScreen * scr, WMView * view, WMDraggingInfo * info)
{
	Atom *typeList;
	int i, count;

	typeList = getTypeAtomList(scr, view, &count);

	/* store the first 3 types */
	for (i = 0; i < 3 && i < count; i++)
		XDND_3_TYPES(info)[i] = typeList[i];

	for (; i < 3; i++)
		XDND_3_TYPES(info)[i] = None;

	/* store the entire type list */
	XChangeProperty(scr->display,
			WMViewXID(view),
			scr->xdndTypeListAtom,
			XA_ATOM, XDND_PROPERTY_FORMAT, PropModeReplace, (unsigned char *)typeList, count);
}

static void registerOperationList(WMScreen * scr, WMView * view, WMArray * operationArray)
{
	Atom *actionList;
	WMDragOperationType operation;
	int count = WMGetArrayItemCount(operationArray);
	int i;

	actionList = wmalloc(sizeof(Atom) * count);

	for (i = 0; i < count; i++) {
		operation = WMGetDragOperationItemType(WMGetFromArray(operationArray, i));
		actionList[i] = W_OperationToAction(scr, operation);
	}

	XChangeProperty(scr->display,
			WMViewXID(view),
			scr->xdndActionListAtom,
			XA_ATOM, XDND_PROPERTY_FORMAT, PropModeReplace, (unsigned char *)actionList, count);
}

static void registerDescriptionList(WMScreen * scr, WMView * view, WMArray * operationArray)
{
	char *text, *textListItem, *textList;
	int count = WMGetArrayItemCount(operationArray);
	int i;
	int size = 0;

	/* size of XA_STRING info */
	for (i = 0; i < count; i++) {
		size += strlen(WMGetDragOperationItemText(WMGetFromArray(operationArray, i))) + 1 /* NULL */;
	}

	/* create text list */
	textList = wmalloc(size);
	textListItem = textList;

	for (i = 0; i < count; i++) {
		text = WMGetDragOperationItemText(WMGetFromArray(operationArray, i));
		wstrlcpy(textListItem, text, size);

		/* to next text offset */
		textListItem = &(textListItem[strlen(textListItem) + 1]);
	}

	XChangeProperty(scr->display,
			WMViewXID(view),
			scr->xdndActionDescriptionAtom,
			XA_STRING,
			XDND_ACTION_DESCRIPTION_FORMAT, PropModeReplace, (unsigned char *)textList, size);
}

/* called if wanted operation is WDOperationAsk */
static void registerSupportedOperations(WMView * view)
{
	WMScreen *scr = W_VIEW_SCREEN(view);
	WMArray *operationArray;

	operationArray = view->dragSourceProcs->askedOperations(view);

	registerOperationList(scr, view, operationArray);
	registerDescriptionList(scr, view, operationArray);

	/* WMFreeArray(operationArray); */
}

static void initSourceDragInfo(WMView * sourceView, WMDraggingInfo * info)
{
	WMRect emptyZone;

	XDND_SOURCE_INFO(info) = (W_DragSourceInfo *) wmalloc(sizeof(W_DragSourceInfo));

	XDND_SOURCE_VIEW(info) = sourceView;
	XDND_DEST_WIN(info) = None;
	XDND_DRAG_ICON(info) = None;

	XDND_SOURCE_ACTION(info) = W_OperationToAction(W_VIEW_SCREEN(sourceView),
						       sourceView->dragSourceProcs->
						       wantedDropOperation(sourceView));

	XDND_DEST_ACTION(info) = None;

	XDND_SOURCE_STATE(info) = idleState;

	emptyZone.pos = wmkpoint(0, 0);
	emptyZone.size = wmksize(0, 0);
	XDND_NO_POS_ZONE(info) = emptyZone;
}

/*
 Returned array is destroyed after dropDataTypes call
 */
static WMArray *defDropDataTypes(WMView * self)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	return NULL;
}

static WMDragOperationType defWantedDropOperation(WMView * self)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	return WDOperationNone;
}

/*
 Must be defined if wantedDropOperation return WDOperationAsk
 (useless otherwise).
 Return a WMDragOperationItem array (destroyed after call).
 A WMDragOperationItem links a label to an operation.
 static WMArray*
 defAskedOperations(WMView *self); */

static Bool defAcceptDropOperation(WMView * self, WMDragOperationType allowedOperation)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;
	(void) allowedOperation;

	return False;
}

static void defBeganDrag(WMView * self, WMPoint * point)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;
	(void) point;
}

static void defEndedDrag(WMView * self, WMPoint * point, Bool deposited)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;
	(void) point;
	(void) deposited;
}

/*
 Returned data is not destroyed
 */
static WMData *defFetchDragData(WMView * self, char *type)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;
	(void) type;

	return NULL;
}

void WMSetViewDragSourceProcs(WMView * view, WMDragSourceProcs * procs)
{
	if (view->dragSourceProcs)
		wfree(view->dragSourceProcs);
	view->dragSourceProcs = wmalloc(sizeof(WMDragSourceProcs));

	*view->dragSourceProcs = *procs;

	if (procs->dropDataTypes == NULL)
		view->dragSourceProcs->dropDataTypes = defDropDataTypes;

	if (procs->wantedDropOperation == NULL)
		view->dragSourceProcs->wantedDropOperation = defWantedDropOperation;

	/*
	   Note: askedOperations can be NULL, if wantedDropOperation never returns
	   WDOperationAsk.
	 */

	if (procs->acceptDropOperation == NULL)
		view->dragSourceProcs->acceptDropOperation = defAcceptDropOperation;

	if (procs->beganDrag == NULL)
		view->dragSourceProcs->beganDrag = defBeganDrag;

	if (procs->endedDrag == NULL)
		view->dragSourceProcs->endedDrag = defEndedDrag;

	if (procs->fetchDragData == NULL)
		view->dragSourceProcs->fetchDragData = defFetchDragData;
}

static Bool isXdndAware(WMScreen * scr, Window win)
{
	Atom type;
	int format;
	unsigned long count, remain;
	unsigned char *winXdndVersion;

	if (win == None)
		return False;

	XGetWindowProperty(scr->display, win, scr->xdndAwareAtom,
			   0, 1, False, XA_ATOM, &type, &format, &count, &remain, &winXdndVersion);

	if (type != XA_ATOM || format != XDND_PROPERTY_FORMAT || count == 0 || !winXdndVersion) {
		if (winXdndVersion)
			XFree(winXdndVersion);
		return False;
	}

	XFree(winXdndVersion);
	return (count == 1);	/* xdnd version is set */
}

static Window *windowChildren(Display * dpy, Window win, unsigned *nchildren)
{
	Window *children;
	Window foo, bar;

	if (!XQueryTree(dpy, win, &foo, &bar, &children, nchildren)) {
		*nchildren = 0;
		return NULL;
	} else
		return children;
}

static Window lookForAwareWindow(WMScreen * scr, WMPoint * mousePos, Window win)
{
	int tmpx, tmpy;
	Window child;

	/* Since xdnd v3, only the toplevel window should be aware */
	if (isXdndAware(scr, win))
		return win;

	/* inspect child under pointer */
	if (XTranslateCoordinates(scr->display, scr->rootWin, win, mousePos->x, mousePos->y, &tmpx, &tmpy, &child)) {
		if (child == None)
			return None;
		else
			return lookForAwareWindow(scr, mousePos, child);
	}

	return None;
}

static Window findDestination(WMDraggingInfo * info, WMPoint * mousePos)
{
	WMScreen *scr = sourceScreen(info);
	unsigned nchildren;
	Window *children = windowChildren(scr->display, scr->rootWin, &nchildren);
	int i;
	XWindowAttributes attr;

	if (isXdndAware(scr, scr->rootWin))
		return scr->rootWin;

	/* exclude drag icon (and upper) from search */
	for (i = nchildren - 1; i >= 0; i--) {
		if (children[i] == XDND_DRAG_ICON(info)) {
			i--;
			break;
		}
	}

	if (i < 0) {
		/* root window has no child under drag icon, and is not xdnd aware. */
		return None;
	}

	/* inspecting children, from upper to lower */
	for (; i >= 0; i--) {
		if (XGetWindowAttributes(scr->display, children[i], &attr)
		    && attr.map_state == IsViewable
		    && mousePos->x >= attr.x
		    && mousePos->y >= attr.y
		    && mousePos->x < attr.x + attr.width && mousePos->y < attr.y + attr.height) {
			return lookForAwareWindow(scr, mousePos, children[i]);
		}
	}

	/* No child window under drag pointer */
	return None;
}

static void storeDestinationProtocolVersion(WMDraggingInfo * info)
{
	Atom type;
	int format;
	unsigned long count, remain;
	unsigned char *winXdndVersion;
	WMScreen *scr = W_VIEW_SCREEN(XDND_SOURCE_VIEW(info));

	wassertr(XDND_DEST_WIN(info) != None);

	if (XGetWindowProperty(scr->display, XDND_DEST_WIN(info),
			       scr->xdndAwareAtom,
			       0, 1, False, XA_ATOM, &type, &format,
			       &count, &remain, &winXdndVersion) == Success) {
		XDND_DEST_VERSION(info) = *winXdndVersion;
		XFree(winXdndVersion);
	} else {
		XDND_DEST_VERSION(info) = 0;
		wwarning(_("could not get XDND version for target of drop"));
	}
}

static void initMotionProcess(WMView * view, WMDraggingInfo * info, XEvent * event, WMPoint * startLocation)
{
	WMScreen *scr = W_VIEW_SCREEN(view);

	/* take ownership of XdndSelection */
	XDND_SELECTION_PROCS(info) = (WMSelectionProcs *) wmalloc(sizeof(WMSelectionProcs));
	XDND_SELECTION_PROCS(info)->convertSelection = convertSelection;
	XDND_SELECTION_PROCS(info)->selectionLost = selectionLost;
	XDND_SELECTION_PROCS(info)->selectionDone = selectionDone;
	XDND_TIMESTAMP(info) = event->xmotion.time;

	if (!WMCreateSelectionHandler(view, scr->xdndSelectionAtom, CurrentTime, XDND_SELECTION_PROCS(info), NULL)) {
		wwarning(_("could not get ownership of XDND selection"));
		return;
	}

	registerDropTypes(scr, view, info);

	if (XDND_SOURCE_ACTION(info) == W_VIEW_SCREEN(view)->xdndActionAsk)
		registerSupportedOperations(view);

	if (view->dragSourceProcs->beganDrag != NULL) {
		view->dragSourceProcs->beganDrag(view, startLocation);
	}
}

static void processMotion(WMDraggingInfo * info, WMPoint * mousePos)
{
	Window newDestination = findDestination(info, mousePos);

	W_DragSourceStopTimer();

	if (newDestination != XDND_DEST_WIN(info)) {
		recolorCursor(info, False);

		if (XDND_DEST_WIN(info) != None) {
			/* leaving a xdnd window */
			sendLeaveMessage(info);
		}

		XDND_DEST_WIN(info) = newDestination;
		XDND_DEST_ACTION(info) = None;
		XDND_NO_POS_ZONE(info).size.width = 0;
		XDND_NO_POS_ZONE(info).size.height = 0;

		if (newDestination != None) {
			/* entering a xdnd window */
			XDND_SOURCE_STATE(info) = idleState;
			storeDestinationProtocolVersion(info);

			if (!sendEnterMessage(info)) {
				XDND_DEST_WIN(info) = None;
				return;
			}

			W_DragSourceStartTimer(info);
		} else {
			XDND_SOURCE_STATE(info) = NULL;
		}
	} else {
		if (XDND_DEST_WIN(info) != None) {
			if (!sendPositionMessage(info, mousePos)) {
				XDND_DEST_WIN(info) = None;
				return;
			}

			W_DragSourceStartTimer(info);
		}
	}
}

static Bool processButtonRelease(WMDraggingInfo * info)
{
	if (XDND_SOURCE_STATE(info) == dropAllowedState) {
		/* begin drop */
		W_DragSourceStopTimer();

		if (!sendDropMessage(info))
			return False;

		W_DragSourceStartTimer(info);
		return True;
	} else {
		if (XDND_DEST_WIN(info) != None)
			sendLeaveMessage(info);

		W_DragSourceStopTimer();
		return False;
	}
}

Bool WMIsDraggingFromView(WMView * view)
{
	WMDraggingInfo *info = &W_VIEW_SCREEN(view)->dragInfo;

	return (XDND_SOURCE_INFO(info) != NULL && XDND_SOURCE_STATE(info) != finishDropState);
	/* return W_VIEW_SCREEN(view)->dragInfo.sourceInfo != NULL; */
}

void WMDragImageFromView(WMView * view, XEvent * event)
{
	WMDraggingInfo *info = &W_VIEW_SCREEN(view)->dragInfo;
	WMPoint mouseLocation;

	switch (event->type) {
	case ButtonPress:
		if (event->xbutton.button == Button1) {
			XEvent nextEvent;

			XPeekEvent(event->xbutton.display, &nextEvent);

			/* Initialize only if a drag really begins (avoid clicks) */
			if (nextEvent.type == MotionNotify) {
				initSourceDragInfo(view, info);
			}
		}

		break;

	case ButtonRelease:
		if (WMIsDraggingFromView(view)) {
			Bool dropBegan = processButtonRelease(info);

			recolorCursor(info, False);
			if (dropBegan) {
				endDragImage(info, False);
				XDND_SOURCE_STATE(info) = finishDropState;
			} else {
				/* drop failed */
				endDragImage(info, True);
				endDragProcess(info, False);
			}
		}
		break;

	case MotionNotify:
		if (WMIsDraggingFromView(view)) {
			mouseLocation = wmkpoint(event->xmotion.x_root, event->xmotion.y_root);

			if (abs(XDND_DRAG_ICON_POS(info).x - mouseLocation.x) >=
			    MIN_X_MOVE_OFFSET
			    || abs(XDND_DRAG_ICON_POS(info).y - mouseLocation.y) >= MIN_Y_MOVE_OFFSET) {
				if (XDND_DRAG_ICON(info) == None) {
					initMotionProcess(view, info, event, &mouseLocation);
					startDragImage(view, info, event);
				} else {
					XDND_DRAG_ICON_POS(info).x = mouseLocation.x - XDND_MOUSE_OFFSET(info).x;
					XDND_DRAG_ICON_POS(info).y = mouseLocation.y - XDND_MOUSE_OFFSET(info).y;

					refreshDragImage(view, info);
					processMotion(info, &mouseLocation);
				}
			}
		}
		break;
	}
}

/* Minimal mouse events handler: no right or double-click detection,
 only drag is supported */
static void dragImageHandler(XEvent * event, void *cdata)
{
	WMView *view = (WMView *) cdata;

	WMDragImageFromView(view, event);
}

/* ----- source states ----- */

#ifdef XDND_DEBUG
static void traceStatusMsg(Display * dpy, XClientMessageEvent * statusEvent)
{
	printf("Xdnd status message:\n");

	if (statusEvent->data.l[1] & 0x2UL)
		printf("\tsend position on every move\n");
	else {
		int x, y, w, h;
		x = statusEvent->data.l[2] >> 16;
		y = statusEvent->data.l[2] & 0xFFFFL;
		w = statusEvent->data.l[3] >> 16;
		h = statusEvent->data.l[3] & 0xFFFFL;

		printf("\tsend position out of ((%d,%d) , (%d,%d))\n", x, y, x + w, y + h);
	}

	if (statusEvent->data.l[1] & 0x1L)
		printf("\tallowed action: %s\n", XGetAtomName(dpy, statusEvent->data.l[4]));
	else
		printf("\tno action allowed\n");
}
#endif

static void storeDropAction(WMDraggingInfo * info, Atom destAction)
{
	WMView *sourceView = XDND_SOURCE_VIEW(info);
	WMScreen *scr = W_VIEW_SCREEN(sourceView);

	if (sourceView->dragSourceProcs->acceptDropOperation != NULL) {
		if (sourceView->dragSourceProcs->acceptDropOperation(sourceView,
								     W_ActionToOperation(scr, destAction)))
			XDND_DEST_ACTION(info) = destAction;
		else
			XDND_DEST_ACTION(info) = None;
	} else {
		XDND_DEST_ACTION(info) = destAction;
	}
}

static void storeStatusMessageInfos(WMDraggingInfo * info, XClientMessageEvent * statusEvent)
{
	WMRect *noPosZone = &(XDND_NO_POS_ZONE(info));

#ifdef XDND_DEBUG

	traceStatusMsg(sourceScreen(info)->display, statusEvent);
#endif

	if (statusEvent->data.l[1] & 0x2UL) {
		/* bit 1 set: destination wants position messages on every move */
		noPosZone->size.width = 0;
		noPosZone->size.height = 0;
	} else {
		/* don't send another position message while in given rectangle */
		noPosZone->pos.x = statusEvent->data.l[2] >> 16;
		noPosZone->pos.y = statusEvent->data.l[2] & 0xFFFFL;
		noPosZone->size.width = statusEvent->data.l[3] >> 16;
		noPosZone->size.height = statusEvent->data.l[3] & 0xFFFFL;
	}

	if ((statusEvent->data.l[1] & 0x1L) || statusEvent->data.l[4] != None) {
		/* destination accept drop */
		storeDropAction(info, statusEvent->data.l[4]);
	} else {
		XDND_DEST_ACTION(info) = None;
	}
}

static void *idleState(WMView * view, XClientMessageEvent * event, WMDraggingInfo * info)
{
	WMScreen *scr;
	Atom destMsg = event->message_type;

	scr = W_VIEW_SCREEN(view);

	if (destMsg == scr->xdndStatusAtom) {
		storeStatusMessageInfos(info, event);

		if (XDND_DEST_ACTION(info) != None) {
			recolorCursor(info, True);
			W_DragSourceStartTimer(info);
			return dropAllowedState;
		} else {
			/* drop denied */
			recolorCursor(info, False);
			return idleState;
		}
	}

	if (destMsg == scr->xdndFinishedAtom) {
		wwarning("received xdndFinishedAtom before drop began");
	}

	W_DragSourceStartTimer(info);
	return idleState;
}

static void *dropAllowedState(WMView * view, XClientMessageEvent * event, WMDraggingInfo * info)
{
	WMScreen *scr = W_VIEW_SCREEN(view);
	Atom destMsg = event->message_type;

	if (destMsg == scr->xdndStatusAtom) {
		storeStatusMessageInfos(info, event);

		if (XDND_DEST_ACTION(info) == None) {
			/* drop denied */
			recolorCursor(info, False);
			return idleState;
		}
	}

	W_DragSourceStartTimer(info);
	return dropAllowedState;
}

static void *finishDropState(WMView * view, XClientMessageEvent * event, WMDraggingInfo * info)
{
	WMScreen *scr = W_VIEW_SCREEN(view);
	Atom destMsg = event->message_type;

	if (destMsg == scr->xdndFinishedAtom) {
		endDragProcess(info, True);
		return NULL;
	}

	W_DragSourceStartTimer(info);
	return finishDropState;
}

/* ----- end of source states ----- */

/* ----- source timer ----- */
static void dragSourceResponseTimeOut(void *source)
{
	WMView *view = (WMView *) source;
	WMDraggingInfo *info = &(W_VIEW_SCREEN(view)->dragInfo);

	wwarning(_("delay for drag destination response expired"));
	sendLeaveMessage(info);

	recolorCursor(info, False);
	if (XDND_SOURCE_STATE(info) == finishDropState) {
		/* drop failed */
		endDragImage(info, True);
		endDragProcess(info, False);
	} else {
		XDND_SOURCE_STATE(info) = idleState;
	}
}

void W_DragSourceStopTimer()
{
	if (dndSourceTimer != NULL) {
		WMDeleteTimerHandler(dndSourceTimer);
		dndSourceTimer = NULL;
	}
}

void W_DragSourceStartTimer(WMDraggingInfo * info)
{
	W_DragSourceStopTimer();

	dndSourceTimer = WMAddTimerHandler(XDND_DESTINATION_RESPONSE_MAX_DELAY,
					   dragSourceResponseTimeOut, XDND_SOURCE_VIEW(info));
}

/* ----- End of Destination timer ----- */

void W_DragSourceStateHandler(WMDraggingInfo * info, XClientMessageEvent * event)
{
	WMView *view;
	W_DndState *newState;

	if (XDND_SOURCE_VIEW_STORED(info)) {
		if (XDND_SOURCE_STATE(info) != NULL) {
			view = XDND_SOURCE_VIEW(info);
#ifdef XDND_DEBUG

			printf("current source state: %s\n", stateName(XDND_SOURCE_STATE(info)));
#endif

			newState = (W_DndState *) XDND_SOURCE_STATE(info) (view, event, info);

#ifdef XDND_DEBUG

			printf("new source state: %s\n", stateName(newState));
#endif

			if (newState != NULL)
				XDND_SOURCE_STATE(info) = newState;
			/* else drop finished, and info has been flushed */
		}

	} else {
		wwarning("received DnD message without having a target");
	}
}

void WMSetViewDragImage(WMView * view, WMPixmap * dragImage)
{
	if (view->dragImage != NULL)
		WMReleasePixmap(view->dragImage);

	view->dragImage = WMRetainPixmap(dragImage);
}

void WMReleaseViewDragImage(WMView * view)
{
	if (view->dragImage != NULL)
		WMReleasePixmap(view->dragImage);
}

/* Create a drag handler, associating drag event masks with dragEventProc */
void WMCreateDragHandler(WMView * view, WMEventProc * dragEventProc, void *clientData)
{
	WMCreateEventHandler(view,
			     ButtonPressMask | ButtonReleaseMask | Button1MotionMask, dragEventProc, clientData);
}

void WMDeleteDragHandler(WMView * view, WMEventProc * dragEventProc, void *clientData)
{
	WMDeleteEventHandler(view,
			     ButtonPressMask | ButtonReleaseMask | Button1MotionMask, dragEventProc, clientData);
}

/* set default drag handler for view */
void WMSetViewDraggable(WMView * view, WMDragSourceProcs * dragSourceProcs, WMPixmap * dragImage)
{
	wassertr(dragImage != NULL);
	view->dragImage = WMRetainPixmap(dragImage);

	WMSetViewDragSourceProcs(view, dragSourceProcs);

	WMCreateDragHandler(view, dragImageHandler, view);
}

void WMUnsetViewDraggable(WMView * view)
{
	if (view->dragSourceProcs) {
		wfree(view->dragSourceProcs);
		view->dragSourceProcs = NULL;
	}

	WMReleaseViewDragImage(view);

	WMDeleteDragHandler(view, dragImageHandler, view);
}
