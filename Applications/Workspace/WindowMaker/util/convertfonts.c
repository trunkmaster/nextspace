/* convertfonts.c - converts fonts in a style file to fontconfig format
 *
 *  WindowMaker window manager
 *
 *  Copyright (c) 2004 Dan Pascu
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
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#include <WINGs/WUtil.h>

#include "../src/wconfig.h"

#include "common.h"


char *FontOptions[] = {
	"IconTitleFont",
	"ClipTitleFont",
	"LargeDisplayFont",
	"MenuTextFont",
	"MenuTitleFont",
	"WindowTitleFont",
	"SystemFont",
	"BoldSystemFont",
	NULL
};

static const char *prog_name;


static noreturn void print_help(int print_usage, int exitval)
{
	printf("Usage: %s [-h] [-v] [--keep-xlfd] <style_file>\n", prog_name);
	if (print_usage) {
		puts("Converts fonts in a style file into fontconfig format");
		puts("");
		puts("  -h, --help     display this help and exit");
		puts("  -v, --version  output version information and exit");
		puts("  --keep-xlfd    preserve the original xlfd by appending a ':xlfd=<xlfd>' hint");
		puts("                 to the font name. This property is not used by the fontconfig");
		puts("                 matching engine to find the font, but it is useful as a hint");
		puts("                 about what the original font was to allow hand tuning the");
		puts("                 result or restoring the xlfd. The default is to not add it");
		puts("                 as it results in long, unreadable and confusing names.");
	}
	exit(exitval);
}

int main(int argc, char **argv)
{
	WMPropList *style, *key, *val;
	char *file = NULL, *oldfont, *newfont;
	struct stat st;
	Bool keepXLFD = False;
	int i, ch;

	struct option longopts[] = {
		{ "version",	no_argument,	NULL,		'v' },
		{ "help",	no_argument,	NULL,		'h' },
		{ "keep-xlfd",	no_argument,	&keepXLFD,	True },
		{ NULL,		0,		NULL,		0 }
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

	if (stat(file, &st) != 0) {
		perror(file);
		return 1;
	}

	if (!S_ISREG(st.st_mode)) {		/* maybe symlink too? */
		fprintf(stderr, "%s: `%s' is not a regular file\n", prog_name, file);
		return 1;
	}

	/* we need this in order for MB_CUR_MAX to work */
	/* this contradicts big time with getstyle */
	setlocale(LC_ALL, "");

	WMPLSetCaseSensitive(False);

	style = WMReadPropListFromFile(file);
	if (!style) {
		perror(file);
		printf("%s: could not load style file\n", prog_name);
		return 1;
	}

	if (!WMIsPLDictionary(style)) {
		printf("%s: '%s' is not a well formatted style file\n", prog_name, file);
		return 1;
	}

	for (i = 0; FontOptions[i] != NULL; i++) {
		key = WMCreatePLString(FontOptions[i]);
		val = WMGetFromPLDictionary(style, key);
		if (val) {
			oldfont = WMGetFromPLString(val);
			newfont = convertFont(oldfont, keepXLFD);
			if (oldfont != newfont) {
				val = WMCreatePLString(newfont);
				WMPutInPLDictionary(style, key, val);
				WMReleasePropList(val);
				wfree(newfont);
			}
		}
		WMReleasePropList(key);
	}

	WMWritePropListToFile(style, file);

	return 0;
}
