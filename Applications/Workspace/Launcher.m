/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014-2021 Sergii Stoian
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
#import <SystemKit/OSEFileManager.h>
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
  NSText *fieldEditor = [_window fieldEditor:NO forObject:self];

  [fieldEditor setSelectedRange:NSMakeRange([fieldString length], 0)];
}
@end

@implementation Launcher

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"Launcher: dealloc");

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
  searchPaths = [[NSArray alloc] initWithArray:[envPath componentsSeparatedByString:@":"]];
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
  } else {
    NSString *fieldValue = [commandField stringValue];
    [completionList reloadColumn:0];
    [completionList setTitle:@"History" ofColumn:0];
    if (fieldValue.length > 0) {
      [completionList selectRow:[historyList indexOfObject:fieldValue] inColumn:0];
    }
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
  NSString *commandLine = [commandField stringValue];
  NSString *commandPath = nil;
  NSMutableArray *commandArgs = nil;
  NSTask *commandTask = nil;

  if (!commandLine || [commandLine length] == 0 || [commandLine isEqualToString:@""]) {
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
        } @catch (NSException *exception) {
          NXTRunAlertPanel(@"Run Command", @"Run command failed with exception: \'%@\'", @"Close",
                           nil, nil, [exception reason]);
        } @finally {
          [window close];
        }
      }
    }
    return;
  }

  commandArgs = [NSMutableArray arrayWithArray:[commandLine componentsSeparatedByString:@" "]];
  commandPath = [commandArgs objectAtIndex:0];
  [commandArgs removeObjectAtIndex:0];

  NSDebugLLog(@"Launcher", @"Running command: %@ with args %@", commandPath, commandArgs);

  commandTask = [NSTask new];
  [commandTask setArguments:commandArgs];
  [commandTask setLaunchPath:commandPath];

  @try {
    [commandTask launch];
    [historyList insertObject:[commandField stringValue] atIndex:0];
    [self saveHistory];
  } @catch (NSException *exception) {
    NXTRunAlertPanel(@"Run Command", @"Run command failed with exception: \'%@\'", @"Close", nil,
                     nil, [exception reason]);
    [window makeKeyAndOrderFront:self];
    return;
  }
  [window close];
}

- (void)runInTerminal:(id)sender
{
  if (sender != runInTerminal)
    return;

  isRunInTerminal = [sender state];
}

// --- History file manipulations

#define LIB_DIR @"Library/Workspace"
#define WM_LIB_DIR @"Library/WindowMaker"

- (void)initHistory
{
  NSString *libPath;
  NSString *histPath;
  NSString *wmHistPath;
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDir;

  libPath = [NSHomeDirectory() stringByAppendingPathComponent:LIB_DIR];
  histPath = [libPath stringByAppendingPathComponent:@"LauncherHistory"];
  wmHistPath = [NSHomeDirectory() stringByAppendingFormat:@"/%@/History", WM_LIB_DIR];

  // Create ~/Library/Workspace directory if not exsist
  if ([fm fileExistsAtPath:libPath isDirectory:&isDir] == NO) {
    if ([fm createDirectoryAtPath:libPath attributes:nil] == NO) {
      NSDebugLLog(@"Launcher", @"Failed to create library directory %@!", libPath);
    }
  } else if ([fm fileExistsAtPath:histPath isDirectory:&isDir] != NO && isDir == NO) {
    historyList = [[NSMutableArray alloc] initWithContentsOfFile:histPath];
  }

  // Load WindowMaker history
  if (historyList == nil) {
    historyList = [[NSMutableArray alloc] initWithContentsOfFile:wmHistPath];
    if (historyList == nil) {
      NSDebugLLog(@"Launcher", @"Failed to load history file %@", wmHistPath);
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

  historyPath = [NSHomeDirectory() stringByAppendingFormat:@"/%@/LauncherHistory", LIB_DIR];
  [historyList writeToFile:historyPath atomically:YES];
}

// --- Utility

- (NSArray *)completionForCommand:(NSString *)command
{
  NSMutableArray *variants = [[NSMutableArray alloc] init];
  OSEFileManager *fm = [OSEFileManager defaultManager];
  NSString *absPath;

  if (!command || [command length] == 0 || [command isEqualToString:@""]) {
    return variants;
  }

  // NSDebugLLog(@"Launcher", @"completionFor: %@ - %@", command, historyList);

  // Go through the history first
  // for (NSString *compElement in historyList) {
  //   if ([compElement rangeOfString:command].location == 0) {
  //     [variants addObject:compElement];
  //   }
  // }

  absPath = [fm absolutePathForPath:command];
  // NSDebugLLog(@"Launcher", @"Absolute command: %@ - %@", command, absPath);
  if (absPath) {  // Absolute path exists
    NSArray *completion = [fm completionForPath:absPath isAbsolute:YES];
    for (NSString *path in completion) {
      if ([fm isExecutableFileAtPath:path]) {
        [variants addObject:path];
      }
    }
  } else {  // No absolute path - go through the $PATH
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
  NSString *command = [commandField stringValue];
  NSUInteger commandLength = [command length];
  NSString *variant;
  NSUInteger variantsCount;

  // NSDebugLLog(@"Launcher", @">>> Make completion <<<");

  if (commandVariants)
    [commandVariants release];
  commandVariants = [self completionForCommand:command];
  variantsCount = [commandVariants count];

  if (variantsCount > 0) {
    NSDebugLLog(@"Launcher", @"Completions: %lu source: %@ index: %li", variantsCount,
                (completionSource == historyList ? @"History" : @"Completion"), completionIndex);
    // Completion list handling
    if (variantsCount > 1) {
      completionIndex = (completionSource == historyList) ? -1 : completionIndex + 1;
      ASSIGN(completionSource, commandVariants);
    } else {
      completionIndex = 0;
      ASSIGN(completionSource, commandVariants);
    }
    [self reloadCompletionList];

    // Extract and process current variant
    if (completionIndex < 0 && variantsCount == 1) {
      variant = commandVariants[0];
    } else if (completionIndex >= 0) {
      variant = commandVariants[completionIndex];
    } else {
      variant = [command stringByExpandingTildeInPath];
    }
    if ([[OSEFileManager defaultManager] directoryExistsAtPath:variant] &&
        [variant characterAtIndex:[variant length] - 1] != '/') {
      if ([command characterAtIndex:0] == '~') {
        variant = [variant stringByAbbreviatingWithTildeInPath];
      }
      variant = [variant stringByAppendingFormat:@"/"];
    } else if ([command characterAtIndex:0] == '~') {
      variant = [variant stringByAbbreviatingWithTildeInPath];
    }
    [commandField setStringValue:variant];

    // Process text field changes
    if (completionIndex < 0 || variantsCount == 1) {
      [commandField deselectText];
      [savedCommand setString:variant];
    } else {
      NSText *fieldEditor = [window fieldEditor:NO forObject:commandField];
      NSRange range;
      commandLength = [savedCommand length];
      range = NSMakeRange(commandLength, ([variant length] - commandLength));
      [fieldEditor setSelectedRange:range];
    }
  } else {
    completionIndex = -1;
    ASSIGN(completionSource, historyList);
    [self reloadCompletionList];
  }
  [self updateButtonsState];
}

- (void)updateButtonsState
{
  OSEFileManager *fm = [OSEFileManager defaultManager];
  BOOL isDir;
  NSString *text;
  BOOL isEnabled = YES;

  text = [fm absolutePathForPath:[commandField stringValue]];
  if (text == nil) {
    if (completionIndex < 0) {
      isEnabled = NO;
    }
  } else if ([text isEqualToString:@""] || [text characterAtIndex:0] == ' ') {
    isEnabled = NO;
  } else if (([text characterAtIndex:0] == '/') &&
             (![fm fileExistsAtPath:text isDirectory:&isDir] || isDir)) {
    isEnabled = NO;
  }

  [runInTerminal setEnabled:isEnabled];
  [runButton setEnabled:isEnabled];
}

// --- Command text field delegate

- (void)commandFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch (c) {
    case 13:  // Return/Enter key
    case 3:   // Enter key (numpad)
      [self runCommand:self];
      break;
    case NSDownArrowFunctionKey:
      // NSDebugLLog(@"Launcher", @"WMCommandField key: Down");
      completionIndex++;
      if (completionIndex >= [completionSource count]) {
        completionIndex--;
      }
      [commandField setStringValue:[completionSource objectAtIndex:completionIndex]];
      [completionList selectRow:completionIndex inColumn:0];
      [self updateButtonsState];
      break;
    case NSUpArrowFunctionKey:
      // NSDebugLLog(@"Launcher", @"WMCommandField key: Up");
      if (completionIndex > -1)
        completionIndex--;
      if (completionIndex >= 0) {
        [commandField setStringValue:[completionSource objectAtIndex:completionIndex]];
        [completionList selectRow:completionIndex inColumn:0];
      } else {
        [commandField setStringValue:savedCommand];
        [commandField deselectText];
        [completionList reloadColumn:0];
      }
      [self updateButtonsState];
      break;
    case NSTabCharacter:
      [[window fieldEditor:NO forObject:commandField]
          setSelectedRange:NSMakeRange([[commandField stringValue] length], 0)];
      break;
    case 27:  // Escape
      [self makeCompletion];
      break;
    case NSLeftArrowFunctionKey:
    case NSRightArrowFunctionKey:
    case NSHomeFunctionKey:
    case NSBeginFunctionKey:
    case NSEndFunctionKey:
      [savedCommand setString:[commandField stringValue]];
      break;
    default:
      [savedCommand setString:[commandField stringValue]];
      if ([savedCommand length] < 2) {
        ASSIGN(completionSource, historyList);
      }
      completionIndex = -1;
      [self reloadCompletionList];
      break;
  }
  // NSDebugLLog(@"Launcher", @"WMCommandField key: %i", c);
}
// --- Command and History browser delegate
- (void)browser:(NSBrowser *)sender
    createRowsForColumn:(NSInteger)column
               inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;

  if (sender != completionList || completionList == nil)
    return;

  for (NSString *variant in completionSource) {
    [matrix addRow];
    cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
    [cell setLeaf:YES];
    if (completionSource != historyList) {
      [cell setTitle:[variant lastPathComponent]];
      [cell setRepresentedObject:variant];
    } else {
      [cell setTitle:variant];
    }
    [cell setRefusesFirstResponder:YES];
  }
}

- (void)listItemClicked:(id)sender
{
  NSInteger selRow;
  NSString *absPath;
  NSString *fieldValue = [commandField stringValue];
  id object;

  if (sender != completionList)
    return;

  completionIndex = [sender selectedRowInColumn:0];
  absPath = [[completionList selectedCellInColumn:0] representedObject];
  if (absPath == nil) {
    absPath = [completionSource objectAtIndex:completionIndex];
  }
  if (fieldValue && fieldValue.length > 0 && [fieldValue characterAtIndex:0] == '~') {
    absPath = [absPath stringByAbbreviatingWithTildeInPath];
  }

  [commandField setStringValue:absPath];
  [self updateButtonsState];

  [window makeFirstResponder:commandField];
}

- (void)reloadCompletionList
{
  [completionList reloadColumn:0];

  if (completionSource == historyList) {
    [completionList setTitle:@"History" ofColumn:0];
  } else {
    [completionList setTitle:@"Completion" ofColumn:0];
  }

  if (completionIndex >= 0) {
    [completionList selectRow:completionIndex inColumn:0];
  }
}

@end
