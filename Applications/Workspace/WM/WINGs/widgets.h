#ifndef _WWIDGETS_H_
#define _WWIDGETS_H_

#include "WINGs.h"

#define WC_UserWidget	128

#define CHECK_CLASS(widget, class) assert(W_CLASS(widget)==(class))

#define W_CLASS(widget)  	(((W_WidgetType*)(widget))->widgetClass)
#define W_VIEW(widget)   	(((W_WidgetType*)(widget))->view)

/* -- Functions -- */

W_Class W_RegisterUserWidget(void);

/* ---[ WINGs/widgets.c ]------------------------------------------------- */

WMScreen* WMOpenScreen(const char *display);

WMScreen* WMCreateScreenWithRContext(Display *display, int screen,
                                     RContext *context);

WMScreen* WMCreateScreen(Display *display, int screen);

WMScreen* WMCreateSimpleApplicationScreen(Display *display);

void WMScreenMainLoop(WMScreen *scr);
//_wings_noreturn void WMScreenMainLoop(WMScreen *scr);

void WMBreakModalLoop(WMScreen *scr);

void WMRunModalLoop(WMScreen *scr, WMView *view);

RContext* WMScreenRContext(WMScreen *scr);

Display* WMScreenDisplay(WMScreen *scr);

int WMScreenDepth(WMScreen *scr);

void WMSetFocusToWidget(WMWidget *widget);

//---

WMScreen* WMWidgetScreen(WMWidget *w);

unsigned int WMScreenWidth(WMScreen *scr);

unsigned int WMScreenHeight(WMScreen *scr);

void WMUnmapWidget(WMWidget *w);

void WMMapWidget(WMWidget *w);

Bool WMWidgetIsMapped(WMWidget *w);

void WMRaiseWidget(WMWidget *w);

void WMLowerWidget(WMWidget *w);

void WMMoveWidget(WMWidget *w, int x, int y);

void WMResizeWidget(WMWidget *w, unsigned int width, unsigned int height);

void WMSetWidgetBackgroundColor(WMWidget *w, WMColor *color);

WMColor* WMGetWidgetBackgroundColor(WMWidget *w);

void WMSetWidgetBackgroundPixmap(WMWidget *w, WMPixmap *pix);

WMPixmap *WMGetWidgetBackgroundPixmap(WMWidget *w);

void WMMapSubwidgets(WMWidget *w);

void WMUnmapSubwidgets(WMWidget *w);

void WMRealizeWidget(WMWidget *w);

void WMReparentWidget(WMWidget *w, WMWidget *newParent, int x, int y);

void WMDestroyWidget(WMWidget *widget);

void WMHangData(WMWidget *widget, void *data);

void* WMGetHangedData(WMWidget *widget);

unsigned int WMWidgetWidth(WMWidget *w);

unsigned int WMWidgetHeight(WMWidget *w);

Window WMWidgetXID(WMWidget *w);

void WMRedisplayWidget(WMWidget *w);

#endif
