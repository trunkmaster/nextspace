/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2018-2021 Sergii Stoian
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

//-----------------------------------------------------------------------------
// Common part
//-----------------------------------------------------------------------------
#include <dispatch/dispatch.h>
#include <CoreFoundation/CFRunLoop.h>
extern dispatch_queue_t workspace_q;
extern CFRunLoopRef wm_runloop;

typedef enum WorkspaceExitCode {
  WSLogoutOnQuit = 0,     // normal application quit
  WSPowerOffOnQuit = 129  // ShutdownExitCode in Login/Controller.h
} WorkspaceExitCode;
extern WorkspaceExitCode ws_quit_code;

//-----------------------------------------------------------------------------
// Visible in Workspace only
//-----------------------------------------------------------------------------
#ifdef __OBJC__

#include <wraster.h>

#include <WM/core/log_utils.h>

#include <WM/screen.h>
#include <WM/dock.h>
#include <WM/xrandr.h>
#include <WM/iconyard.h>
#include <WM/defaults.h>
#include <WM/event.h>
#include <WM/actions.h>
#include <WM/startup.h>
#include <WM/shutdown.h>
#include <WM/misc.h>
#include <WM/wmspec.h>

#undef _
#define _(X) [GS_LOCALISATION_BUNDLE localizedStringForKey:(X) value:@"" table:nil]

@class NSImage;
NSImage *WSImageForRasterImage(RImage *r_image);

#endif  //__OBJC__

//-----------------------------------------------------------------------------
// Visible in Window Manager and Workspace
// Workspace callbacks for use inside Window Manager.
//-----------------------------------------------------------------------------

RImage *WSLoadRasterImage(const char *file_path);

char *WSSaveRasterImageAsTIFF(RImage *r_image, char *file_path);

// --- XRandR
void WSUpdateScreenInfo(WScreen *scr);
void WSUpdateScreenParameters(void);

// --- Workspaces
void WSActivateApplication(WScreen *scr, char *app_name);
void WSActivateWorkspaceApp(WScreen *scr);

// -- Alerts, messages and sounds
int WSRunAlertPanel(char *title, char *message, char *defaultButton, char *alternateButton,
                    char *otherButton);
void WSRingBell(WWindow *wwin);
void WSMessage(char *fmt, ...);
// #define WMLogInfo(fmt, args...) WSMessage(fmt, ## args)
