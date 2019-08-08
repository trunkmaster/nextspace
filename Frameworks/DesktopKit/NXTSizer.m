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

#import "NXTSizer.h"

static inline NSRect IncrementedRect(NSRect r)
{
  r.origin.x--;
  r.origin.y--;
  r.size.width += 2;
  r.size.height += 2;

  return r;
}

@implementation NXTSizer

- (void)mouseDown:(NSEvent *)ev
{
  float lastPoint;

  if (delegate == nil ||
      ![delegate respondsToSelector:@selector(arrowView:shouldMoveByDelta:)] ||
      ![delegate respondsToSelector:@selector(arrowViewStoppedMoving:)]) {
    return;
  }

  lastPoint = [ev locationInWindow].x;

  while ([(ev = [[self window] nextEventMatchingMask:NSAnyEventMask]) type]
         != NSLeftMouseUp) {
    float delta;

    if ([ev type] != NSLeftMouseDragged)
      continue;

    delta = [ev locationInWindow].x - lastPoint;
    if ([delegate arrowView:self shouldMoveByDelta:delta]) {
      NSRect frame;
        
      frame = [self frame];
      [[self superview] setNeedsDisplayInRect:IncrementedRect(frame)];
      frame.origin.x += delta;
      [self setFrame:frame];
      [self setNeedsDisplay:YES];
      [[self superview] setNeedsDisplayInRect:IncrementedRect(frame)];
        
      lastPoint = [ev locationInWindow].x;
    }
  }

  [delegate arrowViewStoppedMoving:self];
}

@end
