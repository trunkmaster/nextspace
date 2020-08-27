// Copyright 1991, 1994, 1997 Scott Hess.  Permission to use, copy,
// modify, and distribute this software and its documentation for
// any purpose and without fee is hereby granted, provided that
// this copyright notice appear in all copies.
// 
// Scott Hess makes no representations about the suitability of
// this software for any purpose.  It is provided "as is" without
// express or implied warranty.
//
// Modifications to run on Cocoa made by Gregory Casamento and 
// Alex Malmberg
//
#import "Percentages.h"
#import "TimeMonWraps.h"
#import "loadave.h"
#import "TimeMonColors.h"
#import "NSColorExtensions.h"
#import <syslog.h>
#import <math.h>

// Determines how much movement is needed for a display/redisplay.
#define MINSHOWN	0.01
// Minimum values for the defaults.
#define MINPERIOD	0.1
#define MINFACTOR	4
#define MINLAGFACTOR	1

@implementation Percentages

- (id)init
{
  self = [super init];
  if (self) {
      // stipple = [NSImage imageNamed:@"NSApplicationIcon"];
      defaults = [NSUserDefaults standardUserDefaults];
      [NSApp setDelegate:self];
    }
  return self;
}

- (void)drawImageRep
{
  NSColor *borderColor = [NSColor colorFromStringRepresentation: 
                                         [defaults stringForKey:@"BorderColor"]];

  int i;
  static float radii[3]={ 23.0, 17.0, 11.0};
  NSPoint point = NSMakePoint(24,24);
  NSBezierPath *bp = [NSBezierPath bezierPath];
  NSPoint outer = NSMakePoint(47.5, 24.0);
  NSPoint middle = NSMakePoint(41.5, 24.0);
  NSPoint inner = NSMakePoint(35.5, 24.0);
  NSPoint lineEnd = NSMakePoint(24.0, 48.0);

  for(i = 0; i < 3; i++) {
    // Store away the values we redraw.
    bcopy(pcents[i], lpcents[i], sizeof(lpcents[i])); 
    drawArc2(radii[i],
             90 - (pcents[i][0]) * 360,
             90 - (pcents[i][0] + pcents[i][1]) * 360,
             90 - (pcents[i][0] + pcents[i][1] + pcents[i][2]) * 360,
             90 - (pcents[i][0] + pcents[i][1] + pcents[i][2] + pcents[i][3]) * 360);
  }
  
  [borderColor set];
  [bp moveToPoint: outer];
  [bp appendBezierPathWithArcWithCenter:point
                                 radius:23.5
                             startAngle:0
                               endAngle:360
                              clockwise:NO];

  [bp moveToPoint: middle];
  [bp appendBezierPathWithArcWithCenter:point
                                 radius:17.5
                             startAngle:0
                               endAngle:360
                              clockwise:NO];

  [bp moveToPoint: inner];
  [bp appendBezierPathWithArcWithCenter:point
                                 radius:11.5
                             startAngle:0
                               endAngle:360
                              clockwise:NO];

  [bp moveToPoint:point];
  [bp lineToPoint:lineEnd];
  [bp stroke];
}

- (void)awakeFromNib
{
  NSString *path = [[NSBundle mainBundle] pathForResource:@"README" 
                                                   ofType:@"rtf"];
  // load the readme if it exists.
  if (path != nil) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data != nil) {
      NSDictionary  *dict = nil;
      NSTextStorage *ts = [[NSTextStorage alloc] initWithRTF:data
                                          documentAttributes:&dict];
      [[(NSTextView *)readmeText layoutManager] replaceTextStorage:ts];
    }
  }  
}

- (void)update
{
  NSImageRep *r;
  NSImage    *stipple;
  
  stipple = [[NSImage alloc] initWithSize:NSMakeSize(48,48)];
  r = [[NSCustomImageRep alloc]
        initWithDrawSelector:@selector(drawImageRep)
                    delegate:self];
  [r setSize:NSMakeSize(48,48)];
  [stipple addRepresentation:r];
  [NSApp setApplicationIconImage:stipple];

  [r release];
  [stipple release];  /* setApplicationIconImage does a retain, so we release */
}

- (void)step
{
  int i, j, oIndex;
  float total;
  
  // Read the new CPU times.
  la_read(oldTimes[laIndex]);
  
  // The general idea for calculating the ring values is to
  // first find the earliest valid index into the oldTimes
  // table for that ring.  Once in a "steady state", this is
  // determined by the lagFactor and/or layerFactor values.
  // Prior to steady state, things are restricted by how many
  // steps have been performed.	 Note that the index must
  // also be wrapped around to remain within the table.
  // 
  // The values are all then easily calculated by subtracting
  // the info at the old index from the info at the current
  // index.
  
  // Calculate values for the innermost "lag" ring.
  oIndex=(laIndex-MIN(lagFactor, steps)+laSize)%laSize;
  for(total=0, i=0; i<CPUSTATES; i++) {
    total+=oldTimes[laIndex][i]-oldTimes[oIndex][i];
  }
  if (total) {
    for (i = 0; i < CPUSTATES; i++)
      pcents[2][i] = (oldTimes[laIndex][i] - oldTimes[oIndex][i]) / total;
  }
  
  // Calculate the middle ring.
  oIndex=(laIndex-MIN(lagFactor+layerFactor, steps)+laSize)%laSize;
  for(total=0, i=0; i<CPUSTATES; i++) {
    total+=oldTimes[laIndex][i]-oldTimes[oIndex][i];
  }
  if (total) {
    for (i = 0; i < CPUSTATES; i++)
      pcents[1][i] = (oldTimes[laIndex][i] - oldTimes[oIndex][i]) / total;
  }
  
  // Calculate the outer ring.
  oIndex=(laIndex-MIN(lagFactor+layerFactor*layerFactor, steps)+laSize)%laSize;
  for(total=0, i=0; i<CPUSTATES; i++) {
    total+=oldTimes[laIndex][i]-oldTimes[oIndex][i];
  }
  if (total) {
    for (i = 0; i < CPUSTATES; i++)
      pcents[0][i] = (oldTimes[laIndex][i] - oldTimes[oIndex][i]) / total;
  }
  
  // Move the index forward for the next cycle.
  laIndex = (laIndex + 1) % laSize;
  steps++;
  
  // Look through the rings and see if any values changed by
  // one percent or more, and if so mark that and inner rings
  // for update.
  for (i = 0; i < CPUSTATES; i++) {
    for (j = 0; j < CPUSTATES; j++) {
      if (rint(pcents[i][j] * 100) != rint(lpcents[i][j] * 100)) {
        for ( ; i < 3; i++) {
          updateFlags[i] = YES;
        }
        break;
      }
    }
  }
  
  // If there's a need for updating of any rings, call update.
  if (updateFlags[2]) {
    [self update];
  }
}

// This was for debugging, no longer needed.  I used it to hook
// up a menu item to manually call step.
- (void)cycle:(id)sender
{
  [self step];
}

// Resize the oldTimes array and rearrange the values within
// so that as many as possible are retained, but no bad values
// are introduced.
- (void)__reallocOldTimes
{
  CPUTime *newTimes;
  // Get the new size for the array.
  unsigned newSize = layerFactor * layerFactor + lagFactor + 1;
    
  // Allocate info for the array.
  newTimes = NSZoneMalloc([self zone], sizeof(CPUTime) * newSize);
  bzero(newTimes, sizeof(CPUTime) * newSize);
    
  // If there was a previous array, copy over values.  First,
  // an index is found for the first valid time.	Then enough
  // times to fill the rings are copied, if available.
  if (oldTimes) {
    unsigned ii, jj, elts;
	
    elts = MIN(lagFactor + layerFactor * layerFactor + 1, steps);
    ii = (laIndex + laSize - elts) % laSize;
    jj = MIN(laSize - ii, elts);
	
    if (jj){
      bcopy(oldTimes + ii, newTimes + 0, jj * sizeof(oldTimes[0]));
    }
    if (jj < elts) {
      bcopy(oldTimes + 0, newTimes + jj, (elts - jj) * sizeof(oldTimes[0]));
    }
	
    // Free the old times.
    NSZoneFree([self zone], oldTimes);
  }
    
  // Reset everything so that we only access valid data.
  oldTimes	= newTimes;
  laIndex	= MIN(steps, laSize);
  laIndex	= MIN(laIndex, newSize)%newSize;
  steps	= MIN(steps, laSize);
  steps	= MIN(steps, newSize);
  laSize	= newSize;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  float f;
  int ret;
  CPUTime cp_time;
  SEL stepSel = @selector(step);
  NSMethodSignature *sig = [self methodSignatureForSelector:stepSel];
  NSDictionary *defs;

  defs = @{@"UpdatePeriod":@"0.5",
           @"LagFactor":@"4",
           @"LayerFactor":@"16",
           @"HideOnAutolaunch":@"YES",
           // For color systems.
           @"IdleColor":@"1.000 1.000 1.000 1.000",     // White
           @"NiceColor":@"0.333 0.667 0.867 1.000",     // A light blue-green
           @"UserColor":@"0.200 0.467 0.800 1.000",     // A darker blue-green
           @"SystemColor":@"0.000 0.000 1.000 1.000",   // Blue
           @"IOWaitColor":@"1.000 0.800 0.900 1.000",   // Light purple
           @"BorderColor":@"0.000 0.000 0.000 1.000",   // Default border color
           // For monochrome systems.
           @"IdleGray":@"1.000",                        // White
           @"NiceGray":@"0.667",                        // Light gray
           @"UserGray":@"0.333",                        // Dark gray
           @"SystemGray":@"0.000",                      // Black
  };

  [defaults registerDefaults:defs];
  [defaults synchronize];
	
  // Shoot out error codes if there was an error.
  if ((ret = la_init(cp_time))) {
    const id syslogs[] = {
                          NULL,					// LA_NOERR
                          @"Cannot read or parse /proc/stat."	// LA_ERROR
    };
    NSLog(@"TimeMon: %@", syslogs[ret]);
    NSLog(@"TimeMon: Exiting!");
    NSRunAlertPanel(@"TimeMon", syslogs[ret], @"OK", nil, nil, nil);
    [NSApp terminate:[notification object]];
  }

  // Get us registered for periodic exec.
  f = [defaults floatForKey:@"UpdatePeriod"];
  f = MAX(f, MINPERIOD);
  [periodText setFloatValue:f];
    
  selfStep = [[NSInvocation invocationWithMethodSignature:sig] retain];
  [selfStep setSelector:stepSel];
  [selfStep setTarget:self];
  [selfStep retainArguments];
  te = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)f
                                    invocation:selfStep
                                       repeats:YES];
    
  // Get the lag factor.
  lagFactor = [defaults integerForKey:@"LagFactor"];
  lagFactor = MAX(lagFactor, MINLAGFACTOR);
  [lagText setIntValue:lagFactor];
    
  // Get the layer factor.
  layerFactor = [defaults integerForKey:@"LayerFactor"];
  layerFactor = MAX(layerFactor, MINFACTOR);
  [factorText setIntValue:layerFactor];
    
  [self __reallocOldTimes];
  bcopy(cp_time, oldTimes[0], sizeof(CPUTime));
  laIndex = 1;
  steps = 1;

  [colorFields setDrawsBackground:YES];
  [colorFields readColors];
  
  [self update];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(id)sender
{
  // If te is installed, remove it.
  if (te) {
    [te invalidate];
    te = nil;
  }
  // [stipple release];
  la_finish();
  return NSTerminateNow;
}

- (void)display
{
  updateFlags[0] = updateFlags[1] = updateFlags[2] = YES;
  [self update];
}

- (void)togglePause:(id)sender
{
  if (te) {
    NSImage *pausedImage = [NSImage imageNamed:@"TimeMonP"];
    NSImage *pausedStipple = [NSApp applicationIconImage];
      
    [pauseMenuCell setTitle:@"Continue"];
    [te invalidate];
    te = nil;
      
    [pausedStipple lockFocus];
    [pausedImage compositeToPoint:NSZeroPoint 
                        operation:NSCompositeSourceOver];
    [pausedStipple unlockFocus];
      
    [NSApp setApplicationIconImage:pausedStipple];
  } 
  else {
    float f;
    [pauseMenuCell setTitle:@"Pause"];
    f = [defaults floatForKey:@"UpdatePeriod"];
    f = MAX(f, MINPERIOD);
    [periodText setFloatValue:f];
    te = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)f
                                      invocation:selfStep
                                         repeats:YES];
    [self display];
  }
}

- (void)setPeriod:(id)sender
{
  [defaults setObject:[periodText stringValue] forKey:@"UpdatePeriod"];
  [defaults synchronize];
  if (te) {
    float f;
    [te invalidate];
    f = [defaults floatForKey:@"UpdatePeriod"];
    f = MAX(f, MINPERIOD);
    [periodText setFloatValue:f];
    te = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)f
                                      invocation:selfStep
                                         repeats:YES];
  }
}

- (void)setLag:(id)sender
{
  [defaults setObject:[lagText stringValue] forKey:@"LagFactor"];
  [defaults synchronize];
  lagFactor = [defaults integerForKey:@"LagFactor"];
  lagFactor = MAX(lagFactor, MINLAGFACTOR);
  [lagText setIntValue:lagFactor];
  [self __reallocOldTimes];
}

- (void)setFactor:(id)sender
{
  [defaults setObject:[factorText stringValue] forKey:@"LayerFactor"];
  [defaults synchronize];
  layerFactor = [defaults integerForKey:@"LayerFactor"];
  layerFactor = MAX(layerFactor, MINFACTOR);
  [factorText setIntValue:layerFactor];
  [self __reallocOldTimes];
}

- (BOOL)textShouldEndEditing:(NSText *)sender
{
  id delegate = [sender delegate];
  
  if (delegate == factorText) 
    {
      [self setFactor:factorText];
    } 
  else if (delegate == periodText) 
    {
      [self setPeriod:periodText];
    } 
  else if (delegate == lagText) 
    {
      [self setLag:lagText];
    }

  return YES;
}
@end
