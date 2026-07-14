/* All rights reserved */

#include <AppKit/AppKit.h>
#include "WinController.h"

@implementation WinController

- (id) init
{
  if((self = [super init]) != nil)
    {
      if([NSBundle loadNibNamed: @"Controller" owner: self] == NO)
	{
	  NSLog(@"Problem loading interface");
	  return nil;
	}
      [window makeKeyAndOrderFront: self];
    }

  return self;
}

- (void) closeWindow: (id) sender
{
  [window close];
}

- (void) dealloc
{
  [super dealloc];
  RELEASE(window);
}

@end
