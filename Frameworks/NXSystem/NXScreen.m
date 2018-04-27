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
x//   RRCrtc      *crtcs;
//   int         noutput;
//   RROutput    *outputs;
//   int         nmode;
//   XRRModeInfo *modes;
// } XRRScreenResources;
*/

#import <AppKit/NSGraphics.h>
#import <NXAppKit/NXAlert.h>
#import <NXFoundation/NXDefaults.h>
#include <X11/Xatom.h>

#import "NXDisplay.h"
#import "NXScreen.h"
#import "NXPower.h"
#import "NXMouse.h"

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
NSString *NXDisplayFrameKey = @"Frame";
NSString *NXDisplayHiddenFrameKey = @"FrameHidden";
NSString *NXDisplayFrameRateKey = @"FrameRate";
NSString *NXDisplaySizeKey = @"Size";
NSString *NXDisplayRateKey = @"Rate";
NSString *NXDisplayPhSizeKey = @"PhysicalSize";
NSString *NXDisplayPropertiesKey = @"Properties";

// Notifications
NSString *NXScreenDidChangeNotification = @"NXScreenDidChangeNotification";
NSString *NXScreenDidUpdateNotification = @"NXScreenDidUpdateNotification";

static NXScreen *systemScreen = nil;

@interface NXScreen (Private)
- (NSSize)_sizeInPixels;
- (NSSize)_sizeInPixelsForLayout:(NSArray *)layout;
- (NSSize)_sizeInMilimeters;
- (NSSize)_sizeInMilimetersForLayout:(NSArray *)layout;
- (NSString *)_displayConfigFileName;
- (void)_restoreDisplaysAttributesFromLayout:(NSArray *)layout;
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
  NSRect       frame;
  
  for (NSDictionary *display in layout)
    {
      if ([[display objectForKey:NXDisplayIsActiveKey] isEqualToString:@"NO"])
        continue;
      
      frame = NSRectFromString([display objectForKey:NXDisplayFrameKey]);
          
      w = frame.origin.x + frame.size.width;
      if (w > width) width = w;

      h = frame.origin.y + frame.size.height;
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

// Calculate screen size in pixels using displays information contained
// in 'layout'.
// Doesn't change 'sizeInPixels' ivar.
// TODO: calculate real size wrt monitor layout
- (NSSize)_sizeInMilimetersForLayout:(NSArray *)layout
{
  CGFloat      width = 0.0, height = 0.0;
  NSSize       dPSize, pixSize;
  NSDictionary *mode;
  
  for (NSDictionary *display in layout)
    {
      if ([[display objectForKey:NXDisplayIsActiveKey] isEqualToString:@"NO"])
        continue;
      
      dPSize = NSSizeFromString([display objectForKey:NXDisplayPhSizeKey]);
          
      if (dPSize.width > width)
        width = dPSize.width;
      else if (dPSize.width == 0)
        width = 200; // perhaps it's VM, this number will be ignored
          
      if (dPSize.height > height)
        height = dPSize.height;
      else if (dPSize.height == 0)
        height = 200; // perhaps it's VM, this number will be ignored
    }
  
  return NSMakeSize(width, height);
}

- (NSString *)_displayConfigFileName
{
  NSUInteger layoutHash = 0;
  NSString   *configDir;

  // Construct path to config file
  configDir = [LAYOUTS_DIR stringByExpandingTildeInPath];
  
  for (NXDisplay *d in [self connectedDisplays])
    {
      layoutHash += [[d uniqueID] hash];
    }
  
  return [NSString stringWithFormat:@"%@/Displays-%lu.config",
                   configDir, layoutHash];
}

// Restore some Display attributes from saved layout (if any)
- (void)_restoreDisplaysAttributesFromLayout:(NSArray *)layout
{
  id	       attribute;
  NSRect       hiddenFrame;
  NSDictionary *props;
  
  if (layout == nil)
    return;
  
  for (NXDisplay *d in systemDisplays)
    {
      // FrameHidden
      attribute = [self objectForKey:NXDisplayHiddenFrameKey
                          forDisplay:d
                            inLayout:layout];
      if (attribute != nil && [attribute isKindOfClass:[NSString class]])
        {
          hiddenFrame = NSRectFromString(attribute);
          NSDebugLLog(@"Screen", @"[NXScreen] %@ restore hiddenFrame: %@",
                      d.outputName, attribute);
          if ([d isActive] == NO && NSIsEmptyRect(hiddenFrame) == NO)
            {
              d.hiddenFrame = hiddenFrame;
            }
        }

      // Gamma
      attribute = [self objectForKey:NXDisplayGammaKey
                          forDisplay:d
                            inLayout:layout];
      if (attribute != nil &&
          [attribute isKindOfClass:[NSDictionary class]])
        {
          // Only 'gammaValue' ivar will be set if display is inactive
          [d setGammaFromDescription:attribute];
        }
    }
}

@end

@implementation NXScreen

+ (id)sharedScreen
{
  if (systemScreen == nil)
    {
      systemScreen = [[NXScreen alloc] init];
    }

  return systemScreen;
}

- (id)init
{
  self = [super init];

  xDisplay = XOpenDisplay(getenv("DISPLAY"));
  if (!xDisplay)
    {
      NSLog(@"Can't open Xorg display. Please setup DISPLAY environment variable.");
      return nil;
    }

  {
    int event_base, error_base;
    int major_version, minor_version;

    XRRQueryExtension(xDisplay, &event_base, &error_base);
    XRRQueryVersion(xDisplay, &major_version, &minor_version);

    NSDebugLLog(@"Screen", @"XRandR %i.%i, event base:%i, error base:%i",
                major_version, minor_version,
                event_base, error_base);
  }

  xRootWindow = RootWindow(xDisplay, DefaultScreen(xDisplay));
  screen_resources = NULL;

  updateScreenLock = [[NSLock alloc] init];
  [self randrUpdateScreenResources];

  // Initially we set primary display to first active
  if ([self mainDisplay] == nil)
    {
      NSDebugLLog(@"Screen", @"NXScreen: main display not found, setting first active as main.");
      for (NXDisplay *display in systemDisplays)
        {
          if ([display isActive])
            {
              [display setMain:YES];
              break;
            }
        }
    }

  useAutosave = NO;

  // Workspace Manager notification sent as a reaction to XRRScreenChangeNotify
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(randrScreenDidChange:)
           name:NXScreenDidChangeNotification
         object:nil];

  return self;
}

- (void)setUseAutosave:(BOOL)yn
{
  useAutosave = yn;
}

- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"NXScreen: -dealloc");
  
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];

  XRRFreeScreenResources(screen_resources);
  
  XCloseDisplay(xDisplay);

  [systemDisplays release];
  [updateScreenLock release];

  [super dealloc];
}

//
//------------------------------------------------------------------------------
// Screen resources attributes
//------------------------------------------------------------------------------
//

// External notification - NXScreenDidChangeNotification.
// XRRScreenResources update will generate NXScreenDidUpdateNotification.
- (void)randrScreenDidChange:(NSNotification *)aNotif
{
  NSDebugLLog(@"Screen", @"NXScreen: NXScreenDidChangeNotification received.");
  
  [self randrUpdateScreenResources];
}

- (XRRScreenResources *)randrScreenResources
{
  if (screen_resources == NULL)
    {
      [self randrUpdateScreenResources];
    }
  
  return screen_resources;
}

- (void)randrUpdateScreenResources
{
  NXDisplay *display;
  
  if ([updateScreenLock tryLock] == NO)
    {
      NSDebugLLog(@"Screen", @"NXScreen: update of XRandR screen resources was unsuccessful!");
      return;
    }
    
  NSDebugLLog(@"Screen", @"NXScreen: randrUpdateScreenResources: START");
  
  // Reread screen resources
  if (screen_resources)
    {
      XRRFreeScreenResources(screen_resources);
    }
  screen_resources = XRRGetScreenResources(xDisplay, xRootWindow);

  // Create/clean display information local cache.
  if (systemDisplays)
    {
      [systemDisplays removeAllObjects];
    }
  else
    {
      systemDisplays = [[NSMutableArray alloc] init];
    }

  // Update displays info
  for (int i=0; i < screen_resources->noutput; i++)
    {
      display = [[NXDisplay alloc]
                  initWithOutputInfo:screen_resources->outputs[i]
                     screenResources:screen_resources
                              screen:self
                            xDisplay:xDisplay];
      
      [systemDisplays addObject:display];
      [display release];
    }

  // Restore some Display attributes from saved layout (if any)
  [self _restoreDisplaysAttributesFromLayout:[self savedDisplayLayout]];

  // Update screen dimensions
  sizeInPixels = [self _sizeInPixels];
  sizeInMilimeters = [self _sizeInMilimeters];

  [updateScreenLock unlock];
  
  NSDebugLLog(@"Screen", @"NXScreen: randrUpdateScreenResources: END");
  
  [[NSNotificationCenter defaultCenter]
    postNotificationName:NXScreenDidUpdateNotification
                  object:self];
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

- (BOOL)savedBackgroundColorRed:(CGFloat *)redComponent
                          green:(CGFloat *)greenComponent
                           blue:(CGFloat *)blueComponent
{
  NSDictionary	*dBack;
  BOOL		success = NO;
  
  dBack =  [[NXDefaults globalUserDefaults]
                               objectForKey:@"NXDesktopBackgroundColor"];
  if (dBack)
    {
      *redComponent = [dBack[@"Red"] floatValue];
      *greenComponent = [dBack[@"Green"] floatValue];
      *blueComponent = [dBack[@"Blue"] floatValue];
      success = YES;
    }
  else
    {
      *redComponent = 83.0/255.0;
      *greenComponent = 83.0/255.0;
      *blueComponent = 116.0/255.0;
      success = YES;
    }
  
  return success;
}

- (BOOL)backgroundColorRed:(CGFloat *)redComponent
                     green:(CGFloat *)greenComponent
                      blue:(CGFloat *)blueComponent
{
  XWindowAttributes	attrs;
  XImage		*image;
  unsigned long		pixel;
  BOOL			success = NO;

  // Try to get background color from root window pixel at (0,0).
  // Other pixels have random values. Perhaps because root window background
  // is set with XSetWindowBackground function and:
  // "XSetWindowBackground uses a pixmap of undefined size filled with the pixel
  // value you passed" [XSetWindowBackground(3)].
  if (XGetWindowAttributes(xDisplay, xRootWindow, &attrs) != 0)
    {
      image = XGetImage(xDisplay, xRootWindow, 0, 0,
                        attrs.width, attrs.height, AllPlanes, ZPixmap);
      if (image != NULL)
        {
          pixel = XGetPixel(image, attrs.width-1, attrs.height-1); // magic: works in VM
          // fprintf(stderr, "X Offset: %i\n", image->xoffset);
          // fprintf(stderr, "BP Red: %lu (%f)\n",
          //         (attrs.backing_pixel), (CGFloat)(attrs.backing_pixel>>16)/255.0);
          // fprintf(stderr, "Red  : %lu (%f)\n",
          //         (pixel>>16), (CGFloat)(pixel>>16)/255.0);
          // fprintf(stderr, "Green: %lu (%f)\n",
          //         ((pixel&0x00ff00)>>8), (CGFloat)((pixel&0x00ff00)>>8)/255.0);
          // fprintf(stderr, "Blue : %lu (%f)\n",
          //         (pixel&0x0000ff), (CGFloat)(pixel&0x0000ff)/255.0);
          // cBack = [NSColor colorWithDeviceRed:(CGFloat)(pixel>>16)/255.0
          //                               green:(CGFloat)((pixel&0x00ff00)>>8)/255.0
          //                                blue:(CGFloat)(pixel&0x0000ff)/255.0
          //                               alpha:1.0];
          *redComponent = (CGFloat)(pixel>>16)/255.0;
          *greenComponent = (CGFloat)((pixel&0x00ff00)>>8)/255.0;
          *blueComponent = (CGFloat)(pixel&0x0000ff)/255.0;
          XDestroyImage(image);
          success = YES;
        }
    }

  if (success == NO)
    {
      success = [self savedBackgroundColorRed:redComponent
                                        green:greenComponent
                                         blue:blueComponent];
    }
  
    
  return success;
}

- (BOOL)setBackgroundColorRed:(CGFloat)redComponent
                        green:(CGFloat)greenComponent
                         blue:(CGFloat)blueComponent
{
  unsigned	red, green, blue;
  NSString	*rgbSpec;
  char		*x_color_spec;
  Screen	*xScreen = DefaultScreenOfDisplay(xDisplay);
  XColor	xColor;

  // rgbColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
  
  red     = (unsigned)(255/(1/redComponent));
  green   = (unsigned)(255/(1/greenComponent));
  blue    = (unsigned)(255/(1/blueComponent));
  rgbSpec = [NSString stringWithFormat:@"rgb:%.2x/%.2x/%.2x", red, green, blue];
  
  x_color_spec = (char *)[rgbSpec cString];
  
  if (!XParseColor(xDisplay, xScreen->cmap, x_color_spec, &xColor))
    {
      fprintf(stderr,"NXScreen: unknown color \"%s\"\n", x_color_spec);
      return NO;
    }
  if (!XAllocColor(xDisplay, xScreen->cmap, &xColor))
    {
      fprintf(stderr, "NXScreen: unable to allocate color for \"%s\"\n",
              x_color_spec);
      return NO;
    }
  
  XSetWindowBackground(xDisplay, xRootWindow, xColor.pixel);
  XClearWindow(xDisplay, xRootWindow);
  XSync(xDisplay, False);
  return YES;
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
  return systemDisplays;
}

- (NSArray *)activeDisplays
{
  NSMutableArray *activeDL = [[NSMutableArray alloc] init];
  
  for (NXDisplay *d in systemDisplays)
    {
      if ([d isActive])
        {
          [activeDL addObject:d];
        }
    }

  return [activeDL autorelease];
}

- (NSArray *)connectedDisplays
{
  NSMutableArray *connectedDL = [[NSMutableArray alloc] init];

  for (NXDisplay *d in systemDisplays)
    {
      if ([d isConnected])
        {
          [connectedDL addObject:d];
        }
    }

  return [connectedDL autorelease];
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

- (void)setMainDisplay:(NXDisplay *)display
{
  if (display == nil)
    {
      XRRSetOutputPrimary(xDisplay, xRootWindow, None);
      [self randrUpdateScreenResources];
      return;
    }
  
  for (NXDisplay *d in systemDisplays)
    {
      [d setMain:(d == display) ? YES : NO];
    }
  [self randrUpdateScreenResources];
  if (useAutosave)
    [self saveCurrentDisplayLayout];
}

- (NXDisplay *)displayAtPoint:(NSPoint)point
{
  for (NXDisplay *display in systemDisplays)
    {
      if (NSPointInRect(point, [display frame]) == YES)
        return display;
    }
  
  return nil;
}

- (NXDisplay *)displayWithMouseCursor
{
  NXMouse   *mouse;
  NXDisplay *display;

  mouse = [NXMouse new];
  display = [self displayAtPoint:[mouse locationOnScreen]];
  [mouse release];

  return display;
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

- (NSPoint)positionForDisplay:(NXDisplay *)display
                  isActivated:(BOOL)activated
{
  NSPoint position;

  if (activated == NO)
    return display.hiddenFrame.origin;
  
  position = NSMakePoint(0, 0);
  for (NXDisplay *d in [self connectedDisplays])
    {
      if (d != display)
        position.x += d.frame.size.width;
    }
  
  return position;
}

- (void)activateDisplay:(NXDisplay *)display
{
  NSArray *newLayout;
  NSRect frame;
  
  NSDebugLLog(@"Screen",
              @"NXSystem: prepare to activate display: %@ with hiddenFrame: %@",
              display.outputName, NSStringFromRect(display.hiddenFrame));
  NSDebugLLog(@"Screen",
              @"NXSystem: prepare to activate display: %@ with frame: %@",
              display.outputName, NSStringFromRect(display.frame));  
  
  [display setActive:YES];
  // frame = display.frame;
  // frame.origin = [self positionForDisplay:display isActivated:YES];
  // display.frame = display.hiddenFrame;
  
  newLayout = [self arrangedDisplayLayout];
 
  NSDebugLLog(@"Screen",
              @"NXSystem: activate display: %@ with frame: %@",
              display.outputName, NSStringFromRect(display.frame));

  XLockDisplay(xDisplay);
  [self applyDisplayLayout:newLayout];
  XUnlockDisplay(xDisplay);
}

- (void)deactivateDisplay:(NXDisplay *)display
{
  NSArray *newLayout;

  [display setActive:NO];
  
  newLayout = [self arrangedDisplayLayout];

  XLockDisplay(xDisplay);
  [self applyDisplayLayout:newLayout];
  XUnlockDisplay(xDisplay);
  
  NSDebugLLog(@"Screen",
              @"NXSystem: deactivated display: %@ with frame: %@",
              display.outputName, NSStringFromRect(display.frame));
  NSDebugLLog(@"Screen",
              @"NXSystem: deactivated display: %@ with hiddenFrame: %@",
              display.outputName, NSStringFromRect(display.hiddenFrame));
}

- (void)setDisplay:(NXDisplay *)display
        resolution:(NSDictionary *)resolution
{
  NSRect  frame = display.frame;
  NSArray *newLayout;

  frame.size = NSSizeFromString([resolution objectForKey:NXDisplaySizeKey]);
  display.frame = frame;
  
  [self applyDisplayLayout:[self arrangedDisplayLayout]];
}

- (void)setDisplay:(NXDisplay *)display
          position:(NSPoint)position
{
  NSRect  frame = [display frame];

  if (NSEqualPoints(position, frame.origin) == NO)
    {
      frame.origin = position;
      [display setFrame:frame];
  
      [self applyDisplayLayout:[self arrangedDisplayLayout]];
    }
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
// list of supported) with highest refresh rate for that resolution. Origin of
// first monitor in Xrandr list will be (0,0). Other monitors will lined
// horizontally from left to right (second monitor's origin X will be the width
// of first one, third's - sum of widths of first and second monitors etc.).
// All monitor's Y position = 0.
// All newly connected monitors will be placed rightmost (despite the current
// layout of monitors).
- (NSArray *)defaultLayout:(BOOL)arrange
{
  NSMutableDictionary *d;
  NSMutableDictionary *gamma;
  NSMutableArray      *layout = [NSMutableArray new];
  NSDictionary        *resolution;
  NSPoint             origin = NSMakePoint(0.0,0.0);
  NSSize              size;
  NSRect              frame;
  NSDictionary        *properties;
  
  for (NXDisplay *display in [self connectedDisplays])
    {
      // With default layout all monitors have origin set to (0.0,0.0),
      // show the same contents. Primary(main) display make sense on aligned
      // monitors (screen stretched across all active monitors).
      // So in this case all monitors must be unset as primary(main).
      if (arrange == NO)
        [display setMain:NO];
      else if ([systemDisplays indexOfObject:display] == 0)
        [display setMain:YES];
        
      d = [[NSMutableDictionary alloc] init];
      [d setObject:([display uniqueID] == nil) ? @" " : [display uniqueID]
            forKey:NXDisplayIDKey];
      [d setObject:[display outputName]
            forKey:NXDisplayNameKey];
      
      [d setObject:NSStringFromSize([display physicalSize])
            forKey:NXDisplayPhSizeKey];
      
      // Preferred resolution always at first position.
      resolution = [display bestResolution];
      frame = NSZeroRect;
      frame.size = NSSizeFromString([resolution objectForKey:NXDisplaySizeKey]);
      frame.origin = origin;
      
      [d setObject:NSStringFromRect(frame)
            forKey:NXDisplayFrameKey];
      [d setObject:NSStringFromRect(NSZeroRect)
            forKey:NXDisplayHiddenFrameKey];
      [d setObject:[resolution objectForKey:NXDisplayRateKey]
            forKey:NXDisplayFrameRateKey];

      if ([display isBuiltin] && [NXPower isLidClosed])
        {
          [d setObject:@"NO" forKey:NXDisplayIsActiveKey];
          [d setObject:@"NO" forKey:NXDisplayIsMainKey];
        }
      else
        {
          [d setObject:@"YES" forKey:NXDisplayIsActiveKey];
          [d setObject:([display isMain]) ? @"YES" : @"NO"
                forKey:NXDisplayIsMainKey];
        }
      
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

      if (arrange && (![display isBuiltin] || ![NXPower isLidClosed]))
        {
          origin.x +=
            NSSizeFromString([resolution objectForKey:NXDisplaySizeKey]).width;
        }
    }

  return [layout copy];
}

// Create layout description from displays' actual (visible by user)
// information.
- (NSArray *)currentLayout
{
  NSMutableDictionary *d;
  NSMutableArray      *layout = [NSMutableArray new];
  NSDictionary        *resolution;
  NSDictionary        *properties;
  NSDictionary        *gamma;

  for (NXDisplay *display in [self connectedDisplays])
    {
      d = [[[NSMutableDictionary alloc] init] autorelease];
      @try
        {
          [d setObject:([display uniqueID] == nil) ? @" " : [display uniqueID]
                forKey:NXDisplayIDKey];
          [d setObject:[display outputName]
                forKey:NXDisplayNameKey];
      
          [d setObject:NSStringFromSize([display physicalSize])
                forKey:NXDisplayPhSizeKey];

          [d setObject:NSStringFromRect([display frame])
                forKey:NXDisplayFrameKey];
          [d setObject:NSStringFromRect([display hiddenFrame])
                forKey:NXDisplayHiddenFrameKey];
          [d setObject:[display.activeResolution objectForKey:NXDisplayRateKey]
                forKey:NXDisplayFrameRateKey];

          [d setObject:([display isActive]) ? @"YES" : @"NO"
                forKey:NXDisplayIsActiveKey];
          [d setObject:([display isMain]) ? @"YES" : @"NO"
                forKey:NXDisplayIsMainKey];

          gamma = [display gammaDescription];
          [d setObject:gamma forKey:NXDisplayGammaKey];
          if ((properties = [display properties]))
            {
              [d setObject:properties forKey:NXDisplayPropertiesKey];
            }
        }
      @catch (NSException *exception)
        {
          NSLog(@"Exception occured during getting layout of displays: %@",
                exception.description);
        }

      [layout addObject:d];
    }

  return layout;
}

- (BOOL)validateLayout:(NSArray *)layout
{
  NSDictionary	*gamma;
  NSString	*dName;
  NSRect	dFrame;
  NSDictionary	*resolution;
  
  for (NSDictionary *d in layout)
    {
      dName = [d objectForKey:NXDisplayNameKey];

      // ID
      if (![self displayWithID:[d objectForKey:NXDisplayIDKey]])
        { // Some display is not connected - use default layout
          NSDebugLLog(@"Screen", @"NXScreen: monitor %@ is not connected.", dName);
          return NO;
        }

      // Resolution & origin
      dFrame = NSRectFromString([d objectForKey:NXDisplayFrameKey]);
      if ([[d objectForKey:NXDisplayIsActiveKey] isEqualToString:@"YES"] &&
          (dFrame.size.width <= 0 || dFrame.size.height <= 0))
        { // Display resolution or origin not found
          NSDebugLLog(@"Screen",
                      @"NXScreen: monitor %@ has no saved resolution or origin.",
                      dName);
          return NO;
        }

      // Is resolution supported by monitor?
      // resolution = [d objectForKey:NXDisplayResolutionKey];
      // if (![[self displayWithName:dName] isSupportedResolution:resolution])
      //   {
      //     NSLog(@"NXScreen: monitor %@ doesn't support resolution %@.",
      //           dName, [resolution objectForKey:NXDisplaySizeKey]);
      //     return NO;
      //   }
      
      if (!(gamma = [d objectForKey:NXDisplayGammaKey]) ||
          ![gamma objectForKey:NXDisplayGammaRedKey] ||
          ![gamma objectForKey:NXDisplayGammaGreenKey] ||
          ![gamma objectForKey:NXDisplayGammaBlueKey] ||
          ![gamma objectForKey:NXDisplayGammaBrightnessKey])
        { // Something wrong with saved gamma
          NSDebugLLog(@"Screen", @"NXScreen: display %@ no saved gamma", dName);
          return NO;
        }
    }

  return YES;
}

- (BOOL)applyDisplayLayout:(NSArray *)layout
{
  NSSize       newPixSize;
  NSSize       mmSize;
  NXDisplay    *mainDisplay;
  NXDisplay    *lastActiveDisplay;
  NXDisplay    *display;
  NSString     *displayName;
  NSDictionary *gamma;
  NSRect       frame;
  NSNumber     *frameRate;
  NSDictionary *resolution;
  NSPoint      origin;

  // Validate 'layout'
  if ([self validateLayout:layout] == NO)
    {
      NSDebugLLog(@"Screen",
                  @"NXScreen: Proposed layout is invalid. Do nothing.");
      return NO;
    }

  // Calculate sizes of screen
  newPixSize = [self _sizeInPixelsForLayout:layout];
  mmSize = [self _sizeInMilimetersForLayout:layout];
  NSDebugLLog(@"Screen", @"NXScreen: New screen size: %@, old %@",
              NSStringFromSize(newPixSize), NSStringFromSize(sizeInPixels));

  [updateScreenLock lock];
  
  // If new screen size is BIGGER - set new screen size here
  if (newPixSize.width > sizeInPixels.width ||
      newPixSize.height > sizeInPixels.height)
    {
      // NSLog(@"NXScreen: set new BIGGER screen size: START");
      XRRSetScreenSize(xDisplay, xRootWindow,
                       (int)newPixSize.width, (int)newPixSize.height,
                       (int)mmSize.width, (int)mmSize.height);
      // NSLog(@"NXScreen: set new BIGGER screen size: END");
    }
  
  // Set resolution and gamma to displays
  mainDisplay = nil;
  for (NSDictionary *displayLayout in layout)
    {
      displayName = [displayLayout objectForKey:NXDisplayNameKey];
      display = [self displayWithName:displayName];

      // Set resolution to displays marked as active in layout
      if ([[displayLayout objectForKey:NXDisplayIsActiveKey]
            isEqualToString:@"YES"])
        {
          if ([display isBuiltin] && [NXPower isLidClosed])
            {
              // set 'frame' to preserve it in 'hiddenFrame' on deactivate
              frame = NSRectFromString([displayLayout
                                         objectForKey:NXDisplayFrameKey]);
              display.frame = frame;
              // save 'frame' in 'hiddenFrame'
              [display setActive:NO];
              // deactivate
              [display setResolution:[NXDisplay zeroResolution]
                            position:display.hiddenFrame.origin];
              continue;
            }

          if ([[displayLayout objectForKey:NXDisplayIsMainKey]
                isEqualToString:@"YES"])
            mainDisplay = display;

          frame = NSRectFromString([displayLayout
                                     objectForKey:NXDisplayFrameKey]);
          frameRate = [displayLayout objectForKey:NXDisplayFrameRateKey];
          resolution = [display resolutionWithWidth:frame.size.width
                                             height:frame.size.height
                                               rate:[frameRate floatValue]];
          [display setResolution:resolution position:frame.origin];
          XFlush(xDisplay);

          lastActiveDisplay = display;
        }
      else // Setting zero resolution to display disables it.
        {
          [display setResolution:[NXDisplay zeroResolution]
                        position:[display hiddenFrame].origin];
        }
      gamma = [displayLayout objectForKey:NXDisplayGammaKey];
      [display setGammaFromDescription:gamma];
    }

  // If new screen size is SMALLER - set new screen size here
  if (newPixSize.width < sizeInPixels.width ||
      newPixSize.height < sizeInPixels.height)
    {
      // NSLog(@"NXScreen: set new SMALLER screen size: START");
      XRRSetScreenSize(xDisplay, xRootWindow,
                       (int)newPixSize.width, (int)newPixSize.height,
                       (int)mmSize.width, (int)mmSize.height);
      // NSLog(@"NXScreen: set new SMALLER screen size: END");
    }
  
  sizeInPixels = newPixSize;
  
  // No active main displays left. Set main to last processed with loop above.
  if (mainDisplay)
    {
      if ([mainDisplay isMain] == NO)
        {
          [mainDisplay setMain:YES];
        }
    }
  else
    {
      [lastActiveDisplay setMain:YES];
    }

  if (useAutosave == YES)
    {
      [self saveCurrentDisplayLayout];
    }

  [updateScreenLock unlock];
  
  return YES;
}

// --- Saving and reading
- (BOOL)saveCurrentDisplayLayout
{
  NSString *configFile = [self _displayConfigFileName];
  NSString *configDir = [configFile stringByDeletingLastPathComponent];

  // Construct path to config file
  if (![[NSFileManager defaultManager] fileExistsAtPath:configDir])
    {
      [[NSFileManager defaultManager] createDirectoryAtPath:configDir
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:NULL];
    }
  
  return [[self currentLayout] writeToFile:configFile atomically:YES];
}

- (NSArray *)savedDisplayLayout
{
  NSArray  *layout = nil;
  NSString *configPath = [self _displayConfigFileName];

  if ([[NSFileManager defaultManager] fileExistsAtPath:configPath])
    {
      layout = [NSArray arrayWithContentsOfFile:configPath];
    }

  return layout;
}

- (BOOL)applySavedDisplayLayout
{
  NSArray *layout = [self savedDisplayLayout];

  if (layout)
    {
      NSLog(@"NXScreen: Apply display layout saved in %@",
            [self _displayConfigFileName]);
      return [self applyDisplayLayout:layout];
    }
  
  NSLog(@"NXScreen: Apply automatic default display layout");
  return [self applyDisplayLayout:[self defaultLayout:YES]];
}

- (NSDictionary *)descriptionOfDisplay:(NXDisplay *)display
                              inLayout:(NSArray *)layout
{
  for (NSDictionary *dDesc in layout)
    {
      if ([[dDesc objectForKey:@"Name"] isEqualToString:display.outputName] &&
          [[dDesc objectForKey:@"ID"] isEqual:[display uniqueID]])
        {
          return dDesc;
        }
    }

  return nil;
}

- (id)objectForKey:(NSString *)key
        forDisplay:(NXDisplay *)display
          inLayout:(NSArray *)layout
{
  return [[self descriptionOfDisplay:display inLayout:layout] objectForKey:key];
}

// --- Arrangement
NSComparisonResult compareLayoutEntries(NSDictionary *displayA,
                                        NSDictionary *displayB,
                                        void *context)
{
  NSPoint aPoint, bPoint;
  BOOL    aIsActive, bIsActive;

  aPoint = NSRectFromString([displayA objectForKey:NXDisplayFrameKey]).origin;
  bPoint = NSRectFromString([displayB objectForKey:NXDisplayFrameKey]).origin;
  
  aIsActive = [[displayB objectForKey:NXDisplayIsActiveKey]
                isEqualToString:@"YES"];
  bIsActive = [[displayB objectForKey:NXDisplayIsActiveKey]
                isEqualToString:@"YES"];
  
  if (aPoint.x < bPoint.x && aIsActive)
    return  NSOrderedAscending;
  else if (aPoint.x > bPoint.x && bIsActive)
    return NSOrderedDescending;
  else
    return NSOrderedSame;
}

// This is new verion of -arrangeDisplays.
// Changes only position of displays.
// Return layout description with adjusted disoplays position without changing
// actual properties of displays.
// If you need to propagate changes to displays use -applyDisplayLayout: with
// returned layout description as an argument.
- (NSArray *)arrangedDisplayLayout
{
  NSMutableArray *layout;
  NSRect	 dFrame, dLastFrame;
  CGFloat	 midX, midY;

  layout = [[[self currentLayout]
                     sortedArrayUsingFunction:compareLayoutEntries
                                      context:NULL] mutableCopy];
  // At this point displays in layout are sorted at X axis.
  dLastFrame = NSMakeRect(0,0,0,0);
  for (NSMutableDictionary *d in layout)
    {
      if ([[d objectForKey:NXDisplayIsActiveKey] isEqualToString:@"NO"])
        continue;
        
      dFrame = NSRectFromString([d objectForKey:NXDisplayFrameKey]);
      dFrame.origin.x = NSMaxX(dLastFrame);
      
      [d setObject:NSStringFromRect(dFrame) forKey:NXDisplayFrameKey];
      
      NSDebugLLog(@"Screen", @"NXScreen: %@ new frame: %@",
                  [d objectForKey:NXDisplayNameKey],
                  NSStringFromRect(dFrame));
      
      dLastFrame = dFrame;
    }

  return [layout autorelease];
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
