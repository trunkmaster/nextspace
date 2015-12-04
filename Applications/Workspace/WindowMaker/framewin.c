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

#include <stdlib.h>
#include <string.h>

#include <wraster/wraster.h>

#include "WindowMaker.h"
#include "GNUstep.h"
#include "texture.h"
#include "screen.h"
#include "wcore.h"
#include "framewin.h"
#include "stacking.h"
#include "funcs.h"

#define DBLCLICK_TIME wPreferences.dblclick_time

extern WPreferences wPreferences;

static void handleExpose(WObjDescriptor *desc, XEvent *event);
static void handleButtonExpose(WObjDescriptor *desc, XEvent *event);

static void buttonMouseDown(WObjDescriptor *desc, XEvent *event);
static void titlebarMouseDown(WObjDescriptor *desc, XEvent *event);
static void resizebarMouseDown(WObjDescriptor *desc, XEvent *event);

static void checkTitleSize(WFrameWindow *fwin);


static void paintButton(WCoreWindow *button, WTexture *texture,
                        unsigned long color,  WPixmap *image, int pushed);

static void updateTitlebar(WFrameWindow *fwin);


WFrameWindow*
wFrameWindowCreate(WScreen *scr, int wlevel, int x, int y,
                   int width, int height, int *clearance, int flags,
                   WTexture **title_texture, WTexture **resize_texture,
                   WMColor **color, WMFont **font)
{
    WFrameWindow *fwin;

    fwin = wmalloc(sizeof(WFrameWindow));
    memset(fwin, 0, sizeof(WFrameWindow));

    fwin->screen_ptr = scr;

    fwin->flags.single_texture = (flags & WFF_SINGLE_STATE) ? 1 : 0;

    fwin->title_texture = title_texture;
    fwin->resizebar_texture = resize_texture;
    fwin->title_color = color;
    fwin->title_clearance = clearance;
    fwin->font = font;

    fwin->core = wCoreCreateTopLevel(scr, x, y, width, height,
                                     (flags & WFF_BORDER)
                                     ? FRAME_BORDER_WIDTH : 0);
    if (wPreferences.use_saveunders) {
        unsigned long vmask;
        XSetWindowAttributes attribs;

        vmask = CWSaveUnder;
        attribs.save_under = True;
        XChangeWindowAttributes(dpy, fwin->core->window, vmask, &attribs);
    }

    /* setup stacking information */
    fwin->core->stacking = wmalloc(sizeof(WStacking));
    fwin->core->stacking->above = NULL;
    fwin->core->stacking->under = NULL;
    fwin->core->stacking->child_of = NULL;
    fwin->core->stacking->window_level = wlevel;

    AddToStackList(fwin->core);

    wFrameWindowUpdateBorders(fwin, flags);

    return fwin;
}



void
wFrameWindowUpdateBorders(WFrameWindow *fwin, int flags)
{
    int theight;
    int bsize;
    int width, height;
    int i;
    WScreen *scr = fwin->screen_ptr;

    width = fwin->core->width;
    if (flags & WFF_IS_SHADED)
        height = -1;
    else
        height = fwin->core->height - fwin->top_width - fwin->bottom_width;

    if (flags & WFF_TITLEBAR)
        theight = WMFontHeight(*fwin->font) + (*fwin->title_clearance + TITLEBAR_EXTEND_SPACE) * 2;
    else
        theight = 0;

    if (wPreferences.new_style) {
        bsize = theight;
    } else {
        bsize = theight - 7;
    }

    if (fwin->titlebar) {
        /* if we had a titlebar and is requesting for one,
         * check if the size has changed and resize it */
        if (flags & WFF_TITLEBAR) {
            fwin->top_width = theight;

            fwin->flags.need_texture_remake = 1;

            if (wPreferences.new_style) {
                if (fwin->left_button) {
                    wCoreConfigure(fwin->left_button, 0, 0, bsize, bsize);
                }

                if (fwin->right_button) {
                    wCoreConfigure(fwin->right_button, width-bsize+1,
                                   0, bsize, bsize);
                }
            } else { /* !new_style */
                if (fwin->left_button) {
                    wCoreConfigure(fwin->left_button, 3, (theight-bsize)/2,
                                   bsize, bsize);
                }

                if (fwin->right_button) {
                    wCoreConfigure(fwin->right_button, width-bsize-3,
                                   (theight-bsize)/2, bsize, bsize);
                }
            }
            updateTitlebar(fwin);
        } else {
            /* we had a titlebar, but now we don't need it anymore */
            for (i=0; i < (fwin->flags.single_texture ? 1 : 3); i++) {
                FREE_PIXMAP(fwin->title_back[i]);
                if (wPreferences.new_style) {
                    FREE_PIXMAP(fwin->lbutton_back[i]);
                    FREE_PIXMAP(fwin->rbutton_back[i]);
                }
            }
            if (fwin->left_button)
                wCoreDestroy(fwin->left_button);
            fwin->left_button = NULL;

            if (fwin->right_button)
                wCoreDestroy(fwin->right_button);
            fwin->right_button = NULL;

            wCoreDestroy(fwin->titlebar);
            fwin->titlebar = NULL;

            fwin->top_width = 0;
        }
    } else {
        /* if we didn't have a titlebar and are being requested for
         * one, create it */
        if (flags & WFF_TITLEBAR) {
            fwin->top_width = theight;

            fwin->flags.titlebar = 1;
            fwin->titlebar = wCoreCreate(fwin->core, 0, 0, width+1, theight);

            if (flags & WFF_LEFT_BUTTON) {
                fwin->flags.left_button = 1;
                if (wPreferences.new_style) {
                    fwin->left_button = wCoreCreate(fwin->core, 0, 0,
                                                    bsize, bsize);
                    if (width < theight*4) {
                        fwin->flags.lbutton_dont_fit = 1;
                    } else {
                        XMapRaised(dpy, fwin->left_button->window);
                    }
                } else {
                    fwin->left_button =
                        wCoreCreate(fwin->titlebar, 3, (theight-bsize)/2,
                                    bsize, bsize);

                    XSetWindowBackground(dpy, fwin->left_button->window,
                                         scr->widget_texture->normal.pixel);

                    if (width < theight*3) {
                        fwin->flags.lbutton_dont_fit = 1;
                    } else {
                        XMapRaised(dpy, fwin->left_button->window);
                    }
                }
            }

            if (flags & WFF_RIGHT_BUTTON) {
                fwin->flags.right_button = 1;
                if (wPreferences.new_style) {
                    fwin->right_button =
                        wCoreCreate(fwin->core, width-bsize+1, 0,
                                    bsize, bsize);
                } else {
                    fwin->right_button =
                        wCoreCreate(fwin->titlebar, width-bsize-3,
                                    (theight-bsize)/2, bsize, bsize);
                    XSetWindowBackground(dpy, fwin->right_button->window,
                                         scr->widget_texture->normal.pixel);
                }

                if (width < theight*2) {
                    fwin->flags.rbutton_dont_fit = 1;
                } else {
                    XMapRaised(dpy, fwin->right_button->window);
                }
            }

            if (wPreferences.new_style)
                updateTitlebar(fwin);

            XMapRaised(dpy, fwin->titlebar->window);

            fwin->flags.need_texture_remake = 1;
        }
    }
    checkTitleSize(fwin);

    if (flags & WFF_RESIZEBAR) {
        fwin->bottom_width = RESIZEBAR_HEIGHT;

        if (!fwin->resizebar) {
            fwin->flags.resizebar = 1;
            fwin->resizebar = wCoreCreate(fwin->core, 0,
                                          height + fwin->top_width,
                                          width, RESIZEBAR_HEIGHT);
            fwin->resizebar_corner_width = RESIZEBAR_CORNER_WIDTH;
            if (width < RESIZEBAR_CORNER_WIDTH*2 + RESIZEBAR_MIN_WIDTH) {
                fwin->resizebar_corner_width = (width - RESIZEBAR_MIN_WIDTH)/2;
                if (fwin->resizebar_corner_width < 0)
                    fwin->resizebar_corner_width = 0;
            }

            XMapWindow(dpy, fwin->resizebar->window);
            XLowerWindow(dpy, fwin->resizebar->window);

            fwin->flags.need_texture_remake = 1;
        } else {
            if (height+fwin->top_width+fwin->bottom_width != fwin->core->height) {
                wCoreConfigure(fwin->resizebar, 0, height + fwin->top_width,
                               width, RESIZEBAR_HEIGHT);
            }
        }
    } else {
        fwin->bottom_width = 0;

        if (fwin->resizebar) {
            fwin->bottom_width = 0;
            wCoreDestroy(fwin->resizebar);
            fwin->resizebar = NULL;
        }
    }

    if (height + fwin->top_width + fwin->bottom_width != fwin->core->height
        && !(flags & WFF_IS_SHADED)) {
        wFrameWindowResize(fwin, width,
                           height + fwin->top_width + fwin->bottom_width);
    }


    if (flags & WFF_BORDER) {
        XSetWindowBorderWidth(dpy, fwin->core->window, FRAME_BORDER_WIDTH);
    } else {
        XSetWindowBorderWidth(dpy, fwin->core->window, 0);
    }

    /* setup object descriptors */

    if (fwin->titlebar) {
        fwin->titlebar->descriptor.handle_expose = handleExpose;
        fwin->titlebar->descriptor.parent = fwin;
        fwin->titlebar->descriptor.parent_type = WCLASS_FRAME;
        fwin->titlebar->descriptor.handle_mousedown = titlebarMouseDown;
    }

    if (fwin->resizebar) {
        fwin->resizebar->descriptor.handle_expose = handleExpose;
        fwin->resizebar->descriptor.parent = fwin;
        fwin->resizebar->descriptor.parent_type = WCLASS_FRAME;
        fwin->resizebar->descriptor.handle_mousedown = resizebarMouseDown;
    }

    if (fwin->left_button) {
        fwin->left_button->descriptor.handle_expose = handleButtonExpose;
        fwin->left_button->descriptor.parent = fwin;
        fwin->left_button->descriptor.parent_type = WCLASS_FRAME;
        fwin->left_button->descriptor.handle_mousedown = buttonMouseDown;
    }

    if (fwin->right_button) {
        fwin->right_button->descriptor.parent = fwin;
        fwin->right_button->descriptor.parent_type = WCLASS_FRAME;
        fwin->right_button->descriptor.handle_expose = handleButtonExpose;
        fwin->right_button->descriptor.handle_mousedown = buttonMouseDown;
    }

    checkTitleSize(fwin);
}



void
wFrameWindowDestroy(WFrameWindow *fwin)
{
    int i;

    if (fwin->left_button)
        wCoreDestroy(fwin->left_button);

    if (fwin->right_button)
        wCoreDestroy(fwin->right_button);

    if (fwin->resizebar)
        wCoreDestroy(fwin->resizebar);

    if (fwin->titlebar)
        wCoreDestroy(fwin->titlebar);

    RemoveFromStackList(fwin->core);

    wCoreDestroy(fwin->core);

    if (fwin->title)
        wfree(fwin->title);

    for (i=0; i < (fwin->flags.single_texture ? 1 : 3); i++) {
        FREE_PIXMAP(fwin->title_back[i]);
        if (wPreferences.new_style) {
            FREE_PIXMAP(fwin->lbutton_back[i]);
            FREE_PIXMAP(fwin->rbutton_back[i]);
        }
    }

    wfree(fwin);
}


void
wFrameWindowChangeState(WFrameWindow *fwin, int state)
{
    if (fwin->flags.state==state)
        return;

    fwin->flags.state = state;
    fwin->flags.need_texture_change = 1;

    wFrameWindowPaint(fwin);
}


static void
updateTitlebar(WFrameWindow *fwin)
{
    int x, w;
    int theight;

    theight = WMFontHeight(*fwin->font) + (*fwin->title_clearance + TITLEBAR_EXTEND_SPACE) * 2;

    x = 0;
    w = fwin->core->width + 1;

    if (wPreferences.new_style) {
        if (fwin->flags.hide_left_button || !fwin->left_button
            || fwin->flags.lbutton_dont_fit) {
            x = 0;
        } else {
            x = fwin->left_button->width;
            w -= fwin->left_button->width;
        }
    }

    if (wPreferences.new_style) {
        if (!fwin->flags.hide_right_button && fwin->right_button
            && !fwin->flags.rbutton_dont_fit) {
            w -= fwin->right_button->width;
        }
    }

    if (wPreferences.new_style || fwin->titlebar->width!=w)
        fwin->flags.need_texture_remake = 1;

    wCoreConfigure(fwin->titlebar, x, 0, w, theight);
}


void
wFrameWindowHideButton(WFrameWindow *fwin, int flags)
{
    if ((flags & WFF_RIGHT_BUTTON) && fwin->right_button) {
        XUnmapWindow(dpy, fwin->right_button->window);
        fwin->flags.hide_right_button = 1;
    }

    if ((flags & WFF_LEFT_BUTTON) && fwin->left_button) {
        XUnmapWindow(dpy, fwin->left_button->window);
        fwin->flags.hide_left_button = 1;
    }

    if (fwin->titlebar) {
        if (wPreferences.new_style) {
            updateTitlebar(fwin);
        } else {
            XClearWindow(dpy, fwin->titlebar->window);
            wFrameWindowPaint(fwin);
        }
        checkTitleSize(fwin);
    }
}


void
wFrameWindowShowButton(WFrameWindow *fwin, int flags)
{
    if ((flags & WFF_RIGHT_BUTTON) && fwin->right_button
        && fwin->flags.hide_right_button) {

        if (!fwin->flags.rbutton_dont_fit)
            XMapWindow(dpy, fwin->right_button->window);

        fwin->flags.hide_right_button = 0;
    }

    if ((flags & WFF_LEFT_BUTTON) && fwin->left_button
        && fwin->flags.hide_left_button) {

        if (!fwin->flags.lbutton_dont_fit)
            XMapWindow(dpy, fwin->left_button->window);

        fwin->flags.hide_left_button = 0;
    }


    if (fwin->titlebar) {
        if (wPreferences.new_style) {
            updateTitlebar(fwin);
        } else {
            XClearWindow(dpy, fwin->titlebar->window);
            wFrameWindowPaint(fwin);
        }
        checkTitleSize(fwin);
    }
}


static void
renderTexture(WScreen *scr, WTexture *texture, int width, int height,
              int bwidth, int bheight, int left, int right,
              Pixmap *title, Pixmap *lbutton, Pixmap *rbutton)
{
    RImage *img;
    RImage *limg, *rimg, *mimg;
    int x, w;

    *title = None;
    *lbutton = None;
    *rbutton = None;

    img = wTextureRenderImage(texture, width, height, WREL_FLAT);
    if (!img) {
        wwarning(_("could not render texture: %s"), RMessageForError(RErrorCode));
        return;
    }

    if (wPreferences.new_style) {
        if (left) {
            limg = RGetSubImage(img, 0, 0, bwidth, bheight);
        } else
            limg = NULL;

        x = 0;
        w = img->width;

        if (limg) {
            RBevelImage(limg, RBEV_RAISED2);
            if (!RConvertImage(scr->rcontext, limg, lbutton)) {
                wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));
            }
            x += limg->width;
            w -= limg->width;
            RReleaseImage(limg);
        }

        if (right) {
            rimg = RGetSubImage(img, width - bwidth, 0,	bwidth, bheight);
        } else
            rimg = NULL;

        if (rimg) {
            RBevelImage(rimg, RBEV_RAISED2);
            if (!RConvertImage(scr->rcontext, rimg, rbutton)) {
                wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));
            }
            w -= rimg->width;
            RReleaseImage(rimg);
        }

        if (w!=width) {
            mimg = RGetSubImage(img, x, 0, w, img->height);
            RBevelImage(mimg, RBEV_RAISED2);

            if (!RConvertImage(scr->rcontext, mimg, title)) {
                wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));
            }
            RReleaseImage(mimg);
        } else {
            RBevelImage(img, RBEV_RAISED2);

            if (!RConvertImage(scr->rcontext, img, title)) {
                wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));
            }
        }
    } else {
        RBevelImage(img, RBEV_RAISED2);

        if (!RConvertImage(scr->rcontext, img, title)) {
            wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));
        }
    }

    RReleaseImage(img);
}


static void
renderResizebarTexture(WScreen *scr, WTexture *texture, int width, int height,
                       int cwidth, Pixmap *pmap)
{
    RImage *img;
    RColor light;
    RColor dark;

    *pmap = None;

    img = wTextureRenderImage(texture, width, height, WREL_FLAT);
    if (!img) {
        wwarning(_("could not render texture: %s"),
                 RMessageForError(RErrorCode));
        return;
    }

    light.alpha = 0;
    light.red = light.green = light.blue = 80;

    dark.alpha = 0;
    dark.red = dark.green = dark.blue = 40;

    ROperateLine(img, RSubtractOperation, 0, 0, width-1, 0, &dark);
    ROperateLine(img, RAddOperation, 0, 1, width-1, 1, &light);

    ROperateLine(img, RSubtractOperation, cwidth, 2, cwidth, height-1, &dark);
    ROperateLine(img, RAddOperation, cwidth+1, 2, cwidth+1, height-1, &light);

    if (width > 1)
        ROperateLine(img, RSubtractOperation, width-cwidth-2, 2,
                     width-cwidth-2, height-1, &dark);
    ROperateLine(img, RAddOperation, width-cwidth-1, 2, width-cwidth-1,
                 height-1, &light);

#ifdef SHADOW_RESIZEBAR
    ROperateLine(img, RAddOperation, 0, 1, 0, height-1, &light);
    ROperateLine(img, RSubtractOperation, width-1, 1, width-1, height-1,
                 &dark);
    ROperateLine(img, RSubtractOperation, 0, height-1, width-1, height-1,
                 &dark);
#endif /* SHADOW_RESIZEBAR */


    if (!RConvertImage(scr->rcontext, img, pmap)) {
        wwarning(_("error rendering image: %s"), RMessageForError(RErrorCode));
    }

    RReleaseImage(img);
}



static void
updateTexture(WFrameWindow *fwin)
{
    int i;
    unsigned long pixel;

    i = fwin->flags.state;
    if (fwin->titlebar) {
        if (fwin->title_texture[i]->any.type!=WTEX_SOLID) {
            XSetWindowBackgroundPixmap(dpy, fwin->titlebar->window,
                                       fwin->title_back[i]);
            if (wPreferences.new_style) {
                if (fwin->left_button && fwin->lbutton_back[i])
                    XSetWindowBackgroundPixmap(dpy, fwin->left_button->window,
                                               fwin->lbutton_back[i]);

                if (fwin->right_button && fwin->rbutton_back[i])
                    XSetWindowBackgroundPixmap(dpy, fwin->right_button->window,
                                               fwin->rbutton_back[i]);
            }
        } else {
            pixel = fwin->title_texture[i]->solid.normal.pixel;
            XSetWindowBackground(dpy, fwin->titlebar->window, pixel);
            if (wPreferences.new_style) {
                if (fwin->left_button)
                    XSetWindowBackground(dpy, fwin->left_button->window,
                                         pixel);
                if (fwin->right_button)
                    XSetWindowBackground(dpy, fwin->right_button->window,
                                         pixel);
            }
        }
        XClearWindow(dpy, fwin->titlebar->window);

        if (fwin->left_button) {
            XClearWindow(dpy, fwin->left_button->window);
            handleButtonExpose(&fwin->left_button->descriptor, NULL);
        }
        if (fwin->right_button) {
            XClearWindow(dpy, fwin->right_button->window);
            handleButtonExpose(&fwin->right_button->descriptor, NULL);
        }
    }
}



static void
remakeTexture(WFrameWindow *fwin, int state)
{
    Pixmap pmap, lpmap, rpmap;

    if (fwin->title_texture[state] && fwin->titlebar) {
        FREE_PIXMAP(fwin->title_back[state]);
        if (wPreferences.new_style) {
            FREE_PIXMAP(fwin->lbutton_back[state]);
            FREE_PIXMAP(fwin->rbutton_back[state]);
        }

        if (fwin->title_texture[state]->any.type!=WTEX_SOLID) {
            int left, right;
            int width;

            /* eventually surrounded by if new_style */
            left = fwin->left_button && !fwin->flags.hide_left_button
                && !fwin->flags.lbutton_dont_fit;
            right = fwin->right_button && !fwin->flags.hide_right_button
                && !fwin->flags.rbutton_dont_fit;

            width = fwin->core->width+1;

            renderTexture(fwin->screen_ptr, fwin->title_texture[state],
                          width, fwin->titlebar->height,
                          fwin->titlebar->height, fwin->titlebar->height,
                          left, right, &pmap, &lpmap, &rpmap);

            fwin->title_back[state] = pmap;
            if (wPreferences.new_style) {
                fwin->lbutton_back[state] = lpmap;
                fwin->rbutton_back[state] = rpmap;
            }
        }
    }
    if (fwin->resizebar_texture && fwin->resizebar_texture[0]
        && fwin->resizebar && state == 0) {

        FREE_PIXMAP(fwin->resizebar_back[0]);

        if (fwin->resizebar_texture[0]->any.type!=WTEX_SOLID) {

            renderResizebarTexture(fwin->screen_ptr,
                                   fwin->resizebar_texture[0],
                                   fwin->resizebar->width,
                                   fwin->resizebar->height,
                                   fwin->resizebar_corner_width,
                                   &pmap);

            fwin->resizebar_back[0] = pmap;
        }

        /* this part should be in updateTexture() */
        if (fwin->resizebar_texture[0]->any.type!=WTEX_SOLID) {
            XSetWindowBackgroundPixmap(dpy, fwin->resizebar->window,
                                       fwin->resizebar_back[0]);
        } else {
            XSetWindowBackground(dpy, fwin->resizebar->window,
                                 fwin->resizebar_texture[0]->solid.normal.pixel);
        }
        XClearWindow(dpy, fwin->resizebar->window);
    }
}


void
wFrameWindowPaint(WFrameWindow *fwin)
{
    WScreen *scr = fwin->screen_ptr;
    int state;

    state = fwin->flags.state;

    if (fwin->flags.is_client_window_frame)
        fwin->flags.justification = wPreferences.title_justification;

    if (fwin->flags.need_texture_remake) {
        int i;

        fwin->flags.need_texture_remake = 0;
        fwin->flags.need_texture_change = 0;

        if (fwin->flags.single_texture) {
            remakeTexture(fwin, 0);
            updateTexture(fwin);
        } else {
            /* first render the texture for the current state... */
            remakeTexture(fwin, state);
            /* ... and paint it */
            updateTexture(fwin);

            for (i=0; i < 3; i++) {
                if (i != state) {
                    remakeTexture(fwin, i);
                }
            }
        }
    }

    if (fwin->flags.need_texture_change) {
        fwin->flags.need_texture_change = 0;

        updateTexture(fwin);
    }

    if (fwin->titlebar && !fwin->flags.repaint_only_resizebar
        && fwin->title_texture[state]->any.type==WTEX_SOLID) {
        wDrawBevel(fwin->titlebar->window, fwin->titlebar->width,
                   fwin->titlebar->height,
                   (WTexSolid*)fwin->title_texture[state],
                   WREL_RAISED);
    }

    if (fwin->resizebar	&& !fwin->flags.repaint_only_titlebar
        && fwin->resizebar_texture[0]->any.type == WTEX_SOLID) {
        Window win;
        int w, h;
        int cw;
        GC light_gc, dim_gc;
        WTexSolid *texture = (WTexSolid*)fwin->resizebar_texture[0];

        w = fwin->resizebar->width;
        h = fwin->resizebar->height;
        cw = fwin->resizebar_corner_width;
        light_gc = texture->light_gc;
        dim_gc = texture->dim_gc;
        win = fwin->resizebar->window;

        XDrawLine(dpy, win, dim_gc, 0, 0, w, 0);
        XDrawLine(dpy, win, light_gc, 0, 1, w, 1);

        XDrawLine(dpy, win, dim_gc, cw, 2, cw, h);
        XDrawLine(dpy, win, light_gc, cw+1, 2, cw+1, h);

        XDrawLine(dpy, win, dim_gc, w-cw-2, 2, w-cw-2, h);
        XDrawLine(dpy, win, light_gc, w-cw-1, 2, w-cw-1, h);

#ifdef SHADOW_RESIZEBAR
        XDrawLine(dpy, win, light_gc, 0, 1, 0, h-1);
        XDrawLine(dpy, win, dim_gc, w-1, 2, w-1, h-1);
        XDrawLine(dpy, win, dim_gc, 1, h-1, cw, h-1);
        XDrawLine(dpy, win, dim_gc, cw+2, h-1, w-cw-2, h-1);
        XDrawLine(dpy, win, dim_gc, w-cw, h-1, w-1, h-1);
#endif /* SHADOW_RESIZEBAR */
    }


    if (fwin->titlebar && !fwin->flags.repaint_only_resizebar) {
        int x, y, w, h;
        int lofs = 6, rofs = 6;
        int titlelen;
        int allButtons = 1;


        if (!wPreferences.new_style) {
            if (fwin->left_button && !fwin->flags.hide_left_button
                && !fwin->flags.lbutton_dont_fit)
                lofs += fwin->left_button->width + 3;
            else
                allButtons = 0;

            if (fwin->right_button && !fwin->flags.hide_right_button
                && !fwin->flags.rbutton_dont_fit)
                rofs += fwin->right_button->width + 3;
            else
                allButtons = 0;
        }

        if (fwin->title) {
            Drawable buf;
            char *title;

            title = ShrinkString(*fwin->font, fwin->title,
                                 fwin->titlebar->width - lofs - rofs);
            titlelen = strlen(title);
            w = WMWidthOfString(*fwin->font, title, titlelen);

            switch (fwin->flags.justification) {
            case WTJ_LEFT:
                x = lofs;
                break;

            case WTJ_RIGHT:
                x = fwin->titlebar->width - w - rofs;
                break;

            default:
                if (!allButtons)
                    x = lofs + (fwin->titlebar->width - w - lofs - rofs) / 2;
                else
                    x = (fwin->titlebar->width - w) / 2;
                break;
            }

            y = *fwin->title_clearance + TITLEBAR_EXTEND_SPACE;
            h = WMFontHeight(*fwin->font);

            /* We use a w+2 buffer to have an extra pixel on the left and
             * another one on the right. This is because for some odd reason,
             * sometimes when using AA fonts (when libfreetype2 is compiled
             * with bytecode interpreter turned off), some fonts are drawn
             * starting from x = -1 not from 0 as requested. Observed with
             * capital A letter on the bold 'trebuchet ms' font. -Dan
             */
            buf = XCreatePixmap(dpy, fwin->titlebar->window, w+2, h,
                                scr->w_depth);

            XSetClipMask(dpy, scr->copy_gc, None);

            if (fwin->title_texture[state]->any.type!=WTEX_SOLID) {
                XCopyArea(dpy, fwin->title_back[state], buf, scr->copy_gc,
                          x-1, y, w+2, h, 0, 0);
            } else {
                XSetForeground(dpy, scr->copy_gc,
                               fwin->title_texture[state]->solid.normal.pixel);
                XFillRectangle(dpy, buf, scr->copy_gc, 0, 0, w+2, h);
            }

            /*XDrawRectangle(dpy, buf, WMColorGC(scr->white),1,0,w,h-1);*/
            WMDrawString(scr->wmscreen, buf, fwin->title_color[state],
                         *fwin->font, 1, 0, title, titlelen);

            XCopyArea(dpy, buf, fwin->titlebar->window, scr->copy_gc,
                      0, 0, w+2, h, x-1, y);

            XFreePixmap(dpy, buf);

            wfree(title);
        }

        if (fwin->left_button)
            handleButtonExpose(&fwin->left_button->descriptor, NULL);
        if (fwin->right_button)
            handleButtonExpose(&fwin->right_button->descriptor, NULL);
    }
}


static void
reconfigure(WFrameWindow *fwin, int x, int y, int width, int height,
            Bool dontMove)
{
    int k = (wPreferences.new_style ? 4 : 3);
    int resizedHorizontally = 0;

    if (dontMove)
        XResizeWindow(dpy, fwin->core->window, width, height);
    else
        XMoveResizeWindow(dpy, fwin->core->window, x, y, width, height);

    /*
     if (fwin->core->height != height && fwin->resizebar)
     XMoveWindow(dpy, fwin->resizebar->window, 0,
     height - fwin->resizebar->height);
     */
    if (fwin->core->width != width) {
        fwin->flags.need_texture_remake = 1;
        resizedHorizontally = 1;
    }

    fwin->core->width = width;
    fwin->core->height = height;

    if (fwin->titlebar && resizedHorizontally) {
        /* Check if the titlebar is wide enough to hold the buttons.
         * Temporarily remove them if can't
         */
        if (fwin->left_button) {
            if (width < fwin->top_width*k && !fwin->flags.lbutton_dont_fit) {

                if (!fwin->flags.hide_left_button) {
                    XUnmapWindow(dpy, fwin->left_button->window);
                }
                fwin->flags.lbutton_dont_fit = 1;
            } else if (width >= fwin->top_width*k && fwin->flags.lbutton_dont_fit) {

                if (!fwin->flags.hide_left_button) {
                    XMapWindow(dpy, fwin->left_button->window);
                }
                fwin->flags.lbutton_dont_fit = 0;
            }
        }

        if (fwin->right_button) {
            if (width < fwin->top_width*2 && !fwin->flags.rbutton_dont_fit) {

                if (!fwin->flags.hide_right_button) {
                    XUnmapWindow(dpy, fwin->right_button->window);
                }
                fwin->flags.rbutton_dont_fit = 1;
            } else if (width >= fwin->top_width*2 && fwin->flags.rbutton_dont_fit) {

                if (!fwin->flags.hide_right_button) {
                    XMapWindow(dpy, fwin->right_button->window);
                }
                fwin->flags.rbutton_dont_fit = 0;
            }
        }

        if (wPreferences.new_style) {
            if (fwin->right_button)
                XMoveWindow(dpy, fwin->right_button->window,
                            width - fwin->right_button->width + 1, 0);
        } else {
            if (fwin->right_button)
                XMoveWindow(dpy, fwin->right_button->window,
                            width - fwin->right_button->width - 3,
                            (fwin->titlebar->height - fwin->right_button->height)/2);
        }
        updateTitlebar(fwin);
        checkTitleSize(fwin);
    }

    if (fwin->resizebar) {
        wCoreConfigure(fwin->resizebar, 0,
                       fwin->core->height - fwin->resizebar->height,
                       fwin->core->width, fwin->resizebar->height);

        fwin->resizebar_corner_width = RESIZEBAR_CORNER_WIDTH;
        if (fwin->core->width < RESIZEBAR_CORNER_WIDTH*2 + RESIZEBAR_MIN_WIDTH) {
            fwin->resizebar_corner_width = fwin->core->width/2;
        }
    }
}

void
wFrameWindowConfigure(WFrameWindow *fwin, int x, int y, int width, int height)
{
    reconfigure(fwin, x, y, width, height, False);
}

void
wFrameWindowResize(WFrameWindow *fwin, int width, int height)
{
    reconfigure(fwin, 0, 0, width, height, True);
}



int
wFrameWindowChangeTitle(WFrameWindow *fwin, char *new_title)
{
    /* check if the title is the same as before */
    if (fwin->title) {
        if (new_title && (strcmp(fwin->title, new_title) == 0)) {
            return 0;
        }
    } else {
        if (!new_title)
            return 0;
    }

    if (fwin->title)
        wfree(fwin->title);

    fwin->title = wstrdup(new_title);

    if (fwin->titlebar) {
        XClearWindow(dpy, fwin->titlebar->window);

        wFrameWindowPaint(fwin);
    }
    checkTitleSize(fwin);

    return 1;
}


/*********************************************************************/

static void
handleExpose(WObjDescriptor *desc, XEvent *event)
{
    WFrameWindow *fwin = (WFrameWindow*)desc->parent;


    if (fwin->titlebar && fwin->titlebar->window == event->xexpose.window)
        fwin->flags.repaint_only_titlebar = 1;
    if (fwin->resizebar && fwin->resizebar->window == event->xexpose.window)
        fwin->flags.repaint_only_resizebar = 1;
    wFrameWindowPaint(fwin);
    fwin->flags.repaint_only_titlebar = 0;
    fwin->flags.repaint_only_resizebar = 0;
}


static void
checkTitleSize(WFrameWindow *fwin)
{
    int width;

    if (!fwin->title) {
        fwin->flags.incomplete_title = 0;
        return;
    }

    if (!fwin->titlebar) {
        fwin->flags.incomplete_title = 1;
        return;
    } else {
        width = fwin->titlebar->width - 6 - 6;
    }

    if (!wPreferences.new_style) {
        if (fwin->left_button && !fwin->flags.hide_left_button
            && !fwin->flags.lbutton_dont_fit)
            width -= fwin->left_button->width + 3;

        if (fwin->right_button && !fwin->flags.hide_right_button
            && !fwin->flags.rbutton_dont_fit)
            width -= fwin->right_button->width + 3;
    }
    if (WMWidthOfString(*fwin->font, fwin->title, strlen(fwin->title)) > width) {
        fwin->flags.incomplete_title = 1;
    } else {
        fwin->flags.incomplete_title = 0;
    }
}


static void
paintButton(WCoreWindow *button, WTexture *texture, unsigned long color,
            WPixmap *image, int pushed)
{
    WScreen *scr = button->screen_ptr;
    GC copy_gc = scr->copy_gc;
    int x=0, y=0, d=0;
    int left=0, width=0;

    /* setup stuff according to the state */
    if (pushed) {
        if (image) {
            if (image->width>=image->height*2) {
                /* the image contains 2 pictures: the second is for the
                 * pushed state */
                width = image->width/2;
                left = image->width/2;
            } else {
                width = image->width;
            }
        }
        XSetClipMask(dpy, copy_gc, None);
        XSetForeground(dpy, copy_gc, scr->white_pixel);
        d=1;
        if (wPreferences.new_style) {
            XFillRectangle(dpy, button->window, copy_gc, 0, 0,
                           button->width-1, button->height-1);
            XSetForeground(dpy, copy_gc, scr->black_pixel);
            XDrawRectangle(dpy, button->window, copy_gc, 0, 0,
                           button->width-1, button->height-1);
        } else {
            XFillRectangle(dpy, button->window, copy_gc, 0, 0,
                           button->width, button->height);
            XSetForeground(dpy, copy_gc, scr->black_pixel);
            XDrawRectangle(dpy, button->window, copy_gc, 0, 0,
                           button->width, button->height);
        }
    } else {
        XClearWindow(dpy, button->window);

        if (image) {
            if (image->width>=image->height*2)
                width = image->width/2;
            else
                width = image->width;
        }
        d=0;

        if (wPreferences.new_style) {
            if (texture->any.type==WTEX_SOLID || pushed) {
                wDrawBevel(button->window, button->width, button->height,
                           (WTexSolid*)texture, WREL_RAISED);
            }
        } else {
            wDrawBevel(button->window, button->width, button->height,
                       scr->widget_texture, WREL_RAISED);
        }
    }

    if (image) {
        /* display image */
        XSetClipMask(dpy, copy_gc, image->mask);
        x = (button->width - width)/2 + d;
        y = (button->height - image->height)/2 + d;
        XSetClipOrigin(dpy, copy_gc, x-left, y);
        if (!wPreferences.new_style) {
            XSetForeground(dpy, copy_gc, scr->black_pixel);
            if (!pushed) {
                if (image->depth==1)
                    XCopyPlane(dpy, image->image, button->window, copy_gc,
                               left, 0, width, image->height, x, y, 1);
                else
                    XCopyArea(dpy, image->image, button->window, copy_gc,
                              left, 0, width, image->height, x, y);
            } else {
                XSetForeground(dpy, copy_gc, scr->dark_pixel);
                XFillRectangle(dpy, button->window, copy_gc, 0, 0,
                               button->width, button->height);
            }
        } else {
            if (pushed) {
                XSetForeground(dpy, copy_gc, scr->black_pixel);
            } else {
                XSetForeground(dpy, copy_gc, color);
                XSetBackground(dpy, copy_gc, texture->any.color.pixel);
            }
            XFillRectangle(dpy, button->window, copy_gc, 0, 0,
                           button->width, button->height);
        }
    }
}


static void
handleButtonExpose(WObjDescriptor *desc, XEvent *event)
{
    WFrameWindow *fwin = (WFrameWindow*)desc->parent;
    WCoreWindow *button = (WCoreWindow*)desc->self;

        if (button == fwin->left_button) {
            paintButton(button, fwin->title_texture[fwin->flags.state],
                        WMColorPixel(fwin->title_color[fwin->flags.state]),
                        fwin->lbutton_image, False);
        } else {
            paintButton(button, fwin->title_texture[fwin->flags.state],
                        WMColorPixel(fwin->title_color[fwin->flags.state]),
                        fwin->rbutton_image, False);
        }
}


static void
titlebarMouseDown(WObjDescriptor *desc, XEvent *event)
{
    WFrameWindow *fwin = desc->parent;
    WCoreWindow *titlebar = desc->self;

    if (IsDoubleClick(fwin->core->screen_ptr, event)) {
        if (fwin->on_dblclick_titlebar) {
            (*fwin->on_dblclick_titlebar)(titlebar, fwin->child, event);
        }
    } else {
        if (fwin->on_mousedown_titlebar) {
            (*fwin->on_mousedown_titlebar)(titlebar, fwin->child, event);
        }
    }
}


static void
resizebarMouseDown(WObjDescriptor *desc, XEvent *event)
{
    WFrameWindow *fwin = desc->parent;
    WCoreWindow *resizebar = desc->self;

    if (fwin->on_mousedown_resizebar)
        (*fwin->on_mousedown_resizebar)(resizebar, fwin->child, event);
}


static void
buttonMouseDown(WObjDescriptor *desc, XEvent *event)
{
    WFrameWindow *fwin = desc->parent;
    WCoreWindow *button = desc->self;
    WPixmap *image;
    XEvent ev;
    int done=0, execute=1;
    WTexture *texture;
    unsigned long pixel;
    int clickButton = event->xbutton.button;

    if (IsDoubleClick(fwin->core->screen_ptr, event)) {
        if (button == fwin->right_button && fwin->on_dblclick_right) {
            (*fwin->on_dblclick_right)(button, fwin->child, event);
        }
        return;
    }

    if (button == fwin->left_button) {
        image = fwin->lbutton_image;
    } else {
        image = fwin->rbutton_image;
    }

    pixel = WMColorPixel(fwin->title_color[fwin->flags.state]);
    texture = fwin->title_texture[fwin->flags.state];
    paintButton(button, texture, pixel, image, True);

    while (!done) {
        WMMaskEvent(dpy, LeaveWindowMask|EnterWindowMask|ButtonReleaseMask
                    |ButtonPressMask|ExposureMask, &ev);
        switch (ev.type) {
        case LeaveNotify:
            execute = 0;
            paintButton(button, texture, pixel, image, False);
            break;

        case EnterNotify:
            execute = 1;
            paintButton(button, texture, pixel, image, True);
            break;

        case ButtonPress:
            break;

        case ButtonRelease:
            if (ev.xbutton.button == clickButton)
                done = 1;
            break;

        default:
            WMHandleEvent(&ev);
        }
    }
    paintButton(button, texture, pixel, image, False);

    if (execute) {
        if (button == fwin->left_button) {
            if (fwin->on_click_left)
                (*fwin->on_click_left)(button, fwin->child, &ev);
        } else if (button == fwin->right_button) {
            if (fwin->on_click_right)
                (*fwin->on_click_right)(button, fwin->child, &ev);
        }
    }
}

