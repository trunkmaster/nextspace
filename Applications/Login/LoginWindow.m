/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// Description: borderless window that centers in active display,
//              shakes on user authentication failure and shrinks
//              on success. Other window control functions are
//              placed into Controller.
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

#import <unistd.h>

#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSEDisplay.h>
#import <SystemKit/OSEMouse.h>

#import "Controller.h"
#import "LoginWindow.h"

@implementation LoginWindow

// It was neccesary to override this method to get the borderless
// window since it is not available from InterfaceBuilder.
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)styleMask
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag
{
  return [super initWithContentRect:contentRect
                          styleMask:NSBorderlessWindowMask
                            backing:bufferingType
                              defer:flag];
}

- (BOOL)canBecomeKeyWindow
{
  return YES;
}

- (BOOL)canBecomeMainWindow
{
  // If set to YES login window appears regrdless of
  // "Visible at launch time" bit set
  return NO;
}

/*
   This method is a temporary solution. GNUstep doesn't count screen size and
   display laying out to each other on multi-display setups. For example, if 2
   displays stacked side-by-side with top edges aligned by the Y axis
   (deafult layout) we need to add bottom side offset to point.y because GNUstep
   coordinate system starts at bottom left corner. If displays aligned by bottom
   edge - no offset have to be added.
   The worst case is when displays are not aligned along some edge(s).
   In this case XRandR screen dimensions increase while GNUstep is not aware of
   such changes. We need to adjust `point` to be correct in GNUstep coordinate
   system and screen dimensions.
*/
- (void)center
{
  OSEScreen *screen = [[NSApp delegate] systemScreen];
  OSEDisplay *display = nil;
  NSSize screenSize;
  NSRect displayRect;
  NSRect windowRect = [self frame];
  NSPoint newOrigin;

  NSDebugLLog(@"Screen", @"center");

  // Get NEXTSPACE display rect
  if (screen != nil) {
    [screen randrUpdateScreenResources];
    if ([[screen activeDisplays] count] > 0) {
      display = [screen mainDisplay];
      if (!display) {
        NSDebugLLog(@"Screen", @"No main display - using first active.");
        display = [[screen activeDisplays] objectAtIndex:0];
      }
    } else if ([[screen connectedDisplays] count] > 0) {
      NSDebugLLog(@"Screen", @"No active displays left - activating first connected.");
      display = [[screen connectedDisplays] objectAtIndex:0];
      [screen activateDisplay:display];
    }
    screenSize = [screen sizeInPixels];
    displayRect = [display frame];

    NSDebugLLog(@"Screen", @"Screen size   : %4.0f x %4.0f", screenSize.width, screenSize.height);
  }

  NSDebugLLog(@"Screen", @"Display frame : %4.0f x %4.0f  (%4.0f, %4.0f)", displayRect.size.width,
              displayRect.size.height, displayRect.origin.x, displayRect.origin.y);

  NSDebugLLog(@"Screen", @"Window frame  : %4.0f x %4.0f  (%4.0f, %4.0f)", windowRect.size.width,
              windowRect.size.height, windowRect.origin.x, windowRect.origin.y);

  // Calculate the new position of the window on display.
  newOrigin.x = displayRect.size.width / 2 - windowRect.size.width / 2;
  newOrigin.x += displayRect.origin.x;
  newOrigin.y = displayRect.size.height / 2 - windowRect.size.height / 2;
  newOrigin.y += displayRect.origin.y;
  // displayRect is presented system(Xlib) coordiante system.
  // Convert newOrigin into OpenStep coordinate system (non-flipped).
  newOrigin.y = screenSize.height - (newOrigin.y + windowRect.size.height);
  NSDebugLLog(@"Screen", @"New origin    :              (%4.0f, %4.0f)", newOrigin.x, newOrigin.y);

  [self setFrameOrigin:newOrigin];
}

#define ANIMATION_DELAY 250

- (NSPoint)windowScreenOrigin
{
  NSRect allScreensFrame;
  NSRect frame = [self frame];
  NSPoint origin = frame.origin;

  for (NSScreen *scr in [NSScreen screens]) {
    allScreensFrame = NSUnionRect(allScreensFrame, [scr frame]);
  }

  origin.y = NSMaxY(allScreensFrame) - NSMaxY(frame);

  NSLog(@"[screen origin] Y -> Xlib: %.0f Max: %.0f Screen: %.0f (Max: %.0f)", origin.y,
        NSMaxY(frame), allScreensFrame.origin.y, NSMaxY(allScreensFrame));

  return origin;
}

- (void)shakePanel:(Window)panel onDisplay:(Display *)dpy
{
  NSPoint origin = [self windowScreenOrigin];
  int x, initial_x, y;
  int i, j, num_steps, num_shakes;

  initial_x = x = (int)origin.x;
  y = (int)origin.y;

  num_steps = 4;
  num_shakes = 14;
  for (i = 0; i < num_shakes; i++) {
    for (j = 0; j < num_steps; j++) {
      x += 10;
      XMoveWindow(dpy, panel, x, y);
      XSync(dpy, false);
      usleep(ANIMATION_DELAY);
    }
    for (j = 0; j < num_steps * 2; j++) {
      x -= 10;
      XMoveWindow(dpy, panel, x, y);
      XSync(dpy, false);
      usleep(ANIMATION_DELAY);
    }
    for (j = 0; j < num_steps; j++) {
      x += 10;
      XMoveWindow(dpy, panel, x, y);
      XSync(dpy, false);
      usleep(ANIMATION_DELAY);
    }
  }
  XMoveWindow(dpy, panel, initial_x, y);
  XSync(dpy, False);
}

#define SHRINK_FACTOR 2

- (void)shrinkPanel:(Window)panel onDisplay:(Display *)dpy
{
  NSRect windowRect = [self frame];
  NSPoint origin = [self windowScreenOrigin];
  GC gc;
  Pixmap pixmap;
  XImage *windowSnap;
  int x, y, width, height, initial_x, initial_width;

  initial_x = x = (int)origin.x;
  y = (int)origin.y;
  initial_width = width = (int)windowRect.size.width;
  height = (int)windowRect.size.height;

  pixmap = XCreatePixmap(dpy, panel, width, height, 24);
  gc = XCreateGC(dpy, pixmap, 0, NULL);

  windowSnap = XGetImage(dpy, panel, 0, 0, width, height, AllPlanes, XYPixmap);
  XPutImage(dpy, pixmap, gc, windowSnap, 0, 0, 0, 0, width, height);

  while ((width - SHRINK_FACTOR) > 0) {
    x += SHRINK_FACTOR / 2;
    width -= SHRINK_FACTOR;

    XMoveResizeWindow(dpy, panel, x, y, width, height);
    XCopyArea(dpy, pixmap, pixmap, gc, SHRINK_FACTOR / 2, 0, width, height, 0, 0);
    XSetWindowBackgroundPixmap(dpy, panel, pixmap);
    XSync(dpy, False);
    usleep(ANIMATION_DELAY);
  }

  // Restore original window size. Don't call XSync and let Controller hide
  // panel before XMoveResizeWindow results will  made visible.
  XMoveResizeWindow(dpy, panel, initial_x, y, initial_width, height);
  XSync(dpy, False);

  XFree(windowSnap);
  XFreeGC(dpy, gc);
  XFreePixmap(dpy, pixmap);
}

@end
