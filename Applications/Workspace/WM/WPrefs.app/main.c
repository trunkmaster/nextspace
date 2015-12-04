/*
 *  WPrefs - Window Maker Preferences Program
 *
 *  Copyright (c) 1998-2003 Alfredo K. Kojima
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

#include "config.h"

#include "WPrefs.h"

#include <assert.h>

#include <X11/Xlocale.h>
#include <X11/XKBlib.h>

#include <sys/wait.h>
#include <unistd.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

char *NOptionValueChanged = "NOptionValueChanged";
Bool xext_xkb_supported = False;


#define MAX_DEATHS	64

struct {
	pid_t pid;
	void *data;
	void (*handler) (void *);
} DeadHandlers[MAX_DEATHS];

static pid_t DeadChildren[MAX_DEATHS];
static int DeadChildrenCount = 0;

static noreturn void wAbort(Bool foo)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) foo;

	exit(1);
}

static void print_help(const char *progname)
{
	printf(_("usage: %s [options]\n"), progname);
	puts(_("options:"));
	puts(_(" -display <display>	display to be used"));
	puts(_(" --version		print version number and exit"));
	puts(_(" --help		print this message and exit"));
}

#if 0
static RETSIGTYPE handleDeadChild(int sig)
{
	pid_t pid;
	int status;

	pid = waitpid(-1, &status, WNOHANG);
	if (pid > 0) {
		DeadChildren[DeadChildrenCount++] = pid;
	}
}
#endif

void AddDeadChildHandler(pid_t pid, void (*handler) (void *), void *data)
{
	int i;

	for (i = 0; i < MAX_DEATHS; i++) {
		if (DeadHandlers[i].pid == 0) {
			DeadHandlers[i].pid = pid;
			DeadHandlers[i].handler = handler;
			DeadHandlers[i].data = data;
			break;
		}
	}
	assert(i != MAX_DEATHS);
}

int main(int argc, char **argv)
{
	Display *dpy;
	WMScreen *scr;
	char *path;
	int i;
	char *display_name = "";

	wsetabort(wAbort);

	memset(DeadHandlers, 0, sizeof(DeadHandlers));

	WMInitializeApplication("WPrefs", &argc, argv);

	WMSetResourcePath(RESOURCE_PATH);
	path = WMPathForResourceOfType("WPrefs.tiff", NULL);
	if (!path) {
		/* maybe it is run directly from the source directory */
		WMSetResourcePath(".");
		path = WMPathForResourceOfType("WPrefs.tiff", NULL);
		if (!path) {
			WMSetResourcePath("..");
		}
	}
	if (path) {
		wfree(path);
	}

	if (argc > 1) {
		for (i = 1; i < argc; i++) {
			if (strcmp(argv[i], "-version") == 0 || strcmp(argv[i], "--version") == 0) {
				printf("WPrefs (Window Maker) %s\n", VERSION);
				exit(0);
			} else if (strcmp(argv[i], "-display") == 0) {
				i++;
				if (i >= argc) {
					wwarning(_("too few arguments for %s"), argv[i - 1]);
					exit(0);
				}
				display_name = argv[i];
			} else {
				print_help(argv[0]);
				exit(0);
			}
		}
	}

	setlocale(LC_ALL, "");

#ifdef I18N
	if (getenv("NLSPATH"))
		bindtextdomain("WPrefs", getenv("NLSPATH"));
	else
		bindtextdomain("WPrefs", LOCALEDIR);
	bind_textdomain_codeset("WPrefs", "UTF-8");
	textdomain("WPrefs");

	if (!XSupportsLocale()) {
		wwarning(_("X server does not support locale"));
	}
	if (XSetLocaleModifiers("") == NULL) {
		wwarning(_("cannot set locale modifiers"));
	}
#endif

	dpy = XOpenDisplay(display_name);
	if (!dpy) {
		wfatal(_("could not open display %s"), XDisplayName(display_name));
		exit(0);
	}
#if 0
	XSynchronize(dpy, 1);
#endif
	scr = WMCreateScreen(dpy, DefaultScreen(dpy));
	if (!scr) {
		wfatal(_("could not initialize application"));
		exit(0);
	}

	xext_xkb_supported = XkbQueryExtension(dpy, NULL, NULL, NULL, NULL, NULL);

	WMPLSetCaseSensitive(False);

	Initialize(scr);

	while (1) {
		XEvent event;

		WMNextEvent(dpy, &event);

		while (DeadChildrenCount-- > 0) {
			int i;

			for (i = 0; i < MAX_DEATHS; i++) {
				if (DeadChildren[i] == DeadHandlers[i].pid) {
					(*DeadHandlers[i].handler) (DeadHandlers[i].data);
					DeadHandlers[i].pid = 0;
				}
			}
		}

		WMHandleEvent(&event);
	}
}
