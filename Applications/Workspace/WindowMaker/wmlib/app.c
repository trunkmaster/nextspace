/* app.c - application context stuff
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

#include <X11/Xlib.h>
#include <stdlib.h>
#include <string.h>

#include "WMaker.h"
#include "app.h"

WMAppContext *WMAppCreateWithMain(Display * display, int screen_number, Window main_window)
{
	wmAppContext *ctx;

	ctx = malloc(sizeof(wmAppContext));
	if (!ctx)
		return NULL;

	ctx->dpy = display;
	ctx->screen_number = screen_number;
	ctx->our_leader_hint = False;
	ctx->main_window = main_window;
	ctx->windows = malloc(sizeof(Window));
	if (!ctx->windows) {
		free(ctx);
		return NULL;
	}
	ctx->win_count = 1;
	ctx->windows[0] = main_window;

	ctx->main_menu = NULL;

	ctx->last_menu_tag = 100;

	return ctx;
}

int WMAppAddWindow(WMAppContext * app, Window window)
{
	Window *win;

	win = malloc(sizeof(Window) * (app->win_count + 1));
	if (!win)
		return False;

	memcpy(win, app->windows, sizeof(Window) * app->win_count);

	free(app->windows);

	win[app->win_count] = window;
	app->windows = win;
	app->win_count++;

	return True;
}

int WMAppSetMainMenu(WMAppContext * app, WMMenu * menu)
{
	app->main_menu = menu;
	return True;
}
