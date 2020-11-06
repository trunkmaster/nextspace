#ifndef _WWINDOW_H_
#define _WWINDOW_H_

/* ---[ WINGs/wwindow.c ]------------------------------------------------- */

WMWindow* WMCreateWindow(WMScreen *screen, const char *name);

WMWindow* WMCreateWindowWithStyle(WMScreen *screen, const char *name, int style);

WMWindow* WMCreatePanelWithStyleForWindow(WMWindow *owner, const char *name,
                                          int style);

WMWindow* WMCreatePanelForWindow(WMWindow *owner, const char *name);

void WMChangePanelOwner(WMWindow *win, WMWindow *newOwner);

void WMSetWindowTitle(WMWindow *wPtr, const char *title);

void WMSetWindowMiniwindowTitle(WMWindow *win, const char *title);

void WMSetWindowMiniwindowImage(WMWindow *win, RImage *image);

void WMSetWindowMiniwindowPixmap(WMWindow *win, WMPixmap *pixmap);

void WMSetWindowCloseAction(WMWindow *win, WMAction *action, void *clientData);

void WMSetWindowInitialPosition(WMWindow *win, int x, int y);

void WMSetWindowUserPosition(WMWindow *win, int x, int y);

void WMSetWindowAspectRatio(WMWindow *win, int minX, int minY,
                            int maxX, int maxY);

void WMSetWindowMaxSize(WMWindow *win, unsigned width, unsigned height);

void WMSetWindowMinSize(WMWindow *win, unsigned width, unsigned height);

void WMSetWindowBaseSize(WMWindow *win, unsigned width, unsigned height);

void WMSetWindowResizeIncrements(WMWindow *win, unsigned wIncr, unsigned hIncr);

void WMSetWindowLevel(WMWindow *win, int level);

void WMSetWindowDocumentEdited(WMWindow *win, Bool flag);

void WMCloseWindow(WMWindow *win);

#endif
