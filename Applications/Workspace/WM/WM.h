/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2014 Window Maker Team
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

#ifndef __WORKSPACE_WM__
#define __WORKSPACE_WM__

#include <assert.h>
#include <limits.h>

#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFNotificationCenter.h>

#include "core/wscreen.h"
#include "core/util.h"
#include "core/drawing.h"

#include "config.h"

/*************************************************************************************************
 *  Definitions and compile time options                                                         *
 *************************************************************************************************/

/* Define to support ICCCM protocol for window manager replacement */
#undef USE_ICCCM_WMREPLACE
/* Undefine if you want to disable animations */
#define USE_ANIMATIONS
/* Whether Drag-and-Drop on the dock should be enabled */
#define USE_DOCK_XDND
/* Undefine to disable Motif WM hints handling */
#define USE_MWM_HINTS
/* Undefine if you don't want balloons for showing extra information, like window titles that
   are not fully visible. */
#define BALLOON_TEXT
/* If balloons should be shaped or be simple rectangles. The X server must support the shape
   extensions and it's support must be  enabled (default). */
#ifdef USE_XSHAPE
#define SHAPED_BALLOON
#endif
/* Turn on a hack to make mouse and keyboard actions work even if the NumLock or ScrollLock
   modifiers are turned on. They might inflict a performance/memory penalty. */
#define NUMLOCK_HACK
/* Define if you want the shape setting code to be optimized for applications that change
   their shape frequently (like xdaliclock -shape), removing flickering. If wmaker and your
   display are on different machines and the network connection is slow, it is not recommended. */
#undef OPTIMIZE_SHAPE
/* Define if you want window manager to send the synthetic ConfigureNotify event to windows
   while moving at every single movement. Default is to send a synthetic ConfigureNotify event
   only at the end of window moving, which improves performance. */
#undef CONFIGURE_WINDOW_WHILE_MOVING
/* Define if you want a dot to be shown in the application icon of applications that are hidden. */
#define HIDDENDOT
/* Ignores the PPosition hint from clients. This is needed for some programs that have buggy
   implementations of such hint and place themselves in strange locations. */
#undef IGNORE_PPOSITION
/* Define if you want a resizebar with shadows like in AfterStep, instead of the default Openstep
   look. NEXTSTEP 3.3 also does not have these shadows. */
#undef SHADOW_RESIZEBAR
/* Define if you want the window creation animation when superfluous is enabled. */
#undef WINDOW_BIRTH_ZOOM
/* Define to hide titles in miniwindows */
#undef NO_MINIWINDOW_TITLES

/*
 * You should not modify the following values, unless you know what you're doing.
 */

/* number of window shortcuts */
#define MAX_WINDOW_SHORTCUTS 10
//#define MIN_TITLEFONT_HEIGHT(h)   ((h)>14 ? (h) : 14)
/* window's titlebar height */
#define TITLEBAR_HEIGHT 18
/* height of the resizebar */
#define RESIZEBAR_HEIGHT 8
/* min width of handles-corner_width */
#define RESIZEBAR_MIN_WIDTH 20
/* width of the corner of resizebars */
#define RESIZEBAR_CORNER_WIDTH 28
#define MENU_INDICATOR_SPACE 12
/* minimum size for windows */
#define MIN_WINDOW_SIZE 5
/* size of the icon window */
#define ICON_WIDTH 64
#define ICON_HEIGHT 64
#define ICON_BORDER_WIDTH 2
/* size of the icon pixmap */
#define MAX_ICON_WIDTH 60
#define MAX_ICON_HEIGHT 48
#define MAX_DESKTOPS 100
#define MAX_MENU_TEXT_LENGTH 512
#define MAX_RESTART_ARGS 16
#define MAX_DEAD_PROCESSES 128
#define MAXLINE 1024

#ifdef _MAX_PATH
#define DEFAULT_PATH_MAX _MAX_PATH
#else
#define DEFAULT_PATH_MAX 512
#endif

#ifdef USE_XKB
#define KEEP_XKB_LOCK_STATUS
#endif

#if !defined(__OBJC__)

#if defined(HAVE_LIBINTL_H) && defined(I18N)
#include <libintl.h>
#define _(text) gettext(text)
/* Use N_() in initializers, it will make xgettext pick the string up for translation */
#define N_(text) (text)
#if defined(MENU_TEXTDOMAIN)
#define M_(text) dgettext(MENU_TEXTDOMAIN, text)
#else
#define M_(text) (text)
#endif
#else
#define _(text) text
#define N_(text) text
#define M_(text) text
#endif /* HAVE_LIBINTL_H && I18N */

#endif /* !__OBJC__ */

/* class codes */
typedef enum {
  WCLASS_UNKNOWN = 0,
  WCLASS_WINDOW = 1, /* managed client windows */
  WCLASS_MENU = 2,   /* root menus */
  WCLASS_APPICON = 3,
  WCLASS_DUMMYWINDOW = 4, /* window that holds window group leader */
  WCLASS_MINIWINDOW = 5,
  WCLASS_DOCK_ICON = 6,
  WCLASS_PAGER = 7,
  WCLASS_TEXT_INPUT = 8,
  WCLASS_FRAME = 9
} WClassType;

/*
 * WObjDescriptor will be used by the event dispatcher to send events to a particular object
 * through the methods in the method table. If all objects of the same class share the same
 * methods, the class method table should be used, otherwise a new method table must be created
 * for each object.
 * It is also assigned to find the parent structure of a given window (like the WWindow or
 * WMenu for a button)
 */
typedef struct WObjDescriptor {
  void *self; /* the object that will be called */
  /* event handlers */
  void (*handle_expose)(struct WObjDescriptor *sender, XEvent *event);
  void (*handle_mousedown)(struct WObjDescriptor *sender, XEvent *event);
  void (*handle_enternotify)(struct WObjDescriptor *sender, XEvent *event);
  void (*handle_leavenotify)(struct WObjDescriptor *sender, XEvent *event);

  WClassType parent_type; /* type code of the parent */
  void *parent;           /* parent object (WWindow or WMenu) */
} WObjDescriptor;

/* internal buttons */
#define WBUT_CLOSE 0
#define WBUT_BROKENCLOSE 1
#define WBUT_ICONIFY 2
#define WBUT_KILL 3
#define WBUT_MAXIMIZE 4
#define WBUT_RESTORE 5
#define PRED_BPIXMAPS 6 /* count of WBUT icons */

/* program states */
typedef enum {
  WSTATE_NORMAL = 0,
  WSTATE_EXITING = 1,
  WSTATE_MODAL = 2,
  WSTATE_NEED_EXIT = 10,     // SIGTERM, SIGINT, SIGHUP
  WSTATE_NEED_RESTART = 11,  // SIGUSR1
  WSTATE_RESTARTING = 12,
  WSTATE_NEED_REREAD = 13  // SIGUSR2
} wprog_state;
#define WCHECK_STATE(chk_state) (w_global.program.state == (chk_state))
#define WCHANGE_STATE(nstate)                                                \
  {                                                                          \
    if (w_global.program.state == WSTATE_NORMAL || (nstate) != WSTATE_MODAL) \
      w_global.program.state = (nstate);                                     \
    if (w_global.program.signal_state != 0)                                  \
      w_global.program.state = w_global.program.signal_state;                \
  }

/* Flags for the WM state when restarting/crash situations */
#define WFLAGS_NONE (0)
#define WFLAGS_CRASHED (1 << 0)

/* appearance settings clientdata flags */
enum { WFontSettings = 1 << 0, WTextureSettings = 1 << 1, WColorSettings = 1 << 2 };

typedef struct {
  int x1, y1;
  int x2, y2;
} WArea;

/****** Global Variables  ******/
extern Display *dpy;

extern struct wm_global_variables {
  /* Tracking of the state of the program */
  struct {
    wprog_state state;
    wprog_state signal_state;
  } program;

  // /* locale to use. NULL==POSIX or C */
  // const char *locale;

  /* Tracking of X events timestamps */
  struct {
    /* ts of the last event we received */
    Time last_event;

    /* ts on the last time we did XSetInputFocus() */
    Time focus_change;

  } timestamp;

  /* Global Domains, for storing dictionaries */
  struct {
    /* Note: you must #include <defaults.h> if you want to use them */
    struct WDDomain *wm_state;
    struct WDDomain *wm_preferences;
    struct WDDomain *window_attrs;
    struct WDDomain *root_menu;
  } domain;

  /* Screens related */
  /* int screen_count; */

  /*
   * Ignore Workspace Change:
   * this variable is used to prevent workspace switch while certain
   * operations are ongoing.
   */
  Bool ignore_desktop_change;

  /*
   * Process WorkspaceMap Event:
   * this variable is set when the Workspace Map window is being displayed,
   * it is mainly used to avoid re-opening another one at the same time
   */
  Bool process_workspacemap_event;

#ifdef HAVE_INOTIFY
  struct {
    int fd_event_queue; /* Inotify's queue file descriptor */
    int wd_defaults;    /* Watch Descriptor for the 'Defaults' configuration file */
  } inotify;
#endif

  /* definition for X Atoms */
  struct {
    /* Window-Manager related */
    struct {
      Atom state;
      Atom change_state;
      Atom protocols;
      Atom take_focus;
      Atom delete_window;
      Atom save_yourself;
      Atom client_leader;
      Atom colormap_windows;
      Atom colormap_notify;
      Atom ignore_focus_events;
    } wm;

    /* GNUStep related */
    struct {
      Atom wm_attr;
      Atom wm_miniaturize_window;
      Atom wm_hide_app;
      Atom wm_resizebar;
      Atom titlebar_state;
    } gnustep;

    /* Destkop-environment related */
    struct {
      Atom gtk_object_path;
    } desktop;

    /* WindowMaker specific */
    struct {
      Atom menu;
      Atom wm_protocols;
      Atom state;

      Atom wm_function;
      Atom noticeboard;
      Atom command;

      Atom icon_size;
      Atom icon_tile;
    } wmaker;

  } atom;

  /* X Contexts */
  struct {
    XContext client_win;
    XContext app_win;
    XContext stack;
  } context;

  /* X Extensions */
  struct {
#ifdef USE_XSHAPE
    struct {
      Bool supported;
      int event_base;
    } shape;
#endif

#ifdef KEEP_XKB_LOCK_STATUS
    struct {
      Bool supported;
      int event_base;
    } xkb;
#endif

    /*
     * If no extension were activated, we would end up with an empty
     * structure, which old compilers may not appreciate, so let's
     * work around this with a simple:
     */
    int dummy;
  } xext;

  /* Keyboard and shortcuts */
  struct {
    /*
     * Bit-mask to hide special key modifiers which we don't want to
     * impact the shortcuts (typically: CapsLock, NumLock, ScrollLock)
     */
    unsigned int modifiers_mask;
  } shortcut;
} w_global;

/* CoreFoundation notifications -- initialized in startup.c */
/* Applications */
extern CFStringRef WMDidCreateApplicationNotification;
extern CFStringRef WMDidDestroyApplicationNotification;
extern CFStringRef WMDidActivateApplicationNotification;
extern CFStringRef WMDidDeactivateApplicationNotification;
/* Windows */
extern CFStringRef WMDidManageWindowNotification;
extern CFStringRef WMDidUnmanageWindowNotification;
extern CFStringRef WMDidChangeWindowDesktopNotification;
extern CFStringRef WMDidChangeWindowStateNotification;
extern CFStringRef WMDidChangeWindowFocusNotification;
extern CFStringRef WMDidChangeWindowStackingNotification;
extern CFStringRef WMDidChangeWindowNameNotification;
extern CFStringRef WMDidResetWindowStackingNotification;
/* Workspaces */
extern CFStringRef WMDidCreateDesktopNotification;
extern CFStringRef WMDidDestroyDesktopNotification;
extern CFStringRef WMDidChangeDesktopNotification;
extern CFStringRef WMDidChangeDesktopNameNotification;
/* Appearance and settings - WM.plist */
extern CFStringRef WMDidChangeWindowAppearanceSettings;
extern CFStringRef WMDidChangeIconAppearanceSettings;
extern CFStringRef WMDidChangeIconTileSettings;
extern CFStringRef WMDidChangeMenuAppearanceSettings;
extern CFStringRef WMDidChangeMenuTitleAppearanceSettings;
/* Other */
// userInfo = { "XkbGroup" = CFNumber }
extern CFStringRef WMDidChangeKeyboardLayoutNotification;

/* Notifications to communicate with applications. Manadatory prefixes in
   notification names are:
     - WMShould for notification from application to perform some action
     - WMDid to notify application about action completion
   Every WMDid should complement WMShould notification.

   All WMShould* and WMDid* notifications must contain in userInfo:
     "WindowID" = CFNumber;
     "ApplicationName" = CFString;
   Objective C definitions located in DesktopKit/NXTWorkspace.[hm].
*/
// WM.plist
extern CFStringRef WMDidChangeAppearanceSettingsNotification;
// WMState.plist
extern CFStringRef WMDidChangeDockContentNotification;
// Hide All
extern CFStringRef WMShouldHideOthersNotification;
extern CFStringRef WMDidHideOthersNotification;
// Quit or Force Quit
extern CFStringRef WMShouldTerminateApplicationNotification;
extern CFStringRef WMDidTerminateApplicationNotification;
// Zoom Window
/* additional userInfo element:
   "ZoomType" = "Vertical" | "Horizontal" | "Maximize"; */
extern CFStringRef WMShouldZoomWindowNotification;
extern CFStringRef WMDidZoomWindowNotification;
// Tile Window
/* additional userInfo element:
   "TileDirection" = "Left" | "Right" | "Top" | "Bottom"; */
extern CFStringRef WMShouldTileWindowNotification;
extern CFStringRef WMDidTileWindowNotification;
// Shade Window
extern CFStringRef WMShouldShadeWindowNotification;
extern CFStringRef WMDidShadeWindowNotification;
// Arrange in Front
extern CFStringRef WMShouldArrangeWindowsNotification;
extern CFStringRef WMDidArrangeWindowsNotification;
// Miniaturize Window
extern CFStringRef WMShouldMinmizeWindowNotification;
extern CFStringRef WMDidMinmizeWindowNotification;
// Close Window
extern CFStringRef WMShouldCloseWindowNotification;
extern CFStringRef WMDidCloseWindowNotification;

void *userInfoValueForKey(CFDictionaryRef theDict, CFStringRef key);

#endif  // __WORKSPACE_WM__
