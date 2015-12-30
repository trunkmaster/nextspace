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
#import <AppKit/NSBrowser.h>
#import <AppKit/NSBrowserCell.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSSlider.h>

#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>

#import <dispatch/dispatch.h>
#import <X11/Xlib.h>

#import "Display.h"

@implementation DisplayPrefs

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;
static NXDisplay		*selectedDisplay = nil;

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Monitor" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  XInitThreads();
      
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

  [monitorsList loadColumnZero];
  {
    NSArray *cells = [[monitorsList matrixInColumn:0] cells];
    int i;
    for (i = 0; i < [cells count]; i++)
      {
        if ([[cells objectAtIndex:i] isEnabled] == YES)
          {
            [monitorsList selectRow:i inColumn:0];
            break;
          }
      }
  }
  [self monitorsListClicked:monitorsList];
  
  [rotationBtn setEnabled:NO];
  [reflectionBtn setEnabled:NO];

  { // Window background
    
  }
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Display" owner:self])
        {
          NSLog (@"Display.preferences: Could not load NIB, aborting.");
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
// Helper methods
//
- (void)fillRateButton
{
  NSString     *resBtnTitle = [resolutionBtn titleOfSelectedItem];
  NSArray      *m = [selectedDisplay allResolutions];
  NSString     *rateString;
  NSDictionary *res;
  NSString     *resTitle;
  NSSize       size;

  [rateBtn removeAllItems];
  for (NSInteger i = 0; i < [m count]; i++)
    {
      res = [m objectAtIndex:i];
      size = NSSizeFromString([res objectForKey:@"Size"]);
      resTitle = [NSString stringWithFormat:@"%.0fx%.0f",
                           size.width, size.height];
      if ([resTitle isEqualToString:resBtnTitle])
        {
          rateString = [NSString stringWithFormat:@"%.1f Hz",
                               [[res objectForKey:@"Rate"] floatValue]];
          [rateBtn addItemWithTitle:rateString];
          [[rateBtn itemWithTitle:rateString] setRepresentedObject:res];
        }
    }

  [rateBtn setEnabled:([[rateBtn itemArray] count] == 1) ? NO : YES];
}

- (void)setResolution
{
  // Set resolution only to active display.
  // Display activating implemented in 'Screen' Preferences' module.
  if ([selectedDisplay isActive])
    {
      [[NXScreen sharedScreen]
        setDisplay:selectedDisplay
        resolution:[[rateBtn selectedCell] representedObject]
            origin:[selectedDisplay frame].origin];
      
      [[NSNotificationCenter defaultCenter]
        postNotificationName:DisplayPreferencesDidChangeNotification
                      object:self];
    }  
}

//
// Action methods
//
- (IBAction)monitorsListClicked:(id)sender
{
  NSArray      *m;
  NSSize       size;
  NSString     *resolution;
  NSDictionary *r;

  selectedDisplay = [[sender selectedCell] representedObject];
  m = [selectedDisplay allResolutions];
  // NSLog(@"Display.preferences: selected monitor with title: %@", mName);

  // Resolution
  [resolutionBtn removeAllItems];
  for (NSDictionary *res in m)
    {
      size = NSSizeFromString([res objectForKey:@"Size"]);
      resolution = [NSString stringWithFormat:@"%.0fx%.0f",
                             size.width, size.height];
      [resolutionBtn addItemWithTitle:resolution];
    }
  r = [selectedDisplay resolution];
  size = NSSizeFromString([r objectForKey:@"Size"]);
  resolution = [NSString stringWithFormat:@"%.0fx%.0f",
                         size.width, size.height];
  [resolutionBtn selectItemWithTitle:resolution];
  // Rate button filled here. Items tagged with resolution description
  // object in [NSDisplay allModes] array
  [self fillRateButton];

  // Contrast
  NSString *gammaString = [NSString stringWithFormat:@"%.2f",
                                    [selectedDisplay gamma]];
  [gammaSlider setFloatValue:[gammaString floatValue]];
  [gammaField setStringValue:gammaString];

  // Brightness
  CGFloat brightness = [selectedDisplay gammaBrightness];
  [brightnessSlider setFloatValue:brightness * 100];
  [brightnessField
    setStringValue:[NSString stringWithFormat:@"%.0f", brightness * 100]];
}

- (IBAction)resolutionClicked:(id)sender
{
  [self fillRateButton];
  [self setResolution];
  
  NSLog(@"resolutionClicked: Selected resolution: %@",
        [[rateBtn selectedCell] representedObject]);
}

- (IBAction)rateClicked:(id)sender
{
  [self setResolution];

  NSLog(@"rateClicked: Selected resolution: %@",
        [[rateBtn selectedCell] representedObject]);
}

- (IBAction)sliderMoved:(id)sender
{
  CGFloat value = [sender floatValue];
  
  if (sender == gammaSlider)
    {
      // NSLog(@"Gamma slider moved");
      [gammaField setStringValue:[NSString stringWithFormat:@"%.2f", value]];
      
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                     ^{
                       [selectedDisplay
                         setGamma:value
                         brightness:[brightnessSlider floatValue]/100];
                     });
    }
  else if (sender == brightnessSlider)
    {
      // NSLog(@"Brightness slider moved");
      [brightnessField setIntValue:[sender intValue]];
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                     ^{
                       [selectedDisplay setGamma:[gammaSlider floatValue]
                                      brightness:value/100];
                     });
    }
  else
    NSLog(@"Unknown slider moved");  
}

- (IBAction)backgroundChanged:(id)sender
{
  NSLog(@"Display: backgroundChanged");
  [[NXScreen sharedScreen] setBackgroundColor:[colorBtn color]];
}

//
// Browser (list of monitors) delegate methods
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
  NSBrowserCell *bc;

  if (column > 0)
    return;

  for (NXDisplay *d in [[NXScreen sharedScreen] connectedDisplays])
    {
      [matrix addRow];
      bc = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];
      [bc setTitle:[d outputName]];
      [bc setRepresentedObject:d];
      [bc setLeaf:YES];
      [bc setRefusesFirstResponder:YES];
      [bc setEnabled:[d isActive]];
    }
}

//
// TextField Delegate methods
//
// - (BOOL)textShouldEndEditing:(NSText *)textObject
// {
//   NSString *text = [textObject text];

  
// }

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  id      tf = [aNotification object];
  CGFloat value = [tf floatValue];

  if (tf == gammaField)
    {
      [gammaSlider setFloatValue:value];
      [selectedDisplay setGamma:value];
    }
  else if (tf == brightnessField)
    {
      [brightnessSlider setFloatValue:value];
      [selectedDisplay setGammaBrightness:value/100];
    }
}
  
@end
