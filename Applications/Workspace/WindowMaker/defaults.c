/* defaults.c - manage configuration through defaults db
 *
 *  Window Maker window manager
 *
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#include "wconfig.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>

#ifdef HAVE_DLFCN_H
# include <dlfcn.h>
#endif



#ifndef PATH_MAX
#define PATH_MAX DEFAULT_PATH_MAX
#endif

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

#include <wraster/wraster.h>

#include "WindowMaker.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "texture.h"
#include "screen.h"
#include "resources.h"
#include "defaults.h"
#include "keybind.h"
#include "xmodifier.h"
#include "icon.h"
#include "funcs.h"
#include "actions.h"
#include "dock.h"
#include "workspace.h"
#include "properties.h"



/***** Global *****/

extern WDDomain *WDWindowMaker;
extern WDDomain *WDWindowAttributes;
extern WDDomain *WDRootMenu;

extern int wScreenCount;

extern Atom _XA_WINDOWMAKER_ICON_SIZE;
extern Atom _XA_WINDOWMAKER_ICON_TILE;

/*
 extern WMPropList *wDomainName;
 extern WMPropList *wAttributeDomainName;
 */
extern WPreferences wPreferences;

extern WShortKey wKeyBindings[WKBD_LAST];

typedef struct {
    char *key;
    char *default_value;
    void *extra_data;
    void *addr;
    int (*convert)();
    int (*update)();
    WMPropList *plkey;
    WMPropList *plvalue;		       /* default value */
} WDefaultEntry;


/* used to map strings to integers */
typedef struct {
    char *string;
    short value;
    char is_alias;
} WOptionEnumeration;


/* type converters */
static int getBool();
static int getInt();
static int getCoord();
#if 0
/* this is not used yet */
static int getString();
#endif
static int getPathList();
static int getEnum();
static int getTexture();
static int getWSBackground();
static int getWSSpecificBackground();
static int getFont();
static int getColor();
static int getKeybind();
static int getModMask();
#ifdef NEWSTUFF
static int getRImage();
#endif
static int getPropList();

/* value setting functions */
static int setJustify();
static int setClearance();
static int setIfDockPresent();
static int setStickyIcons();
/*
 static int setPositive();
 */
static int setWidgetColor();
static int setIconTile();
static int setWinTitleFont();
static int setMenuTitleFont();
static int setMenuTextFont();
static int setIconTitleFont();
static int setIconTitleColor();
static int setIconTitleBack();
static int setLargeDisplayFont();
static int setWTitleColor();
static int setFTitleBack();
static int setPTitleBack();
static int setUTitleBack();
static int setResizebarBack();
static int setWorkspaceBack();
static int setWorkspaceSpecificBack();
#ifdef VIRTUAL_DESKTOP
static int setVirtualDeskEnable();
#endif
static int setMenuTitleColor();
static int setMenuTextColor();
static int setMenuDisabledColor();
static int setMenuTitleBack();
static int setMenuTextBack();
static int setHightlight();
static int setHightlightText();
static int setKeyGrab();
static int setDoubleClick();
static int setIconPosition();

static int setClipTitleFont();
static int setClipTitleColor();

static int setMenuStyle();
static int setSwPOptions();
static int updateUsableArea();


extern Cursor wCursor[WCUR_LAST];
static int getCursor();
static int setCursor();


/*
 * Tables to convert strings to enumeration values.
 * Values stored are char
 */


/* WARNING: sum of length of all value strings must not exceed
 * this value */
#define TOTAL_VALUES_LENGTH	80




#define REFRESH_WINDOW_TEXTURES	(1<<0)
#define REFRESH_MENU_TEXTURE	(1<<1)
#define REFRESH_MENU_FONT	(1<<2)
#define REFRESH_MENU_COLOR	(1<<3)
#define REFRESH_MENU_TITLE_TEXTURE	(1<<4)
#define REFRESH_MENU_TITLE_FONT	(1<<5)
#define REFRESH_MENU_TITLE_COLOR	(1<<6)
#define REFRESH_WINDOW_TITLE_COLOR (1<<7)
#define REFRESH_WINDOW_FONT	(1<<8)
#define REFRESH_ICON_TILE	(1<<9)
#define REFRESH_ICON_FONT	(1<<10)
#define REFRESH_WORKSPACE_BACK	(1<<11)

#define REFRESH_BUTTON_IMAGES   (1<<12)

#define REFRESH_ICON_TITLE_COLOR (1<<13)
#define REFRESH_ICON_TITLE_BACK (1<<14)



static WOptionEnumeration seFocusModes[] = {
    {"Manual", WKF_CLICK, 0}, {"ClickToFocus", WKF_CLICK, 1},
    {"Sloppy", WKF_SLOPPY, 0}, {"SemiAuto", WKF_SLOPPY, 1}, {"Auto", WKF_SLOPPY, 1},
    {NULL, 0, 0}
};

static WOptionEnumeration seColormapModes[] = {
    {"Manual", WCM_CLICK, 0}, {"ClickToFocus", WCM_CLICK, 1},
    {"Auto", WCM_POINTER, 0}, {"FocusFollowMouse", WCM_POINTER, 1},
    {NULL, 0, 0}
};

static WOptionEnumeration sePlacements[] = {
    {"Auto", WPM_AUTO, 0},
    {"Smart", WPM_SMART, 0},
    {"Cascade", WPM_CASCADE, 0},
    {"Random", WPM_RANDOM, 0},
    {"Manual", WPM_MANUAL, 0},
    {NULL, 0, 0}
};

static WOptionEnumeration seGeomDisplays[] = {
    {"None", WDIS_NONE, 0},
    {"Center", WDIS_CENTER, 0},
    {"Corner", WDIS_TOPLEFT, 0},
    {"Floating", WDIS_FRAME_CENTER, 0},
    {"Line", WDIS_NEW, 0},
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
    {NULL, 0, 0}
};

static WOptionEnumeration seMouseWheelActions[] = {
    {"None", WA_NONE, 0},
    {"SwitchWorkspaces", WA_SWITCH_WORKSPACES, 0},
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
    {"blv", IY_BOTTOM|IY_LEFT|IY_VERT, 0},
    {"blh", IY_BOTTOM|IY_LEFT|IY_HORIZ, 0},
    {"brv", IY_BOTTOM|IY_RIGHT|IY_VERT, 0},
    {"brh", IY_BOTTOM|IY_RIGHT|IY_HORIZ, 0},
    {"tlv", IY_TOP|IY_LEFT|IY_VERT, 0},
    {"tlh", IY_TOP|IY_LEFT|IY_HORIZ, 0},
    {"trv", IY_TOP|IY_RIGHT|IY_VERT, 0},
    {"trh", IY_TOP|IY_RIGHT|IY_HORIZ, 0},
    {NULL, 0, 0}
};

static WOptionEnumeration seMenuStyles[] = {
    {"normal", MS_NORMAL, 0},
    {"singletexture", MS_SINGLE_TEXTURE, 0},
    {"flat", MS_FLAT, 0},
    {NULL, 0, 0}
};


static WOptionEnumeration seDisplayPositions[] = {
    {"none",  		WD_NONE,	0},
    {"center", 		WD_CENTER,	0},
    {"top",		WD_TOP,		0},
    {"bottom",		WD_BOTTOM,	0},
    {"topleft",		WD_TOPLEFT,	0},
    {"topright",	WD_TOPRIGHT, 	0},
    {"bottomleft",	WD_BOTTOMLEFT,	0},
    {"bottomright",	WD_BOTTOMRIGHT,	0},
    {NULL,		0,		0}
};

static WOptionEnumeration seWorkspaceBorder[] = {
    {"None",  		WB_NONE,	0},
    {"LeftRight",      	WB_LEFTRIGHT,	0},
    {"TopBottom",      	WB_TOPBOTTOM,  	0},
    {"AllDirections",  	WB_ALLDIRS,	0},
    {NULL,		0,		0}
};


/*
 * ALL entries in the tables bellow, NEED to have a default value
 * defined, and this value needs to be correct.
 */

/* these options will only affect the window manager on startup
 *
 * static defaults can't access the screen data, because it is
 * created after these defaults are read
 */
WDefaultEntry staticOptionList[] = {

    {"ColormapSize",	"4",			NULL,
    &wPreferences.cmap_size,	getInt,		NULL
    },
    {"DisableDithering",	"NO",			NULL,
    &wPreferences.no_dithering,	getBool,	NULL
    },
    /* static by laziness */
    {"IconSize",	"64",			NULL,
    &wPreferences.icon_size,	getInt,		NULL
    },
    {"ModifierKey",	"Mod1",			NULL,
    &wPreferences.modifier_mask,	getModMask,	NULL
    },
    {"DisableWSMouseActions", "NO",		NULL,
    &wPreferences.disable_root_mouse, getBool,	NULL
    },
    {"FocusMode",	"manual",		seFocusModes,
    &wPreferences.focus_mode,	getEnum,	NULL
    }, /* have a problem when switching from manual to sloppy without restart */
    {"NewStyle",	"NO",			NULL,
    &wPreferences.new_style, 	getBool, 	NULL
    },
    {"DisableDock",	"NO",		(void*) WM_DOCK,
    NULL, 	getBool,        setIfDockPresent
    },
    {"DisableClip",	"NO",		(void*) WM_CLIP,
    NULL, 	getBool,        setIfDockPresent
    },
    {"DisableMiniwindows", "NO",		NULL,
    &wPreferences.disable_miniwindows, getBool,	NULL
    }
};



WDefaultEntry optionList[] = {
    /* dynamic options */
    {"IconPosition",	"blh",			seIconPositions,
    &wPreferences.icon_yard,	getEnum,	setIconPosition
    },
    {"IconificationStyle", "Zoom",             seIconificationStyles,
    &wPreferences.iconification_style,    getEnum, NULL
    },
    {"MouseLeftButtonAction", "SelectWindows",	seMouseButtonActions,
    &wPreferences.mouse_button1, 	getEnum,	NULL
    },
    {"MouseMiddleButtonAction", "OpenWindowListMenu",	seMouseButtonActions,
    &wPreferences.mouse_button2, getEnum,	NULL
    },
    {"MouseRightButtonAction", "OpenApplicationsMenu",	seMouseButtonActions,
    &wPreferences.mouse_button3,	getEnum,	NULL
    },
    {"MouseWheelAction", "None",	seMouseWheelActions,
    &wPreferences.mouse_wheel,	getEnum,	NULL
    },
    {"PixmapPath",	DEF_PIXMAP_PATHS,	NULL,
    &wPreferences.pixmap_path,	getPathList,	NULL
    },
    {"IconPath",	DEF_ICON_PATHS,		NULL,
    &wPreferences.icon_path,	getPathList,	NULL
    },
    {"ColormapMode",	"auto",			seColormapModes,
    &wPreferences.colormap_mode,	getEnum,	NULL
    },
    {"AutoFocus", 	"NO",			NULL,
    &wPreferences.auto_focus,	getBool,	NULL
    },
    {"RaiseDelay",	"0",			NULL,
    &wPreferences.raise_delay,	getInt,		NULL
    },
    {"CirculateRaise",	"NO",			NULL,
    &wPreferences.circ_raise, 	getBool, 	NULL
    },
    {"Superfluous",	"NO",			NULL,
    &wPreferences.superfluous, 	getBool, 	NULL
    },
    {"AdvanceToNewWorkspace", "NO",		NULL,
    &wPreferences.ws_advance,      getBool,     NULL
    },
    {"CycleWorkspaces", "NO",			NULL,
    &wPreferences.ws_cycle,        getBool,	NULL
    },
    {"WorkspaceNameDisplayPosition", "center",	seDisplayPositions,
    &wPreferences.workspace_name_display_position, getEnum, NULL
    },
    {"WorkspaceBorder", "None",			seWorkspaceBorder,
    &wPreferences.workspace_border_position, getEnum, updateUsableArea
    },
    {"WorkspaceBorderSize", "0",       		 NULL,
    &wPreferences.workspace_border_size, getInt, updateUsableArea
    },
#ifdef VIRTUAL_DESKTOP
    {"EnableVirtualDesktop", "NO",              NULL,
    &wPreferences.vdesk_enable, getBool,        setVirtualDeskEnable
    },
    {"VirtualEdgeExtendSpace", "0",             NULL,
    &wPreferences.vedge_bordersize, getInt,     NULL
    },
    {"VirtualEdgeHorizonScrollSpeed", "30",     NULL,
    &wPreferences.vedge_hscrollspeed, getInt,   NULL
    },
    {"VirtualEdgeVerticalScrollSpeed", "30",    NULL,
    &wPreferences.vedge_vscrollspeed, getInt,   NULL
    },
    {"VirtualEdgeResistance", "30",             NULL,
    &wPreferences.vedge_resistance, getInt,     NULL
    },
    {"VirtualEdgeAttraction", "30",             NULL,
    &wPreferences.vedge_attraction, getInt,     NULL
    },
    {"VirtualEdgeLeftKey", "None",		    (void*)WKBD_VDESK_LEFT,
    NULL,				getKeybind,	setKeyGrab
    },
    {"VirtualEdgeRightKey", "None",		    (void*)WKBD_VDESK_RIGHT,
    NULL,				getKeybind,	setKeyGrab
    },
    {"VirtualEdgeUpKey", "None",		    (void*)WKBD_VDESK_UP,
    NULL,				getKeybind,	setKeyGrab
    },
    {"VirtualEdgeDownKey", "None",		    (void*)WKBD_VDESK_DOWN,
    NULL,				getKeybind,	setKeyGrab
    },
#endif
    {"StickyIcons", "NO",			NULL,
    &wPreferences.sticky_icons, getBool, setStickyIcons
    },
    {"SaveSessionOnExit", "NO",			NULL,
    &wPreferences.save_session_on_exit, getBool,	NULL
    },
    {"WrapMenus", "NO",				NULL,
    &wPreferences.wrap_menus,	getBool,	NULL
    },
    {"ScrollableMenus",	"NO",			NULL,
    &wPreferences.scrollable_menus, getBool,	NULL
    },
    {"MenuScrollSpeed",	"medium",    		seSpeeds,
    &wPreferences.menu_scroll_speed, getEnum,    	NULL
    },
    {"IconSlideSpeed",	"medium",		seSpeeds,
    &wPreferences.icon_slide_speed, getEnum,     	NULL
    },
    {"ShadeSpeed",	"medium",    		seSpeeds,
    &wPreferences.shade_speed,	 getEnum,	NULL
    },
    {"DoubleClickTime",	"250",   (void*) &wPreferences.dblclick_time,
    &wPreferences.dblclick_time, getInt,        setDoubleClick,
    },
    {"AlignSubmenus",	"NO",			NULL,
    &wPreferences.align_menus,	getBool,	NULL
    },
    {"OpenTransientOnOwnerWorkspace",	"NO",	NULL,
    &wPreferences.open_transients_with_parent, getBool,	NULL
    },
    {"WindowPlacement",	"auto",		sePlacements,
    &wPreferences.window_placement, getEnum,	NULL
    },
    {"IgnoreFocusClick","NO",			NULL,
    &wPreferences.ignore_focus_click, getBool,	NULL
    },
    {"UseSaveUnders",	"NO",			NULL,
    &wPreferences.use_saveunders,	getBool,	NULL
    },
    {"OpaqueMove",	"NO",			NULL,
    &wPreferences.opaque_move,	getBool,	NULL
    },
    {"DisableSound",	"NO",			NULL,
    &wPreferences.no_sound,	getBool,	NULL
    },
    {"DisableAnimations",	"NO",			NULL,
    &wPreferences.no_animations,	getBool,	NULL
    },
    {"DontLinkWorkspaces","NO",			NULL,
    &wPreferences.no_autowrap,	getBool,	NULL
    },
    {"AutoArrangeIcons", "NO",			NULL,
    &wPreferences.auto_arrange_icons, getBool,	NULL
    },
    {"NoWindowOverDock", "NO",			NULL,
    &wPreferences.no_window_over_dock, getBool,   updateUsableArea
    },
    {"NoWindowOverIcons", "NO",			NULL,
    &wPreferences.no_window_over_icons, getBool,  updateUsableArea
    },
    {"WindowPlaceOrigin", "(0, 0)",		NULL,
    &wPreferences.window_place_origin, getCoord,  NULL
    },
    {"ResizeDisplay",	"corner",	       	seGeomDisplays,
    &wPreferences.size_display,	getEnum,	NULL
    },
    {"MoveDisplay",	"corner",      		seGeomDisplays,
    &wPreferences.move_display,	getEnum,	NULL
    },
    {"DontConfirmKill",	"NO",			NULL,
    &wPreferences.dont_confirm_kill,	getBool,NULL
    },
    {"WindowTitleBalloons", "NO",		NULL,
    &wPreferences.window_balloon,	getBool,	NULL
    },
    {"MiniwindowTitleBalloons", "NO",		NULL,
    &wPreferences.miniwin_balloon,getBool,	NULL
    },
    {"AppIconBalloons", "NO",		NULL,
    &wPreferences.appicon_balloon,getBool,	NULL
    },
    {"HelpBalloons",	"NO",		NULL,
    &wPreferences.help_balloon,	getBool,	NULL
    },
    {"EdgeResistance", 	"30",			NULL,
    &wPreferences.edge_resistance,getInt,		NULL
    },
    {"Attraction", 	"NO",			NULL,
    &wPreferences.attract,  getBool,    NULL
    },
    {"DisableBlinking",	"NO",		NULL,
    &wPreferences.dont_blink,	getBool,	NULL
    },
    /* style options */
    {"MenuStyle", 	"normal",  		seMenuStyles,
    &wPreferences.menu_style, getEnum, 	setMenuStyle
    },
    {"WidgetColor",	"(solid, gray)",	NULL,
    NULL,				getTexture,	setWidgetColor,
    },
    {"WorkspaceSpecificBack","()",	NULL,
    NULL,		getWSSpecificBackground, setWorkspaceSpecificBack
    },
    /* WorkspaceBack must come after WorkspaceSpecificBack or
     * WorkspaceBack wont know WorkspaceSpecificBack was also
     * specified and 2 copies of wmsetbg will be launched */
    {"WorkspaceBack",	"(solid, black)",	NULL,
    NULL,				getWSBackground,setWorkspaceBack
    },
    {"SmoothWorkspaceBack", 	"NO",		NULL,
    NULL,				getBool,	NULL
    },
    {"IconBack",	"(solid, gray)",       	NULL,
    NULL,				getTexture,	setIconTile
    },
    {"TitleJustify",	"center",		seJustifications,
    &wPreferences.title_justification, getEnum,	setJustify
    },
    {"WindowTitleFont",	DEF_TITLE_FONT,	       	NULL,
    NULL,				getFont,	setWinTitleFont,
    },
    {"WindowTitleExtendSpace",	DEF_WINDOW_TITLE_EXTEND_SPACE,	       	NULL,
    &wPreferences.window_title_clearance,	getInt,		setClearance
    },
    {"MenuTitleExtendSpace",	DEF_MENU_TITLE_EXTEND_SPACE,	       	NULL,
    &wPreferences.menu_title_clearance,	getInt,		setClearance
    },
    {"MenuTextExtendSpace",	DEF_MENU_TEXT_EXTEND_SPACE,	       	NULL,
    &wPreferences.menu_text_clearance,	getInt,		setClearance
    },
    {"MenuTitleFont",	DEF_MENU_TITLE_FONT,	NULL,
    NULL,				getFont,	setMenuTitleFont
    },
    {"MenuTextFont",	DEF_MENU_ENTRY_FONT,	NULL,
    NULL,				getFont,	setMenuTextFont
    },
    {"IconTitleFont",	DEF_ICON_TITLE_FONT,	NULL,
    NULL,				getFont,	setIconTitleFont
    },
    {"ClipTitleFont",	DEF_CLIP_TITLE_FONT,	NULL,
    NULL,				getFont,	setClipTitleFont
    },
    {"LargeDisplayFont",DEF_WORKSPACE_NAME_FONT, NULL,
    NULL,				getFont,	setLargeDisplayFont
    },
    {"HighlightColor",	"white",		NULL,
    NULL,				getColor,	setHightlight
    },
    {"HighlightTextColor",	"black",	NULL,
    NULL,				getColor,	setHightlightText
    },
    {"ClipTitleColor",	"black",		(void*)CLIP_NORMAL,
    NULL,				getColor,	setClipTitleColor
    },
    {"CClipTitleColor", "\"#454045\"",		(void*)CLIP_COLLAPSED,
    NULL,				getColor,	setClipTitleColor
    },
    {"FTitleColor",	"white",		(void*)WS_FOCUSED,
    NULL,				getColor,	setWTitleColor
    },
    {"PTitleColor",	"white",		(void*)WS_PFOCUSED,
    NULL,				getColor,	setWTitleColor
    },
    {"UTitleColor",	"black",		(void*)WS_UNFOCUSED,
    NULL,				getColor,	setWTitleColor
    },
    {"FTitleBack",	"(solid, black)",      	NULL,
    NULL,				getTexture,	setFTitleBack
    },
    {"PTitleBack",	"(solid, \"#616161\")",	NULL,
    NULL,				getTexture,	setPTitleBack
    },
    {"UTitleBack",	"(solid, gray)",	NULL,
    NULL,				getTexture,	setUTitleBack
    },
    {"ResizebarBack",	"(solid, gray)",	NULL,
    NULL,				getTexture,	setResizebarBack
    },
    {"MenuTitleColor",	"white",       		NULL,
    NULL,				getColor,	setMenuTitleColor
    },
    {"MenuTextColor",	"black",       		NULL,
    NULL,				getColor,	setMenuTextColor
    },
    {"MenuDisabledColor", "\"#616161\"",       	NULL,
    NULL,				getColor,	setMenuDisabledColor
    },
    {"MenuTitleBack",	"(solid, black)",      	NULL,
    NULL,				getTexture,	setMenuTitleBack
    },
    {"MenuTextBack",	"(solid, gray)",       	NULL,
    NULL,				getTexture,	setMenuTextBack
    },
    {"IconTitleColor",	"white",       		NULL,
    NULL,				getColor,	setIconTitleColor
    },
    {"IconTitleBack",	"black",       		NULL,
    NULL,				getColor,	setIconTitleBack
    },
    {"SwitchPanelImages", "(swtile.png, swback.png, 30, 40)",  &wPreferences,
    NULL,               getPropList,     setSwPOptions
    },
    /* keybindings */
#ifndef LITE
    {"RootMenuKey",	"None",			(void*)WKBD_ROOTMENU,
    NULL,				getKeybind,	setKeyGrab
    },
    {"WindowListKey",	"None",			(void*)WKBD_WINDOWLIST,
    NULL,				getKeybind,	setKeyGrab
    },
#endif /* LITE */
    {"WindowMenuKey",	"None",		       	(void*)WKBD_WINDOWMENU,
    NULL,				getKeybind,	setKeyGrab
    },
    {"ClipLowerKey",   "None",		        (void*)WKBD_CLIPLOWER,
    NULL,				getKeybind,	setKeyGrab
    },
    {"ClipRaiseKey",   "None",		        (void*)WKBD_CLIPRAISE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"ClipRaiseLowerKey", "None",		 (void*)WKBD_CLIPRAISELOWER,
    NULL,				getKeybind,	setKeyGrab
    },
    {"MiniaturizeKey",	"None",	       		(void*)WKBD_MINIATURIZE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"HideKey", "None",	       			(void*)WKBD_HIDE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"HideOthersKey", "None",	       		(void*)WKBD_HIDE_OTHERS,
    NULL,				getKeybind,	setKeyGrab
    },
    {"MoveResizeKey", "None",	       		(void*)WKBD_MOVERESIZE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"CloseKey", "None",       			(void*)WKBD_CLOSE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"MaximizeKey", "None",			(void*)WKBD_MAXIMIZE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"VMaximizeKey", "None",			(void*)WKBD_VMAXIMIZE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"HMaximizeKey", "None",			(void*)WKBD_HMAXIMIZE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"RaiseKey", "\"Meta+Up\"",			(void*)WKBD_RAISE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"LowerKey", "\"Meta+Down\"",			(void*)WKBD_LOWER,
    NULL,				getKeybind,	setKeyGrab
    },
    {"RaiseLowerKey", "None",			(void*)WKBD_RAISELOWER,
    NULL,				getKeybind,	setKeyGrab
    },
    {"ShadeKey", "None",			(void*)WKBD_SHADE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"SelectKey", "None",			(void*)WKBD_SELECT,
    NULL,				getKeybind,	setKeyGrab
    },
    {"FocusNextKey", "None",		       	(void*)WKBD_FOCUSNEXT,
    NULL,				getKeybind,	setKeyGrab
    },
    {"FocusPrevKey", "None",			(void*)WKBD_FOCUSPREV,
    NULL,				getKeybind,	setKeyGrab
    },
    {"NextWorkspaceKey", "None",		(void*)WKBD_NEXTWORKSPACE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"PrevWorkspaceKey", "None",       		(void*)WKBD_PREVWORKSPACE,
    NULL,				getKeybind,	setKeyGrab
    },
    {"NextWorkspaceLayerKey", "None",		(void*)WKBD_NEXTWSLAYER,
    NULL,				getKeybind,	setKeyGrab
    },
    {"PrevWorkspaceLayerKey", "None", 		(void*)WKBD_PREVWSLAYER,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace1Key", "None",			(void*)WKBD_WORKSPACE1,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace2Key", "None",			(void*)WKBD_WORKSPACE2,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace3Key", "None",			(void*)WKBD_WORKSPACE3,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace4Key", "None",			(void*)WKBD_WORKSPACE4,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace5Key", "None",			(void*)WKBD_WORKSPACE5,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace6Key", "None",			(void*)WKBD_WORKSPACE6,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace7Key", "None",			(void*)WKBD_WORKSPACE7,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace8Key", "None",			(void*)WKBD_WORKSPACE8,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace9Key", "None",			(void*)WKBD_WORKSPACE9,
    NULL,				getKeybind,	setKeyGrab
    },
    {"Workspace10Key", "None",			(void*)WKBD_WORKSPACE10,
    NULL,				getKeybind,	setKeyGrab
    },
    {"WindowShortcut1Key","None",		(void*)WKBD_WINDOW1,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"WindowShortcut2Key","None",		(void*)WKBD_WINDOW2,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"WindowShortcut3Key","None",		(void*)WKBD_WINDOW3,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"WindowShortcut4Key","None",		(void*)WKBD_WINDOW4,
    NULL, 			getKeybind,	setKeyGrab
    }
    ,{"WindowShortcut5Key","None",		(void*)WKBD_WINDOW5,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"WindowShortcut6Key","None",		(void*)WKBD_WINDOW6,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"WindowShortcut7Key","None",		(void*)WKBD_WINDOW7,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"WindowShortcut8Key","None",		(void*)WKBD_WINDOW8,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"WindowShortcut9Key","None",		(void*)WKBD_WINDOW9,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"WindowShortcut10Key","None",		(void*)WKBD_WINDOW10,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"ScreenSwitchKey",  "None",		(void*)WKBD_SWITCH_SCREEN,
    NULL, 			getKeybind,	setKeyGrab
    },
    {"NormalCursor", "(builtin, left_ptr)",	(void*)WCUR_ROOT,
    NULL,				getCursor,	setCursor
    },
    {"ArrowCursor", "(builtin, top_left_arrow)",	(void*)WCUR_ARROW,
    NULL,				getCursor,	setCursor
    },
    {"MoveCursor", "(builtin, fleur)",		(void*)WCUR_MOVE,
    NULL,				getCursor,	setCursor
    },
    {"ResizeCursor", "(builtin, sizing)",	(void*)WCUR_RESIZE,
    NULL,				getCursor,	setCursor
    },
    {"TopLeftResizeCursor", "(builtin, top_left_corner)",
    (void*)WCUR_TOPLEFTRESIZE,
    NULL,				getCursor,	setCursor
    },
    {"TopRightResizeCursor", "(builtin, top_right_corner)",
    (void*)WCUR_TOPRIGHTRESIZE,
    NULL,				getCursor,	setCursor
    },
    {"BottomLeftResizeCursor", "(builtin, bottom_left_corner)",
    (void*)WCUR_BOTTOMLEFTRESIZE,
    NULL,				getCursor,	setCursor
    },
    {"BottomRightResizeCursor", "(builtin, bottom_right_corner)",
    (void*)WCUR_BOTTOMRIGHTRESIZE,
    NULL,				getCursor,	setCursor
    },
    {"VerticalResizeCursor", "(builtin, sb_v_double_arrow)",
    (void*)WCUR_VERTICALRESIZE,
    NULL,				getCursor,	setCursor
    },
    {"HorizontalResizeCursor", "(builtin, sb_h_double_arrow)",
    (void*)WCUR_HORIZONRESIZE,
    NULL,				getCursor,	setCursor
    },
    {"WaitCursor", "(builtin, watch)",		(void*)WCUR_WAIT,
    NULL,				getCursor,	setCursor
    },
    {"QuestionCursor", "(builtin, question_arrow)",	(void*)WCUR_QUESTION,
    NULL,				getCursor,	setCursor
    },
    {"TextCursor", "(builtin, xterm)",		(void*)WCUR_TEXT,
    NULL,				getCursor,	setCursor
    },
    {"SelectCursor", "(builtin, cross)",	(void*)WCUR_SELECT,
    NULL,				getCursor,	setCursor
    }
};


#if 0
static void rereadDefaults(void);
#endif

#if 0
static void
rereadDefaults(void)
{
    /* must defer the update because accessing X data from a
     * signal handler can mess up Xlib */

}
#endif

static void
initDefaults()
{
    int i;
    WDefaultEntry *entry;

    WMPLSetCaseSensitive(False);

    for (i=0; i<sizeof(optionList)/sizeof(WDefaultEntry); i++) {
        entry = &optionList[i];

        entry->plkey = WMCreatePLString(entry->key);
        if (entry->default_value)
            entry->plvalue = WMCreatePropListFromDescription(entry->default_value);
        else
            entry->plvalue = NULL;
    }

    for (i=0; i<sizeof(staticOptionList)/sizeof(WDefaultEntry); i++) {
        entry = &staticOptionList[i];

        entry->plkey = WMCreatePLString(entry->key);
        if (entry->default_value)
            entry->plvalue = WMCreatePropListFromDescription(entry->default_value);
        else
            entry->plvalue = NULL;
    }

    /*
     wDomainName = WMCreatePLString(WMDOMAIN_NAME);
     wAttributeDomainName = WMCreatePLString(WMATTRIBUTE_DOMAIN_NAME);

     PLRegister(wDomainName, rereadDefaults);
     PLRegister(wAttributeDomainName, rereadDefaults);
     */
}


static WMPropList*
readGlobalDomain(char *domainName, Bool requireDictionary)
{
    WMPropList *globalDict = NULL;
    char path[PATH_MAX];
    struct stat stbuf;

    snprintf(path, sizeof(path), "%s/WindowMaker/%s", SYSCONFDIR, domainName);
    if (stat(path, &stbuf)>=0) {
        globalDict = WMReadPropListFromFile(path);
        if (globalDict && requireDictionary && !WMIsPLDictionary(globalDict)) {
            wwarning(_("Domain %s (%s) of global defaults database is corrupted!"),
                     domainName, path);
            WMReleasePropList(globalDict);
            globalDict = NULL;
        } else if (!globalDict) {
            wwarning(_("could not load domain %s from global defaults database"),
                     domainName);
        }
    }

    return globalDict;
}


#if defined(GLOBAL_PREAMBLE_MENU_FILE) || defined(GLOBAL_EPILOGUE_MENU_FILE)
static void
prependMenu(WMPropList *destarr, WMPropList *array)
{
    WMPropList *item;
    int i;

    for (i=0; i<WMGetPropListItemCount(array); i++) {
        item = WMGetFromPLArray(array, i);
        if (item)
            WMInsertInPLArray(destarr, i+1, item);
    }
}


static void
appendMenu(WMPropList *destarr, WMPropList *array)
{
    WMPropList *item;
    int i;

    for (i=0; i<WMGetPropListItemCount(array); i++) {
        item = WMGetFromPLArray(array, i);
        if (item)
            WMAddToPLArray(destarr, item);
    }
}
#endif


/* Fixup paths for cached pixmaps from .AppInfo to Library/WindowMaker/... */
static Bool
fixupCachedPixmapsPaths(WMPropList *dict)
{
    WMPropList *allApps, *app, *props, *iconkey, *icon, *newicon;
    char *path, *fixedpath, *ptr, *search;
    int i, len, slen;
    Bool changed = False;

    search  = "/.AppInfo/WindowMaker/";
    slen = strlen(search);

    iconkey = WMCreatePLString("Icon");
    allApps = WMGetPLDictionaryKeys(dict);

    for (i=0; i < WMGetPropListItemCount(allApps); i++) {
        app = WMGetFromPLArray(allApps, i);
        props = WMGetFromPLDictionary(dict, app);
        if (!props)
            continue;
        icon = WMGetFromPLDictionary(props, iconkey);
        if (icon && WMIsPLString(icon)) {
            path = WMGetFromPLString(icon);
            ptr = strstr(path, search);
            if (ptr) {
                changed = True;
                len = (ptr - path);
                fixedpath = wmalloc(strlen(path)+32);
                strncpy(fixedpath, path, len);
                fixedpath[len] = 0;
                strcat(fixedpath, "/Library/WindowMaker/CachedPixmaps/");
                strcat(fixedpath, ptr+slen);
                newicon = WMCreatePLString(fixedpath);
                WMPutInPLDictionary(props, iconkey, newicon);
                WMReleasePropList(newicon);
                wfree(fixedpath);
            }
        }
    }

    WMReleasePropList(allApps);
    WMReleasePropList(iconkey);

    return changed;
}


void
wDefaultsMergeGlobalMenus(WDDomain *menuDomain)
{
    WMPropList *menu = menuDomain->dictionary;
    WMPropList *submenu;

    if (!menu || !WMIsPLArray(menu))
        return;

#ifdef GLOBAL_PREAMBLE_MENU_FILE
    submenu = WMReadPropListFromFile(SYSCONFDIR"/WindowMaker/"GLOBAL_PREAMBLE_MENU_FILE);

    if (submenu && !WMIsPLArray(submenu)) {
        wwarning(_("invalid global menu file %s"),
                 GLOBAL_PREAMBLE_MENU_FILE);
        WMReleasePropList(submenu);
        submenu = NULL;
    }
    if (submenu) {
        prependMenu(menu, submenu);
        WMReleasePropList(submenu);
    }
#endif

#ifdef GLOBAL_EPILOGUE_MENU_FILE
    submenu = WMReadPropListFromFile(SYSCONFDIR"/WindowMaker/"GLOBAL_EPILOGUE_MENU_FILE);

    if (submenu && !WMIsPLArray(submenu)) {
        wwarning(_("invalid global menu file %s"),
                 GLOBAL_EPILOGUE_MENU_FILE);
        WMReleasePropList(submenu);
        submenu = NULL;
    }
    if (submenu) {
        appendMenu(menu, submenu);
        WMReleasePropList(submenu);
    }
#endif

    menuDomain->dictionary = menu;
}


void
wDefaultsDestroyDomain(WDDomain *domain)
{
    if (domain->dictionary)
        WMReleasePropList(domain->dictionary);
    wfree(domain->path);
    wfree(domain);
}


WDDomain*
wDefaultsInitDomain(char *domain, Bool requireDictionary)
{
    WDDomain *db;
    struct stat stbuf;
    static int inited = 0;
    char path[PATH_MAX];
    char *the_path;
    WMPropList *shared_dict=NULL;

    if (!inited) {
        inited = 1;
        initDefaults();
    }

    db = wmalloc(sizeof(WDDomain));
    memset(db, 0, sizeof(WDDomain));
    db->domain_name = domain;
    db->path = wdefaultspathfordomain(domain);
    the_path = db->path;

    if (the_path && stat(the_path, &stbuf)>=0) {
        db->dictionary = WMReadPropListFromFile(the_path);
        if (db->dictionary) {
            if (requireDictionary && !WMIsPLDictionary(db->dictionary)) {
                WMReleasePropList(db->dictionary);
                db->dictionary = NULL;
                wwarning(_("Domain %s (%s) of defaults database is corrupted!"),
                         domain, the_path);
            }
            if (strcmp(domain, "WMWindowAttributes")==0 && db->dictionary) {
                if (fixupCachedPixmapsPaths(db->dictionary)) {
                    WMWritePropListToFile(db->dictionary, db->path, True);
                    /* re-read the timestamp. if this fails take current time */
                    if (stat(db->path, &stbuf)<0) {
                        stbuf.st_mtime = time(NULL);
                    }
                }
            }
            db->timestamp = stbuf.st_mtime;
        } else {
            wwarning(_("could not load domain %s from user defaults database"),
                     domain);
        }
    }

    /* global system dictionary */
    snprintf(path, sizeof(path), "%s/WindowMaker/%s", SYSCONFDIR, domain);
    if (stat(path, &stbuf)>=0) {
        shared_dict = WMReadPropListFromFile(path);
        if (shared_dict) {
            if (requireDictionary && !WMIsPLDictionary(shared_dict)) {
                wwarning(_("Domain %s (%s) of global defaults database is corrupted!"),
                         domain, path);
                WMReleasePropList(shared_dict);
                shared_dict = NULL;
            } else {
                if (db->dictionary && WMIsPLDictionary(shared_dict) &&
                    WMIsPLDictionary(db->dictionary)) {
                    WMMergePLDictionaries(shared_dict, db->dictionary, True);
                    WMReleasePropList(db->dictionary);
                    db->dictionary = shared_dict;
                    if (stbuf.st_mtime > db->timestamp)
                        db->timestamp = stbuf.st_mtime;
                } else if (!db->dictionary) {
                    db->dictionary = shared_dict;
                    if (stbuf.st_mtime > db->timestamp)
                        db->timestamp = stbuf.st_mtime;
                }
            }
        } else {
            wwarning(_("could not load domain %s from global defaults database (%s)"),
                     domain, path);
        }
    }

    return db;
}


void
wReadStaticDefaults(WMPropList *dict)
{
    WMPropList *plvalue;
    WDefaultEntry *entry;
    int i;
    void *tdata;


    for (i=0; i<sizeof(staticOptionList)/sizeof(WDefaultEntry); i++) {
        entry = &staticOptionList[i];

        if (dict)
            plvalue = WMGetFromPLDictionary(dict, entry->plkey);
        else
            plvalue = NULL;

        if (!plvalue) {
            /* no default in the DB. Use builtin default */
            plvalue = entry->plvalue;
        }

        if (plvalue) {
            /* convert data */
            (*entry->convert)(NULL, entry, plvalue, entry->addr, &tdata);
            if (entry->update) {
                (*entry->update)(NULL, entry, tdata, entry->extra_data);
            }
        }
    }
}



void
wDefaultsCheckDomains(void *foo)
{
    WScreen *scr;
    struct stat stbuf;
    WMPropList *shared_dict = NULL;
    WMPropList *dict;
    int i;

#ifdef HEARTBEAT
    puts("Checking domains...");
#endif
    if (stat(WDWindowMaker->path, &stbuf)>=0
        && WDWindowMaker->timestamp < stbuf.st_mtime) {
#ifdef HEARTBEAT
        puts("Checking WindowMaker domain");
#endif
        WDWindowMaker->timestamp = stbuf.st_mtime;

        /* global dictionary */
        shared_dict = readGlobalDomain("WindowMaker", True);
        /* user dictionary */
        dict = WMReadPropListFromFile(WDWindowMaker->path);
        if (dict) {
            if (!WMIsPLDictionary(dict)) {
                WMReleasePropList(dict);
                dict = NULL;
                wwarning(_("Domain %s (%s) of defaults database is corrupted!"),
                         "WindowMaker", WDWindowMaker->path);
            } else {
                if (shared_dict) {
                    WMMergePLDictionaries(shared_dict, dict, True);
                    WMReleasePropList(dict);
                    dict = shared_dict;
                    shared_dict = NULL;
                }
                for (i=0; i<wScreenCount; i++) {
                    scr = wScreenWithNumber(i);
                    if (scr)
                        wReadDefaults(scr, dict);
                }
                if (WDWindowMaker->dictionary) {
                    WMReleasePropList(WDWindowMaker->dictionary);
                }
                WDWindowMaker->dictionary = dict;
            }
        } else {
            wwarning(_("could not load domain %s from user defaults database"),
                     "WindowMaker");
        }
        if (shared_dict) {
            WMReleasePropList(shared_dict);
        }
    }

    if (stat(WDWindowAttributes->path, &stbuf)>=0
        && WDWindowAttributes->timestamp < stbuf.st_mtime) {
#ifdef HEARTBEAT
        puts("Checking WMWindowAttributes domain");
#endif
        /* global dictionary */
        shared_dict = readGlobalDomain("WMWindowAttributes", True);
        /* user dictionary */
        dict = WMReadPropListFromFile(WDWindowAttributes->path);
        if (dict) {
            if (!WMIsPLDictionary(dict)) {
                WMReleasePropList(dict);
                dict = NULL;
                wwarning(_("Domain %s (%s) of defaults database is corrupted!"),
                         "WMWindowAttributes", WDWindowAttributes->path);
            } else {
                if (shared_dict) {
                    WMMergePLDictionaries(shared_dict, dict, True);
                    WMReleasePropList(dict);
                    dict = shared_dict;
                    shared_dict = NULL;
                }
                if (WDWindowAttributes->dictionary) {
                    WMReleasePropList(WDWindowAttributes->dictionary);
                }
                WDWindowAttributes->dictionary = dict;
                for (i=0; i<wScreenCount; i++) {
                    scr = wScreenWithNumber(i);
                    if (scr) {
                        RImage *image;

                        wDefaultUpdateIcons(scr);

                        /* Update the panel image if changed */
                        /* Don't worry. If the image is the same these
                         * functions will have no performance impact. */
                        image = wDefaultGetImage(scr, "Logo", "WMPanel");

                        if (!image) {
                            wwarning(_("could not load logo image for panels: %s"),
                                     RMessageForError(RErrorCode));
                        } else {
                            WMSetApplicationIconImage(scr->wmscreen, image);
                            RReleaseImage(image);
                        }
                    }
                }
            }
        } else {
            wwarning(_("could not load domain %s from user defaults database"),
                     "WMWindowAttributes");
        }
        WDWindowAttributes->timestamp = stbuf.st_mtime;
        if (shared_dict) {
            WMReleasePropList(shared_dict);
        }
    }

#ifndef LITE
    if (stat(WDRootMenu->path, &stbuf)>=0
        && WDRootMenu->timestamp < stbuf.st_mtime) {
        dict = WMReadPropListFromFile(WDRootMenu->path);
#ifdef HEARTBEAT
        puts("Checking WMRootMenu domain");
#endif
        if (dict) {
            if (!WMIsPLArray(dict) && !WMIsPLString(dict)) {
                WMReleasePropList(dict);
                dict = NULL;
                wwarning(_("Domain %s (%s) of defaults database is corrupted!"),
                         "WMRootMenu", WDRootMenu->path);
            } else {
                if (WDRootMenu->dictionary) {
                    WMReleasePropList(WDRootMenu->dictionary);
                }
                WDRootMenu->dictionary = dict;
                wDefaultsMergeGlobalMenus(WDRootMenu);
            }
        } else {
            wwarning(_("could not load domain %s from user defaults database"),
                     "WMRootMenu");
        }
        WDRootMenu->timestamp = stbuf.st_mtime;
    }
#endif /* !LITE */

    if (!foo)
        WMAddTimerHandler(DEFAULTS_CHECK_INTERVAL, wDefaultsCheckDomains, foo);
}


void
wReadDefaults(WScreen *scr, WMPropList *new_dict)
{
    WMPropList *plvalue, *old_value;
    WDefaultEntry *entry;
    int i, must_update;
    int update_workspace_back = 0;	       /* kluge :/ */
    int needs_refresh;
    void *tdata;
    WMPropList *old_dict = (WDWindowMaker->dictionary!=new_dict
                            ? WDWindowMaker->dictionary : NULL);

    must_update = 0;

    needs_refresh = 0;

    for (i=0; i<sizeof(optionList)/sizeof(WDefaultEntry); i++) {
        entry = &optionList[i];

        if (new_dict)
            plvalue = WMGetFromPLDictionary(new_dict, entry->plkey);
        else
            plvalue = NULL;

        if (!old_dict)
            old_value = NULL;
        else
            old_value = WMGetFromPLDictionary(old_dict, entry->plkey);


        if (!plvalue && !old_value) {
            /* no default in  the DB. Use builtin default */
            plvalue = entry->plvalue;
            if (plvalue && new_dict) {
                WMPutInPLDictionary(new_dict, entry->plkey, plvalue);
                must_update = 1;
            }
        } else if (!plvalue) {
            /* value was deleted from DB. Keep current value */
            continue;
        } else if (!old_value) {
            /* set value for the 1st time */
        } else if (!WMIsPropListEqualTo(plvalue, old_value)) {
            /* value has changed */
        } else {

            if (strcmp(entry->key, "WorkspaceBack") == 0
                && update_workspace_back
                && scr->flags.backimage_helper_launched) {
            } else {
                /* value was not changed since last time */
                continue;
            }
        }

        if (plvalue) {
#ifdef DEBUG
            printf("Updating %s to %s\n", entry->key,
                   WMGetPropListDescription(plvalue, False));
#endif
            /* convert data */
            if ((*entry->convert)(scr, entry, plvalue, entry->addr, &tdata)) {
                /*
                 * If the WorkspaceSpecificBack data has been changed
                 * so that the helper will be launched now, we must be
                 * sure to send the default background texture config
                 * to the helper.
                 */
                if (strcmp(entry->key, "WorkspaceSpecificBack") == 0
                    && !scr->flags.backimage_helper_launched) {
                    update_workspace_back = 1;
                }
                if (entry->update) {
                    needs_refresh |=
                        (*entry->update)(scr, entry, tdata, entry->extra_data);
                }
            }
        }
    }

    if (needs_refresh!=0 && !scr->flags.startup) {
        int foo;

        foo = 0;
        if (needs_refresh & REFRESH_MENU_TITLE_TEXTURE)
            foo |= WTextureSettings;
        if (needs_refresh & REFRESH_MENU_TITLE_FONT)
            foo |= WFontSettings;
        if (needs_refresh & REFRESH_MENU_TITLE_COLOR)
            foo |= WColorSettings;
        if (foo)
            WMPostNotificationName(WNMenuTitleAppearanceSettingsChanged, NULL,
                                   (void*)foo);

        foo = 0;
        if (needs_refresh & REFRESH_MENU_TEXTURE)
            foo |= WTextureSettings;
        if (needs_refresh & REFRESH_MENU_FONT)
            foo |= WFontSettings;
        if (needs_refresh & REFRESH_MENU_COLOR)
            foo |= WColorSettings;
        if (foo)
            WMPostNotificationName(WNMenuAppearanceSettingsChanged, NULL,
                                   (void*)foo);

        foo = 0;
        if (needs_refresh & REFRESH_WINDOW_FONT) {
            foo |= WFontSettings;
        }
        if (needs_refresh & REFRESH_WINDOW_TEXTURES) {
            foo |= WTextureSettings;
        }
        if (needs_refresh & REFRESH_WINDOW_TITLE_COLOR) {
            foo |= WColorSettings;
        }
        if (foo)
            WMPostNotificationName(WNWindowAppearanceSettingsChanged, NULL,
                                   (void*)foo);

        if (!(needs_refresh & REFRESH_ICON_TILE)) {
            foo = 0;
            if (needs_refresh & REFRESH_ICON_FONT) {
                foo |= WFontSettings;
            }
            if (needs_refresh & REFRESH_ICON_TITLE_COLOR) {
                foo |= WTextureSettings;
            }
            if (needs_refresh & REFRESH_ICON_TITLE_BACK) {
                foo |= WTextureSettings;
            }
            if (foo)
                WMPostNotificationName(WNIconAppearanceSettingsChanged, NULL,
                                       (void*)foo);
        }
        if (needs_refresh & REFRESH_ICON_TILE)
            WMPostNotificationName(WNIconTileSettingsChanged, NULL,  NULL);
    }
}


void
wDefaultUpdateIcons(WScreen *scr)
{
    WAppIcon *aicon = scr->app_icon_list;
    WWindow *wwin = scr->focused_window;
    char *file;

    while(aicon) {
        file = wDefaultGetIconFile(scr, aicon->wm_instance, aicon->wm_class,
                                   False);
        if ((file && aicon->icon->file && strcmp(file, aicon->icon->file)!=0)
            || (file && !aicon->icon->file)) {
            RImage *new_image;

            if (aicon->icon->file)
                wfree(aicon->icon->file);
            aicon->icon->file = wstrdup(file);

            new_image = wDefaultGetImage(scr, aicon->wm_instance,
                                         aicon->wm_class);
            if (new_image) {
                wIconChangeImage(aicon->icon, new_image);
                wAppIconPaint(aicon);
            }
        }
        aicon = aicon->next;
    }

    if (!wPreferences.flags.noclip)
        wClipIconPaint(scr->clip_icon);

    while (wwin) {
        if (wwin->icon && wwin->flags.miniaturized) {
            file = wDefaultGetIconFile(scr, wwin->wm_instance, wwin->wm_class,
                                       False);
            if ((file && wwin->icon->file && strcmp(file, wwin->icon->file)!=0)
                || (file && !wwin->icon->file)) {
                RImage *new_image;

                if (wwin->icon->file)
                    wfree(wwin->icon->file);
                wwin->icon->file = wstrdup(file);

                new_image = wDefaultGetImage(scr, wwin->wm_instance,
                                             wwin->wm_class);
                if (new_image)
                    wIconChangeImage(wwin->icon, new_image);
            }
        }
        wwin = wwin->prev;
    }
}


/* --------------------------- Local ----------------------- */

#define GET_STRING_OR_DEFAULT(x, var) if (!WMIsPLString(value)) { \
    wwarning(_("Wrong option format for key \"%s\". Should be %s."), \
    entry->key, x); \
    wwarning(_("using default \"%s\" instead"), entry->default_value); \
    var = entry->default_value;\
    } else var = WMGetFromPLString(value)\





static int
string2index(WMPropList *key, WMPropList *val, char *def,
             WOptionEnumeration *values)
{
    char *str;
    WOptionEnumeration *v;
    char buffer[TOTAL_VALUES_LENGTH];

    if (WMIsPLString(val) && (str = WMGetFromPLString(val))) {
        for (v=values; v->string!=NULL; v++) {
            if (strcasecmp(v->string, str)==0)
                return v->value;
        }
    }

    buffer[0] = 0;
    for (v=values; v->string!=NULL; v++) {
        if (!v->is_alias) {
            if (buffer[0]!=0)
                strcat(buffer, ", ");
            strcat(buffer, v->string);
        }
    }
    wwarning(_("wrong option value for key \"%s\". Should be one of %s"),
             WMGetFromPLString(key), buffer);

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
static int
getBool(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
        void **ret)
{
    static char data;
    char *val;
    int second_pass=0;

    GET_STRING_OR_DEFAULT("Boolean", val);

again:
    if ((val[1]=='\0' && (val[0]=='y' || val[0]=='Y'))
        || strcasecmp(val, "YES")==0) {

        data = 1;
    } else if ((val[1]=='\0' && (val[0]=='n' || val[0]=='N'))
               || strcasecmp(val, "NO")==0) {
        data = 0;
    } else {
        int i;
        if (sscanf(val, "%i", &i)==1) {
            if (i!=0)
                data = 1;
            else
                data = 0;
        } else {
            wwarning(_("can't convert \"%s\" to boolean for key \"%s\""),
                     val, entry->key);
            if (second_pass==0) {
                val = WMGetFromPLString(entry->plvalue);
                second_pass = 1;
                wwarning(_("using default \"%s\" instead"), val);
                goto again;
            }
            return False;
        }
    }

    if (ret)
        *ret = &data;
    if (addr)
        *(char*)addr = data;

    return True;
}


static int
getInt(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
       void **ret)
{
    static int data;
    char *val;


    GET_STRING_OR_DEFAULT("Integer", val);

    if (sscanf(val, "%i", &data)!=1) {
        wwarning(_("can't convert \"%s\" to integer for key \"%s\""),
                 val, entry->key);
        val = WMGetFromPLString(entry->plvalue);
        wwarning(_("using default \"%s\" instead"), val);
        if (sscanf(val, "%i", &data)!=1) {
            return False;
        }
    }

    if (ret)
        *ret = &data;
    if (addr)
        *(int*)addr = data;

    return True;
}


static int
getCoord(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
         void **ret)
{
    static WCoord data;
    char *val_x, *val_y;
    int nelem, changed=0;
    WMPropList *elem_x, *elem_y;

again:
    if (!WMIsPLArray(value)) {
        wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                 entry->key, "Coordinate");
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    nelem = WMGetPropListItemCount(value);
    if (nelem != 2) {
        wwarning(_("Incorrect number of elements in array for key \"%s\"."),
                 entry->key);
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    elem_x = WMGetFromPLArray(value, 0);
    elem_y = WMGetFromPLArray(value, 1);

    if (!elem_x || !elem_y || !WMIsPLString(elem_x) || !WMIsPLString(elem_y)) {
        wwarning(_("Wrong value for key \"%s\". Should be Coordinate."),
                 entry->key);
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    val_x = WMGetFromPLString(elem_x);
    val_y = WMGetFromPLString(elem_y);

    if (sscanf(val_x, "%i", &data.x)!=1 || sscanf(val_y, "%i", &data.y)!=1) {
        wwarning(_("can't convert array to integers for \"%s\"."), entry->key);
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    if (data.x < 0)
        data.x = 0;
    else if (data.x > scr->scr_width/3)
        data.x = scr->scr_width/3;
    if (data.y < 0)
        data.y = 0;
    else if (data.y > scr->scr_height/3)
        data.y = scr->scr_height/3;

    if (ret)
        *ret = &data;
    if (addr)
        *(WCoord*)addr = data;

    return True;
}


static int
getPropList(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
           void **ret)
{
    WMRetainPropList(value);

    *ret= value;

    return True;
}

#if 0
/* This function is not used at the moment. */
static int
getString(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
          void **ret)
{
    static char *data;

    GET_STRING_OR_DEFAULT("String", data);

    if (!data) {
        data = WMGetFromPLString(entry->plvalue);
        if (!data)
            return False;
    }

    if (ret)
        *ret = &data;
    if (addr)
        *(char**)addr = wstrdup(data);

    return True;
}
#endif


static int
getPathList(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
            void **ret)
{
    static char *data;
    int i, count, len;
    char *ptr;
    WMPropList *d;
    int changed=0;

again:
    if (!WMIsPLArray(value)) {
        wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                 entry->key, "an array of paths");
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    i = 0;
    count = WMGetPropListItemCount(value);
    if (count < 1) {
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    len = 0;
    for (i=0; i<count; i++) {
        d = WMGetFromPLArray(value, i);
        if (!d || !WMIsPLString(d)) {
            count = i;
            break;
        }
        len += strlen(WMGetFromPLString(d))+1;
    }

    ptr = data = wmalloc(len+1);

    for (i=0; i<count; i++) {
        d = WMGetFromPLArray(value, i);
        if (!d || !WMIsPLString(d)) {
            break;
        }
        strcpy(ptr, WMGetFromPLString(d));
        ptr += strlen(WMGetFromPLString(d));
        *ptr = ':';
        ptr++;
    }
    ptr--; *(ptr--) = 0;

    if (*(char**)addr!=NULL) {
        wfree(*(char**)addr);
    }
    *(char**)addr = data;

    return True;
}


static int
getEnum(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
        void **ret)
{
    static signed char data;

    data = string2index(entry->plkey, value, entry->default_value,
                        (WOptionEnumeration*)entry->extra_data);
    if (data < 0)
        return False;

    if (ret)
        *ret = &data;
    if (addr)
        *(signed char*)addr = data;

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

static WTexture*
parse_texture(WScreen *scr, WMPropList *pl)
{
    WMPropList *elem;
    char *val;
    int nelem;
    WTexture *texture=NULL;

    nelem = WMGetPropListItemCount(pl);
    if (nelem < 1)
        return NULL;


    elem = WMGetFromPLArray(pl, 0);
    if (!elem || !WMIsPLString(elem))
        return NULL;
    val = WMGetFromPLString(elem);


    if (strcasecmp(val, "solid")==0) {
        XColor color;

        if (nelem != 2)
            return NULL;

        /* get color */

        elem = WMGetFromPLArray(pl, 1);
        if (!elem || !WMIsPLString(elem))
            return NULL;
        val = WMGetFromPLString(elem);

        if (!XParseColor(dpy, scr->w_colormap, val, &color)) {
            wwarning(_("\"%s\" is not a valid color name"), val);
            return NULL;
        }

        texture = (WTexture*)wTextureMakeSolid(scr, &color);
    } else if (strcasecmp(val, "dgradient")==0
               || strcasecmp(val, "vgradient")==0
               || strcasecmp(val, "hgradient")==0) {
        RColor color1, color2;
        XColor xcolor;
        int type;

        if (nelem != 3) {
            wwarning(_("bad number of arguments in gradient specification"));
            return NULL;
        }

        if (val[0]=='d' || val[0]=='D')
            type = WTEX_DGRADIENT;
        else if (val[0]=='h' || val[0]=='H')
            type = WTEX_HGRADIENT;
        else
            type = WTEX_VGRADIENT;


        /* get from color */
        elem = WMGetFromPLArray(pl, 1);
        if (!elem || !WMIsPLString(elem))
            return NULL;
        val = WMGetFromPLString(elem);

        if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
            wwarning(_("\"%s\" is not a valid color name"), val);
            return NULL;
        }
        color1.alpha = 255;
        color1.red = xcolor.red >> 8;
        color1.green = xcolor.green >> 8;
        color1.blue = xcolor.blue >> 8;

        /* get to color */
        elem = WMGetFromPLArray(pl, 2);
        if (!elem || !WMIsPLString(elem)) {
            return NULL;
        }
        val = WMGetFromPLString(elem);

        if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
            wwarning(_("\"%s\" is not a valid color name"), val);
            return NULL;
        }
        color2.alpha = 255;
        color2.red = xcolor.red >> 8;
        color2.green = xcolor.green >> 8;
        color2.blue = xcolor.blue >> 8;

        texture = (WTexture*)wTextureMakeGradient(scr, type, &color1, &color2);

    } else if (strcasecmp(val, "igradient")==0) {
        RColor colors1[2], colors2[2];
        int th1, th2;
        XColor xcolor;
        int i;

        if (nelem != 7) {
            wwarning(_("bad number of arguments in gradient specification"));
            return NULL;
        }

        /* get from color */
        for (i = 0; i < 2; i++) {
            elem = WMGetFromPLArray(pl, 1+i);
            if (!elem || !WMIsPLString(elem))
                return NULL;
            val = WMGetFromPLString(elem);

            if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
                wwarning(_("\"%s\" is not a valid color name"), val);
                return NULL;
            }
            colors1[i].alpha = 255;
            colors1[i].red = xcolor.red >> 8;
            colors1[i].green = xcolor.green >> 8;
            colors1[i].blue = xcolor.blue >> 8;
        }
        elem = WMGetFromPLArray(pl, 3);
        if (!elem || !WMIsPLString(elem))
            return NULL;
        val = WMGetFromPLString(elem);
        th1 = atoi(val);


        /* get from color */
        for (i = 0; i < 2; i++) {
            elem = WMGetFromPLArray(pl, 4+i);
            if (!elem || !WMIsPLString(elem))
                return NULL;
            val = WMGetFromPLString(elem);

            if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
                wwarning(_("\"%s\" is not a valid color name"), val);
                return NULL;
            }
            colors2[i].alpha = 255;
            colors2[i].red = xcolor.red >> 8;
            colors2[i].green = xcolor.green >> 8;
            colors2[i].blue = xcolor.blue >> 8;
        }
        elem = WMGetFromPLArray(pl, 6);
        if (!elem || !WMIsPLString(elem))
            return NULL;
        val = WMGetFromPLString(elem);
        th2 = atoi(val);

        texture = (WTexture*)wTextureMakeIGradient(scr, th1, colors1,
                                                   th2, colors2);

    } else if (strcasecmp(val, "mhgradient")==0
               || strcasecmp(val, "mvgradient")==0
               || strcasecmp(val, "mdgradient")==0) {
        XColor color;
        RColor **colors;
        int i, count;
        int type;

        if (nelem < 3) {
            wwarning(_("too few arguments in multicolor gradient specification"));
            return NULL;
        }

        if (val[1]=='h' || val[1]=='H')
            type = WTEX_MHGRADIENT;
        else if (val[1]=='v' || val[1]=='V')
            type = WTEX_MVGRADIENT;
        else
            type = WTEX_MDGRADIENT;

        count = nelem-1;

        colors = wmalloc(sizeof(RColor*)*(count+1));

        for (i=0; i<count; i++) {
            elem = WMGetFromPLArray(pl, i+1);
            if (!elem || !WMIsPLString(elem)) {
                for (--i; i>=0; --i) {
                    wfree(colors[i]);
                }
                wfree(colors);
                return NULL;
            }
            val = WMGetFromPLString(elem);

            if (!XParseColor(dpy, scr->w_colormap, val, &color)) {
                wwarning(_("\"%s\" is not a valid color name"), val);
                for (--i; i>=0; --i) {
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

        texture = (WTexture*)wTextureMakeMGradient(scr, type, colors);
    } else if (strcasecmp(val, "spixmap")==0 ||
               strcasecmp(val, "cpixmap")==0 ||
               strcasecmp(val, "tpixmap")==0) {
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
        elem = WMGetFromPLArray(pl, 2);
        if (!elem || !WMIsPLString(elem)) {
            return NULL;
        }
        val = WMGetFromPLString(elem);

        if (!XParseColor(dpy, scr->w_colormap, val, &color)) {
            wwarning(_("\"%s\" is not a valid color name"), val);
            return NULL;
        }

        /* file name */
        elem = WMGetFromPLArray(pl, 1);
        if (!elem || !WMIsPLString(elem))
            return NULL;
        val = WMGetFromPLString(elem);

        texture = (WTexture*)wTextureMakePixmap(scr, type, val, &color);
    } else if (strcasecmp(val, "thgradient")==0
               || strcasecmp(val, "tvgradient")==0
               || strcasecmp(val, "tdgradient")==0) {
        RColor color1, color2;
        XColor xcolor;
        int opacity;
        int style;

        if (val[1]=='h' || val[1]=='H')
            style = WTEX_THGRADIENT;
        else if (val[1]=='v' || val[1]=='V')
            style = WTEX_TVGRADIENT;
        else
            style = WTEX_TDGRADIENT;

        if (nelem != 5) {
            wwarning(_("bad number of arguments in textured gradient specification"));
            return NULL;
        }

        /* get from color */
        elem = WMGetFromPLArray(pl, 3);
        if (!elem || !WMIsPLString(elem))
            return NULL;
        val = WMGetFromPLString(elem);

        if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
            wwarning(_("\"%s\" is not a valid color name"), val);
            return NULL;
        }
        color1.alpha = 255;
        color1.red = xcolor.red >> 8;
        color1.green = xcolor.green >> 8;
        color1.blue = xcolor.blue >> 8;

        /* get to color */
        elem = WMGetFromPLArray(pl, 4);
        if (!elem || !WMIsPLString(elem)) {
            return NULL;
        }
        val = WMGetFromPLString(elem);

        if (!XParseColor(dpy, scr->w_colormap, val, &xcolor)) {
            wwarning(_("\"%s\" is not a valid color name"), val);
            return NULL;
        }
        color2.alpha = 255;
        color2.red = xcolor.red >> 8;
        color2.green = xcolor.green >> 8;
        color2.blue = xcolor.blue >> 8;

        /* get opacity */
        elem = WMGetFromPLArray(pl, 2);
        if (!elem || !WMIsPLString(elem))
            opacity = 128;
        else
            val = WMGetFromPLString(elem);

        if (!val || (opacity = atoi(val)) < 0 || opacity > 255) {
            wwarning(_("bad opacity value for tgradient texture \"%s\". Should be [0..255]"), val);
            opacity = 128;
        }

        /* get file name */
        elem = WMGetFromPLArray(pl, 1);
        if (!elem || !WMIsPLString(elem))
            return NULL;
        val = WMGetFromPLString(elem);

        texture = (WTexture*)wTextureMakeTGradient(scr, style, &color1, &color2,
                                                   val, opacity);
    }
#ifdef TEXTURE_PLUGIN
    else if (strcasecmp(val, "function")==0) {
        WTexFunction *function;
        void (*initFunc) (Display *, Colormap);
        char *lib, *func, **argv;
        int i, argc;

        if (nelem < 3)
            return NULL;

        /* get the library name */
        elem = WMGetFromPLArray(pl, 1);
        if (!elem || !WMIsPLString(elem)) {
            return NULL;
        }
        lib = WMGetFromPLString(elem);

        /* get the function name */
        elem = WMGetFromPLArray(pl, 2);
        if (!elem || !WMIsPLString(elem)) {
            return NULL;
        }
        func = WMGetFromPLString(elem);

        argc = nelem - 2;
        argv = (char **)wmalloc(argc * sizeof(char *));

        /* get the parameters */
        argv[0] = wstrdup(func);
        for (i = 0; i < argc - 1; i++) {
            elem = WMGetFromPLArray(pl, 3 + i);
            if (!elem || !WMIsPLString(elem)) {
                wfree(argv);

                return NULL;
            }
            argv[i+1] = wstrdup(WMGetFromPLString(elem));
        }

        function = wTextureMakeFunction(scr, lib, func, argc, argv);

#ifdef HAVE_DLFCN_H
        if (function) {
            initFunc = dlsym(function->handle, "initWindowMaker");
            if (initFunc) {
                initFunc(dpy, scr->w_colormap);
            } else {
                wwarning(_("could not initialize library %s"), lib);
            }
        } else {
            wwarning(_("could not find function %s::%s"), lib, func);
        }
#endif /* HAVE_DLFCN_H */
        texture = (WTexture*)function;
    }
#endif /* TEXTURE_PLUGIN */
    else {
        wwarning(_("invalid texture type %s"), val);
        return NULL;
    }
    return texture;
}



static int
getTexture(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
           void **ret)
{
    static WTexture *texture;
    int changed=0;

again:
    if (!WMIsPLArray(value)) {
        wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                 entry->key, "Texture");
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    if (strcmp(entry->key, "WidgetColor")==0 && !changed) {
        WMPropList *pl;

        pl = WMGetFromPLArray(value, 0);
        if (!pl || !WMIsPLString(pl) || !WMGetFromPLString(pl)
            || strcasecmp(WMGetFromPLString(pl), "solid")!=0) {
            wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                     entry->key, "Solid Texture");

            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
    }

    texture = parse_texture(scr, value);

    if (!texture) {
        wwarning(_("Error in texture specification for key \"%s\""),
                 entry->key);
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    if (ret)
        *ret = &texture;

    if (addr)
        *(WTexture**)addr = texture;

    return True;
}


static int
getWSBackground(WScreen *scr, WDefaultEntry *entry, WMPropList *value,
                void *addr, void **ret)
{
    WMPropList *elem;
    int changed = 0;
    char *val;
    int nelem;

again:
    if (!WMIsPLArray(value)) {
        wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                 "WorkspaceBack", "Texture or None");
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    /* only do basic error checking and verify for None texture */

    nelem = WMGetPropListItemCount(value);
    if (nelem > 0) {
        elem = WMGetFromPLArray(value, 0);
        if (!elem || !WMIsPLString(elem)) {
            wwarning(_("Wrong type for workspace background. Should be a texture type."));
            if (changed==0) {
                value = entry->plvalue;
                changed = 1;
                wwarning(_("using default \"%s\" instead"), entry->default_value);
                goto again;
            }
            return False;
        }
        val = WMGetFromPLString(elem);

        if (strcasecmp(val, "None")==0)
            return True;
    }
    *ret = WMRetainPropList(value);

    return True;
}


static int
getWSSpecificBackground(WScreen *scr, WDefaultEntry *entry, WMPropList *value,
                        void *addr, void **ret)
{
    WMPropList *elem;
    int nelem;
    int changed = 0;

again:
    if (!WMIsPLArray(value)) {
        wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                 "WorkspaceSpecificBack", "an array of textures");
        if (changed==0) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return False;
    }

    /* only do basic error checking and verify for None texture */

    nelem = WMGetPropListItemCount(value);
    if (nelem > 0) {
        while (nelem--) {
            elem = WMGetFromPLArray(value, nelem);
            if (!elem || !WMIsPLArray(elem)) {
                wwarning(_("Wrong type for background of workspace %i. Should be a texture."),
                         nelem);
            }
        }
    }

    *ret = WMRetainPropList(value);

#ifdef notworking
    /*
     * Kluge to force wmsetbg helper to set the default background.
     * If the WorkspaceSpecificBack is changed once wmaker has started,
     * the WorkspaceBack won't be sent to the helper, unless the user
     * changes it's value too. So, we must force this by removing the
     * value from the defaults DB.
     */
    if (!scr->flags.backimage_helper_launched && !scr->flags.startup) {
        WMPropList *key = WMCreatePLString("WorkspaceBack");

        WMRemoveFromPLDictionary(WDWindowMaker->dictionary, key);

        WMReleasePropList(key);
    }
#endif
    return True;
}


static int
getFont(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
        void **ret)
{
    static WMFont *font;
    char *val;

    GET_STRING_OR_DEFAULT("Font", val);

    font = WMCreateFont(scr->wmscreen, val);
    if (!font)
        font = WMCreateFont(scr->wmscreen, "fixed");

    if (!font) {
        wfatal(_("could not load any usable font!!!"));
        exit(1);
    }

    if (ret)
        *ret = font;

    /* can't assign font value outside update function */
    wassertrv(addr == NULL, True);

    return True;
}


static int
getColor(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
         void **ret)
{
    static XColor color;
    char *val;
    int second_pass=0;

    GET_STRING_OR_DEFAULT("Color", val);


again:
    if (!wGetColor(scr, val, &color)) {
        wwarning(_("could not get color for key \"%s\""),
                 entry->key);
        if (second_pass==0) {
            val = WMGetFromPLString(entry->plvalue);
            second_pass = 1;
            wwarning(_("using default \"%s\" instead"), val);
            goto again;
        }
        return False;
    }

    if (ret)
        *ret = &color;

    assert(addr==NULL);
    /*
     if (addr)
     *(unsigned long*)addr = pixel;
     */

    return True;
}



static int
getKeybind(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
           void **ret)
{
    static WShortKey shortcut;
    KeySym ksym;
    char *val;
    char *k;
    char buf[128], *b;


    GET_STRING_OR_DEFAULT("Key spec", val);

    if (!val || strcasecmp(val, "NONE")==0) {
        shortcut.keycode = 0;
        shortcut.modifier = 0;
        if (ret)
            *ret = &shortcut;
        return True;
    }

    strcpy(buf, val);

    b = (char*)buf;

    /* get modifiers */
    shortcut.modifier = 0;
    while ((k = strchr(b, '+'))!=NULL) {
        int mod;

        *k = 0;
        mod = wXModifierFromKey(b);
        if (mod<0) {
            wwarning(_("%s: invalid key modifier \"%s\""), entry->key, b);
            return False;
        }
        shortcut.modifier |= mod;

        b = k+1;
    }

    /* get key */
    ksym = XStringToKeysym(b);

    if (ksym==NoSymbol) {
        wwarning(_("%s:invalid kbd shortcut specification \"%s\""), entry->key,
                 val);
        return False;
    }

    shortcut.keycode = XKeysymToKeycode(dpy, ksym);
    if (shortcut.keycode==0) {
        wwarning(_("%s:invalid key in shortcut \"%s\""), entry->key, val);
        return False;
    }

    if (ret)
        *ret = &shortcut;

    return True;
}


static int
getModMask(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
           void **ret)
{
    static unsigned int mask;
    char *str;

    GET_STRING_OR_DEFAULT("Modifier Key", str);

    if (!str)
        return False;

    mask = wXModifierFromKey(str);
    if (mask < 0) {
        wwarning(_("%s: modifier key %s is not valid"), entry->key, str);
        mask = 0;
        return False;
    }

    if (addr)
        *(unsigned int*)addr = mask;

    if (ret)
        *ret = &mask;

    return True;
}


#ifdef NEWSTUFF
static int
getRImages(WScreen *scr, WDefaultEntry *entry, WMPropList *value,
           void *addr, void **ret)
{
    unsigned int mask;
    char *str;
    RImage *image;
    int i, n;
    int w, h;

    GET_STRING_OR_DEFAULT("Image File Path", str);
    if (!str)
        return False;

    image = RLoadImage(scr->rcontext, str, 0);
    if (!image) {
        wwarning(_("could not load image in option %s: %s"), entry->key,
                 RMessageForError(RErrorCode));
        return False;
    }

    if (*(RImage**)addr) {
        RReleaseImage(*(RImage**)addr);
    }
    if (addr)
        *(RImage**)addr = image;

    assert(ret == NULL);
    /*
     if (ret)
     *(RImage**)ret = image;
     */

    return True;
}
#endif

# include <X11/cursorfont.h>
typedef struct
{
    char *name;
    int id;
} WCursorLookup;

#define CURSOR_ID_NONE	(XC_num_glyphs)

static WCursorLookup cursor_table[] =
{
    { "X_cursor",		XC_X_cursor },
    { "arrow",			XC_arrow },
    { "based_arrow_down",	XC_based_arrow_down },
    { "based_arrow_up",		XC_based_arrow_up },
    { "boat",			XC_boat },
    { "bogosity",		XC_bogosity },
    { "bottom_left_corner",	XC_bottom_left_corner },
    { "bottom_right_corner",	XC_bottom_right_corner },
    { "bottom_side",		XC_bottom_side },
    { "bottom_tee",		XC_bottom_tee },
    { "box_spiral",		XC_box_spiral },
    { "center_ptr",		XC_center_ptr },
    { "circle",			XC_circle },
    { "clock",			XC_clock },
    { "coffee_mug",		XC_coffee_mug },
    { "cross",			XC_cross },
    { "cross_reverse",		XC_cross_reverse },
    { "crosshair",		XC_crosshair },
    { "diamond_cross",		XC_diamond_cross },
    { "dot",			XC_dot },
    { "dotbox",			XC_dotbox },
    { "double_arrow",		XC_double_arrow },
    { "draft_large",		XC_draft_large },
    { "draft_small",		XC_draft_small },
    { "draped_box",		XC_draped_box },
    { "exchange",		XC_exchange },
    { "fleur",			XC_fleur },
    { "gobbler",		XC_gobbler },
    { "gumby",			XC_gumby },
    { "hand1",			XC_hand1 },
    { "hand2",			XC_hand2 },
    { "heart",			XC_heart },
    { "icon",			XC_icon },
    { "iron_cross",		XC_iron_cross },
    { "left_ptr",		XC_left_ptr },
    { "left_side",		XC_left_side },
    { "left_tee",		XC_left_tee },
    { "leftbutton",		XC_leftbutton },
    { "ll_angle",		XC_ll_angle },
    { "lr_angle",		XC_lr_angle },
    { "man",			XC_man },
    { "middlebutton",		XC_middlebutton },
    { "mouse",			XC_mouse },
    { "pencil",			XC_pencil },
    { "pirate",			XC_pirate },
    { "plus",			XC_plus },
    { "question_arrow",		XC_question_arrow },
    { "right_ptr",		XC_right_ptr },
    { "right_side",		XC_right_side },
    { "right_tee",		XC_right_tee },
    { "rightbutton",		XC_rightbutton },
    { "rtl_logo",		XC_rtl_logo },
    { "sailboat",		XC_sailboat },
    { "sb_down_arrow",		XC_sb_down_arrow },
    { "sb_h_double_arrow",	XC_sb_h_double_arrow },
    { "sb_left_arrow",		XC_sb_left_arrow },
    { "sb_right_arrow",		XC_sb_right_arrow },
    { "sb_up_arrow",		XC_sb_up_arrow },
    { "sb_v_double_arrow",	XC_sb_v_double_arrow },
    { "shuttle",		XC_shuttle },
    { "sizing",			XC_sizing },
    { "spider",			XC_spider },
    { "spraycan",		XC_spraycan },
    { "star",			XC_star },
    { "target",			XC_target },
    { "tcross",			XC_tcross },
    { "top_left_arrow",		XC_top_left_arrow },
    { "top_left_corner",	XC_top_left_corner },
    { "top_right_corner",	XC_top_right_corner },
    { "top_side",		XC_top_side },
    { "top_tee",		XC_top_tee },
    { "trek",			XC_trek },
    { "ul_angle",		XC_ul_angle },
    { "umbrella",		XC_umbrella },
    { "ur_angle",		XC_ur_angle },
    { "watch",			XC_watch },
    { "xterm",			XC_xterm },
    { NULL,			CURSOR_ID_NONE }
};

static void
check_bitmap_status(int status, char *filename, Pixmap bitmap)
{
    switch(status) {
    case BitmapOpenFailed:
        wwarning(_("failed to open bitmap file \"%s\""), filename);
        break;
    case BitmapFileInvalid:
        wwarning(_("\"%s\" is not a valid bitmap file"), filename);
        break;
    case BitmapNoMemory:
        wwarning(_("out of memory reading bitmap file \"%s\""), filename);
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
static int
parse_cursor(WScreen *scr, WMPropList *pl, Cursor *cursor)
{
    WMPropList *elem;
    char *val;
    int nelem;
    int status = 0;

    nelem = WMGetPropListItemCount(pl);
    if (nelem < 1) {
        return(status);
    }
    elem = WMGetFromPLArray(pl, 0);
    if (!elem || !WMIsPLString(elem)) {
        return(status);
    }
    val = WMGetFromPLString(elem);

    if (0 == strcasecmp(val, "none")) {
        status = 1;
        *cursor = None;
    } else if (0 == strcasecmp(val, "builtin")) {
        int i;
        int cursor_id = CURSOR_ID_NONE;

        if (2 != nelem) {
            wwarning(_("bad number of arguments in cursor specification"));
            return(status);
        }
        elem = WMGetFromPLArray(pl, 1);
        if (!elem || !WMIsPLString(elem)) {
            return(status);
        }
        val = WMGetFromPLString(elem);

        for (i = 0; NULL != cursor_table[i].name; i++) {
            if (0 == strcasecmp(val, cursor_table[i].name)) {
                cursor_id = cursor_table[i].id;
                break;
            }
        }
        if (CURSOR_ID_NONE == cursor_id) {
            wwarning(_("unknown builtin cursor name \"%s\""), val);
        } else {
            *cursor = XCreateFontCursor(dpy, cursor_id);
            status = 1;
        }
    } else if (0 == strcasecmp(val, "bitmap")) {
        char *bitmap_name;
        char *mask_name;
        int bitmap_status;
        int mask_status;
        Pixmap bitmap;
        Pixmap mask;
        unsigned int w, h;
        int x, y;
        XColor fg, bg;

        if (3 != nelem) {
            wwarning(_("bad number of arguments in cursor specification"));
            return(status);
        }
        elem = WMGetFromPLArray(pl, 1);
        if (!elem || !WMIsPLString(elem)) {
            return(status);
        }
        val = WMGetFromPLString(elem);
        bitmap_name = FindImage(wPreferences.pixmap_path, val);
        if (!bitmap_name) {
            wwarning(_("could not find cursor bitmap file \"%s\""), val);
            return(status);
        }
        elem = WMGetFromPLArray(pl, 2);
        if (!elem || !WMIsPLString(elem)) {
            wfree(bitmap_name);
            return(status);
        }
        val = WMGetFromPLString(elem);
        mask_name = FindImage(wPreferences.pixmap_path, val);
        if (!mask_name) {
            wfree(bitmap_name);
            wwarning(_("could not find cursor bitmap file \"%s\""), val);
            return(status);
        }
        mask_status = XReadBitmapFile(dpy, scr->w_win, mask_name, &w, &h,
                                      &mask, &x, &y);
        bitmap_status = XReadBitmapFile(dpy, scr->w_win, bitmap_name, &w, &h,
                                        &bitmap, &x, &y);
        if ((BitmapSuccess == bitmap_status) &&
            (BitmapSuccess == mask_status)) {
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
    }
    return(status);
}


static int
getCursor(WScreen *scr, WDefaultEntry *entry, WMPropList *value, void *addr,
          void **ret)
{
    static Cursor cursor;
    int status;
    int changed = 0;

again:
    if (!WMIsPLArray(value)) {
        wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                 entry->key, "cursor specification");
        if (!changed) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return(False);
    }
    status = parse_cursor(scr, value, &cursor);
    if (!status) {
        wwarning(_("Error in cursor specification for key \"%s\""), entry->key);
        if (!changed) {
            value = entry->plvalue;
            changed = 1;
            wwarning(_("using default \"%s\" instead"), entry->default_value);
            goto again;
        }
        return(False);
    }
    if (ret) {
        *ret = &cursor;
    }
    if (addr) {
        *(Cursor *)addr = cursor;
    }
    return(True);
}
#undef CURSOR_ID_NONE


/* ---------------- value setting functions --------------- */
static int
setJustify(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    return REFRESH_WINDOW_TITLE_COLOR;
}

static int
setClearance(WScreen *scr, WDefaultEntry *entry, void *bar, void *foo)
{
    return REFRESH_WINDOW_FONT|REFRESH_BUTTON_IMAGES|REFRESH_MENU_TITLE_FONT|REFRESH_MENU_FONT;
}

static int
setIfDockPresent(WScreen *scr, WDefaultEntry *entry, char *flag, long which)
{
    switch (which) {
    case WM_DOCK:
        wPreferences.flags.nodock = wPreferences.flags.nodock || *flag;
        break;
    case WM_CLIP:
        wPreferences.flags.noclip = wPreferences.flags.noclip || *flag;
        break;
    default:
        break;
    }
    return 0;
}


static int
setStickyIcons(WScreen *scr, WDefaultEntry *entry, void *bar, void *foo)
{
    if (scr->workspaces) {
        wWorkspaceForceChange(scr, scr->current_workspace);
        wArrangeIcons(scr, False);
    }
    return 0;
}

#if not_used
static int
setPositive(WScreen *scr, WDefaultEntry *entry, int *value, void *foo)
{
    if (*value <= 0)
        *(int*)foo = 1;

    return 0;
}
#endif



static int
setIconTile(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    Pixmap pixmap;
    RImage *img;
    int reset = 0;

    img = wTextureRenderImage(*texture, wPreferences.icon_size,
                              wPreferences.icon_size,
                              ((*texture)->any.type & WREL_BORDER_MASK)
                              ? WREL_ICON : WREL_FLAT);
    if (!img) {
        wwarning(_("could not render texture for icon background"));
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


    if (!wPreferences.flags.noclip) {
        if (scr->clip_tile) {
            RReleaseImage(scr->clip_tile);
        }
        scr->clip_tile = wClipMakeTile(scr, img);
    }

    scr->icon_tile_pixmap = pixmap;

    if (scr->def_icon_pixmap) {
        XFreePixmap(dpy, scr->def_icon_pixmap);
        scr->def_icon_pixmap = None;
    }
    if (scr->def_ticon_pixmap) {
        XFreePixmap(dpy, scr->def_ticon_pixmap);
        scr->def_ticon_pixmap = None;
    }

    if (scr->icon_back_texture) {
        wTextureDestroy(scr, (WTexture*)scr->icon_back_texture);
    }
    scr->icon_back_texture = wTextureMakeSolid(scr, &((*texture)->any.color));

    if (scr->clip_balloon)
        XSetWindowBackground(dpy, scr->clip_balloon,
                             (*texture)->any.color.pixel);

    /*
     * Free the texture as nobody else will use it, nor refer to it.
     */
    if (!entry->addr)
        wTextureDestroy(scr, *texture);

    return (reset ? REFRESH_ICON_TILE : 0);
}



static int
setWinTitleFont(WScreen *scr, WDefaultEntry *entry, WMFont *font, void *foo)
{
    if (scr->title_font) {
        WMReleaseFont(scr->title_font);
    }
    scr->title_font = font;

    return REFRESH_WINDOW_FONT|REFRESH_BUTTON_IMAGES;
}


static int
setMenuTitleFont(WScreen *scr, WDefaultEntry *entry, WMFont *font, void *foo)
{
    if (scr->menu_title_font) {
        WMReleaseFont(scr->menu_title_font);
    }

    scr->menu_title_font = font;

    return REFRESH_MENU_TITLE_FONT;
}


static int
setMenuTextFont(WScreen *scr, WDefaultEntry *entry, WMFont *font, void *foo)
{
    if (scr->menu_entry_font) {
        WMReleaseFont(scr->menu_entry_font);
    }
    scr->menu_entry_font = font;

    return REFRESH_MENU_FONT;
}



static int
setIconTitleFont(WScreen *scr, WDefaultEntry *entry, WMFont *font, void *foo)
{
    if (scr->icon_title_font) {
        WMReleaseFont(scr->icon_title_font);
    }

    scr->icon_title_font = font;

    return REFRESH_ICON_FONT;
}


static int
setClipTitleFont(WScreen *scr, WDefaultEntry *entry, WMFont *font, void *foo)
{
    if (scr->clip_title_font) {
        WMReleaseFont(scr->clip_title_font);
    }

    scr->clip_title_font = font;

    return REFRESH_ICON_FONT;
}


static int
setLargeDisplayFont(WScreen *scr, WDefaultEntry *entry, WMFont *font, void *foo)
{
    if (scr->workspace_name_font) {
        WMReleaseFont(scr->workspace_name_font);
    }

    scr->workspace_name_font = font;

    return 0;
}


static int
setHightlight(WScreen *scr, WDefaultEntry *entry, XColor *color, void *foo)
{
    if (scr->select_color)
        WMReleaseColor(scr->select_color);

    scr->select_color =
        WMCreateRGBColor(scr->wmscreen, color->red, color->green,
                         color->blue, True);

    wFreeColor(scr, color->pixel);

    return REFRESH_MENU_COLOR;
}


static int
setHightlightText(WScreen *scr, WDefaultEntry *entry, XColor *color, void *foo)
{
    if (scr->select_text_color)
        WMReleaseColor(scr->select_text_color);

    scr->select_text_color =
        WMCreateRGBColor(scr->wmscreen, color->red, color->green,
                         color->blue, True);

    wFreeColor(scr, color->pixel);

    return REFRESH_MENU_COLOR;
}


static int
setClipTitleColor(WScreen *scr, WDefaultEntry *entry, XColor *color, long index)
{
    if (scr->clip_title_color[index])
        WMReleaseColor(scr->clip_title_color[index]);
    scr->clip_title_color[index] = WMCreateRGBColor(scr->wmscreen, color->red,
                                                    color->green, color->blue,
                                                    True);
#ifdef GRADIENT_CLIP_ARROW
    if (index == CLIP_NORMAL) {
        RImage *image;
        RColor color1, color2;
        int pt = CLIP_BUTTON_SIZE*wPreferences.icon_size/64;
        int as = pt - 15; /* 15 = 5+5+5 */

        FREE_PIXMAP(scr->clip_arrow_gradient);

        color1.red = (color->red >> 8)*6/10;
        color1.green = (color->green >> 8)*6/10;
        color1.blue = (color->blue >> 8)*6/10;

        color2.red = WMIN((color->red >> 8)*20/10, 255);
        color2.green = WMIN((color->green >> 8)*20/10, 255);
        color2.blue = WMIN((color->blue >> 8)*20/10, 255);

        image = RRenderGradient(as+1, as+1, &color1, &color2, RDiagonalGradient);
        RConvertImage(scr->rcontext, image, &scr->clip_arrow_gradient);
        RReleaseImage(image);
    }
#endif /* GRADIENT_CLIP_ARROW */

    wFreeColor(scr, color->pixel);

    return REFRESH_ICON_TITLE_COLOR;
}


static int
setWTitleColor(WScreen *scr, WDefaultEntry *entry, XColor *color, long index)
{
    if (scr->window_title_color[index])
        WMReleaseColor(scr->window_title_color[index]);

    scr->window_title_color[index] =
        WMCreateRGBColor(scr->wmscreen, color->red, color->green, color->blue,
                         True);

    wFreeColor(scr, color->pixel);

    return REFRESH_WINDOW_TITLE_COLOR;
}


static int
setMenuTitleColor(WScreen *scr, WDefaultEntry *entry, XColor *color, long index)
{
    if (scr->menu_title_color[0])
        WMReleaseColor(scr->menu_title_color[0]);

    scr->menu_title_color[0] =
        WMCreateRGBColor(scr->wmscreen, color->red, color->green,
                         color->blue, True);

    wFreeColor(scr, color->pixel);

    return REFRESH_MENU_TITLE_COLOR;
}


static int
setMenuTextColor(WScreen *scr, WDefaultEntry *entry, XColor *color, void *foo)
{
    if (scr->mtext_color)
        WMReleaseColor(scr->mtext_color);

    scr->mtext_color = WMCreateRGBColor(scr->wmscreen, color->red,
                                        color->green, color->blue, True);

    if (WMColorPixel(scr->dtext_color) == WMColorPixel(scr->mtext_color)) {
        WMSetColorAlpha(scr->dtext_color, 0x7fff);
    } else {
        WMSetColorAlpha(scr->dtext_color, 0xffff);
    }

    wFreeColor(scr, color->pixel);

    return REFRESH_MENU_COLOR;
}


static int
setMenuDisabledColor(WScreen *scr, WDefaultEntry *entry, XColor *color, void *foo)
{
    if (scr->dtext_color)
        WMReleaseColor(scr->dtext_color);

    scr->dtext_color = WMCreateRGBColor(scr->wmscreen, color->red,
                                        color->green, color->blue, True);

    if (WMColorPixel(scr->dtext_color) == WMColorPixel(scr->mtext_color)) {
        WMSetColorAlpha(scr->dtext_color, 0x7fff);
    } else {
        WMSetColorAlpha(scr->dtext_color, 0xffff);
    }

    wFreeColor(scr, color->pixel);

    return REFRESH_MENU_COLOR;
}


static int
setIconTitleColor(WScreen *scr, WDefaultEntry *entry, XColor *color, void *foo)
{
    if (scr->icon_title_color)
        WMReleaseColor(scr->icon_title_color);
    scr->icon_title_color = WMCreateRGBColor(scr->wmscreen, color->red,
                                             color->green, color->blue,
                                             True);

    wFreeColor(scr, color->pixel);

    return REFRESH_ICON_TITLE_COLOR;
}


static int
setIconTitleBack(WScreen *scr, WDefaultEntry *entry, XColor *color, void *foo)
{
    if (scr->icon_title_texture) {
        wTextureDestroy(scr, (WTexture*)scr->icon_title_texture);
    }
    scr->icon_title_texture = wTextureMakeSolid(scr, color);

    return REFRESH_ICON_TITLE_BACK;
}


static void
trackDeadProcess(pid_t pid, unsigned char status, WScreen *scr)
{
    close(scr->helper_fd);
    scr->helper_fd = 0;
    scr->helper_pid = 0;
    scr->flags.backimage_helper_launched = 0;
}


static int
setWorkspaceSpecificBack(WScreen *scr, WDefaultEntry *entry, WMPropList *value,
                         void *bar)
{
    WMPropList *val;
    char *str;
    int i;

    if (scr->flags.backimage_helper_launched) {
        if (WMGetPropListItemCount(value)==0) {
            SendHelperMessage(scr, 'C', 0, NULL);
            SendHelperMessage(scr, 'K', 0, NULL);

            WMReleasePropList(value);
            return 0;
        }
    } else {
        pid_t pid;
        int filedes[2];

        if (WMGetPropListItemCount(value) == 0)
            return 0;

        if (pipe(filedes) < 0) {
            wsyserror("pipe() failed:can't set workspace specific background image");

            WMReleasePropList(value);
            return 0;
        }

        pid = fork();
        if (pid < 0) {
            wsyserror("fork() failed:can't set workspace specific background image");
            if (close(filedes[0]) < 0)
                wsyserror("could not close pipe");
            if (close(filedes[1]) < 0)
                wsyserror("could not close pipe");

        } else if (pid == 0) {
            char *dither;

            SetupEnvironment(scr);

            if (close(0) < 0)
                wsyserror("could not close pipe");
            if (dup(filedes[0]) < 0) {
                wsyserror("dup() failed:can't set workspace specific background image");
            }
            dither = wPreferences.no_dithering ? "-m" : "-d";
            if (wPreferences.smooth_workspace_back)
                execlp("wmsetbg", "wmsetbg", "-helper", "-S", dither, NULL);
            else
                execlp("wmsetbg", "wmsetbg", "-helper", dither, NULL);
            wsyserror("could not execute wmsetbg");
            exit(1);
        } else {

            if (fcntl(filedes[0], F_SETFD, FD_CLOEXEC) < 0) {
                wsyserror("error setting close-on-exec flag");
            }
            if (fcntl(filedes[1], F_SETFD, FD_CLOEXEC) < 0) {
                wsyserror("error setting close-on-exec flag");
            }

            scr->helper_fd = filedes[1];
            scr->helper_pid = pid;
            scr->flags.backimage_helper_launched = 1;

            wAddDeathHandler(pid, (WDeathHandler*)trackDeadProcess, scr);

            SendHelperMessage(scr, 'P', -1, wPreferences.pixmap_path);
        }

    }

    for (i = 0; i < WMGetPropListItemCount(value); i++) {
        val = WMGetFromPLArray(value, i);
        if (val && WMIsPLArray(val) && WMGetPropListItemCount(val)>0) {
            str = WMGetPropListDescription(val, False);

            SendHelperMessage(scr, 'S', i+1, str);

            wfree(str);
        } else {
            SendHelperMessage(scr, 'U', i+1, NULL);
        }
    }
    sleep(1);

    WMReleasePropList(value);
    return 0;
}


static int
setWorkspaceBack(WScreen *scr, WDefaultEntry *entry, WMPropList *value,
                 void *bar)
{
    if (scr->flags.backimage_helper_launched) {
        char *str;

        if (WMGetPropListItemCount(value)==0) {
            SendHelperMessage(scr, 'U', 0, NULL);
        } else {
            /* set the default workspace background to this one */
            str = WMGetPropListDescription(value, False);
            if (str) {
                SendHelperMessage(scr, 'S', 0, str);
                wfree(str);
                SendHelperMessage(scr, 'C', scr->current_workspace+1, NULL);
            } else {
                SendHelperMessage(scr, 'U', 0, NULL);
            }
        }
    } else if (WMGetPropListItemCount(value) > 0) {
        char *command;
        char *text;
        char *dither;
        int len;

        SetupEnvironment(scr);
        text = WMGetPropListDescription(value, False);
        len = strlen(text)+40;
        command = wmalloc(len);
        dither = wPreferences.no_dithering ? "-m" : "-d";
        if (wPreferences.smooth_workspace_back)
            snprintf(command, len, "wmsetbg %s -S -p '%s' &", dither, text);
        else
            snprintf(command, len, "wmsetbg %s -p '%s' &", dither, text);
        wfree(text);
        system(command);
        wfree(command);
    }
    WMReleasePropList(value);

    return 0;
}


#ifdef VIRTUAL_DESKTOP
static int
setVirtualDeskEnable(WScreen *scr, WDefaultEntry *entry, void *foo, void *bar)
{
    wWorkspaceUpdateEdge(scr);
    return 0;
}
#endif


static int
setWidgetColor(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    if (scr->widget_texture) {
        wTextureDestroy(scr, (WTexture*)scr->widget_texture);
    }
    scr->widget_texture = *(WTexSolid**)texture;

    return 0;
}


static int
setFTitleBack(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    if (scr->window_title_texture[WS_FOCUSED]) {
        wTextureDestroy(scr, scr->window_title_texture[WS_FOCUSED]);
    }
    scr->window_title_texture[WS_FOCUSED] = *texture;

    return REFRESH_WINDOW_TEXTURES;
}


static int
setPTitleBack(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    if (scr->window_title_texture[WS_PFOCUSED]) {
        wTextureDestroy(scr, scr->window_title_texture[WS_PFOCUSED]);
    }
    scr->window_title_texture[WS_PFOCUSED] = *texture;

    return REFRESH_WINDOW_TEXTURES;
}


static int
setUTitleBack(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    if (scr->window_title_texture[WS_UNFOCUSED]) {
        wTextureDestroy(scr, scr->window_title_texture[WS_UNFOCUSED]);
    }
    scr->window_title_texture[WS_UNFOCUSED] = *texture;

    return REFRESH_WINDOW_TEXTURES;
}


static int
setResizebarBack(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    if (scr->resizebar_texture[0]) {
        wTextureDestroy(scr, scr->resizebar_texture[0]);
    }
    scr->resizebar_texture[0] = *texture;

    return REFRESH_WINDOW_TEXTURES;
}


static int
setMenuTitleBack(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    if (scr->menu_title_texture[0]) {
        wTextureDestroy(scr, scr->menu_title_texture[0]);
    }
    scr->menu_title_texture[0] = *texture;

    return REFRESH_MENU_TITLE_TEXTURE;
}


static int
setMenuTextBack(WScreen *scr, WDefaultEntry *entry, WTexture **texture, void *foo)
{
    if (scr->menu_item_texture) {
        wTextureDestroy(scr, scr->menu_item_texture);
        wTextureDestroy(scr, (WTexture*)scr->menu_item_auxtexture);
    }
    scr->menu_item_texture = *texture;

    scr->menu_item_auxtexture
        = wTextureMakeSolid(scr, &scr->menu_item_texture->any.color);

    return REFRESH_MENU_TEXTURE;
}


static int
setKeyGrab(WScreen *scr, WDefaultEntry *entry, WShortKey *shortcut, long index)
{
    WWindow *wwin;
    wKeyBindings[index] = *shortcut;

    wwin = scr->focused_window;

    while (wwin!=NULL) {
        XUngrabKey(dpy, AnyKey, AnyModifier, wwin->frame->core->window);

        if (!WFLAGP(wwin, no_bind_keys)) {
            wWindowSetKeyGrabs(wwin);
        }
        wwin = wwin->prev;
    }

    return 0;
}


static int
setIconPosition(WScreen *scr, WDefaultEntry *entry, void *bar, void *foo)
{
    wScreenUpdateUsableArea(scr);
    wArrangeIcons(scr, True);

    return 0;
}


static int
updateUsableArea(WScreen *scr, WDefaultEntry *entry, void *bar, void *foo)
{
    wScreenUpdateUsableArea(scr);

    return 0;
}


static int
setMenuStyle(WScreen *scr, WDefaultEntry *entry, int *value, void *foo)
{
    return REFRESH_MENU_TEXTURE;
}


static RImage *chopOffImage(RImage *image, int x, int y, int w, int h)
{
    RImage *img= RCreateImage(w, h, image->format == RRGBAFormat);
    
    RCopyArea(img, image, x, y, w, h, 0, 0);
    
    return img;
}

static int
setSwPOptions(WScreen *scr, WDefaultEntry *entry, WMPropList *array, void *foo)
{
    char *path;
    RImage *bgimage;
    int cwidth, cheight;
    WPreferences *prefs= (WPreferences*)foo;

    if (!WMIsPLArray(array) || WMGetPropListItemCount(array)==0) {
        if (prefs->swtileImage) RReleaseImage(prefs->swtileImage);
        prefs->swtileImage= NULL;
 
        WMReleasePropList(array);
        return 0;
    }

    switch (WMGetPropListItemCount(array))
    {
    case 4:
        if (!WMIsPLString(WMGetFromPLArray(array, 1))) {
            wwarning(_("Invalid arguments for option \"%s\""),
                     entry->key);
            break;
        } else
          path= FindImage(wPreferences.pixmap_path, WMGetFromPLString(WMGetFromPLArray(array, 1)));

        if (!path) {
            wwarning(_("Could not find image \"%s\" for option \"%s\""), 
                     WMGetFromPLString(WMGetFromPLArray(array, 1)),
                     entry->key);
        } else {
            bgimage= RLoadImage(scr->rcontext, path, 0);
            if (!bgimage) {
                wwarning(_("Could not load image \"%s\" for option \"%s\""), 
                         path, entry->key);
                wfree(path);
            } else {
                wfree(path);
            
                cwidth= atoi(WMGetFromPLString(WMGetFromPLArray(array, 2)));
                cheight= atoi(WMGetFromPLString(WMGetFromPLArray(array, 3)));

                if (cwidth <= 0 || cheight <= 0 ||
                    cwidth >= bgimage->width - 2 ||
                    cheight >= bgimage->height - 2)
                    wwarning(_("Invalid split sizes for SwitchPanel back image."));
                else {
                    int i;
                    int swidth, theight;
                    for (i= 0; i < 9; i++) {
                        if (prefs->swbackImage[i])
                          RReleaseImage(prefs->swbackImage[i]);
                        prefs->swbackImage[i]= NULL;
                    }
                    swidth= (bgimage->width - cwidth) / 2;
                    theight= (bgimage->height - cheight) / 2;

                    prefs->swbackImage[0]= chopOffImage(bgimage, 0, 0,
                                                        swidth, theight);
                    prefs->swbackImage[1]= chopOffImage(bgimage, swidth, 0,
                                                        cwidth, theight);
                    prefs->swbackImage[2]= chopOffImage(bgimage, swidth+cwidth, 0,
                                                        swidth, theight);

                    prefs->swbackImage[3]= chopOffImage(bgimage, 0, theight,
                                                        swidth, cheight);
                    prefs->swbackImage[4]= chopOffImage(bgimage, swidth, theight,
                                                        cwidth, cheight);
                    prefs->swbackImage[5]= chopOffImage(bgimage, swidth+cwidth, theight,
                                                        swidth, cheight);

                    prefs->swbackImage[6]= chopOffImage(bgimage, 0, theight+cheight,
                                                        swidth, theight);
                    prefs->swbackImage[7]= chopOffImage(bgimage, swidth, theight+cheight,
                                                        cwidth, theight);
                    prefs->swbackImage[8]= chopOffImage(bgimage, swidth+cwidth, theight+cheight,
                                                        swidth, theight);

                    // check if anything failed
                    for (i= 0; i < 9; i++) {
                        if (!prefs->swbackImage[i]) {
                            for (; i>=0; --i) {
                                RReleaseImage(prefs->swbackImage[i]);
                                prefs->swbackImage[i]= NULL;
                            }
                            break;
                        }
                    }
                }
                RReleaseImage(bgimage);
            }
        }

    case 1:
        if (!WMIsPLString(WMGetFromPLArray(array, 0))) {
            wwarning(_("Invalid arguments for option \"%s\""),
                     entry->key);
            break;
        } else
          path= FindImage(wPreferences.pixmap_path, WMGetFromPLString(WMGetFromPLArray(array, 0)));

        if (!path) {
            wwarning(_("Could not find image \"%s\" for option \"%s\""), 
                     WMGetFromPLString(WMGetFromPLArray(array, 0)),
                     entry->key);
        } else {
            if (prefs->swtileImage) RReleaseImage(prefs->swtileImage);

            prefs->swtileImage= RLoadImage(scr->rcontext, path, 0);
            if (!prefs->swtileImage) {
                wwarning(_("Could not load image \"%s\" for option \"%s\""), 
                         path, entry->key);
            }
            wfree(path);
        }
        break;

    default:
        wwarning(_("Invalid number of arguments for option \"%s\""),
                 entry->key);
        break;
    }

    WMReleasePropList(array);
        
    return 0;
}


/*
 static int
 setButtonImages(WScreen *scr, WDefaultEntry *entry, int *value, void *foo)
 {
 return REFRESH_BUTTON_IMAGES;
 }
 */

/*
 * Very ugly kluge.
 * Need access to the double click variables, so that all widgets in
 * wmaker panels will have the same dbl-click values.
 * TODO: figure a better way of dealing with it.
 */
#include <WINGs/WINGsP.h>

static int
setDoubleClick(WScreen *scr, WDefaultEntry *entry, int *value, void *foo)
{
    extern _WINGsConfiguration WINGsConfiguration;

    if (*value <= 0)
        *(int*)foo = 1;

    WINGsConfiguration.doubleClickDelay = *value;

    return 0;
}


static int
setCursor(WScreen *scr, WDefaultEntry *entry, Cursor *cursor, long index)
{
    if (wCursor[index] != None) {
        XFreeCursor(dpy, wCursor[index]);
    }

    wCursor[index] = *cursor;

    if (index==WCUR_ROOT && *cursor!=None) {
        XDefineCursor(dpy, scr->root_win, *cursor);
    }

    return 0;
}


