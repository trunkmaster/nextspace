/* seticons.c - sets icon configuration in WindowMaker
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
	printf("Usage: %s [-h] [-v] file\n", prog_name);
	if (print_usage) {
		puts("Reads icon configuration from FILE and updates Window Maker.");
		puts("");
		puts("  -h, --help     display this help and exit");
		puts("  -v, --version  output version information and exit");
	}
	exit(exitval);
}

int main(int argc, char **argv)
{
	WMPropList *window_name, *window_attrs, *icon_value;
	WMPropList *all_windows, *iconset, *keylist;
	int i, ch;
	char *path = NULL;

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

	if (argc != 1)
		print_help(0, 1);

	path = wdefaultspathfordomain("WMWindowAttributes");

	all_windows = WMReadPropListFromFile(path);
	if (!all_windows) {
		printf("%s: could not load WindowMaker configuration file \"%s\".\n", prog_name, path);
		return 1;
	}

	iconset = WMReadPropListFromFile(argv[0]);
	if (!iconset) {
		printf("%s: could not load icon set file \"%s\".\n", prog_name, argv[0]);
		return 1;
	}

	keylist = WMGetPLDictionaryKeys(iconset);

	for (i = 0; i < WMGetPropListItemCount(keylist); i++) {
		window_name = WMGetFromPLArray(keylist, i);
		if (!WMIsPLString(window_name))
			continue;

		icon_value = WMGetFromPLDictionary(iconset, window_name);
		if (!icon_value || !WMIsPLDictionary(icon_value))
			continue;

		window_attrs = WMGetFromPLDictionary(all_windows, window_name);
		if (window_attrs) {
			if (WMIsPLDictionary(window_attrs)) {
				WMMergePLDictionaries(window_attrs, icon_value, True);
			}
		} else {
			WMPutInPLDictionary(all_windows, window_name, icon_value);
		}
	}

	WMWritePropListToFile(all_windows, path);

	return 0;
}
