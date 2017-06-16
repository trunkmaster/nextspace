/* 
   LoginWindow.h

   Class to allow the display of a borderless window.  It also
   provides the necessary functionality for some of the other nice
   things we want the window to do.

   Copyright (C) 2000 Gregory John Casamento 

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2000
   
   This file is part of GNUstep.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   You can reach me at:
   Gregory Casamento, 14218 Oxford Drive, Laurel, MD 20707, 
   USA
*/

#import "unistd.h"
#import <X11/Xlib.h>

#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>

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

- (void)center
{
  NXScreen  *screen = nil;
  NXDisplay *mainDisplay = nil;
  NSRect    mDisplayRect, gScreenRect, windowRect;
  NSPoint   newOrigin;

  // Get NEXTSPACE screen rect
  screen = [NXScreen sharedScreen];
  [screen randrUpdateScreenResources];
  mainDisplay = [screen mainDisplay];
  if (!mainDisplay)
    {
      mainDisplay = [[screen activeDisplays] objectAtIndex:0];
    }
  mDisplayRect = [mainDisplay frame];
  NSLog(@"NEXTSPACE screen size: %@", NSStringFromRect(mDisplayRect));

  // Get GNUstep screen rect
  gScreenRect = [[self screen] frame];
  NSLog(@"GNUstep screen size: %@", NSStringFromRect(gScreenRect));
    
  // Get window size
  windowRect = [self frame];
    
  // Calculate the new position of the window.
  newOrigin.x = mDisplayRect.size.width/2 - windowRect.size.width/2;
  newOrigin.x += mDisplayRect.origin.x;
  newOrigin.y = mDisplayRect.size.height/2 - windowRect.size.height/2;
  newOrigin.y += gScreenRect.size.height - mDisplayRect.size.height;

  // Set the origin
  [self setFrameOrigin:newOrigin];
  // NSLog(@"Center: x=%f y=%f", newOrigin.x, newOrigin.y);
}

- (void)awakeFromNib
{
  NSRect rect;

  rect = [self frame];
  rect.size = [[panelImageView image] size];
  [self setFrame:rect display:NO];
  [self center];

  [self displayHostname];
}

- (void)shakePanel:(Window)panel onDisplay:(Display*)dpy
{
  NSRect windowRect = [self frame];
  int    i = 0, j = 0, num_steps, num_shakes;
  int    x = (int)windowRect.origin.x;
  int    xo = x;
  int    y = (int)windowRect.origin.y;
  
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
  XMoveWindow(dpy, panel, xo, y);
}

#define SHRINKFACTOR 2

- (void)shrinkPanel:(Window)panel onDisplay:(Display *)dpy
{
  NSRect windowRect = [self frame];
  NSRect mDisplayRect = [[[NXScreen sharedScreen] mainDisplay] frame];
  GC     gc;
  Pixmap pixmap;
  XImage *windowSnap;
  int    x, y, width, height, xo, wo;

  xo = x = (int)windowRect.origin.x;
  y = (int)(mDisplayRect.size.height - windowRect.size.height)/2;
  wo = width = (int)windowRect.size.width;
  height = (int)windowRect.size.height;

  pixmap = XCreatePixmap(dpy, panel, width, height, 24);
  gc = XCreateGC(dpy, pixmap, 0, NULL);
    
  windowSnap = XGetImage(dpy, panel, 0, 0, width, height, AllPlanes, XYPixmap);
  XPutImage(dpy, pixmap, gc, windowSnap, 0, 0, 0, 0, width, height);
    
  while ((width - SHRINKFACTOR) > 0)
    {
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

- (void)displayHostname
{
  char     hostname[256], displayname[256];
  int      namelen = 256, index = 0;
  NSString *host_name = nil;

  // Initialize hostname
  gethostname( hostname, namelen );
  for(index = 0; index < 256 && hostname[index] != '.'; index++)
    {
      displayname[index] = hostname[index];
    }
  displayname[index] = 0;
  host_name = [NSString stringWithCString:displayname];
  [hostnameField setStringValue:host_name];
}

@end

