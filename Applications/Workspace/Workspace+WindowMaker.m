//============================================================================
// Interface to WindowMaker part. 
// Consists of functions to avoid converting WindowMaker sources to ObjC.
//============================================================================

#ifdef NEXTSPACE

#include <X11/Xlib.h>
#include <X11/Xlocale.h>
#include <X11/Xatom.h>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <NXAppKit/NXAlert.h>
#import <NXSystem/NXScreen.h>

#import "Workspace+WindowMaker.h"
#import "Operations/ProcessManager.h"

// defined and set in WindowMaker
extern Display *dpy;

// WindowMaker functions
extern char *GetCommandForWindow(Window win);

//-----------------------------------------------------------------------------
// Workspace X Window related utility functions
//-----------------------------------------------------------------------------
BOOL xIsWindowServerReady(void)
{
  Display *xdpy = XOpenDisplay(NULL);
  BOOL    ready = (xdpy == NULL ? NO : YES);

  if (ready) XCloseDisplay(xdpy);

  return ready;
}

static int CantManageScreen = 0;

static int xAlreadyRunningErrorHandler(Display *dpy, XErrorEvent *error)
{
  CantManageScreen = 1;
  return -1;
}

BOOL xIsWindowManagerAlreadyRunning(void)
{
  Display       *xDisplay = NULL;
  int           xScreen = -1;
  long          event_mask;
  XErrorHandler oldHandler;

  oldHandler = XSetErrorHandler((XErrorHandler)xAlreadyRunningErrorHandler);
  event_mask = SubstructureRedirectMask;

  xDisplay = XOpenDisplay(NULL);
  xScreen = DefaultScreen(xDisplay);
  XSelectInput(xDisplay, RootWindow(xDisplay, xScreen), event_mask);

  XSync(xDisplay, False);
  XSetErrorHandler(oldHandler);

  if (CantManageScreen)
    {
      XCloseDisplay(xDisplay);
      return YES;
    }
  else
    {
      event_mask &= ~(SubstructureRedirectMask);
      XSelectInput(xDisplay, RootWindow(xDisplay, xScreen), event_mask);
      XSync(xDisplay, False);
      XCloseDisplay(xDisplay);
      return NO;
    }
}

//--- Below this line X Window related functions is TODO

// TODO: Move to NXFoundation/NXFileManager
NSString *fullPathForCommand(NSString *command)
{
  NSString      *commandFile;
  NSString      *envPath;
  NSEnumerator  *e;
  NSString      *path;
  NSFileManager *fm;

  if ([command isAbsolutePath])
    {
      return command;
    }

  commandFile = [[command componentsSeparatedByString:@" "] objectAtIndex:0];
  // commandFile = [command lastPathComponent];
  envPath = [NSString stringWithCString:getenv("PATH")];
  e = [[envPath componentsSeparatedByString:@":"] objectEnumerator];
  fm = [NSFileManager defaultManager];

  while ((path = [e nextObject]))
    {
      if ([[fm directoryContentsAtPath:path] containsObject:commandFile])
	{
	  return [path stringByAppendingPathComponent:commandFile];
	}
    }

  return nil;
}

//-----------------------------------------------------------------------------
// WindowMaker releated functions: call WindowMaker functions, change
// WindowMaker behaviour, change WindowMaker runtime variables.
// 'WWM' prefix is a vector of calls 'Workspace->WindowMaker'
//-----------------------------------------------------------------------------

// WM/src/main.c
extern int real_main(int argc, char **argv);

void WWMInitializeWindowMaker(int argc, char **argv)
{
  int  len;
  char *str;
  char *DisplayName = NULL;
  
  // Initialize Xlib support for concurrent threads.
  XInitThreads();

  memset(&w_global, 0, sizeof(w_global));
  w_global.program.state = WSTATE_NORMAL;
  w_global.program.signal_state = WSTATE_NORMAL;
  w_global.timestamp.last_event = CurrentTime;
  w_global.timestamp.focus_change = CurrentTime;
  w_global.ignore_workspace_change = False;
  w_global.shortcut.modifiers_mask = 0xff;

  /* setup common stuff for the monitor and wmaker itself */
  WMInitializeApplication("WindowMaker", &argc, argv);

  memset(&wPreferences, 0, sizeof(wPreferences));
  // wDockDoAutoLaunch() called in applicationDidFinishLaunching of Workspace
  wPreferences.flags.noautolaunch = 1;

  // DISPLAY environment var
  DisplayName = XDisplayName(DisplayName);
  len = strlen(DisplayName) + 64;
  str = wmalloc(len);
  snprintf(str, len, "DISPLAY=%s", DisplayName);
  putenv(str);

  @autoreleasepool {
    // Check WMState user file (Dock state)
    if (WWMStateCheck() == nil)
      {
        NSLog(@"[Workspace] Dock contents cannot be restored."
              " Show only Workspace application icon.");
      }
    // Restore display layout
    [[[NXScreen new] autorelease] applySavedDisplayLayout];
  }

  // WM/src/main.c
  real_main(argc, argv);

  // Just load saved Dock state without icons drawing.
  // Dock appears on screen after call to WWMDockShowIcons in
  // Controller's -applicationDidFinishLaunching method.
  WWMDockStateLoad();
  
  //--- Below this point WindowMaker was initialized

  // TODO: go through all screens
  // Adjust WM elements placing
  XWUpdateScreenInfo(wScreenWithNumber(0));

  // Dock startup activities
  // {
  //   WAppIcon **icon_array = wScreenWithNumber(0)->dock->icon_array;
  //   WAppIcon *btn;
  //   int      i, icon_count;

  //   icon_count = wScreenWithNumber(0)->dock->icon_count;
  //   for (i=1; i < icon_count; i++)
  //     {
  //       btn = icon_array[i];
  //       if (btn->auto_launch)
  //         {
  //           fprintf(stderr, "*** WindowMaker+: appicon %i state -> launching\n",
  //                   i);
  //           btn->launching = 1;
  //           wAppIconPaint(btn);
  //         }
  //     }
  // }

  // Unmanage some signals which are managed by GNUstep part of Workspace
  WWMSetupSignalHandling();
  
  // Setup predefined _GNUSTEP_FRAME_OFFSETS atom for correct
  // initialization of GNUstep backend (gnustep-back).
  WWMSetupFrameOffsetProperty();
}

void WWMSetupFrameOffsetProperty()
{
  int		count, nelements;
  NSUInteger	titleBarHeight;

  // GSMenuBarHeight defines height for GNUstep menu title bar.
  // WindowMaker window title bar height stored in
  // ~/L/P/.WindowMaker/WindowMaker setting WindowTitle*Height.
  // Should be 23
  titleBarHeight = [[NSUserDefaults standardUserDefaults]
                     floatForKey:@"GSMenuBarHeight"];
  if (titleBarHeight < 23) titleBarHeight = 23;
    
  uint16_t offsets[] = { 1, 1, titleBarHeight, 1,
                         1, 1, titleBarHeight, 1,
                         1, 1, titleBarHeight, 1,
                         1, 1, titleBarHeight, 1,
                         1, 1, titleBarHeight, 1,
                         1, 1, titleBarHeight, 1,
                         1, 1, titleBarHeight, 1,
                         1, 1, titleBarHeight, 9,
                         1, 1, titleBarHeight, 9,
                         1, 1, titleBarHeight, 9,
                         1, 1, titleBarHeight, 9,
                         1, 1, titleBarHeight, 9,
                         1, 1, titleBarHeight, 9,
                         1, 1, titleBarHeight, 9,
                         1, 1, titleBarHeight, 9};
  
  XChangeProperty(dpy, wScreenWithNumber(0)->root_win,
                  XInternAtom(dpy, "_GNUSTEP_FRAME_OFFSETS", False),
                  XA_CARDINAL, 16, PropModeReplace,
                  (unsigned char *)offsets, 60);
}

void WWMSetDockAppiconState(int index_in_dock, int launching)
{
  WAppIcon *btn = wScreenWithNumber(0)->dock->icon_array[index_in_dock];
  int      saved_launching = btn->launching;

  // Set and display dock icon state change
  btn->launching = launching;
  wAppIconPaint(btn);

  // Revert attribute back to make dock autolaunch working
  if (index_in_dock > 0)
    {
      btn->launching = saved_launching;
    }
}

// Disable some signal handling inside WindowMaker code.
// Should be called after WWMInitializeWindowMaker().
void WWMSetupSignalHandling(void)
{
  // signal(SIGTERM, SIG_DFL); // Logout panel - OK
  // signal(SIGINT, SIG_DFL);  // Logout panel - OK
  signal(SIGHUP, SIG_IGN);  //
  signal(SIGUSR1, SIG_IGN); //
  // signal(SIGUSR2, SIG_DFL); // WindowMaker reread defaults - OK
}

// ----------------------------
// --- Dock
// ----------------------------

void WWMDockStateLoad(void)
{
  WMPropList *state;
  WAppIcon *btn;

  // Load WMState dictionary
  state = WMGetFromPLDictionary(wScreenWithNumber(0)->session_state,
                                WMCreatePLString("Dock"));
  wScreenWithNumber(0)->dock = wDockRestoreState(wScreenWithNumber(0),
                                                 state, WM_DOCK);

  // Setup main button properties
  btn = wScreenWithNumber(0)->dock->icon_array[0];
  btn->wm_class = "GNUstep";
  btn->wm_instance = "Workspace";
  btn->command = "NEXTSPACE internal: don't edit it!";
  btn->auto_launch = 0;
  btn->launching = 1;
  btn->running = 0;
  btn->lock = 1;
  // wAppIconPaint(btn);
}

void WWMDockShowIcons(WDock *dock)
{
  WAppIcon *btn;

  if (dock == NULL)
    return;

  btn = dock->icon_array[0];
  // moveDock(dock, btn->x_pos, btn->y_pos);

  for (int i = 0; i < dock->max_icons; i++)
    {
      if (dock->icon_array[i])
        XMapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  dock->mapped = 1;

  wAppIconPaint(btn);
}

// -- Should be called from already existing @autoreleasepool ---

// Returns path to user WMState if exist.
// Returns 'nil' if user WMState doesn't exist and cannot
// be recovered from Workspace.app/WindowMaker directory.
// TODO: rename to WWMDockStateCheck
NSString *WWMStateCheck(void)
{
  NSString      *userDefPath, *appDefPath;
  NSFileManager *fm = [NSFileManager defaultManager];

  userDefPath = [NSString stringWithFormat:@"%@/.WindowMaker/WMState",
                          GSDefaultsRootForUser(NSUserName())];
  
  if (![fm fileExistsAtPath:userDefPath])
    {
      appDefPath = [[NSBundle mainBundle] pathForResource:@"WMState"
                                                   ofType:nil
                                              inDirectory:@"WindowMaker"];
      if (![fm fileExistsAtPath:appDefPath])
        {
          return nil;
        }

      [fm copyItemAtPath:appDefPath toPath:userDefPath error:NULL];
    }

  return userDefPath;
}

NSDictionary *WWMStateLoad(void)
{
  NSDictionary *wmstateDict;

  wmstateDict = [[NSDictionary alloc] initWithContentsOfFile:WWMStateCheck()];

  return wmstateDict;
}

NSString *WWMStateDockAppsKey()
{
  NSArray  *dockApps;
  NSString *appsKey;
      
  appsKey = [NSString stringWithFormat:@"Applications%i",
                      wScreenWithNumber(0)->scr_height];
  
  dockApps = [[WWMStateLoad() objectForKey:@"Dock"] objectForKey:appsKey];
  if (!dockApps || [dockApps count] == 0)
    {
//      [appsKey release];
      appsKey = @"Applications";
    }

//  [dockApps release];
  
  return appsKey;
}

NSArray *WWMStateDockAppsLoad(void)
{
  return [[WWMStateLoad() objectForKey:@"Dock"] objectForKey:WWMStateDockAppsKey()];
}

void WWMStateDockAppsSave(NSArray *dockIcons)
{
  NSMutableDictionary *wmstateDict = [WWMStateLoad() mutableCopy];
  NSString            *filePath;
      
  [wmstateDict setObject:dockIcons forKey:WWMStateDockAppsKey()];
  if ((filePath = WWMStateCheck()))
    {
      [wmstateDict writeToFile:filePath atomically:YES];
    }
}

NSArray *WWMStateAutostartApps(void)
{
  NSArray        *dockIcons = WWMStateDockAppsLoad();
  NSDictionary   *dIcon;
  NSMutableArray *autostartList = [NSMutableArray new];

  for (dIcon in dockIcons)
    {
      if ([[dIcon objectForKey:@"AutoLaunch"] isEqualToString:@"Yes"])
        {
          [autostartList addObject:dIcon];
        }
    }
  return autostartList;
}

#include <stacking.h>
static WAppIcon *_wAppIconCreate(WWindow *leader_win)
{
  WAppIcon *aicon;

  aicon = wmalloc(sizeof(WAppIcon));
  wretain(aicon);
  aicon->yindex = -1;
  aicon->xindex = -1;
  aicon->prev = NULL;
  aicon->next = NULL;

  if (leader_win->wm_class)
    aicon->wm_class = wstrdup(leader_win->wm_class);

  if (leader_win->wm_instance)
    aicon->wm_instance = wstrdup(leader_win->wm_instance);

  aicon->icon = icon_create_for_wwindow(leader_win);
  
// #ifdef USE_DOCK_XDND
//   wXDNDMakeAwareness(aicon->icon->core->window);
// #endif

  /* will be overriden if docked */
  aicon->icon->core->descriptor.handle_mousedown = appIconMouseDown;
  // aicon->icon->core->descriptor.handle_expose = iconExpose;
  aicon->icon->core->descriptor.parent_type = WCLASS_APPICON;
  aicon->icon->core->descriptor.parent = aicon;
  AddToStackList(aicon->icon->core);
  aicon->icon->show_title = 0;

  return aicon;
}

// wmName is in 'wm_instance.wm_class' format
NSPoint WWMCreateLaunchingIcon(NSString *wmName,
                               NSImage *anImage,
                               NSPoint sourcePoint)
{
  NSPoint  iconPoint = {0, 0};
  BOOL     iconFound = NO;
  WDock    *dock = wScreenWithNumber(0)->dock;
  WAppIcon *icon;
  int      i;
  NSArray    *wmNameParts = [wmName componentsSeparatedByString:@"."];
  const char *wmInstance = [[wmNameParts objectAtIndex:0] cString];
  const char *wmClass = [[wmNameParts objectAtIndex:1] cString];
  
  // 1. Search for icon in dock and set its state to launching
  for (i=0; i < dock->icon_count; i++)
    {
      icon = dock->icon_array[i];
      if (!strcmp(icon->wm_instance, wmInstance) &&
          !strcmp(icon->wm_class, wmClass))
        {
          iconPoint.x = icon->x_pos;
          iconPoint.y = wScreenWithNumber(0)->scr_height - icon->y_pos - 64;

          [[NSApp delegate] slideImage:anImage
                                  from:sourcePoint
                                    to:iconPoint];
          
          icon->launching = 1;
          wAppIconPaint(icon);

          iconFound = YES;
          break;
        }
    }
  
  // 2. Otherwise create appicon and set its state to launching
  /*  if (iconFound == NO)
    {
      Window   leader;
      WWindow  *wLeader;
      WAppIcon *appIcon;

      fprintf(stderr, "*** Creating X window...\n");
      {
        XSizeHints mysizehints;
        XWMHints   mywmhints;
        char       *Geometry = "";
        XClassHint classHint;
        int        dummy = 0, borderwidth = 1;

        // Create a window to hold the stuff
        mysizehints.flags = USSize | USPosition;
        mysizehints.x = 0;
        mysizehints.y = 0;

        XWMGeometry(dpy, DefaultScreen(dpy), Geometry, NULL,
                    borderwidth, &mysizehints,
                    &mysizehints.x, &mysizehints.y,
                    &mysizehints.width, &mysizehints.height, &dummy);

        mysizehints.width = 10;
        mysizehints.height = 10;
        
        leader = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy),
                                     mysizehints.x, mysizehints.y,
                                     mysizehints.width, mysizehints.height,
                                     borderwidth,
                                     BlackPixel(dpy, 0),
                                     WhitePixel(dpy, 0));

        // XSetWMNormalHints(dpy, leader, &mysizehints);
        classHint.res_name = (char *)wmInstance;
        classHint.res_class = (char *)wmClass;
        XSetClassHint(dpy, leader, &classHint);
      }

      fprintf(stderr, "*** X window created\n");
      
      wLeader = wWindowFor(leader);
      fprintf(stderr, "*** WindowMaker window created\n");
      
      // appIcon = _wAppIconCreate(wLeader);

      // fprintf(stderr, "*** Created app icon coordinates: %i.%i\n",
      //         appIcon->x_pos, appIcon->y_pos);
    }*/

  return iconPoint;
}

//--- End of functions which require existing @autorelease pool ---

void WWMWipeDesktop(WScreen * scr)
{
  Window       rootWindow, parentWindow;
  Window       *childrenWindows;
  unsigned int nChildrens, i;
  WWindow      *wwin;
  WApplication *wapp;
    
  XQueryTree(dpy, DefaultRootWindow(dpy),
             &rootWindow, &parentWindow,
             &childrenWindows, &nChildrens);
    
  for (i=0; i < nChildrens; i++)
    {
      wapp = wApplicationOf(childrenWindows[i]);
      if (wapp)
        {
          wwin = wapp->main_window_desc;
          if (!strcmp(wwin->wm_class, "GNUstep"))
            {
              continue;
            }
          else
            {
              if (wwin->protocols.DELETE_WINDOW)
                {
                  wClientSendProtocol(wwin, w_global.atom.wm.delete_window,
                                      w_global.timestamp.last_event);
                }
              else
                {
                  wClientKill(wwin);
                }
            }
        }
    }
  
  XSync(dpy, False);
}

void WWMShutdown(WShutdownMode mode)
{
  int i;

  fprintf(stderr, "*** Shutting down Window Manager...\n");
  
  for (i = 0; i < w_global.screen_count; i++)
    {
      WScreen *scr;

      scr = wScreenWithNumber(i);
      if (scr)
        {
          if (scr->helper_pid)
            {
              kill(scr->helper_pid, SIGKILL);
            }

          wScreenSaveState(scr);

          if (mode == WSKillMode)
            WWMWipeDesktop(scr);
          else
            RestoreDesktop(scr);
        }
      wNETWMCleanup(scr); // Delete _NET_* Atoms
    }
  // ExecExitScript();
  
  RShutdown(); /* wrlib clean exit */
  wutil_shutdown();  /* WUtil clean-up */
}

//-----------------------------------------------------------------------------
// Workspace functions which are called from WindowMaker code.
// Most calls are coming from X11 EventLoop().
// 'XW' prefix is a vector of calls 'WindowMaker(X)->Workspace(W)'
//-----------------------------------------------------------------------------

//--- Application management
NSDictionary *WXApplicationInfoForWApp(WApplication *wapp, WWindow *wwin)
{
  NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
  NSString            *xAppName = nil;
  NSString            *xAppPath = nil;
  int                 app_pid;
  char                *app_command;

  [appInfo setObject:@"YES" forKey:@"IsXWindowApplication"];

  // NSApplicationName = NSString*
  xAppName = [NSString stringWithCString:wapp->main_window_desc->wm_class];
  [appInfo setObject:xAppName forKey:@"NSApplicationName"];

  // NSApplicationProcessIdentifier = NSString*
  if ((app_pid = wNETWMGetPidForWindow(wwin->client_win)) > 0)
    {
      [appInfo setObject:[NSString stringWithFormat:@"%i", app_pid]
        	  forKey:@"NSApplicationProcessIdentifier"];
    }
  else
    {
      [appInfo setObject:@"-1"
        	  forKey:@"NSApplicationProcessIdentifier"];
    }

  // NSApplicationPath = NSString*
  app_command = GetCommandForWindow(wwin->client_win);
  if (app_command != NULL)
    {
      xAppPath = fullPathForCommand([NSString stringWithCString:app_command]);
      if (xAppPath)
        {
          [appInfo setObject:xAppPath
                      forKey:@"NSApplicationPath"];
        }
    }
  else
    {
      [appInfo setObject:@"--" forKey:@"NSApplicationPath"];
    }

  // Get icon image from windowmaker app structure(WApplication)
  // NSApplicationIcon=NSImage*
  NSLog(@"%@ icon filename: %s", xAppName, wapp->app_icon->icon->file);
  if (wapp->app_icon->icon->file_image)
    {
      RImage           *image = wapp->app_icon->icon->file_image;
      NSBitmapImageRep *rep = nil;
      NSImage          *icon = [[NSImage alloc] init];

      rep = [[NSBitmapImageRep alloc]
               initWithBitmapDataPlanes:&image->data
                             pixelsWide:image->width
                             pixelsHigh:image->height
                          bitsPerSample:8
                        samplesPerPixel:(image->format == RRGBAFormat) ? 4 : 3
                               hasAlpha:(image->format == RRGBAFormat) ? YES : NO
                               isPlanar:NO
                         colorSpaceName:NSDeviceRGBColorSpace
                            bytesPerRow:0
                           bitsPerPixel:0];
      [icon addRepresentation:rep];
      [rep release];
      
      [appInfo setObject:icon forKey:@"NSApplicationIcon"];
      [icon release];
    }

  return (NSDictionary *)appInfo;
}

// Will be called by WindowMaker in global queue with high-priority
// (com.apple.root.high-priority)
void XWApplicationDidCreate(WApplication *wapp, WWindow *wwin)
{
  NSNotification *notif = nil;
  NSDictionary   *appInfo = nil;

  if (!strcmp(wapp->main_window_desc->wm_class,"GNUstep"))
    return;

  // fprintf(stderr, "*** New X11 application %s.%s"
  //         " appmain:0x%lx main:0x%lx client:0x%lx group:0x%lx\n", 
  //         wapp->main_window_desc->wm_instance,
  //         wapp->main_window_desc->wm_class,
  //         wapp->main_window_desc->main_window,
  //         wwin->main_window, wwin->client_win, wwin->group_id);

  // NSApplicationName=NSString*
  // NSApplicationProcessIdentifier=NSString*
  // NSApplicationIcon=NSImage*
  // NSApplicationPath=NSString*
  appInfo = WXApplicationInfoForWApp(wapp, wwin);
  NSLog(@"W+WM: XWApplicationDidCreate: %@", appInfo);
  
  notif = [NSNotification 
            notificationWithName:NSWorkspaceDidLaunchApplicationNotification
                          object:appInfo
                        userInfo:appInfo];
  // [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
  [[ProcessManager shared] applicationDidLaunch:notif];
}

void XWApplicationDidAddWindow(WApplication *wapp, WWindow *wwin)
{
  XWApplicationDidCreate(wapp, wwin);
  
  // fprintf(stderr, "*** New window for %s.%s"
  //         " appmain:0x%lx main:0x%lx client:0x%lx group:0x%lx\n",
  //         wapp->main_window_desc->wm_instance,
  //         wapp->main_window_desc->wm_class,
  //         wapp->main_window_desc->main_window,
  //         wwin->main_window, wwin->client_win, wwin->group_id);  
}

void XWApplicationDidDestroy(WApplication *wapp)
{
  NSNotification *notif = nil;
  NSDictionary   *appInfo = nil;

  if (!strcmp(wapp->main_window_desc->wm_class,"GNUstep"))
    return;

  fprintf(stderr, "*** X11 application %s.%s did finished\n", 
          wapp->main_window_desc->wm_instance, 
          wapp->main_window_desc->wm_class);

  appInfo = WXApplicationInfoForWApp(wapp, wapp->main_window_desc);
  NSLog(@"W+WM: XWApplicationDidDestroy: %@", appInfo);
  
  notif = [NSNotification 
            notificationWithName:NSWorkspaceDidTerminateApplicationNotification
                          object:nil
                        userInfo:appInfo];

  // [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
  [[ProcessManager shared] applicationDidTerminate:notif];
}

void XWApplicationDidCloseWindow(WWindow *wwin)
{
  NSNotification *notif;
  NSDictionary   *appInfo;
  
  if (!strcmp(wwin->wm_class,"GNUstep"))
    return;

  // fprintf(stderr, "*** X11 application %s.%s window did closed(destroyed)\n", 
  //         wwin->wm_instance, wwin->wm_class);

  // NSLog(@"W+WM: XWApplicationDidCloseWindow: %s:%i %i %i %i",
  //       wwin->wm_class,
  //       wNETWMGetPidForWindow(wwin->client_win),
  //       wNETWMGetPidForWindow(wwin->main_window),
  //       wNETWMGetPidForWindow(wwin->client_leader),
  //       wNETWMGetPidForWindow(wwin->group_id));
  
  appInfo = [NSDictionary
              dictionaryWithObject:[NSString stringWithCString:wwin->wm_class]
                            forKey:@"NSApplicationName"];
  notif = [NSNotification 
            notificationWithName:WMApplicationDidTerminateSubprocessNotification
                          object:nil
                        userInfo:appInfo];

  // [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
  [[ProcessManager shared] applicationDidTerminateSubprocess:notif];
}

// Used for changing focus to Workspace when no window left to set focus to
// TODO
void xActivateWorkspace(void)
{
  NSLog(@"xActivateWorkspace");
//  [[[NSApp mainMenu] window] makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

// Screen resizing
static void moveDock(WDock *dock, int new_x, int new_y)
{
  WAppIcon *btn;
  WDrawerChain *dc;
  int i;

  if (dock->type == WM_DOCK)
    {
      for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next)
        moveDock(dc->adrawer, new_x, dc->adrawer->y_pos - dock->y_pos + new_y);
    }

  dock->x_pos = new_x;
  dock->y_pos = new_y;
  for (i = 0; i < dock->max_icons; i++)
    {
      btn = dock->icon_array[i];
      if (btn)
        {
          btn->x_pos = new_x + btn->xindex * wPreferences.icon_size;
          btn->y_pos = new_y + btn->yindex * wPreferences.icon_size;
          XMoveWindow(dpy, btn->icon->core->window, btn->x_pos, btn->y_pos);
        }
    }
}

#include <X11/extensions/Xinerama.h>
void XWUpdateScreenInfo(WScreen *scr)
{
  NSRect dRect;
  int    dWidth;

  XLockDisplay(dpy);

  NSLog(@"XRRScreenChangeNotify received, updating applications and WindowMaker...");

  // 1. Update screen dimensions
  scr->scr_width = WidthOfScreen(ScreenOfDisplay(dpy, scr->screen));
  scr->scr_height = HeightOfScreen(ScreenOfDisplay(dpy, scr->screen));
  
  // 2. Update Xinerama heads dimension (-> xinerama.c)
  WXineramaInfo      *info = &scr->xine_info;
  XineramaScreenInfo *xine_screens;

  xine_screens = XineramaQueryScreens(dpy, &info->count);
  for (int i = 0; i < info->count; i++)
    {
      info->screens[i].pos.x = xine_screens[i].x_org;
      info->screens[i].pos.y = xine_screens[i].y_org;
      info->screens[i].size.width = xine_screens[i].width;
      info->screens[i].size.height = xine_screens[i].height;
    }
  XFree(xine_screens);

  // 3. Update WindowMaker info about usable area
  wScreenUpdateUsableArea(scr);

  @autoreleasepool {
    NXScreen *systemScreen = [[NXScreen new] autorelease];
    
    // 4.1 Get info about main display
    dRect = [[systemScreen mainDisplay] frame];
    dWidth = dRect.origin.x + dRect.size.width;
    
    // Save changed layout in user's preferences directory
    [systemScreen saveCurrentDisplayLayout];
  }
  
  // 4.2 Move Dock
  // Place Dock into main display with changed usable area.
  // moveDock(scr->dock,
  //          (scr->scr_width - wPreferences.icon_size - DOCK_EXTRA_SPACE), 0);
  moveDock(scr->dock, (dWidth - wPreferences.icon_size - DOCK_EXTRA_SPACE), 0);
  
  // 5. Move IconYard
  // IconYard is placed into main display automatically.
  wArrangeIcons(scr, True);
  
  // 6. Save Dock state with new position and screen size
  wScreenSaveState(scr);

  // Save changed layout in user's preferences directory
  // [systemScreen saveCurrentDisplayLayout];
 
  // NSLog(@"XRRScreenChangeNotify: END");
  XUnlockDisplay(dpy);

  // NSLog(@"Sending NXScreenDidChangeNotification...");
  // Send notification to active NXScreen applications.
  [[NSDistributedNotificationCenter defaultCenter]
     postNotificationName:NXScreenDidChangeNotification
                   object:nil];
}

#endif //NEXTSPACE
