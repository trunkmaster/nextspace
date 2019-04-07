/*  wsmap.c - worskpace map
 *
 *  Window Maker window manager
 *
 *  Copyright (c) 2014 Window Maker Team - David Maciejak
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

#include <stdlib.h>
#include <stdio.h>

#ifdef USE_XSHAPE
#include <X11/extensions/shape.h>
#endif

#include "screen.h"
#include "window.h"
#include "misc.h"
#include "workspace.h"
#include "wsmap.h"

#include "WINGs/WINGsP.h"


static const int WORKSPACE_MAP_RATIO  = 10;
static const int WORKSPACE_SEPARATOR_WIDTH = 12;
static const int mini_workspace_per_line = 5;

/*
 * Used to store the index of the tenth displayed mini workspace
 * will be 0 for workspaces number 0 to 9
 * 1 for workspaces number 10 -> 19
 */
static int wsmap_bulk_index;
static WMPixmap *frame_bg_focused;
static WMPixmap *frame_bg_unfocused;

typedef struct {
	WScreen *scr;
	WMWindow *win;
	int xcount, ycount;
	int wswidth, wsheight;
	int mini_workspace_width, mini_workspace_height;
	int edge;
	int border_width;
} WWorkspaceMap;

typedef struct {
	WMButton *workspace_img_button;
	WMLabel *workspace_label;
} W_WorkspaceMap;

void wWorkspaceMapUpdate(WScreen *scr)
{
	XImage *pimg;

	pimg = XGetImage(dpy, scr->root_win, 0, 0,
	                 scr->scr_width, scr->scr_height,
	                 AllPlanes, ZPixmap);
	if (pimg) {
		RImage *mini_preview;

		mini_preview = RCreateImageFromXImage(scr->rcontext, pimg, NULL);
		XDestroyImage(pimg);

		if (mini_preview) {
			RImage *tmp = scr->workspaces[scr->current_workspace]->map;

			if (tmp)
				RReleaseImage(tmp);

			scr->workspaces[scr->current_workspace]->map =
				RSmoothScaleImage(mini_preview,
				                  scr->scr_width / WORKSPACE_MAP_RATIO,
				                  scr->scr_height / WORKSPACE_MAP_RATIO);
			RReleaseImage(mini_preview);
		}
	}
}

static void workspace_map_slide(WWorkspaceMap *wsmap)
{
	if (wsmap->edge == WD_TOP)
		slide_window(WMWidgetXID(wsmap->win), 0, -1 * wsmap->wsheight, wsmap->xcount, wsmap->ycount);
	else
		slide_window(WMWidgetXID(wsmap->win), 0, wsmap->scr->scr_height, wsmap->xcount, wsmap->ycount);
}

static void workspace_map_unslide(WWorkspaceMap *wsmap)
{
	if (wsmap->edge == WD_TOP)
		slide_window(WMWidgetXID(wsmap->win), wsmap->xcount, wsmap->ycount, 0, -1 * wsmap->wsheight);
	else
		slide_window(WMWidgetXID(wsmap->win), wsmap->xcount, wsmap->ycount, 0, wsmap->scr->scr_height);
}

static void workspace_map_destroy(WWorkspaceMap *wsmap)
{
	workspace_map_unslide(wsmap);
	WMUnmapWidget(wsmap->win);

	if (wsmap->win) {
		Window info_win = wsmap->scr->info_window;
		XEvent ev;

		ev.xclient.type = ClientMessage;
		ev.xclient.message_type = w_global.atom.wm.ignore_focus_events;
		ev.xclient.format = 32;
		ev.xclient.data.l[0] = True;

		XSendEvent(dpy, info_win, True, EnterWindowMask, &ev);
		WMUnmapWidget(wsmap->win);

		ev.xclient.data.l[0] = False;
		XSendEvent(dpy, info_win, True, EnterWindowMask, &ev);
		WMDestroyWidget(wsmap->win);

		if (frame_bg_focused)
			WMReleasePixmap(frame_bg_focused);
		if (frame_bg_unfocused)
			WMReleasePixmap(frame_bg_unfocused);
	}
	wfree(wsmap);
}

static void selected_workspace_callback(WMWidget *w, void *data)
{
	WWorkspaceMap *wsmap = (WWorkspaceMap *) data;
	WMButton *click_button = w;

	if (w && wsmap) {
		int workspace_id = atoi(WMGetButtonText(click_button));

		wWorkspaceChange(wsmap->scr, workspace_id);
		w_global.process_workspacemap_event = False;
	}
}

static void set_workspace_map_background_image(WWorkspaceMap *wsmap)
{
	Pixmap pixmap, mask;

	if (wPreferences.wsmbackTexture->any.type == WTEX_PIXMAP) {
		RImage *tmp = wTextureRenderImage(wPreferences.wsmbackTexture, wsmap->wswidth, wsmap->wsheight, WREL_FLAT);

		if (!tmp)
			return;

		RConvertImageMask(wsmap->scr->rcontext, tmp, &pixmap, &mask, 250);
		RReleaseImage(tmp);

		if (!pixmap)
			return;

		XSetWindowBackgroundPixmap(dpy, WMWidgetXID(wsmap->win), pixmap);

#ifdef USE_XSHAPE
		if (mask && w_global.xext.shape.supported)
			XShapeCombineMask(dpy, WMWidgetXID(wsmap->win), ShapeBounding, 0, 0, mask, ShapeSet);
#endif

		if (pixmap)
			XFreePixmap(dpy, pixmap);
		if (mask)
			XFreePixmap(dpy, mask);
	}
}

static void workspace_map_show(WWorkspaceMap *wsmap)
{
	WMMapSubwidgets(wsmap->win);
	WMMapWidget(wsmap->win);
	workspace_map_slide(wsmap);
}

static WMPixmap *get_frame_background_color(WWorkspaceMap *wsmap, unsigned int width, unsigned int height, int type)
{
	RImage *img;
	WMPixmap *pix;

	if (!wsmap->scr->window_title_texture[type])
		return NULL;

	img = wTextureRenderImage(wsmap->scr->window_title_texture[type], width, height, WREL_FLAT);
	if (!img)
		return NULL;

	pix = WMCreatePixmapFromRImage(wsmap->scr->wmscreen, img, 128);
	RReleaseImage(img);

	return pix;
}

static void workspace_map_realize(WWorkspaceMap *wsmap, WMFrame *frame_border, W_WorkspaceMap *wsmap_array)
{
	int i, mini_workspace_cnt, general_index;
	WMPixmap *frame_border_pixmap;
	WMSize label_size;

	WMRealizeWidget(wsmap->win);
	set_workspace_map_background_image(wsmap);

	frame_border_pixmap = get_frame_background_color(wsmap, wsmap->wswidth, wsmap->border_width, WS_FOCUSED);
	WMSetWidgetBackgroundPixmap(frame_border, frame_border_pixmap);
	WMReleasePixmap(frame_border_pixmap);

	label_size = WMGetViewSize(W_VIEW(wsmap_array[0].workspace_label));
	frame_bg_focused = get_frame_background_color(wsmap, label_size.width, label_size.height, WS_FOCUSED);
	frame_bg_unfocused = get_frame_background_color(wsmap, label_size.width, label_size.height, WS_UNFOCUSED);

	mini_workspace_cnt = (wsmap->scr->workspace_count <= 2 * mini_workspace_per_line) ? wsmap->scr->workspace_count : 2 * mini_workspace_per_line;
	for (i = 0; i < mini_workspace_cnt; i++) {
		general_index = i + wsmap_bulk_index * 2 * mini_workspace_per_line;
		if (general_index == wsmap->scr->current_workspace) {
			WMSetWidgetBackgroundPixmap(wsmap_array[i].workspace_label, frame_bg_focused);
			WMSetLabelTextColor(wsmap_array[i].workspace_label, wsmap->scr->window_title_color[WS_FOCUSED]);
		} else {
			WMSetWidgetBackgroundPixmap(wsmap_array[i].workspace_label, frame_bg_unfocused);
			WMSetLabelTextColor(wsmap_array[i].workspace_label, wsmap->scr->window_title_color[WS_UNFOCUSED]);
		}
	}
}

static WMPixmap *enlight_workspace(WScreen *scr, RImage *mini_wkspace_map)
{
	RImage *tmp = RCloneImage(mini_wkspace_map);
	RColor color;
	WMPixmap *icon;

	color.red = color.green = color.blue = 0;
	color.alpha = 160;
	RLightImage(tmp, &color);
	icon = WMCreatePixmapFromRImage(scr->wmscreen, tmp, 128);
	RReleaseImage(tmp);

	return icon;
}

static WMPixmap *dummy_background_pixmap(WWorkspaceMap *wsmap)
{
	RImage *img;
	WMPixmap *icon;

	img = RCreateImage(wsmap->wswidth, wsmap->wsheight, 0);

	if (!img)
		return NULL;

	/* the workspace texture is not saved anywhere, so just using the default unfocus color */
	if (wsmap->scr->window_title_texture[WS_UNFOCUSED]) {
		RColor frame_bg_color;

		frame_bg_color.red = wsmap->scr->window_title_texture[WS_UNFOCUSED]->solid.normal.red;
		frame_bg_color.green = wsmap->scr->window_title_texture[WS_UNFOCUSED]->solid.normal.green;
		frame_bg_color.blue = wsmap->scr->window_title_texture[WS_UNFOCUSED]->solid.normal.blue;
		RFillImage(img, &frame_bg_color);
	}

	icon = WMCreatePixmapFromRImage(wsmap->scr->wmscreen, img, 128);
	RReleaseImage(img);

	return icon;
}

static void show_mini_workspace(WWorkspaceMap *wsmap, W_WorkspaceMap *wsmap_array, int max_mini_workspace)
{
	int index, space_width;
	int border_width_adjustement = (wsmap->edge == WD_TOP) ? 0 : wsmap->border_width;
	int font_height = WMFontHeight(wsmap->scr->info_text_font);

	if (max_mini_workspace > mini_workspace_per_line)
		space_width = (wsmap->wswidth - mini_workspace_per_line * wsmap->mini_workspace_width) / (mini_workspace_per_line + 1);
	else
		space_width = (wsmap->wswidth - max_mini_workspace * wsmap->mini_workspace_width) / (max_mini_workspace + 1);

	for (index = 0; index <  max_mini_workspace; index++) {
		int i , j;

		j = index;

		if (index >= mini_workspace_per_line) {
			i = 1;
			j -= mini_workspace_per_line;
		} else {
			i = 0;
		}
		if (wsmap_array[index].workspace_img_button) {
			WMResizeWidget(wsmap_array[index].workspace_img_button, wsmap->mini_workspace_width, wsmap->mini_workspace_height);
			WMMoveWidget(wsmap_array[index].workspace_img_button, j * wsmap->mini_workspace_width + (j + 1) * space_width,
			             border_width_adjustement + WORKSPACE_SEPARATOR_WIDTH +
			             i * (wsmap->mini_workspace_height + 2 * WORKSPACE_SEPARATOR_WIDTH) + font_height);
			WMMapWidget(wsmap_array[index].workspace_img_button);
		}
		if (wsmap_array[index].workspace_label) {
			WMResizeWidget(wsmap_array[index].workspace_label, wsmap->mini_workspace_width, font_height);
			WMMoveWidget(wsmap_array[index].workspace_label, j * wsmap->mini_workspace_width + (j + 1) * space_width,
			             border_width_adjustement + WORKSPACE_SEPARATOR_WIDTH +
			             i * (wsmap->mini_workspace_height + 2 * WORKSPACE_SEPARATOR_WIDTH));
			WMMapWidget(wsmap_array[index].workspace_label);
		}
	}
}

static void hide_mini_workspace(W_WorkspaceMap *wsmap_array, int i)
{
	if (wsmap_array[i].workspace_img_button)
		WMUnmapWidget(wsmap_array[i].workspace_img_button);
	if (wsmap_array[i].workspace_label)
		WMUnmapWidget(wsmap_array[i].workspace_label);
}

static  WMPixmap *get_mini_workspace(WWorkspaceMap *wsmap, int index)
{
	if (!wsmap->scr->workspaces[index]->map)
		return dummy_background_pixmap(wsmap);

	if (index == wsmap->scr->current_workspace)
		return enlight_workspace(wsmap->scr, wsmap->scr->workspaces[index]->map);

	return WMCreatePixmapFromRImage(wsmap->scr->wmscreen, wsmap->scr->workspaces[index]->map, 128);
}

static void create_mini_workspace(WScreen *scr, WWorkspaceMap *wsmap, W_WorkspaceMap *wsmap_array)
{
	int workspace_index;
	int mini_workspace_cnt;
	char name[10];
	WMButton *mini_workspace_btn;
	WMPixmap *icon;

	/* by default display the 10 first mini workspaces */
	wsmap_bulk_index = 0;
	mini_workspace_cnt = (scr->workspace_count <= 2 * mini_workspace_per_line) ? scr->workspace_count : 2 * mini_workspace_per_line;
	for (workspace_index = 0; workspace_index < mini_workspace_cnt; workspace_index++) {
		mini_workspace_btn = WMCreateButton(wsmap->win, WBTOnOff);
		WMSetButtonBordered(mini_workspace_btn, 0);
		WMLabel *workspace_name_label =	WMCreateLabel(wsmap->win);
		WMSetLabelFont(workspace_name_label, scr->info_text_font);
		WMSetLabelText(workspace_name_label,  scr->workspaces[workspace_index]->name);

		wsmap_array[workspace_index].workspace_img_button = mini_workspace_btn;
		wsmap_array[workspace_index].workspace_label = workspace_name_label;

		WMSetButtonImagePosition(mini_workspace_btn, WIPImageOnly);
		icon = get_mini_workspace(wsmap, workspace_index);
		if (icon) {
			WMSetButtonImage(mini_workspace_btn, icon);
			WMReleasePixmap(icon);
		}

		snprintf(name, sizeof(name), "%d", workspace_index);
		WMSetButtonText(mini_workspace_btn, name);
		WMSetButtonAction(mini_workspace_btn, selected_workspace_callback, wsmap);
	}
	show_mini_workspace(wsmap, wsmap_array, mini_workspace_cnt);
}

static WWorkspaceMap *create_workspace_map(WScreen *scr, W_WorkspaceMap *wsmap_array, int edge)
{
	WWorkspaceMap *wsmap;

	if (scr->workspace_count == 0)
		return NULL;

	wsmap = wmalloc(sizeof(*wsmap));

	wsmap->border_width = 5;
	wsmap->edge = edge;
	wsmap->mini_workspace_width = scr->scr_width / WORKSPACE_MAP_RATIO;
	wsmap->mini_workspace_height = scr->scr_height / WORKSPACE_MAP_RATIO;

	wsmap->scr = scr;
	wsmap->win = WMCreateWindow(scr->wmscreen, "wsmap");
	wsmap->wswidth = WidthOfScreen(DefaultScreenOfDisplay(dpy));
	wsmap->wsheight = WMFontHeight(scr->info_text_font) + (wsmap->mini_workspace_height + 2 * WORKSPACE_SEPARATOR_WIDTH) *
								(scr->workspace_count > mini_workspace_per_line ? 2 : 1);

	if (wPreferences.wsmbackTexture->any.type == WTEX_SOLID) {
		WMColor *tmp = WMCreateRGBColor(scr->wmscreen,
							wPreferences.wsmbackTexture->any.color.red,
							wPreferences.wsmbackTexture->any.color.green,
							wPreferences.wsmbackTexture->any.color.blue,
							False);
		WMSetWidgetBackgroundColor(wsmap->win, tmp);
		WMReleaseColor(tmp);
	}
	WMResizeWidget(wsmap->win, wsmap->wswidth, wsmap->wsheight + wsmap->border_width);

	WMFrame *framel = WMCreateFrame(wsmap->win);
	WMResizeWidget(framel, wsmap->wswidth, wsmap->border_width);
	WMSetFrameRelief(framel, WRSimple);
	wWorkspaceMapUpdate(scr);

	wsmap->xcount = 0;
	if (edge == WD_TOP) {
		wsmap->ycount = 0;
		WMMoveWidget(framel, 0, wsmap->wsheight);
	} else {
		wsmap->ycount = scr->scr_height - wsmap->wsheight - wsmap->border_width;
		WMMoveWidget(framel, 0, 0);
	}

	create_mini_workspace(scr, wsmap, wsmap_array);
	workspace_map_realize(wsmap, framel, wsmap_array);

	return wsmap;
}

static void update_mini_workspace(WWorkspaceMap *wsmap, W_WorkspaceMap *wsmap_array, int bulk_of_ten)
{
	int local_index, general_index;
	int mini_workspace_cnt;
	char name[10];
	WMPixmap *icon;

	if (bulk_of_ten == wsmap_bulk_index)
		return;

	if (bulk_of_ten < 0)
		return;

	if (wsmap->scr->workspace_count <= bulk_of_ten * 2 * mini_workspace_per_line)
		return;

	wsmap_bulk_index = bulk_of_ten;

	mini_workspace_cnt = wsmap->scr->workspace_count - wsmap_bulk_index * 2 * mini_workspace_per_line;
	if (mini_workspace_cnt > 2 * mini_workspace_per_line)
		mini_workspace_cnt = 2 * mini_workspace_per_line;

	for (local_index = 0; local_index <  2 * mini_workspace_per_line; local_index++) {
		general_index = local_index + wsmap_bulk_index * 2 * mini_workspace_per_line;
		if (general_index < wsmap->scr->workspace_count) {
			/* updating label */
			WMSetLabelText(wsmap_array[local_index].workspace_label, wsmap->scr->workspaces[general_index]->name);
			snprintf(name, sizeof(name), "%d", general_index);
			WMSetButtonText(wsmap_array[local_index].workspace_img_button, name);

			/* updating label background*/
			if (general_index == wsmap->scr->current_workspace) {
				WMSetWidgetBackgroundPixmap(wsmap_array[local_index].workspace_label, frame_bg_focused);
				WMSetLabelTextColor(wsmap_array[local_index].workspace_label, wsmap->scr->window_title_color[WS_FOCUSED]);
			} else {
				WMSetWidgetBackgroundPixmap(wsmap_array[local_index].workspace_label, frame_bg_unfocused);
				WMSetLabelTextColor(wsmap_array[local_index].workspace_label, wsmap->scr->window_title_color[WS_UNFOCUSED]);
			}

			icon = get_mini_workspace(wsmap, general_index);
			if (icon) {
				WMSetButtonImage(wsmap_array[local_index].workspace_img_button, icon);
				WMReleasePixmap(icon);
			}
		} else {
			if (local_index < wsmap->scr->workspace_count)
				hide_mini_workspace(wsmap_array, local_index);
		}
	}
	show_mini_workspace(wsmap, wsmap_array, mini_workspace_cnt);
}

static void handle_event(WWorkspaceMap *wsmap, W_WorkspaceMap *wsmap_array)
{
	XEvent ev;
	int modifiers;
	KeyCode escKey = XKeysymToKeycode(dpy, XK_Escape);

	XGrabKeyboard(dpy, WMWidgetXID(wsmap->win), False, GrabModeAsync, GrabModeAsync, CurrentTime);
	XGrabPointer(dpy, WMWidgetXID(wsmap->win), True,
	             ButtonMotionMask | ButtonReleaseMask | ButtonPressMask,
	             GrabModeAsync, GrabModeAsync, WMWidgetXID(wsmap->win), None, CurrentTime);

	w_global.process_workspacemap_event = True;
	while (w_global.process_workspacemap_event) {
		WMMaskEvent(dpy, KeyPressMask | KeyReleaseMask | ExposureMask
		            | PointerMotionMask | ButtonPressMask | ButtonReleaseMask | EnterWindowMask, &ev);

		modifiers = ev.xkey.state & w_global.shortcut.modifiers_mask;

		switch (ev.type) {
		case KeyPress:
			if (ev.xkey.keycode == escKey || (wKeyBindings[WKBD_WORKSPACEMAP].keycode != 0 &&
			                                  wKeyBindings[WKBD_WORKSPACEMAP].keycode == ev.xkey.keycode &&
			                                  wKeyBindings[WKBD_WORKSPACEMAP].modifier == modifiers)) {
				w_global.process_workspacemap_event = False;
			} else {
				KeySym ks;
				int bulk_id;

				XLookupString(&ev.xkey, NULL, 16, &ks, NULL);

				bulk_id = -1;
				if (ks >= 0x30 && ks <= 0x39)
					bulk_id = ks - 0x30;
				else
					if (ks == XK_Left)
						bulk_id = wsmap_bulk_index - 1;
					else if (ks == XK_Right)
							bulk_id = wsmap_bulk_index + 1;

				if (bulk_id >= 0)
					update_mini_workspace(wsmap, wsmap_array, bulk_id);
			}
			break;

		case ButtonPress:
			switch (ev.xbutton.button) {
			case Button6:
				update_mini_workspace(wsmap, wsmap_array, wsmap_bulk_index - 1);
				break;
			case Button7:
				update_mini_workspace(wsmap, wsmap_array, wsmap_bulk_index + 1);
				break;
			default:
				WMHandleEvent(&ev);
			}
			break;

		default:
			WMHandleEvent(&ev);
			break;
		}
	}

	XUngrabPointer(dpy, CurrentTime);
	XUngrabKeyboard(dpy, CurrentTime);

	workspace_map_destroy(wsmap);
}

static WWorkspaceMap *init_workspace_map(WScreen *scr, W_WorkspaceMap *wsmap_array)
{
	WWorkspaceMap *wsmap;

	wsmap = create_workspace_map(scr, wsmap_array, WD_BOTTOM);
	return wsmap;
}

void StartWorkspaceMap(WScreen *scr)
{
	WWorkspaceMap *wsmap;
	W_WorkspaceMap wsmap_array[2 * mini_workspace_per_line];

	/* save the current screen before displaying the workspace map */
	wWorkspaceMapUpdate(scr);

	wsmap = init_workspace_map(scr, wsmap_array);
	if (wsmap) {
		workspace_map_show(wsmap);
		handle_event(wsmap, wsmap_array);
	}
}
