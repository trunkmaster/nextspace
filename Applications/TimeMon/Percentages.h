// Copyright 1991, 1994, 1997 Scott Hess.  Permission to use, copy,
// modify, and distribute this software and its documentation for
// any purpose and without fee is hereby granted, provided that
// this copyright notice appear in all copies.
// 
// Scott Hess makes no representations about the suitability of
// this software for any purpose.  It is provided "as is" without
// express or implied warranty.
//
#import <AppKit/AppKit.h>
#import "loadave.h"

typedef unsigned long long CPUTime[CPUSTATES];

@interface Percentages : NSObject
{
  CPUTime        *oldTimes;		// The array of collected CPU times for
					// the previous lagFactor+layerFactor^2
					// time slices.
  int            laIndex;		// Index into the array of collected values.
  int            laSize;		// lagFactor+layerFactor^2
  int            lagFactor;		// How long to average for the inner circle.
  int            layerFactor;		// The factor that differentiates layers.
  unsigned       steps;			// Number of steps we've done.
  float          pcents[3][CPUSTATES];	// Percentages for display.
  float          lpcents[3][CPUSTATES];	// Last-displayed percentages.

  BOOL           updateFlags[3];	// Which percentages to update.
  NSTimer        *te;			// The timed entry keeping us alive.
  NSInvocation   *selfStep;		// The invocation describing [self step]
  NSUserDefaults *defaults;
  id             periodText;		// Period of the display.
  id             lagText;		// Lag factore for the inner circle.
  id             factorText;		// Factor between layers.
  id             pauseMenuCell;		// To change when we pause/unpause.
  id             colorFields;		// Fields that contain the color scheme.
  id             readmeText;		// the readme text...
}

// Action methods
- (void)togglePause:(id)sender;
- (void)setPeriod:(id)sender;
- (void)setLag:(id)sender;
- (void)setFactor:(id)sender;

    // Update as indicated by updateFlags.
- (void)update;
    // Get new _cp_time and apply that data to percentages.
- (void)step;
    // Hook into initialization process of app.
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
    // Pull out timed entries and stuff.
- (NSApplicationTerminateReply)applicationShouldTerminate:(id)sender;
- (void)display;

@end
