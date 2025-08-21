#import <AppKit/AppKit.h>
#import <DesktopKit/NXTAlert.h>

@interface NXTCountdownAlert : NXTAlert
{
  NSString *messageTextFormat;
  NSTimer *countDownTimer;
}

@property (readwrite, nonatomic) int countDownPeriod;

- (NSTextView *)message;

@end