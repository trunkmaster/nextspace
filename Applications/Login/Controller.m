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
#import <sys/consio.h> // for changing VT
#endif

#import <dispatch/dispatch.h>

#import <SystemKit/OSEDisplay.h>
#import <SystemKit/OSEMouse.h>
#import <DesktopKit/NXTAlert.h>

static NSString *PAMAuthenticationException = @"PAMAuthenticationException";
static NSString *PAMAccountExpiredException = @"PAMAccountExpiredException";
static NSString *PAMCredentialsException = @"PAMCredentialsException";
static NSString *PAMPermissionDeniedException = @"PAMPermissionDeniedException";
static NSString *PAMSessionOpeningException = @"PAMSessionOpeningException";

// ============================================================================
// ==== Internal functions
// ============================================================================

int ConversationFunction(int num_msg,
			 const struct pam_message ** msg,
			 struct pam_response ** resp,
			 void * appdata_ptr);

static int catchXErrors(Display* dpy, XErrorEvent* event);

int ConversationFunction(int num_msg, 
    			 const struct pam_message ** msg, 
    			 struct pam_response ** resp, 
    			 void * appdata_ptr)
{
  if (num_msg != 1) {
    NSLog(@"PAM error");
    return -1;
  }

  *resp = malloc(sizeof(struct pam_response));
  (*resp)[0].resp = strdup([[[NSApp delegate] password] cString]);
  (*resp)[0].resp_retcode = 0;

  return PAM_SUCCESS;
}

static int catchXErrors(Display* dpy, XErrorEvent* event)
{
  return 0;
}

void *alloc(int size)
{
  void *tmp;

  tmp = malloc(size);
  if (!tmp) {
    NSLog(@"out of memory, terminating");
    exit(0);
  }
  else {
    memset(tmp, 0, size);
    }

  return tmp;
}

//=============================================================================
// Manage user sessions
//=============================================================================
@implementation Controller (UserSession)

- (void)openSessionForUser:(NSString *)user
{
  UserSession *aSession;

  aSession = [[UserSession alloc] initWithOwner:self
                                           name:user
                                       defaults:(NSDictionary *)prefs];
  [aSession readSessionScript];
  aSession.isRunning = YES;
  [userSessions setObject:aSession forKey:user]; // remember user session
  [aSession release];

  // --- GCD code ---
  dispatch_queue_t gq = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
  dispatch_async(gq, ^{
      @autoreleasepool {
        while (aSession.isRunning != NO) {
          [aSession launchSessionScript];
          [self performSelectorOnMainThread:@selector(userSessionWillClose:)
                                 withObject:aSession
                              waitUntilDone:YES];
        }
        NSLog(@"[GCD] panelExitCode: %d", panelExitCode);
        if (panelExitCode == ShutdownExitCode) {
          [self performSelectorOnMainThread:@selector(shutDown:)
                                 withObject:self
                              waitUntilDone:NO];
        }
        else if (panelExitCode == RebootExitCode) {
          [self performSelectorOnMainThread:@selector(restart:)
                                 withObject:self
                              waitUntilDone:NO];
        }
      }
    });
  // ----------------
}

- (void)userSessionWillClose:(UserSession *)session
{
  NSString  *user = session.userName;
  NSInteger choice;
  NSInteger sessionExitStatus;

  NSLog(@"Session WILL close for user \'%@\' [%lu] exitStatus: %lu",
        user, [session retainCount], session.exitStatus);
  
  if ([userSessions objectForKey:user] == nil) {
    return;
  }

  session.isRunning = NO;
  sessionExitStatus = session.exitStatus;

  if (sessionExitStatus == ShutdownExitCode) {
    panelExitCode = ShutdownExitCode;
    // [self setPanelExitCode:ShutdownExitCode];
  }
  else if (sessionExitStatus != 0 &&
           sessionExitStatus != ShutdownExitCode &&
           sessionExitStatus != RebootExitCode) {
    choice = NXTRunAlertPanel(@"Login", @"Session finished with error. "
                              "See console.log for details.\n"
                              "Do you want to restart or cleanup session?\n"
                              "Note: \"Cleanup\" will kill all running applications.",
                              @"Restart", @"Cleanup", nil);
    if (choice == NSAlertAlternateReturn) {
      [self closeAllXClients];
    }
    else {
      session.isRunning = YES;
    }
  }

  // Do not close PAM session and show window if session aimed to be restarted.
  // Session will be restarted in GCD queue (openSessionForUser:)
  if (session.isRunning == NO) {
    [userSessions removeObjectForKey:user];
    pam_end(PAM_handle, 0);
  
    // TODO: actually this doesn't make sense because no multuple session handling
    // implemented yet. Leave it for the future.
    if ([[userSessions allKeys] count] == 0) {
      if (sessionExitStatus != ShutdownExitCode) {
        [self setWindowVisible:YES];
      }
    }
  }
}

@end

//=============================================================================
// X Window System category
//=============================================================================
@implementation Controller (XWindowSystem)

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
  
  XSetWindowBackground(xDisplay, xRootWindow, 5460853L);
  XClearWindow(xDisplay, xRootWindow);
  XSync(xDisplay, false);
}

- (void)setWindowVisible:(BOOL)flag
{
  [self clearFields];
  if (flag) {
    [self setRootWindowBackground];
    [window center];
    [window makeKeyAndOrderFront:self];

    XSetInputFocus(xDisplay, xPanelWindow, RevertToPointerRoot, 
                   CurrentTime);
    XGrabKeyboard(xDisplay, xPanelWindow, False, GrabModeAsync, 
                  GrabModeAsync, CurrentTime);
  }
  else {
    XUngrabKeyboard(xDisplay, CurrentTime);
    [window orderOut:self]; // to prevent altert panels to show window
    XWithdrawWindow(xDisplay, xPanelWindow, xScreen);
  }
  XFlush(xDisplay);
}

- (void)closeAllXClients
{
  Window            dummywindow;
  Window*           children;
  unsigned int      nchildren = 0;
  unsigned int      i;
  XWindowAttributes attr;

  XSync(xDisplay, 0);
  XSetErrorHandler(catchXErrors);
  XQueryTree(xDisplay, xRootWindow, &dummywindow, &dummywindow, 
	     &children, &nchildren);

  for (i = 0; i < nchildren; i++) {
    if (XGetWindowAttributes(xDisplay, children[i], &attr)
        && (attr.map_state != IsUnmapped)) {
      // children[i] = XmuClientWindow(xDisplay, children[i]);
      XKillClient(xDisplay, children[i]);
      // XDestroyWindow(xDisplay, children[i]);
    }
    else {
      children[i] = 0;
    }
  }

  XFree((char *)children);

  XSync(xDisplay, 0);
  XSetErrorHandler(NULL);
}

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
  
  if (busyTimer != nil &&
      [busyTimer isKindOfClass:[NSTimer class]] &&
      [busyTimer isValid]) {
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
  switch (pam_acct_mgmt(handle, 0))
    {
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
    case PAM_USER_UNKNOWN: // hide the fact that the user is unknown
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
  NSRect   rect;
  NSString *user;

  NSLog(@"Login: awakeFromNib");

  // Adjust window size to background image size
  rect = [window frame];
  rect.size = [[panelImageView image] size];
  [window setFrame:rect display:NO];
  // [self center];
  
  [shutDownBtn setRefusesFirstResponder:YES];
  [restartBtn setRefusesFirstResponder:YES];
  [fieldsImage setRefusesFirstResponder:YES];
  [fieldsLabelImage setRefusesFirstResponder:YES];
  [panelImageView setRefusesFirstResponder:YES];

  // Open preferences
  prefs = [[NXTDefaults alloc] initWithSystemDefaults];

  [hostnameField retain];
  [self displayHostname];

  user = [self lastLoggedInUser];
  if (user && [user length] > 0) {
    [userName setStringValue:user];
  }
            
  userSessions = [[NSMutableDictionary alloc] init];

  panelExitCode = 0;
}

- (void)displayHostname
{
  char     hostname[256], displayname[256];
  int      namelen = 256, index = 0;
  NSString *host_name = nil;

  // Initialize hostname
  gethostname( hostname, namelen );
  for(index = 0; index < 256 && hostname[index] != '.'; index++) {
    displayname[index] = hostname[index];
  }
  displayname[index] = 0;
  host_name = [NSString stringWithCString:displayname];
  [hostnameField setStringValue:host_name];

  if ([[prefs objectForKey:@"DisplayHostName"] integerValue] == 0) {
    if ([hostnameField superview] != nil) {
      [hostnameField removeFromSuperview];
    }
  }
  else if ([hostnameField superview] == nil) {
    [panelImageView addSubview:hostnameField];
  }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
  NSLog(@"appDidFinishLaunch: start");

  // Initialize X resources
  [self initXApp];

  NSLog(@"appDidFinishLaunch: before showWindow");
  // Show login window
  [self setWindowVisible:YES];
  NSLog(@"appDidFinishLaunch: end");

  // Turn light on
  // for (OSEDisplay *display in [[OSEScreen sharedScreen] activeDisplays])
  //   {
  //     [display fadeToNormal:1.0];
  //   }
  // NSConnection *conn = [NSConnection defaultConnection];
  // [conn registerName:@"loginwindow"];

  [[NSDistributedNotificationCenter
     notificationCenterForType:GSPublicNotificationCenterType]
    addObserver:self
       selector:@selector(defaultsDidChange:)
           name:@"LoginDefaultsDidChangeNotification"
         object:@"Preferences"];
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
    }
    else if ([user isEqualToString:@"quit"]) {
      NSLog(@"Application will be stopped");
      panelExitCode = QuitExitCode;
      [NSApp stop:self]; // Go out of run loop
      return;
    }
    else if ([user isEqualToString:@"terminate"]) {
      NSLog(@"Application will quit");
      [NSApp terminate:self]; // Equivalent to "Quit" menu item
      return;
    }
    else {
      [window makeFirstResponder:password];
      return;
    }
  }

  if ([self authenticateUser:user] == YES) {
    [window shrinkPanel:xPanelWindow onDisplay:xDisplay];
    [self setWindowVisible:NO];
    [self openSessionForUser:user];
  }
  else {
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
    alertResult = NXTRunAlertPanel(_(@"Restart"),
                                   _(@"Do you really want to restart the computer?"),
                                   _(@"Restart"), _(@"Cancel"), nil);
  
    if (alertResult == NSAlertDefaultReturn) {
      panelExitCode = RebootExitCode;
    }
  }

  if (panelExitCode == RebootExitCode) {
    NSLog(@"[Controller] restart: application will be stopped with exit code: %d",
          panelExitCode);
    [NSApp stop:self]; // Go out of run loop
  }
}

- (void)shutDown:sender
{
  NSInteger alertResult;

  NSLog(@"[Controller shutDown] initial exit code: %d", panelExitCode);
  
  // Ask user to verify his choice
  if (panelExitCode == 0) {
    alertResult = NXTRunAlertPanel(_(@"Power"),
                                   _(@"Do you really want to turn off the computer?"),
                                   _(@"Turn it off"), _(@"Cancel"), nil);
  
    if (alertResult == NSAlertDefaultReturn) {
      panelExitCode = ShutdownExitCode;
    }
  }
  
  if (panelExitCode == ShutdownExitCode) {
    NSLog(@"[Controller] shutDown: application will be stopped with exit code: %d",
          panelExitCode);
    [NSApp stop:self]; // Go out of run loop
  }
}

- (void)clearFields
{
  NSString *user = [self lastLoggedInUser];

  [password setStringValue:@""];
  
  if (user && [user length] > 0) {  
    [userName setStringValue:user];
    [window makeFirstResponder:password];
  }
  else {
    [userName setStringValue:@""];
    [window makeFirstResponder:userName];
  }
}

@end

