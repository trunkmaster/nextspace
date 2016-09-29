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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimer.h>
#import <AppKit/NSView.h>

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

  NSTimer *updateTimer;

  // Properties and state
  BOOL isAlive;
  BOOL is24HourFormat;
  BOOL isYearVisible;
  BOOL isTrackDefaults;
  BOOL isColonBlinking, isColonVisible;
  BOOL isMorning;

  NSImage *clockBits;
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
  NSRect  colonDisplayRect;
  NSRect  amRect;
  NSRect  pmRect;

  // Year
  NSRect yearDisplayRect;
  NSRect year_nums[10];
}

- (void)loadImageForLanguage:(NSString *)languageName;

- (void)sizeToFit;

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

/// Sets the calendar date the receiver is to display.
- (void)setCalendarDate:(NSCalendarDate *)aDate;
- (NSCalendarDate *)calendarDate;

/** Sets whether the receiver is tracking the defaults database for
    defaults changes about the receiver's appearance. */
- (void)setTracksDefaultsDatabase:(BOOL)flag;
- (BOOL)tracksDefaultsDatabase;

- (void)setLanguage:(NSString *)languageName;

@end
