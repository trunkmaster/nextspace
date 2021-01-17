/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2001 Dan Pascu
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#include <unistd.h>
#include <X11/Xutil.h>

#include "WM.h"

#include "util.h"
#include "string_utils.h"

#include "wscreen.h"
#include "wpixmap.h"
#include "widgets.h"
#include "wappresource.h"

#include "GNUstep.h"

void WMSetApplicationIconWindow(WMScreen *scr, Window window)
{
  scr->applicationIconWindow = window;

  if (scr->groupLeader) {
    XWMHints *hints;

    hints = XGetWMHints(scr->display, scr->groupLeader);
    hints->flags |= IconWindowHint;
    hints->icon_window = window;

    XSetWMHints(scr->display, scr->groupLeader, hints);
    XFree(hints);
  }
}

void WMSetApplicationIconImage(WMScreen *scr, RImage *image)
{
  WMPixmap *icon;

  if (scr->applicationIconImage == image)
    return;

  if (scr->applicationIconImage)
    RReleaseImage(scr->applicationIconImage);

  scr->applicationIconImage = RRetainImage(image);

  /* TODO: check whether we should set the pixmap only if there's none yet */
  if (image != NULL && (icon = WMCreatePixmapFromRImage(scr, image, 128)) != NULL) {
    WMSetApplicationIconPixmap(scr, icon);
    WMReleasePixmap(icon);
  }
}

RImage *WMGetApplicationIconImage(WMScreen *scr)
{
  return scr->applicationIconImage;
}

void WMSetApplicationIconPixmap(WMScreen *scr, WMPixmap *icon)
{
  if (scr->applicationIconPixmap == icon)
    return;

  if (scr->applicationIconPixmap)
    WMReleasePixmap(scr->applicationIconPixmap);

  scr->applicationIconPixmap = WMRetainPixmap(icon);

  if (scr->groupLeader) {
    XWMHints *hints;

    hints = XGetWMHints(scr->display, scr->groupLeader);
    hints->flags |= IconPixmapHint | IconMaskHint;
    hints->icon_pixmap = (icon != NULL ? icon->pixmap : None);
    hints->icon_mask = (icon != NULL ? icon->mask : None);

    XSetWMHints(scr->display, scr->groupLeader, hints);
    XFree(hints);
  }
}

WMPixmap *WMGetApplicationIconPixmap(WMScreen *scr)
{
  return scr->applicationIconPixmap;
}

WMPixmap *WMCreateApplicationIconBlendedPixmap(WMScreen *scr, const RColor *color)
{
  WMPixmap *pix;

  if (scr->applicationIconImage) {
    static const RColor gray = {
                                /* red   */ 0xAE,
                                /* green */ 0xAA,
                                /* blue  */ 0xAE,
                                /* alpha */ 0xFF
    };

    if (!color)
      color = &gray;

    pix = WMCreateBlendedPixmapFromRImage(scr, scr->applicationIconImage, color);
  } else {
    pix = NULL;
  }

  return pix;
}

void WMSetApplicationHasAppIcon(WMScreen *scr, Bool flag)
{
  scr->aflags.hasAppIcon = ((flag == 0) ? 0 : 1);
}

void W_InitApplication(WMScreen *scr)
{
  Window leader;
  XClassHint *classHint;
  XWMHints *hints;

  leader = XCreateSimpleWindow(scr->display, scr->rootWin, -1, -1, 1, 1, 0, 0, 0);

  if (!scr->aflags.simpleApplication) {
    classHint = XAllocClassHint();
    classHint->res_name = "groupLeader";
    classHint->res_class = WMApplication.applicationName;
    XSetClassHint(scr->display, leader, classHint);
    XFree(classHint);

    XSetCommand(scr->display, leader, WMApplication.argv, WMApplication.argc);

    hints = XAllocWMHints();

    hints->flags = WindowGroupHint;
    hints->window_group = leader;

    /* This code will never actually be reached, because to have
     *scr->applicationIconPixmap set we need to have a screen first,
     *but this function is called in the screen creation process.
     *-Dan
     */
    if (scr->applicationIconPixmap) {
      hints->flags |= IconPixmapHint;
      hints->icon_pixmap = scr->applicationIconPixmap->pixmap;
      if (scr->applicationIconPixmap->mask) {
        hints->flags |= IconMaskHint;
        hints->icon_mask = scr->applicationIconPixmap->mask;
      }
    }

    XSetWMHints(scr->display, leader, hints);

    XFree(hints);
  }
  scr->groupLeader = leader;
}

//-------------------------------------

struct W_Application WMApplication;

char *_WINGS_progname = NULL;

Bool W_ApplicationInitialized(void)
{
  return _WINGS_progname != NULL;
}

void WMInitializeApplication(const char *applicationName, int *argc, char **argv)
{
  int i;

  assert(argc != NULL);
  assert(argv != NULL);
  assert(applicationName != NULL);

  _WINGS_progname = argv[0];

  WMApplication.applicationName = wstrdup(applicationName);
  WMApplication.argc = *argc;

  WMApplication.argv = wmalloc((*argc + 1) *sizeof(char *));
  for (i = 0; i < *argc; i++) {
    WMApplication.argv[i] = wstrdup(argv[i]);
  }
  WMApplication.argv[i] = NULL;
}

void WMReleaseApplication(void)
{
  int i;

  /*
   *We save the configuration on exit, this used to be handled
   *through an 'atexit' registered function but if application
   *properly calls WMReleaseApplication then the info to that
   *will have been freed by us.
   */
  /* w_save_defaults_changes(); */

  if (WMApplication.applicationName) {
    wfree(WMApplication.applicationName);
    WMApplication.applicationName = NULL;
  }

  if (WMApplication.argv) {
    for (i = 0; i < WMApplication.argc; i++)
      wfree(WMApplication.argv[i]);

    wfree(WMApplication.argv);
    WMApplication.argv = NULL;
  }
}

char *WMGetApplicationName()
{
  return WMApplication.applicationName;
}

