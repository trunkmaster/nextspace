/* menu.h - private menu declarations
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

#ifndef _MENU_H_
#define _MENU_H_

#define WMMENU_PROPNAME	"_WINDOWMAKER_MENU"

typedef struct _wmMenuEntry {
    struct _wmMenuEntry *next;
    struct _wmMenuEntry *prev;

    struct _wmMenu *menu;	       /* menu for the entry */

    char *text;			       /* entry text */
    char *shortcut;
    WMMenuAction callback;
    void *clientData;		       /* data to pass to callback */
    WMFreeFunction free;	       /* function to free clientData */
    int tag;			       /* unique entry ID */

    struct _wmMenu *cascade;	       /* cascade menu */
    short order;
    short enabled;		       /* entry is selectable */

    char *entryline;
} wmMenuEntry;


typedef struct _wmMenu {
    wmAppContext *appcontext;
    int code;

    struct _wmMenu *parent;

    char *title;		       /* menu title */
    wmMenuEntry *entries;	       /* list of entries */
    wmMenuEntry *first;		       /* first of list of entries */
    int realized;

    char *entryline;
    char *entryline2;
} wmMenu;



enum {
    wmBeginMenu = 1,
    wmEndMenu = 2,
    wmNormalItem = 10,
    wmDoubleItem = 11,
    wmSubmenuItem = 12
};


#endif

