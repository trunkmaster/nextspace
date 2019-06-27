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
#import <DesktopKit/NXTDefaults.h>

#import "Login.h"

@implementation Login

static NXTDefaults *defaults = nil;

- (void)dealloc
{
  NSLog(@"view RC: %lu", [view retainCount]);
  [image release];
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

- (NSDictionary *)_rootDefaults
{
  NSString     *path = @"/root/Library/Preferences/.NextSpace/Login";
  NSDictionary *defs = nil;

  if ([[NSFileManager defaultManager] fileExistsAtPath:path] != NO) {
    defs = [NSDictionary dictionaryWithContentsOfFile:path];
  }
  else {
    NSLog(@"Failed to read `root` Login defaults.");
  }

  return defs;
}

- (void)awakeFromNib
{
  NSDictionary *defs = [self _rootDefaults];

  if (defs != nil && [defs isKindOfClass:[NSDictionary class]]) {
    [displayHostName setState:NSOnState];
    [displayHostName
      setState:[[defs objectForKey:@"DisplayHostName"] integerValue]];
    [saveLastLoggedIn setState:NSOnState];
    [saveLastLoggedIn
      setState:[[defs objectForKey:@"RememberLastLoggedInUser"] integerValue]];
  }
  else {
    [displayHostName setState:NSOffState];
    [displayHostName setEnabled:NO];
    [saveLastLoggedIn setState:NSOffState];
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
  NSDictionary *setting;
  NSNumber     *senderState;

  NSLog(@"[Login] setLastLoggedIn: %@", [sender className]);

  senderState = [NSNumber numberWithInteger:[sender state]];
  setting = @{@"RememberLastLoggedInUser":senderState};
  
  [[NSDistributedNotificationCenter
     notificationCenterForType:GSPublicNotificationCenterType]
    postNotificationName:@"LoginDefaultsShouldChangeNotification"
                  object:@"Preferences"
                userInfo:setting
      deliverImmediately:YES];
}
- (IBAction)setDisplayHostName:(id)sender
{
  NSDictionary *setting;
  NSNumber     *senderState;

  NSLog(@"[Login] setDisplayHostName: %@", [sender className]);

  senderState = [NSNumber numberWithInteger:[sender state]];
  setting = @{@"DisplayHostName":senderState};
  
  [[NSDistributedNotificationCenter
     notificationCenterForType:GSPublicNotificationCenterType]
    postNotificationName:@"LoginDefaultsShouldChangeNotification"
                  object:@"Preferences"
                userInfo:setting
      deliverImmediately:YES];
}

@end
