
#include "WINGsP.h"

#define XDND_COLOR_DATA_TYPE "application/X-color"

char *WMColorWellDidChangeNotification = "WMColorWellDidChangeNotification";

typedef struct W_ColorWell {
	W_Class widgetClass;
	WMView *view;

	WMView *colorView;

	WMColor *color;

	WMAction *action;
	void *clientData;

	WMPoint ipoint;

	struct {
		unsigned int active:1;
		unsigned int bordered:1;
	} flags;

	WMArray *xdndTypes;
} ColorWell;

static char *_ColorWellActivatedNotification = "_ColorWellActivatedNotification";

static void destroyColorWell(ColorWell * cPtr);
static void paintColorWell(ColorWell * cPtr);

static void handleEvents(XEvent * event, void *data);

static void handleDragEvents(XEvent * event, void *data);

static void handleActionEvents(XEvent * event, void *data);

static void willResizeColorWell(W_ViewDelegate * self, WMView * view, unsigned int *width, unsigned int *height);

W_ViewDelegate _ColorWellViewDelegate = {
	NULL,
	NULL,
	NULL,
	NULL,
	willResizeColorWell
};

static WMArray *dropDataTypes(WMView * self);
static WMDragOperationType wantedDropOperation(WMView * self);
static Bool acceptDropOperation(WMView * self, WMDragOperationType operation);
static WMData *fetchDragData(WMView * self, char *type);

static WMDragSourceProcs _DragSourceProcs = {
	dropDataTypes,
	wantedDropOperation,
	NULL,
	acceptDropOperation,
	NULL,
	NULL,
	fetchDragData
};

static WMArray *requiredDataTypes(WMView * self,
				  WMDragOperationType requestedOperation, WMArray * sourceDataTypes);
static WMDragOperationType allowedOperation(WMView * self,
					    WMDragOperationType requestedOperation, WMArray * sourceDataTypes);
static void performDragOperation(WMView * self, WMArray * dropDatas,
				 WMArray * operationsList, WMPoint * dropLocation);

static WMDragDestinationProcs _DragDestinationProcs = {
	NULL,
	requiredDataTypes,
	allowedOperation,
	NULL,
	performDragOperation,
	NULL
};

#define DEFAULT_WIDTH		60
#define DEFAULT_HEIGHT		30

#define MIN_WIDTH	16
#define MIN_HEIGHT	8

static void colorChangedObserver(void *data, WMNotification * notification)
{
	WMColorPanel *panel = (WMColorPanel *) WMGetNotificationObject(notification);
	WMColorWell *cPtr = (WMColorWell *) data;
	WMColor *color;

	if (!cPtr->flags.active)
		return;

	color = WMGetColorPanelColor(panel);

	WMSetColorWellColor(cPtr, color);
	WMPostNotificationName(WMColorWellDidChangeNotification, cPtr, NULL);
}

static void updateColorCallback(void *self, void *data)
{
	WMColorPanel *panel = (WMColorPanel *) self;
	WMColorWell *cPtr = (ColorWell *) data;
	WMColor *color;

	color = WMGetColorPanelColor(panel);
	WMSetColorWellColor(cPtr, color);
	WMPostNotificationName(WMColorWellDidChangeNotification, cPtr, NULL);
}

static WMArray *getXdndTypeArray(void)
{
	WMArray *types = WMCreateArray(1);
	WMAddToArray(types, XDND_COLOR_DATA_TYPE);
	return types;
}

WMColorWell *WMCreateColorWell(WMWidget * parent)
{
	ColorWell *cPtr;

	cPtr = wmalloc(sizeof(ColorWell));

	cPtr->widgetClass = WC_ColorWell;

	cPtr->view = W_CreateView(W_VIEW(parent));
	if (!cPtr->view) {
		wfree(cPtr);
		return NULL;
	}
	cPtr->view->self = cPtr;

	cPtr->view->delegate = &_ColorWellViewDelegate;

	cPtr->colorView = W_CreateView(cPtr->view);
	if (!cPtr->colorView) {
		W_DestroyView(cPtr->view);
		wfree(cPtr);
		return NULL;
	}
	cPtr->colorView->self = cPtr;

	WMCreateEventHandler(cPtr->view, ExposureMask | StructureNotifyMask
			     | ClientMessageMask, handleEvents, cPtr);

	WMCreateEventHandler(cPtr->colorView, ExposureMask, handleEvents, cPtr);

	WMCreateDragHandler(cPtr->colorView, handleDragEvents, cPtr);

	WMCreateEventHandler(cPtr->view, ButtonPressMask, handleActionEvents, cPtr);
	WMCreateEventHandler(cPtr->colorView, ButtonPressMask, handleActionEvents, cPtr);

	cPtr->colorView->flags.mapWhenRealized = 1;

	cPtr->flags.bordered = 1;

	W_ResizeView(cPtr->view, DEFAULT_WIDTH, DEFAULT_HEIGHT);

	cPtr->color = WMBlackColor(WMWidgetScreen(cPtr));

	WMAddNotificationObserver(colorChangedObserver, cPtr, WMColorPanelColorChangedNotification, NULL);

	WMSetViewDragSourceProcs(cPtr->colorView, &_DragSourceProcs);
	WMSetViewDragDestinationProcs(cPtr->colorView, &_DragDestinationProcs);

	cPtr->xdndTypes = getXdndTypeArray();
	WMRegisterViewForDraggedTypes(cPtr->colorView, cPtr->xdndTypes);

	return cPtr;
}

void WMSetColorWellColor(WMColorWell * cPtr, WMColor * color)
{
	if (cPtr->color)
		WMReleaseColor(cPtr->color);

	cPtr->color = WMRetainColor(color);

	if (cPtr->colorView->flags.realized && cPtr->colorView->flags.mapped)
		paintColorWell(cPtr);
}

WMColor *WMGetColorWellColor(WMColorWell * cPtr)
{
	return cPtr->color;
}

void WSetColorWellBordered(WMColorWell * cPtr, Bool flag)
{
	flag = ((flag == 0) ? 0 : 1);
	if (cPtr->flags.bordered != flag) {
		cPtr->flags.bordered = flag;
		W_ResizeView(cPtr->view, cPtr->view->size.width, cPtr->view->size.height);
	}
}

static void willResizeColorWell(W_ViewDelegate * self, WMView * view, unsigned int *width, unsigned int *height)
{
	WMColorWell *cPtr = (WMColorWell *) view->self;
	int bw;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	if (cPtr->flags.bordered) {

		if (*width < MIN_WIDTH)
			*width = MIN_WIDTH;
		if (*height < MIN_HEIGHT)
			*height = MIN_HEIGHT;

		bw = (int)((float)WMIN(*width, *height) * 0.24F);

		W_ResizeView(cPtr->colorView, *width - 2 * bw, *height - 2 * bw);

		if (cPtr->colorView->pos.x != bw || cPtr->colorView->pos.y != bw)
			W_MoveView(cPtr->colorView, bw, bw);
	} else {
		W_ResizeView(cPtr->colorView, *width, *height);

		W_MoveView(cPtr->colorView, 0, 0);
	}
}

static void paintColorWell(ColorWell * cPtr)
{
	W_Screen *scr = cPtr->view->screen;

	W_DrawRelief(scr, cPtr->view->window, 0, 0, cPtr->view->size.width, cPtr->view->size.height, WRRaised);

	W_DrawRelief(scr, cPtr->colorView->window, 0, 0,
		     cPtr->colorView->size.width, cPtr->colorView->size.height, WRSunken);

	if (cPtr->color)
		WMPaintColorSwatch(cPtr->color, cPtr->colorView->window,
				   2, 2, cPtr->colorView->size.width - 4, cPtr->colorView->size.height - 4);
}

static void handleEvents(XEvent * event, void *data)
{
	ColorWell *cPtr = (ColorWell *) data;

	CHECK_CLASS(data, WC_ColorWell);

	switch (event->type) {
	case Expose:
		if (event->xexpose.count != 0)
			break;
		paintColorWell(cPtr);
		break;

	case DestroyNotify:
		destroyColorWell(cPtr);
		break;

	}
}

static WMArray *dropDataTypes(WMView * self)
{
	return ((ColorWell *) self->self)->xdndTypes;
}

static WMDragOperationType wantedDropOperation(WMView * self)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	return WDOperationCopy;
}

static Bool acceptDropOperation(WMView * self, WMDragOperationType operation)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	return (operation == WDOperationCopy);
}

static WMData *fetchDragData(WMView * self, char *type)
{
	char *color = WMGetColorRGBDescription(((WMColorWell *) self->self)->color);
	WMData *data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) type;

	data = WMCreateDataWithBytes(color, strlen(color) + 1);
	wfree(color);

	return data;
}

static WMPixmap *makeDragPixmap(WMColorWell * cPtr)
{
	WMScreen *scr = cPtr->view->screen;
	Pixmap pix;

	pix = XCreatePixmap(scr->display, W_DRAWABLE(scr), 16, 16, scr->depth);

	XFillRectangle(scr->display, pix, WMColorGC(cPtr->color), 0, 0, 15, 15);

	XDrawRectangle(scr->display, pix, WMColorGC(scr->black), 0, 0, 15, 15);

	return WMCreatePixmapFromXPixmaps(scr, pix, None, 16, 16, scr->depth);
}

static void handleDragEvents(XEvent * event, void *data)
{
	WMColorWell *cPtr = (ColorWell *) data;

	if (event->type == ButtonPress && event->xbutton.button == Button1) {
		/* initialise drag icon */
		WMSetViewDragImage(cPtr->colorView, makeDragPixmap(cPtr));
	}

	WMDragImageFromView(cPtr->colorView, event);
}

static void handleActionEvents(XEvent * event, void *data)
{
	WMColorWell *cPtr = (ColorWell *) data;
	WMScreen *scr = WMWidgetScreen(cPtr);
	WMColorPanel *cpanel;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) event;

	if (cPtr->flags.active)
		W_SetViewBackgroundColor(cPtr->view, scr->gray);
	else
		W_SetViewBackgroundColor(cPtr->view, scr->white);
	paintColorWell(cPtr);

	cPtr->flags.active ^= 1;

	if (cPtr->flags.active) {
		WMPostNotificationName(_ColorWellActivatedNotification, cPtr, NULL);
	}
	cpanel = WMGetColorPanel(scr);

	WMSetColorPanelAction(cpanel, updateColorCallback, cPtr);

	if (cPtr->color)
		WMSetColorPanelColor(cpanel, cPtr->color);
	WMShowColorPanel(cpanel);
}

static void destroyColorWell(ColorWell * cPtr)
{
	WMRemoveNotificationObserver(cPtr);

	if (cPtr->color)
		WMReleaseColor(cPtr->color);

	WMFreeArray(cPtr->xdndTypes);

	wfree(cPtr);
}

static Bool dropIsOk(WMDragOperationType request, WMArray * sourceDataTypes)
{
	WMArrayIterator iter;
	char *type;

	if (request == WDOperationCopy) {
		WM_ITERATE_ARRAY(sourceDataTypes, type, iter) {
			if (type != NULL && strcmp(type, XDND_COLOR_DATA_TYPE) == 0) {
				return True;
			}
		}
	}

	return False;
}

static WMArray *requiredDataTypes(WMView * self, WMDragOperationType request, WMArray * sourceDataTypes)
{
	if (dropIsOk(request, sourceDataTypes))
		return ((ColorWell *) self->self)->xdndTypes;
	else
		return NULL;
}

static WMDragOperationType allowedOperation(WMView * self, WMDragOperationType request, WMArray * sourceDataTypes)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	if (dropIsOk(request, sourceDataTypes))
		return WDOperationCopy;
	else
		return WDOperationNone;
}

static void performDragOperation(WMView * self, WMArray * dropData, WMArray * operations, WMPoint * dropLocation)
{
	char *colorName;
	WMColor *color;
	WMData *data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) operations;
	(void) dropLocation;

	/* only one operation requested (WDOperationCopy) implies only one data */
	data = (WMData *) WMGetFromArray(dropData, 0);

	if (data != NULL) {
		colorName = (char *)WMDataBytes(data);
		color = WMCreateNamedColor(W_VIEW_SCREEN(self), colorName, True);
		WMSetColorWellColor(self->self, color);
		WMReleaseColor(color);
	}
}
