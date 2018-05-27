/*
  Class:               NXIconBadge
  Inherits from:       NSView
  Class descritopn:    The badge that provides additional information for 
                       appicon or icon. Draws background and sunken text.

  Copyright (C) 2018 Sergii Stoian

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

#import <AppKit/AppKit.h>

#import "NXIconBadge.h"

@implementation NXIconBadge

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
  rect.size = [NXIconBadge sizeForString:text withFont:font];
  
  [super initWithFrame:rect];
  
  string = [[NSMutableString alloc] initWithString:text];

  if (tColor)
    {
      textAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                  tColor, NSForegroundColorAttributeName,
                                font, NSFontAttributeName, nil];
      [textAttrs retain];
    }

  if (sColor)
    {
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
  vFrame.size = [NXIconBadge sizeForString:string withFont:font];
  
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
  
  if (shadowAttrs)
    {
      point.x++;
      point.y--;
      [string drawAtPoint:point withAttributes:shadowAttrs];
    }
  if (textAttrs)
    {
      point.x--;
      point.y++;
      [string drawAtPoint:point withAttributes:textAttrs];
    }
}

@end
