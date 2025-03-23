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

/*
// output:
// typedef struct _XRROutputInfo {
//   Time            timestamp;
//   RRCrtc          crtc;
//   char            *name;
//   int             nameLen;
//   unsigned long   mm_width;
//   unsigned long   mm_height;
//   Connection      connection;
//   SubpixelOrder   subpixel_order;
//   int             ncrtc;
//   RRCrtc          *crtcs;
//   int             nclone;
//   RROutput        *clones;
//   int             nmode;
//   int             npreferred;
//   RRMode          *modes;
// } XRROutputInfo;

// CRTC:
// typedef struct _XRRCrtcInfo {
//   Time            timestamp;
//   int             x, y;
//   unsigned int    width, height;
//   RRMode          mode;
//   Rotation        rotation;
//   int             noutput;
//   RROutput        *outputs;
//   Rotation        rotations;
//   int             npossible;
//   RROutput        *possible;
// } XRRCrtcInfo;

// mode:
// typedef struct _XRRModeInfo {
//   RRMode              id;
//   unsigned int        width;
//   unsigned int        height;
//   unsigned long       dotClock;
//   unsigned int        hSyncStart;
//   unsigned int        hSyncEnd;
//   unsigned int        hTotal;
//   unsigned int        hSkew;
//   unsigned int        vSyncStart;
//   unsigned int        vSyncEnd;
//   unsigned int        vTotal;
//   char                *name;
//   unsigned int        nameLength;
//   XRRModeFlags        modeFlags;
// } XRRModeInfo;
*/

#include <X11/Xatom.h>
#include <X11/Xmd.h>
#import "OSEScreen.h"
#import "OSEDisplay.h"

@implementation OSEDisplay

// @synthesize outputName;
// @synthesize physicalSize;

+ (NSDictionary *)zeroResolution
{
  NSString *zeroSizeString = NSStringFromSize(NSMakeSize(0, 0));
  NSNumber *zeroRate = [NSNumber numberWithFloat:0.0];

  return [NSDictionary dictionaryWithObjectsAndKeys:zeroSizeString, OSEDisplayResolutionSizeKey, zeroRate,
                                                    OSEDisplayResolutionRateKey, nil];
}

//------------------------------------------------------------------------------
//--- Utility
//------------------------------------------------------------------------------
- (XRRModeInfo)_modeInfoForMode:(RRMode)mode
{
  XRRScreenResources *scr_resources = [screen randrScreenResources];
  XRRModeInfo rrMode;

  for (int i = 0; i < scr_resources->nmode; i++) {
    rrMode = scr_resources->modes[i];
    if (rrMode.id == mode)
      break;
  }
  return rrMode;
}
// Get mode with highest refresh rate
- (RRMode)_modeForResolution:(NSDictionary *)resolution
{
  XRRScreenResources *scr_resources = [screen randrScreenResources];
  XRROutputInfo *output_info;
  RRMode mode = None;
  XRRModeInfo mode_info;
  NSSize resDims;
  float rRate, mode_rate = 0.0;

  output_info = XRRGetOutputInfo(xDisplay, scr_resources, output_id);

  resDims = NSSizeFromString([resolution objectForKey:OSEDisplayResolutionSizeKey]);

  for (int i = 0; i < output_info->nmode; i++) {
    mode_info = [self _modeInfoForMode:output_info->modes[i]];
    if (mode_info.width == (unsigned int)resDims.width &&
        mode_info.height == (unsigned int)resDims.height) {
      rRate = (float)mode_info.dotClock / mode_info.hTotal / mode_info.vTotal;
      if (rRate > mode_rate)
        mode_rate = rRate;

      mode = output_info->modes[i];
    }
  }

  XRRFreeOutputInfo(output_info);

  return mode;
}
- (NSDictionary *)_resolutionForModeInfo:(XRRModeInfo)mode_info
{
  NSSize resSize;
  NSDictionary *res;
  CGFloat r;

  for (res in allResolutions) {
    resSize = NSSizeFromString([res objectForKey:OSEDisplayResolutionSizeKey]);
    if (resSize.width == mode_info.width && resSize.height == mode_info.height &&
        [[res objectForKey:OSEDisplayResolutionRateKey] floatValue] == _activeRate) {
      break;
    } else {
      res = nil;
    }
  }

  return res;
}

// Names are coming from kernel video and drm drivers:
//   eDP - Embedded DisplayPort
//   LVDS - Low-Voltage Differential Signaling
// If returns YES monitor will be deactivated on LID close.
- (BOOL)_isBuiltin
{
  if (!_outputName)
    return NO;

  if (([_outputName rangeOfString:@"LVDS"].location != NSNotFound))
    return YES;

  if (([_outputName rangeOfString:@"eDP"].location != NSNotFound))
    return YES;

  return NO;
}

//------------------------------------------------------------------------------
//--- Base
//------------------------------------------------------------------------------
- (id)initWithOutputInfo:(RROutput)output
         screenResources:(XRRScreenResources *)scr_res
                  screen:(OSEScreen *)scr
                xDisplay:(Display *)x_display
{
  XRROutputInfo *output_info;
  XRRModeInfo mode_info;
  XRRCrtcInfo *crtc_info;
  CGFloat rRate;
  NSSize rSize;
  NSDictionary *res;

  self = [super init];

  xDisplay = x_display;
  screen = scr;
  screen_resources = scr_res;

  isMain = NO;
  // isActive = NO;
  output_id = output;

  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output);

  // Output (connection port)
  _outputName = [[NSString alloc] initWithCString:output_info->name];
  _isBuiltin = [self _isBuiltin];
  _physicalSize = NSMakeSize((CGFloat)output_info->mm_width, (CGFloat)output_info->mm_height);
  connectionState = output_info->connection;

  // Get all resolutions for display
  allResolutions = [[NSMutableArray alloc] init];
  for (int i = 0; i < output_info->nmode; i++) {
    mode_info = [self _modeInfoForMode:output_info->modes[i]];
    rSize = NSMakeSize((CGFloat)mode_info.width, (CGFloat)mode_info.height);
    rRate = (CGFloat)mode_info.dotClock / mode_info.hTotal / mode_info.vTotal;
    res = @{
      OSEDisplayResolutionNameKey : [NSString stringWithCString:mode_info.name],
      OSEDisplayResolutionSizeKey : NSStringFromSize(rSize),
      OSEDisplayResolutionRateKey : [NSNumber numberWithDouble:rRate],
    };

    [allResolutions addObject:res];
  }

  // CRTC = 0 if monitor is not connected to output port
  if (output_info->crtc && [allResolutions count] > 0) {
    crtc_info = XRRGetCrtcInfo(xDisplay, screen_resources, output_info->crtc);
    // Current resolution
    mode_info = [self _modeInfoForMode:crtc_info->mode];
    if (mode_info.width > 0 && mode_info.height > 0) {
      // Actually there are dimensions of display:
      // 1. Resolution of monitor: mode_info.width x mode_info.height
      // 2. Logical size of display: crtc_info->width x crtc_info->height
      // Now I'm sticking to mode_info because I can't imagine real life
      // use case when logical size need to be bigger than resolution.
      _frame = NSMakeRect((CGFloat)crtc_info->x, (CGFloat)crtc_info->y, mode_info.width,
                          mode_info.height);
      _activeRate = (CGFloat)mode_info.dotClock / mode_info.hTotal / mode_info.vTotal;
      _activeResolution = [self resolutionWithWidth:mode_info.width
                                             height:mode_info.height
                                               rate:_activeRate];
      _activePosition = _frame.origin;
      // isActive = YES;

      XRRFreeCrtcInfo(crtc_info);

      // Primary display
      isMain = [self isMain];
    }
  } else if ([allResolutions count] > 0) {
    ASSIGN(_activeResolution, [OSEDisplay zeroResolution]);
    _activePosition = NSMakePoint(0, 0);
    _hiddenFrame.origin = _activePosition;
    _hiddenFrame.size = NSSizeFromString([[self bestResolution] objectForKey:OSEDisplayResolutionSizeKey]);
  }

  XRRFreeOutputInfo(output_info);

  // Initialize properties
  properties = nil;
  [self parseProperties];

  // Set initial values to gammaValue and gammaBrightness
  [self _getGamma];

  return self;
}

- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEDisplay %@: -dealloc", _outputName);

  // NSLog(@"OSEDisplay %@: resolution count: %lu; reaint count: %lu",
  //       outputName, [allResolutions count], [allResolutions retainCount]);
  // [allResolutions release];

  [properties release];
  [_outputName release];

  [super dealloc];
}

- (CGFloat)dpi
{
  // NSLog(@"OSEDisplay DPI: %.0f points, %.0f mm",
  //       frame.size.height, _physicalSize.height);
  if ((_frame.size.height <= 0) || (_physicalSize.height <= 0))
    return .0;

  return (25.4 * _frame.size.height) / _physicalSize.height;
}

//------------------------------------------------------------------------------
//--- Resolution and refresh rate
// resolution - NSDictionary with: Size = {width, height}, Rate = rate in Hz
// mode       - XRandR RRMode structure
// modeInfo   - XRandR XRRModeInfo structure
//------------------------------------------------------------------------------
- (NSArray *)allResolutions
{
  return allResolutions;
}

// First entry in list of supported resolutions
- (NSDictionary *)bestResolution
{
  return [allResolutions objectAtIndex:0];
}

- (BOOL)isSupportedResolution:(NSDictionary *)resolution
{
  NSSize dSize = NSSizeFromString([resolution objectForKey:OSEDisplayResolutionSizeKey]);

  if (dSize.width == 0 &&
      dSize.height == 0) {  // resolution 0x0 used for display deactivation - accept it
    return YES;
  }

  return !([self _modeForResolution:resolution] == 0);
}

- (NSDictionary *)resolutionWithWidth:(CGFloat)width height:(CGFloat)height rate:(CGFloat)refresh
{
  NSSize resSize;
  NSDictionary *res, *resolution = nil;
  CGFloat resRate, max_rate = 0.0;

  for (res in allResolutions) {
    resSize = NSSizeFromString([res objectForKey:OSEDisplayResolutionSizeKey]);
    resRate = [[res objectForKey:OSEDisplayResolutionRateKey] floatValue];
    if (resSize.width == width && resSize.height == height) {
      // 'rate' was specified, search for exact resolution
      if (refresh) {
        if ((float)refresh == (float)resRate) {
          resolution = res;
          break;
        }
      } else if (resRate > max_rate)  // search for resolution with max rate
      {
        resolution = res;
        max_rate = resRate;
      }
    }
  }
  // Combintation of 'width', 'height' and 'rate' doesn't match any resolutions
  // supported by display.
  // It's quite normal situation inside VM - resolution list reported by VM
  // doesn't consist current resolution of Xorg display if VM window was resized.
  // Create new resolution and add to list of known resolutions.
  if (resolution == nil) {
    // NSLog(@"OSEDisplay: Display is not set up with best resolution: %@",
    //       [self bestResolution]);
    NSSize rSize = NSMakeSize(width, height);
    NSNumber *rRate = [NSNumber numberWithFloat:refresh];

    resolution =
        [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromSize(rSize), OSEDisplayResolutionSizeKey,
                                                   rRate, OSEDisplayResolutionRateKey, nil];
    [allResolutions insertObject:resolution atIndex:0];
  }

  return resolution;
}

// Actually sets resolution of display device without changing layout.
// Updates '_frame', '_activeRate', '_activeResolution' and '_activePosition'
// ivars.
// If display was deactivated setting resolution to non-zero value activates it.
// If you want to set resolution and relayout displays with new resolution use
// [OSEScreen setDisplay:resolution:] instead.
- (void)setResolution:(NSDictionary *)resolution position:(NSPoint)position
{
  XRROutputInfo *output_info;
  XRRCrtcInfo *crtc_info;
  RRMode rr_mode;
  RRCrtc rr_crtc;
  XRRModeInfo mode_info;
  NSSize dims, resolutionSize;

  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output_id);

  NSDebugLLog(@"Screen", @"%s: Set resolution %@ and origin %@", output_info->name,
              [resolution objectForKey:OSEDisplayResolutionSizeKey], NSStringFromPoint(position));

  rr_crtc = output_info->crtc;
  if (!rr_crtc) {
    NSDebugLLog(@"Screen", @"%s: no CRTC assossiated with Output - requesting free CRTC...",
                output_info->name);
    rr_crtc = [screen randrFindFreeCRTC];
    if (!rr_crtc) {
      NSDebugLLog(@"Screen", @"%s: Can't find free CRTC!", output_info->name);
    }
    crtc_info = XRRGetCrtcInfo(xDisplay, screen_resources, rr_crtc);
    crtc_info->timestamp = CurrentTime;
    crtc_info->rotation = RR_Rotate_0;
    crtc_info->outputs[0] = output_id;
    crtc_info->noutput = 1;
  } else {
    crtc_info = XRRGetCrtcInfo(xDisplay, screen_resources, rr_crtc);
  }

  resolutionSize = NSSizeFromString([resolution objectForKey:OSEDisplayResolutionSizeKey]);

  NSLog(@"[OSEDisplay] %s reoslutionSize: %@ frame: %@", output_info->name,
        [resolution objectForKey:OSEDisplayResolutionSizeKey], [resolution objectForKey:OSEDisplayFrameKey]);

  if (resolutionSize.width == 0 || resolutionSize.height == 0) {
    rr_mode = None;
    crtc_info->timestamp = CurrentTime;
    crtc_info->rotation = RR_Rotate_0;
    crtc_info->outputs = NULL;
    crtc_info->noutput = 0;
  } else {
    // Check if resolution is supported must be done before screen size
    // calculation ([OSEScreen applyLayout:]).
    rr_mode = [self _modeForResolution:resolution];
  }

  // Current and new modes differ
  if (crtc_info->mode != rr_mode || crtc_info->x != position.x || crtc_info->y != position.y) {
    XRRSetCrtcConfig(xDisplay, screen_resources, rr_crtc, crtc_info->timestamp, position.x,
                     position.y, rr_mode, crtc_info->rotation, crtc_info->outputs,
                     crtc_info->noutput);
  }

  // Update _frame, so _activeResolution{Size} == _frame.size
  _frame = NSMakeRect(position.x, position.y, resolutionSize.width, resolutionSize.height);

  // Save values which represent current monitor state
  ASSIGN(_activeResolution, resolution);
  _activeRate = [[resolution objectForKey:OSEDisplayResolutionRateKey] floatValue];
  _activePosition = position;

  XRRFreeCrtcInfo(crtc_info);
  XRRFreeOutputInfo(output_info);
}

//------------------------------------------------------------------------------
//--- Monitor state
//------------------------------------------------------------------------------
- (BOOL)isConnected
{
  return (connectionState == RR_Connected) ? YES : NO;
}

- (BOOL)isActive
{
  return (NSIsEmptyRect(_frame)) ? NO : YES;
}

// Changes '_activeResolution' ivar without setting resolution to monitor.
// Used for preparation to apply new display layout.
- (void)setActive:(BOOL)active
{
  NSDictionary *resolution;

  if (active == YES)  // activation
  {
    if (NSIsEmptyRect(_hiddenFrame) == NO) {
      _frame = _hiddenFrame;
      _hiddenFrame = NSZeroRect;
    } else {
      _frame.size = NSSizeFromString([[self bestResolution] objectForKey:OSEDisplayResolutionSizeKey]);
    }
    resolution = [self resolutionWithWidth:_frame.size.width height:_frame.size.height rate:0.0];
  } else  // deactivation
  {
    _hiddenFrame = _frame;
    _frame = NSZeroRect;
    resolution = [OSEDisplay zeroResolution];
  }

  // Synchronize _frame and _activeResolution
  ASSIGN(_activeResolution, resolution);
}

- (BOOL)isMain
{
  if (XRRGetOutputPrimary(xDisplay, RootWindow(xDisplay, DefaultScreen(xDisplay))) == output_id) {
    return YES;
  }

  return NO;
}

- (void)setMain:(BOOL)yn
{
  if ([self isActive] && yn == YES) {
    NSDebugLLog(@"Screen", @"%@: become main display.", _outputName);
    XRRSetOutputPrimary(xDisplay, RootWindow(xDisplay, DefaultScreen(xDisplay)), output_id);
  }

  isMain = yn;
}

//------------------------------------------------------------------------------
//--- Gamma correction, brightness
//------------------------------------------------------------------------------

/* Returns the index of the last value in an array < 0xffff */
// from xrandr.c
static int find_last_non_clamped(CARD16 array[], int size)
{
  int i;
  for (i = size - 1; i > 0; i--) {
    if (array[i] < 0xffff)
      return i;
  }
  return 0;
}

// from xrandr.c
- (void)_getGamma
{
  XRROutputInfo *output_info;
  XRRCrtcGamma *crtc_gamma;
  CGFloat i1, v1, i2, v2;
  int size, middle, last_best, last_red, last_green, last_blue;
  CARD16 *best_array;

  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output_id);

  // Default values
  gammaValue.red = 1.0;
  gammaValue.green = 1.0;
  gammaValue.blue = 1.0;
  gammaBrightness = 1.0;

  if (!output_info->crtc) {
    NSDebugLLog(@"Display", @"OSEDisplay: No display connected to output %s", output_info->name);
    return;
  }

  size = XRRGetCrtcGammaSize(xDisplay, output_info->crtc);
  if (!size) {
    NSDebugLLog(@"Display", @"OSEDisplay: Failed to get size of gamma for output %s",
                output_info->name);
    return;
  }

  crtc_gamma = XRRGetCrtcGamma(xDisplay, output_info->crtc);
  if (!crtc_gamma) {
    NSDebugLLog(@"Display", @"OSEDisplay: Failed to get gamma for output %s", output_info->name);
    return;
  }

  /*
   * Here is a bit tricky because gamma is a whole curve for each
   * color.  So, typically, we need to represent 3 * 256 values as 3 + 1
   * values.  Therefore, we approximate the gamma curve (v) by supposing
   * it always follows the way we set it: a power function (i^g)
   * multiplied by a brightness (b).
   * v = i^g * b
   * so g = (ln(v) - ln(b))/ln(i)
   * and b can be found using two points (v1,i1) and (v2, i2):
   * b = e^((ln(v2)*ln(i1) - ln(v1)*ln(i2))/ln(i1/i2))
   * For the best resolution, we select i2 at the highest place not
   * clamped and i1 at i2/2. Note that if i2 = 1 (as in most normal
   * cases), then b = v2.
   */
  last_red = find_last_non_clamped(crtc_gamma->red, size);
  last_green = find_last_non_clamped(crtc_gamma->green, size);
  last_blue = find_last_non_clamped(crtc_gamma->blue, size);
  best_array = crtc_gamma->red;
  last_best = last_red;
  if (last_green > last_best) {
    last_best = last_green;
    best_array = crtc_gamma->green;
  }
  if (last_blue > last_best) {
    last_best = last_blue;
    best_array = crtc_gamma->blue;
  }
  if (last_best == 0) {
    last_best = 1;
  }

  middle = last_best / 2;
  i1 = (CGFloat)(middle + 1) / size;
  v1 = (CGFloat)(best_array[middle]) / 65535;
  i2 = (CGFloat)(last_best + 1) / size;
  v2 = (CGFloat)(best_array[last_best]) / 65535;
  if (v2 < 0.0001) { /* The screen is black */
    gammaBrightness = 0;
  } else {
    if ((last_best + 1) == size) {
      gammaBrightness = v2;
    } else {
      gammaBrightness = exp((log(v2) * log(i1) - log(v1) * log(i2)) / log(i1 / i2));
    }
    gammaValue.red = log((double)(crtc_gamma->red[last_red / 2]) / gammaBrightness / 65535) /
                     log((CGFloat)((last_red / 2) + 0.5) / size);
    gammaValue.green = log((CGFloat)(crtc_gamma->green[last_green / 2]) / gammaBrightness / 65535) /
                       log((CGFloat)((last_green / 2) + 0.5) / size);
    gammaValue.blue = log((CGFloat)(crtc_gamma->blue[last_blue / 2]) / gammaBrightness / 65535) /
                      log((CGFloat)((last_blue / 2) + 0.5) / size);

    // Drop precision to 2 digits after point
    // NSLog(@"OSEDisplay _getGamma pre: %f", gammaValue.red);

    gammaValue.red = (CGFloat)((int)(gammaValue.red * 100.0)) / 100.0;
    gammaValue.green = (CGFloat)((int)(gammaValue.green * 100.0)) / 100.0;
    gammaValue.blue = (CGFloat)((int)(gammaValue.blue * 100.0)) / 100.0;
    // gammaBrightness = (CGFloat)((int)(gammaBrightness*100.0))/100.0;

    // NSLog(@"OSEDisplay _getGamma post: %f", gammaValue.red);
  }

  XRRFreeGamma(crtc_gamma);
}

//---
// gamma - monitor gamma, for example 0.8
// gamma correction - 1.0/gamma, e.g. 1.25

- (BOOL)isGammaSupported
{
  XRROutputInfo *output_info;
  int size;

  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output_id);

  if (!output_info->crtc)
    return NO;

  size = XRRGetCrtcGammaSize(xDisplay, output_info->crtc);

  if (size == 0 || [self uniqueID] == nil)
    return NO;

  return YES;
}

- (NSDictionary *)gammaDescription
{
  NSMutableDictionary *d = [[NSMutableDictionary alloc] init];

  // NSLog(@"OSEDisplay gammaDescription: %f", gammaValue.red);

  [d setObject:[NSString stringWithFormat:@"%.2f", gammaValue.red] forKey:OSEDisplayGammaRedKey];
  [d setObject:[NSString stringWithFormat:@"%.2f", gammaValue.green]
        forKey:OSEDisplayGammaGreenKey];
  [d setObject:[NSString stringWithFormat:@"%.2f", gammaValue.blue] forKey:OSEDisplayGammaBlueKey];
  [d setObject:[NSString stringWithFormat:@"%.2f", gammaBrightness]
        forKey:OSEDisplayGammaBrightnessKey];

  return [d autorelease];
}

- (NXGammaValue)gammaFromDescription:(NSDictionary *)desc
{
  CGFloat red, green, blue, brightness;
  NXGammaValue gamma;

  if (!desc)
    return gammaValue;

  red = [[desc objectForKey:OSEDisplayGammaRedKey] floatValue];
  green = [[desc objectForKey:OSEDisplayGammaGreenKey] floatValue];
  blue = [[desc objectForKey:OSEDisplayGammaBlueKey] floatValue];

  gamma.red = (red == 0.0) ? 1.0 : red;
  gamma.green = (green == 0.0) ? 1.0 : green;
  gamma.blue = (blue == 0.0) ? 1.0 : blue;

  return gamma;
}

- (void)setGammaFromDescription:(NSDictionary *)gammaDict
{
  NSString *red, *green, *blue, *brightness;

  if (!gammaDict)
    return;

  gammaValue = [self gammaFromDescription:gammaDict];
  gammaBrightness = [[gammaDict objectForKey:OSEDisplayGammaBrightnessKey] floatValue];

  // We're done - gammaValue is set but display is not ready
  if (![self isActive])
    return;

  // NSLog(@"setGammaFromDescription: %f : %f : %f",
  //       gammaValue.red, gammaValue.green, gammaValue.blue);

  [self setGammaRed:gammaValue.red
              green:gammaValue.green
               blue:gammaValue.blue
         brightness:gammaBrightness];
}

- (CGFloat)gamma
{
  [self _getGamma];

  return (gammaValue.red + gammaValue.green + gammaValue.blue) / 3.0;
}

- (CGFloat)gammaBrightness
{
  [self _getGamma];

  return gammaBrightness;
}

- (void)setGammaRed:(CGFloat)gammaRed
              green:(CGFloat)gammaGreen
               blue:(CGFloat)gammaBlue
         brightness:(CGFloat)brightness
{
  XRROutputInfo *output_info;
  XRRCrtcGamma *gamma, *new_gamma;
  int i, size;

  // if ([self isGammaSupported] == NO) return;

  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output_id);
  gamma = XRRGetCrtcGamma(xDisplay, output_info->crtc);
  size = gamma->size;
  new_gamma = XRRAllocGamma(size);

  gammaValue.red = (gammaRed == 0.0) ? 1.0 : gammaRed;
  gammaValue.green = (gammaGreen == 0.0) ? 1.0 : gammaGreen;
  gammaValue.blue = (gammaBlue == 0.0) ? 1.0 : gammaBlue;
  gammaBrightness = brightness;

  for (i = 0; i < size; i++) {
    if (gammaRed == 1.0 && brightness == 1.0)
      new_gamma->red[i] = (CGFloat)i / (CGFloat)(size - 1) * 65535.0;
    else
      new_gamma->red[i] =
          MIN(pow((CGFloat)i / (CGFloat)(size - 1), gammaValue.red) * brightness, 1.0) * 65535.0;

    if (gammaGreen == 1.0 && brightness == 1.0)
      new_gamma->green[i] = (CGFloat)i / (CGFloat)(size - 1) * 65535.0;
    else
      new_gamma->green[i] =
          MIN(pow((CGFloat)i / (CGFloat)(size - 1), gammaValue.green) * brightness, 1.0) * 65535.0;

    if (gammaBlue == 1.0 && brightness == 1.0)
      new_gamma->blue[i] = (CGFloat)i / (CGFloat)(size - 1) * 65535.0;
    else
      new_gamma->blue[i] =
          MIN(pow((CGFloat)i / (CGFloat)(size - 1), gammaValue.blue) * brightness, 1.0) * 65535.0;
  }

  XRRSetCrtcGamma(xDisplay, output_info->crtc, new_gamma);
  XSync(xDisplay, False);

  XRRFreeGamma(new_gamma);
  XRRFreeOutputInfo(output_info);
}

- (void)setGamma:(CGFloat)value brightness:(CGFloat)brightness
{
  [self setGammaRed:value green:value blue:value brightness:brightness];
}

- (void)setGamma:(CGFloat)value
{
  [self setGammaRed:value green:value blue:value brightness:gammaBrightness];
}

- (void)setGammaBrightness:(CGFloat)brightness
{
  [self setGammaRed:gammaValue.red
              green:gammaValue.green
               blue:gammaValue.blue
         brightness:brightness];
}

#include <unistd.h>

// TODO: set fade speed by time interval
- (void)fadeToBlack:(CGFloat)brightness
{
  if (![self isActive])
    return;

  XGrabServer(xDisplay);

  for (float i = 10; i >= 0; i--) {
    [self setGammaBrightness:brightness * (i / 10)];
    usleep(30000);
  }

  XUngrabServer(xDisplay);
}

// TODO: set fade speed by time interval
- (void)fadeToNormal:(CGFloat)brightness
{
  if (![self isActive])
    return;

  // XGrabServer(xDisplay);

  // for (float i=0; i <= 10; i++)
  //   {
  //     [self setGammaBrightness:i/10];
  //     usleep(10000);
  //   }

  NSDebugLLog(@"Screen", @">>> Start fade to normal");

  CGFloat secs = 0.5;
  NSUInteger msecs = secs * 1000000;
  NSUInteger steps = ceil(msecs / 30000);
  // NSUInteger msecs_step = msecs / steps;

  for (float i = 0; i <= steps; i++) {
    [self setGammaBrightness:brightness * (i / steps)];
    usleep(30000);
  }

  NSDebugLLog(@"Screen", @">>> End fade to normal");

  // XUngrabServer(xDisplay);
}

- (void)fadeTo:(NSInteger)mode      // now ignored
      interval:(CGFloat)seconds     // in seconds, mininmum 0.1
    brightness:(CGFloat)brightness  // original brightness
{
  if (![self isActive])
    return;

  NSDebugLLog(@"Screen", @">>> Start fade");

  NSUInteger msecs = seconds * 1000000;
  NSUInteger steps = ceil(msecs / 30000);
  float i;

  i = 1;
  while (i <= steps) {
    if (mode)  // to normal
      [self setGammaBrightness:brightness * (i / steps)];
    else  // to black
      [self setGammaBrightness:brightness * (i / steps)];

    usleep(30000);
    i++;
  }

  NSDebugLLog(@"Screen", @">>> End fade");

  // XUngrabServer(xDisplay);
}

//------------------------------------------------------------------------------
//--- Display properties
//------------------------------------------------------------------------------

id property_value(Display *dpy, int value_format, /* 8, 16, 32 */
                  Atom value_type,                /* XA_{ATOM,INTEGER,CARDINAL} */
                  const void *value_bytes)
{
  char *str = NULL;
  id aValue = @"?";
  if (value_type == XA_ATOM && value_format == 32) {
    const Atom *val = value_bytes;
    aValue = [NSString stringWithCString:XGetAtomName(dpy, *val)];
  }

  if (value_type == XA_INTEGER) {
    if (value_format == 8) {
      const int8_t *val = value_bytes;
      // printf ("%" PRId8, *val);
      aValue = [NSNumber numberWithChar:*val];
    }
    if (value_format == 16) {
      const int16_t *val = value_bytes;
      // printf ("%" PRId16, *val);
      aValue = [NSNumber numberWithShort:*val];
    }
    if (value_format == 32) {
      const int32_t *val = value_bytes;
      // printf ("%" PRId32, *val);
      aValue = [NSNumber numberWithInt:*val];
    }
  }

  if (value_type == XA_CARDINAL) {
    if (value_format == 8) {
      const uint8_t *val = value_bytes;
      // printf ("%" PRIu8, *val);
      aValue = [NSNumber numberWithUnsignedChar:*val];
    }
    if (value_format == 16) {
      const uint16_t *val = value_bytes;
      // printf ("%" PRIu16, *val);
      aValue = [NSNumber numberWithUnsignedShort:*val];
    }
    if (value_format == 32) {
      const uint32_t *val = value_bytes;
      // printf ("%" PRIu32, *val);
      aValue = [NSNumber numberWithUnsignedInt:*val];
    }
  }

  return aValue;
}

- (void)parseProperties
{
  Atom *output_props;
  int nprops;
  Atom actual_type;
  int actual_format;
  unsigned long bytes_after;
  unsigned long nitems;
  unsigned char *prop;
  char *atom_name;
  XRRPropertyInfo *prop_info;

  NSMutableDictionary *valueDict;
  NSMutableArray *value;
  NSMutableArray *variants;

  if (properties == nil) {
    properties = [[NSMutableDictionary alloc] init];
  }

  output_props = XRRListOutputProperties(xDisplay, output_id, &nprops);

  // fprintf(stderr, "properties(%i):\n", nprops);
  for (int k = 0; k < nprops; k++) {
    XRRGetOutputProperty(xDisplay, output_id,
                         output_props[k],  // Atom
                         0,                // long offset,
                         128,              // long length,
                         false,            // Bool _delete,
                         false,            // Bool pending,
                         AnyPropertyType,  // Atom req_type,
                         &actual_type,     // Atom *actual_type,
                         &actual_format,   // int *actual_format,
                         &nitems,          // unsigned long *nitems,
                         &bytes_after,     // unsigned long *bytes_after,
                         &prop);           // unsigned char **

    // Name
    atom_name = XGetAtomName(xDisplay, output_props[k]);

    if (!strcmp(atom_name, "EDID") && nitems > 1) {
      [properties setObject:[NSData dataWithBytes:prop length:128] forKey:@"EDID"];
    } else {
      valueDict = [[NSMutableDictionary alloc] init];

      // Value
      {
        int bytes_per_item = actual_format / 8;

        value = [[NSMutableArray alloc] init];
        for (int i = 0; i < (int)nitems; i++) {
          [value addObject:property_value(xDisplay, actual_format, actual_type,
                                          prop + (i * bytes_per_item))];
        }
        [valueDict setObject:value forKey:@"Value"];
        [value release];
      }

      prop_info = XRRQueryOutputProperty(xDisplay, output_id, output_props[k]);

      // Range of values
      if (prop_info->range && prop_info->num_values > 0) {
        NSRange range;
        NSNumber *start, *end;

        for (int j = 0; j < prop_info->num_values / 2; j++) {
          start = property_value(xDisplay, 32, actual_type,
                                 (unsigned char *)&(prop_info->values[j * 2]));
          end = property_value(xDisplay, 32, actual_type,
                               (unsigned char *)&(prop_info->values[j * 2 + 1]));
        }
        range = NSMakeRange([start unsignedIntValue], [end unsignedIntValue]);
        [valueDict setObject:NSStringFromRange(range) forKey:@"Range"];
      }

      // Supported values
      if (!prop_info->range && prop_info->num_values > 0) {
        id vv;
        variants = [[NSMutableArray alloc] init];

        for (int j = 0; j < prop_info->num_values; j++) {
          vv = property_value(xDisplay, 32, actual_type, (unsigned char *)&(prop_info->values[j]));
          [variants addObject:vv];
        }
        [valueDict setObject:variants forKey:@"Supported"];
        [variants release];
      }

      [properties setObject:valueDict forKey:[NSString stringWithCString:(char *)atom_name]];
      [valueDict release];
      free(prop_info);
    }

    free(prop);
  }
}

- (NSDictionary *)properties
{
  return properties;
}

- (id)uniqueID
{
  id displayID = [properties objectForKey:@"EDID"];

  if ([displayID length] < 1) {
    displayID = _outputName;
  }

  return displayID;
}

@end
