#ifndef _WVIEW_H_
#define _WVIEW_H_

typedef struct W_ViewDelegate {
    void *data;
    void (*didMove)(struct W_ViewDelegate*, WMView*);
    void (*didResize)(struct W_ViewDelegate*, WMView*);
    void (*willMove)(struct W_ViewDelegate*, WMView*, int*, int*);
    void (*willResize)(struct W_ViewDelegate*, WMView*,
                       unsigned int*, unsigned int*);
} W_ViewDelegate;

struct W_View {
    struct W_Screen *screen;

    WMWidget *self;     /* must point to the widget the view belongs to */

    W_ViewDelegate *delegate;

    Window window;

    WMSize size;

    short topOffs;
    short leftOffs;
    short bottomOffs;
    short rightOffs;

    WMPoint pos;

    struct W_View *nextFocusChain;     /* next/prev in focus chain */
    struct W_View *prevFocusChain;

    struct W_View *nextResponder;      /* next to receive keyboard events */

    struct W_View *parent;             /* parent WMView */

    struct W_View *childrenList;       /* first in list of child windows */

    struct W_View *nextSister;         /* next on parent's children list */

    WMArray *eventHandlers;            /* event handlers for this window */

    unsigned long attribFlags;
    XSetWindowAttributes attribs;

    void *hangedData;                  /* data holder for user program */

    WMColor *backColor;
    WMPixmap *backImage;


    Cursor cursor;

    Atom *droppableTypes;
    struct W_DragSourceProcs      *dragSourceProcs;
    struct W_DragDestinationProcs *dragDestinationProcs;
    WMPixmap *dragImage;
    int helpContext;

    XIC xic;

    struct {
        unsigned int realized:1;
        unsigned int mapped:1;
        unsigned int parentDying:1;
        unsigned int dying:1;           /* the view is being destroyed */
        unsigned int topLevel:1;        /* is a top level window */
        unsigned int root:1;            /* is the root window */
        unsigned int mapWhenRealized:1; /* map the view when it's realized */
        unsigned int alreadyDead:1;     /* view was freed */

        unsigned int dontCompressMotion:1; /* motion notify event compress */
        unsigned int notifySizeChanged:1;
        unsigned int dontCompressExpose:1; /* expose event compress */

        /* toplevel only */
        unsigned int worksWhenModal:1;
        unsigned int pendingRelease1:1;
        unsigned int pendingRelease2:1;
        unsigned int pendingRelease3:1;
        unsigned int pendingRelease4:1;
        unsigned int pendingRelease5:1;
        unsigned int xdndHintSet:1;
    } flags;

    int refCount;
};
typedef struct W_View W_View;

#define W_VIEW_REALIZED(view)	(view)->flags.realized
#define W_VIEW_MAPPED(view)	(view)->flags.mapped

#define W_VIEW_DISPLAY(view)    (view)->screen->display
#define W_VIEW_SCREEN(view)	(view)->screen
#define W_VIEW_DRAWABLE(view)	(view)->window

#define W_VIEW_WIDTH(view)	(view)->size.width
#define W_VIEW_HEIGHT(view)	(view)->size.height

/* -- Functions -- */

W_View *W_GetViewForXWindow(Display *display, Window window);

W_View *W_CreateView(W_View *parent);

W_View *W_CreateTopView(W_Screen *screen);

W_View *W_CreateUnmanagedTopView(W_Screen *screen);

W_View *W_CreateRootView(W_Screen *screen);

void W_DestroyView(W_View *view);

void W_RealizeView(W_View *view);

void W_RedisplayView(WMView *view);

void W_ReparentView(W_View *view, W_View *newParent, int x, int y);

void W_RaiseView(W_View *view);

void W_LowerView(W_View *view);

void W_MapView(W_View *view);

void W_MapSubviews(W_View *view);

void W_UnmapSubviews(W_View *view);

W_View *W_TopLevelOfView(W_View *view);

void W_UnmapView(W_View *view);

WMView *W_RetainView(WMView *view);

void W_ReleaseView(WMView *view);

void W_MoveView(W_View *view, int x, int y);

void W_ResizeView(W_View *view, unsigned int width, unsigned int height);

void W_SetViewBackgroundColor(W_View *view, WMColor *color);

void W_SetViewBackgroundPixmap(W_View *view, WMPixmap *pix);

void W_SetViewCursor(W_View *view, Cursor cursor);

void W_SetFocusOfTopLevel(W_View *toplevel, W_View *view);

W_View *W_FocusedViewOfToplevel(W_View *view);

void W_BroadcastMessage(W_View *targetParent, XEvent *event);

void W_DispatchMessage(W_View *target, XEvent *event);

/* ---[ WINGs/wview.c ]--------------------------------------------------- */

Window WMViewXID(WMView *view);

void WMSetViewNotifySizeChanges(WMView *view, Bool flag);

void WMSetViewExpandsToParent(WMView *view, int topOffs, int leftOffs,
                              int rightOffs, int bottomOffs);

WMSize WMGetViewSize(WMView *view);

WMPoint WMGetViewPosition(WMView *view);

WMPoint WMGetViewScreenPosition(WMView *view);

WMWidget* WMWidgetOfView(WMView *view);

/* notifications */
extern char *WMViewSizeDidChangeNotification;
extern char *WMViewFocusDidChangeNotification;
extern char *WMViewRealizedNotification;

#endif
