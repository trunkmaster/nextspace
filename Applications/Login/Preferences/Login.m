/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Description: Module for Preferences application.
//
// Copyright (C) 2011-2019 Sergii Stoian
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

#include <math.h>
#include <sys/types.h>
#include <grp.h>

#import <Foundation/NSValue.h>
#import <Foundation/NSDistributedNotificationCenter.h>
#import <Foundation/NSFileManager.h>

#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSTextView.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontPanel.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSOpenPanel.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSSlider.h>
#import <AppKit/NSApplication.h>

#import <DesktopKit/NXTAlert.h>

#import "Login.h"

@interface Login (Private)
- (BOOL)_hookIsValid:(NSString *)hookPath;
@end
@implementation Login (Private)
- (BOOL)_hookIsValid:(NSString *)hookPath
{
  NSFileManager *fm = [NSFileManager defaultManager];

  if (hookPath == nil) {
    return NO;
  }

  // Empty string is valid. It's used to clear hooks.
  if ([hookPath isEqualToString:@""]) {
    return YES;
  }
  
  // Check if file exist and is executable
  if ([fm isExecutableFileAtPath:hookPath] == NO) {
    NXTRunAlertPanel(@"Set Login Hook",
                     @"File `%@` does not exist.\n"
                     "Please specifiy existing program or script.",
                     @"Understood", nil, nil, hookPath);
    return NO;
  }
  else if ([fm isExecutableFileAtPath:hookPath] == NO) {
    NXTRunAlertPanel(@"Set Login Hook",
                     @"File `%@` is not executable.\n"
                     "Please specifiy another or fix permissions.",
                     @"Understood", nil, nil, hookPath);
    return NO;
  }

  return YES;
}
@end

@implementation Login

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"Login -dealloc");
  
  [image release];
  [defaults release];
  [super dealloc];
}

- (id)init
{
  NSBundle *bundle;
  NSString *imagePath;
      
  self = [super init];
      
  defaults = [[OSEDefaults alloc] initDefaultsWithPath:NSUserDomainMask
                                                domain:@"Login"];

  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource:@"Loginwindow" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
  view = nil;
      
  return self;
}

- (BOOL)_isAdminUser
{
  struct group *grp;
  int i = 0;
  BOOL isAdmin = NO;

  grp = getgrnam("wheel");
  if (grp == NULL) {
    grp = getgrnam("adm");
  }
  while (grp && grp->gr_mem[i] != NULL) {
    printf("[Login] wheel member: %s\n", grp->gr_mem[i]);
    if (!strcmp(grp->gr_mem[i], [NSUserName() cString])) {
      isAdmin = YES;
      break;
    }
    i++;
  }

  return isAdmin;
}

- (void)awakeFromNib
{
  systemDefaults = [[OSEDefaults alloc]
                     initDefaultsWithPath:NSSystemDomainMask
                                   domain:@"Login"];

  if (systemDefaults != nil) {
    [displayHostname
      setState:[[systemDefaults objectForKey:@"DisplayHostName"]
                 integerValue]];
  }
  if (systemDefaults != nil) {
    [saveLastLoggedIn
      setState:[[systemDefaults objectForKey:@"RememberLastLoggedInUser"]
                 integerValue]];
  }

  isAdminUser = [self _isAdminUser];
  if (isAdminUser == NO) {
    [screenSaverSlider setEnabled:NO];
    [screenSaverField setEnabled:NO];
    
    [customSaverTitle setEnabled:NO];
    [customSaverField setEnabled:NO];
    [customSaverButton setEnabled:NO];
    
    [customUITitle setEnabled:NO];
    [customUIField setEnabled:NO];
    [customUIButton setEnabled:NO];
    
    [displayHostname setEnabled:NO];
    [saveLastLoggedIn setEnabled:NO];
  }
  
  [loginHookField setStringValue:[defaults objectForKey:@"LoginHook"]];
  [logoutHookField setStringValue:[defaults objectForKey:@"LogoutHook"]];

  [view retain];
}

- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Login" owner:self]) {
      return nil;
    }      
  }
  return view;
}

- (NSString *)buttonCaption
{
  return @"Login Window Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (IBAction)setScreenSaver:(id)sender
{
  if ([sender isKindOfClass:[NSSlider class]]) {
    [screenSaverField setFloatValue:[sender floatValue]];
  }
  else if ([sender isKindOfClass:[NSTextField class]]) {
    [screenSaverSlider setFloatValue:[sender floatValue]];
  }
}
- (IBAction)setLoginHook:(id)sender
{
  NSString *hookPath = nil;
  
  NSLog(@"Set LogIn Hook: %@", [sender className]);
  if ([sender isKindOfClass:[NSTextField class]] != NO) {
    hookPath = [sender stringValue];
  }
  else if ([sender isKindOfClass:[NSButton class]] != NO) {
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setTitle:@"Set Login Hook"];
    [panel setShowsHiddenFiles:NO];

    if ([panel runModalForDirectory:NSHomeDirectory()
                               file:@""
                              types:nil] == NSOKButton) {
      hookPath = [panel filename];
    }
  }

  // Clear textfield with wrong
  if ([self _hookIsValid:hookPath] == NO) {
    if ([sender isKindOfClass:[NSTextField class]] != NO) {
      [loginHookField setStringValue:@""];
    }
  }
  else {
    if ([sender isKindOfClass:[NSTextField class]] == NO) {
      [loginHookField setStringValue:hookPath];
    }
    [defaults setObject:hookPath forKey:@"LoginHook"];
    [[sender window] makeFirstResponder:[loginHookField nextKeyView]];
  }
}
- (IBAction)setLogoutHook:(id)sender
{
  NSString *hookPath = nil;
  
  NSLog(@"Set LogOut Hook: %@", [sender className]);
  
  if ([sender isKindOfClass:[NSTextField class]] != NO) {
    hookPath = [sender stringValue];
  }
  else if ([sender isKindOfClass:[NSButton class]] != NO) {
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setTitle:@"Set Logout Hook"];
    [panel setShowsHiddenFiles:NO];

    if ([panel runModalForDirectory:NSHomeDirectory()
                               file:@""
                              types:nil] == NSOKButton) {
      hookPath = [panel filename];
    }
  }

  // Clear textfield with wrong
  if ([self _hookIsValid:hookPath] == NO) {
    if ([sender isKindOfClass:[NSTextField class]] != NO) {
      [loginHookField setStringValue:@""];
    }
  }
  else {
    if ([sender isKindOfClass:[NSTextField class]] == NO) {
      [loginHookField setStringValue:hookPath];
    }
    [defaults setObject:hookPath forKey:@"LogoutHook"];
    if ([(NSControl *)[logoutHookField nextKeyView] isEnabled] != NO)
      [[sender window] makeFirstResponder:[logoutHookField nextKeyView]];
    else
      [[sender window] makeFirstResponder:loginHookField];
  }
}
- (IBAction)setLastLoggedIn:(id)sender
{
  // NSLog(@"[Login] setLastLoggedIn: %@", [sender className]);

  [systemDefaults setObject:[NSNumber numberWithInteger:[sender state]]
                     forKey:@"RememberLastLoggedInUser"];
  [systemDefaults synchronize];

  [[NSDistributedNotificationCenter notificationCenterForType:GSPublicNotificationCenterType]
      postNotificationName:@"LoginDefaultsDidChangeNotification"
                    object:@"Preferences"
                  userInfo:nil
        deliverImmediately:YES];
}
- (IBAction)setDisplayHostName:(id)sender
{
  // NSLog(@"[Login] setDisplayHostName: %@", [sender className]);

  [systemDefaults setObject:[NSNumber numberWithInteger:[sender state]]
                     forKey:@"DisplayHostName"];
  [systemDefaults synchronize];

  [[NSDistributedNotificationCenter notificationCenterForType:GSPublicNotificationCenterType]
      postNotificationName:@"LoginDefaultsDidChangeNotification"
                    object:@"Preferences"
                  userInfo:nil
        deliverImmediately:YES];
}

@end
