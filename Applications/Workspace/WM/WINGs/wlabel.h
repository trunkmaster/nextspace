#ifndef _WLABEL_H_
#define _WLABEL_H_

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
