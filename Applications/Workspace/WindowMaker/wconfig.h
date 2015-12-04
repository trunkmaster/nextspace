/*
 * wconfig.h- default configuration and definitions + compile time options
 *
 *  WindowMaker window manager
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
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef WMCONFIG_H_
#define WMCONFIG_H_

#include "config.h"

/*** Change this file (wconfig.h) *after* you ran configure ***/

/*
 *--------------------------------------------------------------------
 * 			Feature Selection
 *
 * 	Comment out the following #defines if you want to
 * disable a feature.
 * 	Also check the features you can enable through configure.
 *--------------------------------------------------------------------
 */


/*
 * #undefine if you dont want texture plugin support or your system have
 * some sort of problem with them.
 */
#define TEXTURE_PLUGIN

#ifdef TEXTURE_PLUGIN
#undef DRAWSTRING_PLUGIN
#endif


/* undefine ANIMATIONS if you don't want animations for iconification,
 * shading, icon arrangement etc. */
#define ANIMATIONS


/*
 * undefine USECPP if you don't want your config files to be preprocessed
 * by cpp
 */
#define USECPP

/* #define CPP_PATH /usr/bin/cpp */


#define NETWM_HINTS

/*
 * support for XDND drop in the Dock. Experimental
 */
/*#define XDND*/

/*
 * support for Motif window manager (mwm) window hints
 */
#define MWM_HINTS


/*
 * Undefine BALLOON_TEXT if you don't want balloons for showing extra
 * information, like window titles that are not fully visible.
 */
#define BALLOON_TEXT

/*
 * If balloons should be shaped or be simple rectangles.
 * The X server must support the shape extensions and it's support
 * must be enabled (default).
 */
#define SHAPED_BALLOON


/*
 * Turn on a hack to make mouse and keyboard actions work even if
 * the NumLock or ScrollLock modifiers are turned on. They might
 * inflict a performance/memory penalty.
 *
 * If you're an X expert (knows the implementation of XGrabKey() in X)
 * and knows that the penalty is small (or not), please tell me.
 */
#define NUMLOCK_HACK



/*
 * define OPTIMIZE_SHAPE if you want the shape setting code to be optimized
 * for applications that change their shape frequently (like xdaliclock
 * -shape), removing flickering. If wmaker and your display are on
 * different machines and the network connection is slow, it is not
 * recommended.
 */
#undef OPTIMIZE_SHAPE

/* define CONFIGURE_WINDOW_WHILE_MOVING if you want WindowMaker to send
 * the synthetic ConfigureNotify event to windows while moving at every
 * single movement. Default is to send a synthetic ConfigureNotify event
 * only at the end of window moving, which improves performance.
 */
#undef CONFIGURE_WINDOW_WHILE_MOVING


/*
 * disable/enable workspace indicator in the dock
 */
#undef WS_INDICATOR


/*
 * define HIDDENDOT if you want a dot to be shown in the application icon
 * of applications that are hidden.
 */
#define HIDDENDOT


/*
 * Ignores the PPosition hint from clients. This is needed for some
 * programs that have buggy implementations of such hint and place
 * themselves in strange locations.
 */
#undef IGNORE_PPOSITION


/*
 * Do not scale application icon and miniwindow icon images.
 */
#undef DONT_SCALE_ICONS






#define SILLYNESS





/*
 *..........................................................................
 * The following options WILL NOT BE MADE RUN-TIME. Please do not request.
 * They will only add unneeded bloat.
 *..........................................................................
 */

/*
 * define SHADOW_RESIZEBAR if you want a resizebar with shadows like in
 * AfterStep, instead of the default Openstep look.
 * NEXTSTEP 3.3 also does not have these shadows.
 */
#undef SHADOW_RESIZEBAR

/*
 * Define DEMATERIALIZE_ICON if you want the undocked icon animation
 * to be a progressive disaparison animation.
 * This will cause all application icons to be created with Save Under
 * enable.
 */
#undef DEMATERIALIZE_ICON

/*
 * Define ICON_KABOOM_EXTRA if you want extra fancy icon undocking
 * explosion animation.
 */
#undef ICON_KABOOM_EXTRA

/*
 * #define if you want the window creation animation when superfluous
 * is enabled. Only enable one of them.
 */
#undef WINDOW_BIRTH_ZOOM

#undef WINDOW_BIRTH_ZOOM2

/*
 * whether arrow drawing in clip buttons should be gradiented
 */
#undef GRADIENT_CLIP_ARROWS


/*
 *--------------------------------------------------------------------
 * 			Default Configuration
 *
 * 	Some of the following options can be configured in
 * the preference files, but if for some reason, they can't
 * be used, these defaults will be.
 * 	There are also some options that can only be configured here,
 * at compile time.
 *--------------------------------------------------------------------
 */

/* list of paths to look for the config files, searched in order
 * of appearance */
#define DEF_CONFIG_PATHS \
    "~/Library/WindowMaker:"PKGDATADIR

#define DEF_MENU_FILE	"menu"

/* name of the script to execute at startup */
#define DEF_INIT_SCRIPT "autostart"

#define DEF_EXIT_SCRIPT "exitscript"

#define DEFAULTS_DIR "/Library/Preferences"

#ifdef USE_TIFF
#define DEF_BUTTON_IMAGES PKGDATADIR"/buttons.tiff"
#else
#define DEF_BUTTON_IMAGES PKGDATADIR"/buttons.xpm"
#endif

/* the file of the system wide submenu to be forced into the main menu */
#define GLOBAL_PREAMBLE_MENU_FILE "GlobalMenu.pre"
#define GLOBAL_EPILOGUE_MENU_FILE "GlobalMenu.post"


/* pixmap path */
#define DEF_PIXMAP_PATHS \
    "(\"~/Library/WindowMaker/Pixmaps\",\""PIXMAPDIR"\")"

/* icon path */
#define DEF_ICON_PATHS \
    "(\"~/Library/Icons\",\""PIXMAPDIR"\")"


/* window title to use for untitled windows */
#define DEF_WINDOW_TITLE "Untitled"

/* default style */
#define DEF_FRAME_COLOR   "white"


#define DEF_TITLE_FONT "\"Helvetica:bold:pixelsize=12\""
#define DEF_MENU_TITLE_FONT "\"Helvetica:bold:pixelsize=12\""
#define DEF_MENU_ENTRY_FONT "\"Helvetica:pixelsize=12\""
#define DEF_ICON_TITLE_FONT "\"Helvetica:pixelsize=10\""
#define DEF_CLIP_TITLE_FONT "\"Helvetica:bold:pixelsize=10\""
#define DEF_INFO_TEXT_FONT "\"Helvetica:pixelsize=12\""

#define DEF_WORKSPACE_NAME_FONT "\"Helvetica:pixelsize=24\""


#define DEF_FRAME_THICKNESS 1	       /* linewidth of the move/resize frame */

#define DEF_WINDOW_TITLE_EXTEND_SPACE	"0"
#define DEF_MENU_TITLE_EXTEND_SPACE	"0"
#define DEF_MENU_TEXT_EXTEND_SPACE	"0"
#define TITLEBAR_EXTEND_SPACE 4

#define DEF_XPM_CLOSENESS	40000

/* default position of application menus */
#define DEF_APPMENU_X		10
#define DEF_APPMENU_Y		10

/* calculate window edge resistance from edge resistance */
#define WIN_RESISTANCE(x)	(((x)*20)/30)

/* Window level where icons reside */
#define NORMAL_ICON_LEVEL WMNormalLevel

/* do not divide main menu and submenu in different tiers,
 * opposed to OpenStep */
#define SINGLE_MENULEVEL

/* max. time to spend doing animations in seconds. If the animation
 * time exceeds this value, it is immediately finished. Usefull for
 * moments of high-load.
 */
#define MAX_ANIMATION_TIME	1

/* Zoom animation */
#define MINIATURIZE_ANIMATION_FRAMES_Z   5
#define MINIATURIZE_ANIMATION_STEPS_Z    12
#define MINIATURIZE_ANIMATION_DELAY_Z    10000
/* Twist animation */
#define MINIATURIZE_ANIMATION_FRAMES_T   12
#define MINIATURIZE_ANIMATION_STEPS_T    16
#define MINIATURIZE_ANIMATION_DELAY_T    20000
#define MINIATURIZE_ANIMATION_TWIST_T    0.5
/* Flip animation */
#define MINIATURIZE_ANIMATION_FRAMES_F   12
#define MINIATURIZE_ANIMATION_STEPS_F    16
#define MINIATURIZE_ANIMATION_DELAY_F    20000
#define MINIATURIZE_ANIMATION_TWIST_F    0.5


#define HIDE_ANIMATION_STEPS (MINIATURIZE_ANIMATION_STEPS*2/3)

/* delay before balloon is shown (ms) */
#define BALLOON_DELAY           1000

/* delay for menu item selection hysteresis (ms) */
#define MENU_SELECT_DELAY       200

/* delay for jumpback of scrolled menus (ms) */
#define MENU_JUMP_BACK_DELAY    400

/* *** animation speed constants *** */

/* icon slide */
#define ICON_SLIDE_SLOWDOWN_UF	1
#define ICON_SLIDE_DELAY_UF	0
#define ICON_SLIDE_STEPS_UF	50

#define ICON_SLIDE_SLOWDOWN_F	3
#define ICON_SLIDE_DELAY_F	0
#define ICON_SLIDE_STEPS_F	50

#define ICON_SLIDE_SLOWDOWN_M	5
#define ICON_SLIDE_DELAY_M	0
#define ICON_SLIDE_STEPS_M	30

#define ICON_SLIDE_SLOWDOWN_S	10
#define ICON_SLIDE_DELAY_S	0
#define ICON_SLIDE_STEPS_S	20

#define ICON_SLIDE_SLOWDOWN_US	20
#define ICON_SLIDE_DELAY_US	1
#define ICON_SLIDE_STEPS_US	10

/* menu scrolling */
#define MENU_SCROLL_STEPS_UF	14
#define MENU_SCROLL_DELAY_UF	1

#define MENU_SCROLL_STEPS_F	10
#define MENU_SCROLL_DELAY_F	5

#define MENU_SCROLL_STEPS_M	6
#define MENU_SCROLL_DELAY_M	5

#define MENU_SCROLL_STEPS_S	4
#define MENU_SCROLL_DELAY_S	6

#define MENU_SCROLL_STEPS_US	1
#define MENU_SCROLL_DELAY_US	8


/* shade animation */
#define SHADE_STEPS_UF		5
#define SHADE_DELAY_UF		0

#define SHADE_STEPS_F		10
#define SHADE_DELAY_F		0

#define SHADE_STEPS_M		15
#define SHADE_DELAY_M		0

#define SHADE_STEPS_S		30
#define SHADE_DELAY_S		0

#define SHADE_STEPS_US		40
#define SHADE_DELAY_US		10


/* workspace name on switch display */
#define WORKSPACE_NAME_FADE_DELAY 30

#ifdef VIRTUAL_DESKTOP
/* workspace virtual edge speed */
#define VIRTUALEDGE_SCROLL_VSTEP 30
#define VIRTUALEDGE_SCROLL_HSTEP 30
#endif

#define WORKSPACE_NAME_DELAY	400

/* window birth animation steps (DO NOT MAKE IT RUN-TIME) */
#define WINDOW_BIRTH_STEPS	20

/* number of steps for icon dematerialization. */
#define DEMATERIALIZE_STEPS	16

/* Delay when cycling colors of selected icons. */
#define COLOR_CYCLE_DELAY	200

/* size of the pieces in the undocked icon explosion */
#define ICON_KABOOM_PIECE_SIZE 4


/* Position increment for smart placement. >= 1  raise these values if it's
 * too slow for you */
#define PLACETEST_HSTEP	8
#define PLACETEST_VSTEP	8


#define DOCK_EXTRA_SPACE	3

/* Vicinity in which an icon can be attached to the clip */
#define CLIP_ATTACH_VICINITY	1

#define CLIP_BUTTON_SIZE  23


/* The amount of space (in multiples of the icon size)
 * a docked icon must be dragged out to detach it */
#define DOCK_DETTACH_THRESHOLD	3

/* Delay (in ms) after which the clip will autocollapse when leaved */
#define AUTO_COLLAPSE_DELAY     1000

/* Delay (in ms) after which the clip will autoexpand when entered.
 * Set this to zero if you want instant expanding. */
#define AUTO_EXPAND_DELAY       600

/* Delay (in ms) after which the clip will be lowered when leaved */
#define AUTO_LOWER_DELAY        1000

/* Delay (in ms) after which the clip will be raised when entered.
 * Set this to zero if you want instant raise. */
#define AUTO_RAISE_DELAY        600


/* Max. number of icons the clip can have */
#define CLIP_MAX_ICONS		32

/* blink interval when invoking a menu item */
#define MENU_BLINK_DELAY	60000
#define MENU_BLINK_COUNT	0

#define CURSOR_BLINK_RATE	300

#define MOVE_THRESHOLD	5 /* how many pixels to move before dragging windows
                           * and other objects */

#define KEY_CONTROL_WINDOW_WEIGHT 1

#define HRESIZE_THRESHOLD	3

#define MAX_WORKSPACENAME_WIDTH	32
#define MAX_WINDOWLIST_WIDTH	160     /* max width of window title in
                                         * window list */

#define DEFAULTS_CHECK_INTERVAL 2000	/* how often wmaker will check for
                                         * changes in the config files */

/* if your keyboard don't have arrow keys */
#undef ARROWLESS_KBD


/* don't put titles in miniwindows */
#undef NO_MINIWINDOW_TITLES


#define FRAME_BORDER_COLOR "black"


/* for boxes with high mouse sampling rates (SGI) */
#define DELAY_BETWEEN_MOUSE_SAMPLING  10


/*
 *----------------------------------------------------------------------
 * You should not modify the following values, unless you know
 * what you're doing.
 *----------------------------------------------------------------------
 */


/* number of window shortcuts */
#define MAX_WINDOW_SHORTCUTS 10


#define WM_PI 3.14159265358979323846

#define FRAME_BORDER_WIDTH 1	       /* width of window border for frames */

#define RESIZEBAR_HEIGHT 8	       /* height of the resizebar */
#define RESIZEBAR_MIN_WIDTH 20	       /* min. width of handles-corner_width */
#define RESIZEBAR_CORNER_WIDTH 28      /* width of the corner of resizebars */

#define MENU_INDICATOR_SPACE	12

/* minimum size for windows */
#define MIN_WINDOW_SIZE	5

#define MIN_TITLEFONT_HEIGHT(h)   ((h)>14 ? (h) : 14)

#define ICON_WIDTH	64	       /* size of the icon window */
#define ICON_HEIGHT	64
#define ICON_BORDER_WIDTH 2

#define MAX_ICON_WIDTH	60	       /* size of the icon pixmap */
#define MAX_ICON_HEIGHT 48

#define MAX_WORKSPACES  100

#define MAX_MENU_TEXT_LENGTH 512

#define MAX_RESTART_ARGS	16

#define MAX_DEAD_PROCESSES	128


#define MAXLINE		1024


#ifdef _MAX_PATH
# define DEFAULT_PATH_MAX	_MAX_PATH
#else
# define DEFAULT_PATH_MAX	512
#endif


#undef DEBUG
#undef DEBUG0

/* some rules */

#ifndef SHAPE
#undef SHAPED_BALLOON
#endif

#ifndef DEMATERIALIZE_ICON
# define NORMAL_ICON_KABOOM
#endif

#if defined(HAVE_LIBINTL_H) && defined(I18N)
# include <libintl.h>
# define _(text) gettext(text)
#else 
# if defined(WITH_GNUSTEP)
#  define _(text) (text)
# endif
#endif


#if defined(__GNUC__) && !defined(__STRICT_ANSI__)
# define INLINE inline
#else
# define INLINE
#endif

#endif /* WMCONFIG_H_ */

