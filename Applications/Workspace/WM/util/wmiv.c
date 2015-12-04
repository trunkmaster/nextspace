/*
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#if !defined(_GNU_SOURCE)
#define _GNU_SOURCE
#endif

#include <X11/keysym.h>
#include <X11/XKBlib.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include "wraster.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <limits.h>
#include <unistd.h>
#include <sys/stat.h>
#include <getopt.h>
#include "config.h"

#ifdef HAVE_EXIF
#include <libexif/exif-data.h>
#endif

#ifdef HAVE_PTHREAD
#include <pthread.h>
#endif

#ifdef USE_XPM
extern int XpmCreatePixmapFromData(Display *, Drawable, char **, Pixmap *, Pixmap *, void *);
/*	this is the icon from eog project
	git.gnome.org/browse/eog
*/
#include "wmiv.h"
#endif

#define DEBUG 0
#define FILE_SEPARATOR '/'

Display *dpy;
Window win;
RContext *ctx;
RImage *img;
Pixmap pix;

const char *APPNAME = "wmiv";
int APPVERSION_MAJOR = 0;
int APPVERSION_MINOR = 7;
int NEXT = 0;
int PREV = 1;
float zoom_factor = 0;
int max_width = 0;
int max_height = 0;

Bool fullscreen_flag = False;
Bool focus = False;
Bool back_from_fullscreen = False;

#ifdef HAVE_PTHREAD
Bool diaporama_flag = False;
int diaporama_delay = 5;
pthread_t tid = 0;
#endif
XTextProperty title_property;
XTextProperty icon_property;
unsigned current_index = 1;
unsigned max_index = 1;

RColor lightGray;
RColor darkGray;
RColor black;
RColor red;

typedef struct link link_t;
struct link {
	const void *data;
	link_t *prev;
	link_t *next;
};

typedef struct linked_list {
	int count;
	link_t *first;
	link_t *last;
} linked_list_t;

linked_list_t list;
link_t *current_link;


/*
	load_oriented_image: used to load an image and optionally
	get its orientation if libexif is available
	return the image on success, NULL on failure
*/
RImage *load_oriented_image(RContext *context, const char *file, int index)
{
	RImage *image;
#ifdef HAVE_EXIF
	int orientation = 0;
#endif
	image = RLoadImage(context, file, index);
	if (!image)
		return NULL;
#ifdef HAVE_EXIF
	ExifData *exifData = exif_data_new_from_file(file);
	if (exifData) {
		ExifByteOrder byteOrder = exif_data_get_byte_order(exifData);
		ExifEntry *exifEntry = exif_data_get_entry(exifData, EXIF_TAG_ORIENTATION);
		if (exifEntry)
			orientation = exif_get_short(exifEntry->data, byteOrder);

		exif_data_free(exifData);
	}

/*
	0th Row      0th Column
	1  top          left side
	2  top          right side
	3  bottom     right side
	4  bottom     left side
	5  left side    top
	6  right side  top
	7  right side  bottom
	8  left side    bottom
*/

	if (image && (orientation > 1)) {
		RImage *tmp = NULL;
		switch (orientation) {
		case 2:
			tmp = RFlipImage(image, RHorizontalFlip);
			break;
		case 3:
			tmp = RRotateImage(image, 180);
			break;
		case 4:
			tmp = RFlipImage(image, RVerticalFlip);
			break;
		case 5: {
				RImage *tmp2;
				tmp2 = RFlipImage(image, RVerticalFlip);
				if (tmp2) {
					tmp = RRotateImage(tmp2, 90);
					RReleaseImage(tmp2);
				}
			}
			break;
		case 6:
			tmp = RRotateImage(image, 90);
			break;
		case 7: {
				RImage *tmp2;
				tmp2 = RFlipImage(image, RVerticalFlip);
				if (tmp2) {
					tmp = RRotateImage(tmp2, 270);
					RReleaseImage(tmp2);
				}
			}
			break;
		case 8:
			tmp = RRotateImage(image, 270);
			break;
		}
		if (tmp) {
			RReleaseImage(image);
			image = tmp;
		}
	}
#endif
	return image;
}

/*
	change_title: used to change window title
	return EXIT_SUCCESS on success, 1 on failure
*/
int change_title(XTextProperty *prop, char *filename)
{
	char *combined_title = NULL;
	if (!asprintf(&combined_title, "%s - %u/%u - %s", APPNAME, current_index, max_index, filename))
		if (!asprintf(&combined_title, "%s - %u/%u", APPNAME, current_index, max_index))
			return EXIT_FAILURE;
	XStringListToTextProperty(&combined_title, 1, prop);
	XSetWMName(dpy, win, prop);
	if (prop->value)
		XFree(prop->value);
	free(combined_title);
	return EXIT_SUCCESS;
}

/*
	rescale_image: used to rescale the current image based on the screen size
	return EXIT_SUCCESS on success
*/
int rescale_image(void)
{
	long final_width = img->width;
	long final_height = img->height;

	/* check if there is already a zoom factor applied */
	if (zoom_factor != 0) {
		final_width = img->width + (int)(img->width * zoom_factor);
		final_height = img->height + (int)(img->height * zoom_factor);
	}
	if ((max_width < final_width) || (max_height < final_height)) {
		long val = 0;
		if (final_width > final_height) {
			val = final_height * max_width / final_width;
			final_width = final_width * val / final_height;
			final_height = val;
			if (val > max_height) {
				val = final_width * max_height / final_height;
				final_height = final_height * val / final_width;
				final_width = val;
			}
		} else {
			val = final_width * max_height / final_height;
			final_height = final_height * val / final_width;
			final_width = val;
			if (val > max_width) {
				val = final_height * max_width / final_width;
				final_width = final_width * val / final_height;
				final_height = val;
			}
		}
	}
	if ((final_width != img->width) || (final_height != img->height)) {
		RImage *old_img = img;
		img = RScaleImage(img, final_width, final_height);
		if (!img) {
			img = old_img;
			return EXIT_FAILURE;
		}
		RReleaseImage(old_img);
	}
	if (!RConvertImage(ctx, img, &pix)) {
		fprintf(stderr, "%s\n", RMessageForError(RErrorCode));
		return EXIT_FAILURE;
	}
	return EXIT_SUCCESS;
}

/*
	maximize_image: find the best image size for the current display
	return EXIT_SUCCESS on success
*/
int maximize_image(void)
{
	rescale_image();
	XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0,
		img->width, img->height, max_width/2-img->width/2, max_height/2-img->height/2);
	return EXIT_SUCCESS;
}

/*
	merge_with_background: merge the current image with with a checkboard background
	return EXIT_SUCCESS on success, 1 on failure
*/
int merge_with_background(RImage *i)
{
	if (i) {
		RImage *back;
		back = RCreateImage(i->width, i->height, True);
		if (back) {
			int opaq = 255;
			int x = 0, y = 0;

			RFillImage(back, &lightGray);
			for (x = 0; x <= i->width; x += 8) {
				if (x/8 % 2)
					y = 8;
				else
					y = 0;
				for (; y <= i->height; y += 16)
					ROperateRectangle(back, RAddOperation, x, y, x+8, y+8, &darkGray);
			}

			RCombineImagesWithOpaqueness(i, back, opaq);
			RReleaseImage(back);
			return EXIT_SUCCESS;
		}
	}
	return EXIT_FAILURE;
}

/*
	turn_image: rotate the image by the angle passed
	return EXIT_SUCCESS on success, EXIT_FAILURE on failure
*/
int turn_image(float angle)
{
	RImage *tmp;

	if (!img)
		return EXIT_FAILURE;

	tmp = RRotateImage(img, angle);
	if (!tmp)
		return EXIT_FAILURE;

	if (!fullscreen_flag) {
		if (img->width != tmp->width || img->height != tmp->height)
			XResizeWindow(dpy, win, tmp->width, tmp->height);
	}

	RReleaseImage(img);
	img = tmp;

	rescale_image();
	if (!fullscreen_flag) {
		XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0, img->width, img->height, 0, 0);
	} else {
		XClearWindow(dpy, win);
		XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0,
			img->width, img->height, max_width/2-img->width/2, max_height/2-img->height/2);
	}

	return EXIT_SUCCESS;
}

/*
	turn_image_right: rotate the image by 90 degree
	return EXIT_SUCCESS on success, EXIT_FAILURE on failure
*/
int turn_image_right(void)
{
	return turn_image(90.0);
}

/*
	turn_image_left: rotate the image by -90 degree
	return EXIT_SUCCESS on success, 1 on failure
*/
int turn_image_left(void)
{
	return turn_image(-90.0);
}

/*
	draw_failed_image: create a red crossed image to indicate an error loading file
	return the image on success, NULL on failure

*/
RImage *draw_failed_image(void)
{
	RImage *failed_image = NULL;
	XWindowAttributes attr;

	if (win && (XGetWindowAttributes(dpy, win, &attr) >= 0))
		failed_image = RCreateImage(attr.width, attr.height, False);
	else
		failed_image = RCreateImage(50, 50, False);
	if (!failed_image)
		return NULL;

	RFillImage(failed_image, &black);
	ROperateLine(failed_image, RAddOperation, 0, 0, failed_image->width, failed_image->height, &red);
	ROperateLine(failed_image, RAddOperation, 0, failed_image->height, failed_image->width, 0, &red);

	return failed_image;
}

/*
	full_screen: sending event to the window manager to switch from/to full screen mode
	return EXIT_SUCCESS on success, 1 on failure
*/
int full_screen(void)
{
	XEvent xev;

	Atom wm_state = XInternAtom(dpy, "_NET_WM_STATE", True);
	Atom fullscreen = XInternAtom(dpy, "_NET_WM_STATE_FULLSCREEN", True);
	long mask = SubstructureNotifyMask;

	if (fullscreen_flag) {
		fullscreen_flag = False;
		zoom_factor = 0;
		back_from_fullscreen = True;
	} else {
		fullscreen_flag = True;
		zoom_factor = 1000;
	}

	memset(&xev, 0, sizeof(xev));
	xev.type = ClientMessage;
	xev.xclient.display = dpy;
	xev.xclient.window = win;
	xev.xclient.message_type = wm_state;
	xev.xclient.format = 32;
	xev.xclient.data.l[0] = fullscreen_flag;
	xev.xclient.data.l[1] = fullscreen;

	if (!XSendEvent(dpy, DefaultRootWindow(dpy), False, mask, &xev)) {
		fprintf(stderr, "Error: sending fullscreen event to xserver\n");
		return EXIT_FAILURE;
	}
	return EXIT_SUCCESS;
}

/*
	zoom_in_out: apply a zoom factor on the current image
	arg: 1 to zoom in, 0 to zoom out
	return EXIT_SUCCESS on success, 1 on failure
*/
int zoom_in_out(int z)
{
	RImage *old_img = img;
	RImage *tmp = load_oriented_image(ctx, current_link->data, 0);
	if (!tmp)
		return EXIT_FAILURE;

	if (z) {
		zoom_factor += 0.2;
		img = RScaleImage(tmp, tmp->width + (int)(tmp->width * zoom_factor),
				tmp->height + (int)(tmp->height * zoom_factor));
		if (!img) {
			img = old_img;
			return EXIT_FAILURE;
		}
	} else {
		zoom_factor -= 0.2;
		int new_width = tmp->width + (int) (tmp->width * zoom_factor);
		int new_height = tmp->height + (int)(tmp->height * zoom_factor);
		if ((new_width <= 0) || (new_height <= 0)) {
			zoom_factor += 0.2;
			RReleaseImage(tmp);
			return EXIT_FAILURE;
		}
		img = RScaleImage(tmp, new_width, new_height);
		if (!img) {
			img = old_img;
			return EXIT_FAILURE;
		}
	}
	RReleaseImage(old_img);
	RReleaseImage(tmp);
	XFreePixmap(dpy, pix);

	merge_with_background(img);
	if (!RConvertImage(ctx, img, &pix)) {
		fprintf(stderr, "%s\n", RMessageForError(RErrorCode));
		return EXIT_FAILURE;
	}
	XResizeWindow(dpy, win, img->width, img->height);
	return EXIT_SUCCESS;
}

/*
	zoom_in: transitional fct used to call zoom_in_out with zoom in flag
	return EXIT_SUCCESS on success, 1 on failure
*/
int zoom_in(void)
{
	return zoom_in_out(1);
}

/*
	zoom_out: transitional fct used to call zoom_in_out with zoom out flag
	return EXIT_SUCCESS on success, 1 on failure
*/
int zoom_out(void)
{
	return zoom_in_out(0);
}

/*
	change_image: load previous or next image
	arg: way which could be PREV or NEXT constant
	return EXIT_SUCCESS on success, 1 on failure
*/
int change_image(int way)
{
	if (img && current_link) {
		int old_img_width = img->width;
		int old_img_height = img->height;

		RReleaseImage(img);

		if (way == NEXT) {
			current_link = current_link->next;
			current_index++;
		} else {
			current_link = current_link->prev;
			current_index--;
		}
		if (current_link == NULL) {
			if (way == NEXT) {
				current_link = list.first;
				current_index = 1;
			} else {
				current_link = list.last;
				current_index = max_index;
			}
		}
		if (DEBUG)
			fprintf(stderr, "current file is> %s\n", (char *)current_link->data);
		img = load_oriented_image(ctx, current_link->data, 0);

		if (!img) {
			fprintf(stderr, "Error: %s %s\n", (char *)current_link->data,
				RMessageForError(RErrorCode));
			img = draw_failed_image();
		} else {
			merge_with_background(img);
		}
		rescale_image();
		if (!fullscreen_flag) {
			if ((old_img_width != img->width) || (old_img_height != img->height))
				XResizeWindow(dpy, win, img->width, img->height);
			else
				XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0, img->width, img->height, 0, 0);
			change_title(&title_property, (char *)current_link->data);
		} else {
			XClearWindow(dpy, win);
			XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0,
				img->width, img->height, max_width/2-img->width/2, max_height/2-img->height/2);
		}
		return EXIT_SUCCESS;
	}
	return EXIT_FAILURE;
}

#ifdef HAVE_PTHREAD
/*
	diaporama: send a xevent to display the next image at every delay set to diaporama_delay
	arg: not used
	return void
*/
void *diaporama(void *arg)
{
	(void) arg;

	XKeyEvent event;
	event.display = dpy;
	event.window = win;
	event.root = DefaultRootWindow(dpy);
	event.subwindow = None;
	event.time = CurrentTime;
	event.x = 1;
	event.y = 1;
	event.x_root = 1;
	event.y_root = 1;
	event.same_screen = True;
	event.keycode = XKeysymToKeycode(dpy, XK_Right);
	event.state = 0;
	event.type = KeyPress;

	while (diaporama_flag) {
		int r;
		r = XSendEvent(event.display, event.window, True, KeyPressMask, (XEvent *)&event);
		if (!r)
			fprintf(stderr, "Error sending event\n");
		XFlush(dpy);
		/* default sleep time between moving to next image */
		sleep(diaporama_delay);
	}
	tid = 0;
	return arg;
}
#endif

/*
	linked_list_init: init the linked list
*/
void linked_list_init(linked_list_t *list)
{
	list->first = list->last = 0;
	list->count = 0;
}

/*
	linked_list_add: add an element to the linked list
	return EXIT_SUCCESS on success, 1 otherwise
*/
int linked_list_add(linked_list_t *list, const void *data)
{
	link_t *link;

	/* calloc sets the "next" field to zero. */
	link = calloc(1, sizeof(link_t));
	if (!link) {
		fprintf(stderr, "Error: memory allocation failed\n");
		return EXIT_FAILURE;
	}
	link->data = data;
	if (list->last) {
		/* Join the two final links together. */
		list->last->next = link;
		link->prev = list->last;
		list->last = link;
	} else {
		list->first = link;
		list->last = link;
	}
	list->count++;
	return EXIT_SUCCESS;
}

/*
	linked_list_free: deallocate the whole linked list
*/
void linked_list_free(linked_list_t *list)
{
	link_t *link;
	link_t *next;
	for (link = list->first; link; link = next) {
		/* Store the next value so that we don't access freed memory. */
		next = link->next;
		if (link->data)
			free((char *)link->data);
		free(link);
	}
}

/*
	connect_dir: list and sort by name all files from a given directory
	arg: the directory path that contains images, the linked list where to add the new file refs
	return: the first argument of the list or NULL on failure
*/
link_t *connect_dir(char *dirpath, linked_list_t *li)
{
	struct dirent **dir;
	int dv, idx;
	char path[PATH_MAX] = "";

	if (!dirpath)
		return NULL;

	dv = scandir(dirpath, &dir, 0, alphasort);
	if (dv < 0) {
		/* maybe it's a file */
		struct stat stDirInfo;
		if (lstat(dirpath, &stDirInfo) == 0) {
			linked_list_add(li, strdup(dirpath));
			return li->first;
		} else {
			return NULL;
		}
	}
	for (idx = 0; idx < dv; idx++) {
			struct stat stDirInfo;
			if (dirpath[strlen(dirpath)-1] == FILE_SEPARATOR)
				snprintf(path, PATH_MAX, "%s%s", dirpath, dir[idx]->d_name);
			else
				snprintf(path, PATH_MAX, "%s%c%s", dirpath, FILE_SEPARATOR, dir[idx]->d_name);

			free(dir[idx]);
			if ((lstat(path, &stDirInfo) == 0) && !S_ISDIR(stDirInfo.st_mode))
				linked_list_add(li, strdup(path));
	}
	free(dir);
	return li->first;
}

/*
	main
*/
int main(int argc, char **argv)
{
	int option = -1;
	RContextAttributes attr;
	XEvent e;
	KeySym keysym;
	char *reading_filename = "";
	int screen, file_i;
	int quit = 0;
	XClassHint *class_hints;
	XSizeHints *size_hints;
	XWMHints *win_hints;
#ifdef USE_XPM
	Pixmap icon_pixmap, icon_shape;
#endif
	class_hints = XAllocClassHint();
	if (!class_hints) {
		fprintf(stderr, "Error: failure allocating memory\n");
		return EXIT_FAILURE;
	}
	class_hints->res_name = (char *)APPNAME;
	class_hints->res_class = "default";

	/* init colors */
	lightGray.red = lightGray.green = lightGray.blue = 211;
	darkGray.red = darkGray.green = darkGray.blue = 169;
	lightGray.alpha = darkGray.alpha = 1;
	black.red = black.green = black.blue = 0;
	red.red = 255;
	red.green = red.blue = 0;

	static struct option long_options[] = {
			{"version", no_argument, 0, 'v'},
			{"help", no_argument, 0, 'h'},
			{0, 0, 0, 0}
		};
	int option_index = 0;

	option = getopt_long (argc, argv, "hv", long_options, &option_index);
	if (option != -1) {
		switch (option) {
		case 'h':
			printf("Usage: %s [image(s)|directory]\n"
			"Options:\n"
			"  -h, --help     print this help text\n"
			"  -v, --version  print version\n"
			"Keys:\n"
			"  [+]            zoom in\n"
			"  [-]            zoom out\n"
			"  [Esc]          actual size\n"
#ifdef HAVE_PTHREAD
			"  [D]            launch diaporama mode\n"
#endif
			"  [L]            rotate image on the left\n"
			"  [Q]            quit\n"
			"  [R]            rotate image on the right\n"
			"  [▸]            next image\n"
			"  [◂]            previous image\n"
			"  [▴]            first image\n"
			"  [▾]            last image\n",
			argv[0]);
			return EXIT_SUCCESS;
		case 'v':
			fprintf(stderr, "%s version %d.%d\n", APPNAME, APPVERSION_MAJOR, APPVERSION_MINOR);
			return EXIT_SUCCESS;
		case '?':
			return EXIT_FAILURE;
		}
	}

	linked_list_init(&list);

	dpy = XOpenDisplay(NULL);
	if (!dpy) {
		fprintf(stderr, "Error: can't open display");
		linked_list_free(&list);
		return EXIT_FAILURE;
	}

	screen = DefaultScreen(dpy);
	max_width = DisplayWidth(dpy, screen);
	max_height = DisplayHeight(dpy, screen);

	attr.flags = RC_RenderMode | RC_ColorsPerChannel;
	attr.render_mode = RDitheredRendering;
	attr.colors_per_channel = 4;
	ctx = RCreateContext(dpy, DefaultScreen(dpy), &attr);

	if (argc < 2) {
		argv[1] = ".";
		argc = 2;
	}

	for (file_i = 1; file_i < argc; file_i++) {
		current_link = connect_dir(argv[file_i], &list);
		if (current_link) {
			reading_filename = (char *)current_link->data;
			max_index = list.count;
		}
	}

	img = load_oriented_image(ctx, reading_filename, 0);

	if (!img) {
		fprintf(stderr, "Error: %s %s\n", reading_filename, RMessageForError(RErrorCode));
		img = draw_failed_image();
		if (!current_link)
			return EXIT_FAILURE;
	}

	merge_with_background(img);
	rescale_image();

	if (DEBUG)
		fprintf(stderr, "display size: %dx%d\n", max_width, max_height);

	win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0,
		img->width, img->height, 0, 0, BlackPixel(dpy, screen));
	XSelectInput(dpy, win, KeyPressMask|StructureNotifyMask|ExposureMask|ButtonPressMask|FocusChangeMask);

	size_hints = XAllocSizeHints();
	if (!size_hints) {
		fprintf(stderr, "Error: failure allocating memory\n");
		return EXIT_FAILURE;
	}
	size_hints->width = img->width;
	size_hints->height = img->height;

	Atom delWindow = XInternAtom(dpy, "WM_DELETE_WINDOW", 0);
	XSetWMProtocols(dpy, win, &delWindow, 1);
	change_title(&title_property, reading_filename);

	win_hints = XAllocWMHints();
	if (win_hints) {
		win_hints->flags = StateHint|InputHint|WindowGroupHint;

#ifdef USE_XPM
		if ((XpmCreatePixmapFromData(dpy, win, wmiv_xpm, &icon_pixmap, &icon_shape, NULL)) == 0) {
			win_hints->flags |= IconPixmapHint|IconMaskHint|IconPositionHint;
			win_hints->icon_pixmap = icon_pixmap;
			win_hints->icon_mask = icon_shape;
			win_hints->icon_x = 0;
			win_hints->icon_y = 0;
		}
#endif
		win_hints->initial_state = NormalState;
		win_hints->input = True;
		win_hints->window_group = win;
		XStringListToTextProperty((char **)&APPNAME, 1, &icon_property);
		XSetWMProperties(dpy, win, NULL, &icon_property, argv, argc, size_hints, win_hints, class_hints);
		if (icon_property.value)
			XFree(icon_property.value);
		XFree(win_hints);
		XFree(class_hints);
		XFree(size_hints);

	}
	XMapWindow(dpy, win);
	XFlush(dpy);
	XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0, img->width, img->height, 0, 0);

	while (!quit) {
		XNextEvent(dpy, &e);
		if (e.type == ClientMessage) {
			if (e.xclient.data.l[0] == delWindow)
				quit = 1;
				break;
		}
		if (e.type == FocusIn) {
			focus = True;
			continue;
		}
		if (e.type == FocusOut) {
			focus = False;
			continue;
		}
		if (!fullscreen_flag && (e.type == Expose)) {
			XExposeEvent xev = e.xexpose;
			if (xev.count == 0)
				XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0, img->width, img->height, 0, 0);
			continue;
		}
		if (!fullscreen_flag && e.type == ConfigureNotify) {
			XConfigureEvent xce = e.xconfigure;
			if (xce.width != img->width || xce.height != img->height) {
				RImage *old_img = img;
				img = load_oriented_image(ctx, current_link->data, 0);
				if (!img) {
					/* keep the old img and window size */
					img = old_img;
					XResizeWindow(dpy, win, img->width, img->height);
				} else {
					RImage *tmp2;
					if (!back_from_fullscreen)
						/* manually resized window */
						tmp2 = RScaleImage(img, xce.width, xce.height);
					else {
						/* back from fullscreen mode, maybe img was rotated */
						tmp2 = img;
						back_from_fullscreen = False;
						XClearWindow(dpy, win);
					}
					merge_with_background(tmp2);
					if (RConvertImage(ctx, tmp2, &pix)) {
						RReleaseImage(old_img);
						img = RCloneImage(tmp2);
						RReleaseImage(tmp2);
						change_title(&title_property, (char *)current_link->data);
						XSync(dpy, True);
						XResizeWindow(dpy, win, img->width, img->height);
						XCopyArea(dpy, pix, win, ctx->copy_gc, 0, 0,
									img->width, img->height, 0, 0);

					}
				}
			}
			continue;
		}
		if (fullscreen_flag && e.type == ConfigureNotify) {
			maximize_image();
			continue;
		}
		if (e.type == ButtonPress) {
			switch (e.xbutton.button) {
			case Button1: {
				if (focus) {
					if (img && (e.xbutton.x > img->width/2))
						change_image(NEXT);
					else
						change_image(PREV);
					}
				}
				break;
			case Button4:
				zoom_in();
				break;
			case Button5:
				zoom_out();
				break;
			case 8:
				change_image(PREV);
				break;
			case 9:
				change_image(NEXT);
				break;
			}
			continue;
		}
		if (e.type == KeyPress) {
			keysym = XkbKeycodeToKeysym(dpy, e.xkey.keycode, 0, e.xkey.state & ShiftMask?1:0);
#ifdef HAVE_PTHREAD
			if (keysym != XK_Right)
				diaporama_flag = False;
#endif
			switch (keysym) {
			case XK_Right:
				change_image(NEXT);
				break;
			case XK_Left:
				change_image(PREV);
				break;
			case XK_Up:
				if (current_link) {
					current_link = list.last;
					change_image(NEXT);
				}
				break;
			case XK_Down:
				if (current_link) {
					current_link = list.first;
					change_image(PREV);
				}
				break;
#ifdef HAVE_PTHREAD
			case XK_F5:
			case XK_d:
				if (!tid) {
					if (current_link && !diaporama_flag) {
						diaporama_flag = True;
						pthread_create(&tid, NULL, &diaporama, NULL);
					} else {
						fprintf(stderr, "Can't use diaporama mode\n");
					}
				}
				break;
#endif
			case XK_q:
				quit = 1;
				break;
			case XK_Escape:
				if (!fullscreen_flag) {
					zoom_factor = -0.2;
					/* zoom_in will increase the zoom factor by 0.2 */
					zoom_in();
				} else {
					/* we are in fullscreen mode already, want to return to normal size */
					full_screen();
				}
				break;
			case XK_plus:
				zoom_in();
				break;
			case XK_minus:
				zoom_out();
				break;
			case XK_F11:
			case XK_f:
				full_screen();
				break;
			case XK_r:
				turn_image_right();
				break;
			case XK_l:
				turn_image_left();
				break;
			}

		}
	}

	if (img)
		RReleaseImage(img);
	if (pix)
		XFreePixmap(dpy, pix);
#ifdef USE_XPM
	if (icon_pixmap)
		XFreePixmap(dpy, icon_pixmap);
	if (icon_shape)
		XFreePixmap(dpy, icon_shape);
#endif
	linked_list_free(&list);
	RDestroyContext(ctx);
	RShutdown();
	XCloseDisplay(dpy);
	return EXIT_SUCCESS;
}
