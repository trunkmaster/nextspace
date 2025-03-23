/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Description: Represents output port in computer and connected physical monitor.
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

#import <Foundation/Foundation.h>

#import <X11/extensions/Xrandr.h>

@class OSEScreen;

struct _NXGammaValue {
  CGFloat red;
  CGFloat green;
  CGFloat blue;
};
typedef struct _NXGammaValue NXGammaValue;

// Physical device
@interface OSEDisplay : NSObject
{
  Display *xDisplay;
  OSEScreen *screen;
  XRRScreenResources *screen_resources;
  RROutput output_id;

  Connection connectionState;      // RandR connection state
  NSMutableArray *allResolutions;  // width, height, rate

  CGFloat dpiValue;  // calculated DPI

  NXGammaValue gammaValue;
  CGFloat gammaBrightness;

  NSMutableDictionary *properties;

  BOOL isMain;
  // BOOL			isActive;
}

@property (readonly) NSString *outputName;  // LVDS, VGA, DVI, HDMI
@property (readonly) NSSize physicalSize;   // in milimetres
@property (readonly) BOOL isBuiltin;        // determined by outputName

+ (NSDictionary *)zeroResolution;

- (id)initWithOutputInfo:(RROutput)output
         screenResources:(XRRScreenResources *)scr_res
                  screen:(OSEScreen *)scr
                xDisplay:(Display *)x_display;

- (CGFloat)dpi;  // calculated from frame and phys. size

//------------------------------------------------------------------------------
//--- Resolution, refresh rate
//------------------------------------------------------------------------------
//--- Getters for resolutions supported by display
- (NSArray *)allResolutions;  // Supported resolutions (W x H @ R)
- (NSDictionary *)bestResolution;
- (BOOL)isSupportedResolution:(NSDictionary *)resolution;
- (NSDictionary *)resolutionWithWidth:(CGFloat)width height:(CGFloat)height rate:(CGFloat)refresh;

//--- Active (visible to user) resolution of display
// These values may only be changed with -setResolution:position: method.
@property (readonly) NSDictionary *activeResolution;  // {Size=; Rate=}
@property (readonly) CGFloat activeRate;              // Refresh rate for resolution
@property (readonly) NSPoint activePosition;

//--- Setter
- (void)setResolution:(NSDictionary *)resolution position:(NSPoint)position;

//------------------------------------------------------------------------------
//--- Properties which aimed to process requests by OSEScreen
// frame - holds active resolution and position of display.
//         If 'frame.size' differs from resolultion's 'Size' it means resolution
//         change was requested.
//         If frame.size holds zeros - display deactivation requested.
//         'hiddenFrame.size' must hold non-zero values.
// hiddenFrame - if holds non-zero values - display deactivation was requested
//               or display already deactivated.
// When display is deactivated resolution and origin values are set to 0.
//------------------------------------------------------------------------------
@property NSRect frame;        // logical rect of monitor
@property NSRect hiddenFrame;  // logical rect for inactive monitor

//------------------------------------------------------------------------------
//--- Monitor state
//------------------------------------------------------------------------------
- (BOOL)isConnected;  // output has connected monitor
- (BOOL)isActive;     // is online and visible
- (void)setActive:(BOOL)active;
- (BOOL)isMain;
- (void)setMain:(BOOL)yn;

//------------------------------------------------------------------------------
//--- Gamma correction, brightness
//------------------------------------------------------------------------------
- (void)_getGamma;
- (BOOL)isGammaSupported;

// Gettters
- (NSDictionary *)gammaDescription;
- (void)setGammaFromDescription:(NSDictionary *)gammaDict;
- (CGFloat)gamma;
- (CGFloat)gammaBrightness;

// Settters
- (void)setGammaRed:(CGFloat)gammaRed
              green:(CGFloat)gammaGreen
               blue:(CGFloat)gammaBlue
         brightness:(CGFloat)brightness;
- (void)setGamma:(CGFloat)gammaValue brightness:(CGFloat)gammaBrightness;
- (void)setGamma:(CGFloat)value;
- (void)setGammaBrightness:(CGFloat)brightness;

// Other
- (void)fadeToBlack:(CGFloat)brightness;
- (void)fadeToNormal:(CGFloat)brightness;
// TODO
- (void)fadeTo:(NSInteger)mode       // 0 - to black, 1 - to normal
      interval:(CGFloat)seconds      // in seconds, mininmum 0.1
    brightness:(CGFloat)brightness;  // original brightness

//------------------------------------------------------------------------------
//--- Display properties
//------------------------------------------------------------------------------
- (void)parseProperties;
- (NSDictionary *)properties;
- (id)uniqueID;

// - (NSString *)model;    // EDID
// - (CGFloat)gamma;       // EDID
// - (NSArray *)rotations; // XRRRotations

@end
