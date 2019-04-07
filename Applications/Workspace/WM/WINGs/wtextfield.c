
#include "WINGsP.h"
#include "wconfig.h"

#include <X11/keysym.h>
#include <X11/Xatom.h>

#include <ctype.h>

#define CURSOR_BLINK_ON_DELAY	600
#define CURSOR_BLINK_OFF_DELAY	300

char *WMTextDidChangeNotification = "WMTextDidChangeNotification";
char *WMTextDidBeginEditingNotification = "WMTextDidBeginEditingNotification";
char *WMTextDidEndEditingNotification = "WMTextDidEndEditingNotification";

typedef struct W_TextField {
	W_Class widgetClass;
	W_View *view;

#if 0
	struct W_TextField *nextField;	/* next textfield in the chain */
	struct W_TextField *prevField;
#endif

	char *text;
	int textLen;		/* size of text */
	int bufferSize;		/* memory allocated for text */

	int viewPosition;	/* position of text being shown */

	int cursorPosition;	/* position of the insertion cursor */

	short usableWidth;
	short offsetWidth;	/* offset of text from border */

	WMRange selection;

	WMFont *font;

	WMTextFieldDelegate *delegate;

	WMHandlerID timerID;	/* for cursor blinking */

	struct {
		WMAlignment alignment:2;

		unsigned int bordered:1;

		unsigned int beveled:1;

		unsigned int enabled:1;

		unsigned int focused:1;

		unsigned int cursorOn:1;

		unsigned int secure:1;	/* password entry style */

		unsigned int pointerGrabbed:1;

		unsigned int ownsSelection:1;

		unsigned int waitingSelection:1;	/* requested selection, but
							 * didnt get yet */

		unsigned int notIllegalMovement:1;
	} flags;
} TextField;

#define NOTIFY(T,C,N,A) { WMNotification *notif = WMCreateNotification(N,T,A);\
    if ((T)->delegate && (T)->delegate->C)\
    (*(T)->delegate->C)((T)->delegate,notif);\
    WMPostNotification(notif);\
    WMReleaseNotification(notif);}

#define MIN_TEXT_BUFFER		2
#define TEXT_BUFFER_INCR	8

#define WM_EMACSKEYMASK   ControlMask

#define WM_EMACSKEY_LEFT  XK_b
#define WM_EMACSKEY_RIGHT XK_f
#define WM_EMACSKEY_HOME  XK_a
#define WM_EMACSKEY_END   XK_e
#define WM_EMACSKEY_BS    XK_h
#define WM_EMACSKEY_DEL   XK_d

#define DEFAULT_WIDTH		60
#define DEFAULT_HEIGHT		20
#define DEFAULT_BORDERED	True
#define DEFAULT_ALIGNMENT	WALeft

static void destroyTextField(TextField * tPtr);
static void paintTextField(TextField * tPtr);

static void handleEvents(XEvent * event, void *data);
static void handleTextFieldActionEvents(XEvent * event, void *data);
static void didResizeTextField(W_ViewDelegate * self, WMView * view);

struct W_ViewDelegate _TextFieldViewDelegate = {
	NULL,
	NULL,
	didResizeTextField,
	NULL,
	NULL
};

static void lostSelection(WMView * view, Atom selection, void *cdata);

static WMData *requestHandler(WMView * view, Atom selection, Atom target, void *cdata, Atom * type);

static WMSelectionProcs selectionHandler = {
	requestHandler,
	lostSelection,
	NULL
};

#define TEXT_WIDTH(tPtr, start) (WMWidthOfString((tPtr)->font, \
    &((tPtr)->text[(start)]), (tPtr)->textLen - (start)))

#define TEXT_WIDTH2(tPtr, start, end) (WMWidthOfString((tPtr)->font, \
    &((tPtr)->text[(start)]), (end) - (start)))

static inline int oneUTF8CharBackward(const char *str, int len)
{
	const unsigned char *ustr = (const unsigned char *)str;
	int pos = 0;

	while (len-- > 0 && ustr[--pos] >= 0x80 && ustr[pos] <= 0xbf) ;
	return pos;
}

static inline int oneUTF8CharForward(const char *str, int len)
{
	const unsigned char *ustr = (const unsigned char *)str;
	int pos = 0;

	while (len-- > 0 && ustr[++pos] >= 0x80 && ustr[pos] <= 0xbf) ;
	return pos;
}

// find the beginning of the UTF8 char pointed by str
static inline int seekUTF8CharStart(const char *str, int len)
{
	const unsigned char *ustr = (const unsigned char *)str;
	int pos = 0;

	while (len-- > 0 && ustr[pos] >= 0x80 && ustr[pos] <= 0xbf)
		--pos;
	return pos;
}

static void normalizeRange(TextField * tPtr, WMRange * range)
{
	if (range->position < 0 && range->count < 0)
		range->count = 0;

	if (range->count == 0) {
		/*range->position = 0; why is this? */
		return;
	}

	/* (1,-2) ~> (0,1) ; (1,-1) ~> (0,1) ; (2,-1) ~> (1,1) */
	if (range->count < 0) {	/* && range->position >= 0 */
		if (range->position + range->count < 0) {
			range->count = range->position;
			range->position = 0;
		} else {
			range->count = -range->count;
			range->position -= range->count;
		}
		/* (-2,1) ~> (0,0) ; (-1,1) ~> (0,0) ; (-1,2) ~> (0,1) */
	} else if (range->position < 0) {	/* && range->count > 0 */
		if (range->position + range->count < 0) {
			range->position = range->count = 0;
		} else {
			range->count += range->position;
			range->position = 0;
		}
	}

	if (range->position + range->count > tPtr->textLen)
		range->count = tPtr->textLen - range->position;
}

static void memmv(char *dest, const char *src, int size)
{
	int i;

	if (dest > src) {
		for (i = size - 1; i >= 0; i--) {
			dest[i] = src[i];
		}
	} else if (dest < src) {
		for (i = 0; i < size; i++) {
			dest[i] = src[i];
		}
	}
}

static int incrToFit(TextField * tPtr)
{
	int vp = tPtr->viewPosition;

	while (TEXT_WIDTH(tPtr, tPtr->viewPosition) > tPtr->usableWidth) {
		tPtr->viewPosition += oneUTF8CharForward(&tPtr->text[tPtr->viewPosition],
							 tPtr->textLen - tPtr->viewPosition);
	}
	return vp != tPtr->viewPosition;
}

static int incrToFit2(TextField * tPtr)
{
	int vp = tPtr->viewPosition;

	while (TEXT_WIDTH2(tPtr, tPtr->viewPosition, tPtr->cursorPosition)
	       >= tPtr->usableWidth)
		tPtr->viewPosition += oneUTF8CharForward(&tPtr->text[tPtr->viewPosition],
							 tPtr->cursorPosition - tPtr->viewPosition);
	return vp != tPtr->viewPosition;
}

static void decrToFit(TextField * tPtr)
{
	int vp = tPtr->viewPosition;

	while (vp > 0 && (vp += oneUTF8CharBackward(&tPtr->text[vp], vp),
			  TEXT_WIDTH(tPtr, vp)) < tPtr->usableWidth) {
		tPtr->viewPosition = vp;
	}
}

#undef TEXT_WIDTH
#undef TEXT_WIDTH2

static WMData *requestHandler(WMView * view, Atom selection, Atom target, void *cdata, Atom * type)
{
	TextField *tPtr = view->self;
	int count;
	Display *dpy = tPtr->view->screen->display;
	Atom _TARGETS;
	Atom TEXT = XInternAtom(dpy, "TEXT", False);
	Atom COMPOUND_TEXT = XInternAtom(dpy, "COMPOUND_TEXT", False);
	WMData *data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) selection;
	(void) cdata;

	count = tPtr->selection.count < 0
	    ? tPtr->selection.position + tPtr->selection.count : tPtr->selection.position;

	if (target == XA_STRING || target == TEXT || target == COMPOUND_TEXT) {

		data = WMCreateDataWithBytes(&(tPtr->text[count]), abs(tPtr->selection.count));
		WMSetDataFormat(data, 8);
		*type = target;

		return data;
	}

	_TARGETS = XInternAtom(dpy, "TARGETS", False);
	if (target == _TARGETS) {
		Atom supported_type[4];

		supported_type[0] = _TARGETS;
		supported_type[1] = XA_STRING;
		supported_type[2] = TEXT;
		supported_type[3] = COMPOUND_TEXT;

		data = WMCreateDataWithBytes(supported_type, sizeof(supported_type));
		WMSetDataFormat(data, 32);

		*type = target;
		return data;
	}

	return NULL;

}

static void lostSelection(WMView * view, Atom selection, void *cdata)
{
	TextField *tPtr = (WMTextField *) view->self;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) cdata;

	if (tPtr->flags.ownsSelection) {
		WMDeleteSelectionHandler(view, selection, CurrentTime);
		tPtr->flags.ownsSelection = 0;
	}
	if (tPtr->selection.count != 0) {
		tPtr->selection.count = 0;
		paintTextField(tPtr);
	}
}

static void selectionNotification(void *observerData, WMNotification * notification)
{
	WMView *observerView = (WMView *) observerData;
	WMView *newOwnerView = (WMView *) WMGetNotificationClientData(notification);

	if (observerView != newOwnerView) {
		/*
		   //if (tPtr->flags.ownsSelection)
		   //    WMDeleteSelectionHandler(observerView, XA_PRIMARY, CurrentTime);
		 */
		lostSelection(observerView, XA_PRIMARY, NULL);
	}
}

static void realizeObserver(void *self, WMNotification * not)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) not;

	W_CreateIC(((TextField *) self)->view);
}

WMTextField *WMCreateTextField(WMWidget * parent)
{
	TextField *tPtr;

	tPtr = wmalloc(sizeof(TextField));
	tPtr->widgetClass = WC_TextField;

	tPtr->view = W_CreateView(W_VIEW(parent));
	if (!tPtr->view) {
		wfree(tPtr);
		return NULL;
	}
	tPtr->view->self = tPtr;

	tPtr->view->delegate = &_TextFieldViewDelegate;

	tPtr->view->attribFlags |= CWCursor;
	tPtr->view->attribs.cursor = tPtr->view->screen->textCursor;

	W_SetViewBackgroundColor(tPtr->view, tPtr->view->screen->white);

	tPtr->text = wmalloc(MIN_TEXT_BUFFER);
	tPtr->textLen = 0;
	tPtr->bufferSize = MIN_TEXT_BUFFER;

	tPtr->flags.enabled = 1;

	WMCreateEventHandler(tPtr->view, ExposureMask | StructureNotifyMask | FocusChangeMask, handleEvents, tPtr);

	tPtr->font = WMRetainFont(tPtr->view->screen->normalFont);

	tPtr->flags.bordered = DEFAULT_BORDERED;
	tPtr->flags.beveled = True;
	tPtr->flags.alignment = DEFAULT_ALIGNMENT;
	tPtr->offsetWidth = WMAX((tPtr->view->size.height - WMFontHeight(tPtr->font)) / 2, 1);

	W_ResizeView(tPtr->view, DEFAULT_WIDTH, DEFAULT_HEIGHT);

	WMCreateEventHandler(tPtr->view, EnterWindowMask | LeaveWindowMask
			     | ButtonReleaseMask | ButtonPressMask | KeyPressMask | Button1MotionMask,
			     handleTextFieldActionEvents, tPtr);

	WMAddNotificationObserver(selectionNotification, tPtr->view,
				  WMSelectionOwnerDidChangeNotification, (void *)XA_PRIMARY);

	WMAddNotificationObserver(realizeObserver, tPtr, WMViewRealizedNotification, tPtr->view);

	tPtr->flags.cursorOn = 1;

	return tPtr;
}

void WMSetTextFieldDelegate(WMTextField * tPtr, WMTextFieldDelegate * delegate)
{
	CHECK_CLASS(tPtr, WC_TextField);

	tPtr->delegate = delegate;
}

WMTextFieldDelegate *WMGetTextFieldDelegate(WMTextField * tPtr)
{
	CHECK_CLASS(tPtr, WC_TextField);

	return tPtr->delegate;
}

void WMInsertTextFieldText(WMTextField * tPtr, const char *text, int position)
{
	int len;

	CHECK_CLASS(tPtr, WC_TextField);

	if (!text)
		return;

	len = strlen(text);

	/* check if buffer will hold the text */
	if (len + tPtr->textLen >= tPtr->bufferSize) {
		tPtr->bufferSize = tPtr->textLen + len + TEXT_BUFFER_INCR;
		tPtr->text = wrealloc(tPtr->text, tPtr->bufferSize);
	}

	if (position < 0 || position >= tPtr->textLen) {
		/* append the text at the end */
		wstrlcat(tPtr->text, text, tPtr->bufferSize);
		tPtr->textLen += len;
		tPtr->cursorPosition += len;
		incrToFit(tPtr);
	} else {
		/* insert text at position */
		memmv(&(tPtr->text[position + len]), &(tPtr->text[position]), tPtr->textLen - position + 1);

		memcpy(&(tPtr->text[position]), text, len);

		tPtr->textLen += len;
		if (position >= tPtr->cursorPosition) {
			tPtr->cursorPosition += len;
			incrToFit2(tPtr);
		} else {
			incrToFit(tPtr);
		}
	}

	paintTextField(tPtr);
}

void WMDeleteTextFieldRange(WMTextField * tPtr, WMRange range)
{
	CHECK_CLASS(tPtr, WC_TextField);

	normalizeRange(tPtr, &range);

	if (!range.count)
		return;

	memmv(&(tPtr->text[range.position]), &(tPtr->text[range.position + range.count]),
	      tPtr->textLen - (range.position + range.count) + 1);

	/* better than nothing ;) */
	if (tPtr->cursorPosition > range.position)
		tPtr->viewPosition += oneUTF8CharBackward(&tPtr->text[tPtr->viewPosition], tPtr->viewPosition);
	tPtr->textLen -= range.count;
	tPtr->cursorPosition = range.position;

	decrToFit(tPtr);

	paintTextField(tPtr);
}

char *WMGetTextFieldText(WMTextField * tPtr)
{
	CHECK_CLASS(tPtr, WC_TextField);

	return wstrdup(tPtr->text);
}

void WMSetTextFieldText(WMTextField * tPtr, const char *text)
{
	CHECK_CLASS(tPtr, WC_TextField);

	if ((text && strcmp(tPtr->text, text) == 0) || (!text && tPtr->textLen == 0))
		return;

	if (text == NULL) {
		tPtr->text[0] = 0;
		tPtr->textLen = 0;
	} else {
		tPtr->textLen = strlen(text);

		if (tPtr->textLen >= tPtr->bufferSize) {
			tPtr->bufferSize = tPtr->textLen + TEXT_BUFFER_INCR;
			tPtr->text = wrealloc(tPtr->text, tPtr->bufferSize);
		}
		wstrlcpy(tPtr->text, text, tPtr->bufferSize);
	}

	tPtr->cursorPosition = tPtr->selection.position = tPtr->textLen;
	tPtr->viewPosition = 0;
	tPtr->selection.count = 0;

	if (tPtr->view->flags.realized)
		paintTextField(tPtr);
}

void WMSetTextFieldAlignment(WMTextField * tPtr, WMAlignment alignment)
{
	CHECK_CLASS(tPtr, WC_TextField);

	tPtr->flags.alignment = alignment;

	if (alignment != WALeft) {
		wwarning(_("only left alignment is supported in textfields"));
		return;
	}

	if (tPtr->view->flags.realized) {
		paintTextField(tPtr);
	}
}

void WMSetTextFieldBordered(WMTextField * tPtr, Bool bordered)
{
	CHECK_CLASS(tPtr, WC_TextField);

	tPtr->flags.bordered = bordered;

	if (tPtr->view->flags.realized) {
		paintTextField(tPtr);
	}
}

void WMSetTextFieldBeveled(WMTextField * tPtr, Bool flag)
{
	CHECK_CLASS(tPtr, WC_TextField);

	tPtr->flags.beveled = ((flag == 0) ? 0 : 1);

	if (tPtr->view->flags.realized) {
		paintTextField(tPtr);
	}
}

void WMSetTextFieldSecure(WMTextField * tPtr, Bool flag)
{
	CHECK_CLASS(tPtr, WC_TextField);

	tPtr->flags.secure = ((flag == 0) ? 0 : 1);

	if (tPtr->view->flags.realized) {
		paintTextField(tPtr);
	}
}

Bool WMGetTextFieldEditable(WMTextField * tPtr)
{
	CHECK_CLASS(tPtr, WC_TextField);

	return tPtr->flags.enabled;
}

void WMSetTextFieldEditable(WMTextField * tPtr, Bool flag)
{
	CHECK_CLASS(tPtr, WC_TextField);

	tPtr->flags.enabled = ((flag == 0) ? 0 : 1);

	if (tPtr->view->flags.realized) {
		paintTextField(tPtr);
	}
}

void WMSelectTextFieldRange(WMTextField * tPtr, WMRange range)
{
	CHECK_CLASS(tPtr, WC_TextField);

	if (tPtr->flags.enabled) {
		normalizeRange(tPtr, &range);

		tPtr->selection = range;

		tPtr->cursorPosition = range.position + range.count;

		if (tPtr->view->flags.realized) {
			paintTextField(tPtr);
		}
	}
}

void WMSetTextFieldCursorPosition(WMTextField * tPtr, unsigned int position)
{
	CHECK_CLASS(tPtr, WC_TextField);

	if (tPtr->flags.enabled) {
		if (position > tPtr->textLen)
			position = tPtr->textLen;

		tPtr->cursorPosition = position;
		if (tPtr->view->flags.realized) {
			paintTextField(tPtr);
		}
	}
}

unsigned WMGetTextFieldCursorPosition(WMTextField *tPtr)
{
	CHECK_CLASS(tPtr, WC_TextField);

	return tPtr->cursorPosition;
}

void WMSetTextFieldNextTextField(WMTextField * tPtr, WMTextField * next)
{
	CHECK_CLASS(tPtr, WC_TextField);
	if (next == NULL) {
		if (tPtr->view->nextFocusChain)
			tPtr->view->nextFocusChain->prevFocusChain = NULL;
		tPtr->view->nextFocusChain = NULL;
		return;
	}

	CHECK_CLASS(next, WC_TextField);

	if (tPtr->view->nextFocusChain)
		tPtr->view->nextFocusChain->prevFocusChain = NULL;
	if (next->view->prevFocusChain)
		next->view->prevFocusChain->nextFocusChain = NULL;

	tPtr->view->nextFocusChain = next->view;
	next->view->prevFocusChain = tPtr->view;
}

void WMSetTextFieldPrevTextField(WMTextField * tPtr, WMTextField * prev)
{
	CHECK_CLASS(tPtr, WC_TextField);
	if (prev == NULL) {
		if (tPtr->view->prevFocusChain)
			tPtr->view->prevFocusChain->nextFocusChain = NULL;
		tPtr->view->prevFocusChain = NULL;
		return;
	}

	CHECK_CLASS(prev, WC_TextField);

	if (tPtr->view->prevFocusChain)
		tPtr->view->prevFocusChain->nextFocusChain = NULL;
	if (prev->view->nextFocusChain)
		prev->view->nextFocusChain->prevFocusChain = NULL;

	tPtr->view->prevFocusChain = prev->view;
	prev->view->nextFocusChain = tPtr->view;
}

void WMSetTextFieldFont(WMTextField * tPtr, WMFont * font)
{
	CHECK_CLASS(tPtr, WC_TextField);

	if (tPtr->font)
		WMReleaseFont(tPtr->font);
	tPtr->font = WMRetainFont(font);

	tPtr->offsetWidth = WMAX((tPtr->view->size.height - WMFontHeight(tPtr->font)) / 2, 1);

	if (tPtr->view->flags.realized) {
		paintTextField(tPtr);
	}
}

WMFont *WMGetTextFieldFont(WMTextField * tPtr)
{
	return tPtr->font;
}

static void didResizeTextField(W_ViewDelegate * self, WMView * view)
{
	WMTextField *tPtr = (WMTextField *) view->self;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	tPtr->offsetWidth = WMAX((tPtr->view->size.height - WMFontHeight(tPtr->font)) / 2, 1);

	tPtr->usableWidth = tPtr->view->size.width - 2 * tPtr->offsetWidth /*+ 2 */ ;
}

static char *makeHiddenString(int length)
{
	char *data = wmalloc(length + 1);

	memset(data, '*', length);
	data[length] = '\0';

	return data;
}

static void paintCursor(TextField * tPtr)
{
	int cx;
	WMScreen *screen = tPtr->view->screen;
	int textWidth;
	char *text;

	if (tPtr->flags.secure)
		text = makeHiddenString(strlen(tPtr->text));
	else
		text = tPtr->text;

	cx = WMWidthOfString(tPtr->font, &(text[tPtr->viewPosition]), tPtr->cursorPosition - tPtr->viewPosition);

	switch (tPtr->flags.alignment) {
	case WARight:
		textWidth = WMWidthOfString(tPtr->font, text, tPtr->textLen);
		if (textWidth < tPtr->usableWidth)
			cx += tPtr->offsetWidth + tPtr->usableWidth - textWidth + 1;
		else
			cx += tPtr->offsetWidth + 1;
		break;
	case WALeft:
		cx += tPtr->offsetWidth + 1;
		break;
	case WAJustified:
		/* not supported */
	case WACenter:
		textWidth = WMWidthOfString(tPtr->font, text, tPtr->textLen);
		if (textWidth < tPtr->usableWidth)
			cx += tPtr->offsetWidth + (tPtr->usableWidth - textWidth) / 2;
		else
			cx += tPtr->offsetWidth;
		break;
	}
	/*
	   XDrawRectangle(screen->display, tPtr->view->window, screen->xorGC,
	   cx, tPtr->offsetWidth, 1,
	   tPtr->view->size.height - 2*tPtr->offsetWidth - 1);
	   printf("%d %d\n",cx,tPtr->cursorPosition);
	 */

	XDrawLine(screen->display, tPtr->view->window, screen->xorGC,
		  cx, tPtr->offsetWidth, cx, tPtr->view->size.height - tPtr->offsetWidth - 1);

	W_SetPreeditPositon(tPtr->view, cx, 0);

	if (tPtr->flags.secure) {
		wfree(text);
	}
}

static void drawRelief(WMView * view, Bool beveled)
{
	WMScreen *scr = view->screen;
	Display *dpy = scr->display;
	GC wgc;
	GC lgc;
	GC dgc;
	int width = view->size.width;
	int height = view->size.height;

	dgc = WMColorGC(scr->darkGray);

	if (!beveled) {
		XDrawRectangle(dpy, view->window, dgc, 0, 0, width - 1, height - 1);

		return;
	}
	wgc = WMColorGC(scr->white);
	lgc = WMColorGC(scr->gray);

	/* top left */
	XDrawLine(dpy, view->window, dgc, 0, 0, width - 1, 0);
	XDrawLine(dpy, view->window, dgc, 0, 1, width - 2, 1);

	XDrawLine(dpy, view->window, dgc, 0, 0, 0, height - 2);
	XDrawLine(dpy, view->window, dgc, 1, 0, 1, height - 3);

	/* bottom right */
	XDrawLine(dpy, view->window, wgc, 0, height - 1, width - 1, height - 1);
	XDrawLine(dpy, view->window, lgc, 1, height - 2, width - 2, height - 2);

	XDrawLine(dpy, view->window, wgc, width - 1, 0, width - 1, height - 1);
	XDrawLine(dpy, view->window, lgc, width - 2, 1, width - 2, height - 3);
}

static void paintTextField(TextField * tPtr)
{
	W_Screen *screen = tPtr->view->screen;
	W_View *view = tPtr->view;
	W_View viewbuffer;
	int tx, ty, tw;
	int rx;
	int bd;
	int totalWidth;
	char *text;
	Pixmap drawbuffer;
	WMColor *color;

	if (!view->flags.realized || !view->flags.mapped)
		return;

	if (!tPtr->flags.bordered) {
		bd = 0;
	} else {
		bd = 2;
	}

	if (tPtr->flags.secure) {
		text = makeHiddenString(strlen(tPtr->text));
	} else {
		text = tPtr->text;
	}

	totalWidth = tPtr->view->size.width - 2 * bd;

	drawbuffer = XCreatePixmap(screen->display, view->window,
				   view->size.width, view->size.height, screen->depth);
	XFillRectangle(screen->display, drawbuffer, WMColorGC(screen->white),
		       0, 0, view->size.width, view->size.height);
	/* this is quite dirty */
	viewbuffer.screen = view->screen;
	viewbuffer.size = view->size;
	viewbuffer.window = drawbuffer;

	if (tPtr->textLen > 0) {
		tw = WMWidthOfString(tPtr->font, &(text[tPtr->viewPosition]), tPtr->textLen - tPtr->viewPosition);

		ty = tPtr->offsetWidth;
		switch (tPtr->flags.alignment) {
		case WALeft:
			tx = tPtr->offsetWidth + 1;
			if (tw < tPtr->usableWidth)
				XFillRectangle(screen->display, drawbuffer,
					       WMColorGC(screen->white),
					       bd + tw, bd, totalWidth - tw, view->size.height - 2 * bd);
			break;

		case WACenter:
			tx = tPtr->offsetWidth + (tPtr->usableWidth - tw) / 2;
			if (tw < tPtr->usableWidth)
				XClearArea(screen->display, view->window, bd, bd,
					   totalWidth, view->size.height - 2 * bd, False);
			break;

		default:
		case WARight:
			tx = tPtr->offsetWidth + tPtr->usableWidth - tw - 1;
			if (tw < tPtr->usableWidth)
				XClearArea(screen->display, view->window, bd, bd,
					   totalWidth - tw, view->size.height - 2 * bd, False);
			break;
		}

		color = tPtr->flags.enabled ? screen->black : screen->darkGray;

		WMDrawImageString(screen, drawbuffer, color, screen->white,
				  tPtr->font, tx, ty, &(text[tPtr->viewPosition]),
				  tPtr->textLen - tPtr->viewPosition);

		if (tPtr->selection.count) {
			int count, count2;

			count = tPtr->selection.count < 0
			    ? tPtr->selection.position + tPtr->selection.count : tPtr->selection.position;
			count2 = abs(tPtr->selection.count);
			if (count < tPtr->viewPosition) {
				count2 = abs(count2 - abs(tPtr->viewPosition - count));
				count = tPtr->viewPosition;
			}

			rx = tPtr->offsetWidth + 1 + WMWidthOfString(tPtr->font, text, count)
			    - WMWidthOfString(tPtr->font, text, tPtr->viewPosition);

			WMDrawImageString(screen, drawbuffer, color, screen->gray,
					  tPtr->font, rx, ty, &(text[count]), count2);
		}
	} else {
		XFillRectangle(screen->display, drawbuffer, WMColorGC(screen->white),
			       bd, bd, totalWidth, view->size.height - 2 * bd);
	}

	/* draw relief */
	if (tPtr->flags.bordered) {
		drawRelief(&viewbuffer, tPtr->flags.beveled);
	}

	if (tPtr->flags.secure)
		wfree(text);
	XCopyArea(screen->display, drawbuffer, view->window,
		  screen->copyGC, 0, 0, view->size.width, view->size.height, 0, 0);
	XFreePixmap(screen->display, drawbuffer);

	/* draw cursor */
	if (tPtr->flags.focused && tPtr->flags.enabled && tPtr->flags.cursorOn) {
		paintCursor(tPtr);
	}
}

static void blinkCursor(void *data)
{
	TextField *tPtr = (TextField *) data;

	if (tPtr->flags.cursorOn) {
		tPtr->timerID = WMAddTimerHandler(CURSOR_BLINK_OFF_DELAY, blinkCursor, data);
	} else {
		tPtr->timerID = WMAddTimerHandler(CURSOR_BLINK_ON_DELAY, blinkCursor, data);
	}
	paintCursor(tPtr);
	tPtr->flags.cursorOn = !tPtr->flags.cursorOn;
}

static void handleEvents(XEvent * event, void *data)
{
	TextField *tPtr = (TextField *) data;

	CHECK_CLASS(data, WC_TextField);

	switch (event->type) {
	case FocusIn:
		W_FocusIC(tPtr->view);
		if (W_FocusedViewOfToplevel(W_TopLevelOfView(tPtr->view)) != tPtr->view)
			return;
		tPtr->flags.focused = 1;

		if (!tPtr->timerID) {
			tPtr->timerID = WMAddTimerHandler(CURSOR_BLINK_ON_DELAY, blinkCursor, tPtr);
		}

		paintTextField(tPtr);

		NOTIFY(tPtr, didBeginEditing, WMTextDidBeginEditingNotification, NULL);

		tPtr->flags.notIllegalMovement = 0;
		break;

	case FocusOut:
		W_UnFocusIC(tPtr->view);
		tPtr->flags.focused = 0;

		if (tPtr->timerID)
			WMDeleteTimerHandler(tPtr->timerID);
		tPtr->timerID = NULL;

		paintTextField(tPtr);
		if (!tPtr->flags.notIllegalMovement) {
			NOTIFY(tPtr, didEndEditing, WMTextDidEndEditingNotification,
			       (void *)WMIllegalTextMovement);
		}
		break;

	case Expose:
		if (event->xexpose.count != 0)
			break;
		paintTextField(tPtr);
		break;

	case DestroyNotify:
		destroyTextField(tPtr);
		break;
	}
}

static void handleTextFieldKeyPress(TextField * tPtr, XEvent * event)
{
	char buffer[64];
	KeySym ksym;
	char *textEvent = NULL;
	void *data = NULL;
	int count, refresh = 0;
	int control_pressed = 0;
	int cancelSelection = 1;
	Bool shifted, controled, modified;
	Bool relay = True;

	/*printf("(%d,%d) -> ", tPtr->selection.position, tPtr->selection.count); */
	if (((XKeyEvent *) event)->state & WM_EMACSKEYMASK)
		control_pressed = 1;

	shifted = (event->xkey.state & ShiftMask ? True : False);
	controled = (event->xkey.state & ControlMask ? True : False);
	modified = shifted || controled;

	count = W_LookupString(tPtr->view, &event->xkey, buffer, 63, &ksym, NULL);
	//count = XLookupString(&event->xkey, buffer, 63, &ksym, NULL);
	buffer[count] = '\0';

	switch (ksym) {
	case XK_Tab:
#ifdef XK_ISO_Left_Tab
	case XK_ISO_Left_Tab:
#endif
		if (!controled) {
			if (shifted) {
				if (tPtr->view->prevFocusChain) {
					W_SetFocusOfTopLevel(W_TopLevelOfView(tPtr->view),
							     tPtr->view->prevFocusChain);
					tPtr->flags.notIllegalMovement = 1;
				}
				data = (void *)WMBacktabTextMovement;
			} else {
				if (tPtr->view->nextFocusChain) {
					W_SetFocusOfTopLevel(W_TopLevelOfView(tPtr->view),
							     tPtr->view->nextFocusChain);
					tPtr->flags.notIllegalMovement = 1;
				}
				data = (void *)WMTabTextMovement;
			}
			textEvent = WMTextDidEndEditingNotification;

			cancelSelection = 0;

			relay = False;
		}
		break;

	case XK_Escape:
		if (!modified) {
			data = (void *)WMEscapeTextMovement;
			textEvent = WMTextDidEndEditingNotification;

			relay = False;
		}
		break;

#ifdef XK_KP_Enter
	case XK_KP_Enter:
#endif
	case XK_Return:
		if (!modified) {
			data = (void *)WMReturnTextMovement;
			textEvent = WMTextDidEndEditingNotification;

			relay = False;
		}
		break;

	case WM_EMACSKEY_LEFT:
		if (!control_pressed)
			goto normal_key;
		else
			controled = False;

#ifdef XK_KP_Left
	case XK_KP_Left:
#endif
	case XK_Left:
		if (tPtr->cursorPosition > 0) {
			int i;
			paintCursor(tPtr);

			i = tPtr->cursorPosition;
			i += oneUTF8CharBackward(&tPtr->text[i], i);
			if (controled) {
				while (i > 0 && tPtr->text[i] != ' ')
					i--;
				while (i > 0 && tPtr->text[i] == ' ')
					i--;

				tPtr->cursorPosition = (i > 0) ? i + 1 : 0;
			} else
				tPtr->cursorPosition = i;

			if (tPtr->cursorPosition < tPtr->viewPosition) {
				tPtr->viewPosition = tPtr->cursorPosition;
				refresh = 1;
			} else
				paintCursor(tPtr);
		}
		if (shifted)
			cancelSelection = 0;

		relay = False;

		break;

	case WM_EMACSKEY_RIGHT:
		if (!control_pressed)
			goto normal_key;
		else
			controled = False;

#ifdef XK_KP_Right
	case XK_KP_Right:
#endif
	case XK_Right:
		if (tPtr->cursorPosition < tPtr->textLen) {
			int i;
			paintCursor(tPtr);

			i = tPtr->cursorPosition;
			if (controled) {
				while (tPtr->text[i] && tPtr->text[i] != ' ')
					i++;
				while (tPtr->text[i] == ' ')
					i++;
			} else {
				i += oneUTF8CharForward(&tPtr->text[i], tPtr->textLen - i);
			}
			tPtr->cursorPosition = i;

			refresh = incrToFit2(tPtr);

			if (!refresh)
				paintCursor(tPtr);
		}
		if (shifted)
			cancelSelection = 0;

		relay = False;

		break;

	case WM_EMACSKEY_HOME:
		if (!control_pressed)
			goto normal_key;
		else
			controled = False;

#ifdef XK_KP_Home
	case XK_KP_Home:
#endif
	case XK_Home:
		if (!controled) {
			if (tPtr->cursorPosition > 0) {
				paintCursor(tPtr);
				tPtr->cursorPosition = 0;
				if (tPtr->viewPosition > 0) {
					tPtr->viewPosition = 0;
					refresh = 1;
				} else
					paintCursor(tPtr);
			}
			if (shifted)
				cancelSelection = 0;

			relay = False;
		}
		break;

	case WM_EMACSKEY_END:
		if (!control_pressed)
			goto normal_key;
		else
			controled = False;

#ifdef XK_KP_End
	case XK_KP_End:
#endif
	case XK_End:
		if (!controled) {
			if (tPtr->cursorPosition < tPtr->textLen) {
				paintCursor(tPtr);
				tPtr->cursorPosition = tPtr->textLen;
				tPtr->viewPosition = 0;

				refresh = incrToFit(tPtr);

				if (!refresh)
					paintCursor(tPtr);
			}
			if (shifted)
				cancelSelection = 0;

			relay = False;
		}
		break;

	case WM_EMACSKEY_BS:
		if (!control_pressed)
			goto normal_key;
		else
			modified = False;

	case XK_BackSpace:
		if (!modified) {
			if (tPtr->selection.count) {
				WMDeleteTextFieldRange(tPtr, tPtr->selection);
				data = (void *)WMDeleteTextEvent;
				textEvent = WMTextDidChangeNotification;
			} else if (tPtr->cursorPosition > 0) {
				int i = oneUTF8CharBackward(&tPtr->text[tPtr->cursorPosition],
							    tPtr->cursorPosition);
				WMRange range;
				range.position = tPtr->cursorPosition + i;
				range.count = -i;
				WMDeleteTextFieldRange(tPtr, range);
				data = (void *)WMDeleteTextEvent;
				textEvent = WMTextDidChangeNotification;
			}

			relay = False;
		}
		break;

	case WM_EMACSKEY_DEL:
		if (!control_pressed)
			goto normal_key;
		else
			modified = False;

#ifdef XK_KP_Delete
	case XK_KP_Delete:
#endif
	case XK_Delete:
		if (!modified) {
			if (tPtr->selection.count) {
				WMDeleteTextFieldRange(tPtr, tPtr->selection);
				data = (void *)WMDeleteTextEvent;
				textEvent = WMTextDidChangeNotification;
			} else if (tPtr->cursorPosition < tPtr->textLen) {
				WMRange range;
				range.position = tPtr->cursorPosition;
				range.count = oneUTF8CharForward(&tPtr->text[tPtr->cursorPosition],
								 tPtr->textLen - tPtr->cursorPosition);
				WMDeleteTextFieldRange(tPtr, range);
				data = (void *)WMDeleteTextEvent;
				textEvent = WMTextDidChangeNotification;
			}

			relay = False;
		}
		break;

 normal_key:
	default:
		if (!controled) {
			if (count > 0 && !iscntrl(buffer[0])) {
				if (tPtr->selection.count)
					WMDeleteTextFieldRange(tPtr, tPtr->selection);
				WMInsertTextFieldText(tPtr, buffer, tPtr->cursorPosition);
				data = (void *)WMInsertTextEvent;
				textEvent = WMTextDidChangeNotification;

				relay = False;
			}
		}
		break;
	}

	if (relay) {
		WMRelayToNextResponder(W_VIEW(tPtr), event);
		return;
	}

	/* Do not allow text selection in secure text fields */
	if (cancelSelection || tPtr->flags.secure) {
		lostSelection(tPtr->view, XA_PRIMARY, NULL);

		if (tPtr->selection.count) {
			tPtr->selection.count = 0;
			refresh = 1;
		}
		tPtr->selection.position = tPtr->cursorPosition;
	} else {
		if (tPtr->selection.count != tPtr->cursorPosition - tPtr->selection.position) {

			tPtr->selection.count = tPtr->cursorPosition - tPtr->selection.position;

			refresh = 1;
		}
	}

	/*printf("(%d,%d)\n", tPtr->selection.position, tPtr->selection.count); */

	if (textEvent) {
		WMNotification *notif = WMCreateNotification(textEvent, tPtr, data);

		if (tPtr->delegate) {
			if (textEvent == WMTextDidBeginEditingNotification && tPtr->delegate->didBeginEditing)
				(*tPtr->delegate->didBeginEditing) (tPtr->delegate, notif);

			else if (textEvent == WMTextDidEndEditingNotification && tPtr->delegate->didEndEditing)
				(*tPtr->delegate->didEndEditing) (tPtr->delegate, notif);

			else if (textEvent == WMTextDidChangeNotification && tPtr->delegate->didChange)
				(*tPtr->delegate->didChange) (tPtr->delegate, notif);
		}

		WMPostNotification(notif);
		WMReleaseNotification(notif);
	}

	if (refresh)
		paintTextField(tPtr);

	/*printf("(%d,%d)\n", tPtr->selection.position, tPtr->selection.count); */
}

static int pointToCursorPosition(TextField * tPtr, int x)
{
	int a, b, pos, prev, tw;

	if (tPtr->flags.bordered)
		x -= 2;

	if (WMWidthOfString(tPtr->font, &(tPtr->text[tPtr->viewPosition]),
			    tPtr->textLen - tPtr->viewPosition) <= x)
		return tPtr->textLen;

	a = tPtr->viewPosition;
	b = tPtr->textLen;

	/* we halve the text until we get into a 10 byte vicinity of x */
	while (b - a > 10) {
		pos = (a + b) / 2;
		pos += seekUTF8CharStart(&tPtr->text[pos], pos - a);
		tw = WMWidthOfString(tPtr->font, &(tPtr->text[tPtr->viewPosition]), pos - tPtr->viewPosition);
		if (tw > x) {
			b = pos;
		} else if (tw < x) {
			a = pos;
		} else {
			return pos;
		}
	}

	/* at this point x can be positioned on any glyph between 'a' and 'b-1'
	 * inclusive, with the exception of the left border of the 'a' glyph and
	 * the right border or the 'b-1' glyph
	 *
	 * ( <--- range for x's position ---> )
	 * a a+1 .......................... b-1 b
	 */
	pos = prev = a;
	while (pos <= b) {
		tw = WMWidthOfString(tPtr->font, &(tPtr->text[tPtr->viewPosition]), pos - tPtr->viewPosition);
		if (tw > x) {
			return prev;
		} else if (pos == b) {
			break;
		}
		prev = pos;
		pos += oneUTF8CharForward(&tPtr->text[pos], b - pos);
	}

	return b;
}

static void pasteText(WMView * view, Atom selection, Atom target, Time timestamp, void *cdata, WMData * data)
{
	TextField *tPtr = (TextField *) view->self;
	char *str;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) selection;
	(void) target;
	(void) timestamp;
	(void) cdata;

	tPtr->flags.waitingSelection = 0;

	if (data != NULL) {
		str = (char *)WMDataBytes(data);

		WMInsertTextFieldText(tPtr, str, tPtr->cursorPosition);
		NOTIFY(tPtr, didChange, WMTextDidChangeNotification, (void *)WMInsertTextEvent);
	} else {
		int n;

		str = XFetchBuffer(tPtr->view->screen->display, &n, 0);

		if (str != NULL) {
			str[n] = 0;
			WMInsertTextFieldText(tPtr, str, tPtr->cursorPosition);
			XFree(str);
			NOTIFY(tPtr, didChange, WMTextDidChangeNotification, (void *)WMInsertTextEvent);
		}
	}
}

static void handleTextFieldActionEvents(XEvent * event, void *data)
{
	TextField *tPtr = (TextField *) data;
	static Time lastButtonReleasedEvent = 0;
	static Time lastButtonReleasedEvent2 = 0;
	Display *dpy = event->xany.display;

	CHECK_CLASS(data, WC_TextField);

	switch (event->type) {
	case KeyPress:
		if (tPtr->flags.waitingSelection) {
			return;
		}
		if (tPtr->flags.enabled && tPtr->flags.focused) {
			handleTextFieldKeyPress(tPtr, event);
			XDefineCursor(dpy, W_VIEW(tPtr)->window, W_VIEW(tPtr)->screen->invisibleCursor);
			tPtr->flags.pointerGrabbed = 1;
		}
		break;

	case MotionNotify:

		if (tPtr->flags.pointerGrabbed) {
			tPtr->flags.pointerGrabbed = 0;
			XDefineCursor(dpy, W_VIEW(tPtr)->window, W_VIEW(tPtr)->screen->textCursor);
		}
		if (tPtr->flags.waitingSelection) {
			return;
		}

		if (tPtr->flags.enabled && (event->xmotion.state & Button1Mask)) {

			if (tPtr->viewPosition < tPtr->textLen && event->xmotion.x > tPtr->usableWidth) {
				if (WMWidthOfString(tPtr->font,
						    &(tPtr->text[tPtr->viewPosition]),
						    tPtr->cursorPosition - tPtr->viewPosition)
				    > tPtr->usableWidth) {
					tPtr->viewPosition += oneUTF8CharForward(&tPtr->text[tPtr->viewPosition],
										 tPtr->textLen -
										 tPtr->viewPosition);
				}
			} else if (tPtr->viewPosition > 0 && event->xmotion.x < 0) {
				paintCursor(tPtr);
				tPtr->viewPosition += oneUTF8CharBackward(&tPtr->text[tPtr->viewPosition],
									  tPtr->viewPosition);
			}

			tPtr->cursorPosition = pointToCursorPosition(tPtr, event->xmotion.x);

			/* Do not allow text selection in secure textfields */
			if (tPtr->flags.secure) {
				tPtr->selection.position = tPtr->cursorPosition;
			}

			tPtr->selection.count = tPtr->cursorPosition - tPtr->selection.position;

			paintCursor(tPtr);
			paintTextField(tPtr);

		}
		break;

	case ButtonPress:
		if (tPtr->flags.pointerGrabbed) {
			tPtr->flags.pointerGrabbed = 0;
			XDefineCursor(dpy, W_VIEW(tPtr)->window, W_VIEW(tPtr)->screen->textCursor);
			break;
		}

		if (tPtr->flags.waitingSelection) {
			break;
		}

		switch (tPtr->flags.alignment) {
			int textWidth;
		case WARight:
			textWidth = WMWidthOfString(tPtr->font, tPtr->text, tPtr->textLen);
			if (tPtr->flags.enabled && !tPtr->flags.focused) {
				WMSetFocusToWidget(tPtr);
			}
			if (tPtr->flags.focused) {
				tPtr->selection.position = tPtr->cursorPosition;
				tPtr->selection.count = 0;
			}
			if (textWidth < tPtr->usableWidth) {
				tPtr->cursorPosition = pointToCursorPosition(tPtr,
									     event->xbutton.x - tPtr->usableWidth
									     + textWidth);
			} else
				tPtr->cursorPosition = pointToCursorPosition(tPtr, event->xbutton.x);

			paintTextField(tPtr);
			break;

		case WALeft:
			if (tPtr->flags.enabled && !tPtr->flags.focused) {
				WMSetFocusToWidget(tPtr);
			}
			if (tPtr->flags.focused && event->xbutton.button == Button1) {
				tPtr->cursorPosition = pointToCursorPosition(tPtr, event->xbutton.x);
				tPtr->selection.position = tPtr->cursorPosition;
				tPtr->selection.count = 0;
				paintTextField(tPtr);
			}
			if (event->xbutton.button == Button2 && tPtr->flags.enabled) {
				char *text;
				int n;

				if (!WMRequestSelection(tPtr->view, XA_PRIMARY, XA_STRING,
							event->xbutton.time, pasteText, NULL)) {
					text = XFetchBuffer(tPtr->view->screen->display, &n, 0);

					if (text) {
						text[n] = 0;
						WMInsertTextFieldText(tPtr, text, tPtr->cursorPosition);
						XFree(text);
						NOTIFY(tPtr, didChange, WMTextDidChangeNotification,
						       (void *)WMInsertTextEvent);
					}
				} else {
					tPtr->flags.waitingSelection = 1;
				}
			}
			break;
		default:
			break;
		}
		break;

	case ButtonRelease:
		if (tPtr->flags.pointerGrabbed) {
			tPtr->flags.pointerGrabbed = 0;
			XDefineCursor(dpy, W_VIEW(tPtr)->window, W_VIEW(tPtr)->screen->textCursor);
		}
		if (tPtr->flags.waitingSelection) {
			break;
		}

		if (!tPtr->flags.secure && tPtr->selection.count != 0) {
			int start, count;
			XRotateBuffers(dpy, 1);

			count = abs(tPtr->selection.count);
			if (tPtr->selection.count < 0)
				start = tPtr->selection.position - count;
			else
				start = tPtr->selection.position;

			XStoreBuffer(dpy, &tPtr->text[start], count, 0);
		}

		if (!tPtr->flags.secure &&
		    event->xbutton.time - lastButtonReleasedEvent <= WINGsConfiguration.doubleClickDelay) {

			if (event->xbutton.time - lastButtonReleasedEvent2 <=
			    2 * WINGsConfiguration.doubleClickDelay) {
				tPtr->selection.position = 0;
				tPtr->selection.count = tPtr->textLen;
			} else {
				int pos, cnt;
				char *txt;
				pos = tPtr->selection.position;
				cnt = tPtr->selection.count;
				txt = tPtr->text;
				while (pos >= 0) {
					if (txt[pos] == ' ' || txt[pos] == '\t')
						break;
					pos--;
				}
				pos++;

				while (pos + cnt < tPtr->textLen) {
					if (txt[pos + cnt] == ' ' || txt[pos + cnt] == '\t')
						break;
					cnt++;
				}
				tPtr->selection.position = pos;
				tPtr->selection.count = cnt;
			}
			paintTextField(tPtr);

			if (!tPtr->flags.ownsSelection) {
				tPtr->flags.ownsSelection =
				    WMCreateSelectionHandler(tPtr->view,
							     XA_PRIMARY,
							     event->xbutton.time, &selectionHandler, NULL);
			}
		} else if (!tPtr->flags.secure && tPtr->selection.count != 0 && !tPtr->flags.ownsSelection) {
			tPtr->flags.ownsSelection =
			    WMCreateSelectionHandler(tPtr->view,
						     XA_PRIMARY, event->xbutton.time, &selectionHandler, NULL);
		}

		lastButtonReleasedEvent2 = lastButtonReleasedEvent;
		lastButtonReleasedEvent = event->xbutton.time;

		break;
	}
}

static void destroyTextField(TextField * tPtr)
{
	if (tPtr->timerID)
		WMDeleteTimerHandler(tPtr->timerID);

	W_DestroyIC(tPtr->view);

	WMReleaseFont(tPtr->font);
	/*// use lostSelection() instead of WMDeleteSelectionHandler here? */
	WMDeleteSelectionHandler(tPtr->view, XA_PRIMARY, CurrentTime);
	WMRemoveNotificationObserver(tPtr);

	if (tPtr->text)
		wfree(tPtr->text);

	wfree(tPtr);
}
