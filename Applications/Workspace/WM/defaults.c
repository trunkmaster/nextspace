/*  Manage configuration through defaults db
 *
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
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

#include "WM.h"

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <limits.h>
#include <signal.h>

#ifdef HAVE_INOTIFY
#include <sys/select.h>
#include <sys/inotify.h>
#endif

#ifndef PATH_MAX
#define PATH_MAX DEFAULT_PATH_MAX
#endif

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <X11/Xcursor/Xcursor.h>

#include <wraster.h>

#include <core/WMcore.h>
#include <core/util.h>
#include <core/log_utils.h>
#include <core/string_utils.h>
#include <core/file_utils.h>

#include <core/wscreen.h>
#include <core/wcolor.h>
#include <core/drawing.h>
#include <core/wuserdefaults.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFFileDescriptor.h>

#include "WM.h"
#include "framewin.h"
#include "window.h"
#include "texture.h"
#include "screen.h"
#include "resources.h"
#include "defaults.h"
#include "xmodifier.h"
#include "icon.h"
#include "actions.h"
#include "dock.h"
#include "desktop.h"
#include "properties.h"
#include "misc.h"
#include "winmenu.h"
#include "moveres.h"
#include "iconyard.h"

#include "Workspace+WM.h"

#include "defaults.h"

struct WPreferences wPreferences;

WShortKey wKeyBindings[WKBD_LAST];

typedef struct _WDefaultEntry WDefaultEntry;

typedef int (WDECallbackConvert) (WScreen *scr, WDefaultEntry *entry, CFTypeRef plvalue, void *addr, void **tdata);
typedef int (WDECallbackUpdate) (WScreen *scr, WDefaultEntry *entry, void *tdata, void *extra_data);

struct _WDefaultEntry {
  const char         *key;
  const char         *default_value;
  void               *extra_data;
  void               *addr;
  WDECallbackConvert *convert;
  WDECallbackUpdate  *update;
  CFStringRef        plkey;
  CFPropertyListRef  plvalue;	/* default value */
};

/* type converters */
static WDECallbackConvert getBool;
static WDECallbackConvert getInt;
static WDECallbackConvert getCoord;
static WDECallbackConvert getPathList;
static WDECallbackConvert getEnum;
static WDECallbackConvert getTexture;
static WDECallbackConvert getFont;
static WDECallbackConvert getColor;
static WDECallbackConvert getKeybind;
static WDECallbackConvert getModMask;
static WDECallbackConvert getAltModMask;
static WDECallbackConvert getPropList;

/* value setting functions */
static WDECallbackUpdate setJustify;
static WDECallbackUpdate setClearance;
static WDECallbackUpdate setIfDockPresent;
static WDECallbackUpdate setClipMergedInDock;
static WDECallbackUpdate setWrapAppiconsInDock;
static WDECallbackUpdate setStickyIcons;
static WDECallbackUpdate setWidgetColor;
static WDECallbackUpdate setIconTile;
static WDECallbackUpdate setMiniwindowTile; /* NEXTSPACE */
static WDECallbackUpdate setWinTitleFont;
static WDECallbackUpdate setMenuTitleFont;
static WDECallbackUpdate setMenuTextFont;
static WDECallbackUpdate setIconTitleFont;
static WDECallbackUpdate setIconTitleColor;
static WDECallbackUpdate setIconTitleBack;
static WDECallbackUpdate setFrameBorderWidth;
static WDECallbackUpdate setFrameBorderColor;
static WDECallbackUpdate setFrameFocusedBorderColor;
static WDECallbackUpdate setFrameSelectedBorderColor;
static WDECallbackUpdate setLargeDisplayFont;
static WDECallbackUpdate setWTitleColor;
static WDECallbackUpdate setFTitleBack;
static WDECallbackUpdate setPTitleBack;
static WDECallbackUpdate setUTitleBack;
static WDECallbackUpdate setResizebarBack;
static WDECallbackUpdate setMenuTitleColor;
static WDECallbackUpdate setMenuTextColor;
static WDECallbackUpdate setMenuDisabledColor;
static WDECallbackUpdate setMenuTitleBack;
static WDECallbackUpdate setMenuTextBack;
static WDECallbackUpdate setHightlight;
static WDECallbackUpdate setHightlightText;
static WDECallbackUpdate setKeyGrab;
static WDECallbackUpdate setDoubleClick;
static WDECallbackUpdate setIconPosition;
static WDECallbackUpdate setWorkspaceMapBackground;

static WDECallbackUpdate setClipTitleFont;
static WDECallbackUpdate setClipTitleColor;

static WDECallbackUpdate setMenuStyle;
static WDECallbackUpdate setSwPOptions;
static WDECallbackUpdate updateUsableArea;

static WDECallbackUpdate setModifierKeyLabels;

static WDECallbackConvert getCursor;
static WDECallbackUpdate setCursor;

static WDECallbackUpdate setAntialiasedText;

/*
 * Tables to convert strings to enumeration values.
 * Values stored are char
 */

/* WARNING: sum of length of all value strings must not exceed
 * this value */
#define TOTAL_VALUES_LENGTH		80

#define REFRESH_WINDOW_TEXTURES		(1<<0)
#define REFRESH_MENU_TEXTURE		(1<<1)
#define REFRESH_MENU_FONT		(1<<2)
#define REFRESH_MENU_COLOR		(1<<3)
#define REFRESH_MENU_TITLE_TEXTURE	(1<<4)
#define REFRESH_MENU_TITLE_FONT		(1<<5)
#define REFRESH_MENU_TITLE_COLOR	(1<<6)
#define REFRESH_WINDOW_TITLE_COLOR	(1<<7)
#define REFRESH_WINDOW_FONT		(1<<8)
#define REFRESH_ICON_TILE		(1<<9)
#define REFRESH_ICON_FONT		(1<<10)
#define REFRESH_WORKSPACE_BACK		(1<<11)
#define REFRESH_BUTTON_IMAGES		(1<<12)
#define REFRESH_ICON_TITLE_COLOR	(1<<13)
#define REFRESH_ICON_TITLE_BACK		(1<<14)

#define REFRESH_FRAME_BORDER REFRESH_MENU_FONT|REFRESH_WINDOW_FONT

/* used to map strings to integers */
typedef struct {
  const char *string;
  short value;
  char is_alias;
} WOptionEnumeration;

static WOptionEnumeration seTitlebarStyles[] = {
  {"new", TS_NEW, 0},
  {"old", TS_OLD, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seColormapModes[] = {
  {"Manual", WCM_CLICK, 0},
  {"ClickToFocus", WCM_CLICK, 1},
  {"Auto", WCM_POINTER, 0},
  {"FocusFollowMouse", WCM_POINTER, 1},
  {NULL, 0, 0}
};
static WOptionEnumeration sePlacements[] = {
  {"Auto", WPM_AUTO, 0},
  {"Smart", WPM_SMART, 0},
  {"Cascade", WPM_CASCADE, 0},
  {"Random", WPM_RANDOM, 0},
  {"Manual", WPM_MANUAL, 0},
  {"Center", WPM_CENTER, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seGeomDisplays[] = {
  {"None", WDIS_NONE, 0},
  {"Center", WDIS_CENTER, 0},
  {"Corner", WDIS_TOPLEFT, 0},
  {"Floating", WDIS_FRAME_CENTER, 0},
  {"Line", WDIS_NEW, 0},
  {"Titlebar", WDIS_TITLEBAR, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seSpeeds[] = {
  {"UltraFast", SPEED_ULTRAFAST, 0},
  {"Fast", SPEED_FAST, 0},
  {"Medium", SPEED_MEDIUM, 0},
  {"Slow", SPEED_SLOW, 0},
  {"UltraSlow", SPEED_ULTRASLOW, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seMouseButtonActions[] = {
  {"None", WA_NONE, 0},
  {"SelectWindows", WA_SELECT_WINDOWS, 0},
  {"OpenApplicationsMenu", WA_OPEN_APPMENU, 0},
  {"OpenWindowListMenu", WA_OPEN_WINLISTMENU, 0},
  {"MoveToPrevWorkspace", WA_MOVE_PREVWORKSPACE, 0},
  {"MoveToNextWorkspace", WA_MOVE_NEXTWORKSPACE, 0},
  {"MoveToPrevWindow", WA_MOVE_PREVWINDOW, 0},
  {"MoveToNextWindow", WA_MOVE_NEXTWINDOW, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seMouseWheelActions[] = {
  {"None", WA_NONE, 0},
  {"SwitchWorkspaces", WA_SWITCH_WORKSPACES, 0},
  {"SwitchWindows", WA_SWITCH_WINDOWS, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seIconificationStyles[] = {
  {"Zoom", WIS_ZOOM, 0},
  {"Twist", WIS_TWIST, 0},
  {"Flip", WIS_FLIP, 0},
  {"None", WIS_NONE, 0},
  {"random", WIS_RANDOM, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seJustifications[] = {
  {"Left", WTJ_LEFT, 0},
  {"Center", WTJ_CENTER, 0},
  {"Right", WTJ_RIGHT, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seIconPositions[] = {
  {"blv", IY_BOTTOM | IY_LEFT | IY_VERT, 0},
  {"blh", IY_BOTTOM | IY_LEFT | IY_HORIZ, 0},
  {"brv", IY_BOTTOM | IY_RIGHT | IY_VERT, 0},
  {"brh", IY_BOTTOM | IY_RIGHT | IY_HORIZ, 0},
  {"tlv", IY_TOP | IY_LEFT | IY_VERT, 0},
  {"tlh", IY_TOP | IY_LEFT | IY_HORIZ, 0},
  {"trv", IY_TOP | IY_RIGHT | IY_VERT, 0},
  {"trh", IY_TOP | IY_RIGHT | IY_HORIZ, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seMenuStyles[] = {
  {"normal", MS_NORMAL, 0},
  {"singletexture", MS_SINGLE_TEXTURE, 0},
  {"flat", MS_FLAT, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seDisplayPositions[] = {
  {"none", WD_NONE, 0},
  {"center", WD_CENTER, 0},
  {"top", WD_TOP, 0},
  {"bottom", WD_BOTTOM, 0},
  {"topleft", WD_TOPLEFT, 0},
  {"topright", WD_TOPRIGHT, 0},
  {"bottomleft", WD_BOTTOMLEFT, 0},
  {"bottomright", WD_BOTTOMRIGHT, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seWorkspaceBorder[] = {
  {"None", WB_NONE, 0},
  {"LeftRight", WB_LEFTRIGHT, 0},
  {"TopBottom", WB_TOPBOTTOM, 0},
  {"AllDirections", WB_ALLDIRS, 0},
  {NULL, 0, 0}
};
static WOptionEnumeration seDragMaximizedWindow[] = {
  {"Move", DRAGMAX_MOVE, 0},
  {"RestoreGeometry", DRAGMAX_RESTORE, 0},
  {"Unmaximize", DRAGMAX_UNMAXIMIZE, 0},
  {"NoMove", DRAGMAX_NOMOVE, 0},
  {NULL, 0, 0}
};

/*
 * ALL entries in the tables bellow, NEED to have a default value
 * defined, and this value needs to be correct.
 *
 * These options will only affect the window manager on startup
 *
 * Static defaults can't access the screen data, because it is
 * created after these defaults are read
 */
WDefaultEntry staticOptionList[] = {
  {"ColormapSize", "4", NULL, &wPreferences.cmap_size, getInt, NULL, NULL, NULL},
  {"DisableDithering", "NO", NULL, &wPreferences.no_dithering, getBool, NULL, NULL, NULL},
  {"IconSize", "64", NULL, &wPreferences.icon_size, getInt, NULL, NULL, NULL},
  {"TitlebarStyle", "old", seTitlebarStyles, &wPreferences.titlebar_style, getEnum, NULL, NULL, NULL},
  {"DisableDock", "NO", (void *)WM_DOCK, NULL, getBool, setIfDockPresent, NULL, NULL},
  {"DisableClip", "YES", (void *)WM_CLIP, NULL, getBool, setIfDockPresent, NULL, NULL},
  {"DisableDrawers", "YES", (void *)WM_DRAWER, NULL, getBool, setIfDockPresent, NULL, NULL},
  {"ClipMergedInDock", "NO", NULL, NULL, getBool, setClipMergedInDock, NULL, NULL},
  {"DisableMiniwindows", "NO", NULL, &wPreferences.disable_miniwindows, getBool, NULL, NULL, NULL},
  {"EnableWorkspacePager", "NO", NULL, &wPreferences.enable_workspace_pager, getBool, NULL, NULL, NULL}
};

#define NUM2STRING_(x) #x
#define NUM2STRING(x) NUM2STRING_(x)

/* dynamic options */
WDefaultEntry optionList[] = {
    {"IconPosition", "blh", seIconPositions, &wPreferences.icon_yard, getEnum, setIconPosition,
     NULL, NULL},
    {"IconificationStyle", "Zoom", seIconificationStyles, &wPreferences.iconification_style,
     getEnum, NULL, NULL, NULL},
    {"ImagePaths", DEF_IMAGE_PATHS, NULL, &wPreferences.image_paths, getPathList, NULL, NULL, NULL},
    {"ColormapMode", "Auto", seColormapModes, &wPreferences.colormap_mode, getEnum, NULL, NULL,
     NULL},
    {"AutoFocus", "YES", NULL, &wPreferences.auto_focus, getBool, NULL, NULL, NULL},
    {"RaiseDelay", "0", NULL, &wPreferences.raise_delay, getInt, NULL, NULL, NULL},
    {"CirculateRaise", "YES", NULL, &wPreferences.circ_raise, getBool, NULL, NULL, NULL},
    {"Superfluous", "YES", NULL, &wPreferences.superfluous, getBool, NULL, NULL, NULL},
    {"StickyIcons", "YES", NULL, &wPreferences.sticky_icons, getBool, setStickyIcons, NULL, NULL},
    {"SaveSessionOnExit", "NO", NULL, &wPreferences.save_session_on_exit, getBool, NULL, NULL,
     NULL},
    {"ScrollableMenus", "YES", NULL, &wPreferences.scrollable_menus, getBool, NULL, NULL, NULL},
    {"MenuScrollSpeed", "medium", seSpeeds, &wPreferences.menu_scroll_speed, getEnum, NULL, NULL,
     NULL},
    {"IconSlideSpeed", "Slow", seSpeeds, &wPreferences.icon_slide_speed, getEnum, NULL, NULL, NULL},
    {"ClipAutoraiseDelay", "600", NULL, &wPreferences.clip_auto_raise_delay, getInt, NULL, NULL,
     NULL},
    {"ClipAutolowerDelay", "1000", NULL, &wPreferences.clip_auto_lower_delay, getInt, NULL, NULL,
     NULL},
    {"ClipAutoexpandDelay", "600", NULL, &wPreferences.clip_auto_expand_delay, getInt, NULL, NULL,
     NULL},
    {"ClipAutocollapseDelay", "1000", NULL, &wPreferences.clip_auto_collapse_delay, getInt, NULL,
     NULL, NULL},
    {"WrapAppiconsInDock", "NO", NULL, NULL, getBool, setWrapAppiconsInDock, NULL, NULL},
    {"AlignSubmenus", "YES", NULL, &wPreferences.align_menus, getBool, NULL, NULL, NULL},
    {"ViKeyMenus", "NO", NULL, &wPreferences.vi_key_menus, getBool, NULL, NULL, NULL},
    {"OpenTransientOnOwnerWorkspace", "YES", NULL, &wPreferences.open_transients_with_parent,
     getBool, NULL, NULL, NULL},
    {"WindowPlacement", "cascade", sePlacements, &wPreferences.window_placement, getEnum, NULL,
     NULL, NULL},
    {"IgnoreFocusClick", "NO", NULL, &wPreferences.ignore_focus_click, getBool, NULL, NULL, NULL},
    {"UseSaveUnders", "NO", NULL, &wPreferences.use_saveunders, getBool, NULL, NULL, NULL},
    {"OpaqueMove", "YES", NULL, &wPreferences.opaque_move, getBool, NULL, NULL, NULL},
    {"OpaqueResize", "NO", NULL, &wPreferences.opaque_resize, getBool, NULL, NULL, NULL},
    {"OpaqueMoveResizeKeyboard", "NO", NULL, &wPreferences.opaque_move_resize_keyboard, getBool,
     NULL, NULL, NULL},
    {"DisableAnimations", "NO", NULL, &wPreferences.no_animations, getBool, NULL, NULL, NULL},
    {"DontLinkWorkspaces", "NO", NULL, &wPreferences.no_autowrap, getBool, NULL, NULL, NULL},
    {"WindowSnapping", "NO", NULL, &wPreferences.window_snapping, getBool, NULL, NULL, NULL},
    {"SnapEdgeDetect", "1", NULL, &wPreferences.snap_edge_detect, getInt, NULL, NULL, NULL},
    {"SnapCornerDetect", "10", NULL, &wPreferences.snap_corner_detect, getInt, NULL, NULL, NULL},
    {"DragMaximizedWindow", "Move", seDragMaximizedWindow, &wPreferences.drag_maximized_window,
     getEnum, NULL, NULL, NULL},
    {"AutoArrangeIcons", "NO", NULL, &wPreferences.auto_arrange_icons, getBool, NULL, NULL, NULL},
    {"NoWindowOverDock", "YES", NULL, &wPreferences.no_window_over_dock, getBool, updateUsableArea,
     NULL, NULL},
    {"NoWindowOverIcons", "YES", NULL, &wPreferences.no_window_over_icons, getBool,
     updateUsableArea, NULL, NULL},
    {"WindowPlaceOrigin", "(100, 100)", NULL, &wPreferences.window_place_origin, getCoord, NULL,
     NULL, NULL},
    {"ResizeDisplay", "Titlebar", seGeomDisplays, &wPreferences.size_display, getEnum, NULL, NULL,
     NULL},
    {"MoveDisplay", "Titlebar", seGeomDisplays, &wPreferences.move_display, getEnum, NULL, NULL,
     NULL},
    {"DontConfirmKill", "NO", NULL, &wPreferences.dont_confirm_kill, getBool, NULL, NULL, NULL},
    {"WindowTitleBalloons", "NO", NULL, &wPreferences.window_balloon, getBool, NULL, NULL, NULL},
    {"MiniwindowTitleBalloons", "YES", NULL, &wPreferences.miniwin_title_balloon, getBool, NULL,
     NULL, NULL},
    {"MiniwindowPreviewBalloons", "NO", NULL, &wPreferences.miniwin_preview_balloon, getBool, NULL,
     NULL, NULL},
    {"AppIconBalloons", "NO", NULL, &wPreferences.appicon_balloon, getBool, NULL, NULL, NULL},
    {"HelpBalloons", "NO", NULL, &wPreferences.help_balloon, getBool, NULL, NULL, NULL},
    {"EdgeResistance", "30", NULL, &wPreferences.edge_resistance, getInt, NULL, NULL, NULL},
    {"ResizeIncrement", "0", NULL, &wPreferences.resize_increment, getInt, NULL, NULL, NULL},
    {"Attraction", "NO", NULL, &wPreferences.attract, getBool, NULL, NULL, NULL},
    {"DisableBlinking", "NO", NULL, &wPreferences.dont_blink, getBool, NULL, NULL, NULL},
    {"SingleClickLaunch", "NO", NULL, &wPreferences.single_click, getBool, NULL, NULL, NULL},
    {"SwitchPanelOnlyOpen", "NO", NULL, &wPreferences.panel_only_open, getBool, NULL, NULL, NULL},
    {"MiniPreviewSize", "128", NULL, &wPreferences.minipreview_size, getInt, NULL, NULL, NULL},
    {"IgnoreGtkHints", "NO", NULL, &wPreferences.ignore_gtk_decoration_hints, getBool, NULL, NULL,
     NULL},

    /* --- Mouse options --- */

    {"DoubleClickTime", "350", (void *)&wPreferences.dblclick_time, &wPreferences.dblclick_time,
     getInt, setDoubleClick, NULL, NULL},
    {"DisableWSMouseActions", "NO", NULL, &wPreferences.disable_root_mouse, getBool, NULL, NULL,
     NULL},
    {"MouseLeftButtonAction", "SelectWindows", seMouseButtonActions, &wPreferences.mouse_button1,
     getEnum, NULL, NULL, NULL},
    {"MouseMiddleButtonAction", "OpenWindowListMenu", seMouseButtonActions,
     &wPreferences.mouse_button2, getEnum, NULL, NULL, NULL},
    {"MouseRightButtonAction", "OpenApplicationsMenu", seMouseButtonActions,
     &wPreferences.mouse_button3, getEnum, NULL, NULL, NULL},
    {"MouseBackwardButtonAction", "None", seMouseButtonActions, &wPreferences.mouse_button8,
     getEnum, NULL, NULL, NULL},
    {"MouseForwardButtonAction", "None", seMouseButtonActions, &wPreferences.mouse_button9, getEnum,
     NULL, NULL, NULL},
    {"MouseWheelAction", "None", seMouseWheelActions, &wPreferences.mouse_wheel_scroll, getEnum,
     NULL, NULL, NULL},
    {"MouseWheelTiltAction", "None", seMouseWheelActions, &wPreferences.mouse_wheel_tilt, getEnum,
     NULL, NULL, NULL},

    /* --- Workspaces --- */

    {"AdvanceToNewWorkspace", "NO", NULL, &wPreferences.ws_advance, getBool, NULL, NULL, NULL},
    {"CycleWorkspaces", "NO", NULL, &wPreferences.ws_cycle, getBool, NULL, NULL, NULL},
    {"WorkspaceNameDisplayPosition", "center", seDisplayPositions,
     &wPreferences.workspace_name_display_position, getEnum, NULL, NULL, NULL},
    {"WorkspaceBorder", "AllDirections", seWorkspaceBorder, &wPreferences.workspace_border_position,
     getEnum, updateUsableArea, NULL, NULL},
    {"WorkspaceBorderSize", "0", NULL, &wPreferences.workspace_border_size, getInt,
     updateUsableArea, NULL, NULL},

    /* --- Animations --- */

    {"ShadeSpeed", "medium", seSpeeds, &wPreferences.shade_speed, getEnum, NULL, NULL, NULL},
    {"BounceAppIconsWhenUrgent", "YES", NULL, &wPreferences.bounce_appicons_when_urgent, getBool,
     NULL, NULL, NULL},
    {"RaiseAppIconsWhenBouncing", "NO", NULL, &wPreferences.raise_appicons_when_bouncing, getBool,
     NULL, NULL, NULL},
    {"DoNotMakeAppIconsBounce", "YES", NULL, &wPreferences.do_not_make_appicons_bounce, getBool,
     NULL, NULL, NULL},

    /* --- Options need to get rid of or fix --- */

    /* --- Style options --- */

    {"MenuStyle", "normal", seMenuStyles, &wPreferences.menu_style, getEnum, setMenuStyle, NULL,
     NULL},
    {"WidgetColor", "(solid, \"#aaaaaa\")", NULL, NULL, getTexture, setWidgetColor, NULL, NULL},
    {"IconBack", DEF_ICON_BACK, NULL, NULL, getTexture, setIconTile, NULL, NULL},
    /* NEXTSPACE */
    {"MiniwindowBack", DEF_MINIWINDOW_BACK, NULL, NULL, getTexture, setMiniwindowTile, NULL, NULL},
    {"TitleJustify", "center", seJustifications, &wPreferences.title_justification, getEnum,
     setJustify, NULL, NULL},
    {"WindowTitleFont", DEF_TITLE_FONT, NULL, NULL, getFont, setWinTitleFont, NULL, NULL},
    {"WindowTitleExtendSpace", DEF_WINDOW_TITLE_EXTEND_SPACE, NULL,
     &wPreferences.window_title_clearance, getInt, setClearance, NULL, NULL},
    {"WindowTitleMinHeight", "22", NULL, &wPreferences.window_title_min_height, getInt,
     setClearance, NULL, NULL},
    {"WindowTitleMaxHeight", "22", NULL, &wPreferences.window_title_max_height, getInt,
     setClearance, NULL, NULL},
    {"MenuTitleExtendSpace", DEF_MENU_TITLE_EXTEND_SPACE, NULL, &wPreferences.menu_title_clearance,
     getInt, setClearance, NULL, NULL},
    {"MenuTitleMinHeight", "22", NULL, &wPreferences.menu_title_min_height, getInt, setClearance,
     NULL, NULL},
    {"MenuTitleMaxHeight", "22", NULL, &wPreferences.menu_title_max_height, getInt, setClearance,
     NULL, NULL},
    {"MenuTextExtendSpace", DEF_MENU_TEXT_EXTEND_SPACE, NULL, &wPreferences.menu_text_clearance,
     getInt, setClearance, NULL, NULL},
    {"MenuTitleFont", DEF_MENU_TITLE_FONT, NULL, NULL, getFont, setMenuTitleFont, NULL, NULL},
    {"MenuTextFont", DEF_MENU_ENTRY_FONT, NULL, NULL, getFont, setMenuTextFont, NULL, NULL},
    {"IconTitleFont", DEF_ICON_TITLE_FONT, NULL, NULL, getFont, setIconTitleFont, NULL, NULL},
    {"ClipTitleFont", DEF_CLIP_TITLE_FONT, NULL, NULL, getFont, setClipTitleFont, NULL, NULL},
    {"UseAntialiasedText", "NO", NULL, NULL, getBool, setAntialiasedText, NULL, NULL},
    {"ShowClipTitle", "YES", NULL, &wPreferences.show_clip_title, getBool, NULL, NULL, NULL},
    {"LargeDisplayFont", DEF_WORKSPACE_NAME_FONT, NULL, NULL, getFont, setLargeDisplayFont, NULL,
     NULL},
    {"HighlightColor", "white", NULL, NULL, getColor, setHightlight, NULL, NULL},
    {"HighlightTextColor", "black", NULL, NULL, getColor, setHightlightText, NULL, NULL},
    {"ClipTitleColor", "black", (void *)CLIP_NORMAL, NULL, getColor, setClipTitleColor, NULL, NULL},
    {"CClipTitleColor", "\"#454045\"", (void *)CLIP_COLLAPSED, NULL, getColor, setClipTitleColor,
     NULL, NULL},
    {"FTitleColor", "white", (void *)WS_FOCUSED, NULL, getColor, setWTitleColor, NULL, NULL},
    {"PTitleColor", "white", (void *)WS_PFOCUSED, NULL, getColor, setWTitleColor, NULL, NULL},
    {"UTitleColor", "black", (void *)WS_UNFOCUSED, NULL, getColor, setWTitleColor, NULL, NULL},
    {"FTitleBack", "(solid, black)", NULL, NULL, getTexture, setFTitleBack, NULL, NULL},
    {"PTitleBack", "(solid, \"#555555\")", NULL, NULL, getTexture, setPTitleBack, NULL, NULL},
    {"UTitleBack", "(solid, \"#aaaaaa\")", NULL, NULL, getTexture, setUTitleBack, NULL, NULL},
    {"ResizebarBack", "(solid, \"#aaaaaa\")", NULL, NULL, getTexture, setResizebarBack, NULL, NULL},
    {"MenuTitleColor", "white", NULL, NULL, getColor, setMenuTitleColor, NULL, NULL},
    {"MenuTextColor", "black", NULL, NULL, getColor, setMenuTextColor, NULL, NULL},
    {"MenuDisabledColor", "\"#555555\"", NULL, NULL, getColor, setMenuDisabledColor, NULL, NULL},
    {"MenuTitleBack", "(solid, black)", NULL, NULL, getTexture, setMenuTitleBack, NULL, NULL},
    {"MenuTextBack", "(solid, \"#aaaaaa\")", NULL, NULL, getTexture, setMenuTextBack, NULL, NULL},
    {"IconTitleColor", "white", NULL, NULL, getColor, setIconTitleColor, NULL, NULL},
    {"IconTitleBack", "black", NULL, NULL, getColor, setIconTitleBack, NULL, NULL},
    {"SwitchPanelImages", "(swtile.png, swback.png, 30, 40)", &wPreferences, NULL, getPropList,
     setSwPOptions, NULL, NULL},
    {"ModifierKeyLabels",
     "(\"Shift+\", \"Control+\", \"Alt+\", \"Mod2+\", \"Mod3+\", \"Super+\", \"Mod5+\")",
     &wPreferences, NULL, getPropList, setModifierKeyLabels, NULL, NULL},
    {"FrameBorderWidth", "1", NULL, NULL, getInt, setFrameBorderWidth, NULL, NULL},
    {"FrameBorderColor", "black", NULL, NULL, getColor, setFrameBorderColor, NULL, NULL},
    {"FrameFocusedBorderColor", "black", NULL, NULL, getColor, setFrameFocusedBorderColor, NULL,
     NULL},
    {"FrameSelectedBorderColor", "white", NULL, NULL, getColor, setFrameSelectedBorderColor, NULL,
     NULL},
    {"WorkspaceMapBack", "(solid, black)", NULL, NULL, getTexture, setWorkspaceMapBackground, NULL,
     NULL},

    /* --- Key bindings --- */

    {"CommandModifierKey", "Alt", NULL, &wPreferences.cmd_modifier_mask, getModMask, NULL, NULL,
     NULL},
    {"AlternateModifierKey", "Super", NULL, &wPreferences.alt_modifier_mask, getAltModMask, NULL,
     NULL, NULL},
    /* Dock and Icon Yard */
    /* {"DockHideShowKey", "\"Alternate+D\"", (void *)WKBD_DOCKHIDESHOW, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* {"IconYardHideShowKey", "\"Alternate+Y\"", (void *)WKBD_YARDHIDESHOW, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* Window Resizing */
    /* {"MaximusKey", "\"Super+KP_5\"", (void *)WKBD_MAXIMUS, NULL, getKeybind, setKeyGrab, NULL,
       NULL}, */
    /* {"ShadeKey", "\"Alternate+KP_Subtract\"", (void *)WKBD_SHADE, NULL, getKeybind, setKeyGrab,
       NULL, NULL}, */
    /* {"MaximizeKey", "\"Alternate+KP_Add\"", (void *)WKBD_MAXIMIZE, NULL, getKeybind, setKeyGrab,
       NULL, NULL}, */
    /* {"VMaximizeKey", "\"Alternate+Up\"", (void *)WKBD_VMAXIMIZE, NULL, getKeybind, setKeyGrab,
       NULL, NULL}, */
    /* {"HMaximizeKey", "\"Alternate+Right\"", (void *)WKBD_HMAXIMIZE, NULL, getKeybind, setKeyGrab,
       NULL, NULL}, */
    /* {"LHMaximizeKey", "\"Alternate+KP_4\"", (void *)WKBD_LHMAXIMIZE, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* {"RHMaximizeKey", "\"Alternate+KP_6\"", (void *)WKBD_RHMAXIMIZE, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* {"THMaximizeKey", "\"Alternate+KP_8\"", (void *)WKBD_THMAXIMIZE, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* {"BHMaximizeKey", "\"Alternate+KP_2\"", (void *)WKBD_BHMAXIMIZE, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* {"LTCMaximizeKey", "\"Alternate+KP_7\"", (void *)WKBD_LTCMAXIMIZE, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* {"RTCMaximizeKey", "\"Alternate+KP_9\"", (void *)WKBD_RTCMAXIMIZE, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* {"LBCMaximizeKey", "\"Alternate+KP_1\"", (void *)WKBD_LBCMAXIMIZE, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* {"RBCMaximizeKey", "\"Alternate+KP_3\"", (void *)WKBD_RBCMAXIMIZE, NULL, getKeybind,
       setKeyGrab, NULL, NULL}, */
    /* Window Ordering */
    /* {"CloseKey", "\"Command+w\"", (void *)WKBD_CLOSE, NULL, getKeybind, setKeyGrab, NULL, NULL},
     */
    /* {"HideKey", "\"Command+h\"", (void *)WKBD_HIDE, NULL, getKeybind, setKeyGrab, NULL, NULL}, */
    /* {"HideOthersKey", "\"Command+H\"", (void *)WKBD_HIDE_OTHERS, NULL, getKeybind, setKeyGrab,
       NULL, NULL}, */
    /* {"MiniaturizeKey", "\"Command+m\"", (void *)WKBD_MINIATURIZE, NULL, getKeybind, setKeyGrab,
       NULL, NULL}, */
    /* {"MinimizeAllKey", "\"Command+M\"", (void *)WKBD_MINIMIZEALL, NULL, getKeybind, setKeyGrab,
       NULL, NULL}, */
    /* Focus switch */
    {"RaiseKey", "\"Command+Up\"", (void *)WKBD_RAISE, NULL, getKeybind, setKeyGrab, NULL, NULL},
    {"LowerKey", "\"Command+Down\"", (void *)WKBD_LOWER, NULL, getKeybind, setKeyGrab, NULL, NULL},
    {"FocusNextKey", "\"Command+grave\"", (void *)WKBD_NEXT_WIN, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"FocusPrevKey", "\"Command+Shift+grave\"", (void *)WKBD_PREV_WIN, NULL, getKeybind, setKeyGrab,
     NULL, NULL},
    {"GroupNextKey", "\"Command+Tab\"", (void *)WKBD_NEXT_APP, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"GroupPrevKey", "\"Command+Shift+Tab\"", (void *)WKBD_PREV_APP, NULL, getKeybind, setKeyGrab,
     NULL, NULL},
    /* Workspaces */
    {"NextWorkspaceKey", "\"Control+Right\"", (void *)WKBD_NEXT_DESKTOP, NULL, getKeybind,
     setKeyGrab, NULL, NULL},
    {"PrevWorkspaceKey", "\"Control+Left\"", (void *)WKBD_PREV_DESKTOP, NULL, getKeybind,
     setKeyGrab, NULL, NULL},
    {"LastWorkspaceKey", "None", (void *)WKBD_LAST_DESKTOP, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop1Key", "\"Control+1\"", (void *)WKBD_DESKTOP_1, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop2Key", "\"Control+2\"", (void *)WKBD_DESKTOP_2, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop3Key", "\"Control+3\"", (void *)WKBD_DESKTOP_3, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop4Key", "\"Control+4\"", (void *)WKBD_DESKTOP_4, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop5Key", "\"Control+5\"", (void *)WKBD_DESKTOP_5, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop6Key", "\"Control+6\"", (void *)WKBD_DESKTOP_6, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop7Key", "\"Control+7\"", (void *)WKBD_DESKTOP_7, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop8Key", "\"Control+8\"", (void *)WKBD_DESKTOP_8, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop9Key", "\"Control+9\"", (void *)WKBD_DESKTOP_9, NULL, getKeybind, setKeyGrab, NULL,
     NULL},
    {"Desktop10Key", "\"Control+0\"", (void *)WKBD_DESKTOP_10, NULL, getKeybind, setKeyGrab, NULL,
     NULL},

    {"WindowRelaunchKey", "None", (void *)WKBD_RELAUNCH, NULL, getKeybind, setKeyGrab, NULL, NULL},

    /* --- Mouse cursors --- */
    {"NormalCursor", "(builtin, left_ptr)", (void *)WCUR_ROOT, NULL, getCursor, setCursor, NULL,
     NULL},
    {"ArrowCursor", "(builtin, left_ptr)", (void *)WCUR_ARROW, NULL, getCursor, setCursor, NULL,
     NULL},
    {"ResizeCursor", "(builtin, sizing)", (void *)WCUR_RESIZE, NULL, getCursor, setCursor, NULL,
     NULL},
    {"WaitCursor", "(builtin, watch)", (void *)WCUR_WAIT, NULL, getCursor, setCursor, NULL, NULL},
    {"QuestionCursor", "(builtin, question_arrow)", (void *)WCUR_QUESTION, NULL, getCursor,
     setCursor, NULL, NULL},
    {"TextCursor", "(builtin, xterm)", (void *)WCUR_TEXT, NULL, getCursor, setCursor, NULL, NULL},
    {"SelectCursor", "(builtin, cross)", (void *)WCUR_SELECT, NULL, getCursor, setCursor, NULL,
     NULL},
    {"MoveCursor", "(library, move)", (void *)WCUR_MOVE, NULL, getCursor, setCursor, NULL, NULL},
    {"TopLeftResizeCursor", "(library, bd_double_arrow)", (void *)WCUR_TOPLEFTRESIZE, NULL,
     getCursor, setCursor, NULL, NULL},
    {"TopRightResizeCursor", "(library, fd_double_arrow)", (void *)WCUR_TOPRIGHTRESIZE, NULL,
     getCursor, setCursor, NULL, NULL},
    {"BottomLeftResizeCursor", "(library, fd_double_arrow)", (void *)WCUR_BOTTOMLEFTRESIZE, NULL,
     getCursor, setCursor, NULL, NULL},
    {"BottomRightResizeCursor", "(library, bd_double_arrow)", (void *)WCUR_BOTTOMRIGHTRESIZE, NULL,
     getCursor, setCursor, NULL, NULL},
    {"VerticalResizeCursor", "(library, wm_v_double_arrow)", (void *)WCUR_VERTICALRESIZE, NULL,
     getCursor, setCursor, NULL, NULL},
    {"HorizontalResizeCursor", "(library, wm_h_double_arrow)", (void *)WCUR_HORIZONRESIZE, NULL,
     getCursor, setCursor, NULL, NULL},
    {"UpResizeCursor", "(library, wm_up_arrow)", (void *)WCUR_UPRESIZE, NULL, getCursor, setCursor,
     NULL, NULL},
    {"DownResizeCursor", "(library, wm_down_arrow)", (void *)WCUR_DOWNRESIZE, NULL, getCursor,
     setCursor, NULL, NULL},
    {"LeftResizeCursor", "(library, wm_left_arrow)", (void *)WCUR_LEFTRESIZE, NULL, getCursor,
     setCursor, NULL, NULL},
    {"RightResizeCursor", "(library, wm_right_arrow)", (void *)WCUR_RIGHTRESIZE, NULL, getCursor,
     setCursor, NULL, NULL},
    {"DialogHistoryLines", "500", NULL, &wPreferences.history_lines, getInt, NULL, NULL, NULL},
    {"CycleActiveHeadOnly", "NO", NULL, &wPreferences.cycle_active_head_only, getBool, NULL, NULL,
     NULL},
    {"CycleIgnoreMinimized", "NO", NULL, &wPreferences.cycle_ignore_minimized, getBool, NULL, NULL,
     NULL}};

/* set `plkey` and `plvalue` fields of entries in `optionList` and `staticOptionList` */
static void _initializeOptionLists(void)
{
  unsigned int i;
  WDefaultEntry *entry;

  for (i = 0; i < wlengthof(optionList); i++) {
    entry = &optionList[i];

    entry->plkey = CFStringCreateWithCString(NULL, entry->key, CFStringGetSystemEncoding());
    if (entry->default_value)
      entry->plvalue = WMUserDefaultsFromDescription(entry->default_value);
    else
      entry->plvalue = NULL;
  }

  for (i = 0; i < wlengthof(staticOptionList); i++) {
    entry = &staticOptionList[i];

    entry->plkey = CFStringCreateWithCString(NULL, entry->key, CFStringGetSystemEncoding());
    if (entry->default_value)
      entry->plvalue = WMUserDefaultsFromDescription(entry->default_value);
    else
      entry->plvalue = NULL;
  }
}

static void _updateApplicationIcons(WScreen *scr)
{
  WAppIcon *aicon = scr->app_icon_list;
  WDrawerChain *dc;
  WWindow *wwin = scr->focused_window;

  while (aicon) {
    /* Get the application icon, default included */
    wIconChangeImageFile(aicon->icon, NULL);
    wAppIconPaint(aicon);
    aicon = aicon->next;
  }

  if (!wPreferences.flags.noclip || wPreferences.flags.clip_merged_in_dock)
    wClipIconPaint(scr->clip_icon);

  for (dc = scr->drawers; dc != NULL; dc = dc->next)
    wDrawerIconPaint(dc->adrawer->icon_array[0]);

  while (wwin) {
    if (wwin->icon && wwin->flags.miniaturized)
      wIconChangeImageFile(wwin->icon, NULL);
    wwin = wwin->prev;
  }
}

/*
 * Update in-memory representaion (w_global.domain.<domain>) of defaults domain.
 * domain->timestamp will be updated only in case of successful read and validate 
 * of domain file.
 */
static void _updateDomain(WDDomain *domain, Bool shouldNotify)
{
  WScreen *scr;
  CFMutableDictionaryRef dict;

  if (!domain) {
    WMLogError("Could not update NULL domain.");
    return;
  }

#ifdef HAVE_INOTIFY
  if (domain->inotify_watch >= 0) {
    wDefaultsShouldTrackChanges(domain, false);
  }
#endif
  
  WMLogWarning("Updating domain %@...", domain->name);
  /* User dictionary */
  dict = (CFMutableDictionaryRef)WMUserDefaultsRead(domain->name, false);
  if (dict) {
    if (CFGetTypeID(dict) == CFDictionaryGetTypeID()) {
      if ((scr = wDefaultScreen()) && CFStringCompare(domain->name, CFSTR("WM"), 0) == 0) {
        wDefaultsReadPreferences(scr, dict, shouldNotify);
      }
      if (domain->dictionary) {
        CFRelease(domain->dictionary);
      }
      domain->dictionary = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, dict);
    } else {
      WMLogError("Domain %@ of defaults database is corrupted!", domain->name);
    }
    CFRelease(dict);
    dict = NULL;
  } else {
    WMLogError("Could not load domain %@. It is not dictionary!", domain->name);
    if (domain->dictionary) {
      WMLogError("Write from memory to path %@.", domain->path);
      WMUserDefaultsWrite(domain->dictionary, domain->name);
    }
  }

  domain->timestamp = WMUserDefaultsFileModificationTime(domain->name, 0);
#ifdef HAVE_INOTIFY
  if (domain->shouldTrackChanges) {
    wDefaultsShouldTrackChanges(domain, true);
  }
#endif
}

#ifdef HAVE_INOTIFY

static WDDomain *_domainForWatchDescriptor(int wd)
{
  if (wd == w_global.domain.wm_preferences->inotify_watch) {
    return w_global.domain.wm_preferences;
  }
  if (wd == w_global.domain.wm_state->inotify_watch) {
    return w_global.domain.wm_state;
  }
  if (wd == w_global.domain.window_attrs->inotify_watch) {
    return w_global.domain.window_attrs;
  }

  return NULL;
}

static void _processWatchEvents(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
  ssize_t eventQLength;
  size_t i = 0;
  /* Make room for at lease 5 simultaneous events, with path + filenames */
  char buff[ (sizeof(struct inotify_event) + NAME_MAX + 1) * 5 ];
  WDDomain *domain;

  WMLogError("_inotifyHandleEvents");

  /*
   * Read off the queued events queue overflow is not checked (IN_Q_OVERFLOW).
   */
  eventQLength = read(w_global.inotify.fd_event_queue, buff, sizeof(buff));

  if (eventQLength <= 0) {
    // There's a problem to get events from queue. Enable callbacks again and wait for next event.
    WMLogError("inotify: read problem when trying to get event: %s", strerror(errno));
    goto done;
  }

  /* Check what events occured */
  while (i < eventQLength) {
    struct inotify_event *pevent = (struct inotify_event *)&buff[i];

    domain = _domainForWatchDescriptor(pevent->wd);
    if (!domain) {
      WMLogWarning("inotify [descriptor %i]: ignore event for domain that is not tracked anymore.",
                   pevent->wd);
      goto next_event;
    }

    if (pevent->mask & IN_MODIFY) {
      WMLogWarning("inotify [descriptor %i]: defaults domain has been modified.", pevent->wd);
      wDefaultsUpdateDomainsIfNeeded(NULL);
    }
    
    if (pevent->mask & IN_MOVE_SELF) {
      WMLogWarning("inotify [descriptor %i]: defaults domain has been moved.", pevent->wd);
      wDefaultsUpdateDomainsIfNeeded(NULL);
    }
    
    if (pevent->mask & IN_DELETE_SELF) {
      WMLogWarning("inotify [descriptor %i]: defaults domain has been deleted.", pevent->wd);
      wDefaultsUpdateDomainsIfNeeded(NULL);
    }
    
    if (pevent->mask & IN_UNMOUNT) {
      WMLogWarning("inotify: the unit containing the defaults database has"
                   " been unmounted. Disabling tracking changes mode."
                   " Any changes will not be saved.");

      wDefaultsShouldTrackChanges(domain, false);
      wPreferences.flags.noupdates = 1;
    }

  next_event:
    /* move to next event in the buffer */
    i += sizeof(struct inotify_event) + pevent->len;
  }

done:
  CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
}

static Bool _initializeInotify()
{
  w_global.inotify.fd_event_queue = inotify_init1(O_NONBLOCK);
  if (w_global.inotify.fd_event_queue < 0) {
    WMLogWarning("** inotify ** could not initialise an inotify instance."
                 " Changes to the defaults database will require a restart to take effect.");
    return False;
  } else {  // Add to runloop
    CFFileDescriptorRef ifd = NULL;
    CFRunLoopSourceRef ifd_source = NULL;

    ifd = CFFileDescriptorCreate(kCFAllocatorDefault, w_global.inotify.fd_event_queue, true,
                                 _processWatchEvents, NULL);
    CFFileDescriptorEnableCallBacks(ifd, kCFFileDescriptorReadCallBack);

    ifd_source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, ifd, 0);
    CFRunLoopAddSource(wm_runloop, ifd_source, kCFRunLoopDefaultMode);
    CFRelease(ifd_source);
    CFRelease(ifd);
  }

  return True;
}

void wDefaultsShouldTrackChanges(WDDomain *domain, Bool shouldTrack)
{
  CFStringRef domainPath = NULL;
  const char *watchPath = NULL;

  if (!domain) {
    return;
  }

  if (!wm_runloop) {
    return;
  }

  // Initialize inotify if needed
  if ((w_global.inotify.fd_event_queue < 0) && (_initializeInotify() == False)) {
    return;
  }

  // Create watcher
  if (shouldTrack == true) {
    uint32_t mask = IN_MOVE_SELF| IN_DELETE_SELF | IN_MODIFY | IN_UNMOUNT;
    
    domainPath = CFURLCopyFileSystemPath(domain->path, kCFURLPOSIXPathStyle);
    watchPath = CFStringGetCStringPtr(domainPath, kCFStringEncodingUTF8);
  
    WMLogError("inotify: will add watch for %s.", watchPath);
    domain->inotify_watch = inotify_add_watch(w_global.inotify.fd_event_queue, watchPath, mask);
    
    if (domain->inotify_watch < 0) {
      WMLogWarning("** inotify ** could not add an inotify watch on path %s (error: %i %s)."
                   " Changes to the defaults database will require a restart to take effect.",
                   watchPath, errno, strerror(errno));
    }
    CFRelease(domainPath);
  } else if (domain->inotify_watch >= 0) {
    WMLogError("inotify: will remove watch for %@.", domain->name);
    inotify_rm_watch(w_global.inotify.fd_event_queue, domain->inotify_watch);
    domain->inotify_watch = -1;
  }
  // else shouldTrack == false but domain is not tracked for changes - do nothing.
}

#endif /* HAVE_INOTIFY */

static void _settingsObserver(CFNotificationCenterRef center,
                              void *observer,  // NULL
                              CFNotificationName name,
                              const void *object,  // object - ignored
                              CFDictionaryRef userInfo)
{
  wDefaultsUpdateDomainsIfNeeded(NULL);
}

// Called from startup.c
static Bool isOptionListsIntialized = false;
static Bool isObserverSet = false;
WDDomain *wDefaultsInitDomain(const char *domain_name, Bool shouldTrackChanges)
{
  WDDomain *domain;
  CFMutableDictionaryRef dict;

  if (isOptionListsIntialized == false) {
    isOptionListsIntialized = true;
    _initializeOptionLists();
  }

  // TODO: check if domain already exist
  WMLogWarning("initializing domain: %s", domain_name);

  domain = wmalloc(sizeof(WDDomain));
  domain->name = CFStringCreateWithCString(kCFAllocatorDefault, domain_name, kCFStringEncodingUTF8);
  domain->inotify_watch = -1;
  domain->shouldTrackChanges = shouldTrackChanges;

  // Initializing domain->dictionary
  dict = (CFMutableDictionaryRef)WMUserDefaultsRead(domain->name, true);
  if (dict) {
    if ((CFGetTypeID(dict) != CFDictionaryGetTypeID())) {
      CFRelease(dict);
      domain->dictionary = NULL;
      WMLogError("domain %s (%@) of defaults database is corrupted!", domain_name,
                 CFURLGetString(domain->path));
    }
    domain->dictionary = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, dict);
    CFRelease(dict);
  } else {
    WMLogError("creating empty domain: %@", domain->name);
    domain->dictionary = CFDictionaryCreateMutable(
        kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  }

  if (domain->dictionary && WMUserDefaultsWrite(domain->dictionary, domain->name)) {
    CFURLRef osURL;
    
    domain->timestamp = WMUserDefaultsFileModificationTime(domain->name, 0);
    // Dictionary was written to .plist file - set domain->path
    osURL = WMUserDefaultsCopyURLForDomain(domain->name);
    domain->path = CFURLCreateCopyAppendingPathExtension(NULL, osURL, CFSTR("plist"));
    CFRelease(osURL);

    wDefaultsShouldTrackChanges(domain, shouldTrackChanges);

    // first domain without tracking changes (inotify)
    if ((shouldTrackChanges == false) && (isObserverSet == false)) {
      WMLogError("Setting up `WMSettingsDidChangeNotification` observer...");
      CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, _settingsObserver,
                                      WMDidChangeAppearanceSettingsNotification, NULL,
                                      CFNotificationSuspensionBehaviorDeliverImmediately);
    }
  }

  return domain;
}

// Called from startup.c
// Apply `plvalue` from `dict` to appropriate `entry->addr` specified in `staticOptionList`
void wDefaultsReadStaticPreferences(CFMutableDictionaryRef dict)
{
  CFTypeRef plvalue;
  WDefaultEntry *entry;
  unsigned int i;
  void *tdata;

  for (i = 0; i < wlengthof(staticOptionList); i++) {
    entry = &staticOptionList[i];

    if (dict)
      plvalue = CFDictionaryGetValue(dict, entry->plkey);
    else
      plvalue = NULL;

    // No need to hold default value in dictionary
    if (plvalue && CFEqual(plvalue, entry->plvalue)) {
      plvalue = NULL;
      CFDictionaryRemoveValue(dict, entry->plkey);
    }
    
    /* no default in the DB. Use builtin default */
    if (!plvalue)
      plvalue = entry->plvalue;

    if (plvalue) {
      /* convert data */
      (*entry->convert) (NULL, entry, plvalue, entry->addr, &tdata);
      if (entry->update)
        (*entry->update) (NULL, entry, tdata, entry->extra_data);
    }
  }
}

// Propagates `optionList` values to `wPreferences`, `WScreen` or other global variable.
// If option exists in `new_dict` - use it instead.
// Usually `new_dict` is a `w_global.domain.wm_preferences->dictionary` which is the in-memory
// representation of WM.plist file.
//
// Function applies `plvalue` from `new_dict` to appropriate `entry->addr` specified in `optionList`.
// `entry->addr` is a wPreferences member or `NULL`. `NULL` means that `entry->update` callback
// sets value to appropriate structure (for example, WScreen) or global variable.
void wDefaultsReadPreferences(WScreen *scr, CFMutableDictionaryRef new_dict, Bool shouldNotify)
{
  CFDictionaryRef old_dict = NULL;
  CFTypeRef plvalue = NULL;
  CFTypeRef old_plvalue = NULL;
  WDefaultEntry *entry;
  unsigned int i;
  unsigned int needs_refresh = 0;
  void *tdata;

  WMLogWarning("Reading preferences from WM.plist....");

  if (w_global.domain.wm_preferences->dictionary != new_dict) {
    old_dict = w_global.domain.wm_preferences->dictionary;
  }

  WMLogWarning("WindowTitleFont from new_dict %@", CFDictionaryGetValue(new_dict, CFSTR("WindowTitleFont")));

  for (i = 0; i < wlengthof(optionList); i++) {
    entry = &optionList[i];

    if (new_dict) {
      plvalue = CFDictionaryGetValue(new_dict, entry->plkey);
    } else {
      plvalue = NULL;
    }

    if (old_dict) {
      old_plvalue = CFDictionaryGetValue(old_dict, entry->plkey);
    } else {
      old_plvalue = NULL;
    }

    // No need to hold default value in dictionary
    if (plvalue && CFEqual(plvalue, entry->plvalue)) {
      plvalue = NULL;
      CFDictionaryRemoveValue(new_dict, entry->plkey);
    }

    if (!plvalue) {
      // value was deleted from DB. Keep current value
      plvalue = entry->plvalue;
    } else if (!old_plvalue) {
      // set value for the 1st time
    } else if (CFEqual(plvalue, old_plvalue)) {
      // value was not changed since last time
      continue;
    }

    if (plvalue) {
      // convert data
      if ((*entry->convert) (scr, entry, plvalue, entry->addr, &tdata)) {
        // propagate converted value
        if (entry->update) {
          needs_refresh |= (*entry->update) (scr, entry, tdata, entry->extra_data);
        }
      }
    }
  }

  if (shouldNotify && needs_refresh != 0 /* && !scr->flags.startup && !scr->flags.startup2*/) {
    int foo;

    foo = 0;
    if (needs_refresh & REFRESH_MENU_TITLE_TEXTURE)
      foo |= WTextureSettings;
    if (needs_refresh & REFRESH_MENU_TITLE_FONT)
      foo |= WFontSettings;
    if (needs_refresh & REFRESH_MENU_TITLE_COLOR)
      foo |= WColorSettings;
    if (foo) {
      CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                           WMDidChangeMenuTitleAppearanceSettings,
                                           (void *)(uintptr_t)foo, NULL, TRUE);
    }
    foo = 0;
    if (needs_refresh & REFRESH_MENU_TEXTURE)
      foo |= WTextureSettings;
    if (needs_refresh & REFRESH_MENU_FONT)
      foo |= WFontSettings;
    if (needs_refresh & REFRESH_MENU_COLOR)
      foo |= WColorSettings;
    if (foo) {
      CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                           WMDidChangeMenuAppearanceSettings,
                                           (void *)(uintptr_t)foo, NULL, TRUE);
    }
    foo = 0;
    if (needs_refresh & REFRESH_WINDOW_FONT)
      foo |= WFontSettings;
    if (needs_refresh & REFRESH_WINDOW_TEXTURES)
      foo |= WTextureSettings;
    if (needs_refresh & REFRESH_WINDOW_TITLE_COLOR)
      foo |= WColorSettings;
    if (foo) {
      CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                           WMDidChangeWindowAppearanceSettings,
                                           (void *)(uintptr_t)foo, NULL, TRUE);
    }
    if (!(needs_refresh & REFRESH_ICON_TILE)) {
      foo = 0;
      if (needs_refresh & REFRESH_ICON_FONT)
        foo |= WFontSettings;
      if (needs_refresh & REFRESH_ICON_TITLE_COLOR)
        foo |= WTextureSettings;
      if (needs_refresh & REFRESH_ICON_TITLE_BACK)
        foo |= WTextureSettings;
      if (foo) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                             WMDidChangeIconAppearanceSettings,
                                             (void *)(uintptr_t)foo, NULL, TRUE);
      }
    }
    if (needs_refresh & REFRESH_ICON_TILE) {
      CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                           WMDidChangeIconTileSettings, 
                                           NULL, NULL, TRUE);
    }
  }
}

// Update in-memory representaion of user defaults.
// Also used as CFTimer callback - that's why argument exists.
void wDefaultsUpdateDomainsIfNeeded(void* arg)
{
  WScreen *scr;
  CFAbsoluteTime time = 0.0;

   // ~/Library/Preferences/.NextSpace/WM.plist
  time = WMUserDefaultsFileModificationTime(w_global.domain.wm_preferences->name, 0);
  if (w_global.domain.wm_preferences->timestamp < time) {
    _updateDomain(w_global.domain.wm_preferences, True);
  }

  // ~/Library/Preferences/.NextSpace/WMState.plist
  time = WMUserDefaultsFileModificationTime(w_global.domain.wm_state->name, 0);
  if (w_global.domain.wm_state->timestamp < time) {
    _updateDomain(w_global.domain.wm_state, True);
  }

  // ~/Library/Preferences/.NextSpace/WMWindowAttributes.plist
  time = WMUserDefaultsFileModificationTime(w_global.domain.window_attrs->name, 0);
  if (w_global.domain.window_attrs->timestamp < time) {
    _updateDomain(w_global.domain.window_attrs, False);
    if ((scr = wDefaultScreen())) {
      _updateApplicationIcons(scr);
    }
  }

#ifndef HAVE_INOTIFY
  if (!arg) {
    WMAddTimerHandler(DEFAULTS_CHECK_INTERVAL, wDefaultsUpdateDomainsIfNeeded, NULL);
  }
#endif
}

/* --------------------------- Local ----------------------- */

#define GET_STRING_OR_DEFAULT(x, var) if (CFGetTypeID(value) != CFStringGetTypeID()) { \
    WMLogWarning(_("Wrong option format for key \"%s\". Should be %s."), entry->key, x); \
    WMLogWarning(_("using default \"%s\" instead"), entry->default_value);  \
    var = entry->default_value;                                         \
  } else var = WMUserDefaultsGetCString(value, kCFStringEncodingUTF8);  \


static int string2index(CFTypeRef key, CFTypeRef val, const char *def, WOptionEnumeration *values)
{
  const char *str = NULL;
  WOptionEnumeration *v;
  char buffer[TOTAL_VALUES_LENGTH];

  if (CFGetTypeID(val) == CFStringGetTypeID()) {
    str = WMUserDefaultsGetCString(val, kCFStringEncodingUTF8);
  }
  
  if (str) {
    for (v = values; v->string != NULL; v++) {
      if (strcasecmp(v->string, str) == 0)
        return v->value;
    }
  }

  buffer[0] = 0;
  for (v = values; v->string != NULL; v++) {
    if (!v->is_alias) {
      if (buffer[0] != 0)
        strcat(buffer, ", ");
      snprintf(buffer+strlen(buffer), sizeof(buffer)-strlen(buffer)-1, "\"%s\"", v->string);
    }
  }
  WMLogWarning(_("wrong option value for key \"%s\"; got \"%s\", should be one of %s."),
           WMUserDefaultsGetCString(key, kCFStringEncodingUTF8),
           str ? str : "(unknown)",
           buffer);

  if (def) {
    return string2index(key, val, NULL, values);
  }

  return -1;
}

/*
 * value - is the value in the defaults DB
 * addr - is the address to store the data
 * ret - is the address to store a pointer to a temporary buffer. ret
 * 	must not be freed and is used by the set functions
 */
static int getBool(WScreen *scr, WDefaultEntry *entry, CFTypeRef value, void *addr, void **ret)
{
  static char data;
  const char *val;
  int second_pass = 0;

  GET_STRING_OR_DEFAULT("Boolean", val);

 again:
  if ((val[1] == '\0' && (val[0] == 'y' || val[0] == 'Y'))
      || strcasecmp(val, "YES") == 0) {

    data = 1;
  } else if ((val[1] == '\0' && (val[0] == 'n' || val[0] == 'N'))
             || strcasecmp(val, "NO") == 0) {
    data = 0;
  } else {
    int i;
    if (sscanf(val, "%i", &i) == 1) {
      if (i != 0)
        data = 1;
      else
        data = 0;
    } else {
      WMLogWarning(_("can't convert \"%s\" to boolean for key \"%s\""), val, entry->key);
      if (second_pass == 0) {
        val = WMUserDefaultsGetCString(entry->plvalue, kCFStringEncodingUTF8);
        second_pass = 1;
        WMLogWarning(_("using default \"%s\" instead"), val);
        goto again;
      }
      return False;
    }
  }

  if (ret)
    *ret = &data;
  if (addr)
    *(char *)addr = data;

  return True;
}

static int getInt(WScreen *scr, WDefaultEntry *entry, CFTypeRef value, void *addr, void **ret)
{
  static int data;
  const char *val;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;

  GET_STRING_OR_DEFAULT("Integer", val);

  if (sscanf(val, "%i", &data) != 1) {
    WMLogWarning(_("can't convert \"%s\" to integer for key \"%s\""), val, entry->key);
    val = WMUserDefaultsGetCString(entry->plvalue, kCFStringEncodingUTF8);
    WMLogWarning(_("using default \"%s\" instead"), val);
    if (sscanf(val, "%i", &data) != 1) {
      return False;
    }
  }

  if (ret)
    *ret = &data;
  if (addr)
    *(int *)addr = data;

  return True;
}

static int getCoord(WScreen *scr, WDefaultEntry *entry, CFTypeRef value, void *addr, void **ret)
{
  static WMPoint data;
  const char *val_x, *val_y;
  int nelem, changed = 0;
  CFStringRef elem_x, elem_y;

 again:
  if (CFGetTypeID(value) != CFArrayGetTypeID()) {
    WMLogWarning(_("Wrong option format for key \"%s\". Should be %s."), entry->key, "Coordinate");
    if (changed == 0) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return False;
  }

  nelem = CFArrayGetCount(value);
  if (nelem != 2) {
    WMLogWarning(_("Incorrect number of elements in array for key \"%s\"."), entry->key);
    if (changed == 0) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return False;
  }

  elem_x = CFArrayGetValueAtIndex(value, 0);
  elem_y = CFArrayGetValueAtIndex(value, 1);

  if (!elem_x || !elem_y /*|| !WMIsPLString(elem_x) || !WMIsPLString(elem_y)*/) {
    WMLogWarning(_("Wrong value for key \"%s\". Should be Coordinate."), entry->key);
    if (changed == 0) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return False;
  }

  val_x = WMUserDefaultsGetCString(elem_x, kCFStringEncodingUTF8);
  val_y = WMUserDefaultsGetCString(elem_y, kCFStringEncodingUTF8);

  if (sscanf(val_x, "%i", &data.x) != 1 || sscanf(val_y, "%i", &data.y) != 1) {
    WMLogWarning(_("can't convert array to integers for \"%s\"."), entry->key);
    if (changed == 0) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return False;
  }

  if (data.x < 0)
    data.x = 0;
  else if (data.x > scr->width / 3)
    data.x = scr->width / 3;
  if (data.y < 0)
    data.y = 0;
  else if (data.y > scr->height / 3)
    data.y = scr->height / 3;

  if (ret)
    *ret = &data;
  if (addr)
    *(WMPoint *) addr = data;

  return True;
}

static int getPropList(WScreen *scr, WDefaultEntry *entry, CFTypeRef value, void *addr, void **ret)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) entry;
  (void) addr;

  CFRetain(value);

  *ret = (void *)value;

  return True;
}

static int getPathList(WScreen *scr, WDefaultEntry *entry, CFTypeRef value, void *addr, void **ret)
{
  static char *data;
  int i, count, len;
  char *ptr;
  CFTypeRef d;
  int changed = 0;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) ret;

 again:
  if (CFGetTypeID(value) != CFArrayGetTypeID()) {
    WMLogWarning(_("Wrong option format for key \"%s\". Should be %s."), entry->key,
             "an array of paths");
    if (changed == 0) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return False;
  }

  i = 0;
  count = CFArrayGetCount(value);
  if (count < 1) {
    if (changed == 0) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return False;
  }

  len = 0;
  for (i = 0; i < count; i++) {
    d = CFArrayGetValueAtIndex(value, i);
    if (!d || (CFGetTypeID(d) != CFStringGetTypeID())) {
      count = i;
      break;
    }
    len += strlen(WMUserDefaultsGetCString(d, kCFStringEncodingUTF8)) + 1;
  }

  ptr = data = wmalloc(len + 1);

  for (i = 0; i < count; i++) {
    d = CFArrayGetValueAtIndex(value, i);
    if (!d || (CFGetTypeID(d) != CFStringGetTypeID())) {
      break;
    }
    strcpy(ptr, WMUserDefaultsGetCString(d, kCFStringEncodingUTF8));
    ptr += strlen(WMUserDefaultsGetCString(d, kCFStringEncodingUTF8));
    *ptr = ':';
    ptr++;
  }
  ptr--;
  *(ptr--) = 0;

  if (*(char **)addr != NULL) {
    wfree(*(char **)addr);
  }
  *(char **)addr = data;

  return True;
}

static int getEnum(WScreen *scr, WDefaultEntry *entry, CFTypeRef value, void *addr, void **ret)
{
  static signed char data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;

  data = string2index(entry->plkey, value, entry->default_value, (WOptionEnumeration *)entry->extra_data);
  if (data < 0)
    return False;

  if (ret)
    *ret = &data;
  if (addr)
    *(signed char *)addr = data;

  return True;
}

/*
 * (solid <color>)
 * (hgradient <color> <color>)
 * (vgradient <color> <color>)
 * (dgradient <color> <color>)
 * (mhgradient <color> <color> ...)
 * (mvgradient <color> <color> ...)
 * (mdgradient <color> <color> ...)
 * (igradient <color1> <color1> <thickness1> <color2> <color2> <thickness2>)
 * (tpixmap <file> <color>)
 * (spixmap <file> <color>)
 * (cpixmap <file> <color>)
 * (thgradient <file> <opaqueness> <color> <color>)
 * (tvgradient <file> <opaqueness> <color> <color>)
 * (tdgradient <file> <opaqueness> <color> <color>)
 * (function <lib> <function> ...)
 */

static WTexture *parse_texture(WScreen *scr, CFTypeRef pl)
{
  CFTypeRef elem;
  const char *val;
  int nelem;
  WTexture *texture = NULL;

  nelem = CFArrayGetCount(pl);
  if (nelem < 1)
    return NULL;

  elem = CFArrayGetValueAtIndex(pl, 0);
  if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
    return NULL;
  val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

  if (strcasecmp(val, "solid") == 0) {
    XColor color;

    if (nelem != 2)
      return NULL;

    /* get color */

    elem = CFArrayGetValueAtIndex(pl, 1);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    if (!XParseColor(dpy, scr->w_colormap, val, &color)) {
      WMLogWarning(_("\"%s\" is not a valid color name"), val);
      return NULL;
    }

    texture = (WTexture *) wTextureMakeSolid(scr, &color);
  } else if (strcasecmp(val, "dgradient") == 0
             || strcasecmp(val, "vgradient") == 0 || strcasecmp(val, "hgradient") == 0) {
    RColor color1, color2;
    XColor xcolor;
    int type;

    if (nelem != 3) {
      WMLogWarning(_("bad number of arguments in gradient specification"));
      return NULL;
    }

    if (val[0] == 'd' || val[0] == 'D')
      type = WTEX_DGRADIENT;
    else if (val[0] == 'h' || val[0] == 'H')
      type = WTEX_HGRADIENT;
    else
      type = WTEX_VGRADIENT;

    /* get from color */
    elem = CFArrayGetValueAtIndex(pl, 1);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
      WMLogWarning(_("\"%s\" is not a valid color name"), val);
      return NULL;
    }
    color1.alpha = 255;
    color1.red = xcolor.red >> 8;
    color1.green = xcolor.green >> 8;
    color1.blue = xcolor.blue >> 8;

    /* get to color */
    elem = CFArrayGetValueAtIndex(pl, 2);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
      WMLogWarning(_("\"%s\" is not a valid color name"), val);
      return NULL;
    }
    color2.alpha = 255;
    color2.red = xcolor.red >> 8;
    color2.green = xcolor.green >> 8;
    color2.blue = xcolor.blue >> 8;

    texture = (WTexture *) wTextureMakeGradient(scr, type, &color1, &color2);

  } else if (strcasecmp(val, "igradient") == 0) {
    RColor colors1[2], colors2[2];
    int th1, th2;
    XColor xcolor;
    int i;

    if (nelem != 7) {
      WMLogWarning(_("bad number of arguments in gradient specification"));
      return NULL;
    }

    /* get from color */
    for (i = 0; i < 2; i++) {
      elem = CFArrayGetValueAtIndex(pl, 1 + i);
      if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
        return NULL;
      val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

      if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
        WMLogWarning(_("\"%s\" is not a valid color name"), val);
        return NULL;
      }
      colors1[i].alpha = 255;
      colors1[i].red = xcolor.red >> 8;
      colors1[i].green = xcolor.green >> 8;
      colors1[i].blue = xcolor.blue >> 8;
    }
    elem = CFArrayGetValueAtIndex(pl, 3);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);
    th1 = atoi(val);

    /* get from color */
    for (i = 0; i < 2; i++) {
      elem = CFArrayGetValueAtIndex(pl, 4 + i);
      if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
        return NULL;
      val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

      if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
        WMLogWarning(_("\"%s\" is not a valid color name"), val);
        return NULL;
      }
      colors2[i].alpha = 255;
      colors2[i].red = xcolor.red >> 8;
      colors2[i].green = xcolor.green >> 8;
      colors2[i].blue = xcolor.blue >> 8;
    }
    elem = CFArrayGetValueAtIndex(pl, 6);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);
    th2 = atoi(val);

    texture = (WTexture *) wTextureMakeIGradient(scr, th1, colors1, th2, colors2);

  } else if (strcasecmp(val, "mhgradient") == 0
             || strcasecmp(val, "mvgradient") == 0 || strcasecmp(val, "mdgradient") == 0) {
    XColor color;
    RColor **colors;
    int i, count;
    int type;

    if (nelem < 3) {
      WMLogWarning(_("too few arguments in multicolor gradient specification"));
      return NULL;
    }

    if (val[1] == 'h' || val[1] == 'H')
      type = WTEX_MHGRADIENT;
    else if (val[1] == 'v' || val[1] == 'V')
      type = WTEX_MVGRADIENT;
    else
      type = WTEX_MDGRADIENT;

    count = nelem - 1;

    colors = wmalloc(sizeof(RColor *) * (count + 1));

    for (i = 0; i < count; i++) {
      elem = CFArrayGetValueAtIndex(pl, i + 1);
      if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID())) {
        for (--i; i >= 0; --i) {
          wfree(colors[i]);
        }
        wfree(colors);
        return NULL;
      }
      val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

      if (!XParseColor(dpy, scr->w_colormap, val, &color)) {
        WMLogWarning(_("\"%s\" is not a valid color name"), val);
        for (--i; i >= 0; --i) {
          wfree(colors[i]);
        }
        wfree(colors);
        return NULL;
      } else {
        colors[i] = wmalloc(sizeof(RColor));
        colors[i]->red = color.red >> 8;
        colors[i]->green = color.green >> 8;
        colors[i]->blue = color.blue >> 8;
      }
    }
    colors[i] = NULL;

    texture = (WTexture *) wTextureMakeMGradient(scr, type, colors);
  } else if (strcasecmp(val, "spixmap") == 0 ||
             strcasecmp(val, "cpixmap") == 0 || strcasecmp(val, "tpixmap") == 0) {
    XColor color;
    int type;

    if (nelem != 3)
      return NULL;

    if (val[0] == 's' || val[0] == 'S')
      type = WTP_SCALE;
    else if (val[0] == 'c' || val[0] == 'C')
      type = WTP_CENTER;
    else
      type = WTP_TILE;

    /* get color */
    elem = CFArrayGetValueAtIndex(pl, 2);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    if (!XParseColor(dpy, scr->w_colormap, val, &color)) {
      WMLogWarning(_("\"%s\" is not a valid color name"), val);
      return NULL;
    }

    /* file name */
    elem = CFArrayGetValueAtIndex(pl, 1);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    texture = (WTexture *) wTextureMakePixmap(scr, type, val, &color);
  } else if (strcasecmp(val, "thgradient") == 0
             || strcasecmp(val, "tvgradient") == 0 || strcasecmp(val, "tdgradient") == 0) {
    RColor color1, color2;
    XColor xcolor;
    int opacity;
    int style;

    if (val[1] == 'h' || val[1] == 'H')
      style = WTEX_THGRADIENT;
    else if (val[1] == 'v' || val[1] == 'V')
      style = WTEX_TVGRADIENT;
    else
      style = WTEX_TDGRADIENT;

    if (nelem != 5) {
      WMLogWarning(_("bad number of arguments in textured gradient specification"));
      return NULL;
    }

    /* get from color */
    elem = CFArrayGetValueAtIndex(pl, 3);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
      WMLogWarning(_("\"%s\" is not a valid color name"), val);
      return NULL;
    }
    color1.alpha = 255;
    color1.red = xcolor.red >> 8;
    color1.green = xcolor.green >> 8;
    color1.blue = xcolor.blue >> 8;

    /* get to color */
    elem = CFArrayGetValueAtIndex(pl, 4);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
      WMLogWarning(_("\"%s\" is not a valid color name"), val);
      return NULL;
    }
    color2.alpha = 255;
    color2.red = xcolor.red >> 8;
    color2.green = xcolor.green >> 8;
    color2.blue = xcolor.blue >> 8;

    /* get opacity */
    elem = CFArrayGetValueAtIndex(pl, 2);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      opacity = 128;
    else
      val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    if (!val || (opacity = atoi(val)) < 0 || opacity > 255) {
      WMLogWarning(_("bad opacity value for tgradient texture \"%s\". Should be [0..255]"), val);
      opacity = 128;
    }

    /* get file name */
    elem = CFArrayGetValueAtIndex(pl, 1);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID()))
      return NULL;
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    texture = (WTexture *)wTextureMakeTGradient(scr, style, &color1, &color2, val, opacity);
  } else if (strcasecmp(val, "function") == 0) {
    /* Leave this in to handle the unlikely case of
     * someone actually having function textures configured */
    WMLogWarning("function texture support has been removed");
    return NULL;
  } else {
    WMLogWarning(_("invalid texture type %s"), val);
    return NULL;
  }
  return texture;
}

static int getTexture(WScreen *scr, WDefaultEntry *entry, CFTypeRef value, void *addr, void **ret)
{
  const char *val;
  static WTexture *texture;
  int changed = 0;

 again:
  /* if (CFGetTypeID(value) != CFArrayGetTypeID()) { */
  /*   WMLogWarning(_("Wrong option format for key \"%s\". Should be %s."), entry->key, "Texture"); */
  /*   if (changed == 0) { */
  /*     value = entry->plvalue; */
  /*     changed = 1; */
  /*     WMLogWarning(_("using default \"%s\" instead"), entry->default_value); */
  /*     goto again; */
  /*   } */
  /*   return False; */
  /* } */

  if (strcmp(entry->key, "WidgetColor") == 0 && !changed) {
    CFTypeRef pl = CFArrayGetValueAtIndex(value, 0);

    if (pl && (CFGetTypeID(pl) == CFStringGetTypeID())) {
      val = WMUserDefaultsGetCString(pl, kCFStringEncodingUTF8);
    }
    if (!val || strcasecmp(val, "solid") != 0) {
      WMLogWarning(_("Wrong option format for key \"%s\". Should be %s."),
               entry->key, "Solid Texture");

      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
  }

  texture = parse_texture(scr, value);

  if (!texture) {
    WMLogWarning(_("Error in texture specification for key \"%s\""), entry->key);
    if (changed == 0) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return False;
  }

  if (ret)
    *ret = &texture;

  if (addr)
    *(WTexture **) addr = texture;

  return True;
}

static int getFont(WScreen *scr, WDefaultEntry *entry, CFTypeRef value, void *addr, void **ret)
{
  static WMFont *font;
  const char *val;

  (void) addr;

  GET_STRING_OR_DEFAULT("Font", val);

  font = WMCreateFont(scr->wmscreen, val);
  if (!font)
    font = WMCreateFont(scr->wmscreen, "fixed");

  if (!font) {
    WMLogCritical(_("could not load any usable font!!!"));
    exit(1);
  }

  if (ret)
    *ret = font;

  /* can't assign font value outside update function */
  wassertrv(addr == NULL, True);

  return True;
}

static int getColor(WScreen * scr, WDefaultEntry * entry, CFTypeRef value, void *addr, void **ret)
{
  static XColor color;
  const char *val;
  int second_pass = 0;

  (void) addr;

  GET_STRING_OR_DEFAULT("Color", val);

 again:
  if (!wGetColor(scr, val, &color)) {
    WMLogWarning(_("could not get color for key \"%s\""), entry->key);
    if (second_pass == 0) {
      val = WMUserDefaultsGetCString(entry->plvalue, kCFStringEncodingUTF8);
      second_pass = 1;
      WMLogWarning(_("using default \"%s\" instead"), val);
      goto again;
    }
    return False;
  }

  if (ret)
    *ret = &color;

  assert(addr == NULL);
  /*
    if (addr)
    *(unsigned long*)addr = pixel;
    */

  return True;
}

static int getKeybind(WScreen * scr, WDefaultEntry * entry, CFTypeRef value, void *addr, void **ret)
{
  static WShortKey shortcut;
  KeySym ksym;
  const char *val;
  char *k;
  char buf[MAX_SHORTCUT_LENGTH], *b;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) addr;

  GET_STRING_OR_DEFAULT("Key spec", val);

  if (!val || strcasecmp(val, "NONE") == 0) {
    shortcut.keycode = 0;
    shortcut.modifier = 0;
    if (ret)
      *ret = &shortcut;
    return True;
  }

  wstrlcpy(buf, val, MAX_SHORTCUT_LENGTH);

  b = (char *)buf;

  /* get modifiers */
  shortcut.modifier = 0;
  while ((k = strchr(b, '+')) != NULL) {
    int mod;

    *k = 0;
    mod = wXModifierFromKey(b);
    if (mod < 0) {
      WMLogWarning(_("%s: invalid key modifier \"%s\""), entry->key, b);
      return False;
    }
    shortcut.modifier |= mod;

    b = k + 1;
  }

  /* get key */
  ksym = XStringToKeysym(b);

  if (ksym == NoSymbol) {
    WMLogWarning(_("%s:invalid kbd shortcut specification \"%s\""), entry->key, val);
    return False;
  }

  shortcut.keycode = XKeysymToKeycode(dpy, ksym);
  if (shortcut.keycode == 0) {
    WMLogWarning(_("%s:invalid key in shortcut \"%s\""), entry->key, val);
    return False;
  }

  if (ret)
    *ret = &shortcut;

  return True;
}

static int getModMask(WScreen * scr, WDefaultEntry * entry, CFTypeRef value, void *addr, void **ret)
{
  static int mask;
  const char *str;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;

  GET_STRING_OR_DEFAULT("Modifier Key", str);

  if (!str)
    return False;

  mask = wXModifierFromKey(str);
  if (mask < 0) {
    WMLogWarning(_("%s: modifier key %s is not valid"), entry->key, str);
    mask = 0;
    return False;
  }

  if (addr)
    *(int *)addr = mask;

  if (ret)
    *ret = &mask;

  return True;
}

static int getAltModMask(WScreen * scr, WDefaultEntry * entry, CFTypeRef value, void *addr, void **ret)
{
  static int mask;
  const char *str;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;

  GET_STRING_OR_DEFAULT("Alternate Modifier Key", str);

  if (!str)
    return False;

  mask = wXModifierFromKey(str);
  if (mask < 0) {
    WMLogWarning(_("%s: modifier key %s is not valid"), entry->key, str);
    mask = 0;
    return False;
  }

  if (addr)
    *(int *)addr = mask;

  if (ret)
    *ret = &mask;

  return True;
}

# include <X11/cursorfont.h>
typedef struct {
  const char *name;
  int id;
} WCursorLookup;

#define CURSOR_ID_NONE	(XC_num_glyphs)

static const WCursorLookup cursor_table[] = {
                                             {"X_cursor", XC_X_cursor},
                                             {"arrow", XC_arrow},
                                             {"based_arrow_down", XC_based_arrow_down},
                                             {"based_arrow_up", XC_based_arrow_up},
                                             {"boat", XC_boat},
                                             {"bogosity", XC_bogosity},
                                             {"bottom_left_corner", XC_bottom_left_corner},
                                             {"bottom_right_corner", XC_bottom_right_corner},
                                             {"bottom_side", XC_bottom_side},
                                             {"bottom_tee", XC_bottom_tee},
                                             {"box_spiral", XC_box_spiral},
                                             {"center_ptr", XC_center_ptr},
                                             {"circle", XC_circle},
                                             {"clock", XC_clock},
                                             {"coffee_mug", XC_coffee_mug},
                                             {"cross", XC_cross},
                                             {"cross_reverse", XC_cross_reverse},
                                             {"crosshair", XC_crosshair},
                                             {"diamond_cross", XC_diamond_cross},
                                             {"dot", XC_dot},
                                             {"dotbox", XC_dotbox},
                                             {"double_arrow", XC_double_arrow},
                                             {"draft_large", XC_draft_large},
                                             {"draft_small", XC_draft_small},
                                             {"draped_box", XC_draped_box},
                                             {"exchange", XC_exchange},
                                             {"fleur", XC_fleur},
                                             {"gobbler", XC_gobbler},
                                             {"gumby", XC_gumby},
                                             {"hand1", XC_hand1},
                                             {"hand2", XC_hand2},
                                             {"heart", XC_heart},
                                             {"icon", XC_icon},
                                             {"iron_cross", XC_iron_cross},
                                             {"left_ptr", XC_left_ptr},
                                             {"left_side", XC_left_side},
                                             {"left_tee", XC_left_tee},
                                             {"leftbutton", XC_leftbutton},
                                             {"ll_angle", XC_ll_angle},
                                             {"lr_angle", XC_lr_angle},
                                             {"man", XC_man},
                                             {"middlebutton", XC_middlebutton},
                                             {"mouse", XC_mouse},
                                             {"pencil", XC_pencil},
                                             {"pirate", XC_pirate},
                                             {"plus", XC_plus},
                                             {"question_arrow", XC_question_arrow},
                                             {"right_ptr", XC_right_ptr},
                                             {"right_side", XC_right_side},
                                             {"right_tee", XC_right_tee},
                                             {"rightbutton", XC_rightbutton},
                                             {"rtl_logo", XC_rtl_logo},
                                             {"sailboat", XC_sailboat},
                                             {"sb_down_arrow", XC_sb_down_arrow},
                                             {"sb_h_double_arrow", XC_sb_h_double_arrow},
                                             {"sb_left_arrow", XC_sb_left_arrow},
                                             {"sb_right_arrow", XC_sb_right_arrow},
                                             {"sb_up_arrow", XC_sb_up_arrow},
                                             {"sb_v_double_arrow", XC_sb_v_double_arrow},
                                             {"shuttle", XC_shuttle},
                                             {"sizing", XC_sizing},
                                             {"spider", XC_spider},
                                             {"spraycan", XC_spraycan},
                                             {"star", XC_star},
                                             {"target", XC_target},
                                             {"tcross", XC_tcross},
                                             {"top_left_arrow", XC_top_left_arrow},
                                             {"top_left_corner", XC_top_left_corner},
                                             {"top_right_corner", XC_top_right_corner},
                                             {"top_side", XC_top_side},
                                             {"top_tee", XC_top_tee},
                                             {"trek", XC_trek},
                                             {"ul_angle", XC_ul_angle},
                                             {"umbrella", XC_umbrella},
                                             {"ur_angle", XC_ur_angle},
                                             {"watch", XC_watch},
                                             {"xterm", XC_xterm},
                                             {NULL, CURSOR_ID_NONE}
};

static void check_bitmap_status(int status, const char *filename, Pixmap bitmap)
{
  switch (status) {
  case BitmapOpenFailed:
    WMLogWarning(_("failed to open bitmap file \"%s\""), filename);
    break;
  case BitmapFileInvalid:
    WMLogWarning(_("\"%s\" is not a valid bitmap file"), filename);
    break;
  case BitmapNoMemory:
    WMLogWarning(_("out of memory reading bitmap file \"%s\""), filename);
    break;
  case BitmapSuccess:
    XFreePixmap(dpy, bitmap);
    break;
  }
}

/*
 * (none)
 * (builtin, <cursor_name>)
 * (bitmap, <cursor_bitmap>, <cursor_mask>)
 */
static int parse_cursor(WScreen * scr, CFTypeRef pl, Cursor * cursor)
{
  CFTypeRef elem;
  const char *val;
  int nelem;
  int status = 0;

  nelem = CFArrayGetCount(pl);
  if (nelem < 1) {
    return (status);
  }
  elem = CFArrayGetValueAtIndex(pl, 0);
  if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID())) {
    return (status);
  }
  val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

  if (strcasecmp(val, "none") == 0) {
    status = 1;
    *cursor = None;
  } else if (strcasecmp(val, "builtin") == 0) {
    int i;
    int cursor_id = CURSOR_ID_NONE;

    if (nelem != 2) {
      WMLogWarning(_("bad number of arguments in cursor specification"));
      return (status);
    }
    elem = CFArrayGetValueAtIndex(pl, 1);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID())) {
      return (status);
    }
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    for (i = 0; cursor_table[i].name != NULL; i++) {
      if (strcasecmp(val, cursor_table[i].name) == 0) {
        cursor_id = cursor_table[i].id;
        break;
      }
    }
    if (CURSOR_ID_NONE == cursor_id) {
      WMLogWarning(_("unknown builtin cursor name \"%s\""), val);
    } else {
      *cursor = XCreateFontCursor(dpy, cursor_id);
      status = 1;
    }
  } else if (strcasecmp(val, "bitmap") == 0) {
    char *bitmap_name;
    char *mask_name;
    int bitmap_status;
    int mask_status;
    Pixmap bitmap;
    Pixmap mask;
    unsigned int w, h;
    int x, y;
    XColor fg, bg;

    if (nelem != 3) {
      WMLogWarning(_("bad number of arguments in cursor specification"));
      return (status);
    }
    elem = CFArrayGetValueAtIndex(pl, 1);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID())) {
      return (status);
    }
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);
    bitmap_name = WMAbsolutePathForFile(wPreferences.image_paths, val);
    if (!bitmap_name) {
      WMLogWarning(_("could not find cursor bitmap file \"%s\""), val);
      return (status);
    }
    elem = CFArrayGetValueAtIndex(pl, 2);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID())) {
      return (status);
    }
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);
    mask_name = WMAbsolutePathForFile(wPreferences.image_paths, val);
    if (!mask_name) {
      wfree(bitmap_name);
      WMLogWarning(_("could not find cursor bitmap file \"%s\""), val);
      return (status);
    }
    mask_status = XReadBitmapFile(dpy, scr->w_win, mask_name, &w, &h, &mask, &x, &y);
    bitmap_status = XReadBitmapFile(dpy, scr->w_win, bitmap_name, &w, &h, &bitmap, &x, &y);
    if ((BitmapSuccess == bitmap_status) && (BitmapSuccess == mask_status)) {
      fg.pixel = scr->black_pixel;
      bg.pixel = scr->white_pixel;
      XQueryColor(dpy, scr->w_colormap, &fg);
      XQueryColor(dpy, scr->w_colormap, &bg);
      *cursor = XCreatePixmapCursor(dpy, bitmap, mask, &fg, &bg, x, y);
      status = 1;
    }
    check_bitmap_status(bitmap_status, bitmap_name, bitmap);
    check_bitmap_status(mask_status, mask_name, mask);
    wfree(bitmap_name);
    wfree(mask_name);
  } else if (strcasecmp(val, "library") == 0) {
    if (nelem != 2) {
      WMLogWarning(_("bad number of arguments in cursor specification"));
      return (status);
    }
    elem = CFArrayGetValueAtIndex(pl, 1);
    if (!elem || (CFGetTypeID(elem) != CFStringGetTypeID())) {
      return (status);
    }
    val = WMUserDefaultsGetCString(elem, kCFStringEncodingUTF8);

    *cursor = XcursorLibraryLoadCursor(dpy, val);
    status = 1;

    if (cursor == NULL) {
      WMLogWarning(_("unknown builtin cursor name \"%s\""), val);
    }
  }
  return (status);
}

static int getCursor(WScreen * scr, WDefaultEntry * entry, CFTypeRef value, void *addr, void **ret)
{
  static Cursor cursor;
  int status;
  int changed = 0;

 again:
  if (CFGetTypeID(value) != CFArrayGetTypeID()) {
    WMLogWarning(_("Wrong option format for key \"%s\". Should be %s."),
             entry->key, "cursor specification");
    if (!changed) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return (False);
  }
  status = parse_cursor(scr, value, &cursor);
  if (!status) {
    WMLogWarning(_("Error in cursor specification for key \"%s\""), entry->key);
    if (!changed) {
      value = entry->plvalue;
      changed = 1;
      WMLogWarning(_("using default \"%s\" instead"), entry->default_value);
      goto again;
    }
    return (False);
  }
  if (ret) {
    *ret = &cursor;
  }
  if (addr) {
    *(Cursor *) addr = cursor;
  }
  return (True);
}

#undef CURSOR_ID_NONE

/* ---------------- value setting functions --------------- */
static int setJustify(WScreen * scr, WDefaultEntry * entry, void *tdata, void *extra_data)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) entry;
  (void) tdata;
  (void) extra_data;

  return REFRESH_WINDOW_TITLE_COLOR;
}

static int setClearance(WScreen * scr, WDefaultEntry * entry, void *bar, void *foo)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) entry;
  (void) bar;
  (void) foo;

  return REFRESH_WINDOW_FONT | REFRESH_BUTTON_IMAGES | REFRESH_MENU_TITLE_FONT | REFRESH_MENU_FONT;
}

static int setIfDockPresent(WScreen * scr, WDefaultEntry * entry, void *tdata, void *extra_data)
{
  char *flag = tdata;
  long which = (long) extra_data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) entry;

  switch (which) {
  case WM_DOCK:
    wPreferences.flags.nodock = wPreferences.flags.nodock || *flag;
    // Drawers require the dock
    wPreferences.flags.nodrawer = wPreferences.flags.nodrawer || wPreferences.flags.nodock;
    break;
  case WM_CLIP:
    wPreferences.flags.noclip = wPreferences.flags.noclip || *flag;
    break;
  case WM_DRAWER:
    wPreferences.flags.nodrawer = wPreferences.flags.nodrawer || *flag;
    break;
  default:
    break;
  }
  return 0;
}

static int setClipMergedInDock(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  char *flag = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) entry;
  (void) foo;

  wPreferences.flags.clip_merged_in_dock = *flag;
  wPreferences.flags.noclip = wPreferences.flags.noclip || *flag;
  return 0;
}

static int setWrapAppiconsInDock(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  char *flag = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) entry;
  (void) foo;

  wPreferences.flags.wrap_appicons_in_dock = *flag;
  return 0;
}

static int setStickyIcons(WScreen * scr, WDefaultEntry * entry, void *bar, void *foo)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) bar;
  (void) foo;

  if (scr->desktops) {
    wDesktopForceChange(scr, scr->current_desktop, NULL);
    if (wPreferences.auto_arrange_icons) {
      wArrangeIcons(scr, False);
    }
  }
  return 0;
}

static int setIconTile(WScreen * scr, WDefaultEntry * entry, void *tdata, void *foo)
{
  Pixmap pixmap;
  RImage *img;
  WTexture ** texture = tdata;
  int reset = 0;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) foo;

  img = wTextureRenderImage(*texture, wPreferences.icon_size,
                            wPreferences.icon_size, ((*texture)->any.type & WREL_BORDER_MASK)
                            ? WREL_ICON : WREL_FLAT);
  if (!img) {
    WMLogWarning(_("could not render texture for icon background"));
    if (!entry->addr)
      wTextureDestroy(scr, *texture);
    return 0;
  }
  RConvertImage(scr->rcontext, img, &pixmap);

  if (scr->icon_tile) {
    reset = 1;
    RReleaseImage(scr->icon_tile);
    XFreePixmap(dpy, scr->icon_tile_pixmap);
  }

  scr->icon_tile = img;

  /* put the icon in the noticeboard hint */
  PropSetIconTileHint(scr, img);

  if (!wPreferences.flags.noclip || wPreferences.flags.clip_merged_in_dock) {
    if (scr->clip_tile) {
      RReleaseImage(scr->clip_tile);
    }
    scr->clip_tile = wClipMakeTile(img);
  }

  if (!wPreferences.flags.nodrawer) {
    if (scr->drawer_tile) {
      RReleaseImage(scr->drawer_tile);
    }
    scr->drawer_tile = wDrawerMakeTile(scr, img);
  }

  scr->icon_tile_pixmap = pixmap;

  if (scr->def_icon_rimage) {
    RReleaseImage(scr->def_icon_rimage);
    scr->def_icon_rimage = NULL;
  }

  if (scr->icon_back_texture)
    wTextureDestroy(scr, (WTexture *) scr->icon_back_texture);

  scr->icon_back_texture = wTextureMakeSolid(scr, &((*texture)->any.color));

  /* Free the texture as nobody else will use it, nor refer to it.  */
  if (!entry->addr)
    wTextureDestroy(scr, *texture);

  return (reset ? REFRESH_ICON_TILE : 0);
}

static int setMiniwindowTile(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  Pixmap	pixmap;
  RImage	*img;
  WTexture	**texture = tdata;
  int		reset = 0;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) foo;

  img = wTextureRenderImage(*texture, wPreferences.icon_size,
                            wPreferences.icon_size,
                            ((*texture)->any.type & WREL_BORDER_MASK)
                            ? WREL_ICON : WREL_FLAT);
  if (!img)
    {
      WMLogWarning(_("could not render texture for miniwindow background"));
      if (!entry->addr)
        wTextureDestroy(scr, *texture);
      return 0;
    }
  RConvertImage(scr->rcontext, img, &pixmap);

  if (scr->miniwindow_tile)
    {
      reset = 1;
      RReleaseImage(scr->miniwindow_tile);
    }

  scr->miniwindow_tile = img;

  /* put the icon in the noticeboard hint */
  /* PropSetIconTileHint(scr, img); */

  /* scr->icon_tile_pixmap = pixmap; */

  /* icon back color for shadowing */
  /*  if (scr->icon_back_texture)
      wTextureDestroy(scr, (WTexture *) scr->icon_back_texture);
      scr->icon_back_texture = wTextureMakeSolid(scr, &((*texture)->any.color));*/

  /* Free the texture as nobody else will use it, nor refer to it.  */
  if (!entry->addr)
    wTextureDestroy(scr, *texture);

  return (reset ? REFRESH_ICON_TILE : 0);
}

static int setWinTitleFont(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WMFont *font = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->title_font) {
    WMReleaseFont(scr->title_font);
  }
  scr->title_font = font;

  return REFRESH_WINDOW_FONT | REFRESH_BUTTON_IMAGES;
}

static int setMenuTitleFont(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WMFont *font = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->menu_title_font) {
    WMReleaseFont(scr->menu_title_font);
  }

  scr->menu_title_font = font;

  return REFRESH_MENU_TITLE_FONT;
}

static int setMenuTextFont(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WMFont *font = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->menu_item_font) {
    WMReleaseFont(scr->menu_item_font);
  }
  scr->menu_item_font = font;

  return REFRESH_MENU_FONT;
}

static int setIconTitleFont(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WMFont *font = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->icon_title_font) {
    WMReleaseFont(scr->icon_title_font);
  }

  scr->icon_title_font = font;

  return REFRESH_ICON_FONT;
}

static int setClipTitleFont(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WMFont *font = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->clip_title_font) {
    WMReleaseFont(scr->clip_title_font);
  }

  scr->clip_title_font = font;

  return REFRESH_ICON_FONT;
}

static int setLargeDisplayFont(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WMFont *font = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) entry;
  (void) foo;

  if (scr->workspace_name_font)
    WMReleaseFont(scr->workspace_name_font);

  scr->workspace_name_font = font;

  return 0;
}

static int setAntialiasedText(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  char *flag = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  scr->wmscreen->antialiasedText = *flag;

  return 0;
}

static int setHightlight(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->select_color)
    WMReleaseColor(scr->select_color);

  scr->select_color = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  wFreeColor(scr, color->pixel);

  return REFRESH_MENU_COLOR;
}

static int setHightlightText(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->select_text_color)
    WMReleaseColor(scr->select_text_color);

  scr->select_text_color = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  wFreeColor(scr, color->pixel);

  return REFRESH_MENU_COLOR;
}

static int setClipTitleColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *extra_data)
{
  XColor *color = tdata;
  long widx = (long) extra_data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;

  if (scr->clip_title_color[widx])
    WMReleaseColor(scr->clip_title_color[widx]);

  scr->clip_title_color[widx] = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);
  wFreeColor(scr, color->pixel);

  return REFRESH_ICON_TITLE_COLOR;
}

static int setWTitleColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *extra_data)
{
  XColor *color = tdata;
  long widx = (long) extra_data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;

  if (scr->window_title_color[widx])
    WMReleaseColor(scr->window_title_color[widx]);

  scr->window_title_color[widx] =
    WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  wFreeColor(scr, color->pixel);

  return REFRESH_WINDOW_TITLE_COLOR;
}

static int setMenuTitleColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *extra_data)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) extra_data;

  if (scr->menu_title_color[0])
    WMReleaseColor(scr->menu_title_color[0]);

  scr->menu_title_color[0] = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  wFreeColor(scr, color->pixel);

  return REFRESH_MENU_TITLE_COLOR;
}

static int setMenuTextColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->mtext_color)
    WMReleaseColor(scr->mtext_color);

  scr->mtext_color = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  if (WMColorPixel(scr->dtext_color) == WMColorPixel(scr->mtext_color)) {
    WMSetColorAlpha(scr->dtext_color, 0x7fff);
  } else {
    WMSetColorAlpha(scr->dtext_color, 0xffff);
  }

  wFreeColor(scr, color->pixel);

  return REFRESH_MENU_COLOR;
}

static int setMenuDisabledColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->dtext_color)
    WMReleaseColor(scr->dtext_color);

  scr->dtext_color = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  if (WMColorPixel(scr->dtext_color) == WMColorPixel(scr->mtext_color)) {
    WMSetColorAlpha(scr->dtext_color, 0x7fff);
  } else {
    WMSetColorAlpha(scr->dtext_color, 0xffff);
  }

  wFreeColor(scr, color->pixel);

  return REFRESH_MENU_COLOR;
}

static int setIconTitleColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->icon_title_color)
    WMReleaseColor(scr->icon_title_color);
  scr->icon_title_color = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  wFreeColor(scr, color->pixel);

  return REFRESH_ICON_TITLE_COLOR;
}

static int setIconTitleBack(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->icon_title_texture) {
    wTextureDestroy(scr, (WTexture *) scr->icon_title_texture);
  }
  scr->icon_title_texture = wTextureMakeSolid(scr, color);

  return REFRESH_ICON_TITLE_BACK;
}

static int setFrameBorderWidth(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  int *value = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  scr->frame_border_width = *value;

  return REFRESH_FRAME_BORDER;
}

static int setFrameBorderColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->frame_border_color)
    WMReleaseColor(scr->frame_border_color);
  scr->frame_border_color = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  wFreeColor(scr, color->pixel);

  return REFRESH_FRAME_BORDER;
}

static int setFrameFocusedBorderColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->frame_focused_border_color)
    WMReleaseColor(scr->frame_focused_border_color);
  scr->frame_focused_border_color = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  wFreeColor(scr, color->pixel);

  return REFRESH_FRAME_BORDER;
}

static int setFrameSelectedBorderColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  XColor *color = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->frame_selected_border_color)
    WMReleaseColor(scr->frame_selected_border_color);
  scr->frame_selected_border_color = WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue, True);

  wFreeColor(scr, color->pixel);

  return REFRESH_FRAME_BORDER;
}

static int setWidgetColor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WTexture **texture = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->widget_texture) {
    wTextureDestroy(scr, (WTexture *) scr->widget_texture);
  }
  scr->widget_texture = *(WTexSolid **) texture;

  return 0;
}

static int setFTitleBack(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WTexture **texture = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->window_title_texture[WS_FOCUSED]) {
    wTextureDestroy(scr, scr->window_title_texture[WS_FOCUSED]);
  }
  scr->window_title_texture[WS_FOCUSED] = *texture;

  return REFRESH_WINDOW_TEXTURES;
}

static int setPTitleBack(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WTexture **texture = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->window_title_texture[WS_PFOCUSED]) {
    wTextureDestroy(scr, scr->window_title_texture[WS_PFOCUSED]);
  }
  scr->window_title_texture[WS_PFOCUSED] = *texture;

  return REFRESH_WINDOW_TEXTURES;
}

static int setUTitleBack(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WTexture **texture = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->window_title_texture[WS_UNFOCUSED]) {
    wTextureDestroy(scr, scr->window_title_texture[WS_UNFOCUSED]);
  }
  scr->window_title_texture[WS_UNFOCUSED] = *texture;

  return REFRESH_WINDOW_TEXTURES;
}

static int setResizebarBack(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WTexture **texture = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->resizebar_texture[0]) {
    wTextureDestroy(scr, scr->resizebar_texture[0]);
  }
  scr->resizebar_texture[0] = *texture;

  return REFRESH_WINDOW_TEXTURES;
}

static int setMenuTitleBack(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WTexture **texture = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->menu_title_texture[0]) {
    wTextureDestroy(scr, scr->menu_title_texture[0]);
  }
  scr->menu_title_texture[0] = *texture;

  return REFRESH_MENU_TITLE_TEXTURE;
}

static int setMenuTextBack(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WTexture **texture = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (scr->menu_item_texture) {
    wTextureDestroy(scr, scr->menu_item_texture);
    wTextureDestroy(scr, (WTexture *) scr->menu_item_auxtexture);
  }
  scr->menu_item_texture = *texture;

  scr->menu_item_auxtexture = wTextureMakeSolid(scr, &scr->menu_item_texture->any.color);

  return REFRESH_MENU_TEXTURE;
}

static int setKeyGrab(WScreen *scr, WDefaultEntry *entry, void *tdata, void *extra_data)
{
  WShortKey *shortcut = tdata;
  WWindow *wwin;
  long widx = (long) extra_data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;

  wKeyBindings[widx] = *shortcut;

  wwin = scr->focused_window;

  while (wwin != NULL) {
    XUngrabKey(dpy, AnyKey, AnyModifier, wwin->frame->core->window);

    if (!WFLAGP(wwin, no_bind_keys)) {
      wWindowSetKeyGrabs(wwin);
    }
    wwin = wwin->prev;
  }

  return 0;
}

static int setIconPosition(WScreen *scr, WDefaultEntry *entry, void *bar, void *foo)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) bar;
  (void) foo;

  wScreenUpdateUsableArea(scr);
  if (wPreferences.auto_arrange_icons) {
    wArrangeIcons(scr, True);
  }

  return 0;
}

static int updateUsableArea(WScreen *scr, WDefaultEntry *entry, void *bar, void *foo)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) bar;
  (void) foo;

  wScreenUpdateUsableArea(scr);

  return 0;
}

static int setWorkspaceMapBackground(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  WTexture **texture = tdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;
  (void) foo;

  if (wPreferences.wsmbackTexture)
    wTextureDestroy(scr, wPreferences.wsmbackTexture);

  wPreferences.wsmbackTexture = *texture;

  return REFRESH_WINDOW_TEXTURES;
}

static int setMenuStyle(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) scr;
  (void) entry;
  (void) tdata;
  (void) foo;

  return REFRESH_MENU_TEXTURE;
}

static RImage *chopOffImage(RImage *image, int x, int y, int w, int h)
{
  RImage *img = RCreateImage(w, h, image->format == RRGBAFormat);

  RCopyArea(img, image, x, y, w, h, 0, 0);

  return img;
}

static int setSwPOptions(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  CFTypeRef array = tdata;
  CFStringRef value;
  char *path;
  RImage *bgimage;
  int cwidth, cheight;
  struct WPreferences *prefs = foo;

  if (!array || (CFGetTypeID(array) != CFArrayGetTypeID()) || CFArrayGetCount(array) == 0) {
    if (prefs->swtileImage)
      RReleaseImage(prefs->swtileImage);
    prefs->swtileImage = NULL;

    CFRelease(array);
    return 0;
  }

  switch (CFArrayGetCount(array)) {
  case 4:
    value = CFArrayGetValueAtIndex(array, 1);
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      WMLogWarning(_("Invalid arguments for option \"%s\""), entry->key);
      break;
    } else {
      path = WMAbsolutePathForFile(wPreferences.image_paths,
                                  WMUserDefaultsGetCString(value, kCFStringEncodingUTF8));
    }

    if (!path) {
      WMLogWarning(_("Could not find image \"%s\" for option \"%s\""),
               WMUserDefaultsGetCString(value, kCFStringEncodingUTF8), entry->key);
    } else {
      bgimage = RLoadImage(scr->rcontext, path, 0);
      if (!bgimage) {
        WMLogWarning(_("Could not load image \"%s\" for option \"%s\""), path, entry->key);
        wfree(path);
      } else {
        wfree(path);

        cwidth = atoi(WMUserDefaultsGetCString(CFArrayGetValueAtIndex(array, 2),
                                            kCFStringEncodingUTF8));
        cheight = atoi(WMUserDefaultsGetCString(CFArrayGetValueAtIndex(array, 3),
                                             kCFStringEncodingUTF8));

        if (cwidth <= 0 || cheight <= 0 ||
            cwidth >= bgimage->width - 2 || cheight >= bgimage->height - 2)
          WMLogWarning(_("Invalid split sizes for switch panel back image."));
        else {
          int i;
          int swidth, theight;
          for (i = 0; i < 9; i++) {
            if (prefs->swbackImage[i])
              RReleaseImage(prefs->swbackImage[i]);
            prefs->swbackImage[i] = NULL;
          }
          swidth = (bgimage->width - cwidth) / 2;
          theight = (bgimage->height - cheight) / 2;

          prefs->swbackImage[0] = chopOffImage(bgimage, 0, 0, swidth, theight);
          prefs->swbackImage[1] = chopOffImage(bgimage, swidth, 0, cwidth, theight);
          prefs->swbackImage[2] = chopOffImage(bgimage, swidth + cwidth, 0,
                                               swidth, theight);

          prefs->swbackImage[3] = chopOffImage(bgimage, 0, theight, swidth, cheight);
          prefs->swbackImage[4] = chopOffImage(bgimage, swidth, theight,
                                               cwidth, cheight);
          prefs->swbackImage[5] = chopOffImage(bgimage, swidth + cwidth, theight,
                                               swidth, cheight);

          prefs->swbackImage[6] = chopOffImage(bgimage, 0, theight + cheight,
                                               swidth, theight);
          prefs->swbackImage[7] = chopOffImage(bgimage, swidth, theight + cheight,
                                               cwidth, theight);
          prefs->swbackImage[8] =
            chopOffImage(bgimage, swidth + cwidth, theight + cheight, swidth,
                         theight);

          // check if anything failed
          for (i = 0; i < 9; i++) {
            if (!prefs->swbackImage[i]) {
              for (; i >= 0; --i) {
                RReleaseImage(prefs->swbackImage[i]);
                prefs->swbackImage[i] = NULL;
              }
              break;
            }
          }
        }
        RReleaseImage(bgimage);
      }
    }

  case 1:
    value = CFArrayGetValueAtIndex(array, 0);
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
      WMLogWarning(_("Invalid arguments for option \"%s\""), entry->key);
      break;
    } else {
      path = WMAbsolutePathForFile(wPreferences.image_paths,
                       WMUserDefaultsGetCString(value, kCFStringEncodingUTF8));
    }

    if (!path) {
      WMLogWarning(_("Could not find image \"%s\" for option \"%s\""),
               WMUserDefaultsGetCString(value, kCFStringEncodingUTF8), entry->key);
    } else {
      if (prefs->swtileImage)
        RReleaseImage(prefs->swtileImage);

      prefs->swtileImage = RLoadImage(scr->rcontext, path, 0);
      if (!prefs->swtileImage) {
        WMLogWarning(_("Could not load image \"%s\" for option \"%s\""), path, entry->key);
      }
      wfree(path);
    }
    break;

  default:
    WMLogWarning(_("Invalid number of arguments for option \"%s\""), entry->key);
    break;
  }

  CFRelease(array);

  return 0;
}

static int setModifierKeyLabels(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  CFTypeRef array = tdata;
  CFStringRef value;
  int i;
  struct WPreferences *prefs = foo;

  if ((CFGetTypeID(array) != CFArrayGetTypeID()) || CFArrayGetCount(array) != 7) {
    WMLogWarning(_("Value for option \"%s\" must be an array of 7 strings"), entry->key);
    CFRelease(array);
    return 0;
  }

  /* DestroyWindowMenu(scr); */

  for (i = 0; i < 7; i++) {
    if (prefs->modifier_labels[i])
      wfree(prefs->modifier_labels[i]);

    value = CFArrayGetValueAtIndex(array, i);
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
      prefs->modifier_labels[i] = wstrdup(WMUserDefaultsGetCString(value, kCFStringEncodingUTF8));
    } else {
      WMLogWarning(_("Invalid argument for option \"%s\" item %d"), entry->key, i);
      prefs->modifier_labels[i] = NULL;
    }
  }

  CFRelease(array);

  return 0;
}

// FIXME: this callback was left for reference only - it aimed to set WINGs configuration
// field which is not used anymore.
static int setDoubleClick(WScreen *scr, WDefaultEntry *entry, void *tdata, void *foo)
{
  int *value = tdata;

  if (*value <= 0)
    *(int *)foo = 1;

  /* this function was in removed configuration.c */
  /* W_setconf_doubleClickDelay(*value); */

  return 0;
}

static int setCursor(WScreen *scr, WDefaultEntry *entry, void *tdata, void *extra_data)
{
  Cursor *cursor = tdata;
  long widx = (long) extra_data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) entry;

  if (wPreferences.cursor[widx] != None) {
    XFreeCursor(dpy, wPreferences.cursor[widx]);
  }

  wPreferences.cursor[widx] = *cursor;

  if (widx == WCUR_ROOT && *cursor != None) {
    XDefineCursor(dpy, scr->root_win, *cursor);
  }

  return 0;
}
