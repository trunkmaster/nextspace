/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2005 Saso Kiselkov
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

/** @class NXTClockView
    @brief Classic NeXT-style clock.

    This class represents a classic NeXT-style clock as we know it
    from the Preferences app.
    
    Date views use one value in the defaults database (which they
    watch for changes if configured to do so): "NXTClockViewShows12HourFormat".
    If this key is set to "YES", then they display 12-hour AM/PM format.
    Otherwise they display 24-hour format time.

    @author Saso Kiselkov, Sergii Stoian
*/

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimer.h>
#import <AppKit/NSView.h>

@interface NXTClockView : NSView
{
  // Double-click target/action
  id		actionTarget;
  SEL		doubleAction;
  
  // The currently displayed date.
  NSCalendarDate *date;
  NSInteger      dayOfWeek, lastDOW;
  NSInteger      dayOfMonth, lastDOM;
  NSInteger      monthOfYear, lastMOY;
  NSInteger      hourOfDay, lastHOD;
  NSInteger      minuteOfHour, lastMOH;
  NSInteger      yearOfCommonEra, lastYOCE;

  NSTimer *updateTimer;
  BOOL    dateChanged;

  // Properties and state
  BOOL isAlive;
  BOOL is24HourFormat;
  BOOL isYearVisible;
  BOOL isTrackDefaults;
  BOOL isColonBlinking, isColonVisible;
  BOOL isMorning;

  NSImage *clockBits;
  NSImage *tileImage;
  NSRect  tileRect;

  // Day of week, month, day
  NSRect dowDisplayRect;
  NSRect mondayRect;
  NSRect dayDisplayRect;
  NSRect firstDayRect;
  NSRect monthDisplayRect;
  NSRect januaryRect;

  // LED time
  CGFloat timeOffset;
  NSRect  timeDisplayRect;
  NSRect  time_nums[10];
  NSRect  colonRect;
  NSRect  noColonRect;
  NSRect  colonDisplayRect;
  NSRect  amRect;
  NSRect  pmRect;

  // Year
  NSRect yearDisplayRect;
  NSRect year_nums[10];
}

//-----------------------------------------------------------------------------
#pragma mark - Init and dealloc
//-----------------------------------------------------------------------------
/** Loads 'clockbits.tiff' located in framework resources. */
- initWithFrame:(NSRect)aFrame;

/** Uses framework 'clockbits.tiff' for everything except tile image.
    `displayRects` is a dictionary with rects to place elements inside specified
    custom tile image. */
- initWithFrame:(NSRect)aFrame
           tile:(NSImage *)image
   displayRects:(NSDictionary *)rects;

/** If `languageName` is `nil` loads clockbits for system default language (
    first language specified in `NSLanguages` array in NSGlobalDomain). */
- (void)loadClockbitsForLanguage:(NSString *)languageName;

//-----------------------------------------------------------------------------
#pragma mark - Double click
//-----------------------------------------------------------------------------
- (void)setTarget:(id)target;
- (void)setDoubleAction:(SEL)sel;
  
//-----------------------------------------------------------------------------
#pragma mark - Drawing
//-----------------------------------------------------------------------------
- (void)sizeToFit;

//-----------------------------------------------------------------------------
#pragma mark - Properties
//-----------------------------------------------------------------------------
/** Sets whether the receiver displays the year information in a small
    text field at it's bottom. */
- (void)setYearVisible:(BOOL)flag;
- (BOOL)isYearVisible;

/** Sets whether the receiver is to display 12-hour AM/PM format or full
    24-hour format. */
- (void)set24HourFormat:(BOOL)flag;
- (BOOL)is24HourFormat;

/** Set whether the receiver display real machine date. Alive state can be
    determined by blinking colon in time field. */
- (void)setAlive:(BOOL)live;
- (BOOL)isAlive;

/** Sets the calendar date the receiver is to display. */
- (void)setCalendarDate:(NSCalendarDate *)aDate;
- (NSCalendarDate *)calendarDate;

- (void)setLanguage:(NSString *)languageName;

//-----------------------------------------------------------------------------
#pragma mark - Defaults
//-----------------------------------------------------------------------------
/** Tracks changes of NXTClockView24HourFormat - 12/24 hour clock format. */
- (void)setTracksDefaultsDatabase:(BOOL)flag;
- (BOOL)tracksDefaultsDatabase;

@end

extern NSString *NXTClockView24HourFormat;
