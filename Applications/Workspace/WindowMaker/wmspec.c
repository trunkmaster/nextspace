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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
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

#ifdef NETWM_HINTS

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <string.h>

#include "WindowMaker.h"
#include "window.h"
#include "screen.h"
#include "workspace.h"
#include "framewin.h"
#include "actions.h"
#include "client.h"
#include "wmspec.h"
#include "icon.h"
#include "stacking.h"
#include "xinerama.h"
#include "properties.h"


#ifdef DEBUG_WMSPEC
#include <stdio.h>
#endif

/* Global variables */
extern Atom _XA_WM_DELETE_WINDOW;
extern Time LastTimestamp;
extern WPreferences wPreferences;

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
static Atom net_workarea;			    /* XXX: not xinerama compatible */
static Atom net_supporting_wm_check;
static Atom net_virtual_roots;			    /* N/A */
static Atom net_desktop_layout;			    /* XXX */
static Atom net_showing_desktop;

/* Other Root Window Messages */
static Atom net_close_window;
static Atom net_moveresize_window;		    /* TODO */
static Atom net_wm_moveresize;			    /* TODO */

/* Application Window Properties */
static Atom net_wm_name;
static Atom net_wm_visible_name;		    /* TODO (unnecessary?) */
static Atom net_wm_icon_name;
static Atom net_wm_visible_icon_name;		    /* TODO (unnecessary?) */
static Atom net_wm_desktop;
static Atom net_wm_window_type;
static Atom net_wm_window_type_desktop;
static Atom net_wm_window_type_dock;
static Atom net_wm_window_type_toolbar;
static Atom net_wm_window_type_menu;
static Atom net_wm_window_type_utility;
static Atom net_wm_window_type_splash;
static Atom net_wm_window_type_dialog;
static Atom net_wm_window_type_normal;
static Atom net_wm_state;
static Atom net_wm_state_modal;			    /* XXX: what is this?!? */
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
static Atom net_wm_strut;			    /* XXX: see net_workarea */
static Atom net_wm_strut_partial;		    /* TODO: doesn't really fit into the current strut scheme */
static Atom net_wm_icon_geometry;		    /* FIXME: should work together with net_wm_handled_icons, gnome-panel-2.2.0.1 doesn't use _NET_WM_HANDLED_ICONS, thus present situation. */
static Atom net_wm_icon;
static Atom net_wm_pid;				    /* TODO */
static Atom net_wm_handled_icons;		    /* FIXME: see net_wm_icon_geometry */

/* Window Manager Protocols */
static Atom net_wm_ping;			    /* TODO */

static Atom utf8_string;

typedef struct {
    char * name;
    Atom * atom;
} atomitem_t;

static atomitem_t atomNames[] = {
    { "_NET_SUPPORTED", &net_supported },
    { "_NET_CLIENT_LIST", &net_client_list },
    { "_NET_CLIENT_LIST_STACKING", &net_client_list_stacking },
    { "_NET_NUMBER_OF_DESKTOPS", &net_number_of_desktops },
    { "_NET_DESKTOP_GEOMETRY", &net_desktop_geometry },
    { "_NET_DESKTOP_VIEWPORT", &net_desktop_viewport },
    { "_NET_CURRENT_DESKTOP", &net_current_desktop },
    { "_NET_DESKTOP_NAMES", &net_desktop_names },
    { "_NET_ACTIVE_WINDOW", &net_active_window },
    { "_NET_WORKAREA", &net_workarea },
    { "_NET_SUPPORTING_WM_CHECK", &net_supporting_wm_check },
    { "_NET_VIRTUAL_ROOTS", &net_virtual_roots },
    { "_NET_DESKTOP_LAYOUT", &net_desktop_layout },
    { "_NET_SHOWING_DESKTOP", &net_showing_desktop },

    { "_NET_CLOSE_WINDOW", &net_close_window },
    { "_NET_MOVERESIZE_WINDOW", &net_moveresize_window },
    { "_NET_WM_MOVERESIZE", &net_wm_moveresize },

    { "_NET_WM_NAME", &net_wm_name },
    { "_NET_WM_VISIBLE_NAME", &net_wm_visible_name },
    { "_NET_WM_ICON_NAME", &net_wm_icon_name },
    { "_NET_WM_VISIBLE_ICON_NAME", &net_wm_visible_icon_name },
    { "_NET_WM_DESKTOP", &net_wm_desktop },
    { "_NET_WM_WINDOW_TYPE", &net_wm_window_type },
    { "_NET_WM_WINDOW_TYPE_DESKTOP", &net_wm_window_type_desktop },
    { "_NET_WM_WINDOW_TYPE_DOCK", &net_wm_window_type_dock },
    { "_NET_WM_WINDOW_TYPE_TOOLBAR", &net_wm_window_type_toolbar },
    { "_NET_WM_WINDOW_TYPE_MENU", &net_wm_window_type_menu },
    { "_NET_WM_WINDOW_TYPE_UTILITY", &net_wm_window_type_utility },
    { "_NET_WM_WINDOW_TYPE_SPLASH", &net_wm_window_type_splash },
    { "_NET_WM_WINDOW_TYPE_DIALOG", &net_wm_window_type_dialog },
    { "_NET_WM_WINDOW_TYPE_NORMAL", &net_wm_window_type_normal },
    { "_NET_WM_STATE", &net_wm_state },
    { "_NET_WM_STATE_MODAL", &net_wm_state_modal },
    { "_NET_WM_STATE_STICKY", &net_wm_state_sticky },
    { "_NET_WM_STATE_MAXIMIZED_VERT", &net_wm_state_maximized_vert },
    { "_NET_WM_STATE_MAXIMIZED_HORZ", &net_wm_state_maximized_horz },
    { "_NET_WM_STATE_SHADED", &net_wm_state_shaded },
    { "_NET_WM_STATE_SKIP_TASKBAR", &net_wm_state_skip_taskbar },
    { "_NET_WM_STATE_SKIP_PAGER", &net_wm_state_skip_pager },
    { "_NET_WM_STATE_HIDDEN", &net_wm_state_hidden },
    { "_NET_WM_STATE_FULLSCREEN", &net_wm_state_fullscreen },
    { "_NET_WM_STATE_ABOVE", &net_wm_state_above },
    { "_NET_WM_STATE_BELOW", &net_wm_state_below },
    { "_NET_WM_ALLOWED_ACTIONS", &net_wm_allowed_actions },
    { "_NET_WM_ACTION_MOVE", &net_wm_action_move },
    { "_NET_WM_ACTION_RESIZE", &net_wm_action_resize },
    { "_NET_WM_ACTION_MINIMIZE", &net_wm_action_minimize },
    { "_NET_WM_ACTION_SHADE", &net_wm_action_shade },
    { "_NET_WM_ACTION_STICK", &net_wm_action_stick },
    { "_NET_WM_ACTION_MAXIMIZE_HORZ", &net_wm_action_maximize_horz },
    { "_NET_WM_ACTION_MAXIMIZE_VERT", &net_wm_action_maximize_vert },
    { "_NET_WM_ACTION_FULLSCREEN", &net_wm_action_fullscreen },
    { "_NET_WM_ACTION_CHANGE_DESKTOP", &net_wm_action_change_desktop },
    { "_NET_WM_ACTION_CLOSE", &net_wm_action_close },
    { "_NET_WM_STRUT", &net_wm_strut },
    { "_NET_WM_STRUT_PARTIAL", &net_wm_strut_partial },
    { "_NET_WM_ICON_GEOMETRY", &net_wm_icon_geometry },
    { "_NET_WM_ICON", &net_wm_icon },
    { "_NET_WM_PID", &net_wm_pid },
    { "_NET_WM_HANDLED_ICONS", &net_wm_handled_icons },

    { "_NET_WM_PING", &net_wm_ping },

    { "UTF8_STRING", &utf8_string },
};

#define atomNr (sizeof(atomNames)/sizeof(atomitem_t))

#define _NET_WM_STATE_REMOVE 0
#define _NET_WM_STATE_ADD 1
#define _NET_WM_STATE_TOGGLE 2

#define _NET_WM_MOVERESIZE_SIZE_TOPLEFT      0
#define _NET_WM_MOVERESIZE_SIZE_TOP          1
#define _NET_WM_MOVERESIZE_SIZE_TOPRIGHT     2
#define _NET_WM_MOVERESIZE_SIZE_RIGHT        3
#define _NET_WM_MOVERESIZE_SIZE_BOTTOMRIGHT  4
#define _NET_WM_MOVERESIZE_SIZE_BOTTOM       5
#define _NET_WM_MOVERESIZE_SIZE_BOTTOMLEFT   6
#define _NET_WM_MOVERESIZE_SIZE_LEFT         7
#define _NET_WM_MOVERESIZE_MOVE              8   /* movement only */
#define _NET_WM_MOVERESIZE_SIZE_KEYBOARD     9   /* size via keyboard */
#define _NET_WM_MOVERESIZE_MOVE_KEYBOARD    10   /* move via keyboard */

static void observer(void *self, WMNotification *notif);
static void wsobserver(void *self, WMNotification *notif);

static void updateClientList(WScreen *scr);
static void updateClientListStacking(WScreen *scr, WWindow *);

static void updateWorkspaceNames(WScreen *scr);
static void updateCurrentWorkspace(WScreen *scr);
static void updateWorkspaceCount(WScreen *scr);

typedef struct NetData {
    WScreen *scr;
    WReservedArea *strut;
    WWindow **show_desktop;
} NetData;


static void
setSupportedHints(WScreen *scr)
{
    Atom atom[atomNr];
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
    atom[i++] = net_wm_window_type_normal;

    atom[i++] = net_wm_state;
    /*    atom[i++] = net_wm_state_modal; */ /* XXX: not sure where/when to use it. */
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

    atom[i++] = net_wm_name;
    atom[i++] = net_wm_icon_name;

    XChangeProperty(dpy, scr->root_win, net_supported, XA_ATOM, 32,
                    PropModeReplace, (unsigned char*)atom, i);

    /* set supporting wm hint */
    XChangeProperty(dpy, scr->root_win, net_supporting_wm_check, XA_WINDOW, 32,
                    PropModeReplace, (unsigned char*)&scr->info_window, 1);

    XChangeProperty(dpy, scr->info_window, net_supporting_wm_check, XA_WINDOW,
                    32, PropModeReplace, (unsigned char*)&scr->info_window, 1);

    char *my_name = "WindowMaker";
    XChangeProperty(dpy, scr->info_window, net_wm_name, utf8_string,
                    8, PropModeReplace, (unsigned char *)my_name, strlen(my_name));
}


void
wNETWMUpdateDesktop(WScreen *scr)
{
    CARD32 *views, sizes[2];
    int count, i;

    if (scr->workspace_count==0)
        return;

    count = scr->workspace_count * 2;
    views = wmalloc(sizeof(CARD32) * count);
    /*memset(views, 0, sizeof(CARD32) * count);*/

#ifdef VIRTUAL_DESKTOP
    sizes[0] = scr->workspaces[scr->current_workspace]->width;
    sizes[1] = scr->workspaces[scr->current_workspace]->height;
#else
    sizes[0] = scr->scr_width;
    sizes[1] = scr->scr_height;
#endif

    for (i=0; i<scr->workspace_count; i++) {
#ifdef VIRTUAL_DESKTOP
        views[2*i + 0] = scr->workspaces[i]->view_x;
        views[2*i + 1] = scr->workspaces[i]->view_y;
#else
        views[2*i + 0] = 0;
        views[2*i + 1] = 0;
#endif
    }

    XChangeProperty(dpy, scr->root_win, net_desktop_geometry, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char*)sizes, 2);

    XChangeProperty(dpy, scr->root_win, net_desktop_viewport, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char*)views, count);

    wfree(views);
}


int
wNETWMGetCurrentDesktopFromHint(WScreen *scr)
{
    int count;
    unsigned char *prop;

    prop= PropGetCheckProperty(scr->root_win, net_current_desktop, XA_CARDINAL,
                               0, 1, &count);
    if (prop)
    {
        int desktop= *(CARD32*)prop;
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
static CARD32*
findBestIcon(CARD32 *data, unsigned long items)
{
    int size, wanted, d, distance;
    unsigned long i;
    CARD32 *icon;

    /* better use only 75% of icon_size. For 64x64 this means 48x48
     * This leaves room around the icon for the miniwindow title and
     * results in better overall aesthetics -Dan */
    wanted = wPreferences.icon_size * wPreferences.icon_size;

    for (icon=NULL, distance=LONG_MAX, i=0L; i<items-1; ) {
        size = data[i] * data[i+1];
        if (size==0)
            break;
        d = wanted - size;
        if (d>=0 && d<=distance && (i+size+2)<=items) {
            distance = d;
            icon = &data[i];
        }
        i += size+2;
    }

    return icon;
}


static RImage*
makeRImageFromARGBData(CARD32 *data)
{
    int size, width, height, i;
    RImage *image;
    unsigned char *imgdata;
    CARD32 pixel;

    width  = data[0];
    height = data[1];
    size   = width * height;

    if (size == 0)
        return NULL;

    image = RCreateImage(width, height, True);

    for (imgdata=image->data, i=2; i<size+2; i++, imgdata+=4) {
        pixel = data[i];
        imgdata[3] = (pixel >> 24) & 0xff; /* A */
        imgdata[0] = (pixel >> 16) & 0xff; /* R */
        imgdata[1] = (pixel >>  8) & 0xff; /* G */
        imgdata[2] = (pixel >>  0) & 0xff; /* B */
    }

    return image;
}


static void
updateIconImage(WScreen *scr, WWindow *wwin)
{
    CARD32 *property, *data;
    unsigned long items, rest;
    Atom type;
    int format;
    RImage *image;

    if (XGetWindowProperty(dpy, wwin->client_win, net_wm_icon, 0L, LONG_MAX,
                           False, XA_CARDINAL, &type, &format, &items, &rest,
                           (unsigned char**)&property)!=Success || !property) {
        return;
    }

    if (type!=XA_CARDINAL || format!=32 || items<2) {
        XFree(property);
        return;
    }

    data = findBestIcon(property, items);
    if (!data) {
        XFree(property);
        return;
    }

    image = makeRImageFromARGBData(data);

    if (image) {
        if (wwin->net_icon_image)
            RReleaseImage(wwin->net_icon_image);
        wwin->net_icon_image = image;
    }

    XFree(property);
}


static void
updateShowDesktop(WScreen * scr, Bool show)
{
    CARD32 foo;

    foo = (show == True);
    XChangeProperty(dpy, scr->root_win, net_showing_desktop, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char *)&foo, 1);
}


void
wNETWMShowingDesktop(WScreen *scr, Bool show)
{
    if (show && scr->netdata->show_desktop == NULL) {
        WWindow *tmp, **wins;
        int i=0;

        wins = (WWindow **)wmalloc(sizeof(WWindow *)*(scr->window_count+1));

        tmp = scr->focused_window;
        while (tmp) {
            if (!tmp->flags.hidden && !tmp->flags.miniaturized &&
                !WFLAGP(tmp, skip_window_list)) {

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
            wWorkspaceChange(scr, ws);
        wfree(scr->netdata->show_desktop);
        scr->netdata->show_desktop = NULL;
        updateShowDesktop(scr, False);
    }
}


void
wNETWMInitStuff(WScreen *scr)
{
    NetData *data;
    int i;

#ifdef DEBUG_WMSPEC
    printf( "wNETWMInitStuff\n");
#endif

#ifdef HAVE_XINTERNATOMS
    {
        Atom atoms[atomNr];
        char * names[atomNr];

        for (i = 0; i < atomNr; ++i) {
            names[i] = atomNames[i].name;
        }
        XInternAtoms(dpy, &names[0], atomNr, False, atoms);
        for (i = 0; i < atomNr; ++i) {
            *atomNames[i].atom = atoms[i];
        }
    }
#else
    for (i = 0; i < atomNr; i++) {
        *atomNames[i].atom = XInternAtom(dpy, atomNames[i].name, False);
    }
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


void
wNETWMCleanup(WScreen *scr)
{
    int i;

    for (i= 0; i < atomNr; i++)
      XDeleteProperty(dpy, scr->root_win, *atomNames[i].atom);
}


void
wNETWMUpdateActions(WWindow *wwin, Bool del)
{
    Atom action[10]; /* nr of actions atoms defined */
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


void
wNETWMUpdateWorkarea(WScreen *scr, WArea usableArea)
{
    CARD32 *area;
    int count, i;

    /* XXX: not Xinerama compatible,
     xinerama gets the largest available */

    if(!scr->netdata || scr->workspace_count==0)
        return;

    count = scr->workspace_count * 4;
    area = wmalloc(sizeof(CARD32) * count);
    for (i=0; i<scr->workspace_count; i++) {
        area[4*i + 0] = usableArea.x1;
        area[4*i + 1] = usableArea.y1;
        area[4*i + 2] = usableArea.x2 - usableArea.x1;
        area[4*i + 3] = usableArea.y2 - usableArea.y1;
    }

    XChangeProperty(dpy, scr->root_win, net_workarea, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char*)area, count);

    wfree(area);
}


Bool
wNETWMGetUsableArea(WScreen *scr, int head, WArea *area)
{
    WReservedArea *cur;
    WMRect rect;

    if(!scr->netdata || !scr->netdata->strut)
        return False;

    area->x1 = area->y1 = area->x2 = area->y2 = 0;

    for(cur = scr->netdata->strut ; cur ; cur = cur->next) {
        WWindow * wwin = wWindowFor(cur->window);
        if (wWindowTouchesHead(wwin, head)) {
            if(cur->area.x1 > area->x1)
                area->x1 = cur->area.x1;
            if(cur->area.y1 > area->y1)
                area->y1 = cur->area.y1;
            if(cur->area.x2 > area->x2)
                area->x2 = cur->area.x2;
            if(cur->area.y2 > area->y2)
                area->y2 = cur->area.y2;
        }
    }

    if (area->x1==0 && area->x2==0 &&
        area->y1==0 && area->y2==0) return False;

    rect = wGetRectForHead(scr, head);

    area->x1 = rect.pos.x + area->x1;
    area->x2 = rect.pos.x + rect.size.width - area->x2;
    area->y1 = rect.pos.y + area->y1;
    area->y2 = rect.pos.y + rect.size.height - area->y2;

    return True;
}


static void
updateClientList(WScreen *scr)
{
    WWindow *wwin;
    Window *windows;
    int count;

    windows = (Window *)wmalloc(sizeof(Window)*(scr->window_count+1));

    count = 0;
    wwin = scr->focused_window;
    while (wwin) {
        windows[count++] = wwin->client_win;
        wwin = wwin->prev;
    }
    XChangeProperty(dpy, scr->root_win, net_client_list, XA_WINDOW, 32,
                    PropModeReplace, (unsigned char*)windows, count);

    wfree(windows);
    XFlush(dpy);
}


static void
updateClientListStacking(WScreen *scr, WWindow *wwin_excl)
{
    WWindow *wwin;
    Window *client_list;
    Window *client_list_reverse;
    int client_count;
    WCoreWindow *tmp;
    WMBagIterator iter;
    int i;

    /* update client list */
    i = scr->window_count + 1;
    client_list = (Window*)wmalloc(sizeof(Window) * i);
    client_list_reverse = (Window*)wmalloc(sizeof(Window) * i);

    client_count = 0;
    WM_ETARETI_BAG(scr->stacking_list, tmp, iter) {
        while (tmp) {
            wwin = wWindowFor(tmp->window);
            /* wwin_excl is a window to exclude from the list
             (e.g. it's now unmanaged) */
            if(wwin && (wwin != wwin_excl))
                client_list[client_count++] = wwin->client_win;
            tmp = tmp->stacking->under;
        }
    }

    for(i = 0; i < client_count; i++) {
        Window w = client_list[client_count - i - 1];
        client_list_reverse[i] = w;
    }

    XChangeProperty(dpy, scr->root_win, net_client_list_stacking, XA_WINDOW, 32,
                    PropModeReplace, (unsigned char *)client_list_reverse, client_count);

    wfree(client_list);
    wfree(client_list_reverse);

    XFlush(dpy);
}


static void
updateWorkspaceCount(WScreen *scr) /* changeable */
{
    CARD32 count;

    count = scr->workspace_count;

    XChangeProperty(dpy, scr->root_win, net_number_of_desktops, XA_CARDINAL,
                    32, PropModeReplace, (unsigned char*)&count, 1);
}


static void
updateCurrentWorkspace(WScreen *scr) /* changeable */
{
    CARD32 count;

    count = scr->current_workspace;

    XChangeProperty(dpy, scr->root_win, net_current_desktop, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char*)&count, 1);
}


static void
updateWorkspaceNames(WScreen *scr)
{
    char buf[1024], *pos;
    unsigned int i, len, curr_size;

    pos = buf;
    len = 0;
    for(i = 0; i < scr->workspace_count; i++) {
        curr_size = strlen(scr->workspaces[i]->name);
        strcpy(pos, scr->workspaces[i]->name);
        pos += (curr_size+1);
        len += (curr_size+1);
    }

    XChangeProperty(dpy, scr->root_win, net_desktop_names, utf8_string, 8,
                    PropModeReplace, (unsigned char *)buf, len);
}


static void
updateFocusHint(WScreen *scr, WWindow *wwin) /* changeable */
{
    Window window;

    if (!scr->focused_window || !scr->focused_window->flags.focused)
        window = None;
    else
        window = scr->focused_window->client_win;

    XChangeProperty(dpy, scr->root_win, net_active_window, XA_WINDOW, 32,
                    PropModeReplace, (unsigned char*)&window, 1);
}


static void
updateWorkspaceHint(WWindow *wwin, Bool fake, Bool del)
{
    CARD32 l;

    if (del) {
        XDeleteProperty(dpy, wwin->client_win, net_wm_desktop);
    } else {
        l = ((fake || IS_OMNIPRESENT(wwin)) ? -1 : wwin->frame->workspace);
        XChangeProperty(dpy, wwin->client_win, net_wm_desktop, XA_CARDINAL,
                        32, PropModeReplace, (unsigned char*)&l, 1);
    }
}


static void
updateStateHint(WWindow *wwin, Bool changedWorkspace, Bool del) /* changeable */
{
    if (del) {
        if (!wwin->flags.net_state_from_client) {
            XDeleteProperty(dpy, wwin->client_win, net_wm_state);
        }
    } else {
        Atom state[15]; /* nr of defined state atoms */
        int i = 0;

        if(changedWorkspace || (wPreferences.sticky_icons && !IS_OMNIPRESENT(wwin)))
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
        if ((wwin->flags.hidden || wwin->flags.miniaturized) && !wwin->flags.net_show_desktop){
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


static Bool
updateStrut(WWindow *wwin, Bool adding)
{
    WScreen *scr;
    WReservedArea *area;
    Bool hasState = False;

    scr = wwin->screen_ptr;

    if (adding) {
        Atom type_ret;
        int fmt_ret;
        unsigned long nitems_ret;
        unsigned long bytes_after_ret;
        long *data = 0;

        if (XGetWindowProperty(dpy, wwin->client_win, net_wm_strut, 0, 4, False,
                               XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                               &bytes_after_ret,
                               (unsigned char**)&data)==Success && data) {

            area = (WReservedArea *)wmalloc(sizeof(WReservedArea));
            area->area.x1 = data[0];
            area->area.x2 = data[1];
            area->area.y1 = data[2];
            area->area.y2 = data[3];

            area->window = wwin->client_win;

            area->next = scr->netdata->strut;
            scr->netdata->strut = area;

            XFree(data);
            hasState = True;
#ifdef VIRTUAL_DESKTOP
            /* just in case wm_window_type didn't set it already */
            wwin->client_flags.virtual_stick = 1;
#endif
        }

    } else {
        /* deleting */
        area = scr->netdata->strut;

        if(area) {
            if(area->window == wwin->client_win) {
                scr->netdata->strut = area->next;
                wfree(area);
                hasState = True;
            } else {
                while(area->next && area->next->window != wwin->client_win)
                    area = area->next;

                if(area->next) {
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


static int
getWindowLayer(WWindow * wwin)
{
    int layer = WMNormalLevel;

    if (wwin->type == net_wm_window_type_desktop) {
        layer = WMDesktopLevel;
    } else if (wwin->type == net_wm_window_type_dock) {
        layer = WMDockLevel;
    } else if (wwin->type == net_wm_window_type_toolbar) {
        layer = WMMainMenuLevel;
    } else if (wwin->type == net_wm_window_type_menu) {
        layer = WMSubmenuLevel;
    } else if (wwin->type == net_wm_window_type_utility) {
    } else if (wwin->type == net_wm_window_type_splash) {
    } else if (wwin->type == net_wm_window_type_dialog) {
        if (wwin->transient_for) {
            WWindow *parent = wWindowFor(wwin->transient_for);
            if (parent && parent->flags.fullscreen) {
                layer = WMFullscreenLevel;
            }
        }
        /* //layer = WMPopUpLevel; // this seems a bad idea -Dan */
    } else if (wwin->type == net_wm_window_type_normal) {
    }

    if (wwin->client_flags.sunken && WMSunkenLevel < layer)
        layer = WMSunkenLevel;
    if (wwin->client_flags.floating && WMFloatingLevel > layer)
        layer = WMFloatingLevel;

    return layer;
}


static void
doStateAtom(WWindow *wwin, Atom state, int set, Bool init)
{

    if (state == net_wm_state_sticky) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !IS_OMNIPRESENT(wwin);
        }
        if (set != wwin->flags.omnipresent) {
            wWindowSetOmnipresent(wwin, set);
        }
    } else if (state == net_wm_state_shaded) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !wwin->flags.shaded;
        }
        if (init) {
            wwin->flags.shaded = set;
        } else {
            if (set) {
                wShadeWindow(wwin);
            } else {
                wUnshadeWindow(wwin);
            }
        }
    } else if (state == net_wm_state_skip_taskbar) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !wwin->client_flags.skip_window_list;
        }
        wwin->client_flags.skip_window_list = set;
    } else if (state == net_wm_state_skip_pager) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !wwin->flags.net_skip_pager;
        }
        wwin->flags.net_skip_pager = set;
    } else if (state == net_wm_state_maximized_vert) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !(wwin->flags.maximized & MAX_VERTICAL);
        }
        if (init) {
            wwin->flags.maximized |= (set ? MAX_VERTICAL : 0);
        } else {
            if (set) {
                wMaximizeWindow(wwin, wwin->flags.maximized | MAX_VERTICAL);
            } else {
                wMaximizeWindow(wwin, wwin->flags.maximized & ~MAX_VERTICAL);
            }
        }
    } else if (state == net_wm_state_maximized_horz) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !(wwin->flags.maximized & MAX_HORIZONTAL);
        }
        if (init) {
            wwin->flags.maximized |= (set ? MAX_HORIZONTAL : 0);
        } else {
            if (set) {
                wMaximizeWindow(wwin, wwin->flags.maximized | MAX_HORIZONTAL);
            } else {
                wMaximizeWindow(wwin, wwin->flags.maximized & ~MAX_HORIZONTAL);
            }
        }
    } else if (state == net_wm_state_hidden) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !(wwin->flags.miniaturized);
        }
        if (init) {
            wwin->flags.miniaturized = set;
        } else {
            if (set) {
                wIconifyWindow(wwin);
            } else {
                wDeiconifyWindow(wwin);
            }
        }
    } else if (state == net_wm_state_fullscreen) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !(wwin->flags.fullscreen);
        }
        if (init) {
            wwin->flags.fullscreen = set;
        } else {
            if (set) {
                wFullscreenWindow(wwin);
            } else {
                wUnfullscreenWindow(wwin);
            }
        }
    } else if (state == net_wm_state_above) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !(wwin->client_flags.floating);
        }
        if (init) {
            wwin->client_flags.floating = set;
        } else {
            wwin->client_flags.floating = set;
            ChangeStackingLevel(wwin->frame->core, getWindowLayer(wwin));
        }

    } else if (state == net_wm_state_below) {
        if (set == _NET_WM_STATE_TOGGLE) {
            set = !(wwin->client_flags.sunken);
        }
        if (init) {
            wwin->client_flags.sunken = set;
        } else {
            wwin->client_flags.sunken = set;
            ChangeStackingLevel(wwin->frame->core, getWindowLayer(wwin));
        }

    } else {
#ifdef DEBUG_WMSPEC
        printf("doStateAtom unknown atom %s set %d\n", XGetAtomName(dpy, state), set);
#endif
    }
}


static void
removeIcon( WWindow * wwin)
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


static Bool
handleWindowType(WWindow * wwin, Atom type, int *layer)
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
        wwin->client_flags.dont_move_off = 1;
        wwin->client_flags.no_appicon = 1;
        wwin->flags.net_skip_pager = 1;
        wwin->frame_x = 0;
        wwin->frame_y = 0;
#ifdef VIRTUAL_DESKTOP
        wwin->client_flags.virtual_stick = 1;
#endif
    } else if (type == net_wm_window_type_dock) {
        wwin->client_flags.no_titlebar = 1;
        wwin->client_flags.no_resizable = 1;
        wwin->client_flags.no_miniaturizable = 1;
        wwin->client_flags.no_border = 1; /* XXX: really not a single decoration. */
        wwin->client_flags.no_resizebar = 1;
        wwin->client_flags.no_shadeable = 1;
        wwin->client_flags.no_movable = 1;
        wwin->client_flags.omnipresent = 1;
        wwin->client_flags.skip_window_list = 1;
        wwin->client_flags.dont_move_off = 1;
        wwin->flags.net_skip_pager = 1;
#ifdef VIRTUAL_DESKTOP
        wwin->client_flags.virtual_stick = 1;
#endif
    } else if (type == net_wm_window_type_toolbar) {
        wwin->client_flags.no_titlebar = 1;
        wwin->client_flags.no_resizable = 1;
        wwin->client_flags.no_miniaturizable = 1;
        wwin->client_flags.no_resizebar = 1;
        wwin->client_flags.no_shadeable = 1;
        wwin->client_flags.skip_window_list = 1;
        wwin->client_flags.dont_move_off = 1;
        wwin->client_flags.no_appicon = 1;
    } else if (type == net_wm_window_type_menu) {
        wwin->client_flags.no_titlebar = 1;
        wwin->client_flags.no_resizable = 1;
        wwin->client_flags.no_miniaturizable = 1;
        wwin->client_flags.no_resizebar = 1;
        wwin->client_flags.no_shadeable = 1;
        wwin->client_flags.skip_window_list = 1;
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
        wwin->client_flags.dont_move_off = 1;
        wwin->client_flags.no_appicon = 1;
        wwin->flags.net_skip_pager = 1;
    } else if (type == net_wm_window_type_dialog) {
        /* These also seem a bad idea in our context -Dan
        // wwin->client_flags.skip_window_list = 1;
        // wwin->client_flags.no_appicon = 1;
        */
    } else if (type == net_wm_window_type_normal) {
    } else {
        ret = False;
    }

    wwin->type = type;
    *layer = getWindowLayer(wwin);

    return ret;
}


void
wNETWMPositionSplash(WWindow *wwin, int *x, int *y, int width, int height)
{
    if (wwin->type == net_wm_window_type_splash) {
        WScreen * scr = wwin->screen_ptr;
        WMRect rect = wGetRectForHead(scr, wGetHeadForPointerLocation(scr));
        *x = rect.pos.x + (rect.size.width - width)/2;
        *y = rect.pos.y + (rect.size.height - height)/2;
    }
}


static void
updateWindowType(WWindow * wwin)
{
    Atom type_ret;
    int fmt_ret;
    unsigned long nitems_ret;
    unsigned long bytes_after_ret;
    long *data = 0;
    int layer = 0;
    if (XGetWindowProperty(dpy, wwin->client_win, net_wm_window_type, 0, 1,
                           False, XA_ATOM, &type_ret, &fmt_ret, &nitems_ret,
                           &bytes_after_ret, (unsigned char **)&data)==Success
        && data) {

        int i;
        Atom * type = (Atom *)data;
        for (i=0; i<nitems_ret; ++i) {
            if (handleWindowType(wwin, type[i], &layer)) break;
        }
        XFree(data);
    }

    ChangeStackingLevel(wwin->frame->core, layer);
    wwin->frame->flags.need_texture_change = 1;
    wWindowConfigureBorders(wwin);
    wFrameWindowPaint(wwin->frame);
    wNETWMUpdateActions(wwin, False);
}


Bool
wNETWMCheckClientHints(WWindow *wwin, int *layer, int *workspace)
{
    Atom type_ret;
    int fmt_ret;
    unsigned long nitems_ret;
    unsigned long bytes_after_ret;
    long *data = 0;
    Bool hasState = False;
    int i;

    if (XGetWindowProperty(dpy, wwin->client_win, net_wm_desktop, 0, 1, False,
                           XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                           &bytes_after_ret,
                           (unsigned char**)&data)==Success && data) {

        long desktop = *data;
        XFree(data);

        if(desktop == -1)
            wwin->client_flags.omnipresent = 1;
        else
            *workspace = desktop;

        hasState = True;
    }

    if (XGetWindowProperty(dpy, wwin->client_win, net_wm_state, 0, 1, False,
                           XA_ATOM, &type_ret, &fmt_ret, &nitems_ret,
                           &bytes_after_ret,
                           (unsigned char**)&data)==Success && data) {

        Atom * state = (Atom *)data;
        for(i=0; i<nitems_ret; ++i) {
            doStateAtom(wwin, state[i], _NET_WM_STATE_ADD, True);
        }
        XFree(data);
        hasState = True;
    }

    if (XGetWindowProperty(dpy, wwin->client_win, net_wm_window_type, 0, 1, False,
                           XA_ATOM, &type_ret, &fmt_ret, &nitems_ret,
                           &bytes_after_ret,
                           (unsigned char **)&data) == Success && data) {

        Atom * type = (Atom *)data;
        for (i=0; i<nitems_ret; ++i) {
            if (handleWindowType(wwin, type[i], layer)) break;
        }
        XFree(data);
        hasState = True;
    }

    wNETWMUpdateActions(wwin, False);
    updateStrut(wwin, False);
    if (updateStrut(wwin, True)) {
        hasState = True;
    }
    wScreenUpdateUsableArea(wwin->screen_ptr);

    return hasState;
}


static Bool
updateNetIconInfo(WWindow *wwin) {

    Atom type_ret;
    int fmt_ret;
    unsigned long nitems_ret;
    unsigned long bytes_after_ret;
    long *data = 0;
    Bool hasState = False;
    Bool old_state = wwin->flags.net_handle_icon;

    if (XGetWindowProperty(dpy, wwin->client_win, net_wm_handled_icons, 0, 1, False,
                           XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                           &bytes_after_ret, (unsigned char **)&data) == Success && data) {
        long handled = *data;
        wwin->flags.net_handle_icon = (handled != 0);
        XFree(data);
        hasState = True;

    } else wwin->flags.net_handle_icon = False;

    if ( XGetWindowProperty(dpy, wwin->client_win, net_wm_icon_geometry, 0, 4, False,
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

    } else wwin->flags.net_handle_icon = False;

    if (wwin->flags.miniaturized &&
        old_state != wwin->flags.net_handle_icon) {
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


Bool
wNETWMCheckInitialClientState(WWindow *wwin)
{
    Bool hasState = False;

#ifdef DEBUG_WMSPEC
    printf("CheckInitialClientState\n");
#endif

    wNETWMShowingDesktop(wwin->screen_ptr, False);

    hasState |= updateNetIconInfo(wwin);

    updateIconImage(wwin->screen_ptr, wwin);

    return hasState;
}


static void
handleDesktopNames(XClientMessageEvent *event, WScreen *scr)
{
    unsigned long nitems_ret, bytes_after_ret;
    char *data, *names[32];
    int fmt_ret, i, n;
    Atom type_ret;

    if (XGetWindowProperty(dpy, scr->root_win, net_desktop_names, 0, 1, False,
                           utf8_string, &type_ret, &fmt_ret, &nitems_ret,
                           &bytes_after_ret,
                           (unsigned char**)&data)!=Success) {
        return;
    }

    if (data == 0)
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


Bool
wNETWMProcessClientMessage(XClientMessageEvent *event)
{
    WScreen *scr;
    WWindow *wwin;
    Bool done = True;

#ifdef DEBUG_WMSPEC
    printf("processClientMessage type %s\n", XGetAtomName(dpy, event->message_type));
#endif

    scr = wScreenForWindow(event->window);
    if (scr) {
        /* generic client messages */
        if (event->message_type == net_current_desktop) {
            wWorkspaceChange(scr, event->data.l[0]);
        } else if(event->message_type == net_number_of_desktops) {
            long value;

            value = event->data.l[0];
            if(value > scr->workspace_count) {
                wWorkspaceMake(scr, value - scr->workspace_count);
            } else if(value < scr->workspace_count) {
                int i;
                Bool rebuild = False;

                for (i = scr->workspace_count-1; i >= value; i--) {
                    if (!wWorkspaceDelete(scr, i)) {
                        rebuild = True;
                        break;
                    }
                }

                if(rebuild) {
                    updateWorkspaceCount(scr);
                }
            }
        } else if (event->message_type == net_showing_desktop) {
            wNETWMShowingDesktop(scr, event->data.l[0]);
#ifdef VIRTUAL_DESKTOP
        } else if (event->message_type == net_desktop_viewport) {
            wWorkspaceSetViewport(scr, scr->current_workspace,
                                  event->data.l[0], event->data.l[1]);
#endif
        } else if (event->message_type == net_desktop_names) {
            handleDesktopNames(event, scr);
        } else {
            done = False;
        }

        if (done)
            return True;
    }

    /* window specific client messages */

    wwin = wWindowFor(event->window);
    if (!wwin)
        return False;

    if (event->message_type == net_active_window) {
        wNETWMShowingDesktop(scr, False);
        wMakeWindowVisible(wwin);
    } else if (event->message_type == net_close_window) {
        if (!WFLAGP(wwin, no_closable)) {
            if (wwin->protocols.DELETE_WINDOW)
                wClientSendProtocol(wwin, _XA_WM_DELETE_WINDOW, LastTimestamp);
        }
    } else if (event->message_type == net_wm_state) {
        int maximized = wwin->flags.maximized;
        long set = event->data.l[0];

#ifdef DEBUG_WMSPEC
        printf("net_wm_state set %d a1 %s a2 %s\n", set,
               XGetAtomName(dpy, event->data.l[1]),
               XGetAtomName(dpy, event->data.l[2]));
#endif

        doStateAtom(wwin, (Atom)event->data.l[1], set, False);
        if(event->data.l[2])
            doStateAtom(wwin, (Atom)event->data.l[2], set, False);

        if(wwin->flags.maximized != maximized) {
            if(!wwin->flags.maximized) {
                wwin->flags.maximized = maximized;
                wUnmaximizeWindow(wwin);
            } else {
                wMaximizeWindow(wwin, wwin->flags.maximized);
            }
        }
        updateStateHint(wwin, False, False);
    } else if (event->message_type == net_wm_handled_icons ||
               event->message_type == net_wm_icon_geometry) {
        updateNetIconInfo(wwin);
    } else if (event->message_type == net_wm_desktop) {
        long desktop = event->data.l[0];
        if (desktop == -1) {
            wWindowSetOmnipresent(wwin, True);
        } else {
            if (IS_OMNIPRESENT(wwin))
                wWindowSetOmnipresent(wwin, False);
            wWindowChangeWorkspace(wwin, desktop);
        }
    } else if (event->message_type == net_wm_icon) {
        updateIconImage(scr, wwin);
    } else {
        done = False;
    }

    return done;
}


Bool
wNETWMCheckClientHintChange(WWindow *wwin, XPropertyEvent *event)
{
    Bool ret = True;

    if(event->atom == net_wm_strut) {
        updateStrut(wwin, False);
        updateStrut(wwin, True);
        wScreenUpdateUsableArea(wwin->screen_ptr);
    } else if (event->atom == net_wm_handled_icons ||
               event->atom == net_wm_icon_geometry) {
        updateNetIconInfo(wwin);
    } else if (event->atom == net_wm_window_type) {
        updateWindowType(wwin);
    } else if (event->atom == net_wm_name) {
        char *name= wNETWMGetWindowName(wwin->client_win);
        wWindowUpdateName(wwin, name);
        if (name) wfree(name);
    } else if (event->atom == net_wm_icon_name) {
        if (wwin->icon) {
            char *name= wNETWMGetIconName(wwin->client_win);
            wIconChangeTitle(wwin->icon, name);
        }
    } else {
        ret = False;
    }

    return ret;
}


int
wNETWMGetPidForWindow(Window window)
{
    Atom type_ret;
    int fmt_ret;
    unsigned long nitems_ret;
    unsigned long bytes_after_ret;
    long *data = 0;
    int pid;

    if (XGetWindowProperty(dpy, window, net_wm_pid, 0, 1, False,
                           XA_CARDINAL, &type_ret, &fmt_ret, &nitems_ret,
                           &bytes_after_ret,
                           (unsigned char**)&data)==Success && data) {

        pid = *data;
        XFree(data);
    } else {
        pid = 0;
    }

    return pid;
}


char*
wNETWMGetWindowName(Window window)
{
    char *name;
    char *ret;
    int size;

    name= (char*)PropGetCheckProperty(window,
                                      net_wm_name, utf8_string, 0,
                                      0, &size);
    if (name) {
        ret= wstrndup(name, size);
        XFree(name);
    }
    else
        ret= NULL;
    return ret;
}


char*
wNETWMGetIconName(Window window)
{
    char *name;
    char *ret;
    int size;

    name= (char*)PropGetCheckProperty(window,
                                      net_wm_icon_name, utf8_string, 0,
                                      0, &size);
    if (name) {
        ret= wstrndup(name, size);
        XFree(name);
    }
    else
        ret= NULL;
    return ret;
}


static void
observer(void *self, WMNotification *notif)
{
    WWindow *wwin = (WWindow*)WMGetNotificationObject(notif);
    const char *name = WMGetNotificationName(notif);
    void *data = WMGetNotificationClientData(notif);
    NetData *ndata = (NetData*)self;


    if (strcmp(name, WMNManaged) == 0 && wwin) {
        updateClientList(wwin->screen_ptr);
        updateClientListStacking(wwin->screen_ptr, NULL);
        updateStateHint(wwin, True, False);

        updateStrut(wwin, False);
        updateStrut(wwin, True);
        wScreenUpdateUsableArea(wwin->screen_ptr);
    } else if (strcmp(name, WMNUnmanaged) == 0 && wwin) {
        updateClientList(wwin->screen_ptr);
        updateClientListStacking(wwin->screen_ptr, wwin);
        updateWorkspaceHint(wwin, False, True);
        updateStateHint(wwin, False, True);
        wNETWMUpdateActions(wwin, True);

        updateStrut(wwin, False);
        wScreenUpdateUsableArea(wwin->screen_ptr);
    } else if (strcmp(name, WMNResetStacking) == 0 && wwin) {
        updateClientListStacking(wwin->screen_ptr, NULL);
        updateStateHint(wwin, False, False);
    } else if (strcmp(name, WMNChangedStacking) == 0 && wwin) {
        updateClientListStacking(wwin->screen_ptr, NULL);
        updateStateHint(wwin, False, False);
    } else if (strcmp(name, WMNChangedFocus) == 0) {
        updateFocusHint(ndata->scr, wwin);
    } else if (strcmp(name, WMNChangedWorkspace) == 0 && wwin) {
        updateWorkspaceHint(wwin, False, False);
        updateStateHint(wwin, True, False);
    } else if (strcmp(name, WMNChangedState) == 0 && wwin) {
        updateStateHint(wwin, !strcmp(data, "omnipresent"), False);
    }
}


static void
wsobserver(void *self, WMNotification *notif)
{
    WScreen *scr = (WScreen*)WMGetNotificationObject(notif);
    const char *name = WMGetNotificationName(notif);

    if (strcmp(name, WMNWorkspaceCreated) == 0) {
        updateWorkspaceCount(scr);
        updateWorkspaceNames(scr);
    } else if (strcmp(name, WMNWorkspaceDestroyed) == 0) {
        updateWorkspaceCount(scr);
        updateWorkspaceNames(scr);
    } else if (strcmp(name, WMNWorkspaceChanged) == 0) {
        updateCurrentWorkspace(scr);
    } else if (strcmp(name, WMNWorkspaceNameChanged) == 0) {
        updateWorkspaceNames(scr);
    }
}

#endif /* NETWM_HINTS */


