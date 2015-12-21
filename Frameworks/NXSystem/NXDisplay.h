/*
 * NXDisplay.h
 *
 * Represents output port in computer and connected physical monitor.
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

#import <Foundation/Foundation.h>

#import <X11/extensions/Xrandr.h>

@class NXScreen;

struct _NXGammaValue
{
  CGFloat red;
  CGFloat green;
  CGFloat blue;
};
typedef struct _NXGammaValue NXGammaValue;

// Physical device
@interface NXDisplay : NSObject
{
  Display     *xDisplay;
  NXScreen    *screen;
  XRRScreenResources *screen_resources;
  RROutput    output_id;

  NSString       *outputName;     // name of Xrandr output (VGA)
  NSSize         physicalSize;    // physical size in milimeters
  Connection     connectionState; // RandR connection state
  NSMutableArray *resolutions; // width, height, rate
  
  NSRect   frame;           // logical rect of display
  NSSize   modeSize;        // display resolution
  CGFloat  modeRate;        // refresh rate for resolution (75.0)
  
  CGFloat  dpiValue;

  NXGammaValue gammaValue;
  CGFloat      gammaBrightness;

  NSMutableDictionary *properties;
  
  BOOL        isMain;
  BOOL        isActive;
}

- (id)initWithOutputInfo:(RROutput)output
                  screen:(NXScreen *)scr
                xDisplay:(Display *)x_display;

- (NSString *)outputName; // LVDS, VGA, DVI, HDMI
- (NSSize)physicalSize;   // in milimetres

- (NSArray *)allModes;    // Supported resolutions (W x H @ R)
- (NSDictionary *)preferredMode;
- (NSDictionary *)mode;   // Current mode
- (NSSize)modeSize;       // width, height
- (CGFloat)modeRate;      // 75.0 in Hertz

- (RRMode)randrModeForResolution:(NSDictionary *)resolution;
- (void)setResolution:(NSDictionary *)resolution
               origin:(NSPoint)origin;

- (NSRect)frame;          // logical rect of display
- (CGFloat)dpi;

- (BOOL)isConnected;      // output has connected monitor
- (BOOL)isActive;         // is online and visible
- (void)deactivate;
- (void)activate;

- (BOOL)isBuiltin;
- (BOOL)isMain;
- (void)setMain:(BOOL)yn;

- (void)_getGamma;

// Get
- (NSDictionary *)gammaDescription;
- (void)setGammaFromDescription:(NSDictionary *)gammaDict;
- (CGFloat)gamma;
- (CGFloat)gammaBrightness;

// Set
- (void)setGammaRed:(CGFloat)gammaRed
              green:(CGFloat)gammaGreen
               blue:(CGFloat)gammaBlue
         brightness:(CGFloat)brightness;
- (void)setGamma:(CGFloat)gammaValue
      brightness:(CGFloat)gammaBrightness;
- (void)setGamma:(CGFloat)value;
- (void)setGammaBrightness:(CGFloat)brightness;

// Other
- (void)fadeToBlack:(CGFloat)brightness;
- (void)fadeToNormal:(CGFloat)brightness;
// - (void)fadeToBlack;
// - (void)fadeToNormal;
- (void)fadeTo:(NSInteger)mode      // 0 - to black, 1 - to normal
      interval:(CGFloat)seconds     // in seconds, mininmum 0.1
    brightness:(CGFloat)brightness; // original brightness

- (void)parseProperties;
- (NSDictionary *)properties;
- (id)uniqueID;

// - (NSString *)model;    // EDID
// - (CGFloat)brightness;  // EDID (if supported)
// - (CGFloat)gamma;       // EDID
// - (NSArray *)rotations; // XRRRotations

@end
