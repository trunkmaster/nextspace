//============================================================================
// Interface to WindowMaker part. 
// Consists of functions to avoid converting WindowMaker sources to ObjC.
//============================================================================

#ifdef NEXTSPACE

#include <X11/Xlib.h>
#include <X11/Xlocale.h>
#include <X11/Xatom.h>
#include <X11/extensions/Xinerama.h>

#include <wraster.h>
#include <startup.h>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <NXAppKit/NXAlert.h>
#import <NXSystem/NXScreen.h>
#import <NXSystem/NXSystemInfo.h>

#import "Workspace+WindowMaker.h"
#import "Controller.h"
#import "Operations/ProcessManager.h"

// WindowMaker functions and vars
extern Display *dpy;
extern char *GetCommandForWindow(Window win);
// WindowMaker/src/main.c
extern int real_main(int argc, char **argv);

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
//------------------------------------------------------------------------------

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
  wPreferences.flags.nodock = 0;
  wPreferences.flags.noclip = 1;
  wPreferences.flags.nodrawer = 1;

  // DISPLAY environment var
  DisplayName = XDisplayName(DisplayName);
  len = strlen(DisplayName) + 64;
  str = wmalloc(len);
  snprintf(str, len, "DISPLAY=%s", DisplayName);
  putenv(str);

  @autoreleasepool {
    // Check WMState user file (Dock state)
    if (WWMDockStatePath() == nil)
      {
        NSLog(@"[Workspace] Dock contents cannot be restored."
              " Show only Workspace application icon.");
      }
    // Restore display layout
    [[[NXScreen new] autorelease] applySavedDisplayLayout];
  }

  // external function (WindowMaker/src/main.c)
  real_main(argc, argv);
  
  // Just load saved Dock state without icons drawing.
  WWMDockInit();

  //--- Below this point WindowMaker was initialized

  // TODO: go through all screens
  // Adjust WM elements placing
  XWUpdateScreenInfo(wScreenWithNumber(0));

  WWMDockShowIcons(wScreenWithNumber(0)->dock);

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

// --- Logout
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

  if (launchingIcons) free(launchingIcons);
  
  RShutdown(); /* wrlib clean exit */
  wutil_shutdown();  /* WUtil clean-up */
}

// ----------------------------
// --- Icon Yard
// ----------------------------
void WWMIconYardShowIcons(WScreen *screen)
{
  WAppIcon *appicon = screen->app_icon_list;
  WWindow  *w_window;
  
  // Miniwindows
  w_window = screen->focused_window;
  while (w_window) {
    if (w_window && w_window->icon) {
      XMapWindow(dpy, w_window->icon->core->window);
    }
    w_window = w_window->prev;
  }
  
  // Appicons
  appicon = screen->app_icon_list;
  while (appicon) {
    if (!appicon->docked) {
      XMapWindow(dpy, appicon->icon->core->window);
    }
    appicon = appicon->next;
  }
  
  XSync(dpy, False);
}
void WWMIconYardHideIcons(WScreen *screen)
{
  WAppIcon *appicon = screen->app_icon_list;
  WWindow  *w_window;

  // Miniwindows
  w_window = screen->focused_window;
  while (w_window) {
    if (w_window && w_window->icon) {
      XUnmapWindow(dpy, w_window->icon->core->window);
    }
    w_window = w_window->prev;
  }

  // Appicons
  appicon = screen->app_icon_list;
  while (appicon) {
    if (!appicon->docked) {
      XUnmapWindow(dpy, appicon->icon->core->window);
    }
    appicon = appicon->next;
  }
  
  XSync(dpy, False);
}

// ----------------------------
// --- Dock
// ----------------------------

// --- Init
#import "Recycler.h"
void WWMDockInit(void)
{
  WDock      *dock = wScreenWithNumber(0)->dock;
  WMPropList *state;
  WAppIcon   *btn;
  NSString   *iconName;
  NSString   *iconPath;

  // Setup main button properties to let Dock correctrly register Workspace
  btn = dock->icon_array[0];
  btn->wm_class = "GNUstep";
  btn->wm_instance = "Workspace";
  btn->command = "Workspace Manager";
  btn->auto_launch = 0; // disable autolaunch by WindowMaker's functions
  btn->launching = 1;   // tell Dock to wait for Workspace
  btn->running = 0;     // ...and we're not running yet
  btn->lock = 1;
  wAppIconPaint(btn);

  // Set icon image before GNUstep application sets it
  iconName = [NSString stringWithCString:APP_ICON];
  iconPath = [[NSBundle mainBundle] pathForImageResource:iconName];
  if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath] == YES)
    WWMSetDockAppImage(iconPath, 0, NO);

  // Setup Recycler icon
  [RecyclerIcon recyclerAppIconForDock:dock];
  
  launchingIcons = NULL;
}
void WWMDockShowIcons(WDock *dock)
{
  if (dock == NULL || dock->mapped) {
    return;
  }
  for (int i = 0; i < (dock->collapsed ? 1 : dock->max_icons); i++) {
    if (dock->icon_array[i]) {
      XMapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  }
  XSync(dpy, False);
  dock->mapped = 1;
}
void WWMDockHideIcons(WDock *dock)
{
  if (dock == NULL || !dock->mapped) {
    return;
  }
  for (int i = 0; i < (dock->collapsed ? 1 : dock->max_icons); i++) {
    if (dock->icon_array[i]) {
      XUnmapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  }
  XSync(dpy, False);
  dock->mapped = 0;
}
void WWMDockUncollapse(WDock *dock)
{
  if (dock == NULL || !dock->collapsed) {
    return;
  }
  for (int i = 1; i < dock->max_icons; i++) {
    if (dock->icon_array[i]) {
      XMapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  }
  XSync(dpy, False);
  dock->collapsed = 0;
}
void WWMDockCollapse(WDock *dock)
{
  if (dock == NULL || dock->collapsed || !dock->mapped) {
    return;
  }
  for (int i = 1; i < dock->max_icons; i++) {
    if (dock->icon_array[i]) {
      XUnmapWindow(dpy, dock->icon_array[i]->icon->core->window);
    }
  }
  XSync(dpy, False);
  dock->collapsed = 1;
}

// -- Should be called from already existing @autoreleasepool ---

// Returns path to user WMState if exist.
// Returns 'nil' if user WMState doesn't exist and cannot
// be recovered from Workspace.app/WindowMaker directory.
NSString *WWMDockStatePath(void)
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

// Saves dock on-screen state into WMState file
void WWMDockStateSave(void)
{
  // WScreen    *scr = NULL;
  // WMPropList *old_state = NULL;

  for (int i = 0; i < w_global.screen_count; i++)
    {
      wScreenSaveState(wScreenWithNumber(i));
      // scr = wScreenWithNumber(i);
      // old_state = scr->session_state;
      // scr->session_state = WMCreatePLDictionary(NULL, NULL);
      
      // wDockSaveState(scr, old_state);
      // WMReleasePropList(old_state);
      // wDockSaveState(scr, scr->session_state);
    }
}

// Returns NSDictionary representation of WMState file
NSDictionary *WWMDockState(void)
{
  NSDictionary *wmState;

  wmState = [[NSDictionary alloc] initWithContentsOfFile:WWMDockStatePath()];

  return [wmState autorelease];
}

NSArray *WWMDockStateApps(void)
{
  NSArray  *dockApps;
  NSString *appsKey;
      
  appsKey = [NSString stringWithFormat:@"Applications%i",
                      wScreenWithNumber(0)->scr_height];
  
  dockApps = [[WWMDockState() objectForKey:@"Dock"] objectForKey:appsKey];
  if (!dockApps || [dockApps count] == 0)
    {
      [[WWMDockState() objectForKey:@"Dock"] objectForKey:@"Applications"];
    }

  return dockApps;
}

void WWMDockAutoLaunch(WDock *dock)
{
  WAppIcon    *btn;
  WSavedState *state;
  char        *command = NULL;
  NSString    *cmd;

  for (int i = 0; i < dock->max_icons; i++)
    {
      btn = dock->icon_array[i];

      if (!btn || !btn->auto_launch ||
          !btn->command || btn->running || btn->launching)
        continue;

      state = wmalloc(sizeof(WSavedState));
      state->workspace = 0;
      btn->drop_launch = 0;
      btn->paste_launch = 0;

      // Add '-NXAutoLaunch YES' to GNUstep application parameters
      if (!strcmp(btn->wm_class, "GNUstep"))
        {
          cmd = [NSString stringWithCString:btn->command];
          if ([cmd rangeOfString:@"NXAutoLaunch"].location == NSNotFound)
            {
              cmd = [cmd stringByAppendingString:@" -NXAutoLaunch YES"];
            }
          command = wstrdup(btn->command);
          wfree(btn->command);
          btn->command = wstrdup([cmd cString]);
        }

      wDockLaunchWithState(btn, state);

      // Return 'command' field into initial state (without -NXAutoLaunch)
      if (!strcmp(btn->wm_class, "GNUstep"))
        {
          wfree(btn->command);
          btn->command = wstrdup(command);
          wfree(command);
          command = NULL;
        }
    }  
}

// --- Appicons getters/setters of on-screen Dock

NSInteger WWMDockAppsCount(void)
{
  WScreen *scr = wScreenWithNumber(XDefaultScreen(dpy));
  WDock   *dock = scr->dock;

  if (!dock)
    return 0;
  else
    return dock->max_icons;
    // return dock->icon_count;
}

WAppIcon *_appiconInDockPosition(int position)
{
  WScreen  *scr = wScreenWithNumber(XDefaultScreen(dpy));
  WDock    *dock = scr->dock;

  if (!dock || position > dock->max_icons-1)
    return NULL;

  for (int i=0; i < dock->max_icons; i++)
    {
      if (!dock->icon_array[i])
        continue;
      
      if (dock->icon_array[i]->yindex == position)
        return dock->icon_array[i];
    }
  
  return NULL;
}

NSString *WWMDockAppName(int position)
{
  WAppIcon *appicon = _appiconInDockPosition(position);

  if (appicon)
    return [NSString stringWithFormat:@"%s.%s",
                     appicon->wm_instance, appicon->wm_class];
  else
    return @".NoApplication";
}

NSImage *_imageForRasterImage(RImage *r_image)
{
  BOOL		   hasAlpha = (r_image->format == RRGBAFormat) ? YES : NO;
  NSBitmapImageRep *rep = nil;
  NSImage          *image = nil;

  rep = [[NSBitmapImageRep alloc]
               initWithBitmapDataPlanes:&r_image->data
                             pixelsWide:r_image->width
                             pixelsHigh:r_image->height
                          bitsPerSample:8
                        samplesPerPixel:hasAlpha ? 4 : 3
                               hasAlpha:hasAlpha
                               isPlanar:NO
                         colorSpaceName:NSDeviceRGBColorSpace
                            bytesPerRow:0
                           bitsPerPixel:hasAlpha ? 32 : 24];

  if (rep)
    {
      image = [[NSImage alloc] init];
      [image addRepresentation:rep];
      [rep release];
    }

  return [image autorelease];
}

char *XWSaveRasterImageAsTIFF(RImage *r_image, char *file_path)
{
  NSImage  *image = _imageForRasterImage(r_image);
  NSData   *tiffRep = [image TIFFRepresentation];
  NSString *filePath;

  filePath = [NSString stringWithCString:file_path];
  wfree(file_path);
  
  if (![[filePath pathExtension] isEqualToString:@"tiff"])
    {
      filePath = [filePath stringByDeletingPathExtension];
      filePath = [filePath stringByAppendingPathExtension:@"tiff"];
    }
  
  [tiffRep writeToFile:filePath atomically:YES];
  [image release];

  return wstrdup([filePath cString]);
}

NSImage *WWMDockAppImage(int position)
{
  WAppIcon     *btn = _appiconInDockPosition(position);
  NSString     *iconPath;
  NSString     *appName;
  NSDictionary *appDesc;
  NSImage      *icon = nil;

  if (btn)
    {
      // NSLog(@"W+W: icon image file: %s", btn->icon->file);
      if (btn->icon->file)
        { // Docked and not running application
          iconPath = [NSString stringWithCString:btn->icon->file];
          icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
          [icon autorelease];
        }
      else
        {
          if (!strcmp(btn->wm_class, "GNUstep"))
            appName = [NSString stringWithCString:btn->wm_instance];
          else
            appName = [NSString stringWithCString:btn->wm_class];
          
          appDesc = [[ProcessManager shared] _applicationWithName:appName];
          
          if (!strcmp(btn->wm_class, "GNUstep"))
            {
              icon = [[NSApp delegate]
                       iconForFile:[appDesc objectForKey:@"NSApplicationPath"]];
            }
          else
            {
              icon = [appDesc objectForKey:@"NSApplicationIcon"];
            }
        }
      if (!icon)
        icon = [NSImage imageNamed:@"NXUnknownApplication"];
    }
  
  return icon;
}
void WWMSetDockAppImage(NSString *path, int position, BOOL save)
{
  WDock    *dock = wScreenWithNumber(0)->dock;
  WAppIcon *btn;
  RImage   *rimage;

  for (int i = 0; i < wScreenWithNumber(0)->dock->max_icons; i++)
    {
      btn = dock->icon_array[i];
      if (btn->yindex == position)
        break;
    }
  
  if (btn->icon->file)
    {
      wfree(btn->icon->file);
    }
  btn->icon->file = wstrdup([path cString]);

  rimage = RLoadImage(wScreenWithNumber(0)->rcontext, btn->icon->file, 0);

  if (!rimage)
    return;
  
  if (btn->icon->file_image)
    {
      RReleaseImage(btn->icon->file_image);
      btn->icon->file_image = NULL;
    }
  btn->icon->file_image = RRetainImage(rimage);
  
  // Write to WindowMaker 'WMWindowAttributes' file
  if (save == YES)
    {
      NSMutableDictionary *wa, *appAttrs;
      NSString *waPath, *appKey;

      waPath = [WWMDockStatePath() stringByDeletingLastPathComponent];
      waPath = [waPath stringByAppendingPathComponent:@"WMWindowAttributes"];
  
      wa = [[NSMutableDictionary alloc] initWithContentsOfFile:waPath];
      appKey = [NSString stringWithFormat:@"%s.%s",
                         btn->wm_instance, btn->wm_class];
      appAttrs = [wa objectForKey:appKey];
      if (!appAttrs)
        appAttrs = [NSMutableDictionary new];
  
      [appAttrs setObject:[NSString stringWithCString:btn->icon->file]
                   forKey:@"Icon"];
      [appAttrs setObject:@"YES" forKey:@"AlwaysUserIcon"];

      if (position == 0)
        {
          [wa setObject:appAttrs forKey:@"Logo.WMDock"];
          [wa setObject:appAttrs forKey:@"Logo.WMPanel"];
        }
  
      [wa setObject:appAttrs forKey:appKey];
      [wa writeToFile:waPath atomically:YES];
      [wa release];
    }
  
  wIconUpdate(btn->icon);
}

BOOL WWMIsDockAppAutolaunch(int position)
{
  WAppIcon *appicon = _appiconInDockPosition(position);
    
  if (!appicon || appicon->auto_launch == 0)
    return NO;
  else
    return YES;
}
void WWMSetDockAppAutolaunch(int position, BOOL autolaunch)
{
  WAppIcon *appicon = _appiconInDockPosition(position);
    
  if (appicon)
    {
      appicon->auto_launch = (autolaunch == YES) ? 1 : 0;
      WWMDockStateSave();
    }
}

BOOL WWMIsDockAppLocked(int position)
{
  WAppIcon *appicon = _appiconInDockPosition(position);
    
  if (!appicon || appicon->lock == 0)
    return NO;
  else
    return YES;
}
void WWMSetDockAppLocked(int position, BOOL lock)
{
  WAppIcon *appicon = _appiconInDockPosition(position);
    
  if (appicon)
    {
      appicon->lock = (lock == YES) ? 1 : 0;
      WWMDockStateSave();
    }
}

NSString *WWMDockAppCommand(int position)
{
  WAppIcon *appicon = _appiconInDockPosition(position);

  if (appicon)
    return [NSString stringWithCString:appicon->command];
  else
    return nil;
}
void WWMSetDockAppCommand(int position, const char *command)
{
  WAppIcon *appicon = _appiconInDockPosition(position);
  
  if (appicon)
    {
      wfree(appicon->command);
      appicon->command = wstrdup(command);
      WWMDockStateSave();
    }
}

NSString *WWMDockAppPasteCommand(int position)
{
  WAppIcon *appicon = _appiconInDockPosition(position);

  if (appicon)
    return [NSString stringWithCString:appicon->paste_command];
  else
    return nil;
}
void WWMSetDockAppPasteCommand(int position, const char *command)
{
  WAppIcon *appicon = _appiconInDockPosition(position);
  
  if (appicon)
    {
      wfree(appicon->paste_command);
      appicon->paste_command = wstrdup(command);
      WWMDockStateSave();
    }
}

NSString *WWMDockAppDndCommand(int position)
{
  WAppIcon *appicon = _appiconInDockPosition(position);

  if (appicon)
    return [NSString stringWithCString:appicon->dnd_command];
  else
    return nil;
}
void WWMSetDockAppDndCommand(int position, const char *command)
{
  WAppIcon *appicon = _appiconInDockPosition(position);
  
  if (appicon)
    {
      wfree(appicon->dnd_command);
      appicon->dnd_command = wstrdup(command);
      WWMDockStateSave();
    }
}

// ----------------------------
// --- Launching appicons
// ----------------------------

// It is array of pointers to WAppIcon.
// These pointers also placed into WScreen->app_icon_list.
// Launching icons number is much smaller, but I use DOCK_MAX_ICONS
// (defined in WindowMaker/src/wconfig.h) as references number.
// static WAppIcon **launchingIcons = NULL;
void _AddLaunchingIcon(WAppIcon *appicon)
{
  if (!launchingIcons)
    launchingIcons = wmalloc(DOCK_MAX_ICONS * sizeof(WAppIcon*));
  
  for (int i=0; i < DOCK_MAX_ICONS; i++)
    {
      if (launchingIcons[i] == NULL)
        {
          launchingIcons[i] = appicon;
          RemoveFromStackList(appicon->icon->core);
          break;
        }
    }
}
void _RemoveLaunchingIcon(WAppIcon *appicon)
{
  WAppIcon *licon;
  
  for (int i=0; i < DOCK_MAX_ICONS; i++)
    {
      licon = launchingIcons[i];
      if (licon && (licon == appicon))
        {
          AddToStackList(appicon->icon->core);
          launchingIcons[i] = NULL;
          break;
        }
    }
}
WAppIcon *_FindLaunchingIcon(char *wm_instance, char *wm_class)
{
  WAppIcon *licon, *aicon = NULL;

  if (!launchingIcons)
    return aicon;
  
  for (int i=0; i < DOCK_MAX_ICONS; i++)
    {
      licon = launchingIcons[i];
      if (licon &&
          !strcmp(wm_instance, licon->wm_instance) &&
          !strcmp(wm_class, licon->wm_class))
        {
          aicon = licon;
          break;
        }
    }

  return aicon;
}
NSPoint _pointForNewLaunchingIcon(int *x_ret, int *y_ret)
{
  WScreen  *scr = wScreenWithNumber(0);
  NSRect   mdRect = [[[NXScreen sharedScreen] mainDisplay] frame];
  NSPoint  iconPoint = {0,0};
  WAppIcon *appIcon;

  if (!launchingIcons)
    {
      *x_ret = 0;
      *y_ret = mdRect.size.height - ICON_HEIGHT;
      return iconPoint;
    }

  // Add all launch icons to stack list to calculate position for new one
  for (int i=0; i < DOCK_MAX_ICONS; i++)
    {
      appIcon = launchingIcons[i];
      if (appIcon)
        AddToStackList(appIcon->icon->core);
    }
  
  // Calculate postion for new launch icon
  PlaceIcon(wScreenWithNumber(0), x_ret, y_ret, 0);
  iconPoint.x = (CGFloat)*x_ret;
  iconPoint.y = mdRect.size.height - (*y_ret + ICON_HEIGHT);

  // Remove all launch icons from stack list to place appicons over them
  for (int i=0; i < DOCK_MAX_ICONS; i++)
    {
      appIcon = launchingIcons[i];
      if (appIcon)
        RemoveFromStackList(appIcon->icon->core);
    }

  return iconPoint;
}
// wmName is in 'wm_instance.wm_class' format
static NSLock *raceLock = nil;
WAppIcon *WWMCreateLaunchingIcon(NSString *wmName, NSImage *anImage,
                                 NSPoint sourcePoint,
                                 NSString *imagePath)
{
  NSPoint    iconPoint = {0, 0};
  BOOL       iconFound = NO;
  WScreen    *scr = wScreenWithNumber(0);
  WAppIcon   *appIcon;
  NSArray    *wmNameParts = [wmName componentsSeparatedByString:@"."];
  const char *wmInstance = [[wmNameParts objectAtIndex:0] cString];
  const char *wmClass = [[wmNameParts objectAtIndex:1] cString];

  if (!raceLock) raceLock = [NSLock new];
  [raceLock lock];

  // NSLog(@"Create icon for: %s.%s", wmInstance, wmClass);
  
  // 1. Search for existing icon in IconYard and Dock
  appIcon = scr->app_icon_list;
  while (appIcon->next)
    {
      // NSLog(@"Analyzing: %s.%s", appIcon->wm_instance, appIcon->wm_class);
      if (!strcmp(appIcon->wm_instance, wmInstance) &&
          !strcmp(appIcon->wm_class, wmClass))
        {
          iconPoint.x = appIcon->x_pos + ((ICON_WIDTH - [anImage size].width)/2);
          iconPoint.y = wScreenWithNumber(0)->scr_height - appIcon->y_pos - 64;
          iconPoint.y += (ICON_WIDTH - [anImage size].width)/2;
          [[NSApp delegate] slideImage:anImage
                                  from:sourcePoint
                                    to:iconPoint];
          if (appIcon->docked && !appIcon->running)
            {
              appIcon->launching = 1;
              wAppIconPaint(appIcon);
            }
          iconFound = YES;
          break;
        }
      appIcon = appIcon->next;
    }

  // 2. Otherwise create appicon and set its state to launching
  if (iconFound == NO)
    {
      NSRect mdRect = [[[NXScreen sharedScreen] mainDisplay] frame];
      int    x_ret = 0, y_ret = 0;
      
      appIcon = wAppIconCreateForDock(wScreenWithNumber(0), NULL,
                                      (char *)wmInstance, (char *)wmClass,
                                      TILE_NORMAL);
      appIcon->icon->core->descriptor.handle_mousedown = NULL;
      appIcon->launching = 1;
      _AddLaunchingIcon(appIcon);
      wIconChangeImageFile(appIcon->icon, [imagePath cString]);
      // NSLog(@"First icon in launching list for: %s.%s",
      //       launchingIcons->wm_instance, launchingIcons->wm_class);

      iconPoint = _pointForNewLaunchingIcon(&x_ret, &y_ret);
      wAppIconMove(appIcon, x_ret, y_ret);
      // NSLog(@"[Workspace] new icon point for '%@': %i.%i",
      //       wmName, appIcon->x_pos, appIcon->y_pos);
      
      [[NSApp delegate] slideImage:anImage
                              from:sourcePoint
                                to:iconPoint];

      wAppIconPaint(appIcon);
      XMapWindow(dpy, appIcon->icon->core->window);
      XSync(dpy, False);      
    }
  
  [raceLock unlock];
  
  return appIcon;
}

void WWMDestroyLaunchingIcon(WAppIcon *appIcon)
{
  _RemoveLaunchingIcon(appIcon);
  wAppIconDestroy(appIcon);
}

//--- End of functions which require existing @autorelease pool ---

//-----------------------------------------------------------------------------
// Workspace functions which are called from WindowMaker code.
// Most calls are coming from X11 EventLoop().
// 'XW' prefix is a vector of calls 'WindowMaker(X)->Workspace(W)'
// All the functions below are executed insise 'wwmaker_q' GCD queue.
//-----------------------------------------------------------------------------

//--- Application management
NSDictionary *_applicationInfoForWApp(WApplication *wapp, WWindow *wwin)
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
  else if ((app_pid = wapp->app_icon->pid) > 0)
    {
      [appInfo setObject:[NSString stringWithFormat:@"%i", app_pid]
        	  forKey:@"NSApplicationProcessIdentifier"];
    }
  else
    {
      [appInfo setObject:@"-1" forKey:@"NSApplicationProcessIdentifier"];
    }

  // NSApplicationPath = NSString*
  app_command = GetCommandForWindow(wwin->client_win);
  if (app_command != NULL)
    {
      xAppPath = fullPathForCommand([NSString stringWithCString:app_command]);
      if (xAppPath)
        [appInfo setObject:xAppPath forKey:@"NSApplicationPath"];
      else
        [appInfo setObject:[NSString stringWithCString:app_command]
                    forKey:@"NSApplicationPath"];
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
      [appInfo setObject:_imageForRasterImage(wapp->app_icon->icon->file_image)
                  forKey:@"NSApplicationIcon"];
    }

  return (NSDictionary *)appInfo;
}

// Called by WindowMaker in GCD global high-priority queue
// (com.apple.root.high-priority)
void XWApplicationDidCreate(WApplication *wapp, WWindow *wwin)
{
  NSNotification *notif = nil;
  NSDictionary   *appInfo = nil;
  char           *wm_instance, *wm_class;
  WAppIcon       *appIcon;

  wm_instance = wapp->main_window_desc->wm_instance;
  wm_class = wapp->main_window_desc->wm_class;
  appIcon = _FindLaunchingIcon(wm_instance, wm_class);
  if (appIcon)
    {
      WWMDestroyLaunchingIcon(appIcon);
    }
  
  if (!strcmp(wm_class,"GNUstep"))
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
  appInfo = _applicationInfoForWApp(wapp, wwin);
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
  // XWApplicationDidCreate(wapp, wwin);
  
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

  appInfo = _applicationInfoForWApp(wapp, wapp->main_window_desc);
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
    scr->scr_width = (int)[systemScreen sizeInPixels].width;
    scr->scr_height = (int)[systemScreen sizeInPixels].height;
    
    // Save changed layout in user's preferences directory
    // [systemScreen saveCurrentDisplayLayout];
  }
  
  // 4.2 Move Dock
  // Place Dock into main display with changed usable area.
  [RecyclerIcon recyclerAppIconForDock:scr->dock];
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

// TODO: Use for changing focus to Workspace when no window left to set focus to
void XWWorkspaceDidChange(WScreen *scr, int workspace)
{
  [[NSApp delegate] updateWorkspaceBadge];
  // [NSApp activateIgnoringOtherApps:YES];
  // [[[NSApp mainMenu] window] makeKeyAndOrderFront:nil];
}

void XWDockContentDidChange(WDock *dock)
{
  NSNotification *notif;
  
  notif = [NSNotification 
            notificationWithName:@"WMDockContentDidChange"
                          object:nil
                        userInfo:nil];

  [[NSNotificationCenter defaultCenter] postNotification:notif];
}

#endif //NEXTSPACE
