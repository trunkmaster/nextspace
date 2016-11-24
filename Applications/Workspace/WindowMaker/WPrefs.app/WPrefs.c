/* WPrefs.c- main window and other basic stuff
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

#include "config.h"

#include "WPrefs.h"
#include <assert.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif


#define MAX_SECTIONS 16

typedef struct _WPrefs {
	WMWindow *win;

	WMScrollView *scrollV;
	WMFrame *buttonF;
	WMButton *sectionB[MAX_SECTIONS];

	int sectionCount;

	WMButton *saveBtn;
	WMButton *closeBtn;
	WMButton *undoBtn;
	WMButton *undosBtn;

	WMButton *balloonBtn;

	WMFrame *banner;
	WMLabel *nameL;
	WMLabel *versionL;
	WMLabel *statusL;

	Panel *currentPanel;
} _WPrefs;

static _WPrefs WPrefs;

/* system wide defaults dictionary. Read-only */
static WMPropList *GlobalDB = NULL;
/* user defaults dictionary */
static WMPropList *WindowMakerDB = NULL;
static char *WindowMakerDBPath = NULL;

static Bool TIFFOK = False;

#define INITIALIZED_PANEL	(1<<0)

static void loadConfigurations(WMScreen * scr, WMWindow * mainw);

static void savePanelData(Panel * panel);

static void prepareForClose(void);

static noreturn void quit(WMWidget *w, void *data)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;
	(void) data;

	prepareForClose();

	WMReleaseApplication();
	exit(0);
}

static void save(WMWidget * w, void *data)
{
	int i;
	WMPropList *p1, *p2;
	WMPropList *keyList;
	WMPropList *key;
	XEvent ev;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) data;

	/*    puts("gathering data"); */
	for (i = 0; i < WPrefs.sectionCount; i++) {
		PanelRec *rec = WMGetHangedData(WPrefs.sectionB[i]);
		if ((rec->callbacks.flags & INITIALIZED_PANEL))
			savePanelData((Panel *) rec);
	}
	/*    puts("compressing data"); */
	/* compare the user dictionary with the global and remove redundant data */
	keyList = WMGetPLDictionaryKeys(GlobalDB);
	/*    puts(WMGetPropListDescription(WindowMakerDB, False)); */
	for (i = 0; i < WMGetPropListItemCount(keyList); i++) {
		key = WMGetFromPLArray(keyList, i);

		/* We don't have this value anyway, so no problem.
		 * Probably  a new option */
		p1 = WMGetFromPLDictionary(WindowMakerDB, key);
		if (!p1)
			continue;
		/* The global doesn't have it, so no problem either. */
		p2 = WMGetFromPLDictionary(GlobalDB, key);
		if (!p2)
			continue;
		/* If both values are the same, don't save. */
		if (WMIsPropListEqualTo(p1, p2))
			WMRemoveFromPLDictionary(WindowMakerDB, key);
	}
	/*    puts(WMGetPropListDescription(WindowMakerDB, False)); */
	WMReleasePropList(keyList);
	/*    puts("storing data"); */

	WMWritePropListToFile(WindowMakerDB, WindowMakerDBPath);

	memset(&ev, 0, sizeof(XEvent));

	ev.xclient.type = ClientMessage;
	ev.xclient.message_type = XInternAtom(WMScreenDisplay(WMWidgetScreen(w)), "_WINDOWMAKER_COMMAND", False);
	ev.xclient.window = DefaultRootWindow(WMScreenDisplay(WMWidgetScreen(w)));
	ev.xclient.format = 8;
	strncpy(ev.xclient.data.b, "Reconfigure", sizeof(ev.xclient.data.b));

	XSendEvent(WMScreenDisplay(WMWidgetScreen(w)),
		   DefaultRootWindow(WMScreenDisplay(WMWidgetScreen(w))), False, SubstructureRedirectMask, &ev);
	XFlush(WMScreenDisplay(WMWidgetScreen(w)));
}

static void undo(WMWidget * w, void *data)
{
	PanelRec *rec = (PanelRec *) WPrefs.currentPanel;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;
	(void) data;

	if (!rec)
		return;

	if (rec->callbacks.undoChanges && (rec->callbacks.flags & INITIALIZED_PANEL)) {
		(*rec->callbacks.undoChanges) (WPrefs.currentPanel);
	}
}

static void undoAll(WMWidget * w, void *data)
{
	int i;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;
	(void) data;

	for (i = 0; i < WPrefs.sectionCount; i++) {
		PanelRec *rec = WMGetHangedData(WPrefs.sectionB[i]);

		if (rec->callbacks.undoChanges && (rec->callbacks.flags & INITIALIZED_PANEL))
			(*rec->callbacks.undoChanges) ((Panel *) rec);
	}
}

static void prepareForClose(void)
{
	int i;

	for (i = 0; i < WPrefs.sectionCount; i++) {
		PanelRec *rec = WMGetHangedData(WPrefs.sectionB[i]);

		if (rec->callbacks.prepareForClose && (rec->callbacks.flags & INITIALIZED_PANEL))
			(*rec->callbacks.prepareForClose) ((Panel *) rec);
	}
}

static void toggleBalloons(WMWidget *w, void *data)
{
	WMUserDefaults *udb = WMGetStandardUserDefaults();
	Bool flag;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;
	(void) data;

	flag = WMGetButtonSelected(WPrefs.balloonBtn);

	WMSetBalloonEnabled(WMWidgetScreen(WPrefs.win), flag);

	WMSetUDBoolForKey(udb, flag, "BalloonHelp");
}

static void createMainWindow(WMScreen * scr)
{
	WMScroller *scroller;
	WMFont *font;
	char buffer[128];

	WPrefs.win = WMCreateWindow(scr, "wprefs");
	WMResizeWidget(WPrefs.win, 520, 390);
	WMSetWindowTitle(WPrefs.win, _("Window Maker Preferences"));
	WMSetWindowCloseAction(WPrefs.win, quit, NULL);
	WMSetWindowMaxSize(WPrefs.win, 520, 390);
	WMSetWindowMinSize(WPrefs.win, 520, 390);
	WMSetWindowMiniwindowTitle(WPrefs.win, _("Preferences"));

	WPrefs.scrollV = WMCreateScrollView(WPrefs.win);
	WMResizeWidget(WPrefs.scrollV, 500, 87);
	WMMoveWidget(WPrefs.scrollV, 10, 10);
	WMSetScrollViewRelief(WPrefs.scrollV, WRSunken);
	WMSetScrollViewHasHorizontalScroller(WPrefs.scrollV, True);
	WMSetScrollViewHasVerticalScroller(WPrefs.scrollV, False);
	scroller = WMGetScrollViewHorizontalScroller(WPrefs.scrollV);
	WMSetScrollerArrowsPosition(scroller, WSANone);

	WPrefs.buttonF = WMCreateFrame(WPrefs.win);
	WMSetFrameRelief(WPrefs.buttonF, WRFlat);

	WMSetScrollViewContentView(WPrefs.scrollV, WMWidgetView(WPrefs.buttonF));

	WPrefs.undosBtn = WMCreateCommandButton(WPrefs.win);
	WMResizeWidget(WPrefs.undosBtn, 90, 28);
	WMMoveWidget(WPrefs.undosBtn, 135, 350);
	WMSetButtonText(WPrefs.undosBtn, _("Revert Page"));
	WMSetButtonAction(WPrefs.undosBtn, undo, NULL);

	WPrefs.undoBtn = WMCreateCommandButton(WPrefs.win);
	WMResizeWidget(WPrefs.undoBtn, 90, 28);
	WMMoveWidget(WPrefs.undoBtn, 235, 350);
	WMSetButtonText(WPrefs.undoBtn, _("Revert All"));
	WMSetButtonAction(WPrefs.undoBtn, undoAll, NULL);

	WPrefs.saveBtn = WMCreateCommandButton(WPrefs.win);
	WMResizeWidget(WPrefs.saveBtn, 80, 28);
	WMMoveWidget(WPrefs.saveBtn, 335, 350);
	WMSetButtonText(WPrefs.saveBtn, _("Save"));
	WMSetButtonAction(WPrefs.saveBtn, save, NULL);

	WPrefs.closeBtn = WMCreateCommandButton(WPrefs.win);
	WMResizeWidget(WPrefs.closeBtn, 80, 28);
	WMMoveWidget(WPrefs.closeBtn, 425, 350);
	WMSetButtonText(WPrefs.closeBtn, _("Close"));
	WMSetButtonAction(WPrefs.closeBtn, quit, NULL);

	WPrefs.balloonBtn = WMCreateSwitchButton(WPrefs.win);
	WMResizeWidget(WPrefs.balloonBtn, 200, 28);
	WMMoveWidget(WPrefs.balloonBtn, 15, 350);
	WMSetButtonText(WPrefs.balloonBtn, _("Balloon Help"));
	WMSetButtonAction(WPrefs.balloonBtn, toggleBalloons, NULL);
	{
		WMUserDefaults *udb = WMGetStandardUserDefaults();
		Bool flag = WMGetUDBoolForKey(udb, "BalloonHelp");

		WMSetButtonSelected(WPrefs.balloonBtn, flag);
		WMSetBalloonEnabled(scr, flag);
	}

	/* banner */
	WPrefs.banner = WMCreateFrame(WPrefs.win);
	WMResizeWidget(WPrefs.banner, FRAME_WIDTH, FRAME_HEIGHT);
	WMMoveWidget(WPrefs.banner, FRAME_LEFT, FRAME_TOP);
	WMSetFrameRelief(WPrefs.banner, WRFlat);

	font = WMCreateFont(scr, "Lucida Sans,URW Gothic L,Times New Roman,serif"
			    ":bold:pixelsize=26:antialias=true");
	WPrefs.nameL = WMCreateLabel(WPrefs.banner);
	WMSetLabelTextAlignment(WPrefs.nameL, WACenter);
	WMResizeWidget(WPrefs.nameL, FRAME_WIDTH - 20, 60);
	WMMoveWidget(WPrefs.nameL, 10, 50);
	WMSetLabelFont(WPrefs.nameL, font);
	WMSetLabelText(WPrefs.nameL, _("Window Maker Preferences"));
	WMReleaseFont(font);

	WPrefs.versionL = WMCreateLabel(WPrefs.banner);
	WMResizeWidget(WPrefs.versionL, FRAME_WIDTH - 20, 20);
	WMMoveWidget(WPrefs.versionL, 10, 120);
	WMSetLabelTextAlignment(WPrefs.versionL, WACenter);
	sprintf(buffer, _("Version %s"), VERSION);
	WMSetLabelText(WPrefs.versionL, buffer);

	WPrefs.statusL = WMCreateLabel(WPrefs.banner);
	WMResizeWidget(WPrefs.statusL, FRAME_WIDTH - 20, 60);
	WMMoveWidget(WPrefs.statusL, 10, 150);
	WMSetLabelTextAlignment(WPrefs.statusL, WACenter);
	WMSetLabelText(WPrefs.statusL, _("Starting..."));

	WMMapSubwidgets(WPrefs.win);

	WMUnmapWidget(WPrefs.undosBtn);
	WMUnmapWidget(WPrefs.undoBtn);
	WMUnmapWidget(WPrefs.saveBtn);
}

static void showPanel(Panel * panel)
{
	PanelRec *rec = (PanelRec *) panel;

	if (!(rec->callbacks.flags & INITIALIZED_PANEL)) {
		(*rec->callbacks.createWidgets) (panel);
		rec->callbacks.flags |= INITIALIZED_PANEL;
	}

	WMSetWindowTitle(WPrefs.win, rec->sectionName);

	if (rec->callbacks.showPanel)
		(*rec->callbacks.showPanel) (panel);

	WMMapWidget(rec->box);
}

static void hidePanel(Panel * panel)
{
	PanelRec *rec = (PanelRec *) panel;

	WMUnmapWidget(rec->box);

	if (rec->callbacks.hidePanel)
		(*rec->callbacks.hidePanel) (panel);
}

static void savePanelData(Panel * panel)
{
	PanelRec *rec = (PanelRec *) panel;

	if (rec->callbacks.updateDomain) {
		(*rec->callbacks.updateDomain) (panel);
	}
}

static void changeSection(WMWidget * self, void *data)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	if (WPrefs.currentPanel == data)
		return;

	if (WPrefs.currentPanel == NULL) {
		WMDestroyWidget(WPrefs.nameL);
		WMDestroyWidget(WPrefs.versionL);
		WMDestroyWidget(WPrefs.statusL);

		WMSetFrameRelief(WPrefs.banner, WRGroove);

		/*      WMMapWidget(WPrefs.undosBtn);
		   WMMapWidget(WPrefs.undoBtn);
		 */
		WMMapWidget(WPrefs.saveBtn);
	}

	showPanel(data);

	if (WPrefs.currentPanel)
		hidePanel(WPrefs.currentPanel);
	WPrefs.currentPanel = data;
}

char *LocateImage(const char *name)
{
	char *path;
	char *tmp = wmalloc(strlen(name) + 8);

	if (TIFFOK) {
		sprintf(tmp, "%s.tiff", name);
		path = WMPathForResourceOfType(tmp, "tiff");
	} else {
		sprintf(tmp, "%s.xpm", name);
		path = WMPathForResourceOfType(tmp, "xpm");
	}
	wfree(tmp);
	if (!path) {
		wwarning(_("could not locate image file %s"), name);
	}

	return path;
}

void CreateImages(WMScreen *scr, RContext *rc, RImage *xis, const char *file,
		WMPixmap **icon_normal, WMPixmap **icon_greyed)
{
	RImage *icon;
	char *path;
	RColor gray = { 0xae, 0xaa, 0xae, 0 };

	path = LocateImage(file);
	if (!path)
	{
		*icon_normal = NULL;
		if (icon_greyed)
			*icon_greyed = NULL;
		return;
	}

	*icon_normal = WMCreatePixmapFromFile(scr, path);
	if (!*icon_normal)
	{
		wwarning(_("could not load icon %s"), path);
		if (icon_greyed)
			*icon_greyed = NULL;
		wfree(path);
		return;
	}

	if (!icon_greyed) // Greyed-out version not requested, we are done
	{
		wfree(path);
		return;
	}

	icon = RLoadImage(rc, path, 0);
	if (!icon)
	{
		wwarning(_("could not load icon %s"), path);
		*icon_greyed = NULL;
		wfree(path);
		return;
	}
	RCombineImageWithColor(icon, &gray);
	if (xis)
	{
		RCombineImagesWithOpaqueness(icon, xis, 180);
	}
	*icon_greyed = WMCreatePixmapFromRImage(scr, icon, 127);
	if (!*icon_greyed)
	{
		wwarning(_("could not process icon %s: %s"), path, RMessageForError(RErrorCode));
	}
	RReleaseImage(icon);
	wfree(path);
}


void SetButtonAlphaImage(WMScreen *scr, WMButton *bPtr, const char *file)
{
	WMPixmap *icon;
	RColor color;
	char *iconPath;

	iconPath = LocateImage(file);

	color.red = 0xae;
	color.green = 0xaa;
	color.blue = 0xae;
	color.alpha = 0;
	if (iconPath) {
		icon = WMCreateBlendedPixmapFromFile(scr, iconPath, &color);
		if (!icon)
			wwarning(_("could not load icon file %s"), iconPath);
	} else {
		icon = NULL;
	}

	WMSetButtonImage(bPtr, icon);

	color.red = 0xff;
	color.green = 0xff;
	color.blue = 0xff;
	color.alpha = 0;
	if (iconPath) {
		icon = WMCreateBlendedPixmapFromFile(scr, iconPath, &color);
		if (!icon)
			wwarning(_("could not load icon file %s"), iconPath);
	} else {
		icon = NULL;
	}

	WMSetButtonAltImage(bPtr, icon);

	if (icon)
		WMReleasePixmap(icon);

	if (iconPath)
		wfree(iconPath);
}

void AddSection(Panel * panel, const char *iconFile)
{
	WMButton *bPtr;

	assert(WPrefs.sectionCount < MAX_SECTIONS);

	bPtr = WMCreateCustomButton(WPrefs.buttonF, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(bPtr, 64, 64);
	WMMoveWidget(bPtr, WPrefs.sectionCount * 64, 0);
	WMSetButtonImagePosition(bPtr, WIPImageOnly);
	WMSetButtonAction(bPtr, changeSection, panel);
	WMHangData(bPtr, panel);

	WMSetBalloonTextForView(((PanelRec *) panel)->description, WMWidgetView(bPtr));
	SetButtonAlphaImage(WMWidgetScreen(bPtr), bPtr, iconFile);
	WMMapWidget(bPtr);

	WPrefs.sectionB[WPrefs.sectionCount] = bPtr;

	if (WPrefs.sectionCount > 0)
		WMGroupButtons(WPrefs.sectionB[0], bPtr);

	WPrefs.sectionCount++;

	WMResizeWidget(WPrefs.buttonF, WPrefs.sectionCount * 64, 64);
}

void Initialize(WMScreen * scr)
{
	char **list;
	int i;
	char *path;

	list = RSupportedFileFormats();
	for (i = 0; list[i] != NULL; i++) {
		if (strcmp(list[i], "TIFF") == 0) {
			TIFFOK = True;
			break;
		}
	}

	if (TIFFOK)
		path = WMPathForResourceOfType("WPrefs.tiff", NULL);
	else
		path = WMPathForResourceOfType("WPrefs.xpm", NULL);
	if (path) {
		RImage *tmp;

		tmp = RLoadImage(WMScreenRContext(scr), path, 0);
		if (!tmp) {
			wwarning(_("could not load image file %s:%s"), path, RMessageForError(RErrorCode));
		} else {
			WMSetApplicationIconImage(scr, tmp);
			RReleaseImage(tmp);
		}
		wfree(path);
	}

	memset(&WPrefs, 0, sizeof(_WPrefs));
	createMainWindow(scr);

	WMRealizeWidget(WPrefs.win);

	WMSetWindowMiniwindowImage(WPrefs.win, WMGetApplicationIconImage(scr));

	WMMapWidget(WPrefs.win);
	XFlush(WMScreenDisplay(scr));
	WMSetLabelText(WPrefs.statusL, _("Loading Window Maker configuration files..."));
	XFlush(WMScreenDisplay(scr));
	loadConfigurations(scr, WPrefs.win);

	WMSetLabelText(WPrefs.statusL, _("Initializing configuration panels..."));

	InitFocus(WPrefs.banner);
	InitWindowHandling(WPrefs.banner);

	InitMenuPreferences(WPrefs.banner);
	InitIcons(WPrefs.banner);
	InitPreferences(WPrefs.banner);

	InitPaths(WPrefs.banner);
	InitDocks(WPrefs.banner);
	InitWorkspace(WPrefs.banner);
	InitConfigurations(WPrefs.banner);

	InitMenu(WPrefs.banner);

#ifdef not_yet_fully_implemented
	InitKeyboardSettings(WPrefs.banner);
#endif
	InitKeyboardShortcuts(WPrefs.banner);
	InitMouseSettings(WPrefs.banner);

	InitAppearance(WPrefs.banner);

	InitFontSimple(WPrefs.banner);

#ifdef not_yet_fully_implemented
	InitThemes(WPrefs.banner);
#endif
	InitExpert(WPrefs.banner);

	WMRealizeWidget(WPrefs.scrollV);

	WMSetLabelText(WPrefs.statusL, "");
}

WMWindow *GetWindow(void)
{
	return WPrefs.win;
}

static void loadConfigurations(WMScreen * scr, WMWindow * mainw)
{
	WMPropList *db, *gdb;
	char *path;
	FILE *file;
	char buffer[1024];
	char mbuf[1024];
	int v1, v2, v3;

	path = wdefaultspathfordomain("WindowMaker");
	WindowMakerDBPath = path;

	db = WMReadPropListFromFile(path);
	if (db) {
		if (!WMIsPLDictionary(db)) {
			WMReleasePropList(db);
			db = NULL;
			sprintf(mbuf, _("Window Maker domain (%s) is corrupted!"), path);
			WMRunAlertPanel(scr, mainw, _("Error"), mbuf, _("OK"), NULL, NULL);
		}
	} else {
		sprintf(mbuf, _("Could not load Window Maker domain (%s) from defaults database."), path);
		WMRunAlertPanel(scr, mainw, _("Error"), mbuf, _("OK"), NULL, NULL);
	}

	path = getenv("WMAKER_BIN_NAME");
	if (!path)
		path = "wmaker";
	{
		char *command;

		command = wstrconcat(path, " --version");
		file = popen(command, "r");
		wfree(command);
	}
	if (!file || !fgets(buffer, 1023, file)) {
		werror(_("could not extract version information from Window Maker"));
		wfatal(_("Make sure wmaker is in your search path."));

		WMRunAlertPanel(scr, mainw, _("Error"),
				_
				("Could not extract version from Window Maker. Make sure it is correctly installed and is in your PATH environment variable."),
				_("OK"), NULL, NULL);
		exit(1);
	}
	if (file)
		pclose(file);

	if (sscanf(buffer, "Window Maker %i.%i.%i", &v1, &v2, &v3) != 3
	    && sscanf(buffer, "WindowMaker %i.%i.%i", &v1, &v2, &v3) != 3) {
		WMRunAlertPanel(scr, mainw, _("Error"),
				_("Could not extract version from Window Maker. "
				  "Make sure it is correctly installed and the path "
				  "where it installed is in the PATH environment "
				  "variable."), _("OK"), NULL, NULL);
		exit(1);
	}
	if (v1 == 0 && (v2 < 18 || v3 < 0)) {
		sprintf(mbuf, _("WPrefs only supports Window Maker 0.18.0 or newer.\n"
				"The version installed is %i.%i.%i\n"), v1, v2, v3);
		WMRunAlertPanel(scr, mainw, _("Error"), mbuf, _("OK"), NULL, NULL);
		exit(1);

	}
	if (v1 > 1 || (v1 == 1 && (v2 > 0))) {
		sprintf(mbuf,
			_
			("Window Maker %i.%i.%i, which is installed in your system, is not fully supported by this version of WPrefs."),
			v1, v2, v3);
		WMRunAlertPanel(scr, mainw, _("Warning"), mbuf, _("OK"), NULL, NULL);
	}

	{
		char *command;

		command = wstrconcat(path, " --global_defaults_path");
		file = popen(command, "r");
		wfree(command);
	}
	if (!file || !fgets(buffer, 1023, file)) {
		werror(_("could not run \"%s --global_defaults_path\"."), path);
		exit(1);
	} else {
		char *ptr;
		ptr = strchr(buffer, '\n');
		if (ptr)
			*ptr = 0;
		strcat(buffer, "/WindowMaker");
	}

	if (file)
		pclose(file);

	gdb = WMReadPropListFromFile(buffer);

	if (gdb) {
		if (!WMIsPLDictionary(gdb)) {
			WMReleasePropList(gdb);
			gdb = NULL;
			sprintf(mbuf, _("Window Maker domain (%s) is corrupted!"), buffer);
			WMRunAlertPanel(scr, mainw, _("Error"), mbuf, _("OK"), NULL, NULL);
		}
	} else {
		sprintf(mbuf, _("Could not load global Window Maker domain (%s)."), buffer);
		WMRunAlertPanel(scr, mainw, _("Error"), mbuf, _("OK"), NULL, NULL);
	}

	if (!db) {
		db = WMCreatePLDictionary(NULL, NULL);
	}
	if (!gdb) {
		gdb = WMCreatePLDictionary(NULL, NULL);
	}

	GlobalDB = gdb;

	WindowMakerDB = db;
}

WMPropList *GetObjectForKey(const char *defaultName)
{
	WMPropList *object = NULL;
	WMPropList *key = WMCreatePLString(defaultName);

	object = WMGetFromPLDictionary(WindowMakerDB, key);
	if (!object)
		object = WMGetFromPLDictionary(GlobalDB, key);

	WMReleasePropList(key);

	return object;
}

void SetObjectForKey(WMPropList * object, const char *defaultName)
{
	WMPropList *key = WMCreatePLString(defaultName);

	WMPutInPLDictionary(WindowMakerDB, key, object);
	WMReleasePropList(key);
}

void RemoveObjectForKey(const char *defaultName)
{
	WMPropList *key = WMCreatePLString(defaultName);

	WMRemoveFromPLDictionary(WindowMakerDB, key);

	WMReleasePropList(key);
}

char *GetStringForKey(const char *defaultName)
{
	WMPropList *val;

	val = GetObjectForKey(defaultName);

	if (!val)
		return NULL;

	if (!WMIsPLString(val))
		return NULL;

	return WMGetFromPLString(val);
}

WMPropList *GetArrayForKey(const char *defaultName)
{
	WMPropList *val;

	val = GetObjectForKey(defaultName);

	if (!val)
		return NULL;

	if (!WMIsPLArray(val))
		return NULL;

	return val;
}

WMPropList *GetDictionaryForKey(const char *defaultName)
{
	WMPropList *val;

	val = GetObjectForKey(defaultName);

	if (!val)
		return NULL;

	if (!WMIsPLDictionary(val))
		return NULL;

	return val;
}

int GetIntegerForKey(const char *defaultName)
{
	WMPropList *val;
	char *str;
	int value;

	val = GetObjectForKey(defaultName);

	if (!val)
		return 0;

	if (!WMIsPLString(val))
		return 0;

	str = WMGetFromPLString(val);
	if (!str)
		return 0;

	if (sscanf(str, "%i", &value) != 1)
		return 0;

	return value;
}

Bool GetBoolForKey(const char *defaultName)
{
	int value;
	char *str;

	str = GetStringForKey(defaultName);

	if (!str)
		return False;

	if (sscanf(str, "%i", &value) == 1 && value != 0)
		return True;

	if (strcasecmp(str, "YES") == 0)
		return True;

	if (strcasecmp(str, "Y") == 0)
		return True;

	return False;
}

void SetIntegerForKey(int value, const char *defaultName)
{
	WMPropList *object;
	char buffer[128];

	sprintf(buffer, "%i", value);
	object = WMCreatePLString(buffer);

	SetObjectForKey(object, defaultName);
	WMReleasePropList(object);
}

void SetStringForKey(const char *value, const char *defaultName)
{
	WMPropList *object;

	object = WMCreatePLString(value);

	SetObjectForKey(object, defaultName);
	WMReleasePropList(object);
}

void SetBoolForKey(Bool value, const char *defaultName)
{
	static WMPropList *yes = NULL, *no = NULL;

	if (!yes) {
		yes = WMCreatePLString("YES");
		no = WMCreatePLString("NO");
	}

	SetObjectForKey(value ? yes : no, defaultName);
}

void SetSpeedForKey(int speed, const char *defaultName)
{
	char *str;

	switch (speed) {
	case 0:
		str = "ultraslow";
		break;
	case 1:
		str = "slow";
		break;
	case 2:
		str = "medium";
		break;
	case 3:
		str = "fast";
		break;
	case 4:
		str = "ultrafast";
		break;
	default:
		str = NULL;
	}

	if (str)
		SetStringForKey(str, defaultName);
}

int GetSpeedForKey(const char *defaultName)
{
	char *str;
	int i;

	str = GetStringForKey(defaultName);
	if (!str)
		return 2;

	if (strcasecmp(str, "ultraslow") == 0)
		i = 0;
	else if (strcasecmp(str, "slow") == 0)
		i = 1;
	else if (strcasecmp(str, "medium") == 0)
		i = 2;
	else if (strcasecmp(str, "fast") == 0)
		i = 3;
	else if (strcasecmp(str, "ultrafast") == 0)
		i = 4;
	else {
		wwarning(_("bad speed value for option %s; using default Medium"), defaultName);
		i = 2;
	}
	return i;
}
