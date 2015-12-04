/*
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

#include "wconfig.h"

#ifdef BALLOON_TEXT

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#ifdef SHAPED_BALLOON
#include <X11/extensions/shape.h>
#endif

#include <stdlib.h>
#include <string.h>

#include <wraster/wraster.h>

#include "WindowMaker.h"
#include "screen.h"
#include "texture.h"
#include "wcore.h"
#include "framewin.h"
#include "icon.h"
#include "appicon.h"
#include "funcs.h"
#include "workspace.h"
#include "balloon.h"



extern WPreferences wPreferences;

typedef struct _WBalloon {
    Window window;

#ifdef SHAPED_BALLOON
    GC monoGC;
#endif
    int prevType;

    Window objectWindow;
    char *text;
    int h;

    WMHandlerID timer;

    Pixmap contents;

    char mapped;
    char ignoreTimer;
} WBalloon;


#define TOP	0
#define BOTTOM	1
#define LEFT	0
#define RIGHT	2

#define TLEFT	(TOP|LEFT)
#define TRIGHT 	(TOP|RIGHT)
#define BLEFT	(BOTTOM|LEFT)
#define BRIGHT	(BOTTOM|RIGHT)


static int
countLines(const char *text)
{
    const char *p = text;
    int h = 1;

    while (*p) {
        if (*p == '\n' && p[1] != 0)
            h++;
        p++;
    }
    return h;
}


static int
getMaxStringWidth(WMFont *font, char *text)
{
    char *p = text;
    char *pb = p;
    int pos = 0;
    int w = 0, wt;

    while (*p) {
        if (*p == '\n') {
            wt = WMWidthOfString(font, pb, pos);
            if (wt > w)
                w = wt;
            pos = 0;
            pb = p + 1;
        } else {
            pos++;
        }
        p++;
    }
    if (pos > 0) {
        wt = WMWidthOfString(font, pb, pos);
        if (wt > w)
            w = wt;
    }
    return w;
}


static void
drawMultiLineString(WMScreen *scr, Pixmap pixmap, WMColor *color,
                    WMFont *font, int x, int y, char *text, int len)
{
    char *p = text;
    char *pb = p;
    int l = 0, pos = 0;
    int height = WMFontHeight(font);

    while (*p && p - text < len) {
        if (*p == '\n') {
            WMDrawString(scr, pixmap, color, font, x, y + l * height, pb,
                         pos);
            l++;
            pos = 0;
            pb = p + 1;
        } else {
            pos++;
        }
        p++;
    }
    if (pos > 0) {
        WMDrawString(scr, pixmap, color, font, x, y + l * height, pb, pos);
    }
}




#ifdef SHAPED_BALLOON

#define 	SPACE	12


static void
drawBalloon(WScreen *scr, Pixmap bitmap, Pixmap pix, int x, int y, int w,
            int h, int side)
{
    GC bgc = scr->balloon->monoGC;
    GC gc = scr->draw_gc;
    int rad = h * 3 / 10;
    XPoint pt[3], ipt[3];
    int w1;

    /* outline */
    XSetForeground(dpy, bgc, 1);

    XFillArc(dpy, bitmap, bgc, x, y, rad, rad, 90 * 64, 90 * 64);
    XFillArc(dpy, bitmap, bgc, x, y + h - 1 - rad, rad, rad, 180 * 64,
             90 * 64);

    XFillArc(dpy, bitmap, bgc, x + w - 1 - rad, y, rad, rad, 0 * 64,
             90 * 64);
    XFillArc(dpy, bitmap, bgc, x + w - 1 - rad, y + h - 1 - rad, rad, rad,
             270 * 64, 90 * 64);

    XFillRectangle(dpy, bitmap, bgc, x, y + rad / 2, w, h - rad);
    XFillRectangle(dpy, bitmap, bgc, x + rad / 2, y, w - rad, h);

    /* interior */
    XSetForeground(dpy, gc, scr->white_pixel);

    XFillArc(dpy, pix, gc, x + 1, y + 1, rad, rad, 90 * 64, 90 * 64);
    XFillArc(dpy, pix, gc, x + 1, y + h - 2 - rad, rad, rad, 180 * 64,
             90 * 64);

    XFillArc(dpy, pix, gc, x + w - 2 - rad, y + 1, rad, rad, 0 * 64,
             90 * 64);
    XFillArc(dpy, pix, gc, x + w - 2 - rad, y + h - 2 - rad, rad, rad,
             270 * 64, 90 * 64);

    XFillRectangle(dpy, pix, gc, x + 1, y + 1 + rad / 2, w - 2,
                   h - 2 - rad);
    XFillRectangle(dpy, pix, gc, x + 1 + rad / 2, y + 1, w - 2 - rad,
                   h - 2);

    if (side & BOTTOM) {
        pt[0].y = y + h - 1;
        pt[1].y = y + h - 1 + SPACE;
        pt[2].y = y + h - 1;
        ipt[0].y = pt[0].y - 1;
        ipt[1].y = pt[1].y - 1;
        ipt[2].y = pt[2].y - 1;
    } else {
        pt[0].y = y;
        pt[1].y = y - SPACE;
        pt[2].y = y;
        ipt[0].y = pt[0].y + 1;
        ipt[1].y = pt[1].y + 1;
        ipt[2].y = pt[2].y + 1;
    }

    /*w1 = WMAX(h, 24); */
    w1 = WMAX(h, 21);

    if (side & RIGHT) {
        pt[0].x = x + w - w1 + 2 * w1 / 16;
        pt[1].x = x + w - w1 + 11 * w1 / 16;
        pt[2].x = x + w - w1 + 7 * w1 / 16;
        ipt[0].x = x + 1 + w - w1 + 2 * (w1 - 1) / 16;
        ipt[1].x = x + 1 + w - w1 + 11 * (w1 - 1) / 16;
        ipt[2].x = x + 1 + w - w1 + 7 * (w1 - 1) / 16;
        /*ipt[0].x = pt[0].x+1;
         ipt[1].x = pt[1].x;
         ipt[2].x = pt[2].x; */
    } else {
        pt[0].x = x + w1 - 2 * w1 / 16;
        pt[1].x = x + w1 - 11 * w1 / 16;
        pt[2].x = x + w1 - 7 * w1 / 16;
        ipt[0].x = x - 1 + w1 - 2 * (w1 - 1) / 16;
        ipt[1].x = x - 1 + w1 - 11 * (w1 - 1) / 16;
        ipt[2].x = x - 1 + w1 - 7 * (w1 - 1) / 16;
        /*ipt[0].x = pt[0].x-1;
         ipt[1].x = pt[1].x;
         ipt[2].x = pt[2].x; */
    }

    XFillPolygon(dpy, bitmap, bgc, pt, 3, Convex, CoordModeOrigin);
    XFillPolygon(dpy, pix, gc, ipt, 3, Convex, CoordModeOrigin);

    /* fix outline */
    XSetForeground(dpy, gc, scr->black_pixel);

    XDrawLines(dpy, pix, gc, pt, 3, CoordModeOrigin);
    if (side & RIGHT) {
        pt[0].x++;
        pt[2].x--;
    } else {
        pt[0].x--;
        pt[2].x++;
    }
    XDrawLines(dpy, pix, gc, pt, 3, CoordModeOrigin);
}


static Pixmap
makePixmap(WScreen *scr, int width, int height, int side, Pixmap *mask)
{
    WBalloon *bal = scr->balloon;
    Pixmap bitmap;
    Pixmap pixmap;
    int x, y;

    bitmap =
        XCreatePixmap(dpy, scr->root_win, width + SPACE, height + SPACE,
                      1);

    if (!bal->monoGC) {
        bal->monoGC = XCreateGC(dpy, bitmap, 0, NULL);
    }
    XSetForeground(dpy, bal->monoGC, 0);
    XFillRectangle(dpy, bitmap, bal->monoGC, 0, 0, width + SPACE,
                   height + SPACE);

    pixmap =
        XCreatePixmap(dpy, scr->root_win, width + SPACE, height + SPACE,
                      scr->w_depth);
    XSetForeground(dpy, scr->draw_gc, scr->black_pixel);
    XFillRectangle(dpy, pixmap, scr->draw_gc, 0, 0, width + SPACE,
                   height + SPACE);

    if (side & BOTTOM) {
        y = 0;
    } else {
        y = SPACE;
    }
    x = 0;

    drawBalloon(scr, bitmap, pixmap, x, y, width, height, side);

    *mask = bitmap;

    return pixmap;
}


static void
showText(WScreen *scr, int x, int y, int h, int w, char *text)
{
    int width;
    int height;
    Pixmap pixmap;
    Pixmap mask;
    WMFont *font = scr->info_text_font;
    int side = 0;
    int ty;
    int bx, by;

    if (scr->balloon->contents)
        XFreePixmap(dpy, scr->balloon->contents);

    width = getMaxStringWidth(font, text) + 16;
    height = countLines(text) * WMFontHeight(font) + 4;

    if (height < 16)
        height = 16;
    if (width < height)
        width = height;


    if (x + width > scr->scr_width) {
        side = RIGHT;
        bx = x - width + w / 2;
        if (bx < 0)
            bx = 0;
    } else {
        side = LEFT;
        bx = x + w / 2;
    }
    if (bx + width > scr->scr_width)
        bx = scr->scr_width - width;

    if (y - (height + SPACE) < 0) {
        side |= TOP;
        by = y + h - 1;
        ty = SPACE;
    } else {
        side |= BOTTOM;
        by = y - (height + SPACE);
        ty = 0;
    }
    pixmap = makePixmap(scr, width, height, side, &mask);

    drawMultiLineString(scr->wmscreen, pixmap, scr->black, font, 8, ty + 2,
                        text, strlen(text));

    XSetWindowBackgroundPixmap(dpy, scr->balloon->window, pixmap);
    scr->balloon->contents = pixmap;

    XResizeWindow(dpy, scr->balloon->window, width, height + SPACE);
    XShapeCombineMask(dpy, scr->balloon->window, ShapeBounding, 0, 0, mask,
                      ShapeSet);
    XFreePixmap(dpy, mask);
    XMoveWindow(dpy, scr->balloon->window, bx, by);
    XMapRaised(dpy, scr->balloon->window);


    scr->balloon->mapped = 1;
}
#else				/* !SHAPED_BALLOON */


static void
showText(WScreen *scr, int x, int y, int h, int w, char *text)
{
    int width;
    int height;
    Pixmap pixmap;
    WMFont *font = scr->info_text_font;

    if (scr->balloon->contents)
        XFreePixmap(dpy, scr->balloon->contents);

    width = getMaxStringWidth(font, text) + 8;
    /*width = WMWidthOfString(font, text, strlen(text))+8;*/
    height = countLines(text) * WMFontHeight(font) + 4;

    if (x < 0)
        x = 0;
    else if (x + width > scr->scr_width - 1)
        x = scr->scr_width - width;

    if (y - height - 2 < 0) {
        y += h;
        if (y < 0)
            y = 0;
    } else {
        y -= height + 2;
    }

    if (scr->window_title_texture[0])
        XSetForeground(dpy, scr->draw_gc,
                       scr->window_title_texture[0]->any.color.pixel);
    else
        XSetForeground(dpy, scr->draw_gc, scr->light_pixel);

    pixmap =
        XCreatePixmap(dpy, scr->root_win, width, height, scr->w_depth);
    XFillRectangle(dpy, pixmap, scr->draw_gc, 0, 0, width, height);

    drawMultiLineString(scr->wmscreen, pixmap, scr->window_title_color[0],
                        font, 4, 2, text, strlen(text));

    XResizeWindow(dpy, scr->balloon->window, width, height);
    XMoveWindow(dpy, scr->balloon->window, x, y);

    XSetWindowBackgroundPixmap(dpy, scr->balloon->window, pixmap);
    XClearWindow(dpy, scr->balloon->window);
    XMapRaised(dpy, scr->balloon->window);

    scr->balloon->contents = pixmap;

    scr->balloon->mapped = 1;
}
#endif				/* !SHAPED_BALLOON */


static void
showBalloon(WScreen *scr)
{
    int x, y;
    Window foow;
    unsigned foo, w;

    if (scr->balloon) {
        scr->balloon->timer = NULL;
        scr->balloon->ignoreTimer = 1;
    }

    if (!XGetGeometry(dpy, scr->balloon->objectWindow, &foow, &x, &y,
                      &w, &foo, &foo, &foo)) {
        scr->balloon->prevType = 0;
        return;
    }
    showText(scr, x, y, scr->balloon->h, w, scr->balloon->text);
}


static void
frameBalloon(WObjDescriptor *object)
{
    WFrameWindow *fwin = (WFrameWindow *) object->parent;
    WScreen *scr = fwin->core->screen_ptr;

    if (fwin->titlebar != object->self
        || !fwin->flags.is_client_window_frame) {
        wBalloonHide(scr);
        return;
    }
    if (fwin->title && fwin->flags.incomplete_title) {
        scr->balloon->h = (fwin->titlebar ? fwin->titlebar->height : 0);
        scr->balloon->text = wstrdup(fwin->title);
        scr->balloon->objectWindow = fwin->core->window;
        scr->balloon->timer = WMAddTimerHandler(BALLOON_DELAY,
                                                (WMCallback *) showBalloon,
                                                scr);
    }
}


static void
miniwindowBalloon(WObjDescriptor *object)
{
    WIcon *icon = (WIcon *) object->parent;
    WScreen *scr = icon->core->screen_ptr;

    if (!icon->icon_name) {
        wBalloonHide(scr);
        return;
    }
    scr->balloon->h = icon->core->height;
    scr->balloon->text = wstrdup(icon->icon_name);
    scr->balloon->objectWindow = icon->core->window;
    if ((scr->balloon->prevType == object->parent_type
         || scr->balloon->prevType == WCLASS_APPICON)
        && scr->balloon->ignoreTimer) {
        XUnmapWindow(dpy, scr->balloon->window);
        showBalloon(scr);
    } else {
        scr->balloon->timer = WMAddTimerHandler(BALLOON_DELAY,
                                                (WMCallback *) showBalloon,
                                                scr);
    }
}


static void
appiconBalloon(WObjDescriptor *object)
{
    WAppIcon *aicon = (WAppIcon *) object->parent;
    WScreen *scr = aicon->icon->core->screen_ptr;
    char *tmp;

    if (aicon->command && aicon->wm_class) {
        int len = strlen(aicon->command) + strlen(aicon->wm_class) + 8;
        tmp = wmalloc(len);
        snprintf(tmp, len, "%s\n(%s)", aicon->wm_class, aicon->command);
        scr->balloon->text = tmp;
    } else if (aicon->command) {
        scr->balloon->text = wstrdup(aicon->command);
    } else if (aicon->wm_class) {
        scr->balloon->text = wstrdup(aicon->wm_class);
    } else {
        wBalloonHide(scr);
        return;
    }
    scr->balloon->h = aicon->icon->core->height - 2;

    scr->balloon->objectWindow = aicon->icon->core->window;
    if ((scr->balloon->prevType == object->parent_type
         || scr->balloon->prevType == WCLASS_MINIWINDOW)
        && scr->balloon->ignoreTimer) {
        XUnmapWindow(dpy, scr->balloon->window);
        showBalloon(scr);
    } else {
        scr->balloon->timer = WMAddTimerHandler(BALLOON_DELAY,
                                                (WMCallback *) showBalloon,
                                                scr);
    }
}



void
wBalloonInitialize(WScreen *scr)
{
    WBalloon *bal;
    XSetWindowAttributes attribs;
    unsigned long vmask;

    bal = wmalloc(sizeof(WBalloon));
    memset(bal, 0, sizeof(WBalloon));

    scr->balloon = bal;

    vmask = CWSaveUnder | CWOverrideRedirect | CWColormap | CWBackPixel
        | CWBorderPixel;
    attribs.save_under = True;
    attribs.override_redirect = True;
    attribs.colormap = scr->w_colormap;
    attribs.background_pixel = scr->icon_back_texture->normal.pixel;
    attribs.border_pixel = 0;	/* do not care */

    bal->window = XCreateWindow(dpy, scr->root_win, 1, 1, 10, 10, 1,
                                scr->w_depth, CopyFromParent,
                                scr->w_visual, vmask, &attribs);
#if 0
    /* select EnterNotify to so that the balloon will be unmapped
     * when the pointer is moved over it */
    XSelectInput(dpy, bal->window, EnterWindowMask);
#endif
}


void
wBalloonEnteredObject(WScreen *scr, WObjDescriptor *object)
{
    WBalloon *balloon = scr->balloon;

    if (balloon->timer) {
        WMDeleteTimerHandler(balloon->timer);
        balloon->timer = NULL;
        balloon->ignoreTimer = 0;
    }

    if (scr->balloon->text)
        wfree(scr->balloon->text);
    scr->balloon->text = NULL;

    if (!object) {
        wBalloonHide(scr);
        balloon->ignoreTimer = 0;
        return;
    }
    switch (object->parent_type) {
    case WCLASS_FRAME:
        if (wPreferences.window_balloon) {
            frameBalloon(object);
        }
        break;

    case WCLASS_DOCK_ICON:
        if (object->parent != scr->clip_icon
            && wPreferences.appicon_balloon)
            appiconBalloon(object);
        else
            wBalloonHide(scr);
        break;

    case WCLASS_MINIWINDOW:
        if (wPreferences.miniwin_balloon) {
            miniwindowBalloon(object);
        }
        break;
    case WCLASS_APPICON:
        if (wPreferences.appicon_balloon)
            appiconBalloon(object);
        break;
    default:
        wBalloonHide(scr);
        break;
    }
    scr->balloon->prevType = object->parent_type;
}



void
wBalloonHide(WScreen *scr)
{
    if (scr) {
        if (scr->balloon->mapped) {
            XUnmapWindow(dpy, scr->balloon->window);
            scr->balloon->mapped = 0;
        } else if (scr->balloon->timer) {
            WMDeleteTimerHandler(scr->balloon->timer);
            scr->balloon->timer = NULL;
        }
        scr->balloon->prevType = 0;
    }
}

#endif

