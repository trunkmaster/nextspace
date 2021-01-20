/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
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

#include <X11/Xlib.h>

#include "util.h"
#include "log_utils.h"
#include "string_utils.h"

#include "WM.h"
#include "wscreen.h"
#include "winputmethod.h"
#include "drawing.h"

typedef struct WMIMContext {
  XIM xim;
  XIMStyle ximstyle;
} WMIMContext;

static void instantiateIM_cb(Display *display, XPointer client_data, XPointer call_data)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) display;
  (void) call_data;

  WMInitIM((WMScreen *) client_data);
}

static void destroyIM_cb(XIM xim, XPointer client_data, XPointer call_data)
{
  WMScreen *scr = (WMScreen *) client_data;
  WMView *target;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) call_data;

  if (scr->imctx->xim != xim)
    return;

  target = scr->rootView->childrenList;
  while (target != NULL) {
    WMDestroyIC(target);
    target = target->nextSister;
  }

  wfree(scr->imctx);
  scr->imctx = NULL;

  XRegisterIMInstantiateCallback(scr->display, NULL, NULL, NULL, instantiateIM_cb, (XPointer) scr);
}

void WMInitIM(WMScreen *scr)
{
  XIM xim;

  if (scr->imctx)
    return;

  xim = XOpenIM(scr->display, NULL, NULL, NULL);

  if (xim) {
    XIMStyles *im_styles;
    XIMCallback cb;
    int i;

    scr->imctx = wmalloc(sizeof(WMIMContext));
    scr->imctx->xim = xim;

    cb.callback = destroyIM_cb;
    cb.client_data = (XPointer) scr;
    if (XSetIMValues(scr->imctx->xim, XNDestroyCallback, &cb, NULL))
      WMLogWarning(_("could not add destroy callback for XIM input method"));
    XUnregisterIMInstantiateCallback(scr->display, NULL, NULL, NULL, instantiateIM_cb, (XPointer) scr);
    /* Get available input style */
    XGetIMValues(scr->imctx->xim, XNQueryInputStyle, &im_styles, NULL);

    scr->imctx->ximstyle = 0;

    for (i = 0; i < im_styles->count_styles && scr->imctx->ximstyle == 0; i++) {
      if ((im_styles->supported_styles[i] & XIMPreeditPosition) &&
          (im_styles->supported_styles[i] & XIMStatusNothing)) {
        scr->imctx->ximstyle = XIMPreeditPosition | XIMStatusNothing;
      } else if ((im_styles->supported_styles[i] & XIMPreeditNothing) &&
                 (im_styles->supported_styles[i] & XIMStatusNothing)) {
        scr->imctx->ximstyle = XIMPreeditNothing | XIMStatusNothing;
      }
    }
    XFree(im_styles);
  } else {
    XRegisterIMInstantiateCallback(scr->display, NULL, NULL, NULL, instantiateIM_cb, (XPointer) scr);
  }
}

void WMCreateIC(WMView *view)
{
  WMScreen *scr = WMViewScreen(view);
  XVaNestedList preedit_attr = NULL;

  if (view->xic || !view->flags.realized || !scr->imctx)
    return;

  if (scr->imctx->ximstyle & XIMPreeditPosition) {
    XPoint spot;
    XRectangle rect;
    int ofs;

    ofs = (view->size.height - WMFontHeight(scr->normalFont)) / 2;

    rect.x = ofs;
    rect.y = ofs;
    rect.height = WMFontHeight(scr->normalFont);
    rect.width = view->size.width - ofs *2;
    spot.x = rect.x;
    spot.y = rect.y + rect.height;

    // this really needs to be changed, but I don't know how yet -Dan
    // it used to be like this with fontsets, but no longer applies to xft
    preedit_attr = XVaCreateNestedList(0, XNSpotLocation, &spot,
                                       XNArea, &rect, XNFontInfo, scr->normalFont->font, NULL);
  }

  view->xic = XCreateIC(scr->imctx->xim, XNInputStyle, scr->imctx->ximstyle,
                        XNClientWindow, view->window,
                        preedit_attr ? XNPreeditAttributes : NULL, preedit_attr, NULL);

  if (preedit_attr)
    XFree(preedit_attr);

  if (view->xic) {
    unsigned long fevent = 0;
    XGetICValues(view->xic, XNFilterEvents, &fevent, NULL);
    XSelectInput(scr->display, view->window,
                 ButtonPressMask | ButtonReleaseMask | ExposureMask |
                 KeyPressMask | FocusChangeMask | ButtonMotionMask | fevent);
  }
}

void WMDestroyIC(WMView *view)
{
  if (view->xic) {
    XDestroyIC(view->xic);
    view->xic = 0;
  }
}

static void setPreeditArea(WMView *view)
{
  WMScreen *scr = WMViewScreen(view);
  XVaNestedList preedit_attr = NULL;

  if (view->xic && (scr->imctx->ximstyle & XIMPreeditPosition)) {
    XRectangle rect;
    int ofs;

    ofs = (view->size.height - WMFontHeight(scr->normalFont)) / 2;
    rect.x = ofs;
    rect.y = ofs;
    rect.height = WMFontHeight(scr->normalFont);
    rect.width = view->size.width - ofs *2;

    preedit_attr = XVaCreateNestedList(0, XNArea, &rect, NULL);
    XSetICValues(view->xic, XNPreeditAttributes, preedit_attr, NULL);

    if (preedit_attr) {
      XFree(preedit_attr);
    }
  }
}

void WMFocusIC(WMView *view)
{
  WMScreen *scr = WMViewScreen(view);

  if (view->xic) {
    XSetICFocus(view->xic);
    XSetICValues(view->xic, XNFocusWindow, view->window, NULL);

    if (scr->imctx->ximstyle & XIMPreeditPosition) {
      setPreeditArea(view);
    }
  }
}

void WMUnFocusIC(WMView *view)
{
  if (view->xic) {
    XUnsetICFocus(view->xic);
  }
}

void WMSetPreeditPositon(WMView *view, int x, int y)
{
  WMScreen *scr = WMViewScreen(view);
  XVaNestedList preedit_attr = NULL;

  if (view->xic && (scr->imctx->ximstyle & XIMPreeditPosition)) {
    XPoint spot;
    int ofs;

    ofs = (view->size.height - WMFontHeight(scr->normalFont)) / 2;
    spot.x = x;
    spot.y = y + view->size.height - ofs - 3;
    preedit_attr = XVaCreateNestedList(0, XNSpotLocation, &spot, NULL);
    XSetICValues(view->xic, XNPreeditAttributes, preedit_attr, NULL);
    if (preedit_attr) {
      XFree(preedit_attr);
    }
  }
}

int WMLookupString(WMView *view, XKeyPressedEvent *event, char *buffer, int buflen, KeySym *keysym, Status *status)
{
  WMScreen *scr = WMViewScreen(view);

  XSetInputFocus(scr->display, view->window, RevertToParent, CurrentTime);

#ifdef X_HAVE_UTF8_STRING
  if (view->xic)
    return Xutf8LookupString(view->xic, event, buffer, buflen, keysym, status);
#endif
  return XLookupString(event, buffer, buflen, keysym, (XComposeStatus *) status);
}
