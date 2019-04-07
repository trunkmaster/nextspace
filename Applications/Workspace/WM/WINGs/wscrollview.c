
#include "WINGsP.h"

typedef struct W_ScrollView {
	W_Class widgetClass;
	WMView *view;

	WMView *contentView;
	WMView *viewport;

	WMScroller *vScroller;
	WMScroller *hScroller;

	short lineScroll;
	short pageScroll;

	struct {
		WMReliefType relief:3;
		unsigned int hasVScroller:1;
		unsigned int hasHScroller:1;

	} flags;

} ScrollView;

static void destroyScrollView(ScrollView * sPtr);

static void paintScrollView(ScrollView * sPtr);
static void handleEvents(XEvent * event, void *data);
static void handleViewportEvents(XEvent * event, void *data);
static void resizeScrollView(W_ViewDelegate *self, WMView *view);
static void updateScrollerProportion(ScrollView *sPtr);

W_ViewDelegate _ScrollViewViewDelegate = {
	NULL,
	NULL,
	resizeScrollView,
	NULL,
	NULL
};

WMScrollView *WMCreateScrollView(WMWidget * parent)
{
	ScrollView *sPtr;

	sPtr = wmalloc(sizeof(ScrollView));
	sPtr->widgetClass = WC_ScrollView;

	sPtr->view = W_CreateView(W_VIEW(parent));
	if (!sPtr->view) {
		wfree(sPtr);
		return NULL;
	}
	sPtr->viewport = W_CreateView(sPtr->view);
	if (!sPtr->viewport) {
		W_DestroyView(sPtr->view);
		wfree(sPtr);
		return NULL;
	}
	sPtr->view->self = sPtr;
	sPtr->viewport->self = sPtr;

	sPtr->view->delegate = &_ScrollViewViewDelegate;

	sPtr->viewport->flags.mapWhenRealized = 1;

	WMCreateEventHandler(sPtr->view, StructureNotifyMask | ExposureMask, handleEvents, sPtr);
	WMCreateEventHandler(sPtr->viewport, SubstructureNotifyMask, handleViewportEvents, sPtr);

	sPtr->lineScroll = 4;

	sPtr->pageScroll = 0;

	return sPtr;
}

static void applyScrollerValues(WMScrollView * sPtr)
{
	int x, y;

	if (sPtr->contentView == NULL)
		return;

	if (sPtr->flags.hasHScroller) {
		float v = WMGetScrollerValue(sPtr->hScroller);
		int size;

		size = sPtr->contentView->size.width - sPtr->viewport->size.width;

		x = v * size;
	} else {
		x = 0;
	}

	if (sPtr->flags.hasVScroller) {
		float v = WMGetScrollerValue(sPtr->vScroller);

		int size;

		size = sPtr->contentView->size.height - sPtr->viewport->size.height;

		y = v * size;
	} else {
		y = 0;
	}

	x = WMAX(0, x);
	y = WMAX(0, y);

	W_MoveView(sPtr->contentView, -x, -y);

	W_RaiseView(sPtr->viewport);
}

static void reorganizeInterior(WMScrollView * sPtr)
{
	int hx, hy, hw;
	int vx, vy, vh;
	int cx, cy, cw, ch;

	cw = hw = sPtr->view->size.width;
	vh = ch = sPtr->view->size.height;

	if (sPtr->flags.relief == WRSimple) {
		cw -= 2;
		ch -= 2;
		cx = 1;
		cy = 1;
	} else if (sPtr->flags.relief != WRFlat) {
		cw -= 3;
		ch -= 3;
		cx = 2;
		cy = 2;
	} else {
		cx = 0;
		cy = 0;
	}

	if (sPtr->flags.hasHScroller) {
		int h = 20;

		ch -= h;

		if (sPtr->flags.relief == WRSimple) {
			hx = 0;
			hy = sPtr->view->size.height - h;
		} else if (sPtr->flags.relief != WRFlat) {
			hx = 1;
			hy = sPtr->view->size.height - h - 1;
			hw -= 2;
		} else {
			hx = 0;
			hy = sPtr->view->size.height - h;
		}
	} else {
		/* make compiler shutup */
		hx = 0;
		hy = 0;
	}

	if (sPtr->flags.hasVScroller) {
		int w = 20;
		cw -= w;
		cx += w;
		hx += w - 1;
		hw -= w - 1;

		if (sPtr->flags.relief == WRSimple) {
			vx = 0;
			vy = 0;
		} else if (sPtr->flags.relief != WRFlat) {
			vx = 1;
			vy = 1;
			vh -= 2;
		} else {
			vx = 0;
			vy = 0;
		}
	} else {
		/* make compiler shutup */
		vx = 0;
		vy = 0;
	}

	W_ResizeView(sPtr->viewport, cw, ch);
	W_MoveView(sPtr->viewport, cx, cy);

	if (sPtr->flags.hasHScroller) {
		WMResizeWidget(sPtr->hScroller, hw, 20);
		WMMoveWidget(sPtr->hScroller, hx, hy);
	}
	if (sPtr->flags.hasVScroller) {
		WMResizeWidget(sPtr->vScroller, 20, vh);
		WMMoveWidget(sPtr->vScroller, vx, vy);
	}

	applyScrollerValues(sPtr);
}

static void resizeScrollView(W_ViewDelegate * self, WMView * view)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	reorganizeInterior(view->self);
	updateScrollerProportion(view->self);
}

void WMResizeScrollViewContent(WMScrollView * sPtr, unsigned int width, unsigned int height)
{
	int w, h, x;

	w = width;
	h = height;

	x = 0;
	if (sPtr->flags.relief == WRSimple) {
		w += 2;
		h += 2;
	} else if (sPtr->flags.relief != WRFlat) {
		w += 4;
		h += 4;
		x = 1;
	}

	if (sPtr->flags.hasVScroller) {
		WMResizeWidget(sPtr->vScroller, 20, h);
		width -= W_VIEW(sPtr->vScroller)->size.width;
	}

	if (sPtr->flags.hasHScroller) {
		WMResizeWidget(sPtr->hScroller, w, 20);
		WMMoveWidget(sPtr->hScroller, x, h);
		height -= W_VIEW(sPtr->hScroller)->size.height;
	}

	W_ResizeView(sPtr->view, w, h);

	W_ResizeView(sPtr->viewport, width, height);
}

void WMSetScrollViewLineScroll(WMScrollView * sPtr, int amount)
{
	assert(amount > 0);

	sPtr->lineScroll = amount;
}

void WMSetScrollViewPageScroll(WMScrollView * sPtr, int amount)
{
	assert(amount >= 0);

	sPtr->pageScroll = amount;
}

WMRect WMGetScrollViewVisibleRect(WMScrollView * sPtr)
{
	WMRect rect;

	rect.pos.x = -sPtr->contentView->pos.x;
	rect.pos.y = -sPtr->contentView->pos.y;
	rect.size = sPtr->viewport->size;

	return rect;
}

void WMScrollViewScrollPoint(WMScrollView * sPtr, WMPoint point)
{
	float xsize, ysize;
	float xpos, ypos;

	xsize = sPtr->contentView->size.width - sPtr->viewport->size.width;
	ysize = sPtr->contentView->size.height - sPtr->viewport->size.height;

	xpos = point.x / xsize;
	ypos = point.y / ysize;

	if (sPtr->hScroller)
		WMSetScrollerParameters(sPtr->hScroller, xpos, WMGetScrollerKnobProportion(sPtr->hScroller));
	if (sPtr->vScroller)
		WMSetScrollerParameters(sPtr->vScroller, ypos, WMGetScrollerKnobProportion(sPtr->vScroller));

	W_MoveView(sPtr->contentView, -point.x, -point.y);
}

static void doScrolling(WMWidget * self, void *data)
{
	ScrollView *sPtr = (ScrollView *) data;
	float value;
	int pos;
	int vpsize;
	float size;

	if (sPtr->hScroller == (WMScroller *) self) {
		pos = -sPtr->contentView->pos.x;
		size = sPtr->contentView->size.width - sPtr->viewport->size.width;
		vpsize = sPtr->viewport->size.width - sPtr->pageScroll;
	} else {
		pos = -sPtr->contentView->pos.y;
		size = sPtr->contentView->size.height - sPtr->viewport->size.height;
		vpsize = sPtr->viewport->size.height - sPtr->pageScroll;
	}
	if (vpsize <= 0)
		vpsize = 1;

	switch (WMGetScrollerHitPart(self)) {
	case WSDecrementLine:
		if (pos > 0) {
			pos -= sPtr->lineScroll;
			if (pos < 0)
				pos = 0;
			value = (float)pos / size;
			WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		}
		break;
	case WSIncrementLine:
		if (pos < size) {
			pos += sPtr->lineScroll;
			if (pos > size)
				pos = size;
			value = (float)pos / size;
			WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		}
		break;

	case WSKnob:
		value = WMGetScrollerValue(self);
		pos = value * size;
		break;

	case WSDecrementPage:
		if (pos > 0) {
			pos -= vpsize;
			if (pos < 0)
				pos = 0;
			value = (float)pos / size;
			WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		}
		break;

	case WSDecrementWheel:
		if (pos > 0) {
			pos -= vpsize / 3;
			if (pos < 0)
				pos = 0;
			value = (float)pos / size;
			WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		}
		break;

	case WSIncrementPage:
		if (pos < size) {
			pos += vpsize;
			if (pos > size)
				pos = size;
			value = (float)pos / size;
			WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		}
		break;

	case WSIncrementWheel:
		if (pos < size) {
			pos += vpsize / 3;
			if (pos > size)
				pos = size;
			value = (float)pos / size;
			WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		}
		break;

	case WSNoPart:
	case WSKnobSlot:
		break;
	}

	if (sPtr->hScroller == (WMScroller *) self) {
		W_MoveView(sPtr->contentView, -pos, sPtr->contentView->pos.y);
	} else {
		W_MoveView(sPtr->contentView, sPtr->contentView->pos.x, -pos);
	}
}

WMScroller *WMGetScrollViewHorizontalScroller(WMScrollView * sPtr)
{
	return sPtr->hScroller;
}

WMScroller *WMGetScrollViewVerticalScroller(WMScrollView * sPtr)
{
	return sPtr->vScroller;
}

void WMSetScrollViewHasHorizontalScroller(WMScrollView * sPtr, Bool flag)
{
	if (flag) {
		if (sPtr->flags.hasHScroller)
			return;
		sPtr->flags.hasHScroller = 1;

		sPtr->hScroller = WMCreateScroller(sPtr);
		WMSetScrollerAction(sPtr->hScroller, doScrolling, sPtr);
		/* make it a horiz. scroller */
		WMResizeWidget(sPtr->hScroller, 2, 1);

		if (W_VIEW_REALIZED(sPtr->view)) {
			WMRealizeWidget(sPtr->hScroller);
		}

		reorganizeInterior(sPtr);

		WMMapWidget(sPtr->hScroller);
	} else {
		if (!sPtr->flags.hasHScroller)
			return;

		WMUnmapWidget(sPtr->hScroller);
		WMDestroyWidget(sPtr->hScroller);
		sPtr->hScroller = NULL;
		sPtr->flags.hasHScroller = 0;

		reorganizeInterior(sPtr);
	}
}

void WMSetScrollViewHasVerticalScroller(WMScrollView * sPtr, Bool flag)
{
	if (flag) {
		if (sPtr->flags.hasVScroller)
			return;
		sPtr->flags.hasVScroller = 1;

		sPtr->vScroller = WMCreateScroller(sPtr);
		WMSetScrollerAction(sPtr->vScroller, doScrolling, sPtr);
		WMSetScrollerArrowsPosition(sPtr->vScroller, WSAMaxEnd);
		/* make it a vert. scroller */
		WMResizeWidget(sPtr->vScroller, 1, 2);

		if (W_VIEW_REALIZED(sPtr->view)) {
			WMRealizeWidget(sPtr->vScroller);
		}

		reorganizeInterior(sPtr);

		WMMapWidget(sPtr->vScroller);
	} else {
		if (!sPtr->flags.hasVScroller)
			return;
		sPtr->flags.hasVScroller = 0;

		WMUnmapWidget(sPtr->vScroller);
		WMDestroyWidget(sPtr->vScroller);
		sPtr->vScroller = NULL;

		reorganizeInterior(sPtr);
	}
}

void WMSetScrollViewContentView(WMScrollView * sPtr, WMView * view)
{
	assert(sPtr->contentView == NULL);

	sPtr->contentView = view;

	W_ReparentView(sPtr->contentView, sPtr->viewport, 0, 0);

	if (sPtr->flags.hasHScroller) {
		float prop;

		prop = (float)sPtr->viewport->size.width / sPtr->contentView->size.width;
		WMSetScrollerParameters(sPtr->hScroller, 0, prop);
	}
	if (sPtr->flags.hasVScroller) {
		float prop;

		prop = (float)sPtr->viewport->size.height / sPtr->contentView->size.height;

		WMSetScrollerParameters(sPtr->vScroller, 0, prop);
	}
}

void WMSetScrollViewRelief(WMScrollView * sPtr, WMReliefType type)
{
	sPtr->flags.relief = type;

	reorganizeInterior(sPtr);

	if (sPtr->view->flags.mapped)
		paintScrollView(sPtr);

}

static void paintScrollView(ScrollView * sPtr)
{
	W_DrawRelief(sPtr->view->screen, sPtr->view->window, 0, 0,
		     sPtr->view->size.width, sPtr->view->size.height, sPtr->flags.relief);
}

static void updateScrollerProportion(ScrollView * sPtr)
{
	float prop, value;
	float oldV, oldP;

	if (sPtr->flags.hasHScroller) {
		oldV = WMGetScrollerValue(sPtr->hScroller);
		oldP = WMGetScrollerKnobProportion(sPtr->hScroller);

		prop = (float)sPtr->viewport->size.width / (float)sPtr->contentView->size.width;

		if (oldP < 1.0F)
			value = (prop * oldV) / oldP;
		else
			value = 0;
		WMSetScrollerParameters(sPtr->hScroller, value, prop);
	}
	if (sPtr->flags.hasVScroller) {
		oldV = WMGetScrollerValue(sPtr->vScroller);
		oldP = WMGetScrollerKnobProportion(sPtr->vScroller);

		prop = (float)sPtr->viewport->size.height / (float)sPtr->contentView->size.height;

		if (oldP < 1.0F)
			value = (prop * oldV) / oldP;
		else
			value = 0;
		WMSetScrollerParameters(sPtr->vScroller, value, prop);
	}
	applyScrollerValues(sPtr);
}

static void handleViewportEvents(XEvent * event, void *data)
{
	ScrollView *sPtr = (ScrollView *) data;

	if (sPtr->contentView && event->xconfigure.window == sPtr->contentView->window)
		updateScrollerProportion(sPtr);
}

static void handleEvents(XEvent * event, void *data)
{
	ScrollView *sPtr = (ScrollView *) data;

	CHECK_CLASS(data, WC_ScrollView);

	switch (event->type) {
	case Expose:
		if (event->xexpose.count != 0)
			break;
		if (event->xexpose.serial == 0)	/* means it's artificial */
			W_RedisplayView(sPtr->contentView);
		else
			paintScrollView(sPtr);
		break;

	case DestroyNotify:
		destroyScrollView(sPtr);
		break;

	}
}

static void destroyScrollView(ScrollView * sPtr)
{
	wfree(sPtr);
}
