
#include <X11/Xmd.h>

#include "wconfig.h"

#include "WINGsP.h"

#include "GNUstep.h"

#include <X11/Xatom.h>

typedef struct W_Window {
	W_Class widgetClass;
	W_View *view;

	struct W_Window *nextPtr;	/* next in the window list */

	struct W_Window *owner;

	char *title;

	WMPixmap *miniImage;	/* miniwindow */
	char *miniTitle;

	char *wname;

	WMSize resizeIncrement;
	WMSize baseSize;
	WMSize minSize;
	WMSize maxSize;
	WMPoint minAspect;
	WMPoint maxAspect;

	WMPoint upos;
	WMPoint ppos;

	WMAction *closeAction;
	void *closeData;

	int level;

	struct {
		unsigned style:4;
		unsigned configured:1;
		unsigned documentEdited:1;

		unsigned setUPos:1;
		unsigned setPPos:1;
		unsigned setAspect:1;
	} flags;
} _Window;


static void willResizeWindow(W_ViewDelegate *, WMView *, unsigned *, unsigned *);

struct W_ViewDelegate _WindowViewDelegate = {
	NULL,
	NULL,
	NULL,
	NULL,
	willResizeWindow
};

#define DEFAULT_WIDTH	400
#define DEFAULT_HEIGHT	180

static void destroyWindow(_Window * win);

static void handleEvents(XEvent * event, void *clientData);

static void realizeWindow(WMWindow * win);

static void realizeObserver(void *self, WMNotification * not)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) not;

	realizeWindow(self);
}

WMWindow *WMCreatePanelWithStyleForWindow(WMWindow * owner, const char *name, int style)
{
	WMWindow *win;

	win = WMCreateWindowWithStyle(owner->view->screen, name, style);
	win->owner = owner;

	return win;
}

WMWindow *WMCreatePanelForWindow(WMWindow * owner, const char *name)
{
	return WMCreatePanelWithStyleForWindow(owner, name,
					       WMTitledWindowMask | WMClosableWindowMask | WMResizableWindowMask);
}

void WMChangePanelOwner(WMWindow * win, WMWindow * newOwner)
{
	win->owner = newOwner;

	if (win->view->flags.realized && newOwner) {
		XSetTransientForHint(win->view->screen->display, win->view->window, newOwner->view->window);
	}
}

WMWindow *WMCreateWindow(WMScreen * screen, const char *name)
{
	return WMCreateWindowWithStyle(screen, name, WMTitledWindowMask
				       | WMClosableWindowMask
				       | WMMiniaturizableWindowMask | WMResizableWindowMask);
}

WMWindow *WMCreateWindowWithStyle(WMScreen * screen, const char *name, int style)
{
	_Window *win;

	win = wmalloc(sizeof(_Window));
	win->widgetClass = WC_Window;

	win->view = W_CreateTopView(screen);
	if (!win->view) {
		wfree(win);
		return NULL;
	}
	win->view->self = win;

	win->view->delegate = &_WindowViewDelegate;

	win->wname = wstrdup(name);

	/* add to the window list of the screen (application) */
	win->nextPtr = screen->windowList;
	screen->windowList = win;

	WMCreateEventHandler(win->view, ExposureMask | StructureNotifyMask
			     | ClientMessageMask | FocusChangeMask, handleEvents, win);

	W_ResizeView(win->view, DEFAULT_WIDTH, DEFAULT_HEIGHT);

	WMAddNotificationObserver(realizeObserver, win, WMViewRealizedNotification, win->view);

	win->flags.style = style;

	win->level = WMNormalWindowLevel;

	/* kluge. Find a better solution */
	W_SetFocusOfTopLevel(win->view, win->view);

	return win;
}

static void setWindowTitle(WMWindow * win, const char *title)
{
	WMScreen *scr = win->view->screen;
	XTextProperty property;
	int result;

	result = XmbTextListToTextProperty(scr->display, (char **)&title, 1, XStdICCTextStyle, &property);
	if (result == XNoMemory || result == XLocaleNotSupported) {
		wwarning(_("window title conversion error... using STRING encoding"));
		XStoreName(scr->display, win->view->window, title);
	} else {
		XSetWMName(scr->display, win->view->window, &property);
		if (property.value)
			XFree(property.value);
	}

	XChangeProperty(scr->display, win->view->window,
			scr->netwmName, scr->utf8String, 8,
			PropModeReplace, (unsigned char *)title, strlen(title));
}

static void setMiniwindowTitle(WMWindow * win, const char *title)
{
	WMScreen *scr = win->view->screen;
	XTextProperty property;
	int result;

	result = XmbTextListToTextProperty(scr->display, (char **)&title, 1, XStdICCTextStyle, &property);
	if (result == XNoMemory || result == XLocaleNotSupported) {
		wwarning(_("icon title conversion error... using STRING encoding"));
		XSetIconName(scr->display, win->view->window, title);
	} else {
		XSetWMIconName(scr->display, win->view->window, &property);
		if (property.value)
			XFree(property.value);
	}

	XChangeProperty(scr->display, win->view->window,
			scr->netwmIconName, scr->utf8String, 8,
			PropModeReplace, (unsigned char *)title, strlen(title));
}

static void setMiniwindow(WMWindow *win, RImage *image)
{
	WMScreen *scr = win->view->screen;
	unsigned long *data;
	int x, y;
	int o;

	if (!image)
		return;

	data = wmalloc((image->width * image->height + 2) * sizeof(long));

	o = 0;
	data[o++] = image->width;
	data[o++] = image->height;

	for (y = 0; y < image->height; y++) {
		for (x = 0; x < image->width; x++) {
			unsigned long pixel;
			int offs = (x + y * image->width);

			if (image->format == RRGBFormat) {
				pixel  = ((unsigned long) image->data[offs * 3    ]) << 16;
				pixel |= ((unsigned long) image->data[offs * 3 + 1]) <<  8;
				pixel |= ((unsigned long) image->data[offs * 3 + 2]);
			} else {
				pixel  = ((unsigned long) image->data[offs * 4    ]) << 16;
				pixel |= ((unsigned long) image->data[offs * 4 + 1]) <<  8;
				pixel |= ((unsigned long) image->data[offs * 4 + 2]);
				pixel |= ((unsigned long) image->data[offs * 4 + 3]) << 24;
			}

			data[o++] = pixel;
		}
	}

	XChangeProperty(scr->display, win->view->window, scr->netwmIcon,
			XA_CARDINAL, 32, PropModeReplace,
			(unsigned char *)data, (image->width * image->height + 2));

	wfree(data);
}

void WMSetWindowTitle(WMWindow * win, const char *title)
{
	wassertr(title != NULL);

	if (win->title != NULL)
		wfree(win->title);

	win->title = wstrdup(title);

	if (win->view->flags.realized) {
		setWindowTitle(win, title);
	}
}

void WMSetWindowCloseAction(WMWindow * win, WMAction * action, void *clientData)
{
	Atom *atoms = NULL;
	Atom *newAtoms;
	int count;
	WMScreen *scr = win->view->screen;

	if (win->view->flags.realized) {
		if (action && !win->closeAction) {
			if (!XGetWMProtocols(scr->display, win->view->window, &atoms, &count)) {
				count = 0;
			}
			newAtoms = wmalloc((count + 1) * sizeof(Atom));
			if (count > 0)
				memcpy(newAtoms, atoms, count * sizeof(Atom));
			newAtoms[count++] = scr->deleteWindowAtom;
			XSetWMProtocols(scr->display, win->view->window, newAtoms, count);
			if (atoms)
				XFree(atoms);
			wfree(newAtoms);
		} else if (!action && win->closeAction) {
			int i, ncount;

			if (XGetWMProtocols(scr->display, win->view->window, &atoms, &count) && count > 0) {
				newAtoms = wmalloc((count - 1) * sizeof(Atom));
				ncount = 0;
				for (i = 0; i < count; i++) {
					if (atoms[i] != scr->deleteWindowAtom) {
						newAtoms[i] = atoms[i];
						ncount++;
					}
				}
				XSetWMProtocols(scr->display, win->view->window, newAtoms, ncount);
				if (atoms)
					XFree(atoms);
				wfree(newAtoms);
			}
		}
	}
	win->closeAction = action;
	win->closeData = clientData;
}

static void willResizeWindow(W_ViewDelegate * self, WMView * view, unsigned *width, unsigned *height)
{
	WMWindow *win = (WMWindow *) view->self;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	if (win->minSize.width > 0 && win->minSize.height > 0) {
		if (*width < win->minSize.width)
			*width = win->minSize.width;
		if (*height < win->minSize.height)
			*height = win->minSize.height;
	}

	if (win->maxSize.width > 0 && win->maxSize.height > 0) {
		if (*width > win->maxSize.width)
			*width = win->maxSize.width;
		if (*height > win->maxSize.height)
			*height = win->maxSize.height;
	}
}

static void setSizeHints(WMWindow * win)
{
	XSizeHints *hints;

	hints = XAllocSizeHints();
	if (!hints) {
		wwarning("could not allocate memory for window size hints");
		return;
	}

	hints->flags = 0;

	if (win->flags.setPPos) {
		hints->flags |= PPosition;
		hints->x = win->ppos.x;
		hints->y = win->ppos.y;
	}
	if (win->flags.setUPos) {
		hints->flags |= USPosition;
		hints->x = win->upos.x;
		hints->y = win->upos.y;
	}
	if (win->minSize.width > 0 && win->minSize.height > 0) {
		hints->flags |= PMinSize;
		hints->min_width = win->minSize.width;
		hints->min_height = win->minSize.height;
	}
	if (win->maxSize.width > 0 && win->maxSize.height > 0) {
		hints->flags |= PMaxSize;
		hints->max_width = win->maxSize.width;
		hints->max_height = win->maxSize.height;
	}
	if (win->baseSize.width > 0 && win->baseSize.height > 0) {
		hints->flags |= PBaseSize;
		hints->base_width = win->baseSize.width;
		hints->base_height = win->baseSize.height;
	}
	if (win->resizeIncrement.width > 0 && win->resizeIncrement.height > 0) {
		hints->flags |= PResizeInc;
		hints->width_inc = win->resizeIncrement.width;
		hints->height_inc = win->resizeIncrement.height;
	}
	if (win->flags.setAspect) {
		hints->flags |= PAspect;
		hints->min_aspect.x = win->minAspect.x;
		hints->min_aspect.y = win->minAspect.y;
		hints->max_aspect.x = win->maxAspect.x;
		hints->max_aspect.y = win->maxAspect.y;
	}

	if (hints->flags) {
		XSetWMNormalHints(win->view->screen->display, win->view->window, hints);
	}
	XFree(hints);
}

static void writeGNUstepWMAttr(WMScreen * scr, Window window, GNUstepWMAttributes * attr)
{
	unsigned long data[9];

	/* handle idiot compilers where array of CARD32 != struct of CARD32 */
	data[0] = attr->flags;
	data[1] = attr->window_style;
	data[2] = attr->window_level;
	data[3] = 0;		/* reserved */
	/* The X protocol says XIDs are 32bit */
	data[4] = attr->miniaturize_pixmap;
	data[5] = attr->close_pixmap;
	data[6] = attr->miniaturize_mask;
	data[7] = attr->close_mask;
	data[8] = attr->extra_flags;
	XChangeProperty(scr->display, window, scr->attribsAtom, scr->attribsAtom,
			32, PropModeReplace, (unsigned char *)data, 9);
}

static void setWindowMakerHints(WMWindow * win)
{
	GNUstepWMAttributes attribs;
	WMScreen *scr = WMWidgetScreen(win);

	memset(&attribs, 0, sizeof(GNUstepWMAttributes));
	attribs.flags = GSWindowStyleAttr | GSWindowLevelAttr | GSExtraFlagsAttr;
	attribs.window_style = win->flags.style;
	attribs.window_level = win->level;
	if (win->flags.documentEdited)
		attribs.extra_flags = GSDocumentEditedFlag;
	else
		attribs.extra_flags = 0;

	writeGNUstepWMAttr(scr, win->view->window, &attribs);
}

static void realizeWindow(WMWindow * win)
{
	XWMHints *hints;
	XClassHint *classHint;
	WMScreen *scr = win->view->screen;
	Atom atoms[4];
	int count;

	classHint = XAllocClassHint();
	classHint->res_name = win->wname;
	classHint->res_class = WMGetApplicationName();
	XSetClassHint(scr->display, win->view->window, classHint);
	XFree(classHint);

	hints = XAllocWMHints();
	hints->flags = 0;
	if (!scr->aflags.simpleApplication) {
		hints->flags |= WindowGroupHint;
		hints->window_group = scr->groupLeader;
	}
	if (win->miniImage) {
		hints->flags |= IconPixmapHint;
		hints->icon_pixmap = WMGetPixmapXID(win->miniImage);
		hints->icon_mask = WMGetPixmapMaskXID(win->miniImage);
		if (hints->icon_mask != None) {
			hints->flags |= IconMaskHint;
		}
	}
	if (hints->flags != 0)
		XSetWMHints(scr->display, win->view->window, hints);
	XFree(hints);

	count = 0;
	if (win->closeAction) {
		atoms[count++] = scr->deleteWindowAtom;
	}

	if (count > 0)
		XSetWMProtocols(scr->display, win->view->window, atoms, count);

	if (win->title || win->miniTitle)
		XmbSetWMProperties(scr->display, win->view->window, win->title,
				   win->miniTitle, NULL, 0, NULL, NULL, NULL);

	setWindowMakerHints(win);

	setSizeHints(win);

	if (win->owner) {
		XSetTransientForHint(scr->display, win->view->window, win->owner->view->window);
	}

	if (win->title)
		setWindowTitle(win, win->title);
}

void WMSetWindowAspectRatio(WMWindow * win, int minX, int minY, int maxX, int maxY)
{
	win->flags.setAspect = 1;
	win->minAspect.x = minX;
	win->minAspect.y = minY;
	win->maxAspect.x = maxX;
	win->maxAspect.y = maxY;
	if (win->view->flags.realized)
		setSizeHints(win);
}

void WMSetWindowInitialPosition(WMWindow * win, int x, int y)
{
	win->flags.setPPos = 1;
	win->ppos.x = x;
	win->ppos.y = y;
	if (win->view->flags.realized)
		setSizeHints(win);
	WMMoveWidget(win, x, y);
}

void WMSetWindowUserPosition(WMWindow * win, int x, int y)
{
	win->flags.setUPos = 1;
	win->upos.x = x;
	win->upos.y = y;
	if (win->view->flags.realized)
		setSizeHints(win);
	WMMoveWidget(win, x, y);
}

void WMSetWindowMinSize(WMWindow * win, unsigned width, unsigned height)
{
	win->minSize.width = width;
	win->minSize.height = height;
	if (win->view->flags.realized)
		setSizeHints(win);
}

void WMSetWindowMaxSize(WMWindow * win, unsigned width, unsigned height)
{
	win->maxSize.width = width;
	win->maxSize.height = height;
	if (win->view->flags.realized)
		setSizeHints(win);
}

void WMSetWindowBaseSize(WMWindow * win, unsigned width, unsigned height)
{
	/* TODO: validate sizes */
	win->baseSize.width = width;
	win->baseSize.height = height;
	if (win->view->flags.realized)
		setSizeHints(win);
}

void WMSetWindowResizeIncrements(WMWindow * win, unsigned wIncr, unsigned hIncr)
{
	win->resizeIncrement.width = wIncr;
	win->resizeIncrement.height = hIncr;
	if (win->view->flags.realized)
		setSizeHints(win);
}

void WMSetWindowLevel(WMWindow * win, int level)
{
	win->level = level;
	if (win->view->flags.realized)
		setWindowMakerHints(win);
}

void WMSetWindowDocumentEdited(WMWindow * win, Bool flag)
{
	flag = ((flag == 0) ? 0 : 1);
	if (win->flags.documentEdited != flag) {
		win->flags.documentEdited = flag;
		if (win->view->flags.realized)
			setWindowMakerHints(win);
	}
}

void WMSetWindowMiniwindowImage(WMWindow * win, RImage * image)
{
	if (win->view->flags.realized)
		setMiniwindow(win, image);
}

void WMSetWindowMiniwindowPixmap(WMWindow * win, WMPixmap * pixmap)
{
	if ((win->miniImage && !pixmap) || (!win->miniImage && pixmap)) {
		if (win->miniImage)
			WMReleasePixmap(win->miniImage);

		if (pixmap)
			win->miniImage = WMRetainPixmap(pixmap);
		else
			win->miniImage = NULL;

		if (win->view->flags.realized) {
			XWMHints *hints;

			hints = XGetWMHints(win->view->screen->display, win->view->window);
			if (!hints) {
				hints = XAllocWMHints();
				if (!hints) {
					wwarning("could not allocate memory for WM hints");
					return;
				}
				hints->flags = 0;
			}
			if (pixmap) {
				hints->flags |= IconPixmapHint;
				hints->icon_pixmap = WMGetPixmapXID(pixmap);
				hints->icon_mask = WMGetPixmapMaskXID(pixmap);
				if (hints->icon_mask != None) {
					hints->flags |= IconMaskHint;
				}
			}
			XSetWMHints(win->view->screen->display, win->view->window, hints);
			XFree(hints);
		}
	}
}

void WMSetWindowMiniwindowTitle(WMWindow * win, const char *title)
{
	if (win && ((win->miniTitle && !title) || (!win->miniTitle && title)
	    || (title && win->miniTitle && strcoll(title, win->miniTitle) != 0))) {
		if (win->miniTitle)
			wfree(win->miniTitle);

		if (title)
			win->miniTitle = wstrdup(title);
		else
			win->miniTitle = NULL;

		if (win->view->flags.realized) {
			setMiniwindowTitle(win, title);
		}
	}
}

void WMCloseWindow(WMWindow * win)
{
	WMUnmapWidget(win);
	/* withdraw the window */
	if (win->view->flags.realized)
		XWithdrawWindow(win->view->screen->display, win->view->window, win->view->screen->screen);
}

static void handleEvents(XEvent * event, void *clientData)
{
	_Window *win = (_Window *) clientData;
	W_View *view = win->view;

	switch (event->type) {
	case ClientMessage:
		if (event->xclient.message_type == win->view->screen->protocolsAtom
		    && event->xclient.format == 32
		    && event->xclient.data.l[0] == win->view->screen->deleteWindowAtom) {

			if (win->closeAction) {
				(*win->closeAction) (win, win->closeData);
			}
		}
		break;
		/*
		 * was causing windows to ignore commands like closeWindow
		 * after the windows is iconized/restored or a workspace change
		 * if this is really needed, put the MapNotify portion too and
		 * fix the restack bug in wmaker
		 case UnmapNotify:
		 WMUnmapWidget(win);
		 break;
		 *
		 case MapNotify:
		 WMMapWidget(win);
		 break;

		 */
	case DestroyNotify:
		destroyWindow(win);
		break;

	case ConfigureNotify:
		if (event->xconfigure.width != view->size.width || event->xconfigure.height != view->size.height) {

			view->size.width = event->xconfigure.width;
			view->size.height = event->xconfigure.height;

			if (view->flags.notifySizeChanged) {
				WMPostNotificationName(WMViewSizeDidChangeNotification, view, NULL);
			}
		}
		if (event->xconfigure.x != view->pos.x || event->xconfigure.y != view->pos.y) {

			if (event->xconfigure.send_event) {
				view->pos.x = event->xconfigure.x;
				view->pos.y = event->xconfigure.y;
			} else {
				Window foo;

				XTranslateCoordinates(view->screen->display,
						      view->window, view->screen->rootWin,
						      event->xconfigure.x, event->xconfigure.y,
						      &view->pos.x, &view->pos.y, &foo);
			}
		}
		break;
	}
}

static void destroyWindow(_Window * win)
{
	WMScreen *scr = win->view->screen;

	WMRemoveNotificationObserver(win);

	if (scr->windowList == win) {
		scr->windowList = scr->windowList->nextPtr;
	} else {
		WMWindow *ptr;
		ptr = scr->windowList;

		if (ptr) {
			while (ptr->nextPtr) {
				if (ptr->nextPtr == win) {
					ptr->nextPtr = ptr->nextPtr->nextPtr;
					break;
				}
				ptr = ptr->nextPtr;
			}
		}
	}

	if (win->title) {
		wfree(win->title);
	}

	if (win->miniTitle) {
		wfree(win->miniTitle);
	}

	if (win->miniImage) {
		WMReleasePixmap(win->miniImage);
	}

	if (win->wname)
		wfree(win->wname);

	wfree(win);
}
