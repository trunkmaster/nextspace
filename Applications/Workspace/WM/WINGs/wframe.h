#ifndef _WFRAME_H_
#define _WFRAME_H_

typedef struct W_Frame {
	W_Class widgetClass;
	W_View *view;

	char *caption;
	WMColor *textColor;

	struct {
		WMReliefType relief:4;
		WMTitlePosition titlePosition:4;
	} flags;
} W_Frame;
typedef struct W_Frame WMFrame;

/* ---[ WINGs/wframe.c ]-------------------------------------------------- */

WMFrame* WMCreateFrame(WMWidget *parent);

void WMSetFrameTitlePosition(WMFrame *fPtr, WMTitlePosition position);

void WMSetFrameRelief(WMFrame *fPtr, WMReliefType relief);

void WMSetFrameTitle(WMFrame *fPtr, const char *title);

void WMSetFrameTitleColor(WMFrame *fPtr, WMColor *color);

#endif
