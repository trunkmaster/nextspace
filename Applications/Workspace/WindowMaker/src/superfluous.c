/*
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
#include <unistd.h>
#include <math.h>
#include <time.h>

#include <wraster.h>

#include "WindowMaker.h"
#include "screen.h"
#include "superfluous.h"
#include "framewin.h"
#include "window.h"
#include "actions.h"
#include "xinerama.h"
#include "stacking.h"

#define PIECES ((64/ICON_KABOOM_PIECE_SIZE)*(64/ICON_KABOOM_PIECE_SIZE))
#define KAB_PRECISION		4
#define BOUNCE_HZ		25
#define BOUNCE_DELAY		(1000/BOUNCE_HZ)
#define BOUNCE_HEIGHT		24
#define BOUNCE_LENGTH		0.3
#define BOUNCE_DAMP		0.6
#define URGENT_BOUNCE_DELAY	3000


void DoKaboom(WScreen * scr, Window win, int x, int y)
{
#ifdef NORMAL_ICON_KABOOM
	int i, j, k;
	int sw = scr->scr_width, sh = scr->scr_height;
	int px[PIECES];
	short py[PIECES];
	char pvx[PIECES], pvy[PIECES];
	/* in MkLinux/PPC gcc seems to think that char is unsigned? */
	signed char ax[PIECES], ay[PIECES];
	Pixmap tmp;

	XSetClipMask(dpy, scr->copy_gc, None);
	tmp = XCreatePixmap(dpy, scr->root_win, wPreferences.icon_size, wPreferences.icon_size, scr->depth);
	if (scr->w_visual == DefaultVisual(dpy, scr->screen))
		XCopyArea(dpy, win, tmp, scr->copy_gc, 0, 0, wPreferences.icon_size, wPreferences.icon_size, 0, 0);
	else {
		XImage *image;

		image = XGetImage(dpy, win, 0, 0, wPreferences.icon_size,
				  wPreferences.icon_size, AllPlanes, ZPixmap);
		if (!image) {
			XUnmapWindow(dpy, win);
			return;
		}
		XPutImage(dpy, tmp, scr->copy_gc, image, 0, 0, 0, 0,
			  wPreferences.icon_size, wPreferences.icon_size);
		XDestroyImage(image);
	}

	for (i = 0, k = 0; i < wPreferences.icon_size / ICON_KABOOM_PIECE_SIZE && k < PIECES; i++) {
		for (j = 0; j < wPreferences.icon_size / ICON_KABOOM_PIECE_SIZE && k < PIECES; j++) {
			if (rand() % 2) {
				ax[k] = i;
				ay[k] = j;
				px[k] = (x + i * ICON_KABOOM_PIECE_SIZE) << KAB_PRECISION;
				py[k] = y + j * ICON_KABOOM_PIECE_SIZE;
				pvx[k] = rand() % (1 << (KAB_PRECISION + 3)) - (1 << (KAB_PRECISION + 3)) / 2;
				pvy[k] = -15 - rand() % 7;
				k++;
			} else {
				ax[k] = -1;
			}
		}
	}

	XUnmapWindow(dpy, win);

	j = k;
	while (k > 0) {
		XEvent foo;

		if (XCheckTypedEvent(dpy, ButtonPress, &foo)) {
			XPutBackEvent(dpy, &foo);
			XClearWindow(dpy, scr->root_win);
			break;
		}

		for (i = 0; i < j; i++) {
			if (ax[i] >= 0) {
				int _px = px[i] >> KAB_PRECISION;
				XClearArea(dpy, scr->root_win, _px, py[i],
					   ICON_KABOOM_PIECE_SIZE, ICON_KABOOM_PIECE_SIZE, False);
				px[i] += pvx[i];
				py[i] += pvy[i];
				_px = px[i] >> KAB_PRECISION;
				pvy[i]++;
				if (_px < -wPreferences.icon_size || _px > sw || py[i] >= sh) {
					ax[i] = -1;
					k--;
				} else {
					XCopyArea(dpy, tmp, scr->root_win, scr->copy_gc,
						  ax[i] * ICON_KABOOM_PIECE_SIZE, ay[i] * ICON_KABOOM_PIECE_SIZE,
						  ICON_KABOOM_PIECE_SIZE, ICON_KABOOM_PIECE_SIZE, _px, py[i]);
				}
			}
		}

		XFlush(dpy);
		wusleep(MINIATURIZE_ANIMATION_DELAY_Z * 2);
	}

	XFreePixmap(dpy, tmp);
#endif	/* NORMAL_ICON_KABOOM */
}

Pixmap MakeGhostIcon(WScreen * scr, Drawable drawable)
{
	RImage *back;
	RColor color;
	Pixmap pixmap;

	if (!drawable)
		return None;

	back = RCreateImageFromDrawable(scr->rcontext, drawable, None);
	if (!back)
		return None;

	color.red = 0xff;
	color.green = 0xff;
	color.blue = 0xff;
	color.alpha = 200;

	RClearImage(back, &color);
	RConvertImage(scr->rcontext, back, &pixmap);

	RReleaseImage(back);

	return pixmap;
}

void DoWindowBirth(WWindow *wwin)
{
#ifdef WINDOW_BIRTH_ZOOM
	int center_x, center_y;
	int width = wwin->frame->core->width;
	int height = wwin->frame->core->height;
	int w = WMIN(width, 20);
	int h = WMIN(height, 20);
	WScreen *scr = wwin->screen_ptr;

	center_x = wwin->frame_x + (width - w) / 2;
	center_y = wwin->frame_y + (height - h) / 2;

	animateResize(scr, center_x, center_y, 1, 1, wwin->frame_x, wwin->frame_y, width, height);
#else
	/* Parameter not used, but tell the compiler that it is ok */
	(void) wwin;
#endif
}

typedef struct AppBouncerData {
	WApplication *wapp;
	int count;
	int pow;
	int dir;
	WMHandlerID *timer;
} AppBouncerData;

static void doAppBounce(void *arg)
{
	AppBouncerData *data = (AppBouncerData*)arg;
	WAppIcon *aicon = data->wapp->app_icon;

	if (!aicon)
		return;

reinit:
	if (data->wapp->refcount > 1) {
		if (wPreferences.raise_appicons_when_bouncing)
			XRaiseWindow(dpy, aicon->icon->core->window);

		const double ticks = BOUNCE_HZ * BOUNCE_LENGTH;
		const double s = sqrt(BOUNCE_HEIGHT)/(ticks/2);
		double h = BOUNCE_HEIGHT*pow(BOUNCE_DAMP, data->pow);
		double sqrt_h = sqrt(h);
		if (h > 3) {
			double offset, x = s * data->count - sqrt_h;
			if (x > sqrt_h) {
				++data->pow;
				data->count = 0;
				goto reinit;
			} else ++data->count;
			offset = h - x*x;

			switch (data->dir) {
			case 0: /* left, bounce to right */
				XMoveWindow(dpy, aicon->icon->core->window,
					    aicon->x_pos + (int)offset, aicon->y_pos);
				break;
			case 1: /* right, bounce to left */
				XMoveWindow(dpy, aicon->icon->core->window,
					    aicon->x_pos - (int)offset, aicon->y_pos);
				break;
			case 2: /* top, bounce down */
				XMoveWindow(dpy, aicon->icon->core->window,
					    aicon->x_pos, aicon->y_pos + (int)offset);
				break;
			case 3: /* bottom, bounce up */
				XMoveWindow(dpy, aicon->icon->core->window,
					    aicon->x_pos, aicon->y_pos - (int)offset);
				break;
			}
			return;
		}
	}

	XMoveWindow(dpy, aicon->icon->core->window,
			aicon->x_pos, aicon->y_pos);
	CommitStackingForWindow(aicon->icon->core);
	data->wapp->flags.bouncing = 0;
	WMDeleteTimerHandler(data->timer);
	wApplicationDestroy(data->wapp);
	free(data);
}

static int bounceDirection(WAppIcon *aicon)
{
	enum { left_e = 1, right_e = 2, top_e = 4, bottom_e = 8 };

	WScreen *scr = aicon->icon->core->screen_ptr;
	WMRect rr, sr;
	int l, r, t, b, h, v;
	int dir = 0;

	rr.pos.x = aicon->x_pos;
	rr.pos.y = aicon->y_pos;
	rr.size.width = rr.size.height = 64;

	sr = wGetRectForHead(scr, wGetHeadForRect(scr, rr));

	l = rr.pos.x - sr.pos.x;
	r = sr.pos.x + sr.size.width - rr.pos.x - rr.size.width;
	t = rr.pos.y - sr.pos.y;
	b = sr.pos.y + sr.size.height - rr.pos.y - rr.size.height;

	if (l < r) {
		dir |= left_e;
		h = l;
	} else {
		dir |= right_e;
		h = r;
	}

	if (t < b) {
		dir |= top_e;
		v = t;
	} else {
		dir |= bottom_e;
		v = b;
	}

	if (aicon->dock && abs(aicon->xindex) != abs(aicon->yindex)) {
		if (abs(aicon->xindex) < abs(aicon->yindex)) dir &= ~(top_e | bottom_e);
		else dir &= ~(left_e | right_e);
	} else {
		if (h < v) dir &= ~(top_e | bottom_e);
		else dir &= ~(left_e | right_e);
	}

	switch (dir) {
	case left_e:
		dir = 0;
		break;

	case right_e:
		dir = 1;
		break;

	case top_e:
		dir = 2;
		break;

	case bottom_e:
		dir = 3;
		break;

	default:
		wwarning(_("Impossible direction: %d"), dir);
		dir = 3;
		break;
	}

	return dir;
}

void wAppBounce(WApplication *wapp)
{
	if (!wPreferences.no_animations && wapp->app_icon && !wapp->flags.bouncing
		&& !wPreferences.do_not_make_appicons_bounce) {
		++wapp->refcount;
		wapp->flags.bouncing = 1;

		AppBouncerData *data = (AppBouncerData *)malloc(sizeof(AppBouncerData));
		data->wapp = wapp;
		data->count = data->pow = 0;
		data->dir = bounceDirection(wapp->app_icon);
		data->timer = WMAddPersistentTimerHandler(BOUNCE_DELAY, doAppBounce, data);
	}
}

static int appIsUrgent(WApplication *wapp)
{
	WScreen *scr;
	WWindow *wlist;

	if (!wapp->main_window_desc) {
		wwarning("group leader not found for window group");
		return 0;
	}
	scr = wapp->main_window_desc->screen_ptr;
	wlist = scr->focused_window;
	if (!wlist)
		return 0;

	while (wlist) {
		if (wlist->main_window == wapp->main_window) {
			if (wlist->flags.urgent)
				return 1;
		}
		wlist = wlist->prev;
	}

	return 0;
}

static void doAppUrgentBounce(void *arg)
{
	WApplication *wapp = (WApplication *)arg;

	if (appIsUrgent(wapp)) {
		if(wPreferences.bounce_appicons_when_urgent) wAppBounce(wapp);
	} else {
		WMDeleteTimerHandler(wapp->urgent_bounce_timer);
		wapp->urgent_bounce_timer = NULL;
	}
}

void wAppBounceWhileUrgent(WApplication *wapp)
{
	if (!wapp) return;
	if (appIsUrgent(wapp)) {
		if (!wapp->urgent_bounce_timer) {
			wapp->urgent_bounce_timer = WMAddPersistentTimerHandler(URGENT_BOUNCE_DELAY, doAppUrgentBounce, wapp);
			doAppUrgentBounce(wapp);
		}
	} else {
		if (wapp->urgent_bounce_timer) {
			WMDeleteTimerHandler(wapp->urgent_bounce_timer);
			wapp->urgent_bounce_timer = NULL;
		}
	}
}
