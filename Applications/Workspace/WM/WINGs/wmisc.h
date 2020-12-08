#ifndef __WORKSPACE_WM_WMISC__
#define __WORKSPACE_WM_WMISC__

#include <WINGs/WINGs.h>
#include <WINGs/wview.h>
#include <WINGs/wfont.h>

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

/* ---[ WINGs/wmisc.c ]--------------------------------------------------- */

WMPoint wmkpoint(int x, int y);

WMSize wmksize(unsigned int width, unsigned int height);

WMRect wmkrect(int x, int y, unsigned int width, unsigned int height);

#ifdef ANSI_C_DOESNT_LIKE_IT_THIS_WAY
#define wmksize(width, height) (WMSize){(width), (height)}
#define wmkpoint(x, y)         (WMPoint){(x), (y)}
#endif

#endif
