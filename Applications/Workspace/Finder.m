/* All Rights reserved */

#import <AppKit/AppKit.h>
#import <NXFoundation/NXDefaults.h>
#import <NXAppKit/NXAlert.h>
#import <NXAppKit/NXIconView.h>

#import <Viewers/PathIcon.h>
#import <Preferences/Shelf/ShelfPrefs.h>

#import "Finder.h"

@interface WMFindField : NSTextField
- (void)findFieldKeyUp:(NSEvent *)theEvent;
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
@end

@implementation Finder

- (void)dealloc
{
  NSLog(@"Finder: dealloc");

  [window release];
  [savedCommand release];
  [historyList release];
  [searchPaths release];
  
  [super dealloc];
}

- init
{
  NSString *envPath;
  
  [super init];
  
  [self initHistory];
  ASSIGN(completionSource, historyList);
  completionIndex = -1;

  savedCommand = [[NSMutableString alloc] init];
  
  envPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
  searchPaths = [[NSArray alloc]
                  initWithArray:[envPath componentsSeparatedByString:@":"]];
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
  
  [findField setStringValue:@""];

  [completionList loadColumnZero];
  [completionList setTakesTitleFromPreviousColumn:NO];
  [completionList setTitle:@"History" ofColumn:0];
  [completionList scrollColumnToVisible:0];
  [completionList setRefusesFirstResponder:YES];
  [completionList setTarget:self];
  [completionList setAction:@selector(listItemClicked:)];
}

- (void)activate
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
    [completionList reloadColumn:0];
    // [completionList setTitle:@"History" ofColumn:0];
  }
  
  [findField selectText:nil];
  [window center];
  [window makeKeyAndOrderFront:nil];
}

- (void)deactivate
{
  [window close];
}

- (void)runCommand:(id)sender
{
  NSString       *commandLine = [findField stringValue];
  NSString       *commandPath = nil;
  NSMutableArray *commandArgs = nil;
  NSTask         *commandTask = nil;

  if (!commandLine || [commandLine length] == 0 ||
      [commandLine isEqualToString:@""]) {
    return;
  }

  if (isRunInTerminal) {
    id proxy = GSContactApplication(@"Terminal", nil, nil);
    if (proxy != nil) {
      if ([proxy respondsToSelector:@selector(runProgram:)]) {
        @try {
          [proxy performSelector:@selector(runProgram) withObject:commandLine];
          [historyList insertObject:[findField stringValue] atIndex:0];
          [self saveHistory];
        }
        @catch (NSException *exception) {
          NXRunAlertPanel(@"Run Command",
                          @"Run command failed with exception: \'%@\'", 
                          @"Close", nil, nil, [exception reason]);
        }
        @finally {
          [window close];
        }
      }
    }
    return;
  }

  commandArgs = [NSMutableArray 
                  arrayWithArray:[commandLine componentsSeparatedByString:@" "]];
  commandPath = [commandArgs objectAtIndex:0];
  [commandArgs removeObjectAtIndex:0];

  NSLog(@"Running command: %@ with args %@", commandPath, commandArgs);
  
  commandTask = [NSTask new];
  [commandTask setArguments:commandArgs];
  [commandTask setLaunchPath:commandPath];
  
  @try {
    [commandTask launch];
    [historyList insertObject:[findField stringValue] atIndex:0];
    [self saveHistory];
  }
  @catch (NSException *exception) {
    NXRunAlertPanel(@"Run Command",
                    @"Run command failed with exception: \'%@\'", 
                    @"Close", nil, nil, [exception reason]);
  }
  @finally {
    [window close];
  }
}

- (void)runInTerminal:(id)sender
{
  if (sender != runInTerminal)
    return;
  
  isRunInTerminal = [sender state];
}

// --- History file manipulations

#define LIB_DIR    @"Library/Workspace"
#define WM_LIB_DIR @"Library/WindowMaker"

- (void)initHistory
{
  NSString 	*libPath;
  NSString	*histPath;  
  NSString	*wmHistPath;
  NSFileManager	*fm = [NSFileManager defaultManager];
  BOOL		isDir;

  libPath = [NSHomeDirectory() stringByAppendingPathComponent:LIB_DIR];
  histPath = [libPath stringByAppendingPathComponent:@"LauncherHistory"];
  wmHistPath = [NSHomeDirectory()
                   stringByAppendingFormat:@"/%@/History", WM_LIB_DIR];

  // Create ~/Library/Workspace directory if not exsist
  if ([fm fileExistsAtPath:libPath isDirectory:&isDir] == NO) {
    if ([fm createDirectoryAtPath:libPath attributes:nil] == NO) {
      NSLog(@"Failed to create library directory %@!", libPath);
    }
  }
  else if ([fm fileExistsAtPath:histPath isDirectory:&isDir] != NO &&
           isDir == NO) {
    historyList = [[NSMutableArray alloc] initWithContentsOfFile:histPath];
  }

  // Load WindowMaker history
  if (historyList == nil) {
    historyList = [[NSMutableArray alloc] initWithContentsOfFile:wmHistPath];
    if (historyList == nil) {
      NSLog(@"Failed to load history file %@", wmHistPath);
      historyList = [[NSMutableArray alloc] init];
    }
  }

  [self saveHistory];
}

- (void)saveHistory
{
  NSString *historyPath;
  NSString *latestCommand;
  NSString *element;
  NSUInteger elementsCount = [historyList count];
  
  // Remove duplicates
  if (elementsCount > 1) {
    latestCommand = [historyList objectAtIndex:0];
    for (int i = 1; i < elementsCount; i++) {
      element = [historyList objectAtIndex:i];
      if ([element isEqualToString:latestCommand]) {
        [historyList removeObjectAtIndex:i];
        elementsCount--;
      }
    }
  }
  
  historyPath = [NSHomeDirectory()
                    stringByAppendingFormat:@"/%@/LauncherHistory", LIB_DIR];
  [historyList writeToFile:historyPath atomically:YES];
}

// --- Utility

- (NSArray *)completionFor:(NSString *)command
{
  NSMutableArray *variants = [[NSMutableArray alloc] init];
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSArray        *dirContents;
  const char     *c_t;
  BOOL           includeDirs = NO;
  NSString       *absPath;
  BOOL           isDir;

  if (!command || [command length] == 0 || [command isEqualToString:@""]) {
    return variants;
  }

  // NSLog(@"completionFor:%@", command);

  // Go through the history first
  for (NSString *compElement in historyList) {
    if ([compElement rangeOfString:command].location == 0) {
      [variants addObject:compElement];
    }
  }

  c_t = [command cString];
  if (c_t[0] == '/') {
    includeDirs = YES;
  }
  if ([command length] > 1) {
    if (c_t[0] == '.' && c_t[1] == '/') {
      command = [command stringByReplacingCharactersInRange:NSMakeRange(0,2)
                                                 withString:NSHomeDirectory()];
      includeDirs = YES;
    }
    if (c_t[0] == '~') {
      command = [command stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                                 withString:NSHomeDirectory()];
      includeDirs = YES;
    }
  }

  if (includeDirs) {
    NSString *commandBase = [NSString stringWithString:command];
    // Do filesystem scan
    while ([fm fileExistsAtPath:commandBase isDirectory:&isDir] == NO) {
      commandBase = [commandBase stringByDeletingLastPathComponent];
    }
    dirContents = [fm directoryContentsAtPath:commandBase];
    for (NSString *file in dirContents) {
      absPath = [commandBase stringByAppendingPathComponent:file];
      if ([absPath rangeOfString:command].location == 0) {
        if ([fm isExecutableFileAtPath:absPath]) {
          [variants addObject:absPath];
        }
      }
    }
  }
  else {
    // Gor through the $PATH directories
    for (NSString *dir in searchPaths) {
      dirContents = [fm directoryContentsAtPath:dir];
      for (NSString *file in dirContents) {
        if ([file rangeOfString:command].location == 0) {
          absPath = [dir stringByAppendingPathComponent:file];
          if ([fm isExecutableFileAtPath:absPath]) {
            [variants addObject:file];
          }
        }
      }
    }
  }
  
  return variants;
}

- (void)makeCompletion
{
  NSString   *command = [findField stringValue];
  NSString   *variant;
  NSText     *fieldEditor = [window fieldEditor:NO forObject:findField];
  NSUInteger selLocation, selLength;

  if (commandVariants) [commandVariants release];
  commandVariants = [self completionFor:command];

  if ([commandVariants count] > 0) {
    ASSIGN(completionSource, commandVariants);
    [completionList reloadColumn:0];
    [completionList setTitle:@"Completion" ofColumn:0];
    [completionList selectRow:0 inColumn:0];
    variant = [commandVariants objectAtIndex:0];
    completionIndex = 0;

    [findField setStringValue:variant];
    selLocation = [command length];
    selLength = [variant length] - [command length];
    [fieldEditor setSelectedRange:NSMakeRange(selLocation, selLength)];
  }
  else {
    ASSIGN(completionSource, historyList);
    [completionList reloadColumn:0];
    [completionList setTitle:@"History" ofColumn:0];
    completionIndex = -1;
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
  [runInTerminal setEnabled:isEnabled];
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
  text = [field stringValue];
  if ([text length] > [savedCommand length]) {
    [self makeCompletion];
  }

  [savedCommand setString:text];
  [self updateButtonsState];
}
- (void)findFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSUpArrowFunctionKey:
    // NSLog(@"WMCommandField key: Up");
    completionIndex++;
    if (completionIndex >= [completionSource count]) {
      completionIndex--;
    }
    [findField setStringValue:[completionSource objectAtIndex:completionIndex]];
    [completionList selectRow:completionIndex inColumn:0];
    [self updateButtonsState];
    break;
  case NSDownArrowFunctionKey:
    // NSLog(@"WMCommandField key: Down");
    if (completionIndex > -1)
      completionIndex--;
    if (completionIndex >= 0) {
      [findField setStringValue:[completionSource objectAtIndex:completionIndex]];
      [completionList selectRow:completionIndex inColumn:0];
    }
    else {
      [findField setStringValue:@""];
      [completionList reloadColumn:0];
    }
    [self updateButtonsState];
    break;
  case NSDeleteFunctionKey:
  case NSDeleteCharacter:
    // NSLog(@"WMCommandField key: Delete or Backspace");
    {
      NSText  *text = [window fieldEditor:NO forObject:findField];
      NSRange selectedRange = [text selectedRange];
      if (selectedRange.length > 0) {
        [text replaceRange:selectedRange withString:@""];
      }

      if ([[findField stringValue] length] > 0) {
        ASSIGN(completionSource, historyList);
        if (commandVariants) [commandVariants release];
        commandVariants = [self completionFor:[findField stringValue]];
        ASSIGN(completionSource, commandVariants);
        [completionList reloadColumn:0];
        [completionList setTitle:@"Completion" ofColumn:0];
        completionIndex = -1;
      }
      else {
        ASSIGN(completionSource, historyList);
        [completionList reloadColumn:0];
        [completionList setTitle:@"History" ofColumn:0];
        completionIndex = -1;
      }
      [self updateButtonsState];
    }
  case NSTabCharacter:
    [[window fieldEditor:NO forObject:findField]
        setSelectedRange:NSMakeRange([[findField stringValue] length], 0)];
    break;
  default:
    break;
  }
  // NSLog(@"WMCommandField key: %X", c);
}
// --- Command and History browser delegate
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
	    inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  
  if (sender != completionList)
    return;

  for (NSString *variant in completionSource) {
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

  if (sender != completionList)
    return;
  
  completionIndex = [sender selectedRowInColumn:0];
  [findField setStringValue:[completionSource objectAtIndex:completionIndex]];
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
