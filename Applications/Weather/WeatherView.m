/*
  Class:               WeatherView
  Inherits from:       NSView
  Class descritopn:    Dock app with weather conditions

  Copyright (C) 2016-present Sergii Stoian <stoyan255@gmail.com>

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

#import "WeatherView.h"

@interface SunkenString : NSObject
{
 @private
  NSMutableString *string;
  NSDictionary *stringAttrs;
  NSDictionary *shadowAttrs;
  NSDictionary *highlightAttrs;
}

- (id)initWithString:(NSString *)text
                font:(NSFont *)sFont
          lightColor:(NSColor *)lColor
           darkColor:(NSColor *)dColor
           textColor:(NSColor *)tColor;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)text;
- (void)setStringColor:(NSColor *)color;
- (NSUInteger)width;
- (NSUInteger)height;

- (void)drawAtPoint:(NSPoint)point;

@end

@implementation SunkenString

- (id)initWithString:(NSString *)text
                font:(NSFont *)sFont
          lightColor:(NSColor *)lColor
           darkColor:(NSColor *)dColor
           textColor:(NSColor *)tColor
{
  [super init];
  
  string = [[NSMutableString alloc] initWithString:text];

  stringAttrs = @{NSForegroundColorAttributeName : tColor, NSFontAttributeName : sFont};
  [stringAttrs retain];

  if (dColor != nil) {
    shadowAttrs = @{NSForegroundColorAttributeName : dColor, NSFontAttributeName : sFont};
    [shadowAttrs retain];
  }

  if (lColor != nil) {
    highlightAttrs = @{NSForegroundColorAttributeName : lColor, NSFontAttributeName : sFont};
    [highlightAttrs retain];
  }

  return self;
}

- (void)dealloc
{
  [string release];
  [stringAttrs release];
  [shadowAttrs release];
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

- (void)setStringColor:(NSColor *)color
{
  NSFont *sFont = stringAttrs[NSFontAttributeName];
  [stringAttrs release];
  stringAttrs = @{NSForegroundColorAttributeName : color, NSFontAttributeName : sFont};
  [stringAttrs retain];
}

- (NSUInteger)width
{
  return [[stringAttrs objectForKey:NSFontAttributeName] widthOfString:string];
}

- (NSUInteger)height
{
  return [[stringAttrs objectForKey:NSFontAttributeName] defaultLineHeightForFont];
}

- (void)drawAtPoint:(NSPoint)point
{
  point.x--;
  point.y++;
  if (shadowAttrs != nil) {
    [string drawAtPoint:point withAttributes:shadowAttrs];
  }
  point.x += 2;
  point.y -= 2;
  if (highlightAttrs != nil) {
    [string drawAtPoint:point withAttributes:highlightAttrs];
  }
  point.x--;
  point.y++;
  [string drawAtPoint:point withAttributes:stringAttrs];
}

@end

// static int icon_number = 0;

@implementation WeatherView : NSView

// - (BOOL)acceptsFirstMouse:(NSEvent *)anEvent
// {
//   return YES;
// }

// - (void)mouseDown:(NSEvent *)event
// {
//   NSLog(@"mouseDown:");
//   if ([event clickCount] >= 2) {
//     [NSApp activateIgnoringOtherApps:YES];
//   } else {
//     if (icon_number > 47) {
//       icon_number = 0;
//     } else {
//       icon_number++;
//     }
//     [self setImage:[NSImage imageNamed:[NSString stringWithFormat:@"%i.png", icon_number]]];
//   }
// }

- (id)initWithFrame:(NSRect)frameRect
{
  [super initWithFrame:frameRect];

  conditionImage = [[NSImage imageNamed:@"na.png"] copy];

  tempPositiveColor = [NSColor colorWithDeviceRed:(120.0 / 255.0) green:0.0 blue:0.0 alpha:1.0];
  [tempPositiveColor retain];
  tempNegativeColor = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:(120.0 / 255.0) alpha:1.0];
  [tempNegativeColor retain];

  temperature = [[SunkenString alloc] initWithString:@"°"
                                                font:[NSFont boldSystemFontOfSize:22]
                                          lightColor:[NSColor lightGrayColor]
                                           darkColor:nil
                                           textColor:tempPositiveColor];

  humidity = [[SunkenString alloc] initWithString:@"%"
                                             font:[NSFont systemFontOfSize:9]
                                       lightColor:nil
                                        darkColor:nil
                                        textColor:[NSColor textColor]];

  return self;
}

- (void)drawRect:(NSRect)rect
{
  [[NSImage imageNamed:@"common_Tile"] compositeToPoint:NSMakePoint(0, 0)
                                              operation:NSCompositeSourceOver];
  [conditionImage compositeToPoint:NSMakePoint(4, (62 - [conditionImage size].height))
                         operation:NSCompositeSourceOver];

  [temperature drawAtPoint:NSMakePoint((64 - [temperature width]) / 2.0, [humidity height])];
  [humidity drawAtPoint:NSMakePoint(4, 2)];
  
  [super drawRect:rect];
}

- (void)dealloc
{
  [conditionImage release];
  [temperature release];
  [humidity release];
  
  [super dealloc];
}

- (void)setImage:(NSImage *)image
{
  if (conditionImage != nil) {
    [conditionImage release];
  }
  conditionImage = [image copy];
  [conditionImage setScalesWhenResized:NO];
  
  [self setNeedsDisplay:YES];
}

- (void)setTemperature:(NSString *)temp
{
  if ([temp containsString:@"-"]) {
    [temperature setStringColor:tempNegativeColor];
  } else {
    [temperature setStringColor:tempPositiveColor];
  }
  [temperature setStringValue:[NSString stringWithFormat:@"%@°", temp]];
}

- (void)setHumidity:(NSString *)hum
{
  [humidity setStringValue:[NSString stringWithFormat:@"Humidity: %@%%", hum]];
}

@end
