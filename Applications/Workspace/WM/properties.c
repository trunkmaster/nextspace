/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
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

#include "WM.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#include <core/util.h>
#include <core/log_utils.h>

#include "WM.h"
#include "window.h"
#include "GNUstep.h"
#include "properties.h"

int wPropertiesGetNormalHints(Window window, XSizeHints *size_hints, int *pre_iccm)
{
  long supplied_hints;

  if (!XGetWMNormalHints(dpy, window, size_hints, &supplied_hints)) {
    return False;
  }
  if (supplied_hints ==
      (USPosition | USSize | PPosition | PSize | PMinSize | PMaxSize | PResizeInc | PAspect)) {
    *pre_iccm = 1;
  } else {
    *pre_iccm = 0;
  }
  return True;
}

int wPropertiesGetWMClass(Window window, char **wm_class, char **wm_instance)
{
  XClassHint *class_hint;

  class_hint = XAllocClassHint();
  if (XGetClassHint(dpy, window, class_hint) == 0) {
    *wm_class = strdup("default");
    *wm_instance = strdup("default");
    XFree(class_hint);
    return False;
  }
  *wm_instance = strdup(class_hint->res_name);
  *wm_class = strdup(class_hint->res_class);

  XFree(class_hint->res_name);
  XFree(class_hint->res_class);
  XFree(class_hint);

  return True;
}

void wPropGetProtocols(Window window, WProtocols *prots)
{
  Atom *protocols;
  int count, i;

  memset(prots, 0, sizeof(WProtocols));
  if (!XGetWMProtocols(dpy, window, &protocols, &count)) {
    return;
  }
  for (i = 0; i < count; i++) {
    if (protocols[i] == w_global.atom.wm.take_focus)
      prots->TAKE_FOCUS = 1;
    else if (protocols[i] == w_global.atom.wm.delete_window)
      prots->DELETE_WINDOW = 1;
    else if (protocols[i] == w_global.atom.wm.save_yourself)
      prots->SAVE_YOURSELF = 1;
    else if (protocols[i] == w_global.atom.gnustep.wm_miniaturize_window)
      prots->MINIATURIZE_WINDOW = 1;
    else if (protocols[i] == w_global.atom.gnustep.wm_hide_app)
      prots->HIDE_APP = 1;
  }
  XFree(protocols);
}

unsigned char *wPropertiesGetWindowProperty(Window window, Atom hint, Atom type, int format, int count,
                                    int *retCount)
{
  Atom type_ret;
  int fmt_ret;
  unsigned long nitems_ret;
  unsigned long bytes_after_ret;
  unsigned char *data;
  int tmp;

  if (count <= 0)
    tmp = 0xffffff;
  else
    tmp = count;

  if (XGetWindowProperty(dpy, window, hint, 0, tmp, False, type, &type_ret, &fmt_ret, &nitems_ret,
                         &bytes_after_ret, (unsigned char **)&data) != Success ||
      !data)
    return NULL;

  if ((type != AnyPropertyType && type != type_ret) || (count > 0 && nitems_ret != count) ||
      (format != 0 && format != fmt_ret)) {
    XFree(data);
    return NULL;
  }

  if (retCount)
    *retCount = nitems_ret;

  return data;
}

int wPropertiesGetGNUstepWMAttr(Window window, GNUstepWMAttributes **attr)
{
  unsigned long *data;

  data = (unsigned long *)wPropertiesGetWindowProperty(window, w_global.atom.gnustep.wm_attr,
                                               w_global.atom.gnustep.wm_attr, 32, 9, NULL);

  if (!data)
    return False;

  *attr = malloc(sizeof(GNUstepWMAttributes));
  if (!*attr) {
    XFree(data);
    return False;
  }
  (*attr)->flags = data[0];
  (*attr)->window_style = data[1];
  (*attr)->window_level = data[2];
  (*attr)->reserved = data[3];
  (*attr)->miniaturize_pixmap = data[4];
  (*attr)->close_pixmap = data[5];
  (*attr)->miniaturize_mask = data[6];
  (*attr)->close_mask = data[7];
  (*attr)->extra_flags = data[8];

  XFree(data);

  return True;
}

void wPropertiesSetWMakerProtocols(Window root)
{
  // Atom protocols[3];
  Atom protocols[1];
  int count = 0;

  // protocols[count++] = w_global.atom.wmaker.menu;
  // protocols[count++] = w_global.atom.wmaker.noticeboard;
  protocols[count++] = w_global.atom.wmaker.wm_function;

  XChangeProperty(dpy, root, w_global.atom.wmaker.wm_protocols, XA_ATOM, 32, PropModeReplace,
                  (unsigned char *)protocols, count);
}

void wPropertiesSetWMName(WScreen *scr, char *name, char *class)
{
  static Atom wm_name_atom = 0;
  static Atom wm_class_atom = 0;
  static Atom wm_pid_atom = 0;
  
  if (scr->info_window == None)
    return;

  wm_name_atom = XInternAtom(dpy, "_NET_WM_NAME", False);
  XChangeProperty(dpy, scr->info_window, wm_name_atom, XA_STRING, 8, PropModeReplace,
                  (unsigned char *)name, strlen(name));
  wm_class_atom = XInternAtom(dpy, "WM_CLASS", False);
  XChangeProperty(dpy, scr->info_window, wm_class_atom, XA_STRING, 8, PropModeReplace,
                  (unsigned char *)class, strlen(class));
  wm_pid_atom = XInternAtom(dpy, "_NET_WM_PID", False);

  unsigned long pid = getpid();
  // CFLog(kCFLogLevelInfo, CFSTR("WorkspaceManager PID: %i"), pid);
  XChangeProperty(dpy, scr->info_window, wm_pid_atom, XA_CARDINAL, 32, PropModeReplace,
                  (unsigned char *)&pid, 1L);
}

#if 0
void PropSetIconTileHint(WScreen *scr, RImage *image)
{
  static Atom imageAtom = 0;
  unsigned char *tmp;
  int x, y;

  if (scr->info_window == None)
    return;

  if (!imageAtom) {
    /*
     * WIDTH, HEIGHT (16 bits, MSB First)
     * array of R,G,B,A bytes
     */
    imageAtom = XInternAtom(dpy, "_RGBA_IMAGE", False);
  }

  tmp = malloc(image->width * image->height * 4 + 4);
  if (!tmp) {
    WMLogWarning("could not allocate memory to set _WINDOWMAKER_ICON_TILE hint");
    return;
  }

  tmp[0] = image->width >> 8;
  tmp[1] = image->width & 0xff;
  tmp[2] = image->height >> 8;
  tmp[3] = image->height & 0xff;

  if (image->format == RRGBAFormat) {
    memcpy(&tmp[4], image->data, image->width * image->height * 4);
  } else {
    unsigned char *ptr = (unsigned char *)(tmp + 4);
    unsigned char *src = (unsigned char *)image->data;

    for (y = 0; y < image->height; y++) {
      for (x = 0; x < image->width; x++) {
        *ptr++ = *src++;
        *ptr++ = *src++;
        *ptr++ = *src++;
        *ptr++ = 255;
      }
    }
  }

  XChangeProperty(dpy, scr->info_window, w_global.atom.wmaker.icon_tile, imageAtom, 8,
                  PropModeReplace, tmp, image->width * image->height * 4 + 4);
  wfree(tmp);
}
#endif

Window wPropertiesGetClientLeader(Window window)
{
  Window *win;
  Window leader;

  win = (Window *)wPropertiesGetWindowProperty(window, w_global.atom.wm.client_leader, XA_WINDOW, 32, 1,
                                       NULL);

  if (!win)
    return None;

  leader = (Window)*win;
  XFree(win);

  return leader;
}

int wPropertiesGetWindowState(Window window)
{
  long *data;
  long state;

  data = (long *)wPropertiesGetWindowProperty(window, w_global.atom.wm.state, w_global.atom.wm.state, 32, 1,
                                      NULL);

  if (!data)
    return -1;

  state = *data;
  XFree(data);

  return state;
}

void wPropertiesCleanUp(Window root)
{
  // XDeleteProperty(dpy, root, w_global.atom.wmaker.noticeboard);
  XDeleteProperty(dpy, root, w_global.atom.wmaker.wm_protocols);
  XDeleteProperty(dpy, root, XA_WM_ICON_SIZE);
}
