/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
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

#ifndef __WORKSPACE_WM_DOCK__
#define __WORKSPACE_WM_DOCK__

#include "appicon.h"

#define DOCK_EXTRA_SPACE 3

/* Vicinity in which an icon can be attached to the clip */
#define CLIP_ATTACH_VICINITY	1
#define CLIP_BUTTON_SIZE      23

/* The amount of space (in multiples of the icon size)
 * a docked icon must be dragged out to detach it */
#define DOCK_DETTACH_THRESHOLD 2

/* Max. number of icons the dock and clip can have */
#define DOCK_MAX_ICONS 32

typedef struct WDock {
  WScreen *screen_ptr;
  int x_pos, y_pos;		       /* position of the first icon */

  WAppIcon **icon_array;	       /* array of docked icons */
  int max_icons;

  int icon_count;

#define WM_DOCK   0
#define WM_CLIP   1
#define WM_DRAWER 2
  int type;

  WMagicNumber auto_expand_magic;
  WMagicNumber auto_collapse_magic;
  WMagicNumber auto_raise_magic;
  WMagicNumber auto_lower_magic;
  unsigned int auto_collapse : 1;       /* if clip auto-collapse itself */
  unsigned int auto_raise_lower : 1;    /* if clip should raise/lower when
                                           entered/leaved */
  unsigned int on_right_side : 1;
  unsigned int collapsed : 1;
  unsigned int mapped : 1;
  unsigned int lowered : 1;
  unsigned int attract_icons : 1;       /* If clip should attract app-icons */

  unsigned int lclip_button_pushed : 1;
  unsigned int rclip_button_pushed : 1;

  struct WMenu *menu;

  struct WDDomain *defaults;
} WDock;

int wDockMaxIcons(WScreen *scr);
WDock *wDockCreate(WScreen *scr, int type, const char *name);
WDock *wDockRestoreState(WScreen *scr, CFDictionaryRef dock_state, int type);

void wDockDestroy(WDock *dock);
void wDockHideIcons(WDock *dock);
void wDockShowIcons(WDock *dock);
void wDockUncollapse(WDock *dock);
void wDockCollapse(WDock *dock);
void wDockLower(WDock *dock);
void wDockRaise(WDock *dock);
void wDockRaiseLower(WDock *dock);
int wDockLevel(WDock *dock);
void wDockSetLevel(WDock *dock, int level);

void wDockSaveState(WScreen *scr, CFDictionaryRef old_state);

Bool wDockAttachIcon(WDock *dock, WAppIcon *icon, int x, int y, Bool update_icon);
Bool wDockSnapIcon(WDock *dock, WAppIcon *icon, int req_x, int req_y, int *ret_x, int *ret_y,
                   int redocking);
Bool wDockFindFreeSlot(WDock *dock, int *req_x, int *req_y);
void wDockDetach(WDock *dock, WAppIcon *icon);
Bool wDockMoveIconBetweenDocks(WDock *src, WDock *dest, WAppIcon *icon, int x, int y);
void wDockReattachIcon(WDock *dock, WAppIcon *icon, int x, int y);
WAppIcon *wDockAppiconAtSlot(WDock *dock, int position);

void wSlideAppicons(WAppIcon **appicons, int n, int to_the_left);
void wDrawerFillTheGap(WDock *drawer, WAppIcon *aicon, Bool redocking);

void wDockFinishLaunch(WAppIcon *icon);
void wDockTrackWindowLaunch(WDock *dock, Window window);
WAppIcon *wDockFindIconForWindow(WDock *dock, Window window);
void wDockDoAutoLaunch(WDock *dock, int desktop);
void wDockLaunchWithState(WAppIcon *btn, WSavedState *state);

#ifdef USE_DOCK_XDND
int wDockReceiveDNDDrop(WScreen *scr, XEvent *event);
#endif

void wClipIconPaint(WAppIcon *aicon);
void wClipSaveState(WScreen *scr);
CFMutableDictionaryRef wClipSaveDesktopState(WScreen *scr, int desktop);
WAppIcon *wClipRestoreState(WScreen *scr, CFDictionaryRef clip_state);

void wDrawerIconPaint(WAppIcon *dicon);
void wDrawersSaveState(WScreen *scr);
void wDrawersRestoreState(WScreen *scr);
int wIsADrawer(WAppIcon *aicon);

void wClipUpdateForDesktopChange(WScreen *scr, int desktop);

RImage *wClipMakeTile(RImage *normalTile);
RImage *wDrawerMakeTile(WScreen *scr, RImage *normalTile);

#define WO_FAILED          0
#define WO_NOT_APPLICABLE  1
#define WO_SUCCESS         2

typedef enum {
  P_NORMAL = 0,
  P_AUTO_RAISE_LOWER,
  P_KEEP_ON_TOP,
} dockPosition;

int wClipMakeIconOmnipresent(WAppIcon *aicon, int omnipresent);

#endif /* __WORKSPACEWM_DOCK__ */
