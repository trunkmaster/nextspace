/* winmenu.c - command menu for windows
 *
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

#include "wconfig.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include "WindowMaker.h"
#include "actions.h"
#include "menu.h"
#include "funcs.h"
#include "window.h"
#include "client.h"
#include "application.h"
#include "keybind.h"
#include "framewin.h"
#include "workspace.h"
#include "winspector.h"
#include "dialog.h"
#include "stacking.h"
#include "icon.h"


#define MC_MAXIMIZE	0
#define MC_MINIATURIZE	1
#define MC_SHADE	2
#define MC_HIDE		3
#define MC_MOVERESIZE   4
#define MC_SELECT       5
#define MC_DUMMY_MOVETO 6
#define MC_PROPERTIES   7
#define MC_OPTIONS      8
#define MC_SHORTCUT     8

#define MC_CLOSE        9
#define MC_KILL         10


#define WO_KEEP_ON_TOP		0
#define WO_KEEP_AT_BOTTOM	1
#define WO_OMNIPRESENT		2
#define WO_ENTRIES		3

/**** Global data ***/
extern Time LastTimestamp;
extern Atom _XA_WM_DELETE_WINDOW;
extern Atom _XA_GNUSTEP_WM_MINIATURIZE_WINDOW;

extern WShortKey wKeyBindings[WKBD_LAST];

extern WPreferences wPreferences;

static void updateOptionsMenu(WMenu *menu, WWindow *wwin);

static void
execWindowOptionCommand(WMenu *menu, WMenuEntry *entry)
{
    WWindow *wwin = (WWindow*)entry->clientdata;

    switch (entry->order) {
    case WO_KEEP_ON_TOP:
        if(wwin->frame->core->stacking->window_level!=WMFloatingLevel)
            ChangeStackingLevel(wwin->frame->core, WMFloatingLevel);
        else
            ChangeStackingLevel(wwin->frame->core, WMNormalLevel);
        break;

    case WO_KEEP_AT_BOTTOM:
        if(wwin->frame->core->stacking->window_level!=WMSunkenLevel)
            ChangeStackingLevel(wwin->frame->core, WMSunkenLevel);
        else
            ChangeStackingLevel(wwin->frame->core, WMNormalLevel);
        break;

    case WO_OMNIPRESENT:
        wWindowSetOmnipresent(wwin, !wwin->flags.omnipresent);
        break;
    }
}


static void
execMenuCommand(WMenu *menu, WMenuEntry *entry)
{
    WWindow *wwin = (WWindow*)entry->clientdata;
    WApplication *wapp;

    CloseWindowMenu(menu->frame->screen_ptr);

    switch (entry->order) {
    case MC_CLOSE:
        /* send delete message */
        wClientSendProtocol(wwin, _XA_WM_DELETE_WINDOW, LastTimestamp);
        break;

    case MC_KILL:
        wretain(wwin);
        if (wPreferences.dont_confirm_kill
            || wMessageDialog(menu->frame->screen_ptr, _("Kill Application"),
                              _("This will kill the application.\nAny unsaved changes will be lost.\nPlease confirm."),
                              _("Yes"), _("No"), NULL)==WAPRDefault) {
            if (!wwin->flags.destroyed)
                wClientKill(wwin);
        }
        wrelease(wwin);
        break;

    case MC_MINIATURIZE:
        if (wwin->flags.miniaturized) {
            wDeiconifyWindow(wwin);
        } else{
            if (wwin->protocols.MINIATURIZE_WINDOW) {
                wClientSendProtocol(wwin, _XA_GNUSTEP_WM_MINIATURIZE_WINDOW,
                                    LastTimestamp);
            } else {
                wIconifyWindow(wwin);
            }
        }
        break;

    case MC_MAXIMIZE:
        if (wwin->flags.maximized)
            wUnmaximizeWindow(wwin);
        else
            wMaximizeWindow(wwin, MAX_VERTICAL|MAX_HORIZONTAL);
        break;

    case MC_SHADE:
        if (wwin->flags.shaded)
            wUnshadeWindow(wwin);
        else
            wShadeWindow(wwin);
        break;

    case MC_SELECT:
        if (!wwin->flags.miniaturized)
            wSelectWindow(wwin, !wwin->flags.selected);
        else
            wIconSelect(wwin->icon);
        break;

    case MC_MOVERESIZE:
        wKeyboardMoveResizeWindow(wwin);
        break;

    case MC_PROPERTIES:
        wShowInspectorForWindow(wwin);
        break;

    case MC_HIDE:
        wapp = wApplicationOf(wwin->main_window);
        wHideApplication(wapp);
        break;
    }
}


static void
switchWSCommand(WMenu *menu, WMenuEntry *entry)
{
    WWindow *wwin = (WWindow*)entry->clientdata;

    wSelectWindow(wwin, False);
    wWindowChangeWorkspace(wwin, entry->order);
}


static void
makeShortcutCommand(WMenu *menu, WMenuEntry *entry)
{
    WWindow *wwin = (WWindow*)entry->clientdata;
    WScreen *scr = wwin->screen_ptr;
    int index = entry->order-WO_ENTRIES;

    if (scr->shortcutWindows[index]) {
        WMFreeArray(scr->shortcutWindows[index]);
        scr->shortcutWindows[index] = NULL;
    }

    if (wwin->flags.selected && scr->selected_windows) {
        scr->shortcutWindows[index] = WMDuplicateArray(scr->selected_windows);
        /*WMRemoveFromArray(scr->shortcutWindows[index], wwin);
         WMInsertInArray(scr->shortcutWindows[index], 0, wwin);*/
    } else {
        scr->shortcutWindows[index] = WMCreateArray(4);
        WMAddToArray(scr->shortcutWindows[index], wwin);
    }

    wSelectWindow(wwin, !wwin->flags.selected);
    XFlush(dpy);
    wusleep(3000);
    wSelectWindow(wwin, !wwin->flags.selected);
    XFlush(dpy);
}


static void
updateWorkspaceMenu(WMenu *menu)
{
    WScreen *scr = menu->frame->screen_ptr;
    char title[MAX_WORKSPACENAME_WIDTH+1];
    int i;

    if (!menu)
        return;

    for (i=0; i<scr->workspace_count; i++) {
        if (i < menu->entry_no) {
            if (strcmp(menu->entries[i]->text,scr->workspaces[i]->name)!=0) {
                wfree(menu->entries[i]->text);
                strncpy(title, scr->workspaces[i]->name, MAX_WORKSPACENAME_WIDTH);
                title[MAX_WORKSPACENAME_WIDTH] = 0;
                menu->entries[i]->text = wstrdup(title);
                menu->flags.realized = 0;
            }
        } else {
            strncpy(title, scr->workspaces[i]->name, MAX_WORKSPACENAME_WIDTH);
            title[MAX_WORKSPACENAME_WIDTH] = 0;

            wMenuAddCallback(menu, title, switchWSCommand, NULL);

            menu->flags.realized = 0;
        }
    }

    if (!menu->flags.realized)
        wMenuRealize(menu);
}


static void
updateMakeShortcutMenu(WMenu *menu, WWindow *wwin)
{
    WMenu *smenu = menu->cascades[menu->entries[MC_SHORTCUT]->cascade];
    int i;
    char *buffer;
    int buflen;
    KeyCode kcode;

    if (!smenu)
        return;

    buflen = strlen(_("Set Shortcut"))+16;
    buffer = wmalloc(buflen);

    for (i=WO_ENTRIES; i<smenu->entry_no; i++) {
        char *tmp;
        int shortcutNo = i-WO_ENTRIES;
        WMenuEntry *entry = smenu->entries[i];
        WMArray *shortSelWindows = wwin->screen_ptr->shortcutWindows[shortcutNo];

        snprintf(buffer, buflen, "%s %i", _("Set Shortcut"), shortcutNo+1);

        if (!shortSelWindows) {
            entry->flags.indicator_on = 0;
        } else {
            entry->flags.indicator_on = 1;
            if (WMCountInArray(shortSelWindows, wwin))
                entry->flags.indicator_type = MI_DIAMOND;
            else
                entry->flags.indicator_type = MI_CHECK;
        }

        if (strcmp(buffer, entry->text)!=0) {
            wfree(entry->text);
            entry->text = wstrdup(buffer);
            smenu->flags.realized = 0;
        }

        kcode = wKeyBindings[WKBD_WINDOW1+shortcutNo].keycode;

        if (kcode) {
            if ((tmp = XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0)))
                && (!entry->rtext || strcmp(tmp, entry->rtext)!=0)) {
                if (entry->rtext)
                    wfree(entry->rtext);
                entry->rtext = wstrdup(tmp);
                smenu->flags.realized = 0;
            }
            wMenuSetEnabled(smenu, i, True);
        } else {
            wMenuSetEnabled(smenu, i, False);
            if (entry->rtext) {
                wfree(entry->rtext);
                entry->rtext = NULL;
                smenu->flags.realized = 0;
            }
        }
        entry->clientdata = wwin;
    }
    wfree(buffer);
    if (!smenu->flags.realized)
        wMenuRealize(smenu);
}


static void
updateOptionsMenu(WMenu *menu, WWindow *wwin)
{
    WMenu *smenu = menu->cascades[menu->entries[MC_OPTIONS]->cascade];

    /* keep on top check */
    smenu->entries[WO_KEEP_ON_TOP]->clientdata = wwin;
    smenu->entries[WO_KEEP_ON_TOP]->flags.indicator_on =
        (wwin->frame->core->stacking->window_level == WMFloatingLevel)?1:0;
    wMenuSetEnabled(smenu, WO_KEEP_ON_TOP, !wwin->flags.miniaturized);

    /* keep at bottom check */
    smenu->entries[WO_KEEP_AT_BOTTOM]->clientdata = wwin;
    smenu->entries[WO_KEEP_AT_BOTTOM]->flags.indicator_on =
        (wwin->frame->core->stacking->window_level == WMSunkenLevel)?1:0;
    wMenuSetEnabled(smenu, WO_KEEP_AT_BOTTOM, !wwin->flags.miniaturized);

    /* omnipresent check */
    smenu->entries[WO_OMNIPRESENT]->clientdata = wwin;
    smenu->entries[WO_OMNIPRESENT]->flags.indicator_on = IS_OMNIPRESENT(wwin);

    smenu->flags.realized = 0;
    wMenuRealize(smenu);
}


static WMenu*
makeWorkspaceMenu(WScreen *scr)
{
    WMenu *menu;

    menu = wMenuCreate(scr, NULL, False);
    if (!menu) {
        wwarning(_("could not create submenu for window menu"));
        return NULL;
    }

    updateWorkspaceMenu(menu);

    return menu;
}


static WMenu*
makeMakeShortcutMenu(WScreen *scr, WMenu *menu)
{
    /*
     WMenu *menu;
     */
    int i;
    /*
     menu = wMenuCreate(scr, NULL, False);
     if (!menu) {
     wwarning(_("could not create submenu for window menu"));
     return NULL;
     }
     */

    for (i=0; i<MAX_WINDOW_SHORTCUTS; i++) {
        WMenuEntry *entry;
        entry = wMenuAddCallback(menu, "", makeShortcutCommand, NULL);

        entry->flags.indicator = 1;
    }

    return menu;
}



static WMenu*
makeOptionsMenu(WScreen *scr)
{
    WMenu *menu;
    WMenuEntry *entry;

    menu = wMenuCreate(scr, NULL, False);
    if (!menu) {
        wwarning(_("could not create submenu for window menu"));
        return NULL;
    }

    entry = wMenuAddCallback(menu, _("Keep on top"), execWindowOptionCommand,
                             NULL);
    entry->flags.indicator = 1;
    entry->flags.indicator_type = MI_CHECK;

    entry = wMenuAddCallback(menu, _("Keep at bottom"), execWindowOptionCommand,
                             NULL);
    entry->flags.indicator = 1;
    entry->flags.indicator_type = MI_CHECK;

    entry = wMenuAddCallback(menu, _("Omnipresent"), execWindowOptionCommand,
                             NULL);
    entry->flags.indicator = 1;
    entry->flags.indicator_type = MI_CHECK;

    return menu;
}


static WMenu*
createWindowMenu(WScreen *scr)
{
    WMenu *menu;
    KeyCode kcode;
    WMenuEntry *entry;
    char *tmp;

    menu = wMenuCreate(scr, NULL, False);
    /*
     * Warning: If you make some change that affects the order of the
     * entries, you must update the command #defines in the top of
     * this file.
     */
    entry = wMenuAddCallback(menu, _("Maximize"), execMenuCommand, NULL);
    if (wKeyBindings[WKBD_MAXIMIZE].keycode!=0) {
        kcode = wKeyBindings[WKBD_MAXIMIZE].keycode;

        if (kcode && (tmp = XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0))))
            entry->rtext = wstrdup(tmp);
    }

    entry = wMenuAddCallback(menu, _("Miniaturize"), execMenuCommand, NULL);
    if (wKeyBindings[WKBD_MINIATURIZE].keycode!=0) {
        kcode = wKeyBindings[WKBD_MINIATURIZE].keycode;

        if (kcode && (tmp = XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0))))
            entry->rtext = wstrdup(tmp);
    }

    entry = wMenuAddCallback(menu, _("Shade"), execMenuCommand, NULL);
    if (wKeyBindings[WKBD_SHADE].keycode!=0) {
        kcode = wKeyBindings[WKBD_SHADE].keycode;

        if (kcode && (tmp = XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0))))
            entry->rtext = wstrdup(tmp);
    }

    entry = wMenuAddCallback(menu, _("Hide"), execMenuCommand, NULL);
    if (wKeyBindings[WKBD_HIDE].keycode!=0) {
        kcode = wKeyBindings[WKBD_HIDE].keycode;

        if (kcode && (tmp = XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0))))
            entry->rtext = wstrdup(tmp);
    }

    entry = wMenuAddCallback(menu, _("Resize/Move"), execMenuCommand, NULL);
    if (wKeyBindings[WKBD_MOVERESIZE].keycode!=0) {
        kcode = wKeyBindings[WKBD_MOVERESIZE].keycode;

        if (kcode && (tmp = XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0))))
            entry->rtext = wstrdup(tmp);
    }

    entry = wMenuAddCallback(menu, _("Select"), execMenuCommand, NULL);
    if (wKeyBindings[WKBD_SELECT].keycode!=0) {
        kcode = wKeyBindings[WKBD_SELECT].keycode;

        if (kcode && (tmp = XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0))))
            entry->rtext = wstrdup(tmp);
    }

    entry = wMenuAddCallback(menu, _("Move To"), NULL, NULL);
    scr->workspace_submenu = makeWorkspaceMenu(scr);
    if (scr->workspace_submenu)
        wMenuEntrySetCascade(menu, entry, scr->workspace_submenu);

    entry = wMenuAddCallback(menu, _("Attributes..."), execMenuCommand, NULL);

    entry = wMenuAddCallback(menu, _("Options"), NULL, NULL);
    wMenuEntrySetCascade(menu, entry,
                         makeMakeShortcutMenu(scr, makeOptionsMenu(scr)));

    /*
     entry = wMenuAddCallback(menu, _("Select Shortcut"), NULL, NULL);
     wMenuEntrySetCascade(menu, entry, makeMakeShortcutMenu(scr));
     */

    entry = wMenuAddCallback(menu, _("Close"), execMenuCommand, NULL);
    if (wKeyBindings[WKBD_CLOSE].keycode!=0) {
        kcode = wKeyBindings[WKBD_CLOSE].keycode;
        if (kcode && (tmp = XKeysymToString(XKeycodeToKeysym(dpy, kcode, 0))))
            entry->rtext = wstrdup(tmp);
    }

    entry = wMenuAddCallback(menu, _("Kill"), execMenuCommand, NULL);

    return menu;
}


void
CloseWindowMenu(WScreen *scr)
{
    if (scr->window_menu) {
        if (scr->window_menu->flags.mapped)
            wMenuUnmap(scr->window_menu);

        if (scr->window_menu->entries[0]->clientdata) {
            WWindow *wwin = (WWindow*)scr->window_menu->entries[0]->clientdata;

            wwin->flags.menu_open_for_me = 0;
        }
        scr->window_menu->entries[0]->clientdata = NULL;
    }
}



static void
updateMenuForWindow(WMenu *menu, WWindow *wwin)
{
    WApplication *wapp = wApplicationOf(wwin->main_window);
    WScreen *scr = wwin->screen_ptr;
    int i;

    updateOptionsMenu(menu, wwin);

    updateMakeShortcutMenu(menu, wwin);

    wMenuSetEnabled(menu, MC_HIDE, wapp!=NULL
                    && !WFLAGP(wapp->main_window_desc, no_appicon));

    wMenuSetEnabled(menu, MC_CLOSE,
                    (wwin->protocols.DELETE_WINDOW
                     && !WFLAGP(wwin, no_closable)));

    if (wwin->flags.miniaturized) {
        static char *text = NULL;
        if (!text) text = _("Deminiaturize");

        menu->entries[MC_MINIATURIZE]->text = text;
    } else {
        static char *text = NULL;
        if (!text) text = _("Miniaturize");

        menu->entries[MC_MINIATURIZE]->text = text;
    }

    wMenuSetEnabled(menu, MC_MINIATURIZE, !WFLAGP(wwin, no_miniaturizable));

    if (wwin->flags.maximized) {
        static char *text = NULL;
        if (!text) text = _("Unmaximize");

        menu->entries[MC_MAXIMIZE]->text = text;
    } else {
        static char *text = NULL;
        if (!text) text = _("Maximize");

        menu->entries[MC_MAXIMIZE]->text = text;
    }
    wMenuSetEnabled(menu, MC_MAXIMIZE, IS_RESIZABLE(wwin));


    wMenuSetEnabled(menu, MC_MOVERESIZE, IS_RESIZABLE(wwin)
                    && !wwin->flags.miniaturized);

    if (wwin->flags.shaded) {
        static char *text = NULL;
        if (!text) text = _("Unshade");

        menu->entries[MC_SHADE]->text = text;
    } else {
        static char *text = NULL;
        if (!text) text = _("Shade");

        menu->entries[MC_SHADE]->text = text;
    }

    wMenuSetEnabled(menu, MC_SHADE, !WFLAGP(wwin, no_shadeable)
                    && !wwin->flags.miniaturized);

    wMenuSetEnabled(menu, MC_DUMMY_MOVETO, !IS_OMNIPRESENT(wwin));

    if (!wwin->flags.inspector_open) {
        wMenuSetEnabled(menu, MC_PROPERTIES, True);
    } else {
        wMenuSetEnabled(menu, MC_PROPERTIES, False);
    }

    /* set the client data of the entries to the window */
    for (i = 0; i < menu->entry_no; i++) {
        menu->entries[i]->clientdata = wwin;
    }

    for (i = 0; i < scr->workspace_submenu->entry_no; i++) {
        scr->workspace_submenu->entries[i]->clientdata = wwin;
        if (i == scr->current_workspace) {
            wMenuSetEnabled(scr->workspace_submenu, i, False);
        } else {
            wMenuSetEnabled(scr->workspace_submenu, i, True);
        }
    }

    menu->flags.realized = 0;
    wMenuRealize(menu);
}


void
OpenWindowMenu(WWindow *wwin, int x, int y, int keyboard)
{
    WMenu *menu;
    WScreen *scr = wwin->screen_ptr;

    wwin->flags.menu_open_for_me = 1;

    if (!scr->window_menu) {
        scr->window_menu = createWindowMenu(scr);

        /* hack to save some memory allocation/deallocation */
        wfree(scr->window_menu->entries[MC_MINIATURIZE]->text);
        wfree(scr->window_menu->entries[MC_MAXIMIZE]->text);
        wfree(scr->window_menu->entries[MC_SHADE]->text);
    } else {
        updateWorkspaceMenu(scr->workspace_submenu);
    }

    menu = scr->window_menu;
    if (menu->flags.mapped) {
        wMenuUnmap(menu);
        if (menu->entries[0]->clientdata==wwin) {
            return;
        }
    }

    updateMenuForWindow(menu, wwin);

    x -= menu->frame->core->width/2;
    if (x + menu->frame->core->width > wwin->frame_x+wwin->frame->core->width)
        x = wwin->frame_x+wwin->frame->core->width - menu->frame->core->width;
    if (x < wwin->frame_x)
        x = wwin->frame_x;

    if (!wwin->flags.internal_window)
        wMenuMapAt(menu, x, y, keyboard);
}


void
OpenMiniwindowMenu(WWindow *wwin, int x, int y)
{
    WMenu *menu;
    WScreen *scr = wwin->screen_ptr;

    wwin->flags.menu_open_for_me = 1;

    if (!scr->window_menu) {
        scr->window_menu = createWindowMenu(scr);

        /* hack to save some memory allocation/deallocation */
        wfree(scr->window_menu->entries[MC_MINIATURIZE]->text);
        wfree(scr->window_menu->entries[MC_MAXIMIZE]->text);
        wfree(scr->window_menu->entries[MC_SHADE]->text);
    } else {
        updateWorkspaceMenu(scr->workspace_submenu);
    }

    menu = scr->window_menu;
    if (menu->flags.mapped) {
        wMenuUnmap(menu);
        if (menu->entries[0]->clientdata==wwin) {
            return;
        }
    }

    updateMenuForWindow(menu, wwin);

    x -= menu->frame->core->width/2;

    wMenuMapAt(menu, x, y, False);
}

