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

#import "Console.h"

@implementation Console

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
  // Wait for changes to take effect: avoid flickering of 
  // window on creation.
  // [[NSRunLoop currentRunLoop] 
  //       runMode:NSDefaultRunLoopMode 
  //    beforeDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
}

- (void)dealloc
{
  NSLog(@"Console: dealloc");

  [self deactivate];

  [savedString release];
  [consoleFile release];
  [window release];

  [super dealloc];
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
          NSRunAlertPanel(_(@"Workspace"),
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

@end
