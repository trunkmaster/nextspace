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

//#import <X11/Xatom.h>
//#import <X11/Xutil.h>
//#import <X11/Xmu/WinUtil.h>

#import <GNUstepGUI/GSDisplayServer.h>
#import <AppKit/AppKit.h>

#import <DesktopKit/NXTDefaults.h>
#import <SystemKit/OSEScreen.h>

#import "LoginWindow.h"

extern NSString *SessionDidCloseNotification;

@class UserSession;

@interface Controller : NSObject
{
  IBOutlet LoginWindow *window;
  IBOutlet id          fieldsImage;
  IBOutlet id          fieldsLabelImage;
  IBOutlet id          panelImageView;
  IBOutlet id          userName;
  IBOutlet id          password;
  IBOutlet id          shutDownBtn;
  IBOutlet id          restartBtn;
  IBOutlet id          quitLabel;

  // X resources
  GSDisplayServer      *xServer;
  Display              *xDisplay;
  Window               xRootWindow;
  Window               xPanelWindow;

  OSEScreen	       *screen;

  // Preferences
  NXTDefaults           *prefs;

  // User sessions
  NSArray              *mainThreadPorts;
  NSMutableDictionary  *userSessions;

  pam_handle_t         *PAM_handle;
}

- (BOOL)authenticateUser:(NSString *)user;

- (void)authenticate:(id)sender;
- (void)restart:sender;
- (void)shutDown:sender;
- (void)clearFields;
- (void)prepareForQuit;

- (NSString *)password;
- (NSWindow *)window;

@end

@interface Controller (UserSession)

- (void)openSessionForUser:(NSString *)userName;
- (void)launchUserSession:(UserSession *)session;
- (oneway void)userSessionWillClose:(UserSession *)session;
- (void)showSessionMessage:(NSString *)message;

@end

@interface Controller (XWindowSystem)

- (void)setRootWindowBackground;
- (void)setWindowVisible:(BOOL)flag;
- (void)hideWindow;
- (void)showWindow;
- (void)closeAllXClients;

@end

@interface Controller (Preferences)

- (void)openLoginPreferences;
- (NSString*)shutdownCommand;
- (NSString*)rebootCommand;
- (NSString*)lastLoggedInUser;
- (void)setLastLoggedInUser:(NSString *)username;

@end

@interface Controller (PAMAuth)

- (void)authenticateWithHandle:(pam_handle_t *)handle;
- (void)establishAccountManagementWithHandle:(pam_handle_t *)handle;
- (void)establishCredentialsWithHandle:(pam_handle_t *)handle;
- (void)openSessionWithHandle:(pam_handle_t *)handle;

@end

