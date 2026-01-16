/*
 */
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSDebug.h>

#import "XGScreenContext.h"

@implementation XGScreenContext

- (RContextAttributes *)_getXDefaults
{
  int dummy;
  RContextAttributes *attribs;

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  attribs = (RContextAttributes *)malloc(sizeof(RContextAttributes));

  attribs->flags = 0;
  if ([defaults boolForKey:@"NSDefaultVisual"])
    attribs->flags |= RC_DefaultVisual;
  if ((dummy = [defaults integerForKey:@"NSDefaultVisual"])) {
    attribs->flags |= RC_VisualID;
    attribs->visualid = dummy;
  }
  if ((dummy = [defaults integerForKey:@"NSColorsPerChannel"])) {
    attribs->flags |= RC_ColorsPerChannel;
    attribs->colors_per_channel = dummy;
  }

  return attribs;
}

- initForDisplay:(Display *)dpy screen:(int)screen_id
{
  RContextAttributes *attribs;
  XColor testColor;
  unsigned char r, g, b;

  /* Get the visual information */
  attribs = NULL;
  // attribs = [self _getXDefaults];
  rcontext = RCreateContext(dpy, screen_id, attribs);

  /*
   * If we have shared memory available, only use it when the XGPS-Shm
   * default is set to YES
   */
  if (rcontext->attribs->use_shared_memory == True &&
      [[NSUserDefaults standardUserDefaults] boolForKey:@"XGPS-Shm"] != YES)
    rcontext->attribs->use_shared_memory = False;

  /*
   *        Crude tests to see if we can accelerate creation of pixels from
   *        8-bit red, green and blue color values.
   */
  if (rcontext->depth == 12 || rcontext->depth == 16) {
    drawMechanism = XGDM_FAST16;
    r = 8;
    g = 9;
    b = 7;
    testColor.pixel = (((r << 5) + g) << 6) + b;
    XQueryColor(rcontext->dpy, rcontext->cmap, &testColor);
    if (((testColor.red >> 11) != r) || ((testColor.green >> 11) != g) ||
        ((testColor.blue >> 11) != b)) {
      NSLog(@"WARNING - XGServer is unable to use the "
            @"fast algorithm for writing to a 16-bit display on "
            @"this host - perhaps you'd like to adjust the code "
            @"to work ... and submit a patch.");
      drawMechanism = XGDM_PORTABLE;
    }
  } else if (rcontext->depth == 15) {
    drawMechanism = XGDM_FAST15;
    r = 8;
    g = 9;
    b = 7;
    testColor.pixel = (((r << 5) + g) << 5) + b;
    XQueryColor(rcontext->dpy, rcontext->cmap, &testColor);
    if (((testColor.red >> 11) != r) || ((testColor.green >> 11) != g) ||
        ((testColor.blue >> 11) != b)) {
      NSLog(@"WARNING - XGServer is unable to use the "
            @"fast algorithm for writing to a 15-bit display on "
            @"this host - perhaps you'd like to adjust the code "
            @"to work ... and submit a patch.");
      drawMechanism = XGDM_PORTABLE;
    }
  } else if (rcontext->depth == 24 || rcontext->depth == 32) {
    drawMechanism = XGDM_FAST32;
    r = 32;
    g = 33;
    b = 31;
    testColor.pixel = (((r << 8) + g) << 8) + b;
    XQueryColor(rcontext->dpy, rcontext->cmap, &testColor);
    if (((testColor.red >> 8) == r) && ((testColor.green >> 8) == g) &&
        ((testColor.blue >> 8) == b)) {
      drawMechanism = XGDM_FAST32;
    } else if (((testColor.red >> 8) == b) && ((testColor.green >> 8) == g) &&
               ((testColor.blue >> 8) == r)) {
      drawMechanism = XGDM_FAST32_BGR;
    } else {
      NSLog(@"WARNING - XGServer is unable to use the "
            @"fast algorithm for writing to a 32-bit display on "
            @"this host - perhaps you'd like to adjust the code "
            @"to work ... and submit a patch.");
      drawMechanism = XGDM_PORTABLE;
    }
  } else if (rcontext->depth == 8) {
    drawMechanism = XGDM_FAST8;
    r = 2;
    g = 3;
    b = 1;
    testColor.pixel = (((r << 3) + g) << 2) + b;
    XQueryColor(rcontext->dpy, rcontext->cmap, &testColor);
    if (((testColor.red >> 13) != r) || ((testColor.green >> 13) != g) ||
        ((testColor.blue >> 14) != b)) {
      NSLog(@"WARNING - XGServer is unable to use the "
            @"fast algorithm for writing to an 8-bit display on "
            @"this host - the most likely reason being "
            @"the StandardColormap RGB_BEST_MAP has not been installed.");
      drawMechanism = XGDM_PORTABLE;
    }
  } else {
    NSLog(@"WARNING - XGServer is unable to use a "
          @"fast algorithm for writing to the display on "
          @"this host - perhaps you'd like to adjust the code "
          @"to work ... and submit a patch.");
    drawMechanism = XGDM_PORTABLE;
  }
  NSDebugLLog(@"XGTrace", @"Draw mech %d for screen %d", drawMechanism, screen_id);
  return self;
}

- (void)dealloc
{
#ifndef HAVE_WRASTER_H
  // FIXME: context.c does not include a clean up function for Rcontext,
  // so we try do it here.

  /*
    Note that this can be done only when we use our own version of wraster.
    If we're using an external version of wraster, the rcontext structure
    might be different (different fields, or differently used fields), which
    breaks this code.
  */

  if (rcontext) {
    XFreeGC(rcontext->dpy, rcontext->copy_gc);
    if (rcontext->drawable) {
      XDestroyWindow(rcontext->dpy, rcontext->drawable);
    }
    if (rcontext->pixels) {
      free(rcontext->pixels);
    }
    if (rcontext->colors) {
      free(rcontext->colors);
    }
    if (rcontext->hermes_data) {
      free(rcontext->hermes_data);
    }
    free(rcontext->attribs);
    free(rcontext);
  }
#endif
  [super dealloc];
}

- (XGDrawMechanism)drawMechanism
{
  return drawMechanism;
}

- (RContext *)context
{
  return rcontext;
}

@end
