
#include "WINGsP.h"

typedef struct {
	WMView *view;
	int minSize;
	int maxSize;
	int space;
	unsigned expand:1;
	unsigned fill:1;
	unsigned end:1;
} SubviewItem;

typedef struct W_Box {
	W_Class widgetClass;
	W_View *view;

	WMArray *subviews;

	short borderWidth;

	unsigned horizontal:1;
} Box;

#define DEFAULT_WIDTH		40
#define DEFAULT_HEIGHT		40

static void destroyBox(Box * bPtr);

static void handleEvents(XEvent * event, void *data);

static void didResize(struct W_ViewDelegate *, WMView *);

static W_ViewDelegate delegate = {
	NULL,
	NULL,
	didResize,
	NULL,
	NULL
};

WMBox *WMCreateBox(WMWidget * parent)
{
	Box *bPtr;

	bPtr = wmalloc(sizeof(Box));

	bPtr->widgetClass = WC_Box;

	bPtr->view = W_CreateView(W_VIEW(parent));
	if (!bPtr->view) {
		wfree(bPtr);
		return NULL;
	}
	bPtr->view->self = bPtr;

	bPtr->view->delegate = &delegate;

	bPtr->subviews = WMCreateArrayWithDestructor(2, wfree);

	WMCreateEventHandler(bPtr->view, StructureNotifyMask, handleEvents, bPtr);

	WMResizeWidget(bPtr, DEFAULT_WIDTH, DEFAULT_HEIGHT);

	return bPtr;
}

typedef struct {
	WMBox *box;
	int total;
	int expands;
	int x, y;
	int xe, ye;
	int w, h;
} BoxData;

static void computeExpansion(void *object, void *cdata)
{
	SubviewItem *item = (SubviewItem *) object;
	BoxData *eData = (BoxData *) cdata;

	eData->total -= item->minSize;
	eData->total -= item->space;
	if (item->expand) {
		eData->expands++;
	}
}

static void doRearrange(void *object, void *cdata)
{
	SubviewItem *item = (SubviewItem *) object;
	BoxData *eData = (BoxData *) cdata;

	if (eData->box->horizontal) {
		eData->w = item->minSize;
		if (item->expand)
			eData->w += eData->total / eData->expands;
	} else {
		eData->h = item->minSize;
		if (item->expand)
			eData->h += eData->total / eData->expands;
	}
	if (!item->end) {
		W_MoveView(item->view, eData->x, eData->y);
	}
	W_ResizeView(item->view, eData->w, eData->h);
	if (eData->box->horizontal) {
		if (item->end)
			eData->xe -= eData->w + item->space;
		else
			eData->x += eData->w + item->space;
	} else {
		if (item->end)
			eData->ye -= eData->h + item->space;
		else
			eData->y += eData->h + item->space;
	}
	if (item->end) {
		W_MoveView(item->view, eData->xe, eData->ye);
	}
}

static void rearrange(WMBox * box)
{
	BoxData eData;

	eData.box = box;
	eData.x = eData.y = box->borderWidth;
	eData.w = eData.h = 1;
	eData.expands = 0;

	if (box->horizontal) {
		eData.ye = box->borderWidth;
		eData.xe = WMWidgetWidth(box) - box->borderWidth;
		eData.h = WMWidgetHeight(box) - 2 * box->borderWidth;
		eData.total = WMWidgetWidth(box) - 2 * box->borderWidth;
	} else {
		eData.xe = box->borderWidth;
		eData.ye = WMWidgetHeight(box) - box->borderWidth;
		eData.w = WMWidgetWidth(box) - 2 * box->borderWidth;
		eData.total = WMWidgetHeight(box) - 2 * box->borderWidth;
	}

	if (eData.w <= 0 || eData.h <= 0 || eData.total <= 0) {
		return;
	}

	WMMapArray(box->subviews, computeExpansion, &eData);
	WMMapArray(box->subviews, doRearrange, &eData);
}

void WMSetBoxBorderWidth(WMBox * box, unsigned width)
{
	if (box->borderWidth != width) {
		box->borderWidth = width;
		rearrange(box);
	}
}

void WMAddBoxSubview(WMBox * bPtr, WMView * view, Bool expand, Bool fill, int minSize, int maxSize, int space)
{
	SubviewItem *subView;

	subView = wmalloc(sizeof(SubviewItem));
	subView->view = view;
	subView->minSize = minSize;
	subView->maxSize = maxSize;
	subView->expand = expand;
	subView->fill = fill;
	subView->space = space;
	subView->end = 0;

	WMAddToArray(bPtr->subviews, subView);

	rearrange(bPtr);
}

void WMAddBoxSubviewAtEnd(WMBox * bPtr, WMView * view, Bool expand, Bool fill, int minSize, int maxSize, int space)
{
	SubviewItem *subView;

	subView = wmalloc(sizeof(SubviewItem));
	subView->view = view;
	subView->minSize = minSize;
	subView->maxSize = maxSize;
	subView->expand = expand;
	subView->fill = fill;
	subView->space = space;
	subView->end = 1;

	WMAddToArray(bPtr->subviews, subView);

	rearrange(bPtr);
}

static int matchView(const void *item, const void *cdata)
{
	return (((SubviewItem *) item)->view == (WMView *) cdata);
}

void WMRemoveBoxSubview(WMBox * bPtr, WMView * view)
{
	if (WMRemoveFromArrayMatching(bPtr->subviews, matchView, view)) {
		rearrange(bPtr);
	}
}

void WMSetBoxHorizontal(WMBox * box, Bool flag)
{
	/* make sure flag is either 0 or 1 no matter what true value was passed */
	flag = ((flag == 0) ? 0 : 1);
	if (box->horizontal != flag) {
		box->horizontal = flag;
		rearrange(box);
	}
}

static void destroyBox(Box * bPtr)
{
	WMFreeArray(bPtr->subviews);
	wfree(bPtr);
}

static void didResize(struct W_ViewDelegate *delegate, WMView * view)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) delegate;

	rearrange(view->self);
}

static void handleEvents(XEvent * event, void *data)
{
	Box *bPtr = (Box *) data;

	CHECK_CLASS(data, WC_Box);

	switch (event->type) {
	case DestroyNotify:
		destroyBox(bPtr);
		break;

	case ConfigureNotify:
		rearrange(bPtr);
		break;
	}
}
