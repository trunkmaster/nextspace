
#import "NXClockView.h"

#import <Foundation/NSTimer.h>
#import <AppKit/AppKit.h>
#import <NXFoundation/NXDefaults.h>

#define DISTRIBUTED_NC [NSDistributedNotificationCenter notificationCenterForType:NSLocalNotificationCenterType]

@implementation NXClockView

//-----------------------------------------------------------------------------
#pragma mark - Init and dealloc
//-----------------------------------------------------------------------------

- initWithFrame:(NSRect)aFrame
{
  self = [super initWithFrame:aFrame];

  // ivars
  date = nil;
  updateTimer = nil;
  clockBits = nil;
  
  // Defaults
  isColonVisible = YES;
  [self setYearVisible:YES];
  isTrackDefaults = NO;
  [self setTracksDefaultsDatabase:YES];
  [self setAlive:NO];
  lastDOW = lastDOM = lastMOY = lastHOD = lastMOH = lastYOCE = -1;

  // Tile: inside 'clockbits' image
  tileRect = NSMakeRect(191, 9, 64, 71);

  // Day of week
  dowDisplayRect = NSMakeRect(14, 41, 33, 6);    // inside 'tileRect'
  mondayRect     = NSMakeRect( 0, 71, 19, 6);    // 'MON' + one white line below

  // Day
  dayDisplayRect = NSMakeRect(14, 22, 33, 17);   // inside 'tileRect'
  firstDayRect   = NSMakeRect(64, 14, 12, 17);   // '1'

  // Month
  monthDisplayRect = NSMakeRect(14, 16, 31, 6);  // display rect inside 'tileRect'
  januaryRect      = NSMakeRect(40, 72, 22, 6);  // 'JAN' + one white line above

  // it's inside tile rect
  timeDisplayRect = NSMakeRect(5, 53, 53, 11);   // display rect inside 'tileRect'
  
  time_nums[0] = NSMakeRect(150, 56, 9, 11); // 0
  time_nums[1] = NSMakeRect(83,  56, 4, 11); // 1
  time_nums[2] = NSMakeRect(87,  56, 8, 11); // 2
  time_nums[3] = NSMakeRect(95,  56, 8, 11); // 3
  time_nums[4] = NSMakeRect(103, 56, 8, 11); // 4
  time_nums[5] = NSMakeRect(111, 56, 7, 11); // 5
  time_nums[6] = NSMakeRect(118, 56, 8, 11); // 6
  time_nums[7] = NSMakeRect(126, 56, 7, 11); // 7
  time_nums[8] = NSMakeRect(133, 56, 9, 11); // 8
  time_nums[9] = NSMakeRect(142, 56, 8, 11); // 9

  colonRect = NSMakeRect(159, 56, 3,  11);   // :
  noColonRect = NSMakeRect(83, 0, 3, 11);
  
  amRect = NSMakeRect(162, 56, 13, 6);       // am
  pmRect = NSMakeRect(175, 56, 12, 6);       // pm

  yearDisplayRect = NSMakeRect(14, 2, 38, 6);
  year_nums[0] = NSMakeRect(12,  8, 6, 6);
  year_nums[1] = NSMakeRect(0,  20, 2, 6);
  year_nums[2] = NSMakeRect(2,  20, 5, 6);
  year_nums[3] = NSMakeRect(7,  20, 5, 6);
  year_nums[4] = NSMakeRect(12, 20, 6, 6);
  year_nums[5] = NSMakeRect(0,  14, 5, 6);
  year_nums[6] = NSMakeRect(5,  14, 6, 6);
  year_nums[7] = NSMakeRect(11, 14, 5, 6);
  year_nums[8] = NSMakeRect(0,   8, 6, 6);
  year_nums[9] = NSMakeRect(6,   8, 6, 6);

  // Load clockbits for default language
  [self loadClockbitsForLanguage:nil];

  // The next 2 method calls sets 'colonDisplayRect' ivar but it will not
  // cause drawing because 'is24HourFormat' was not changed
  is24HourFormat = [[NXDefaults globalUserDefaults]
                         boolForKey:@"NXClockView24HourFormat"];
  [self set24HourFormat:is24HourFormat];
  
  [self setCalendarDate:[NSCalendarDate dateWithYear:1970
                                               month:1
                                                 day:1
                                                hour:0
                                              minute:0
                                              second:0
                                            timeZone:[NSTimeZone localTimeZone]]];

  return self;
}

- initWithFrame:(NSRect)aFrame
           tile:(NSImage *)image
   displayRects:(NSDictionary *)rects
{
  NSString *rectString;
  NSSize   tileSize;
  
  [self initWithFrame:aFrame];

  if (image != nil) {
    tileImage = image;
    tileSize = [image size];
    tileRect = NSMakeRect(0, 0, tileSize.width, tileSize.height);
  }

  // Reassert display rects already assigned in initWithFrame:
  if (rects != nil) {
    if ((rectString = [rects objectForKey:@"DayOfWeek"]) != nil)
      dowDisplayRect = NSRectFromString(rectString);
    if ((rectString = [rects objectForKey:@"Day"]) != nil)
      dayDisplayRect = NSRectFromString(rectString);
    if ((rectString = [rects objectForKey:@"Month"]) != nil)
      monthDisplayRect = NSRectFromString(rectString);
    if ((rectString = [rects objectForKey:@"Time"]) != nil)
      timeDisplayRect = NSRectFromString(rectString);
    if ((rectString = [rects objectForKey:@"Year"]) != nil)
      yearDisplayRect = NSRectFromString(rectString);
  }

  [self set24HourFormat:is24HourFormat];

  return self;
}

- (void)loadClockbitsForLanguage:(NSString *)languageName
{
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *langPath, *bitsPath;
  NSArray  *languageList;

  if (languageName == nil) {
    languageList = [[NSUserDefaults standardUserDefaults]
                     objectForKey:@"NSLanguages"];
    if (languageList != nil && [languageList count] > 0) {
      languageName = [languageList objectAtIndex:0];
    }
    if (languageName == nil) {
      languageName = @"English";
    }
  }

  langPath = [bundle pathForResource:languageName ofType:@"lproj"];
  if ([[NSFileManager defaultManager] fileExistsAtPath:langPath] == YES) {
    bitsPath = [langPath stringByAppendingPathComponent:@"clockbits.tiff"];
  }
  else {
    bitsPath = [bundle pathForResource:@"clockbits"
                                ofType:@"tiff"
                           inDirectory:@"English.lproj"];
  }

  // Release already loaded clockbits
  if (clockBits != nil) {
    [clockBits release];
  }
  clockBits = [[NSImage alloc] initByReferencingFile:bitsPath];
  dateChanged = YES;
}

- (void)dealloc
{
  NSLog(@"[NXClockView] dealloc");
  if (isTrackDefaults) {
    [DISTRIBUTED_NC removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  }
  
  if (updateTimer != nil) {
    if ([updateTimer isValid] == YES) {
      [updateTimer invalidate];
    }
    [updateTimer release];
  }
  [date release];

  // if (tileImage) {
  //   [tileImage release];
  // }

  [super dealloc];
}

//-----------------------------------------------------------------------------
#pragma mark - Double click
//-----------------------------------------------------------------------------
- (void)setTarget:(id)target
{
  actionTarget = target;
}

- (void)setDoubleAction:(SEL)sel
{
  doubleAction = sel;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)anEvent
{
  return YES;
}

- (void)mouseDown:(NSEvent *)event
{
  if ([event clickCount] >= 2) {
    [actionTarget performSelector:doubleAction];
  }
}

//-----------------------------------------------------------------------------
#pragma mark - Drawing
//-----------------------------------------------------------------------------

- (void)sizeToFit
{
  NSRect myFrame = [self frame];

  if (isYearVisible)
    myFrame.size.height = 70;
  else
    myFrame.size.height = 57;
  
  myFrame.size.width = 55;

  [self setFrame:myFrame];
}

- (void)update:(NSTimer *)timer
{
  isColonVisible = !isColonVisible;
  [self setCalendarDate:[NSCalendarDate calendarDate]];
}

- (void)_drawColon
{
  if (isColonVisible) {
    [clockBits drawAtPoint:colonDisplayRect.origin
                  fromRect:colonRect
                 operation:NSCompositeSourceAtop
                  fraction:1.0];
  }
  else {
    [clockBits drawAtPoint:colonDisplayRect.origin
                  fromRect:noColonRect
                 operation:NSCompositeSourceAtop
                  fraction:1.0];
  }
}

- (void)drawRect:(NSRect)r
{
  CGFloat   hoffset;
  CGFloat   rectCenter;
  NSRect    elRect;
  NSPoint   elPoint;
  NSInteger ampm_offset;

  // if (dateChanged == NO && !NSEqualRects(_bounds, r))
  // If rect that needs to be update is rect for colon drawing
  // do not update the rest of view.
  if (NSEqualRects(r, colonDisplayRect) == YES) {
    [self _drawColon];
    return;
  }
  
  // Tile
  if (NSIntersectsRect(r, [self bounds]) == YES) {
    // NSLog(@"NXClockView: draw TILE");
    if (tileImage)
      [tileImage compositeToPoint:NSMakePoint(0,0)
                         fromRect:tileRect
                        operation:NSCompositeSourceAtop];
    else
      [clockBits compositeToPoint:NSMakePoint(0,0)
                         fromRect:tileRect
                        operation:NSCompositeSourceAtop];
  }

  // --- Date
  
  // Day of week
  // dayOfWeek = [date dayOfWeek];
  if (NSIntersectsRect(r, dowDisplayRect) == YES) {
    // NSLog(@"NXClockView: draw DAY OF WEEK");
    elRect = mondayRect;
    elRect.origin.y -= (dayOfWeek > 0 ? dayOfWeek : 7) * mondayRect.size.height;
    rectCenter = dowDisplayRect.origin.x + ceilf(dowDisplayRect.size.width/2);
    elPoint = NSMakePoint(rectCenter - ceilf(elRect.size.width/2),
                          dowDisplayRect.origin.y);
    [clockBits compositeToPoint:elPoint
                       fromRect:elRect
                      operation:NSCompositeSourceOver];
  }

  // Day of month
  // dayOfMonth = [date dayOfMonth];
  if (NSIntersectsRect(r, dayDisplayRect) == YES) {
    // NSLog(@"NXClockView: draw DAY OF MONTH");
    rectCenter = dayDisplayRect.origin.x + ceilf(dayDisplayRect.size.width/2);
    if (dayOfMonth > 9) {
      int  decade, day;

      // First digit of day
      elRect = firstDayRect;
      decade = (dayOfMonth - (dayOfMonth % 10)) / 10;
      elRect.origin.x += (decade - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint((rectCenter - firstDayRect.size.width) + 1,
                            dayDisplayRect.origin.y);
      [clockBits compositeToPoint:elPoint
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
      // Second digit of day
      elRect = firstDayRect;
      if ((day = dayOfMonth % 10) == 0)
        day = 10;
      elRect.origin.x += (day - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint(rectCenter - 1, dayDisplayRect.origin.y);
      [clockBits compositeToPoint:elPoint
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
    }
    else {
      elRect = firstDayRect;
      elRect.origin.x += (dayOfMonth - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint(rectCenter - ceilf(firstDayRect.size.width/2),
                            dayDisplayRect.origin.y);
      [clockBits compositeToPoint:elPoint
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
    }
  }

  // Month
  // monthOfYear = [date monthOfYear];
  if (NSIntersectsRect(r, monthDisplayRect) == YES) {
    // NSLog(@"NXClockView: draw MONTH");
    elRect = januaryRect;
    elRect.origin.y -= monthOfYear * januaryRect.size.height;
    rectCenter = monthDisplayRect.origin.x + ceilf(monthDisplayRect.size.width/2);
    elPoint = NSMakePoint(rectCenter - ceilf(elRect.size.width/2),
                          monthDisplayRect.origin.y);
    [clockBits compositeToPoint:elPoint
                       fromRect:elRect
                      operation:NSCompositeSourceOver];
  }

  // --- Time
  
  // Hours
  // second digit of hour
  if (NSIntersectsRect(r, timeDisplayRect) == YES) {
    rectCenter = ceilf(timeDisplayRect.size.width/2 - colonRect.size.width/2)
      + timeOffset;
      // NSLog(@"NXClockView: draw TIME");
      elRect = time_nums[(hourOfDay % 10)];
      hoffset = rectCenter - elRect.size.width;
      [clockBits compositeToPoint:NSMakePoint(hoffset, timeDisplayRect.origin.y)
                         fromRect:elRect
                        operation:NSCompositeSourceOver];

      // first digit of hour
      if (is24HourFormat || hourOfDay > 9) {
        elRect = time_nums[((hourOfDay - (hourOfDay % 10)) / 10)];
        hoffset -= elRect.size.width;
        [clockBits compositeToPoint:NSMakePoint(hoffset, timeDisplayRect.origin.y)
                           fromRect:elRect
                          operation:NSCompositeSourceOver];
      }

      // Time Colon
      [self _drawColon];

      // Minutes
      hoffset = rectCenter + colonRect.size.width;
      elRect = time_nums[(minuteOfHour - (minuteOfHour % 10)) / 10];
      [clockBits compositeToPoint:NSMakePoint(hoffset, timeDisplayRect.origin.y)
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
      hoffset += elRect.size.width;
      elRect = time_nums[minuteOfHour % 10];
      [clockBits compositeToPoint:NSMakePoint(hoffset, timeDisplayRect.origin.y)
                         fromRect:elRect
                        operation:NSCompositeSourceOver];

      // am/pm
      if (is24HourFormat == NO) {
        hoffset = (timeDisplayRect.origin.x + timeDisplayRect.size.width) - 3;
        ampm_offset = timeDisplayRect.origin.y +
          (timeDisplayRect.size.height-amRect.size.height)/2;
        if (isMorning) {
          hoffset -= amRect.size.width;
          [clockBits compositeToPoint:NSMakePoint(hoffset, ampm_offset)
                             fromRect:amRect
                            operation:NSCompositeSourceOver];
        }
        else {
          hoffset -= pmRect.size.width;
          [clockBits compositeToPoint:NSMakePoint(hoffset, ampm_offset)
                             fromRect:pmRect
                            operation:NSCompositeSourceOver];
        }
      }
  }

  // Year
  if ((NSIntersectsRect(r, yearDisplayRect) == YES) && (isYearVisible == YES)) {
    // NSLog(@"NXClockView: draw YEAR");
    int thousands, hundreds, tens, nums;
    CGFloat x;
      
    nums = yearOfCommonEra % 10;                          // 201. 6
    tens = ((yearOfCommonEra % 100) - nums) / 10;         // 20. 16
    hundreds = ((yearOfCommonEra % 1000) - tens) / 100;   // 2. 016
    thousands = (yearOfCommonEra - (hundreds + tens)) / 1000;

    rectCenter = yearDisplayRect.origin.x + yearDisplayRect.size.width/2;
    x = rectCenter - ((year_nums[hundreds].size.width +
                       year_nums[thousands].size.width +
                       year_nums[tens].size.width +
                       year_nums[nums].size.width) / 2);
      
    elRect = year_nums[thousands];
    [clockBits compositeToPoint:NSMakePoint(x, yearDisplayRect.origin.y)
                       fromRect:elRect
                      operation:NSCompositeSourceOver];
    x += elRect.size.width;
      
    elRect = year_nums[hundreds];
    [clockBits compositeToPoint:NSMakePoint(x, yearDisplayRect.origin.y)
                       fromRect:elRect
                      operation:NSCompositeSourceOver];
    x += elRect.size.width;
      
    elRect = year_nums[tens];
    [clockBits compositeToPoint:NSMakePoint(x, yearDisplayRect.origin.y)
                       fromRect:elRect
                      operation:NSCompositeSourceOver];
    x += elRect.size.width;
      
    elRect = year_nums[nums];
    [clockBits compositeToPoint:NSMakePoint(x, yearDisplayRect.origin.y)
                       fromRect:elRect
                      operation:NSCompositeSourceOver];
  }

  dateChanged = NO;
}

//-----------------------------------------------------------------------------
#pragma mark - Properties
//-----------------------------------------------------------------------------

- (void)setYearVisible:(BOOL)flag
{
  if (isYearVisible != flag) {
    isYearVisible = flag;
    if (clockBits != nil) {
      dateChanged = YES;
      [self displayRect:yearDisplayRect];
    }
  }
}

- (BOOL)isYearVisible
{
  return isYearVisible;
}

- (void)set24HourFormat:(BOOL)flag
{
  CGFloat rectCenter;
  
  if (flag == NO)
    timeOffset = -4;
  else
    timeOffset = 3;

  rectCenter = ceilf(timeDisplayRect.size.width/2 - colonRect.size.width/2) + timeOffset;
  colonDisplayRect = NSMakeRect(rectCenter, timeDisplayRect.origin.y,
                                colonRect.size.width, colonRect.size.height);
  if (is24HourFormat != flag) {
    is24HourFormat = flag;
    if (clockBits != nil) {
      [self displayRect:timeDisplayRect];
    }
  }
}

- (BOOL)is24HourFormat
{
  return is24HourFormat;
}

- (void)setAlive:(BOOL)live
{
  if (live == isAlive)
    return;
  
  isAlive = live;
  if (isAlive == YES) {
    dateChanged = YES;
    [self update:nil];
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                   target:self
                                                 selector:@selector(update:)
                                                 userInfo:nil
                                                  repeats:YES];
  }
  else {
    if (updateTimer != nil) {
      [updateTimer invalidate];
      isColonVisible = YES;
      dateChanged = YES;
      [self displayRect:colonDisplayRect];
    }
  }
}

- (BOOL)isAlive
{
  return isAlive;
}

- (void)setCalendarDate:(NSCalendarDate *)aDate
{
  ASSIGN(date, aDate);
  
  hourOfDay = [date hourOfDay];
  minuteOfHour = [date minuteOfHour];
  dayOfWeek = [date dayOfWeek];
  dayOfMonth = [date dayOfMonth];
  monthOfYear = [date monthOfYear];
  yearOfCommonEra = [date yearOfCommonEra];

  // Draw updated time
  if (minuteOfHour != lastMOH || hourOfDay != lastHOD) {
    if (is24HourFormat == NO) {
      isMorning = NO;
      if (hourOfDay == 0) {
        hourOfDay = 12;
        isMorning = YES;
      }
      else if (hourOfDay < 12) {
        isMorning = YES;
      }
      else if (hourOfDay > 12) {
        hourOfDay -= 12;
      }
    }
    // NSLog(@"setCalendarDate: TIME changed");
    dateChanged = YES;
    [self setNeedsDisplayInRect:timeDisplayRect];
    lastMOH = minuteOfHour;
    lastHOD = hourOfDay;
  }

  // Draw updated day of week and day of month
  if (dayOfWeek != lastDOW || dayOfMonth != lastDOM) {
    // NSLog(@"setCalendarDate: DAY changed");
    dateChanged = YES;
    [self setNeedsDisplayInRect:NSUnionRect(dowDisplayRect, dayDisplayRect)];
    lastDOW = dayOfWeek;
    lastDOM = dayOfMonth;
  }

  // Draw updated month
  if (monthOfYear != lastMOY) {
    // NSLog(@"setCalendarDate: MONTH changed");
    dateChanged = YES;
    [self setNeedsDisplayInRect:monthDisplayRect];
    lastMOY = monthOfYear;
  }
  
  // Draw updated year
  if (yearOfCommonEra != lastYOCE) {
    // NSLog(@"setCalendarDate: YEAR changed");
    dateChanged = YES;
    [self setNeedsDisplayInRect:yearDisplayRect];
    lastYOCE = yearOfCommonEra;
  }

  // Draw only colon. 'colonDisplayRect' is calculated in first run of drawRect:
  // depending on clock display format.
  if (isAlive == YES) {
    [self setNeedsDisplayInRect:colonDisplayRect];
  }
}

- (NSCalendarDate *)calendarDate
{
  return date;
}

- (void)setLanguage:(NSString *)languageName
{
  [self loadClockbitsForLanguage:languageName];
  [self setNeedsDisplay:YES];
}

//-----------------------------------------------------------------------------
#pragma mark - Defaults
//-----------------------------------------------------------------------------

- (void)setTracksDefaultsDatabase:(BOOL)flag
{
  if (flag != isTrackDefaults) {
    if (flag != NO) {
      // ~/Library/Preferences/.NextSpace/NXGlobalDomain
      // NXClockView24HourFormat = YES/NO;
      [DISTRIBUTED_NC addObserver:self
                         selector:@selector(defaultsChanged:)
                             name:NXUserDefaultsDidChangeNotification
                           object:nil];
      
      // ~/Library/Preferences/NSGlobalDomain.
      // NSLanguages
      [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(defaultsChanged:)
               name:NSUserDefaultsDidChangeNotification
             object:nil];
    }
    else {
      [DISTRIBUTED_NC removeObserver:self];
    }
  }
  isTrackDefaults = flag;
}

- (BOOL)tracksDefaultsDatabase
{
  return isTrackDefaults;
}

- (void)defaultsChanged:(NSNotification *)notif
{
  id notifObject = [notif object];
  
  NSLog(@"NXClockView: defaults was changed! %@", [[notif object] className]);

  if ([notifObject isKindOfClass:[NSString class]]) {
    // NextSpace's NXGlobalDomain was changed
    [self set24HourFormat:[[NXDefaults globalUserDefaults]
                            boolForKey:@"NXClockView24HourFormat"]];
  }
  else if ([notifObject isKindOfClass:[NSUserDefaults class]]) {
    [self setLanguage:nil];
  }
}

@end
