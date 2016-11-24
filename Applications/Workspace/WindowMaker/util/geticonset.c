/* geticonset.c - outputs icon configuration from WindowMaker to stdout
 *
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

#ifdef __GLIBC__
#define _GNU_SOURCE		/* getopt_long */
#endif

#include "config.h"

#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#include <WINGs/WUtil.h>

#include "../src/wconfig.h"

static const char *prog_name;

static noreturn void print_help(int print_usage, int exitval)
{
	printf("Usage: %s [-h] [-v] [file]\n", prog_name);
	if (print_usage) {
		puts("Retrieves program icon configuration and output to FILE or to stdout");
		puts("");
		puts("  -h, --help     display this help and exit");
		puts("  -v, --version  output version information and exit");
	}
	exit(exitval);
}

int main(int argc, char **argv)
{
	WMPropList *window_name, *icon_key, *window_attrs, *icon_value;
	WMPropList *all_windows, *iconset, *keylist;
	char *path;
	int i, ch;

	struct option longopts[] = {
		{ "version",	no_argument,	NULL,		'v' },
		{ "help",	no_argument,	NULL,		'h' },
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

	path = wdefaultspathfordomain("WMWindowAttributes");

	all_windows = WMReadPropListFromFile(path);
	if (!all_windows) {
		printf("%s: could not load WindowMaker configuration file \"%s\".\n", prog_name, path);
		return 1;
	}

	iconset = WMCreatePLDictionary(NULL, NULL);

	keylist = WMGetPLDictionaryKeys(all_windows);
	icon_key = WMCreatePLString("Icon");

	for (i = 0; i < WMGetPropListItemCount(keylist); i++) {
		WMPropList *icondic;

		window_name = WMGetFromPLArray(keylist, i);
		if (!WMIsPLString(window_name))
			continue;

		window_attrs = WMGetFromPLDictionary(all_windows, window_name);
		if (window_attrs && WMIsPLDictionary(window_attrs)) {
			icon_value = WMGetFromPLDictionary(window_attrs, icon_key);
			if (icon_value) {
				icondic = WMCreatePLDictionary(icon_key, icon_value, NULL);
				WMPutInPLDictionary(iconset, window_name, icondic);
			}
		}
	}

	if (argc == 1) {
		WMWritePropListToFile(iconset, argv[0]);
	} else {
		puts(WMGetPropListDescription(iconset, True));
	}
	return 0;
}
