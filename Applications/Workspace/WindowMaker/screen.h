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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#ifndef WMSCREEN_H_
#define WMSCREEN_H_

#include "wconfig.h"
#include "WindowMaker.h"
#include <sys/types.h>

#include <WINGs/WUtil.h>


#define WTB_LEFT	0
#define WTB_RIGHT	1

#define WTB_FOCUSED	0
#define WTB_UNFOCUSED	2
#define WTB_PFOCUSED	4
#define WTB_MENU 6



typedef struct {
    WMRect *screens;
    int count;                 /* screen count, 0 = inactive */
    int primary_head;	       /* main working screen */
} WXineramaInfo;



/* an area of the screen reserved by some window */
typedef struct WReservedArea {
    WArea area;
    Window window;
    struct WReservedArea *next;
} WReservedArea;


typedef struct WAppIconChain {
    struct WAppIcon *aicon;
    struct WAppIconChain *next;
} WAppIconChain;


/*
 * each WScreen is saved into a context associated with it's root window
 */
typedef struct _WScreen {
    int	screen;			       /* screen number */

#if 0
    Atom managerAtom;		       /* WM_Sn atom for manager selection */
    Window managerWindow;	       /* window for manager selection */
#endif
    Window info_window;		       /* for our window manager info stuff */

    int scr_width;		       /* size of the screen */
    int scr_height;

#ifdef VIRTUAL_DESKTOP
    int virtual_nr_edges;
    Window * virtual_edges;
#endif

    Window root_win;		       /* root window of screen */
    int  depth;			       /* depth of the default visual */
    Colormap colormap;		       /* root colormap */
    int root_colormap_install_count;
    struct WWindow *original_cmap_window; /* colormap before installing
                                           * root colormap temporarily */
    struct WWindow *cmap_window;
    Colormap current_colormap;

    Window w_win;		       /* window to use as drawable
                                        * for new GCs, pixmaps etc. */
    Visual *w_visual;
    int  w_depth;
    Colormap w_colormap;	       /* our colormap */

    WXineramaInfo xine_info;

    Window no_focus_win;	       /* window to get focus when nobody
                                        * else can do it */

    struct WWindow *focused_window;    /* window that has the focus
                                        * Use this list if you want to
                                        * traverse the entire window list
                                        */

    WMArray *selected_windows;

    WMArray *fakeGroupLeaders;         /* list of fake window group ids */

    struct WAppIcon *app_icon_list;    /* list of all app-icons on screen */

    struct WApplication *wapp_list;    /* list of all aplications */

    WMBag *stacking_list;	       /* bag of lists of windows
                                        * in stacking order.
                                        * Indexed by window level
                                        * and each list on the array
                                        * is ordered from the topmost to
                                        * the lowest window
                                        */

    int window_count;		       /* number of windows in window_list */

    int workspace_count;	       /* number of workspaces */

    struct WWorkspace **workspaces;    /* workspace array */

    int current_workspace;	       /* current workspace number */


    WReservedArea *reservedAreas;      /* used to build totalUsableArea */

    WArea *usableArea;		       /* area of the workspace where
                                        * we can put windows on, as defined
                                        * by other clients (not us) */
    WArea *totalUsableArea;	       /* same as above, but including
                                        * the dock and other stuff */

    WMColor *black;
    WMColor *white;
    WMColor *gray;
    WMColor *darkGray;

    /* shortcuts for the pixels of the above colors. just for convenience */
    WMPixel black_pixel;
    WMPixel white_pixel;
    WMPixel light_pixel;
    WMPixel dark_pixel;

    Pixmap stipple_bitmap;
    Pixmap transp_stipple;	       /* for making holes in icon masks for
                                        * transparent icon simulation */
    WMFont *title_font;		       /* default font for the titlebars */
    WMFont *menu_title_font;	       /* font for menu titlebars */
    WMFont *menu_entry_font;	       /* font for menu items */
    WMFont *icon_title_font;	       /* for icon titles */
    WMFont *clip_title_font;	       /* for clip titles */
    WMFont *info_text_font;	       /* text on things like geometry
                                        * hint boxes */

    XFontStruct *tech_draw_font;       /* font for tech draw style geom view
                                          needs to be a core font so we can
                                          use it with a XORing GC */

    WMFont *workspace_name_font;

    WMColor *select_color;
    WMColor *select_text_color;
    /* foreground colors */
    WMColor *window_title_color[3];    /* window titlebar text (foc, unfoc, pfoc)*/
    WMColor *menu_title_color[3];      /* menu titlebar text */
    WMColor *clip_title_color[2];      /* clip title text */
    WMColor *mtext_color;	       /* menu item text */
    WMColor *dtext_color;	       /* disabled menu item text */

    WMPixel line_pixel;
    WMPixel frame_border_pixel;	       /* frame border */


    union WTexture *menu_title_texture[3];/* menu titlebar texture (tex, -, -) */
    union WTexture *window_title_texture[3];  /* win textures (foc, unfoc, pfoc) */
    union WTexture *resizebar_texture[3];/* window resizebar texture (tex, -, -) */

    union WTexture *menu_item_texture; /* menu item texture */

    struct WTexSolid *menu_item_auxtexture; /* additional texture to draw menu
    * cascade arrows */
    struct WTexSolid *icon_title_texture;/* icon titles */

    struct WTexSolid *widget_texture;

    struct WTexSolid *icon_back_texture; /* icon back color for shadowing */


    WMColor *icon_title_color;	       /* icon title color */

    GC icon_select_gc;

    GC frame_gc;		       /* gc for resize/move frame (root) */
    GC line_gc;			       /* gc for drawing XORed lines (root) */
    GC copy_gc;			       /* gc for XCopyArea() */
    GC stipple_gc;		       /* gc for stippled filling */
    GC draw_gc;			       /* gc for drawing misc things */
    GC mono_gc;			       /* gc for 1 bit drawables */

#ifndef NEWSTUFF
    struct WPixmap *b_pixmaps[PRED_BPIXMAPS]; /* internal pixmaps for buttons*/
#endif
    struct WPixmap *menu_radio_indicator;/* left menu indicator */
    struct WPixmap *menu_check_indicator;/* left menu indicator for checkmark */
    struct WPixmap *menu_mini_indicator;   /* for miniwindow */
    struct WPixmap *menu_hide_indicator;   /* for hidden window */
    struct WPixmap *menu_shade_indicator;  /* for shaded window */
    int app_menu_x, app_menu_y;	       /* position for application menus */

#ifndef LITE
    struct WMenu *root_menu;	       /* root window menu */
    struct WMenu *switch_menu;	       /* window list menu */
#endif
    struct WMenu *workspace_menu;      /* workspace operation */
    struct WMenu *window_menu;	       /* window command menu */
    struct WMenu *icon_menu;	       /* icon/appicon menu */
    struct WMenu *workspace_submenu;   /* workspace list for window_menu */

    struct WDock *dock;		       /* the application dock */
    struct WPixmap *dock_dots;	       /* 3 dots for the Dock */
    Window dock_shadow;		       /* shadow for dock buttons */
    struct WAppIcon *clip_icon;        /* The clip main icon */
    struct WMenu *clip_menu;           /* Menu for clips */
    struct WMenu *clip_submenu;        /* Workspace list for clips */
    struct WMenu *clip_options;	       /* Options for Clip */
    struct WMenu *clip_ws_menu;	       /* workspace menu for clip */
    struct WDock *last_dock;
    WAppIconChain *global_icons;       /* for omnipresent icons chain in clip */
    int global_icon_count;	       /* How many global icons do we have */

    Window clip_balloon;	       /* window for workspace name */

    int keymove_tick;

#ifdef GRADIENT_CLIP_ARROW
    Pixmap clip_arrow_gradient;
#endif

    struct RContext *rcontext;	       /* wrlib context */

    WMScreen *wmscreen;		       /* for widget library */

    struct RImage *icon_tile;
    struct RImage *clip_tile;
    Pixmap icon_tile_pixmap;	       /* for app supplied icons */

    Pixmap def_icon_pixmap;	       /* default icons */
    Pixmap def_ticon_pixmap;

    struct WDialogData *dialog_data;


    struct W_GeometryView *gview;      /* size/position view */

#ifdef NEWSTUFF
    struct RImage *button_images[2][PRED_BPIXMAPS];/* scaled tbar btn images */
#endif

    /* state and other informations */
    short cascade_index;	       /* for cascade window placement */

    WMPropList *session_state;

    /* for double-click detection */
    Time last_click_time;
    Window last_click_window;
    int last_click_button;

    /* balloon help data */
    struct _WBalloon *balloon;

    /* workspace name data */
    Window workspace_name;
    WMHandlerID *workspace_name_timer;
    struct WorkspaceNameData *workspace_name_data;

    /* for raise-delay */
    WMHandlerID *autoRaiseTimer;
    Window autoRaiseWindow;	       /* window that is scheduled to be
                                        * raised */

    /* for window shortcuts */
    WMArray *shortcutWindows[MAX_WINDOW_SHORTCUTS];

#ifdef XDND
    char *xdestring;
#endif

#ifdef NETWM_HINTS
    struct NetData *netdata;
#endif

    int helper_fd;
    pid_t helper_pid;

    struct {
        unsigned int startup:1;	       /* during window manager startup */
        unsigned int regenerate_icon_textures:1;
        unsigned int dnd_data_convertion_status:1;
        unsigned int root_menu_changed_shortcuts:1;
        unsigned int added_workspace_menu:1;
        unsigned int added_windows_menu:1;
        unsigned int startup2:1;       /* startup phase 2 */
        unsigned int supports_tiff:1;
        unsigned int clip_balloon_mapped:1;
        unsigned int next_click_is_not_double:1;
        unsigned int backimage_helper_launched:1;
        /* some client has issued a WM_COLORMAP_NOTIFY */
        unsigned int colormap_stuff_blocked:1;
        unsigned int doing_alt_tab:1;
        unsigned int jump_back_pending:1;
        unsigned int ignore_focus_events:1;
    } flags;
} WScreen;



WScreen *wScreenInit(int screen_number);
void wScreenSaveState(WScreen *scr);
void wScreenRestoreState(WScreen *scr);

int wScreenBringInside(WScreen *scr, int *x, int *y, int width, int height);
int wScreenKeepInside(WScreen *scr, int *x, int *y, int width, int height);


/* in startup.c */
WScreen *wScreenWithNumber(int i);
WScreen *wScreenForRootWindow(Window window);   /* window must be valid */
WScreen *wScreenSearchForRootWindow(Window window);
WScreen *wScreenForWindow(Window window);   /* slower than above functions */

void wScreenFinish(WScreen *scr);

void wScreenUpdateUsableArea(WScreen *scr);

#endif
