/* menu.c - menu interface functions
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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include "WMaker.h"
#include "app.h"
#include "menu.h"

WMMenu *WMMenuCreate(WMAppContext * app, char *title)
{
	wmMenu *menu;

	if (strlen(title) > 255)
		return NULL;

	menu = malloc(sizeof(wmMenu));
	if (!menu)
		return NULL;

	menu->appcontext = app;
	menu->parent = NULL;
	menu->title = title;
	menu->entries = NULL;
	menu->first = NULL;

	menu->realized = False;
	menu->code = app->last_menu_tag++;

	menu->entryline = malloc(strlen(title) + 32);
	menu->entryline2 = malloc(32);
	if (!menu->entryline || !menu->entryline2) {
		if (menu->entryline)
			free(menu->entryline);
		free(menu);
		return NULL;
	}
	sprintf(menu->entryline, "%i %i %s", wmBeginMenu, menu->code, title);
	sprintf(menu->entryline2, "%i %i", wmEndMenu, menu->code);
	return menu;
}

int
WMMenuAddItem(WMMenu * menu, char *text, WMMenuAction action,
	      void *clientData, WMFreeFunction freedata, char *rtext)
{
	wmMenuEntry *entry;

	/* max size of right side text */
	if (rtext && strlen(rtext) > 4)
		return -1;

	/* max size of menu text */
	if (strlen(text) > 255)
		return -1;

	entry = malloc(sizeof(wmMenuEntry));
	if (!entry)
		return -1;

	entry->entryline = malloc(strlen(text) + 100);
	if (!entry->entryline) {
		free(entry);
		return -1;
	}

	if (menu->entries)
		entry->order = menu->entries->order + 1;
	else {
		entry->order = 0;
		menu->first = entry;
	}
	entry->next = NULL;
	entry->prev = menu->entries;
	if (menu->entries)
		menu->entries->next = entry;
	menu->entries = entry;

	entry->menu = menu;
	entry->text = text;
	entry->shortcut = rtext;
	entry->callback = action;
	entry->clientData = clientData;
	entry->free = freedata;
	entry->tag = menu->appcontext->last_menu_tag++;
	entry->cascade = NULL;
	entry->enabled = True;

	if (!rtext)
		sprintf(entry->entryline, "%i %i %i %i %s", wmNormalItem, menu->code, entry->tag, True, text);
	else
		sprintf(entry->entryline, "%i %i %i %i %s %s", wmDoubleItem,
			menu->code, entry->tag, True, rtext, text);
	return entry->tag;
}

int WMMenuAddSubmenu(WMMenu * menu, char *text, WMMenu * submenu)
{
	wmMenuEntry *entry;

	/* max size of menu text */
	if (strlen(text) > 255)
		return -1;

	entry = malloc(sizeof(wmMenuEntry));
	if (!entry)
		return -1;

	entry->entryline = malloc(strlen(text) + 100);
	if (!entry->entryline) {
		free(entry);
		return -1;
	}

	if (menu->entries)
		entry->order = menu->entries->order + 1;
	else {
		entry->order = 0;
		menu->first = entry;
	}
	entry->next = NULL;
	entry->prev = menu->entries;
	if (menu->entries)
		menu->entries->next = entry;
	menu->entries = entry;
	entry->menu = menu;
	entry->text = text;
	entry->shortcut = NULL;
	entry->callback = NULL;
	entry->clientData = NULL;
	entry->tag = menu->appcontext->last_menu_tag++;
	entry->cascade = submenu;
	entry->enabled = True;

	sprintf(entry->entryline, "%i %i %i %i %i %s", wmSubmenuItem,
		menu->code, entry->tag, True, submenu->code, text);
	return entry->tag;
}

static int countItems(WMMenu * menu)
{
	wmMenuEntry *entry = menu->first;
	int c;

	c = 1;
	while (entry) {
		c++;
		if (entry->cascade) {
			c += countItems(entry->cascade);
		}
		entry = entry->next;
	}
	c++;
	return c;
}

static void addItems(char **slist, int *index, WMMenu * menu)
{
	wmMenuEntry *entry = menu->first;

	slist[(*index)++] = menu->entryline;
	while (entry) {
		slist[(*index)++] = entry->entryline;
		if (entry->cascade) {
			addItems(slist, index, entry->cascade);
		}
		entry = entry->next;
	}
	slist[(*index)++] = menu->entryline2;
}

static Atom getatom(Display * dpy)
{
	static Atom atom = 0;

	if (atom == 0) {
		atom = XInternAtom(dpy, WMMENU_PROPNAME, False);
	}
	return atom;
}

int WMRealizeMenus(WMAppContext * app)
{
	int i, count;
	char **slist;
	XTextProperty text_prop;

	if (!app->main_menu)
		return False;

	/* first count how many menu items there are */
	count = countItems(app->main_menu);
	if (count == 0)
		return True;

	count++;
	slist = malloc(count * sizeof(char *));
	if (!slist) {
		return False;
	}

	slist[0] = "WMMenu 0";
	i = 1;
	addItems(slist, &i, app->main_menu);

	if (!XStringListToTextProperty(slist, i, &text_prop)) {
		free(slist);
		return False;
	}
	free(slist);
	XSetTextProperty(app->dpy, app->main_window, &text_prop, getatom(app->dpy));

	XFree(text_prop.value);

	return True;
}
