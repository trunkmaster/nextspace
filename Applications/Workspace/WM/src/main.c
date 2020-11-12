/*
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

#include "wconfig.h"

#ifdef HAVE_INOTIFY
#include <sys/inotify.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

/* Xlocale.h and locale.h are the same if X_LOCALE is undefind in wconfig.h,
 * and if X_LOCALE is defined, X's locale emulating functions will be used.
 * See Xlocale.h for more information.
 */
#include <X11/Xlocale.h>

#define MAINFILE

#include "WindowMaker.h"
#include "window.h"
#include "defaults.h"
#include "event.h"
#include "startup.h"
#include "menu.h"
#include "keybind.h"
#include "xmodifier.h"
#include "session.h"
#include "shutdown.h"
#include "main.h"

#include <WMcore/WMcore.h>

#include "dock.h"
#include <Workspace+WM.h>

#ifndef GLOBAL_DEFAULTS_SUBDIR
#define GLOBAL_DEFAULTS_SUBDIR "WindowMaker"
#endif

/****** Global Variables ******/
struct wmaker_global_variables w_global;

/* general info */

Display *dpy;

char *ProgName;

struct WPreferences wPreferences;

WShortKey wKeyBindings[WKBD_LAST];

/* notifications */
const char WMNManaged[] = "WMNManaged";
const char WMNUnmanaged[] = "WMNUnmanaged";
const char WMNChangedWorkspace[] = "WMNChangedWorkspace";
const char WMNChangedState[] = "WMNChangedState";
const char WMNChangedFocus[] = "WMNChangedFocus";
const char WMNChangedStacking[] = "WMNChangedStacking";
const char WMNChangedName[] = "WMNChangedName";

const char WMNWorkspaceCreated[] = "WMNWorkspaceCreated";
const char WMNWorkspaceDestroyed[] = "WMNWorkspaceDestroyed";
const char WMNWorkspaceChanged[] = "WMNWorkspaceChanged";
const char WMNWorkspaceNameChanged[] = "WMNWorkspaceNameChanged";

const char WMNResetStacking[] = "WMNResetStacking";

/******** End Global Variables *****/

static char *DisplayName = NULL;
static char **Arguments;
static int  *wVisualID = NULL;
static int  wVisualID_len = 0;

// int real_main(int argc, char **argv);
int WMInitialize(int argc, char **argv);

int getWVisualID(int screen)
{
  if (wVisualID == NULL)
    return -1;
  if (screen < 0 || screen >= wVisualID_len)
    return -1;

  return wVisualID[screen];
}

static void setWVisualID(int screen, int val)
{
  int i;

  if (screen < 0)
    return;

  if (wVisualID == NULL) {
    /* no array at all, alloc space for screen + 1 entries
     * and init with default value */
    wVisualID_len = screen + 1;
    wVisualID = (int *)malloc(wVisualID_len * sizeof(int));
    for (i = 0; i < wVisualID_len; i++) {
      wVisualID[i] = -1;
    }
  }
  else if (screen >= wVisualID_len) {
    /* larger screen number than previously allocated
       so enlarge array */
    int oldlen = wVisualID_len;

    wVisualID_len = screen + 1;
    wVisualID = (int *)wrealloc(wVisualID, wVisualID_len * sizeof(int));
    for (i = oldlen; i < wVisualID_len; i++) {
      wVisualID[i] = -1;
    }
  }

  wVisualID[screen] = val;
}

noreturn void Exit(int status)
{
  if (dpy)
    XCloseDisplay(dpy);

  RShutdown(); /* wrlib clean exit */
  wutil_shutdown();  /* WUtil clean-up */

  exit(status);
}

void Restart(char *manager, Bool abortOnFailure)
{
  char *prog = NULL;
  char *argv[MAX_RESTART_ARGS];
  int i;

  if (manager && manager[0] != 0) {
    prog = argv[0] = strtok(manager, " ");
    for (i = 1; i < MAX_RESTART_ARGS; i++) {
      argv[i] = strtok(NULL, " ");
      if (argv[i] == NULL) {
        break;
      }
    }
  }
  if (dpy) {
    XCloseDisplay(dpy);
    dpy = NULL;
  }
  if (!prog) {
    execvp(Arguments[0], Arguments);
    wfatal(_("failed to restart Window Maker."));
  } else {
    execvp(prog, argv);
    werror(_("could not exec %s"), prog);
  }
  if (abortOnFailure)
    exit(7);
}

void SetupEnvironment(WScreen * scr)
{
  char *tmp;

  tmp = wmalloc(60);
  snprintf(tmp, 60, "WRASTER_COLOR_RESOLUTION%i=%i", scr->screen,
           scr->rcontext->attribs->colors_per_channel);
  putenv(tmp);
}

typedef struct {
  WScreen *scr;
  char *command;
} _tuple;

static void shellCommandHandler(pid_t pid, unsigned int status, void *client_data)
{
  _tuple *data = (_tuple *) client_data;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) pid;

  if (status == 127) {
    char *buffer;

    buffer = wstrconcat(_("Could not execute command: "), data->command);
    dispatch_async(workspace_q, ^{
        WSRunAlertPanel(_("Run Error"), buffer, _("Got It"), NULL, NULL);
      });
    wfree(buffer);
  } else if (status != 127) {
    /*
      printf("%s: %i\n", data->command, status);
    */
  }

  wfree(data->command);
  wfree(data);
}

void ExecuteShellCommand(WScreen *scr, const char *command)
{
  static char *shell = NULL;
  pid_t pid;

  /*
   * This have a problem: if the shell is tcsh (not sure about others)
   * and ~/.tcshrc have /bin/stty erase ^H somewhere on it, the shell
   * will block and the command will not be executed.
   if (!shell) {
   shell = getenv("SHELL");
   if (!shell)
   shell = "/bin/sh";
   }
  */
  shell = "/bin/sh";

  pid = fork();

  if (pid == 0) {

    SetupEnvironment(scr);

#ifdef HAVE_SETSID
    setsid();
#endif
    execl(shell, shell, "-c", command, NULL);
    werror("could not execute %s -c %s", shell, command);
    Exit(-1);
  } else if (pid < 0) {
    werror("cannot fork a new process");
  } else {
    _tuple *data = wmalloc(sizeof(_tuple));

    data->scr = scr;
    data->command = wstrdup(command);

    wAddDeathHandler(pid, shellCommandHandler, data);
  }
}

/*
 *---------------------------------------------------------------------
 * RelaunchWindow--
 * 	Launch a new instance of the active window
 *
 *----------------------------------------------------------------------
 */
Bool RelaunchWindow(WWindow *wwin)
{
  if (! wwin || ! wwin->client_win) {
    werror("no window to relaunch");
    return False;
  }

  char **argv;
  int argc;

  if (! XGetCommand(dpy, wwin->client_win, &argv, &argc) || argc == 0 || argv == NULL) {
    werror("cannot relaunch the application because no WM_COMMAND property is set");
    return False;
  }

  pid_t pid = fork();

  if (pid == 0) {
    SetupEnvironment(wwin->screen_ptr);
#ifdef HAVE_SETSID
    setsid();
#endif
    /* argv is not null-terminated */
    char **a = (char **) malloc(argc + 1);
    if (! a) {
      werror("out of memory trying to relaunch the application");
      Exit(-1);
    }

    int i;
    for (i = 0; i < argc; i++)
      a[i] = argv[i];
    a[i] = NULL;

    execvp(a[0], a);
    Exit(-1);
  } else if (pid < 0) {
    werror("cannot fork a new process");

    XFreeStringList(argv);
    return False;
  } else {
    _tuple *data = wmalloc(sizeof(_tuple));

    data->scr = wwin->screen_ptr;
    data->command = wtokenjoin(argv, argc);

    /* not actually a shell command */
    wAddDeathHandler(pid, shellCommandHandler, data);

    XFreeStringList(argv);
  }

  return True;
}

/*
 *---------------------------------------------------------------------
 * wAbort--
 * 	Do a major cleanup and exit the program
 *
 *----------------------------------------------------------------------
 */
noreturn void wAbort(Bool dumpCore)
{
  WScreen *scr;

  scr = wDefaultScreen();
  if (scr)
    RestoreDesktop(scr);
  printf(_("%s aborted.\n"), ProgName);
  if (dumpCore)
    abort();
  else
    exit(1);
}

static void check_defaults(void)
{
  char *path;

  path = wdefaultspathfordomain("WindowMaker");

  if (access(path, R_OK) != 0) {
    wwarning(_("could not find user GNUstep directory (%s)."), path);

    if (system("wmaker.inst --batch") != 0) {
      wwarning(_("There was an error while creating GNUstep directory, please "
                 "make sure you have installed Window Maker correctly and run wmaker.inst"));
    } else {
      wwarning(_("%s directory created with default configuration."), path);
    }
  }

  wfree(path);
}

#ifdef HAVE_INOTIFY
/*
 * Add watch here, used to notify if configuration
 * files have changed, using linux kernel inotify mechanism
 */
static void inotifyWatchConfig(void)
{
  char *watchPath = NULL;

  w_global.inotify.fd_event_queue = inotify_init();	/* Initialise an inotify instance */
  if (w_global.inotify.fd_event_queue < 0) {
    wwarning(_("could not initialise an inotify instance."
               " Changes to the defaults database will require"
               " a restart to take effect. Check your kernel!"));
  } else {
    watchPath = wdefaultspathfordomain("");
    /* Add the watch; really we are only looking for modify events
     * but we might want more in the future so check all events for now.
     * The individual events are checked for in event.c.
     */
    w_global.inotify.wd_defaults = inotify_add_watch(w_global.inotify.fd_event_queue,
                                                     watchPath, IN_ALL_EVENTS);
    if (w_global.inotify.wd_defaults < 0) {
      wwarning(_("could not add an inotify watch on path %s."
                 " Changes to the defaults database will require"
                 " a restart to take effect."), watchPath);
      close(w_global.inotify.fd_event_queue);
      w_global.inotify.fd_event_queue = -1;
    }
  }
  wfree(watchPath);
}
#endif /* HAVE_INOTIFY */

void ExecInitScript(void)
{
  char *file, *paths;

  paths = wstrconcat(wusergnusteppath(), "/Workspace");
  paths = wstrappend(paths, ":" DEF_CONFIG_PATHS);

  file = wfindfile(paths, DEF_INIT_SCRIPT);
  wfree(paths);

  if (file) {
    if (system(file) != 0) {
      werror(_("%s:could not execute initialization script"), file);
    }
    wfree(file);
  }
}

void ExecExitScript(void)
{
  char *file, *paths;

  paths = wstrconcat(wusergnusteppath(), "/Workspace");
  paths = wstrappend(paths, ":" DEF_CONFIG_PATHS);

  file = wfindfile(paths, DEF_EXIT_SCRIPT);
  wfree(paths);

  if (file) {
    if (system(file) != 0) {
      werror(_("%s:could not execute exit script"), file);
    }
    wfree(file);
  }
}

int WMInitialize(int argc, char **argv)
{
  setlocale(LC_ALL, "");
  wsetabort(wAbort);

  if (!wPreferences.flags.noupdates) {
    /* check existence of Defaults DB directory */
    check_defaults();
  }

  if (w_global.locale) {
    setenv("LANG", w_global.locale, 1);
  } else {
    w_global.locale = getenv("LC_ALL");
    if (!w_global.locale) {
      w_global.locale = getenv("LANG");
    }
  }

  setlocale(LC_ALL, "");

  if (!w_global.locale || strcmp(w_global.locale, "C") == 0 ||
      strcmp(w_global.locale, "POSIX") == 0) {
    w_global.locale = NULL;
  }
#ifdef I18N
  if (getenv("NLSPATH")) {
    bindtextdomain("WindowMaker", getenv("NLSPATH"));
#if defined(MENU_TEXTDOMAIN)
    bindtextdomain(MENU_TEXTDOMAIN, getenv("NLSPATH"));
#endif
  }
  else {
    bindtextdomain("WindowMaker", LOCALEDIR);
#if defined(MENU_TEXTDOMAIN)
    bindtextdomain(MENU_TEXTDOMAIN, LOCALEDIR);
#endif
  }
  bind_textdomain_codeset("WindowMaker", "UTF-8");
#if defined(MENU_TEXTDOMAIN)
  bind_textdomain_codeset(MENU_TEXTDOMAIN, "UTF-8");
#endif
  textdomain("WindowMaker");

  if (!XSupportsLocale()) {
    wwarning(_("X server does not support locale"));
  }

  if (XSetLocaleModifiers("") == NULL) {
    wwarning(_("cannot set locale modifiers"));
  }
#endif

  if (w_global.locale) {
    char *ptr;

    w_global.locale = wstrdup(w_global.locale);
    ptr = strchr(w_global.locale, '.');
    if (ptr)
      *ptr = 0;
  }

  /* open display */
  dpy = XOpenDisplay(DisplayName);
  if (dpy == NULL) {
    wfatal(_("could not open display \"%s\""), XDisplayName(DisplayName));
    exit(1);
  }

  if (fcntl(ConnectionNumber(dpy), F_SETFD, FD_CLOEXEC) < 0) {
    werror("error setting close-on-exec flag for X connection");
    exit(1);
  }


  if (getWVisualID(0) < 0) {
    /*
     *   If unspecified, use default visual instead of waiting
     * for wrlib/context.c:bestContext() that may end up choosing
     * the "fake" 24 bits added by the Composite extension.
     *   This is required to avoid all sort of corruptions when
     * composite is enabled, and at a depth other than 24.
     */
    setWVisualID(0, (int)DefaultVisual(dpy, DefaultScreen(dpy))->visualid);
  }

  DisplayName = XDisplayName(DisplayName);
  setenv("DISPLAY", DisplayName, 1);

  wXModifierInitialize();
  StartUp(True);

  ExecInitScript();
#ifdef HAVE_INOTIFY
  inotifyWatchConfig();
#endif
  
  return 0;
}
