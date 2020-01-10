/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2005 Saso Kiselkov
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

#import <AppKit/NSTextView.h>

@class NXTIcon, NSScrollView;

@interface NXTIconLabel : NSTextView
{
  NSString *oldString;
  NSString *oldString1;
  NXTIcon  *icon;

  id iconLabelDelegate;
}

// Designated initializer.
- initWithFrame:(NSRect) frame
	   icon:(NXTIcon *)icon;

// Tells the receiver to adjust it's frame to fit into its superview.
- (void)adjustFrame;
- (void)adjustFrameForString:(NSString *)string;

// Sets the delegate to whom delegate messages are passed.
- (void)setIconLabelDelegate:aDelegate;
// Returns the delegate.
- iconLabelDelegate;

// Returns the icon which owns the receiver.
- (NXTIcon *)icon;

@end

@protocol NXTIconLabelDelegate

- (void)   iconLabel:(NXTIconLabel *)anIconLabel
 didChangeStringFrom:(NSString *)oldLabelString
                  to:(NSString *)newLabelString;


@end
