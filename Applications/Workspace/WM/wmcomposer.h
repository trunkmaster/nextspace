#include <X11/Xlib.h>

Bool wComposerInitialize();
void wComposerRunLoop();
void wComposerProcessEvent(XEvent ev);
Bool wComposerErrorHandler(Display *dpy, XErrorEvent *ev);