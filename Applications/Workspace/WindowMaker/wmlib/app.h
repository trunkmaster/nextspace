/* app.h - private declarations for application context
 *
 * WMlib - WindowMaker application programming interface
 *
 * Copyright (C) 1997-2003 Alfredo K. Kojima
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#ifndef _APP_H_
#define _APP_H_

typedef struct _wmAppContext {
    Display *dpy;
    int screen_number;

    int our_leader_hint;	       /* if app leader hint was set by us */
    Window main_window;		       /* main window of the application */
    Window *windows;
    int win_count;		       /* size of windows array */

    WMMenu *main_menu;

    int last_menu_tag;
} wmAppContext;

#endif

