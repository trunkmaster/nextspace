/* setstyle.c - loads style related options to wmaker
 *
 *  WindowMaker window manager
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

#ifdef __GLIBC__
#define _GNU_SOURCE		/* getopt_long */
#endif

#include "config.h"

#include <sys/stat.h>

#include <getopt.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <X11/Xlib.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#include <WINGs/WUtil.h>

#include "../src/wconfig.h"

#include "common.h"

#define MAX_OPTIONS 128

char *FontOptions[] = {
	"IconTitleFont",
	"ClipTitleFont",
	"LargeDisplayFont",
	"MenuTextFont",
	"MenuTitleFont",
	"WindowTitleFont",
	NULL
};

char *CursorOptions[] = {
	"NormalCursor",
	"ArrowCursor",
	"MoveCursor",
	"ResizeCursor",
	"TopLeftResizeCursor",
	"TopRightResizeCursor",
	"BottomLeftResizeCursor",
	"BottomRightResizeCursor",
	"VerticalResizeCursor",
	"HorizontalResizeCursor",
	"WaitCursor",
	"QuestionCursor",
	"TextCursor",
	"SelectCursor",
	NULL
};

static const char *prog_name;
int ignoreFonts = 0;
int ignoreCursors = 0;

Display *dpy;


static Bool isCursorOption(const char *option)
{
	int i;

	for (i = 0; CursorOptions[i] != NULL; i++) {
		if (strcasecmp(option, CursorOptions[i]) == 0) {
			return True;
		}
	}

	return False;
}

static Bool isFontOption(const char *option)
{
	int i;

	for (i = 0; FontOptions[i] != NULL; i++) {
		if (strcasecmp(option, FontOptions[i]) == 0) {
			return True;
		}
	}

	return False;
}

/*
 * finds elements in `texture' that reference external files,
 * prepends `prefix' to these files. `prefix' is a path component
 * that qualifies the external references to be absolute, possibly
 * pending further expansion
 */
static void hackPathInTexture(WMPropList * texture, const char *prefix)
{
	WMPropList *type;
	char *t;

	/* get texture type */
	type = WMGetFromPLArray(texture, 0);
	t = WMGetFromPLString(type);
	if (t == NULL)
		return;

	if (strcasecmp(t, "tpixmap") == 0 ||
	    strcasecmp(t, "spixmap") == 0 ||
	    strcasecmp(t, "mpixmap") == 0 ||
	    strcasecmp(t, "cpixmap") == 0 ||
	    strcasecmp(t, "tvgradient") == 0 ||
	    strcasecmp(t, "thgradient") == 0 ||
	    strcasecmp(t, "tdgradient") == 0) {
		WMPropList *file;
		char buffer[4018];

		/* get pixmap file path */
		file = WMGetFromPLArray(texture, 1);
		sprintf(buffer, "%s/%s", prefix, WMGetFromPLString(file));
		/* replace path with full path */
		WMDeleteFromPLArray(texture, 1);
		WMInsertInPLArray(texture, 1, WMCreatePLString(buffer));

	} else if (strcasecmp(t, "bitmap") == 0) {
		WMPropList *file;
		char buffer[4018];

		/* get bitmap file path */
		file = WMGetFromPLArray(texture, 1);
		sprintf(buffer, "%s/%s", prefix, WMGetFromPLString(file));
		/* replace path with full path */
		WMDeleteFromPLArray(texture, 1);
		WMInsertInPLArray(texture, 1, WMCreatePLString(buffer));

		/* get mask file path */
		file = WMGetFromPLArray(texture, 2);
		sprintf(buffer, "%s/%s", prefix, WMGetFromPLString(file));
		/* replace path with full path */
		WMDeleteFromPLArray(texture, 2);
		WMInsertInPLArray(texture, 2, WMCreatePLString(buffer));
	}
}

static void hackPaths(WMPropList * style, const char *prefix)
{
	WMPropList *keys;
	WMPropList *key;
	WMPropList *value;
	int i;

	keys = WMGetPLDictionaryKeys(style);

	for (i = 0; i < WMGetPropListItemCount(keys); i++) {
		key = WMGetFromPLArray(keys, i);

		value = WMGetFromPLDictionary(style, key);
		if (!value)
			continue;

		if (strcasecmp(WMGetFromPLString(key), "WorkspaceSpecificBack") == 0) {
			if (WMIsPLArray(value)) {
				int j;
				WMPropList *texture;

				for (j = 0; j < WMGetPropListItemCount(value); j++) {
					texture = WMGetFromPLArray(value, j);

					if (texture && WMIsPLArray(texture)
					    && WMGetPropListItemCount(texture) > 2) {

						hackPathInTexture(texture, prefix);
					}
				}
			}
		} else {

			if (WMIsPLArray(value) && WMGetPropListItemCount(value) > 2) {

				hackPathInTexture(value, prefix);
			}
		}
	}

	WMReleasePropList(keys);
}

static WMPropList *getColor(WMPropList * texture)
{
	WMPropList *value, *type;
	char *str;

	type = WMGetFromPLArray(texture, 0);
	if (!type)
		return NULL;

	value = NULL;

	str = WMGetFromPLString(type);
	if (strcasecmp(str, "solid") == 0) {
		value = WMGetFromPLArray(texture, 1);
	} else if (strcasecmp(str, "dgradient") == 0
		   || strcasecmp(str, "hgradient") == 0 || strcasecmp(str, "vgradient") == 0) {
		WMPropList *c1, *c2;
		int r1, g1, b1, r2, g2, b2;
		char buffer[32];

		c1 = WMGetFromPLArray(texture, 1);
		c2 = WMGetFromPLArray(texture, 2);
		if (!dpy) {
			if (sscanf(WMGetFromPLString(c1), "#%2x%2x%2x", &r1, &g1, &b1) == 3
			    && sscanf(WMGetFromPLString(c2), "#%2x%2x%2x", &r2, &g2, &b2) == 3) {
				sprintf(buffer, "#%02x%02x%02x", (r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2);
				value = WMCreatePLString(buffer);
			} else {
				value = c1;
			}
		} else {
			XColor color1;
			XColor color2;

			XParseColor(dpy, DefaultColormap(dpy, DefaultScreen(dpy)), WMGetFromPLString(c1), &color1);
			XParseColor(dpy, DefaultColormap(dpy, DefaultScreen(dpy)), WMGetFromPLString(c2), &color2);

			sprintf(buffer, "#%02x%02x%02x",
				(color1.red + color2.red) >> 9,
				(color1.green + color2.green) >> 9, (color1.blue + color2.blue) >> 9);
			value = WMCreatePLString(buffer);
		}
	} else if (strcasecmp(str, "mdgradient") == 0
		   || strcasecmp(str, "mhgradient") == 0 || strcasecmp(str, "mvgradient") == 0) {

		value = WMGetFromPLArray(texture, 1);

	} else if (strcasecmp(str, "tpixmap") == 0
		   || strcasecmp(str, "cpixmap") == 0 || strcasecmp(str, "spixmap") == 0) {

		value = WMGetFromPLArray(texture, 2);
	}

	return value;
}

/*
 * since some of the options introduce incompatibilities, we will need
 * to do a kluge here or the themes ppl will get real annoying.
 * So, treat for the absence of the following options:
 * IconTitleColor
 * IconTitleBack
 */
static void hackStyle(WMPropList * style)
{
	WMPropList *keys, *tmp;
	int foundIconTitle = 0, foundResizebarBack = 0;
	int i;

	keys = WMGetPLDictionaryKeys(style);

	for (i = 0; i < WMGetPropListItemCount(keys); i++) {
		char *str;

		tmp = WMGetFromPLArray(keys, i);
		str = WMGetFromPLString(tmp);
		if (str) {
			if (ignoreFonts && isFontOption(str)) {
				WMRemoveFromPLDictionary(style, tmp);
				continue;
			}
			if (ignoreCursors && isCursorOption(str)) {
				WMRemoveFromPLDictionary(style, tmp);
				continue;
			}
			if (isFontOption(str)) {
				WMPropList *value;
				char *newfont, *oldfont;

				value = WMGetFromPLDictionary(style, tmp);
				if (value) {
					oldfont = WMGetFromPLString(value);
					newfont = convertFont(oldfont, False);
					if (newfont != oldfont) {
						value = WMCreatePLString(newfont);
						WMPutInPLDictionary(style, tmp, value);
						WMReleasePropList(value);
						wfree(newfont);
					}
				}
			}
			if (strcasecmp(str, "IconTitleColor") == 0 || strcasecmp(str, "IconTitleBack") == 0) {
				foundIconTitle = 1;
			} else if (strcasecmp(str, "ResizebarBack") == 0) {
				foundResizebarBack = 1;
			}
		}
	}
	WMReleasePropList(keys);

	if (!foundIconTitle) {
		/* set the default values */
		tmp = WMGetFromPLDictionary(style, WMCreatePLString("FTitleColor"));
		if (tmp) {
			WMPutInPLDictionary(style, WMCreatePLString("IconTitleColor"), tmp);
		}

		tmp = WMGetFromPLDictionary(style, WMCreatePLString("FTitleBack"));
		if (tmp) {
			WMPropList *value;

			value = getColor(tmp);

			if (value) {
				WMPutInPLDictionary(style, WMCreatePLString("IconTitleBack"), value);
			}
		}
	}

	if (!foundResizebarBack) {
		/* set the default values */
		tmp = WMGetFromPLDictionary(style, WMCreatePLString("UTitleBack"));
		if (tmp) {
			WMPropList *value;

			value = getColor(tmp);

			if (value) {
				WMPropList *t;

				t = WMCreatePLArray(WMCreatePLString("solid"), value, NULL);
				WMPutInPLDictionary(style, WMCreatePLString("ResizebarBack"), t);
			}
		}
	}

	if (!WMGetFromPLDictionary(style, WMCreatePLString("MenuStyle"))) {
		WMPutInPLDictionary(style, WMCreatePLString("MenuStyle"), WMCreatePLString("normal"));
	}
}

static noreturn void print_help(int print_usage, int exitval)
{
	printf("Usage: %s [OPTIONS] FILE\n", prog_name);
	if (print_usage) {
		puts("Reads style/theme configuration from FILE and updates Window Maker.");
		puts("");
		puts("  --no-fonts          ignore font related options");
		puts("  --no-cursors        ignore cursor related options");
		puts("  --ignore <option>   ignore changes in the specified option");
		puts("  -h, --help          display this help and exit");
		puts("  -v, --version       output version information and exit");
	}
	exit(exitval);
}

int main(int argc, char **argv)
{
	WMPropList *prop, *style;
	char *path;
	char *file = NULL;
	struct stat st;
	int i, ch, ignflag = 0;
	int ignoreCount = 0;
	char *ignoreList[MAX_OPTIONS];
	XEvent ev;

	struct option longopts[] = {
		{ "version",	no_argument,		NULL,			'v' },
		{ "help",	no_argument,		NULL,			'h' },
		{ "no-fonts",	no_argument,		&ignoreFonts,		1 },
		{ "no-cursors",	no_argument,		&ignoreCursors,		1 },
		{ "ignore",	required_argument,	&ignflag,		1 },
		{ NULL,		0,			NULL,			0 }
	};

	prog_name = argv[0];
	while ((ch = getopt_long(argc, argv, "hv", longopts, NULL)) != -1)
		switch(ch) {
			case 'v':
				printf("%s (Window Maker %s)\n", prog_name, VERSION);
				return 0;
				/* NOTREACHED */
			case 'h':
				print_help(1, 0);
				/* NOTREACHED */
			case 0:
				if (ignflag) {
					if (ignoreCount >= MAX_OPTIONS) {
						printf("Maximum %d `ignore' arguments\n", MAX_OPTIONS);
						return 1;
					}
					ignoreList[ignoreCount++] = optarg;
					ignflag = 0;
				};
				break;
			default:
				print_help(0, 1);
				/* NOTREACHED */
		}

	argc -= optind;
	argv += optind;

	if (argc != 1)
		print_help(0, 1);

	file = argv[0];

	WMPLSetCaseSensitive(False);

	path = wdefaultspathfordomain("WindowMaker");

	prop = WMReadPropListFromFile(path);
	if (!prop) {
		perror(path);
		printf("%s: could not load WindowMaker configuration file.\n", prog_name);
		return 1;
	}

	if (stat(file, &st) < 0) {
		perror(file);
		return 1;
	}
	if (S_ISDIR(st.st_mode)) {		/* theme pack */
		char buf[PATH_MAX];
		char *homedir;

		if (realpath(file, buf) == NULL) {
			perror(file);
			return 1;
		}
		strncat(buf, "/style", sizeof(buf) - strlen(buf) - 1);

		if (stat(buf, &st) != 0 || !S_ISREG(st.st_mode)) {	/* maybe symlink too? */
			printf("%s: %s: style file not found or not a file\n", prog_name, buf);
			return 1;
		}

		style = WMReadPropListFromFile(buf);
		if (!style) {
			perror(buf);
			printf("%s: could not load style file.\n", prog_name);
			return 1;
		}

		buf[strlen(buf) - 6 /* strlen("/style") */] = '\0';
		homedir = wstrdup(wgethomedir());
		if (strlen(homedir) > 1	&&	/* this is insane, wgethomedir() returns `/' on error */
		    strncmp(homedir, buf, strlen(homedir)) == 0) {
			/* theme pack is under ${HOME}; exchange ${HOME} part
			 * for `~' so it gets portable references to the user home dir */
			*buf = '~';
			memmove(buf + 1, buf + strlen(homedir), strlen(buf) - strlen(homedir) + 1);
		}
		wfree(homedir);

		hackPaths(style, buf);		/* this will prefix pixmaps in the style
						 * with absolute(ish) references */

	} else {				/* normal style file */

		style = WMReadPropListFromFile(file);
		if (!style) {
			perror(file);
			printf("%s:could not load style file.\n", prog_name);
			return 1;
		}
	}

	if (!WMIsPLDictionary(style)) {
		printf("%s: '%s' is not a style file/theme\n", prog_name, file);
		return 1;
	}

	hackStyle(style);

	if (ignoreCount > 0) {
		for (i = 0; i < ignoreCount; i++) {
			WMRemoveFromPLDictionary(style, WMCreatePLString(ignoreList[i]));
		}
	}

	WMMergePLDictionaries(prop, style, True);

	WMWritePropListToFile(prop, path);

	dpy = XOpenDisplay("");
	if (dpy) {
		memset(&ev, 0, sizeof(XEvent));

		ev.xclient.type = ClientMessage;
		ev.xclient.message_type = XInternAtom(dpy, "_WINDOWMAKER_COMMAND", False);
		ev.xclient.window = DefaultRootWindow(dpy);
		ev.xclient.format = 8;
		strncpy(ev.xclient.data.b, "Reconfigure", sizeof(ev.xclient.data.b));

		XSendEvent(dpy, DefaultRootWindow(dpy), False, SubstructureRedirectMask, &ev);
		XFlush(dpy);
	}

	return 0;
}
