/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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
#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#ifdef SHAPE
#include <X11/extensions/shape.h>
#endif

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "WindowMaker.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "properties.h"
#include "actions.h"
#include "icon.h"
#include "client.h"
#include "funcs.h"
#include "stacking.h"
#include "appicon.h"
#include "appmenu.h"
#ifdef NETWM_HINTS
# include "wmspec.h"
#endif


/****** Global Variables ******/

/* contexts */
extern XContext wWinContext;

extern Atom _XA_WM_STATE;
extern Atom _XA_WM_PROTOCOLS;
extern Atom _XA_WM_COLORMAP_WINDOWS;

extern Atom _XA_WINDOWMAKER_MENU;

extern Atom _XA_GNUSTEP_WM_ATTR;
extern Atom _XA_GNUSTEP_WM_RESIZEBAR;

#ifdef SHAPE
extern Bool wShapeSupported;
#endif


/*
 *--------------------------------------------------------------------
 * wClientRestore--
 * 	Reparent the window back to the root window.
 *
 *--------------------------------------------------------------------
 */
void
wClientRestore(WWindow *wwin)
{
#if 0
    int gx, gy;

    wClientGetGravityOffsets(wwin, &gx, &gy);
    /* set the positio of the frame on screen */
    wwin->frame_x -= gx * FRAME_BORDER_WIDTH;
    wwin->frame_y -= gy * FRAME_BORDER_WIDTH;
    /* if gravity is to the south, account for the border sizes */
    if (gy > 0)
        wwin->frame_y += (wwin->frame->top_width + wwin->frame->bottom_width);
#endif
    XSetWindowBorderWidth(dpy, wwin->client_win, wwin->old_border_width);
    XReparentWindow(dpy, wwin->client_win, wwin->screen_ptr->root_win,
                    wwin->frame_x, wwin->frame_y);

    /* don't let the window get iconified after restart */
    /*
     if (wwin->flags.shaded)
     wClientSetState(wwin, NormalState, None);
     */
}


/*
 *----------------------------------------------------------------------
 * wClientSetState--
 * 	Set the state of the client window to one of the window
 * states defined in ICCCM (Iconic, Withdrawn, Normal)
 *
 * Side effects:
 * 	The WM_STATE property of the window is updated as well as the
 * WWindow.state variable.
 *----------------------------------------------------------------------
 */
void
wClientSetState(WWindow *wwin, int state, Window icon_win)
{
    CARD32 data[2];

    wwin->state = state;

    data[0] = (unsigned long) state;
    data[1] = (unsigned long) icon_win;

    XChangeProperty(dpy, wwin->client_win, _XA_WM_STATE, _XA_WM_STATE, 32,
                    PropModeReplace, (unsigned char *) data, 2);
}


void
wClientGetGravityOffsets(WWindow *wwin, int *ofs_x, int *ofs_y)
{
    switch (wwin->normal_hints->win_gravity) {
    case ForgetGravity:
    case CenterGravity:
    case StaticGravity:
        *ofs_x = 0;
        *ofs_y = 0;
        break;
    case NorthWestGravity:
        *ofs_x = -1;
        *ofs_y = -1;
        break;
    case NorthGravity:
        *ofs_x = 0;
        *ofs_y = -1;
        break;
    case NorthEastGravity:
        *ofs_x = 1;
        *ofs_y = -1;
        break;
    case WestGravity:
        *ofs_x = -1;
        *ofs_y = 0;
        break;
    case EastGravity:
        *ofs_x = 1;
        *ofs_y = 0;
        break;
    case SouthWestGravity:
        *ofs_x = -1;
        *ofs_y = 1;
        break;
    case SouthGravity:
        *ofs_x = 0;
        *ofs_y = 1;
        break;
    case SouthEastGravity:
        *ofs_x = 1;
        *ofs_y = 1;
        break;
    }
}



void
wClientConfigure(WWindow *wwin, XConfigureRequestEvent *xcre)
{
    XWindowChanges xwc;
    int nx, ny, nwidth, nheight;
    int ofs_x, ofs_y;

    /*  printf("configure event: %d %d %d %d\n", xcre->x, xcre->y, xcre->width, xcre->height);*/

    if (wwin==NULL) {
        /*
         * configure a window that was not mapped by us
         */
        xwc.x = xcre->x;
        xwc.y = xcre->y;
        xwc.width = xcre->width;
        xwc.height = xcre->height;
        xwc.border_width = xcre->border_width;
        xwc.stack_mode = xcre->detail;
        xwc.sibling = xcre->above;
        XConfigureWindow(dpy, xcre->window, xcre->value_mask, &xwc);
        return;
    }
#ifdef SHAPE
    if (wShapeSupported) {
        int junk;
        unsigned int ujunk;
        int b_shaped;

        XShapeSelectInput(dpy, wwin->client_win, ShapeNotifyMask);
        XShapeQueryExtents(dpy, wwin->client_win, &b_shaped, &junk, &junk,
                           &ujunk, &ujunk, &junk, &junk, &junk, &ujunk,
                           &ujunk);
        wwin->flags.shaped = b_shaped;
    }
#endif
    if (xcre->value_mask & CWStackMode) {
        WObjDescriptor *desc;
        WWindow *sibling;

        if ((xcre->value_mask & CWSibling) &&
            (XFindContext(dpy, xcre->above, wWinContext,
                          (XPointer *)&desc) == XCSUCCESS)
            && (desc->parent_type==WCLASS_WINDOW)) {
            sibling=desc->parent;
            xwc.sibling = sibling->frame->core->window;
        } else {
            xwc.sibling = xcre->above;
        }
        xwc.stack_mode = xcre->detail;
        XConfigureWindow(dpy, wwin->frame->core->window,
                         xcre->value_mask & (CWSibling | CWStackMode), &xwc);
        /* fix stacking order */
        RemakeStackList(wwin->screen_ptr);
    }

    wClientGetGravityOffsets(wwin, &ofs_x, &ofs_y);

    if (xcre->value_mask & CWBorderWidth) {
        wwin->old_border_width = xcre->border_width;
    }

    if (!wwin->flags.shaded) {
        /* If the window is shaded, wrong height will be set for the window */
        if (xcre->value_mask & CWX) {
            nx = xcre->x;
            /* Subtracting the border makes the window shift by 1 pixel -Dan */
            /*if (HAS_BORDER(wwin)) {
                nx -= FRAME_BORDER_WIDTH;
            }*/
        } else {
            nx = wwin->frame_x;
        }

        if (xcre->value_mask & CWY) {
            ny = xcre->y - ((ofs_y < 0) ? 0 : wwin->frame->top_width);
            /* Subtracting the border makes the window shift by 1 pixel -Dan */
            /*if (HAS_BORDER(wwin)) {
                ny -= FRAME_BORDER_WIDTH;
            }*/
        } else {
            ny = wwin->frame_y;
        }

        if (xcre->value_mask & CWWidth)
            nwidth = xcre->width;
        else
            nwidth = wwin->frame->core->width;

        if (xcre->value_mask & CWHeight)
            nheight = xcre->height;
        else
            nheight = wwin->frame->core->height - wwin->frame->top_width - wwin->frame->bottom_width;

        wWindowConfigure(wwin, nx, ny, nwidth, nheight);
        wwin->old_geometry.x = nx;
        wwin->old_geometry.y = ny;
        wwin->old_geometry.width = nwidth;
        wwin->old_geometry.height = nheight;
    }
}


void
wClientSendProtocol(WWindow *wwin, Atom protocol, Time time)
{
    XEvent event;

    event.xclient.type = ClientMessage;
    event.xclient.message_type = _XA_WM_PROTOCOLS;
    event.xclient.format = 32;
    event.xclient.display = dpy;
    event.xclient.window = wwin->client_win;
    event.xclient.data.l[0] = protocol;
    event.xclient.data.l[1] = time;
    event.xclient.data.l[2] = 0;
    event.xclient.data.l[3] = 0;
    XSendEvent(dpy, wwin->client_win, False, NoEventMask, &event);
    XSync(dpy, False);
}



void
wClientKill(WWindow *wwin)
{
    XKillClient(dpy, wwin->client_win);

    XFlush(dpy);
}



/*
 *----------------------------------------------------------------------
 * wClientCheckProperty--
 * 	Handles PropertyNotify'es, verifying which property was
 * changed and updating internal state according to that, like redrawing
 * the icon title when it is changed.
 *
 * Side effects:
 * 	Depends on the changed property.
 *
 * TODO: _GNUSTEP_WM_ATTR
 *----------------------------------------------------------------------
 */
void
wClientCheckProperty(WWindow *wwin, XPropertyEvent *event)
{
    XWindowAttributes attribs;
    XWMHints *new_hints;
    int i, g1, g2;
    char *tmp = NULL;

    switch (event->atom) {
    case XA_WM_NAME:
        if (!wwin->flags.net_has_title)
        {
            /* window title was changed */
            if (!wFetchName(dpy, wwin->client_win, &tmp)) {
                wWindowUpdateName(wwin, NULL);
            } else {
                wWindowUpdateName(wwin, tmp);
            }
            if (tmp)
              XFree(tmp);
        }
        break;

    case XA_WM_ICON_NAME:
        if (!wwin->flags.net_has_icon_title)
        {
            if (!wwin->icon)
              break;
            else {
                char *new_title;
                
                /* icon title was changed */
                wGetIconName(dpy, wwin->client_win, &new_title);
                wIconChangeTitle(wwin->icon, new_title);
            }
        }
        break;

    case XA_WM_COMMAND:
        if (wwin->main_window!=None) {
            WApplication *wapp = wApplicationOf(wwin->main_window);
            char *command;

            if (!wapp || !wapp->app_icon || wapp->app_icon->docked)
                break;

            command = GetCommandForWindow(wwin->main_window);
            if (command) {
                if (wapp->app_icon->command)
                    wfree(wapp->app_icon->command);
                wapp->app_icon->command = command;
            }
        }
        break;

    case XA_WM_HINTS:
        /* WM_HINTS */

        new_hints = XGetWMHints(dpy, wwin->client_win);

        /* group leader update
         *
         * This means that the window is setting the leader after
         * it was mapped, changing leaders or removing the leader.
         *
         * Valid state transitions are:
         *
         *          _1            __2
         *         / \           /  \
         *         v |           v  |
         *         (GC)         (GC')
         *        /  ^          /   ^
         *       3|  |4        5|   |6
         *        |  |          |   |
         *        v  /          v   /
         *        (G'C)        (G'C')
         *
         * Where G is the window_group hint, C is CLIENT_LEADER property
         * and ' indicates the hint is unset.
         *
         * 1,2 - change group leader to new value of window_group
         * 3 - change leader to value of CLIENT_LEADER
         * 4 - change leader to value of window_group
         * 5 - destroy application
         * 6 - create application
         */
        if (new_hints && (new_hints->flags & WindowGroupHint)
            && new_hints->window_group!=None) {
            g2 = 1;
        } else {
            g2 = 0;
        }
        if (wwin->wm_hints && (wwin->wm_hints->flags & WindowGroupHint)
            && wwin->wm_hints->window_group!=None) {
            g1 = 1;
        } else {
            g1 = 0;
        }

        if (wwin->client_leader) {
            if (g1 && g2
                && wwin->wm_hints->window_group!=new_hints->window_group) {
                i = 1;
            } else if (g1 && !g2) {
                i = 3;
            } else if (!g1 && g2) {
                i = 4;
            } else {
                i = 0;
            }
        } else {
            if (g1 && g2
                && wwin->wm_hints->window_group!=new_hints->window_group) {
                i = 2;
            } else if (g1 && !g2) {
                i = 5;
            } else if (!g1 && g2) {
                i = 6;
            } else {
                i = 0;
            }
        }

        /* Handling this may require more work. -Dan */
        if (wwin->fake_group!=NULL) {
            i = 7;
        }

        if (wwin->wm_hints)
            XFree(wwin->wm_hints);

        wwin->wm_hints = new_hints;

        /* do action according to state transition */
        switch (i) {
            /* 3 - change leader to value of CLIENT_LEADER */
        case 3:
            wApplicationDestroy(wApplicationOf(wwin->main_window));
            wwin->main_window = wwin->client_leader;
            wwin->group_id = None;
            wApplicationCreate(wwin);
            break;

            /* 1,2,4 - change leader to new value of window_group */
        case 1:
        case 2:
        case 4:
            wApplicationDestroy(wApplicationOf(wwin->main_window));
            wwin->main_window = new_hints->window_group;
            wwin->group_id = wwin->main_window;
            wApplicationCreate(wwin);
            break;

            /* 5 - destroy application */
        case 5:
            wApplicationDestroy(wApplicationOf(wwin->main_window));
            wwin->main_window = None;
            wwin->group_id = None;
            break;

            /* 6 - create application */
        case 6:
            wwin->main_window = new_hints->window_group;
            wwin->group_id = wwin->main_window;
            wApplicationCreate(wwin);
            break;
            /* 7 - we have a fake window group id, so just ignore anything else */
        case 7:
            break;
        }
#ifdef DEBUG
        if (i) {
            printf("window leader update caused state transition %i\n",i);
        }
#endif

        if (wwin->wm_hints) {
            /* update icon */
            if ((wwin->wm_hints->flags & IconPixmapHint)
                || (wwin->wm_hints->flags & IconWindowHint)) {
                WApplication *wapp;

                if (wwin->flags.miniaturized && wwin->icon) {
                    wIconUpdate(wwin->icon);
                }
                wapp = wApplicationOf(wwin->main_window);
                if (wapp && wapp->app_icon) {
                    wIconUpdate(wapp->app_icon->icon);
                }
            }

            if (wwin->wm_hints->flags & UrgencyHint)
                wwin->flags.urgent = 1;
            else
                wwin->flags.urgent = 0;
            /*} else if (wwin->fake_group!=NULL) {
             wwin->group_id = wwin->fake_group->leader;*/
        } else {
            wwin->group_id = None;
        }
        break;

    case XA_WM_NORMAL_HINTS:
        /* normal (geometry) hints */
        {
            int foo;
            unsigned bar;

            XGetWindowAttributes(dpy, wwin->client_win, &attribs);
            wClientGetNormalHints(wwin, &attribs, False, &foo, &foo,
                                  &bar, &bar);
            /* TODO: should we check for consistency of the current
             * size against the new geometry hints? */
        }
        break;

    case XA_WM_TRANSIENT_FOR:
        {
            Window new_owner;
            WWindow *owner;

            if (!XGetTransientForHint(dpy, wwin->client_win, &new_owner)) {
                new_owner = None;
            } else {
                if (new_owner==0 || new_owner == wwin->client_win) {
                    new_owner = wwin->screen_ptr->root_win;
                }
            }
            if (new_owner!=wwin->transient_for) {
                owner = wWindowFor(wwin->transient_for);
                if (owner) {
                    if (owner->flags.semi_focused) {
                        owner->flags.semi_focused = 0;
                        if ((owner->flags.mapped || owner->flags.shaded)
                            && owner->frame)
                            wFrameWindowPaint(owner->frame);
                    }
                }
                owner = wWindowFor(new_owner);
                if (owner) {
                    if (!owner->flags.semi_focused) {
                        owner->flags.semi_focused = 1;
                        if ((owner->flags.mapped || owner->flags.shaded)
                            && owner->frame)
                            wFrameWindowPaint(owner->frame);
                    }
                }
                wwin->transient_for = new_owner;
                if (new_owner==None) {
                    if (WFLAGP(wwin, no_miniaturizable)) {
                        WSETUFLAG(wwin, no_miniaturizable, 0);
                        WSETUFLAG(wwin, no_miniaturize_button, 0);
                        if (wwin->frame)
                            wWindowConfigureBorders(wwin);
                    }
                } else if (!WFLAGP(wwin, no_miniaturizable)) {
                    WSETUFLAG(wwin, no_miniaturizable, 1);
                    WSETUFLAG(wwin, no_miniaturize_button, 1);
                    if (wwin->frame)
                        wWindowConfigureBorders(wwin);
                }
            }
        }
        break;

    default:
        if (event->atom==_XA_WM_PROTOCOLS) {

            PropGetProtocols(wwin->client_win, &wwin->protocols);

            WSETUFLAG(wwin, kill_close, !wwin->protocols.DELETE_WINDOW);

            if (wwin->frame)
                wWindowUpdateButtonImages(wwin);

        } else if (event->atom==_XA_WM_COLORMAP_WINDOWS) {

            GetColormapWindows(wwin);
            wColormapInstallForWindow(wwin->screen_ptr, wwin);

        } else if (event->atom==_XA_WINDOWMAKER_MENU) {
            WApplication *wapp;

            wapp = wApplicationOf(wwin->main_window);
            if (wapp) {
                if (wapp->menu) {
                    /* update menu */
                    /* TODO: remake appmenu update */
                    wAppMenuDestroy(wapp->menu);
                }
                if (wwin->fake_group) {
                    extern WPreferences wPreferences;
                    WScreen *scr = wwin->screen_ptr;
                    WWindow *foo = scr->focused_window;
                    WFakeGroupLeader *fPtr = wwin->fake_group;

                    wApplicationDestroy(wapp);
                    while (foo) {
                        if (foo->fake_group && foo->fake_group==fPtr) {
                            WSETUFLAG(foo, shared_appicon, 0);
                            foo->fake_group = NULL;
                            if (foo->group_id!=None)
                                foo->main_window = foo->group_id;
                            else if (foo->client_leader!=None)
                                foo->main_window = foo->client_leader;
                            else if (WFLAGP(foo, emulate_appicon))
                                foo->main_window = foo->client_win;
                            else
                                foo->main_window = None;
                            if (foo->main_window) {
                                wapp = wApplicationCreate(foo);
                            }
                        }
                        foo = foo->prev;
                    }

                    if (fPtr->leader!=None)
                        XDestroyWindow(dpy, fPtr->leader);
                    fPtr->retainCount = 0;
                    fPtr->leader = None;
                    fPtr->origLeader = None;

                    wapp = wApplicationOf(wwin->main_window);
                    if (wapp) {
                        wapp->menu = wAppMenuGet(scr, wwin->main_window);
                    }
                    if (wPreferences.auto_arrange_icons) {
                        wArrangeIcons(wwin->screen_ptr, True);
                    }
                } else {
                    wapp->menu = wAppMenuGet(wwin->screen_ptr, wwin->main_window);
                }
                /* make the appmenu be mapped */
                wSetFocusTo(wwin->screen_ptr, NULL);
                wSetFocusTo(wwin->screen_ptr, wwin->screen_ptr->focused_window);
            }
        } else if (event->atom==_XA_GNUSTEP_WM_ATTR) {
            GNUstepWMAttributes *attr;

            PropGetGNUstepWMAttr(wwin->client_win, &attr);

            wWindowUpdateGNUstepAttr(wwin, attr);

            XFree(attr);
        } else {
#ifdef NETWM_HINTS
            wNETWMCheckClientHintChange(wwin, event);
#endif
        }
    }
}


/*
 *----------------------------------------------------------------------
 * wClientGetNormalHints--
 * 	Get size (normal) hints and a default geometry for the client
 * window. The hints are also checked for inconsistency. If geometry is
 * True, the returned data will account for client specified initial
 * geometry.
 *
 * Side effects:
 * 	normal_hints is filled with valid data.
 *----------------------------------------------------------------------
 */
void
wClientGetNormalHints(WWindow *wwin, XWindowAttributes *wattribs, Bool geometry,
                      int *x, int *y, unsigned *width, unsigned *height)
{
    int pre_icccm = 0;		       /* not used */

    /* find a position for the window */
    if (!wwin->normal_hints)
        wwin->normal_hints = XAllocSizeHints();

    if (!PropGetNormalHints(wwin->client_win, wwin->normal_hints, &pre_icccm)) {
        wwin->normal_hints->flags = 0;
    }
    *x = wattribs->x;
    *y = wattribs->y;

    *width = wattribs->width;
    *height = wattribs->height;

    if (!(wwin->normal_hints->flags & PWinGravity)) {
        wwin->normal_hints->win_gravity = NorthWestGravity;
    }
    if (!(wwin->normal_hints->flags & PMinSize)) {
        wwin->normal_hints->min_width = MIN_WINDOW_SIZE;
        wwin->normal_hints->min_height = MIN_WINDOW_SIZE;
    }
    if (!(wwin->normal_hints->flags & PBaseSize)) {
        wwin->normal_hints->base_width = 0;
        wwin->normal_hints->base_height = 0;
    }
    if (!(wwin->normal_hints->flags & PMaxSize)) {
        wwin->normal_hints->max_width = wwin->screen_ptr->scr_width*2;
        wwin->normal_hints->max_height = wwin->screen_ptr->scr_height*2;
    }

    /* some buggy apps set weird hints.. */
    if (wwin->normal_hints->min_width <= 0)
        wwin->normal_hints->min_width = MIN_WINDOW_SIZE;

    if (wwin->normal_hints->min_height <= 0)
        wwin->normal_hints->min_height = MIN_WINDOW_SIZE;


    if (wwin->normal_hints->max_width < wwin->normal_hints->min_width)
        wwin->normal_hints->max_width = wwin->normal_hints->min_width;

    if (wwin->normal_hints->max_height < wwin->normal_hints->min_height)
        wwin->normal_hints->max_height = wwin->normal_hints->min_height;

    if (!(wwin->normal_hints->flags & PResizeInc)) {
        wwin->normal_hints->width_inc = 1;
        wwin->normal_hints->height_inc = 1;
    } else {
        if (wwin->normal_hints->width_inc <= 0)
            wwin->normal_hints->width_inc = 1;
        if (wwin->normal_hints->height_inc <= 0)
            wwin->normal_hints->height_inc = 1;
    }

    if (wwin->normal_hints->flags & PAspect) {
        if (wwin->normal_hints->min_aspect.x < 1)
            wwin->normal_hints->min_aspect.x = 1;
        if (wwin->normal_hints->min_aspect.y < 1)
            wwin->normal_hints->min_aspect.y = 1;

        if (wwin->normal_hints->max_aspect.x < 1)
            wwin->normal_hints->max_aspect.x = 1;
        if (wwin->normal_hints->max_aspect.y < 1)
            wwin->normal_hints->max_aspect.y = 1;
    }

    if (wwin->normal_hints->min_height > wwin->normal_hints->max_height) {
        wwin->normal_hints->min_height = wwin->normal_hints->max_height;
    }
    if (wwin->normal_hints->min_width > wwin->normal_hints->max_width) {
        wwin->normal_hints->min_width = wwin->normal_hints->max_width;
    }

#ifdef IGNORE_PPOSITION
    wwin->normal_hints->flags &= ~PPosition;
#endif

    if (pre_icccm && !wwin->screen_ptr->flags.startup && geometry) {
        if (wwin->normal_hints->flags & (USPosition|PPosition)) {
            *x = wwin->normal_hints->x;
            *y = wwin->normal_hints->y;
        }
        if (wwin->normal_hints->flags & (USSize|PSize)) {
            *width = wwin->normal_hints->width;
            *height = wwin->normal_hints->height;
        }
    }
}


void
GetColormapWindows(WWindow *wwin)
{
#ifndef NO_CRASHES
    if (wwin->cmap_windows) {
        XFree(wwin->cmap_windows);
    }

    wwin->cmap_windows = NULL;
    wwin->cmap_window_no = 0;

    if (!XGetWMColormapWindows(dpy, wwin->client_win, &(wwin->cmap_windows),
                               &(wwin->cmap_window_no))
        || !wwin->cmap_windows) {
        wwin->cmap_window_no = 0;
        wwin->cmap_windows = NULL;
    }

#endif
}
