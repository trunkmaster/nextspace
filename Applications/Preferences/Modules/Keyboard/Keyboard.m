/*
  Controller class for Keyboard preferences bundle

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

#import <Foundation/Foundation.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSWindow.h>

#import <NXFoundation/NXDefaults.h>
#import <NXSystem/NXKeyboard.h>
//#include <X11/XKBlib.h>

#import "Keyboard.h"

@implementation Keyboard

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Keyboard" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"KeyboardPrefs -dealloc");
  [image release];
  if (keyboard) [keyboard release];
  [super dealloc];
}

- (void)awakeFromNib
{
  NXDefaults *defs = [NXDefaults globalUserDefaults];
  NXKeyboard *keyb = [NXKeyboard new];
    
  [view retain];
  [window release];

  for (id c in [sectionsMtrx cells])
    [c setRefusesFirstResponder:YES];

  // Key Repeat
  [repeatBox retain];
  [repeatBox removeFromSuperview];
  for (id c in [initialRepeatMtrx cells])
    [c setRefusesFirstResponder:YES];
  for (id c in [repeatRateMtrx cells])
    [c setRefusesFirstResponder:YES];

  if (![initialRepeatMtrx selectCellWithTag:[keyb initialRepeat]])
    {
      if ([defs integerForKey:InitialRepeat] < 0)
        [initialRepeatMtrx selectCellWithTag:200];
      else
        [initialRepeatMtrx
            selectCellWithTag:[defs integerForKey:InitialRepeat]];
      [self repeatAction:initialRepeatMtrx];
    }
    
  if (![repeatRateMtrx selectCellWithTag:[keyb repeatRate]])
    {
      if ([defs integerForKey:RepeatRate] < 0)
        [repeatRateMtrx selectCellWithTag:40];
      else
        [repeatRateMtrx selectCellWithTag:[defs integerForKey:RepeatRate]];
      [self repeatAction:repeatRateMtrx];
    }
  
  // Layouts
  [layoutsBox retain];
  [layoutsBox removeFromSuperview];
  [layoutList setHeaderView:nil];
  [layoutList setDelegate:self];
  [layoutList setDataSource:self];
  [layoutList deselectAll:self];

  // Shortcuts
  [shortcutsBox retain];
  [shortcutsBox removeFromSuperview];
  [shortcutsBrowser loadColumnZero];
  [shortcutsBrowser setTitle:@"Action" ofColumn:0];
  [shortcutsBrowser setTitle:@"Shortcut" ofColumn:1];

  // Options

  [self sectionButtonClicked:sectionsMtrx];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Keyboard" owner:self])
        {
          NSLog (@"Could not load Keyboard.gorm file.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Keyboard Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (void)sectionButtonClicked:(id)sender
{
  switch ([[sender selectedCell] tag])
    {
    case 0: // Key Repeat
      [sectionBox setContentView:repeatBox];
      break;
    case 1: // Layouts
      [layoutList reloadData];
      [sectionBox setContentView:layoutsBox];
      break;
    case 2: // Shortcuts
      [sectionBox setContentView:shortcutsBox];
      break;
    default:
      NSLog(@"Keyboard.preferences: Unknow section button was clicked!");
    }
}

//
// Table delegate methods
//
- (int)numberOfRowsInTableView:(NSTableView *)tv
{
  if (tv == layoutList)
    {
      NSDictionary *layouts = [NXKeyboard currentServerConfig];
      layouts = [[NXKeyboard currentServerConfig]
                  objectForKey:@"NXKeyboardLayouts"];
      return [layouts count];
      // if (!keyboard)
      //   keyboard = [[NXKeyboard alloc] init];
      // return [[keyboard layoutList] count];
    }
  else if (tv == layoutShortcutList)
    {
    }
  return 0;
}

- (id)           tableView:(NSTableView *)tv
 objectValueForTableColumn:(NSTableColumn *)tc
                       row:(int)row
{
  if (tv == layoutList)
    {
      NSArray *layouts = [[NXKeyboard currentServerConfig]
                                objectForKey:@"NXKeyboardLayouts"];
      
      if (!keyboard)
        keyboard = [[NXKeyboard alloc] init];
      
      return [keyboard nameForLayout:[layouts objectAtIndex:row]];
      // return [[[[keyboard layoutList] allValues]
      //           sortedArrayUsingSelector:@selector(compare:)]
      //          objectAtIndex:row];
    }
  else if (tv == layoutShortcutList)
    {
    }

  return nil;
}

@end

@implementation Keyboard (KeyRepeat)

- (void)repeatAction:(id)sender
{
  NXDefaults	*defs = [NXDefaults globalUserDefaults];
  NXKeyboard	*keyb = [NXKeyboard new];
  
  if (sender == initialRepeatMtrx)
    { // NXKeyboard-InitialKeyRepeat - delay in milliseconds before repeat
      [defs setInteger:[[sender selectedCell] tag] forKey:InitialRepeat];
      [keyb setInitialRepeat:[defs integerForKey:InitialRepeat]];
    }
  else if (sender == repeatRateMtrx)
    { // NXKeyboard - RepeatRate - num of repeates per second
      [defs setInteger:[[sender selectedCell] tag] forKey:RepeatRate];
      [keyb setRepeatRate:[defs integerForKey:RepeatRate]];
    }

  [defs synchronize];

  [[sender window] makeFirstResponder:repeatTestField];
}

@end

@implementation Keyboard (Layouts)

// "Add.." button action
- (void)layoutAdd:(id)sender
{
  if (!layoutAddPanel)
    {
      layoutAddPanel = [[AddLayoutPanel alloc]
                         initWithKeyboard:[NXKeyboard new]];
    }
  [NSApp runModalForWindow:[layoutAddPanel panel]];
}
- (void)layoutRemove:(id)sender
{
}
- (void)layoutMove:(id)sender
{
  if (sender == layoutUpBtn)
    {
    }
  else if (sender == layoutDownBtn)
    {
    }
}

@end
