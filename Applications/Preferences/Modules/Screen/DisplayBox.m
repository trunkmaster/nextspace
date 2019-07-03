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

#import "ScreenCanvas.h"
#import "DisplayBox.h"

@implementation DisplayBox

@synthesize displayFrame;
@synthesize displayName;

- initWithFrame:(NSRect)frameRect
        display:(OSEDisplay *)aDisplay
          owner:(id)prefs
{
  NSRect nameRect;
  
  self = [super initWithFrame:frameRect];
  [self setBorderType:NSLineBorder];
  [self setTitlePosition:NSNoTitle];
  [self setContentViewMargins:NSMakeSize(1, 1)];

  owner = prefs;
  
  _display = aDisplay;

  nameRect = frameRect;
  nameRect.size.height = 15;
  nameRect.size.width -= 15;
  nameRect.origin.x = 0;
  nameRect.origin.y = (frameRect.size.height - nameRect.size.height)/2;

  nameField = [[NSTextField alloc] initWithFrame:nameRect];
  [nameField setEditable:NO];
  [nameField setSelectable:NO];
  [nameField setDrawsBackground:NO];
  [nameField setTextColor:[NSColor whiteColor]];
  [nameField setAlignment:NSCenterTextAlignment];
  [nameField setBezeled:NO];

  [self addSubview:nameField];
  [nameField release];
  
  isMainDisplay = NO;

  return self;
}

- (void)dealloc
{
  NSLog(@"Screen: display box %@: -dealloc", [nameField stringValue]);
  [super dealloc];
}

- (void)setActive:(BOOL)active
{
  CGFloat red, green, blue;
  NSColor *color;
  
  if (active)
    {
      [[OSEScreen sharedScreen] savedBackgroundColorRed:&red
                                                 green:&green
                                                  blue:&blue];
      color = [NSColor colorWithDeviceRed:red
                                    green:green
                                     blue:blue
                                    alpha:1.0];
      [nameField setTextColor:[NSColor whiteColor]];
    }
  else
    {
      color = [NSColor darkGrayColor];
      [nameField setTextColor:[NSColor lightGrayColor]];
    }
  ASSIGN(bgColor, color);
  
  isActiveDisplay = active;
  
  [[self superview] setNeedsDisplay:YES];
}

- (BOOL)isActive
{
  return isActiveDisplay;
}

- (void)setMain:(BOOL)isMain
{
  isMainDisplay = isMain;
  [[self superview] setNeedsDisplay:YES];
}

- (BOOL)isMain
{
  return isMainDisplay;
}

- (void)setSelected:(BOOL)selected
{
  isSelected = selected;
  [self setNeedsDisplay:YES];
}

- (NSPoint)centerPoint
{
  return NSMakePoint(NSMidX(self.frame), NSMidY(self.frame));
}

// NSView override
- (void)mouseDown:(NSEvent *)theEvent
{
  if ([theEvent clickCount] >= 2)
    {
      // Set main display
    }
  else
    {
      [(ScreenCanvas *)[[self superview] superview] mouseDown:theEvent
                                                        inBox:self];
    }
}

- (void)drawRect:(NSRect)rect
{
  NSRect boxFrame = [self frame];
  
  [super drawRect:rect];

  [nameField setStringValue:displayName];
  
  [bgColor set];
  NSRectFill([[self contentView] frame]);

  // Draw red frame
  if (isSelected)
    {
      NSColor *selColor;

      selColor = [NSColor colorWithDeviceRed:1.0
                                       green:221.0/255.0
                                        blue:0.0
                                       alpha:1];

      // [[NSColor yellowColor] set];
      [selColor set];
      PSnewpath();
      PSmoveto(1.5,1.5);
      PSlineto(1.5, boxFrame.size.height-1.5);
      PSlineto(boxFrame.size.width-1.5, boxFrame.size.height-1.5);
      PSlineto(boxFrame.size.width-1.5, 1.5);
      PSlineto(1.5, 1.5);
      PSstroke();
    }

  if (!isActiveDisplay) return;
  
  // Draw dock and icon yard
  NSSize  iSize = [owner.dockImage size];
  NSPoint iPoint = NSMakePoint(boxFrame.size.width-iSize.width-3,
                               boxFrame.size.height-iSize.height-3);
  if (isMainDisplay)
    {
      [owner.dockImage compositeToPoint:iPoint
                              operation:NSCompositeSourceOver];
      
      iSize = [owner.appIconYardImage size];
      iPoint = NSMakePoint(3,3);
      [owner.appIconYardImage compositeToPoint:iPoint
                                     operation:NSCompositeSourceOver];
    }
  else
    {
      iPoint = NSMakePoint(3,3);
      iSize = [[owner iconYardImage] size];
      [owner.iconYardImage compositeToPoint:iPoint
                                  operation:NSCompositeSourceOver];
      iPoint.x += iSize.width;
      [owner.iconYardImage compositeToPoint:iPoint
                                  operation:NSCompositeSourceOver];
    }
}

@end
