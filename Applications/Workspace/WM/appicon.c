/* icon for applications (not mini-window)
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
#include <X11/extensions/shape.h>
#include <stdlib.h>
#include <libgen.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

#include <core/util.h>
#include <core/log_utils.h>
#include <core/string_utils.h>
#include <core/file_utils.h>
#include <core/wevent.h>
#include <core/wuserdefaults.h>

#include "WM.h"
#include "window.h"
#include "icon.h"
#include "application.h"
#include "appicon.h"
#include "actions.h"
#include "stacking.h"
#include "dock.h"
#include "desktop.h"
#include "animations.h"
#include "menu.h"
#include "framewin.h"
#include "xrandr.h"
#include "client.h"
#include "placement.h"
#include "misc.h"
#include "event.h"
#include "moveres.h"
#include "iconyard.h"
#ifdef USE_DOCK_XDND
#include "xdnd.h"
#endif

#include <Workspace+WM.h>

/*
 * icon_file for the dock is got from the preferences file by
 * using the classname/instancename
 */

#define ALT_MOD_MASK wPreferences.alt_modifier_mask
#define ICON_SIZE wPreferences.icon_size

static void iconDblClick(WObjDescriptor *desc, XEvent *event);
static void iconExpose(WObjDescriptor *desc, XEvent *event);
static void wApplicationSaveIconPathFor(const char *iconPath, const char *wm_instance,
                                        const char *wm_class);
static WAppIcon *wAppIconCreate(WWindow *leader_win);
static void add_to_appicon_list(WScreen *scr, WAppIcon *appicon);
static void remove_from_appicon_list(WScreen *scr, WAppIcon *appicon);
static void create_appicon_from_dock(WWindow *wwin, WApplication *wapp, Window main_window);

/* This function is used if the application is a .app. It checks if it has an icon in it
 * like for example /usr/local/GNUstep/Applications/WPrefs.app/WPrefs.tiff
 */
void wApplicationExtractDirPackIcon(const char *path, const char *wm_instance, const char *wm_class)
{
  char *iconPath = NULL;
  char *tmp = NULL;

  if (strstr(path, ".app")) {
    tmp = wmalloc(strlen(path) + 16);

    if (wPreferences.supports_tiff) {
      strcpy(tmp, path);
      strcat(tmp, ".tiff");
      if (access(tmp, R_OK) == 0)
        iconPath = tmp;
    }

    if (!iconPath) {
      strcpy(tmp, path);
      strcat(tmp, ".xpm");
      if (access(tmp, R_OK) == 0)
        iconPath = tmp;
    }

    if (!iconPath)
      wfree(tmp);

    if (iconPath) {
      wApplicationSaveIconPathFor(iconPath, wm_instance, wm_class);
      wfree(iconPath);
    }
  }
}

WAppIcon *wAppIconCreateForDock(WScreen *scr, const char *command, const char *wm_instance,
                                const char *wm_class, int tile)
{
  WAppIcon *aicon;

  aicon = wmalloc(sizeof(WAppIcon));
  wretain(aicon);
  aicon->yindex = -1;
  aicon->xindex = -1;

  add_to_appicon_list(scr, aicon);

  if (command)
    aicon->command = wstrdup(command);

  if (wm_class)
    aicon->wm_class = wstrdup(wm_class);

  if (wm_instance)
    aicon->wm_instance = wstrdup(wm_instance);

  if (wPreferences.flags.clip_merged_in_dock && wm_class != NULL && strcmp(wm_class, "WMDock") == 0)
    tile = TILE_CLIP;
  aicon->icon = icon_create_for_dock(scr, command, wm_instance, wm_class, tile);

#ifdef USE_DOCK_XDND
  wXDNDMakeAwareness(aicon->icon->core->window);
#endif

  /* will be overriden by dock */
  aicon->icon->core->descriptor.handle_mousedown = appIconMouseDown;
  aicon->icon->core->descriptor.handle_expose = iconExpose;
  aicon->icon->core->descriptor.parent_type = WCLASS_APPICON;
  aicon->icon->core->descriptor.parent = aicon;
  AddToStackList(aicon->icon->core);

  return aicon;
}

void create_appicon_for_application(WApplication *wapp, WWindow *wwin)
{
  /* Try to create an icon from the dock or clip */
  create_appicon_from_dock(wwin, wapp, wapp->main_window);

  /* Check if launching icon was created by Workspace */
  if (!wapp->app_icon) {
    wapp->app_icon = wLaunchingAppIconForApplication(wwin->screen, wapp);
    if (wapp->app_icon) {
      wapp->app_icon->icon->core->descriptor.handle_mousedown = appIconMouseDown;
    }
  }

  /* If app_icon was not found, create it */
  if (!wapp->app_icon) {
    /* Create the icon */
    wapp->app_icon = wAppIconCreate(wapp->main_wwin);
    wIconUpdate(wapp->app_icon->icon);

    /* Now, paint the icon */
    if (!WFLAGP(wapp->main_wwin, no_appicon))
      paint_app_icon(wapp);
  }

  /* Save the app_icon in a file */
  save_appicon(wapp->app_icon, False);
}

void unpaint_app_icon(WApplication *wapp)
{
  WAppIcon *aicon;
  WScreen *scr;
  WDock *clip;

  if (!wapp || !wapp->app_icon)
    return;

  aicon = wapp->app_icon;

  /* If the icon is docked, don't continue */
  if (aicon->flags.docked)
    return;

  scr = wapp->main_wwin->screen;
  clip = scr->desktops[scr->current_desktop]->clip;

  if (!clip || !aicon->flags.attracted || !clip->collapsed)
    XUnmapWindow(dpy, aicon->icon->core->window);

  /* We want to avoid having it on the list  because otherwise
   * there will be a hole when the icons are arranged with
   * wArrangeIcons() */
  remove_from_appicon_list(scr, aicon);

  if (wPreferences.auto_arrange_icons && !aicon->flags.attracted)
    wArrangeIcons(scr, True);
}

void paint_app_icon(WApplication *wapp)
{
  WIcon *icon;
  WScreen *scr;
  WDock *attracting_dock;
  int x = 0, y = 0;
  Bool update_icon = False;

  if (!wapp || !wapp->app_icon || !wapp->main_wwin)
    return;

  icon = wapp->app_icon->icon;
  scr = wapp->main_wwin->screen;
  wapp->app_icon->main_window = wapp->main_window;

  /* If the icon is docked, don't continue */
  if (wapp->app_icon->flags.docked)
    return;

  attracting_dock = scr->attracting_drawer != NULL ? scr->attracting_drawer
                                                   : scr->desktops[scr->current_desktop]->clip;
  if (attracting_dock && attracting_dock->attract_icons &&
      wDockFindFreeSlot(attracting_dock, &x, &y)) {
    wapp->app_icon->flags.attracted = 1;
    if (!icon->shadowed) {
      icon->shadowed = 1;
      update_icon = True;
    }
    wDockAttachIcon(attracting_dock, wapp->app_icon, x, y, update_icon);
  } else {
    /* We must know if the icon is painted in the screen,
     * because if painted, then PlaceIcon will return the next
     * space on the screen, and the icon will move */
    if (wapp->app_icon->next == NULL && wapp->app_icon->prev == NULL) {
      PlaceIcon(scr, &x, &y, wGetHeadForWindow(wapp->main_wwin));
      wAppIconMove(wapp->app_icon, x, y);
      wLowerFrame(icon->core);
    }
  }

  /* If we want appicon (no_appicon is not set) and the icon is not
   * in the appicon_list, we must add it. Else, we want to avoid
   * having it on the list */
  if (!WFLAGP(wapp->main_wwin, no_appicon) && wapp->app_icon->next == NULL &&
      wapp->app_icon->prev == NULL)
    add_to_appicon_list(scr, wapp->app_icon);

  if ((!attracting_dock || !wapp->app_icon->flags.attracted || !attracting_dock->collapsed) &&
      scr->flags.icon_yard_mapped) {
    XMapWindow(dpy, icon->core->window);
  }
  if (wPreferences.auto_arrange_icons && !wapp->app_icon->flags.attracted) {
    wArrangeIcons(scr, True);
  }
}

void removeAppIconFor(WApplication *wapp)
{
  if (!wapp->app_icon)
    return;

  if (wapp->app_icon->flags.docked && !wapp->app_icon->flags.attracted) {
    wapp->app_icon->flags.running = 0;
    /* since we keep it, we don't care if it was attracted or not */
    wapp->app_icon->flags.attracted = 0;
    wapp->app_icon->icon->shadowed = 0;
    wapp->app_icon->main_window = None;
    wapp->app_icon->pid = 0;
    wapp->app_icon->icon->owner = NULL;
    wapp->app_icon->icon->icon_win = None;

    /* Set the icon image */
    set_icon_image_from_database(wapp->app_icon->icon, wapp->app_icon->wm_instance,
                                 wapp->app_icon->wm_class, wapp->app_icon->command);

    /* Update the icon, because wapp->app_icon->icon could be NULL */
    wIconUpdate(wapp->app_icon->icon);

    /* Paint it */
    wAppIconPaint(wapp->app_icon);
  } else if (wapp->app_icon->flags.docked) {
    wapp->app_icon->flags.running = 0;
    if (wapp->app_icon->dock->type == WM_DRAWER) {
      wDrawerFillTheGap(wapp->app_icon->dock, wapp->app_icon, True);
    }
    wDockDetach(wapp->app_icon->dock, wapp->app_icon);
  } else {
    wAppIconDestroy(wapp->app_icon);
  }

  wapp->app_icon = NULL;

  if (wPreferences.auto_arrange_icons)
    wArrangeIcons(wapp->main_wwin->screen, True);
}

static WAppIcon *wAppIconCreate(WWindow *leader_win)
{
  WAppIcon *aicon;

  aicon = wmalloc(sizeof(WAppIcon));
  wretain(aicon);
  aicon->yindex = -1;
  aicon->xindex = -1;
  aicon->prev = NULL;
  aicon->next = NULL;

  if (leader_win->wm_class)
    aicon->wm_class = wstrdup(leader_win->wm_class);

  if (leader_win->wm_instance)
    aicon->wm_instance = wstrdup(leader_win->wm_instance);

  aicon->icon = icon_create_for_wwindow(leader_win);
#ifdef USE_DOCK_XDND
  wXDNDMakeAwareness(aicon->icon->core->window);
#endif

  /* will be overriden if docked */
  aicon->icon->core->descriptor.handle_mousedown = appIconMouseDown;
  aicon->icon->core->descriptor.handle_expose = iconExpose;
  aicon->icon->core->descriptor.parent_type = WCLASS_APPICON;
  aicon->icon->core->descriptor.parent = aicon;
  AddToStackList(aicon->icon->core);
  aicon->icon->show_title = 0;

  return aicon;
}

void wAppIconDestroy(WAppIcon *aicon)
{
  WScreen *scr = aicon->icon->core->screen_ptr;

  RemoveFromStackList(aicon->icon->core);
  wIconDestroy(aicon->icon);
  if (aicon->command)
    wfree(aicon->command);
#ifdef USE_DOCK_XDND
  if (aicon->dnd_command)
    wfree(aicon->dnd_command);
#endif
  if (aicon->wm_instance)
    wfree(aicon->wm_instance);

  if (aicon->wm_class)
    wfree(aicon->wm_class);

  remove_from_appicon_list(scr, aicon);

  aicon->flags.destroyed = 1;
  wrelease(aicon);
}

static void drawCorner(WIcon *icon)
{
  WScreen *scr = icon->core->screen_ptr;
  XPoint points[3];

  points[0].x = 1;
  points[0].y = 1;
  points[1].x = 12;
  points[1].y = 1;
  points[2].x = 1;
  points[2].y = 12;
  XFillPolygon(dpy, icon->core->window, scr->icon_title_texture->normal_gc, points, 3, Convex,
               CoordModeOrigin);
  XDrawLine(dpy, icon->core->window, scr->icon_title_texture->light_gc, 0, 0, 0, 12);
  XDrawLine(dpy, icon->core->window, scr->icon_title_texture->light_gc, 0, 0, 12, 0);
}

void wAppIconMove(WAppIcon *aicon, int x, int y)
{
  XMoveWindow(dpy, aicon->icon->core->window, x, y);
  aicon->x_pos = x;
  aicon->y_pos = y;
}

void wAppIconPaint(WAppIcon *aicon)
{
  WApplication *wapp;
  WScreen *scr = aicon->icon->core->screen_ptr;

  if (aicon->icon->owner) {
    wapp = wApplicationOf(aicon->icon->owner->main_window);
  } else {
    wapp = NULL;
  }

  wIconPaint(aicon->icon);

  if (aicon->flags.docked && !aicon->flags.running && aicon->command != NULL &&
      aicon->yindex != 0) {
    XSetClipMask(dpy, scr->copy_gc, scr->dock_dots->mask);
    XSetClipOrigin(dpy, scr->copy_gc, 0, 0);
    XCopyArea(dpy, scr->dock_dots->image, aicon->icon->core->window, scr->copy_gc, 0, 0,
              scr->dock_dots->width, scr->dock_dots->height, 0, 0);
  }
#ifdef HIDDENDOT
  if (wapp && wapp->flags.hidden) {
    XSetClipMask(dpy, scr->copy_gc, scr->dock_dots->mask);
    XSetClipOrigin(dpy, scr->copy_gc, 0, 0);
    XCopyArea(dpy, scr->dock_dots->image, aicon->icon->core->window, scr->copy_gc, 0, 0, 7,
              scr->dock_dots->height, 0, 0);
  }
#endif /* HIDDENDOT */

  if (aicon->flags.omnipresent) {
    drawCorner(aicon->icon);
  }

  XSetClipMask(dpy, scr->copy_gc, None);
  if (aicon->flags.launching && !aicon->flags.running) {
    XFillRectangle(dpy, aicon->icon->core->window, scr->stipple_gc, 0, 0, wPreferences.icon_size,
                   wPreferences.icon_size);
  }
}

/* Save the application icon, if it's a dockapp then use it with dock = True */
void save_appicon(WAppIcon *aicon, Bool dock)
{
  char *path;

  if (!aicon)
    return;

  if (dock && (!aicon->flags.docked || aicon->flags.attracted))
    return;

  path = wIconStore(aicon->icon);
  if (!path)
    return;

  wApplicationSaveIconPathFor(path, aicon->wm_instance, aicon->wm_class);
  wfree(path);
}

#define canBeDocked(wwin) ((wwin) && ((wwin)->wm_class || (wwin)->wm_instance))

static void openApplicationMenu(WApplication *wapp, int x, int y)
{
  WMenu *menu = wapp->app_menu->brother;

  x -= MENU_WIDTH(menu) / 2;
  if (x < 0) {
    x = 0;
  }

  /* mouse pointer will be located at the middle of titlebar */
  y -= menu->frame->titlebar->height / 2;
  if (y < 0) {
    y = 0;
  }

  wMenuMapAt(menu, x, y, False);
}

/******************************************************************/

static void iconExpose(WObjDescriptor *desc, XEvent *event) { wAppIconPaint(desc->parent); }

static void relaunchApplication(WApplication *wapp)
{
  WScreen *scr;
  WWindow *wlist, *next;

  scr = wapp->main_wwin->screen;
  wlist = scr->focused_window;
  if (!wlist)
    return;

  while (wlist->prev)
    wlist = wlist->prev;

  while (wlist) {
    next = wlist->next;

    if (wlist->main_window == wapp->main_window) {
      if (wRelaunchWindow(wlist))
        return;
    }

    wlist = next;
  }
}

static void iconDblClick(WObjDescriptor *desc, XEvent *event)
{
  WAppIcon *aicon = desc->parent;
  WApplication *wapp;
  WScreen *scr = aicon->icon->core->screen_ptr;
  int unhideHere;

  assert(aicon->icon->owner != NULL);

  wapp = wApplicationOf(aicon->icon->owner->main_window);

  if (event->xbutton.state & ControlMask) {
    relaunchApplication(wapp);
    return;
  }

  unhideHere = (event->xbutton.state & ShiftMask);
  /* go to the last workspace that the user worked on the app */
  if (!unhideHere && wapp->last_desktop != scr->current_desktop) {
    wApplicationActivate(wapp);
  }

  wUnhideApplication(wapp, event->xbutton.button == Button2, unhideHere);

  if (event->xbutton.state & ALT_MOD_MASK)
    wApplicationHideOthers(aicon->icon->owner);
}

void appIconMouseDown(WObjDescriptor *desc, XEvent *event)
{
  WAppIcon *aicon = desc->parent;
  WScreen *scr = aicon->icon->core->screen_ptr;
  Bool hasMoved;

  WMLogInfo("[appicon.c] Appicon Mouse Down\n");

  if (aicon->flags.editing || WCHECK_STATE(WSTATE_MODAL))
    return;

  if (IsDoubleClick(scr, event)) {
    /* Middle or right mouse actions were handled on first click */
    WMLogInfo("[appicon.c] Appicon Double-click\n");
    if (event->xbutton.button == Button1)
      iconDblClick(desc, event);
    return;
  }

  if (event->xbutton.button == Button2) {
    WApplication *wapp = wApplicationOf(aicon->icon->owner->main_window);

    if (wapp)
      relaunchApplication(wapp);

    return;
  }

  if (event->xbutton.button == Button3) {
    WObjDescriptor *desc;
    WApplication *wapp = wApplicationOf(aicon->icon->owner->main_window);

    if (!wapp)
      return;

    if (event->xbutton.send_event &&
        XGrabPointer(dpy, aicon->icon->core->window, True,
                     ButtonMotionMask | ButtonReleaseMask | ButtonPressMask, GrabModeAsync,
                     GrabModeAsync, None, None, CurrentTime) != GrabSuccess) {
      WMLogWarning("pointer grab failed for appicon menu");
      return;
    }

    openApplicationMenu(wapp, event->xbutton.x_root, event->xbutton.y_root);

    /* allow drag select of menu */
    /* desc = &scr->icon_menu->menu->descriptor; */
    desc = &wapp->app_menu->brother->menu->descriptor;
    event->xbutton.send_event = True;
    (*desc->handle_mousedown)(desc, event);
    return;
  }

  hasMoved = wHandleAppIconMove(aicon, event);
  if (wPreferences.single_click && !hasMoved && aicon->dock != NULL) {
    iconDblClick(desc, event);
  }
}

Bool wHandleAppIconMove(WAppIcon *aicon, XEvent *event)
{
  WIcon *icon = aicon->icon;
  WScreen *scr = icon->core->screen_ptr;
  WDock *originalDock = aicon->dock; /* can be NULL */
  WDock *lastDock = originalDock;
  WDock *allDocks[scr->drawer_count + 2]; /* clip, dock and drawers (order determined at runtime) */
  WDrawerChain *dc;
  Bool dockable, ondock;
  Bool grabbed = False;
  Bool collapsed =
      False; /* Stores the collapsed state of lastDock, before the moving appicon entered it */
  int superfluous = wPreferences.superfluous; /* we cache it to avoid problems */
  int omnipresent = aicon->flags.omnipresent; /* this must be cached */
  Bool showed_all_clips = False;

  int clickButton = event->xbutton.button;
  Pixmap ghost = None;
  Window wins[2]; /* Managing shadow window */
  XEvent ev;

  int x = aicon->x_pos, y = aicon->y_pos;
  int ofs_x = event->xbutton.x, ofs_y = event->xbutton.y;
  int shad_x = x, shad_y = y;
  int ix = aicon->xindex, iy = aicon->yindex;
  int i;
  int oldX = x;
  int oldY = y;
  Bool hasMoved = False;

  if (wPreferences.flags.noupdates && originalDock != NULL)
    return False;

  // If icon is docked, Dock raises in iconMouseDown()(dock.c)
  if (!aicon->flags.docked) {
    wRaiseFrame(icon->core);
  }
  /* if (!(event->xbutton.state & ALT_MOD_MASK)) */
  /* wRaiseFrame(icon->core); */
  /* else { */
  /* If Mod is pressed for an docked appicon, assume it is to undock it,
   * so don't lower it */
  /* 	if (originalDock == NULL) */
  /* 		wLowerFrame(icon->core); */
  /* } */

  if (XGrabPointer(dpy, icon->core->window, True,
                   ButtonMotionMask | ButtonReleaseMask | ButtonPressMask, GrabModeAsync,
                   GrabModeAsync, None, None, CurrentTime) != GrabSuccess) {
    WMLogWarning("Pointer grab failed in wHandleAppIconMove");
  }

  if (originalDock != NULL) {
    dockable = True;
    ondock = True;
  } else {
    ondock = False;
    if (wPreferences.flags.nodock && wPreferences.flags.noclip && wPreferences.flags.nodrawer)
      dockable = 0;
    else
      dockable = canBeDocked(icon->owner);
  }

  /* We try the various docks in that order:
   * - First, the dock the appicon comes from, if any
   * - Then, the drawers
   * - Then, the "dock" (WM_DOCK)
   * - Finally, the clip
   */
  i = 0;
  if (originalDock != NULL)
    allDocks[i++] = originalDock;
  /* Testing scr->drawers is enough, no need to test wPreferences.flags.nodrawer */
  for (dc = scr->drawers; dc != NULL; dc = dc->next) {
    if (dc->adrawer != originalDock)
      allDocks[i++] = dc->adrawer;
  }
  if (!wPreferences.flags.nodock && scr->dock != originalDock)
    allDocks[i++] = scr->dock;

  if (!wPreferences.flags.noclip && originalDock != scr->desktops[scr->current_desktop]->clip)
    allDocks[i++] = scr->desktops[scr->current_desktop]->clip;

  for (; i < scr->drawer_count + 2; i++) /* In case the clip, the dock, or both, are disabled */
    allDocks[i] = NULL;

  wins[0] = icon->core->window;
  wins[1] = scr->dock_shadow;
  XRestackWindows(dpy, wins, 2);
  XMoveResizeWindow(dpy, scr->dock_shadow, aicon->x_pos, aicon->y_pos, ICON_SIZE, ICON_SIZE);
  if (superfluous) {
    if (icon->pixmap != None)
      ghost = MakeGhostIcon(scr, icon->pixmap);
    else
      ghost = MakeGhostIcon(scr, icon->core->window);
    XSetWindowBackgroundPixmap(dpy, scr->dock_shadow, ghost);
    XClearWindow(dpy, scr->dock_shadow);
  }
  if (ondock)
    XMapWindow(dpy, scr->dock_shadow);

  while (1) {
    WMMaskEvent(dpy,
                PointerMotionMask | ButtonReleaseMask | ButtonPressMask | ButtonMotionMask |
                    ExposureMask | EnterWindowMask,
                &ev);
    switch (ev.type) {
      case Expose:
        WMHandleEvent(&ev);
        break;

      case EnterNotify:
        /* It means the cursor moved so fast that it entered
         * something else (if moving slowly, it would have
         * stayed in the appIcon that is being moved. Ignore
         * such "spurious" EnterNotifiy's */
        break;

      case MotionNotify:
        hasMoved = True;
        if (!grabbed) {
          if (abs(ofs_x - ev.xmotion.x) >= MOVE_THRESHOLD ||
              abs(ofs_y - ev.xmotion.y) >= MOVE_THRESHOLD) {
            XChangeActivePointerGrab(dpy, ButtonMotionMask | ButtonReleaseMask | ButtonPressMask,
                                     wPreferences.cursor[WCUR_MOVE], CurrentTime);
            grabbed = 1;
          } else {
            break;
          }
        }

        if (omnipresent && !showed_all_clips) {
          int i;
          for (i = 0; i < scr->desktop_count; i++) {
            if (i == scr->current_desktop)
              continue;

            wDockShowIcons(scr->desktops[i]->clip);
            /* Note: if dock is collapsed (for instance, because it
               auto-collapses), its icons still won't show up */
          }
          showed_all_clips = True; /* To prevent flickering */
        }

        x = ev.xmotion.x_root - ofs_x;
        y = ev.xmotion.y_root - ofs_y;
        wAppIconMove(aicon, x, y);

        WDock *theNewDock = NULL;
        if (!(ev.xmotion.state & ALT_MOD_MASK) || aicon->flags.launching || aicon->flags.lock ||
            originalDock == NULL) {
          for (i = 0; dockable && i < scr->drawer_count + 2; i++) {
            WDock *theDock = allDocks[i];
            if (theDock == NULL)
              break;
            if (wDockSnapIcon(theDock, aicon, x, y, &ix, &iy, (theDock == originalDock))) {
              theNewDock = theDock;
              break;
            }
          }
          /* In those cases, stay in lastDock if no dock really wants us */
          /* if (originalDock != NULL && theNewDock == NULL && */
          /*     (aicon->launching || aicon->lock || aicon->running)) { */
          if (originalDock != NULL && theNewDock == NULL &&
              (aicon->flags.launching || aicon->flags.lock)) {
            theNewDock = lastDock;
          }
        }
        if (lastDock != NULL && lastDock != theNewDock) {
          /* Leave lastDock in the state we found it */
          if (lastDock->type == WM_DRAWER) {
            wDrawerFillTheGap(lastDock, aicon, (lastDock == originalDock));
          }
          if (collapsed) {
            lastDock->collapsed = 1;
            wDockHideIcons(lastDock);
            collapsed = False;
          }
          if (lastDock->auto_raise_lower) {
            wDockLower(lastDock);
          }
        }
        if (theNewDock != NULL) {
          if (lastDock != theNewDock) {
            collapsed = theNewDock->collapsed;
            if (collapsed) {
              theNewDock->collapsed = 0;
              wDockShowIcons(theNewDock);
            }
            if (theNewDock->auto_raise_lower) {
              wDockRaise(theNewDock);
              /* And raise the moving tile above it */
              wRaiseFrame(aicon->icon->core);
            }
            lastDock = theNewDock;
          }

          shad_x = lastDock->x_pos + ix * wPreferences.icon_size;
          shad_y = lastDock->y_pos + iy * wPreferences.icon_size;

          XMoveWindow(dpy, scr->dock_shadow, shad_x, shad_y);

          if (!ondock) {
            XMapWindow(dpy, scr->dock_shadow);
          }
          ondock = 1;
        } else {
          lastDock = theNewDock;  // i.e., NULL
          if (ondock) {
            XUnmapWindow(dpy, scr->dock_shadow);
            /*
             * Leaving that weird comment for now.
             * But if we see no gap, there is no need to fill one!
             * We could test ondock first and the lastDock to NULL afterwards
             if (lastDock_before_it_was_null->type == WM_DRAWER) {
             wDrawerFillTheGap(lastDock, aicon, (lastDock == originalDock));
             } */
          }
          ondock = 0;
        }
        break;

      case ButtonPress:
        break;

      case ButtonRelease:
        if (ev.xbutton.button != clickButton)
          break;
        XUngrabPointer(dpy, CurrentTime);

        Bool docked = False;
        if (ondock) {
          wSlideWindow(icon->core->window, x, y, shad_x, shad_y);
          XUnmapWindow(dpy, scr->dock_shadow);
          if (originalDock == NULL) {  // docking an undocked appicon
            docked = wDockAttachIcon(lastDock, aicon, ix, iy, False);
            if (!docked) {
              /* AppIcon got rejected (happens only when we can't get the
                 command for that appicon, and the user cancels the
                 wInputDialog asking for one). Make the rejection obvious by
                 sliding the icon to its old position */
              if (lastDock->type == WM_DRAWER) {
                // Also fill the gap left in the drawer
                wDrawerFillTheGap(lastDock, aicon, False);
              }
              wSlideWindow(icon->core->window, x, y, oldX, oldY);
            }
          } else {  // moving a docked appicon to a dock
            if (originalDock == lastDock) {
              docked = True;
              wDockReattachIcon(originalDock, aicon, ix, iy);
            } else {
              docked = wDockMoveIconBetweenDocks(originalDock, lastDock, aicon, ix, iy);
              if (!docked) {
                /* Possible scenario: user moved an auto-attracted appicon
                   from the clip to the dock, and cancelled the wInputDialog
                   asking for a command */
                if (lastDock->type == WM_DRAWER) {
                  wDrawerFillTheGap(lastDock, aicon, False);
                }
                /* If aicon comes from a drawer, make some room to reattach it */
                if (originalDock->type == WM_DRAWER) {
                  WAppIcon *aiconsToShift[originalDock->icon_count];
                  int j = 0;

                  for (i = 0; i < originalDock->max_icons; i++) {
                    WAppIcon *ai = originalDock->icon_array[i];
                    if (ai && ai != aicon && abs(ai->xindex) >= abs(aicon->xindex))
                      aiconsToShift[j++] = ai;
                  }
                  if (j != originalDock->icon_count - abs(aicon->xindex) - 1)
                    // Trust this never happens?
                    WMLogWarning(
                        "Shifting j=%d appicons (instead of %d!) to reinsert aicon at index %d.", j,
                        originalDock->icon_count - abs(aicon->xindex) - 1, aicon->xindex);
                  wSlideAppicons(aiconsToShift, j, originalDock->on_right_side);
                  // Trust the appicon is inserted at exactly the same place, so its oldX/oldY are
                  // consistent with its "new" location?
                }

                wSlideWindow(icon->core->window, x, y, oldX, oldY);
                wDockReattachIcon(originalDock, aicon, aicon->xindex, aicon->yindex);
              } else {
                if (originalDock->auto_collapse && !originalDock->collapsed) {
                  originalDock->collapsed = 1;
                  wDockHideIcons(originalDock);
                }
                if (originalDock->auto_raise_lower)
                  wDockLower(originalDock);
              }
            }
          }
          // No matter what happened above, check to lower lastDock
          // Don't see why I commented out the following 2 lines
          /* if (lastDock->auto_raise_lower)
             wDockLower(lastDock); */
          /* If docked (or tried to dock) to a auto_collapsing dock, unset
           * collapsed, so that wHandleAppIconMove doesn't collapse it
           * right away (the timer will take care of it) */
          if (lastDock->auto_collapse)
            collapsed = 0;
        } else if (originalDock != NULL) { /* Detaching a docked appicon */
          if (superfluous) {
            if (!aicon->flags.running) {
              if (!wPreferences.no_animations) {
                /* We need to deselect it, even if is deselected in
                 * wDockDetach(), because else DoKaboom() will fail.
                 */
                if (aicon->icon->selected) {
                  wIconSelect(aicon->icon);
                }
                DoKaboom(scr, aicon->icon->core->window, x, y);
              }
            } else {
              // Move running appicon to Icon Yard
              int x1, y1;
              PlaceIcon(scr, &x1, &y1, wGetHeadForWindow(icon->owner));
              wSlideWindow(icon->core->window, x, y, x1, y1);
              wAppIconMove(aicon, x1, y1);
            }
          }
          wDockDetach(originalDock, aicon);
          if (originalDock->auto_collapse && !originalDock->collapsed) {
            originalDock->collapsed = 1;
            wDockHideIcons(originalDock);
          }
          if (originalDock->auto_raise_lower) {
            wDockLower(originalDock);
          }
        } else {
          wSlideWindow(icon->core->window, x, y, oldX, oldY);
          wAppIconMove(aicon, oldX, oldY);
        }

        // Can't remember why the icon hiding is better done above than below (commented out)
        // Also, lastDock is quite different from originalDock
        /*
          if (collapsed) {
          lastDock->collapsed = 1;
          wDockHideIcons(lastDock);
          collapsed = 0;
          }
        */
        if (superfluous) {
          if (ghost != None) {
            XFreePixmap(dpy, ghost);
          }
          XSetWindowBackground(dpy, scr->dock_shadow, scr->white_pixel);
        }
        if (showed_all_clips) {
          int i;
          for (i = 0; i < scr->desktop_count; i++) {
            if (i == scr->current_desktop) {
              continue;
            }
            wDockHideIcons(scr->desktops[i]->clip);
          }
        }
        /* Need to rearrange unless moving from dock to dock */
        if (wPreferences.auto_arrange_icons && !(originalDock != NULL && docked)) {
          wArrangeIcons(scr, True);
        }
        return hasMoved;
    }
  }
}

/* This function save the application icon and store the path in the Dictionary */
static void wApplicationSaveIconPathFor(const char *iconPath, const char *wm_instance,
                                        const char *wm_class)
{
  CFMutableDictionaryRef dict = w_global.domain.window_attrs->dictionary;
  CFMutableDictionaryRef adict = NULL;
  CFTypeRef val;
  CFStringRef key;
  CFStringRef iconkey;
  char *tmp;

  if (!dict) {
    WMLogError(_("cannot save appicon to a NULL WMWindowAttributes"));
    return;
  }

  iconkey = CFStringCreateWithCString(kCFAllocatorDefault, "Icon", kCFStringEncodingUTF8);

  tmp = get_name_for_instance_class(wm_instance, wm_class);
  key = CFStringCreateWithCString(kCFAllocatorDefault, tmp, kCFStringEncodingUTF8);
  wfree(tmp);

  val = CFDictionaryGetValue(dict, key);
  if (val && (CFGetTypeID(val) == CFDictionaryGetTypeID())) {
    adict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, (CFDictionaryRef)val);
  }

  if (adict) {
    val = CFDictionaryGetValue(adict, iconkey);
    CFRetain(val);
  } else {
    /* no dictionary for app, so create one */
    adict = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
    val = CFStringCreateWithCString(kCFAllocatorDefault, iconPath, kCFStringEncodingUTF8);
    CFDictionarySetValue(adict, iconkey, val);
  }

  if (adict) {
    CFDictionarySetValue(dict, key, adict);
  }

  if (val && !wPreferences.flags.noupdates) {
    WMUserDefaultsWrite(w_global.domain.window_attrs->dictionary, w_global.domain.window_attrs->name);
  }

  if (adict) {
    CFRelease(adict);
  }
  CFRelease(val);
  CFRelease(iconkey);
  CFRelease(key);
}

static WAppIcon *findDockIconFor(WDock *dock, Window main_window)
{
  WAppIcon *aicon = NULL;

  aicon = wDockFindIconForWindow(dock, main_window);
  if (!aicon) {
    wDockTrackWindowLaunch(dock, main_window);
    aicon = wDockFindIconForWindow(dock, main_window);
  }
  return aicon;
}

static void create_appicon_from_dock(WWindow *wwin, WApplication *wapp, Window main_window)
{
  WScreen *scr = wwin->screen;
  wapp->app_icon = NULL;

  if (scr->last_dock)
    wapp->app_icon = findDockIconFor(scr->last_dock, main_window);

  /* check main dock if we did not find it in last dock */
  if (!wapp->app_icon && scr->dock)
    wapp->app_icon = findDockIconFor(scr->dock, main_window);

  /* check clips */
  if (!wapp->app_icon) {
    int i;
    for (i = 0; i < scr->desktop_count; i++) {
      WDock *dock = scr->desktops[i]->clip;

      if (dock)
        wapp->app_icon = findDockIconFor(dock, main_window);

      if (wapp->app_icon)
        break;
    }
  }

  /* Finally check drawers */
  if (!wapp->app_icon) {
    WDrawerChain *dc;
    for (dc = scr->drawers; dc != NULL; dc = dc->next) {
      wapp->app_icon = findDockIconFor(dc->adrawer, main_window);
      if (wapp->app_icon)
        break;
    }
  }

  /* If created, then set some flags */
  if (wapp->app_icon) {
    WWindow *mainw = wapp->main_wwin;

    wapp->app_icon->flags.running = 1;
    wapp->app_icon->icon->owner = mainw;
    if (mainw->wm_hints && (mainw->wm_hints->flags & IconWindowHint))
      wapp->app_icon->icon->icon_win = mainw->wm_hints->icon_window;

    /* Update the icon images */
    wIconUpdate(wapp->app_icon->icon);

    /* Paint it */
    wAppIconPaint(wapp->app_icon);
    save_appicon(wapp->app_icon, True);
  }
}

/* Add the appicon to the appiconlist */
static void add_to_appicon_list(WScreen *scr, WAppIcon *appicon)
{
  appicon->prev = NULL;
  appicon->next = scr->app_icon_list;
  if (scr->app_icon_list)
    scr->app_icon_list->prev = appicon;

  scr->app_icon_list = appicon;
}

/* Remove the appicon from the appiconlist */
static void remove_from_appicon_list(WScreen *scr, WAppIcon *appicon)
{
  if (appicon == scr->app_icon_list) {
    if (appicon->next)
      appicon->next->prev = NULL;
    scr->app_icon_list = appicon->next;
  } else {
    if (appicon->next)
      appicon->next->prev = appicon->prev;
    if (appicon->prev)
      appicon->prev->next = appicon->next;
  }

  appicon->prev = NULL;
  appicon->next = NULL;
}

/* Return the AppIcon associated with a given (Xlib) Window. */
WAppIcon *wAppIconFor(Window window)
{
  WObjDescriptor *desc;

  if (window == None)
    return NULL;

  if (XFindContext(dpy, window, w_global.context.client_win, (XPointer *)&desc) == XCNOENT)
    return NULL;

  if (desc->parent_type == WCLASS_APPICON || desc->parent_type == WCLASS_DOCK_ICON)
    return desc->parent;

  return NULL;
}

// ----------------------------
// --- Launching appicons
// ----------------------------
// It is array of pointers to WAppIcon.
// These pointers also placed into WScreen->app_icon_list.
// Launching icons number is much smaller, but I use DOCK_MAX_ICONS as references number.
static Window _createIconForSliding(WScreen *scr, int x, int y, const char *image_path)
{
  int vmask = CWBackPixel | CWSaveUnder | CWOverrideRedirect | CWColormap | CWBorderPixel;
  XSetWindowAttributes attribs;
  Window image_win;
  RImage *rimage = NULL;
  Pixmap pixmap = 0, mask = 0;

  if (image_path == NULL) {
    WMLogInfo("[appicon.c] _createIconForSliding Could not create image. No image path specified.");
  }

  // Window
  attribs.save_under = True;
  attribs.override_redirect = True;
  attribs.colormap = scr->w_colormap;
  attribs.background_pixel = scr->icon_back_texture->normal.pixel;
  attribs.border_pixel = 0; /* do not care */

  image_win = XCreateWindow(dpy, scr->root_win, x, x, MAX_ICON_HEIGHT, MAX_ICON_HEIGHT, 0,
                            scr->w_depth, CopyFromParent, scr->w_visual, vmask, &attribs);

  // Image
  // rimage = RLoadImage(scr->rcontext, image_path, 0);
  rimage = WSLoadRasterImage(image_path);
  if (!rimage) {
    image_path = WMAbsolutePathForFile(wPreferences.image_paths, "NXApplication.tiff");
    // rimage = RLoadImage(scr->rcontext, image_path, 0);
    rimage = WSLoadRasterImage(image_path);
  }
  if (rimage) {
    RConvertImageMask(scr->rcontext, rimage, &pixmap, &mask, 158);
    RReleaseImage(rimage);
    if (pixmap && mask) {
      XSetWindowBackgroundPixmap(dpy, image_win, pixmap);
      XShapeCombineMask(dpy, image_win, ShapeBounding, 0, 0, mask, ShapeSet);
      XFreePixmap(dpy, pixmap);
      XFreePixmap(dpy, mask);
    } else {
      WMLogInfo("[appicon.c] _createIconForSliding Failed to load image at path: %s", image_path);
    }
  } else {
    WMLogInfo("[appicon.c] _createIconForSliding Failed to load image at path: %s", image_path);
  }

  XClearWindow(dpy, image_win);

  return image_win;
}

WAppIcon *wLaunchingAppIconCreate(const char *wm_instance, const char *wm_class,
                                  const char *launch_path, int x0, int y0, const char *image_path)
{
  int x1, y1;
  Boolean iconFound = false;
  WScreen *scr = wDefaultScreen();
  WAppIcon *app_icon = NULL;
  Window icon_window;

  if (wm_instance == NULL || wm_class == NULL || image_path == NULL) {
    // Can't create launching icon without application name and icon path
    return NULL;
  }

  // 0. Create icon window
  icon_window = _createIconForSliding(scr, x0, y0, image_path);
  // Convert OpenStep to X11
  y0 = scr->height - y0 - MAX_ICON_HEIGHT;
  XMoveWindow(dpy, icon_window, x0, y0);
  XMapRaised(dpy, icon_window);
  XFlush(dpy);

  // 1. Search for existing icon in IconYard and Dock
  app_icon = scr->app_icon_list;
  while (app_icon->next) {
    if (!strcmp(app_icon->wm_instance, wm_instance) && !strcmp(app_icon->wm_class, wm_class)) {
      x1 = app_icon->x_pos + (ICON_WIDTH - MAX_ICON_WIDTH) / 2 + 6;
      y1 = app_icon->y_pos + (ICON_HEIGHT - MAX_ICON_HEIGHT) / 2;

      wSlideWindow(icon_window, x0, y0, x1, y1);

      if (app_icon->flags.docked && !app_icon->flags.running) {
        app_icon->flags.launching = 1;
        wAppIconPaint(app_icon);
      }
      iconFound = true;
      break;
    }
    app_icon = app_icon->next;
  }

  // 2. Otherwise create appicon and set its state to launching
  if (iconFound == false) {
    app_icon =
        wAppIconCreateForDock(scr, launch_path, (char *)wm_instance, (char *)wm_class, TILE_NORMAL);
    CFArrayAppendValue(scr->launching_icons, app_icon);
    RemoveFromStackList(app_icon->icon->core);
    app_icon->icon->core->descriptor.handle_mousedown = NULL;
    app_icon->flags.launching = 1;
    if (image_path != NULL && strlen(image_path) > 0) {
      wIconChangeImageFile(app_icon->icon, image_path);
    }

    // Calculate postion for new launch icon
    PlaceIcon(scr, &x1, &y1, scr->xrandr_info.primary_head);
    wAppIconMove(app_icon, x1, y1);

    // Slide
    x1 += (ICON_HEIGHT - MAX_ICON_HEIGHT) / 2;
    y1 += (ICON_HEIGHT - MAX_ICON_HEIGHT) / 2;
    wSlideWindow(icon_window, x0, y0, x1, y1);

    // Draw launching appicon
    wAppIconPaint(app_icon);
    XMapWindow(dpy, app_icon->icon->core->window);

    XSync(dpy, False);
  }

  // Remove temporary icon
  XUnmapWindow(dpy, icon_window);
  XDestroyWindow(dpy, icon_window);

  return app_icon;
}

void wLaunchingAppIconFinish(WScreen *scr, WAppIcon *appicon)
{
  CFIndex index, count;

  count = CFArrayGetCount(scr->launching_icons);
  index = CFArrayGetFirstIndexOfValue(scr->launching_icons, CFRangeMake(0, count), appicon);

  if (index != kCFNotFound) {
    CFArrayRemoveValueAtIndex(scr->launching_icons, index);
    AddToStackList(appicon->icon->core);
    appicon->flags.launching = 0;
    wAppIconPaint(appicon);
  }
}

void wLaunchingAppIconDestroy(WScreen *scr, WAppIcon *appicon)
{
  wLaunchingAppIconFinish(scr, appicon);
  wAppIconDestroy(appicon);
}

WAppIcon *wLaunchingAppIconForInstance(WScreen *scr, char *wm_instance, char *wm_class)
{
  CFIndex count;
  WAppIcon *aicon = NULL;

  if (scr->launching_icons != NULL) {
    count = CFArrayGetCount(scr->launching_icons);
    for (CFIndex i = 0; i < count; i++) {
      aicon = (WAppIcon *)CFArrayGetValueAtIndex(scr->launching_icons, i);
      if (aicon && !strcmp(wm_instance, aicon->wm_instance) && !strcmp(wm_class, aicon->wm_class)) {
        break;
      }
    }
  }
  return aicon;
}

WAppIcon *wLaunchingAppIconForApplication(WScreen *scr, WApplication *wapp)
{
  WAppIcon *aicon;
  WWindow *main_window = wapp->main_wwin;

  aicon = wLaunchingAppIconForInstance(scr, main_window->wm_instance, main_window->wm_class);
  if (!aicon) {
    return NULL;
  }

  aicon->icon->owner = main_window;

  if (main_window->wm_hints && (main_window->wm_hints->flags & IconWindowHint)) {
    aicon->icon->icon_win = main_window->wm_hints->icon_window;
  }

  wIconUpdate(aicon->icon);
  wIconPaint(aicon->icon);

  return aicon;
}

WAppIcon *wLaunchingAppIconForCommand(WScreen *scr, char *command)
{
  CFIndex count;
  WAppIcon *aicon = NULL;

  if (scr->launching_icons != NULL) {
    count = CFArrayGetCount(scr->launching_icons);
    for (CFIndex i = 0; i < count; i++) {
      aicon = (WAppIcon *)CFArrayGetValueAtIndex(scr->launching_icons, i);
      if (aicon->command && !strcmp(command, aicon->command)) {
        break;
      }
    }
  }

  return aicon;
}
