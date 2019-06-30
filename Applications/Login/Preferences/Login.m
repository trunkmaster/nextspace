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

#import <math.h>
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

#import "Login.h"

@implementation Login

static NXTDefaults *defaults = nil;

- (void)dealloc
{
  NSLog(@"view RC: %lu", [view retainCount]);
  [image release];
  [defs release];
  [super dealloc];
}

- (id)init
{
  NSBundle *bundle;
  NSString *imagePath;
      
  self = [super init];
      
  defaults = [NXTDefaults userDefaults];

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
  while (grp->gr_mem[i] != NULL) {
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
  defs = [[NXTDefaults alloc] initDefaultsWithPath:NSSystemDomainMask
                                            domain:@"Login"];

  if (defs != nil) {
    [displayHostname
      setState:[[defs objectForKey:@"DisplayHostName"] integerValue]];
  }
  if (defs != nil) {
    [saveLastLoggedIn
      setState:[[defs objectForKey:@"RememberLastLoggedInUser"] integerValue]];
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
  
  [view retain];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Login" owner:self])
        {
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
- (IBAction)setLoginHook:(id)sender
{
  
}
- (IBAction)setLogoutHook:(id)sender
{
}
- (IBAction)setLastLoggedIn:(id)sender
{
  // NSDictionary *setting;
  // NSNumber     *senderState;

  NSLog(@"[Login] setLastLoggedIn: %@", [sender className]);

  // senderState = [NSNumber numberWithInteger:[sender state]];
  // setting = @{@"RememberLastLoggedInUser":senderState};

  [defs setObject:[NSNumber numberWithInteger:[sender state]]
           forKey:@"RememberLastLoggedInUser"];
  [defs synchronize];
  
  [[NSDistributedNotificationCenter
     notificationCenterForType:GSPublicNotificationCenterType]
    postNotificationName:@"LoginDefaultsDidChangeNotification"
                  object:@"Preferences"
                userInfo:nil
      deliverImmediately:YES];
}
- (IBAction)setDisplayHostName:(id)sender
{
  // NSDictionary *setting;
  // NSNumber     *senderState;

  NSLog(@"[Login] setDisplayHostName: %@", [sender className]);

  // senderState = [NSNumber numberWithInteger:[sender state]];
  // setting = @{@"DisplayHostName":senderState};
  
  [defs setObject:[NSNumber numberWithInteger:[sender state]]
           forKey:@"DisplayHostName"];
  [defs synchronize];
  
  [[NSDistributedNotificationCenter
     notificationCenterForType:GSPublicNotificationCenterType]
    postNotificationName:@"LoginDefaultsDidChangeNotification"
                  object:@"Preferences"
                userInfo:nil
      deliverImmediately:YES];
}

@end
