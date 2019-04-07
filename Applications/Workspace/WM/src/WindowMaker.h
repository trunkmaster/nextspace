/*
 *  Window Maker window manager
 *
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

#ifndef WINDOWMAKER_H_
#define WINDOWMAKER_H_

#include "wconfig.h"
#include <assert.h>
#include <limits.h>
#include <WINGs/WINGs.h>


/* class codes */
typedef enum {
  WCLASS_UNKNOWN = 0,
  WCLASS_WINDOW = 1,          /* managed client windows */
  WCLASS_MENU = 2,            /* root menus */
  WCLASS_APPICON = 3,
  WCLASS_DUMMYWINDOW = 4,     /* window that holds window group leader */
  WCLASS_MINIWINDOW = 5,
  WCLASS_DOCK_ICON = 6,
  WCLASS_PAGER = 7,
  WCLASS_TEXT_INPUT = 8,
  WCLASS_FRAME = 9
} WClassType;


/*
 * generic window levels (a superset of the N*XTSTEP ones)
 * Applications should use levels between WMDesktopLevel and
 * WMScreensaverLevel anything boyond that range is allowed,
 * but discouraged.
 */
enum {
  WMBackLevel = INT_MIN+1,    /* Very lowest level */
  WMDesktopLevel = -1000,     /* Lowest level of normal use */
  WMSunkenLevel = -1,
  WMNormalLevel = 0,
  WMFloatingLevel = 3,
  WMDockLevel = 5,
  WMSubmenuLevel = 10,
  WMMainMenuLevel = 20,
  WMStatusLevel = 21,
  WMModalLevel = 100,
  WMPopUpLevel = 101,
  WMScreensaverLevel = 1000,
  WMOuterSpaceLevel = INT_MAX
};

/*
 * WObjDescriptor will be used by the event dispatcher to
 * send events to a particular object through the methods in the
 * method table. If all objects of the same class share the
 * same methods, the class method table should be used, otherwise
 * a new method table must be created for each object.
 * It is also assigned to find the parent structure of a given
 * window (like the WWindow or WMenu for a button)
 */

typedef struct WObjDescriptor {
  void *self;                        /* the object that will be called */
  /* event handlers */
  void (*handle_expose)(struct WObjDescriptor *sender, XEvent *event);
  void (*handle_mousedown)(struct WObjDescriptor *sender, XEvent *event);
  void (*handle_enternotify)(struct WObjDescriptor *sender, XEvent *event);
  void (*handle_leavenotify)(struct WObjDescriptor *sender, XEvent *event);

  WClassType parent_type;            /* type code of the parent */
  void *parent;                      /* parent object (WWindow or WMenu) */
} WObjDescriptor;

/* internal buttons */
#define WBUT_CLOSE              0
#define WBUT_BROKENCLOSE        1
#define WBUT_ICONIFY            2
#define WBUT_KILL		3
#define WBUT_MAXIMIZE		4
#define WBUT_RESTORE		5
#ifdef XKB_BUTTON_HINT
#define WBUT_XKBGROUP1		6
#define WBUT_XKBGROUP2		7
#define WBUT_XKBGROUP3		8
#define WBUT_XKBGROUP4		9
#define PRED_BPIXMAPS		10 /* reserved for 4 groups */
#else
#define PRED_BPIXMAPS		6 /* count of WBUT icons */
#endif /* XKB_BUTTON_HINT */

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

/* geometry displays */
#define WDIS_NEW		0	/* new style */
#define WDIS_CENTER		1	/* center of screen */
#define WDIS_TOPLEFT		2	/* top left corner of screen */
#define WDIS_FRAME_CENTER	3	/* center of the frame */
#define WDIS_NONE		4

/* keyboard input focus mode */
#define WKF_CLICK	0
#define WKF_SLOPPY	2

/* colormap change mode */
#define WCM_CLICK	0
#define WCM_POINTER	1

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

/* switchmenu actions */
#define ACTION_ADD		0
#define ACTION_REMOVE		1
#define ACTION_CHANGE		2
#define ACTION_CHANGE_WORKSPACE	3
#define ACTION_CHANGE_STATE	4


/* speeds */
#define SPEED_ULTRAFAST 0
#define SPEED_FAST	1
#define SPEED_MEDIUM	2
#define SPEED_SLOW	3
#define SPEED_ULTRASLOW 4


/* window states */
#define WS_FOCUSED	0
#define WS_UNFOCUSED	1
#define WS_PFOCUSED	2

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


/* menu styles */
#define MS_NORMAL		0
#define MS_SINGLE_TEXTURE	1
#define MS_FLAT			2

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

/* titlebar style */
#define TS_NEW		0
#define TS_OLD		1
#define TS_NEXT		2

/* workspace border position */
#define	WB_NONE		0
#define	WB_LEFTRIGHT	1
#define	WB_TOPBOTTOM	2
#define WB_ALLDIRS      (WB_LEFTRIGHT|WB_TOPBOTTOM)

/* drag maximized window behaviors */
enum {
  DRAGMAX_MOVE,
  DRAGMAX_RESTORE,
  DRAGMAX_UNMAXIMIZE,
  DRAGMAX_NOMOVE
};

/* program states */
typedef enum {
  WSTATE_NORMAL		= 0,
  WSTATE_NEED_EXIT	= 1,
  WSTATE_NEED_RESTART	= 2,
  WSTATE_EXITING		= 3,
  WSTATE_RESTARTING	= 4,
  WSTATE_MODAL		= 5,
  WSTATE_NEED_REREAD	= 6
} wprog_state;


#define WCHECK_STATE(chk_state)	(w_global.program.state == (chk_state))


#define WCHANGE_STATE(nstate) {                                 \
    if (w_global.program.state == WSTATE_NORMAL                 \
        || (nstate) != WSTATE_MODAL)                            \
      w_global.program.state = (nstate);                        \
    if (w_global.program.signal_state != 0)			\
      w_global.program.state = w_global.program.signal_state;	\
  }


/* only call inside signal handlers, with signals blocked */
#define SIG_WCHANGE_STATE(nstate) {             \
    w_global.program.signal_state = (nstate);	\
    w_global.program.state = (nstate);		\
  }


/* Flags for the Window Maker state when restarting/crash situations */
#define WFLAGS_NONE       (0)
#define WFLAGS_CRASHED    (1<<0)


/* notifications */

#ifdef MAINFILE
#define NOTIFICATION(n) const char WN##n [] = #n
#else
#define NOTIFICATION(n) extern const char WN##n []
#endif

NOTIFICATION(WindowAppearanceSettingsChanged);

NOTIFICATION(IconAppearanceSettingsChanged);

NOTIFICATION(IconTileSettingsChanged);

NOTIFICATION(MenuAppearanceSettingsChanged);

NOTIFICATION(MenuTitleAppearanceSettingsChanged);


/* appearance settings clientdata flags */
enum {
  WFontSettings = 1 << 0,
  WTextureSettings = 1 << 1,
  WColorSettings = 1 << 2
};



typedef struct {
  int x1, y1;
  int x2, y2;
} WArea;

typedef struct WCoord {
  int x, y;
} WCoord;

extern struct WPreferences {
  char *pixmap_path;                 /* : separated list of paths to find pixmaps */
  char *icon_path;                   /* : separated list of paths to find icons */
  WMArray *fallbackWMs;              /* fallback window manager list */
  char *logger_shell;                /* shell to log child stdi/o */
  RImage *button_images;             /* titlebar button images */
  char smooth_workspace_back;
  signed char size_display;          /* display type for resize geometry */
  signed char move_display;          /* display type for move geometry */
  signed char window_placement;      /* window placement mode */
  signed char colormap_mode;         /* colormap focus mode */
  signed char focus_mode;            /* window focusing mode */

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
  WCoord window_place_origin;        /* Offset for windows placed on screen */

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
#ifdef KEEP_XKB_LOCK_STATUS
  char modelock;
#endif
  char no_dithering;                 /* use dithering or not */
  char no_animations;                /* enable/disable animations */
  char no_autowrap;                  /* wrap workspace when window is moved to the edge */
  char window_snapping;              /* enable window snapping */
  int snap_edge_detect;              /* how far from edge to begin snap */
  int snap_corner_detect;            /* how far from corner to begin snap */
  char drag_maximized_window;        /* behavior when a maximized window is dragged */

  char highlight_active_app;         /* show the focused app by highlighting its icon */
  char auto_arrange_icons;           /* automagically arrange icons */
  char icon_box_position;            /* position to place icons */
  signed char iconification_style;   /* position to place icons */
  char disable_root_mouse;           /* disable button events in root window */
  char auto_focus;                   /* focus window when it's mapped */
  char *icon_back_file;              /* background image for icons */

  WCoord *root_menu_pos;             /* initial position of the root menu*/
  WCoord *app_menu_pos;
  WCoord *win_menu_pos;

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
  char new_style;                    /* Use newstyle buttons */
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

/****** Global Variables  ******/
extern Display	*dpy;

extern struct wmaker_global_variables {
  /* Tracking of the state of the program */
  struct {
    wprog_state state;
    wprog_state signal_state;
  } program;

  /* locale to use. NULL==POSIX or C */
  const char *locale;

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
    struct WDDomain *wmaker;
    struct WDDomain *window_attr;
    struct WDDomain *root_menu;
  } domain;

  /* Screens related */
  int screen_count;

  /*
   * Ignore Workspace Change:
   * this variable is used to prevent workspace switch while certain
   * operations are ongoing.
   */
  Bool ignore_workspace_change;

  /*
   * Process WorkspaceMap Event:
   * this variable is set when the Workspace Map window is being displayed,
   * it is mainly used to avoid re-opening another one at the same time
   */
  Bool process_workspacemap_event;

#ifdef HAVE_INOTIFY
  struct {
    int fd_event_queue;   /* Inotify's queue file descriptor */
    int wd_defaults;   /* Watch Descriptor for the 'Defaults' configuration file */
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

#ifdef USE_RANDR
    struct {
      Bool supported;
      int event_base;
    } randr;
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

/****** Notifications ******/
extern const char WMNManaged[];
extern const char WMNUnmanaged[];
extern const char WMNChangedWorkspace[];
extern const char WMNChangedState[];
extern const char WMNChangedFocus[];
extern const char WMNChangedStacking[];
extern const char WMNChangedName[];

extern const char WMNWorkspaceCreated[];
extern const char WMNWorkspaceDestroyed[];
extern const char WMNWorkspaceChanged[];
extern const char WMNWorkspaceNameChanged[];

extern const char WMNResetStacking[];

#endif
