/*
 *  WINGs WMRuler: nifty ruler widget for WINGs :-)
 *
 *  Copyright (c) 1999-2000 Nwanua Elumeze
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#include "WINGsP.h"
#include "wconfig.h"

#define MIN_DOC_WIDTH 10

typedef struct W_Ruler {
	W_Class widgetClass;
	W_View *view;
	W_View *pview;		/* the parent's view (for drawing the line) */

	WMAction *moveAction;	/* what to when while moving */
	WMAction *releaseAction;	/* what to do when released */
	void *clientData;

	WMColor *fg;
	GC fgGC, bgGC;
	WMFont *font;
	WMRulerMargins margins;
	int offset;
	int motion;		/* the position of the _moving_ marker(s) */
	int end;		/* the last tick on the baseline (restrict markers to it) */

	Pixmap drawBuffer;

	struct {
		unsigned int whichMarker:3;
		/*    0,    1,     2,     3,    4,       5,            6 */
		/* none, left, right, first, body, tabstop, first & body */

		unsigned int buttonPressed:1;
		unsigned int redraw:1;
		unsigned int RESERVED:27;
	} flags;
} Ruler;

/* Marker for left margin

   |\
   | \
   |__\
   |
   |

 */
static void drawLeftMarker(Ruler * rPtr)
{
	XPoint points[4];
	int xpos = (rPtr->flags.whichMarker == 1 ? rPtr->motion : rPtr->margins.left);

	XDrawLine(rPtr->view->screen->display, rPtr->drawBuffer, rPtr->fgGC, xpos, 8, xpos, 22);
	points[0].x = xpos;
	points[0].y = 1;
	points[1].x = points[0].x + 6;
	points[1].y = 8;
	points[2].x = points[0].x + 6;
	points[2].y = 9;
	points[3].x = points[0].x;
	points[3].y = 9;
	XFillPolygon(rPtr->view->screen->display, rPtr->drawBuffer, rPtr->fgGC,
		     points, 4, Convex, CoordModeOrigin);
}

/* Marker for right margin

  /|
 / |
/__|
   |
   |

 */
static void drawRightMarker(Ruler * rPtr)
{
	XPoint points[4];
	int xpos = (rPtr->flags.whichMarker == 2 ? rPtr->motion : rPtr->margins.right);

	XDrawLine(rPtr->view->screen->display, rPtr->drawBuffer, rPtr->fgGC, xpos, 8, xpos, 22);
	points[0].x = xpos + 1;
	points[0].y = 0;
	points[1].x = points[0].x - 6;
	points[1].y = 7;
	points[2].x = points[0].x - 6;
	points[2].y = 9;
	points[3].x = points[0].x;
	points[3].y = 9;
	XFillPolygon(rPtr->view->screen->display, rPtr->drawBuffer, rPtr->fgGC,
		     points, 4, Convex, CoordModeOrigin);
}

/* Marker for first line only
   _____
   |___|
   |

 */
static void drawFirstMarker(Ruler * rPtr)
{
	int xpos = ((rPtr->flags.whichMarker == 3 || rPtr->flags.whichMarker == 6) ?
		    rPtr->motion : rPtr->margins.first);

	XFillRectangle(rPtr->view->screen->display, rPtr->drawBuffer, rPtr->fgGC, xpos - 5, 10, 11, 5);
	XDrawLine(rPtr->view->screen->display, rPtr->drawBuffer, rPtr->fgGC, xpos, 12, xpos, 22);
}

/* Marker for rest of body
   _____
   \   /
    \./
 */
static void drawBodyMarker(Ruler * rPtr)
{
	XPoint points[4];
	int xpos = ((rPtr->flags.whichMarker == 4 || rPtr->flags.whichMarker == 6) ?
		    rPtr->motion : rPtr->margins.body);

	points[0].x = xpos - 5;
	points[0].y = 16;
	points[1].x = points[0].x + 11;
	points[1].y = 16;
	points[2].x = points[0].x + 5;
	points[2].y = 22;
	XFillPolygon(rPtr->view->screen->display, rPtr->drawBuffer, rPtr->fgGC,
		     points, 3, Convex, CoordModeOrigin);
}

static void createDrawBuffer(Ruler * rPtr)
{
	if (!rPtr->view->flags.realized)
		return;

	if (rPtr->drawBuffer)
		XFreePixmap(rPtr->view->screen->display, rPtr->drawBuffer);

	rPtr->drawBuffer = XCreatePixmap(rPtr->view->screen->display,
					 rPtr->view->window, rPtr->view->size.width, 40,
					 rPtr->view->screen->depth);
	XFillRectangle(rPtr->view->screen->display, rPtr->drawBuffer,
		       rPtr->bgGC, 0, 0, rPtr->view->size.width, 40);
}

static void drawRulerOnPixmap(Ruler * rPtr)
{
	int i, j, w, m;
	char c[3];
	int marks[9] = { 11, 3, 5, 3, 7, 3, 5, 3 };

	if (!rPtr->drawBuffer || !rPtr->view->flags.realized)
		return;

	XFillRectangle(rPtr->view->screen->display, rPtr->drawBuffer,
		       rPtr->bgGC, 0, 0, rPtr->view->size.width, 40);

	WMDrawString(rPtr->view->screen, rPtr->drawBuffer, rPtr->fg,
		     rPtr->font, rPtr->margins.left + 2, 26, _("0   inches"), 10);

	/* marker ticks */
	i = j = m = 0;
	w = rPtr->view->size.width - rPtr->margins.left;
	while (m < w) {
		XDrawLine(rPtr->view->screen->display, rPtr->drawBuffer,
			  rPtr->fgGC, rPtr->margins.left + m, 23, rPtr->margins.left + m, marks[i % 8] + 23);
		if (i != 0 && i % 8 == 0) {
			if (j < 10)
				snprintf(c, 3, "%d", ++j);
			else
				snprintf(c, 3, "%2d", ++j);
			WMDrawString(rPtr->view->screen, rPtr->drawBuffer, rPtr->fg,
				     rPtr->font, rPtr->margins.left + 2 + m, 26, c, 2);
		}
		m = (++i) * 10;
	}

	rPtr->end = rPtr->margins.left + m - 10;
	if (rPtr->margins.right > rPtr->end)
		rPtr->margins.right = rPtr->end;
	/* base line */
	XDrawLine(rPtr->view->screen->display, rPtr->drawBuffer, rPtr->fgGC,
		  rPtr->margins.left, 22, rPtr->margins.left + m - 10, 22);

	drawLeftMarker(rPtr);
	drawRightMarker(rPtr);
	drawFirstMarker(rPtr);
	drawBodyMarker(rPtr);

	rPtr->flags.redraw = False;
}

static void paintRuler(Ruler * rPtr)
{
	if (!rPtr->drawBuffer || !rPtr->view->flags.realized)
		return;

	if (rPtr->flags.redraw)
		drawRulerOnPixmap(rPtr);
	XCopyArea(rPtr->view->screen->display, rPtr->drawBuffer,
		  rPtr->view->window, rPtr->bgGC, 0, 0, rPtr->view->size.width, 40, 0, 0);
}

static Bool verifyMarkerMove(Ruler * rPtr, int x)
{
	if (rPtr->flags.whichMarker < 1 || rPtr->flags.whichMarker > 6)
		return False;

	switch (rPtr->flags.whichMarker) {
	case 1:
		if (x > rPtr->margins.right - 10 || x < rPtr->offset ||
		    rPtr->margins.body + x > rPtr->margins.right - MIN_DOC_WIDTH ||
		    rPtr->margins.first + x > rPtr->margins.right - MIN_DOC_WIDTH)
			return False;
		break;

	case 2:
		if (x < rPtr->margins.first + MIN_DOC_WIDTH || x < rPtr->margins.body + MIN_DOC_WIDTH || x < rPtr->margins.left + MIN_DOC_WIDTH || x > rPtr->end)	/*rPtr->view->size.width) */
			return False;
		break;

	case 3:
		if (x >= rPtr->margins.right - MIN_DOC_WIDTH || x < rPtr->margins.left)
			return False;
		break;

	case 4:
		if (x >= rPtr->margins.right - MIN_DOC_WIDTH || x < rPtr->margins.left)
			return False;
		break;

	case 6:
		if (x >= rPtr->margins.right - MIN_DOC_WIDTH || x < rPtr->margins.left)
			return False;
		break;

	default:
		return False;
	}

	rPtr->motion = x;
	return True;
}

static int whichMarker(Ruler * rPtr, int x, int y)
{
	if (x < rPtr->offset || y > 22)
		return 0;

	if (rPtr->margins.left - x >= -6 && y <= 9 && (rPtr->margins.left - x <= 0) && y >= 4) {
		rPtr->motion = rPtr->margins.left;
		return 1;
	}
	if (rPtr->margins.right - x >= -1 && y <= 11 && rPtr->margins.right - x <= 5 && y >= 4) {
		rPtr->motion = rPtr->margins.right;
		return 2;
	}
#if 0
	/* both first and body? */
	if (rPtr->margins.first - x <= 4 && rPtr->margins.first - x >= -5
	    && rPtr->margins.body - x <= 4 && rPtr->margins.body - x >= -5 && y >= 15 && y <= 17) {
		rPtr->motion = rPtr->margins.first;
		return 6;
	}
#endif

	if (rPtr->margins.first - x <= 4 && y <= 15 && rPtr->margins.first - x >= -5 && y >= 10) {
		rPtr->motion = rPtr->margins.first;
		return 3;
	}
	if (rPtr->margins.body - x <= 4 && y <= 21 && rPtr->margins.body - x >= -5 && y >= 17) {
		rPtr->motion = rPtr->margins.body;
		return 4;
	}
	/* do tabs (5) */

	return 0;
}

static void rulerDidResize(W_ViewDelegate * self, WMView * view)
{
	Ruler *rPtr = (Ruler *) view->self;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	createDrawBuffer(rPtr);
	rPtr->flags.redraw = True;
	paintRuler(rPtr);

}

static void handleEvents(XEvent * event, void *data)
{
	Ruler *rPtr = (Ruler *) data;

	switch (event->type) {
	case Expose:
		rulerDidResize(rPtr->view->delegate, rPtr->view);
		break;

	case MotionNotify:
		if (rPtr->flags.buttonPressed && (event->xmotion.state & Button1Mask)) {
			if (verifyMarkerMove(rPtr, event->xmotion.x)) {
				GC gc = WMColorGC(WMDarkGrayColor(rPtr->view->screen));

				if (rPtr->moveAction)
					(rPtr->moveAction) (rPtr, rPtr->clientData);
				rPtr->flags.redraw = True;
				paintRuler(rPtr);
				XSetLineAttributes(rPtr->view->screen->display, gc, 1,
						   LineSolid, CapNotLast, JoinMiter);
				XDrawLine(rPtr->pview->screen->display,
					  rPtr->pview->window,
					  gc, rPtr->motion + 1, 40,
					  rPtr->motion + 1, rPtr->pview->size.height - 5);
			}
		}
		break;

	case ButtonPress:
		if (event->xbutton.button != Button1)
			return;
		rPtr->flags.buttonPressed = True;
		rPtr->flags.whichMarker = whichMarker(rPtr, event->xmotion.x, event->xmotion.y);
		break;

	case ButtonRelease:
		if (event->xbutton.button != Button1)
			return;
		rPtr->flags.buttonPressed = False;
		switch (rPtr->flags.whichMarker) {
		case 1:{
				int change = rPtr->margins.left - rPtr->motion;

				rPtr->margins.first -= change;
				rPtr->margins.body -= change;
				rPtr->margins.left = rPtr->motion;
				rPtr->flags.redraw = True;
				paintRuler(rPtr);
				break;
			}
		case 2:
			rPtr->margins.right = rPtr->motion;
			break;
		case 3:
			rPtr->margins.first = rPtr->motion;
			break;
		case 4:
			rPtr->margins.body = rPtr->motion;
			break;
		case 6:
			rPtr->margins.first = rPtr->margins.body = rPtr->motion;
			break;
		}
		if (rPtr->releaseAction)
			(rPtr->releaseAction) (rPtr, rPtr->clientData);
		break;
	}
}

W_ViewDelegate _RulerViewDelegate = {
	NULL,
	NULL,
	rulerDidResize,
	NULL,
	NULL
};

WMRuler *WMCreateRuler(WMWidget * parent)
{
	Ruler *rPtr = wmalloc(sizeof(Ruler));
	unsigned int w = WMWidgetWidth(parent);

	rPtr->widgetClass = WC_Ruler;

	rPtr->view = W_CreateView(W_VIEW(parent));

	if (!rPtr->view) {
		wfree(rPtr);
		return NULL;
	}

	rPtr->view->self = rPtr;

	rPtr->drawBuffer = (Pixmap) NULL;

	W_ResizeView(rPtr->view, w, 40);

	WMCreateEventHandler(rPtr->view, ExposureMask | StructureNotifyMask
			     | EnterWindowMask | LeaveWindowMask | FocusChangeMask
			     | ButtonReleaseMask | ButtonPressMask | KeyReleaseMask
			     | KeyPressMask | Button1MotionMask, handleEvents, rPtr);

	rPtr->view->delegate = &_RulerViewDelegate;

	rPtr->fg = WMBlackColor(rPtr->view->screen);
	rPtr->fgGC = WMColorGC(rPtr->fg);
	rPtr->bgGC = WMColorGC(WMGrayColor(rPtr->view->screen));
	rPtr->font = WMSystemFontOfSize(rPtr->view->screen, 8);

	rPtr->offset = 22;
	rPtr->margins.left = 22;
	rPtr->margins.body = 22;
	rPtr->margins.first = 42;
	rPtr->margins.right = (w < 502 ? w : 502);
	rPtr->margins.tabs = NULL;

	rPtr->flags.whichMarker = 0;	/* none */
	rPtr->flags.buttonPressed = False;
	rPtr->flags.redraw = True;

	rPtr->moveAction = NULL;
	rPtr->releaseAction = NULL;

	rPtr->pview = W_VIEW(parent);

	return rPtr;
}

void WMSetRulerMargins(WMRuler * rPtr, WMRulerMargins margins)
{
	if (!rPtr)
		return;
	rPtr->margins.left = margins.left + rPtr->offset;
	rPtr->margins.right = margins.right + rPtr->offset;
	rPtr->margins.first = margins.first + rPtr->offset;
	rPtr->margins.body = margins.body + rPtr->offset;
	rPtr->margins.tabs = margins.tabs;	/*for loop */
	rPtr->flags.redraw = True;
	paintRuler(rPtr);

}

WMRulerMargins *WMGetRulerMargins(WMRuler * rPtr)
{
	WMRulerMargins *margins = wmalloc(sizeof(WMRulerMargins));

	if (!rPtr) {
		margins->first = margins->body = margins->left = 0;
		margins->right = 100;
		return margins;
	}

	margins->left = rPtr->margins.left - rPtr->offset;
	margins->right = rPtr->margins.right - rPtr->offset;
	margins->first = rPtr->margins.first - rPtr->offset;
	margins->body = rPtr->margins.body - rPtr->offset;
	/*for */
	margins->tabs = rPtr->margins.tabs;

	return margins;
}

Bool WMIsMarginEqualToMargin(WMRulerMargins * aMargin, WMRulerMargins * anotherMargin)
{
	if (aMargin == anotherMargin)
		return True;
	else if (!aMargin || !anotherMargin)
		return False;
	if (aMargin->left != anotherMargin->left)
		return False;
	if (aMargin->first != anotherMargin->first)
		return False;
	if (aMargin->body != anotherMargin->body)
		return False;
	if (aMargin->right != anotherMargin->right)
		return False;

	return True;
}

void WMSetRulerOffset(WMRuler * rPtr, int pixels)
{
	if (!rPtr || pixels < 0 || pixels + MIN_DOC_WIDTH >= rPtr->view->size.width)
		return;
	rPtr->offset = pixels;
	/*rulerDidResize(rPtr, rPtr->view); */
}

int WMGetRulerOffset(WMRuler * rPtr)
{
	if (!rPtr)
		return 0;	/* what value should return if no ruler? -1 or 0? */
	return rPtr->offset;
}

void WMSetRulerReleaseAction(WMRuler * rPtr, WMAction * action, void *clientData)
{
	if (!rPtr)
		return;

	rPtr->releaseAction = action;
	rPtr->clientData = clientData;
}

void WMSetRulerMoveAction(WMRuler * rPtr, WMAction * action, void *clientData)
{
	if (!rPtr)
		return;

	rPtr->moveAction = action;
	rPtr->clientData = clientData;
}

/* _which_ one was released */
int WMGetReleasedRulerMargin(WMRuler * rPtr)
{
	if (!rPtr)
		return 0;
	return rPtr->flags.whichMarker;
}

/* _which_ one is being grabbed */
int WMGetGrabbedRulerMargin(WMRuler * rPtr)
{
	if (!rPtr)
		return 0;
	return rPtr->flags.whichMarker;
}
