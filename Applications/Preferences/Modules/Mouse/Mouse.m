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
#import <AppKit/NSAffineTransform.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSPopUpButton.h>

#import <NXSystem/NXMouse.h>
#import <NXAppKit/NXNumericField.h>

#import "Mouse.h"

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;

@implementation Mouse

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Mouse" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  mouse = [NXMouse new];

  return self;
}

- (void)dealloc
{
  NSLog(@"Mouse -dealloc");
  [image release];
  [handImage release];
  [mouse release];
  
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

  // NSLog(@"[Mouse] current acceleration = %li times, threshold = %li pixels",
  //       [mouse acceleration], [mouse accelerationThreshold]);

  // Mouse speed
  [speedMtrx selectCellWithTag:[mouse acceleration]];

  // Double-Click Delay
  [doubleClickMtrx selectCellWithTag:[mouse doubleClickTime]];

  // Threshold
  [tresholdSlider setIntegerValue:[mouse accelerationThreshold]];
  [tresholdField setMinimumValue:1];
  [tresholdField setMaximumValue:7];
  [tresholdField setIntegerValue:[mouse accelerationThreshold]];

  // Mouse Wheel Scrolls
  [wheelScrollField setMinimumValue:1];
  [wheelScrollField setIntegerValue:[mouse wheelScrollLines]];
  [wheelControlScrollField setMinimumValue:1];
  [wheelControlScrollField setIntegerValue:[mouse wheelControlScrollLines]];

  // Menu Button
  for (id c in [menuMtrx cells])
    [c setRefusesFirstResponder:YES];
  handImage = [[handImageView image] copy];
  
  [menuMtrx selectCellWithTag:[mouse isMenuButtonEnabled]];
  if ([mouse menuButton] == NSLeftMouseDown)
    [self setMenuButtonHand:menuLeftBtn];
  else
    [self setMenuButtonHand:menuRightBtn];

  // Cursors
  // [cursorsBtn removeAllItems];
  // [cursorsBtn addItemsWithTitles:[mouse availableCursorThemes]];
  // NSLog(@"Current cursor theme name: %@", [mouse cursorTheme]);
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
  [mouse setAcceleration:[[sender selectedCell] tag] threshold:0];
  [mouse saveToDefaults];
}
- (void)doubleClickMtrxClicked:(id)sender
{
  [mouse setDoubleClickTime:[[doubleClickMtrx selectedCell] tag]];
  [mouse saveToDefaults];
}
- (void)setTreshold:(id)sender
{
  if (sender == tresholdSlider)
    {
      [tresholdField setIntValue:[tresholdSlider integerValue]];
    }
  else if (sender == tresholdField)
    {
      [tresholdSlider setIntValue:[tresholdField integerValue]];
      [tresholdField setIntValue:[tresholdSlider integerValue]];
    }
  
  [mouse setAcceleration:0 threshold:[tresholdField integerValue]];
  [mouse saveToDefaults];
}
- (void)setWheelScroll:(id)sender
{
  [mouse setWheelScrollLines:[wheelScrollField integerValue]];
  [mouse setWheelControlScrollLines:[wheelControlScrollField integerValue]];
  [mouse saveToDefaults];
}

- (NSImage *)_flipImage:(NSImage *)sourceImage
{
  NSBitmapImageRep  *rep;
  NSImage           *img;
  NSAffineTransform *transform = [NSAffineTransform transform];

  rep = [NSBitmapImageRep
          imageRepWithData:[sourceImage TIFFRepresentation]];
  img = [[NSImage alloc]
          initWithSize:NSMakeSize(rep.pixelsWide, rep.pixelsHigh)];
  
  [img lockFocus];
  [transform translateXBy:rep.pixelsWide yBy:0];
  [transform scaleXBy:-1 yBy:1];
  [transform concat];
  [rep drawInRect:NSMakeRect(0, 0, rep.pixelsWide, rep.pixelsHigh)];
  [img unlockFocus];

  return [img autorelease];
}
- (void)setMenuButtonHand:(id)sender
{
  NSEventType button;
  NSLog(@"Button sender state %li", [sender state]);
  if (sender == menuRightBtn && [sender state] == NSOnState)
    {
      [handImageView setImage:handImage];
    }
  if (sender == menuLeftBtn && [sender state] == NSOnState)
    {
      [handImageView setImage:[self _flipImage:[handImageView image]]];
    }
  [sender setState:NSOnState];
  [(sender == menuLeftBtn) ? menuRightBtn : menuLeftBtn setState:NSOffState];

  button = (sender == menuLeftBtn) ? NSLeftMouseDown : NSRightMouseDown;
  [mouse setMenuButtonEnabled:YES menuButton:button];
  [mouse saveToDefaults];
}
- (void)setMenuButtonEnabled:(id)sender
{
  NSInteger  state = [[sender selectedCell] tag];
  NSUInteger button;
  BOOL       isEnabled;

  [handImageView setEnabled:state];
  [menuRightBtn setEnabled:state];
  [menuLeftBtn setEnabled:state];

  button = [menuLeftBtn state] ? NSLeftMouseDown : NSRightMouseDown;
  isEnabled = [[sender selectedCell] tag] ? YES : NO;
  
  [mouse setMenuButtonEnabled:isEnabled menuButton:button];  
  [mouse saveToDefaults];
}

- (void)setCursorTheme:(id)sender
{
  // [mouse setCursorTheme:[cursorsBtn titleOfSelectedItem]];
  // NSLog(@"Current cursor theme name: %@", [mouse cursorTheme]);
}

@end
