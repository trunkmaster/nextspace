/*
 */
#include "wraster.h"
#include "x11/XGServer.h"

@interface XGScreenContext : NSObject {
  RContext *rcontext;
  XGDrawMechanism drawMechanism;
}

- initForDisplay:(Display *)dpy screen:(int)screen_id;
- (XGDrawMechanism)drawMechanism;
- (RContext *)context;
@end
