/* All rights reserved */

#include <AppKit/AppKit.h>
#include "MyController.h"

@implementation MyController


- (void) buttonPressed: (id)sender
{
  [value setStringValue: @"Hello"];
}

- (void) openWindow: (id) sender
{
    winController = [[WinController alloc] init];
}

- (void) dealloc
{
  [super dealloc];
  RELEASE(winController);
}

@end
