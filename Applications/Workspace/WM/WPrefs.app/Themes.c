/* Themes.c- Theme stuff
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

typedef struct _Panel {
	WMBox *box;

	char *sectionName;

	CallbackRec callbacks;

	WMWidget *parent;

	WMButton *saveB;
	WMList *list;
	WMButton *loadB;
	WMButton *instB;

	WMFrame *totF;
	WMButton *totB;
	WMLabel *totL;

	WMFrame *botF;
	WMButton *botB;
	WMLabel *botL;

	pid_t tilePID;
	pid_t barPID;
} _Panel;

#define ICON_FILE	"theme"

static void showData(_Panel * panel)
{

}

static void finishedTileDownload(void *data)
{
	_Panel *panel = (_Panel *) data;

	WMSetButtonText(panel->totB, _("Set"));
	panel->tilePID = 0;
}

static void finishedBarDownload(void *data)
{
	_Panel *panel = (_Panel *) data;

	WMSetButtonText(panel->botB, _("Set"));
	panel->barPID = 0;
}

static pid_t downloadFile(WMScreen * scr, _Panel * panel, const char *file)
{
	pid_t pid;

	pid = fork();
	if (pid < 0) {
		werror("could not fork() process");

		WMRunAlertPanel(scr, GetWindow(), _("Error"),
				"Could not start download. fork() failed", _("OK"), NULL, NULL);
		return -1;
	}
	if (pid != 0) {
		return pid;
	}

	close(ConnectionNumber(WMScreenDisplay(scr)));

	exit(1);
}

static void downloadCallback(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	pid_t newPid;
	WMButton *button = (WMButton *) w;
	pid_t *pid;

	if (button == panel->totB) {
		pid = &panel->tilePID;
	} else {
		pid = &panel->barPID;
	}

	if (*pid == 0) {
		newPid = downloadFile(WMWidgetScreen(w), panel, NULL);
		if (newPid < 0) {
			return;
		}
		WMSetButtonText(button, _("Stop"));

		if (button == panel->totB) {
			AddDeadChildHandler(newPid, finishedTileDownload, data);
		} else {
			AddDeadChildHandler(newPid, finishedBarDownload, data);
		}
		*pid = newPid;
	} else {
		*pid = 0;

		WMSetButtonText(button, _("Download"));
	}
}

static void createPanel(Panel * p)
{
	_Panel *panel = (_Panel *) p;

	panel->box = WMCreateBox(panel->parent);
	WMSetViewExpandsToParent(WMWidgetView(panel->box), 2, 2, 2, 2);

	panel->saveB = WMCreateCommandButton(panel->box);
	WMResizeWidget(panel->saveB, 154, 24);
	WMMoveWidget(panel->saveB, 15, 10);
	WMSetButtonText(panel->saveB, _("Save Current Theme"));

	panel->list = WMCreateList(panel->box);
	WMResizeWidget(panel->list, 154, 150);
	WMMoveWidget(panel->list, 15, 40);

	panel->loadB = WMCreateCommandButton(panel->box);
	WMResizeWidget(panel->loadB, 74, 24);
	WMMoveWidget(panel->loadB, 15, 200);
	WMSetButtonText(panel->loadB, _("Load"));

	panel->instB = WMCreateCommandButton(panel->box);
	WMResizeWidget(panel->instB, 74, 24);
	WMMoveWidget(panel->instB, 95, 200);
	WMSetButtonText(panel->instB, _("Install"));

    /**************** Tile of the day ****************/

	panel->totF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->totF, 210, 105);
	WMMoveWidget(panel->totF, 240, 10);
	WMSetFrameTitle(panel->totF, _("Tile of The Day"));

	panel->totL = WMCreateLabel(panel->totF);
	WMResizeWidget(panel->totL, 67, 67);
	WMMoveWidget(panel->totL, 25, 25);
	WMSetLabelRelief(panel->totL, WRSunken);

	panel->totB = WMCreateCommandButton(panel->totF);
	WMResizeWidget(panel->totB, 86, 24);
	WMMoveWidget(panel->totB, 105, 45);
	WMSetButtonText(panel->totB, _("Download"));
	WMSetButtonAction(panel->totB, downloadCallback, panel);

	WMMapSubwidgets(panel->totF);

    /**************** Bar of the day ****************/

	panel->botF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->botF, 315, 95);
	WMMoveWidget(panel->botF, 190, 125);
	WMSetFrameTitle(panel->botF, _("Bar of The Day"));

	panel->botL = WMCreateLabel(panel->botF);
	WMResizeWidget(panel->botL, 285, 32);
	WMMoveWidget(panel->botL, 15, 20);
	WMSetLabelRelief(panel->botL, WRSunken);

	panel->botB = WMCreateCommandButton(panel->botF);
	WMResizeWidget(panel->botB, 86, 24);
	WMMoveWidget(panel->botB, 110, 60);
	WMSetButtonText(panel->botB, _("Download"));
	WMSetButtonAction(panel->botB, downloadCallback, panel);

	WMMapSubwidgets(panel->botF);

	WMRealizeWidget(panel->box);
	WMMapSubwidgets(panel->box);

	showData(panel);
}

static void storeData(_Panel * panel)
{
}

Panel *InitThemes(WMWidget *parent)
{
	_Panel *panel;

	panel = wmalloc(sizeof(_Panel));

	panel->sectionName = _("Themes");

	panel->parent = parent;

	panel->callbacks.createWidgets = createPanel;
	panel->callbacks.updateDomain = storeData;

	AddSection(panel, ICON_FILE);

	return panel;
}
