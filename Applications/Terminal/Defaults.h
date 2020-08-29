/*
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <Foundation/Foundation.h>

#import <TerminalKit/TerminalKit.h>

@interface Defaults (Sessions)

+ (NSString *)sessionsDirectory;

@end

//----------------------------------------------------------------------------
// Startup
//---
extern NSString *StartupActionKey;
extern NSString	*StartupFileKey;
extern NSString	*HideOnAutolaunchKey;

typedef enum {
  OnStartDoNothing = 1,
  OnStartOpenFile = 2,
  OnStartCreateShell = 3
} StartupAction;

@interface Defaults (Startup)
- (StartupAction)startupAction;
- (void)setStartupAction:(StartupAction)action;
- (NSString *)startupFile;
- (void)setStartupFile:(NSString *)filePath;
- (BOOL)hideOnAutolaunch;
- (void)setHideOnAutolaunch:(BOOL)yn;
@end
