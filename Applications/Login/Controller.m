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

#import "Controller.h"
#import "UserSession.h"

#import <unistd.h>
#import <fcntl.h>
#import <sys/ioctl.h>

#ifdef __FreeBSD__
#import <sys/consio.h>  // for changing VT
#endif

#import <SystemKit/OSEDisplay.h>
#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSEMouse.h>

static NSString *PAMAuthenticationException = @"PAMAuthenticationException";
static NSString *PAMAccountExpiredException = @"PAMAccountExpiredException";
static NSString *PAMCredentialsException = @"PAMCredentialsException";
static NSString *PAMPermissionDeniedException = @"PAMPermissionDeniedException";
static NSString *PAMSessionOpeningException = @"PAMSessionOpeningException";

LoginExitCode panelExitCode;

//=============================================================================
// Manage user sessions
//=============================================================================
@implementation Controller (UserSession)

// This methods runs in session thread or with performSelectorOnMainThread.
// In the latter case modal mode works without correct buttons update.
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  UserSession *session = context;

  NSLog(@"KVO: changed path %@. Exit status: %li. Thread: %@", keyPath, session.exitStatus,
        [NSThread currentThread]);

  if ([session isKindOfClass:[UserSession class]] == NO) {
    NSLog(@"Session is not kind of class UserSession, skip it.");
    return;
  }

  if (session.isRunning != NO) {
    NSLog(@"Session still running, skip it.");
    return;
  }

  if (session.exitStatus == ShutdownExitCode) {
    panelExitCode = ShutdownExitCode;
    [self shutDown:self];
  } else if (session.exitStatus == RebootExitCode) {
    panelExitCode = RebootExitCode;
    [self restart:self];
  } else if (session.exitStatus != 0) {
    [self runAlertPanelForSession:session];
  } else {
    [self closeUserSession:session];
  }
}

- (void)openSessionForUser:(NSString *)user
{
  UserSession *session;

  if ([userSessions objectForKey:user]) {
    NSLog(@"Session for user '%@' already opened.", user);
    return;
  }

  session = [[UserSession alloc] initWithOwner:self name:user defaults:(NSDictionary *)prefs];
  [session readSessionScript];
  [session addObserver:self
            forKeyPath:@"isRunning"
               options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
               context:session];
  [userSessions setObject:session forKey:user];  // remember user session
  [session release];

  [self runUserSession:session];

  NSLog(@"(openSessionForUser:) session was STARTED!");
}

- (void)runUserSession:(UserSession *)session
{
  if (session.run_queue == NULL) {
    session.run_queue = dispatch_queue_create("ns.login.session", DISPATCH_QUEUE_CONCURRENT);
  }

  dispatch_async(session.run_queue, ^{
    NSLog(@"(runUserSesion:) Session Log - %@", session.sessionLog);

    [session launchSessionScript];
    // [session performSelectorOnMainThread:@selector(setRunning:)
    //                           withObject:[NSNumber numberWithBool:YES]
    //                        waitUntilDone:YES];
    // sleep(1);
    // [session performSelectorOnMainThread:@selector(setRunning:)
    //                           withObject:[NSNumber numberWithBool:NO]
    //                        waitUntilDone:YES];

    NSLog(@"(runUserSession:) session was FINISHED! Is running: %@",
          session.isRunning ? @"YES" : @"NO");
  });
}

- (void)closeUserSession:(UserSession *)session
{
  NSInteger exitStatus = session.exitStatus;

  NSLog(@"Session WILL close for user \'%@\' [%lu] exitStatus: %lu", session.userName,
        [session retainCount], exitStatus);

  if ([userSessions objectForKey:session.userName] == nil) {
    return;
  }

  [session removeObserver:self forKeyPath:@"isRunning"];

  // Do not close PAM session and show window if session aimed to be restarted.
  // Session will be restarted in GCD queue (openSessionForUser:)
  if (session.isRunning == NO) {
    [userSessions removeObjectForKey:session.userName];
    pam_end(PAM_handle, 0);

    // TODO: actually this doesn't make sense because no multiple session handling
    // implemented yet. Leave it for the future.
    if ([[userSessions allKeys] count] == 0) {
      if (exitStatus != ShutdownExitCode && exitStatus != RebootExitCode) {
        isWindowActive = YES;
        [self setWindowVisible:YES];
      }
    }
  } else {
    NSLog(@"closeUserSession: session still running - will not be closed.");
  }
}

- (void)runAlertPanelForSession:(UserSession *)session
{
  alert = [[NXTAlert alloc]
        initWithTitle:@"Login"
              message:@"Session finished with error.\n\n"
                       "Click \"Restart\" to return to Workspace, "
                       "click \"Quit\" to close your applications, "
                       "click \"Explain\" to get more information about session failure."
        defaultButton:@"Restart"
      alternateButton:@"Quit"
          otherButton:@"Explain"];

  [alert setButtonsTarget:self];
  [alert setButtonsAction:@selector(alertButtonPressed:)];
  alert.representedObject = session;

  NSLog(@"Console log for %@ - %@", session.userName, session.sessionLog);

  [alert show];
}

- (void)alertButtonPressed:(id)sender
{
  UserSession *session = alert.representedObject;
  NSInteger buttonTag = [sender tag];

  if (buttonTag == NSAlertDefaultReturn || buttonTag == NSAlertAlternateReturn) {
    [[alert panel] close];
    [alert release];
  }

  switch (buttonTag) {
    case NSAlertDefaultReturn:  // Restart
      [self runUserSession:session];
      break;
    case NSAlertAlternateReturn:  // Quit
      // At this point only applications with visible windows will be killed
      [self closeAllXClients];
      [self closeUserSession:session];
      break;
    case NSAlertOtherReturn:
      // NSLog(@"Alert Panel: show console.log contents.");
      [NSBundle loadNibNamed:@"ConsoleLog" owner:self];
      if (consoleLogView) {
        // NSLog(@"Adding accessory view to Alert Panel.");
        NSTextView *textView = [consoleLogView documentView];
        [textView setFont:[NSFont userFixedPitchFontOfSize:10.0]];
        [textView setString:[NSString stringWithContentsOfFile:session.sessionLog]];
        [alert setAccessoryView:consoleLogView];
        [sender setEnabled:NO];
      }
      return;
    default:
      NSLog(@"Alert Panel: user has made a strange choice!");
  }
}

@end

//=============================================================================
// X Window System
//=============================================================================
@implementation Controller (XWindowSystem)

static int catchXErrors(Display *dpy, XErrorEvent *event) { return 0; }

// --- General
- (void)initXApp
{
  GSDisplayServer *xServer = GSCurrentServer();

  xDisplay = [xServer serverDevice];
  xScreen = DefaultScreen(xDisplay);
  xRootWindow = RootWindow(xDisplay, xScreen);
  xPanelWindow = (Window)[xServer windowDevice:[window windowNumber]];
}

- (void)setRootWindowBackground
{
  XSetWindowAttributes winattrs;

  winattrs.cursor = XCreateFontCursor(xDisplay, XC_left_ptr);
  XChangeWindowAttributes(xDisplay, xRootWindow, CWCursor, &winattrs);

  [self.systemScreen setBackgroundColorRed:83.0 / 255.0 green:83.0 / 255.0 blue:116.0 / 255.0];
}

- (void)setWindowVisible:(BOOL)flag
{
  [self clearFields];
  if (flag) {
    [self setRootWindowBackground];
    [window center];
    [window makeKeyAndOrderFront:self];

    XSetInputFocus(xDisplay, xPanelWindow, RevertToPointerRoot, CurrentTime);
    XGrabKeyboard(xDisplay, xPanelWindow, False, GrabModeAsync, GrabModeAsync, CurrentTime);
  } else {
    XUngrabKeyboard(xDisplay, CurrentTime);
    [window orderOut:self];  // to prevent altert panels to show window
    XWithdrawWindow(xDisplay, xPanelWindow, xScreen);
  }
  XFlush(xDisplay);
}

- (void)closeAllXClients
{
  Window dummywindow;
  Window *children;
  unsigned int nchildren = 0;
  unsigned int i;
  XWindowAttributes attr;

  XSync(xDisplay, 0);
  XSetErrorHandler(catchXErrors);
  XQueryTree(xDisplay, xRootWindow, &dummywindow, &dummywindow, &children, &nchildren);

  for (i = 0; i < nchildren; i++) {
    if (XGetWindowAttributes(xDisplay, children[i], &attr) && (attr.map_state != IsUnmapped)) {
      // children[i] = XmuClientWindow(xDisplay, children[i]);
      XKillClient(xDisplay, children[i]);
      // XDestroyWindow(xDisplay, children[i]);
    } else {
      children[i] = 0;
    }
  }

  XFree((char *)children);

  XSync(xDisplay, 0);
  XSetErrorHandler(NULL);
}

//============================================================================
// OSEScreen events
//============================================================================
- (void)lidDidChange:(NSNotification *)aNotif
{
  OSEDisplay *builtinDisplay = nil;
  BOOL isLidClosed = NO;

  NSLog(@"lidDidChange: %@", aNotif.userInfo);

  if (aNotif.userInfo) {
    NSNumber *lidValue = aNotif.userInfo[@"LidIsClosed"];
    if (lidValue) {
      isLidClosed = [lidValue boolValue];
    }
  } else {
    isLidClosed = [self.systemScreen isLidClosed];
  }

  for (OSEDisplay *d in [self.systemScreen allDisplays]) {
    if ([d isBuiltin] != NO) {
      builtinDisplay = d;
      break;
    }
  }

  if (builtinDisplay) {
    if (isWindowActive != NO && [window isVisible]) {
      [self setWindowVisible:NO];
    }

    if (isLidClosed == NO && ![builtinDisplay isActive]) {
      NSLog(@"activating display %@", [builtinDisplay outputName]);
      [self.systemScreen activateDisplay:builtinDisplay];
    } else if (isLidClosed != NO && [builtinDisplay isActive]) {
      NSLog(@"DEactivating display %@", [builtinDisplay outputName]);
      [self.systemScreen deactivateDisplay:builtinDisplay];
    }

    NSLog(@"OSEScreen size: %.0f x %.0f", [self.systemScreen sizeInPixels].width,
          [self.systemScreen sizeInPixels].height);

    if (isWindowActive != NO && NSEqualSizes([self.systemScreen sizeInPixels], NSZeroSize) == NO) {
      [self setWindowVisible:YES];
    }
  }
}

// --- Busy cursor
- (void)setBusyCursor
{
  XcursorCursors *cursors;

  if (busy_cursor != NULL) {
    [self destroyBusyCursor];
  }

  cursors = XcursorLibraryLoadCursors(xDisplay, "watch");
  fprintf(stderr, "[Busy Cursor] loaded %i cursors\n", cursors->ncursor);
  busy_cursor = XcursorAnimateCreate(cursors);
  XcursorCursorsDestroy(cursors);

  busyTimer = [NSTimer timerWithTimeInterval:0.02
                                      target:self
                                    selector:@selector(animateBusyCursor:)
                                    userInfo:nil
                                     repeats:YES];
  // [self animateBusyCursor:nil];
  [busyTimer fire];
}

- (void)destroyBusyCursor
{
  Cursor arrow_cursor;

  if (busyTimer != nil && [busyTimer isKindOfClass:[NSTimer class]] && [busyTimer isValid]) {
    [busyTimer invalidate];
  }
  XcursorAnimateDestroy(busy_cursor);
  busy_cursor = NULL;

  arrow_cursor = XCreateFontCursor(xDisplay, XC_left_ptr);
  XDefineCursor(xDisplay, xRootWindow, arrow_cursor);
  XDefineCursor(xDisplay, xPanelWindow, arrow_cursor);
  XFreeCursor(xDisplay, arrow_cursor);
}

- (void)animateBusyCursor:(NSTimer *)timer
{
  Cursor xcursor = XcursorAnimateNext(busy_cursor);

  fprintf(stderr, "[Animate] cursor %i\n", busy_cursor->sequence);

  XDefineCursor(xDisplay, xRootWindow, xcursor);
  XDefineCursor(xDisplay, xPanelWindow, xcursor);

  XFlush(xDisplay);
}

@end

//=============================================================================
// Application preferences
//=============================================================================
@implementation Controller (Preferences)

- (NSString *)lastLoggedInUser
{
  if ([[prefs objectForKey:@"RememberLastLoggedInUser"] integerValue] == 1) {
    return [prefs objectForKey:@"LastLoggedInUser"];
  }

  return nil;
}

- (void)setLastLoggedInUser:(NSString *)username
{
  [prefs setObject:username == nil ? @"" : [NSString stringWithString:username]
            forKey:@"LastLoggedInUser"];
}

@end

//=============================================================================
// PAM operations
//=============================================================================
@implementation Controller (PAMAuth)

int ConversationFunction(int num_msg, const struct pam_message **msg, struct pam_response **resp,
                         void *appdata_ptr)
{
  if (num_msg != 1) {
    NSLog(@"PAM: 0 messages was sent to conversation function.");
    return -1;
  }

  // *resp = malloc(sizeof(struct pam_response));
  *resp = malloc(sizeof(struct pam_response));
  if (!*resp) {
    NSLog(@"PAM: out of memory, terminating");
    exit(0);
  } else {
    memset(*resp, 0, sizeof(struct pam_response));
  }

  (*resp)[0].resp = strdup([[[NSApp delegate] password] cString]);
  (*resp)[0].resp_retcode = 0;

  return PAM_SUCCESS;
}

- (BOOL)authenticateUser:(NSString *)user
{
  struct pam_conv conv;

  conv.conv = ConversationFunction;
  if (pam_start("login", [user cString], &conv, &PAM_handle) != PAM_SUCCESS) {
    NSLog(@"Failed to initialize PAM");
    return NO;
  }

  NS_DURING
  {
    [self authenticateWithHandle:PAM_handle];
    [self establishAccountManagementWithHandle:PAM_handle];
    [self establishCredentialsWithHandle:PAM_handle];
    [self setLastLoggedInUser:user];
    [self openSessionWithHandle:PAM_handle];
    return YES;
  }
  NS_HANDLER
  {
    pam_end(PAM_handle, 0);
    return NO;
  }
  NS_ENDHANDLER
}

// It is needed by ConversationFunction()
- (NSString *)password
{
  return [password stringValue];
}

- (void)authenticateWithHandle:(pam_handle_t *)handle
{
  int ret;

  if ((ret = pam_authenticate(handle, 0)) != PAM_SUCCESS) {
    NSLog(@"PAM error: %s", pam_strerror(handle, ret));
    [NSException raise:PAMAuthenticationException format:nil];
  }
}

- (void)establishAccountManagementWithHandle:(pam_handle_t *)handle
{
  switch (pam_acct_mgmt(handle, 0)) {
    case PAM_ACCT_EXPIRED:
      NSLog(@"PAM: Account expired.");
      [NSException raise:PAMAccountExpiredException format:nil];
      break;
    case PAM_AUTH_ERR:
      NSLog(@"PAM: Error.");
      [NSException raise:PAMAuthenticationException format:nil];
      break;
    case PAM_PERM_DENIED:
      NSLog(@"PAM: Permission denied.");
      [NSException raise:PAMPermissionDeniedException format:nil];
      break;
    case PAM_USER_UNKNOWN:  // hide the fact that the user is unknown
      NSLog(@"PAM: User unknown.");
      [NSException raise:PAMAuthenticationException format:nil];
      break;
    default:
      break;
  }
}

- (void)establishCredentialsWithHandle:(pam_handle_t *)handle
{
  if (pam_setcred(handle, PAM_ESTABLISH_CRED) != PAM_SUCCESS) {
    NSLog(@"PAM: Failed to establish PAM credetials.");
    [NSException raise:PAMCredentialsException format:nil];
  }
}

- (void)openSessionWithHandle:(pam_handle_t *)handle
{
  if (pam_open_session(handle, 0) != PAM_SUCCESS) {
    NSLog(@"PAM: Failed to open PAM session.");
    [NSException raise:PAMSessionOpeningException format:nil];
  }
}

@end

@implementation Controller

- (void)awakeFromNib
{
  NSRect rect;
  NSString *user;

  if (userSessions) {
    // Already called - may be called by alert panel log view
    return;
  }

  userSessions = [[NSMutableDictionary alloc] init];

  NSLog(@"awakeFromNib");

  // Adjust window size to background image size
  rect = [window frame];
  rect.size = [[panelImageView image] size];
  [window setFrame:rect display:NO];

  [shutDownBtn setRefusesFirstResponder:YES];
  [restartBtn setRefusesFirstResponder:YES];
  [fieldsImage setRefusesFirstResponder:YES];
  [fieldsLabelImage setRefusesFirstResponder:YES];
  [panelImageView setRefusesFirstResponder:YES];

  // Open preferences
  prefs = [[OSEDefaults alloc] initWithSystemDefaults];

  [hostnameField retain];
  [self displayHostname];

  user = [self lastLoggedInUser];
  if (user && [user length] > 0) {
    [userName setStringValue:user];
  }

  [password setEchosBullets:NO];

  panelExitCode = 0;
  NSLog(@"awakeFromNib: end");
}

- (void)displayHostname
{
  char hostname[256], displayname[256];
  int namelen = 256, index = 0;
  NSString *host_name = nil;

  // Initialize hostname
  gethostname(hostname, namelen);
  for (index = 0; index < 256 && hostname[index] != '.'; index++) {
    displayname[index] = hostname[index];
  }
  displayname[index] = 0;
  host_name = [NSString stringWithCString:displayname];
  [hostnameField setStringValue:host_name];

  if ([[prefs objectForKey:@"DisplayHostName"] integerValue] == 0) {
    if ([hostnameField superview] != nil) {
      [hostnameField removeFromSuperview];
    }
  } else if ([hostnameField superview] == nil) {
    [panelImageView addSubview:hostnameField];
  }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
  NSLog(@"appDidFinishLaunch: start");

  // Initialize X resources
  [self initXApp];

   // Screen
  _systemScreen = [[OSEScreen sharedScreen] retain];

  NSLog(@"appDidFinishLaunch: before showWindow");
  // Show login window
  [self setWindowVisible:YES];
  isWindowActive = YES;

  // Turn light on
  // for (OSEDisplay *display in [[OSEScreen sharedScreen] activeDisplays])
  //   {
  //     [display fadeToNormal:1.0];
  //   }
  // NSConnection *conn = [NSConnection defaultConnection];
  // [conn registerName:@"loginwindow"];

  // Laptop lid events handling
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(lidDidChange:)
                                               name:OSEPowerLidDidChangeNotification
                                             object:_systemScreen.systemPower];

  // Defaults
  [[NSDistributedNotificationCenter notificationCenterForType:GSPublicNotificationCenterType]
      addObserver:self
         selector:@selector(defaultsDidChange:)
             name:@"LoginDefaultsDidChangeNotification"
           object:@"Preferences"];
  NSLog(@"appDidFinishLaunch: end");
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  NSLog(@"ApplicationShouldTerminate");
  [_systemScreen release];
  return NSTerminateNow;
}

- (void)defaultsDidChange:(NSNotification *)notif
{
  [prefs reload];
  [self displayHostname];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  // NSLog(@"Control did end editing.");
}

- (void)authenticate:(id)sender
{
  NSString *user = [[NSString alloc] initWithString:[userName stringValue]];

  // [self setBusyCursor];

  NSLog(@"[Controller authenticate:] userName: %@", user);

  if (sender == userName) {
    if ([user isEqualToString:@"console"]) {
#ifdef __FreeBSD__
      int fd = open("/dev/ttyv0", O_RDONLY, 0);

      NSLog(@"Switch to console %i", fd);
      ioctl(fd, VT_ACTIVATE, 1);
      ioctl(fd, VT_WAITACTIVE, 1);
      NSLog(@"Switch to console %i completed!", fd);
      close(fd);
#endif
      [self clearFields];
      return;
    } else if ([user isEqualToString:@"quit"]) {
      NSLog(@"Application will be stopped");
      panelExitCode = QuitExitCode;
      [NSApp terminate:self];  // Go out of run loop
      return;
    } else if ([user isEqualToString:@"terminate"]) {
      NSLog(@"Application will quit");
      panelExitCode = QuitExitCode;
      [NSApp terminate:self];  // Equivalent to "Quit" menu item
      return;
    } else if ([user isEqualToString:@"shake"]) {  // for testing
      [window shakePanel:xPanelWindow onDisplay:xDisplay];
      return;
    } else {
      [window makeFirstResponder:password];
      return;
    }
  }

  if ([self authenticateUser:user] == YES) {
    [window shrinkPanel:xPanelWindow onDisplay:xDisplay];
    [self setWindowVisible:NO];
    isWindowActive = NO;
    [self openSessionForUser:user];
  } else {
    [window shakePanel:xPanelWindow onDisplay:xDisplay];
  }

  [self clearFields];
  // [self destroyBusyCursor];
  [user release];
}

- (void)restart:sender
{
  NSInteger alertResult;

  NSLog(@"[Controller restart] initial exit code: %d", panelExitCode);

  // No need to ask user if exit code already defined.
  if (panelExitCode == 0) {
    alertResult = NXTRunAlertPanel(_(@"Restart"), _(@"Do you really want to restart the computer?"),
                                   _(@"Restart"), _(@"Cancel"), nil);

    if (alertResult == NSAlertDefaultReturn) {
      panelExitCode = RebootExitCode;
    }
  }

  if (panelExitCode == RebootExitCode) {
    NSLog(@"[Controller] restart: application will be stopped with exit code: %d", panelExitCode);
    [NSApp stop:self];  // Go out of run loop
  }
}

- (void)shutDown:sender
{
  NSInteger alertResult;

  NSLog(@"[Controller shutDown] initial exit code: %d", panelExitCode);

  // Ask user to verify his choice
  if (panelExitCode == 0) {
    alertResult = NXTRunAlertPanel(_(@"Power"), _(@"Do you really want to turn off the computer?"),
                                   _(@"Turn it off"), _(@"Cancel"), nil);

    if (alertResult == NSAlertDefaultReturn) {
      panelExitCode = ShutdownExitCode;
    }
  }

  if (panelExitCode == ShutdownExitCode) {
    NSLog(@"[Controller] shutDown: application will be stopped with exit code: %d", panelExitCode);
    [NSApp stop:self];  // Go out of run loop
  }
}

- (void)clearFields
{
  NSString *user = [self lastLoggedInUser];

  [password setStringValue:@""];

  if (user && [user length] > 0) {
    [userName setStringValue:user];
    [window makeFirstResponder:password];
  } else {
    [userName setStringValue:@""];
    [window makeFirstResponder:userName];
  }
}

@end
