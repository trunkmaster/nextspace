/*
  Copyright (C) 2015-2017 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <AppKit/AppKit.h>

#import "Preferences/Preferences.h"
#import "SetTitlePanel.h"
#import "TerminalWindow.h"
#import "TerminalServicesPanel.h"

@interface Controller : NSObject <NSMenuValidation>
{
  NSMutableArray      *idleList;
  NSMutableDictionary *windows;
  int                 num_windows;
  NSWindow            *mainWindow;
  NSTimer             *timer;
  BOOL                isAppAutoLaunched;
  
  BOOL                quitPanelOpen;

  Preferences           *preferencesPanel;
  TerminalServicesPanel *servicesPanel;
  SetTitlePanel	        *setTitlePanel;
}

@end

@interface Controller (TerminalController)

- (void)childWithPID:(int)pid didExit:(int)status;

- (void)terminalWindow:(TerminalWindowController *)twc becameIdle:(BOOL)idle;
- (BOOL)isTerminalWindowIdle:(TerminalWindowController *)twc;
- (void)closeTerminalWindow:(TerminalWindowController *)twc;

- (void)setupTerminalWindow:(TerminalWindowController *)controller;
- (NSArray *)shellList;
- (TerminalWindowController *)newWindow;
- (TerminalWindowController *)newWindowWithShell;
- (TerminalWindowController *)newWindowWithStartupFile:(NSString *)filePath;
- (TerminalWindowController *)newWindowWithProgram:(NSString *)program
                                         arguments:(NSArray *)args
                                             input:(NSString *)input;

- (int)numberOfActiveTerminalWindows;
- (void)checkActiveTerminalWindows;
- (void)checkTerminalWindowsState;
- (int)pidForTerminalWindow:(TerminalWindowController *)twc;

- (TerminalWindowController *)terminalWindowForWindow:(NSWindow *)win;
- (id)preferencesForWindow:(NSWindow *)win
                      live:(BOOL)isLive;

@end
