/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
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
#include <errno.h>
#include <signal.h>
#include <sys/wait.h>
#ifdef __FreeBSD__
#include <sys/signal.h>
#endif

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/cursorfont.h>
#include <X11/Xproto.h>
#include <X11/keysym.h>

#include <X11/Xresource.h>

#ifdef SHAPE
#include <X11/extensions/shape.h>
#endif

#include "WindowMaker.h"
#include "GNUstep.h"
#include "texture.h"
#include "screen.h"
#include "window.h"
#include "actions.h"
#include "client.h"
#include "funcs.h"
#include "dock.h"
#include "workspace.h"
#include "keybind.h"
#include "framewin.h"
#include "session.h"
#include "defaults.h"
#include "properties.h"
#include "dialog.h"
#include "wmspec.h"
#ifdef XDND
#include "xdnd.h"
#endif

#include "xutil.h"

#if 0
#ifdef SYS_SIGLIST_DECLARED
extern const char * const sys_siglist[];
#endif
#endif

/* for SunOS */
#ifndef SA_RESTART
# define SA_RESTART 0
#endif

/* Just in case, for weirdo systems */
#ifndef SA_NODEFER
# define SA_NODEFER 0
#endif

/****** Global Variables ******/

extern WPreferences wPreferences;

extern WDDomain *WDWindowMaker;
extern WDDomain *WDRootMenu;
extern WDDomain *WDWindowAttributes;

extern WShortKey wKeyBindings[WKBD_LAST];

extern int wScreenCount;


#ifdef SHAPE
extern Bool wShapeSupported;
extern int wShapeEventBase;
#endif

/* contexts */
extern XContext wWinContext;
extern XContext wAppWinContext;
extern XContext wStackContext;
extern XContext wVEdgeContext;

/* atoms */
extern Atom _XA_WM_STATE;
extern Atom _XA_WM_CHANGE_STATE;
extern Atom _XA_WM_PROTOCOLS;
extern Atom _XA_WM_TAKE_FOCUS;
extern Atom _XA_WM_DELETE_WINDOW;
extern Atom _XA_WM_SAVE_YOURSELF;
extern Atom _XA_WM_CLIENT_LEADER;
extern Atom _XA_WM_COLORMAP_WINDOWS;
extern Atom _XA_WM_COLORMAP_NOTIFY;

extern Atom _XA_GNUSTEP_WM_ATTR;

extern Atom _XA_WINDOWMAKER_MENU;
extern Atom _XA_WINDOWMAKER_WM_PROTOCOLS;
extern Atom _XA_WINDOWMAKER_STATE;
extern Atom _XA_WINDOWMAKER_WM_FUNCTION;
extern Atom _XA_WINDOWMAKER_NOTICEBOARD;
extern Atom _XA_WINDOWMAKER_COMMAND;
extern Atom _XA_WINDOWMAKER_ICON_SIZE;
extern Atom _XA_WINDOWMAKER_ICON_TILE;

extern Atom _XA_GNUSTEP_WM_MINIATURIZE_WINDOW;
extern Atom _XA_GNUSTEP_TITLEBAR_STATE;


/* cursors */
extern Cursor wCursor[WCUR_LAST];

/* special flags */
extern char WDelayedActionSet;

/***** Local *****/

static WScreen **wScreen = NULL;


static unsigned int _NumLockMask = 0;
static unsigned int _ScrollLockMask = 0;



static void manageAllWindows(WScreen *scr, int crashed);

extern void NotifyDeadProcess(pid_t pid, unsigned char status);


static int
catchXError(Display *dpy, XErrorEvent *error)
{
    char buffer[MAXLINE];

    /* ignore some errors */
    if (error->resourceid != None
        && ((error->error_code == BadDrawable
             && error->request_code == X_GetGeometry)
            || (error->error_code == BadMatch
                && (error->request_code == X_SetInputFocus))
            || (error->error_code == BadWindow)
            /*
             && (error->request_code == X_GetWindowAttributes
             || error->request_code == X_SetInputFocus
             || error->request_code == X_ChangeWindowAttributes
             || error->request_code == X_GetProperty
             || error->request_code == X_ChangeProperty
             || error->request_code == X_QueryTree
             || error->request_code == X_GrabButton
             || error->request_code == X_UngrabButton
             || error->request_code == X_SendEvent
             || error->request_code == X_ConfigureWindow))
             */
            || (error->request_code == X_InstallColormap))) {
#ifndef DEBUG

        return 0;
#else
        printf("got X error %x %x %x\n", error->request_code,
               error->error_code, (unsigned)error->resourceid);
        return 0;
#endif
    }
    FormatXError(dpy, error, buffer, MAXLINE);
    wwarning(_("internal X error: %s\n"), buffer);
    return -1;
}


/*
 *----------------------------------------------------------------------
 * handleXIO-
 * 	Handle X shutdowns and other stuff.
 *----------------------------------------------------------------------
 */
static int
handleXIO(Display *xio_dpy)
{
    dpy = NULL;
    Exit(0);
    return 0;
}


/*
 *----------------------------------------------------------------------
 * delayedAction-
 * 	Action to be executed after the signal() handler is exited.
 *----------------------------------------------------------------------
 */
static void
delayedAction(void *cdata)
{
    if (WDelayedActionSet == 0) {
        return;
    }
    WDelayedActionSet--;
    /*
     * Make the event dispatcher do whatever it needs to do,
     * including handling zombie processes, restart and exit
     * signals.
     */
    DispatchEvent(NULL);
}


/*
 *----------------------------------------------------------------------
 * handleExitSig--
 * 	User generated exit signal handler.
 *----------------------------------------------------------------------
 */
// Unused
#if 0
static RETSIGTYPE
handleExitSig(int sig)
{
    sigset_t sigs;

    sigfillset(&sigs);
    sigprocmask(SIG_BLOCK, &sigs, NULL);

    if (sig == SIGUSR1) {
#ifdef SYS_SIGLIST_DECLARED
        wwarning("got signal %i (%s) - restarting\n", sig, sys_siglist[sig]);
#else
        wwarning("got signal %i - restarting\n", sig);
#endif

        SIG_WCHANGE_STATE(WSTATE_NEED_RESTART);
        /* setup idle handler, so that this will be handled when
         * the select() is returned becaused of the signal, even if
         * there are no X events in the queue */
        WDelayedActionSet++;
    } else if (sig == SIGUSR2) {
#ifdef SYS_SIGLIST_DECLARED
        wwarning("got signal %i (%s) - rereading defaults\n", sig, sys_siglist[sig]);
#else
        wwarning("got signal %i - rereading defaults\n", sig);
#endif

        SIG_WCHANGE_STATE(WSTATE_NEED_REREAD);
        /* setup idle handler, so that this will be handled when
         * the select() is returned becaused of the signal, even if
         * there are no X events in the queue */
        WDelayedActionSet++;
    } else if (sig==SIGTERM || sig==SIGINT || sig==SIGHUP) {
#ifdef SYS_SIGLIST_DECLARED
        wwarning("got signal %i (%s) - exiting...\n", sig, sys_siglist[sig]);
#else
        wwarning("got signal %i - exiting...\n", sig);
#endif

        SIG_WCHANGE_STATE(WSTATE_NEED_EXIT);

        WDelayedActionSet++;
    }

    sigprocmask(SIG_UNBLOCK, &sigs, NULL);
}
#endif

/* Dummy signal handler */
static void
dummyHandler(int sig)
{
}


/*
 *----------------------------------------------------------------------
 * handleSig--
 * 	general signal handler. Exits the program gently.
 *----------------------------------------------------------------------
 */
static RETSIGTYPE
handleSig(int sig)
{
#ifdef SYS_SIGLIST_DECLARED
    wfatal("got signal %i (%s)\n", sig, sys_siglist[sig]);
#else
    wfatal("got signal %i\n", sig);
#endif

    /* Setting the signal behaviour back to default and then reraising the
     * signal is a cleaner way to make program exit and core dump than calling
     * abort(), since it correctly returns from the signal handler and sets
     * the flags accordingly. -Dan
     */
    if (sig==SIGSEGV || sig==SIGFPE || sig==SIGBUS || sig==SIGILL
        || sig==SIGABRT) {
        signal(sig, SIG_DFL);
        kill(getpid(), sig);
        return;
    }

    wAbort(0);
}


static RETSIGTYPE
buryChild(int foo)
{
    pid_t pid;
    int status;
    int save_errno = errno;
    sigset_t sigs;

    sigfillset(&sigs);
    /* Block signals so that NotifyDeadProcess() doesn't get fux0red */
    sigprocmask(SIG_BLOCK, &sigs, NULL);

    /* R.I.P. */
    /* If 2 or more kids exit in a small time window, before this handler gets
     * the chance to get invoked, the SIGCHLD signals will be merged and only
     * one SIGCHLD signal will be sent to us. We use a while loop to get all
     * exited child status because we can't count on the number of SIGCHLD
     * signals to know exactly how many kids have exited. -Dan
     */
    while ((pid=waitpid(-1, &status, WNOHANG))>0 || (pid<0 && errno==EINTR)) {
        NotifyDeadProcess(pid, WEXITSTATUS(status));
    }

    WDelayedActionSet++;

    sigprocmask(SIG_UNBLOCK, &sigs, NULL);

    errno = save_errno;
}


static void
getOffendingModifiers()
{
    int i;
    XModifierKeymap *modmap;
    KeyCode nlock, slock;
    static int mask_table[8] = {
        ShiftMask,LockMask,ControlMask,Mod1Mask,
        Mod2Mask, Mod3Mask, Mod4Mask, Mod5Mask
    };

    nlock = XKeysymToKeycode(dpy, XK_Num_Lock);
    slock = XKeysymToKeycode(dpy, XK_Scroll_Lock);

    /*
     * Find out the masks for the NumLock and ScrollLock modifiers,
     * so that we can bind the grabs for when they are enabled too.
     */
    modmap = XGetModifierMapping(dpy);

    if (modmap!=NULL && modmap->max_keypermod>0) {
        for (i=0; i<8*modmap->max_keypermod; i++) {
            if (modmap->modifiermap[i]==nlock && nlock!=0)
                _NumLockMask = mask_table[i/modmap->max_keypermod];
            else if (modmap->modifiermap[i]==slock && slock!=0)
                _ScrollLockMask = mask_table[i/modmap->max_keypermod];
        }
    }

    if (modmap)
        XFreeModifiermap(modmap);
}



#ifdef NUMLOCK_HACK
void
wHackedGrabKey(int keycode, unsigned int modifiers,
               Window grab_window, Bool owner_events, int pointer_mode,
               int keyboard_mode)
{
    if (modifiers == AnyModifier)
        return;

    /* grab all combinations of the modifier with CapsLock, NumLock and
     * ScrollLock. How much memory/CPU does such a monstrosity consume
     * in the server?
     */
    if (_NumLockMask)
        XGrabKey(dpy, keycode, modifiers|_NumLockMask,
                 grab_window, owner_events, pointer_mode, keyboard_mode);
    if (_ScrollLockMask)
        XGrabKey(dpy, keycode, modifiers|_ScrollLockMask,
                 grab_window, owner_events, pointer_mode, keyboard_mode);
    if (_NumLockMask && _ScrollLockMask)
        XGrabKey(dpy, keycode, modifiers|_NumLockMask|_ScrollLockMask,
                 grab_window, owner_events, pointer_mode, keyboard_mode);
    if (_NumLockMask)
        XGrabKey(dpy, keycode, modifiers|_NumLockMask|LockMask,
                 grab_window, owner_events, pointer_mode, keyboard_mode);
    if (_ScrollLockMask)
        XGrabKey(dpy, keycode, modifiers|_ScrollLockMask|LockMask,
                 grab_window, owner_events, pointer_mode, keyboard_mode);
    if (_NumLockMask && _ScrollLockMask)
        XGrabKey(dpy, keycode, modifiers|_NumLockMask|_ScrollLockMask|LockMask,
                 grab_window, owner_events, pointer_mode, keyboard_mode);
    /* phew, I guess that's all, right? */
}
#endif

void
wHackedGrabButton(unsigned int button, unsigned int modifiers,
                  Window grab_window, Bool owner_events,
                  unsigned int event_mask, int pointer_mode,
                  int keyboard_mode, Window confine_to, Cursor cursor)
{
    XGrabButton(dpy, button, modifiers, grab_window, owner_events,
                event_mask, pointer_mode, keyboard_mode, confine_to, cursor);

    if (modifiers==AnyModifier)
        return;

    XGrabButton(dpy, button, modifiers|LockMask, grab_window, owner_events,
                event_mask, pointer_mode, keyboard_mode, confine_to, cursor);

#ifdef NUMLOCK_HACK
    /* same as above, but for mouse buttons */
    if (_NumLockMask)
        XGrabButton(dpy, button, modifiers|_NumLockMask,
                    grab_window, owner_events, event_mask, pointer_mode,
                    keyboard_mode, confine_to, cursor);
    if (_ScrollLockMask)
        XGrabButton(dpy, button, modifiers|_ScrollLockMask,
                    grab_window, owner_events, event_mask, pointer_mode,
                    keyboard_mode, confine_to, cursor);
    if (_NumLockMask && _ScrollLockMask)
        XGrabButton(dpy, button, modifiers|_ScrollLockMask|_NumLockMask,
                    grab_window, owner_events, event_mask, pointer_mode,
                    keyboard_mode, confine_to, cursor);
    if (_NumLockMask)
        XGrabButton(dpy, button, modifiers|_NumLockMask|LockMask,
                    grab_window, owner_events, event_mask, pointer_mode,
                    keyboard_mode, confine_to, cursor);
    if (_ScrollLockMask)
        XGrabButton(dpy, button, modifiers|_ScrollLockMask|LockMask,
                    grab_window, owner_events, event_mask, pointer_mode,
                    keyboard_mode, confine_to, cursor);
    if (_NumLockMask && _ScrollLockMask)
        XGrabButton(dpy, button, modifiers|_ScrollLockMask|_NumLockMask|LockMask,
                    grab_window, owner_events, event_mask, pointer_mode,
                    keyboard_mode, confine_to, cursor);
#endif /* NUMLOCK_HACK */
}

#ifdef notused
void
wHackedUngrabButton(unsigned int button, unsigned int modifiers,
                    Window grab_window)
{
    XUngrabButton(dpy, button, modifiers|_NumLockMask,
                  grab_window);
    XUngrabButton(dpy, button, modifiers|_ScrollLockMask,
                  grab_window);
    XUngrabButton(dpy, button, modifiers|_NumLockMask|_ScrollLockMask,
                  grab_window);
    XUngrabButton(dpy, button, modifiers|_NumLockMask|LockMask,
                  grab_window);
    XUngrabButton(dpy, button, modifiers|_ScrollLockMask|LockMask,
                  grab_window);
    XUngrabButton(dpy, button, modifiers|_NumLockMask|_ScrollLockMask|LockMask,
                  grab_window);
}
#endif



WScreen*
wScreenWithNumber(int i)
{
    assert(i < wScreenCount);

    return wScreen[i];
}


WScreen*
wScreenForRootWindow(Window window)
{
    int i;

    if (wScreenCount==1)
        return wScreen[0];

    /*
     * Since the number of heads will probably be small (normally 2),
     * it should be faster to use this than a hash table, because
     * of the overhead.
     */
    for (i=0; i<wScreenCount; i++) {
        if (wScreen[i]->root_win == window) {
            return wScreen[i];
        }
    }

    return wScreenForWindow(window);
}


WScreen*
wScreenSearchForRootWindow(Window window)
{
    int i;

    if (wScreenCount==1)
        return wScreen[0];

    /*
     * Since the number of heads will probably be small (normally 2),
     * it should be faster to use this than a hash table, because
     * of the overhead.
     */
    for (i=0; i<wScreenCount; i++) {
        if (wScreen[i]->root_win == window) {
            return wScreen[i];
        }
    }

    return wScreenForWindow(window);
}


WScreen*
wScreenForWindow(Window window)
{
    XWindowAttributes attr;

    if (wScreenCount==1)
        return wScreen[0];

    if (XGetWindowAttributes(dpy, window, &attr)) {
        return wScreenForRootWindow(attr.root);
    }
    return NULL;
}


static char *atomNames[] = {
    "WM_STATE",
    "WM_CHANGE_STATE",
    "WM_PROTOCOLS",
    "WM_TAKE_FOCUS",
    "WM_DELETE_WINDOW",
    "WM_SAVE_YOURSELF",
    "WM_CLIENT_LEADER",
    "WM_COLORMAP_WINDOWS",
    "WM_COLORMAP_NOTIFY",

    "_WINDOWMAKER_MENU",
    "_WINDOWMAKER_STATE",
    "_WINDOWMAKER_WM_PROTOCOLS",
    "_WINDOWMAKER_WM_FUNCTION",
    "_WINDOWMAKER_NOTICEBOARD",
    "_WINDOWMAKER_COMMAND",
    "_WINDOWMAKER_ICON_SIZE",
    "_WINDOWMAKER_ICON_TILE",

    GNUSTEP_WM_ATTR_NAME,
    GNUSTEP_WM_MINIATURIZE_WINDOW,
    GNUSTEP_TITLEBAR_STATE
};


/*
 *----------------------------------------------------------
 * StartUp--
 * 	starts the window manager and setup global data.
 * Called from main() at startup.
 *
 * Side effects:
 * global data declared in main.c is initialized
 *----------------------------------------------------------
 */
void
StartUp(Bool defaultScreenOnly)
{
//  struct sigaction sig_action; // Moved to SetupSignalHandling
  int j, max;
  Atom atom[sizeof(atomNames)/sizeof(char*)];

  /*
   * Ignore CapsLock in modifiers
   */
  ValidModMask = 0xff & ~LockMask;

  getOffendingModifiers();
  /*
   * Ignore NumLock and ScrollLock too
   */
  ValidModMask &= ~(_NumLockMask|_ScrollLockMask);


  memset(&wKeyBindings, 0, sizeof(wKeyBindings));

  wWinContext = XUniqueContext();
  wAppWinContext = XUniqueContext();
  wStackContext = XUniqueContext();
  wVEdgeContext = XUniqueContext();

  /*    _XA_VERSION = XInternAtom(dpy, "VERSION", False);*/

#ifdef HAVE_XINTERNATOMS
  XInternAtoms(dpy, atomNames, sizeof(atomNames)/sizeof(char*),
	       False, atom);
#else

    {
      int i;
      for (i = 0; i < sizeof(atomNames)/sizeof(char*); i++) {
	  atom[i] = XInternAtom(dpy, atomNames[i], False);
      }
    }
#endif

  _XA_WM_STATE = atom[0];
  _XA_WM_CHANGE_STATE = atom[1];
  _XA_WM_PROTOCOLS = atom[2];
  _XA_WM_TAKE_FOCUS = atom[3];
  _XA_WM_DELETE_WINDOW = atom[4];
  _XA_WM_SAVE_YOURSELF = atom[5];
  _XA_WM_CLIENT_LEADER = atom[6];
  _XA_WM_COLORMAP_WINDOWS = atom[7];
  _XA_WM_COLORMAP_NOTIFY = atom[8];

  _XA_WINDOWMAKER_MENU = atom[9];
  _XA_WINDOWMAKER_STATE = atom[10];
  _XA_WINDOWMAKER_WM_PROTOCOLS = atom[11];
  _XA_WINDOWMAKER_WM_FUNCTION = atom[12];
  _XA_WINDOWMAKER_NOTICEBOARD = atom[13];
  _XA_WINDOWMAKER_COMMAND = atom[14];
  _XA_WINDOWMAKER_ICON_SIZE = atom[15];
  _XA_WINDOWMAKER_ICON_TILE = atom[16];

  _XA_GNUSTEP_WM_ATTR = atom[17];
  _XA_GNUSTEP_WM_MINIATURIZE_WINDOW = atom[18];
  _XA_GNUSTEP_TITLEBAR_STATE = atom[19];

#ifdef XDND
  wXDNDInitializeAtoms();
#endif


  /* cursors */
  wCursor[WCUR_NORMAL] = None; /* inherit from root */
  wCursor[WCUR_ROOT] = XCreateFontCursor(dpy, XC_left_ptr);
  wCursor[WCUR_ARROW] = XCreateFontCursor(dpy, XC_top_left_arrow);
  wCursor[WCUR_MOVE] = XCreateFontCursor(dpy, XC_fleur);
  wCursor[WCUR_RESIZE] = XCreateFontCursor(dpy, XC_sizing);
  wCursor[WCUR_TOPLEFTRESIZE] = XCreateFontCursor(dpy, XC_top_left_corner);
  wCursor[WCUR_TOPRIGHTRESIZE] = XCreateFontCursor(dpy, XC_top_right_corner);
  wCursor[WCUR_BOTTOMLEFTRESIZE] = XCreateFontCursor(dpy, XC_bottom_left_corner);
  wCursor[WCUR_BOTTOMRIGHTRESIZE] = XCreateFontCursor(dpy, XC_bottom_right_corner);
  wCursor[WCUR_VERTICALRESIZE] = XCreateFontCursor(dpy, XC_sb_v_double_arrow);
  wCursor[WCUR_HORIZONRESIZE] = XCreateFontCursor(dpy, XC_sb_h_double_arrow);
  wCursor[WCUR_WAIT] = XCreateFontCursor(dpy, XC_watch);
  wCursor[WCUR_QUESTION] = XCreateFontCursor(dpy, XC_question_arrow);
  wCursor[WCUR_TEXT]     = XCreateFontCursor(dpy, XC_xterm); /* odd name???*/
  wCursor[WCUR_SELECT] = XCreateFontCursor(dpy, XC_cross);
    {
      Pixmap cur = XCreatePixmap(dpy, DefaultRootWindow(dpy), 16, 16, 1);
      GC gc = XCreateGC(dpy, cur, 0, NULL);
      XColor black;
      memset(&black, 0, sizeof(XColor));
      XSetForeground(dpy, gc, 0);
      XFillRectangle(dpy, cur, gc, 0, 0, 16, 16);
      XFreeGC(dpy, gc);
      wCursor[WCUR_EMPTY] = XCreatePixmapCursor(dpy, cur, cur, &black, &black, 0, 0);
      XFreePixmap(dpy, cur);
    }

  //-->STOIAN: Signal handling stuff goes to SetupSignalHandling()
  // Called from Workspace's [Controller -applicationDidFinishLaunching:]

  /* handle X shutdowns a such */
  XSetIOErrorHandler(handleXIO);

  /* set hook for out event dispatcher in WINGs event dispatcher */
  WMHookEventHandler(DispatchEvent);

  /* initialize defaults stuff */
  WDWindowMaker = wDefaultsInitDomain("WindowMaker", True);
  if (!WDWindowMaker->dictionary)
    {
      wwarning(_("could not read domain \"%s\" from defaults database"),
	       "WindowMaker");
    }

  /* read defaults that don't change until a restart and are
   * screen independent */
  wReadStaticDefaults(WDWindowMaker ? WDWindowMaker->dictionary : NULL);

  /* check sanity of some values */
  if (wPreferences.icon_size < 16)
    {
      wwarning(_("icon size is configured to %i, but it's too small. Using 16, instead\n"),
	       wPreferences.icon_size);
      wPreferences.icon_size = 16;
    }

  /* init other domains */
  WDRootMenu = wDefaultsInitDomain("WMRootMenu", False);
  if (!WDRootMenu->dictionary)
    {
      wwarning(_("could not read domain \"%s\" from defaults database"),
	       "WMRootMenu");
    }
  wDefaultsMergeGlobalMenus(WDRootMenu);

  WDWindowAttributes = wDefaultsInitDomain("WMWindowAttributes", True);
  if (!WDWindowAttributes->dictionary)
    {
      wwarning(_("could not read domain \"%s\" from defaults database"),
	       "WMWindowAttributes");
    }

  XSetErrorHandler((XErrorHandler)catchXError);

#ifdef SHAPE
  /* ignore j */
  wShapeSupported = XShapeQueryExtension(dpy, &wShapeEventBase, &j);
#endif

  if (defaultScreenOnly)
    {
      max = 1;
    }
  else
    {
      max = ScreenCount(dpy);
    }
  wScreen = wmalloc(sizeof(WScreen*)*max);

  wScreenCount = 0;

  /* manage the screens */
  for (j = 0; j < max; j++)
    {
      if (defaultScreenOnly || max==1)
	{
	  wScreen[wScreenCount] = wScreenInit(DefaultScreen(dpy));
	  if (!wScreen[wScreenCount])
	    {
	      wfatal(_("it seems that there is already a window manager running"));
	      Exit(1);
	    }
	} 
      else
	{
	  wScreen[wScreenCount] = wScreenInit(j);
	  if (!wScreen[wScreenCount])
	    {
	      wwarning(_("could not manage screen %i"), j);
	      continue;
	    }
	}
      wScreenCount++;
    }

#ifndef LITE
  InitializeSwitchMenu();
#endif

  // initialize/restore state for the screens
  for (j = 0; j < wScreenCount; j++)
    {
      int lastDesktop;

      lastDesktop= wNETWMGetCurrentDesktopFromHint(wScreen[j]);

      wScreenRestoreState(wScreen[j]);

      // manage all windows that were already here before us
      if (!wPreferences.flags.nodock && wScreen[j]->dock)
	wScreen[j]->last_dock = wScreen[j]->dock;

      manageAllWindows(wScreen[j], wPreferences.flags.restarting==2);

      // restore saved menus
      wMenuRestoreState(wScreen[j]);

      // If we're not restarting, restore session
      if (wPreferences.flags.restarting==0 && !wPreferences.flags.norestore)
	wSessionRestoreState(wScreen[j]);

      //-->STOIAN: Automatic launching of docked apps moved into AutolaunchDockApps()
      // Called from Workspace_main.m

      // go to workspace where we were before restart
      if (lastDesktop >= 0)
	{
	  wWorkspaceForceChange(wScreen[j], lastDesktop);
	}
      else
	{
	  wSessionRestoreLastWorkspace(wScreen[j]);
	}
    }

  if (wScreenCount == 0)
    {
      wfatal(_("could not manage any screen"));
      Exit(1);
    }

  if (!wPreferences.flags.nopolling && !wPreferences.flags.noupdates)
    {
      /* setup defaults file polling */
      WMAddTimerHandler(3000, wDefaultsCheckDomains, NULL);
    }
}

//----------------------------------------------------------------------------
// Functions moved from StartUp. Called from Workspace.
//----------------------------------------------------------------------------

//-->STOIAN
void
AutolaunchDockApps(void)
{
  int j;

  for (j = 0; j < wScreenCount; j++)
    {
      if (!wPreferences.flags.noautolaunch)
	{
	  // auto-launch apps
	  if (!wPreferences.flags.nodock && wScreen[j]->dock)
	    {
	      wScreen[j]->last_dock = wScreen[j]->dock;
	      wDockDoAutoLaunch(wScreen[j]->dock, 0);
	    }
	  // auto-launch apps in clip
	  if (!wPreferences.flags.noclip)
	    {
	      int i;
	      for(i=0; i<wScreen[j]->workspace_count; i++)
		{
		  if (wScreen[j]->workspaces[i]->clip)
		    {
		      wScreen[j]->last_dock = wScreen[j]->workspaces[i]->clip;
		      wDockDoAutoLaunch(wScreen[j]->workspaces[i]->clip, i);
		    }
		}
	    }
	}
    }
}

//-->STOIAN
void
SetupSignalHandling(void)
{
  struct sigaction sig_action;

  /* signal handler stuff that gets called when a signal is caught */
  WMAddPersistentTimerHandler(500, delayedAction, NULL);

  /* emergency exit... */
  sig_action.sa_handler = handleSig;
  sigemptyset(&sig_action.sa_mask);

  sig_action.sa_flags = SA_RESTART;
  sigaction(SIGQUIT, &sig_action, NULL);
  /* instead of catching these, we let the default handler abort the
   * program. The new monitor process will take appropriate action
   * when it detects the crash.
   sigaction(SIGSEGV, &sig_action, NULL);
   sigaction(SIGBUS, &sig_action, NULL);
   sigaction(SIGFPE, &sig_action, NULL);
   sigaction(SIGABRT, &sig_action, NULL);
   */

/*  sig_action.sa_handler = handleExitSig;*/

  /* Here we set SA_RESTART for safety, because SIGUSR1 may not be handled
   * immediately. -Dan */
  // These signals should handle GNUstep part (Workspace)
/*  sig_action.sa_flags = SA_RESTART;
  sigaction(SIGTERM, &sig_action, NULL);
  sigaction(SIGINT, &sig_action, NULL);
  sigaction(SIGHUP, &sig_action, NULL);
  sigaction(SIGUSR1, &sig_action, NULL);
  sigaction(SIGUSR2, &sig_action, NULL);*/

  /* ignore dead pipe */
  /* Because POSIX mandates that only signal with handlers are reset
   * accross an exec*(), we do not want to propagate ignoring SIGPIPEs
   * to children. Hence the dummy handler.
   * Philippe Troin <phil@fifi.org>
   */
  sig_action.sa_handler = &dummyHandler;
  sig_action.sa_flags = SA_RESTART;
  sigaction(SIGPIPE, &sig_action, NULL);

  /* handle dead children */
  sig_action.sa_handler = buryChild;
  sig_action.sa_flags = SA_NOCLDSTOP|SA_RESTART;
  sigaction(SIGCHLD, &sig_action, NULL);

  /* Now we unblock all signals, that may have been blocked by the parent
   * who exec()-ed us. This can happen for example if Window Maker crashes
   * and restarts itself or another window manager from the signal handler.
   * In this case, the new proccess inherits the blocked signal mask and
   * will no longer react to that signal, until unblocked.
   * This is because the signal handler of the proccess who crashed (parent)
   * didn't return, and the signal remained blocked. -Dan
   */
  sigfillset(&sig_action.sa_mask);
  sigprocmask(SIG_UNBLOCK, &sig_action.sa_mask, NULL);
}

//-->STOIAN
void
SetupNoFocusWindow(Window window)
{
  WScreen      *scr = wScreen[0];
  WApplication *wapp = wApplicationOf(window);

  if (wapp == NULL)
    fprintf(stderr, "->WindowMaker: no application for no-focus-window\n");

  scr->no_focus_win = window;
}

//----------------------------------------------------------------------------

static Bool
windowInList(Window window, Window *list, int count)
{
    for (; count>=0; count--) {
        if (window == list[count])
            return True;
    }
    return False;
}

/*
 *-----------------------------------------------------------------------
 * manageAllWindows--
 * 	Manages all windows in the screen.
 *
 * Notes:
 * 	Called when the wm is being started.
 *	No events can be processed while the windows are being
 * reparented/managed.
 *-----------------------------------------------------------------------
 */
static void
manageAllWindows(WScreen *scr, int crashRecovery)
{
    Window root, parent;
    Window *children;
    unsigned int nchildren;
    unsigned int i, j;
    WWindow *wwin;

    XGrabServer(dpy);
    XQueryTree(dpy, scr->root_win, &root, &parent, &children, &nchildren);

    scr->flags.startup = 1;

    /* first remove all icon windows */
    for (i = 0; i < nchildren; i++) {
        XWMHints *wmhints;

        if (children[i]==None)
            continue;

        wmhints = XGetWMHints(dpy, children[i]);
        if (wmhints && (wmhints->flags & IconWindowHint)) {
            for (j = 0; j < nchildren; j++)  {
                if (children[j] == wmhints->icon_window) {
                    XFree(wmhints);
                    wmhints = NULL;
                    children[j] = None;
                    break;
                }
            }
        }
        if (wmhints) {
            XFree(wmhints);
        }
    }


    for (i = 0; i < nchildren; i++) {
        if (children[i] == None)
            continue;

        wwin = wManageWindow(scr, children[i]);
        if (wwin) {
            /* apply states got from WSavedState */
            /* shaded + minimized is not restored correctly */
            if (wwin->flags.shaded) {
                wwin->flags.shaded = 0;
                wShadeWindow(wwin);
            }
            if (wwin->flags.miniaturized
                && (wwin->transient_for == None
                    || wwin->transient_for == scr->root_win
                    || !windowInList(wwin->transient_for, children,
                                     nchildren))) {

                wwin->flags.skip_next_animation = 1;
                wwin->flags.miniaturized = 0;
                wIconifyWindow(wwin);
            } else {
                wClientSetState(wwin, NormalState, None);
            }
            if (crashRecovery) {
                int border;

                border = (!HAS_BORDER(wwin) ? 0 : FRAME_BORDER_WIDTH);

                wWindowMove(wwin, wwin->frame_x - border,
                            wwin->frame_y - border -
                            (wwin->frame->titlebar ?
                             wwin->frame->titlebar->height : 0));
            }
        }
    }
    XUngrabServer(dpy);

    /* hide apps */
    wwin = scr->focused_window;
    while (wwin) {
        if (wwin->flags.hidden) {
            WApplication *wapp = wApplicationOf(wwin->main_window);

            if (wapp) {
                wwin->flags.hidden = 0;
                wHideApplication(wapp);
            } else {
                wwin->flags.hidden = 0;
            }
        }
        wwin = wwin->prev;
    }

    XFree(children);
    scr->flags.startup = 0;
    scr->flags.startup2 = 1;

    while (XPending(dpy)) {
        XEvent ev;
        WMNextEvent(dpy, &ev);
        WMHandleEvent(&ev);
    }
    wWorkspaceForceChange(scr, 0);
    if (!wPreferences.flags.noclip)
        wDockShowIcons(scr->workspaces[scr->current_workspace]->clip);
    scr->flags.startup2 = 0;
}

