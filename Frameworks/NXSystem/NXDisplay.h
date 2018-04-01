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
  Display		*xDisplay;
  NXScreen		*screen;
  XRRScreenResources	*screen_resources;
  RROutput		output_id;

  Connection     	connectionState;	// RandR connection state
  NSMutableArray 	*allResolutions;	// width, height, rate
  
  CGFloat  		dpiValue;		// calculated DPI

  NXGammaValue		gammaValue;
  CGFloat		gammaBrightness;

  NSMutableDictionary	*properties;
  
  BOOL			isMain;
  BOOL			isActive;
}

@property (readonly) NSString *outputName;  // LVDS, VGA, DVI, HDMI
@property (readonly) NSSize physicalSize;  // in milimetres
@property (readonly) BOOL isBuiltin;  // determined by outputName

+ (NSDictionary *)zeroResolution;

- (id)initWithOutputInfo:(RROutput)output
         screenResources:(XRRScreenResources *)scr_res
                  screen:(NXScreen *)scr
                xDisplay:(Display *)x_display;

- (CGFloat)dpi;           // calculated from frame and phys. size

//------------------------------------------------------------------------------
//--- Resolution, refresh rate
//------------------------------------------------------------------------------
//--- Getters for resolutions supported by display
- (NSArray *)allResolutions;    // Supported resolutions (W x H @ R)
// - (NSDictionary *)largestResolution;
- (NSDictionary *)bestResolution;
- (BOOL)isSupportedResolution:(NSDictionary *)resolution;
- (NSDictionary *)resolutionWithWidth:(CGFloat)width
                               height:(CGFloat)height
                                 rate:(CGFloat)refresh;

//--- Active (visible to user) resolution of display
// These values may only be changed with -setResolution:position: method.
@property (readonly) NSDictionary *activeResolution;  // {Size=; Rate=}
@property (readonly) CGFloat activeRate;  // Refresh rate for resolution
@property (readonly) NSPoint activePosition;

//--- Setter
- (void)setResolution:(NSDictionary *)resolution
             position:(NSPoint)position;

//------------------------------------------------------------------------------
//--- Properties which aimed to process requests by NXScreen
// frame - holds active resolution and position of display.
//         If 'frame.size' differs from resolultion's 'Size' it means resolution
//         change was requested.
//         If frame.size holds zeros - display deactivation requested.
//         'hiddenFrame.size' must hold non-zero values.
// hiddenFrame - if holds non-zero values - display deactivation was requested
//               or display already deactivated.
// When display is deactivated resolution and origin values are set to 0.
//------------------------------------------------------------------------------
@property NSRect frame;  // logical rect of monitor
@property NSRect hiddenFrame;  // logical rect for inactive monitor

//------------------------------------------------------------------------------
//--- Monitor state
//------------------------------------------------------------------------------
- (BOOL)isConnected;      // output has connected monitor
- (BOOL)isActive;         // is online and visible
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
- (void)setGamma:(CGFloat)gammaValue
      brightness:(CGFloat)gammaBrightness;
- (void)setGamma:(CGFloat)value;
- (void)setGammaBrightness:(CGFloat)brightness;

// Other
- (void)fadeToBlack:(CGFloat)brightness;
- (void)fadeToNormal:(CGFloat)brightness;
// TODO
- (void)fadeTo:(NSInteger)mode      // 0 - to black, 1 - to normal
      interval:(CGFloat)seconds     // in seconds, mininmum 0.1
    brightness:(CGFloat)brightness; // original brightness

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
