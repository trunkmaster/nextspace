/* Menu.c- menu definition
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

#include "WPrefs.h"
#include <assert.h>
#include <ctype.h>

#include <X11/keysym.h>
#include <X11/cursorfont.h>

#include "editmenu.h"

typedef enum {
	NoInfo,
	ExecInfo,
	CommandInfo,
	ExternalInfo,
	PipeInfo,
	PLPipeInfo,
	DirectoryInfo,
	WSMenuInfo,
	WWindowListInfo,
	LastInfo
} InfoType;

#define MAX_SECTION_SIZE 4

typedef struct _Panel {
	WMBox *box;
	char *sectionName;

	char *description;

	CallbackRec callbacks;
	WMWidget *parent;

	WMFont *boldFont;
	WMFont *normalFont;
	WMColor *white;
	WMColor *gray;
	WMColor *black;

	WMPixmap *markerPix[LastInfo];

	WMPopUpButton *typeP;

	WMWidget *itemPad[3];
	int currentPad;

	WEditMenu *menu;
	char *menuPath;

	WMFrame *optionsF;

	WMFrame *commandF;
	WMTextField *commandT;	/* command to run */
	WMButton *browseB;
	WMButton *xtermC;	/* inside xterm? */

	WMFrame *pathF;
	WMTextField *pathT;

	WMFrame *pipeF;
	WMTextField *pipeT;
	WMButton *pipeCacheB;

	WMFrame *plpipeF;
	WMTextField *plpipeT;
	WMButton *plpipeCacheB;

	WMFrame *dpathF;
	WMTextField *dpathT;

	WMFrame *dcommandF;
	WMTextField *dcommandT;

	WMButton *dstripB;

	WMFrame *shortF;
	WMTextField *shortT;
	WMButton *sgrabB;
	WMButton *sclearB;

	WMList *icommandL;

	WMFrame *paramF;
	WMTextField *paramT;

	WMButton *quickB;

	Bool dontAsk;		/* whether to comfirm submenu remove */
	Bool dontSave;

	Bool capturing;

	/* about the currently selected item */
	WEditMenuItem *currentItem;
	InfoType currentType;
	WMWidget *sections[LastInfo][MAX_SECTION_SIZE];
} _Panel;

typedef struct {
	InfoType type;
	union {
		struct {
			int command;
			char *parameter;
			char *shortcut;
		} command;
		struct {
			char *command;
			char *shortcut;
		} exec;
		struct {
			char *path;
		} external;
		struct {
			char *command;
			unsigned cached:1;
		} pipe;
		struct {
			char *directory;
			char *command;
			unsigned stripExt:1;
		} directory;
	} param;
} ItemData;

static char *commandNames[] = {
	"ARRANGE_ICONS",
	"HIDE_OTHERS",
	"SHOW_ALL",
	"EXIT",
	"SHUTDOWN",
	"RESTART",
	"RESTART",
	"SAVE_SESSION",
	"CLEAR_SESSION",
	"REFRESH",
	"INFO_PANEL",
	"LEGAL_PANEL"
};

#define ICON_FILE	"menus"

static void showData(_Panel * panel);

static void updateMenuItem(_Panel * panel, WEditMenuItem * item, WMWidget * changedWidget);

static void menuItemSelected(struct WEditMenuDelegate *delegate, WEditMenu * menu, WEditMenuItem * item);

static void menuItemDeselected(struct WEditMenuDelegate *delegate, WEditMenu * menu, WEditMenuItem * item);

static void menuItemCloned(struct WEditMenuDelegate *delegate, WEditMenu * menu,
			   WEditMenuItem * origItem, WEditMenuItem * newItem);

static void menuItemEdited(struct WEditMenuDelegate *delegate, WEditMenu * menu, WEditMenuItem * item);

static Bool shouldRemoveItem(struct WEditMenuDelegate *delegate, WEditMenu * menu, WEditMenuItem * item);

static void freeItemData(ItemData * data);


static WEditMenuDelegate menuDelegate = {
	NULL,
	menuItemCloned,
	menuItemEdited,
	menuItemSelected,
	menuItemDeselected,
	shouldRemoveItem
};

static void dataChanged(void *self, WMNotification * notif)
{
	_Panel *panel = (_Panel *) self;
	WEditMenuItem *item = panel->currentItem;
	WMWidget *w = (WMWidget *) WMGetNotificationObject(notif);

	updateMenuItem(panel, item, w);
}

static void buttonClicked(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	WEditMenuItem *item = panel->currentItem;

	updateMenuItem(panel, item, w);
}

static void icommandLClicked(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int cmd;

	cmd = WMGetListSelectedItemRow(w);
	if (cmd == 3 || cmd == 4) {
		WMMapWidget(panel->quickB);
	} else {
		WMUnmapWidget(panel->quickB);
	}
	if (cmd == 6) {
		WMMapWidget(panel->paramF);
	} else {
		WMUnmapWidget(panel->paramF);
	}
}

static void browseForFile(WMWidget * self, void *clientData)
{
	_Panel *panel = (_Panel *) clientData;
	WMFilePanel *filePanel;
	char *text, *oldprog, *newprog;

	filePanel = WMGetOpenPanel(WMWidgetScreen(self));
	text = WMGetTextFieldText(panel->commandT);

	oldprog = wtrimspace(text);
	wfree(text);

	if (oldprog[0] == 0 || oldprog[0] != '/') {
		wfree(oldprog);
		oldprog = wstrdup("/");
	} else {
		char *ptr = oldprog;
		while (*ptr && !isspace(*ptr))
			ptr++;
		*ptr = 0;
	}

	WMSetFilePanelCanChooseDirectories(filePanel, False);

	if (WMRunModalFilePanelForDirectory(filePanel, panel->parent, oldprog, _("Select Program"), NULL) == True) {
		newprog = WMGetFilePanelFileName(filePanel);
		WMSetTextFieldText(panel->commandT, newprog);
		updateMenuItem(panel, panel->currentItem, panel->commandT);
		wfree(newprog);
	}

	wfree(oldprog);
}

static void sgrabClicked(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	Display *dpy = WMScreenDisplay(WMWidgetScreen(panel->parent));
	char *shortcut;

	if (w == panel->sclearB) {
		WMSetTextFieldText(panel->shortT, "");
		updateMenuItem(panel, panel->currentItem, panel->shortT);
		return;
	}

	if (!panel->capturing) {
		panel->capturing = 1;
		WMSetButtonText(w, _("Cancel"));
		XGrabKeyboard(dpy, WMWidgetXID(panel->parent), True, GrabModeAsync, GrabModeAsync, CurrentTime);
		shortcut = capture_shortcut(dpy, &panel->capturing, 0);
		if (shortcut) {
			WMSetTextFieldText(panel->shortT, shortcut);
			updateMenuItem(panel, panel->currentItem, panel->shortT);
			wfree(shortcut);
		}
	}
	panel->capturing = 0;
	WMSetButtonText(w, _("Capture"));
	XUngrabKeyboard(dpy, CurrentTime);
}

static void changedItemPad(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int padn = WMGetPopUpButtonSelectedItem(w);

	WMUnmapWidget(panel->itemPad[panel->currentPad]);
	WMMapWidget(panel->itemPad[padn]);

	panel->currentPad = padn;
}

static WEditMenu *putNewSubmenu(WEditMenu * menu, const char *title)
{
	WEditMenu *tmp;
	WEditMenuItem *item;

	item = WAddMenuItemWithTitle(menu, title);

	tmp = WCreateEditMenu(WMWidgetScreen(menu), title);
	WSetEditMenuAcceptsDrop(tmp, True);
	WSetEditMenuDelegate(tmp, &menuDelegate);
	WSetEditMenuSubmenu(menu, item, tmp);

	return tmp;
}

static ItemData *putNewItem(_Panel * panel, WEditMenu * menu, int type, const char *title)
{
	WEditMenuItem *item;
	ItemData *data;

	item = WAddMenuItemWithTitle(menu, title);

	data = wmalloc(sizeof(ItemData));
	data->type = type;
	WSetEditMenuItemData(item, data, (WMCallback *) freeItemData);
	WSetEditMenuItemImage(item, panel->markerPix[type]);

	return data;
}

static WEditMenu *makeFactoryMenu(WMWidget * parent, int width)
{
	WEditMenu *pad;

	pad = WCreateEditMenuPad(parent);
	WMResizeWidget(pad, width, 10);
	WSetEditMenuMinSize(pad, wmksize(width, 0));
	WSetEditMenuMaxSize(pad, wmksize(width, 0));
	WSetEditMenuSelectable(pad, False);
	WSetEditMenuEditable(pad, False);
	WSetEditMenuIsFactory(pad, True);
	WSetEditMenuDelegate(pad, &menuDelegate);

	return pad;
}

static void createPanel(_Panel * p)
{
	_Panel *panel = (_Panel *) p;
	WMScreen *scr = WMWidgetScreen(panel->parent);
	WMColor *black = WMBlackColor(scr);
	WMColor *white = WMWhiteColor(scr);
	WMColor *gray = WMGrayColor(scr);
	WMFont *bold = WMBoldSystemFontOfSize(scr, 12);
	WMFont *font = WMSystemFontOfSize(scr, 12);
	WMLabel *label;
	int width;

	menuDelegate.data = panel;

	panel->boldFont = bold;
	panel->normalFont = font;

	panel->black = black;
	panel->white = white;
	panel->gray = gray;

	{
		Pixmap pix;
		Display *dpy = WMScreenDisplay(scr);
		GC gc;
		WMPixmap *pixm;

		pixm = WMCreatePixmap(scr, 7, 7, WMScreenDepth(scr), True);

		pix = WMGetPixmapXID(pixm);

		XDrawLine(dpy, pix, WMColorGC(black), 0, 3, 6, 3);
		XDrawLine(dpy, pix, WMColorGC(black), 3, 0, 3, 6);
		/*
		   XDrawLine(dpy, pix, WMColorGC(black), 1, 0, 3, 3);
		   XDrawLine(dpy, pix, WMColorGC(black), 1, 6, 3, 3);
		   XDrawLine(dpy, pix, WMColorGC(black), 0, 0, 0, 6);
		 */

		pix = WMGetPixmapMaskXID(pixm);

		gc = XCreateGC(dpy, pix, 0, NULL);

		XSetForeground(dpy, gc, 0);
		XFillRectangle(dpy, pix, gc, 0, 0, 7, 7);

		XSetForeground(dpy, gc, 1);
		XDrawLine(dpy, pix, gc, 0, 3, 6, 3);
		XDrawLine(dpy, pix, gc, 3, 0, 3, 6);

		panel->markerPix[ExternalInfo] = pixm;
		panel->markerPix[PipeInfo] = pixm;
		panel->markerPix[PLPipeInfo] = pixm;
		panel->markerPix[DirectoryInfo] = pixm;
		panel->markerPix[WSMenuInfo] = pixm;
		panel->markerPix[WWindowListInfo] = pixm;

		XFreeGC(dpy, gc);
	}

	panel->box = WMCreateBox(panel->parent);
	WMSetViewExpandsToParent(WMWidgetView(panel->box), 2, 2, 2, 2);

	panel->typeP = WMCreatePopUpButton(panel->box);
	WMResizeWidget(panel->typeP, 150, 20);
	WMMoveWidget(panel->typeP, 10, 10);

	WMAddPopUpButtonItem(panel->typeP, _("New Items"));
	WMAddPopUpButtonItem(panel->typeP, _("Sample Commands"));
	WMAddPopUpButtonItem(panel->typeP, _("Sample Submenus"));

	WMSetPopUpButtonAction(panel->typeP, changedItemPad, panel);

	WMSetPopUpButtonSelectedItem(panel->typeP, 0);

	{
		WEditMenu *pad;

		pad = makeFactoryMenu(panel->box, 150);
		WMMoveWidget(pad, 10, 40);

		putNewItem(panel, pad, ExecInfo, _("Run Program"));
		putNewItem(panel, pad, CommandInfo, _("Internal Command"));
		putNewSubmenu(pad, _("Submenu"));
		putNewItem(panel, pad, ExternalInfo, _("External Submenu"));
		putNewItem(panel, pad, PipeInfo, _("Generated Submenu"));
		putNewItem(panel, pad, PLPipeInfo, _("Generated PL Menu"));
		putNewItem(panel, pad, DirectoryInfo, _("Directory Contents"));
		putNewItem(panel, pad, WSMenuInfo, _("Workspace Menu"));
		putNewItem(panel, pad, WWindowListInfo, _("Window List Menu"));

		panel->itemPad[0] = pad;
	}

	{
		WEditMenu *pad;
		ItemData *data;
		WMScrollView *sview;

		sview = WMCreateScrollView(panel->box);
		WMResizeWidget(sview, 150, 180);
		WMMoveWidget(sview, 10, 40);
		WMSetScrollViewHasVerticalScroller(sview, True);

		pad = makeFactoryMenu(panel->box, 130);

		WMSetScrollViewContentView(sview, WMWidgetView(pad));

		data = putNewItem(panel, pad, ExecInfo, _("XTerm"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg black -fg white";

		data = putNewItem(panel, pad, ExecInfo, _("rxvt"));
		data->param.exec.command = "rxvt";

		data = putNewItem(panel, pad, ExecInfo, _("ETerm"));
		data->param.exec.command = "eterm";

		data = putNewItem(panel, pad, ExecInfo, _("Run..."));
		data->param.exec.command = _("%A(Run,Type command to run)");

		data = putNewItem(panel, pad, ExecInfo, _("Firefox"));
		data->param.exec.command = "firefox";

		data = putNewItem(panel, pad, ExecInfo, _("gimp"));
		data->param.exec.command = "gimp";

		data = putNewItem(panel, pad, ExecInfo, _("epic"));
		data->param.exec.command = "xterm -e epic";

		data = putNewItem(panel, pad, ExecInfo, _("ee"));
		data->param.exec.command = "ee";

		data = putNewItem(panel, pad, ExecInfo, _("xv"));
		data->param.exec.command = "xv";

		data = putNewItem(panel, pad, ExecInfo, _("Evince"));
		data->param.exec.command = "evince";

		data = putNewItem(panel, pad, ExecInfo, _("ghostview"));
		data->param.exec.command = "gv";

		data = putNewItem(panel, pad, CommandInfo, _("Exit Window Maker"));
		data->param.command.command = 3;

		WMMapWidget(pad);

		panel->itemPad[1] = sview;
	}

	{
		WEditMenu *pad, *smenu;
		ItemData *data;
		WMScrollView *sview;

		sview = WMCreateScrollView(panel->box);
		WMResizeWidget(sview, 150, 180);
		WMMoveWidget(sview, 10, 40);
		WMSetScrollViewHasVerticalScroller(sview, True);

		pad = makeFactoryMenu(panel->box, 130);

		WMSetScrollViewContentView(sview, WMWidgetView(pad));

		data = putNewItem(panel, pad, ExternalInfo, _("Debian Menu"));
		data->param.pipe.command = "/etc/X11/WindowMaker/menu.hook";

		data = putNewItem(panel, pad, PipeInfo, _("RedHat Menu"));
		data->param.pipe.command = "wmconfig --output wmaker";

		data = putNewItem(panel, pad, PipeInfo, _("Menu Conectiva"));
		data->param.pipe.command = "wmconfig --output wmaker";

		data = putNewItem(panel, pad, DirectoryInfo, _("Themes"));
		data->param.directory.command = "setstyle";
		data->param.directory.directory =
		    "/usr/share/WindowMaker/Themes /usr/local/share/WindowMaker/Themes $HOME/GNUstep/Library/WindowMaker/Themes";
		data->param.directory.stripExt = 1;

		data = putNewItem(panel, pad, DirectoryInfo, _("Bg Images (scale)"));
		data->param.directory.command = "wmsetbg -u -s";
		data->param.directory.directory =
		    "/opt/kde2/share/wallpapers /usr/share/WindowMaker/Backgrounds $HOME/GNUstep/Library/WindowMaker/Backgrounds";
		data->param.directory.stripExt = 1;

		data = putNewItem(panel, pad, DirectoryInfo, _("Bg Images (tile)"));
		data->param.directory.command = "wmsetbg -u -t";
		data->param.directory.directory =
		    "/opt/kde2/share/wallpapers /usr/share/WindowMaker/Backgrounds $HOME/GNUstep/Library/WindowMaker/Backgrounds";
		data->param.directory.stripExt = 1;

		smenu = putNewSubmenu(pad, _("Assorted XTerms"));

		data = putNewItem(panel, smenu, ExecInfo, _("XTerm Yellow on Blue"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg midnightblue -fg yellow";

		data = putNewItem(panel, smenu, ExecInfo, _("XTerm White on Black"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg black -fg white";

		data = putNewItem(panel, smenu, ExecInfo, _("XTerm Black on White"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg white -fg black";

		data = putNewItem(panel, smenu, ExecInfo, _("XTerm Black on Beige"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg '#bbbb99' -fg black";

		data = putNewItem(panel, smenu, ExecInfo, _("XTerm White on Green"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg '#228822' -fg white";

		data = putNewItem(panel, smenu, ExecInfo, _("XTerm White on Olive"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg '#335533' -fg white";

		data = putNewItem(panel, smenu, ExecInfo, _("XTerm Blue on Blue"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg '#112244' -fg '#88aabb'";

		data = putNewItem(panel, smenu, ExecInfo, _("XTerm BIG FONTS"));
		data->param.exec.command = "xterm -sb -sl 2000 -bg black -fg white -fn 10x20";

		WMMapWidget(pad);

		panel->itemPad[2] = sview;
	}

	width = FRAME_WIDTH - 20 - 150 - 10 - 2;

	panel->optionsF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->optionsF, width, FRAME_HEIGHT - 15);
	WMMoveWidget(panel->optionsF, 10 + 150 + 10, 5);

	width -= 20;

	/* command */

	panel->commandF = WMCreateFrame(panel->optionsF);
	WMResizeWidget(panel->commandF, width, 50);
	WMMoveWidget(panel->commandF, 10, 20);
	WMSetFrameTitle(panel->commandF, _("Program to Run"));
	WMSetFrameTitlePosition(panel->commandF, WTPAtTop);

	panel->commandT = WMCreateTextField(panel->commandF);
	WMResizeWidget(panel->commandT, width - 95, 20);
	WMMoveWidget(panel->commandT, 10, 20);

	panel->browseB = WMCreateCommandButton(panel->commandF);
	WMResizeWidget(panel->browseB, 70, 24);
	WMMoveWidget(panel->browseB, width - 80, 18);
	WMSetButtonText(panel->browseB, _("Browse"));
	WMSetButtonAction(panel->browseB, browseForFile, panel);

	WMAddNotificationObserver(dataChanged, panel, WMTextDidChangeNotification, panel->commandT);

#if 0
	panel->xtermC = WMCreateSwitchButton(panel->commandF);
	WMResizeWidget(panel->xtermC, width - 20, 20);
	WMMoveWidget(panel->xtermC, 10, 50);
	WMSetButtonText(panel->xtermC, _("Run the program inside a Xterm"));
#endif
	WMMapSubwidgets(panel->commandF);

	/* path */

	panel->pathF = WMCreateFrame(panel->optionsF);
	WMResizeWidget(panel->pathF, width, 150);
	WMMoveWidget(panel->pathF, 10, 40);
	WMSetFrameTitle(panel->pathF, _("Path for Menu"));

	panel->pathT = WMCreateTextField(panel->pathF);
	WMResizeWidget(panel->pathT, width - 20, 20);
	WMMoveWidget(panel->pathT, 10, 20);

	WMAddNotificationObserver(dataChanged, panel, WMTextDidChangeNotification, panel->pathT);

	label = WMCreateLabel(panel->pathF);
	WMResizeWidget(label, width - 20, 80);
	WMMoveWidget(label, 10, 50);
	WMSetLabelText(label, _("Enter the path for a file containing a menu\n"
				"or a list of directories with the programs you\n"
				"want to have listed in the menu. Ex:\n"
				"~/GNUstep/Library/WindowMaker/menu\n" "or\n" "/usr/bin ~/xbin"));

	WMMapSubwidgets(panel->pathF);

	/* pipe */

	panel->pipeF = WMCreateFrame(panel->optionsF);
	WMResizeWidget(panel->pipeF, width, 155);
	WMMoveWidget(panel->pipeF, 10, 30);
	WMSetFrameTitle(panel->pipeF, _("Command"));

	panel->pipeT = WMCreateTextField(panel->pipeF);
	WMResizeWidget(panel->pipeT, width - 20, 20);
	WMMoveWidget(panel->pipeT, 10, 20);

	WMAddNotificationObserver(dataChanged, panel, WMTextDidChangeNotification, panel->pipeT);

	label = WMCreateLabel(panel->pipeF);
	WMResizeWidget(label, width - 20, 40);
	WMMoveWidget(label, 10, 50);
	WMSetLabelText(label, _("Enter a command that outputs a menu\n" "definition to stdout when invoked."));

	panel->pipeCacheB = WMCreateSwitchButton(panel->pipeF);
	WMResizeWidget(panel->pipeCacheB, width - 20, 40);
	WMMoveWidget(panel->pipeCacheB, 10, 110);
	WMSetButtonText(panel->pipeCacheB, _("Cache menu contents after opening for\n" "the first time"));

	WMMapSubwidgets(panel->pipeF);

	/* proplist pipe */

	panel->plpipeF = WMCreateFrame(panel->optionsF);
	WMResizeWidget(panel->plpipeF, width, 155);
	WMMoveWidget(panel->plpipeF, 10, 30);
	WMSetFrameTitle(panel->plpipeF, _("Command"));

	panel->plpipeT = WMCreateTextField(panel->plpipeF);
	WMResizeWidget(panel->plpipeT, width - 20, 20);
	WMMoveWidget(panel->plpipeT, 10, 20);

	WMAddNotificationObserver(dataChanged, panel, WMTextDidChangeNotification, panel->plpipeT);

	label = WMCreateLabel(panel->plpipeF);
	WMResizeWidget(label, width - 20, 40);
	WMMoveWidget(label, 10, 50);
	WMSetLabelText(label, _("Enter a command that outputs a proplist menu\n" "definition to stdout when invoked."));

	panel->plpipeCacheB = WMCreateSwitchButton(panel->plpipeF);
	WMResizeWidget(panel->plpipeCacheB, width - 20, 40);
	WMMoveWidget(panel->plpipeCacheB, 10, 110);
	WMSetButtonText(panel->plpipeCacheB, _("Cache menu contents after opening for\n" "the first time"));

	WMMapSubwidgets(panel->plpipeF);

	/* directory menu */

	panel->dcommandF = WMCreateFrame(panel->optionsF);
	WMResizeWidget(panel->dcommandF, width, 90);
	WMMoveWidget(panel->dcommandF, 10, 25);
	WMSetFrameTitle(panel->dcommandF, _("Command to Open Files"));

	panel->dcommandT = WMCreateTextField(panel->dcommandF);
	WMResizeWidget(panel->dcommandT, width - 20, 20);
	WMMoveWidget(panel->dcommandT, 10, 20);

	WMAddNotificationObserver(dataChanged, panel, WMTextDidChangeNotification, panel->dcommandT);

	label = WMCreateLabel(panel->dcommandF);
	WMResizeWidget(label, width - 20, 45);
	WMMoveWidget(label, 10, 40);
	WMSetLabelText(label, _("Enter the command you want to use to open the\n"
				"files in the directories listed below."));

	WMMapSubwidgets(panel->dcommandF);

	panel->dpathF = WMCreateFrame(panel->optionsF);
	WMResizeWidget(panel->dpathF, width, 80);
	WMMoveWidget(panel->dpathF, 10, 125);
	WMSetFrameTitle(panel->dpathF, _("Directories with Files"));

	panel->dpathT = WMCreateTextField(panel->dpathF);
	WMResizeWidget(panel->dpathT, width - 20, 20);
	WMMoveWidget(panel->dpathT, 10, 20);

	WMAddNotificationObserver(dataChanged, panel, WMTextDidChangeNotification, panel->dpathT);

	panel->dstripB = WMCreateSwitchButton(panel->dpathF);
	WMResizeWidget(panel->dstripB, width - 20, 20);
	WMMoveWidget(panel->dstripB, 10, 50);
	WMSetButtonText(panel->dstripB, _("Strip extensions from file names"));

	WMSetButtonAction(panel->dstripB, buttonClicked, panel);

	WMMapSubwidgets(panel->dpathF);

	/* shortcut */

	panel->shortF = WMCreateFrame(panel->optionsF);
	WMResizeWidget(panel->shortF, width, 50);
	WMMoveWidget(panel->shortF, 10, 160);
	WMSetFrameTitle(panel->shortF, _("Keyboard Shortcut"));

	panel->shortT = WMCreateTextField(panel->shortF);
	WMResizeWidget(panel->shortT, width - 20 - 150, 20);
	WMMoveWidget(panel->shortT, 10, 20);

	WMAddNotificationObserver(dataChanged, panel, WMTextDidChangeNotification, panel->shortT);

	panel->sgrabB = WMCreateCommandButton(panel->shortF);
	WMResizeWidget(panel->sgrabB, 70, 24);
	WMMoveWidget(panel->sgrabB, width - 80, 18);
	WMSetButtonText(panel->sgrabB, _("Capture"));
	WMSetButtonAction(panel->sgrabB, sgrabClicked, panel);

	panel->sclearB = WMCreateCommandButton(panel->shortF);
	WMResizeWidget(panel->sclearB, 70, 24);
	WMMoveWidget(panel->sclearB, width - 155, 18);
	WMSetButtonText(panel->sclearB, _("Clear"));
	WMSetButtonAction(panel->sclearB, sgrabClicked, panel);

	WMMapSubwidgets(panel->shortF);

	/* internal command */

	panel->icommandL = WMCreateList(panel->optionsF);
	WMResizeWidget(panel->icommandL, width, 80);
	WMMoveWidget(panel->icommandL, 10, 20);

	WMSetListAction(panel->icommandL, icommandLClicked, panel);

	WMAddNotificationObserver(dataChanged, panel, WMListSelectionDidChangeNotification, panel->icommandL);

	WMInsertListItem(panel->icommandL, 0, _("Arrange Icons"));
	WMInsertListItem(panel->icommandL, 1, _("Hide All Windows Except For The Focused One"));
	WMInsertListItem(panel->icommandL, 2, _("Show All Windows"));

	WMInsertListItem(panel->icommandL, 3, _("Exit Window Maker"));
	WMInsertListItem(panel->icommandL, 4, _("Exit X Session"));
	WMInsertListItem(panel->icommandL, 5, _("Restart Window Maker"));
	WMInsertListItem(panel->icommandL, 6, _("Start Another Window Manager   : ("));

	WMInsertListItem(panel->icommandL, 7, _("Save Current Session"));
	WMInsertListItem(panel->icommandL, 8, _("Clear Saved Session"));
	WMInsertListItem(panel->icommandL, 9, _("Refresh Screen"));
	WMInsertListItem(panel->icommandL, 10, _("Open Info Panel"));
	WMInsertListItem(panel->icommandL, 11, _("Open Copyright Panel"));

	panel->paramF = WMCreateFrame(panel->optionsF);
	WMResizeWidget(panel->paramF, width, 50);
	WMMoveWidget(panel->paramF, 10, 105);
	WMSetFrameTitle(panel->paramF, _("Window Manager to Start"));

	panel->paramT = WMCreateTextField(panel->paramF);
	WMResizeWidget(panel->paramT, width - 20, 20);
	WMMoveWidget(panel->paramT, 10, 20);

	WMAddNotificationObserver(dataChanged, panel, WMTextDidChangeNotification, panel->paramT);

	WMMapSubwidgets(panel->paramF);

	panel->quickB = WMCreateSwitchButton(panel->optionsF);
	WMResizeWidget(panel->quickB, width, 20);
	WMMoveWidget(panel->quickB, 10, 120);
	WMSetButtonText(panel->quickB, _("Do not confirm action."));
	WMSetButtonAction(panel->quickB, buttonClicked, panel);

	label = WMCreateLabel(panel->optionsF);
	WMResizeWidget(label, width + 5, FRAME_HEIGHT - 50);
	WMMoveWidget(label, 7, 20);
	WMSetLabelText(label,
		       _("Instructions:\n\n"
			 " - drag items from the left to the menu to add new items\n"
			 " - drag items out of the menu to remove items\n"
			 " - drag items in menu to change their position\n"
			 " - drag items with Control pressed to copy them\n"
			 " - double click in a menu item to change the label\n"
			 " - click on a menu item to change related information"));
	WMMapWidget(label);

	WMRealizeWidget(panel->box);
	WMMapSubwidgets(panel->box);
	WMMapWidget(panel->box);

	{
		int i;
		for (i = 0; i < wlengthof(panel->itemPad); i++)
			WMUnmapWidget(panel->itemPad[i]);
	}
	changedItemPad(panel->typeP, panel);

	panel->sections[NoInfo][0] = label;

	panel->sections[ExecInfo][0] = panel->commandF;
	panel->sections[ExecInfo][1] = panel->shortF;

	panel->sections[CommandInfo][0] = panel->icommandL;
	panel->sections[CommandInfo][1] = panel->shortF;

	panel->sections[ExternalInfo][0] = panel->pathF;

	panel->sections[PipeInfo][0] = panel->pipeF;

	panel->sections[PLPipeInfo][0] = panel->plpipeF;

	panel->sections[DirectoryInfo][0] = panel->dpathF;
	panel->sections[DirectoryInfo][1] = panel->dcommandF;

	panel->currentType = NoInfo;

	showData(panel);

	{
		WMPoint pos;

		pos = WMGetViewScreenPosition(WMWidgetView(panel->box));

		if (pos.x < 200) {
			pos.x += FRAME_WIDTH + 20;
		} else {
			pos.x = 10;
		}

		pos.y = WMAX(pos.y - 100, 0);

		if (panel->menu)
			WEditMenuShowAt(panel->menu, pos.x, pos.y);
	}
}

static void freeItemData(ItemData * data)
{
#define CFREE(d) if (d) wfree(d)

	/* TODO */
	switch (data->type) {
	case CommandInfo:
		CFREE(data->param.command.parameter);
		CFREE(data->param.command.shortcut);
		break;

	case ExecInfo:
		CFREE(data->param.exec.command);
		CFREE(data->param.exec.shortcut);
		break;

	case PipeInfo:
		CFREE(data->param.pipe.command);
		break;

	case PLPipeInfo:
		CFREE(data->param.pipe.command);
		break;

	case ExternalInfo:
		CFREE(data->param.external.path);
		break;

	case DirectoryInfo:
		CFREE(data->param.directory.command);
		CFREE(data->param.directory.directory);
		break;

	default:
		break;
	}

	wfree(data);
#undef CFREE
}

static ItemData *parseCommand(WMPropList * item)
{
	ItemData *data = wmalloc(sizeof(ItemData));
	WMPropList *p;
	char *command = NULL;
	char *parameter = NULL;
	char *shortcut = NULL;
	int i = 1;

	p = WMGetFromPLArray(item, i++);
	command = WMGetFromPLString(p);
	if (strcmp(command, "SHORTCUT") == 0) {
		p = WMGetFromPLArray(item, i++);
		shortcut = WMGetFromPLString(p);
		p = WMGetFromPLArray(item, i++);
		command = WMGetFromPLString(p);
	}
	p = WMGetFromPLArray(item, i++);
	if (p)
		parameter = WMGetFromPLString(p);

	if (strcmp(command, "EXEC") == 0 || strcmp(command, "SHEXEC") == 0) {

		data->type = ExecInfo;

		data->param.exec.command = wstrdup(parameter);
		if (shortcut)
			data->param.exec.shortcut = wstrdup(shortcut);

	} else if (strcmp(command, "OPEN_MENU") == 0) {
		char *p;
		/*
		 * dir menu, menu file
		 * dir WITH
		 * |pipe
		 */
		p = parameter;
		while (isspace(*p) && *p)
			p++;
		if (*p == '|') {
			if (*(p + 1) == '|') {
				p++;
				data->param.pipe.cached = 0;
			} else {
				data->param.pipe.cached = 1;
			}
			data->type = PipeInfo;
			data->param.pipe.command = wtrimspace(p + 1);
		} else {
			char *s;

			p = wstrdup(p);

			s = strstr(p, "WITH");
			if (s) {
				char **tokens;
				char **ctokens;
				int tokn;
				int i, j;

				data->type = DirectoryInfo;

				*s = '\0';
				s += 5;
				while (*s && isspace(*s))
					s++;
				data->param.directory.command = wstrdup(s);

				wtokensplit(p, &tokens, &tokn);
				wfree(p);

				ctokens = wmalloc(sizeof(char *) * tokn);

				for (i = 0, j = 0; i < tokn; i++) {
					if (strcmp(tokens[i], "-noext") == 0) {
						data->param.directory.stripExt = 1;
					} else {
						ctokens[j++] = tokens[i];
					}
				}
				data->param.directory.directory = wtokenjoin(ctokens, j);
				wfree(ctokens);

				wtokenfree(tokens, tokn);
			} else {
				data->type = ExternalInfo;
				data->param.external.path = p;
			}
		}
	} else if (strcmp(command, "OPEN_PLMENU") == 0) {
		char *p;

		p = parameter;
		while (isspace(*p) && *p)
			p++;
		if (*p == '|') {
			if (*(p + 1) == '|') {
				p++;
				data->param.pipe.cached = 0;
			} else {
				data->param.pipe.cached = 1;
			}
			data->type = PLPipeInfo;
			data->param.pipe.command = wtrimspace(p + 1);
		}
	} else if (strcmp(command, "WORKSPACE_MENU") == 0) {
		data->type = WSMenuInfo;
	} else if (strcmp(command, "WINDOWS_MENU") == 0) {
		data->type = WWindowListInfo;
	} else {
		int cmd;

		if (strcmp(command, "ARRANGE_ICONS") == 0) {
			cmd = 0;
		} else if (strcmp(command, "HIDE_OTHERS") == 0) {
			cmd = 1;
		} else if (strcmp(command, "SHOW_ALL") == 0) {
			cmd = 2;
		} else if (strcmp(command, "EXIT") == 0) {
			cmd = 3;
		} else if (strcmp(command, "SHUTDOWN") == 0) {
			cmd = 4;
		} else if (strcmp(command, "RESTART") == 0) {
			if (parameter) {
				cmd = 6;
			} else {
				cmd = 5;
			}
		} else if (strcmp(command, "SAVE_SESSION") == 0) {
			cmd = 7;
		} else if (strcmp(command, "CLEAR_SESSION") == 0) {
			cmd = 8;
		} else if (strcmp(command, "REFRESH") == 0) {
			cmd = 9;
		} else if (strcmp(command, "INFO_PANEL") == 0) {
			cmd = 10;
		} else if (strcmp(command, "LEGAL_PANEL") == 0) {
			cmd = 11;
		} else {
			wwarning(_("unknown command '%s' in menu"), command);
			wfree(data);
			return NULL;
		}

		data->type = CommandInfo;

		data->param.command.command = cmd;
		if (shortcut)
			data->param.command.shortcut = wstrdup(shortcut);
		if (parameter)
			data->param.command.parameter = wstrdup(parameter);
	}

	return data;
}

static void updateFrameTitle(_Panel * panel, const char *title, InfoType type)
{
	if (type != NoInfo) {
		char *tmp;

		switch (type) {
		case ExecInfo:
			tmp = wstrconcat(title, _(": Execute Program"));
			break;

		case CommandInfo:
			tmp = wstrconcat(title, _(": Perform Internal Command"));
			break;

		case ExternalInfo:
			tmp = wstrconcat(title, _(": Open a Submenu"));
			break;

		case PipeInfo:
			tmp = wstrconcat(title, _(": Program Generated Submenu"));
			break;

		case PLPipeInfo:
			tmp = wstrconcat(title, _(": Program Generated Proplist Submenu"));
			break;

		case DirectoryInfo:
			tmp = wstrconcat(title, _(": Directory Contents Menu"));
			break;

		case WSMenuInfo:
			tmp = wstrconcat(title, _(": Open Workspaces Submenu"));
			break;

		case WWindowListInfo:
			tmp = wstrconcat(title, _(": Open Window List Submenu"));
			break;

		default:
			tmp = NULL;
			break;
		}
		WMSetFrameTitle(panel->optionsF, tmp);
		wfree(tmp);
	} else {
		WMSetFrameTitle(panel->optionsF, NULL);
	}
}

static void changeInfoType(_Panel * panel, const char *title, InfoType type)
{
	WMWidget **w;

	if (panel->currentType != type) {

		w = panel->sections[panel->currentType];

		while (*w) {
			WMUnmapWidget(*w);
			w++;
		}
		WMUnmapWidget(panel->paramF);
		WMUnmapWidget(panel->quickB);

		w = panel->sections[type];

		while (*w) {
			WMMapWidget(*w);
			w++;
		}
	}

	updateFrameTitle(panel, title, type);

	panel->currentType = type;
}

static void updateMenuItem(_Panel * panel, WEditMenuItem * item, WMWidget * changedWidget)
{
	ItemData *data = WGetEditMenuItemData(item);

	assert(data != NULL);

#define REPLACE(v, d) if (v) wfree(v); v = d

	switch (data->type) {
	case ExecInfo:
		if (changedWidget == panel->commandT) {
			REPLACE(data->param.exec.command, WMGetTextFieldText(panel->commandT));
		}
		if (changedWidget == panel->shortT) {
			REPLACE(data->param.exec.shortcut, WMGetTextFieldText(panel->shortT));
		}
		break;

	case CommandInfo:
		if (changedWidget == panel->icommandL) {
			data->param.command.command = WMGetListSelectedItemRow(panel->icommandL);
		}
		switch (data->param.command.command) {
		case 3:
		case 4:
			if (changedWidget == panel->quickB) {
				REPLACE(data->param.command.parameter, WMGetButtonSelected(panel->quickB)
					? wstrdup("QUICK") : NULL);
			}
			break;

		case 6:
			if (changedWidget == panel->paramT) {
				REPLACE(data->param.command.parameter, WMGetTextFieldText(panel->paramT));
			}
			break;
		}
		if (changedWidget == panel->shortT) {
			REPLACE(data->param.command.shortcut, WMGetTextFieldText(panel->shortT));
		}

		break;

	case PipeInfo:
		if (changedWidget == panel->pipeT) {
			REPLACE(data->param.pipe.command, WMGetTextFieldText(panel->pipeT));
		}
		if (changedWidget == panel->pipeCacheB) {
			data->param.pipe.cached = WMGetButtonSelected(panel->pipeCacheB);
		}
		break;

	case PLPipeInfo:
		if (changedWidget == panel->plpipeT) {
			REPLACE(data->param.pipe.command, WMGetTextFieldText(panel->plpipeT));
		}
		if (changedWidget == panel->plpipeCacheB) {
			data->param.pipe.cached = WMGetButtonSelected(panel->plpipeCacheB);
		}
		break;

	case ExternalInfo:
		if (changedWidget == panel->pathT) {
			REPLACE(data->param.external.path, WMGetTextFieldText(panel->pathT));
		}
		break;

	case DirectoryInfo:
		if (changedWidget == panel->dpathT) {
			REPLACE(data->param.directory.directory, WMGetTextFieldText(panel->dpathT));
		}
		if (changedWidget == panel->dcommandT) {
			REPLACE(data->param.directory.command, WMGetTextFieldText(panel->dcommandT));
		}
		if (changedWidget == panel->dstripB) {
			data->param.directory.stripExt = WMGetButtonSelected(panel->dstripB);
		}
		break;

	default:
		assert(0);
		break;
	}

#undef REPLACE
}

static void
menuItemCloned(WEditMenuDelegate * delegate, WEditMenu * menu, WEditMenuItem * origItem, WEditMenuItem * newItem)
{
	ItemData *data = WGetEditMenuItemData(origItem);
	ItemData *newData;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) delegate;
	(void) menu;

	if (!data)
		return;

#define DUP(s) (s) ? wstrdup(s) : NULL

	newData = wmalloc(sizeof(ItemData));

	newData->type = data->type;

	switch (data->type) {
	case ExecInfo:
		newData->param.exec.command = DUP(data->param.exec.command);
		newData->param.exec.shortcut = DUP(data->param.exec.shortcut);
		break;

	case CommandInfo:
		newData->param.command.command = data->param.command.command;
		newData->param.command.parameter = DUP(data->param.command.parameter);
		newData->param.command.shortcut = DUP(data->param.command.shortcut);
		break;

	case PipeInfo:
		newData->param.pipe.command = DUP(data->param.pipe.command);
		newData->param.pipe.cached = data->param.pipe.cached;
		break;

	case PLPipeInfo:
		newData->param.pipe.command = DUP(data->param.pipe.command);
		newData->param.pipe.cached = data->param.pipe.cached;
		break;

	case ExternalInfo:
		newData->param.external.path = DUP(data->param.external.path);
		break;

	case DirectoryInfo:
		newData->param.directory.directory = DUP(data->param.directory.directory);
		newData->param.directory.command = DUP(data->param.directory.command);
		newData->param.directory.stripExt = data->param.directory.stripExt;
		break;

	default:
		break;
	}

#undef DUP

	WSetEditMenuItemData(newItem, newData, (WMCallback *) freeItemData);
}

static void menuItemEdited(struct WEditMenuDelegate *delegate, WEditMenu * menu, WEditMenuItem * item)
{
	_Panel *panel = (_Panel *) delegate->data;
	WEditMenu *submenu;

	/* Parameter not used, but tell the compiler it is ok */
	(void) menu;

	updateFrameTitle(panel, WGetEditMenuItemTitle(item), panel->currentType);

	submenu = WGetEditMenuSubmenu(item);
	if (submenu) {
		WSetEditMenuTitle(submenu, WGetEditMenuItemTitle(item));
	}
}

static Bool shouldRemoveItem(struct WEditMenuDelegate *delegate, WEditMenu * menu, WEditMenuItem * item)
{
	_Panel *panel = (_Panel *) delegate->data;

	if (panel->dontAsk)
		return True;

	if (WGetEditMenuSubmenu(item)) {
		int res;

		res = WMRunAlertPanel(WMWidgetScreen(menu), NULL,
				      _("Remove Submenu"),
				      _("Removing this item will destroy all items inside\n"
					"the submenu. Do you really want to do that?"),
				      _("Yes"), _("No"), _("Yes, don't ask again"));
		switch (res) {
		case WAPRDefault:
			return True;
		case WAPRAlternate:
			return False;
		case WAPROther:
			panel->dontAsk = True;
			return True;
		}
	}
	return True;
}

static void menuItemDeselected(WEditMenuDelegate * delegate, WEditMenu * menu, WEditMenuItem * item)
{
	_Panel *panel = (_Panel *) delegate->data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) menu;
	(void) item;

	changeInfoType(panel, NULL, NoInfo);
}

static void menuItemSelected(WEditMenuDelegate * delegate, WEditMenu * menu, WEditMenuItem * item)
{
	ItemData *data = WGetEditMenuItemData(item);
	_Panel *panel = (_Panel *) delegate->data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) menu;

	panel->currentItem = item;

	if (data) {
		changeInfoType(panel, WGetEditMenuItemTitle(item), data->type);

		switch (data->type) {
		case NoInfo:
			break;

		case ExecInfo:
			WMSetTextFieldText(panel->commandT, data->param.exec.command);
			WMSetTextFieldText(panel->shortT, data->param.exec.shortcut);
			break;

		case CommandInfo:
			WMSelectListItem(panel->icommandL, data->param.command.command);
			WMSetListPosition(panel->icommandL, data->param.command.command - 2);
			WMSetTextFieldText(panel->shortT, data->param.command.shortcut);

			switch (data->param.command.command) {
			case 3:
			case 4:
				WMSetButtonSelected(panel->quickB, data->param.command.parameter != NULL);
				break;
			case 6:
				WMSetTextFieldText(panel->paramT, data->param.command.parameter);
				break;
			}

			icommandLClicked(panel->icommandL, panel);
			break;

		case PipeInfo:
			WMSetTextFieldText(panel->pipeT, data->param.pipe.command);
			WMSetButtonSelected(panel->pipeCacheB, data->param.pipe.cached);
			break;

		case PLPipeInfo:
			WMSetTextFieldText(panel->plpipeT, data->param.pipe.command);
			WMSetButtonSelected(panel->plpipeCacheB, data->param.pipe.cached);
			break;

		case ExternalInfo:
			WMSetTextFieldText(panel->pathT, data->param.external.path);
			break;

		case DirectoryInfo:
			WMSetTextFieldText(panel->dpathT, data->param.directory.directory);
			WMSetTextFieldText(panel->dcommandT, data->param.directory.command);
			WMSetButtonSelected(panel->dstripB, data->param.directory.stripExt);
			break;

		case WSMenuInfo:
			break;

		default:
			break;
		}
	}
}

static WEditMenu *buildSubmenu(_Panel * panel, WMPropList * pl)
{
	WMScreen *scr = WMWidgetScreen(panel->parent);
	WEditMenu *menu;
	WEditMenuItem *item;
	char *title;
	WMPropList *tp, *bp;
	int i;

	tp = WMGetFromPLArray(pl, 0);
	title = WMGetFromPLString(tp);

	menu = WCreateEditMenu(scr, title);

	for (i = 1; i < WMGetPropListItemCount(pl); i++) {
		WMPropList *pi;

		pi = WMGetFromPLArray(pl, i);

		tp = WMGetFromPLArray(pi, 0);
		bp = WMGetFromPLArray(pi, 1);

		title = WMGetFromPLString(tp);

		if (!bp || WMIsPLArray(bp)) {	/* it's a submenu */
			WEditMenu *submenu;

			submenu = buildSubmenu(panel, pi);

			item = WAddMenuItemWithTitle(menu, title);

			WSetEditMenuSubmenu(menu, item, submenu);
		} else {
			ItemData *data;

			data = parseCommand(pi);

			if (data != NULL) {
				item = WAddMenuItemWithTitle(menu, title);
				if (panel->markerPix[data->type])
					WSetEditMenuItemImage(item, panel->markerPix[data->type]);
				WSetEditMenuItemData(item, data, (WMCallback *) freeItemData);
			} else {
				char *buf = wmalloc(1024);
				snprintf(buf, 1024, _("Invalid menu command \"%s\" with label \"%s\" cleared"),
					WMGetFromPLString(WMGetFromPLArray(pi, 1)),
					WMGetFromPLString(WMGetFromPLArray(pi, 0)));
				WMRunAlertPanel(scr, panel->parent, _("Warning"), buf, _("OK"), NULL, NULL);
				wfree(buf);
			}

		}
	}

	WSetEditMenuAcceptsDrop(menu, True);
	WSetEditMenuDelegate(menu, &menuDelegate);

	WMRealizeWidget(menu);

	return menu;
}

static void buildMenuFromPL(_Panel * panel, WMPropList * pl)
{
	panel->menu = buildSubmenu(panel, pl);
}

static WMPropList *getDefaultMenu(_Panel * panel)
{
	WMPropList *menu;
	static const char menuPath[] = WMAKER_RESOURCE_PATH "/plmenu";

	menu = WMReadPropListFromFile(menuPath);
	if (!menu) {
		char *buffer, *msg;

		msg = _("Could not open default menu from '%s'");
		buffer = wmalloc(strlen(msg) + strlen(menuPath) + 10);
		sprintf(buffer, msg, menuPath);
		WMRunAlertPanel(WMWidgetScreen(panel->parent), panel->parent,
				_("Error"), buffer, _("OK"), NULL, NULL);
		wfree(buffer);
	}

	return menu;
}

static void showData(_Panel * panel)
{
	const char *gspath;
	char *menuPath;
	WMPropList *pmenu;

	gspath = wusergnusteppath();

	menuPath = wmalloc(strlen(gspath) + 32);
	strcpy(menuPath, gspath);
	strcat(menuPath, "/Defaults/WMRootMenu");

	pmenu = WMReadPropListFromFile(menuPath);

	if (!pmenu || !WMIsPLArray(pmenu)) {
		int res;

		res = WMRunAlertPanel(WMWidgetScreen(panel->parent), panel->parent,
				      _("Warning"),
				      _("The menu file format currently in use is not supported\n"
					"by this tool. Do you want to discard the current menu\n"
					"to use this tool?"),
				      _("Yes, Discard and Update"), _("No, Keep Current Menu"), NULL);

		if (res == WAPRDefault) {
			pmenu = getDefaultMenu(panel);

			if (!pmenu) {
				pmenu = WMCreatePLArray(WMCreatePLString("Applications"), NULL);
			}
		} else {
			panel->dontSave = True;
			return;
		}
	}

	panel->menuPath = menuPath;

	buildMenuFromPL(panel, pmenu);

	WMReleasePropList(pmenu);
}

static Bool notblank(const char *s)
{
	if (s) {
		while (*s++) {
			if (!isspace(*s))
				return True;
		}
	}
	return False;
}

static WMPropList *processData(const char *title, ItemData * data)
{
	WMPropList *item;
	char *s1;
	static WMPropList *pscut = NULL;
	static WMPropList *pomenu = NULL;
	static WMPropList *poplmenu = NULL;
	int i;

	if (data == NULL)
		return NULL;

	if (!pscut) {
		pscut = WMCreatePLString("SHORTCUT");
		pomenu = WMCreatePLString("OPEN_MENU");
		poplmenu = WMCreatePLString("OPEN_PLMENU");
	}

	item = WMCreatePLArray(WMCreatePLString(title), NULL);

	switch (data->type) {
	case ExecInfo:
		if (data->param.exec.command == NULL)
			goto return_null;
#if 1
		if (strpbrk(data->param.exec.command, "&$*|><?`=;")) {
			s1 = "SHEXEC";
		} else {
			s1 = "EXEC";
		}
#else
		s1 = "SHEXEC";
#endif

		if (notblank(data->param.exec.shortcut)) {
			WMAddToPLArray(item, pscut);
			WMAddToPLArray(item, WMCreatePLString(data->param.exec.shortcut));
		}

		WMAddToPLArray(item, WMCreatePLString(s1));
		WMAddToPLArray(item, WMCreatePLString(data->param.exec.command));
		break;

	case CommandInfo:
		if (notblank(data->param.command.shortcut)) {
			WMAddToPLArray(item, pscut);
			WMAddToPLArray(item, WMCreatePLString(data->param.command.shortcut));
		}

		i = data->param.command.command;

		WMAddToPLArray(item, WMCreatePLString(commandNames[i]));

		switch (i) {
		case 3:
		case 4:
			if (data->param.command.parameter) {
				WMAddToPLArray(item, WMCreatePLString(data->param.command.parameter));
			}
			break;

		case 6:	/* restart */
			if (data->param.command.parameter) {
				WMAddToPLArray(item, WMCreatePLString(data->param.command.parameter));
			}
			break;
		}

		break;

	case PipeInfo:
	case PLPipeInfo:
		if (!data->param.pipe.command)
			goto return_null;
		if (data->type == PLPipeInfo)
			WMAddToPLArray(item, poplmenu);
		else
			WMAddToPLArray(item, pomenu);

		if (data->param.pipe.cached)
			s1 = wstrconcat("| ", data->param.pipe.command);
		else
			s1 = wstrconcat("|| ", data->param.pipe.command);
		WMAddToPLArray(item, WMCreatePLString(s1));
		wfree(s1);
		break;

	case ExternalInfo:
		if (!data->param.external.path)
			goto return_null;
		WMAddToPLArray(item, pomenu);
		WMAddToPLArray(item, WMCreatePLString(data->param.external.path));
		break;

	case DirectoryInfo:
		{
			int l;
			char *tmp;

			if (!data->param.directory.directory || !data->param.directory.command)
				goto return_null;

			l = strlen(data->param.directory.directory);
			l += strlen(data->param.directory.command);
			l += 32;

			WMAddToPLArray(item, pomenu);

			tmp = wmalloc(l);
			sprintf(tmp, "%s%s WITH %s",
				data->param.directory.stripExt ? "-noext " : "",
				data->param.directory.directory, data->param.directory.command);

			WMAddToPLArray(item, WMCreatePLString(tmp));
			wfree(tmp);
		}
		break;

	case WSMenuInfo:
		WMAddToPLArray(item, WMCreatePLString("WORKSPACE_MENU"));
		break;

	case WWindowListInfo:
		WMAddToPLArray(item, WMCreatePLString("WINDOWS_MENU"));
		break;

	default:
		assert(0);
		break;
	}

	return item;

 return_null:
	WMReleasePropList(item);
	return NULL;
}

static WMPropList *processSubmenu(WEditMenu * menu)
{
	WEditMenuItem *item;
	WMPropList *pmenu;
	WMPropList *pl;
	char *s;
	int i;

	s = WGetEditMenuTitle(menu);
	pl = WMCreatePLString(s);

	pmenu = WMCreatePLArray(pl, NULL);

	i = 0;
	while ((item = WGetEditMenuItem(menu, i++))) {
		WEditMenu *submenu;

		s = WGetEditMenuItemTitle(item);

		submenu = WGetEditMenuSubmenu(item);
		if (submenu) {
			pl = processSubmenu(submenu);
		} else {
			pl = processData(s, WGetEditMenuItemData(item));
		}

		if (!pl)
			continue;

		WMAddToPLArray(pmenu, pl);
	}

	return pmenu;
}

static WMPropList *buildPLFromMenu(_Panel * panel)
{
	WMPropList *menu;

	menu = processSubmenu(panel->menu);

	return menu;
}

static void storeData(_Panel * panel)
{
	WMPropList *menu;

	if (panel->dontSave)
		return;

	menu = buildPLFromMenu(panel);

	WMWritePropListToFile(menu, panel->menuPath);

	WMReleasePropList(menu);
}

static void showMenus(_Panel * panel)
{
	if (panel->menu)
		WEditMenuUnhide(panel->menu);
}

static void hideMenus(_Panel * panel)
{
	if (panel->menu)
		WEditMenuHide(panel->menu);
}

Panel *InitMenu(WMWidget *parent)
{
	_Panel *panel;

	panel = wmalloc(sizeof(_Panel));

	panel->sectionName = _("Applications Menu Definition");

	panel->description = _("Edit the menu for launching applications.");

	panel->parent = parent;

	panel->callbacks.createWidgets = createPanel;
	panel->callbacks.updateDomain = storeData;
	panel->callbacks.showPanel = showMenus;
	panel->callbacks.hidePanel = hideMenus;

	AddSection(panel, ICON_FILE);

	return panel;
}
