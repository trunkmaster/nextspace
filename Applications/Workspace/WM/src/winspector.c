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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

#include "WindowMaker.h"
#include "screen.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "workspace.h"
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
#include "wmspec.h"
#include "misc.h"
#include "switchmenu.h"

#include <WINGs/WUtil.h>

#define USE_TEXT_FIELD		1
#define UPDATE_TEXT_FIELD	2
#define REVERT_TO_DEFAULT	4
#define PWIDTH			290
#define PHEIGHT			360
#define UNDEFINED_POS		0xffffff
#define UPDATE_DEFAULTS		1
#define IS_BOOLEAN		2


static const struct {
	const char *key_name;
	WWindowAttributes flag;
	const char *caption;
	const char *description;
} window_attribute[] = {
	{ "NoTitlebar", { .no_titlebar = 1 }, N_("Disable titlebar"),
	  N_("Remove the titlebar of this window.\n"
	     "To access the window commands menu of a window\n"
	     "without it's titlebar, press Control+Esc (or the\n"
	     "equivalent shortcut, if you changed the default\n"
	     "settings).") },

	{ "NoResizebar", { .no_resizebar = 1 }, N_("Disable resizebar"),
	  N_("Remove the resizebar of this window.") },

	{ "NoCloseButton", { .no_close_button = 1 }, N_("Disable close button"),
	  N_("Remove the `close window' button of this window.") },

	{ "NoMiniaturizeButton", { .no_miniaturize_button = 1 }, N_("Disable miniaturize button"),
	  N_("Remove the `miniaturize window' button of the window.") },

	{ "NoBorder", { .no_border = 1 }, N_("Disable border"),
	  N_("Remove the 1 pixel black border around the window.") },

	{ "KeepOnTop", { .floating = 1 }, N_("Keep on top (floating)"),
	  N_("Keep the window over other windows, not allowing\n"
	     "them to cover it.") },

	{ "KeepOnBottom", { .sunken = 1 }, N_("Keep at bottom (sunken)"),
	  N_("Keep the window under all other windows.") },

	{ "Omnipresent", { .omnipresent = 1 }, N_("Omnipresent"),
	  N_("Make window present in all workspaces.") },

	{ "StartMiniaturized", { .start_miniaturized = 1 }, N_("Start miniaturized"),
	  N_("Make the window be automatically miniaturized when it's\n"
	     "first shown.") },

	{ "StartMaximized", { .start_maximized = 1 }, N_("Start maximized"),
	  N_("Make the window be automatically maximized when it's\n"
	     "first shown.") },

	{ "FullMaximize", { .full_maximize = 1 }, N_("Full screen maximization"),
	  N_("Make the window use the whole screen space when it's\n"
				  "maximized. The titlebar and resizebar will be moved\n"
				  "to outside the screen.") }

}, advanced_option[] = {
	{ "NoKeyBindings", { .no_bind_keys = 1 }, N_("Do not bind keyboard shortcuts"),
	  N_("Do not bind keyboard shortcuts from Window Maker\n"
	     "when this window is focused. This will allow the\n"
	     "window to receive all key combinations regardless\n"
	     "of your shortcut configuration.") },

	{ "NoMouseBindings", { .no_bind_mouse = 1 }, N_("Do not bind mouse clicks"),
	  N_("Do not bind mouse actions, such as `Alt'+drag\n"
	     "in the window (when Alt is the modifier you have\n"
	     "configured).") },

	{ "SkipWindowList", { .skip_window_list = 1 }, N_("Do not show in the window list"),
	  N_("Do not list the window in the window list menu.") },

	{ "SkipSwitchPanel", { .skip_switchpanel = 1 }, N_("Do not show in the switch panel"),
	  N_("Do not include in switch panel while cycling windows.") },

	{ "Unfocusable", { .no_focusable = 1 }, N_("Do not let it take focus"),
	  N_("Do not let the window take keyboard focus when you\n"
	     "click on it.") },

	{ "KeepInsideScreen", { .dont_move_off = 1 }, N_("Keep inside screen"),
	  N_("Do not allow the window to move itself completely\n"
	     "outside the screen. For bug compatibility.\n") },

	{ "NoHideOthers", { .no_hide_others = 1 }, N_("Ignore 'Hide Others'"),
	  N_("Do not hide the window when issuing the\n"
	     "`HideOthers' command.") },

	{ "DontSaveSession", { .dont_save_session = 1 }, N_("Ignore 'Save Session'"),
	  N_("Do not save the associated application in the\n"
	     "session's state, so that it won't be restarted\n"
	     "together with other applications when Window Maker\n"
	     "starts.") },

	{ "EmulateAppIcon", { .emulate_appicon = 1 }, N_("Emulate application icon"),
	  N_("Make this window act as an application that provides\n"
	     "enough information to Window Maker for a dockable\n"
	     "application icon to be created.") },

	{ "FocusAcrossWorkspace", { .focus_across_wksp = 1 }, N_("Focus across workspaces"),
	  N_("Allow Window Maker to switch workspace to satisfy\n"
	     "a focus request (annoying).") },

	{ "NoMiniaturizable", { .no_miniaturizable = 1 }, N_("Do not let it be minimized"),
	  N_("Do not let the window of this application be\n"
	     "minimized.\n") }

#ifdef XKB_BUTTON_HINT
	,{ "NoLanguageButton", { .no_language_button = 1 }, N_("Disable language button"),
	   N_("Remove the `toggle language' button of the window.") }
#endif

}, application_attr[] = {
	{ "StartHidden", { .start_hidden = 1 }, N_("Start hidden"),
	  N_("Automatically hide application when it's started.") },

	{ "NoAppIcon", { .no_appicon = 1 }, N_("No application icon"),
	  N_("Disable the application icon for the application.\n"
	     "Note that you won't be able to dock it anymore,\n"
	     "and any icons that are already docked will stop\n"
	     "working correctly.") },

	{ "SharedAppIcon", { .shared_appicon = 1 }, N_("Shared application icon"),
	  N_("Use a single shared application icon for all of\n"
	     "the instances of this application.\n") }
};

typedef struct InspectorPanel {
	struct InspectorPanel *nextPtr;

	WWindow *frame;
	WWindow *inspected;	/* the window that's being inspected */
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
	WMButton *attrChk[sizeof(window_attribute) / sizeof(window_attribute[0])];

	/* 3rd page. more attributes */
	WMFrame *moreFrm;
	WMButton *moreChk[sizeof(advanced_option) / sizeof(advanced_option[0])];

	/* 4th page. icon and workspace */
	WMFrame *iconFrm;
	WMLabel *iconLbl;
	WMLabel *fileLbl;
	WMTextField *fileText;
	WMButton *alwChk;
	WMButton *browseIconBtn;
	WMFrame *wsFrm;
	WMPopUpButton *wsP;

	/* 5th page. application wide attributes */
	WMFrame *appFrm;
	WMButton *appChk[sizeof(application_attr) / sizeof(application_attr[0])];

	unsigned int done:1;
	unsigned int destroyed:1;
	unsigned int choosingIcon:1;
} InspectorPanel;

static InspectorPanel *panelList = NULL;

/*
 * We are supposed to use the 'key_name' from the the 'window_attribute' structure when we want to
 * save the user choice to the database, but as we will need to convert that name into a Property
 * List, we use here a Cache of Property Lists, generated only once, which can be reused. It will
 * also save on memory because of the re-use of the same storage space instead of allocating a new
 * one everytime.
 */
static WMPropList *pl_attribute[sizeof(window_attribute) / sizeof(window_attribute[0])] = { [0] = NULL };
static WMPropList *pl_advoptions[sizeof(advanced_option) / sizeof(advanced_option[0])];
static WMPropList *pl_appattrib[sizeof(application_attr) / sizeof(application_attr[0])];

static WMPropList *AAlwaysUserIcon;
static WMPropList *AStartWorkspace;
static WMPropList *AIcon;

/* application wide options */
static WMPropList *AnyWindow;
static WMPropList *EmptyString;
static WMPropList *Yes, *No;

static char *spec_text;
static void applySettings(WMWidget *button, void *panel);

static InspectorPanel *createInspectorForWindow(WWindow *wwin, int xpos, int ypos, Bool showSelectPanel);

static void create_tab_window_attributes(WWindow *wwin, InspectorPanel *panel, int frame_width);
static void create_tab_window_advanced(WWindow *wwin, InspectorPanel *panel, int frame_width);
static void create_tab_icon_workspace(WWindow *wwin, InspectorPanel *panel);
static void create_tab_app_specific(WWindow *wwin, InspectorPanel *panel, int frame_width);

/*
 * These 3 functions sets/clear/read a bit inside a bit-field in a generic manner;
 * they uses binary operators to be as effiscient as possible, also counting on compiler's
 * optimisations because the bit-field structure will fit in only 1 or 2 int but it is
 * depending on the processor architecture.
 */
static inline void set_attr_flag(WWindowAttributes *target, const WWindowAttributes *flag)
{
	int i;
	const unsigned char *src;
	unsigned char *dst;

	src = (const unsigned char *) flag;
	dst = (unsigned char *) target;

	for (i = 0; i < sizeof(*flag); i++)
		dst[i] |= src[i];
}

static inline void clear_attr_flag(WWindowAttributes *target, const WWindowAttributes *flag)
{
	int i;
	const unsigned char *src;
	unsigned char *dst;

	src = (const unsigned char *) flag;
	dst = (unsigned char *) target;

	for (i = 0; i < sizeof(*flag); i++)
		dst[i] &= ~src[i];
}

static inline int get_attr_flag(const WWindowAttributes *from, const WWindowAttributes *flag)
{
	int i;
	const unsigned char *xpect, *field;

	field = (const unsigned char *) from;
	xpect = (const unsigned char *) flag;

	for (i = 0; i < sizeof(*flag); i++)
		if (field[i] & xpect[i])
			return 1;

	return 0;
}

/*
 * This function is creating the Property List for the cache mentionned above
 */
static void make_keys(void)
{
	int i;

	if (pl_attribute[0] != NULL)
		return;

	for (i = 0; i < wlengthof(window_attribute); i++)
		pl_attribute[i] = WMCreatePLString(window_attribute[i].key_name);

	for (i = 0; i < wlengthof(advanced_option); i++)
		pl_advoptions[i] = WMCreatePLString(advanced_option[i].key_name);

	for (i = 0; i < wlengthof(application_attr); i++)
		pl_appattrib[i] = WMCreatePLString(application_attr[i].key_name);

	AIcon = WMCreatePLString("Icon");
	AAlwaysUserIcon = WMCreatePLString("AlwaysUserIcon");

	AStartWorkspace = WMCreatePLString("StartWorkspace");

	AnyWindow = WMCreatePLString("*");
	EmptyString = WMCreatePLString("");
	Yes = WMCreatePLString("Yes");
	No = WMCreatePLString("No");
}

static void freeInspector(InspectorPanel *panel)
{
	panel->destroyed = 1;

	if (panel->choosingIcon)
		return;

	WMDestroyWidget(panel->win);
	XDestroyWindow(dpy, panel->parent);
	wfree(panel);
}

static void destroyInspector(WCoreWindow *foo, void *data, XEvent *event)
{
	InspectorPanel *panel, *tmp;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) foo;
	(void) event;

	panel = panelList;
	while (panel->frame != data)
		panel = panel->nextPtr;

	if (panelList == panel) {
		panelList = panel->nextPtr;
	} else {
		tmp = panelList;
		while (tmp->nextPtr != panel)
			tmp = tmp->nextPtr;

		tmp->nextPtr = panel->nextPtr;
	}
	panel->inspected->flags.inspector_open = 0;
	panel->inspected->inspector = NULL;

	WMRemoveNotificationObserver(panel);

	wWindowUnmap(panel->frame);
	wUnmanageWindow(panel->frame, True, False);

	freeInspector(panel);
}

void wDestroyInspectorPanels(void)
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

static void changePage(WMWidget *bPtr, void *client_data)
{
	InspectorPanel *panel = (InspectorPanel *) client_data;
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

static int showIconFor(WMScreen *scrPtr, InspectorPanel *panel, const char *wm_instance, const char *wm_class, int flags)
{
	WMPixmap *pixmap = (WMPixmap *) NULL;
	char *file = NULL, *path = NULL;

	if ((flags & USE_TEXT_FIELD) != 0) {
		file = WMGetTextFieldText(panel->fileText);
		if (file && file[0] == 0) {
			wfree(file);
			file = NULL;
		}
	} else if (flags & REVERT_TO_DEFAULT) {
		const char *db_icon;

		/* Get the application icon, default NOT included */
		db_icon = wDefaultGetIconFile(wm_instance, wm_class, False);
		if (db_icon != NULL) {
			file = wstrdup(db_icon);
			flags |= UPDATE_TEXT_FIELD;
		}
	}

	if ((flags & UPDATE_TEXT_FIELD) != 0)
		WMSetTextFieldText(panel->fileText, file);

	if (file) {
		path = FindImage(wPreferences.icon_path, file);

		if (!path) {
			char *buf;
			int len = strlen(file) + 80;

			buf = wmalloc(len);
			snprintf(buf, len, _("Could not find icon \"%s\" specified for this window"), file);
			wMessageDialog(panel->frame->screen_ptr, _("Error"), buf, _("OK"), NULL, NULL);
			wfree(buf);
			wfree(file);
			return -1;
		}

		pixmap = WMCreatePixmapFromFile(scrPtr, path);
		wfree(path);

		if (!pixmap) {
			char *buf;
			int len = strlen(file) + 80;

			buf = wmalloc(len);
			snprintf(buf, len, _("Could not open specified icon \"%s\":%s"),
				 file, RMessageForError(RErrorCode));
			wMessageDialog(panel->frame->screen_ptr, _("Error"), buf, _("OK"), NULL, NULL);
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

static int getBool(WMPropList *value)
{
	char *val;

	if (!WMIsPLString(value))
		return 0;

	val = WMGetFromPLString(value);
	if (val == NULL)
		return 0;

	if ((val[1] == '\0' &&
	     (val[0] == 'y' || val[0] == 'Y' || val[0] == 'T' ||
	      val[0] == 't' || val[0] == '1')) ||
	     (strcasecmp(val, "YES") == 0 || strcasecmp(val, "TRUE") == 0)) {
		return 1;
	} else if ((val[1] == '\0' &&
		   (val[0] == 'n' || val[0] == 'N' || val[0] == 'F' ||
		    val[0] == 'f' || val[0] == '0')) ||
		   (strcasecmp(val, "NO") == 0 || strcasecmp(val, "FALSE") == 0)) {
		return 0;
	} else {
		wwarning(_("can't convert \"%s\" to boolean"), val);
		return 0;
	}
}

/* Will insert the attribute = value; pair in window's list,
 * if it's different from the defaults.
 * Defaults means either defaults database, or attributes saved
 * for the default window "*". This is to let one revert options that are
 * global because they were saved for all windows ("*"). */
static int
insertAttribute(WMPropList *dict, WMPropList *window, WMPropList *attr, WMPropList *value, int flags)
{
	WMPropList *def_win, *def_value = NULL;
	int update = 0, modified = 0;

	if (!(flags & UPDATE_DEFAULTS) && dict) {
		def_win = WMGetFromPLDictionary(dict, AnyWindow);
		if (def_win != NULL)
			def_value = WMGetFromPLDictionary(def_win, attr);
	}

	/* If we could not find defaults in database, fall to hardcoded values.
	 * Also this is true if we save defaults for all windows */
	if (!def_value)
		def_value = ((flags & IS_BOOLEAN) != 0) ? No : EmptyString;

	if (flags & IS_BOOLEAN)
		update = (getBool(value) != getBool(def_value));
	else
		update = !WMIsPropListEqualTo(value, def_value);

	if (update) {
		WMPutInPLDictionary(window, attr, value);
		modified = 1;
	}

	return modified;
}

static void saveSettings(WMWidget *button, void *client_data)
{
	InspectorPanel *panel = (InspectorPanel *) client_data;
	WWindow *wwin = panel->inspected;
	WDDomain *db = w_global.domain.window_attr;
	WMPropList *dict = NULL;
	WMPropList *winDic, *appDic, *value, *value1, *key = NULL, *key2;
	char *icon_file, *buf1, *buf2;
	int flags = 0, i = 0, different = 0, different2 = 0;

	/* Save will apply the changes and save them */
	applySettings(panel->applyBtn, panel);

	if (WMGetButtonSelected(panel->instRb) != 0) {
		key = WMCreatePLString(wwin->wm_instance);
	} else if (WMGetButtonSelected(panel->clsRb) != 0) {
		key = WMCreatePLString(wwin->wm_class);
	} else if (WMGetButtonSelected(panel->bothRb) != 0) {
		buf1 = StrConcatDot(wwin->wm_instance, wwin->wm_class);
		key = WMCreatePLString(buf1);
		wfree(buf1);
	} else if (WMGetButtonSelected(panel->defaultRb) != 0) {
		key = WMRetainPropList(AnyWindow);
		flags = UPDATE_DEFAULTS;
	}

	if (!key)
		return;

	dict = db->dictionary;
	if (!dict) {
		dict = WMCreatePLDictionary(NULL, NULL);
		if (dict) {
			db->dictionary = dict;
		} else {
			WMReleasePropList(key);
			return;
		}
	}

	if (showIconFor(WMWidgetScreen(button), panel, NULL, NULL, USE_TEXT_FIELD) < 0)
		return;

	WMPLSetCaseSensitive(True);

	winDic = WMCreatePLDictionary(NULL, NULL);
	appDic = WMCreatePLDictionary(NULL, NULL);

	/* Save the icon info */
	/* The flag "Ignore client suplied icon is not selected" */
	buf1 = wmalloc(4);
	snprintf(buf1, 4, "%s", (WMGetButtonSelected(panel->alwChk) != 0) ? "Yes" : "No");
	value1 = WMCreatePLString(buf1);
	different |= insertAttribute(dict, winDic, AAlwaysUserIcon, value1, flags);
	WMReleasePropList(value1);
	wfree(buf1);

	/* The icon filename (if exists) */
	icon_file = WMGetTextFieldText(panel->fileText);
	if (icon_file != NULL) {
		if (icon_file[0] != '\0') {
			value = WMCreatePLString(icon_file);
			different |= insertAttribute(dict, winDic, AIcon, value, flags);
			different2 |= insertAttribute(dict, appDic, AIcon, value, flags);
			WMReleasePropList(value);
		}
		wfree(icon_file);
	}

	i = WMGetPopUpButtonSelectedItem(panel->wsP) - 1;
	if (i >= 0 && i < panel->frame->screen_ptr->workspace_count) {
		value = WMCreatePLString(panel->frame->screen_ptr->workspaces[i]->name);
		different |= insertAttribute(dict, winDic, AStartWorkspace, value, flags);
		WMReleasePropList(value);
	}

	flags |= IS_BOOLEAN;

	/* Attributes... --> Window Attributes */
	for (i = 0; i < wlengthof(window_attribute); i++) {
		value = (WMGetButtonSelected(panel->attrChk[i]) != 0) ? Yes : No;
		different |= insertAttribute(dict, winDic, pl_attribute[i], value, flags);
	}

	/* Attributes... --> Advanced Options */
	for (i = 0; i < wlengthof(advanced_option); i++) {
		value = (WMGetButtonSelected(panel->moreChk[i]) != 0) ? Yes : No;
		different |= insertAttribute(dict, winDic, pl_advoptions[i], value, flags);
	}

	/* Attributes... --> Application Specific */
	if (wwin->main_window != None && wApplicationOf(wwin->main_window) != NULL) {
		for (i = 0; i < wlengthof(application_attr); i++) {
			value = (WMGetButtonSelected(panel->appChk[i]) != 0) ? Yes : No;
			different2 |= insertAttribute(dict, appDic, pl_appattrib[i], value, flags);
		}
	}

	if (wwin->fake_group) {
		key2 = WMCreatePLString(wwin->fake_group->identifier);
		if (WMIsPropListEqualTo(key, key2)) {
			WMMergePLDictionaries(winDic, appDic, True);
			different |= different2;
		} else {
			WMRemoveFromPLDictionary(dict, key2);
			if (different2)
				WMPutInPLDictionary(dict, key2, appDic);
		}
		WMReleasePropList(key2);
	} else if (wwin->main_window != wwin->client_win) {
		WApplication *wapp = wApplicationOf(wwin->main_window);

		if (wapp) {
			buf2 = StrConcatDot(wapp->main_window_desc->wm_instance,
					      wapp->main_window_desc->wm_class);
			key2 = WMCreatePLString(buf2);
			wfree(buf2);

			if (WMIsPropListEqualTo(key, key2)) {
				WMMergePLDictionaries(winDic, appDic, True);
				different |= different2;
			} else {
				WMRemoveFromPLDictionary(dict, key2);
				if (different2)
					WMPutInPLDictionary(dict, key2, appDic);
			}
			WMReleasePropList(key2);
		}
	} else {
		WMMergePLDictionaries(winDic, appDic, True);
		different |= different2;
	}
	WMReleasePropList(appDic);

	WMRemoveFromPLDictionary(dict, key);
	if (different)
		WMPutInPLDictionary(dict, key, winDic);

	WMReleasePropList(key);
	WMReleasePropList(winDic);

	UpdateDomainFile(db);

	/* clean up */
	WMPLSetCaseSensitive(False);
}

static void applySettings(WMWidget *button, void *client_data)
{
	InspectorPanel *panel = (InspectorPanel *) client_data;
	WWindow *wwin = panel->inspected;
	WApplication *wapp = wApplicationOf(wwin->main_window);
	int old_skip_window_list, old_omnipresent, old_no_bind_keys, old_no_bind_mouse;
	int i;

	old_skip_window_list = WFLAGP(wwin, skip_window_list);
	old_omnipresent = WFLAGP(wwin, omnipresent);
	old_no_bind_keys = WFLAGP(wwin, no_bind_keys);
	old_no_bind_mouse = WFLAGP(wwin, no_bind_mouse);

	showIconFor(WMWidgetScreen(button), panel, NULL, NULL, USE_TEXT_FIELD);

	/* Attributes... --> Window Attributes */
	for (i = 0; i < wlengthof(window_attribute); i++) {
		if (WMGetButtonSelected(panel->attrChk[i]))
			set_attr_flag(&wwin->user_flags, &window_attribute[i].flag);
		else
			clear_attr_flag(&wwin->user_flags, &window_attribute[i].flag);

		set_attr_flag(&wwin->defined_user_flags, &window_attribute[i].flag);
	}

	/* Attributes... --> Advanced Options */
	for (i = 0; i < wlengthof(advanced_option); i++) {
		if (WMGetButtonSelected(panel->moreChk[i]))
			set_attr_flag(&wwin->user_flags, &advanced_option[i].flag);
		else
			clear_attr_flag(&wwin->user_flags, &advanced_option[i].flag);

		set_attr_flag(&wwin->defined_user_flags, &advanced_option[i].flag);
	}

	WSETUFLAG(wwin, always_user_icon, WMGetButtonSelected(panel->alwChk));

	if (WFLAGP(wwin, no_titlebar) && wwin->flags.shaded)
		wUnshadeWindow(wwin);

	WSETUFLAG(wwin, no_shadeable, WFLAGP(wwin, no_titlebar));

	/*
	 * Update the window level according to AlwaysOnTop/AlwaysOnBotton
	 * if the level did not change, ChangeStackingLevel will do nothing anyway
	 */
	if (WFLAGP(wwin, floating))
		ChangeStackingLevel(wwin->frame->core, WMFloatingLevel);
	else if (WFLAGP(wwin, sunken))
		ChangeStackingLevel(wwin->frame->core, WMSunkenLevel);
	else
		ChangeStackingLevel(wwin->frame->core, WMNormalLevel);

	wwin->flags.omnipresent = 0;

	if (WFLAGP(wwin, skip_window_list) != old_skip_window_list) {
		UpdateSwitchMenu(wwin->screen_ptr, wwin, WFLAGP(wwin, skip_window_list)?ACTION_REMOVE:ACTION_ADD);
	} else {
		if (WFLAGP(wwin, omnipresent) != old_omnipresent)
			WMPostNotificationName(WMNChangedState, wwin, "omnipresent");
	}

	if (WFLAGP(wwin, no_bind_keys) != old_no_bind_keys) {
		if (WFLAGP(wwin, no_bind_keys))
			XUngrabKey(dpy, AnyKey, AnyModifier, wwin->frame->core->window);
		else
			wWindowSetKeyGrabs(wwin);
	}

	if (WFLAGP(wwin, no_bind_mouse) != old_no_bind_mouse)
		wWindowResetMouseGrabs(wwin);

	wwin->frame->flags.need_texture_change = 1;
	wWindowConfigureBorders(wwin);
	wFrameWindowPaint(wwin->frame);
	wNETWMUpdateActions(wwin, False);

	/* Can't apply emulate_appicon because it will probably cause problems. */
	if (wapp) {
		/* do application wide stuff */
		for (i = 0; i < wlengthof(application_attr); i++) {
			if (WMGetButtonSelected(panel->appChk[i]))
				set_attr_flag(&wapp->main_window_desc->user_flags, &application_attr[i].flag);
			else
				clear_attr_flag(&wapp->main_window_desc->user_flags, &application_attr[i].flag);

			set_attr_flag(&wapp->main_window_desc->defined_user_flags, &application_attr[i].flag);
		}

		if (WFLAGP(wapp->main_window_desc, no_appicon))
			unpaint_app_icon(wapp);
		else
			paint_app_icon(wapp);

		char *file = WMGetTextFieldText(panel->fileText);
		if (file[0] == 0) {
			wfree(file);
			file = NULL;
		}

		/* If always_user_icon flag is set, but the user icon is not set
		 * we use client supplied icon and we unset the flag */
		if ((WFLAGP(wwin, always_user_icon) && (!file))) {
			/* Show the warning */
			char *buf;
			int len = 100;

			buf = wmalloc(len);
			snprintf(buf, len, _("Ignore client supplied icon is set, but icon filename textbox is empty. Using client supplied icon"));
			wMessageDialog(panel->frame->screen_ptr, _("Warning"), buf, _("OK"), NULL, NULL);
			wfree(buf);
			wfree(file);

			/* Change the flags */
			WSETUFLAG(wwin, always_user_icon, 0);
			WMSetButtonSelected(panel->alwChk, 0);
		}

		/* After test the always_user_icon flag value before,
		 * the "else" block is used only if the flag is set and
		 * the icon text box has an icon path */
		if (!WFLAGP(wwin, always_user_icon)) {
			/* Change App Icon image, using the icon provided by the client */
			if (wapp->app_icon) {
				RImage *image = get_rimage_icon_from_wm_hints(wapp->app_icon->icon);
				if (image) {
					set_icon_image_from_image(wapp->app_icon->icon, image);
					update_icon_pixmap(wapp->app_icon->icon);
				} else {
					wIconUpdate(wapp->app_icon->icon);
				}
			}

			/* Change icon image if the app is minimized,
			 * using the icon provided by the client */
			if (wwin->icon) {
				RImage *image = get_rimage_icon_from_wm_hints(wwin->icon);
				if (image) {
					set_icon_image_from_image(wwin->icon, image);
					update_icon_pixmap(wwin->icon);
				} else {
					wIconUpdate(wwin->icon);
				}
			}
		} else {
			/* Change App Icon image */
			if (wapp->app_icon)
				wIconChangeImageFile(wapp->app_icon->icon, file);

			/* Change icon image if the app is minimized */
			if (wwin->icon)
				wIconChangeImageFile(wwin->icon, file);
		}

		if (file)
			wfree(file);
	}

	wNETFrameExtents(wwin);
}

static void revertSettings(WMWidget *button, void *client_data)
{
	InspectorPanel *panel = (InspectorPanel *) client_data;
	WWindow *wwin = panel->inspected;
	WApplication *wapp = wApplicationOf(wwin->main_window);
	int i, n, workspace, level;
	char *wm_instance = NULL, *wm_class = NULL;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) button;

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

	/* Attributes... --> Window Attributes */
	for (i = 0; i < wlengthof(window_attribute); i++) {
		int is_userdef, flag;

		is_userdef = get_attr_flag(&wwin->defined_user_flags, &window_attribute[i].flag);
		if (is_userdef)
			flag = get_attr_flag(&wwin->user_flags, &window_attribute[i].flag);
		else
			flag = get_attr_flag(&wwin->client_flags, &window_attribute[i].flag);

		WMSetButtonSelected(panel->attrChk[i], flag);
	}

	/* Attributes... --> Advanced Options */
	for (i = 0; i < wlengthof(advanced_option); i++) {
		int is_userdef, flag;

		is_userdef = get_attr_flag(&wwin->defined_user_flags, &advanced_option[i].flag);
		if (is_userdef)
			flag = get_attr_flag(&wwin->user_flags, &advanced_option[i].flag);
		else
			flag = get_attr_flag(&wwin->client_flags, &advanced_option[i].flag);

		WMSetButtonSelected(panel->moreChk[i], flag);
	}

	/* Attributes... --> Application Specific */
	if (panel->appFrm && wapp) {
		for (i = 0; i < wlengthof(application_attr); i++) {
			int is_userdef, flag = 0;

			is_userdef = get_attr_flag(&wapp->main_window_desc->defined_user_flags, &application_attr[i].flag);
			if (is_userdef)
				flag = get_attr_flag(&wapp->main_window_desc->user_flags, &application_attr[i].flag);
			else
				flag = get_attr_flag(&wapp->main_window_desc->client_flags, &application_attr[i].flag);

			WMSetButtonSelected(panel->appChk[i], flag);
		}
	}
	WMSetButtonSelected(panel->alwChk, WFLAGP(wwin, always_user_icon));

	showIconFor(WMWidgetScreen(panel->alwChk), panel, wm_instance, wm_class, REVERT_TO_DEFAULT);

	n = wDefaultGetStartWorkspace(wwin->screen_ptr, wm_instance, wm_class);

	if (n >= 0 && n < wwin->screen_ptr->workspace_count)
		WMSetPopUpButtonSelectedItem(panel->wsP, n + 1);
	else
		WMSetPopUpButtonSelectedItem(panel->wsP, 0);

	/* must auto apply, so that there wno't be internal
	 * inconsistencies between the state in the flags and
	 * the actual state of the window */
	applySettings(panel->applyBtn, panel);
}

static void chooseIconCallback(WMWidget *self, void *clientData)
{
	char *file;
	InspectorPanel *panel = (InspectorPanel *) clientData;
	int result;

	panel->choosingIcon = 1;

	WMSetButtonEnabled(panel->browseIconBtn, False);

	result = wIconChooserDialog(panel->frame->screen_ptr, &file,
				    panel->inspected->wm_instance,
				    panel->inspected->wm_class);

	panel->choosingIcon = 0;

	if (!panel->destroyed) {	/* kluge */
		if (result) {
			WMSetTextFieldText(panel->fileText, file);
			showIconFor(WMWidgetScreen(self), panel, NULL, NULL, USE_TEXT_FIELD);
		}
		WMSetButtonEnabled(panel->browseIconBtn, True);
	} else {
		freeInspector(panel);
	}
	if (result)
		wfree(file);
}

static void textEditedObserver(void *observerData, WMNotification *notification)
{
	InspectorPanel *panel = (InspectorPanel *) observerData;

	if ((long)WMGetNotificationClientData(notification) != WMReturnTextMovement)
		return;

	showIconFor(WMWidgetScreen(panel->win), panel, NULL, NULL, USE_TEXT_FIELD);
}

static void selectSpecification(WMWidget *bPtr, void *data)
{
	InspectorPanel *panel = (InspectorPanel *) data;
	char str[256];
	WWindow *wwin = panel->inspected;

	if (bPtr == panel->defaultRb && (wwin->wm_instance || wwin->wm_class))
		WMSetButtonEnabled(panel->applyBtn, False);
	else
		WMSetButtonEnabled(panel->applyBtn, True);

	snprintf(str, sizeof(str),
	         _("Inspecting  %s.%s"),
	         wwin->wm_instance ? wwin->wm_instance : "?",
	         wwin->wm_class ? wwin->wm_class : "?");

	wFrameWindowChangeTitle(panel->frame->frame, str);
}

static void selectWindow(WMWidget *bPtr, void *data)
{
	InspectorPanel *panel = (InspectorPanel *) data;
	WWindow *wwin = panel->inspected;
	WScreen *scr = wwin->screen_ptr;
	XEvent event;
	WWindow *iwin;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) bPtr;

	if (XGrabPointer(dpy, scr->root_win, True,
			 ButtonPressMask, GrabModeAsync, GrabModeAsync, None,
			 wPreferences.cursor[WCUR_SELECT], CurrentTime) != GrabSuccess) {
		wwarning("could not grab mouse pointer");
		return;
	}

	WMSetLabelText(panel->specLbl, _("Click in the window you wish to inspect."));
	WMMaskEvent(dpy, ButtonPressMask, &event);
	XUngrabPointer(dpy, CurrentTime);

	iwin = wWindowFor(event.xbutton.subwindow);
	if (iwin && !iwin->flags.internal_window && iwin != wwin && !iwin->flags.inspector_open) {
		iwin->flags.inspector_open = 1;
		iwin->inspector = createInspectorForWindow(iwin,
							   panel->frame->frame_x, panel->frame->frame_y, True);
		wCloseInspectorForWindow(wwin);
	} else {
		WMSetLabelText(panel->specLbl, spec_text);
	}
}

static InspectorPanel *createInspectorForWindow(WWindow *wwin, int xpos, int ypos, Bool showSelectPanel)
{
	WScreen *scr = wwin->screen_ptr;
	InspectorPanel *panel;
	Window parent;
	char *str = NULL, *tmp = NULL;
	int x, y, btn_width, frame_width;
	WMButton *selectedBtn = NULL;

	spec_text = _("The configuration will apply to all\n"
		      "windows that have their WM_CLASS\n"
		      "property set to the above selected\n" "name, when saved.");

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
	btn_width = (PWIDTH - (2 * 15) - (2 * 10)) / 3;
	panel->saveBtn = WMCreateCommandButton(panel->win);
	WMSetButtonAction(panel->saveBtn, saveSettings, panel);
	WMMoveWidget(panel->saveBtn, (2 * (btn_width + 10)) + 15, PHEIGHT - 40);
	WMSetButtonText(panel->saveBtn, _("Save"));
	WMResizeWidget(panel->saveBtn, btn_width, 28);
	if (wPreferences.flags.noupdates || !(wwin->wm_class || wwin->wm_instance))
		WMSetButtonEnabled(panel->saveBtn, False);

	panel->applyBtn = WMCreateCommandButton(panel->win);
	WMSetButtonAction(panel->applyBtn, applySettings, panel);
	WMMoveWidget(panel->applyBtn, btn_width + 10 + 15, PHEIGHT - 40);
	WMSetButtonText(panel->applyBtn, _("Apply"));
	WMResizeWidget(panel->applyBtn, btn_width, 28);

	panel->revertBtn = WMCreateCommandButton(panel->win);
	WMSetButtonAction(panel->revertBtn, revertSettings, panel);
	WMMoveWidget(panel->revertBtn, 15, PHEIGHT - 40);
	WMSetButtonText(panel->revertBtn, _("Reload"));
	WMResizeWidget(panel->revertBtn, btn_width, 28);

	/* page selection popup button */
	panel->pagePopUp = WMCreatePopUpButton(panel->win);
	WMSetPopUpButtonAction(panel->pagePopUp, changePage, panel);
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
	WMMoveWidget(panel->selWinB, 20, 145 - 24 - 10);
	WMResizeWidget(panel->selWinB, frame_width - 2 * 10 - 20, 24);
	WMSetButtonText(panel->selWinB, _("Select window"));
	WMSetButtonAction(panel->selWinB, selectWindow, panel);

	panel->specLbl = WMCreateLabel(panel->win);
	WMMoveWidget(panel->specLbl, 15, 210);
	WMResizeWidget(panel->specLbl, frame_width, 100);
	WMSetLabelText(panel->specLbl, spec_text);
	WMSetLabelWraps(panel->specLbl, True);

	WMSetLabelTextAlignment(panel->specLbl, WALeft);

	/**** attributes ****/
	create_tab_window_attributes(wwin, panel, frame_width);
	create_tab_window_advanced(wwin, panel, frame_width);
	create_tab_icon_workspace(wwin, panel);
	create_tab_app_specific(wwin, panel, frame_width);

	/* if the window is a transient, don't let it have a miniaturize button */
	if (wwin->transient_for != None && wwin->transient_for != scr->root_win)
		WMSetButtonEnabled(panel->attrChk[3], False);
	else
		WMSetButtonEnabled(panel->attrChk[3], True);

	if (!wwin->wm_class && !wwin->wm_instance)
		WMSetPopUpButtonItemEnabled(panel->pagePopUp, 0, False);

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

	parent = XCreateSimpleWindow(dpy, scr->root_win, 0, 0, PWIDTH, PHEIGHT, 0, 0, 0);
	XSelectInput(dpy, parent, KeyPressMask | KeyReleaseMask);
	panel->parent = parent;
	XReparentWindow(dpy, WMWidgetXID(panel->win), parent, 0, 0);

	WMMapWidget(panel->win);

	XSetTransientForHint(dpy, parent, wwin->client_win);

	if (xpos == UNDEFINED_POS) {
		x = wwin->frame_x + wwin->frame->core->width / 2;
		y = wwin->frame_y + wwin->frame->top_width * 2;
		if (y + PHEIGHT > scr->scr_height)
			y = scr->scr_height - PHEIGHT - 30;
		if (x + PWIDTH > scr->scr_width)
			x = scr->scr_width - PWIDTH;
	} else {
		x = xpos;
		y = ypos;
	}

	panel->frame = wManageInternalWindow(scr, parent, wwin->client_win, "Inspector", x, y, PWIDTH, PHEIGHT);

	if (!selectedBtn)
		selectedBtn = panel->defaultRb;

	WMSetButtonSelected(selectedBtn, True);
	selectSpecification(selectedBtn, panel);

	/* kluge to know who should get the key events */
	panel->frame->client_leader = WMWidgetXID(panel->win);

	panel->frame->client_flags.no_closable = 0;
	panel->frame->client_flags.no_close_button = 0;
	wWindowUpdateButtonImages(panel->frame);
	wFrameWindowShowButton(panel->frame->frame, WFF_RIGHT_BUTTON);
	panel->frame->frame->on_click_right = destroyInspector;

	wWindowMap(panel->frame);

	showIconFor(WMWidgetScreen(panel->alwChk), panel, wwin->wm_instance, wwin->wm_class, UPDATE_TEXT_FIELD);

	return panel;
}

void wShowInspectorForWindow(WWindow *wwin)
{
	if (wwin->flags.inspector_open)
		return;

	WMSetBalloonEnabled(wwin->screen_ptr->wmscreen, wPreferences.help_balloon);

	make_keys();
	wwin->flags.inspector_open = 1;
	wwin->inspector = createInspectorForWindow(wwin, UNDEFINED_POS, UNDEFINED_POS, False);
}

void wHideInspectorForWindow(WWindow *wwin)
{
	WWindow *pwin = wwin->inspector->frame;

	wWindowUnmap(pwin);
	pwin->flags.hidden = 1;

	wClientSetState(pwin, IconicState, None);
}

void wUnhideInspectorForWindow(WWindow *wwin)
{
	WWindow *pwin = wwin->inspector->frame;

	pwin->flags.hidden = 0;
	pwin->flags.mapped = 1;
	XMapWindow(dpy, pwin->client_win);
	XMapWindow(dpy, pwin->frame->core->window);
	wClientSetState(pwin, NormalState, None);
}

WWindow *wGetWindowOfInspectorForWindow(WWindow *wwin)
{
	if (!wwin->inspector)
		return NULL;

	assert(wwin->flags.inspector_open != 0);
	return wwin->inspector->frame;
}

void wCloseInspectorForWindow(WWindow *wwin)
{
	WWindow *pwin = wwin->inspector->frame;	/* the inspector window */

	(*pwin->frame->on_click_right) (NULL, pwin, NULL);
}

static void create_tab_window_attributes(WWindow *wwin, InspectorPanel *panel, int frame_width)
{
	int i = 0;

	panel->attrFrm = WMCreateFrame(panel->win);
	WMSetFrameTitle(panel->attrFrm, _("Attributes"));
	WMMoveWidget(panel->attrFrm, 15, 45);
	WMResizeWidget(panel->attrFrm, frame_width, 250);

	for (i = 0; i < wlengthof(window_attribute); i++) {
		int is_userdef, flag;

		is_userdef = get_attr_flag(&wwin->defined_user_flags, &window_attribute[i].flag);
		if (is_userdef)
			flag = get_attr_flag(&wwin->user_flags, &window_attribute[i].flag);
		else
			flag = get_attr_flag(&wwin->client_flags, &window_attribute[i].flag);

		panel->attrChk[i] = WMCreateSwitchButton(panel->attrFrm);
		WMMoveWidget(panel->attrChk[i], 10, 20 * (i + 1));
		WMResizeWidget(panel->attrChk[i], frame_width - 15, 20);
		WMSetButtonSelected(panel->attrChk[i], flag);
		WMSetButtonText(panel->attrChk[i], _(window_attribute[i].caption));

		WMSetBalloonTextForView(_(window_attribute[i].description), WMWidgetView(panel->attrChk[i]));
	}
}

static void create_tab_window_advanced(WWindow *wwin, InspectorPanel *panel, int frame_width)
{
	int i = 0;

	panel->moreFrm = WMCreateFrame(panel->win);
	WMSetFrameTitle(panel->moreFrm, _("Advanced"));
	WMMoveWidget(panel->moreFrm, 15, 45);
	WMResizeWidget(panel->moreFrm, frame_width, 265);

	for (i = 0; i < wlengthof(advanced_option); i++) {
		int is_userdef, flag;

		is_userdef = get_attr_flag(&wwin->defined_user_flags, &advanced_option[i].flag);
		if (is_userdef)
			flag = get_attr_flag(&wwin->user_flags, &advanced_option[i].flag);
		else
			flag = get_attr_flag(&wwin->client_flags, &advanced_option[i].flag);

		panel->moreChk[i] = WMCreateSwitchButton(panel->moreFrm);
		WMMoveWidget(panel->moreChk[i], 10, 20 * (i + 1) - 4);
		WMResizeWidget(panel->moreChk[i], frame_width - 15, 20);
		WMSetButtonSelected(panel->moreChk[i], flag);
		WMSetButtonText(panel->moreChk[i], _(advanced_option[i].caption));

		WMSetBalloonTextForView(_(advanced_option[i].description), WMWidgetView(panel->moreChk[i]));
	}
}

static void create_tab_icon_workspace(WWindow *wwin, InspectorPanel *panel)
{
	WScreen *scr = wwin->screen_ptr;
	int i = 0;

	/* miniwindow/workspace */
	panel->iconFrm = WMCreateFrame(panel->win);
	WMMoveWidget(panel->iconFrm, 15, 50);
	WMResizeWidget(panel->iconFrm, PWIDTH - (2 * 15), 170);
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

	panel->fileLbl = WMCreateLabel(panel->iconFrm);
	WMMoveWidget(panel->fileLbl, 20, 85);
	WMResizeWidget(panel->fileLbl, PWIDTH - (2 * 15) - (2 * 20), 14);
	WMSetLabelText(panel->fileLbl, _("Icon filename:"));

	panel->fileText = WMCreateTextField(panel->iconFrm);
	WMMoveWidget(panel->fileText, 20, 105);
	WMResizeWidget(panel->fileText, PWIDTH - (2 * 20) - (2 * 15), 20);
	WMSetTextFieldText(panel->fileText, NULL);
	WMAddNotificationObserver(textEditedObserver, panel, WMTextDidEndEditingNotification, panel->fileText);

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
				  " first shown."), WMWidgetView(panel->wsFrm));

	panel->wsP = WMCreatePopUpButton(panel->wsFrm);
	WMMoveWidget(panel->wsP, 20, 30);
	WMResizeWidget(panel->wsP, PWIDTH - (2 * 15) - (2 * 20), 20);
	WMAddPopUpButtonItem(panel->wsP, _("Nowhere in particular"));

	for (i = 0; i < wwin->screen_ptr->workspace_count; i++)
		WMAddPopUpButtonItem(panel->wsP, scr->workspaces[i]->name);

	i = wDefaultGetStartWorkspace(wwin->screen_ptr, wwin->wm_instance, wwin->wm_class);
	if (i >= 0 && i <= wwin->screen_ptr->workspace_count)
		WMSetPopUpButtonSelectedItem(panel->wsP, i + 1);
	else
		WMSetPopUpButtonSelectedItem(panel->wsP, 0);
}

static void create_tab_app_specific(WWindow *wwin, InspectorPanel *panel, int frame_width)
{
	WScreen *scr = wwin->screen_ptr;
	int i = 0, tmp;

	if (wwin->main_window != None) {
		WApplication *wapp = wApplicationOf(wwin->main_window);

		panel->appFrm = WMCreateFrame(panel->win);
		WMSetFrameTitle(panel->appFrm, _("Application Attributes"));
		WMMoveWidget(panel->appFrm, 15, 50);
		WMResizeWidget(panel->appFrm, frame_width, 240);

		for (i = 0; i < wlengthof(application_attr); i++) {
			int is_userdef, flag;

			is_userdef = get_attr_flag(&wapp->main_window_desc->defined_user_flags, &application_attr[i].flag);
			if (is_userdef)
				flag = get_attr_flag(&wapp->main_window_desc->user_flags, &application_attr[i].flag);
			else
				flag = get_attr_flag(&wapp->main_window_desc->client_flags, &application_attr[i].flag);

			panel->appChk[i] = WMCreateSwitchButton(panel->appFrm);
			WMMoveWidget(panel->appChk[i], 10, 20 * (i + 1));
			WMResizeWidget(panel->appChk[i], 205, 20);
			WMSetButtonSelected(panel->appChk[i], flag);
			WMSetButtonText(panel->appChk[i], _(application_attr[i].caption));

			WMSetBalloonTextForView(_(application_attr[i].description),
			                        WMWidgetView(panel->appChk[i]));
		}

		if (WFLAGP(wwin, emulate_appicon)) {
			WMSetButtonEnabled(panel->appChk[1], False);
			WMSetButtonEnabled(panel->moreChk[7], True);
		} else {
			WMSetButtonEnabled(panel->appChk[1], True);
			WMSetButtonEnabled(panel->moreChk[7], False);
		}
	} else {
		if ((wwin->transient_for != None && wwin->transient_for != scr->root_win)
		    || !wwin->wm_class || !wwin->wm_instance)
			tmp = False;
		else
			tmp = True;

		WMSetButtonEnabled(panel->moreChk[7], tmp);

		WMSetPopUpButtonItemEnabled(panel->pagePopUp, 4, False);
		panel->appFrm = NULL;
	}
}
