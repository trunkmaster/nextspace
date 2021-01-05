#ifndef __WORKSPACE_WM_WLABEL__
#define __WORKSPACE_WM_WLABEL__

#include "wfont.h"

typedef struct W_Label {
	W_Class widgetClass;
	W_View *view;

	char *caption;

	WMColor *textColor;
	WMFont *font;		/* if NULL, use default */

	W_Pixmap *image;

	struct {
		WMReliefType relief:3;
		WMImagePosition imagePosition:4;
		WMAlignment alignment:2;

		unsigned int noWrap:1;

		unsigned int redrawPending:1;
	} flags;
} W_Label;
typedef struct W_Label WMLabel;

/* ---[ WINGs/wlabel.c ]-------------------------------------------------- */

WMLabel* WMCreateLabel(WMWidget *parent);

void WMSetLabelWraps(WMLabel *lPtr, Bool flag);

void WMSetLabelImage(WMLabel *lPtr, WMPixmap *image);

WMPixmap* WMGetLabelImage(WMLabel *lPtr);

char* WMGetLabelText(WMLabel *lPtr);

void WMSetLabelImagePosition(WMLabel *lPtr, WMImagePosition position);

void WMSetLabelTextAlignment(WMLabel *lPtr, WMAlignment alignment);

void WMSetLabelRelief(WMLabel *lPtr, WMReliefType relief);

void WMSetLabelText(WMLabel *lPtr, const char *text);

WMFont* WMGetLabelFont(WMLabel *lPtr);

void WMSetLabelFont(WMLabel *lPtr, WMFont *font);

void WMSetLabelTextColor(WMLabel *lPtr, WMColor *color);

#endif
