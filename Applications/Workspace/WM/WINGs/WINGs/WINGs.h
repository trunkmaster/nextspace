/* WINGs.h
 *
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2001 Alfredo K. Kojima
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef _WINGS_H_
#define _WINGS_H_

#include <wraster.h>
#include <WINGs/WUtil.h>
#include <X11/Xlib.h>

#define WINGS_H_VERSION  20150508


#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */
#if 0
}
#endif


#ifdef __STDC_VERSION__
# if __STDC_VERSION__ >= 201112L
/*
 * Ideally, we would like to include the proper header to have 'noreturn' properly
 * defined (that's what is done for the rest of the code)
 * However, as we're a public API file we can't do that in a portable fashion, so
 * we just stick to plain STD C11 keyword
 */
#  define _wings_noreturn _Noreturn
# else
#  define _wings_noreturn /**/
# endif
#else
#define _wings_noreturn /**/
#endif

typedef unsigned long WMPixel;


typedef struct {
    unsigned int width;
    unsigned int height;
} WMSize;

typedef struct {
    int x;
    int y;
} WMPoint;

typedef struct {
    WMPoint pos;
    WMSize size;
} WMRect;





#define ClientMessageMask	(1L<<30)


#ifndef _DEFINED_GNUSTEP_WINDOW_INFO
#define	_DEFINED_GNUSTEP_WINDOW_INFO
/*
 * Window levels are taken from GNUstep (gui/AppKit/NSWindow.h)
 * NSDesktopWindowLevel intended to be the level at which things
 * on the desktop sit ... so you should be able
 * to put a desktop background just below it.
 *
 * Applications are actually permitted to use any value in the
 * range INT_MIN+1 to INT_MAX
 */
enum {
    WMDesktopWindowLevel = -1000, /* GNUstep addition     */
    WMNormalWindowLevel = 0,
    WMFloatingWindowLevel = 3,
    WMSubmenuWindowLevel = 3,
    WMTornOffMenuWindowLevel = 3,
    WMMainMenuWindowLevel = 20,
    WMDockWindowLevel = 21,       /* Deprecated - use NSStatusWindowLevel */
    WMStatusWindowLevel = 21,
    WMModalPanelWindowLevel = 100,
    WMPopUpMenuWindowLevel = 101,
    WMScreenSaverWindowLevel = 1000
};


/* window attributes */
enum {
    WMBorderlessWindowMask = 0,
    WMTitledWindowMask = 1,
    WMClosableWindowMask = 2,
    WMMiniaturizableWindowMask = 4,
    WMResizableWindowMask = 8,
    WMIconWindowMask = 64,
    WMMiniWindowMask = 128
};
#endif


/* button types */
typedef enum {
    /* 0 is reserved for internal use */
    WBTMomentaryPush = 1,
    WBTPushOnPushOff = 2,
    WBTToggle = 3,
    WBTSwitch = 4,
    WBTRadio = 5,
    WBTMomentaryChange = 6,
    WBTOnOff = 7,
    WBTMomentaryLight = 8,
    WBTTriState = 9
} WMButtonType;

/* button behaviour masks */
enum {
    WBBSpringLoadedMask = (1 << 0),
    WBBPushInMask       = (1 << 1),
    WBBPushChangeMask   = (1 << 2),
    WBBPushLightMask    = (1 << 3),
    WBBStateLightMask   = (1 << 5),
    WBBStateChangeMask  = (1 << 6),
    WBBStatePushMask    = (1 << 7)
};


/* frame title positions */
typedef enum {
    WTPNoTitle,
    WTPAboveTop,
    WTPAtTop,
    WTPBelowTop,
    WTPAboveBottom,
    WTPAtBottom,
    WTPBelowBottom
} WMTitlePosition;


/* relief types */
typedef enum {
    WRFlat,
    WRSimple,
    WRRaised,
    WRSunken,
    WRGroove,
    WRRidge,
    WRPushed
} WMReliefType;


/* alignment types */
typedef enum {
    WALeft,
    WACenter,
    WARight,
    WAJustified		       /* not valid for textfields */
} WMAlignment;


/* image position */
typedef enum {
    WIPNoImage,
    WIPImageOnly,
    WIPLeft,
    WIPRight,
    WIPBelow,
    WIPAbove,
    WIPOverlaps
} WMImagePosition;


/* scroller arrow position */
typedef enum {
    WSAMaxEnd,
    WSAMinEnd,
    WSANone
} WMScrollArrowPosition;

/* scroller parts */
typedef enum {
    WSNoPart,
    WSDecrementPage,
    WSIncrementPage,
    WSDecrementLine,
    WSIncrementLine,
    WSDecrementWheel,
    WSIncrementWheel,
    WSKnob,
    WSKnobSlot
} WMScrollerPart;

/* usable scroller parts */
typedef enum {
    WSUNoParts,
    WSUOnlyArrows,
    WSUAllParts
} WMUsableScrollerParts;

/* matrix types */
typedef enum {
    WMRadioMode,
    WMHighlightMode,
    WMListMode,
    WMTrackMode
} WMMatrixTypes;


typedef enum {
    WTTopTabsBevelBorder,
    WTNoTabsBevelBorder,
    WTNoTabsLineBorder,
    WTNoTabsNoBorder
} WMTabViewType;


/* text movement types */
enum {
    WMIllegalTextMovement,
    WMReturnTextMovement,
    WMEscapeTextMovement,
    WMTabTextMovement,
    WMBacktabTextMovement,
    WMLeftTextMovement,
    WMRightTextMovement,
    WMUpTextMovement,
    WMDownTextMovement
};

/* text field special events */
enum {
    WMInsertTextEvent,
    WMDeleteTextEvent
};


enum {
    WLNotFound = -1       /* element was not found in WMList */
};


/* drag operations */
typedef enum {
    WDOperationNone = 0,
    WDOperationCopy,
    WDOperationMove,
    WDOperationLink,
    WDOperationAsk,
    WDOperationPrivate
} WMDragOperationType;


typedef enum {
    WMGrayModeColorPanel = 1,
    WMRGBModeColorPanel = 2,
    WMCMYKModeColorPanel = 3,
    WMHSBModeColorPanel = 4,
    WMCustomPaletteModeColorPanel = 5,
    WMColorListModeColorPanel = 6,
    WMWheelModeColorPanel = 7
} WMColorPanelMode;



/* system images */
#define WSIReturnArrow			1
#define WSIHighlightedReturnArrow	2
#define WSIScrollerDimple		3
#define WSIArrowLeft			4
#define WSIHighlightedArrowLeft	        5
#define WSIArrowRight			6
#define WSIHighlightedArrowRight	7
#define WSIArrowUp			8
#define WSIHighlightedArrowUp		9
#define WSIArrowDown			10
#define WSIHighlightedArrowDown		11
#define WSICheckMark			12

enum {
    WLDSSelected = (1 << 16),
    WLDSDisabled = (1 << 17),
    WLDSFocused = (1 << 18),
    WLDSIsBranch = (1 << 19)
};

/* alert panel return values */
enum {
    WAPRDefault = 0,
    WAPRAlternate = 1,
    WAPROther = -1,
    WAPRError = -2
};



/* types of input observers */
enum {
    WIReadMask = (1 << 0),
    WIWriteMask = (1 << 1),
    WIExceptMask = (1 << 2)
};



typedef int W_Class;

enum {
    WC_Window = 0,
    WC_Frame = 1,
    WC_Label = 2,
    WC_Button = 3,
    WC_TextField = 4,
    WC_Scroller	= 5,
    WC_ScrollView = 6,
    WC_List = 7,
    WC_Browser = 8,
    WC_PopUpButton = 9,
    WC_ColorWell = 10,
    WC_Slider = 11,
    WC_Matrix = 12,		       /* not ready */
    WC_SplitView = 13,
    WC_TabView = 14,
    WC_ProgressIndicator = 15,
    WC_MenuView = 16,
    WC_Ruler = 17,
    WC_Text = 18,
    WC_Box = 19
};

/* All widgets must start with the following structure
 * in that order. Used for typecasting to get some generic data */
typedef struct W_WidgetType {
    W_Class widgetClass;
    struct W_View *view;

} W_WidgetType;


#define WMWidgetClass(widget)  	(((W_WidgetType*)(widget))->widgetClass)
#define WMWidgetView(widget)   	(((W_WidgetType*)(widget))->view)


/* widgets */

typedef void WMWidget;

typedef struct W_Pixmap WMPixmap;
typedef struct W_Font	WMFont;
typedef struct W_Color	WMColor;

typedef struct W_Screen WMScreen;

typedef struct W_View WMView;

typedef struct W_Window WMWindow;
typedef struct W_Frame WMFrame;
typedef struct W_Button WMButton;
typedef struct W_Label WMLabel;
typedef struct W_TextField WMTextField;
typedef struct W_Scroller WMScroller;
typedef struct W_ScrollView WMScrollView;
typedef struct W_List WMList;
typedef struct W_Browser WMBrowser;
typedef struct W_PopUpButton WMPopUpButton;
typedef struct W_ProgressIndicator WMProgressIndicator;
typedef struct W_ColorWell WMColorWell;
typedef struct W_Slider WMSlider;
typedef struct W_Matrix WMMatrix;      /* not ready */
typedef struct W_SplitView WMSplitView;
typedef struct W_TabView WMTabView;
typedef struct W_Ruler WMRuler;
typedef struct W_Text WMText;
typedef struct W_Box WMBox;


/* not widgets */
typedef struct W_TabViewItem WMTabViewItem;
typedef struct W_MenuItem WMMenuItem;


typedef struct W_FilePanel WMFilePanel;
typedef WMFilePanel WMOpenPanel;
typedef WMFilePanel WMSavePanel;

typedef struct W_FontPanel WMFontPanel;

typedef struct W_ColorPanel WMColorPanel;


/* item for WMList */
typedef struct WMListItem {
    char *text;
    void *clientData;		       /* ptr for user clientdata. */

    unsigned int uflags:16;	       /* flags for the user */
    unsigned int selected:1;
    unsigned int disabled:1;
    unsigned int isBranch:1;
    unsigned int loaded:1;
} WMListItem;

/* struct for message panel */
typedef struct WMAlertPanel {
    WMWindow *win;		       /* window */
    WMBox *vbox;
    WMBox *hbox;
    WMButton *defBtn;		       /* default button */
    WMButton *altBtn;		       /* alternative button */
    WMButton *othBtn;		       /* other button */
    WMLabel *iLbl;		       /* icon label */
    WMLabel *tLbl;		       /* title label */
    WMLabel *mLbl;		       /* message label */
    WMFrame *line;		       /* separator */
    short result;		       /* button that was pushed */
} WMAlertPanel;


typedef struct WMGenericPanel {
    WMWindow *win;
    WMBox *vbox;

    WMLabel *iLbl;
    WMLabel *tLbl;

    WMFrame *line;

    WMFrame *content;

    WMBox *buttonBox;
    WMButton *defBtn;
    WMButton *altBtn;

    short result;
} WMGenericPanel;


typedef struct WMInputPanel {
    WMWindow *win;		       /* window */
    WMButton *defBtn;		       /* default button */
    WMButton *altBtn;		       /* alternative button */
    WMLabel *tLbl;		       /* title label */
    WMLabel *mLbl;		       /* message label */
    WMTextField *text;		       /* text field */
    short result;		       /* button that was pushed */
} WMInputPanel;


/* Basic font styles. Used to easily get one style from another */
typedef enum WMFontStyle {
    WFSNormal = 0,
    WFSBold   = 1,
    WFSItalic = 2,
    WFSBoldItalic = 3
} WMFontStyle;


/* WMRuler: */
typedef struct {
    WMArray  *tabs;             /* a growable array of tabstops */
    unsigned short left;        /* left margin marker */
    unsigned short right;       /* right margin marker */
    unsigned short first;       /* indentation marker for first line only */
    unsigned short body;        /* body indentation marker */
    unsigned short retainCount;
} WMRulerMargins;
/* All indentation and tab markers are _relative_ to the left margin marker */


typedef void WMEventProc(XEvent *event, void *clientData);

typedef void WMEventHook(XEvent *event);

/* self is set to the widget from where the callback is being called and
 * clientData to the data set to with WMSetClientData() */
typedef void WMAction(WMWidget *self, void *clientData);

/* same as WMAction, but for stuff that arent widgets */
typedef void WMAction2(void *self, void *clientData);


/* delegate method like stuff */
typedef void WMListDrawProc(WMList *lPtr, int index, Drawable d, char *text,
                            int state, WMRect *rect);


/*
typedef void WMSplitViewResizeSubviewsProc(WMSplitView *sPtr,
                                           unsigned int oldWidth,
                                           unsigned int oldHeight);
*/

typedef void WMSplitViewConstrainProc(WMSplitView *sPtr, int dividerIndex,
                                      int *minSize, int *maxSize);

typedef WMWidget* WMMatrixCreateCellProc(WMMatrix *mPtr);




typedef struct WMBrowserDelegate {
    void *data;

    void (*createRowsForColumn)(struct WMBrowserDelegate *self,
                                WMBrowser *sender, int column, WMList *list);

    char* (*titleOfColumn)(struct WMBrowserDelegate *self, WMBrowser *sender,
                           int column);

    void (*didScroll)(struct WMBrowserDelegate *self, WMBrowser *sender);

    void (*willScroll)(struct WMBrowserDelegate *self, WMBrowser *sender);
} WMBrowserDelegate;


typedef struct WMTextFieldDelegate {
    void *data;

    void (*didBeginEditing)(struct WMTextFieldDelegate *self,
                            WMNotification *notif);

    void (*didChange)(struct WMTextFieldDelegate *self,
                      WMNotification *notif);

    void (*didEndEditing)(struct WMTextFieldDelegate *self,
                          WMNotification *notif);

    Bool (*shouldBeginEditing)(struct WMTextFieldDelegate *self,
                               WMTextField *tPtr);

    Bool (*shouldEndEditing)(struct WMTextFieldDelegate *self,
                             WMTextField *tPtr);
} WMTextFieldDelegate;


typedef struct WMTextDelegate {
    void *data;

    Bool (*didDoubleClickOnPicture)(struct WMTextDelegate *self,
                                    void *description);

} WMTextDelegate;



typedef struct WMTabViewDelegate {
    void *data;

    void (*didChangeNumberOfItems)(struct WMTabViewDelegate *self,
                                   WMTabView *tabView);

    void (*didSelectItem)(struct WMTabViewDelegate *self, WMTabView *tabView,
                          WMTabViewItem *item);

    Bool (*shouldSelectItem)(struct WMTabViewDelegate *self, WMTabView *tabView,
                             WMTabViewItem *item);

    void (*willSelectItem)(struct WMTabViewDelegate *self, WMTabView *tabView,
                           WMTabViewItem *item);
} WMTabViewDelegate;




typedef void WMSelectionCallback(WMView *view, Atom selection, Atom target,
                                 Time timestamp, void *cdata, WMData *data);


typedef struct WMSelectionProcs {
    WMData* (*convertSelection)(WMView *view, Atom selection, Atom target,
                                void *cdata, Atom *type);
    void (*selectionLost)(WMView *view, Atom selection, void *cdata);
    void (*selectionDone)(WMView *view, Atom selection, Atom target,
                          void *cdata);
} WMSelectionProcs;


typedef struct W_DraggingInfo WMDraggingInfo;


/* links a label to a dnd operation. */
typedef struct W_DragOperationtItem WMDragOperationItem;


typedef struct W_DragSourceProcs {
    WMArray* (*dropDataTypes)(WMView *self);
    WMDragOperationType (*wantedDropOperation)(WMView *self);
    WMArray* (*askedOperations)(WMView *self);
    Bool (*acceptDropOperation)(WMView *self, WMDragOperationType operation);
    void (*beganDrag)(WMView *self, WMPoint *point);
    void (*endedDrag)(WMView *self, WMPoint *point, Bool deposited);
    WMData* (*fetchDragData)(WMView *self, char *type);
    /*Bool (*ignoreModifierKeysWhileDragging)(WMView *view);*/
} WMDragSourceProcs;



typedef struct W_DragDestinationProcs {
    void (*prepareForDragOperation)(WMView *self);
    WMArray* (*requiredDataTypes)(WMView *self, WMDragOperationType request,
                                  WMArray *sourceDataTypes);
    WMDragOperationType (*allowedOperation)(WMView *self,
                                            WMDragOperationType request,
                                            WMArray *sourceDataTypes);
    Bool (*inspectDropData)(WMView *self, WMArray *dropData);
    void (*performDragOperation)(WMView *self, WMArray *dropData,
                                 WMArray *operations, WMPoint *dropLocation);
    void (*concludeDragOperation)(WMView *self);
} WMDragDestinationProcs;


/* ---[ WINGs/wmisc.c ]--------------------------------------------------- */


WMPoint wmkpoint(int x, int y);

WMSize wmksize(unsigned int width, unsigned int height);

WMRect wmkrect(int x, int y, unsigned int width, unsigned int height);

#ifdef ANSI_C_DOESNT_LIKE_IT_THIS_WAY
#define wmksize(width, height) (WMSize){(width), (height)}
#define wmkpoint(x, y)         (WMPoint){(x), (y)}
#endif

/* ---[ WINGs/wapplication.c ]-------------------------------------------- */


void WMInitializeApplication(const char *applicationName, int *argc, char **argv);

/* You're supposed to call this funtion before exiting so WINGs can terminate properly */
void WMReleaseApplication(void);

void WMSetResourcePath(const char *path);

/* don't free the returned string */
char* WMGetApplicationName(void);

/* Try to locate resource file. ext may be NULL */
char* WMPathForResourceOfType(const char *resource, const char *ext);

/* ---[ WINGs/widgets.c ]------------------------------------------------- */

WMScreen* WMOpenScreen(const char *display);

WMScreen* WMCreateScreenWithRContext(Display *display, int screen,
                                     RContext *context);

WMScreen* WMCreateScreen(Display *display, int screen);

WMScreen* WMCreateSimpleApplicationScreen(Display *display);

_wings_noreturn void WMScreenMainLoop(WMScreen *scr);

void WMBreakModalLoop(WMScreen *scr);

void WMRunModalLoop(WMScreen *scr, WMView *view);

RContext* WMScreenRContext(WMScreen *scr);

Display* WMScreenDisplay(WMScreen *scr);

int WMScreenDepth(WMScreen *scr);

void WMSetFocusToWidget(WMWidget *widget);

/* ---[ WINGs/wappresource.c ]-------------------------------------------- */

void WMSetApplicationIconImage(WMScreen *app, RImage *image);

RImage* WMGetApplicationIconImage(WMScreen *app);

void WMSetApplicationIconPixmap(WMScreen *app, WMPixmap *icon);

WMPixmap* WMGetApplicationIconPixmap(WMScreen *app);

/* If color==NULL it will use the default color for panels: ae/aa/ae */
WMPixmap* WMCreateApplicationIconBlendedPixmap(WMScreen *scr, const RColor *color);

void WMSetApplicationIconWindow(WMScreen *scr, Window window);

/* ---[ WINGs/wevent.c ]-------------------------------------------------- */

WMEventHook* WMHookEventHandler(WMEventHook *handler);

int WMHandleEvent(XEvent *event);

Bool WMScreenPending(WMScreen *scr);

void WMCreateEventHandler(WMView *view, unsigned long mask,
                          WMEventProc *eventProc, void *clientData);

void WMDeleteEventHandler(WMView *view, unsigned long mask,
                          WMEventProc *eventProc, void *clientData);

int WMIsDoubleClick(XEvent *event);

/*int WMIsTripleClick(XEvent *event);*/

void WMNextEvent(Display *dpy, XEvent *event);

void WMMaskEvent(Display *dpy, long mask, XEvent *event);

void WMSetViewNextResponder(WMView *view, WMView *responder);

void WMRelayToNextResponder(WMView *view, XEvent *event);


/* ---[ WINGs/selection.c ]----------------------------------------------- */


Bool WMCreateSelectionHandler(WMView *view, Atom selection, Time timestamp,
                              WMSelectionProcs *procs, void *cdata);

void WMDeleteSelectionHandler(WMView *view, Atom selection, Time timestamp);

Bool WMRequestSelection(WMView *view, Atom selection, Atom target,
                        Time timestamp, WMSelectionCallback *callback,
                        void *cdata);


extern char *WMSelectionOwnerDidChangeNotification;

/* ---[ WINGs/dragcommon.c ]---------------------------------------------- */

WMArray* WMCreateDragOperationArray(int initialSize);

WMDragOperationItem* WMCreateDragOperationItem(WMDragOperationType type,
                                               char* text);

WMDragOperationType WMGetDragOperationItemType(WMDragOperationItem* item);

char* WMGetDragOperationItemText(WMDragOperationItem* item);

/* ---[ WINGs/dragsource.c ]---------------------------------------------- */

void WMSetViewDragImage(WMView* view, WMPixmap *dragImage);

void WMReleaseViewDragImage(WMView* view);

void WMSetViewDragSourceProcs(WMView *view, WMDragSourceProcs *procs);

Bool WMIsDraggingFromView(WMView *view);

void WMDragImageFromView(WMView *view, XEvent *event);

/* Create a drag handler, associating drag event masks with dragEventProc */
void WMCreateDragHandler(WMView *view, WMEventProc *dragEventProc, void *clientData);

void WMDeleteDragHandler(WMView *view, WMEventProc *dragEventProc, void *clientData);

/* set default drag handler for view */
void WMSetViewDraggable(WMView *view, WMDragSourceProcs *procs, WMPixmap *dragImage);

void WMUnsetViewDraggable(WMView *view);

/* ---[ WINGs/dragdestination.c ]----------------------------------------- */

void WMRegisterViewForDraggedTypes(WMView *view, WMArray *acceptedTypes);

void WMUnregisterViewDraggedTypes(WMView *view);

void WMSetViewDragDestinationProcs(WMView *view, WMDragDestinationProcs *procs);

/* ---[ WINGs/wfont.c ]--------------------------------------------------- */

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

/* ---[ WINGs/wpixmap.c ]------------------------------------------------- */

WMPixmap* WMRetainPixmap(WMPixmap *pixmap);

void WMReleasePixmap(WMPixmap *pixmap);

WMPixmap* WMCreatePixmap(WMScreen *scrPtr, int width, int height, int depth,
                         Bool masked);

WMPixmap* WMCreatePixmapFromXPixmaps(WMScreen *scrPtr, Pixmap pixmap,
                                     Pixmap mask, int width, int height,
                                     int depth);

WMPixmap* WMCreatePixmapFromRImage(WMScreen *scrPtr, RImage *image,
                                   int threshold);

WMPixmap* WMCreatePixmapFromXPMData(WMScreen *scrPtr, char **data);

WMSize WMGetPixmapSize(WMPixmap *pixmap);

WMPixmap* WMCreatePixmapFromFile(WMScreen *scrPtr, const char *fileName);

WMPixmap* WMCreateBlendedPixmapFromRImage(WMScreen *scrPtr, RImage *image,
                                          const RColor *color);

WMPixmap* WMCreateBlendedPixmapFromFile(WMScreen *scrPtr, const char *fileName,
                                        const RColor *color);

WMPixmap* WMCreateScaledBlendedPixmapFromFile(WMScreen *scrPtr, const char *fileName,
                                              const RColor *color,
                                              unsigned int width,
                                              unsigned int height);

void WMDrawPixmap(WMPixmap *pixmap, Drawable d, int x, int y);

Pixmap WMGetPixmapXID(WMPixmap *pixmap);

Pixmap WMGetPixmapMaskXID(WMPixmap *pixmap);

WMPixmap* WMGetSystemPixmap(WMScreen *scr, int image);

/* ---[ WINGs/wcolor.c ]-------------------------------------------------- */


WMColor* WMDarkGrayColor(WMScreen *scr);

WMColor* WMGrayColor(WMScreen *scr);

WMColor* WMBlackColor(WMScreen *scr);

WMColor* WMWhiteColor(WMScreen *scr);

void WMSetColorInGC(WMColor *color, GC gc);

GC WMColorGC(WMColor *color);

WMPixel WMColorPixel(WMColor *color);

void WMPaintColorSwatch(WMColor *color, Drawable d, int x, int y,
                        unsigned int width, unsigned int height);

void WMReleaseColor(WMColor *color);

WMColor* WMRetainColor(WMColor *color);

WMColor* WMCreateRGBColor(WMScreen *scr, unsigned short red,
                          unsigned short green, unsigned short blue,
                          Bool exact);

WMColor* WMCreateRGBAColor(WMScreen *scr, unsigned short red,
                           unsigned short green, unsigned short blue,
                           unsigned short alpha, Bool exact);

WMColor* WMCreateNamedColor(WMScreen *scr, const char *name, Bool exact);

RColor WMGetRColorFromColor(WMColor *color);

void WMSetColorAlpha(WMColor *color, unsigned short alpha);

unsigned short WMRedComponentOfColor(WMColor *color);

unsigned short WMGreenComponentOfColor(WMColor *color);

unsigned short WMBlueComponentOfColor(WMColor *color);

unsigned short WMGetColorAlpha(WMColor *color);

char* WMGetColorRGBDescription(WMColor *color);

/* ---[ WINGs/widgets.c ]------------------------------------------------- */

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

/* ---[ WINGs/wballoon.c ]------------------------------------------------ */

void WMSetBalloonTextForView(const char *text, WMView *view);

void WMSetBalloonTextAlignment(WMScreen *scr, WMAlignment alignment);

void WMSetBalloonFont(WMScreen *scr, WMFont *font);

void WMSetBalloonTextColor(WMScreen *scr, WMColor *color);

void WMSetBalloonDelay(WMScreen *scr, int delay);

void WMSetBalloonEnabled(WMScreen *scr, Bool flag);


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

/* ---[ WINGs/wbutton.c ]------------------------------------------------- */

void WMSetButtonAction(WMButton *bPtr, WMAction *action, void *clientData);

#define WMCreateCommandButton(parent) \
    WMCreateCustomButton((parent), WBBSpringLoadedMask\
    |WBBPushInMask\
    |WBBPushLightMask\
    |WBBPushChangeMask)

#define WMCreateRadioButton(parent) \
    WMCreateButton((parent), WBTRadio)

#define WMCreateSwitchButton(parent) \
    WMCreateButton((parent), WBTSwitch)

WMButton* WMCreateButton(WMWidget *parent, WMButtonType type);

WMButton* WMCreateCustomButton(WMWidget *parent, int behaviourMask);

void WMSetButtonImageDefault(WMButton *bPtr);

void WMSetButtonImage(WMButton *bPtr, WMPixmap *image);

void WMSetButtonAltImage(WMButton *bPtr, WMPixmap *image);

void WMSetButtonImagePosition(WMButton *bPtr, WMImagePosition position);

void WMSetButtonFont(WMButton *bPtr, WMFont *font);

void WMSetButtonTextAlignment(WMButton *bPtr, WMAlignment alignment);

void WMSetButtonText(WMButton *bPtr, const char *text);

/* Returns direct pointer to internal data, do not modify! */
const char *WMGetButtonText(WMButton *bPtr);

void WMSetButtonAltText(WMButton *bPtr, const char *text);

void WMSetButtonTextColor(WMButton *bPtr, WMColor *color);

void WMSetButtonAltTextColor(WMButton *bPtr, WMColor *color);

void WMSetButtonDisabledTextColor(WMButton *bPtr, WMColor *color);

void WMSetButtonSelected(WMButton *bPtr, int isSelected);

int WMGetButtonSelected(WMButton *bPtr);

void WMSetButtonBordered(WMButton *bPtr, int isBordered);

void WMSetButtonEnabled(WMButton *bPtr, Bool flag);

int WMGetButtonEnabled(WMButton *bPtr);

void WMSetButtonImageDimsWhenDisabled(WMButton *bPtr, Bool flag);

void WMSetButtonTag(WMButton *bPtr, int tag);

void WMGroupButtons(WMButton *bPtr, WMButton *newMember);

void WMPerformButtonClick(WMButton *bPtr);

void WMSetButtonContinuous(WMButton *bPtr, Bool flag);

void WMSetButtonPeriodicDelay(WMButton *bPtr, float delay, float interval);

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

/* ---[ WINGs/wframe.c ]-------------------------------------------------- */

WMFrame* WMCreateFrame(WMWidget *parent);

void WMSetFrameTitlePosition(WMFrame *fPtr, WMTitlePosition position);

void WMSetFrameRelief(WMFrame *fPtr, WMReliefType relief);

void WMSetFrameTitle(WMFrame *fPtr, const char *title);

void WMSetFrameTitleColor(WMFrame *fPtr, WMColor *color);

/* ---[ WINGs/wtextfield.c ]---------------------------------------------- */

WMTextField* WMCreateTextField(WMWidget *parent);

void WMInsertTextFieldText(WMTextField *tPtr, const char *text, int position);

void WMDeleteTextFieldRange(WMTextField *tPtr, WMRange range);

/* you can free the returned string */
char* WMGetTextFieldText(WMTextField *tPtr);

void WMSetTextFieldText(WMTextField *tPtr, const char *text);

void WMSetTextFieldAlignment(WMTextField *tPtr, WMAlignment alignment);

void WMSetTextFieldFont(WMTextField *tPtr, WMFont *font);

WMFont* WMGetTextFieldFont(WMTextField *tPtr);

void WMSetTextFieldBordered(WMTextField *tPtr, Bool bordered);

void WMSetTextFieldBeveled(WMTextField *tPtr, Bool flag);

Bool WMGetTextFieldEditable(WMTextField *tPtr);

void WMSetTextFieldEditable(WMTextField *tPtr, Bool flag);

void WMSetTextFieldSecure(WMTextField *tPtr, Bool flag);

void WMSelectTextFieldRange(WMTextField *tPtr, WMRange range);

void WMSetTextFieldCursorPosition(WMTextField *tPtr, unsigned int position);

unsigned WMGetTextFieldCursorPosition(WMTextField *tPtr);

void WMSetTextFieldNextTextField(WMTextField *tPtr, WMTextField *next);

void WMSetTextFieldPrevTextField(WMTextField *tPtr, WMTextField *prev);

void WMSetTextFieldDelegate(WMTextField *tPtr, WMTextFieldDelegate *delegate);

WMTextFieldDelegate* WMGetTextFieldDelegate(WMTextField *tPtr);

extern char *WMTextDidChangeNotification;
extern char *WMTextDidBeginEditingNotification;
extern char *WMTextDidEndEditingNotification;

/* ---[ WINGs/wscroller.c ]----------------------------------------------- */

WMScroller* WMCreateScroller(WMWidget *parent);

void WMSetScrollerParameters(WMScroller *sPtr, float floatValue,
                             float knobProportion);

float WMGetScrollerKnobProportion(WMScroller *sPtr);

float WMGetScrollerValue(WMScroller *sPtr);

WMScrollerPart WMGetScrollerHitPart(WMScroller *sPtr);

void WMSetScrollerAction(WMScroller *sPtr, WMAction *action, void *clientData);

void WMSetScrollerArrowsPosition(WMScroller *sPtr,
                                 WMScrollArrowPosition position);

extern char *WMScrollerDidScrollNotification;

/* ---[ WINGs/wlist.c ]--------------------------------------------------- */

WMList* WMCreateList(WMWidget *parent);

void WMSetListAllowMultipleSelection(WMList *lPtr, Bool flag);

void WMSetListAllowEmptySelection(WMList *lPtr, Bool flag);

#define WMAddListItem(lPtr, text) WMInsertListItem((lPtr), -1, (text))

WMListItem* WMInsertListItem(WMList *lPtr, int row, const char *text);

void WMSortListItems(WMList *lPtr);

void WMSortListItemsWithComparer(WMList *lPtr, WMCompareDataProc *func);

int WMFindRowOfListItemWithTitle(WMList *lPtr, const char *title);

WMListItem* WMGetListItem(WMList *lPtr, int row);

WMArray* WMGetListItems(WMList *lPtr);

void WMRemoveListItem(WMList *lPtr, int row);

void WMSelectListItem(WMList *lPtr, int row);

void WMUnselectListItem(WMList *lPtr, int row);

/* This will select all items in range, and deselect all the others */
void WMSetListSelectionToRange(WMList *lPtr, WMRange range);

/* This will select all items in range, leaving the others as they are */
void WMSelectListItemsInRange(WMList *lPtr, WMRange range);

void WMSelectAllListItems(WMList *lPtr);

void WMUnselectAllListItems(WMList *lPtr);

void WMSetListUserDrawProc(WMList *lPtr, WMListDrawProc *proc);

void WMSetListUserDrawItemHeight(WMList *lPtr, unsigned short height);

int WMGetListItemHeight(WMList *lPtr);

/* don't free the returned data */
WMArray* WMGetListSelectedItems(WMList *lPtr);

/*
 * For the following 2 functions, in case WMList allows multiple selection,
 * the first item in the list of selected items, respective its row number,
 * will be returned.
 */

/* don't free the returned data */
WMListItem* WMGetListSelectedItem(WMList *lPtr);

int WMGetListSelectedItemRow(WMList *lPtr);

void WMSetListAction(WMList *lPtr, WMAction *action, void *clientData);

void WMSetListDoubleAction(WMList *lPtr, WMAction *action, void *clientData);

void WMClearList(WMList *lPtr);

int WMGetListNumberOfRows(WMList *lPtr);

void WMSetListPosition(WMList *lPtr, int row);

void WMSetListBottomPosition(WMList *lPtr, int row);

int WMGetListPosition(WMList *lPtr);

Bool WMListAllowsMultipleSelection(WMList *lPtr);

Bool WMListAllowsEmptySelection(WMList *lPtr);


extern char *WMListDidScrollNotification;
extern char *WMListSelectionDidChangeNotification;

/* ---[ WINGs/wbrowser.c ]------------------------------------------------ */

WMBrowser* WMCreateBrowser(WMWidget *parent);

void WMSetBrowserAllowMultipleSelection(WMBrowser *bPtr, Bool flag);

void WMSetBrowserAllowEmptySelection(WMBrowser *bPtr, Bool flag);

void WMSetBrowserPathSeparator(WMBrowser *bPtr, const char *separator);

void WMSetBrowserTitled(WMBrowser *bPtr, Bool flag);

void WMLoadBrowserColumnZero(WMBrowser *bPtr);

int WMAddBrowserColumn(WMBrowser *bPtr);

void WMRemoveBrowserItem(WMBrowser *bPtr, int column, int row);

void WMSetBrowserMaxVisibleColumns(WMBrowser *bPtr, int columns);

void WMSetBrowserColumnTitle(WMBrowser *bPtr, int column, const char *title);

WMListItem* WMInsertBrowserItem(WMBrowser *bPtr, int column, int row, const char *text, Bool isBranch);

void WMSortBrowserColumn(WMBrowser *bPtr, int column);

void WMSortBrowserColumnWithComparer(WMBrowser *bPtr, int column,
                                     WMCompareDataProc *func);

/* Don't free the returned string. */
char* WMSetBrowserPath(WMBrowser *bPtr, char *path);

/* free the returned string */
char* WMGetBrowserPath(WMBrowser *bPtr);

/* free the returned string */
char* WMGetBrowserPathToColumn(WMBrowser *bPtr, int column);

/* free the returned array */
WMArray* WMGetBrowserPaths(WMBrowser *bPtr);

void WMSetBrowserAction(WMBrowser *bPtr, WMAction *action, void *clientData);

void WMSetBrowserDoubleAction(WMBrowser *bPtr, WMAction *action,
                              void *clientData);

WMListItem* WMGetBrowserSelectedItemInColumn(WMBrowser *bPtr, int column);

int WMGetBrowserFirstVisibleColumn(WMBrowser *bPtr);

int WMGetBrowserSelectedColumn(WMBrowser *bPtr);

int WMGetBrowserSelectedRowInColumn(WMBrowser *bPtr, int column);

int WMGetBrowserNumberOfColumns(WMBrowser *bPtr);

int WMGetBrowserMaxVisibleColumns(WMBrowser *bPtr);

WMList* WMGetBrowserListInColumn(WMBrowser *bPtr, int column);

void WMSetBrowserDelegate(WMBrowser *bPtr, WMBrowserDelegate *delegate);

Bool WMBrowserAllowsMultipleSelection(WMBrowser *bPtr);

Bool WMBrowserAllowsEmptySelection(WMBrowser *bPtr);

void WMSetBrowserHasScroller(WMBrowser *bPtr, int hasScroller);

/* ---[ WINGs/wmenuitem.c ]----------------------------------------------- */


Bool WMMenuItemIsSeparator(WMMenuItem *item);

WMMenuItem* WMCreateMenuItem(void);

void WMDestroyMenuItem(WMMenuItem *item);

Bool WMGetMenuItemEnabled(WMMenuItem *item);

void WMSetMenuItemEnabled(WMMenuItem *item, Bool flag);

char* WMGetMenuItemShortcut(WMMenuItem *item);

unsigned WMGetMenuItemShortcutModifierMask(WMMenuItem *item);

void WMSetMenuItemShortcut(WMMenuItem *item, const char *shortcut);

void WMSetMenuItemShortcutModifierMask(WMMenuItem *item, unsigned mask);

void* WMGetMenuItemRepresentedObject(WMMenuItem *item);

void WMSetMenuItemRepresentedObject(WMMenuItem *item, void *object);

void WMSetMenuItemAction(WMMenuItem *item, WMAction *action, void *data);

WMAction* WMGetMenuItemAction(WMMenuItem *item);

void* WMGetMenuItemData(WMMenuItem *item);

void WMSetMenuItemTitle(WMMenuItem *item, const char *title);

char* WMGetMenuItemTitle(WMMenuItem *item);

void WMSetMenuItemState(WMMenuItem *item, int state);

int WMGetMenuItemState(WMMenuItem *item);

void WMSetMenuItemPixmap(WMMenuItem *item, WMPixmap *pixmap);

WMPixmap* WMGetMenuItemPixmap(WMMenuItem *item);

void WMSetMenuItemOnStatePixmap(WMMenuItem *item, WMPixmap *pixmap);

WMPixmap* WMGetMenuItemOnStatePixmap(WMMenuItem *item);

void WMSetMenuItemOffStatePixmap(WMMenuItem *item, WMPixmap *pixmap);

WMPixmap* WMGetMenuItemOffStatePixmap(WMMenuItem *item);

void WMSetMenuItemMixedStatePixmap(WMMenuItem *item, WMPixmap *pixmap);

WMPixmap* WMGetMenuItemMixedStatePixmap(WMMenuItem *item);

/*void WMSetMenuItemSubmenu(WMMenuItem *item, WMMenu *submenu);


WMMenu* WMGetMenuItemSubmenu(WMMenuItem *item);

Bool WMGetMenuItemHasSubmenu(WMMenuItem *item);
*/

/* ---[ WINGs/wpopupbutton.c ]-------------------------------------------- */

WMPopUpButton* WMCreatePopUpButton(WMWidget *parent);

void WMSetPopUpButtonAction(WMPopUpButton *sPtr, WMAction *action,
                            void *clientData);

void WMSetPopUpButtonPullsDown(WMPopUpButton *bPtr, Bool flag);

WMMenuItem* WMAddPopUpButtonItem(WMPopUpButton *bPtr, const char *title);

WMMenuItem* WMInsertPopUpButtonItem(WMPopUpButton *bPtr, int index,
                                    const char *title);

void WMRemovePopUpButtonItem(WMPopUpButton *bPtr, int index);

void WMSetPopUpButtonItemEnabled(WMPopUpButton *bPtr, int index, Bool flag);

Bool WMGetPopUpButtonItemEnabled(WMPopUpButton *bPtr, int index);

void WMSetPopUpButtonSelectedItem(WMPopUpButton *bPtr, int index);

int WMGetPopUpButtonSelectedItem(WMPopUpButton *bPtr);

void WMSetPopUpButtonText(WMPopUpButton *bPtr, const char *text);

/* don't free the returned data */
char* WMGetPopUpButtonItem(WMPopUpButton *bPtr, int index);

WMMenuItem* WMGetPopUpButtonMenuItem(WMPopUpButton *bPtr, int index);

int WMGetPopUpButtonNumberOfItems(WMPopUpButton *bPtr);

void WMSetPopUpButtonEnabled(WMPopUpButton *bPtr, Bool flag);

Bool WMGetPopUpButtonEnabled(WMPopUpButton *bPtr);

/* ---[ WINGs/wprogressindicator.c ]------------------------------------- */

WMProgressIndicator* WMCreateProgressIndicator(WMWidget *parent);

void WMSetProgressIndicatorMinValue(WMProgressIndicator *progressindicator, int value);

void WMSetProgressIndicatorMaxValue(WMProgressIndicator *progressindicator, int value);

void WMSetProgressIndicatorValue(WMProgressIndicator *progressindicator, int value);

int WMGetProgressIndicatorMinValue(WMProgressIndicator *progressindicator);

int WMGetProgressIndicatorMaxValue(WMProgressIndicator *progressindicator);

int WMGetProgressIndicatorValue(WMProgressIndicator *progressindicator);

/* ---[ WINGs/wcolorpanel.c ]--------------------------------------------- */

WMColorPanel* WMGetColorPanel(WMScreen *scrPtr);

void WMFreeColorPanel(WMColorPanel *panel);

void WMShowColorPanel(WMColorPanel *panel);

void WMCloseColorPanel(WMColorPanel *panel);

void WMSetColorPanelColor(WMColorPanel *panel, WMColor *color);

WMColor* WMGetColorPanelColor(WMColorPanel *panel);

void WMSetColorPanelPickerMode(WMColorPanel *panel, WMColorPanelMode mode);

void WMSetColorPanelAction(WMColorPanel *panel, WMAction2 *action, void *data);

extern char *WMColorPanelColorChangedNotification;

/* ---[ WINGs/wcolorwell.c ]---------------------------------------------- */

WMColorWell* WMCreateColorWell(WMWidget *parent);

void WMSetColorWellColor(WMColorWell *cPtr, WMColor *color);

WMColor* WMGetColorWellColor(WMColorWell *cPtr);

void WSetColorWellBordered(WMColorWell *cPtr, Bool flag);


extern char *WMColorWellDidChangeNotification;


/* ---[ WINGs/wscrollview.c ]--------------------------------------------- */

WMScrollView* WMCreateScrollView(WMWidget *parent);

void WMResizeScrollViewContent(WMScrollView *sPtr, unsigned int width,
                               unsigned int height);

void WMSetScrollViewHasHorizontalScroller(WMScrollView *sPtr, Bool flag);

void WMSetScrollViewHasVerticalScroller(WMScrollView *sPtr, Bool flag);

void WMSetScrollViewContentView(WMScrollView *sPtr, WMView *view);

void WMSetScrollViewRelief(WMScrollView *sPtr, WMReliefType type);

WMRect WMGetScrollViewVisibleRect(WMScrollView *sPtr);

WMScroller* WMGetScrollViewHorizontalScroller(WMScrollView *sPtr);

WMScroller* WMGetScrollViewVerticalScroller(WMScrollView *sPtr);

void WMSetScrollViewLineScroll(WMScrollView *sPtr, int amount);

void WMSetScrollViewPageScroll(WMScrollView *sPtr, int amount);

/* ---[ WINGs/wslider.c ]------------------------------------------------- */

WMSlider* WMCreateSlider(WMWidget *parent);

int WMGetSliderMinValue(WMSlider *slider);

int WMGetSliderMaxValue(WMSlider *slider);

int WMGetSliderValue(WMSlider *slider);

void WMSetSliderMinValue(WMSlider *slider, int value);

void WMSetSliderMaxValue(WMSlider *slider, int value);

void WMSetSliderValue(WMSlider *slider, int value);

void WMSetSliderContinuous(WMSlider *slider, Bool flag);

void WMSetSliderAction(WMSlider *slider, WMAction *action, void *data);

void WMSetSliderKnobThickness(WMSlider *sPtr, int thickness);

void WMSetSliderImage(WMSlider *sPtr, WMPixmap *pixmap);

/* ---[ WINGs/wsplitview.c ]---------------------------------------------- */


WMSplitView* WMCreateSplitView(WMWidget *parent);

Bool WMGetSplitViewVertical(WMSplitView *sPtr);

void WMSetSplitViewVertical(WMSplitView *sPtr, Bool flag);

int WMGetSplitViewSubviewsCount(WMSplitView *sPtr); /* ??? remove ??? */

WMView* WMGetSplitViewSubviewAt(WMSplitView *sPtr, int index);

/* remove the first subview == view */
void WMRemoveSplitViewSubview(WMSplitView *sPtr, WMView *view);

void WMRemoveSplitViewSubviewAt(WMSplitView *sPtr, int index);


void WMAddSplitViewSubview(WMSplitView *sPtr, WMView *subview);

void WMAdjustSplitViewSubviews(WMSplitView *sPtr);

void WMSetSplitViewConstrainProc(WMSplitView *sPtr,
                                 WMSplitViewConstrainProc *proc);

/*
void WMSetSplitViewResizeSubviewsProc(WMSplitView *sPtr,
                                      WMSplitViewResizeSubviewsProc *proc);
*/

int WMGetSplitViewDividerThickness(WMSplitView *sPtr);

/* ...................................................................... */

WMRuler* WMCreateRuler (WMWidget *parent);

WMRulerMargins* WMGetRulerMargins(WMRuler *rPtr);

void WMSetRulerMargins(WMRuler *rPtr, WMRulerMargins margins);

Bool WMIsMarginEqualToMargin(WMRulerMargins *aMargin, WMRulerMargins *anotherMargin);

int WMGetGrabbedRulerMargin(WMRuler *rPtr);

int WMGetReleasedRulerMargin(WMRuler *rPtr);

int WMGetRulerOffset(WMRuler *rPtr);

void WMSetRulerOffset(WMRuler *rPtr, int pixels);

void WMSetRulerMoveAction(WMRuler *rPtr, WMAction *action, void *clientData);

void WMSetRulerReleaseAction(WMRuler *rPtr, WMAction *action, void *clientData);

/* ....................................................................... */


#define WMCreateText(parent) WMCreateTextForDocumentType \
    ((parent), (NULL), (NULL))

WMText* WMCreateTextForDocumentType(WMWidget *parent, WMAction *parser,
                                    WMAction *writer);

void WMSetTextDelegate(WMText *tPtr, WMTextDelegate *delegate);

void WMFreezeText(WMText *tPtr);

#define WMRefreshText(tPtr) WMThawText((tPtr))

void WMThawText(WMText *tPtr);

int WMScrollText(WMText *tPtr, int amount);

int WMPageText(WMText *tPtr, Bool direction);

void WMSetTextHasHorizontalScroller(WMText *tPtr, Bool shouldhave);

void WMSetTextHasVerticalScroller(WMText *tPtr, Bool shouldhave);

void WMSetTextHasRuler(WMText *tPtr, Bool shouldhave);

void WMShowTextRuler(WMText *tPtr, Bool show);

int WMGetTextRulerShown(WMText *tPtr);

void WMSetTextEditable(WMText *tPtr, Bool editable);

int WMGetTextEditable(WMText *tPtr);

void WMSetTextUsesMonoFont(WMText *tPtr, Bool mono);

int WMGetTextUsesMonoFont(WMText *tPtr);

void WMSetTextIndentNewLines(WMText *tPtr, Bool indent);

void WMSetTextIgnoresNewline(WMText *tPtr, Bool ignore);

int WMGetTextIgnoresNewline(WMText *tPtr);

void WMSetTextDefaultFont(WMText *tPtr, WMFont *font);

WMFont* WMGetTextDefaultFont(WMText *tPtr);

void WMSetTextDefaultColor(WMText *tPtr, WMColor *color);

WMColor* WMGetTextDefaultColor(WMText *tPtr);

void WMSetTextRelief(WMText *tPtr, WMReliefType relief);

void WMSetTextForegroundColor(WMText *tPtr, WMColor *color);

void WMSetTextBackgroundColor(WMText *tPtr, WMColor *color);

void WMSetTextBackgroundPixmap(WMText *tPtr, WMPixmap *pixmap);

void WMPrependTextStream(WMText *tPtr, const char *text);

void WMAppendTextStream(WMText *tPtr, const char *text);

#define WMClearText(tPtr) WMAppendTextStream \
    ((tPtr), (NULL))

/* free the text */
char* WMGetTextStream(WMText *tPtr);

/* free the text */
char* WMGetTextSelectedStream(WMText *tPtr);

/* destroy the array */
WMArray* WMGetTextObjects(WMText *tPtr);

/* destroy the array */
WMArray* WMGetTextSelectedObjects(WMText *tPtr);

void WMSetTextSelectionColor(WMText *tPtr, WMColor *color);

WMColor* WMGetTextSelectionColor(WMText *tPtr);

void WMSetTextSelectionFont(WMText *tPtr, WMFont *font);

WMFont* WMGetTextSelectionFont(WMText *tPtr);

void WMSetTextSelectionUnderlined(WMText *tPtr, int underlined);

int WMGetTextSelectionUnderlined(WMText *tPtr);

void WMSetTextAlignment(WMText *tPtr, WMAlignment alignment);

Bool WMFindInTextStream(WMText *tPtr, const char *needle, Bool direction,
                        Bool caseSensitive);

/* Warning: replacement can be modified by the function */
Bool WMReplaceTextSelection(WMText *tPtr, char *replacement);


/* parser related stuff... use only if implementing a new parser */

void* WMCreateTextBlockWithObject(WMText *tPtr, WMWidget *w, const char *description,
                                  WMColor *color, unsigned short first,
                                  unsigned short extraInfo);

void* WMCreateTextBlockWithPixmap(WMText *tPtr, WMPixmap *p, const char *description,
                                  WMColor *color, unsigned short first,
                                  unsigned short extraInfo);

void* WMCreateTextBlockWithText(WMText *tPtr, const char *text, WMFont *font,
                                WMColor *color, unsigned short first,
                                unsigned short length);

void WMSetTextBlockProperties(WMText *tPtr, void *vtb, unsigned int first,
                              unsigned int kanji, unsigned int underlined,
                              int script, WMRulerMargins *margins);

/* do NOT free the margins */
void WMGetTextBlockProperties(WMText *tPtr, void *vtb, unsigned int *first,
                              unsigned int *kanji, unsigned int *underlined,
                              int *script, WMRulerMargins *margins);

int WMGetTextInsertType(WMText *tPtr);

/*int WMGetTextBlocks(WMText *tPtr);

void WMSetCurrentTextBlock(WMText *tPtr, int current);

int WMGetCurrentTextBlock(WMText *tPtr);*/

void WMPrependTextBlock(WMText *tPtr, void *vtb);

void WMAppendTextBlock(WMText *tPtr, void *vtb);

void* WMRemoveTextBlock(WMText *tPtr);

void WMDestroyTextBlock(WMText *tPtr, void *vtb);

/* ---[ WINGs/wtabview.c ]------------------------------------------------ */

WMTabView* WMCreateTabView(WMWidget *parent);

void WMSetTabViewType(WMTabView *tPtr, WMTabViewType type);

void WMSetTabViewEnabled(WMTabView *tPtr, Bool flag);

void WMSetTabViewFont(WMTabView *tPtr, WMFont *font);

void WMAddItemInTabView(WMTabView *tPtr, WMTabViewItem *item);

void WMInsertItemInTabView(WMTabView *tPtr, int index, WMTabViewItem *item);

void WMRemoveTabViewItem(WMTabView *tPtr, WMTabViewItem *item);

WMTabViewItem* WMAddTabViewItemWithView(WMTabView *tPtr, WMView *view,
                                        int identifier, const char *label);

WMTabViewItem* WMTabViewItemAtPoint(WMTabView *tPtr, int x, int y);

void WMSelectFirstTabViewItem(WMTabView *tPtr);

void WMSelectLastTabViewItem(WMTabView *tPtr);

void WMSelectNextTabViewItem(WMTabView *tPtr);

void WMSelectPreviousTabViewItem(WMTabView *tPtr);

WMTabViewItem* WMGetSelectedTabViewItem(WMTabView *tPtr);

void WMSelectTabViewItem(WMTabView *tPtr, WMTabViewItem *item);

void WMSelectTabViewItemAtIndex(WMTabView *tPtr, int index);

void WMSetTabViewDelegate(WMTabView *tPtr, WMTabViewDelegate *delegate);


WMTabViewItem* WMCreateTabViewItemWithIdentifier(int identifier);

void WMSetTabViewItemEnabled(WMTabViewItem *tPtr, Bool flag);

int WMGetTabViewItemIdentifier(WMTabViewItem *item);

void WMSetTabViewItemLabel(WMTabViewItem *item, const char *label);

char* WMGetTabViewItemLabel(WMTabViewItem *item);

void WMSetTabViewItemView(WMTabViewItem *item, WMView *view);

WMView* WMGetTabViewItemView(WMTabViewItem *item);

void WMDestroyTabViewItem(WMTabViewItem *item);


/* ---[ WINGs/wbox.c ]---------------------------------------------------- */

WMBox* WMCreateBox(WMWidget *parent);

void WMSetBoxBorderWidth(WMBox *box, unsigned width);

void WMAddBoxSubview(WMBox *bPtr, WMView *view, Bool expand, Bool fill,
                     int minSize, int maxSize, int space);

void WMAddBoxSubviewAtEnd(WMBox *bPtr, WMView *view, Bool expand, Bool fill,
                          int minSize, int maxSize, int space);

void WMRemoveBoxSubview(WMBox *bPtr, WMView *view);

void WMSetBoxHorizontal(WMBox *box, Bool flag);

/* ---[ WINGs/wpanel.c ]-------------------------------------------------- */

int WMRunAlertPanel(WMScreen *app, WMWindow *owner, const char *title, const char *msg,
                    const char *defaultButton, const char *alternateButton,
                    const char *otherButton);

/* you can free the returned string */
char* WMRunInputPanel(WMScreen *app, WMWindow *owner, const char *title, const char *msg,
                      const char *defaultText, const char *okButton, const char *cancelButton);

WMAlertPanel* WMCreateAlertPanel(WMScreen *app, WMWindow *owner, const char *title,
                                 const char *msg, const char *defaultButton,
                                 const char *alternateButton, const char *otherButton);

WMInputPanel* WMCreateInputPanel(WMScreen *app, WMWindow *owner, const char *title,
                                 const char *msg, const char *defaultText, const char *okButton,
                                 const char *cancelButton);


WMGenericPanel* WMCreateGenericPanel(WMScreen *scrPtr, WMWindow *owner,
                                     const char *title, const char *defaultButton,
                                     const char *alternateButton);

void WMDestroyAlertPanel(WMAlertPanel *panel);

void WMDestroyInputPanel(WMInputPanel *panel);

void WMDestroyGenericPanel(WMGenericPanel *panel);

/* ---[ WINGs/wfilepanel.c ]---------------------------------------------- */

/* only 1 instance per WMScreen */
WMOpenPanel* WMGetOpenPanel(WMScreen *scrPtr);

WMSavePanel* WMGetSavePanel(WMScreen *scrPtr);

void WMSetFilePanelCanChooseDirectories(WMFilePanel *panel, Bool flag);

void WMSetFilePanelCanChooseFiles(WMFilePanel *panel, Bool flag);

void WMSetFilePanelAutoCompletion(WMFilePanel *panel, Bool flag);

void WMSetFilePanelDirectory(WMFilePanel *panel, char *path);

/* you can free the returned string */
char* WMGetFilePanelFileName(WMFilePanel *panel);

void WMFreeFilePanel(WMFilePanel *panel);

int WMRunModalFilePanelForDirectory(WMFilePanel *panel, WMWindow *owner,
                                    char *path, const char *name, char **fileTypes);

void WMSetFilePanelAccessoryView(WMFilePanel *panel, WMView *view);

WMView* WMGetFilePanelAccessoryView(WMFilePanel *panel);


/* ---[ WINGs/wfontpanel.c ]---------------------------------------------- */

/* only 1 instance per WMScreen */
WMFontPanel* WMGetFontPanel(WMScreen *scr);

void WMShowFontPanel(WMFontPanel *panel);

void WMHideFontPanel(WMFontPanel *panel);

void WMFreeFontPanel(WMFontPanel *panel);

void WMSetFontPanelAction(WMFontPanel *panel, WMAction2 *action, void *data);

void WMSetFontPanelFont(WMFontPanel *panel, const char *fontName);

WMFont* WMGetFontPanelFont(WMFontPanel *panel);

/* ---[ WINGs/configuration.c ]------------------------------------------- */
unsigned W_getconf_mouseWheelUp(void);
unsigned W_getconf_mouseWheelDown(void);
void W_setconf_doubleClickDelay(int value);

#ifdef __cplusplus
}
#endif /* __cplusplus */


/* These definitions are not meant to be seen outside this file */
#undef _wings_noreturn


#endif
