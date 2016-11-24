
#include "WINGsP.h"

#include "wconfig.h"

#include <wraster.h>

#define LIGHT_STIPPLE_WIDTH 4
#define LIGHT_STIPPLE_HEIGHT 4
static char LIGHT_STIPPLE_BITS[] = {
	0x05, 0x0a, 0x05, 0x0a
};

#define DARK_STIPPLE_WIDTH 4
#define DARK_STIPPLE_HEIGHT 4
static char DARK_STIPPLE_BITS[] = {
	0x0a, 0x04, 0x0a, 0x01
};

static WMColor *createRGBAColor(WMScreen * scr, unsigned short red,
				unsigned short green, unsigned short blue, unsigned short alpha);

/*
 * TODO: make the color creation code return the same WMColor for the
 * same colors.
 * make findCloseColor() find the closest color in the RContext pallette
 * or in the other colors allocated by WINGs.
 */

static WMColor *findCloseColor(WMScreen * scr, unsigned short red, unsigned short green,
			       unsigned short blue, unsigned short alpha)
{
	WMColor *color;
	XColor xcolor;
	RColor rcolor;

	rcolor.red = red >> 8;
	rcolor.green = green >> 8;
	rcolor.blue = blue >> 8;
	rcolor.alpha = alpha >> 8;

	if (!RGetClosestXColor(scr->rcontext, &rcolor, &xcolor))
		return NULL;

	if (!XAllocColor(scr->display, scr->colormap, &xcolor))
		return NULL;

	color = wmalloc(sizeof(WMColor));

	color->screen = scr;
	color->refCount = 1;
	color->color = xcolor;
	color->alpha = alpha;
	color->flags.exact = 1;
	color->gc = NULL;

	return color;
}

static WMColor *createRGBAColor(WMScreen * scr, unsigned short red, unsigned short green,
				unsigned short blue, unsigned short alpha)
{
	WMColor *color;
	XColor xcolor;

	xcolor.red = red;
	xcolor.green = green;
	xcolor.blue = blue;
	xcolor.flags = DoRed | DoGreen | DoBlue;
	if (!XAllocColor(scr->display, scr->colormap, &xcolor))
		return NULL;

	color = wmalloc(sizeof(WMColor));

	color->screen = scr;
	color->refCount = 1;
	color->color = xcolor;
	color->alpha = alpha;
	color->flags.exact = 1;
	color->gc = NULL;

	return color;
}

WMColor *WMCreateRGBColor(WMScreen * scr, unsigned short red, unsigned short green,
			  unsigned short blue, Bool exact)
{
	WMColor *color = NULL;

	if (!exact || !(color = createRGBAColor(scr, red, green, blue, 0xffff))) {
		color = findCloseColor(scr, red, green, blue, 0xffff);
	}
	if (!color)
		color = WMBlackColor(scr);

	return color;
}

RColor WMGetRColorFromColor(WMColor * color)
{
	RColor rcolor;

	rcolor.red = color->color.red >> 8;
	rcolor.green = color->color.green >> 8;
	rcolor.blue = color->color.blue >> 8;
	rcolor.alpha = color->alpha >> 8;

	return rcolor;
}

WMColor *WMCreateRGBAColor(WMScreen * scr, unsigned short red, unsigned short green,
			   unsigned short blue, unsigned short alpha, Bool exact)
{
	WMColor *color = NULL;

	if (!exact || !(color = createRGBAColor(scr, red, green, blue, alpha))) {
		color = findCloseColor(scr, red, green, blue, alpha);
	}
	if (!color)
		color = WMBlackColor(scr);

	return color;
}

WMColor *WMCreateNamedColor(WMScreen * scr, const char *name, Bool exact)
{
	WMColor *color;
	XColor xcolor;

	if (!XParseColor(scr->display, scr->colormap, name, &xcolor))
		return NULL;

	if (scr->visual->class == TrueColor)
		exact = True;

	if (!exact || !(color = createRGBAColor(scr, xcolor.red, xcolor.green, xcolor.blue, 0xffff))) {
		color = findCloseColor(scr, xcolor.red, xcolor.green, xcolor.blue, 0xffff);
	}
	return color;
}

WMColor *WMRetainColor(WMColor * color)
{
	assert(color != NULL);

	color->refCount++;

	return color;
}

void WMReleaseColor(WMColor * color)
{
	color->refCount--;

	if (color->refCount < 1) {
		XFreeColors(color->screen->display, color->screen->colormap, &(color->color.pixel), 1, 0);
		if (color->gc)
			XFreeGC(color->screen->display, color->gc);
		wfree(color);
	}
}

void WMSetColorAlpha(WMColor * color, unsigned short alpha)
{
	color->alpha = alpha;
}

void WMPaintColorSwatch(WMColor * color, Drawable d, int x, int y, unsigned int width, unsigned int height)
{
	XFillRectangle(color->screen->display, d, WMColorGC(color), x, y, width, height);
}

WMPixel WMColorPixel(WMColor * color)
{
	return color->color.pixel;
}

GC WMColorGC(WMColor * color)
{
	if (!color->gc) {
		XGCValues gcv;
		WMScreen *scr = color->screen;

		gcv.foreground = color->color.pixel;
		gcv.graphics_exposures = False;
		color->gc = XCreateGC(scr->display, scr->rcontext->drawable,
				      GCForeground | GCGraphicsExposures, &gcv);
	}

	return color->gc;
}

void WMSetColorInGC(WMColor * color, GC gc)
{
	XSetForeground(color->screen->display, gc, color->color.pixel);
}

/* "system" colors */
WMColor *WMWhiteColor(WMScreen * scr)
{
	if (!scr->white) {
		scr->white = WMCreateRGBColor(scr, 0xffff, 0xffff, 0xffff, True);
		if (!scr->white->flags.exact)
			wwarning(_("could not allocate %s color"), _("white"));
	}
	return WMRetainColor(scr->white);
}

WMColor *WMBlackColor(WMScreen * scr)
{
	if (!scr->black) {
		scr->black = WMCreateRGBColor(scr, 0, 0, 0, True);
		if (!scr->black->flags.exact)
			wwarning(_("could not allocate %s color"), _("black"));
	}
	return WMRetainColor(scr->black);
}

WMColor *WMGrayColor(WMScreen * scr)
{
	if (!scr->gray) {
		WMColor *color;

		if (scr->depth == 1) {
			Pixmap stipple;
			WMColor *white = WMWhiteColor(scr);
			WMColor *black = WMBlackColor(scr);
			XGCValues gcv;

			stipple = XCreateBitmapFromData(scr->display, W_DRAWABLE(scr),
							LIGHT_STIPPLE_BITS, LIGHT_STIPPLE_WIDTH,
							LIGHT_STIPPLE_HEIGHT);

			color = createRGBAColor(scr, 0xffff, 0xffff, 0xffff, 0xffff);

			gcv.foreground = white->color.pixel;
			gcv.background = black->color.pixel;
			gcv.fill_style = FillStippled;
			gcv.stipple = stipple;
			color->gc = XCreateGC(scr->display, W_DRAWABLE(scr), GCForeground
					      | GCBackground | GCStipple | GCFillStyle
					      | GCGraphicsExposures, &gcv);

			XFreePixmap(scr->display, stipple);
			WMReleaseColor(white);
			WMReleaseColor(black);
		} else {
			color = WMCreateRGBColor(scr, 0xaeba, 0xaaaa, 0xaeba, True);
			if (!color->flags.exact)
				wwarning(_("could not allocate %s color"), _("gray"));
		}
		scr->gray = color;
	}
	return WMRetainColor(scr->gray);
}

WMColor *WMDarkGrayColor(WMScreen * scr)
{
	if (!scr->darkGray) {
		WMColor *color;

		if (scr->depth == 1) {
			Pixmap stipple;
			WMColor *white = WMWhiteColor(scr);
			WMColor *black = WMBlackColor(scr);
			XGCValues gcv;

			stipple = XCreateBitmapFromData(scr->display, W_DRAWABLE(scr),
							DARK_STIPPLE_BITS, DARK_STIPPLE_WIDTH,
							DARK_STIPPLE_HEIGHT);

			color = createRGBAColor(scr, 0, 0, 0, 0xffff);

			gcv.foreground = white->color.pixel;
			gcv.background = black->color.pixel;
			gcv.fill_style = FillStippled;
			gcv.stipple = stipple;
			color->gc = XCreateGC(scr->display, W_DRAWABLE(scr), GCForeground
					      | GCBackground | GCStipple | GCFillStyle
					      | GCGraphicsExposures, &gcv);

			XFreePixmap(scr->display, stipple);
			WMReleaseColor(white);
			WMReleaseColor(black);
		} else {
			color = WMCreateRGBColor(scr, 0x5144, 0x5555, 0x5144, True);
			if (!color->flags.exact)
				wwarning(_("could not allocate %s color"), _("dark gray"));
		}
		scr->darkGray = color;
	}
	return WMRetainColor(scr->darkGray);
}

unsigned short WMRedComponentOfColor(WMColor * color)
{
	return color->color.red;
}

unsigned short WMGreenComponentOfColor(WMColor * color)
{
	return color->color.green;
}

unsigned short WMBlueComponentOfColor(WMColor * color)
{
	return color->color.blue;
}

unsigned short WMGetColorAlpha(WMColor * color)
{
	return color->alpha;
}

char *WMGetColorRGBDescription(WMColor * color)
{
	char *str = wmalloc(8);

	if (snprintf(str, 8, "#%02x%02x%02x",
		     color->color.red >> 8, color->color.green >> 8, color->color.blue >> 8) >= 8) {
		wfree(str);
		return NULL;
	}

	return str;
}
