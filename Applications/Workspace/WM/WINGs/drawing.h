#ifndef __WORKSPACE_WM_DRAWING__
#define __WORKSPACE_WM_DRAWING__

#define DOUBLE_BUFFER   1

typedef struct {
    int x;
    int y;
} WMPoint;

typedef struct {
    unsigned int width;
    unsigned int height;
} WMSize;

typedef struct {
    WMPoint pos;
    WMSize size;
} WMRect;

/* #include <WINGs/WINGs.h> */
#include <WINGs/wview.h>
#include <WINGs/wfont.h>

/* relief types */
typedef enum {
    WRFlat,
    WRSimple,
    WRRaised,
    WRSunken,
    WRGroove,
    WRRidge,
    WRPushed
} WMReliefType;

/* alignment types */
typedef enum {
    WALeft,
    WACenter,
    WARight,
    WAJustified		       /* not valid for textfields */
} WMAlignment;

/* image position */
typedef enum {
    WIPNoImage,
    WIPImageOnly,
    WIPLeft,
    WIPRight,
    WIPBelow,
    WIPAbove,
    WIPOverlaps
} WMImagePosition;

void W_DrawRelief(W_Screen *scr, Drawable d, int x, int y, unsigned int width,
                  unsigned int height, WMReliefType relief);

void W_DrawReliefWithGC(W_Screen *scr, Drawable d, int x, int y,
                        unsigned int width, unsigned int height,
                        WMReliefType relief,
                        GC black, GC dark, GC light, GC white);

void W_PaintTextAndImage(W_View *view, int wrap, WMColor *textColor,
                         W_Font *font, WMReliefType relief, const char *text,
                         WMAlignment alignment, W_Pixmap *image,
                         WMImagePosition position, WMColor *backColor, int ofs);

void W_PaintText(W_View *view, Drawable d, WMFont *font,  int x, int y,
                 int width, WMAlignment alignment, WMColor *color,
                 int wrap, const char *text, int length);

int W_GetTextHeight(WMFont *font, const char *text, int width, int wrap);

WMPoint WMMakePoint(int x, int y);
WMSize WMMakeSize(unsigned int width, unsigned int height);
WMRect WMMakeRect(int x, int y, unsigned int width, unsigned int height);

#endif
