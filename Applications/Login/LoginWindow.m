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
#import <X11/Xlib.h>

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
- (NSPoint)centeredOriginForGNUstep:(BOOL)isGNUstep
{
  OSEScreen  *screen;
  OSEDisplay *display;
  NSSize     screenSize;
  NSRect     displayRect;
  NSRect     windowRect = [self frame];
  NSRect     gsScreenRect;
  NSPoint    newOrigin;

  // Get NEXTSPACE display rect
  screen = [[OSEScreen new] autorelease];
  screenSize = [screen sizeInPixels];
  display = [screen displayWithMouseCursor];
  if (!display) {
    display = [screen mainDisplay];
    if (!display) {
      display = [[screen activeDisplays] objectAtIndex:0];
    }
  }
  displayRect = [display frame];
  NSLog(@"NEXTSPACE display frame: %@", NSStringFromRect(displayRect));
  NSLog(@"NEXTSPACE screen size: %@", NSStringFromSize([screen sizeInPixels]));

  NSLog(@"Window frame: %@", NSStringFromRect(windowRect));
  
  // Calculate the new position of the window.
  newOrigin.x = displayRect.size.width/2 - windowRect.size.width/2;
  // newOrigin.x += displayRect.origin.x;
  newOrigin.y = displayRect.size.height/2 - windowRect.size.height/2;
  // newOrigin.y += gScreenRect.size.height - displayRect.size.height;
  NSLog(@"New origin: x = %.0f, y = %.0f", newOrigin.x, newOrigin.y);
  
  NSLog(@"Display rect: %@", NSStringFromRect(displayRect));
  newOrigin.x += displayRect.origin.x;

  if (isGNUstep != NO) {
    // Get GNUstep screen rect
    gsScreenRect = [[self screen] frame];
    NSLog(@"GNUstep screen size: %@", NSStringFromRect(gsScreenRect));

    if (NSMaxY(displayRect) < screenSize.height) {
      newOrigin.y += (screenSize.height - NSMaxY(displayRect));
    }
    // Add bottom offset
    // Compensate difference between GNUstep and NEXTSPACE screen heights
    if (gsScreenRect.size.height > 0) {
      newOrigin.y -= (screenSize.height - gsScreenRect.size.height);
    }
  }
  else {
    newOrigin.y += displayRect.origin.y;
  }
  
  return newOrigin;
}

- (void)center
{
  NSPoint newOrigin;

  newOrigin = [self centeredOriginForGNUstep:YES];
  NSLog(@"Center: x = %.0f, y = %.0f", newOrigin.x, newOrigin.y);
  // Set the origin
  [self setFrameOrigin:newOrigin];
}

- (void)shakePanel:(Window)panel onDisplay:(Display*)dpy
{
  NSPoint origin = [self centeredOriginForGNUstep:NO];
  int     x, xo, y;
  int     i = 0, j = 0, num_steps, num_shakes;

  xo = x = (int)origin.x;
  y = (int)origin.y;
    
  // NSLog(@"shakePanel with frame: %@", NSStringFromRect(windowRect));
  
  num_steps = 4;
  num_shakes = 14;
  for (i = 0; i < num_shakes; i++)
    {
      for (j = 0; j < num_steps; j++)
        {
          x += 10;
          XMoveWindow(dpy, panel, x, y);
          XSync(dpy, false);
          usleep(600);
        }
      for (j = 0; j < num_steps*2; j++)
        {
          x -= 10;
          XMoveWindow(dpy, panel, x, y);
          XSync(dpy, false);
          usleep(600);
        }
      for (j = 0; j < num_steps; j++)
        {
          x += 10;
          XMoveWindow(dpy, panel, x, y);
          XSync(dpy, false);
          usleep(600);
        }
    }
  // XMoveWindow(dpy, panel, xo, y);
  [self center];
}

#define SHRINKFACTOR 2

- (void)shrinkPanel:(Window)panel onDisplay:(Display *)dpy
{
  NSRect  windowRect = [self frame];
  NSPoint origin = [self centeredOriginForGNUstep:NO];
  GC      gc;
  Pixmap  pixmap;
  XImage  *windowSnap;
  int     x, y, width, height, xo, wo;

  xo = x = (int)origin.x;
  y = (int)origin.y;
  wo = width = (int)windowRect.size.width;
  height = (int)windowRect.size.height;

  pixmap = XCreatePixmap(dpy, panel, width, height, 24);
  gc = XCreateGC(dpy, pixmap, 0, NULL);
    
  windowSnap = XGetImage(dpy, panel, 0, 0, width, height, AllPlanes, XYPixmap);
  XPutImage(dpy, pixmap, gc, windowSnap, 0, 0, 0, 0, width, height);
    
  while ((width - SHRINKFACTOR) > 0) {
    x += SHRINKFACTOR/2;
    width -= SHRINKFACTOR;
    
    XMoveResizeWindow(dpy, panel, x, y, width, height);
    XCopyArea(dpy, pixmap, pixmap, gc,
              SHRINKFACTOR/2, 0, width, height, 0, 0);
    XSetWindowBackgroundPixmap(dpy, panel, pixmap);
    XSync(dpy, False);
    usleep(250);
  }

  // Restore original window size. Don't call XSync and let Controller hide
  // panel before XMoveResizeWindow results will  made visible.
  XMoveResizeWindow(dpy, panel, xo, y, wo, height);
  
  XFree(windowSnap);
  XFreeGC(dpy, gc);
  XFreePixmap(dpy, pixmap);
}

@end
