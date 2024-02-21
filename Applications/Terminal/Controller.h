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

#import <AppKit/AppKit.h>

#import "Preferences/Preferences.h"
#import "SetTitlePanel.h"
#import "TerminalWindow.h"
#import "TerminalServicesPanel.h"
#import "InfoPanel.h"

@interface Controller : NSObject <NSMenuValidation>
{
  NSMutableArray *idleList;
  NSMutableDictionary *windows;
  int num_windows;
  NSWindow *mainWindow;
  NSTimer *timer;
  BOOL isAppAutoLaunched;

  BOOL quitPanelOpen;

  Preferences *preferencesPanel;
  TerminalServicesPanel *servicesPanel;
  SetTitlePanel *setTitlePanel;
  InfoPanel *infoPanel;

  // Find
  NSWindow *findPanel;

  // Save As accessory
  id accView;
  id windowPopUp;
  id loadAtStartupBtn;
}

@end

@interface Controller (TerminalController)

- (void)childWithPID:(int)pid didExit:(int)status;

- (void)terminalWindow:(TerminalWindowController *)twc becameIdle:(BOOL)idle;
- (BOOL)isTerminalWindowIdle:(TerminalWindowController *)twc;
- (TerminalWindowController *)idleTerminalWindow;
- (void)closeTerminalWindow:(TerminalWindowController *)twc;

- (void)setupTerminalWindow:(TerminalWindowController *)controller;
- (NSArray *)shellList;
- (BOOL)isProgramClean:(NSString *)program;
- (TerminalWindowController *)newWindow;
- (TerminalWindowController *)newWindowWithShell;
- (TerminalWindowController *)newWindowWithPreferences:(id)defs startupFile:(NSString *)path;
- (void)openStartupFile:(NSString *)filePath;
- (TerminalWindowController *)newWindowWithProgram:(NSString *)program
                                         arguments:(NSArray *)args
                                             input:(NSString *)input;

- (int)numberOfActiveTerminalWindows;
- (void)checkActiveTerminalWindows;
- (void)checkTerminalWindowsState;
- (int)pidForTerminalWindow:(TerminalWindowController *)twc;

- (TerminalWindowController *)terminalWindowForWindow:(NSWindow *)win;
- (id)preferencesForWindow:(NSWindow *)win live:(BOOL)isLive;

@end
