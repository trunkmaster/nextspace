#ifndef _WINGSP_H_
#define _WINGSP_H_


#include <X11/Xlib.h>
#include <X11/Xutil.h>

#ifdef USE_PANGO
#include <pango/pango.h>
#endif

#include <WINGs/WINGs.h>

#if WINGS_H_VERSION < 20041030
#error There_is_an_old_WINGs.h_file_somewhere_in_your_system._Please_remove_it.
#endif

#include <assert.h>

#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/* ---[ global settigns ]------------------------------------------------- */

#define DOUBLE_BUFFER   1

#define SCROLLER_WIDTH	20

typedef struct _WINGsConfiguration {
    char *systemFont;
    char *boldSystemFont;
    int  defaultFontSize;
    Bool antialiasedText;
    char *floppyPath;
    unsigned doubleClickDelay;
    unsigned mouseWheelUp;
    unsigned mouseWheelDown;
} _WINGsConfiguration;

extern char *_WINGS_progname;
extern _WINGsConfiguration WINGsConfiguration;
extern struct W_Application WMApplication;


/* ---[ drag*.c ]--------------------------------------------------------- */

/*
 * We need to define these structure first because they are used in W_Screen
 * below. The rest of drag-related stuff if after because it needs W_Screen
 */
#define XDND_VERSION    3

typedef struct W_DraggingInfo {
    unsigned char protocolVersion; /* version supported on the other side */
    Time timestamp;

    Atom sourceAction;
    Atom destinationAction;

    struct W_DragSourceInfo* sourceInfo;    /* infos needed by source */
    struct W_DragDestinationInfo* destInfo; /* infos needed by destination */
} W_DraggingInfo;

/* ---[ Structures from WINGs.h ]----------------------------------------- */

/* Pre-definition of internal structs */
typedef struct W_Color W_Color;
typedef struct W_Pixmap W_Pixmap;
typedef struct W_View W_View;

typedef struct W_FocusInfo {
    W_View *toplevel;
    W_View *focused;    /* view that has the focus in this toplevel */
    struct W_FocusInfo *next;
} W_FocusInfo;

typedef struct W_Screen {
    Display *display;
    int screen;
    int depth;

    Colormap colormap;

    Visual *visual;

    Time lastEventTime;

    Window rootWin;

    W_View *rootView;

    RContext *rcontext;

    struct W_IMContext *imctx;

    struct _XftDraw *xftdraw;          /* shared XftDraw */

    /* application related */

    W_FocusInfo *focusInfo;

    RImage *applicationIconImage;      /* image (can have alpha channel) */
    W_Pixmap *applicationIconPixmap; /* pixmap - no alpha channel */
    Window applicationIconWindow;

    struct W_Window *windowList;       /* list of windows in the app */

    Window groupLeader;                /* the leader of the application */
                                       /* also used for other things */

    struct W_SelectionHandlers *selectionHandlerList;

    struct {
        unsigned int hasAppIcon:1;
        unsigned int simpleApplication:1;
    } aflags;

    WMOpenPanel *sharedOpenPanel;
    WMSavePanel *sharedSavePanel;

    struct W_FontPanel *sharedFontPanel;

    struct W_ColorPanel *sharedColorPanel;

    Pixmap stipple;

    W_View *dragSourceView;
    W_DraggingInfo dragInfo;

    /* colors */
    W_Color *white;
    W_Color *black;
    W_Color *gray;
    W_Color *darkGray;

    GC stippleGC;

    GC copyGC;
    GC clipGC;

    GC monoGC;                         /* GC for 1bpp visuals */

    GC xorGC;

    GC ixorGC;                         /* IncludeInferiors XOR */

    GC drawStringGC;                   /* for WMDrawString() */

    GC drawImStringGC;                 /* for WMDrawImageString() */

    struct W_Font *normalFont;

    struct W_Font *boldFont;

    WMHashTable *fontCache;

    Bool antialiasedText;

    unsigned int ignoredModifierMask; /* modifiers to ignore when typing txt */

    struct W_Balloon *balloon;


    W_Pixmap *checkButtonImageOn;
    W_Pixmap *checkButtonImageOff;

    W_Pixmap *radioButtonImageOn;
    W_Pixmap *radioButtonImageOff;

    W_Pixmap *buttonArrow;
    W_Pixmap *pushedButtonArrow;

    W_Pixmap *scrollerDimple;

    W_Pixmap *upArrow;
    W_Pixmap *downArrow;
    W_Pixmap *leftArrow;
    W_Pixmap *rightArrow;

    W_Pixmap *hiUpArrow;
    W_Pixmap *hiDownArrow;
    W_Pixmap *hiLeftArrow;
    W_Pixmap *hiRightArrow;

    W_Pixmap *pullDownIndicator;
    W_Pixmap *popUpIndicator;

    W_Pixmap *checkMark;

    W_Pixmap *homeIcon;
    W_Pixmap *altHomeIcon;

    W_Pixmap *trashcanIcon;
    W_Pixmap *altTrashcanIcon;

    W_Pixmap *createDirIcon;
    W_Pixmap *altCreateDirIcon;

    W_Pixmap *disketteIcon;
    W_Pixmap *altDisketteIcon;
    W_Pixmap *unmountIcon;
    W_Pixmap *altUnmountIcon;

    W_Pixmap *magnifyIcon;
    /*W_Pixmap *altMagnifyIcon;*/
    W_Pixmap *wheelIcon;
    W_Pixmap *grayIcon;
    W_Pixmap *rgbIcon;
    W_Pixmap *cmykIcon;
    W_Pixmap *hsbIcon;
    W_Pixmap *customPaletteIcon;
    W_Pixmap *colorListIcon;

    W_Pixmap *defaultObjectIcon;

    Cursor defaultCursor;

    Cursor textCursor;

    Cursor invisibleCursor;

    Atom attribsAtom;              /* GNUstepWindowAttributes */

    Atom deleteWindowAtom;         /* WM_DELETE_WINDOW */

    Atom protocolsAtom;            /* _XA_WM_PROTOCOLS */

    Atom clipboardAtom;            /* CLIPBOARD */

    Atom xdndAwareAtom;            /* XdndAware */
    Atom xdndSelectionAtom;
    Atom xdndEnterAtom;
    Atom xdndLeaveAtom;
    Atom xdndPositionAtom;
    Atom xdndDropAtom;
    Atom xdndFinishedAtom;
    Atom xdndTypeListAtom;
    Atom xdndActionListAtom;
    Atom xdndActionDescriptionAtom;
    Atom xdndStatusAtom;

    Atom xdndActionCopy;
    Atom xdndActionMove;
    Atom xdndActionLink;
    Atom xdndActionAsk;
    Atom xdndActionPrivate;

    Atom wmIconDragOffsetAtom;

    Atom wmStateAtom;              /* WM_STATE */
    
    Atom utf8String;

    Atom netwmName;
    Atom netwmIconName;
    Atom netwmIcon;

    /* stuff for detecting double-clicks */
    Time lastClickTime;            /* time of last mousedown event */
    Window lastClickWindow;        /* window of the last mousedown */

    struct W_View *modalView;
    unsigned modalLoop:1;
    unsigned ignoreNextDoubleClick:1;

    /*
     * New stuff in Window Maker 0.95.7
     * Added at the end of the structure to avoid breaking binary compatibility
     * with previous versions of the toolkit
     */
    W_Pixmap *tristateButtonImageOn;
    W_Pixmap *tristateButtonImageOff;
    W_Pixmap *tristateButtonImageTri;

} W_Screen;

#define W_DRAWABLE(scr)		(scr)->rcontext->drawable


/* ---[ configuration.c ]------------------------------------------------- */

void W_ReadConfigurations(void);


/* ---[ drag*.c ]--------------------------------------------------------- */

typedef struct W_DragOperationItem {
    WMDragOperationType type;
    char* text;
} W_DragOperationItem;

typedef void* W_DndState(WMView *destView, XClientMessageEvent *event,
                         WMDraggingInfo *info);

typedef struct W_DragSourceInfo {
    WMView *sourceView;
    Window destinationWindow;
    W_DndState *state;
    WMSelectionProcs *selectionProcs;
    Window icon;
    WMPoint imageLocation;
    WMPoint mouseOffset; /* mouse pos in icon */
    Cursor dragCursor;
    WMRect noPositionMessageZone;
    Atom firstThreeTypes[3];
} W_DragSourceInfo;

typedef struct W_DragDestinationInfo {
    WMView *destView;
    WMView *xdndAwareView;
    Window sourceWindow;
    W_DndState *state;
    Bool sourceActionChanged;
    WMArray *sourceTypes;
    WMArray *requiredTypes;
    Bool typeListAvailable;
    WMArray *dropDatas;
} W_DragDestinationInfo;

/* -- Functions -- */

void W_HandleDNDClientMessage(WMView *toplevel, XClientMessageEvent *event);

Atom W_OperationToAction(WMScreen *scr, WMDragOperationType operation);

WMDragOperationType W_ActionToOperation(WMScreen *scr, Atom action);

void W_FreeDragOperationItem(void* item);

Bool W_SendDnDClientMessage(Display *dpy, Window win, Atom message,
                            unsigned long data1, unsigned long data2,
                            unsigned long data3, unsigned long data4,
                            unsigned long data5);

void W_DragSourceStartTimer(WMDraggingInfo *info);

void W_DragSourceStopTimer(void);

void W_DragSourceStateHandler(WMDraggingInfo *info, XClientMessageEvent *event);

void W_DragDestinationStartTimer(WMDraggingInfo *info);

void W_DragDestinationStopTimer(void);

void W_DragDestinationStoreEnterMsgInfo(WMDraggingInfo *info, WMView *toplevel,
                                        XClientMessageEvent *event);

void W_DragDestinationStorePositionMsgInfo(WMDraggingInfo *info,
                                           WMView *toplevel,
                                           XClientMessageEvent *event);

void W_DragDestinationCancelDropOnEnter(WMView *toplevel, WMDraggingInfo *info);

void W_DragDestinationStateHandler(WMDraggingInfo *info,
                                   XClientMessageEvent *event);

void W_DragDestinationInfoClear(WMDraggingInfo *info);

void W_FreeViewXdndPart(WMView *view);


/* ---[ handlers.c ]------------------------------------------------------ */

Bool W_CheckIdleHandlers(void);

void W_CheckTimerHandlers(void);

Bool W_HandleInputEvents(Bool waitForInput, int inputfd);


/* ---[ notification.c ]-------------------------------------------------- */

void W_InitNotificationCenter(void);

void W_ReleaseNotificationCenter(void);

void W_FlushASAPNotificationQueue(void);

void W_FlushIdleNotificationQueue(void);


/* ---[ selection.c ]----------------------------------------------------- */

void W_HandleSelectionEvent(XEvent *event);


/* ---[ wapplication.c ]-------------------------------------------------- */

typedef struct W_Application {
    char *applicationName;
    int argc;
    char **argv;
    char *resourcePath;
} W_Application;

/* -- Functions -- */

void W_InitApplication(WMScreen *scr);

Bool W_ApplicationInitialized(void);


/* ---[ wballoon.c ]------------------------------------------------------ */

struct W_Balloon *W_CreateBalloon(WMScreen *scr);

void W_BalloonHandleEnterView(WMView *view);

void W_BalloonHandleLeaveView(WMView *view);


/* ---[ wcolor.c ]-------------------------------------------------------- */

struct W_Color {
    struct W_Screen *screen;

    XColor color;
    unsigned short alpha;
    short refCount;
    GC gc;
    struct {
        unsigned int exact:1;
    } flags;
};

#define W_PIXEL(c)		(c)->color.pixel


/* ---[ wevent.c ]-------------------------------------------------------- */

typedef struct W_EventHandler {
    unsigned long eventMask;

    WMEventProc *proc;

    void *clientData;
} W_EventHandler;

/* -- Functions -- */

void W_CallDestroyHandlers(W_View *view);


/* ---[ wfont.c ]--------------------------------------------------------- */

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


/* ---[ widgets.c ]------------------------------------------------------- */

#define WC_UserWidget	128

#define CHECK_CLASS(widget, class) assert(W_CLASS(widget)==(class))

#define W_CLASS(widget)  	(((W_WidgetType*)(widget))->widgetClass)
#define W_VIEW(widget)   	(((W_WidgetType*)(widget))->view)

/* -- Functions -- */

W_Class W_RegisterUserWidget(void);


/* ---[ winputmethod.c ]-------------------------------------------------- */

void W_InitIM(WMScreen *scr);

void W_CreateIC(WMView *view);

void W_DestroyIC(WMView *view);

void W_FocusIC(WMView *view);

void W_UnFocusIC(WMView *view);

void W_SetPreeditPositon(W_View *view, int x, int y);

int W_LookupString(W_View *view, XKeyPressedEvent *event, char *buffer,
                   int buflen, KeySym *keysym, Status *status);


/* ---[ wmisc.c ]--------------------------------------------------------- */

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


/* ---[ wpixmap.c ]------------------------------------------------------- */

struct W_Pixmap {
    struct W_Screen *screen;
    Pixmap pixmap;
    Pixmap mask;
    unsigned short width;
    unsigned short height;
    short depth;
    short refCount;
};


/* ---[ wview.c ]--------------------------------------------------------- */

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


#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _WINGSP_H_ */
