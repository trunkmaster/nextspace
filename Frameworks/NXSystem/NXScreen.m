/*
 * NXScrren.m
 *
 * Provides integration with XRandR subsystem.
 * Manage display layouts.
 *
 * Copyright 2015, Serg Stoyan
 * All right reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
// screen:
// typedef struct _XRRScreenResources {
//   Time        timestamp;
//   Time        configTimestamp;
//   int         ncrtc;
//   RRCrtc      *crtcs;
//   int         noutput;
//   RROutput    *outputs;
//   int         nmode;
//   XRRModeInfo *modes;
// } XRRScreenResources;
*/

#import <AppKit/NSGraphics.h>

#import "NXDisplay.h"
#import "NXScreen.h"

// Displays.config field keys
NSString *NXDisplayIsActiveKey = @"Active";
NSString *NXDisplayIsMainKey = @"Main";
NSString *NXDisplayGammaKey = @"Gamma";
NSString *NXDisplayGammaRedKey = @"Red";
NSString *NXDisplayGammaGreenKey = @"Green";
NSString *NXDisplayGammaBlueKey = @"Blue";
NSString *NXDisplayGammaBrightnessKey = @"Brightness";
NSString *NXDisplayIDKey = @"ID";
NSString *NXDisplayNameKey = @"Name";
NSString *NXDisplayOriginKey = @"Origin";
NSString *NXDisplayResolutionKey = @"Resolution";
NSString *NXDisplaySizeKey = @"Size";
NSString *NXDisplayRateKey = @"Rate";
NSString *NXDisplayPhSizeKey = @"PhysicalSize";
NSString *NXDisplayPropertiesKey = @"Properties";

// Notifications
NSString *NXScreenDidChangeNotification = @"NXScreenDidChangeNotification";

@interface NXScreen (Private)
- (NSSize)_sizeInPixels;
- (NSSize)_sizeInPixelsForLayout:(NSArray *)layout;
- (NSSize)_sizeInMilimeters;
- (void)_refreshDisplaysInfo;
@end

@implementation NXScreen (Private)
// Calculate screen size in pixels using current displays information
- (NSSize)_sizeInPixels
{
  CGFloat width = 0.0, height = 0.0, w = 0.0, h = 0.0;
  NSRect  dFrame;
  
  for (NXDisplay *display in systemDisplays)
    {
      if ([display isConnected] && [display isActive])
        {
          dFrame = [display frame];
          
          w = dFrame.origin.x + dFrame.size.width;
          if (w > width) width = w;

          h = dFrame.origin.y + dFrame.size.height;
          if (h > height) height = h;
        }
    }

  return NSMakeSize(width, height);
}

// Calculate screen size in pixels using displays information contained
// in 'layout'.
// Doesn't change 'sizeInPixels' ivar.
- (NSSize)_sizeInPixelsForLayout:(NSArray *)layout
{
  CGFloat      width = 0.0, height = 0.0, w = 0.0, h = 0.0;
  NSSize       size;
  NSPoint      origin;
  NSDictionary *resolution;
  
  for (NSDictionary *display in layout)
    {
      if ([[display objectForKey:NXDisplayIsActiveKey] isEqualToString:@"NO"])
        continue;
      
      origin = NSPointFromString([display objectForKey:NXDisplayOriginKey]);
      resolution = [display objectForKey:NXDisplayResolutionKey];
      size = NSSizeFromString([resolution objectForKey:NXDisplaySizeKey]);
          
      w = origin.x + size.width;
      if (w > width) width = w;

      h = origin.y + size.height;
      if (h > height) height = h;
    }

  return NSMakeSize(width, height);
}

// Physical size of screen based on physical sizes of monitors.
// For VM (size of all monitors is 0x0 mm) returns 200x200.
// Doesn't change 'sizeInMilimetres' ivar.
- (NSSize)_sizeInMilimeters
{
  CGFloat      width = 0.0, height = 0.0;
  NSSize       dPSize, pixSize;
  NSDictionary *mode;
  
  for (NXDisplay *display in systemDisplays)
    {
      if ([display isConnected] && [display isActive])
        {
          dPSize = [display physicalSize];
          
          if (dPSize.width > width)
            width = dPSize.width;
          else if (dPSize.width == 0)
            width = 200; // perhaps it's VM, this number will be ignored
          
          if (dPSize.height > height)
            height = dPSize.height;
          else if (dPSize.height == 0)
            height = 200; // perhaps it's VM, this number will be ignored
        }
    }
  
  return NSMakeSize(width, height);
}

// Update display information local cache.
- (void)_refreshDisplaysInfo
{
  NXDisplay *display;

  if (systemDisplays) [systemDisplays release];
  systemDisplays = [[NSMutableArray alloc] init];

  if (screen_resources == NULL)
    {
      screen_resources = XRRGetScreenResources(xDisplay, xRootWindow);
    }

  for (int i=0; i < screen_resources->noutput; i++)
    {
      display = [[NXDisplay alloc]
                  initWithOutputInfo:screen_resources->outputs[i]
                              screen:self
                            xDisplay:xDisplay];
      
      if (XRRGetOutputPrimary(xDisplay, xRootWindow) ==
          screen_resources->outputs[i])
        {
          mainDisplay = display;
        }
      
      [systemDisplays addObject:display];
      [display release];      
    }
  
  // Update screen dimensions
  sizeInPixels = [self _sizeInPixels];
  sizeInMilimeters = [self _sizeInMilimeters];
}

@end

@implementation NXScreen
static id systemScreen = nil;

+ (id)sharedScreen
{
  if (systemScreen == nil)
    {
      self = systemScreen = [NXScreen new];
    }

  return systemScreen;
}

- (id)init
{
  self = [super init];

  xDisplay = XOpenDisplay(getenv("DISPLAY"));
  if (!xDisplay)
    {
      NSLog(@"Can't open Xorg display.");
      return nil;
    }

  {
    int event_base, error_base;
    int major_version, minor_version;

    XRRQueryExtension(xDisplay, &event_base, &error_base);
    XRRQueryVersion(xDisplay, &major_version, &minor_version);

    NSLog(@"XRandR %i.%i, event:%i, erro:%i",
          major_version, minor_version,
          event_base, error_base);
  }

  xRootWindow = RootWindow(xDisplay, DefaultScreen(xDisplay));
  screen_resources = NULL;

  [self _refreshDisplaysInfo];

  // Initially we set primary display to first active
  if ([self mainDisplay] == nil)
    {
      NSLog(@"NXScreen: main display not found, setting first active as main.");
      for (NXDisplay *display in systemDisplays)
        {
          if ([display isActive])
            {
              [display setMain:YES];
              break;
            }
        }
    }

  return self;
}

- (void)dealloc
{
  XRRFreeScreenResources(screen_resources);
  
  XCloseDisplay(xDisplay);

  [super dealloc];
}

//
//------------------------------------------------------------------------------
// Screen resources attributes
//------------------------------------------------------------------------------
//

- (XRRScreenResources *)randrScreenResources
{
  // XLockDisplay(xDisplay);

  if (screen_resources)
    {
      XRRFreeScreenResources(screen_resources);
    }
  screen_resources = XRRGetScreenResources(xDisplay, xRootWindow);
  
  // XUnlockDisplay(xDisplay);
  
  return screen_resources;
}

- (RRCrtc)randrFindFreeCRTC
{
  RRCrtc      crtc;
  XRRCrtcInfo *info;

  for (int i=0; i<screen_resources->ncrtc; i++)
    {
      crtc = screen_resources->crtcs[i];
      info = XRRGetCrtcInfo(xDisplay, screen_resources, crtc);
      // fprintf(stderr, "CRTC '%lu' has %i outputs.\n", crtc, info->noutput);
      
      if (info->noutput == 0)
        break;
    }

  return crtc;
}

- (NSSize)sizeInPixels
{
  return sizeInPixels;
}

- (NSSize)sizeInMilimeters
{
  return sizeInMilimeters;
}

- (NSUInteger)colorDepth
{
  Window root;
  int x, y;
  unsigned width, height, bw, depth;

  XGetGeometry (xDisplay, xRootWindow,
                &root, &x, &y, &width, &height, &bw, &depth);
  XSync (xDisplay, 0);

  return (NSUInteger)depth;
}

- (NSColor *)backgroundColor
{
  // XWindowAttributes attrs;
  // XGCValues gc_values;
  
  // XGetWindowAttributes(xDisplay, xRootWindow, &attrs);
  
  // xScreen = DefaultScreenOfDisplay(xDisplay);
  // XGetGCValues(xDisplay, xScreen->default_gc, GCBackground, &gc_values);

  // fprintf(stderr, "Desktop background: %lu\n", gc_values.background);

  return nil;
}

- (void)setBackgroundColor:(NSColor *)color
{
  Screen *xScreen = DefaultScreenOfDisplay(xDisplay);
  XColor xColor;
  char   *x_color_spec;
  
  // color = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
  // xf.red   = 65535 * [color redComponent];
  // xf.green = 65535 * [color greenComponent];
  // xf.blue  = 65535 * [color blueComponent];

  x_color_spec = (char *)[[NSString stringWithFormat:@"rgb:%x/%x/%x",
                                    (int)(65535 * [color redComponent]),
                                    (int)(65535 * [color greenComponent]),
                                    (int)(65535 * [color blueComponent])]
                           cString];
  fprintf(stderr, "Set root window background: %s\n", x_color_spec);
  
  XParseColor(xDisplay, xScreen->cmap, x_color_spec, &xColor);
  
  // NSDebugLLog(@"XGTrace", @"setbackgroundcolor: %@ %d", color, win);
  // xf = [self xColorFromColor: xf forScreen: window->screen];
  // window->xwn_attrs.background_pixel = xf.pixel;
  
  XSetWindowBackground(xDisplay, xRootWindow, xColor.pixel);
  XSync(xDisplay, False);
  XClearWindow(xDisplay, xRootWindow);
}

//
//------------------------------------------------------------------------------
// Displays
// 
// -allDisplays, -activeDisplays, -connectedDisplay refresh display information
// before returning processed 'systemDisplays' array.
// Other -display* methods work with cached displays information.
//------------------------------------------------------------------------------
//

// Returns array of NXDisplay
- (NSArray *)allDisplays
{
  [self _refreshDisplaysInfo];
  
  return systemDisplays;
}

- (NSArray *)activeDisplays
{
  NSMutableArray *activeDL = [[NSMutableArray alloc] init];
  
  [self _refreshDisplaysInfo];
  
  for (NXDisplay *d in systemDisplays)
    {
      if ([d isActive])
        {
          [activeDL addObject:d];
        }
    }

  return activeDL;
}

- (NSArray *)connectedDisplays
{
  NSMutableArray *connectedDL = [[NSMutableArray alloc] init];

  [self _refreshDisplaysInfo];
  
  for (NXDisplay *d in systemDisplays)
    {
      if ([d isConnected])
        {
          [connectedDL addObject:d];
        }
    }

  return connectedDL;
}

//---

- (NXDisplay *)mainDisplay
{
  NXDisplay *display;
  
  for (display in systemDisplays)
    {
      if ([display isActive] && [display isMain])
        break;
      display = nil;
    }
  
  return display;
}

// TODO
- (NXDisplay *)displayAtPoint:(NSPoint)point
{
  return [systemDisplays objectAtIndex:0];
}

- (NXDisplay *)displayWithName:(NSString *)name
{
  for (NXDisplay *display in systemDisplays)
    {
      if ([[display outputName] isEqualToString:name])
        return display;
    }

  return nil;
}

- (NXDisplay *)displayWithID:(id)uniqueID
{
  NSData *uid;
  for (NXDisplay *display in systemDisplays)
    {
      uid = [display uniqueID];
      if (uid && ([uid hash] == [uniqueID hash]))
        {
          return display;
        }
    }

  return nil;
}

//------------------------------------------------------------------------------
// Layouts
//------------------------------------------------------------------------------
// Described by set of NXDisplay's with:
// - resolution and refresh rate (mode);
// - origin (position) - place displays aligned with each other;
// - rotation
// For example:
// 1. Latop with builtin monitor(1920x1080) has 1 NXDisplay with resolution set
//    to 1920x1080 and origin set to (0,0).
//    Screen size is: 1920x1080.
// 2. Laptop with connected external monitor (1280x1024) has 2 NXDisplays:
//    - builtin with resolution 1920x1080 and origin (0,0);
//    - external monitor with resolution 1280x1024 and origin (1920,0)
//    Screen size is: 3200x1080.

// Resolutions of all connected monitors will be set to preferred (first in
// list of supported) with  highest refresh rate for that
// resolution. Origin of first monitor in Xrandr list will be (0,0). Other
// monitors will lined horizontally from left to right (second monitor's
// origin X will be the width of first one, third's - sum of widths of first
// and second monitors etc.).
// All monitor's Y position = 0.
// All newly connected monitors will be placed rightmost (despite the current
// layout of existing monitors).
- (NSArray *)defaultLayout:(BOOL)arrange
{
  NSMutableDictionary *d;
  NSMutableDictionary *gamma;
  NSMutableArray      *layout = [NSMutableArray new];
  NSDictionary        *resolution;
  NSPoint             origin = NSMakePoint(0.0,0.0);
  NSDictionary        *properties;
  
  for (NXDisplay *display in [self connectedDisplays])
    {
      resolution = [display bestResolution];
      
      d = [[NSMutableDictionary alloc] init];
      [d setObject:([display uniqueID] == nil) ? @" " : [display uniqueID]
            forKey:NXDisplayIDKey];
      [d setObject:[display outputName]
            forKey:NXDisplayNameKey];
      [d setObject:resolution
            forKey:NXDisplayResolutionKey];
      [d setObject:NSStringFromPoint(origin)
            forKey:NXDisplayOriginKey];
      [d setObject:NSStringFromSize([display physicalSize])
            forKey:NXDisplayPhSizeKey];
      [d setObject:@"YES"
            forKey:NXDisplayIsActiveKey];
      [d setObject:([display isMain]) ? @"YES" : @"NO"
            forKey:NXDisplayIsMainKey];
      
      gamma = [NSMutableDictionary new];
      [gamma setObject:[NSNumber numberWithFloat:0.8]
                forKey:NXDisplayGammaRedKey];
      [gamma setObject:[NSNumber numberWithFloat:0.8]
                forKey:NXDisplayGammaGreenKey];
      [gamma setObject:[NSNumber numberWithFloat:0.8]
                forKey:NXDisplayGammaBlueKey];
      [gamma setObject:[NSNumber numberWithFloat:1.0]
                forKey:NXDisplayGammaBrightnessKey];
      [d setObject:gamma forKey:NXDisplayGammaKey];
      
      if ((properties = [display properties]))
        {
          [d setObject:properties forKey:NXDisplayPropertiesKey];
        }
      
      [layout addObject:d];
      [d release];

      if (arrange)
        {
          origin.x +=
            NSSizeFromString([resolution objectForKey:NXDisplaySizeKey]).width;
        }
    }

  return [layout copy];
}

- (NSArray *)currentLayout
{
  NSMutableDictionary *d;
  NSMutableArray      *layout = [NSMutableArray new];
  NSDictionary        *resolution;
  NSPoint             origin = NSMakePoint(0.0,0.0);
  NSDictionary        *properties;
  
  for (NXDisplay *display in [self connectedDisplays])
    {
      d = [[NSMutableDictionary alloc] init];
      [d setObject:([display uniqueID] == nil) ? @" " : [display uniqueID]
            forKey:NXDisplayIDKey];
      [d setObject:[display outputName]
            forKey:NXDisplayNameKey];
      [d setObject:[display resolution]
            forKey:NXDisplayResolutionKey];
      [d setObject:NSStringFromPoint([display frame].origin)
            forKey:NXDisplayOriginKey];
      [d setObject:NSStringFromSize([display physicalSize])
            forKey:NXDisplayPhSizeKey];
      [d setObject:([display isActive]) ? @"YES" : @"NO"
            forKey:NXDisplayIsActiveKey];
      [d setObject:([display isMain]) ? @"YES" : @"NO"
            forKey:NXDisplayIsMainKey];

      [d setObject:[display gammaDescription] forKey:NXDisplayGammaKey];
      if ((properties = [display properties]))
        {
          [d setObject:properties forKey:NXDisplayPropertiesKey];
        }

      [layout addObject:d];
      [d release];
    }

  return layout;
}

- (BOOL)validateLayout:(NSArray *)layout
{
  NSDictionary *gamma;
  
  for (NSDictionary *d in layout)
    {
      if (![self displayWithID:[d objectForKey:NXDisplayIDKey]])
        { // Some display is not connected - use default layout
          NSLog(@"NXScreen: display is not connected");
          return NO;
        }
      if (![d objectForKey:NXDisplayResolutionKey] ||
          ![d objectForKey:NXDisplayOriginKey])
        { // Display resolution or origin not found
          NSLog(@"NXScreen: display no saved resolution or origin");
          return NO;
        }
      ;
      if (!(gamma = [d objectForKey:NXDisplayGammaKey]) ||
          ![gamma objectForKey:NXDisplayGammaRedKey] ||
          ![gamma objectForKey:NXDisplayGammaGreenKey] ||
          ![gamma objectForKey:NXDisplayGammaBlueKey] ||
          ![gamma objectForKey:NXDisplayGammaBrightnessKey])
        { // Something wrong with saved gamma
          NSLog(@"NXScreen: display no saved gamma");
          return NO;
        }
    }

  return YES;
}

- (void)applyDisplayLayout:(NSArray *)layout
{
  NSSize    newPixSize;
  NSSize    mmSize;
  BOOL      isGrowing = NO;
  NXDisplay *display;
  XRRProviderResources *provider_resources;

  // Validate 'layout'
  if ([self validateLayout:layout] == NO)
    {
      NSLog(@"NXScreen:Applying default layout. Display.config ignored.");
      layout = [self defaultLayout:YES];
    }
  
  newPixSize = [self _sizeInPixelsForLayout:layout];
  mmSize = [self _sizeInMilimeters];
  NSLog(@"New screen size: %@, old %.0fx%.0f",
        NSStringFromSize(newPixSize), sizeInPixels.width, sizeInPixels.height);
  // Deactivate displays with current width or height bigger
  // than new screen size. Otherwise [NXDisplay setResolution...] will fail with
  // XRandR error and application will be terminated.
  NSRect dRect;
  for (NXDisplay *d in [self activeDisplays])
    {
      // dRect = [d frame];
      // if (sizeInPixels.width < dRect.size.width ||
      //     sizeInPixels.height < dRect.size.height)
      //   {
          [d deactivate];
        // }
    }

  // Set new screen size for new layout
  XRRSetScreenSize(xDisplay, xRootWindow,
                   (int)newPixSize.width, (int)newPixSize.height,
                   (int)mmSize.width, (int)mmSize.height);
  
  // if (sizeInPixels.width < newPixSize.width &&
  //     sizeInPixels.height < newPixSize.height)
  //   {
  //     // Screen is getting bigger
  //     isGrowing = YES;
  //     XRRSetScreenSize(xDisplay, xRootWindow,
  //                      (int)newPixSize.width, (int)newPixSize.height,
  //                      (int)mmSize.width, (int)mmSize.height);
  //   }
  
  sizeInPixels = newPixSize;
  
  // Set resolution and gamma to displays
  NSString     *displayName;
  NSDictionary *gamma;
  NSDictionary *resolution;
  NSPoint      origin;
  for (NSDictionary *displayLayout in layout)
    {
      displayName = [displayLayout objectForKey:NXDisplayNameKey];
      display = [self displayWithName:displayName];
      
      if ([[displayLayout objectForKey:NXDisplayIsActiveKey]
            isEqualToString:@"NO"])
        {
          [display deactivate];
        }
      else
        {
          gamma = [displayLayout objectForKey:NXDisplayGammaKey];
          [display setGammaFromDescription:gamma];

          resolution = [displayLayout objectForKey:NXDisplayResolutionKey];
          origin = NSPointFromString([displayLayout
                                       objectForKey:NXDisplayOriginKey]);
          [display setResolution:resolution origin:origin];
        }
    }

  // Screen size gets smaller and must have changed after display
  // resolution changes.
  // if (isGrowing == NO)
  //   {
  //     XRRSetScreenSize(xDisplay, xRootWindow,
  //                      (int)newPixSize.width, (int)newPixSize.height,
  //                      (int)mmSize.width, (int)mmSize.height);
  //   }

  // XUngrabServer(xDisplay);
  
  [self _refreshDisplaysInfo];
}

- (void)setDisplay:(NXDisplay *)display
        resolution:(NSDictionary *)resolution
            origin:(NSPoint)origin
{
  NSString            *displayName = [display outputName];
  NSMutableArray      *newLayout = [[self currentLayout] mutableCopy];
  NSDictionary	      *d;
  NSMutableDictionary *dd;
  NSUInteger	      i, dCount;
  NSSize	      oldSize, dSize, newSize;
  NSPoint             oldOrigin, dOrigin;
  CGFloat	      xOffset, yOffset;
  CGFloat 	      dTopY, dRightX, oldTopY, oldRightX;
  
  // [newLayout writeToFile:@"Display.config" atomically:YES];
  
  // 1. Change resolution and origin of display in layout.
  dCount = [newLayout count];
  for (i = 0; i < dCount; i++)
    {
      d = [newLayout objectAtIndex:i];
      if ([[d objectForKey:NXDisplayNameKey] isEqualToString:displayName])
        {
          // Save old values for resolution and origin
          oldSize = NSSizeFromString([[d objectForKey:NXDisplayResolutionKey]
                                       objectForKey:NXDisplaySizeKey]);
          oldOrigin = NSPointFromString([d objectForKey:NXDisplayOriginKey]);
          oldTopY = oldOrigin.y + oldSize.height;
          oldRightX = oldOrigin.x + oldSize.width;
          newSize = NSSizeFromString([resolution objectForKey:NXDisplaySizeKey]);
          
          dd = [d mutableCopy];
          [dd setObject:resolution forKey:NXDisplayResolutionKey];
          [dd setObject:NSStringFromPoint(origin) forKey:NXDisplayOriginKey];
          [newLayout replaceObjectAtIndex:i withObject:dd];
          [dd release];
          break;
        }
    }

  // 2. Change origin of other display(s) if new resolution requires it.
  for (NSUInteger i=0; i<[newLayout count]; i++)
    {
      d = [newLayout objectAtIndex:0];
      if (![[d objectForKey:NXDisplayNameKey] isEqualToString:displayName])
        {
          dSize = NSSizeFromString([[d objectForKey:NXDisplayResolutionKey]
                                       objectForKey:NXDisplaySizeKey]);
          dOrigin = NSPointFromString([d objectForKey:NXDisplayOriginKey]);
          dTopY = dOrigin.y + dSize.height;
          dRightX = dOrigin.x + dSize.width;
          // Adjust horizontal position
          if ((dOrigin.x > oldOrigin.x) &&
              (dTopY > oldOrigin.y && dOrigin.y < oldTopY))
            {
              xOffset = dOrigin.x - oldOrigin.x - oldSize.width;
              dOrigin.x = origin.x + newSize.width + xOffset;
            }
          // Adjust vertical position
          if ((dOrigin.y > oldOrigin.y) &&
              (dRightX > oldOrigin.x && dOrigin.x < oldRightX))
            {
              yOffset = dOrigin.y - oldOrigin.y - oldSize.height;
              dOrigin.y = origin.y + newSize.height + yOffset;
            }
          
          dd = [d mutableCopy];
          [dd setObject:NSStringFromPoint(dOrigin) forKey:NXDisplayOriginKey];
          [newLayout replaceObjectAtIndex:[newLayout indexOfObject:d]
                               withObject:dd];
          [dd release];
        }
    }

  // 3. Apply new layout
  // [newLayout writeToFile:@"NewDisplay.config" atomically:YES];
  [self applyDisplayLayout:newLayout];
  [newLayout release];
}

//------------------------------------------------------------------------------
// Video adapters
//------------------------------------------------------------------------------
  // provider_resources = XRRGetProviderResources(xDisplay, xRootWindow);
  // if (provider_resources->nproviders < 1)
  //   { // No video cards - applying layout doesn't make sense or work.
  //     NSLog(@"NXScreen: No video adapters found - no saved layout will be applied.");
  //     XRRFreeProviderResources(provider_resources);
  //     return;
  //   }

@end
