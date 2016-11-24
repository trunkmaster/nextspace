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

#ifndef WMKEYBIND_H
#define WMKEYBIND_H

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
	WKBD_ROOTMENU,
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

	/* Dock */
	WKBD_DOCKRAISELOWER,

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

	/* screen */
	WKBD_SWITCH_SCREEN,

	/* open "run" dialog */
	WKBD_RUN,

#ifdef KEEP_XKB_LOCK_STATUS
	WKBD_TOGGLE,
#endif
	/* keep this last */
	WKBD_LAST
};

typedef struct WShortKey {
    unsigned int modifier;
    KeyCode keycode;
} WShortKey;

/* ---[ Global Variables ]------------------------------------------------ */

extern WShortKey wKeyBindings[WKBD_LAST];

/* ---[ Functions ]------------------------------------------------------- */

void wKeyboardInitialize(void);

#endif /* WMKEYBIND_H */
