/* window.c - client window managing stuffs
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
#ifdef USE_XSHAPE
#include <X11/extensions/shape.h>
#endif
#ifdef KEEP_XKB_LOCK_STATUS
#include <X11/XKBlib.h>
#endif	  /* KEEP_XKB_LOCK_STATUS */
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

/* For getting mouse wheel mappings from WINGs */
#include <WINGs/WINGs.h>
#include <WINGs/notification.h>
#include <WINGs/configuration.h>

#include "GNUstep.h"
#include "WindowMaker.h"
#include "wcore.h"
#include "framewin.h"
#include "texture.h"
#include "window.h"
#include "icon.h"
#include "properties.h"
#include "actions.h"
#include "client.h"
#include "colormap.h"
#include "keybind.h"
#include "stacking.h"
#include "defaults.h"
#include "workspace.h"
#include "xrandr.h"
#include "appicon.h"
#include "superfluous.h"
#include "placement.h"
#include "misc.h"
#include "startup.h"
#include "winmenu.h"
#include "osdep.h"

#ifdef USE_MWM_HINTS
# include "motif.h"
#endif
#include "wmspec.h"

#ifdef NEXTSPACE
#include <Workspace+WM.h>
#endif

#define MOD_MASK wPreferences.modifier_mask
#define ALT_MOD_MASK wPreferences.alt_modifier_mask


/***** Local Stuff *****/
static WWindowState *windowState = NULL;
static int getSavedState(Window window, WSavedState **state);
static void setupGNUstepHints(WWindow *wwin, GNUstepWMAttributes *gs_hints);

/* frame window (during window grabs) */
static void frameMouseDown(WObjDescriptor *desc, XEvent *event);

/* close button */
static void windowCloseClick(WCoreWindow *sender, void *data, XEvent *event);
static void windowCloseDblClick(WCoreWindow *sender, void *data, XEvent *event);

/* iconify button */
static void windowIconifyClick(WCoreWindow *sender, void *data, XEvent *event);

#ifdef XKB_BUTTON_HINT
static void windowLanguageClick(WCoreWindow *sender, void *data, XEvent *event);
#endif

static void titlebarMouseDown(WCoreWindow *sender, void *data, XEvent *event);
static void titlebarDblClick(WCoreWindow *sender, void *data, XEvent *event);
static void resizebarMouseDown(WCoreWindow *sender, void *data, XEvent *event);

static void release_wwindowstate(WWindowState *wstate);

/****** Notification Observers ******/

static void appearanceObserver(void *self, WMNotification * notif)
{
  WWindow *wwin = (WWindow *) self;
  uintptr_t flags = (uintptr_t)WMGetNotificationClientData(notif);

  if (!wwin->frame || (!wwin->frame->titlebar && !wwin->frame->resizebar))
    return;

  if (flags & WFontSettings) {
    wWindowConfigureBorders(wwin);
    if (wwin->flags.shaded) {
      wFrameWindowResize(wwin->frame, wwin->frame->core->width, wwin->frame->top_width - 1);
      wwin->client.y = wwin->frame_y - wwin->client.height + wwin->frame->top_width;
      wWindowSynthConfigureNotify(wwin);
    }
  }
  if (flags & WTextureSettings)
    wwin->frame->flags.need_texture_remake = 1;

  if (flags & (WTextureSettings | WColorSettings)) {
    if (wwin->frame->titlebar)
      XClearWindow(dpy, wwin->frame->titlebar->window);

    wFrameWindowPaint(wwin->frame);
  }
}


/* Return the WWindow associated with a given (Xlib) Window. */
WWindow *wWindowFor(Window window)
{
  WObjDescriptor *desc;

  if (window == None)
    return NULL;

  if (XFindContext(dpy, window, w_global.context.client_win, (XPointer *) & desc) == XCNOENT)
    return NULL;

  if (desc->parent_type == WCLASS_WINDOW)
    return desc->parent;
  else if (desc->parent_type == WCLASS_FRAME) {
    WFrameWindow *frame = (WFrameWindow *) desc->parent;
    if (frame->flags.is_client_window_frame)
      return frame->child;
  }

  return NULL;
}

WWindow *wWindowCreate(void)
{
  WWindow *wwin;

  wwin = wmalloc(sizeof(WWindow));
  wretain(wwin);

  wwin->client_descriptor.handle_mousedown = frameMouseDown;
  wwin->client_descriptor.parent = wwin;
  wwin->client_descriptor.self = wwin;
  wwin->client_descriptor.parent_type = WCLASS_WINDOW;

  return wwin;
}

void wWindowDestroy(WWindow *wwin)
{
  int i;

  if (wwin->screen_ptr->cmap_window == wwin)
    wwin->screen_ptr->cmap_window = NULL;

  WMRemoveNotificationObserver(wwin);

  wwin->flags.destroyed = 1;

  for (i = 0; i < MAX_WINDOW_SHORTCUTS; i++) {
    if (!wwin->screen_ptr->shortcutWindows[i])
      continue;

    WMRemoveFromArray(wwin->screen_ptr->shortcutWindows[i], wwin);

    if (!WMGetArrayItemCount(wwin->screen_ptr->shortcutWindows[i])) {
      WMFreeArray(wwin->screen_ptr->shortcutWindows[i]);
      wwin->screen_ptr->shortcutWindows[i] = NULL;
    }
  }

  if (wwin->fake_group && wwin->fake_group->retainCount > 0) {
    wwin->fake_group->retainCount--;
    if (wwin->fake_group->retainCount == 0 && wwin->fake_group->leader != None) {
      XDestroyWindow(dpy, wwin->fake_group->leader);
      wwin->fake_group->leader = None;
      wwin->fake_group->origLeader = None;
      XFlush(dpy);
    }
  }

  if (wwin->normal_hints)
    XFree(wwin->normal_hints);

  if (wwin->wm_hints)
    XFree(wwin->wm_hints);

  if (wwin->wm_instance)
    XFree(wwin->wm_instance);

  if (wwin->wm_class)
    XFree(wwin->wm_class);

  if (wwin->wm_gnustep_attr)
    wfree(wwin->wm_gnustep_attr);

  if (wwin->cmap_windows)
    XFree(wwin->cmap_windows);

  XDeleteContext(dpy, wwin->client_win, w_global.context.client_win);

  if (wwin->frame)
    wFrameWindowDestroy(wwin->frame);

  if (wwin->icon) {
    RemoveFromStackList(wwin->icon->core);
    wIconDestroy(wwin->icon);
    if (wPreferences.auto_arrange_icons)
      wArrangeIcons(wwin->screen_ptr, True);
  }
  if (wwin->net_icon_image)
    RReleaseImage(wwin->net_icon_image);

  wrelease(wwin);
}

static void setupGNUstepHints(WWindow *wwin, GNUstepWMAttributes *gs_hints)
{
  if (gs_hints->flags & GSWindowStyleAttr) {
    if (gs_hints->window_style == NSBorderlessWindowMask) {
      wwin->client_flags.no_border = 1;
      wwin->client_flags.no_titlebar = 1;
      wwin->client_flags.no_closable = 1;
      wwin->client_flags.no_miniaturizable = 1;
      wwin->client_flags.no_resizable = 1;
      wwin->client_flags.no_close_button = 1;
      wwin->client_flags.no_miniaturize_button = 1;
      wwin->client_flags.no_resizebar = 1;
    } else {
      wwin->client_flags.no_close_button =
        ((gs_hints->window_style & NSClosableWindowMask) ? 0 : 1);

      wwin->client_flags.no_closable = ((gs_hints->window_style & NSClosableWindowMask) ? 0 : 1);

      wwin->client_flags.no_miniaturize_button =
        ((gs_hints->window_style & NSMiniaturizableWindowMask) ? 0 : 1);

      wwin->client_flags.no_miniaturizable = wwin->client_flags.no_miniaturize_button;

      wwin->client_flags.no_resizebar =
        ((gs_hints->window_style & NSResizableWindowMask) ? 0 : 1);

      wwin->client_flags.no_resizable = wwin->client_flags.no_resizebar;

      /* these attributes supposedly imply in the existence
       * of a titlebar */
      if (gs_hints->window_style & (NSResizableWindowMask |
                                    NSClosableWindowMask | NSMiniaturizableWindowMask)) {
        wwin->client_flags.no_titlebar = 0;
      } else {
        wwin->client_flags.no_titlebar =
          ((gs_hints->window_style & NSTitledWindowMask) ? 0 : 1);
      }

    }
  } else {
    /* setup the defaults */
    wwin->client_flags.no_border = 0;
    wwin->client_flags.no_titlebar = 0;
    wwin->client_flags.no_closable = 0;
    wwin->client_flags.no_miniaturizable = 0;
    wwin->client_flags.no_resizable = 0;
    wwin->client_flags.no_close_button = 0;
    wwin->client_flags.no_miniaturize_button = 0;
    wwin->client_flags.no_resizebar = 0;
  }
  if (gs_hints->extra_flags & GSNoApplicationIconFlag)
    wwin->client_flags.no_appicon = 1;
}

static void discard_hints_from_gtk(WWindow *wwin)
{
  Atom type;
  int format;
  unsigned long nb_item, nb_remain;
  unsigned char *result;
  int status;

  status = XGetWindowProperty(dpy, wwin->client_win, w_global.atom.desktop.gtk_object_path, 0, 16, False,
                              AnyPropertyType, &type, &format, &nb_item, &nb_remain, &result);
  if (status != Success)
    return;

  /* If we're here, that means the Property exists. We don't care what is inside, it means it is a GTK-based application */

  if (result != NULL)
    XFree(result);

  /* GTK is asking to remove these decorations: */
  wwin->client_flags.no_titlebar = 0;
  wwin->client_flags.no_close_button = 0;
  wwin->client_flags.no_miniaturize_button = 0;
  wwin->client_flags.no_resizebar = 0;
}

void wWindowSetupInitialAttributes(WWindow *wwin, int *level, int *workspace)
{
  WScreen *scr = wwin->screen_ptr;

  /* set some default values if WMWindowAttributes doesn't exist */
  wwin->client_flags.shared_appicon = 1;
  
  /* sets global default stuff - read from WMWindowAttributes*/
  wDefaultFillAttributes(wwin->wm_instance, wwin->wm_class, &wwin->user_flags, NULL, True);
  wwin->defined_user_flags = wwin->user_flags;

  /*
   * Decoration setting is done in this precedence (lower to higher)
   * - use global default in the resource database
   * - guess some settings
   * - use GNUstep/external window attributes
   * - set hints specified for the app in the resource DB
   *
   */
  wwin->client_flags.broken_close = 0;

  if (wwin->protocols.DELETE_WINDOW)
    wwin->client_flags.kill_close = 0;
  else
    wwin->client_flags.kill_close = 1;

  /* transients can't be iconified or maximized */
  if (wwin->transient_for != None && wwin->transient_for != scr->root_win) {
    wwin->client_flags.no_miniaturizable = 1;
    wwin->client_flags.no_miniaturize_button = 1;
  }

  /* if the window can't be resized, remove the resizebar */
  if (wwin->normal_hints->flags & (PMinSize | PMaxSize)
      && (wwin->normal_hints->min_width == wwin->normal_hints->max_width)
      && (wwin->normal_hints->min_height == wwin->normal_hints->max_height)) {
    wwin->client_flags.no_resizable = 1;
    wwin->client_flags.no_resizebar = 1;
  }

  /* set GNUstep window attributes */
  if (wwin->wm_gnustep_attr) {
    setupGNUstepHints(wwin, wwin->wm_gnustep_attr);

    if (wwin->wm_gnustep_attr->flags & GSWindowLevelAttr) {

      *level = wwin->wm_gnustep_attr->window_level;
      /*
       * INT_MIN is the only illegal window level.
       */
      if (*level == INT_MIN)
        *level = INT_MIN + 1;
    } else {
      /* setup defaults */
      *level = NSNormalWindowLevel;
    }
  } else {
    int tmp_workspace = -1;
    int tmp_level = INT_MIN;	/* INT_MIN is never used by the window levels */

#ifdef USE_MWM_HINTS
    wMWMCheckClientHints(wwin);
#endif	/* USE_MWM_HINTS */

    wNETWMCheckClientHints(wwin, &tmp_level, &tmp_workspace);

    if (wPreferences.ignore_gtk_decoration_hints)
      discard_hints_from_gtk(wwin);

    /* window levels are between INT_MIN+1 and INT_MAX, so if we still
     * have INT_MIN that means that no window level was requested. -Dan
     */
    if (tmp_level == INT_MIN) {
      if (WFLAGP(wwin, floating))
        *level = NSFloatingWindowLevel;
      /* else if (WFLAGP(wwin, sunken)) */
      /*   *level = WMSunkenLevel; */
      else
        *level = NSNormalWindowLevel;
    } else {
      *level = tmp_level;
    }

    if (wwin->transient_for != None && wwin->transient_for != scr->root_win) {
      WWindow *transientOwner = wWindowFor(wwin->transient_for);
      if (transientOwner) {
        int ownerLevel = transientOwner->frame->core->stacking->window_level;
        if (ownerLevel > *level)
          *level = ownerLevel;
      }
    }

    if (tmp_workspace >= 0)
      *workspace = tmp_workspace % scr->workspace_count;
  }

  /*
   * Set attributes specified only for that window/class.
   * This might do duplicate work with the 1st wDefaultFillAttributes().
   */
  wDefaultFillAttributes(wwin->wm_instance, wwin->wm_class, &wwin->user_flags,
                         &wwin->defined_user_flags, False);
  /*
   * Sanity checks for attributes that depend on other attributes
   */
  if (wwin->user_flags.no_appicon && wwin->defined_user_flags.no_appicon)
    wwin->user_flags.emulate_appicon = 0;

  if (wwin->main_window != None) {
    WApplication *wapp = wApplicationOf(wwin->main_window);
    if (wapp && !wapp->flags.emulated)
      wwin->user_flags.emulate_appicon = 0;
  }

  if (wwin->transient_for != None && wwin->transient_for != wwin->screen_ptr->root_win)
    wwin->user_flags.emulate_appicon = 0;

  if (wwin->user_flags.sunken && wwin->defined_user_flags.sunken
      && wwin->user_flags.floating && wwin->defined_user_flags.floating)
    wwin->user_flags.sunken = 0;

  /* A window that does not have a title cannot be Shaded and we don't let user override this */
  wwin->client_flags.no_shadeable = WFLAGP(wwin, no_titlebar);
  wwin->defined_user_flags.no_shadeable = 0;

  /* windows that have takefocus=False shouldn't take focus at all */
  if (wwin->focus_mode == WFM_NO_INPUT)
    wwin->client_flags.no_focusable = 1;
}

Bool wWindowObscuresWindow(WWindow *wwin, WWindow *obscured)
{
  int w1, h1, w2, h2;

  w1 = wwin->frame->core->width;
  h1 = wwin->frame->core->height;
  w2 = obscured->frame->core->width;
  h2 = obscured->frame->core->height;

  if (!IS_OMNIPRESENT(wwin) && !IS_OMNIPRESENT(obscured)
      && wwin->frame->workspace != obscured->frame->workspace)
    return False;

  if (wwin->frame_x + w1 < obscured->frame_x
      || wwin->frame_y + h1 < obscured->frame_y
      || wwin->frame_x > obscured->frame_x + w2 || wwin->frame_y > obscured->frame_y + h2)
    return False;

  return True;
}

static void fixLeaderProperties(WWindow *wwin)
{
  XClassHint *classHint;
  XWMHints *hints, *clientHints;
  XWindowAttributes attr;
  Window leaders[2], window;
  char **argv, *command;
  int argc, i, pid;
  Bool haveCommand;

  classHint = XAllocClassHint();
  clientHints = XGetWMHints(dpy, wwin->client_win);
  pid = wNETWMGetPidForWindow(wwin->client_win);
  if (pid > 0)
    haveCommand = GetCommandForPid(pid, &argv, &argc);
  else
    haveCommand = False;

  leaders[0] = wwin->client_leader;
  leaders[1] = wwin->group_id;

  if (haveCommand) {
    command = GetCommandForWindow(wwin->client_win);
    if (command)
      wfree(command); /* command already set. nothing to do. */
    else
      XSetCommand(dpy, wwin->client_win, argv, argc);
  }

  for (i = 0; i < 2; i++) {
    window = leaders[i];
    if (window) {
      if (XGetClassHint(dpy, window, classHint) == 0) {
        classHint->res_name = wwin->wm_instance;
        classHint->res_class = wwin->wm_class;
        XSetClassHint(dpy, window, classHint);
      }
      hints = XGetWMHints(dpy, window);
      if (hints) {
        XFree(hints);
      } else if (clientHints) {
        /* set window group leader to self */
        clientHints->window_group = window;
        clientHints->flags |= WindowGroupHint;
        XSetWMHints(dpy, window, clientHints);
      }

      if (haveCommand) {
        command = GetCommandForWindow(window);
        if (command)
          wfree(command); /* command already set. nothing to do. */
        else
          XSetCommand(dpy, window, argv, argc);
      }

      /* Make sure we get notification when this window is destroyed */
      if (XGetWindowAttributes(dpy, window, &attr))
        XSelectInput(dpy, window, attr.your_event_mask | StructureNotifyMask | PropertyChangeMask);
    }
  }

  XFree(classHint);
  if (clientHints)
    XFree(clientHints);
  if (haveCommand)
    wfree(argv);
}

static Window createFakeWindowGroupLeader(WScreen *scr, Window win, char *instance, char *class)
{
  XClassHint *classHint;
  XWMHints *hints;
  Window leader;
  int argc;
  char **argv;

  leader = XCreateSimpleWindow(dpy, scr->root_win, 10, 10, 10, 10, 0, 0, 0);
  /* set class hint */
  classHint = XAllocClassHint();
  classHint->res_name = instance;
  classHint->res_class = class;
  XSetClassHint(dpy, leader, classHint);
  XFree(classHint);

  /* inherit these from the original leader if available */
  hints = XGetWMHints(dpy, win);
  if (!hints) {
    hints = XAllocWMHints();
    hints->flags = 0;
  }
  /* set window group leader to self */
  hints->window_group = leader;
  hints->flags |= WindowGroupHint;
  XSetWMHints(dpy, leader, hints);
  XFree(hints);

  if (XGetCommand(dpy, win, &argv, &argc) != 0 && argc > 0) {
    XSetCommand(dpy, leader, argv, argc);
    XFreeStringList(argv);
  }

  return leader;
}

static int matchIdentifier(const void *item, const void *cdata)
{
  return (strcmp(((WFakeGroupLeader *) item)->identifier, (char *)cdata) == 0);
}

/*
 *----------------------------------------------------------------
 * wManageWindow--
 * 	reparents the window and allocates a descriptor for it.
 * Window manager hints and other hints are fetched to configure
 * the window decoration attributes and others. User preferences
 * for the window are used if available, to configure window
 * decorations and some behaviour.
 * 	If in startup, windows that are override redirect,
 * unmapped and never were managed and are Withdrawn are not
 * managed.
 *
 * Returns:
 * 	the new window descriptor
 *
 * Side effects:
 * 	The window is reparented and appropriate notification
 * is done to the client. Input mask for the window is setup.
 * 	The window descriptor is also associated with various window
 * contexts and inserted in the head of the window list.
 * Event handler contexts are associated for some objects
 * (buttons, titlebar and resizebar)
 *
 *----------------------------------------------------------------
 */
WWindow *wManageWindow(WScreen *scr, Window window)
{
  WWindow *wwin;
  int x, y;
  unsigned width, height;
  XWindowAttributes wattribs;
  XSetWindowAttributes attribs;
  WWindowState *win_state;
  WWindow *transientOwner = NULL;
  int window_level;
  int wm_state;
  int foo;
  int workspace = -1;
  char *title;
  Bool withdraw = False;
  Bool raise = False;

  /* wmessage("[window.c] will manage window:%lu\n", window); */

  /* mutex. */
  XGrabServer(dpy);
  XSync(dpy, False);

  /* make sure the window is still there */
  if (!XGetWindowAttributes(dpy, window, &wattribs)) {
    XUngrabServer(dpy);
    return NULL;
  }

  /* if it's an override-redirect, ignore it */
  if (wattribs.override_redirect) {
    XUngrabServer(dpy);
    return NULL;
  }

  wm_state = PropGetWindowState(window);

  /* if it's startup and the window is unmapped, don't manage it */
  if (scr->flags.startup && wm_state < 0 && wattribs.map_state == IsUnmapped) {
    XUngrabServer(dpy);
    return NULL;
  }

  wwin = wWindowCreate();

  title = wNETWMGetWindowName(window);
  if (title)
    wwin->flags.net_has_title = 1;
  else if (!wFetchName(dpy, window, &title))
    title = NULL;

  XSaveContext(dpy, window, w_global.context.client_win, (XPointer) & wwin->client_descriptor);

#ifdef USE_XSHAPE
  if (w_global.xext.shape.supported) {
    int junk;
    unsigned int ujunk;
    int b_shaped;

    XShapeSelectInput(dpy, window, ShapeNotifyMask);
    XShapeQueryExtents(dpy, window, &b_shaped, &junk, &junk, &ujunk,
                       &ujunk, &junk, &junk, &junk, &ujunk, &ujunk);
    wwin->flags.shaped = b_shaped;
  }
#endif

  /* Get hints and other information in properties */
  PropGetWMClass(window, &wwin->wm_class, &wwin->wm_instance);

  /* setup descriptor */
  wwin->client_win = window;
  wwin->screen_ptr = scr;
  wwin->old_border_width = wattribs.border_width;
  wwin->event_mask = CLIENT_EVENTS;
  attribs.event_mask = CLIENT_EVENTS;
  attribs.do_not_propagate_mask = ButtonPressMask | ButtonReleaseMask;
  attribs.save_under = False;

  XChangeWindowAttributes(dpy, window, CWEventMask | CWDontPropagate | CWSaveUnder, &attribs);
  XSetWindowBorderWidth(dpy, window, 0);

  /* get hints from GNUstep app */
  if (wwin->wm_class != NULL && strcmp(wwin->wm_class, "GNUstep") == 0)
    wwin->flags.is_gnustep = 1;

  if (!PropGetGNUstepWMAttr(window, &wwin->wm_gnustep_attr))
    wwin->wm_gnustep_attr = NULL;

  if (wwin->wm_class != NULL && strcmp(wwin->wm_class, "DockApp") == 0) {
    wwin->flags.is_dockapp = 1;
    withdraw = True;
  }

  wwin->client_leader = PropGetClientLeader(window);
  if (wwin->client_leader != None)
    wwin->main_window = wwin->client_leader;

  wwin->wm_hints = XGetWMHints(dpy, window);

  if (wwin->wm_hints) {
    if (wwin->wm_hints->flags & StateHint) {
      if (wwin->wm_hints->initial_state == IconicState) {
        wwin->flags.miniaturized = 1;
      } else if (wwin->wm_hints->initial_state == WithdrawnState) {
        wwin->flags.is_dockapp = 1;
        withdraw = True;
      }
    }

    if (wwin->wm_hints->flags & WindowGroupHint) {
      wwin->group_id = wwin->wm_hints->window_group;
      /* window_group has priority over CLIENT_LEADER */
      wwin->main_window = wwin->group_id;
    } else {
      wwin->group_id = None;
    }

    if (wwin->wm_hints->flags & UrgencyHint) {
      wwin->flags.urgent = 1;
      wAppBounceWhileUrgent(wApplicationOf(wwin->main_window));
    }
  } else {
    wwin->group_id = None;
  }

  PropGetProtocols(window, &wwin->protocols);

  if (!XGetTransientForHint(dpy, window, &wwin->transient_for)) {
    wwin->transient_for = None;
  } else {
    if (wwin->transient_for == None || wwin->transient_for == window) {
      wwin->transient_for = scr->root_win;
    } else {
      transientOwner = wWindowFor(wwin->transient_for);
      if (transientOwner && transientOwner->main_window != None)
        wwin->main_window = transientOwner->main_window;
    }
  }

  /* guess the focus mode */
  wwin->focus_mode = GetFocusMode(wwin);

  /* get geometry stuff */
  wClientGetNormalHints(wwin, &wattribs, True, &x, &y, &width, &height);

  /* get colormap windows */
  GetColormapWindows(wwin);

  /*
   * Setup the decoration/window attributes and
   * geometry
   */
  wWindowSetupInitialAttributes(wwin, &window_level, &workspace);

  /* Make broken apps behave as a nice app. */
  /* if (WFLAGP(wwin, emulate_appicon)) */
  if (wwin->main_window == None) {
    WApplication *wapp = wApplicationWithName(scr, wwin->wm_instance);
    if (!wapp)
      wwin->main_window = wwin->client_win;
    else
      wwin->main_window = wapp->main_window;
    WSETUFLAG(wwin, emulate_appicon, 1);
    WSETUFLAG(wwin, shared_appicon, 1);
  }

  fixLeaderProperties(wwin);

  wwin->orig_main_window = wwin->main_window;

  if (wwin->flags.is_gnustep)
    wwin->client_flags.shared_appicon = 0;

  if (wwin->flags.is_dockapp)
    wwin->client_flags.shared_appicon = 0;

  if (wwin->main_window) {
    WApplication *app = wApplicationOf(wwin->main_window);
    if (app && app->app_icon)
      wwin->client_flags.shared_appicon = 0;
  }

  if (!withdraw && wwin->main_window && WFLAGP(wwin, shared_appicon)) {
    char *buffer, *instance, *class;
    WFakeGroupLeader *fPtr;
    int index;

#define ADEQUATE(x) ((x)!=None && (x)!=wwin->client_win && (x)!=fPtr->leader)

    /* // only enter here if PropGetWMClass() succeds */
    PropGetWMClass(wwin->main_window, &class, &instance);
    buffer = StrConcatDot(instance, class);

    index = WMFindInArray(scr->fakeGroupLeaders, matchIdentifier, (void *)buffer);
    if (index != WANotFound) {
      fPtr = WMGetFromArray(scr->fakeGroupLeaders, index);
      if (fPtr->retainCount == 0)
        fPtr->leader = createFakeWindowGroupLeader(scr, wwin->main_window,
                                                   instance, class);

      fPtr->retainCount++;
      if (fPtr->origLeader == None) {
        if (ADEQUATE(wwin->main_window)) {
          fPtr->retainCount++;
          fPtr->origLeader = wwin->main_window;
        }
      }
      wwin->fake_group = fPtr;
      wwin->main_window = fPtr->leader;
      wfree(buffer);
    } else {
      fPtr = (WFakeGroupLeader *) wmalloc(sizeof(WFakeGroupLeader));

      fPtr->identifier = buffer;
      fPtr->leader = createFakeWindowGroupLeader(scr, wwin->main_window, instance, class);
      fPtr->origLeader = None;
      fPtr->retainCount = 1;

      WMAddToArray(scr->fakeGroupLeaders, fPtr);

      if (ADEQUATE(wwin->main_window)) {
        fPtr->retainCount++;
        fPtr->origLeader = wwin->main_window;
      }
      wwin->fake_group = fPtr;
      wwin->main_window = fPtr->leader;
    }

    if (instance)
      free(instance);

    if (class)
      free(class);
#undef ADEQUATE
  }

  /*
   * Setup the initial state of the window
   */
  if (WFLAGP(wwin, start_miniaturized) && !WFLAGP(wwin, no_miniaturizable))
    wwin->flags.miniaturized = 1;

  if (WFLAGP(wwin, start_maximized) && IS_RESIZABLE(wwin))
    wwin->flags.maximized = MAX_VERTICAL | MAX_HORIZONTAL;

  // TODO: for GNUstep applications with `cairo` backend this code shows
  // flickering app appicon. Without calling this code bad side effects
  // occure - main menu appears in window list, menu-only app has no icon
  // in switch panel, etc.
  // wNETWMCheckInitialClientState() need to inspected.
  wNETWMCheckInitialClientState(wwin);

  /* apply previous state if it exists and we're in startup */
  if (scr->flags.startup && wm_state >= 0) {
    if (wm_state == IconicState)
      wwin->flags.miniaturized = 1;
    else if (wm_state == WithdrawnState)
      withdraw = True;
  }

  /* if there is a saved state (from file), restore it */
  win_state = NULL;
  if (wwin->main_window != None)
    win_state = (WWindowState *) wWindowGetSavedState(wwin->main_window);
  else
    win_state = (WWindowState *) wWindowGetSavedState(window);

  if (win_state && !withdraw) {
    if (win_state->state->hidden > 0)
      wwin->flags.hidden = win_state->state->hidden;

    if (win_state->state->shaded > 0 && !WFLAGP(wwin, no_shadeable))
      wwin->flags.shaded = win_state->state->shaded;

    if (win_state->state->miniaturized > 0 && !WFLAGP(wwin, no_miniaturizable))
      wwin->flags.miniaturized = win_state->state->miniaturized;

    if (!IS_OMNIPRESENT(wwin)) {
      int w = wDefaultGetStartWorkspace(scr, wwin->wm_instance,
                                        wwin->wm_class);
      if (w < 0 || w >= scr->workspace_count) {
        workspace = win_state->state->workspace;
        if (workspace >= scr->workspace_count)
          workspace = scr->current_workspace;
      } else {
        workspace = w;
      }
    } else {
      workspace = scr->current_workspace;
    }
  }

  /* if we're restarting, restore saved state (from hints).
   * This will overwrite previous */
  {
    WSavedState *wstate;

    if (getSavedState(window, &wstate)) {
      wwin->flags.shaded = wstate->shaded;
      wwin->flags.hidden = wstate->hidden;
      wwin->flags.miniaturized = wstate->miniaturized;
      wwin->flags.maximized = wstate->maximized;
      if (wwin->flags.maximized) {
        wwin->old_geometry.x = wstate->x;
        wwin->old_geometry.y = wstate->y;
        wwin->old_geometry.width = wstate->w;
        wwin->old_geometry.height = wstate->h;
      }

      workspace = wstate->workspace;
    } else {
      wstate = NULL;
    }

    /* restore window shortcut */
    if (wstate != NULL || win_state != NULL) {
      unsigned mask = 0;

      if (win_state != NULL)
        mask = win_state->state->window_shortcuts;

      if (wstate != NULL && mask == 0)
        mask = wstate->window_shortcuts;

      if (mask > 0) {
        int i;

        for (i = 0; i < MAX_WINDOW_SHORTCUTS; i++) {
          if (mask & (1 << i)) {
            if (!scr->shortcutWindows[i])
              scr->shortcutWindows[i] = WMCreateArray(4);

            WMAddToArray(scr->shortcutWindows[i], wwin);
          }
        }
      }
    }

    if (wstate != NULL)
      wfree(wstate);
  }

  /* don't let transients start miniaturized if their owners are not */
  if (transientOwner && !transientOwner->flags.miniaturized && wwin->flags.miniaturized && !withdraw) {
    wwin->flags.miniaturized = 0;
    if (wwin->wm_hints)
      wwin->wm_hints->initial_state = NormalState;
  }

  /* set workspace on which the window starts */
  if (workspace >= 0) {
    if (workspace > scr->workspace_count - 1)
      workspace = workspace % scr->workspace_count;
  } else {
    int w;

    w = wDefaultGetStartWorkspace(scr, wwin->wm_instance, wwin->wm_class);

    if (w >= 0 && w < scr->workspace_count && !(IS_OMNIPRESENT(wwin))) {
      workspace = w;
    } else {
      if (wPreferences.open_transients_with_parent && transientOwner)
        workspace = transientOwner->frame->workspace;
      else
        workspace = scr->current_workspace;
    }
  }

  /* setup window geometry */
  if (win_state && win_state->state->w > 0) {
    width = win_state->state->w;
    height = win_state->state->h;
  }

  wWindowConstrainSize(wwin, &width, &height);

  /* do not ask for window placement if the window is
   * transient, during startup, if the initial workspace is another one
   * or if the window wants to start iconic.
   * If geometry was saved, restore it. */
  {
    Bool dontBring = False;

    if (win_state && win_state->state->w > 0) {
      x = win_state->state->x;
      y = win_state->state->y;
    } else if ((wwin->transient_for == None || wPreferences.window_placement != WPM_MANUAL)
               && !scr->flags.startup
               && workspace == scr->current_workspace
               && !wwin->flags.miniaturized
               && !wwin->flags.maximized && !(wwin->normal_hints->flags & (USPosition | PPosition))) {

      if (transientOwner && transientOwner->flags.mapped) {
        int offs = WMAX(20, 2 * transientOwner->frame->top_width);
        WMRect rect;
        int head;

        x = transientOwner->frame_x +
          abs((int)(transientOwner->frame->core->width - width) / 2) + offs;
        y = transientOwner->frame_y +
          abs((int)(transientOwner->frame->core->height - height) / 3) + offs;

        /* limit transient windows to be inside their parent's head */
        rect.pos.x = transientOwner->frame_x;
        rect.pos.y = transientOwner->frame_y;
        rect.size.width = transientOwner->frame->core->width;
        rect.size.height = transientOwner->frame->core->height;

        head = wGetHeadForRect(scr, rect);
        rect = wGetRectForHead(scr, head);

        if (x < rect.pos.x)
          x = rect.pos.x;
        else if (x + width > rect.pos.x + rect.size.width)
          x = rect.pos.x + rect.size.width - width;

        if (y < rect.pos.y)
          y = rect.pos.y;
        else if (y + height > rect.pos.y + rect.size.height)
          y = rect.pos.y + rect.size.height - height;

      } else {
        PlaceWindow(wwin, &x, &y, width, height);
      }

      if (wPreferences.window_placement == WPM_MANUAL)
        dontBring = True;

    } else if (scr->xrandr_info.count && (wwin->normal_hints->flags & PPosition)) {
      int head, flags;
      WMRect rect;
      int reposition = 0;

      /* Make spash screens come out in the center of a head
       * trouble is that most splashies never get here
       * they are managed trough atoms but god knows where.
       * Dan, do you know ? -peter
       *
       * Most of them are not managed, they have set
       * OverrideRedirect, which means we can't do anything about
       * them. -alfredo */
      {
        /* xinerama checks for: across head and dead space */
        rect.pos.x = x;
        rect.pos.y = y;
        rect.size.width = width;
        rect.size.height = height;

        head = wGetRectPlacementInfo(scr, rect, &flags);

        if (flags & XFLAG_DEAD)
          reposition = 1;

        if (flags & XFLAG_MULTIPLE)
          reposition = 2;
      }

      switch (reposition) {
      case 1:
        head = wGetHeadForPointerLocation(scr);
        rect = wGetRectForHead(scr, head);

        x = rect.pos.x + (x * rect.size.width) / scr->scr_width;
        y = rect.pos.y + (y * rect.size.height) / scr->scr_height;
        break;

      case 2:
        rect = wGetRectForHead(scr, head);

        if (x < rect.pos.x)
          x = rect.pos.x;
        else if (x + width > rect.pos.x + rect.size.width)
          x = rect.pos.x + rect.size.width - width;

        if (y < rect.pos.y)
          y = rect.pos.y;
        else if (y + height > rect.pos.y + rect.size.height)
          y = rect.pos.y + rect.size.height - height;

        break;

      default:
        break;
      }
    }

    if (WFLAGP(wwin, dont_move_off) && dontBring)
      wScreenBringInside(scr, &x, &y, width, height);
  }

  wNETWMPositionSplash(wwin, &x, &y, width, height);

  if (wwin->flags.urgent) {
    if (!IS_OMNIPRESENT(wwin))
      wwin->flags.omnipresent ^= 1;
  }

  /* Create frame, borders and do reparenting */
  foo = WFF_LEFT_BUTTON | WFF_RIGHT_BUTTON;
#ifdef XKB_BUTTON_HINT
  if (wPreferences.modelock)
    foo |= WFF_LANGUAGE_BUTTON;
#endif
  if (HAS_TITLEBAR(wwin))
    foo |= WFF_TITLEBAR;

  if (HAS_RESIZEBAR(wwin))
    foo |= WFF_RESIZEBAR;

  if (HAS_BORDER(wwin))
    foo |= WFF_BORDER;

  wwin->frame = wFrameWindowCreate(scr, window_level,
                                   x, y, width, height,
                                   &wPreferences.window_title_clearance,
                                   &wPreferences.window_title_min_height,
                                   &wPreferences.window_title_max_height,
                                   foo,
                                   scr->window_title_texture,
                                   scr->resizebar_texture, scr->window_title_color, &scr->title_font,
                                   wattribs.depth, wattribs.visual, wattribs.colormap);

  wwin->frame->flags.is_client_window_frame = 1;
  wwin->frame->flags.justification = wPreferences.title_justification;

  wNETWMCheckInitialFrameState(wwin);

  /* setup button images */
  wWindowUpdateButtonImages(wwin);

  /* hide unused buttons */
  foo = 0;
  if (WFLAGP(wwin, no_close_button))
    foo |= WFF_RIGHT_BUTTON;

  if (WFLAGP(wwin, no_miniaturize_button))
    foo |= WFF_LEFT_BUTTON;

#ifdef XKB_BUTTON_HINT
  if (WFLAGP(wwin, no_language_button) || WFLAGP(wwin, no_focusable))
    foo |= WFF_LANGUAGE_BUTTON;
#endif
  if (foo != 0)
    wFrameWindowHideButton(wwin->frame, foo);

  wwin->frame->child = wwin;
  wwin->frame->workspace = workspace;
  wwin->frame->on_click_left = windowIconifyClick;

#ifdef XKB_BUTTON_HINT
  if (wPreferences.modelock)
    wwin->frame->on_click_language = windowLanguageClick;
#endif

  wwin->frame->on_click_right = windowCloseClick;
  wwin->frame->on_dblclick_right = windowCloseDblClick;
  wwin->frame->on_mousedown_titlebar = titlebarMouseDown;
  wwin->frame->on_dblclick_titlebar = titlebarDblClick;
  wwin->frame->on_mousedown_resizebar = resizebarMouseDown;

  XSelectInput(dpy, wwin->client_win, wwin->event_mask & ~StructureNotifyMask);
  XReparentWindow(dpy, wwin->client_win, wwin->frame->core->window, 0, wwin->frame->top_width);
  XSelectInput(dpy, wwin->client_win, wwin->event_mask);

  {
    int gx, gy;

    wClientGetGravityOffsets(wwin, &gx, &gy);

    /* if gravity is to the south, account for the border sizes */
    if (gy > 0)
      y -= wwin->frame->top_width + wwin->frame->bottom_width;
  }

  /* We're starting to manage already existed window at our startup.
   * Adjust window position so window will not be shifted down and right
   * after decorations added.
   */
  if (scr->flags.startup) {
    x -= 1;
    y -= (wwin->frame->top_width + 1);
  }

  /*
   * wWindowConfigure() will init the client window's size
   * (wwin->client.{width,height}) and all other geometry
   * related variables (frame_x,frame_y) */
  wWindowConfigure(wwin, x, y, width, height);

  /* to make sure the window receives it's new position after reparenting */
  wWindowSynthConfigureNotify(wwin);

  /* Setup descriptors and save window to internal lists */
  if (wwin->main_window != None) {
    WApplication *app;
    WWindow *leader;

    /* Leader windows do not necessary set themselves as leaders.
     * If this is the case, point the leader of this window to
     * itself */
    leader = wWindowFor(wwin->main_window);
    if (leader && leader->main_window == None)
      leader->main_window = leader->client_win;

    app = wApplicationCreate(wwin);
    if (app) {
      app->last_workspace = workspace;

      /* Do application specific stuff, like setting application
       * wide attributes. */

      if (wwin->flags.hidden) {
        /* if the window was set to hidden because it was hidden
         * in a previous incarnation and that state was restored */
        app->flags.hidden = 1;
      } else if (app->flags.hidden) {
        if (WFLAGP(app->main_window_desc, start_hidden)) {
          wwin->flags.hidden = 1;
        } else if (!wwin->flags.is_gnustep) { // GNUstep application unhides itself
          wUnhideApplication(app, False, False);
          raise = True;
        }
      }
      wAppBounce(app);
    }
  }

  /* setup the frame descriptor */
  wwin->frame->core->descriptor.handle_mousedown = frameMouseDown;
  wwin->frame->core->descriptor.parent = wwin;
  wwin->frame->core->descriptor.parent_type = WCLASS_WINDOW;

  /* don't let windows go away if we die */
  XAddToSaveSet(dpy, window);

  XLowerWindow(dpy, window);

  /* if window is in this workspace and should be mapped, then  map it */
  if (!wwin->flags.miniaturized && (workspace == scr->current_workspace || IS_OMNIPRESENT(wwin))
      && !wwin->flags.hidden && !withdraw) {

    /* The following "if" is to avoid crashing of clients that expect
     * WM_STATE set before they get mapped. Else WM_STATE is set later,
     * after the return from this function. */
    if (wwin->wm_hints && (wwin->wm_hints->flags & StateHint))
      wClientSetState(wwin, wwin->wm_hints->initial_state, None);
    else
      wClientSetState(wwin, NormalState, None);

    if (wPreferences.superfluous && !wPreferences.no_animations && !scr->flags.startup &&
        (wwin->transient_for == None || wwin->transient_for == scr->root_win)
        && wPreferences.auto_focus)
      DoWindowBirth(wwin);

    wWindowMap(wwin);
  }

  /* setup stacking descriptor */
  if (transientOwner)
    wwin->frame->core->stacking->child_of = transientOwner->frame->core;
  else
    wwin->frame->core->stacking->child_of = NULL;

  if (!scr->focused_window) {
    /* first window on the list */
    wwin->next = NULL;
    wwin->prev = NULL;
    scr->focused_window = wwin;
  } else {
    WWindow *tmp;

    /* add window at beginning of focus window list */
    tmp = scr->focused_window;
    while (tmp->prev)
      tmp = tmp->prev;

    tmp->prev = wwin;
    wwin->next = tmp;
    wwin->prev = NULL;
  }

  /* raise is set to true if we un-hid the app when this window was born.
   * we raise, else old windows of this app will be above this new one. */
  if (raise)
    wRaiseFrame(wwin->frame->core);

  /* Update name must come after WApplication stuff is done */
  wWindowUpdateName(wwin, title);
  if (title)
    XFree(title);

  XUngrabServer(dpy);

  /* Final preparations before window is ready to go */
  wFrameWindowChangeState(wwin->frame, WS_UNFOCUSED);

  /* GNUstep application has custom focus management - let it focus its window.
     Our wSetFocusTo call would be a result of FocusIn event appearance.
     .is_dockapp is set for windows created with Withdrawn state */
  if (!wwin->flags.is_gnustep && !wwin->flags.is_dockapp
      && !wwin->flags.miniaturized && !wwin->flags.hidden
      && workspace == scr->current_workspace) {
    if (((transientOwner && transientOwner->flags.focused)
         || wPreferences.auto_focus) && !WFLAGP(wwin, no_focusable)) {

      /* only auto_focus if on same screen as mouse
       * (and same head for xinerama mode)
       * TODO: make it an option */

      /*TODO add checking the head of the window, is it available? */
      short same_screen = 0, same_head = 1;

      int foo;
      unsigned int bar;
      Window dummy;

      if (XQueryPointer(dpy, scr->root_win, &dummy, &dummy,
                        &foo, &foo, &foo, &foo, &bar) != False)
        same_screen = 1;

      if (same_screen == 1 && same_head == 1)
        wSetFocusTo(scr, wwin);
    }
  }
  wWindowResetMouseGrabs(wwin);

  if (!WFLAGP(wwin, no_bind_keys))
    wWindowSetKeyGrabs(wwin);

  WMPostNotificationName(WMNManaged, wwin, NULL);
  wColormapInstallForWindow(scr, scr->cmap_window);

  /* Setup Notification Observers */
  WMAddNotificationObserver(appearanceObserver, wwin, WNWindowAppearanceSettingsChanged, wwin);

  /*  Cleanup temporary stuff */
  if (win_state)
    wWindowDeleteSavedState(win_state);

  /* If the window must be withdrawed, then do it now.
   * Must do some optimization, 'though */
  if (withdraw && wwin->frame->core->stacking->window_level != NSMainMenuWindowLevel) {
    wwin->flags.mapped = 0;
    wClientSetState(wwin, WithdrawnState, None);
    wUnmanageWindow(wwin, True, False);
    wwin = NULL;
  }

  return wwin;
}

WWindow *wManageInternalWindow(WScreen *scr, Window window, Window owner,
			       const char *title, int x, int y, int width, int height)
{
  WWindow *wwin;
  int foo;

  wwin = wWindowCreate();

  WMAddNotificationObserver(appearanceObserver, wwin, WNWindowAppearanceSettingsChanged, wwin);

  wwin->flags.internal_window = 1;

  wwin->client_flags.omnipresent = 1;
  wwin->client_flags.no_shadeable = 1;
  wwin->client_flags.no_resizable = 1;
  wwin->client_flags.no_miniaturizable = 1;

  wwin->focus_mode = WFM_PASSIVE;
  wwin->client_win = window;
  wwin->screen_ptr = scr;
  wwin->transient_for = owner;
  wwin->client.x = x;
  wwin->client.y = y;
  wwin->client.width = width;
  wwin->client.height = height;
  wwin->frame_x = wwin->client.x;
  wwin->frame_y = wwin->client.y;

  foo = WFF_RIGHT_BUTTON | WFF_BORDER;
  foo |= WFF_TITLEBAR;
#ifdef XKB_BUTTON_HINT
  foo |= WFF_LANGUAGE_BUTTON;
#endif

  wwin->frame = wFrameWindowCreate(scr, NSFloatingWindowLevel,
                                   wwin->frame_x, wwin->frame_y,
                                   width, height,
                                   &wPreferences.window_title_clearance,
                                   &wPreferences.window_title_min_height,
                                   &wPreferences.window_title_max_height,
                                   foo,
                                   scr->window_title_texture,
                                   scr->resizebar_texture, scr->window_title_color, &scr->title_font,
                                   scr->w_depth, scr->w_visual, scr->w_colormap);

  XSaveContext(dpy, window, w_global.context.client_win, (XPointer) & wwin->client_descriptor);

  wwin->frame->flags.is_client_window_frame = 1;
  wwin->frame->flags.justification = wPreferences.title_justification;

  wFrameWindowChangeTitle(wwin->frame, title);

  /* setup button images */
  wWindowUpdateButtonImages(wwin);

  /* hide buttons */
  wFrameWindowHideButton(wwin->frame, WFF_RIGHT_BUTTON);

  wwin->frame->child = wwin;
  wwin->frame->workspace = wwin->screen_ptr->current_workspace;

#ifdef XKB_BUTTON_HINT
  if (wPreferences.modelock)
    wwin->frame->on_click_language = windowLanguageClick;
#endif

  wwin->frame->on_click_right = windowCloseClick;
  wwin->frame->on_mousedown_titlebar = titlebarMouseDown;
  wwin->frame->on_dblclick_titlebar = titlebarDblClick;
  wwin->frame->on_mousedown_resizebar = resizebarMouseDown;
  wwin->client.y += wwin->frame->top_width;

  XReparentWindow(dpy, wwin->client_win, wwin->frame->core->window, 0, wwin->frame->top_width);
  wWindowConfigure(wwin, wwin->frame_x, wwin->frame_y, wwin->client.width, wwin->client.height);

  /* setup the frame descriptor */
  wwin->frame->core->descriptor.handle_mousedown = frameMouseDown;
  wwin->frame->core->descriptor.parent = wwin;
  wwin->frame->core->descriptor.parent_type = WCLASS_WINDOW;

  XLowerWindow(dpy, window);
  XMapSubwindows(dpy, wwin->frame->core->window);

  /* setup stacking descriptor */
  if (wwin->transient_for != None && wwin->transient_for != scr->root_win) {
    WWindow *tmp;
    tmp = wWindowFor(wwin->transient_for);
    if (tmp)
      wwin->frame->core->stacking->child_of = tmp->frame->core;
  } else {
    wwin->frame->core->stacking->child_of = NULL;
  }

  if (!scr->focused_window) {
    /* first window on the list */
    wwin->next = NULL;
    wwin->prev = NULL;
    scr->focused_window = wwin;
  } else {
    WWindow *tmp;

    /* add window at beginning of focus window list */
    tmp = scr->focused_window;
    while (tmp->prev)
      tmp = tmp->prev;
    tmp->prev = wwin;
    wwin->next = tmp;
    wwin->prev = NULL;
  }

  if (wwin->flags.is_gnustep == 0)
    wFrameWindowChangeState(wwin->frame, WS_UNFOCUSED);

  /*    if (wPreferences.auto_focus) */
  wSetFocusTo(scr, wwin);
  wWindowResetMouseGrabs(wwin);
  wWindowSetKeyGrabs(wwin);

  return wwin;
}

/*
 *----------------------------------------------------------------------
 * wUnmanageWindow--
 * 	Removes the frame window from a window and destroys all data
 * related to it. The window will be reparented back to the root window
 * if restore is True.
 *
 * Side effects:
 * 	Everything related to the window is destroyed and the window
 * is removed from the window lists. Focus is set to the previous on the
 * window list.
 *----------------------------------------------------------------------
 */
void wUnmanageWindow(WWindow *wwin, Bool restore, Bool destroyed)
{
  WCoreWindow *frame = wwin->frame->core;
  WWindow *owner = NULL;
  WWindow *new_focused_window = NULL;
  int wasFocused;
  WScreen *scr = wwin->screen_ptr;
  WApplication *oapp;

  wmessage("[window.c] will unmanage window:%lu\n", wwin->client_win);
  
  /* Close window menu if it's open for this window */
  if (wwin->flags.menu_open_for_me)
    CloseWindowMenu(scr);

  /* Don't restore focus to this window after a window exits
   * fullscreen mode */
  if (scr->bfs_focused_window == wwin)
    scr->bfs_focused_window = NULL;

  if (!destroyed) {
    if (!wwin->flags.internal_window)
      XRemoveFromSaveSet(dpy, wwin->client_win);

    /* If this is a leader window, we still need to listen for
     * DestroyNotify and PropertyNotify. */
    if (wApplicationOf(wwin->client_win))
      XSelectInput(dpy, wwin->client_win, StructureNotifyMask | PropertyChangeMask);
    else
      XSelectInput(dpy, wwin->client_win, NoEventMask);

    XUngrabButton(dpy, AnyButton, AnyModifier, wwin->client_win);
    XUngrabKey(dpy, AnyKey, AnyModifier, wwin->client_win);
  }

  XUnmapWindow(dpy, frame->window);

  XUnmapWindow(dpy, wwin->client_win);

  /* deselect window */
  wSelectWindow(wwin, False);

  /* remove all pending events on window */
  /* I think this only matters for autoraise */
  if (wPreferences.raise_delay)
    WMDeleteTimerWithClientData(wwin->frame->core);

  XFlush(dpy);

  /* reparent the window back to the root */
  if (restore)
    wClientRestore(wwin);

  if (wwin->transient_for != scr->root_win) {
    owner = wWindowFor(wwin->transient_for);
    if (owner) {
      if (!owner->flags.semi_focused)
        owner = NULL;
      else
        owner->flags.semi_focused = 0;
    }
  }

  wasFocused = wwin->flags.focused;

  /* remove from window focus list */
  if (!wwin->prev && !wwin->next) {
    /* was the only window */
    scr->focused_window = NULL;
    new_focused_window = NULL;
  }
  else {
    if (wwin->prev)
      wwin->prev->next = wwin->next;

    if (wwin->next)
      wwin->next->prev = wwin->prev;
    else {
      scr->focused_window = wwin->prev;
      scr->focused_window->next = NULL;
    }

    new_focused_window = wNextWindowToFocus(wwin);
  }

  if (!wwin->flags.internal_window) {
    WMPostNotificationName(WMNUnmanaged, wwin, NULL);
  }
  
  oapp = wApplicationOf(wwin->main_window);
  
  if (wasFocused) {
    WApplication *napp = wApplicationOf(new_focused_window->main_window);
    
    if (owner && new_focused_window != owner) {
      wFrameWindowChangeState(owner->frame, WS_UNFOCUSED);
    }
    
    if (!strcmp(new_focused_window->wm_instance, "Workspace")
        || napp->last_workspace == scr->current_workspace) {
      napp = NULL;
    }
    
    if (wwin->flags.is_gnustep) {
      wmessage("[window.c] new_focused_window == %lu",
               new_focused_window ? new_focused_window->client_win : 0);
      /* When main menu becomes unmanaged - app's quitting - we should switch
         focus to other app. Otherwise set focus to main menu to prevent 
         appication focus lost (FocusOut event is generated by X server as a 
         result of XUnmapWindow() call, focus goes to root window and application 
         deactivates). */
      if (WINDOW_LEVEL(wwin) == NSMainMenuWindowLevel) {
        wmessage("[window.c] set focus to new_focused_window == %lu",
                 new_focused_window ? new_focused_window->client_win : 0);
        /* Application activation executes workspace switch */
        if (napp)
          wApplicationActivate(napp);
        else
          wSetFocusTo(scr, new_focused_window);
      }
      else if (oapp && oapp->menu_win) {
        /* wSetFocusTo will be called in handleFocusIn() */
        wmessage("[window.c] set focus to main menu == %lu", oapp->menu_win->client_win);
        XSetInputFocus(dpy, oapp->menu_win->client_win, RevertToParent, CurrentTime);
        oapp->menu_win->flags.focused = 1;
      }
    }
    else if (new_focused_window->frame->workspace != scr->current_workspace) {
      wWorkspaceForceChange(scr, new_focused_window->frame->workspace, new_focused_window);
    }
    else if (napp) {
      wApplicationActivate(napp);
    }
    else {
      wSetFocusTo(scr, new_focused_window);
    }
  }

  /* Call it second time because application context might not exist at this point */
  oapp = wApplicationOf(wwin->main_window);
  if (oapp) {
    wApplicationRemoveWindow(oapp, wwin);
  }

  wNETCleanupFrameExtents(wwin);

  wWindowDestroy(wwin);
  XFlush(dpy);
}

void wWindowMap(WWindow *wwin)
{
  XMapWindow(dpy, wwin->frame->core->window);
  if (!wwin->flags.shaded) {
    /* window will be remapped when getting MapNotify */
    XSelectInput(dpy, wwin->client_win, wwin->event_mask & ~StructureNotifyMask);
    XMapWindow(dpy, wwin->client_win);
    XSelectInput(dpy, wwin->client_win, wwin->event_mask);

    wwin->flags.mapped = 1;
  }
}

void wWindowUnmap(WWindow *wwin)
{
  wwin->flags.mapped = 0;

  /* prevent window withdrawal when getting UnmapNotify */
  XSelectInput(dpy, wwin->client_win, wwin->event_mask & ~StructureNotifyMask);
  XUnmapWindow(dpy, wwin->client_win);
  XSelectInput(dpy, wwin->client_win, wwin->event_mask);

  XUnmapWindow(dpy, wwin->frame->core->window);
}

void wWindowSingleFocus(WWindow *wwin)
{
  WScreen *scr;
  int x, y, move = 0;

  if (!wwin)
    return;

  scr = wwin->screen_ptr;
  wMakeWindowVisible(wwin);

  x = wwin->frame_x;
  y = wwin->frame_y;

  /* bring window back to visible area */
  move = wScreenBringInside(scr, &x, &y, wwin->frame->core->width, wwin->frame->core->height);

  if (move) {
    wWindowConfigure(wwin, x, y, wwin->client.width, wwin->client.height);
  }
}

void wWindowFocusPrev(WWindow *wwin, Bool inSameWorkspace)
{
  WWindow *tmp;

  if (!wwin || !wwin->prev)
    return;

  tmp = wwin;
  while (tmp->prev)
    tmp = tmp->prev;

  if (inSameWorkspace)
    while (tmp && (tmp->frame->workspace != wwin->frame->workspace))
      tmp = tmp->next;

  wWindowSingleFocus(tmp);
}

void wWindowFocusNext(WWindow *wwin, Bool inSameWorkspace)
{
  WWindow *tmp;

  if (!wwin || !wwin->prev)
    return;

  tmp = wwin->prev;
  if (inSameWorkspace)
    while (tmp && (tmp->frame->workspace != wwin->frame->workspace))
      tmp = tmp->prev;

  wWindowSingleFocus(tmp);
}

void wWindowFocus(WWindow *wwin, WWindow *owin)
{
  WWindow *nowner;
  WWindow *oowner;

  wPrintWindowFocusState(wwin, "[START] wWindowFocus:");
  
#ifdef KEEP_XKB_LOCK_STATUS
  if (wPreferences.modelock)
    XkbLockGroup(dpy, XkbUseCoreKbd, wwin->frame->languagemode);
#endif /* KEEP_XKB_LOCK_STATUS */

  wwin->flags.semi_focused = 0;

  /* GNUstep app manages focus itself after WM_TAKE_FOCUS was sent (wSetFocusTo) */
  if (wwin->flags.is_gnustep == 0) {
    wFrameWindowChangeState(wwin->frame, WS_FOCUSED);
    wRaiseFrame(wwin->frame->core);
  }

  wwin->flags.focused = 1;

  wWindowResetMouseGrabs(wwin);

  WMPostNotificationName(WMNChangedFocus, wwin, (void *)True);

  if (owin == wwin || !owin)
    return;

  nowner = wWindowFor(wwin->transient_for);

  /* new window is a transient for the old window */
  if (nowner == owin) {
    owin->flags.semi_focused = 1;
    wWindowUnfocus(nowner);
    return;
  }

  oowner = wWindowFor(owin->transient_for);

  /* new window is owner of old window */
  if (wwin == oowner) {
    wWindowUnfocus(owin);
    return;
  }

  if (!nowner) {
    wWindowUnfocus(owin);
    return;
  }

  /* new window has same owner of old window */
  if (oowner == nowner) {
    /* prevent unfocusing of owner */
    oowner->flags.semi_focused = 0;
    wWindowUnfocus(owin);
    oowner->flags.semi_focused = 1;

    return;
  }

  /* nowner != NULL && oowner != nowner */
  nowner->flags.semi_focused = 1;
  wWindowUnfocus(nowner);
  wWindowUnfocus(owin);
  wPrintWindowFocusState(wwin, "[ END ] wWindowFocus:");
}

void wWindowUnfocus(WWindow *wwin)
{
  CloseWindowMenu(wwin->screen_ptr);

  wPrintWindowFocusState(wwin, "[START] wWindowUnfocus:");
  
  if (wwin->flags.is_gnustep == 0) {
    wFrameWindowChangeState(wwin->frame, wwin->flags.semi_focused ? WS_PFOCUSED : WS_UNFOCUSED);
  }
  else if (WINDOW_LEVEL(wwin) != NSMainMenuWindowLevel) {
    /* Send FocusOut event with NotifyNormal mode since
       GNUstep(NEXTSPACE, XGServerEvent.m, processEvent:, FocusOut) ignores
       grabbed mode FocusOut events.*/
    Window  fwin;
    int     rev;
    XGetInputFocus(dpy, &fwin, &rev);

    XEvent ev;
    ev.xfocus.type = FocusOut;
    ev.xfocus.send_event = True;
    ev.xfocus.display = dpy;
    ev.xfocus.window = wwin->client_win;
    ev.xfocus.mode = NotifyNormal;
    XSendEvent(dpy, wwin->client_win, True, FocusChangeMask, &ev);
  }

  if (wwin->transient_for != None && wwin->transient_for != wwin->screen_ptr->root_win) {
    WWindow *owner = wWindowFor(wwin->transient_for);
    if (owner && owner->flags.semi_focused) {
      owner->flags.semi_focused = 0;
      if (owner->flags.mapped || owner->flags.shaded) {
        wWindowUnfocus(owner);
        wFrameWindowPaint(owner->frame);
      }
    }
  }
  
  wwin->flags.focused = 0;
  wWindowResetMouseGrabs(wwin);
  WMPostNotificationName(WMNChangedFocus, wwin, (void *)False);
  wPrintWindowFocusState(wwin, "[ END ] wWindowUnfocus:");
}

void wWindowUpdateName(WWindow *wwin, const char *newTitle)
{
  const char *title;

  if (!wwin->frame)
    return;

  if (!newTitle)
    title = DEF_WINDOW_TITLE; /* the hint was removed */
  else
    title = newTitle;

  if (wFrameWindowChangeTitle(wwin->frame, title))
    WMPostNotificationName(WMNChangedName, wwin, NULL);
}

/*
 *----------------------------------------------------------------------
 *
 * wWindowConstrainSize--
 * 	Constrains size for the client window, taking the maximal size,
 * window resize increments and other size hints into account.
 *
 * Returns:
 * 	The closest size to what was given that the client window can
 * have.
 *
 *----------------------------------------------------------------------
 */
void wWindowConstrainSize(WWindow *wwin, unsigned int *nwidth, unsigned int *nheight)
{
  int width = (int)*nwidth;
  int height = (int)*nheight;
  int winc = 1;
  int hinc = 1;
  int minW = 1, minH = 1;
  int maxW = wwin->screen_ptr->scr_width * 2;
  int maxH = wwin->screen_ptr->scr_height * 2;
  int minAX = -1, minAY = -1;
  int maxAX = -1, maxAY = -1;
  int baseW = 0;
  int baseH = 0;

  if (wwin->normal_hints) {
    winc = wwin->normal_hints->width_inc;
    hinc = wwin->normal_hints->height_inc;
    minW = wwin->normal_hints->min_width;
    minH = wwin->normal_hints->min_height;
    maxW = wwin->normal_hints->max_width;
    maxH = wwin->normal_hints->max_height;
    if (wwin->normal_hints->flags & PAspect) {
      minAX = wwin->normal_hints->min_aspect.x;
      minAY = wwin->normal_hints->min_aspect.y;
      maxAX = wwin->normal_hints->max_aspect.x;
      maxAY = wwin->normal_hints->max_aspect.y;
    }

    baseW = wwin->normal_hints->base_width;
    baseH = wwin->normal_hints->base_height;
  }

  if (width < minW)
    width = minW;
  if (height < minH)
    height = minH;

  if (width > maxW)
    width = maxW;
  if (height > maxH)
    height = maxH;

  /* aspect ratio code borrowed from olwm */
  if (minAX > 0) {
    /* adjust max aspect ratio */
    if (!(maxAX == 1 && maxAY == 1) && width * maxAY > height * maxAX) {
      if (maxAX > maxAY) {
        height = (width * maxAY) / maxAX;
        if (height > maxH) {
          height = maxH;
          width = (height * maxAX) / maxAY;
        }
      } else {
        width = (height * maxAX) / maxAY;
        if (width > maxW) {
          width = maxW;
          height = (width * maxAY) / maxAX;
        }
      }
    }

    /* adjust min aspect ratio */
    if (!(minAX == 1 && minAY == 1) && width * minAY < height * minAX) {
      if (minAX > minAY) {
        height = (width * minAY) / minAX;
        if (height < minH) {
          height = minH;
          width = (height * minAX) / minAY;
        }
      } else {
        width = (height * minAX) / minAY;
        if (width < minW) {
          width = minW;
          height = (width * minAY) / minAX;
        }
      }
    }
  }

  if (baseW != 0)
    width = (((width - baseW) / winc) * winc) + baseW;
  else
    width = (((width - minW) / winc) * winc) + minW;

  if (baseH != 0)
    height = (((height - baseH) / hinc) * hinc) + baseH;
  else
    height = (((height - minH) / hinc) * hinc) + minH;

  /* broken stupid apps may cause preposterous values for these.. */
  if (width > 0)
    *nwidth = width;
  if (height > 0)
    *nheight = height;
}

void wWindowCropSize(WWindow *wwin, unsigned int maxW, unsigned int maxH,
		     unsigned int *width, unsigned int *height)
{
  int baseW = 0, baseH = 0;
  int winc = 1, hinc = 1;

  if (wwin->normal_hints) {
    baseW = wwin->normal_hints->base_width;
    baseH = wwin->normal_hints->base_height;

    winc = wwin->normal_hints->width_inc;
    hinc = wwin->normal_hints->height_inc;
  }

  if (*width > maxW)
    *width = maxW - (maxW - baseW) % winc;

  if (*height > maxH)
    *height = maxH - (maxH - baseH) % hinc;
}

void wWindowChangeWorkspace(WWindow *wwin, int workspace)
{
  WScreen *scr = wwin->screen_ptr;
  WApplication *wapp;
  int unmap = 0;

  if (workspace >= scr->workspace_count || workspace < 0 || workspace == wwin->frame->workspace)
    return;

  if (workspace != scr->current_workspace) {
    /* Sent to other workspace. Unmap window */
    if ((wwin->flags.mapped
         || wwin->flags.shaded || (wwin->flags.miniaturized && !wPreferences.sticky_icons))
        && !IS_OMNIPRESENT(wwin) && !wwin->flags.changing_workspace) {

      wapp = wApplicationOf(wwin->main_window);
      if (wapp)
        wapp->last_workspace = workspace;

      if (wwin->flags.miniaturized) {
        if (wwin->icon) {
          XUnmapWindow(dpy, wwin->icon->core->window);
          wwin->icon->mapped = 0;
        }
      } else {
        unmap = 1;
        wSetFocusTo(scr, NULL);
      }
    }
  } else {
    /* brought to current workspace. Map window */
    if (wwin->flags.miniaturized && !wPreferences.sticky_icons) {
      if (wwin->icon) {
        XMapWindow(dpy, wwin->icon->core->window);
        wwin->icon->mapped = 1;
      }
    } else if (!wwin->flags.mapped && !(wwin->flags.miniaturized || wwin->flags.hidden)) {
      wWindowMap(wwin);
    }
  }
  if (!IS_OMNIPRESENT(wwin)) {
    int oldWorkspace = wwin->frame->workspace;
    wwin->frame->workspace = workspace;
    WMPostNotificationName(WMNChangedWorkspace, wwin, (void *)(uintptr_t) oldWorkspace);
  }

  if (unmap)
    wWindowUnmap(wwin);
}

void wWindowChangeWorkspaceRelative(WWindow *wwin, int amount)
{
  WScreen *scr = wwin->screen_ptr;
  int w = scr->current_workspace + amount;

  if (amount < 0) {
    if (w >= 0) {
      wWindowChangeWorkspace(wwin, w);
    } else if (wPreferences.ws_cycle) {
      wWindowChangeWorkspace(wwin, scr->workspace_count + w);
    }
  } else if (amount > 0) {
    if (w < scr->workspace_count) {
      wWindowChangeWorkspace(wwin, w);
    } else if (wPreferences.ws_advance) {
      int workspace = WMIN(w, MAX_WORKSPACES - 1);
      wWorkspaceMake(scr, workspace);
      wWindowChangeWorkspace(wwin, workspace);
    } else if (wPreferences.ws_cycle) {
      wWindowChangeWorkspace(wwin, w % scr->workspace_count);
    }
  }
}

void wWindowSynthConfigureNotify(WWindow *wwin)
{
  XEvent sevent;

  sevent.type = ConfigureNotify;
  sevent.xconfigure.display = dpy;
  sevent.xconfigure.event = wwin->client_win;
  sevent.xconfigure.window = wwin->client_win;

  sevent.xconfigure.x = wwin->client.x;
  sevent.xconfigure.y = wwin->client.y;
  sevent.xconfigure.width = wwin->client.width;
  sevent.xconfigure.height = wwin->client.height;

  sevent.xconfigure.border_width = wwin->old_border_width;
  if (HAS_TITLEBAR(wwin) && wwin->frame->titlebar)
    sevent.xconfigure.above = wwin->frame->titlebar->window;
  else
    sevent.xconfigure.above = None;

  sevent.xconfigure.override_redirect = False;
  XSendEvent(dpy, wwin->client_win, False, StructureNotifyMask, &sevent);
  XFlush(dpy);
}

/*
 *----------------------------------------------------------------------
 * wWindowConfigure()
 *
 * req_x, req_y: new requested positions for the frame
 * req_width, req_height: new requested sizes for the client
 *
 * Configures the frame, decorations and client window to the specified
 * geometry, whose validity is not checked --  wWindowConstrainSize()
 * must be used for that.
 * 	The size parameters are for the client window, but the position is
 * for the frame.
 * 	The client window receives a ConfigureNotify event, according
 * to what ICCCM says.
 *
 * Returns:
 * 	None
 *
 * Side effects:
 * 	Window size and position are changed and client window receives
 * a ConfigureNotify event.
 *----------------------------------------------------------------------
 */
void wWindowConfigure(WWindow *wwin, int req_x, int req_y, int req_width, int req_height)
{
  int synth_notify = False;
  int resize;

  /* if window size is guaranteed to fail - fix it to some reasonable
   * defaults. original report was a problem with VirtualBox VM. */
  if (req_height > SHRT_MAX)
    req_height = 480;
  
  if (req_width > SHRT_MAX)
    req_height = 640;
           
  resize = (req_width != wwin->client.width || req_height != wwin->client.height);
  /*
   * if the window is being moved but not resized then
   * send a synthetic ConfigureNotify
   */
  if ((req_x != wwin->frame_x || req_y != wwin->frame_y) && !resize)
    synth_notify = True;

  if (WFLAGP(wwin, dont_move_off))
    wScreenBringInside(wwin->screen_ptr, &req_x, &req_y, req_width, req_height);

  if (resize) {
    if (req_width < MIN_WINDOW_SIZE)
      req_width = MIN_WINDOW_SIZE;
    if (req_height < MIN_WINDOW_SIZE)
      req_height = MIN_WINDOW_SIZE;

    /* If growing, resize inner part before frame,
     * if shrinking, resize frame before.
     * This will prevent the frame (that can have a different color)
     * to be exposed, causing flicker */
    if (req_height > wwin->frame->core->height || req_width > wwin->frame->core->width)
      XResizeWindow(dpy, wwin->client_win, req_width, req_height);

    if (wwin->flags.shaded) {
      wFrameWindowConfigure(wwin->frame, req_x, req_y, req_width, wwin->frame->core->height);
      wwin->old_geometry.height = req_height;
    } else {
      int h;

      h = req_height + wwin->frame->top_width + wwin->frame->bottom_width;

      wFrameWindowConfigure(wwin->frame, req_x, req_y, req_width, h);
    }

    if (!(req_height > wwin->frame->core->height || req_width > wwin->frame->core->width))
      XResizeWindow(dpy, wwin->client_win, req_width, req_height);

    wwin->client.x = req_x;
    wwin->client.y = req_y + wwin->frame->top_width;
    wwin->client.width = req_width;
    wwin->client.height = req_height;
  } else {
    wwin->client.x = req_x;
    wwin->client.y = req_y + wwin->frame->top_width;

    XMoveWindow(dpy, wwin->frame->core->window, req_x, req_y);
  }
  wwin->frame_x = req_x;
  wwin->frame_y = req_y;
  if (HAS_BORDER(wwin)) {
    wwin->client.x += wwin->screen_ptr->frame_border_width;
    wwin->client.y += wwin->screen_ptr->frame_border_width;
  }
#ifdef USE_XSHAPE
  if (w_global.xext.shape.supported && wwin->flags.shaped && resize)
    wWindowSetShape(wwin);
#endif

  if (synth_notify)
    wWindowSynthConfigureNotify(wwin);

  wNETFrameExtents(wwin);

  XFlush(dpy);
}

/* req_x, req_y:  new position of the frame */
void wWindowMove(WWindow *wwin, int req_x, int req_y)
{
#ifdef CONFIGURE_WINDOW_WHILE_MOVING
  int synth_notify = False;

  /* Send a synthetic ConfigureNotify event for every window movement. */
  if ((req_x != wwin->frame_x || req_y != wwin->frame_y))
    synth_notify = True;
#else
  /* A single synthetic ConfigureNotify event is sent at the end of
   * a completed (opaque) movement in moveres.c */
#endif

  if (WFLAGP(wwin, dont_move_off))
    wScreenBringInside(wwin->screen_ptr, &req_x, &req_y,
                       wwin->frame->core->width, wwin->frame->core->height);

  wwin->client.x = req_x;
  wwin->client.y = req_y + wwin->frame->top_width;
  if (HAS_BORDER(wwin)) {
    wwin->client.x += wwin->screen_ptr->frame_border_width;
    wwin->client.y += wwin->screen_ptr->frame_border_width;
  }

  XMoveWindow(dpy, wwin->frame->core->window, req_x, req_y);

  wwin->frame_x = req_x;
  wwin->frame_y = req_y;

#ifdef CONFIGURE_WINDOW_WHILE_MOVING
  if (synth_notify)
    wWindowSynthConfigureNotify(wwin);
#endif
}

void wWindowUpdateButtonImages(WWindow *wwin)
{
  WScreen *scr = wwin->screen_ptr;
  Pixmap pixmap, mask;
  WFrameWindow *fwin = wwin->frame;

  if (!HAS_TITLEBAR(wwin))
    return;

  /* miniaturize button */
  if (!WFLAGP(wwin, no_miniaturize_button)) {
    if (wwin->wm_gnustep_attr && wwin->wm_gnustep_attr->flags & GSMiniaturizePixmapAttr) {
      pixmap = wwin->wm_gnustep_attr->miniaturize_pixmap;

      if (wwin->wm_gnustep_attr->flags & GSMiniaturizeMaskAttr)
        mask = wwin->wm_gnustep_attr->miniaturize_mask;
      else
        mask = None;

      if (fwin->lbutton_image
          && (fwin->lbutton_image->image != pixmap || fwin->lbutton_image->mask != mask)) {
        wPixmapDestroy(fwin->lbutton_image);
        fwin->lbutton_image = NULL;
      }

      if (!fwin->lbutton_image) {
        fwin->lbutton_image = wPixmapCreate(pixmap, mask);
        fwin->lbutton_image->client_owned = 1;
        fwin->lbutton_image->client_owned_mask = 1;
      }
    } else {
      if (fwin->lbutton_image && !fwin->lbutton_image->shared)
        wPixmapDestroy(fwin->lbutton_image);

#ifdef NEXTSPACE
      if (scr->flags.modifier_pressed) {
        if (wwin->flags.maximized) {
          fwin->lbutton_image = scr->b_pixmaps[WBUT_RESTORE];
        } else {
          fwin->lbutton_image = scr->b_pixmaps[WBUT_MAXIMIZE];
        }
      } else
#endif
        fwin->lbutton_image = scr->b_pixmaps[WBUT_ICONIFY];
    }
  }
#ifdef XKB_BUTTON_HINT
  if (!WFLAGP(wwin, no_language_button)) {
    if (fwin->languagebutton_image && !fwin->languagebutton_image->shared)
      wPixmapDestroy(fwin->languagebutton_image);

    fwin->languagebutton_image = scr->b_pixmaps[WBUT_XKBGROUP1 + fwin->languagemode];
  }
#endif

  /* close button */

  /* redefine WFLAGP to MGFLAGP to allow broken close operation */
#define MGFLAGP(wwin, FLAG)	(wwin)->client_flags.FLAG

  if (!WFLAGP(wwin, no_close_button)) {
    if (wwin->wm_gnustep_attr && wwin->wm_gnustep_attr->flags & GSClosePixmapAttr) {
      pixmap = wwin->wm_gnustep_attr->close_pixmap;

      if (wwin->wm_gnustep_attr->flags & GSCloseMaskAttr)
        mask = wwin->wm_gnustep_attr->close_mask;
      else
        mask = None;

      if (fwin->rbutton_image && (fwin->rbutton_image->image != pixmap
                                  || fwin->rbutton_image->mask != mask)) {
        wPixmapDestroy(fwin->rbutton_image);
        fwin->rbutton_image = NULL;
      }

      if (!fwin->rbutton_image) {
        fwin->rbutton_image = wPixmapCreate(pixmap, mask);
        fwin->rbutton_image->client_owned = 1;
        fwin->rbutton_image->client_owned_mask = 1;
      }

    } else if (WFLAGP(wwin, kill_close)) {
      if (fwin->rbutton_image && !fwin->rbutton_image->shared)
        wPixmapDestroy(fwin->rbutton_image);

      fwin->rbutton_image = scr->b_pixmaps[WBUT_KILL];

    } else if (MGFLAGP(wwin, broken_close)) {
      if (fwin->rbutton_image && !fwin->rbutton_image->shared)
        wPixmapDestroy(fwin->rbutton_image);

      fwin->rbutton_image = scr->b_pixmaps[WBUT_BROKENCLOSE];

    } else {
      if (fwin->rbutton_image && !fwin->rbutton_image->shared)
        wPixmapDestroy(fwin->rbutton_image);

#ifdef NEXTSPACE
      if (scr->flags.modifier_pressed)
        fwin->rbutton_image = scr->b_pixmaps[WBUT_KILL];
      else
#endif
        fwin->rbutton_image = scr->b_pixmaps[WBUT_CLOSE];
    }
  }

  /* force buttons to be redrawn */
  fwin->flags.need_texture_change = 1;
  wFrameWindowPaint(fwin);
}

/*
 *---------------------------------------------------------------------------
 * wWindowConfigureBorders--
 * 	Update window border configuration according to attribute flags.
 *
 *---------------------------------------------------------------------------
 */
void wWindowConfigureBorders(WWindow *wwin)
{
  if (wwin->frame) {
    int flags;
    int newy, oldh;

    flags = WFF_LEFT_BUTTON | WFF_RIGHT_BUTTON;

#ifdef XKB_BUTTON_HINT
    if (wPreferences.modelock)
      flags |= WFF_LANGUAGE_BUTTON;
#endif

    if (HAS_TITLEBAR(wwin))
      flags |= WFF_TITLEBAR;
    if (HAS_RESIZEBAR(wwin) && IS_RESIZABLE(wwin))
      flags |= WFF_RESIZEBAR;
    if (HAS_BORDER(wwin))
      flags |= WFF_BORDER;
    if (wwin->flags.shaded)
      flags |= WFF_IS_SHADED;
    if (wwin->flags.selected)
      flags |= WFF_SELECTED;

    oldh = wwin->frame->top_width;
    wFrameWindowUpdateBorders(wwin->frame, flags);
    wFrameWindowPaint(wwin->frame);
    if (oldh != wwin->frame->top_width) {
      newy = wwin->frame_y + oldh - wwin->frame->top_width;

      XMoveWindow(dpy, wwin->client_win, 0, wwin->frame->top_width);
      wWindowConfigure(wwin, wwin->frame_x, newy, wwin->client.width, wwin->client.height);
    }

    flags = 0;
    if (!WFLAGP(wwin, no_miniaturize_button)
        && wwin->frame->flags.hide_left_button)
      flags |= WFF_LEFT_BUTTON;

#ifdef XKB_BUTTON_HINT
    if (!WFLAGP(wwin, no_language_button)
        && wwin->frame->flags.hide_language_button)
      flags |= WFF_LANGUAGE_BUTTON;
#endif

    if (!WFLAGP(wwin, no_close_button)
        && wwin->frame->flags.hide_right_button)
      flags |= WFF_RIGHT_BUTTON;

    if (flags != 0) {
      wWindowUpdateButtonImages(wwin);
      wFrameWindowShowButton(wwin->frame, flags);
    }

    flags = 0;
    if (WFLAGP(wwin, no_miniaturize_button)
        && !wwin->frame->flags.hide_left_button)
      flags |= WFF_LEFT_BUTTON;

#ifdef XKB_BUTTON_HINT
    if (WFLAGP(wwin, no_language_button)
        && !wwin->frame->flags.hide_language_button)
      flags |= WFF_LANGUAGE_BUTTON;
#endif

    if (WFLAGP(wwin, no_close_button)
        && !wwin->frame->flags.hide_right_button)
      flags |= WFF_RIGHT_BUTTON;

    if (flags != 0)
      wFrameWindowHideButton(wwin->frame, flags);

#ifdef USE_XSHAPE
    if (w_global.xext.shape.supported && wwin->flags.shaped)
      wWindowSetShape(wwin);
#endif
  }
}

void wWindowSaveState(WWindow *wwin)
{
  long data[10];
  int i;

  memset(data, 0, sizeof(long) * 10);
  data[0] = wwin->frame->workspace;
  data[1] = wwin->flags.miniaturized;
  data[2] = wwin->flags.shaded;
  data[3] = wwin->flags.hidden;
  data[4] = wwin->flags.maximized;
  if (wwin->flags.maximized == 0) {
    data[5] = wwin->frame_x;
    data[6] = wwin->frame_y;
    data[7] = wwin->frame->core->width;
    data[8] = wwin->frame->core->height;
  } else {
    data[5] = wwin->old_geometry.x;
    data[6] = wwin->old_geometry.y;
    data[7] = wwin->old_geometry.width;
    data[8] = wwin->old_geometry.height;
  }

  for (i = 0; i < MAX_WINDOW_SHORTCUTS; i++) {
    if (wwin->screen_ptr->shortcutWindows[i] &&
        WMCountInArray(wwin->screen_ptr->shortcutWindows[i], wwin))
      data[9] |= 1 << i;
  }

  XChangeProperty(dpy, wwin->client_win, w_global.atom.wmaker.state,
                  w_global.atom.wmaker.state, 32, PropModeReplace, (unsigned char *)data, 10);
}

static int getSavedState(Window window, WSavedState ** state)
{
  Atom type_ret;
  int fmt_ret;
  unsigned long nitems_ret;
  unsigned long bytes_after_ret;
  long *data;

  if (XGetWindowProperty(dpy, window, w_global.atom.wmaker.state, 0, 10,
                         True, w_global.atom.wmaker.state,
                         &type_ret, &fmt_ret, &nitems_ret, &bytes_after_ret,
                         (unsigned char **)&data) != Success || !data || nitems_ret < 10)
    return 0;

  if (type_ret != w_global.atom.wmaker.state) {
    XFree(data);
    return 0;
  }

  *state = wmalloc(sizeof(WSavedState));

  (*state)->workspace = data[0];
  (*state)->miniaturized = data[1];
  (*state)->shaded = data[2];
  (*state)->hidden = data[3];
  (*state)->maximized = data[4];
  (*state)->x = data[5];
  (*state)->y = data[6];
  (*state)->w = data[7];
  (*state)->h = data[8];
  (*state)->window_shortcuts = data[9];

  XFree(data);

  return 1;
}

#ifdef USE_XSHAPE
void wWindowClearShape(WWindow * wwin)
{
  XShapeCombineMask(dpy, wwin->frame->core->window, ShapeBounding,
                    0, wwin->frame->top_width, None, ShapeSet);
  XFlush(dpy);
}

void wWindowSetShape(WWindow * wwin)
{
  XRectangle rect[2];
  int count;
#ifdef OPTIMIZE_SHAPE
  XRectangle *rects;
  XRectangle *urec;
  int ordering;

  /* only shape is the client's */
  if (!HAS_TITLEBAR(wwin) && !HAS_RESIZEBAR(wwin))
    goto alt_code;

  /* Get array of rectangles describing the shape mask */
  rects = XShapeGetRectangles(dpy, wwin->client_win, ShapeBounding, &count, &ordering);
  if (!rects)
    goto alt_code;

  urec = malloc(sizeof(XRectangle) * (count + 2));
  if (!urec) {
    XFree(rects);
    goto alt_code;
  }

  /* insert our decoration rectangles in the rect list */
  memcpy(urec, rects, sizeof(XRectangle) * count);
  XFree(rects);

  if (HAS_TITLEBAR(wwin)) {
    urec[count].x = -1;
    urec[count].y = -1 - wwin->frame->top_width;
    urec[count].width = wwin->frame->core->width + 2;
    urec[count].height = wwin->frame->top_width + 1;
    count++;
  }
  if (HAS_RESIZEBAR(wwin)) {
    urec[count].x = -1;
    urec[count].y = wwin->frame->core->height - wwin->frame->bottom_width - wwin->frame->top_width;
    urec[count].width = wwin->frame->core->width + 2;
    urec[count].height = wwin->frame->bottom_width + 1;
    count++;
  }

  /* shape our frame window */
  XShapeCombineRectangles(dpy, wwin->frame->core->window, ShapeBounding,
                          0, wwin->frame->top_width, urec, count, ShapeSet, Unsorted);
  XFlush(dpy);
  wfree(urec);
  return;

 alt_code:
#endif				/* OPTIMIZE_SHAPE */
  count = 0;
  if (HAS_TITLEBAR(wwin)) {
    rect[count].x = -1;
    rect[count].y = -1;
    rect[count].width = wwin->frame->core->width + 2;
    rect[count].height = wwin->frame->top_width + 1;
    count++;
  }
  if (HAS_RESIZEBAR(wwin)) {
    rect[count].x = -1;
    rect[count].y = wwin->frame->core->height - wwin->frame->bottom_width;
    rect[count].width = wwin->frame->core->width + 2;
    rect[count].height = wwin->frame->bottom_width + 1;
    count++;
  }
  if (count > 0) {
    XShapeCombineRectangles(dpy, wwin->frame->core->window, ShapeBounding,
                            0, 0, rect, count, ShapeSet, Unsorted);
  }
  XShapeCombineShape(dpy, wwin->frame->core->window, ShapeBounding,
                     0, wwin->frame->top_width, wwin->client_win,
                     ShapeBounding, (count > 0 ? ShapeUnion : ShapeSet));
  XFlush(dpy);
}
#endif				/* USE_XSHAPE */

/* ====================================================================== */

FocusMode GetFocusMode(WWindow * wwin)
{
  FocusMode mode;

  if ((wwin->wm_hints) && (wwin->wm_hints->flags & InputHint)) {
    if (wwin->wm_hints->input == True) {
      if (wwin->protocols.TAKE_FOCUS)
        mode = WFM_LOCALLY_ACTIVE;
      else
        mode = WFM_PASSIVE;
    } else {
      if (wwin->protocols.TAKE_FOCUS)
        mode = WFM_GLOBALLY_ACTIVE;
      else
        mode = WFM_NO_INPUT;
    }
  } else {
    mode = WFM_PASSIVE;
  }
  return mode;
}

void wWindowSetKeyGrabs(WWindow * wwin)
{
  int i;
  WShortKey *key;

  for (i = 0; i < WKBD_LAST; i++) {
    key = &wKeyBindings[i];

    if (key->keycode == 0)
      continue;
    if (key->modifier != AnyModifier) {
      XGrabKey(dpy, key->keycode, key->modifier | LockMask,
               wwin->frame->core->window, True, GrabModeAsync, GrabModeAsync);
#ifdef NUMLOCK_HACK
      /* Also grab all modifier combinations possible that include,
       * LockMask, ScrollLockMask and NumLockMask, so that keygrabs
       * work even if the NumLock/ScrollLock key is on.
       */
      wHackedGrabKey(key->keycode, key->modifier,
                     wwin->frame->core->window, True, GrabModeAsync, GrabModeAsync);
#endif
    }
    XGrabKey(dpy, key->keycode, key->modifier,
             wwin->frame->core->window, True, GrabModeAsync, GrabModeAsync);
  }

#ifdef NEXTSPACE
  XGrabKey(dpy, XKeysymToKeycode(dpy, XK_Super_L), 0, wwin->client_win, True,
           GrabModeAsync, GrabModeAsync);
  XGrabKey(dpy, XKeysymToKeycode(dpy, XK_Super_R), 0, wwin->client_win, True,
           GrabModeAsync, GrabModeAsync);
#endif
}

void wWindowResetMouseGrabs(WWindow * wwin)
{
  /* Mouse grabs can't be done on the client window because of
   * ICCCM and because clients that try to do the same will crash.
   *
   * But there is a problem wich makes tbar buttons of unfocused
   * windows not usable as the click goes to the frame window instead
   * of the button itself. Must figure a way to fix that.
   */

  XUngrabButton(dpy, AnyButton, AnyModifier, wwin->client_win);

  if (!WFLAGP(wwin, no_bind_mouse)) {
    /* grabs for Meta+drag */
    wHackedGrabButton(AnyButton, MOD_MASK, wwin->client_win,
                      True, ButtonPressMask | ButtonReleaseMask,
                      GrabModeSync, GrabModeAsync, None, None);

    /* for CTRL+Wheel to Scroll Horiz, we have to grab CTRL as well
     * but we only grab it for Button4 and Button 5 since a lot of apps
     * use CTRL+Button1-3 for app related functionality
     */
    if (wPreferences.resize_increment > 0) {
      wHackedGrabButton(Button4, ControlMask, wwin->client_win,
                        True, ButtonPressMask | ButtonReleaseMask,
                        GrabModeSync, GrabModeAsync, None, None);
      wHackedGrabButton(Button5, ControlMask, wwin->client_win,
                        True, ButtonPressMask | ButtonReleaseMask,
                        GrabModeSync, GrabModeAsync, None, None);

      wHackedGrabButton(Button4, MOD_MASK | ControlMask, wwin->client_win,
                        True, ButtonPressMask | ButtonReleaseMask,
                        GrabModeSync, GrabModeAsync, None, None);
      wHackedGrabButton(Button5, MOD_MASK | ControlMask, wwin->client_win,
                        True, ButtonPressMask | ButtonReleaseMask,
                        GrabModeSync, GrabModeAsync, None, None);
    }
  }

  if (!wwin->flags.focused && !WFLAGP(wwin, no_focusable)
      && !wwin->flags.is_gnustep) {
    /* the passive grabs to focus the window */
    /* if (wPreferences.focus_mode == WKF_CLICK) */
    XGrabButton(dpy, AnyButton, AnyModifier, wwin->client_win,
                True, ButtonPressMask | ButtonReleaseMask, GrabModeSync, GrabModeAsync, None, None);
  }
  XFlush(dpy);
}

void wWindowUpdateGNUstepAttr(WWindow * wwin, GNUstepWMAttributes * attr)
{
  if (attr->flags & GSExtraFlagsAttr) {
    if (MGFLAGP(wwin, broken_close) != (attr->extra_flags & GSDocumentEditedFlag)) {
      wwin->client_flags.broken_close = !MGFLAGP(wwin, broken_close);
      wWindowUpdateButtonImages(wwin);
    }
  }
}

WMagicNumber wWindowAddSavedState(const char *instance, const char *class,
                                  const char *command, pid_t pid, WSavedState * state)
{
  WWindowState *wstate;

  wstate = malloc(sizeof(WWindowState));
  if (!wstate)
    return NULL;

  memset(wstate, 0, sizeof(WWindowState));
  wstate->pid = pid;
  if (instance)
    wstate->instance = wstrdup(instance);
  if (class)
    wstate->class = wstrdup(class);
  if (command)
    wstate->command = wstrdup(command);
  wstate->state = state;

  wstate->next = windowState;
  windowState = wstate;

  return wstate;
}

static inline int is_same(const char *x, const char *y)
{
  if ((x == NULL) && (y == NULL))
    return 1;

  if ((x == NULL) || (y == NULL))
    return 0;

  if (strcmp(x, y) == 0)
    return 1;
  else
    return 0;
}

WMagicNumber wWindowGetSavedState(Window win)
{
  char *instance, *class, *command = NULL;
  WWindowState *wstate = windowState;

  if (!wstate)
    return NULL;

  command = GetCommandForWindow(win);
  if (!command)
    return NULL;

  if (PropGetWMClass(win, &class, &instance)) {
    while (wstate) {
      if (is_same(instance, wstate->instance) &&
          is_same(class, wstate->class) &&
          is_same(command, wstate->command)) {
        break;
      }
      wstate = wstate->next;
    }
  } else {
    wstate = NULL;
  }

  if (command)
    wfree(command);
  if (instance)
    free(instance);
  if (class)
    free(class);

  return wstate;
}

void wWindowDeleteSavedState(WMagicNumber id)
{
  WWindowState *tmp, *wstate = (WWindowState *) id;

  if (!wstate || !windowState)
    return;

  tmp = windowState;
  if (tmp == wstate) {
    windowState = wstate->next;
    release_wwindowstate(wstate);
  } else {
    while (tmp->next) {
      if (tmp->next == wstate) {
        tmp->next = wstate->next;
        release_wwindowstate(wstate);
        break;
      }
      tmp = tmp->next;
    }
  }
}

void wWindowDeleteSavedStatesForPID(pid_t pid)
{
  WWindowState *tmp, *wstate;

  if (!windowState)
    return;

  tmp = windowState;
  if (tmp->pid == pid) {
    wstate = windowState;
    windowState = tmp->next;

    release_wwindowstate(wstate);
  } else {
    while (tmp->next) {
      if (tmp->next->pid == pid) {
        wstate = tmp->next;
        tmp->next = wstate->next;
        release_wwindowstate(wstate);
        break;
      }
      tmp = tmp->next;
    }
  }
}

static void release_wwindowstate(WWindowState *wstate)
{
  if (wstate->instance)
    wfree(wstate->instance);

  if (wstate->class)
    wfree(wstate->class);

  if (wstate->command)
    wfree(wstate->command);

  wfree(wstate->state);
  wfree(wstate);
}

void wWindowSetOmnipresent(WWindow *wwin, Bool flag)
{
  if (wwin->flags.omnipresent == flag)
    return;

  wwin->flags.omnipresent = flag;
  WMPostNotificationName(WMNChangedState, wwin, "omnipresent");
}

static void resizebarMouseDown(WCoreWindow *sender, void *data, XEvent *event)
{
  WWindow *wwin = data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) sender;

#ifndef NUMLOCK_HACK
  if ((event->xbutton.state & ValidModMask)
      != (event->xbutton.state & ~LockMask)) {
    wwarning(_("The NumLock, ScrollLock or similar key seems to be turned on. "
               "Turn it off or some mouse actions and keyboard shortcuts will not work."));
  }
#endif

  event->xbutton.state &= w_global.shortcut.modifiers_mask;

  CloseWindowMenu(wwin->screen_ptr);

  if (!(event->xbutton.state & ControlMask) && !WFLAGP(wwin, no_focusable)) {
    wSetFocusTo(wwin->screen_ptr, wwin);
  }

  if (event->xbutton.button == Button1)
    wRaiseFrame(wwin->frame->core);

  // For NEXTSPACE resize events are handled in handleMotionNotify() (evenc.c)
  // It was implemented to provide immediate chnage of focus and window raise
  // after mouse down. With the code below window will be raised or focused on mouse
  // release.
#ifndef NEXTSPACE
  if (event->xbutton.window != wwin->frame->resizebar->window) {
    if (XGrabPointer(dpy, wwin->frame->resizebar->window, True,
                     ButtonMotionMask | ButtonReleaseMask | ButtonPressMask,
                     GrabModeAsync, GrabModeAsync, None, None, CurrentTime)
        != GrabSuccess) {
      return;
    }
  }

  if (event->xbutton.state & MOD_MASK) {
    /* move the window */
    wMouseMoveWindow(wwin, event);
    XUngrabPointer(dpy, CurrentTime);
  } else {
    wMouseResizeWindow(wwin, event);
    XUngrabPointer(dpy, CurrentTime);
  }
#endif
}

static void titlebarDblClick(WCoreWindow *sender, void *data, XEvent *event)
{
  WWindow *wwin = data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) sender;

  event->xbutton.state &= w_global.shortcut.modifiers_mask;

  if (event->xbutton.button == Button1) {
    if (event->xbutton.state == 0) {
      if (!WFLAGP(wwin, no_shadeable)) {
        /* shade window */
        if (wwin->flags.shaded)
          wUnshadeWindow(wwin);
        else
          wShadeWindow(wwin);
      }
    } else {
      int dir = 0;

      if (event->xbutton.state & ControlMask)
        dir |= MAX_VERTICAL;

      if (event->xbutton.state & ShiftMask) {
        dir |= MAX_HORIZONTAL;
        if (!(event->xbutton.state & ControlMask))
          wSelectWindow(wwin, !wwin->flags.selected);
      }

      /* maximize window */
      if (dir != 0 && IS_RESIZABLE(wwin)) {
        int ndir = dir ^ wwin->flags.maximized;

        if (ndir != 0)
          wMaximizeWindow(wwin, ndir);
        else
          wUnmaximizeWindow(wwin);
      }
    }
  }
  else if (event->xbutton.button == Button3) {
    if (event->xbutton.state & MOD_MASK)
      wHideOtherApplications(wwin);
  }
  else if (event->xbutton.button == Button2) {
    wSelectWindow(wwin, !wwin->flags.selected);
  }
  else if (event->xbutton.button == W_getconf_mouseWheelUp()) {
    wShadeWindow(wwin);
  }
  else if (event->xbutton.button == W_getconf_mouseWheelDown()) {
    wUnshadeWindow(wwin);
  }
}

static void frameMouseDown(WObjDescriptor *desc, XEvent *event)
{
  WWindow *wwin = desc->parent;
  unsigned int new_width, w_scale;
  unsigned int new_height, h_scale;
  unsigned int resize_width_increment = 0;
  unsigned int resize_height_increment = 0;

  if (wwin->normal_hints) {
    w_scale = (wPreferences.resize_increment + wwin->normal_hints->width_inc - 1) / wwin->normal_hints->width_inc;
    h_scale = (wPreferences.resize_increment + wwin->normal_hints->height_inc - 1) / wwin->normal_hints->height_inc;
    resize_width_increment = wwin->normal_hints->width_inc * w_scale;
    resize_height_increment = wwin->normal_hints->height_inc * h_scale;
  }
  if (resize_width_increment <= 1 && resize_height_increment <= 1) {
    resize_width_increment = wPreferences.resize_increment;
    resize_height_increment = wPreferences.resize_increment;
  }

  event->xbutton.state &= w_global.shortcut.modifiers_mask;

  CloseWindowMenu(wwin->screen_ptr);

  if (!(event->xbutton.state & ControlMask) && !WFLAGP(wwin, no_focusable))
    wSetFocusTo(wwin->screen_ptr, wwin);

  if (event->xbutton.button == Button1)
    wRaiseFrame(wwin->frame->core);

  if (event->xbutton.state & ControlMask) {
    if (event->xbutton.button == Button4) {
      new_width = wwin->client.width - resize_width_increment;
      wWindowConstrainSize(wwin, &new_width, &wwin->client.height);
      wWindowConfigure(wwin, wwin->frame_x, wwin->frame_y, new_width, wwin->client.height);
    }
    if (event->xbutton.button == Button5) {
      new_width = wwin->client.width + resize_width_increment;
      wWindowConstrainSize(wwin, &new_width, &wwin->client.height);
      wWindowConfigure(wwin, wwin->frame_x, wwin->frame_y, new_width, wwin->client.height);
    }
  }

  if (event->xbutton.state & MOD_MASK) {
    /* move the window */
    if (XGrabPointer(dpy, wwin->client_win, False,
                     ButtonMotionMask | ButtonReleaseMask | ButtonPressMask,
                     GrabModeAsync, GrabModeAsync, None, None, CurrentTime) != GrabSuccess) {
      return;
    }
    if (event->xbutton.button == Button3) {
      wMouseResizeWindow(wwin, event);
    } else if (event->xbutton.button == Button4) {
      new_height = wwin->client.height - resize_height_increment;
      wWindowConstrainSize(wwin, &wwin->client.width, &new_height);
      wWindowConfigure(wwin, wwin->frame_x, wwin->frame_y, wwin->client.width, new_height);
    } else if (event->xbutton.button == Button5) {
      new_height = wwin->client.height + resize_height_increment;
      wWindowConstrainSize(wwin, &wwin->client.width, &new_height);
      wWindowConfigure(wwin, wwin->frame_x, wwin->frame_y, wwin->client.width, new_height);
    } else if (event->xbutton.button == Button1 || event->xbutton.button == Button2) {
      wMouseMoveWindow(wwin, event);
    }
    XUngrabPointer(dpy, CurrentTime);
  }
}

static void titlebarMouseDown(WCoreWindow *sender, void *data, XEvent *event)
{
  WWindow *wwin = (WWindow *) data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) sender;

  /* Mouse scroll up and down - do nothing.
     Unfocused window can shaded without focus switch */
  if (!event->xbutton.state &&
      (event->xbutton.button == Button4 || event->xbutton.button == Button5))
    return;

#ifndef NUMLOCK_HACK
  if ((event->xbutton.state & ValidModMask) != (event->xbutton.state & ~LockMask))
    wwarning(_("The NumLock, ScrollLock or similar key seems to be turned on. "
               "Turn it off or some mouse actions and keyboard shortcuts will not work."));
#endif
  event->xbutton.state &= w_global.shortcut.modifiers_mask;

  CloseWindowMenu(wwin->screen_ptr);

  /* wmessage("[window.c] xbutton.state: %i, Command mask: %i Alternate mask: %i\n", */
  /*         event->xbutton.state, wXModifierFromKey("MOD1"), */
  /*         wXModifierFromKey("MOD4")); */

  if (event->xbutton.button == Button1
      && !(event->xbutton.state & MOD_MASK) // not Mod4, Alternate
      && !(event->xbutton.state & ALT_MOD_MASK) // not Mod1, Command
      && !WFLAGP(wwin, no_focusable)) { // focusable
    wSetFocusTo(wwin->screen_ptr, wwin);
  }

  // Handle Click, Shift + Click and Command + Click
  if (event->xbutton.button == Button1 || event->xbutton.button == Button2) {
    if (event->xbutton.button == Button1) {
      if (event->xbutton.state & ALT_MOD_MASK) // Command + Click
        wLowerFrame(wwin->frame->core);
      else
        wRaiseFrame(wwin->frame->core);
    }
    // Shift + Click
    if ((event->xbutton.state & ShiftMask) && !(event->xbutton.state & ControlMask)) {
      wSelectWindow(wwin, !wwin->flags.selected);
      return;
    }
#ifndef NEXTSPACE
    if (event->xbutton.window != wwin->frame->titlebar->window
        && XGrabPointer(dpy, wwin->frame->titlebar->window, False,
                        ButtonMotionMask | ButtonReleaseMask | ButtonPressMask,
                        GrabModeAsync, GrabModeAsync, None, None, CurrentTime) != GrabSuccess) {
      return;
    }

    /* move the window */
    wMouseMoveWindow(wwin, event);

    XUngrabPointer(dpy, CurrentTime);
#endif
  }
  else if (event->xbutton.button == Button3
           && !wwin->flags.internal_window
           && !WCHECK_STATE(WSTATE_MODAL)) {
    WObjDescriptor *desc;

    if (event->xbutton.window != wwin->frame->titlebar->window
        && XGrabPointer(dpy, wwin->frame->titlebar->window, False,
                        ButtonMotionMask | ButtonReleaseMask | ButtonPressMask,
                        GrabModeAsync, GrabModeAsync, None, None, CurrentTime) != GrabSuccess) {
      return;
    }

    OpenWindowMenu(wwin, event->xbutton.x_root, wwin->frame_y + wwin->frame->top_width, False);

    /* allow drag select */
    desc = &wwin->screen_ptr->window_menu->menu->descriptor;
    event->xany.send_event = True;
    (*desc->handle_mousedown) (desc, event);

    XUngrabPointer(dpy, CurrentTime);
  }
}

static void windowCloseClick(WCoreWindow *sender, void *data, XEvent *event)
{
  WWindow *wwin = data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) sender;

  event->xbutton.state &= w_global.shortcut.modifiers_mask;

  CloseWindowMenu(wwin->screen_ptr);

  if (event->xbutton.button < Button1 || event->xbutton.button > Button3)
    return;

  /* if control-click or modifier-click, kill the client */
  if (event->xbutton.state & ControlMask || event->xbutton.state & MOD_MASK) {
    wClientKill(wwin);
  } else {
    if (wwin->protocols.DELETE_WINDOW && event->xbutton.state == 0) {
      /* send delete message */
      wClientSendProtocol(wwin, w_global.atom.wm.delete_window,
                          w_global.timestamp.last_event);
    }
  }
}

static void windowCloseDblClick(WCoreWindow *sender, void *data, XEvent *event)
{
  WWindow *wwin = data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) sender;

  CloseWindowMenu(wwin->screen_ptr);

  if (event->xbutton.button < Button1 || event->xbutton.button > Button3)
    return;

  /* send delete message */
  if (wwin->protocols.DELETE_WINDOW)
    wClientSendProtocol(wwin, w_global.atom.wm.delete_window,
                        w_global.timestamp.last_event);
  else
    wClientKill(wwin);
}

#ifdef XKB_BUTTON_HINT
static void windowLanguageClick(WCoreWindow *sender, void *data, XEvent *event)
{
  WWindow *wwin = data;
  WFrameWindow *fwin = wwin->frame;
  WScreen *scr = fwin->screen_ptr;
  int tl;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) sender;

  if (event->xbutton.button != Button1 && event->xbutton.button != Button3)
    return;
  tl = wwin->frame->languagemode;
  wwin->frame->languagemode = wwin->frame->last_languagemode;
  wwin->frame->last_languagemode = tl;
  wSetFocusTo(scr, wwin);
  wwin->frame->languagebutton_image =
    wwin->frame->screen_ptr->b_pixmaps[WBUT_XKBGROUP1 + wwin->frame->languagemode];
  wFrameWindowUpdateLanguageButton(wwin->frame);
  if (event->xbutton.button == Button3)
    return;
  wRaiseFrame(fwin->core);
}
#endif

static void windowIconifyClick(WCoreWindow *sender, void *data, XEvent *event)
{
  WWindow *wwin = data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) sender;

  event->xbutton.state &= w_global.shortcut.modifiers_mask;

  CloseWindowMenu(wwin->screen_ptr);

  if (event->xbutton.button < Button1 || event->xbutton.button > Button3)
    return;

  if (event->xbutton.button == Button1 && event->xbutton.state == 0) {
    if (wwin->protocols.MINIATURIZE_WINDOW) {
      wClientSendProtocol(wwin, w_global.atom.gnustep.wm_miniaturize_window,
                          w_global.timestamp.last_event);
    }
    else {
      wIconifyWindow(wwin);
    }
  }
#ifdef NEXTSPACE
  else if (event->xbutton.button == Button1 && event->xbutton.state & MOD_MASK) {
    if (wwin->flags.maximized) {
      wUnmaximizeWindow(wwin);
    }
    else {
      wMaximizeWindow(wwin, MAX_VERTICAL | MAX_HORIZONTAL);
    }
  }
#endif
  else if (event->xbutton.button == Button3) {
    WApplication *wapp = wApplicationOf(wwin->main_window);
    if (wwin->protocols.HIDE_APP) {
      wClientSendProtocol(wwin, w_global.atom.gnustep.wm_hide_app,
                          event->xbutton.time);
    }
    else if (wapp && !WFLAGP(wwin, no_appicon)) {
      wHideApplication(wapp);
    }
  }
}

/* static char *windowLevelDescription(WWindow *wwin) */
/* { */
  
/* } */

void wPrintWindowFocusState(WWindow *wwin, char *prefix)
{
  WWindow *focused_win = NULL;
  Window  fwin;
  int     rev;
  WWindow *x_focused_win = NULL;
  
  XGetInputFocus(dpy, &fwin, &rev);
  x_focused_win = wWindowFor(fwin);

  if (wwin)
    focused_win = wwin->screen_ptr->focused_window;

  wmessage("%s %lu (%s:%s) [WM focused: %lu (%s:%s)] [X focused: %lu (%s:%s)]",
            prefix,
            (wwin && wwin->client_win) ? wwin->client_win : 0,
            (wwin && wwin->wm_instance) ? wwin->wm_instance : "",
            (wwin && (WINDOW_LEVEL(wwin) == NSMainMenuWindowLevel)) ? "menu" : "window",
            
            (focused_win && focused_win->client_win) ? focused_win->client_win : 0,
            (focused_win && focused_win->wm_instance) ? focused_win->wm_instance : 0,
            (focused_win && (WINDOW_LEVEL(focused_win) == NSMainMenuWindowLevel)) ? "menu" : "window",
            
            (x_focused_win && x_focused_win->client_win) ? x_focused_win->client_win : 0,
            (x_focused_win && x_focused_win->wm_instance) ? x_focused_win->wm_instance : "",
            (x_focused_win && (WINDOW_LEVEL(x_focused_win) == NSMainMenuWindowLevel)) ? "menu" : "window");
  
  return;
}
