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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#include "wconfig.h"

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

#define MAINFILE

#include "WindowMaker.h"
#include "window.h"
#include "funcs.h"
#include "menu.h"
#include "keybind.h"
#include "xmodifier.h"
#include "defaults.h"
#include "session.h"
#include "dialog.h"

#include "winspector.h"
#include "properties.h"
#include "wmspec.h"
#include "client.h"

#include <WINGs/WUtil.h>

#include <Foundation/Foundation.h>

#include <X11/Xlocale.h>
/****** Global Variables ******/

/* general info */

Display	*dpy;

char *ProgName;

unsigned int ValidModMask = 0xff;

/* locale to use. NULL==POSIX or C */
char *Locale=NULL;

int wScreenCount=0;

WPreferences wPreferences;


WMPropList *wDomainName;
WMPropList *wAttributeDomainName;

WShortKey wKeyBindings[WKBD_LAST];

/* defaults domains */
WDDomain *WDWindowMaker = NULL;
WDDomain *WDWindowAttributes = NULL;
WDDomain *WDRootMenu = NULL;

/* XContexts */
XContext wWinContext;
XContext wAppWinContext;
XContext wStackContext;
XContext wVEdgeContext;

/* Atoms */
Atom _XA_WM_STATE;
Atom _XA_WM_CHANGE_STATE;
Atom _XA_WM_PROTOCOLS;
Atom _XA_WM_TAKE_FOCUS;
Atom _XA_WM_DELETE_WINDOW;
Atom _XA_WM_SAVE_YOURSELF;
Atom _XA_WM_CLIENT_LEADER;
Atom _XA_WM_COLORMAP_WINDOWS;
Atom _XA_WM_COLORMAP_NOTIFY;

Atom _XA_GNUSTEP_WM_ATTR;
Atom _XA_GNUSTEP_WM_MINIATURIZE_WINDOW;
Atom _XA_GNUSTEP_WM_RESIZEBAR;
Atom _XA_GNUSTEP_TITLEBAR_STATE;

Atom _XA_WINDOWMAKER_MENU;
Atom _XA_WINDOWMAKER_WM_PROTOCOLS;
Atom _XA_WINDOWMAKER_STATE;

Atom _XA_WINDOWMAKER_WM_FUNCTION;
Atom _XA_WINDOWMAKER_NOTICEBOARD;
Atom _XA_WINDOWMAKER_COMMAND;

Atom _XA_WINDOWMAKER_ICON_SIZE;
Atom _XA_WINDOWMAKER_ICON_TILE;


/* cursors */
Cursor wCursor[WCUR_LAST];

/* last event timestamp for XSetInputFocus */
Time LastTimestamp = CurrentTime;
/* timestamp on the last time we did XSetInputFocus() */
Time LastFocusChange = CurrentTime;

#ifdef SHAPE
Bool wShapeSupported;
int wShapeEventBase;
#endif

/* special flags */
char WProgramSigState = 0;
char WProgramState = WSTATE_NORMAL;
char WDelayedActionSet = 0;


/* temporary stuff */
int wVisualID = -1;


/* notifications */
const char *WMNManaged = "WMNManaged";
const char *WMNUnmanaged = "WMNUnmanaged";
const char *WMNChangedWorkspace = "WMNChangedWorkspace";
const char *WMNChangedState = "WMNChangedState";
const char *WMNChangedFocus = "WMNChangedFocus";
const char *WMNChangedStacking = "WMNChangedStacking";
const char *WMNChangedName = "WMNChangedName";

const char *WMNWorkspaceCreated = "WMNWorkspaceCreated";
const char *WMNWorkspaceDestroyed = "WMNWorkspaceDestroyed";
const char *WMNWorkspaceChanged = "WMNWorkspaceChanged";
const char *WMNWorkspaceNameChanged = "WMNWorkspaceNameChanged";

const char *WMNResetStacking = "WMNResetStacking";

/******** End Global Variables *****/

static char *DisplayName = NULL;

static char **Arguments;

static int ArgCount;

extern void EventLoop();
extern void StartUp();
extern int MonitorLoop(int argc, char **argv);

static Bool multiHead = True;

/* stdi/o for log shell */
static int LogStdIn = -1, LogStdOut = -1, LogStdErr = -1;


void
Exit(int status)
{
#ifdef XSMP_ENABLED
    wSessionDisconnectManager();
#endif
    if (dpy)
        XCloseDisplay(dpy);

    exit(status);
}

void
Restart(char *manager, Bool abortOnFailure)
{
    char *prog=NULL;
    char *argv[MAX_RESTART_ARGS];
    int i;

    if (manager && manager[0]!=0) {
        prog = argv[0] = strtok(manager, " ");
        for (i=1; i<MAX_RESTART_ARGS; i++) {
            argv[i]=strtok(NULL, " ");
            if (argv[i]==NULL) {
                break;
            }
        }
    }
    if (dpy) {
#ifdef XSMP_ENABLED
        wSessionDisconnectManager();
#endif
        XCloseDisplay(dpy);
        dpy = NULL;
    }
    if (!prog) {
        execvp(Arguments[0], Arguments);
        wfatal("failed to restart Window Maker.");
    } else {
        execvp(prog, argv);
        wsyserror("could not exec %s", prog);
    }
    if (abortOnFailure)
        exit(7);
}

void
SetupEnvironment(WScreen *scr)
{
    char *tmp, *ptr;
    char buf[16];

    if (multiHead) {
        int len = strlen(DisplayName)+64;
        tmp = wmalloc(len);
        snprintf(tmp, len, "DISPLAY=%s", XDisplayName(DisplayName));
        ptr = strchr(strchr(tmp, ':'), '.');
        if (ptr)
            *ptr = 0;
        snprintf(buf, sizeof(buf), ".%i", scr->screen);
        strcat(tmp, buf);
        putenv(tmp);
    }
    tmp = wmalloc(60);
    snprintf(tmp, 60, "WRASTER_COLOR_RESOLUTION%i=%i", scr->screen,
             scr->rcontext->attribs->colors_per_channel);
    putenv(tmp);
}


typedef struct {
    WScreen *scr;
    char *command;
} _tuple;


static void
shellCommandHandler(pid_t pid, unsigned char status, _tuple *data)
{
    if (status == 127) {
        char *buffer;

        buffer = wstrconcat("Could not execute command: ", data->command);

        wMessageDialog(data->scr, ("Error"), buffer, ("OK"), NULL, NULL);
        wfree(buffer);
    } else if (status != 127) {
        /*
         printf("%s: %i\n", data->command, status);
         */
    }

    wfree(data->command);
    wfree(data);
}


void
ExecuteShellCommand(WScreen *scr, char *command)
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

    if (pid==0) {

        SetupEnvironment(scr);

#ifdef HAVE_SETSID
        setsid();
#endif
        execl(shell, shell, "-c", command, NULL);
        wsyserror("could not execute %s -c %s", shell, command);
        Exit(-1);
    } else if (pid < 0) {
        wsyserror("cannot fork a new process");
    } else {
        _tuple *data = wmalloc(sizeof(_tuple));

        data->scr = scr;
        data->command = wstrdup(command);

        wAddDeathHandler(pid, (WDeathHandler*)shellCommandHandler, data);
    }
}


/*
 *---------------------------------------------------------------------------
 * StartLogShell
 * 	Start a shell that will receive all stdin and stdout from processes
 * forked by wmaker.
 *---------------------------------------------------------------------------
 */
void
StartLogShell(WScreen *scr)
{
    int in_fd[2];
    int out_fd[2];
    int err_fd[2];
    pid_t pid;

    SetupEnvironment(scr);

    if (pipe(in_fd) < 0) {
        wsyserror("could not create pipe for log shell\n");
        return;
    }
    if (pipe(out_fd) < 0) {
        wsyserror("could not create pipe for log shell\n");
        close(in_fd[0]);
        close(in_fd[1]);
        return;
    }
    if (pipe(err_fd) < 0) {
        wsyserror("could not create pipe for log shell\n");
        close(out_fd[0]);
        close(out_fd[1]);
        close(in_fd[0]);
        close(in_fd[1]);
        return;
    }

    pid = fork();
    if (pid < 0) {
        wsyserror("could not fork a new process for log shell\n");
        return;
    } else if (pid == 0) {
        close(in_fd[0]);
        close(out_fd[1]);
        close(err_fd[1]);

        close(0);
        close(1);
        close(2);

        if (dup2(in_fd[1], 0) < 0) {
            wsyserror("could not redirect stdin for log shell\n");
            exit(1);
        }
        if (dup2(out_fd[1], 1) < 0) {
            wsyserror("could not redirect stdout for log shell\n");
            exit(1);
        }
        if (dup2(err_fd[1], 2) < 0) {
            wsyserror("could not redirect stderr for log shell\n");
            exit(1);
        }

        close(in_fd[1]);
        close(out_fd[1]);
        close(err_fd[1]);

        execl("/bin/sh", "/bin/sh", "-c", wPreferences.logger_shell, NULL);
        wsyserror("could not execute %s\n", wPreferences.logger_shell);
        exit(1);
    } else {
        close(in_fd[1]);
        close(out_fd[0]);
        close(err_fd[0]);

        LogStdIn = in_fd[1];
        LogStdOut = out_fd[0];
        LogStdErr = err_fd[0];
    }
}


//---------------------------------------------------------------------
// wAbort--
// 	Do a major cleanup and exit the program
//
//----------------------------------------------------------------------
void
wAbort(Bool dumpCore)
{
    int i;
    WScreen *scr;

    for (i=0; i<wScreenCount; i++) {
        scr = wScreenWithNumber(i);
        if (scr)
            RestoreDesktop(scr);
    }
    printf(("%s aborted.\n"), ProgName);
    if (dumpCore)
        abort();
    else
        exit(1);
}

void
check_defaults()
{
  char *path;

  path = wdefaultspathfordomain("WindowMaker");

  if (access(path, R_OK)!=0) {
#if 0
      wfatal(("could not find user GNUstep directory (%s).\n"
	      "Make sure you have installed Window Maker correctly and run wmaker.inst"),
	     path);
      exit(1);
#else
      wwarning(("could not find user GNUstep directory (%s)."), path);

      if (system("wmaker.inst --batch") != 0) {
	  wwarning(("There was an error while creating GNUstep directory, please "
		    "make sure you have installed Window Maker correctly and run wmaker.inst"));
      } else {
	  wwarning(("%s directory created with default configuration."), path);
      }
#endif
  }

  wfree(path);
}


static void
execInitScript()
{
  char *file, *paths;

  paths = wstrconcat(wusergnusteppath(), "/Library/WindowMaker");
  paths = wstrappend(paths, ":"DEF_CONFIG_PATHS);

  file = wfindfile(paths, DEF_INIT_SCRIPT);
  wfree(paths);

  if (file) {
      if (system(file) != 0) {
	  wsyserror(("%s:could not execute initialization script"), file);
      }
      wfree(file);
  }
}

void
ExecExitScript()
{
    char *file, *paths;

    paths = wstrconcat(wusergnusteppath(), "/Library/WindowMaker");
    paths = wstrappend(paths, ":"DEF_CONFIG_PATHS);

    file = wfindfile(paths, DEF_EXIT_SCRIPT);
    wfree(paths);

    if (file) {
        if (system(file) != 0) {
            wsyserror(("%s:could not execute exit script"), file);
        }
        wfree(file);
    }
}

//----------------------------------------------------------------------------
// WindowMaker init and exit
//----------------------------------------------------------------------------
Display *
WindowMaker_main(int argc, char **argv)
{
  int  i;
  int  restart=0;
  char *str;
  int  d, s;
  int  flag;
#ifdef DEBUG
  Bool doSync = False;
#endif
  int  len;

  NSLog(@"-> WindowMaker: initializing...");

  setlocale(LC_ALL, "");

//  wsetabort(wAbort);

  /* setup common stuff for the monitor and wmaker itself */
  WMInitializeApplication("WindowMaker", &argc, argv);
  DisplayName = XDisplayName(DisplayName);
  len = strlen(DisplayName)+64;
  str = wmalloc(len);
  snprintf(str, len, "DISPLAY=%s", DisplayName);
  putenv(str);

  // for telling WPrefs what's the name of the wmaker binary being ran
  str = wstrconcat("WMAKER_BIN_NAME=", argv[0]);
  putenv(str);

  flag= 0;
  ArgCount = argc;
  Arguments = wmalloc(sizeof(char*)*(ArgCount+1));
  for (i= 0; i < argc; i++)
    {
      Arguments[i]= argv[i];
    }

  ProgName = strrchr(argv[0],'/');
  if (!ProgName)
    ProgName = argv[0];
  else
    ProgName++;

//  restart = 0;

  // 1 for "-nocpp" || "--no-cpp"
  // disable preprocessing of configuration files
  wPreferences.flags.nocpp = 0; 
  // '0' = '--for-real' & '1' = '--for-real=' & '2' '--for-real-'
  wPreferences.flags.restarting = 0; 
  // 1 for -no-autolaunch, --no-autolaunch
  // do not autolaunch applications
  wPreferences.flags.noautolaunch = 0;
  // 1 for "-dont-restore" || "--dont-restore"
  // do not restore saved session
  wPreferences.flags.norestore = 1;
  // 1 for "-nodock" || "--no-dock"
  // do not open the application Dock
  wPreferences.flags.nodock = 0;
  // 1 for "-noclip" || "--no-clip"
  // do not open the workspace Clip
  wPreferences.flags.noclip = 1;
  // 1 for "-static" || "--static"
  // do not periodically check for configuration updates
  wPreferences.flags.noupdates = 0;
  // "-locale" || "--locale"
  // locale to use
  // Locale = argv[i];
  // 1 for "-nopolling" || "--no-polling"
  wPreferences.flags.nopolling = 0;
  // do not update or save configurations

  NSLog(@"-> WindowMaker: version %s", VERSION);
  NSLog(@"-> WindowMaker: global defaults path %s", SYSCONFDIR);

#ifdef DEBUG
  // True for "--synchronous"
  doSync = True;
#endif

  if (!wPreferences.flags.noupdates) {
    /* check existence of Defaults DB directory */
    check_defaults();
  }


  if (Locale) {
    /* return of wstrconcat should not be free-ed! read putenv man page */
    putenv(wstrconcat("LANG=", Locale));
  } else {
    Locale = getenv("LC_ALL");
    if (!Locale) {
      Locale = getenv("LANG");
    }
  }
  NSLog (@"-> WindowMaker: Locale = %s", Locale);

  setlocale(LC_ALL, "");

  if (!Locale || strcmp(Locale, "C")==0 || strcmp(Locale, "POSIX")==0)
    Locale = NULL;
#ifdef I18N
  if (getenv("NLSPATH"))
    bindtextdomain("WindowMaker", getenv("NLSPATH"));
  else
    bindtextdomain("WindowMaker", LOCALEDIR);
  bind_textdomain_codeset("WindowMaker", "UTF-8");
  textdomain("WindowMaker");

  if (!XSupportsLocale()) {
    wwarning(("X server does not support locale"));
  }

  if (XSetLocaleModifiers("") == NULL) {
    wwarning(("cannot set locale modifiers"));
  }
#endif

  if (Locale) {
    char *ptr;

    Locale = wstrdup(Locale);
    ptr = strchr(Locale, '.');
    if (ptr)
      *ptr = 0;
  }

  /* open display */
  dpy = XOpenDisplay(DisplayName);
  if (dpy == NULL) {
    wfatal(("could not open display \"%s\""), XDisplayName(DisplayName));
    exit(1);
  }

  if (fcntl(ConnectionNumber(dpy), F_SETFD, FD_CLOEXEC) < 0) {
    wsyserror("error setting close-on-exec flag for X connection");
    exit(1);
  }

  /* check if the user specified a complete display name (with screen).
   * If so, only manage the specified screen */
  if (DisplayName)
    str = strchr(DisplayName, ':');
  else
    str = NULL;

  if (str && sscanf(str, ":%i.%i", &d, &s)==2)
    multiHead = False;

  DisplayName = XDisplayName(DisplayName);
  {
    int len = strlen(DisplayName)+64;
    str = wmalloc(len);
    snprintf(str, len, "DISPLAY=%s", DisplayName);
  }
  putenv(str);

#ifdef DEBUG
  if (doSync)
    XSynchronize(dpy, True);
#endif

  wXModifierInitialize();

#ifdef XSMP_ENABLED
  wSessionConnectManager(argv, argc);
#endif

  StartUp(!multiHead);

  if (wScreenCount == 1)
    multiHead = False;

  execInitScript();

//-->STOIAN
  // EventLoop() called by Workspace

  return dpy;
}


static void wipeDesktop(WScreen *scr);


/*
 *----------------------------------------------------------------------
 * Shutdown-
 * 	Exits the window manager cleanly. If mode is WSLogoutMode,
 * the whole X session will be closed, by killing all clients if
 * no session manager is running or by asking a shutdown to
 * it if its present.
 *
 *----------------------------------------------------------------------
 */
void
Shutdown(WShutdownMode mode)
{
    int i;

    NSLog(@"-> WindowMaker: exiting...");

    switch (mode) {
      case WSLogoutMode:
#ifdef XSMP_ENABLED
	wSessionRequestShutdown();
#else
	for (i = 0; i < wScreenCount; i++)
	  {
	    WScreen *scr;

	    scr = wScreenWithNumber(i);
	    if (scr)
	      {
		wSessionSaveClients(scr);
	      }
	    wScreenSaveState(scr);
	  }
#endif
	break;

      case WSKillMode:
      case WSExitMode:
	for (i = 0; i < wScreenCount; i++) {
	    WScreen *scr;

	    scr = wScreenWithNumber(i);
	    if (scr) {
		if (scr->helper_pid)
		  kill(scr->helper_pid, SIGKILL);

		/* if the session is not being managed, save restart info */
#ifdef XSMP_ENABLED
		if (!wSessionIsManaged())
#endif
		  wSessionSaveClients(scr);

		wScreenSaveState(scr);

		if (mode == WSKillMode)
		  wipeDesktop(scr);
		else
		  RestoreDesktop(scr);
	    }
	}
	ExecExitScript();
	break;

      case WSRestartPreparationMode:
	for (i=0; i<wScreenCount; i++) {
	    WScreen *scr;

	    scr = wScreenWithNumber(i);
	    if (scr) {
		if (scr->helper_pid)
		  kill(scr->helper_pid, SIGKILL);
		wScreenSaveState(scr);
		RestoreDesktop(scr);
	    }
	}
	break;
    }
}


static void
restoreWindows(WMBag *bag, WMBagIterator iter)
{
  WCoreWindow *next;
  WCoreWindow *core;
  WWindow *wwin;


  if (iter == NULL) {
      core = WMBagFirst(bag, &iter);
  } else {
      core = WMBagNext(bag, &iter);
  }

  if (core == NULL)
    return;

  restoreWindows(bag, iter);

  /* go to the end of the list */
  while (core->stacking->under)
    core = core->stacking->under;

  while (core) {
      next = core->stacking->above;

      if (core->descriptor.parent_type==WCLASS_WINDOW) {
	  Window window;

	  wwin = core->descriptor.parent;
	  window = wwin->client_win;
	  wUnmanageWindow(wwin, !wwin->flags.internal_window, False);
	  XMapWindow(dpy, window);
      }
      core = next;
  }
}


/*
 *----------------------------------------------------------------------
 * RestoreDesktop--
 * 	Puts the desktop in a usable state when exiting.
 *
 * Side effects:
 * 	All frame windows are removed and windows are reparented
 * back to root. Windows that are outside the screen are
 * brought to a viable place.
 *
 *----------------------------------------------------------------------
 */
void
RestoreDesktop(WScreen *scr)
{
    if (scr->helper_pid > 0) {
        kill(scr->helper_pid, SIGTERM);
        scr->helper_pid = 0;
    }

    XGrabServer(dpy);
    wDestroyInspectorPanels();

    /* reparent windows back to the root window, keeping the stacking order */
    restoreWindows(scr->stacking_list, NULL);

    XUngrabServer(dpy);
    XSetInputFocus(dpy, PointerRoot, RevertToParent, CurrentTime);
    wColormapInstallForWindow(scr, NULL);
    PropCleanUp(scr->root_win);
    wNETWMCleanup(scr);
    XSync(dpy, 0);
}


/*
 *----------------------------------------------------------------------
 * wipeDesktop--
 * 	Kills all windows in a screen. Send DeleteWindow to all windows
 * that support it and KillClient on all windows that don't.
 *
 * Side effects:
 * 	All managed windows are closed.
 *
 * TODO: change to XQueryTree()
 *----------------------------------------------------------------------
 */
static void
wipeDesktop(WScreen *scr)
{
    WWindow *wwin;

    wwin = scr->focused_window;
    while (wwin) {
        if (wwin->protocols.DELETE_WINDOW)
            wClientSendProtocol(wwin, _XA_WM_DELETE_WINDOW, LastTimestamp);
        else
            wClientKill(wwin);
        wwin = wwin->prev;
    }
    XSync(dpy, False);
}
