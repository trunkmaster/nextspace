/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Description: Module for Preferences application.
//
// Copyright (C) 2011 Sergii Stoian
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

static NXTDefaults          *defaults = nil;

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

- (void)dealloc
{
  NSLog(@"view RC: %lu", [view retainCount]);
  [image release];
  [super dealloc];
}

- (void)awakeFromNib
{
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

  senderState = [NSNumber numberWithInteger:[sender state]];
  setting = @{@"SaveLastLoggedInUser":senderState};
  
  [[NSDistributedNotificationCenter defaultCenter]
    postNotificationName:@"LoginDefaultsShouldChangeNotification"
                  object:setting];  
}
- (IBAction)setDisplayHostName:(id)sender
{
  NSDictionary *setting;
  NSNumber     *senderState;

  NSLog(@"[Login] setDisplayHostName");

  senderState = [NSNumber numberWithInteger:[sender state]];
  setting = @{@"DisplayHostName":senderState};
  
  [[NSDistributedNotificationCenter notificationCenterForType:NSLocalNotificationCenterType]
    postNotificationName:@"LoginDefaultsShouldChangeNotification"
                  object:@"Preferences"
                userInfo:setting];
}

@end
