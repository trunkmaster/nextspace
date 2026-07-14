/*
**  GDBWrapper
**
**  Copyright (c) 2008-2021
**
**  Author: Gregory Casamento <greg.casamento@gmail.com>
**          Riccardo Mottola <rm@gnu.org>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "PCDebuggerWrapperProtocol.h"

typedef enum PCDebuggerOutputType_enum {
  PCDBNotFoundRecord = 0,
  PCDBPromptRecord, 
  PCDBResultRecord,
  PCDBConsoleStreamRecord,
  PCDBTargetStreamRecord,
  PCDBLogStreamRecord,
  PCDBAsyncStatusRecord,
  PCDBAsyncExecRecord,
  PCDBAsyncNotifyRecord,
  PCDBBreakpointRecord,
  PCDBFrameRecord,
  PCDBThreadRecord,
  PCDBAdaExceptionRecord,
  PCDBEmptyRecord
} PCDebuggerOutputTypes;

@interface GDBWrapper : NSObject <PCDebuggerWrapperProtocol>
{
  NSString *debuggerPath;
  PCDebugger *debugger;
  NSTextView *tView;
  NSMutableString *singleInputLine;
  NSTask *task;
  NSFileHandle *stdinHandle;
  NSFileHandle *stdoutHandle;
  NSFileHandle *errorHandle;

  NSColor *userInputColor;
  NSColor *debuggerColor;
  NSColor *messageColor;
  NSColor *errorColor;
  NSColor *promptColor;
  NSFont  *font;

  BOOL debuggerStarted;
  float          debuggerVersion;
  NSDictionary *lastMIDictionary;
  NSString     *lastMIString;
}

- (float) debuggerVersion;
- (void) setDebuggerVersion:(float)ver;

- (void)logStdOut:(NSNotification *)aNotif;

- (void)logErrOut:(NSNotification *)aNotif;

- (void) taskDidTerminate: (NSNotification *)notif;

- (NSString *) startMessage;

- (NSString *) stopMessage;

- (void) putChar:(unichar)ch;

// methods for a look-ahead recursive parser which attempts to parse
// gdb's output to a Dictionary/Array structure representable in a plist

// LAR parser - single string element (-> NSString value)
- (NSString *) parseString: (NSScanner *)scanner;

// LAR parser - array element (-> NSArray value)
- (NSArray *) parseArray: (NSScanner *)scanner;

// LAR parser - key-value list (-> NSDictionary value)
- (NSDictionary *) parseKeyValue: (NSScanner *)scanner;

// parses a single line from the debugger or the machine interface
// it splits out the type then recurses in the LAR methods
- (PCDebuggerOutputTypes) parseStringLine: (NSString *)stringInput;

@end
