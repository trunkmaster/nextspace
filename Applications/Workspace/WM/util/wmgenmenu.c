/* Copyright (C) 2010 Carlos R. Mafra */

#ifdef __GLIBC__
#define _GNU_SOURCE		/* getopt_long */
#endif

#include "config.h"

#include <ctype.h>
#include <getopt.h>
#include <limits.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#include <WINGs/WUtil.h>

#include "../src/wconfig.h"

#define MAX_NR_APPS 128 /* Maximum number of entries in each apps list */
#define MAX_WMS 10      /* Maximum number of other window managers to check */

#include "wmgenmenu.h"

static void find_and_write(const char *group, char *list[][2], int this_is_terminals);
static void other_window_managers(void);
static void print_help(int print_usage, int exitval);

static const char *prog_name;

char *path, *terminal = NULL;

WMPropList *RMenu, *L1Menu, *L2Menu, *L3Menu, *L4Menu;

int main(int argc, char *argv[])
{
	char *t;
	int ch;
	char *tmp, *theme_paths, *style_paths, *icon_paths;

	tmp = wstrconcat("-noext ", PKGDATADIR);
	theme_paths = wstrconcat(tmp, "/Themes $HOME/GNUstep/Library/WindowMaker/Themes WITH setstyle");
	style_paths = wstrconcat(tmp, "/Styles $HOME/GNUstep/Library/WindowMaker/Styles WITH setstyle");
	icon_paths = wstrconcat(tmp, "/IconSets $HOME/GNUstep/Library/WindowMaker/IconSets WITH seticons");

	struct option longopts[] = {
		{ "version",		no_argument,	NULL,	'v' },
		{ "help",		no_argument,	NULL,	'h' },
		{ NULL,			0,		NULL,	0 }
	};

	prog_name = argv[0];
	while ((ch = getopt_long(argc, argv, "hv", longopts, NULL)) != -1)
		switch (ch) {
		case 'v':
			printf("%s (Window Maker %s)\n", prog_name, VERSION);
			return 0;
			/* NOTREACHED */
		case 'h':
			print_help(1, 0);
			/* NOTREACHED */
		default:
			print_help(0, 1);
			/* NOTREACHED */
		}

	argc -= optind;
	argv += optind;

	if (argc != 0)
		print_help(0, 1);

	path = getenv("PATH");
	setlocale(LC_ALL, "");

#if defined(HAVE_LIBINTL_H) && defined(I18N)
	if (getenv("NLSPATH"))
		bindtextdomain("wmgenmenu", getenv("NLSPATH"));
	else
		bindtextdomain("wmgenmenu", LOCALEDIR);

	bind_textdomain_codeset("wmgenmenu", "UTF-8");
	textdomain("wmgenmenu");
#endif

	/*
	 * The menu generated is a five-level hierarchy, of which the
	 * top level (RMenu) is only used to hold the others (a single
	 * PLString, which will be the title of the root menu)
	 *
	 * RMenu                Window Maker
	 *   L1Menu               Applications
	 *     L2Menu               Terminals
	 *       L3Menu               XTerm
	 *       L3Menu               RXVT
	 *     L2Menu               Internet
	 *       L3Menu               Firefox
	 *     L2Menu               E-mail
	 *   L1Menu               Appearance
	 *     L2Menu               Themes
	 *     L2Menu               Background
	 *       L3Menu               Solid
	 *         L4Menu               Indigo
	 *   L1Menu               Configure Window Maker
	 *
	 */

	/* Root */
	RMenu = WMCreatePLArray(WMCreatePLString("Window Maker"), NULL);

	/* Root -> Applications */
	L1Menu = WMCreatePLArray(WMCreatePLString(_("Applications")), NULL);

	/* Root -> Applications -> <category> */
	find_and_write(_("Terminals"), Terminals, 1);	/* always keep terminals the top item */
	find_and_write(_("Internet"), Internet, 0);
	find_and_write(_("Email"), Email, 0);
	find_and_write(_("Mathematics"), Mathematics, 0);
	find_and_write(_("File Managers"), File_managers, 0);
	find_and_write(_("Graphics"), Graphics, 0);
	find_and_write(_("Multimedia"), Multimedia, 0);
	find_and_write(_("Editors"), Editors, 0);
	find_and_write(_("Development"), Development, 0);
	find_and_write("Window Maker", WindowMaker, 0);
	find_and_write(_("Office"), Office, 0);
	find_and_write(_("Astronomy"), Astronomy, 0);
	find_and_write(_("Sound"), Sound, 0);
	find_and_write(_("Comics"), Comics, 0);
	find_and_write(_("Viewers"), Viewers, 0);
	find_and_write(_("Utilities"), Utilities, 0);
	find_and_write(_("System"), System, 0);
	find_and_write(_("Video"), Video, 0);
	find_and_write(_("Chat and Talk"), Chat, 0);
	find_and_write(_("P2P Network"), P2P, 0);
	find_and_write(_("Games"), Games, 0);
	find_and_write("OpenSUSE", OpenSUSE, 0);
	find_and_write("Mandriva", Mandriva, 0);

	WMAddToPLArray(RMenu, L1Menu);

	/* Root -> `Run' dialog */
	L1Menu = WMCreatePLArray(
		WMCreatePLString(_("Run...")),
		WMCreatePLString("SHEXEC"),
		WMCreatePLString(_("%A(Run, Type command:)")),
		NULL
	);
	WMAddToPLArray(RMenu, L1Menu);

	/* Root -> Appearance */
	L1Menu = WMCreatePLArray(WMCreatePLString(_("Appearance")), NULL);

	/* Root -> Appearance -> Themes */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Themes")),
		WMCreatePLString("OPEN_MENU"),
		WMCreatePLString(theme_paths),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Appearance -> Styles */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Styles")),
		WMCreatePLString("OPEN_MENU"),
		WMCreatePLString(style_paths),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Appearance -> Icon Sets */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Icon Sets")),
		WMCreatePLString("OPEN_MENU"),
		WMCreatePLString(icon_paths),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Appearance -> Background */
	L2Menu = WMCreatePLArray(WMCreatePLString(_("Background")), NULL);

	/* Root -> Appearance -> Background -> Solid */
	L3Menu = WMCreatePLArray(WMCreatePLString(_("Solid")), NULL);

#define SOLID_BACK(label, colorspec)									\
	L4Menu = WMCreatePLArray(									\
		WMCreatePLString(label),								\
		WMCreatePLString("EXEC"),								\
		WMCreatePLString("wdwrite WindowMaker WorkspaceBack '(solid, \"" colorspec "\")'"),	\
		NULL											\
	);												\
	WMAddToPLArray(L3Menu, L4Menu)

	/* Root -> Appearance -> Background -> Solid -> <color> */
	SOLID_BACK(_("Black"), "black");
	SOLID_BACK(_("Blue"), "#505075");
	SOLID_BACK(_("Indigo"), "#243e6c");
	SOLID_BACK(_("Bluemarine"), "#243e6c");
	SOLID_BACK(_("Purple"), "#554466");
	SOLID_BACK(_("Wheat"), "wheat4");
	SOLID_BACK(_("Dark Gray"), "#333340");
	SOLID_BACK(_("Wine"), "#400020");
#undef SOLID_BACK
	WMAddToPLArray(L2Menu, L3Menu);

	/* Root -> Appearance -> Background -> Gradient */
	L3Menu = WMCreatePLArray(WMCreatePLString(_("Gradient")), NULL);

#define GRADIENT_BACK(label, fcolorspec, tcolorspec)							\
	L4Menu = WMCreatePLArray(									\
		WMCreatePLString(label),								\
		WMCreatePLString("EXEC"),								\
		WMCreatePLString("wdwrite WindowMaker WorkspaceBack '(vgradient, \"" 			\
		    fcolorspec "\", \"" tcolorspec "\"'"),						\
		NULL											\
	);												\
	WMAddToPLArray(L3Menu, L4Menu)

	/* Root -> Appearance -> Background -> Gradient -> <color> */
	L4Menu = WMCreatePLArray(
		WMCreatePLString(_("Sunset")),
		WMCreatePLString("EXEC"),
		WMCreatePLString("wdwrite WindowMaker WorkspaceBack "
		    "'(mvgradient, deepskyblue4, black, deepskyblue4, tomato4)'"),
		NULL
	);
	WMAddToPLArray(L3Menu, L4Menu);
	GRADIENT_BACK(_("Sky"), "blue4", "white");
	GRADIENT_BACK(_("Blue Shades"), "#7080a5", "#101020");
	GRADIENT_BACK(_("Indigo Shades"), "#746ebc", "#242e4c");
	GRADIENT_BACK(_("Purple Shades"), "#654c66", "#151426");
	GRADIENT_BACK(_("Wheat Shades"), "#a09060", "#302010");
	GRADIENT_BACK(_("Grey Shades"), "#636380", "#131318");
	GRADIENT_BACK(_("Wine Shades"), "#600040", "#180010");
#undef GRADIENT_BACK
	WMAddToPLArray(L2Menu, L3Menu);

	/* Root -> Appearance -> Background -> Images */
	L3Menu = WMCreatePLArray(
		WMCreatePLString(_("Images")),
		WMCreatePLString("OPEN_MENU"),
		WMCreatePLString("-noext $HOME/GNUstep/Library/WindowMaker/Backgrounds WITH wmsetbg -u -t"),
		NULL
	);
	WMAddToPLArray(L2Menu, L3Menu);

	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Appearance -> Save Theme */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Save Theme")),
		WMCreatePLString("SHEXEC"),
		WMCreatePLString("getstyle -p \"%a(Theme name, Name to save theme as)\""),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Appearance -> Save IconSet */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Save IconSet")),
		WMCreatePLString("SHEXEC"),
		WMCreatePLString("geticonset $HOME/GNUstep/Library/WindowMaker/IconSets/"
			"\"%a(IconSet name,Name to save icon set as)\""),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);
	WMAddToPLArray(RMenu, L1Menu);

	/* Root -> Workspaces */
	L1Menu = WMCreatePLArray(
		WMCreatePLString(_("Workspaces")),
		WMCreatePLString("WORKSPACE_MENU"),
		NULL
	);
	WMAddToPLArray(RMenu, L1Menu);

	/* Root -> Workspace */
	L1Menu = WMCreatePLArray(WMCreatePLString(_("Workspace")), NULL);
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Hide Others")),
		WMCreatePLString("HIDE_OTHERS"),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Workspace -> Show All */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Show All")),
		WMCreatePLString("SHOW_ALL"),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Workspace -> Arrange Icons */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Arrange Icons")),
		WMCreatePLString("ARRANGE_ICONS"),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Workspace -> Refresh */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Refresh")),
		WMCreatePLString("REFRESH"),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Workspace -> Save Session */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Save Session")),
		WMCreatePLString("SAVE_SESSION"),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);

	/* Root -> Workspace -> Clear Session */
	L2Menu = WMCreatePLArray(
		WMCreatePLString(_("Clear Session")),
		WMCreatePLString("CLEAR_SESSION"),
		NULL
	);
	WMAddToPLArray(L1Menu, L2Menu);
	WMAddToPLArray(RMenu, L1Menu);

	/* Root -> Configure Window Maker */
	L1Menu = WMCreatePLArray(
		WMCreatePLString(_("Configure Window Maker")),
		WMCreatePLString("EXEC"),
		WMCreatePLString("WPrefs"),
		NULL
	);
	WMAddToPLArray(RMenu, L1Menu);

	/* Root -> Info Panel */
	L1Menu = WMCreatePLArray(
		WMCreatePLString(_("Info Panel")),
		WMCreatePLString("INFO_PANEL"),
		NULL
	);
	WMAddToPLArray(RMenu, L1Menu);

	/* Root -> Restart Window Maker */
	L1Menu = WMCreatePLArray(
		WMCreatePLString(_("Restart Window Maker")),
		WMCreatePLString("RESTART"),
		NULL
	);
	WMAddToPLArray(RMenu, L1Menu);

	/* Root -> Other Window Managers [-> <other window manager> ...] */
	other_window_managers();

	/* Root -> Lock Screen */
	t = wfindfile(path, "xlock");
	if (t) {
		L1Menu = WMCreatePLArray(
			WMCreatePLString(_("Lock Screen")),
			WMCreatePLString("EXEC"),
			WMCreatePLString("xlock -allowroot -usefirst -mode matrix"),
			NULL
		);
		WMAddToPLArray(RMenu, L1Menu);
		wfree(t);
	}

	/* Root -> Exit Window Maker */
	L1Menu = WMCreatePLArray(
		WMCreatePLString(_("Exit Window Maker")),
		WMCreatePLString("EXIT"),
		NULL
	);
	WMAddToPLArray(RMenu, L1Menu);

	printf("%s", WMGetPropListDescription(RMenu, True));
	puts("");

	return 0;
}

/*
 * Creates an L2Menu made of L3Menu items
 * Attaches to L1Menu
 * - make sure previous menus of these levels are
 *   attached to their parent before calling
 */
static void find_and_write(const char *group, char *list[][2], int this_is_terminals)
{
	int i, argc;
	char *t, **argv, buf[PATH_MAX];

	/* or else pre-existing menus of these levels
	 * will badly disturb empty group detection */
	L2Menu = NULL;
	L3Menu = NULL;

	i = 0;
	while (list[i][0]) {
		/* Before checking if app exists, split its options */
		wtokensplit(list[i][1], &argv, &argc);
		t = wfindfile(path, argv[0]);
		if (t) {
			/* find a terminal to be used for cmnds that need a terminal */
			if (this_is_terminals && !terminal)
				terminal = wstrdup(list[i][1]);
			if (*(argv[argc-1]) != '!') {
				L3Menu = WMCreatePLArray(
					WMCreatePLString(_(list[i][0])),
					WMCreatePLString("EXEC"),
					WMCreatePLString(list[i][1]),
					NULL
				);
			} else {
				char comm[PATH_MAX], *ptr;

				strncpy(comm, list[i][1], sizeof(comm) - 1);
				comm[sizeof(comm) - 1] = '\0';

				/* delete character " !" from the command */
				ptr = strchr(comm, '!');
				if (ptr != NULL) {
					while (ptr > comm) {
						if (!isspace(ptr[-1]))
							break;
						ptr--;
					}
					*ptr = '\0';
				}
				snprintf(buf, sizeof(buf), "%s -e %s", terminal ? terminal : "xterm" , comm);

				/* Root -> Applications -> <category> -> <application> */
				L3Menu = WMCreatePLArray(
					WMCreatePLString(_(list[i][0])),
					WMCreatePLString("EXEC"),
					WMCreatePLString(buf),
					NULL
				);
			}
			if (!L2Menu)
				L2Menu = WMCreatePLArray(
					WMCreatePLString(group),
					NULL
				);
			WMAddToPLArray(L2Menu, L3Menu);
			wfree(t);
		}
		i++;
	}
	if (L2Menu)
		WMAddToPLArray(L1Menu, L2Menu);
}

/*
 * Creates an L1Menu made of L2Menu items
 * - make sure previous menus of these levels are
 *   attached to their parent before calling
 * Attaches to RMenu
 */
static void other_window_managers(void)
{
	int i;
	char *t, buf[PATH_MAX];

	/* or else pre-existing menus of these levels
	 * will badly disturb empty group detection */
	L1Menu = NULL;
	L2Menu = NULL;

	i = 0;
	while (other_wm[i][0]) {
		t = wfindfile(path, other_wm[i][1]);
		if (t) {
			snprintf(buf, sizeof(buf), _("Start %s"), _(other_wm[i][0]));
			/* Root -> Other Window Managers -> <other window manager> */
			L2Menu = WMCreatePLArray(
				WMCreatePLString(buf),
				WMCreatePLString("RESTART"),
				WMCreatePLString(other_wm[i][1]),
				NULL
			);
			if (!L1Menu)
				L1Menu = WMCreatePLArray(
					WMCreatePLString(_("Other Window Managers")),
					NULL
				);
			WMAddToPLArray(L1Menu, L2Menu);
			wfree(t);
		}
		i++;
	}
	if (L1Menu)
		WMAddToPLArray(RMenu, L1Menu);
}

noreturn void print_help(int print_usage, int exitval)
{
	printf("Usage: %s [-h] [-v]\n", prog_name);
	if (print_usage) {
		puts("Writes a menu structure usable as ~/GNUstep/Defaults/WMRootMenu to stdout");
		puts("");
		puts("  -h, --help           display this help and exit");
		puts("  -v, --version        output version information and exit");
	}
	exit(exitval);
}
