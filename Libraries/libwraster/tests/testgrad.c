
#include <X11/Xlib.h>
#include "wraster.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Display *dpy;
Window win;
RContext *ctx;
RImage *imgh, *imgv, *imgd;
Pixmap pix;
char *ProgName;

void print_help()
{
	printf("usage: %s [-options] color1 [color2 ...]\n", ProgName);
	puts("options:");
	puts(" -m 		match  colors");
	puts(" -d		dither colors (default)");
	puts(" -c <cpc>	colors per channel to use");
	puts(" -v <vis-id>	visual id to use");
}

int main(int argc, char **argv)
{
	RContextAttributes attr;
	RColor **colors = NULL;
	int i, rmode = RDitheredRendering, ncolors = 0, cpc = 4;
	char **color_name;
	XColor color;
	XSetWindowAttributes val;
	int visualID = -1;

	ProgName = strrchr(argv[0], '/');
	if (!ProgName)
		ProgName = argv[0];
	else
		ProgName++;

	color_name = (char **)malloc(sizeof(char *) * argc);
	if (color_name == NULL) {
		fprintf(stderr, "Cannot allocate memory!\n");
		exit(1);
	}

	if (argc > 1) {
		for (i = 1; i < argc; i++) {
			if (strcmp(argv[i], "-m") == 0) {
				rmode = RBestMatchRendering;
			} else if (strcmp(argv[i], "-d") == 0) {
				rmode = RDitheredRendering;
			} else if (strcmp(argv[i], "-c") == 0) {
				i++;
				if (i >= argc) {
					fprintf(stderr, "too few arguments for %s\n", argv[i - 1]);
					exit(0);
				}
				if (sscanf(argv[i], "%i", &cpc) != 1) {
					fprintf(stderr, "bad value for colors per channel: \"%s\"\n", argv[i]);
					exit(0);
				}
			} else if (strcmp(argv[i], "-v") == 0) {
				i++;
				if (i >= argc) {
					fprintf(stderr, "too few arguments for %s\n", argv[i - 1]);
					exit(0);
				}
				if (sscanf(argv[i], "%i", &visualID) != 1) {
					fprintf(stderr, "bad value for visual ID: \"%s\"\n", argv[i]);
					exit(0);
				}
			} else if (argv[i][0] != '-') {
				color_name[ncolors++] = argv[i];
			} else {
				print_help();
				exit(1);
			}
		}
	}

	if (ncolors == 0) {
		print_help();
		exit(1);
	}

	dpy = XOpenDisplay("");
	if (!dpy) {
		puts("cant open display");
		exit(1);
	}
	attr.flags = RC_RenderMode | RC_ColorsPerChannel;

	attr.render_mode = rmode;
	attr.colors_per_channel = cpc;

	if (visualID >= 0) {
		attr.flags |= RC_VisualID;
		attr.visualid = visualID;
	}

	ctx = RCreateContext(dpy, DefaultScreen(dpy), &attr);

	if (!ctx) {
		printf("could not initialize graphics library context: %s\n", RMessageForError(RErrorCode));
		exit(1);
	}

	colors = malloc(sizeof(RColor *) * (ncolors + 1));
	for (i = 0; i < ncolors; i++) {
		if (!XParseColor(dpy, ctx->cmap, color_name[i], &color)) {
			printf("could not parse color \"%s\"\n", color_name[i]);
			exit(1);
		} else {
			colors[i] = malloc(sizeof(RColor));
			colors[i]->red = color.red >> 8;
			colors[i]->green = color.green >> 8;
			colors[i]->blue = color.blue >> 8;
			printf("0x%02x%02x%02x\n", colors[i]->red, colors[i]->green, colors[i]->blue);
		}
	}
	colors[i] = NULL;

	val.background_pixel = ctx->black;
	val.colormap = ctx->cmap;
	val.backing_store = Always;
	win = XCreateWindow(dpy, DefaultRootWindow(dpy), 10, 10, 750, 250,
			    0, ctx->depth, InputOutput, ctx->visual,
			    CWColormap | CWBackPixel | CWBackingStore, &val);
	XMapRaised(dpy, win);
	XFlush(dpy);

	imgh = RRenderMultiGradient(250, 250, colors, RGRD_HORIZONTAL);
	imgv = RRenderMultiGradient(250, 250, colors, RGRD_VERTICAL);
	imgd = RRenderMultiGradient(250, 250, colors, RGRD_DIAGONAL);
	RConvertImage(ctx, imgh, &pix);
	XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0, 250, 250, 0, 0);
	RReleaseImage(imgh);

	RConvertImage(ctx, imgv, &pix);
	XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0, 250, 250, 250, 0);
	RReleaseImage(imgv);

	RConvertImage(ctx, imgd, &pix);
	XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0, 250, 250, 500, 0);
	RReleaseImage(imgd);

	XFlush(dpy);

	getchar();

	free(color_name);
	for (i = 0; i < ncolors + 1; i++)
		free(colors[i]);
	free(colors);

	RDestroyContext(ctx);
	RShutdown();
	XCloseDisplay(dpy);

	return 0;
}
