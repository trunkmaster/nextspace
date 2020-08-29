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

  Defaults can provide access to user defaults file (~/L/P/Terminal.plist) and 
  arbitrary file.
  Access to NSUserDefaults file:
  	[Defaults shared];
  Acess to arbitrary file:
  	[[Defaults alloc] initWithFile:"~/path/to/filename"];

*/

#import <Foundation/NSString.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSGraphics.h>

#import <DesktopKit/NXTAlert.h>

#import "Defaults.h"

@implementation Defaults (Sessions)
+ (NSString *)sessionsDirectory
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *path;
  BOOL          isDir;
  
  // Assume that ~/Library already exists
  path = [NSString stringWithFormat:@"%@/Library/Terminal", NSHomeDirectory()];

  if ([fm fileExistsAtPath:path isDirectory:&isDir])
    {
      if (!isDir)
        {
          NXTRunAlertPanel(@"Session Directory",
                          @"%@ exists and not a directory.\n"
                          "Check your home directory layout",
                          @"Ok", nil, nil, path);
          return nil;
        }
    }
  else
    {
      if ([fm createDirectoryAtPath:path attributes:nil] == NO)
        {
          NXTRunAlertPanel(@"Session Directory",
                          @"Error occured while creating directory %@.\n"
                          "Check your home directory layout",
                          @"Ok", nil, nil, path);
          return nil;
        }
    }

  return path;
}
@end

//----------------------------------------------------------------------------
// Startup
//---
NSString *StartupActionKey = @"StartupAction";
NSString *StartupFileKey = @"StartupFile";
NSString *HideOnAutolaunchKey = @"HideOnAutolaunch";
//---
@implementation Defaults (Startup)
- (StartupAction)startupAction
{
  if ([self integerForKey:StartupActionKey] == -1)
    [self setStartupAction:OnStartCreateShell];
  
  return [self integerForKey:StartupActionKey];
}
- (void)setStartupAction:(StartupAction)action
{
  [self setInteger:action forKey:StartupActionKey];
}
- (NSString *)startupFile
{
  return [self objectForKey:StartupFileKey];
}
- (void)setStartupFile:(NSString *)path
{
  [self setObject:path forKey:StartupFileKey];
}
- (BOOL)hideOnAutolaunch
{
  return [self boolForKey:HideOnAutolaunchKey];
}
- (void)setHideOnAutolaunch:(BOOL)yn
{
  [self setBool:yn forKey:HideOnAutolaunchKey];
}
@end
