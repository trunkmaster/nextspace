#ifndef __WORKSPACE_WM_WCOLOR__
#define __WORKSPACE_WM_WCOLOR__

typedef struct W_Color {
    struct W_Screen *screen;

    XColor color;
    unsigned short alpha;
    short refCount;
    GC gc;
    struct {
        unsigned int exact:1;
    } flags;
} W_Color;

#define W_PIXEL(c)		(c)->color.pixel

/* ---[ WINGs/wcolor.c ]-------------------------------------------------- */

WMColor* WMDarkGrayColor(WMScreen *scr);

WMColor* WMGrayColor(WMScreen *scr);

WMColor* WMBlackColor(WMScreen *scr);

WMColor* WMWhiteColor(WMScreen *scr);

void WMSetColorInGC(WMColor *color, GC gc);

GC WMColorGC(WMColor *color);

WMPixel WMColorPixel(WMColor *color);

void WMPaintColorSwatch(WMColor *color, Drawable d, int x, int y,
                        unsigned int width, unsigned int height);

void WMReleaseColor(WMColor *color);

WMColor* WMRetainColor(WMColor *color);

WMColor* WMCreateRGBColor(WMScreen *scr, unsigned short red,
                          unsigned short green, unsigned short blue,
                          Bool exact);

WMColor* WMCreateRGBAColor(WMScreen *scr, unsigned short red,
                           unsigned short green, unsigned short blue,
                           unsigned short alpha, Bool exact);

WMColor* WMCreateNamedColor(WMScreen *scr, const char *name, Bool exact);

RColor WMGetRColorFromColor(WMColor *color);

void WMSetColorAlpha(WMColor *color, unsigned short alpha);

unsigned short WMRedComponentOfColor(WMColor *color);

unsigned short WMGreenComponentOfColor(WMColor *color);

unsigned short WMBlueComponentOfColor(WMColor *color);

unsigned short WMGetColorAlpha(WMColor *color);

char* WMGetColorRGBDescription(WMColor *color);

#endif
