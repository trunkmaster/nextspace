/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
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

#import <Foundation/NSProcessInfo.h>
#import "Application.h"

@implementation	NSIconWindow

- (BOOL)canBecomeMainWindow
{
  return NO;
}

- (BOOL)canBecomeKeyWindow
{
  return NO;
}

- (BOOL)worksWhenModal
{
  return YES;
}

- (void)orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)otherWin
{
  // Do nothing preventing window from appearing
}

- (void)_initDefaults
{
  [super _initDefaults];
  // Set the title of the window to the process name. Even as the
  // window shows no title bar, the window manager may show it.
  [self setTitle:[[NSProcessInfo processInfo] processName]];
  [self setExcludedFromWindowsMenu:YES];
  [self setReleasedWhenClosed:NO];
  _windowLevel = NSDockWindowLevel;
}

@end

@implementation	LoginApplication

- _appIconInit
{
  // Do nothing
  return self;
}

@end

