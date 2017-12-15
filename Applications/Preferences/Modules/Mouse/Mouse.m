/*
  Mouse.m

  Controller class for Mouse preferences bundle

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		2015

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
#import <AppKit/NSScrollView.h>
#import <AppKit/NSScroller.h>

#import <NXSystem/NXMouse.h>

#import "Mouse.h"

@implementation Mouse

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Mouse" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"Mouse -dealloc");
  [image release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  for (id c in [speedMtrx cells])
    [c setRefusesFirstResponder:YES];
  for (id c in [doubleClickMtrx cells])
    [c setRefusesFirstResponder:YES];

  NXMouse *mouse = [NXMouse new];

  NSLog(@"[Mouse] current acceleration = %li times, threshold = %li pixels",
        [mouse acceleration], [mouse accelerationThreshold]);
  [speedMtrx selectCellWithTag:[mouse acceleration]];
  [mouse release];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Mouse" owner:self])
        {
          NSLog (@"Mouse.preferences: Could not load NIB, aborting.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Mouse Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (void)speedMtrxClicked:(id)sender
{
  NXDefaults	*defs = [NXDefaults globalUserDefaults];
  NXMouse	*mouse = [NXMouse new];
  NSUInteger	tag = [[sender selectedCell] tag];
  
  [mouse setAcceleration:tag threshold:tag];
  [mouse release];

  [defs setInteger:tag forKey:Acceleration];
  [defs setInteger:tag forKey:Threshold];
}
- (void)doubleClickMtrxClicked:(id)sender
{
  // GNUstep:
  // 1. Write to the NSGlobalDomain -> GSDoubleClickTime
  [[NSUserDefaults standardUserDefaults]
    setInteger:[[doubleClickMtrx selectedCell] tag]
        forKey:@"GSDoubleClickTime"];
  // 2. Set new value to GNUstep backend
  // WindowMaker:
  // Write to ~/L/P/.WindowMaker/WindowMaker -> DoubleClickTime
}

- (void)setWheelScroll:(id)sender
{
  if (sender == wheelScrollSlider)
    {
    }
  else if (sender == wheelScrollField)
    {
    }
}

@end

