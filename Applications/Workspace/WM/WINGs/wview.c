
#include "WINGsP.h"

#include <X11/Xresource.h>

/* the notifications about views */

char *WMViewSizeDidChangeNotification = "WMViewSizeDidChangeNotification";
char *WMViewFocusDidChangeNotification = "WMViewFocusDidChangeNotification";
char *WMViewRealizedNotification = "WMViewRealizedNotification";

#define EVENT_MASK  \
    KeyPressMask|KeyReleaseMask|ButtonPressMask|ButtonReleaseMask| \
    EnterWindowMask|LeaveWindowMask|PointerMotionMask|ExposureMask| \
    VisibilityChangeMask|FocusChangeMask|PropertyChangeMask|\
    SubstructureNotifyMask|SubstructureRedirectMask

static const XSetWindowAttributes defAtts = {
	None,			/* background_pixmap */
	0,			/* background_pixel */
	CopyFromParent,		/* border_pixmap */
	0,			/* border_pixel */
	ForgetGravity,		/* bit_gravity */
	ForgetGravity,		/* win_gravity */
	NotUseful,		/* backing_store */
	(unsigned)~0,		/* backing_planes */
	0,			/* backing_pixel */
	False,			/* save_under */
	EVENT_MASK,		/* event_mask */
	0,			/* do_not_propagate_mask */
	False,			/* override_redirect */
	None,			/* colormap */
	None			/* cursor */
};

static XContext ViewContext = 0;	/* context for views */

W_View *W_GetViewForXWindow(Display * display, Window window)
{
	W_View *view;

	if (XFindContext(display, window, ViewContext, (XPointer *) & view) == 0) {
		return view;
	}
	return NULL;
}

static void unparentView(W_View * view)
{
	/* remove from parent's children list */
	if (view->parent != NULL) {
		W_View *ptr;

		ptr = view->parent->childrenList;
		if (ptr == view) {
			view->parent->childrenList = view->nextSister;
		} else {
			while (ptr != NULL) {
				if (ptr->nextSister == view) {
					ptr->nextSister = view->nextSister;
					break;
				}
				ptr = ptr->nextSister;
			}
		}
	}
	view->parent = NULL;
}

static void adoptChildView(W_View * view, W_View * child)
{
	child->nextSister = NULL;

	/* add to end of children list of parent */
	if (view->childrenList == NULL) {
		view->childrenList = child;
	} else {
		W_View *ptr;

		ptr = view->childrenList;
		while (ptr->nextSister != NULL)
			ptr = ptr->nextSister;
		ptr->nextSister = child;
	}
	child->parent = view;
}

static W_View *createView(W_Screen * screen, W_View * parent)
{
	W_View *view;

	if (ViewContext == 0)
		ViewContext = XUniqueContext();

	view = wmalloc(sizeof(W_View));
	view->screen = screen;

	if (parent != NULL) {
		/* attributes are not valid for root window */
		view->attribFlags = CWEventMask | CWBitGravity;
		view->attribs = defAtts;

                view->attribFlags |= CWBackPixel | CWColormap | CWBorderPixel | CWBackPixmap;
                view->attribs.background_pixmap = None;
		view->attribs.background_pixel = W_PIXEL(screen->gray);
		view->attribs.border_pixel = W_PIXEL(screen->black);
		view->attribs.colormap = screen->colormap;

		view->backColor = WMRetainColor(screen->gray);

		adoptChildView(parent, view);
	}

	view->xic = 0;

	view->refCount = 1;

	view->eventHandlers = WMCreateArrayWithDestructor(4, wfree);

	return view;
}

W_View *W_CreateView(W_View * parent)
{
	return createView(parent->screen, parent);
}

W_View *W_CreateRootView(W_Screen * screen)
{
	W_View *view;

	view = createView(screen, NULL);

	view->window = screen->rootWin;

	view->flags.realized = 1;
	view->flags.mapped = 1;
	view->flags.root = 1;

	view->size.width = WidthOfScreen(ScreenOfDisplay(screen->display, screen->screen));
	view->size.height = HeightOfScreen(ScreenOfDisplay(screen->display, screen->screen));

	return view;
}

W_View *W_CreateTopView(W_Screen * screen)
{
	W_View *view;

	view = createView(screen, screen->rootView);
	if (!view)
		return NULL;

	view->flags.topLevel = 1;
	view->attribs.event_mask |= StructureNotifyMask;

	return view;
}

W_View *W_CreateUnmanagedTopView(W_Screen * screen)
{
	W_View *view;

	view = createView(screen, screen->rootView);
	if (!view)
		return NULL;

	view->flags.topLevel = 1;
	view->attribs.event_mask |= StructureNotifyMask;

	view->attribFlags |= CWOverrideRedirect;
	view->attribs.override_redirect = True;

	return view;
}

void W_RealizeView(W_View * view)
{
	Window parentWID;
	Display *dpy = view->screen->display;
	W_View *ptr;

	assert(view->size.width > 0);
	assert(view->size.height > 0);

	if (view->parent && !view->parent->flags.realized) {
		wwarning("trying to realize widget of unrealized parent");
		return;
	}

	if (!view->flags.realized) {

		if (view->parent == NULL) {
			wwarning("trying to realize widget without parent");
			return;
		}

		parentWID = view->parent->window;
		view->window = XCreateWindow(dpy, parentWID, view->pos.x, view->pos.y,
					     view->size.width, view->size.height, 0,
					     view->screen->depth, InputOutput,
					     view->screen->visual, view->attribFlags, &view->attribs);

		XSaveContext(dpy, view->window, ViewContext, (XPointer) view);

		view->flags.realized = 1;

		if (view->flags.mapWhenRealized) {
			W_MapView(view);
			view->flags.mapWhenRealized = 0;
		}

		WMPostNotificationName(WMViewRealizedNotification, view, NULL);
	}

	/* realize children */
	ptr = view->childrenList;
	while (ptr != NULL) {
		W_RealizeView(ptr);

		ptr = ptr->nextSister;
	}
}

void W_ReparentView(W_View * view, W_View * newParent, int x, int y)
{
	Display *dpy = view->screen->display;

	assert(!view->flags.topLevel);

	unparentView(view);
	adoptChildView(newParent, view);

	if (view->flags.realized) {
		if (newParent->flags.realized) {
			XReparentWindow(dpy, view->window, newParent->window, x, y);
		} else {
			wwarning("trying to reparent realized view to unrealized parent");
			return;
		}
	}

	view->pos.x = x;
	view->pos.y = y;
}

void W_RaiseView(W_View * view)
{
	if (W_VIEW_REALIZED(view))
		XRaiseWindow(W_VIEW_DISPLAY(view), W_VIEW_DRAWABLE(view));
}

void W_LowerView(W_View * view)
{
	if (W_VIEW_REALIZED(view))
		XLowerWindow(W_VIEW_DISPLAY(view), W_VIEW_DRAWABLE(view));
}

void W_MapView(W_View * view)
{
	if (!view->flags.mapped) {
		if (view->flags.realized) {
			XMapRaised(view->screen->display, view->window);
			XFlush(view->screen->display);
			view->flags.mapped = 1;
		} else {
			view->flags.mapWhenRealized = 1;
		}
	}
}

/*
 * W_MapSubviews-
 *     maps all children of the current view that where already realized.
 */
void W_MapSubviews(W_View * view)
{
	XMapSubwindows(view->screen->display, view->window);
	XFlush(view->screen->display);

	view = view->childrenList;
	while (view) {
		view->flags.mapped = 1;
		view->flags.mapWhenRealized = 0;
		view = view->nextSister;
	}
}

void W_UnmapSubviews(W_View * view)
{
	XUnmapSubwindows(view->screen->display, view->window);
	XFlush(view->screen->display);

	view = view->childrenList;
	while (view) {
		view->flags.mapped = 0;
		view->flags.mapWhenRealized = 0;
		view = view->nextSister;
	}
}

void W_UnmapView(W_View * view)
{
	view->flags.mapWhenRealized = 0;
	if (!view->flags.mapped)
		return;

	XUnmapWindow(view->screen->display, view->window);
	XFlush(view->screen->display);

	view->flags.mapped = 0;
}

W_View *W_TopLevelOfView(W_View * view)
{
	W_View *toplevel;

	for (toplevel = view; toplevel && !toplevel->flags.topLevel; toplevel = toplevel->parent) ;

	return toplevel;
}

static void destroyView(W_View * view)
{
	W_View *ptr;

	if (view->flags.alreadyDead)
		return;
	view->flags.alreadyDead = 1;

	/* delete the balloon text for the view, if there's any */
	WMSetBalloonTextForView(NULL, view);

	if (view->nextFocusChain)
		view->nextFocusChain->prevFocusChain = view->prevFocusChain;
	if (view->prevFocusChain)
		view->prevFocusChain->nextFocusChain = view->nextFocusChain;

	/* Do not leave focus in a inexisting control */
	if (W_FocusedViewOfToplevel(W_TopLevelOfView(view)) == view)
		W_SetFocusOfTopLevel(W_TopLevelOfView(view), NULL);

	if (view->flags.topLevel) {
		W_FocusInfo *info = view->screen->focusInfo;
		/* remove focus information associated to this toplevel */

		if (info) {
			if (info->toplevel == view) {
				view->screen->focusInfo = info->next;
				wfree(info);
			} else {
				while (info->next) {
					if (info->next->toplevel == view)
						break;
					info = info->next;
				}
				if (info->next) {
					W_FocusInfo *next = info->next->next;
					wfree(info->next);
					info->next = next;
				}
				/* else the toplevel did not have any focused subview */
			}
		}
	}

	/* destroy children recursively */
	while (view->childrenList != NULL) {
		ptr = view->childrenList;
		ptr->flags.parentDying = 1;

		W_DestroyView(ptr);

		if (ptr == view->childrenList) {
			view->childrenList = ptr->nextSister;
			ptr->parent = NULL;
		}
	}

	W_CallDestroyHandlers(view);

	if (view->flags.realized) {
		XDeleteContext(view->screen->display, view->window, ViewContext);

		/* if parent is being destroyed, it will die naturaly */
		if (!view->flags.parentDying || view->flags.topLevel)
			XDestroyWindow(view->screen->display, view->window);
	}

	/* remove self from parent's children list */
	unparentView(view);

	/* the array has a wfree() destructor that will be called automatically */
	WMFreeArray(view->eventHandlers);
	view->eventHandlers = NULL;

	WMRemoveNotificationObserver(view);

	W_FreeViewXdndPart(view);

	if (view->backColor)
		WMReleaseColor(view->backColor);

	wfree(view);
}

void W_DestroyView(W_View * view)
{
	view->refCount--;

	if (view->refCount < 1) {
		destroyView(view);
	}
}

void W_MoveView(W_View * view, int x, int y)
{
	assert(view->flags.root == 0);

	if (view->delegate && view->delegate->willMove) {
		(*view->delegate->willMove) (view->delegate, view, &x, &y);
	}

	if (view->pos.x == x && view->pos.y == y)
		return;

	if (view->flags.realized) {
		XMoveWindow(view->screen->display, view->window, x, y);
	}
	view->pos.x = x;
	view->pos.y = y;

	if (view->delegate && view->delegate->didMove) {
		(*view->delegate->didMove) (view->delegate, view);
	}
}

void W_ResizeView(W_View * view, unsigned int width, unsigned int height)
{
	/*int shrinked; */

	if (view->delegate && view->delegate->willResize) {
		(*view->delegate->willResize) (view->delegate, view, &width, &height);
	}

	assert(width > 0);
	assert(height > 0);

	if (view->size.width == width && view->size.height == height)
		return;

	/*shrinked = width < view->size.width || height < view->size.height; */

	if (view->flags.realized) {
		XResizeWindow(view->screen->display, view->window, width, height);
	}
	view->size.width = width;
	view->size.height = height;

	if (view->delegate && view->delegate->didResize) {
		(*view->delegate->didResize) (view->delegate, view);
	}

	/* // TODO. replace in WINGs code, with the didResize delegate */
	if (view->flags.notifySizeChanged)
		WMPostNotificationName(WMViewSizeDidChangeNotification, view, NULL);
}

void W_RedisplayView(W_View * view)
{
	XEvent ev;

	if (!view->flags.mapped)
		return;

	ev.xexpose.type = Expose;
	ev.xexpose.display = view->screen->display;
	ev.xexpose.window = view->window;
	ev.xexpose.count = 0;

	ev.xexpose.serial = 0;

	WMHandleEvent(&ev);
}

void W_SetViewBackgroundColor(W_View * view, WMColor * color)
{
	if (view->backColor)
		WMReleaseColor(view->backColor);
	view->backColor = WMRetainColor(color);

	view->attribFlags |= CWBackPixel;
	view->attribs.background_pixel = W_PIXEL(color);
	if (view->flags.realized) {
		XSetWindowBackground(view->screen->display, view->window, W_PIXEL(color));
		XClearWindow(view->screen->display, view->window);
	}
}

void W_SetViewBackgroundPixmap(W_View *view, WMPixmap *pix)
{
       if (view->backImage)
               WMReleasePixmap(view->backImage);
       view->backImage = WMRetainPixmap(pix);

       view->attribFlags |= CWBackPixmap;
       view->attribs.background_pixmap = pix->pixmap;
       if (view->flags.realized) {
               XSetWindowBackgroundPixmap(view->screen->display, view->window, pix->pixmap);
               XClearWindow(view->screen->display, view->window);
       }
}

void W_SetViewCursor(W_View * view, Cursor cursor)
{
	view->cursor = cursor;
	if (W_VIEW_REALIZED(view)) {
		XDefineCursor(W_VIEW_DISPLAY(view), W_VIEW_DRAWABLE(view), cursor);
	} else {
		view->attribFlags |= CWCursor;
		view->attribs.cursor = cursor;
	}
}

W_View *W_FocusedViewOfToplevel(W_View * view)
{
	WMScreen *scr = view->screen;
	W_FocusInfo *info;

	for (info = scr->focusInfo; info != NULL; info = info->next)
		if (view == info->toplevel)
			break;

	if (!info)
		return NULL;

	return info->focused;
}

void W_SetFocusOfTopLevel(W_View * toplevel, W_View * view)
{
	WMScreen *scr = toplevel->screen;
	XEvent event;
	W_FocusInfo *info;

	for (info = scr->focusInfo; info != NULL; info = info->next)
		if (toplevel == info->toplevel)
			break;

	if (!info) {
		info = wmalloc(sizeof(W_FocusInfo));
		info->toplevel = toplevel;
		info->focused = view;
		info->next = scr->focusInfo;
		scr->focusInfo = info;
	} else {
		event.xfocus.mode = NotifyNormal;
		event.xfocus.detail = NotifyDetailNone;
		if (info->focused) {
			/* simulate FocusOut event */
			event.xfocus.type = FocusOut;
			W_DispatchMessage(info->focused, &event);
		}
		info->focused = view;
	}
	if (view) {
		/* simulate FocusIn event */
		event.xfocus.type = FocusIn;
		W_DispatchMessage(view, &event);
	}
}

void W_BroadcastMessage(W_View * targetParent, XEvent * event)
{
	W_View *target;

	target = targetParent->childrenList;
	while (target != NULL) {
		W_DispatchMessage(target, event);

		target = target->nextSister;
	}
}

void W_DispatchMessage(W_View * target, XEvent * event)
{
	if (target->window == None)
		return;
	event->xclient.window = target->window;
	event->xclient.display = target->screen->display;

	WMHandleEvent(event);
	/*
	   XSendEvent(target->screen->display, target->window, False,
	   SubstructureNotifyMask, event);
	 */
}

WMView *W_RetainView(WMView * view)
{
	view->refCount++;

	return view;
}

void W_ReleaseView(WMView * view)
{
	view->refCount--;

	if (view->refCount < 1) {
		destroyView(view);
	}
}

WMWidget *WMWidgetOfView(WMView * view)
{
	return view->self;
}

WMSize WMGetViewSize(WMView * view)
{
	return view->size;
}

WMPoint WMGetViewPosition(WMView * view)
{
	return view->pos;
}

void WMSetViewNotifySizeChanges(WMView * view, Bool flag)
{
	view->flags.notifySizeChanged = ((flag == 0) ? 0 : 1);
}

Window WMViewXID(WMView * view)
{
	return view->window;
}

WMPoint WMGetViewScreenPosition(WMView * view)
{
	WMScreen *scr = W_VIEW_SCREEN(view);
	Window foo;
	int x, y, topX, topY;
	unsigned int bar;
	WMView *topView;

	topView = view;
	while (topView->parent && topView->parent != scr->rootView)
		topView = topView->parent;

	if (!XGetGeometry(scr->display, W_VIEW_DRAWABLE(topView), &foo, &topX, &topY, &bar, &bar, &bar, &bar)) {
		topX = topY = 0;
	}

	XTranslateCoordinates(scr->display, W_VIEW_DRAWABLE(view), scr->rootWin, 0, 0, &x, &y, &foo);

	return wmkpoint(x - topX, y - topY);
}

static void resizedParent(void *self, WMNotification * notif)
{
	WMSize size = WMGetViewSize((WMView *) WMGetNotificationObject(notif));
	WMView *view = (WMView *) self;

	W_MoveView(view, view->leftOffs, view->topOffs);
	W_ResizeView(view, size.width - (view->leftOffs + view->rightOffs),
		     size.height - (view->topOffs + view->bottomOffs));
}

void WMSetViewExpandsToParent(WMView * view, int leftOffs, int topOffs, int rightOffs, int bottomOffs)
{
	WMSize size = view->parent->size;

	view->topOffs = topOffs;
	view->bottomOffs = bottomOffs;
	view->leftOffs = leftOffs;
	view->rightOffs = rightOffs;

	WMAddNotificationObserver(resizedParent, view, WMViewSizeDidChangeNotification, view->parent);
	WMSetViewNotifySizeChanges(view->parent, True);

	W_MoveView(view, leftOffs, topOffs);
	W_ResizeView(view, size.width - (leftOffs + rightOffs), size.height - (topOffs + bottomOffs));
}
