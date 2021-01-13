/*
 *  Definitions and compile time options
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
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#ifndef __WORKSPACE_WM_DEFS__
#define __WORKSPACE_WM_DEFS__

#include "config.h"

/* Undefine if you don't want balloons for showing extra information, like window titles that 
   are not fully visible. */
#define BALLOON_TEXT
/* If balloons should be shaped or be simple rectangles. The X server must support the shape 
   extensions and it's support must be  enabled (default). */
#ifdef USE_XSHAPE
# define SHAPED_BALLOON
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
#define MAX_WINDOW_SHORTCUTS	10
//#define MIN_TITLEFONT_HEIGHT(h)   ((h)>14 ? (h) : 14)
/* window's titlebar height */
#define TITLEBAR_HEIGHT		18
/* height of the resizebar */
#define RESIZEBAR_HEIGHT	8
/* min width of handles-corner_width */
#define RESIZEBAR_MIN_WIDTH	20
/* width of the corner of resizebars */
#define RESIZEBAR_CORNER_WIDTH	28
#define MENU_INDICATOR_SPACE	12
/* minimum size for windows */
#define MIN_WINDOW_SIZE		5
/* size of the icon window */
#define ICON_WIDTH		64
#define ICON_HEIGHT		64
#define ICON_BORDER_WIDTH	2
/* size of the icon pixmap */
#define MAX_ICON_WIDTH		60
#define MAX_ICON_HEIGHT		48
#define MAX_WORKSPACES		100
#define MAX_MENU_TEXT_LENGTH	512
#define MAX_RESTART_ARGS	16
#define MAX_DEAD_PROCESSES	128
#define MAXLINE			1024

#ifdef _MAX_PATH
#  define DEFAULT_PATH_MAX	_MAX_PATH
#else
#  define DEFAULT_PATH_MAX	512
#endif

#ifdef  XKB_MODELOCK
#  define KEEP_XKB_LOCK_STATUS
#endif

#if defined(HAVE_LIBINTL_H) && defined(I18N)
#  include <libintl.h>
#  define _(text) gettext(text)
/* Use N_() in initializers, it will make xgettext pick the string up for translation */
#  define N_(text) (text)
#  if defined(MENU_TEXTDOMAIN)
#    define M_(text) dgettext(MENU_TEXTDOMAIN, text)
#  else
#    define M_(text) (text)
#  endif
#else
#  define _(text) (text)
#  define N_(text) (text)
#  define M_(text) (text)
#endif /* defined(HAVE_LIBINTL_H) && defined(I18N) */

#endif /* __WORKSPACE_WM_DEFS__ */

