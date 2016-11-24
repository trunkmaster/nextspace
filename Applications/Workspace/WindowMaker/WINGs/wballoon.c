
#include "wconfig.h"
#include "WINGsP.h"

#ifdef USE_XSHAPE
#include <X11/extensions/shape.h>
#endif

typedef struct W_Balloon {
	W_View *view;

	WMHashTable *table;	/* Table from view ptr to text */

	WMColor *backColor;
	WMColor *textColor;
	WMFont *font;

	WMHandlerID timer;	/* timer for showing balloon */

	WMHandlerID noDelayTimer;

	int delay;

	Window forWindow;	/* window for which the balloon
				 * is being show in the moment */

	struct {
		WMAlignment alignment:2;
		unsigned enabled:1;

		unsigned noDelay:1;
	} flags;
} Balloon;

#define DEFAULT_WIDTH		60
#define DEFAULT_HEIGHT		14
#define DEFAULT_ALIGNMENT	WALeft
#define DEFAULT_DELAY		500

#define NO_DELAY_DELAY		150

static void destroyBalloon(Balloon * bPtr);

static void handleEvents(XEvent * event, void *data);

static void showText(Balloon * bPtr, int x, int y, int w, int h, const char *text);

struct W_Balloon *W_CreateBalloon(WMScreen * scr)
{
	Balloon *bPtr;

	bPtr = wmalloc(sizeof(Balloon));

	bPtr->view = W_CreateUnmanagedTopView(scr);
	if (!bPtr->view) {
		wfree(bPtr);
		return NULL;
	}
	bPtr->view->self = bPtr;

	bPtr->textColor = WMRetainColor(bPtr->view->screen->black);

	WMCreateEventHandler(bPtr->view, StructureNotifyMask, handleEvents, bPtr);

	W_ResizeView(bPtr->view, DEFAULT_WIDTH, DEFAULT_HEIGHT);
	bPtr->flags.alignment = DEFAULT_ALIGNMENT;

	bPtr->table = WMCreateHashTable(WMIntHashCallbacks);

	bPtr->delay = DEFAULT_DELAY;

	bPtr->flags.enabled = 1;

	return bPtr;
}

void WMSetBalloonTextAlignment(WMScreen * scr, WMAlignment alignment)
{
	scr->balloon->flags.alignment = alignment;

}

void WMSetBalloonTextForView(const char *text, WMView * view)
{
	char *oldText = NULL;
	WMScreen *scr = view->screen;

	if (text) {
		oldText = WMHashInsert(scr->balloon->table, view, wstrdup(text));
	} else {
		oldText = WMHashGet(scr->balloon->table, view);

		WMHashRemove(scr->balloon->table, view);
	}

	if (oldText) {
		wfree(oldText);
	}
}

void WMSetBalloonFont(WMScreen * scr, WMFont * font)
{
	Balloon *bPtr = scr->balloon;

	if (bPtr->font != NULL)
		WMReleaseFont(bPtr->font);

	if (font)
		bPtr->font = WMRetainFont(font);
	else
		bPtr->font = NULL;
}

void WMSetBalloonTextColor(WMScreen * scr, WMColor * color)
{
	Balloon *bPtr = scr->balloon;

	if (bPtr->textColor)
		WMReleaseColor(bPtr->textColor);

	bPtr->textColor = WMRetainColor(color);
}

void WMSetBalloonDelay(WMScreen * scr, int delay)
{
	scr->balloon->delay = delay;
}

void WMSetBalloonEnabled(WMScreen * scr, Bool flag)
{
	scr->balloon->flags.enabled = ((flag == 0) ? 0 : 1);

	W_UnmapView(scr->balloon->view);
}

static void clearNoDelay(void *data)
{
	Balloon *bPtr = (Balloon *) data;

	bPtr->flags.noDelay = 0;
	bPtr->noDelayTimer = NULL;
}

void W_BalloonHandleLeaveView(WMView * view)
{
	Balloon *bPtr = view->screen->balloon;

	if (bPtr->forWindow == view->window) {
		if (bPtr->view->flags.mapped) {
			W_UnmapView(bPtr->view);
			bPtr->noDelayTimer = WMAddTimerHandler(NO_DELAY_DELAY, clearNoDelay, bPtr);
		}
		if (bPtr->timer)
			WMDeleteTimerHandler(bPtr->timer);

		bPtr->timer = NULL;

		bPtr->forWindow = None;
	}
}

/*
 * botar balao perto do cursor
 * so mapear balao se o mouse ficar parado pelo delay
 *
 */

static void showBalloon(void *data)
{
	char *text;
	WMView *view = (WMView *) data;
	Balloon *bPtr = view->screen->balloon;
	int x, y;
	Window foo;

	bPtr->timer = NULL;

	text = WMHashGet(bPtr->table, view);
	if (!text)
		return;

	XTranslateCoordinates(view->screen->display, view->window, view->screen->rootWin, 0, 0, &x, &y, &foo);

	if (!bPtr->view->flags.realized)
		W_RealizeView(bPtr->view);

	showText(bPtr, x, y, view->size.width, view->size.height, text);

	bPtr->flags.noDelay = 1;
}

void W_BalloonHandleEnterView(WMView * view)
{
	Balloon *bPtr = view->screen->balloon;
	char *text;

	if (!bPtr->flags.enabled)
		return;

	text = WMHashGet(bPtr->table, view);
	if (!text) {
		if (bPtr->view->flags.realized)
			W_UnmapView(bPtr->view);

		return;
	}

	if (bPtr->timer)
		WMDeleteTimerHandler(bPtr->timer);
	bPtr->timer = NULL;

	if (bPtr->noDelayTimer)
		WMDeleteTimerHandler(bPtr->noDelayTimer);
	bPtr->noDelayTimer = NULL;

	bPtr->forWindow = view->window;

	if (bPtr->flags.noDelay) {
		bPtr->timer = NULL;

		showBalloon(view);
	} else {
		bPtr->timer = WMAddTimerHandler(bPtr->delay, showBalloon, view);
	}
}

#define TOP	0
#define BOTTOM	1
#define LEFT	0
#define RIGHT	2

#define 	SPACE	12

static void drawBalloon(WMScreen * scr, Pixmap bitmap, Pixmap pix, int x, int y, int w, int h, int side)
{
	Display *dpy = scr->display;
	WMColor *white = WMWhiteColor(scr);
	WMColor *black = WMBlackColor(scr);
	GC bgc = scr->monoGC;
	GC gc = WMColorGC(white);
	int rad = h * 3 / 10;
	XPoint pt[3], ipt[3];
	int w1;

	/* outline */
	XSetForeground(dpy, bgc, 1);

	XFillArc(dpy, bitmap, bgc, x, y, rad, rad, 90 * 64, 90 * 64);
	XFillArc(dpy, bitmap, bgc, x, y + h - 1 - rad, rad, rad, 180 * 64, 90 * 64);

	XFillArc(dpy, bitmap, bgc, x + w - 1 - rad, y, rad, rad, 0 * 64, 90 * 64);
	XFillArc(dpy, bitmap, bgc, x + w - 1 - rad, y + h - 1 - rad, rad, rad, 270 * 64, 90 * 64);

	XFillRectangle(dpy, bitmap, bgc, x, y + rad / 2, w, h - rad);
	XFillRectangle(dpy, bitmap, bgc, x + rad / 2, y, w - rad, h);

	/* interior */
	XFillArc(dpy, pix, gc, x + 1, y + 1, rad, rad, 90 * 64, 90 * 64);
	XFillArc(dpy, pix, gc, x + 1, y + h - 2 - rad, rad, rad, 180 * 64, 90 * 64);

	XFillArc(dpy, pix, gc, x + w - 2 - rad, y + 1, rad, rad, 0 * 64, 90 * 64);
	XFillArc(dpy, pix, gc, x + w - 2 - rad, y + h - 2 - rad, rad, rad, 270 * 64, 90 * 64);

	XFillRectangle(dpy, pix, gc, x + 1, y + 1 + rad / 2, w - 2, h - 2 - rad);
	XFillRectangle(dpy, pix, gc, x + 1 + rad / 2, y + 1, w - 2 - rad, h - 2);

	if (side & BOTTOM) {
		pt[0].y = y + h - 1;
		pt[1].y = y + h - 1 + SPACE;
		pt[2].y = y + h - 1;
		ipt[0].y = pt[0].y - 1;
		ipt[1].y = pt[1].y - 1;
		ipt[2].y = pt[2].y - 1;
	} else {
		pt[0].y = y;
		pt[1].y = y - SPACE;
		pt[2].y = y;
		ipt[0].y = pt[0].y + 1;
		ipt[1].y = pt[1].y + 1;
		ipt[2].y = pt[2].y + 1;
	}

	/*w1 = WMAX(h, 24); */
	w1 = WMAX(h, 21);

	if (side & RIGHT) {
		pt[0].x = x + w - w1 + 2 * w1 / 16;
		pt[1].x = x + w - w1 + 11 * w1 / 16;
		pt[2].x = x + w - w1 + 7 * w1 / 16;
		ipt[0].x = x + 1 + w - w1 + 2 * (w1 - 1) / 16;
		ipt[1].x = x + 1 + w - w1 + 11 * (w1 - 1) / 16;
		ipt[2].x = x + 1 + w - w1 + 7 * (w1 - 1) / 16;
		/*ipt[0].x = pt[0].x+1;
		   ipt[1].x = pt[1].x;
		   ipt[2].x = pt[2].x; */
	} else {
		pt[0].x = x + w1 - 2 * w1 / 16;
		pt[1].x = x + w1 - 11 * w1 / 16;
		pt[2].x = x + w1 - 7 * w1 / 16;
		ipt[0].x = x - 1 + w1 - 2 * (w1 - 1) / 16;
		ipt[1].x = x - 1 + w1 - 11 * (w1 - 1) / 16;
		ipt[2].x = x - 1 + w1 - 7 * (w1 - 1) / 16;
		/*ipt[0].x = pt[0].x-1;
		   ipt[1].x = pt[1].x;
		   ipt[2].x = pt[2].x; */
	}

	XFillPolygon(dpy, bitmap, bgc, pt, 3, Convex, CoordModeOrigin);
	XFillPolygon(dpy, pix, gc, ipt, 3, Convex, CoordModeOrigin);

	/* fix outline */
	XDrawLines(dpy, pix, WMColorGC(black), pt, 3, CoordModeOrigin);
	if (side & RIGHT) {
		pt[0].x++;
		pt[2].x--;
	} else {
		pt[0].x--;
		pt[2].x++;
	}
	XDrawLines(dpy, pix, WMColorGC(black), pt, 3, CoordModeOrigin);

	WMReleaseColor(white);
	WMReleaseColor(black);
}

static Pixmap makePixmap(WMScreen * scr, int width, int height, int side, Pixmap * mask)
{
	Display *dpy = WMScreenDisplay(scr);
	Pixmap bitmap;
	Pixmap pixmap;
	int x, y;
	WMColor *black = WMBlackColor(scr);

	bitmap = XCreatePixmap(dpy, scr->rootWin, width + SPACE, height + SPACE, 1);

	XSetForeground(dpy, scr->monoGC, 0);
	XFillRectangle(dpy, bitmap, scr->monoGC, 0, 0, width + SPACE, height + SPACE);

	pixmap = XCreatePixmap(dpy, scr->rootWin, width + SPACE, height + SPACE, scr->depth);

	XFillRectangle(dpy, pixmap, WMColorGC(black), 0, 0, width + SPACE, height + SPACE);

	if (side & BOTTOM) {
		y = 0;
	} else {
		y = SPACE;
	}
	x = 0;

	drawBalloon(scr, bitmap, pixmap, x, y, width, height, side);

	*mask = bitmap;

	WMReleaseColor(black);

	return pixmap;
}

static void showText(Balloon * bPtr, int x, int y, int w, int h, const char *text)
{
	WMScreen *scr = bPtr->view->screen;
	Display *dpy = WMScreenDisplay(scr);
	int width;
	int height;
	Pixmap pixmap;
	Pixmap mask;
	WMFont *font = bPtr->font ? bPtr->font : scr->normalFont;
	int textHeight;
	int side = 0;
	int ty;
	int bx, by;

	{
		int w;
		const char *ptr, *ptr2;

		ptr2 = ptr = text;
		width = 0;
		while (ptr && ptr2) {
			ptr2 = strchr(ptr, '\n');
			if (ptr2) {
				w = WMWidthOfString(font, ptr, ptr2 - ptr);
			} else {
				w = WMWidthOfString(font, ptr, strlen(ptr));
			}
			if (w > width)
				width = w;
			ptr = ptr2 + 1;
		}
	}

	width += 16;

	textHeight = W_GetTextHeight(font, text, width, False);

	height = textHeight + 4;

	if (height < 16)
		height = 16;
	if (width < height)
		width = height;

	if (x + width > scr->rootView->size.width) {
		side = RIGHT;
		bx = x - width + w / 2;
		if (bx < 0)
			bx = 0;
	} else {
		side = LEFT;
		bx = x + w / 2;
	}
	if (bx + width > scr->rootView->size.width)
		bx = scr->rootView->size.width - width;

	if (y - (height + SPACE) < 0) {
		side |= TOP;
		by = y + h - 1;
		ty = SPACE;
	} else {
		side |= BOTTOM;
		by = y - (height + SPACE);
		ty = 0;
	}
	pixmap = makePixmap(scr, width, height, side, &mask);

	W_PaintText(bPtr->view, pixmap, font, 8, ty + (height - textHeight) / 2,
		    width, bPtr->flags.alignment,
		    bPtr->textColor ? bPtr->textColor : scr->black, False, text, strlen(text));

	XSetWindowBackgroundPixmap(dpy, bPtr->view->window, pixmap);

	W_ResizeView(bPtr->view, width, height + SPACE);

	XFreePixmap(dpy, pixmap);

#ifdef USE_XSHAPE
	XShapeCombineMask(dpy, bPtr->view->window, ShapeBounding, 0, 0, mask, ShapeSet);
#endif
	XFreePixmap(dpy, mask);

	W_MoveView(bPtr->view, bx, by);

	W_MapView(bPtr->view);
}

static void handleEvents(XEvent * event, void *data)
{
	Balloon *bPtr = (Balloon *) data;

	switch (event->type) {
	case DestroyNotify:
		destroyBalloon(bPtr);
		break;
	}
}

static void destroyBalloon(Balloon * bPtr)
{
	WMHashEnumerator e;
	char *str;

	e = WMEnumerateHashTable(bPtr->table);

	while ((str = WMNextHashEnumeratorItem(&e))) {
		wfree(str);
	}
	WMFreeHashTable(bPtr->table);

	if (bPtr->textColor)
		WMReleaseColor(bPtr->textColor);

	if (bPtr->font)
		WMReleaseFont(bPtr->font);

	wfree(bPtr);
}
