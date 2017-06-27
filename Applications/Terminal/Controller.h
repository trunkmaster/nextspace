/*
 *
 */

#import <AppKit/AppKit.h>

#import "Preferences/Preferences.h"
#import "SetTitlePanel.h"

@interface Controller : NSObject
{
  NSMutableArray      *idleList;
  NSMutableDictionary *windows;
  NSTimer             *timer;
  
  BOOL                quitPanelOpen;
  int                 num_windows;

  Preferences         *preferencesPanel;
  SetTitlePanel	      *setTitlePanel;
}

@end

@interface Controller (TerminalController)

- (void)childWithPID:(int)pid didExit:(int)status;

- (void)window:(TerminalWindowController *)twc becameIdle:(BOOL)idle;
- (void)closeWindow:(TerminalWindowController *)twc;
- (Defaults *)defaultsForWindow:(NSWindow *)win;

- (TerminalWindowController *)newTerminalWindow;
- (TerminalWindowController *)newWindowWithShell;
- (TerminalWindowController *)idleTerminalWindow;

- (int)numberOfActiveWindows;
- (void)checkActiveWindows;

@end
