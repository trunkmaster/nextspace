/* All rights reserved */

#import <AppKit/AppKit.h>
#import "SlidersTest.h"

@implementation SlidersTest

- (id)init
{
  self = [super init];

  if (![NSBundle loadNibNamed:@"Sliders" owner:self]) {
    NSLog(@"SlidersTest: Could not load nib, aborting.");
    return nil;
  }

  return self;
}


- (void)awakeFromNib
{
  NSCell *cell;

  cell = [lineBorderH cell];
  [cell setBordered:YES];
  [cell setBezeled:NO];
  cell = [lineBorderV cell];
  [cell setBordered:YES];
  [cell setBezeled:NO];

  cell = [bezelBorderH cell];
  [cell setBordered:NO];
  [cell setBezeled:YES];
  cell = [bezelBorderV cell];
  [cell setBordered:NO];
  [cell setBezeled:YES];

  cell = [noBorderH cell];
  [cell setBordered:NO];
  [cell setBezeled:NO];
  cell = [noBorderV cell];
  [cell setBordered:NO];
  [cell setBezeled:NO];
}

- (void)show
{
  [window makeKeyAndOrderFront:self];
}

@end
