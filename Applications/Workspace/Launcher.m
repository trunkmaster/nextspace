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
// - (BOOL)textShouldEndEditing:(NSText *)textObject
// {
//   return NO;
// }
// - (void)selectText:(id)sender
// {
//   // Do nothing to prevent selection flickering
//   NSText *text = [_window fieldEditor:YES forObject:self];
//   [_cell setUpFieldEditorAttributes:text];
//   // [super selectText:self];
// }
@end

@implementation Launcher

- (void)dealloc
{
  NSLog(@"Launcher: dealloc");

  [window release];
  [savedCommand release];
  [historyList release];
  
  [super dealloc];
}

- init
{
  [super init];
  
  [self initHistory];
  ASSIGN(completionSource, historyList);
  completionIndex = -1;

  savedCommand = [[NSMutableString alloc] init];

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

  commandArgs = [NSMutableArray 
                  arrayWithArray:[commandLine componentsSeparatedByString:@" "]];
  commandPath = [commandArgs objectAtIndex:0];
  [commandArgs removeObjectAtIndex:0];

  NSLog(@"Running command: %@ with args %@", commandPath, commandArgs);
  
  commandTask = [NSTask new];
  [commandTask setArguments:commandArgs];
  [commandTask setLaunchPath:commandPath];
//  [commandTask setStandardOutput:[NSFileHandle fileHandleWithStandardOutput]];
//  [commandTask setStandardError:[NSFileHandle fileHandleWithStandardError]];
//  [commandTask setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
  
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
  const char     *c_t;

  if (!command || [command length] == 0 || [command isEqualToString:@""]) {
    return variants;
  }

  // NSLog(@"completionFor:%@", command);

  // c_t = [command cString];
  // if ((c_t[0] == '/' ||
  //      ([command length] > 1 &&
  //       c_t[1] == '/' && (c_t[0] == '.' || c_t[0] == '~')))) {
  //   NSLog(@"Do filesystem scan for completion.");
  // }
  
  for (NSString *compElement in completionSource) {
    if ([compElement rangeOfString:command].location == 0) {
      [variants addObject:compElement];
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

// --- Command text field delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSTextField *field = [aNotification object];
  NSString    *text;

  if (field != commandField ||![field isKindOfClass:[NSTextField class]]) {
    return;
  }

  // Do not make completion if text in field was shrinked
  text = [field stringValue];
  if ([text length] > [savedCommand length]) {
    [self makeCompletion];
  }
  [savedCommand setString:text];

  if ([text isEqualToString:@""] || [text characterAtIndex:0] == ' ') {
    [runInTerminal setEnabled:NO];
    [runButton setEnabled:NO];
  }
  else {
    [runInTerminal setEnabled:YES];
    [runButton setEnabled:YES];
  }
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
    }
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

@end
