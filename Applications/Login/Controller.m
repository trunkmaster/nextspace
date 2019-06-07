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

static NSString
  * AuthenticationException = @"AuthenticationException",
//  * AccountRequiresResetupException = @"AccountRequiredResetupException",
  * AccountExpiredException = @"AccountExpiredException",
  * CredentialsException = @"CredentialsException",
  * PermissionDeniedException = @"PermissionDeniedException",
  * SessionOpeningException = @"SessionOpeningException";

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
  if (num_msg != 1)
    {
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
  if (!tmp)
    {
      NSLog(@"out of memory, terminating");
      exit(0);
    }
  else
    {
      memset(tmp, 0, size);
    }

  return tmp;
}

//=============================================================================
// Manage user sessions
//=============================================================================
@implementation Controller (UserSession)

- (id)defaultsForKey:(NSString *)key forUser:(NSString *)user
{
  NSString	*pathFormat = @"%@/Library/Preferences/.NextSpace/Login";
  NSString	*homeDir = NSHomeDirectoryForUser(user);
  NSString	*defsPath;
  NSDictionary	*defs;
  
  defsPath = [NSString stringWithFormat:pathFormat, homeDir];
  defs = [NSDictionary dictionaryWithContentsOfFile:defsPath];

  return [defs objectForKey:key];
}

- (NSArray *)sessionScriptForUser:(NSString *)user
{
  NSString		*homeDir;
  NSFileManager		*fm = [NSFileManager defaultManager];
  NSString		*path = nil;
  NSArray		*userSessionCommand = nil, *uss;
  NSMutableArray	*sessionScript = nil;
  NSString		*hook;

  sessionScript = [NSMutableArray new];
  homeDir = NSHomeDirectoryForUser(user);
    
  // Logout hook
  hook = [self defaultsForKey:@"LoginHook" forUser:user];
  if (hook != nil) [sessionScript addObject:hook];
  
  // E.g. "~/.xinitrc", "~/.xsession"
  uss = [prefs objectForKey:@"UserSessionScripts"];
  for (path in uss)
    {
      path = [homeDir stringByAppendingPathComponent:path];
      if ([fm fileExistsAtPath:path])
        {
          userSessionCommand = [NSArray arrayWithObjects:path, nil];
          break;
        }
    }

  NSLog(@"User session command: %@", userSessionCommand);
  
  if (userSessionCommand)
    {
      [sessionScript addObject:userSessionCommand];
    }
  else // Try system session script
    {
      [sessionScript
        addObjectsFromArray:[prefs objectForKey:@"DefaultSessionScript"]];
    }
    
  NSLog(@"Default session script: %@",
        [prefs objectForKey:@"DefaultSessionScript"]);
  
  // Logout hook
  hook = [self defaultsForKey:@"LogoutHook" forUser:user];
  if (hook != nil) [sessionScript addObject:hook];
  
  NSLog(@"User session script: %@", sessionScript);
 
  return [sessionScript autorelease];
}

- (void)openSessionForUser:(NSString *)user
{
  // NSArray	*sessionScript;
  UserSession	*aSession;

  // sessionScript = [self sessionScriptForUser:user];
  // // Set up session attributes
  // aSession = [[UserSession alloc] init];
  // [userSessions setObject:aSession forKey:user]; // remember user session
  // [aSession setSessionName:user];
  // if (sessionScript == nil || [sessionScript count] == 0)
  //   { // Nothing to start
  //     NSLog(@"Login failed: Couldn't find session script");
  //     NXRunAlertPanel(@"Login failed", 
  //        	      @"Couldn't find session script\n"
  //        	      "Please check preferences of Login application.", 
  //        	      nil, nil, nil);
  //     [self userSessionWillClose:aSession];
  //     [aSession release];
  //     return;
  //   }
  // [aSession setSessionScript:sessionScript];

  aSession = [[UserSession alloc] initWithOwner:self name:user];
  [userSessions setObject:aSession forKey:user]; // remember user session
  [aSession release];

  // NSThread *mct = [NSThread currentThread];
  // [mct setName:@"MainLoginThread"];
  // NSLog(@"Main thread[%@:%p]: %lu [main=%i]", 
  //       [mct name], mct, [mct retainCount], [mct isMainThread]);

  // --- GCD code ---
  dispatch_queue_t gq = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,
                                                  0);
  dispatch_async(gq, ^{ [self launchUserSession:aSession]; });
  // ----------------
}

// Executed inside libdispatch thread
- (void)launchUserSession:(UserSession *)session
{
  if ([[NSThread currentThread] isMainThread])
    {
      NSLog(@"Error: user session started inside main thread");
      NSRunAlertPanel(@"Open session", 
		      @"Error opening user session.\n"
		      "User session started inside main thread.", 
		      nil, nil, nil);
      [self showWindow];
      return;
    }

  @autoreleasepool
    {
      // NSString *threadName;
      // threadName = [NSString stringWithFormat:@"UserSessionThread_%@",
      //                        [session sessionName]];
      // [[NSThread currentThread] setName:threadName];

      [session launch];
      [self performSelectorOnMainThread:@selector(userSessionWillClose:) 
			     withObject:session
			  waitUntilDone:YES];
    }
}

- (oneway void)userSessionWillClose:(UserSession *)session
{
  NSString *user = [session sessionName];

  NSLog(@"Session WILL close for user \'%@\' [%lu]", 
        user, [session retainCount]);
  // NSThread *mct = [NSThread currentThread];
  // NSLog(@"Main thread[%@:%p]: %lu [main=%i]", 
  //       [mct name], mct, [mct retainCount], [mct isMainThread]);

  if ([userSessions objectForKey:user] == nil)
    {
      return;
    }
  [userSessions removeObjectForKey:user];
  pam_end(PAM_handle, 0);

//  [self closeAllXClients];

  if ([[userSessions allKeys] count] == 0)
    {
      [self showWindow];
    }
}

- (void)showSessionMessage:(NSString *)message
{
  NXTRunAlertPanel(@"Login", message, @"OK", nil, nil);
}

@end

//=============================================================================
// X Window System category
//=============================================================================
@implementation Controller (XWindowSystem)

- (void)initXApp
{
  OSEDisplay *display;
  
  xServer = GSCurrentServer();
  xDisplay = [xServer serverDevice];
  xRootWindow = RootWindow(xDisplay, DefaultScreen(xDisplay));
  xPanelWindow = (Window)[xServer windowDevice:[window windowNumber]];

  // Set initial position of mouse cursor
  display = [screen displayWithMouseCursor];
  XWarpPointer(xDisplay, None, xRootWindow, 0, 0, 0, 0,
               (int)display.frame.origin.x + 50,
               (int)display.frame.origin.y + 50);
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
  if (flag)
    {
      [self setRootWindowBackground];
      [window center];
      [window makeKeyAndOrderFront:self];

      XSetInputFocus(xDisplay, xPanelWindow, RevertToPointerRoot, 
                     CurrentTime);
      XGrabKeyboard(xDisplay, xPanelWindow, False, GrabModeAsync, 
                    GrabModeAsync, CurrentTime);
    }
  else
    {
      XUngrabKeyboard(xDisplay, CurrentTime);
      XWithdrawWindow(xDisplay, xPanelWindow, DefaultScreen(xDisplay));
    }
  XFlush(xDisplay);
}

- (void)hideWindow
{
  [self setWindowVisible:NO];
}

- (void)showWindow
{
  [self setWindowVisible:YES];
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

  for (i = 0; i < nchildren; i++)
    {
      if (XGetWindowAttributes(xDisplay, children[i], &attr)
	  && (attr.map_state != IsUnmapped))
	{
//	  children[i] = XmuClientWindow(xDisplay, children[i]);
	  XKillClient(xDisplay, children[i]);
//	  XDestroyWindow(xDisplay, children[i]);
	}
      else
	{
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
  
  if (busyTimer != nil && [busyTimer isValid]) {
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

- (void)openLoginPreferences
{
  prefs = [[NXTDefaults alloc] initWithUserDefaults];
}

- (NSString *)shutdownCommand
{
  return [prefs objectForKey:@"ShutdownCommand"];
}

- (NSString *)rebootCommand
{
  return [prefs objectForKey:@"RebootCommand"];
}

- (NSString *)lastLoggedInUser
{
  return [prefs objectForKey:@"LastLoggedInUser"];
}

- (void)setLastLoggedInUser:(NSString *)username
{
  [prefs setObject:username forKey:@"LastLoggedInUser"];
}

@end

//=============================================================================
// PAM operations
//=============================================================================
@implementation Controller (PAMAuth)

- (void)authenticateWithHandle:(pam_handle_t *)handle
{
  int ret;
  
  if ((ret = pam_authenticate(handle, 0)) != PAM_SUCCESS)
    {
      NSLog(@"PAM error: %s", pam_strerror(handle, ret));
      [NSException raise:AuthenticationException format:nil];
    }
}

- (void)establishAccountManagementWithHandle:(pam_handle_t *)handle
{
  switch (pam_acct_mgmt(handle, 0))
    {
//    case PAM_AUTHTOKEN_REQD:
//      [NSException raise:AccountRequiresResetupException format:nil];
//      break;
    case PAM_ACCT_EXPIRED:
      [NSException raise:AccountExpiredException format:nil];
      break;
    case PAM_AUTH_ERR:
      [NSException raise:AuthenticationException format:nil];
      break;
    case PAM_PERM_DENIED:
      [NSException raise:PermissionDeniedException format:nil];
      break;
    case PAM_USER_UNKNOWN: // hide the fact that the user is unknown
      [NSException raise:AuthenticationException format:nil];
      break;
    default:
      break;
    }
}

- (void)establishCredentialsWithHandle:(pam_handle_t *)handle
{
  if (pam_setcred(handle, PAM_ESTABLISH_CRED) != PAM_SUCCESS)
    {
      [NSException raise:CredentialsException format:nil];
    }
}

- (void)openSessionWithHandle:(pam_handle_t *)handle
{
  if (pam_open_session(handle, 0) != PAM_SUCCESS)
    {
      NSRunAlertPanel(_(@"Failed to open session"), nil, nil, nil, nil);
      [NSException raise:SessionOpeningException format:nil];
    }
}

@end

@implementation Controller

- (void)awakeFromNib
{
  NSLog(@"Login: awakeFromNib");
  [quitLabel retain];
  [quitLabel removeFromSuperview];
  
  [shutDownBtn setRefusesFirstResponder:YES];
  [restartBtn setRefusesFirstResponder:YES];
  [fieldsImage setRefusesFirstResponder:YES];
  [fieldsLabelImage setRefusesFirstResponder:YES];
  [panelImageView setRefusesFirstResponder:YES];

  [userName setStringValue:[self lastLoggedInUser]];

  userSessions = [[NSMutableDictionary alloc] init];

  // Setup events and notifications
  [[NSDistributedNotificationCenter 
     notificationCenterForType:GSPublicNotificationCenterType]
    addObserver:self selector:@selector(shutDown:)
           name:@"XSComputerShouldGoDown"
         object:@"WorkspaceManager"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
  NSLog(@"appDidFinishLaunch: start");
  // Open preferences
  [self openLoginPreferences];

  // Initialize X resources
  [self initXApp];

  NSLog(@"appDidFinishLaunch: before showWindow");
  // Show login window
  [self showWindow];
  NSLog(@"appDidFinishLaunch: end");

  // Turn light on
  // for (OSEDisplay *display in [[OSEScreen sharedScreen] activeDisplays])
  //   {
  //     [display fadeToNormal:1.0];
  //   }
}

- (BOOL)authenticateUser:(NSString *)user
{
  struct pam_conv conv;

  conv.conv = ConversationFunction;
  if (pam_start("login", [user cString], &conv, &PAM_handle) != PAM_SUCCESS)
    {
      NSLog(@"Failed to initialize PAM");
      NXTRunAlertPanel(@"Login authentication",
                      @"Failed to initialize PAM", nil, nil, nil);
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

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSLog(@"Control did end editing.");
}

- (void)authenticate:(id)sender
{
  NSString *user = [userName stringValue];

  [self setBusyCursor];
  
  NSLog(@"[Controller authenticate:] userName RC: %lu", [user retainCount]);

  if (sender == userName)
    {
      if ([user isEqualToString:@"console"])
	{
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
      else if ([user isEqualToString:@"close"])
	{
	  NSLog(@"Application will be stopped");
	  [NSApp stop:self]; // Go out of run loop
	  return;
	}
      else if ([user isEqualToString:@"quit"])
	{
	  NSLog(@"Application will quit");
	  [NSApp terminate:self]; // Equivalent to "Quit" menu item
	  return;
	}
      else
	{
	  [window makeFirstResponder:password];
	  return;
	}
    }

  if ([self authenticateUser:user] == YES)
    {
      [window shrinkPanel:xPanelWindow onDisplay:xDisplay];
      [self hideWindow];
      
      // Clear password ivar for security reasons
      // [password setStringValue:@""];

      NSLog(@"Controller, username: %@", user);
      // NSLog(@"[Controller authenticate:] userName RC: %lu", [user retainCount]);
      [self openSessionForUser:user];
      // NSLog(@"[Controller authenticate:] userName RC: %lu", [user retainCount]);
    }
  else
    {
      [window shakePanel:xPanelWindow onDisplay:xDisplay];
      [self clearFields];
    }
  [self destroyBusyCursor];
}

- (void)restart:sender
{
  NSString *restartCmd;
  
  if (NXTRunAlertPanel(_(@"Restart"),
         	      _(@"Do you really want to restart the computer?"),
         	      _(@"Restart"), _(@"Cancel"), nil)
      == NSAlertDefaultReturn)
    {
      if ((restartCmd = [self rebootCommand]) == nil)
	{
	  restartCmd = @"reboot";
	}

      NSLog(@"RebootCommand: %@", restartCmd);
      [quitLabel setStringValue:@"Restarting computer..."];
      [self prepareForQuit];
      system([restartCmd cString]);
    }
}

- (void)shutDown:sender
{
  NSString *shutDownCmd;
  BOOL     askUser = YES;
  BOOL     performShutdown = NO;

  NSLog(@"Login: receive \"Power off\" event from %@", [sender className]);

  // Workspace app requests shutdown.
  // TODO: Check if user has rights to do it (key?salt?)
  // TODO: Check if other users still logged in
  if ([sender isKindOfClass:[NSNotification class]])
    {
      NSLog(@"POWER OFF: request by a NSNotification: %@", [sender object]);
      askUser = NO;
      performShutdown = YES;
    }

  // Ask user to verify his choice
  if (askUser &&
      NXTRunAlertPanel(_(@"Power"),
		      _(@"Do you really want to turn off the computer?"),
		      _(@"Turn it off"), _(@"Cancel"), nil) 
      == NSAlertDefaultReturn)
    {
      performShutdown = YES;
    }

  // Perform quit preparation procedure and power off computer
  if (performShutdown == YES)
    {
      if ((shutDownCmd = [self shutdownCommand]) == nil)
	{
	  shutDownCmd = @"shutdown -h now";
	}

      [quitLabel setStringValue:@"Powering off computer..."];
      [self prepareForQuit];
      system([shutDownCmd cString]);
    }
}

- (void)clearFields
{
  NSString *user = [self lastLoggedInUser];
  
  [password setStringValue:@""];
  
  if (user && [user length] > 0)
  {  
    [userName setStringValue:[self lastLoggedInUser]];
    [window makeFirstResponder:password];
  }
  else
  {
    [userName setStringValue:@""];
    [window makeFirstResponder:userName];
  }
}

- (void)prepareForQuit
{
  [userName removeFromSuperview];
  [password removeFromSuperview];
  [fieldsImage removeFromSuperview];
  [fieldsLabelImage removeFromSuperview];

  [[window contentView] addSubview:quitLabel];
}

// It is needed by ConversationFunction()
- (NSString *)password
{
  return [password stringValue];
}

- (NSWindow *)window
{
  return window;
}

@end

