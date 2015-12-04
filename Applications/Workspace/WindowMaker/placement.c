/* placement.c - window and icon placement on screen
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
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>

#include "WindowMaker.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "icon.h"
#include "appicon.h"
#include "actions.h"
#include "funcs.h"
#include "application.h"
#include "appicon.h"
#include "dock.h"
#include "xinerama.h"


extern WPreferences wPreferences;


#define X_ORIGIN WMAX(usableArea.x1,\
    wPreferences.window_place_origin.x)

#define Y_ORIGIN WMAX(usableArea.y1,\
    wPreferences.window_place_origin.y)


/*
 * interactive window placement is in moveres.c
 */

extern void InteractivePlaceWindow(WWindow *wwin, int *x_ret, int *y_ret,
                                   unsigned width, unsigned height);


/*
 * Returns True if it is an icon and is in this workspace.
 */
static Bool
iconPosition(WCoreWindow *wcore, int sx1, int sy1, int sx2, int sy2,
             int workspace, int *retX, int *retY)
{
    void *parent;
    int ok = 0;

    parent = wcore->descriptor.parent;

    /* if it is an application icon */
    if (wcore->descriptor.parent_type == WCLASS_APPICON
        && !((WAppIcon*)parent)->docked) {
        *retX = ((WAppIcon*)parent)->x_pos;
        *retY = ((WAppIcon*)parent)->y_pos;

        ok = 1;
    } else if (wcore->descriptor.parent_type == WCLASS_MINIWINDOW &&
               (((WIcon*)parent)->owner->frame->workspace == workspace
                || IS_OMNIPRESENT(((WIcon*)parent)->owner)
                || wPreferences.sticky_icons)
               && ((WIcon*)parent)->mapped) {

        *retX = ((WIcon*)parent)->owner->icon_x;
        *retY = ((WIcon*)parent)->owner->icon_y;

        ok = 1;
    } else if (wcore->descriptor.parent_type == WCLASS_WINDOW
               && ((WWindow*)parent)->flags.icon_moved
               && (((WWindow*)parent)->frame->workspace == workspace
                   || IS_OMNIPRESENT((WWindow*)parent)
                   || wPreferences.sticky_icons)) {
        *retX = ((WWindow*)parent)->icon_x;
        *retY = ((WWindow*)parent)->icon_y;

        ok = 1;
    }


    /*
     * Check if it is inside the screen.
     */
    if (ok) {
        if (*retX < sx1-wPreferences.icon_size)
            ok = 0;
        else if (*retX > sx2)
            ok = 0;

        if (*retY < sy1-wPreferences.icon_size)
            ok = 0;
        else if (*retY > sy2)
            ok = 0;
    }

    return ok;
}




void
PlaceIcon(WScreen *scr, int *x_ret, int *y_ret, int head)
{
    int pf;			       /* primary axis */
    int sf;			       /* secondary axis */
    int fullW;
    int fullH;
    char *map;
    int pi, si;
    WCoreWindow *obj;
    int sx1, sx2, sy1, sy2;	       /* screen boundary */
    int sw, sh;
    int xo, yo;
    int xs, ys;
    int x, y;
    int isize = wPreferences.icon_size;
    int done = 0;
    WMBagIterator iter;
    WArea area = wGetUsableAreaForHead(scr, head, NULL, False);

    /* Find out screen boundaries. */

    /* Allows each head to have miniwindows */

    sx1 = area.x1;
    sy1 = area.y1;
    sx2 = area.x2;
    sy2 = area.y2;
    sw = sx2-sx1;
    sh = sy2-sy1;

#if 0
    if (scr->dock) {
        if (scr->dock->on_right_side)
            sx2 -= isize + DOCK_EXTRA_SPACE;
        else
            sx1 += isize + DOCK_EXTRA_SPACE;
    }
#endif

    sw = isize * (sw/isize);
    sh = isize * (sh/isize);
    fullW = (sx2-sx1)/isize;
    fullH = (sy2-sy1)/isize;

    /* icon yard boundaries */
    if (wPreferences.icon_yard & IY_VERT) {
        pf = fullH;
        sf = fullW;
    } else {
        pf = fullW;
        sf = fullH;
    }
    if (wPreferences.icon_yard & IY_RIGHT) {
        xo = sx2 - isize;
        xs = -1;
    } else {
        xo = sx1;
        xs = 1;
    }
    if (wPreferences.icon_yard & IY_TOP) {
        yo = sy1;
        ys = 1;
    } else {
        yo = sy2 - isize;
        ys = -1;
    }

    /*
     * Create a map with the occupied slots. 1 means the slot is used
     * or at least partially used.
     * The slot usage can be optimized by only marking fully used slots
     * or slots that have most of it covered.
     * Space usage is worse than the fvwm algorithm (used in the old version)
     * but complexity is much better (faster) than it.
     */
    map = wmalloc((sw+2) * (sh+2));
    memset(map, 0, (sw+2) * (sh+2));

#define INDEX(x,y)	(((y)+1)*(sw+2) + (x) + 1)

    WM_ETARETI_BAG(scr->stacking_list, obj, iter) {

        while (obj) {
            int x, y;

            if (iconPosition(obj, sx1, sy1, sx2, sy2, scr->current_workspace,
                             &x, &y)) {
                int xdi, ydi;	       /* rounded down */
                int xui, yui;	       /* rounded up */

                xdi = x/isize;
                ydi = y/isize;
                xui = (x+isize/2)/isize;
                yui = (y+isize/2)/isize;
                map[INDEX(xdi,ydi)] = 1;
                map[INDEX(xdi,yui)] = 1;
                map[INDEX(xui,ydi)] = 1;
                map[INDEX(xui,yui)] = 1;
            }
            obj = obj->stacking->under;
        }
    }
    /*
     * Default position
     */
    *x_ret = 0;
    *y_ret = 0;

    /*
     * Look for an empty slot
     */
    for (si=0; si<sf; si++) {
        for (pi=0; pi<pf; pi++) {
            if (wPreferences.icon_yard & IY_VERT) {
                x = xo + xs*(si*isize);
                y = yo + ys*(pi*isize);
            } else {
                x = xo + xs*(pi*isize);
                y = yo + ys*(si*isize);
            }
            if (!map[INDEX(x/isize, y/isize)]) {
                *x_ret = x;
                *y_ret = y;
                done = 1;
                break;
            }
        }
        if (done)
            break;
    }

    wfree(map);
}


/*
 * This function calculates the length of the intersection of two
 * line sections. (Hey, is that english?)
 */
static int
calcIntersectionLength(int p1, int l1, int p2, int l2)
{
    int isect;
    int tmp;

    if (p1 > p2) {
        tmp = p1;
        p1 = p2;
        p2 = tmp;
        tmp = l1;
        l1 = l2;
        l2 = tmp;
    }

    if (p1 + l1 < p2)
        isect = 0;
    else if (p2 + l2 < p1 + l1)
        isect = l2;
    else
        isect = p1 + l1 - p2;

    return isect;
}


/*
 * This function calculates the area of the intersection of two rectangles.
 */

int
calcIntersectionArea(int x1, int y1, int w1, int h1,
                     int x2, int y2, int w2, int h2)
{
    return calcIntersectionLength(x1, w1, x2, w2)
        * calcIntersectionLength(y1, h1, y2, h2);
}


static int
calcSumOfCoveredAreas(WWindow *wwin, int x, int y, int w, int h)
{
    int sum_isect = 0;
    WWindow *test_window;
    int tw,tx,ty,th;

    test_window = wwin->screen_ptr->focused_window;
    for(;test_window != NULL && test_window->prev != NULL;)
        test_window = test_window->prev;

    for(; test_window != NULL; test_window = test_window->next) {
        if (test_window->frame->core->stacking->window_level
            < WMNormalLevel) {
            continue;
        }

#if 0
        tw = test_window->client.width;
        if (test_window->flags.shaded)
            th = test_window->frame->top_width;
        else
            th = test_window->client.height + extra_height;
#else
        tw = test_window->frame->core->width;
        th = test_window->frame->core->height;
#endif
        tx = test_window->frame_x;
        ty = test_window->frame_y;

        if (test_window->flags.mapped ||
            (test_window->flags.shaded &&
             !(test_window->flags.miniaturized ||
               test_window->flags.hidden))) {
            sum_isect += calcIntersectionArea(tx, ty, tw, th, x, y, w, h);
        }
    }

    return sum_isect;
}


static void
smartPlaceWindow(WWindow *wwin, int *x_ret, int *y_ret,
                 unsigned int width, unsigned int height,
                 WArea usableArea)
{
    int test_x = 0, test_y = Y_ORIGIN;
    int from_x, to_x, from_y, to_y;
    int sx;
    int min_isect, min_isect_x, min_isect_y;
    int sum_isect;

    if (wwin->frame) {
        height += wwin->frame->top_width + wwin->frame->bottom_width;
    } else {
        if (HAS_TITLEBAR(wwin)) height += 18;
        if (HAS_RESIZEBAR(wwin)) height += 8;
    }
    if (HAS_BORDER(wwin)) {
        height += 2;
        width += 2;
    }
    sx = X_ORIGIN;

    min_isect = INT_MAX;
    min_isect_x = sx;
    min_isect_y = test_y;

    while (((test_y + height) < usableArea.y2)) {
        test_x = sx;
        while ((test_x + width) < usableArea.x2) {
            sum_isect = calcSumOfCoveredAreas(wwin, test_x, test_y,
                                              width, height);

            if (sum_isect < min_isect) {
                min_isect = sum_isect;
                min_isect_x = test_x;
                min_isect_y = test_y;
            }

            test_x += PLACETEST_HSTEP;
        }
        test_y += PLACETEST_VSTEP;
    }

    from_x = min_isect_x - PLACETEST_HSTEP + 1;
    from_x = WMAX(from_x, X_ORIGIN);
    to_x = min_isect_x + PLACETEST_HSTEP;
    if (to_x + width > usableArea.x2)
        to_x = usableArea.x2 - width;

    from_y = min_isect_y - PLACETEST_VSTEP + 1;
    from_y = WMAX(from_y, Y_ORIGIN);
    to_y = min_isect_y + PLACETEST_VSTEP;
    if (to_y + height > usableArea.y2)
        to_y = usableArea.y2 - height;

    for (test_x = from_x; test_x < to_x; test_x++) {
        for (test_y = from_y; test_y < to_y; test_y++) {
            sum_isect = calcSumOfCoveredAreas(wwin, test_x, test_y,
                                              width, height);

            if (sum_isect < min_isect) {
                min_isect = sum_isect;
                min_isect_x = test_x;
                min_isect_y = test_y;
            }
        }
    }

    *x_ret = min_isect_x;
    *y_ret = min_isect_y;
}


static Bool
autoPlaceWindow(WWindow *wwin, int *x_ret, int *y_ret,
                unsigned int width, unsigned int height, int tryCount,
                WArea usableArea)
{
    WScreen *scr = wwin->screen_ptr;
    int test_x = 0, test_y = Y_ORIGIN;
    int loc_ok = False, tw,tx,ty,th;
    int swidth, sx;
    WWindow *test_window;

    if (wwin->frame) {
        height += wwin->frame->top_width + wwin->frame->bottom_width;
    } else {
        if (HAS_TITLEBAR(wwin)) height += 18;
        if (HAS_RESIZEBAR(wwin)) height += 8;
    }
    if (HAS_BORDER(wwin)) {
        height += 2;
        width += 2;
    }

    swidth = usableArea.x2-usableArea.x1;
    sx = X_ORIGIN;

    /* this was based on fvwm2's smart placement */

    while (((test_y + height) < (usableArea.y2 - usableArea.y1)) && !loc_ok) {
        test_x = sx;

        while (((test_x + width) < swidth) && (!loc_ok)) {

            loc_ok = True;
            test_window = scr->focused_window;

            while ((test_window != NULL) && (loc_ok == True)) {

                if (test_window->frame->core->stacking->window_level
                    < WMNormalLevel && tryCount > 0) {
                    test_window = test_window->next;
                    continue;
                }
#if 0
                tw = test_window->client.width;
                if (test_window->flags.shaded)
                    th = test_window->frame->top_width;
                else
                    th = test_window->client.height + extra_height;
#else
                tw = test_window->frame->core->width;
                th = test_window->frame->core->height;
#endif
                tx = test_window->frame_x;
                ty = test_window->frame_y;

                if ((tx < (test_x + width)) && ((tx + tw) > test_x) &&
                    (ty < (test_y + height)) && ((ty + th) > test_y) &&
                    (test_window->flags.mapped ||
                     (test_window->flags.shaded &&
                      test_window->frame->workspace==scr->current_workspace &&
                      !(test_window->flags.miniaturized ||
                        test_window->flags.hidden)))) {

                    loc_ok = False;
                }
                test_window = test_window->next;
            }

            test_window = scr->focused_window;

            while ((test_window != NULL) && (loc_ok == True))  {

                if (test_window->frame->core->stacking->window_level
                    < WMNormalLevel && tryCount > 0) {
                    test_window = test_window->prev;
                    continue;
                }
#if 0
                tw = test_window->client.width;
                if (test_window->flags.shaded)
                    th = test_window->frame->top_width;
                else
                    th = test_window->client.height + extra_height;
#else
                tw = test_window->frame->core->width;
                th = test_window->frame->core->height;
#endif
                tx = test_window->frame_x;
                ty = test_window->frame_y;

                if ((tx < (test_x + width)) && ((tx + tw) > test_x) &&
                    (ty < (test_y + height)) && ((ty + th) > test_y) &&
                    (test_window->flags.mapped ||
                     (test_window->flags.shaded &&
                      test_window->frame->workspace==scr->current_workspace &&
                      !(test_window->flags.miniaturized ||
                        test_window->flags.hidden)))) {

                    loc_ok = False;
                }
                test_window = test_window->prev;
            }
            if (loc_ok == True) {
                *x_ret = test_x;
                *y_ret = test_y;
                break;
            }
            test_x += PLACETEST_HSTEP;
        }
        test_y += PLACETEST_VSTEP;
    }

    return loc_ok;
}


static void
cascadeWindow(WScreen *scr, WWindow *wwin, int *x_ret, int *y_ret,
              unsigned int width, unsigned int height, int h,
              WArea usableArea)
{
    if (wwin->frame) {
        height += wwin->frame->top_width + wwin->frame->bottom_width;
    } else {
        if (HAS_TITLEBAR(wwin)) height += 18;
        if (HAS_RESIZEBAR(wwin)) height += 8;
    }
    if (HAS_BORDER(wwin)) {
        height += 2;
        width += 2;
    }

    *x_ret = h * scr->cascade_index + X_ORIGIN;
    *y_ret = h * scr->cascade_index + Y_ORIGIN;

    if (width + *x_ret > usableArea.x2 || height + *y_ret > usableArea.y2) {
        scr->cascade_index = 0;
        *x_ret = X_ORIGIN;
        *y_ret = Y_ORIGIN;
    }
}


static void
randomPlaceWindow(WScreen *scr, WWindow *wwin, int *x_ret, int *y_ret,
                  unsigned int width, unsigned int height,
                  WArea usableArea)
{
    int w, h;

    if (wwin->frame) {
        height += wwin->frame->top_width + wwin->frame->bottom_width;
    } else {
        if (HAS_TITLEBAR(wwin)) height += 18;
        if (HAS_RESIZEBAR(wwin)) height += 8;
    }
    if (HAS_BORDER(wwin)) {
        height += 2;
        width += 2;
    }

    w = ((usableArea.x2-X_ORIGIN) - width);
    h = ((usableArea.y2-Y_ORIGIN) - height);
    if (w<1) w = 1;
    if (h<1) h = 1;
    *x_ret = X_ORIGIN + rand()%w;
    *y_ret = Y_ORIGIN + rand()%h;
}



void
PlaceWindow(WWindow *wwin, int *x_ret, int *y_ret,
            unsigned width, unsigned height)
{
    WScreen *scr = wwin->screen_ptr;
    int h = WMFontHeight(scr->title_font) + (wPreferences.window_title_clearance + TITLEBAR_EXTEND_SPACE) * 2;
    WArea usableArea = wGetUsableAreaForHead(scr,
                                             wGetHeadForPointerLocation(scr),
                                             NULL, True);

    switch (wPreferences.window_placement) {
    case WPM_MANUAL:
        InteractivePlaceWindow(wwin, x_ret, y_ret, width, height);
        break;

    case WPM_SMART:
        smartPlaceWindow(wwin, x_ret, y_ret, width, height, usableArea);
        break;

    case WPM_AUTO:
        if (autoPlaceWindow(wwin, x_ret, y_ret, width, height, 0,
                            usableArea)) {
            break;
        } else if (autoPlaceWindow(wwin, x_ret, y_ret, width, height, 1,
                                   usableArea)) {
            break;
        }
        /* there isn't a break here, because if we fail, it should fall
         through to cascade placement, as people who want tiling want
         automagicness aren't going to want to place their window */

    case WPM_CASCADE:
        if (wPreferences.window_placement == WPM_AUTO)
            scr->cascade_index++;

        cascadeWindow(scr, wwin, x_ret, y_ret, width, height, h, usableArea);

        if (wPreferences.window_placement == WPM_CASCADE)
            scr->cascade_index++;
        break;

    case WPM_RANDOM:
        randomPlaceWindow(scr, wwin, x_ret, y_ret, width, height, usableArea);
        break;

#ifdef DEBUG
    default:
        puts("Invalid window placement!!!");
        *x_ret = 0;
        *y_ret = 0;
#endif
    }

    /*
     * clip to usableArea instead of full screen
     * this will also take dock/clip etc.. into account
     * aswell as being xinerama friendly
     */
    if (*x_ret + width > usableArea.x2)
        *x_ret = usableArea.x2 - width;
    if (*x_ret < usableArea.x1)
        *x_ret = usableArea.x1;

    if (*y_ret + height > usableArea.y2)
        *y_ret = usableArea.y2 - height;
    if (*y_ret < usableArea.y1)
        *y_ret = usableArea.y1;
}


