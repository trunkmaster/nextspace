/*
**  PCDebuggerWrapperProtocol.h
**
**  Copyright (c) 2016-2021
**
**  Author: Riccardo Mottola <rm@gnu.org>
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

#import <Foundation/NSObject.h>

@class NSColor;
@class NSTextView;
@class NSArray;
@class NSString;
@class PCDebugger;

@protocol PCDebuggerWrapperProtocol <NSObject>

- (void)setFont:(NSFont *)font;

- (NSColor *)userInputColor;
- (NSColor *)debuggerColor;
- (NSColor *)messageColor;
- (NSColor *)errorColor;

- (NSTextView *)textView;
- (void)setTextView: (NSTextView *)tv;
- (PCDebugger *)debugger;
- (void)setDebugger:(PCDebugger *)dbg;

- (NSString *)debuggerPath;
- (void)setDebuggerPath:(NSString *)path;

- (BOOL)debuggerStarted;

- (void) runProgram: (NSString *)path
 inCurrentDirectory: (NSString *)directory
   logStandardError: (BOOL)logError;

- (void)logString:(NSString *)str
          newLine:(BOOL)newLine
        withColor:(NSColor *)color;

- (void) setBreakpoints:(NSArray *)breakpoints;

- (void) terminate;

- (void) interrupt;

- (void) putString: (NSString *)string;

- (void) keyDown: (NSEvent*)theEvent;

- (void) debuggerSetup;

@end
