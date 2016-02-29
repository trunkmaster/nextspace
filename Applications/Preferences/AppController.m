/* 
   Project: Preferences

   Copyright (C) 2006 Free Software Foundation

   Author: Serg Stoyan

   Created: 2006-06-05 01:22:56 +0300 by stoyan
   
   Application Controller

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

#import <NXSystem/NXScreen.h>

#import "AppController.h"
#import "ClockView.h"

static NSUserDefaults *defaults = nil;

@implementation AppController

- (id)init
{
  if (!(self = [super init]))
    {
      return nil;
    }

  if (!defaults)
    {
      defaults = [NSUserDefaults standardUserDefaults];
    }

  prefsController = nil;

  return self;
}

// - (void)dealloc
// {
//   [super dealloc];
// }

- (void)awakeFromNib
{
  if (clockView)
    return;
  
  clockView = [ClockView new];
  [[NSApp iconWindow] setContentView:clockView];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notify
{
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif
{
  [NSApp hide:self];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotif
{
  [prefsController release];
}

- (void)applicationDidBecomeActive:(NSNotification*)aNotification
{
  // NSLog(@"Application became active!");
  // if (prefsController)
  //   {
  //     [[prefsController window] makeKeyWindow];
  //   }
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName
{
  return YES;
}

- (void)showPreferencesWindow
{
  if (prefsController == nil)
    {
      prefsController = [[PrefsController alloc] init];
      if ([NSBundle loadNibNamed:@"PrefsWindow" owner:self] == NO)
        {
          NSLog(@"Error loading NIB PrefsWindow");
          return;
        }
    }

  [NSApp activateIgnoringOtherApps:YES];
  [[prefsController window] makeKeyAndOrderFront:self];
}

@end
