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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
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
#include <X11/Xresource.h>
#include <X11/Xutil.h>
#include <X11/cursorfont.h>
#include <X11/Xproto.h>
#include <X11/keysym.h>
#ifdef USE_XSHAPE
#include <X11/extensions/shape.h>
#endif
#ifdef KEEP_XKB_LOCK_STATUS
#include <X11/XKBlib.h>
#endif
#ifdef USE_RANDR
#include <X11/extensions/Xrandr.h>
#endif

#include "WindowMaker.h"
#include "GNUstep.h"
#include "texture.h"
#include "screen.h"
#include "window.h"
#include "actions.h"
#include "client.h"
#include "main.h"
#include "startup.h"
#include "dock.h"
#include "workspace.h"
#include "keybind.h"
#include "framewin.h"
#include "session.h"
#include "defaults.h"
#include "properties.h"
#include "dialog.h"
#include "wmspec.h"
#include "event.h"
#include "switchmenu.h"
#ifdef USE_DOCK_XDND
#include "xdnd.h"
#endif

#include "xutil.h"

/* for SunOS */
#ifndef SA_RESTART
# define SA_RESTART 0
#endif

/* Just in case, for weirdo systems */
#ifndef SA_NODEFER
# define SA_NODEFER 0
#endif

/***** Local *****/
static WScreen **wScreen = NULL;
static unsigned int _NumLockMask = 0;
static unsigned int _ScrollLockMask = 0;
static void manageAllWindows(WScreen * scr, int crashed);

static int catchXError(Display * dpy, XErrorEvent * error)
{
	char buffer[MAXLINE];

	/* ignore some errors */
	if (error->resourceid != None
	    && ((error->error_code == BadDrawable && error->request_code == X_GetGeometry)
          || (error->error_code == BadMatch && (error->request_code == X_SetInputFocus))
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
		return 0;
	}
	FormatXError(dpy, error, buffer, MAXLINE);
	wwarning(_("internal X error: %s"), buffer);
	return -1;
}

/*
 *----------------------------------------------------------------------
 * handleXIO-
 * 	Handle X shutdowns and other stuff.
 *----------------------------------------------------------------------
 */
static int handleXIO(Display * xio_dpy)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) xio_dpy;

	dpy = NULL;
	Exit(0);
	return 0;
}

/*
 *----------------------------------------------------------------------
 * handleExitSig--
 * 	User generated exit signal handler.
 *----------------------------------------------------------------------
 */
static RETSIGTYPE handleExitSig(int sig)
{
	sigset_t sigs;

	sigfillset(&sigs);
	sigprocmask(SIG_BLOCK, &sigs, NULL);

	if (sig == SIGUSR1) {
		wwarning("got signal %i - restarting", sig);
		SIG_WCHANGE_STATE(WSTATE_NEED_RESTART);
	} else if (sig == SIGUSR2) {
		wwarning("got signal %i - rereading defaults", sig);
		SIG_WCHANGE_STATE(WSTATE_NEED_REREAD);
	} else if (sig == SIGTERM || sig == SIGINT || sig == SIGHUP) {
		wwarning("got signal %i - exiting...", sig);
		SIG_WCHANGE_STATE(WSTATE_NEED_EXIT);
	}

	sigprocmask(SIG_UNBLOCK, &sigs, NULL);
	DispatchEvent(NULL);	/* Dispatch events imediately. */
}

/* Dummy signal handler */
static void dummyHandler(int sig)
{
	/* Parameter is not used, but tell the compiler that it is ok */
	(void) sig;
}

/*
 *----------------------------------------------------------------------
 * handleSig--
 * 	general signal handler. Exits the program gently.
 *----------------------------------------------------------------------
 */
static RETSIGTYPE handleSig(int sig)
{
	wfatal("got signal %i", sig);

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

	wAbort(0);
}

static RETSIGTYPE buryChild(int foo)
{
	pid_t pid;
	int status;
	int save_errno = errno;
	sigset_t sigs;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) foo;

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

static void getOffendingModifiers(void)
{
	int i;
	XModifierKeymap *modmap;
	KeyCode nlock, slock;
	static int mask_table[8] = {
		ShiftMask, LockMask, ControlMask, Mod1Mask,
		Mod2Mask, Mod3Mask, Mod4Mask, Mod5Mask
	};

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
void
wHackedGrabKey(int keycode, unsigned int modifiers,
               Window grab_window, Bool owner_events, int pointer_mode, int keyboard_mode)
{
	if (modifiers == AnyModifier)
		return;

	/* grab all combinations of the modifier with CapsLock, NumLock and
	 * ScrollLock. How much memory/CPU does such a monstrosity consume
	 * in the server?
	 */
	if (_NumLockMask)
		XGrabKey(dpy, keycode, modifiers | _NumLockMask,
             grab_window, owner_events, pointer_mode, keyboard_mode);
	if (_ScrollLockMask)
		XGrabKey(dpy, keycode, modifiers | _ScrollLockMask,
             grab_window, owner_events, pointer_mode, keyboard_mode);
	if (_NumLockMask && _ScrollLockMask)
		XGrabKey(dpy, keycode, modifiers | _NumLockMask | _ScrollLockMask,
             grab_window, owner_events, pointer_mode, keyboard_mode);
	if (_NumLockMask)
		XGrabKey(dpy, keycode, modifiers | _NumLockMask | LockMask,
             grab_window, owner_events, pointer_mode, keyboard_mode);
	if (_ScrollLockMask)
		XGrabKey(dpy, keycode, modifiers | _ScrollLockMask | LockMask,
             grab_window, owner_events, pointer_mode, keyboard_mode);
	if (_NumLockMask && _ScrollLockMask)
		XGrabKey(dpy, keycode, modifiers | _NumLockMask | _ScrollLockMask | LockMask,
             grab_window, owner_events, pointer_mode, keyboard_mode);
	/* phew, I guess that's all, right? */
}
#endif

void
wHackedGrabButton(unsigned int button, unsigned int modifiers,
                  Window grab_window, Bool owner_events,
                  unsigned int event_mask, int pointer_mode, int keyboard_mode,
                  Window confine_to, Cursor cursor)
{
	XGrabButton(dpy, button, modifiers, grab_window, owner_events,
              event_mask, pointer_mode, keyboard_mode, confine_to, cursor);

	if (modifiers == AnyModifier)
		return;

	XGrabButton(dpy, button, modifiers | LockMask, grab_window, owner_events,
              event_mask, pointer_mode, keyboard_mode, confine_to, cursor);

#ifdef NUMLOCK_HACK
	/* same as above, but for mouse buttons */
	if (_NumLockMask)
		XGrabButton(dpy, button, modifiers | _NumLockMask,
                grab_window, owner_events, event_mask, pointer_mode,
                keyboard_mode, confine_to, cursor);
	if (_ScrollLockMask)
		XGrabButton(dpy, button, modifiers | _ScrollLockMask,
                grab_window, owner_events, event_mask, pointer_mode,
                keyboard_mode, confine_to, cursor);
	if (_NumLockMask && _ScrollLockMask)
		XGrabButton(dpy, button, modifiers | _ScrollLockMask | _NumLockMask,
                grab_window, owner_events, event_mask, pointer_mode,
                keyboard_mode, confine_to, cursor);
	if (_NumLockMask)
		XGrabButton(dpy, button, modifiers | _NumLockMask | LockMask,
                grab_window, owner_events, event_mask, pointer_mode,
                keyboard_mode, confine_to, cursor);
	if (_ScrollLockMask)
		XGrabButton(dpy, button, modifiers | _ScrollLockMask | LockMask,
                grab_window, owner_events, event_mask, pointer_mode,
                keyboard_mode, confine_to, cursor);
	if (_NumLockMask && _ScrollLockMask)
		XGrabButton(dpy, button, modifiers | _ScrollLockMask | _NumLockMask | LockMask,
                grab_window, owner_events, event_mask, pointer_mode,
                keyboard_mode, confine_to, cursor);
#endif				/* NUMLOCK_HACK */
}

WScreen *wScreenWithNumber(int i)
{
	assert(i < w_global.screen_count);

	return wScreen[i];
}

WScreen *wScreenForRootWindow(Window window)
{
	int i;

	if (w_global.screen_count == 1)
		return wScreen[0];

	/* Since the number of heads will probably be small (normally 2),
	 * it should be faster to use this than a hash table, because
	 * of the overhead. */
	for (i = 0; i < w_global.screen_count; i++)
		if (wScreen[i]->root_win == window)
			return wScreen[i];

	return wScreenForWindow(window);
}

WScreen *wScreenForWindow(Window window)
{
	XWindowAttributes attr;

	if (w_global.screen_count == 1)
		return wScreen[0];

	if (XGetWindowAttributes(dpy, window, &attr))
		return wScreenForRootWindow(attr.root);

	return NULL;
}

static char *atomNames[] = {
  /* 0  */  "WM_STATE",
  /* 1  */  "WM_CHANGE_STATE",
  /* 2  */  "WM_PROTOCOLS",
  /* 3  */  "WM_TAKE_FOCUS",
  /* 4  */  "WM_DELETE_WINDOW",
  /* 5  */  "WM_SAVE_YOURSELF",
  /* 6  */  "WM_CLIENT_LEADER",
  /* 7  */  "WM_COLORMAP_WINDOWS",
  /* 8  */  "WM_COLORMAP_NOTIFY",

  /* 9  */  "_WINDOWMAKER_MENU",
  /* 10 */  "_WINDOWMAKER_STATE",
  /* 11 */  "_WINDOWMAKER_WM_PROTOCOLS",
  /* 12 */  "_WINDOWMAKER_WM_FUNCTION",
  /* 13 */  "_WINDOWMAKER_NOTICEBOARD",
  /* 14 */  "_WINDOWMAKER_COMMAND",
  /* 15 */  "_WINDOWMAKER_ICON_SIZE",
  /* 16 */  "_WINDOWMAKER_ICON_TILE",

  /* 17 */  "_GNUSTEP_WM_ATTR",
  /* 18 */  "_GNUSTEP_WM_MINIATURIZE_WINDOW",
  /* 19 */  "_GNUSTEP_WM_HIDE_APP",
  /* 20 */  "_GNUSTEP_TITLEBAR_STATE",

  /* 21 */  "_GTK_APPLICATION_OBJECT_PATH",

  /* 22 */  "WM_IGNORE_FOCUS_EVENTS"
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
void StartUp(Bool defaultScreenOnly)
{
	struct sigaction sig_action;
	int i, j, max;
	char **formats;
	Atom atom[wlengthof(atomNames)];

	/*
	 * Ignore CapsLock in modifiers
	 */
	w_global.shortcut.modifiers_mask = 0xff & ~LockMask;

	getOffendingModifiers();
	/*
	 * Ignore NumLock and ScrollLock too
	 */
	w_global.shortcut.modifiers_mask &= ~(_NumLockMask | _ScrollLockMask);

	memset(&wKeyBindings, 0, sizeof(wKeyBindings));

	w_global.context.client_win = XUniqueContext();
	w_global.context.app_win = XUniqueContext();
	w_global.context.stack = XUniqueContext();

	/*    _XA_VERSION = XInternAtom(dpy, "VERSION", False); */

#ifdef HAVE_XINTERNATOMS
	XInternAtoms(dpy, atomNames, wlengthof(atomNames), False, atom);
#else

	{
		int i;
		for (i = 0; i < wlengthof(atomNames); i++)
			atom[i] = XInternAtom(dpy, atomNames[i], False);
	}
#endif

	w_global.atom.wm.state = atom[0];
	w_global.atom.wm.change_state = atom[1];
	w_global.atom.wm.protocols = atom[2];
	w_global.atom.wm.take_focus = atom[3];
	w_global.atom.wm.delete_window = atom[4];
	w_global.atom.wm.save_yourself = atom[5];
	w_global.atom.wm.client_leader = atom[6];
	w_global.atom.wm.colormap_windows = atom[7];
	w_global.atom.wm.colormap_notify = atom[8];

	w_global.atom.wmaker.menu = atom[9];
	w_global.atom.wmaker.state = atom[10];
	w_global.atom.wmaker.wm_protocols = atom[11];
	w_global.atom.wmaker.wm_function = atom[12];
	w_global.atom.wmaker.noticeboard = atom[13];
	w_global.atom.wmaker.command = atom[14];
	w_global.atom.wmaker.icon_size = atom[15];
	w_global.atom.wmaker.icon_tile = atom[16];

	w_global.atom.gnustep.wm_attr = atom[17];
	w_global.atom.gnustep.wm_miniaturize_window = atom[18];
	w_global.atom.gnustep.wm_hide_app = atom[19];
	w_global.atom.gnustep.titlebar_state = atom[20];

	w_global.atom.desktop.gtk_object_path = atom[21];

	w_global.atom.wm.ignore_focus_events = atom[22];

#ifdef USE_DOCK_XDND
	wXDNDInitializeAtoms();
#endif

	/* cursors */
	wPreferences.cursor[WCUR_NORMAL] = None;	/* inherit from root */
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
	wPreferences.cursor[WCUR_TEXT] = XCreateFontCursor(dpy, XC_xterm);	/* odd name??? */
	wPreferences.cursor[WCUR_SELECT] = XCreateFontCursor(dpy, XC_cross);

	Pixmap cur = XCreatePixmap(dpy, DefaultRootWindow(dpy), 16, 16, 1);
	GC gc = XCreateGC(dpy, cur, 0, NULL);
	XColor black;
	memset(&black, 0, sizeof(XColor));
	XSetForeground(dpy, gc, 0);
	XFillRectangle(dpy, cur, gc, 0, 0, 16, 16);
	XFreeGC(dpy, gc);
	wPreferences.cursor[WCUR_EMPTY] = XCreatePixmapCursor(dpy, cur, cur, &black, &black, 0, 0);
	XFreePixmap(dpy, cur);

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

	sig_action.sa_handler = handleExitSig;

	/* Here we set SA_RESTART for safety, because SIGUSR1 may not be handled
	 * immediately. -Dan */
	sig_action.sa_flags = SA_RESTART;
	sigaction(SIGTERM, &sig_action, NULL);
	sigaction(SIGINT, &sig_action, NULL);
	sigaction(SIGHUP, &sig_action, NULL);
	sigaction(SIGUSR1, &sig_action, NULL);
	sigaction(SIGUSR2, &sig_action, NULL);

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

	/* handle X shutdowns a such */
	XSetIOErrorHandler(handleXIO);

	/* set hook for out event dispatcher in WINGs event dispatcher */
	WMHookEventHandler(DispatchEvent);

	/* initialize defaults stuff */
	w_global.domain.wmaker = wDefaultsInitDomain("WindowMaker", True);
	if (!w_global.domain.wmaker->dictionary)
		wwarning(_("could not read domain \"%s\" from defaults database"), "WindowMaker");

	/* read defaults that don't change until a restart and are
	 * screen independent */
	wReadStaticDefaults(w_global.domain.wmaker ? w_global.domain.wmaker->dictionary : NULL);

	/* check sanity of some values */
	if (wPreferences.icon_size < 16) {
		wwarning(_("icon size is configured to %i, but it's too small. Using 16 instead"),
             wPreferences.icon_size);
		wPreferences.icon_size = 16;
	}

	/* init other domains */
	w_global.domain.root_menu = wDefaultsInitDomain("WMRootMenu", False);
	if (!w_global.domain.root_menu->dictionary)
		wwarning(_("could not read domain \"%s\" from defaults database"), "WMRootMenu");

	wDefaultsMergeGlobalMenus(w_global.domain.root_menu);

	w_global.domain.window_attr = wDefaultsInitDomain("WMWindowAttributes", True);
	if (!w_global.domain.window_attr->dictionary)
		wwarning(_("could not read domain \"%s\" from defaults database"), "WMWindowAttributes");

	XSetErrorHandler((XErrorHandler) catchXError);

#ifdef USE_XSHAPE
	/* ignore j */
	w_global.xext.shape.supported = XShapeQueryExtension(dpy, &w_global.xext.shape.event_base, &j);
#endif

#ifdef USE_RANDR
	w_global.xext.randr.supported = XRRQueryExtension(dpy, &w_global.xext.randr.event_base, &j);
#endif

#ifdef KEEP_XKB_LOCK_STATUS
	w_global.xext.xkb.supported = XkbQueryExtension(dpy, NULL, &w_global.xext.xkb.event_base,
                                                  NULL, NULL, NULL);
	if (wPreferences.modelock && !w_global.xext.xkb.supported) {
		wwarning(_("XKB is not supported. KbdModeLock is automatically disabled."));
		wPreferences.modelock = 0;
	}
#endif

	if (defaultScreenOnly)
		max = 1;
	else
		max = ScreenCount(dpy);

	wScreen = wmalloc(sizeof(WScreen *) * max);

	w_global.screen_count = 0;

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

	/* manage the screens */
	for (j = 0; j < max; j++) {
		if (defaultScreenOnly || max == 1) {
			wScreen[w_global.screen_count] = wScreenInit(DefaultScreen(dpy));
			if (!wScreen[w_global.screen_count]) {
				wfatal(_("it seems that there is already a window manager running"));
				Exit(1);
			}
		} else {
			wScreen[w_global.screen_count] = wScreenInit(j);
			if (!wScreen[w_global.screen_count]) {
				wwarning(_("could not manage screen %i"), j);
				continue;
			}
		}
		w_global.screen_count++;
	}

	InitializeSwitchMenu();

	/* initialize/restore state for the screens */
	for (j = 0; j < w_global.screen_count; j++) {
		int lastDesktop;

		lastDesktop = wNETWMGetCurrentDesktopFromHint(wScreen[j]);

		wScreenRestoreState(wScreen[j]);

		/* manage all windows that were already here before us */
		if (!wPreferences.flags.nodock && wScreen[j]->dock)
			wScreen[j]->last_dock = wScreen[j]->dock;

		manageAllWindows(wScreen[j], wPreferences.flags.restarting == 2);

		/* restore saved menus */
		wMenuRestoreState(wScreen[j]);

		/* If we're not restarting, restore session */
		if (wPreferences.flags.restarting == 0 && !wPreferences.flags.norestore)
			wSessionRestoreState(wScreen[j]);

		if (!wPreferences.flags.noautolaunch) {
			/* auto-launch apps */
			if (!wPreferences.flags.nodock && wScreen[j]->dock) {
				wScreen[j]->last_dock = wScreen[j]->dock;
				wDockDoAutoLaunch(wScreen[j]->dock, 0);
			}
			/* auto-launch apps in clip */
			if (!wPreferences.flags.noclip) {
				int i;
				for (i = 0; i < wScreen[j]->workspace_count; i++) {
					if (wScreen[j]->workspaces[i]->clip) {
						wScreen[j]->last_dock = wScreen[j]->workspaces[i]->clip;
						wDockDoAutoLaunch(wScreen[j]->workspaces[i]->clip, i);
					}
				}
			}
			/* auto-launch apps in drawers */
			if (!wPreferences.flags.nodrawer) {
				WDrawerChain *dc;
				for (dc = wScreen[j]->drawers; dc; dc = dc->next) {
					wScreen[j]->last_dock = dc->adrawer;
					wDockDoAutoLaunch(dc->adrawer, 0);
				}
			}
		}

		/* go to workspace where we were before restart */
		if (lastDesktop >= 0)
			wWorkspaceForceChange(wScreen[j], lastDesktop);
		else
			wSessionRestoreLastWorkspace(wScreen[j]);
	}

	if (w_global.screen_count == 0) {
		wfatal(_("could not manage any screen"));
		Exit(1);
	}

#ifndef HAVE_INOTIFY
	/* setup defaults file polling */
	if (!wPreferences.flags.noupdates)
		WMAddTimerHandler(3000, wDefaultsCheckDomains, NULL);
#endif

}

static Bool windowInList(Window window, Window * list, int count)
{
	for (; count >= 0; count--) {
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
static void manageAllWindows(WScreen * scr, int crashRecovery)
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
              || !windowInList(wwin->transient_for, children, nchildren))) {

				wwin->flags.skip_next_animation = 1;
				wwin->flags.miniaturized = 0;
				wIconifyWindow(wwin);
			} else {
				wClientSetState(wwin, NormalState, None);
			}
			if (crashRecovery) {
				int border;

				border = (!HAS_BORDER(wwin) ? 0 : scr->frame_border_width);

				wWindowMove(wwin, wwin->frame_x - border,
                    wwin->frame_y - border -
                    (wwin->frame->titlebar ? wwin->frame->titlebar->height : 0));
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
	scr->last_workspace = 0;
	wWorkspaceForceChange(scr, 0);
	if (!wPreferences.flags.noclip)
		wDockShowIcons(scr->workspaces[scr->current_workspace]->clip);
	scr->flags.startup2 = 0;
}
