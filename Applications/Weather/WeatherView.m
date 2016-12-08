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

  // lightTempAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
  //                                  NSColorAttributeName,
  //                                [NSColor lightGrayColor],
  //                                NSFontAttributeName,
  //                                [NSFont boldSystemFontOfSize:16]];
  // tempString = [[NSMutableString alloc] initWithString:@"***"
  //                                           attributes:];

  temperatureW = [[NSTextField alloc] initWithFrame:NSMakeRect(9, 0, 46, 18)];
  [temperatureW setBezeled:NO];
  [temperatureW setBordered:NO];
  [temperatureW setDrawsBackground:NO];
  [temperatureW setEditable:NO];
  [temperatureW setSelectable:NO];
  [temperatureW setAlignment:NSCenterTextAlignment];
  [temperatureW setFont:[NSFont boldSystemFontOfSize:16]];
  [temperatureW setTextColor:[NSColor lightGrayColor]];
  [temperatureW setStringValue:@"***"];
  
  temperatureB = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 1, 48, 18)];
  [temperatureB setBezeled:NO];
  [temperatureB setBordered:NO];
  [temperatureB setDrawsBackground:NO];
  [temperatureB setEditable:NO];
  [temperatureB setSelectable:NO];
  [temperatureB setAlignment:NSCenterTextAlignment];
  [temperatureB setFont:[NSFont boldSystemFontOfSize:16]];
  [temperatureB setTextColor:[NSColor blackColor]];
  [temperatureB setStringValue:@"***"];

  [self addSubview:temperatureW];
  [self addSubview:temperatureB];

  return self;
}

- (void)drawRect:(NSRect)rect
{
  [[NSImage imageNamed:@"common_Tile"] compositeToPoint:NSMakePoint(0, 0)
                                              operation:NSCompositeSourceOver];
  [conditionImage compositeToPoint:NSMakePoint(9, 14)
                         operation:NSCompositeSourceOver];
  [super drawRect:rect];
}

- (void)dealloc
{
  // [imageView release];
  [conditionImage release];
  [temperatureW release];
  [temperatureB release];
  [super dealloc];
}

- (void)setImage:(NSImage *)image
{
  // [imageView setImage:image];
  if (conditionImage != nil)
    [conditionImage release];
  
  conditionImage = [image copy];
  [self setNeedsDisplay:YES];
}

- (void)setTemperature:(NSString *)temp
{
  [temperatureW setStringValue:[NSString stringWithFormat:@"%@°", temp]];
  [temperatureB setStringValue:[NSString stringWithFormat:@"%@°", temp]];
}

@end
