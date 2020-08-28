/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2018 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

//
// This header is for Window Manager(X11) and Workspace(GNUstep) integration
//

#ifdef NEXTSPACE

//-----------------------------------------------------------------------------
// Common part
//-----------------------------------------------------------------------------
#include <dispatch/dispatch.h>
dispatch_queue_t workspace_q;

enum {
      WSLogoutOnQuit = 0,
      WSPowerOffOnQuit = 11 // ShutdownExitCode in Login application
};
int ws_quit_code;

//-----------------------------------------------------------------------------
// Visible in Workspace only
//-----------------------------------------------------------------------------
#ifdef __Foundation_h_GNUSTEP_BASE_INCLUDE

#undef _

#include <wraster.h>

#include <screen.h>
#include <window.h>
#include <event.h>
#include <dock.h>
#include <actions.h> // wArrangeIcons()
#include <application.h>
#include <appicon.h>
#include <shutdown.h> // Shutdown(), WSxxxMode
#include <client.h>
#include <wmspec.h>
// Appicons placement
#include <stacking.h>
#include <placement.h>
#include <xrandr.h>

#undef _
#define _(X) [GS_LOCALISATION_BUNDLE localizedStringForKey: (X) value: @"" table: nil]

BOOL xIsWindowServerReady(void);
BOOL xIsWindowManagerAlreadyRunning(void);

//-----------------------------------------------------------------------------
// Calls related to internals of Window Manager.
// 'WM' prefix is a call direction 'to WindowManager'
//-----------------------------------------------------------------------------

void WMInitializeWindowMaker(int argc, char **argv);
void WMSetupFrameOffsetProperty();
void WMSetDockAppiconState(int index_in_dock, int launching);
// Disable some signal handling inside WindowMaker code.
void WMSetupSignalHandling(void);

// --- Logout/PowerOff related activities
void WMWipeDesktop(WScreen * scr);
void WMShutdown(WShutdownMode mode);

// --- Defaults
NSString *WMDefaultsPath(void);
  
// --- Icon Yard
void WMIconYardShowIcons(WScreen *screen);
void WMIconYardHideIcons(WScreen *screen);

// --- Dock
void WMDockInit(void);
void WMDockShowIcons(WDock *dock);
void WMDockHideIcons(WDock *dock);
void WMDockUncollapse(WDock *dock);
void WMDockCollapse(WDock *dock);

// - Should be called from already existing @autoreleasepool
NSString     *WMDockStatePath(void);
NSDictionary *WMDockState(void);
void         WMDockStateSave(void);
NSArray      *WMDockStateApps(void);
void         WMDockAutoLaunch(WDock *dock);

// Appicons getters/setters of on-screen Dock
WAppIcon  **launchingIcons;
NSInteger WMDockAppsCount(void);
NSString  *WMDockAppName(int position);
NSImage   *WMDockAppImage(int position);
void      WMSetDockAppImage(NSString *path, int position, BOOL saved);
BOOL      WMIsDockAppAutolaunch(int position);
void      WMSetDockAppAutolaunch(int position, BOOL autolaunch);
BOOL      WMIsDockAppLocked(int position);
void      WMSetDockAppLocked(int position, BOOL lock);
NSString  *WMDockAppCommand(int position);
void      WMSetDockAppCommand(int position, const char *command);
NSString  *WMDockAppPasteCommand(int position);
void      WMSetDockAppPasteCommand(int postion, const char *command);
NSString  *WMDockAppDndCommand(int position);
void      WMSetDockAppDndCommand(int position, const char *command);

WAppIcon *WMCreateLaunchingIcon(NSString *wmName,
                                 NSString *launchPath,
                                 NSImage *anImage,
                                 NSPoint sourcePoint,
                                 NSString *imagePath);
void WMFinishLaunchingIcon(WAppIcon *appIcon);
void WMDestroyLaunchingIcon(WAppIcon *appIcon);
// - End of functions which require existing @autorelease pool

// --- Windows and applications
NSString *WMWindowState(NSWindow *nsWindow);
NSArray *WMNotDockedAppList(void);
BOOL WMIsAppRunning(NSString *appName);
pid_t WMExecuteCommand(NSString *command);

#endif //__Foundation_h_GNUSTEP_BASE_INCLUDE

//-----------------------------------------------------------------------------
// Visible in Window Manager and Workspace
// Workspace callbacks for use inside Window Manager.
//-----------------------------------------------------------------------------

// --- Dock
int WSDockMaxIcons(WScreen *scr);
int WSDockLevel();
void WSSetDockLevel(int level);
void WSDockContentDidChange(WDock *dock);

// --- Application icons
WAppIcon *WSLaunchingIconForApplication(WApplication *wapp);
WAppIcon *WSLaunchingIconForCommand(char *command);

char *WSSaveRasterImageAsTIFF(RImage *r_image, char *file_path);
  
// --- Applications creation and destroying
void WSApplicationDidCreate(WApplication *wapp, WWindow *wwin);
void WSApplicationDidAddWindow(WApplication *wapp, WWindow *wwin);
void WSApplicationDidDestroy(WApplication *wapp);
void WSApplicationDidCloseWindow(WWindow *wwin);

// --- XRandR
void WSUpdateScreenInfo(WScreen *scr);
void WSUpdateScreenParameters(void);

// --- Workspaces
void WSActivateApplication(WScreen *scr, char *app_name);
void WSActivateWorkspaceApp(WScreen *scr);
void WSWorkspaceDidChange(WScreen *scr, int workspace, WWindow *focused_window);

// --- Layout badge in Workspace appicon
void WSKeyboardGroupDidChange(int group);

// -- Alerts, messages and sounds
int WSRunAlertPanel(char *title, char *message,
                     char *defaultButton,
                     char *alternateButton,
                     char *otherButton);
void WSRingBell(WWindow *wwin);
void WSMessage(char *fmt, ...);
#define wmessage(fmt, args...) WSMessage(fmt, ## args)

#endif //NEXTSPACE
