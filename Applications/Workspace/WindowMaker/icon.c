/* icon.c - window icon and dock and appicon parent
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
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <wraster/wraster.h>
#include <sys/stat.h>

#include "WindowMaker.h"
#include "wcore.h"
#include "texture.h"
#include "window.h"
#include "icon.h"
#include "actions.h"
#include "funcs.h"
#include "stacking.h"
#include "application.h"
#include "defaults.h"
#include "appicon.h"
#include "wmspec.h"

/**** Global varianebles ****/
extern WPreferences wPreferences;

#define MOD_MASK wPreferences.modifier_mask

extern Cursor wCursor[WCUR_LAST];


static void miniwindowExpose(WObjDescriptor *desc, XEvent *event);
static void miniwindowMouseDown(WObjDescriptor *desc, XEvent *event);
static void miniwindowDblClick(WObjDescriptor *desc, XEvent *event);


/****** Notification Observers ******/

static void
appearanceObserver(void *self, WMNotification *notif)
{
    WIcon *icon = (WIcon*)self;
    int flags = (int)WMGetNotificationClientData(notif);

    if (flags & WTextureSettings) {
        icon->force_paint = 1;
    }
    if (flags & WFontSettings) {
        icon->force_paint = 1;
    }
    /*
     if (flags & WColorSettings) {
     }
     */

    wIconPaint(icon);

    /* so that the appicon expose handlers will paint the appicon specific
     * stuff */
    XClearArea(dpy, icon->core->window, 0, 0, icon->core->width,
               icon->core->height, True);
}


static void
tileObserver(void *self, WMNotification *notif)
{
    WIcon *icon = (WIcon*)self;

    icon->force_paint = 1;
    wIconPaint(icon);

    XClearArea(dpy, icon->core->window, 0, 0, 1, 1, True);
}

/************************************/



INLINE static void
getSize(Drawable d, unsigned int *w, unsigned int *h, unsigned int *dep)
{
    Window rjunk;
    int xjunk, yjunk;
    unsigned int bjunk;

    XGetGeometry(dpy, d, &rjunk, &xjunk, &yjunk, w, h, &bjunk, dep);
}


WIcon*
wIconCreate(WWindow *wwin)
{
    WScreen *scr=wwin->screen_ptr;
    WIcon *icon;
    char *file;
    unsigned long vmask = 0;
    XSetWindowAttributes attribs;

    icon = wmalloc(sizeof(WIcon));
    memset(icon, 0, sizeof(WIcon));
    icon->core = wCoreCreateTopLevel(scr, wwin->icon_x, wwin->icon_y,
                                     wPreferences.icon_size,
                                     wPreferences.icon_size, 0);

    if (wPreferences.use_saveunders) {
        vmask |= CWSaveUnder;
        attribs.save_under = True;
    }
    /* a white border for selecting it */
    vmask |= CWBorderPixel;
    attribs.border_pixel = scr->white_pixel;

    XChangeWindowAttributes(dpy, icon->core->window, vmask, &attribs);


    /* will be overriden if this is an application icon */
    icon->core->descriptor.handle_mousedown = miniwindowMouseDown;
    icon->core->descriptor.handle_expose = miniwindowExpose;
    icon->core->descriptor.parent_type = WCLASS_MINIWINDOW;
    icon->core->descriptor.parent = icon;

    icon->core->stacking = wmalloc(sizeof(WStacking));
    icon->core->stacking->above = NULL;
    icon->core->stacking->under = NULL;
    icon->core->stacking->window_level = NORMAL_ICON_LEVEL;
    icon->core->stacking->child_of = NULL;

    icon->owner = wwin;
    if (wwin->wm_hints && (wwin->wm_hints->flags & IconWindowHint)) {
        if (wwin->client_win == wwin->main_window) {
            WApplication *wapp;
            /* do not let miniwindow steal app-icon's icon window */
            wapp = wApplicationOf(wwin->client_win);
            if (!wapp || wapp->app_icon==NULL)
                icon->icon_win = wwin->wm_hints->icon_window;
        } else {
            icon->icon_win = wwin->wm_hints->icon_window;
        }
    }
#ifdef NO_MINIWINDOW_TITLES
    icon->show_title = 0;
#else
    icon->show_title = 1;
#endif
#ifdef NETWM_HINTS
    if (!icon->image && !WFLAGP(wwin, always_user_icon))
        icon->image = RRetainImage(wwin->net_icon_image);
    if (!icon->image)
#endif
        icon->image = wDefaultGetImage(scr, wwin->wm_instance, wwin->wm_class);

    file = wDefaultGetIconFile(scr, wwin->wm_instance, wwin->wm_class,
                               False);
    if (file) {
        icon->file = wstrdup(file);
    }

    icon->icon_name = wNETWMGetIconName(wwin->client_win);
    if (icon->icon_name)
      wwin->flags.net_has_icon_title= 1;
    else
      wGetIconName(dpy, wwin->client_win, &icon->icon_name);

    icon->tile_type = TILE_NORMAL;

    wIconUpdate(icon);

    XFlush(dpy);

    WMAddNotificationObserver(appearanceObserver, icon,
                              WNIconAppearanceSettingsChanged, icon);
    WMAddNotificationObserver(tileObserver, icon,
                              WNIconTileSettingsChanged, icon);
    return icon;
}


WIcon*
wIconCreateWithIconFile(WScreen *scr, char *iconfile, int tile)
{
    WIcon *icon;
    unsigned long vmask = 0;
    XSetWindowAttributes attribs;

    icon = wmalloc(sizeof(WIcon));
    memset(icon, 0, sizeof(WIcon));
    icon->core = wCoreCreateTopLevel(scr, 0, 0, wPreferences.icon_size,
                                     wPreferences.icon_size, 0);
    if (wPreferences.use_saveunders) {
        vmask = CWSaveUnder;
        attribs.save_under = True;
    }
    /* a white border for selecting it */
    vmask |= CWBorderPixel;
    attribs.border_pixel = scr->white_pixel;

    XChangeWindowAttributes(dpy, icon->core->window, vmask, &attribs);

    /* will be overriden if this is a application icon */
    icon->core->descriptor.handle_mousedown = miniwindowMouseDown;
    icon->core->descriptor.handle_expose = miniwindowExpose;
    icon->core->descriptor.parent_type = WCLASS_MINIWINDOW;
    icon->core->descriptor.parent = icon;

    icon->core->stacking = wmalloc(sizeof(WStacking));
    icon->core->stacking->above = NULL;
    icon->core->stacking->under = NULL;
    icon->core->stacking->window_level = NORMAL_ICON_LEVEL;
    icon->core->stacking->child_of = NULL;

    if (iconfile) {
        icon->image = RLoadImage(scr->rcontext, iconfile, 0);
        if (!icon->image) {
            wwarning(_("error loading image file \"%s\""), iconfile, RMessageForError(RErrorCode));
        }

        icon->image = wIconValidateIconSize(scr, icon->image);

        icon->file = wstrdup(iconfile);
    }

    icon->tile_type = tile;

    wIconUpdate(icon);

    WMAddNotificationObserver(appearanceObserver, icon,
                              WNIconAppearanceSettingsChanged, icon);
    WMAddNotificationObserver(tileObserver, icon,
                              WNIconTileSettingsChanged, icon);

    return icon;
}



void
wIconDestroy(WIcon *icon)
{
    WCoreWindow *core = icon->core;
    WScreen *scr = core->screen_ptr;

    WMRemoveNotificationObserver(icon);

    if (icon->handlerID)
        WMDeleteTimerHandler(icon->handlerID);

    if (icon->icon_win) {
        int x=0, y=0;

        if (icon->owner) {
            x = icon->owner->icon_x;
            y = icon->owner->icon_y;
        }
        XUnmapWindow(dpy, icon->icon_win);
        XReparentWindow(dpy, icon->icon_win, scr->root_win, x, y);
    }
    if (icon->icon_name)
        XFree(icon->icon_name);

    if (icon->pixmap)
        XFreePixmap(dpy, icon->pixmap);

    if (icon->file)
        wfree(icon->file);

    if (icon->image!=NULL)
        RReleaseImage(icon->image);

    wCoreDestroy(icon->core);
    wfree(icon);
}



static void
drawIconTitle(WScreen *scr, Pixmap pixmap, int height)
{
    XFillRectangle(dpy, pixmap, scr->icon_title_texture->normal_gc,
                   0, 0, wPreferences.icon_size, height+1);
    XDrawLine(dpy, pixmap, scr->icon_title_texture->light_gc, 0, 0,
              wPreferences.icon_size, 0);
    XDrawLine(dpy, pixmap, scr->icon_title_texture->light_gc, 0, 0,
              0, height+1);
    XDrawLine(dpy, pixmap, scr->icon_title_texture->dim_gc,
              wPreferences.icon_size-1, 0, wPreferences.icon_size-1, height+1);
}


static Pixmap
makeIcon(WScreen *scr, RImage *icon, int titled, int shadowed, int tileType)
{
    RImage *tile;
    Pixmap pixmap;
    int x, y, sx, sy;
    unsigned w, h;
    int theight = WMFontHeight(scr->icon_title_font);

    if (tileType == TILE_NORMAL)
        tile = RCloneImage(scr->icon_tile);
    else {
        assert(scr->clip_tile);
        tile = RCloneImage(scr->clip_tile);
    }
    if (icon) {
        w = (icon->width > wPreferences.icon_size)
            ? wPreferences.icon_size : icon->width;
        x = (wPreferences.icon_size - w) / 2;
        sx = (icon->width - w)/2;

        if (!titled) {
            h = (icon->height > wPreferences.icon_size)
                ? wPreferences.icon_size : icon->height;
            y = (wPreferences.icon_size - h) / 2;
            sy = (icon->height - h)/2;
        } else {
            h = (icon->height+theight > wPreferences.icon_size
                 ? wPreferences.icon_size-theight : icon->height);
            y = theight+((int)wPreferences.icon_size-theight-h)/2;
            sy = (icon->height - h)/2;
        }
        RCombineArea(tile, icon, sx, sy, w, h, x, y);
    }

    if (shadowed) {
        RColor color;

        color.red   = scr->icon_back_texture->light.red   >> 8;
        color.green = scr->icon_back_texture->light.green >> 8;
        color.blue  = scr->icon_back_texture->light.blue  >> 8;
        color.alpha = 150; /* about 60% */
        RClearImage(tile, &color);
    }

    if (!RConvertImage(scr->rcontext, tile, &pixmap)) {
        wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));
    }
    RReleaseImage(tile);

    if (titled)
        drawIconTitle(scr, pixmap, theight);

    return pixmap;
}


void
wIconChangeTitle(WIcon *icon, char *new_title)
{
    int changed;

    changed = (new_title==NULL && icon->icon_name!=NULL)
        || (new_title!=NULL && icon->icon_name==NULL);

    if (icon->icon_name!=NULL)
        XFree(icon->icon_name);

    icon->icon_name = new_title;

    if (changed)
        icon->force_paint = 1;
    wIconPaint(icon);
}


void
wIconChangeImage(WIcon *icon, RImage *new_image)
{
    assert(icon != NULL);

    if (icon->image)
        RReleaseImage(icon->image);

    icon->image = new_image;

    wIconUpdate(icon);
}


RImage*
wIconValidateIconSize(WScreen *scr, RImage *icon)
{
    RImage *tmp;
    int w, h;

    if (!icon)
        return NULL;
#ifndef DONT_SCALE_ICONS
    if (wPreferences.icon_size != 64) {
        w = wPreferences.icon_size * icon->width / 64;
        h = wPreferences.icon_size * icon->height / 64;

        tmp = RScaleImage(icon, w, h);
        RReleaseImage(icon);
        icon = tmp;
    }
#endif
#if 0
    if (icon->width > wPreferences.icon_size
        || icon->height > wPreferences.icon_size) {
        if (icon->width > icon->height) {
            w = wPreferences.icon_size - 4;
            h = w*icon->height/icon->width;
        } else {
            h = wPreferences.icon_size - 4;
            w = h*icon->width/icon->height;
        }
        tmp = RScaleImage(icon, w, h);
        RReleaseImage(icon);
        icon = tmp;
    }
#endif

    return icon;
}


Bool
wIconChangeImageFile(WIcon *icon, char *file)
{
    WScreen *scr = icon->core->screen_ptr;
    RImage *image;
    char *path;
    int error = 0;

    if (!file) {
        wIconChangeImage(icon, NULL);
        return True;
    }

    path = FindImage(wPreferences.icon_path, file);

    if (path && (image = RLoadImage(scr->rcontext, path, 0))) {
        image = wIconValidateIconSize(icon->core->screen_ptr, image);

        wIconChangeImage(icon, image);
    } else {
        error = 1;
    }

    if (path)
        wfree(path);

    return !error;
}



static char*
getnameforicon(WWindow *wwin)
{
    char *prefix, *suffix;
    char *path;
    int len;

    if (wwin->wm_class && wwin->wm_instance) {
        int len = strlen(wwin->wm_class)+strlen(wwin->wm_instance)+2;
        suffix = wmalloc(len);
        snprintf(suffix, len, "%s.%s", wwin->wm_instance, wwin->wm_class);
    } else if (wwin->wm_class) {
        int len = strlen(wwin->wm_class)+1;
        suffix = wmalloc(len);
        snprintf(suffix, len, "%s", wwin->wm_class);
    } else if (wwin->wm_instance) {
        int len = strlen(wwin->wm_instance)+1;
        suffix = wmalloc(len);
        snprintf(suffix, len, "%s", wwin->wm_instance);
    } else {
        return NULL;
    }

    prefix = wusergnusteppath();
    len = strlen(prefix)+64+strlen(suffix);
    path = wmalloc(len+1);
    snprintf(path, len, "%s/Library/WindowMaker", prefix);

    if (access(path, F_OK)!=0) {
        if (mkdir(path, S_IRUSR|S_IWUSR|S_IXUSR)) {
            wsyserror(_("could not create directory %s"), path);
            wfree(path);
            wfree(suffix);
            return NULL;
        }
    }
    strcat(path, "/CachedPixmaps");
    if (access(path, F_OK)!=0) {
        if (mkdir(path, S_IRUSR|S_IWUSR|S_IXUSR)!=0) {
            wsyserror(_("could not create directory %s"), path);
            wfree(path);
            wfree(suffix);
            return NULL;
        }
    }

    strcat(path, "/");
    strcat(path, suffix);
    strcat(path, ".xpm");
    wfree(suffix);

    return path;
}


/*
 * wIconStore--
 * 	Stores the client supplied icon at ~/GNUstep/Library/WindowMaker/CachedPixmaps
 * and returns the path for that icon. Returns NULL if there is no
 * client supplied icon or on failure.
 *
 * Side effects:
 * 	New directories might be created.
 */
char*
wIconStore(WIcon *icon)
{
    char *path;
    RImage *image;
    WWindow *wwin = icon->owner;

    if (!wwin || !wwin->wm_hints || !(wwin->wm_hints->flags & IconPixmapHint)
        || wwin->wm_hints->icon_pixmap == None)
        return NULL;

    path = getnameforicon(wwin);
    if (!path)
        return NULL;

    image = RCreateImageFromDrawable(icon->core->screen_ptr->rcontext,
                                     wwin->wm_hints->icon_pixmap,
                                     (wwin->wm_hints->flags & IconMaskHint)
                                     ? wwin->wm_hints->icon_mask : None);
    if (!image) {
        wfree(path);
        return NULL;
    }

    if (!RSaveImage(image, path, "XPM")) {
        wfree(path);
        path = NULL;
    }
    RReleaseImage(image);

    return path;
}


/*
void wIconChangeIconWindow(WIcon *icon, Window new_window);
*/

static void
cycleColor(void *data)
{
    WIcon *icon = (WIcon*)data;
    WScreen *scr = icon->core->screen_ptr;
    XGCValues gcv;

    icon->step--;
    gcv.dash_offset = icon->step;
    XChangeGC(dpy, scr->icon_select_gc, GCDashOffset, &gcv);

    XDrawRectangle(dpy, icon->core->window, scr->icon_select_gc, 0, 0,
                   icon->core->width-1, icon->core->height-1);
    icon->handlerID = WMAddTimerHandler(COLOR_CYCLE_DELAY, cycleColor, icon);
}


void
wIconSetHighlited(WIcon *icon, Bool flag)
{
    if (icon->highlighted == flag) {
        return;
    }

    icon->highlighted = flag;
    wIconPaint(icon);
}



void
wIconSelect(WIcon *icon)
{
    WScreen *scr = icon->core->screen_ptr;
    icon->selected = !icon->selected;

    if (icon->selected) {
        icon->step = 0;
        if (!wPreferences.dont_blink)
            icon->handlerID = WMAddTimerHandler(10, cycleColor, icon);
        else
            XDrawRectangle(dpy, icon->core->window, scr->icon_select_gc, 0, 0,
                           icon->core->width-1, icon->core->height-1);
    } else {
        if (icon->handlerID) {
            WMDeleteTimerHandler(icon->handlerID);
            icon->handlerID = NULL;
        }
        XClearArea(dpy, icon->core->window, 0, 0, icon->core->width,
                   icon->core->height, True);
    }
}


void
wIconUpdate(WIcon *icon)
{
    WScreen *scr = icon->core->screen_ptr;
    int title_height = WMFontHeight(scr->icon_title_font);
    WWindow *wwin = icon->owner;

    assert(scr->icon_tile!=NULL);

    if (icon->pixmap!=None)
        XFreePixmap(dpy, icon->pixmap);
    icon->pixmap = None;


    if (wwin && (WFLAGP(wwin, always_user_icon)
#ifdef NETWM_HINTS
                 || wwin->net_icon_image
#endif
                ))
        goto user_icon;

    /* use client specified icon window */
    if (icon->icon_win!=None) {
        XWindowAttributes attr;
        int resize=0;
        unsigned int width, height, depth;
        int theight;
        Pixmap pixmap;

        getSize(icon->icon_win, &width, &height, &depth);

        if (width > wPreferences.icon_size) {
            resize = 1;
            width = wPreferences.icon_size;
        }
        if (height > wPreferences.icon_size) {
            resize = 1;
            height = wPreferences.icon_size;
        }
        if (icon->show_title
            && (height+title_height < wPreferences.icon_size)) {
            pixmap = XCreatePixmap(dpy, scr->w_win, wPreferences.icon_size,
                                   wPreferences.icon_size, scr->w_depth);
            XSetClipMask(dpy, scr->copy_gc, None);
            XCopyArea(dpy, scr->icon_tile_pixmap, pixmap, scr->copy_gc, 0, 0,
                      wPreferences.icon_size, wPreferences.icon_size, 0, 0);
            drawIconTitle(scr, pixmap, title_height);
            theight = title_height;
        } else {
            pixmap = None;
            theight = 0;
            XSetWindowBackgroundPixmap(dpy, icon->core->window,
                                       scr->icon_tile_pixmap);
        }

        XSetWindowBorderWidth(dpy, icon->icon_win, 0);
        XReparentWindow(dpy, icon->icon_win, icon->core->window,
                        (wPreferences.icon_size-width)/2,
                        theight+(wPreferences.icon_size-height-theight)/2);
        if (resize)
            XResizeWindow(dpy, icon->icon_win, width, height);

        XMapWindow(dpy, icon->icon_win);

        XAddToSaveSet(dpy, icon->icon_win);

        icon->pixmap = pixmap;

        if (XGetWindowAttributes(dpy, icon->icon_win, &attr)) {
            if (attr.all_event_masks & ButtonPressMask) {
                wHackedGrabButton(Button1, MOD_MASK, icon->core->window, True,
                                  ButtonPressMask, GrabModeSync, GrabModeAsync,
                                  None, wCursor[WCUR_ARROW]);
            }
        }
    } else if (wwin && wwin->wm_hints
               && (wwin->wm_hints->flags & IconPixmapHint)) {
        int x, y;
        unsigned int w, h;
        Window jw;
        int ji, dotitle;
        unsigned int ju, d;
        Pixmap pixmap;

        if (!XGetGeometry(dpy, wwin->wm_hints->icon_pixmap, &jw,
                          &ji, &ji, &w, &h, &ju, &d)) {
            icon->owner->wm_hints->flags &= ~IconPixmapHint;
            goto user_icon;
        }

        pixmap = XCreatePixmap(dpy, icon->core->window, wPreferences.icon_size,
                               wPreferences.icon_size, scr->w_depth);
        XSetClipMask(dpy, scr->copy_gc, None);
        XCopyArea(dpy, scr->icon_tile_pixmap, pixmap, scr->copy_gc, 0, 0,
                  wPreferences.icon_size, wPreferences.icon_size, 0, 0);

        if (w > wPreferences.icon_size)
            w = wPreferences.icon_size;
        x = (wPreferences.icon_size-w)/2;

        if (icon->show_title && (title_height < wPreferences.icon_size)) {
            drawIconTitle(scr, pixmap, title_height);
            dotitle = 1;

            if (h > wPreferences.icon_size - title_height - 2) {
                h = wPreferences.icon_size - title_height - 2;
                y = title_height + 1;
            } else {
                y = (wPreferences.icon_size-h-title_height)/2+title_height + 1;
            }
        } else {
            dotitle = 0;
            if (w > wPreferences.icon_size)
                w = wPreferences.icon_size;
            y = (wPreferences.icon_size-h)/2;
        }

        if (wwin->wm_hints->flags & IconMaskHint)
            XSetClipMask(dpy, scr->copy_gc, wwin->wm_hints->icon_mask);

        XSetClipOrigin(dpy, scr->copy_gc, x, y);

        if (d != scr->w_depth) {
            XSetForeground(dpy, scr->copy_gc, scr->black_pixel);
            XSetBackground(dpy, scr->copy_gc, scr->white_pixel);
            XCopyPlane(dpy, wwin->wm_hints->icon_pixmap, pixmap, scr->copy_gc,
                       0, 0, w, h, x, y, 1);
        } else {
            XCopyArea(dpy, wwin->wm_hints->icon_pixmap, pixmap, scr->copy_gc,
                      0, 0, w, h, x, y);
        }

        XSetClipOrigin(dpy, scr->copy_gc, 0, 0);

        icon->pixmap = pixmap;
    } else {
    user_icon:

        if (icon->image) {
            icon->pixmap = makeIcon(scr, icon->image, icon->show_title,
                                    icon->shadowed, icon->tile_type);
        } else {
            /* make default icons */

            if (!scr->def_icon_pixmap) {
                RImage *image = NULL;
                char *path;
                char *file;

                file = wDefaultGetIconFile(scr, NULL, NULL, False);
                if (file) {
                    path = FindImage(wPreferences.icon_path, file);
                    if (!path) {
                        wwarning(_("could not find default icon \"%s\""),file);
                        goto make_icons;
                    }

                    image = RLoadImage(scr->rcontext, path, 0);
                    if (!image) {
                        wwarning(_("could not load default icon \"%s\":%s"),
                                 file, RMessageForError(RErrorCode));
                    }
                    wfree(path);
                }
                make_icons:

                image = wIconValidateIconSize(scr, image);
                scr->def_icon_pixmap = makeIcon(scr, image, False, False,
                                                icon->tile_type);
                scr->def_ticon_pixmap = makeIcon(scr, image, True, False,
                                                 icon->tile_type);
                if (image)
                    RReleaseImage(image);
            }

            if (icon->show_title) {
                XSetWindowBackgroundPixmap(dpy, icon->core->window,
                                           scr->def_ticon_pixmap);
            } else {
                XSetWindowBackgroundPixmap(dpy, icon->core->window,
                                           scr->def_icon_pixmap);
            }
            icon->pixmap = None;
        }
    }
    if (icon->pixmap != None) {
        XSetWindowBackgroundPixmap(dpy, icon->core->window, icon->pixmap);
    }
    XClearWindow(dpy, icon->core->window);

    wIconPaint(icon);
}



void
wIconPaint(WIcon *icon)
{
    WScreen *scr=icon->core->screen_ptr;
    int x;
    char *tmp;

    if (icon->force_paint) {
        icon->force_paint = 0;
        wIconUpdate(icon);
        return;
    }

    XClearWindow(dpy, icon->core->window);

    /* draw the icon title */
    if (icon->show_title && icon->icon_name!=NULL) {
        int l;
        int w;

        tmp = ShrinkString(scr->icon_title_font, icon->icon_name,
                           wPreferences.icon_size-4);
        w = WMWidthOfString(scr->icon_title_font, tmp, l=strlen(tmp));

        if (w > icon->core->width - 4)
            x = (icon->core->width - 4) - w;
        else
            x = (icon->core->width - w)/2;

        WMDrawString(scr->wmscreen, icon->core->window, scr->icon_title_color,
                     scr->icon_title_font, x, 1, tmp, l);
        wfree(tmp);
    }

    if (icon->selected)
        XDrawRectangle(dpy, icon->core->window, scr->icon_select_gc, 0, 0,
                       icon->core->width-1, icon->core->height-1);
}


/******************************************************************/

static void
miniwindowExpose(WObjDescriptor *desc, XEvent *event)
{
    wIconPaint(desc->parent);
}


static void
miniwindowDblClick(WObjDescriptor *desc, XEvent *event)
{
    WIcon *icon = desc->parent;

    assert(icon->owner!=NULL);

    wDeiconifyWindow(icon->owner);
}


static void
miniwindowMouseDown(WObjDescriptor *desc, XEvent *event)
{
    WIcon *icon = desc->parent;
    WWindow *wwin = icon->owner;
    XEvent ev;
    int x=wwin->icon_x, y=wwin->icon_y;
    int dx=event->xbutton.x, dy=event->xbutton.y;
    int grabbed=0;
    int clickButton=event->xbutton.button;

    if (WCHECK_STATE(WSTATE_MODAL))
        return;

    if (IsDoubleClick(icon->core->screen_ptr, event)) {
        miniwindowDblClick(desc, event);
        return;
    }

#ifdef DEBUG
    puts("Moving miniwindow");
#endif
    if (event->xbutton.button == Button1) {
        if (event->xbutton.state & MOD_MASK)
            wLowerFrame(icon->core);
        else
            wRaiseFrame(icon->core);
        if (event->xbutton.state & ShiftMask) {
            wIconSelect(icon);
            wSelectWindow(icon->owner, !wwin->flags.selected);
        }
    } else if (event->xbutton.button == Button3) {
        WObjDescriptor *desc;

        OpenMiniwindowMenu(wwin, event->xbutton.x_root,
                           event->xbutton.y_root);

        /* allow drag select of menu */
        desc = &wwin->screen_ptr->window_menu->menu->descriptor;
        event->xbutton.send_event = True;
        (*desc->handle_mousedown)(desc, event);

        return;
    }

    if (XGrabPointer(dpy, icon->core->window, False, ButtonMotionMask
                     |ButtonReleaseMask|ButtonPressMask, GrabModeAsync,
                     GrabModeAsync, None, None, CurrentTime) !=GrabSuccess) {
#ifdef DEBUG0
        wwarning("pointer grab failed for icon move");
#endif
    }
    while(1) {
        WMMaskEvent(dpy, PointerMotionMask|ButtonReleaseMask|ButtonPressMask
                    |ButtonMotionMask|ExposureMask, &ev);
        switch (ev.type) {
        case Expose:
            WMHandleEvent(&ev);
            break;

        case MotionNotify:
            if (!grabbed) {
                if (abs(dx-ev.xmotion.x)>=MOVE_THRESHOLD
                    || abs(dy-ev.xmotion.y)>=MOVE_THRESHOLD) {
                    XChangeActivePointerGrab(dpy, ButtonMotionMask
                                             |ButtonReleaseMask|ButtonPressMask,
                                             wCursor[WCUR_MOVE], CurrentTime);
                    grabbed=1;
                } else {
                    break;
                }
            }
            x = ev.xmotion.x_root - dx;
            y = ev.xmotion.y_root - dy;
            XMoveWindow(dpy, icon->core->window, x, y);
            break;

        case ButtonPress:
            break;

        case ButtonRelease:
            if (ev.xbutton.button != clickButton)
                break;

            if (wwin->icon_x!=x || wwin->icon_y!=y)
                wwin->flags.icon_moved = 1;

            XMoveWindow(dpy, icon->core->window, x, y);

            wwin->icon_x = x;
            wwin->icon_y = y;
#ifdef DEBUG
            puts("End miniwindow move");
#endif
            XUngrabPointer(dpy, CurrentTime);

            if (wPreferences.auto_arrange_icons)
                wArrangeIcons(wwin->screen_ptr, True);
            return;

        }
    }
}


