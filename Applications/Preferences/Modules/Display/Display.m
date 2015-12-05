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
#import <AppKit/NSButton.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSTableColumn.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSMatrix.h>

#import "Display.h"

@implementation Display

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
  [arrangementView retain];
  [sizecolorView retain];
  [powerView retain];

  // {
  //   NSRect rect = [monitorsScroll frame];
  //   NSTableColumn *tColumn;
  //   tColumn = [monitorsTable tableColumnWithIdentifier:@"Monitors"];
  //   [tColumn setWidth:(rect.size.width-23)];
  // }
  
  [[sectionsMtrx cellWithTag:0] setRefusesFirstResponder:YES];
  [[sectionsMtrx cellWithTag:1] setRefusesFirstResponder:YES];
  [[sectionsMtrx cellWithTag:2] setRefusesFirstResponder:YES];
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
      [self sectionButtonClicked:sectionsMtrx];
    }
  
  [monitorsList setTitle:@"Monitors" ofColumn:0];
  [monitorsList loadColumnZero];
  
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
- (IBAction)sectionButtonClicked:(id)sender
{
  switch ([[sender selectedCell] tag])
    {
    case 0: // Arrangement
      [sectionBox setContentView:arrangementView];
      break;
    case 1: // Size & Colors
      [sectionBox setContentView:sizecolorView];
      break;
    case 2: // Power
      [sectionBox setContentView:powerView];
      break;
    default:
      NSLog(@"Display.preferences: Unknow section button was clicked!");
    }
}

@end

