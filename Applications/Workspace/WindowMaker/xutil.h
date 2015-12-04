

#ifndef _WM_XUTIL_H_
#define _WM_XUTIL_H_

void FormatXError(Display *dpy, XErrorEvent *error, char *buffer, int size);


void RequestSelection(Display *dpy, Window requestor, Time timestamp);


char *GetSelection(Display *dpy, Window requestor);


#endif
