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

  [variantList release];
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
  variantList = [[NSMutableArray alloc] init]; 

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

  [resultsFound setStringValue:@""];
  [statusField setStringValue:@""];

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
  
  [variantList removeAllObjects];
}

- (NSWindow *)window
{
  return window;
}

// --- Actions

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

  [variantList removeAllObjects];
  
  if ([enteredText length] == 0) {
    NSSet  *selectedIcons = [shelf selectedIcons];
    
    if ([selectedIcons count] > 1) {
      for (PathIcon *icon in selectedIcons) {
        [variantList addObjectsFromArray:[icon paths]];
      }
    }
    else {
      enteredText = [[[selectedIcons anyObject] paths] objectAtIndex:0];
      [variantList addObjectsFromArray:[self completionFor:enteredText]];
    }
  }
  else {
    [variantList addObjectsFromArray:[self completionFor:enteredText]];
  }

  [resultsFound setStringValue:[NSString stringWithFormat:@"%lu found",
                                         [variantList count]]];
  
  if ([variantList count] > 0) {
    NSFileManager  *fm = [NSFileManager defaultManager];
    BOOL           isDir;
    NSString       *path = [findField stringValue];
    
    [resultList reloadColumn:0];

    // Append '/' to dir name or shrink enetered path to existing dir
    if ([path length] > 0 && [path characterAtIndex:[path length]-1] != '/') {
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
      variant = [variantList objectAtIndex:0];
      path = [path stringByDeletingLastPathComponent];
      [findField setStringValue:[path stringByAppendingPathComponent:variant]];
      [findField deselectText];
    }
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

- (void)findInDirectory:(NSString *)dirPath
             expression:(NSRegularExpression *)regexp
{
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          isDir;
  NSArray       *dirContents;
  NSUInteger    numberOfMatches;
  NSString      *itemPath;

  NSLog(@"Processing: %@...", dirPath);
  
  dirContents = [fileViewer directoryContentsAtPath:dirPath forPath:nil];
  for (NSString *item in dirContents) {
    itemPath = [NSString stringWithFormat:@"%@/%@", dirPath, item];
    [fm fileExistsAtPath:itemPath isDirectory:&isDir];
    if (isDir) {
      [self findInDirectory:itemPath expression:regexp];
    }
    else {
      numberOfMatches = [regexp numberOfMatchesInString:item
                                                options:0
                                                  range:NSMakeRange(0, [item length])];
      if (numberOfMatches > 0) {
        NSLog(@"Match: %@/%@", dirPath, item);
        [variantList addObject:[NSString stringWithFormat:@"%@/%@", dirPath, item]];
        // [resultList reloadColumn:0];
      }
    }
  }
}

- (void)performFind:(id)sender
{
  NSError             *error = NULL;
  NSRegularExpression *regex;
  NSMutableArray      *searchPaths = [NSMutableArray array];
  NSArray             *dirContents;
  NSFileManager       *fm = [NSFileManager defaultManager];
  BOOL                isDir;
  NSUInteger          numberOfMatches;

  [statusField setStringValue:@"Searching..."];
  
  [variantList removeAllObjects];

  for (PathIcon *icon in [shelf selectedIcons]) {
    [searchPaths addObjectsFromArray:[icon paths]];
  }
  
  regex = [NSRegularExpression
            regularExpressionWithPattern:[findField stringValue]
                                 options:NSRegularExpressionCaseInsensitive
                                   error:&error];

  // NSMatrix *matrix = [resultList matrixInColumn:0];
  // NSBrowserCell *cell;

  for (NSString *path in searchPaths) {
    [self findInDirectory:path expression:regex];
    [resultList reloadColumn:0];
  }

  [resultsFound setStringValue:[NSString stringWithFormat:@"%lu found",
                                         [variantList count]]];
  
  [findButton setImagePosition:NSImageAbove];
  [findButton setNextState];
  [statusField setStringValue:@""];
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
  [self restoreShelfSelection];
  resultIndex = -1;
  
  text = [field stringValue];
  if ([text length] > 0 && [text characterAtIndex:[text length]-1] == '/') {
    [self makeCompletion];
  }
  else {
    [variantList removeAllObjects];
    [resultList reloadColumn:0];
  }

  [self updateButtonsState];
}
- (void)findFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSTabCharacter:
    if (resultIndex >= 0 && resultIndex >= [variantList count]-1) {
      [resultList reloadColumn:0];
      resultIndex = -1;
      [resultIcon removeFromSuperview];
      [self restoreShelfSelection];
      [window makeFirstResponder:findField];
      [findField deselectText];
    }
    else if ([variantList count] > 0){
      resultIndex++;
      [resultList selectRow:resultIndex inColumn:0];
      [self listItemClicked:resultList];
    }
    break;
  case 27: // Escape
    [self makeCompletion];
    if ([resultIcon superview]) {
      resultIndex = -1;
      [resultIcon removeFromSuperview];
      [self restoreShelfSelection];
      [window makeFirstResponder:findField];
      [findField deselectText];
    }
    break;
  case NSCarriageReturnCharacter:
  case NSEnterCharacter:
    {
      NSString *enteredText = [findField stringValue];
      if ([enteredText characterAtIndex:0] == '/') {
        [fileViewer displayPath:enteredText selection:nil sender:self];
        [self deactivate]; 
      }
      else {
        // FIXME: The code below is a placeholder.
        if ([findButton imagePosition] == NSImageOnly) {
          [findButton setImagePosition:NSImageAbove];
        }
        else {
          [findButton setImagePosition:NSImageOnly];
        }
        [findButton performClick:self];
      }        
   }
  default:
    break;
  }
}

// --- Results browser delegate

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
  if ([path length] > 1 && [path characterAtIndex:[path length]-1] != '/') {
    path = [path stringByDeletingLastPathComponent];
  }
  path = [path stringByAppendingPathComponent:item];
  
  [resultIcon setIconImage:[[NSApp delegate] iconForFile:path]];
  [resultIcon setPaths:@[path]];
  if (![resultIcon superview]) {
    [resultIcon putIntoView:iconPlace atPoint:NSMakePoint(33,48)];
    if ([[shelf selectedIcons] count] > 0) {
      [self resignShelfSelection];
    }
  }
  
  [window makeFirstResponder:findField];
}

@end

@implementation Finder (Shelf)

- (NSArray *)storableShelfSelection
{
  NSMutableArray *selectedSlots = [[NSMutableArray alloc] init];
  NXIconSlot     slot;
  
  for (PathIcon *icon in [shelf selectedIcons]) {
    if ([icon isKindOfClass:[NSNull class]]) {
      continue;
    }
    slot = [shelf slotForIcon:icon];
    [selectedSlots addObject:@[[NSNumber numberWithInt:slot.x],
                               [NSNumber numberWithInt:slot.y]]];
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

// This method manipulates icon selected state directly.
// NXIconView -selectedIcons method returns selected set of icons.
- (void)resignShelfSelection
{
  NSSet *selectedIcons = [shelf selectedIcons];
  
  ASSIGN(savedSelection, [NSSet setWithSet:selectedIcons]);

  for (PathIcon *icon in selectedIcons) {
    [icon setSelected:NO];
    [[icon label] setTextColor:[NSColor whiteColor]];
    [[icon shortLabel] setTextColor:[NSColor whiteColor]];
  }
}

- (void)restoreShelfSelection
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
