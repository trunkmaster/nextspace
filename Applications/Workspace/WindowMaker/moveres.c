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
#include <X11/keysym.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include "WindowMaker.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "client.h"
#include "icon.h"
#include "dock.h"
#include "funcs.h"
#include "actions.h"
#include "workspace.h"

#include "geomview.h"
#include "screen.h"
#include "xinerama.h"

#include <WINGs/WINGsP.h>


/* How many different types of geometry/position
 display thingies are there? */
#define NUM_DISPLAYS 5

#define LEFT            1
#define RIGHT           2
#define HORIZONTAL      (LEFT|RIGHT)
#define UP              4
#define DOWN            8
#define VERTICAL        (UP|DOWN)


/* True if window currently has a border. This also includes borderless
 * windows which are currently selected
 */
#define HAS_BORDER_WITH_SELECT(w) ((w)->flags.selected || HAS_BORDER(w))


/****** Global Variables ******/
extern Time LastTimestamp;

extern Cursor wCursor[WCUR_LAST];

extern WPreferences wPreferences;

extern Atom _XA_WM_PROTOCOLS;



/*
 *----------------------------------------------------------------------
 * checkMouseSamplingRate-
 *      For lowering the mouse motion sampling rate for machines where
 * it's too high (SGIs). If it returns False then the event should be
 * ignored.
 *----------------------------------------------------------------------
 */
static Bool
checkMouseSamplingRate(XEvent *ev)
{
    static Time previousMotion = 0;

    if (ev->type == MotionNotify) {
        if (ev->xmotion.time - previousMotion < DELAY_BETWEEN_MOUSE_SAMPLING) {
            return False;
        } else {
            previousMotion = ev->xmotion.time;
        }
    }
    return True;
}



/*
 *----------------------------------------------------------------------
 * moveGeometryDisplayCentered
 *
 * routine that moves the geometry/position window on scr so it is
 * centered over the given coordinates (x,y). Also the window position
 * is clamped so it stays on the screen at all times.
 *----------------------------------------------------------------------
 */
static void
moveGeometryDisplayCentered(WScreen *scr, int x, int y)
{
    unsigned int w = WMWidgetWidth(scr->gview);
    unsigned int h = WMWidgetHeight(scr->gview);
    int x1 = 0, y1 = 0, x2 = scr->scr_width, y2 = scr->scr_height;

    x -= w / 2;
    y -= h / 2;

    /* dead area check */
    if (scr->xine_info.count) {
        WMRect rect;
        int head, flags;

        rect.pos.x = x;
        rect.pos.y = y;
        rect.size.width = w;
        rect.size.height = h;

        head = wGetRectPlacementInfo(scr, rect, &flags);

        if (flags & (XFLAG_DEAD | XFLAG_PARTIAL)) {
            rect = wGetRectForHead(scr, head);
            x1 = rect.pos.x;
            y1 = rect.pos.y;
            x2 = x1 + rect.size.width;
            y2 = y1 + rect.size.height;
        }
    }

    if (x < x1 + 1)
        x = x1 + 1;
    else if (x > (x2 - w))
        x = x2 - w;

    if (y < y1 + 1)
        y = y1 + 1;
    else if (y > (y2 - h))
        y = y2 - h;


    WMMoveWidget(scr->gview, x, y);
}


static void
showPosition(WWindow *wwin, int x, int y)
{
    WScreen *scr = wwin->screen_ptr;

    if (wPreferences.move_display == WDIS_NEW) {
#if 0
        int width = wwin->frame->core->width;
        int height = wwin->frame->core->height;

        GC lgc = scr->line_gc;
        XSetForeground(dpy, lgc, scr->line_pixel);
        sprintf(num, "%i", x);

        XDrawLine(dpy, scr->root_win, lgc, 0, y-1, scr->scr_width, y-1);
        XDrawLine(dpy, scr->root_win, lgc, 0, y+height+2, scr->scr_width,
                  y+height+2);
        XDrawLine(dpy, scr->root_win, lgc, x-1, 0, x-1, scr->scr_height);
        XDrawLine(dpy, scr->root_win, lgc, x+width+2, 0, x+width+2,
                  scr->scr_height);
#endif
    } else {
#ifdef VIRTUAL_DESKTOP
        WSetGeometryViewShownPosition(scr->gview,
                                      x + scr->workspaces[scr->current_workspace]->view_x,
                                      y + scr->workspaces[scr->current_workspace]->view_y);
#else
        WSetGeometryViewShownPosition(scr->gview, x, y);
#endif
    }
}


static void
cyclePositionDisplay(WWindow *wwin, int x, int y, int w, int h)
{
    WScreen *scr = wwin->screen_ptr;
    WMRect rect;

    wPreferences.move_display++;
    wPreferences.move_display %= NUM_DISPLAYS;

    if (wPreferences.move_display == WDIS_NEW) {
        wPreferences.move_display++;
        wPreferences.move_display %= NUM_DISPLAYS;
    }

    if (wPreferences.move_display == WDIS_NONE) {
        WMUnmapWidget(scr->gview);
    } else {
        if (wPreferences.move_display == WDIS_CENTER) {
            rect = wGetRectForHead(scr, wGetHeadForWindow(wwin));
            moveGeometryDisplayCentered(scr, rect.pos.x + rect.size.width/2,
                                        rect.pos.y + rect.size.height/2);
        } else if (wPreferences.move_display == WDIS_TOPLEFT) {
            rect = wGetRectForHead(scr, wGetHeadForWindow(wwin));
            moveGeometryDisplayCentered(scr, rect.pos.x + 1, rect.pos.y + 1);
        } else if (wPreferences.move_display == WDIS_FRAME_CENTER) {
            moveGeometryDisplayCentered(scr, x + w/2, y + h/2);
        }
        WMMapWidget(scr->gview);
    }
}


static void
mapPositionDisplay(WWindow *wwin, int x, int y, int w, int h)
{
    WScreen *scr = wwin->screen_ptr;
    WMRect rect;

    if (wPreferences.move_display == WDIS_NEW
        || wPreferences.move_display == WDIS_NONE) {
        return;
    } else if (wPreferences.move_display == WDIS_CENTER) {
        rect = wGetRectForHead(scr, wGetHeadForWindow(wwin));
        moveGeometryDisplayCentered(scr, rect.pos.x + rect.size.width/2,
                                    rect.pos.y + rect.size.height/2);
    } else if (wPreferences.move_display == WDIS_TOPLEFT) {
        rect = wGetRectForHead(scr, wGetHeadForWindow(wwin));
        moveGeometryDisplayCentered(scr, rect.pos.x + 1, rect.pos.y + 1);
    } else if (wPreferences.move_display == WDIS_FRAME_CENTER) {
        moveGeometryDisplayCentered(scr, x + w/2, y + h/2);
    }
    WMMapWidget(scr->gview);
    WSetGeometryViewShownPosition(scr->gview, x, y);
}


static void
showGeometry(WWindow *wwin, int x1, int y1, int x2, int y2, int direction)
{
    WScreen *scr = wwin->screen_ptr;
    Window root = scr->root_win;
    GC gc = scr->line_gc;
    int ty, by, my, x, y, mx, s;
    char num[16];
    XSegment segment[4];
    int fw, fh;

    /* This seems necessary for some odd reason (too lazy to write x1-1 and
     * x2-1 everywhere below in the code). But why only for x? */
    x1--; x2--;

    if (HAS_BORDER_WITH_SELECT(wwin)) {
        x1 += FRAME_BORDER_WIDTH;
        x2 += FRAME_BORDER_WIDTH;
        y1 += FRAME_BORDER_WIDTH;
        y2 += FRAME_BORDER_WIDTH;
    }

    ty = y1 + wwin->frame->top_width;
    by = y2 - wwin->frame->bottom_width;

    if (wPreferences.size_display == WDIS_NEW) {
        fw = XTextWidth(scr->tech_draw_font, "8888", 4);
        fh = scr->tech_draw_font->ascent+scr->tech_draw_font->descent;

        XSetForeground(dpy, gc, scr->line_pixel);

        /* vertical geometry */
        if (((direction & LEFT) && (x2 < scr->scr_width - fw)) || (x1 < fw)) {
            x = x2;
            s = -15;
        } else {
            x = x1;
            s = 15;
        }
        my = (ty + by) / 2;

        /* top arrow & end bar */
        segment[0].x1 = x - (s + 6);  segment[0].y1 = ty;
        segment[0].x2 = x - (s - 10); segment[0].y2 = ty;

        /* arrowhead */
        segment[1].x1 = x - (s - 2); segment[1].y1 = ty + 1;
        segment[1].x2 = x - (s - 5); segment[1].y2 = ty + 7;

        segment[2].x1 = x - (s - 2); segment[2].y1 = ty + 1;
        segment[2].x2 = x - (s + 1); segment[2].y2 = ty + 7;

        /* line */
        segment[3].x1 = x - (s - 2); segment[3].y1 = ty + 1;
        segment[3].x2 = x - (s - 2); segment[3].y2 = my - fh/2 - 1;

        XDrawSegments(dpy, root, gc, segment, 4);

        /* bottom arrow & end bar */
        segment[0].y1 = by;
        segment[0].y2 = by;

        /* arrowhead */
        segment[1].y1 = by - 1;
        segment[1].y2 = by - 7;

        segment[2].y1 = by - 1;
        segment[2].y2 = by - 7;

        /* line */
        segment[3].y1 = my + fh/2 + 2;
        segment[3].y2 = by - 1;

        XDrawSegments(dpy, root, gc, segment, 4);

        snprintf(num, sizeof(num), "%i", (by - ty - wwin->normal_hints->base_height) /
                 wwin->normal_hints->height_inc);
        fw = XTextWidth(scr->tech_draw_font, num, strlen(num));

        /* Display the height. */
        XSetFont(dpy, gc, scr->tech_draw_font->fid);
        XDrawString(dpy, root, gc, x - s + 3 - fw/2, my + scr->tech_draw_font->ascent - fh/2 + 1, num, strlen(num));

        /* horizontal geometry */
        if (y1 < 15) {
            y = y2;
            s = -15;
        } else {
            y = y1;
            s = 15;
        }
        mx = x1 + (x2 - x1)/2;
        snprintf(num, sizeof(num), "%i", (x2 - x1 - wwin->normal_hints->base_width) /
                 wwin->normal_hints->width_inc);
        fw = XTextWidth(scr->tech_draw_font, num, strlen(num));

        /* left arrow & end bar */
        segment[0].x1 = x1; segment[0].y1 = y - (s + 6);
        segment[0].x2 = x1; segment[0].y2 = y - (s - 10);

        /* arrowhead */
        segment[1].x1 = x1 + 7; segment[1].y1 = y - (s + 1);
        segment[1].x2 = x1 + 1; segment[1].y2 = y - (s - 2);

        segment[2].x1 = x1 + 1; segment[2].y1 = y - (s - 2);
        segment[2].x2 = x1 + 7; segment[2].y2 = y - (s - 5);

        /* line */
        segment[3].x1 = x1 + 1; segment[3].y1 = y - (s - 2);
        segment[3].x2 = mx - fw/2 - 2; segment[3].y2 = y - (s - 2);

        XDrawSegments(dpy, root, gc, segment, 4);

        /* right arrow & end bar */
        segment[0].x1 = x2 + 1;
        segment[0].x2 = x2 + 1;

        /* arrowhead */
        segment[1].x1 = x2 - 6;
        segment[1].x2 = x2;

        segment[2].x1 = x2;
        segment[2].x2 = x2 - 6;

        /* line */
        segment[3].x1 = mx + fw/2 + 2;
        segment[3].x2 = x2;

        XDrawSegments(dpy, root, gc, segment, 4);

        /* Display the width. */
        XDrawString(dpy, root, gc, mx - fw/2 + 1, y - s + scr->tech_draw_font->ascent - fh/2 + 1, num, strlen(num));
    } else {
        WSetGeometryViewShownSize(scr->gview,
                                  (x2 - x1 - wwin->normal_hints->base_width)
                                  / wwin->normal_hints->width_inc,
                                  (by - ty - wwin->normal_hints->base_height)
                                  / wwin->normal_hints->height_inc);
    }
}


static void
cycleGeometryDisplay(WWindow *wwin, int x, int y, int w, int h, int dir)
{
    WScreen *scr = wwin->screen_ptr;
    WMRect rect;

    wPreferences.size_display++;
    wPreferences.size_display %= NUM_DISPLAYS;

    if (wPreferences.size_display == WDIS_NEW
        || wPreferences.size_display == WDIS_NONE) {
        WMUnmapWidget(scr->gview);
    } else {
        if (wPreferences.size_display == WDIS_CENTER) {
            rect = wGetRectForHead(scr, wGetHeadForWindow(wwin));
            moveGeometryDisplayCentered(scr, rect.pos.x + rect.size.width/2,
                                        rect.pos.y + rect.size.height/2);
        } else if (wPreferences.size_display == WDIS_TOPLEFT) {
            rect = wGetRectForHead(scr, wGetHeadForWindow(wwin));
            moveGeometryDisplayCentered(scr, rect.pos.x + 1, rect.pos.y + 1);
        } else if (wPreferences.size_display == WDIS_FRAME_CENTER) {
            moveGeometryDisplayCentered(scr, x + w/2, y + h/2);
        }
        WMMapWidget(scr->gview);
        showGeometry(wwin, x, y, x + w, y + h, dir);
    }
}


static void
mapGeometryDisplay(WWindow *wwin, int x, int y, int w, int h)
{
    WScreen *scr = wwin->screen_ptr;
    WMRect rect;

    if (wPreferences.size_display == WDIS_NEW
        || wPreferences.size_display == WDIS_NONE)
        return;

    if (wPreferences.size_display == WDIS_CENTER) {
        rect = wGetRectForHead(scr, wGetHeadForWindow(wwin));
        moveGeometryDisplayCentered(scr, rect.pos.x + rect.size.width/2,
                                    rect.pos.y + rect.size.height/2);
    } else if (wPreferences.size_display == WDIS_TOPLEFT) {
        rect = wGetRectForHead(scr, wGetHeadForWindow(wwin));
        moveGeometryDisplayCentered(scr, rect.pos.x + 1, rect.pos.y + 1);
    } else if (wPreferences.size_display == WDIS_FRAME_CENTER) {
        moveGeometryDisplayCentered(scr, x + w/2, y + h/2);
    }
    WMMapWidget(scr->gview);
    showGeometry(wwin, x, y, x + w, y + h, 0);
}



static void
doWindowMove(WWindow *wwin, WMArray *array, int dx, int dy)
{
    WWindow *tmpw;
    WScreen *scr = wwin->screen_ptr;
    int x, y;

    if (!array || !WMGetArrayItemCount(array)) {
        wWindowMove(wwin, wwin->frame_x + dx, wwin->frame_y + dy);
    } else {
        WMArrayIterator iter;

        WM_ITERATE_ARRAY(array, tmpw, iter) {
            x = tmpw->frame_x + dx;
            y = tmpw->frame_y + dy;

#if 1 /* XXX: with xinerama patch was #if 0, check this */
            /* don't let windows become unreachable */

            if (x + (int)tmpw->frame->core->width < 20)
                x = 20 - (int)tmpw->frame->core->width;
            else if (x + 20 > scr->scr_width)
                x = scr->scr_width - 20;

            if (y + (int)tmpw->frame->core->height < 20)
                y = 20 - (int)tmpw->frame->core->height;
            else if (y + 20 > scr->scr_height)
                y = scr->scr_height - 20;
#else
            wScreenBringInside(scr, &x, &y,
                               (int)tmpw->frame->core->width,
                               (int)tmpw->frame->core->height);
#endif

            wWindowMove(tmpw, x, y);
        }
    }
}


static void
drawTransparentFrame(WWindow *wwin, int x, int y, int width, int height)
{
    Window root = wwin->screen_ptr->root_win;
    GC gc = wwin->screen_ptr->frame_gc;
    int h = 0;
    int bottom = 0;

    if (HAS_BORDER_WITH_SELECT(wwin)) {
        x += FRAME_BORDER_WIDTH;
        y += FRAME_BORDER_WIDTH;
    }

    if (HAS_TITLEBAR(wwin) && !wwin->flags.shaded) {
        h = WMFontHeight(wwin->screen_ptr->title_font) + (wPreferences.window_title_clearance + TITLEBAR_EXTEND_SPACE) * 2;
    }
    if (HAS_RESIZEBAR(wwin) && !wwin->flags.shaded) {
        /* Can't use wwin-frame->bottom_width because, in some cases
         (e.g. interactive placement), frame does not point to anything. */
        bottom = RESIZEBAR_HEIGHT;
    }
    XDrawRectangle(dpy, root, gc, x - 1, y - 1, width + 1, height + 1);

    if (h > 0) {
        XDrawLine(dpy, root, gc, x, y + h - 1, x + width, y + h - 1);
    }
    if (bottom > 0) {
        XDrawLine(dpy, root, gc, x, y + height - bottom,
                  x + width, y + height - bottom);
    }
}


static void
drawFrames(WWindow *wwin, WMArray *array, int dx, int dy)
{
    WWindow *tmpw;
    int scr_width = wwin->screen_ptr->scr_width;
    int scr_height = wwin->screen_ptr->scr_height;
    int x, y;

    if (!array) {

        x = wwin->frame_x + dx;
        y = wwin->frame_y + dy;

        drawTransparentFrame(wwin, x, y,
                             wwin->frame->core->width,
                             wwin->frame->core->height);

    } else {
        WMArrayIterator iter;

        WM_ITERATE_ARRAY(array, tmpw, iter) {
            x = tmpw->frame_x + dx;
            y = tmpw->frame_y + dy;

            /* don't let windows become unreachable */
#if 1 /* XXX: was 0 in XINERAMA patch, check */
            if (x + (int)tmpw->frame->core->width < 20)
                x = 20 - (int)tmpw->frame->core->width;
            else if (x + 20 > scr_width)
                x = scr_width - 20;

            if (y + (int)tmpw->frame->core->height < 20)
                y = 20 - (int)tmpw->frame->core->height;
            else if (y + 20 > scr_height)
                y = scr_height - 20;

#else
            wScreenBringInside(wwin->screen_ptr, &x, &y,
                               (int)tmpw->frame->core->width,
                               (int)tmpw->frame->core->height);
#endif

            drawTransparentFrame(tmpw, x, y, tmpw->frame->core->width,
                                 tmpw->frame->core->height);
        }
    }
}



static void
flushMotion()
{
    XEvent ev;

    XSync(dpy, False);
    while (XCheckMaskEvent(dpy, ButtonMotionMask, &ev)) ;
}


static void
crossWorkspace(WScreen *scr, WWindow *wwin, int opaque_move,
               int new_workspace, int rewind)
{
    /* do not let window be unmapped */
    if (opaque_move) {
        wwin->flags.changing_workspace = 1;
        wWindowChangeWorkspace(wwin, new_workspace);
    }
    /* go to new workspace */
    wWorkspaceChange(scr, new_workspace);

    wwin->flags.changing_workspace = 0;

    if (rewind)
        XWarpPointer(dpy, None, None, 0, 0, 0, 0, scr->scr_width - 20, 0);
    else
        XWarpPointer(dpy, None, None, 0, 0, 0, 0, -(scr->scr_width - 20), 0);

    flushMotion();

    if (!opaque_move) {
        XGrabPointer(dpy, scr->root_win, True, PointerMotionMask
                     |ButtonReleaseMask|ButtonPressMask, GrabModeAsync,
                     GrabModeAsync, None, wCursor[WCUR_MOVE], CurrentTime);
    }
}




typedef struct {
    /* arrays of WWindows sorted by the respective border position */
    WWindow **topList;		       /* top border */
    WWindow **leftList;		       /* left border */
    WWindow **rightList;	       /* right border */
    WWindow **bottomList;	       /* bottom border */
    int count;

    /* index of window in the above lists indicating the relative position
     * of the window with the others */
    int topIndex;
    int leftIndex;
    int rightIndex;
    int bottomIndex;

    int rubCount;		       /* for workspace switching */

    int winWidth, winHeight;	       /* width/height of the window */
    int realX, realY;		       /* actual position of the window */
    int calcX, calcY;		       /* calculated position of window */
    int omouseX, omouseY;	       /* old mouse position */
    int mouseX, mouseY;		       /* last known position of the pointer */
} MoveData;

#define WTOP(w) (w)->frame_y
#define WLEFT(w) (w)->frame_x
#define WRIGHT(w) ((w)->frame_x + (int)(w)->frame->core->width - 1 + \
    (HAS_BORDER_WITH_SELECT(w) ? 2*FRAME_BORDER_WIDTH : 0))
#define WBOTTOM(w) ((w)->frame_y + (int)(w)->frame->core->height - 1 + \
    (HAS_BORDER_WITH_SELECT(w) ? 2*FRAME_BORDER_WIDTH : 0))

static int
compareWTop(const void *a, const void *b)
{
    WWindow *wwin1 = *(WWindow**)a;
    WWindow *wwin2 = *(WWindow**)b;

    if (WTOP(wwin1) > WTOP(wwin2))
        return -1;
    else if (WTOP(wwin1) < WTOP(wwin2))
        return 1;
    else
        return 0;
}


static int
compareWLeft(const void *a, const void *b)
{
    WWindow *wwin1 = *(WWindow**)a;
    WWindow *wwin2 = *(WWindow**)b;

    if (WLEFT(wwin1) > WLEFT(wwin2))
        return -1;
    else if (WLEFT(wwin1) < WLEFT(wwin2))
        return 1;
    else
        return 0;
}


static int
compareWRight(const void *a, const void *b)
{
    WWindow *wwin1 = *(WWindow**)a;
    WWindow *wwin2 = *(WWindow**)b;

    if (WRIGHT(wwin1) < WRIGHT(wwin2))
        return -1;
    else if (WRIGHT(wwin1) > WRIGHT(wwin2))
        return 1;
    else
        return 0;
}



static int
compareWBottom(const void *a, const void *b)
{
    WWindow *wwin1 = *(WWindow**)a;
    WWindow *wwin2 = *(WWindow**)b;

    if (WBOTTOM(wwin1) < WBOTTOM(wwin2))
        return -1;
    else if (WBOTTOM(wwin1) > WBOTTOM(wwin2))
        return 1;
    else
        return 0;
}


static void
updateResistance(WWindow *wwin, MoveData *data, int newX, int newY)
{
    int i;
    int newX2 = newX + data->winWidth;
    int newY2 = newY + data->winHeight;
    Bool ok = False;

    if (newX < data->realX) {
        if (data->rightIndex > 0
            && newX < WRIGHT(data->rightList[data->rightIndex-1])) {
            ok = True;
        } else if (data->leftIndex <= data->count-1
                   && newX2 <= WLEFT(data->leftList[data->leftIndex])) {
            ok = True;
        }
    } else if (newX > data->realX) {
        if (data->leftIndex > 0
            && newX2 > WLEFT(data->leftList[data->leftIndex-1])) {
            ok = True;
        } else if (data->rightIndex <= data->count-1
                   && newX >= WRIGHT(data->rightList[data->rightIndex])) {
            ok = True;
        }
    }

    if (!ok) {
        if (newY < data->realY) {
            if (data->bottomIndex > 0
                && newY < WBOTTOM(data->bottomList[data->bottomIndex-1])) {
                ok = True;
            } else if (data->topIndex <= data->count-1
                       && newY2 <= WTOP(data->topList[data->topIndex])) {
                ok = True;
            }
        } else if (newY > data->realY) {
            if (data->topIndex > 0
                && newY2 > WTOP(data->topList[data->topIndex-1])) {
                ok = True;
            } else if (data->bottomIndex <= data->count-1
                       && newY >= WBOTTOM(data->bottomList[data->bottomIndex])) {
                ok = True;
            }
        }
    }

    if (!ok)
        return;

    /* TODO: optimize this */
    if (data->realY < WBOTTOM(data->bottomList[0])) {
        data->bottomIndex = 0;
    }
    if (data->realX < WRIGHT(data->rightList[0])) {
        data->rightIndex = 0;
    }
    if ((data->realX + data->winWidth) > WLEFT(data->leftList[0])) {
        data->leftIndex = 0;
    }
    if ((data->realY + data->winHeight) > WTOP(data->topList[0])) {
        data->topIndex = 0;
    }
    for (i = 0; i < data->count; i++) {
        if (data->realY > WBOTTOM(data->bottomList[i])) {
            data->bottomIndex = i + 1;
        }
        if (data->realX > WRIGHT(data->rightList[i])) {
            data->rightIndex = i + 1;
        }
        if ((data->realX + data->winWidth) < WLEFT(data->leftList[i])) {
            data->leftIndex = i + 1;
        }
        if ((data->realY + data->winHeight) < WTOP(data->topList[i])) {
            data->topIndex = i + 1;
        }
    }
}


static void
freeMoveData(MoveData *data)
{
    if (data->topList)
        wfree(data->topList);
    if (data->leftList)
        wfree(data->leftList);
    if (data->rightList)
        wfree(data->rightList);
    if (data->bottomList)
        wfree(data->bottomList);
}


static void
updateMoveData(WWindow *wwin, MoveData *data)
{
    WScreen *scr = wwin->screen_ptr;
    WWindow *tmp;
    int i;

    data->count = 0;
    tmp = scr->focused_window;
    while (tmp) {
        if (tmp != wwin && scr->current_workspace == tmp->frame->workspace
            && !tmp->flags.miniaturized
            && !tmp->flags.hidden
            && !tmp->flags.obscured
            && !WFLAGP(tmp, sunken)) {
            data->topList[data->count] = tmp;
            data->leftList[data->count] = tmp;
            data->rightList[data->count] = tmp;
            data->bottomList[data->count] = tmp;
            data->count++;
        }
        tmp = tmp->prev;
    }

    if (data->count == 0) {
        data->topIndex = 0;
        data->leftIndex = 0;
        data->rightIndex = 0;
        data->bottomIndex = 0;
        return;
    }

    /* order from closest to the border of the screen to farthest */

    qsort(data->topList, data->count, sizeof(WWindow**), compareWTop);
    qsort(data->leftList, data->count, sizeof(WWindow**), compareWLeft);
    qsort(data->rightList, data->count, sizeof(WWindow**), compareWRight);
    qsort(data->bottomList, data->count, sizeof(WWindow**), compareWBottom);

    /* figure the position of the window relative to the others */

    data->topIndex = -1;
    data->leftIndex = -1;
    data->rightIndex = -1;
    data->bottomIndex = -1;

    if (WTOP(wwin) < WBOTTOM(data->bottomList[0])) {
        data->bottomIndex = 0;
    }
    if (WLEFT(wwin) < WRIGHT(data->rightList[0])) {
        data->rightIndex = 0;
    }
    if (WRIGHT(wwin) > WLEFT(data->leftList[0])) {
        data->leftIndex = 0;
    }
    if (WBOTTOM(wwin) > WTOP(data->topList[0])) {
        data->topIndex = 0;
    }
    for (i = 0; i < data->count; i++) {
        if (WTOP(wwin) >= WBOTTOM(data->bottomList[i])) {
            data->bottomIndex = i + 1;
        }
        if (WLEFT(wwin) >= WRIGHT(data->rightList[i])) {
            data->rightIndex = i + 1;
        }
        if (WRIGHT(wwin) <= WLEFT(data->leftList[i])) {
            data->leftIndex = i + 1;
        }
        if (WBOTTOM(wwin) <= WTOP(data->topList[i])) {
            data->topIndex = i + 1;
        }
    }
}


static void
initMoveData(WWindow *wwin, MoveData *data)
{
    int i;
    WWindow *tmp;

    memset(data, 0, sizeof(MoveData));

    for (i = 0, tmp = wwin->screen_ptr->focused_window;
         tmp != NULL;
         tmp = tmp->prev, i++);

    if (i > 1) {
        data->topList = wmalloc(sizeof(WWindow*) * i);
        data->leftList = wmalloc(sizeof(WWindow*) * i);
        data->rightList = wmalloc(sizeof(WWindow*) * i);
        data->bottomList = wmalloc(sizeof(WWindow*) * i);

        updateMoveData(wwin, data);
    }

    data->realX = wwin->frame_x;
    data->realY = wwin->frame_y;
    data->calcX = wwin->frame_x;
    data->calcY = wwin->frame_y;

    data->winWidth = wwin->frame->core->width +
        (HAS_BORDER_WITH_SELECT(wwin) ? 2*FRAME_BORDER_WIDTH : 0);
    data->winHeight = wwin->frame->core->height +
        (HAS_BORDER_WITH_SELECT(wwin) ? 2*FRAME_BORDER_WIDTH : 0);
}


static Bool
checkWorkspaceChange(WWindow *wwin, MoveData *data, Bool opaqueMove)
{
    WScreen *scr = wwin->screen_ptr;
    Bool changed = False;

    if (data->mouseX <= 1) {
        if (scr->current_workspace > 0) {

            crossWorkspace(scr, wwin, opaqueMove, scr->current_workspace - 1,
                           True);
            changed = True;
            data->rubCount = 0;

        } else if (scr->current_workspace == 0 && wPreferences.ws_cycle) {

            crossWorkspace(scr, wwin, opaqueMove, scr->workspace_count - 1,
                           True);
            changed = True;
            data->rubCount = 0;
        }
    } else if (data->mouseX >= scr->scr_width - 2) {

        if (scr->current_workspace == scr->workspace_count - 1) {

            if (wPreferences.ws_cycle
                || scr->workspace_count == MAX_WORKSPACES) {

                crossWorkspace(scr, wwin, opaqueMove, 0, False);
                changed = True;
                data->rubCount = 0;
            }
            /* if user insists on trying to go to next workspace even when
             * it's already the last, create a new one */
            else if (data->omouseX == data->mouseX
                     && wPreferences.ws_advance) {

                /* detect user "rubbing" the window against the edge */
                if (data->rubCount > 0
                    && data->omouseY - data->mouseY > MOVE_THRESHOLD) {

                    data->rubCount = -(data->rubCount + 1);

                } else if (data->rubCount <= 0
                           && data->mouseY - data->omouseY > MOVE_THRESHOLD) {

                    data->rubCount = -data->rubCount + 1;
                }
            }
            /* create a new workspace */
            if (abs(data->rubCount) > 2) {
                /* go to next workspace */
                wWorkspaceNew(scr);

                crossWorkspace(scr, wwin, opaqueMove,
                               scr->current_workspace+1, False);
                changed = True;
                data->rubCount = 0;
            }
        } else if (scr->current_workspace < scr->workspace_count) {

            /* go to next workspace */
            crossWorkspace(scr, wwin, opaqueMove,
                           scr->current_workspace+1, False);
            changed = True;
            data->rubCount = 0;
        }
    } else {
        data->rubCount = 0;
    }

    return changed;
}


static void
updateWindowPosition(WWindow *wwin, MoveData *data, Bool doResistance,
                     Bool opaqueMove, int newMouseX, int newMouseY)
{
    WScreen *scr = wwin->screen_ptr;
    int dx, dy;			       /* how much mouse moved */
    int winL, winR, winT, winB;	       /* requested new window position */
    int newX, newY;		       /* actual new window position */
    Bool hresist, vresist;
    Bool updateIndex;
    Bool attract;

    hresist = False;
    vresist = False;

    updateIndex = False;

    /* check the direction of the movement */
    dx = newMouseX - data->mouseX;
    dy = newMouseY - data->mouseY;

    data->omouseX = data->mouseX;
    data->omouseY = data->mouseY;
    data->mouseX = newMouseX;
    data->mouseY = newMouseY;

    winL = data->calcX + dx;
    winR = data->calcX + data->winWidth + dx;
    winT = data->calcY + dy;
    winB = data->calcY + data->winHeight + dy;

    newX = data->realX;
    newY = data->realY;

    if (doResistance) {
        int l_edge, r_edge;
        int edge_l, edge_r;
        int t_edge, b_edge;
        int edge_t, edge_b;
        int resist;

        resist = WIN_RESISTANCE(wPreferences.edge_resistance);
        attract = wPreferences.attract;
        /* horizontal movement: check horizontal edge resistances */
        if (dx || dy) {
            WMRect rect;
            int i, head;
            /* window is the leftmost window: check against screen edge */

            /* Add inter head resistance 1/2 (if needed) */
            head = wGetHeadForPointerLocation(scr);
            rect = wGetRectForHead(scr, head);

            l_edge = WMAX(scr->totalUsableArea[head].x1, rect.pos.x);
            edge_l = l_edge - resist;
            edge_r = WMIN(scr->totalUsableArea[head].x2, rect.pos.x + rect.size.width);
            r_edge = edge_r + resist;

            /* 1 */
            if ((data->rightIndex >= 0) && (data->rightIndex <= data->count)) {
                WWindow *looprw;

                for (i = data->rightIndex - 1; i >= 0; i--) {
                    looprw = data->rightList[i];
                    if (!(data->realY > WBOTTOM(looprw)
                          || (data->realY + data->winHeight) < WTOP(looprw))) {
                        if (attract
                            || ((data->realX < (WRIGHT(looprw) + 2)) && dx < 0)) {
                            l_edge = WRIGHT(looprw) + 1;
                            resist = WIN_RESISTANCE(wPreferences.edge_resistance);
                        }
                        break;
                    }
                }

                if (attract) {
                    for (i = data->rightIndex; i < data->count; i++) {
                        looprw = data->rightList[i];
                        if(!(data->realY > WBOTTOM(looprw)
                             || (data->realY + data->winHeight) < WTOP(looprw))) {
                            r_edge = WRIGHT(looprw) + 1;
                            resist = WIN_RESISTANCE(wPreferences.edge_resistance);
                            break;
                        }
                    }
                }
            }

            if ((data->leftIndex >= 0) && (data->leftIndex <= data->count)) {
                WWindow *looprw;

                for (i = data->leftIndex - 1; i >= 0; i--) {
                    looprw = data->leftList[i];
                    if (!(data->realY > WBOTTOM(looprw)
                          || (data->realY + data->winHeight) < WTOP(looprw))) {
                        if (attract
                            || (((data->realX + data->winWidth) > (WLEFT(looprw) - 1)) && dx > 0)) {
                            edge_r = WLEFT(looprw);
                            resist = WIN_RESISTANCE(wPreferences.edge_resistance);
                        }
                        break;
                    }
                }

                if (attract)
                    for (i = data->leftIndex; i < data->count; i++) {
                        looprw = data->leftList[i];
                        if(!(data->realY > WBOTTOM(looprw)
                             || (data->realY + data->winHeight) < WTOP(looprw))) {
                            edge_l = WLEFT(looprw);
                            resist = WIN_RESISTANCE(wPreferences.edge_resistance);
                            break;
                        }
                    }
            }

            /*
             printf("%d %d\n",winL,winR);
             printf("l_ %d r_ %d _l %d _r %d\n",l_edge,r_edge,edge_l,edge_r);
             */

            if ((winL - l_edge) < (r_edge - winL)) {
                if (resist > 0) {
                    if ((attract && winL <= l_edge + resist && winL >= l_edge - resist)
                        || (dx < 0 && winL <= l_edge && winL >= l_edge - resist)) {
                        newX = l_edge;
                        hresist = True;
                    }
                }
            } else {
                if (resist > 0 && attract && winL >= r_edge - resist && winL <= r_edge + resist) {
                    newX = r_edge;
                    hresist = True;
                }
            }

            if ((winR - edge_l) < (edge_r - winR)) {
                if (resist > 0 && attract && winR <= edge_l + resist && winR >= edge_l - resist) {
                    newX = edge_l - data->winWidth;
                    hresist = True;
                }
            } else {
                if (resist > 0) {
                    if ((attract && winR >= edge_r - resist && winR <= edge_r + resist)
                        || (dx > 0 && winR >= edge_r && winR <= edge_r + resist)) {
                        newX = edge_r - data->winWidth;
                        hresist = True;
                    }
                }
            }

            /* VeRT */
            /* Add inter head resistance 2/2 (if needed) */
            t_edge = WMAX(scr->totalUsableArea[head].y1, rect.pos.y);
            edge_t = t_edge - resist;
            edge_b = WMIN(scr->totalUsableArea[head].y2, rect.pos.y + rect.size.height);
            b_edge = edge_b + resist;

            if ((data->bottomIndex >= 0) && (data->bottomIndex <= data->count)) {
                WWindow *looprw;

                for (i = data->bottomIndex - 1; i >= 0; i--) {
                    looprw = data->bottomList[i];
                    if (!(data->realX > WRIGHT(looprw)
                          || (data->realX + data->winWidth) < WLEFT(looprw))) {
                        if (attract
                            || ((data->realY < (WBOTTOM(looprw) + 2)) && dy < 0)) {
                            t_edge = WBOTTOM(looprw) + 1;
                            resist = WIN_RESISTANCE(wPreferences.edge_resistance);
                        }
                        break;
                    }
                }

                if (attract) {
                    for (i = data->bottomIndex; i < data->count; i++) {
                        looprw = data->bottomList[i];
                        if(!(data->realX > WRIGHT(looprw)
                             || (data->realX + data->winWidth) < WLEFT(looprw))) {
                            b_edge = WBOTTOM(looprw) + 1;
                            resist = WIN_RESISTANCE(wPreferences.edge_resistance);
                            break;
                        }
                    }
                }
            }

            if ((data->topIndex >= 0) && (data->topIndex <= data->count)) {
                WWindow *looprw;

                for (i = data->topIndex - 1; i >= 0; i--) {
                    looprw = data->topList[i];
                    if (!(data->realX > WRIGHT(looprw)
                          || (data->realX + data->winWidth) < WLEFT(looprw))) {
                        if (attract
                            || (((data->realY + data->winHeight) > (WTOP(looprw) - 1)) && dy > 0)) {
                            edge_b = WTOP(looprw);
                            resist = WIN_RESISTANCE(wPreferences.edge_resistance);
                        }
                        break;
                    }
                }

                if (attract)
                    for (i = data->topIndex; i < data->count; i++) {
                        looprw = data->topList[i];
                        if(!(data->realX > WRIGHT(looprw)
                             || (data->realX + data->winWidth) < WLEFT(looprw))) {
                            edge_t = WTOP(looprw);
                            resist = WIN_RESISTANCE(wPreferences.edge_resistance);
                            break;
                        }
                    }
            }

            if ((winT - t_edge) < (b_edge - winT)) {
                if (resist > 0) {
                    if ((attract && winT <= t_edge + resist && winT >= t_edge - resist)
                        || (dy < 0 && winT <= t_edge && winT >= t_edge - resist)) {
                        newY = t_edge;
                        vresist = True;
                    }
                }
            }
            else {
                if (resist > 0 && attract && winT >= b_edge - resist && winT <= b_edge + resist) {
                    newY = b_edge;
                    vresist = True;
                }
            }

            if ((winB - edge_t) < (edge_b - winB)) {
                if (resist > 0 && attract && winB <= edge_t + resist && winB >= edge_t - resist) {
                    newY = edge_t - data->winHeight;
                    vresist = True;
                }
            }
            else {
                if (resist > 0) {
                    if ((attract && winB >= edge_b - resist && winB <= edge_b + resist)
                        || (dy > 0 && winB >= edge_b && winB <= edge_b + resist)) {
                        newY = edge_b - data->winHeight;
                        vresist = True;
                    }
                }
            }
        }
        /* END VeRT */

    }

    /* update window position */
    data->calcX += dx;
    data->calcY += dy;

    if (((dx > 0 && data->calcX - data->realX > 0)
         || (dx < 0 && data->calcX - data->realX < 0)) && !hresist)
        newX = data->calcX;

    if (((dy > 0 && data->calcY - data->realY > 0)
         || (dy < 0 && data->calcY - data->realY < 0)) && !vresist)
        newY = data->calcY;

    if (data->realX != newX || data->realY != newY) {

        if (wPreferences.move_display == WDIS_NEW
            && !scr->selected_windows) {
            showPosition(wwin, data->realX, data->realY);
        }
        if (opaqueMove) {
            doWindowMove(wwin, scr->selected_windows,
                         newX - wwin->frame_x,
                         newY - wwin->frame_y);
        } else {
            /* erase frames */
            drawFrames(wwin, scr->selected_windows,
                       data->realX - wwin->frame_x,
                       data->realY - wwin->frame_y);
        }

        if (!scr->selected_windows
            && wPreferences.move_display == WDIS_FRAME_CENTER) {

            moveGeometryDisplayCentered(scr, newX + data->winWidth/2,
                                        newY + data->winHeight/2);
        }

        if (!opaqueMove) {
            /* draw frames */
            drawFrames(wwin, scr->selected_windows,
                       newX - wwin->frame_x,
                       newY - wwin->frame_y);
        }

        if (!scr->selected_windows) {
            showPosition(wwin, newX, newY);
        }
    }


    /* recalc relative window position */
    if (doResistance && (data->realX != newX || data->realY != newY)) {
        updateResistance(wwin, data, newX, newY);
    }

    data->realX = newX;
    data->realY = newY;
}


#define _KS KEY_CONTROL_WINDOW_WEIGHT

#define MOVABLE_BIT	0x01
#define RESIZABLE_BIT	0x02

int
wKeyboardMoveResizeWindow(WWindow *wwin)
{
    WScreen *scr = wwin->screen_ptr;
    Window root = scr->root_win;
    XEvent event;
    int w = wwin->frame->core->width;
    int h = wwin->frame->core->height;
    int scr_width = wwin->screen_ptr->scr_width;
    int scr_height = wwin->screen_ptr->scr_height;
    int vert_border = wwin->frame->top_width + wwin->frame->bottom_width;
    int src_x = wwin->frame_x;
    int src_y = wwin->frame_y;
    int done,off_x,off_y,ww,wh;
    int kspeed = _KS;
    Time lastTime = 0;
    KeyCode shiftl, shiftr, ctrll, ctrlmode;
    KeySym keysym=NoSymbol;
    int moment=0;
    int modes = ((IS_MOVABLE(wwin)   ? MOVABLE_BIT   : 0) |
                 (IS_RESIZABLE(wwin) ? RESIZABLE_BIT : 0));
    int head = ((wPreferences.auto_arrange_icons && wXineramaHeads(scr)>1)
                ? wGetHeadForWindow(wwin)
                : scr->xine_info.primary_head);

    shiftl = XKeysymToKeycode(dpy, XK_Shift_L);
    shiftr = XKeysymToKeycode(dpy, XK_Shift_R);
    ctrll = XKeysymToKeycode(dpy, XK_Control_L);
    ctrlmode=done=off_x=off_y=0;

    if (modes == RESIZABLE_BIT) {
        ctrlmode = 1;
    }

    XSync(dpy, False);
    wusleep(10000);
    XGrabKeyboard(dpy, root, False, GrabModeAsync, GrabModeAsync, CurrentTime);

    if (!wwin->flags.selected) {
        wUnselectWindows(scr);
    }
    XGrabServer(dpy);
    XGrabPointer(dpy, scr->root_win, True, PointerMotionMask
                 |ButtonReleaseMask|ButtonPressMask, GrabModeAsync,
                 GrabModeAsync, None, wCursor[WCUR_DEFAULT], CurrentTime);

    if (wwin->flags.shaded || scr->selected_windows) {
        if(scr->selected_windows)
            drawFrames(wwin,scr->selected_windows,off_x,off_y);
        else drawTransparentFrame(wwin, src_x+off_x, src_y+off_y, w, h);
        if(!scr->selected_windows)
            mapPositionDisplay(wwin, src_x, src_y, w, h);
    } else {
        drawTransparentFrame(wwin, src_x+off_x, src_y+off_y, w, h);
    }
    ww=w;
    wh=h;
    while(1) {
        /*
         looper.ox=off_x;
         looper.oy=off_y;
         */
        do {
            WMMaskEvent(dpy, KeyPressMask | ButtonReleaseMask
                        | ButtonPressMask | ExposureMask, &event);
            if (event.type == Expose) {
                WMHandleEvent(&event);
            }
        } while (event.type == Expose);


        if (wwin->flags.shaded || scr->selected_windows) {
            if(scr->selected_windows)
                drawFrames(wwin,scr->selected_windows,off_x,off_y);
            else drawTransparentFrame(wwin, src_x+off_x, src_y+off_y, w, h);
            /*** I HATE EDGE RESISTANCE - ]d ***/
        }
        else {
            drawTransparentFrame(wwin, src_x+off_x, src_y+off_y, ww, wh);
        }

        if(ctrlmode)
            showGeometry(wwin, src_x+off_x, src_y+off_y, src_x+off_x+ww, src_y+off_y+wh,0);

        XUngrabServer(dpy);
        XSync(dpy, False);

        switch (event.type) {
        case KeyPress:
            /* accelerate */
            if (event.xkey.time - lastTime > 50) {
                kspeed/=(1 + (event.xkey.time - lastTime)/100);
            } else {
                if (kspeed < 20) {
                    kspeed++;
                }
            }
            if (kspeed < _KS) kspeed = _KS;
            lastTime = event.xkey.time;
            if (modes == (MOVABLE_BIT|RESIZABLE_BIT)) {
                if ((event.xkey.state & ControlMask) && !wwin->flags.shaded) {
                    ctrlmode=1;
                    wUnselectWindows(scr);
                }
                else {
                    ctrlmode=0;
                }
            }
            if (event.xkey.keycode == shiftl || event.xkey.keycode == shiftr) {
                if (ctrlmode)
                    cycleGeometryDisplay(wwin, src_x+off_x, src_y+off_y, ww, wh, 0);
                else
                    cyclePositionDisplay(wwin, src_x+off_x, src_y+off_y, ww, wh);
            }
            else {

                keysym = XLookupKeysym(&event.xkey, 0);
                switch (keysym) {
                case XK_Return:
                    done=2;
                    break;
                case XK_Escape:
                    done=1;
                    break;
                case XK_Up:
#ifdef XK_KP_Up
                case XK_KP_Up:
#endif
                case XK_k:
                    if (ctrlmode){
                        if (moment != UP)
                            h = wh;
                        h-=kspeed;
                        moment = UP;
                        if (h < 1) h = 1;
                    }
                    else off_y-=kspeed;
                    break;
                case XK_Down:
#ifdef XK_KP_Down
                case XK_KP_Down:
#endif
                case XK_j:
                    if (ctrlmode){
                        if (moment != DOWN)
                            h = wh;
                        h+=kspeed;
                        moment = DOWN;
                    }
                    else off_y+=kspeed;
                    break;
                case XK_Left:
#ifdef XK_KP_Left
                case XK_KP_Left:
#endif
                case XK_h:
                    if (ctrlmode) {
                        if (moment != LEFT)
                            w = ww;
                        w-=kspeed;
                        if (w < 1) w = 1;
                        moment = LEFT;
                    }
                    else off_x-=kspeed;
                    break;
                case XK_Right:
#ifdef XK_KP_Right
                case XK_KP_Right:
#endif
                case XK_l:
                    if (ctrlmode) {
                        if (moment != RIGHT)
                            w = ww;
                        w+=kspeed;
                        moment = RIGHT;
                    }
                    else off_x+=kspeed;
                    break;
                }

                ww=w;wh=h;
                wh-=vert_border;
                wWindowConstrainSize(wwin, (unsigned int*)&ww, (unsigned int*)&wh);
                wh+=vert_border;

                if (wPreferences.ws_cycle){
                    if (src_x + off_x + ww < 20){
                        if(!scr->current_workspace) {
                            wWorkspaceChange(scr, scr->workspace_count-1);
                        }
                        else wWorkspaceChange(scr, scr->current_workspace-1);
                        off_x += scr_width;
                    }
                    else if (src_x + off_x + 20 > scr_width){
                        if(scr->current_workspace == scr->workspace_count-1) {
                            wWorkspaceChange(scr, 0);
                        }
                        else wWorkspaceChange(scr, scr->current_workspace+1);
                        off_x -= scr_width;
                    }
                }
                else {
                    if (src_x + off_x + ww < 20)
                        off_x = 20 - ww - src_x;
                    else if (src_x + off_x + 20 > scr_width)
                        off_x = scr_width - 20 - src_x;
                }

                if (src_y + off_y + wh < 20) {
                    off_y = 20 - wh - src_y;
                }
                else if (src_y + off_y + 20 > scr_height) {
                    off_y = scr_height - 20 - src_y;
                }
            }
            break;
        case ButtonPress:
        case ButtonRelease:
            done=1;
            break;
        case Expose:
            WMHandleEvent(&event);
            while (XCheckTypedEvent(dpy, Expose, &event)) {
                WMHandleEvent(&event);
            }
            break;

        default:
            WMHandleEvent(&event);
            break;
        }

        XGrabServer(dpy);
        /*xxx*/

        if (wwin->flags.shaded && !scr->selected_windows){
            moveGeometryDisplayCentered(scr, src_x+off_x + w/2, src_y+off_y + h/2);
        } else {
            if (ctrlmode) {
                WMUnmapWidget(scr->gview);
                mapGeometryDisplay(wwin, src_x+off_x, src_y+off_y, ww, wh);
            } else if(!scr->selected_windows) {
                WMUnmapWidget(scr->gview);
                mapPositionDisplay(wwin, src_x+off_x, src_y+off_y, ww, wh);
            }
        }

        if (wwin->flags.shaded || scr->selected_windows) {
            if (scr->selected_windows)
                drawFrames(wwin,scr->selected_windows,off_x,off_y);
            else
                drawTransparentFrame(wwin, src_x+off_x, src_y+off_y, w, h);
        } else {
            drawTransparentFrame(wwin, src_x+off_x, src_y+off_y, ww, wh);
        }


        if (ctrlmode) {
            showGeometry(wwin, src_x+off_x, src_y+off_y, src_x+off_x+ww, src_y+off_y+wh,0);
        } else if(!scr->selected_windows)
            showPosition(wwin, src_x+off_x, src_y+off_y);


        if (done) {
            scr->keymove_tick=0;
            /*
             WMDeleteTimerWithClientData(&looper);
             */
            if (wwin->flags.shaded || scr->selected_windows) {
                if(scr->selected_windows)
                    drawFrames(wwin,scr->selected_windows,off_x,off_y);
                else drawTransparentFrame(wwin, src_x+off_x, src_y+off_y, w, h);
            }
            else {
                drawTransparentFrame(wwin, src_x+off_x, src_y+off_y, ww, wh);
            }

            if (ctrlmode) {
                showGeometry(wwin, src_x+off_x, src_y+off_y, src_x+off_x+ww, src_y+off_y+wh,0);
                WMUnmapWidget(scr->gview);
            } else
                WMUnmapWidget(scr->gview);

            XUngrabKeyboard(dpy, CurrentTime);
            XUngrabPointer(dpy, CurrentTime);
            XUngrabServer(dpy);

            if(done==2) {
                if (wwin->flags.shaded || scr->selected_windows) {
                    if (!scr->selected_windows) {
                        wWindowMove(wwin, src_x+off_x, src_y+off_y);
                        wWindowSynthConfigureNotify(wwin);
                    } else {
                        WMArrayIterator iter;
                        WWindow *foo;

                        doWindowMove(wwin, scr->selected_windows, off_x, off_y);

                        WM_ITERATE_ARRAY(scr->selected_windows, foo, iter) {
                            wWindowSynthConfigureNotify(foo);
                        }
                    }
                } else {
                    if (wwin->client.width != ww)
                        wwin->flags.user_changed_width = 1;

                    if (wwin->client.height != wh - vert_border)
                        wwin->flags.user_changed_height = 1;

                    wWindowConfigure(wwin, src_x+off_x, src_y+off_y,
                                     ww, wh - vert_border);
                    wWindowSynthConfigureNotify(wwin);
                }
                wWindowChangeWorkspace(wwin, scr->current_workspace);
                wSetFocusTo(scr, wwin);
            }

            if (wPreferences.auto_arrange_icons && wXineramaHeads(scr)>1 &&
                head != wGetHeadForWindow(wwin)) {
                wArrangeIcons(scr, True);
            }


#if defined(NETWM_HINTS) && defined(VIRTUAL_DESKTOP)
            wWorkspaceResizeViewport(scr, scr->current_workspace);
#endif

            return 1;
        }
    }
}


/*
 *----------------------------------------------------------------------
 * wMouseMoveWindow--
 * 	Move the named window and the other selected ones (if any),
 * interactively. Also shows the position of the window, if only one
 * window is being moved.
 * 	If the window is not on the selected window list, the selected
 * windows are deselected.
 * 	If shift is pressed during the operation, the position display
 * is changed to another type.
 *
 * Returns:
 * 	True if the window was moved, False otherwise.
 *
 * Side effects:
 * 	The window(s) position is changed, and the client(s) are
 * notified about that.
 * 	The position display configuration may be changed.
 *----------------------------------------------------------------------
 */
int
wMouseMoveWindow(WWindow *wwin, XEvent *ev)
{
    WScreen *scr = wwin->screen_ptr;
    XEvent event;
    Window root = scr->root_win;
    KeyCode shiftl, shiftr;
    Bool done = False;
    int started = 0;
    int warped = 0;
    /* This needs not to change while moving, else bad things can happen */
    int opaqueMove = wPreferences.opaque_move;
    MoveData moveData;
    int head = ((wPreferences.auto_arrange_icons && wXineramaHeads(scr) > 1)
                ? wGetHeadForWindow(wwin)
                : scr->xine_info.primary_head);
#ifdef GHOST_WINDOW_MOVE
    RImage *rimg = InitGhostWindowMove(scr);
#endif

    if (!IS_MOVABLE(wwin))
        return False;

    if (wPreferences.opaque_move && !wPreferences.use_saveunders) {
        XSetWindowAttributes attr;

        attr.save_under = True;
        XChangeWindowAttributes(dpy, wwin->frame->core->window,
                                CWSaveUnder, &attr);
    }


    initMoveData(wwin, &moveData);

    moveData.mouseX = ev->xmotion.x_root;
    moveData.mouseY = ev->xmotion.y_root;

    if (!wwin->flags.selected) {
        /* this window is not selected, unselect others and move only wwin */
        wUnselectWindows(scr);
    }
#ifdef DEBUG
    puts("Moving window");
#endif
    shiftl = XKeysymToKeycode(dpy, XK_Shift_L);
    shiftr = XKeysymToKeycode(dpy, XK_Shift_R);
    while (!done) {
        if (warped) {
            int junk;
            Window junkw;

            /* XWarpPointer() doesn't seem to generate Motion events, so
             * we've got to simulate them */
            XQueryPointer(dpy, root, &junkw, &junkw, &event.xmotion.x_root,
                          &event.xmotion.y_root, &junk, &junk,
                          (unsigned *) &junk);
        } else {
            WMMaskEvent(dpy, KeyPressMask | ButtonMotionMask
                        | PointerMotionHintMask
                        | ButtonReleaseMask | ButtonPressMask | ExposureMask,
                        &event);

            if (event.type == MotionNotify) {
                /* compress MotionNotify events */
                while (XCheckMaskEvent(dpy, ButtonMotionMask, &event)) ;
                if (!checkMouseSamplingRate(&event))
                    continue;
            }
        }
        switch (event.type) {
        case KeyPress:
            if ((event.xkey.keycode == shiftl || event.xkey.keycode == shiftr)
                && started && !scr->selected_windows) {

                if (!opaqueMove) {
                    drawFrames(wwin, scr->selected_windows,
                               moveData.realX - wwin->frame_x,
                               moveData.realY - wwin->frame_y);
                }

                if (wPreferences.move_display == WDIS_NEW
                    && !scr->selected_windows) {
                    showPosition(wwin, moveData.realX, moveData.realY);
                    XUngrabServer(dpy);
                }
                cyclePositionDisplay(wwin, moveData.realX, moveData.realY,
                                     moveData.winWidth, moveData.winHeight);

                if (wPreferences.move_display == WDIS_NEW
                    && !scr->selected_windows) {
                    XGrabServer(dpy);
                    showPosition(wwin, moveData.realX, moveData.realY);
                }

                if (!opaqueMove) {
                    drawFrames(wwin, scr->selected_windows,
                               moveData.realX - wwin->frame_x,
                               moveData.realY - wwin->frame_y);
                }
                /*} else {
                 WMHandleEvent(&event); this causes problems needs fixing */
            }
            break;

        case MotionNotify:
            if (started) {
                updateWindowPosition(wwin, &moveData,
                                     scr->selected_windows == NULL
                                     && wPreferences.edge_resistance > 0,
                                     opaqueMove,
                                     event.xmotion.x_root,
                                     event.xmotion.y_root);

                if (!warped && !wPreferences.no_autowrap) {
                    int oldWorkspace = scr->current_workspace;

                    if (wPreferences.move_display == WDIS_NEW
                        && !scr->selected_windows) {
                        showPosition(wwin, moveData.realX, moveData.realY);
                        XUngrabServer(dpy);
                    }
                    if (!opaqueMove) {
                        drawFrames(wwin, scr->selected_windows,
                                   moveData.realX - wwin->frame_x,
                                   moveData.realY - wwin->frame_y);
                    }
                    if (checkWorkspaceChange(wwin, &moveData, opaqueMove)) {
                        if (scr->current_workspace != oldWorkspace
                            && wPreferences.edge_resistance > 0
                            && scr->selected_windows == NULL)
                            updateMoveData(wwin, &moveData);
                        warped = 1;
                    }
                    if (!opaqueMove) {
                        drawFrames(wwin, scr->selected_windows,
                                   moveData.realX - wwin->frame_x,
                                   moveData.realY - wwin->frame_y);
                    }
                    if (wPreferences.move_display == WDIS_NEW
                        && !scr->selected_windows) {
                        XSync(dpy, False);
                        showPosition(wwin, moveData.realX, moveData.realY);
                        XGrabServer(dpy);
                    }
                } else {
                    warped = 0;
                }
            } else if (abs(ev->xmotion.x_root - event.xmotion.x_root) >= MOVE_THRESHOLD
                       || abs(ev->xmotion.y_root - event.xmotion.y_root) >= MOVE_THRESHOLD) {

                XChangeActivePointerGrab(dpy, ButtonMotionMask
                                         | ButtonReleaseMask | ButtonPressMask,
                                         wCursor[WCUR_MOVE], CurrentTime);
                started = 1;
                XGrabKeyboard(dpy, root, False, GrabModeAsync, GrabModeAsync,
                              CurrentTime);

                if (!scr->selected_windows)
                    mapPositionDisplay(wwin, moveData.realX, moveData.realY,
                                       moveData.winWidth, moveData.winHeight);

                if (started && !opaqueMove)
                    drawFrames(wwin, scr->selected_windows, 0, 0);

                if (!opaqueMove || (wPreferences.move_display==WDIS_NEW
                                    && !scr->selected_windows)) {
                    XGrabServer(dpy);
                    if (wPreferences.move_display==WDIS_NEW)
                        showPosition(wwin, moveData.realX, moveData.realY);
                }
            }
            break;

        case ButtonPress:
            break;

        case ButtonRelease:
            if (event.xbutton.button != ev->xbutton.button)
                break;

            if (started) {
                XEvent e;
                if (!opaqueMove) {
                    drawFrames(wwin, scr->selected_windows,
                               moveData.realX - wwin->frame_x,
                               moveData.realY - wwin->frame_y);
                    XSync(dpy, 0);
                    doWindowMove(wwin, scr->selected_windows,
                                 moveData.realX - wwin->frame_x,
                                 moveData.realY - wwin->frame_y);
                }
#ifndef CONFIGURE_WINDOW_WHILE_MOVING
                wWindowSynthConfigureNotify(wwin);
#endif
                XUngrabKeyboard(dpy, CurrentTime);
                XUngrabServer(dpy);
                if (!opaqueMove) {
                    wWindowChangeWorkspace(wwin, scr->current_workspace);
                    wSetFocusTo(scr, wwin);
                }
                if (wPreferences.move_display == WDIS_NEW)
                    showPosition(wwin, moveData.realX, moveData.realY);

                /* discard all enter/leave events that happened until
                 * the time the button was released */
                while (XCheckTypedEvent(dpy, EnterNotify, &e)) {
                    if (e.xcrossing.time > event.xbutton.time) {
                        XPutBackEvent(dpy, &e);
                        break;
                    }
                }
                while (XCheckTypedEvent(dpy, LeaveNotify, &e)) {
                    if (e.xcrossing.time > event.xbutton.time) {
                        XPutBackEvent(dpy, &e);
                        break;
                    }
                }

                if (!scr->selected_windows) {
                    /* get rid of the geometry window */
                    WMUnmapWidget(scr->gview);
                }
            }
#ifdef DEBUG
            puts("End move window");
#endif
            done = True;
            break;

        default:
            if (started && !opaqueMove) {
                drawFrames(wwin, scr->selected_windows,
                           moveData.realX - wwin->frame_x,
                           moveData.realY - wwin->frame_y);
                XUngrabServer(dpy);
                WMHandleEvent(&event);
                XSync(dpy, False);
                XGrabServer(dpy);
                drawFrames(wwin, scr->selected_windows,
                           moveData.realX - wwin->frame_x,
                           moveData.realY - wwin->frame_y);
            } else {
                WMHandleEvent(&event);
            }
            break;
        }
    }

    if (wPreferences.opaque_move && !wPreferences.use_saveunders) {
        XSetWindowAttributes attr;

        attr.save_under = False;
        XChangeWindowAttributes(dpy, wwin->frame->core->window,
                                CWSaveUnder, &attr);

    }

    freeMoveData(&moveData);

    if (started && wPreferences.auto_arrange_icons && wXineramaHeads(scr)>1 &&
        head != wGetHeadForWindow(wwin)) {
        wArrangeIcons(scr, True);
    }

#if defined(NETWM_HINTS) && defined(VIRTUAL_DESKTOP)
    if (started)
        wWorkspaceResizeViewport(scr, scr->current_workspace);
#endif

    return started;
}


#define RESIZEBAR	1
#define HCONSTRAIN	2

static int
getResizeDirection(WWindow *wwin, int x, int y, int dx, int dy,
                   int flags)
{
    int w = wwin->frame->core->width - 1;
    int cw = wwin->frame->resizebar_corner_width;
    int dir;

    /* if not resizing through the resizebar */
    if (!(flags & RESIZEBAR)) {
        int xdir = (abs(x) < (wwin->client.width/2)) ? LEFT : RIGHT;
        int ydir = (abs(y) < (wwin->client.height/2)) ? UP : DOWN;
        if (abs(dx) < 2 || abs(dy) < 2) {
            if (abs(dy) > abs(dx))
                xdir = 0;
            else
                ydir = 0;
        }
        return (xdir | ydir);
    }

    /* window is too narrow. allow diagonal resize */
    if (cw * 2 >= w) {
        int ydir;

        if (flags & HCONSTRAIN)
            ydir = 0;
        else
            ydir = DOWN;
        if (x < cw)
            return (LEFT | ydir);
        else
            return (RIGHT | ydir);
    }
    /* vertical resize */
    if ((x > cw) && (x < w - cw))
        return DOWN;

    if (x < cw)
        dir = LEFT;
    else
        dir = RIGHT;

    if ((abs(dy) > 0) && !(flags & HCONSTRAIN))
        dir |= DOWN;

    return dir;
}


void
wMouseResizeWindow(WWindow *wwin, XEvent *ev)
{
    XEvent event;
    WScreen *scr = wwin->screen_ptr;
    Window root = scr->root_win;
    int vert_border = wwin->frame->top_width + wwin->frame->bottom_width;
    int fw = wwin->frame->core->width;
    int fh = wwin->frame->core->height;
    int fx = wwin->frame_x;
    int fy = wwin->frame_y;
    int is_resizebar = (wwin->frame->resizebar
                        && ev->xany.window==wwin->frame->resizebar->window);
    int orig_x, orig_y;
    int started;
    int dw, dh;
    int rw = fw, rh = fh;
    int rx1, ry1, rx2, ry2;
    int res = 0;
    KeyCode shiftl, shiftr;
    int h = 0;
    int orig_fx = fx;
    int orig_fy = fy;
    int orig_fw = fw;
    int orig_fh = fh;
    int head = ((wPreferences.auto_arrange_icons && wXineramaHeads(scr)>1)
                ? wGetHeadForWindow(wwin)
                : scr->xine_info.primary_head);

    if (!IS_RESIZABLE(wwin))
        return;

    if (wwin->flags.shaded) {
        wwarning("internal error: tryein");
        return;
    }
    orig_x = ev->xbutton.x_root;
    orig_y = ev->xbutton.y_root;

    started = 0;
#ifdef DEBUG
    puts("Resizing window");
#endif

    wUnselectWindows(scr);
    rx1 = fx;
    rx2 = fx + fw - 1;
    ry1 = fy;
    ry2 = fy + fh - 1;
    shiftl = XKeysymToKeycode(dpy, XK_Shift_L);
    shiftr = XKeysymToKeycode(dpy, XK_Shift_R);
    if (HAS_TITLEBAR(wwin))
        h = WMFontHeight(wwin->screen_ptr->title_font) + (wPreferences.window_title_clearance + TITLEBAR_EXTEND_SPACE) * 2;
    else
        h = 0;
    while (1) {
        WMMaskEvent(dpy, KeyPressMask | ButtonMotionMask
                    | ButtonReleaseMask | PointerMotionHintMask
                    | ButtonPressMask | ExposureMask, &event);
        if (!checkMouseSamplingRate(&event))
            continue;

        switch (event.type) {
        case KeyPress:
            showGeometry(wwin, fx, fy, fx + fw, fy + fh, res);
            if ((event.xkey.keycode == shiftl || event.xkey.keycode == shiftr)
                && started) {
                drawTransparentFrame(wwin, fx, fy, fw, fh);
                cycleGeometryDisplay(wwin, fx, fy, fw, fh, res);
                drawTransparentFrame(wwin, fx, fy, fw, fh);
            }
            showGeometry(wwin, fx, fy, fx + fw, fy + fh, res);
            break;

        case MotionNotify:
            if (started) {
                while (XCheckMaskEvent(dpy, ButtonMotionMask, &event)) ;

                dw = 0;
                dh = 0;

                orig_fx = fx;
                orig_fy = fy;
                orig_fw = fw;
                orig_fh = fh;

                if (res & LEFT)
                    dw = orig_x - event.xmotion.x_root;
                else if (res & RIGHT)
                    dw = event.xmotion.x_root - orig_x;
                if (res & UP)
                    dh = orig_y - event.xmotion.y_root;
                else if (res & DOWN)
                    dh = event.xmotion.y_root - orig_y;

                orig_x = event.xmotion.x_root;
                orig_y = event.xmotion.y_root;

                rw += dw;
                rh += dh;
                fw = rw;
                fh = rh - vert_border;
                wWindowConstrainSize(wwin, (unsigned int*)&fw, (unsigned int*)&fh);
                fh += vert_border;
                if (res & LEFT)
                    fx = rx2 - fw + 1;
                else if (res & RIGHT)
                    fx = rx1;
                if (res & UP)
                    fy = ry2 - fh + 1;
                else if (res & DOWN)
                    fy = ry1;
            } else if (abs(orig_x - event.xmotion.x_root) >= MOVE_THRESHOLD
                       || abs(orig_y - event.xmotion.y_root) >= MOVE_THRESHOLD) {
                int tx, ty;
                Window junkw;
                int flags;

                XTranslateCoordinates(dpy, root, wwin->frame->core->window,
                                      orig_x, orig_y, &tx, &ty, &junkw);

                /* check if resizing through resizebar */
                if (is_resizebar)
                    flags = RESIZEBAR;
                else
                    flags = 0;

                if (is_resizebar && ((ev->xbutton.state & ShiftMask)
                                     || abs(orig_y - event.xmotion.y_root) < HRESIZE_THRESHOLD))
                    flags |= HCONSTRAIN;

                res = getResizeDirection(wwin, tx, ty,
                                         orig_x - event.xmotion.x_root,
                                         orig_y - event.xmotion.y_root, flags);

                if (res == (UP|LEFT))
                    XChangeActivePointerGrab(dpy, ButtonMotionMask
                                             | ButtonReleaseMask | ButtonPressMask,
                                             wCursor[WCUR_TOPLEFTRESIZE], CurrentTime);
                else if (res == (UP|RIGHT))
                    XChangeActivePointerGrab(dpy, ButtonMotionMask
                                             | ButtonReleaseMask | ButtonPressMask,
                                             wCursor[WCUR_TOPRIGHTRESIZE], CurrentTime);
                else if (res == (DOWN|LEFT))
                    XChangeActivePointerGrab(dpy, ButtonMotionMask
                                             | ButtonReleaseMask | ButtonPressMask,
                                             wCursor[WCUR_BOTTOMLEFTRESIZE], CurrentTime);
                else if (res == (DOWN|RIGHT))
                    XChangeActivePointerGrab(dpy, ButtonMotionMask
                                             | ButtonReleaseMask | ButtonPressMask,
                                             wCursor[WCUR_BOTTOMRIGHTRESIZE], CurrentTime);
                else if (res == DOWN || res == UP)
                    XChangeActivePointerGrab(dpy, ButtonMotionMask
                                             | ButtonReleaseMask | ButtonPressMask,
                                             wCursor[WCUR_VERTICALRESIZE], CurrentTime);
                else if (res & (DOWN|UP))
                    XChangeActivePointerGrab(dpy, ButtonMotionMask
                                             | ButtonReleaseMask | ButtonPressMask,
                                             wCursor[WCUR_VERTICALRESIZE], CurrentTime);
                else if (res & (LEFT|RIGHT))
                    XChangeActivePointerGrab(dpy, ButtonMotionMask
                                             | ButtonReleaseMask | ButtonPressMask,
                                             wCursor[WCUR_HORIZONRESIZE], CurrentTime);

                XGrabKeyboard(dpy, root, False, GrabModeAsync, GrabModeAsync,
                              CurrentTime);

                XGrabServer(dpy);

                /* Draw the resize frame for the first time. */
                mapGeometryDisplay(wwin, fx, fy, fw, fh);

                drawTransparentFrame(wwin, fx, fy, fw, fh);

                showGeometry(wwin, fx, fy, fx + fw, fy + fh, res);

                started = 1;
            }
            if (started) {
                if (wPreferences.size_display == WDIS_FRAME_CENTER) {
                    drawTransparentFrame(wwin, orig_fx, orig_fy,
                                         orig_fw, orig_fh);
                    moveGeometryDisplayCentered(scr, fx + fw / 2, fy + fh / 2);
                    drawTransparentFrame(wwin, fx, fy, fw, fh);
                } else {
                    drawTransparentFrame(wwin, orig_fx, orig_fy,
                                         orig_fw, orig_fh);
                    drawTransparentFrame(wwin, fx, fy, fw, fh);
                }
                if (fh != orig_fh || fw != orig_fw) {
                    if (wPreferences.size_display == WDIS_NEW) {
                        showGeometry(wwin, orig_fx, orig_fy, orig_fx + orig_fw,
                                     orig_fy + orig_fh, res);
                    }
                    showGeometry(wwin, fx, fy, fx + fw, fy + fh, res);
                }
            }
            break;

        case ButtonPress:
            break;

        case ButtonRelease:
            if (event.xbutton.button != ev->xbutton.button)
                break;

            if (started) {
                showGeometry(wwin, fx, fy, fx + fw, fy + fh, res);

                drawTransparentFrame(wwin, fx, fy, fw, fh);

                XUngrabKeyboard(dpy, CurrentTime);
                WMUnmapWidget(scr->gview);
                XUngrabServer(dpy);

                if (wwin->client.width != fw)
                    wwin->flags.user_changed_width = 1;

                if (wwin->client.height != fh - vert_border)
                    wwin->flags.user_changed_height = 1;

                wWindowConfigure(wwin, fx, fy, fw, fh - vert_border);
            }
#ifdef DEBUG
            puts("End resize window");
#endif
            return;

        default:
            WMHandleEvent(&event);
        }
    }

    if (wPreferences.auto_arrange_icons && wXineramaHeads(scr) > 1 &&
        head != wGetHeadForWindow(wwin)) {
        wArrangeIcons(scr, True);
    }

#if defined(NETWM_HINTS) && defined(VIRTUAL_DESKTOP)
    wWorkspaceResizeViewport(scr, scr->current_workspace);
#endif
}

#undef LEFT
#undef RIGHT
#undef HORIZONTAL
#undef UP
#undef DOWN
#undef VERTICAL
#undef HCONSTRAIN
#undef RESIZEBAR

void
wUnselectWindows(WScreen *scr)
{
    WWindow *wwin;

    if (!scr->selected_windows)
        return;

    while (WMGetArrayItemCount(scr->selected_windows)) {
        wwin = WMGetFromArray(scr->selected_windows, 0);
        if (wwin->flags.miniaturized && wwin->icon && wwin->icon->selected)
            wIconSelect(wwin->icon);

        wSelectWindow(wwin, False);
    }
    WMFreeArray(scr->selected_windows);
    scr->selected_windows = NULL;
}

#ifndef LITE
static void
selectWindowsInside(WScreen *scr, int x1, int y1, int x2, int y2)
{
    WWindow *tmpw;

    /* select the windows and put them in the selected window list */
    tmpw = scr->focused_window;
    while (tmpw != NULL) {
        if (!(tmpw->flags.miniaturized || tmpw->flags.hidden)) {
            if ((tmpw->frame->workspace == scr->current_workspace
                 || IS_OMNIPRESENT(tmpw))
                && (tmpw->frame_x >= x1) && (tmpw->frame_y >= y1)
                && (tmpw->frame->core->width + tmpw->frame_x <= x2)
                && (tmpw->frame->core->height + tmpw->frame_y <= y2)) {
                wSelectWindow(tmpw, True);
            }
        }
        tmpw = tmpw->prev;
    }
}


void
wSelectWindows(WScreen *scr, XEvent *ev)
{
    XEvent event;
    Window root = scr->root_win;
    GC gc = scr->frame_gc;
    int xp = ev->xbutton.x_root;
    int yp = ev->xbutton.y_root;
    int w = 0, h = 0;
    int x = xp, y = yp;

#ifdef DEBUG
    puts("Selecting windows");
#endif
    if (XGrabPointer(dpy, scr->root_win, False, ButtonMotionMask
                     | ButtonReleaseMask | ButtonPressMask, GrabModeAsync,
                     GrabModeAsync, None, wCursor[WCUR_DEFAULT],
                     CurrentTime) != Success) {
        return;
    }
    XGrabServer(dpy);

    wUnselectWindows(scr);

    XDrawRectangle(dpy, root, gc, xp, yp, w, h);
    while (1) {
        WMMaskEvent(dpy, ButtonReleaseMask | PointerMotionMask
                    | ButtonPressMask, &event);

        switch (event.type) {
        case MotionNotify:
            XDrawRectangle(dpy, root, gc, x, y, w, h);
            x = event.xmotion.x_root;
            if (x < xp) {
                w = xp - x;
            } else {
                w = x - xp;
                x = xp;
            }
            y = event.xmotion.y_root;
            if (y < yp) {
                h = yp - y;
            } else {
                h = y - yp;
                y = yp;
            }
            XDrawRectangle(dpy, root, gc, x, y, w, h);
            break;

        case ButtonPress:
            break;

        case ButtonRelease:
            if (event.xbutton.button != ev->xbutton.button)
                break;

            XDrawRectangle(dpy, root, gc, x, y, w, h);
            XUngrabServer(dpy);
            XUngrabPointer(dpy, CurrentTime);
            selectWindowsInside(scr, x, y, x + w, y + h);

#ifdef DEBUG
            puts("End window selection");
#endif
            return;

        default:
            WMHandleEvent(&event);
            break;
        }
    }
}
#endif /* !LITE */

void
InteractivePlaceWindow(WWindow *wwin, int *x_ret, int *y_ret,
                       unsigned width, unsigned height)
{
    WScreen *scr = wwin->screen_ptr;
    Window root = scr->root_win;
    int x, y, h = 0;
    XEvent event;
    KeyCode shiftl, shiftr;
    Window junkw;
    int junk;

    if (XGrabPointer(dpy, root, True, PointerMotionMask | ButtonPressMask,
                     GrabModeAsync, GrabModeAsync, None,
                     wCursor[WCUR_DEFAULT], CurrentTime) != Success) {
        *x_ret = 0;
        *y_ret = 0;
        return;
    }
    if (HAS_TITLEBAR(wwin)) {
        h = WMFontHeight(scr->title_font) + (wPreferences.window_title_clearance + TITLEBAR_EXTEND_SPACE) * 2;
        height += h;
    }
    if (HAS_RESIZEBAR(wwin)) {
        height += RESIZEBAR_HEIGHT;
    }
    XGrabKeyboard(dpy, root, False, GrabModeAsync, GrabModeAsync, CurrentTime);
    XQueryPointer(dpy, root, &junkw, &junkw, &x, &y, &junk, &junk,
                  (unsigned *) &junk);
    mapPositionDisplay(wwin, x - width/2, y - h/2, width, height);

    drawTransparentFrame(wwin, x - width/2, y - h/2, width, height);

    shiftl = XKeysymToKeycode(dpy, XK_Shift_L);
    shiftr = XKeysymToKeycode(dpy, XK_Shift_R);
    while (1) {
        WMMaskEvent(dpy, PointerMotionMask|ButtonPressMask|ExposureMask|KeyPressMask,
                    &event);

        if (!checkMouseSamplingRate(&event))
            continue;

        switch (event.type) {
        case KeyPress:
            if ((event.xkey.keycode == shiftl)
                || (event.xkey.keycode == shiftr)) {
                drawTransparentFrame(wwin,
                                     x - width/2, y - h/2, width, height);
                cyclePositionDisplay(wwin,
                                     x - width/2, y - h/2, width, height);
                drawTransparentFrame(wwin,
                                     x - width/2, y - h/2, width, height);
            }
            break;

        case MotionNotify:
            drawTransparentFrame(wwin, x - width/2, y - h/2, width, height);

            x = event.xmotion.x_root;
            y = event.xmotion.y_root;

            if (wPreferences.move_display == WDIS_FRAME_CENTER)
                moveGeometryDisplayCentered(scr, x, y + (height - h) / 2);

            showPosition(wwin, x - width/2, y - h/2);

            drawTransparentFrame(wwin, x - width/2, y - h/2, width, height);

            break;

        case ButtonPress:
            drawTransparentFrame(wwin, x - width/2, y - h/2, width, height);
            XSync(dpy, 0);
            *x_ret = x - width/2;
            *y_ret = y - h/2;
            XUngrabPointer(dpy, CurrentTime);
            XUngrabKeyboard(dpy, CurrentTime);
            /* get rid of the geometry window */
            WMUnmapWidget(scr->gview);
            return;

        default:
            WMHandleEvent(&event);
            break;
        }
    }
}

