#import <AppKit/AppKit.h>

@interface BatteryView : NSView
{
  NSInteger percentage;
  NSInteger acLine;
  NSInteger batteryState;
  BOOL available;
}
- (void)setPercentage:(NSInteger)percent ac:(NSInteger)ac state:(NSInteger)state;
- (void)setUnavailable;
@end
