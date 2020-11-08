#ifndef _WAPPRESOURCE_H_
#define _WAPPRESOURCE_H_

#include <WINGs/wpixmap.h>

/* ---[ WINGs/wappresource.c ]-------------------------------------------- */

void WMSetApplicationIconImage(WMScreen *app, RImage *image);

RImage* WMGetApplicationIconImage(WMScreen *app);

void WMSetApplicationIconPixmap(WMScreen *app, WMPixmap *icon);

WMPixmap* WMGetApplicationIconPixmap(WMScreen *app);

/* If color==NULL it will use the default color for panels: ae/aa/ae */
WMPixmap* WMCreateApplicationIconBlendedPixmap(WMScreen *scr, const RColor *color);

void WMSetApplicationIconWindow(WMScreen *scr, Window window);

#endif
