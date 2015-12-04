/* Paths.c- pixmap/icon paths
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

#include "WPrefs.h"
#include <unistd.h>
#include <assert.h>

typedef struct _Panel {
	WMBox *box;
	char *sectionName;

	char *description;

	CallbackRec callbacks;

	WMWidget *parent;

	WMTabView *tabv;

	WMFrame *pixF;
	WMList *pixL;
	WMButton *pixaB;
	WMButton *pixrB;

	WMFrame *icoF;
	WMList *icoL;
	WMButton *icoaB;
	WMButton *icorB;

	WMColor *red;
	WMColor *black;
	WMColor *white;
	WMColor *gray;
	WMFont *font;
} _Panel;

#define ICON_FILE	"paths"

static void addPathToList(WMList * list, int index, const char *path)
{
	char *fpath = wexpandpath(path);
	WMListItem *item;

	item = WMInsertListItem(list, index, path);

	if (access(fpath, X_OK) != 0) {
		item->uflags = 1;
	}
	wfree(fpath);
}

static void showData(_Panel * panel)
{
	WMPropList *array, *val;
	int i;

	array = GetObjectForKey("IconPath");
	if (!array || !WMIsPLArray(array)) {
		if (array)
			wwarning(_("bad value in option IconPath. Using default path list"));
		addPathToList(panel->icoL, -1, "~/pixmaps");
		addPathToList(panel->icoL, -1, "~/GNUstep/Library/Icons");
		addPathToList(panel->icoL, -1, "/usr/include/X11/pixmaps");
		addPathToList(panel->icoL, -1, "/usr/local/share/WindowMaker/Icons");
		addPathToList(panel->icoL, -1, "/usr/local/share/WindowMaker/Pixmaps");
		addPathToList(panel->icoL, -1, "/usr/share/WindowMaker/Icons");
	} else {
		for (i = 0; i < WMGetPropListItemCount(array); i++) {
			val = WMGetFromPLArray(array, i);
			addPathToList(panel->icoL, -1, WMGetFromPLString(val));
		}
	}

	array = GetObjectForKey("PixmapPath");
	if (!array || !WMIsPLArray(array)) {
		if (array)
			wwarning(_("bad value in option PixmapPath. Using default path list"));
		addPathToList(panel->pixL, -1, "~/pixmaps");
		addPathToList(panel->pixL, -1, "~/GNUstep/Library/WindowMaker/Pixmaps");
		addPathToList(panel->pixL, -1, "/usr/local/share/WindowMaker/Pixmaps");
	} else {
		for (i = 0; i < WMGetPropListItemCount(array); i++) {
			val = WMGetFromPLArray(array, i);
			addPathToList(panel->pixL, -1, WMGetFromPLString(val));
		}
	}
}

static void pushButton(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int i;

	/* icon paths */
	if (w == panel->icorB) {
		i = WMGetListSelectedItemRow(panel->icoL);

		if (i >= 0)
			WMRemoveListItem(panel->icoL, i);
	}

	/* pixmap paths */
	if (w == panel->pixrB) {
		i = WMGetListSelectedItemRow(panel->pixL);

		if (i >= 0)
			WMRemoveListItem(panel->pixL, i);
	}
}

static void browseForFile(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	WMFilePanel *filePanel;

	assert(w == panel->icoaB || w == panel->pixaB);

	filePanel = WMGetOpenPanel(WMWidgetScreen(w));

	WMSetFilePanelCanChooseFiles(filePanel, False);

	if (WMRunModalFilePanelForDirectory(filePanel, panel->parent, "/", _("Select directory"), NULL) == True) {
		char *str = WMGetFilePanelFileName(filePanel);

		if (str) {
			int len = strlen(str);

			/* Remove the trailing '/' except if the path is exactly / */
			if (len > 1 && str[len - 1] == '/') {
				str[len - 1] = '\0';
				len--;
			}
			if (len > 0) {
				WMList *lPtr;
				int i;

				if (w == panel->icoaB)
					lPtr = panel->icoL;
				else if (w == panel->pixaB)
					lPtr = panel->pixL;
				else
					goto error_unknown_widget;

				i = WMGetListSelectedItemRow(lPtr);
				if (i >= 0)
					i++;
				addPathToList(lPtr, i, str);
				WMSetListBottomPosition(lPtr, WMGetListNumberOfRows(lPtr));
			}
		error_unknown_widget:
			wfree(str);
		}
	}
}

static void paintItem(WMList * lPtr, int index, Drawable d, char *text, int state, WMRect * rect)
{
	int width, height, x, y;
	_Panel *panel = (_Panel *) WMGetHangedData(lPtr);
	WMScreen *scr = WMWidgetScreen(lPtr);
	Display *dpy = WMScreenDisplay(scr);
	WMColor *backColor = (state & WLDSSelected) ? panel->white : panel->gray;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) index;

	width = rect->size.width;
	height = rect->size.height;
	x = rect->pos.x;
	y = rect->pos.y;

	XFillRectangle(dpy, d, WMColorGC(backColor), x, y, width, height);

	if (state & 1) {
		WMDrawString(scr, d, panel->red, panel->font, x + 4, y, text, strlen(text));
	} else {
		WMDrawString(scr, d, panel->black, panel->font, x + 4, y, text, strlen(text));
	}
}

static void storeData(_Panel * panel)
{
	WMPropList *list;
	WMPropList *tmp;
	int i;
	char *p;

	list = WMCreatePLArray(NULL, NULL);
	for (i = 0; i < WMGetListNumberOfRows(panel->icoL); i++) {
		p = WMGetListItem(panel->icoL, i)->text;
		tmp = WMCreatePLString(p);
		WMAddToPLArray(list, tmp);
	}
	SetObjectForKey(list, "IconPath");

	list = WMCreatePLArray(NULL, NULL);
	for (i = 0; i < WMGetListNumberOfRows(panel->pixL); i++) {
		p = WMGetListItem(panel->pixL, i)->text;
		tmp = WMCreatePLString(p);
		WMAddToPLArray(list, tmp);
	}
	SetObjectForKey(list, "PixmapPath");
}

static void createPanel(Panel * p)
{
	_Panel *panel = (_Panel *) p;
	WMScreen *scr = WMWidgetScreen(panel->parent);
	WMTabViewItem *tab;

	panel->white = WMWhiteColor(scr);
	panel->black = WMBlackColor(scr);
	panel->gray = WMGrayColor(scr);
	panel->red = WMCreateRGBColor(scr, 0xffff, 0, 0, True);
	panel->font = WMSystemFontOfSize(scr, 12);

	panel->box = WMCreateBox(panel->parent);
	WMSetViewExpandsToParent(WMWidgetView(panel->box), 2, 2, 2, 2);

	panel->tabv = WMCreateTabView(panel->box);
	WMMoveWidget(panel->tabv, 12, 10);
	WMResizeWidget(panel->tabv, 500, 215);

	/* icon path */
	panel->icoF = WMCreateFrame(panel->box);
	WMSetFrameRelief(panel->icoF, WRFlat);
	WMResizeWidget(panel->icoF, 230, 210);

	tab = WMCreateTabViewItemWithIdentifier(0);
	WMSetTabViewItemView(tab, WMWidgetView(panel->icoF));
	WMAddItemInTabView(panel->tabv, tab);
	WMSetTabViewItemLabel(tab, _("Icon Search Paths"));

	panel->icoL = WMCreateList(panel->icoF);
	WMResizeWidget(panel->icoL, 480, 147);
	WMMoveWidget(panel->icoL, 10, 10);
	WMSetListUserDrawProc(panel->icoL, paintItem);
	WMHangData(panel->icoL, panel);

	panel->icoaB = WMCreateCommandButton(panel->icoF);
	WMResizeWidget(panel->icoaB, 95, 24);
	WMMoveWidget(panel->icoaB, 293, 165);
	WMSetButtonText(panel->icoaB, _("Add"));
	WMSetButtonAction(panel->icoaB, browseForFile, panel);
	WMSetButtonImagePosition(panel->icoaB, WIPRight);

	panel->icorB = WMCreateCommandButton(panel->icoF);
	WMResizeWidget(panel->icorB, 95, 24);
	WMMoveWidget(panel->icorB, 395, 165);
	WMSetButtonText(panel->icorB, _("Remove"));
	WMSetButtonAction(panel->icorB, pushButton, panel);

	WMMapSubwidgets(panel->icoF);

	/* pixmap path */
	panel->pixF = WMCreateFrame(panel->box);
	WMSetFrameRelief(panel->pixF, WRFlat);
	WMResizeWidget(panel->pixF, 230, 210);

	tab = WMCreateTabViewItemWithIdentifier(0);
	WMSetTabViewItemView(tab, WMWidgetView(panel->pixF));
	WMAddItemInTabView(panel->tabv, tab);
	WMSetTabViewItemLabel(tab, _("Pixmap Search Paths"));

	panel->pixL = WMCreateList(panel->pixF);
	WMResizeWidget(panel->pixL, 480, 147);
	WMMoveWidget(panel->pixL, 10, 10);
	WMSetListUserDrawProc(panel->pixL, paintItem);
	WMHangData(panel->pixL, panel);

	panel->pixaB = WMCreateCommandButton(panel->pixF);
	WMResizeWidget(panel->pixaB, 95, 24);
	WMMoveWidget(panel->pixaB, 293, 165);
	WMSetButtonText(panel->pixaB, _("Add"));
	WMSetButtonAction(panel->pixaB, browseForFile, panel);
	WMSetButtonImagePosition(panel->pixaB, WIPRight);

	panel->pixrB = WMCreateCommandButton(panel->pixF);
	WMResizeWidget(panel->pixrB, 95, 24);
	WMMoveWidget(panel->pixrB, 395, 165);
	WMSetButtonText(panel->pixrB, _("Remove"));
	WMSetButtonAction(panel->pixrB, pushButton, panel);

	WMMapSubwidgets(panel->pixF);

	WMRealizeWidget(panel->box);
	WMMapSubwidgets(panel->box);

	showData(panel);
}

Panel *InitPaths(WMWidget *parent)
{
	_Panel *panel;

	panel = wmalloc(sizeof(_Panel));

	panel->sectionName = _("Search Path Configuration");

	panel->description = _("Search paths to use when looking for pixmaps\n" "and icons.");

	panel->parent = parent;

	panel->callbacks.createWidgets = createPanel;
	panel->callbacks.updateDomain = storeData;

	AddSection(panel, ICON_FILE);

	return panel;
}
