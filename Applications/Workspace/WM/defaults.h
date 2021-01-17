/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
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

#ifndef __WORKSPACE_WM_DEFAULTS__
#define __WORKSPACE_WM_DEFAULTS__

#include <CoreFoundation/CoreFoundation.h>

#include "screen.h"
#include "window.h"

typedef struct WDDomain {
  CFStringRef            name;
  CFMutableDictionaryRef dictionary;
  CFURLRef               path;
  CFAbsoluteTime         timestamp;
#ifdef HAVE_INOTIFY
  int                    inotify_watch;
#endif
} WDDomain;

/* Mouse cursors */
typedef enum {
  WCUR_NORMAL,
  WCUR_MOVE,
  WCUR_RESIZE,
  WCUR_TOPLEFTRESIZE,
  WCUR_TOPRIGHTRESIZE,
  WCUR_BOTTOMLEFTRESIZE,
  WCUR_BOTTOMRIGHTRESIZE,
  WCUR_VERTICALRESIZE,
  WCUR_HORIZONRESIZE,
  WCUR_UPRESIZE,
  WCUR_DOWNRESIZE,
  WCUR_LEFTRESIZE,
  WCUR_RIGHTRESIZE,
  WCUR_WAIT,
  WCUR_ARROW,
  WCUR_QUESTION,
  WCUR_TEXT,
  WCUR_SELECT,
  WCUR_ROOT,
  WCUR_EMPTY,

  /* Count of the number of cursors defined */
  WCUR_LAST
} w_cursor;

extern struct WPreferences {
  char *image_paths;                 /* : separated list of paths to find images */
  char *logger_shell;                /* shell to log child stdi/o */
  RImage *button_images;             /* titlebar button images */
  char smooth_workspace_back;
  signed char size_display;          /* display type for resize geometry */
  signed char move_display;          /* display type for move geometry */
  signed char window_placement;      /* window placement mode */
  signed char colormap_mode;         /* colormap focus mode */

  char opaque_move;                  /* update window position during move */
  char opaque_resize;                /* update window position during resize */
  char opaque_move_resize_keyboard;  /* update window position during move,resize with keyboard */
  char wrap_menus;                   /* wrap menus at edge of screen */
  char scrollable_menus;             /* let them be scrolled */
  char vi_key_menus;                 /* use h/j/k/l to select */
  char align_menus;                  /* align menu with their parents */
  char use_saveunders;               /* turn on SaveUnders for menus, icons etc. */
  char no_window_over_dock;
  char no_window_over_icons;
  WMPoint window_place_origin;        /* Offset for windows placed on screen */

  char constrain_window_size;        /* don't let windows get bigger than screen */
  char windows_cycling;              /* windoze cycling */
  char circ_raise;                   /* raise window after Alt-tabbing */
  char ignore_focus_click;
  char open_transients_with_parent;  /* open transient window in same workspace as parent */
  signed char title_justification;   /* titlebar text alignment */
  int window_title_clearance;
  int window_title_min_height;
  int window_title_max_height;
  int menu_title_clearance;
  int menu_title_min_height;
  int menu_title_max_height;
  int menu_text_clearance;
  char multi_byte_text;
  char no_dithering;                 /* use dithering or not */
  char no_animations;                /* enable/disable animations */
  char no_autowrap;                  /* wrap workspace when window is moved to the edge */
  char window_snapping;              /* enable window snapping */
  int snap_edge_detect;              /* how far from edge to begin snap */
  int snap_corner_detect;            /* how far from corner to begin snap */
  char drag_maximized_window;        /* behavior when a maximized window is dragged */

  char auto_arrange_icons;           /* automagically arrange icons */
  char icon_box_position;            /* position to place icons */
  signed char iconification_style;   /* position to place icons */
  char disable_root_mouse;           /* disable button events in root window */
  char auto_focus;                   /* focus window when it's mapped */
  char *icon_back_file;              /* background image for icons */

  WMPoint *root_menu_pos;             /* initial position of the root menu*/
  WMPoint *app_menu_pos;
  WMPoint *win_menu_pos;

  signed char icon_yard;             /* aka iconbox */

  int raise_delay;                   /* delay for autoraise. 0 is disabled */
  int cmap_size;                     /* size of dithering colormap in colors per channel */

  int icon_size;                     /* size of the icon */
  signed char menu_style;            /* menu decoration style */
  signed char workspace_name_display_position;
  unsigned int modifier_mask;        /* mask to use as kbd modifier - Alternate */
  unsigned int alt_modifier_mask;    /* mask to use as kbd modifier - Command */
  char *modifier_labels[7];          /* Names of the modifiers */

  unsigned int supports_tiff;        /* Use tiff files */

  char ws_advance;                   /* Create new workspace and advance */
  char ws_cycle;                     /* Cycle existing workspaces */
  char save_session_on_exit;         /* automatically save session on exit */
  char sticky_icons;                 /* If miniwindows will be onmipresent */
  char dont_confirm_kill;            /* do not confirm Kill application */
  char disable_miniwindows;
  char enable_workspace_pager;
  char ignore_gtk_decoration_hints;

  char dont_blink;                   /* do not blink icon selection */

  /* Appearance options */
  char titlebar_style;               /* Use newstyle buttons */
  char superfluous;                  /* Use superfluous things */

  /* root window mouse bindings */
  signed char mouse_button1;         /* action for left mouse button */
  signed char mouse_button2;         /* action for middle mouse button */
  signed char mouse_button3;         /* action for right mouse button */
  signed char mouse_button8;         /* action for 4th button aka backward mouse button */
  signed char mouse_button9;         /* action for 5th button aka forward mouse button */
  signed char mouse_wheel_scroll;    /* action for mouse wheel scroll */
  signed char mouse_wheel_tilt;      /* action for mouse wheel tilt */

  /* balloon text */
  char window_balloon;
  char miniwin_title_balloon;
  char miniwin_preview_balloon;
  char appicon_balloon;
  char help_balloon;

  /* some constants */
  int dblclick_time;                 /* double click delay time in ms */

  /* animate menus */
  signed char menu_scroll_speed;     /* how fast menus are scrolled */

  /* animate icon sliding */
  signed char icon_slide_speed;      /* icon slide animation speed */

  /* shading animation */
  signed char shade_speed;

  /* bouncing animation */
  char bounce_appicons_when_urgent;
  char raise_appicons_when_bouncing;
  char do_not_make_appicons_bounce;

  int edge_resistance;
  int resize_increment;
  char attract;

  unsigned int workspace_border_size; /* Size in pixels of the workspace border */
  char workspace_border_position;     /* Where to leave a workspace border */
  char single_click;                  /* single click to lauch applications */
  int history_lines;                  /* history of "Run..." dialog */
  char cycle_active_head_only;        /* Cycle only windows on the active head */
  char cycle_ignore_minimized;        /* Ignore minimized windows when cycling */
  char strict_windoze_cycle;          /* don't close switch panel when shift is released */
  char panel_only_open;               /* Only open the switch panel; don't switch */
  int minipreview_size;               /* Size of Mini-Previews in pixels */

  /* All delays here are in ms. 0 means instant auto-action. */
  int clip_auto_raise_delay;          /* Delay after which the clip will be raised when entered */
  int clip_auto_lower_delay;          /* Delay after which the clip will be lowered when leaved */
  int clip_auto_expand_delay;         /* Delay after which the clip will expand when entered */
  int clip_auto_collapse_delay;       /* Delay after which the clip will collapse when leaved */

  RImage *swtileImage;
  RImage *swbackImage[9];

  union WTexture *wsmbackTexture;

  char show_clip_title;

  struct {
#ifdef USE_ICCCM_WMREPLACE
    unsigned int replace:1;               /* replace existing window manager */
#endif
    unsigned int nodock:1;                /* don't display the dock */
    unsigned int noclip:1;                /* don't display the clip */
    unsigned int clip_merged_in_dock:1;   /* disable clip, switch workspaces with dock */
    unsigned int nodrawer:1;              /* don't use drawers */
    unsigned int wrap_appicons_in_dock:1; /* Whether to wrap appicons when Dock is moved up and down */
    unsigned int noupdates:1;             /* don't require ~/GNUstep (-static) */
    unsigned int noautolaunch:1;          /* don't autolaunch apps */
    unsigned int norestore:1;             /* don't restore session */
    unsigned int restarting:2;
  } flags;                                      /* internal flags */

  /* Map table between w_cursor and actual X id */
  Cursor cursor[WCUR_LAST];

} wPreferences;

WDDomain *wDefaultsInitDomain(const char *domain_name, Bool shouldTrackChanges);
void wDefaultsReadStatic(CFMutableDictionaryRef dict);
void wDefaultsRead(WScreen *scr, CFMutableDictionaryRef new_dict);
void wDefaultsUpdateDomainsIfNeeded(void* arg);

#ifdef HAVE_INOTIFY
void wDefaultsShouldTrackChanges(WDDomain *domain, Bool shouldTrack);
#endif

/* Default images path */
#define DEF_IMAGE_PATHS                                 \
  "(\"~/Library/Images/\",                              \
    \"/Library/Images/\",                               \
    \"/usr/NextSpace/Images/\",                         \
    \"/usr/NextSpace/Apps/Workspace.app/Resources/\")"
/* default fonts */
#define DEF_TITLE_FONT			"\"Helvetica:bold:pixelsize=12\""
#define DEF_MENU_TITLE_FONT		"\"Helvetica:bold:pixelsize=12\""
#define DEF_MENU_ENTRY_FONT		"\"Helvetica:pixelsize=12\""
#define DEF_ICON_TITLE_FONT		"\"Helvetica:pixelsize=9\""
#define DEF_CLIP_TITLE_FONT		"\"Helvetica:pixelsize=10\""
#define DEF_INFO_TEXT_FONT		"\"Helvetica:pixelsize=12\""
#define DEF_WORKSPACE_NAME_FONT		"\"Helvetica:pixelsize=24\""
#define DEF_WINDOW_TITLE_EXTEND_SPACE	"0"
#define DEF_MENU_TITLE_EXTEND_SPACE	"0"
#define DEF_MENU_TEXT_EXTEND_SPACE	"0"

#ifndef HAVE_INOTIFY
/* Check defaults database for changes every this many milliseconds */
#define DEFAULTS_CHECK_INTERVAL	3000
#endif

/* window placement mode */
#define WPM_MANUAL	0
#define WPM_CASCADE	1
#define WPM_SMART	2
#define WPM_RANDOM	3
#define WPM_AUTO        4
#define WPM_CENTER      5

/* text justification */
#define WTJ_CENTER	0
#define WTJ_LEFT	1
#define WTJ_RIGHT	2

/* iconification styles */
#define WIS_ZOOM        0
#define WIS_TWIST       1
#define WIS_FLIP        2
#define WIS_NONE        3
#define WIS_RANDOM	4 /* secret */

/* speeds */
#define SPEED_ULTRAFAST 0
#define SPEED_FAST	1
#define SPEED_MEDIUM	2
#define SPEED_SLOW	3
#define SPEED_ULTRASLOW 4

/* workspace actions */
#define WA_NONE                 0
#define WA_SELECT_WINDOWS       1
#define WA_OPEN_APPMENU         2
#define WA_OPEN_WINLISTMENU     3
#define WA_SWITCH_WORKSPACES    4
#define WA_MOVE_PREVWORKSPACE   5
#define WA_MOVE_NEXTWORKSPACE   6
#define WA_SWITCH_WINDOWS       7
#define WA_MOVE_PREVWINDOW      8
#define WA_MOVE_NEXTWINDOW      9

/* workspace display position */
#define WD_NONE		0
#define WD_CENTER	1
#define WD_TOP		2
#define WD_BOTTOM	3
#define WD_TOPLEFT	4
#define WD_TOPRIGHT	5
#define WD_BOTTOMLEFT	6
#define WD_BOTTOMRIGHT	7

/* workspace border position */
#define	WB_NONE		0
#define	WB_LEFTRIGHT	1
#define	WB_TOPBOTTOM	2
#define WB_ALLDIRS      (WB_LEFTRIGHT|WB_TOPBOTTOM)

/* menu styles */
#define MS_NORMAL		0
#define MS_SINGLE_TEXTURE	1
#define MS_FLAT			2

/* titlebar style */
#define TS_NEW		0
#define TS_OLD		1

/* colormap change mode */
#define WCM_CLICK	0
#define WCM_POINTER	1

/* clip title colors */
#define CLIP_NORMAL	0
#define CLIP_COLLAPSED	1

/* icon yard position */
#define	IY_VERT		1
#define	IY_HORIZ	0
#define	IY_TOP		2
#define	IY_BOTTOM	0
#define	IY_RIGHT	4
#define	IY_LEFT		0

/* drag maximized window behaviors */
enum {
  DRAGMAX_MOVE,
  DRAGMAX_RESTORE,
  DRAGMAX_UNMAXIMIZE,
  DRAGMAX_NOMOVE
};

/* --- Key bindings --- */

/* <X11/X.h> doesn't define these, even though XFree supports them */
#ifndef Button6
#define Button6 6
#endif

#ifndef Button7
#define Button7 7
#endif

#ifndef Button8
#define Button8 8
#endif

#ifndef Button9
#define Button9 9
#endif

enum {
      /* anywhere */
      WKBD_WINDOWMENU,
      WKBD_WINDOWLIST,

      /* window */
      WKBD_MINIATURIZE,
      WKBD_MINIMIZEALL,
      WKBD_HIDE,
      WKBD_HIDE_OTHERS,
      WKBD_MAXIMIZE,
      WKBD_VMAXIMIZE,
      WKBD_HMAXIMIZE,
      WKBD_LHMAXIMIZE,
      WKBD_RHMAXIMIZE,
      WKBD_THMAXIMIZE,
      WKBD_BHMAXIMIZE,
      WKBD_LTCMAXIMIZE,
      WKBD_RTCMAXIMIZE,
      WKBD_LBCMAXIMIZE,
      WKBD_RBCMAXIMIZE,
      WKBD_MAXIMUS,
      WKBD_SELECT,
      WKBD_OMNIPRESENT,
      WKBD_RAISE,
      WKBD_LOWER,
      WKBD_RAISELOWER,
      WKBD_MOVERESIZE,
      WKBD_SHADE,
      WKBD_WORKSPACEMAP,
      WKBD_FOCUSNEXT,
      WKBD_FOCUSPREV,
      WKBD_GROUPNEXT,
      WKBD_GROUPPREV,

      /* window, menu */
      WKBD_CLOSE,

      /* Dock and Icon Yard*/
      WKBD_DOCKRAISELOWER,
      WKBD_DOCKHIDESHOW,
      WKBD_YARDHIDESHOW,

      /* Clip */
      WKBD_CLIPRAISELOWER,

      /* workspace */
      WKBD_WORKSPACE1,
      WKBD_WORKSPACE2,
      WKBD_WORKSPACE3,
      WKBD_WORKSPACE4,
      WKBD_WORKSPACE5,
      WKBD_WORKSPACE6,
      WKBD_WORKSPACE7,
      WKBD_WORKSPACE8,
      WKBD_WORKSPACE9,
      WKBD_WORKSPACE10,
      WKBD_NEXTWORKSPACE,
      WKBD_PREVWORKSPACE,
      WKBD_LASTWORKSPACE,
      WKBD_NEXTWSLAYER,
      WKBD_PREVWSLAYER,

      /* move to workspace */
      WKBD_MOVE_WORKSPACE1,
      WKBD_MOVE_WORKSPACE2,
      WKBD_MOVE_WORKSPACE3,
      WKBD_MOVE_WORKSPACE4,
      WKBD_MOVE_WORKSPACE5,
      WKBD_MOVE_WORKSPACE6,
      WKBD_MOVE_WORKSPACE7,
      WKBD_MOVE_WORKSPACE8,
      WKBD_MOVE_WORKSPACE9,
      WKBD_MOVE_WORKSPACE10,
      WKBD_MOVE_NEXTWORKSPACE,
      WKBD_MOVE_PREVWORKSPACE,
      WKBD_MOVE_LASTWORKSPACE,
      WKBD_MOVE_NEXTWSLAYER,
      WKBD_MOVE_PREVWSLAYER,

      /* window shortcuts */
      WKBD_WINDOW1,
      WKBD_WINDOW2,
      WKBD_WINDOW3,
      WKBD_WINDOW4,
      WKBD_WINDOW5,
      WKBD_WINDOW6,
      WKBD_WINDOW7,
      WKBD_WINDOW8,
      WKBD_WINDOW9,
      WKBD_WINDOW10,

      /* launch a new instance of the active window */
      WKBD_RELAUNCH,

      /* open "run" dialog */
      WKBD_RUN,
      
      /* keep this last */
      WKBD_LAST
};

typedef struct WShortKey {
  unsigned int modifier;
  KeyCode keycode;
} WShortKey;

extern WShortKey wKeyBindings[WKBD_LAST];

#endif /* __WORKSPACE_WM_DEFAULTS__ */
