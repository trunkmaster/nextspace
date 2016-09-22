
#import "NXClockView.h"

#import <AppKit/AppKit.h>

@implementation NXClockView (Private)

@end

@implementation NXClockView

#pragma mark - Init and dealloc

- initWithFrame:(NSRect)aFrame
{
  // self = [super initWithFrame:NSMakeRect(0, 0, 55, 71)];
  self = [super initWithFrame:aFrame];

  // Defaults
  showsLEDColon = YES;
  shows12HourFormat = YES;
  // shows12HourFormat = [[NSUserDefaults standardUserDefaults]
  //                       boolForKey:@"NXClockViewShows12HourFormat"];
  [self setTracksDefaultsDatabase:YES];

  // Image rects
  tileRect = NSMakeRect(191, 9, 64, 71);
  
  mondayRect = NSMakeRect(0, 71, 21, 6);     // 'MON' + one white line below
  januaryRect = NSMakeRect(40, 72, 22, 6);   // 'JAN' + one white line above
  firstDayRect = NSMakeRect(64, 14, 12, 17); // '1'

  // it's inside tile rect
  ledDisplayRect = NSMakeRect(5, 51, 53, 16);
  
  led_nums[0] = NSMakeRect(150, 57, 9, 11); // 0
  led_nums[1] = NSMakeRect(83,  57, 4, 11); // 1
  led_nums[2] = NSMakeRect(87,  57, 8, 11); // 2
  led_nums[3] = NSMakeRect(95,  57, 8, 11); // 3
  led_nums[4] = NSMakeRect(103, 57, 8, 11); // 4
  led_nums[5] = NSMakeRect(111, 57, 7, 11); // 5
  led_nums[6] = NSMakeRect(118, 57, 8, 11); // 6
  led_nums[7] = NSMakeRect(126, 57, 7, 11); // 7
  led_nums[8] = NSMakeRect(133, 57, 9, 11); // 8
  led_nums[9] = NSMakeRect(142, 57, 8, 11); // 9

  ledColonRect = NSMakeRect(159, 57, 3,  11);
  ledAMRect    = NSMakeRect(162, 56, 13, 11);
  ledPMRect    = NSMakeRect(175, 56, 12, 11);

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
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  TEST_RELEASE(yearField);
  TEST_RELEASE(date);

  [super dealloc];
}

#pragma mark - Drawing

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
  float  offset;
  float  hoffset;
  int    dayOfMonth;
  int    hourOfDay;
  int    minuteOfHour;
  BOOL   morning = NO;
  CGFloat rectCenter = r.size.width/2;
  NSRect  elRect;
  NSPoint elPoint;
  int     v_offset;

  // if (showsYear)
  //   offset = 11;
  // else
    offset = 0;

  elPoint = NSMakePoint(rectCenter - ceilf(tileRect.size.width/2), offset);
  [clockBits compositeToPoint:elPoint
                     fromRect:tileRect
                    operation:NSCompositeSourceOver];

  if (date == nil)
    return;

  // --- Date
  
  // Day of week
  elRect = mondayRect;
  elRect.origin.y -= ([date dayOfWeek] > 0 ? [date dayOfWeek] : 7) * mondayRect.size.height;
  elPoint = NSMakePoint(rectCenter - ceilf(elRect.size.width/2),
                        offset + 41);
  [clockBits  compositeToPoint:elPoint
                      fromRect:elRect
                     operation:NSCompositeSourceOver];

  // Month
  elRect = januaryRect;
  elRect.origin.y -= [date monthOfYear] * januaryRect.size.height;
  elPoint = NSMakePoint(rectCenter - ceilf(elRect.size.width/2),
                        offset + 16);
  [clockBits  compositeToPoint:elPoint
                      fromRect:elRect
                     operation:NSCompositeSourceOver];

  // Day of month
  dayOfMonth = [date dayOfMonth];
  v_offset = offset + 31 - (firstDayRect.size.height/2);
  if (dayOfMonth > 9)
    {
      CGFloat x = rectCenter - firstDayRect.size.width;
      int     decade, day;

      // Decade of month
      elRect = firstDayRect;
      decade = (dayOfMonth - (dayOfMonth % 10)) / 10;
      elRect.origin.x += (decade - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint(x, v_offset);
      [clockBits  compositeToPoint:elPoint
                          fromRect:elRect
                         operation:NSCompositeSourceOver];
      // Day of decade
      elRect = firstDayRect;
      if ((day = dayOfMonth % 10) == 0)
        day = 10;
      elRect.origin.x += (day - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint(x + (firstDayRect.size.width-2), v_offset);
      [clockBits  compositeToPoint:elPoint
                          fromRect:elRect
                         operation:NSCompositeSourceOver];
    }
  else
    {
      elRect = firstDayRect;
      elRect.origin.x += (dayOfMonth - 1) * firstDayRect.size.width;
      elPoint = NSMakePoint(rectCenter - firstDayRect.size.width/2, v_offset);
      [clockBits  compositeToPoint:elPoint
                          fromRect:elRect
                         operation:NSCompositeSourceOver];
    }

  // --- Time
  
  hourOfDay = [date hourOfDay];
  minuteOfHour = [date minuteOfHour];

  if (shows12HourFormat)
    {
      if (hourOfDay == 0)
	{
	  hourOfDay = 12;
	  morning = YES;
	}
      else if (hourOfDay < 12)
	{
	  morning = YES;
	}
      else
	{
	  if (hourOfDay > 12)
	    hourOfDay -= 12;
	  morning = NO;
	}

      hoffset = -4;
    }
  else
    {
      hoffset = 3;
    }

  rectCenter = hoffset + ledDisplayRect.size.width/2;
  offset = ledDisplayRect.origin.y + (ledDisplayRect.size.height - 11)/2;

  // Colon
  hoffset = rectCenter - ledColonRect.size.width/2;
  if (showsLEDColon)
    {
      [clockBits  compositeToPoint:NSMakePoint(hoffset, offset)
                          fromRect:ledColonRect
                         operation:NSCompositeSourceOver];
      // if (0) // if blinking enabled
      //   {
      //     [self setShowsLEDColon:!showsLEDColon];
      //   }
    }
  
  // Hours
  // second digit of hour
  elRect = led_nums[(hourOfDay % 10)];
  hoffset -= elRect.size.width;
  [clockBits  compositeToPoint:NSMakePoint(hoffset, offset)
                      fromRect:elRect
                     operation:NSCompositeSourceOver];

  // first digit of hour
  if (!shows12HourFormat || hourOfDay > 9)
    {
      elRect = led_nums[((hourOfDay - (hourOfDay % 10)) / 10)];
      hoffset -= elRect.size.width;
      [clockBits  compositeToPoint:NSMakePoint(hoffset, offset)
                          fromRect:elRect
                         operation:NSCompositeSourceOver];
    }

  // Minutes
  hoffset = rectCenter + ledColonRect.size.width/2;
  elRect = led_nums[(minuteOfHour - (minuteOfHour % 10)) / 10];
  [clockBits  compositeToPoint:NSMakePoint(hoffset, offset)
                      fromRect:elRect
                     operation:NSCompositeSourceOver];
  hoffset += elRect.size.width;
  elRect = led_nums[minuteOfHour % 10];
  [clockBits  compositeToPoint:NSMakePoint(hoffset, offset)
                      fromRect:elRect
                     operation:NSCompositeSourceOver];
  hoffset += elRect.size.width;

  // am/pm
  if (shows12HourFormat)
    {
      float voffset;
      hoffset = (ledDisplayRect.origin.x + ledDisplayRect.size.width);
      voffset = offset + (ledDisplayRect.size.height-2-ledAMRect.size.height)/2;
      if (morning)
        {
          hoffset -= ledAMRect.size.width + 3;
          [clockBits  compositeToPoint:NSMakePoint(hoffset, voffset)
                              fromRect:ledAMRect
                             operation:NSCompositeSourceOver];
        }
      else
        {
          hoffset -= ledPMRect.size.width + 3;
          [clockBits  compositeToPoint:NSMakePoint(hoffset, voffset)
                              fromRect:ledPMRect
                             operation:NSCompositeSourceOver];
        }
    }
}

#pragma mark - Properties

- (void)setShowsYear:(BOOL)flag
{
  if (showsYear == NO && flag == YES)
    {
      if (yearField == nil)
        {
          yearField = [[NSTextField alloc]
                          initWithFrame:NSMakeRect(0, 0, 64, 12)];
          [yearField setFont:
                       [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
          [yearField setEditable:NO];
          [yearField setSelectable:NO];
          [yearField setBordered:NO];
          [yearField setBezeled:NO];
          [yearField setDrawsBackground:NO];
          [yearField setAlignment:NSCenterTextAlignment];
        }

      if (date != nil)
        [yearField setIntValue:[date yearOfCommonEra]];
      else
        [yearField setStringValue:nil];

      [self addSubview:yearField];
    }
  else if (showsYear == YES && flag == NO)
    {
      [yearField removeFromSuperview];
    }
  showsYear = flag;
}

- (BOOL)showsYear
{
  return showsYear;
}

- (void)setShows12HourFormat:(BOOL)flag
{
  if (shows12HourFormat != flag)
    {
      shows12HourFormat = flag;
      [self setNeedsDisplay:YES];
    }
}

- (BOOL)shows12HourFormat
{
  return shows12HourFormat;
}

- (void)setShowsLEDColon:(BOOL)flag
{
  if (showsLEDColon != flag)
    {
      showsLEDColon = flag;
      [self setNeedsDisplay:YES];
    }
}

- (BOOL)showsLEDColon
{
  return showsLEDColon;
}

- (void)setCalendarDate:(NSCalendarDate *)aDate
{
  ASSIGN(date, aDate);

  if (yearField != nil)
    [yearField setIntValue:[date yearOfCommonEra]];

  [self setNeedsDisplay:YES];
}

- (NSCalendarDate *)calendarDate
{
  return date;
}

#pragma mark - Defaults

// Track changes of:
// - NSLanguages - language order
// - NXClockView24HourFormat - 12/24 hour clock format
- (void)setTracksDefaultsDatabase:(BOOL)flag
{
  if (flag != tracksDefaults)
    {
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      
      if (flag == YES)
        {
          [nc addObserver:self
                 selector:@selector(defaultsChanged:)
                     name:NSUserDefaultsDidChangeNotification
                   object:[NSUserDefaults standardUserDefaults]];
        }
      else
        {
          [nc removeObserver:self];
        }
    }
}

- (BOOL)tracksDefaultsDatabase
{
  return tracksDefaults;
}

- (void)defaultsChanged:(NSNotification *)notif
{
  NSUserDefaults *df = [notif object];
  NSArray        *languages = nil;

  // NextSpace's NXGlobalDomain was changed
  if ([df objectForKey:@"NXClockView24HourFormat"] != nil)
    {
      BOOL flag;
      
      flag = [df boolForKey:@"NXClockView24HourFormat"];
      if (flag != shows12HourFormat)
        {
          shows12HourFormat = flag;
          [self setNeedsDisplay:YES];
        }
      return;
    }

  // GNUstep's NSGlobalDomain was changed
  if ((languages = [df objectForKey:@"NSLanguages"]) != nil &&
      [languages isKindOfClass:[NSArray class]])
    {
      [self loadImageForLanguage:[languages objectAtIndex:0]];
      [self setNeedsDisplay:YES];
      return;
    }
}

- (void)setLanguage:(NSString *)languageName
{
  [self loadImageForLanguage:languageName];
  [self setNeedsDisplay:YES];
}

@end
