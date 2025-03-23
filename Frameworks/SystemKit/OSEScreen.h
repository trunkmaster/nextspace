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
 * Provides integration with XRandR subsystem.
 * Manage display layouts.
 *
 * OSEScreen, OSEDisplay

 *
 * Definitions
 *
 Screen  - A set of displays (monitors) for a single user with one keyboard and
           mouse. In other words, screen is a set of hardware resources: one or
           more monitors, one keyboard and one mouse.
           Logical screen size may be bigger then sum of OSEDisplays resolutions.

           Xrandr's name - Screen.

 Display - Physical monitor and hardware that can be color, grayscale, or
           monochrome. Characterized by, resolution, refresh rate, gamma
           correction, brightness, contrast.
           Also has specific properties like: vendor and model name, serial
           number etc.

           Xrandr's name - Output.

 View    - Image visible for user on Display. It's part of Screen and can be
           visible on multiple Displays (in case of clonning). View is always
           part of Screen but can be invisible on some Display.

           Xrandr's name - CRTC.

 *
 * Description
 *
 OSEScreen subsystem is a set of functions and classes to get and set underlying 
 windowing system information, including:
 - Getting Display information: resolution, monitor mode, monitor type
   (CRT, TFT, LVDS), gamma, color depth, dpi value, monitor model.
 - Changing Display modes: resolution, refresh rate, full screen.
 - Configuring Display configuration: mirroring, dual screen.
 - Providing mechanism to do various display manipulation: fading, switching
   to console, power management.
 */
#include <X11/extensions/Xrandr.h>

#import <Foundation/Foundation.h>
#import <AppKit/NSColor.h>
#import <SystemKit/OSEPower.h>

@class OSEDisplay;

@interface OSEScreen : NSObject
{
 @private
  Display *xDisplay;
  Window xRootWindow;

  Pixmap background_pixmap;
  GC background_gc;
  XGCValues background_gc_values;
  id backgroundPixmapOwner;

  BOOL useAutosave;
  NSLock *updateScreenLock;
  XRRScreenResources *screen_resources;
  NSMutableArray *systemDisplays;
  NSSize sizeInPixels, sizeInMilimeters;
}

@property (readonly) OSEPower *systemPower;

+ (id)sharedScreen;
- (void)setUseAutosave:(BOOL)yn;

- (BOOL)isLidClosed;

- (XRRScreenResources *)randrScreenResources;
- (void)randrUpdateScreenResources;
- (RRCrtc)randrFindFreeCRTC;

- (NSSize)sizeInPixels;
- (NSSize)sizeInMilimeters;
- (NSUInteger)colorDepth;

/** Returns color saved in defaults with key NXDesktopBackgroundBolor */
- (BOOL)savedBackgroundColorRed:(CGFloat *)redComponent
                          green:(CGFloat *)greenComponent
                           blue:(CGFloat *)blueComponent;
/** Returns current color of root window. On failure returns saved color. */
- (BOOL)backgroundColorRed:(CGFloat *)redComponent
                     green:(CGFloat *)greenComponent
                      blue:(CGFloat *)blueComponent;
- (BOOL)setBackgroundColorRed:(CGFloat)redComponent
                        green:(CGFloat)greenComponent
                         blue:(CGFloat)blueComponent;
 
- (NSArray *)allDisplays;
- (NSArray *)activeDisplays;
- (NSArray *)connectedDisplays;

- (OSEDisplay *)mainDisplay;
- (void)setMainDisplay:(OSEDisplay *)display;

- (OSEDisplay *)displayAtPoint:(NSPoint)point;
- (OSEDisplay *)displayWithMouseCursor;
- (OSEDisplay *)displayWithName:(NSString *)name;
- (OSEDisplay *)displayWithID:(id)uniqueID;

- (void)activateDisplay:(OSEDisplay *)display;
- (void)deactivateDisplay:(OSEDisplay *)display;
- (void)setDisplay:(OSEDisplay *)display resolution:(NSDictionary *)resolution;

- (NSArray *)defaultLayout:(BOOL)arrange;
- (NSArray *)currentLayout;
- (BOOL)validateLayout:(NSArray *)layout;
- (BOOL)applyDisplayLayout:(NSArray *)layout;
- (BOOL)saveCurrentDisplayLayout;
- (NSArray *)savedDisplayLayout;
- (BOOL)applySavedDisplayLayout;
- (NSDictionary *)descriptionOfDisplay:(OSEDisplay *)display
                              inLayout:(NSArray *)layout;
- (id)objectForKey:(NSString *)key
        forDisplay:(OSEDisplay *)display
          inLayout:(NSArray *)layout;

- (NSArray *)arrangedDisplayLayout;

@end

// NXGlobalDefaults desktop background key
extern NSString *OSEDesktopBackgroundColor;

// Displays.config user path
#define DISPLAYS_CONFIG @"~/Library/Preferences/Displays.config"
#define LAYOUTS_DIR     @"~/Library/Preferences/.NextSpace"

// Displays.config field keys
extern NSString *OSEDisplayIsActiveKey;
extern NSString *OSEDisplayIsMainKey;
extern NSString *OSEDisplayGammaKey;
extern NSString *OSEDisplayGammaRedKey;
extern NSString *OSEDisplayGammaGreenKey;
extern NSString *OSEDisplayGammaBlueKey;
extern NSString *OSEDisplayGammaBrightnessKey;
extern NSString *OSEDisplayIDKey;
extern NSString *OSEDisplayNameKey;
extern NSString *OSEDisplayFrameKey;
extern NSString *OSEDisplayHiddenFrameKey;
extern NSString *OSEDisplayFrameRateKey;
extern NSString *OSEDisplayResolutionNameKey;
extern NSString *OSEDisplayResolutionSizeKey;
extern NSString *OSEDisplayResolutionRateKey;
extern NSString *OSEDisplayPhSizeKey;
extern NSString *OSEDisplayPropertiesKey;

// Notifications
extern NSString *OSEScreenDidChangeNotification;
extern NSString *OSEScreenDidUpdateNotification;
