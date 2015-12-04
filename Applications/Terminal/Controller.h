/*
 *
 */

#import <AppKit/AppKit.h>

@interface Controller : NSObject
{
  NSMutableArray      *idleList;
  NSMutableDictionary *windows;
  NSTimer             *timer;
  
  BOOL                quitPanelOpen;
  int                 num_windows;
}

@end

@interface Controller (TerminalController)

- (void)childWithPID:(int)pid didExit:(int)status;

- (void)window:(TerminalWindowController *)twc becameIdle:(BOOL)idle;
- (void)closeWindow:(TerminalWindowController *)twc;

- (TerminalWindowController *)newTerminalWindow;
- (TerminalWindowController *)newWindowWithShell;
- (TerminalWindowController *)idleTerminalWindow;

- (int)numberOfActiveWindows;
- (void)checkActiveWindows;

@end
