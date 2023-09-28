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

@interface Console : NSObject
{
  id window, text;

  NSString *consoleFile;
  NSFileHandle *fh;
  NSString *savedString;
  NSTimer *timer;

  BOOL isActive;
}

- (NSWindow *)window;
- (void)activate;
- (void)deactivate;

/** Reads data from the console file handle and appends it to the
    console display. This method is invoked automatically by a timer
    every 0.1 seconds. */
- (void)readConsoleFile;

@end
