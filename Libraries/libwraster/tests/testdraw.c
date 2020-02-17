
#include <X11/Xlib.h>
#include "wraster.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/time.h>
#include <time.h>

Display *dpy;
RContext *ctx;
char *ProgName;

void testDraw()
{
	RImage *img, *tile, *icon, *tmp;
	RColor color, from, to;
	RColor cdelta;
	RSegment segs[20];
	int i, x, y;
	XSetWindowAttributes val;
	Pixmap pix, back;
	Window win;

	val.background_pixel = ctx->black;
	val.colormap = ctx->cmap;
	win = XCreateWindow(dpy, DefaultRootWindow(dpy), 10, 10, 128, 256,
			    0, ctx->depth, InputOutput, ctx->visual, CWColormap | CWBackPixel, &val);
	back = XCreatePixmap(ctx->dpy, ctx->drawable, 128, 256, ctx->depth);

	/* Dark blue tile gradient */
	from.red = 0x28;
	from.green = 0x45;
	from.blue = 0x69;
	from.alpha = 0xff;
	to.red = 0x08;
	to.green = 0x24;
	to.blue = 0x20;
	to.alpha = 0xff;

	/* Standard gray tile gradient */
	/*from.red = 0xa6;
	   from.green = 0xa6;
	   from.blue = 0xb6;
	   from.alpha = 0xff;
	   to.red = 0x51;
	   to.green = 0x55;
	   to.blue = 0x61;
	   to.alpha = 0xff; */

	/* Make the tile, and put it as a sample in the first place */
	tile = RRenderGradient(64, 64, &from, &to, RGRD_DIAGONAL);
	img = RCloneImage(tile);
	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 0, 0);

	/* Read the image, and combine it with the tile. Put it as a sample
	 * in the second slot, and also save a copy for later use. */
	icon = RLoadImage(ctx, "ballot_box.xpm", 0);
	if (!icon) {
		puts(RMessageForError(RErrorCode));
		exit(1);
	}
	RCombineArea(img, icon, 0, 0, icon->width, icon->height, 8, 8);
	RReleaseImage(icon);
	tmp = img;
	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 64, 0);

	img = RCloneImage(tile);

	/* Draw random pixels on image */
	for (i = 0; i < 200; i++) {
		color.red = rand() % 256;
		color.green = rand() % 256;
		color.blue = rand() % 256;
		color.alpha = 255;
		x = rand() % 64;
		y = rand() % 64;
		RPutPixel(img, x, y, &color);
	}

	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 0, 64);

	RReleaseImage(img);
	img = RCloneImage(tile);

	/* Alter random pixels in image with the same amount for r/g/b */
	for (i = 0; i < 200; i++) {
		cdelta.red = cdelta.green = cdelta.blue = rand() % 511 - 255;
		cdelta.alpha = 0;
		x = rand() % 64;
		y = rand() % 64;
		ROperatePixel(img, RAddOperation, x, y, &cdelta);
	}

	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 64, 64);

	RReleaseImage(img);
	img = RCloneImage(tile);

	/* Draw lines in all directions to test different slopes */
	color.red = 0xff;
	color.green = 0x7d;
	color.blue = 0x52;
	color.alpha = 0xff;
	for (i = 0; i < 16; i++)
		segs[i].x1 = segs[i].y1 = 31;

	segs[6].x2 = segs[7].x2 = segs[8].x2 = segs[9].x2 = segs[10].x2 = 0;
	segs[2].y2 = segs[3].y2 = segs[4].y2 = segs[5].y2 = segs[6].y2 = 0;
	segs[5].x2 = segs[11].x2 = 16;
	segs[1].y2 = segs[7].y2 = 16;
	segs[4].x2 = segs[12].x2 = 31;
	segs[0].y2 = segs[8].y2 = 31;
	segs[3].x2 = segs[13].x2 = 46;
	segs[9].y2 = segs[15].y2 = 46;
	segs[0].x2 = segs[1].x2 = segs[2].x2 = segs[14].x2 = segs[15].x2 = 62;
	segs[10].y2 = segs[11].y2 = segs[12].y2 = segs[13].y2 = segs[14].y2 = 62;
	RDrawSegments(img, segs, 9, &color);

	/* Also test how alpha channel behaves when drawing lines */
	color.alpha = 0x80;
	RDrawSegments(img, &segs[9], 7, &color);

	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 0, 128);

	RReleaseImage(img);
	img = RCloneImage(tile);

	/* Alter lines in all directions (test different slopes) */
	cdelta.red = cdelta.green = cdelta.blue = 80;
	cdelta.alpha = 0;
	ROperateSegments(img, RAddOperation, segs, 16, &cdelta);

	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 64, 128);

	RReleaseImage(img);

	/* Create a bevel around the icon, and save it for a later use */
	img = tmp;
	cdelta.red = cdelta.green = cdelta.blue = 80;
	cdelta.alpha = 0;
	ROperateLine(img, RAddOperation, 8, 8, 56, 8, &cdelta);
	ROperateLine(img, RAddOperation, 8, 9, 8, 56, &cdelta);
	cdelta.red = cdelta.green = cdelta.blue = 40;
	cdelta.alpha = 0;
	ROperateLine(img, RSubtractOperation, 8, 56, 56, 56, &cdelta);
	ROperateLine(img, RSubtractOperation, 56, 8, 56, 55, &cdelta);
	RReleaseImage(tile);
	tmp = RCloneImage(img);

	/* Draw some solid lines over the icon */
	color.red = 0xff;
	color.green = 0x7d;
	color.blue = 0x52;
	color.alpha = 0xff;
	for (i = 16; i < 24; i++) {
		RDrawLine(img, 9, i, 55, i, &color);
	}

	/* Also try some lines with alpha over the icon */
	color.alpha = 0x80;
	for (i = 40; i < 48; i++) {
		RDrawLine(img, 9, i, 55, i, &color);
	}

	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 0, 192);

	RReleaseImage(img);

	/* Restore the image with the icon, and alter some lines */
	img = tmp;
	cdelta.red = cdelta.green = cdelta.blue = 80;
	cdelta.alpha = 0;
	for (i = 16; i < 24; i++) {
		ROperateLine(img, RSubtractOperation, 9, i, 55, i, &cdelta);
	}
	cdelta.red = cdelta.green = cdelta.blue = 80;
	for (i = 40; i < 48; i++) {
		ROperateLine(img, RAddOperation, 9, i, 55, i, &cdelta);
	}

	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 64, 192);

	XSetWindowBackgroundPixmap(dpy, win, back);
	XMapRaised(dpy, win);
	XClearWindow(dpy, win);
	XFlush(dpy);
}

void testBevel()
{
	RImage *img, *tile;
	RColor color, from, to;
	XSetWindowAttributes val;
	Pixmap pix, back;
	Window win;

	val.background_pixel = ctx->black;
	val.colormap = ctx->cmap;
	win = XCreateWindow(dpy, DefaultRootWindow(dpy), 10, 10, 140, 140,
			    0, ctx->depth, InputOutput, ctx->visual, CWColormap | CWBackPixel, &val);
	back = XCreatePixmap(ctx->dpy, ctx->drawable, 140, 140, ctx->depth);

	/* Standard gray tile gradient */
	from.red = 0xa6;
	from.green = 0xa6;
	from.blue = 0xb6;
	from.alpha = 0xff;
	to.red = 0x51;
	to.green = 0x55;
	to.blue = 0x61;
	to.alpha = 0xff;

	/* Dark blue tile gradient */
	/*from.red = 0x28;
	   from.green = 0x45;
	   from.blue = 0x69;
	   from.alpha = 0xff;
	   to.red = 0x08;
	   to.green = 0x24;
	   to.blue = 0x20;
	   to.alpha = 0xff; */

	/* Create Background */
	img = RCreateImage(140, 140, True);
	color.red = 0x28;
	color.green = 0x45;
	color.blue = 0x69;
	color.alpha = 0xff;
	RClearImage(img, &color);
	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 140, 140, 0, 0);
	RReleaseImage(img);

	tile = RRenderGradient(64, 64, &from, &to, RGRD_DIAGONAL);

	img = RCloneImage(tile);
	RBevelImage(img, RBEV_SUNKEN);
	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 3, 3);
	RReleaseImage(img);

	img = RCloneImage(tile);
	RBevelImage(img, RBEV_RAISED);
	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 73, 3);
	RReleaseImage(img);

	img = RCloneImage(tile);
	RBevelImage(img, RBEV_RAISED2);
	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 3, 73);
	RReleaseImage(img);

	img = RCloneImage(tile);
	RBevelImage(img, RBEV_RAISED3);
	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 73, 73);
	RReleaseImage(img);

	XSetWindowBackgroundPixmap(dpy, win, back);
	XMapRaised(dpy, win);
	XClearWindow(dpy, win);
	XFlush(dpy);
}

void testScale()
{
	RImage *image;
	RImage *scaled;
	XSetWindowAttributes val;
	Pixmap pix;
	Window win;

	val.background_pixel = ctx->black;
	val.colormap = ctx->cmap;
	win = XCreateWindow(dpy, DefaultRootWindow(dpy), 10, 10, 140, 140,
			    0, ctx->depth, InputOutput, ctx->visual, CWColormap | CWBackPixel, &val);
	XStoreName(dpy, win, "Scale");
	pix = XCreatePixmap(ctx->dpy, ctx->drawable, 140, 140, ctx->depth);

	image = RLoadImage(ctx, "ballot_box.xpm", 0);
	if (!image) {
		puts("couldnt load ballot_box.xpm");
		return;
	}

	scaled = RScaleImage(image, 140, 140);

	RReleaseImage(image);
	RConvertImage(ctx, scaled, &pix);
	XSetWindowBackgroundPixmap(dpy, win, pix);
	XMapRaised(dpy, win);
	XClearWindow(dpy, win);
	XFlush(dpy);
}

void testRotate()
{

	RImage *image;
	RImage *rotated;
	XSetWindowAttributes val;
	Pixmap pix;
	Window win;

	image = RLoadImage(ctx, "ballot_box.xpm", 0);
	if (!image) {
		puts("couldnt load ballot_box.xpm");
		return;
	}

	image = RScaleImage(image, 90, 180);

	val.background_pixel = ctx->black;
	val.colormap = ctx->cmap;
	win = XCreateWindow(dpy, DefaultRootWindow(dpy), 10, 10, image->height,
			    image->width, 0, ctx->depth, InputOutput, ctx->visual, CWColormap | CWBackPixel, &val);
	XStoreName(dpy, win, "Rotate");
	pix = XCreatePixmap(ctx->dpy, ctx->drawable, image->height, image->width, ctx->depth);

	rotated = RRotateImage(image, 90.0);

	RReleaseImage(image);
	RConvertImage(ctx, rotated, &pix);
	XSetWindowBackgroundPixmap(dpy, win, pix);
	XMapRaised(dpy, win);
	XClearWindow(dpy, win);
	XFlush(dpy);
}

void drawClip()
{
	RImage *img;
	RColor color, from, to, tmp;
	RColor cdelta, cdelta1;
	RSegment segs[20];
	XSetWindowAttributes val;
	Pixmap pix, back;
	Window win;

	val.background_pixel = ctx->black;
	val.colormap = ctx->cmap;
	win = XCreateWindow(dpy, DefaultRootWindow(dpy), 10, 10, 64, 64,
			    0, ctx->depth, InputOutput, ctx->visual, CWColormap | CWBackPixel, &val);
	back = XCreatePixmap(ctx->dpy, ctx->drawable, 64, 64, ctx->depth);

	/* Standard gray tile gradient */
	from.red = 0xa6;
	from.green = 0xa6;
	from.blue = 0xb6;
	from.alpha = 0xff;
	to.red = 0x51;
	to.green = 0x55;
	to.blue = 0x61;
	to.alpha = 0xff;

	/* Dark blue tile gradient */
	from.red = 0x28;
	from.green = 0x45;
	from.blue = 0x69;
	from.alpha = 0xff;
	to.red = 0x08;
	to.green = 0x24;
	to.blue = 0x20;
	to.alpha = 0xff;

	img = RRenderGradient(64, 64, &from, &to, RGRD_DIAGONAL);

	RBevelImage(img, RBEV_RAISED3);
#if 1
	color.alpha = 255;
	color.red = color.green = color.blue = 0;

	cdelta.alpha = 0;
	cdelta.red = cdelta.green = cdelta.blue = 80;

	cdelta1.alpha = 0;
	cdelta1.red = cdelta1.green = cdelta1.blue = 40;

	segs[0].x1 = segs[2].y1 = segs[4].x1 = segs[4].x2 = 63 - 21;
	segs[0].x2 = segs[2].y2 = segs[1].x2 = segs[3].y2 = 63 - 2;
	segs[0].y1 = segs[2].x1 = segs[1].y1 = segs[3].x1 = 2;
	segs[0].y2 = segs[2].x2 = segs[6].x1 = segs[6].x2 = 21;
	segs[1].x1 = segs[3].y1 = segs[5].x1 = segs[5].x2 = 63 - 22;
	segs[1].y2 = segs[3].x2 = segs[7].x1 = segs[7].x2 = 22;

	segs[4].y1 = segs[5].y1 = segs[10].x1 = segs[11].x1 = 0;
	segs[4].y2 = segs[5].y2 = segs[10].x2 = segs[11].x2 = 1;
	segs[6].y1 = segs[7].y1 = segs[8].x1 = segs[9].x1 = 63 - 1;
	segs[6].y2 = segs[7].y2 = segs[8].x2 = segs[9].x2 = 63;
	segs[8].y1 = segs[8].y2 = 21;
	segs[9].y1 = segs[9].y2 = 22;
	segs[10].y1 = segs[10].y2 = 63 - 21;
	segs[11].y1 = segs[11].y2 = 63 - 22;
	/* Black segments */
	RDrawSegments(img, segs, 12, &color);

	segs[0].x1 = segs[3].y1 = 63 - 20;
	segs[0].x2 = segs[1].y2 = segs[2].x2 = segs[3].y2 = 63 - 2;
	segs[0].y1 = segs[1].x1 = segs[2].y1 = segs[3].x1 = 2;
	segs[1].y1 = segs[2].x1 = 63 - 23;
	segs[0].y2 = segs[3].x2 = 20;
	segs[1].x2 = segs[2].y2 = 23;
	/* Bevels arround black segments */
	ROperateSegments(img, RAddOperation, segs, 2, &cdelta);
	ROperateSegments(img, RSubtractOperation, &segs[2], 2, &cdelta1);

	RGetPixel(img, 63 - 2, 20, &tmp);
	/*RPutPixel(img, 63-1, 23, &tmp); */
	RDrawLine(img, 63 - 1, 23, 63, 23, &tmp);
	RGetPixel(img, 63 - 23, 2, &tmp);
	RDrawLine(img, 63 - 23, 0, 63 - 23, 1, &tmp);

	RGetPixel(img, 23, 63 - 2, &tmp);
	/*RPutPixel(img, 23, 63-1, &tmp); */
	RDrawLine(img, 23, 63 - 1, 23, 63, &tmp);
	RGetPixel(img, 2, 63 - 20, &tmp);
	RDrawLine(img, 0, 63 - 23, 1, 63 - 23, &tmp);
#else
	color.alpha = 255;
	color.red = color.green = color.blue = 0;

	cdelta.alpha = 0;
	cdelta.red = cdelta.green = cdelta.blue = 80;

	cdelta1.alpha = 0;
	cdelta1.red = cdelta1.green = cdelta1.blue = 40;

	RDrawLine(img, 63 - 21, 2, 63 - 2, 21, &color);	/* upper 2 black lines */
	ROperateLine(img, RAddOperation, 63 - 20, 2, 63 - 2, 20, &cdelta);	/* the bevel arround them */
	ROperateLine(img, RSubtractOperation, 63 - 22, 2, 63 - 2, 22, &cdelta1);
	RDrawLine(img, 63 - 21, 0, 63 - 21, 1, &color);	/* upper small black lines */
	RDrawLine(img, 63 - 1, 21, 63, 21, &color);

	RGetPixel(img, 63 - 2, 20, &tmp);
	RPutPixel(img, 63 - 1, 22, &tmp);
	RGetPixel(img, 2, 63 - 22, &tmp);
	RDrawLine(img, 63 - 22, 0, 63 - 22, 1, &tmp);

	RDrawLine(img, 2, 63 - 21, 21, 63 - 2, &color);	/* lower 2 black lines */
	ROperateLine(img, RSubtractOperation, 2, 63 - 20, 20, 63 - 2, &cdelta1);	/* the bevel arround them */
	ROperateLine(img, RAddOperation, 2, 63 - 22, 22, 63 - 2, &cdelta);
	RDrawLine(img, 21, 63 - 1, 21, 63, &color);	/* lower small black lines */
	RDrawLine(img, 0, 63 - 21, 1, 63 - 21, &color);
	ROperateLine(img, RAddOperation, 22, 63 - 1, 22, 63, &cdelta);
	/*ROperateLine(img, RAddOperation, 22, 63-1, 22, 63, &cdelta); *//* the bevel arround them */
	ROperateLine(img, RSubtractOperation, 0, 63 - 22, 1, 63 - 22, &cdelta1);
#endif

	RConvertImage(ctx, img, &pix);
	XCopyArea(dpy, pix, back, ctx->copy_gc, 0, 0, 64, 64, 0, 0);
	RReleaseImage(img);

	XSetWindowBackgroundPixmap(dpy, win, back);
	XMapRaised(dpy, win);
	XClearWindow(dpy, win);
	XFlush(dpy);
}

void benchmark()
{
	RImage *img;
	RColor color;
	RColor cdelta;
	double t1, t2, total, d1 = 0, d2 = 0, d3 = 0;
	struct timeval timev;
	int i, j;

	puts("Starting benchmark");

	gettimeofday(&timev, NULL);
	t1 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);

	img = RCreateImage(1024, 768, True);

	gettimeofday(&timev, NULL);
	t2 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);
	total = t2 - t1;
	printf("Image created in %f sec\n", total);

	gettimeofday(&timev, NULL);
	t1 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);

	color.red = 0x28;
	color.green = 0x45;
	color.blue = 0x69;
	color.alpha = 0xff;
	RClearImage(img, &color);

	color.red = 0xff;
	color.green = 0x7d;
	color.blue = 0x52;
	color.alpha = 0xff;
	cdelta.red = cdelta.green = cdelta.blue = 80;
	cdelta.alpha = 0;

	gettimeofday(&timev, NULL);
	t2 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);
	total = t2 - t1;
	printf("Image filled in %f sec\n", total);

	for (j = 1; j < 6; j++) {
		printf("Pass %d...\n", j);
		gettimeofday(&timev, NULL);
		t1 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);

		color.alpha = 0xff;
		for (i = 0; i < 10000; i++) {
			RDrawLine(img, 0, i % 64, i % 64, 63, &color);
		}

		gettimeofday(&timev, NULL);
		t2 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);
		total = t2 - t1;
		printf("Drawing 10000 lines in %f sec\n", total);
		d1 += total;

		gettimeofday(&timev, NULL);
		t1 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);

		color.alpha = 80;
		for (i = 0; i < 10000; i++) {
			RDrawLine(img, 0, i % 64, i % 64, 63, &color);
		}

		gettimeofday(&timev, NULL);
		t2 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);
		total = t2 - t1;
		printf("Drawing 10000 lines with alpha in %f sec\n", total);
		d2 += total;

		gettimeofday(&timev, NULL);
		t1 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);

		for (i = 0; i < 10000; i++) {
			ROperateLine(img, RAddOperation, 0, i % 64, i % 64, 63, &cdelta);
		}

		gettimeofday(&timev, NULL);
		t2 = (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);
		total = t2 - t1;
		printf("Altering 10000 lines in %f sec\n", total);
		d3 += total;
	}
	printf("Average: %f, %f, %f\n", d1 / 5, d2 / 5, d3 / 5);

	RReleaseImage(img);
}

int main(int argc, char **argv)
{
	RContextAttributes attr;
	int visualID = -1;

	(void) argc;

	ProgName = strrchr(argv[0], '/');
	if (!ProgName)
		ProgName = argv[0];
	else
		ProgName++;

	dpy = XOpenDisplay("");
	if (!dpy) {
		puts("cant open display");
		exit(1);
	}

	attr.flags = RC_RenderMode | RC_ColorsPerChannel;

	attr.render_mode = RDitheredRendering;
	attr.colors_per_channel = 4;

	if (visualID >= 0) {
		attr.flags |= RC_VisualID;
		attr.visualid = visualID;
	}

	ctx = RCreateContext(dpy, DefaultScreen(dpy), &attr);

	if (!ctx) {
		printf("could not initialize graphics library context: %s\n", RMessageForError(RErrorCode));
		exit(1);
	}

	/* Here are the things we want to test */
	testDraw();

	testBevel();

	drawClip();

	testScale();

	testRotate();

	/* benchmark(); */

	getchar();
	return 0;
}
