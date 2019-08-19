/* -*- mode: objc -*- */
//
// Project: Preferences
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

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSButton.h>

#import "Password.h"

@implementation Password

static NSBundle *bundle = nil;

- (void)dealloc
{
  NSLog(@"Password -dealloc");
  [image release];
  [lockImage release];
  [lockOpenImage release];
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  bundle = [NSBundle bundleForClass:[self class]];
  image = [[NSImage alloc]
            initWithContentsOfFile:[bundle pathForResource:@"Password"
                                                    ofType:@"tiff"]];
  lockImage = [[NSImage alloc]
                initWithContentsOfFile:[bundle pathForResource:@"Password"
                                                        ofType:@"tiff"]];
  lockOpenImage = [[NSImage alloc]
                     initWithContentsOfFile:[bundle pathForResource:@"Password"
                                                             ofType:@"tiff"]];
      
  return self;
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [messageField setStringValue:@""];
  [passwordField setStringValue:@"Password Secure"];

  [okButton setRefusesFirstResponder:YES];
  [canceButton setRefusesFirstResponder:YES];
  [lockView setRefusesFirstResponder:YES];
}

- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Password" owner:self]) {
      NSLog (@"Password.preferences: Could not load NIB, aborting.");
      return nil;
    }
  }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Password Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (IBAction)changePassword:(id)sender
{
  switch (state) {
  case EnterOld:
    [passwordField setDrawsBackground:YES];
    [passwordField setStringValue:@""];
    [[passwordField cell] setTextColor:[NSColor whiteColor]];
    [passwordField setAlignment:NSLeftTextAlignment];
    [passwordField setEditable:YES];
    [[view window] makeFirstResponder:passwordField];
    // Please type your old password.
    [messageField setStringValue:@"Please type your old password."];
    [okButton setTitle:@"Ok"];
    [cancelButton setEnabled:YES];
    state++;
    break;
  case EnterNew:
    // Please type your new password.
    [messageField setStringValue:@"Please type your new password."];
    [passwordField setStringValue:@""];
    state++;
    break;
  case ConfirmNew:
    // Please type your new password again.
    [passwordField setStringValue:@""];
    [messageField setStringValue:@"Please type your new password again."];
    state++;
    break;
  default:
    [self cancel:okButton];
  }
}

- (IBAction)cancel:(id)sender
{
  // Password field
  [passwordField setEditable:NO];
  [passwordField setDrawsBackground:NO];
  [passwordField setStringValue:@"Password Secure"];
  [[passwordField cell] setTextColor:[NSColor darkGrayColor]];
  [passwordField setAlignment:NSCenterTextAlignment];
  //
  [messageField setStringValue:@""];
  [okButton setTitle:@"Change"];
  [cancelButton setEnabled:NO];
  state = EnterOld;
}

@end
