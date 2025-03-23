/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
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

/*
screen:
typedef struct _XRRScreenResources {
  Time        timestamp;
  Time        configTimestamp;
  int         ncrtc;
  RRCrtc      *crtcs;
  int         noutput;
  RROutput    *outputs;
  int         nmode;
  XRRModeInfo *modes;
} XRRScreenResources;
*/

#include <X11/Xlib.h>
#include <X11/X.h>
#include <X11/Xatom.h>

#import <AppKit/NSGraphics.h>

#import "OSEDefaults.h"
#import "OSEDisplay.h"
#import "OSEScreen.h"
#import "OSEMouse.h"

// NXGlobalDomain key
NSString *OSEDesktopBackgroundColor = @"DesktopBackgroundColor";

// Displays.config field keys
NSString *OSEDisplayIsActiveKey = @"Active";
NSString *OSEDisplayIsMainKey = @"Main";
NSString *OSEDisplayGammaKey = @"Gamma";
NSString *OSEDisplayGammaRedKey = @"Red";
NSString *OSEDisplayGammaGreenKey = @"Green";
NSString *OSEDisplayGammaBlueKey = @"Blue";
NSString *OSEDisplayGammaBrightnessKey = @"Brightness";
NSString *OSEDisplayIDKey = @"ID";
NSString *OSEDisplayNameKey = @"Name";
NSString *OSEDisplayFrameKey = @"Frame";
NSString *OSEDisplayHiddenFrameKey = @"FrameHidden";
NSString *OSEDisplayFrameRateKey = @"FrameRate";
NSString *OSEDisplayResolutionNameKey = @"ResolutionName";
NSString *OSEDisplayResolutionSizeKey = @"ResolutionSize";
NSString *OSEDisplayResolutionRateKey = @"ResolutionRate";
NSString *OSEDisplayPhSizeKey = @"PhysicalSize";
NSString *OSEDisplayPropertiesKey = @"Properties";

// Notifications
NSString *OSEScreenDidChangeNotification = @"OSEScreenDidChangeNotification";
NSString *OSEScreenDidUpdateNotification = @"OSEScreenDidUpdateNotification";

static OSEScreen *systemScreen = nil;

@interface OSEScreen (Private)
- (NSSize)_sizeInPixels;
- (NSSize)_sizeInPixelsForLayout:(NSArray *)layout;
- (NSSize)_sizeInMilimeters;
- (NSSize)_sizeInMilimetersForLayout:(NSArray *)layout;
- (NSString *)_displayConfigFileName;
- (void)_restoreDisplaysAttributesFromLayout:(NSArray *)layout;
@end

@implementation OSEScreen (Private)
// Calculate screen size in pixels using current displays information
- (NSSize)_sizeInPixels
{
  CGFloat width = 0.0, height = 0.0, w = 0.0, h = 0.0;
  NSRect  dFrame;
  
  for (OSEDisplay *display in systemDisplays) {
    if ([display isConnected] && [display isActive]) {
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
  
  for (NSDictionary *display in layout) {
    if ([[display objectForKey:OSEDisplayIsActiveKey] isEqualToString:@"NO"]) {
      continue;
    }
      
    frame = NSRectFromString([display objectForKey:OSEDisplayFrameKey]);
          
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
  
  for (OSEDisplay *display in systemDisplays) {
    if ([display isConnected] && [display isActive]) {
      dPSize = [display physicalSize];
          
      if (dPSize.width > width) {
        width = dPSize.width;
      }
      else if (dPSize.width == 0) {
        width = 200; // perhaps it's VM, this number will be ignored
      }
          
      if (dPSize.height > height) {
        height = dPSize.height;
      }
      else if (dPSize.height == 0) {
        height = 200; // perhaps it's VM, this number will be ignored
      }
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
  
  for (NSDictionary *display in layout) {
    if ([[display objectForKey:OSEDisplayIsActiveKey] isEqualToString:@"NO"]) {
      continue;
    }
      
    dPSize = NSSizeFromString([display objectForKey:OSEDisplayPhSizeKey]);
          
    if (dPSize.width > width) {
      width = dPSize.width;
    }
    else if (dPSize.width == 0) {
      width = 200; // perhaps it's VM, this number will be ignored
    }
          
    if (dPSize.height > height) {
      height = dPSize.height;
    }
    else if (dPSize.height == 0) {
      height = 200; // perhaps it's VM, this number will be ignored
    }
  }
  
  return NSMakeSize(width, height);
}

- (NSString *)_displayConfigFileName
{
  NSUInteger layoutHash = 0;
  NSString   *configDir;

  // Construct path to config file
  configDir = [LAYOUTS_DIR stringByExpandingTildeInPath];
  
  for (OSEDisplay *d in [self connectedDisplays]) {
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
  
  if (layout == nil) {
    return;
  }
  
  for (OSEDisplay *d in systemDisplays) {
    // FrameHidden
    attribute = [self objectForKey:OSEDisplayHiddenFrameKey
                        forDisplay:d
                          inLayout:layout];
    if (attribute != nil && [attribute isKindOfClass:[NSString class]]) {
      hiddenFrame = NSRectFromString(attribute);
      NSDebugLLog(@"Screen", @"[OSEScreen] %@ restore hiddenFrame: %@",
                  d.outputName, attribute);
      if ([d isActive] == NO && NSIsEmptyRect(hiddenFrame) == NO) {
        d.hiddenFrame = hiddenFrame;
      }
    }

    // Gamma
    attribute = [self objectForKey:OSEDisplayGammaKey
                        forDisplay:d
                          inLayout:layout];
    if (attribute != nil &&
        [attribute isKindOfClass:[NSDictionary class]]) {
      // Only 'gammaValue' ivar will be set if display is inactive
      [d setGammaFromDescription:attribute];
    }
  }
}

@end

@implementation OSEScreen

+ (id)sharedScreen
{
  if (systemScreen == nil) {
    systemScreen = [[[OSEScreen alloc] init] autorelease];
  }

  return systemScreen;
}

// - (oneway void)release
// {
//   NSDebugLLog(@"dealloc", @"OSEScreen: reatin count: %lu", [self retainCount]);
//   [super release];
// }

- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEScreen: -dealloc (retain count: %lu)", [self retainCount]);

  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];

  if (background_pixmap != None && backgroundPixmapOwner == self) {
    // From XChangeProperty(3): "The lifetime of a property is not tied to the storing client.
    // Properties remain until explicitly deleted, until the window is destroyed, or until the
    // server resets.". So we don't need to free `background_pixmap` property.
    //   XFree(&background_pixmap);
    background_pixmap = None;
    backgroundPixmapOwner = nil;
  }
  if (background_gc != None) {
    XFreeGC(xDisplay, background_gc);
    background_gc = None;
  }
  XRRFreeScreenResources(screen_resources);

  XCloseDisplay(xDisplay);

  [systemDisplays release];
  [updateScreenLock release];

  [_systemPower stopEventsMonitor];
  [_systemPower release];

  systemScreen = nil;

  [super dealloc];
}

- (id)init
{
  int event_base, error_base;
  int major_version, minor_version;

  if (systemScreen != nil) {
    return systemScreen;
  }

  xDisplay = XOpenDisplay(getenv("DISPLAY"));
  if (!xDisplay) {
    NSLog(@"Can't open Xorg display. Please setup DISPLAY environment variable.");
    return nil;
  }

  if (XRRQueryExtension(xDisplay, &event_base, &error_base) == True) {
    XRRQueryVersion(xDisplay, &major_version, &minor_version);
    NSDebugLLog(@"Screen", @"XRandR %i.%i, event base:%i, error base:%i",
                major_version, minor_version,
                event_base, error_base);
  }
  else {
    NSLog(@"[OSEScreen] no XRandR extension available. Return nil.");
    return nil;
  }

  self = [super init];

  xRootWindow = RootWindow(xDisplay, DefaultScreen(xDisplay));
  screen_resources = NULL;

  updateScreenLock = [[NSLock alloc] init];
  [self randrUpdateScreenResources];

  // Initially we set primary display to first active
  if ([self mainDisplay] == nil) {
    NSDebugLLog(@"Screen",
                @"OSEScreen: main display not found,"
                @" setting first active as main.");
    for (OSEDisplay *display in systemDisplays) {
      if ([display isActive]) {
        [display setMain:YES];
        break;
      }
    }
  }

  useAutosave = NO;
  background_pixmap = None;
  background_gc = None;

  _systemPower = [[OSEPower sharedPower] retain];

  // Workspace Manager notification sent as a reaction to XRRScreenChangeNotify
  // Notification sent to active OSEScreen applications of current user.
  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                      selector:@selector(randrScreenDidChange:)
                                                          name:OSEScreenDidChangeNotification
                                                        object:nil];

  return self;
}

- (void)setUseAutosave:(BOOL)yn
{
  useAutosave = yn;
}

- (BOOL)isLidClosed
{
  return [_systemPower isLidClosed];
}

//
//------------------------------------------------------------------------------
// Screen resources attributes
//------------------------------------------------------------------------------
//

// External notification - OSEScreenDidChangeNotification.
// XRRScreenResources update will generate OSEScreenDidUpdateNotification.
- (void)randrScreenDidChange:(NSNotification *)aNotif
{
  NSDebugLLog(@"Screen", @"OSEScreen: OSEScreenDidChangeNotification received.");
  [self randrUpdateScreenResources];
}

- (XRRScreenResources *)randrScreenResources
{
  if (screen_resources == NULL) {
    [self randrUpdateScreenResources];
  }
  return screen_resources;
}

- (void)randrUpdateScreenResources
{
  OSEDisplay *display;
  
  if ([updateScreenLock tryLock] == NO) {
    NSDebugLLog(@"Screen", @"OSEScreen: update of XRandR screen"
                           @" resources was unsuccessful!");
    return;
  }
    
  NSDebugLLog(@"Screen", @"OSEScreen: randrUpdateScreenResources: START");
  
  // Reread screen resources
  if (screen_resources) {
    XRRFreeScreenResources(screen_resources);
  }
  screen_resources = XRRGetScreenResources(xDisplay, xRootWindow);

  // Create/clean display information local cache.
  if (systemDisplays) {
    [systemDisplays removeAllObjects];
  }
  else {
    systemDisplays = [[NSMutableArray alloc] init];
  }

  // Update displays info
  for (int i=0; i < screen_resources->noutput; i++) {
    display = [[OSEDisplay alloc] initWithOutputInfo:screen_resources->outputs[i]
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
  
  NSDebugLLog(@"Screen", @"OSEScreen: randrUpdateScreenResources: END");

  [[NSNotificationCenter defaultCenter] postNotificationName:OSEScreenDidUpdateNotification
                                                      object:self];
}

- (RRCrtc)randrFindFreeCRTC
{
  RRCrtc      crtc;
  XRRCrtcInfo *info;

  for (int i=0; i<screen_resources->ncrtc; i++) {
    crtc = screen_resources->crtcs[i];
    info = XRRGetCrtcInfo(xDisplay, screen_resources, crtc);
    // fprintf(stderr, "CRTC '%lu' has %i outputs.\n", crtc, info->noutput);
    
    if (info->noutput == 0) {
      break;
    }
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
  
  dBack = [[OSEDefaults globalUserDefaults]
                               objectForKey:OSEDesktopBackgroundColor];
  if (dBack) {
    *redComponent = [dBack[@"Red"] floatValue];
    *greenComponent = [dBack[@"Green"] floatValue];
    *blueComponent = [dBack[@"Blue"] floatValue];
    success = YES;
  }
  else {
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
  if (XGetWindowAttributes(xDisplay, xRootWindow, &attrs) != 0) {
    image = XGetImage(xDisplay, xRootWindow, 0, 0,
                      attrs.width, attrs.height, AllPlanes, ZPixmap);
    if (image != NULL) {
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

  if (success == NO) {
    success = [self savedBackgroundColorRed:redComponent
                                      green:greenComponent
                                       blue:blueComponent];
  }
      
  return success;
}

- (void)_setBackgroundXColor:(XColor)xColor
                  forXScreen:(Screen *)xScreen
{
  Atom rootpmap_id = XInternAtom(xDisplay, "_XROOTPMAP_ID", False);

  if (background_pixmap == None) {
    // Try to get existing _XROOTPMAP_ID property
    Atom type;
    int format;
    unsigned long length, after;
    unsigned char *data = 0;
    int result = XGetWindowProperty(xDisplay, xRootWindow, rootpmap_id, 0, 1, True, AnyPropertyType,
                                    &type, &format, &length, &after, &data);

    if (result == Success && data && type == XA_PIXMAP && format == 32 && length == 1) {
      // Do not clear out - owner may still exist (Login.app)
      // XKillClient(xDisplay, *((Pixmap *)data));
      // XFree(data);
      background_pixmap = *((Pixmap *)data);
    } else {
      background_pixmap = XCreatePixmap(xDisplay, xRootWindow, 1, 1, DefaultDepth(xDisplay, 0));
      backgroundPixmapOwner = self;
    }
    background_gc_values.foreground = xColor.pixel;
    background_gc = XCreateGC(xDisplay, xRootWindow, GCForeground, &background_gc_values);
  }

  // Set new _XROOTPMAP_ID property
  if (background_pixmap != None) {
    background_gc_values.foreground = xColor.pixel;
    XChangeGC(xDisplay, background_gc, GCForeground, &background_gc_values);

    XFillRectangle(xDisplay, background_pixmap, background_gc, 0, 0, 1, 1);
    XChangeProperty(xDisplay, xRootWindow, rootpmap_id, XA_PIXMAP, 32, PropModeReplace,
                    (unsigned char *)&background_pixmap, 1);
  }
}

- (BOOL)setBackgroundColorRed:(CGFloat)redComponent
                        green:(CGFloat)greenComponent
                         blue:(CGFloat)blueComponent
{
  unsigned red, green, blue;
  NSString *rgbSpec;
  char     *x_color_spec;
  Screen   *xScreen = DefaultScreenOfDisplay(xDisplay);
  XColor   xColor;

  // rgbColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
  
  red     = (unsigned)(255/(1/redComponent));
  green   = (unsigned)(255/(1/greenComponent));
  blue    = (unsigned)(255/(1/blueComponent));
  rgbSpec = [NSString stringWithFormat:@"rgb:%.2x/%.2x/%.2x", red, green, blue];
  
  x_color_spec = (char *)[rgbSpec cString];
  
  if (!XParseColor(xDisplay, xScreen->cmap, x_color_spec, &xColor)) {
    fprintf(stderr,"OSEScreen: unknown color \"%s\"\n", x_color_spec);
    return NO;
  }
  if (!XAllocColor(xDisplay, xScreen->cmap, &xColor)) {
    fprintf(stderr, "OSEScreen: unable to allocate color for \"%s\"\n",
            x_color_spec);
    return NO;
  }

  // Set background for non-compositor sessions
  XSetWindowBackground(xDisplay, xRootWindow, xColor.pixel);
  XClearWindow(xDisplay, xRootWindow);
  // Set background for sessions with compositor
  [self _setBackgroundXColor:xColor forXScreen:xScreen];
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

// Returns array of OSEDisplay
- (NSArray *)allDisplays
{
  return systemDisplays;
}

- (NSArray *)activeDisplays
{
  NSMutableArray *activeDisplays = [[NSMutableArray alloc] init];
  
  for (OSEDisplay *display in systemDisplays) {
    if ([display isActive]) {
      NSLog(@"Adding active display: %@", [display outputName]);
      [activeDisplays addObject:display];
    }
  }
  return [activeDisplays autorelease];
}

- (NSArray *)connectedDisplays
{
  NSMutableArray *connectedDisplays = [[NSMutableArray alloc] init];

  for (OSEDisplay *display in systemDisplays) {
      if ([display isConnected]) {
        [connectedDisplays addObject:display];
      }
  }
  return [connectedDisplays autorelease];
}

//---

- (OSEDisplay *)mainDisplay
{
  OSEDisplay *display = nil;
  
  for (OSEDisplay *d in systemDisplays) {
    if ([d isActive] && [d isMain]) {
      display = d;
      break;
    }
  }
  
  return display;
}

- (void)setMainDisplay:(OSEDisplay *)display
{
  if (display == nil) {
    XRRSetOutputPrimary(xDisplay, xRootWindow, None);
    [self randrUpdateScreenResources];
    return;
  }
  
  for (OSEDisplay *d in systemDisplays) {
    [d setMain:(d == display) ? YES : NO];
  }
  [self randrUpdateScreenResources];
  if (useAutosave) {
    [self saveCurrentDisplayLayout];
  }
}

- (OSEDisplay *)displayAtPoint:(NSPoint)point
{
  for (OSEDisplay *display in systemDisplays) {
    if (NSPointInRect(point, [display frame]) == YES) {
      return display;
    }
  }
  
  return nil;
}

- (OSEDisplay *)displayWithMouseCursor
{
  OSEMouse   *mouse;
  OSEDisplay *display;

  mouse = [OSEMouse new];
  display = [self displayAtPoint:[mouse locationOnScreen]];
  [mouse release];

  return display;
}

- (OSEDisplay *)displayWithName:(NSString *)name
{
  for (OSEDisplay *display in systemDisplays) {
    if ([[display outputName] isEqualToString:name]) {
      return display;
    }
  }
  return nil;
}

- (OSEDisplay *)displayWithID:(id)uniqueID
{
  NSData *uid;
  for (OSEDisplay *display in systemDisplays) {
    uid = [display uniqueID];
    if (uid && ([uid hash] == [uniqueID hash])) {
      return display;
    }
  }

  return nil;
}

- (NSPoint)positionForDisplay:(OSEDisplay *)display
                  isActivated:(BOOL)activated
{
  NSPoint position;

  if (activated == NO) {
    return display.hiddenFrame.origin;
  }
  
  position = NSMakePoint(0, 0);
  for (OSEDisplay *d in [self connectedDisplays]) {
    if (d != display) {
      position.x += d.frame.size.width;
    }
  }
  
  return position;
}

- (void)activateDisplay:(OSEDisplay *)display
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

- (void)deactivateDisplay:(OSEDisplay *)display
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

- (void)setDisplay:(OSEDisplay *)display
        resolution:(NSDictionary *)resolution
{
  NSRect  frame = display.frame;
  NSArray *newLayout;

  frame.size = NSSizeFromString([resolution objectForKey:OSEDisplayResolutionSizeKey]);
  display.frame = frame;
  
  [self applyDisplayLayout:[self arrangedDisplayLayout]];
}

- (void)setDisplay:(OSEDisplay *)display
          position:(NSPoint)position
{
  NSRect  frame = [display frame];

  if (NSEqualPoints(position, frame.origin) == NO) {
    frame.origin = position;
    [display setFrame:frame];
    
    [self applyDisplayLayout:[self arrangedDisplayLayout]];
  }
}
//------------------------------------------------------------------------------
// Layouts
//------------------------------------------------------------------------------
// Described by set of OSEDisplay's with:
// - resolution and refresh rate (mode);
// - origin (position) - place displays aligned with each other;
// - rotation
// For example:
// 1. Latop with builtin monitor(1920x1080) has 1 OSEDisplay with resolution set
//    to 1920x1080 and origin set to (0,0).
//    Screen size is: 1920x1080.
// 2. Laptop with connected external monitor (1280x1024) has 2 OSEDisplays:
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
  
  for (OSEDisplay *display in [self connectedDisplays]) {
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
          forKey:OSEDisplayIDKey];
    [d setObject:[display outputName]
          forKey:OSEDisplayNameKey];
      
    [d setObject:NSStringFromSize([display physicalSize])
          forKey:OSEDisplayPhSizeKey];
      
    // Preferred resolution always at first position.
    resolution = [display bestResolution];
    frame = NSZeroRect;
    frame.size = NSSizeFromString([resolution objectForKey:OSEDisplayResolutionSizeKey]);
    frame.origin = origin;
      
    [d setObject:NSStringFromRect(frame)
          forKey:OSEDisplayFrameKey];
    [d setObject:NSStringFromRect(NSZeroRect)
          forKey:OSEDisplayHiddenFrameKey];
    [d setObject:[resolution objectForKey:OSEDisplayResolutionRateKey]
          forKey:OSEDisplayFrameRateKey];

    if ([display isBuiltin] && [_systemPower isLidClosed]) {
      [d setObject:@"NO" forKey:OSEDisplayIsActiveKey];
      [d setObject:@"NO" forKey:OSEDisplayIsMainKey];
    }
    else {
      [d setObject:@"YES" forKey:OSEDisplayIsActiveKey];
      [d setObject:([display isMain]) ? @"YES" : @"NO"
            forKey:OSEDisplayIsMainKey];
    }
      
    gamma = [NSMutableDictionary new];
    [gamma setObject:[NSNumber numberWithFloat:0.8]
              forKey:OSEDisplayGammaRedKey];
    [gamma setObject:[NSNumber numberWithFloat:0.8]
              forKey:OSEDisplayGammaGreenKey];
    [gamma setObject:[NSNumber numberWithFloat:0.8]
              forKey:OSEDisplayGammaBlueKey];
    [gamma setObject:[NSNumber numberWithFloat:1.0]
              forKey:OSEDisplayGammaBrightnessKey];
    [d setObject:gamma forKey:OSEDisplayGammaKey];
      
    if ((properties = [display properties])) {
      [d setObject:properties forKey:OSEDisplayPropertiesKey];
    }
      
    [layout addObject:d];
    [d release];

    if (arrange && (![display isBuiltin] || ![_systemPower isLidClosed])) {
      origin.x +=
        NSSizeFromString([resolution objectForKey:OSEDisplayResolutionSizeKey]).width;
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

  for (OSEDisplay *display in [self connectedDisplays]) {
    d = [[[NSMutableDictionary alloc] init] autorelease];
    @try {
      [d setObject:([display uniqueID] == nil) ? @" " : [display uniqueID]
            forKey:OSEDisplayIDKey];
      [d setObject:[display outputName]
            forKey:OSEDisplayNameKey];
      
      [d setObject:NSStringFromSize([display physicalSize])
            forKey:OSEDisplayPhSizeKey];

      [d setObject:NSStringFromRect([display frame])
            forKey:OSEDisplayFrameKey];
      [d setObject:NSStringFromRect([display hiddenFrame])
            forKey:OSEDisplayHiddenFrameKey];
      [d setObject:[display.activeResolution objectForKey:OSEDisplayResolutionRateKey]
            forKey:OSEDisplayFrameRateKey];

      [d setObject:([display isActive]) ? @"YES" : @"NO"
            forKey:OSEDisplayIsActiveKey];
      [d setObject:([display isMain]) ? @"YES" : @"NO"
            forKey:OSEDisplayIsMainKey];

      gamma = [display gammaDescription];
      [d setObject:gamma forKey:OSEDisplayGammaKey];
      if ((properties = [display properties])) {
        [d setObject:properties forKey:OSEDisplayPropertiesKey];
      }
    }
    @catch (NSException *exception) {
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
  
  for (NSDictionary *d in layout) {
    dName = [d objectForKey:OSEDisplayNameKey];

    // ID
    if (![self displayWithID:[d objectForKey:OSEDisplayIDKey]]) {
      // Some display is not connected - use default layout
      NSDebugLLog(@"Screen", @"OSEScreen: monitor %@ is not connected.", dName);
      return NO;
    }

    // Resolution & origin
    dFrame = NSRectFromString([d objectForKey:OSEDisplayFrameKey]);
    if ([[d objectForKey:OSEDisplayIsActiveKey] isEqualToString:@"YES"] &&
        (dFrame.size.width <= 0 || dFrame.size.height <= 0)) {
      // Display resolution or origin not found
      NSDebugLLog(@"Screen",
                  @"OSEScreen: monitor %@ has no saved resolution or origin.",
                  dName);
      return NO;
    }

    // Is resolution supported by monitor?
    // resolution = [d objectForKey:OSEDisplayResolutionKey];
    // if (![[self displayWithName:dName] isSupportedResolution:resolution])
    //   {
    //     NSLog(@"OSEScreen: monitor %@ doesn't support resolution %@.",
    //           dName, [resolution objectForKey:OSEDisplaySizeKey]);
    //     return NO;
    //   }
      
    if (!(gamma = [d objectForKey:OSEDisplayGammaKey]) ||
        ![gamma objectForKey:OSEDisplayGammaRedKey] ||
        ![gamma objectForKey:OSEDisplayGammaGreenKey] ||
        ![gamma objectForKey:OSEDisplayGammaBlueKey] ||
        ![gamma objectForKey:OSEDisplayGammaBrightnessKey]) {
      // Something wrong with saved gamma
      NSDebugLLog(@"Screen", @"OSEScreen: display %@ no saved gamma", dName);
      return NO;
    }
  }

  return YES;
}

- (BOOL)applyDisplayLayout:(NSArray *)layout
{
  NSSize       newPixSize;
  NSSize       mmSize;
  OSEDisplay   *mainDisplay = nil;
  OSEDisplay   *lastActiveDisplay = nil;
  OSEDisplay   *display = nil;
  NSString     *displayName = nil;
  NSDictionary *gamma = nil;
  NSRect       frame;
  NSNumber     *frameRate = nil;
  NSDictionary *resolution = nil;
  NSPoint      origin;

  // Validate 'layout'
  if ([self validateLayout:layout] == NO) {
    NSDebugLLog(@"Screen",
                @"OSEScreen: Proposed layout is invalid. Do nothing.");
    return NO;
  }

  // Calculate sizes of screen
  newPixSize = [self _sizeInPixelsForLayout:layout];
  mmSize = [self _sizeInMilimetersForLayout:layout];
  NSDebugLLog(@"Screen", @"OSEScreen: New screen size: %@, old %@",
              NSStringFromSize(newPixSize), NSStringFromSize(sizeInPixels));

  [updateScreenLock lock];
  
  /* If new screen size is BIGGER - set new screen size here
     Example: current size is 1440x900, new size 1280x960. Height is bigger
     but width is smaller. In VirtualBox this leads to - X Error: 
     BadMatch (invalid parameter attributes). */
  if (newPixSize.width > sizeInPixels.width &&
      newPixSize.height > sizeInPixels.height) {
    NSDebugLLog(@"Screen", @"OSEScreen: set new BIGGER screen size: START");
    XRRSetScreenSize(xDisplay, xRootWindow,
                     (int)newPixSize.width, (int)newPixSize.height,
                     (int)mmSize.width, (int)mmSize.height);
    NSDebugLLog(@"Screen", @"OSEScreen: set new BIGGER screen size: END");
  }
  
  // Set resolution and gamma to displays
  mainDisplay = nil;
  for (NSDictionary *displayLayout in layout) {
    displayName = [displayLayout objectForKey:OSEDisplayNameKey];
    display = [self displayWithName:displayName];

    // Set resolution to displays marked as active in layout
    if ([[displayLayout objectForKey:OSEDisplayIsActiveKey] isEqualToString:@"YES"]) {
      if ([display isBuiltin] && [_systemPower isLidClosed]) {
        // set 'frame' to preserve it in 'hiddenFrame' on deactivate
        frame = NSRectFromString([displayLayout objectForKey:OSEDisplayFrameKey]);
        display.frame = frame;
        // save 'frame' in 'hiddenFrame'
        [display setActive:NO];
        // deactivate
        [display setResolution:[OSEDisplay zeroResolution] position:display.hiddenFrame.origin];
        continue;
      }

      if ([[displayLayout objectForKey:OSEDisplayIsMainKey] isEqualToString:@"YES"]) {
        mainDisplay = display;
      }

      frame = NSRectFromString([displayLayout objectForKey:OSEDisplayFrameKey]);
      frameRate = [displayLayout objectForKey:OSEDisplayFrameRateKey];
      resolution = [display resolutionWithWidth:frame.size.width
                                         height:frame.size.height
                                           rate:[frameRate floatValue]];
      [display setResolution:resolution position:frame.origin];
      XFlush(xDisplay);

      lastActiveDisplay = display;
    } else {  // Setting zero resolution to display disables it.
      [display setResolution:[OSEDisplay zeroResolution] position:[display hiddenFrame].origin];
    }
    gamma = [displayLayout objectForKey:OSEDisplayGammaKey];
    [display setGammaFromDescription:gamma];
  }

  // If new screen size is SMALLER - set new screen size here
  if (newPixSize.width < sizeInPixels.width ||
      newPixSize.height < sizeInPixels.height) {
    NSDebugLLog(@"Screen", @"OSEScreen: set new SMALLER screen size: START");
    XRRSetScreenSize(xDisplay, xRootWindow,
                     (int)newPixSize.width, (int)newPixSize.height,
                     (int)mmSize.width, (int)mmSize.height);
    NSDebugLLog(@"Screen", @"OSEScreen: set new SMALLER screen size: END");
  }
  
  sizeInPixels = newPixSize;
  
  // No active main displays left. Set main to last processed with loop above.
  if (mainDisplay) {
    if ([mainDisplay isMain] == NO) {
      [mainDisplay setMain:YES];
    }
  }
  else {
    [lastActiveDisplay setMain:YES];
  }

  if (useAutosave == YES) {
    [self saveCurrentDisplayLayout];
  }

  [updateScreenLock unlock];

  // Send notification to other user's OSEScreen applications.
  // We're don't listen to this notification beacuse it leads to user user's application crash.
  NSLog(@"Screen: sending OSEScreenDidChangeNotification to GSPublicNotificationCenterType...");
  [[NSDistributedNotificationCenter notificationCenterForType:GSPublicNotificationCenterType]
      postNotificationName:OSEScreenDidChangeNotification
                    object:nil
                  userInfo:nil
        deliverImmediately:YES];
    
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

  if (layout) {
    NSDebugLLog(@"Screen", @"OSEScreen: Apply display layout saved in %@",
                [self _displayConfigFileName]);
    return [self applyDisplayLayout:layout];
  }

  NSDebugLLog(@"Screen", @"OSEScreen: Apply automatic default display layout");
  return [self applyDisplayLayout:[self defaultLayout:YES]];
}

- (NSDictionary *)descriptionOfDisplay:(OSEDisplay *)display
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
        forDisplay:(OSEDisplay *)display
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

  aPoint = NSRectFromString([displayA objectForKey:OSEDisplayFrameKey]).origin;
  bPoint = NSRectFromString([displayB objectForKey:OSEDisplayFrameKey]).origin;
  
  aIsActive = [[displayB objectForKey:OSEDisplayIsActiveKey]
                isEqualToString:@"YES"];
  bIsActive = [[displayB objectForKey:OSEDisplayIsActiveKey]
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
      if ([[d objectForKey:OSEDisplayIsActiveKey] isEqualToString:@"NO"])
        continue;
        
      dFrame = NSRectFromString([d objectForKey:OSEDisplayFrameKey]);
      dFrame.origin.x = NSMaxX(dLastFrame);
      
      [d setObject:NSStringFromRect(dFrame) forKey:OSEDisplayFrameKey];
      
      NSDebugLLog(@"Screen", @"OSEScreen: %@ new frame: %@",
                  [d objectForKey:OSEDisplayNameKey],
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
//     NSLog(@"OSEScreen: No video adapters found - no saved layout will be applied.");
//     XRRFreeProviderResources(provider_resources);
//     return;
//   }

@end
