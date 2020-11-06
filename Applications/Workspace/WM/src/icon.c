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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <wraster.h>
#include <sys/stat.h>

#include <WINGs/notification.h>

#include "GNUstep.h"
#include "WindowMaker.h"
#include "wcore.h"
#include "texture.h"
#include "window.h"
#include "icon.h"
#include "actions.h"
#include "stacking.h"
#include "application.h"
#include "defaults.h"
#include "appicon.h"
#include "wmspec.h"
#include "misc.h"
#include "startup.h"
#include "event.h"
#include "winmenu.h"

#include "dock.h"
#include <Workspace+WM.h>

/**** Global variables ****/

#define MOD_MASK wPreferences.modifier_mask
#define ICON_BORDER 3

static void miniwindowExpose(WObjDescriptor *desc, XEvent *event);
static void miniwindowMouseDown(WObjDescriptor *desc, XEvent *event);
static void miniwindowDblClick(WObjDescriptor *desc, XEvent *event);

static WIcon *icon_create_core(WScreen *scr, int coord_x, int coord_y);

static void set_dockapp_in_icon(WIcon *icon);
static void get_rimage_icon_from_icon_win(WIcon *icon);
static void get_rimage_icon_from_user_icon(WIcon *icon);
static void get_rimage_icon_from_default_icon(WIcon *icon);
static void get_rimage_icon_from_x11(WIcon *icon);

static void icon_update_pixmap(WIcon *icon, RImage *image);
static void unset_icon_image(WIcon *icon);

/****** Notification Observers ******/

static void appearanceObserver(void *self, WMNotification *notif)
{
  WIcon *icon = (WIcon *) self;
  uintptr_t flags = (uintptr_t)WMGetNotificationClientData(notif);

  if ((flags & WTextureSettings) || (flags & WFontSettings)) {
    /* If the rimage exists, update the icon, else create it */
    if (icon->file_image)
      update_icon_pixmap(icon);
    else
      wIconPaint(icon);
  }

  /* so that the appicon expose handlers will paint the appicon specific
   * stuff */
  XClearArea(dpy, icon->core->window, 0, 0, icon->core->width, icon->core->height, True);
}

static void tileObserver(void *self, WMNotification *notif)
{
  WIcon *icon = (WIcon *) self;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) notif;

  update_icon_pixmap(icon);

  XClearArea(dpy, icon->core->window, 0, 0, 1, 1, True);
}

/************************************/

static int getSize(Drawable d, unsigned int *w, unsigned int *h, unsigned int *dep)
{
  Window rjunk;
  int xjunk, yjunk;
  unsigned int bjunk;

  return XGetGeometry(dpy, d, &rjunk, &xjunk, &yjunk, w, h, &bjunk, dep);
}

WIcon *icon_create_for_wwindow(WWindow *wwin)
{
  WScreen *scr = wwin->screen_ptr;
  WIcon *icon;

  icon = icon_create_core(scr, wwin->icon_x, wwin->icon_y);

  icon->owner = wwin;
  if (wwin->wm_hints && (wwin->wm_hints->flags & IconWindowHint)) {
    if (wwin->client_win == wwin->main_window) {
      WApplication *wapp;
      /* do not let miniwindow steal app-icon's icon window */
      wapp = wApplicationOf(wwin->client_win);
      if (!wapp || wapp->app_icon == NULL)
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

  wIconChangeTitle(icon, wwin);
  icon->tile_type = TILE_NORMAL;

  set_icon_image_from_database(icon, wwin->wm_instance, wwin->wm_class, NULL);
  /* Update the icon, because icon could be NULL */
  wIconUpdate(icon);

  WMAddNotificationObserver(appearanceObserver, icon, WNIconAppearanceSettingsChanged, icon);
  WMAddNotificationObserver(tileObserver, icon, WNIconTileSettingsChanged, icon);

  return icon;
}

WIcon *icon_create_for_dock(WScreen *scr, const char *command, const char *wm_instance, const char *wm_class, int tile)
{
  WIcon *icon;

  icon = icon_create_core(scr, 0, 0);
  icon->tile_type = tile;

  set_icon_image_from_database(icon, wm_instance, wm_class, command);
  /* Update the icon, because icon could be NULL */
  wIconUpdate(icon);

  WMAddNotificationObserver(appearanceObserver, icon, WNIconAppearanceSettingsChanged, icon);
  WMAddNotificationObserver(tileObserver, icon, WNIconTileSettingsChanged, icon);

  return icon;
}

static WIcon *icon_create_core(WScreen *scr, int coord_x, int coord_y)
{
  WIcon *icon;

  icon = wmalloc(sizeof(WIcon));
  icon->core = wCoreCreateTopLevel(scr,
                                   coord_x,
                                   coord_y,
                                   wPreferences.icon_size,
                                   wPreferences.icon_size,
                                   0, scr->w_depth, scr->w_visual, scr->w_colormap,
                                   scr->white_pixel);

  /* Set NETWM window type to be correctly handled by compton */
  // This atoms already exist in wmspe.c but defined static.
  Atom data = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);
  Atom property = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
  XChangeProperty(dpy, icon->core->window, property,
                  XA_ATOM, 32, PropModeReplace,
                  (unsigned char *)&data, 1);

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

  /* Icon image */
  icon->file = NULL;
  icon->file_image = NULL;

  return icon;
}

void wIconDestroy(WIcon *icon)
{
  WCoreWindow *core = icon->core;
  WScreen *scr = core->screen_ptr;

  WMRemoveNotificationObserver(icon);

  if (icon->handlerID)
    WMDeleteTimerHandler(icon->handlerID);

  if (icon->icon_win) {
    int x = 0, y = 0;

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

  if (icon->mini_preview)
    XFreePixmap(dpy, icon->mini_preview);

  unset_icon_image(icon);

  wCoreDestroy(icon->core);
  wfree(icon);
}

#ifndef NEXTSPACE
static void drawIconTitleBackground(WScreen *scr, Pixmap pixmap, int height)
{
  XFillRectangle(dpy, pixmap, scr->icon_title_texture->normal_gc, 0, 0, wPreferences.icon_size, height + 1);
  XDrawLine(dpy, pixmap, scr->icon_title_texture->light_gc, 0, 0, wPreferences.icon_size, 0);
  XDrawLine(dpy, pixmap, scr->icon_title_texture->light_gc, 0, 0, 0, height + 1);
  XDrawLine(dpy, pixmap, scr->icon_title_texture->dim_gc,
            wPreferences.icon_size - 1, 0, wPreferences.icon_size - 1, height + 1);
}
#endif /* NEXTSPACE */

static void icon_update_pixmap(WIcon *icon, RImage *image)
{
  RImage *tile;
  Pixmap pixmap;
  int x, y, sx, sy;
  unsigned w, h;
  int theight = 0;
  WScreen *scr = icon->core->screen_ptr;

  switch (icon->tile_type) {
  case TILE_NORMAL:
#ifdef NEXTSPACE
    if (icon->show_title)
      tile = RCloneImage(scr->miniwindow_tile);
    else
#endif
      tile = RCloneImage(scr->icon_tile);
    break;
  case TILE_CLIP:
    tile = RCloneImage(scr->clip_tile);
    break;
  case TILE_DRAWER:
    tile = RCloneImage(scr->drawer_tile);
    break;
  default:
    /*
     * The icon has always rigth value, this case is
     * only to avoid a compiler warning with "tile"
     * "may be used uninitialized"
     */
    wwarning("Unknown tile type: %d.\n", icon->tile_type);
    tile = RCloneImage(scr->icon_tile);
  }

  if (image) {
    w = (image->width > wPreferences.icon_size)
      ? wPreferences.icon_size : image->width;
    x = (wPreferences.icon_size - w) / 2;
    sx = (image->width - w) / 2;

    if (icon->show_title)
      theight = WMFontHeight(scr->icon_title_font);

    h = (image->height + theight > wPreferences.icon_size
         ? wPreferences.icon_size - theight : image->height);
    y = theight + (wPreferences.icon_size - theight - h) / 2;
    sy = (image->height - h) / 2;

    RCombineArea(tile, image, sx, sy, w, h, x, y);
  }

  if (icon->shadowed) {
    RColor color;

    color.red = scr->icon_back_texture->light.red >> 8;
    color.green = scr->icon_back_texture->light.green >> 8;
    color.blue = scr->icon_back_texture->light.blue >> 8;
    color.alpha = 150;	/* about 60% */
    RClearImage(tile, &color);
  }

  if (icon->highlighted) {
    RColor color;

    color.red = color.green = color.blue = 0;
    color.alpha = 160;
    RLightImage(tile, &color);
  }

  if (!RConvertImage(scr->rcontext, tile, &pixmap))
    wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));

  RReleaseImage(tile);

  /* Draw the icon's title background (without text) */
#ifndef NEXTSPACE
  if (icon->show_title)
    drawIconTitleBackground(scr, pixmap, theight);
#endif

  icon->pixmap = pixmap;
}

void wIconChangeTitle(WIcon *icon, WWindow *wwin)
{
  if (!icon || !wwin)
    return;

  /* Remove the previous icon title */
  if (icon->icon_name != NULL)
    XFree(icon->icon_name);

  /* Set the new one, using two methods to identify
     the icon name or switch back to window name */
  icon->icon_name = wNETWMGetIconName(wwin->client_win);
  if (!icon->icon_name || !strlen(icon->icon_name))
    if (!wGetIconName(dpy, wwin->client_win, &icon->icon_name))
      icon->icon_name = wNETWMGetWindowName(wwin->client_win);
}

RImage *wIconValidateIconSize(RImage *icon, int max_size)
{
  RImage *nimage;

  if (!icon)
    return NULL;

  /* We should hold "ICON_BORDER" (~2) pixels to include the icon border */
  if (((max_size + ICON_BORDER) < icon->width) ||
      ((max_size + ICON_BORDER) < icon->height)) {
    if (icon->width > icon->height)
      nimage = RScaleImage(icon, max_size - ICON_BORDER,
                           (icon->height * (max_size - ICON_BORDER) / icon->width));
    else
      nimage = RScaleImage(icon, (icon->width * (max_size - ICON_BORDER) / icon->height),
                           max_size - ICON_BORDER);
    RReleaseImage(icon);
    icon = nimage;
  }

  return icon;
}

int wIconChangeImageFile(WIcon *icon, const char *file)
{
  WScreen *scr = icon->core->screen_ptr;
  char *path;
  RImage *image = NULL;

  /* If no new image, don't do nothing */
  if (!file)
    return 1;

  /* Find the new image */
  path = FindImage(wPreferences.icon_path, file);
  if (!path)
    return 0;

  image = get_rimage_from_file(scr, path, wPreferences.icon_size);
  if (!image) {
    wfree(path);
    return 0;
  }

  /* Set the new image */
  set_icon_image_from_image(icon, image);
  icon->file = wstrdup(path);
  update_icon_pixmap(icon);

  wfree(path);
  return 1;
}

static char *get_name_for_wwin(WWindow *wwin)
{
  return get_name_for_instance_class(wwin->wm_instance, wwin->wm_class);
}

char *get_name_for_instance_class(const char *wm_instance, const char *wm_class)
{
  char *suffix;
  int len;

  if (wm_class && wm_instance) {
    len = strlen(wm_class) + strlen(wm_instance) + 2;
    suffix = wmalloc(len);
    snprintf(suffix, len, "%s.%s", wm_instance, wm_class);
  } else if (wm_class) {
    len = strlen(wm_class) + 1;
    suffix = wmalloc(len);
    snprintf(suffix, len, "%s", wm_class);
  } else if (wm_instance) {
    len = strlen(wm_instance) + 1;
    suffix = wmalloc(len);
    snprintf(suffix, len, "%s", wm_instance);
  } else {
    return NULL;
  }

  return suffix;
}

static char *get_icon_cache_path(void)
{
  const char *prefix;
  char *path;
  int len, ret;

  prefix = wusergnusteppath();
  len = strlen(prefix) + strlen(CACHE_ICON_PATH) + 2;
  path = wmalloc(len);
  snprintf(path, len, "%s%s/", prefix, CACHE_ICON_PATH);

  /* If the folder exists, exit */
  if (access(path, F_OK) == 0)
    return path;

  /* Create the folder */
  ret = wmkdirhier((const char *) path);

  /* Exit 1 on success, 0 on failure */
  if (ret == 1)
    return path;

  /* Fail */
  wfree(path);
  return NULL;
}

static RImage *get_wwindow_image_from_wmhints(WWindow *wwin, WIcon *icon)
{
  RImage *image = NULL;
  XWMHints *hints = wwin->wm_hints;

  if (hints && (hints->flags & IconPixmapHint) && hints->icon_pixmap != None)
    image = RCreateImageFromDrawable(icon->core->screen_ptr->rcontext,
                                     hints->icon_pixmap,
                                     (hints->flags & IconMaskHint)
                                     ? hints->icon_mask : None);

  return image;
}

/*
 * wIconStore--
 * 	Stores the client supplied icon at CACHE_ICON_PATH
 * and returns the path for that icon. Returns NULL if there is no
 * client supplied icon or on failure.
 *
 * Side effects:
 * 	New directories might be created.
 */
char *wIconStore(WIcon *icon)
{
  char *path, *dir_path, *file;
  int len = 0;
  RImage *image = NULL;
  WWindow *wwin = icon->owner;

  if (!wwin)
    return NULL;

  dir_path = get_icon_cache_path();
  if (!dir_path)
    return NULL;

  file = get_name_for_wwin(wwin);
  if (!file) {
    wfree(dir_path);
    return NULL;
  }

  len = strlen(dir_path) + strlen(file) + 5;
  path = wmalloc(len);
  snprintf(path, len, "%s%s.xpm", dir_path, file);
  wfree(dir_path);
  wfree(file);

  /* If icon exists, exit */
  if (access(path, F_OK) == 0)
    return path;

  if (wwin->net_icon_image)
    image = RRetainImage(wwin->net_icon_image);
  else
    image = get_wwindow_image_from_wmhints(wwin, icon);

  if (!image) {
    wfree(path);
    return NULL;
  }

#ifdef NEXTSPACE
  path = WSSaveRasterImageAsTIFF(image, path);
#else
  if (!RSaveImage(image, path, "XPM")) {
    wfree(path);
    path = NULL;
  }
#endif /* NEXTSPACE */

  RReleaseImage(image);

  return path;
}

static void cycleColor(void *data)
{
  WIcon *icon = (WIcon *) data;
  WScreen *scr = icon->core->screen_ptr;
  XGCValues gcv;

  icon->step--;
  gcv.dash_offset = icon->step;
  XChangeGC(dpy, scr->icon_select_gc, GCDashOffset, &gcv);

  XDrawRectangle(dpy, icon->core->window, scr->icon_select_gc, 0, 0,
                 icon->core->width - 1, icon->core->height - 1);
  icon->handlerID = WMAddTimerHandler(COLOR_CYCLE_DELAY, cycleColor, icon);
}

void wIconSetHighlited(WIcon *icon, Bool flag)
{
  if (icon->highlighted == flag)
    return;

  icon->highlighted = flag;
  update_icon_pixmap(icon);
}

void wIconSelect(WIcon *icon)
{
  WScreen *scr = icon->core->screen_ptr;
  icon->selected = !icon->selected;

  if (icon->selected) {
    icon->step = 0;
    if (!wPreferences.dont_blink)
      icon->handlerID = WMAddTimerHandler(10, cycleColor, icon);
    else
      XDrawRectangle(dpy, icon->core->window, scr->icon_select_gc, 0, 0,
                     icon->core->width - 1, icon->core->height - 1);
  } else {
    if (icon->handlerID) {
      WMDeleteTimerHandler(icon->handlerID);
      icon->handlerID = NULL;
    }
    XClearArea(dpy, icon->core->window, 0, 0, icon->core->width, icon->core->height, True);
  }
}

static void unset_icon_image(WIcon *icon)
{
  if (icon->file) {
    wfree(icon->file);
    icon->file = NULL;
  }

  if (icon->file_image) {
    RReleaseImage(icon->file_image);
    icon->file_image = NULL;
  }
}

void set_icon_image_from_image(WIcon *icon, RImage *image)
{
  if (!icon)
    return;

  unset_icon_image(icon);

  icon->file_image = NULL;
  icon->file_image = image;
}

void set_icon_minipreview(WIcon *icon, RImage *image)
{
  Pixmap tmp;
  RImage *scaled_mini_preview;
  WScreen *scr = icon->core->screen_ptr;

  scaled_mini_preview = RSmoothScaleImage(image, wPreferences.minipreview_size - 2 * MINIPREVIEW_BORDER,
	                                  wPreferences.minipreview_size - 2 * MINIPREVIEW_BORDER);

  if (RConvertImage(scr->rcontext, scaled_mini_preview, &tmp)) {
    if (icon->mini_preview != None)
      XFreePixmap(dpy, icon->mini_preview);
    icon->mini_preview = tmp;
  }
  RReleaseImage(scaled_mini_preview);
}

void wIconUpdate(WIcon *icon)
{
  WWindow *wwin = NULL;

  if (icon && icon->owner)
    wwin = icon->owner;

  if (wwin && WFLAGP(wwin, always_user_icon)) {
    /* Forced use user_icon */
    get_rimage_icon_from_user_icon(icon);
  } else if (icon->icon_win != None) {
    /* Get the Pixmap from the WIcon */
    get_rimage_icon_from_icon_win(icon);
  } else if (wwin && wwin->net_icon_image) {
    /* Use _NET_WM_ICON icon */
    get_rimage_icon_from_x11(icon);
  } else if (wwin && wwin->wm_hints && (wwin->wm_hints->flags & IconPixmapHint)) {
    /* Get the Pixmap from the wm_hints, else, from the user */
    unset_icon_image(icon);
    icon->file_image = get_rimage_icon_from_wm_hints(icon);
    if (!icon->file_image)
      get_rimage_icon_from_user_icon(icon);
  } else {
    /* Get the Pixmap from the user */
    get_rimage_icon_from_user_icon(icon);
  }

  update_icon_pixmap(icon);
}

void update_icon_pixmap(WIcon *icon)
{
  if (icon->pixmap != None)
    XFreePixmap(dpy, icon->pixmap);

  icon->pixmap = None;
 
  /* If dockapp, put inside the icon */
  if (icon->icon_win != None) {
    /* file_image is NULL, because is docked app */
    icon_update_pixmap(icon, NULL);
    set_dockapp_in_icon(icon);
  }
  else {
    /* Create the pixmap even if `file_image` is NULL */
    icon_update_pixmap(icon, icon->file_image);
  }

  if (icon->pixmap != None) {
    XSetWindowBackgroundPixmap(dpy, icon->core->window, icon->pixmap);
  }

  /* Paint it */
  wIconPaint(icon);
}

static void get_rimage_icon_from_x11(WIcon *icon)
{
  /* Remove the icon image */
  unset_icon_image(icon);

  /* Set the new icon image */
  icon->file_image = RRetainImage(icon->owner->net_icon_image);
}

static void get_rimage_icon_from_user_icon(WIcon *icon)
{
  if (icon->file_image)
    return;

  get_rimage_icon_from_default_icon(icon);
}

static void get_rimage_icon_from_default_icon(WIcon *icon)
{
  WScreen *scr = icon->core->screen_ptr;

  /* If the icon don't have image, we should use the default image. */
  if (!scr->def_icon_rimage)
    scr->def_icon_rimage = get_default_image(scr);

  /* Remove the icon image */
  unset_icon_image(icon);

  /* Set the new icon image */
  icon->file_image = RRetainImage(scr->def_icon_rimage);
}

/* Get the RImage from the WIcon of the WWindow */
static void get_rimage_icon_from_icon_win(WIcon *icon)
{
  RImage *image;

  /* Create the new RImage */
  image = get_window_image_from_x11(icon->icon_win);

  /* Free the icon info */
  unset_icon_image(icon);

  /* Set the new info */
  icon->file_image = image;
}

/* Set the dockapp in the WIcon */
static void set_dockapp_in_icon(WIcon *icon)
{
  XWindowAttributes attr;
  WScreen *scr = icon->core->screen_ptr;
  unsigned int w, h, d;

  /* Reparent the dock application to the icon */

  /* We need the application size to center it
   * and show in the correct position */
  getSize(icon->icon_win, &w, &h, &d);

  /* Set the background pixmap */
  XSetWindowBackgroundPixmap(dpy, icon->core->window, scr->icon_tile_pixmap);

  /* Set the icon border */
  XSetWindowBorderWidth(dpy, icon->icon_win, 0);

  /* Put the dock application in the icon */
  XReparentWindow(dpy, icon->icon_win, icon->core->window,
                  (wPreferences.icon_size - w) / 2,
                  (wPreferences.icon_size - h) / 2);

  /* Show it and save */
  XMapWindow(dpy, icon->icon_win);
  XAddToSaveSet(dpy, icon->icon_win);

  /* Needed to move the icon clicking on the application part */
  if ((XGetWindowAttributes(dpy, icon->icon_win, &attr)) &&
      (attr.all_event_masks & ButtonPressMask))
    wHackedGrabButton(Button1, MOD_MASK, icon->core->window, True,
                      ButtonPressMask, GrabModeSync, GrabModeAsync,
                      None, wPreferences.cursor[WCUR_ARROW]);
}

/* Get the RImage from the XWindow wm_hints */
RImage *get_rimage_icon_from_wm_hints(WIcon *icon)
{
  RImage *image = NULL;
  unsigned int w, h, d;
  WWindow *wwin = icon->owner;

  if (!getSize(wwin->wm_hints->icon_pixmap, &w, &h, &d)) {
    icon->owner->wm_hints->flags &= ~IconPixmapHint;
    return NULL;
  }

  image = get_wwindow_image_from_wmhints(wwin, icon);
  if (!image)
    return NULL;

  /* Resize the icon to the wPreferences.icon_size size */
  image = wIconValidateIconSize(image, wPreferences.icon_size);

  return image;
}

/* This function updates in the screen the icon title */
static void update_icon_title(WIcon *icon)
{
  WScreen *scr = icon->core->screen_ptr;
  int x, l, w;
  char *tmp;

  /* draw the icon title */
  if (icon->show_title && icon->icon_name != NULL) {
    tmp = ShrinkString(scr->icon_title_font, icon->icon_name, wPreferences.icon_size - 4);
    w = WMWidthOfString(scr->icon_title_font, tmp, l = strlen(tmp));

    if (w > icon->core->width - 4)
      x = (icon->core->width - 4) - w;
    else
      x = (icon->core->width - w) / 2;
#ifdef NEXTSPACE
    if (x < 2) x = 2;
#endif /* NEXTSPACE */
    WMDrawString(scr->wmscreen, icon->core->window, scr->icon_title_color,
                 scr->icon_title_font, x, 1, tmp, l);
    wfree(tmp);
  }
}


void wIconPaint(WIcon *icon)
{
  if (!icon || !icon->core || !icon->core->screen_ptr)
    return;

  WScreen *scr = icon->core->screen_ptr;

  XClearWindow(dpy, icon->core->window);

  update_icon_title(icon);

  if (icon->selected)
    XDrawRectangle(dpy, icon->core->window, scr->icon_select_gc, 0, 0,
                   icon->core->width - 1, icon->core->height - 1);
}

/******************************************************************/

static void miniwindowExpose(WObjDescriptor *desc, XEvent *event)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) event;

  wIconPaint(desc->parent);
}

static void miniwindowDblClick(WObjDescriptor *desc, XEvent *event)
{
  WIcon *icon = desc->parent;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) event;

  assert(icon->owner != NULL);

  wDeiconifyWindow(icon->owner);
}

static void miniwindowMouseDown(WObjDescriptor *desc, XEvent *event)
{
  WIcon *icon = desc->parent;
  WWindow *wwin = icon->owner;
  XEvent ev;
  int x = wwin->icon_x, y = wwin->icon_y;
  int dx = event->xbutton.x, dy = event->xbutton.y;
  int grabbed = 0;
  int clickButton = event->xbutton.button;
  Bool hasMoved = False;

  if (WCHECK_STATE(WSTATE_MODAL))
    return;

  if (IsDoubleClick(icon->core->screen_ptr, event)) {
    miniwindowDblClick(desc, event);
    return;
  }

  if (event->xbutton.button == Button1) {
    if (event->xbutton.state & MOD_MASK)
      wLowerFrame(icon->core);
    else
      wRaiseFrame(icon->core);
    if (event->xbutton.state & ShiftMask) {
      wIconSelect(icon);
      wSelectWindow(icon->owner, !wwin->flags.selected);
    }
  } else if (event->xbutton.button == Button3 && (event->xbutton.state & MOD_MASK)) {
    WObjDescriptor *desc;

    OpenMiniwindowMenu(wwin, event->xbutton.x_root, event->xbutton.y_root);

    /* allow drag select of menu */
    desc = &wwin->screen_ptr->window_menu->menu->descriptor;
    event->xbutton.send_event = True;
    (*desc->handle_mousedown) (desc, event);

    return;
  }

  if (XGrabPointer(dpy, icon->core->window, False, ButtonMotionMask
                   | ButtonReleaseMask | ButtonPressMask, GrabModeAsync,
                   GrabModeAsync, None, None, CurrentTime) != GrabSuccess) {
  }
  while (1) {
    WMMaskEvent(dpy, PointerMotionMask | ButtonReleaseMask | ButtonPressMask
                | ButtonMotionMask | ExposureMask, &ev);
    switch (ev.type) {
    case Expose:
      WMHandleEvent(&ev);
      break;

    case MotionNotify:
      hasMoved = True;
      if (!grabbed) {
        if (abs(dx - ev.xmotion.x) >= MOVE_THRESHOLD
            || abs(dy - ev.xmotion.y) >= MOVE_THRESHOLD) {
          XChangeActivePointerGrab(dpy, ButtonMotionMask
                                   | ButtonReleaseMask | ButtonPressMask,
                                   wPreferences.cursor[WCUR_MOVE], CurrentTime);
          grabbed = 1;
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

      if (wwin->icon_x != x || wwin->icon_y != y)
        wwin->flags.icon_moved = 1;

      XMoveWindow(dpy, icon->core->window, x, y);

      wwin->icon_x = x;
      wwin->icon_y = y;
      XUngrabPointer(dpy, CurrentTime);

      if (wPreferences.auto_arrange_icons)
        wArrangeIcons(wwin->screen_ptr, True);
      if (wPreferences.single_click && !hasMoved)
        miniwindowDblClick(desc, event);
      return;

    }
  }
}

void set_icon_image_from_database(WIcon *icon, const char *wm_instance,
                                  const char *wm_class, const char *command)
{
  char *file = NULL;

  file = get_icon_filename(wm_instance, wm_class, command, False);
  if (file) {
    icon->file = wstrdup(file);
    icon->file_image = get_rimage_from_file(icon->core->screen_ptr,
                                            icon->file, wPreferences.icon_size);
    wfree(file);
  }
}
