/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
 *  Copyright (c) 2014 Window Maker Team
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <assert.h>

#include <X11/Xresource.h>
#include <X11/Xutil.h>

#include <CoreFoundation/CFNotificationCenter.h>

#include "util.h"
#include "log_utils.h"

#include "wscreen.h"
#include "dragcommon.h"
#include "wevent.h"
#include "wpixmap.h"
#include "wcolor.h"
#include "wballoon.h"

#include "wview.h"

/* the notifications about views */

CFStringRef WMViewSizeDidChangeNotification = CFSTR("WMViewSizeDidChangeNotification");
CFStringRef WMViewDidRealizeNotification = CFSTR("WMViewDidRealizeNotification");

#define EVENT_MASK                                                      \
  KeyPressMask|KeyReleaseMask|ButtonPressMask|ButtonReleaseMask|        \
  EnterWindowMask|LeaveWindowMask|PointerMotionMask|ExposureMask|       \
  VisibilityChangeMask|FocusChangeMask|PropertyChangeMask|              \
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

WMView *WMGetViewForXWindow(Display *display, Window window)
{
  WMView *view;

  if (XFindContext(display, window, ViewContext, (XPointer *) & view) == 0) {
    return view;
  }
  return NULL;
}

static void unparentView(WMView *view)
{
  /* remove from parent's children list */
  if (view->parent != NULL) {
    WMView *ptr;

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

static void adoptChildView(WMView *view, WMView *child)
{
  child->nextSister = NULL;

  /* add to end of children list of parent */
  if (view->childrenList == NULL) {
    view->childrenList = child;
  } else {
    WMView *ptr;

    ptr = view->childrenList;
    while (ptr->nextSister != NULL)
      ptr = ptr->nextSister;
    ptr->nextSister = child;
  }
  child->parent = view;
}

static void freeHandler(CFAllocatorRef allocator, const void *item)
{
  wfree((void *)item);
}

static WMView *createView(WMScreen *screen, WMView *parent)
{
  WMView *view;

  if (ViewContext == 0)
    ViewContext = XUniqueContext();

  view = wmalloc(sizeof(WMView));
  view->screen = screen;

  if (parent != NULL) {
    /* attributes are not valid for root window */
    view->attribFlags = CWEventMask | CWBitGravity;
    view->attribs = defAtts;

    view->attribFlags |= CWBackPixel | CWColormap | CWBorderPixel | CWBackPixmap;
    view->attribs.background_pixmap = None;
    view->attribs.background_pixel = WMPIXEL(screen->gray);
    view->attribs.border_pixel = WMPIXEL(screen->black);
    view->attribs.colormap = screen->colormap;

    view->backColor = WMRetainColor(screen->gray);

    adoptChildView(parent, view);
  }

  view->xic = 0;

  view->refCount = 1;

  CFArrayCallBacks cbs = {0, NULL, freeHandler, NULL, NULL};
  view->eventHandlers = CFArrayCreateMutable(kCFAllocatorDefault, 4, &cbs);

  return view;
}

WMView *WMCreateView(WMView *parent)
{
  return createView(parent->screen, parent);
}

WMView *WMCreateRootView(WMScreen *screen)
{
  WMView *view;

  view = createView(screen, NULL);

  view->window = screen->rootWin;

  view->flags.realized = 1;
  view->flags.mapped = 1;
  view->flags.root = 1;

  view->size.width = WidthOfScreen(ScreenOfDisplay(screen->display, screen->screen));
  view->size.height = HeightOfScreen(ScreenOfDisplay(screen->display, screen->screen));

  return view;
}

WMView *WMCreateTopView(WMScreen *screen)
{
  WMView *view;

  view = createView(screen, screen->rootView);
  if (!view)
    return NULL;

  view->flags.topLevel = 1;
  view->attribs.event_mask |= StructureNotifyMask;

  return view;
}

WMView *WMCreateUnmanagedTopView(WMScreen *screen)
{
  WMView *view;

  view = createView(screen, screen->rootView);
  if (!view)
    return NULL;

  view->flags.topLevel = 1;
  view->attribs.event_mask |= StructureNotifyMask;

  view->attribFlags |= CWOverrideRedirect;
  view->attribs.override_redirect = True;

  return view;
}

void WMRealizeView(WMView *view)
{
  Window parentWID;
  Display *dpy = view->screen->display;
  WMView *ptr;

  assert(view->size.width > 0);
  assert(view->size.height > 0);

  if (view->parent && !view->parent->flags.realized) {
    WMLogWarning("trying to realize widget of unrealized parent");
    return;
  }

  if (!view->flags.realized) {

    if (view->parent == NULL) {
      WMLogWarning("trying to realize widget without parent");
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
      WMMapView(view);
      view->flags.mapWhenRealized = 0;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                         WMViewDidRealizeNotification, view, NULL, TRUE);
  }

  /* realize children */
  ptr = view->childrenList;
  while (ptr != NULL) {
    WMRealizeView(ptr);

    ptr = ptr->nextSister;
  }
}

void WMReparentView(WMView *view, WMView *newParent, int x, int y)
{
  Display *dpy = view->screen->display;

  assert(!view->flags.topLevel);

  unparentView(view);
  adoptChildView(newParent, view);

  if (view->flags.realized) {
    if (newParent->flags.realized) {
      XReparentWindow(dpy, view->window, newParent->window, x, y);
    } else {
      WMLogWarning("trying to reparent realized view to unrealized parent");
      return;
    }
  }

  view->pos.x = x;
  view->pos.y = y;
}

void WMRaiseView(WMView *view)
{
  if (WMViewIsRealized(view))
    XRaiseWindow(WMViewDisplay(view), WMViewDrawable(view));
}

void WMLowerView(WMView *view)
{
  if (WMViewIsRealized(view))
    XLowerWindow(WMViewDisplay(view), WMViewDrawable(view));
}

void WMMapView(WMView *view)
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
 *WMMapSubviews-
 *    maps all children of the current view that where already realized.
 */
void WMMapSubviews(WMView *view)
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

void WMUnmapSubviews(WMView *view)
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

void WMUnmapView(WMView *view)
{
  view->flags.mapWhenRealized = 0;
  if (!view->flags.mapped)
    return;

  XUnmapWindow(view->screen->display, view->window);
  XFlush(view->screen->display);

  view->flags.mapped = 0;
}

WMView *WMTopLevelOfView(WMView *view)
{
  WMView *toplevel;

  for (toplevel = view; toplevel && !toplevel->flags.topLevel; toplevel = toplevel->parent) ;

  return toplevel;
}

static void destroyView(WMView *view)
{
  WMView *ptr;

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
  if (WMFocusedViewOfToplevel(WMTopLevelOfView(view)) == view)
    WMSetFocusOfTopLevel(WMTopLevelOfView(view), NULL);

  if (view->flags.topLevel) {
    WMFocusInfo *info = view->screen->focusInfo;
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
          WMFocusInfo *next = info->next->next;
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

    WMDestroyView(ptr);

    if (ptr == view->childrenList) {
      view->childrenList = ptr->nextSister;
      ptr->parent = NULL;
    }
  }

  WMCallDestroyHandlers(view);

  if (view->flags.realized) {
    XDeleteContext(view->screen->display, view->window, ViewContext);

    /* if parent is being destroyed, it will die naturaly */
    if (!view->flags.parentDying || view->flags.topLevel)
      XDestroyWindow(view->screen->display, view->window);
  }

  /* remove self from parent's children list */
  unparentView(view);

  /* the array has a wfree() destructor that will be called automatically */
  CFRelease(view->eventHandlers);
  view->eventHandlers = NULL;

  CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetLocalCenter(), view);

  WMFreeViewXdndPart(view);

  if (view->backColor)
    WMReleaseColor(view->backColor);

  wfree(view);
}

void WMDestroyView(WMView *view)
{
  view->refCount--;

  if (view->refCount < 1) {
    destroyView(view);
  }
}

void WMMoveView(WMView *view, int x, int y)
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

void WMResizeView(WMView *view, unsigned int width, unsigned int height)
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
    CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                         WMViewSizeDidChangeNotification, view, NULL, TRUE);
}

void WMRedisplayView(WMView *view)
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

void WMSetViewBackgroundColor(WMView *view, WMColor *color)
{
  if (view->backColor)
    WMReleaseColor(view->backColor);
  view->backColor = WMRetainColor(color);

  view->attribFlags |= CWBackPixel;
  view->attribs.background_pixel = WMPIXEL(color);
  if (view->flags.realized) {
    XSetWindowBackground(view->screen->display, view->window, WMPIXEL(color));
    XClearWindow(view->screen->display, view->window);
  }
}

void WMSetViewBackgroundPixmap(WMView *view, WMPixmap *pix)
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

void WMSetViewCursor(WMView *view, Cursor cursor)
{
  view->cursor = cursor;
  if (WMViewIsRealized(view)) {
    XDefineCursor(WMViewDisplay(view), WMViewDrawable(view), cursor);
  } else {
    view->attribFlags |= CWCursor;
    view->attribs.cursor = cursor;
  }
}

WMView *WMFocusedViewOfToplevel(WMView *view)
{
  WMScreen *scr = view->screen;
  WMFocusInfo *info;

  for (info = scr->focusInfo; info != NULL; info = info->next)
    if (view == info->toplevel)
      break;

  if (!info)
    return NULL;

  return info->focused;
}

void WMSetFocusOfTopLevel(WMView *toplevel, WMView *view)
{
  WMScreen *scr = toplevel->screen;
  XEvent event;
  WMFocusInfo *info;

  for (info = scr->focusInfo; info != NULL; info = info->next)
    if (toplevel == info->toplevel)
      break;

  if (!info) {
    info = wmalloc(sizeof(WMFocusInfo));
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
      WMDispatchMessage(info->focused, &event);
    }
    info->focused = view;
  }
  if (view) {
    /* simulate FocusIn event */
    event.xfocus.type = FocusIn;
    WMDispatchMessage(view, &event);
  }
}

void WMBroadcastMessage(WMView *targetParent, XEvent *event)
{
  WMView *target;

  target = targetParent->childrenList;
  while (target != NULL) {
    WMDispatchMessage(target, event);

    target = target->nextSister;
  }
}

void WMDispatchMessage(WMView *target, XEvent *event)
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

WMView *WMRetainView(WMView *view)
{
  view->refCount++;

  return view;
}

void WMReleaseView(WMView *view)
{
  view->refCount--;

  if (view->refCount < 1) {
    destroyView(view);
  }
}

WMWidget *WMWidgetOfView(WMView *view)
{
  return view->self;
}

WMSize WMGetViewSize(WMView *view)
{
  return view->size;
}

WMPoint WMGetViewPosition(WMView *view)
{
  return view->pos;
}

void WMSetViewNotifySizeChanges(WMView *view, Bool flag)
{
  view->flags.notifySizeChanged = ((flag == 0) ? 0 : 1);
}

Window WMViewXID(WMView *view)
{
  return view->window;
}

WMPoint WMGetViewScreenPosition(WMView *view)
{
  WMScreen *scr = WMViewScreen(view);
  Window foo;
  int x, y, topX, topY;
  unsigned int bar;
  WMView *topView;

  topView = view;
  while (topView->parent && topView->parent != scr->rootView)
    topView = topView->parent;

  if (!XGetGeometry(scr->display, WMViewDrawable(topView), &foo, &topX, &topY, &bar, &bar, &bar, &bar)) {
    topX = topY = 0;
  }

  XTranslateCoordinates(scr->display, WMViewDrawable(view), scr->rootWin, 0, 0, &x, &y, &foo);

  return WMMakePoint(x - topX, y - topY);
}

/* static void resizedParent(void *self, WMNotification *notif) */
static void resizedParent(CFNotificationCenterRef center,
                          void *observedView,
                          CFNotificationName name,
                          const void *parentView,
                          CFDictionaryRef userInfo)
{
  WMSize size = WMGetViewSize((WMView *)parentView);
  WMView *view = (WMView *)observedView;

  WMMoveView(view, view->leftOffs, view->topOffs);
  WMResizeView(view, size.width - (view->leftOffs + view->rightOffs),
               size.height - (view->topOffs + view->bottomOffs));
}

void WMSetViewExpandsToParent(WMView *view, int leftOffs, int topOffs, int rightOffs, int bottomOffs)
{
  WMSize size = view->parent->size;

  view->topOffs = topOffs;
  view->bottomOffs = bottomOffs;
  view->leftOffs = leftOffs;
  view->rightOffs = rightOffs;

  CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), view, resizedParent,
                                  WMViewSizeDidChangeNotification, view->parent,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  WMSetViewNotifySizeChanges(view->parent, True);

  WMMoveView(view, leftOffs, topOffs);
  WMResizeView(view, size.width - (leftOffs + rightOffs), size.height - (topOffs + bottomOffs));
}
