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

- (id)initWithString:(NSString *)text
                font:(NSFont *)sFont
          lightColor:(NSColor *)lColor
           darkColor:(NSColor *)dColor
{
  [super init];
  
  string = [[NSMutableString alloc] initWithString:text];

  stringAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                dColor, NSForegroundColorAttributeName,
                              sFont, NSFontAttributeName, nil];
  [stringAttrs retain];
  highlightAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                   lColor, NSForegroundColorAttributeName,
                                 sFont, NSFontAttributeName, nil];
  [highlightAttrs retain];

  return self;
}

- (void)dealloc
{
  [string release];
  [stringAttrs release];
  [highlightAttrs release];
  
  [super dealloc];
}

- (NSString *)stringValue
{
  return string;
}

- (void)setStringValue:(NSString *)text
{
  [string release];
  string = [[NSMutableString alloc] initWithString:text];
}

- (NSUInteger)width
{
  return [[stringAttrs objectForKey:NSFontAttributeName] widthOfString:string];
}

- (void)drawAtPoint:(NSPoint)point
{
  point.x++;
  point.y--;
  [string drawAtPoint:point withAttributes:highlightAttrs];
  point.x--;
  point.y++;
  [string drawAtPoint:point withAttributes:stringAttrs];
}

@end
