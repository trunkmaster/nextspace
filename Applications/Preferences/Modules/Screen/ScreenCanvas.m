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

#import <AppKit/AppKit.h>

#import <SystemKit/OSEMouse.h>
#import <GNUstepGUI/GSDisplayServer.h>

#import "ScreenCanvas.h"
#import "DisplayBox.h"
#import "Screen.h"

@interface FlippedView : NSView
{
}
@end

@implementation FlippedView

- (BOOL)isFlipped
{
  return YES;
}

@end

@implementation ScreenCanvas

- initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  [self setBorderType:NSBezelBorder];
  [self setTitlePosition:NSNoTitle];
  [self setFillColor:[NSColor grayColor]];
  [self setContentViewMargins:NSMakeSize(0, 0)];
  [self setContentView:[[FlippedView new] autorelease]];

  isMouseDragged = NO;
  
  return self;
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect:rect];

  [_fill_color set];
  NSRectFill([[self contentView] frame]);

  // [self resetCursorRects];

  // CGFloat f, lines = rect.size.height;
  // CGFloat pattern[2] = {1};
  // [[NSColor darkGrayColor] set];
  // PSsetdash(pattern, 1, 0);
  // for (f=2; f<lines-2; f++)
  //   {
  //     PSmoveto(2, f);
  //     PSlineto(rect.size.width, f);
  //     f++;
  //     PSmoveto(3, f);
  //     PSlineto(rect.size.width-2, f);
  //   }
  // PSstroke();
}

- (void)resetCursorRects
{
  // NSLog(@"ScreenCanvas: resetCursorRects");

  [[self window] discardCursorRects];
  for (NSView *sview in [[self contentView] subviews])
    {
      [self addCursorRect:[sview frame]
                   cursor:[NSCursor openHandCursor]];
    }
}

- (DisplayBox *)lowerBoxForBox:(DisplayBox *)box
{
  NSRect     boxFrame = [box frame];
  DisplayBox *boxUnder = nil;

  for (DisplayBox *db in [[self contentView] subviews])
    {
      if (db == box)
        continue;
      
      if (NSIntersectsRect(boxFrame, [db frame]) == YES)
        {
          boxUnder = db;
          break;
        }
    }

  return boxUnder;
}

- (DisplayBox *)closestBoxForBox:(DisplayBox *)box
{
  NSPoint    closestPoint = NSMakePoint(CGFLOAT_MAX, CGFLOAT_MAX);
  DisplayBox *closestBox = nil;

  for (DisplayBox *db in [[self contentView] subviews])
    {
      if (db == box)
        continue;
      
      if (closestPoint.x > db.frame.origin.x &&
          closestPoint.y > db.frame.origin.y)
        {
          closestPoint = db.frame.origin;
          closestBox = db;
        }
    }

  return closestBox;
}

- (void)slideBox:(DisplayBox *)box initialOrigin:(NSPoint)origin
{
  DisplayBox *closestBox = [self closestBoxForBox:box];
  NSPoint    initialOrigin = origin;

  if (closestBox != nil)
    {
      NSPoint buCPoint = [closestBox centerPoint];
      NSPoint bCPoint = [box centerPoint];
      
      if (bCPoint.x < buCPoint.x)
        {
          if (bCPoint.x < NSMinX(closestBox.frame))
            origin.x = NSMinX(closestBox.frame) - box.frame.size.width;
          else
            origin.x = NSMinX(closestBox.frame);
        }
      else if (bCPoint.x > buCPoint.x)
        {
          if (bCPoint.x > NSMaxX(closestBox.frame))
            origin.x = NSMaxX(closestBox.frame);
          else
            origin.x = NSMaxX(closestBox.frame) - box.frame.size.width;
        }
      
      if (bCPoint.y < buCPoint.y)
        {
          if (bCPoint.y < NSMinY(closestBox.frame))
            origin.y = NSMinY(closestBox.frame) - box.frame.size.height;
          else
            origin.y = NSMinY(closestBox.frame);
        }
      else if (bCPoint.y > buCPoint.y)
        {
          if (bCPoint.y > NSMaxY(closestBox.frame))
            origin.y = NSMaxY(closestBox.frame);
          else
            origin.y = NSMaxY(closestBox.frame) - box.frame.size.height;
        }
    }

  // {
  //   NSBitmapImageRep	*imgRep;
  //   NSImage		*image;

  //   [box lockFocus];
  //   imgRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[box bounds]];
  //   [box unlockFocus];
  //   image = [[NSImage alloc] initWithData:[imgRep TIFFRepresentation]];

  //   [[NSWorkspace sharedWorkspace]
  //     slideImage:image
  //           from:[self convertRectToBase:box.frame].origin
  //             to:origin];
  //   [imgRep release];
  //   [image release];
  // }

  [box setFrameOrigin:origin];

  if (NSEqualPoints(initialOrigin, origin) == NO)
    {
      [[NSNotificationCenter defaultCenter]
        postNotificationName:@"DisplayBoxPositionDidChange"
                      object:box];
    }
}

- (NSRect)boxGroupRect
{
  NSRect groupRect = NSMakeRect(-1,-1,0,0);

  for (DisplayBox *db in [[self contentView] subviews])
    {
      if (db.frame.origin.x < groupRect.origin.x)
        { // Extend to the left
          groupRect.size.width += NSMinX(groupRect) - NSMinX(db.frame);
          groupRect.origin.x = db.frame.origin.x;
        }
      else
        { // Extend to the right
          if (NSMaxX(db.frame) > NSMaxX(groupRect))
            groupRect.size.width += db.frame.size.width;
          if (groupRect.origin.x < 0 ) // this is the first time we'll touch it
            groupRect.origin.x = db.frame.origin.x;
        }
      
      if (db.frame.origin.y < groupRect.origin.y)
        { // Extend to the top
          groupRect.size.height += NSMinY(groupRect) - NSMinY(db.frame);
          groupRect.origin.y = db.frame.origin.y;
        }
      else
        { // Extend to the bottom
          if (groupRect.origin.y < 0)  // this is the first time we'll touch it
            groupRect.origin.y = db.frame.origin.y;
          if (NSMaxY(db.frame) > NSMaxY(groupRect))
            groupRect.size.height += NSMaxY(db.frame) - NSMaxY(groupRect);
        }
      NSLog(@"box = %@, groupRect = %@",
            NSStringFromRect(db.frame), NSStringFromRect(groupRect));
    }

  return groupRect;
}

- (void)centerBoxes
{
  CGFloat xOffset = .0, yOffset = .0;
  NSRect  groupRect = [self boxGroupRect];
  NSPoint bOrigin;

  // NSLog(@"canvas = %.0f group = %.0f",
  //       NSWidth([self frame]), NSWidth(groupRect));
  xOffset = floorf(((NSWidth([self frame]) - NSWidth(groupRect)) / 2));
  yOffset = floorf(((NSHeight([self frame]) - NSHeight(groupRect)) / 2));
  // NSLog(@"groupRect = %@", NSStringFromRect(groupRect));
  // NSLog(@"xOffset = %.0f, yOffset = %.0f", xOffset, yOffset);
  
  for (DisplayBox *db in [[self contentView] subviews])
    {
      bOrigin = db.frame.origin;
      // NSLog(@"initial box origin = %@", NSStringFromPoint(bOrigin));
      bOrigin.x = (bOrigin.x - groupRect.origin.x) + xOffset;
      bOrigin.y = (bOrigin.y - groupRect.origin.y) + yOffset;
      // NSLog(@"set new box origin = %@", NSStringFromPoint(bOrigin));
      [db setFrameOrigin:bOrigin];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
            inBox:(DisplayBox *)box
{
  NSWindow   *window = [self window];
  NSRect     canvasFrame = [[self contentView] frame];
  NSRect     boxFrame = [box frame];
  NSPoint    location, initialLocation, lastLocation;
  
  NSPoint    initialOrigin, boxOrigin;
  NSUInteger eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                          | NSPeriodicMask | NSOtherMouseUpMask
                          | NSRightMouseUpMask);
  NSDate     *theDistantFuture = [NSDate distantFuture];
  BOOL       done = NO;
  NSInteger  moveThreshold;

  initialOrigin = boxOrigin = boxFrame.origin;
  initialLocation = lastLocation = [theEvent locationInWindow];

  moveThreshold = [[[OSEMouse new] autorelease] accelerationThreshold];
  [[NSCursor closedHandCursor] push];
  
  [NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.02];

  while (!done)
    {
      theEvent = [NSApp nextEventMatchingMask:eventMask
                                    untilDate:theDistantFuture
                                       inMode:NSEventTrackingRunLoopMode
                                      dequeue:YES];

      switch ([theEvent type])
        {
        case NSRightMouseUp:
        case NSOtherMouseUp:
        case NSLeftMouseUp:
          // NSLog(@"Mouse UP.");
          if (NSEqualPoints(initialLocation, location) == NO)
            {
              [self slideBox:box initialOrigin:initialOrigin];
              [self centerBoxes];
            }
          // Reset mouse cursor to cursor befor mouse down - openHandCursor.
          // TODO: on momentary mouse down/up (without drag) cursor turns
          // into arrowCursor. This is wrong. Perhaps this is due to old and
          // new cursor rects intersection.
          [NSCursor pop];
          [self resetCursorRects];
          [self setNeedsDisplay:YES];
          done = YES;
          break;
        case NSPeriodic:
          location = [window mouseLocationOutsideOfEventStream];
          
          if (!NSPointInRect(location, [self frame]))
            break;
          
          if (NSEqualPoints(location, lastLocation) == NO &&
              (fabs(location.x - initialLocation.x) > moveThreshold ||
               fabs(location.y - initialLocation.y) > moveThreshold))
            {
              boxOrigin.x += (location.x - lastLocation.x);
              if (boxOrigin.x < 0)
                {
                  boxOrigin.x = 0;
                }
              else if ((boxOrigin.x + boxFrame.size.width)
                       >= canvasFrame.size.width)
                {
                  boxOrigin.x = canvasFrame.size.width - boxFrame.size.width;
                }

              // Content view is flipped - reverse increment
              boxOrigin.y -= (location.y - lastLocation.y);
              if (boxOrigin.y < 0)
                {
                  boxOrigin.y = 0;
                }
              else if ((boxOrigin.y + boxFrame.size.height)
                       >= canvasFrame.size.height)
                {
                  boxOrigin.y = canvasFrame.size.height - boxFrame.size.height;
                }
                  
              [box setFrameOrigin:boxOrigin];
              [self setNeedsDisplay:YES];
                  
              lastLocation = location;
            }
          break;

        default:
          break;
        }
    }
  [NSEvent stopPeriodicEvents];

  if (NSEqualPoints(initialLocation, lastLocation) == YES)
    {
      [owner displayBoxClicked:box];
    }
}

@end
