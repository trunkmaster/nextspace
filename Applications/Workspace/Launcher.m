/* All Rights reserved */

#import <AppKit/AppKit.h>
#import <NXAppKit/NXAlert.h>
#import "Launcher.h"

@interface WMCommandField : NSTextField
- (void)commandFieldKeyUp:(NSEvent *)theEvent;
@end
@implementation WMCommandField
- (void)keyUp:(NSEvent *)theEvent
{
  if (_delegate && [_delegate respondsToSelector:@selector(commandFieldKeyUp:)]) {
    [_delegate commandFieldKeyUp:theEvent];
  }
}
- (void)commandFieldKeyUp:(NSEvent *)theEvent
{
  // Should be implemented by delegate
}
@end

@implementation Launcher

- (void)dealloc
{
  NSLog(@"Launcher: dealloc");

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
  [commandField setStringValue:@""];

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
    [NSBundle loadNibNamed:@"Launcher" owner:self];
  }
  else {
    [completionList reloadColumn:0];
    // [completionList setTitle:@"History" ofColumn:0];
  }
  
  [commandField selectText:nil];
  [window center];
  [window makeKeyAndOrderFront:nil];
}

- (void)deactivate
{
  [window close];
}

- (void)runCommand:(id)sender
{
  NSString       *commandLine = [commandField stringValue];
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
          [historyList insertObject:[commandField stringValue] atIndex:0];
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
    [historyList insertObject:[commandField stringValue] atIndex:0];
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
  NSString   *command = [commandField stringValue];
  NSString   *variant;
  NSText     *fieldEditor = [window fieldEditor:NO forObject:commandField];
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

    [commandField setStringValue:variant];
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
  NSString       *text = [commandField stringValue];
  BOOL           isEnabled = YES;
  
  if ([text isEqualToString:@""] || [text characterAtIndex:0] == ' ')
    isEnabled = NO;
  else if ([text characterAtIndex:0] == '/' &&
           (![fm fileExistsAtPath:text isDirectory:&isDir] || isDir)) {
    isEnabled = NO;
  }
  [runInTerminal setEnabled:isEnabled];
  [runButton setEnabled:isEnabled];
}

// --- Command text field delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSTextField    *field = [aNotification object];
  NSString       *text;

  if (field != commandField ||![field isKindOfClass:[NSTextField class]]) {
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
- (void)commandFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSUpArrowFunctionKey:
    // NSLog(@"WMCommandField key: Up");
    completionIndex++;
    if (completionIndex >= [completionSource count]) {
      completionIndex--;
    }
    [commandField setStringValue:[completionSource objectAtIndex:completionIndex]];
    [completionList selectRow:completionIndex inColumn:0];
    [self updateButtonsState];
    break;
  case NSDownArrowFunctionKey:
    // NSLog(@"WMCommandField key: Down");
    if (completionIndex > -1)
      completionIndex--;
    if (completionIndex >= 0) {
      [commandField setStringValue:[completionSource objectAtIndex:completionIndex]];
      [completionList selectRow:completionIndex inColumn:0];
    }
    else {
      [commandField setStringValue:@""];
      [completionList reloadColumn:0];
    }
    [self updateButtonsState];
    break;
  case NSDeleteFunctionKey:
  case NSDeleteCharacter:
    // NSLog(@"WMCommandField key: Delete or Backspace");
    {
      NSText  *text = [window fieldEditor:NO forObject:commandField];
      NSRange selectedRange = [text selectedRange];
      if (selectedRange.length > 0) {
        [text replaceRange:selectedRange withString:@""];
      }

      if ([[commandField stringValue] length] > 0) {
        ASSIGN(completionSource, historyList);
        if (commandVariants) [commandVariants release];
        commandVariants = [self completionFor:[commandField stringValue]];
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
    [[window fieldEditor:NO forObject:commandField]
        setSelectedRange:NSMakeRange([[commandField stringValue] length], 0)];
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
  [commandField setStringValue:[completionSource objectAtIndex:completionIndex]];
  [self updateButtonsState];
  
  [window makeFirstResponder:commandField];
}

@end
