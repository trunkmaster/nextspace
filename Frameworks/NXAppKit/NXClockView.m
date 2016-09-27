
#import "NXClockView.h"

#import <AppKit/AppKit.h>
#import <NXFoundation/NXDefaults.h>

@implementation NXClockView (Private)

@end

@implementation NXClockView

//-----------------------------------------------------------------------------
#pragma mark - Init and dealloc
//-----------------------------------------------------------------------------

- initWithFrame:(NSRect)aFrame
{
  self = [super initWithFrame:aFrame];

  // Defaults
  shows24HourFormat = [[NXDefaults globalUserDefaults]
                        boolForKey:@"NXClockView24HourFormat"];
  // The next method call sets 'timeOffset' ivar but will not cause drawing
  // because 'shows24HourFormat' was not changed (set at the above line).
  [self setShows24HourFormat:shows24HourFormat];
  showsLEDColon = YES;
  [self setShowsLEDColon:YES];
  showsYear = YES;
  [self setTracksDefaultsDatabase:YES];

  // Tile: inside 'clockbits' image
  tileRect = NSMakeRect(191, 9, 64, 71);

  // Day of week
  dowRect    = NSMakeRect(14, 41, 33, 6);    // display rect inside 'tileRect'
  mondayRect = NSMakeRect( 0, 71, 19, 6);    // 'MON' + one white line below

  // Day
  dayRect      = NSMakeRect(14, 22, 33, 17); // display rect rect inside 'tileRect'
  firstDayRect = NSMakeRect(64, 14, 12, 17); // '1'

  // Month
  monthRect   = NSMakeRect(14, 16, 31, 6);   // display rect inside 'tileRect'
  januaryRect = NSMakeRect(40, 72, 22, 6);   // 'JAN' + one white line above

  // it's inside tile rect
  timeRect = NSMakeRect(5, 53, 53, 11);      // display rect inside 'tileRect'
  
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
  amRect    = NSMakeRect(162, 56, 13, 6);    // am
  pmRect    = NSMakeRect(175, 56, 12, 6);    // pm

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

  [self loadImageForLanguage:nil];
  
  return self;
}

- (void)loadImageForLanguage:(NSString *)languageName
{
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *langDir;

  if (languageName == nil)
    {
      langDir = @"English.lproj";
    }
  else
    {
      langDir = [languageName stringByAppendingPathExtension:@"lproj"];
    }
  
  if (clockBits != nil)
    {
      [clockBits release];
    }

  clockBits = [[NSImage alloc]
		  initByReferencingFile:[bundle pathForResource:@"clockbits"
                                                         ofType:@"tiff"
                                                    inDirectory:langDir]];

  if (clockBits == nil) // No resource for specified language
    {
      [self loadImageForLanguage:nil];
    }
}

- (void)dealloc
{
  [[NSDistributedNotificationCenter
              notificationCenterForType:NSLocalNotificationCenterType]
    removeObserver:self];

  TEST_RELEASE(date);

  [super dealloc];
}

//-----------------------------------------------------------------------------
#pragma mark - Drawing
//-----------------------------------------------------------------------------

- (void)sizeToFit
{
  NSRect myFrame = [self frame];

  if (showsYear)
    myFrame.size.height = 70;
  else
    myFrame.size.height = 57;

  myFrame.size.width = 55;

  [self setFrame:myFrame];
}

- (void)drawRect:(NSRect)r
{
  float   hoffset;
  BOOL    morning;
  CGFloat rectCenter;
  NSRect  elRect;
  NSPoint elPoint;
  int     ampm_offset;

  // Tile
  [clockBits compositeToPoint:NSMakePoint(0,0)
                     fromRect:tileRect
                    operation:NSCompositeSourceOver];

  if (date == nil)
    return;

  // --- Date
  
  // Day of week
  // dayOfWeek = [date dayOfWeek];
  elRect = mondayRect;
  elRect.origin.y -= (dayOfWeek > 0 ? dayOfWeek : 7) * mondayRect.size.height;
  rectCenter = dowRect.origin.x + ceilf(dowRect.size.width/2);
  elPoint = NSMakePoint(rectCenter - ceilf(elRect.size.width/2),
                        dowRect.origin.y);
  [clockBits compositeToPoint:elPoint
                     fromRect:elRect
                    operation:NSCompositeSourceOver];

  // Day of month
  // dayOfMonth = [date dayOfMonth];
  rectCenter = dayRect.origin.x + ceilf(dayRect.size.width/2);
  if (dayOfMonth > 9)
    {
      int  decade, day;

      // First digit of day
      elRect = firstDayRect;
      decade = (dayOfMonth - (dayOfMonth % 10)) / 10;
      elRect.origin.x += (decade - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint((rectCenter - firstDayRect.size.width) + 1,
                            dayRect.origin.y);
      [clockBits compositeToPoint:elPoint
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
      // Second digit of day
      elRect = firstDayRect;
      if ((day = dayOfMonth % 10) == 0)
        day = 10;
      elRect.origin.x += (day - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint(rectCenter - 1, dayRect.origin.y);
      [clockBits compositeToPoint:elPoint
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
    }
  else
    {
      elRect = firstDayRect;
      elRect.origin.x += (dayOfMonth - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint(rectCenter - ceilf(firstDayRect.size.width/2),
                            dayRect.origin.y);
      [clockBits compositeToPoint:elPoint
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
    }

  // Month
  // monthOfYear = [date monthOfYear];
  elRect = januaryRect;
  elRect.origin.y -= monthOfYear * januaryRect.size.height;
  rectCenter = monthRect.origin.x + ceilf(monthRect.size.width/2);
  elPoint = NSMakePoint(rectCenter - ceilf(elRect.size.width/2),
                        monthRect.origin.y);
  [clockBits compositeToPoint:elPoint
                     fromRect:elRect
                    operation:NSCompositeSourceOver];

  // --- Time
  
  // hourOfDay = [date hourOfDay];
  // minuteOfHour = [date minuteOfHour];
  if (shows24HourFormat == NO)
    {
      morning = NO;
      if (hourOfDay == 0)
	{
	  hourOfDay = 12;
	  morning = YES;
	}
      else if (hourOfDay < 12)
	{
	  morning = YES;
	}
      else if (hourOfDay > 12)
	{
          hourOfDay -= 12;
	}
    }

  // Colon
  rectCenter = ceilf(timeRect.size.width/2 - colonRect.size.width/2) + timeOffset;
  if (showsLEDColon)
    {
      [clockBits compositeToPoint:NSMakePoint(rectCenter, timeRect.origin.y)
                         fromRect:colonRect
                        operation:NSCompositeSourceOver];
      // if (0) // if blinking enabled
      //   {
      //     [self setShowsLEDColon:!showsLEDColon];
      //   }
    }
  
  // Hours
  // second digit of hour
  elRect = time_nums[(hourOfDay % 10)];
  hoffset = rectCenter - elRect.size.width;
  [clockBits compositeToPoint:NSMakePoint(hoffset, timeRect.origin.y)
                     fromRect:elRect
                    operation:NSCompositeSourceOver];

  // first digit of hour
  if (shows24HourFormat || hourOfDay > 9)
    {
      elRect = time_nums[((hourOfDay - (hourOfDay % 10)) / 10)];
      hoffset -= elRect.size.width;
      [clockBits compositeToPoint:NSMakePoint(hoffset, timeRect.origin.y)
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
    }

  // Minutes
  hoffset = rectCenter + colonRect.size.width;
  elRect = time_nums[(minuteOfHour - (minuteOfHour % 10)) / 10];
  [clockBits compositeToPoint:NSMakePoint(hoffset, timeRect.origin.y)
                     fromRect:elRect
                    operation:NSCompositeSourceOver];
  hoffset += elRect.size.width;
  elRect = time_nums[minuteOfHour % 10];
  [clockBits compositeToPoint:NSMakePoint(hoffset, timeRect.origin.y)
                     fromRect:elRect
                    operation:NSCompositeSourceOver];

  // am/pm
  if (shows24HourFormat == NO)
    {
      hoffset = (timeRect.origin.x + timeRect.size.width) - 3;
      ampm_offset = timeRect.origin.y + (timeRect.size.height-amRect.size.height)/2;
      if (morning)
        {
          hoffset -= amRect.size.width;
          [clockBits compositeToPoint:NSMakePoint(hoffset, ampm_offset)
                             fromRect:amRect
                            operation:NSCompositeSourceOver];
        }
      else
        {
          hoffset -= pmRect.size.width;
          [clockBits compositeToPoint:NSMakePoint(hoffset, ampm_offset)
                             fromRect:pmRect
                            operation:NSCompositeSourceOver];
        }
    }

  if (showsYear == YES)
    {
      int thousands, hundreds, tens, nums;
      CGFloat x;
      
      nums = yearOfCommonEra % 10;                          // 201. 6
      tens = ((yearOfCommonEra % 100) - nums) / 10;         // 20. 16
      hundreds = ((yearOfCommonEra % 1000) - tens) / 100;   // 2. 016
      thousands = (yearOfCommonEra - (hundreds + tens)) / 1000;

      // TODO: implement and use yearRect
      rectCenter = r.size.width/2;

      // To the left from the center
      elRect = year_nums[hundreds];
      x = rectCenter - elRect.size.width;
      [clockBits compositeToPoint:NSMakePoint(x, 2)
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
      elRect = year_nums[thousands];
      x -= elRect.size.width;
      [clockBits compositeToPoint:NSMakePoint(x, 2)
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
      
      // To the right from the center
      elRect = year_nums[tens];
      x = rectCenter;
      [clockBits compositeToPoint:NSMakePoint(x, 2)
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
      
      x += elRect.size.width;
      elRect = year_nums[nums];
      [clockBits compositeToPoint:NSMakePoint(x, 2)
                         fromRect:elRect
                        operation:NSCompositeSourceOver];
    }

  lastHOD = hourOfDay;
  lastMOH = minuteOfHour;
  lastDOW = dayOfWeek;
  lastDOM = dayOfMonth;
  lastMOY = monthOfYear;
  lastYOCE = yearOfCommonEra;
}

//-----------------------------------------------------------------------------
#pragma mark - Properties
//-----------------------------------------------------------------------------

- (void)setShowsYear:(BOOL)flag
{
  if (showsYear != flag)
    {
      showsYear = flag;
      if (clockBits != nil)
        {
          [self setNeedsDisplay:YES];
        }
    }
}

- (BOOL)showsYear
{
  return showsYear;
}

- (void)setShows24HourFormat:(BOOL)flag
{
  if (flag == NO)
    {
      timeOffset = -4;
    }
  else
    {
      timeOffset = 3;
    }

  if (shows24HourFormat != flag)
    {
      shows24HourFormat = flag;
      if (clockBits != nil)
        {
          [self setNeedsDisplay:YES];
        }
    }
}

- (BOOL)shows24HourFormat
{
  return shows24HourFormat;
}

- (void)setShowsLEDColon:(BOOL)flag
{
  if (showsLEDColon != flag)
    {
      showsLEDColon = flag;
       if (clockBits != nil)
        {
          [self setNeedsDisplay:YES];
        }
    }
}

- (BOOL)showsLEDColon
{
  return showsLEDColon;
}

- (void)setCalendarDate:(NSCalendarDate *)aDate
{
  BOOL dateChanged = NO;
    
  ASSIGN(date, aDate);
  
  hourOfDay = [date hourOfDay];
  minuteOfHour = [date minuteOfHour];
  dayOfWeek = [date dayOfWeek];
  dayOfMonth = [date dayOfMonth];
  monthOfYear = [date monthOfYear];
  yearOfCommonEra = [date yearOfCommonEra];

  if (hourOfDay != lastHOD || minuteOfHour != lastMOH ||
      dayOfWeek != lastDOW || dayOfMonth != lastDOM ||
      monthOfYear != lastMOY || yearOfCommonEra != lastYOCE)
    {
      dateChanged = YES;
    }

  if (dateChanged == YES)
    {
      [self setNeedsDisplay:YES];
    }
  else if (showsLEDColon == YES && colonBlinks == YES)
    {
      [self drawColon];
    }
}

- (NSCalendarDate *)calendarDate
{
  return date;
}

//-----------------------------------------------------------------------------
#pragma mark - Defaults
//-----------------------------------------------------------------------------

// Track changes of NXClockView24HourFormat - 12/24 hour clock format
- (void)setTracksDefaultsDatabase:(BOOL)flag
{
  if (flag != tracksDefaults)
    {
      NSDistributedNotificationCenter *dnc;

      dnc = [NSDistributedNotificationCenter
              notificationCenterForType:NSLocalNotificationCenterType];
      
      if (flag == YES)
        {
          // ~/Library/Preferences/.NextSpace/NXGlobalDomain
          // NXClockView24HourFormat = YES/NO;
          [dnc addObserver:self
                  selector:@selector(defaultsChanged:)
                      name:NXUserDefaultsDidChangeNotification
                   object:nil];
        }
      else
        {
          [dnc removeObserver:self];
        }
    }
}

- (BOOL)tracksDefaultsDatabase
{
  return tracksDefaults;
}

- (void)defaultsChanged:(NSNotification *)notif
{
  NSLog(@"NXClockView: defaults was changed! %@", [notif object]);

  if ([[notif object] isKindOfClass:[NSString class]])
    {
      // NextSpace's NXGlobalDomain was changed
      [self setShows24HourFormat:
              [[NXDefaults globalUserDefaults]
                boolForKey:@"NXClockView24HourFormat"]];
    }
}

- (void)setLanguage:(NSString *)languageName
{
  [self loadImageForLanguage:languageName];
  [self setNeedsDisplay:YES];
}

@end
