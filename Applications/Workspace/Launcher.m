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

static Launcher *shared = nil;

+ shared
{
  if (shared == nil) {
    shared = [self new];
  }

  return shared;
}

- (void)dealloc
{
  NSDebugLLog(@"Launcher", @"Launcher: dealloc");

  [super dealloc];
}

- init
{
  [super init];

  ASSIGN(savedString, @"");
  historyMode = YES;
  filesystemMode = NO;

  return self;
}

- (void)awakeFromNib
{
  [commandName setStringValue:savedString];
  DESTROY(savedString);

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
  }
  
  [commandName selectText:nil];
  [window center];
  [window makeKeyAndOrderFront:nil];
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
/*  [commandTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
  [commandTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
  [commandTask setStandardInput:[NSFileHandle fileHandleWithNullDevice]];*/
  NS_DURING {
    [commandTask launch];
  }
  NS_HANDLER {
    NXRunAlertPanel(@"Run Command",
                    @"Run command failed with exception: \'%@\'", 
                    @"Close", nil, nil,
                    [localException reason]);
  }
  NS_ENDHANDLER

  DESTROY(savedString);
  ASSIGN(savedString, [commandName stringValue]);
  [window close];
}

// --- Utility
- (NSArray *)loadHistory
{
  NSArray       *wmHistory;
  NSString      *wmHistoryPath;
  
  [historyAndCompletion setTitle:@"History" ofColumn:0];
  wmHistoryPath = [NSString stringWithFormat:@"%@/Library/WindowMaker/History",
                            NSHomeDirectory()];
  wmHistory = [NSArray arrayWithContentsOfFile:wmHistoryPath];

  return wmHistory;
}

- (NSArray *)makeCompletionFor:(NSString *)command
{
  return nil;
}

// --- Command text field delegate
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSLog(@"Launcher: text changed.");
  NSTextField *commandField = [aNotification object];
  NSString    *commandText;
  NSArray     *variants;

  if (commandField != commandName ||
      [commandField isKindOfClass:[NSTextField class]]) {
    return;
  }
  commandText = [commandField stringValue];
  if (!filesystemMode && [commandText characterAtIndex:0] == '/') {
    filesystemMode = YES;
  }
  variants = [self makeCompletionFor:commandText];
}
- (void)commandFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSUpArrowFunctionKey:
    NSLog(@"WMCommandField key: Up");
    break;
  case NSDownArrowFunctionKey:
    NSLog(@"WMCommandField key: Down");
    break;
  case NSHomeFunctionKey:
    NSLog(@"WMCommandField key: Home");
    break;
  case NSEndFunctionKey:
    NSLog(@"WMCommandField key: End");
    break;
  case NSTabCharacter:
    NSLog(@"WMCommandField key: Tab");
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

  if (historyMode != NO) {
    for (NSString *command in [self loadHistory]) {
      [matrix addRow];
      cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:0];
      [cell setLeaf:YES];
      [cell setTitle:command];
      [cell setRefusesFirstResponder:YES];
    }
  }
}

@end
