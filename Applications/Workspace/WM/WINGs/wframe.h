#ifndef _WFRAME_H_
#define _WFRAME_H_

/* ---[ WINGs/wframe.c ]-------------------------------------------------- */

WMFrame* WMCreateFrame(WMWidget *parent);

void WMSetFrameTitlePosition(WMFrame *fPtr, WMTitlePosition position);

void WMSetFrameRelief(WMFrame *fPtr, WMReliefType relief);

void WMSetFrameTitle(WMFrame *fPtr, const char *title);

void WMSetFrameTitleColor(WMFrame *fPtr, WMColor *color);

#endif
