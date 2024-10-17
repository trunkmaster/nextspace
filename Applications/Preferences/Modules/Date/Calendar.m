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

#import "Calendar.h"
#include "Foundation/NSObjCRuntime.h"

@implementation Calendar

- (void)dealloc
{
  [imageWeeks release];
  [imageDays release];
  [imageDaysH release];

  [super dealloc];
}

- (void)drawRect:(NSRect)calendar
{
  NSBundle *bundle;
  NSString *imagePath;
  int startColumn = 0;

  bundle = [NSBundle bundleForClass:[self class]];

  imageWeeks = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"weeks"
                                                                        ofType:@"tiff"]];
  imageDays = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"days"
                                                                       ofType:@"tiff"]];
  imageDaysH = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"daysH"
                                                                        ofType:@"tiff"]];

  {
    NSInteger dow = [currentDate dayOfWeek];
    NSInteger fullWeeks = [currentDate dayOfMonth] / 7;
    startColumn = (dow + 1) - ([currentDate dayOfMonth] - (fullWeeks * 7));
  }
  
  if (imageWeeks) {
    unsigned dayDestOffset = 18;
    unsigned daySourceOffset = 17;
    unsigned weekDestOffset = 16;
    unsigned weekSourceOffset = 13;
    unsigned endDayOfWeek = 7;
    int xSource, xDest, ySource, yDest;

    [imageWeeks compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeSourceOver];

    xSource = 0;
    ySource = 91;
    xDest = (startColumn * dayDestOffset) + 1;
    yDest = 82;
    for (unsigned dom = 0; dom < numberOfDaysInMonth; dom += 7) {
      if ((dom + 7) >= numberOfDaysInMonth) {
        endDayOfWeek -= ((dom + 7) - numberOfDaysInMonth);
      }
      for (unsigned dow = 0; dow < endDayOfWeek; dow++) {
        if ([currentDate dayOfMonth] == (dom + 1 + dow)) {
          [imageDaysH drawAtPoint:NSMakePoint(xDest, yDest)
                        fromRect:NSMakeRect(xSource, ySource, 17, 13)
                       operation:NSCompositeHighlight
                        fraction:1.0];
        } else {
          [imageDays drawAtPoint:NSMakePoint(xDest, yDest)
                        fromRect:NSMakeRect(xSource, ySource, 17, 13)
                       operation:NSCompositeHighlight
                        fraction:1.0];
        }
        xDest += dayDestOffset;
        xSource += daySourceOffset;
      }
      xDest = 1;
      xSource = 0;
      yDest -= weekDestOffset;
      ySource -= weekSourceOffset;
    }
  } else {
    [[NSColor redColor] set];
    NSLog(@"Image not found");
  }
}

- (void)setDate:(NSCalendarDate *)date
{
  currentDate = date;
  numberOfDaysInMonth = [date lastDayOfGregorianMonth:[date monthOfYear] year:[date yearOfCommonEra]];
  [self setNeedsDisplay:YES];
}

- (NSCalendarDate *)date
{
  return currentDate;
}

@end
