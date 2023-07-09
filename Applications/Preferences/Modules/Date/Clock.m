/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
// Copyright (C) 2022-2023 Andres Morales
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


#import <Clock.h>

@implementation Clock : NSView

- (void) setImage: (NSImage *)image
{
  NSString *imagePath;
  NSBundle *bundle;

  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource: @"ClockView" ofType: @"tiff"];
  imageClock = [[NSImage alloc] initWithContentsOfFile: imagePath];

  [self setNeedsDisplay:YES];
}

- (void) drawRect:(NSRect)clock
{
  NSDictionary *clockRects;

  clockRects = @{@"DayOfWeek":NSStringFromRect(NSMakeRect(14, 33, 33, 6)),
                       @"Day":NSStringFromRect(NSMakeRect(14, 15, 33, 17)),
                     @"Month":NSStringFromRect(NSMakeRect(14,  9, 31, 6)),
                      @"Time":NSStringFromRect(NSMakeRect( 5, 46, 53, 11))};

  clockView = [[NXTClockView alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)
                                             tile:[NSImage imageNamed:@"standard"]
                                     displayRects:clockRects];

}

@end
