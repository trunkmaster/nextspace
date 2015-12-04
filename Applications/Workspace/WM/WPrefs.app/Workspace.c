/* Workspace.c- workspace options
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

typedef struct _Panel {
	WMBox *box;

	char *sectionName;

	char *description;

	CallbackRec callbacks;

	WMWidget *parent;

	WMFrame *navF;

	WMButton *linkB;
	WMButton *cyclB;
	WMButton *newB;
	WMLabel *linkL;
	WMLabel *cyclL;
	WMLabel *newL;

	WMLabel *posiL;
	WMLabel *posL;
	WMPopUpButton *posP;
} _Panel;

#define ICON_FILE	"workspace"

#define ARQUIVO_XIS	"xis"
#define DONT_LINK_FILE	"dontlinkworkspaces"
#define CYCLE_FILE	"cycleworkspaces"
#define ADVANCE_FILE	"advancetonewworkspace"
#define WSNAME_FILE 	"workspacename"

static char *WSNamePositions[] = {
	"none",
	"center",
	"top",
	"bottom",
	"topleft",
	"topright",
	"bottomleft",
	"bottomright"
};

static void showData(_Panel * panel)
{
	int i, idx;
	char *str;

	WMSetButtonSelected(panel->linkB, !GetBoolForKey("DontLinkWorkspaces"));

	WMSetButtonSelected(panel->cyclB, GetBoolForKey("CycleWorkspaces"));

	WMSetButtonSelected(panel->newB, GetBoolForKey("AdvanceToNewWorkspace"));

	str = GetStringForKey("WorkspaceNameDisplayPosition");
	if (!str)
		str = "center";

	idx = 1;		/* center */
	for (i = 0; i < wlengthof(WSNamePositions); i++) {
		if (strcasecmp(WSNamePositions[i], str) == 0) {
			idx = i;
			break;
		}
	}
	WMSetPopUpButtonSelectedItem(panel->posP, idx);
}

static void createPanel(Panel * p)
{
	_Panel *panel = (_Panel *) p;
	WMScreen *scr = WMWidgetScreen(panel->parent);
	WMPixmap *icon1;
	RImage *xis = NULL;
	RContext *rc = WMScreenRContext(scr);
	char *path;

	path = LocateImage(ARQUIVO_XIS);
	if (path) {
		xis = RLoadImage(rc, path, 0);
		if (!xis) {
			wwarning(_("could not load image file %s"), path);
		}
		wfree(path);
	}

	panel->box = WMCreateBox(panel->parent);
	WMSetViewExpandsToParent(WMWidgetView(panel->box), 2, 2, 2, 2);

    /***************** Workspace Navigation *****************/
	panel->navF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->navF, 490, 210);
	WMMoveWidget(panel->navF, 15, 8);
	WMSetFrameTitle(panel->navF, _("Workspace Navigation"));

	panel->cyclB = WMCreateSwitchButton(panel->navF);
	WMResizeWidget(panel->cyclB, 410, 34);
	WMMoveWidget(panel->cyclB, 75, 26);
	WMSetButtonText(panel->cyclB, _("Wrap to the first workspace from the last workspace"));

	panel->cyclL = WMCreateLabel(panel->navF);
	WMResizeWidget(panel->cyclL, 60, 60);
	WMMoveWidget(panel->cyclL, 10, 12);
	WMSetLabelImagePosition(panel->cyclL, WIPImageOnly);
	CreateImages(scr, rc, xis, CYCLE_FILE, &icon1, NULL);
	if (icon1)
	{
		WMSetLabelImage(panel->cyclL, icon1);
		WMReleasePixmap(icon1);
	}

	/**/ panel->linkB = WMCreateSwitchButton(panel->navF);
	WMResizeWidget(panel->linkB, 410, 34);
	WMMoveWidget(panel->linkB, 75, 73);
	WMSetButtonText(panel->linkB, _("Switch workspaces while dragging windows"));

	panel->linkL = WMCreateLabel(panel->navF);
	WMResizeWidget(panel->linkL, 60, 40);
	WMMoveWidget(panel->linkL, 10, 77);
	WMSetLabelImagePosition(panel->linkL, WIPImageOnly);
	CreateImages(scr, rc, xis, DONT_LINK_FILE, &icon1, NULL);
	if (icon1)
	{
		WMSetLabelImage(panel->linkL, icon1);
		WMReleasePixmap(icon1);
	}

	/**/ panel->newB = WMCreateSwitchButton(panel->navF);
	WMResizeWidget(panel->newB, 410, 34);
	WMMoveWidget(panel->newB, 75, 115);
	WMSetButtonText(panel->newB, _("Automatically create new workspaces"));

	panel->newL = WMCreateLabel(panel->navF);
	WMResizeWidget(panel->newL, 60, 20);
	WMMoveWidget(panel->newL, 10, 123);
	WMSetLabelImagePosition(panel->newL, WIPImageOnly);
	CreateImages(scr, rc, xis, ADVANCE_FILE, &icon1, NULL);
	if (icon1)
	{
		WMSetLabelImage(panel->newL, icon1);
		WMReleasePixmap(icon1);
	}

	/**/ panel->posL = WMCreateLabel(panel->navF);
	WMResizeWidget(panel->posL, 275, 30);
	WMMoveWidget(panel->posL, 75, 161);
	// WMSetLabelTextAlignment(panel->posL, WARight);
	WMSetLabelText(panel->posL, _("Position of workspace name display"));

	panel->posiL = WMCreateLabel(panel->navF);
	WMResizeWidget(panel->posiL, 60, 40);
	WMMoveWidget(panel->posiL, 10, 156);
	WMSetLabelImagePosition(panel->posiL, WIPImageOnly);
	CreateImages(scr, rc, xis, WSNAME_FILE, &icon1, NULL);
	if (icon1)
	{
		WMSetLabelImage(panel->posiL, icon1);
		WMReleasePixmap(icon1);
	}

	panel->posP = WMCreatePopUpButton(panel->navF);
	WMResizeWidget(panel->posP, 125, 20);
	WMMoveWidget(panel->posP, 350, 166);
	WMAddPopUpButtonItem(panel->posP, _("Disable"));
	WMAddPopUpButtonItem(panel->posP, _("Center"));
	WMAddPopUpButtonItem(panel->posP, _("Top"));
	WMAddPopUpButtonItem(panel->posP, _("Bottom"));
	WMAddPopUpButtonItem(panel->posP, _("Top/Left"));
	WMAddPopUpButtonItem(panel->posP, _("Top/Right"));
	WMAddPopUpButtonItem(panel->posP, _("Bottom/Left"));
	WMAddPopUpButtonItem(panel->posP, _("Bottom/Right"));

	WMMapSubwidgets(panel->navF);

	if (xis)
		RReleaseImage(xis);

	WMRealizeWidget(panel->box);
	WMMapSubwidgets(panel->box);

	showData(panel);
}

static void storeData(_Panel * panel)
{
	SetBoolForKey(!WMGetButtonSelected(panel->linkB), "DontLinkWorkspaces");
	SetBoolForKey(WMGetButtonSelected(panel->cyclB), "CycleWorkspaces");
	SetBoolForKey(WMGetButtonSelected(panel->newB), "AdvanceToNewWorkspace");

	SetStringForKey(WSNamePositions[WMGetPopUpButtonSelectedItem(panel->posP)],
			"WorkspaceNameDisplayPosition");
}

Panel *InitWorkspace(WMWidget *parent)
{
	_Panel *panel;

	panel = wmalloc(sizeof(_Panel));

	panel->sectionName = _("Workspace Preferences");

	panel->description = _("Workspace navigation features\n"
			       "and workspace name display settings.");

	panel->parent = parent;

	panel->callbacks.createWidgets = createPanel;
	panel->callbacks.updateDomain = storeData;

	AddSection(panel, ICON_FILE);

	return panel;
}
