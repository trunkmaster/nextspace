/*
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

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#ifdef KEEP_XKB_LOCK_STATUS
#include <X11/XKBlib.h>
#endif				/* KEEP_XKB_LOCK_STATUS */

#include <stdlib.h>
#include <string.h>

#include <wraster.h>

#include "WindowMaker.h"
#include "GNUstep.h"
#include "texture.h"
#include "resources.h"
#include "screen.h"
#include "wcore.h"
#include "window.h"
#include "framewin.h"
#include "stacking.h"
#include "misc.h"
#include "event.h"


static void handleExpose(WObjDescriptor * desc, XEvent * event);
static void handleButtonExpose(WObjDescriptor * desc, XEvent * event);

static void buttonMouseDown(WObjDescriptor * desc, XEvent * event);
static void titlebarMouseDown(WObjDescriptor * desc, XEvent * event);
static void resizebarMouseDown(WObjDescriptor * desc, XEvent * event);

static void checkTitleSize(WFrameWindow * fwin);

static void paintButton(WCoreWindow * button, WTexture * texture,
			unsigned long color, WPixmap * image, int pushed);

static void updateTitlebar(WFrameWindow * fwin);

static void allocFrameBorderPixel(Colormap colormap, const char *color_name, unsigned long **pixel);

static void allocFrameBorderPixel(Colormap colormap, const char *color_name, unsigned long **pixel) {
	XColor xcol;

	*pixel = NULL;

	if (! wGetColorForColormap(colormap, color_name, &xcol))
		return;

	*pixel = wmalloc(sizeof(unsigned long));
	if (*pixel)
		**pixel = xcol.pixel;
}

WFrameWindow *wFrameWindowCreate(WScreen * scr, int wlevel, int x, int y,
				 int width, int height, int *clearance,
				 int *title_min, int *title_max, int flags,
				 WTexture ** title_texture, WTexture ** resize_texture,
				 WMColor ** color, WMFont ** font,
				 int depth, Visual *visual, Colormap colormap)
{
	WFrameWindow *fwin;

	fwin = wmalloc(sizeof(WFrameWindow));

	fwin->screen_ptr = scr;

	fwin->flags.single_texture = (flags & WFF_SINGLE_STATE) ? 1 : 0;

	fwin->title_texture = title_texture;
	fwin->resizebar_texture = resize_texture;
	fwin->title_color = color;
	fwin->title_clearance = clearance;
	fwin->title_min_height = title_min;
	fwin->title_max_height = title_max;
	fwin->font = font;
#ifdef KEEP_XKB_LOCK_STATUS
	fwin->languagemode = XkbGroup1Index;
	fwin->last_languagemode = XkbGroup2Index;
#endif

	fwin->depth = depth;
	fwin->visual = visual;
	fwin->colormap = colormap;

	fwin->core = wCoreCreateTopLevel(scr, x, y, width, height, (flags & WFF_BORDER)
					 ? scr->frame_border_width : 0, fwin->depth, fwin->visual, fwin->colormap, scr->frame_border_pixel);

	/* setup stacking information */
	fwin->core->stacking = wmalloc(sizeof(WStacking));
	fwin->core->stacking->above = NULL;
	fwin->core->stacking->under = NULL;
	fwin->core->stacking->child_of = NULL;
	fwin->core->stacking->window_level = wlevel;

	AddToStackList(fwin->core);

	wFrameWindowUpdateBorders(fwin, flags);

	return fwin;
}

void wFrameWindowUpdateBorders(WFrameWindow * fwin, int flags)
{
	int theight;
	int bsize;
	int width, height;
	int i;
	WScreen *scr = fwin->screen_ptr;

	width = fwin->core->width;
	if (flags & WFF_IS_SHADED)
		height = -1;
	else
		height = fwin->core->height - fwin->top_width - fwin->bottom_width;

	if (flags & WFF_TITLEBAR) {
		theight = WMFontHeight(*fwin->font) + (*fwin->title_clearance + TITLEBAR_EXTEND_SPACE) * 2;

		if (theight > *fwin->title_max_height)
			theight = *fwin->title_max_height;

		if (theight < *fwin->title_min_height)
			theight = *fwin->title_min_height;
	} else {
		theight = 0;
	}

	if (wPreferences.new_style == TS_NEW) {
		bsize = theight;
	} else if (wPreferences.new_style == TS_OLD) {
		bsize = theight - 7;
	} else {
		bsize = theight - 8;
	}

	if (fwin->titlebar) {
		/* if we had a titlebar and is requesting for one,
		 * check if the size has changed and resize it */
		if (flags & WFF_TITLEBAR) {
			fwin->top_width = theight;

			fwin->flags.need_texture_remake = 1;

			if (wPreferences.new_style == TS_NEW) {
				if (fwin->left_button)
					wCoreConfigure(fwin->left_button, 0, 0, bsize, bsize);
#ifdef XKB_BUTTON_HINT
				if (fwin->language_button) {
					if (fwin->flags.hide_left_button || !fwin->left_button
					    || fwin->flags.lbutton_dont_fit)
						wCoreConfigure(fwin->language_button, 0, 0, bsize, bsize);
					else
						wCoreConfigure(fwin->language_button, bsize, 0, bsize, bsize);
				}
#endif

				if (fwin->right_button)
					wCoreConfigure(fwin->right_button, width - bsize + 1, 0, bsize, bsize);

			} else {	/* !new_style */
				if (fwin->left_button)
					wCoreConfigure(fwin->left_button, 3, (theight - bsize) / 2, bsize, bsize);
#ifdef XKB_BUTTON_HINT
				if (fwin->language_button)
					wCoreConfigure(fwin->language_button, 6 + bsize, (theight - bsize) / 2,
						       bsize, bsize);
#endif

				if (fwin->right_button)
					wCoreConfigure(fwin->right_button, width - bsize - 3,
						       (theight - bsize) / 2, bsize, bsize);
			}
			updateTitlebar(fwin);
		} else {
			/* we had a titlebar, but now we don't need it anymore */
			for (i = 0; i < (fwin->flags.single_texture ? 1 : 3); i++) {
				FREE_PIXMAP(fwin->title_back[i]);
				if (wPreferences.new_style == TS_NEW) {
					FREE_PIXMAP(fwin->lbutton_back[i]);
					FREE_PIXMAP(fwin->rbutton_back[i]);
#ifdef XKB_BUTTON_HINT
					FREE_PIXMAP(fwin->languagebutton_back[i]);
#endif
				}
			}
			if (fwin->left_button)
				wCoreDestroy(fwin->left_button);
			fwin->left_button = NULL;

#ifdef XKB_BUTTON_HINT
			if (fwin->language_button)
				wCoreDestroy(fwin->language_button);
			fwin->language_button = NULL;
#endif

			if (fwin->right_button)
				wCoreDestroy(fwin->right_button);
			fwin->right_button = NULL;

			wCoreDestroy(fwin->titlebar);
			fwin->titlebar = NULL;

			fwin->top_width = 0;
		}
	} else {
		/* if we didn't have a titlebar and are being requested for
		 * one, create it */
		if (flags & WFF_TITLEBAR) {
			fwin->top_width = theight;

			fwin->flags.titlebar = 1;
			fwin->titlebar = wCoreCreate(fwin->core, 0, 0, width + 1, theight);

			if (flags & WFF_LEFT_BUTTON) {
				fwin->flags.left_button = 1;
				if (wPreferences.new_style == TS_NEW) {
					fwin->left_button = wCoreCreate(fwin->core, 0, 0, bsize, bsize);

					if (width < theight * 4)
						fwin->flags.lbutton_dont_fit = 1;
					else
						XMapRaised(dpy, fwin->left_button->window);

				} else if (wPreferences.new_style == TS_OLD) {
					fwin->left_button =
					    wCoreCreate(fwin->titlebar, 3, (theight - bsize) / 2, bsize, bsize);

					XSetWindowBackground(dpy, fwin->left_button->window,
							     scr->widget_texture->normal.pixel);

					if (width < theight * 3)
						fwin->flags.lbutton_dont_fit = 1;
					else
						XMapRaised(dpy, fwin->left_button->window);

				} else {
					fwin->left_button =
					    wCoreCreate(fwin->titlebar, 3, (theight-bsize)/2,
								    bsize, bsize);

					XSetWindowBackground(dpy, fwin->left_button->window,
							     scr->widget_texture->dark.pixel);

					if (width < theight * 3)
						fwin->flags.lbutton_dont_fit = 1;
					else
						XMapRaised(dpy, fwin->left_button->window);

				}
			}
#ifdef XKB_BUTTON_HINT
			if (flags & WFF_LANGUAGE_BUTTON) {
				fwin->flags.language_button = 1;
				if (wPreferences.new_style == TS_NEW) {
					fwin->language_button = wCoreCreate(fwin->core, bsize, 0, bsize, bsize);

					if (width < theight * 4)
						fwin->flags.languagebutton_dont_fit = 1;
					else
						XMapRaised(dpy, fwin->language_button->window);
				} else {
					fwin->language_button =
					    wCoreCreate(fwin->titlebar, bsize + 6, (theight - bsize) / 2,
							bsize, bsize);

					XSetWindowBackground(dpy, fwin->language_button->window,
							     scr->widget_texture->normal.pixel);

					if (width < theight * 3)
						fwin->flags.languagebutton_dont_fit = 1;
					else
						XMapRaised(dpy, fwin->language_button->window);
				}
			}
#endif

			if (flags & WFF_RIGHT_BUTTON) {
				fwin->flags.right_button = 1;
				if (wPreferences.new_style == TS_NEW) {
					fwin->right_button =
					    wCoreCreate(fwin->core, width - bsize + 1, 0, bsize, bsize);
				} else if (wPreferences.new_style == TS_OLD) {
					fwin->right_button =
					    wCoreCreate(fwin->titlebar, width - bsize - 3,
							(theight - bsize) / 2, bsize, bsize);
					XSetWindowBackground(dpy, fwin->right_button->window,
							     scr->widget_texture->normal.pixel);
				} else {
					fwin->right_button =
					    wCoreCreate(fwin->titlebar, width-bsize-3,
							(theight-bsize)/2, bsize, bsize);
					XSetWindowBackground(dpy, fwin->right_button->window,
							     scr->widget_texture->dark.pixel);
				}

				if (width < theight * 2)
					fwin->flags.rbutton_dont_fit = 1;
				else
					XMapRaised(dpy, fwin->right_button->window);
			}

			if (wPreferences.new_style == TS_NEW)
				updateTitlebar(fwin);

			XMapRaised(dpy, fwin->titlebar->window);

			fwin->flags.need_texture_remake = 1;
		}
	}
	checkTitleSize(fwin);

	if (flags & WFF_RESIZEBAR) {
		fwin->bottom_width = RESIZEBAR_HEIGHT;

		if (!fwin->resizebar) {
			fwin->flags.resizebar = 1;
			fwin->resizebar = wCoreCreate(fwin->core, 0,
						      height + fwin->top_width, width, RESIZEBAR_HEIGHT);
			fwin->resizebar_corner_width = RESIZEBAR_CORNER_WIDTH;
			if (width < RESIZEBAR_CORNER_WIDTH * 2 + RESIZEBAR_MIN_WIDTH) {
				fwin->resizebar_corner_width = (width - RESIZEBAR_MIN_WIDTH) / 2;
				if (fwin->resizebar_corner_width < 0)
					fwin->resizebar_corner_width = 0;
			}

			XMapWindow(dpy, fwin->resizebar->window);
			XLowerWindow(dpy, fwin->resizebar->window);

			fwin->flags.need_texture_remake = 1;
		} else {
			if (height + fwin->top_width + fwin->bottom_width != fwin->core->height)
				wCoreConfigure(fwin->resizebar, 0, height + fwin->top_width,
					       width, RESIZEBAR_HEIGHT);
		}
	} else {
		fwin->bottom_width = 0;

		if (fwin->resizebar) {
			fwin->bottom_width = 0;
			wCoreDestroy(fwin->resizebar);
			fwin->resizebar = NULL;
		}
	}

	if (height + fwin->top_width + fwin->bottom_width != fwin->core->height && !(flags & WFF_IS_SHADED))
		wFrameWindowResize(fwin, width, height + fwin->top_width + fwin->bottom_width);

	if (flags & WFF_BORDER)
		XSetWindowBorderWidth(dpy, fwin->core->window, scr->frame_border_width);
	else
		XSetWindowBorderWidth(dpy, fwin->core->window, 0);

	/* setup object descriptors */
	if (fwin->titlebar) {
		fwin->titlebar->descriptor.handle_expose = handleExpose;
		fwin->titlebar->descriptor.parent = fwin;
		fwin->titlebar->descriptor.parent_type = WCLASS_FRAME;
		fwin->titlebar->descriptor.handle_mousedown = titlebarMouseDown;
	}

	if (fwin->resizebar) {
		fwin->resizebar->descriptor.handle_expose = handleExpose;
		fwin->resizebar->descriptor.parent = fwin;
		fwin->resizebar->descriptor.parent_type = WCLASS_FRAME;
		fwin->resizebar->descriptor.handle_mousedown = resizebarMouseDown;
	}

	if (fwin->left_button) {
		fwin->left_button->descriptor.handle_expose = handleButtonExpose;
		fwin->left_button->descriptor.parent = fwin;
		fwin->left_button->descriptor.parent_type = WCLASS_FRAME;
		fwin->left_button->descriptor.handle_mousedown = buttonMouseDown;
	}

#ifdef XKB_BUTTON_HINT
	if (fwin->language_button) {
		fwin->language_button->descriptor.handle_expose = handleButtonExpose;
		fwin->language_button->descriptor.parent = fwin;
		fwin->language_button->descriptor.parent_type = WCLASS_FRAME;
		fwin->language_button->descriptor.handle_mousedown = buttonMouseDown;
	}
#endif

	if (fwin->right_button) {
		fwin->right_button->descriptor.parent = fwin;
		fwin->right_button->descriptor.parent_type = WCLASS_FRAME;
		fwin->right_button->descriptor.handle_expose = handleButtonExpose;
		fwin->right_button->descriptor.handle_mousedown = buttonMouseDown;
	}

	checkTitleSize(fwin);

	allocFrameBorderPixel(fwin->colormap, WMGetColorRGBDescription(scr->frame_border_color), &fwin->border_pixel);
	allocFrameBorderPixel(fwin->colormap, WMGetColorRGBDescription(scr->frame_focused_border_color), &fwin->focused_border_pixel);
	allocFrameBorderPixel(fwin->colormap, WMGetColorRGBDescription(scr->frame_selected_border_color), &fwin->selected_border_pixel);

	if (flags & WFF_SELECTED) {
		if (fwin->selected_border_pixel)
			XSetWindowBorder(dpy, fwin->core->window, *fwin->selected_border_pixel);
	}
	else {
		if (fwin->flags.state == WS_FOCUSED) {
			if (fwin->focused_border_pixel)
				XSetWindowBorder(dpy, fwin->core->window, *fwin->focused_border_pixel);
		} else {
			if (fwin->border_pixel)
				XSetWindowBorder(dpy, fwin->core->window, *fwin->border_pixel);
		}
	}
}

void wFrameWindowDestroy(WFrameWindow * fwin)
{
	int i;

	if (fwin->left_button)
		wCoreDestroy(fwin->left_button);

#ifdef XKB_BUTTON_HINT
	if (fwin->language_button)
		wCoreDestroy(fwin->language_button);
#endif

	if (fwin->right_button)
		wCoreDestroy(fwin->right_button);

	if (fwin->resizebar)
		wCoreDestroy(fwin->resizebar);

	if (fwin->titlebar)
		wCoreDestroy(fwin->titlebar);

	RemoveFromStackList(fwin->core);

	wCoreDestroy(fwin->core);

	if (fwin->title)
		wfree(fwin->title);

	for (i = 0; i < (fwin->flags.single_texture ? 1 : 3); i++) {
		FREE_PIXMAP(fwin->title_back[i]);
		if (wPreferences.new_style == TS_NEW) {
			FREE_PIXMAP(fwin->lbutton_back[i]);
#ifdef XKB_BUTTON_HINT
			FREE_PIXMAP(fwin->languagebutton_back[i]);
#endif
			FREE_PIXMAP(fwin->rbutton_back[i]);
		}
	}

	wfree(fwin);
}

void wFrameWindowChangeState(WFrameWindow * fwin, int state)
{
	if (fwin->flags.state == state)
		return;

	fwin->flags.state = state;
	fwin->flags.need_texture_change = 1;

	if (fwin->flags.state == WS_FOCUSED) {
		if (fwin->focused_border_pixel)
			XSetWindowBorder(dpy, fwin->core->window, *fwin->focused_border_pixel);
	} else {
		if (fwin->border_pixel)
			XSetWindowBorder(dpy, fwin->core->window, *fwin->border_pixel);
	}
	wFrameWindowPaint(fwin);
}

static void updateTitlebar(WFrameWindow * fwin)
{
	int x, w;
	int theight;

	theight = WMFontHeight(*fwin->font) + (*fwin->title_clearance + TITLEBAR_EXTEND_SPACE) * 2;

	if (theight > *fwin->title_max_height)
		theight = *fwin->title_max_height;

	if (theight < *fwin->title_min_height)
		theight = *fwin->title_min_height;

	x = 0;
	w = fwin->core->width + 1;

	if (wPreferences.new_style == TS_NEW) {
		if (fwin->flags.hide_left_button || !fwin->left_button || fwin->flags.lbutton_dont_fit) {
			x = 0;
#ifdef XKB_BUTTON_HINT
			if (fwin->language_button)
				wCoreConfigure(fwin->language_button, 0, 0,
					       fwin->language_button->width, fwin->language_button->width);
#endif
		} else {
#ifdef XKB_BUTTON_HINT
			if (fwin->language_button)
				wCoreConfigure(fwin->language_button, fwin->left_button->width, 0,
					       fwin->language_button->width, fwin->language_button->width);
#endif
			x = fwin->left_button->width;
			w -= fwin->left_button->width;
		}
#ifdef XKB_BUTTON_HINT
		if (fwin->flags.hide_language_button || !fwin->language_button
		    || fwin->flags.languagebutton_dont_fit) {
		} else {
			x += fwin->language_button->width;
			w -= fwin->language_button->width;
		}
#endif
	}
#ifdef XKB_BUTTON_HINT
	else {
		int bsize = theight - 7;
		if (fwin->flags.hide_left_button || !fwin->left_button || fwin->flags.lbutton_dont_fit) {
			if (fwin->language_button)
				wCoreConfigure(fwin->language_button, 3, (theight - bsize) / 2,
					       fwin->language_button->width, fwin->language_button->width);
		} else {
			if (fwin->language_button)
				wCoreConfigure(fwin->language_button,
					       6 + fwin->left_button->width, (theight - bsize) / 2,
					       fwin->language_button->width, fwin->language_button->width);
		}
	}
#endif

	if (wPreferences.new_style == TS_NEW) {
		if (!fwin->flags.hide_right_button && fwin->right_button && !fwin->flags.rbutton_dont_fit)
			w -= fwin->right_button->width;
	}

	if (wPreferences.new_style == TS_NEW || fwin->titlebar->width != w)
		fwin->flags.need_texture_remake = 1;

	wCoreConfigure(fwin->titlebar, x, 0, w, theight);
}

void wFrameWindowHideButton(WFrameWindow * fwin, int flags)
{
	if ((flags & WFF_RIGHT_BUTTON) && fwin->right_button) {
		XUnmapWindow(dpy, fwin->right_button->window);
		fwin->flags.hide_right_button = 1;
	}

	if ((flags & WFF_LEFT_BUTTON) && fwin->left_button) {
		XUnmapWindow(dpy, fwin->left_button->window);
		fwin->flags.hide_left_button = 1;
	}
#ifdef XKB_BUTTON_HINT
	if ((flags & WFF_LANGUAGE_BUTTON) && fwin->language_button) {
		XUnmapWindow(dpy, fwin->language_button->window);
		fwin->flags.hide_language_button = 1;
	}
#endif

	if (fwin->titlebar) {
		if (wPreferences.new_style == TS_NEW) {
			updateTitlebar(fwin);
		} else {
#ifdef XKB_BUTTON_HINT
			updateTitlebar(fwin);
#else
			XClearWindow(dpy, fwin->titlebar->window);
			wFrameWindowPaint(fwin);
#endif
		}
		checkTitleSize(fwin);
	}
}

void wFrameWindowShowButton(WFrameWindow * fwin, int flags)
{
	if ((flags & WFF_RIGHT_BUTTON) && fwin->right_button && fwin->flags.hide_right_button) {

		if (!fwin->flags.rbutton_dont_fit)
			XMapWindow(dpy, fwin->right_button->window);

		fwin->flags.hide_right_button = 0;
	}
#ifdef XKB_BUTTON_HINT
	if ((flags & WFF_LANGUAGE_BUTTON) && fwin->language_button && fwin->flags.hide_language_button) {

		if (!fwin->flags.languagebutton_dont_fit)
			XMapWindow(dpy, fwin->language_button->window);

		fwin->flags.hide_language_button = 0;
	}
#endif

	if ((flags & WFF_LEFT_BUTTON) && fwin->left_button && fwin->flags.hide_left_button) {

		if (!fwin->flags.lbutton_dont_fit)
			XMapWindow(dpy, fwin->left_button->window);

		fwin->flags.hide_left_button = 0;
	}

	if (fwin->titlebar) {
		if (wPreferences.new_style == TS_NEW) {
			updateTitlebar(fwin);
		} else {
			XClearWindow(dpy, fwin->titlebar->window);
			wFrameWindowPaint(fwin);
		}
		checkTitleSize(fwin);
	}
}

static void
#ifdef XKB_BUTTON_HINT
renderTexture(WScreen * scr, WTexture * texture, int width, int height,
	      int bwidth, int bheight, int left, int language, int right,
	      Pixmap * title, Pixmap * lbutton, Pixmap * languagebutton, Pixmap * rbutton)
#else
renderTexture(WScreen * scr, WTexture * texture, int width, int height,
	      int bwidth, int bheight, int left, int right, Pixmap * title, Pixmap * lbutton, Pixmap * rbutton)
#endif
{
	RImage *img;
	RImage *limg, *rimg, *mimg;
#ifdef XKB_BUTTON_HINT
	RImage *timg;
#endif
	int x, w;

	*title = None;
	*lbutton = None;
	*rbutton = None;
#ifdef XKB_BUTTON_HINT
	*languagebutton = None;
#endif

	img = wTextureRenderImage(texture, width, height, WREL_FLAT);
	if (!img) {
		wwarning(_("could not render texture: %s"), RMessageForError(RErrorCode));
		return;
	}

	if (wPreferences.new_style == TS_NEW) {
		if (left)
			limg = RGetSubImage(img, 0, 0, bwidth, bheight);
		else
			limg = NULL;

		x = 0;
		w = img->width;

#ifdef XKB_BUTTON_HINT
		if (language)
			timg = RGetSubImage(img, bwidth * left, 0, bwidth, bheight);
		else
			timg = NULL;
#endif

		if (limg) {
			RBevelImage(limg, RBEV_RAISED2);
			if (!RConvertImage(scr->rcontext, limg, lbutton))
				wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));

			x += limg->width;
			w -= limg->width;
			RReleaseImage(limg);
		}
#ifdef XKB_BUTTON_HINT
		if (timg) {
			RBevelImage(timg, RBEV_RAISED2);
			if (!RConvertImage(scr->rcontext, timg, languagebutton))
				wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));

			x += timg->width;
			w -= timg->width;
			RReleaseImage(timg);
		}
#endif

		if (right)
			rimg = RGetSubImage(img, width - bwidth, 0, bwidth, bheight);
		else
			rimg = NULL;

		if (rimg) {
			RBevelImage(rimg, RBEV_RAISED2);
			if (!RConvertImage(scr->rcontext, rimg, rbutton))
				wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));

			w -= rimg->width;
			RReleaseImage(rimg);
		}

		if (w != width) {
			mimg = RGetSubImage(img, x, 0, w, img->height);
			RBevelImage(mimg, RBEV_RAISED2);

			if (!RConvertImage(scr->rcontext, mimg, title))
				wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));

			RReleaseImage(mimg);
		} else {
			RBevelImage(img, RBEV_RAISED2);

			if (!RConvertImage(scr->rcontext, img, title))
				wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));
		}
	} else {
		RBevelImage(img, RBEV_RAISED2);

		if (!RConvertImage(scr->rcontext, img, title))
			wwarning(_("error rendering image:%s"), RMessageForError(RErrorCode));
	}

	RReleaseImage(img);
}

static void
renderResizebarTexture(WScreen * scr, WTexture * texture, int width, int height, int cwidth, Pixmap * pmap)
{
	RImage *img;
	RColor light;
	RColor dark;

	*pmap = None;

	img = wTextureRenderImage(texture, width, height, WREL_FLAT);
	if (!img) {
		wwarning(_("could not render texture: %s"), RMessageForError(RErrorCode));
		return;
	}

	light.alpha = 0;
	light.red = light.green = light.blue = 80;

	dark.alpha = 0;
	dark.red = dark.green = dark.blue = 40;

	ROperateLine(img, RSubtractOperation, 0, 0, width - 1, 0, &dark);
	ROperateLine(img, RAddOperation, 0, 1, width - 1, 1, &light);

	ROperateLine(img, RSubtractOperation, cwidth, 2, cwidth, height - 1, &dark);
	ROperateLine(img, RAddOperation, cwidth + 1, 2, cwidth + 1, height - 1, &light);

	if (width > 1)
		ROperateLine(img, RSubtractOperation, width - cwidth - 2, 2,
			     width - cwidth - 2, height - 1, &dark);
	ROperateLine(img, RAddOperation, width - cwidth - 1, 2, width - cwidth - 1, height - 1, &light);

#ifdef SHADOW_RESIZEBAR
	ROperateLine(img, RAddOperation, 0, 1, 0, height - 1, &light);
	ROperateLine(img, RSubtractOperation, width - 1, 1, width - 1, height - 1, &dark);
	ROperateLine(img, RSubtractOperation, 0, height - 1, width - 1, height - 1, &dark);
#endif				/* SHADOW_RESIZEBAR */

	if (!RConvertImage(scr->rcontext, img, pmap))
		wwarning(_("error rendering image: %s"), RMessageForError(RErrorCode));

	RReleaseImage(img);
}

static void updateTexture(WFrameWindow * fwin)
{
	int i;
	unsigned long pixel;

	i = fwin->flags.state;
	if (fwin->titlebar) {
		if (fwin->title_texture[i]->any.type != WTEX_SOLID) {
			XSetWindowBackgroundPixmap(dpy, fwin->titlebar->window, fwin->title_back[i]);
			if (wPreferences.new_style == TS_NEW) {
				if (fwin->left_button && fwin->lbutton_back[i])
					XSetWindowBackgroundPixmap(dpy, fwin->left_button->window,
								   fwin->lbutton_back[i]);

#ifdef XKB_BUTTON_HINT
				if (fwin->language_button && fwin->languagebutton_back[i])
					XSetWindowBackgroundPixmap(dpy, fwin->language_button->window,
								   fwin->languagebutton_back[i]);
#endif

				if (fwin->right_button && fwin->rbutton_back[i])
					XSetWindowBackgroundPixmap(dpy, fwin->right_button->window,
								   fwin->rbutton_back[i]);
			}
		} else {
			pixel = fwin->title_texture[i]->solid.normal.pixel;
			XSetWindowBackground(dpy, fwin->titlebar->window, pixel);
			if (wPreferences.new_style == TS_NEW) {
				if (fwin->left_button)
					XSetWindowBackground(dpy, fwin->left_button->window, pixel);
#ifdef XKB_BUTTON_HINT
				if (fwin->language_button)
					XSetWindowBackground(dpy, fwin->language_button->window, pixel);
#endif
				if (fwin->right_button)
					XSetWindowBackground(dpy, fwin->right_button->window, pixel);
			}
		}
		XClearWindow(dpy, fwin->titlebar->window);

		if (fwin->left_button) {
			XClearWindow(dpy, fwin->left_button->window);
			handleButtonExpose(&fwin->left_button->descriptor, NULL);
		}
#ifdef XKB_BUTTON_HINT
		if (fwin->language_button) {
			XClearWindow(dpy, fwin->language_button->window);
			handleButtonExpose(&fwin->language_button->descriptor, NULL);
		}
#endif
		if (fwin->right_button) {
			XClearWindow(dpy, fwin->right_button->window);
			handleButtonExpose(&fwin->right_button->descriptor, NULL);
		}
	}
}

static void remakeTexture(WFrameWindow * fwin, int state)
{
	Pixmap pmap, lpmap, rpmap;
#ifdef XKB_BUTTON_HINT
	Pixmap tpmap;
#endif

	if (fwin->title_texture[state] && fwin->titlebar) {
		FREE_PIXMAP(fwin->title_back[state]);
		if (wPreferences.new_style == TS_NEW) {
			FREE_PIXMAP(fwin->lbutton_back[state]);
			FREE_PIXMAP(fwin->rbutton_back[state]);
#ifdef XKB_BUTTON_HINT
			FREE_PIXMAP(fwin->languagebutton_back[state]);
#endif
		}

		if (fwin->title_texture[state]->any.type != WTEX_SOLID) {
			int left, right;
			int width;
#ifdef XKB_BUTTON_HINT
			int language;
#endif

			/* eventually surrounded by if new_style */
			left = fwin->left_button && !fwin->flags.hide_left_button && !fwin->flags.lbutton_dont_fit;
#ifdef XKB_BUTTON_HINT
			language = fwin->language_button && !fwin->flags.hide_language_button
			    && !fwin->flags.languagebutton_dont_fit;
#endif
			right = fwin->right_button && !fwin->flags.hide_right_button
			    && !fwin->flags.rbutton_dont_fit;

			width = fwin->core->width + 1;

#ifdef XKB_BUTTON_HINT
			renderTexture(fwin->screen_ptr, fwin->title_texture[state],
				      width, fwin->titlebar->height,
				      fwin->titlebar->height, fwin->titlebar->height,
				      left, language, right, &pmap, &lpmap, &tpmap, &rpmap);
#else
			renderTexture(fwin->screen_ptr, fwin->title_texture[state],
				      width, fwin->titlebar->height,
				      fwin->titlebar->height, fwin->titlebar->height,
				      left, right, &pmap, &lpmap, &rpmap);
#endif

			fwin->title_back[state] = pmap;
			if (wPreferences.new_style == TS_NEW) {
				fwin->lbutton_back[state] = lpmap;
				fwin->rbutton_back[state] = rpmap;
#ifdef XKB_BUTTON_HINT
				fwin->languagebutton_back[state] = tpmap;
#endif
			}
		}
	}
	if (fwin->resizebar_texture && fwin->resizebar_texture[0]
	    && fwin->resizebar && state == 0) {

		FREE_PIXMAP(fwin->resizebar_back[0]);

		if (fwin->resizebar_texture[0]->any.type != WTEX_SOLID) {

			renderResizebarTexture(fwin->screen_ptr,
					       fwin->resizebar_texture[0],
					       fwin->resizebar->width,
					       fwin->resizebar->height, fwin->resizebar_corner_width, &pmap);

			fwin->resizebar_back[0] = pmap;
		}

		/* this part should be in updateTexture() */
		if (fwin->resizebar_texture[0]->any.type != WTEX_SOLID)
			XSetWindowBackgroundPixmap(dpy, fwin->resizebar->window, fwin->resizebar_back[0]);
		else
			XSetWindowBackground(dpy, fwin->resizebar->window,
					     fwin->resizebar_texture[0]->solid.normal.pixel);

		XClearWindow(dpy, fwin->resizebar->window);
	}
}

void wFrameWindowPaint(WFrameWindow * fwin)
{
	WScreen *scr = fwin->screen_ptr;
	int state;

	state = fwin->flags.state;

	if (fwin->flags.is_client_window_frame)
		fwin->flags.justification = wPreferences.title_justification;

	if (fwin->flags.need_texture_remake) {
		int i;

		fwin->flags.need_texture_remake = 0;
		fwin->flags.need_texture_change = 0;

		if (fwin->flags.single_texture) {
			remakeTexture(fwin, 0);
			updateTexture(fwin);
		} else {
			/* first render the texture for the current state... */
			remakeTexture(fwin, state);
			/* ... and paint it */
			updateTexture(fwin);

			for (i = 0; i < 3; i++) {
				if (i != state)
					remakeTexture(fwin, i);
			}
		}
	}

	if (fwin->flags.need_texture_change) {
		fwin->flags.need_texture_change = 0;

		updateTexture(fwin);
	}

	if (fwin->titlebar && !fwin->flags.repaint_only_resizebar
	    && fwin->title_texture[state]->any.type == WTEX_SOLID) {
		wDrawBevel(fwin->titlebar->window, fwin->titlebar->width,
			   fwin->titlebar->height, (WTexSolid *) fwin->title_texture[state], WREL_RAISED);
	}

	if (fwin->resizebar && !fwin->flags.repaint_only_titlebar
	    && fwin->resizebar_texture[0]->any.type == WTEX_SOLID) {
		Window win;
		int w, h;
		int cw;
		GC light_gc, dim_gc;
		WTexSolid *texture = (WTexSolid *) fwin->resizebar_texture[0];

		w = fwin->resizebar->width;
		h = fwin->resizebar->height;
		cw = fwin->resizebar_corner_width;
		light_gc = texture->light_gc;
		dim_gc = texture->dim_gc;
		win = fwin->resizebar->window;

		XDrawLine(dpy, win, dim_gc, 0, 0, w, 0);
		XDrawLine(dpy, win, light_gc, 0, 1, w, 1);

		XDrawLine(dpy, win, dim_gc, cw, 2, cw, h);
		XDrawLine(dpy, win, light_gc, cw + 1, 2, cw + 1, h);

		XDrawLine(dpy, win, dim_gc, w - cw - 2, 2, w - cw - 2, h);
		XDrawLine(dpy, win, light_gc, w - cw - 1, 2, w - cw - 1, h);

#ifdef SHADOW_RESIZEBAR
		XDrawLine(dpy, win, light_gc, 0, 1, 0, h - 1);
		XDrawLine(dpy, win, dim_gc, w - 1, 2, w - 1, h - 1);
		XDrawLine(dpy, win, dim_gc, 1, h - 1, cw, h - 1);
		XDrawLine(dpy, win, dim_gc, cw + 2, h - 1, w - cw - 2, h - 1);
		XDrawLine(dpy, win, dim_gc, w - cw, h - 1, w - 1, h - 1);
#endif				/* SHADOW_RESIZEBAR */
	}

	if (fwin->titlebar && !fwin->flags.repaint_only_resizebar) {
		int x, y, w, h;
		int lofs = 6, rofs = 6;
		int titlelen;
		int allButtons = 1;

		if (!wPreferences.new_style == TS_NEW) {
			if (fwin->left_button && !fwin->flags.hide_left_button && !fwin->flags.lbutton_dont_fit)
				lofs += fwin->left_button->width + 3;
			else
				allButtons = 0;

#ifdef XKB_BUTTON_HINT
			if (fwin->language_button && !fwin->flags.hide_language_button
			    && !fwin->flags.languagebutton_dont_fit)
				lofs += fwin->language_button->width;
			else
				allButtons = 0;
#endif

			if (fwin->right_button && !fwin->flags.hide_right_button && !fwin->flags.rbutton_dont_fit)
				rofs += fwin->right_button->width + 3;
			else
				allButtons = 0;
		}
#ifdef XKB_BUTTON_HINT
		fwin->languagebutton_image = scr->b_pixmaps[WBUT_XKBGROUP1 + fwin->languagemode];
#endif

		if (fwin->title) {
			Drawable buf;
			char *title;

			title = ShrinkString(*fwin->font, fwin->title, fwin->titlebar->width - lofs - rofs);
			titlelen = strlen(title);
			w = WMWidthOfString(*fwin->font, title, titlelen);

			switch (fwin->flags.justification) {
			case WTJ_LEFT:
				x = lofs;
				break;

			case WTJ_RIGHT:
				x = fwin->titlebar->width - w - rofs;
				break;

			default:
				if (!allButtons)
					x = lofs + (fwin->titlebar->width - w - lofs - rofs) / 2;
				else
					x = (fwin->titlebar->width - w) / 2;
				break;
			}

			y = *fwin->title_clearance + TITLEBAR_EXTEND_SPACE;
			h = WMFontHeight(*fwin->font);

			if (y*2 + h > *fwin->title_max_height)
				y = (*fwin->title_max_height - h) / 2;

			if (y*2 + h < *fwin->title_min_height)
				y = (*fwin->title_min_height - h) / 2;

			/* We use a w+2 buffer to have an extra pixel on the left and
			 * another one on the right. This is because for some odd reason,
			 * sometimes when using AA fonts (when libfreetype2 is compiled
			 * with bytecode interpreter turned off), some fonts are drawn
			 * starting from x = -1 not from 0 as requested. Observed with
			 * capital A letter on the bold 'trebuchet ms' font. -Dan
			 */
			buf = XCreatePixmap(dpy, fwin->titlebar->window, w + 2, h, scr->w_depth);

			XSetClipMask(dpy, scr->copy_gc, None);

			if (fwin->title_texture[state]->any.type != WTEX_SOLID) {
				XCopyArea(dpy, fwin->title_back[state], buf, scr->copy_gc,
					  x - 1, y, w + 2, h, 0, 0);
			} else {
				XSetForeground(dpy, scr->copy_gc, fwin->title_texture[state]->solid.normal.pixel);
				XFillRectangle(dpy, buf, scr->copy_gc, 0, 0, w + 2, h);
			}

			/*XDrawRectangle(dpy, buf, WMColorGC(scr->white),1,0,w,h-1); */
			WMDrawString(scr->wmscreen, buf, fwin->title_color[state],
				     *fwin->font, 1, 0, title, titlelen);

			XCopyArea(dpy, buf, fwin->titlebar->window, scr->copy_gc, 0, 0, w + 2, h, x - 1, y);

			XFreePixmap(dpy, buf);

			wfree(title);
		}

		if (fwin->left_button)
			handleButtonExpose(&fwin->left_button->descriptor, NULL);
		if (fwin->right_button)
			handleButtonExpose(&fwin->right_button->descriptor, NULL);
#ifdef XKB_BUTTON_HINT
		if (fwin->language_button)
			handleButtonExpose(&fwin->language_button->descriptor, NULL);
#endif
	}
}

static void reconfigure(WFrameWindow * fwin, int x, int y, int width, int height, Bool dontMove)
{
	int k = (wPreferences.new_style == TS_NEW ? 4 : 3);
	int resizedHorizontally = 0;

	if (dontMove)
		XResizeWindow(dpy, fwin->core->window, width, height);
	else
		XMoveResizeWindow(dpy, fwin->core->window, x, y, width, height);

	if (fwin->core->width != width) {
		fwin->flags.need_texture_remake = 1;
		resizedHorizontally = 1;
	}

	fwin->core->width = width;
	fwin->core->height = height;

	if (fwin->titlebar && resizedHorizontally) {
		/* Check if the titlebar is wide enough to hold the buttons.
		 * Temporarily remove them if can't
		 */
		if (fwin->left_button) {
			if (width < fwin->top_width * k && !fwin->flags.lbutton_dont_fit) {
				if (!fwin->flags.hide_left_button)
					XUnmapWindow(dpy, fwin->left_button->window);

				fwin->flags.lbutton_dont_fit = 1;
			} else if (width >= fwin->top_width * k && fwin->flags.lbutton_dont_fit) {
				if (!fwin->flags.hide_left_button)
					XMapWindow(dpy, fwin->left_button->window);

				fwin->flags.lbutton_dont_fit = 0;
			}
		}
#ifdef XKB_BUTTON_HINT
		if (fwin->language_button) {
			if (width < fwin->top_width * k && !fwin->flags.languagebutton_dont_fit) {
				if (!fwin->flags.hide_language_button)
					XUnmapWindow(dpy, fwin->language_button->window);

				fwin->flags.languagebutton_dont_fit = 1;
			} else if (width >= fwin->top_width * k && fwin->flags.languagebutton_dont_fit) {
				if (!fwin->flags.hide_language_button)
					XMapWindow(dpy, fwin->language_button->window);

				fwin->flags.languagebutton_dont_fit = 0;
			}
		}
#endif

		if (fwin->right_button) {
			if (width < fwin->top_width * 2 && !fwin->flags.rbutton_dont_fit) {
				if (!fwin->flags.hide_right_button)
					XUnmapWindow(dpy, fwin->right_button->window);

				fwin->flags.rbutton_dont_fit = 1;
			} else if (width >= fwin->top_width * 2 && fwin->flags.rbutton_dont_fit) {
				if (!fwin->flags.hide_right_button)
					XMapWindow(dpy, fwin->right_button->window);

				fwin->flags.rbutton_dont_fit = 0;
			}
		}

		if (wPreferences.new_style == TS_NEW) {
			if (fwin->right_button)
				XMoveWindow(dpy, fwin->right_button->window,
					    width - fwin->right_button->width + 1, 0);
		} else {
			if (fwin->right_button)
				XMoveWindow(dpy, fwin->right_button->window,
					    width - fwin->right_button->width - 3,
					    (fwin->titlebar->height - fwin->right_button->height) / 2);
		}
		updateTitlebar(fwin);
		checkTitleSize(fwin);
	}

	if (fwin->resizebar) {
		wCoreConfigure(fwin->resizebar, 0,
			       fwin->core->height - fwin->resizebar->height,
			       fwin->core->width, fwin->resizebar->height);

		fwin->resizebar_corner_width = RESIZEBAR_CORNER_WIDTH;
		if (fwin->core->width < RESIZEBAR_CORNER_WIDTH * 2 + RESIZEBAR_MIN_WIDTH)
			fwin->resizebar_corner_width = fwin->core->width / 2;
	}
}

void wFrameWindowConfigure(WFrameWindow * fwin, int x, int y, int width, int height)
{
	reconfigure(fwin, x, y, width, height, False);
}

void wFrameWindowResize(WFrameWindow * fwin, int width, int height)
{
	reconfigure(fwin, 0, 0, width, height, True);
}

int wFrameWindowChangeTitle(WFrameWindow *fwin, const char *new_title)
{
	if (new_title == NULL)
		return 0;

	/* check if the title is the same as before */
	if (fwin->title) {
		if (strcmp(fwin->title, new_title) == 0)
			return 0;
	}

	if (fwin->title)
		wfree(fwin->title);

	fwin->title = wstrdup(new_title);

	if (fwin->titlebar) {
		XClearWindow(dpy, fwin->titlebar->window);

		wFrameWindowPaint(fwin);
	}
	checkTitleSize(fwin);

	return 1;
}

#ifdef XKB_BUTTON_HINT
void wFrameWindowUpdateLanguageButton(WFrameWindow * fwin)
{
	paintButton(fwin->language_button, fwin->title_texture[fwin->flags.state],
		    WMColorPixel(fwin->title_color[fwin->flags.state]), fwin->languagebutton_image, True);
}
#endif				/* XKB_BUTTON_HINT */

/*********************************************************************/

static void handleExpose(WObjDescriptor * desc, XEvent * event)
{
	WFrameWindow *fwin = (WFrameWindow *) desc->parent;

	if (fwin->titlebar && fwin->titlebar->window == event->xexpose.window)
		fwin->flags.repaint_only_titlebar = 1;
	if (fwin->resizebar && fwin->resizebar->window == event->xexpose.window)
		fwin->flags.repaint_only_resizebar = 1;
	wFrameWindowPaint(fwin);
	fwin->flags.repaint_only_titlebar = 0;
	fwin->flags.repaint_only_resizebar = 0;
}

static void checkTitleSize(WFrameWindow * fwin)
{
	int width;

	if (!fwin->title) {
		fwin->flags.incomplete_title = 0;
		return;
	}

	if (!fwin->titlebar) {
		fwin->flags.incomplete_title = 1;
		return;
	} else {
		width = fwin->titlebar->width - 6 - 6;
	}

	if (!wPreferences.new_style == TS_NEW) {
		if (fwin->left_button && !fwin->flags.hide_left_button && !fwin->flags.lbutton_dont_fit)
			width -= fwin->left_button->width + 3;

#ifdef XKB_BUTTON_HINT
		if (fwin->language_button && !fwin->flags.hide_language_button
		    && !fwin->flags.languagebutton_dont_fit)
			width -= fwin->language_button->width + 3;
#endif

		if (fwin->right_button && !fwin->flags.hide_right_button && !fwin->flags.rbutton_dont_fit)
			width -= fwin->right_button->width + 3;
	}

	if (WMWidthOfString(*fwin->font, fwin->title, strlen(fwin->title)) > width)
		fwin->flags.incomplete_title = 1;
	else
		fwin->flags.incomplete_title = 0;
}

static void paintButton(WCoreWindow * button, WTexture * texture, unsigned long color, WPixmap * image, int pushed)
{
	WScreen *scr = button->screen_ptr;
	GC copy_gc = scr->copy_gc;
	int x = 0, y = 0, d = 0;
	int left = 0, width = 0;

	/* setup stuff according to the state */
	if (pushed) {
		if (image) {
			if (image->width >= image->height * 2) {
				/* the image contains 2 pictures: the second is for the
				 * pushed state */
				width = image->width / 2;
				left = image->width / 2;
			} else {
				width = image->width;
			}
		}
		XSetClipMask(dpy, copy_gc, None);
		if (wPreferences.new_style == TS_NEXT)
			XSetForeground(dpy, copy_gc, scr->black_pixel);
		else
			XSetForeground(dpy, copy_gc, scr->white_pixel);

		d = 1;
		if (wPreferences.new_style == TS_NEW) {
			XFillRectangle(dpy, button->window, copy_gc, 0, 0, button->width - 1, button->height - 1);
			XSetForeground(dpy, copy_gc, scr->black_pixel);
			XDrawRectangle(dpy, button->window, copy_gc, 0, 0, button->width - 1, button->height - 1);
		} else if (wPreferences.new_style == TS_OLD) {
			XFillRectangle(dpy, button->window, copy_gc, 0, 0, button->width, button->height);
			XSetForeground(dpy, copy_gc, scr->black_pixel);
			XDrawRectangle(dpy, button->window, copy_gc, 0, 0, button->width, button->height);
		} else {
			XFillRectangle(dpy, button->window, copy_gc, 0, 0, button->width-3, button->height-3);
			XSetForeground(dpy, copy_gc, scr->black_pixel);
			XDrawRectangle(dpy, button->window, copy_gc, 0, 0, button->width-3, button->height-3);
		}
	} else {
		XClearWindow(dpy, button->window);

		if (image) {
			if (image->width >= image->height * 2)
				width = image->width / 2;
			else
				width = image->width;
		}
		d = 0;

		if (wPreferences.new_style == TS_NEW) {
			if (texture->any.type == WTEX_SOLID || pushed)
				wDrawBevel(button->window, button->width, button->height,
					   (WTexSolid *) texture, WREL_RAISED);
		} else {
			wDrawBevel(button->window, button->width, button->height,
				   scr->widget_texture, WREL_RAISED);
		}
	}

	if (image) {
		/* display image */
		XSetClipMask(dpy, copy_gc, image->mask);
		x = (button->width - width) / 2 + d;
		y = (button->height - image->height) / 2 + d;
		XSetClipOrigin(dpy, copy_gc, x - left, y);
		if (!wPreferences.new_style == TS_NEW) {
			XSetForeground(dpy, copy_gc, scr->black_pixel);
			if (!pushed) {
				if (image->depth == 1)
					XCopyPlane(dpy, image->image, button->window, copy_gc,
						   left, 0, width, image->height, x, y, 1);
				else
					XCopyArea(dpy, image->image, button->window, copy_gc,
						  left, 0, width, image->height, x, y);
			} else {
				if (wPreferences.new_style == TS_OLD) {
					XSetForeground(dpy, copy_gc, scr->dark_pixel);
					XFillRectangle(dpy, button->window, copy_gc, 0, 0,
						       button->width, button->height);
				} else {
					XSetForeground(dpy, copy_gc, scr->black_pixel);
					XCopyArea(dpy, image->image, button->window, copy_gc,
						  left, 0, width, image->height, x, y);
				}
			}
		} else {
			if (pushed) {
				XSetForeground(dpy, copy_gc, scr->black_pixel);
			} else {
				XSetForeground(dpy, copy_gc, color);
				XSetBackground(dpy, copy_gc, texture->any.color.pixel);
			}
			XFillRectangle(dpy, button->window, copy_gc, 0, 0, button->width, button->height);
		}
	}
}

static void handleButtonExpose(WObjDescriptor * desc, XEvent * event)
{
	WFrameWindow *fwin = (WFrameWindow *) desc->parent;
	WCoreWindow *button = (WCoreWindow *) desc->self;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) event;

#ifdef XKB_BUTTON_HINT
	if (button == fwin->language_button) {
		if (wPreferences.modelock)
			paintButton(button, fwin->title_texture[fwin->flags.state],
				    WMColorPixel(fwin->title_color[fwin->flags.state]),
				    fwin->languagebutton_image, False);
	} else
#endif
	if (button == fwin->left_button)
		paintButton(button, fwin->title_texture[fwin->flags.state],
			    WMColorPixel(fwin->title_color[fwin->flags.state]), fwin->lbutton_image, False);
	else
		paintButton(button, fwin->title_texture[fwin->flags.state],
			    WMColorPixel(fwin->title_color[fwin->flags.state]), fwin->rbutton_image, False);
}

static void titlebarMouseDown(WObjDescriptor * desc, XEvent * event)
{
	WFrameWindow *fwin = desc->parent;
	WCoreWindow *titlebar = desc->self;

	if (IsDoubleClick(fwin->core->screen_ptr, event)) {
		if (fwin->on_dblclick_titlebar)
			(*fwin->on_dblclick_titlebar) (titlebar, fwin->child, event);
	} else {
		if (fwin->on_mousedown_titlebar)
			(*fwin->on_mousedown_titlebar) (titlebar, fwin->child, event);
	}
}

static void resizebarMouseDown(WObjDescriptor * desc, XEvent * event)
{
	WFrameWindow *fwin = desc->parent;
	WCoreWindow *resizebar = desc->self;

	if (fwin->on_mousedown_resizebar)
		(*fwin->on_mousedown_resizebar) (resizebar, fwin->child, event);
}

static void buttonMouseDown(WObjDescriptor * desc, XEvent * event)
{
	WFrameWindow *fwin = desc->parent;
	WCoreWindow *button = desc->self;
	WPixmap *image;
	XEvent ev;
	int done = 0, execute = 1;
	WTexture *texture;
	unsigned long pixel;
	int clickButton = event->xbutton.button;

	if (IsDoubleClick(fwin->core->screen_ptr, event)) {
		if (button == fwin->right_button && fwin->on_dblclick_right)
			(*fwin->on_dblclick_right) (button, fwin->child, event);

		return;
	}

	if (button == fwin->left_button)
		image = fwin->lbutton_image;
	else
		image = fwin->rbutton_image;

#ifdef XKB_BUTTON_HINT
	if (button == fwin->language_button) {
		if (!wPreferences.modelock)
			return;
		image = fwin->languagebutton_image;
	}
#endif

	pixel = WMColorPixel(fwin->title_color[fwin->flags.state]);
	texture = fwin->title_texture[fwin->flags.state];
	paintButton(button, texture, pixel, image, True);

	while (!done) {
		WMMaskEvent(dpy, LeaveWindowMask | EnterWindowMask | ButtonReleaseMask
			    | ButtonPressMask | ExposureMask, &ev);
		switch (ev.type) {
		case LeaveNotify:
			execute = 0;
			paintButton(button, texture, pixel, image, False);
			break;

		case EnterNotify:
			execute = 1;
			paintButton(button, texture, pixel, image, True);
			break;

		case ButtonPress:
			break;

		case ButtonRelease:
			if (ev.xbutton.button == clickButton)
				done = 1;
			break;

		default:
			WMHandleEvent(&ev);
		}
	}
	paintButton(button, texture, pixel, image, False);

	if (execute) {
		if (button == fwin->left_button) {
			if (fwin->on_click_left)
				(*fwin->on_click_left) (button, fwin->child, &ev);
		} else if (button == fwin->right_button) {
			if (fwin->on_click_right)
				(*fwin->on_click_right) (button, fwin->child, &ev);
		}
#ifdef XKB_BUTTON_HINT
		else if (button == fwin->language_button) {
			if (fwin->on_click_language)
				(*fwin->on_click_language) (button, fwin->child, &ev);
		}
#endif

	}
}
