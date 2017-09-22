/*
  Copyright (C) 2015-2017 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/
 
#import <sys/wait.h>

#import <NXAppKit/NXAlert.h>

#import "Defaults.h"

#import "TerminalServices.h"
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
  isAppAutoLaunched = NO;
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [timer invalidate];
  
  [windows release];
  [idleList release];

  [super dealloc];
}

// --- Menu

// Info > Preferences
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

- (void)openServicesPanel:(id)sender
{
  if (servicesPanel == nil)
    {
      servicesPanel = [[TerminalServicesPanel alloc] init];
    }
 
  [servicesPanel activatePanel];
}

// Shell > New
- (void)openWindow:(id)sender
{
  [[self newWindowWithShell] showWindow:self];
}

// Shell > Open...
- (void)openSession:(id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  NSString    *sessionDir, *path;

  [panel setCanChooseDirectories:NO];
  [panel setAllowsMultipleSelection:NO];
  [panel setTitle:@"Open Shell"];
  [panel setShowsHiddenFiles:NO];

  if ((sessionDir = [Defaults sessionsDirectory]) == nil)
    return;

  if ([panel runModalForDirectory:sessionDir
                             file:@"Default.term"
                            types:[NSArray arrayWithObject:@"term"]]
      == NSOKButton)
    {
      if ((path = [panel filename]) != nil)
        {
          [[self newWindowWithStartupFile:path] showWindow:self];
        }
    }  
}
// Shell > Save
- (void)saveSession:(id)sender
{
  TerminalWindowController *twc;
  NSString *sessionDir, *fileName, *filePath;
  BOOL isDefaultSession = NO;
  BOOL isSessionChanged = NO;

  twc = [self terminalWindowForWindow:[NSApp mainWindow]];
  fileName = [twc fileName];
  
  isDefaultSession = [fileName isEqualToString:@"Default"];
  if ([self preferencesForWindow:[NSApp mainWindow] live:YES] != nil)
    {
      isSessionChanged = YES;
    }
  
  if ((sessionDir = [Defaults sessionsDirectory]) == nil)
    return;
  
  fileName = [[twc fileName] stringByAppendingPathExtension:@"term"];
  filePath = [sessionDir stringByAppendingPathComponent:fileName];
  
  if (!isDefaultSession)
    {
      if (!isSessionChanged)
        {
          // If session was opened from file and not changed - menu item must
          // be disabled and this method must not be called!
          NSLog(@"Shell > Save menu item should not be called!");
        }
      else
        { // If session was opened from file and changed - save silently
          NSLog(@"Session was opened from file and changed - save silently");
          Defaults *defs = [twc livePreferences];
          if (defs == nil) defs = [twc preferences];
          [defs writeToFile:filePath atomically:YES];
        }
    }
  else
    { // If it's a default session (changed or not) - open "Save As..." panel
      NSLog(@"It's a default session - open \"Save As...\" panel");
      [self saveSessionAs:sender];
    }
  
}
// Shell -> Save As...
- (void)saveSessionAs:(id)sender
{
  TerminalWindowController *twc;
  NSString    *fileName, *filePath;
  NSSavePanel *panel;
  NSString    *sessionDir;
  Defaults    *prefs;

  if ((sessionDir = [Defaults sessionsDirectory]) == nil)
    return;
  
  twc = [self terminalWindowForWindow:[NSApp mainWindow]];
  
  panel = [NSSavePanel savePanel];
  [panel setTitle:@"Save Shell"];
  [panel setShowsHiddenFiles:NO];
  if (accView == nil)
    {
      [NSBundle loadNibNamed:@"SaveAsAccessory" owner:self];
    }
  [panel setAccessoryView:accView];

  fileName = [[twc fileName] stringByAppendingPathExtension:@"term"];
  filePath = [sessionDir stringByAppendingPathComponent:fileName];

  if ([panel runModalForDirectory:sessionDir file:fileName] == NSOKButton)
    {
      filePath = [panel filename];
      prefs = [twc livePreferences];
      if (prefs == nil)
        {
          prefs = [twc preferences];
        }
      [prefs writeToFile:filePath atomically:YES];
    }
}
- (void)setAVSaveWindows:(id)sender
{
  NSInteger saveAllWindows = 1;
  saveAllWindows = [sender selectedTag] & saveAllWindows;
  // NSLog(@"Save Shell: saveAllWindows == %li", saveAllWindows);
}
-(void)setAVOpenAtStartup:(id)sender
{
  
}
// Shell > Set Title...
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
  NSString *itemTitle = [menuItem title];

  if ([self terminalWindowForWindow:[NSApp keyWindow]] == nil)
    {
      // NSLog(@"Controller: Validate menu: %@: key window is not Terminal",
      //       menuTitle);
      if ([itemTitle isEqualToString:@"Save"])
        return NO;
      if ([itemTitle isEqualToString:@"Save As..."])
        return NO;
      if ([itemTitle isEqualToString:@"Set Title..."])
        return NO;
      
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
  idleList = [[NSMutableArray alloc] init];
  
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
  NSArray *arguments;
  TerminalWindowController *twc;

  NSLog(@"Controller: applicationDidFinishLaunching");
  
  [NSApp setServicesProvider:[[TerminalServices alloc] init]];

  // Remove "Terminal" from argument list
  arguments = [args subarrayWithRange:NSMakeRange(1,[args count]-1)];
  // Check for -NXAutoLaunch
  if ([arguments containsObject:@"-NXAutoLaunch"])
    {
      NSLog(@"Appplication arguments contains -NXAutoLaunch");
      
      NSUInteger index = [arguments indexOfObject:@"-NXAutoLaunch"];
      if ([[arguments objectAtIndex:++index] isEqualToString:@"YES"])
        {
          isAppAutoLaunched = YES;
        }
    }

  switch ([[Defaults shared] startupAction])
    {
    case OnStartCreateShell:
      twc = [self newWindowWithShell];
      [twc showWindow:self];
      break;
    case OnStartOpenFile:
      twc = [self newWindowWithStartupFile:[[Defaults shared] startupFile]];
      [twc showWindow:self];
      break;
    default:
      // OnStartDoNothing == do nothing
      break;
    }

  // By default "-NXAutoLaunch YES" option resigns active state from
  // starting application.
  if (isAppAutoLaunched == YES && [[Defaults shared] hideOnAutolaunch] == YES)
    [NSApp hide:self];
  else
    [NSApp activateIgnoringOtherApps:YES];

  // Activate timer for windows state checking
  timer = [NSTimer
            scheduledTimerWithTimeInterval:2.0
                                    target:self
                                  selector:@selector(checkTerminalWindowsState)
                                  userInfo:nil
                                   repeats:YES];
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

- (BOOL)application:(NSApplication *)sender
 	   openFile:(NSString *)filename
{
  NSLog(@"Open file: %@", filename);
  
  return YES;
}

/*
// WTF???

- (BOOL)terminalRunProgram:(NSString *)path
	     withArguments:(NSArray *)args
	       inDirectory:(NSString *)directory
		properties:(NSDictionary *)properties
{
  TerminalWindowController *twc;

  NSDebugLLog(@"Application",
	      @"terminalRunProgram: %@ withArguments: %@ inDirectory: %@ properties: %@",
	      path,args,directory,properties);

  [NSApp activateIgnoringOtherApps:YES];

  {
    id o = [properties objectForKey:@"CloseOnExit"];
    
    if (o && [o respondsToSelector:@selector(boolValue)] && ![o boolValue])
      {
        twc = [self idleTerminalWindow];
        [twc showWindow:self];
      }
    else
      {
        twc = [self newWindow];
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

// WTF???
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
*/
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
    return;

  NSArray *wins = [windows allValues];

  for (TerminalWindowController *twc in wins)
    {
      // NSLog(@"%@: idleList contains = %i, user programm = %i ",
      //       [twc shellPath],
      //       [idleList containsObject:twc],
      //       [[twc terminalView] isUserProgramRunning]);
 
      if ([[twc terminalView] isUserProgramRunning] ||
          [idleList containsObject:twc] ||
          [self isProgramClean:[twc shellPath]] == NO)
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

      // HACK: This is window running Services command. Ignore it.
      if ([idleList containsObject:twc])
        {
          [idleList removeObject:twc];
          [[NSApp delegate] checkActiveTerminalWindows];
          return;          
        }
      
      NSLog(@"Window %@ became idle.", [twc shellPath]);
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
              // WindowCloseAlways - "Always close the window"
              // 'status == 0' - "Close the window if shell exits cleanly"
              if ((windowCloseBehavior == WindowCloseAlways) || (status == 0))
                {
                  [twc close];
                }
            }
        }
    }
  else
    {
      NSLog(@"Window %@ became non idle.", [twc shellPath]);
      [idleList removeObject:twc];
    }

  [[NSApp delegate] checkActiveTerminalWindows];
}

- (BOOL)isTerminalWindowIdle:(TerminalWindowController *)twc
{
  return [idleList containsObject:twc];
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

// Terminal window can be run in 2 modes: 'Shell' and 'Program'
// 
// In 'Shell' mode launched shell is not considered as running program
// (close window button has normal state). Close window button change its state
// to 'document edited' until some program executed in the shell (as aresult
// shell has child process).
// 
// In 'Program' mode any programm executed considered as important and close
// window button has 'document edited' state. This button changes its state
// to normal when running program finishes.
// Also in 'Program' mode window will never close despite the 'When Shell Exits'
// preferences setting.

- (BOOL)_noDuplicatesOf:(NSString *)string inside:(NSArray *)array
{
  for (NSString *s in array)
    {
      if ([[s lastPathComponent] isEqualToString:[string lastPathComponent]])
        {
          return NO;
        }
    }
  return YES;
}
// Fill in array with items from /etc/shells
// Omit 'nologin' as shell and duplicates (/bin/sh and /usr/bin/sh are
// duplicates).
- (NSArray *)shellList
{
  NSString  *etc_shells = [NSString stringWithContentsOfFile:@"/etc/shells"];
  NSString  *lString;
  NSRange   lRange;
  NSUInteger index, stringLength = [etc_shells length];
  NSMutableArray *shells = [[NSMutableArray alloc] init];

  for (index=0; index < stringLength;)
    {
      lRange = [etc_shells lineRangeForRange:NSMakeRange(index, 0)];
      lRange.length -= 1; // Do not include new line char
      lString = [etc_shells substringFromRange:lRange];
      if ([lString rangeOfString:@"nologin"].location == NSNotFound &&
          [self _noDuplicatesOf:lString inside:shells])
        {
          [shells addObject:lString];
        }
      index = lRange.location + lRange.length + 1;
    }

  return [shells autorelease];
}

// For now it's only a shells
- (BOOL)isProgramClean:(NSString *)program
{
  for (NSString *s in [self shellList])
    {
      if ([[s lastPathComponent] isEqualToString:[program lastPathComponent]])
        {
          return YES;
        }
    }
  
  return NO;
}

- (void)setupTerminalWindow:(TerminalWindowController *)controller
{
  [controller setDocumentEdited:YES];
  
  if ([[windows allValues] count] > 0)
    {
      NSRect  mwFrame = [[NSApp mainWindow] frame];
      NSPoint wOrigin = mwFrame.origin;

      wOrigin.x += [NSScroller scrollerWidth] + 3;
      wOrigin.y -= 24;
      [[controller window] setFrameOrigin:wOrigin];
    }
  else
    {
      [[controller window] center];
    }
}

- (TerminalWindowController *)newWindow
{
  TerminalWindowController *twc = [[TerminalWindowController alloc] init];
  
  if (twc == nil) return nil;
  
  [self setupTerminalWindow:twc];

  return twc;
}

- (TerminalWindowController *)newWindowWithShell
{
  TerminalWindowController *twc = [self newWindow];
  int pid;

  if (twc == nil) return nil;
  
  pid = [[twc terminalView] runShell];
  [windows setObject:twc forKey:[NSString stringWithFormat:@"%i",pid]];

  return twc;
}

- (TerminalWindowController *)newWindowWithProgram:(NSString *)program
                                         arguments:(NSArray *)args
                                             input:(NSString *)input
{
  TerminalWindowController *twc = [self newWindow];
  int pid;

  if (twc == nil) return nil;
 
  if (program == nil)
    program = [[twc preferences] shell];
  
  pid = [[twc terminalView] runProgram:program
                         withArguments:args
                          initialInput:input];
  [windows setObject:twc forKey:[NSString stringWithFormat:@"%i",pid]];
  [idleList addObject:twc];
  
  return twc;
}

// Create window, and run shell.
// Add window to 'windows' array.
- (TerminalWindowController *)newWindowWithStartupFile:(NSString *)filePath
{
  TerminalWindowController *twc;
  NSString *shell;
  NSArray *args;
  int pid;

  twc = [[TerminalWindowController alloc] initWithStartupFile:filePath];
  [self setupTerminalWindow:twc];
  
  args = [[[twc preferences] shell] componentsSeparatedByString:@" "];
  shell = [[args objectAtIndex:0] copy];
  if ([args count] > 1)
    args = [args subarrayWithRange:NSMakeRange(1,[args count]-1)];
  else
    args = nil;

  NSLog(@"Create Terminal window with Startup File: %@."
        " Program: %@, arguments: %@", filePath, shell, args);
  
  pid = [[twc terminalView] runProgram:shell
                         withArguments:args
                           inDirectory:nil
                          initialInput:nil
                                  arg0:shell];
  [windows setObject:twc forKey:[NSString stringWithFormat:@"%i",pid]];

  [shell release];
  
  return twc;
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
