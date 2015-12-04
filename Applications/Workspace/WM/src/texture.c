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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <wraster.h>

#include "WindowMaker.h"
#include "texture.h"
#include "window.h"
#include "misc.h"


static void bevelImage(RImage * image, int relief);
static RImage * get_texture_image(WScreen *scr, const char *pixmap_file);

WTexSolid *wTextureMakeSolid(WScreen * scr, XColor * color)
{
	WTexSolid *texture;
	int gcm;
	XGCValues gcv;

	texture = wmalloc(sizeof(WTexture));

	texture->type = WTEX_SOLID;
	texture->subtype = 0;

	XAllocColor(dpy, scr->w_colormap, color);
	texture->normal = *color;
	if (color->red == 0 && color->blue == 0 && color->green == 0) {
		texture->light.red = 0xb6da;
		texture->light.green = 0xb6da;
		texture->light.blue = 0xb6da;
		texture->dim.red = 0x6185;
		texture->dim.green = 0x6185;
		texture->dim.blue = 0x6185;
	} else {
		RColor rgb;
		RHSVColor hsv, hsv2;
		int v;

		rgb.red = color->red >> 8;
		rgb.green = color->green >> 8;
		rgb.blue = color->blue >> 8;
		RRGBtoHSV(&rgb, &hsv);
		RHSVtoRGB(&hsv, &rgb);
		hsv2 = hsv;

		v = hsv.value * 16 / 10;
		hsv.value = (v > 255 ? 255 : v);
		RHSVtoRGB(&hsv, &rgb);
		texture->light.red = rgb.red << 8;
		texture->light.green = rgb.green << 8;
		texture->light.blue = rgb.blue << 8;

		hsv2.value = hsv2.value / 2;
		RHSVtoRGB(&hsv2, &rgb);
		texture->dim.red = rgb.red << 8;
		texture->dim.green = rgb.green << 8;
		texture->dim.blue = rgb.blue << 8;
	}
	texture->dark.red = 0;
	texture->dark.green = 0;
	texture->dark.blue = 0;
	XAllocColor(dpy, scr->w_colormap, &texture->light);
	XAllocColor(dpy, scr->w_colormap, &texture->dim);
	XAllocColor(dpy, scr->w_colormap, &texture->dark);

	gcm = GCForeground | GCBackground | GCGraphicsExposures;
	gcv.graphics_exposures = False;

	gcv.background = gcv.foreground = texture->light.pixel;
	texture->light_gc = XCreateGC(dpy, scr->w_win, gcm, &gcv);

	gcv.background = gcv.foreground = texture->dim.pixel;
	texture->dim_gc = XCreateGC(dpy, scr->w_win, gcm, &gcv);

	gcv.background = gcv.foreground = texture->dark.pixel;
	texture->dark_gc = XCreateGC(dpy, scr->w_win, gcm, &gcv);

	gcv.background = gcv.foreground = color->pixel;
	texture->normal_gc = XCreateGC(dpy, scr->w_win, gcm, &gcv);

	return texture;
}

static int dummyErrorHandler(Display * foo, XErrorEvent * bar)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) foo;
	(void) bar;

	return 0;
}

void wTextureDestroy(WScreen * scr, WTexture * texture)
{
	int i;
	int count = 0;
	unsigned long colors[8];

	/*
	 * some stupid servers don't like white or black being freed...
	 */
#define CANFREE(c) (c!=scr->black_pixel && c!=scr->white_pixel && c!=0)
	switch (texture->any.type) {
	case WTEX_SOLID:
		XFreeGC(dpy, texture->solid.light_gc);
		XFreeGC(dpy, texture->solid.dark_gc);
		XFreeGC(dpy, texture->solid.dim_gc);
		if (CANFREE(texture->solid.light.pixel))
			colors[count++] = texture->solid.light.pixel;
		if (CANFREE(texture->solid.dim.pixel))
			colors[count++] = texture->solid.dim.pixel;
		if (CANFREE(texture->solid.dark.pixel))
			colors[count++] = texture->solid.dark.pixel;
		break;

	case WTEX_PIXMAP:
		RReleaseImage(texture->pixmap.pixmap);
		break;

	case WTEX_MHGRADIENT:
	case WTEX_MVGRADIENT:
	case WTEX_MDGRADIENT:
		for (i = 0; texture->mgradient.colors[i] != NULL; i++) {
			wfree(texture->mgradient.colors[i]);
		}
		wfree(texture->mgradient.colors);
		break;

	case WTEX_THGRADIENT:
	case WTEX_TVGRADIENT:
	case WTEX_TDGRADIENT:
		RReleaseImage(texture->tgradient.pixmap);
		break;
	}

	if (CANFREE(texture->any.color.pixel))
		colors[count++] = texture->any.color.pixel;
	if (count > 0) {
		XErrorHandler oldhandler;

		/* ignore error from buggy servers that don't know how
		 * to do reference counting for colors. */
		XSync(dpy, 0);
		oldhandler = XSetErrorHandler(dummyErrorHandler);
		XFreeColors(dpy, scr->w_colormap, colors, count, 0);
		XSync(dpy, 0);
		XSetErrorHandler(oldhandler);
	}
	XFreeGC(dpy, texture->any.gc);
	wfree(texture);
#undef CANFREE
}

WTexGradient *wTextureMakeGradient(WScreen *scr, int style, const RColor *from, const RColor *to)
{
	WTexGradient *texture;
	XGCValues gcv;

	texture = wmalloc(sizeof(WTexture));
	texture->type = style;
	texture->subtype = 0;

	texture->color1 = *from;
	texture->color2 = *to;

	texture->normal.red = (from->red + to->red) << 7;
	texture->normal.green = (from->green + to->green) << 7;
	texture->normal.blue = (from->blue + to->blue) << 7;

	XAllocColor(dpy, scr->w_colormap, &texture->normal);
	gcv.background = gcv.foreground = texture->normal.pixel;
	gcv.graphics_exposures = False;
	texture->normal_gc = XCreateGC(dpy, scr->w_win, GCForeground | GCBackground | GCGraphicsExposures, &gcv);

	return texture;
}

WTexIGradient *wTextureMakeIGradient(WScreen *scr, int thickness1, const RColor colors1[2],
				     int thickness2, const RColor colors2[2])
{
	WTexIGradient *texture;
	XGCValues gcv;
	int i;

	texture = wmalloc(sizeof(WTexture));
	texture->type = WTEX_IGRADIENT;
	for (i = 0; i < 2; i++) {
		texture->colors1[i] = colors1[i];
		texture->colors2[i] = colors2[i];
	}
	texture->thickness1 = thickness1;
	texture->thickness2 = thickness2;
	if (thickness1 >= thickness2) {
		texture->normal.red = (colors1[0].red + colors1[1].red) << 7;
		texture->normal.green = (colors1[0].green + colors1[1].green) << 7;
		texture->normal.blue = (colors1[0].blue + colors1[1].blue) << 7;
	} else {
		texture->normal.red = (colors2[0].red + colors2[1].red) << 7;
		texture->normal.green = (colors2[0].green + colors2[1].green) << 7;
		texture->normal.blue = (colors2[0].blue + colors2[1].blue) << 7;
	}
	XAllocColor(dpy, scr->w_colormap, &texture->normal);
	gcv.background = gcv.foreground = texture->normal.pixel;
	gcv.graphics_exposures = False;
	texture->normal_gc = XCreateGC(dpy, scr->w_win, GCForeground | GCBackground | GCGraphicsExposures, &gcv);

	return texture;
}

WTexMGradient *wTextureMakeMGradient(WScreen * scr, int style, RColor ** colors)
{
	WTexMGradient *texture;
	XGCValues gcv;
	int i;

	texture = wmalloc(sizeof(WTexture));
	texture->type = style;
	texture->subtype = 0;

	i = 0;
	while (colors[i] != NULL)
		i++;
	i--;
	texture->normal.red = (colors[0]->red << 8);
	texture->normal.green = (colors[0]->green << 8);
	texture->normal.blue = (colors[0]->blue << 8);

	texture->colors = colors;

	XAllocColor(dpy, scr->w_colormap, &texture->normal);
	gcv.background = gcv.foreground = texture->normal.pixel;
	gcv.graphics_exposures = False;
	texture->normal_gc = XCreateGC(dpy, scr->w_win, GCForeground | GCBackground | GCGraphicsExposures, &gcv);

	return texture;
}

WTexPixmap *wTextureMakePixmap(WScreen *scr, int style, const char *pixmap_file, XColor *color)
{
	WTexPixmap *texture;
	XGCValues gcv;
	RImage *image;

	image = get_texture_image(scr, pixmap_file);
	if (!image)
		return NULL;

	texture = wmalloc(sizeof(WTexture));
	texture->type = WTEX_PIXMAP;
	texture->subtype = style;

	texture->normal = *color;

	XAllocColor(dpy, scr->w_colormap, &texture->normal);
	gcv.background = gcv.foreground = texture->normal.pixel;
	gcv.graphics_exposures = False;
	texture->normal_gc = XCreateGC(dpy, scr->w_win, GCForeground | GCBackground | GCGraphicsExposures, &gcv);

	texture->pixmap = image;

	return texture;
}

WTexTGradient *wTextureMakeTGradient(WScreen *scr, int style, const RColor *from, const RColor *to,
				     const char *pixmap_file, int opacity)
{
	WTexTGradient *texture;
	XGCValues gcv;
	RImage *image;

	image = get_texture_image(scr, pixmap_file);
	if (!image)
		return NULL;

	texture = wmalloc(sizeof(WTexture));
	texture->type = style;

	texture->opacity = opacity;

	texture->color1 = *from;
	texture->color2 = *to;

	texture->normal.red = (from->red + to->red) << 7;
	texture->normal.green = (from->green + to->green) << 7;
	texture->normal.blue = (from->blue + to->blue) << 7;

	XAllocColor(dpy, scr->w_colormap, &texture->normal);
	gcv.background = gcv.foreground = texture->normal.pixel;
	gcv.graphics_exposures = False;
	texture->normal_gc = XCreateGC(dpy, scr->w_win, GCForeground | GCBackground | GCGraphicsExposures, &gcv);

	texture->pixmap = image;

	return texture;
}

static RImage * get_texture_image(WScreen *scr, const char *pixmap_file)
{
	char *file;
	RImage *image;

	file = FindImage(wPreferences.pixmap_path, pixmap_file);
	if (!file) {
		wwarning(_("image file \"%s\" used as texture could not be found."), pixmap_file);
		return NULL;
	}
	image = RLoadImage(scr->rcontext, file, 0);
	if (!image) {
		wwarning(_("could not load texture pixmap \"%s\":%s"), file, RMessageForError(RErrorCode));
		wfree(file);
		return NULL;
	}
	wfree(file);

	return image;
}

RImage *wTextureRenderImage(WTexture * texture, int width, int height, int relief)
{
	RImage *image = NULL;
	RColor color1;
	int d;
	int subtype;

	switch (texture->any.type) {
	case WTEX_SOLID:
		image = RCreateImage(width, height, False);

		color1.red = texture->solid.normal.red >> 8;
		color1.green = texture->solid.normal.green >> 8;
		color1.blue = texture->solid.normal.blue >> 8;
		color1.alpha = 255;

		RClearImage(image, &color1);
		break;

	case WTEX_PIXMAP:
		if (texture->pixmap.subtype == WTP_TILE) {
			image = RMakeTiledImage(texture->pixmap.pixmap, width, height);
		} else if (texture->pixmap.subtype == WTP_CENTER) {
			color1.red = texture->pixmap.normal.red >> 8;
			color1.green = texture->pixmap.normal.green >> 8;
			color1.blue = texture->pixmap.normal.blue >> 8;
			color1.alpha = 255;
			image = RMakeCenteredImage(texture->pixmap.pixmap, width, height, &color1);
		} else {
			image = RScaleImage(texture->pixmap.pixmap, width, height);
		}
		break;

	case WTEX_IGRADIENT:
		image = RRenderInterwovenGradient(width, height,
						  texture->igradient.colors1,
						  texture->igradient.thickness1,
						  texture->igradient.colors2, texture->igradient.thickness2);
		break;

	case WTEX_HGRADIENT:
		subtype = RGRD_HORIZONTAL;
		goto render_gradient;

	case WTEX_VGRADIENT:
		subtype = RGRD_VERTICAL;
		goto render_gradient;

	case WTEX_DGRADIENT:
		subtype = RGRD_DIAGONAL;
 render_gradient:

		image = RRenderGradient(width, height, &texture->gradient.color1,
					&texture->gradient.color2, subtype);
		break;

	case WTEX_MHGRADIENT:
		subtype = RGRD_HORIZONTAL;
		goto render_mgradient;

	case WTEX_MVGRADIENT:
		subtype = RGRD_VERTICAL;
		goto render_mgradient;

	case WTEX_MDGRADIENT:
		subtype = RGRD_DIAGONAL;
 render_mgradient:
		image = RRenderMultiGradient(width, height, &(texture->mgradient.colors[1]), subtype);
		break;

	case WTEX_THGRADIENT:
		subtype = RGRD_HORIZONTAL;
		goto render_tgradient;

	case WTEX_TVGRADIENT:
		subtype = RGRD_VERTICAL;
		goto render_tgradient;

	case WTEX_TDGRADIENT:
		subtype = RGRD_DIAGONAL;
 render_tgradient:
		{
			RImage *grad;

			image = RMakeTiledImage(texture->tgradient.pixmap, width, height);
			if (!image)
				break;

			grad = RRenderGradient(width, height, &texture->tgradient.color1,
					       &texture->tgradient.color2, subtype);
			if (!grad) {
				RReleaseImage(image);
				image = NULL;
				break;
			}

			RCombineImagesWithOpaqueness(image, grad, texture->tgradient.opacity);
			RReleaseImage(grad);
		}
		break;
	default:
		puts("ERROR in wTextureRenderImage()");
		image = NULL;
		break;
	}

	if (!image) {
		RColor gray;

		wwarning(_("could not render texture: %s"), RMessageForError(RErrorCode));

		image = RCreateImage(width, height, False);
		if (image == NULL) {
			wwarning(_("could not allocate image buffer"));
			return NULL;
		}

		gray.red = 190;
		gray.green = 190;
		gray.blue = 190;
		gray.alpha = 255;
		RClearImage(image, &gray);
	}

	/* render bevel */

	switch (relief) {
	case WREL_ICON:
		d = RBEV_RAISED3;
		break;

	case WREL_RAISED:
		d = RBEV_RAISED2;
		break;

	case WREL_SUNKEN:
		d = RBEV_SUNKEN;
		break;

	case WREL_FLAT:
		d = 0;
		break;

	case WREL_MENUENTRY:
		d = -WREL_MENUENTRY;
		break;

	default:
		d = 0;
	}

	if (d > 0) {
		RBevelImage(image, d);
	} else if (d < 0) {
		bevelImage(image, -d);
	}

	return image;
}

static void bevelImage(RImage * image, int relief)
{
	int width = image->width;
	int height = image->height;
	RColor color;

	switch (relief) {
	case WREL_MENUENTRY:
		color.red = color.green = color.blue = 80;
		color.alpha = 0;
		 /**/ ROperateLine(image, RAddOperation, 1, 0, width - 2, 0, &color);
		 /**/ ROperateLine(image, RAddOperation, 0, 0, 0, height - 1, &color);

		color.red = color.green = color.blue = 40;
		color.alpha = 0;
		ROperateLine(image, RSubtractOperation, width - 1, 0, width - 1, height - 1, &color);

		 /**/ ROperateLine(image, RSubtractOperation, 1, height - 2, width - 2, height - 2, &color);

		color.red = color.green = color.blue = 0;
		color.alpha = 255;
		RDrawLine(image, 0, height - 1, width - 1, height - 1, &color);
		 /**/ break;

	}
}

void wDrawBevel(Drawable d, unsigned width, unsigned height, WTexSolid * texture, int relief)
{
	GC light, dim, dark;
	XSegment segs[4];

	if (relief == WREL_FLAT)
		return;

	light = texture->light_gc;
	dim = texture->dim_gc;
	dark = texture->dark_gc;
	switch (relief) {
	case WREL_MENUENTRY:
	case WREL_RAISED:
	case WREL_ICON:
		segs[0].x1 = 1;
		segs[0].x2 = width - 2;
		segs[0].y2 = segs[0].y1 = height - 2;
		segs[1].x1 = width - 2;
		segs[1].y1 = 1;
		segs[1].x2 = width - 2;
		segs[1].y2 = height - 2;
		if (wPreferences.new_style == TS_NEXT) {
			XDrawSegments(dpy, d, dark, segs, 2);
		} else {
			XDrawSegments(dpy, d, dim, segs, 2);
		}
		segs[0].x1 = 0;
		segs[0].x2 = width - 1;
		segs[0].y2 = segs[0].y1 = height - 1;
		segs[1].x1 = segs[1].x2 = width - 1;
		segs[1].y1 = 0;
		segs[1].y2 = height - 1;
		if (wPreferences.new_style == TS_NEXT) {
			XDrawSegments(dpy, d, light, segs, 2);
		} else {
			XDrawSegments(dpy, d, dark, segs, 2);
		}
		segs[0].x1 = segs[0].y1 = segs[0].y2 = 0;
		segs[0].x2 = width - 2;
		segs[1].x1 = segs[1].y1 = 0;
		segs[1].x2 = 0;
		segs[1].y2 = height - 2;
		if (wPreferences.new_style == TS_NEXT) {
			XDrawSegments(dpy, d, dark, segs, 2);
		} else {
			XDrawSegments(dpy, d, light, segs, 2);
		}
		if (relief == WREL_ICON) {
			segs[0].x1 = segs[0].y1 = segs[0].y2 = 1;
			segs[0].x2 = width - 2;
			segs[1].x1 = segs[1].y1 = 1;
			segs[1].x2 = 1;
			segs[1].y2 = height - 2;
			XDrawSegments(dpy, d, light, segs, 2);
		}
		break;
	}
}
