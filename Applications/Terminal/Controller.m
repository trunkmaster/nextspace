/*
 *
 */
 
#import <sys/wait.h>

#import <NXAppKit/NXAlert.h>

#import "Defaults.h"

#import "Services.h"
#import "ServicesPrefs.h"
#import "TerminalView.h"
#import "TerminalWindow.h"

#import "Controller.h"

//-----------------------------------------------------------------------------
// Child shells management
//-----------------------------------------------------------------------------
// static void child_action_handler(int signal, siginfo_t *siginfo, void *context)
// {
//   NSLog(@"Received signal %i: PID=%i error=%i status=%i",
//         signal, siginfo->si_pid,
//         siginfo->si_errno, siginfo->si_status);

//   [[NSApp delegate] childWithPID:siginfo->si_pid
//                          didExit:siginfo->si_status];
// }
// {
//   struct  sigaction child_action;
//   child_action.sa_sigaction = &child_action_handler;
//   child_action.sa_flags = SA_SIGINFO;
//   sigaction(SIGCHLD, &child_action, NULL);
// }  
//-----------------------------------------------------------------------------

@implementation Controller

- init
{
  if (!(self=[super init])) return nil;

  windows = [[NSMutableDictionary alloc] init];
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [windows release];

  [super dealloc];
}

// --- Menu

// "Terminal Preferences" panel
- (void)openPreferences:(id)sender
{
  // load Preferences.bundle, send 'activate' to principal class
  if (preferencesPanel == nil)
    {
      NSString *bundlePath;
      NSBundle *bundle;

      bundlePath = [[[NSBundle mainBundle] resourcePath]
                     stringByAppendingPathComponent:@"Preferences.bundle"];

      // NSLog(@"[Controller] Inspectors: %@", inspectorsPath);

      bundle = [[NSBundle alloc] initWithPath:bundlePath];

      // NSLog(@"[Controller] Inspectors Class: %@",
      //       [inspectorsBundle principalClass]);
      preferencesPanel = [[[bundle principalClass] alloc] init];
    }
  
  [preferencesPanel activatePanel];
}

- (void)openWindow:(id)sender
{
  [self newWindowWithShell];
}

// "Set Title" panel
- (void)openSetTitlePanel:(id)sender
{
  if (setTitlePanel == nil)
    {
      setTitlePanel = [[SetTitlePanel alloc] init];
    }
  [setTitlePanel activatePanel];
}

// "Font" menu
- (void)orderFrontFontPanel:(id)sender
{
  NSFontManager *fm = [NSFontManager sharedFontManager];
  TerminalWindowController *twc = [self terminalWindowForWindow:mainWindow];
  Defaults *prefs = [twc livePreferences];

  if (prefs == nil) prefs = [twc preferences];
  
  [fm setSelectedFont:[prefs terminalFont] isMultiple:NO];
  [fm orderFrontFontPanel:sender];
}
// Bold and Italic
- (void)addFontTrait:(id)sender
{
  [[NSFontManager sharedFontManager] addFontTrait:sender];
}
// Larger and Smaller
- (void)modifyFont:(id)sender
{
  [[NSFontManager sharedFontManager] modifyFont:sender];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  NSString *menuTitle = [[menuItem menu] title];
  // NSString *itemTitle = [menuItem title];

  if ([self terminalWindowForWindow:[NSApp keyWindow]] == nil)
    {
      // NSLog(@"Controller: Validate menu: %@: key window is not Terminal",
      //       menuTitle);
      if ([menuTitle isEqualToString:@"Font"])
        return NO;
      if ([menuTitle isEqualToString:@"Find"])
        return NO;
    }
  
  return YES;
}

// --- NSApplication delegate
- (void)applicationWillFinishLaunching:(NSNotification *)n
{
  [TerminalView registerPasteboardTypes];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(noMoreActiveTerminalWindows:)
	   name:TerminalWindowNoMoreActiveWindowsNotification
	 object:nil];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(mainWindowDidChange:)
           name:NSWindowDidBecomeMainNotification
         object:nil];  
}

- (void)applicationDidFinishLaunching:(NSNotification *)n
{
  NSArray *args = [[NSProcessInfo processInfo] arguments];
    
  [NSApp setServicesProvider:[[TerminalServices alloc] init]];

  if ([args count] > 1)
    {
      TerminalWindowController *twc;
      NSString *cmdline;

      args = [args subarrayWithRange:NSMakeRange(1,[args count]-1)];
      cmdline = [args componentsJoinedByString:@" "];

      twc = [self createTerminalWindow];
      [[twc terminalView]
        runProgram:@"/bin/sh"
        withArguments:[NSArray arrayWithObjects:@"-c",cmdline,nil]
        initialInput:nil];
      [twc showWindow:self];
    }
  else
    {
      switch ([[Defaults shared] startupAction])
        {
        case OnStartCreateShell:
          [self openWindow:self];
          break;
        case OnStartOpenFile:
          // TODO: open window with startupfile
          // [TerminalWindow initWithStartupfile:]
          break;
        default:
          // OnStartDoNothing == do nothing
          break;
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)n
{
  if (preferencesPanel)
    {
      [preferencesPanel closePanel];
      [preferencesPanel release];
    }
  
  if (setTitlePanel)
    {
      [setTitlePanel closeSetTitlePanel:self];
      [setTitlePanel release];
    }

  // Clear font pasteboard data
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSFontPboard];
  if ([pb dataForType:NSFontPboardType] != nil)
    {
      [pb setData:nil forType:NSFontPboardType];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  TerminalWindowController *twc;
  BOOL ask = NO;
  
  if (![self numberOfActiveTerminalWindows])
    {
      return NSTerminateNow;
    }

  // manually check state of windows
  [self checkTerminalWindowsState];
  
  for (NSString *windowKey in windows)
    {
      twc = [windows objectForKey:windowKey];
      if ([[twc window] isDocumentEdited])
        {
          ask = YES;
        }
    }

  if (ask)
    {
      [NSApp activateIgnoringOtherApps:YES];
      if (NXRunAlertPanel((@"Quit"),
                          (@"You have commands running in some terminal windows.\n"
                           "Quit Terminal terminating running commands?"),
                          (@"Don't quit"), (@"Quit"), nil)
          == NSAlertAlternateReturn)
        {
          return NSTerminateNow;
        }
      else
        {
          return NSTerminateLater;
        }
    }

  return NSTerminateNow;
}

- (void)quitAnyway:(id)sender
{
  [NSApp replyToApplicationShouldTerminate:YES];
}

- (void)dontQuit:(id)sender
{
  [NSApp replyToApplicationShouldTerminate:NO];
}

- (BOOL)application:(NSApplication *)sender
 	   openFile:(NSString *)filename
{
  TerminalWindowController *twc;

  NSDebugLLog(@"Application",@"openFile: '%@'",filename);

  // TODO: shouldn't ignore other apps

  [NSApp activateIgnoringOtherApps:YES];

  twc = [self createTerminalWindow];
  [[twc terminalView] runProgram:filename
		   withArguments:nil
		    initialInput:nil];
  [twc showWindow:self];

  return YES;
}


// TODO
- (BOOL)terminalRunProgram:(NSString *)path
	     withArguments:(NSArray *)args
	       inDirectory:(NSString *)directory
		properties:(NSDictionary *)properties
{
  TerminalWindowController *twc;

  NSDebugLLog(@"Application",
	      @"terminalRunProgram: %@ withArguments: %@ inDirectory: %@ properties: %@",
	      path,args,directory,properties);

  // TODO: shouldn't ignore other apps

  [NSApp activateIgnoringOtherApps:YES];

  {
    id o;
    o = [properties objectForKey: @"CloseOnExit"];
    if (o && [o respondsToSelector: @selector(boolValue)] &&
        ![o boolValue])
      {
        twc = [self idleTerminalWindow];
        [twc showWindow:self];        
      }
    else
      {
        twc = [self createTerminalWindow];
        [twc showWindow:self];
      }
  }

  [[twc terminalView] runProgram:path
		   withArguments:args
		     inDirectory:directory
		    initialInput:nil
			    arg0:nil];

  return YES;
}

// TODO
- (BOOL)terminalRunCommand:(NSString *)cmdline
	       inDirectory:(NSString *)directory
		properties:(NSDictionary *)properties
{
  NSDebugLLog(@"Application",
	      @"terminalRunCommand: %@ inDirectory: %@ properties: %@",
	      cmdline,directory,properties);

  return [self terminalRunProgram:@"/bin/sh"
		    withArguments:[NSArray arrayWithObjects: @"-c",cmdline,nil]
		      inDirectory:directory
		       properties:properties];
}

@end

//-----------------------------------------------------------------------------
// Child shells management
//---
// Role of these methods are to create, monitor and close terminal windows
// In method names 'Window' means NSWindow,
// 'TerminalWindow' - TerminalWindowController
//-----------------------------------------------------------------------------
@implementation Controller (TerminalController)

- (void)childWithPID:(int)pid didExit:(int)status
{
  TerminalWindowController *twc;
  int                      windowCloseBehavior;

  NSLog(@"Child with pid: %i did exit(%i)", pid, status);
  
  twc = [windows objectForKey:[NSString stringWithFormat:@"%i",pid]];
  [twc setDocumentEdited:NO];

  windowCloseBehavior = [[twc preferences] windowCloseBehavior];
  if (windowCloseBehavior != WindowCloseNever)
    {
      if ((windowCloseBehavior == WindowCloseAlways) || (status == 0))
        {
          [twc close];
        }
    }
}

- (void)mainWindowDidChange:(NSNotification *)notif
{
  NSFontManager *fm = [NSFontManager sharedFontManager];
  NSFontPanel   *fp = [fm fontPanel:NO];
  Defaults      *defs;

  mainWindow = [notif object];
  
  if (fp == nil)
    {
      return;
    }
  
  if ((defs = [self preferencesForWindow:mainWindow live:YES]) == nil)
    {
      if ((defs = [self preferencesForWindow:mainWindow live:NO]) == nil)
        { // this is not terminal window
          return;
        }
    }

  [fm setSelectedFont:[defs terminalFont] isMultiple:NO];
}

- (void)noMoreActiveTerminalWindows:(NSNotification *)n
{
  if (quitPanelOpen) 
    {
      [NSApp replyToApplicationShouldTerminate:YES];
    }
}

- (int)numberOfActiveTerminalWindows
{
  return [windows count] - [idleList count];
}

- (void)checkActiveTerminalWindows
{
  if (![self numberOfActiveTerminalWindows])
    {
      [[NSNotificationCenter defaultCenter]
			postNotificationName:TerminalWindowNoMoreActiveWindowsNotification
                                      object:self];
    }
}

- (void)checkTerminalWindowsState
{
  if ([windows count] <= 0)
    {
      [timer invalidate];
      timer = nil;
      return;
    }

  NSArray *wins = [windows allValues];

  for (TerminalWindowController *twc in wins)
    {
      if ([[twc terminalView] isUserProgramRunning])
        {
          [twc setDocumentEdited:YES];
        }
      else
        {
          [twc setDocumentEdited:NO];
        }
    }
}

- (int)pidForTerminalWindow:(TerminalWindowController *)twc
{
  NSArray *keys = [windows allKeys];
  int     pid = -1;
 
  for (NSString *PID in keys)
    {
      if ([windows objectForKey:PID] == twc)
        {
          pid = [PID integerValue]; 
        }
    }

  return pid;
}

- (TerminalWindowController *)terminalWindowForWindow:(NSWindow *)win
{
  for (TerminalWindowController *windowController in [windows allValues])
    {
      if ([windowController window] == win)
        {
          return windowController;
        }
    }
  
  return nil;
}

- (void)terminalWindow:(TerminalWindowController *)twc becameIdle:(BOOL)idle
{
  if (idle)
    {
      int pid, status;
      
      [idleList addObject:twc];
      
      if ((pid = [self pidForTerminalWindow:twc]) > 0)
        {
          fprintf(stderr, "Idle: Waiting for PID: %i...", pid);
          waitpid(pid, &status, 0);
          fprintf(stderr, "\tdone!\n");
          
          // [self childWithPID:pid didExit:status];
          int windowCloseBehavior = [[Defaults shared] windowCloseBehavior];
          [twc setDocumentEdited:NO];

          windowCloseBehavior = [twc closeBehavior];
          if (windowCloseBehavior != WindowCloseNever)
            {
              if ((windowCloseBehavior == WindowCloseAlways) || (status == 0))
                {
                  [twc close];
                }
            }
        }
    }
  else
    {
      [idleList removeObject:twc];
    }

  
  [[NSApp delegate] checkActiveTerminalWindows];
}

// TODO: TerminalWindowDidCloseNotification -> windowDidClose:(NSNotification*)n
- (void)closeTerminalWindow:(TerminalWindowController *)twc
{
  int pid, status;
  
  if ([idleList containsObject:twc])
    [idleList removeObject:twc];

  if ((pid = [self pidForTerminalWindow:twc]) > 0)
    {
      kill(pid, SIGKILL);
      // fprintf(stderr, "Close: Waiting for PID: %i...", pid);
      waitpid(pid, &status, 0);
      // fprintf(stderr, "\tdone!\n");
      
      [windows removeObjectForKey:[NSString stringWithFormat:@"%i", pid]];
    }
   
  [[NSApp delegate] checkActiveTerminalWindows];
}

// TODO:
// Terminal window can be run in 2 modes: 'Shell' and 'Program' (now it's
// called 'Idle').
// 
// In 'Shell' mode running shell is not considered as running program
// (close window button has normal state). Close window button change its state
// to 'document edited' until some program executed in the shell (as aresult
// shell has child process).
// 
// In 'Program' mode any programm executed considered as important and close
// window button has 'document edited' state. This button changes its state
// to normal when running program finishes.
// Also in 'Program' mode window will never close despite the 'When Shell Exits'
// preferences setting.
- (TerminalWindowController *)createTerminalWindow
{
  TerminalWindowController *twc;

  twc = [[TerminalWindowController alloc] init];
  [twc setDocumentEdited:YES];
  
  NSArray *wins = [windows allValues];
  if ([wins count] > 0)
    {
      NSRect  mwFrame = [[NSApp mainWindow] frame];
      NSPoint wOrigin = mwFrame.origin;

      wOrigin.x += [NSScroller scrollerWidth]+3;
      wOrigin.y -= 24;
      [[twc window] setFrameOrigin:wOrigin];
    }
  else
    {
      [[twc window] center];
    }
  
  return twc;
}

- (TerminalWindowController *)newWindowWithShell
{
  TerminalWindowController *twc = [self createTerminalWindow];
  int pid;

  if (twc == nil) return nil;

  pid = [[twc terminalView] runShell];
  [windows setObject:twc forKey:[NSString stringWithFormat:@"%i",pid]];
  
  [twc showWindow:self];

  if (timer == nil)
    {
      timer =
        [NSTimer
          scheduledTimerWithTimeInterval:2.0
                                  target:self
                                selector:@selector(checkTerminalWindowsState)
                                userInfo:nil
                                 repeats:YES];
    }

  return twc;
}

// + (TerminalWindowController *)newWindowWithProgram:(NSString *)path
// {
// }

- (TerminalWindowController *)idleTerminalWindow
{
  NSDebugLLog(@"idle",@"get idle window from idle list: %@",idleList);
  
  if ([idleList count])
    return [idleList objectAtIndex:0];
  
  return [self createTerminalWindow];
}

//-----------------------------------------------------------------------------
// Preferences and sessions
//---
- (id)preferencesForWindow:(NSWindow *)win
                      live:(BOOL)isLive
{
  TerminalWindowController *windowController;
  
  windowController = [self terminalWindowForWindow:win];
  if (windowController != nil)
    {
      if (isLive)
        return [windowController livePreferences];
      else
        return [windowController preferences];
    }
  
  return nil;
}

@end
