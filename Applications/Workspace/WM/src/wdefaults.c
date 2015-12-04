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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "wconfig.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

#include <wraster.h>

#include "WindowMaker.h"
#include "window.h"
#include "appicon.h"
#include "screen.h"
#include "workspace.h"
#include "defaults.h"
#include "icon.h"
#include "misc.h"

#define APPLY_VAL(value, flag, attrib)	\
    if (value) {attr->flag = getBool(attrib, value); \
    if (mask) mask->flag = 1;}

/* Local stuff */

/* type converters */
static int getBool(WMPropList *, WMPropList *);
static char *getString(WMPropList *, WMPropList *);
static WMPropList *ANoTitlebar = NULL;
static WMPropList *ANoResizebar;
static WMPropList *ANoMiniaturizeButton;
static WMPropList *ANoMiniaturizable;
static WMPropList *ANoCloseButton;
static WMPropList *ANoBorder;
static WMPropList *ANoHideOthers;
static WMPropList *ANoMouseBindings;
static WMPropList *ANoKeyBindings;
static WMPropList *ANoAppIcon;	/* app */
static WMPropList *AKeepOnTop;
static WMPropList *AKeepOnBottom;
static WMPropList *AOmnipresent;
static WMPropList *ASkipWindowList;
static WMPropList *ASkipSwitchPanel;
static WMPropList *AKeepInsideScreen;
static WMPropList *AUnfocusable;
static WMPropList *AAlwaysUserIcon;
static WMPropList *AStartMiniaturized;
static WMPropList *AStartMaximized;
static WMPropList *AStartHidden;	/* app */
static WMPropList *ADontSaveSession;	/* app */
static WMPropList *AEmulateAppIcon;
static WMPropList *AFocusAcrossWorkspace;
static WMPropList *AFullMaximize;
static WMPropList *ASharedAppIcon;	/* app */
#ifdef XKB_BUTTON_HINT
static WMPropList *ANoLanguageButton;
#endif
static WMPropList *AStartWorkspace;
static WMPropList *AIcon;
static WMPropList *AnyWindow;
static WMPropList *No;

static void init_wdefaults(void)
{
	AIcon = WMCreatePLString("Icon");

	ANoTitlebar = WMCreatePLString("NoTitlebar");
	ANoResizebar = WMCreatePLString("NoResizebar");
	ANoMiniaturizeButton = WMCreatePLString("NoMiniaturizeButton");
	ANoMiniaturizable = WMCreatePLString("NoMiniaturizable");
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
	ASkipSwitchPanel = WMCreatePLString("SkipSwitchPanel");
	AKeepInsideScreen = WMCreatePLString("KeepInsideScreen");
	AUnfocusable = WMCreatePLString("Unfocusable");
	AAlwaysUserIcon = WMCreatePLString("AlwaysUserIcon");
	AStartMiniaturized = WMCreatePLString("StartMiniaturized");
	AStartHidden = WMCreatePLString("StartHidden");
	AStartMaximized = WMCreatePLString("StartMaximized");
	ADontSaveSession = WMCreatePLString("DontSaveSession");
	AEmulateAppIcon = WMCreatePLString("EmulateAppIcon");
	AFocusAcrossWorkspace = WMCreatePLString("FocusAcrossWorkspace");
	AFullMaximize = WMCreatePLString("FullMaximize");
	ASharedAppIcon = WMCreatePLString("SharedAppIcon");
#ifdef XKB_BUTTON_HINT
	ANoLanguageButton = WMCreatePLString("NoLanguageButton");
#endif

	AStartWorkspace = WMCreatePLString("StartWorkspace");

	AnyWindow = WMCreatePLString("*");
	No = WMCreatePLString("No");
}

/* Returns the correct WMPropList, using instance+class or instance, or class, or default */
static WMPropList *get_value(WMPropList * dict_win, WMPropList * dict_class, WMPropList * dict_name,
			     WMPropList * dict_any, WMPropList * option, WMPropList * default_value,
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

static WMPropList *get_value_from_instanceclass(const char *value)
{
	WMPropList *key, *val = NULL;

	if (!value)
		return NULL;

	key = WMCreatePLString(value);

	WMPLSetCaseSensitive(True);

	if (w_global.domain.window_attr->dictionary)
		val = key ? WMGetFromPLDictionary(w_global.domain.window_attr->dictionary, key) : NULL;

	if (key)
		WMReleasePropList(key);

	WMPLSetCaseSensitive(False);

	return val;
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
void wDefaultFillAttributes(const char *instance, const char *class,
			    WWindowAttributes *attr, WWindowAttributes *mask,
			    Bool useGlobalDefault)
{
	WMPropList *value, *dw, *dc, *dn, *da;
	char *buffer;

	dw = dc = dn = da = NULL;

	if (!ANoTitlebar)
		init_wdefaults();

	if (class && instance) {
		buffer = StrConcatDot(instance, class);
		dw = get_value_from_instanceclass(buffer);
		wfree(buffer);
	}

	dn = get_value_from_instanceclass(instance);
	dc = get_value_from_instanceclass(class);

	WMPLSetCaseSensitive(True);

	if ((w_global.domain.window_attr->dictionary) && (useGlobalDefault))
		da = WMGetFromPLDictionary(w_global.domain.window_attr->dictionary, AnyWindow);

	/* get the data */
	value = get_value(dw, dc, dn, da, ANoTitlebar, No, useGlobalDefault);
	APPLY_VAL(value, no_titlebar, ANoTitlebar);

	value = get_value(dw, dc, dn, da, ANoResizebar, No, useGlobalDefault);
	APPLY_VAL(value, no_resizebar, ANoResizebar);

	value = get_value(dw, dc, dn, da, ANoMiniaturizeButton, No, useGlobalDefault);
	APPLY_VAL(value, no_miniaturize_button, ANoMiniaturizeButton);

	value = get_value(dw, dc, dn, da, ANoMiniaturizable, No, useGlobalDefault);
	APPLY_VAL(value, no_miniaturizable, ANoMiniaturizable);

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

	value = get_value(dw, dc, dn, da, ASkipSwitchPanel, No, useGlobalDefault);
	APPLY_VAL(value, skip_switchpanel, ASkipSwitchPanel);

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

	value = get_value(dw, dc, dn, da, AFocusAcrossWorkspace, No, useGlobalDefault);
	APPLY_VAL(value, focus_across_wksp, AFocusAcrossWorkspace);

	value = get_value(dw, dc, dn, da, AFullMaximize, No, useGlobalDefault);
	APPLY_VAL(value, full_maximize, AFullMaximize);

#ifdef XKB_BUTTON_HINT
	value = get_value(dw, dc, dn, da, ANoLanguageButton, No, useGlobalDefault);
	APPLY_VAL(value, no_language_button, ANoLanguageButton);
#endif

	/* clean up */
	WMPLSetCaseSensitive(False);
}

static WMPropList *get_generic_value(const char *instance, const char *class,
				     WMPropList *option, Bool default_icon)
{
	WMPropList *value, *key, *dict;

	value = NULL;

	WMPLSetCaseSensitive(True);

	/* Search the icon name using class and instance */
	if (class && instance) {
		char *buffer;

		buffer = wmalloc(strlen(class) + strlen(instance) + 2);
		sprintf(buffer, "%s.%s", instance, class);
		key = WMCreatePLString(buffer);
		wfree(buffer);

		dict = WMGetFromPLDictionary(w_global.domain.window_attr->dictionary, key);
		WMReleasePropList(key);

		if (dict)
			value = WMGetFromPLDictionary(dict, option);
	}

	/* Search the icon name using instance */
	if (!value && instance) {
		key = WMCreatePLString(instance);

		dict = WMGetFromPLDictionary(w_global.domain.window_attr->dictionary, key);
		WMReleasePropList(key);

		if (dict)
			value = WMGetFromPLDictionary(dict, option);
	}

	/* Search the icon name using class */
	if (!value && class) {
		key = WMCreatePLString(class);

		dict = WMGetFromPLDictionary(w_global.domain.window_attr->dictionary, key);
		WMReleasePropList(key);

		if (dict)
			value = WMGetFromPLDictionary(dict, option);
	}

	/* Search the default icon name - See default_icon argument! */
	if (!value && default_icon) {
		/* AnyWindow is "*" - see wdefaults.c */
		dict = WMGetFromPLDictionary(w_global.domain.window_attr->dictionary, AnyWindow);

		if (dict)
			value = WMGetFromPLDictionary(dict, option);
	}

	WMPLSetCaseSensitive(False);

	return value;
}

/* Get the file name of the image, using instance and class */
char *get_icon_filename(const char *winstance, const char *wclass, const char *command,
			Bool default_icon)
{
	char *file_name;
	char *file_path;

	/* Get the file name of the image, using instance and class */
	file_name = wDefaultGetIconFile(winstance, wclass, default_icon);

	/* Check if the file really exists in the disk */
	if (file_name)
		file_path = FindImage(wPreferences.icon_path, file_name);
	else
		file_path = NULL;

	/* If the specific icon filename is not found, and command is specified,
	 * then include the .app icons and re-do the search. */
	if (!file_path && command) {
		wApplicationExtractDirPackIcon(command, winstance, wclass);
		file_name = wDefaultGetIconFile(winstance, wclass, False);

		if (file_name) {
			file_path = FindImage(wPreferences.icon_path, file_name);
			if (!file_path)
				wwarning(_("icon \"%s\" doesn't exist, check your config files"), file_name);

			/* FIXME: Here, if file_path does not exist then the icon is still in the
			 * "icon database" (w_global.domain.window_attr->dictionary), but the file
			 * for the icon is no more on disk. Therefore, we should remove it from the
			 * database. Is possible to do that using wDefaultChangeIcon() */
		}
	}

	/*
	 * Don't wfree(file_name) because it is a direct pointer inside the icon
	 * dictionary (w_global.domain.window_attr->dictionary) and not a result
	 * allocated with wstrdup()
	 */

	if (!file_path && default_icon)
		file_path = get_default_image_path();

	return file_path;
}

/* This function returns the image picture for the file_name file */
RImage *get_rimage_from_file(WScreen *scr, const char *file_name, int max_size)
{
	RImage *image = NULL;

	if (!file_name)
		return NULL;

	image = RLoadImage(scr->rcontext, file_name, 0);
	if (!image)
		wwarning(_("error loading image file \"%s\": %s"), file_name,
			 RMessageForError(RErrorCode));

	image = wIconValidateIconSize(image, max_size);

	return image;
}

/* This function returns the default icon's full path
 * If the path for an icon is not found, returns NULL */
char *get_default_image_path(void)
{
	char *path = NULL, *file = NULL;

	/* Get the default icon */
	file = wDefaultGetIconFile(NULL, NULL, True);
	if (file)
		path = FindImage(wPreferences.icon_path, file);

	return path;
}

/* This function creates the RImage using the default icon */
RImage *get_default_image(WScreen *scr)
{
	RImage *image = NULL;
	char *path = NULL;

	/* Get the filename full path */
	path = get_default_image_path();
	if (!path)
		return NULL;

	/* Get the default icon */
	image = get_rimage_from_file(scr, path, wPreferences.icon_size);
	if (!image)
		wwarning(_("could not find default icon \"%s\""), path);

	/* Resize the icon to the wPreferences.icon_size size
	 * usually this function will return early, because size is right */
	image = wIconValidateIconSize(image, wPreferences.icon_size);

	return image;
}

RImage *get_icon_image(WScreen *scr, const char *winstance, const char *wclass, int max_size)
{
	char *file_name = NULL;

	/* Get the file name of the image, using instance and class */
	file_name = get_icon_filename(winstance, wclass, NULL, True);

	return get_rimage_from_file(scr, file_name, max_size);
}

int wDefaultGetStartWorkspace(WScreen *scr, const char *instance, const char *class)
{
	WMPropList *value;
	int w;
	char *tmp;

	if (!ANoTitlebar)
		init_wdefaults();

	if (!w_global.domain.window_attr->dictionary)
		return -1;

	value = get_generic_value(instance, class, AStartWorkspace, True);

	if (!value)
		return -1;

	tmp = getString(AStartWorkspace, value);

	if (!tmp || strlen(tmp) == 0)
		return -1;

	/* Get the workspace number for the workspace name */
	w = wGetWorkspaceNumber(scr, tmp);

	return w;
}

/* Get the name of the Icon File. If default_icon is True, then, default value included */
char *wDefaultGetIconFile(const char *instance, const char *class, Bool default_icon)
{
	WMPropList *value;
	char *tmp;

	if (!ANoTitlebar)
		init_wdefaults();

	if (!w_global.domain.window_attr || !w_global.domain.window_attr->dictionary)
		return NULL;

	value = get_generic_value(instance, class, AIcon, default_icon);

	if (!value)
		return NULL;

	tmp = getString(AIcon, value);

	return tmp;
}

void wDefaultChangeIcon(const char *instance, const char *class, const char *file)
{
	WDDomain *db = w_global.domain.window_attr;
	WMPropList *icon_value = NULL, *value, *attr, *key, *def_win, *def_icon = NULL;
	WMPropList *dict = db->dictionary;
	int same = 0;

	if (!dict) {
		dict = WMCreatePLDictionary(NULL, NULL);
		if (dict)
			db->dictionary = dict;
		else
			return;
	}

	WMPLSetCaseSensitive(True);

	if (instance && class) {
		char *buffer;

		buffer = StrConcatDot(instance, class);
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

		def_win = WMGetFromPLDictionary(dict, AnyWindow);
		if (def_win != NULL)
			def_icon = WMGetFromPLDictionary(def_win, AIcon);

		if (def_icon && !strcmp(WMGetFromPLString(def_icon), file))
			same = 1;
	}

	attr = WMGetFromPLDictionary(dict, key);
	if (attr != NULL) {
		if (WMIsPLDictionary(attr)) {
			if (icon_value != NULL && !same)
				WMMergePLDictionaries(attr, icon_value, False);
			else
				WMRemoveFromPLDictionary(attr, AIcon);
		}
	} else if (icon_value != NULL && !same) {
		WMPutInPLDictionary(dict, key, icon_value);
	}

	if (!wPreferences.flags.noupdates)
		UpdateDomainFile(db);

	WMReleasePropList(key);
	if (icon_value)
		WMReleasePropList(icon_value);

	WMPLSetCaseSensitive(False);
}

void wDefaultPurgeInfo(const char *instance, const char *class)
{
	WMPropList *value, *key, *dict;
	char *buffer;

	if (!AIcon) { /* Unnecessary precaution */
		init_wdefaults();
	}

	WMPLSetCaseSensitive(True);

	buffer = wmalloc(strlen(class) + strlen(instance) + 2);
	sprintf(buffer, "%s.%s", instance, class);
	key = WMCreatePLString(buffer);

	dict = WMGetFromPLDictionary(w_global.domain.window_attr->dictionary, key);

	if (dict) {
		value = WMGetFromPLDictionary(dict, AIcon);
		if (value) {
			WMRemoveFromPLDictionary(dict, AIcon);
		}
		WMRemoveFromPLDictionary(w_global.domain.window_attr->dictionary, key);
		UpdateDomainFile(w_global.domain.window_attr);
	}

	wfree(buffer);
	WMReleasePropList(key);
	WMPLSetCaseSensitive(False);
}

/* --------------------------- Local ----------------------- */

static int getBool(WMPropList * key, WMPropList * value)
{
	char *val;

	if (!WMIsPLString(value)) {
		wwarning(_("Wrong option format for key \"%s\". Should be %s."),
			 WMGetFromPLString(key), "Boolean");
		return 0;
	}
	val = WMGetFromPLString(value);

	if ((val[1] == '\0' && (val[0] == 'y' || val[0] == 'Y' || val[0] == 'T' || val[0] == 't' || val[0] == '1'))
	    || (strcasecmp(val, "YES") == 0 || strcasecmp(val, "TRUE") == 0)) {

		return 1;
	} else if ((val[1] == '\0'
		    && (val[0] == 'n' || val[0] == 'N' || val[0] == 'F' || val[0] == 'f' || val[0] == '0'))
		   || (strcasecmp(val, "NO") == 0 || strcasecmp(val, "FALSE") == 0)) {

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
static char *getString(WMPropList * key, WMPropList * value)
{
	if (!WMIsPLString(value)) {
		wwarning(_("Wrong option format for key \"%s\". Should be %s."), WMGetFromPLString(key), "String");
		return NULL;
	}

	return WMGetFromPLString(value);
}
