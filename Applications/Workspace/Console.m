/* -*- mode: objc -*- */
//
// Project: Workspace
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

#import <Foundation/NSDistributedNotificationCenter.h>
#import <DesktopKit/NXTAlert.h>
#import "Console.h"

#define DNC [NSDistributedNotificationCenter defaultCenter]

@implementation Console

- (void)dealloc
{
  NSLog(@"Console: dealloc");

  [DNC removeObserver:self];

  [self deactivate];

  [savedString release];
  [consoleFile release];
  [window release];

  [super dealloc];
}

- init
{
  [super init];

  consoleFile = [NSTemporaryDirectory()
                    stringByAppendingPathComponent:@"console.log"];
  [consoleFile retain];
  ASSIGN(savedString, @"");
  
  fh = nil;
  isActive = NO;

  return self;
}

- (void)awakeFromNib
{
  [text setFont:[NSFont userFixedPitchFontOfSize:0]];
  [text setString:savedString];
  DESTROY(savedString);

  [window setFrameAutosaveName:@"Console"];
  [DNC addObserver:self
          selector:@selector(fontDidChange:)
              name:@"NXTSystemFontPreferencesDidChangeNotification"
            object:@"Preferences"];
}

- (NSWindow *)window
{
  return window;
}

- (void)activate
{
  if (window == nil)
    {
      [NSBundle loadNibNamed:@"Console" owner:self];
    }

  if (fh == nil)
    {
      ASSIGN(fh, [NSFileHandle fileHandleForReadingAtPath:consoleFile]);
      if (fh == nil)
        {
          NXTRunAlertPanel(_(@"Workspace"),
                           _(@"Couldn't open console file %@"), nil, nil, nil,
                           consoleFile);
          return;
        }

      timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                               target:self
                                             selector:@selector(readConsoleFile)
                                             userInfo:nil
                                              repeats:YES];
      isActive = YES;
    }
  
  [window makeKeyAndOrderFront:nil];
  [text scrollPoint:NSMakePoint(0, [text frame].size.height)];
}

- (void)deactivate
{
  if (isActive == NO)
    return;

  [timer invalidate];
  
  [fh closeFile];
  [fh release];
  fh = nil;
  
  [window close];

  isActive = NO;
}

- (void)readConsoleFile
{
  NSData         *data = [fh readDataToEndOfFile];
  NSString       *string;
  NSUserDefaults *df;
  unsigned       consoleHistory;

  if ([data length] == 0)
    {
      return;
    }

  df = [NSUserDefaults standardUserDefaults];
  if ([df objectForKey: @"ConsoleHistoryLength"])
    {
      consoleHistory = [df integerForKey: @"ConsoleHistoryLength"];
    }
  else
    {
      consoleHistory = 64 * 1024;
    }

  string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
    autorelease];

  if (text != nil)
    {
      [text replaceCharactersInRange:NSMakeRange([[text string] length], 0)
			  withString:string];
      if ([[text string] length] > consoleHistory)
        {
          [text replaceCharactersInRange:
                  NSMakeRange(0, [[text string] length] - consoleHistory)
                              withString: @""];
        }
      [text scrollRangeToVisible:NSMakeRange([[text string] length], 0)];
    }
  else
    {
      ASSIGN(savedString, [savedString stringByAppendingString: string]);
      if ([savedString length] > consoleHistory)
	{
	  ASSIGN(savedString,[savedString
		 substringFromIndex:[savedString length] -
		 consoleHistory]);
	}
    }
}

// Notifications
- (void)fontDidChange:(NSNotification *)aNotif
{
  NSFont *font;
  NSUserDefaults *defaults;
  NSDictionary *globalDomain;

  defaults = [NSUserDefaults standardUserDefaults];
  [defaults synchronize];
  globalDomain = [defaults persistentDomainForName:NSGlobalDomain];

  font = [NSFont
           fontWithName:[globalDomain objectForKey:@"NSUserFixedPitchFont"]
                   size:[[globalDomain objectForKey:@"NSUserFixedPitchFontSize"] floatValue]];
  [text setFont:font];
}

@end
