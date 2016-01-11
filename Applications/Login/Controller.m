/*
   Controller.m
   The main app controller of the Login application.

   This file is part of xSTEP.

   Copyright (C) 2006

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "Controller.h"
#import "UserSession.h"

#import <unistd.h>
#import <fcntl.h>
#import <sys/ioctl.h>

#ifdef __FreeBSD__
#import <sys/consio.h> // for changing VT
#endif

#import <dispatch/dispatch.h>

#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>

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

- (void)openSessionForUser:(NSString *)user
{
  NSString            *homeDir = NSHomeDirectoryForUser(user);
  NSFileManager       *fm = [NSFileManager defaultManager];
  NSString            *path = nil;
  NSArray             *userSessionScripts = nil;
  NSMutableDictionary *sessionScript = nil;
  NSEnumerator        *e;

  // Clear password ivar for security reasons
  [password setStringValue:nil];

  // Prepare session script for passing to UserSession
  userSessionScripts = [prefs objectForKey:@"UserSessionScripts"];
  if (userSessionScripts != nil)
    {
      e = [userSessionScripts objectEnumerator];
      while ((path = [e nextObject]) != nil)
	{
	  path = [homeDir stringByAppendingPathComponent:path];
	  if ([fm fileExistsAtPath:path])
	    {
	      break;
	    }
	}

      if (path != nil)
	{
	  sessionScript = [NSMutableDictionary new];
	  [sessionScript setObject:[prefs objectForKey:@"LoginHook"]
			    forKey:@"1"];
	  [sessionScript setObject:[NSArray arrayWithObjects:path, nil]
			    forKey:@"2"];
	  [sessionScript setObject:[prefs objectForKey:@"LogoutHook"]
			    forKey:@"3"];
	}
    }

  NSLog(@"User session script: %@", sessionScript);
 
  // Try system session script
  if (sessionScript == nil)
    {
      sessionScript = [[prefs objectForKey:@"SystemSessionScript"] mutableCopy];
    }

  if (sessionScript == nil)
    { // Nothing to start
      NSRunAlertPanel(@"Login failed", 
		      @"Couldn't find session script\n"
		      "Please check preferences of Login application.", 
		      nil, nil, nil);
      return;
    }

  // Set up session attributes
  UserSession *aSession = [[UserSession alloc] init];

  [aSession setSessionScript:sessionScript];
  [aSession setSessionName:user];
  [userSessions setObject:aSession forKey:user]; // remember user session

  [sessionScript release];
//  [user release];
  [aSession release];

  NSThread *mct = [NSThread currentThread];
  [mct setName:@"MainLoginThread"];
  NSLog(@"Main thread[%@:%p]: %lu [main=%i]", 
	[mct name], mct, [mct retainCount], [mct isMainThread]);

  // --- GCD code ---
  dispatch_queue_t gq = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
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
      NSThread *ct = [NSThread currentThread];

      [ct setName:[NSString stringWithFormat:@"UserSessionThread_%@",[session sessionName]]];

      [session launchSession];
      [self performSelectorOnMainThread:@selector(userSessionWillClose:) 
			     withObject:session
			  waitUntilDone:YES];

      NSLog(@"Session thread[%@:%p]: %lu [main=%i]", 
	    [ct name], ct, [ct retainCount], [ct isMainThread]);
    }
}

- (oneway void)userSessionWillClose:(UserSession *)session
{
  NSString *user = [session sessionName];

//  NSLog(@"Session WILL close for user \'%@\' [%lu]", 
//	user, [session retainCount]);
  NSThread *mct = [NSThread currentThread];
  NSLog(@"Main thread[%@:%p]: %lu [main=%i]", 
	[mct name], mct, [mct retainCount], [mct isMainThread]);

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

@end

//=============================================================================
// X Window System category
//=============================================================================
@implementation Controller (XWindowSystem)

- (void)initXApp
{
  xServer = GSCurrentServer();
  xDisplay = [xServer serverDevice];
  xRootWindow = RootWindow(xDisplay, DefaultScreen(xDisplay));
  xPanelWindow = (Window)[xServer windowDevice:[window windowNumber]];
}

- (void)setRootWindowBackground
{
  XSetWindowAttributes winattrs;

  // TODO: Leave it for future experiments...
  // XWarpPointer(xDisplay, None, xRootWindow, 0, 0, 0, 0, 100, 100);

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
      // TODO: Implement shrinking of window
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

@end

//=============================================================================
// Application preferences
//=============================================================================
@implementation Controller (Preferences)

- (void)openLoginPreferences
{
  prefs = [[NXDefaults alloc] initWithSystemDefaults];
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
  for (NXDisplay *display in [[NXScreen sharedScreen] activeDisplays])
    {
      [display fadeToNormal:1.0];
    }
}

- (BOOL)authenticateUser:(NSString *)user
{
//  pam_handle_t    *handle;
  struct pam_conv conv;

  conv.conv = ConversationFunction;
  if (pam_start("login", [user cString], &conv, &PAM_handle) != PAM_SUCCESS)
    {
      NSLog(@"Failed to initialize PAM");
//      NSRunAlertPanel(_(@"Failed to initialize PAM"), nil, nil, nil, nil);
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
      NSLog(@"Controller, username: %@", user);
      [self setLastLoggedInUser:user];
      NSLog(@"[Controller authenticate:] userName RC: %lu", [user retainCount]);
      [self openSessionForUser:user];
      NSLog(@"[Controller authenticate:] userName RC: %lu", [user retainCount]);

      [window shrinkPanel:xPanelWindow onDisplay:xDisplay];
      [self hideWindow];
    }
  else
    {
      [window shakePanel:xPanelWindow onDisplay:xDisplay];
      [self clearFields];
    }
}

- (void)restart:sender
{
  NSString *restartCmd;
  /*  NSAlert *alertPanel;

  // {
    NSRect   panelFrame, displayFrame;
    NXScreen *rScreen;
    NSPoint  newOrigin;
    
    alertPanel = NSGetAlertPanel(@"Restart",
                                 @"Do you really want to restart the computer?",
                                 @"Restart", @"Cancel", nil);
    // [alertPanel sizePanelToFit];
    // panelFrame = [[alertPanel window] frame];

    // rScreen = [[NXScreen alloc] init];
    // displayFrame = [[rScreen mainDisplay] frame];
    // [rScreen release];
    displayFrame = [[[alertPanel window] screen] frame];

    // Calculate the new position of the window.
    // newOrigin.x = displayFrame.size.width/2 - panelFrame.size.width/2;
    newOrigin.x = displayFrame.size.width/2;
    newOrigin.x += displayFrame.origin.x;
    newOrigin.y = displayFrame.size.height/2;
    // newOrigin.y += gScreenRect.size.height - displayFrame.size.height;

    // Set the origin
    [[alertPanel window] setFrameOrigin:newOrigin];
    // [[alertPanel window] makeKeyAndOrderFront:self];
  // }
  // if ([alertPanel runModal] == NSAlertDefaultReturn)
  */

  if (NSRunAlertPanel(_(@"Restart"),
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
      NSRunAlertPanel(_(@"Power"),
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

