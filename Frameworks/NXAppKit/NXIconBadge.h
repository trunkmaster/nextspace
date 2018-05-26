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

#import <AppKit/NSTextView.h>

@interface NXIconBadge : NSView
{
  NSMutableString *string;
  NSDictionary    *stringAttrs;
  NSDictionary    *highlightAttrs;
}

- (id)initWithString:(NSString *)text
                font:(NSFont *)sFont
          lightColor:(NSColor *)lColor
           darkColor:(NSColor *)dColor;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)text;
- (NSUInteger)width;

- (void)drawAtPoint:(NSPoint)point;

@end
