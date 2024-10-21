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

@implementation Calendar

- (void)dealloc
{
  [imageWeeks release];
  [imageWeeksMonday release];
  [imageDays release];
  [imageDaysH release];

  [super dealloc];
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
  [super initWithFrame:frameRect];
  [self setDate:[NSCalendarDate now]];
  NSLog(@"First weekday: %lu", [[NSCalendar currentCalendar] firstWeekday]);
  return self;
}

- (NSInteger)_startWeekdayOfMonth
{
  NSCalendarDate *monthDate = [NSCalendarDate dateWithYear:[currentDate yearOfCommonEra]
                                                     month:[currentDate monthOfYear]
                                                       day:1
                                                      hour:0
                                                    minute:0
                                                    second:1
                                                  timeZone:[NSTimeZone localTimeZone]];
  NSInteger dayOfWeek = [monthDate dayOfWeek] + 1;

  if ([[NSCalendar currentCalendar] firstWeekday] == 2) { // Monday
    if (dayOfWeek == 1) {
      dayOfWeek = 7;
    } else {
      dayOfWeek -= 1;
    }
  }

  return dayOfWeek;
}

- (void)drawRect:(NSRect)rect
{
  NSBundle *bundle;

  bundle = [NSBundle bundleForClass:[self class]];

  imageWeeks = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"weeks"
                                                                        ofType:@"tiff"]];
  imageWeeksMonday = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"weeksMonday"
                                                                              ofType:@"tiff"]];
  imageDays = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"days"
                                                                       ofType:@"tiff"]];
  imageDaysH = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"daysH"
                                                                        ofType:@"tiff"]];
  
  if (imageWeeks) {
    NSInteger startDayOfWeek = [self _startWeekdayOfMonth];
    short endDayOfWeek = 7;
    CGFloat dayDestOffset = 18;
    CGFloat daySourceOffset = 17;
    CGFloat weekDestOffset = 16;
    CGFloat weekSourceOffset = 13;
    CGFloat xSource = 0;
    CGFloat ySource = 91;
    CGFloat xDest = ((startDayOfWeek - 1) * dayDestOffset) + 1;
    CGFloat yDest = 82;

    [imageWeeks compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeSourceOver];
    if ([[NSCalendar currentCalendar] firstWeekday] == 2) {
      xDest = ((startDayOfWeek - 1) * dayDestOffset) + 1;
      [imageWeeksMonday
          compositeToPoint:NSMakePoint(0, imageWeeks.size.height - imageWeeksMonday.size.height)
                 operation:NSCompositeSourceOver];
    }

    // for (unsigned dom = 0; dom < numberOfDaysInMonth; dom += 7) {
    unsigned short dayOfMonth = 1;
    while (dayOfMonth < numberOfDaysInMonth) {

      if (endDayOfWeek == 7 && (dayOfMonth + 7) > numberOfDaysInMonth) {
        endDayOfWeek -= ((dayOfMonth + 6) - numberOfDaysInMonth);
      }

      for (unsigned dayOfWeek = startDayOfWeek; dayOfWeek <= endDayOfWeek; dayOfWeek++) {
        if ([currentDate dayOfMonth] == dayOfMonth) {
          [imageDaysH drawAtPoint:NSMakePoint(xDest, yDest)
                        fromRect:NSMakeRect(xSource, ySource, 17, 13)
                       operation:NSCompositeSourceOver
                        fraction:1.0];
        } else {
          [imageDays drawAtPoint:NSMakePoint(xDest, yDest)
                        fromRect:NSMakeRect(xSource, ySource, 17, 13)
                       operation:NSCompositeSourceOver
                        fraction:1.0];
        }
        xDest += dayDestOffset;
        if (dayOfMonth % 7 == 0) {
          xSource = 0;
          ySource -= weekSourceOffset;
        } else {
          xSource += daySourceOffset;
        }
        dayOfMonth++;
      }
      startDayOfWeek = 1;
      endDayOfWeek = 7;
      // New row on screen
      xDest = 1;
      yDest -= weekDestOffset;
    }
  } else {
    [[NSColor redColor] set];
    NSLog(@"Image not found");
  }
}

- (void)setDate:(NSCalendarDate *)date
{
  ASSIGN(currentDate, date);
  numberOfDaysInMonth = [date lastDayOfGregorianMonth:[date monthOfYear] year:[date yearOfCommonEra]];
  [self setNeedsDisplay:YES];
}

- (NSCalendarDate *)date
{
  return currentDate;
}

@end
