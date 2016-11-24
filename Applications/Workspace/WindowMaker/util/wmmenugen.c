/*
 * wmmenugen - Window Maker PropList menu generator
 *
 * Copyright (c) 2010. Tamas Tevesz <ice@extreme.hu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <sys/types.h>
#include <sys/stat.h>

#include <ctype.h>
#include <ftw.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <errno.h>

#include "wmmenugen.h"

static void addWMMenuEntryCallback(WMMenuEntry *aEntry);
static void assemblePLMenuFunc(WMTreeNode *aNode, void *data);
static int dirParseFunc(const char *filename, const struct stat *st, int tflags, struct FTW *ftw);
static int menuSortFunc(const void *left, const void *right);
static int nodeFindSubMenuByNameFunc(const void *item, const void *cdata);
static WMTreeNode *findPositionInMenu(const char *submenu);


typedef void fct_parse_menufile(const char *file, cb_add_menu_entry *addWMMenuEntryCallback);
typedef Bool fct_validate_filename(const char *filename, const struct stat *st, int tflags, struct FTW *ftw);


static WMArray *plMenuNodes;
static const char *terminal;
static fct_parse_menufile *parse;
static fct_validate_filename *validateFilename;

static const char *prog_name;

/* Global Variables from wmmenugen.h */
WMTreeNode *menu;
char *env_lang, *env_ctry, *env_enc, *env_mod;

static void print_help(void)
{
	printf("Usage: %s -parser:<parser> fspec [fspec...]\n", prog_name);
	puts("Dynamically generate a menu in Property List format for Window Maker");
	puts("");
	puts("  -h, --help\t\tdisplay this help and exit");
	puts("  -parser=<name>\tspecify the format of the input, see below");
	puts("  --version\t\toutput version information and exit");
	puts("");
	puts("fspec: the file to be converted or the directory containing all the menu files");
	puts("");
	puts("Known parsers:");
	puts("  xdg\t\tDesktop Entry from FreeDesktop standard");
	puts("  wmconfig\tfrom the menu generation tool by the same name");
}

#ifdef DEBUG
static const char *get_parser_name(void)
{
	if (parse == &parse_xdg)
		return "xdg";
	if (parse == &parse_wmconfig)
		return "wmconfig";

	/* This case is not supposed to happen, but if it does it means that someone to update this list */
	return "<unknown>";
}
#endif

int main(int argc, char **argv)
{
	struct stat st;
	int i;
	int *previousDepth;

	prog_name = argv[0];
	plMenuNodes = WMCreateArray(8); /* grows on demand */
	menu = (WMTreeNode *)NULL;
	parse = NULL;
	validateFilename = NULL;

	/* assemblePLMenuFunc passes this around */
	previousDepth = (int *)wmalloc(sizeof(int));
	*previousDepth = -1;

	/* currently this is used only by the xdg parser, but it might be useful
	 * in the future localizing other menus, so it won't hurt to have it here.
	 */
	parse_locale(NULL, &env_lang, &env_ctry, &env_enc, &env_mod);
	terminal = find_terminal_emulator();

	for (i = 1; i <= argc; i++)
	{
		if (strncmp(argv[i], "-parser", 7) == 0 &&
		    (argv[i][7] == '=' ||
		     argv[i][7] == ':' || /* for legacy compatibility */
		     argv[i][7] == '\0')) {
			const char *name;

			if (argv[i][7] == '\0') {
				if (++i > argc) {
					fprintf(stderr, "%s: Missing parser name after \"-parser\"\n", prog_name);
					return 2;
				}
				name = argv[i];
			} else {
				name = argv[i] + 8;
			}

			if (strcmp(name, "xdg") == 0) {
				parse = &parse_xdg;
			} else if (strcmp(name, "wmconfig") == 0) {
				parse = &parse_wmconfig;
				validateFilename = &wmconfig_validate_file;
			} else {
				fprintf(stderr, "%s: Unknown parser \"%s\"\n", prog_name, name);
				return 2;
			}
			continue;
		}

		if (strcmp(argv[i], "--version") == 0) {
			printf("%s (Window Maker %s)\n", prog_name, VERSION);
			return 0;
		}

		if (strcmp(argv[i], "-h") == 0 ||
		    strcmp(argv[i], "-help") == 0 ||
		    strcmp(argv[i], "--help") == 0) {
			print_help();
			return 0;
		}

		if (parse == NULL) {
			fprintf(stderr, "%s: argument \"%s\" with no valid parser\n", prog_name, argv[i]);
			return 2;
		}

#if DEBUG
		fprintf(stderr, "%s: Using parser \"%s\" to process \"%s\"\n",
		        prog_name, get_parser_name(), argv[i]);
#endif

		if (stat(argv[i], &st) == -1) {
			fprintf(stderr, "%s: unable to stat \"%s\", %s\n",
			        prog_name, argv[i], strerror(errno));
			return 1;
		} else if (S_ISREG(st.st_mode)) {
			parse(argv[i], addWMMenuEntryCallback);
		} else if (S_ISDIR(st.st_mode)) {
			nftw(argv[i], dirParseFunc, 16, FTW_PHYS);
		} else {
			fprintf(stderr, "%s: \"%s\" is not a file or directory\n", prog_name, argv[i]);
			return 1;
		}
	}

	if (!menu) {
		fprintf(stderr, "%s: parsers failed to create a valid menu\n", prog_name);
		return 1;
	}

	WMSortTree(menu, menuSortFunc);
	WMTreeWalk(menu, assemblePLMenuFunc, previousDepth, True);

	i = WMGetArrayItemCount(plMenuNodes);
	if (i > 2) { /* more than one submenu unprocessed is almost certainly an error */
		fprintf(stderr, "%s: unprocessed levels on the stack. fishy.\n", prog_name);
		return 3;
	} else if (i > 1 ) { /* possibly the top-level attachment is not yet done */
		WMPropList *first, *next;

		next = WMPopFromArray(plMenuNodes);
		first = WMPopFromArray(plMenuNodes);
		WMAddToPLArray(first, next);
		WMAddToArray(plMenuNodes, first);
	}

	puts(WMGetPropListDescription((WMPropList *)WMGetFromArray(plMenuNodes, 0), True));

	return 0;
}

static int dirParseFunc(const char *filename, const struct stat *st, int tflags, struct FTW *ftw)
{
	(void)st;
	(void)tflags;
	(void)ftw;

	if (validateFilename &&
	    !validateFilename(filename, st, tflags, ftw))
		return 0;

	parse(filename, addWMMenuEntryCallback);
	return 0;
}

/* upon fully deducing one particular menu entry, parsers call back to this
 * function to have said menu entry added to the wm menu. initializes wm menu
 * with a root element if needed.
 */
static void addWMMenuEntryCallback(WMMenuEntry *aEntry)
{
	WMMenuEntry *wm;
	WMTreeNode *at;

	wm = (WMMenuEntry *)wmalloc(sizeof(WMMenuEntry));	/* this entry */
	at = (WMTreeNode *)NULL;				/* will be a child of this entry */

	if (!menu) {
		WMMenuEntry *root;

		root = (WMMenuEntry *)wmalloc(sizeof(WMMenuEntry));
		root->Name = "Applications";
		root->CmdLine = NULL;
		root->SubMenu = NULL;
		root->Flags = 0;
		menu = WMCreateTreeNode(root);
	}

	if (aEntry->SubMenu)
		at = findPositionInMenu(aEntry->SubMenu);

	if (!at)
		at = menu;

	wm->Flags = aEntry->Flags;
	wm->Name = wstrdup(aEntry->Name);
	wm->CmdLine = wstrdup(aEntry->CmdLine);
	wm->SubMenu = NULL;
	WMAddItemToTree(at, wm);

}

/* creates the proplist menu out of the abstract menu representation in `menu'.
 */
static void assemblePLMenuFunc(WMTreeNode *aNode, void *data)
{
	WMMenuEntry *wm;
	WMPropList *pl;
	int pDepth, cDepth;

	wm = (WMMenuEntry *)WMGetDataForTreeNode(aNode);
	cDepth = WMGetTreeNodeDepth(aNode);
	pDepth = *(int *)data;

	if (pDepth > cDepth) {				/* just ascended out of a/several submenu(s) */
		WMPropList *last, *but;			/* merge the tail up to the current position */
		int i;
		for (i = pDepth - cDepth; i > 0; i--) {
			last = WMPopFromArray(plMenuNodes);
			but = WMPopFromArray(plMenuNodes);
			WMAddToPLArray(but, last);
			WMAddToArray(plMenuNodes, but);
		}
	}

	if (!wm->CmdLine) {				/* new submenu */
		WMAddToArray(plMenuNodes, WMCreatePLArray(WMCreatePLString(wm->Name), NULL));
	} else {					/* new menu item */
		pl = WMPopFromArray(plMenuNodes);
		if (wm->Flags & F_RESTART_OTHER) {	/* RESTART, somewm */
			char buf[1024];
			memset(buf, 0, sizeof(buf));
			snprintf(buf, sizeof(buf), "%s %s", _("Restart"), wm->Name);
			WMAddToPLArray(pl, WMCreatePLArray(
				WMCreatePLString(buf),
				WMCreatePLString("RESTART"),
				WMCreatePLString(wm->CmdLine),
				NULL)
			);
		} else if (wm->Flags & F_RESTART_SELF) {/* RESTART */
			WMAddToPLArray(pl, WMCreatePLArray(
				WMCreatePLString(_("Restart Window Maker")),
				WMCreatePLString("RESTART"),
				NULL)
			);
		} else if (wm->Flags & F_QUIT) {	/* EXIT */
			WMAddToPLArray(pl, WMCreatePLArray(
				WMCreatePLString(_("Exit Window Maker")),
				WMCreatePLString("EXIT"),
				NULL)
			);
		} else {				/* plain simple command */
			char buf[1024];

			memset(buf, 0, sizeof(buf));
			if (wm->Flags & F_TERMINAL)	/* XXX: quoting! */
				snprintf(buf, sizeof(buf), "%s -e \"%s\"", terminal, wm->CmdLine);
			else
				snprintf(buf, sizeof(buf), "%s", wm->CmdLine);

			WMAddToPLArray(pl, WMCreatePLArray(
				WMCreatePLString(wm->Name),
				WMCreatePLString("SHEXEC"),
				WMCreatePLString(buf),
				NULL)
			);
		}
		WMAddToArray(plMenuNodes, pl);
	}

	*(int *)data = cDepth;
	return;
}

/* sort the menu tree; callback for WMSortTree()
 */
static int menuSortFunc(const void *left, const void *right)
{
	WMMenuEntry *leftwm;
	WMMenuEntry *rightwm;

	leftwm = (WMMenuEntry *)WMGetDataForTreeNode(*(WMTreeNode **)left);
	rightwm = (WMMenuEntry *)WMGetDataForTreeNode(*(WMTreeNode **)right);

	/* submenus first */
	if (!leftwm->CmdLine && rightwm->CmdLine)
		return -1;
	if (leftwm->CmdLine && !rightwm->CmdLine)
		return 1;

	/* the rest lexicographically */
	return strcasecmp(leftwm->Name, rightwm->Name);

}

/* returns the leaf an entry with the submenu spec `submenu' attaches to.
 * creates `submenu' path (anchored to the root) along the way.
 */
static WMTreeNode *findPositionInMenu(const char *submenu)
{
	char *q;
	WMMenuEntry *wm;
	WMTreeNode *node, *pnode;
	char buf[1024];

	/* qualify submenu with "Applications/" (the root node) */
	memset(buf, 0, sizeof(buf));
	snprintf(buf, sizeof(buf), "Applications/%s", submenu);

	/* start at the root */
	node = menu;

	q = strtok(buf, "/");
	while (q) {
		pnode = node;
		node = WMFindInTreeWithDepthLimit(pnode, nodeFindSubMenuByNameFunc, q, 1);
		if (!node) {
			wm = (WMMenuEntry *)wmalloc(sizeof(WMMenuEntry));
			wm->Flags = 0;
			wm->Name = wstrdup(q);
			wm->CmdLine = NULL;
			wm->SubMenu = NULL;
			node = WMAddNodeToTree(pnode, WMCreateTreeNode(wm));
		}
		q = strtok(NULL, "/");
	}

	return node;
}

/* find node where Name = cdata and node is a submenu
 */
static int nodeFindSubMenuByNameFunc(const void *item, const void *cdata)
{
	WMMenuEntry *wm;

	wm = (WMMenuEntry *)item;

	if (wm->CmdLine) /* if it has a cmdline, it can't be a submenu */
		return 0;

	return strcmp(wm->Name, (const char *)cdata) == 0;
}
