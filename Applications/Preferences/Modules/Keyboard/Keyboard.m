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

  keyboard = [[NXKeyboard alloc] init];
      
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
    
  [view retain];
  [window release];

  // for (id c in [sectionsMtrx cells])
  //   [c setRefusesFirstResponder:YES];
  [sectionsBtn setRefusesFirstResponder:YES];

  // Key Repeat
  [repeatBox retain];
  [repeatBox removeFromSuperview];
  for (id c in [initialRepeatMtrx cells])
    [c setRefusesFirstResponder:YES];
  for (id c in [repeatRateMtrx cells])
    [c setRefusesFirstResponder:YES];

  if (![initialRepeatMtrx selectCellWithTag:[keyboard initialRepeat]])
    {
      if ([defs integerForKey:InitialRepeat] < 0)
        [initialRepeatMtrx selectCellWithTag:200];
      else
        [initialRepeatMtrx
            selectCellWithTag:[defs integerForKey:InitialRepeat]];
      [self repeatAction:initialRepeatMtrx];
    }
    
  if (![repeatRateMtrx selectCellWithTag:[keyboard repeatRate]])
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
  // [layoutList setHeaderView:nil];
  [layoutList setDelegate:self];
  [layoutList setDataSource:self];
  [layoutList deselectAll:self];
  [layoutList setTarget:self];
  [layoutList setAction:@selector(layoutClicked:)];
  [layoutShortcutBtn setRefusesFirstResponder:YES];

  // Shortcuts
  [shortcutsBox retain];
  [shortcutsBox removeFromSuperview];
  [shortcutsBrowser loadColumnZero];
  [shortcutsBrowser setTitle:@"Group" ofColumn:0];
  [shortcutsBrowser setTitle:@"Action" ofColumn:1];
  // [shortcutsBrowser setTitle:@"Shortcut" ofColumn:2];

  // Numeric Keypad
  [keypadBox retain];
  for (id c in [deleteKeyMtrx cells])
    [c setRefusesFirstResponder:YES];
  for (id c in [numpadMtrx cells])
    [c setRefusesFirstResponder:YES];

  // Modifiers
  [modifiersBox retain];
  [composeBtn setRefusesFirstResponder:YES];
  for (id c in [swapCAMtrx cells])
    [c setRefusesFirstResponder:YES];
  [capsLockBtn setRefusesFirstResponder:YES];
  for (id c in [capsLockMtrx cells])
    [c setRefusesFirstResponder:YES];
  
  [self sectionButtonClicked:sectionsBtn];
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
  switch ([[sender selectedItem] tag])
    {
    case 0: // Key Repeat
      [sectionBox setContentView:repeatBox];
      break;
    case 1: // Layouts
      [sectionBox setContentView:layoutsBox];
      [self updateLayouts];
      [layoutList selectRow:0 byExtendingSelection:NO];
      if (!options)
        options = [[keyboard options] copy];
      [self initSwitchLayoutShortcuts];
      break;
    case 2: // Shortcuts
      [sectionBox setContentView:shortcutsBox];
      break;
    case 3: // Numeric Keypad
      if (!options)
        options = [[keyboard options] copy];
      [self updateNumpad];
      [sectionBox setContentView:keypadBox];
      break;
    case 4: // Compose, Caps Lock, Command/Alternate swap
      if (!options)
        options = [[keyboard options] copy];
      [self initModifiers];
      [sectionBox setContentView:modifiersBox];
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
      [layoutAddBtn setEnabled:([layouts count] < 4) ? YES : NO];
      return [layouts count];
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
      NSString *title, *variant;
      
      title = [keyboard nameForLayout:[layouts objectAtIndex:row]];
      variant = [variants objectAtIndex:row];
      if (![variant isEqualToString:@""])
        {
          title = [NSString stringWithFormat:@"%@, %@",
                            title, [keyboard nameForVariant:variant]];
        }
        
      return title;
    }
  else if (tv == layoutShortcutList)
    {
    }

  return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSTableView *tv = [aNotification object];

  NSLog(@"Selection Did Change: %@", [tv className]);
  
  if (tv == layoutList)
    {
      NSInteger selRow = [tv selectedRow];
  
      [layoutRemoveBtn setEnabled:[tv numberOfRows] > 1 ? YES : NO];
      [layoutUpBtn setEnabled:(selRow == 0) ? NO : YES];
      [layoutDownBtn setEnabled:(selRow == [tv numberOfRows]-1) ? NO : YES];
    }
}

@end

@implementation Keyboard (KeyRepeat)

- (void)repeatAction:(id)sender
{
  NXDefaults	*defs = [NXDefaults globalUserDefaults];
  
  if (sender == initialRepeatMtrx)
    { // NXKeyboard-InitialKeyRepeat - delay in milliseconds before repeat
      [defs setInteger:[[sender selectedCell] tag] forKey:InitialRepeat];
      [keyboard setInitialRepeat:[defs integerForKey:InitialRepeat]];
    }
  else if (sender == repeatRateMtrx)
    { // NXKeyboard - RepeatRate - num of repeates per second
      [defs setInteger:[[sender selectedCell] tag] forKey:RepeatRate];
      [keyboard setRepeatRate:[defs integerForKey:RepeatRate]];
    }

  [defs synchronize];

  [[sender window] makeFirstResponder:repeatTestField];
}

@end

@implementation Keyboard (Layouts)

- (void)updateLayouts
{
  NXDefaults	*defs = [NXDefaults globalUserDefaults];
  
  if (layouts) [layouts release];
  layouts = [[keyboard layouts] copy];
  if (variants) [variants release];
  variants = [[keyboard variants] copy];
  
  [defs setObject:layouts forKey:Layouts];
  [defs setObject:variants forKey:Variants];
  [defs synchronize];
  
  [layoutList reloadData];
}

// "Add.." button action
- (void)showAddLayoutPanel:sender
{
  if (!layoutAddPanel)
    {
      layoutAddPanel = [[AddLayoutPanel alloc]
                         initWithKeyboard:[NXKeyboard new]];
    }
  // [NSApp runModalForWindow:[layoutAddPanel panel]] stops clock in appicon.
  [layoutAddPanel orderFront:self];
}
- (void)addLayout:(NSString *)layout variant:(NSString *)variant
{
  [keyboard addLayout:layout variant:variant];
  [self updateLayouts];
  
  [[layoutAddPanel panel] close];
  
  [layoutList selectRow:[layoutList numberOfRows]-1
              byExtendingSelection:NO];
}
- (void)layoutRemove:(id)sender
{
  NSInteger selRow = [layoutList selectedRow];
  
  [keyboard removeLayout:[layouts objectAtIndex:selRow]
                 variant:[variants objectAtIndex:selRow]];
  
  [self updateLayouts];
  [layoutList selectRow:(selRow > 0) ? selRow-1 : 0
              byExtendingSelection:NO];
}
- (void)layoutMove:(id)sender
{
  NSInteger	 selRow = [layoutList selectedRow];
  NSMutableArray *mLayouts = [layouts mutableCopy];
  NSMutableArray *mVariants = [variants mutableCopy];
  NSString	 *sl, *sv;
  
  sl = [layouts objectAtIndex:selRow];
  sv = [variants objectAtIndex:selRow];
  [mLayouts removeObjectAtIndex:selRow];
  [mVariants removeObjectAtIndex:selRow];
  
  if (sender == layoutUpBtn)
    selRow--;
  else if (sender == layoutDownBtn)
    selRow++;
  
  [mLayouts insertObject:sl atIndex:selRow];
  [mVariants insertObject:sv atIndex:selRow];
  
  [keyboard setLayouts:mLayouts variants:mVariants options:nil];
  [self updateLayouts];
    
  [layoutList selectRow:selRow byExtendingSelection:NO];
}

// Change layout shortcut
- (void)initSwitchLayoutShortcuts
{
  NSString	*lSwitchFile;
  id 		value;
  id		item;
  NSString	*shortcut = nil;
    
  lSwitchFile = [bundle pathForResource:@"LayoutSwitchKeys" ofType:@"plist"];
  layoutSwitchKeys = [[NSDictionary alloc] initWithContentsOfFile:lSwitchFile];
  
  [layoutShortcutBtn removeAllItems];
  [layoutShortcutBtn addItemWithTitle:@"None"];
  [[layoutShortcutBtn itemWithTitle:@"None"] setRepresentedObject:@""];

  for (NSString *k in [layoutSwitchKeys allKeys])
    {
      [layoutShortcutBtn addItemWithTitle:k];
      item = [layoutShortcutBtn itemWithTitle:k];
      
      value = [layoutSwitchKeys objectForKey:k];
      if ([value isKindOfClass:[NSDictionary class]])
        {
          value = [value objectForKey:@"Option"];
          [item setEnabled:NO];
        }
      [item setRepresentedObject:value];
      
      if ([options containsObject:value])
        shortcut = [k copy];
    }
  [layoutSwitchKeys release];
  if (shortcut)
    {
      [layoutShortcutBtn selectItemWithTitle:shortcut];
      [shortcut release];
    }
  else
    [layoutShortcutBtn selectItemWithTitle:@"None"];

  // Refresh defaults with actual X11 settings
  [[NXDefaults globalUserDefaults] setObject:options forKey:Options];
  [[NXDefaults globalUserDefaults] synchronize];
}

// Replaces "NXKeyboardOptions" array item that contains "grp:" substring.
- (void)setLayoutShortcut:(id)sender
{
  NXDefaults		*defs = [NXDefaults globalUserDefaults];
  NSMutableArray	*mOptions = [options mutableCopy];
  id			selectedOption;
  BOOL			isOptionReplaced = NO;

  selectedOption = [[layoutShortcutBtn selectedItem] representedObject];
  
  NSLog(@"[Keyboard] selected option: %@", selectedOption);
  
  for (NSString *opt in mOptions)
    {
      if ([opt rangeOfString:@"grp:"].location != NSNotFound)
        {
          if ([selectedOption isEqualToString:@""] == NO)
            {
              [mOptions replaceObjectAtIndex:[mOptions indexOfObject:opt]
                                  withObject:selectedOption];
            }
          else
            {
              [mOptions removeObject:opt];
            }
          isOptionReplaced = YES;
          break;
        }
    }

  if (isOptionReplaced == NO)
    {
      [mOptions addObject:selectedOption];
    }
  
  if ([keyboard setLayouts:nil variants:nil options:mOptions] == YES)
    {
      [defs setObject:mOptions forKey:Options];
      [defs synchronize];
      
      [options release];
      options = [[keyboard options] copy];
    }
  
  [mOptions release];
}

@end

@implementation Keyboard (NumPad)

- (BOOL)_setOption:(NSString *)option
{
  NSString 		*optType;
  NSMutableArray	*mOptions = [options mutableCopy];
  BOOL			SUCCESS = NO;
  NXDefaults		*defs = [NXDefaults globalUserDefaults];
  NSInteger		optIndex = -1;

  optType = [[option componentsSeparatedByString:@":"] objectAtIndex:0];
  for (NSString *opt in mOptions)
    {
      if ([opt rangeOfString:optType].location != NSNotFound)
        {
          optIndex = [mOptions indexOfObject:opt];
        }
    }
  if (optIndex >= 0)
    {
      [mOptions removeObjectAtIndex:optIndex];
    }
  [mOptions addObject:option];

  SUCCESS = [keyboard setLayouts:nil variants:nil options:mOptions];
  if (SUCCESS == YES)
    {
      [defs setObject:mOptions forKey:Options];
      [defs synchronize];
      
      [options release];
      options = [[keyboard options] copy];
    }
  
  [mOptions release];

  return SUCCESS;
}

- (NSString *)_optionWithType:(NSString *)type
{
  NSString *optType;
  NSString *opt = nil;
  
  for (NSString *o in options)
    {
      optType = [[o componentsSeparatedByString:@":"] objectAtIndex:0];
      if ([optType isEqualToString:type])
        opt = [o copy];
      break;
    }

  return opt;
}

- (void)updateNumpad
{
  if ([options containsObject:@"kpdl:comma"])
    [deleteKeyMtrx selectCellWithTag:1];
  else
    {
      [deleteKeyMtrx selectCellWithTag:0];
      if ([options containsObject:@"kpdl:dot"] == NO)
        {
          [self _setOption:@"kpdl:dot"];
        }
    }

  if ([options containsObject:@"numpad:mac"])
    [numpadMtrx selectCellWithTag:2];  // Always enter digits
  else if ([options containsObject:@"numpad:microsoft"])
    [numpadMtrx selectCellWithTag:1];  // Default+
  else
    {
      [numpadMtrx selectCellWithTag:0]; // Default "numpad:pc"
      if ([options containsObject:@"numpad:pc"] == NO)
        {
          [self _setOption:@"numpad:pc"];
        }
    }
}

- (void)deleteKeyMtrxClicked:(id)sender
{
  switch([[sender selectedCell] tag])
    {
    case 0:
      [self _setOption:@"kpdl:dot"];
      break;
    case 1:
      [self _setOption:@"kpdl:comma"];
      break;
    }
}

- (void)numpadMtrxClicked:(id)sender
{
  switch([[sender selectedCell] tag])
    {
    case 0:
      [self _setOption:@"numpad:pc"];
      break;
    case 1:
      [self _setOption:@"numpad:microsoft"];
      break;
    case 2:
      [self _setOption:@"numpad:mac"];
      break;
    }
}

@end

@implementation Keyboard (Modifiers)

- (void)initModifiers
{
  NSString     *aFile;
  NSDictionary *aDict;
  id 		value;
  id		item;
  NSString	*selected;

  // Compose Character Key
  aFile = [bundle pathForResource:@"ComposeCharacterKey" ofType:@"plist"];
  aDict = [[NSDictionary alloc] initWithContentsOfFile:aFile];
  
  [composeBtn removeAllItems];
  [composeBtn addItemWithTitle:@"None"];
  [[composeBtn itemWithTitle:@"None"] setRepresentedObject:@""];
  
  selected = nil;
  for (NSString *k in [aDict allKeys])
    {
      [composeBtn addItemWithTitle:k];
      item = [composeBtn itemWithTitle:k];
      value = [aDict objectForKey:k];
      [item setRepresentedObject:value];
      
      if ([options containsObject:value])
        selected = [k copy];
    }
  [aDict release];
  if (selected)
    {
      [composeBtn selectItemWithTitle:selected];
      [selected release];
    }
  else
    [composeBtn selectItemWithTitle:@"None"];

  // Command and Alternate Swap
  NSString *caOption = [self _optionWithType:@"altwin"];
  if (!caOption)
    [swapCAMtrx selectItemWithTag:0]; // No swap
  else if ([caOption isEqualToString:@"altwin:swap_lalt_lwin"])
    [swapCAMtrx selectItemWithTag:1]; // At the left side of keyboard
  else if ([caOption isEqualToString:@"altwin:swap_alt_win"])
    [swapCAMtrx selectItemWithTag:2]; // At both sides
    
  return;

  // Caps Lock Key
  aFile = [bundle pathForResource:@"CapsLockKey" ofType:@"plist"];
  aDict = [[NSDictionary alloc] initWithContentsOfFile:aFile];
  
  [capsLockBtn removeAllItems];

  selected = nil;
  for (NSString *k in [aDict allKeys])
    {
      [capsLockBtn addItemWithTitle:k];
      item = [capsLockBtn itemWithTitle:k];
      value = [aDict objectForKey:k];
      [item setRepresentedObject:value];
      
      if ([options containsObject:value])
        selected = [k copy];
    }
  [aDict release];
  if (selected)
    {
      [capsLockMtrx selectItemWithTag:0];
      [capsLockBtn setEnabled:NO];
      [capsLockBtn selectItemWithTitle:selected];
      [selected release];
    }
  else
    {
      [capsLockMtrx selectItemWithTag:1];
      [capsLockBtn setEnabled:NO];
    }
}

- (void)updateModifiers
{
}

- (void)composeBtnClicked:(id)sender
{
}
- (void)swapCAMtrxClicked:(id)sender
{
}
- (void)capsLockBtnClicked:(id)sender
{
}
- (void)capsLockMtrxClicked:(id)sender
{
}

@end
