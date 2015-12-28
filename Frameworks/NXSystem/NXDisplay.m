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
#import "NXScreen.h"
#import "NXDisplay.h"

@implementation NXDisplay

- (id)initWithOutputInfo:(RROutput)output
                  screen:(NXScreen *)scr
                xDisplay:(Display *)x_display
{
  XRROutputInfo *output_info;
  
  self = [super init];

  xDisplay = x_display;
  screen = [scr retain];
  screen_resources = [screen randrScreenResources];

  isMain = NO;
  isActive = NO;
  output_id = output;
  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output);

  // Output (connection port)
  outputName = [[NSString alloc] initWithCString:output_info->name];
  physicalSize = NSMakeSize((CGFloat)output_info->mm_width,
                            (CGFloat)output_info->mm_height);
  connectionState = output_info->connection;

  // Display modes (resolutions supported by monitor connected to output)
  XRRModeInfo  mode_info;
  XRRCrtcInfo  *crtc_info;
  NSString     *name;
  NSNumber     *rate;
  NSSize       dimensions;
  NSDictionary *res;
  
  resolutions = [[NSMutableArray alloc] init];
  
  for (int i=0; i<output_info->nmode; i++)
    {
      mode_info = getModeInfoForMode(xDisplay,
                                     screen_resources,
                                     output_info->modes[i]);
      rate = [NSNumber
               numberWithFloat:
                 (float)mode_info.dotClock/mode_info.hTotal/mode_info.vTotal];

      name = [NSString stringWithFormat:@"%s@%.2f",
                       mode_info.name, [rate floatValue]];
      dimensions = NSMakeSize((CGFloat)mode_info.width,
                              (CGFloat)mode_info.height);
      res = [NSDictionary dictionaryWithObjectsAndKeys:
                            name, @"Name",
                          NSStringFromSize(dimensions), @"Dimensions",
                          rate, @"Rate",
                          nil];
      [resolutions addObject:res];
    }

  //CRTC (may be 0 only if monitor is not connected to output port)
  if (output_info->crtc)
    {
      crtc_info = XRRGetCrtcInfo(xDisplay, screen_resources, output_info->crtc);
      frame = NSMakeRect((CGFloat)crtc_info->x,
                         (CGFloat)crtc_info->y,
                         (CGFloat)crtc_info->width,
                         (CGFloat)crtc_info->height);
      
      // Current resolution
      mode_info = getModeInfoForMode(xDisplay,
                                     screen_resources, crtc_info->mode);
      if (mode_info.width > 0 && mode_info.height)
        {
          isActive = YES;
          modeSize = NSMakeSize(mode_info.width, mode_info.height);
          modeRate = (float)mode_info.dotClock/mode_info.hTotal/mode_info.vTotal;
          dpiValue = (25.4 * modeSize.height) / output_info->mm_height;
        }

      // Primary display
      isMain = [self isMain];
      
      XRRFreeCrtcInfo(crtc_info);
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
  [screen release];

  [properties release];
  [outputName release];
  [resolutions release];
  
  [super dealloc];
}

- (NSString *)outputName
{
  return outputName;
}
- (NSSize)physicalSize
{
  return physicalSize;
}

- (NSArray *)allModes
{
  return resolutions;
}
- (NSDictionary *)preferredMode
{
  NSDictionary *mode=nil, *res;
  NSSize       resSize;
  int          mpixels=0, mps, res_count;
  float        rate=0.0, r;

  res_count = [resolutions count];
  for (int i=0; i<res_count; i++)
    {
      res = [resolutions objectAtIndex:i];
      resSize = NSSizeFromString([res objectForKey:@"Dimensions"]);
      mps = resSize.width * resSize.height;
      r = [[res objectForKey:@"Rate"] floatValue];
      
      if ((mps == mpixels) && (r > rate))
        {
          mode = res;
        }
      else if (mps > mpixels)
        {
          mpixels = mps;
          mode = res;
        }
    }

  if (!mode) mode = [resolutions objectAtIndex:0];
  
  return mode;
}
// Returns mode description.
// If mode is not in list of supported by monitor - returns 'nil'.
- (NSDictionary *)mode
{
  NSDictionary *mode = nil;
  NSSize       modeDims;

  for (mode in resolutions)
    {
      modeDims = NSSizeFromString([mode objectForKey:@"Dimensions"]);
      if (modeDims.width == modeSize.width &&
          modeDims.height == modeSize.height &&
          [[mode objectForKey:@"Rate"] floatValue] == modeRate)
        {
          break;
        }
    }

  if (mode == nil)
    {
      mode = [self preferredMode];
    }

  return mode;
}
- (NSSize)modeSize
{
  return modeSize;
}
- (CGFloat)modeRate
{
  return modeRate;
}

// Get mode with highest refresh rate
- (RRMode)randrModeForResolution:(NSDictionary *)resolution
{
  // XRRScreenResources *screen_resources = [screen randrScreenResources];
  XRROutputInfo      *output_info;
  RRMode             mode = None;
  XRRModeInfo        mode_info;
  NSSize             resDims;
  float              rate, mode_rate=0.0;
  
  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output_id);

  resDims = NSSizeFromString([resolution objectForKey:@"Dimensions"]);

  for (int i=0; i<output_info->nmode; i++)
    {
      mode_info = getModeInfoForMode(xDisplay, screen_resources,
                                     output_info->modes[i]);
      if (mode_info.width == (unsigned int)resDims.width &&
          mode_info.height == (unsigned int)resDims.height)
        {
          rate = (float)mode_info.dotClock/mode_info.hTotal/mode_info.vTotal;
          if (rate > mode_rate) mode_rate = rate;
          
          mode = output_info->modes[i];
        }
    }
  
  XRRFreeOutputInfo(output_info);

  return mode;
}

// Sets resolution without changing layout
// If you want to relayout displays with new resolution use
// [NXScreen setDisplay:resolution:origin] instead.
- (void)setResolution:(NSDictionary *)resolution
               origin:(NSPoint)origin
{
  XRRScreenResources *scr_resources = [screen randrScreenResources];
  XRROutputInfo      *output_info;
  XRRCrtcInfo        *crtc_info;
  RRMode             rr_mode;
  RRCrtc             rr_crtc;
  XRRModeInfo        mode_info;
  CGFloat            brightness = gammaBrightness;
  NSSize 	     dims;
  
  output_info = XRRGetOutputInfo(xDisplay, scr_resources, output_id);
  
  NSLog(@"Set resolution %@ for CRTC output %s", 
        [resolution objectForKey:@"Dimensions"],
        output_info->name);
 
  rr_crtc = output_info->crtc;
  if (!rr_crtc)
    {
      rr_crtc = [screen randrFindFreeCRTC];
      crtc_info = XRRGetCrtcInfo(xDisplay, scr_resources, rr_crtc);
      crtc_info->timestamp = CurrentTime;
      crtc_info->rotation = RR_Rotate_0;
      crtc_info->outputs[0] = output_id;
      crtc_info->noutput = 1;
      origin.x = frame.origin.x;
      origin.y = frame.origin.y;
    }
  else
    {
      crtc_info = XRRGetCrtcInfo(xDisplay, scr_resources, rr_crtc);
    }

  if (dims.width == 0 || dims.height == 0)
    {
      rr_mode = None;
      crtc_info->timestamp = CurrentTime;
      crtc_info->rotation = RR_Rotate_0;
      crtc_info->outputs = NULL;
      crtc_info->noutput = 0;
    }
  else
    {
      rr_mode = [self randrModeForResolution:resolution];
    }
  
  // Current and new modes differ
  if (crtc_info->mode != rr_mode)
    {
      [self fadeToBlack:brightness];
  
      XRRSetCrtcConfig(xDisplay,
                       scr_resources,
                       rr_crtc,
                       crtc_info->timestamp,
                       origin.x, origin.y,
                       rr_mode,
                       crtc_info->rotation,
                       crtc_info->outputs,
                       crtc_info->noutput);
  
      // Save dimensions in ivars for -activate.
      dims = NSSizeFromString([resolution objectForKey:@"Dimensions"]);
      if (dims.width > 0 && dims.height > 0)
        {
          isActive = YES;
          modeSize = NSSizeFromString([resolution objectForKey:@"Dimensions"]);
          modeRate = [[resolution objectForKey:@"Rate"] floatValue];
          frame = NSMakeRect(origin.x, origin.y,
                             modeSize.width, modeSize.height);
        }
      
      [self fadeToNormal:brightness];
    }
  
  XRRFreeCrtcInfo(crtc_info);
  XRRFreeOutputInfo(output_info);  
}

- (NSRect)frame
{
  return frame;
 }
- (CGFloat)dpi
{
  return dpiValue;
} 

- (BOOL)isConnected
{
  if (connectionState == RR_Connected)
    return YES;
  
  return NO;
}
- (BOOL)isActive
{
  return isActive;
}
- (void)deactivate
{
  NSDictionary *res;
  
  res = [NSDictionary dictionaryWithObjectsAndKeys:
                        outputName, @"Name",
                      NSStringFromSize(NSMakeSize(0,0)), @"Dimensions",
                         [NSNumber numberWithFloat:0.0], @"Rate",
                      nil];
  [self setResolution:res origin:NSMakePoint(0,0)];
  isActive = NO;
}
- (void)activate
{
  NSDictionary *res;
  NSNumber     *rate = [NSNumber numberWithFloat:modeRate];
  
  res = [NSDictionary dictionaryWithObjectsAndKeys:
                        outputName, @"Name",
                      NSStringFromSize(modeSize), @"Dimensions",
                      rate, @"Rate",
                      nil];
  [self setResolution:res origin:frame.origin];
  isActive = YES;
}

// TODO
- (BOOL)isBuiltin
{
  return NO;
}

- (BOOL)isMain
{
  if (XRRGetOutputPrimary(xDisplay, RootWindow(xDisplay, DefaultScreen(xDisplay)))
      == output_id)
    {
      return YES;
    }
  
  return NO;
}

- (void)setMain:(BOOL)yn
{
  if (isMain && yn == NO)
    {
      XRRSetOutputPrimary(xDisplay,
                          RootWindow(xDisplay, DefaultScreen(xDisplay)),
                          None);
      isMain = NO;
    }
  
  if (yn == YES)
    {
      XRRSetOutputPrimary(xDisplay,
                          RootWindow(xDisplay, DefaultScreen(xDisplay)),
                          output_id);
      isMain = YES;
    }
}

//------------------------------------------------------------------------------
//--- Gamma correction, brightness
//------------------------------------------------------------------------------

/* Returns the index of the last value in an array < 0xffff */
// from xrandr.c
static int
find_last_non_clamped(CARD16 array[], int size)
{
  int i;
  for (i = size - 1; i > 0; i--)
    {
      if (array[i] < 0xffff)
        return i;
    }
  return 0;
}

// from xrandr.c
- (void)_getGamma
{
  // XRRScreenResources *screen_resources = [screen randrScreenResources];
  XRROutputInfo      *output_info;
  XRRCrtcGamma	     *crtc_gamma;
  CGFloat            i1, v1, i2, v2;
  int                size, middle, last_best, last_red, last_green, last_blue;
  CARD16             *best_array;

  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output_id);

  // Default values
  gammaValue.red = 1.0;
  gammaValue.green = 1.0;
  gammaValue.blue = 1.0;
  gammaBrightness = 1.0;
  
  if (!output_info->crtc)
    {
      return;
    }

  size = XRRGetCrtcGammaSize(xDisplay, output_info->crtc);
  if (!size)
    {
      NSLog(@"NXDisplay: Failed to get size of gamma for output %s",
            output_info->name);
      return;
    }

  crtc_gamma = XRRGetCrtcGamma(xDisplay, output_info->crtc);
  if (!crtc_gamma)
    {
      NSLog(@"NXDisplay: Failed to get gamma for output %s", output_info->name);
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
  if (last_green > last_best)
    {
      last_best = last_green;
      best_array = crtc_gamma->green;
    }
  if (last_blue > last_best)
    {
      last_best = last_blue;
      best_array = crtc_gamma->blue;
    }
  if (last_best == 0)
    {
      last_best = 1;
    }

  middle = last_best / 2;
  i1 = (CGFloat)(middle + 1) / size;
  v1 = (CGFloat)(best_array[middle]) / 65535;
  i2 = (CGFloat)(last_best + 1) / size;
  v2 = (CGFloat)(best_array[last_best]) / 65535;
  if (v2 < 0.0001)
    { /* The screen is black */
      gammaBrightness = 0;
    }
  else
    {
      if ((last_best + 1) == size)
        {
          gammaBrightness = v2;
        }
      else
        {
          gammaBrightness = exp((log(v2)*log(i1) - log(v1)*log(i2))/log(i1/i2));
        }
      gammaValue.red =
        log((CGFloat)(crtc_gamma->red[last_red/2])/gammaBrightness/65535)
        / log((CGFloat)((last_red/2) + 1) / size);
      gammaValue.green =
        log((CGFloat)(crtc_gamma->green[last_green/2])/gammaBrightness/65535)
        / log((CGFloat)((last_green/2) + 1) / size);
      gammaValue.blue =
        log((double)(crtc_gamma->blue[last_blue/2])/gammaBrightness/65535)
        / log((CGFloat)((last_blue / 2) + 1) / size);
    }

  XRRFreeGamma(crtc_gamma);  
}

//---
// gamma - monitor gamma, for example 0.8
// gamma correction - 1.0/gamma, e.g. 1.25

- (NSDictionary *)gammaDescription
{
  NSMutableDictionary *d = [[NSMutableDictionary alloc] init];

  [d setObject:[[NSNumber numberWithFloat:gammaValue.red] stringValue]
        forKey:@"Red"];
  [d setObject:[[NSNumber numberWithFloat:gammaValue.green] stringValue]
        forKey:@"Green"];
  [d setObject:[[NSNumber numberWithFloat:gammaValue.blue] stringValue]
        forKey:@"Blue"];
  [d setObject:[[NSNumber numberWithFloat:gammaBrightness] stringValue]
        forKey:@"Brightness"];

  return [d autorelease];
}

- (void)setGammaFromDescription:(NSDictionary *)gammaDict
{
  if (!gammaDict || !isActive)
    return;

  NSLog(@"setGammaFromDescription: %f : %f : %f",
        [[gammaDict objectForKey:@"Red"] floatValue],
        [[gammaDict objectForKey:@"Green"] floatValue],
        [[gammaDict objectForKey:@"Blue"] floatValue]);
  
  [self
    setGammaRed:[[gammaDict objectForKey:@"Red"] floatValue]
          green:[[gammaDict objectForKey:@"Green"] floatValue]
           blue:[[gammaDict objectForKey:@"Blue"] floatValue]
     brightness:[[gammaDict objectForKey:@"Brightness"] floatValue]];
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
  // XRRScreenResources *screen_resources = [screen randrScreenResources];
  XRROutputInfo      *output_info;
  XRRCrtcGamma       *gamma, *new_gamma;
  int                i, size;
   
  output_info = XRRGetOutputInfo(xDisplay, screen_resources, output_id);
  gamma = XRRGetCrtcGamma(xDisplay, output_info->crtc);
  size = gamma->size;
  new_gamma = XRRAllocGamma(size);

  gammaValue.red = (gammaRed == 0.0) ? 1.0 : gammaRed;
  gammaValue.green = (gammaGreen == 0.0) ? 1.0 : gammaGreen;
  gammaValue.blue = (gammaBlue == 0.0) ? 1.0 : gammaBlue;
  gammaBrightness = brightness;
  
  for (i = 0; i < size; i++)
    {
      if (gammaRed == 1.0 && brightness == 1.0)
        new_gamma->red[i] = (CGFloat)i / (CGFloat)(size - 1) * 65535.0;
      else
        new_gamma->red[i] = MIN(pow((CGFloat)i / (CGFloat)(size - 1),
                                    gammaValue.red)
                                * brightness, 1.0) * 65535.0;

      if (gammaGreen == 1.0 && brightness == 1.0)
        new_gamma->green[i] = (CGFloat)i / (CGFloat)(size - 1) * 65535.0;
      else
        new_gamma->green[i] = MIN(pow((CGFloat)i / (CGFloat)(size - 1),
                                      gammaValue.green)
                                  * brightness, 1.0) * 65535.0;

      if (gammaBlue == 1.0 && brightness == 1.0)
        new_gamma->blue[i] = (CGFloat)i / (CGFloat)(size - 1) * 65535.0;
      else
        new_gamma->blue[i] = MIN(pow((CGFloat)i / (CGFloat)(size - 1),
                                     gammaValue.blue)
                                 * brightness, 1.0) * 65535.0;
    }

  XRRSetCrtcGamma(xDisplay, output_info->crtc, new_gamma);
  XSync(xDisplay, False);
  
  XRRFreeGamma(new_gamma);
  XRRFreeOutputInfo(output_info);  
}

- (void)setGamma:(CGFloat)value
      brightness:(CGFloat)brightness
{
  [self setGammaRed:value
              green:value
               blue:value
         brightness:brightness];
}

- (void)setGamma:(CGFloat)value
{
  [self setGammaRed:value
              green:value
               blue:value
         brightness:gammaBrightness];
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

  // XGrabServer(xDisplay);
  
  for (float i=10; i >= 0; i--)
    {
      [self setGammaBrightness:brightness * (i/10)];
      usleep(30000);
    }
  
  // XUngrabServer(xDisplay);
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

  NSLog(@">>> Start fade to normal");

  CGFloat    secs = 0.5;
  NSUInteger msecs = secs * 1000000;
  NSUInteger steps = ceil(msecs / 30000);
  // NSUInteger msecs_step = msecs / steps;

  for (float i=0; i <= steps; i++)
    {
      [self setGammaBrightness:brightness * (i/steps)];
      usleep(30000);
    }
  
  NSLog(@">>> End fade to normal");

  // XUngrabServer(xDisplay);
}

- (void)fadeTo:(NSInteger)mode     // now ignored
      interval:(CGFloat)seconds    // in seconds, mininmum 0.1
    brightness:(CGFloat)brightness // original brightness
{
  if (![self isActive])
    return;
  
  NSLog(@">>> Start fade");

  NSUInteger msecs = seconds * 1000000;
  NSUInteger steps = ceil(msecs / 30000);
  float      i;
  
  i = 1;
  while (i <= steps)
    {
      if (mode) // to normal
        [self setGammaBrightness:brightness * (i/steps)];
      else	// to black
        [self setGammaBrightness:brightness * (i/steps)];
      
      usleep(30000);
      i++;
    }
  
  NSLog(@">>> End fade");

  // XUngrabServer(xDisplay);
}

//------------------------------------------------------------------------------
//--- Display properties
//------------------------------------------------------------------------------

XRRModeInfo getModeInfoForMode(Display *dpy,
                               XRRScreenResources *xrrs,
                               RRMode mode)
{
  XRRModeInfo rrMode;

  for (int i=0; i<xrrs->nmode; i++)
    {
      rrMode = xrrs->modes[i];
      if (rrMode.id == mode) break;
    }
  
  return rrMode;
}

id
property_value(Display *dpy,
               int value_format, /* 8, 16, 32 */
               Atom value_type,  /* XA_{ATOM,INTEGER,CARDINAL} */
               const void *value_bytes)
{
  char *str = NULL;
  id   aValue = @"?";
  if (value_type == XA_ATOM && value_format == 32)
    {
      const Atom *val = value_bytes;
      aValue = [NSString stringWithCString:XGetAtomName(dpy, *val)];
    }

  if (value_type == XA_INTEGER)
    {
      if (value_format == 8)
        {
          const int8_t *val = value_bytes;
          // printf ("%" PRId8, *val);
          aValue = [NSNumber numberWithChar:*val];
        }
      if (value_format == 16)
        {
          const int16_t *val = value_bytes;
          // printf ("%" PRId16, *val);
          aValue = [NSNumber numberWithShort:*val];
        }
      if (value_format == 32)
        {
          const int32_t *val = value_bytes;
          // printf ("%" PRId32, *val);
          aValue = [NSNumber numberWithInt:*val];
        }
    }

  if (value_type == XA_CARDINAL)
    {
      if (value_format == 8)
        {
          const uint8_t *val = value_bytes;
          // printf ("%" PRIu8, *val);
          aValue = [NSNumber numberWithUnsignedChar:*val];
        }
      if (value_format == 16)
        {
          const uint16_t *val = value_bytes;
          // printf ("%" PRIu16, *val);
          aValue = [NSNumber numberWithUnsignedShort:*val];
        }
      if (value_format == 32)
        {
          const uint32_t *val = value_bytes;
          // printf ("%" PRIu32, *val);
          aValue = [NSNumber numberWithUnsignedInt:*val];
        }
    }

  return aValue;
}

- (void)parseProperties
{
  Atom			*output_props;
  int			nprops;
  Atom			actual_type;
  int			actual_format;
  unsigned long		bytes_after;
  unsigned long		nitems;
  unsigned char		*prop;
  char			*atom_name;
  XRRPropertyInfo	*prop_info;
  
  NSMutableDictionary	*valueDict;
  NSMutableArray	*value;
  NSMutableArray	*variants;

  if (properties == nil)
    {
      properties = [[NSMutableDictionary alloc] init];
    }
  
  output_props = XRRListOutputProperties(xDisplay, output_id, &nprops);
  
  // fprintf(stderr, "properties(%i):\n", nprops);
  for (int k=0; k<nprops; k++)
    {
      XRRGetOutputProperty(xDisplay, output_id,
			   output_props[k], // Atom
			   0,               // long offset,
			   128,             // long length,
			   false,           // Bool _delete,
			   false,           // Bool pending,
			   AnyPropertyType, // Atom req_type,
			   &actual_type,    // Atom *actual_type,
			   &actual_format,  // int *actual_format,
			   &nitems,         // unsigned long *nitems,
			   &bytes_after,    // unsigned long *bytes_after,
			   &prop);          // unsigned char **

      // Name
      atom_name = XGetAtomName(xDisplay, output_props[k]);
      
      if (!strcmp(atom_name, "EDID") && nitems > 1)
        {
          [properties setObject:[NSData dataWithBytes:prop length:128]
                         forKey:@"EDID"];
        }
      else
        {
          valueDict = [[NSMutableDictionary alloc] init];
          
          // Value
          {
            int bytes_per_item = actual_format / 8;
            
            value = [[NSMutableArray alloc] init];
            for (int i=0; i<(int)nitems; i++)
              {
                [value addObject:property_value(xDisplay,
                                                actual_format,
                                                actual_type,
                                                prop + (i * bytes_per_item))];
              }
            [valueDict setObject:value forKey:@"Value"];
            [value release];
          }

          prop_info = XRRQueryOutputProperty(xDisplay, output_id, output_props[k]);

          // Range of values
          if (prop_info->range && prop_info->num_values > 0)
            {
              NSRange range;
              NSNumber *start, *end;
              
              for (int j = 0; j < prop_info->num_values / 2; j++)
                {
                  start =
                    property_value(xDisplay, 32, actual_type,
                                   (unsigned char *) &(prop_info->values[j*2]));
                  end =
                    property_value(xDisplay, 32, actual_type,
                                   (unsigned char *) &(prop_info->values[j*2+1]));
                }
              range = NSMakeRange([start unsignedIntValue],
                                  [end unsignedIntValue]);
              [valueDict setObject:NSStringFromRange(range)
                            forKey:@"Range"];
            }

          // Supported values
          if (!prop_info->range && prop_info->num_values > 0)
            {
              id vv;
              variants = [[NSMutableArray alloc] init];
              
              for (int j = 0; j < prop_info->num_values; j++)
                {
                  vv = property_value(xDisplay, 32, actual_type,
                                      (unsigned char *) &(prop_info->values[j]));
                  [variants addObject:vv];
                }
              [valueDict setObject:variants forKey:@"Supported"];
              [variants release];
            }
          
          [properties setObject:valueDict
                         forKey:[NSString stringWithCString:(char *)atom_name]];
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

  if ([displayID length] < 1)
    {
      displayID = @" ";
    }
  
  return displayID;
}

@end
