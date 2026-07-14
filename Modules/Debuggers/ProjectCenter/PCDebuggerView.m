/*
**  PCDebuggerView
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

#import "PCDebuggerView.h"
#import "PCDebugger.h"

#import <ProjectCenter/PCProject.h>
#import <Foundation/NSScanner.h>

#import <unistd.h>
#import <signal.h>

#ifndef NOTIFICATION_CENTER
#define NOTIFICATION_CENTER [NSNotificationCenter defaultCenter]
#endif

@implementation PCDebuggerView

-(void)setDebugger:(PCDebugger *)theDebugger
{
  debugger = theDebugger;
}


- (void)setFont:(NSFont *)aFont
{
  [[debugger debuggerWrapper] setFont:aFont];
}

/**
 * Log string to the view.
 */
- (void) logString:(NSString *)str
	   newLine:(BOOL)newLine
{
  [[debugger debuggerWrapper] logString: str newLine: newLine withColor:[[debugger debuggerWrapper] debuggerColor]];
}


- (void) terminate
{
  [[debugger debuggerWrapper] terminate];
}

- (void) mouseDown: (NSEvent *)event
{
  // do nothing...
}

/**
 * Start the program.
 */
- (void) runProgram: (NSString *)path
 inCurrentDirectory: (NSString *)directory
   logStandardError: (BOOL)logError
{
  [[debugger debuggerWrapper] runProgram: path
		      inCurrentDirectory: directory
			logStandardError: logError];
}

- (void) putString: (NSString *)string
{
  NSAttributedString* attr = [[NSAttributedString alloc] initWithString:string];
  [[self textStorage] appendAttributedString:attr];
  [self scrollRangeToVisible:NSMakeRange([[self string] length], 0)];
  [[debugger debuggerWrapper] putString:string];
}

- (void) keyDown: (NSEvent*)theEvent
{
  [[debugger debuggerWrapper] keyDown:theEvent];
}

@end
