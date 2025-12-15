/* All rights reserved */

#import "SlidersTest.h"

@implementation SlidersTest

- (void)awakeFromNib
{
  [lineBorderH setBorderType:NSLineBorder];
  [lineBorderV setBorderType:NSLineBorder];

  [bezelBorderH setBorderType:NSBezelBorder];
  [bezelBorderV setBorderType:NSBezelBorder];

  [noBorderH setBorderType:NSNoBorder];
  [noBorderV setBorderType:NSNoBorder];
}

- (void)show
{
  [window makeKeyAndOrderFront:self];
}

@end
