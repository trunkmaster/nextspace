/* -*- mode: objc -*- */
//
// Project: Workspace
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

#import <AppKit/AppKit.h>
#import <DesktopKit/NXTAlert.h>
#import <DesktopKit/NXTFileManager.h>
#import "Launcher.h"

@interface WMCommandField : NSTextField
- (void)commandFieldKeyUp:(NSEvent *)theEvent;
- (void)deselectText;
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
- (void)deselectText
{
  NSString *fieldString = [self stringValue];
  NSText   *fieldEditor = [_window fieldEditor:NO forObject:self];
  
  [fieldEditor setSelectedRange:NSMakeRange([fieldString length], 0)];
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
          NXTRunAlertPanel(@"Run Command",
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
    NXTRunAlertPanel(@"Run Command",
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

- (NSArray *)completionForCommand:(NSString *)command
{
  NSMutableArray *variants = [[NSMutableArray alloc] init];
  NXTFileManager *fm = [NXTFileManager defaultManager];
  NSString       *absPath;

  if (!command || [command length] == 0 || [command isEqualToString:@""]) {
    return variants;
  }

  NSLog(@"completionFor: %@ - %@", command, historyList);

  // Go through the history first
  for (NSString *compElement in historyList) {
    if ([compElement rangeOfString:command].location == 0) {
      [variants addObject:compElement];
    }
  }

  absPath = [fm absolutePathForPath:command];
  // NSLog(@"Absolute command: %@ - %@", command, absPath);
  if (absPath) { // Absolute path exists
    NSArray *completion = [fm completionForPath:absPath isAbsolute:YES];
    for (NSString *path in completion) {
      if ([fm isExecutableFileAtPath:path]) {
        [variants addObject:path];
      }
    }
  }
  else { // No absolute path - go through the $PATH
    NSArray *executables;
    executables = [fm executablesForSubstring:command];
    if ([executables count] > 0) {
      [variants addObjectsFromArray:executables];
    }
  }
  
  return variants;
}

- (void)makeCompletion
{
  NSString       *command = [commandField stringValue];
  NSUInteger     commandLength = [command length];
  NSString       *variant;
  BOOL           isDir = NO;
  NXTFileManager *fm = [NXTFileManager defaultManager];

  if (commandVariants) [commandVariants release];
  commandVariants =[self completionForCommand:command];

  if ([commandVariants count] > 0) {
    ASSIGN(completionSource, commandVariants);
    [completionList reloadColumn:0];
    [completionList setTitle:@"Completion" ofColumn:0];
    [completionList selectRow:0 inColumn:0];
    variant = [commandVariants objectAtIndex:0];
    completionIndex = 0;
    isDir = [fm directoryExistsAtPath:variant];

    if ([[commandField stringValue] characterAtIndex:0] == '~') {
      variant = [variant stringByAbbreviatingWithTildeInPath];
    }
    if (isDir) {
      variant = [variant stringByAppendingFormat:@"/"];
      // commandLength++;
    }
    if ([commandVariants count] == 1) {
      [commandField setStringValue:variant];
      [commandField deselectText];
    }
    else {
      NSText     *fieldEditor = [window fieldEditor:NO forObject:commandField];
      NSUInteger selLength = [variant length] - commandLength;
      [commandField setStringValue:variant];
      [fieldEditor setSelectedRange:NSMakeRange(commandLength, selLength)];
    }
  }
  else {
    ASSIGN(completionSource, historyList);
    [completionList reloadColumn:0];
    [completionList setTitle:@"History" ofColumn:0];
    completionIndex = -1;
  }
  [self updateButtonsState];
}

- (void)updateButtonsState
{
  NXTFileManager *fm = [NXTFileManager defaultManager];
  BOOL           isDir;
  NSString       *text;
  BOOL           isEnabled = YES;

  text = [fm absolutePathForPath:[commandField stringValue]];
  if (text == nil) {
    if (completionIndex < 0) {
      isEnabled = NO;
    }
  }
  else if ([text isEqualToString:@""] || [text characterAtIndex:0] == ' ') {
    isEnabled = NO;
  }
  else if (([text characterAtIndex:0] == '/') &&
           (![fm fileExistsAtPath:text isDirectory:&isDir] || isDir)) {
    isEnabled = NO;
  }
  
  [runInTerminal setEnabled:isEnabled];
  [runButton setEnabled:isEnabled];
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

  if ([text length] == 0) {
    ASSIGN(completionSource, historyList);
    [completionList reloadColumn:0];
    [completionList setTitle:@"History" ofColumn:0];
    completionIndex = -1;
  }
  // else if ([text characterAtIndex:[text length]-1] == '/' &&
  //          [text length] > [savedCommand length]) {
  //   [self makeCompletion];
  // }

  // [savedCommand setString:text];
  [self updateButtonsState];
}
- (void)commandFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSDownArrowFunctionKey:
    // NSLog(@"WMCommandField key: Down");
    completionIndex++;
    if (completionIndex >= [completionSource count]) {
      completionIndex--;
    }
    [commandField setStringValue:[completionSource objectAtIndex:completionIndex]];
    [completionList selectRow:completionIndex inColumn:0];
    [self updateButtonsState];
    break;
  case NSUpArrowFunctionKey:
    // NSLog(@"WMCommandField key: Up");
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
    /*  case NSDeleteFunctionKey:
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
        commandVariants = [self completionForCommand:[commandField stringValue]];
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
    break; */
  case NSTabCharacter:
    [[window fieldEditor:NO forObject:commandField]
        setSelectedRange:NSMakeRange([[commandField stringValue] length], 0)];
    break;
  case 27: // Escape
    [self makeCompletion];
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

  if ([completionSource count] == 1)
    return;

  for (NSString *variant in completionSource) {
    [matrix addRow];
    cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
    [cell setLeaf:YES];
    if (completionSource != historyList) {
      [cell setTitle:[variant lastPathComponent]];
      [cell setRepresentedObject:variant];
    }
    else {
      [cell setTitle:variant];
    }
    [cell setRefusesFirstResponder:YES];
  }
}

- (void)listItemClicked:(id)sender
{
  NSInteger selRow;
  NSString  *title;
  id        object;

  if (sender != completionList)
    return;
  
  completionIndex = [sender selectedRowInColumn:0];
  title = [[completionList selectedCellInColumn:0] representedObject];
  if (title == nil) {
    title = [completionSource objectAtIndex:completionIndex];
  }
  [commandField setStringValue:title];
  [self updateButtonsState];
  
  [window makeFirstResponder:commandField];
}

@end
