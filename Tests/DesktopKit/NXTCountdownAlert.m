#import "NXTCountdownAlert.h"

@implementation NXTCountdownAlert

- (id)initWithTitle:(NSString *)titleText
            message:(NSString *)messageText
      defaultButton:(NSString *)defaultText
    alternateButton:(NSString *)alternateText
        otherButton:(NSString *)otherText
{
  [super initWithTitle:titleText
               message:messageText
         defaultButton:defaultText
       alternateButton:alternateText
           otherButton:otherText];

  if ([messageText rangeOfString:@"%"].location == NSNotFound) {
    NSLog(
        @"NXTCountdownAlert: message doesn't contain formatting characher - using default message");
    messageTextFormat = @"Panel will be closed after %i seconds";
  } else {
    messageTextFormat = [messageText copy];
  }
  
  return self;
}

- (void)setCountDownPeriod:(int)countDownPeriod
{
  _countDownPeriod = countDownPeriod;
  [messageView setText:[NSString stringWithFormat:messageTextFormat, _countDownPeriod]];
}

- (NSTextView *)message
{
  return messageView;
}

- (void)update:(NSTimer *)timer
{
  NSLog(@"%s - %i", __func__, _countDownPeriod);
  [messageView setText:[NSString stringWithFormat:messageTextFormat, _countDownPeriod]];
  if (_countDownPeriod <= 0) {
    [countDownTimer invalidate];
    [panel orderOut:self];
    [NSApp stopModalWithCode:0];
  } else {
    _countDownPeriod--;
  }
}

- (NSInteger)runModal
{
  NSInteger result;

  countDownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                    target:self
                                                  selector:@selector(update:)
                                                  userInfo:nil
                                                   repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:countDownTimer forMode:NSModalPanelRunLoopMode];
  [countDownTimer fire];
  [self show];

  result = [NSApp runModalForWindow:panel];
  if ([countDownTimer isValid]) {
    [countDownTimer invalidate];
  }
  [panel orderOut:self];
  
  return result;
}

@end