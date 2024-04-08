/*
  Project: Terminal

  Copyright (c) 2024-present Sergii Stoian <stoyan255@gmail.com>

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

#import "TerminalIcon.h"
#include "AppKit/NSEvent.h"
#include "Foundation/NSObjCRuntime.h"

@implementation TerminalIcon : NSImageView

- (void)dealloc
{
  [_scrollingImage release];
  [super dealloc];
}

- (instancetype)initWithFrame:(NSRect)rect scrollingFrame:(NSRect)scrollingRect
{
  [super initWithFrame:rect];

  _scrollingRect = scrollingRect;
  _isAnimates = NO;
  yPosition = 0;

  return self;
}

- (void)setTitle:(NSString *)title
{
  if (titleCell == nil) {
    CGFloat fontSize;

    titleCell = [[NSTextFieldCell alloc] initTextCell:title];
    [titleCell setSelectable:NO];
    [titleCell setEditable:NO];
    [titleCell setBordered:NO];
    [titleCell setAlignment:NSCenterTextAlignment];
    [titleCell setDrawsBackground:NO];
    [titleCell setTextColor:[NSColor whiteColor]];
    fontSize = [NSFont systemFontSizeForControlSize:NSMiniControlSize];
    [titleCell setFont:[NSFont systemFontOfSize:fontSize]];
  } else {
    [titleCell setStringValue:title];
  }
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)aRect
{
  NSPoint iconPoint = NSMakePoint((_frame.size.width - _iconImage.size.width) / 2.0,
                                     (_frame.size.width - _iconImage.size.height) / 2.0);

  if (_isMiniWindow != NO) {
    iconPoint.y -= (13 / 2.0) - 1;
    // Tile
    [[NSImage imageNamed:@"common_MiniWindowTile"] compositeToPoint:NSMakePoint(0, 0)
                                                           fromRect:NSMakeRect(0, 0, 64, 64)
                                                          operation:NSCompositeSourceOver];
    // Title
    [titleCell drawWithFrame:NSMakeRect(3, _frame.size.height - 13, _frame.size.width - 6, 10)
                      inView:self];
  }

  // Icon
  [_iconImage compositeToPoint:iconPoint
                      fromRect:NSMakeRect(0, 0, _iconImage.size.width, _iconImage.size.height)
                     operation:NSCompositeSourceOver];

  // Animation
  if (_isAnimates != NO) {
    switch ((int)yPosition) {
      case 5:
        _isAnimates = NO;
      case 0:
        yPosition = _scrollingImage.size.height - _scrollingRect.size.height;

    }
    [_scrollingImage compositeToPoint:NSMakePoint(_scrollingRect.origin.x + iconPoint.x,
                                                  _scrollingRect.origin.y + iconPoint.y)
                             fromRect:NSMakeRect(0, yPosition, _scrollingRect.size.width,
                                                 _scrollingRect.size.height)
                            operation:NSCompositeSourceOver];

    yPosition -= 1;
  }
}

- (void)animate
{
  [self setNeedsDisplay:YES];
  [self display];
}

@end
