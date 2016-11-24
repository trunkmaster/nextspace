
#include "WINGsP.h"

#undef STRICT_NEXT_BEHAVIOUR

typedef struct W_Slider {
	W_Class widgetClass;
	WMView *view;

	int minValue;
	int maxValue;

	int value;

	Pixmap knobPixmap;
	WMPixmap *backPixmap;

	WMAction *action;
	void *clientData;

	int knobThickness;

	struct {
		unsigned int continuous:1;

		unsigned int vertical:1;
		unsigned int dragging:1;
	} flags;

} Slider;

static void didResizeSlider(W_ViewDelegate * self, WMView * view);

W_ViewDelegate _SliderViewDelegate = {
	NULL,
	NULL,
	didResizeSlider,
	NULL,
	NULL
};

static void destroySlider(Slider * sPtr);
static void paintSlider(Slider * sPtr);

static void handleEvents(XEvent * event, void *data);
static void handleActionEvents(XEvent * event, void *data);

static void makeKnobPixmap(Slider * sPtr);

static void realizeObserver(void *self, WMNotification * not)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) not;

	makeKnobPixmap(self);
}

WMSlider *WMCreateSlider(WMWidget * parent)
{
	Slider *sPtr;

	sPtr = wmalloc(sizeof(Slider));
	sPtr->widgetClass = WC_Slider;

	sPtr->view = W_CreateView(W_VIEW(parent));
	if (!sPtr->view) {
		wfree(sPtr);
		return NULL;
	}
	sPtr->view->self = sPtr;

	sPtr->view->delegate = &_SliderViewDelegate;

	WMCreateEventHandler(sPtr->view, ExposureMask | StructureNotifyMask, handleEvents, sPtr);

	WMCreateEventHandler(sPtr->view, ButtonPressMask | ButtonReleaseMask
			     | EnterWindowMask | LeaveWindowMask | ButtonMotionMask, handleActionEvents, sPtr);

	W_ResizeView(sPtr->view, 100, 16);
	sPtr->flags.vertical = 0;
	sPtr->minValue = 0;
	sPtr->maxValue = 100;
	sPtr->value = 50;

	sPtr->knobThickness = 20;

	sPtr->flags.continuous = 1;

	WMAddNotificationObserver(realizeObserver, sPtr, WMViewRealizedNotification, sPtr->view);

	return sPtr;
}

void WMSetSliderImage(WMSlider * sPtr, WMPixmap * pixmap)
{
	if (sPtr->backPixmap)
		WMReleasePixmap(sPtr->backPixmap);

	sPtr->backPixmap = WMRetainPixmap(pixmap);

	if (sPtr->view->flags.mapped) {
		paintSlider(sPtr);
	}
}

void WMSetSliderKnobThickness(WMSlider * sPtr, int thickness)
{
	assert(thickness > 0);

	sPtr->knobThickness = thickness;

	if (sPtr->knobPixmap) {
		makeKnobPixmap(sPtr);
	}

	if (sPtr->view->flags.mapped) {
		paintSlider(sPtr);
	}
}

int WMGetSliderMinValue(WMSlider * slider)
{
	CHECK_CLASS(slider, WC_Slider);

	return slider->minValue;
}

int WMGetSliderMaxValue(WMSlider * slider)
{
	CHECK_CLASS(slider, WC_Slider);

	return slider->maxValue;
}

int WMGetSliderValue(WMSlider * slider)
{
	CHECK_CLASS(slider, WC_Slider);

	return slider->value;
}

void WMSetSliderMinValue(WMSlider * slider, int value)
{
	CHECK_CLASS(slider, WC_Slider);

	slider->minValue = value;
	if (slider->value < value) {
		slider->value = value;
		if (slider->view->flags.mapped)
			paintSlider(slider);
	}
}

void WMSetSliderMaxValue(WMSlider * slider, int value)
{
	CHECK_CLASS(slider, WC_Slider);

	slider->maxValue = value;
	if (slider->value > value) {
		slider->value = value;
		if (slider->view->flags.mapped)
			paintSlider(slider);
	}
}

void WMSetSliderValue(WMSlider * slider, int value)
{
	CHECK_CLASS(slider, WC_Slider);

	if (value < slider->minValue)
		slider->value = slider->minValue;
	else if (value > slider->maxValue)
		slider->value = slider->maxValue;
	else
		slider->value = value;

	if (slider->view->flags.mapped)
		paintSlider(slider);
}

void WMSetSliderContinuous(WMSlider * slider, Bool flag)
{
	CHECK_CLASS(slider, WC_Slider);

	slider->flags.continuous = ((flag == 0) ? 0 : 1);
}

void WMSetSliderAction(WMSlider * slider, WMAction * action, void *data)
{
	CHECK_CLASS(slider, WC_Slider);

	slider->action = action;
	slider->clientData = data;
}

static void makeKnobPixmap(Slider * sPtr)
{
	Pixmap pix;
	WMScreen *scr = sPtr->view->screen;
	int w, h;

	if (sPtr->flags.vertical) {
		w = sPtr->view->size.width - 2;
		h = sPtr->knobThickness;
	} else {
		w = sPtr->knobThickness;
		h = sPtr->view->size.height - 2;
	}

	pix = XCreatePixmap(scr->display, sPtr->view->window, w, h, scr->depth);
	XFillRectangle(scr->display, pix, WMColorGC(scr->gray), 0, 0, w, h);

	if (sPtr->knobThickness < 10) {
		W_DrawRelief(scr, pix, 0, 0, w, h, WRRaised);
	} else if (sPtr->flags.vertical) {
		XDrawLine(scr->display, pix, WMColorGC(scr->white), 0, 0, 0, h - 3);
		XDrawLine(scr->display, pix, WMColorGC(scr->white), 1, 0, 1, h - 3);
		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), w - 2, 1, w - 2, h / 2 - 2);
		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), w - 2, h / 2, w - 2, h - 2);

		XDrawLine(scr->display, pix, WMColorGC(scr->white), 0, 0, w - 2, 0);
		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), 1, h / 2 - 2, w - 3, h / 2 - 2);
		XDrawLine(scr->display, pix, WMColorGC(scr->white), 0, h / 2 - 1, w - 3, h / 2 - 1);

		XDrawLine(scr->display, pix, WMColorGC(scr->black), w - 1, 0, w - 1, h - 2);

		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), 0, h - 3, w - 2, h - 3);
		XDrawLine(scr->display, pix, WMColorGC(scr->black), 0, h - 2, w - 1, h - 2);
		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), 0, h - 1, w - 1, h - 1);
	} else {
		XDrawLine(scr->display, pix, WMColorGC(scr->white), 0, 0, w - 3, 0);

		XDrawLine(scr->display, pix, WMColorGC(scr->white), 0, 0, 0, h - 2);

		XDrawLine(scr->display, pix, WMColorGC(scr->white), 1, 0, 1, h - 3);
		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), w / 2 - 2, 1, w / 2 - 2, h - 3);
		XDrawLine(scr->display, pix, WMColorGC(scr->white), w / 2 - 1, 0, w / 2 - 1, h - 3);

		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), w - 3, 0, w - 3, h - 2);
		XDrawLine(scr->display, pix, WMColorGC(scr->black), w - 2, 0, w - 2, h - 2);
		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), w - 1, 0, w - 1, h - 1);

		XDrawLine(scr->display, pix, WMColorGC(scr->black), 1, h - 1, w / 2 + 1, h - 1);
		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), 1, h - 2, w / 2 - 2, h - 2);
		XDrawLine(scr->display, pix, WMColorGC(scr->darkGray), w / 2, h - 2, w - 3, h - 2);

		XDrawLine(scr->display, pix, WMColorGC(scr->black), 0, h - 1, w - 2, h - 1);
	}

	if (sPtr->knobPixmap)
		XFreePixmap(scr->display, sPtr->knobPixmap);
	sPtr->knobPixmap = pix;
}

static void didResizeSlider(W_ViewDelegate * self, WMView * view)
{
	Slider *sPtr = (Slider *) view->self;
	int width = sPtr->view->size.width;
	int height = sPtr->view->size.height;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	assert(width > 0);
	assert(height > 0);

	if (width > height) {
		if (sPtr->flags.vertical) {
			sPtr->flags.vertical = 0;
			if (sPtr->view->flags.realized)
				makeKnobPixmap(sPtr);
		}
	} else {
		if (!sPtr->flags.vertical) {
			sPtr->flags.vertical = 1;
			if (sPtr->view->flags.realized)
				makeKnobPixmap(sPtr);
		}
	}
}

static void paintSlider(Slider * sPtr)
{
	W_Screen *scr = sPtr->view->screen;
	GC bgc;
	GC wgc;
	GC lgc;
	WMSize size = sPtr->view->size;
	int pos;
	Pixmap buffer;

#define MINV sPtr->minValue
#define MAXV sPtr->maxValue
#define POSV sPtr->value

	bgc = WMColorGC(scr->black);
	wgc = WMColorGC(scr->white);
	lgc = WMColorGC(scr->gray);

	buffer = XCreatePixmap(scr->display, sPtr->view->window, size.width, size.height, scr->depth);

	if (sPtr->backPixmap) {
		WMSize size = WMGetPixmapSize(sPtr->backPixmap);

		XCopyArea(scr->display, WMGetPixmapXID(sPtr->backPixmap),
			  buffer, scr->copyGC, 0, 0, size.width, size.height, 1, 1);
	} else {
		XFillRectangle(scr->display, buffer, lgc, 0, 0, size.width, size.height);
		XFillRectangle(scr->display, buffer, scr->stippleGC, 0, 0, size.width, size.height);
	}

	if (sPtr->flags.vertical) {
		pos = (size.height - 2 - sPtr->knobThickness) * (POSV - MINV) / (MAXV - MINV) + 1;
		/* draw knob */
		XCopyArea(scr->display, sPtr->knobPixmap, buffer,
			  scr->copyGC, 0, 0, size.width - 2, sPtr->knobThickness, 1, pos);
	} else {
		pos = (size.width - 2 - sPtr->knobThickness) * (POSV - MINV) / (MAXV - MINV) + 1;
		/* draw knob */
		XCopyArea(scr->display, sPtr->knobPixmap, buffer,
			  scr->copyGC, 0, 0, sPtr->knobThickness, size.height, pos, 1);
	}

	XDrawLine(scr->display, buffer, bgc, 0, 0, 0, size.height - 1);
	XDrawLine(scr->display, buffer, bgc, 0, 0, size.width, 0);

	XDrawLine(scr->display, buffer, wgc, size.width - 1, 0, size.width - 1, size.height - 1);
	XDrawLine(scr->display, buffer, wgc, 0, size.height - 1, size.width - 1, size.height - 1);

	XCopyArea(scr->display, buffer, sPtr->view->window, scr->copyGC, 0, 0, size.width, size.height, 0, 0);
	XFreePixmap(scr->display, buffer);
}

static void handleEvents(XEvent * event, void *data)
{
	Slider *sPtr = (Slider *) data;

	CHECK_CLASS(data, WC_Slider);

	switch (event->type) {
	case Expose:
		if (event->xexpose.count != 0)
			break;
		paintSlider(sPtr);
		break;

	case DestroyNotify:
		destroySlider(sPtr);
		break;

	}
}

#define DECR_PART	1
#define KNOB_PART	2
#define INCR_PART	3

static int getSliderPart(Slider * sPtr, int x, int y)
{
	int p;
	int pos;
	WMSize size = sPtr->view->size;

	if (sPtr->flags.vertical) {
		p = y;
		pos = (size.height - 2 - sPtr->knobThickness) * (POSV - MINV) / (MAXV - MINV);
		if (p < pos)
			return INCR_PART;
		if (p > pos + sPtr->knobThickness)
			return DECR_PART;
		return KNOB_PART;
	} else {
		p = x;
		pos = (size.width - 2 - sPtr->knobThickness) * (POSV - MINV) / (MAXV - MINV);
		if (p < pos)
			return DECR_PART;
		if (p > pos + sPtr->knobThickness)
			return INCR_PART;
		return KNOB_PART;
	}
}

static int valueForMousePoint(Slider * sPtr, int x, int y)
{
	WMSize size = sPtr->view->size;
	int f;

	if (sPtr->flags.vertical) {
		f = (y - sPtr->knobThickness / 2) * (MAXV - MINV)
		    / ((int)size.height - 2 - sPtr->knobThickness);
	} else {
		f = (x - sPtr->knobThickness / 2) * (MAXV - MINV)
		    / ((int)size.width - 2 - sPtr->knobThickness);
	}

	f += sPtr->minValue;
	if (f < sPtr->minValue)
		f = sPtr->minValue;
	else if (f > sPtr->maxValue)
		f = sPtr->maxValue;

	return f;
}

static void handleActionEvents(XEvent * event, void *data)
{
	WMSlider *sPtr = (Slider *) data;

	CHECK_CLASS(data, WC_Slider);

	switch (event->type) {
	case ButtonPress:
		if (event->xbutton.button == WINGsConfiguration.mouseWheelDown && !sPtr->flags.dragging) {
			/* Wheel down */
			if (sPtr->value + 1 <= sPtr->maxValue) {
				WMSetSliderValue(sPtr, sPtr->value + 1);
				if (sPtr->flags.continuous && sPtr->action) {
					(*sPtr->action) (sPtr, sPtr->clientData);
				}
			}
		} else if (event->xbutton.button == WINGsConfiguration.mouseWheelUp && !sPtr->flags.dragging) {
			/* Wheel up */
			if (sPtr->value - 1 >= sPtr->minValue) {
				WMSetSliderValue(sPtr, sPtr->value - 1);
				if (sPtr->flags.continuous && sPtr->action) {
					(*sPtr->action) (sPtr, sPtr->clientData);
				}
			}
		} else if (getSliderPart(sPtr, event->xbutton.x, event->xbutton.y)
			   == KNOB_PART)
			sPtr->flags.dragging = 1;
		else {
#ifdef STRICT_NEXT_BEHAVIOUR
			sPtr->flags.dragging = 1;

			sPtr->value = valueForMousePoint(sPtr, event->xmotion.x, event->xmotion.y);
			paintSlider(sPtr);
#else
			int tmp;

			if (event->xbutton.button == Button2) {
				sPtr->flags.dragging = 1;

				sPtr->value = valueForMousePoint(sPtr, event->xmotion.x, event->xmotion.y);
				paintSlider(sPtr);
			} else {
				tmp = valueForMousePoint(sPtr, event->xmotion.x, event->xmotion.y);
				if (tmp < sPtr->value)
					tmp = sPtr->value - 1;
				else
					tmp = sPtr->value + 1;
				WMSetSliderValue(sPtr, tmp);
			}
#endif

			if (sPtr->flags.continuous && sPtr->action) {
				(*sPtr->action) (sPtr, sPtr->clientData);
			}
		}
		break;

	case ButtonRelease:
		if (!sPtr->flags.continuous && sPtr->action) {
			(*sPtr->action) (sPtr, sPtr->clientData);
		}
		sPtr->flags.dragging = 0;
		break;

	case MotionNotify:
		if (sPtr->flags.dragging) {
			sPtr->value = valueForMousePoint(sPtr, event->xmotion.x, event->xmotion.y);
			paintSlider(sPtr);

			if (sPtr->flags.continuous && sPtr->action) {
				(*sPtr->action) (sPtr, sPtr->clientData);
			}
		}
		break;
	}
}

static void destroySlider(Slider * sPtr)
{
	if (sPtr->knobPixmap)
		XFreePixmap(sPtr->view->screen->display, sPtr->knobPixmap);

	if (sPtr->backPixmap)
		WMReleasePixmap(sPtr->backPixmap);

	WMRemoveNotificationObserver(sPtr);

	wfree(sPtr);
}
