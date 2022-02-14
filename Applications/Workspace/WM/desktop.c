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
#ifdef USE_XSHAPE
#include <X11/extensions/shape.h>
#endif

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <ctype.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>

#include <CoreFoundation/CFRunLoop.h>
#include <CoreFoundation/CFNotificationCenter.h>
#include <CoreFoundation/CFNumber.h>

#include <core/WMcore.h>
#include <core/util.h>
#include <core/log_utils.h>
#include <core/string_utils.h>

#include <core/wscreen.h>
#include <core/wevent.h>
#include <core/wcolor.h>
#include <core/drawing.h>

#include "WM.h"
#include "framewin.h"
#include "window.h"
#include "icon.h"
#include "misc.h"
#include "menu.h"
#include "application.h"
#include "dock.h"
#include "actions.h"
#include "desktop.h"
#include "appicon.h"
#include "wmspec.h"
#include "xrandr.h"
#include "event.h"
#include "iconyard.h"

#ifdef NEXTSPACE
#include <Workspace+WM.h>
#include "stacking.h"
#endif // NEXTSPACE        

#define WORKSPACE_NAME_DISPLAY_PADDING 32
/* workspace name on switch display */
#define WORKSPACE_NAME_FADE_DELAY 30
#define WORKSPACE_NAME_DELAY 400

static CFTypeRef dDesktops = CFSTR("Desktops");
static CFTypeRef dName = CFSTR("Name");

static void _postNotification(CFStringRef name, int workspace_number, void *object)
{
  CFMutableDictionaryRef info;
  CFNumberRef workspace;
  
  info = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
                                   &kCFTypeDictionaryKeyCallBacks,
                                   &kCFTypeDictionaryValueCallBacks);
  workspace = CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType, &workspace_number);
  CFDictionaryAddValue(info, CFSTR("workspace"), workspace);
  
  CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), name, object, info, TRUE);
  
  CFRelease(workspace);
  CFRelease(info);
}

typedef struct WorkspaceNameData {
  int count;
  RImage *back;
  RImage *text;
  time_t timeout;
} WorkspaceNameData;

static void _hideWorkspaceName(CFRunLoopTimerRef timer, void *data) // (void *data)
{
  WScreen *scr = (WScreen *) data;

  WMLogInfo("_hideWorkspaceName: %i (%s)", scr->workspace_name_data->count,
           dispatch_queue_get_label(dispatch_get_current_queue()));
  
  if (!scr->workspace_name_data || scr->workspace_name_data->count == 0
      /*|| time(NULL) > scr->workspace_name_data->timeout*/) {
    XUnmapWindow(dpy, scr->workspace_name);

    if (scr->workspace_name_data) {
      RReleaseImage(scr->workspace_name_data->back);
      RReleaseImage(scr->workspace_name_data->text);
      wfree(scr->workspace_name_data);

      scr->workspace_name_data = NULL;
    }
    WMDeleteTimerHandler(scr->workspace_name_timer);
    scr->workspace_name_timer = NULL;
  } else {
    RImage *img = RCloneImage(scr->workspace_name_data->back);
    Pixmap pix;

    /* scr->workspace_name_timer = WMAddTimerHandler(WORKSPACE_NAME_FADE_DELAY, 0, */
    /*                                               _hideWorkspaceName, scr); */
    
    RCombineImagesWithOpaqueness(img, scr->workspace_name_data->text,
                                 scr->workspace_name_data->count * 255 / 10);

    RConvertImage(scr->rcontext, img, &pix);

    RReleaseImage(img);

    XSetWindowBackgroundPixmap(dpy, scr->workspace_name, pix);
    XClearWindow(dpy, scr->workspace_name);
    XFreePixmap(dpy, pix);
    XFlush(dpy);

    scr->workspace_name_data->count--;
  }
}

static void _showWorkspaceName(WScreen *scr, int workspace)
{
  WorkspaceNameData *data;
  RXImage *ximg;
  Pixmap text, mask;
  int w, h;
  int px, py;
  char *name = scr->desktops[workspace]->name;
  int len = strlen(name);
  int x, y;
#ifdef USE_XRANDR
  int head;
  WMRect rect;
  int xx, yy;
#endif

  if (wPreferences.workspace_name_display_position == WD_NONE || scr->desktop_count < 2)
    return;

  if (scr->workspace_name_timer) {
    WMDeleteTimerHandler(scr->workspace_name_timer);
    XUnmapWindow(dpy, scr->workspace_name);
    XFlush(dpy);
  }
  /* scr->workspace_name_timer = WMAddTimerHandler(WORKSPACE_NAME_DELAY, 0, */
  /*                                               _hideWorkspaceName, scr); */

  if (scr->workspace_name_data) {
    RReleaseImage(scr->workspace_name_data->back);
    RReleaseImage(scr->workspace_name_data->text);
    wfree(scr->workspace_name_data);
  }

  data = wmalloc(sizeof(WorkspaceNameData));
  data->back = NULL;

  w = WMWidthOfString(scr->workspace_name_font, name, len);
  h = WMFontHeight(scr->workspace_name_font);

#ifdef USE_XRANDR
  head = wGetHeadForPointerLocation(scr);
  rect = wGetRectForHead(scr, head);
  if (scr->xrandr_info.count) {
    xx = rect.pos.x + (scr->xrandr_info.screens[head].size.width - (w + 4)) / 2;
    yy = rect.pos.y + (scr->xrandr_info.screens[head].size.height - (h + 4)) / 2;
  }
  else {
    xx = (scr->width - (w + 4)) / 2;
    yy = (scr->height - (h + 4)) / 2;
  }
#endif

  switch (wPreferences.workspace_name_display_position) {
  case WD_TOP:
#ifdef USE_XRANDR
    px = xx;
#else
    px = (scr->scr_width - (w + 4)) / 2;
#endif
    py = WORKSPACE_NAME_DISPLAY_PADDING;
    break;
  case WD_BOTTOM:
#ifdef USE_XRANDR
    px = xx;
#else
    px = (scr->scr_width - (w + 4)) / 2;
#endif
    py = scr->height - (h + 4 + WORKSPACE_NAME_DISPLAY_PADDING);
    break;
  case WD_TOPLEFT:
    px = WORKSPACE_NAME_DISPLAY_PADDING;
    py = WORKSPACE_NAME_DISPLAY_PADDING;
    break;
  case WD_TOPRIGHT:
    px = scr->width - (w + 4 + WORKSPACE_NAME_DISPLAY_PADDING);
    py = WORKSPACE_NAME_DISPLAY_PADDING;
    break;
  case WD_BOTTOMLEFT:
    px = WORKSPACE_NAME_DISPLAY_PADDING;
    py = scr->height - (h + 4 + WORKSPACE_NAME_DISPLAY_PADDING);
    break;
  case WD_BOTTOMRIGHT:
    px = scr->width - (w + 4 + WORKSPACE_NAME_DISPLAY_PADDING);
    py = scr->height - (h + 4 + WORKSPACE_NAME_DISPLAY_PADDING);
    break;
  case WD_CENTER:
  default:
#ifdef USE_XRANDR
    px = xx;
    py = yy;
#else
    px = (scr->scr_width - (w + 4)) / 2;
    py = (scr->scr_height - (h + 4)) / 2;
#endif
    break;
  }
  XResizeWindow(dpy, scr->workspace_name, w + 4, h + 4);
  XMoveWindow(dpy, scr->workspace_name, px, py);

  text = XCreatePixmap(dpy, scr->w_win, w + 4, h + 4, scr->w_depth);
  mask = XCreatePixmap(dpy, scr->w_win, w + 4, h + 4, 1);

  /* XSetForeground(dpy, scr->mono_gc, 0); */
  /* XFillRectangle(dpy, mask, scr->mono_gc, 0, 0, w+4, h+4); */

  XFillRectangle(dpy, text, WMColorGC(scr->black), 0, 0, w + 4, h + 4);

  for (x = 0; x <= 4; x++)
    for (y = 0; y <= 4; y++)
      WMDrawString(scr->wmscreen, text, scr->white, scr->workspace_name_font, x, y, name, len);

  XSetForeground(dpy, scr->mono_gc, 1);
  XSetBackground(dpy, scr->mono_gc, 0);

  XCopyPlane(dpy, text, mask, scr->mono_gc, 0, 0, w + 4, h + 4, 0, 0, 1 << (scr->w_depth - 1));

  /* XSetForeground(dpy, scr->mono_gc, 1); */
  XSetBackground(dpy, scr->mono_gc, 1);

  XFillRectangle(dpy, text, WMColorGC(scr->black), 0, 0, w + 4, h + 4);

  WMDrawString(scr->wmscreen, text, scr->white, scr->workspace_name_font, 2, 2, name, len);

#ifdef USE_XSHAPE
  if (w_global.xext.shape.supported)
    XShapeCombineMask(dpy, scr->workspace_name, ShapeBounding, 0, 0, mask, ShapeSet);
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

  ximg = RGetXImage(scr->rcontext, scr->root_win, px, py, data->text->width, data->text->height);
  if (!ximg)
    goto erro;

  XMapRaised(dpy, scr->workspace_name);
  XFlush(dpy);

  data->back = RCreateImageFromXImage(scr->rcontext, ximg->image, NULL);
  RDestroyXImage(scr->rcontext, ximg);

  if (!data->back) {
    goto erro;
  }

  data->count = 10;

  /* set a timeout for the effect */
  data->timeout = time(NULL) + 2 + (WORKSPACE_NAME_DELAY + WORKSPACE_NAME_FADE_DELAY * data->count) / 1000;

  scr->workspace_name_data = data;

  scr->workspace_name_timer = WMAddTimerHandler(WORKSPACE_NAME_DELAY,
                                                WORKSPACE_NAME_DELAY,
                                                _hideWorkspaceName, scr);
  WMLogInfo("Timer created in %s", dispatch_queue_get_label(dispatch_get_current_queue()));
  
  return;

 erro:
  if (scr->workspace_name_timer) {
    WMDeleteTimerHandler(scr->workspace_name_timer);
  }

  if (data->text)
    RReleaseImage(data->text);
  if (data->back)
    RReleaseImage(data->back);
  wfree(data);

  scr->workspace_name_data = NULL;
}

/* 
   Public namespace
*/
void wDesktopMake(WScreen *scr, int count)
{
  while (count > 0) {
    wDesktopNew(scr);
    count--;
  }
}

int wDesktopNew(WScreen *scr)
{
  WDesktop *wspace, **list;
  int i;

  if (scr->desktop_count < MAX_DESKTOPS) {
    scr->desktop_count++;

    wspace = wmalloc(sizeof(WDesktop));
    wspace->name = NULL;
    wspace->clip = NULL;
    wspace->focused_window = NULL;

    if (!wspace->name) {
      static const char *new_name = NULL;
      static size_t name_length;

      if (new_name == NULL) {
        new_name = _("Desktop %i");
        name_length = strlen(new_name) + 8;
      }
      wspace->name = wmalloc(name_length);
      snprintf(wspace->name, name_length, new_name, scr->desktop_count);
    }

    if (!wPreferences.flags.noclip)
      wspace->clip = wDockCreate(scr, WM_CLIP, NULL);

    list = wmalloc(sizeof(WDesktop *) * scr->desktop_count);

    for (i = 0; i < scr->desktop_count - 1; i++)
      list[i] = scr->desktops[i];

    list[i] = wspace;
    if (scr->desktops)
      wfree(scr->desktops);

    scr->desktops = list;

    wNETWMUpdateDesktop(scr);
    _postNotification(WMDidCreateDesktopNotification, (scr->desktop_count - 1), scr);
    XFlush(dpy);

    return scr->desktop_count - 1;
  }

  return -1;
}

Bool wDesktopDelete(WScreen *scr, int workspace)
{
  WWindow *tmp;
  WDesktop **list;
  int i, j;

  if (workspace <= 0)
    return False;

  /* verify if workspace is in use by some window */
  tmp = scr->focused_window;
  while (tmp) {
    if (!IS_OMNIPRESENT(tmp) && tmp->frame->desktop == workspace)
      return False;
    tmp = tmp->prev;
  }

  if (!wPreferences.flags.noclip) {
    wDockDestroy(scr->desktops[workspace]->clip);
    scr->desktops[workspace]->clip = NULL;
  }

  list = wmalloc(sizeof(WDesktop *) * (scr->desktop_count - 1));
  j = 0;
  for (i = 0; i < scr->desktop_count; i++) {
    if (i != workspace-1) {
      list[j++] = scr->desktops[i];
    } else {
      if (scr->desktops[i]->name)
        wfree(scr->desktops[i]->name);
      if (scr->desktops[i]->map)
        RReleaseImage(scr->desktops[i]->map);
      wfree(scr->desktops[i]);
    }
  }
  wfree(scr->desktops);
  scr->desktops = list;
  scr->desktop_count--;

  wNETWMUpdateDesktop(scr);
  
  _postNotification(WMDidDestroyDesktopNotification, (scr->desktop_count - 1), scr);
  
  if (scr->current_desktop >= scr->desktop_count)
    wDesktopChange(scr, scr->desktop_count - 1, NULL);
  if (scr->last_desktop >= scr->desktop_count)
    scr->last_desktop = 0;

  return True;
}

void wDesktopChange(WScreen *scr, int workspace, WWindow *focus_win)
{
  if (scr->flags.startup || scr->flags.startup2 || scr->flags.ignore_focus_events)
    return;

  if (workspace != scr->current_desktop)
    wDesktopForceChange(scr, workspace, focus_win);
}

void wDesktopRelativeChange(WScreen * scr, int amount)
{
  int w;

  /* While the deiconify animation is going on the window is
   * still "flying" to its final position and we don't want to
   * change workspace before the animation finishes, otherwise
   * the window will land in the new workspace */
  if (w_global.ignore_desktop_change)
    return;

  w = scr->current_desktop + amount;

  if (amount < 0) {
    if (w >= 0) {
      wDesktopChange(scr, w, NULL);
    } else if (wPreferences.ws_cycle) {
      wDesktopChange(scr, scr->desktop_count + w, NULL);
    }
  } else if (amount > 0) {
    if (w < scr->desktop_count) {
      wDesktopChange(scr, w, NULL);
    } else if (wPreferences.ws_advance) {
      wDesktopChange(scr, WMIN(w, MAX_DESKTOPS - 1), NULL);
    } else if (wPreferences.ws_cycle) {
      wDesktopChange(scr, w % scr->desktop_count, NULL);
    }
  }
}

void wDesktopSaveFocusedWindow(WScreen *scr, int workspace, WWindow *wwin)
{
  WWindow *saved_wwin;
    
  if (scr->desktops[workspace]->focused_window) {
    wrelease(scr->desktops[workspace]->focused_window);
  }

  if (wwin) {
    WMLogInfo("save focused window: %lu, %s.%s (%i x %i) to workspace %i\n",
             wwin->client_win, wwin->wm_instance, wwin->wm_class,
             wwin->old_geometry.width, wwin->old_geometry.height,
             workspace);
  
    saved_wwin = wWindowCreate();
    saved_wwin->wm_class = wstrdup(wwin->wm_class);
    saved_wwin->wm_instance = wstrdup(wwin->wm_instance);
    saved_wwin->client_win = wwin->client_win;
    
    scr->desktops[workspace]->focused_window = saved_wwin;
  }
  else {
    scr->desktops[workspace]->focused_window = NULL;
  }
}

void wDesktopForceChange(WScreen * scr, int workspace, WWindow *focus_win)
{
  WWindow *tmp, *foc = NULL;

  if (workspace >= MAX_DESKTOPS || workspace < 0 || workspace == scr->current_desktop)
    return;

  if (workspace > scr->desktop_count - 1)
    wDesktopMake(scr, workspace - scr->desktop_count + 1);

  /* save focused window to the workspace before switch */
  if (scr->focused_window
      && scr->focused_window->frame->desktop == scr->current_desktop) {
    wDesktopSaveFocusedWindow(scr, scr->current_desktop, scr->focused_window);
  }
  else {
    wDesktopSaveFocusedWindow(scr, scr->current_desktop, NULL);
  }

  scr->last_desktop = scr->current_desktop;
  scr->current_desktop = workspace;

  tmp = scr->focused_window;
  if (tmp != NULL) {
    WWindow **toUnmap;
    int toUnmapSize, toUnmapCount;
    WWindow **toMap;
    int toMapSize, toMapCount;

    toUnmapSize = 16;
    toUnmapCount = 0;
    toUnmap = wmalloc(toUnmapSize * sizeof(WWindow *));

    toMapSize = 16;
    toMapCount = 0;
    toMap = wmalloc(toMapSize * sizeof(WWindow *));
    
    while (tmp) {
      if (tmp->frame->desktop != workspace && !tmp->flags.selected) /* Unmap */ {
        /* manage unmap list */
        if (toUnmapCount == toUnmapSize) {
          toUnmapSize *= 2;
          toUnmap = wrealloc(toUnmap, toUnmapSize * sizeof(WWindow *));
        }
        
        /* unmap windows not on this workspace */
        if (!IS_OMNIPRESENT(tmp)) {
          if ((tmp->flags.mapped || tmp->flags.shaded) && !tmp->flags.changing_workspace) {
            toUnmap[toUnmapCount++] = tmp;
          }
        }
        else { // OMNIPRESENT
          /* update current workspace of omnipresent windows */
          WApplication *wapp = wApplicationOf(tmp->main_window);
          tmp->frame->desktop = workspace;
          if (wapp && WINDOW_LEVEL(tmp) != NSMainMenuWindowLevel) {
            wapp->last_desktop = workspace;
          }
        }
        /* unmap miniwindows not on this workspace */
        if (!wPreferences.sticky_icons && tmp->flags.miniaturized &&
            tmp->icon && !IS_OMNIPRESENT(tmp)) {
          XUnmapWindow(dpy, tmp->icon->core->window);
          tmp->icon->mapped = 0;
        }
      }
      else /* Map */ {
        /* manage map list */
        if (toMapCount == toMapSize) {
          toMapSize *= 2;
          toMap = wrealloc(toMap, toMapSize * sizeof(WWindow *));
        }
        
        /* change selected windows' workspace */
        if (tmp->flags.selected) {
          wWindowChangeDesktop(tmp, workspace);
          if (!tmp->flags.miniaturized && !foc) {
            foc = tmp;
          }
        }
        else {
          if (!tmp->flags.hidden) {
            if (!(tmp->flags.mapped || tmp->flags.miniaturized)) {
              /* remap windows that are on this workspace */
              toMap[toMapCount++] = tmp;
            }
            /* Also map miniwindow if not omnipresent */
            if (!wPreferences.sticky_icons &&
                tmp->flags.miniaturized && !IS_OMNIPRESENT(tmp) && tmp->icon) {
              tmp->icon->mapped = 1;
              XMapWindow(dpy, tmp->icon->core->window);
            }
          }
        }
      }
      tmp = tmp->prev;
    }

    WMLogInfo("windows to map: %i to unmap: %i\n", toMapCount, toUnmapCount);
    while (toUnmapCount > 0) {
      wWindowUnmap(toUnmap[--toUnmapCount]);
    }
    while (toMapCount > 0) {
      wWindowMap(toMap[--toMapCount]);
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

    if (focus_win) {
      foc = focus_win;
    }

    /* At this point `foc` can hold random selected window or `NULL` */
    if (!foc) {
      foc = scr->desktops[workspace]->focused_window;
      WMLogInfo("SAVED focused window for WS-%d: %lu, %s.%s\n", workspace,
               foc ? foc->client_win : 0,
               foc ? foc->wm_instance : "-",
               foc ? foc->wm_class : "-");
    }
    
    /*
     * Check that the window we want to focus still exists, because the application owning it
     * could decide to unmap/destroy it in response to unmap any of its other window following
     * the workspace change, this happening during our 'ProcessPendingEvents' loop.
     */
    if (foc != NULL) {
      WWindow *parse;
      Bool found;

      found = False;
      for (parse = scr->focused_window; parse != NULL; parse = parse->prev) {
        if (parse->client_win == foc->client_win) {
          found = True;
          foc = parse;
          break;
        }
      }
      if (!found)
        foc = NULL;
    }

    if (foc) {
      /* Mapped window found earlier. */
      WMLogInfo("NEW focused window after CHECK: %lu, %s.%s (%i x %i)\n",
               foc->client_win, foc->wm_instance, foc->wm_class,
               foc->old_geometry.width, foc->old_geometry.height);
      if (foc->flags.hidden) {
        foc = NULL;
      }
    }
    wSetFocusTo(scr, foc);
      
    wfree(toUnmap);
    wfree(toMap);
  }

  /* We need to always arrange icons when changing workspace, even if
   * no autoarrange icons, because else the icons in different desktops
   * can be superposed.
   * This can be avoided if appicons are also workspace specific.
   */
  if (!wPreferences.sticky_icons) {
    wArrangeIcons(scr, False);
  }
  if (scr->dock) {
    wAppIconPaint(scr->dock->icon_array[0]);
  }
  wScreenUpdateUsableArea(scr);
  wNETWMUpdateDesktop(scr);
  _showWorkspaceName(scr, workspace);

  /* Workspace switch completed */
  scr->last_desktop = workspace;

  _postNotification(WMDidChangeDesktopNotification, workspace, scr);

  XSync(dpy, False);
}

void wDesktopRename(WScreen *scr, int workspace, const char *name)
{
  char buf[MAX_DESKTOPNAME_WIDTH + 1];
  char *tmp;

  if (workspace >= scr->desktop_count)
    return;

  /* trim white spaces */
  tmp = wtrimspace(name);

  if (strlen(tmp) == 0) {
    snprintf(buf, sizeof(buf), _("Workspace %i"), workspace + 1);
  } else {
    strncpy(buf, tmp, MAX_DESKTOPNAME_WIDTH);
  }
  buf[MAX_DESKTOPNAME_WIDTH] = 0;
  wfree(tmp);

  /* update workspace */
  wfree(scr->desktops[workspace]->name);
  scr->desktops[workspace]->name = wstrdup(buf);

  _postNotification(WMDidChangeDesktopNameNotification, workspace, scr);
}

void wDesktopSaveState(WScreen *scr)
{
  CFMutableArrayRef parr;
  CFMutableDictionaryRef wks_state;
  CFStringRef pstr;
  int i = 0;

  parr = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
  for (i = 0; i < scr->desktop_count; i++) {
    wks_state = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
                                          &kCFTypeDictionaryKeyCallBacks,
                                          &kCFTypeDictionaryValueCallBacks);
    pstr = CFStringCreateWithCString(kCFAllocatorDefault, scr->desktops[i]->name,
                                     kCFStringEncodingUTF8);
    CFDictionarySetValue(wks_state, dName, pstr);
    CFRelease(pstr);
    
    CFArrayAppendValue(parr, wks_state);
    CFRelease(wks_state);
  }
  CFDictionarySetValue(scr->session_state, dDesktops, parr);
  CFRelease(parr);
}

void wDesktopRestoreState(WScreen *scr)
{
  CFTypeRef parr, wks_state, pstr;

  if (scr->session_state == NULL)
    return;

  parr = CFDictionaryGetValue(scr->session_state, dDesktops);

  if (!parr)
    return;

  for (int i = 0; i < WMIN(CFArrayGetCount(parr), MAX_DESKTOPS); i++) {
    wks_state = CFArrayGetValueAtIndex(parr, i);
    if (CFGetTypeID(wks_state) == CFDictionaryGetTypeID()) {
      pstr = CFDictionaryGetValue(wks_state, dName);
    } else {
      pstr = wks_state;
    }
    if (i >= scr->desktop_count) {
      wDesktopNew(scr);
    }

    wfree(scr->desktops[i]->name);
    scr->desktops[i]->name = wstrdup(CFStringGetCStringPtr(pstr, kCFStringEncodingUTF8));

    _postNotification(WMDidChangeDesktopNameNotification, i, scr);
  }
}

/* Returns the workspace number for a given workspace name */
int wGetDesktopNumber(WScreen *scr, const char *value)
{
  int w, i;

  if (sscanf(value, "%i", &w) != 1) {
    w = -1;
    for (i = 0; i < scr->desktop_count; i++) {
      if (strcmp(scr->desktops[i]->name, value) == 0) {
        w = i;
        break;
      }
    }
  } else {
    w--;
  }

  return w;
}
