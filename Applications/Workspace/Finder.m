/* All Rights reserved */

#import <AppKit/AppKit.h>
#import <NXFoundation/NXDefaults.h>
#import <NXAppKit/NXAlert.h>
#import <NXAppKit/NXIconView.h>

#import <Viewers/FileViewer.h>
#import <Viewers/PathIcon.h>
#import <Preferences/Shelf/ShelfPrefs.h>

#import "Finder.h"

@interface WMFindField : NSTextField
- (void)findFieldKeyUp:(NSEvent *)theEvent;
- (void)deselectText;
@end
@implementation WMFindField
- (void)keyUp:(NSEvent *)theEvent
{
  if (_delegate && [_delegate respondsToSelector:@selector(findFieldKeyUp:)]) {
    [_delegate findFieldKeyUp:theEvent];
  }
}
- (void)findFieldKeyUp:(NSEvent *)theEvent
{
  // Should be implemented by delegate
}
- (void)deselectText
{
  NSString   *fieldString = [self stringValue];
  NSText     *fieldEditor = [_window fieldEditor:NO forObject:self];
  
  [fieldEditor setSelectedRange:NSMakeRange([fieldString length], 0)];
}
@end

@implementation Finder

- (void)dealloc
{
  NSLog(@"Finder: dealloc");

  [resultIcon release];
  [window release];
  
  [super dealloc];
}

- (id)initWithFileViewer:(FileViewer *)fv
{
  NXDefaults *df = [NXDefaults userDefaults];
  NSSize     slotSize;
    
  if ((self = [super init]) == nil) {
    return nil;
  }

  if ([df objectForKey:ShelfIconSlotWidth]) {
    slotSize = NSMakeSize([df floatForKey:ShelfIconSlotWidth], 76);
  }
  else {
    slotSize = NSMakeSize(76, 76);
  }
  [NXIcon setDefaultIconSize:NSMakeSize(66, 56)];
  [NXIconView setDefaultSlotSize:slotSize];
  [NSBundle loadNibNamed:@"Finder" owner:self];

  fileViewer = fv;
  resultIndex = -1;

  return self;
}

- (void)setFileViewer:(FileViewer *)fv
{
  fileViewer = fv;
}

- (void)awakeFromNib
{
  // Shelf
  [shelf setAllowsMultipleSelection:YES];
  [shelf setAllowsEmptySelection:NO];
  [shelf setDelegate:self];
  // [shelf setTarget:self];
  // [shelf setAction:@selector(iconClicked:)];
  // [shelf setDoubleAction:@selector(iconDoubleClicked:)];
  // [shelf setDragAction:@selector(iconDragged:event:)];
  {
    NSDictionary *aDict;
    NSArray      *shelfSelection;
    PathIcon     *icon;

    aDict = [[NXDefaults userDefaults] objectForKey:@"FinderShelfContents"];
    if (!aDict || ![aDict isKindOfClass:[NSDictionary class]]) {
      // Home
      icon = [shelf createIconForPaths:@[NSHomeDirectory()]];
      if (icon) {
        [icon setDelegate:self];
        [icon setEditable:NO];
        [icon registerForDraggedTypes:@[NSFilenamesPboardType]];
        [[icon label] setNextKeyView:findField];
        [shelf putIcon:icon intoSlot:NXMakeIconSlot(0,0)];
        [shelf selectIcons:[NSSet setWithObject:icon]];
      }
    }
    else {
      [shelf reconstructFromRepresentation:aDict];
      for (NXIcon *icon in [shelf icons]) {
        [[icon label] setNextKeyView:findField];
      }
    }

    shelfSelection = [[NXDefaults userDefaults] objectForKey:@"FinderShelfSelection"];
    [self reconstructShelfSelection:shelfSelection];
  }

  // Text field
  [findField setStringValue:@""];

  // Browser list
  [resultList loadColumnZero];
  [resultList setTakesTitleFromPreviousColumn:NO];
  [resultList scrollColumnToVisible:0];
  [resultList setRefusesFirstResponder:YES];
  [resultList setTarget:self];
  [resultList setAction:@selector(listItemClicked:)];

  // Icon at the right of text field
  [iconPlace setBorderType:NSNoBorder];
  resultIcon = [[PathIcon alloc] init];
  [resultIcon setIconSize:NSMakeSize(66, 52)];
  [resultIcon setEditable:NO];
  [resultIcon setSelected:YES];
  [resultIcon setPaths:@[@"me"]];
  [resultIcon setMaximumCollapsedLabelWidth:50];
  [resultIcon setShowsExpandedLabelWhenSelected:NO];
}

- (void)activateWithString:(NSString *)searchString
{
  [resultList reloadColumn:0];

  if ([searchString length] > 0) {
    [findField setStringValue:searchString];
  }
  else {
    [findField setStringValue:@""];
  }
  
  [window makeFirstResponder:findField];
  
  if (![searchString isEqualToString:@""]) {
    [[window fieldEditor:NO forObject:findField]
      setSelectedRange:NSMakeRange([searchString length], 0)];
  }
  if ([window isVisible] == NO) {
    [window center];
    [window makeKeyAndOrderFront:nil];
  }
}

- (void)deactivate
{
  [window close];
}

- (void)windowWillClose:(NSNotification *)notif
{
  NXDefaults *df = [NXDefaults userDefaults];

  [df setObject:[shelf storableRepresentation] forKey:@"FinderShelfContents"];
  [df setObject:[self storableShelfSelection] forKey:@"FinderShelfSelection"];
  [df synchronize];
  
  [variantList release];
  variantList = nil;
}

- (NSWindow *)window
{
  return window;
}

// --- Utility

- (NSArray *)completionFor:(NSString *)path
{
  NSMutableArray *variants = [[NSMutableArray alloc] init];
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSArray        *dirContents;
  const char     *c_t;
  BOOL           isAbsolute = NO;
  NSString       *absPath;
  BOOL           isDir;

  if (!path || [path length] == 0 || [path isEqualToString:@""]) {
    return variants;
  }

  c_t = [path cString];
  if (c_t[0] == '/') {
    isAbsolute = YES;
  }
  else if (c_t[0] == '~') {
    path = [path stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                         withString:NSHomeDirectory()];
    isAbsolute = YES;
  }
  else if (([path length] > 1) && (c_t[0] == '.' && c_t[1] == '/')) {
    path = [path stringByReplacingCharactersInRange:NSMakeRange(0,2)
                                         withString:NSHomeDirectory()];
    isAbsolute = YES;
  }

  if (isAbsolute) {
    NSString *pathBase = [NSString stringWithString:path];
    
    // Do filesystem scan
    while ([fm fileExistsAtPath:pathBase isDirectory:&isDir] == NO) {
      pathBase = [pathBase stringByDeletingLastPathComponent];
    }
    dirContents = [fileViewer directoryContentsAtPath:pathBase forPath:nil];
    for (NSString *file in dirContents) {
      absPath = [pathBase stringByAppendingPathComponent:file];
      if ([absPath rangeOfString:path].location == 0) {
        [variants addObject:[absPath lastPathComponent]];
      }
    }
  }
  
  [findField setStringValue:path];
  [findField deselectText];  

  return variants;
}

- (void)makeCompletion
{
  NSString   *enteredText = [findField stringValue];
  NSString   *variant;
  NSText     *fieldEditor = [window fieldEditor:NO forObject:findField];
  NSUInteger selLocation, selLength;

  if ([enteredText length] == 0) {
    PathIcon *homeIcon = [shelf iconInSlot:NXMakeIconSlot(0,0)];
    NSSet    *selectedIcons = [shelf selectedIcons];
    if ([selectedIcons count] == 1) {
      PathIcon *icon = [selectedIcons anyObject];
      if (icon != homeIcon) {
        enteredText = [[icon paths] objectAtIndex:0];
      }
      else {
        enteredText = [[homeIcon paths] objectAtIndex:0];
      }
    }
  }

  if (variantList) {
    [variantList release];
  }
  variantList = [self completionFor:enteredText];
  [resultsFound setStringValue:[NSString stringWithFormat:@"%lu found",
                                         [variantList count]]];

  if ([variantList count] > 0) {
    NSFileManager  *fm = [NSFileManager defaultManager];
    BOOL           isDir;
    NSString       *path = [findField stringValue];
    
    [resultList reloadColumn:0];

    // Append '/' to dir name or shrink enetered path to exxisting dir
    if ([path characterAtIndex:[path length]-1] != '/') {
      if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
        if (isDir != NO) {
          path = [path stringByAppendingString:@"/"];
        }
      }
    }

    [findField setStringValue:path];
    [findField deselectText];
    
    // Set field value to first variant
    if ([variantList count] == 1) {
      // [resultList selectRow:0 inColumn:0];
      // resultIndex = 0;
      variant = [variantList objectAtIndex:0];
      path = [path stringByDeletingLastPathComponent];
      [findField setStringValue:[path stringByAppendingPathComponent:variant]];
      [findField deselectText];
    }
    // else {
    //   [fieldEditor
    //     setSelectedRange:NSMakeRange([path length] - [variant length], [variant length])];
    // }
  }
  else {
    [resultList reloadColumn:0];
    resultIndex = -1;
  }
}

- (void)updateButtonsState
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  BOOL           isDir;
  NSString       *text = [findField stringValue];
  BOOL           isEnabled = YES;
  
  if ([text isEqualToString:@""] || [text characterAtIndex:0] == ' ')
    isEnabled = NO;
  else if ([text characterAtIndex:0] == '/' &&
           (![fm fileExistsAtPath:text isDirectory:&isDir] || isDir)) {
    isEnabled = NO;
  }
  [findButton setEnabled:isEnabled];
  [findScopeButton setEnabled:isEnabled];
}

// --- Command text field delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSTextField *field = [aNotification object];
  NSString    *text;

  if (field != findField ||![field isKindOfClass:[NSTextField class]]) {
    return;
  }

  [resultsFound setStringValue:@""];
  [resultIcon removeFromSuperview];
  [self restoreSelection];
  
  text = [field stringValue];
  if ([text length] > 0 && [text characterAtIndex:[text length]-1] == '/') {
    [self makeCompletion];
  }
  else {
    [variantList release];
    variantList = nil;
    [resultList reloadColumn:0];
  }

  [self updateButtonsState];
}
- (void)findFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSTabCharacter:
    [window makeFirstResponder:findField];
    [self deactivate];
    break;
  case 27: // Escape
    [self makeCompletion];
    break;
  case NSCarriageReturnCharacter:
  case NSEnterCharacter:
    [fileViewer displayPath:[findField stringValue] selection:nil sender:self];
    [self deactivate];
  default:
    break;
  }
}
// --- Command and History browser delegate
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
	    inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  
  if (sender != resultList)
    return;

  for (NSString *variant in variantList) {
    [matrix addRow];
    cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
    [cell setLeaf:YES];
    [cell setTitle:variant];
    [cell setRefusesFirstResponder:YES];
  }
}

- (void)listItemClicked:(id)sender
{
  NSInteger selRow;
  NSString  *item, *path;
  NXIcon    *sIcon;

  if (sender != resultList)
    return;

  resultIndex = [resultList selectedRowInColumn:0];
  item = [variantList objectAtIndex:resultIndex];

  path = [findField stringValue];
  if ([path characterAtIndex:[path length]-1] != '/') {
    path = [path stringByDeletingLastPathComponent];
  }
  path = [path stringByAppendingPathComponent:item];
  
  [resultIcon setIconImage:[[NSApp delegate] iconForFile:path]];
  [resultIcon setPaths:@[path]];
  if (![resultIcon superview]) {
    [resultIcon putIntoView:iconPlace atPoint:NSMakePoint(33,48)];
    [self resignSelection];
  }
  
  [window makeFirstResponder:findField];
}

@end

@implementation Finder (Shelf)

- (NSArray *)storableShelfSelection
{
  NSMutableArray *selectedSlots = [[NSMutableArray alloc] init];
  NXIconSlot     slot;
  
  for (PathIcon *icon in [shelf icons]) {
    if ([icon isKindOfClass:[NSNull class]]) {
      continue;
    }
    if ([icon isSelected] != NO) {
      slot = [shelf slotForIcon:icon];
      [selectedSlots addObject:@[[NSNumber numberWithInt:slot.x],
                                 [NSNumber numberWithInt:slot.y]]];
    }
  }

  return [selectedSlots autorelease];
}

- (void)reconstructShelfSelection:(NSArray *)selectedSlots
{
  NXIconSlot   slot;
  NSMutableSet *selection = [[NSMutableSet alloc] init];

  for (NSArray *slotRep in selectedSlots) {
    slot = NXMakeIconSlot([[slotRep objectAtIndex:0] intValue],
                          [[slotRep objectAtIndex:1] intValue]);
    [selection addObject:[shelf iconInSlot:slot]];
  }

  if (!selectedSlots || [selectedSlots count] == 0) {
    [selection addObject:[shelf iconInSlot:NXMakeIconSlot(0,0)]];
  }
  [shelf selectIcons:selection];
  [selection release];
}

- (void)resignSelection
{
  NSSet *selectedIcons = [shelf selectedIcons];
  
  ASSIGN(savedSelection, [NSSet setWithSet:selectedIcons]);

  for (PathIcon *icon in selectedIcons) {
    [icon setSelected:NO];
    [[icon label] setTextColor:[NSColor whiteColor]];
    [[icon shortLabel] setTextColor:[NSColor whiteColor]];
  }
}

- (void)restoreSelection
{
  if (!savedSelection || [savedSelection count] <= 0)
    return;

  for (PathIcon *icon in savedSelection) {
    [icon setSelected:YES];
    [[icon label] setTextColor:[NSColor blackColor]];
    [[icon shortLabel] setTextColor:[NSColor blackColor]];
  }
}

@end
