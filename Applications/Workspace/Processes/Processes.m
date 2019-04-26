/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2018 Sergii Stoian
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

#import <sys/types.h>
#import <signal.h>
#import <AppKit/NSAlert.h>

#import <NXAppKit/NXUtilities.h>

#import <Operations/ProcessManager.h>
#import <Operations/BGOperation.h>
#import "BGProcess.h"
#import "Processes.h"

@implementation Processes

static Processes *shared = nil;

+ shared
{
  if (shared == nil)
    {
      shared = [self new];
    }
  return shared;
}

- initWithManager:(ProcessManager *)procman
{
  // Only one instance of Processes must exist.
  if (shared != nil)
    return shared;
  
  self = [super init];
  shared = self;

  ASSIGN(manager, procman);
  displayedFop = -1;
  
  if ([NSBundle loadNibNamed:@"Processes" owner:self] == NO)
    {
      NSLog(@"Processes: failed to load NIB");
      return nil;
    }
      
  [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(listDidChangeSelection:)
               name:NSTableViewSelectionDidChangeNotification
             object:nil];
  
  [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(operationDidChangeState:)
               name:WMOperationDidChangeStateNotification
             object:nil];

  return self;
}

- (void)awakeFromNib
{
  [procWindow setDelegate:self];
  [procPopup setRefusesFirstResponder:YES];

  // Applications
  RETAIN(appBox);
  [appBox removeFromSuperview];
  DESTROY(appBogusWindow);

  [appList setHeaderView:nil];
  [appList setCornerView:nil];
  [appList setDoubleAction:@selector(activateApp:)];

  [appKillBtn setEnabled:NO];

  // Background processes
  RETAIN(backBox);
  [backBox removeFromSuperview];
  RETAIN(backNoFopLabel);
  [backNoFopLabel removeFromSuperview];
  [backFopBox setContentView:backNoFopLabel];
  DESTROY(backBogusWindow);

  [backList setHeaderView:nil];
  [backList setCornerView:nil];

  // Set active view to 'Applications'
  [procBox setContentView:appBox];
  [appList reloadData];
  [self showApp:nil];

  [procWindow setFrameAutosaveName:@"Processes"];
  // Wait for changes to take effect: avoid flickering of 
  // window on creation.
  // [[NSRunLoop currentRunLoop] 
  //       runMode:NSDefaultRunLoopMode 
  //    beforeDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
}

- (void)dealloc
{
  NSLog(@"Processes: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [manager release];
  
  if (procWindow && [procWindow isVisible]) [procWindow close];
  [procWindow release];

  shared = nil;

  [super dealloc];
}

- (NSWindow *)window
{
  return procWindow;
}

- (void)show
{
  [procWindow makeKeyAndOrderFront:nil];
}

- (void)setView:(id)sender
{
  if ([sender isKindOfClass:[BGOperation class]])
    {
      [procPopup selectItemAtIndex:1];
    }
  
  switch ([procPopup indexOfSelectedItem])
    {
    case 0: 
      [procBox setContentView:appBox];
      [procWindow makeFirstResponder:appList];
      break;
    case 1:
      [procBox setContentView:backBox];
      [self showOperation:sender];
      [self windowDidResize:nil]; // adjust table columns
      [procWindow makeFirstResponder:backList];
      break;
    }
}


// NSTable delegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  if (aTableView == appList)
    {
      return [[manager applications] count];
    }
  else
    {
      return [[manager operations] count];
    }
}

- (id)          tableView:(NSTableView *)aTableView 
objectValueForTableColumn:(NSTableColumn *)aTableColumn 
	 	      row:(NSInteger)rowIndex
{
  NSString *identifier = [aTableColumn identifier];

  //  NSLog(@"tableView:objectValueForTableColumn:%@row:%i",
  //  identifier, rowIndex);

  if (aTableView == appList)
    {
      NSDictionary *app = [[manager applications] objectAtIndex:rowIndex];

      if ([identifier isEqualToString:@"AppName"])
	{
	  return [app objectForKey:@"NSApplicationName"];
	}
      else
	{
	  if ([app objectForKey:@"StartingUp"] == nil)
	    {
	      return _(@"Running");
	    }
	  else
	    {
	      return _(@"Starting up");
	    }
	}
    }
  else
    {
      NSArray     *opList = [manager operations];
      BGOperation *bgop;

      if ([opList count] <= 0)
	{
	  return nil;
	}

      bgop = [opList objectAtIndex:rowIndex];

      if ([identifier isEqualToString:@"OperationName"])
	{
          return NXShortenString([bgop titleString],
                                 [aTableColumn width]-4,
                                 [[aTableColumn dataCell] font], 
                                 NXPathElement, NXDotsAtLeft);
	}
      else if ([identifier isEqualToString:@"OperationState"])
	{
          return [bgop stateString];
	}
      else
	{
          return [[bgop userInterface] miniIcon];
	}
    }
}

- (void)windowDidResize:(NSNotification*)aNotification
{
  NSTableColumn *tCol;
  NSRect        rect;
  
  [backList sizeLastColumnToFit];

  rect = [backList frame];

  tCol = [backList tableColumnWithIdentifier:@"OperationState"];
  [[tCol dataCell] setAlignment:NSRightTextAlignment];
  [tCol setWidth:(rect.size.width-21) * 0.2];

  tCol = [backList tableColumnWithIdentifier:@"OperationName"];
  [tCol setWidth:(rect.size.width-21) * 0.8];
}

- (void)listDidChangeSelection:(NSNotification *)aNotification
{
  id sender = [aNotification object];

  if (sender == appList)
    {
      [self showApp:appList];
    }
  else if (sender == backList)
    {
      [self showOperation:backList];
    }
}

@end


@implementation Processes (Applications)

// 'Kill' button clicked
- (void)kill:(id)sender
{
  NSDictionary *appInfo;

  appInfo = [[manager applications] objectAtIndex:[appList selectedRow]];
  if (NSRunAlertPanel(_(@"Really kill?"),
		      _(@"Really kill application %@?"), 
		      _(@"Cancel"), _(@"Kill"), nil,
		      [appInfo objectForKey: @"NSApplicationName"]) 
      != NSAlertDefaultReturn)
    {
      NSString       *pidListString;
      NSMutableArray *pidList;

      pidList = [appInfo objectForKey:@"NSApplicationProcessIdentifier"];
      for (NSString *pidString in pidList)
        {
          kill([pidString intValue], SIGKILL);
        }
      
      if (![[appInfo objectForKey:@"IsXWindowApplication"]
             isEqualToString:@"YES"])
        {// GNUstep app: send notification to remove app from list
          NSNotification *notif;
          
          notif = [NSNotification 
                    notificationWithName:NSWorkspaceDidTerminateApplicationNotification
                                  object:nil
                                userInfo:appInfo];

          [[[NSWorkspace sharedWorkspace] notificationCenter]
            postNotification:notif];
        }
    }
  
  if (appList != nil)
    {
      [appList reloadData];
      [self showApp:nil];
    }
}

// Called when application in list clicked
- (void)showApp:(id)sender
{
  NSDictionary *appInfo;
  NSImage      *icon;
  NSString     *name, *path;
  NSArray      *pid;
  
  NSWorkspace  *ws = [NSWorkspace sharedWorkspace];

  if ([appList selectedRow] < 0)
    return;

  appInfo = [[manager applications] objectAtIndex:[appList selectedRow]];

  // Name
  name = [appInfo objectForKey:@"NSApplicationName"];
  [appName setStringValue:name];

  // Status: and Path:
  if ([appInfo objectForKey:@"StartingUp"] != nil)
    {
      [appStatus setStringValue:_(@"Starting up")];
      path = [ws fullPathForApplication:
                   [appInfo objectForKey:@"NSApplicationName"]];
    }
  else
    {
      [appStatus setStringValue:_(@"Running")];
      path = [appInfo objectForKey:@"NSApplicationPath"];
    }
  [appPath setStringValue:path];

  // Process ID:
  pid = [appInfo objectForKey:@"NSApplicationProcessIdentifier"];
  [appPID setStringValue:[pid componentsJoinedByString:@", "]];

  // Icon
  icon = [appInfo objectForKey:@"NSApplicationIcon"];
  // TODO: icons of X11 applications after restart of Workspace changing
  // into GSMutableString.
  // NSLog(@"showApp: icon class name: %@ [%@]", [icon className], icon);
  if ([name isEqualToString:@"Workspace"])
    {
      [appIcon setImage:[NSApp applicationIconImage]];
    }
  else if (icon && [icon isKindOfClass:[NSImage class]])
    {
      [appIcon setImage:(NSImage *)icon];
    }
  else if ([pid containsObject:@"-1"] ||
           [[appInfo objectForKey:@"IsXWindowApplication"]
             isEqualToString:@"YES"])
    {
      [appIcon setImage:[NSImage imageNamed:@"XWindow"]];
    }
  else
    {
      [appIcon setImage:[ws iconForFile:path]];
    }

  // Apps with empty "" or unknown "-1" PIDs should not be added?
  // We can't manage them.
  if ([pid containsObject:@"-1"] || [pid containsObject:@""] ||
      [name isEqualToString:@"Workspace"])
    {
      [appKillBtn setEnabled:NO];
      [appKillBtn setTransparent:YES];
      [appKillBtn setHidden:YES];
    }
  else 
    {
      [appKillBtn setEnabled: YES];
      [appKillBtn setTransparent: NO];
      [appKillBtn setHidden:NO];
    }

  [procPopup selectItemAtIndex:0];
  [self setView:procPopup];
  
  // [self show];
}

// Called when application in list double clicked
- (void)activateApp:sender
{
  int          clickedRow;
  NSDictionary *appInfo;

  clickedRow = [sender clickedRow];

  if (clickedRow < 0)
    {
      return;
    }

  appInfo = [[manager applications] objectAtIndex:clickedRow];
  if ([appInfo objectForKey:@"StartingUp"] != nil)
    {
      NSRunAlertPanel(_(@"The application is still starting up"),
		      _(@"An application that is starting up cannot be activated"),
		      nil, nil, nil);
    }
  else
    {
      NSString *app;
      id       otherApp;

      app = [appInfo objectForKey:@"NSApplicationName"];
      if ([app isEqualToString:@"Workspace"])
	{
	  return;
	}
      otherApp = [NSConnection rootProxyForConnectionWithRegisteredName:app
								   host:nil];
      if (otherApp == nil)
	{
	  NSRunAlertPanel(_(@"Couldn't contact app"),
			  _(@"Couldn't contact application %@."),
			  nil, nil, nil, app);
	}
      else
	{
	  [otherApp activateIgnoringOtherApps:NO];
	  [NSApp deactivate];
	}
    }
}

- (void)updateAppList
{
  if (appList != nil)
    {
      [appList reloadData];
      // [self showApp:self];
      // To avoid problems related to crss-thread calls
      // [NSTimer scheduledTimerWithTimeInterval:0.5
      //                                  target:self
      //                                selector:@selector(showApp:)
      //                                userInfo:self
      //                                 repeats:NO];
    }
}

@end

@implementation Processes (Background)

- (void)operationDidChangeState:(NSNotification *)notif
{
  BGOperation *op = [notif object];

  if ([op state] == OperationAlert)
    {
      [self setView:op];
      [self show];
    }
  else
    {
      [self showOperation:backList];
    }
}

- (void)showOperation:(id)sender
{
  int         idx = -1;
  BGOperation *bgop = nil;
  NSArray     *opList = [manager operations];

  [backList reloadData];
  
  if ([opList count] > 0)
    {
      if ([sender isKindOfClass:[BGOperation class]])
        {
          idx = [opList indexOfObjectIdenticalTo:sender];
        }
      else if ((idx = [backList selectedRow]) < 0) 
        { // none of operation was selected
          idx = 0;
        }
      
      bgop = [opList objectAtIndex:idx];

      // NSLog(@"[Processes showOperation:%@] row #%i selected", 
      //       [sender className], idx);

      [backList selectRow:idx byExtendingSelection:NO];

      [backFopBox setContentView:[[bgop userInterface] processView]];
      [bgop updateProcessView:YES];
    }
  else
    {
      NSLog(@"Show NO operation view");
      displayedFop = -1;
      [backFopBox setContentView:backNoFopLabel];
    }
}

- (void)updateBGProcessList
{
  if (backList != nil) 
    {
      [backList reloadData];
    }
}

@end
