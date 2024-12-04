/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2024 Sergii Stoian
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

#import "NXTTabViewItem.h"

@implementation NXTTabViewItem

#pragma mark - Overridings

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (instancetype)init
{
  [super init];
  _superviewOldSize = NSZeroSize;
  return self;
}

- (void)setTabRect:(NSRect)tabRect
{
  _rect = tabRect;
}

- (void)setView:(NSView *)view
{
  [super setView:view];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewDidResize:)
                                               name:NSViewFrameDidChangeNotification
                                             object:view];
}

- (void)viewDidResize:(NSNotification *)aNotif
{
  _superviewOldSize = [[_view superview] frame].size;
}

#pragma mark - Resizing

- (void)resizeViewToSuperview:(NSView *)superView
{
  // NSLog(@"Tab %@ OLD superview size %@", _label, NSStringFromSize(_superviewOldSize));
  if (NSEqualSizes(_superviewOldSize, NSZeroSize)) {
    _superviewOldSize = superView.frame.size;
    // NSLog(@"Tab %@ INITIAL superview size is %@", _label, NSStringFromSize(superView.frame.size));
    return;
  }
  if (NSEqualSizes(_superviewOldSize, superView.frame.size) == NO) {
    // NSLog(@"Tab %@ RESIZE to superview size %@ with old: %@", _label,
    //       NSStringFromSize(superView.frame.size), NSStringFromSize(_superviewOldSize));
    [_view resizeWithOldSuperviewSize:_superviewOldSize];
  }
}

@end
