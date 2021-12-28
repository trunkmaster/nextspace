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

// WM functions and vars
extern Display *dpy;

//-----------------------------------------------------------------------------
// Workspace functions which are called from WM's code.
// All the functions below are executed inside 'wwmaker_q' GCD queue.
// TODO: all events based function should be replaces with CF notifications.
//-----------------------------------------------------------------------------

NSImage *WSImageForRasterImage(RImage *r_image)
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
  NSImage  *image = WSImageForRasterImage(r_image);
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



// static NSDictionary *_applicationInfoForWApp(WApplication *wapp, WWindow *wwin)
// {
//   NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
//   NSString            *appName = nil;
//   NSString            *appPath = nil;
//   int                 app_pid;
//   char                *app_command;

//   // Gather NSApplicationName and NSApplicationPath
//   if (!strcmp(wapp->main_window_desc->wm_class, "GNUstep")) {
//     [appInfo setObject:@"NO" forKey:@"IsXWindowApplication"];
//     appName = [NSString stringWithCString:wapp->main_window_desc->wm_instance];
//     appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:appName];
//   } else {
//     [appInfo setObject:@"YES" forKey:@"IsXWindowApplication"];
//     appName = [NSString stringWithCString:wapp->main_window_desc->wm_class];
//     app_command = wGetCommandForWindow(wwin->client_win);
//     if (app_command) {
//       appPath = [[NXTFileManager defaultManager]
//                   absolutePathForCommand:[NSString stringWithCString:app_command]];
//     }
//   }
//   // NSApplicationName = NSString*
//   [appInfo setObject:appName forKey:@"NSApplicationName"];
//   // NSApplicationPath = NSString*
//   if (appPath) {
//     [appInfo setObject:appPath forKey:@"NSApplicationPath"];
//   } else if (app_command) {
//     [appInfo setObject:[NSString stringWithCString:app_command]
//                 forKey:@"NSApplicationPath"];
//   } else {
//     [appInfo setObject:@"--" forKey:@"NSApplicationPath"];
//   }

//   // NSApplicationProcessIdentifier = NSString*
//   if ((app_pid = wNETWMGetPidForWindow(wwin->client_win)) > 0) {
//     [appInfo setObject:[NSString stringWithFormat:@"%i", app_pid]
//                 forKey:@"NSApplicationProcessIdentifier"];
//   }
//   else if ((app_pid = wapp->app_icon->pid) > 0) {
//     [appInfo setObject:[NSString stringWithFormat:@"%i", app_pid]
//                 forKey:@"NSApplicationProcessIdentifier"];
//   }
//   else {
//     [appInfo setObject:@"-1" forKey:@"NSApplicationProcessIdentifier"];
//   }

//   // Get icon image from windowmaker app structure(WApplication)
//   // NSApplicationIcon=NSImage*
//   // NSLog(@"%@ icon filename: %s", xAppName, wapp->app_icon->icon->file);
//   if (wapp->app_icon->icon->file_image) {
//     [appInfo setObject:WSImageForRasterImage(wapp->app_icon->icon->file_image)
//                 forKey:@"NSApplicationIcon"];
//   }

//   return (NSDictionary *)appInfo;
// }

// void WSApplicationDidCreate(WApplication *wapp)
// {
//   NSNotification *notif = nil;
//   NSDictionary *appInfo = nil;
//   char *wm_instance, *wm_class;
//   WAppIcon *appIcon;
//   WWindow *wwin;

//   wm_instance = wapp->main_window_desc->wm_instance;
//   wm_class = wapp->main_window_desc->wm_class;
  
//   appIcon = wLaunchingAppIconForInstance(wapp->main_window_desc->screen_ptr, wm_instance, wm_class);
//   if (appIcon) {
//     wLaunchingAppIconFinish(wapp->main_window_desc->screen_ptr, appIcon);
//     appIcon->main_window = wapp->main_window;
//   }

//   // GNUstep application will register itself in ProcessManager with AppKit notification.
//   if (!strcmp(wm_class,"GNUstep")) {
//     return;
//   }

//   wwin = (WWindow *)CFArrayGetValueAtIndex(wapp->windows, 0);
//   appInfo = _applicationInfoForWApp(wapp, wwin);
//   NSDebugLLog(@"WM", @"W+WM: WSApplicationDidCreate: %@", appInfo);

//   notif = [NSNotification notificationWithName:NSWorkspaceDidLaunchApplicationNotification
//                                         object:appInfo
//                                       userInfo:appInfo];
//   [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
// }

// void WSApplicationDidDestroy(WApplication *wapp)
// {
//   NSNotification *notif = nil;
//   NSDictionary   *appInfo = nil;

//   // Application could terminate in 2 ways:
//   // 1. normal - AppKit notfication mechanism works
//   // 2. crash - no AppKit involved so we should use this code to inform ProcessManager
//   // [ProcessManager applicationDidTerminate:] should expect 2 calls for option #1.
//   appInfo = _applicationInfoForWApp(wapp, wapp->main_window_desc);
//   NSLog(@"W+WM: WSApplicationDidDestroy: %@", appInfo);
  
//   notif = [NSNotification notificationWithName:NSWorkspaceDidTerminateApplicationNotification
//                                         object:nil
//                                       userInfo:appInfo];
//   [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
// }

// void WSApplicationDidCloseWindow(WWindow *wwin)
// {
//   NSNotification *notif;
//   NSDictionary   *appInfo;
  
//   if (!strcmp(wwin->wm_class,"GNUstep"))
//     return;

//   appInfo = @{@"NSApplicationName":[NSString stringWithCString:wwin->wm_class]};
//   notif = [NSNotification notificationWithName:WMApplicationDidTerminateSubprocessNotification
//                                         object:nil
//                                       userInfo:appInfo];
//   [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
// }

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

// Layout badge in Workspace appicon
//------------------------------------------------------------------------------
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

// Dock
//------------------------------------------------------------------------------
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
