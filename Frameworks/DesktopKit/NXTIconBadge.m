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

#import <AppKit/AppKit.h>

#import "NXTIconBadge.h"

@implementation NXTIconBadge

+ (NSSize)sizeForString:(NSString *)text
               withFont:(NSFont *)sFont
{
  NSSize size = NSMakeSize(0,0);

  size.width = [sFont widthOfString:text] + 2;
  size.height = [sFont boundingRectForFont].size.height;

  return size;
}

- (id)initWithPoint:(NSPoint)position
               text:(NSString *)text
               font:(NSFont *)font
          textColor:(NSColor *)tColor
        shadowColor:(NSColor *)sColor
{
  NSRect rect = NSMakeRect(position.x, position.y, 0, 0);
  rect.size = [NXTIconBadge sizeForString:text withFont:font];
  
  [super initWithFrame:rect];
  
  string = [[NSMutableString alloc] initWithString:text];

  if (tColor) {
    textAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                tColor, NSForegroundColorAttributeName,
                              font, NSFontAttributeName, nil];
    [textAttrs retain];
  }

  if (sColor) {
    shadowAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                  sColor, NSForegroundColorAttributeName,
                                font, NSFontAttributeName, nil];
    [shadowAttrs retain];
  }

  return self;
}

- (void)setAlignment:(NSTextAlignment)mode
{
}

- (void)dealloc
{
  [string release];
  [textAttrs release];
  [shadowAttrs release];
  
  [super dealloc];
}

- (NSString *)stringValue
{
  return string;
}
- (void)setStringValue:(NSString *)text
{
  NSRect vFrame = [self frame];
  NSFont *font = [textAttrs objectForKey:NSFontAttributeName];

  [string setString:text];

  // Adopt size of view to the new string
  vFrame.size = [NXTIconBadge sizeForString:string withFont:font];
  
  [self setFrame:vFrame];
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
  NSRect  vFrame = [self frame];
  NSPoint point = vFrame.origin;

  point.x = 0;
  point.y = 0;

  [super drawRect:rect];
  
  if (shadowAttrs) {
    point.x++;
    point.y--;
    [string drawAtPoint:point withAttributes:shadowAttrs];
  }
  if (textAttrs) {
    point.x--;
    point.y++;
    [string drawAtPoint:point withAttributes:textAttrs];
  }
}

@end
