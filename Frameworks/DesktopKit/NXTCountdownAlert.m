/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Description: Alert panel with countdown displayed in message.
//              
//
// Copyright (C) 2025- Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

#import "NXTCountdownAlert.h"

@implementation NXTCountdownAlert

- (void)dealloc
{
  [messageTextFormat release];
  [super dealloc];
}

- (void)setCountDownPeriod:(int)seconds
{
  NSString *messageText;

  // Countdown period can be set only if timer is not created
  if (seconds <= 0 || (countDownTimer != nil && countDownPeriod > 0)) {
    return;
  }

  countDownPeriod = seconds;

  messageText = [messageView text];
  if ([messageText rangeOfString:@"%"].location == NSNotFound) {
    NSLog(@"NXTCountdownAlert: message has no formatting characher - using default.");
    messageTextFormat = @"Panel will be closed after %i seconds";
  } else {
    messageTextFormat = [[NSString alloc] initWithString:messageText];
  }
  [messageView setText:[NSString stringWithFormat:messageTextFormat, countDownPeriod]];

  countDownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                    target:self
                                                  selector:@selector(update:)
                                                  userInfo:nil
                                                   repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:countDownTimer forMode:NSModalPanelRunLoopMode];
}

- (void)update:(NSTimer *)timer
{
//   NSLog(@"%s - %i", __func__, countDownPeriod);
  if (countDownPeriod <= 0 || [countDownTimer isValid] == NO) {
    [countDownTimer invalidate];
    [panel orderOut:self];
    [NSApp stopModalWithCode:NSAlertDefaultReturn];
  } else {
    [messageView setText:[NSString stringWithFormat:messageTextFormat, countDownPeriod]];
    countDownPeriod--;
  }
}

- (NSInteger)runModal
{
  NSInteger result;

  [countDownTimer fire];
  result = [super runModal];
  if ([countDownTimer isValid]) {
    [countDownTimer invalidate];
  }

  return result;
}

@end