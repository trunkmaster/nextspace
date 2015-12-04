/*
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <time.h>

#include <wraster/wraster.h>

#include "WindowMaker.h"
#include "screen.h"
#include "superfluous.h"
#include "dock.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "icon.h"
#include "appicon.h"


extern WPreferences wPreferences;


#ifdef SPEAKER_SOUND
static void
play(Display *dpy, int pitch, int delay)
{
    XKeyboardControl kc;

    kc.bell_pitch = pitch;
    kc.bell_percent = 50;
    kc.bell_duration = delay;
    XChangeKeyboardControl(dpy, KBBellPitch|KBBellDuration|KBBellPercent,&kc);
    XBell(dpy, 50);
    XFlush(dpy);
    wusleep(delay);
}
#endif



#ifdef DEMATERIALIZE_ICON
void
DoKaboom(WScreen *scr, Window win, int x, int y)
{
    RImage *icon;
    RImage *back;
    RImage *image;
    Pixmap pixmap;
    XImage *ximage;
    GC gc;
    XGCValues gcv;
    int i;
    int w, h;
    int run;
    XEvent event;

    h = w = wPreferences.icon_size;
    if (x < 0 || x + w > scr->scr_width || y < 0 || y + h > scr->scr_height)
        return;

    icon = RCreateImageFromDrawable(scr->rcontext, win, None);
    if (!icon)
        return;

    gcv.foreground = scr->white_pixel;
    gcv.background = scr->black_pixel;
    gcv.graphics_exposures = False;
    gcv.subwindow_mode = IncludeInferiors;
    gc = XCreateGC(dpy, scr->w_win, GCForeground|GCBackground|GCSubwindowMode
                   |GCGraphicsExposures, &gcv);


    XGrabServer(dpy);
    RConvertImage(scr->rcontext, icon, &pixmap);
    XUnmapWindow(dpy, win);

    ximage = XGetImage(dpy, scr->root_win, x, y, w, h, AllPlanes, ZPixmap);
    XCopyArea(dpy, pixmap, scr->root_win, gc, 0, 0, w, h, x, y);
    XFreePixmap(dpy,pixmap);

    back = RCreateImageFromXImage(scr->rcontext, ximage, NULL);
    XDestroyImage(ximage);
    if (!back) {
        RReleaseImage(icon);
        return;
    }


    for (i=0,run=0; i<DEMATERIALIZE_STEPS; i++) {
        XEvent foo;
        if (!run && XCheckTypedEvent(dpy, ButtonPress, &foo)) {
            run=1;
            XPutBackEvent(dpy, &foo);
        }
        image = RCloneImage(back);
        RCombineImagesWithOpaqueness(image, icon,
                                     (DEMATERIALIZE_STEPS-1-i)*256/(DEMATERIALIZE_STEPS+2));
        RConvertImage(scr->rcontext, image, &pixmap);
        XCopyArea(dpy, pixmap, scr->root_win, gc, 0, 0, w, h, x, y);
        XFreePixmap(dpy, pixmap);
        XFlush(dpy);
        if(!run) wusleep(1000);
    }

    while (XCheckTypedEvent(dpy, MotionNotify, &event)) {
    }
    XFlush(dpy);

    XUngrabServer(dpy);
    XFreeGC(dpy, gc);
    RReleaseImage(icon);
    RReleaseImage(back);
}
#endif /* DEMATERIALIZE_ICON */






#ifdef NORMAL_ICON_KABOOM
void
DoKaboom(WScreen *scr, Window win, int x, int y)
{
    int i, j, k;
    int sw=scr->scr_width, sh=scr->scr_height;
#define KAB_PRECISION	4
    int px[PIECES];
    short py[PIECES];
#ifdef ICON_KABOOM_EXTRA
    short ptx[2][PIECES], pty[2][PIECES];
    int ll;
#endif
    char pvx[PIECES], pvy[PIECES];
    /* in MkLinux/PPC gcc seems to think that char is unsigned? */
    signed char ax[PIECES], ay[PIECES];
    Pixmap tmp;

    XSetClipMask(dpy, scr->copy_gc, None);
    tmp = XCreatePixmap(dpy, scr->root_win, wPreferences.icon_size,
                        wPreferences.icon_size, scr->depth);
    if (scr->w_visual == DefaultVisual(dpy, scr->screen))
        XCopyArea(dpy, win, tmp, scr->copy_gc, 0, 0, wPreferences.icon_size,
                  wPreferences.icon_size, 0, 0);
    else {
        XImage *image;

        image = XGetImage(dpy, win, 0, 0, wPreferences.icon_size,
                          wPreferences.icon_size, AllPlanes, ZPixmap);
        if (!image) {
            XUnmapWindow(dpy, win);
            return;
        }
        XPutImage(dpy, tmp, scr->copy_gc, image, 0, 0, 0, 0,
                  wPreferences.icon_size, wPreferences.icon_size);
        XDestroyImage(image);
    }

    for (i=0,k=0; i<wPreferences.icon_size/ICON_KABOOM_PIECE_SIZE && k<PIECES;
         i++) {
        for (j=0; j<wPreferences.icon_size/ICON_KABOOM_PIECE_SIZE && k<PIECES;
             j++) {
            if (rand()%2) {
                ax[k]=i;
                ay[k]=j;
                px[k]=(x+i*ICON_KABOOM_PIECE_SIZE)<<KAB_PRECISION;
                py[k]=y+j*ICON_KABOOM_PIECE_SIZE;
                pvx[k]=rand()%(1<<(KAB_PRECISION+3))-(1<<(KAB_PRECISION+3))/2;
                pvy[k]=-15-rand()%7;
#ifdef ICON_KABOOM_EXTRA
                for (ll=0; ll<2; ll++) {
                    ptx[ll][k] = px[k];
                    pty[ll][k] = py[k];
                }
#endif
                k++;
            } else {
                ax[k]=-1;
            }
        }
    }

    XUnmapWindow(dpy, win);

    j=k;
    while (k>0) {
        XEvent foo;

        if (XCheckTypedEvent(dpy, ButtonPress, &foo)) {
            XPutBackEvent(dpy, &foo);
            XClearWindow(dpy, scr->root_win);
            break;
        }

        for (i=0; i<j ; i++) {
            if (ax[i]>=0) {
                int _px = px[i]>>KAB_PRECISION;
#ifdef ICON_KABOOM_EXTRA
                XClearArea(dpy, scr->root_win, ptx[1][i], pty[1][i],
                           ICON_KABOOM_PIECE_SIZE, ICON_KABOOM_PIECE_SIZE,
                           False);

                ptx[1][i] = ptx[0][i];
                pty[1][i] = pty[0][i];
                ptx[0][i] = _px;
                pty[0][i] = py[i];
#else
                XClearArea(dpy, scr->root_win, _px, py[i],
                           ICON_KABOOM_PIECE_SIZE, ICON_KABOOM_PIECE_SIZE,
                           False);
#endif
                px[i]+=pvx[i];
                py[i]+=pvy[i];
                _px = px[i]>>KAB_PRECISION;
                pvy[i]++;
                if (_px<-wPreferences.icon_size || _px>sw || py[i]>=sh) {
#ifdef ICON_KABOOM_EXTRA
                    if (py[i]>sh && _px<sw && _px>0) {
                        pvy[i] = -(pvy[i]/2);
                        if (abs(pvy[i]) > 3) {
                            py[i] = sh-ICON_KABOOM_PIECE_SIZE;
                            XCopyArea(dpy, tmp, scr->root_win, scr->copy_gc,
                                      ax[i]*ICON_KABOOM_PIECE_SIZE,
                                      ay[i]*ICON_KABOOM_PIECE_SIZE,
                                      ICON_KABOOM_PIECE_SIZE,
                                      ICON_KABOOM_PIECE_SIZE,
                                      _px, py[i]);
                        } else {
                            ax[i] = -1;
                        }
                    } else {
                        ax[i] = -1;
                    }
                    if (ax[i]<0) {
                        for (ll=0; ll<2; ll++)
                            XClearArea(dpy, scr->root_win, ptx[ll][i], pty[ll][i],
                                       ICON_KABOOM_PIECE_SIZE,
                                       ICON_KABOOM_PIECE_SIZE, False);
                        k--;
                    }
#else /* !ICON_KABOOM_EXTRA */
                    ax[i]=-1;
                    k--;
#endif /* !ICON_KABOOM_EXTRA */
                } else {
                    XCopyArea(dpy, tmp, scr->root_win, scr->copy_gc,
                              ax[i]*ICON_KABOOM_PIECE_SIZE, ay[i]*ICON_KABOOM_PIECE_SIZE,
                              ICON_KABOOM_PIECE_SIZE, ICON_KABOOM_PIECE_SIZE,
                              _px, py[i]);
                }
            }
        }

        XFlush(dpy);
#ifdef SPEAKER_SOUND
        play(dpy, 100+rand()%250, 12);
#else
# if (MINIATURIZE_ANIMATION_DELAY_Z > 0)
        wusleep(MINIATURIZE_ANIMATION_DELAY_Z*2);
# endif
#endif
    }

    XFreePixmap(dpy, tmp);
}
#endif /* NORMAL_ICON_KABOOM */


Pixmap
MakeGhostDock(WDock *dock, int sx, int dx, int y)
{
    WScreen *scr = dock->screen_ptr;
    XImage *img;
    RImage *back, *dock_image;
    Pixmap pixmap;
    int i, virtual_tiles, h, j, n;
    unsigned long red_mask, green_mask, blue_mask;

    virtual_tiles = 0;
    for (i=0; i<dock->max_icons; i++) {
        if (dock->icon_array[i]!=NULL &&
            dock->icon_array[i]->yindex > virtual_tiles)
            virtual_tiles = dock->icon_array[i]->yindex;
    }
    virtual_tiles++;
    h = virtual_tiles * wPreferences.icon_size;
    h = (y + h > scr->scr_height) ? scr->scr_height-y : h;
    virtual_tiles = h / wPreferences.icon_size; /* The visible ones */
    if (h % wPreferences.icon_size)
        virtual_tiles++;  /* There is one partially visible tile at end */

    img=XGetImage(dpy, scr->root_win, dx, y, wPreferences.icon_size, h,
                  AllPlanes, ZPixmap);
    if (!img)
        return None;

    red_mask = img->red_mask;
    green_mask = img->green_mask;
    blue_mask = img->blue_mask;

    back = RCreateImageFromXImage(scr->rcontext, img, NULL);
    XDestroyImage(img);
    if (!back) {
        return None;
    }

    for (i=0;i<dock->max_icons;i++) {
        if (dock->icon_array[i]!=NULL &&
            dock->icon_array[i]->yindex < virtual_tiles) {
            Pixmap which;
            j = dock->icon_array[i]->yindex * wPreferences.icon_size;
            n = (h - j < wPreferences.icon_size) ? h - j :
                wPreferences.icon_size;
            if (dock->icon_array[i]->icon->pixmap)
                which = dock->icon_array[i]->icon->pixmap;
            else
                which = dock->icon_array[i]->icon->core->window;

            img=XGetImage(dpy, which, 0, 0, wPreferences.icon_size, n,
                          AllPlanes, ZPixmap);

            if (!img){
                RReleaseImage(back);
                return None;
            }
            img->red_mask = red_mask;
            img->green_mask = green_mask;
            img->blue_mask = blue_mask;

            dock_image = RCreateImageFromXImage(scr->rcontext, img, NULL);
            XDestroyImage(img);
            if (!dock_image) {
                RReleaseImage(back);
                return None;
            }
            RCombineAreaWithOpaqueness(back, dock_image, 0, 0,
                                       wPreferences.icon_size, n,
                                       0, j, 30 * 256 / 100);
            RReleaseImage(dock_image);
        }
    }


    RConvertImage(scr->rcontext, back, &pixmap);

    RReleaseImage(back);

    return pixmap;
}


Pixmap
MakeGhostIcon(WScreen *scr, Drawable drawable)
{
    RImage *back;
    RColor color;
    Pixmap pixmap;


    if (!drawable)
        return None;

    back = RCreateImageFromDrawable(scr->rcontext, drawable, None);
    if (!back)
        return None;

    color.red = 0xff;
    color.green = 0xff;
    color.blue = 0xff;
    color.alpha = 200;

    RClearImage(back, &color);
    RConvertImage(scr->rcontext, back, &pixmap);

    RReleaseImage(back);

    return pixmap;
}



#ifdef WINDOW_BIRTH_ZOOM
void
DoWindowBirth(WWindow *wwin)
{
    int width = wwin->frame->core->width;
    int height = wwin->frame->core->height;
    int w = WMIN(width, 20);
    int h = WMIN(height, 20);
    int x, y;
    int dw, dh;
    int i;
    time_t time0 = time(NULL);

    dw = (width-w)/WINDOW_BIRTH_STEPS;
    dh = (height-h)/WINDOW_BIRTH_STEPS;

    x = wwin->frame_x + (width-w)/2;
    y = wwin->frame_y + (height-h)/2;

    XMoveResizeWindow(dpy, wwin->frame->core->window, x, y, w, h);

    XMapWindow(dpy, wwin->frame->core->window);

    XFlush(dpy);
    for (i=0; i<WINDOW_BIRTH_STEPS; i++) {
        x -= dw/2 + dw%2;
        y -= dh/2 + dh%2;
        w += dw;
        h += dh;
        XMoveResizeWindow(dpy, wwin->frame->core->window, x, y, w, h);
        XFlush(dpy);
        /* a timeout */
        if (time(NULL)-time0 > MAX_ANIMATION_TIME)
            break;
    }

    XMoveResizeWindow(dpy, wwin->frame->core->window,
                      wwin->frame_x, wwin->frame_y, width, height);
    XFlush(dpy);
}
#else
#ifdef WINDOW_BIRTH_ZOOM2
extern void animateResize();

void DoWindowBirth(WWindow *wwin)
{
    /* dummy stub */

    int center_x, center_y;
    int width = wwin->frame->core->width;
    int height = wwin->frame->core->height;
    int w = WMIN(width, 20);
    int h = WMIN(height, 20);
    WScreen *scr = wwin->screen_ptr;

    center_x = wwin->frame_x + (width - w) / 2;
    center_y = wwin->frame_y + (height - h) / 2;

    animateResize(scr, center_x, center_y, 1, 1,
                  wwin->frame_x , wwin->frame_y, width, height,
                  0);
}
#else
void
DoWindowBirth(WWindow *wwin)
{
    /* dummy stub */
}
#endif
#endif






#ifdef SILLYNESS
static WMPixmap *data[12];

static Bool
loadData(WScreen *scr)
{
    FILE *f;
    int i;
    RImage *image;
    Pixmap d[12];

    f = fopen(PKGDATADIR"/xtree.dat", "rb");
    if (!f)
        return False;

    image = RCreateImage(50, 50, False);
    if (!image) {
        fclose(f);
        return False;
    }

    for (i = 0; i < 12; i++) {
        if (fread(image->data, 50*50*3, 1, f)!=1) {
            goto error;
        }
        if (!RConvertImage(scr->rcontext, image, &(d[i]))) {
            goto error;
        }
    }
    RReleaseImage(image);

    fclose(f);

    for (i=0; i<12; i++) {
        data[i] = WMCreatePixmapFromXPixmaps(scr->wmscreen, d[i], None, 50, 50,
                                             scr->w_depth);
    }

    return True;

error:
    RReleaseImage(image);

    fclose(f);

    while (--i > 0) {
        XFreePixmap(dpy, d[i]);
    }

    return False;
}


WMPixmap*
DoXThing(WWindow *wwin)
{
    static int order = 0;

    order++;

    return data[order % 12];
}


Bool
InitXThing(WScreen *scr)
{
    time_t t;
    struct tm *l;
    static int i = 0;

    if (i)
        return True;

    t = time(NULL);
    l = localtime(&t);
    if ((l->tm_mon!=11||l->tm_mday<24||l->tm_mday>26)) {
        return False;
    }

    if (!loadData(scr))
        return False;

    i = 1;

    return True;
}

#endif /* SILLYNESS */


#ifdef GHOST_WINDOW_MOVE

typedef struct {
    WScreen *scr;

    int width, height;

    int iniX, iniY;
    int boxX, boxY;

    Window window;

    RXImage *winImage;

    RXImage *backImage;

    /* the combined image */
    RXImage *image;
    Pixmap pixmap;

} _GhostWindowData;



_GhostWindowData*
InitGhostWindowMove(WWindow *wwin)
{
    _GhostWindowData *gdata;
    WScreen *scr = wwin->screen_ptr;
    unsigned short *ptr;
    unsigned short mask;
    int i;

    gdata = wmalloc(sizeof(_GhostWindowData));

    gdata->width = wwin->frame->core->width;
    gdata->height = wwin->frame->core->height;

    gdata->iniX = wwin->frame_x;
    gdata->iniY = wwin->frame_y;

    gdata->boxX = wwin->frame_x;
    gdata->boxY = wwin->frame_y;

    gdata->window =
        XCreateSimpleWindow(dpy, scr->root_win, wwin->frame_x, wwin->frame_y,
                            gdata->width, gdata->height, 0, 0, 0);

    gdata->winImage = RGetXImage(scr->rcontext, wwin->frame->core->window,
                                 0, 0, gdata->width, gdata->height);

    gdata->backImage = RCreateXImage(scr->rcontext, scr->w_depth,
                                     gdata->width, gdata->height);

    memcpy(gdata->backImage->image->data, gdata->winImage->image->data,
           gdata->winImage->image->bytes_per_line * gdata->height);

    gdata->image = RCreateXImage(scr->rcontext, scr->w_depth,
                                 gdata->width, gdata->height);

    ptr = (unsigned short*)gdata->winImage->image->data;

    mask = 0x7b00|0x3d0|0x1e;

    for (i = 0;
         i < gdata->winImage->image->bytes_per_line * gdata->height;
         i++, ptr++) {

        *ptr &= mask;
    }

    return gdata;
}


static void
mergeGhostWindow(_GhostWindowData *gdata)
{
    register unsigned short *ptrw, *ptrb, *ptr;
    int count;
    int i;

    ptr = (unsigned short*)gdata->image->image->data;
    ptrw = (unsigned short*)gdata->winImage->image->data;
    ptrb = (unsigned short*)gdata->backImage->image->data;

    count = gdata->winImage->image->bytes_per_line * gdata->height;

    while (count--) {
        *ptr = (*ptrw + *ptrb) >> 1;

        ptr++;
        ptrw++;
        ptrb++;
    }
}


void
UpdateGhostWindowMove(void *data, int x, int y)
{
    _GhostWindowData *gdata = (_GhostWindowData*)data;
    WScreen *scr = gdata->scr;

    /* no intersection of new background with current */
    if (x + gdata->width <= gdata->boxX
        || x >= gdata->boxX + gdata->width
        || y + gdata->height <= gdata->boxY
        || y >= gdata->boxY + gdata->height) {
        int i;

        RDestroyXImage(gdata->backImage);

        gdata->backImage = RGetXImage(scr->rcontext, scr->root_win, x, y,
                                      gdata->width, gdata->height);

        ptr = (unsigned short*)gdata->backImage->image->data;

        mask = 0x7b00|0x3d0|0x1e;

        for (i = 0;
             i < gdata->winImage->image->bytes_per_line * gdata->height;
             i++, ptr++) {

            *ptr &= mask;
        }
    } else {
        int hx, hw, hy, hh;
        int vx, vw, vy, vh;
        int i, j;
        unsigned char *backP = gdata->backImage->image->data;
        unsigned char *winP = gdata->winImage->image->data;
        int backLineLen = gdata->backImage->image->bytes_per_line;
        int winLineLen = gdata->winImage->image->bytes_per_line;

        /* 1st move the area of the current backImage that overlaps
         * the new backImage to it's new position */

        if (x < gdata->boxX) {
            vx = x + gdata->width;
            vw = gdata->width - vx;
        } else if (x > gdata->boxX) {
            vw = gdata->boxX + gdata->width - x;
            vx = gdata->boxX - vw;
        } else {
            vx = 0;
            vw = gdata->width;
        }

        if (y < gdata->boxY) {
            vy = y + gdata->height;
            vh = gdata->height - vy;
        } else if (y > gdata->boxY) {
            vh = gdata->boxY + gdata->height - y;
            vy = gdata->boxY - vh;
        } else {
            vy = 0;
            vh = gdata->height;
        }

        if (y < gdata->boxY) {
            int dy = vy - gdata->boxY;

            if (x < gdata->boxX) {
                for (i = vh - 1; i >= 0; i--) {
                    memmove(&backP[(i + dy) * backLineLen + 2 * vx],
                            &backP[i * backLineLen], 2 * vw);
                }
            } else /* if (x > gdata->boxX) */ {
                for (i = vh - 1; i >= 0; i--) {
                    memmove(&backP[(i + dy) * backLineLen],
                            &backP[i * backLineLen + 2 * vx], 2 * vw);
                }
            }
        } else /*if (y > gdata->boxY) */ {
            int dy = gdata->boxY - vy;

            if (x < gdata->boxX) {
                for (i = 0; i < vh - 1; i++) {
                    memmove(&backP[i * backLineLen + 2 * vx],
                            &backP[(i + dy) * backLineLen], 2 * vw);
                }
            } else /*if (x > gdata->boxX) */ {
                for (i = 0; i < vh - 1; i++) {
                    memmove(&backP[i * backLineLen],
                            &backP[(i + dy) * backLineLen + 2 * vx], 2 * vw);
                }
            }
        }

        /* 2nd grab the background image from the screen and copy to the
         * buffer. also maskout the lsb of rgb in each pixel of grabbed data */

        if (y < gdata->boxY) {
            vy = y;
            vh = gdata->boxY - vy;

            hy = y + vh;
            hh = gdata->height - vh;
        } else if (y > gdata->boxY) {
            vy = gdata->boxY + gdata->height;
            vh = vy - (y + gdata->height);

            hy = y;
            hh = y - gdata->boxY;
        } else {
            vy = vh = 0;

            hy = y;
            hh = gdata->height;
        }

        if (x < gdata->boxX) {
            hx = x;
            hw = gdata->boxX - hx;
        } else if (x > gdata->boxX) {
            hx = gdata->boxX + gdata->width;
            hw = hx - (x + gdata->width);
        } else {
            hx = hw = 0;

            vx = x;
            vw = gdata->width;
        }

        /* 1st the top/bottom part */



        /* 2nd the left/right part */
    }

    mergeGhostWindow(gdata);
}


#endif /* GHOST_WINDOW_MOVE */

