/*
**  PCDebugger
**
**  Copyright (c) 2008-2021
**
**  Author: Gregory Casamento <greg_casamento@yahoo.com>
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

#import <stdio.h>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#import <Protocols/CodeDebugger.h>
#import "PCDebuggerWrapperProtocol.h"

extern NSString *PCBreakTypeKey;
extern NSString *PCBreakTypeByLine;
extern NSString *PCBreakTypeMethod;
extern NSString *PCBreakMethod;
extern NSString *PCBreakFilename;
extern NSString *PCBreakLineNumber;

extern NSString *PCDBDebuggerStartedNotification;

@interface PCDebugger : NSObject <CodeDebugger>
{
  id             debuggerView;
  id             debuggerWindow;
  id             statusField;
  NSString       *executablePath;
  int            subProcessId;
  NSDictionary   *lastInfoParsed;
  NSString       *lastFileNameParsed;
  NSUInteger     lastLineNumberParsed;
  NSMutableArray *breakpoints;
  id <PCDebuggerWrapperProtocol> debuggerWrapper;
}

- (id <PCDebuggerWrapperProtocol>)debuggerWrapper;
- (void) setStatus: (NSString *) status;
- (NSString *) status;
- (NSString *)executablePath;
- (void)setExecutablePath:(NSString *)p;
- (void) interrupt;
- (int) subProcessId;
- (void) setSubProcessId:(int)pid;
- (NSDictionary *)lastInfoParsed;
- (void)setSetInfoParsed: (NSDictionary *)dict;
- (NSString *)lastFileNameParsed;
- (void) setLastFileNameParsed: (NSString *)fname;
- (NSUInteger)lastLineNumberParsed;
- (void)setLastLineNumberParsed: (NSUInteger)num;
- (void)updateEditor;

@end
