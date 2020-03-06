#include <X11/Xlib.h>
#include "wraster.h"
#include <stdlib.h>
#include <stdio.h>
#include "tile.xpm"
Display *dpy;
Window win;
RContext *ctx;
RImage *img;
Pixmap pix;

int main(int argc, char **argv)
{
	RContextAttributes attr;

	dpy = XOpenDisplay("");
	if (!dpy) {
		puts("cant open display");
		exit(1);
	}

	attr.flags = RC_RenderMode | RC_ColorsPerChannel;
	attr.render_mode = RDitheredRendering;
	attr.colors_per_channel = 4;
	ctx = RCreateContext(dpy, DefaultScreen(dpy), &attr);

	if (argc < 2) {
		printf("using default image as none was provided\n");
		img = RGetImageFromXPMData(ctx, image_name);
	}
	else
		img = RLoadImage(ctx, argv[1], 0);

	if (!img) {
		puts(RMessageForError(RErrorCode));
		exit(1);
	}

	if (argc > 2) {
		RImage *tmp = img;

		img = RScaleImage(tmp, tmp->width * atol(argv[2]), tmp->height * atol(argv[2]));
		/*img = RSmoothScaleImage(tmp, tmp->width*atol(argv[2]),
		   tmp->height*atol(argv[2]));
		 */

		RReleaseImage(tmp);
	}
#if 0
	if (argc > 2) {
		img = RScaleImage(img, img->width * atof(argv[2]), img->height * atof(argv[2]));
	}

	{
		RImage *tmp = RCreateImage(200, 200, True);
		RColor col = { 0, 0, 255, 255 };

		if (img->format == RRGBAFormat)
			puts("alpha");
		else
			puts("no alpha");

		RClearImage(tmp, &col);

		RCombineArea(tmp, img, 0, 0, 20, 20, 10, 10);
		img = tmp;
	}
#endif

	if (!RConvertImage(ctx, img, &pix)) {
		puts(RMessageForError(RErrorCode));
		exit(1);
	}

	printf("size is %ix%i\n", img->width, img->height);

	win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 10, 10, img->width, img->height, 0, 0, 0);
	XSetWindowBackgroundPixmap(dpy, win, pix);
	XClearWindow(dpy, win);
	XMapRaised(dpy, win);
	XFlush(dpy);
	getchar();

	return 0;
}
