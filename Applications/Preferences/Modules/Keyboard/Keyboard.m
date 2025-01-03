/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

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

#import <SystemKit/OSEDefaults.h>
#import <SystemKit/OSEKeyboard.h>

#import "Keyboard.h"

@implementation Keyboard

static NSBundle    *bundle = nil;
static OSEDefaults *defaults = nil;

- (id)init
{
  self = [super init];
  
  defaults = [OSEDefaults globalUserDefaults];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Keyboard" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  keyboard = [[OSEKeyboard alloc] init];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"KeyboardPrefs -dealloc");
  
  [image release];
  [keyboard release];
  if (view) {
    [view release];
    [repeatBox release];
    [shortcutsBox release];
    [keypadBox release];
    [modifiersBox release];
  }

  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [sectionsBtn setRefusesFirstResponder:YES];

  // Model
  [modelBox retain];
  [modelBox removeFromSuperview];
  [modelDescription setStringValue:@""];

  // Key Repeat
  [repeatBox retain];
  [repeatBox removeFromSuperview];
  for (id c in [initialRepeatMtrx cells])
    [c setRefusesFirstResponder:YES];
  for (id c in [repeatRateMtrx cells])
    [c setRefusesFirstResponder:YES];

  if (![initialRepeatMtrx selectCellWithTag:[keyboard initialRepeat]])
    {
      if ([defaults integerForKey:OSEKeyboardInitialRepeat] < 0)
        [initialRepeatMtrx selectCellWithTag:200];
      else
        [initialRepeatMtrx
            selectCellWithTag:[defaults integerForKey:OSEKeyboardInitialRepeat]];
      [self repeatAction:initialRepeatMtrx];
    }
    
  if (![repeatRateMtrx selectCellWithTag:[keyboard repeatRate]])
    {
      if ([defaults integerForKey:OSEKeyboardRepeatRate] < 0)
        [repeatRateMtrx selectCellWithTag:40];
      else
        [repeatRateMtrx
          selectCellWithTag:[defaults integerForKey:OSEKeyboardRepeatRate]];
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

  // Numeric Keypad
  [keypadBox retain];
  for (id c in [deleteKeyMtrx cells])
    [c setRefusesFirstResponder:YES];
  for (id c in [numpadMtrx cells])
    [c setRefusesFirstResponder:YES];
  for (id c in [numLockStateMtrx cells])
    [c setRefusesFirstResponder:YES];

  // Modifiers
  [modifiersBox retain];
  [composeKeyBtn setRefusesFirstResponder:YES];
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
    case 0: // Model
      [sectionBox setContentView:modelBox];
      [self initModel];
      break;
    case 1: // Key Repeat
      [sectionBox setContentView:repeatBox];
      break;
    case 2: // Layouts
      [sectionBox setContentView:layoutsBox];
      [self updateLayouts];
      if (!options)
        options = [[keyboard options] copy];
      [self initSwitchLayoutShortcuts];
      break;
    case 3: // Shortcuts
      [sectionBox setContentView:shortcutsBox];
      break;
    case 4: // Numeric Keypad
      if (!options)
        options = [[keyboard options] copy];
      [self initNumpad];
      [sectionBox setContentView:keypadBox];
      break;
    case 5: // Compose, Caps Lock, Command/Alternate swap
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

//
// Options utility methods
// 
- (NSString *)_optionWithType:(NSString *)type
{
  NSString *optType;
  NSString *opt = nil;
  
  for (NSString *o in options)
    {
      optType = [[o componentsSeparatedByString:@":"] objectAtIndex:0];
      if ([optType isEqualToString:type])
        {
          opt = [o copy];
          break;
        }
    }

  return opt;
}

- (BOOL)_setOption:(NSString *)option
{
  OSEDefaults		*defs = [OSEDefaults globalUserDefaults];
  NSMutableArray	*mOptions = [options mutableCopy];
  NSArray		*optComponents;
  NSString		*savedOption;
  BOOL			SUCCESS = NO;

  optComponents = [option componentsSeparatedByString:@":"];
  savedOption = [self _optionWithType:optComponents[0]];
  
  if ([[optComponents lastObject] isEqualToString:@""] == NO)
    {
      if (savedOption)
        [mOptions replaceObjectAtIndex:[mOptions indexOfObject:savedOption]
                            withObject:option];
      else
        [mOptions addObject:option];
    }
  else if (savedOption)
    {
      [mOptions removeObject:savedOption];
    }

 SUCCESS = [keyboard setLayouts:nil variants:nil options:mOptions];
  if (SUCCESS == YES)
    {
      [defs setObject:mOptions forKey:OSEKeyboardOptions];
      [options release];
      options = [[keyboard options] copy];
    }
  
  [mOptions release];

  return SUCCESS;
}

@end

@implementation Keyboard (KeyRepeat)

- (void)repeatAction:(id)sender
{
  OSEDefaults	*defs = [OSEDefaults globalUserDefaults];
  
  if (sender == initialRepeatMtrx)
    { // NXKeyboard-InitialKeyRepeat - delay in milliseconds before repeat
      [defs setInteger:[[sender selectedCell] tag] forKey:OSEKeyboardInitialRepeat];
      [keyboard setInitialRepeat:[defs integerForKey:OSEKeyboardInitialRepeat]];
    }
  else if (sender == repeatRateMtrx)
    { // NXKeyboard - RepeatRate - num of repeates per second
      [defs setInteger:[[sender selectedCell] tag] forKey:OSEKeyboardRepeatRate];
      [keyboard setRepeatRate:[defs integerForKey:OSEKeyboardRepeatRate]];
    }

  [[sender window] makeFirstResponder:repeatTestField];
}

@end

@implementation Keyboard (Layouts)

- (void)updateLayouts
{
  OSEDefaults *defs = [OSEDefaults globalUserDefaults];

  if (layouts) {
    [layouts release];
  }
  layouts = [[keyboard layouts] copy];

  if (variants) {
    [variants release];
  }
  variants = [[keyboard variants] copy];

  [defs setObject:layouts forKey:OSEKeyboardLayouts];
  [defs setObject:variants forKey:OSEKeyboardVariants];

  [layoutList reloadData];
}

// "Add.." button action
- (void)showAddLayoutPanel:sender
{
  if (!layoutAddPanel)
    {
      layoutAddPanel = [[AddLayoutPanel alloc]
                         initWithKeyboard:[OSEKeyboard new]];
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

- (void)initSwitchLayoutShortcuts
{
  NSString	*lSwitchFile;
  id 		value;
  id		item;
  NSString	*shortcut = nil;
    
  lSwitchFile = [bundle pathForResource:@"LayoutSwitchKeys" ofType:@"plist"];
  layoutSwitchKeys = [[NSDictionary alloc] initWithContentsOfFile:lSwitchFile];
  
  [layoutShortcutBtn setAutoenablesItems:NO];
  [layoutShortcutBtn removeAllItems];
  [layoutShortcutBtn addItemWithTitle:@"None"];
  [[layoutShortcutBtn itemWithTitle:@"None"] setRepresentedObject:@""];

  for (NSString *k in [layoutSwitchKeys allKeys])
    {
      [layoutShortcutBtn addItemWithTitle:k];
      item = [layoutShortcutBtn itemWithTitle:k];
      
      value = [layoutSwitchKeys objectForKey:k];
      [item setRepresentedObject:value];
      
      if (([value isKindOfClass:[NSDictionary class]] &&
           [options containsObject:[value objectForKey:@"Option"]])
          || [options containsObject:value])
        shortcut = [k copy];
    }
  [layoutSwitchKeys release];
  [self updateSwitchLayoutShortcuts];
  
  if (shortcut)
    {
      [layoutShortcutBtn selectItemWithTitle:shortcut];
      [shortcut release];
    }
  else
    [layoutShortcutBtn selectItemWithTitle:@"None"];

  // Refresh defaults with actual X11 settings
  [[OSEDefaults globalUserDefaults] setObject:options forKey:OSEKeyboardOptions];
}

- (void)updateSwitchLayoutShortcuts
{
  id	repObject;

  for (NSMenuItem *item in [layoutShortcutBtn itemArray])
    {
      [item setEnabled:YES];
      repObject = [item representedObject];
      if ([repObject isKindOfClass:[NSDictionary class]])
        {
          for (NSString *o in [repObject objectForKey:@"ConflictsWithOptions"])
            {
              if ([options containsObject:o])
                [item setEnabled:NO]; 
            }
        }
    }
}

// Replaces "NXKeyboardOptions" array item that contains "grp:" substring.
- (void)setLayoutShortcut:(id)sender
{
  OSEDefaults		*defs = [OSEDefaults globalUserDefaults];
  NSMutableArray	*mOptions = [options mutableCopy];
  id			selectedOption;
  BOOL			isOptionReplaced = NO;

  selectedOption = [[layoutShortcutBtn selectedItem] representedObject];
  if ([selectedOption isKindOfClass:[NSDictionary class]])
    selectedOption = [selectedOption objectForKey:@"Option"];
  
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
      [defs setObject:mOptions forKey:OSEKeyboardOptions];
      [options release];
      options = [[keyboard options] copy];
    }
  
  [mOptions release];
}

@end

@implementation Keyboard (NumPad)

- (void)initNumpad
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
    {
      [numpadMtrx selectCellWithTag:2];  // Always enter digits
      [numLockStateMtrx setEnabled:NO];
    }
  else if ([options containsObject:@"numpad:microsoft"])
    {
      [numpadMtrx selectCellWithTag:1];  // Default+
    }
  else
    {
      [numpadMtrx selectCellWithTag:0]; // Default "numpad:pc"
      if ([options containsObject:@"numpad:pc"] == NO)
        {
          [self _setOption:@"numpad:pc"];
        }
    }

  NSInteger numLockState;
  
  numLockState = [[OSEDefaults globalUserDefaults] integerForKey:OSEKeyboardNumLockState];
  [numLockStateMtrx selectCellWithTag:numLockState];
  if ([[numpadMtrx selectedCell] tag] != 2 )
    [keyboard setNumLockState:numLockState];
  else
    [keyboard setNumLockState:0];
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
  [numLockStateMtrx setEnabled:YES];
  switch([[sender selectedCell] tag])
    {
    case 0:
      [self _setOption:@"numpad:pc"];
      [keyboard setNumLockState:[[numLockStateMtrx selectedCell] tag]];
      break;
    case 1:
      [self _setOption:@"numpad:microsoft"];
      [keyboard setNumLockState:[[numLockStateMtrx selectedCell] tag]];
      break;
    case 2:
      [self _setOption:@"numpad:mac"];
      [numLockStateMtrx setEnabled:NO];
      [keyboard setNumLockState:0];
      break;
    }
}

- (void)numLockMtrxClicked:(id)sender
{
  [[OSEDefaults globalUserDefaults] setInteger:[[sender selectedCell] tag]
                                       forKey:OSEKeyboardNumLockState];
  [keyboard setNumLockState:[[sender selectedCell] tag]];
}

@end

@implementation Keyboard (Modifiers)

- (void)initModifiers
{
  NSString     *aFile;
  NSDictionary *aDict;
  id 		value;
  id		item;
  NSString	*opt;

  // Compose Character Key
  aFile = [bundle pathForResource:@"ComposeCharacterKey" ofType:@"plist"];
  aDict = [[NSDictionary alloc] initWithContentsOfFile:aFile];
  
  [composeKeyBtn removeAllItems];
  [composeKeyBtn addItemWithTitle:@"None"];
  [[composeKeyBtn itemWithTitle:@"None"] setRepresentedObject:@"compose:"];
  for (NSString *k in [aDict allKeys])
    {
      [composeKeyBtn addItemWithTitle:k];
      item = [composeKeyBtn itemWithTitle:k];
      value = [aDict objectForKey:k];
      [item setRepresentedObject:value];
    }
  [aDict release];

  opt = [self _optionWithType:@"compose"];
  if (opt)
    {
      [composeKeyBtn
        selectItemWithTitle:[[aDict allKeysForObject:opt] lastObject]];
    }
  else
    {
      [composeKeyBtn selectItemWithTitle:@"None"];
    }
  [opt release];
  
  // Command and Alternate Swap
  opt = [self _optionWithType:@"altwin"];
  if ([opt isEqualToString:@"altwin:swap_lalt_lwin"])
    [swapCAMtrx selectCellWithTag:1]; // At the left side of keyboard
  else if ([opt isEqualToString:@"altwin:swap_alt_win"])
    [swapCAMtrx selectCellWithTag:2]; // At both sides
  else
    [swapCAMtrx selectCellWithTag:0]; // No swap
  [opt release];
  
  // Caps Lock Key
  aFile = [bundle pathForResource:@"CapsLockKey" ofType:@"plist"];
  aDict = [[NSDictionary alloc] initWithContentsOfFile:aFile];
  
  [capsLockBtn removeAllItems];
  for (NSString *k in [aDict allKeys])
    {
      [capsLockBtn addItemWithTitle:k];
      item = [capsLockBtn itemWithTitle:k];
      value = [aDict objectForKey:k];
      [item setRepresentedObject:value];
    }
  [aDict release];
  
  opt = [self _optionWithType:@"caps"];
  if (opt == nil)
    {
      [capsLockMtrx selectCellWithTag:0];
      [capsLockBtn selectItemWithTitle:@"Caps Lock"];
    }
  else if ([opt isEqualToString:@"caps:none"])
    {
      [capsLockMtrx selectCellWithTag:1];
      [capsLockBtn setEnabled:NO];
    }
  else
    {
      [capsLockMtrx selectCellWithTag:0];
      [capsLockBtn
        selectItemWithTitle:[[aDict allKeysForObject:opt] lastObject]];
    }
  [opt release];
}
- (void)composeBtnClicked:(id)sender
{
  [self _setOption:[[sender selectedItem] representedObject]];
}
- (void)swapCAMtrxClicked:(id)sender
{
  switch([[sender selectedCell] tag])
    {
    case 0:
      [self _setOption:@"altwin:"];
      break;
    case 1:
      [self _setOption:@"altwin:swap_lalt_lwin"];
      break;
    case 2:
      [self _setOption:@"altwin:swap_alt_win"];
      break;
    }
}
- (void)capsLockBtnClicked:(id)sender
{
  [self _setOption:[[sender selectedItem] representedObject]];
}
- (void)capsLockMtrxClicked:(id)sender
{
  switch([[sender selectedCell] tag])
    {
    case 0:
      [capsLockBtn setEnabled:YES];
      [self _setOption:[[capsLockBtn selectedItem] representedObject]];
      break;
    case 1:
      [capsLockBtn setEnabled:NO];
      [self _setOption:@"caps:none"];
      break;
    }
}

@end

@implementation Keyboard (Model)

- (NSDictionary *)_modelsList
{
  NSString     *filePath = nil;
  NSDictionary *fileContents = nil;

  filePath = [bundle pathForResource:@"Model" ofType:@"plist"];
  if (filePath) {
    fileContents = [[NSDictionary alloc] initWithContentsOfFile:filePath];
  }
  else {
    NSLog(@"Keyboard ERROR: Model.plist file resource was not found!");
  }

  return [fileContents autorelease];
}

- (void)initModel
{
  NSDictionary *modelsList = nil;
  NSString     *theModel = nil;
  NSString     *theVendor = nil;
  NSString     *currentModel = nil;
  NSString     *modelType = nil;
  
  if ([[[modelBrowser matrixInColumn:0] cells] count] == 0) {
    [modelBrowser loadColumnZero];
  }
  
  modelsList = [self _modelsList];
  if (modelsList == nil) {
    return;
  }

  currentModel = [keyboard model];
  NSLog(@"Current keyboard model is: %@", currentModel);

  for (NSString *vendor in modelsList) {
    for (NSString *model in modelsList[vendor]) {
      modelType = [modelsList[vendor][model] allKeys][0];
      if ([modelType isEqualToString:currentModel]) {
        theModel = [NSString stringWithString:model];
        [modelDescription setStringValue:modelsList[vendor][model][modelType]];
        break;
      }
    }
    if (theModel) {
      theVendor = [NSString stringWithString:vendor];
      break;
    }
  }
  NSLog(@"Model browser: vendor: %@ model:%@", theVendor, theModel);
  
  [modelBrowser setPath:[NSString stringWithFormat:@"/%@/%@", theVendor, theModel]];
}

- (NSString *)browser:(NSBrowser *)sender
        titleOfColumn:(NSInteger)column
{
  if (column == 0) {
    return @"Vendor";
  }

  return [[sender pathToColumn:column] lastPathComponent];
}

- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSDictionary  *modelsList = nil;
  NSArray       *items = nil;
  NSBrowserCell *cell = nil;
  
  if (sender != modelBrowser) {
    return;
  }
  
  modelsList = [self _modelsList];
  
  if (column == 0) {
    items = [[modelsList allKeys] sortedArrayUsingSelector:@selector(compare:)];
  }
  else {
    NSString     *vendor = [[sender path] lastPathComponent];
    NSDictionary *models = [modelsList objectForKey:vendor];
    items = [[models allKeys] sortedArrayUsingSelector:@selector(compare:)];
  }

  for (NSString *entry in items) {
    [matrix addRow];
    cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:0];
    [cell setLeaf:(column == 0) ? NO : YES];
    [cell setTitle:entry];
    [cell setRefusesFirstResponder:YES];
  }
}

- (void)modelBrowserClicked:(id)sender
{
  NSDictionary  *modelsList = nil;
  NSDictionary  *vendor = nil, *model = nil;
  NSString      *modelKey = nil;
  NSArray       *pathArray = nil;
  
  if (sender != modelBrowser) {
    return;
  }
  
  modelsList = [self _modelsList];
  
  pathArray = [[sender path] pathComponents];
  vendor = modelsList[pathArray[1]];
  model = vendor[pathArray[2]];
  modelKey = [model allKeys][0];
  // NSLog(@"Model Browser clicked! %@ - %@ - %@ (%@)",
  //       pathArray[1], pathArray[2], modelKey, model[modelKey]);
  if (modelKey) {
    // Display description
    [modelDescription setStringValue:model[modelKey]];
    // Save setting to NXGlobalDomain
    [keyboard setModel:modelKey];
    [[OSEDefaults globalUserDefaults] setObject:modelKey
                                         forKey:OSEKeyboardModel];
  }
  else {
    [modelDescription setStringValue:@""];
  }
}

- (BOOL)browser:(NSBrowser *)sender
      selectRow:(NSInteger)row
       inColumn:(NSInteger)column
{
  NSLog(@"Selected item: %@",
        [[[sender matrixInColumn:column] selectedCell] title]);
  return YES;
}

@end
