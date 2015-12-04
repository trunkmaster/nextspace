/* wdefaults.c - window specific defaults
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
#include <ctype.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

#include <wraster/wraster.h>


#include "WindowMaker.h"
#include "window.h"
#include "screen.h"
#include "funcs.h"
#include "workspace.h"
#include "defaults.h"
#include "icon.h"


/* Global stuff */

extern WPreferences wPreferences;

extern WMPropList *wAttributeDomainName;

extern WDDomain *WDWindowAttributes;


/* Local stuff */


/* type converters */
static int getBool(WMPropList*, WMPropList*);

static char* getString(WMPropList*, WMPropList*);


static WMPropList *ANoTitlebar = NULL;
static WMPropList *ANoResizebar;
static WMPropList *ANoMiniaturizeButton;
static WMPropList *ANoCloseButton;
static WMPropList *ANoBorder;
static WMPropList *ANoHideOthers;
static WMPropList *ANoMouseBindings;
static WMPropList *ANoKeyBindings;
static WMPropList *ANoAppIcon;	       /* app */
static WMPropList *AKeepOnTop;
static WMPropList *AKeepOnBottom;
static WMPropList *AOmnipresent;
static WMPropList *ASkipWindowList;
static WMPropList *AKeepInsideScreen;
static WMPropList *AUnfocusable;
static WMPropList *AAlwaysUserIcon;
static WMPropList *AStartMiniaturized;
static WMPropList *AStartMaximized;
static WMPropList *AStartHidden;       /* app */
static WMPropList *ADontSaveSession;   /* app */
static WMPropList *AEmulateAppIcon;
static WMPropList *AFullMaximize;
static WMPropList *ASharedAppIcon;     /* app */

static WMPropList *AStartWorkspace;

static WMPropList *AIcon;


static WMPropList *AnyWindow;
static WMPropList *No;


static void
init_wdefaults(WScreen *scr)
{
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
    AStartHidden = WMCreatePLString("StartHidden");
    AStartMaximized = WMCreatePLString("StartMaximized");
    ADontSaveSession = WMCreatePLString("DontSaveSession");
    AEmulateAppIcon = WMCreatePLString("EmulateAppIcon");
    AFullMaximize = WMCreatePLString("FullMaximize");
    ASharedAppIcon = WMCreatePLString("SharedAppIcon");

    AStartWorkspace = WMCreatePLString("StartWorkspace");

    AnyWindow = WMCreatePLString("*");
    No = WMCreatePLString("No");
    /*
     if (!scr->wattribs) {
     scr->wattribs = PLGetDomain(wAttributeDomainName);
     }*/
}



static WMPropList*
get_value(WMPropList *dict_win, WMPropList *dict_class, WMPropList *dict_name,
          WMPropList *dict_any, WMPropList *option, WMPropList *default_value,
          Bool useGlobalDefault)
{
    WMPropList *value;


    if (dict_win) {
        value = WMGetFromPLDictionary(dict_win, option);
        if (value)
            return value;
    }

    if (dict_name) {
        value = WMGetFromPLDictionary(dict_name, option);
        if (value)
            return value;
    }

    if (dict_class) {
        value = WMGetFromPLDictionary(dict_class, option);
        if (value)
            return value;
    }

    if (!useGlobalDefault)
        return NULL;

    if (dict_any) {
        value = WMGetFromPLDictionary(dict_any, option);
        if (value)
            return value;
    }

    return default_value;
}


/*
 *----------------------------------------------------------------------
 * wDefaultFillAttributes--
 * 	Retrieves attributes for the specified instance/class and
 * fills attr with it. Values that are actually defined are also
 * set in mask. If useGlobalDefault is True, the default for
 * all windows ("*") will be used for when no values are found
 * for that instance/class.
 *
 *----------------------------------------------------------------------
 */
void
wDefaultFillAttributes(WScreen *scr, char *instance, char *class,
                       WWindowAttributes *attr,
                       WWindowAttributes *mask,
                       Bool useGlobalDefault)
{
    WMPropList *value, *key1, *key2, *key3, *dw, *dc, *dn, *da;


    if (class && instance) {
        char *buffer;

        buffer = wmalloc(strlen(class)+strlen(instance)+2);
        sprintf(buffer, "%s.%s", instance, class);
        key1 = WMCreatePLString(buffer);
        wfree(buffer);
    } else {
        key1 = NULL;
    }

    if (instance)
        key2 = WMCreatePLString(instance);
    else
        key2 = NULL;

    if (class)
        key3 = WMCreatePLString(class);
    else
        key3 = NULL;

    if (!ANoTitlebar) {
        init_wdefaults(scr);
    }

    WMPLSetCaseSensitive(True);

    if (WDWindowAttributes->dictionary) {
        dw = key1 ? WMGetFromPLDictionary(WDWindowAttributes->dictionary, key1) : NULL;
        dn = key2 ? WMGetFromPLDictionary(WDWindowAttributes->dictionary, key2) : NULL;
        dc = key3 ? WMGetFromPLDictionary(WDWindowAttributes->dictionary, key3) : NULL;
        if (useGlobalDefault)
            da = WMGetFromPLDictionary(WDWindowAttributes->dictionary, AnyWindow);
        else
            da = NULL;
    } else {
        dw = NULL;
        dn = NULL;
        dc = NULL;
        da = NULL;
    }
    if (key1)
        WMReleasePropList(key1);
    if (key2)
        WMReleasePropList(key2);
    if (key3)
        WMReleasePropList(key3);

#define APPLY_VAL(value, flag, attrib)	\
    if (value) {attr->flag = getBool(attrib, value); \
    if (mask) mask->flag = 1;}

    /* get the data */
    value = get_value(dw, dc, dn, da, ANoTitlebar, No, useGlobalDefault);
    APPLY_VAL(value, no_titlebar, ANoTitlebar);

    value = get_value(dw, dc, dn, da, ANoResizebar, No, useGlobalDefault);
    APPLY_VAL(value, no_resizebar, ANoResizebar);

    value = get_value(dw, dc, dn, da, ANoMiniaturizeButton, No, useGlobalDefault);
    APPLY_VAL(value, no_miniaturize_button, ANoMiniaturizeButton);

    value = get_value(dw, dc, dn, da, ANoCloseButton, No, useGlobalDefault);
    APPLY_VAL(value, no_close_button, ANoCloseButton);

    value = get_value(dw, dc, dn, da, ANoBorder, No, useGlobalDefault);
    APPLY_VAL(value, no_border, ANoBorder);

    value = get_value(dw, dc, dn, da, ANoHideOthers, No, useGlobalDefault);
    APPLY_VAL(value, no_hide_others, ANoHideOthers);

    value = get_value(dw, dc, dn, da, ANoMouseBindings, No, useGlobalDefault);
    APPLY_VAL(value, no_bind_mouse, ANoMouseBindings);

    value = get_value(dw, dc, dn, da, ANoKeyBindings, No, useGlobalDefault);
    APPLY_VAL(value, no_bind_keys, ANoKeyBindings);

    value = get_value(dw, dc, dn, da, ANoAppIcon, No, useGlobalDefault);
    APPLY_VAL(value, no_appicon, ANoAppIcon);

    value = get_value(dw, dc, dn, da, ASharedAppIcon, No, useGlobalDefault);
    APPLY_VAL(value, shared_appicon, ASharedAppIcon);

    value = get_value(dw, dc, dn, da, AKeepOnTop, No, useGlobalDefault);
    APPLY_VAL(value, floating, AKeepOnTop);

    value = get_value(dw, dc, dn, da, AKeepOnBottom, No, useGlobalDefault);
    APPLY_VAL(value, sunken, AKeepOnBottom);

    value = get_value(dw, dc, dn, da, AOmnipresent, No, useGlobalDefault);
    APPLY_VAL(value, omnipresent, AOmnipresent);

    value = get_value(dw, dc, dn, da, ASkipWindowList, No, useGlobalDefault);
    APPLY_VAL(value, skip_window_list, ASkipWindowList);

    value = get_value(dw, dc, dn, da, AKeepInsideScreen, No, useGlobalDefault);
    APPLY_VAL(value, dont_move_off, AKeepInsideScreen);

    value = get_value(dw, dc, dn, da, AUnfocusable, No, useGlobalDefault);
    APPLY_VAL(value, no_focusable, AUnfocusable);

    value = get_value(dw, dc, dn, da, AAlwaysUserIcon, No, useGlobalDefault);
    APPLY_VAL(value, always_user_icon, AAlwaysUserIcon);

    value = get_value(dw, dc, dn, da, AStartMiniaturized, No, useGlobalDefault);
    APPLY_VAL(value, start_miniaturized, AStartMiniaturized);

    value = get_value(dw, dc, dn, da, AStartHidden, No, useGlobalDefault);
    APPLY_VAL(value, start_hidden, AStartHidden);

    value = get_value(dw, dc, dn, da, AStartMaximized, No, useGlobalDefault);
    APPLY_VAL(value, start_maximized, AStartMaximized);

    value = get_value(dw, dc, dn, da, ADontSaveSession, No, useGlobalDefault);
    APPLY_VAL(value, dont_save_session, ADontSaveSession);

    value = get_value(dw, dc, dn, da, AEmulateAppIcon, No, useGlobalDefault);
    APPLY_VAL(value, emulate_appicon, AEmulateAppIcon);

    value = get_value(dw, dc, dn, da, AFullMaximize, No, useGlobalDefault);
    APPLY_VAL(value, full_maximize, AFullMaximize);

    /* clean up */
    WMPLSetCaseSensitive(False);
}



WMPropList*
get_generic_value(WScreen *scr, char *instance, char *class, WMPropList *option,
                  Bool noDefault)
{
    WMPropList *value, *key, *dict;

    value = NULL;

    WMPLSetCaseSensitive(True);

    if (class && instance) {
        char *buffer;

        buffer = wmalloc(strlen(class)+strlen(instance)+2);
        sprintf(buffer, "%s.%s", instance, class);
        key = WMCreatePLString(buffer);
        wfree(buffer);

        dict = WMGetFromPLDictionary(WDWindowAttributes->dictionary, key);
        WMReleasePropList(key);

        if (dict) {
            value = WMGetFromPLDictionary(dict, option);
        }
    }

    if (!value && instance) {
        key = WMCreatePLString(instance);

        dict = WMGetFromPLDictionary(WDWindowAttributes->dictionary, key);
        WMReleasePropList(key);
        if (dict) {
            value = WMGetFromPLDictionary(dict, option);
        }
    }

    if (!value && class) {
        key = WMCreatePLString(class);

        dict = WMGetFromPLDictionary(WDWindowAttributes->dictionary, key);
        WMReleasePropList(key);

        if (dict) {
            value = WMGetFromPLDictionary(dict, option);
        }
    }

    if (!value && !noDefault) {
        dict = WMGetFromPLDictionary(WDWindowAttributes->dictionary, AnyWindow);

        if (dict) {
            value = WMGetFromPLDictionary(dict, option);
        }
    }

    WMPLSetCaseSensitive(False);

    return value;
}


char*
wDefaultGetIconFile(WScreen *scr, char *instance, char *class,
                    Bool noDefault)
{
    WMPropList *value;
    char *tmp;

    if (!ANoTitlebar) {
        init_wdefaults(scr);
    }

    if (!WDWindowAttributes->dictionary)
        return NULL;

    value = get_generic_value(scr, instance, class, AIcon, noDefault);

    if (!value)
        return NULL;

    tmp = getString(AIcon, value);

    return tmp;
}


RImage*
wDefaultGetImage(WScreen *scr, char *winstance, char *wclass)
{
    char *file_name;
    char *path;
    RImage *image;

    file_name = wDefaultGetIconFile(scr, winstance, wclass, False);
    if (!file_name)
        return NULL;

    path = FindImage(wPreferences.icon_path, file_name);

    if (!path) {
        wwarning(_("could not find icon file \"%s\""), file_name);
        return NULL;
    }

    image = RLoadImage(scr->rcontext, path, 0);
    if (!image) {
        wwarning(_("error loading image file \"%s\""), path, RMessageForError(RErrorCode));
    }
    wfree(path);

    image = wIconValidateIconSize(scr, image);

    return image;
}


int
wDefaultGetStartWorkspace(WScreen *scr, char *instance, char *class)
{
    WMPropList *value;
    int w, i;
    char *tmp;

    if (!ANoTitlebar) {
        init_wdefaults(scr);
    }

    if (!WDWindowAttributes->dictionary)
        return -1;

    value = get_generic_value(scr, instance, class, AStartWorkspace,
                              False);

    if (!value)
        return -1;

    tmp = getString(AStartWorkspace, value);

    if (!tmp || strlen(tmp)==0)
        return -1;

    if (sscanf(tmp, "%i", &w)!=1) {
        w = -1;
        for (i=0; i < scr->workspace_count; i++) {
            if (strcmp(scr->workspaces[i]->name, tmp)==0) {
                w = i;
                break;
            }
        }
    } else {
        w--;
    }

    return w;
}


void
wDefaultChangeIcon(WScreen *scr, char *instance, char* class, char *file)
{
    WDDomain *db = WDWindowAttributes;
    WMPropList *icon_value=NULL, *value, *attr, *key, *def_win, *def_icon=NULL;
    WMPropList *dict = db->dictionary;
    int same = 0;

    if (!dict) {
        dict = WMCreatePLDictionary(NULL, NULL);
        if (dict) {
            db->dictionary = dict;
        } else {
            return;
        }
    }

    WMPLSetCaseSensitive(True);

    if (instance && class) {
        char *buffer;
        buffer = wmalloc(strlen(instance) + strlen(class) + 2);
        sprintf(buffer, "%s.%s", instance, class);
        key = WMCreatePLString(buffer);
        wfree(buffer);
    } else if (instance) {
        key = WMCreatePLString(instance);
    } else if (class) {
        key = WMCreatePLString(class);
    } else {
        key = WMRetainPropList(AnyWindow);
    }

    if (file) {
        value = WMCreatePLString(file);
        icon_value = WMCreatePLDictionary(AIcon, value, NULL);
        WMReleasePropList(value);

        if ((def_win = WMGetFromPLDictionary(dict, AnyWindow)) != NULL) {
            def_icon = WMGetFromPLDictionary(def_win, AIcon);
        }

        if (def_icon && !strcmp(WMGetFromPLString(def_icon), file))
            same = 1;
    }

    if ((attr = WMGetFromPLDictionary(dict, key)) != NULL) {
        if (WMIsPLDictionary(attr)) {
            if (icon_value!=NULL && !same)
                WMMergePLDictionaries(attr, icon_value, False);
            else
                WMRemoveFromPLDictionary(attr, AIcon);
        }
    } else if (icon_value!=NULL && !same) {
        WMPutInPLDictionary(dict, key, icon_value);
    }
    if (!wPreferences.flags.noupdates) {
        UpdateDomainFile(db);
    }

    WMReleasePropList(key);
    if(icon_value)
        WMReleasePropList(icon_value);

    WMPLSetCaseSensitive(False);
}



/* --------------------------- Local ----------------------- */

static int
getBool(WMPropList *key, WMPropList *value)
{
    char *val;

    if (!WMIsPLString(value)) {
        wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                 WMGetFromPLString(key), "Boolean");
        return 0;
    }
    val = WMGetFromPLString(value);

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
        /* We return False if we can't convert to BOOLEAN.
         * This is because all options defaults to False.
         * -1 is not checked and thus is interpreted as True,
         * which is not good.*/
        return 0;
    }
}


/* WARNING: Do not free the value returned by this function!! */
static char*
getString(WMPropList *key, WMPropList *value)
{
    if (!WMIsPLString(value)) {
        wwarning(_("Wrong option format for key \"%s\". Should be %s."),
                 WMGetFromPLString(key), "String");
        return NULL;
    }

    return WMGetFromPLString(value);
}

