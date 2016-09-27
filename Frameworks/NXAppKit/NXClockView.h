/** @class NXClockView
    @brief This class is a classic NeXT-style clock.

    This class represents a classic NeXT-style clock as we know it
    from the Preferences app.
    
    Date views use one value in the defaults database (which they
    watch for changes if configured to do so): "NXClockViewShows12HourFormat".
    If this key is set to "YES", then they display 12-hour AM/PM format.
    Otherwise they display 24-hour format time.

    @author Saso Kiselkov, Sergii Stoian
*/

#import <AppKit/NSView.h>

@class NSTextField, NSCalendarDate;

@interface NXClockView : NSView
{
  // The currently displayed date.
  NSCalendarDate *date;
  NSInteger      dayOfWeek, lastDOW;
  NSInteger      dayOfMonth, lastDOM;
  NSInteger      monthOfYear, lastMOY;
  NSInteger      hourOfDay, lastHOD;
  NSInteger      minuteOfHour, lastMOH;
  NSInteger      yearOfCommonEra, lastYOCE;

  // Properties
  BOOL shows24HourFormat;
  BOOL showsLEDColon;
  BOOL showsYear;
  BOOL tracksDefaults;

  NSImage *clockBits;
  NSRect  tileRect;

  // Day of week, month, day
  NSRect dowRect;
  NSRect mondayRect;
  NSRect dayRect;
  NSRect firstDayRect;
  NSRect monthRect;
  NSRect januaryRect;

  // LED time
  CGFloat timeOffset;
  NSRect  timeRect;
  NSRect  time_nums[10];
  NSRect  colonRect;
  NSRect  colonDisplayRect;
  NSRect  amRect;
  NSRect  pmRect;

  // Year
  NSRect yearRect;
  NSRect year_nums[10];
}

- (void)loadImageForLanguage:(NSString *)languageName;

- (void)sizeToFit;

/** Sets whether the receiver displays the year information in a small
    text field at it's bottom. */
- (void)setShowsYear:(BOOL)flag;
- (BOOL)showsYear;

 /** Sets whether the receiver is to display 12-hour AM/PM format or full
     24-hour format. */
- (void)setShows24HourFormat:(BOOL)flag;
- (BOOL)shows24HourFormat;

/** Sets whether the receiver is to display a colon between the hour
    and minute fields. */
- (void)setShowsLEDColon:(BOOL)flag;
- (BOOL)showsLEDColon;

/// Sets the calendar date the receiver is to display.
- (void)setCalendarDate:(NSCalendarDate *)aDate;
- (NSCalendarDate *)calendarDate;

/** Sets whether the receiver is tracking the defaults database for
    defaults changes about the receiver's appearance. */
- (void)setTracksDefaultsDatabase:(BOOL)flag;
- (BOOL)tracksDefaultsDatabase;

- (void)setLanguage:(NSString *)languageName;

@end
