/*
 *
 */

#import <AppKit/AppKit.h>

#import "Preferences/Preferences.h"
#import "SetTitlePanel.h"
#import "TerminalWindow.h"

@interface Controller : NSObject <NSMenuValidation>
{
  NSMutableArray      *idleList;
  NSMutableDictionary *windows;
  int                 num_windows;
  NSWindow            *mainWindow;
  NSTimer             *timer;
  
  BOOL                quitPanelOpen;

  Preferences         *preferencesPanel;
  SetTitlePanel	      *setTitlePanel;
}

@end

@interface Controller (TerminalController)

- (void)childWithPID:(int)pid didExit:(int)status;

- (void)terminalWindow:(TerminalWindowController *)twc becameIdle:(BOOL)idle;
- (BOOL)isTerminalWindowIdle:(TerminalWindowController *)twc;
- (void)closeTerminalWindow:(TerminalWindowController *)twc;

- (void)setupTerminalWindow:(TerminalWindowController *)controller;
- (TerminalWindowController *)newWindow;
- (TerminalWindowController *)newWindowWithShell;
- (TerminalWindowController *)newWindowWithStartupFile:(NSString *)filePath;
- (TerminalWindowController *)newWindowWithProgram:(NSString *)program
                                         arguments:(NSArray *)args;
- (TerminalWindowController *)idleTerminalWindow;

- (int)numberOfActiveTerminalWindows;
- (void)checkActiveTerminalWindows;
- (void)checkTerminalWindowsState;
- (int)pidForTerminalWindow:(TerminalWindowController *)twc;

- (TerminalWindowController *)terminalWindowForWindow:(NSWindow *)win;
- (id)preferencesForWindow:(NSWindow *)win
                      live:(BOOL)isLive;

@end
