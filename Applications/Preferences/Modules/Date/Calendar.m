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
#import <Foundation/NSCalendar.h>

@implementation Calendar

- (void)drawRect:(NSRect)calendar
{
  NSBundle *bundle;
  NSString *imagePathWeeks, *imagePathDays;
  int startColumn = 0;

  bundle = [NSBundle bundleForClass:[self class]];

  imagePathWeeks = [bundle pathForResource:@"weeks" ofType:@"tiff"];
  imageWeeks = [[NSImage alloc] initWithContentsOfFile:imagePathWeeks];

  imagePathDays = [bundle pathForResource:@"days" ofType:@"tiff"];
  imageDays = [[NSImage alloc] initWithContentsOfFile:imagePathDays];

  if (imageWeeks) {
    unsigned dayDestOffset = 18;
    unsigned daySourceOffset = 17;
    unsigned weekDestOffset = 16;
    unsigned weekSourceOffset = 13;
    unsigned endDayOfWeek = 7;
    int xSource, xDest, ySource, yDest;

    [imageWeeks compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeSourceOver];

    NSLog(@"Minmum days in first week: %lu", [[NSCalendar currentCalendar] firstWeekday]);

    xSource = 0;
    xDest = (startColumn * dayDestOffset) + 1;
    yDest = 82;
    ySource = 91;
    for (unsigned dom = 0; dom < numberOfDaysInMonth; dom += 7) {
      if ((dom + 7) >= numberOfDaysInMonth) {
        endDayOfWeek -= ((dom + 7) - numberOfDaysInMonth);
      }
      for (unsigned dow = 0; dow < endDayOfWeek; dow++) {
        [imageDays drawAtPoint:NSMakePoint(xDest, yDest)
                      fromRect:NSMakeRect(xSource, ySource, 17, 13)
                     operation:NSCompositeHighlight
                      fraction:1.0];
        xDest += dayDestOffset;
        xSource += daySourceOffset;
      }
      xDest = 1;
      xSource = 0;
      yDest -= weekDestOffset;
      ySource -= weekSourceOffset;
    }
  }

  // if (imageWeeks) {
  //   [imageWeeks compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeSourceOver];

  //   for (n = 1; n <= 109; n += 18) {
  //     [imageDays drawAtPoint:NSMakePoint(n, 82)
  //                  fromRect:NSMakeRect(x, 91, 17, 13)
  //                 operation:NSCompositeHighlight
  //                  fraction:1.0];  // 1

  //     [imageDays drawAtPoint:NSMakePoint(n, 66)
  //                  fromRect:NSMakeRect(x, 78, 17, 13)
  //                 operation:NSCompositeHighlight
  //                  fraction:1.0];  // 2

  //     [imageDays drawAtPoint:NSMakePoint(n, 50)
  //                  fromRect:NSMakeRect(x, 65, 17, 13)
  //                 operation:NSCompositeHighlight
  //                  fraction:1.0];  // 3

  //     [imageDays drawAtPoint:NSMakePoint(n, 34)
  //                  fromRect:NSMakeRect(x, 52, 17, 13)
  //                 operation:NSCompositeHighlight
  //                  fraction:1.0];  // 4

  //     [imageDays drawAtPoint:NSMakePoint(n, 18)
  //                  fromRect:NSMakeRect(x, 39, 17, 13)
  //                 operation:NSCompositeHighlight
  //                  fraction:1.0];  // 5

  //     [imageDays drawAtPoint:NSMakePoint(n, 2)
  //                  fromRect:NSMakeRect(x, 26, 17, 13)
  //                 operation:NSCompositeHighlight
  //                  fraction:1.0];  // 6
  //     x += 17;
  //   }
  // } else {
  //   [[NSColor redColor] set];
  //   NSLog(@"Image not found");
  // }
}

- (void)setDate:(NSCalendarDate *)date
{
  currentDate = date;
  numberOfDaysInMonth = [date lastDayOfGregorianMonth:[date monthOfYear] year:[date yearOfCommonEra]];
  [self setNeedsDisplay:YES];
}

@end
