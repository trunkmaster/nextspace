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

#ifndef WMFUNCS_H_
#define WMFUNCS_H_

#include <sys/types.h>
#include <stdio.h>

#include "window.h"
#include "defaults.h"

typedef void (WCallBack)(void *cdata);

typedef void (WDeathHandler)(pid_t pid, unsigned int status, void *cdata);

void Shutdown(WShutdownMode mode);

void RestoreDesktop(WScreen *scr);

void Exit(int status);

void Restart(char *manager, Bool abortOnFailure);

void SetupEnvironment(WScreen *scr);

void DispatchEvent(XEvent *event);

#ifdef LITE
#define UpdateSwitchMenu(a,b,c)
#else
void UpdateSwitchMenu(WScreen *scr, WWindow *wwin, int action);

Bool wRootMenuPerformShortcut(XEvent *event);

void wRootMenuBindShortcuts(Window window);

void OpenRootMenu(WScreen *scr, int x, int y, int keyboard);

void OpenSwitchMenu(WScreen *scr, int x, int y, int keyboard);

void InitializeSwitchMenu(void);

#endif /* !LITE */



void OpenWindowMenu(WWindow *wwin, int x, int y, int keyboard);

void OpenMiniwindowMenu(WWindow *wwin, int x, int y);

void OpenWorkspaceMenu(WScreen *scr, int x, int y);

void CloseWindowMenu(WScreen *scr);

WMagicNumber wAddDeathHandler(pid_t pid, WDeathHandler *callback, void *cdata);

void wColormapInstallForWindow(WScreen *scr, WWindow *wwin);

void wColormapInstallRoot(WScreen *scr);

void wColormapUninstallRoot(WScreen *scr);

void wColormapAllowClientInstallation(WScreen *scr, Bool starting);

Pixmap LoadIcon(WScreen *scr, char *path, char *mask, int title_height);

void PlaceIcon(WScreen *scr, int *x_ret, int *y_ret, int head);

int calcIntersectionArea(int x1, int y1, int w1, int h1,
                         int x2, int y2, int w2, int h2);

void PlaceWindow(WWindow *wwin, int *x_ret, int *y_ret,
                 unsigned int width, unsigned int height);


void StartWindozeCycle(WWindow *wwin, XEvent *event, Bool next);

#ifdef USECPP
char *MakeCPPArgs(char *path);
#endif

char *StrConcatDot(char *a, char *b);

char *ExpandOptions(WScreen *scr, char *cmdline);

void ExecuteShellCommand(WScreen *scr, char *command);

void StartLogShell(WScreen *scr);


Bool IsDoubleClick(WScreen *scr, XEvent *event);

WWindow *NextToFocusAfter(WWindow *wwin);
WWindow *NextToFocusBefore(WWindow *wwin);

void SlideWindow(Window win, int from_x, int from_y, int to_x, int to_y);

char *ShrinkString(WMFont *font, char *string, int width);

char *FindImage(char *paths, char *file);

RImage*wGetImageForWindowName(WScreen *scr, char *winstance, char *wclass);

void ParseWindowName(WMPropList *value, char **winstance, char **wclass,
                     char *where);

void SendHelperMessage(WScreen *scr, char type, int workspace, char *msg);

char *GetShortcutString(char *text);

char *EscapeWM_CLASS(char *name, char *class);

void UnescapeWM_CLASS(char *str, char **name, char **class);

Bool UpdateDomainFile(WDDomain *domain);

#ifdef NUMLOCK_HACK
void wHackedGrabKey(int keycode, unsigned int modifiers,
                    Window grab_window, Bool owner_events, int pointer_mode,
                    int keyboard_mode);
#endif

void wHackedGrabButton(unsigned int button, unsigned int modifiers,
                       Window grab_window, Bool owner_events,
                       unsigned int event_mask, int pointer_mode,
                       int keyboard_mode, Window confine_to, Cursor cursor);


void ExecExitScript();

/****** I18N Wrapper for XFetchName,XGetIconName ******/

Bool wFetchName(Display *dpy, Window win, char **winname);
Bool wGetIconName(Display *dpy, Window win, char **iconname);

/* Free returned string it when done. (applies to the next 2 functions) */
char* GetCommandForWindow(Window win);
char* GetProgramNameForWindow(Window win);

Bool GetCommandForPid(int pid, char ***argv, int *argc);

#endif
