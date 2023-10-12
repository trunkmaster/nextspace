#include <X11/Xlib.h>

Bool wComposerInitialize();
void wComposerRunLoop();
Bool wComposerErrorHandler(Display *dpy, XErrorEvent *ev);