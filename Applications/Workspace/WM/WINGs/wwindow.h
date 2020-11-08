#ifndef _WWINDOW_H_
#define _WWINDOW_H_

/* self is set to the widget from where the callback is being called and
 * clientData to the data set to with WMSetClientData() */
typedef void WMAction(WMWidget *self, void *clientData);
/* same as WMAction, but for stuff that arent widgets */
typedef void WMAction2(void *self, void *clientData);

typedef struct W_Window {
	W_Class widgetClass;
	W_View *view;

	struct W_Window *nextPtr;	/* next in the window list */

	struct W_Window *owner;

	char *title;

	WMPixmap *miniImage;	/* miniwindow */
	char *miniTitle;

	char *wname;

	WMSize resizeIncrement;
	WMSize baseSize;
	WMSize minSize;
	WMSize maxSize;
	WMPoint minAspect;
	WMPoint maxAspect;

	WMPoint upos;
	WMPoint ppos;

	WMAction *closeAction;
	void *closeData;

	int level;

	struct {
		unsigned style:4;
		unsigned configured:1;
		unsigned documentEdited:1;

		unsigned setUPos:1;
		unsigned setPPos:1;
		unsigned setAspect:1;
	} flags;
} W_Window;
typedef struct W_Window WMWindow;

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
