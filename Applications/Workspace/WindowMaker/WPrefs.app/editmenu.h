/* editmenu.h - editable menus
 *
 *  WPrefs - Window Maker Preferences Program
 *
 *  Copyright (c) 2000-2003 Alfredo K. Kojima
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


#ifndef _editmenu_h_
#define _editmenu_h_

typedef struct W_EditMenu WEditMenu;
typedef struct W_EditMenuItem WEditMenuItem;


typedef struct WEditMenuDelegate {
    void *data;

    void (*itemCloned)(struct WEditMenuDelegate*, WEditMenu*,
                       WEditMenuItem*, WEditMenuItem *);
    void (*itemEdited)(struct WEditMenuDelegate*, WEditMenu*,
                       WEditMenuItem*);
    void (*itemSelected)(struct WEditMenuDelegate*, WEditMenu*,
                         WEditMenuItem*);
    void (*itemDeselected)(struct WEditMenuDelegate*, WEditMenu*,
                           WEditMenuItem*);
    Bool (*shouldRemoveItem)(struct WEditMenuDelegate*, WEditMenu*,
                             WEditMenuItem*);
} WEditMenuDelegate;




WEditMenuItem *WCreateEditMenuItem(WMWidget *parent, const char *title,
                                   Bool isTitle);


char *WGetEditMenuItemTitle(WEditMenuItem *item);

void *WGetEditMenuItemData(WEditMenuItem *item);

void WSetEditMenuItemData(WEditMenuItem *item, void *data,
                          WMCallback *destroyer);

void WSetEditMenuItemImage(WEditMenuItem *item, WMPixmap *pixmap);

WEditMenu *WCreateEditMenu(WMScreen *scr, const char *title);

WEditMenu *WCreateEditMenuPad(WMWidget *parent);

void WSetEditMenuDelegate(WEditMenu *mPtr, WEditMenuDelegate *delegate);

WEditMenuItem *WInsertMenuItemWithTitle(WEditMenu *mPtr, int index,
                                        const char *title);

WEditMenuItem *WAddMenuItemWithTitle(WEditMenu *mPtr, const char *title);

WEditMenuItem *WGetEditMenuItem(WEditMenu *mPtr, int index);

void WSetEditMenuTitle(WEditMenu *mPtr, const char *title);

char *WGetEditMenuTitle(WEditMenu *mPtr);

void WSetEditMenuAcceptsDrop(WEditMenu *mPtr, Bool flag);

void WSetEditMenuSubmenu(WEditMenu *mPtr, WEditMenuItem *item,
                         WEditMenu *submenu);


WEditMenu *WGetEditMenuSubmenu(WEditMenuItem *item);

void WRemoveEditMenuItem(WEditMenu *mPtr, WEditMenuItem *item);

void WSetEditMenuSelectable(WEditMenu *mPtr, Bool flag);

void WSetEditMenuEditable(WEditMenu *mPtr, Bool flag);

void WSetEditMenuIsFactory(WEditMenu *mPtr, Bool flag);

void WSetEditMenuMinSize(WEditMenu *mPtr, WMSize size);

void WSetEditMenuMaxSize(WEditMenu *mPtr, WMSize size);

WMPoint WGetEditMenuLocationForSubmenu(WEditMenu *mPtr, WEditMenu *submenu);

void WTearOffEditMenu(WEditMenu *menu, WEditMenu *submenu);

Bool WEditMenuIsTornOff(WEditMenu *mPtr);


void WEditMenuHide(WEditMenu *menu);

void WEditMenuUnhide(WEditMenu *menu);

void WEditMenuShowAt(WEditMenu *menu, int x, int y);


#endif

