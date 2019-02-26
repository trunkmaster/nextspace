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
  return NXRunAlertPanel(@"Quit",
                         @"Do you really want to quit?",
                         @"Quit Now!", @"Who knows...", @"No!");
  // return NXRunAlertPanel(@"GNU Preamble",
  //                        @"This program is free software; \nyou can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; \neither version 2 of the License, or (at your option) any later version.",
  //                        @"Default", @"Alternate Button", @"Other");
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

- (void)showMultilineAlert:(id)sender
{
  // NXRunAlertPanel(@"GNU Preamble",
  //                 @"This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.",
  //                 @"OK", @"Return to programm", @"Cancel");

  NXRunAlertPanel(@"OpenStep Confusion",
                  @"History\n"
                  "While the company \"NeXT\" has always been spelled with a lowercase \"e\", to make the logo look better and to make the name more recognizable in print, the names of the product changed quite often. Here is a detailed history as Garance A. Drosehn and we understand it.\n"
                  "NextStep - has never been used as a spelling as far as we can tell. But the all lowercase \"Next\" portion can be found in default filesystem locations such as: NextApps, NextLibrary, etc. These folder names have lasted until 1997 ... no matter how NeXT called their operating system.\n"
                  "NeXTstep - \"originally\" was the name of the GUI and API parts (without the operating system). This was back in the days when IBM was going to port those parts to run on AIX. So the name \"NeXTstep\" was used to indicate what parts of the system IBM was getting.\n"
                  "NeXTStep - was used for the whole system (GUI, Apps, MachOS, etc.) and sometimes even referred to the hardware (e.g. \"I use a NeXTStep machine\"). The first release was in 1988, with version 2.0 following in 1990 and another major leap in 1993 when release 3.0 went public.\n"
                  "NeXTSTEP - defined the entire software package (since release 3.1 in late 1993) and became popular as the system got ported to Intel hardware. It now no longer included the hardware and maybe they figured that the all caps \"STEP\" would be less problematic to the press which seldom got the spelling right anyway. But the lower \"e\" still kept the company visible. The product was sold as NeXTSTEP (for the original NeXT hardware) and NeXTSTEP/Intel.\n"
                  "NEXTSTEP - was either the attempt to get away from the \"NeXT hardware\" association, since it no longer had the lower case \"e\", or they just got tired of giving reasons for the weird spelling. During that time NeXT also was on the transition to morph from \"NeXT Computer Inc\" to \"NeXT Software Inc\".\n"
                  "NEXTSTEP was still based on Mach, but now sold as NEXTSTEP/NeXT Computers (black), NEXTSTEP/Intel (white), NEXTSTEP/PA-RISC (green) and NEXTSTEP/SPARC (yellow). The colors where a shortcut which sometimes have been used in the community.",
                  @"Ok", nil, nil);  
}

- (void)show3LineAlert:(id)sender
{
  // NXRunAlertPanel(@"Alert with 3 line message",
  //                 @"This is the FIRST line.\n"
  //                 "This is the SECOND line.\n"
  //                 "This is the THIRD line.\n",
  //                 @"Dismiss", nil, nil);
  NXAlert *alert = [[NXAlert alloc] init];
  [alert createPanel];
  [alert setTitle:@"Alert with 3 line message"
          message:@"This is the FIRST line.\n"
         "This is the SECOND line.\n"
         "This is the THIRD line.\n"
        defaultBT:@"Dismiss"
      alternateBT:nil
          otherBT:nil];
  [alert runModal];
}

- (void)showSinglelineAlert:(id)sender
{
  NXRunAlertPanel(@"Alert with single line message",
                  @"What is you favourite drink?",
                  @"Wiskey", @"Beer", @"Vodka");
}

- (void)showCursorsTest:(id)sender
{
  if (cursorsTest == nil)
    {
      cursorsTest = [[CursorsTest alloc] init];
    }
  [cursorsTest show];
}

- (void)showIconViewTest:(id)sender
{
  if (iconViewTest == nil)
    {
      iconViewTest = [[IconViewTest alloc] init];
    }
  [iconViewTest show];
}

- (void)showTextTest:(id)sender
{
  if (textTest == nil) {
    textTest = [[TextTest alloc] init];
  }
  [textTest show];
}

@end
