/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2008-2016 Free Software Foundation

   Authors: Gregory Casamento

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _CodeDebugger_h_
#define _CodeDebugger_h_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@protocol CodeDebugger <NSObject>

// ===========================================================================
// ==== Initialization
// ===========================================================================

- (void)debugExecutableAtPath:(NSString *)filePath withDebugger: (NSString *)debuggerPath;
- (void)show;

// ===========================================================================
// ==== Accessor methods
// ===========================================================================

- (NSWindow *)debuggerWindow;
- (void)setDebuggerWindow: (NSWindow *)window;
- (NSView *)debuggerView;
- (void)setDebuggerView: (id)view;
- (NSString *)executablePath;
- (void)setExecutablePath:(NSString *)path;

// ===========================================================================
// ==== Accessor methods
// ===========================================================================

- (void) startDebugger;

@end

#endif
