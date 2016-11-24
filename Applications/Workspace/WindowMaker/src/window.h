/*
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

#ifndef WMWINDOW_H_
#define WMWINDOW_H_

#include <wraster.h>

#include "wconfig.h"
#include "GNUstep.h"
#include "texture.h"
#include "menu.h"
#include "application.h"

/* not defined in my X11 headers */
#ifndef UrgencyHint
#define UrgencyHint (1L << 8)
#endif


#define BORDER_TOP	1
#define BORDER_BOTTOM	2
#define BORDER_LEFT	4
#define BORDER_RIGHT	8
#define BORDER_ALL	(1|2|4|8)


#define CLIENT_EVENTS (StructureNotifyMask | PropertyChangeMask\
    | EnterWindowMask | LeaveWindowMask | ColormapChangeMask \
    | FocusChangeMask | VisibilityChangeMask)

typedef enum {
    WFM_PASSIVE, WFM_NO_INPUT, WFM_LOCALLY_ACTIVE, WFM_GLOBALLY_ACTIVE
} FocusMode;


/*
 * window attribute flags.
 *
 * Note: attributes that should apply to the application as a
 * whole should only access the flags from app->main_window_desc->window_flags
 * This is to make sure that the application doesn't have many different
 * values for the same option. For example, imagine xfoo, which has
 * foo.bar as leader and it a child window named foo.baz. If you set
 * StartHidden YES for foo.bar and NO for foo.baz we must *always* guarantee
 * that the value that will be used will be that of the leader foo.bar.
 * The attributes inspector must always save application wide options
 * in the name of the leader window, not the child.
 *
 */
/*
 * All flags must have their default values = 0
 *
 * New flag scheme:
 *
 * user_flags, defined_flags
 * client_flags
 *
 * if defined window_flag then window_flag else client_flag
 *
 */

#define WFLAGP(wwin, FLAG)	((wwin)->defined_user_flags.FLAG \
    ? (wwin)->user_flags.FLAG \
    : (wwin)->client_flags.FLAG)

#define WSETUFLAG(wwin, FLAG, VAL)	(wwin)->user_flags.FLAG = (VAL),\
    (wwin)->defined_user_flags.FLAG = 1

typedef struct {
    /* OpenStep */
    unsigned int no_titlebar:1;	       /* draw titlebar? */
    unsigned int no_resizable:1;
    unsigned int no_closable:1;
    unsigned int no_miniaturizable:1;
    unsigned int no_border:1;	       /* 1 pixel border around window */
#ifdef XKB_BUTTON_HINT
    unsigned int no_language_button:1;
#endif
    unsigned int no_movable:1;

    /* decorations */
    unsigned int no_resizebar:1;       /* draw the bottom handle? */
    unsigned int no_close_button:1;    /* draw a close button? */
    unsigned int no_miniaturize_button:1; /* draw an iconify button? */

    unsigned int broken_close:1;       /* is the close button broken? */

    /* ours */
    unsigned int kill_close:1;	       /* can't send WM_DELETE_WINDOW */

    unsigned int no_shadeable:1;
    unsigned int omnipresent:1;
    unsigned int skip_window_list:1;
    unsigned int skip_switchpanel:1;
    unsigned int floating:1;	       /* put in WMFloatingLevel */
    unsigned int sunken:1;	       /* put in WMSunkenLevel */
    unsigned int no_bind_keys:1;       /* intercept wm kbd binds
                                        * while window is focused */
    unsigned int no_bind_mouse:1;      /* intercept mouse events
                                        * on client area while window
                                        * is focused */
    unsigned int no_hide_others:1;     /* hide window when doing hideothers */
    unsigned int no_appicon:1;	       /* make app icon */

    unsigned int shared_appicon:1;

    unsigned int dont_move_off:1;

    unsigned int no_focusable:1;
    unsigned int focus_across_wksp:1;   /* let wmaker switch workspace to follow
					 * a focus request */

    unsigned int always_user_icon:1;   /* ignore client IconPixmap or
                                        * IconWindow */

    unsigned int start_miniaturized:1;
    unsigned int start_hidden:1;
    unsigned int start_maximized:1;
    unsigned int dont_save_session:1;  /* do not save app's state in session */

    unsigned int full_maximize:1;
    /*
     * emulate_app_icon must be automatically disabled for apps that can
     * generate their own appicons and for apps that have no_appicon=1
     */
    unsigned int emulate_appicon:1;

} WWindowAttributes;



/*
 * Window manager protocols that both the client as we understand.
 */
typedef struct {
    unsigned int TAKE_FOCUS:1;
    unsigned int DELETE_WINDOW:1;
    unsigned int SAVE_YOURSELF:1;
    /* WindowMaker specific */
    unsigned int MINIATURIZE_WINDOW:1;
} WProtocols;


/*
 * Structure used for storing fake window group information
 */
typedef struct WFakeGroupLeader {
    char *identifier;
    Window leader;
    Window origLeader;
    int retainCount;
} WFakeGroupLeader;


/*
 * Stores client window information. Each client window has it's
 * structure created when it's being first mapped.
 */
typedef struct WWindow {
	struct WWindow *prev;			/* window focus list */
	struct WWindow *next;

	WScreen *screen_ptr; 			/* pointer to the screen structure */
	WWindowAttributes user_flags;		/* window attribute flags set by user */
	WWindowAttributes defined_user_flags;	/* mask for user_flags */
	WWindowAttributes client_flags;		/* window attribute flags set by app
						 * initialized with global defaults */

	struct InspectorPanel *inspector;	/* pointer to attribute editor panel */

	struct WFrameWindow *frame;		/* the frame window */
	int frame_x, frame_y;			/* position of the frame in root*/

	struct {
		int x, y;
		unsigned int width, height;	/* original geometry of the window */
	} old_geometry;				/* (before things like maximize) */

	struct {
		int x, y;
		unsigned int width, height;	/* original geometry of the window */
	} bfs_geometry;				/* (before fullscreen) */

	int maximus_x;				/* size after Maximusizing */
	int maximus_y;

	/* client window info */
	short old_border_width;			/* original border width of client_win*/
	Window client_win;			/* the window we're managing */
	WObjDescriptor client_descriptor;	/* dummy descriptor for client */
	struct {
		int x, y;			/* position of *client* relative
						 * to root */
		unsigned int width, height;	/* size of the client window */
	} client;

	XSizeHints *normal_hints;		/* WM_NORMAL_HINTS */
	XWMHints *wm_hints;			/* WM_HINTS (optional) */
	char *wm_instance;			/* instance of WM_CLASS */
	char *wm_class;				/* class of WM_CLASS */
	GNUstepWMAttributes *wm_gnustep_attr;	/* GNUstep window attributes */

	int state;				/* state as in ICCCM */

	Window transient_for;			/* WM_TRANSIENT_FOR */

	WFakeGroupLeader *fake_group;		/* Fake group leader for grouping into
						 * a single appicon */
	Window group_id;			/* the leader window of the group */
	Window client_leader;			/* WM_CLIENT_LEADER if not
						 * internal_window */

	Window main_window;			/* main window for the application */
	Window orig_main_window;		/* original main window of application.
						 * used for the shared appicon thing */

	int cmap_window_no;
	Window *cmap_windows;

	/* protocols */
	WProtocols protocols;			/* accepted WM_PROTOCOLS */

	FocusMode focus_mode;			/* type of keyboard input focus */

	long event_mask;			/* the event mask thats selected */

	/* state flags */
	struct {
		unsigned int mapped:1;
		unsigned int focused:1;
		unsigned int miniaturized:1;
		unsigned int hidden:1;
		unsigned int shaded:1;
		unsigned int maximized:7;
		unsigned int old_maximized:7;
		unsigned int fullscreen:1;
		unsigned int omnipresent:1;
		unsigned int semi_focused:1;
		/* window type flags */
		unsigned int urgent:1;		/* if wm_hints says this is urgent */
#ifdef USE_XSHAPE
		unsigned int shaped:1;
#endif

		/* info flags */
		unsigned int is_gnustep:1;	/* 1 if the window belongs to a GNUstep
						 * app */
		unsigned int is_dockapp:1;	/* 1 if the window belongs to a DockApp */

		unsigned int icon_moved:1;	/* icon for this window was moved
						 * by the user */
		unsigned int selected:1;	/* multiple window selection */
		unsigned int skip_next_animation:1;
		unsigned int internal_window:1;
		unsigned int changing_workspace:1;

		unsigned int inspector_open:1;	/* attrib inspector is already open */

		unsigned int destroyed:1;	/* window was already destroyed */
		unsigned int menu_open_for_me:1;/* window commands menu */
		unsigned int obscured:1;	/* window is obscured */

		unsigned int net_skip_pager:1;
		unsigned int net_handle_icon:1;
		unsigned int net_show_desktop:1;
		unsigned int net_has_title:1;	/* use netwm version of WM_NAME */
	} flags;				/* state of the window */

	struct WIcon *icon;			/* Window icon when miminized
						 * else is NULL! */
	int icon_x, icon_y;			/* position of the icon */
	int icon_w, icon_h;
	RImage *net_icon_image;			/* Window Image */
	Atom type;
} WWindow;

#define HAS_TITLEBAR(w)		(!(WFLAGP((w), no_titlebar) || (w)->flags.fullscreen))
#define HAS_RESIZEBAR(w)	(!(WFLAGP((w), no_resizebar) || (w)->flags.fullscreen))
#define HAS_BORDER(w)		(!(WFLAGP((w), no_border) || (w)->flags.fullscreen))
#define IS_MOVABLE(w)		(!(WFLAGP((w), no_movable) || (w)->flags.fullscreen))
#define IS_RESIZABLE(w)		(!(WFLAGP((w), no_resizable) || (w)->flags.fullscreen))
#define IS_OMNIPRESENT(w)	((w)->flags.omnipresent | WFLAGP(w, omnipresent))
#define WINDOW_LEVEL(w)		((w)->frame->core->stacking->window_level)

/*
 * Changes to this must update wWindowSaveState/getSavedState
 */
typedef struct WSavedState {
    int workspace;
    int miniaturized;
    int shaded;
    int hidden;
    int maximized;
    int x;			       /* original geometry of the */
    int y;			       /* window if it's maximized */
    unsigned int w;
    unsigned int h;
    unsigned window_shortcuts; /* mask like 1<<shortcut_number */
} WSavedState;

typedef struct WWindowState {
    char *instance;
    char *class;
    char *command;
    pid_t pid;
    WSavedState *state;
    struct WWindowState *next;
} WWindowState;

typedef void* WMagicNumber;

void wWindowDestroy(WWindow *wwin);
WWindow *wWindowCreate(void);

#ifdef USE_XSHAPE
void wWindowSetShape(WWindow *wwin);
void wWindowClearShape(WWindow *wwin);
#endif

WWindow *wManageWindow(WScreen *scr, Window window);

void wUnmanageWindow(WWindow *wwin, Bool restore, Bool destroyed);

void wWindowSingleFocus(WWindow *wwin);
void wWindowFocusPrev(WWindow *wwin, Bool inSameWorkspace);
void wWindowFocusNext(WWindow *wwin, Bool inSameWorkspace);
void wWindowFocus(WWindow *wwin, WWindow *owin);
void wWindowUnfocus(WWindow *wwin);

void wWindowUpdateName(WWindow *wwin, const char *newTitle);
void wWindowConstrainSize(WWindow *wwin, unsigned int *nwidth, unsigned int *nheight);
void wWindowCropSize(WWindow *wwin, unsigned int maxw, unsigned int maxh,
                     unsigned int *nwidth, unsigned int *nheight);
void wWindowConfigure(WWindow *wwin, int req_x, int req_y,
                      int req_width, int req_height);

void wWindowMove(WWindow *wwin, int req_x, int req_y);

void wWindowSynthConfigureNotify(WWindow *wwin);

WWindow *wWindowFor(Window window);


void wWindowConfigureBorders(WWindow *wwin);

void wWindowUpdateButtonImages(WWindow *wwin);

void wWindowSaveState(WWindow *wwin);

void wWindowChangeWorkspace(WWindow *wwin, int workspace);
void wWindowChangeWorkspaceRelative(WWindow *wwin, int amount);

void wWindowSetKeyGrabs(WWindow *wwin);

void wWindowResetMouseGrabs(WWindow *wwin);

WWindow *wManageInternalWindow(WScreen *scr, Window window, Window owner,
                               const char *title, int x, int y,
                               int width, int height);

void wWindowSetupInitialAttributes(WWindow *wwin, int *level, int *workspace);

void wWindowUpdateGNUstepAttr(WWindow *wwin, GNUstepWMAttributes *attr);

void wWindowMap(WWindow *wwin);

void wWindowUnmap(WWindow *wwin);

void wWindowDeleteSavedStatesForPID(pid_t pid);

WMagicNumber wWindowAddSavedState(const char *instance, const char *class, const char *command,
                                  pid_t pid, WSavedState *state);

WMagicNumber wWindowGetSavedState(Window win);

void wWindowDeleteSavedState(WMagicNumber id);

Bool wWindowObscuresWindow(WWindow *wwin, WWindow *obscured);

void wWindowSetOmnipresent(WWindow *wwin, Bool flag);
#endif
