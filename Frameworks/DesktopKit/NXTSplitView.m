/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
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

#import <Foundation/NSNotification.h>
#import "NXTSplitView.h"

NSString *NXTSplitViewDividerDidDraw = @"NXTSplitViewDividerDidDraw";

@implementation NXTSplitView

// --- Overridings

- (CGFloat)dividerThickness
{
  if (_dividerWidth <= 0) {
    _dividerWidth = 8.0;
  }
  
  return _dividerWidth;
}

- (void)setDividerThinkness:(CGFloat)width
{
  _dividerWidth = width;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  if (!resizableState) {
    return;
  }

  [super mouseDown:theEvent];
}

- (void)resetCursorRects
{
  if (!resizableState) {
    return;
  }

  [super resetCursorRects];
}

- (NSRect)dividerRect
{
  return dividerRect;
}

- (void)drawDividerInRect:(NSRect)aRect
{
  if (resizableState == 0) {
    return;
  }
  
  [super drawDividerInRect:aRect];

  dividerRect = aRect;

  [[NSNotificationCenter defaultCenter] 
    postNotificationName:NXTSplitViewDividerDidDraw
		  object:self];
}

// --- Extentions

- (void)setResizableState:(NSInteger)state
{
  resizableState = state;
  [self setNeedsDisplay:YES];
}

- (NSInteger)resizableState
{
  return resizableState;
}

@end
