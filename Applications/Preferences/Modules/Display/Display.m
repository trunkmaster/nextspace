/*
  Display.m

  Controller class for Display preferences bundle

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		28 Nov 2015

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  Free Software Foundation, Inc.
  59 Temple Place - Suite 330
  Boston, MA  02111-1307, USA
*/
#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSPopUpButton.h>
// #import <AppKit/NSTableView.h>
// #import <AppKit/NSTableColumn.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSBrowserCell.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSSlider.h>

#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>

#import "Display.h"

@implementation DisplayPrefs

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Monitor" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  [image release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Display" owner:self])
        {
          NSLog (@"Display.preferences: Could not load nib \"Display\", aborting.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Display Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (IBAction)monitorsListClicked:(id)sender
{
  NSString *mName = [[[sender matrixInColumn:0] selectedCell] title];
  NSSize   size;
  NSString *resolution;
  
  NSLog(@"Display.preferences: selected monitor with title: %@", mName);

  for (NXDisplay *d in [[NXScreen sharedScreen] connectedDisplays])
    {
      if ([[d outputName] isEqualToString:mName])
        {
          NSArray      *m = [d allModes];
          NSDictionary *r;

          // Resolution
          [resolutionBtn removeAllItems];
          [rateBtn removeAllItems];
          for (NSDictionary *res in m)
            {
              size = NSSizeFromString([res objectForKey:@"Dimensions"]);
              resolution = [NSString stringWithFormat:@"%.0f x %.0f",
                                     size.width, size.height];
              [resolutionBtn addItemWithTitle:resolution];
              [rateBtn addItemWithTitle:[[res objectForKey:@"Rate"] stringValue]];
            }
          r = [d mode];
          [resolutionBtn selectItemAtIndex:[m indexOfObject:r]];
          [rateBtn selectItemWithTitle:[[r objectForKey:@"Rate"] stringValue]];

          // Gamma
          CGFloat gamma = [d gammaValue].red;
          [gammaSlider setFloatValue:1.0/gamma];
          [gammaField setStringValue:[NSString stringWithFormat:@"%.2f", 1.0/gamma]];

          // Brightness
          CGFloat brightness = [d gammaBrightness];
          [brightnessSlider setFloatValue:brightness];
          [brightnessField
             setStringValue:[NSString stringWithFormat:@"%.0f", brightness*100]];
        }
    }
}

- (IBAction)sliderMoved:(id)sender
{
  if (sender == gammaSlider)
    {
      // NSLog(@"Gamma slider moved");
      [gammaField setFloatValue:[sender floatValue]];
    }
  else if (sender == brightnessSlider)
    {
      // NSLog(@"Brightness slider moved");
      [brightnessField setFloatValue:[sender floatValue]*100];
    }
  else
    NSLog(@"Unknown slider moved");  
}

//
// Delegate methods
//
- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(NSInteger)column
{
  if (column > 0)
    return @"";

  return @"Monitors";
}

- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSArray *displays;
  NSBrowserCell *bc;

  if (column > 0)
    return;
  
  displays = [[NXScreen sharedScreen] connectedDisplays];
    
  for (NXDisplay *d in displays)
    {
      [matrix addRow];
      bc = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];
      [bc setTitle:[d outputName]];
      [bc setLeaf:YES];
      [bc setRefusesFirstResponder:YES];
    }
}

- (BOOL)browser:(NSBrowser *)sender
      selectRow:(NSInteger)row
       inColumn:(NSInteger)column
{
  // Update preferences
  // NSLog(@"Display.preferences: selected monitor with title: %@",
  //       [[[sender matrixInColumn:column] cellAtRow:row column:0] title]);
  return YES;
}

@end
