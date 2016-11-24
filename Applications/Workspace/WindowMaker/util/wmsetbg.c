/* wmsetbg.c- sets root window background image and also works as
 * 		workspace background setting helper for wmaker
 *
 *  WindowMaker window manager
 *
 *  Copyright (c) 1998-2003 Alfredo K. Kojima
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

/*
 * TODO: rewrite, too dirty
 */
#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <string.h>
#include <strings.h>
#include <pwd.h>
#include <signal.h>
#include <sys/types.h>
#include <ctype.h>

#ifdef USE_XINERAMA
# ifdef SOLARIS_XINERAMA	/* sucks */
#  include <X11/extensions/xinerama.h>
# else
#  include <X11/extensions/Xinerama.h>
# endif
#endif

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#include "../src/wconfig.h"


#include <WINGs/WINGs.h>
#include <wraster.h>

typedef struct {
	WMRect *screens;
	int count;		/* screen count, 0 = inactive */
} WXineramaInfo;

#define WORKSPACE_COUNT (MAX_WORKSPACES+1)

Display *dpy;
char *display = "";
Window root;
int scr;
int scrWidth;
int scrHeight;
int scrX, scrY;

WXineramaInfo xineInfo;

Bool smooth = False;
#ifdef USE_XINERAMA
Bool xineStretch = False;
#endif

Pixmap CurrentPixmap = None;
char *PixmapPath = NULL;

static const char *prog_name;

typedef struct BackgroundTexture {
	int refcount;

	int solid;

	char *spec;

	XColor color;
	Pixmap pixmap;		/* for all textures, including solid */
	int width;		/* size of the pixmap */
	int height;
} BackgroundTexture;

static noreturn void quit(int rcode)
{
	WMReleaseApplication();
	exit(rcode);
}

static void initXinerama(void)
{
	xineInfo.screens = NULL;
	xineInfo.count = 0;
#ifdef USE_XINERAMA
# ifdef SOLARIS_XINERAMA
	if (XineramaGetState(dpy, scr)) {
		XRectangle head[MAXFRAMEBUFFERS];
		unsigned char hints[MAXFRAMEBUFFERS];
		int i;

		if (XineramaGetInfo(dpy, scr, head, hints, &xineInfo.count)) {

			xineInfo.screens = wmalloc(sizeof(WMRect) * (xineInfo.count + 1));

			for (i = 0; i < xineInfo.count; i++) {
				xineInfo.screens[i].pos.x = head[i].x;
				xineInfo.screens[i].pos.y = head[i].y;
				xineInfo.screens[i].size.width = head[i].width;
				xineInfo.screens[i].size.height = head[i].height;
			}
		}
	}
# else				/* !SOLARIS_XINERAMA */
	if (XineramaIsActive(dpy)) {
		XineramaScreenInfo *xine_screens;
		int i;

		xine_screens = XineramaQueryScreens(dpy, &xineInfo.count);

		xineInfo.screens = wmalloc(sizeof(WMRect) * (xineInfo.count + 1));

		for (i = 0; i < xineInfo.count; i++) {
			xineInfo.screens[i].pos.x = xine_screens[i].x_org;
			xineInfo.screens[i].pos.y = xine_screens[i].y_org;
			xineInfo.screens[i].size.width = xine_screens[i].width;
			xineInfo.screens[i].size.height = xine_screens[i].height;
		}
		XFree(xine_screens);
	}
# endif				/* !SOLARIS_XINERAMA */
#endif				/* USE_XINERAMA */
}

static RImage *loadImage(RContext * rc, const char *file)
{
	char *path;
	RImage *image;

	if (access(file, F_OK) != 0) {
		path = wfindfile(PixmapPath, file);
		if (!path) {
			wwarning("%s:could not find image file used in texture", file);
			return NULL;
		}
	} else {
		path = wstrdup(file);
	}

	image = RLoadImage(rc, path, 0);
	if (!image) {
		wwarning("%s:could not load image file used in texture:%s", path, RMessageForError(RErrorCode));
	}
	wfree(path);

	return image;
}

static void
applyImage(RContext * rc, BackgroundTexture * texture, RImage * image, char type,
	   int x, int y, int width, int height)
{
	int w, h;
	Bool fimage = False;

	switch (toupper(type)) {
	case 'S':
	case 'M':
	case 'F':
		if (toupper(type) == 'S') {
			w = width;
			h = height;
		} else if(toupper(type) == 'F') {
			if (image->width * height > image->height * width) {
				w = (height * image->width) / image->height;
				h = height;
			} else {
				w = width;
				h = (width * image->height) / image->width;
			}
		} else {
			if (image->width * height > image->height * width) {
				w = width;
				h = (width * image->height) / image->width;
			} else {
				w = (height * image->width) / image->height;
				h = height;
			}
		}

		if (w != image->width || h != image->height) {
			RImage *simage;

			if (smooth) {
				simage = RSmoothScaleImage(image, w, h);
			} else {
				simage = RScaleImage(image, w, h);
			}

			if (!simage) {
				wwarning("could not scale image:%s", RMessageForError(RErrorCode));
				return;
			}
			fimage = True;
			image = simage;
		}

		/* fall through */
	case 'C':
		{
			Pixmap pixmap;

			if (!RConvertImage(rc, image, &pixmap)) {
				wwarning("could not convert texture:%s", RMessageForError(RErrorCode));
				if (fimage)
					RReleaseImage(image);
				return;
			}

			if (image->width != width || image->height != height) {
				int sx, sy, w, h;

				if (image->height < height) {
					h = image->height;
					y += (height - h) / 2;
					sy = 0;
				} else {
					sy = (image->height - height) / 2;
					h = height;
				}
				if (image->width < width) {
					w = image->width;
					x += (width - w) / 2;
					sx = 0;
				} else {
					sx = (image->width - width) / 2;
					w = width;
				}

				XCopyArea(dpy, pixmap, texture->pixmap, DefaultGC(dpy, scr), sx, sy, w, h, x, y);
			} else
				XCopyArea(dpy, pixmap, texture->pixmap, DefaultGC(dpy, scr), 0, 0, width, height,
					  x, y);

			XFreePixmap(dpy, pixmap);
			if (fimage) {
				RReleaseImage(image);
			}
		}
		break;
	}
}

static BackgroundTexture *parseTexture(RContext * rc, char *text)
{
	BackgroundTexture *texture = NULL;
	WMPropList *texarray;
	WMPropList *val;
	int count;
	char *tmp;
	char *type;

#define GETSTRORGOTO(val, str, i, label) \
    val = WMGetFromPLArray(texarray, i);\
    if (!WMIsPLString(val)) {\
    wwarning("could not parse texture %s", text);\
    goto label;\
    }\
    str = WMGetFromPLString(val)

	texarray = WMCreatePropListFromDescription(text);
	if (!texarray || !WMIsPLArray(texarray)
	    || (count = WMGetPropListItemCount(texarray)) < 2) {

		wwarning("could not parse texture %s", text);
		if (texarray)
			WMReleasePropList(texarray);
		return NULL;
	}

	texture = wmalloc(sizeof(BackgroundTexture));

	GETSTRORGOTO(val, type, 0, error);

	if (strcasecmp(type, "solid") == 0) {
		XColor color;
		Pixmap pixmap;

		texture->solid = 1;

		GETSTRORGOTO(val, tmp, 1, error);

		if (!XParseColor(dpy, DefaultColormap(dpy, scr), tmp, &color)) {
			wwarning("could not parse color %s in texture %s", tmp, text);
			goto error;
		}
		XAllocColor(dpy, DefaultColormap(dpy, scr), &color);

		pixmap = XCreatePixmap(dpy, root, 8, 8, DefaultDepth(dpy, scr));
		XSetForeground(dpy, DefaultGC(dpy, scr), color.pixel);
		XFillRectangle(dpy, pixmap, DefaultGC(dpy, scr), 0, 0, 8, 8);

		texture->pixmap = pixmap;
		texture->color = color;
		texture->width = 8;
		texture->height = 8;
	} else if (strcasecmp(type, "vgradient") == 0
		   || strcasecmp(type, "dgradient") == 0 || strcasecmp(type, "hgradient") == 0) {
		XColor color;
		RColor color1, color2;
		RImage *image;
		Pixmap pixmap;
		RGradientStyle gtype;
		int iwidth, iheight;

		GETSTRORGOTO(val, tmp, 1, error);

		if (!XParseColor(dpy, DefaultColormap(dpy, scr), tmp, &color)) {
			wwarning("could not parse color %s in texture %s", tmp, text);
			goto error;
		}

		color1.red = color.red >> 8;
		color1.green = color.green >> 8;
		color1.blue = color.blue >> 8;

		GETSTRORGOTO(val, tmp, 2, error);

		if (!XParseColor(dpy, DefaultColormap(dpy, scr), tmp, &color)) {
			wwarning("could not parse color %s in texture %s", tmp, text);
			goto error;
		}

		color2.red = color.red >> 8;
		color2.green = color.green >> 8;
		color2.blue = color.blue >> 8;

		switch (type[0]) {
		case 'h':
		case 'H':
			gtype = RHorizontalGradient;
			iwidth = scrWidth;
			iheight = 32;
			break;
		case 'V':
		case 'v':
			gtype = RVerticalGradient;
			iwidth = 32;
			iheight = scrHeight;
			break;
		default:
			gtype = RDiagonalGradient;
			iwidth = scrWidth;
			iheight = scrHeight;
			break;
		}

		image = RRenderGradient(iwidth, iheight, &color1, &color2, gtype);

		if (!image) {
			wwarning("could not render gradient texture:%s", RMessageForError(RErrorCode));
			goto error;
		}

		if (!RConvertImage(rc, image, &pixmap)) {
			wwarning("could not convert texture:%s", RMessageForError(RErrorCode));
			RReleaseImage(image);
			goto error;
		}

		texture->width = image->width;
		texture->height = image->height;
		RReleaseImage(image);

		texture->pixmap = pixmap;
	} else if (strcasecmp(type, "mvgradient") == 0
		   || strcasecmp(type, "mdgradient") == 0 || strcasecmp(type, "mhgradient") == 0) {
		XColor color;
		RColor **colors;
		RImage *image;
		Pixmap pixmap;
		int i, j;
		RGradientStyle gtype;
		int iwidth, iheight;

		colors = malloc(sizeof(RColor *) * (count - 1));
		if (!colors) {
			wwarning("out of memory while parsing texture");
			goto error;
		}
		memset(colors, 0, sizeof(RColor *) * (count - 1));

		for (i = 2; i < count; i++) {
			val = WMGetFromPLArray(texarray, i);
			if (!WMIsPLString(val)) {
				wwarning("could not parse texture %s", text);

				for (j = 0; colors[j] != NULL; j++)
					wfree(colors[j]);
				wfree(colors);
				goto error;
			}
			tmp = WMGetFromPLString(val);

			if (!XParseColor(dpy, DefaultColormap(dpy, scr), tmp, &color)) {
				wwarning("could not parse color %s in texture %s", tmp, text);

				for (j = 0; colors[j] != NULL; j++)
					wfree(colors[j]);
				wfree(colors);
				goto error;
			}
			if (!(colors[i - 2] = malloc(sizeof(RColor)))) {
				wwarning("out of memory while parsing texture");

				for (j = 0; colors[j] != NULL; j++)
					wfree(colors[j]);
				wfree(colors);
				goto error;
			}

			colors[i - 2]->red = color.red >> 8;
			colors[i - 2]->green = color.green >> 8;
			colors[i - 2]->blue = color.blue >> 8;
		}

		switch (type[1]) {
		case 'h':
		case 'H':
			gtype = RHorizontalGradient;
			iwidth = scrWidth;
			iheight = 32;
			break;
		case 'V':
		case 'v':
			gtype = RVerticalGradient;
			iwidth = 32;
			iheight = scrHeight;
			break;
		default:
			gtype = RDiagonalGradient;
			iwidth = scrWidth;
			iheight = scrHeight;
			break;
		}

		image = RRenderMultiGradient(iwidth, iheight, colors, gtype);

		for (j = 0; colors[j] != NULL; j++)
			wfree(colors[j]);
		wfree(colors);

		if (!image) {
			wwarning("could not render gradient texture:%s", RMessageForError(RErrorCode));
			goto error;
		}

		if (!RConvertImage(rc, image, &pixmap)) {
			wwarning("could not convert texture:%s", RMessageForError(RErrorCode));
			RReleaseImage(image);
			goto error;
		}

		texture->width = image->width;
		texture->height = image->height;
		RReleaseImage(image);

		texture->pixmap = pixmap;
	} else if (strcasecmp(type, "cpixmap") == 0
		   || strcasecmp(type, "spixmap") == 0 || strcasecmp(type, "fpixmap") == 0
		   || strcasecmp(type, "mpixmap") == 0 || strcasecmp(type, "tpixmap") == 0) {
		XColor color;
		Pixmap pixmap = None;
		RImage *image = NULL;
		int iwidth = 0, iheight = 0;
		RColor rcolor;

		GETSTRORGOTO(val, tmp, 1, error);
		/*
		   if (toupper(type[0]) == 'T' || toupper(type[0]) == 'C')
		   pixmap = LoadJPEG(rc, tmp, &iwidth, &iheight);
		 */

		if (!pixmap) {
			image = loadImage(rc, tmp);
			if (!image) {
				goto error;
			}
			iwidth = image->width;
			iheight = image->height;
		}

		GETSTRORGOTO(val, tmp, 2, error);

		if (!XParseColor(dpy, DefaultColormap(dpy, scr), tmp, &color)) {
			wwarning("could not parse color %s in texture %s", tmp, text);
			RReleaseImage(image);
			goto error;
		}
		if (!XAllocColor(dpy, DefaultColormap(dpy, scr), &color)) {
			rcolor.red = color.red >> 8;
			rcolor.green = color.green >> 8;
			rcolor.blue = color.blue >> 8;
			RGetClosestXColor(rc, &rcolor, &color);
		} else {
			rcolor.red = 0;
			rcolor.green = 0;
			rcolor.blue = 0;
		}
		/* for images with a transparent color */
		if (image && image->data[3])
			RCombineImageWithColor(image, &rcolor);

		switch (toupper(type[0])) {
		case 'T':
			texture->width = iwidth;
			texture->height = iheight;
			if (!pixmap && !RConvertImage(rc, image, &pixmap)) {
				wwarning("could not convert texture:%s", RMessageForError(RErrorCode));
				RReleaseImage(image);
				goto error;
			}

			texture->pixmap = pixmap;
			texture->color = color;
			break;
		case 'S':
		case 'M':
		case 'C':
		case 'F':
			{
				Pixmap tpixmap =
				    XCreatePixmap(dpy, root, scrWidth, scrHeight, DefaultDepth(dpy, scr));
				XSetForeground(dpy, DefaultGC(dpy, scr), color.pixel);
				XFillRectangle(dpy, tpixmap, DefaultGC(dpy, scr), 0, 0, scrWidth, scrHeight);

				texture->pixmap = tpixmap;
				texture->color = color;
				texture->width = scrWidth;
				texture->height = scrHeight;

				if (!image)
					break;

#ifdef USE_XINERAMA
				if (xineInfo.count && ! xineStretch) {
					int i;
					for (i = 0; i < xineInfo.count; ++i) {
						applyImage(rc, texture, image, type[0],
							   xineInfo.screens[i].pos.x, xineInfo.screens[i].pos.y,
							   xineInfo.screens[i].size.width,
							   xineInfo.screens[i].size.height);
					}
				} else {
					applyImage(rc, texture, image, type[0], 0, 0, scrWidth, scrHeight);
				}
#else				/* !USE_XINERAMA */
				applyImage(rc, texture, image, type[0], 0, 0, scrWidth, scrHeight);
#endif				/* !USE_XINERAMA */
			}
			break;
		}
		if (image)
			RReleaseImage(image);

	} else if (strcasecmp(type, "thgradient") == 0
		   || strcasecmp(type, "tvgradient") == 0 || strcasecmp(type, "tdgradient") == 0) {
		XColor color;
		RColor color1, color2;
		RImage *image;
		RImage *gradient;
		RImage *tiled;
		Pixmap pixmap;
		int opaq;
		char *file;
		RGradientStyle gtype;
		int twidth, theight;

		GETSTRORGOTO(val, file, 1, error);

		GETSTRORGOTO(val, tmp, 2, error);

		opaq = atoi(tmp);

		GETSTRORGOTO(val, tmp, 3, error);

		if (!XParseColor(dpy, DefaultColormap(dpy, scr), tmp, &color)) {
			wwarning("could not parse color %s in texture %s", tmp, text);
			goto error;
		}

		color1.red = color.red >> 8;
		color1.green = color.green >> 8;
		color1.blue = color.blue >> 8;

		GETSTRORGOTO(val, tmp, 4, error);

		if (!XParseColor(dpy, DefaultColormap(dpy, scr), tmp, &color)) {
			wwarning("could not parse color %s in texture %s", tmp, text);
			goto error;
		}

		color2.red = color.red >> 8;
		color2.green = color.green >> 8;
		color2.blue = color.blue >> 8;

		image = loadImage(rc, file);
		if (!image) {
			goto error;
		}

		switch (type[1]) {
		case 'h':
		case 'H':
			gtype = RHorizontalGradient;
			twidth = scrWidth;
			theight = image->height > scrHeight ? scrHeight : image->height;
			break;
		case 'V':
		case 'v':
			gtype = RVerticalGradient;
			twidth = image->width > scrWidth ? scrWidth : image->width;
			theight = scrHeight;
			break;
		default:
			gtype = RDiagonalGradient;
			twidth = scrWidth;
			theight = scrHeight;
			break;
		}
		gradient = RRenderGradient(twidth, theight, &color1, &color2, gtype);

		if (!gradient) {
			wwarning("could not render texture:%s", RMessageForError(RErrorCode));
			RReleaseImage(image);
			goto error;
		}

		tiled = RMakeTiledImage(image, twidth, theight);
		if (!tiled) {
			wwarning("could not render texture:%s", RMessageForError(RErrorCode));
			RReleaseImage(gradient);
			RReleaseImage(image);
			goto error;
		}
		RReleaseImage(image);

		RCombineImagesWithOpaqueness(tiled, gradient, opaq);
		RReleaseImage(gradient);

		if (!RConvertImage(rc, tiled, &pixmap)) {
			wwarning("could not convert texture:%s", RMessageForError(RErrorCode));
			RReleaseImage(tiled);
			goto error;
		}
		texture->width = tiled->width;
		texture->height = tiled->height;

		RReleaseImage(tiled);

		texture->pixmap = pixmap;
	} else if (strcasecmp(type, "function") == 0) {
		/* Leave this in to handle the unlikely case of
		 * someone actually having function textures configured */
		wwarning("function texture support has been removed");
		goto error;
	} else {
		wwarning("invalid texture type %s", text);
		goto error;
	}

	texture->spec = wstrdup(text);

	return texture;

 error:
	if (texture)
		wfree(texture);
	if (texarray)
		WMReleasePropList(texarray);

	return NULL;
}

static void freeTexture(BackgroundTexture * texture)
{
	if (texture->solid) {
		unsigned long pixel[1];

		pixel[0] = texture->color.pixel;
		/* dont free black/white pixels */
		if (pixel[0] != BlackPixelOfScreen(DefaultScreenOfDisplay(dpy))
		    && pixel[0] != WhitePixelOfScreen(DefaultScreenOfDisplay(dpy)))
			XFreeColors(dpy, DefaultColormap(dpy, scr), pixel, 1, 0);
	}
	if (texture->pixmap) {
		XFreePixmap(dpy, texture->pixmap);
	}
	wfree(texture->spec);
	wfree(texture);
}

static void setupTexture(RContext * rc, BackgroundTexture ** textures, int *maxTextures, int workspace, char *texture)
{
	BackgroundTexture *newTexture = NULL;
	int i;

	/* unset the texture */
	if (!texture) {
		if (textures[workspace] != NULL) {
			textures[workspace]->refcount--;

			if (textures[workspace]->refcount == 0)
				freeTexture(textures[workspace]);
		}
		textures[workspace] = NULL;
		return;
	}

	if (textures[workspace]
	    && strcasecmp(textures[workspace]->spec, texture) == 0) {
		/* texture did not change */
		return;
	}

	/* check if the same texture is already created */
	for (i = 0; i < *maxTextures; i++) {
		if (textures[i] && strcasecmp(textures[i]->spec, texture) == 0) {
			newTexture = textures[i];
			break;
		}
	}

	if (!newTexture) {
		/* create the texture */
		newTexture = parseTexture(rc, texture);
	}
	if (!newTexture)
		return;

	if (textures[workspace] != NULL) {

		textures[workspace]->refcount--;

		if (textures[workspace]->refcount == 0)
			freeTexture(textures[workspace]);
	}

	newTexture->refcount++;
	textures[workspace] = newTexture;

	if (*maxTextures < workspace)
		*maxTextures = workspace;
}

static Pixmap duplicatePixmap(Pixmap pixmap, int width, int height)
{
	Display *tmpDpy;
	Pixmap copyP;

	/* must open a new display or the RetainPermanent will
	 * leave stuff allocated in RContext unallocated after exit */
	tmpDpy = XOpenDisplay(display);
	if (!tmpDpy) {
		wwarning("could not open display to update background image information");

		return None;
	} else {
		XSync(dpy, False);

		copyP = XCreatePixmap(tmpDpy, root, width, height, DefaultDepth(tmpDpy, scr));
		XCopyArea(tmpDpy, pixmap, copyP, DefaultGC(tmpDpy, scr), 0, 0, width, height, 0, 0);
		XSync(tmpDpy, False);

		XSetCloseDownMode(tmpDpy, RetainPermanent);
		XCloseDisplay(tmpDpy);
	}

	return copyP;
}

static int dummyErrorHandler(Display * dpy, XErrorEvent * err)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) dpy;
	(void) err;

	return 0;
}

static void setPixmapProperty(Pixmap pixmap)
{
	static Atom prop = 0;
	Atom type;
	int format;
	unsigned long length, after;
	unsigned char *data;
	int mode;

	if (!prop) {
		prop = XInternAtom(dpy, "_XROOTPMAP_ID", False);
	}

	XGrabServer(dpy);

	/* Clear out the old pixmap */
	XGetWindowProperty(dpy, root, prop, 0L, 1L, False, AnyPropertyType,
			   &type, &format, &length, &after, &data);

	if ((type == XA_PIXMAP) && (format == 32) && (length == 1)) {
		XSetErrorHandler(dummyErrorHandler);
		XKillClient(dpy, *((Pixmap *) data));
		XSync(dpy, False);
		XSetErrorHandler(NULL);
		mode = PropModeReplace;
	} else {
		mode = PropModeAppend;
	}
	if (pixmap)
		XChangeProperty(dpy, root, prop, XA_PIXMAP, 32, mode, (unsigned char *)&pixmap, 1);
	else
		XDeleteProperty(dpy, root, prop);

	XUngrabServer(dpy);
	XFlush(dpy);
}

static void changeTexture(BackgroundTexture * texture)
{
	if (!texture) {
		return;
	}

	if (texture->solid) {
		XSetWindowBackground(dpy, root, texture->color.pixel);
	} else {
		XSetWindowBackgroundPixmap(dpy, root, texture->pixmap);
	}
	XClearWindow(dpy, root);

	XSync(dpy, False);

	{
		Pixmap pixmap;

		pixmap = duplicatePixmap(texture->pixmap, texture->width, texture->height);

		setPixmapProperty(pixmap);
	}
}

static int readmsg(int fd, char *buffer, int size)
{
	int count;

	while (size > 0) {
		count = read(fd, buffer, size);
		if (count < 0)
			return -1;
		size -= count;
		buffer += count;
		*buffer = 0;
	}

	return size;
}

/*
 * Message Format:
 * sizeSntexture_spec - sets the texture for workspace n
 * sizeCn - change background texture to the one for workspace n
 * sizePpath - set the pixmap search path
 *
 * n is 4 bytes
 * size = 4 bytes for length of the message data
 */
static noreturn void helperLoop(RContext * rc)
{
	BackgroundTexture *textures[WORKSPACE_COUNT];
	int maxTextures = 0;
	char buffer[2048], buf[8];
	int size;
	int errcount = 4;

	memset(textures, 0, WORKSPACE_COUNT * sizeof(BackgroundTexture *));

	while (1) {
		int workspace = -1;

		/* get length of message */
		if (readmsg(0, buffer, 4) < 0) {
			werror("error reading message from Window Maker");
			errcount--;
			if (errcount == 0) {
				wfatal("quitting");
				quit(1);
			}
			continue;
		}
		memcpy(buf, buffer, 4);
		buf[4] = 0;
		size = atoi(buf);
		if (size < 0 || size > sizeof(buffer)) {
			wfatal("received invalid size %d for message from WindowMaker", size);
			quit(1);
		}
		if (size == 0) {
			werror("received 0-sized message from WindowMaker, trying to continue");
			continue;
		}

		/* get message */
		if (readmsg(0, buffer, size) < 0) {
			werror("error reading message from Window Maker");
			errcount--;
			if (errcount == 0) {
				wfatal("quitting");
				quit(1);
			}
			continue;
		}
#ifdef DEBUG
		printf("RECEIVED %s\n", buffer);
#endif
		if (buffer[0] != 'P' && buffer[0] != 'K') {
			memcpy(buf, &buffer[1], 4);
			buf[4] = 0;
			workspace = atoi(buf);
			if (workspace < 0 || workspace >= WORKSPACE_COUNT) {
				wwarning("received message with invalid workspace number %i", workspace);
				continue;
			}
		}

		switch (buffer[0]) {
		case 'S':
#ifdef DEBUG
			printf("set texture %s\n", &buffer[5]);
#endif
			setupTexture(rc, textures, &maxTextures, workspace, &buffer[5]);
			break;

		case 'C':
#ifdef DEBUG
			printf("change texture %i\n", workspace);
#endif
			if (!textures[workspace]) {
				changeTexture(textures[0]);
			} else {
				changeTexture(textures[workspace]);
			}
			break;

		case 'P':
#ifdef DEBUG
			printf("change pixmappath %s\n", &buffer[1]);
#endif
			if (PixmapPath)
				wfree(PixmapPath);
			PixmapPath = wstrdup(&buffer[1]);
			break;

		case 'U':
#ifdef DEBUG
			printf("unset workspace %i\n", workspace);
#endif
			setupTexture(rc, textures, &maxTextures, workspace, NULL);
			break;

		case 'K':
#ifdef DEBUG
			printf("exit command\n");
#endif
			quit(0);

		default:
			wwarning("unknown message received");
			break;
		}
	}
}

static void updateDomain(const char *domain, const char *key, const char *texture)
{
	int result;
	char *program = "wdwrite";
	char cmd_smooth[1024];

	snprintf(cmd_smooth, sizeof(cmd_smooth),
	         "wdwrite %s SmoothWorkspaceBack %s",
	         domain, smooth ? "YES" : "NO");
	result = system(cmd_smooth);
	if (result == -1)
		werror("error executing system(\"%s\")", cmd_smooth);

	execlp(program, program, domain, key, texture, NULL);
	wwarning("warning could not run \"%s\"", program);
}

static WMPropList *getValueForKey(const char *domain, const char *keyName)
{
	char *path;
	WMPropList *key, *val, *d;

	key = WMCreatePLString(keyName);

	/* try to find PixmapPath in user defaults */
	path = wdefaultspathfordomain(domain);
	d = WMReadPropListFromFile(path);
	if (!d) {
		wwarning("could not open domain file %s", path);
	}
	wfree(path);

	if (d && !WMIsPLDictionary(d)) {
		WMReleasePropList(d);
		d = NULL;
	}
	if (d) {
		val = WMGetFromPLDictionary(d, key);
	} else {
		val = NULL;
	}
	/* try to find PixmapPath in global defaults */
	if (!val) {
		path = wglobaldefaultspathfordomain(domain);
		if (!path) {
			wwarning("could not locate file for domain %s", domain);
			d = NULL;
		} else {
			d = WMReadPropListFromFile(path);
			wfree(path);
		}

		if (d && !WMIsPLDictionary(d)) {
			WMReleasePropList(d);
			d = NULL;
		}
		if (d) {
			val = WMGetFromPLDictionary(d, key);

		} else {
			val = NULL;
		}
	}

	if (val)
		WMRetainPropList(val);

	WMReleasePropList(key);
	if (d)
		WMReleasePropList(d);

	return val;
}

static char *getPixmapPath(const char *domain)
{
	WMPropList *val;
	char *ptr, *data;
	int len, i, count;

	val = getValueForKey(domain, "PixmapPath");

	if (!val || !WMIsPLArray(val)) {
		if (val)
			WMReleasePropList(val);
		return wstrdup("");
	}

	count = WMGetPropListItemCount(val);
	len = 0;
	for (i = 0; i < count; i++) {
		WMPropList *v;

		v = WMGetFromPLArray(val, i);
		if (!v || !WMIsPLString(v)) {
			continue;
		}
		len += strlen(WMGetFromPLString(v)) + 1;
	}

	ptr = data = wmalloc(len + 1);
	*ptr = 0;

	for (i = 0; i < count; i++) {
		WMPropList *v;

		v = WMGetFromPLArray(val, i);
		if (!v || !WMIsPLString(v)) {
			continue;
		}
		strcpy(ptr, WMGetFromPLString(v));

		ptr += strlen(WMGetFromPLString(v));
		*ptr = ':';
		ptr++;
	}
	if (i > 0)
		ptr--;
	*(ptr--) = 0;

	WMReleasePropList(val);

	return data;
}

static char *getFullPixmapPath(const char *file)
{
	char *tmp;

	if (!PixmapPath || !(tmp = wfindfile(PixmapPath, file))) {
		int bsize = 512;
		char *path = wmalloc(bsize);

		while (!getcwd(path, bsize)) {
			bsize += bsize / 2;
			path = wrealloc(path, bsize);
		}

		tmp = wstrconcat(path, "/");
		wfree(path);
		path = wstrconcat(tmp, file);
		wfree(tmp);

		return path;
	}

	/* the file is in the PixmapPath */
	wfree(tmp);

	return wstrdup(file);
}

static void print_help(void)
{
	printf("Usage: %s [options] [image]\n", prog_name);
	puts("Sets the workspace background to the specified image or a texture and");
	puts("optionally update Window Maker configuration");
	puts("");
	puts(" -display <display>            display to use");
	puts(" -d, --dither                  dither image");
	puts(" -m, --match                   match  colors");
	puts(" -S, --smooth                  smooth scaled image");
#ifdef USE_XINERAMA
	puts(" -X, --xinerama                stretch image across Xinerama heads");
#endif
	puts(" -b, --back-color <color>      background color");
	puts(" -t, --tile                    tile   image");
	puts(" -e, --center                  center image");
	puts(" -s, --scale                   scale  image (default)");
	puts(" -a, --maxscale                scale  image and keep aspect ratio");
	puts(" -f, --fillscale               scale  image to fill screen and keep aspect ratio");
	puts(" -u, --update-wmaker           update WindowMaker domain database");
	puts(" -D, --update-domain <domain>  update <domain> database");
	puts(" -c, --colors <cpc>            colors per channel to use");
	puts(" -p, --parse <texture>         proplist style texture specification");
	puts(" -w, --workspace <workspace>   update background for the specified workspace");
	puts(" -v, --version                 show version of wmsetbg and exit");
	puts(" -h, --help                    show this help and exit");
}

static void changeTextureForWorkspace(const char *domain, char *texture, int workspace)
{
	WMPropList *array, *val;
	char *value;
	int j;

	val = WMCreatePropListFromDescription(texture);
	if (!val) {
		wwarning("could not parse texture %s", texture);
		return;
	}

	array = getValueForKey("WindowMaker", "WorkspaceSpecificBack");

	if (!array) {
		array = WMCreatePLArray(NULL, NULL);
	}

	j = WMGetPropListItemCount(array);
	if (workspace >= j) {
		WMPropList *empty;

		empty = WMCreatePLArray(NULL, NULL);

		while (j++ < workspace - 1) {
			WMAddToPLArray(array, empty);
		}
		WMAddToPLArray(array, val);

		WMReleasePropList(empty);
	} else {
		WMDeleteFromPLArray(array, workspace);
		WMInsertInPLArray(array, workspace, val);
	}

	value = WMGetPropListDescription(array, False);
	updateDomain(domain, "WorkspaceSpecificBack", value);

	WMReleasePropList(array);
}

int main(int argc, char **argv)
{
	int i;
	int helperMode = 0;
	RContext *rc;
	RContextAttributes rattr;
	char *style = "spixmap";
	char *back_color = "gray20";
	char *image_name = NULL;
	char *domain = "WindowMaker";
	int update = 0, cpc = 4, obey_user = 0;
	RRenderingMode render_mode = RDitheredRendering;
	char *texture = NULL;
	int workspace = -1;

	signal(SIGINT, SIG_DFL);
	signal(SIGTERM, SIG_DFL);
	signal(SIGQUIT, SIG_DFL);
	signal(SIGSEGV, SIG_DFL);
	signal(SIGBUS, SIG_DFL);
	signal(SIGFPE, SIG_DFL);
	signal(SIGABRT, SIG_DFL);
	signal(SIGHUP, SIG_DFL);
	signal(SIGPIPE, SIG_DFL);
	signal(SIGCHLD, SIG_DFL);

	WMInitializeApplication("wmsetbg", &argc, argv);

	prog_name = argv[0];
	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-helper") == 0) {
			helperMode = 1;
		} else if (strcmp(argv[i], "-display") == 0) {
			i++;
			if (i >= argc) {
				wfatal("too few arguments for %s", argv[i - 1]);
				quit(1);
			}
			display = argv[i];
		} else if (strcmp(argv[i], "-s") == 0 || strcmp(argv[i], "--scale") == 0) {
			style = "spixmap";
		} else if (strcmp(argv[i], "-t") == 0 || strcmp(argv[i], "--tile") == 0) {
			style = "tpixmap";
		} else if (strcmp(argv[i], "-e") == 0 || strcmp(argv[i], "--center") == 0) {
			style = "cpixmap";
		} else if (strcmp(argv[i], "-a") == 0 || strcmp(argv[i], "--maxscale") == 0) {
			style = "mpixmap";
		} else if (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--fillscale") == 0) {
			style = "fpixmap";
		} else if (strcmp(argv[i], "-d") == 0 || strcmp(argv[i], "--dither") == 0) {
			render_mode = RDitheredRendering;
			obey_user++;
		} else if (strcmp(argv[i], "-m") == 0 || strcmp(argv[i], "--match") == 0) {
			render_mode = RBestMatchRendering;
			obey_user++;
		} else if (strcmp(argv[i], "-S") == 0 || strcmp(argv[i], "--smooth") == 0) {
			smooth = True;
#ifdef USE_XINERAMA
		} else if (strcmp(argv[i], "-X") == 0 || strcmp(argv[i], "--xinerama") == 0) {
			xineStretch = True;
#endif
		} else if (strcmp(argv[i], "-u") == 0 || strcmp(argv[i], "--update-wmaker") == 0) {
			update++;
		} else if (strcmp(argv[i], "-D") == 0 || strcmp(argv[i], "--update-domain") == 0) {
			update++;
			i++;
			if (i >= argc) {
				wfatal("too few arguments for %s", argv[i - 1]);
				quit(1);
			}
			domain = wstrdup(argv[i]);
		} else if (strcmp(argv[i], "-c") == 0 || strcmp(argv[i], "--colors") == 0) {
			i++;
			if (i >= argc) {
				wfatal("too few arguments for %s", argv[i - 1]);
				quit(1);
			}
			if (sscanf(argv[i], "%i", &cpc) != 1) {
				wfatal("bad value for colors per channel: \"%s\"", argv[i]);
				quit(1);
			}
		} else if (strcmp(argv[i], "-b") == 0 || strcmp(argv[i], "--back-color") == 0) {
			i++;
			if (i >= argc) {
				wfatal("too few arguments for %s", argv[i - 1]);
				quit(1);
			}
			back_color = argv[i];
		} else if (strcmp(argv[i], "-p") == 0 || strcmp(argv[i], "--parse") == 0) {
			i++;
			if (i >= argc) {
				wfatal("too few arguments for %s", argv[i - 1]);
				quit(1);
			}
			texture = argv[i];
		} else if (strcmp(argv[i], "-w") == 0 || strcmp(argv[i], "--workspace") == 0) {
			i++;
			if (i >= argc) {
				wfatal("too few arguments for %s", argv[i - 1]);
				quit(1);
			}
			if (sscanf(argv[i], "%i", &workspace) != 1) {
				wfatal("bad value for workspace number: \"%s\"", argv[i]);
				quit(1);
			}
		} else if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--version") == 0) {
			printf("%s (Window Maker %s)\n", prog_name, VERSION);
			quit(0);
		} else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
			print_help();
			quit(0);
		} else if (argv[i][0] != '-') {
			image_name = argv[i];
		} else {
			printf("%s: invalid argument '%s'\n", prog_name, argv[i]);
			printf("Try '%s --help' for more information\n", prog_name);
			quit(1);
		}
	}
	if (!image_name && !texture && !helperMode) {
		printf("%s: you must specify a image file name or a texture\n", prog_name);
		printf("Try '%s --help' for more information\n", prog_name);
		quit(1);
	}

	PixmapPath = getPixmapPath(domain);
	if (!smooth) {
		WMPropList *val;
		/* carlos, don't remove this */
#if 0				/* some problem with Alpha... TODO: check if its right */
		val = WMGetFromPLDictionary(domain, WMCreatePLString("SmoothWorkspaceBack"));
#else
		val = getValueForKey(domain, "SmoothWorkspaceBack");
#endif

		if (val && WMIsPLString(val) && strcasecmp(WMGetFromPLString(val), "YES") == 0)
			smooth = True;
	}

	dpy = XOpenDisplay(display);
	if (!dpy) {
		wfatal("could not open display");
		quit(1);
	}
#if 0
	XSynchronize(dpy, 1);
#endif

	root = DefaultRootWindow(dpy);

	scr = DefaultScreen(dpy);

	scrWidth = WidthOfScreen(DefaultScreenOfDisplay(dpy));
	scrHeight = HeightOfScreen(DefaultScreenOfDisplay(dpy));
	scrX = scrY = 0;

	initXinerama();

	if (!obey_user && DefaultDepth(dpy, scr) <= 8)
		render_mode = RDitheredRendering;

	rattr.flags = RC_RenderMode | RC_ColorsPerChannel | RC_StandardColormap | RC_DefaultVisual;
	rattr.render_mode = render_mode;
	rattr.colors_per_channel = cpc;
	rattr.standard_colormap_mode = RCreateStdColormap;

	rc = RCreateContext(dpy, scr, &rattr);

	if (!rc) {
		rattr.standard_colormap_mode = RIgnoreStdColormap;
		rc = RCreateContext(dpy, scr, &rattr);
	}

	if (!rc) {
		wfatal("could not initialize wrlib: %s", RMessageForError(RErrorCode));
		quit(1);
	}

	if (helperMode) {
		int result;

		/* lower priority, so that it wont use all the CPU */
		result = nice(15);
		if (result == -1)
			wwarning("error could not nice process");

		helperLoop(rc);
	} else {
		BackgroundTexture *tex;
		char buffer[4098];

		if (!texture) {
			char *image_path = getFullPixmapPath(image_name);
			snprintf(buffer, sizeof(buffer), "(%s, \"%s\", %s)", style, image_path, back_color);
			wfree(image_path);
			texture = (char *)buffer;
		}

		if (update && workspace < 0) {
			updateDomain(domain, "WorkspaceBack", texture);
		}

		tex = parseTexture(rc, texture);
		if (!tex)
			quit(1);

		if (workspace < 0)
			changeTexture(tex);
		else {
			/* always update domain */
			changeTextureForWorkspace(domain, texture, workspace);
		}
	}

	WMReleaseApplication();
	return 0;
}
