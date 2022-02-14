/*  Dock - stack of application icons at the right edge of the screen
 *
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
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

#include "WM.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>
#include <stdlib.h>
#include <libgen.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <math.h>
#include <limits.h>

#include <core/WMcore.h>
#include <core/string_utils.h>
#include <core/util.h>
#include <core/log_utils.h>

#include <core/wevent.h>
#include <core/wcolor.h>
#include <core/drawing.h>
#include <core/wuserdefaults.h>

#ifndef PATH_MAX
#define PATH_MAX DEFAULT_PATH_MAX
#endif

#include "GNUstep.h"
#include "WM.h"
#include "wcore.h"
#include "window.h"
#include "window_attributes.h"
#include "icon.h"
#include "appicon.h"
#include "actions.h"
#include "stacking.h"
#include "dock.h"
#include "properties.h"
#include "menu.h"
#include "client.h"
#include "defaults.h"
#include "desktop.h"
#include "framewin.h"
#include "animations.h"
#include "xrandr.h"
#include "placement.h"
#include "misc.h"
#include "event.h"
#include "moveres.h"
#include "iconyard.h"

#ifdef NEXTSPACE
#include <Workspace+WM.h>
#endif

/**** Local variables ****/
#define CLIP_REWIND       1
#define CLIP_IDLE         0
#define CLIP_FORWARD      2

#define MOD_MASK wPreferences.modifier_mask
#define ALT_MOD_MASK wPreferences.alt_modifier_mask
#define ICON_SIZE wPreferences.icon_size

/***** Local variables ****/

static CFStringRef dCommand = CFSTR("Command");
static CFStringRef dPasteCommand = CFSTR("PasteCommand");
#ifdef USE_DOCK_XDND
static CFStringRef dDropCommand = CFSTR("DropCommand");
#endif
static CFStringRef dLock = CFSTR("Lock");
static CFStringRef dAutoLaunch = CFSTR("AutoLaunch");
static CFStringRef dName = CFSTR("Name");
static CFStringRef dForced = CFSTR("Forced");
static CFStringRef dBuggyApplication = CFSTR("BuggyApplication");
static CFStringRef dYes = CFSTR("Yes");
static CFStringRef dNo = CFSTR("No");

static CFStringRef dPosition = CFSTR("Position");
static CFStringRef dApplications = CFSTR("Applications");
static CFStringRef dLowered = CFSTR("Lowered");
static CFStringRef dCollapsed = CFSTR("Collapsed");
static CFStringRef dAutoCollapse = CFSTR("AutoCollapse");
static CFStringRef dAutoRaiseLower = CFSTR("AutoRaiseLower");
static CFStringRef dAutoAttractIcons = CFSTR("AutoAttractIcons");

static CFStringRef dOmnipresent = CFSTR("Omnipresent");

static CFStringRef dDock = CFSTR("Dock");
static CFStringRef dClip = CFSTR("Clip");
/* static CFStringRef dDrawers = CFSTR("Drawers"); */


static void dockIconPaint(CFRunLoopTimerRef timer, void *data);
static void iconMouseDown(WObjDescriptor *desc, XEvent *event);
static pid_t execCommand(WAppIcon *btn, const char *command, WSavedState *state);
static void trackDeadProcess(pid_t pid, unsigned char status, WDock *dock);
static int getClipButton(int px, int py);
static void toggleLowered(WDock *dock);
static void toggleCollapsed(WDock *dock);

static void clipIconExpose(WObjDescriptor *desc, XEvent *event);
static void clipLeave(WDock *dock);
static void handleClipChangeDesktop(WScreen *scr, XEvent *event);
static void clipEnterNotify(WObjDescriptor *desc, XEvent *event);
static void clipLeaveNotify(WObjDescriptor *desc, XEvent *event);
static void clipAutoCollapse(CFRunLoopTimerRef timer, void *cdata);
static void clipAutoExpand(CFRunLoopTimerRef timer, void *cdata);
static void launchDockedApplication(WAppIcon *btn, Bool withSelection);
static void clipAutoLower(CFRunLoopTimerRef timer, void *cdata);
static void clipAutoRaise(CFRunLoopTimerRef timer, void *cdata);
static WAppIcon *mainIconCreate(WScreen *scr, int type, const char *name);

static void drawerIconExpose(WObjDescriptor *desc, XEvent *event);
static void removeDrawerCallback(WMenu *menu, WMenuItem *entry);
static void drawerAppendToChain(WScreen *scr, WDock *drawer);
static char *findUniqueName(WScreen *scr, const char *instance_basename);
static void addADrawerCallback(WMenu *menu, WMenuItem *entry);
static void swapDrawers(WScreen *scr, int new_x);
static WDock* getDrawer(WScreen *scr, int y_index);
static int indexOfHole(WDock *drawer, WAppIcon *moving_aicon, int redocking);
static void drawerConsolidateIcons(WDock *drawer);

static int onScreen(WScreen *scr, int x, int y);

static void toggleLoweredCallback(WMenu *menu, WMenuItem *entry)
{
  assert(entry->clientdata != NULL);

  toggleLowered(entry->clientdata);

  entry->flags.indicator_on = !(((WDock *) entry->clientdata)->lowered);

  wMenuPaint(menu);
}

static void killCallback(WMenu *menu, WMenuItem *entry)
{
  WScreen *scr = menu->menu->screen_ptr;
  WAppIcon *icon;
  WFakeGroupLeader *fPtr = NULL;
  char *buffer, *shortname, **argv;
  int argc;

  if (!WCHECK_STATE(WSTATE_NORMAL))
    return;

  assert(entry->clientdata != NULL);

  icon = (WAppIcon *) entry->clientdata;

  icon->flags.editing = 1;

  WCHANGE_STATE(WSTATE_MODAL);

  /* strip away dir names */
  shortname = basename(icon->command);
  /* separate out command options */
  wtokensplit(shortname, &argv, &argc);

  buffer = wstrconcat(argv[0],
                      _(" will be forcibly closed.\n"
                        "Any unsaved changes will be lost.\n" "Please confirm."));

  if (icon->icon && icon->icon->owner) {
    fPtr = icon->icon->owner->fake_group;
  } else {
    /* is this really necessary? can we kill a non-running dock icon? */
    WFakeGroupLeader *item;

    for (CFIndex i = 0; i < CFArrayGetCount(scr->fakeGroupLeaders); i++) {
      item = (WFakeGroupLeader *)CFArrayGetValueAtIndex(scr->fakeGroupLeaders, i);
      if (item->leader == icon->main_window) {
        fPtr = item;
        break;
      }
    }
  }

  dispatch_async(workspace_q, ^{
      if (wPreferences.dont_confirm_kill
          || WSRunAlertPanel(_("Kill Application"),
                             buffer, _("Keep Running"), _("Kill"), NULL) == NSAlertAlternateReturn) {
        if (fPtr != NULL) {
          WWindow *wwin, *twin;

          wwin = scr->focused_window;
          while (wwin) {
            twin = wwin->prev;
            if (wwin->fake_group == fPtr)
              wClientKill(wwin);

            wwin = twin;
          }
        } else if (icon->icon && icon->icon->owner) {
          wClientKill(icon->icon->owner);
        }
      }
      wfree(buffer);
      wtokenfree(argv, argc);
      icon->flags.editing = 0;
      WCHANGE_STATE(WSTATE_NORMAL);
    });
}

/* TODO: replace this function with a member of the dock struct */
static int numberOfSelectedIcons(WDock *dock)
{
  WAppIcon *aicon;
  int i, n;

  n = 0;
  for (i = 1; i < dock->max_icons; i++) {
    aicon = dock->icon_array[i];
    if (aicon && aicon->icon->selected)
      n++;
  }

  return n;
}

static CFMutableArrayRef getSelected(WDock *dock)
{
  CFMutableArrayRef ret = CFArrayCreateMutable(kCFAllocatorDefault, 8, NULL);
  WAppIcon *btn;
  int i;

  for (i = 1; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];
    if (btn && btn->icon->selected)
      CFArrayAppendValue(ret, btn);
  }

  return ret;
}

static void paintClipButtons(WAppIcon *clipIcon, Bool lpushed, Bool rpushed)
{
  Window win = clipIcon->icon->core->window;
  WScreen *scr = clipIcon->icon->core->screen_ptr;
  XPoint p[4];
  int pt = CLIP_BUTTON_SIZE * ICON_SIZE / 64;
  int tp = ICON_SIZE - pt;
  int as = pt - 15;	/* 15 = 5+5+5 */
  GC gc = scr->draw_gc;	/* maybe use WMColorGC() instead here? */
  WMColor *color;

  color = scr->clip_title_color[CLIP_NORMAL];

  XSetForeground(dpy, gc, WMColorPixel(color));

  if (rpushed) {
    p[0].x = tp + 1;
    p[0].y = 1;
    p[1].x = ICON_SIZE - 2;
    p[1].y = 1;
    p[2].x = ICON_SIZE - 2;
    p[2].y = pt - 1;
  } else if (lpushed) {
    p[0].x = 1;
    p[0].y = tp;
    p[1].x = pt;
    p[1].y = ICON_SIZE - 2;
    p[2].x = 1;
    p[2].y = ICON_SIZE - 2;
  }
  if (lpushed || rpushed) {
    XSetForeground(dpy, scr->draw_gc, scr->white_pixel);
    XFillPolygon(dpy, win, scr->draw_gc, p, 3, Convex, CoordModeOrigin);
    XSetForeground(dpy, scr->draw_gc, scr->black_pixel);
  }

  /* top right arrow */
  p[0].x = p[3].x = ICON_SIZE - 5 - as;
  p[0].y = p[3].y = 5;
  p[1].x = ICON_SIZE - 6;
  p[1].y = 5;
  p[2].x = ICON_SIZE - 6;
  p[2].y = 4 + as;
  if (rpushed) {
    XFillPolygon(dpy, win, scr->draw_gc, p, 3, Convex, CoordModeOrigin);
    XDrawLines(dpy, win, scr->draw_gc, p, 4, CoordModeOrigin);
  } else {
    XFillPolygon(dpy, win, gc, p, 3, Convex, CoordModeOrigin);
    XDrawLines(dpy, win, gc, p, 4, CoordModeOrigin);
  }

  /* bottom left arrow */
  p[0].x = p[3].x = 5;
  p[0].y = p[3].y = ICON_SIZE - 5 - as;
  p[1].x = 5;
  p[1].y = ICON_SIZE - 6;
  p[2].x = 4 + as;
  p[2].y = ICON_SIZE - 6;
  if (lpushed) {
    XFillPolygon(dpy, win, scr->draw_gc, p, 3, Convex, CoordModeOrigin);
    XDrawLines(dpy, win, scr->draw_gc, p, 4, CoordModeOrigin);
  } else {
    XFillPolygon(dpy, win, gc, p, 3, Convex, CoordModeOrigin);
    XDrawLines(dpy, win, gc, p, 4, CoordModeOrigin);
  }
}

RImage *wClipMakeTile(RImage *normalTile)
{
  RImage *tile = RCloneImage(normalTile);
  RColor black;
  RColor dark;
  RColor light;
  int pt, tp;
  int as;

  pt = CLIP_BUTTON_SIZE * wPreferences.icon_size / 64;
  tp = wPreferences.icon_size - 1 - pt;
  as = pt - 15;

  black.alpha = 255;
  black.red = black.green = black.blue = 0;

  dark.alpha = 0;
  dark.red = dark.green = dark.blue = 60;

  light.alpha = 0;
  light.red = light.green = light.blue = 80;

  /* top right */
  ROperateLine(tile, RSubtractOperation, tp, 0, wPreferences.icon_size - 2, pt - 1, &dark);
  RDrawLine(tile, tp - 1, 0, wPreferences.icon_size - 1, pt + 1, &black);
  ROperateLine(tile, RAddOperation, tp, 2, wPreferences.icon_size - 3, pt, &light);

  /* arrow bevel */
  ROperateLine(tile, RSubtractOperation, ICON_SIZE - 7 - as, 4, ICON_SIZE - 5, 4, &dark);
  ROperateLine(tile, RSubtractOperation, ICON_SIZE - 6 - as, 5, ICON_SIZE - 5, 6 + as, &dark);
  ROperateLine(tile, RAddOperation, ICON_SIZE - 5, 4, ICON_SIZE - 5, 6 + as, &light);

  /* bottom left */
  ROperateLine(tile, RAddOperation, 2, tp + 2, pt - 2, wPreferences.icon_size - 3, &dark);
  RDrawLine(tile, 0, tp - 1, pt + 1, wPreferences.icon_size - 1, &black);
  ROperateLine(tile, RSubtractOperation, 0, tp - 2, pt + 1, wPreferences.icon_size - 2, &light);

  /* arrow bevel */
  ROperateLine(tile, RSubtractOperation, 4, ICON_SIZE - 7 - as, 4, ICON_SIZE - 5, &dark);
  ROperateLine(tile, RSubtractOperation, 5, ICON_SIZE - 6 - as, 6 + as, ICON_SIZE - 5, &dark);
  ROperateLine(tile, RAddOperation, 4, ICON_SIZE - 5, 6 + as, ICON_SIZE - 5, &light);

  return tile;
}

static void omnipresentCallback(WMenu *menu, WMenuItem *entry)
{
  WAppIcon *clickedIcon = entry->clientdata;
  WAppIcon *aicon;
  WDock *dock;
  CFMutableArrayRef selectedIcons;
  int failed;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(entry->clientdata != NULL);

  dock = clickedIcon->dock;

  selectedIcons = getSelected(dock);

  if (!CFArrayGetCount(selectedIcons))
    CFArrayAppendValue(selectedIcons, clickedIcon);

  failed = 0;
  for (CFIndex i = 0; i < CFArrayGetCount(selectedIcons); i++) {
    aicon = (WAppIcon *)CFArrayGetValueAtIndex(selectedIcons, i);
    if (wClipMakeIconOmnipresent(aicon, !aicon->flags.omnipresent) == WO_FAILED)
      failed++;
    else if (aicon->icon->selected)
      wIconSelect(aicon->icon);
  }
  CFRelease(selectedIcons);
  if (failed > 1) {
    WSRunAlertPanel(_("Dock: Warning"),
                    _("Some icons cannot be made omnipresent. "
                      "Please make sure that no other icon is "
                      "docked in the same positions on the other "
                      "desktops and the Clip is not full in "
                      "some desktop."), _("OK"), NULL, NULL);
  } else if (failed == 1) {
    WSRunAlertPanel(_("Dock: Warning"),
                    _("Icon cannot be made omnipresent. "
                      "Please make sure that no other icon is "
                      "docked in the same position on the other "
                      "desktops and the Clip is not full in "
                      "some desktop."), _("OK"), NULL, NULL);
  }
}

static void removeIcons(CFMutableArrayRef icons, WDock *dock)
{
  WAppIcon *aicon;
  int keepit;

  for (CFIndex i = 0; i < CFArrayGetCount(icons); i++) {
    aicon = (WAppIcon *)CFArrayGetValueAtIndex(icons, i);
    keepit = aicon->flags.running && wApplicationOf(aicon->main_window);
    wDockDetach(dock, aicon);
    if (keepit) {
      /* XXX: can: aicon->icon == NULL ? */
      PlaceIcon(dock->screen_ptr, &aicon->x_pos, &aicon->y_pos,
                wGetHeadForWindow(aicon->icon->owner));
      XMoveWindow(dpy, aicon->icon->core->window, aicon->x_pos, aicon->y_pos);
      if (!dock->mapped || dock->collapsed)
        XMapWindow(dpy, aicon->icon->core->window);
    }
  }
  CFRelease(icons);

  if (wPreferences.auto_arrange_icons)
    wArrangeIcons(dock->screen_ptr, True);
}

static void removeIconsCallback(WMenu *menu, WMenuItem *entry)
{
  WAppIcon *clickedIcon = (WAppIcon *) entry->clientdata;
  WDock *dock;
  CFMutableArrayRef selectedIcons;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(clickedIcon != NULL);

  dock = clickedIcon->dock;

  selectedIcons = getSelected(dock);

  if (CFArrayGetCount(selectedIcons)) {
    if (WSRunAlertPanel(dock->type == WM_CLIP ? _("Desktop Clip") : _("Drawer"),
                        _("All selected icons will be removed!"),
                        _("OK"), _("Cancel"), NULL) != NSAlertDefaultReturn) {
      CFRelease(selectedIcons);
      return;
    }
  } else {
    if (clickedIcon->xindex == 0 && clickedIcon->yindex == 0) {
      CFRelease(selectedIcons);
      return;
    }
    CFArrayAppendValue(selectedIcons, clickedIcon);
  }

  removeIcons(selectedIcons, dock);

  if (dock->type == WM_DRAWER) {
    drawerConsolidateIcons(dock);
  }
}

static void toggleAutoAttractCallback(WMenu *menu, WMenuItem *entry)
{
  WDock *dock = (WDock *) entry->clientdata;
  WScreen *scr = dock->screen_ptr;

  assert(entry->clientdata != NULL);

  dock->attract_icons = !dock->attract_icons;

  entry->flags.indicator_on = dock->attract_icons;

  wMenuPaint(menu);

  if (dock->attract_icons) {
    if (dock->type == WM_DRAWER) {
      /* The newly auto-attracting dock is a drawer: disable any clip and 
       * previously attracting drawer */

      if (!wPreferences.flags.noclip) {
        int i;
        for (i = 0; i < scr->desktop_count; i++)
          scr->desktops[ i ]->clip->attract_icons = False;
        /* dock menu will be updated later, when opened */
      }

      if (scr->attracting_drawer != NULL)
        scr->attracting_drawer->attract_icons = False;
      scr->attracting_drawer = dock;
    } else {
      /* The newly auto-attracting dock is a clip: disable
       * previously attracting drawer, if applicable */
      if (scr->attracting_drawer != NULL) {
        scr->attracting_drawer->attract_icons = False;
        /* again, its menu will be updated, later. */
        scr->attracting_drawer = NULL;
      }
    }
  }
}

static void selectCallback(WMenu *menu, WMenuItem *entry)
{
  WAppIcon *icon = (WAppIcon *) entry->clientdata;

  assert(icon != NULL);

  wIconSelect(icon->icon);

  wMenuPaint(menu);
}

static void attractIconsCallback(WMenu *menu, WMenuItem *entry)
{
  WAppIcon *clickedIcon = (WAppIcon *) entry->clientdata;
  WDock *clip; /* clip... is a WM_CLIP or a WM_DRAWER */
  WAppIcon *aicon;
  int x, y, x_pos, y_pos;
  Bool update_icon = False;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(entry->clientdata != NULL);
  clip = clickedIcon->dock;

  aicon = clip->screen_ptr->app_icon_list;

  while (aicon) {
    if (!aicon->flags.docked && wDockFindFreeSlot(clip, &x, &y)) {
      x_pos = clip->x_pos + x * ICON_SIZE;
      y_pos = clip->y_pos + y * ICON_SIZE;
      if (aicon->x_pos != x_pos || aicon->y_pos != y_pos)
        wMoveWindow(aicon->icon->core->window, aicon->x_pos, aicon->y_pos, x_pos, y_pos);

      aicon->flags.attracted = 1;
      if (!aicon->icon->shadowed) {
        aicon->icon->shadowed = 1;
        update_icon = True;
      }
      wDockAttachIcon(clip, aicon, x, y, update_icon);
      if (clip->collapsed || !clip->mapped)
        XUnmapWindow(dpy, aicon->icon->core->window);
    }
    aicon = aicon->next;
  }
}

static void selectIconsCallback(WMenu *menu, WMenuItem *entry)
{
  WAppIcon *clickedIcon = (WAppIcon *) entry->clientdata;
  WDock *dock;
  CFMutableArrayRef selectedIcons;
  WAppIcon *btn;
  int i;

  assert(clickedIcon != NULL);
  dock = clickedIcon->dock;

  selectedIcons = getSelected(dock);

  if (!CFArrayGetCount(selectedIcons)) {
    for (i = 1; i < dock->max_icons; i++) {
      btn = dock->icon_array[i];
      if (btn && !btn->icon->selected)
        wIconSelect(btn->icon);
    }
  } else {
    for (CFIndex i = 0; i < CFArrayGetCount(selectedIcons); i++) {
      btn = (WAppIcon *)CFArrayGetValueAtIndex(selectedIcons, i);
      wIconSelect(btn->icon);
    }
  }
  CFRelease(selectedIcons);

  wMenuPaint(menu);
}

static void toggleCollapsedCallback(WMenu *menu, WMenuItem *entry)
{
  assert(entry->clientdata != NULL);

  toggleCollapsed(entry->clientdata);

  entry->flags.indicator_on = ((WDock *) entry->clientdata)->collapsed;

  wMenuPaint(menu);
}

static void toggleAutoCollapseCallback(WMenu *menu, WMenuItem *entry)
{
  WDock *dock;
  assert(entry->clientdata != NULL);

  dock = (WDock *) entry->clientdata;

  dock->auto_collapse = !dock->auto_collapse;

  entry->flags.indicator_on = ((WDock *) entry->clientdata)->auto_collapse;

  wMenuPaint(menu);
}

static void toggleAutoRaiseLower(WDock *dock)
{
  WDrawerChain *dc;

  dock->auto_raise_lower = !dock->auto_raise_lower;
  if (dock->type == WM_DOCK)
    {
      for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next) {
        toggleAutoRaiseLower(dc->adrawer);
      }
    }
}

static void toggleAutoRaiseLowerCallback(WMenu *menu, WMenuItem *entry)
{
  WDock *dock;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(entry->clientdata != NULL);

  dock = (WDock *) entry->clientdata;

  toggleAutoRaiseLower(dock);

  entry->flags.indicator_on = ((WDock *) entry->clientdata)->auto_raise_lower;

  wMenuPaint(menu);
}

static void launchCallback(WMenu *menu, WMenuItem *entry)
{
  WAppIcon *btn = (WAppIcon *) entry->clientdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  launchDockedApplication(btn, False);
}

static void hideCallback(WMenu *menu, WMenuItem *entry)
{
  WApplication *wapp;
  WAppIcon *btn = (WAppIcon *) entry->clientdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  wapp = wApplicationOf(btn->icon->owner->main_window);

  if (wapp->flags.hidden) {
    wDesktopChange(btn->icon->core->screen_ptr, wapp->last_desktop, NULL);
    wUnhideApplication(wapp, False, False);
  } else {
    wApplicationHide(wapp);
  }
}

static void unhideHereCallback(WMenu *menu, WMenuItem *entry)
{
  WApplication *wapp;
  WAppIcon *btn = (WAppIcon *) entry->clientdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  wapp = wApplicationOf(btn->icon->owner->main_window);

  wUnhideApplication(wapp, False, True);
}

/* Name is only used when type == WM_DRAWER and when restoring a specific
 * drawer, with a specific name. When creating a drawer, leave name to NULL
 * and mainIconCreate will find the first unused unique name */
static WAppIcon *mainIconCreate(WScreen *scr, int type, const char *name)
{
  WAppIcon *btn;
  int x_pos;

  switch(type) {
  case WM_CLIP:
    if (scr->clip_icon)
      return scr->clip_icon;

    btn = wAppIconCreateForDock(scr, NULL, "Logo", "WMClip", TILE_CLIP);
    btn->icon->core->descriptor.handle_expose = clipIconExpose;
    x_pos = 0;
    break;
  case WM_DOCK:
  default: /* to avoid a warning about btn and x_pos, basically */
    {
      CFMutableDictionaryRef icon_desc;
      icon_desc = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
                                            &kCFTypeDictionaryKeyCallBacks,
                                            &kCFTypeDictionaryValueCallBacks);
      CFDictionarySetValue(icon_desc, CFSTR("Icon"), CFSTR(APP_ICON));
      CFDictionarySetValue(w_global.domain.window_attr->dictionary,
                           CFSTR("Workspace.GNUstep"), icon_desc);
      CFRelease(icon_desc);
      btn = wAppIconCreateForDock(scr, NULL, "Workspace", "GNUstep", TILE_NORMAL);
      x_pos = scr->width - ICON_SIZE - DOCK_EXTRA_SPACE;
      if (wPreferences.flags.clip_merged_in_dock) {
        btn->icon->core->descriptor.handle_expose = clipIconExpose;
      }
    }
    break;
  case WM_DRAWER:
    if (name == NULL)
      name = findUniqueName(scr, "Drawer");
    btn = wAppIconCreateForDock(scr, NULL, name, "WMDrawer", TILE_DRAWER);
    btn->icon->core->descriptor.handle_expose = drawerIconExpose;
    x_pos = 0;		
  }

  btn->xindex = 0;
  btn->yindex = 0;

  btn->icon->core->descriptor.handle_mousedown = iconMouseDown;
  btn->icon->core->descriptor.handle_enternotify = clipEnterNotify;
  btn->icon->core->descriptor.handle_leavenotify = clipLeaveNotify;
  btn->icon->core->descriptor.parent_type = WCLASS_DOCK_ICON;
  btn->icon->core->descriptor.parent = btn;
#ifndef NEXTSPACE
  XMapWindow(dpy, btn->icon->core->window);
#endif
  btn->x_pos = x_pos;
  btn->y_pos = 0;
  btn->flags.docked = 1;
  if (type == WM_CLIP || (type == WM_DOCK && wPreferences.flags.clip_merged_in_dock))
    scr->clip_icon = btn;

  return btn;
}

static void switchWSCommand(WMenu *menu, WMenuItem *entry)
{
  WAppIcon *btn, *icon = (WAppIcon *) entry->clientdata;
  WScreen *scr = icon->icon->core->screen_ptr;
  WDock *src, *dest;
  CFMutableArrayRef selectedIcons;
  int x, y;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  if (entry->order == scr->current_desktop)
    return;

  src = icon->dock;
  dest = scr->desktops[entry->order]->clip;

  selectedIcons = getSelected(src);

  if (CFArrayGetCount(selectedIcons)) {
    for (CFIndex i = 0; i < CFArrayGetCount(selectedIcons); i++) {
      btn = (WAppIcon *)CFArrayGetValueAtIndex(selectedIcons, i);
      if (wDockFindFreeSlot(dest, &x, &y)) {
        wDockMoveIconBetweenDocks(src, dest, btn, x, y);
        XUnmapWindow(dpy, btn->icon->core->window);
      }
    }
  } else if (icon != scr->clip_icon) {
    if (wDockFindFreeSlot(dest, &x, &y)) {
      wDockMoveIconBetweenDocks(src, dest, icon, x, y);
      XUnmapWindow(dpy, icon->icon->core->window);
    }
  }
  CFRelease(selectedIcons);
}

static void launchDockedApplication(WAppIcon *btn, Bool withSelection)
{
  WScreen *scr = btn->icon->core->screen_ptr;

  if (!btn->flags.launching &&
      ((!withSelection && btn->command != NULL) || (withSelection && btn->paste_command != NULL))) {
    if (!btn->flags.forced_dock) {
      btn->flags.relaunching = btn->flags.running;
      btn->flags.running = 1;
    }
    if (btn->wm_instance || btn->wm_class) {
      WWindowAttributes attr;
      memset(&attr, 0, sizeof(WWindowAttributes));
      wDefaultFillAttributes(btn->wm_instance, btn->wm_class, &attr, NULL, True);

      if (!attr.no_appicon && !btn->flags.buggy_app)
        btn->flags.launching = 1;
      else
        btn->flags.running = 0;
    }
    btn->flags.drop_launch = 0;
    btn->flags.paste_launch = withSelection;
    scr->last_dock = btn->dock;
    btn->pid = execCommand(btn, (withSelection ? btn->paste_command : btn->command), NULL);
    if (btn->pid > 0) {
      if (btn->flags.buggy_app) {
        /* give feedback that the app was launched */
        btn->flags.launching = 1;
        dockIconPaint(NULL, btn);
        btn->flags.launching = 0;
        WMAddTimerHandler(200, 0, dockIconPaint, btn);
      } else {
        dockIconPaint(NULL, btn);
      }
    } else {
      WMLogWarning(_("could not launch application %s"), btn->command);
      btn->flags.launching = 0;
      if (!btn->flags.relaunching)
        btn->flags.running = 0;
    }
  }
}

static void updateDesktopMenu(WMenu *menu, WAppIcon *icon)
{
  WScreen *scr = menu->frame->screen_ptr;
  int i;

  if (!menu || !icon)
    return;

  for (i = 0; i < scr->desktop_count; i++) {
    if (i < menu->items_count) {
      if (strcmp(menu->items[i]->text, scr->desktops[i]->name) != 0) {
        wfree(menu->items[i]->text);
        menu->items[i]->text = wstrdup(scr->desktops[i]->name);
        menu->flags.realized = 0;
      }
      menu->items[i]->clientdata = (void *)icon;
    } else {
      wMenuAddItem(menu, scr->desktops[i]->name, switchWSCommand, (void *)icon);

      menu->flags.realized = 0;
    }

    if (i == scr->current_desktop)
      wMenuSetEnabled(menu, i, False);
    else
      wMenuSetEnabled(menu, i, True);
  }

  if (!menu->flags.realized)
    wMenuRealize(menu);
}

static WMenu *makeDesktopMenu(WScreen *scr)
{
  WMenu *menu;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu)
    WMLogWarning(_("could not create desktop submenu for Clip menu"));

  wMenuAddItem(menu, "", switchWSCommand, (void *)scr->clip_icon);

  menu->flags.realized = 0;
  wMenuRealize(menu);

  return menu;
}

static void updateClipOptionsMenu(WMenu *menu, WDock *dock)
{
  WMenuItem *entry;
  int index = 0;

  if (!menu || !dock)
    return;

  /* keep on top */
  entry = menu->items[index];
  entry->flags.indicator_on = !dock->lowered;
  entry->clientdata = dock;
  wMenuSetEnabled(menu, index, dock->type == WM_CLIP);

  /* collapsed */
  entry = menu->items[++index];
  entry->flags.indicator_on = dock->collapsed;
  entry->clientdata = dock;

  /* auto-collapse */
  entry = menu->items[++index];
  entry->flags.indicator_on = dock->auto_collapse;
  entry->clientdata = dock;

  /* auto-raise/lower */
  entry = menu->items[++index];
  entry->flags.indicator_on = dock->auto_raise_lower;
  entry->clientdata = dock;
  wMenuSetEnabled(menu, index, dock->lowered && (dock->type == WM_CLIP));

  /* attract icons */
  entry = menu->items[++index];
  entry->flags.indicator_on = dock->attract_icons;
  entry->clientdata = dock;

  menu->flags.realized = 0;
  wMenuRealize(menu);
}

static WMenu *makeClipOptionsMenu(WScreen *scr)
{
  WMenu *menu;
  WMenuItem *entry;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu) {
    WMLogWarning(_("could not create options submenu for Clip menu"));
    return NULL;
  }

  entry = wMenuAddItem(menu, _("Keep on Top"), toggleLoweredCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  entry = wMenuAddItem(menu, _("Collapsed"), toggleCollapsedCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  entry = wMenuAddItem(menu, _("Autocollapse"), toggleAutoCollapseCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  entry = wMenuAddItem(menu, _("Autoraise"), toggleAutoRaiseLowerCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  entry = wMenuAddItem(menu, _("Autoattract Icons"), toggleAutoAttractCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  menu->flags.realized = 0;
  wMenuRealize(menu);

  return menu;
}

#ifndef NEXTSPACE
static void setDockPositionNormalCallback(WMenu *menu, WMenuEntry *entry)
{
  WDock *dock = (WDock *) entry->clientdata;
  WDrawerChain *dc;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  if (entry->flags.indicator_on) // already set, nothing to do
    return;
  // Do we come from auto raise lower or keep on top?
  if (dock->auto_raise_lower)
    {
      dock->auto_raise_lower = 0;
      // Only for aesthetic purposes, can be removed when Autoraise status is no longer exposed in drawer option menu
      for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next) {
        dc->adrawer->auto_raise_lower = 0;
      }
    }
  else
    {
      // Will take care of setting lowered = 0 in drawers
      toggleLowered(dock);
    }
  entry->flags.indicator_on = 1;
}
static void setDockPositionAutoRaiseLowerCallback(WMenu *menu, WMenuEntry *entry)
{
  WDock *dock = (WDock *) entry->clientdata;
  WDrawerChain *dc;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  if (entry->flags.indicator_on) // already set, nothing to do
    return;
  // Do we come from normal or keep on top?
  if (!dock->lowered)
    {
      toggleLowered(dock);
    }
  dock->auto_raise_lower = 1;
  // Only for aesthetic purposes, can be removed when Autoraise status is no longer exposed in drawer option menu
  for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next) {
    dc->adrawer->auto_raise_lower = 1;
  }
  entry->flags.indicator_on = 1;
}
static void setDockPositionKeepOnTopCallback(WMenu *menu, WMenuEntry *entry)
{
  WDock *dock = (WDock *) entry->clientdata;
  WDrawerChain *dc;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  if (entry->flags.indicator_on) // already set, nothing to do
    return;
  dock->auto_raise_lower = 0;
  // Only for aesthetic purposes, can be removed when Autoraise status is no longer exposed in drawer option menu
  for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next) {
    dc->adrawer->auto_raise_lower = 0;
  }
  toggleLowered(dock);
  entry->flags.indicator_on = 1;
}
static void updateDockPositionMenu(WMenu *menu, WDock *dock)
{
  WMenuEntry *entry;
  int index = 0;

  assert(menu);
  assert(dock);

  /* Normal level */
  entry = menu->entries[index++];
  entry->flags.indicator_on = (dock->lowered && !dock->auto_raise_lower);
  entry->clientdata = dock;

  /* Auto-raise/lower */
  entry = menu->entries[index++];
  entry->flags.indicator_on = dock->auto_raise_lower;
  entry->clientdata = dock;

  /* Keep on top */
  entry = menu->entries[index++];
  entry->flags.indicator_on = !dock->lowered;
  entry->clientdata = dock;
}
static WMenu *makeDockPositionMenu(WScreen *scr)
{
  /* When calling this, the dock is being created, so scr->dock is still not set
   * Therefore the callbacks' clientdata and the indicators can't be set,
   * they will be updated when the dock menu is opened. */
  WMenu *menu;
  WMenuEntry *entry;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu) {
    WMLogWarning(_("could not create options submenu for dock position menu"));
    return NULL;
  }

  entry = wMenuAddCallback(menu, _("Normal"), setDockPositionNormalCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_type = MI_DIAMOND;

  entry = wMenuAddCallback(menu, _("Auto raise & lower"), setDockPositionAutoRaiseLowerCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_type = MI_DIAMOND;

  entry = wMenuAddCallback(menu, _("Keep on Top"), setDockPositionKeepOnTopCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_type = MI_DIAMOND;

  menu->flags.realized = 0;
  wMenuRealize(menu);

  return menu;
}
#endif // !NEXTSPACE

static WMenu *dockMenuCreate(WScreen *scr, int type)
{
  WMenu *menu;
  WMenuItem *entry;

  if (type == WM_CLIP && scr->clip_menu)
    return scr->clip_menu;

  if (type == WM_DRAWER && scr->drawer_menu)
    return scr->drawer_menu;

  menu = wMenuCreate(scr, "Dock", False);
  if (type == WM_DOCK) {
#ifndef NEXTSPACE
    entry = wMenuAddCallback(menu, _("Dock position"), NULL, NULL);
    if (scr->dock_pos_menu == NULL)
      scr->dock_pos_menu = makeDockPositionMenu(scr);
    wMenuEntrySetCascade(menu, entry, scr->dock_pos_menu);
#endif
    if (!wPreferences.flags.nodrawer)
      wMenuAddItem(menu, _("Add a drawer"), addADrawerCallback, NULL);

  } else {
    if (type == WM_CLIP)
      entry = wMenuAddItem(menu, _("Clip Options"), NULL, NULL);
    else /* if (type == WM_DRAWER) */
      entry = wMenuAddItem(menu, _("Drawer options"), NULL, NULL);

    if (scr->clip_options == NULL)
      scr->clip_options = makeClipOptionsMenu(scr);

    wMenuItemSetSubmenu(menu, entry, scr->clip_options);

    /* The same menu is used for the dock and its appicons. If the menu
     * entry text is different between the two contexts, or if it can
     * change depending on some state, free the duplicated string (from
     * wMenuInsertCallback) and use gettext's string */
    entry = wMenuAddItem(menu, _("Selected"), selectCallback, NULL);
    entry->flags.indicator = 1;
    entry->flags.indicator_on = 1;
    entry->flags.indicator_type = MI_CHECK;

    entry = wMenuAddItem(menu, _("Select All Icons"), selectIconsCallback, NULL);
    wfree(entry->text);
    entry->text = _("Select All Icons"); /* can be: Unselect all icons */

    if (type == WM_CLIP) {
      entry = wMenuAddItem(menu, _("Move Icon To"), NULL, NULL);
      wfree(entry->text);
      entry->text = _("Move Icon To"); /* can be: Move Icons to */
      scr->clip_submenu = makeDesktopMenu(scr);
      if (scr->clip_submenu)
        wMenuItemSetSubmenu(menu, entry, scr->clip_submenu);
    }

    entry = wMenuAddItem(menu, _("Remove Icon"), removeIconsCallback, NULL);
    wfree(entry->text);
    entry->text = _("Remove Icon"); /* can be: Remove Icons */

    wMenuAddItem(menu, _("Attract Icons"), attractIconsCallback, NULL);
  }

  wMenuAddItem(menu, _("Launch"), launchCallback, NULL);
  wMenuAddItem(menu, _("Unhide Here"), unhideHereCallback, NULL);
  entry = wMenuAddItem(menu, _("Hide"), hideCallback, NULL);
  wfree(entry->text);
  entry->text = _("Hide"); /* can be: Unhide */
  entry = wMenuAddItem(menu, _("Kill"), killCallback, NULL);
  wfree(entry->text);
  entry->text = _("Kill"); /* can be: Remove drawer */

  if (type == WM_CLIP)
    scr->clip_menu = menu;

  if (type == WM_DRAWER)
    scr->drawer_menu = menu;

  return menu;
}

int wDockMaxIcons(WScreen *scr)
{
  WMRect head_rect = wGetRectForHead(scr, scr->xrandr_info.primary_head);
  
  return head_rect.size.height / wPreferences.icon_size;
}

WDock *wDockCreate(WScreen *scr, int type, const char *name)
{
  WDock *dock;
  WAppIcon *btn;

  dock = wmalloc(sizeof(WDock));

  switch (type) {
  case WM_CLIP:
    dock->max_icons = DOCK_MAX_ICONS;
    break;
  case WM_DRAWER:
    dock->max_icons = scr->width / wPreferences.icon_size;
    break;
  case WM_DOCK:
  default:
    dock->max_icons = wDockMaxIcons(scr);
  }

  dock->icon_array = wmalloc(sizeof(WAppIcon *) * dock->max_icons);

  btn = mainIconCreate(scr, type, name);
  btn->dock = dock;

  dock->x_pos = btn->x_pos;
  dock->y_pos = btn->y_pos;
  dock->screen_ptr = scr;
  dock->type = type;
  dock->icon_count = 1;
  if (type == WM_DRAWER)
    dock->on_right_side = scr->dock->on_right_side;
  else
    dock->on_right_side = 1;
  dock->collapsed = 0;
  dock->auto_collapse = 0;
  dock->auto_collapse_magic = NULL;
  dock->auto_raise_lower = 0;
  dock->auto_lower_magic = NULL;
  dock->auto_raise_magic = NULL;
  dock->attract_icons = 0;
  dock->lowered = 1;
  dock->icon_array[0] = btn;
  wRaiseFrame(btn->icon->core);
  XMoveWindow(dpy, btn->icon->core->window, btn->x_pos, btn->y_pos);
  /* create dock menu */
  dock->menu = dockMenuCreate(scr, type);

  if (type == WM_DRAWER) {
    drawerAppendToChain(scr, dock);
    dock->auto_collapse = 1;
  }

  return dock;
}

void wDockDestroy(WDock *dock)
{
  int i;
  WAppIcon *aicon;

  for (i = (dock->type == WM_CLIP) ? 1 : 0; i < dock->max_icons; i++) {
    aicon = dock->icon_array[i];
    if (aicon) {
      int keepit = aicon->flags.running && wApplicationOf(aicon->main_window);
      wDockDetach(dock, aicon);
      if (keepit) {
        /* XXX: can: aicon->icon == NULL ? */
        PlaceIcon(dock->screen_ptr, &aicon->x_pos, &aicon->y_pos,
                  wGetHeadForWindow(aicon->icon->owner));
        XMoveWindow(dpy, aicon->icon->core->window, aicon->x_pos, aicon->y_pos);
        if (!dock->mapped || dock->collapsed)
          XMapWindow(dpy, aicon->icon->core->window);
      }
    }
  }
  if (wPreferences.auto_arrange_icons)
    wArrangeIcons(dock->screen_ptr, True);
  wfree(dock->icon_array);
  if (dock->menu && dock->type != WM_CLIP)
    wMenuDestroy(dock->menu, True);
  if (dock->screen_ptr->last_dock == dock)
    dock->screen_ptr->last_dock = NULL;
  wfree(dock);
}

void wClipIconPaint(WAppIcon *aicon)
{
  WScreen *scr = aicon->icon->core->screen_ptr;
  WDesktop *desktop = scr->desktops[scr->current_desktop];
  WMColor *color;
  Window win = aicon->icon->core->window;
  int length, nlength;
  char *ws_name, ws_number[10];
  int ty, tx;

  wIconPaint(aicon->icon);

  length = strlen(desktop->name);
  ws_name = wmalloc(length + 1);
  snprintf(ws_name, length + 1, "%s", desktop->name);
  snprintf(ws_number, sizeof(ws_number), "%i", scr->current_desktop + 1);
  nlength = strlen(ws_number);

  if (wPreferences.flags.noclip || !desktop->clip->collapsed)
    color = scr->clip_title_color[CLIP_NORMAL];
  else
    color = scr->clip_title_color[CLIP_COLLAPSED];

  ty = ICON_SIZE - WMFontHeight(scr->clip_title_font) - 3;

  tx = CLIP_BUTTON_SIZE * ICON_SIZE / 64;

  if(wPreferences.show_clip_title)
    WMDrawString(scr->wmscreen, win, color, scr->clip_title_font, tx, ty, ws_name, length);

  tx = (ICON_SIZE / 2 - WMWidthOfString(scr->clip_title_font, ws_number, nlength)) / 2;

  WMDrawString(scr->wmscreen, win, color, scr->clip_title_font, tx, 2, ws_number, nlength);

  wfree(ws_name);

  if (aicon->flags.launching)
    XFillRectangle(dpy, aicon->icon->core->window, scr->stipple_gc,
                   0, 0, wPreferences.icon_size, wPreferences.icon_size);

  paintClipButtons(aicon, aicon->dock->lclip_button_pushed, aicon->dock->rclip_button_pushed);
}

static void clipIconExpose(WObjDescriptor *desc, XEvent *event)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) desc;
  (void) event;

  wClipIconPaint(desc->parent);
}

static void dockIconPaint(CFRunLoopTimerRef timer, void *data)
{
  WAppIcon *btn = (WAppIcon *)data;
  if (btn == btn->icon->core->screen_ptr->clip_icon) {
    wClipIconPaint(btn);
  } else if (wIsADrawer(btn)) {
    wDrawerIconPaint(btn);
  } else {
    wAppIconPaint(btn);
    save_appicon(btn, True);
  }
}

static CFMutableDictionaryRef _dockCreateIconState(WAppIcon *btn)
{
  CFMutableDictionaryRef node = NULL;
  CFStringRef command, name;
  CFStringRef position, omnipresent;
  char *tmp;
  
  if (btn) {
    if (!btn->command) {
      command = CFStringCreateWithCString(kCFAllocatorDefault, "-",
                                          kCFStringEncodingUTF8);
    }
    else {
      command = CFStringCreateWithCString(kCFAllocatorDefault, btn->command,
                                          kCFStringEncodingUTF8);
    }

    tmp = EscapeWM_CLASS(btn->wm_instance, btn->wm_class);
    name = CFStringCreateWithCString(kCFAllocatorDefault, tmp, kCFStringEncodingUTF8);
    wfree(tmp);

    if (!wPreferences.flags.clip_merged_in_dock && btn == btn->icon->core->screen_ptr->clip_icon) {
      position = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%i,%i"),
                                          btn->x_pos, btn->y_pos);
    }
    else {
      position = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%hi,%hi"),
                                          btn->xindex, btn->yindex);
    }

    node = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                     &kCFTypeDictionaryKeyCallBacks,
                                     &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(node, dCommand, command);
    CFDictionaryAddValue(node, dName, name);
    CFDictionaryAddValue(node, dAutoLaunch, btn->flags.auto_launch ? dYes : dNo);
    CFDictionaryAddValue(node, dLock, btn->flags.lock ? dYes : dNo);
    CFDictionaryAddValue(node, dForced, btn->flags.forced_dock ? dYes : dNo);
    CFDictionaryAddValue(node, dBuggyApplication, btn->flags.buggy_app ? dYes : dNo);
    CFDictionaryAddValue(node, dPosition, position);

    CFRelease(command);
    CFRelease(name);
    CFRelease(position);

    omnipresent = btn->flags.omnipresent ? dYes : dNo;
    if (btn->dock != btn->icon->core->screen_ptr->dock && (btn->xindex != 0 || btn->yindex != 0)) {
      CFDictionaryAddValue(node, dOmnipresent, omnipresent);
    }

#ifdef USE_DOCK_XDND
    if (btn->dnd_command) {
      command = CFStringCreateWithCString(kCFAllocatorDefault, btn->dnd_command,
                                          kCFStringEncodingUTF8);
      CFDictionaryAddValue(node, dDropCommand, command);
      CFRelease(command);
    }
#endif	/* USE_DOCK_XDND */

    if (btn->paste_command) {
      command = CFStringCreateWithCString(kCFAllocatorDefault, btn->paste_command,
                                          kCFStringEncodingUTF8);
      CFDictionaryAddValue(node, dPasteCommand, command);
      CFRelease(command);
    }
  }

  return node;
}

static CFMutableDictionaryRef _dockCreateState(WDock *dock)
{
  int i;
  CFMutableArrayRef list;
  CFMutableDictionaryRef icon_info;
  CFMutableDictionaryRef dock_state;
  CFStringRef value, key;

  list = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);

  for (i = (dock->type == WM_DOCK ? 0 : 1); i < dock->max_icons; i++) {
    WAppIcon *btn = dock->icon_array[i];

    if (!btn || btn->flags.attracted)
      continue;

    icon_info = _dockCreateIconState(dock->icon_array[i]);
    if (icon_info != NULL) {
      CFArrayAppendValue(list, icon_info);
      CFRelease(icon_info);
    }
  }
  
  dock_state = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                         &kCFTypeDictionaryKeyCallBacks,
                                         &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(dock_state, dApplications, list);

  if (dock->type == WM_DOCK) {
    key = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("Applications%i"),
                                   dock->screen_ptr->height);
    CFDictionarySetValue(dock_state, key, list);
    CFRelease(key);

    value = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%i,%i"),
                                     (dock->on_right_side ? -ICON_SIZE : 0), dock->y_pos);
    CFDictionarySetValue(dock_state, dPosition, value);
    CFRelease(value);
  }
  CFRelease(list);

  if (dock->type == WM_CLIP || dock->type == WM_DRAWER) {
    value = (dock->collapsed ? dYes : dNo);
    CFDictionaryAddValue(dock_state, dCollapsed, value);

    value = (dock->auto_collapse ? dYes : dNo);
    CFDictionaryAddValue(dock_state, dAutoCollapse, value);

    value = (dock->attract_icons ? dYes : dNo);
    CFDictionaryAddValue(dock_state, dAutoAttractIcons, value);
  }

  if (dock->type == WM_DOCK || dock->type == WM_CLIP) {
    value = (dock->lowered ? dYes : dNo);
    CFDictionaryAddValue(dock_state, dLowered, value);

    value = (dock->auto_raise_lower ? dYes : dNo);
    CFDictionaryAddValue(dock_state, dAutoRaiseLower, value);
  }

  return dock_state;
}

static void _dockSaveOldState(CFTypeRef key, CFTypeRef value, void *dock_state)
{
  if ((CFStringCompareWithOptions(key, CFSTR("applications"), CFRangeMake(0, 12),
                                  kCFCompareCaseInsensitive) == kCFCompareEqualTo)) {
    if (CFDictionaryGetValue(dock_state, key) == NULL) {
      CFDictionarySetValue(dock_state, key, value);
    }
  }
}

void wDockSaveState(WScreen *scr, CFDictionaryRef old_state)
{
  CFMutableDictionaryRef dock_state = _dockCreateState(scr->dock);
  CFDictionaryRef dock_old_state;

  /*
   * Copy saved states of docks with different sizes.
   */
  if (old_state && CFDictionaryGetCount(old_state)) {
    dock_old_state = CFDictionaryGetValue(old_state, dDock);
    CFDictionaryApplyFunction(dock_old_state, _dockSaveOldState, dock_state);
  }

  if (dock_state && scr->session_state) {
    CFDictionarySetValue(scr->session_state, dDock, dock_state);
    CFRelease(dock_state);
  }
}

void wClipSaveState(WScreen *scr)
{
  CFMutableDictionaryRef clip_state;

  clip_state = _dockCreateIconState(scr->clip_icon);

  CFDictionaryAddValue(scr->session_state, dClip, clip_state);

  CFRelease(clip_state);
}

CFMutableDictionaryRef wClipSaveDesktopState(WScreen *scr, int desktop)
{
  return _dockCreateState(scr->desktops[desktop]->clip);
}

static Bool getBooleanDockValue(CFStringRef value, CFStringRef key)
{
  if (value) {
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
      if (CFStringCompare(value, CFSTR("YES"), kCFCompareCaseInsensitive) == kCFCompareEqualTo)
      return True;
    } else {
      WMLogWarning(_("bad value in docked icon state info %s"),
               CFStringGetCStringPtr(key, kCFStringEncodingUTF8));
    }
  }
  return False;
}

static WAppIcon *_dockRestoreIconState(WScreen *scr, CFDictionaryRef info, int type, int index)
{
  WAppIcon *aicon;
  CFStringRef cmd, value;
  char *wclass, *winstance, *command;

  cmd = CFDictionaryGetValue(info, dCommand);
  if (!cmd || (CFGetTypeID(cmd) != CFStringGetTypeID()))
    return NULL;

  /* parse window name */
  value = CFDictionaryGetValue(info, dName);
  if (!value)
    return NULL;

  ParseWindowName(value, &winstance, &wclass, "dock");

  if (!winstance && !wclass)
    return NULL;

  /* get commands */
  command = wstrdup(CFStringGetCStringPtr(cmd, kCFStringEncodingUTF8));

  if (strcmp(command, "-") == 0) {
    wfree(command);

    if (wclass)
      wfree(wclass);
    if (winstance)
      wfree(winstance);

    return NULL;
  }

  aicon = wAppIconCreateForDock(scr, command, winstance, wclass, TILE_NORMAL);
  if (wclass) {
    wfree(wclass);
  }
  if (winstance) {
    wfree(winstance);
  }
  wfree(command);

  aicon->icon->core->descriptor.handle_mousedown = iconMouseDown;
  aicon->icon->core->descriptor.handle_enternotify = clipEnterNotify;
  aicon->icon->core->descriptor.handle_leavenotify = clipLeaveNotify;
  aicon->icon->core->descriptor.parent_type = WCLASS_DOCK_ICON;
  aicon->icon->core->descriptor.parent = aicon;

#ifdef USE_DOCK_XDND
  cmd = CFDictionaryGetValue(info, dDropCommand);
  if (cmd)
    aicon->dnd_command = wstrdup(CFStringGetCStringPtr(cmd, kCFStringEncodingUTF8));
#endif

  cmd = CFDictionaryGetValue(info, dPasteCommand);
  if (cmd)
    aicon->paste_command = wstrdup(CFStringGetCStringPtr(cmd, kCFStringEncodingUTF8));

  /* check auto launch */
  value = CFDictionaryGetValue(info, dAutoLaunch);

  aicon->flags.auto_launch = getBooleanDockValue(value, dAutoLaunch);

  /* check lock */
  value = CFDictionaryGetValue(info, dLock);

  aicon->flags.lock = getBooleanDockValue(value, dLock);

  /* check if it wasn't normally docked */
  value = CFDictionaryGetValue(info, dForced);

  aicon->flags.forced_dock = getBooleanDockValue(value, dForced);

  /* check if we can rely on the stuff in the app */
  value = CFDictionaryGetValue(info, dBuggyApplication);

  aicon->flags.buggy_app = getBooleanDockValue(value, dBuggyApplication);

  /* get position in the dock */
  value = CFDictionaryGetValue(info, dPosition);
  if (value && CFGetTypeID(value) == CFStringGetTypeID()) {
    if (sscanf(CFStringGetCStringPtr(value, kCFStringEncodingUTF8), "%hi,%hi",
               &aicon->xindex, &aicon->yindex) != 2)
      WMLogWarning(_("bad value in docked icon state info %s"),
               CFStringGetCStringPtr(dPosition, kCFStringEncodingUTF8));

    /* check position sanity */
    /* *Very* incomplete section! */
    if (type == WM_DOCK) {
      aicon->xindex = 0;
    }
  } else {
    aicon->yindex = index;
    aicon->xindex = 0;
  }

  /* check if icon is omnipresent */
  value = CFDictionaryGetValue(info, dOmnipresent);

  aicon->flags.omnipresent = getBooleanDockValue(value, dOmnipresent);

  aicon->flags.running = 0;
  aicon->flags.docked = 1;

  return aicon;
}

#define COMPLAIN(key) WMLogWarning(_("bad value in dock state info:%s"), key)

WAppIcon *wClipRestoreState(WScreen *scr, CFDictionaryRef clip_state)
{
  WAppIcon *icon;
  CFStringRef value;

  icon = mainIconCreate(scr, WM_CLIP, NULL);

  if (!clip_state)
    return icon;

  CFRetain(clip_state);

  /* restore position */

  value = CFDictionaryGetValue(clip_state, dPosition);

  if (value) {
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      COMPLAIN("Position");
    } else {
      if (sscanf(CFStringGetCStringPtr(value, kCFStringEncodingUTF8), "%i,%i",
                 &icon->x_pos, &icon->y_pos) != 2)
        COMPLAIN("Position");

      /* check position sanity */
      if (!onScreen(scr, icon->x_pos, icon->y_pos))
        wScreenKeepInside(scr, &icon->x_pos, &icon->y_pos, ICON_SIZE, ICON_SIZE);
    }
  }
#ifdef USE_DOCK_XDND
  value = CFDictionaryGetValue(clip_state, dDropCommand);
  if (value && (CFGetTypeID(value) == CFStringGetTypeID()))
    icon->dnd_command = wstrdup(CFStringGetCStringPtr(value, kCFStringEncodingUTF8));
#endif

  value = CFDictionaryGetValue(clip_state, dPasteCommand);
  if (value && (CFGetTypeID(value) == CFStringGetTypeID()))
    icon->paste_command = wstrdup(CFStringGetCStringPtr(value, kCFStringEncodingUTF8));

  CFRelease(clip_state);

  return icon;
}

WDock *wDockRestoreState(WScreen *scr, CFDictionaryRef dock_state, int type)
{
  WDock *dock;
  CFArrayRef apps;
  CFStringRef value;
  WAppIcon *aicon, *old_top;
  int count, i;

  dock = wDockCreate(scr, type, NULL);

  if (!dock_state)
    return dock;

  CFRetain(dock_state);

  /* restore position */
  value = CFDictionaryGetValue(dock_state, dPosition);
  if (value) {
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      COMPLAIN("Position");
    } else {
      if (sscanf(CFStringGetCStringPtr(value, kCFStringEncodingUTF8), "%i,%i",
                 &dock->x_pos, &dock->y_pos) != 2)
        COMPLAIN("Position");

      /* check position sanity */
      if (!onScreen(scr, dock->x_pos, dock->y_pos)) {
        int x = dock->x_pos;
        wScreenKeepInside(scr, &x, &dock->y_pos, ICON_SIZE, ICON_SIZE);
      }

      /* Is this needed any more? */
      if (type == WM_CLIP) {
        if (dock->x_pos < 0) {
          dock->x_pos = 0;
        } else if (dock->x_pos > scr->width - ICON_SIZE) {
          dock->x_pos = scr->width - ICON_SIZE;
        }
      } else {
        if (dock->x_pos >= 0) {
          dock->x_pos = DOCK_EXTRA_SPACE;
          dock->on_right_side = 0;
        } else {
          dock->x_pos = scr->width - DOCK_EXTRA_SPACE - ICON_SIZE;
          dock->on_right_side = 1;
        }
      }
    }
  }

  /* restore lowered/raised state */
  dock->lowered = 0;
  value = CFDictionaryGetValue(dock_state, dLowered);
  if (value) {
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      COMPLAIN("Lowered");
    } else {
      if (CFStringCompare(value, CFSTR("YES"), kCFCompareCaseInsensitive) == kCFCompareEqualTo)
        dock->lowered = 1;
    }
  }

  /* restore collapsed state */
  dock->collapsed = 0;
  value = CFDictionaryGetValue(dock_state, dCollapsed);
  if (value) {
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      COMPLAIN("Collapsed");
    } else {
      if (CFStringCompare(value, CFSTR("YES"), kCFCompareCaseInsensitive) == kCFCompareEqualTo)
        dock->collapsed = 1;
    }
  }

  /* restore auto-collapsed state */
  value = CFDictionaryGetValue(dock_state, dAutoCollapse);
  if (value) {
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      COMPLAIN("AutoCollapse");
    } else {
      if (CFStringCompare(value, CFSTR("YES"), kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
        dock->auto_collapse = 1;
        dock->collapsed = 1;
      }
    }
  }

  /* restore auto-raise/lower state */
  value = CFDictionaryGetValue(dock_state, dAutoRaiseLower);
  if (value) {
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      COMPLAIN("AutoRaiseLower");
    } else {
      if (CFStringCompare(value, CFSTR("YES"), kCFCompareCaseInsensitive) == kCFCompareEqualTo)
        dock->auto_raise_lower = 1;
    }
  }

  /* restore attract icons state */
  dock->attract_icons = 0;
  value = CFDictionaryGetValue(dock_state, dAutoAttractIcons);
  if (value) {
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      COMPLAIN("AutoAttractIcons");
    } else {
      if (CFStringCompare(value, CFSTR("YES"), kCFCompareCaseInsensitive) == kCFCompareEqualTo)
        dock->attract_icons = 1;
    }
  }

  /* application list */
  {
    CFStringRef tmp;

    /*
     * When saving, it saves the dock state in
     * Applications and Applicationsnnn
     *
     * When loading, it will first try Applicationsnnn.
     * If it does not exist, use Applications as default.
     */

    tmp = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("Applications%i"),
                                   scr->height);
    apps = CFDictionaryGetValue(dock_state, tmp);
    CFRelease(tmp);

    if (!apps) {
      apps = CFDictionaryGetValue(dock_state, dApplications);
    }
  }

  if (!apps)
    goto finish;

  count = CFArrayGetCount(apps);
  if (count == 0)
    goto finish;

  old_top = dock->icon_array[0];

  /* dock->icon_count is set to 1 when dock is created.
   * Since Clip is already restored, we want to keep it so for clip,
   * but for dock we may change the default top tile, so we set it to 0.
   */
  if (type == WM_DOCK)
    dock->icon_count = 0;

  for (i = 0; i < count; i++) {
    if (dock->icon_count >= dock->max_icons) {
      WMLogWarning(_("there are too many icons stored in dock. Ignoring what doesn't fit"));
      break;
    }

    value = CFArrayGetValueAtIndex(apps, i);
    aicon = _dockRestoreIconState(scr, (CFDictionaryRef)value, type, dock->icon_count);

    dock->icon_array[dock->icon_count] = aicon;

    if (aicon) {
      aicon->dock = dock;
      aicon->x_pos = dock->x_pos + (aicon->xindex * ICON_SIZE);
      aicon->y_pos = dock->y_pos + (aicon->yindex * ICON_SIZE);

      if (dock->lowered)
        ChangeStackingLevel(aicon->icon->core, NSNormalWindowLevel);
      else
        ChangeStackingLevel(aicon->icon->core, NSDockWindowLevel);

      wCoreConfigure(aicon->icon->core, aicon->x_pos, aicon->y_pos, 0, 0);
#ifndef NEXTSPACE
      if (!dock->collapsed) {
        XMapWindow(dpy, aicon->icon->core->window);
      }
      wRaiseFrame(aicon->icon->core);
#endif

      dock->icon_count++;
    }
    else if (dock->icon_count == 0 && type == WM_DOCK) {
      dock->icon_count++;
    }
  }

  /* if the first icon is not defined, use the default */
  if (dock->icon_array[0] == NULL) {
    /* update default icon */
    old_top->x_pos = dock->x_pos;
    old_top->y_pos = dock->y_pos;
    if (dock->lowered)
      ChangeStackingLevel(old_top->icon->core, NSNormalWindowLevel);
    else
      ChangeStackingLevel(old_top->icon->core, NSDockWindowLevel);

    dock->icon_array[0] = old_top;
    XMoveWindow(dpy, old_top->icon->core->window, dock->x_pos, dock->y_pos);
    /* we don't need to increment dock->icon_count here because it was
     * incremented in the loop above.
     */
  }
  else if (old_top != dock->icon_array[0]) {
    if (old_top == scr->clip_icon) { // TODO dande: understand the logic
      scr->clip_icon = dock->icon_array[0];
    }
    wAppIconDestroy(old_top);
  }

  // Workspace Manager
  dock->icon_array[0]->flags.launching = 1;
  dock->icon_array[0]->flags.running = 0;
  dock->icon_array[0]->flags.lock = 1;

 finish:
  CFRelease(dock_state);

  return dock;
}

void wDockLaunchWithState(WAppIcon *btn, WSavedState *state)
{
  if (btn && btn->command && !btn->flags.running && !btn->flags.launching) {
    btn->flags.drop_launch = 0;
    btn->flags.paste_launch = 0;

    btn->pid = execCommand(btn, btn->command, state);

    if (btn->pid > 0) {
      if (!btn->flags.forced_dock && !btn->flags.buggy_app) {
        btn->flags.launching = 1;
        dockIconPaint(NULL, btn);
      }
    }
  } else {
    wfree(state);
  }
}

void wDockDoAutoLaunch(WDock *dock, int desktop)
{
  WAppIcon    *btn;
  WSavedState *state;
  char        *command = NULL;
  CFStringRef  cmd;

  for (int i = 0; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];
    if (!btn || !btn->flags.auto_launch ||
        !btn->command || btn->flags.running || btn->flags.launching ||
        !strcmp(btn->wm_instance, "Workspace")) {
      continue;
    }

    state = wmalloc(sizeof(WSavedState));
    state->desktop = desktop;
    
    if (!strcmp(btn->wm_class, "GNUstep") && !strstr(btn->command, "autolaunch")) {
      cmd = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%s  -autolaunch YES"),
                                     btn->command);
      command = wstrdup(btn->command);
      wfree(btn->command);
      btn->command = wstrdup(CFStringGetCStringPtr(cmd, kCFStringEncodingASCII));
      CFRelease(cmd);
    }

    wDockLaunchWithState(btn, state);

    // Return 'command' field into initial state (without -autolaunch)
    if (!strcmp(btn->wm_class, "GNUstep") && command) {
      wfree(btn->command);
      btn->command = wstrdup(command);
      wfree(command);
      command = NULL;
    }
  }
}

#ifdef USE_DOCK_XDND
static WDock *findDock(WScreen *scr, XEvent *event, int *icon_pos)
{
  WDock *dock;
  int i;

  dock = scr->dock;
  if (dock != NULL) {
    for (i = 0; i < dock->max_icons; i++) {
      if (dock->icon_array[i] &&
          dock->icon_array[i]->icon->core->window == event->xclient.window) {
        *icon_pos = i;
        return dock;
      }
    }
  }

  dock = scr->desktops[scr->current_desktop]->clip;
  if (dock != NULL) {
    for (i = 0; i < dock->max_icons; i++) {
      if (dock->icon_array[i] &&
          dock->icon_array[i]->icon->core->window == event->xclient.window) {
        *icon_pos = i;
        return dock;
      }
    }
  }

  *icon_pos = -1;
  return NULL;
}

int wDockReceiveDNDDrop(WScreen *scr, XEvent *event)
{
  WDock *dock;
  WAppIcon *btn;
  int icon_pos;

  dock = findDock(scr, event, &icon_pos);
  if (!dock)
    return False;

  /*
   * Return True if the drop was on an application icon window.
   * In this case, let the ClientMessage handler redirect the
   * message to the app.
   */
  if (dock->icon_array[icon_pos]->icon->icon_win != None)
    return True;

  if (dock->icon_array[icon_pos]->dnd_command != NULL) {
    scr->flags.dnd_data_convertion_status = 0;

    btn = dock->icon_array[icon_pos];

    if (!btn->flags.forced_dock) {
      btn->flags.relaunching = btn->flags.running;
      btn->flags.running = 1;
    }
    if (btn->wm_instance || btn->wm_class) {
      WWindowAttributes attr;
      memset(&attr, 0, sizeof(WWindowAttributes));
      wDefaultFillAttributes(btn->wm_instance, btn->wm_class, &attr, NULL, True);

      if (!attr.no_appicon)
        btn->flags.launching = 1;
      else
        btn->flags.running = 0;
    }

    btn->flags.paste_launch = 0;
    btn->flags.drop_launch = 1;
    scr->last_dock = dock;
    btn->pid = execCommand(btn, btn->dnd_command, NULL);
    if (btn->pid > 0) {
      dockIconPaint(NULL, btn);
    } else {
      btn->flags.launching = 0;
      if (!btn->flags.relaunching)
        btn->flags.running = 0;
    }
  }
  return False;
}
#endif	/* USE_DOCK_XDND */

Bool wDockAttachIcon(WDock *dock, WAppIcon *icon, int x, int y, Bool update_icon)
{
  WWindow *wwin;
  char *command = NULL;
  int index;

  icon->flags.editing = 0;

  if (icon->command == NULL) {
    /* If icon->owner exists, it means the application is running */
    if (icon->icon->owner) {
      wwin = icon->icon->owner;
      command = wGetCommandForWindow(wwin->client_win);
    }

    if (command) {
      icon->command = command;
    } else {
      WSRunAlertPanel("Desktop Dock",
                      "Application icon without command set cannot be attached to Dock.",
                      _("OK"), NULL, NULL);
      return False;
    }
  }

  for (index = 1; index < dock->max_icons; index++)
    if (dock->icon_array[index] == NULL)
      break;
  /* if (index == dock->max_icons)
     return; */

  assert(index < dock->max_icons);

  dock->icon_array[index] = icon;
  icon->yindex = y;
  icon->xindex = x;

  icon->flags.omnipresent = 0;

  icon->x_pos = dock->x_pos + x * ICON_SIZE;
  icon->y_pos = dock->y_pos + y * ICON_SIZE;

  dock->icon_count++;

  icon->flags.running = 1;
  icon->flags.launching = 0;
  icon->flags.docked = 1;
  icon->dock = dock;
  icon->icon->core->descriptor.handle_mousedown = iconMouseDown;
  icon->icon->core->descriptor.handle_enternotify = clipEnterNotify;
  icon->icon->core->descriptor.handle_leavenotify = clipLeaveNotify;
  icon->icon->core->descriptor.parent_type = WCLASS_DOCK_ICON;
  icon->icon->core->descriptor.parent = icon;

  MoveInStackListUnder(dock->icon_array[index - 1]->icon->core, icon->icon->core);
  wAppIconMove(icon, icon->x_pos, icon->y_pos);

  /*
   * Update icon pixmap, RImage doesn't change,
   * so call wIconUpdate is not needed
   */
  if (update_icon) {
    update_icon_pixmap(icon->icon);
  }

  /* Paint it */
  wAppIconPaint(icon);

  /* Save it */
  save_appicon(icon, True);

  if (wPreferences.auto_arrange_icons)
    wArrangeIcons(dock->screen_ptr, True);

#ifdef USE_DOCK_XDND
  if (icon->command && !icon->dnd_command) {
    int len = strlen(icon->command) + 8;
    icon->dnd_command = wmalloc(len);
    snprintf(icon->dnd_command, len, "%s %%d", icon->command);
  }
#endif

  if (icon->command && !icon->paste_command) {
    int len = strlen(icon->command) + 8;
    icon->paste_command = wmalloc(len);
    snprintf(icon->paste_command, len, "%s %%s", icon->command);
  }

  CFNotificationCenterPostNotification(dock->screen_ptr->notificationCenter,
                                       WMDidChangeDockContentNotification,
                                       dock, NULL, true);

  return True;
}

void wDockReattachIcon(WDock *dock, WAppIcon *icon, int x, int y)
{
  int index;

  for (index = 1; index < dock->max_icons; index++) {
    if (dock->icon_array[index] == icon)
      break;
  }
  assert(index < dock->max_icons);

  icon->yindex = y;
  icon->xindex = x;

  icon->x_pos = dock->x_pos + x * ICON_SIZE;
  icon->y_pos = dock->y_pos + y * ICON_SIZE;
  
  CFNotificationCenterPostNotification(dock->screen_ptr->notificationCenter,
                                       WMDidChangeDockContentNotification,
                                       dock, NULL, TRUE);
}

Bool wDockMoveIconBetweenDocks(WDock *src, WDock *dest, WAppIcon *icon, int x, int y)
{
  WWindow *wwin;
  char *command = NULL;
  int index;
  Bool update_icon = False;

  if (src == dest)
    return True;	/* No move needed, we're already there */

  if (dest == NULL)
    return False;

  /*
   * For the moment we can't do this if we move icons in Clip from one
   * desktop to other, because if we move two or more icons without
   * command, the dialog box will not be able to tell us to which of the
   * moved icons it applies. -Dan
   */
  if ((dest->type == WM_DOCK /*|| dest->keep_attracted */ ) && icon->command == NULL) {
    /* If icon->owner exists, it means the application is running */
    if (icon->icon->owner) {
      wwin = icon->icon->owner;
      command = wGetCommandForWindow(wwin->client_win);
    }

    if (command) {
      icon->command = command;
    } else {
      WSRunAlertPanel("Desktop Dock",
                      "Application icon without command set cannot be attached to Dock.",
                      _("OK"), NULL, NULL);
      return False;
    }
  }

  if (dest->type == WM_DOCK || dest->type == WM_DRAWER)
    wClipMakeIconOmnipresent(icon, False);

  for (index = 1; index < src->max_icons; index++) {
    if (src->icon_array[index] == icon)
      break;
  }
  assert(index < src->max_icons);

  src->icon_array[index] = NULL;
  src->icon_count--;

  for (index = 1; index < dest->max_icons; index++) {
    if (dest->icon_array[index] == NULL)
      break;
  }

  assert(index < dest->max_icons);

  dest->icon_array[index] = icon;
  icon->dock = dest;

  /* deselect the icon */
  if (icon->icon->selected)
    wIconSelect(icon->icon);

  icon->icon->core->descriptor.handle_enternotify = clipEnterNotify;
  icon->icon->core->descriptor.handle_leavenotify = clipLeaveNotify;

  /* set it to be kept when moving to dock.
   * Unless the icon does not have a command set
   */
  if (icon->command && (dest->type == WM_DOCK || dest->type == WM_DRAWER)) {
    icon->flags.attracted = 0;
    if (icon->icon->shadowed) {
      icon->icon->shadowed = 0;
      update_icon = True;
    }
    save_appicon(icon, True);
  }

  if (src->auto_collapse || src->auto_raise_lower)
    clipLeave(src);

  icon->yindex = y;
  icon->xindex = x;

  icon->x_pos = dest->x_pos + x * ICON_SIZE;
  icon->y_pos = dest->y_pos + y * ICON_SIZE;

  dest->icon_count++;

  MoveInStackListUnder(dest->icon_array[index - 1]->icon->core, icon->icon->core);

  /*
   * Update icon pixmap, RImage doesn't change,
   * so call wIconUpdate is not needed
   */
  if (update_icon)
    update_icon_pixmap(icon->icon);

  /* Paint it */
  wAppIconPaint(icon);

  return True;
}

void wDockDetach(WDock *dock, WAppIcon *icon)
{
  int index;
  Bool update_icon = False;

  /* This must be called before icon->dock is set to NULL.
   * Don't move it. -Dan
   */
  wClipMakeIconOmnipresent(icon, False);

  icon->flags.docked = 0;
  icon->dock = NULL;
  icon->flags.attracted = 0;
  icon->flags.auto_launch = 0;
  if (icon->icon->shadowed) {
    icon->icon->shadowed = 0;
    update_icon = True;
  }

  /* deselect the icon */
  if (icon->icon->selected)
    wIconSelect(icon->icon);

  if (icon->command) {
    wfree(icon->command);
    icon->command = NULL;
  }
#ifdef USE_DOCK_XDND
  if (icon->dnd_command) {
    wfree(icon->dnd_command);
    icon->dnd_command = NULL;
  }
#endif
  if (icon->paste_command) {
    wfree(icon->paste_command);
    icon->paste_command = NULL;
  }

  for (index = 1; index < dock->max_icons; index++)
    if (dock->icon_array[index] == icon)
      break;

  assert(index < dock->max_icons);
  dock->icon_array[index] = NULL;
  icon->yindex = -1;
  icon->xindex = -1;

  dock->icon_count--;

  /* if the dock is not attached to an application or
   * the application did not set the appropriate hints yet,
   * destroy the icon */
  if (!icon->flags.running || !wApplicationOf(icon->main_window)) {
    wAppIconDestroy(icon);
  } else {
    icon->icon->core->descriptor.handle_mousedown = appIconMouseDown;
    icon->icon->core->descriptor.handle_enternotify = NULL;
    icon->icon->core->descriptor.handle_leavenotify = NULL;
    icon->icon->core->descriptor.parent_type = WCLASS_APPICON;
    icon->icon->core->descriptor.parent = icon;

    ChangeStackingLevel(icon->icon->core, NORMAL_ICON_LEVEL);

    /*
     * Update icon pixmap, RImage doesn't change,
     * so call wIconUpdate is not needed
     */
    if (update_icon)
      update_icon_pixmap(icon->icon);

    /* Paint it */
    wAppIconPaint(icon);

    if (wPreferences.auto_arrange_icons)
      wArrangeIcons(dock->screen_ptr, True);
  }
  if (dock->auto_collapse || dock->auto_raise_lower)
    clipLeave(dock);
  
  CFNotificationCenterPostNotification(dock->screen_ptr->notificationCenter,
                                       WMDidChangeDockContentNotification,
                                       dock, NULL, TRUE);
}

WAppIcon *wDockAppiconAtSlot(WDock *dock, int position)
{
  if (!dock || position > dock->max_icons-1) {
    return NULL;
  }

  for (int i=0; i < dock->max_icons; i++) {
    if (!dock->icon_array[i]) {
      continue;
    }
    if (dock->icon_array[i]->yindex == position) {
      return dock->icon_array[i];
    }
  }
  
  return NULL;
}

/*
 * returns the closest Dock slot index for the passed
 * coordinates.
 *
 * Returns False if icon can't be docked.
 *
 * Note: this function should NEVER alter ret_x or ret_y, unless it will
 * return True. -Dan
 */
/* Redocking == true means either icon->dock == dock (normal case)
 * or we are called from handleDockMove for a drawer */
Bool wDockSnapIcon(WDock *dock, WAppIcon *icon, int req_x, int req_y, int *ret_x, int *ret_y, int redocking)
{
  WScreen *scr = dock->screen_ptr;
  int dx, dy;
  int ex_x, ex_y;
  int i, offset = ICON_SIZE / 2;
  WAppIcon *aicon = NULL;
  WAppIcon *nicon = NULL;

  if (wPreferences.flags.noupdates)
    return False;

  dx = dock->x_pos;
  dy = dock->y_pos;

  /* if the dock is full */
  if (!redocking && (dock->icon_count >= dock->max_icons))
    return False;

  /* exact position */
  if (req_y < dy)
    ex_y = (req_y - offset - dy) / ICON_SIZE;
  else
    ex_y = (req_y + offset - dy) / ICON_SIZE;

  if (req_x < dx)
    ex_x = (req_x - offset - dx) / ICON_SIZE;
  else
    ex_x = (req_x + offset - dx) / ICON_SIZE;

  /* check if the icon is outside the screen boundaries */
  if (!onScreen(scr, dx + ex_x * ICON_SIZE, dy + ex_y * ICON_SIZE))
    return False;

  switch (dock->type) {
  case WM_DOCK:
    /* We can return False right away if
     * - we do not come from this dock (which is a WM_DOCK),
     * - we are not right over it, and
     * - we are not the main tile of a drawer.
     * In the latter case, we are called from handleDockMove. */
    if (icon->dock != dock && ex_x != 0 &&
        !(icon->dock && icon->dock->type == WM_DRAWER && icon == icon->dock->icon_array[0]))
      return False;

    if (!redocking && ex_x != 0)
      return False;

    if (getDrawer(scr, ex_y)) /* Return false so that the drawer gets it. */
      return False;

    aicon = NULL;
    for (i = 0; i < dock->max_icons; i++) {
      nicon = dock->icon_array[i];
      if (nicon && nicon->yindex == ex_y) {
        aicon = nicon;
        break;
      }
    }

    if (redocking) {
      int sig, done, closest;

      /* Possible cases when redocking:
       *
       * icon dragged out of range of any slot -> false
       * icon dragged on a drawer -> false (to open the drawer)
       * icon dragged to range of free slot
       * icon dragged to range of same slot
       * icon dragged to range of different icon
       */
      if (abs(ex_x) > DOCK_DETTACH_THRESHOLD)
        return False;

      if (aicon == icon || !aicon) {
        *ret_x = 0;
        *ret_y = ex_y;
        return True;
      }

      /* start looking at the upper slot or lower? */
      if (ex_y * ICON_SIZE < (req_y + offset - dy))
        sig = 1;
      else
        sig = -1;

      done = 0;
      /* look for closest free slot */
      for (i = 0; i < (DOCK_DETTACH_THRESHOLD + 1) * 2 && !done; i++) {
        int j;

        done = 1;
        closest = sig * (i / 2) + ex_y;
        /* check if this slot is fully on the screen and not used */
        if (onScreen(scr, dx, dy + closest * ICON_SIZE)) {
          for (j = 0; j < dock->max_icons; j++) {
            if (dock->icon_array[j]
                && dock->icon_array[j]->yindex == closest) {
              /* slot is used by someone else */
              if (dock->icon_array[j] != icon)
                done = 0;
              break;
            }
          }
          /* slot is used by a drawer */
          done = done && !getDrawer(scr, closest);
        }
        else // !onScreen
          done = 0;
        sig = -sig;
      }
      if (done &&
          ((ex_y >= closest && ex_y - closest < DOCK_DETTACH_THRESHOLD + 1)
           || (ex_y < closest && closest - ex_y <= DOCK_DETTACH_THRESHOLD + 1))) {
        *ret_x = 0;
        *ret_y = closest;
        return True;
      }
    } else {	/* !redocking */

      /* if slot is free and the icon is close enough, return it */
      if (!aicon && ex_x == 0) {
        *ret_x = 0;
        *ret_y = ex_y;
        return True;
      }
    }
    break;
  case WM_CLIP:
    {
      int neighbours = 0;
      int start, stop, k;

      start = icon->flags.omnipresent ? 0 : scr->current_desktop;
      stop = icon->flags.omnipresent ? scr->desktop_count : start + 1;

      aicon = NULL;
      for (k = start; k < stop; k++) {
        WDock *tmp = scr->desktops[k]->clip;
        if (!tmp)
          continue;
        for (i = 0; i < tmp->max_icons; i++) {
          nicon = tmp->icon_array[i];
          if (nicon && nicon->xindex == ex_x && nicon->yindex == ex_y) {
            aicon = nicon;
            break;
          }
        }
        if (aicon)
          break;
      }
      for (k = start; k < stop; k++) {
        WDock *tmp = scr->desktops[k]->clip;
        if (!tmp)
          continue;
        for (i = 0; i < tmp->max_icons; i++) {
          nicon = tmp->icon_array[i];
          if (nicon && nicon != icon &&	/* Icon can't be it's own neighbour */
              (abs(nicon->xindex - ex_x) <= CLIP_ATTACH_VICINITY &&
               abs(nicon->yindex - ex_y) <= CLIP_ATTACH_VICINITY)) {
            neighbours = 1;
            break;
          }
        }
        if (neighbours)
          break;
      }

      if (neighbours && (aicon == NULL || (redocking && aicon == icon))) {
        *ret_x = ex_x;
        *ret_y = ex_y;
        return True;
      }
      break;
    }
  case WM_DRAWER:
    {
      WAppIcon *aicons_to_shift[ dock->icon_count ];
      int index_of_hole, j;

      if (ex_y != 0 ||
          abs(ex_x) - dock->icon_count > DOCK_DETTACH_THRESHOLD ||
          (ex_x < 0 && !dock->on_right_side) ||
          (ex_x > 0 &&  dock->on_right_side)) {
        return False;
      }

      if (ex_x == 0)
        ex_x = (dock->on_right_side ? -1 : 1);

      /* "Reduce" ex_x but keep its sign */
      if (redocking) {
        if (abs(ex_x) > dock->icon_count - 1) /* minus 1: do not take icon_array[0] into account */
          ex_x = ex_x * (dock->icon_count - 1) / abs(ex_x); /* don't use *= ! */
      } else {
        if (abs(ex_x) > dock->icon_count)
          ex_x = ex_x * dock->icon_count / abs(ex_x);
      }
      index_of_hole = indexOfHole(dock, icon, redocking);

      /* Find the appicons between where icon was (index_of_hole) and where
       * it wants to be (ex_x) and slide them. */
      j = 0;
      for (i = 1; i < dock->max_icons; i++) {
        aicon = dock->icon_array[i];
        if ((aicon != NULL) && (aicon != icon) &&
            ((ex_x <= aicon->xindex && aicon->xindex < index_of_hole) ||
             (index_of_hole < aicon->xindex && aicon->xindex <= ex_x)))
          aicons_to_shift[ j++ ] = aicon;
      }
      assert(j == abs(ex_x - index_of_hole));

      wSlideAppicons(aicons_to_shift, j, (index_of_hole < ex_x));

      *ret_x = ex_x;
      *ret_y = ex_y;
      return True;
    }
  }
  return False;
}

static int onScreen(WScreen *scr, int x, int y)
{
  WMRect rect;
  int flags;

  rect.pos.x = x;
  rect.pos.y = y;
  rect.size.width = rect.size.height = ICON_SIZE;

  wGetRectPlacementInfo(scr, rect, &flags);

  return !(flags & (XFLAG_DEAD | XFLAG_PARTIAL));
}

/*
 * returns true if it can find a free slot in the dock,
 * in which case it changes x_pos and y_pos accordingly.
 * Else returns false.
 */
Bool wDockFindFreeSlot(WDock *dock, int *x_pos, int *y_pos)
{
  WScreen *scr = dock->screen_ptr;
  WAppIcon *btn;
  WAppIconChain *chain;
  unsigned char *slot_map;
  int mwidth;
  int r;
  int x, y;
  int i, done = False;
  int corner;
  int ex = scr->width, ey = scr->height;
  int extra_count = 0;

  if (dock->type == WM_DRAWER) {
    if (dock->icon_count >= dock->max_icons) { /* drawer is full */
      return False;
    }
    *x_pos = dock->icon_count * (dock->on_right_side ? -1 : 1);
    *y_pos = 0;
    return True;
  }

  if (dock->type == WM_CLIP && dock != scr->desktops[scr->current_desktop]->clip)
    extra_count = scr->global_icon_count;

  /* if the dock is full */
  if (dock->icon_count + extra_count >= dock->max_icons)
    return False;

  if (!wPreferences.flags.nodock && scr->dock && scr->dock->on_right_side) {
    ex -= ICON_SIZE + DOCK_EXTRA_SPACE;
  }

  if (ex < dock->x_pos)
    ex = dock->x_pos;
#define C_NONE 0
#define C_NW 1
#define C_NE 2
#define C_SW 3
#define C_SE 4

  /* check if clip is in a corner */
  if (dock->type == WM_CLIP) {
    if (dock->x_pos < 1 && dock->y_pos < 1)
      corner = C_NE;
    else if (dock->x_pos < 1 && dock->y_pos >= (ey - ICON_SIZE))
      corner = C_SE;
    else if (dock->x_pos >= (ex - ICON_SIZE) && dock->y_pos >= (ey - ICON_SIZE))
      corner = C_SW;
    else if (dock->x_pos >= (ex - ICON_SIZE) && dock->y_pos < 1)
      corner = C_NW;
    else
      corner = C_NONE;
  } else {
    corner = C_NONE;
  }

  /* If the clip is in the corner, use only slots that are in the border
   * of the screen */
  if (corner != C_NONE) {
    char *hmap, *vmap;
    int hcount, vcount;

    hcount = WMIN(dock->max_icons, scr->width / ICON_SIZE);
    vcount = WMIN(dock->max_icons, scr->height / ICON_SIZE);
    hmap = wmalloc(hcount + 1);
    vmap = wmalloc(vcount + 1);

    /* mark used positions */
    switch (corner) {
    case C_NE:
      for (i = 0; i < dock->max_icons; i++) {
        btn = dock->icon_array[i];
        if (!btn)
          continue;

        if (btn->xindex == 0 && btn->yindex > 0 && btn->yindex < vcount)
          vmap[btn->yindex] = 1;
        else if (btn->yindex == 0 && btn->xindex > 0 && btn->xindex < hcount)
          hmap[btn->xindex] = 1;
      }
      for (chain = scr->global_icons; chain != NULL; chain = chain->next) {
        btn = chain->aicon;
        if (btn->xindex == 0 && btn->yindex > 0 && btn->yindex < vcount)
          vmap[btn->yindex] = 1;
        else if (btn->yindex == 0 && btn->xindex > 0 && btn->xindex < hcount)
          hmap[btn->xindex] = 1;
      }
      break;
    case C_NW:
      for (i = 0; i < dock->max_icons; i++) {
        btn = dock->icon_array[i];
        if (!btn)
          continue;

        if (btn->xindex == 0 && btn->yindex > 0 && btn->yindex < vcount)
          vmap[btn->yindex] = 1;
        else if (btn->yindex == 0 && btn->xindex < 0 && btn->xindex > -hcount)
          hmap[-btn->xindex] = 1;
      }
      for (chain = scr->global_icons; chain != NULL; chain = chain->next) {
        btn = chain->aicon;
        if (btn->xindex == 0 && btn->yindex > 0 && btn->yindex < vcount)
          vmap[btn->yindex] = 1;
        else if (btn->yindex == 0 && btn->xindex < 0 && btn->xindex > -hcount)
          hmap[-btn->xindex] = 1;
      }
      break;
    case C_SE:
      for (i = 0; i < dock->max_icons; i++) {
        btn = dock->icon_array[i];
        if (!btn)
          continue;

        if (btn->xindex == 0 && btn->yindex < 0 && btn->yindex > -vcount)
          vmap[-btn->yindex] = 1;
        else if (btn->yindex == 0 && btn->xindex > 0 && btn->xindex < hcount)
          hmap[btn->xindex] = 1;
      }
      for (chain = scr->global_icons; chain != NULL; chain = chain->next) {
        btn = chain->aicon;
        if (btn->xindex == 0 && btn->yindex < 0 && btn->yindex > -vcount)
          vmap[-btn->yindex] = 1;
        else if (btn->yindex == 0 && btn->xindex > 0 && btn->xindex < hcount)
          hmap[btn->xindex] = 1;
      }
      break;
    case C_SW:
    default:
      for (i = 0; i < dock->max_icons; i++) {
        btn = dock->icon_array[i];
        if (!btn)
          continue;

        if (btn->xindex == 0 && btn->yindex < 0 && btn->yindex > -vcount)
          vmap[-btn->yindex] = 1;
        else if (btn->yindex == 0 && btn->xindex < 0 && btn->xindex > -hcount)
          hmap[-btn->xindex] = 1;
      }
      for (chain = scr->global_icons; chain != NULL; chain = chain->next) {
        btn = chain->aicon;
        if (btn->xindex == 0 && btn->yindex < 0 && btn->yindex > -vcount)
          vmap[-btn->yindex] = 1;
        else if (btn->yindex == 0 && btn->xindex < 0 && btn->xindex > -hcount)
          hmap[-btn->xindex] = 1;
      }
    }
    x = 0;
    y = 0;
    done = 0;
    /* search a vacant slot */
    for (i = 1; i < WMAX(vcount, hcount); i++) {
      if (i < vcount && vmap[i] == 0) {
        /* found a slot */
        x = 0;
        y = i;
        done = 1;
        break;
      } else if (i < hcount && hmap[i] == 0) {
        /* found a slot */
        x = i;
        y = 0;
        done = 1;
        break;
      }
    }
    wfree(vmap);
    wfree(hmap);
    /* If found a slot, translate and return */
    if (done) {
      if (corner == C_NW || corner == C_NE)
        *y_pos = y;
      else
        *y_pos = -y;

      if (corner == C_NE || corner == C_SE)
        *x_pos = x;
      else
        *x_pos = -x;

      return True;
    }
    /* else, try to find a slot somewhere else */
  }

  /* a map of mwidth x mwidth would be enough if we allowed icons to be
   * placed outside of screen */
  mwidth = (int)ceil(sqrt(dock->max_icons));

  /* In the worst case (the clip is in the corner of the screen),
   * the amount of icons that fit in the clip is smaller.
   * Double the map to get a safe value.
   */
  mwidth += mwidth;

  r = (mwidth - 1) / 2;

  slot_map = wmalloc(mwidth * mwidth);

#define XY2OFS(x,y) (WMAX(abs(x),abs(y)) > r) ? 0 : (((y)+r)*(mwidth)+(x)+r)

  /* mark used slots in the map. If the slot falls outside the map
   * (for example, when all icons are placed in line), ignore them. */
  for (i = 0; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];
    if (btn)
      slot_map[XY2OFS(btn->xindex, btn->yindex)] = 1;
  }

  for (chain = scr->global_icons; chain != NULL; chain = chain->next)
    slot_map[XY2OFS(chain->aicon->xindex, chain->aicon->yindex)] = 1;

  /* Find closest slot from the center that is free by scanning the
   * map from the center to outward in circular passes.
   * This will not result in a neat layout, but will be optimal
   * in the sense that there will not be holes left.
   */
  done = 0;
  for (i = 1; i <= r && !done; i++) {
    int tx, ty;

    /* top and bottom parts of the ring */
    for (x = -i; x <= i && !done; x++) {
      tx = dock->x_pos + x * ICON_SIZE;
      y = -i;
      ty = dock->y_pos + y * ICON_SIZE;
      if (slot_map[XY2OFS(x, y)] == 0 && onScreen(scr, tx, ty)) {
        *x_pos = x;
        *y_pos = y;
        done = 1;
        break;
      }
      y = i;
      ty = dock->y_pos + y * ICON_SIZE;
      if (slot_map[XY2OFS(x, y)] == 0 && onScreen(scr, tx, ty)) {
        *x_pos = x;
        *y_pos = y;
        done = 1;
        break;
      }
    }
    /* left and right parts of the ring */
    for (y = -i + 1; y <= i - 1; y++) {
      ty = dock->y_pos + y * ICON_SIZE;
      x = -i;
      tx = dock->x_pos + x * ICON_SIZE;
      if (slot_map[XY2OFS(x, y)] == 0 && onScreen(scr, tx, ty)) {
        *x_pos = x;
        *y_pos = y;
        done = 1;
        break;
      }
      x = i;
      tx = dock->x_pos + x * ICON_SIZE;
      if (slot_map[XY2OFS(x, y)] == 0 && onScreen(scr, tx, ty)) {
        *x_pos = x;
        *y_pos = y;
        done = 1;
        break;
      }
    }
  }
  wfree(slot_map);
#undef XY2OFS
  return done;
}

static void moveDock(WDock *dock, int new_x, int new_y)
{
  WAppIcon *btn;
  WDrawerChain *dc;
  int i;

  if (dock->type == WM_DOCK) {
    for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next)
      moveDock(dc->adrawer, new_x, dc->adrawer->y_pos - dock->y_pos + new_y);
  }

  dock->x_pos = new_x;
  dock->y_pos = new_y;
  for (i = 0; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];
    if (btn) {
      btn->x_pos = new_x + btn->xindex * ICON_SIZE;
      btn->y_pos = new_y + btn->yindex * ICON_SIZE;
      XMoveWindow(dpy, btn->icon->core->window, btn->x_pos, btn->y_pos);
    }
  }
}

static void swapDock(WDock *dock)
{
  WScreen *scr = dock->screen_ptr;
  WAppIcon *btn;
  int x, i;

  if (dock->on_right_side)
    x = dock->x_pos = scr->width - ICON_SIZE - DOCK_EXTRA_SPACE;
  else
    x = dock->x_pos = DOCK_EXTRA_SPACE;

  swapDrawers(scr, x);

  for (i = 0; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];
    if (btn) {
      btn->x_pos = x;
      XMoveWindow(dpy, btn->icon->core->window, btn->x_pos, btn->y_pos);
    }
  }

  wScreenUpdateUsableArea(scr);
}

static pid_t execCommand(WAppIcon *btn, const char *command, WSavedState *state)
{
  WScreen *scr = btn->icon->core->screen_ptr;
  pid_t pid;
  char **argv;
  int argc;
  char *cmdline;

  cmdline = ExpandOptions(scr, command);

  if (scr->flags.dnd_data_convertion_status || !cmdline) {
    if (cmdline)
      wfree(cmdline);
    if (state)
      wfree(state);
    return 0;
  }

  wtokensplit(cmdline, &argv, &argc);

  if (!argc) {
    if (cmdline)
      wfree(cmdline);
    if (state)
      wfree(state);
    return 0;
  }

  pid = fork();
  if (pid == 0) {
    char **args;
    int i;

    wSetupCommandEnvironment(scr);

#ifdef HAVE_SETSID
    setsid();
#endif

    args = malloc(sizeof(char *) * (argc + 1));
    if (!args)
      exit(111);

    for (i = 0; i < argc; i++)
      args[i] = argv[i];

    sigset_t sigs;
    sigfillset(&sigs);
    sigprocmask(SIG_UNBLOCK, &sigs, NULL);

    args[argc] = NULL;
    execvp(argv[0], args);
    exit(111);
  }
  wtokenfree(argv, argc);

  if (pid > 0) {
    if (!state) {
      state = wmalloc(sizeof(WSavedState));
      state->hidden = -1;
      state->miniaturized = -1;
      state->shaded = -1;
      if (btn->dock == scr->dock || btn->dock->type == WM_DRAWER || btn->flags.omnipresent)
        state->desktop = -1;
      else
        state->desktop = scr->current_desktop;
    }
    wWindowAddSavedState(btn->wm_instance, btn->wm_class, cmdline, pid, state);
    wAddDeathHandler(pid, (WDeathHandler *) trackDeadProcess, btn->dock);
  } else if (state) {
    wfree(state);
  }
  wfree(cmdline);
  return pid;
}

// NEXTSPACE
void wDockHideIcons(WDock *dock)
{
  if (dock == NULL || !dock->mapped) {
    return;
  }
  for (int i = 0; i < (dock->collapsed ? 1 : dock->max_icons); i++) {
    if (dock->icon_array[i])
      XUnmapWindow(dpy, dock->icon_array[i]->icon->core->window);
  }
  XSync(dpy, False);
  dock->mapped = 0;
}

// NEXTSPACE
void wDockShowIcons(WDock *dock)
{
  if (dock == NULL || dock->mapped) {
    return;
  }
  for (int i = 0; i < (dock->collapsed ? 1 : dock->max_icons); i++) {
    if (dock->icon_array[i]) {
      XMapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  }
  
  XSync(dpy, False);
  dock->mapped = 1;
}

// NEXTSPACE
void wDockUncollapse(WDock *dock)
{
  if (dock == NULL || !dock->collapsed || !dock->mapped) {
    return;
  }
  for (int i = 1; i < dock->max_icons; i++) {
    if (dock->icon_array[i]) {
      XMapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  }
  XSync(dpy, False);
  dock->collapsed = 0;
}

// NEXTSPACE
void wDockCollapse(WDock *dock)
{
  if (dock == NULL || dock->collapsed || !dock->mapped) {
    return;
  }
  for (int i = 1; i < dock->max_icons; i++) {
    if (dock->icon_array[i]) {
      XUnmapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  }
  XSync(dpy, False);
  dock->collapsed = 1;
}


void wDockLower(WDock *dock)
{
  int i;
  WDrawerChain *dc;

  if (dock->type == WM_DOCK) {
    for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next)
      wDockLower(dc->adrawer);
  }
  for (i = 0; i < dock->max_icons; i++) {
    if (dock->icon_array[i])
      wLowerFrame(dock->icon_array[i]->icon->core);
  }
}

void wDockRaise(WDock *dock)
{
  int i;
  WDrawerChain *dc;

  for (i = dock->max_icons - 1; i >= 0; i--) {
    if (dock->icon_array[i]) {
      wRaiseFrame(dock->icon_array[i]->icon->core);
    }
  }
  if (dock->type == WM_DOCK) {
    for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next)
      wDockRaise(dc->adrawer);
  }
}

void wDockRaiseLower(WDock *dock)
{
  if (!dock->icon_array[0]->icon->core->stacking->above
      || (dock->icon_array[0]->icon->core->stacking->window_level
          != dock->icon_array[0]->icon->core->stacking->above->stacking->window_level))
    wDockLower(dock);
  else
    wDockRaise(dock);
}

// NEXTSPACE
enum {
  KeepOnTop = NSDockWindowLevel,
  Normal = NSNormalWindowLevel,
  AutoRaiseLower = NSDesktopWindowLevel
};

// NEXTSPACE
int wDockLevel(WDock *dock)
{
  int current_level = -1;
  
  if (dock->lowered == 1 && dock->auto_raise_lower == 1) {
    current_level = AutoRaiseLower;
  }
  else if (dock->lowered == 1 && dock->auto_raise_lower == 0) {
    current_level = Normal;
  }
  else if (dock->lowered == 0) {
    current_level = KeepOnTop;
  }
  
  return current_level;
}

// NEXTSPACE
void wDockSetLevel(WDock *dock, int level)
{
  WAppIcon *aicon;
  
  if (wDockLevel(dock) == level) {
    return;
  }

  switch (level) {
  case KeepOnTop:
    dock->lowered = 0;
    dock->auto_raise_lower = 0;
    level = NSDockWindowLevel;
    break;
  case Normal:
    dock->lowered = 1;
    dock->auto_raise_lower = 0;
    level = NSNormalWindowLevel;
    break;
  case AutoRaiseLower:
    dock->lowered = 1;
    dock->auto_raise_lower = 1;
    level = NSNormalWindowLevel;
    break;
  }

  // Dock icons
  for (int i = 0; i < dock->max_icons; i++) {
    aicon = dock->icon_array[i];
    if (aicon) {
      ChangeStackingLevel(aicon->icon->core, level);
      if (dock->lowered) {
        wLowerFrame(aicon->icon->core);
      }
      else {
        wRaiseFrame(aicon->icon->core);
      }
    }
  }

  // Drawers
  if (dock->type == WM_DOCK) {
    for (WDrawerChain *dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next) {
      wDockSetLevel(dc->adrawer, level);
    }
    wScreenUpdateUsableArea(dock->screen_ptr);
  }

  wScreenSaveState(dock->screen_ptr);
}


void wDockFinishLaunch(WAppIcon *icon)
{
  icon->flags.launching = 0;
  icon->flags.relaunching = 0;
  dockIconPaint(NULL, icon);
}

WAppIcon *wDockFindIconForWindow(WDock *dock, Window window)
{
  WAppIcon *icon;
  int i;

  for (i = 0; i < dock->max_icons; i++) {
    icon = dock->icon_array[i];
    if (icon && icon->main_window == window)
      return icon;
  }
  return NULL;
}

void wDockTrackWindowLaunch(WDock *dock, Window window)
{
  WAppIcon *icon;
  char *wm_class, *wm_instance;
  int i;
  Bool firstPass = True;
  Bool found = False;
  char *command = NULL;

  if (!PropGetWMClass(window, &wm_class, &wm_instance)) {
    free(wm_class);
    free(wm_instance);
    return;
  }

  command = wGetCommandForWindow(window);
 retry:
  for (i = 0; i < dock->max_icons; i++) {
    icon = dock->icon_array[i];
    if (!icon)
      continue;

    /* app is already attached to icon */
    if (icon->main_window == window) {
      found = True;
      break;
    }

    if ((icon->wm_instance || icon->wm_class)
        && (icon->flags.launching || !icon->flags.running)) {

      if (icon->wm_instance && wm_instance && strcmp(icon->wm_instance, wm_instance) != 0)
        continue;

      if (icon->wm_class && wm_class && strcmp(icon->wm_class, wm_class) != 0)
        continue;

      if (firstPass && command && icon->command && strcmp(icon->command, command) != 0)
        continue;

      if (!icon->flags.relaunching) {
        WApplication *wapp;

        /* Possibly an application that was docked with dockit,
         * but the user did not update WMState to indicate that
         * it was docked by force */
        wapp = wApplicationOf(window);
        if (!wapp) {
          icon->flags.forced_dock = 1;
          icon->flags.running = 0;
        }
        if (!icon->flags.forced_dock)
          icon->main_window = window;
      }
      found = True;
      if (!wPreferences.no_animations && !icon->flags.launching &&
          !dock->screen_ptr->flags.startup && !dock->collapsed) {
        WAppIcon *aicon;
        int x0, y0;

        icon->flags.launching = 1;
        dockIconPaint(NULL, icon);

        aicon = wAppIconCreateForDock(dock->screen_ptr, NULL,
                                      wm_instance, wm_class, TILE_NORMAL);
        /* XXX: can: aicon->icon == NULL ? */
        PlaceIcon(dock->screen_ptr, &x0, &y0, wGetHeadForWindow(aicon->icon->owner));
        wAppIconMove(aicon, x0, y0);
        /* Should this always be lowered? -Dan */
        if (dock->lowered)
          wLowerFrame(aicon->icon->core);
        XMapWindow(dpy, aicon->icon->core->window);
        aicon->flags.launching = 1;
        wAppIconPaint(aicon);
        wSlideWindow(aicon->icon->core->window, x0, y0, icon->x_pos, icon->y_pos);
        XUnmapWindow(dpy, aicon->icon->core->window);
        wAppIconDestroy(aicon);
      }
      wDockFinishLaunch(icon);
      break;
    }
  }

  if (firstPass && !found) {
    firstPass = False;
    goto retry;
  }

  if (command)
    wfree(command);

  if (wm_class)
    free(wm_class);
  if (wm_instance)
    free(wm_instance);
}

void wClipUpdateForDesktopChange(WScreen *scr, int desktop)
{
  if (!wPreferences.flags.noclip) {
    scr->clip_icon->dock = scr->desktops[desktop]->clip;
    if (scr->current_desktop != desktop) {
      WDock *old_clip = scr->desktops[scr->current_desktop]->clip;
      WAppIconChain *chain = scr->global_icons;

      while (chain) {
        wDockMoveIconBetweenDocks(chain->aicon->dock,
                                  scr->desktops[desktop]->clip,
                                  chain->aicon, chain->aicon->xindex, chain->aicon->yindex);
        if (scr->desktops[desktop]->clip->collapsed)
          XUnmapWindow(dpy, chain->aicon->icon->core->window);
        chain = chain->next;
      }

      wDockHideIcons(old_clip);
      if (old_clip->auto_raise_lower) {
        if (old_clip->auto_raise_magic) {
          WMDeleteTimerHandler(old_clip->auto_raise_magic);
          old_clip->auto_raise_magic = NULL;
        }
        wDockLower(old_clip);
      }
      if (old_clip->auto_collapse) {
        if (old_clip->auto_expand_magic) {
          WMDeleteTimerHandler(old_clip->auto_expand_magic);
          old_clip->auto_expand_magic = NULL;
        }
        old_clip->collapsed = 1;
      }
      wDockShowIcons(scr->desktops[desktop]->clip);
    }
  }
}

static void trackDeadProcess(pid_t pid, unsigned char status, WDock *dock)
{
  WAppIcon *icon;
  int i;

  for (i = 0; i < dock->max_icons; i++) {
    icon = dock->icon_array[i];
    if (!icon)
      continue;

    if (icon->flags.launching && icon->pid == pid) {
      if (!icon->flags.relaunching) {
        icon->flags.running = 0;
        icon->main_window = None;
      }
      wDockFinishLaunch(icon);
      icon->pid = 0;
      if (status == 111) {
        char msg[PATH_MAX];
        char *cmd;

#ifdef USE_DOCK_XDND
        if (icon->flags.drop_launch)
          cmd = icon->dnd_command;
        else
#endif
          if (icon->flags.paste_launch)
            cmd = icon->paste_command;
          else
            cmd = icon->command;

        snprintf(msg, sizeof(msg), _("Could not execute command \"%s\""), cmd);

#ifdef NEXTSPACE
        char *message = wstrdup(msg);
        dispatch_async(workspace_q, ^{
            WSRunAlertPanel(_("Desktop Dock"), message, _("Got It"), NULL, NULL);
            wfree(message);
          });
#else
        WMLogInfoDialog(dock->screen_ptr, _("Error"), msg, _("OK"), NULL, NULL);
#endif
      }
      break;
    }
  }
}

/* This function is called when the dock switches state between
 * "normal" (including auto-raise/lower) and "keep on top". It is
 * therefore clearly distinct from wDockLower/Raise, which are called
 * each time a not-kept-on-top dock is lowered/raised. */
static void toggleLowered(WDock *dock)
{
  WAppIcon *tmp;
  WDrawerChain *dc;
  int newlevel, i;

  if (!dock->lowered) {
    newlevel = NSNormalWindowLevel;
    dock->lowered = 1;
  } else {
    newlevel = NSDockWindowLevel;
    dock->lowered = 0;
  }

  for (i = 0; i < dock->max_icons; i++) {
    tmp = dock->icon_array[i];
    if (!tmp)
      continue;

    ChangeStackingLevel(tmp->icon->core, newlevel);

    /* When the dock is no longer "on top", explicitly lower it as well.
     * It saves some CPU cycles (probably) to do it ourselves here
     * rather than calling wDockLower at the end of toggleLowered */
    if (dock->lowered)
      wLowerFrame(tmp->icon->core);
  }

  if (dock->type == WM_DOCK) {
    for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next) {
      toggleLowered(dc->adrawer);
    }
    wScreenUpdateUsableArea(dock->screen_ptr);
  }
}

static void toggleCollapsed(WDock *dock)
{
  if (dock->collapsed) {
    dock->collapsed = 0;
    wDockShowIcons(dock);
  } else {
    dock->collapsed = 1;
    wDockHideIcons(dock);
  }
}

static void openDockMenu(WDock *dock, WAppIcon *aicon, XEvent *event)
{
  WScreen *scr = dock->screen_ptr;
  WObjDescriptor *desc;
  WMenuItem *entry;
  WApplication *wapp = NULL;
  int index = 0;
  int x_pos;
  int n_selected;
  int appIsRunning = aicon->flags.running && aicon->icon && aicon->icon->owner;

  if (dock->type == WM_DOCK) {
    /* Dock position menu */
#ifndef NEXTSPACE
    updateDockPositionMenu(scr->dock_pos_menu, dock);
#else
    index -= 1;
    if (dock->menu->frame->title) {
      wfree(dock->menu->frame->title);
    }
    if (!strcmp(aicon->wm_class, "GNUstep")) {
      dock->menu->frame->title = wstrdup(aicon->wm_instance);
    }
    else {
      dock->menu->frame->title = wstrdup(aicon->wm_class);
    }
#endif
    dock->menu->flags.realized = 0;
    if (!wPreferences.flags.nodrawer) {
      /* add a drawer */
      entry = dock->menu->items[++index];
      entry->clientdata = aicon;
      wMenuSetEnabled(dock->menu, index, True);
    }
  } else {
    /* clip/drawer options */
    if (scr->clip_options)
      updateClipOptionsMenu(scr->clip_options, dock);

    n_selected = numberOfSelectedIcons(dock);

    if (dock->type == WM_CLIP) {
      /* Rename Desktop */
      entry = dock->menu->items[++index];
      if (aicon != scr->clip_icon) {
        entry->callback = omnipresentCallback;
        entry->clientdata = aicon;
        if (n_selected > 0) {
          entry->flags.indicator = 0;
          entry->text = _("Toggle Omnipresent");
        } else {
          entry->flags.indicator = 1;
          entry->flags.indicator_on = aicon->flags.omnipresent;
          entry->flags.indicator_type = MI_CHECK;
          entry->text = _("Omnipresent");
        }
      }
    }

    /* select/unselect icon */
    entry = dock->menu->items[++index];
    entry->clientdata = aicon;
    entry->flags.indicator_on = aicon->icon->selected;
    wMenuSetEnabled(dock->menu, index, aicon != scr->clip_icon && !wIsADrawer(aicon));

    /* select/unselect all icons */
    entry = dock->menu->items[++index];
    entry->clientdata = aicon;
    if (n_selected > 0)
      entry->text = _("Unselect All Icons");
    else
      entry->text = _("Select All Icons");

    wMenuSetEnabled(dock->menu, index, dock->icon_count > 1);

    /* keep icon(s) */
    entry = dock->menu->items[++index];
    entry->clientdata = aicon;
    if (n_selected > 1)
      entry->text = _("Keep Icons");
    else
      entry->text = _("Keep Icon");

    wMenuSetEnabled(dock->menu, index, dock->icon_count > 1);

    if (dock->type == WM_CLIP) {
      /* this is the desktop submenu part */
      entry = dock->menu->items[++index];
      if (n_selected > 1)
        entry->text = _("Move Icons To");
      else
        entry->text = _("Move Icon To");

      if (scr->clip_submenu)
        updateDesktopMenu(scr->clip_submenu, aicon);

      wMenuSetEnabled(dock->menu, index, !aicon->flags.omnipresent);
    }

    /* remove icon(s) */
    entry = dock->menu->items[++index];
    entry->clientdata = aicon;
    if (n_selected > 1)
      entry->text = _("Remove Icons");
    else
      entry->text = _("Remove Icon");

    wMenuSetEnabled(dock->menu, index, dock->icon_count > 1);

    /* attract icon(s) */
    entry = dock->menu->items[++index];
    entry->clientdata = aicon;

    dock->menu->flags.realized = 0;
    wMenuRealize(dock->menu);
  }

  if (aicon->icon->owner)
    wapp = wApplicationOf(aicon->icon->owner->main_window);
  else
    wapp = NULL;

  /* launch */
  entry = dock->menu->items[++index];
  entry->clientdata = aicon;
  wMenuSetEnabled(dock->menu, index, aicon->command != NULL);

  /* unhide here */
  entry = dock->menu->items[++index];
  entry->clientdata = aicon;
  if (wapp && wapp->flags.hidden)
    entry->text = _("Unhide Here");
  else
    entry->text = _("Bring Here");

  wMenuSetEnabled(dock->menu, index, appIsRunning);

  /* hide */
  entry = dock->menu->items[++index];
  entry->clientdata = aicon;
  if (wapp && wapp->flags.hidden)
    entry->text = _("Unhide");
  else
    entry->text = _("Hide");

  wMenuSetEnabled(dock->menu, index, appIsRunning);

#ifndef NEXTSPACE
  /* settings */
  entry = dock->menu->entries[++index];
  entry->clientdata = aicon;
  wMenuSetEnabled(dock->menu, index, !aicon->editing && !wPreferences.flags.noupdates);
#endif
  
  /* kill or remove drawer */
  entry = dock->menu->items[++index];
  entry->clientdata = aicon;
  if (wIsADrawer(aicon)) {
    entry->callback = removeDrawerCallback;
    entry->text = _("Remove drawer");
    wMenuSetEnabled(dock->menu, index, True);
  } else {
    entry->callback = killCallback;
    entry->text = _("Kill");
    wMenuSetEnabled(dock->menu, index, appIsRunning);
  }

  if (!dock->menu->flags.realized)
    wMenuRealize(dock->menu);

  if (dock->type == WM_CLIP || dock->type == WM_DRAWER) {
    /*x_pos = event->xbutton.x_root+2; */
    x_pos = event->xbutton.x_root - dock->menu->frame->core->width / 2 - 1;
    if (x_pos < 0) {
      x_pos = 0;
    } else if (x_pos + dock->menu->frame->core->width > scr->width - 2) {
      x_pos = scr->width - dock->menu->frame->core->width - 4;
    }
  } else {
    x_pos = dock->on_right_side ? event->xbutton.x_root - (dock->menu->frame->core->width/2) : 0;
  }

  wMenuMapAt(dock->menu, x_pos, event->xbutton.y_root + 2, False);

  /* allow drag select */
  event->xany.send_event = True;
  desc = &dock->menu->menu->descriptor;
  (*desc->handle_mousedown) (desc, event);
}

/******************************************************************/
static void iconDblClick(WObjDescriptor *desc, XEvent *event)
{
  WAppIcon *btn = desc->parent;
  WDock *dock = btn->dock;
  WApplication *wapp = NULL;
  int unhideHere = 0;

  if (btn->icon->owner && !(event->xbutton.state & ControlMask)) {
    wapp = wApplicationOf(btn->icon->owner->main_window);

    assert(wapp != NULL);

    WMLogInfo("Dock icon Double-click for desktop %i leader: %lu",
             wapp->last_desktop, wapp->main_window);
    
    unhideHere = (event->xbutton.state & ShiftMask);

    /* go to the last desktop that the user worked on the app */
    if (wapp->last_desktop != dock->screen_ptr->current_desktop && !unhideHere) {
      wApplicationActivate(wapp);
    }

    wUnhideApplication(wapp, event->xbutton.button == Button2, unhideHere);

    if (event->xbutton.state & ALT_MOD_MASK)
      wApplicationHideOthers(btn->icon->owner);
  }
  else {
    if (event->xbutton.button == Button1) {
      if (event->xbutton.state & MOD_MASK) {
        /* raise/lower dock */
        toggleLowered(dock);
      }
      else if (btn == dock->screen_ptr->clip_icon) {
        if (getClipButton(event->xbutton.x, event->xbutton.y) != CLIP_IDLE) {
          handleClipChangeDesktop(dock->screen_ptr, event);
        }
        else if (wPreferences.flags.clip_merged_in_dock) {
          // Is actually the dock
          if (btn->command) {
            if (!btn->flags.launching
                && (!btn->flags.running || (event->xbutton.state & ControlMask))) {
              launchDockedApplication(btn, False);
            }
          }
        }
        else {
          toggleCollapsed(dock);
        }
      }
      else if (wIsADrawer(btn)) {
        toggleCollapsed(dock);
      }
      else if (btn->command) {
        if (!btn->flags.launching && (!btn->flags.running || (event->xbutton.state & ControlMask)))
          launchDockedApplication(btn, False);
      }
    }
  }
}

static void handleDockMove(WDock *dock, WAppIcon *aicon, XEvent *event)
{
  WScreen *scr = dock->screen_ptr;
  int ofs_x = event->xbutton.x, ofs_y = event->xbutton.y;
  WIcon *icon = aicon->icon;
  WAppIcon *tmpaicon;
  WDrawerChain *dc;
  int x = aicon->x_pos, y = aicon->y_pos;;
  int shad_x = x, shad_y = y;
  XEvent ev;
  int grabbed = 0, done, previously_on_right, now_on_right, previous_x_pos, i;
  Pixmap ghost = None;
  int superfluous = wPreferences.superfluous;	/* we catch it to avoid problems */

  if (XGrabPointer(dpy, aicon->icon->core->window, True, ButtonMotionMask
                   | ButtonReleaseMask | ButtonPressMask, GrabModeAsync,
                   GrabModeAsync, None, None, CurrentTime) != GrabSuccess)
    WMLogWarning("pointer grab failed for dock move");

  if (dock->type == WM_DRAWER) {
    Window wins[2];
    wins[0] = icon->core->window;
    wins[1] = scr->dock_shadow;
    XRestackWindows(dpy, wins, 2);
    XMoveResizeWindow(dpy, scr->dock_shadow, aicon->x_pos, aicon->y_pos,
                      ICON_SIZE, ICON_SIZE);
    if (superfluous) {
      if (icon->pixmap!=None)
        ghost = MakeGhostIcon(scr, icon->pixmap);
      else
        ghost = MakeGhostIcon(scr, icon->core->window);

      XSetWindowBackgroundPixmap(dpy, scr->dock_shadow, ghost);
      XClearWindow(dpy, scr->dock_shadow);
    }
    XMapWindow(dpy, scr->dock_shadow);
  }

  previously_on_right = now_on_right = dock->on_right_side;
  previous_x_pos = dock->x_pos;
  done = 0;
  while (!done) {
    WMMaskEvent(dpy, PointerMotionMask | ButtonReleaseMask | ButtonPressMask
                | ButtonMotionMask | ExposureMask | EnterWindowMask, &ev);
    switch (ev.type) {
    case Expose:
      WMHandleEvent(&ev);
      break;

    case EnterNotify:
      /* It means the cursor moved so fast that it entered
       * something else (if moving slowly, it would have
       * stayed in the dock that is being moved. Ignore such
       * "spurious" EnterNotifiy's */
      break;

    case MotionNotify:
      if (!grabbed) {
        if (abs(ofs_x - ev.xmotion.x) >= MOVE_THRESHOLD
            || abs(ofs_y - ev.xmotion.y) >= MOVE_THRESHOLD) {
          XChangeActivePointerGrab(dpy, ButtonMotionMask
                                   | ButtonReleaseMask | ButtonPressMask,
                                   wPreferences.cursor[WCUR_MOVE], CurrentTime);
          grabbed = 1;
        }
        break;
      }
      switch (dock->type) {
      case WM_CLIP:
        x = ev.xmotion.x_root - ofs_x;
        y = ev.xmotion.y_root - ofs_y;
        wScreenKeepInside(scr, &x, &y, ICON_SIZE, ICON_SIZE);
        moveDock(dock, x, y);
        break;
      case WM_DOCK:
        x = ev.xmotion.x_root - ofs_x;
        y = ev.xmotion.y_root - ofs_y;
        if (previously_on_right)
          {
            now_on_right = (ev.xmotion.x_root >= previous_x_pos - ICON_SIZE);
          }
        else
          {
            now_on_right = (ev.xmotion.x_root > previous_x_pos + ICON_SIZE * 2);
          }
        if (now_on_right != dock->on_right_side)
          {
            dock->on_right_side = now_on_right;
            swapDock(dock);
            wArrangeIcons(scr, False);
          }
        // Also perform the vertical move
        wScreenKeepInside(scr, &x, &y, ICON_SIZE, ICON_SIZE);
        moveDock(dock, dock->x_pos, y);
        if (wPreferences.flags.wrap_appicons_in_dock)
          {
            for (i = 0; i < dock->max_icons; i++) {
              int new_y, new_index, j, ok;

              tmpaicon = dock->icon_array[i];
              if (tmpaicon == NULL)
                continue;
              if (onScreen(scr, tmpaicon->x_pos, tmpaicon->y_pos))
                continue;
              new_y = (tmpaicon->y_pos + ICON_SIZE * dock->max_icons) % (ICON_SIZE * dock->max_icons);
              new_index = (new_y - dock->y_pos) / ICON_SIZE;
              if (!onScreen(scr, tmpaicon->x_pos, new_y))
                continue;
              ok = 1;
              for (j = 0; j < dock->max_icons; j++)
                {
                  if (dock->icon_array[j] != NULL &&
                      dock->icon_array[j]->yindex == new_index)
                    {
                      ok = 0;
                      break;
                    }
                }
              if (!ok || getDrawer(scr, new_index) != NULL)
                continue;
              wDockReattachIcon(dock, tmpaicon, tmpaicon->xindex, new_index);
            }
            for (dc = scr->drawers; dc != NULL; dc = dc->next)
              {
                int new_y, new_index, j, ok;
                tmpaicon = dc->adrawer->icon_array[0];
                if (onScreen(scr, tmpaicon->x_pos, tmpaicon->y_pos))
                  continue;
                new_y = (tmpaicon->y_pos + ICON_SIZE * dock->max_icons) % (ICON_SIZE * dock->max_icons);
                new_index = (new_y - dock->y_pos) / ICON_SIZE;
                if (!onScreen(scr, tmpaicon->x_pos, new_y))
                  continue;
                ok = 1;
                for (j = 0; j < dock->max_icons; j++)
                  {
                    if (dock->icon_array[j] != NULL &&
                        dock->icon_array[j]->yindex == new_index)
                      {
                        ok = 0;
                        break;
                      }
                  }
                if (!ok || getDrawer(scr, new_index) != NULL)
                  continue;
                moveDock(dc->adrawer, tmpaicon->x_pos, new_y);
              }
          }
        break;
      case WM_DRAWER:
        {
          WDock *real_dock = dock->screen_ptr->dock;
          Bool snapped;
          int ix, iy;
          x = ev.xmotion.x_root - ofs_x;
          y = ev.xmotion.y_root - ofs_y;
          snapped = wDockSnapIcon(real_dock, aicon, x, y, &ix, &iy, True);
          if (snapped) {
            shad_x = real_dock->x_pos + ix * wPreferences.icon_size;
            shad_y = real_dock->y_pos + iy * wPreferences.icon_size;
            XMoveWindow(dpy, scr->dock_shadow, shad_x, shad_y);
          }
          moveDock(dock, x, y);
          break;
        }
      }
      break;

    case ButtonPress:
      break;

    case ButtonRelease:
      if (ev.xbutton.button != event->xbutton.button)
        break;
      XUngrabPointer(dpy, CurrentTime);
      if (dock->type == WM_DRAWER) {
        Window wins[dock->icon_count];
        int offset_index;

        /*
         * When the dock is on the Right side, the index of the icons are negative to
         * reflect the fact that they are placed on the other side of the dock; we use
         * an offset here so we can have an always positive index for the storage in
         * the 'wins' array.
         */
        if (dock->on_right_side)
          offset_index = dock->icon_count - 1;
        else
          offset_index = 0;

        for (i = 0; i < dock->max_icons; i++) {
          tmpaicon = dock->icon_array[i];
          if (tmpaicon == NULL)
            continue;
          wins[tmpaicon->xindex + offset_index] = tmpaicon->icon->core->window;
        }
        wSlideWindowList(wins, dock->icon_count,
                      (dock->on_right_side ? x - (dock->icon_count - 1) * ICON_SIZE : x),
                      y,
                      (dock->on_right_side ? shad_x - (dock->icon_count - 1) * ICON_SIZE : shad_x),
                      shad_y);
        XUnmapWindow(dpy, scr->dock_shadow);
        moveDock(dock, shad_x, shad_y);
        XResizeWindow(dpy, scr->dock_shadow, ICON_SIZE, ICON_SIZE);
      }
      done = 1;
      break;
    }
  }
  if (superfluous) {
    if (ghost != None)
      XFreePixmap(dpy, ghost);
    XSetWindowBackground(dpy, scr->dock_shadow, scr->white_pixel);
  }
}

static int getClipButton(int px, int py)
{
  int pt = (CLIP_BUTTON_SIZE + 2) * ICON_SIZE / 64;

  if (px < 0 || py < 0 || px >= ICON_SIZE || py >= ICON_SIZE)
    return CLIP_IDLE;

  if (py <= pt - ((int)ICON_SIZE - 1 - px))
    return CLIP_FORWARD;
  else if (px <= pt - ((int)ICON_SIZE - 1 - py))
    return CLIP_REWIND;

  return CLIP_IDLE;
}

static void handleClipChangeDesktop(WScreen *scr, XEvent *event)
{
  XEvent ev;
  int done, direction, new_ws;
  int new_dir;
  WDock *clip = scr->clip_icon->dock;

  direction = getClipButton(event->xbutton.x, event->xbutton.y);

  clip->lclip_button_pushed = direction == CLIP_REWIND;
  clip->rclip_button_pushed = direction == CLIP_FORWARD;

  wClipIconPaint(scr->clip_icon);
  done = 0;
  while (!done) {
    WMMaskEvent(dpy, ExposureMask | ButtonMotionMask | ButtonReleaseMask | ButtonPressMask, &ev);
    switch (ev.type) {
    case Expose:
      WMHandleEvent(&ev);
      break;

    case MotionNotify:
      new_dir = getClipButton(ev.xmotion.x, ev.xmotion.y);
      if (new_dir != direction) {
        direction = new_dir;
        clip->lclip_button_pushed = direction == CLIP_REWIND;
        clip->rclip_button_pushed = direction == CLIP_FORWARD;
        wClipIconPaint(scr->clip_icon);
      }
      break;

    case ButtonPress:
      break;

    case ButtonRelease:
      if (ev.xbutton.button == event->xbutton.button)
        done = 1;
    }
  }

  clip->lclip_button_pushed = 0;
  clip->rclip_button_pushed = 0;

  new_ws = wPreferences.ws_advance || (event->xbutton.state & ControlMask);

  if (direction == CLIP_FORWARD) {
    if (scr->current_desktop < scr->desktop_count - 1)
      wDesktopChange(scr, scr->current_desktop + 1, NULL);
    else if (new_ws && scr->current_desktop < MAX_DESKTOPS - 1)
      wDesktopChange(scr, scr->current_desktop + 1, NULL);
    else if (wPreferences.ws_cycle)
      wDesktopChange(scr, 0, NULL);
  } else if (direction == CLIP_REWIND) {
    if (scr->current_desktop > 0)
      wDesktopChange(scr, scr->current_desktop - 1, NULL);
    else if (scr->current_desktop == 0 && wPreferences.ws_cycle)
      wDesktopChange(scr, scr->desktop_count - 1, NULL);
  }

  wClipIconPaint(scr->clip_icon);
}

static void iconMouseDown(WObjDescriptor *desc, XEvent *event)
{
  WAppIcon *aicon = desc->parent;
  WDock *dock = aicon->dock;
  WScreen *scr = aicon->icon->core->screen_ptr;

  WMLogInfo("Dock iconMouseDown");
  
  if (aicon->flags.editing || WCHECK_STATE(WSTATE_MODAL))
    return;

  scr->last_dock = dock;

  if (dock->menu->flags.mapped)
    wMenuUnmap(dock->menu);

  if (IsDoubleClick(scr, event)) {
    /* double-click was not on the main Dock or Clip icon */
    /*    || getClipButton(event->xbutton.x, event->xbutton.y) == CLIP_IDLE) { */
    if (dock->type == WM_DOCK && aicon->yindex != 0) {
      iconDblClick(desc, event);
      return;
    }
  }

  if (event->xbutton.button == Button1) {
    if (!(event->xbutton.state & MOD_MASK)) {
      wDockRaise(dock);
    }
    if ((event->xbutton.state & ShiftMask) && aicon != scr->clip_icon && dock->type != WM_DOCK) {
      wIconSelect(aicon->icon);
      return;
    }

    if (aicon->yindex == 0 && aicon->xindex == 0) {
      if (getClipButton(event->xbutton.x, event->xbutton.y) != CLIP_IDLE &&
          (dock->type == WM_CLIP ||
           (dock->type == WM_DOCK && wPreferences.flags.clip_merged_in_dock))) {
        handleClipChangeDesktop(scr, event);
      } else {
        handleDockMove(dock, aicon, event);
      }
    } else {
      Bool hasMoved = wHandleAppIconMove(aicon, event);
      if (wPreferences.single_click && !hasMoved) {
        iconDblClick(desc, event);
      }
    }
  } else if (event->xbutton.button == Button2 && dock->type == WM_CLIP &&
             (event->xbutton.state & ShiftMask) && aicon != scr->clip_icon) {
    wClipMakeIconOmnipresent(aicon, !aicon->flags.omnipresent);
  } else if (event->xbutton.button == Button3) {
    if (event->xbutton.send_event &&
        XGrabPointer(dpy, aicon->icon->core->window, True, ButtonMotionMask
                     | ButtonReleaseMask | ButtonPressMask, GrabModeAsync,
                     GrabModeAsync, None, None, CurrentTime) != GrabSuccess) {
      WMLogWarning("pointer grab failed for dockicon menu");
      return;
    }
    if (aicon->flags.running) {
      appIconMouseDown(desc, event);
    } else {
      openDockMenu(dock, aicon, event);
    }
  } else if (event->xbutton.button == Button2) {
    WAppIcon *btn = desc->parent;

    if (!btn->flags.launching && (!btn->flags.running || (event->xbutton.state & ControlMask))) {
      launchDockedApplication(btn, True);
    }
  } else if (event->xbutton.button == Button4 && dock->type == WM_CLIP) {
    wDesktopRelativeChange(scr, 1);
  } else if (event->xbutton.button == Button5 && dock->type == WM_CLIP) {
    wDesktopRelativeChange(scr, -1);
  }
}

static void clipEnterNotify(WObjDescriptor *desc, XEvent *event)
{
  WAppIcon *btn = (WAppIcon *) desc->parent;
  WDock *dock, *tmp;
  WScreen *scr;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) event;

  assert(event->type == EnterNotify);

  if (desc->parent_type != WCLASS_DOCK_ICON)
    return;

  scr = btn->icon->core->screen_ptr;
  dock = btn->dock;

  if (dock == NULL)
    return;

  /* The auto raise/lower code */
  tmp = (dock->type == WM_DRAWER ? scr->dock : dock);
  if (tmp->auto_lower_magic) {
    WMDeleteTimerHandler(tmp->auto_lower_magic);
    tmp->auto_lower_magic = NULL;
  }
  if (tmp->auto_raise_lower && !tmp->auto_raise_magic)
    tmp->auto_raise_magic = WMAddTimerHandler(wPreferences.clip_auto_raise_delay, 0,
                                              clipAutoRaise, (void *)tmp);

  if (dock->type != WM_CLIP && dock->type != WM_DRAWER)
    return;

  /* The auto expand/collapse code */
  if (dock->auto_collapse_magic) {
    WMDeleteTimerHandler(dock->auto_collapse_magic);
    dock->auto_collapse_magic = NULL;
  }
  if (dock->auto_collapse && !dock->auto_expand_magic)
    dock->auto_expand_magic = WMAddTimerHandler(wPreferences.clip_auto_expand_delay, 0,
                                                clipAutoExpand, (void *)dock);
}

static void clipLeave(WDock *dock)
{
  XEvent event;
  WObjDescriptor *desc = NULL;
  WDock *tmp;

  if (dock == NULL)
    return;

  if (XCheckTypedEvent(dpy, EnterNotify, &event) != False) {
    if (XFindContext(dpy, event.xcrossing.window, w_global.context.client_win,
                     (XPointer *) & desc) != XCNOENT
        && desc && desc->parent_type == WCLASS_DOCK_ICON
        && ((WAppIcon *) desc->parent)->dock == dock) {
      /* We haven't left the dock/clip/drawer yet */
      XPutBackEvent(dpy, &event);
      return;
    }

    XPutBackEvent(dpy, &event);
  } else {
    /* We entered a withdrawn window, so we're still in Clip */
    return;
  }

  tmp = (dock->type == WM_DRAWER ? dock->screen_ptr->dock : dock);
  if (tmp->auto_raise_magic) {
    WMDeleteTimerHandler(tmp->auto_raise_magic);
    tmp->auto_raise_magic = NULL;
  }
  if (tmp->auto_raise_lower && !tmp->auto_lower_magic)
    tmp->auto_lower_magic = WMAddTimerHandler(wPreferences.clip_auto_lower_delay, 0,
                                              clipAutoLower, (void *)tmp);

  if (dock->type != WM_CLIP && dock->type != WM_DRAWER)
    return;

  if (dock->auto_expand_magic) {
    WMDeleteTimerHandler(dock->auto_expand_magic);
    dock->auto_expand_magic = NULL;
  }
  if (dock->auto_collapse && !dock->auto_collapse_magic)
    dock->auto_collapse_magic = WMAddTimerHandler(wPreferences.clip_auto_collapse_delay, 0,
                                                  clipAutoCollapse, (void *)dock);
}

static void clipLeaveNotify(WObjDescriptor *desc, XEvent *event)
{
  WAppIcon *btn = (WAppIcon *) desc->parent;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) event;

  assert(event->type == LeaveNotify);

  if (desc->parent_type != WCLASS_DOCK_ICON)
    return;

  clipLeave(btn->dock);
}

static void clipAutoCollapse(CFRunLoopTimerRef timer, void *cdata)
{
  WDock *dock = (WDock *) cdata;

  if (dock->type != WM_CLIP && dock->type != WM_DRAWER)
    return;

  if (dock->auto_collapse) {
    dock->collapsed = 1;
    wDockHideIcons(dock);
  }
  dock->auto_collapse_magic = NULL;
}

static void clipAutoExpand(CFRunLoopTimerRef timer, void *cdata)
{
  WDock *dock = (WDock *) cdata;

  if (dock->type != WM_CLIP && dock->type != WM_DRAWER)
    return;

  if (dock->auto_collapse) {
    dock->collapsed = 0;
    wDockShowIcons(dock);
  }
  dock->auto_expand_magic = NULL;
}

static void clipAutoLower(CFRunLoopTimerRef timer, void *cdata)
{
  WDock *dock = (WDock *) cdata;

  if (dock->auto_raise_lower)
    wDockLower(dock);

  dock->auto_lower_magic = NULL;
}

static void clipAutoRaise(CFRunLoopTimerRef timer, void *cdata)
{
  WDock *dock = (WDock *) cdata;

  if (dock->auto_raise_lower)
    wDockRaise(dock);

  dock->auto_raise_magic = NULL;
}

static Bool iconCanBeOmnipresent(WAppIcon *aicon)
{
  WScreen *scr = aicon->icon->core->screen_ptr;
  WDock *clip;
  WAppIcon *btn;
  int i, j;

  for (i = 0; i < scr->desktop_count; i++) {
    clip = scr->desktops[i]->clip;

    if (clip == aicon->dock)
      continue;

    if (clip->icon_count + scr->global_icon_count >= clip->max_icons)
      return False;	/* Clip is full in some desktop */

    for (j = 0; j < clip->max_icons; j++) {
      btn = clip->icon_array[j];
      if (btn && btn->xindex == aicon->xindex && btn->yindex == aicon->yindex)
        return False;
    }
  }

  return True;
}

int wClipMakeIconOmnipresent(WAppIcon *aicon, int omnipresent)
{
  WScreen *scr = aicon->icon->core->screen_ptr;
  WAppIconChain *new_entry, *tmp, *tmp1;
  int status = WO_SUCCESS;

  if ((scr->dock && aicon->dock == scr->dock) || aicon == scr->clip_icon)
    return WO_NOT_APPLICABLE;

  if (aicon->flags.omnipresent == omnipresent)
    return WO_SUCCESS;

  if (omnipresent) {
    if (iconCanBeOmnipresent(aicon)) {
      aicon->flags.omnipresent = 1;
      new_entry = wmalloc(sizeof(WAppIconChain));
      new_entry->aicon = aicon;
      new_entry->next = scr->global_icons;
      scr->global_icons = new_entry;
      scr->global_icon_count++;
    } else {
      aicon->flags.omnipresent = 0;
      status = WO_FAILED;
    }
  } else {
    aicon->flags.omnipresent = 0;
    if (aicon == scr->global_icons->aicon) {
      tmp = scr->global_icons->next;
      wfree(scr->global_icons);
      scr->global_icons = tmp;
      scr->global_icon_count--;
    } else {
      tmp = scr->global_icons;
      while (tmp->next) {
        if (tmp->next->aicon == aicon) {
          tmp1 = tmp->next->next;
          wfree(tmp->next);
          tmp->next = tmp1;
          scr->global_icon_count--;
          break;
        }
        tmp = tmp->next;
      }
    }
  }

  wAppIconPaint(aicon);

  return status;
}

static void drawerAppendToChain(WScreen *scr, WDock *drawer)
{
  WDrawerChain **where_to_add;

  where_to_add = &scr->drawers;
  while ((*where_to_add) != NULL) {
    where_to_add = &(*where_to_add)->next;
  }

  *where_to_add = wmalloc(sizeof(WDrawerChain));
  (*where_to_add)->adrawer = drawer;
  (*where_to_add)->next = NULL;
  scr->drawer_count++;
}

static void drawerRemoveFromChain(WScreen *scr, WDock *drawer)
{
  WDrawerChain *next, **to_remove;

  to_remove = &scr->drawers;
  while (True) {
    if (*to_remove == NULL) {
      WMLogWarning("The drawer to be removed can not be found.");
      return;
    }
    if ((*to_remove)->adrawer == drawer)
      break;

    to_remove = &(*to_remove)->next;
  }
  next = (*to_remove)->next;
  wfree(*to_remove);
  *to_remove = next;
  scr->drawer_count--;
}

/* Don't free the returned string. Duplicate it. */
static char * findUniqueName(WScreen *scr, const char *instance_basename)
{
  static char buffer[128];
  WDrawerChain *dc;
  int i;
  Bool already_in_use = True;

#define UNIQUE_NAME_WATCHDOG 128
  for (i = 0; already_in_use && i < UNIQUE_NAME_WATCHDOG; i++) {
    snprintf(buffer, sizeof buffer, "%s%d", instance_basename, i);

    already_in_use = False;

    for (dc = scr->drawers; dc != NULL; dc = dc->next) {
      if (!strncmp(dc->adrawer->icon_array[0]->wm_instance, buffer,
                   sizeof buffer)) {
        already_in_use = True;
        break;
      }
    }
  }

  if (i == UNIQUE_NAME_WATCHDOG)
    WMLogWarning("Couldn't find a unique name for drawer in %d attempts.", i);
#undef UNIQUE_NAME_WATCHDOG

  return buffer;
}

static void drawerIconExpose(WObjDescriptor *desc, XEvent *event)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) event;

  wDrawerIconPaint((WAppIcon *) desc->parent);
}

static int addADrawer(WScreen *scr)
{
  int i, y, sig, found_y;
  WDock *drawer, *dock = scr->dock;
  WDrawerChain *dc;
  char can_be_here[2 * dock->max_icons - 1];

  if (dock->icon_count + scr->drawer_count >= dock->max_icons)
    return -1;

  for (y = -dock->max_icons + 1; y < dock->max_icons; y++) {
    can_be_here[y + dock->max_icons - 1] = True;
  }
  for (i = 0; i < dock->max_icons; i++) {
    if (dock->icon_array[i] != NULL)
      can_be_here[dock->icon_array[i]->yindex + dock->max_icons - 1] = False;
  }
  for (dc = scr->drawers; dc != NULL; dc = dc->next) {
    y = (int) ((dc->adrawer->y_pos - dock->y_pos) / ICON_SIZE);
    can_be_here[y + dock->max_icons - 1] = False;
  }

  found_y = False;
  for (sig = 1; !found_y && sig > -2; sig -= 2) // 1, then -1
    {
      for (y = sig; sig * y < dock->max_icons; y += sig)
        {
          if (can_be_here[y + dock->max_icons - 1] &&
              onScreen(scr, dock->x_pos, dock->y_pos + y * ICON_SIZE))
            {
              found_y = True;
              break;
            }
        }
    }
    
  if (!found_y)
    /* This can happen even when dock->icon_count + scr->drawer_count
     * < dock->max_icons when the dock is not aligned on an
     * ICON_SIZE multiple, as some space is lost above and under it */
    return -1;

  drawer = wDockCreate(scr, WM_DRAWER, NULL);
  drawer->lowered = scr->dock->lowered;
  if (!drawer->lowered)
    ChangeStackingLevel(drawer->icon_array[0]->icon->core, NSDockWindowLevel);
  else
    ChangeStackingLevel(drawer->icon_array[0]->icon->core, NSNormalWindowLevel);
  drawer->auto_raise_lower = scr->dock->auto_raise_lower;
  drawer->x_pos = dock->x_pos;
  drawer->y_pos = dock->y_pos + ICON_SIZE * y;
  drawer->icon_array[0]->xindex = 0;
  drawer->icon_array[0]->yindex = 0;
  drawer->icon_array[0]->x_pos = drawer->x_pos;
  drawer->icon_array[0]->y_pos = drawer->y_pos;
  XMoveWindow(dpy, drawer->icon_array[0]->icon->core->window,
              drawer->icon_array[0]->x_pos, drawer->icon_array[0]->y_pos);

  return 0;
}

static void addADrawerCallback(WMenu *menu, WMenuItem *entry)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(entry->clientdata!=NULL);
  addADrawer(((WAppIcon *) entry->clientdata)->dock->screen_ptr);
}

static void drawerDestroy(WDock *drawer)
{
  WScreen *scr;
  int i;
  WAppIcon *aicon = NULL;
  CFMutableArrayRef icons;

  if (drawer == NULL)
    return;

  scr = drawer->screen_ptr;

  /* Note regarding menus: we can't delete any dock/clip/drawer menu, because
   * that would (attempt to) wfree some memory in gettext library (see menu
   * entries that have several "versions", such like "Hide" and "Unhide"). */
  wDefaultPurgeInfo(drawer->icon_array[0]->wm_instance,
                    drawer->icon_array[0]->wm_class);

  if (drawer->icon_count == 2) {
    /* Drawer contains a single appicon: dock it where the drawer was */
    for (i = 1; i < drawer->max_icons; i++) {
      aicon = drawer->icon_array[i];
      if (aicon != NULL)
        break;
    }

    wDockMoveIconBetweenDocks(drawer, scr->dock, aicon,
                              0, (drawer->y_pos - scr->dock->y_pos) / ICON_SIZE);
    XMoveWindow(dpy, aicon->icon->core->window, drawer->x_pos, drawer->y_pos);
    XMapWindow(dpy, aicon->icon->core->window);
  } else if (drawer->icon_count > 2) {
    icons = CFArrayCreateMutable(kCFAllocatorDefault, drawer->icon_count - 1, NULL);
    for (i = 1; i < drawer->max_icons; i++) {
      aicon = drawer->icon_array[i];
      if (aicon == NULL)
        continue;
      CFArrayAppendValue(icons, aicon);
    }
    removeIcons(icons, drawer);
  }

  if (drawer->auto_collapse_magic) {
    WMDeleteTimerHandler(drawer->auto_collapse_magic);
    drawer->auto_collapse_magic = NULL;
  }
  if (drawer->auto_lower_magic) {
    WMDeleteTimerHandler(drawer->auto_lower_magic);
    drawer->auto_lower_magic = NULL;
  }

  wAppIconDestroy(drawer->icon_array[0]);
  wfree(drawer->icon_array);
  drawer->icon_array = NULL;

  drawerRemoveFromChain(scr, drawer);
  if (scr->last_dock == drawer)
    scr->last_dock = NULL;
  if (scr->attracting_drawer == drawer)
    scr->attracting_drawer = NULL;

  wfree(drawer);
}

static void removeDrawerCallback(WMenu *menu, WMenuItem *entry)
{
  WDock *dock = ((WAppIcon*)entry->clientdata)->dock;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(dock != NULL);

  if (dock->icon_count > 2) {
    if (WSRunAlertPanel(_("Drawer"),
                        _("All icons in this drawer will be detached!"),
                        _("OK"), _("Cancel"), NULL) != NSAlertDefaultReturn)
      return;
  }
  drawerDestroy(dock);
}

void wDrawerIconPaint(WAppIcon *dicon)
{
  Window win = dicon->icon->core->window;
  WScreen *scr = dicon->icon->core->screen_ptr;
  XPoint p[4];
  GC gc = scr->draw_gc;
  WMColor *color;

  wIconPaint(dicon->icon);

  if (!dicon->dock->collapsed)
    color = scr->clip_title_color[CLIP_NORMAL];
  else
    color = scr->clip_title_color[CLIP_COLLAPSED];
  XSetForeground(dpy, gc, WMColorPixel(color));

  if (dicon->dock->on_right_side) {
    p[0].x = p[3].x = 10;
    p[0].y = p[3].y = ICON_SIZE / 2 - 5;
    p[1].x = 10;
    p[1].y = ICON_SIZE / 2 + 5;
    p[2].x = 5;
    p[2].y = ICON_SIZE / 2;
  }
  else {
    p[0].x = p[3].x = ICON_SIZE-1 - 10;
    p[0].y = p[3].y = ICON_SIZE / 2 - 5;
    p[1].x = ICON_SIZE-1 - 10;
    p[1].y = ICON_SIZE / 2 + 5;
    p[2].x = ICON_SIZE-1 - 5;
    p[2].y = ICON_SIZE / 2;
  }
  XFillPolygon(dpy, win, gc, p,3,Convex,CoordModeOrigin);
  XDrawLines(dpy, win, gc, p,4,CoordModeOrigin);
}

RImage* wDrawerMakeTile(WScreen *scr, RImage *normalTile)
{
  RImage *tile = RCloneImage(normalTile);
  RColor dark;
  RColor light;

  dark.alpha = 0;
  dark.red = dark.green = dark.blue = 60;

  light.alpha = 0;
  light.red = light.green = light.blue = 80;

  /* arrow bevel */
  if (!scr->dock || scr->dock->on_right_side) {
    ROperateLine(tile, RSubtractOperation, 11, ICON_SIZE / 2 - 7,
                 4, ICON_SIZE / 2, &dark);       /* / */
    ROperateLine(tile, RSubtractOperation, 11, ICON_SIZE / 2 + 7,
                 4, ICON_SIZE / 2, &dark);       /* \ */
    ROperateLine(tile, RAddOperation,      11, ICON_SIZE / 2 - 7,
                 11, ICON_SIZE / 2 + 7, &light); /* | */
  }
  else {
    ROperateLine(tile, RSubtractOperation, ICON_SIZE-1 - 11, ICON_SIZE / 2 - 7,
                 ICON_SIZE-1 - 4, ICON_SIZE / 2, &dark);      /* \ */
    ROperateLine(tile, RAddOperation,      ICON_SIZE-1 - 11, ICON_SIZE / 2 + 7,
                 ICON_SIZE-1 - 4, ICON_SIZE / 2, &light);     /* / */
    ROperateLine(tile, RSubtractOperation, ICON_SIZE-1 - 11, ICON_SIZE / 2 - 7,
                 ICON_SIZE-1 - 11, ICON_SIZE / 2 + 7, &dark); /* | */
  }
  return tile;
}

static void swapDrawer(WDock *drawer, int new_x)
{
  int i;

  drawer->on_right_side = !drawer->on_right_side;
  drawer->x_pos = new_x;

  for (i = 0; i < drawer->max_icons; i++) {
    WAppIcon *ai;

    ai = drawer->icon_array[i];
    if (ai == NULL)
      continue;
    ai->xindex *= -1; /* so A B C becomes C B A */
    ai->x_pos = new_x + ai->xindex * ICON_SIZE;

    /* Update drawer's tile */
    if (i == 0) {
      wIconUpdate(ai->icon);
      wDrawerIconPaint(ai);
    }
    XMoveWindow(dpy, ai->icon->core->window, ai->x_pos, ai->y_pos);
  }
}

static void swapDrawers(WScreen *scr, int new_x)
{
  WDrawerChain *dc;

  if (scr->drawer_tile)
    RReleaseImage(scr->drawer_tile);

  scr->drawer_tile = wDrawerMakeTile(scr, scr->icon_tile);

  for (dc = scr->drawers; dc != NULL; dc = dc->next)
    swapDrawer(dc->adrawer, new_x);
}

int wIsADrawer(WAppIcon *aicon)
{
  return aicon && aicon->dock &&
    aicon->dock->type == WM_DRAWER && aicon->dock->icon_array[0] == aicon;
}

static WDock* getDrawer(WScreen *scr, int y_index)
{
  WDrawerChain *dc;

  for (dc = scr->drawers; dc != NULL; dc = dc->next) {
    if (dc->adrawer->y_pos - scr->dock->y_pos == y_index * ICON_SIZE)
      return dc->adrawer;
  }
  return NULL;
}

/* Find the "hole" a moving appicon created when snapped into the
 * drawer. redocking is a boolean. If the moving appicon comes from the
 * drawer, drawer->icon_count is correct. If not, redocking is then false and
 * there are now drawer->icon_count plus one appicons in the drawer. */
static int indexOfHole(WDock *drawer, WAppIcon *moving_aicon, int redocking)
{
  int index_of_hole, i;

  /* Classic interview question...
   *
   * We have n-1 (n = drawer->icon_count-1 or drawer->icon_count, see
   * redocking) appicons, whose xindex are unique in [1..n]. One is missing:
   * that's where the ghost of the moving appicon is, that's what the
   * function should return.
   *
   * We compute 1+2+...+n (this sum is equal to n*(n+1)/2), we substract to
   * this sum the xindex of each of the n-1 appicons, and we get the correct
   * index! */

  if (redocking) {
    index_of_hole = (drawer->icon_count - 1) * drawer->icon_count / 2;
  } else {
    index_of_hole = drawer->icon_count * (drawer->icon_count + 1) / 2;
  }
  index_of_hole *= (drawer->on_right_side ? -1 : 1);

  for (i = 1; i < drawer->max_icons; i++) {
    if (drawer->icon_array[i] && drawer->icon_array[i] != moving_aicon)
      index_of_hole -= drawer->icon_array[i]->xindex;
  }
  /* WMLogInfo(" Index of the moving appicon is %d (%sredocking)", index_of_hole, (redocking ? "" : "not ")); */
  if (abs(index_of_hole) > abs(drawer->icon_count) - (redocking ? 1 : 0))
    WMLogWarning(" index_of_hole is too large ! (%d greater than %d)",
             index_of_hole, abs(drawer->icon_count) - (redocking ? 1 : 0));
  if (index_of_hole == 0)
    WMLogWarning(" index_of_hole == 0 (%sredocking, icon_count == %d)", (redocking ? "" : "not "), drawer->icon_count);

  return index_of_hole;
}

void wSlideAppicons(WAppIcon **appicons, int n, int to_the_left)
{
  int i;
  int leftmost = -1, min_index = 9999, from_x = -1; // leftmost and from_x initialized to avoid warning
  Window wins[n];
  WAppIcon *aicon;

  if (n < 1)
    return;

  for (i = 0; i < n; i++) {
    aicon = appicons[i];
    aicon->xindex += (to_the_left ? -1 : +1);
    if (aicon->xindex < min_index) {
      min_index = aicon->xindex;
      leftmost = i;
      from_x = aicon->x_pos;
    }
    aicon->x_pos += (to_the_left ? -ICON_SIZE : +ICON_SIZE);
  }

  for (i = 0; i < n; i++) {
    aicon = appicons[i];
    wins[aicon->xindex - min_index] = aicon->icon->core->window;
  }
  aicon = appicons[leftmost];
  wSlideWindowList(wins, n, from_x, aicon->y_pos, aicon->x_pos, aicon->y_pos);
}

void wDrawerFillTheGap(WDock *drawer, WAppIcon *aicon, Bool redocking)
{
  int i, j;
  int index_of_hole = indexOfHole(drawer, aicon, redocking);
  WAppIcon *aicons_to_shift[drawer->icon_count];

  j = 0;
  for (i = 0; i < drawer->max_icons; i++) {
    WAppIcon *ai = drawer->icon_array[i];
    if (ai && ai != aicon &&
        abs(ai->xindex) > abs(index_of_hole))
      aicons_to_shift[j++] = ai;
  }
  if (j != drawer->icon_count - abs(index_of_hole) - (redocking ? 1 : 0))
    WMLogWarning("Removing aicon at index %d from %s: j=%d but should be %d",
             index_of_hole, drawer->icon_array[0]->wm_instance,
             j, drawer->icon_count - abs(index_of_hole) - (redocking ? 1 : 0));
  wSlideAppicons(aicons_to_shift, j, !drawer->on_right_side);
}

static void drawerConsolidateIcons(WDock *drawer)
{
  WAppIcon *aicons_to_shift[drawer->icon_count];
  int maxRemaining = 0;
  int sum = 0;
  int i;
  for (i = 0; i < drawer->max_icons; i++) {
    WAppIcon *ai = drawer->icon_array[i];
    if (ai == NULL)
      continue;
    sum += abs(ai->xindex);
    if (abs(ai->xindex) > maxRemaining)
      maxRemaining = abs(ai->xindex);
  }
  while (sum != maxRemaining * (maxRemaining + 1) / 2) { // while there is a hole
    WAppIcon *ai;
    int n;
    // Look up for the hole at max position
    int maxDeleted;
    for (maxDeleted = maxRemaining - 1; maxDeleted > 0; maxDeleted--) {
      Bool foundAppIconThere = False;
      for (i = 0; i < drawer->max_icons; i++) {
        WAppIcon *ai = drawer->icon_array[i];
        if (ai == NULL)
          continue;
        if (abs(ai->xindex) == maxDeleted) {
          foundAppIconThere = True;
          break;
        }
      }
      if (!foundAppIconThere)
        break;
    }
    assert(maxDeleted > 0); // would mean while test is wrong
    n = 0;
    for (i = 0; i < drawer->max_icons; i++) {
      ai = drawer->icon_array[i];
      if (ai != NULL && abs(ai->xindex) > maxDeleted)
        aicons_to_shift[n++] = ai;
    }
    assert(n == maxRemaining - maxDeleted); // for the code review ;-)
    wSlideAppicons(aicons_to_shift, n, !drawer->on_right_side);
    // Efficient beancounting
    maxRemaining -= 1;
    sum -= n;
  }
}

/* similar to wDockRestoreState, but a lot a specific stuff too... */
/* static WDock *drawerRestoreState(WScreen *scr, CFDictionaryRef drawer_state) */
/* { */
/*   WDock *drawer; */
/*   WMPropList *apps, *value, *dock_state; */
/*   WAppIcon *aicon; */
/*   int count, i; */

/*   if (!drawer_state) */
/*     return NULL; */

/*   make_keys(); */

/*   WMRetainPropList(drawer_state); */

/*   /\* Get the instance name, and create a drawer *\/ */
/*   value = CFDictionaryGetValue(drawer_state, dName); */
/*   drawer = wDockCreate(scr, WM_DRAWER, WMGetFromPLString(value)); */

/*   /\* restore DnD command and paste command *\/ */
/* #ifdef USE_DOCK_XDND */
/*   value = CFDictionaryGetValue(drawer_state, dDropCommand); */
/*   if (value && WMIsPLString(value)) */
/*     drawer->icon_array[0]->dnd_command = wstrdup(WMGetFromPLString(value)); */
/* #endif /\* USE_DOCK_XDND *\/ */

/*   value = CFDictionaryGetValue(drawer_state, dPasteCommand); */
/*   if (value && WMIsPLString(value)) */
/*     drawer->icon_array[0]->paste_command = wstrdup(WMGetFromPLString(value)); */

/*   /\* restore position *\/ */
/*   value = CFDictionaryGetValue(drawer_state, dPosition); */
/*   if (!value || !WMIsPLString(value)) */
/*     COMPLAIN("Position"); */
/*   else { */
/*     int x, y, y_index; */
/*     if (sscanf(WMGetFromPLString(value), "%i,%i", &x, &y) != 2) */
/*       COMPLAIN("Position"); */

/*     /\* check position sanity *\/ */
/*     if (x != scr->dock->x_pos) { */
/*       x = scr->dock->x_pos; */
/*     } */
/*     y_index = (y - scr->dock->y_pos) / ICON_SIZE; */
/*     if (y_index >= scr->dock->max_icons) { */
/*       /\* Here we should do something more intelligent, since it */
/*        * can happen even if the user hasn't hand-edited his */
/*        * G/D/State file (but uses a lower resolution). *\/ */
/*       y_index = scr->dock->max_icons - 1; */
/*     } */
/*     y = scr->dock->y_pos + y_index * ICON_SIZE; */
/*     moveDock(drawer, x, y); */
/*   } */

/*   /\* restore dock properties (applist and others) *\/ */
/*   dock_state = CFDictionaryGetValue(drawer_state, dDock); */

/*   /\* restore lowered/raised state: same as scr->dock, no matter what *\/ */
/*   drawer->lowered = scr->dock->lowered; */
/*   if (!drawer->lowered) */
/*     ChangeStackingLevel(drawer->icon_array[0]->icon->core, NSDockWindowLevel); */
/*   else */
/*     ChangeStackingLevel(drawer->icon_array[0]->icon->core, NSNormalWindowLevel); */
/*   wRaiseFrame(drawer->icon_array[0]->icon->core); */

/*   /\* restore collapsed state *\/ */
/*   drawer->collapsed = 0; */
/*   value = CFDictionaryGetValue(dock_state, dCollapsed); */
/*   if (value && strcasecmp(WMGetFromPLString(value), "YES") == 0) { */
/*     drawer->collapsed = 1; */
/*   } */
/*   /\* restore auto-collapsed state *\/ */
/*   value = CFDictionaryGetValue(dock_state, dAutoCollapse); */
/*   if (value && strcasecmp(WMGetFromPLString(value), "YES") == 0) { */
/*     drawer->auto_collapse = 1; */
/*     drawer->collapsed = 1; */
/*   } else { */
/*     drawer->auto_collapse = 0; // because wDockCreate sets it (drawers only) */
/*   } */

/*   /\* restore auto-raise/lower state: same as scr->dock, no matter what *\/ */
/*   drawer->auto_raise_lower = scr->dock->auto_raise_lower; */

/*   /\* restore attract icons state *\/ */
/*   drawer->attract_icons = 0; */
/*   value = CFDictionaryGetValue(dock_state, dAutoAttractIcons); */
/*   if (value && strcasecmp(WMGetFromPLString(value), "YES") == 0) { */
/*     drawer->attract_icons = 1; */
/*     scr->attracting_drawer = drawer; */
/*   } */

/*   /\* application list *\/ */
/*   apps = CFDictionaryGetValue(dock_state, dApplications); */

/*   if (!apps) { */
/*     goto finish; */
/*   } */

/*   count = WMGetPropListItemCount(apps); */

/*   if (count == 0) */
/*     goto finish; */

/*   for (i=0; i<count; i++) { */
/*     if (drawer->icon_count >= drawer->max_icons) { */
/*       WMLogWarning(_("there are too many icons stored in drawer. Ignoring what doesn't fit")); */
/*       break; */
/*     } */

/*     value = WMGetFromPLArray(apps, i); */
/*     aicon = restore_icon_state(scr, value, WM_DRAWER, drawer->icon_count); */

/*     drawer->icon_array[drawer->icon_count] = aicon; */

/*     if (aicon) { */
/*       aicon->dock = drawer; */
/*       aicon->x_pos = drawer->x_pos + (aicon->xindex * ICON_SIZE); */
/*       aicon->y_pos = drawer->y_pos + (aicon->yindex * ICON_SIZE); */

/*       if (!drawer->lowered) */
/*         ChangeStackingLevel(aicon->icon->core, NSDockWindowLevel); */
/*       else */
/*         ChangeStackingLevel(aicon->icon->core, NSNormalWindowLevel); */

/*       wCoreConfigure(aicon->icon->core, aicon->x_pos, aicon->y_pos, 0, 0); */

/*       if (!drawer->collapsed) */
/*         XMapWindow(dpy, aicon->icon->core->window); */
/*       wRaiseFrame(aicon->icon->core); */

/*       drawer->icon_count++; */
/*     } */
/*   } */

/*  finish: */
/*   WMReleasePropList(drawer_state); */

/*   return drawer; */
/* } */

/* Same kind of comment than for previous function: this function is
 * very similar to make_icon_state, but has substential differences as
 * well. */
/* static WMPropList *drawerSaveState(WDock *drawer) */
/* { */
/*   WMPropList *pstr, *drawer_state; */
/*   WAppIcon *ai; */
/*   char buffer[64]; */

/*   ai = drawer->icon_array[0]; */
/*   /\* Store its name *\/ */
/*   pstr = WMCreatePLString(ai->wm_instance); */
/*   drawer_state = WMCreatePLDictionary(dName, pstr, NULL); /\* we need this final NULL *\/ */
/*   WMReleasePropList(pstr); */

/*   /\* Store its position *\/ */
/*   snprintf(buffer, sizeof(buffer), "%i,%i", ai->x_pos, ai->y_pos); */
/*   pstr = WMCreatePLString(buffer); */
/*   WMPutInPLDictionary(drawer_state, dPosition, pstr); */
/*   WMReleasePropList(pstr); */

/* #ifdef USE_DOCK_XDND */
/*   /\* Store its DnD command *\/ */
/*   if (ai->dnd_command) { */
/*     pstr = WMCreatePLString(ai->dnd_command); */
/*     WMPutInPLDictionary(drawer_state, dDropCommand, pstr); */
/*     WMReleasePropList(pstr); */
/*   } */
/* #endif /\* USE_DOCK_XDND *\/ */

/*   /\* Store its paste command *\/ */
/*   if (ai->paste_command) { */
/*     pstr = WMCreatePLString(ai->paste_command); */
/*     WMPutInPLDictionary(drawer_state, dPasteCommand, pstr); */
/*     WMReleasePropList(pstr); */
/*   } */

/*   /\* Store applications list and other properties *\/ */
/*   pstr = dockSaveState(drawer); */
/*   WMPutInPLDictionary(drawer_state, dDock, pstr); */
/*   WMReleasePropList(pstr); */

/*   return drawer_state; */
/* } */

void wDrawersSaveState(WScreen *scr)
{
  /* WMPropList *all_drawers, *drawer_state; */
  /* int i; */
  /* WDrawerChain *dc; */

  /* make_keys(); */

  /* all_drawers = WMCreatePLArray(NULL); */
  /* for (i=0, dc = scr->drawers; */
  /*      i < scr->drawer_count; */
  /*      i++, dc = dc->next) { */
  /*   drawer_state = drawerSaveState(dc->adrawer); */
  /*   WMAddToPLArray(all_drawers, drawer_state); */
  /*   WMReleasePropList(drawer_state); */
  /* } */
  /* WMPutInPLDictionary(scr->session_state, dDrawers, all_drawers); */
  /* WMReleasePropList(all_drawers); */
}

void wDrawersRestoreState(WScreen *scr)
{
  /* WMPropList *all_drawers, *drawer_state; */
  /* int i; */

  /* make_keys(); */

  /* if (scr->session_state == NULL) */
  /*   return; */

  /* all_drawers = CFDictionaryGetValue(scr->session_state, dDrawers); */
  /* if (!all_drawers) */
  /*   return; */

  /* for (i = 0; i < WMGetPropListItemCount(all_drawers); i++) { */
  /*   drawer_state = WMGetFromPLArray(all_drawers, i); */
  /*   drawerRestoreState(scr, drawer_state); */
  /*   // Note: scr->drawers was updated when the the drawer was created */
  /* } */
}

