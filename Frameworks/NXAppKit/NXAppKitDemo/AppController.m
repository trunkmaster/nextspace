/*
  Class:               AppController
  Inherits from:       NSObject
  Class descritopn:    NSApplication delegate

  Copyright (C) 2016 Sergii Stoian

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <NXAppKit/NXAlert.h>
#import "AppController.h"

@implementation AppController : NSObject

- (void)awakeFromNib
{
}

- (void)dealloc
{
  TEST_RELEASE(numericFieldTest);

  [super dealloc];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  return NXRunAlertPanel(@"Log Out",
                         @"Do you really want to logout?",
                         @"Log Out", @"Power Off", @"Cancel");
  // return NXRunAlertPanel(@"GNU Preamble",
  //                        @"This program is free software; \nyou can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; \neither version 2 of the License, or (at your option) any later version.",
  //                        @"Default", @"Alternate", @"Other");
}

//----------------------------------------------------------------------------
#pragma mark | Actions
//----------------------------------------------------------------------------

- (void)showTextFieldsDemo:(id)sender
{
  if (numericFieldTest == nil)
    {
      numericFieldTest = [[NumericFieldTest alloc] init];
    }
  [numericFieldTest show];
}

- (void)showClockViewDemo:(id)sender
{
  if (clockViewTest == nil)
    {
      clockViewTest = [[ClockViewTest alloc] init];
    }
  [clockViewTest show];
}

@end
