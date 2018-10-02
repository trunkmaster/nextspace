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

  [window release];
  
  [super dealloc];
}

- initWithFileViewer:(FileViewer *)fv
{
  NSString *envPath;
  
  [super init];

  fileViewer = fv;
  resultIndex = -1;

  return self;
}

- (void)awakeFromNib
{
  // Shelf
  [shelf setAutoAdjustsToFitIcons:NO];
  [shelf setAllowsMultipleSelection:YES];
  // [shelf setAllowsEmptySelection:NO];
  [shelf setAllowsAlphanumericSelection:NO];
  [shelf registerForDraggedTypes:@[NSFilenamesPboardType]];
  [shelf setTarget:self];
  [shelf setDelegate:self];
  [shelf setAction:@selector(iconClicked:)];
  // [shelf setDoubleAction:@selector(iconDoubleClicked:)];
  // [shelf setDragAction:@selector(iconDragged:event:)];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(iconSlotWidthChanged:)
           name:ShelfIconSlotWidthDidChangeNotification
         object:nil];
  [self initShelf];

  // Text field
  [findField setStringValue:@""];

  // Browser list
  [resultList loadColumnZero];
  [resultList setTakesTitleFromPreviousColumn:NO];
  [resultList setTitle:@"History" ofColumn:0];
  [resultList scrollColumnToVisible:0];
  [resultList setRefusesFirstResponder:YES];
  [resultList setTarget:self];
  [resultList setAction:@selector(listItemClicked:)];
}

- (void)activateWithString:(NSString *)searchString
{
  if (window == nil) {
    NXDefaults *df = [NXDefaults userDefaults];
    NSSize     slotSize;
    
    if ([df objectForKey:ShelfIconSlotWidth]) {
      slotSize = NSMakeSize([df floatForKey:ShelfIconSlotWidth], 76);
    }
    else {
      slotSize = NSMakeSize(76, 76);
    }
    [NXIconView setDefaultSlotSize:slotSize];
    [NSBundle loadNibNamed:@"Finder" owner:self];
  }
  else {
    [resultList reloadColumn:0];
  }

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
  [window center];
  [window makeKeyAndOrderFront:nil];
}

- (void)deactivate
{
  [window close];
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

  // NSLog(@"completionFor:%@", command);

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
    dirContents = [fm directoryContentsAtPath:pathBase];
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

  if (variantList) {
    [variantList release];
  }
  variantList = [self completionFor:enteredText];

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
      else {
        path = [path stringByDeletingLastPathComponent];
      }
    }

    // Set field value to first variant
    [resultList selectRow:0 inColumn:0];
    variant = [variantList objectAtIndex:0];
    resultIndex = 0;

    path = [path stringByAppendingPathComponent:variant];
    [findField setStringValue:path];
    [findField deselectText];
  
    if ([variantList count] == 1) {
      [findField deselectText];
    }
    else {
      [fieldEditor
        setSelectedRange:NSMakeRange([path length] - [variant length], [variant length])];
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
}

// --- Command text field delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSTextField    *field = [aNotification object];
  NSString       *text;

  if (field != findField ||![field isKindOfClass:[NSTextField class]]) {
    return;
  }

  // Do not make completion if text in field was shrinked
  // text = [field stringValue];
  // if ([text length] > [savedCommand length]) {
    // [self makeCompletion];
  // }

  [self updateButtonsState];
}
- (void)findFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  // case NSDeleteFunctionKey:
  // case NSDeleteCharacter:
  //   {
  //     NSText  *text = [window fieldEditor:NO forObject:findField];
  //     NSRange selectedRange = [text selectedRange];
      
  //     if (selectedRange.length > 0) {
  //       [text replaceRange:selectedRange withString:@""];
  //     }

  //     if ([[findField stringValue] length] > 0) {
  //       if (variantList)
  //         [variantList release];
  //       variantList = [self completionFor:[findField stringValue]];
  //       [resultList reloadColumn:0];
  //       resultIndex = -1;
  //     }
  //     [self updateButtonsState];
  //   }
  //   break;
  case NSTabCharacter:
    [window makeFirstResponder:resultList];
    break;
  case 27: // Escape
    [self makeCompletion];
    break;
  case NSCarriageReturnCharacter:
  case NSEnterCharacter:
    [self makeCompletion];
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

  if (sender != resultList)
    return;
  
  resultIndex = [sender selectedRowInColumn:0];
  [findField setStringValue:[completionSource objectAtIndex:resultIndex]];
  [self updateButtonsState];
  
  [window makeFirstResponder:findField];
}

@end

@implementation Finder (Shelf)

- (void)initShelf
{
  NSDictionary *aDict = [[NXDefaults userDefaults] objectForKey:@"FinderShelfContents"];
  PathIcon     *icon;

  if (!aDict || [aDict isKindOfClass:[NSDictionary class]]) {
    // Home
    icon = [self createIconForPaths:@[NSHomeDirectory()]];
    if (icon) {
      [icon setDelegate:self];
      [icon registerForDraggedTypes:@[NSFilenamesPboardType]];
      [shelf putIcon:icon intoSlot:NXMakeIconSlot(0,0)];
      [icon setEditable:NO];
    }

    // /
    icon = [self createIconForPaths:@[@"/"]];
    if (icon) {
      [icon setDelegate:self];
      [shelf putIcon:icon intoSlot:NXMakeIconSlot(1,0)];
      [icon setEditable:NO];
    }
    return;
  }
  
  for (NSArray *key in [aDict allKeys]) {
    NSArray    *paths;
    NXIconSlot slot;

    if (![key isKindOfClass:[NSArray class]] || [key count] != 2) {
      continue;
    }
    if (![[key objectAtIndex:0] respondsToSelector:@selector(intValue)] ||
        ![[key objectAtIndex:1] respondsToSelector:@selector(intValue)]) {
      continue;
    }

    slot = NXMakeIconSlot([[key objectAtIndex:0] intValue],
                          [[key objectAtIndex:1] intValue]);
      
    paths = [aDict objectForKey:key];
    if (![paths isKindOfClass:[NSArray class]]) {
      continue;
    }

    icon = [self createIconForPaths:paths];
    if (icon) {
      [icon setDelegate:self];
      [icon registerForDraggedTypes:@[NSFilenamesPboardType]];
      [shelf putIcon:icon intoSlot:slot];
    }
  }
}

- (NSDictionary *)shelfRepresentation
{
  NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
  Class               nullClass = [NSNull class];

  for (PathIcon *icon in [shelf icons]) {
    NXIconSlot slot;

    if ([icon isKindOfClass:nullClass] || [[icon paths] count] > 1) {
      continue;
    }

    slot = [shelf slotForIcon:icon];

    if (slot.x == -1) {
      [NSException raise:NSInternalInconsistencyException
                  format:@"ShelfView: in `-storableRepresentation':"
                   @" Unable to deteremine the slot for an icon that"
                   @" _must_ be present"];
    }

    [dict setObject:[icon paths] forKey:@[[NSNumber numberWithInt:slot.x],
                                          [NSNumber numberWithInt:slot.y]]];
  }

  return [dict autorelease];
}

- (void)iconClicked:(id)sender
{
  // Set icon path as root path for search
}

- (PathIcon *)createIconForPaths:(NSArray *)paths
{
  PathIcon *icon;
  NSString *path;
  // NSString *relativePath;
  // NSString *rootPath = [_owner rootPath];

  if ((path = [paths objectAtIndex:0]) == nil) {
    return nil;
  }

  // make sure its a subpath of our current root path
  // if ([path rangeOfString:rootPath].location != 0) {
  //   return nil;
  // }
  // relativePath = [path substringFromIndex:[rootPath length]];

  icon = [[PathIcon new] autorelease];
  if ([paths count] == 1) {
    [icon setIconImage:[[NSApp delegate] iconForFile:path]];
  }
  [icon setPaths:paths];
  [icon setDoubleClickPassesClick:YES];
  [icon setEditable:NO];
  [[icon label] setNextKeyView:findField];

  return icon;
}

// --- Notifications

- (void)iconSlotWidthChanged:(NSNotification *)notif
{
  NXDefaults *df = [NXDefaults userDefaults];
  NSSize     size = [shelf slotSize];
  CGFloat    width = 0.0;

  if ((width = [df floatForKey:ShelfIconSlotWidth]) > 0.0) {
    size.width = width;
  }
  else {
    size.width = SHELF_LABEL_WIDTH;
  }
  [shelf setSlotSize:size];
}

@end
