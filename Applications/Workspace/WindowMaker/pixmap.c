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

#include <wraster/wraster.h>

#include <stdlib.h>
#include <string.h>
#include "WindowMaker.h"
#include "wcore.h"



/*
 *----------------------------------------------------------------------
 * wPixmapCreateFromXPMData--
 * 	Creates a WPixmap structure and initializes it with the supplied
 * XPM structure data.
 *
 * Returns:
 * 	A WPixmap structure or NULL on failure.
 *
 * Notes:
 * 	DEF_XPM_CLOSENESS specifies the XpmCloseness
 *----------------------------------------------------------------------
 */
WPixmap*
wPixmapCreateFromXPMData(WScreen *scr, char **data)
{
    RImage *image;
    WPixmap *pix;

    image = RGetImageFromXPMData(scr->rcontext, data);
    if (!image)
        return NULL;

    pix = wmalloc(sizeof(WPixmap));
    memset(pix, 0, sizeof(WPixmap));

    RConvertImageMask(scr->rcontext, image, &pix->image, &pix->mask, 128);

    pix->width = image->width;
    pix->height = image->height;
    pix->depth = scr->w_depth;

    RReleaseImage(image);

    return pix;
}


/*
 *----------------------------------------------------------------------
 * wPixmapCreateFromXBMData--
 * 	Creates a WPixmap structure and initializes it with the supplied
 * XBM structure data, size and mask.
 *
 * Returns:
 * 	A WPixmap structure or NULL on failure.
 *
 *----------------------------------------------------------------------
 */
WPixmap*
wPixmapCreateFromXBMData(WScreen *scr, char *data, char *mask,
                         int width, int height, unsigned long fg,
                         unsigned long bg)
{
    WPixmap *pix;

    pix = wmalloc(sizeof(WPixmap));
    memset(pix, 0, sizeof(WPixmap));
    pix->image = XCreatePixmapFromBitmapData(dpy, scr->w_win, data, width,
                                             height, fg, bg, scr->w_depth);
    if (pix->image==None) {
        wfree(pix);
        return NULL;
    }
    if (mask) {
        pix->mask = XCreateBitmapFromData(dpy, scr->w_win, mask, width,
                                          height);
    } else {
        pix->mask = None;
    }
    pix->width = width;
    pix->height = height;
    pix->depth = scr->w_depth;
    return pix;
}


#ifdef unused
WPixmap*
wPixmapCreateFromBitmap(WScreen *scr, Pixmap bitmap, Pixmap mask,
                        unsigned long fg, unsigned long bg)
{
    WPixmap *pix;
    XImage *img, *img2;
    Window foo;
    int bar, x, y;
    Pixmap pixmap;
    unsigned int width, height, baz, d;

    if (!XGetGeometry(dpy, bitmap, &foo, &bar, &bar, &width, &height, &baz,
                      &d) || d!=1) {
        return NULL;
    }
    img = XGetImage(dpy, bitmap, 0, 0, width, height, AllPlanes, XYPixmap);
    if (!img)
        return NULL;

    img2=XCreateImage(dpy, scr->w_visual, scr->w_depth, ZPixmap,
                      0, NULL, width, height, 8, 0);
    if (!img2) {
        XDestroyImage(img);
        return NULL;
    }

    pixmap = XCreatePixmap(dpy, scr->w_win, width, height, scr->w_depth);
    if (pixmap==None) {
        XDestroyImage(img);
        XDestroyImage(img2);
        return NULL;
    }

    img2->data = wmalloc(height * img2->bytes_per_line);

    for (y=0; y<height; y++) {
        for (x=0; x<width; x++) {
            if (XGetPixel(img, x, y)==0) {
                XPutPixel(img2, x, y, bg);
            } else {
                XPutPixel(img2, x, y, fg);
            }
        }
    }
    XSetClipMask(dpy, scr->copy_gc, None);
    XPutImage(dpy, pixmap, scr->copy_gc, img2, 0, 0, 0, 0, width, height);
    XDestroyImage(img);
    XDestroyImage(img2);

    pix = wmalloc(sizeof(WPixmap));
    memset(pix, 0, sizeof(WPixmap));
    pix->image = pixmap;
    pix->mask = mask;
    pix->width = width;
    pix->height = height;
    pix->depth = scr->w_depth;
    return pix;
}
#endif /* unused */

WPixmap*
wPixmapCreate(WScreen *scr, Pixmap image, Pixmap mask)
{
    WPixmap *pix;
    Window foo;
    int bar;
    unsigned int width, height, depth, baz;

    pix = wmalloc(sizeof(WPixmap));
    memset(pix, 0, sizeof(WPixmap));
    pix->image = image;
    pix->mask = mask;
    if (!XGetGeometry(dpy, image, &foo, &bar, &bar, &width, &height, &baz,
                      &depth)) {
        wwarning("XGetGeometry() failed during wPixmapCreate()");
        wfree(pix);
        return NULL;
    }
    pix->width = width;
    pix->height = height;
    pix->depth = depth;
    return pix;
}

#if 0
/*
 *----------------------------------------------------------------------
 * wPixmapLoadXBMFile--
 * 	Creates a WPixmap structure and loads a XBM file into it with
 * an optional mask file. If a mask is not wanted, mask_path should be
 * NULL.
 *
 * Returns:
 * 	A WPixmap structure or NULL on failure.
 *
 * Notes:
 * 	If the mask bitmap is not successfully loaded the operation
 * continues as no mask was supplied.
 *----------------------------------------------------------------------
 */
WPixmap*
wPixmapLoadXBMFile(WScreen *scr, char *path, char *mask_path)
{
    WPixmap *pix;
    int junk;

    if (!path) return NULL;

    pix = wmalloc(sizeof(WPixmap));
    memset(pix, 0, sizeof(WPixmap));

    if (XReadBitmapFile(dpy, scr->w_win, path, (unsigned *)&(pix->width),
                        (unsigned *)&(pix->height),
                        &(pix->image), &junk, &junk)!=BitmapSuccess) {
        wfree(pix);
        return NULL;
    }
    if (mask_path!=NULL) {
        if (XReadBitmapFile(dpy, scr->w_win, path, (unsigned *)&junk,
                            (unsigned *)&junk, &(pix->mask),
                            &junk, &junk) !=BitmapSuccess) {
            wwarning(_("could not load mask bitmap file \"%s\". Won't use mask"),
                     mask_path);
            pix->mask = None;
        }
    } else {
        pix->mask = None;
    }
    pix->depth = 1;
    return pix;
}

#endif

/*
 *----------------------------------------------------------------------
 * wPixmapDestroy--
 * 	Destroys a WPixmap structure and the pixmap/mask it holds.
 *
 * Returns:
 * 	None
 *----------------------------------------------------------------------
 */
void
wPixmapDestroy(WPixmap *pix)
{
    if (!pix->shared) {
        if (pix->mask && !pix->client_owned_mask) {
            XFreePixmap(dpy, pix->mask);
        }

        if (pix->image && !pix->client_owned) {
            XFreePixmap(dpy, pix->image);
        }
    }
    wfree(pix);
}


