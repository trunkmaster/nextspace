/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Copyright (C) 2014-2019 Sergii Stoian
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

#import <security/pam_appl.h>
#import <X11/Xlib.h>
#import <X11/cursorfont.h>
#import <X11/Xcursor/Xcursor.h>

#import <GNUstepGUI/GSDisplayServer.h>
#import <AppKit/AppKit.h>

#import <DesktopKit/NXTDefaults.h>
#import <SystemKit/OSEScreen.h>

#import "LoginWindow.h"

// 1 - Catchall for general errors
// 2 - Misuse of shell builtins (according to Bash documentation)
// 10 - exit(0)
// 11 - shutdown
// 12 - reboot
enum LoginExitCode {
  QuitExitCode = 10,
  ShutdownExitCode = 11,
  RebootExitCode = 12,
  UpdateExitCode = 13
};
int panelExitCode;

@class UserSession;

@interface Controller : NSObject
{
  IBOutlet LoginWindow *window;
  IBOutlet id          hostnameField;
  IBOutlet id          fieldsImage;
  IBOutlet id          fieldsLabelImage;
  IBOutlet id          panelImageView;
  IBOutlet id          userName;
  IBOutlet id          password;
  IBOutlet id          shutDownBtn;
  IBOutlet id          restartBtn;

  // X resources
  Display              *xDisplay;
  Window               xRootWindow;
  int                  xScreen;
  Window               xPanelWindow;

  OSEScreen	       *screen;

  // Preferences
  NXTDefaults           *prefs;

  // User sessions
  NSArray              *mainThreadPorts;
  NSMutableDictionary  *userSessions;

  pam_handle_t         *PAM_handle;

  // Busy cursor
  XcursorAnimate       *busy_cursor;
  NSTimer              *busyTimer;
}

- (void)displayHostname;
- (void)clearFields;

- (void)authenticate:(id)sender;
- (void)restart:sender;
- (void)shutDown:sender;

@end

@interface Controller (UserSession)

- (void)openSessionForUser:(NSString *)userName;
- (void)userSessionWillClose:(UserSession *)session;

@end

@interface Controller (XWindowSystem)

- (void)setRootWindowBackground;
- (void)setWindowVisible:(BOOL)flag;
- (void)closeAllXClients;

- (void)setBusyCursor;
- (void)destroyBusyCursor;
- (void)animateBusyCursor:(NSTimer *)timer;

@end

@interface Controller (Preferences)

- (NSString*)lastLoggedInUser;
- (void)setLastLoggedInUser:(NSString *)username;

@end

@interface Controller (PAMAuth)

- (BOOL)authenticateUser:(NSString *)user;
- (NSString *)password;
- (void)authenticateWithHandle:(pam_handle_t *)handle;
- (void)establishAccountManagementWithHandle:(pam_handle_t *)handle;
- (void)establishCredentialsWithHandle:(pam_handle_t *)handle;
- (void)openSessionWithHandle:(pam_handle_t *)handle;

@end

