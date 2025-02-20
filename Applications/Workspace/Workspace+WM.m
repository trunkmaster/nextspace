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
#import <SystemKit/OSEDefaults.h>
#import <DesktopKit/NXTAlert.h>
#import <SoundKit/NXTSound.h>
#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSESystemInfo.h>
#import <SystemKit/OSEKeyboard.h>

#import "Workspace+WM.h"
#import "Controller.h"
#import "Recycler.h"
#import "Processes/ProcessManager.h"

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

@interface NSBitmapImageRep (GSPrivate)
- (NSBitmapImageRep *)_convertToFormatBitsPerSample:(NSInteger)bps
                                    samplesPerPixel:(NSInteger)spp
                                           hasAlpha:(BOOL)alpha
                                           isPlanar:(BOOL)isPlanar
                                     colorSpaceName:(NSString *)colorSpaceName
                                       bitmapFormat:(NSBitmapFormat)bitmapFormat
                                        bytesPerRow:(NSInteger)rowBytes
                                       bitsPerPixel:(NSInteger)pixelBits;
@end

static NSBitmapImageRep *_getBestRepresentationFromImage(NSImage *image)
{
  NSArray *imageRepresentations = [image representations];
  NSUInteger repsCount;
  NSBitmapImageRep *imageRep;
  NSInteger largestBPP = 0;
  int bestRepIndex = 0;

  // Get representation with highest Bits/Pixel value
  repsCount = imageRepresentations.count;
  for (NSUInteger i = 0; i < repsCount; i++) {
    imageRep = imageRepresentations[i];
    if ([imageRep bitsPerPixel] > largestBPP) {
      largestBPP = [imageRep bitsPerPixel];
      bestRepIndex = i;
    }
  }

  return imageRepresentations[bestRepIndex];
}

RImage *WSLoadRasterImage(const char *file_path)
{
  NSImage *image = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithCString:file_path]];
  RImage *raster_image = NULL;

  if (image) {
    NSSize imageSize;
    NSBitmapImageRep *imageRep, *convertedRep;
    BOOL isAlpha;
    int width, height, samplesPerPixel;

    imageRep = _getBestRepresentationFromImage(image);

    imageSize = [imageRep size];
    width = ceil(imageSize.width);
    height = ceil(imageSize.height);
    isAlpha = [imageRep hasAlpha];
    samplesPerPixel = [imageRep hasAlpha] ? 4 : 3;

    convertedRep = [imageRep _convertToFormatBitsPerSample:8
                                           samplesPerPixel:samplesPerPixel
                                                  hasAlpha:isAlpha
                                                  isPlanar:NO
                                            colorSpaceName:NSCalibratedRGBColorSpace
                                              bitmapFormat:[imageRep bitmapFormat]
                                               bytesPerRow:0
                                              bitsPerPixel:0];

    raster_image = RCreateImage(width, height, isAlpha);
    memcpy(raster_image->data, [convertedRep bitmapData],
           width * height * sizeof(unsigned char) * samplesPerPixel);
    [image release];
  }

  return raster_image;
}

NSImage *WSImageForRasterImage(RImage *r_image)
{
  BOOL hasAlpha = (r_image->format == RRGBAFormat) ? YES : NO;
  NSBitmapImageRep *rep = nil;
  NSImage *image = nil;

  rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&r_image->data
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
  NSImage *image = WSImageForRasterImage(r_image);
  NSData *tiffRep = [image TIFFRepresentation];
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

  screenRect = NSMakeRect(0, 0, 0, 0);
  for (int i = 0; i < scr->xrandr_info.count; i++) {
    headRect.origin.x = scr->xrandr_info.screens[i].pos.x;
    headRect.origin.y = scr->xrandr_info.screens[i].pos.y;
    headRect.size.width = scr->xrandr_info.screens[i].size.width;
    headRect.size.height = scr->xrandr_info.screens[i].size.height;

    if (i == scr->xrandr_info.primary_head)
      primaryRect = headRect;

    screenRect = NSUnionRect(screenRect, headRect);
  }
  scr->width = (int)screenRect.size.width;
  scr->height = (int)screenRect.size.height;

  // Update WM usable area info
  wScreenUpdateUsableArea(scr);

  // Move Dock
  // Place Dock into main display with changed usable area.
  // RecyclerIcon call should go first to update its position on screen.
  [RecyclerIcon updatePositionInDock:scr->dock];
  moveDock(scr->dock, (NSMaxX(primaryRect) - wPreferences.icon_size - DOCK_EXTRA_SPACE),
           primaryRect.origin.y);

  // Move IconYard
  // IconYard is placed into main display automatically.
  wArrangeIcons(scr, True);

  // Save Dock state with new position and screen size
  wScreenSaveState(scr);

  // Save changed layout in user's preferences directory
  // [systemScreen saveCurrentDisplayLayout];

  NSDebugLLog(@"Screen", @"XRRScreenChangeNotify: END");
  XUnlockDisplay(dpy);

  NSDebugLLog(@"Screen", @"Sending OSEScreenDidChangeNotification...");
  // Send notification to active OSEScreen applications of current user.
  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:OSEScreenDidChangeNotification
                    object:nil];
}

void WSUpdateScreenParameters(void) { WSUpdateScreenInfo(wDefaultScreen()); }

// Application events
//------------------------------------------------------------------------------
void WSActivateApplication(WScreen *scr, char *app_name)
{
  id app;
  NSString *appName;
  NSConnection *appConnection;

  if (!strcmp(app_name, "Workspace")) {
    WSActivateWorkspaceApp(scr);
    return;
  }

  appName = [NSString stringWithCString:app_name];
  app = [NSConnection rootProxyForConnectionWithRegisteredName:appName host:nil];
  if (app == nil) {
    WSMessage("WSActivateApplication: Couldn't contact application %@.", appName);
    WSActivateWorkspaceApp(scr);
  } else {
    WSMessage("[WS+WM] Activating application `%@`", appName);
    [app activateIgnoringOtherApps:YES];

    appConnection = [app connectionForProxy];
    [[appConnection receivePort] invalidate];
    [[appConnection sendPort] invalidate];
    [appConnection invalidate];
    [app release];

    if ([NSApp isActive] != NO) {
      WSMessage("Workspace is active - deactivating...");
      [NSApp performSelectorOnMainThread:@selector(deactivate) withObject:nil waitUntilDone:YES];
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
  } else {
    XSetInputFocus(dpy, scr->no_focus_win, RevertToParent, CurrentTime);
  }
}

// Utility functions
//------------------------------------------------------------------------------
// Return values:
// NSAlertDefaultReturn = 1;
// NSAlertAlternateReturn = 0;
// NSAlertOtherReturn = -1;
// NSAlertErrorReturn  = -2
int WSRunAlertPanel(char *title, char *message, char *defaultButton, char *alternateButton,
                    char *otherButton)
{
  NSDictionary *info;
  NSMutableDictionary *alertInfo;
  int result;

  info = @{
    @"Title" : [NSString stringWithCString:title],
    @"Message" : [NSString stringWithCString:message],
    @"DefaultButton" : [NSString stringWithCString:defaultButton],
    @"AlternateButton" : alternateButton ? [NSString stringWithCString:alternateButton] : @"",
    @"OtherButton" : otherButton ? [NSString stringWithCString:otherButton] : @""
  };
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
  OSEDefaults *defs = [OSEDefaults globalUserDefaults];
  NSString *beepType = [defs objectForKey:@"NXSystemBeepType"];

  if (beepType && [beepType isEqualToString:@"Visual"]) {
    wShakeWindow(wwin);
  } else {
    [[NSApp delegate] ringBell];
  }
}

void WSMessage(char *fmt, ...)
{
  va_list args;
  NSString *format;

  if (GSDebugSet(@"WM") == YES) {
    va_start(args, fmt);
    format = [NSString stringWithCString:fmt];
    NSLogv([NSString stringWithFormat:@"[WM] %@", format], args);
    va_end(args);
  }
}
