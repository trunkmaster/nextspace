/* dock.c- built-in Dock module for WindowMaker
 *
 *  Window Maker window manager
 *
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

#include "wconfig.h"

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

#ifndef PATH_MAX
#define PATH_MAX DEFAULT_PATH_MAX
#endif

#include "WindowMaker.h"
#include "wcore.h"
#include "window.h"
#include "icon.h"
#include "appicon.h"
#include "actions.h"
#include "stacking.h"
#include "dock.h"
#include "dockedapp.h"
#include "dialog.h"
#include "main.h"
#include "properties.h"
#include "menu.h"
#include "client.h"
#include "defaults.h"
#include "workspace.h"
#include "framewin.h"
#include "superfluous.h"
#include "xinerama.h"
#include "placement.h"
#include "misc.h"
#include "event.h"

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

static WMPropList *dCommand = NULL;
static WMPropList *dPasteCommand = NULL;
#ifdef USE_DOCK_XDND
static WMPropList *dDropCommand = NULL;
#endif
static WMPropList *dAutoLaunch, *dLock;
static WMPropList *dName, *dForced, *dBuggyApplication, *dYes, *dNo;
static WMPropList *dHost, *dDock, *dClip;
static WMPropList *dAutoAttractIcons;

static WMPropList *dPosition, *dApplications, *dLowered, *dCollapsed;

static WMPropList *dAutoCollapse, *dAutoRaiseLower, *dOmnipresent;

static WMPropList *dDrawers = NULL;

static void dockIconPaint(WAppIcon *btn);

static void iconMouseDown(WObjDescriptor *desc, XEvent *event);

static pid_t execCommand(WAppIcon *btn, const char *command, WSavedState *state);

static void trackDeadProcess(pid_t pid, unsigned char status, WDock *dock);

static int getClipButton(int px, int py);

static void toggleLowered(WDock *dock);

static void toggleCollapsed(WDock *dock);

static void clipIconExpose(WObjDescriptor *desc, XEvent *event);

static void clipLeave(WDock *dock);

static void handleClipChangeWorkspace(WScreen *scr, XEvent *event);

static void clipEnterNotify(WObjDescriptor *desc, XEvent *event);
static void clipLeaveNotify(WObjDescriptor *desc, XEvent *event);
static void clipAutoCollapse(void *cdata);
static void clipAutoExpand(void *cdata);
static void launchDockedApplication(WAppIcon *btn, Bool withSelection);

static void clipAutoLower(void *cdata);
static void clipAutoRaise(void *cdata);
static WAppIcon *mainIconCreate(WScreen *scr, int type, const char *name);

static void drawerIconExpose(WObjDescriptor *desc, XEvent *event);
static void removeDrawerCallback(WMenu *menu, WMenuEntry *entry);
static void drawerAppendToChain(WScreen *scr, WDock *drawer);
static char *findUniqueName(WScreen *scr, const char *instance_basename);
static void addADrawerCallback(WMenu *menu, WMenuEntry *entry);
static void swapDrawers(WScreen *scr, int new_x);
static WDock* getDrawer(WScreen *scr, int y_index);
static int indexOfHole(WDock *drawer, WAppIcon *moving_aicon, int redocking);
static void drawerConsolidateIcons(WDock *drawer);

static int onScreen(WScreen *scr, int x, int y);

static void make_keys(void)
{
  if (dCommand != NULL)
    return;

  dCommand = WMRetainPropList(WMCreatePLString("Command"));
  dPasteCommand = WMRetainPropList(WMCreatePLString("PasteCommand"));
#ifdef USE_DOCK_XDND
  dDropCommand = WMRetainPropList(WMCreatePLString("DropCommand"));
#endif
  dLock = WMRetainPropList(WMCreatePLString("Lock"));
  dAutoLaunch = WMRetainPropList(WMCreatePLString("AutoLaunch"));
  dName = WMRetainPropList(WMCreatePLString("Name"));
  dForced = WMRetainPropList(WMCreatePLString("Forced"));
  dBuggyApplication = WMRetainPropList(WMCreatePLString("BuggyApplication"));
  dYes = WMRetainPropList(WMCreatePLString("Yes"));
  dNo = WMRetainPropList(WMCreatePLString("No"));
  dHost = WMRetainPropList(WMCreatePLString("Host"));

  dPosition = WMCreatePLString("Position");
  dApplications = WMCreatePLString("Applications");
  dLowered = WMCreatePLString("Lowered");
  dCollapsed = WMCreatePLString("Collapsed");
  dAutoCollapse = WMCreatePLString("AutoCollapse");
  dAutoRaiseLower = WMCreatePLString("AutoRaiseLower");
  dAutoAttractIcons = WMCreatePLString("AutoAttractIcons");

  dOmnipresent = WMCreatePLString("Omnipresent");

  dDock = WMCreatePLString("Dock");
  dClip = WMCreatePLString("Clip");
  dDrawers = WMCreatePLString("Drawers");
}

static void renameCallback(WMenu *menu, WMenuEntry *entry)
{
  WDock *dock = entry->clientdata;
  char buffer[128];
  int wspace;
  char *name;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(entry->clientdata != NULL);

  wspace = dock->screen_ptr->current_workspace;

  name = wstrdup(dock->screen_ptr->workspaces[wspace]->name);

  snprintf(buffer, sizeof(buffer), _("Type the name for workspace %i:"), wspace + 1);
  if (wInputDialog(dock->screen_ptr, _("Rename Workspace"), buffer, &name))
    wWorkspaceRename(dock->screen_ptr, wspace, name);

  wfree(name);
}

static void toggleLoweredCallback(WMenu *menu, WMenuEntry *entry)
{
  assert(entry->clientdata != NULL);

  toggleLowered(entry->clientdata);

  entry->flags.indicator_on = !(((WDock *) entry->clientdata)->lowered);

  wMenuPaint(menu);
}

static int matchWindow(const void *item, const void *cdata)
{
  return (((WFakeGroupLeader *) item)->leader == (Window) cdata);
}

static void killCallback(WMenu *menu, WMenuEntry *entry)
{
  WScreen *scr = menu->menu->screen_ptr;
  WAppIcon *icon;
  WFakeGroupLeader *fPtr;
  char *buffer, *shortname, **argv;
  int argc;

  if (!WCHECK_STATE(WSTATE_NORMAL))
    return;

  assert(entry->clientdata != NULL);

  icon = (WAppIcon *) entry->clientdata;

  icon->editing = 1;

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
    Window win = icon->main_window;
    int index;

    index = WMFindInArray(scr->fakeGroupLeaders, matchWindow, (void *)win);
    if (index != WANotFound)
      fPtr = WMGetFromArray(scr->fakeGroupLeaders, index);
    else
      fPtr = NULL;
  }

  dispatch_async(workspace_q, ^{
      if (wPreferences.dont_confirm_kill
          || XWRunAlertPanel(_("Kill Application"),
                             buffer, _("Keep Running"), _("Kill"), NULL) == WAPRAlternate) {
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
      icon->editing = 0;
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

static WMArray *getSelected(WDock *dock)
{
  WMArray *ret = WMCreateArray(8);
  WAppIcon *btn;
  int i;

  for (i = 1; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];
    if (btn && btn->icon->selected)
      WMAddToArray(ret, btn);
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

static void omnipresentCallback(WMenu *menu, WMenuEntry *entry)
{
  WAppIcon *clickedIcon = entry->clientdata;
  WAppIcon *aicon;
  WDock *dock;
  WMArray *selectedIcons;
  WMArrayIterator iter;
  int failed;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(entry->clientdata != NULL);

  dock = clickedIcon->dock;

  selectedIcons = getSelected(dock);

  if (!WMGetArrayItemCount(selectedIcons))
    WMAddToArray(selectedIcons, clickedIcon);

  failed = 0;
  WM_ITERATE_ARRAY(selectedIcons, aicon, iter) {
    if (wClipMakeIconOmnipresent(aicon, !aicon->omnipresent) == WO_FAILED)
      failed++;
    else if (aicon->icon->selected)
      wIconSelect(aicon->icon);
  }
  WMFreeArray(selectedIcons);
  if (failed > 1) {
    wMessageDialog(dock->screen_ptr, _("Warning"),
                   _("Some icons cannot be made omnipresent. "
                     "Please make sure that no other icon is "
                     "docked in the same positions on the other "
                     "workspaces and the Clip is not full in "
                     "some workspace."), _("OK"), NULL, NULL);
  } else if (failed == 1) {
    wMessageDialog(dock->screen_ptr, _("Warning"),
                   _("Icon cannot be made omnipresent. "
                     "Please make sure that no other icon is "
                     "docked in the same position on the other "
                     "workspaces and the Clip is not full in "
                     "some workspace."), _("OK"), NULL, NULL);
  }
}

static void removeIcons(WMArray *icons, WDock *dock)
{
  WAppIcon *aicon;
  int keepit;
  WMArrayIterator it;

  WM_ITERATE_ARRAY(icons, aicon, it) {
    keepit = aicon->running && wApplicationOf(aicon->main_window);
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
  WMFreeArray(icons);

  if (wPreferences.auto_arrange_icons)
    wArrangeIcons(dock->screen_ptr, True);
}

static void removeIconsCallback(WMenu *menu, WMenuEntry *entry)
{
  WAppIcon *clickedIcon = (WAppIcon *) entry->clientdata;
  WDock *dock;
  WMArray *selectedIcons;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(clickedIcon != NULL);

  dock = clickedIcon->dock;

  selectedIcons = getSelected(dock);

  if (WMGetArrayItemCount(selectedIcons)) {
    if (wMessageDialog(dock->screen_ptr,
                       dock->type == WM_CLIP ? _("Workspace Clip") : _("Drawer"),
                       _("All selected icons will be removed!"),
                       _("OK"), _("Cancel"), NULL) != WAPRDefault) {
      WMFreeArray(selectedIcons);
      return;
    }
  } else {
    if (clickedIcon->xindex == 0 && clickedIcon->yindex == 0) {
      WMFreeArray(selectedIcons);
      return;
    }
    WMAddToArray(selectedIcons, clickedIcon);
  }

  removeIcons(selectedIcons, dock);

  if (dock->type == WM_DRAWER) {
    drawerConsolidateIcons(dock);
  }
}

static void keepIconsCallback(WMenu *menu, WMenuEntry *entry)
{
  WAppIcon *clickedIcon = (WAppIcon *) entry->clientdata;
  WDock *dock;
  WAppIcon *aicon;
  WMArray *selectedIcons;
  WMArrayIterator it;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(clickedIcon != NULL);
  dock = clickedIcon->dock;

  selectedIcons = getSelected(dock);

  if (!WMGetArrayItemCount(selectedIcons)
      && clickedIcon != dock->screen_ptr->clip_icon) {
    char *command = NULL;

    if (!clickedIcon->command && !clickedIcon->editing) {
      clickedIcon->editing = 1;
      if (wInputDialog(dock->screen_ptr, _("Keep Icon"),
                       _("Type the command used to launch the application"), &command)) {
        if (command && (command[0] == 0 || (command[0] == '-' && command[1] == 0))) {
          wfree(command);
          command = NULL;
        }
        clickedIcon->command = command;
        clickedIcon->editing = 0;
      } else {
        clickedIcon->editing = 0;
        if (command)
          wfree(command);
        WMFreeArray(selectedIcons);
        return;
      }
    }

    WMAddToArray(selectedIcons, clickedIcon);
  }

  WM_ITERATE_ARRAY(selectedIcons, aicon, it) {
    if (aicon->icon->selected)
      wIconSelect(aicon->icon);

    if (aicon->attracted && aicon->command) {
      aicon->attracted = 0;
      if (aicon->icon->shadowed) {
        aicon->icon->shadowed = 0;

        /*
         * Update icon pixmap, RImage doesn't change,
         * so call wIconUpdate is not needed
         */
        update_icon_pixmap(aicon->icon);

        /* Paint it */
        wAppIconPaint(aicon);
      }
    }
    save_appicon(aicon, True);
  }
  WMFreeArray(selectedIcons);
}

static void toggleAutoAttractCallback(WMenu *menu, WMenuEntry *entry)
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
        for (i = 0; i < scr->workspace_count; i++)
          scr->workspaces[ i ]->clip->attract_icons = False;
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

static void selectCallback(WMenu *menu, WMenuEntry *entry)
{
  WAppIcon *icon = (WAppIcon *) entry->clientdata;

  assert(icon != NULL);

  wIconSelect(icon->icon);

  wMenuPaint(menu);
}

static void attractIconsCallback(WMenu *menu, WMenuEntry *entry)
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
    if (!aicon->docked && wDockFindFreeSlot(clip, &x, &y)) {
      x_pos = clip->x_pos + x * ICON_SIZE;
      y_pos = clip->y_pos + y * ICON_SIZE;
      if (aicon->x_pos != x_pos || aicon->y_pos != y_pos)
        move_window(aicon->icon->core->window, aicon->x_pos, aicon->y_pos, x_pos, y_pos);

      aicon->attracted = 1;
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

static void selectIconsCallback(WMenu *menu, WMenuEntry *entry)
{
  WAppIcon *clickedIcon = (WAppIcon *) entry->clientdata;
  WDock *dock;
  WMArray *selectedIcons;
  WMArrayIterator iter;
  WAppIcon *btn;
  int i;

  assert(clickedIcon != NULL);
  dock = clickedIcon->dock;

  selectedIcons = getSelected(dock);

  if (!WMGetArrayItemCount(selectedIcons)) {
    for (i = 1; i < dock->max_icons; i++) {
      btn = dock->icon_array[i];
      if (btn && !btn->icon->selected)
        wIconSelect(btn->icon);
    }
  } else {
    WM_ITERATE_ARRAY(selectedIcons, btn, iter) {
      wIconSelect(btn->icon);
    }
  }
  WMFreeArray(selectedIcons);

  wMenuPaint(menu);
}

static void toggleCollapsedCallback(WMenu *menu, WMenuEntry *entry)
{
  assert(entry->clientdata != NULL);

  toggleCollapsed(entry->clientdata);

  entry->flags.indicator_on = ((WDock *) entry->clientdata)->collapsed;

  wMenuPaint(menu);
}

static void toggleAutoCollapseCallback(WMenu *menu, WMenuEntry *entry)
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

static void toggleAutoRaiseLowerCallback(WMenu *menu, WMenuEntry *entry)
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

static void launchCallback(WMenu *menu, WMenuEntry *entry)
{
  WAppIcon *btn = (WAppIcon *) entry->clientdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  launchDockedApplication(btn, False);
}
#ifndef NEXTSPACE
static void settingsCallback(WMenu *menu, WMenuEntry *entry)
{
  WAppIcon *btn = (WAppIcon *) entry->clientdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  if (btn->editing)
    return;
  ShowDockAppSettingsPanel(btn);
}
#endif
static void hideCallback(WMenu *menu, WMenuEntry *entry)
{
  WApplication *wapp;
  WAppIcon *btn = (WAppIcon *) entry->clientdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  wapp = wApplicationOf(btn->icon->owner->main_window);

  if (wapp->flags.hidden) {
    wWorkspaceChange(btn->icon->core->screen_ptr, wapp->last_workspace);
    wUnhideApplication(wapp, False, False);
  } else {
    wHideApplication(wapp);
  }
}

static void unhideHereCallback(WMenu *menu, WMenuEntry *entry)
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
    btn = wAppIconCreateForDock(scr, NULL, "Logo", "WMDock", TILE_NORMAL);
    if (wPreferences.flags.clip_merged_in_dock)
      btn->icon->core->descriptor.handle_expose = clipIconExpose;
    x_pos = scr->scr_width - ICON_SIZE - DOCK_EXTRA_SPACE;
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
  btn->docked = 1;
  if (type == WM_CLIP ||
      (type == WM_DOCK && wPreferences.flags.clip_merged_in_dock))
    scr->clip_icon = btn;

  return btn;
}

static void switchWSCommand(WMenu *menu, WMenuEntry *entry)
{
  WAppIcon *btn, *icon = (WAppIcon *) entry->clientdata;
  WScreen *scr = icon->icon->core->screen_ptr;
  WDock *src, *dest;
  WMArray *selectedIcons;
  int x, y;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  if (entry->order == scr->current_workspace)
    return;

  src = icon->dock;
  dest = scr->workspaces[entry->order]->clip;

  selectedIcons = getSelected(src);

  if (WMGetArrayItemCount(selectedIcons)) {
    WMArrayIterator iter;

    WM_ITERATE_ARRAY(selectedIcons, btn, iter) {
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
  WMFreeArray(selectedIcons);
}

static void launchDockedApplication(WAppIcon *btn, Bool withSelection)
{
  WScreen *scr = btn->icon->core->screen_ptr;

  if (!btn->launching &&
      ((!withSelection && btn->command != NULL) || (withSelection && btn->paste_command != NULL))) {
    if (!btn->forced_dock) {
      btn->relaunching = btn->running;
      btn->running = 1;
    }
    if (btn->wm_instance || btn->wm_class) {
      WWindowAttributes attr;
      memset(&attr, 0, sizeof(WWindowAttributes));
      wDefaultFillAttributes(btn->wm_instance, btn->wm_class, &attr, NULL, True);

      if (!attr.no_appicon && !btn->buggy_app)
        btn->launching = 1;
      else
        btn->running = 0;
    }
    btn->drop_launch = 0;
    btn->paste_launch = withSelection;
    scr->last_dock = btn->dock;
    btn->pid = execCommand(btn, (withSelection ? btn->paste_command : btn->command), NULL);
    if (btn->pid > 0) {
      if (btn->buggy_app) {
        /* give feedback that the app was launched */
        btn->launching = 1;
        dockIconPaint(btn);
        btn->launching = 0;
        WMAddTimerHandler(200, (WMCallback *) dockIconPaint, btn);
      } else {
        dockIconPaint(btn);
      }
    } else {
      wwarning(_("could not launch application %s"), btn->command);
      btn->launching = 0;
      if (!btn->relaunching)
        btn->running = 0;
    }
  }
}

static void updateWorkspaceMenu(WMenu *menu, WAppIcon *icon)
{
  WScreen *scr = menu->frame->screen_ptr;
  int i;

  if (!menu || !icon)
    return;

  for (i = 0; i < scr->workspace_count; i++) {
    if (i < menu->entry_no) {
      if (strcmp(menu->entries[i]->text, scr->workspaces[i]->name) != 0) {
        wfree(menu->entries[i]->text);
        menu->entries[i]->text = wstrdup(scr->workspaces[i]->name);
        menu->flags.realized = 0;
      }
      menu->entries[i]->clientdata = (void *)icon;
    } else {
      wMenuAddCallback(menu, scr->workspaces[i]->name, switchWSCommand, (void *)icon);

      menu->flags.realized = 0;
    }

    if (i == scr->current_workspace)
      wMenuSetEnabled(menu, i, False);
    else
      wMenuSetEnabled(menu, i, True);
  }

  if (!menu->flags.realized)
    wMenuRealize(menu);
}

static WMenu *makeWorkspaceMenu(WScreen *scr)
{
  WMenu *menu;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu)
    wwarning(_("could not create workspace submenu for Clip menu"));

  wMenuAddCallback(menu, "", switchWSCommand, (void *)scr->clip_icon);

  menu->flags.realized = 0;
  wMenuRealize(menu);

  return menu;
}

static void updateClipOptionsMenu(WMenu *menu, WDock *dock)
{
  WMenuEntry *entry;
  int index = 0;

  if (!menu || !dock)
    return;

  /* keep on top */
  entry = menu->entries[index];
  entry->flags.indicator_on = !dock->lowered;
  entry->clientdata = dock;
  wMenuSetEnabled(menu, index, dock->type == WM_CLIP);

  /* collapsed */
  entry = menu->entries[++index];
  entry->flags.indicator_on = dock->collapsed;
  entry->clientdata = dock;

  /* auto-collapse */
  entry = menu->entries[++index];
  entry->flags.indicator_on = dock->auto_collapse;
  entry->clientdata = dock;

  /* auto-raise/lower */
  entry = menu->entries[++index];
  entry->flags.indicator_on = dock->auto_raise_lower;
  entry->clientdata = dock;
  wMenuSetEnabled(menu, index, dock->lowered && (dock->type == WM_CLIP));

  /* attract icons */
  entry = menu->entries[++index];
  entry->flags.indicator_on = dock->attract_icons;
  entry->clientdata = dock;

  menu->flags.realized = 0;
  wMenuRealize(menu);
}

static WMenu *makeClipOptionsMenu(WScreen *scr)
{
  WMenu *menu;
  WMenuEntry *entry;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu) {
    wwarning(_("could not create options submenu for Clip menu"));
    return NULL;
  }

  entry = wMenuAddCallback(menu, _("Keep on Top"), toggleLoweredCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  entry = wMenuAddCallback(menu, _("Collapsed"), toggleCollapsedCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  entry = wMenuAddCallback(menu, _("Autocollapse"), toggleAutoCollapseCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  entry = wMenuAddCallback(menu, _("Autoraise"), toggleAutoRaiseLowerCallback, NULL);
  entry->flags.indicator = 1;
  entry->flags.indicator_on = 1;
  entry->flags.indicator_type = MI_CHECK;

  entry = wMenuAddCallback(menu, _("Autoattract Icons"), toggleAutoAttractCallback, NULL);
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
    wwarning(_("could not create options submenu for dock position menu"));
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
  WMenuEntry *entry;

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
      wMenuAddCallback(menu, _("Add a drawer"), addADrawerCallback, NULL);

  } else {
    if (type == WM_CLIP)
      entry = wMenuAddCallback(menu, _("Clip Options"), NULL, NULL);
    else /* if (type == WM_DRAWER) */
      entry = wMenuAddCallback(menu, _("Drawer options"), NULL, NULL);

    if (scr->clip_options == NULL)
      scr->clip_options = makeClipOptionsMenu(scr);

    wMenuEntrySetCascade(menu, entry, scr->clip_options);

    /* The same menu is used for the dock and its appicons. If the menu
     * entry text is different between the two contexts, or if it can
     * change depending on some state, free the duplicated string (from
     * wMenuInsertCallback) and use gettext's string */
    if (type == WM_CLIP) {
      entry = wMenuAddCallback(menu, _("Rename Workspace"), renameCallback, NULL);
      wfree(entry->text);
      entry->text = _("Rename Workspace"); /* can be: (Toggle) Omnipresent */
    }

    entry = wMenuAddCallback(menu, _("Selected"), selectCallback, NULL);
    entry->flags.indicator = 1;
    entry->flags.indicator_on = 1;
    entry->flags.indicator_type = MI_CHECK;

    entry = wMenuAddCallback(menu, _("Select All Icons"), selectIconsCallback, NULL);
    wfree(entry->text);
    entry->text = _("Select All Icons"); /* can be: Unselect all icons */

    entry = wMenuAddCallback(menu, _("Keep Icon"), keepIconsCallback, NULL);
    wfree(entry->text);
    entry->text = _("Keep Icon"); /* can be: Keep Icons */

    if (type == WM_CLIP) {
      entry = wMenuAddCallback(menu, _("Move Icon To"), NULL, NULL);
      wfree(entry->text);
      entry->text = _("Move Icon To"); /* can be: Move Icons to */
      scr->clip_submenu = makeWorkspaceMenu(scr);
      if (scr->clip_submenu)
        wMenuEntrySetCascade(menu, entry, scr->clip_submenu);
    }

    entry = wMenuAddCallback(menu, _("Remove Icon"), removeIconsCallback, NULL);
    wfree(entry->text);
    entry->text = _("Remove Icon"); /* can be: Remove Icons */

    wMenuAddCallback(menu, _("Attract Icons"), attractIconsCallback, NULL);
  }

  wMenuAddCallback(menu, _("Launch"), launchCallback, NULL);

  wMenuAddCallback(menu, _("Unhide Here"), unhideHereCallback, NULL);

  entry = wMenuAddCallback(menu, _("Hide"), hideCallback, NULL);
  wfree(entry->text);
  entry->text = _("Hide"); /* can be: Unhide */
#ifndef NEXTSPACE
  wMenuAddCallback(menu, _("Settings..."), settingsCallback, NULL);
#endif
  entry = wMenuAddCallback(menu, _("Kill"), killCallback, NULL);
  wfree(entry->text);
  entry->text = _("Kill"); /* can be: Remove drawer */

  if (type == WM_CLIP)
    scr->clip_menu = menu;

  if (type == WM_DRAWER)
    scr->drawer_menu = menu;

  return menu;
}

WDock *wDockCreate(WScreen *scr, int type, const char *name)
{
  WDock *dock;
  WAppIcon *btn;

  make_keys();

  dock = wmalloc(sizeof(WDock));

  switch (type) {
  case WM_CLIP:
    dock->max_icons = DOCK_MAX_ICONS;
    break;
  case WM_DRAWER:
    dock->max_icons = scr->scr_width / wPreferences.icon_size;
    break;
  case WM_DOCK:
  default:
    dock->max_icons = scr->scr_height / wPreferences.icon_size;
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
      int keepit = aicon->running && wApplicationOf(aicon->main_window);
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
  WWorkspace *workspace = scr->workspaces[scr->current_workspace];
  WMColor *color;
  Window win = aicon->icon->core->window;
  int length, nlength;
  char *ws_name, ws_number[10];
  int ty, tx;

  wIconPaint(aicon->icon);

  length = strlen(workspace->name);
  ws_name = wmalloc(length + 1);
  snprintf(ws_name, length + 1, "%s", workspace->name);
  snprintf(ws_number, sizeof(ws_number), "%i", scr->current_workspace + 1);
  nlength = strlen(ws_number);

  if (wPreferences.flags.noclip || !workspace->clip->collapsed)
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

  if (aicon->launching)
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

static void dockIconPaint(WAppIcon *btn)
{
  if (btn == btn->icon->core->screen_ptr->clip_icon) {
    wClipIconPaint(btn);
  } else if (wIsADrawer(btn)) {
    wDrawerIconPaint(btn);
  } else {
    wAppIconPaint(btn);
    save_appicon(btn, True);
  }
}

static WMPropList *make_icon_state(WAppIcon *btn)
{
  WMPropList *node = NULL;
  WMPropList *command, *autolaunch, *lock, *name, *forced;
  WMPropList *position, *buggy, *omnipresent;
  char *tmp;
  char buffer[64];

  if (btn) {
    if (!btn->command)
      command = WMCreatePLString("-");
    else
      command = WMCreatePLString(btn->command);

    autolaunch = btn->auto_launch ? dYes : dNo;

    lock = btn->lock ? dYes : dNo;

    tmp = EscapeWM_CLASS(btn->wm_instance, btn->wm_class);

    name = WMCreatePLString(tmp);

    wfree(tmp);

    forced = btn->forced_dock ? dYes : dNo;

    buggy = btn->buggy_app ? dYes : dNo;

    if (!wPreferences.flags.clip_merged_in_dock && btn == btn->icon->core->screen_ptr->clip_icon)
      snprintf(buffer, sizeof(buffer), "%i,%i", btn->x_pos, btn->y_pos);
    else
      snprintf(buffer, sizeof(buffer), "%hi,%hi", btn->xindex, btn->yindex);
    position = WMCreatePLString(buffer);

    node = WMCreatePLDictionary(dCommand, command,
                                dName, name,
                                dAutoLaunch, autolaunch,
                                dLock, lock,
                                dForced, forced, dBuggyApplication, buggy, dPosition, position, NULL);
    WMReleasePropList(command);
    WMReleasePropList(name);
    WMReleasePropList(position);

    omnipresent = btn->omnipresent ? dYes : dNo;
    if (btn->dock != btn->icon->core->screen_ptr->dock && (btn->xindex != 0 || btn->yindex != 0))
      WMPutInPLDictionary(node, dOmnipresent, omnipresent);

#ifdef USE_DOCK_XDND
    if (btn->dnd_command) {
      command = WMCreatePLString(btn->dnd_command);
      WMPutInPLDictionary(node, dDropCommand, command);
      WMReleasePropList(command);
    }
#endif	/* USE_DOCK_XDND */

    if (btn->paste_command) {
      command = WMCreatePLString(btn->paste_command);
      WMPutInPLDictionary(node, dPasteCommand, command);
      WMReleasePropList(command);
    }
  }

  return node;
}

static WMPropList *dockSaveState(WDock *dock)
{
  int i;
  WMPropList *icon_info;
  WMPropList *list = NULL, *dock_state = NULL;
  WMPropList *value, *key;
  char buffer[256];

  list = WMCreatePLArray(NULL);

  for (i = (dock->type == WM_DOCK ? 0 : 1); i < dock->max_icons; i++) {
    WAppIcon *btn = dock->icon_array[i];

    if (!btn || btn->attracted)
      continue;

    icon_info = make_icon_state(dock->icon_array[i]);
    if (icon_info != NULL) {
      WMAddToPLArray(list, icon_info);
      WMReleasePropList(icon_info);
    }
  }

  dock_state = WMCreatePLDictionary(dApplications, list, NULL);

  if (dock->type == WM_DOCK) {
    snprintf(buffer, sizeof(buffer), "Applications%i", dock->screen_ptr->scr_height);
    key = WMCreatePLString(buffer);
    WMPutInPLDictionary(dock_state, key, list);
    WMReleasePropList(key);

    snprintf(buffer, sizeof(buffer), "%i,%i", (dock->on_right_side ? -ICON_SIZE : 0), dock->y_pos);
    value = WMCreatePLString(buffer);
    WMPutInPLDictionary(dock_state, dPosition, value);
    WMReleasePropList(value);
  }
  WMReleasePropList(list);

  if (dock->type == WM_CLIP || dock->type == WM_DRAWER) {
    value = (dock->collapsed ? dYes : dNo);
    WMPutInPLDictionary(dock_state, dCollapsed, value);

    value = (dock->auto_collapse ? dYes : dNo);
    WMPutInPLDictionary(dock_state, dAutoCollapse, value);

    value = (dock->attract_icons ? dYes : dNo);
    WMPutInPLDictionary(dock_state, dAutoAttractIcons, value);
  }

  if (dock->type == WM_DOCK || dock->type == WM_CLIP) {
    value = (dock->lowered ? dYes : dNo);
    WMPutInPLDictionary(dock_state, dLowered, value);

    value = (dock->auto_raise_lower ? dYes : dNo);
    WMPutInPLDictionary(dock_state, dAutoRaiseLower, value);
  }

  return dock_state;
}

void wDockSaveState(WScreen *scr, WMPropList *old_state)
{
  WMPropList *dock_state;
  WMPropList *keys;

  dock_state = dockSaveState(scr->dock);

  /*
   * Copy saved states of docks with different sizes.
   */
  if (old_state) {
    int i;
    WMPropList *tmp;

    keys = WMGetPLDictionaryKeys(old_state);
    for (i = 0; i < WMGetPropListItemCount(keys); i++) {
      tmp = WMGetFromPLArray(keys, i);

      if (strncasecmp(WMGetFromPLString(tmp), "applications", 12) == 0
          && !WMGetFromPLDictionary(dock_state, tmp)) {

        WMPutInPLDictionary(dock_state, tmp, WMGetFromPLDictionary(old_state, tmp));
      }
    }
    WMReleasePropList(keys);
  }

  WMPutInPLDictionary(scr->session_state, dDock, dock_state);

  WMReleasePropList(dock_state);
}

void wClipSaveState(WScreen *scr)
{
  WMPropList *clip_state;

  clip_state = make_icon_state(scr->clip_icon);

  WMPutInPLDictionary(scr->session_state, dClip, clip_state);

  WMReleasePropList(clip_state);
}

WMPropList *wClipSaveWorkspaceState(WScreen *scr, int workspace)
{
  return dockSaveState(scr->workspaces[workspace]->clip);
}

static Bool getBooleanDockValue(WMPropList *value, WMPropList *key)
{
  if (value) {
    if (WMIsPLString(value)) {
      if (strcasecmp(WMGetFromPLString(value), "YES") == 0)
        return True;
    } else {
      wwarning(_("bad value in docked icon state info %s"), WMGetFromPLString(key));
    }
  }
  return False;
}

static WAppIcon *restore_icon_state(WScreen *scr, WMPropList *info, int type, int index)
{
  WAppIcon *aicon;
  WMPropList *cmd, *value;
  char *wclass, *winstance, *command;

  cmd = WMGetFromPLDictionary(info, dCommand);
  if (!cmd || !WMIsPLString(cmd))
    return NULL;

  /* parse window name */
  value = WMGetFromPLDictionary(info, dName);
  if (!value)
    return NULL;

  ParseWindowName(value, &winstance, &wclass, "dock");

  if (!winstance && !wclass)
    return NULL;

  /* get commands */
  command = wstrdup(WMGetFromPLString(cmd));

  if (strcmp(command, "-") == 0) {
    wfree(command);

    if (wclass)
      wfree(wclass);
    if (winstance)
      wfree(winstance);

    return NULL;
  }

  aicon = wAppIconCreateForDock(scr, command, winstance, wclass, TILE_NORMAL);
  if (wclass)
    wfree(wclass);
  if (winstance)
    wfree(winstance);

  wfree(command);

  aicon->icon->core->descriptor.handle_mousedown = iconMouseDown;
  aicon->icon->core->descriptor.handle_enternotify = clipEnterNotify;
  aicon->icon->core->descriptor.handle_leavenotify = clipLeaveNotify;
  aicon->icon->core->descriptor.parent_type = WCLASS_DOCK_ICON;
  aicon->icon->core->descriptor.parent = aicon;

#ifdef USE_DOCK_XDND
  cmd = WMGetFromPLDictionary(info, dDropCommand);
  if (cmd)
    aicon->dnd_command = wstrdup(WMGetFromPLString(cmd));
#endif

  cmd = WMGetFromPLDictionary(info, dPasteCommand);
  if (cmd)
    aicon->paste_command = wstrdup(WMGetFromPLString(cmd));

  /* check auto launch */
  value = WMGetFromPLDictionary(info, dAutoLaunch);

  aicon->auto_launch = getBooleanDockValue(value, dAutoLaunch);

  /* check lock */
  value = WMGetFromPLDictionary(info, dLock);

  aicon->lock = getBooleanDockValue(value, dLock);

  /* check if it wasn't normally docked */
  value = WMGetFromPLDictionary(info, dForced);

  aicon->forced_dock = getBooleanDockValue(value, dForced);

  /* check if we can rely on the stuff in the app */
  value = WMGetFromPLDictionary(info, dBuggyApplication);

  aicon->buggy_app = getBooleanDockValue(value, dBuggyApplication);

  /* get position in the dock */
  value = WMGetFromPLDictionary(info, dPosition);
  if (value && WMIsPLString(value)) {
    if (sscanf(WMGetFromPLString(value), "%hi,%hi", &aicon->xindex, &aicon->yindex) != 2)
      wwarning(_("bad value in docked icon state info %s"), WMGetFromPLString(dPosition));

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
  value = WMGetFromPLDictionary(info, dOmnipresent);

  aicon->omnipresent = getBooleanDockValue(value, dOmnipresent);

  aicon->running = 0;
  aicon->docked = 1;

  return aicon;
}

#define COMPLAIN(key) wwarning(_("bad value in dock state info:%s"), key)

WAppIcon *wClipRestoreState(WScreen *scr, WMPropList *clip_state)
{
  WAppIcon *icon;
  WMPropList *value;

  icon = mainIconCreate(scr, WM_CLIP, NULL);

  if (!clip_state)
    return icon;

  WMRetainPropList(clip_state);

  /* restore position */

  value = WMGetFromPLDictionary(clip_state, dPosition);

  if (value) {
    if (!WMIsPLString(value)) {
      COMPLAIN("Position");
    } else {
      if (sscanf(WMGetFromPLString(value), "%i,%i", &icon->x_pos, &icon->y_pos) != 2)
        COMPLAIN("Position");

      /* check position sanity */
      if (!onScreen(scr, icon->x_pos, icon->y_pos))
        wScreenKeepInside(scr, &icon->x_pos, &icon->y_pos, ICON_SIZE, ICON_SIZE);
    }
  }
#ifdef USE_DOCK_XDND
  value = WMGetFromPLDictionary(clip_state, dDropCommand);
  if (value && WMIsPLString(value))
    icon->dnd_command = wstrdup(WMGetFromPLString(value));
#endif

  value = WMGetFromPLDictionary(clip_state, dPasteCommand);
  if (value && WMIsPLString(value))
    icon->paste_command = wstrdup(WMGetFromPLString(value));

  WMReleasePropList(clip_state);

  return icon;
}

WDock *wDockRestoreState(WScreen *scr, WMPropList *dock_state, int type)
{
  WDock *dock;
  WMPropList *apps;
  WMPropList *value;
  WAppIcon *aicon, *old_top;
  int count, i;

  dock = wDockCreate(scr, type, NULL);

  if (!dock_state)
    return dock;

  WMRetainPropList(dock_state);

  /* restore position */
  value = WMGetFromPLDictionary(dock_state, dPosition);
  if (value) {
    if (!WMIsPLString(value)) {
      COMPLAIN("Position");
    } else {
      if (sscanf(WMGetFromPLString(value), "%i,%i", &dock->x_pos, &dock->y_pos) != 2)
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
        } else if (dock->x_pos > scr->scr_width - ICON_SIZE) {
          dock->x_pos = scr->scr_width - ICON_SIZE;
        }
      } else {
        if (dock->x_pos >= 0) {
          dock->x_pos = DOCK_EXTRA_SPACE;
          dock->on_right_side = 0;
        } else {
          dock->x_pos = scr->scr_width - DOCK_EXTRA_SPACE - ICON_SIZE;
          dock->on_right_side = 1;
        }
      }
    }
  }

  /* restore lowered/raised state */
  dock->lowered = 0;

  value = WMGetFromPLDictionary(dock_state, dLowered);
  if (value) {
    if (!WMIsPLString(value)) {
      COMPLAIN("Lowered");
    } else {
      if (strcasecmp(WMGetFromPLString(value), "YES") == 0)
        dock->lowered = 1;
    }
  }

  /* restore collapsed state */
  dock->collapsed = 0;

  value = WMGetFromPLDictionary(dock_state, dCollapsed);
  if (value) {
    if (!WMIsPLString(value)) {
      COMPLAIN("Collapsed");
    } else {
      if (strcasecmp(WMGetFromPLString(value), "YES") == 0)
        dock->collapsed = 1;
    }
  }

  /* restore auto-collapsed state */
  value = WMGetFromPLDictionary(dock_state, dAutoCollapse);
  if (value) {
    if (!WMIsPLString(value)) {
      COMPLAIN("AutoCollapse");
    } else {
      if (strcasecmp(WMGetFromPLString(value), "YES") == 0) {
        dock->auto_collapse = 1;
        dock->collapsed = 1;
      }
    }
  }

  /* restore auto-raise/lower state */
  value = WMGetFromPLDictionary(dock_state, dAutoRaiseLower);
  if (value) {
    if (!WMIsPLString(value)) {
      COMPLAIN("AutoRaiseLower");
    } else {
      if (strcasecmp(WMGetFromPLString(value), "YES") == 0)
        dock->auto_raise_lower = 1;
    }
  }

  /* restore attract icons state */
  dock->attract_icons = 0;

  value = WMGetFromPLDictionary(dock_state, dAutoAttractIcons);
  if (value) {
    if (!WMIsPLString(value)) {
      COMPLAIN("AutoAttractIcons");
    } else {
      if (strcasecmp(WMGetFromPLString(value), "YES") == 0)
        dock->attract_icons = 1;
    }
  }

  /* application list */

  {
    WMPropList *tmp;
    char buffer[64];

    /*
     * When saving, it saves the dock state in
     * Applications and Applicationsnnn
     *
     * When loading, it will first try Applicationsnnn.
     * If it does not exist, use Applications as default.
     */

    snprintf(buffer, sizeof(buffer), "Applications%i", scr->scr_height);

    tmp = WMCreatePLString(buffer);
    apps = WMGetFromPLDictionary(dock_state, tmp);
    WMReleasePropList(tmp);

    if (!apps)
      apps = WMGetFromPLDictionary(dock_state, dApplications);
  }

  if (!apps)
    goto finish;

  count = WMGetPropListItemCount(apps);
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
      wwarning(_("there are too many icons stored in dock. Ignoring what doesn't fit"));
      break;
    }

    value = WMGetFromPLArray(apps, i);
    aicon = restore_icon_state(scr, value, type, dock->icon_count);

    dock->icon_array[dock->icon_count] = aicon;

    if (aicon) {
      aicon->dock = dock;
      aicon->x_pos = dock->x_pos + (aicon->xindex * ICON_SIZE);
      aicon->y_pos = dock->y_pos + (aicon->yindex * ICON_SIZE);

      if (dock->lowered)
        ChangeStackingLevel(aicon->icon->core, WMNormalLevel);
      else
        ChangeStackingLevel(aicon->icon->core, WMDockLevel);

      wCoreConfigure(aicon->icon->core, aicon->x_pos, aicon->y_pos, 0, 0);
#ifndef NEXTSPACE
      if (!dock->collapsed)
        XMapWindow(dpy, aicon->icon->core->window);
#endif
      wRaiseFrame(aicon->icon->core);

      dock->icon_count++;
    } else if (dock->icon_count == 0 && type == WM_DOCK) {
      dock->icon_count++;
    }
  }

  /* if the first icon is not defined, use the default */
  if (dock->icon_array[0] == NULL) {
    /* update default icon */
    old_top->x_pos = dock->x_pos;
    old_top->y_pos = dock->y_pos;
    if (dock->lowered)
      ChangeStackingLevel(old_top->icon->core, WMNormalLevel);
    else
      ChangeStackingLevel(old_top->icon->core, WMDockLevel);

    dock->icon_array[0] = old_top;
    XMoveWindow(dpy, old_top->icon->core->window, dock->x_pos, dock->y_pos);
    /* we don't need to increment dock->icon_count here because it was
     * incremented in the loop above.
     */
  } else if (old_top != dock->icon_array[0]) {
    if (old_top == scr->clip_icon) // TODO dande: understand the logic
      scr->clip_icon = dock->icon_array[0];

    wAppIconDestroy(old_top);
  }

 finish:
  WMReleasePropList(dock_state);

  return dock;
}

void wDockLaunchWithState(WAppIcon *btn, WSavedState *state)
{
  if (btn && btn->command && !btn->running && !btn->launching) {
    btn->drop_launch = 0;
    btn->paste_launch = 0;

    btn->pid = execCommand(btn, btn->command, state);

    if (btn->pid > 0) {
      if (!btn->forced_dock && !btn->buggy_app) {
        btn->launching = 1;
        dockIconPaint(btn);
      }
    }
  } else {
    wfree(state);
  }
}

void wDockDoAutoLaunch(WDock *dock, int workspace)
{
  WAppIcon *btn;
  WSavedState *state;
  int i;

  for (i = 0; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];
    if (!btn || !btn->auto_launch)
      continue;

    state = wmalloc(sizeof(WSavedState));
    state->workspace = workspace;
    /* TODO: this is klugy and is very difficult to understand
     * what's going on. Try to clean up */
    wDockLaunchWithState(btn, state);
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

  dock = scr->workspaces[scr->current_workspace]->clip;
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

    if (!btn->forced_dock) {
      btn->relaunching = btn->running;
      btn->running = 1;
    }
    if (btn->wm_instance || btn->wm_class) {
      WWindowAttributes attr;
      memset(&attr, 0, sizeof(WWindowAttributes));
      wDefaultFillAttributes(btn->wm_instance, btn->wm_class, &attr, NULL, True);

      if (!attr.no_appicon)
        btn->launching = 1;
      else
        btn->running = 0;
    }

    btn->paste_launch = 0;
    btn->drop_launch = 1;
    scr->last_dock = dock;
    btn->pid = execCommand(btn, btn->dnd_command, NULL);
    if (btn->pid > 0) {
      dockIconPaint(btn);
    } else {
      btn->launching = 0;
      if (!btn->relaunching)
        btn->running = 0;
    }
  }
  return False;
}
#endif	/* USE_DOCK_XDND */

Bool wDockAttachIcon(WDock *dock, WAppIcon *icon, int x, int y, Bool update_icon)
{
  WWindow *wwin;
  Bool lupdate_icon = False;
  char *command = NULL;
  int index;

  icon->editing = 0;

  if (update_icon)
    lupdate_icon = True;

  if (icon->command == NULL) {
    /* If icon->owner exists, it means the application is running */
    if (icon->icon->owner) {
      wwin = icon->icon->owner;
      command = GetCommandForWindow(wwin->client_win);
    }

    if (command) {
      icon->command = command;
    } else {
      /* icon->forced_dock = 1; */
      if (dock->type != WM_CLIP || !icon->attracted) {
        icon->editing = 1;
        if (wInputDialog(dock->screen_ptr, _("Dock Icon"),
                         _("Type the command used to launch the application"), &command)) {
          if (command && (command[0] == 0 || (command[0] == '-' && command[1] == 0))) {
            wfree(command);
            command = NULL;
          }
          icon->command = command;
          icon->editing = 0;
        } else {
          icon->editing = 0;
          if (command)
            wfree(command);
          /* If the target is the dock, reject the icon. If
           * the target is the clip, make it an attracted icon
           */
          if (dock->type == WM_CLIP) {
            icon->attracted = 1;
            if (!icon->icon->shadowed) {
              icon->icon->shadowed = 1;
              lupdate_icon = True;
            }
          } else {
            return False;
          }
        }
      }
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

  icon->omnipresent = 0;

  icon->x_pos = dock->x_pos + x * ICON_SIZE;
  icon->y_pos = dock->y_pos + y * ICON_SIZE;

  dock->icon_count++;

  icon->running = 1;
  icon->launching = 0;
  icon->docked = 1;
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
  if (lupdate_icon)
    update_icon_pixmap(icon->icon);

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
  
#ifdef NEXTSPACE
  XWDockContentDidChange(dock);
#endif

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
  
#ifdef NEXTSPACE
  XWDockContentDidChange(dock);
#endif
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
   * workspace to other, because if we move two or more icons without
   * command, the dialog box will not be able to tell us to which of the
   * moved icons it applies. -Dan
   */
  if ((dest->type == WM_DOCK /*|| dest->keep_attracted */ ) && icon->command == NULL) {
    /* If icon->owner exists, it means the application is running */
    if (icon->icon->owner) {
      wwin = icon->icon->owner;
      command = GetCommandForWindow(wwin->client_win);
    }

    if (command) {
      icon->command = command;
    } else {
      icon->editing = 1;
      /* icon->forced_dock = 1; */
      if (wInputDialog(src->screen_ptr, _("Dock Icon"),
                       _("Type the command used to launch the application"), &command)) {
        if (command && (command[0] == 0 || (command[0] == '-' && command[1] == 0))) {
          wfree(command);
          command = NULL;
        }
        icon->command = command;
      } else {
        icon->editing = 0;
        if (command)
          wfree(command);
        return False;
      }
      icon->editing = 0;
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
    icon->attracted = 0;
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

  /* make the settings panel be closed */
  if (icon->panel)
    DestroyDockAppSettingsPanel(icon->panel);

  /* This must be called before icon->dock is set to NULL.
   * Don't move it. -Dan
   */
  wClipMakeIconOmnipresent(icon, False);

  icon->docked = 0;
  icon->dock = NULL;
  icon->attracted = 0;
  icon->auto_launch = 0;
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
  if (!icon->running || !wApplicationOf(icon->main_window)) {
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
#ifdef NEXTSPACE
  XWDockContentDidChange(dock);
#endif
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

      start = icon->omnipresent ? 0 : scr->current_workspace;
      stop = icon->omnipresent ? scr->workspace_count : start + 1;

      aicon = NULL;
      for (k = start; k < stop; k++) {
        WDock *tmp = scr->workspaces[k]->clip;
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
        WDock *tmp = scr->workspaces[k]->clip;
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
  int ex = scr->scr_width, ey = scr->scr_height;
  int extra_count = 0;

  if (dock->type == WM_DRAWER) {
    if (dock->icon_count >= dock->max_icons) { /* drawer is full */
      return False;
    }
    *x_pos = dock->icon_count * (dock->on_right_side ? -1 : 1);
    *y_pos = 0;
    return True;
  }

  if (dock->type == WM_CLIP && dock != scr->workspaces[scr->current_workspace]->clip)
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

    hcount = WMIN(dock->max_icons, scr->scr_width / ICON_SIZE);
    vcount = WMIN(dock->max_icons, scr->scr_height / ICON_SIZE);
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
    x = dock->x_pos = scr->scr_width - ICON_SIZE - DOCK_EXTRA_SPACE;
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

    SetupEnvironment(scr);

#ifdef HAVE_SETSID
    setsid();
#endif

    args = malloc(sizeof(char *) * (argc + 1));
    if (!args)
      exit(111);

    for (i = 0; i < argc; i++)
      args[i] = argv[i];

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
      if (btn->dock == scr->dock || btn->dock->type == WM_DRAWER || btn->omnipresent)
        state->workspace = -1;
      else
        state->workspace = scr->current_workspace;
    }
    wWindowAddSavedState(btn->wm_instance, btn->wm_class, cmdline, pid, state);
    wAddDeathHandler(pid, (WDeathHandler *) trackDeadProcess, btn->dock);
  } else if (state) {
    wfree(state);
  }
  wfree(cmdline);
  return pid;
}

void wDockHideIcons(WDock *dock)
{
  int i;

  if (dock == NULL)
    return;

  for (i = 1; i < dock->max_icons; i++) {
    if (dock->icon_array[i])
      XUnmapWindow(dpy, dock->icon_array[i]->icon->core->window);
  }
  dock->mapped = 0;

  dockIconPaint(dock->icon_array[0]);
}

void wDockShowIcons(WDock *dock)
{
  int i;
  WAppIcon *btn;

  if (dock == NULL)
    return;

  btn = dock->icon_array[0];
  moveDock(dock, btn->x_pos, btn->y_pos);

  /* Deleting any change in stacking level, this function is now only about
     mapping icons */

  if (!dock->collapsed) {
    for (i = 1; i < dock->max_icons; i++) {
      if (dock->icon_array[i])
        XMapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  }
  dock->mapped = 1;

  dockIconPaint(btn);
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
    if (dock->icon_array[i])
      wRaiseFrame(dock->icon_array[i]->icon->core);
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

void wDockFinishLaunch(WAppIcon *icon)
{
  icon->launching = 0;
  icon->relaunching = 0;
  dockIconPaint(icon);
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

  command = GetCommandForWindow(window);
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
        && (icon->launching || !icon->running)) {

      if (icon->wm_instance && wm_instance && strcmp(icon->wm_instance, wm_instance) != 0)
        continue;

      if (icon->wm_class && wm_class && strcmp(icon->wm_class, wm_class) != 0)
        continue;

      if (firstPass && command && strcmp(icon->command, command) != 0)
        continue;

      if (!icon->relaunching) {
        WApplication *wapp;

        /* Possibly an application that was docked with dockit,
         * but the user did not update WMState to indicate that
         * it was docked by force */
        wapp = wApplicationOf(window);
        if (!wapp) {
          icon->forced_dock = 1;
          icon->running = 0;
        }
        if (!icon->forced_dock)
          icon->main_window = window;
      }
      found = True;
      if (!wPreferences.no_animations && !icon->launching &&
          !dock->screen_ptr->flags.startup && !dock->collapsed) {
        WAppIcon *aicon;
        int x0, y0;

        icon->launching = 1;
        dockIconPaint(icon);

        aicon = wAppIconCreateForDock(dock->screen_ptr, NULL,
                                      wm_instance, wm_class, TILE_NORMAL);
        /* XXX: can: aicon->icon == NULL ? */
        PlaceIcon(dock->screen_ptr, &x0, &y0, wGetHeadForWindow(aicon->icon->owner));
        wAppIconMove(aicon, x0, y0);
        /* Should this always be lowered? -Dan */
        if (dock->lowered)
          wLowerFrame(aicon->icon->core);
        XMapWindow(dpy, aicon->icon->core->window);
        aicon->launching = 1;
        wAppIconPaint(aicon);
        slide_window(aicon->icon->core->window, x0, y0, icon->x_pos, icon->y_pos);
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

void wClipUpdateForWorkspaceChange(WScreen *scr, int workspace)
{
  if (!wPreferences.flags.noclip) {
    scr->clip_icon->dock = scr->workspaces[workspace]->clip;
    if (scr->current_workspace != workspace) {
      WDock *old_clip = scr->workspaces[scr->current_workspace]->clip;
      WAppIconChain *chain = scr->global_icons;

      while (chain) {
        wDockMoveIconBetweenDocks(chain->aicon->dock,
                                  scr->workspaces[workspace]->clip,
                                  chain->aicon, chain->aicon->xindex, chain->aicon->yindex);
        if (scr->workspaces[workspace]->clip->collapsed)
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
      wDockShowIcons(scr->workspaces[workspace]->clip);
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

    if (icon->launching && icon->pid == pid) {
      if (!icon->relaunching) {
        icon->running = 0;
        icon->main_window = None;
      }
      wDockFinishLaunch(icon);
      icon->pid = 0;
      if (status == 111) {
        char msg[PATH_MAX];
        char *cmd;

#ifdef USE_DOCK_XDND
        if (icon->drop_launch)
          cmd = icon->dnd_command;
        else
#endif
          if (icon->paste_launch)
            cmd = icon->paste_command;
          else
            cmd = icon->command;

        snprintf(msg, sizeof(msg), _("Could not execute command \"%s\""), cmd);

#ifdef NEXTSPACE
        char *message = wstrdup(msg);
        dispatch_async(workspace_q, ^{
            XWRunAlertPanel(_("Workspace Dock"), message, _("Got It"), NULL, NULL);
            wfree(message);
          });
#else
        wMessageDialog(dock->screen_ptr, _("Error"), msg, _("OK"), NULL, NULL);
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
    newlevel = WMNormalLevel;
    dock->lowered = 1;
  } else {
    newlevel = WMDockLevel;
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
  WMenuEntry *entry;
  WApplication *wapp = NULL;
  int index = 0;
  int x_pos;
  int n_selected;
  int appIsRunning = aicon->running && aicon->icon && aicon->icon->owner;

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
      entry = dock->menu->entries[++index];
      entry->clientdata = aicon;
      wMenuSetEnabled(dock->menu, index, True);
    }
  } else {
    /* clip/drawer options */
    if (scr->clip_options)
      updateClipOptionsMenu(scr->clip_options, dock);

    n_selected = numberOfSelectedIcons(dock);

    if (dock->type == WM_CLIP) {
      /* Rename Workspace */
      entry = dock->menu->entries[++index];
      if (aicon == scr->clip_icon) {
        entry->callback = renameCallback;
        entry->clientdata = dock;
        entry->flags.indicator = 0;
        entry->text = _("Rename Workspace");
      } else {
        entry->callback = omnipresentCallback;
        entry->clientdata = aicon;
        if (n_selected > 0) {
          entry->flags.indicator = 0;
          entry->text = _("Toggle Omnipresent");
        } else {
          entry->flags.indicator = 1;
          entry->flags.indicator_on = aicon->omnipresent;
          entry->flags.indicator_type = MI_CHECK;
          entry->text = _("Omnipresent");
        }
      }
    }

    /* select/unselect icon */
    entry = dock->menu->entries[++index];
    entry->clientdata = aicon;
    entry->flags.indicator_on = aicon->icon->selected;
    wMenuSetEnabled(dock->menu, index, aicon != scr->clip_icon && !wIsADrawer(aicon));

    /* select/unselect all icons */
    entry = dock->menu->entries[++index];
    entry->clientdata = aicon;
    if (n_selected > 0)
      entry->text = _("Unselect All Icons");
    else
      entry->text = _("Select All Icons");

    wMenuSetEnabled(dock->menu, index, dock->icon_count > 1);

    /* keep icon(s) */
    entry = dock->menu->entries[++index];
    entry->clientdata = aicon;
    if (n_selected > 1)
      entry->text = _("Keep Icons");
    else
      entry->text = _("Keep Icon");

    wMenuSetEnabled(dock->menu, index, dock->icon_count > 1);

    if (dock->type == WM_CLIP) {
      /* this is the workspace submenu part */
      entry = dock->menu->entries[++index];
      if (n_selected > 1)
        entry->text = _("Move Icons To");
      else
        entry->text = _("Move Icon To");

      if (scr->clip_submenu)
        updateWorkspaceMenu(scr->clip_submenu, aicon);

      wMenuSetEnabled(dock->menu, index, !aicon->omnipresent);
    }

    /* remove icon(s) */
    entry = dock->menu->entries[++index];
    entry->clientdata = aicon;
    if (n_selected > 1)
      entry->text = _("Remove Icons");
    else
      entry->text = _("Remove Icon");

    wMenuSetEnabled(dock->menu, index, dock->icon_count > 1);

    /* attract icon(s) */
    entry = dock->menu->entries[++index];
    entry->clientdata = aicon;

    dock->menu->flags.realized = 0;
    wMenuRealize(dock->menu);
  }

  if (aicon->icon->owner)
    wapp = wApplicationOf(aicon->icon->owner->main_window);
  else
    wapp = NULL;

  /* launch */
  entry = dock->menu->entries[++index];
  entry->clientdata = aicon;
  wMenuSetEnabled(dock->menu, index, aicon->command != NULL);

  /* unhide here */
  entry = dock->menu->entries[++index];
  entry->clientdata = aicon;
  if (wapp && wapp->flags.hidden)
    entry->text = _("Unhide Here");
  else
    entry->text = _("Bring Here");

  wMenuSetEnabled(dock->menu, index, appIsRunning);

  /* hide */
  entry = dock->menu->entries[++index];
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
  entry = dock->menu->entries[++index];
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
    } else if (x_pos + dock->menu->frame->core->width > scr->scr_width - 2) {
      x_pos = scr->scr_width - dock->menu->frame->core->width - 4;
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

    fprintf(stderr, "[WM] Dock icon Double-click for workspace %i leader: %lu\n",
            wapp->last_workspace, wapp->main_window);
    
    unhideHere = (event->xbutton.state & ShiftMask);

    /* go to the last workspace that the user worked on the app */
    if (wapp->last_workspace != dock->screen_ptr->current_workspace && !unhideHere) {
      wApplicationActivate(wapp);
    }

    wUnhideApplication(wapp, event->xbutton.button == Button2, unhideHere);

    if (event->xbutton.state & ALT_MOD_MASK)
      wHideOtherApplications(btn->icon->owner);
  } else {
    if (event->xbutton.button == Button1) {
      if (event->xbutton.state & MOD_MASK) {
        /* raise/lower dock */
        toggleLowered(dock);
      } else if (btn == dock->screen_ptr->clip_icon) {
        if (getClipButton(event->xbutton.x, event->xbutton.y) != CLIP_IDLE)
          handleClipChangeWorkspace(dock->screen_ptr, event);
        else if (wPreferences.flags.clip_merged_in_dock) {
          // Is actually the dock
          if (btn->command)
            {
              if (!btn->launching && (!btn->running || (event->xbutton.state & ControlMask)))
                launchDockedApplication(btn, False);
            }
          else
            {
              wShowInfoPanel(dock->screen_ptr);
            }
        }
        else
          toggleCollapsed(dock);
      } else if (wIsADrawer(btn)) {
        toggleCollapsed(dock);
      } else if (btn->command) {
        if (!btn->launching && (!btn->running || (event->xbutton.state & ControlMask)))
          launchDockedApplication(btn, False);
      } else if (btn->xindex == 0 && btn->yindex == 0 && btn->dock->type == WM_DOCK) {
        wShowInfoPanel(dock->screen_ptr);
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
    wwarning("pointer grab failed for dock move");

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
        slide_windows(wins, dock->icon_count,
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

static void handleClipChangeWorkspace(WScreen *scr, XEvent *event)
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
    if (scr->current_workspace < scr->workspace_count - 1)
      wWorkspaceChange(scr, scr->current_workspace + 1);
    else if (new_ws && scr->current_workspace < MAX_WORKSPACES - 1)
      wWorkspaceChange(scr, scr->current_workspace + 1);
    else if (wPreferences.ws_cycle)
      wWorkspaceChange(scr, 0);
  } else if (direction == CLIP_REWIND) {
    if (scr->current_workspace > 0)
      wWorkspaceChange(scr, scr->current_workspace - 1);
    else if (scr->current_workspace == 0 && wPreferences.ws_cycle)
      wWorkspaceChange(scr, scr->workspace_count - 1);
  }

  wClipIconPaint(scr->clip_icon);
}

static void iconMouseDown(WObjDescriptor *desc, XEvent *event)
{
  WAppIcon *aicon = desc->parent;
  WDock *dock = aicon->dock;
  WScreen *scr = aicon->icon->core->screen_ptr;

  fprintf(stderr, "[WM] Dock iconMouseDown\n");
  
  if (aicon->editing || WCHECK_STATE(WSTATE_MODAL))
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
    if (!(event->xbutton.state & MOD_MASK))
      wDockRaise(dock);

    if ((event->xbutton.state & ShiftMask) && aicon != scr->clip_icon && dock->type != WM_DOCK) {
      wIconSelect(aicon->icon);
      return;
    }

    if (aicon->yindex == 0 && aicon->xindex == 0) {
      if (getClipButton(event->xbutton.x, event->xbutton.y) != CLIP_IDLE &&
          (dock->type == WM_CLIP || (dock->type == WM_DOCK && wPreferences.flags.clip_merged_in_dock)))
        handleClipChangeWorkspace(scr, event);
      else
        handleDockMove(dock, aicon, event);
    } else {
      Bool hasMoved = wHandleAppIconMove(aicon, event);
      if (wPreferences.single_click && !hasMoved)
        iconDblClick(desc, event);
    }
  } else if (event->xbutton.button == Button2 && aicon == scr->clip_icon) {
    if (!scr->clip_ws_menu)
      scr->clip_ws_menu = wWorkspaceMenuMake(scr, False);

    if (scr->clip_ws_menu) {
      WMenu *wsMenu = scr->clip_ws_menu;
      int xpos;

      wWorkspaceMenuUpdate(scr, wsMenu);

      xpos = event->xbutton.x_root - wsMenu->frame->core->width / 2 - 1;
      if (xpos < 0) {
        xpos = 0;
      } else if (xpos + wsMenu->frame->core->width > scr->scr_width - 2) {
        xpos = scr->scr_width - wsMenu->frame->core->width - 4;
      }
      wMenuMapAt(wsMenu, xpos, event->xbutton.y_root + 2, False);

      desc = &wsMenu->menu->descriptor;
      event->xany.send_event = True;
      (*desc->handle_mousedown) (desc, event);
    }
  } else if (event->xbutton.button == Button2 && dock->type == WM_CLIP &&
             (event->xbutton.state & ShiftMask) && aicon != scr->clip_icon) {
    wClipMakeIconOmnipresent(aicon, !aicon->omnipresent);
  } else if (event->xbutton.button == Button3) {
    if (event->xbutton.send_event &&
        XGrabPointer(dpy, aicon->icon->core->window, True, ButtonMotionMask
                     | ButtonReleaseMask | ButtonPressMask, GrabModeAsync,
                     GrabModeAsync, None, None, CurrentTime) != GrabSuccess) {
      wwarning("pointer grab failed for dockicon menu");
      return;
    }

    openDockMenu(dock, aicon, event);
  } else if (event->xbutton.button == Button2) {
    WAppIcon *btn = desc->parent;

    if (!btn->launching && (!btn->running || (event->xbutton.state & ControlMask)))
      launchDockedApplication(btn, True);
  } else if (event->xbutton.button == Button4 && dock->type == WM_CLIP) {
    wWorkspaceRelativeChange(scr, 1);
  } else if (event->xbutton.button == Button5 && dock->type == WM_CLIP) {
    wWorkspaceRelativeChange(scr, -1);
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
    tmp->auto_raise_magic = WMAddTimerHandler(wPreferences.clip_auto_raise_delay, clipAutoRaise, (void *) tmp);

  if (dock->type != WM_CLIP && dock->type != WM_DRAWER)
    return;

  /* The auto expand/collapse code */
  if (dock->auto_collapse_magic) {
    WMDeleteTimerHandler(dock->auto_collapse_magic);
    dock->auto_collapse_magic = NULL;
  }
  if (dock->auto_collapse && !dock->auto_expand_magic)
    dock->auto_expand_magic = WMAddTimerHandler(wPreferences.clip_auto_expand_delay, clipAutoExpand, (void *)dock);
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
    tmp->auto_lower_magic = WMAddTimerHandler(wPreferences.clip_auto_lower_delay, clipAutoLower, (void *)tmp);

  if (dock->type != WM_CLIP && dock->type != WM_DRAWER)
    return;

  if (dock->auto_expand_magic) {
    WMDeleteTimerHandler(dock->auto_expand_magic);
    dock->auto_expand_magic = NULL;
  }
  if (dock->auto_collapse && !dock->auto_collapse_magic)
    dock->auto_collapse_magic = WMAddTimerHandler(wPreferences.clip_auto_collapse_delay, clipAutoCollapse, (void *)dock);
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

static void clipAutoCollapse(void *cdata)
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

static void clipAutoExpand(void *cdata)
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

static void clipAutoLower(void *cdata)
{
  WDock *dock = (WDock *) cdata;

  if (dock->auto_raise_lower)
    wDockLower(dock);

  dock->auto_lower_magic = NULL;
}

static void clipAutoRaise(void *cdata)
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

  for (i = 0; i < scr->workspace_count; i++) {
    clip = scr->workspaces[i]->clip;

    if (clip == aicon->dock)
      continue;

    if (clip->icon_count + scr->global_icon_count >= clip->max_icons)
      return False;	/* Clip is full in some workspace */

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

  if (aicon->omnipresent == omnipresent)
    return WO_SUCCESS;

  if (omnipresent) {
    if (iconCanBeOmnipresent(aicon)) {
      aicon->omnipresent = 1;
      new_entry = wmalloc(sizeof(WAppIconChain));
      new_entry->aicon = aicon;
      new_entry->next = scr->global_icons;
      scr->global_icons = new_entry;
      scr->global_icon_count++;
    } else {
      aicon->omnipresent = 0;
      status = WO_FAILED;
    }
  } else {
    aicon->omnipresent = 0;
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
      wwarning("The drawer to be removed can not be found.");
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
    wwarning("Couldn't find a unique name for drawer in %d attempts.", i);
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
    ChangeStackingLevel(drawer->icon_array[0]->icon->core, WMDockLevel);
  else
    ChangeStackingLevel(drawer->icon_array[0]->icon->core, WMNormalLevel);
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

static void addADrawerCallback(WMenu *menu, WMenuEntry *entry)
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
  WMArray *icons;

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
    icons = WMCreateArray(drawer->icon_count - 1);
    for (i = 1; i < drawer->max_icons; i++) {
      aicon = drawer->icon_array[i];
      if (aicon == NULL)
        continue;
      WMAddToArray(icons, aicon);
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

static void removeDrawerCallback(WMenu *menu, WMenuEntry *entry)
{
  WDock *dock = ((WAppIcon*)entry->clientdata)->dock;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  assert(dock != NULL);

  if (dock->icon_count > 2) {
    if (wMessageDialog(dock->screen_ptr, _("Drawer"),
                       _("All icons in this drawer will be detached!"),
                       _("OK"), _("Cancel"), NULL) != WAPRDefault)
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
  /* wmessage(" Index of the moving appicon is %d (%sredocking)", index_of_hole, (redocking ? "" : "not ")); */
  if (abs(index_of_hole) > abs(drawer->icon_count) - (redocking ? 1 : 0))
    wwarning(" index_of_hole is too large ! (%d greater than %d)",
             index_of_hole, abs(drawer->icon_count) - (redocking ? 1 : 0));
  if (index_of_hole == 0)
    wwarning(" index_of_hole == 0 (%sredocking, icon_count == %d)", (redocking ? "" : "not "), drawer->icon_count);

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
  slide_windows(wins, n, from_x, aicon->y_pos, aicon->x_pos, aicon->y_pos);
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
    wwarning("Removing aicon at index %d from %s: j=%d but should be %d",
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
static WDock * drawerRestoreState(WScreen *scr, WMPropList *drawer_state)
{
  WDock *drawer;
  WMPropList *apps, *value, *dock_state;
  WAppIcon *aicon;
  int count, i;

  if (!drawer_state)
    return NULL;

  make_keys();

  WMRetainPropList(drawer_state);

  /* Get the instance name, and create a drawer */
  value = WMGetFromPLDictionary(drawer_state, dName);
  drawer = wDockCreate(scr, WM_DRAWER, WMGetFromPLString(value));

  /* restore DnD command and paste command */
#ifdef USE_DOCK_XDND
  value = WMGetFromPLDictionary(drawer_state, dDropCommand);
  if (value && WMIsPLString(value))
    drawer->icon_array[0]->dnd_command = wstrdup(WMGetFromPLString(value));
#endif /* USE_DOCK_XDND */

  value = WMGetFromPLDictionary(drawer_state, dPasteCommand);
  if (value && WMIsPLString(value))
    drawer->icon_array[0]->paste_command = wstrdup(WMGetFromPLString(value));

  /* restore position */
  value = WMGetFromPLDictionary(drawer_state, dPosition);
  if (!value || !WMIsPLString(value))
    COMPLAIN("Position");
  else {
    int x, y, y_index;
    if (sscanf(WMGetFromPLString(value), "%i,%i", &x, &y) != 2)
      COMPLAIN("Position");

    /* check position sanity */
    if (x != scr->dock->x_pos) {
      x = scr->dock->x_pos;
    }
    y_index = (y - scr->dock->y_pos) / ICON_SIZE;
    if (y_index >= scr->dock->max_icons) {
      /* Here we should do something more intelligent, since it
       * can happen even if the user hasn't hand-edited his
       * G/D/State file (but uses a lower resolution). */
      y_index = scr->dock->max_icons - 1;
    }
    y = scr->dock->y_pos + y_index * ICON_SIZE;
    moveDock(drawer, x, y);
  }

  /* restore dock properties (applist and others) */
  dock_state = WMGetFromPLDictionary(drawer_state, dDock);

  /* restore lowered/raised state: same as scr->dock, no matter what */
  drawer->lowered = scr->dock->lowered;
  if (!drawer->lowered)
    ChangeStackingLevel(drawer->icon_array[0]->icon->core, WMDockLevel);
  else
    ChangeStackingLevel(drawer->icon_array[0]->icon->core, WMNormalLevel);
  wRaiseFrame(drawer->icon_array[0]->icon->core);

  /* restore collapsed state */
  drawer->collapsed = 0;
  value = WMGetFromPLDictionary(dock_state, dCollapsed);
  if (value && strcasecmp(WMGetFromPLString(value), "YES") == 0) {
    drawer->collapsed = 1;
  }
  /* restore auto-collapsed state */
  value = WMGetFromPLDictionary(dock_state, dAutoCollapse);
  if (value && strcasecmp(WMGetFromPLString(value), "YES") == 0) {
    drawer->auto_collapse = 1;
    drawer->collapsed = 1;
  } else {
    drawer->auto_collapse = 0; // because wDockCreate sets it (drawers only)
  }

  /* restore auto-raise/lower state: same as scr->dock, no matter what */
  drawer->auto_raise_lower = scr->dock->auto_raise_lower;

  /* restore attract icons state */
  drawer->attract_icons = 0;
  value = WMGetFromPLDictionary(dock_state, dAutoAttractIcons);
  if (value && strcasecmp(WMGetFromPLString(value), "YES") == 0) {
    drawer->attract_icons = 1;
    scr->attracting_drawer = drawer;
  }

  /* application list */
  apps = WMGetFromPLDictionary(dock_state, dApplications);

  if (!apps) {
    goto finish;
  }

  count = WMGetPropListItemCount(apps);

  if (count == 0)
    goto finish;

  for (i=0; i<count; i++) {
    if (drawer->icon_count >= drawer->max_icons) {
      wwarning(_("there are too many icons stored in drawer. Ignoring what doesn't fit"));
      break;
    }

    value = WMGetFromPLArray(apps, i);
    aicon = restore_icon_state(scr, value, WM_DRAWER, drawer->icon_count);

    drawer->icon_array[drawer->icon_count] = aicon;

    if (aicon) {
      aicon->dock = drawer;
      aicon->x_pos = drawer->x_pos + (aicon->xindex * ICON_SIZE);
      aicon->y_pos = drawer->y_pos + (aicon->yindex * ICON_SIZE);

      if (!drawer->lowered)
        ChangeStackingLevel(aicon->icon->core, WMDockLevel);
      else
        ChangeStackingLevel(aicon->icon->core, WMNormalLevel);

      wCoreConfigure(aicon->icon->core, aicon->x_pos, aicon->y_pos, 0, 0);

      if (!drawer->collapsed)
        XMapWindow(dpy, aicon->icon->core->window);
      wRaiseFrame(aicon->icon->core);

      drawer->icon_count++;
    }
  }

 finish:
  WMReleasePropList(drawer_state);

  return drawer;
}

/* Same kind of comment than for previous function: this function is
 * very similar to make_icon_state, but has substential differences as
 * well. */
static WMPropList *drawerSaveState(WDock *drawer)
{
  WMPropList *pstr, *drawer_state;
  WAppIcon *ai;
  char buffer[64];

  ai = drawer->icon_array[0];
  /* Store its name */
  pstr = WMCreatePLString(ai->wm_instance);
  drawer_state = WMCreatePLDictionary(dName, pstr, NULL); /* we need this final NULL */
  WMReleasePropList(pstr);

  /* Store its position */
  snprintf(buffer, sizeof(buffer), "%i,%i", ai->x_pos, ai->y_pos);
  pstr = WMCreatePLString(buffer);
  WMPutInPLDictionary(drawer_state, dPosition, pstr);
  WMReleasePropList(pstr);

#ifdef USE_DOCK_XDND
  /* Store its DnD command */
  if (ai->dnd_command) {
    pstr = WMCreatePLString(ai->dnd_command);
    WMPutInPLDictionary(drawer_state, dDropCommand, pstr);
    WMReleasePropList(pstr);
  }
#endif /* USE_DOCK_XDND */

  /* Store its paste command */
  if (ai->paste_command) {
    pstr = WMCreatePLString(ai->paste_command);
    WMPutInPLDictionary(drawer_state, dPasteCommand, pstr);
    WMReleasePropList(pstr);
  }

  /* Store applications list and other properties */
  pstr = dockSaveState(drawer);
  WMPutInPLDictionary(drawer_state, dDock, pstr);
  WMReleasePropList(pstr);

  return drawer_state;
}

void wDrawersSaveState(WScreen *scr)
{
  WMPropList *all_drawers, *drawer_state;
  int i;
  WDrawerChain *dc;

  make_keys();

  all_drawers = WMCreatePLArray(NULL);
  for (i=0, dc = scr->drawers;
       i < scr->drawer_count;
       i++, dc = dc->next) {
    drawer_state = drawerSaveState(dc->adrawer);
    WMAddToPLArray(all_drawers, drawer_state);
    WMReleasePropList(drawer_state);
  }
  WMPutInPLDictionary(scr->session_state, dDrawers, all_drawers);
  WMReleasePropList(all_drawers);
}

void wDrawersRestoreState(WScreen *scr)
{
  WMPropList *all_drawers, *drawer_state;
  int i;

  make_keys();

  if (scr->session_state == NULL)
    return;

  all_drawers = WMGetFromPLDictionary(scr->session_state, dDrawers);
  if (!all_drawers)
    return;

  for (i = 0; i < WMGetPropListItemCount(all_drawers); i++) {
    drawer_state = WMGetFromPLArray(all_drawers, i);
    drawerRestoreState(scr, drawer_state);
    // Note: scr->drawers was updated when the the drawer was created
  }
}
