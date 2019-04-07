
#include "WINGsP.h"

typedef struct W_Label {
	W_Class widgetClass;
	W_View *view;

	char *caption;

	WMColor *textColor;
	WMFont *font;		/* if NULL, use default */

	W_Pixmap *image;

	struct {
		WMReliefType relief:3;
		WMImagePosition imagePosition:4;
		WMAlignment alignment:2;

		unsigned int noWrap:1;

		unsigned int redrawPending:1;
	} flags;
} Label;

#define DEFAULT_WIDTH		60
#define DEFAULT_HEIGHT		14
#define DEFAULT_ALIGNMENT	WALeft
#define DEFAULT_RELIEF		WRFlat
#define DEFAULT_IMAGE_POSITION	WIPNoImage

static void destroyLabel(Label * lPtr);
static void paintLabel(Label * lPtr);

static void handleEvents(XEvent * event, void *data);

WMLabel *WMCreateLabel(WMWidget * parent)
{
	Label *lPtr;

	lPtr = wmalloc(sizeof(Label));

	lPtr->widgetClass = WC_Label;

	lPtr->view = W_CreateView(W_VIEW(parent));
	if (!lPtr->view) {
		wfree(lPtr);
		return NULL;
	}
	lPtr->view->self = lPtr;

	lPtr->textColor = WMRetainColor(lPtr->view->screen->black);

	WMCreateEventHandler(lPtr->view, ExposureMask | StructureNotifyMask, handleEvents, lPtr);

	W_ResizeView(lPtr->view, DEFAULT_WIDTH, DEFAULT_HEIGHT);
	lPtr->flags.alignment = DEFAULT_ALIGNMENT;
	lPtr->flags.relief = DEFAULT_RELIEF;
	lPtr->flags.imagePosition = DEFAULT_IMAGE_POSITION;
	lPtr->flags.noWrap = 1;

	return lPtr;
}

void WMSetLabelImage(WMLabel * lPtr, WMPixmap * image)
{
	if (lPtr->image != NULL)
		WMReleasePixmap(lPtr->image);

	if (image)
		lPtr->image = WMRetainPixmap(image);
	else
		lPtr->image = NULL;

	if (lPtr->view->flags.realized) {
		paintLabel(lPtr);
	}
}

WMPixmap *WMGetLabelImage(WMLabel * lPtr)
{
	return lPtr->image;
}

char *WMGetLabelText(WMLabel * lPtr)
{
	return lPtr->caption;
}

void WMSetLabelImagePosition(WMLabel * lPtr, WMImagePosition position)
{
	lPtr->flags.imagePosition = position;
	if (lPtr->view->flags.realized) {
		paintLabel(lPtr);
	}
}

void WMSetLabelTextAlignment(WMLabel * lPtr, WMAlignment alignment)
{
	lPtr->flags.alignment = alignment;
	if (lPtr->view->flags.realized) {
		paintLabel(lPtr);
	}
}

void WMSetLabelRelief(WMLabel * lPtr, WMReliefType relief)
{
	lPtr->flags.relief = relief;
	if (lPtr->view->flags.realized) {
		paintLabel(lPtr);
	}
}

void WMSetLabelText(WMLabel * lPtr, const char *text)
{
	if (lPtr->caption)
		wfree(lPtr->caption);

	if (text != NULL) {
		lPtr->caption = wstrdup(text);
	} else {
		lPtr->caption = NULL;
	}
	if (lPtr->view->flags.realized) {
		paintLabel(lPtr);
	}
}

WMFont *WMGetLabelFont(WMLabel * lPtr)
{
	return lPtr->font;
}

void WMSetLabelFont(WMLabel * lPtr, WMFont * font)
{
	if (lPtr->font != NULL)
		WMReleaseFont(lPtr->font);
	if (font)
		lPtr->font = WMRetainFont(font);
	else
		lPtr->font = NULL;

	if (lPtr->view->flags.realized) {
		paintLabel(lPtr);
	}
}

void WMSetLabelTextColor(WMLabel * lPtr, WMColor * color)
{
	if (lPtr->textColor)
		WMReleaseColor(lPtr->textColor);
	lPtr->textColor = WMRetainColor(color);

	if (lPtr->view->flags.realized) {
		paintLabel(lPtr);
	}
}

void WMSetLabelWraps(WMLabel * lPtr, Bool flag)
{
	flag = ((flag == 0) ? 0 : 1);
	if (lPtr->flags.noWrap != !flag) {
		lPtr->flags.noWrap = !flag;
		if (lPtr->view->flags.realized)
			paintLabel(lPtr);
	}
}

static void paintLabel(Label * lPtr)
{
	W_Screen *scrPtr = lPtr->view->screen;

	W_PaintTextAndImage(lPtr->view, !lPtr->flags.noWrap,
			    lPtr->textColor ? lPtr->textColor : scrPtr->black,
			    (lPtr->font != NULL ? lPtr->font : scrPtr->normalFont),
			    lPtr->flags.relief, lPtr->caption,
			    lPtr->flags.alignment, lPtr->image, lPtr->flags.imagePosition, NULL, 0);
}

static void handleEvents(XEvent * event, void *data)
{
	Label *lPtr = (Label *) data;

	CHECK_CLASS(data, WC_Label);

	switch (event->type) {
	case Expose:
		if (event->xexpose.count != 0)
			break;
		paintLabel(lPtr);
		break;

	case DestroyNotify:
		destroyLabel(lPtr);
		break;
	}
}

static void destroyLabel(Label * lPtr)
{
	if (lPtr->textColor)
		WMReleaseColor(lPtr->textColor);

	if (lPtr->caption)
		wfree(lPtr->caption);

	if (lPtr->font)
		WMReleaseFont(lPtr->font);

	if (lPtr->image)
		WMReleasePixmap(lPtr->image);

	wfree(lPtr);
}
