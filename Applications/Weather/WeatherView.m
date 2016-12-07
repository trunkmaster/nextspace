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

@implementation WeatherView : NSView

// 60 x 60
- (id)initWithFrame:(NSRect)frameRect
{
  [super initWithFrame:frameRect];
  
  imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(8, 14, 44, 44)];

  temperature = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 60, 12)];

  [self addSubview:imageView];
  [self addSubview:temperature];

  return self;
}

- (void)dealloc
{
  [imageView release];
  [temperature release];
  [super dealloc];
}

- (void)setImage:(NSImage *)image
{
  [imageView setImage:image];
}

- (void)setTemperature:(NSString *)temp
{
  [temperature setStringValue:temp];
}

@end
