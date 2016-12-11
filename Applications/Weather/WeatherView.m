/*
  Class:               WeatherView
  Inherits from:       NSView
  Class descritopn:    Dock app with weather conditions

  Copyright (C) 2016 Sergii Stoian

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

@implementation SunkenString

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

static int icon_number = 0;

@implementation WeatherView : NSView

- (BOOL)acceptsFirstMouse:(NSEvent *)anEvent
{
  return YES;
}

- (void)mouseDown:(NSEvent *)event
{
  NSLog(@"mouseDown:");
  if ([event clickCount] >= 2)
    {
      [NSApp activateIgnoringOtherApps:YES];
    }
  else
    {
      if (icon_number > 47)
        icon_number = 0;
      else
        icon_number++;
      
      [self
        setImage:[NSImage
                   imageNamed:[NSString
                                stringWithFormat:@"%i.png", icon_number]]];
    }    
}

- (id)initWithFrame:(NSRect)frameRect
{
  [super initWithFrame:frameRect];

  conditionImage = [[NSImage imageNamed:@"3200.png"] copy];

  temperature = [[SunkenString alloc]
                  initWithString:@"°"
                            font:[NSFont boldSystemFontOfSize:16]
                      lightColor:[NSColor lightGrayColor]
                       darkColor:[NSColor blackColor]];
  
  humidity = [[SunkenString alloc]
                  initWithString:@"%"
                            font:[NSFont systemFontOfSize:10]
                      lightColor:[NSColor grayColor]
                       darkColor:[NSColor blackColor]];

  return self;
}

- (void)drawRect:(NSRect)rect
{
  [[NSImage imageNamed:@"common_Tile"] compositeToPoint:NSMakePoint(0, 0)
                                              operation:NSCompositeSourceOver];
  [conditionImage
    compositeToPoint:NSMakePoint((64-[conditionImage size].width)/2,
                                 58-[conditionImage size].height)
           operation:NSCompositeSourceOver];
  
  [temperature drawAtPoint:NSMakePoint(8, 0)];
  [humidity drawAtPoint:NSMakePoint(64-[humidity width]-4, 2)];
  
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
  NSSize imageSize = [image size];
  
  if (conditionImage != nil)
    [conditionImage release];
  
  conditionImage = [image copy];
  [conditionImage setScalesWhenResized:YES];
  imageSize.width -= 6;
  imageSize.height -= 6;
  [conditionImage setSize:imageSize];
  
  [self setNeedsDisplay:YES];
}

- (void)setTemperature:(NSString *)temp
{
  [temperature setStringValue:[NSString stringWithFormat:@"%@°", temp]];
}

- (void)setHumidity:(NSString *)hum
{
  [humidity setStringValue:[NSString stringWithFormat:@"%@%%", hum]];
}

@end
