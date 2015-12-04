/* workspace.c- Workspace management
 *
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
#ifdef SHAPE
#include <X11/extensions/shape.h>
#endif

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <ctype.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>

#include "WindowMaker.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "icon.h"
#include "funcs.h"
#include "menu.h"
#include "application.h"
#include "dock.h"
#include "actions.h"
#include "workspace.h"
#include "appicon.h"
#ifdef NETWM_HINTS
#include "wmspec.h"
#endif

#include "xinerama.h"


extern WPreferences wPreferences;
extern XContext wWinContext;
extern XContext wVEdgeContext;

extern void ProcessPendingEvents();

static WMPropList *dWorkspaces=NULL;
static WMPropList *dClip, *dName;



static void
make_keys()
{
    if (dWorkspaces!=NULL)
        return;

    dWorkspaces = WMCreatePLString("Workspaces");
    dName = WMCreatePLString("Name");
    dClip = WMCreatePLString("Clip");
}


void
wWorkspaceMake(WScreen *scr, int count)
{
    while (count>0) {
        wWorkspaceNew(scr);
        count--;
    }
}


int
wWorkspaceNew(WScreen *scr)
{
    WWorkspace *wspace, **list;
    int i;

    if (scr->workspace_count < MAX_WORKSPACES) {
        scr->workspace_count++;

        wspace = wmalloc(sizeof(WWorkspace));
        wspace->name = NULL;

        if (!wspace->name) {
            wspace->name = wmalloc(strlen(_("Workspace %i"))+8);
            sprintf(wspace->name, _("Workspace %i"), scr->workspace_count);
        }


        if (!wPreferences.flags.noclip) {
            wspace->clip = wDockCreate(scr, WM_CLIP);
        } else
            wspace->clip = NULL;

        list = wmalloc(sizeof(WWorkspace*)*scr->workspace_count);

        for (i=0; i<scr->workspace_count-1; i++) {
            list[i] = scr->workspaces[i];
        }
        list[i] = wspace;
        if (scr->workspaces)
            wfree(scr->workspaces);
        scr->workspaces = list;

        wWorkspaceMenuUpdate(scr, scr->workspace_menu);
        wWorkspaceMenuUpdate(scr, scr->clip_ws_menu);
#ifdef VIRTUAL_DESKTOP
        wspace->view_x = wspace->view_y = 0;
        wspace->height = scr->scr_height;
        wspace->width = scr->scr_width;
#endif
#ifdef NETWM_HINTS
        wNETWMUpdateDesktop(scr);
#endif

        WMPostNotificationName(WMNWorkspaceCreated, scr,
                               (void*)(scr->workspace_count-1));
        XFlush(dpy);

        return scr->workspace_count-1;
    }

    return -1;
}


Bool
wWorkspaceDelete(WScreen *scr, int workspace)
{
    WWindow *tmp;
    WWorkspace **list;
    int i, j;

    if (workspace<=0)
        return False;

    /* verify if workspace is in use by some window */
    tmp = scr->focused_window;
    while (tmp) {
        if (!IS_OMNIPRESENT(tmp) && tmp->frame->workspace==workspace)
            return False;
        tmp = tmp->prev;
    }

    if (!wPreferences.flags.noclip) {
        wDockDestroy(scr->workspaces[workspace]->clip);
        scr->workspaces[workspace]->clip = NULL;
    }

    list = wmalloc(sizeof(WWorkspace*)*(scr->workspace_count-1));
    j = 0;
    for (i=0; i<scr->workspace_count; i++) {
        if (i!=workspace) {
            list[j++] = scr->workspaces[i];
        } else {
            if (scr->workspaces[i]->name)
                wfree(scr->workspaces[i]->name);
            wfree(scr->workspaces[i]);
        }
    }
    wfree(scr->workspaces);
    scr->workspaces = list;

    scr->workspace_count--;


    /* update menu */
    wWorkspaceMenuUpdate(scr, scr->workspace_menu);
    /* clip workspace menu */
    wWorkspaceMenuUpdate(scr, scr->clip_ws_menu);

    /* update also window menu */
    if (scr->workspace_submenu) {
        WMenu *menu = scr->workspace_submenu;

        i = menu->entry_no;
        while (i>scr->workspace_count)
            wMenuRemoveItem(menu, --i);
        wMenuRealize(menu);
    }
    /* and clip menu */
    if (scr->clip_submenu) {
        WMenu *menu = scr->clip_submenu;

        i = menu->entry_no;
        while (i>scr->workspace_count)
            wMenuRemoveItem(menu, --i);
        wMenuRealize(menu);
    }

#ifdef NETWM_HINTS
    wNETWMUpdateDesktop(scr);
#endif

    WMPostNotificationName(WMNWorkspaceDestroyed, scr,
                           (void*)(scr->workspace_count-1));

    if (scr->current_workspace >= scr->workspace_count)
        wWorkspaceChange(scr, scr->workspace_count-1);

    return True;
}


typedef struct WorkspaceNameData {
    int count;
    RImage *back;
    RImage *text;
    time_t timeout;
} WorkspaceNameData;


static void
hideWorkspaceName(void *data)
{
    WScreen *scr = (WScreen*)data;

    if (!scr->workspace_name_data || scr->workspace_name_data->count == 0
        || time(NULL) > scr->workspace_name_data->timeout) {
        XUnmapWindow(dpy, scr->workspace_name);

        if (scr->workspace_name_data) {
            RReleaseImage(scr->workspace_name_data->back);
            RReleaseImage(scr->workspace_name_data->text);
            wfree(scr->workspace_name_data);

            scr->workspace_name_data = NULL;
        }
        scr->workspace_name_timer = NULL;
    } else {
        RImage *img = RCloneImage(scr->workspace_name_data->back);
        Pixmap pix;

        scr->workspace_name_timer =
            WMAddTimerHandler(WORKSPACE_NAME_FADE_DELAY, hideWorkspaceName, scr);

        RCombineImagesWithOpaqueness(img, scr->workspace_name_data->text,
                                     scr->workspace_name_data->count*255/10);

        RConvertImage(scr->rcontext, img, &pix);

        RReleaseImage(img);

        XSetWindowBackgroundPixmap(dpy, scr->workspace_name, pix);
        XClearWindow(dpy, scr->workspace_name);
        XFreePixmap(dpy, pix);
        XFlush(dpy);

        scr->workspace_name_data->count--;
    }
}


static void
showWorkspaceName(WScreen *scr, int workspace)
{
    WorkspaceNameData *data;
    RXImage *ximg;
    Pixmap text, mask;
    int w, h;
    int px, py;
    char *name = scr->workspaces[workspace]->name;
    int len = strlen(name);
    int x, y;

    if (wPreferences.workspace_name_display_position == WD_NONE ||
        scr->workspace_count < 2) {
        return;
    }

    if (scr->workspace_name_timer) {
        WMDeleteTimerHandler(scr->workspace_name_timer);
        XUnmapWindow(dpy, scr->workspace_name);
        XFlush(dpy);
    }
    scr->workspace_name_timer = WMAddTimerHandler(WORKSPACE_NAME_DELAY,
                                                  hideWorkspaceName, scr);

    if (scr->workspace_name_data) {
        RReleaseImage(scr->workspace_name_data->back);
        RReleaseImage(scr->workspace_name_data->text);
        wfree(scr->workspace_name_data);
    }

    data = wmalloc(sizeof(WorkspaceNameData));
    data->back = NULL;

    w = WMWidthOfString(scr->workspace_name_font, name, len);
    h = WMFontHeight(scr->workspace_name_font);

    switch (wPreferences.workspace_name_display_position) {
    case WD_TOP:
        px = (scr->scr_width - (w+4))/2;
        py = 0;
        break;
    case WD_BOTTOM:
        px = (scr->scr_width - (w+4))/2;
        py = scr->scr_height - (h+4);
        break;
    case WD_TOPLEFT:
        px = 0;
        py = 0;
        break;
    case WD_TOPRIGHT:
        px = scr->scr_width - (w+4);
        py = 0;
        break;
    case WD_BOTTOMLEFT:
        px = 0;
        py = scr->scr_height - (h+4);
        break;
    case WD_BOTTOMRIGHT:
        px = scr->scr_width - (w+4);
        py = scr->scr_height - (h+4);
        break;
    case WD_CENTER:
    default:
        px = (scr->scr_width - (w+4))/2;
        py = (scr->scr_height - (h+4))/2;
        break;
    }
    XResizeWindow(dpy, scr->workspace_name, w+4, h+4);
    XMoveWindow(dpy, scr->workspace_name, px, py);

    text = XCreatePixmap(dpy, scr->w_win, w+4, h+4, scr->w_depth);
    mask = XCreatePixmap(dpy, scr->w_win, w+4, h+4, 1);

    /*XSetForeground(dpy, scr->mono_gc, 0);
     XFillRectangle(dpy, mask, scr->mono_gc, 0, 0, w+4, h+4);*/

    XFillRectangle(dpy, text, WMColorGC(scr->black), 0, 0, w+4, h+4);

    for (x = 0; x <= 4; x++) {
        for (y = 0; y <= 4; y++) {
            WMDrawString(scr->wmscreen, text, scr->white,
                         scr->workspace_name_font, x, y, name, len);
        }
    }

    XSetForeground(dpy, scr->mono_gc, 1);
    XSetBackground(dpy, scr->mono_gc, 0);

    XCopyPlane(dpy, text, mask, scr->mono_gc, 0, 0, w+4, h+4, 0, 0, 1<<(scr->w_depth-1));

    /*XSetForeground(dpy, scr->mono_gc, 1);*/
    XSetBackground(dpy, scr->mono_gc, 1);

    XFillRectangle(dpy, text, WMColorGC(scr->black), 0, 0, w+4, h+4);

    WMDrawString(scr->wmscreen, text, scr->white, scr->workspace_name_font,
                 2, 2, name, len);

#ifdef SHAPE
    XShapeCombineMask(dpy, scr->workspace_name, ShapeBounding, 0, 0, mask,
                      ShapeSet);
#endif
    XSetWindowBackgroundPixmap(dpy, scr->workspace_name, text);
    XClearWindow(dpy, scr->workspace_name);

    data->text = RCreateImageFromDrawable(scr->rcontext, text, None);

    XFreePixmap(dpy, text);
    XFreePixmap(dpy, mask);

    if (!data->text) {
        XMapRaised(dpy, scr->workspace_name);
        XFlush(dpy);

        goto erro;
    }

    ximg = RGetXImage(scr->rcontext, scr->root_win, px, py,
                      data->text->width, data->text->height);

    if (!ximg || !ximg->image) {
        goto erro;
    }

    XMapRaised(dpy, scr->workspace_name);
    XFlush(dpy);

    data->back = RCreateImageFromXImage(scr->rcontext, ximg->image, NULL);
    RDestroyXImage(scr->rcontext, ximg);

    if (!data->back) {
        goto erro;
    }

    data->count = 10;

    /* set a timeout for the effect */
    data->timeout = time(NULL) + 2 +
        (WORKSPACE_NAME_DELAY + WORKSPACE_NAME_FADE_DELAY*data->count)/1000;

    scr->workspace_name_data = data;


    return;

erro:
    if (scr->workspace_name_timer)
        WMDeleteTimerHandler(scr->workspace_name_timer);

    if (data->text)
        RReleaseImage(data->text);
    if (data->back)
        RReleaseImage(data->back);
    wfree(data);

    scr->workspace_name_data = NULL;

    scr->workspace_name_timer = WMAddTimerHandler(WORKSPACE_NAME_DELAY +
                                                  10*WORKSPACE_NAME_FADE_DELAY,
                                                  hideWorkspaceName, scr);
}


void
wWorkspaceChange(WScreen *scr, int workspace)
{
    if (scr->flags.startup || scr->flags.startup2) {
        return;
    }

    if (workspace != scr->current_workspace) {
        wWorkspaceForceChange(scr, workspace);
    } /*else {
    showWorkspaceName(scr, workspace);
    }*/
}


void
wWorkspaceRelativeChange(WScreen *scr, int amount)
{
    int w;

    w = scr->current_workspace + amount;

    if (amount < 0) {
        if (w >= 0) {
            wWorkspaceChange(scr, w);
        } else if (wPreferences.ws_cycle) {
            wWorkspaceChange(scr, scr->workspace_count + w);
        }
    } else if (amount > 0) {
        if (w < scr->workspace_count) {
            wWorkspaceChange(scr, w);
        } else if (wPreferences.ws_advance) {
            wWorkspaceChange(scr, WMIN(w, MAX_WORKSPACES-1));
        } else if (wPreferences.ws_cycle) {
            wWorkspaceChange(scr, w % scr->workspace_count);
        }
    }
}


void
wWorkspaceForceChange(WScreen *scr, int workspace)
{
    WWindow *tmp, *foc=NULL, *foc2=NULL;

    if (workspace >= MAX_WORKSPACES || workspace < 0)
        return;

    SendHelperMessage(scr, 'C', workspace+1, NULL);

    if (workspace > scr->workspace_count-1) {
        wWorkspaceMake(scr, workspace - scr->workspace_count + 1);
    }

    wClipUpdateForWorkspaceChange(scr, workspace);

    scr->current_workspace = workspace;

    wWorkspaceMenuUpdate(scr, scr->workspace_menu);

    wWorkspaceMenuUpdate(scr, scr->clip_ws_menu);

    if ((tmp = scr->focused_window)!= NULL) {
        if ((IS_OMNIPRESENT(tmp) && (tmp->flags.mapped || tmp->flags.shaded) &&
             !WFLAGP(tmp, no_focusable)) || tmp->flags.changing_workspace) {
            foc = tmp;
        }

        /* foc2 = tmp; will fix annoyance with gnome panel
         * but will create annoyance for every other application
         */
        while (tmp) {
            if (tmp->frame->workspace!=workspace && !tmp->flags.selected) {
                /* unmap windows not on this workspace */
                if ((tmp->flags.mapped||tmp->flags.shaded) &&
                    !IS_OMNIPRESENT(tmp) && !tmp->flags.changing_workspace) {
                    wWindowUnmap(tmp);
                }
                /* also unmap miniwindows not on this workspace */
                if (!wPreferences.sticky_icons && tmp->flags.miniaturized &&
                    tmp->icon && !IS_OMNIPRESENT(tmp)) {
                    XUnmapWindow(dpy, tmp->icon->core->window);
                    tmp->icon->mapped = 0;
                }
                /* update current workspace of omnipresent windows */
                if (IS_OMNIPRESENT(tmp)) {
                    WApplication *wapp = wApplicationOf(tmp->main_window);

                    tmp->frame->workspace = workspace;

                    if (wapp) {
                        wapp->last_workspace = workspace;
                    }
                    if (!foc2 && (tmp->flags.mapped || tmp->flags.shaded)) {
                        foc2 = tmp;
                    }
                }
            } else {
                /* change selected windows' workspace */
                if (tmp->flags.selected) {
                    wWindowChangeWorkspace(tmp, workspace);
                    if (!tmp->flags.miniaturized && !foc) {
                        foc = tmp;
                    }
                } else {
                    if (!tmp->flags.hidden) {
                        if (!(tmp->flags.mapped || tmp->flags.miniaturized)) {
                            /* remap windows that are on this workspace */
                            wWindowMap(tmp);
                            if (!foc && !WFLAGP(tmp, no_focusable)) {
                                foc = tmp;
                            }
                        }
                        /* Also map miniwindow if not omnipresent */
                        if (!wPreferences.sticky_icons &&
                            tmp->flags.miniaturized &&
                            !IS_OMNIPRESENT(tmp) && tmp->icon) {
                            tmp->icon->mapped = 1;
                            XMapWindow(dpy, tmp->icon->core->window);
                        }
                    }
                }
            }
            tmp = tmp->prev;
        }

        /* Gobble up events unleashed by our mapping & unmapping.
         * These may trigger various grab-initiated focus &
         * crossing events. However, we don't care about them,
         * and ignore their focus implications altogether to avoid
         * flicker.
         */
        scr->flags.ignore_focus_events = 1;
        ProcessPendingEvents();
        scr->flags.ignore_focus_events = 0;

        if (!foc)
            foc = foc2;

        if (scr->focused_window->flags.mapped && !foc) {
            foc = scr->focused_window;
        }
        if (wPreferences.focus_mode == WKF_CLICK) {
            wSetFocusTo(scr, foc);
        } else {
            unsigned int mask;
            int foo;
            Window bar, win;
            WWindow *tmp;

            tmp = NULL;
            if (XQueryPointer(dpy, scr->root_win, &bar, &win,
                              &foo, &foo, &foo, &foo, &mask)) {
                tmp = wWindowFor(win);
            }

            /* If there's a window under the pointer, focus it.
             * (we ate all other focus events above, so it's
             * certainly not focused). Otherwise focus last
             * focused, or the root (depending on sloppiness)
             */
            if (!tmp && wPreferences.focus_mode == WKF_SLOPPY) {
                wSetFocusTo(scr, foc);
            } else {
                wSetFocusTo(scr, tmp);
            }
        }
    }

    /* We need to always arrange icons when changing workspace, even if
     * no autoarrange icons, because else the icons in different workspaces
     * can be superposed.
     * This can be avoided if appicons are also workspace specific.
     */
    if (!wPreferences.sticky_icons)
        wArrangeIcons(scr, False);

    if (scr->dock)
        wAppIconPaint(scr->dock->icon_array[0]);

    if (scr->clip_icon) {
        if (scr->workspaces[workspace]->clip->auto_collapse ||
            scr->workspaces[workspace]->clip->auto_raise_lower) {
            /* to handle enter notify. This will also */
            XUnmapWindow(dpy, scr->clip_icon->icon->core->window);
            XMapWindow(dpy, scr->clip_icon->icon->core->window);
        } else {
            wClipIconPaint(scr->clip_icon);
        }
    }

#ifdef NETWM_HINTS
    wScreenUpdateUsableArea(scr);
    wNETWMUpdateDesktop(scr);
#endif

    showWorkspaceName(scr, workspace);

    WMPostNotificationName(WMNWorkspaceChanged, scr, (void*)workspace);

    /*   XSync(dpy, False); */
}


#ifdef VIRTUAL_DESKTOP

/* TODO:
 *
 * 1) Allow border around each window so the scrolling
 *    won't just stop at the border.
 * 2) Make pager.
 *
 */

#define vec_sub(a, b) wmkpoint((a).x-(b).x, (a).y-(b).y)
#define vec_add(a, b) wmkpoint((a).x+(b).x, (a).y+(b).y)
#define vec_inc(a, b) do { (a).x+=(b).x; (a).y+=(b).y; } while(0)
#define vec_dot(a, b) ((a).x*(b).x + (a).y*(b).y)
#define vec_scale(a, s) wmkpoint((a).x*s, (a).y*s)
#define vec_scale2(a, s, t) wmkpoint((a).x*s, (a).y*t)

#ifndef HAS_BORDER
#define HAS_BORDER(w) (!(WFLAGP((w), no_border)))
#endif

#ifndef IS_VSTUCK
#define IS_VSTUCK(w) (WFLAGP((w), virtual_stick))
#endif

#define updateMinimum(l,p,ml,mp) do { if (cmp(l) && (l)<(ml)) { (ml)=(l); (mp)=(p); }; } while(0)

static Bool cmp_gez(int i) { return (i >= 0); }

static Bool cmp_gz(int i)  { return (i > 0); }


static WMPoint
getClosestEdge(WScreen * scr, WMPoint direction, Bool (*cmp)(int))
{
    WMPoint closest = wmkpoint(0, 0);
    int closest_len = INT_MAX;
    WWindow * wwin;

    for (wwin=scr->focused_window; wwin; wwin=wwin->prev) {
        if (wwin->frame->workspace == scr->current_workspace) {
            if (!wwin->flags.miniaturized &&
                !IS_VSTUCK(wwin) &&
                !wwin->flags.hidden) {
                int border = 2*HAS_BORDER(wwin);
                int len;
                int x1,x2,y1,y2;
                int head = wGetHeadForWindow(wwin);
                WArea area = wGetUsableAreaForHead(scr, head, NULL, False);
                WMPoint p;

                x1 = wwin->frame_x - area.x1;
                y1 = wwin->frame_y - area.y1;
                x2 = wwin->frame_x + wwin->frame->core->width + border - area.x2;
                y2 = wwin->frame_y + wwin->frame->core->height + border - area.y2;

                p = wmkpoint(x1,y1);
                len = vec_dot(direction, p);
                updateMinimum(len, p, closest_len, closest);

                p = wmkpoint(x1,y2);
                len = vec_dot(direction, p);
                updateMinimum(len, p, closest_len, closest);

                p = wmkpoint(x2,y1);
                len = vec_dot(direction, p);
                updateMinimum(len, p, closest_len, closest);

                p = wmkpoint(x2,y2);
                len = vec_dot(direction, p);
                updateMinimum(len, p, closest_len, closest);
            }
        }
    }

    return closest;
}


static void
getViewPosition(WScreen *scr, int workspace, int *x, int *y)
{
    *x = scr->workspaces[workspace]->view_x;
    *y = scr->workspaces[workspace]->view_y;
}


void
wWorkspaceKeyboardMoveDesktop(WScreen *scr, WMPoint direction)
{
    int x, y;
    WMPoint edge = getClosestEdge(scr, direction, cmp_gz);
    int len = vec_dot(edge, direction);
    WMPoint step = vec_scale(direction, len);
    getViewPosition(scr, scr->current_workspace, &x, &y);
    wWorkspaceSetViewport(scr, scr->current_workspace, x+step.x, y+step.y);
}


extern Cursor wCursor[WCUR_LAST];


static void
vdMouseMoveDesktop(XEvent *event, WMPoint direction)
{
    static int lock = False;
    if (lock) return;
    lock = True;

    Bool done = False;
    Bool moved = True;
    WScreen *scr = wScreenForRootWindow(event->xcrossing.root);
    WMPoint old_pos = wmkpoint(event->xcrossing.x_root, event->xcrossing.y_root);
    WMPoint step;
    int x, y;
    int resisted = 0;

    if (XGrabPointer(dpy, event->xcrossing.window, False,
                     PointerMotionMask, GrabModeAsync, GrabModeAsync,
                     scr->root_win, wCursor[WCUR_EMPTY],
                     CurrentTime) != GrabSuccess) {

        /* if the grab fails, do it the old fashioned way */
        step = vec_scale2(direction, wPreferences.vedge_hscrollspeed,
                          wPreferences.vedge_vscrollspeed);
        getViewPosition(scr, scr->current_workspace, &x, &y);
        if (wWorkspaceSetViewport(scr, scr->current_workspace,
                                  x+step.x, y+step.y)) {
            step = vec_scale(direction, 2);
            XWarpPointer(dpy, None, scr->root_win, 0,0,0,0,
                         event->xcrossing.x_root - step.x,
                         event->xcrossing.y_root - step.y);
        }
        goto exit;
    }
    XSync(dpy, True);

    if (old_pos.x < 0)
        old_pos.x = 0;
    if (old_pos.y < 0)
        old_pos.y = 0;
    if (old_pos.x > scr->scr_width)
        old_pos.x = scr->scr_width;
    if (old_pos.y > scr->scr_height)
        old_pos.y = scr->scr_height;

    while (!done) {
        XEvent ev;
        if (moved) {
            XWarpPointer(dpy, None, scr->root_win, 0, 0, 0, 0,
                         scr->scr_width/2, scr->scr_height/2);
            moved = False;
        }
        WMMaskEvent(dpy, PointerMotionMask, &ev);

        switch (ev.type) {
        case MotionNotify:
            {
                int step_len;
                step = wmkpoint(ev.xmotion.x_root-scr->scr_width/2,
                                ev.xmotion.y_root-scr->scr_height/2);
                step_len = vec_dot(step, direction);
                if (step_len < 0) {
                    done = True;
                    break;
                }

                if (step_len > 0) {
                    Bool do_move = True;
                    int resist = wPreferences.vedge_resistance;
                    WMPoint closest;
                    int closest_len = INT_MAX;
                    if (resist) {
                        closest = getClosestEdge(scr, direction, cmp_gez);
                        closest_len = vec_dot(direction, closest);
                    }

                    if (!closest_len) {
                        resisted += step_len;
                        do_move = resisted >= resist;
                        if (do_move) {
                            closest_len = INT_MAX;
                            step_len = resisted - resist;
                            resisted = 0;
                        }
                    }
                    if (do_move) {
                        if (closest_len <= wPreferences.vedge_attraction) {
                            step = vec_scale(direction, closest_len);
                        } else {
                            step = vec_scale(direction, step_len);
                        }

                        getViewPosition(scr, scr->current_workspace, &x, &y);
                        wWorkspaceSetViewport(scr, scr->current_workspace,
                                              x+step.x, y+step.y);
                        moved = True;
                    }
                }
            }
            break;
        }
    }

    step = vec_add(old_pos, vec_scale(direction, -1));
    XWarpPointer(dpy, None, scr->root_win, 0,0,0,0, step.x, step.y);
    XUngrabPointer(dpy, CurrentTime);

exit:
    lock = False;
}


static void
vdHandleEnter_u(XEvent *event) {
    vdMouseMoveDesktop(event, VEC_UP);
}


static void
vdHandleEnter_d(XEvent *event) {
    vdMouseMoveDesktop(event, VEC_DOWN);
}


static void
vdHandleEnter_l(XEvent *event) {
    vdMouseMoveDesktop(event, VEC_LEFT);
}


static void
vdHandleEnter_r(XEvent *event) {
    vdMouseMoveDesktop(event, VEC_RIGHT);
}


#define LEFT_EDGE   0x01
#define RIGHT_EDGE  0x02
#define TOP_EDGE    0x04
#define BOTTOM_EDGE 0x08
#define ALL_EDGES   0x0F

static void
createEdges(WScreen *scr)
{
    if (!scr->virtual_edges) {
        int i, j, w;
        int vmask;
        XSetWindowAttributes attribs;

        int heads = wXineramaHeads(scr);
        int *hasEdges = (int*)wmalloc(sizeof(int)*heads);

        int thickness = 1;
        int nr_edges = 0;
        int max_edges = 4*heads;
        int head;
        Window *edges = (Window *)wmalloc(sizeof(Window)*max_edges);

        for (i=0; i<heads; ++i)
            hasEdges[i] = ALL_EDGES;
        for (i=0; i<heads; ++i) {
            WMRect i_rect = wGetRectForHead(scr, i);
            for (j=i+1; j<heads; ++j) {
                WMRect j_rect = wGetRectForHead(scr, j);

                int vlen = (WMIN(i_rect.pos.y + i_rect.size.height,
                                 j_rect.pos.y + j_rect.size.height) -
                            WMAX(i_rect.pos.y, j_rect.pos.y));

                int hlen = (WMIN(i_rect.pos.x + i_rect.size.width,
                                 j_rect.pos.x + j_rect.size.width) -
                            WMAX( i_rect.pos.x, j_rect.pos.x));

                if (vlen > 0 && hlen == 0) { /* horz alignment, vert edges touch */
                    if (i_rect.pos.x < j_rect.pos.x) { /* i left of j */
                        hasEdges[i] &= ~RIGHT_EDGE;
                        hasEdges[j] &= ~LEFT_EDGE;
                    } else { /* j left of i */
                        hasEdges[j] &= ~RIGHT_EDGE;
                        hasEdges[i] &= ~LEFT_EDGE;
                    }
                } else if (vlen == 0 && hlen > 0) { /* vert alignment, horz edges touch */
                    if (i_rect.pos.y < j_rect.pos.y) { /* i top of j */
                        hasEdges[i] &= ~BOTTOM_EDGE;
                        hasEdges[j] &= ~TOP_EDGE;
                    } else { /* j top of i */
                        hasEdges[j] &= ~BOTTOM_EDGE;
                        hasEdges[i] &= ~TOP_EDGE;
                    }
                }
            }
        }

        for (w = 0; w < scr->workspace_count; w++) {
            /* puts("reset workspace"); */
            wWorkspaceSetViewport(scr, w, 0, 0);
        }

        vmask = CWEventMask|CWOverrideRedirect;
        attribs.event_mask = (EnterWindowMask | LeaveWindowMask | VisibilityChangeMask);
        attribs.override_redirect = True;

        for (head=0; head<wXineramaHeads(scr); ++head) {
            WMRect rect = wGetRectForHead(scr, head);

            if (hasEdges[head] & TOP_EDGE) {
                edges[nr_edges] =
                    XCreateWindow(dpy, scr->root_win, rect.pos.x, rect.pos.y,
                                  rect.size.width, thickness, 0,
                                  CopyFromParent, InputOnly, CopyFromParent,
                                  vmask, &attribs);
                XSaveContext(dpy, edges[nr_edges], wVEdgeContext,
                             (XPointer)vdHandleEnter_u);
                ++nr_edges;
            }

            if (hasEdges[head] & BOTTOM_EDGE) {
                edges[nr_edges] =
                    XCreateWindow(dpy, scr->root_win, rect.pos.x,
                                  rect.pos.y+rect.size.height-thickness,
                                  rect.size.width, thickness, 0,
                                  CopyFromParent, InputOnly, CopyFromParent,
                                  vmask, &attribs);
                XSaveContext(dpy, edges[nr_edges], wVEdgeContext,
                             (XPointer)vdHandleEnter_d);
                ++nr_edges;
            }

            if (hasEdges[head] & LEFT_EDGE) {
                edges[nr_edges] =
                    XCreateWindow(dpy, scr->root_win, rect.pos.x, rect.pos.y,
                                  thickness, rect.pos.y+rect.size.height, 0,
                                  CopyFromParent, InputOnly, CopyFromParent,
                                  vmask, &attribs);
                XSaveContext(dpy, edges[nr_edges], wVEdgeContext,
                             (XPointer)vdHandleEnter_l);
                ++nr_edges;
            }

            if (hasEdges[head] & RIGHT_EDGE) {
                edges[nr_edges] =
                    XCreateWindow(dpy, scr->root_win,
                                  rect.pos.x + rect.size.width - thickness, rect.pos.y,
                                  thickness, rect.size.height, 0,
                                  CopyFromParent, InputOnly, CopyFromParent, vmask,
                                  &attribs);
                XSaveContext(dpy, edges[nr_edges], wVEdgeContext,
                             (XPointer)vdHandleEnter_r);
                ++nr_edges;
            }
        }

        scr->virtual_nr_edges = nr_edges;
        scr->virtual_edges = edges;

        for (i=0; i<scr->virtual_nr_edges; ++i) {
            XMapWindow(dpy, scr->virtual_edges[i]);
        }
        wWorkspaceRaiseEdge(scr);

        wfree(hasEdges);
    }
}


static void
destroyEdges(WScreen *scr)
{
    if (scr->virtual_edges) {
        int i;

        for (i=0; i<scr->virtual_nr_edges; ++i) {
            XDeleteContext(dpy, scr->virtual_edges[i], wVEdgeContext);
            XUnmapWindow(dpy, scr->virtual_edges[i]);
            XDestroyWindow(dpy, scr->virtual_edges[i]);
        }

        wfree(scr->virtual_edges);
        scr->virtual_edges = NULL;
        scr->virtual_nr_edges = 0;
    }
}


void
wWorkspaceUpdateEdge(WScreen *scr)
{
    if (wPreferences.vdesk_enable) {
        createEdges(scr);
    } else {
        destroyEdges(scr);
    }
}


void
wWorkspaceRaiseEdge(WScreen *scr)
{
    static int toggle = 0;
    int i;

    if (!scr->virtual_edges)
        return;

    if (toggle) {
        for (i=0; i<scr->virtual_nr_edges; ++i) {
            XRaiseWindow(dpy, scr->virtual_edges[i]);
        }
    } else {
        for (i=scr->virtual_nr_edges-1; i>=0; --i) {
            XRaiseWindow(dpy, scr->virtual_edges[i]);
        }
    }

    toggle ^= 1;
}


void
wWorkspaceLowerEdge(WScreen *scr)
{
    int i;
    for (i=0; i<scr->virtual_nr_edges; ++i) {
        XLowerWindow(dpy, scr->virtual_edges[i]);
    }
}


void
wWorkspaceResizeViewport(WScreen *scr, int workspace)
{
    int x, y;
    getViewPosition(scr, scr->current_workspace, &x, &y);
    wWorkspaceSetViewport(scr, scr->current_workspace, x, y);
}


void
updateWorkspaceGeometry(WScreen *scr, int workspace, int *view_x, int *view_y)
{
    int most_left, most_right, most_top, most_bottom;
    WWindow *wwin;

    int heads = wXineramaHeads(scr);
    typedef int strut_t[4];
    strut_t * strut = (strut_t*)wmalloc(heads*sizeof(strut_t));
    int head, i;

    for (head=0; head<heads; ++head) {
        WMRect rect = wGetRectForHead(scr, head);
        WArea area = wGetUsableAreaForHead(scr, head, NULL, False);
        strut[head][0] = area.x1 - rect.pos.x;
        strut[head][1] = rect.pos.x + rect.size.width - area.x2;
        strut[head][2] = area.y1 - rect.pos.y;
        strut[head][3] = rect.pos.y + rect.size.height - area.y2;
    }

    /* adjust workspace layout */
    wwin = scr->focused_window;
    most_right = 0;
    most_bottom = 0;
    most_left = scr->scr_width;
    most_top = scr->scr_height;
    for(;wwin; wwin = wwin->prev) {
        if (wwin->frame->workspace == workspace) {
            if (!wwin->flags.miniaturized && !IS_VSTUCK(wwin) &&
                !wwin->flags.hidden) {

                head = wGetHeadForWindow(wwin);

                i = wwin->frame_x - strut[head][0];
                if (i < most_left) /* record positions, should this be cached? */
                    most_left = i;
                i = wwin->frame_x + wwin->frame->core->width + strut[head][1];
                if (HAS_BORDER(wwin))
                    i+=2;
                if (i > most_right)
                    most_right = i;
                i = wwin->frame_y - strut[head][2];
                if (i < most_top)
                    most_top = i;
                i = wwin->frame_y + wwin->frame->core->height + strut[head][3];
                if (HAS_BORDER(wwin))
                    i+=2;
                if (i > most_bottom) {
                    most_bottom = i;
                }
            }
        }
    }

    if (most_left > 0) most_left = 0;
    if (most_top > 0) most_top = 0;

    scr->workspaces[workspace]->width = WMAX(most_right, scr->scr_width) - WMIN(most_left, 0);
    scr->workspaces[workspace]->height = WMAX(most_bottom, scr->scr_height) - WMIN(most_top, 0);

    *view_x += -most_left - scr->workspaces[workspace]->view_x;
    scr->workspaces[workspace]->view_x = -most_left;

    *view_y += -most_top - scr->workspaces[workspace]->view_y;
    scr->workspaces[workspace]->view_y = -most_top;

    wfree(strut);
}


typedef struct _delay_configure {
    WWindow *wwin;
    int delay_count;
} _delay_configure;


void
sendConfigureNotify (_delay_configure *delay)
{
    WWindow *wwin;

    delay->delay_count--;
    if (!delay->delay_count) {
        for (wwin = delay->wwin; wwin; wwin = wwin->prev) {
            wWindowSynthConfigureNotify(wwin);
        }
    }
}


Bool
wWorkspaceSetViewport(WScreen *scr, int workspace, int view_x, int view_y)
{
    Bool adjust_flag = False;
    int diff_x, diff_y;
    static _delay_configure delay_configure = {NULL, 0};
    WWorkspace *wptr;
    WWindow *wwin;

    wptr = scr->workspaces[workspace];

    /*printf("wWorkspaceSetViewport %d %d\n", view_x, view_y);*/

    updateWorkspaceGeometry(scr, workspace, &view_x, &view_y);

    if (view_x + scr->scr_width > wptr->width) {
        /* puts("right edge of vdesk"); */
        view_x = wptr->width - scr->scr_width;
    }
    if (view_x < 0) {
        /* puts("left edge of vdesk"); */
        view_x = 0;
    }
    if (view_y + scr->scr_height > wptr->height) {
        /* puts("right edge of vdesk"); */
        view_y = wptr->height - scr->scr_height;
    }
    if (view_y < 0) {
        /* puts("left edge of vdesk"); */
        view_y = 0;
    }

    diff_x = wptr->view_x - view_x;
    diff_y = wptr->view_y - view_y;
    if (!diff_x && !diff_y)
        return False;

    wptr->view_x = view_x;
    wptr->view_y = view_y;

#ifdef NETWM_HINTS
    wNETWMUpdateDesktop(scr);
#endif

    for (wwin = scr->focused_window; wwin; wwin = wwin->prev) {
        if (wwin->frame->workspace == workspace && !IS_VSTUCK(wwin)) {
            wWindowMove(wwin, wwin->frame_x + diff_x, wwin->frame_y + diff_y);
            adjust_flag = True;
        }
    }
    if (1) { /* if delay*/
        delay_configure.delay_count++;
        delay_configure.wwin = scr->focused_window;
        WMAddTimerHandler(200, (WMCallback *)sendConfigureNotify, &delay_configure);
    }

    return adjust_flag;
}


#endif


static void
switchWSCommand(WMenu *menu, WMenuEntry *entry)
{
    wWorkspaceChange(menu->frame->screen_ptr, (long)entry->clientdata);
}


static void
deleteWSCommand(WMenu *menu, WMenuEntry *entry)
{
    wWorkspaceDelete(menu->frame->screen_ptr,
                     menu->frame->screen_ptr->workspace_count-1);
}


static void
newWSCommand(WMenu *menu, WMenuEntry *foo)
{
    int ws;

    ws = wWorkspaceNew(menu->frame->screen_ptr);
    /* autochange workspace*/
    if (ws>=0)
        wWorkspaceChange(menu->frame->screen_ptr, ws);


    /*
     if (ws<9) {
     int kcode;
     if (wKeyBindings[WKBD_WORKSPACE1+ws]) {
     kcode = wKeyBindings[WKBD_WORKSPACE1+ws]->keycode;
     entry->rtext =
     wstrdup(XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0)));
     }
     }*/
}


static char*
cropline(char *line)
{
    char *start, *end;

    if (strlen(line)==0)
        return line;

    start = line;
    end = &(line[strlen(line)])-1;
    while (isspace(*line) && *line!=0) line++;
    while (isspace(*end) && end!=line) {
        *end=0;
        end--;
    }
    return line;
}


void
wWorkspaceRename(WScreen *scr, int workspace, char *name)
{
    char buf[MAX_WORKSPACENAME_WIDTH+1];
    char *tmp;

    if (workspace >= scr->workspace_count)
        return;

    /* trim white spaces */
    tmp = cropline(name);

    if (strlen(tmp)==0) {
        snprintf(buf, sizeof(buf), _("Workspace %i"), workspace+1);
    } else {
        strncpy(buf, tmp, MAX_WORKSPACENAME_WIDTH);
    }
    buf[MAX_WORKSPACENAME_WIDTH] = 0;

    /* update workspace */
    wfree(scr->workspaces[workspace]->name);
    scr->workspaces[workspace]->name = wstrdup(buf);

    if (scr->clip_ws_menu) {
        if (strcmp(scr->clip_ws_menu->entries[workspace+2]->text, buf)!=0) {
            wfree(scr->clip_ws_menu->entries[workspace+2]->text);
            scr->clip_ws_menu->entries[workspace+2]->text = wstrdup(buf);
            wMenuRealize(scr->clip_ws_menu);
        }
    }
    if (scr->workspace_menu) {
        if (strcmp(scr->workspace_menu->entries[workspace+2]->text, buf)!=0) {
            wfree(scr->workspace_menu->entries[workspace+2]->text);
            scr->workspace_menu->entries[workspace+2]->text = wstrdup(buf);
            wMenuRealize(scr->workspace_menu);
        }
    }

    if (scr->clip_icon)
        wClipIconPaint(scr->clip_icon);

    WMPostNotificationName(WMNWorkspaceNameChanged, scr, (void*)workspace);
}




/* callback for when menu entry is edited */
static void
onMenuEntryEdited(WMenu *menu, WMenuEntry *entry)
{
    char *tmp;

    tmp = entry->text;
    wWorkspaceRename(menu->frame->screen_ptr, (long)entry->clientdata, tmp);
}


WMenu*
wWorkspaceMenuMake(WScreen *scr, Bool titled)
{
    WMenu *wsmenu;

    wsmenu = wMenuCreate(scr, titled ? _("Workspaces") : NULL, False);
    if (!wsmenu) {
        wwarning(_("could not create Workspace menu"));
        return NULL;
    }

    /* callback to be called when an entry is edited */
    wsmenu->on_edit = onMenuEntryEdited;

    wMenuAddCallback(wsmenu, _("New"), newWSCommand, NULL);
    wMenuAddCallback(wsmenu, _("Destroy Last"), deleteWSCommand, NULL);

    return wsmenu;
}



void
wWorkspaceMenuUpdate(WScreen *scr, WMenu *menu)
{
    int i;
    long ws;
    char title[MAX_WORKSPACENAME_WIDTH+1];
    WMenuEntry *entry;
    int tmp;

    if (!menu)
        return;

    if (menu->entry_no < scr->workspace_count+2) {
        /* new workspace(s) added */
        i = scr->workspace_count-(menu->entry_no-2);
        ws = menu->entry_no - 2;
        while (i>0) {
            strcpy(title, scr->workspaces[ws]->name);

            entry = wMenuAddCallback(menu, title, switchWSCommand, (void*)ws);
            entry->flags.indicator = 1;
            entry->flags.editable = 1;

            i--;
            ws++;
        }
    } else if (menu->entry_no > scr->workspace_count+2) {
        /* removed workspace(s) */
        for (i = menu->entry_no-1; i >= scr->workspace_count+2; i--) {
            wMenuRemoveItem(menu, i);
        }
    }
    wMenuRealize(menu);

    for (i=0; i<scr->workspace_count; i++) {
        menu->entries[i+2]->flags.indicator_on = 0;
    }
    menu->entries[scr->current_workspace+2]->flags.indicator_on = 1;

    /* don't let user destroy current workspace */
    if (scr->current_workspace == scr->workspace_count-1) {
        wMenuSetEnabled(menu, 1, False);
    } else {
        wMenuSetEnabled(menu, 1, True);
    }

    tmp = menu->frame->top_width + 5;
    /* if menu got unreachable, bring it to a visible place */
    if (menu->frame_x < tmp - (int)menu->frame->core->width)
        wMenuMove(menu, tmp - (int)menu->frame->core->width, menu->frame_y, False);

    wMenuPaint(menu);
}


void
wWorkspaceSaveState(WScreen *scr, WMPropList *old_state)
{
    WMPropList *parr, *pstr, *wks_state, *old_wks_state, *foo, *bar;
    int i;

    make_keys();

    old_wks_state = WMGetFromPLDictionary(old_state, dWorkspaces);
    parr = WMCreatePLArray(NULL);
    for (i=0; i < scr->workspace_count; i++) {
        pstr = WMCreatePLString(scr->workspaces[i]->name);
        wks_state = WMCreatePLDictionary(dName, pstr, NULL);
        WMReleasePropList(pstr);
        if (!wPreferences.flags.noclip) {
            pstr = wClipSaveWorkspaceState(scr, i);
            WMPutInPLDictionary(wks_state, dClip, pstr);
            WMReleasePropList(pstr);
        } else if (old_wks_state!=NULL) {
            if ((foo = WMGetFromPLArray(old_wks_state, i))!=NULL) {
                if ((bar = WMGetFromPLDictionary(foo, dClip))!=NULL) {
                    WMPutInPLDictionary(wks_state, dClip, bar);
                }
            }
        }
        WMAddToPLArray(parr, wks_state);
        WMReleasePropList(wks_state);
    }
    WMPutInPLDictionary(scr->session_state, dWorkspaces, parr);
    WMReleasePropList(parr);
}


void
wWorkspaceRestoreState(WScreen *scr)
{
    WMPropList *parr, *pstr, *wks_state, *clip_state;
    int i, j, wscount;

    make_keys();

    if (scr->session_state == NULL)
        return;

    parr = WMGetFromPLDictionary(scr->session_state, dWorkspaces);

    if (!parr)
        return;

    wscount = scr->workspace_count;
    for (i=0; i < WMIN(WMGetPropListItemCount(parr), MAX_WORKSPACES); i++) {
        wks_state = WMGetFromPLArray(parr, i);
        if (WMIsPLDictionary(wks_state))
            pstr = WMGetFromPLDictionary(wks_state, dName);
        else
            pstr = wks_state;
        if (i >= scr->workspace_count)
            wWorkspaceNew(scr);
        if (scr->workspace_menu) {
            wfree(scr->workspace_menu->entries[i+2]->text);
            scr->workspace_menu->entries[i+2]->text = wstrdup(WMGetFromPLString(pstr));
            scr->workspace_menu->flags.realized = 0;
        }
        wfree(scr->workspaces[i]->name);
        scr->workspaces[i]->name = wstrdup(WMGetFromPLString(pstr));
        if (!wPreferences.flags.noclip) {
            clip_state = WMGetFromPLDictionary(wks_state, dClip);
            if (scr->workspaces[i]->clip)
                wDockDestroy(scr->workspaces[i]->clip);
            scr->workspaces[i]->clip = wDockRestoreState(scr, clip_state,
                                                         WM_CLIP);
            if (i>0)
                wDockHideIcons(scr->workspaces[i]->clip);

            /* We set the global icons here, because scr->workspaces[i]->clip
             * was not valid in wDockRestoreState().
             * There we only set icon->omnipresent to know which icons we
             * need to set here.
             */
            for (j=0; j<scr->workspaces[i]->clip->max_icons; j++) {
                WAppIcon *aicon = scr->workspaces[i]->clip->icon_array[j];

                if (aicon && aicon->omnipresent) {
                    aicon->omnipresent = 0;
                    wClipMakeIconOmnipresent(aicon, True);
                    XMapWindow(dpy, aicon->icon->core->window);
                }
            }
        }

        WMPostNotificationName(WMNWorkspaceNameChanged, scr, (void*)i);
    }
}


