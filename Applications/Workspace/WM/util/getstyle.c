/* getstyle.c - outputs style related options from WindowMaker to stdout
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

#include <sys/types.h>
#include <sys/stat.h>

#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <libgen.h>
#include <limits.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#include <WINGs/WUtil.h>

#include "common.h"

#ifndef PATH_MAX
#define PATH_MAX  1024
#endif

#include "../src/wconfig.h"


/* table of style related options */
static char *options[] = {
	"TitleJustify",
	"ClipTitleFont",
	"WindowTitleFont",
	"MenuTitleFont",
	"MenuTextFont",
	"IconTitleFont",
	"LargeDisplayFont",
	"HighlightColor",
	"HighlightTextColor",
	"ClipTitleColor",
	"CClipTitleColor",
	"FTitleColor",
	"PTitleColor",
	"UTitleColor",
	"FTitleBack",
	"PTitleBack",
	"UTitleBack",
	"ResizebarBack",
	"MenuTitleColor",
	"MenuTextColor",
	"MenuDisabledColor",
	"MenuTitleBack",
	"MenuTextBack",
	"IconBack",
	"IconTitleColor",
	"IconTitleBack",
	"FrameBorderWidth",
	"FrameBorderColor",
	"FrameFocusedBorderColor",
	"FrameSelectedBorderColor",
	"MenuStyle",
	"WindowTitleExtendSpace",
	"MenuTitleExtendSpace",
	"MenuTextExtendSpace",
	NULL
};

/* table of theme related options */
static char *theme_options[] = {
	"WorkspaceBack",
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

/* table of style related fonts */

static char *font_options[] = {
	"ClipTitleFont",
	"WindowTitleFont",
	"MenuTitleFont",
	"MenuTextFont",
	"IconTitleFont",
	"LargeDisplayFont",
	NULL
};

static const char *prog_name;

WMPropList *PixmapPath = NULL;

char *ThemePath = NULL;


static noreturn void print_help(int print_usage, int exitval)
{
	printf("Usage: %s [-t] [-p] [-h] [-v] [file]\n", prog_name);
	if (print_usage) {
		puts("Retrieves style/theme configuration and outputs to ~/GNUstep/Library/WindowMaker/Themes/file.themed/style or to stdout");
		puts("");
		puts("  -h, --help           display this help and exit");
		puts("  -v, --version        output version information and exit");
		puts("  -t, --theme-options  output theme related options when producing a style file");
		puts("  -p, --pack           produce output as a theme pack");
	}
	exit(exitval);
}

static Bool isFontOption(const char *option)
{
	int i;

	for (i = 0; font_options[i] != NULL; i++) {
		if (strcasecmp(option, font_options[i]) == 0) {
			return True;
		}
	}

	return False;
}

static void findCopyFile(const char *dir, const char *file)
{
	char *fullPath;

	fullPath = wfindfileinarray(PixmapPath, file);
	if (!fullPath) {
		wwarning("Could not find file %s", file);
		if (ThemePath)
			(void)wrmdirhier(ThemePath);
		return;
	}
	wcopy_file(dir, fullPath, fullPath);
	wfree(fullPath);
}

#define THEME_SUBPATH "/Library/WindowMaker/Themes/"
#define THEME_EXTDIR  ".themed/"

static void makeThemePack(WMPropList * style, const char *themeName)
{
	WMPropList *keys;
	WMPropList *key;
	WMPropList *value;
	int i;
	size_t themeNameLen;
	char *themeDir;
	const char *user_base;

	user_base = wusergnusteppath();
	if (user_base == NULL)
		return;
	themeNameLen = strlen(user_base) + sizeof(THEME_SUBPATH) + strlen(themeName) + sizeof(THEME_EXTDIR) + 1;
	themeDir = wmalloc(themeNameLen);
	snprintf(themeDir, themeNameLen,
	         "%s" THEME_SUBPATH "%s" THEME_EXTDIR,
	         user_base, themeName);
	ThemePath = themeDir;

	if (!wmkdirhier(themeDir)) {
		wwarning("Could not make theme dir %s\n", themeDir);
		return;
	}

	keys = WMGetPLDictionaryKeys(style);

	for (i = 0; i < WMGetPropListItemCount(keys); i++) {
		key = WMGetFromPLArray(keys, i);

		value = WMGetFromPLDictionary(style, key);
		if (value && WMIsPLArray(value) && WMGetPropListItemCount(value) > 2) {
			WMPropList *type;
			char *t;

			type = WMGetFromPLArray(value, 0);
			t = WMGetFromPLString(type);
			if (t == NULL)
				continue;

			if (strcasecmp(t, "tpixmap") == 0 ||
			    strcasecmp(t, "spixmap") == 0 ||
			    strcasecmp(t, "cpixmap") == 0 ||
			    strcasecmp(t, "mpixmap") == 0 ||
			    strcasecmp(t, "tdgradient") == 0 ||
			    strcasecmp(t, "tvgradient") == 0 ||
			    strcasecmp(t, "thgradient") == 0) {

				WMPropList *file;
				char *p;
				char *newPath;

				file = WMGetFromPLArray(value, 1);

				p = strrchr(WMGetFromPLString(file), '/');
				if (p) {
					wcopy_file(themeDir, WMGetFromPLString(file), WMGetFromPLString(file));

					newPath = wstrdup(p + 1);
					WMDeleteFromPLArray(value, 1);
					WMInsertInPLArray(value, 1, WMCreatePLString(newPath));
					free(newPath);
				} else {
					findCopyFile(themeDir, WMGetFromPLString(file));
				}
			} else if (strcasecmp(t, "bitmap") == 0) {

				WMPropList *file;
				char *p;
				char *newPath;

				file = WMGetFromPLArray(value, 1);

				p = strrchr(WMGetFromPLString(file), '/');
				if (p) {
					wcopy_file(themeDir, WMGetFromPLString(file), WMGetFromPLString(file));

					newPath = wstrdup(p + 1);
					WMDeleteFromPLArray(value, 1);
					WMInsertInPLArray(value, 1, WMCreatePLString(newPath));
					free(newPath);
				} else {
					findCopyFile(themeDir, WMGetFromPLString(file));
				}

				file = WMGetFromPLArray(value, 2);

				p = strrchr(WMGetFromPLString(file), '/');
				if (p) {
					wcopy_file(themeDir, WMGetFromPLString(file), WMGetFromPLString(file));

					newPath = wstrdup(p + 1);
					WMDeleteFromPLArray(value, 2);
					WMInsertInPLArray(value, 2, WMCreatePLString(newPath));
					free(newPath);
				} else {
					findCopyFile(themeDir, WMGetFromPLString(file));
				}
			}
		}
	}
	WMReleasePropList(keys);
}

int main(int argc, char **argv)
{
	WMPropList *prop, *style, *key, *val;
	char *path;
	int i, ch, theme_too = 0, make_pack = 0;
	char *style_file = NULL;

	struct option longopts[] = {
		{ "pack",		no_argument,	NULL,	'p' },
		{ "theme-options",	no_argument,	NULL,	't' },
		{ "version",		no_argument,	NULL,	'v' },
		{ "help",		no_argument,	NULL,	'h' },
		{ NULL,			0,		NULL,	0 }
	};

	prog_name = argv[0];
	while ((ch = getopt_long(argc, argv, "ptvh", longopts, NULL)) != -1)
		switch(ch) {
			case 'v':
				printf("%s (Window Maker %s)\n", prog_name, VERSION);
				return 0;
				/* NOTREACHED */
			case 'h':
				print_help(1, 0);
				/* NOTREACHED */
			case 'p':
				make_pack = 1;
				theme_too = 1;
				break;
			case 't':
				theme_too = 1;
			case 0:
				break;
			default:
				print_help(0, 1);
				/* NOTREACHED */
		}

	/* At most one non-option ARGV-element is accepted (the theme name) */
	if (argc - optind > 1)
		print_help(0, 1);

	if (argc - optind == 1)
		style_file = argv[argc - 1];

	if (make_pack && !style_file) {
		printf("%s: you must supply a name for the theme pack\n", prog_name);
		return 1;
	}

	WMPLSetCaseSensitive(False);

	path = wdefaultspathfordomain("WindowMaker");

	prop = WMReadPropListFromFile(path);
	if (!prop) {
		printf("%s: could not load WindowMaker configuration file \"%s\".\n", prog_name, path);
		return 1;
	}

	/* get global value */
	path = wglobaldefaultspathfordomain("WindowMaker");

	val = WMReadPropListFromFile(path);
	if (val) {
		WMMergePLDictionaries(val, prop, True);
		WMReleasePropList(prop);
		prop = val;
	}

	style = WMCreatePLDictionary(NULL, NULL);

	for (i = 0; options[i] != NULL; i++) {
		key = WMCreatePLString(options[i]);

		val = WMGetFromPLDictionary(prop, key);
		if (val) {
			WMRetainPropList(val);
			if (isFontOption(options[i])) {
				char *newfont, *oldfont;

				oldfont = WMGetFromPLString(val);
				newfont = convertFont(oldfont, False);
				/* newfont is a reference to old if conversion is not needed */
				if (newfont != oldfont) {
					WMReleasePropList(val);
					val = WMCreatePLString(newfont);
					wfree(newfont);
				}
			}
			WMPutInPLDictionary(style, key, val);
			WMReleasePropList(val);
		}
		WMReleasePropList(key);
	}

	val = WMGetFromPLDictionary(prop, WMCreatePLString("PixmapPath"));
	if (val)
		PixmapPath = val;

	if (theme_too) {
		for (i = 0; theme_options[i] != NULL; i++) {
			key = WMCreatePLString(theme_options[i]);

			val = WMGetFromPLDictionary(prop, key);
			if (val)
				WMPutInPLDictionary(style, key, val);
		}
	}

	if (make_pack) {
		char *path;

		makeThemePack(style, style_file);

		path = wmalloc(strlen(ThemePath) + 32);
		strcpy(path, ThemePath);
		strcat(path, "/style");
		WMWritePropListToFile(style, path);
		wfree(path);
	} else {
		if (style_file) {
			WMWritePropListToFile(style, style_file);
		} else {
			puts(WMGetPropListDescription(style, True));
		}
	}
	return 0;
}
