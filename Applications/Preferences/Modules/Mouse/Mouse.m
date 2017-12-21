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
  [tresholdField setIntegerValue:[mouse accelerationThreshold]];

  // Mouse Wheel Scrolls
  [wheelScrollSlider setIntegerValue:[mouse wheelScrollLines]];
  [wheelScrollField setIntegerValue:[mouse wheelScrollLines]];

  // Menu Button
  for (id c in [menuMtrx cells])
    [c setRefusesFirstResponder:YES];
  handImage = [[handImageView image] copy];
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
}
- (void)doubleClickMtrxClicked:(id)sender
{
  [mouse setDoubleClickTime:[[doubleClickMtrx selectedCell] tag]];
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
}
- (void)setWheelScroll:(id)sender
{
  if (sender == wheelScrollSlider)
    {
      [wheelScrollField setIntValue:[wheelScrollSlider integerValue]];
    }
  else if (sender == wheelScrollField)
    {
      [wheelScrollSlider setIntValue:[wheelScrollField integerValue]];
      [wheelScrollField setIntValue:[wheelScrollSlider integerValue]];
    }

  [mouse setWheelScrollLines:[wheelScrollField integerValue]];
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
  if (sender == menuLeftBtn)
    {
      [domain setObject:[NSNumber numberWithInteger:NSLeftMouseDown]
                 forKey:@"GSMenuButtonEvent"];
    }
  else
    {
      [domain setObject:[NSNumber numberWithInteger:NSRightMouseDown]
                 forKey:@"GSMenuButtonEvent"];
    }
  [defaults setPersistentDomain:domain forName:NSGlobalDomain];
  [defaults synchronize];
  
  [[NSDistributedNotificationCenter defaultCenter]
               postNotificationName:@"GSMouseOptionsDidChangeNotification"
                             object:nil];
}
- (void)setMenuButtonEnabled:(id)sender
{
  NSInteger state = [[sender selectedCell] tag];
  NSNumber  *menuButton;

  [handImageView setEnabled:state];
  [menuRightBtn setEnabled:state];
  [menuLeftBtn setEnabled:state];

  if ([menuLeftBtn state] == NSOnState)
    value = [NSNumber numberWithInteger:NSLeftMouseDown];
  else
    value = [NSNumber numberWithInteger:NSRightMouseDown];
  
  // NSGlobalDomain
  if (state == NSOffState)
    {
      [mouse setMenuButtonEnabled:NO];
    }
  else
    {
      
      [mouse setMenuButtonEnabled:YES menuButton:value];
    }
  if (state == NSOffState)
    {
      [domain setObject:[NSNumber numberWithBool:NO]
                 forKey:@"GSMenuButtonEnabled"];
    }
  else
    {
      NSNumber *value;
      if ([menuLeftBtn state] == NSOnState)
        value = [NSNumber numberWithInteger:NSLeftMouseDown];
      else
        value = [NSNumber numberWithInteger:NSRightMouseDown];
      [domain setObject:value forKey:@"GSMenuButtonEvent"];
      [domain setObject:[NSNumber numberWithBool:YES]
                 forKey:@"GSMenuButtonEnabled"];

    }
  [defaults setPersistentDomain:domain forName:NSGlobalDomain];
  [defaults synchronize];
  
  [[NSDistributedNotificationCenter defaultCenter]
               postNotificationName:@"GSMouseOptionsDidChangeNotification"
                             object:nil];

  // Set WindowMaker preferences. WindowMaker updates it automatically.
  NSString *wmdFormat = @"%@/Library/Preferences/.WindowMaker/WindowMaker";
  NSString *wmdPath;
  NSMutableDictionary *wmDefaults;

  wmdPath = [NSString stringWithFormat:wmdFormat, NSHomeDirectory()];
  wmDefaults = [NSMutableDictionary dictionaryWithContentsOfFile:wmdPath];
  if (state == NSOnState)
    {
      [wmDefaults setObject:@"NO" forKey:@"DisableWSMouseActions"];
    }
  else
    {
      [wmDefaults setObject:@"YES" forKey:@"DisableWSMouseActions"];
    }
  [wmDefaults writeToFile:wmdPath atomically:YES];
}

@end
