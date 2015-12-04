/* winspector.c - window attribute inspector
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

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "WindowMaker.h"
#include "screen.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "workspace.h"
#include "funcs.h"
#include "defaults.h"
#include "dialog.h"
#include "icon.h"
#include "stacking.h"
#include "application.h"
#include "appicon.h"
#include "actions.h"
#include "winspector.h"
#include "dock.h"
#include "client.h"

#ifdef NETWM_HINTS
#include "wmspec.h"
#endif

#include "xinerama.h"

#include <WINGs/WUtil.h>







typedef struct InspectorPanel {
    struct InspectorPanel *nextPtr;

    WWindow *frame;

    WWindow *inspected;       /* the window that's being inspected */

    WMWindow *win;

    Window parent;

    /* common stuff */
    WMButton *revertBtn;
    WMButton *applyBtn;
    WMButton *saveBtn;

    WMPopUpButton *pagePopUp;

    /* first page. general stuff */

    WMFrame *specFrm;
    WMButton *instRb;
    WMButton *clsRb;
    WMButton *bothRb;
    WMButton *defaultRb;

    WMButton *selWinB;

    WMLabel *specLbl;

    /* second page. attributes */

    WMFrame *attrFrm;
    WMButton *attrChk[11];

    /* 3rd page. more attributes */
    WMFrame *moreFrm;
    WMButton *moreChk[8];

    /* 4th page. icon and workspace */
    WMFrame *iconFrm;
    WMLabel *iconLbl;
    WMLabel *fileLbl;
    WMTextField *fileText;
    WMButton *alwChk;
    /*
     WMButton *updateIconBtn;
     */
    WMButton *browseIconBtn;

    WMFrame *wsFrm;
    WMPopUpButton *wsP;

    /* 5th page. application wide attributes */
    WMFrame *appFrm;
    WMButton *appChk[3];

    unsigned int done:1;
    unsigned int destroyed:1;
    unsigned int choosingIcon:1;
} InspectorPanel;




extern Cursor wCursor[WCUR_LAST];

extern WDDomain *WDWindowAttributes;

static InspectorPanel *panelList=NULL;

extern WPreferences wPreferences;

static WMPropList *ANoTitlebar = NULL;
static WMPropList *ANoResizebar;
static WMPropList *ANoMiniaturizeButton;
static WMPropList *ANoCloseButton;
static WMPropList *ANoBorder;
static WMPropList *ANoHideOthers;
static WMPropList *ANoMouseBindings;
static WMPropList *ANoKeyBindings;
static WMPropList *ANoAppIcon;
static WMPropList *AKeepOnTop;
static WMPropList *AKeepOnBottom;
static WMPropList *AOmnipresent;
static WMPropList *ASkipWindowList;
static WMPropList *AKeepInsideScreen;
static WMPropList *AUnfocusable;
static WMPropList *AAlwaysUserIcon;
static WMPropList *AStartMiniaturized;
static WMPropList *AStartMaximized;
static WMPropList *ADontSaveSession;
static WMPropList *AEmulateAppIcon;
static WMPropList *AFullMaximize;
static WMPropList *ASharedAppIcon;

static WMPropList *AStartWorkspace;

static WMPropList *AIcon;

/* application wide options */
static WMPropList *AStartHidden;


static WMPropList *AnyWindow;
static WMPropList *EmptyString;
static WMPropList *Yes, *No;


#define PWIDTH	270
#define PHEIGHT	350



static char *spec_text;


static void applySettings(WMButton *button, InspectorPanel *panel);




#define UNDEFINED_POS 0xffffff

static InspectorPanel *createInspectorForWindow(WWindow *wwin,
                                                int xpos, int ypos,
                                                Bool showSelectPanel);



static void
make_keys()
{
    if (ANoTitlebar!=NULL)
        return;

    AIcon = WMCreatePLString("Icon");
    ANoTitlebar = WMCreatePLString("NoTitlebar");
    ANoResizebar = WMCreatePLString("NoResizebar");
    ANoMiniaturizeButton = WMCreatePLString("NoMiniaturizeButton");
    ANoCloseButton = WMCreatePLString("NoCloseButton");
    ANoBorder = WMCreatePLString("NoBorder");
    ANoHideOthers = WMCreatePLString("NoHideOthers");
    ANoMouseBindings = WMCreatePLString("NoMouseBindings");
    ANoKeyBindings = WMCreatePLString("NoKeyBindings");
    ANoAppIcon = WMCreatePLString("NoAppIcon");
    AKeepOnTop = WMCreatePLString("KeepOnTop");
    AKeepOnBottom = WMCreatePLString("KeepOnBottom");
    AOmnipresent = WMCreatePLString("Omnipresent");
    ASkipWindowList = WMCreatePLString("SkipWindowList");
    AKeepInsideScreen = WMCreatePLString("KeepInsideScreen");
    AUnfocusable = WMCreatePLString("Unfocusable");
    AAlwaysUserIcon = WMCreatePLString("AlwaysUserIcon");
    AStartMiniaturized = WMCreatePLString("StartMiniaturized");
    AStartMaximized = WMCreatePLString("StartMaximized");
    AStartHidden = WMCreatePLString("StartHidden");
    ADontSaveSession = WMCreatePLString("DontSaveSession");
    AEmulateAppIcon = WMCreatePLString("EmulateAppIcon");
    AFullMaximize = WMCreatePLString("FullMaximize");
    ASharedAppIcon = WMCreatePLString("SharedAppIcon");

    AStartWorkspace = WMCreatePLString("StartWorkspace");

    AnyWindow = WMCreatePLString("*");
    EmptyString = WMCreatePLString("");
    Yes = WMCreatePLString("Yes");
    No = WMCreatePLString("No");
}



static void
freeInspector(InspectorPanel *panel)
{
    panel->destroyed = 1;
    if (panel->choosingIcon)
        return;

    WMDestroyWidget(panel->win);

    XDestroyWindow(dpy, panel->parent);

    wfree(panel);
}


static void
destroyInspector(WCoreWindow *foo, void *data, XEvent *event)
{
    InspectorPanel *panel;
    InspectorPanel *tmp;

    panel = panelList;
    while (panel->frame!=data)
        panel = panel->nextPtr;

    if (panelList == panel)
        panelList = panel->nextPtr;
    else {
        tmp = panelList;
        while (tmp->nextPtr!=panel) {
            tmp = tmp->nextPtr;
        }
        tmp->nextPtr = panel->nextPtr;
    }
    panel->inspected->flags.inspector_open = 0;
    panel->inspected->inspector = NULL;

    WMRemoveNotificationObserver(panel);

    wWindowUnmap(panel->frame);
    wUnmanageWindow(panel->frame, True, False);

    freeInspector(panel);
}



void
wDestroyInspectorPanels()
{
    InspectorPanel *panel;

    while (panelList != NULL) {
        panel = panelList;
        panelList = panelList->nextPtr;
        wUnmanageWindow(panel->frame, False, False);
        WMDestroyWidget(panel->win);

        panel->inspected->flags.inspector_open = 0;
        panel->inspected->inspector = NULL;

        wfree(panel);
    }
}


static void
changePage(WMPopUpButton *bPtr, InspectorPanel *panel)
{
    int page;

    page = WMGetPopUpButtonSelectedItem(bPtr);

    if (page == 0) {
        WMMapWidget(panel->specFrm);
        WMMapWidget(panel->specLbl);
    } else if (page == 1) {
        WMMapWidget(panel->attrFrm);
    } else if (page == 2) {
        WMMapWidget(panel->moreFrm);
    } else if (page == 3) {
        WMMapWidget(panel->iconFrm);
        WMMapWidget(panel->wsFrm);
    } else {
        WMMapWidget(panel->appFrm);
    }

    if (page != 0) {
        WMUnmapWidget(panel->specFrm);
        WMUnmapWidget(panel->specLbl);
    }
    if (page != 1)
        WMUnmapWidget(panel->attrFrm);
    if (page != 2)
        WMUnmapWidget(panel->moreFrm);
    if (page != 3) {
        WMUnmapWidget(panel->iconFrm);
        WMUnmapWidget(panel->wsFrm);
    }
    if (page != 4 && panel->appFrm)
        WMUnmapWidget(panel->appFrm);
}


#define USE_TEXT_FIELD          1
#define UPDATE_TEXT_FIELD       2
#define REVERT_TO_DEFAULT       4


static int
showIconFor(WMScreen *scrPtr, InspectorPanel *panel,
            char *wm_instance, char *wm_class, int flags)
{
    WMPixmap *pixmap = (WMPixmap*) NULL;
    char *file=NULL, *path=NULL;
    char *db_icon=NULL;

    if ((flags & USE_TEXT_FIELD) != 0) {
        file = WMGetTextFieldText(panel->fileText);
        if (file && file[0] == 0) {
            wfree(file);
            file = NULL;
        }
    } else {
        db_icon = wDefaultGetIconFile(panel->inspected->screen_ptr,
                                      wm_instance, wm_class, False);
        if(db_icon != NULL)
            file = wstrdup(db_icon);
    }
    if (db_icon!=NULL && (flags & REVERT_TO_DEFAULT)!=0) {
        if (file)
            file = wstrdup(db_icon);
        flags |= UPDATE_TEXT_FIELD;
    }

    if ((flags & UPDATE_TEXT_FIELD) != 0) {
        WMSetTextFieldText(panel->fileText, file);
    }

    if (file) {
        path = FindImage(wPreferences.icon_path, file);

        if (!path) {
            char *buf;
            int len = strlen(file)+80;

            buf = wmalloc(len);
            snprintf(buf, len, _("Could not find icon \"%s\" specified for this window"),
                     file);
            wMessageDialog(panel->frame->screen_ptr, _("Error"), buf,
                           _("OK"), NULL, NULL);
            wfree(buf);
            wfree(file);
            return -1;
        }

        pixmap = WMCreatePixmapFromFile(scrPtr, path);
        wfree(path);

        if (!pixmap) {
            char *buf;
            int len = strlen(file)+80;

            buf = wmalloc(len);
            snprintf(buf, len, _("Could not open specified icon \"%s\":%s"),
                     file, RMessageForError(RErrorCode));
            wMessageDialog(panel->frame->screen_ptr, _("Error"), buf,
                           _("OK"), NULL, NULL);
            wfree(buf);
            wfree(file);
            return -1;
        }
        wfree(file);
    }

    WMSetLabelImage(panel->iconLbl, pixmap);
    if (pixmap)
        WMReleasePixmap(pixmap);

    return 0;
}

#if 0
static void
updateIcon(WMButton *button, InspectorPanel *panel)
{
    showIconFor(WMWidgetScreen(button), panel, NULL, NULL, USE_TEXT_FIELD);
}
#endif

static int
getBool(WMPropList *value)
{
    char *val;

    if (!WMIsPLString(value)) {
        return 0;
    }
    if (!(val = WMGetFromPLString(value))) {
        return 0;
    }

    if ((val[1]=='\0' && (val[0]=='y' || val[0]=='Y' || val[0]=='T'
                          || val[0]=='t' || val[0]=='1'))
        || (strcasecmp(val, "YES")==0 || strcasecmp(val, "TRUE")==0)) {

        return 1;
    } else if ((val[1]=='\0'
                && (val[0]=='n' || val[0]=='N' || val[0]=='F'
                    || val[0]=='f' || val[0]=='0'))
               || (strcasecmp(val, "NO")==0 || strcasecmp(val, "FALSE")==0)) {

        return 0;
    } else {
        wwarning(_("can't convert \"%s\" to boolean"), val);
        return 0;
    }
}


#define UPDATE_DEFAULTS    1
#define IS_BOOLEAN         2


/*
 *  Will insert the attribute = value; pair in window's list,
 * if it's different from the defaults.
 *  Defaults means either defaults database, or attributes saved
 * for the default window "*". This is to let one revert options that are
 * global because they were saved for all windows ("*").
 *
 */


static int
insertAttribute(WMPropList *dict, WMPropList *window, WMPropList *attr,
                WMPropList *value, int flags)
{
    WMPropList *def_win, *def_value=NULL;
    int update = 0;
    int modified = 0;

    if (!(flags & UPDATE_DEFAULTS) && dict) {
        if ((def_win = WMGetFromPLDictionary(dict, AnyWindow)) != NULL) {
            def_value = WMGetFromPLDictionary(def_win, attr);
        }
    }

    /* If we could not find defaults in database, fall to hardcoded values.
     * Also this is true if we save defaults for all windows
     */
    if (!def_value)
        def_value = ((flags & IS_BOOLEAN) != 0) ? No : EmptyString;

    if ((flags & IS_BOOLEAN))
        update = (getBool(value) != getBool(def_value));
    else {
        update = !WMIsPropListEqualTo(value, def_value);
    }

    if (update) {
        WMPutInPLDictionary(window, attr, value);
        modified = 1;
    }

    return modified;
}


static void
saveSettings(WMButton *button, InspectorPanel *panel)
{
    WWindow *wwin = panel->inspected;
    WDDomain *db = WDWindowAttributes;
    WMPropList *dict = db->dictionary;
    WMPropList *winDic, *appDic, *value, *key, *key2;
    char *icon_file;
    int flags = 0;
    int different = 0, different2 = 0;

    /* Save will apply the changes and save them */
    applySettings(panel->applyBtn, panel);

    if (WMGetButtonSelected(panel->instRb) != 0)
        key = WMCreatePLString(wwin->wm_instance);
    else if (WMGetButtonSelected(panel->clsRb) != 0)
        key = WMCreatePLString(wwin->wm_class);
    else if (WMGetButtonSelected(panel->bothRb) != 0) {
        char *buffer;

        buffer = StrConcatDot(wwin->wm_instance, wwin->wm_class);
        key = WMCreatePLString(buffer);
        wfree(buffer);
    } else if (WMGetButtonSelected(panel->defaultRb) != 0) {
        key = WMRetainPropList(AnyWindow);
        flags = UPDATE_DEFAULTS;
    } else
        key = NULL;

    if (!key)
        return;

    if (!dict) {
        dict = WMCreatePLDictionary(NULL, NULL);
        if (dict) {
            db->dictionary = dict;
        } else {
            WMReleasePropList(key);
            return;
        }
    }

    if (showIconFor(WMWidgetScreen(button), panel, NULL, NULL,
                    USE_TEXT_FIELD) < 0)
        return;

    WMPLSetCaseSensitive(True);

    winDic = WMCreatePLDictionary(NULL, NULL);
    appDic = WMCreatePLDictionary(NULL, NULL);

    /* Update icon for window */
    icon_file = WMGetTextFieldText(panel->fileText);
    if (icon_file) {
        if (icon_file[0] != 0) {
            value = WMCreatePLString(icon_file);
            different |= insertAttribute(dict, winDic, AIcon, value, flags);
            different2 |= insertAttribute(dict, appDic, AIcon, value, flags);
            WMReleasePropList(value);
        }
        wfree(icon_file);
    }

    {
        int i = WMGetPopUpButtonSelectedItem(panel->wsP);

        i--;

        if (i>=0 && i < panel->frame->screen_ptr->workspace_count) {
            value = WMCreatePLString(panel->frame->screen_ptr->workspaces[i]->name);
            different |= insertAttribute(dict, winDic, AStartWorkspace, value,
                                         flags);
            WMReleasePropList(value);
        }
    }

    flags |= IS_BOOLEAN;

    value = (WMGetButtonSelected(panel->alwChk)!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AAlwaysUserIcon, value, flags);

    value = (WMGetButtonSelected(panel->attrChk[0])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ANoTitlebar,     value, flags);

    value = (WMGetButtonSelected(panel->attrChk[1])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ANoResizebar,     value, flags);

    value = (WMGetButtonSelected(panel->attrChk[2])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ANoCloseButton,   value, flags);

    value = (WMGetButtonSelected(panel->attrChk[3])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ANoMiniaturizeButton, value, flags);

    value = (WMGetButtonSelected(panel->attrChk[4])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ANoBorder, value, flags);

    value = (WMGetButtonSelected(panel->attrChk[5])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AKeepOnTop,       value, flags);

    value = (WMGetButtonSelected(panel->attrChk[6])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AKeepOnBottom,    value, flags);

    value = (WMGetButtonSelected(panel->attrChk[7])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AOmnipresent,     value, flags);

    value = (WMGetButtonSelected(panel->attrChk[8])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AStartMiniaturized, value, flags);

    value = (WMGetButtonSelected(panel->attrChk[9])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AStartMaximized,  value, flags);

    value = (WMGetButtonSelected(panel->attrChk[10])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AFullMaximize,  value, flags);


    value = (WMGetButtonSelected(panel->moreChk[0])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ANoKeyBindings,   value, flags);

    value = (WMGetButtonSelected(panel->moreChk[1])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ANoMouseBindings, value, flags);

    value = (WMGetButtonSelected(panel->moreChk[2])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ASkipWindowList, value, flags);

    value = (WMGetButtonSelected(panel->moreChk[3])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AUnfocusable, value, flags);

    value = (WMGetButtonSelected(panel->moreChk[4])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AKeepInsideScreen,value, flags);

    value = (WMGetButtonSelected(panel->moreChk[5])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ANoHideOthers,    value, flags);

    value = (WMGetButtonSelected(panel->moreChk[6])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, ADontSaveSession, value, flags);

    value = (WMGetButtonSelected(panel->moreChk[7])!=0) ? Yes : No;
    different |= insertAttribute(dict, winDic, AEmulateAppIcon,  value, flags);


    if (wwin->main_window!=None && wApplicationOf(wwin->main_window)!=NULL) {
        value = (WMGetButtonSelected(panel->appChk[0])!=0) ? Yes : No;
        different2 |= insertAttribute(dict, appDic, AStartHidden, value, flags);

        value = (WMGetButtonSelected(panel->appChk[1])!=0) ? Yes : No;
        different2 |= insertAttribute(dict, appDic, ANoAppIcon, value, flags);

        value = (WMGetButtonSelected(panel->appChk[2])!=0) ? Yes : No;
        different2 |= insertAttribute(dict, appDic, ASharedAppIcon, value, flags);
    }

    if (wwin->fake_group) {
        key2 = WMCreatePLString(wwin->fake_group->identifier);
        if (WMIsPropListEqualTo(key, key2)) {
            WMMergePLDictionaries(winDic, appDic, True);
            different |= different2;
        } else {
            WMRemoveFromPLDictionary(dict, key2);
            if (different2) {
                WMPutInPLDictionary(dict, key2, appDic);
            }
        }
        WMReleasePropList(key2);
        WMReleasePropList(appDic);
    } else if (wwin->main_window != wwin->client_win) {
        WApplication *wapp = wApplicationOf(wwin->main_window);

        if (wapp) {
            char *instance = wapp->main_window_desc->wm_instance;
            char *class = wapp->main_window_desc->wm_class;
            char *buffer;

            buffer = StrConcatDot(instance, class);
            key2 = WMCreatePLString(buffer);
            wfree(buffer);

            if (WMIsPropListEqualTo(key, key2)) {
                WMMergePLDictionaries(winDic, appDic, True);
                different |= different2;
            } else {
                WMRemoveFromPLDictionary(dict, key2);
                if (different2) {
                    WMPutInPLDictionary(dict, key2, appDic);
                }
            }
            WMReleasePropList(key2);
            WMReleasePropList(appDic);
        }
    } else {
        WMMergePLDictionaries(winDic, appDic, True);
        different |= different2;
        WMReleasePropList(appDic);
    }

    WMRemoveFromPLDictionary(dict, key);
    if (different) {
        WMPutInPLDictionary(dict, key, winDic);
    }

    WMReleasePropList(key);
    WMReleasePropList(winDic);

    UpdateDomainFile(db);

    /* clean up */
    WMPLSetCaseSensitive(False);
}


static void
makeAppIconFor(WApplication *wapp)
{
    WScreen *scr = wapp->main_window_desc->screen_ptr;

    if (wapp->app_icon)
        return;

    if (!WFLAGP(wapp->main_window_desc, no_appicon))
        wapp->app_icon = wAppIconCreate(wapp->main_window_desc);
    else
        wapp->app_icon = NULL;

    if (wapp->app_icon) {
        WIcon *icon = wapp->app_icon->icon;
        WDock *clip = scr->workspaces[scr->current_workspace]->clip;
        int x=0, y=0;

        wapp->app_icon->main_window = wapp->main_window;

        if (clip && clip->attract_icons && wDockFindFreeSlot(clip, &x, &y)) {
            wapp->app_icon->attracted = 1;
            if (!wapp->app_icon->icon->shadowed) {
                wapp->app_icon->icon->shadowed = 1;
                wapp->app_icon->icon->force_paint = 1;
            }
            wDockAttachIcon(clip, wapp->app_icon, x, y);
        } else {
            PlaceIcon(scr, &x, &y, wGetHeadForWindow(wapp->main_window_desc));
            wAppIconMove(wapp->app_icon, x, y);
        }
        if (!clip || !wapp->app_icon->attracted || !clip->collapsed)
            XMapWindow(dpy, icon->core->window);

        if (wPreferences.auto_arrange_icons && !wapp->app_icon->attracted)
            wArrangeIcons(wapp->main_window_desc->screen_ptr, True);
    }
}


static void
removeAppIconFor(WApplication *wapp)
{
    if (!wapp->app_icon)
        return;

    if (wapp->app_icon->docked && !wapp->app_icon->attracted) {
        wapp->app_icon->running = 0;
        /* since we keep it, we don't care if it was attracted or not */
        wapp->app_icon->attracted = 0;
        wapp->app_icon->icon->shadowed = 0;
        wapp->app_icon->main_window = None;
        wapp->app_icon->pid = 0;
        wapp->app_icon->icon->owner = NULL;
        wapp->app_icon->icon->icon_win = None;
        wapp->app_icon->icon->force_paint = 1;
        wAppIconPaint(wapp->app_icon);
    } else if (wapp->app_icon->docked) {
        wapp->app_icon->running = 0;
        wDockDetach(wapp->app_icon->dock, wapp->app_icon);
    } else {
        wAppIconDestroy(wapp->app_icon);
    }
    wapp->app_icon = NULL;
    if (wPreferences.auto_arrange_icons)
        wArrangeIcons(wapp->main_window_desc->screen_ptr, True);
}


static void
applySettings(WMButton *button, InspectorPanel *panel)
{
    WWindow *wwin = panel->inspected;
    WApplication *wapp = wApplicationOf(wwin->main_window);
    int floating, sunken, skip_window_list;
    int old_omnipresent;
    int old_no_bind_keys;
    int old_no_bind_mouse;

    old_omnipresent = WFLAGP(wwin, omnipresent);
    old_no_bind_keys = WFLAGP(wwin, no_bind_keys);
    old_no_bind_mouse = WFLAGP(wwin, no_bind_mouse);

    showIconFor(WMWidgetScreen(button), panel, NULL, NULL, USE_TEXT_FIELD);

    WSETUFLAG(wwin, no_titlebar, WMGetButtonSelected(panel->attrChk[0]));
    WSETUFLAG(wwin, no_resizebar, WMGetButtonSelected(panel->attrChk[1]));
    WSETUFLAG(wwin, no_close_button, WMGetButtonSelected(panel->attrChk[2]));
    WSETUFLAG(wwin, no_miniaturize_button, WMGetButtonSelected(panel->attrChk[3]));
    WSETUFLAG(wwin, no_border, WMGetButtonSelected(panel->attrChk[4]));
    floating = WMGetButtonSelected(panel->attrChk[5]);
    sunken   = WMGetButtonSelected(panel->attrChk[6]);
    WSETUFLAG(wwin, omnipresent, WMGetButtonSelected(panel->attrChk[7]));
    WSETUFLAG(wwin, start_miniaturized, WMGetButtonSelected(panel->attrChk[8]));
    WSETUFLAG(wwin, start_maximized, WMGetButtonSelected(panel->attrChk[9]));
    WSETUFLAG(wwin, full_maximize, WMGetButtonSelected(panel->attrChk[10]));

    WSETUFLAG(wwin, no_bind_keys, WMGetButtonSelected(panel->moreChk[0]));
    WSETUFLAG(wwin, no_bind_mouse, WMGetButtonSelected(panel->moreChk[1]));
    skip_window_list = WMGetButtonSelected(panel->moreChk[2]);
    WSETUFLAG(wwin, no_focusable, WMGetButtonSelected(panel->moreChk[3]));
    WSETUFLAG(wwin, dont_move_off, WMGetButtonSelected(panel->moreChk[4]));
    WSETUFLAG(wwin, no_hide_others, WMGetButtonSelected(panel->moreChk[5]));
    WSETUFLAG(wwin, dont_save_session, WMGetButtonSelected(panel->moreChk[6]));
    WSETUFLAG(wwin, emulate_appicon, WMGetButtonSelected(panel->moreChk[7]));
    WSETUFLAG(wwin, always_user_icon, WMGetButtonSelected(panel->alwChk));

    if (WFLAGP(wwin, no_titlebar) && wwin->flags.shaded)
        wUnshadeWindow(wwin);

    WSETUFLAG(wwin, no_shadeable, WFLAGP(wwin, no_titlebar));

    if (floating) {
        if (!WFLAGP(wwin, floating))
            ChangeStackingLevel(wwin->frame->core, WMFloatingLevel);
    } else if (sunken) {
        if (!WFLAGP(wwin, sunken))
            ChangeStackingLevel(wwin->frame->core, WMSunkenLevel);
    } else {
        if (WFLAGP(wwin, floating) || WFLAGP(wwin, sunken))
            ChangeStackingLevel(wwin->frame->core, WMNormalLevel);
    }

    WSETUFLAG(wwin, sunken, sunken);
    WSETUFLAG(wwin, floating, floating);
    wwin->flags.omnipresent = 0;

    if (WFLAGP(wwin, skip_window_list) != skip_window_list) {
        WSETUFLAG(wwin, skip_window_list, skip_window_list);
        UpdateSwitchMenu(wwin->screen_ptr, wwin,
                         skip_window_list ? ACTION_REMOVE : ACTION_ADD);
    } else {
        if (WFLAGP(wwin, omnipresent) != old_omnipresent) {
            WMPostNotificationName(WMNChangedState, wwin, "omnipresent");
        }
    }

    if (WFLAGP(wwin, no_bind_keys) != old_no_bind_keys) {
        if (WFLAGP(wwin, no_bind_keys)) {
            XUngrabKey(dpy, AnyKey, AnyModifier, wwin->frame->core->window);
        } else {
            wWindowSetKeyGrabs(wwin);
        }
    }

    if (WFLAGP(wwin, no_bind_mouse) != old_no_bind_mouse) {
        wWindowResetMouseGrabs(wwin);
    }

    wwin->frame->flags.need_texture_change = 1;
    wWindowConfigureBorders(wwin);
    wFrameWindowPaint(wwin->frame);
#ifdef NETWM_HINTS
    wNETWMUpdateActions(wwin, False);
#endif

    /*
     * Can't apply emulate_appicon because it will probably cause problems.
     */

    if (wapp) {
        /* do application wide stuff */
        WSETUFLAG(wapp->main_window_desc, start_hidden,
                  WMGetButtonSelected(panel->appChk[0]));

        WSETUFLAG(wapp->main_window_desc, no_appicon,
                  WMGetButtonSelected(panel->appChk[1]));

        WSETUFLAG(wapp->main_window_desc, shared_appicon,
                  WMGetButtonSelected(panel->appChk[2]));

        if (WFLAGP(wapp->main_window_desc, no_appicon))
            removeAppIconFor(wapp);
        else
            makeAppIconFor(wapp);

        if (wapp->app_icon && wapp->main_window == wwin->client_win) {
            char *file = WMGetTextFieldText(panel->fileText);

            if (file[0] == 0) {
                wfree(file);
                file = NULL;
            }
            wIconChangeImageFile(wapp->app_icon->icon, file);
            if (file)
                wfree(file);
            wAppIconPaint(wapp->app_icon);
        }
    }
}




static void
revertSettings(WMButton *button, InspectorPanel *panel)
{
    WWindow *wwin = panel->inspected;
    WApplication *wapp = wApplicationOf(wwin->main_window);
    int i, n;
    char *wm_instance = NULL;
    char *wm_class = NULL;
    int workspace, level;

    if (panel->instRb && WMGetButtonSelected(panel->instRb) != 0)
        wm_instance = wwin->wm_instance;
    else if (panel->clsRb && WMGetButtonSelected(panel->clsRb) != 0)
        wm_class = wwin->wm_class;
    else if (panel->bothRb && WMGetButtonSelected(panel->bothRb) != 0) {
        wm_instance = wwin->wm_instance;
        wm_class = wwin->wm_class;
    }
    memset(&wwin->defined_user_flags, 0, sizeof(WWindowAttributes));
    memset(&wwin->user_flags, 0, sizeof(WWindowAttributes));
    memset(&wwin->client_flags, 0, sizeof(WWindowAttributes));

    wWindowSetupInitialAttributes(wwin, &level, &workspace);

    for (i=0; i < 11; i++) {
        int flag = 0;

        switch (i) {
        case 0:
            flag = WFLAGP(wwin, no_titlebar);
            break;
        case 1:
            flag = WFLAGP(wwin, no_resizebar);
            break;
        case 2:
            flag = WFLAGP(wwin, no_close_button);
            break;
        case 3:
            flag = WFLAGP(wwin, no_miniaturize_button);
            break;
        case 4:
            flag = WFLAGP(wwin, no_border);
            break;
        case 5:
            flag = WFLAGP(wwin, floating);
            break;
        case 6:
            flag = WFLAGP(wwin, sunken);
            break;
        case 7:
            flag = WFLAGP(wwin, omnipresent);
            break;
        case 8:
            flag = WFLAGP(wwin, start_miniaturized);
            break;
        case 9:
            flag = WFLAGP(wwin, start_maximized!=0);
            break;
        case 10:
            flag = WFLAGP(wwin, full_maximize);
            break;
        }
        WMSetButtonSelected(panel->attrChk[i], flag);
    }
    for (i=0; i < 8; i++) {
        int flag = 0;

        switch (i) {
        case 0:
            flag = WFLAGP(wwin, no_bind_keys);
            break;
        case 1:
            flag = WFLAGP(wwin, no_bind_mouse);
            break;
        case 2:
            flag = WFLAGP(wwin, skip_window_list);
            break;
        case 3:
            flag = WFLAGP(wwin, no_focusable);
            break;
        case 4:
            flag = WFLAGP(wwin, dont_move_off);
            break;
        case 5:
            flag = WFLAGP(wwin, no_hide_others);
            break;
        case 6:
            flag = WFLAGP(wwin, dont_save_session);
            break;
        case 7:
            flag = WFLAGP(wwin, emulate_appicon);
            break;
        }
        WMSetButtonSelected(panel->moreChk[i], flag);
    }
    if (panel->appFrm && wapp) {
        for (i=0; i < 2; i++) {
            int flag = 0;

            switch (i) {
            case 0:
                flag = WFLAGP(wapp->main_window_desc, start_hidden);
                break;
            case 1:
                flag = WFLAGP(wapp->main_window_desc, no_appicon);
                break;
            case 2:
                flag = WFLAGP(wapp->main_window_desc, shared_appicon);
                break;
            }
            WMSetButtonSelected(panel->appChk[i], flag);
        }
    }
    WMSetButtonSelected(panel->alwChk, WFLAGP(wwin, always_user_icon));

    showIconFor(WMWidgetScreen(panel->alwChk), panel, wm_instance, wm_class,
                REVERT_TO_DEFAULT);

    n = wDefaultGetStartWorkspace(wwin->screen_ptr, wm_instance, wm_class);

    if (n >= 0 && n < wwin->screen_ptr->workspace_count) {
        WMSetPopUpButtonSelectedItem(panel->wsP, n+1);
    } else {
        WMSetPopUpButtonSelectedItem(panel->wsP, 0);
    }

    /* must auto apply, so that there wno't be internal
     * inconsistencies between the state in the flags and
     * the actual state of the window */
    applySettings(panel->applyBtn, panel);
}


static void
chooseIconCallback(WMWidget *self, void *clientData)
{
    char *file;
    InspectorPanel *panel = (InspectorPanel*)clientData;
    int result;

    panel->choosingIcon = 1;

    WMSetButtonEnabled(panel->browseIconBtn, False);

    result = wIconChooserDialog(panel->frame->screen_ptr, &file,
                                panel->inspected->wm_instance,
                                panel->inspected->wm_class);

    panel->choosingIcon = 0;

    if (!panel->destroyed) { /* kluge */
        if (result) {
            WMSetTextFieldText(panel->fileText, file);
            showIconFor(WMWidgetScreen(self), panel, NULL, NULL,
                        USE_TEXT_FIELD);
            wfree(file);
        }
        WMSetButtonEnabled(panel->browseIconBtn, True);
    } else {
        freeInspector(panel);
    }
}


static void
textEditedObserver(void *observerData, WMNotification *notification)
{
    InspectorPanel *panel = (InspectorPanel*)observerData;

    if ((long)WMGetNotificationClientData(notification) != WMReturnTextMovement)
        return;

    showIconFor(WMWidgetScreen(panel->win), panel, NULL, NULL,
                USE_TEXT_FIELD);
    /*
     WMPerformButtonClick(panel->updateIconBtn);
     */
}


static void
selectSpecification(WMWidget *bPtr, void *data)
{
    InspectorPanel *panel = (InspectorPanel*)data;
    char *str;
    WWindow *wwin = panel->inspected;
    int len;

    if (bPtr == panel->defaultRb && (wwin->wm_instance || wwin->wm_class)) {
        WMSetButtonEnabled(panel->applyBtn, False);
    } else {
        WMSetButtonEnabled(panel->applyBtn, True);
    }

    len = 16 + strlen(wwin->wm_instance ? wwin->wm_instance : "?")
        + strlen(wwin->wm_class ? wwin->wm_class : "?");

    str = wmalloc(len);

    snprintf(str, len, _("Inspecting  %s.%s"),
             wwin->wm_instance ? wwin->wm_instance : "?",
             wwin->wm_class ? wwin->wm_class : "?");

    wFrameWindowChangeTitle(panel->frame->frame, str);

    wfree(str);
}


static void
selectWindow(WMWidget *bPtr, void *data)
{
    InspectorPanel *panel = (InspectorPanel*)data;
    WWindow *wwin = panel->inspected;
    WScreen *scr = wwin->screen_ptr;
    XEvent event;
    WWindow *iwin;

    if (XGrabPointer(dpy, scr->root_win, True,
                     ButtonPressMask, GrabModeAsync, GrabModeAsync, None,
                     wCursor[WCUR_SELECT], CurrentTime)!=GrabSuccess) {
        wwarning("could not grab mouse pointer");
        return;
    }

    WMSetLabelText(panel->specLbl, _("Click in the window you wish to inspect."));

    WMMaskEvent(dpy, ButtonPressMask, &event);

    XUngrabPointer(dpy, CurrentTime);

    iwin = wWindowFor(event.xbutton.subwindow);

    if (iwin && !iwin->flags.internal_window && iwin != wwin
        && !iwin->flags.inspector_open) {

        iwin->flags.inspector_open = 1;
        iwin->inspector = createInspectorForWindow(iwin,
                                                   panel->frame->frame_x,
                                                   panel->frame->frame_y,
                                                   True);
        wCloseInspectorForWindow(wwin);
    } else {
        WMSetLabelText(panel->specLbl, spec_text);
    }
}



static InspectorPanel*
createInspectorForWindow(WWindow *wwin, int xpos, int ypos,
                         Bool showSelectPanel)
{
    WScreen *scr = wwin->screen_ptr;
    InspectorPanel *panel;
    Window parent;
    int i;
    int x, y;
    int btn_width, frame_width;
    WMButton *selectedBtn = NULL;
#ifdef wrong_behaviour
    WMPixmap *pixmap;
#endif

    spec_text = _("The configuration will apply to all\n"
                  "windows that have their WM_CLASS\n"
                  "property set to the above selected\n"
                  "name, when saved.");

    panel = wmalloc(sizeof(InspectorPanel));
    memset(panel, 0, sizeof(InspectorPanel));

    panel->destroyed = 0;


    panel->inspected = wwin;

    panel->nextPtr = panelList;
    panelList = panel;


    panel->win = WMCreateWindow(scr->wmscreen, "windowInspector");
    WMResizeWidget(panel->win, PWIDTH, PHEIGHT);


    /**** create common stuff ****/

    /* command buttons */
    /* (PWIDTH - (left and right margin) - (btn interval)) / 3 */
    btn_width = (PWIDTH - (2 * 15) - (2 * 10)) / 3;
    panel->saveBtn = WMCreateCommandButton(panel->win);
    WMSetButtonAction(panel->saveBtn, (WMAction*)saveSettings, panel);
    WMMoveWidget(panel->saveBtn, (2 * (btn_width + 10)) + 15, 310);
    WMSetButtonText(panel->saveBtn, _("Save"));
    WMResizeWidget(panel->saveBtn, btn_width, 28);
    if (wPreferences.flags.noupdates || !(wwin->wm_class || wwin->wm_instance))
        WMSetButtonEnabled(panel->saveBtn, False);

    panel->applyBtn = WMCreateCommandButton(panel->win);
    WMSetButtonAction(panel->applyBtn, (WMAction*)applySettings, panel);
    WMMoveWidget(panel->applyBtn, btn_width + 10 + 15, 310);
    WMSetButtonText(panel->applyBtn, _("Apply"));
    WMResizeWidget(panel->applyBtn, btn_width, 28);

    panel->revertBtn = WMCreateCommandButton(panel->win);
    WMSetButtonAction(panel->revertBtn, (WMAction*)revertSettings, panel);
    WMMoveWidget(panel->revertBtn, 15, 310);
    WMSetButtonText(panel->revertBtn, _("Reload"));
    WMResizeWidget(panel->revertBtn, btn_width, 28);

    /* page selection popup button */
    panel->pagePopUp = WMCreatePopUpButton(panel->win);
    WMSetPopUpButtonAction(panel->pagePopUp, (WMAction*)changePage, panel);
    WMMoveWidget(panel->pagePopUp, 25, 15);
    WMResizeWidget(panel->pagePopUp, PWIDTH - 50, 20);

    WMAddPopUpButtonItem(panel->pagePopUp, _("Window Specification"));
    WMAddPopUpButtonItem(panel->pagePopUp, _("Window Attributes"));
    WMAddPopUpButtonItem(panel->pagePopUp, _("Advanced Options"));
    WMAddPopUpButtonItem(panel->pagePopUp, _("Icon and Initial Workspace"));
    WMAddPopUpButtonItem(panel->pagePopUp, _("Application Specific"));

    /**** window spec ****/
    frame_width = PWIDTH - (2 * 15);

    panel->specFrm = WMCreateFrame(panel->win);
    WMSetFrameTitle(panel->specFrm, _("Window Specification"));
    WMMoveWidget(panel->specFrm, 15, 65);
    WMResizeWidget(panel->specFrm, frame_width, 145);


    panel->defaultRb = WMCreateRadioButton(panel->specFrm);
    WMMoveWidget(panel->defaultRb, 10, 78);
    WMResizeWidget(panel->defaultRb, frame_width - (2 * 10), 20);
    WMSetButtonText(panel->defaultRb, _("Defaults for all windows"));
    WMSetButtonSelected(panel->defaultRb, False);
    WMSetButtonAction(panel->defaultRb, selectSpecification, panel);

    if (wwin->wm_class && wwin->wm_instance) {
        char *str, *tmp;

        tmp = wstrconcat(wwin->wm_instance, ".");
        str = wstrconcat(tmp, wwin->wm_class);

        panel->bothRb = WMCreateRadioButton(panel->specFrm);
        WMMoveWidget(panel->bothRb, 10, 18);
        WMResizeWidget(panel->bothRb, frame_width - (2 * 10), 20);
        WMSetButtonText(panel->bothRb, str);
        wfree(tmp);
        wfree(str);
        WMGroupButtons(panel->defaultRb, panel->bothRb);

        if (!selectedBtn)
            selectedBtn = panel->bothRb;

        WMSetButtonAction(panel->bothRb, selectSpecification, panel);
    }

    if (wwin->wm_instance) {
        panel->instRb = WMCreateRadioButton(panel->specFrm);
        WMMoveWidget(panel->instRb, 10, 38);
        WMResizeWidget(panel->instRb, frame_width - (2 * 10), 20);
        WMSetButtonText(panel->instRb, wwin->wm_instance);
        WMGroupButtons(panel->defaultRb, panel->instRb);

        if (!selectedBtn)
            selectedBtn = panel->instRb;

        WMSetButtonAction(panel->instRb, selectSpecification, panel);
    }

    if (wwin->wm_class) {
        panel->clsRb = WMCreateRadioButton(panel->specFrm);
        WMMoveWidget(panel->clsRb, 10, 58);
        WMResizeWidget(panel->clsRb, frame_width - (2 * 10), 20);
        WMSetButtonText(panel->clsRb, wwin->wm_class);
        WMGroupButtons(panel->defaultRb, panel->clsRb);

        if (!selectedBtn)
            selectedBtn = panel->clsRb;

        WMSetButtonAction(panel->clsRb, selectSpecification, panel);
    }


    panel->selWinB = WMCreateCommandButton(panel->specFrm);
    WMMoveWidget(panel->selWinB, 20, 145-24 - 10);
    WMResizeWidget(panel->selWinB, frame_width - 2*10 - 20, 24);
    WMSetButtonText(panel->selWinB, _("Select window"));
    WMSetButtonAction(panel->selWinB, selectWindow, panel);


    panel->specLbl = WMCreateLabel(panel->win);
    WMMoveWidget(panel->specLbl, 15, 210);
    WMResizeWidget(panel->specLbl, frame_width, 100);
    WMSetLabelText(panel->specLbl, spec_text);
    WMSetLabelWraps(panel->specLbl, True);

    WMSetLabelTextAlignment(panel->specLbl, WALeft);

    /**** attributes ****/
    panel->attrFrm = WMCreateFrame(panel->win);
    WMSetFrameTitle(panel->attrFrm, _("Attributes"));
    WMMoveWidget(panel->attrFrm, 15, 45);
    WMResizeWidget(panel->attrFrm, frame_width, 250);

    for (i=0; i < 11; i++) {
        char *caption = NULL;
        int flag = 0;
        char *descr = NULL;

        switch (i) {
        case 0:
            caption = _("Disable titlebar");
            flag = WFLAGP(wwin, no_titlebar);
            descr = _("Remove the titlebar of this window.\n"
                      "To access the window commands menu of a window\n"
                      "without it's titlebar, press Control+Esc (or the\n"
                      "equivalent shortcut, if you changed the default\n"
                      "settings).");
            break;
        case 1:
            caption = _("Disable resizebar");
            flag = WFLAGP(wwin, no_resizebar);
            descr = _("Remove the resizebar of this window.");
            break;
        case 2:
            caption = _("Disable close button");
            flag = WFLAGP(wwin, no_close_button);
            descr = _("Remove the `close window' button of this window.");
            break;
        case 3:
            caption = _("Disable miniaturize button");
            flag = WFLAGP(wwin, no_miniaturize_button);
            descr = _("Remove the `miniaturize window' button of the window.");
            break;
        case 4:
            caption = _("Disable border");
            flag = WFLAGP(wwin, no_border);
            descr = _("Remove the 1 pixel black border around the window.");
            break;
        case 5:
            caption = _("Keep on top (floating)");
            flag = WFLAGP(wwin, floating);
            descr = _("Keep the window over other windows, not allowing\n"
                      "them to cover it.");
            break;
        case 6:
            caption = _("Keep at bottom (sunken)");
            flag = WFLAGP(wwin, sunken);
            descr = _("Keep the window under all other windows.");
            break;
        case 7:
            caption = _("Omnipresent");
            flag = WFLAGP(wwin, omnipresent);
            descr = _("Make window present in all workspaces.");
            break;
        case 8:
            caption = _("Start miniaturized");
            flag = WFLAGP(wwin, start_miniaturized);
            descr = _("Make the window be automatically miniaturized when it's\n"
                      "first shown.");
            break;
        case 9:
            caption = _("Start maximized");
            flag = WFLAGP(wwin, start_maximized!=0);
            descr = _("Make the window be automatically maximized when it's\n"
                      "first shown.");
            break;
        case 10:
            caption = _("Full screen maximization");
            flag = WFLAGP(wwin, full_maximize);
            descr = _("Make the window use the whole screen space when it's\n"
                      "maximized. The titlebar and resizebar will be moved\n"
                      "to outside the screen.");
            break;
        }
        panel->attrChk[i] = WMCreateSwitchButton(panel->attrFrm);
        WMMoveWidget(panel->attrChk[i], 10, 20*(i+1));
        WMResizeWidget(panel->attrChk[i], frame_width-15, 20);
        WMSetButtonSelected(panel->attrChk[i], flag);
        WMSetButtonText(panel->attrChk[i], caption);

        WMSetBalloonTextForView(descr, WMWidgetView(panel->attrChk[i]));
    }


    /**** more attributes ****/
    panel->moreFrm = WMCreateFrame(panel->win);
    WMSetFrameTitle(panel->moreFrm, _("Advanced"));
    WMMoveWidget(panel->moreFrm, 15, 45);
    WMResizeWidget(panel->moreFrm, frame_width, 250);

    for (i=0; i < 8; i++) {
        char *caption = NULL;
        int flag = 0;
        char *descr = NULL;

        switch (i) {
        case 0:
            caption = _("Do not bind keyboard shortcuts");
            flag = WFLAGP(wwin, no_bind_keys);
            descr = _("Do not bind keyboard shortcuts from Window Maker\n"
                      "when this window is focused. This will allow the\n"
                      "window to receive all key combinations regardless\n"
                      "of your shortcut configuration.");
            break;
        case 1:
            caption = _("Do not bind mouse clicks");
            flag = WFLAGP(wwin, no_bind_mouse);
            descr = _("Do not bind mouse actions, such as `Alt'+drag\n"
                      "in the window (when alt is the modifier you have\n"
                      "configured).");
            break;
        case 2:
            caption = _("Do not show in the window list");
            flag = WFLAGP(wwin, skip_window_list);
            descr = _("Do not list the window in the window list menu.");
            break;
        case 3:
            caption = _("Do not let it take focus");
            flag = WFLAGP(wwin, no_focusable);
            descr = _("Do not let the window take keyboard focus when you\n"
                      "click on it.");
            break;
        case 4:
            caption = _("Keep inside screen");
            flag = WFLAGP(wwin, dont_move_off);
            descr = _("Do not allow the window to move itself completely\n"
                      "outside the screen. For bug compatibility.\n");
            break;
        case 5:
            caption = _("Ignore 'Hide Others'");
            flag = WFLAGP(wwin, no_hide_others);
            descr = _("Do not hide the window when issuing the\n"
                      "`HideOthers' command.");
            break;
        case 6:
            caption = _("Ignore 'Save Session'");
            flag = WFLAGP(wwin, dont_save_session);
            descr = _("Do not save the associated application in the\n"
                      "session's state, so that it won't be restarted\n"
                      "together with other applications when Window Maker\n"
                      "starts.");
            break;
        case 7:
            caption = _("Emulate application icon");
            flag = WFLAGP(wwin, emulate_appicon);
            descr = _("Make this window act as an application that provides\n"
                      "enough information to Window Maker for a dockable\n"
                      "application icon to be created.");
            break;
        }
        panel->moreChk[i] = WMCreateSwitchButton(panel->moreFrm);
        WMMoveWidget(panel->moreChk[i], 10, 20*(i+1));
        WMResizeWidget(panel->moreChk[i], frame_width-15, 20);
        WMSetButtonSelected(panel->moreChk[i], flag);
        WMSetButtonText(panel->moreChk[i], caption);

        WMSetBalloonTextForView(descr, WMWidgetView(panel->moreChk[i]));
    }

    /* miniwindow/workspace */
    panel->iconFrm = WMCreateFrame(panel->win);
    WMMoveWidget(panel->iconFrm, 15, 50);
    WMResizeWidget(panel->iconFrm,  PWIDTH - (2 * 15), 170);
    WMSetFrameTitle(panel->iconFrm, _("Miniwindow Image"));

    panel->iconLbl = WMCreateLabel(panel->iconFrm);
    WMMoveWidget(panel->iconLbl, PWIDTH - (2 * 15) - 22 - 64, 20);
    WMResizeWidget(panel->iconLbl, 64, 64);
    WMSetLabelRelief(panel->iconLbl, WRGroove);
    WMSetLabelImagePosition(panel->iconLbl, WIPImageOnly);

    panel->browseIconBtn = WMCreateCommandButton(panel->iconFrm);
    WMSetButtonAction(panel->browseIconBtn, chooseIconCallback, panel);
    WMMoveWidget(panel->browseIconBtn, 22, 32);
    WMResizeWidget(panel->browseIconBtn, 120, 26);
    WMSetButtonText(panel->browseIconBtn, _("Browse..."));

#ifdef wrong_behaviour
    WMSetButtonImagePosition(panel->updateIconBtn, WIPRight);
    pixmap = WMGetSystemPixmap(scr->wmscreen, WSIReturnArrow);
    WMSetButtonImage(panel->updateIconBtn, pixmap);
    WMReleasePixmap(pixmap);
    pixmap = WMGetSystemPixmap(scr->wmscreen, WSIHighlightedReturnArrow);
    WMSetButtonAltImage(panel->updateIconBtn, pixmap);
    WMReleasePixmap(pixmap);
#endif

    panel->fileLbl = WMCreateLabel(panel->iconFrm);
    WMMoveWidget(panel->fileLbl, 20, 85);
    WMResizeWidget(panel->fileLbl, PWIDTH - (2 * 15) - (2 * 20), 14);
    WMSetLabelText(panel->fileLbl, _("Icon filename:"));

    panel->fileText = WMCreateTextField(panel->iconFrm);
    WMMoveWidget(panel->fileText, 20, 105);
    WMResizeWidget(panel->fileText, PWIDTH - (2 * 20) - (2 * 15), 20);
    WMSetTextFieldText(panel->fileText, NULL);
    WMAddNotificationObserver(textEditedObserver, panel,
                              WMTextDidEndEditingNotification,
                              panel->fileText);

    panel->alwChk = WMCreateSwitchButton(panel->iconFrm);
    WMMoveWidget(panel->alwChk, 20, 130);
    WMResizeWidget(panel->alwChk, PWIDTH - (2 * 15) - (2 * 15), 30);
    WMSetButtonText(panel->alwChk, _("Ignore client supplied icon"));
    WMSetButtonSelected(panel->alwChk, WFLAGP(wwin, always_user_icon));


    panel->wsFrm = WMCreateFrame(panel->win);
    WMMoveWidget(panel->wsFrm, 15, 225);
    WMResizeWidget(panel->wsFrm, PWIDTH - (2 * 15), 70);
    WMSetFrameTitle(panel->wsFrm, _("Initial Workspace"));

    WMSetBalloonTextForView(_("The workspace to place the window when it's"
                              "first shown."), WMWidgetView(panel->wsFrm));

    panel->wsP = WMCreatePopUpButton(panel->wsFrm);
    WMMoveWidget(panel->wsP, 20, 30);
    WMResizeWidget(panel->wsP, PWIDTH - (2 * 15) - (2 * 20), 20);
    WMAddPopUpButtonItem(panel->wsP, _("Nowhere in particular"));
    for (i = 0; i < wwin->screen_ptr->workspace_count; i++) {
        WMAddPopUpButtonItem(panel->wsP, scr->workspaces[i]->name);
    }

    i = wDefaultGetStartWorkspace(wwin->screen_ptr, wwin->wm_instance,
                                  wwin->wm_class);
    if (i >= 0 && i <= wwin->screen_ptr->workspace_count) {
        WMSetPopUpButtonSelectedItem(panel->wsP, i + 1);
    } else {
        WMSetPopUpButtonSelectedItem(panel->wsP, 0);
    }

    /* application wide attributes */
    if (wwin->main_window != None) {
        WApplication *wapp = wApplicationOf(wwin->main_window);

        panel->appFrm = WMCreateFrame(panel->win);
        WMSetFrameTitle(panel->appFrm, _("Application Attributes"));
        WMMoveWidget(panel->appFrm, 15, 50);
        WMResizeWidget(panel->appFrm, frame_width, 240);

        for (i=0; i < 3; i++) {
            char *caption = NULL;
            int flag = 0;
            char *descr = NULL;

            switch (i) {
            case 0:
                caption = _("Start hidden");
                flag = WFLAGP(wapp->main_window_desc, start_hidden);
                descr = _("Automatically hide application when it's started.");
                break;
            case 1:
                caption = _("No application icon");
                flag = WFLAGP(wapp->main_window_desc, no_appicon);
                descr = _("Disable the application icon for the application.\n"
                          "Note that you won't be able to dock it anymore,\n"
                          "and any icons that are already docked will stop\n"
                          "working correctly.");
                break;
            case 2:
                caption = _("Shared application icon");
                flag = WFLAGP(wapp->main_window_desc, shared_appicon);
                descr = _("Use a single shared application icon for all of\n"
                          "the instances of this application.\n");
                break;
            }
            panel->appChk[i] = WMCreateSwitchButton(panel->appFrm);
            WMMoveWidget(panel->appChk[i], 10, 20*(i+1));
            WMResizeWidget(panel->appChk[i], 205, 20);
            WMSetButtonSelected(panel->appChk[i], flag);
            WMSetButtonText(panel->appChk[i], caption);

            WMSetBalloonTextForView(descr, WMWidgetView(panel->appChk[i]));
        }

        if (WFLAGP(wwin, emulate_appicon)) {
            WMSetButtonEnabled(panel->appChk[1], False);
            WMSetButtonEnabled(panel->moreChk[7], True);
        } else {
            WMSetButtonEnabled(panel->appChk[1], True);
            WMSetButtonEnabled(panel->moreChk[7], False);
        }
    } else {
        int tmp;

        if ((wwin->transient_for!=None && wwin->transient_for!=scr->root_win)
            || !wwin->wm_class || !wwin->wm_instance)
            tmp = False;
        else
            tmp = True;
        WMSetButtonEnabled(panel->moreChk[7], tmp);

        WMSetPopUpButtonItemEnabled(panel->pagePopUp, 4, False);
        panel->appFrm = NULL;
    }

    /* if the window is a transient, don't let it have a miniaturize
     * button */
    if (wwin->transient_for!=None && wwin->transient_for!=scr->root_win)
        WMSetButtonEnabled(panel->attrChk[3], False);
    else
        WMSetButtonEnabled(panel->attrChk[3], True);


    if (!wwin->wm_class && !wwin->wm_instance) {
        WMSetPopUpButtonItemEnabled(panel->pagePopUp, 0, False);
    }


    WMRealizeWidget(panel->win);

    WMMapSubwidgets(panel->win);
    WMMapSubwidgets(panel->specFrm);
    WMMapSubwidgets(panel->attrFrm);
    WMMapSubwidgets(panel->moreFrm);
    WMMapSubwidgets(panel->iconFrm);
    WMMapSubwidgets(panel->wsFrm);
    if (panel->appFrm)
        WMMapSubwidgets(panel->appFrm);

    if (showSelectPanel) {
        WMSetPopUpButtonSelectedItem(panel->pagePopUp, 0);
        changePage(panel->pagePopUp, panel);
    } else {
        WMSetPopUpButtonSelectedItem(panel->pagePopUp, 1);
        changePage(panel->pagePopUp, panel);
    }


    parent = XCreateSimpleWindow(dpy, scr->root_win, 0, 0, PWIDTH, PHEIGHT,
                                 0, 0, 0);
    XSelectInput(dpy, parent, KeyPressMask|KeyReleaseMask);
    panel->parent = parent;
    XReparentWindow(dpy, WMWidgetXID(panel->win), parent, 0, 0);

    WMMapWidget(panel->win);

    XSetTransientForHint(dpy, parent, wwin->client_win);

    if (xpos == UNDEFINED_POS) {
        x = wwin->frame_x+wwin->frame->core->width/2;
        y = wwin->frame_y+wwin->frame->top_width*2;
        if (y + PHEIGHT > scr->scr_height)
            y = scr->scr_height - PHEIGHT - 30;
        if (x + PWIDTH > scr->scr_width)
            x = scr->scr_width - PWIDTH;
    } else {
        x = xpos;
        y = ypos;
    }

    panel->frame = wManageInternalWindow(scr, parent, wwin->client_win,
                                         "Inspector", x, y, PWIDTH, PHEIGHT);

    if (!selectedBtn)
        selectedBtn = panel->defaultRb;

    WMSetButtonSelected(selectedBtn, True);

    selectSpecification(selectedBtn, panel);

    /* kluge to know who should get the key events */
    panel->frame->client_leader = WMWidgetXID(panel->win);

    WSETUFLAG(panel->frame, no_closable, 0);
    WSETUFLAG(panel->frame, no_close_button, 0);
    wWindowUpdateButtonImages(panel->frame);
    wFrameWindowShowButton(panel->frame->frame, WFF_RIGHT_BUTTON);
    panel->frame->frame->on_click_right = destroyInspector;

    wWindowMap(panel->frame);

    showIconFor(WMWidgetScreen(panel->alwChk), panel, wwin->wm_instance,
                wwin->wm_class, UPDATE_TEXT_FIELD);

    return panel;
}


void
wShowInspectorForWindow(WWindow *wwin)
{
    if (wwin->flags.inspector_open)
        return;

    WMSetBalloonEnabled(wwin->screen_ptr->wmscreen, wPreferences.help_balloon);

    make_keys();
    wwin->flags.inspector_open = 1;
    wwin->inspector = createInspectorForWindow(wwin, UNDEFINED_POS,
                                               UNDEFINED_POS, False);
}




void
wHideInspectorForWindow(WWindow *wwin)
{
    WWindow *pwin = wwin->inspector->frame;

    wWindowUnmap(pwin);
    pwin->flags.hidden = 1;

    wClientSetState(pwin, IconicState, None);
}



void
wUnhideInspectorForWindow(WWindow *wwin)
{
    WWindow *pwin = wwin->inspector->frame;

    pwin->flags.hidden = 0;
    pwin->flags.mapped = 1;
    XMapWindow(dpy, pwin->client_win);
    XMapWindow(dpy, pwin->frame->core->window);
    wClientSetState(pwin, NormalState, None);
}



WWindow*
wGetWindowOfInspectorForWindow(WWindow *wwin)
{
    if (wwin->inspector) {
        assert(wwin->flags.inspector_open != 0);

        return wwin->inspector->frame;
    } else
        return NULL;
}


void
wCloseInspectorForWindow(WWindow *wwin)
{
    WWindow *pwin = wwin->inspector->frame; /* the inspector window */

    (*pwin->frame->on_click_right)(NULL, pwin, NULL);
}


