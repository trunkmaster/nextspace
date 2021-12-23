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
#include <core/util.h>
#include <core/string_utils.h>
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
#import "Recycler.h"
#import "Operations/ProcessManager.h"

NSString *WMShowAlertPanel = @"WMShowAlertPanelNotification";
dispatch_queue_t workspace_q;
WorkspaceExitCode ws_quit_code;
static WAppIcon **launchingIcons = NULL;

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

// --- Logout
void WMShutdown(WMShutdownMode mode)
{
  fprintf(stderr, "*** Shutting down Window Manager...\n");
  
  // scr = wDefaultScreen();
  // if (scr) {
  //   if (scr->helper_pid) {
  //     kill(scr->helper_pid, SIGKILL);
  //   }

  //   wScreenSaveState(scr);

  //   if (mode == WSKillMode)
  //     WMWipeDesktop(scr);
  //   else
  //     RestoreDesktop(scr);
  // }
  // wNETWMCleanup(scr); // Delete _NET_* Atoms

  wShutdown(WMExitMode);
  if (launchingIcons) free(launchingIcons);
  
//   RShutdown(); /* wrlib clean exit */
// #if HAVE_SYSLOG_H
//   WMSyslogClose();
// #endif
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
  NSString            *appName = nil;
  NSString            *appPath = nil;
  int                 app_pid;
  char                *app_command;

  // Gather NSApplicationName and NSApplicationPath
  if (!strcmp(wapp->main_window_desc->wm_class, "GNUstep")) {
    [appInfo setObject:@"NO" forKey:@"IsXWindowApplication"];
    appName = [NSString stringWithCString:wapp->main_window_desc->wm_instance];
    appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:appName];
  } else {
    [appInfo setObject:@"YES" forKey:@"IsXWindowApplication"];
    appName = [NSString stringWithCString:wapp->main_window_desc->wm_class];
    app_command = wGetCommandForWindow(wwin->client_win);
    if (app_command) {
      appPath = fullPathForCommand([NSString stringWithCString:app_command]);
    }
  }
  // NSApplicationName = NSString*
  [appInfo setObject:appName forKey:@"NSApplicationName"];
  // NSApplicationPath = NSString*
  if (appPath) {
    [appInfo setObject:appPath forKey:@"NSApplicationPath"];
  } else if (app_command) {
    [appInfo setObject:[NSString stringWithCString:app_command]
                forKey:@"NSApplicationPath"];
  } else {
    [appInfo setObject:@"--" forKey:@"NSApplicationPath"];
  }

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

  // Get icon image from windowmaker app structure(WApplication)
  // NSApplicationIcon=NSImage*
  // NSLog(@"%@ icon filename: %s", xAppName, wapp->app_icon->icon->file);
  if (wapp->app_icon->icon->file_image) {
    [appInfo setObject:_imageForRasterImage(wapp->app_icon->icon->file_image)
                forKey:@"NSApplicationIcon"];
  }

  return (NSDictionary *)appInfo;
}

void WSApplicationDidCreate(WApplication *wapp)
{
  NSNotification *notif = nil;
  NSDictionary *appInfo = nil;
  char *wm_instance, *wm_class;
  WAppIcon *appIcon;
  WWindow *wwin;

  wm_instance = wapp->main_window_desc->wm_instance;
  wm_class = wapp->main_window_desc->wm_class;
  
  appIcon = _findLaunchingIcon(wm_instance, wm_class);
  if (appIcon) {
    WMFinishLaunchingIcon(appIcon);
    appIcon->main_window = wapp->main_window;
  }

  // GNUstep application will register itself in ProcessManager with AppKit notification.
  if (!strcmp(wm_class,"GNUstep")) {
    return;
  }

  wwin = (WWindow *)CFArrayGetValueAtIndex(wapp->windows, 0);
  appInfo = _applicationInfoForWApp(wapp, wwin);
  NSDebugLLog(@"WM", @"W+WM: WSApplicationDidCreate: %@", appInfo);

  notif = [NSNotification notificationWithName:NSWorkspaceDidLaunchApplicationNotification
                                        object:appInfo
                                      userInfo:appInfo];
  [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
}

void WSApplicationDidDestroy(WApplication *wapp)
{
  NSNotification *notif = nil;
  NSDictionary   *appInfo = nil;

  // Application could terminate in 2 ways:
  // 1. normal - AppKit notfication mechanism works
  // 2. crash - no AppKit involved so we should use this code to inform ProcessManager
  // [ProcessManager applicationDidTerminate:] should expect 2 calls for option #1.
  appInfo = _applicationInfoForWApp(wapp, wapp->main_window_desc);
  NSLog(@"W+WM: WSApplicationDidDestroy: %@", appInfo);
  
  notif = [NSNotification notificationWithName:NSWorkspaceDidTerminateApplicationNotification
                                        object:nil
                                      userInfo:appInfo];
  [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
}

void WSApplicationDidCloseWindow(WWindow *wwin)
{
  NSNotification *notif;
  NSDictionary   *appInfo;
  
  if (!strcmp(wwin->wm_class,"GNUstep"))
    return;

  appInfo = @{@"NSApplicationName":[NSString stringWithCString:wwin->wm_class]};
  notif = [NSNotification notificationWithName:WMApplicationDidTerminateSubprocessNotification
                                        object:nil
                                      userInfo:appInfo];
  [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
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
// NSAlertDefaultReturn = 1;
// NSAlertAlternateReturn = 0;
// NSAlertOtherReturn = -1;
// NSAlertErrorReturn  = -2
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
