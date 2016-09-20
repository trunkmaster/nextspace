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
  /// The text field used to display the year.
  NSTextField *yearField;

  BOOL showsYear;
  BOOL shows12HourFormat;
  BOOL showsLEDColon;
  BOOL tracksDefaults;

  /// The currently displayed date.
  NSCalendarDate *date;

  NSImage *clockBits;
  NSRect  tileRect;

  // Day of week, month, day of month
  NSRect  mondayRect;
  NSRect  januaryRect;
  NSRect  firstDayRect;

  // LED time
  NSRect ledDisplayRect;
  NSRect led_nums[10];
  NSRect ledColonRect;
  NSRect ledAMRect;
  NSRect ledPMRect;
}

- (void)loadImageForLanguage:(NSString *)languageName;

- (void)sizeToFit;

/** Sets whether the receiver displays the year information in a small
    text field at it's bottom. */
- (void)setShowsYear:(BOOL)flag;
- (BOOL)showsYear;

 /** Sets whether the receiver is to display 12-hour AM/PM format or full
     24-hour format. */
- (void)setShows12HourFormat:(BOOL)flag;
- (BOOL)shows12HourFormat;

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
