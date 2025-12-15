/* All rights reserved */

#import <AppKit/AppKit.h>

@interface SlidersTest : NSObject
{
  IBOutlet id bezelBorderH;
  IBOutlet id bezelBorderV;
  IBOutlet id lineBorderH;
  IBOutlet id lineBorderV;
  IBOutlet id noBorderV;
  IBOutlet id noBorderH;
  IBOutlet id window;
}

- (void)show;

@end
