/*  wmspec.c-- support for the wm-spec Hints
 *
 *  Window Maker window manager
 *
 *  Copyright (c) 1998-2003 Alfredo K. Kojima
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

/*
 * TODO
 * ----
 *
 * This file needs to be checked for all calls to XGetWindowProperty() and
 * proper checks need to be made on the returned values. Only checking for
 * return to be Success is not enough. -Dan
 */

#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <string.h>

#include <WMcore/notification.h>

#include "WindowMaker.h"
#include "window.h"
#include "screen.h"
#include "workspace.h"
#include "framewin.h"
#include "actions.h"
#include "client.h"
#include "appicon.h"
#include "wmspec.h"
#include "icon.h"
#include "stacking.h"
#include "xrandr.h"
#include "properties.h"


/* Root Window Properties */
static Atom net_supported;
static Atom net_client_list;
static Atom net_client_list_stacking;
static Atom net_number_of_desktops;
static Atom net_desktop_geometry;
static Atom net_desktop_viewport;
static Atom net_current_desktop;
static Atom net_desktop_names;
static Atom net_active_window;
static Atom net_workarea;
static Atom net_supporting_wm_check;
static Atom net_virtual_roots;	/* N/A */
static Atom net_desktop_layout;	/* XXX */
static Atom net_showing_desktop;

/* Other Root Window Messages */
static Atom net_close_window;
static Atom net_moveresize_window;	/* TODO */
static Atom net_wm_moveresize;	/* TODO */

/* Application Window Properties */
static Atom net_wm_name;
static Atom net_wm_visible_name;	/* TODO (unnecessary?) */
static Atom net_wm_icon_name;
static Atom net_wm_visible_icon_name;	/* TODO (unnecessary?) */
static Atom net_wm_desktop;
static Atom net_wm_window_type;
static Atom net_wm_window_type_desktop;
static Atom net_wm_window_type_dock;
static Atom net_wm_window_type_toolbar;
static Atom net_wm_window_type_menu;
static Atom net_wm_window_type_utility;
static Atom net_wm_window_type_splash;
static Atom net_wm_window_type_dialog;
static Atom net_wm_window_type_dropdown_menu;
static Atom net_wm_window_type_popup_menu;
static Atom net_wm_window_type_tooltip;
static Atom net_wm_window_type_notification;
static Atom net_wm_window_type_combo;
static Atom net_wm_window_type_dnd;
static Atom net_wm_window_type_normal;
static Atom net_wm_state;
static Atom net_wm_state_modal;	/* XXX: what is this?!? */
static Atom net_wm_state_sticky;
static Atom net_wm_state_maximized_vert;
static Atom net_wm_state_maximized_horz;
static Atom net_wm_state_shaded;
static Atom net_wm_state_skip_taskbar;
static Atom net_wm_state_skip_pager;
static Atom net_wm_state_hidden;
static Atom net_wm_state_fullscreen;
static Atom net_wm_state_above;
static Atom net_wm_state_below;
static Atom net_wm_allowed_actions;
static Atom net_wm_action_move;
static Atom net_wm_action_resize;
static Atom net_wm_action_minimize;
static Atom net_wm_action_shade;
static Atom net_wm_action_stick;
static Atom net_wm_action_maximize_horz;
static Atom net_wm_action_maximize_vert;
static Atom net_wm_action_fullscreen;
static Atom net_wm_action_change_desktop;
static Atom net_wm_action_close;
static Atom net_wm_strut;
static Atom net_wm_strut_partial;	/* TODO: doesn't really fit into the current strut scheme */
static Atom net_wm_icon_geometry;	/* FIXME: should work together with net_wm_handled_icons, gnome-panel-2.2.0.1 doesn't use _NET_WM_HANDLED_ICONS, thus present situation. */
static Atom net_wm_icon;
static Atom net_wm_pid;		/* TODO */
static Atom net_wm_handled_icons;	/* FIXME: see net_wm_icon_geometry */
static Atom net_wm_window_opacity;

static Atom net_frame_extents;

/* Window Manager Protocols */
static Atom net_wm_ping;	/* TODO */

static Atom utf8_string;

typedef struct {
  char *name;
  Atom *atom;
} atomitem_t;

static atomitem_t atomNames[] = {
                                 {"_NET_SUPPORTED", &net_supported},
                                 {"_NET_CLIENT_LIST", &net_client_list},
                                 {"_NET_CLIENT_LIST_STACKING", &net_client_list_stacking},
                                 {"_NET_NUMBER_OF_DESKTOPS", &net_number_of_desktops},
                                 {"_NET_DESKTOP_GEOMETRY", &net_desktop_geometry},
                                 {"_NET_DESKTOP_VIEWPORT", &net_desktop_viewport},
                                 {"_NET_CURRENT_DESKTOP", &net_current_desktop},
                                 {"_NET_DESKTOP_NAMES", &net_desktop_names},
                                 {"_NET_ACTIVE_WINDOW", &net_active_window},
                                 {"_NET_WORKAREA", &net_workarea},
                                 {"_NET_SUPPORTING_WM_CHECK", &net_supporting_wm_check},
                                 {"_NET_VIRTUAL_ROOTS", &net_virtual_roots},
                                 {"_NET_DESKTOP_LAYOUT", &net_desktop_layout},
                                 {"_NET_SHOWING_DESKTOP", &net_showing_desktop},

                                 {"_NET_CLOSE_WINDOW", &net_close_window},
                                 {"_NET_MOVERESIZE_WINDOW", &net_moveresize_window},
                                 {"_NET_WM_MOVERESIZE", &net_wm_moveresize},

                                 {"_NET_WM_NAME", &net_wm_name},
                                 {"_NET_WM_VISIBLE_NAME", &net_wm_visible_name},
                                 {"_NET_WM_ICON_NAME", &net_wm_icon_name},
                                 {"_NET_WM_VISIBLE_ICON_NAME", &net_wm_visible_icon_name},
                                 {"_NET_WM_DESKTOP", &net_wm_desktop},
                                 {"_NET_WM_WINDOW_TYPE", &net_wm_window_type},
                                 {"_NET_WM_WINDOW_TYPE_DESKTOP", &net_wm_window_type_desktop},
                                 {"_NET_WM_WINDOW_TYPE_DOCK", &net_wm_window_type_dock},
                                 {"_NET_WM_WINDOW_TYPE_TOOLBAR", &net_wm_window_type_toolbar},
                                 {"_NET_WM_WINDOW_TYPE_MENU", &net_wm_window_type_menu},
                                 {"_NET_WM_WINDOW_TYPE_UTILITY", &net_wm_window_type_utility},
                                 {"_NET_WM_WINDOW_TYPE_SPLASH", &net_wm_window_type_splash},
                                 {"_NET_WM_WINDOW_TYPE_DIALOG", &net_wm_window_type_dialog},
                                 {"_NET_WM_WINDOW_TYPE_DROPDOWN_MENU", &net_wm_window_type_dropdown_menu},
                                 {"_NET_WM_WINDOW_TYPE_POPUP_MENU", &net_wm_window_type_popup_menu},
                                 {"_NET_WM_WINDOW_TYPE_TOOLTIP", &net_wm_window_type_tooltip},
                                 {"_NET_WM_WINDOW_TYPE_NOTIFICATION", &net_wm_window_type_notification},
                                 {"_NET_WM_WINDOW_TYPE_COMBO", &net_wm_window_type_combo},
                                 {"_NET_WM_WINDOW_TYPE_DND", &net_wm_window_type_dnd},
                                 {"_NET_WM_WINDOW_TYPE_NORMAL", &net_wm_window_type_normal},
                                 {"_NET_WM_STATE", &net_wm_state},
                                 {"_NET_WM_STATE_MODAL", &net_wm_state_modal},
                                 {"_NET_WM_STATE_STICKY", &net_wm_state_sticky},
                                 {"_NET_WM_STATE_MAXIMIZED_VERT", &net_wm_state_maximized_vert},
                                 {"_NET_WM_STATE_MAXIMIZED_HORZ", &net_wm_state_maximized_horz},
                                 {"_NET_WM_STATE_SHADED", &net_wm_state_shaded},
                                 {"_NET_WM_STATE_SKIP_TASKBAR", &net_wm_state_skip_taskbar},
                                 {"_NET_WM_STATE_SKIP_PAGER", &net_wm_state_skip_pager},
                                 {"_NET_WM_STATE_HIDDEN", &net_wm_state_hidden},
                                 {"_NET_WM_STATE_FULLSCREEN", &net_wm_state_fullscreen},
                                 {"_NET_WM_STATE_ABOVE", &net_wm_state_above},
                                 {"_NET_WM_STATE_BELOW", &net_wm_state_below},
                                 {"_NET_WM_ALLOWED_ACTIONS", &net_wm_allowed_actions},
                                 {"_NET_WM_ACTION_MOVE", &net_wm_action_move},
                                 {"_NET_WM_ACTION_RESIZE", &net_wm_action_resize},
                                 {"_NET_WM_ACTION_MINIMIZE", &net_wm_action_minimize},
                                 {"_NET_WM_ACTION_SHADE", &net_wm_action_shade},
                                 {"_NET_WM_ACTION_STICK", &net_wm_action_stick},
                                 {"_NET_WM_ACTION_MAXIMIZE_HORZ", &net_wm_action_maximize_horz},
                                 {"_NET_WM_ACTION_MAXIMIZE_VERT", &net_wm_action_maximize_vert},
                                 {"_NET_WM_ACTION_FULLSCREEN", &net_wm_action_fullscreen},
                                 {"_NET_WM_ACTION_CHANGE_DESKTOP", &net_wm_action_change_desktop},
                                 {"_NET_WM_ACTION_CLOSE", &net_wm_action_close},
                                 {"_NET_WM_STRUT", &net_wm_strut},
                                 {"_NET_WM_STRUT_PARTIAL", &net_wm_strut_partial},
                                 {"_NET_WM_ICON_GEOMETRY", &net_wm_icon_geometry},
                                 {"_NET_WM_ICON", &net_wm_icon},
                                 {"_NET_WM_PID", &net_wm_pid},
                                 {"_NET_WM_HANDLED_ICONS", &net_wm_handled_icons},
                                 {"_NET_WM_WINDOW_OPACITY", &net_wm_window_opacity},

                                 {"_NET_FRAME_EXTENTS", &net_frame_extents},

                                 {"_NET_WM_PING", &net_wm_ping},

                                 {"UTF8_STRING", &utf8_string},
};

#define _NET_WM_STATE_REMOVE 0
#define _NET_WM_STATE_ADD 1
#define _NET_WM_STATE_TOGGLE 2

#if 0
/*
 * These constant provide information on the kind of window move/resize when
 * it is initiated by the application instead of by WindowMaker. They are
 * parameter for the client message _NET_WM_MOVERESIZE, as defined by the
 * FreeDesktop wm-spec standard:
 *   http://standards.freedesktop.org/wm-spec/1.5/ar01s04.html
 *
 * Today, WindowMaker does not support this at all (the corresponding Atom
 * is not added to the list in setSupportedHints), probably because there is
 * nothing it needs to do about it, the application is assumed to know what
 * it is doing, and WindowMaker won't get in the way.
 *
 * The definition of the constants (taken from the standard) are disabled to
 * avoid a spurious warning (-Wunused-macros).
 */
#define _NET_WM_MOVERESIZE_SIZE_TOPLEFT      0
#define _NET_WM_MOVERESIZE_SIZE_TOP          1
#define _NET_WM_MOVERESIZE_SIZE_TOPRIGHT     2
#define _NET_WM_MOVERESIZE_SIZE_RIGHT        3
#define _NET_WM_MOVERESIZE_SIZE_BOTTOMRIGHT  4
#define _NET_WM_MOVERESIZE_SIZE_BOTTOM       5
#define _NET_WM_MOVERESIZE_SIZE_BOTTOMLEFT   6
#define _NET_WM_MOVERESIZE_SIZE_LEFT         7
#define _NET_WM_MOVERESIZE_MOVE              8	/* movement only */
#define _NET_WM_MOVERESIZE_SIZE_KEYBOARD     9	/* size via keyboard */
#define _NET_WM_MOVERESIZE_MOVE_KEYBOARD    10	/* move via keyboard */
#endif

static void observer(void *self, WMNotification *notif);
static void wsobserver(void *self, WMNotification *notif);

static void updateClientList(WScreen *scr);
static void updateClientListStacking(WScreen *scr, WWindow *);

static void updateWorkspaceNames(WScreen *scr);
static void updateCurrentWorkspace(WScreen *scr);
static void updateWorkspaceCount(WScreen *scr);
static void wNETWMShowingDesktop(WScreen *scr, Bool show);

typedef struct NetData {
  WScreen *scr;
  WReservedArea *strut;
  WWindow **show_desktop;
} NetData;

static void setSupportedHints(WScreen *scr)
{
  Atom atom[wlengthof(atomNames)];
  int i = 0;

  /* set supported hints list */
  /* XXX: extend this !!! */

  atom[i++] = net_client_list;
  atom[i++] = net_client_list_stacking;
  atom[i++] = net_number_of_desktops;
  atom[i++] = net_desktop_geometry;
  atom[i++] = net_desktop_viewport;
  atom[i++] = net_current_desktop;
  atom[i++] = net_desktop_names;
  atom[i++] = net_active_window;
  atom[i++] = net_workarea;
  atom[i++] = net_supporting_wm_check;
  atom[i++] = net_showing_desktop;
#if 0
  atom[i++] = net_wm_moveresize;
#endif
  atom[i++] = net_wm_desktop;
  atom[i++] = net_wm_window_type;
  atom[i++] = net_wm_window_type_desktop;
  atom[i++] = net_wm_window_type_dock;
  atom[i++] = net_wm_window_type_toolbar;
  atom[i++] = net_wm_window_type_menu;
  atom[i++] = net_wm_window_type_utility;
  atom[i++] = net_wm_window_type_splash;
  atom[i++] = net_wm_window_type_dialog;
  atom[i++] = net_wm_window_type_dropdown_menu;
  atom[i++] = net_wm_window_type_popup_menu;
  atom[i++] = net_wm_window_type_tooltip;
  atom[i++] = net_wm_window_type_notification;
  atom[i++] = net_wm_window_type_combo;
  atom[i++] = net_wm_window_type_dnd;
  atom[i++] = net_wm_window_type_normal;

  atom[i++] = net_wm_state;
  /*    atom[i++] = net_wm_state_modal; *//* XXX: not sure where/when to use it. */
  atom[i++] = net_wm_state_sticky;
  atom[i++] = net_wm_state_shaded;
  atom[i++] = net_wm_state_maximized_horz;
  atom[i++] = net_wm_state_maximized_vert;
  atom[i++] = net_wm_state_skip_taskbar;
  atom[i++] = net_wm_state_skip_pager;
  atom[i++] = net_wm_state_hidden;
  atom[i++] = net_wm_state_fullscreen;
  atom[i++] = net_wm_state_above;
  atom[i++] = net_wm_state_below;

  atom[i++] = net_wm_allowed_actions;
  atom[i++] = net_wm_action_move;
  atom[i++] = net_wm_action_resize;
  atom[i++] = net_wm_action_minimize;
  atom[i++] = net_wm_action_shade;
  atom[i++] = net_wm_action_stick;
  atom[i++] = net_wm_action_maximize_horz;
  atom[i++] = net_wm_action_maximize_vert;
  atom[i++] = net_wm_action_fullscreen;
  atom[i++] = net_wm_action_change_desktop;
  atom[i++] = net_wm_action_close;

  atom[i++] = net_wm_strut;
  atom[i++] = net_wm_icon_geometry;
  atom[i++] = net_wm_icon;
  atom[i++] = net_wm_handled_icons;
  atom[i++] = net_wm_window_opacity;

  atom[i++] = net_frame_extents;

  atom[i++] = net_wm_name;
  atom[i++] = net_wm_icon_name;

  XChangeProperty(dpy, scr->root_win, net_supported, XA_ATOM, 32, PropModeReplace, (unsigned char *)atom, i);

  /* set supporting wm hint */
  XChangeProperty(dpy, scr->root_win, net_supporting_wm_check, XA_WINDOW, 32,
                  PropModeReplace, (unsigned char *)&scr->info_window, 1);

  XChangeProperty(dpy, scr->info_window, net_supporting_wm_check, XA_WINDOW,
                  32, PropModeReplace, (unsigned char *)&scr->info_window, 1);
}

void wNETWMUpdateDesktop(WScreen *scr)
{
  long *views, sizes[2];
  int count, i;

  if (scr->workspace_count == 0)
    return;

  count = scr->workspace_count * 2;
  views = wmalloc(sizeof(long) * count);
  sizes[0] = scr->scr_width;
  sizes[1] = scr->scr_height;

  for (i = 0; i < scr->workspace_count; i++) {
    views[2 * i + 0] = 0;
    views[2 * i + 1] = 0;
  }

  XChangeProperty(dpy, scr->root_win, net_desktop_geometry, XA_CARDINAL, 32,
                  PropModeReplace, (unsigned char *)sizes, 2);

  XChangeProperty(dpy, scr->root_win, net_desktop_viewport, XA_CARDINAL, 32,
                  PropModeReplace, (unsigned char *)views, count);

  wfree(views);
}

int wNETWMGetCurrentDesktopFromHint(WScreen *scr)
{
  int count;
  unsigned char *prop;

  prop = PropGetCheckProperty(scr->root_win, net_current_desktop, XA_CARDINAL, 0, 1, &count);
  if (prop) {
    int desktop = *(long *)prop;
    XFree(prop);
    return desktop;
  }
  return -1;
}

/*
 * Find the best icon to be used by Window Maker for appicon/miniwindows.
 * Currently the algorithm is to take the image with the size closest
 * to icon_size x icon_size, but never bigger than that.
 *
 * This algorithm is very poorly implemented and needs to be redone (it can
 * easily select images with very large widths and very small heights over
 * square images, if the area of the former is closer to the desired one).
 *
 * The logic can also be changed to accept bigger images and scale them down.
 */
static unsigned long *findBestIcon(unsigned long *data, unsigned long items)
{
  int size, wanted, d;
  unsigned long i, distance;
  unsigned long *icon;

  /* Use only 75% of icon_size. For 64x64 this means 48x48.
   * This leaves room around the icon for the miniwindow title and
   * results in better overall aesthetics -Dan */
  wanted = (wPreferences.icon_size*0.75) * (wPreferences.icon_size*0.75);

  for (icon = NULL, distance = wanted, i = 0L; i < items - 1;) {
    size = data[i] * data[i + 1];
    if (size == 0)
      break;
    d = wanted - size;
    if (d >= 0 && d <= distance && (i + size + 2) <= items) {
      distance = d;
      icon = &data[i];
    }
    i += size + 2;
  }

  return icon;
}

static RImage *makeRImageFromARGBData(unsigned long *data)
{
  int size, width, height, i;
  RImage *image;
  unsigned char *imgdata;
  unsigned long pixel;

  width = data[0];
  height = data[1];
  size = width * height;

  if (size == 0)
    return NULL;

  image = RCreateImage(width, height, True);

  for (imgdata = image->data, i = 2; i < size + 2; i++, imgdata += 4) {
    pixel = data[i];
    imgdata[3] = (pixel >> 24) & 0xff;	/* A */
    imgdata[0] = (pixel >> 16) & 0xff;	/* R */
    imgdata[1] = (pixel >> 8) & 0xff;	/* G */
    imgdata[2] = (pixel >> 0) & 0xff;	/* B */
  }

  return image;
}

RImage *get_window_image_from_x11(Window window)
{
  RImage *image;
  Atom type;
  int format;
  unsigned long items, rest;
  unsigned long *property, *data;

  /* Get the icon from X11 Window */
  if (XGetWindowProperty(dpy, window, net_wm_icon, 0L, LONG_MAX,
                         False, XA_CARDINAL, &type, &format, &items, &rest,
                         (unsigned char **)&property) != Success || !property)
    return NULL;

  if (type != XA_CARDINAL || format != 32 || items < 2) {
    XFree(property);
    return NULL;
  }

  /* Find the best icon */
  data = findBestIcon(property, items);
  if (!data) {
    XFree(property);
    return NULL;
  }

  /* Save the best icon in the X11 icon */
  image = makeRImageFromARGBData(data);

  XFree(property);

  /* Resize the image to the correct value */
  image = wIconValidateIconSize(image, wPreferences.icon_size);

  return image;
}

static void updateIconImage(WWindow *wwin)
{
  /* Remove the icon image from X11 */
  if (wwin->net_icon_image)
    RReleaseImage(wwin->net_icon_image);

  /* Save the icon in the X11 icon */
  wwin->net_icon_image = get_window_image_from_x11(wwin->client_win);

  /* Refresh the Window Icon */
  if (wwin->icon)
    wIconUpdate(wwin->icon);

  /* Refresh the application icon */
  WApplication *app = wApplicationOf(wwin->main_window);
  if (app && app->app_icon) {
    WWindow *app_owner = app->app_icon->icon->owner;
    if (app_owner && !app_owner->net_icon_image) {
      app_owner->net_icon_image = get_window_image_from_x11(wwin->client_win);
      wIconUpdate(app->app_icon->icon);
      wAppIconPaint(app->app_icon);
    }
  }
}

static void updateWindowOpacity(WWindow *wwin)
{
  Atom type;
  int format;
  unsigned long items, rest;
  unsigned long *property;

  if (!wwin->frame)
    return;

  /* We don't care about this ourselves, but other programs need us to copy
   * this to the frame window. */
  if (XGetWindowProperty(dpy, wwin->client_win, net_wm_window_opacity, 0L, 1L,
                         False, XA_CARDINAL, &type, &format, &items, &rest,
                         (unsigned char **)&property) != Success)
    return;

  if (type == None) {
    XDeleteProperty(dpy, wwin->frame->core->window, net_wm_window_opacity);
  } else if (type == XA_CARDINAL && format == 32 && items == 1 && property) {
    XChangeProperty(dpy, wwin->frame->core->window, net_wm_window_opacity,
                    XA_CARDINAL, 32, PropModeReplace, (unsigned char *)property, 1L);
  }

  if (property)
    XFree(property);
}

static void updateShowDesktop(WScreen *scr, Bool show)
{
  long foo;

  foo = (show == True);
  XChangeProperty(dpy, scr->root_win, net_showing_desktop, XA_CARDINAL, 32,
                  PropModeReplace, (unsigned char *)&foo, 1);
}

static void wNETWMShowingDesktop(WScreen *scr, Bool show)
{
  if (show && scr->netdata->show_desktop == NULL) {
    WWindow *tmp, **wins;
    int i = 0;

    wins = (WWindow **) wmalloc(sizeof(WWindow *) * (scr->window_count + 1));

    tmp = scr->focused_window;
    while (tmp) {
      if (!tmp->flags.hidden && !tmp->flags.miniaturized && !WFLAGP(tmp, skip_window_list)) {

        wins[i++] = tmp;
        tmp->flags.skip_next_animation = 1;
        tmp->flags.net_show_desktop = 1;
        wIconifyWindow(tmp);
      }

      tmp = tmp->prev;
    }
    wins[i++] = NULL;

    scr->netdata->show_desktop = wins;
    updateShowDesktop(scr, True);
  } else if (scr->netdata->show_desktop != NULL) {
    /* FIXME: get rid of workspace flashing ! */
    int ws = scr->current_workspace;
    WWindow **tmp;
    for (tmp = scr->netdata->show_desktop; *tmp; ++tmp) {
      wDeiconifyWindow(*tmp);
      (*tmp)->flags.net_show_desktop = 0;
    }
    if (ws != scr->current_workspace)
      wWorkspaceChange(scr, ws, NULL);
    wfree(scr->netdata->show_desktop);
    scr->netdata->show_desktop = NULL;
    updateShowDesktop(scr, False);
  }
}

void wNETWMInitStuff(WScreen *scr)
{
  NetData *data;
  int i;

#ifdef DEBUG_WMSPEC
  wmessage("wNETWMInitStuff");
#endif

#ifdef HAVE_XINTERNATOMS
  {
    Atom atoms[wlengthof(atomNames)];
    char *names[wlengthof(atomNames)];

    for (i = 0; i < wlengthof(atomNames); ++i)
      names[i] = atomNames[i].name;

    XInternAtoms(dpy, &names[0], wlengthof(atomNames), False, atoms);
    for (i = 0; i < wlengthof(atomNames); ++i)
      *atomNames[i].atom = atoms[i];

  }
#else
  for (i = 0; i < wlengthof(atomNames); i++)
    *atomNames[i].atom = XInternAtom(dpy, atomNames[i].name, False);
#endif

  data = wmalloc(sizeof(NetData));
  data->scr = scr;
  data->strut = NULL;
  data->show_desktop = NULL;

  scr->netdata = data;

  setSupportedHints(scr);

  WMAddNotificationObserver(observer, data, WMNManaged, NULL);
  WMAddNotificationObserver(observer, data, WMNUnmanaged, NULL);
  WMAddNotificationObserver(observer, data, WMNChangedWorkspace, NULL);
  WMAddNotificationObserver(observer, data, WMNChangedState, NULL);
  WMAddNotificationObserver(observer, data, WMNChangedFocus, NULL);
  WMAddNotificationObserver(observer, data, WMNChangedStacking, NULL);
  WMAddNotificationObserver(observer, data, WMNChangedName, NULL);

  WMAddNotificationObserver(wsobserver, data, WMNWorkspaceCreated, NULL);
  WMAddNotificationObserver(wsobserver, data, WMNWorkspaceDestroyed, NULL);
  WMAddNotificationObserver(wsobserver, data, WMNWorkspaceChanged, NULL);
  WMAddNotificationObserver(wsobserver, data, WMNWorkspaceNameChanged, NULL);

  updateClientList(scr);
  updateClientListStacking(scr, NULL);
  updateWorkspaceCount(scr);
  updateWorkspaceNames(scr);
  updateShowDesktop(scr, False);

  wScreenUpdateUsableArea(scr);
}

void wNETWMCleanup(WScreen *scr)
{
  int i;

  for (i = 0; i < wlengthof(atomNames); i++)
    XDeleteProperty(dpy, scr->root_win, *atomNames[i].atom);
}

void wNETWMUpdateActions(WWindow *wwin, Bool del)
{
  Atom action[10];	/* nr of actions atoms defined */
  int i = 0;

  if (del) {
    XDeleteProperty(dpy, wwin->client_win, net_wm_allowed_actions);
    return;
  }

  if (IS_MOVABLE(wwin))
    action[i++] = net_wm_action_move;

  if (IS_RESIZABLE(wwin))
    action[i++] = net_wm_action_resize;

  if (!WFLAGP(wwin, no_miniaturizable))
    action[i++] = net_wm_action_minimize;

  if (!WFLAGP(wwin, no_shadeable))
    action[i++] = net_wm_action_shade;

  /*    if (!WFLAGP(wwin, no_stickable)) */
  action[i++] = net_wm_action_stick;

  /*    if (!(WFLAGP(wwin, no_maximizeable) & MAX_HORIZONTAL)) */
  if (IS_RESIZABLE(wwin))
    action[i++] = net_wm_action_maximize_horz;

  /*    if (!(WFLAGP(wwin, no_maximizeable) & MAX_VERTICAL)) */
  if (IS_RESIZABLE(wwin))
    action[i++] = net_wm_action_maximize_vert;

  /*    if (!WFLAGP(wwin, no_fullscreen)) */
  action[i++] = net_wm_action_fullscreen;

  /*    if (!WFLAGP(wwin, no_change_desktop)) */
  action[i++] = net_wm_action_change_desktop;

  if (!WFLAGP(wwin, no_closable))
    action[i++] = net_wm_action_close;

  XChangeProperty(dpy, wwin->client_win, net_wm_allowed_actions,
                  XA_ATOM, 32, PropModeReplace, (unsigned char *)action, i);
}

void wNETWMUpdateWorkarea(WScreen *scr)
{
  WArea total_usable;
  int nb_workspace;

  if (!scr->netdata) {
    /* If the _NET_xxx were not initialised, it not necessary to do anything */
    return;
  }

  if (!scr->usableArea) {
    /* If we don't have any info, we fall back on using the complete screen area */
    total_usable.x1 = 0;
    total_usable.y1 = 0;
    total_usable.x2 = scr->scr_width;
    total_usable.y2 = scr->scr_height;

  } else {
    int i;

    /*
     * the _NET_WORKAREA is supposed to contain the total area of the screen that
     * is usable, so we merge the areas from all xrandr sub-screens
     */
    total_usable = scr->usableArea[0];

    for (i = 1; i < wScreenHeads(scr); i++) {
      /* The merge is not subtle because _NET_WORKAREA does not need more */
      if (scr->usableArea[i].x1 < total_usable.x1)
        total_usable.x1 = scr->usableArea[i].x1;

      if (scr->usableArea[i].y1 < total_usable.y1)
        total_usable.y1 = scr->usableArea[i].y1;

      if (scr->usableArea[i].x2 > total_usable.x2)
        total_usable.x2 = scr->usableArea[i].x2;

      if (scr->usableArea[i].y2 > total_usable.y2)
        total_usable.y2 = scr->usableArea[i].y2;
    }

  }

  /* We are expected to repeat the information for each workspace */
  if (scr->workspace_count == 0)
    nb_workspace = 1;
  else
    nb_workspace = scr->workspace_count;

  {
    long property_value[nb_workspace * 4];
    int i;

    for (i = 0; i < nb_workspace; i++) {
      property_value[4 * i + 0] = total_usable.x1;
      property_value[4 * i + 1] = total_usable.y1;
      property_value[4 * i + 2] = total_usable.x2 - total_usable.x1;
      property_value[4 * i + 3] = total_usable.y2 - total_usable.y1;
    }

    XChangeProperty(dpy, scr->root_win, net_workarea, XA_CARDINAL, 32, PropModeReplace,
                    (unsigned char *) property_value, nb_workspace * 4);
  }
}

Bool wNETWMGetUsableArea(WScreen *scr, int head, WArea *area)
{
  WReservedArea *cur;
  WMRect rect;

  if (!scr->netdata || !scr->netdata->strut)
    return False;

  area->x1 = area->y1 = area->x2 = area->y2 = 0;

  for (cur = scr->netdata->strut; cur; cur = cur->next) {
    WWindow *wwin = wWindowFor(cur->window);
    if (wWindowTouchesHead(wwin, head)) {
      if (cur->area.x1 > area->x1)
        area->x1 = cur->area.x1;
      if (cur->area.y1 > area->y1)
        area->y1 = cur->area.y1;
      if (cur->area.x2 > area->x2)
        area->x2 = cur->area.x2;
      if (cur->area.y2 > area->y2)
        area->y2 = cur->area.y2;
    }
  }

  if (area->x1 == 0 && area->x2 == 0 && area->y1 == 0 && area->y2 == 0)
    return False;

  rect = wGetRectForHead(scr, head);

  area->x1 = rect.pos.x + area->x1;
  area->x2 = rect.pos.x + rect.size.width - area->x2;
  area->y1 = rect.pos.y + area->y1;
  area->y2 = rect.pos.y + rect.size.height - area->y2;

  return True;
}

static void updateClientList(WScreen *scr)
{
  WWindow *wwin;
  Window *windows;
  int count;

  windows = (Window *) wmalloc(sizeof(Window) * (scr->window_count + 1));

  count = 0;
  wwin = scr->focused_window;
  while (wwin) {
    windows[count++] = wwin->client_win;
    wwin = wwin->prev;
  }
  XChangeProperty(dpy, scr->root_win, net_client_list, XA_WINDOW, 32,
                  PropModeReplace, (unsigned char *)windows, count);

  wfree(windows);
  XFlush(dpy);
}

static void updateClientListStacking(WScreen *scr, WWindow *wwin_excl)
{
  WWindow *wwin;
  Window *client_list, *client_list_reverse;
  int client_count, i;
  WCoreWindow *tmp;
  WMBagIterator iter;

  /* update client list */
  i = scr->window_count + 1;
  client_list = (Window *) wmalloc(sizeof(Window) * i);
  client_list_reverse = (Window *) wmalloc(sizeof(Window) * i);

  client_count = 0;
  WM_ETARETI_BAG(scr->stacking_list, tmp, iter) {
    while (tmp) {
      wwin = wWindowFor(tmp->window);
      /* wwin_excl is a window to exclude from the list
         (e.g. it's now unmanaged) */
      if (wwin && (wwin != wwin_excl))
        client_list[client_count++] = wwin->client_win;
      tmp = tmp->stacking->under;
    }
  }

  for (i = 0; i < client_count; i++) {
    Window w = client_list[client_count - i - 1];
    client_list_reverse[i] = w;
  }

  XChangeProperty(dpy, scr->root_win, net_client_list_stacking, XA_WINDOW, 32,
                  PropModeReplace, (unsigned char *)client_list_reverse, client_count);

  wfree(client_list);
  wfree(client_list_reverse);

  XFlush(dpy);
}

static void updateWorkspaceCount(WScreen *scr)
{				/* changeable */
  long count;

  count = scr->workspace_count;

  XChangeProperty(dpy, scr->root_win, net_number_of_desktops, XA_CARDINAL,
                  32, PropModeReplace, (unsigned char *)&count, 1);
}

static void updateCurrentWorkspace(WScreen *scr)
{				/* changeable */
  long count;

  count = scr->current_workspace;

  XChangeProperty(dpy, scr->root_win, net_current_desktop, XA_CARDINAL, 32,
                  PropModeReplace, (unsigned char *)&count, 1);
}

static void updateWorkspaceNames(WScreen *scr)
{
  char buf[MAX_WORKSPACES * (MAX_WORKSPACENAME_WIDTH + 1)], *pos;
  unsigned int i, len, curr_size;

  pos = buf;
  len = 0;
  for (i = 0; i < scr->workspace_count; i++) {
    curr_size = strlen(scr->workspaces[i]->name);
    strcpy(pos, scr->workspaces[i]->name);
    pos += (curr_size + 1);
    len += (curr_size + 1);
  }

  XChangeProperty(dpy, scr->root_win, net_desktop_names, utf8_string, 8,
                  PropModeReplace, (unsigned char *)buf, len);
}

static void updateFocusHint(WScreen *scr)
{				/* changeable */
  Window window;

  if (!scr->focused_window || !scr->focused_window->flags.focused)
    window = None;
  else
    window = scr->focused_window->client_win;

  XChangeProperty(dpy, scr->root_win, net_active_window, XA_WINDOW, 32,
                  PropModeReplace, (unsigned char *)&window, 1);
}

static void updateWorkspaceHint(WWindow *wwin, Bool fake, Bool del)
{
  long l;

  if (del) {
    XDeleteProperty(dpy, wwin->client_win, net_wm_desktop);
  } else {
    l = ((fake || IS_OMNIPRESENT(wwin)) ? -1 : wwin->frame->workspace);
    XChangeProperty(dpy, wwin->client_win, net_wm_desktop, XA_CARDINAL,
                    32, PropModeReplace, (unsigned char *)&l, 1);
  }
}

static void updateStateHint(WWindow *wwin, Bool changedWorkspace, Bool del)
{				/* changeable */
  if (del) {
    XDeleteProperty(dpy, wwin->client_win, net_wm_state);
  } else {
    Atom state[15];	/* nr of defined state atoms */
    int i = 0;

    if (changedWorkspace || (wPreferences.sticky_icons && !IS_OMNIPRESENT(wwin)))
      updateWorkspaceHint(wwin, False, False);

    if (IS_OMNIPRESENT(wwin))
      state[i++] = net_wm_state_sticky;
    if (wwin->flags.shaded)
      state[i++] = net_wm_state_shaded;
    if (wwin->flags.maximized & MAX_HORIZONTAL)
      state[i++] = net_wm_state_maximized_horz;
    if (wwin->flags.maximized & MAX_VERTICAL)
      state[i++] = net_wm_state_maximized_vert;
    if (WFLAGP(wwin, skip_window_list))
      state[i++] = net_wm_state_skip_taskbar;
    if (wwin->flags.net_skip_pager)
      state[i++] = net_wm_state_skip_pager;
    if ((wwin->flags.hidden || wwin->flags.miniaturized) && !wwin->flags.net_show_desktop) {
      state[i++] = net_wm_state_hidden;
      state[i++] = net_wm_state_skip_pager;

      if (wwin->flags.miniaturized && wPreferences.sticky_icons) {
        if (!IS_OMNIPRESENT(wwin))
          updateWorkspaceHint(wwin, True, False);
        state[i++] = net_wm_state_sticky;
      }
    }
    if (WFLAGP(wwin, sunken))
      state[i++] = net_wm_state_below;
    if (WFLAGP(wwin, floating))
      state[i++] = net_wm_state_above;
    if (wwin->flags.fullscreen)
      state[i++] = net_wm_state_fullscreen;

    XChangeProperty(dpy, wwin->client_win, net_wm_state, XA_ATOM, 32,
                    PropModeReplace, (unsigned char *)state, i);
  }
}

static Bool updateStrut(WScreen *scr, Window w, Bool adding)
{
  WReservedArea *area;
  Bool hasState = False;

  if (adding) {
    Atom type_ret;
    int fmt_ret;
    unsigned long nitems_ret, bytes_after_ret;
    long *data = NULL;

    if ((XGetWindowProperty(dpy, w, net_wm_strut, 0, 4, False,
                            XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                            &bytes_after_ret, (unsigned char **)&data) == Success && data) ||
        ((XGetWindowProperty(dpy, w, net_wm_strut_partial, 0, 12, False,
                             XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                             &bytes_after_ret, (unsigned char **)&data) == Success && data))) {

      /* XXX: This is strictly incorrect in the case of net_wm_strut_partial...
       * Discard the start and end properties from the partial strut and treat it as
       * a (deprecated) strut.
       * This means we are marking the whole width or height of the screen as
       * reserved, which is not necessarily what the strut defines.  However for the
       * purposes of determining placement or maximization it's probably good enough.
       */
      area = (WReservedArea *) wmalloc(sizeof(WReservedArea));
      area->area.x1 = data[0];
      area->area.x2 = data[1];
      area->area.y1 = data[2];
      area->area.y2 = data[3];

      area->window = w;

      area->next = scr->netdata->strut;
      scr->netdata->strut = area;

      XFree(data);
      hasState = True;
    }
  } else {
    /* deleting */
    area = scr->netdata->strut;

    if (area) {
      if (area->window == w) {
        scr->netdata->strut = area->next;
        wfree(area);
        hasState = True;
      } else {
        while (area->next && area->next->window != w)
          area = area->next;

        if (area->next) {
          WReservedArea *next;

          next = area->next->next;
          wfree(area->next);
          area->next = next;

          hasState = True;
        }
      }
    }
  }

  return hasState;
}

static int getWindowLayer(WWindow *wwin)
{
  int layer = NSNormalWindowLevel;

  if (wwin->type == net_wm_window_type_desktop) {
    layer = NSDesktopWindowLevel;
  } else if (wwin->type == net_wm_window_type_dock) {
    layer = NSDockWindowLevel;
  } else if (wwin->type == net_wm_window_type_toolbar) {
    layer = NSMainMenuWindowLevel;
  } else if (wwin->type == net_wm_window_type_menu) {
    layer = NSSubmenuWindowLevel;
  } else if (wwin->type == net_wm_window_type_utility) {
  } else if (wwin->type == net_wm_window_type_splash) {
  } else if (wwin->type == net_wm_window_type_dialog) {
    if (wwin->transient_for) {
      WWindow *parent = wWindowFor(wwin->transient_for);
      if (parent && parent->flags.fullscreen)
        layer = NSNormalWindowLevel;
    }
    /* //layer = WMPopUpLevel; // this seems a bad idea -Dan */
  } else if (wwin->type == net_wm_window_type_dropdown_menu) {
    layer = NSSubmenuWindowLevel;
  } else if (wwin->type == net_wm_window_type_popup_menu) {
    layer = NSSubmenuWindowLevel;
  } else if (wwin->type == net_wm_window_type_tooltip) {
  } else if (wwin->type == net_wm_window_type_notification) {
    layer = NSPopUpMenuWindowLevel;
  } else if (wwin->type == net_wm_window_type_combo) {
    layer = NSSubmenuWindowLevel;
  } else if (wwin->type == net_wm_window_type_dnd) {
  } else if (wwin->type == net_wm_window_type_normal) {
  }

  if (wwin->client_flags.sunken && NSSunkenWindowLevel < layer)
    layer = NSSunkenWindowLevel;
  if (wwin->client_flags.floating && NSFloatingWindowLevel > layer)
    layer = NSFloatingWindowLevel;

  return layer;
}

static void doStateAtom(WWindow *wwin, Atom state, int set, Bool init)
{
  if (state == net_wm_state_sticky) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !IS_OMNIPRESENT(wwin);

    if (set != wwin->flags.omnipresent)
      wWindowSetOmnipresent(wwin, set);

  } else if (state == net_wm_state_shaded) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !wwin->flags.shaded;

    if (init) {
      wwin->flags.shaded = set;
    } else {
      if (set)
        wShadeWindow(wwin);
      else
        wUnshadeWindow(wwin);
    }
  } else if (state == net_wm_state_skip_taskbar) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !wwin->client_flags.skip_window_list;

    wwin->client_flags.skip_window_list = set;
  } else if (state == net_wm_state_skip_pager) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !wwin->flags.net_skip_pager;

    wwin->flags.net_skip_pager = set;
  } else if (state == net_wm_state_maximized_vert) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !(wwin->flags.maximized & MAX_VERTICAL);

    if (init) {
      wwin->flags.maximized |= (set ? MAX_VERTICAL : 0);
    } else {
      if (set)
        wMaximizeWindow(wwin, wwin->flags.maximized | MAX_VERTICAL);
      else
        wMaximizeWindow(wwin, wwin->flags.maximized & ~MAX_VERTICAL);
    }
  } else if (state == net_wm_state_maximized_horz) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !(wwin->flags.maximized & MAX_HORIZONTAL);

    if (init) {
      wwin->flags.maximized |= (set ? MAX_HORIZONTAL : 0);
    } else {
      if (set)
        wMaximizeWindow(wwin, wwin->flags.maximized | MAX_HORIZONTAL);
      else
        wMaximizeWindow(wwin, wwin->flags.maximized & ~MAX_HORIZONTAL);
    }
  } else if (state == net_wm_state_hidden) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !(wwin->flags.miniaturized);

    if (init) {
      wwin->flags.miniaturized = set;
    } else {
      if (set)
        wIconifyWindow(wwin);
      else
        wDeiconifyWindow(wwin);
    }
  } else if (state == net_wm_state_fullscreen) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !(wwin->flags.fullscreen);

    if (init) {
      wwin->flags.fullscreen = set;
    } else {
      if (set)
        wFullscreenWindow(wwin);
      else
        wUnfullscreenWindow(wwin);
    }
  } else if (state == net_wm_state_above) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !(wwin->client_flags.floating);

    if (init) {
      wwin->client_flags.floating = set;
    } else {
      wwin->client_flags.floating = set;
      ChangeStackingLevel(wwin->frame->core, getWindowLayer(wwin));
    }

  } else if (state == net_wm_state_below) {
    if (set == _NET_WM_STATE_TOGGLE)
      set = !(wwin->client_flags.sunken);

    if (init) {
      wwin->client_flags.sunken = set;
    } else {
      wwin->client_flags.sunken = set;
      ChangeStackingLevel(wwin->frame->core, getWindowLayer(wwin));
    }

  } else {
#ifdef DEBUG_WMSPEC
    wmessage("doStateAtom unknown atom %s set %d", XGetAtomName(dpy, state), set);
#endif
  }
}

static void removeIcon(WWindow *wwin)
{
  if (wwin->icon == NULL)
    return;
  if (wwin->flags.miniaturized && wwin->icon->mapped) {
    XUnmapWindow(dpy, wwin->icon->core->window);
    RemoveFromStackList(wwin->icon->core);
    wIconDestroy(wwin->icon);
    wwin->icon = NULL;
  }
}

static Bool handleWindowType(WWindow *wwin, Atom type, int *layer)
{
  Bool ret = True;

  if (type == net_wm_window_type_desktop) {
    wwin->client_flags.no_titlebar = 1;
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_border = 1;
    wwin->client_flags.no_resizebar = 1;
    wwin->client_flags.no_shadeable = 1;
    wwin->client_flags.no_movable = 1;
    wwin->client_flags.omnipresent = 1;
    wwin->client_flags.skip_window_list = 1;
    wwin->client_flags.skip_switchpanel = 1;
    wwin->client_flags.dont_move_off = 1;
    wwin->client_flags.no_appicon = 1;
    wwin->flags.net_skip_pager = 1;
    wwin->frame_x = 0;
    wwin->frame_y = 0;
  } else if (type == net_wm_window_type_dock) {
    wwin->client_flags.no_titlebar = 1;
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_border = 1;	/* XXX: really not a single decoration. */
    wwin->client_flags.no_resizebar = 1;
    wwin->client_flags.no_shadeable = 1;
    wwin->client_flags.no_movable = 1;
    wwin->client_flags.omnipresent = 1;
    wwin->client_flags.skip_window_list = 1;
    wwin->client_flags.skip_switchpanel = 1;
    wwin->client_flags.dont_move_off = 1;
    wwin->flags.net_skip_pager = 1;
  } else if (type == net_wm_window_type_toolbar ||
             type == net_wm_window_type_menu) {
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_resizebar = 1;
    wwin->client_flags.no_shadeable = 1;
    wwin->client_flags.skip_window_list = 1;
    wwin->client_flags.skip_switchpanel = 1;
    wwin->client_flags.dont_move_off = 1;
    wwin->client_flags.no_appicon = 1;
  } else if (type == net_wm_window_type_dropdown_menu ||
             type == net_wm_window_type_popup_menu ||
             type == net_wm_window_type_combo) {
    wwin->client_flags.no_titlebar = 1;
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_resizebar = 1;
    wwin->client_flags.no_shadeable = 1;
    wwin->client_flags.skip_window_list = 1;
    wwin->client_flags.skip_switchpanel = 1;
    wwin->client_flags.dont_move_off = 1;
    wwin->client_flags.no_appicon = 1;
  } else if (type == net_wm_window_type_utility) {
    wwin->client_flags.no_appicon = 1;
  } else if (type == net_wm_window_type_splash) {
    wwin->client_flags.no_titlebar = 1;
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_resizebar = 1;
    wwin->client_flags.no_shadeable = 1;
    wwin->client_flags.no_movable = 1;
    wwin->client_flags.skip_window_list = 1;
    wwin->client_flags.skip_switchpanel = 1;
    wwin->client_flags.dont_move_off = 1;
    wwin->client_flags.no_appicon = 1;
    wwin->flags.net_skip_pager = 1;
  } else if (type == net_wm_window_type_dialog) {
    /* These also seem a bad idea in our context -Dan
    // wwin->client_flags.skip_window_list = 1;
    // wwin->client_flags.no_appicon = 1;
    */
  } else if (wwin->type == net_wm_window_type_tooltip) {
    wwin->client_flags.no_titlebar = 1;
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_resizebar = 1;
    wwin->client_flags.no_shadeable = 1;
    wwin->client_flags.no_movable = 1;
    wwin->client_flags.skip_window_list = 1;
    wwin->client_flags.skip_switchpanel = 1;
    wwin->client_flags.dont_move_off = 1;
    wwin->client_flags.no_appicon = 1;
    wwin->client_flags.no_focusable = 1;
    wwin->flags.net_skip_pager = 1;
  } else if (wwin->type == net_wm_window_type_notification) {
    wwin->client_flags.no_titlebar = 1;
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_border = 1;
    wwin->client_flags.no_resizebar = 1;
    wwin->client_flags.no_shadeable = 1;
    wwin->client_flags.no_movable = 1;
    wwin->client_flags.omnipresent = 1;
    wwin->client_flags.skip_window_list = 1;
    wwin->client_flags.skip_switchpanel = 1;
    wwin->client_flags.dont_move_off = 1;
    wwin->client_flags.no_hide_others= 1;
    wwin->client_flags.no_appicon = 1;
    wwin->client_flags.no_focusable = 1;
    wwin->flags.net_skip_pager = 1;
  } else if (wwin->type == net_wm_window_type_dnd) {
    wwin->client_flags.no_titlebar = 1;
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_border = 1;
    wwin->client_flags.no_resizebar = 1;
    wwin->client_flags.no_shadeable = 1;
    wwin->client_flags.no_movable = 1;
    wwin->client_flags.skip_window_list = 1;
    wwin->client_flags.skip_switchpanel = 1;
    wwin->client_flags.dont_move_off = 1;
    wwin->client_flags.no_appicon = 1;
    wwin->flags.net_skip_pager = 1;
  } else if (type == net_wm_window_type_normal) {
  } else {
    ret = False;
  }

  wwin->type = type;
  *layer = getWindowLayer(wwin);

  return ret;
}

void wNETWMPositionSplash(WWindow *wwin, int *x, int *y, int width, int height)
{
  if (wwin->type == net_wm_window_type_splash) {
    WScreen *scr = wwin->screen_ptr;
    WMRect rect = wGetRectForHead(scr, wGetHeadForPointerLocation(scr));
    *x = rect.pos.x + (rect.size.width - width) / 2;
    *y = rect.pos.y + (rect.size.height - height) / 2;
  }
}

static void updateWindowType(WWindow *wwin)
{
  Atom type_ret;
  int fmt_ret, layer;
  unsigned long nitems_ret, bytes_after_ret;
  long *data = NULL;

  if (XGetWindowProperty(dpy, wwin->client_win, net_wm_window_type, 0, 1,
                         False, XA_ATOM, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) == Success && data) {

    int i;
    Atom *type = (Atom *) data;
    for (i = 0; i < nitems_ret; ++i) {
      if (handleWindowType(wwin, type[i], &layer))
        break;
    }
    XFree(data);
  }

  if (wwin->frame != NULL) {
    ChangeStackingLevel(wwin->frame->core, layer);
    wwin->frame->flags.need_texture_change = 1;
    wWindowConfigureBorders(wwin);
    wFrameWindowPaint(wwin->frame);
    wNETWMUpdateActions(wwin, False);
  }
}

void wNETWMCheckClientHints(WWindow *wwin, int *layer, int *workspace)
{
  Atom type_ret;
  int fmt_ret, i;
  unsigned long nitems_ret, bytes_after_ret;
  long *data = NULL;

  if (XGetWindowProperty(dpy, wwin->client_win, net_wm_desktop, 0, 1, False,
                         XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) == Success && data) {

    long desktop = *data;
    XFree(data);

    if (desktop == -1)
      wwin->client_flags.omnipresent = 1;
    else
      *workspace = desktop;
  }

  if (XGetWindowProperty(dpy, wwin->client_win, net_wm_state, 0, 1, False,
                         XA_ATOM, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) == Success && data) {

    Atom *state = (Atom *) data;
    for (i = 0; i < nitems_ret; ++i)
      doStateAtom(wwin, state[i], _NET_WM_STATE_ADD, True);

    XFree(data);
  }

  if (XGetWindowProperty(dpy, wwin->client_win, net_wm_window_type, 0, 1, False,
                         XA_ATOM, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) == Success && data) {

    Atom *type = (Atom *) data;
    for (i = 0; i < nitems_ret; ++i) {
      if (handleWindowType(wwin, type[i], layer))
        break;
    }
    XFree(data);
  }

  wNETWMUpdateActions(wwin, False);
  updateStrut(wwin->screen_ptr, wwin->client_win, False);
  updateStrut(wwin->screen_ptr, wwin->client_win, True);

  wScreenUpdateUsableArea(wwin->screen_ptr);
}

static Bool updateNetIconInfo(WWindow *wwin)
{
  Atom type_ret;
  int fmt_ret;
  unsigned long nitems_ret, bytes_after_ret;
  long *data = NULL;
  Bool hasState = False;
  Bool old_state = wwin->flags.net_handle_icon;

  if (XGetWindowProperty(dpy, wwin->client_win, net_wm_handled_icons, 0, 1, False,
                         XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) == Success && data) {
    long handled = *data;
    wwin->flags.net_handle_icon = (handled != 0);
    XFree(data);
    hasState = True;

  } else {
    wwin->flags.net_handle_icon = False;
  }

  if (XGetWindowProperty(dpy, wwin->client_win, net_wm_icon_geometry, 0, 4, False,
                         XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) == Success && data) {

#ifdef NETWM_PROPER
    if (wwin->flags.net_handle_icon)
#else
      wwin->flags.net_handle_icon = True;
#endif
    {
      wwin->icon_x = data[0];
      wwin->icon_y = data[1];
      wwin->icon_w = data[2];
      wwin->icon_h = data[3];
    }

    XFree(data);
    hasState = True;
  } else {
    wwin->flags.net_handle_icon = False;
  }

  if (wwin->flags.miniaturized && old_state != wwin->flags.net_handle_icon) {
    if (wwin->flags.net_handle_icon) {
      removeIcon(wwin);
    } else {
      wwin->flags.miniaturized = False;
      wwin->flags.skip_next_animation = True;
      wIconifyWindow(wwin);
    }
  }

  return hasState;
}

void wNETWMCheckInitialClientState(WWindow *wwin)
{
#ifdef DEBUG_WMSPEC
  wmessage("wNETWMCheckInitialClientState");
#endif

  wNETWMShowingDesktop(wwin->screen_ptr, False);

  updateWindowType(wwin);
  updateNetIconInfo(wwin);
  updateIconImage(wwin);
}

void wNETWMCheckInitialFrameState(WWindow *wwin)
{
#ifdef DEBUG_WMSPEC
  wmessage("wNETWMCheckInitialFrameState");
#endif

  updateWindowOpacity(wwin);
}

static void handleDesktopNames(WScreen *scr)
{
  unsigned long nitems_ret, bytes_after_ret;
  char *data, *names[32];
  int fmt_ret, i, n;
  Atom type_ret;

  if (XGetWindowProperty(dpy, scr->root_win, net_desktop_names, 0, 1, False,
                         utf8_string, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) != Success)
    return;

  if (data == NULL)
    return;

  if (type_ret != utf8_string || fmt_ret != 8)
    return;

  n = 0;
  names[n] = data;
  for (i = 0; i < nitems_ret; i++) {
    if (data[i] == 0) {
      n++;
      names[n] = &data[i];
    } else if (*names[n] == 0) {
      names[n] = &data[i];
      wWorkspaceRename(scr, n, names[n]);
    }
  }
}

Bool wNETWMProcessClientMessage(XClientMessageEvent *event)
{
  WScreen *scr;
  WWindow *wwin;

#ifdef DEBUG_WMSPEC
  wmessage("processClientMessage type %s",
           XGetAtomName(dpy, event->message_type));
#endif

  scr = wDefaultScreen();
  if (scr) {
    /* generic client messages */
    if (event->message_type == net_current_desktop) {
      wWorkspaceChange(scr, event->data.l[0], NULL);
      return True;

    }
    else if (event->message_type == net_number_of_desktops) {
      long value;

      value = event->data.l[0];
      if (value > scr->workspace_count) {
        wWorkspaceMake(scr, value - scr->workspace_count);
      } else if (value < scr->workspace_count) {
        int i;
        Bool rebuild = False;

        for (i = scr->workspace_count - 1; i >= value; i--) {
          if (!wWorkspaceDelete(scr, i)) {
            rebuild = True;
            break;
          }
        }

        if (rebuild)
          updateWorkspaceCount(scr);
      }
      return True;

    }
    else if (event->message_type == net_showing_desktop) {
      wNETWMShowingDesktop(scr, event->data.l[0]);
      return True;

    }
    else if (event->message_type == net_desktop_names) {
      handleDesktopNames(scr);
      return True;
    }
  }

  /* window specific client messages */

  wwin = wWindowFor(event->window);
  if (!wwin)
    return False;

  if (event->message_type == net_active_window) {
    /*
     * Satisfy a client's focus request only if
     * - request comes from a pager, or
     * - it's explicitly allowed in Advanced Options, or
     * - giving the client the focus does not cause a change in
     *   the active workspace (XXX: or the active head if Xinerama)
     */
    if (wwin->frame->workspace == wwin->screen_ptr->current_workspace /* No workspace change */
        || event->data.l[0] == 2 /* Requested by pager */
        || WFLAGP(wwin, focus_across_wksp) /* Explicitly allowed */) {
      wNETWMShowingDesktop(scr, False);
      wMakeWindowVisible(wwin);
    }
    return True;

  }
  else if (event->message_type == net_close_window) {
    if (!WFLAGP(wwin, no_closable)) {
      if (wwin->protocols.DELETE_WINDOW)
        wClientSendProtocol(wwin, w_global.atom.wm.delete_window,
                            w_global.timestamp.last_event);
    }
    return True;

  }
  else if (event->message_type == net_wm_state) {
    int maximized = wwin->flags.maximized;
    long set = event->data.l[0];

#ifdef DEBUG_WMSPEC
    wmessage("net_wm_state set %ld a1 %s a2 %s", set,
             XGetAtomName(dpy, event->data.l[1]),
             XGetAtomName(dpy, event->data.l[2]));
#endif

    doStateAtom(wwin, (Atom) event->data.l[1], set, False);
    if (event->data.l[2])
      doStateAtom(wwin, (Atom) event->data.l[2], set, False);

    if (wwin->flags.maximized != maximized) {
      if (!wwin->flags.maximized) {
        wwin->flags.maximized = maximized;
        wUnmaximizeWindow(wwin);
      } else {
        wMaximizeWindow(wwin, wwin->flags.maximized);
      }
    }
    updateStateHint(wwin, False, False);
    return True;

  }
  else if (event->message_type == net_wm_handled_icons ||
           event->message_type == net_wm_icon_geometry) {
    updateNetIconInfo(wwin);
    return True;

  }
  else if (event->message_type == net_wm_desktop) {
    long desktop = event->data.l[0];

    if (desktop == -1) {
      wWindowSetOmnipresent(wwin, True);
    } else {
      if (IS_OMNIPRESENT(wwin))
        wWindowSetOmnipresent(wwin, False);
      wWindowChangeWorkspace(wwin, desktop);
    }
    return True;
  }

  return False;
}

void wNETWMCheckClientHintChange(WWindow *wwin, XPropertyEvent *event)
{
#ifdef DEBUG_WMSPEC
  wmessage("%s (%lu) clientHintChange type %s",
           wwin->wm_class, wwin->client_win,
           XGetAtomName(dpy, event->atom));
#endif

  if (event->atom == net_wm_strut || event->atom == net_wm_strut_partial) {
    updateStrut(wwin->screen_ptr, wwin->client_win, False);
    updateStrut(wwin->screen_ptr, wwin->client_win, True);
    wScreenUpdateUsableArea(wwin->screen_ptr);
  }
  else if (event->atom == net_wm_handled_icons ||
           event->atom == net_wm_icon_geometry) {
    updateNetIconInfo(wwin);
  }
  else if (event->atom == net_wm_window_type) {
    updateWindowType(wwin);
  }
  else if (event->atom == net_wm_name) {
    char *name = wNETWMGetWindowName(wwin->client_win);
    wWindowUpdateName(wwin, name);
    if (name)
      wfree(name);
  }
  else if (event->atom == net_wm_icon_name) {
    if (wwin->icon) {
      wIconChangeTitle(wwin->icon, wwin);
      wIconPaint(wwin->icon);
    }
  }
  else if (event->atom == net_wm_icon) {
    updateIconImage(wwin);
  }
  else if (event->atom == net_wm_window_opacity) {
    updateWindowOpacity(wwin);
  }
  /* else if (event->atom == net_wm_state) { */
  /*   updateIconImage(wwin); */
  /* } */
}

int wNETWMGetPidForWindow(Window window)
{
  Atom type_ret;
  int fmt_ret;
  unsigned long nitems_ret, bytes_after_ret;
  long *data = NULL;
  int pid;

  if (XGetWindowProperty(dpy, window, net_wm_pid, 0, 1, False,
                         XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) == Success && data) {
    pid = *data;
    XFree(data);
  } else {
    pid = 0;
  }

  return pid;
}

char *wNETWMGetWindowName(Window window)
{
  char *name;
  char *ret;
  int size;

  name = (char *)PropGetCheckProperty(window, net_wm_name, utf8_string, 0, 0, &size);
  if (name) {
    ret = wstrndup(name, size);
    XFree(name);
  } else {
    ret = NULL;
  }

  return ret;
}

char *wNETWMGetIconName(Window window)
{
  char *name;
  char *ret;
  int size;

  name = (char *)PropGetCheckProperty(window, net_wm_icon_name, utf8_string, 0, 0, &size);
  if (name) {
    ret = wstrndup(name, size);
    XFree(name);
  } else {
    ret = NULL;
  }

  return ret;
}

static void observer(void *self, WMNotification *notif)
{
  WWindow *wwin = (WWindow *) WMGetNotificationObject(notif);
  const char *name = WMGetNotificationName(notif);
  void *data = WMGetNotificationClientData(notif);
  NetData *ndata = (NetData *) self;

  if (strcmp(name, WMNManaged) == 0 && wwin) {
    updateClientList(wwin->screen_ptr);
    updateClientListStacking(wwin->screen_ptr, NULL);
    updateStateHint(wwin, True, False);

    updateStrut(wwin->screen_ptr, wwin->client_win, False);
    updateStrut(wwin->screen_ptr, wwin->client_win, True);
    wScreenUpdateUsableArea(wwin->screen_ptr);
  } else if (strcmp(name, WMNUnmanaged) == 0 && wwin) {
    updateClientList(wwin->screen_ptr);
    updateClientListStacking(wwin->screen_ptr, wwin);
    updateWorkspaceHint(wwin, False, True);
    updateStateHint(wwin, False, True);
    wNETWMUpdateActions(wwin, True);

    updateStrut(wwin->screen_ptr, wwin->client_win, False);
    wScreenUpdateUsableArea(wwin->screen_ptr);
  } else if (strcmp(name, WMNResetStacking) == 0 && wwin) {
    updateClientListStacking(wwin->screen_ptr, NULL);
    updateStateHint(wwin, False, False);
  } else if (strcmp(name, WMNChangedStacking) == 0 && wwin) {
    updateClientListStacking(wwin->screen_ptr, NULL);
    updateStateHint(wwin, False, False);
  } else if (strcmp(name, WMNChangedFocus) == 0) {
    updateFocusHint(ndata->scr);
  } else if (strcmp(name, WMNChangedWorkspace) == 0 && wwin) {
    updateWorkspaceHint(wwin, False, False);
    updateStateHint(wwin, True, False);
  } else if (strcmp(name, WMNChangedState) == 0 && wwin) {
    updateStateHint(wwin, !strcmp(data, "omnipresent"), False);
  }
}

static void wsobserver(void *self, WMNotification *notif)
{
  WScreen *scr = (WScreen *) WMGetNotificationObject(notif);
  const char *name = WMGetNotificationName(notif);

  /* Parameter not used, but tell the compiler that it is ok */
  (void) self;

  if (strcmp(name, WMNWorkspaceCreated) == 0) {
    updateWorkspaceCount(scr);
    updateWorkspaceNames(scr);
    wNETWMUpdateWorkarea(scr);
  } else if (strcmp(name, WMNWorkspaceDestroyed) == 0) {
    updateWorkspaceCount(scr);
    updateWorkspaceNames(scr);
    wNETWMUpdateWorkarea(scr);
  } else if (strcmp(name, WMNWorkspaceChanged) == 0) {
    updateCurrentWorkspace(scr);
  } else if (strcmp(name, WMNWorkspaceNameChanged) == 0) {
    updateWorkspaceNames(scr);
  }
}

void wNETFrameExtents(WWindow *wwin)
{
  long extents[4] = { 0, 0, 0, 0 };

  /* The extents array describes dimensions which are not
   * part of the client window.  In our case that means
   * widths of the border and heights of the titlebar and resizebar.
   *
   * Index 0 = left
   *       1 = right
   *       2 = top
   *       3 = bottom
   */
  if (wwin->frame->titlebar)
    extents[2] = wwin->frame->titlebar->height;
  if (wwin->frame->resizebar)
    extents[3] = wwin->frame->resizebar->height;
  if (HAS_BORDER(wwin)) {
    extents[0] += wwin->screen_ptr->frame_border_width;
    extents[1] += wwin->screen_ptr->frame_border_width;
    extents[2] += wwin->screen_ptr->frame_border_width;
    extents[3] += wwin->screen_ptr->frame_border_width;
  }

  XChangeProperty(dpy, wwin->client_win, net_frame_extents, XA_CARDINAL, 32, PropModeReplace, (unsigned char *) extents, 4);
}

void wNETCleanupFrameExtents(WWindow *wwin)
{
  XDeleteProperty(dpy, wwin->client_win, net_frame_extents);
}
