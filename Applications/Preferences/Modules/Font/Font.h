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

#import <AppKit/NSNibDeclarations.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSTextView.h>

#import <Preferences.h>

@interface Font : NSObject <PrefsModule>
{
  IBOutlet NSPopUpButton *fontCategoryPopUp;
  IBOutlet NSButton      *fontSetButton;
  IBOutlet NSTextField   *fontNameTextField;
  IBOutlet NSScrollView  *fontExampleScrollView;
  IBOutlet NSTextView    *fontExampleTextView;
  IBOutlet NSButton      *enableAntiAliasingButton;
  IBOutlet NSButton      *enableSubpixelButton;
  IBOutlet NSButton      *subpixelModeButton;

  IBOutlet NSWindow      *window;
  IBOutlet id            view;

  NSDictionary		 *fontCategories;

  NSImage		 *image;
  NSString		 *exampleString;
  // NSString		 *normalExampleString;
  // NSString		 *boldExampleString;  
}

- (IBAction)fontCategoryChanged:(id)sender;
- (IBAction)setFont:(id)sender;
- (IBAction)enableAntiAliasingChanged:(id)sender;

@end
