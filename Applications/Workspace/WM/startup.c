/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "WM.h"

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
#include <X11/Xresource.h>
#include <X11/Xutil.h>
#include <X11/cursorfont.h>
#include <X11/Xproto.h>
#include <X11/keysym.h>
#ifdef USE_XSHAPE
#include <X11/extensions/shape.h>
#endif
#ifdef USE_XKB
#include <X11/XKBlib.h>
#endif

#include <core/WMcore.h>
#include <core/util.h>
#include <core/log_utils.h>
#include <core/wuserdefaults.h>
#include <core/wevent.h>
#include <core/string_utils.h>

#include "WM.h"
#include "GNUstep.h"
#include "texture.h"
#include "screen.h"
#include "window.h"
#include "actions.h"
#include "client.h"
#include "startup.h"
#include "dock.h"
#include "desktop.h"
#include "framewin.h"
#include "session.h"
#include "defaults.h"
#include "properties.h"
#include "wmspec.h"
#include "event.h"
#include "switchmenu.h"
#ifdef USE_DOCK_XDND
#include "xdnd.h"
#endif
#include "xutil.h"
#include "window_attributes.h"
#include "misc.h"
#include "xmodifier.h"
#include "dock.h"
#include "application.h"
#include "wmcomposer.h"

/****** Global ******/
Display *dpy;
struct wm_global_variables w_global;

/* CoreFoundation notifications */
CFStringRef WMDidCreateApplicationNotification = CFSTR("WMDidCreateApplicationNotification");
CFStringRef WMDidDestroyApplicationNotification = CFSTR("WMDidDestroyApplicationNotification");
CFStringRef WMDidActivateApplicationNotification = CFSTR("WMDidActivateApplicationNotification");
CFStringRef WMDidDeactivateApplicationNotification = CFSTR("WMDidDeactivateApplicationNotification");

CFStringRef WMDidManageWindowNotification = CFSTR("WMDidManageWindowNotification");
CFStringRef WMDidUnmanageWindowNotification = CFSTR("WMDidUnmanageWindowNotification");
CFStringRef WMDidChangeWindowDesktopNotification = CFSTR("WMDidChangeWindowDesktopNotification");
CFStringRef WMDidChangeWindowStateNotification = CFSTR("WMDidChangeWindowStateNotification");
CFStringRef WMDidChangeWindowFocusNotification = CFSTR("WMDidChangeWindowFocusNotification");
CFStringRef WMDidChangeWindowStackingNotification = CFSTR("WMDidChangeWindowStackingNotification");
CFStringRef WMDidChangeWindowNameNotification = CFSTR("WMDidChangeWindowNameNotification");

CFStringRef WMDidResetWindowStackingNotification = CFSTR("WMDidResetWindowStackingNotification");

CFStringRef WMDidCreateDesktopNotification = CFSTR("WMDidCreateDesktopNotification");
CFStringRef WMDidDestroyDesktopNotification = CFSTR("WMDidDestroyDesktopNotification");
CFStringRef WMDidChangeDesktopNotification = CFSTR("WMDidChangeDesktopNotification");
CFStringRef WMDidChangeDesktopNameNotification = CFSTR("WMDidChangeDesktopNameNotification");

CFStringRef WMDidChangeWindowAppearanceSettings = CFSTR("WMDidChangeWindowAppearanceSettings");
CFStringRef WMDidChangeIconAppearanceSettings = CFSTR("WMDidChangeIconAppearanceSettings");
CFStringRef WMDidChangeIconTileSettings = CFSTR("WMDidChangeIconTileSettings");
CFStringRef WMDidChangeMenuAppearanceSettings = CFSTR("WMDidChangeMenuAppearanceSettings");
CFStringRef WMDidChangeMenuTitleAppearanceSettings =
    CFSTR("WMDidChangeMenuTitleAppearanceSettings");

CFStringRef WMDidChangeKeyboardLayoutNotification = CFSTR("WMDidChangeKeyboardLayoutNotification");

/* GNUstep applications notifications. Public ObjC part resides in DesktopKit/NXTWorkspace.h */
// WM.plist
CFStringRef WMDidChangeAppearanceSettingsNotification = CFSTR("WMDidChangeAppearanceSettingsNotification");
// WMState.plist
CFStringRef WMDidChangeDockContentNotification = CFSTR("WMDidChangeDockContentNotification");
// Hide Others
CFStringRef WMShouldHideOthersNotification = CFSTR("WMShouldHideOthersNotification");
CFStringRef WMDidHideOthersNotification = CFSTR("WMDidHideOthersNotification");
// Quit or Force Quit
CFStringRef WMShouldTerminateApplicationNotification =
    CFSTR("WMShouldTerminateApplicationNotification");
CFStringRef WMDidTerminateApplicationNotification = CFSTR("WMDidTerminateApplicationNotification");
// Windows -> Zoom Window
CFStringRef WMShouldZoomWindowNotification = CFSTR("WMShouldZoomWindowNotification");
CFStringRef WMDidZoomWindowNotification = CFSTR("WMDidZoomWindowNotification");
// Windows -> Tile Window -> Left | Right | Top | Bottom
CFStringRef WMShouldTileWindowNotification = CFSTR("WMShouldTileWindowNotification");
CFStringRef WMDidTileWindowNotification = CFSTR("WMDidTileWindowNotification");
// Windows -> Shade Window
CFStringRef WMShouldShadeWindowNotification = CFSTR("WMShouldShadeWindowNotification");
CFStringRef WMDidShadeWindowNotification = CFSTR("WMDidShadeWindowNotification");
// Windows -> Arrange in Front
CFStringRef WMShouldArrangeWindowsNotification = CFSTR("WMShouldArrangeWindowsNotification");
CFStringRef WMDidArrangeWindowsNotification = CFSTR("WMDidArrangeWindowsNotification");
// Windows -> Miniaturize Window
CFStringRef WMShouldMinmizeWindowNotification = CFSTR("WMShouldMinmizeWindowNotification");
CFStringRef WMDidMinmizeWindowNotification = CFSTR("WMDidMinmizeWindowNotification");
// Windows -> Close Window
CFStringRef WMShouldCloseWindowNotification = CFSTR("WMShouldCloseWindowNotification");
CFStringRef WMDidCloseWindowNotification = CFSTR("WMDidCloseWindowNotification");

/***** Local *****/
static WScreen **wScreen = NULL;
static unsigned int _NumLockMask = 0;
static unsigned int _ScrollLockMask = 0;

WScreen *wDefaultScreen(void) { return wScreen[0]; }

/*--- Xlib errors -------------------------------------------------------------*/

static int _catchXError(Display *dpy, XErrorEvent *error)
{
  char buffer[MAXLINE];

  /* ignore some errors */
  if (error->resourceid != None &&
      ((error->error_code == BadDrawable && error->request_code == X_GetGeometry) ||
       (error->error_code == BadMatch && (error->request_code == X_SetInputFocus)) ||
       (error->error_code == BadWindow)
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
    return 0;
  } else if (wComposerErrorHandler(dpy, error)) {
    return 0;
  }

  FormatXError(dpy, error, buffer, MAXLINE);
  WMLogWarning(_("internal X error: %s"), buffer);
  return -1;
}

void wSetErrorHandler(void) { XSetErrorHandler((XErrorHandler)_catchXError); }

/*--- Signals -----------------------------------------------------------------*/

/* for SunOS */
#ifndef SA_RESTART
#define SA_RESTART 0
#endif

/* Just in case, for weirdo systems */
#ifndef SA_NODEFER
#define SA_NODEFER 0
#endif

/* call only inside signal handlers, with signals blocked */
#define SIG_WCHANGE_STATE(nstate)             \
  {                                           \
    w_global.program.signal_state = (nstate); \
    w_global.program.state = (nstate);        \
  }

/* User generated exit signal handler. */
static RETSIGTYPE _handleExitSig(int sig)
{
  sigset_t sigs;

  sigfillset(&sigs);
  sigprocmask(SIG_BLOCK, &sigs, NULL);

  if (sig == SIGUSR1) {
    WMLogWarning("got signal %i - restarting", sig);
    SIG_WCHANGE_STATE(WSTATE_NEED_RESTART);
  } else if (sig == SIGUSR2) {
    WMLogWarning("got signal %i - rereading defaults", sig);
    SIG_WCHANGE_STATE(WSTATE_NEED_REREAD);
  } else if (sig == SIGTERM || sig == SIGINT || sig == SIGHUP) {
    WMLogWarning("got signal %i - exiting...", sig);
    SIG_WCHANGE_STATE(WSTATE_NEED_EXIT);
  }

  sigprocmask(SIG_UNBLOCK, &sigs, NULL);
  DispatchEvent(NULL); /* Dispatch events imediately. */
}

/* Dummy signal handler */
static void _dummyHandler(int sig)
{
  /* Parameter is not used, but tell the compiler that it is ok */
  (void)sig;
}

/* General signal handler. Exits the program gently. */
static RETSIGTYPE _handleSig(int sig)
{
  WMLogCritical("got signal %i", sig);

  /* Setting the signal behaviour back to default and then reraising the
   * signal is a cleaner way to make program exit and core dump than calling
   * abort(), since it correctly returns from the signal handler and sets
   * the flags accordingly. -Dan
   */
  if (sig == SIGSEGV || sig == SIGFPE || sig == SIGBUS || sig == SIGILL || sig == SIGABRT) {
    signal(sig, SIG_DFL);
    kill(getpid(), sig);
    return;
  }

  /* wAbort(0); */
}

static RETSIGTYPE _buryChild(int foo)
{
  pid_t pid;
  int status;
  int save_errno = errno;
  sigset_t sigs;

  /* Parameter not used, but tell the compiler that it is ok */
  (void)foo;

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
  while ((pid = waitpid(-1, &status, WNOHANG)) > 0 || (pid < 0 && errno == EINTR)) {
    NotifyDeadProcess(pid, WEXITSTATUS(status));
  }

  sigprocmask(SIG_UNBLOCK, &sigs, NULL);

  errno = save_errno;
}

static void _setupSignalHandling(void)
{
  struct sigaction sig_action;

  /* emergency exit... */
  sig_action.sa_handler = _handleSig;
  sigemptyset(&sig_action.sa_mask);

  sig_action.sa_flags = SA_RESTART;
  sigaction(SIGQUIT, &sig_action, NULL);

  sig_action.sa_handler = _handleExitSig;

  /* Here we set SA_RESTART for safety, because SIGUSR1 may not be handled
   * immediately. -Dan */
  sig_action.sa_flags = SA_RESTART;
  sigaction(SIGTERM, &sig_action, NULL);       // Logout panel - OK
  sigaction(SIGINT, &sig_action, NULL);        // Logout panel - OK
  /* sigaction(SIGHUP, &sig_action, NULL); */  // managed by Desktop
  /* sigaction(SIGUSR1, &sig_action, NULL);*/  // managed by Desktop
  sigaction(SIGUSR2, &sig_action, NULL);       // WindowMaker reread defaults - OK

  /* ignore dead pipe */
  /* Because POSIX mandates that only signal with handlers are reset
   * accross an exec*(), we do not want to propagate ignoring SIGPIPEs
   * to children. Hence the dummy handler.
   * Philippe Troin <phil@fifi.org>
   */
  sig_action.sa_handler = &_dummyHandler;
  sig_action.sa_flags = SA_RESTART;
  sigaction(SIGPIPE, &sig_action, NULL);

  /* handle dead children */
  sig_action.sa_handler = _buryChild;
  sig_action.sa_flags = SA_NOCLDSTOP | SA_RESTART;
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

  // Unmanage signals which are managed by GNUstep part of Desktop
  signal(SIGHUP, SIG_IGN);   // NEXTSPACE
  signal(SIGUSR1, SIG_IGN);  // NEXTSPACE
}

/*--- Keyboard ----------------------------------------------------------------*/

static void _getOffendingModifiers(void)
{
  int i;
  XModifierKeymap *modmap;
  KeyCode nlock, slock;
  static int mask_table[8] = {ShiftMask, LockMask, ControlMask, Mod1Mask,
                              Mod2Mask,  Mod3Mask, Mod4Mask,    Mod5Mask};

  nlock = XKeysymToKeycode(dpy, XK_Num_Lock);
  slock = XKeysymToKeycode(dpy, XK_Scroll_Lock);

  /*
   * Find out the masks for the NumLock and ScrollLock modifiers,
   * so that we can bind the grabs for when they are enabled too.
   */
  modmap = XGetModifierMapping(dpy);

  if (modmap != NULL && modmap->max_keypermod > 0) {
    for (i = 0; i < 8 * modmap->max_keypermod; i++) {
      if (modmap->modifiermap[i] == nlock && nlock != 0)
        _NumLockMask = mask_table[i / modmap->max_keypermod];
      else if (modmap->modifiermap[i] == slock && slock != 0)
        _ScrollLockMask = mask_table[i / modmap->max_keypermod];
    }
  }

  if (modmap)
    XFreeModifiermap(modmap);
}

#ifdef NUMLOCK_HACK
void wHackedGrabKey(int keycode, unsigned int modifiers, Window grab_window, Bool owner_events,
                    int pointer_mode, int keyboard_mode)
{
  if (modifiers == AnyModifier)
    return;

  /* grab all combinations of the modifier with CapsLock, NumLock and
   * ScrollLock. How much memory/CPU does such a monstrosity consume
   * in the server?
   */
  if (_NumLockMask)
    XGrabKey(dpy, keycode, modifiers | _NumLockMask, grab_window, owner_events, pointer_mode,
             keyboard_mode);
  if (_ScrollLockMask)
    XGrabKey(dpy, keycode, modifiers | _ScrollLockMask, grab_window, owner_events, pointer_mode,
             keyboard_mode);
  if (_NumLockMask && _ScrollLockMask)
    XGrabKey(dpy, keycode, modifiers | _NumLockMask | _ScrollLockMask, grab_window, owner_events,
             pointer_mode, keyboard_mode);
  if (_NumLockMask)
    XGrabKey(dpy, keycode, modifiers | _NumLockMask | LockMask, grab_window, owner_events,
             pointer_mode, keyboard_mode);
  if (_ScrollLockMask)
    XGrabKey(dpy, keycode, modifiers | _ScrollLockMask | LockMask, grab_window, owner_events,
             pointer_mode, keyboard_mode);
  if (_NumLockMask && _ScrollLockMask)
    XGrabKey(dpy, keycode, modifiers | _NumLockMask | _ScrollLockMask | LockMask, grab_window,
             owner_events, pointer_mode, keyboard_mode);
  /* phew, I guess that's all, right? */
}
#endif

void wHackedGrabButton(unsigned int button, unsigned int modifiers, Window grab_window,
                       Bool owner_events, unsigned int event_mask, int pointer_mode,
                       int keyboard_mode, Window confine_to, Cursor cursor)
{
  XGrabButton(dpy, button, modifiers, grab_window, owner_events, event_mask, pointer_mode,
              keyboard_mode, confine_to, cursor);

  if (modifiers == AnyModifier)
    return;

  XGrabButton(dpy, button, modifiers | LockMask, grab_window, owner_events, event_mask,
              pointer_mode, keyboard_mode, confine_to, cursor);

#ifdef NUMLOCK_HACK
  /* same as above, but for mouse buttons */
  if (_NumLockMask)
    XGrabButton(dpy, button, modifiers | _NumLockMask, grab_window, owner_events, event_mask,
                pointer_mode, keyboard_mode, confine_to, cursor);
  if (_ScrollLockMask)
    XGrabButton(dpy, button, modifiers | _ScrollLockMask, grab_window, owner_events, event_mask,
                pointer_mode, keyboard_mode, confine_to, cursor);
  if (_NumLockMask && _ScrollLockMask)
    XGrabButton(dpy, button, modifiers | _ScrollLockMask | _NumLockMask, grab_window, owner_events,
                event_mask, pointer_mode, keyboard_mode, confine_to, cursor);
  if (_NumLockMask)
    XGrabButton(dpy, button, modifiers | _NumLockMask | LockMask, grab_window, owner_events,
                event_mask, pointer_mode, keyboard_mode, confine_to, cursor);
  if (_ScrollLockMask)
    XGrabButton(dpy, button, modifiers | _ScrollLockMask | LockMask, grab_window, owner_events,
                event_mask, pointer_mode, keyboard_mode, confine_to, cursor);
  if (_NumLockMask && _ScrollLockMask)
    XGrabButton(dpy, button, modifiers | _ScrollLockMask | _NumLockMask | LockMask, grab_window,
                owner_events, event_mask, pointer_mode, keyboard_mode, confine_to, cursor);
#endif /* NUMLOCK_HACK */
}

/*--- Init and startup --------------------------------------------------------*/

static void _initializeAtoms(void)
{
  w_global.atom.wm.state = XInternAtom(dpy, "WM_STATE", False);
  w_global.atom.wm.change_state = XInternAtom(dpy, "WM_CHANGE_STATE", False);
  w_global.atom.wm.protocols = XInternAtom(dpy, "WM_PROTOCOLS", False);
  w_global.atom.wm.take_focus = XInternAtom(dpy, "WM_TAKE_FOCUS", False);
  w_global.atom.wm.delete_window = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
  w_global.atom.wm.save_yourself = XInternAtom(dpy, "WM_SAVE_YOURSELF", False);
  w_global.atom.wm.client_leader = XInternAtom(dpy, "WM_CLIENT_LEADER", False);
  w_global.atom.wm.colormap_windows = XInternAtom(dpy, "WM_COLORMAP_WINDOWS", False);
  w_global.atom.wm.colormap_notify = XInternAtom(dpy, "WM_COLORMAP_NOTIFY", False);

  w_global.atom.wmaker.menu = XInternAtom(dpy, "_WINDOWMAKER_MENU", False);
  w_global.atom.wmaker.state = XInternAtom(dpy, "_WINDOWMAKER_STATE", False);
  w_global.atom.wmaker.wm_protocols = XInternAtom(dpy, "_WINDOWMAKER_WM_PROTOCOLS", False);
  w_global.atom.wmaker.wm_function = XInternAtom(dpy, "_WINDOWMAKER_WM_FUNCTION", False);
  w_global.atom.wmaker.noticeboard = XInternAtom(dpy, "_WINDOWMAKER_NOTICEBOARD", False);
  w_global.atom.wmaker.command = XInternAtom(dpy, "_WINDOWMAKER_COMMAND", False);
  w_global.atom.wmaker.icon_size = XInternAtom(dpy, "_WINDOWMAKER_ICON_SIZE", False);
  w_global.atom.wmaker.icon_tile = XInternAtom(dpy, "_WINDOWMAKER_ICON_TILE", False);

  w_global.atom.gnustep.wm_attr = XInternAtom(dpy, "_GNUSTEP_WM_ATTR", False);
  w_global.atom.gnustep.wm_miniaturize_window =
      XInternAtom(dpy, "_GNUSTEP_WM_MINIATURIZE_WINDOW", False);
  w_global.atom.gnustep.wm_hide_app = XInternAtom(dpy, "_GNUSTEP_WM_HIDE_APP", False);
  w_global.atom.gnustep.titlebar_state = XInternAtom(dpy, "_GNUSTEP_TITLEBAR_STATE", False);

  w_global.atom.desktop.gtk_object_path = XInternAtom(dpy, "_GTK_APPLICATION_OBJECT_PATH", False);

  w_global.atom.wm.ignore_focus_events = XInternAtom(dpy, "WM_IGNORE_FOCUS_EVENTS", False);

#ifdef USE_DOCK_XDND
  wXDNDInitializeAtoms();
#endif
}

static void _initializeCursors(void)
{
  Pixmap cur = XCreatePixmap(dpy, DefaultRootWindow(dpy), 16, 16, 1);
  GC gc = XCreateGC(dpy, cur, 0, NULL);
  XColor black;

  memset(&black, 0, sizeof(XColor));
  XSetForeground(dpy, gc, 0);
  XFillRectangle(dpy, cur, gc, 0, 0, 16, 16);
  XFreeGC(dpy, gc);
  wPreferences.cursor[WCUR_EMPTY] = XCreatePixmapCursor(dpy, cur, cur, &black, &black, 0, 0);
  XFreePixmap(dpy, cur);

  wPreferences.cursor[WCUR_NORMAL] = None; /* inherit from root */
  wPreferences.cursor[WCUR_ROOT] = XCreateFontCursor(dpy, XC_left_ptr);
  wPreferences.cursor[WCUR_ARROW] = XCreateFontCursor(dpy, XC_top_left_arrow);
  wPreferences.cursor[WCUR_MOVE] = XCreateFontCursor(dpy, XC_fleur);
  wPreferences.cursor[WCUR_RESIZE] = XCreateFontCursor(dpy, XC_sizing);
  wPreferences.cursor[WCUR_TOPLEFTRESIZE] = XCreateFontCursor(dpy, XC_top_left_corner);
  wPreferences.cursor[WCUR_TOPRIGHTRESIZE] = XCreateFontCursor(dpy, XC_top_right_corner);
  wPreferences.cursor[WCUR_BOTTOMLEFTRESIZE] = XCreateFontCursor(dpy, XC_bottom_left_corner);
  wPreferences.cursor[WCUR_BOTTOMRIGHTRESIZE] = XCreateFontCursor(dpy, XC_bottom_right_corner);
  wPreferences.cursor[WCUR_VERTICALRESIZE] = XCreateFontCursor(dpy, XC_sb_v_double_arrow);
  wPreferences.cursor[WCUR_HORIZONRESIZE] = XCreateFontCursor(dpy, XC_sb_h_double_arrow);
  wPreferences.cursor[WCUR_WAIT] = XCreateFontCursor(dpy, XC_watch);
  wPreferences.cursor[WCUR_QUESTION] = XCreateFontCursor(dpy, XC_question_arrow);
  wPreferences.cursor[WCUR_TEXT] = XCreateFontCursor(dpy, XC_xterm);
  wPreferences.cursor[WCUR_SELECT] = XCreateFontCursor(dpy, XC_cross);
}

static Bool _isWindowInList(Window window, Window *list, int count)
{
  for (; count >= 0; count--) {
    if (window == list[count])
      return True;
  }
  return False;
}

/*
 * Manages all windows in the screen.
 * Called when the wm is being started. No events can be processed while the windows
 * are being reparented/managed.
 */
static void _manageAllWindows(WScreen *scr)
{
  Window root, parent;
  Window *children;
  unsigned int nchildren;
  unsigned int i, j;
  WWindow *wwin;

  // Startup 1 begins
  scr->flags.startup = 1;

  XGrabServer(dpy);
  XQueryTree(dpy, scr->root_win, &root, &parent, &children, &nchildren);

  /* first remove all icon windows */
  for (i = 0; i < nchildren; i++) {
    XWMHints *wmhints;

    if (children[i] == None)
      continue;

    wmhints = XGetWMHints(dpy, children[i]);
    if (wmhints && (wmhints->flags & IconWindowHint)) {
      for (j = 0; j < nchildren; j++) {
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
  /* now manage them */
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
      if (wwin->flags.miniaturized &&
          (wwin->transient_for == None || wwin->transient_for == scr->root_win ||
           !_isWindowInList(wwin->transient_for, children, nchildren))) {
        wwin->flags.skip_next_animation = 1;
        wwin->flags.miniaturized = 0;
        wIconifyWindow(wwin);
      } else {
        wClientSetState(wwin, NormalState, None);
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
        wApplicationHide(wapp);
      } else {
        wwin->flags.hidden = 0;
      }
    }
    wwin = wwin->prev;
  }

  XFree(children);

  /* Startup 1 finished */
  scr->flags.startup = 0;

  /* Startup 2 begins */
  scr->flags.startup2 = 1;

  while (XPending(dpy)) {
    XEvent ev;
    WMNextEvent(dpy, &ev);
    WMHandleEvent(&ev);
  }

  // Startup 2 finishes in Controller-applicationsDidFinishLaunching
  /* scr->flags.startup2 = 0; */
}

/*
 * Starts the window manager and setup global data.
 */
void wStartUp(Bool defaultScreenOnly)
{
  WScreen *scr;
  int i, j, max;
  char **formats;

  /* Ignore CapsLock in modifiers */
  w_global.shortcut.modifiers_mask = 0xff & ~LockMask;
  _getOffendingModifiers();

  /* Ignore NumLock and ScrollLock too */
  w_global.shortcut.modifiers_mask &= ~(_NumLockMask | _ScrollLockMask);

  memset(&wKeyBindings, 0, sizeof(wKeyBindings));

  w_global.context.client_win = XUniqueContext();
  w_global.context.app_win = XUniqueContext();
  w_global.context.stack = XUniqueContext();

  /* _XA_VERSION = XInternAtom(dpy, "VERSION", False); */

  _initializeAtoms();

  _initializeCursors();

  _setupSignalHandling();

  /* set hook for out event dispatcher in WINGs event dispatcher */
  WMHookEventHandler(DispatchEvent);

  /*
    Initialize defaults stuff
  */
  // Read defaults from WM.plist file. This file may not exist - use hardcoded defults (defaults.c).
  // Defaults are propagated into wPreferences, WScreen.
  w_global.domain.wm_preferences = wDefaultsInitDomain("WM", false);
  if (!w_global.domain.wm_preferences->dictionary) {
    WMLogWarning("could not read domain \"WM\" from defaults database");
  }

  // Process defaults that don't change until a restart and are screen independent.
  // Were read from WM.plist on previous step.
  if (w_global.domain.wm_preferences) {
    wDefaultsReadStaticPreferences(w_global.domain.wm_preferences->dictionary);
    // WMUserDefaultsWrite(w_global.domain.wm_preferences->dictionary, w_global.domain.wm_preferences->name);
  } else {
    wDefaultsReadStaticPreferences(NULL);
  }

  w_global.domain.wm_state = wDefaultsInitDomain("WMState", true);
  if (!w_global.domain.wm_state->dictionary) {
    WMLogWarning("could not read domain \"WMState\" from defaults database");
  }

  /* check sanity of some values */
  if (wPreferences.icon_size < 64) {
    WMLogWarning("Icon size is configured to %i, but it's too small. Using 64 instead",
                 wPreferences.icon_size);
    wPreferences.icon_size = 64;
  }

  /* init other domains */
  w_global.domain.window_attrs = wDefaultsInitDomain("WMWindowAttributes", true);
  if (!w_global.domain.window_attrs->dictionary) {
    WMLogWarning("could not read domain \"WMWindowAttributes\" from defaults database");
  }

  wSetErrorHandler();

#ifdef USE_XSHAPE
  /* ignore j */
  w_global.xext.shape.supported = XShapeQueryExtension(dpy, &w_global.xext.shape.event_base, &j);
#endif
#ifdef USE_XKB
  w_global.xext.xkb.supported =
      XkbQueryExtension(dpy, NULL, &w_global.xext.xkb.event_base, NULL, NULL, NULL);
  if (!w_global.xext.xkb.supported) {
    WMLogWarning(_("XKB is not supported."));
  }
#endif

  /* Check if TIFF images are supported */
  formats = RSupportedFileFormats();
  if (formats) {
    for (i = 0; formats[i] != NULL; i++) {
      if (strcmp(formats[i], "TIFF") == 0) {
        wPreferences.supports_tiff = 1;
        break;
      }
    }
  }

  /* manage the screen */
  max = defaultScreenOnly ? 1 : ScreenCount(dpy);
  wScreen = wmalloc(sizeof(WScreen *) * max);
  wScreen[0] = wScreenInit(DefaultScreen(dpy));

  scr = wScreen[0];

  /* Center for notifications inside WM. */
  scr->notificationCenter = CFNotificationCenterGetLocalCenter();

  /* Launching icons list */
  scr->launching_icons = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);

  InitializeSwitchMenu(scr);

  /* initialize/restore state for the screens */
  wScreenRestoreState(scr);

  /* manage all windows that were already here before us */
  if (!wPreferences.flags.nodock && wScreen[0]->dock) {
    wScreen[0]->last_dock = wScreen[0]->dock;
  }

  _manageAllWindows(scr);

  scr->last_desktop = 0;
  wDesktopForceChange(scr, 0, NULL);

  if (!wPreferences.flags.noclip) {
    wDockShowIcons(scr->desktops[scr->current_desktop]->clip);
  }

  /* restore saved menus */
  wMenuRestoreState(scr);

  /* If we're not restarting, restore session */
  if (!wPreferences.flags.norestore) {
    int lastDesktop = wNETWMGetCurrentDesktopFromHint(scr);

    wSessionRestoreState(scr);

    /* go to desktop where we were before restart */
    if (lastDesktop >= 0) {
      wDesktopForceChange(scr, lastDesktop, NULL);
    } else {
      wSessionRestoreLastDesktop(scr);
    }
  }
}

/*
 * Entry point for window manager part.
 */
void wInitialize(int argc, char **argv)
{
  char *DisplayName = NULL;
  // Initialize Xlib support for concurrent threads.
  XInitThreads();

  memset(&w_global, 0, sizeof(w_global));
  w_global.program.state = WSTATE_NORMAL;
  w_global.program.signal_state = WSTATE_NORMAL;
  w_global.timestamp.last_event = CurrentTime;
  w_global.timestamp.focus_change = CurrentTime;
  w_global.ignore_desktop_change = False;
  w_global.shortcut.modifiers_mask = 0xff;

  memset(&wPreferences, 0, sizeof(wPreferences));
  // wDockDoAutoLaunch() called in applicationDidFinishLaunching of Workspace
  wPreferences.flags.noautolaunch = 1;
  wPreferences.flags.nodock = 0;
  wPreferences.flags.noclip = 1;
  wPreferences.flags.nodrawer = 1;

  // setlocale(LC_ALL, "");

  // if (w_global.locale) {
  //   setenv("LANG", w_global.locale, 1);
  // } else {
  //   w_global.locale = getenv("LC_ALL");
  //   if (!w_global.locale) {
  //     w_global.locale = getenv("LANG");
  //   }
  // }

  // setlocale(LC_ALL, "");

  // if (!w_global.locale || strcmp(w_global.locale, "C") == 0 ||
  //     strcmp(w_global.locale, "POSIX") == 0) {
  //   w_global.locale = NULL;
  // } else {
  //   char *ptr;

  //   w_global.locale = wstrdup(w_global.locale);
  //   ptr = strchr(w_global.locale, '.');
  //   if (ptr)
  //     *ptr = 0;
  // }

  /* open display */
  dpy = XOpenDisplay(DisplayName);
  if (dpy == NULL) {
    WMLogCritical(_("could not open display \"%s\""), XDisplayName(DisplayName));
    exit(1);
  }

  if (fcntl(ConnectionNumber(dpy), F_SETFD, FD_CLOEXEC) < 0) {
    WMLogError("error setting close-on-exec flag for X connection");
    exit(1);
  }

  if (wGetWVisualID(0) < 0) {
    /*
     *   If unspecified, use default visual instead of waiting
     * for wrlib/context.c:bestContext() that may end up choosing
     * the "fake" 24 bits added by the Composite extension.
     *   This is required to avoid all sort of corruptions when
     * composite is enabled, and at a depth other than 24.
     */
    wSetWVisualID(0, (int)DefaultVisual(dpy, DefaultScreen(dpy))->visualid);
  }

  // DisplayName = XDisplayName(DisplayName);
  // setenv("DISPLAY", DisplayName, 1);

  wXModifierInitialize();
}
