/*
  Class representing display in Screen preferences

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		2015

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  Free Software Foundation, Inc.
  59 Temple Place - Suite 330
  Boston, MA  02111-1307, USA
*/
#import "ScreenCanvas.h"
#import "DisplayBox.h"

@implementation DisplayBox

@synthesize displayFrame;
@synthesize displayName;

- initWithFrame:(NSRect)frameRect
        display:(NXDisplay *)aDisplay
          owner:(id)prefs
{
  NSRect nameRect;
  
  self = [super initWithFrame:frameRect];
  [self setBorderType:NSLineBorder];
  [self setTitlePosition:NSNoTitle];
  [self setContentViewMargins:NSMakeSize(1, 1)];
  [self setCursor:[NSCursor openHandCursor]];

  owner = prefs;
  
  // display = aDisplay;

  nameRect = frameRect;
  nameRect.size.height = 15;
  nameRect.size.width -= 2;
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
  NSColor *color;
  
  if (active)
    {
      color = [[NXScreen sharedScreen] savedBackgroundColor];
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

- (void)setCursor:(NSCursor *)c
{
  if (_cursor) [_cursor release];
  _cursor = c;
  [_cursor retain];
  
  [[self window] resetCursorRects];
}

- (NSCursor *)cursor
{
  return _cursor;
}

// NSView override
- (void)resetCursorRects
{
  NSView *contentView = [[self window] contentView];
  
  // NSLog(@"DisplayBox: resetCursorRects");
  [[self superview] discardCursorRects];

  if (!_cursor)
    {
      [self setCursor:[NSCursor arrowCursor]];
    }
  else
    {
      [contentView addCursorRect:[contentView frame]
                          cursor:[NSCursor arrowCursor]];
    }
  
  [[self superview] addCursorRect:[self frame] cursor:_cursor];
}

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
      PSlineto(1.5, rect.size.height-1.5);
      PSlineto(rect.size.width-1.5, rect.size.height-1.5);
      PSlineto(rect.size.width-1.5, 1.5);
      PSlineto(1.5, 1.5);
      PSstroke();
    }

  if (!isActiveDisplay) return;
  
  // Draw dock and icon yard
  NSSize  iSize;
  NSPoint iPoint;
  if (isMainDisplay)
    {
      iSize = [owner.dockImage size];
      iPoint = NSMakePoint(rect.size.width-iSize.width-3,
                           rect.size.height-iSize.height-3);
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
