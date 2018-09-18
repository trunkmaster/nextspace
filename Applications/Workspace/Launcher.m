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

  [wmHistory release];
  [wmHistoryPath release];
  [window release];
  
  [super dealloc];
}

- init
{
  [super init];

  historyMode = YES;
  filesystemMode = NO;
  
  wmHistoryPath = [[NSString alloc] initWithFormat:@"%@/Library/WindowMaker/History",
                                     NSHomeDirectory()];
  wmHistory = [[NSMutableArray alloc] initWithContentsOfFile:wmHistoryPath];
  wmHistoryIndex = -1;

  return self;
}

- (void)awakeFromNib
{
  [commandName setStringValue:@""];

  [historyAndCompletion loadColumnZero];
  [historyAndCompletion setTakesTitleFromPreviousColumn:NO];
  [historyAndCompletion setTitle:@"History" ofColumn:0];
  [historyAndCompletion scrollColumnToVisible:0];
  [historyAndCompletion setRefusesFirstResponder:YES];
}

- (void)activate
{
  if (window == nil) {
    [NSBundle loadNibNamed:@"Launcher" owner:self];
  }
  else {
    [historyAndCompletion reloadColumn:0];
    // [historyAndCompletion setTitle:@"History" ofColumn:0];
  }
  
  [commandName selectText:nil];
  [window center];
  [window makeKeyAndOrderFront:nil];
}

- (void)deactivate
{
  [window close];
}

- (void)runCommand:(id)sender
{
  NSString       *commandPath = nil;
  NSMutableArray *commandArgs = nil;
  NSTask         *commandTask = nil;

  commandArgs = [NSMutableArray 
    arrayWithArray:[[commandName stringValue] componentsSeparatedByString:@" "]];
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
    [wmHistory insertObject:[commandName stringValue] atIndex:0];
    [wmHistory writeToFile:wmHistoryPath atomically:YES];
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

// --- Utility

- (NSArray *)completionFor:(NSString *)command
{
  NSMutableArray *variants = [[NSMutableArray alloc] init];
  unichar c0 = [command characterAtIndex:0];

  if (!command || [command length] == 0 || [command isEqualToString:@""]) {
    completionSource = wmHistory;
    return variants;
  }
  
  if (!filesystemMode && command &&
      (c0 == '/' || c0 == '.' || c0 == '~')) {
    filesystemMode = YES;
  }
  else {
    filesystemMode = NO;
  }

  for (NSString *hCommand in completionSource) {
    if ([hCommand rangeOfString:command].location == 0) {
      [variants addObject:hCommand];
    }
  }
  
  return [variants autorelease];
}

- (void)makeTabCompletion
{
  NSString   *command = [commandName stringValue];
  NSString   *variant;
  NSText     *fieldEditor = [window fieldEditor:NO forObject:commandName];
  NSUInteger selLocation, selLength;
  
  commandVariants = [self completionFor:command];
  [historyAndCompletion reloadColumn:0];
  
  if ([commandVariants count] > 0) {
    [historyAndCompletion selectRow:0 inColumn:0]; // TODO
    [historyAndCompletion setTitle:@"Completion" ofColumn:0];
    wmHistoryIndex = 0;
    completionSource = commandVariants;
    variant = [commandVariants objectAtIndex:0]; // TODO

    [commandName setStringValue:variant];
    selLocation = [command length];
    selLength = [variant length] - [command length];
    [fieldEditor setSelectedRange:NSMakeRange(selLocation, selLength)];
  }
  else {
    [historyAndCompletion setTitle:@"History" ofColumn:0];
    completionSource = wmHistory;
    [historyAndCompletion selectRow:0 inColumn:0];
    wmHistoryIndex = 0;
  }
}

// --- Command text field delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSTextField *commandField = [aNotification object];

  if (commandField != commandName ||
      ![commandField isKindOfClass:[NSTextField class]]) {
    return;
  }
  
  [self makeTabCompletion];
}
- (void)commandFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSUpArrowFunctionKey:
    // NSLog(@"WMCommandField key: Up");
    wmHistoryIndex++;
    if (wmHistoryIndex >= [wmHistory count]) {
      wmHistoryIndex--;
    }
    [commandName setStringValue:[completionSource objectAtIndex:wmHistoryIndex]];
    [historyAndCompletion selectRow:wmHistoryIndex inColumn:0];
    break;
  case NSDownArrowFunctionKey:
    // NSLog(@"WMCommandField key: Down");
    if (wmHistoryIndex > -1)
      wmHistoryIndex--;
    if (wmHistoryIndex >= 0) {
      [commandName setStringValue:[completionSource objectAtIndex:wmHistoryIndex]];
      [historyAndCompletion selectRow:wmHistoryIndex inColumn:0];
    }
    else {
      [commandName setStringValue:@""];
      [historyAndCompletion reloadColumn:0];
    }
    break;
  case NSTabCharacter:
    [self makeTabCompletion];
    break;
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
  
  if (sender != historyAndCompletion)
    return;

  for (NSString *variant in completionSource) {
    [matrix addRow];
    cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
    [cell setLeaf:YES];
    [cell setTitle:variant];
    [cell setRefusesFirstResponder:YES];
  }

  // if ([commandVariants count] > 0) {
  //   hacSource = commandVariants;
  //   for (NSString *variant in commandVariants) {
  //     [matrix addRow];
  //     cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
  //     [cell setLeaf:YES];
  //     [cell setTitle:variant];
  //     [cell setRefusesFirstResponder:YES];
  //   }
  // }
  // else if (historyMode != NO) {
  //   hacSource = wmHistory;
  //   for (NSString *command in wmHistory) {
  //     [matrix addRow];
  //     cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
  //     [cell setLeaf:YES];
  //     [cell setTitle:command];
  //     [cell setRefusesFirstResponder:YES];
  //   }
  // }
}

@end
