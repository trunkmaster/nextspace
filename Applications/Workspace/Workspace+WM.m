/* -*- mode: objc -*- */
//
// Interface to Window Manager part of Workspace application. 
// Consists of functions to avoid converting WindowMaker sources to ObjC.
//
// Project: Workspace
//
// Copyright (C) 2014-2019 Sergii Stoian
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

#include <X11/Xlib.h>
#include <X11/Xlocale.h>
#include <X11/Xatom.h>

#include <wraster.h>
#include <core/wappresource.h>
#include <core/util.h>
#include <core/stringutils.h>
#include <core/wuserdefaults.h>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <DesktopKit/NXTDefaults.h>
#import <DesktopKit/NXTAlert.h>
#import <SoundKit/NXTSound.h>
#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSESystemInfo.h>
#import <SystemKit/OSEKeyboard.h>

#import "Workspace+WM.h"
#import "Controller.h"
#import "Operations/ProcessManager.h"

// #include <WM.h>

NSString *WMShowAlertPanel = @"WMShowAlertPanelNotification";
dispatch_queue_t workspace_q;
WorkspaceExitCode ws_quit_code;
static WAppIcon **launchingIcons;

// WM functions and vars
extern Display *dpy;
// extern char *GetCommandForWindow(Window win);

// TODO: Move to DesktopKit/NXTFileManager
NSString *fullPathForCommand(NSString *command)
{
  NSString      *commandFile;
  NSString      *envPath;
  NSEnumerator  *e;
  NSString      *path;
  NSFileManager *fm;

  if ([command isAbsolutePath]) {
    return command;
  }

  commandFile = [[command componentsSeparatedByString:@" "] objectAtIndex:0];
  // commandFile = [command lastPathComponent];
  envPath = [NSString stringWithCString:getenv("PATH")];
  e = [[envPath componentsSeparatedByString:@":"] objectEnumerator];
  fm = [NSFileManager defaultManager];

  while ((path = [e nextObject])) {
    if ([[fm directoryContentsAtPath:path] containsObject:commandFile]) {
      return [path stringByAppendingPathComponent:commandFile];
    }
  }

  return nil;
}

//-----------------------------------------------------------------------------
// Window Manager(WM) releated functions: call WM's functions, change
// WM's behaviour, change WM's runtime variables.
//------------------------------------------------------------------------------

void WMSetupFrameOffsetProperty()
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
  
  XChangeProperty(dpy, wDefaultScreen()->root_win,
                  XInternAtom(dpy, "_GNUSTEP_FRAME_OFFSETS", False),
                  XA_CARDINAL, 16, PropModeReplace,
                  (unsigned char *)offsets, 60);
}

// --- Logout
void WMWipeDesktop(WScreen * scr)
{
  Window       rootWindow, parentWindow;
  Window       *childrenWindows;
  unsigned int nChildrens, i;
  WWindow      *wwin;
  WApplication *wapp;
    
  XQueryTree(dpy, DefaultRootWindow(dpy),
             &rootWindow, &parentWindow,
             &childrenWindows, &nChildrens);
    
  for (i=0; i < nChildrens; i++) {
    wapp = wApplicationOf(childrenWindows[i]);
    if (wapp) {
      wwin = wapp->main_window_desc;
      if (!strcmp(wwin->wm_class, "GNUstep")) {
        continue;
      }
      else {
        if (wwin->protocols.DELETE_WINDOW) {
          wClientSendProtocol(wwin, w_global.atom.wm.delete_window,
                              w_global.timestamp.last_event);
        }
        else {
          wClientKill(wwin);
        }
      }
    }
  }

  XSync(dpy, False);
}

void WMShutdown(WShutdownMode mode)
{
  int i;
  WScreen *scr;

  fprintf(stderr, "*** Shutting down Window Manager...\n");
  
  scr = wDefaultScreen();
  if (scr) {
    if (scr->helper_pid) {
      kill(scr->helper_pid, SIGKILL);
    }

    wScreenSaveState(scr);

    if (mode == WSKillMode)
      WMWipeDesktop(scr);
    else
      RestoreDesktop(scr);
  }
  wNETWMCleanup(scr); // Delete _NET_* Atoms
  // ExecExitScript();

  if (launchingIcons) free(launchingIcons);
  
  RShutdown(); /* wrlib clean exit */
  wutil_shutdown();  /* WUtil clean-up */
}

// --- Defaults
NSString *WMDefaultsPath(void)
{
  NSString      *userDefPath, *appDefPath;
  NSFileManager *fm = [NSFileManager defaultManager];

  userDefPath = [NSString stringWithFormat:@"%@/.WindowMaker/WindowMaker",
                          GSDefaultsRootForUser(NSUserName())];
  
  if (![fm fileExistsAtPath:userDefPath]) {
    appDefPath = [[NSBundle mainBundle] pathForResource:@"WindowMaker"
                                                 ofType:nil
                                            inDirectory:@"WindowMaker"];
    if (![fm fileExistsAtPath:appDefPath]) {
      return nil;
    }
    
    [fm copyItemAtPath:appDefPath toPath:userDefPath error:NULL];
  }

  return userDefPath;
}

// ----------------------------
// --- Icon Yard
// ----------------------------
void WMIconYardShowIcons(WScreen *screen)
{
  WAppIcon *appicon = screen->app_icon_list;
  WWindow  *w_window;

  // Miniwindows
  w_window = screen->focused_window;
  while (w_window) {
    if (w_window && w_window->flags.miniaturized &&
        w_window->icon && !w_window->icon->mapped ) {
      XMapWindow(dpy, w_window->icon->core->window);
      w_window->icon->mapped = 1;
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
  screen->flags.icon_yard_mapped = 1;
  // wArrangeIcons(screen, True);
}
void WMIconYardHideIcons(WScreen *screen)
{
  WAppIcon *appicon = screen->app_icon_list;
  WWindow  *w_window;

  // Miniwindows
  w_window = screen->focused_window;
  while (w_window) {
    if (w_window && w_window->flags.miniaturized &&
        w_window->icon && w_window->icon->mapped ) {
      XUnmapWindow(dpy, w_window->icon->core->window);
      w_window->icon->mapped = 0;
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
  screen->flags.icon_yard_mapped = 0;
}

// ----------------------------
// --- Dock
// ----------------------------

void WMSetDockAppImage(NSString *path, int position, BOOL save)
{
  WAppIcon *btn;
  RImage   *rimage;

  btn = wDockAppiconAtSlot(wDefaultScreen()->dock, position);
  if (!btn) {
    return;
  }
  
  if (btn->icon->file) {
    wfree(btn->icon->file);
  }
  btn->icon->file = wstrdup([path cString]);

  rimage = RLoadImage(wDefaultScreen()->rcontext, btn->icon->file, 0);
  if (!rimage) {
    return;
  }
  
  if (btn->icon->file_image) {
    RReleaseImage(btn->icon->file_image);
    btn->icon->file_image = NULL;
  }
  btn->icon->file_image = RRetainImage(rimage);
  
  // Write to WM's 'WMWindowAttributes' file
  if (save == YES) {
    CFMutableDictionaryRef winAttrs, appAttrs;
    CFStringRef appKey, iconFile;

    winAttrs = w_global.domain.window_attr->dictionary;

    appKey = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%s.%s"),
                                      btn->wm_instance, btn->wm_class);
    appAttrs = (CFMutableDictionaryRef)CFDictionaryGetValue(winAttrs, appKey);
    if (!appAttrs) {
      appAttrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
                                           &kCFTypeDictionaryKeyCallBacks,
                                           &kCFTypeDictionaryValueCallBacks);
    }
    iconFile = CFStringCreateWithCString(kCFAllocatorDefault, btn->icon->file,
                                         kCFStringEncodingUTF8);
    CFDictionarySetValue(appAttrs, CFSTR("Icon"), iconFile);
    CFRelease(iconFile);
    CFDictionarySetValue(appAttrs, CFSTR("AlwaysUserIcon"), CFSTR("YES"));

    if (position == 0) {
      CFDictionarySetValue(winAttrs, CFSTR("Logo.WMDock"), appAttrs);
      CFDictionarySetValue(winAttrs, CFSTR("Logo.WMPanel"), appAttrs);
    }
  
    CFDictionarySetValue(winAttrs, appKey, appAttrs);
    CFRelease(appKey);
    CFRelease(appAttrs);
    WMUserDefaultsWrite(winAttrs, CFSTR("WMWindowAttributes"));
  }
  
  wIconUpdate(btn->icon);
}

BOOL WMIsDockAppAutolaunch(int position)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);
    
  if (!appicon || appicon->auto_launch == 0) {
    return NO;
  }
  else {
    return YES;
  }
}

// --- Init
#import "Recycler.h"
void WMDockInit(void)
{
  WDock    *dock = wDefaultScreen()->dock;
  WAppIcon *btn;
  NSString *iconName;
  NSString *iconPath;

  // Set icon image before GNUstep application sets it
  iconName = [NSString stringWithCString:APP_ICON];
  iconPath = [[NSBundle mainBundle] pathForImageResource:iconName];
  if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath] == YES)
    WMSetDockAppImage(iconPath, 0, NO);

  // Setup main button properties to let Dock correctrly register Workspace
  btn = dock->icon_array[0];
  btn->wm_class = "GNUstep";
  btn->wm_instance = "Workspace";
  btn->command = "Workspace Manager";
  // btn->auto_launch = 1; // disable autolaunch by WindowMaker's functions
  btn->launching = 1;   // tell Dock to wait for Workspace
  btn->running = 0;     // ...and we're not running yet
  btn->lock = 1;
  wAppIconPaint(btn);

  // Setup Recycler icon
  [RecyclerIcon recyclerAppIconForDock:dock];
  
  launchingIcons = NULL;
}
void WMDockShowIcons(WDock *dock)
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
void WMDockHideIcons(WDock *dock)
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
void WMDockUncollapse(WDock *dock)
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
void WMDockCollapse(WDock *dock)
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

int WSDockMaxIcons(WScreen *scr)
{
  WMRect head_rect = wGetRectForHead(scr, scr->xrandr_info.primary_head);
  
  return head_rect.size.height / wPreferences.icon_size;
}
enum {
  KeepOnTop = NSDockWindowLevel,
  Normal = NSNormalWindowLevel,
  AutoRaiseLower = NSDesktopWindowLevel
};
int WSDockLevel()
{
  int current_level = -1;
  NSDictionary *dockState = [WMDockState() objectForKey:@"Dock"];
  
  if ([[dockState objectForKey:@"Lowered"] isEqualToString:@"Yes"]) {
    // Normal or AutoRaiseLower
    if ([[dockState objectForKey:@"AutoRaiseLower"] isEqualToString:@"Yes"]) {
      current_level = AutoRaiseLower;
    }
    else {
      current_level = Normal;
    }
  }
  else {
    current_level = KeepOnTop;
  }

  return current_level;
}
static void toggleLowered(WDock *dock)
{
  WAppIcon *tmp;
  WDrawerChain *dc;
  int newlevel, i;

  if (!dock->lowered) {
    newlevel = NSNormalWindowLevel;
    dock->lowered = 1;
  } else {
    newlevel = NSDockWindowLevel;
    dock->lowered = 0;
  }

  for (i = 0; i < dock->max_icons; i++) {
    tmp = dock->icon_array[i];
    if (!tmp)
      continue;

    ChangeStackingLevel(tmp->icon->core, newlevel);

    /* When the dock is no longer "on top", explicitly lower it as well.
     * It saves some CPU cycles (probably) to do it ourselves here
     * rather than calling wDockLower at the end of toggleLowered */
    if (dock->lowered)
      wLowerFrame(tmp->icon->core);
  }

  if (dock->type == WM_DOCK) {
    for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next) {
      toggleLowered(dc->adrawer);
    }
    wScreenUpdateUsableArea(dock->screen_ptr);
  }
}
void WSSetDockLevel(int level)
{
  int   current_level;
  WDock *dock = wDefaultScreen()->dock;
  
  // From?
  current_level = WSDockLevel();
  
  // To?
  if (current_level == level)
    return;

  switch (level) {
  case KeepOnTop:
    dock->lowered = 1;
    dock->auto_raise_lower = 0;
    break;
  case Normal:
    dock->lowered = 0;
    dock->auto_raise_lower = 0;
    break;
  case AutoRaiseLower:
    dock->lowered = 0;
    dock->auto_raise_lower = 1;
    break;
  }
  toggleLowered(dock);

  wScreenSaveState(wDefaultScreen());
}

// Returns path to user WMState if exist.
// Returns 'nil' if user WMState doesn't exist and cannot
// be recovered from Workspace.app/Resources/WM directory.
NSString *WMDockStatePath(void)
{
  NSString      *userDefPath, *appDefPath;
  NSFileManager *fm = [NSFileManager defaultManager];

  userDefPath = [NSString stringWithFormat:@"%@/.WindowMaker/WMState",
                          GSDefaultsRootForUser(NSUserName())];
  
  if (![fm fileExistsAtPath:userDefPath]) {
    appDefPath = [[NSBundle mainBundle] pathForResource:@"WMState"
                                                 ofType:nil
                                            inDirectory:@"WM"];
    if (![fm fileExistsAtPath:appDefPath]) {
      return nil;
    }

    [fm copyItemAtPath:appDefPath toPath:userDefPath error:NULL];
  }

  return userDefPath;
}

// Saves dock on-screen state into WMState file
// void WMDockStateSave(void)
// {
//   wScreenSaveState(wDefaultScreen());
// }

// Returns NSDictionary representation of WMState file
NSDictionary *WMDockState(void)
{
  NSString     *wmStatePath;
  NSDictionary *wmState;

  // Defaults existance handled by WM.
  wmStatePath = [NSString stringWithFormat:@"%@/.WindowMaker/WMState.plist",
                          GSDefaultsRootForUser(NSUserName())];
  wmState = [[NSDictionary alloc] initWithContentsOfFile:wmStatePath];

  return [wmState autorelease];
}

NSArray *WMDockStateApps(void)
{
  NSArray  *dockApps;
  NSString *appsKey;
      
  appsKey = [NSString stringWithFormat:@"Applications%i",
                      wDefaultScreen()->scr_height];
  
  dockApps = [[WMDockState() objectForKey:@"Dock"] objectForKey:appsKey];
  if (!dockApps || [dockApps count] == 0) {
    [[WMDockState() objectForKey:@"Dock"] objectForKey:@"Applications"];
  }

  return dockApps;
}

void WMDockAutoLaunch(WDock *dock)
{
  WAppIcon    *btn;
  WSavedState *state;
  char        *command = NULL;
  NSString    *cmd;

  for (int i = 0; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];

    if (!btn || !btn->auto_launch ||
        !btn->command || btn->running || btn->launching ||
        !strcmp(btn->wm_instance, "Workspace")) {
      continue;
    }

    state = wmalloc(sizeof(WSavedState));
    state->workspace = 0;
    btn->drop_launch = 0;
    btn->paste_launch = 0;

    // Add '-autolaunch YES' to GNUstep application parameters
    if (!strcmp(btn->wm_class, "GNUstep")) {
      cmd = [NSString stringWithCString:btn->command];
      if ([cmd rangeOfString:@"autolaunch"].location == NSNotFound) {
        cmd = [cmd stringByAppendingString:@" -autolaunch YES"];
      }
      command = wstrdup(btn->command);
      wfree(btn->command);
      btn->command = wstrdup([cmd cString]);
    }

    wDockLaunchWithState(btn, state);

    // Return 'command' field into initial state (without -autolaunch)
    if (!strcmp(btn->wm_class, "GNUstep")) {
      wfree(btn->command);
      btn->command = wstrdup(command);
      wfree(command);
      command = NULL;
    }
  }  
}

// ----------------------------
// --- Launching appicons
// ----------------------------
// It is array of pointers to WAppIcon.
// These pointers also placed into WScreen->app_icon_list.
// Launching icons number is much smaller, but I use DOCK_MAX_ICONS
// (defined in WM/src/wconfig.h) as references number.
// static WAppIcon **launchingIcons = NULL;
void _addLaunchingIcon(WAppIcon *appicon)
{
  if (!launchingIcons) {
    launchingIcons = wmalloc(DOCK_MAX_ICONS * sizeof(WAppIcon*));
  }
  
  for (int i=0; i < DOCK_MAX_ICONS; i++) {
    if (launchingIcons[i] == NULL) {
      launchingIcons[i] = appicon;
      RemoveFromStackList(appicon->icon->core);
      break;
    }
  }
}
WAppIcon *_findLaunchingIcon(char *wm_instance, char *wm_class)
{
  WAppIcon *aicon = NULL;
  WAppIcon *licon = NULL;

  if (launchingIcons) {
    for (int i=0; i < DOCK_MAX_ICONS; i++) {
      licon = launchingIcons[i];
      if (licon &&
          !strcmp(wm_instance, licon->wm_instance) &&
          !strcmp(wm_class, licon->wm_class)) {
        aicon = licon;
        break;
      }
    }
  }

  return aicon;
}
// wmName is in 'wm_instance.wm_class' format
static NSLock *raceLock = nil;
WAppIcon *WMCreateLaunchingIcon(NSString *wmName,
                                NSString *launchPath,
                                NSImage *anImage,
                                NSPoint sourcePoint,
                                NSString *imagePath)
{
  NSPoint    iconPoint = {0, 0};
  BOOL       iconFound = NO;
  WScreen    *scr = wDefaultScreen();
  WAppIcon   *appIcon;
  NSArray    *wmNameParts;
  const char *wmInstance;
  const char *wmClass;

  if (wmName != nil) {
    wmNameParts = [wmName componentsSeparatedByString:@"."];
    wmInstance = [[wmNameParts objectAtIndex:0] cString];
    wmClass = [[wmNameParts objectAtIndex:1] cString];
  }
  else {
    // Can't create launching icon without application name
    return NULL;
  }

  if (!raceLock) raceLock = [NSLock new];
  [raceLock lock];

  // NSLog(@"Create icon for: %s.%s, %@", wmInstance, wmClass, launchPath);
  
  // 1. Search for existing icon in IconYard and Dock
  appIcon = scr->app_icon_list;
  while (appIcon->next) {
    // NSLog(@"Analyzing: %s.%s", appIcon->wm_instance, appIcon->wm_class);
    if (!strcmp(appIcon->wm_instance, wmInstance) &&
        !strcmp(appIcon->wm_class, wmClass)) {
      iconPoint.x = appIcon->x_pos + ((ICON_WIDTH - [anImage size].width)/2);
      iconPoint.y = scr->scr_height - appIcon->y_pos - 64;
      iconPoint.y += (ICON_WIDTH - [anImage size].width)/2;
      [[NSApp delegate] slideImage:anImage
                              from:sourcePoint
                                to:iconPoint];
      if (appIcon->docked && !appIcon->running) {
        appIcon->launching = 1;
        wAppIconPaint(appIcon);
      }
      iconFound = YES;
      break;
    }
    appIcon = appIcon->next;
  }

  // 2. Otherwise create appicon and set its state to launching
  if (iconFound == NO) {
    int x_ret = 0, y_ret = 0;
      
    appIcon = wAppIconCreateForDock(scr, [launchPath cString],
                                    (char *)wmInstance, (char *)wmClass,
                                    TILE_NORMAL);
    appIcon->icon->core->descriptor.handle_mousedown = NULL;
    appIcon->launching = 1;
    _addLaunchingIcon(appIcon);

    if (imagePath && [imagePath length] > 0) {
      wIconChangeImageFile(appIcon->icon, [imagePath cString]);
    }
    // NSLog(@"First icon in launching list for: %s.%s",
    //       launchingIcons->wm_instance, launchingIcons->wm_class);

    // Calculate postion for new launch icon
    PlaceIcon(scr, &x_ret, &y_ret, scr->xrandr_info.primary_head);
    wAppIconMove(appIcon, x_ret, y_ret);
    iconPoint.x = (CGFloat)x_ret;
    iconPoint.y = scr->scr_height - (y_ret + ICON_HEIGHT);
    [[NSApp delegate] slideImage:anImage
                            from:sourcePoint
                              to:iconPoint];

    // NSLog(@"Created launching appicon: %s.%s, %s",
    //       appIcon->wm_instance, appIcon->wm_class, appIcon->command);

    wAppIconPaint(appIcon);
    XMapWindow(dpy, appIcon->icon->core->window);
    XSync(dpy, False);
  }
  
  [raceLock unlock];
  
  return appIcon;
}

void WMFinishLaunchingIcon(WAppIcon *appIcon)
{
  WAppIcon *licon;
  
  for (int i=0; i < DOCK_MAX_ICONS; i++) {
    licon = launchingIcons[i];
    if (licon && (licon == appIcon)) {
      AddToStackList(appIcon->icon->core);
      launchingIcons[i] = NULL;
      break;
    }
  }
  appIcon->launching = 0;
  wAppIconPaint(appIcon);
}
void WMDestroyLaunchingIcon(WAppIcon *appIcon)
{
  WMFinishLaunchingIcon(appIcon);
  wAppIconDestroy(appIcon);
}

// ----------------------------
// --- Windows and applications
// ----------------------------
#import <GNUstepGUI/GSDisplayServer.h>
#define X_WINDOW(win) (Window)[GSCurrentServer() windowDevice:[(win) windowNumber]]
NSString *WMWindowState(NSWindow *nsWindow)
{
  WWindow *wWin = wWindowFor(X_WINDOW(nsWindow));
  
  if (!wWin)
    return nil;
    
  if (wWin->flags.miniaturized) {
    return @"Miniaturized";
  }
  else if (wWin->flags.shaded) {
    return @"Shaded";
  }
  else if (wWin->flags.hidden) {
    return @"Hidden";
  }
  else {
    return @"Normal";
  }
}

NSArray *WMNotDockedAppList(void)
{
  NSMutableArray *appList = [[NSMutableArray alloc] init];
  NSString       *appName;
  NSString       *appCommand;
  WAppIcon       *appIcon;
  char           *command = NULL;

  appIcon = wDefaultScreen()->app_icon_list;
  while (appIcon->next) {
    if (!strcmp(appIcon->wm_class, "GNUstep") && !strcmp(appIcon->wm_instance, "Login")) {
      appIcon = appIcon->next;
      continue;
    }
    if (!appIcon->docked) {
      if (appIcon->command && appIcon->command != NULL) {
        command = wstrdup(appIcon->command);
      }
      if (command == NULL && appIcon->icon->owner != NULL) {
        command = wGetCommandForWindow(appIcon->icon->owner->client_win);
      }
      if (command != NULL) {
        appName = [[NSString alloc] initWithFormat:@"%s.%s",
                                    appIcon->wm_instance, appIcon->wm_class];
        appCommand = [[NSString alloc] initWithCString:command];
        [appList addObject:@{@"Name":appName, @"Command":appCommand}];
        [appName release];
        [appCommand release];
        wfree(command);
        command = NULL;
      }
      else {
        NSLog(@"Application `%s.%s` was not saved. No application command found.",
              appIcon->wm_instance, appIcon->wm_class);
      }
    }
    appIcon = appIcon->next;
  }
  
  return [appList autorelease];
}

BOOL WMIsAppRunning(NSString *appName)
{
  NSArray  *nameComps = [appName componentsSeparatedByString:@"."];
  char     *app_instance = (char *)[[nameComps objectAtIndex:0] cString];
  char     *app_class = (char *)[[nameComps objectAtIndex:1] cString];
  BOOL     isAppFound = NO;
  WAppIcon *appIcon;

  appIcon = wDefaultScreen()->app_icon_list;
  while (appIcon->next) {
    if (!strcmp(app_instance, appIcon->wm_instance) &&
        !strcmp(app_class, appIcon->wm_class)) {
      isAppFound = YES;
      break;
    }
    appIcon = appIcon->next;
  }

  return isAppFound;
}

pid_t WMExecuteCommand(NSString *command)
{
  WScreen *scr = wDefaultScreen();
  pid_t   pid;
  char    **argv;
  int     argc;

  wtokensplit((char *)[command cString], &argv, &argc);

  if (!argc) {
    return 0;
  }

  pid = fork();
  if (pid == 0) {
    char **args;
    int i;

    args = malloc(sizeof(char *) * (argc + 1));
    if (!args)
      exit(111);
    for (i = 0; i < argc; i++) {
      args[i] = argv[i];
    }

    sigset_t sigs;
    sigfillset(&sigs);
    sigprocmask(SIG_UNBLOCK, &sigs, NULL);
    
    args[argc] = NULL;
    execvp(argv[0], args);
    exit(111);
  }
  while (argc > 0)
    wfree(argv[--argc]);
  wfree(argv);
  return pid;  
}

//--- End of functions which require existing @autorelease pool ---

//-----------------------------------------------------------------------------
// Workspace functions which are called from WM's code.
// All the functions below are executed inside 'wwmaker_q' GCD queue.
//-----------------------------------------------------------------------------

//--- Application management
WAppIcon *WSLaunchingIconForApplication(WApplication *wapp)
{
  WAppIcon *aicon;
  WWindow  *mainw = wapp->main_window_desc;
  
  aicon = _findLaunchingIcon(mainw->wm_instance, mainw->wm_class);
  if (!aicon) {
    return NULL;
  }

  aicon->icon->owner = mainw;
  
  if (mainw->wm_hints && (mainw->wm_hints->flags & IconWindowHint)) {
    aicon->icon->icon_win = mainw->wm_hints->icon_window;
  }
  
  wIconUpdate(aicon->icon);
  wIconPaint(aicon->icon);
    
  return aicon;
}

WAppIcon *WSLaunchingIconForCommand(char *command)
{
  WAppIcon *aicon = NULL;
  WAppIcon *licon = NULL;

  if (launchingIcons) {
    for (int i=0; i < DOCK_MAX_ICONS; i++) {
      licon = launchingIcons[i];
      if (licon && licon->command &&
          !strcmp(command, licon->command)) {
        aicon = licon;
        break;
      }
    }
  }

  return aicon;
}

static NSImage *_imageForRasterImage(RImage *r_image)
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

  if (rep) {
    image = [[NSImage alloc] init];
    [image addRepresentation:rep];
    [rep release];
  }

  return [image autorelease];
}

char *WSSaveRasterImageAsTIFF(RImage *r_image, char *file_path)
{
  NSImage  *image = _imageForRasterImage(r_image);
  NSData   *tiffRep = [image TIFFRepresentation];
  NSString *filePath;

  filePath = [NSString stringWithCString:file_path];
  wfree(file_path);
  
  if (![[filePath pathExtension] isEqualToString:@"tiff"]) {
    filePath = [filePath stringByDeletingPathExtension];
    filePath = [filePath stringByAppendingPathExtension:@"tiff"];
  }
  
  [tiffRep writeToFile:filePath atomically:YES];
  [image release];

  return wstrdup([filePath cString]);
}

static NSDictionary *_applicationInfoForWApp(WApplication *wapp, WWindow *wwin)
{
  NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
  NSString            *xAppName = nil;
  NSString            *xAppPath = nil;
  int                 app_pid;
  char                *app_command;

  [appInfo setObject:@"YES" forKey:@"IsWSindowApplication"];

  // NSApplicationName = NSString*
  xAppName = [NSString stringWithCString:wapp->main_window_desc->wm_class];
  [appInfo setObject:xAppName forKey:@"NSApplicationName"];

  // NSApplicationProcessIdentifier = NSString*
  if ((app_pid = wNETWMGetPidForWindow(wwin->client_win)) > 0) {
    [appInfo setObject:[NSString stringWithFormat:@"%i", app_pid]
                forKey:@"NSApplicationProcessIdentifier"];
  }
  else if ((app_pid = wapp->app_icon->pid) > 0) {
    [appInfo setObject:[NSString stringWithFormat:@"%i", app_pid]
                forKey:@"NSApplicationProcessIdentifier"];
  }
  else {
    [appInfo setObject:@"-1" forKey:@"NSApplicationProcessIdentifier"];
  }

  // NSApplicationPath = NSString*
  app_command = wGetCommandForWindow(wwin->client_win);
  if (app_command != NULL) {
    xAppPath = fullPathForCommand([NSString stringWithCString:app_command]);
    if (xAppPath)
      [appInfo setObject:xAppPath forKey:@"NSApplicationPath"];
    else
      [appInfo setObject:[NSString stringWithCString:app_command]
                  forKey:@"NSApplicationPath"];
  }
  else {
    [appInfo setObject:@"--" forKey:@"NSApplicationPath"];
  }

  // Get icon image from windowmaker app structure(WApplication)
  // NSApplicationIcon=NSImage*
  NSLog(@"%@ icon filename: %s", xAppName, wapp->app_icon->icon->file);
  if (wapp->app_icon->icon->file_image) {
    [appInfo setObject:_imageForRasterImage(wapp->app_icon->icon->file_image)
                forKey:@"NSApplicationIcon"];
  }

  return (NSDictionary *)appInfo;
}

void WSApplicationDidCreate(WApplication *wapp, WWindow *wwin)
{
  NSNotification *notif = nil;
  NSDictionary   *appInfo = nil;
  char           *wm_instance, *wm_class;
  WAppIcon       *appIcon;

  wm_instance = wapp->main_window_desc->wm_instance;
  wm_class = wapp->main_window_desc->wm_class;
  
  appIcon = _findLaunchingIcon(wm_instance, wm_class);
  if (appIcon) {
    WMFinishLaunchingIcon(appIcon);
    appIcon->main_window = wapp->main_window;
  }
  
  if (!strcmp(wm_class,"GNUstep"))
    return;

  appInfo = _applicationInfoForWApp(wapp, wwin);
  NSDebugLLog(@"WM", @"W+WM: WSApplicationDidCreate: %@", appInfo);
  
  notif = [NSNotification 
             notificationWithName:NSWorkspaceDidLaunchApplicationNotification
                           object:appInfo
                         userInfo:appInfo];
  // [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
  [[ProcessManager shared] applicationDidLaunch:notif];
}

void WSApplicationDidDestroy(WApplication *wapp)
{
  NSNotification *notif = nil;
  NSDictionary   *appInfo = nil;

  if (!strcmp(wapp->main_window_desc->wm_class,"GNUstep"))
    return;

  fprintf(stderr, "*** X11 application %s.%s did finished\n", 
          wapp->main_window_desc->wm_instance, 
          wapp->main_window_desc->wm_class);

  appInfo = _applicationInfoForWApp(wapp, wapp->main_window_desc);
  NSLog(@"W+WM: WSApplicationDidDestroy: %@", appInfo);
  
  notif = [NSNotification 
            notificationWithName:NSWorkspaceDidTerminateApplicationNotification
                          object:nil
                        userInfo:appInfo];

  // [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
  [[ProcessManager shared] applicationDidTerminate:notif];
}

void WSApplicationDidCloseWindow(WWindow *wwin)
{
  NSNotification *notif;
  NSDictionary   *appInfo;
  
  if (!strcmp(wwin->wm_class,"GNUstep"))
    return;

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
//------------------------------------------------------------------------------
static void moveDock(WDock *dock, int new_x, int new_y)
{
  WAppIcon *btn;
  WDrawerChain *dc;
  int i;

  if (dock->type == WM_DOCK) {
    for (dc = dock->screen_ptr->drawers; dc != NULL; dc = dc->next)
      moveDock(dc->adrawer, new_x, dc->adrawer->y_pos - dock->y_pos + new_y);
  }

  dock->x_pos = new_x;
  dock->y_pos = new_y;
  for (i = 0; i < dock->max_icons; i++) {
    btn = dock->icon_array[i];
    if (btn) {
      btn->x_pos = new_x + btn->xindex * wPreferences.icon_size;
      btn->y_pos = new_y + btn->yindex * wPreferences.icon_size;
      XMoveWindow(dpy, btn->icon->core->window, btn->x_pos, btn->y_pos);
    }
  }
}

void WSUpdateScreenInfo(WScreen *scr)
{
  NSRect screenRect, headRect, primaryRect;

  XLockDisplay(dpy);

  NSDebugLLog(@"Screen", @"Screen layout changed, updating Workspace and WM...");

  // Update WM Xrandr
  wUpdateXrandrInfo(scr);

  screenRect = NSMakeRect(0,0,0,0);
  for (int i = 0; i < scr->xrandr_info.count; i++) {
    headRect.origin.x = scr->xrandr_info.screens[i].pos.x;
    headRect.origin.y = scr->xrandr_info.screens[i].pos.y;
    headRect.size.width = scr->xrandr_info.screens[i].size.width;
    headRect.size.height = scr->xrandr_info.screens[i].size.height;

    if (i == scr->xrandr_info.primary_head)
      primaryRect = headRect;
    
    screenRect = NSUnionRect(screenRect, headRect);
  }
  scr->scr_width = (int)screenRect.size.width;
  scr->scr_height = (int)screenRect.size.height;

  // Update WM usable area info
  wScreenUpdateUsableArea(scr);

  // Move Dock
  // Place Dock into main display with changed usable area.
  // RecyclerIcon call should go first to update its position on screen.
  [RecyclerIcon updatePositionInDock:scr->dock];
  moveDock(scr->dock,
           (NSMaxX(primaryRect) - wPreferences.icon_size - DOCK_EXTRA_SPACE),
           primaryRect.origin.y);
  
  // Move IconYard
  // IconYard is placed into main display automatically.
  wArrangeIcons(scr, True);
  
  // Save Dock state with new position and screen size
  wScreenSaveState(scr);

  // Save changed layout in user's preferences directory
  // [systemScreen saveCurrentDisplayLayout];
 
  // NSLog(@"XRRScreenChangeNotify: END");
  XUnlockDisplay(dpy);

  // NSLog(@"Sending OSEScreenDidChangeNotification...");
  // Send notification to active OSEScreen applications.
  [[NSDistributedNotificationCenter defaultCenter]
     postNotificationName:OSEScreenDidChangeNotification
                   object:nil];
}

void WSUpdateScreenParameters(void)
{
  WSUpdateScreenInfo(wDefaultScreen());
}

// Application events
//------------------------------------------------------------------------------
void WSActivateApplication(WScreen *scr, char *app_name)
{
  id           app;
  NSString     *appName;
  NSConnection *appConnection;

  if (!strcmp(app_name, "Workspace")) {
    WSActivateWorkspaceApp(scr);
    return;
  }

  appName = [NSString stringWithCString:app_name];
  app = [NSConnection rootProxyForConnectionWithRegisteredName:appName
                                                          host:nil];
  if (app == nil) {
    WSMessage("WSActivateApplication: Couldn't contact application %@.", appName);
    WSActivateWorkspaceApp(scr);
  }
  else {
    WSMessage("[WS+WM] Activating application `%@`", appName);
    [app activateIgnoringOtherApps:YES];

    appConnection = [app connectionForProxy];
    [[appConnection receivePort] invalidate];
    [[appConnection sendPort] invalidate];
    [appConnection invalidate];
    [app release];
    
    if ([NSApp isActive] != NO) {
      WSMessage("Workspace is active - deactivating...");
      [NSApp performSelectorOnMainThread:@selector(deactivate)
                              withObject:nil
                           waitUntilDone:YES];
    }
  }
}

void WSActivateWorkspaceApp(WScreen *scr)
{
  if (scr == NULL)
    scr = wDefaultScreen();
  
  if ([NSApp isHidden] == NO) {
    [[NSApp delegate] performSelectorOnMainThread:@selector(activate)
                                       withObject:nil
                                    waitUntilDone:YES];
  }
  else {
    XSetInputFocus(dpy, scr->no_focus_win, RevertToParent, CurrentTime);
  }
}

void WSKeyboardGroupDidChange(int group)
{
  OSEKeyboard *keyboard = [OSEKeyboard new];
  NSString    *layout = [[keyboard layouts] objectAtIndex:group];

  if ([[keyboard layouts] count] <= 1) {
    layout = @"";
  }
  else {
    layout = [[keyboard layouts] objectAtIndex:group];
  }
  
  [[NSApp delegate] performSelectorOnMainThread:@selector(updateKeyboardBadge:)
                                     withObject:layout
                                  waitUntilDone:YES];
  [keyboard release];
}

void WSDockContentDidChange(WDock *dock)
{
  NSNotification *notif;
  
  notif = [NSNotification 
            notificationWithName:@"WMDockContentDidChange"
                          object:nil
                        userInfo:nil];

  [[NSNotificationCenter defaultCenter] postNotification:notif];
}

// Utility functions
//------------------------------------------------------------------------------
// Return values:
// WMAPRDefault,  NSAlertDefaultReturn = 1;
// WAPRAlternate, NSAlertAlternateReturn = 0;
// WAPROther,     NSAlertOtherReturn = -1;
// WAPRError,     NSAlertErrorReturn  = -2
int WSRunAlertPanel(char *title, char *message,
                     char *defaultButton, char *alternateButton, char *otherButton)
{
  NSDictionary        *info;
  NSMutableDictionary *alertInfo;
  int result;

  info = @{@"Title":[NSString stringWithCString:title],
           @"Message":[NSString stringWithCString:message],
           @"DefaultButton":[NSString stringWithCString:defaultButton],
           @"AlternateButton":alternateButton?[NSString stringWithCString:alternateButton]:@"",
           @"OtherButton":otherButton?[NSString stringWithCString:otherButton]:@""};
  alertInfo = [info mutableCopy];
  
  [[NSApp delegate] performSelectorOnMainThread:@selector(showWMAlert:)
                                     withObject:alertInfo
                                  waitUntilDone:YES];
  result = [[alertInfo objectForKey:@"Result"] integerValue];
  [alertInfo release];
  
  return result;
}

extern void wShakeWindow(WWindow *wwin);
void WSRingBell(WWindow *wwin)
{
  NXTDefaults *defs = [NXTDefaults globalUserDefaults];
  NSString   *beepType = [defs objectForKey:@"NXSystemBeepType"];

  if (beepType && [beepType isEqualToString:@"Visual"]) {
    wShakeWindow(wwin);
  }
  else {
    [[NSApp delegate] ringBell];
  }
}

void WSMessage(char *fmt, ...)
{
  va_list  args;
  NSString *format;

  if (GSDebugSet(@"WM") == YES) {
    va_start(args, fmt);
    format = [NSString stringWithCString:fmt];
    NSLogv([NSString stringWithFormat:@"[WM] %@", format], args);
    va_end(args);
  }
}
