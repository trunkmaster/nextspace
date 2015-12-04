/* KeyboardShortcuts.c- keyboard shortcut bindings
 *
 *  WPrefs - Window Maker Preferences Program
 *
 *  Copyright (c) 1998-2003 Alfredo K. Kojima
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

#include "config.h"		/* for HAVE_XCONVERTCASE */

#include "WPrefs.h"
#include <ctype.h>

#include <X11/keysym.h>
#include <X11/XKBlib.h>

typedef struct _Panel {
	WMBox *box;

	char *sectionName;

	char *description;

	CallbackRec callbacks;

	WMWidget *parent;

	WMLabel *actL;
	WMList *actLs;

	WMFrame *shoF;
	WMTextField *shoT;
	WMButton *cleB;
	WMButton *defB;

	WMLabel *instructionsL;

	WMColor *white;
	WMColor *black;
	WMColor *gray;
	WMFont *font;

	Bool capturing;
	char **shortcuts;
	int actionCount;
} _Panel;

#define ICON_FILE	"keyshortcuts"

/*
 * List of user definable shortcut keys
 * First parameter is the internal keyword known by WMaker
 * Second is the text displayed to the user
 */
static const struct {
	const char *key;
	const char *title;
} keyOptions[] = {
	{ "RootMenuKey",    N_("Open applications menu") },
	{ "WindowListKey",  N_("Open window list menu") },
	{ "WindowMenuKey",  N_("Open window commands menu") },
	{ "HideKey",        N_("Hide active application") },
	{ "HideOthersKey",  N_("Hide other applications") },
	{ "MiniaturizeKey", N_("Miniaturize active window") },
	{ "MinimizeAllKey", N_("Miniaturize all windows") },
	{ "CloseKey",       N_("Close active window") },
	{ "MaximizeKey",    N_("Maximize active window") },
	{ "VMaximizeKey",   N_("Maximize active window vertically") },
	{ "HMaximizeKey",   N_("Maximize active window horizontally") },
	{ "LHMaximizeKey",  N_("Maximize active window left half") },
	{ "RHMaximizeKey",  N_("Maximize active window right half") },
	{ "THMaximizeKey",  N_("Maximize active window top half") },
	{ "BHMaximizeKey",  N_("Maximize active window bottom half") },
	{ "LTCMaximizeKey", N_("Maximize active window left top corner") },
	{ "RTCMaximizeKey", N_("Maximize active window right top corner") },
	{ "LBCMaximizeKey", N_("Maximize active window left bottom corner") },
	{ "RBCMaximizeKey", N_("Maximize active window right bottom corner") },
	{ "MaximusKey",     N_("Maximus: Tiled maximization ") },
	{ "OmnipresentKey", N_("Toggle window omnipresent status") },
	{ "RaiseKey",       N_("Raise active window") },
	{ "LowerKey",       N_("Lower active window") },
	{ "RaiseLowerKey",  N_("Raise/Lower window under mouse pointer") },
	{ "ShadeKey",       N_("Shade active window") },
	{ "MoveResizeKey",  N_("Move/Resize active window") },
	{ "SelectKey",      N_("Select active window") },
	{ "FocusNextKey",   N_("Focus next window") },
	{ "FocusPrevKey",   N_("Focus previous window") },
	{ "GroupNextKey",   N_("Focus next group window") },
	{ "GroupPrevKey",   N_("Focus previous group window") },

	/* Workspace Related */
	{ "WorkspaceMapKey",  N_("Open workspace pager") },
	{ "NextWorkspaceKey", N_("Switch to next workspace") },
	{ "PrevWorkspaceKey", N_("Switch to previous workspace") },
	{ "LastWorkspaceKey", N_("Switch to last used workspace") },
	{ "NextWorkspaceLayerKey", N_("Switch to next ten workspaces") },
	{ "PrevWorkspaceLayerKey", N_("Switch to previous ten workspaces") },
	{ "Workspace1Key",  N_("Switch to workspace 1") },
	{ "Workspace2Key",  N_("Switch to workspace 2") },
	{ "Workspace3Key",  N_("Switch to workspace 3") },
	{ "Workspace4Key",  N_("Switch to workspace 4") },
	{ "Workspace5Key",  N_("Switch to workspace 5") },
	{ "Workspace6Key",  N_("Switch to workspace 6") },
	{ "Workspace7Key",  N_("Switch to workspace 7") },
	{ "Workspace8Key",  N_("Switch to workspace 8") },
	{ "Workspace9Key",  N_("Switch to workspace 9") },
	{ "Workspace10Key", N_("Switch to workspace 10") },
	{ "MoveToNextWorkspaceKey",      N_("Move window to next workspace") },
	{ "MoveToPrevWorkspaceKey",      N_("Move window to previous workspace") },
	{ "MoveToLastWorkspaceKey",      N_("Move window to last used workspace") },
	{ "MoveToNextWorkspaceLayerKey", N_("Move window to next ten workspaces") },
	{ "MoveToPrevWorkspaceLayerKey", N_("Move window to previous ten workspaces") },
	{ "MoveToWorkspace1Key",  N_("Move window to workspace 1") },
	{ "MoveToWorkspace2Key",  N_("Move window to workspace 2") },
	{ "MoveToWorkspace3Key",  N_("Move window to workspace 3") },
	{ "MoveToWorkspace4Key",  N_("Move window to workspace 4") },
	{ "MoveToWorkspace5Key",  N_("Move window to workspace 5") },
	{ "MoveToWorkspace6Key",  N_("Move window to workspace 6") },
	{ "MoveToWorkspace7Key",  N_("Move window to workspace 7") },
	{ "MoveToWorkspace8Key",  N_("Move window to workspace 8") },
	{ "MoveToWorkspace9Key",  N_("Move window to workspace 9") },
	{ "MoveToWorkspace10Key", N_("Move window to workspace 10") },

	/* Window Selection */
	{ "WindowShortcut1Key",  N_("Shortcut for window 1") },
	{ "WindowShortcut2Key",  N_("Shortcut for window 2") },
	{ "WindowShortcut3Key",  N_("Shortcut for window 3") },
	{ "WindowShortcut4Key",  N_("Shortcut for window 4") },
	{ "WindowShortcut5Key",  N_("Shortcut for window 5") },
	{ "WindowShortcut6Key",  N_("Shortcut for window 6") },
	{ "WindowShortcut7Key",  N_("Shortcut for window 7") },
	{ "WindowShortcut8Key",  N_("Shortcut for window 8") },
	{ "WindowShortcut9Key",  N_("Shortcut for window 9") },
	{ "WindowShortcut10Key", N_("Shortcut for window 10") },

	/* Misc. */
	{ "WindowRelaunchKey", N_("Launch new instance of application") },
	{ "ScreenSwitchKey",   N_("Switch to Next Screen/Monitor") },
	{ "RunKey",            N_("Run application") },
	{ "DockRaiseLowerKey", N_("Raise/Lower Dock") },
	{ "ClipRaiseLowerKey", N_("Raise/Lower Clip") }
#ifdef XKB_MODELOCK
	,{ "ToggleKbdModeKey", N_("Toggle keyboard language") }
#endif				/* XKB_MODELOCK */
};

#ifndef HAVE_XCONVERTCASE
/* from Xlib */

static void XConvertCase(register KeySym sym, KeySym * lower, KeySym * upper)
{
	*lower = sym;
	*upper = sym;
	switch (sym >> 8) {
	case 0:		/* Latin 1 */
		if ((sym >= XK_A) && (sym <= XK_Z))
			*lower += (XK_a - XK_A);
		else if ((sym >= XK_a) && (sym <= XK_z))
			*upper -= (XK_a - XK_A);
		else if ((sym >= XK_Agrave) && (sym <= XK_Odiaeresis))
			*lower += (XK_agrave - XK_Agrave);
		else if ((sym >= XK_agrave) && (sym <= XK_odiaeresis))
			*upper -= (XK_agrave - XK_Agrave);
		else if ((sym >= XK_Ooblique) && (sym <= XK_Thorn))
			*lower += (XK_oslash - XK_Ooblique);
		else if ((sym >= XK_oslash) && (sym <= XK_thorn))
			*upper -= (XK_oslash - XK_Ooblique);
		break;
	case 1:		/* Latin 2 */
		/* Assume the KeySym is a legal value (ignore discontinuities) */
		if (sym == XK_Aogonek)
			*lower = XK_aogonek;
		else if (sym >= XK_Lstroke && sym <= XK_Sacute)
			*lower += (XK_lstroke - XK_Lstroke);
		else if (sym >= XK_Scaron && sym <= XK_Zacute)
			*lower += (XK_scaron - XK_Scaron);
		else if (sym >= XK_Zcaron && sym <= XK_Zabovedot)
			*lower += (XK_zcaron - XK_Zcaron);
		else if (sym == XK_aogonek)
			*upper = XK_Aogonek;
		else if (sym >= XK_lstroke && sym <= XK_sacute)
			*upper -= (XK_lstroke - XK_Lstroke);
		else if (sym >= XK_scaron && sym <= XK_zacute)
			*upper -= (XK_scaron - XK_Scaron);
		else if (sym >= XK_zcaron && sym <= XK_zabovedot)
			*upper -= (XK_zcaron - XK_Zcaron);
		else if (sym >= XK_Racute && sym <= XK_Tcedilla)
			*lower += (XK_racute - XK_Racute);
		else if (sym >= XK_racute && sym <= XK_tcedilla)
			*upper -= (XK_racute - XK_Racute);
		break;
	case 2:		/* Latin 3 */
		/* Assume the KeySym is a legal value (ignore discontinuities) */
		if (sym >= XK_Hstroke && sym <= XK_Hcircumflex)
			*lower += (XK_hstroke - XK_Hstroke);
		else if (sym >= XK_Gbreve && sym <= XK_Jcircumflex)
			*lower += (XK_gbreve - XK_Gbreve);
		else if (sym >= XK_hstroke && sym <= XK_hcircumflex)
			*upper -= (XK_hstroke - XK_Hstroke);
		else if (sym >= XK_gbreve && sym <= XK_jcircumflex)
			*upper -= (XK_gbreve - XK_Gbreve);
		else if (sym >= XK_Cabovedot && sym <= XK_Scircumflex)
			*lower += (XK_cabovedot - XK_Cabovedot);
		else if (sym >= XK_cabovedot && sym <= XK_scircumflex)
			*upper -= (XK_cabovedot - XK_Cabovedot);
		break;
	case 3:		/* Latin 4 */
		/* Assume the KeySym is a legal value (ignore discontinuities) */
		if (sym >= XK_Rcedilla && sym <= XK_Tslash)
			*lower += (XK_rcedilla - XK_Rcedilla);
		else if (sym >= XK_rcedilla && sym <= XK_tslash)
			*upper -= (XK_rcedilla - XK_Rcedilla);
		else if (sym == XK_ENG)
			*lower = XK_eng;
		else if (sym == XK_eng)
			*upper = XK_ENG;
		else if (sym >= XK_Amacron && sym <= XK_Umacron)
			*lower += (XK_amacron - XK_Amacron);
		else if (sym >= XK_amacron && sym <= XK_umacron)
			*upper -= (XK_amacron - XK_Amacron);
		break;
	case 6:		/* Cyrillic */
		/* Assume the KeySym is a legal value (ignore discontinuities) */
		if (sym >= XK_Serbian_DJE && sym <= XK_Serbian_DZE)
			*lower -= (XK_Serbian_DJE - XK_Serbian_dje);
		else if (sym >= XK_Serbian_dje && sym <= XK_Serbian_dze)
			*upper += (XK_Serbian_DJE - XK_Serbian_dje);
		else if (sym >= XK_Cyrillic_YU && sym <= XK_Cyrillic_HARDSIGN)
			*lower -= (XK_Cyrillic_YU - XK_Cyrillic_yu);
		else if (sym >= XK_Cyrillic_yu && sym <= XK_Cyrillic_hardsign)
			*upper += (XK_Cyrillic_YU - XK_Cyrillic_yu);
		break;
	case 7:		/* Greek */
		/* Assume the KeySym is a legal value (ignore discontinuities) */
		if (sym >= XK_Greek_ALPHAaccent && sym <= XK_Greek_OMEGAaccent)
			*lower += (XK_Greek_alphaaccent - XK_Greek_ALPHAaccent);
		else if (sym >= XK_Greek_alphaaccent && sym <= XK_Greek_omegaaccent &&
			 sym != XK_Greek_iotaaccentdieresis && sym != XK_Greek_upsilonaccentdieresis)
			*upper -= (XK_Greek_alphaaccent - XK_Greek_ALPHAaccent);
		else if (sym >= XK_Greek_ALPHA && sym <= XK_Greek_OMEGA)
			*lower += (XK_Greek_alpha - XK_Greek_ALPHA);
		else if (sym >= XK_Greek_alpha && sym <= XK_Greek_omega && sym != XK_Greek_finalsmallsigma)
			*upper -= (XK_Greek_alpha - XK_Greek_ALPHA);
		break;
	case 0x14:		/* Armenian */
		if (sym >= XK_Armenian_AYB && sym <= XK_Armenian_fe) {
			*lower = sym | 1;
			*upper = sym & ~1;
		}
		break;
	}
}
#endif

static int NumLockMask(Display *dpy)
{
	int i, mask;
	XModifierKeymap *map;
	static int mask_table[8] = {
		ShiftMask, LockMask, ControlMask, Mod1Mask,
		Mod2Mask, Mod3Mask, Mod4Mask, Mod5Mask
	};
	KeyCode numlock_keycode = XKeysymToKeycode(dpy, XK_Num_Lock);

	if (numlock_keycode == NoSymbol)
		return 0;

	map = XGetModifierMapping(dpy);
	if (!map)
		return 0;

	mask = 0;
	for (i = 0; i < 8 * map->max_keypermod; i++) {
		if (map->modifiermap[i] == numlock_keycode && mask == 0) {
			mask = mask_table[i/map->max_keypermod];
			break;
		}
	}

	if (map)
		XFreeModifiermap(map);

	return mask;
}

char *capture_shortcut(Display *dpy, Bool *capturing, Bool convert_case)
{
	XEvent ev;
	KeySym ksym, lksym, uksym;
	char buffer[64];
	char *key = NULL;
	unsigned int numlock_mask;

	while (*capturing) {
		XAllowEvents(dpy, AsyncKeyboard, CurrentTime);
		WMNextEvent(dpy, &ev);
		if (ev.type == KeyPress && ev.xkey.keycode != 0) {
			numlock_mask = NumLockMask(dpy);

			if (xext_xkb_supported)
				/* conditional mask check to get numeric keypad keys */
				ksym = XkbKeycodeToKeysym(dpy, ev.xkey.keycode, 0, ev.xkey.state & numlock_mask?1:0);
			else
				ksym = XKeycodeToKeysym(dpy, ev.xkey.keycode, 0);

			if (!IsModifierKey(ksym)) {
				if (convert_case) {
					XConvertCase(ksym, &lksym, &uksym);
					key = XKeysymToString(uksym);
				} else {
					key = XKeysymToString(ksym);
				}

				*capturing = 0;
				break;
			}
		}
		WMHandleEvent(&ev);
	}

	if (!key)
		return NULL;

	buffer[0] = 0;

	if (ev.xkey.state & ControlMask)
		strcat(buffer, "Control+");

	if (ev.xkey.state & ShiftMask)
		strcat(buffer, "Shift+");

	if ((numlock_mask != Mod1Mask) && (ev.xkey.state & Mod1Mask))
		strcat(buffer, "Mod1+");

	if ((numlock_mask != Mod2Mask) && (ev.xkey.state & Mod2Mask))
		strcat(buffer, "Mod2+");

	if ((numlock_mask != Mod3Mask) && (ev.xkey.state & Mod3Mask))
		strcat(buffer, "Mod3+");

	if ((numlock_mask != Mod4Mask) && (ev.xkey.state & Mod4Mask))
		strcat(buffer, "Mod4+");

	if ((numlock_mask != Mod5Mask) && (ev.xkey.state & Mod5Mask))
		strcat(buffer, "Mod5+");

	wstrlcat(buffer, key, sizeof(buffer));

	return wstrdup(buffer);
}

static void captureClick(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	Display *dpy = WMScreenDisplay(WMWidgetScreen(panel->parent));
	char *shortcut;

	if (!panel->capturing) {
		panel->capturing = 1;
		WMSetButtonText(w, _("Cancel"));
		WMSetLabelText(panel->instructionsL,
			       _("Press the desired shortcut key(s) or click Cancel to stop capturing."));
		XGrabKeyboard(dpy, WMWidgetXID(panel->parent), True, GrabModeAsync, GrabModeAsync, CurrentTime);
		shortcut = capture_shortcut(dpy, &panel->capturing, 1);
		if (shortcut) {
			int row = WMGetListSelectedItemRow(panel->actLs);

			WMSetTextFieldText(panel->shoT, shortcut);
			if (row >= 0) {
				if (panel->shortcuts[row])
					wfree(panel->shortcuts[row]);
				panel->shortcuts[row] = shortcut;

				WMRedisplayWidget(panel->actLs);
			} else {
				wfree(shortcut);
			}
		}
	}
	panel->capturing = 0;
	WMSetButtonText(w, _("Capture"));
	WMSetLabelText(panel->instructionsL, _("Click on Capture to interactively define the shortcut key."));
	XUngrabKeyboard(dpy, CurrentTime);
}

static void clearShortcut(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int row = WMGetListSelectedItemRow(panel->actLs);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	WMSetTextFieldText(panel->shoT, NULL);

	if (row >= 0) {
		if (panel->shortcuts[row])
			wfree(panel->shortcuts[row]);
		panel->shortcuts[row] = NULL;
		WMRedisplayWidget(panel->actLs);
	}
}

static void typedKeys(void *observerData, WMNotification * notification)
{
	_Panel *panel = (_Panel *) observerData;
	int row = WMGetListSelectedItemRow(panel->actLs);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) notification;

	if (row < 0)
		return;

	if (panel->shortcuts[row])
		wfree(panel->shortcuts[row]);
	panel->shortcuts[row] = WMGetTextFieldText(panel->shoT);
	if (strlen(panel->shortcuts[row]) == 0) {
		wfree(panel->shortcuts[row]);
		panel->shortcuts[row] = NULL;
	}
	WMRedisplayWidget(panel->actLs);
}

static void listClick(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int row = WMGetListSelectedItemRow(w);

	WMSetTextFieldText(panel->shoT, panel->shortcuts[row]);
}

static void showData(_Panel * panel)
{
	char *str;
	int i;

	for (i = 0; i < panel->actionCount; i++) {

		str = GetStringForKey(keyOptions[i].key);
		if (panel->shortcuts[i])
			wfree(panel->shortcuts[i]);
		if (str)
			panel->shortcuts[i] = wtrimspace(str);
		else
			panel->shortcuts[i] = NULL;

		if (panel->shortcuts[i] &&
		    (strcasecmp(panel->shortcuts[i], "none") == 0 || strlen(panel->shortcuts[i]) == 0)) {
			wfree(panel->shortcuts[i]);
			panel->shortcuts[i] = NULL;
		}
	}
	WMRedisplayWidget(panel->actLs);
}

static void paintItem(WMList * lPtr, int index, Drawable d, char *text, int state, WMRect * rect)
{
	int width, height, x, y;
	_Panel *panel = (_Panel *) WMGetHangedData(lPtr);
	WMScreen *scr = WMWidgetScreen(lPtr);
	Display *dpy = WMScreenDisplay(scr);
	WMColor *backColor = (state & WLDSSelected) ? panel->white : panel->gray;

	width = rect->size.width;
	height = rect->size.height;
	x = rect->pos.x;
	y = rect->pos.y;

	XFillRectangle(dpy, d, WMColorGC(backColor), x, y, width, height);

	if (panel->shortcuts[index]) {
		WMPixmap *pix = WMGetSystemPixmap(scr, WSICheckMark);
		WMSize size = WMGetPixmapSize(pix);

		WMDrawPixmap(pix, d, x + (20 - size.width) / 2, (height - size.height) / 2 + y);
		WMReleasePixmap(pix);
	}

	WMDrawString(scr, d, panel->black, panel->font, x + 20, y, text, strlen(text));
}

static void createPanel(Panel * p)
{
	_Panel *panel = (_Panel *) p;
	WMScreen *scr = WMWidgetScreen(panel->parent);
	WMColor *color;
	WMFont *boldFont;
	int i;

	panel->capturing = 0;

	panel->white = WMWhiteColor(scr);
	panel->black = WMBlackColor(scr);
	panel->gray = WMGrayColor(scr);
	panel->font = WMSystemFontOfSize(scr, 12);

	panel->box = WMCreateBox(panel->parent);
	WMSetViewExpandsToParent(WMWidgetView(panel->box), 2, 2, 2, 2);

	boldFont = WMBoldSystemFontOfSize(scr, 12);

	/* **************** Actions **************** */
	panel->actL = WMCreateLabel(panel->box);
	WMResizeWidget(panel->actL, 314, 20);
	WMMoveWidget(panel->actL, 9, 9);
	WMSetLabelFont(panel->actL, boldFont);
	WMSetLabelText(panel->actL, _("Actions"));
	WMSetLabelRelief(panel->actL, WRSunken);
	WMSetLabelTextAlignment(panel->actL, WACenter);
	color = WMDarkGrayColor(scr);
	WMSetWidgetBackgroundColor(panel->actL, color);
	WMReleaseColor(color);
	WMSetLabelTextColor(panel->actL, panel->white);

	panel->actLs = WMCreateList(panel->box);
	WMResizeWidget(panel->actLs, 314, 191);
	WMMoveWidget(panel->actLs, 9, 31);
	WMSetListUserDrawProc(panel->actLs, paintItem);
	WMHangData(panel->actLs, panel);

	for (i = 0; i < wlengthof(keyOptions); i++) {
		WMAddListItem(panel->actLs, _(keyOptions[i].title));
	}
	WMSetListAction(panel->actLs, listClick, panel);

	panel->actionCount = WMGetListNumberOfRows(panel->actLs);
	panel->shortcuts = wmalloc(sizeof(char *) * panel->actionCount);

    /***************** Shortcut ****************/

	panel->shoF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->shoF, 178, 214);
	WMMoveWidget(panel->shoF, 333, 8);
	WMSetFrameTitle(panel->shoF, _("Shortcut"));

	panel->shoT = WMCreateTextField(panel->shoF);
	WMResizeWidget(panel->shoT, 160, 20);
	WMMoveWidget(panel->shoT, 9, 65);
	WMAddNotificationObserver(typedKeys, panel, WMTextDidChangeNotification, panel->shoT);

	panel->cleB = WMCreateCommandButton(panel->shoF);
	WMResizeWidget(panel->cleB, 75, 24);
	WMMoveWidget(panel->cleB, 9, 95);
	WMSetButtonText(panel->cleB, _("Clear"));
	WMSetButtonAction(panel->cleB, clearShortcut, panel);

	panel->defB = WMCreateCommandButton(panel->shoF);
	WMResizeWidget(panel->defB, 75, 24);
	WMMoveWidget(panel->defB, 94, 95);
	WMSetButtonText(panel->defB, _("Capture"));
	WMSetButtonAction(panel->defB, captureClick, panel);

	panel->instructionsL = WMCreateLabel(panel->shoF);
	WMResizeWidget(panel->instructionsL, 160, 55);
	WMMoveWidget(panel->instructionsL, 9, 140);
	WMSetLabelTextAlignment(panel->instructionsL, WACenter);
	WMSetLabelWraps(panel->instructionsL, True);
	WMSetLabelText(panel->instructionsL, _("Click on Capture to interactively define the shortcut key."));

	WMMapSubwidgets(panel->shoF);

	WMReleaseFont(boldFont);

	WMRealizeWidget(panel->box);
	WMMapSubwidgets(panel->box);

	showData(panel);
}

static void storeData(_Panel * panel)
{
	int i;
	char *str;

	for (i = 0; i < panel->actionCount; i++) {
		str = NULL;
		if (panel->shortcuts[i]) {
			str = wtrimspace(panel->shortcuts[i]);
			if (strlen(str) == 0) {
				wfree(str);
				str = NULL;
			}
		}
		if (str) {
			SetStringForKey(str, keyOptions[i].key);
			wfree(str);
		} else {
			SetStringForKey("None", keyOptions[i].key);
		}
	}
}

Panel *InitKeyboardShortcuts(WMWidget *parent)
{
	_Panel *panel;

	panel = wmalloc(sizeof(_Panel));

	panel->sectionName = _("Keyboard Shortcut Preferences");

	panel->description = _("Change the keyboard shortcuts for actions such\n"
			       "as changing workspaces and opening menus.");

	panel->parent = parent;

	panel->callbacks.createWidgets = createPanel;
	panel->callbacks.updateDomain = storeData;

	AddSection(panel, ICON_FILE);

	return panel;
}
