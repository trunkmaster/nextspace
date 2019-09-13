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

#import <DesktopKit/NXTAlert.h>
#import <DesktopKit/NXTSavePanel.h>
#import <DesktopKit/NXTOpenPanel.h>
#import <DesktopKit/NXTHelpPanel.h>
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
  return NXTRunAlertPanel(@"Quit",
                         @"Do you really want to quit?",
                         @"Quit Now!", @"Who knows...", @"No!");
  // return NXTRunAlertPanel(@"GNU Preamble",
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
  // NXTRunAlertPanel(@"GNU Preamble",
  //                 @"This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.",
  //                 @"OK", @"Return to programm", @"Cancel");

  NXTRunAlertPanel(@"OpenStep Confusion",
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
  NXTRunAlertPanel(@"Alert with 3 line message",
                   @"This is the FIRST line.\n"
                   "This is the SECOND line.\n"
                   "This is the THIRD line.\n"
                   "This is the SECOND THIRD line.\n"
                   "This is the SECOND SECOND line.",
                  @"Dismiss", @"Kind Of", @"Something");
  // NXTAlert *alert = [[NXTAlert alloc] init];
  // [alert createPanel];
  // [alert setTitle:@"Alert with 3 line message"
  //         message:@"This is the FIRST line.\n"
  //        "This is the SECOND line.\n"
  //        "This is the THIRD line.\n"
  //       defaultBT:@"Dismiss"
  //     alternateBT:nil
  //         otherBT:nil];
  // [alert runModal];
}

- (void)showSinglelineAlert:(id)sender
{
  NXTRunAlertPanel(@"Alert with single line message",
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

- (void)showDrawingTest:(id)sender
{
  if (drawingTest == nil) {
    drawingTest = [[DrawingTest alloc] init];
  }
  [drawingTest show];
}

- (void)showHelpPanel:(id)sender
{
  NXTHelpPanel *helpPanel;

  NSString     *helpDir;

  helpDir = [[NSBundle mainBundle] pathForResource:@"Help"
                                            ofType:@""
                                       inDirectory:@""];
  // helpPanel = [NXTHelpPanel sharedHelpPanel];
  helpPanel = [NXTHelpPanel sharedHelpPanelWithDirectory:helpDir];
  NSLog(@"Order Help: (%@)%@", helpPanel, [helpPanel helpDirectory]);
  [helpPanel makeKeyAndOrderFront:self];
}
- (void)showHelpTemplatePanel:(id)sender
{
  NXTHelpPanel *helpPanel;
  NSString     *helpDir;

  helpDir = [[NSBundle mainBundle] pathForResource:@"HelpTemplate"
                                            ofType:@""
                                       inDirectory:@""];
  NSLog(@"Get Help Panel for dir: %@", helpDir);
  helpPanel = [NXTHelpPanel sharedHelpPanelWithDirectory:helpDir];
  NSLog(@"Order Help Template: (%@)%@", helpPanel, [helpPanel helpDirectory]);
  [helpPanel makeKeyAndOrderFront:self];
}

- (void)showListViewTest:(id)sender
{
  if (listViewTest == nil) {
    listViewTest = [[ListViewTest alloc] init];
  }
  [listViewTest show];
}

//
//--- Open and Save panels
//

- (void)openSavePanel:(id)sender
{
  // NSSavePanel *panel = [NSSavePanel savePanel];
  // NXTSavePanel *panel = [NXTSavePanel savePanel];
  savePanel = [NXTSavePanel new];
  
  NSLog(@"NXTSavePanel: %@, RC: %lu", [savePanel className],
        [savePanel retainCount]);
  
  // [savePanel setDirectory:NSHomeDirectory()];
  [savePanel runModal];
  [savePanel release];
}

- (void)openOpenPanel:(id)sender
{
  openPanel = [NXTOpenPanel new];
  
  NSLog(@"NXTOpenPanel: %@, RC: %lu", [openPanel className],
        [openPanel retainCount]);

  if ([NSBundle loadNibNamed:@"PanelOptions" owner:self]) {
    [accessoryView retain];
    [accessoryView removeFromSuperview];
    [openPanel setAccessoryView:accessoryView];
    [accessoryView release];
    // NSBox *accView;
    // accView = [[NSBox alloc] initWithFrame:NSMakeRect(0,0,200,100)];
    // [accView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    // [panel setAccessoryView:accView];
    // [accView release];
  }

  if (openPanel) {
    // [openPanel setDirectory:NSHomeDirectory()];
    [openPanel runModal];
    [openPanel release];
    openPanel = nil;
  }
}

//--- Save and Open
- (void)setCreateDirs:(id)sender    // Mac OS extension
{
  NXTSavePanel *panel = (savePanel != nil) ? savePanel : openPanel;
  [panel setCanCreateDirectories:[sender state]];
}
- (void)setHideExtension:(id)sender // Mac OS extension
{
  NXTSavePanel *panel = (savePanel != nil) ? savePanel : openPanel;
  [panel setExtensionHidden:[sender state]];  
}
- (void)setPkgsIsDirs:(id)sender
{
  NXTSavePanel *panel = (savePanel != nil) ? savePanel : openPanel;
  [panel setTreatsFilePackagesAsDirectories:[sender state]];
}

//--- Open only
- (void)setChooseDirs:(id)sender
{
  if (openPanel) {
    [openPanel setCanChooseDirectories:[sender state]];
  }
}
- (void)setChooseFiles:(id)sender
{
  if (openPanel) {
    [openPanel setCanChooseFiles:[sender state]];
  }
}
- (void)setMultiSelection:(id)sender
{
  if (openPanel) {
    [openPanel setAllowsMultipleSelection:[sender state]];
  }
}

@end
