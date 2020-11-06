#ifndef _WFONT_H_
#define _WFONT_H_

typedef struct W_Font {
    struct W_Screen *screen;

    struct _XftFont *font;

    short height;
    short y;
    short refCount;
    char *name;

#ifdef USE_PANGO
    PangoLayout *layout;
#endif
} W_Font;

#define W_FONTID(f)		(f)->font->fid

/* ---[ WINGs/wfont.c ]--------------------------------------------------- */

/* Basic font styles. Used to easily get one style from another */
typedef enum WMFontStyle {
  WFSNormal = 0,
  WFSBold = 1,
  WFSItalic = 2,
  WFSBoldItalic = 3
} WMFontStyle;

Bool WMIsAntialiasingEnabled(WMScreen *scrPtr);

WMFont* WMCreateFont(WMScreen *scrPtr, const char *fontName);

WMFont* WMCopyFontWithStyle(WMScreen *scrPtr, WMFont *font, WMFontStyle style);

WMFont* WMRetainFont(WMFont *font);

void WMReleaseFont(WMFont *font);

char* WMGetFontName(WMFont *font);

unsigned int WMFontHeight(WMFont *font);

void WMSetWidgetDefaultFont(WMScreen *scr, WMFont *font);

void WMSetWidgetDefaultBoldFont(WMScreen *scr, WMFont *font);

WMFont* WMDefaultSystemFont(WMScreen *scrPtr);

WMFont* WMDefaultBoldSystemFont(WMScreen *scrPtr);

WMFont* WMSystemFontOfSize(WMScreen *scrPtr, int size);

WMFont* WMBoldSystemFontOfSize(WMScreen *scrPtr, int size);

void WMDrawString(WMScreen *scr, Drawable d, WMColor *color, WMFont *font,
                  int x, int y, const char *text, int length);

void WMDrawImageString(WMScreen *scr, Drawable d, WMColor *color,
                       WMColor *background, WMFont *font, int x, int y,
                       const char *text, int length);

int WMWidthOfString(WMFont *font, const char *text, int length);

#endif
