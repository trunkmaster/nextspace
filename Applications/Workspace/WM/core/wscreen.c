/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
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

#include <X11/Xft/Xft.h>

#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <X11/cursorfont.h>

#include <X11/Xlocale.h>

#include "WM.h"
#include "widgets.h"
#include "winputmethod.h"
#include "wballoon.h"
#include "log_utils.h"

#include "wscreen.h"

#define STIPPLE_WIDTH 8
#define STIPPLE_HEIGHT 8
static char STIPPLE_BITS[] = { 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55 };

static void _createCutBuffers(WMScreen *scrPtr, Display *display)
{
  Atom *rootWinProps;
  int exists[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
  int count, i;

  rootWinProps = XListProperties(display, scrPtr->rootWin, &count);
  for (i = 0; i < count; i++) {
    switch (rootWinProps[i]) {
    case XA_CUT_BUFFER0:
      exists[0] = 1;
      break;
    case XA_CUT_BUFFER1:
      exists[1] = 1;
      break;
    case XA_CUT_BUFFER2:
      exists[2] = 1;
      break;
    case XA_CUT_BUFFER3:
      exists[3] = 1;
      break;
    case XA_CUT_BUFFER4:
      exists[4] = 1;
      break;
    case XA_CUT_BUFFER5:
      exists[5] = 1;
      break;
    case XA_CUT_BUFFER6:
      exists[6] = 1;
      break;
    case XA_CUT_BUFFER7:
      exists[7] = 1;
      break;
    default:
      break;
    }
  }
  if (rootWinProps) {
    XFree(rootWinProps);
  }
  for (i = 0; i < 8; i++) {
    if (!exists[i]) {
      XStoreBuffer(display, "", 0, i);
    }
  }
}

static void _setupKeyboardModifiers(WMScreen *scrPtr, Display *display)
{
  int i;
  XModifierKeymap *modmap;
  KeyCode nlock, slock;
  static int mask_table[8] = { ShiftMask, LockMask, ControlMask, Mod1Mask,
                               Mod2Mask, Mod3Mask, Mod4Mask, Mod5Mask };
  unsigned int numLockMask = 0, scrollLockMask = 0;

  nlock = XKeysymToKeycode(display, XK_Num_Lock);
  slock = XKeysymToKeycode(display, XK_Scroll_Lock);

  /*
   *Find out the masks for the NumLock and ScrollLock modifiers,
   *so that we can bind the grabs for when they are enabled too.
   */
  modmap = XGetModifierMapping(display);

  if (modmap != NULL && modmap->max_keypermod > 0) {
    for (i = 0; i < 8 *modmap->max_keypermod; i++) {
      if (modmap->modifiermap[i] == nlock && nlock != 0)
        numLockMask = mask_table[i / modmap->max_keypermod];
      else if (modmap->modifiermap[i] == slock && slock != 0)
        scrollLockMask = mask_table[i / modmap->max_keypermod];
    }
  }

  if (modmap)
    XFreeModifiermap(modmap);

  scrPtr->ignoredModifierMask = numLockMask | scrollLockMask | LockMask;
}

static void _createAtoms(WMScreen *scrPtr, Display *display)
{
  scrPtr->attribsAtom = XInternAtom(display, "_GNUSTEP_WM_ATTR", False);
  scrPtr->deleteWindowAtom = XInternAtom(display, "WM_DELETE_WINDOW", False);
  scrPtr->protocolsAtom = XInternAtom(display, "WM_PROTOCOLS", False);
  scrPtr->clipboardAtom = XInternAtom(display, "CLIPBOARD", False);
    
  scrPtr->xdndAwareAtom = XInternAtom(display, "XdndAware", False);
  scrPtr->xdndSelectionAtom = XInternAtom(display, "XdndSelection", False);
  scrPtr->xdndEnterAtom = XInternAtom(display, "XdndEnter", False);
  scrPtr->xdndLeaveAtom = XInternAtom(display, "XdndLeave", False);
  scrPtr->xdndPositionAtom = XInternAtom(display, "XdndPosition", False);
  scrPtr->xdndDropAtom = XInternAtom(display, "XdndDrop", False);
  scrPtr->xdndFinishedAtom = XInternAtom(display, "XdndFinished", False);
  scrPtr->xdndTypeListAtom = XInternAtom(display, "XdndTypeList", False);
  scrPtr->xdndActionListAtom = XInternAtom(display, "XdndActionList", False);
  scrPtr->xdndActionDescriptionAtom = XInternAtom(display, "XdndActionDescription", False);
  scrPtr->xdndStatusAtom = XInternAtom(display, "XdndStatus", False);
  scrPtr->xdndActionCopy = XInternAtom(display, "XdndActionCopy", False);
  scrPtr->xdndActionMove = XInternAtom(display, "XdndActionMove", False);
  scrPtr->xdndActionLink = XInternAtom(display, "XdndActionLink", False);
  scrPtr->xdndActionAsk = XInternAtom(display, "XdndActionAsk", False);
  scrPtr->xdndActionPrivate = XInternAtom(display, "XdndActionPrivate", False);

  scrPtr->wmIconDragOffsetAtom = XInternAtom(display, "_WINGS_DND_MOUSE_OFFSET", False);

  scrPtr->wmStateAtom = XInternAtom(display, "WM_STATE", False);

  scrPtr->utf8String = XInternAtom(display, "UTF8_STRING", False);
  scrPtr->netwmName = XInternAtom(display, "_NET_WM_NAME", False);
  scrPtr->netwmIconName = XInternAtom(display, "_NET_WM_ICON_NAME", False);
  scrPtr->netwmIcon = XInternAtom(display, "_NET_WM_ICON", False);
}

static void _createCursors(WMScreen *scrPtr, Display *display)
{
  XColor bla;
  Pixmap blank;

  scrPtr->defaultCursor = XCreateFontCursor(display, XC_left_ptr);
  
  blank = XCreatePixmap(display, scrPtr->stipple, 1, 1, 1);
  XSetForeground(display, scrPtr->monoGC, 0);
  XFillRectangle(display, blank, scrPtr->monoGC, 0, 0, 1, 1);

  scrPtr->invisibleCursor = XCreatePixmapCursor(display, blank, blank, &bla, &bla, 0, 0);
  XFreePixmap(display, blank);
}

WMScreen *WMCreateScreenWithRContext(Display *display, int screen, RContext *context)
{
  WMScreen *scrPtr;
  XGCValues gcv;
  Pixmap stipple;
  static int initialized = 0;

  if (!initialized) {
    initialized = 1;
    assert(WMApplicationInitialized());
  }

  scrPtr = malloc(sizeof(WMScreen));
  if (!scrPtr)
    return NULL;
  memset(scrPtr, 0, sizeof(WMScreen));

  scrPtr->aflags.hasAppIcon = 1;

  scrPtr->display = display;
  scrPtr->screen = screen;
  scrPtr->rcontext = context;

  scrPtr->depth = context->depth;

  scrPtr->visual = context->visual;
  scrPtr->lastEventTime = 0;

  scrPtr->colormap = context->cmap;

  scrPtr->rootWin = RootWindow(display, screen);

  scrPtr->fontCache = WMCreateHashTable(WMStringPointerHashCallbacks);

  scrPtr->xftdraw = XftDrawCreate(scrPtr->display, WMScreenDrawable(scrPtr), scrPtr->visual, scrPtr->colormap);

  /* Create missing CUT_BUFFERs */
  _createCutBuffers(scrPtr, display);

  scrPtr->ignoredModifierMask = 0;
  _setupKeyboardModifiers(scrPtr, display);

  /* initially allocate some colors */
  WMWhiteColor(scrPtr);
  WMBlackColor(scrPtr);
  WMGrayColor(scrPtr);
  WMDarkGrayColor(scrPtr);

  gcv.graphics_exposures = False;

  gcv.function = GXxor;
  gcv.foreground = WMPIXEL(scrPtr->white);
  if (gcv.foreground == 0)
    gcv.foreground = 1;
  scrPtr->xorGC = XCreateGC(display, WMScreenDrawable(scrPtr), GCFunction
                            | GCGraphicsExposures | GCForeground, &gcv);

  gcv.function = GXxor;
  gcv.foreground = WMPIXEL(scrPtr->gray);
  gcv.subwindow_mode = IncludeInferiors;
  scrPtr->ixorGC = XCreateGC(display, WMScreenDrawable(scrPtr), GCFunction
                             | GCGraphicsExposures | GCForeground | GCSubwindowMode, &gcv);

  gcv.function = GXcopy;
  scrPtr->copyGC = XCreateGC(display, WMScreenDrawable(scrPtr), GCFunction | GCGraphicsExposures, &gcv);

  scrPtr->clipGC = XCreateGC(display, WMScreenDrawable(scrPtr), GCFunction | GCGraphicsExposures, &gcv);

  stipple = XCreateBitmapFromData(display, WMScreenDrawable(scrPtr), STIPPLE_BITS, STIPPLE_WIDTH, STIPPLE_HEIGHT);
  gcv.foreground = WMPIXEL(scrPtr->darkGray);
  gcv.background = WMPIXEL(scrPtr->gray);
  gcv.fill_style = FillStippled;
  gcv.stipple = stipple;
  scrPtr->stippleGC = XCreateGC(display, WMScreenDrawable(scrPtr),
                                GCForeground | GCBackground | GCStipple
                                | GCFillStyle | GCGraphicsExposures, &gcv);

  scrPtr->drawStringGC = XCreateGC(display, WMScreenDrawable(scrPtr), GCGraphicsExposures, &gcv);
  scrPtr->drawImStringGC = XCreateGC(display, WMScreenDrawable(scrPtr), GCGraphicsExposures, &gcv);

  /* we need a 1bpp drawable for the monoGC, so borrow this one */
  scrPtr->monoGC = XCreateGC(display, stipple, 0, NULL);

  scrPtr->stipple = stipple;

  /* scrPtr->antialiasedText = WINGsConfiguration.antialiasedText; */
  scrPtr->antialiasedText = False; /* TODO */
  WMLogWarning("[TODO] Antialised text is set to false. No option exists to configure it.");

  scrPtr->normalFont = WMSystemFontOfSize(scrPtr, 0);

  scrPtr->boldFont = WMBoldSystemFontOfSize(scrPtr, 0);

  if (!scrPtr->boldFont)
    scrPtr->boldFont = scrPtr->normalFont;

  if (!scrPtr->normalFont) {
    WMLogWarning(_("could not load any fonts. Make sure your font installation"
                   " and locale settings are correct."));

    return NULL;
  }

  /* create input method stuff */
  WMInitIM(scrPtr);

  _createCursors(scrPtr, display);

  _createAtoms(scrPtr, display);
  
  scrPtr->rootView = WMCreateRootView(scrPtr);

  scrPtr->balloon = WMCreateBalloon(scrPtr);

  return scrPtr;
}
