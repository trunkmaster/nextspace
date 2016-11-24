/* WindowHandling.c- options for handling windows
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

	WMFrame *placF;
	WMPopUpButton *placP;
	WMLabel *porigL;
	WMLabel *porigvL;
	WMFrame *porigF;
	WMLabel *porigW;

	WMSlider *vsli;
	WMSlider *hsli;

	WMFrame *resF;
	WMSlider *resS;
	WMLabel *resL;
	WMButton *resaB;
	WMButton *resrB;

	WMFrame *maxiF;
	WMLabel *maxiL;
	WMButton *miconB;
	WMButton *mdockB;

	WMFrame *resizeF;
	WMLabel *resizeL;
	WMLabel *resizeTextL;
	WMSlider *resizeS;

	WMFrame *opaqF;
	WMButton *opaqB;
	WMButton *opaqresizeB;
	WMButton *opaqkeybB;

	WMFrame *dragmaxF;
	WMPopUpButton *dragmaxP;
} _Panel;

#define ICON_FILE "whandling"

#define OPAQUE_MOVE_PIXMAP "opaque"

#define NON_OPAQUE_MOVE_PIXMAP "nonopaque"

#define OPAQUE_RESIZE_PIXMAP "opaqueresize"

#define NON_OPAQUE_RESIZE_PIXMAP "noopaqueresize"

#define PLACEMENT_WINDOW_PIXMAP "smallwindow"

#define THUMB_SIZE	16

static const struct {
	const char *db_value;
	const char *label;
} window_placements[] = {
	{ "auto",     N_("Automatic") },
	{ "random",   N_("Random")    },
	{ "manual",   N_("Manual")    },
	{ "cascade",  N_("Cascade")   },
	{ "smart",    N_("Smart")     },
	{ "center",   N_("Center")    }
};

static const struct {
	const char *db_value;
	const char *label;
} drag_maximized_window_options[] = {
	{ "Move",            N_("...changes its position (normal behavior)") },
	{ "RestoreGeometry", N_("...restores its unmaximized geometry")      },
	{ "Unmaximize",      N_("...considers the window now unmaximized")   },
	{ "NoMove",          N_("...does not move the window")               }
};

static void sliderCallback(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int x, y, rx, ry;
	char buffer[64];
	int swidth = WMGetSliderMaxValue(panel->hsli);
	int sheight = WMGetSliderMaxValue(panel->vsli);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	x = WMGetSliderValue(panel->hsli);
	y = WMGetSliderValue(panel->vsli);

	rx = x * (WMWidgetWidth(panel->porigF) - 3) / swidth + 2;
	ry = y * (WMWidgetHeight(panel->porigF) - 3) / sheight + 2;
	WMMoveWidget(panel->porigW, rx, ry);

	sprintf(buffer, "(%i,%i)", x, y);
	WMSetLabelText(panel->porigvL, buffer);
}

static void resistanceCallback(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	char buffer[64];
	int i;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	i = WMGetSliderValue(panel->resS);

	if (i == 0)
		WMSetLabelText(panel->resL, _("OFF"));
	else {
		sprintf(buffer, "%i", i);
		WMSetLabelText(panel->resL, buffer);
	}
}

static void resizeCallback(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	char buffer[64];
	int i;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	i = WMGetSliderValue(panel->resizeS);

	if (i == 0)
		WMSetLabelText(panel->resizeL, _("OFF"));
	else {
		sprintf(buffer, "%i", i);
		WMSetLabelText(panel->resizeL, buffer);
	}
}

static int getPlacement(const char *str)
{
	int i;

	if (!str)
		return 0;

	for (i = 0; i < wlengthof(window_placements); i++) {
		if (strcasecmp(str, window_placements[i].db_value) == 0)
			return i;
	}

	wwarning(_("bad option value %s in WindowPlacement. Using default value"), str);
	return 0;
}

static int getDragMaximizedWindow(const char *str)
{
	int i;

	if (!str)
		return 0;

	for (i = 0; i < wlengthof(drag_maximized_window_options); i++) {
		if (strcasecmp(str, drag_maximized_window_options[i].db_value) == 0)
			return i;
	}

	wwarning(_("bad option value %s in WindowPlacement. Using default value"), str);
	return 0;
}


static void showData(_Panel * panel)
{
	char *str;
	WMPropList *arr;
	int x, y;

	str = GetStringForKey("WindowPlacement");

	WMSetPopUpButtonSelectedItem(panel->placP, getPlacement(str));

	arr = GetObjectForKey("WindowPlaceOrigin");

	x = 0;
	y = 0;
	if (arr && (!WMIsPLArray(arr) || WMGetPropListItemCount(arr) != 2)) {
		wwarning(_("invalid data in option WindowPlaceOrigin. Using default (0,0)"));
	} else {
		if (arr) {
			x = atoi(WMGetFromPLString(WMGetFromPLArray(arr, 0)));
			y = atoi(WMGetFromPLString(WMGetFromPLArray(arr, 1)));
		}
	}

	WMSetSliderValue(panel->hsli, x);
	WMSetSliderValue(panel->vsli, y);

	sliderCallback(NULL, panel);

	x = GetIntegerForKey("EdgeResistance");
	WMSetSliderValue(panel->resS, x);
	resistanceCallback(NULL, panel);

	str = GetStringForKey("DragMaximizedWindow");
	WMSetPopUpButtonSelectedItem(panel->dragmaxP, getDragMaximizedWindow(str));

	x = GetIntegerForKey("ResizeIncrement");
	WMSetSliderValue(panel->resizeS, x);
	resizeCallback(NULL, panel);

	WMSetButtonSelected(panel->opaqB, GetBoolForKey("OpaqueMove"));
	WMSetButtonSelected(panel->opaqresizeB, GetBoolForKey("OpaqueResize"));
	WMSetButtonSelected(panel->opaqkeybB, GetBoolForKey("OpaqueMoveResizeKeyboard"));

	WMSetButtonSelected(panel->miconB, GetBoolForKey("NoWindowOverIcons"));
	WMSetButtonSelected(panel->mdockB, GetBoolForKey("NoWindowOverDock"));

	if (GetBoolForKey("Attraction"))
		WMPerformButtonClick(panel->resrB);
	else
		WMPerformButtonClick(panel->resaB);
}

static void storeData(_Panel * panel)
{
	WMPropList *arr;
	WMPropList *x, *y;
	char buf[16];

	SetBoolForKey(WMGetButtonSelected(panel->miconB), "NoWindowOverIcons");
	SetBoolForKey(WMGetButtonSelected(panel->mdockB), "NoWindowOverDock");

	SetBoolForKey(WMGetButtonSelected(panel->opaqB), "OpaqueMove");
	SetBoolForKey(WMGetButtonSelected(panel->opaqresizeB), "OpaqueResize");
	SetBoolForKey(WMGetButtonSelected(panel->opaqkeybB), "OpaqueMoveResizeKeyboard");

	SetStringForKey(window_placements[WMGetPopUpButtonSelectedItem(panel->placP)].db_value, "WindowPlacement");
	sprintf(buf, "%i", WMGetSliderValue(panel->hsli));
	x = WMCreatePLString(buf);
	sprintf(buf, "%i", WMGetSliderValue(panel->vsli));
	y = WMCreatePLString(buf);
	arr = WMCreatePLArray(x, y, NULL);
	WMReleasePropList(x);
	WMReleasePropList(y);
	SetObjectForKey(arr, "WindowPlaceOrigin");

	SetIntegerForKey(WMGetSliderValue(panel->resS), "EdgeResistance");

	SetStringForKey(drag_maximized_window_options[WMGetPopUpButtonSelectedItem(panel->dragmaxP)].db_value,
	                "DragMaximizedWindow");

	SetIntegerForKey(WMGetSliderValue(panel->resizeS), "ResizeIncrement");
	SetBoolForKey(WMGetButtonSelected(panel->resrB), "Attraction");

	WMReleasePropList(arr);
}

static void createPanel(Panel * p)
{
	_Panel *panel = (Panel *) p;
	WMScreen *scr = WMWidgetScreen(panel->parent);
	WMColor *color;
	WMPixmap *pixmap;
	int width, height;
	int swidth, sheight;
	char *path;
	WMBox *hbox;
	int i;

	panel->box = WMCreateBox(panel->parent);
	WMSetViewExpandsToParent(WMWidgetView(panel->box), 2, 2, 2, 2);
	WMSetBoxHorizontal(panel->box, False);
	WMSetBoxBorderWidth(panel->box, 8);

	hbox = WMCreateBox(panel->box);
	WMSetBoxHorizontal(hbox, True);
	WMAddBoxSubview(panel->box, WMWidgetView(hbox), False, True, 110, 0, 10);

    /************** Window Placement ***************/
	panel->placF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->placF, 222, 163);
	WMMoveWidget(panel->placF, 8, 6);
	WMSetFrameTitle(panel->placF, _("Window Placement"));
	WMSetBalloonTextForView(_("How to place windows when they are first put\n"
				  "on screen."), WMWidgetView(panel->placF));

	panel->placP = WMCreatePopUpButton(panel->placF);
	WMResizeWidget(panel->placP, 90, 20);
	WMMoveWidget(panel->placP, 9, 19);

	for (i = 0; i < wlengthof(window_placements); i++)
		WMAddPopUpButtonItem(panel->placP, _(window_placements[i].label));

	panel->porigL = WMCreateLabel(panel->placF);
	WMResizeWidget(panel->porigL, 50, 20);
	WMMoveWidget(panel->porigL, 100, 19);
	WMSetLabelTextAlignment(panel->porigL, WARight);
	WMSetLabelText(panel->porigL, _("Origin:"));

	panel->porigvL = WMCreateLabel(panel->placF);
	WMResizeWidget(panel->porigvL, 69, 20);
	WMMoveWidget(panel->porigvL, 150, 19);
	WMSetLabelTextAlignment(panel->porigvL, WACenter);

	color = WMCreateRGBColor(scr, 0x5100, 0x5100, 0x7100, True);
	panel->porigF = WMCreateFrame(panel->placF);
	WMSetWidgetBackgroundColor(panel->porigF, color);
	WMReleaseColor(color);
	WMSetFrameRelief(panel->porigF, WRSunken);

	/*
	 * There is an available area of 204 x 109, starting at x=9 y=45
	 * We have to keep 12 pixels in each direction for the sliders,
	 * and an extra pixel for spacing.
	 * In this area, we want to have a rectangle with the same aspect
	 * ratio as the screen.
	 */
	swidth = WidthOfScreen(DefaultScreenOfDisplay(WMScreenDisplay(scr)));
	sheight = HeightOfScreen(DefaultScreenOfDisplay(WMScreenDisplay(scr)));

	width = swidth * (109 - 13) / sheight;
	if (width <= (204 - 13)) {
		height = 109 - 13;
	} else {
		width = 204 - 13;
		height = sheight * (204 - 13) / swidth;
	}
	WMResizeWidget(panel->porigF, width, height);
	WMMoveWidget(panel->porigF, 9 + (204 - 13 - width) / 2, 45 + (109 - 13 - height) / 2);

	panel->porigW = WMCreateLabel(panel->porigF);
	WMMoveWidget(panel->porigW, 2, 2);
	path = LocateImage(PLACEMENT_WINDOW_PIXMAP);
	if (path) {
		pixmap = WMCreatePixmapFromFile(scr, path);
		if (pixmap) {
			WMSize size;

			WMSetLabelImagePosition(panel->porigW, WIPImageOnly);
			size = WMGetPixmapSize(pixmap);
			WMSetLabelImage(panel->porigW, pixmap);
			WMResizeWidget(panel->porigW, size.width, size.height);
			WMReleasePixmap(pixmap);
		} else {
			wwarning(_("could not load icon %s"), path);
		}
		wfree(path);
		if (!pixmap)
			goto use_old_window_representation;
	} else {
	use_old_window_representation:
		WMResizeWidget(panel->porigW, THUMB_SIZE, THUMB_SIZE);
		WMSetLabelRelief(panel->porigW, WRRaised);
	}

	panel->hsli = WMCreateSlider(panel->placF);
	WMResizeWidget(panel->hsli, width, 12);
	WMMoveWidget(panel->hsli, 9 + (204 - 13 - width) / 2, 45 + (109 - 13 - height) / 2 + height + 1);
	WMSetSliderAction(panel->hsli, sliderCallback, panel);
	WMSetSliderMinValue(panel->hsli, 0);
	WMSetSliderMaxValue(panel->hsli, swidth);

	panel->vsli = WMCreateSlider(panel->placF);
	WMResizeWidget(panel->vsli, 12, height);
	WMMoveWidget(panel->vsli, 9 + (204 - 13 - width) / 2 + width + 1, 45 + (109 - 13 - height) / 2);
	WMSetSliderAction(panel->vsli, sliderCallback, panel);
	WMSetSliderMinValue(panel->vsli, 0);
	WMSetSliderMaxValue(panel->vsli, sheight);

	WMMapSubwidgets(panel->porigF);

	WMMapSubwidgets(panel->placF);

    /************** Opaque Move, Resize ***************/
	panel->opaqF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->opaqF, 140, 118);
	WMMoveWidget(panel->opaqF, 372, 103);

	WMSetFrameTitle(panel->opaqF, _("Opaque Move/Resize"));
	WMSetBalloonTextForView(_("Whether the window contents or only a frame should\n"
				  "be displayed during a move or resize.\n"),
				WMWidgetView(panel->opaqF));

	panel->opaqB = WMCreateButton(panel->opaqF, WBTToggle);
	WMResizeWidget(panel->opaqB, 54, 54);
	WMMoveWidget(panel->opaqB, 11, 22);
	WMSetButtonImagePosition(panel->opaqB, WIPImageOnly);

	path = LocateImage(NON_OPAQUE_MOVE_PIXMAP);
	if (path) {
		pixmap = WMCreatePixmapFromFile(scr, path);
		if (pixmap) {
			WMSetButtonImage(panel->opaqB, pixmap);
			WMReleasePixmap(pixmap);
		} else {
			wwarning(_("could not load icon %s"), path);
		}
		wfree(path);
	}

	path = LocateImage(OPAQUE_MOVE_PIXMAP);
	if (path) {
		pixmap = WMCreatePixmapFromFile(scr, path);
		if (pixmap) {
			WMSetButtonAltImage(panel->opaqB, pixmap);
			WMReleasePixmap(pixmap);
		} else {
			wwarning(_("could not load icon %s"), path);
		}
		wfree(path);
	}



	panel->opaqresizeB = WMCreateButton(panel->opaqF, WBTToggle);
	WMResizeWidget(panel->opaqresizeB, 54, 54);
	WMMoveWidget(panel->opaqresizeB, 75, 22);
	WMSetButtonImagePosition(panel->opaqresizeB, WIPImageOnly);

	path = LocateImage(NON_OPAQUE_RESIZE_PIXMAP);
	if (path) {
		pixmap = WMCreatePixmapFromFile(scr, path);
		if (pixmap) {
			WMSetButtonImage(panel->opaqresizeB, pixmap);
			WMReleasePixmap(pixmap);
		} else {
			wwarning(_("could not load icon %s"), path);
		}
		wfree(path);
	}

	path = LocateImage(OPAQUE_RESIZE_PIXMAP);
	if (path) {
		pixmap = WMCreatePixmapFromFile(scr, path);
		if (pixmap) {
			WMSetButtonAltImage(panel->opaqresizeB, pixmap);
			WMReleasePixmap(pixmap);
		} else {
			wwarning(_("could not load icon %s"), path);
		}
		wfree(path);
	}

	panel->opaqkeybB = WMCreateSwitchButton(panel->opaqF);
	WMResizeWidget(panel->opaqkeybB, 122, 25);
	WMMoveWidget(panel->opaqkeybB, 11, 85);
	WMSetButtonText(panel->opaqkeybB, _("by keyboard"));

	WMSetBalloonTextForView(_("When selected, moving or resizing windows\n"
				  "using keyboard shortcuts will also display its\n"
				  "content instead of just a frame."), WMWidgetView(panel->opaqkeybB));

	WMMapSubwidgets(panel->opaqF);


    /**************** Account for Icon/Dock ***************/
	panel->maxiF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->maxiF, 140, 92);
	WMMoveWidget(panel->maxiF, 372, 6);
	WMSetFrameTitle(panel->maxiF, _("When maximizing..."));

	panel->maxiL = WMCreateLabel(panel->maxiF);
	WMSetLabelText(panel->maxiL, _("...do not cover:"));
	WMResizeWidget(panel->maxiL, 120, 20);
	WMMoveWidget(panel->maxiL, 10, 16);

	panel->miconB = WMCreateSwitchButton(panel->maxiF);
	WMResizeWidget(panel->miconB, 120, 25);
	WMMoveWidget(panel->miconB, 10, 36);
	WMSetButtonText(panel->miconB, _("Icons"));

	panel->mdockB = WMCreateSwitchButton(panel->maxiF);
	WMResizeWidget(panel->mdockB, 120, 25);
	WMMoveWidget(panel->mdockB, 10, 61);
	WMSetButtonText(panel->mdockB, _("The dock"));

	WMMapSubwidgets(panel->maxiF);

    /**************** Resize with Mod+Wheel ***************/
	panel->resizeF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->resizeF, 127, 66);
	WMMoveWidget(panel->resizeF, 238, 103);
	WMSetFrameTitle(panel->resizeF, _("Mod+Wheel"));

	panel->resizeTextL = WMCreateLabel(panel->resizeF);
	WMSetLabelText(panel->resizeTextL, _("Resize increment:"));
	WMResizeWidget(panel->resizeTextL, 118, 20);
	WMMoveWidget(panel->resizeTextL, 5, 16);

	panel->resizeS = WMCreateSlider(panel->resizeF);
	WMResizeWidget(panel->resizeS, 80, 15);
	WMMoveWidget(panel->resizeS, 9, 40);
	WMSetSliderMinValue(panel->resizeS, 0);
	WMSetSliderMaxValue(panel->resizeS, 100);
	WMSetSliderAction(panel->resizeS, resizeCallback, panel);

	panel->resizeL = WMCreateLabel(panel->resizeF);
	WMResizeWidget(panel->resizeL, 30, 15);
	WMMoveWidget(panel->resizeL, 90, 40);

	WMMapSubwidgets(panel->resizeF);

    /**************** Edge Resistance  ****************/
	panel->resF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->resF, 127, 92);
	WMMoveWidget(panel->resF, 238, 6);
	WMSetFrameTitle(panel->resF, _("Edge Resistance"));

	WMSetBalloonTextForView(_("Edge resistance will make windows `resist'\n"
				  "being moved further for the defined threshold\n"
				  "when moved against other windows or the edges\n"
				  "of the screen."), WMWidgetView(panel->resF));

	panel->resS = WMCreateSlider(panel->resF);
	WMResizeWidget(panel->resS, 80, 15);
	WMMoveWidget(panel->resS, 9, 20);
	WMSetSliderMinValue(panel->resS, 0);
	WMSetSliderMaxValue(panel->resS, 80);
	WMSetSliderAction(panel->resS, resistanceCallback, panel);

	panel->resL = WMCreateLabel(panel->resF);
	WMResizeWidget(panel->resL, 30, 15);
	WMMoveWidget(panel->resL, 90, 22);

	panel->resaB = WMCreateRadioButton(panel->resF);
	WMMoveWidget(panel->resaB, 9, 39);
	WMResizeWidget(panel->resaB, 107, 23);
	WMSetButtonText(panel->resaB, _("Resist"));

	panel->resrB = WMCreateRadioButton(panel->resF);
	WMMoveWidget(panel->resrB, 9, 62);
	WMResizeWidget(panel->resrB, 107, 23);
	WMSetButtonText(panel->resrB, _("Attract"));
	WMGroupButtons(panel->resrB, panel->resaB);

	WMMapSubwidgets(panel->resF);

    /**************** Dragging a Maximized Window ****************/
	panel->dragmaxF = WMCreateFrame(panel->box);
	WMResizeWidget(panel->dragmaxF, 357, 49);
	WMMoveWidget(panel->dragmaxF, 8, 172);
	WMSetFrameTitle(panel->dragmaxF, _("Dragging a maximized window..."));

	panel->dragmaxP = WMCreatePopUpButton(panel->dragmaxF);
	WMResizeWidget(panel->dragmaxP, 328, 20);
	WMMoveWidget(panel->dragmaxP, 15, 18);

	for (i = 0; i < wlengthof(drag_maximized_window_options); i++)
		WMAddPopUpButtonItem(panel->dragmaxP, _(drag_maximized_window_options[i].label));

	WMMapSubwidgets(panel->dragmaxF);

	WMRealizeWidget(panel->box);
	WMMapSubwidgets(panel->box);

	/* show the config data */
	showData(panel);
}

static void undo(_Panel * panel)
{
	showData(panel);
}

Panel *InitWindowHandling(WMWidget *parent)
{
	_Panel *panel;

	panel = wmalloc(sizeof(_Panel));

	panel->sectionName = _("Window Handling Preferences");

	panel->description = _("Window handling options. Initial placement style\n"
			       "edge resistance, opaque move etc.");

	panel->parent = parent;

	panel->callbacks.createWidgets = createPanel;
	panel->callbacks.updateDomain = storeData;
	panel->callbacks.undoChanges = undo;

	AddSection(panel, ICON_FILE);

	return panel;
}
