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


#ifndef WMAPPLICATION_H_
#define WMAPPLICATION_H_

/* for tracking single application instances */
typedef struct WApplication {
    struct WApplication *next;
    struct WApplication *prev;

    Window main_window;		       /* ID of the group leader */

    struct WWindow *main_window_desc;  /* main (leader) window descriptor */

    WMenu *menu;		       /* application menu */

    struct WAppIcon *app_icon;

    int refcount;

    struct WWindow *last_focused;      /* focused window before hide */

    int last_workspace;		       /* last workspace used to work on the
                                        * app */
    struct {
        unsigned int skip_next_animation:1;
        unsigned int hidden:1;
        unsigned int emulated:1;
    } flags;
} WApplication;


WApplication *wApplicationCreate(struct WWindow *wwin);
void wApplicationDestroy(WApplication *wapp);

WApplication *wApplicationOf(Window window);

void wApplicationExtractDirPackIcon(WScreen *scr,char *path, char *wm_instance,
                                    char *wm_class);

#ifdef NEWAPPICON

# define wApplicationActivate(wapp)	{\
    wapp->main_window_desc->flags.focused=1; \
    wAppIconPaint(wapp->app_icon);\
    }
#define wApplicationDeactivate(wapp)	{\
    wapp->main_window_desc->flags.focused=0;\
    wAppIconPaint(wapp->app_icon);\
    }
#endif

#endif

