/*
  Class:               NXAlert
  Inherits from:       NSObject
  Class descritopn:    Owner of alert panel

  Copyright (C) 2016 Sergii Stoian

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

#include <AppKit/AppKit.h>

@interface NXAlert : NSObject
{
  NSPanel     *panel;
  NSTextField *titleField;
  NSImageView *icon;
  NSTextField *messageField;
  NSButton    *defaultButton;
  NSButton    *alternateButton;
  NSButton    *otherButton;

  NSString    *titleString;
  NSString    *messageString;
  NSString    *defaultString;
  NSString    *alternateString;
  NSString    *otherString;
}

- (void)buttonPressed:(id)sender;

@end

extern NSInteger NXRunAlertPanel(NSString *title,
                                 NSString *msg,
                                 NSString *defaultButton,
                                 NSString *alternateButton,
                                 NSString *otherButton, ...);
