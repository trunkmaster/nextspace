/*
  Class:               AddLayoutPanel
  Inherits from:       NSObject
  Class descritopn:    Panel to select keyboard layout for Keyboard 
                       preferences bundle

  Copyright (C) 2017 Sergii Stoian <stoyan255@ukr.net>

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

#import <AppKit/AppKit.h>
#import <NXSystem/NXKeyboard.h>

@class Keyboard;

@interface AddLayoutPanel : NSObject
{
  NSWindow     *panel;
  NSBrowser    *browser;
  NSButton     *addBtn;
  NSTextField  *infoField;
  
  NXKeyboard   *keyboard;
  Keyboard     *kPrefs;
  NSDictionary *layoutDict;
  NSArray      *layoutList;
  NSDictionary *variantDict;
}

- initWithKeyboard:(NXKeyboard *)k;
- (NSWindow *)panel;
- (void)orderFront:(Keyboard *)kPreferences;

@end
