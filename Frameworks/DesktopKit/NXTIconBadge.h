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

/*
 * Class:               NXTIconBadge
 * Inherits from:       NSView
 * Class descritopn:    The badge that provides additional information for 
 *                      appicon or icon. Draws background and sunken text.
 */

#import <AppKit/NSView.h>
#import <AppKit/NSText.h>

@interface NXTIconBadge : NSView
{
  NSMutableString *string;
  NSDictionary    *textAttrs;
  NSDictionary    *shadowAttrs;
}

- (id)initWithPoint:(NSPoint)position
               text:(NSString *)text
               font:(NSFont *)font
          textColor:(NSColor *)tColor
        shadowColor:(NSColor *)sColor;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)text;
- (void)setAlignment:(NSTextAlignment)mode;

@end
