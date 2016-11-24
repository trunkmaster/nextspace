/*
 * ColorPanel for WINGs
 *
 * by	]d				: Original idea and basic initial code
 *	Pascal Hofstee			: Code for wheeldrawing and calculating
 *				   	  colors from it.
 *					  Primary coder of this Color Panel.
 *	Alban Hertroys			: Optimizations for algorithms for color-
 *					  wheel. Also custom ColorPalettes and
 *					  magnifying glass. Secondary coder ;)
 *	Alfredo K. Kojima		: For pointing out memory-allocation
 *					  problems and similair code-issues
 *	Marco van Hylckama-Vlieg	: For once again doing the artwork ;-)
 *
 */

/* TODO:
 * 	-	Look at further optimization of colorWheel matrix calculation.
 * 		It appears to be rather symmetric in angles of 60 degrees,
 * 		while it is optimized in angles of 90 degrees.
 * 	-	Custom color-lists and custom colors in custom color-lists.
 * 	-	Stored colors
 * 	-	Resizing
 */

#include "wconfig.h"
#include "WINGsP.h"
#include "rgb.h"

#include <errno.h>
#include <math.h>
#include <unistd.h>
#include <ctype.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>


/* BUG There's something fishy with shaped windows */
/* Whithout shape extension the magnified image is completely broken -Dan */

#ifdef USE_XSHAPE
# include <X11/extensions/shape.h>
#endif

char *WMColorPanelColorChangedNotification = "WMColorPanelColorChangedNotification";

/*
 * Bitmaps for magnifying glass cursor
 */

/* Cursor */
#define Cursor_x_hot 11
#define Cursor_y_hot 11
#define Cursor_width 32
#define Cursor_height 32
static unsigned char Cursor_bits[] = {
	0x00, 0x7e, 0x00, 0x00, 0xc0, 0x81, 0x03, 0x00, 0x20, 0x00, 0x04, 0x00, 0x10, 0x00, 0x08,
	0x00, 0x08, 0x00, 0x10, 0x00, 0x04, 0x00, 0x20, 0x00, 0x02, 0x00, 0x40, 0x00, 0x02, 0x00,
	0x40, 0x00, 0x02, 0x00, 0x40, 0x00, 0x01, 0x42, 0x80, 0x00, 0x01, 0x24, 0x80, 0x00, 0x01,
	0x00, 0x80, 0x00, 0x01, 0x00, 0x80, 0x00, 0x01, 0x24, 0x80, 0x00, 0x01, 0x42, 0x80, 0x00,
	0x02, 0x00, 0x40, 0x00, 0x02, 0x00, 0x40, 0x00, 0x02, 0x00, 0x40, 0x00, 0x04, 0x00, 0x20,
	0x00, 0x08, 0x00, 0x50, 0x00, 0x10, 0x00, 0x88, 0x00, 0x20, 0x00, 0x5c, 0x01, 0xc0, 0x81,
	0x3b, 0x02, 0x00, 0x7e, 0x70, 0x05, 0x00, 0x00, 0xe0, 0x08, 0x00, 0x00, 0xc0, 0x15, 0x00,
	0x00, 0x80, 0x23, 0x00, 0x00, 0x00, 0x57, 0x00, 0x00, 0x00, 0x8e, 0x00, 0x00, 0x00, 0x5c,
	0x00, 0x00, 0x00, 0xb8, 0x00, 0x00, 0x00, 0x70
};

/* Cursor shape-mask */
#define Cursor_shape_width 32
#define Cursor_shape_height 32
static unsigned char Cursor_shape_bits[] = {
	0x00, 0x7e, 0x00, 0x00, 0xc0, 0x81, 0x03, 0x00, 0x20, 0x00, 0x04, 0x00, 0x10, 0x00, 0x08,
	0x00, 0x08, 0x00, 0x10, 0x00, 0x04, 0x00, 0x20, 0x00, 0x02, 0x00, 0x40, 0x00, 0x02, 0x00,
	0x40, 0x00, 0x02, 0x00, 0x40, 0x00, 0x01, 0x42, 0x80, 0x00, 0x01, 0x24, 0x80, 0x00, 0x01,
	0x00, 0x80, 0x00, 0x01, 0x00, 0x80, 0x00, 0x01, 0x24, 0x80, 0x00, 0x01, 0x42, 0x80, 0x00,
	0x02, 0x00, 0x40, 0x00, 0x02, 0x00, 0x40, 0x00, 0x02, 0x00, 0x40, 0x00, 0x04, 0x00, 0x20,
	0x00, 0x08, 0x00, 0x70, 0x00, 0x10, 0x00, 0xf8, 0x00, 0x20, 0x00, 0xfc, 0x01, 0xc0, 0x81,
	0xfb, 0x03, 0x00, 0x7e, 0xf0, 0x07, 0x00, 0x00, 0xe0, 0x0f, 0x00, 0x00, 0xc0, 0x1f, 0x00,
	0x00, 0x80, 0x3f, 0x00, 0x00, 0x00, 0x7f, 0x00, 0x00, 0x00, 0xfe, 0x00, 0x00, 0x00, 0xfc,
	0x00, 0x00, 0x00, 0xf8, 0x00, 0x00, 0x00, 0x70
};

/* Clip-mask for magnified pixels */
#define Cursor_mask_width 24
#define Cursor_mask_height 24
static unsigned char Cursor_mask_bits[] = {
	0x00, 0x00, 0x00, 0x00, 0x7e, 0x00, 0xc0, 0xff, 0x03, 0xe0, 0xff, 0x07,
	0xf0, 0xff, 0x0f, 0xf8, 0xff, 0x1f, 0xfc, 0xff, 0x3f, 0xfc, 0xff, 0x3f,
	0xfc, 0xff, 0x3f, 0xfe, 0xff, 0x7f, 0xfe, 0xff, 0x7f, 0xfe, 0xff, 0x7f,
	0xfe, 0xff, 0x7f, 0xfe, 0xff, 0x7f, 0xfe, 0xff, 0x7f, 0xfc, 0xff, 0x3f,
	0xfc, 0xff, 0x3f, 0xfc, 0xff, 0x3f, 0xf8, 0xff, 0x1f, 0xf0, 0xff, 0x0f,
	0xe0, 0xff, 0x07, 0xc0, 0xff, 0x03, 0x00, 0x7e, 0x00, 0x00, 0x00, 0x00
};

typedef struct MovingView {
	WMView *view;		/* The view this is all about */
	XImage *image;		/* What's under the view */
	XImage *dirtyRect;	/* Storage of overlapped image area */
	Pixmap magPix;		/* Magnified part of pixmap */
	RColor color;		/* Color of a pixel in the image */
	int x, y;		/* Position of view */
} MovingView;

typedef struct CPColor {
	RColor rgb;		/* The RGB values of the color  */
	RHSVColor hsv;		/* The HSV values of the color  */
	enum {			/* Which one was last set ?     */
		cpNone,
		cpRGB,
		cpHSV
	} set;
} CPColor;

typedef struct WheelMatrix {
	unsigned int width, height;	/* Size of the colorwheel */
	unsigned char *data[3];	/* Wheel data (R,G,B) */
	unsigned char values[256];	/* Precalculated values R,G & B = 0-255 */
} wheelMatrix;

typedef struct W_ColorPanel {
	WMWindow *win;
	WMFont *font8;
	WMFont *font12;
	void *clientData;
	WMAction2 *action;

	/* Common Stuff */
	WMColorWell *colorWell;
	WMButton *magnifyBtn;
	WMButton *wheelBtn;
	WMButton *slidersBtn;
	WMButton *customPaletteBtn;
	WMButton *colorListBtn;

	/* Magnifying Glass */
	MovingView *magnifyGlass;

	/* ColorWheel Panel */
	WMFrame *wheelFrm;
	WMSlider *wheelBrightnessS;
	WMView *wheelView;

	/* Slider Panels */
	WMFrame *slidersFrm;
	WMFrame *seperatorFrm;
	WMButton *grayBtn;
	WMButton *rgbBtn;
	WMButton *cmykBtn;
	WMButton *hsbBtn;
	/* Gray Scale Panel */
	WMFrame *grayFrm;
	WMLabel *grayMinL;
	WMLabel *grayMaxL;
	WMSlider *grayBrightnessS;
	WMTextField *grayBrightnessT;
	WMButton *grayPresetBtn[7];

	/* RGB Panel */
	WMButton *rgbDecB;
	WMButton *rgbHexB;
	WMFrame *rgbFrm;
	WMLabel *rgbMinL;
	WMLabel *rgbMaxL;
	WMSlider *rgbRedS;
	WMSlider *rgbGreenS;
	WMSlider *rgbBlueS;
	WMTextField *rgbRedT;
	WMTextField *rgbGreenT;
	WMTextField *rgbBlueT;
	enum {
		RGBdec,
		RGBhex
	} rgbState;

	/* CMYK Panel */
	WMFrame *cmykFrm;
	WMLabel *cmykMinL;
	WMLabel *cmykMaxL;
	WMSlider *cmykCyanS;
	WMSlider *cmykMagentaS;
	WMSlider *cmykYellowS;
	WMSlider *cmykBlackS;
	WMTextField *cmykCyanT;
	WMTextField *cmykMagentaT;
	WMTextField *cmykYellowT;
	WMTextField *cmykBlackT;

	/* HSB Panel */
	WMFrame *hsbFrm;
	WMSlider *hsbHueS;
	WMSlider *hsbSaturationS;
	WMSlider *hsbBrightnessS;
	WMTextField *hsbHueT;
	WMTextField *hsbSaturationT;
	WMTextField *hsbBrightnessT;

	/* Custom Palette Panel */
	WMFrame *customPaletteFrm;
	WMPopUpButton *customPaletteHistoryBtn;
	WMFrame *customPaletteContentFrm;
	WMPopUpButton *customPaletteMenuBtn;
	WMView *customPaletteContentView;

	/* Color List Panel */
	WMFrame *colorListFrm;
	WMPopUpButton *colorListHistoryBtn;
	WMList *colorListContentLst;
	WMPopUpButton *colorListColorMenuBtn;
	WMPopUpButton *colorListListMenuBtn;

	/* Look-Up Tables and Images */
	wheelMatrix *wheelMtrx;
	Pixmap wheelImg;
	Pixmap selectionImg;
	Pixmap selectionBackImg;
	RImage *customPaletteImg;
	char *lastBrowseDir;

	/* Common Data Fields */
	CPColor color;		/* Current color */
	WMColorPanelMode mode;	/* Current color selection mode */
	WMColorPanelMode slidersmode;	/* Current color sel. mode sliders panel */
	WMColorPanelMode lastChanged;	/* Panel that last changed the color */
	int colx, coly;		/* (x,y) of sel.-marker in WheelMode */
	int palx, paly;		/* (x,y) of sel.-marker in
				   CustomPaletteMode */
	double palXRatio, palYRatio;	/* Ratios in x & y between
					   original and scaled
					   palettesize */
	int currentPalette;
	char *configurationPath;

	struct {
		unsigned int continuous:1;
		unsigned int dragging:1;
	} flags;
} W_ColorPanel;

enum {
	CPmenuNewFromFile,
	CPmenuRename,
	CPmenuRemove,
	CPmenuCopy,
	CPmenuNewFromClipboard
} customPaletteMenuItem;

enum {
	CLmenuAdd,
	CLmenuRename,
	CLmenuRemove
} colorListMenuItem;

#define	PWIDTH                  194
#define	PHEIGHT                 266
#define	colorWheelSize          150
#define	customPaletteWidth      182
#define	customPaletteHeight     106
#define	knobThickness           8

#define	SPECTRUM_WIDTH          511
#define	SPECTRUM_HEIGHT         360

#define	COLORWHEEL_PART         1
#define	CUSTOMPALETTE_PART      2


static char *generateNewFilename(const char *curName);
static void convertCPColor(CPColor * color);
static RColor ulongToRColor(WMScreen * scr, unsigned long value);
static unsigned char getShift(unsigned char value);

static void modeButtonCallback(WMWidget * w, void *data);
static int getPickerPart(W_ColorPanel * panel, int x, int y);
static void readConfiguration(W_ColorPanel * panel);
static void readXColors(W_ColorPanel * panel);

static void closeWindowCallback(WMWidget * w, void *data);

static Cursor magnifyGrabPointer(W_ColorPanel * panel);
static WMPoint magnifyInitialize(W_ColorPanel * panel);
static void magnifyPutCursor(WMWidget * w, void *data);
static Pixmap magnifyCreatePixmap(WMColorPanel * panel);
static void magnifyGetImageStored(W_ColorPanel * panel, int x1, int y1, int x2, int y2);
static XImage *magnifyGetImage(WMScreen * scr, XImage * image, int x, int y, int w, int h);

static wheelMatrix *wheelCreateMatrix(unsigned int width, unsigned int height);
static void wheelDestroyMatrix(wheelMatrix * matrix);
static void wheelInitMatrix(W_ColorPanel * panel);
static void wheelCalculateValues(W_ColorPanel * panel, int maxvalue);
static void wheelRender(W_ColorPanel * panel);
static Bool wheelInsideColorWheel(W_ColorPanel * panel, unsigned long ofs);
static void wheelPaint(W_ColorPanel * panel);

static void wheelHandleEvents(XEvent * event, void *data);
static void wheelHandleActionEvents(XEvent * event, void *data);
static void wheelBrightnessSliderCallback(WMWidget * w, void *data);
static void wheelUpdateSelection(W_ColorPanel * panel);
static void wheelUndrawSelection(W_ColorPanel * panel);

static void wheelPositionSelection(W_ColorPanel * panel, int x, int y);
static void wheelPositionSelectionOutBounds(W_ColorPanel * panel, int x, int y);
static void wheelUpdateBrightnessGradientFromLocation(W_ColorPanel * panel);
static void wheelUpdateBrightnessGradient(W_ColorPanel * panel, CPColor topColor);

static void grayBrightnessSliderCallback(WMWidget * w, void *data);
static void grayPresetButtonCallback(WMWidget * w, void *data);
static void grayBrightnessTextFieldCallback(void *observerData, WMNotification * notification);

static void rgbSliderCallback(WMWidget * w, void *data);
static void rgbTextFieldCallback(void *observerData, WMNotification * notification);
static void rgbDecToHex(WMWidget *w, void *data);

static void cmykSliderCallback(WMWidget * w, void *data);
static void cmykTextFieldCallback(void *observerData, WMNotification * notification);

static void hsbSliderCallback(WMWidget * w, void *data);
static void hsbTextFieldCallback(void *observerData, WMNotification * notification);
static void hsbUpdateBrightnessGradient(W_ColorPanel * panel);
static void hsbUpdateSaturationGradient(W_ColorPanel * panel);
static void hsbUpdateHueGradient(W_ColorPanel * panel);

static void customRenderSpectrum(W_ColorPanel * panel);
static void customSetPalette(W_ColorPanel * panel);
static void customPaletteHandleEvents(XEvent * event, void *data);
static void customPaletteHandleActionEvents(XEvent * event, void *data);
static void customPalettePositionSelection(W_ColorPanel * panel, int x, int y);
static void customPalettePositionSelectionOutBounds(W_ColorPanel * panel, int x, int y);
static void customPaletteMenuCallback(WMWidget * w, void *data);
static void customPaletteHistoryCallback(WMWidget * w, void *data);

static void customPaletteMenuNewFromFile(W_ColorPanel * panel);
static void customPaletteMenuRename(W_ColorPanel * panel);
static void customPaletteMenuRemove(W_ColorPanel * panel);

static void colorListPaintItem(WMList * lPtr, int index, Drawable d, char *text, int state, WMRect * rect);
static void colorListSelect(WMWidget * w, void *data);
static void colorListColorMenuCallback(WMWidget * w, void *data);
static void colorListListMenuCallback(WMWidget * w, void *data);

static void wheelInit(W_ColorPanel * panel);
static void grayInit(W_ColorPanel * panel);
static void rgbInit(W_ColorPanel * panel);
static void cmykInit(W_ColorPanel * panel);
static void hsbInit(W_ColorPanel * panel);


static inline int get_textfield_as_integer(WMTextField *widget)
{
	char *str;
	int value;

	str = WMGetTextFieldText(widget);
	value = atoi(str);
	wfree(str);
	return value;
}

void WMSetColorPanelAction(WMColorPanel * panel, WMAction2 * action, void *data)
{
	panel->action = action;
	panel->clientData = data;
}

static WMColorPanel *makeColorPanel(WMScreen * scrPtr, const char *name)
{
	WMColorPanel *panel;
	RImage *image;
	WMPixmap *pixmap;
	RColor from;
	RColor to;
	WMColor *textcolor, *graybuttoncolor;
	int i;
	GC bgc = WMColorGC(scrPtr->black);
	GC wgc = WMColorGC(scrPtr->white);

	panel = wmalloc(sizeof(WMColorPanel));
	panel->color.rgb.red = 0;
	panel->color.rgb.green = 0;
	panel->color.rgb.blue = 0;
	panel->color.hsv.hue = 0;
	panel->color.hsv.saturation = 0;
	panel->color.hsv.value = 0;
	panel->color.set = cpNone;	/* Color has not been set yet */

	panel->font8 = WMSystemFontOfSize(scrPtr, 8);
	panel->font12 = WMSystemFontOfSize(scrPtr, 12);

	panel->win = WMCreateWindowWithStyle(scrPtr, name,
					     WMTitledWindowMask | WMClosableWindowMask | WMResizableWindowMask);
	WMResizeWidget(panel->win, PWIDTH, PHEIGHT);
	WMSetWindowTitle(panel->win, _("Colors"));
	WMSetWindowCloseAction(panel->win, closeWindowCallback, panel);

	/* Set Default ColorPanel Mode(s) */
	panel->mode = WMWheelModeColorPanel;
	panel->lastChanged = 0;
	panel->slidersmode = WMRGBModeColorPanel;
	panel->configurationPath = wstrconcat(wusergnusteppath(), "/Library/Colors/");

	/* Some General Purpose Widgets */
	panel->colorWell = WMCreateColorWell(panel->win);
	WMResizeWidget(panel->colorWell, 134, 36);
	WSetColorWellBordered(panel->colorWell, False);
	WMMoveWidget(panel->colorWell, 56, 4);

	panel->magnifyBtn = WMCreateCustomButton(panel->win, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->magnifyBtn, 46, 36);
	WMMoveWidget(panel->magnifyBtn, 6, 4);
	WMSetButtonAction(panel->magnifyBtn, magnifyPutCursor, panel);
	WMSetButtonImagePosition(panel->magnifyBtn, WIPImageOnly);
	WMSetButtonImage(panel->magnifyBtn, scrPtr->magnifyIcon);

	panel->wheelBtn = WMCreateCustomButton(panel->win, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->wheelBtn, 46, 32);
	WMMoveWidget(panel->wheelBtn, 6, 44);
	WMSetButtonAction(panel->wheelBtn, modeButtonCallback, panel);
	WMSetButtonImagePosition(panel->wheelBtn, WIPImageOnly);
	WMSetButtonImage(panel->wheelBtn, scrPtr->wheelIcon);

	panel->slidersBtn = WMCreateCustomButton(panel->win, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->slidersBtn, 46, 32);
	WMMoveWidget(panel->slidersBtn, 52, 44);
	WMSetButtonAction(panel->slidersBtn, modeButtonCallback, panel);
	WMSetButtonImagePosition(panel->slidersBtn, WIPImageOnly);
	WMSetButtonImage(panel->slidersBtn, scrPtr->rgbIcon);

	panel->customPaletteBtn = WMCreateCustomButton(panel->win, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->customPaletteBtn, 46, 32);
	WMMoveWidget(panel->customPaletteBtn, 98, 44);
	WMSetButtonAction(panel->customPaletteBtn, modeButtonCallback, panel);
	WMSetButtonImagePosition(panel->customPaletteBtn, WIPImageOnly);
	WMSetButtonImage(panel->customPaletteBtn, scrPtr->customPaletteIcon);

	panel->colorListBtn = WMCreateCustomButton(panel->win, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->colorListBtn, 46, 32);
	WMMoveWidget(panel->colorListBtn, 144, 44);
	WMSetButtonAction(panel->colorListBtn, modeButtonCallback, panel);
	WMSetButtonImagePosition(panel->colorListBtn, WIPImageOnly);
	WMSetButtonImage(panel->colorListBtn, scrPtr->colorListIcon);

	/* Let's Group some of them together */
	WMGroupButtons(panel->wheelBtn, panel->slidersBtn);
	WMGroupButtons(panel->wheelBtn, panel->customPaletteBtn);
	WMGroupButtons(panel->wheelBtn, panel->colorListBtn);

	/* Widgets for the ColorWheel Panel */
	panel->wheelFrm = WMCreateFrame(panel->win);
	WMSetFrameRelief(panel->wheelFrm, WRFlat);
	WMResizeWidget(panel->wheelFrm, PWIDTH - 8, PHEIGHT - 80 - 26);
	WMMoveWidget(panel->wheelFrm, 5, 80);

	panel->wheelView = W_CreateView(W_VIEW(panel->wheelFrm));
	/* XXX Can we create a view ? */
	W_ResizeView(panel->wheelView, colorWheelSize + 4, colorWheelSize + 4);
	W_MoveView(panel->wheelView, 0, 0);

	/* Create an event handler to handle expose/click events in ColorWheel */
	WMCreateEventHandler(panel->wheelView,
			     ButtonPressMask | ButtonReleaseMask | EnterWindowMask |
			     LeaveWindowMask | ButtonMotionMask, wheelHandleActionEvents, panel);

	WMCreateEventHandler(panel->wheelView, ExposureMask, wheelHandleEvents, panel);

	panel->wheelBrightnessS = WMCreateSlider(panel->wheelFrm);
	WMResizeWidget(panel->wheelBrightnessS, 16, 153);
	WMMoveWidget(panel->wheelBrightnessS, 5 + colorWheelSize + 14, 1);
	WMSetSliderMinValue(panel->wheelBrightnessS, 0);
	WMSetSliderMaxValue(panel->wheelBrightnessS, 255);
	WMSetSliderAction(panel->wheelBrightnessS, wheelBrightnessSliderCallback, panel);
	WMSetSliderKnobThickness(panel->wheelBrightnessS, knobThickness);

	panel->wheelMtrx = wheelCreateMatrix(colorWheelSize + 4, colorWheelSize + 4);
	wheelInitMatrix(panel);

	/* Widgets for the Slider Panels */
	panel->slidersFrm = WMCreateFrame(panel->win);
	WMSetFrameRelief(panel->slidersFrm, WRFlat);
	WMResizeWidget(panel->slidersFrm, PWIDTH - 8, PHEIGHT - 80 - 26);
	WMMoveWidget(panel->slidersFrm, 4, 80);

	panel->seperatorFrm = WMCreateFrame(panel->slidersFrm);
	WMSetFrameRelief(panel->seperatorFrm, WRPushed);
	WMResizeWidget(panel->seperatorFrm, PWIDTH - 8, 2);
	WMMoveWidget(panel->seperatorFrm, 0, 1);

	panel->grayBtn = WMCreateCustomButton(panel->slidersFrm, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->grayBtn, 46, 24);
	WMMoveWidget(panel->grayBtn, 1, 8);
	WMSetButtonAction(panel->grayBtn, modeButtonCallback, panel);
	WMSetButtonImagePosition(panel->grayBtn, WIPImageOnly);
	WMSetButtonImage(panel->grayBtn, scrPtr->grayIcon);

	panel->rgbBtn = WMCreateCustomButton(panel->slidersFrm, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->rgbBtn, 46, 24);
	WMMoveWidget(panel->rgbBtn, 47, 8);
	WMSetButtonAction(panel->rgbBtn, modeButtonCallback, panel);
	WMSetButtonImagePosition(panel->rgbBtn, WIPImageOnly);
	WMSetButtonImage(panel->rgbBtn, scrPtr->rgbIcon);

	panel->cmykBtn = WMCreateCustomButton(panel->slidersFrm, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->cmykBtn, 46, 24);
	WMMoveWidget(panel->cmykBtn, 93, 8);
	WMSetButtonAction(panel->cmykBtn, modeButtonCallback, panel);
	WMSetButtonImagePosition(panel->cmykBtn, WIPImageOnly);
	WMSetButtonImage(panel->cmykBtn, scrPtr->cmykIcon);

	panel->hsbBtn = WMCreateCustomButton(panel->slidersFrm, WBBStateLightMask | WBBStateChangeMask);
	WMResizeWidget(panel->hsbBtn, 46, 24);
	WMMoveWidget(panel->hsbBtn, 139, 8);
	WMSetButtonAction(panel->hsbBtn, modeButtonCallback, panel);
	WMSetButtonImagePosition(panel->hsbBtn, WIPImageOnly);
	WMSetButtonImage(panel->hsbBtn, scrPtr->hsbIcon);

	/* Let's Group the Slider Panel Buttons Together */
	WMGroupButtons(panel->grayBtn, panel->rgbBtn);
	WMGroupButtons(panel->grayBtn, panel->cmykBtn);
	WMGroupButtons(panel->grayBtn, panel->hsbBtn);

	textcolor = WMDarkGrayColor(scrPtr);

	/* Widgets for GrayScale Panel */
	panel->grayFrm = WMCreateFrame(panel->slidersFrm);
	WMSetFrameRelief(panel->grayFrm, WRFlat);
	WMResizeWidget(panel->grayFrm, PWIDTH - 8, PHEIGHT - 80 - 26 - 32);
	WMMoveWidget(panel->grayFrm, 0, 34);

	panel->grayMinL = WMCreateLabel(panel->grayFrm);
	WMResizeWidget(panel->grayMinL, 20, 10);
	WMMoveWidget(panel->grayMinL, 2, 2);
	WMSetLabelText(panel->grayMinL, "0");
	WMSetLabelTextAlignment(panel->grayMinL, WALeft);
	WMSetLabelTextColor(panel->grayMinL, textcolor);
	WMSetLabelFont(panel->grayMinL, panel->font8);

	panel->grayMaxL = WMCreateLabel(panel->grayFrm);
	WMResizeWidget(panel->grayMaxL, 40, 10);
	WMMoveWidget(panel->grayMaxL, 104, 2);
	WMSetLabelText(panel->grayMaxL, "100");
	WMSetLabelTextAlignment(panel->grayMaxL, WARight);
	WMSetLabelTextColor(panel->grayMaxL, textcolor);
	WMSetLabelFont(panel->grayMaxL, panel->font8);

	panel->grayBrightnessS = WMCreateSlider(panel->grayFrm);
	WMResizeWidget(panel->grayBrightnessS, 141, 16);
	WMMoveWidget(panel->grayBrightnessS, 2, 14);
	WMSetSliderMinValue(panel->grayBrightnessS, 0);
	WMSetSliderMaxValue(panel->grayBrightnessS, 100);
	WMSetSliderKnobThickness(panel->grayBrightnessS, knobThickness);
	WMSetSliderAction(panel->grayBrightnessS, grayBrightnessSliderCallback, panel);

	from.red = 0;
	from.green = 0;
	from.blue = 0;

	to.red = 255;
	to.green = 255;
	to.blue = 255;

	image = RRenderGradient(141, 16, &from, &to, RGRD_HORIZONTAL);
	pixmap = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	if (pixmap)
		W_PaintText(W_VIEW(panel->grayBrightnessS), pixmap->pixmap,
			    panel->font12, 2, 0, 100, WALeft, scrPtr->white,
			    False, _("Brightness"), strlen(_("Brightness")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->grayBrightnessS, pixmap);
	WMReleasePixmap(pixmap);

	panel->grayBrightnessT = WMCreateTextField(panel->grayFrm);
	WMResizeWidget(panel->grayBrightnessT, 40, 18);
	WMMoveWidget(panel->grayBrightnessT, 146, 13);
	WMSetTextFieldAlignment(panel->grayBrightnessT, WALeft);
	WMAddNotificationObserver(grayBrightnessTextFieldCallback, panel,
				  WMTextDidEndEditingNotification, panel->grayBrightnessT);

	for (i = 0; i < 7; i++) {
		pixmap = WMCreatePixmap(scrPtr, 13, 13, scrPtr->depth, False);

		graybuttoncolor = WMCreateRGBColor(scrPtr, (255 / 6) * i << 8,
						   (255 / 6) * i << 8, (255 / 6) * i << 8, True);
		WMPaintColorSwatch(graybuttoncolor, pixmap->pixmap, 0, 0, 15, 15);
		WMReleaseColor(graybuttoncolor);

		panel->grayPresetBtn[i] = WMCreateCommandButton(panel->grayFrm);
		WMResizeWidget(panel->grayPresetBtn[i], 20, 24);
		WMMoveWidget(panel->grayPresetBtn[i], 2 + (i * 20), 34);
		WMSetButtonAction(panel->grayPresetBtn[i], grayPresetButtonCallback, panel);
		WMSetButtonImage(panel->grayPresetBtn[i], pixmap);
		WMSetButtonImagePosition(panel->grayPresetBtn[i], WIPImageOnly);
		WMReleasePixmap(pixmap);

	}

	/* End of GrayScale Panel */

	/* Widgets for RGB Panel */
	panel->rgbFrm = WMCreateFrame(panel->slidersFrm);
	WMSetFrameRelief(panel->rgbFrm, WRFlat);
	WMResizeWidget(panel->rgbFrm, PWIDTH - 8, PHEIGHT - 80 - 26 - 32);
	WMMoveWidget(panel->rgbFrm, 0, 34);

	panel->rgbMinL = WMCreateLabel(panel->rgbFrm);
	WMResizeWidget(panel->rgbMinL, 20, 10);
	WMMoveWidget(panel->rgbMinL, 2, 2);
	WMSetLabelText(panel->rgbMinL, "0");
	WMSetLabelTextAlignment(panel->rgbMinL, WALeft);
	WMSetLabelTextColor(panel->rgbMinL, textcolor);
	WMSetLabelFont(panel->rgbMinL, panel->font8);

	panel->rgbMaxL = WMCreateLabel(panel->rgbFrm);
	WMResizeWidget(panel->rgbMaxL, 40, 10);
	WMMoveWidget(panel->rgbMaxL, 104, 2);
	WMSetLabelText(panel->rgbMaxL, "255");
	WMSetLabelTextAlignment(panel->rgbMaxL, WARight);
	WMSetLabelTextColor(panel->rgbMaxL, textcolor);
	WMSetLabelFont(panel->rgbMaxL, panel->font8);

	panel->rgbRedS = WMCreateSlider(panel->rgbFrm);
	WMResizeWidget(panel->rgbRedS, 141, 16);
	WMMoveWidget(panel->rgbRedS, 2, 14);
	WMSetSliderMinValue(panel->rgbRedS, 0);
	WMSetSliderMaxValue(panel->rgbRedS, 255);
	WMSetSliderKnobThickness(panel->rgbRedS, knobThickness);
	WMSetSliderAction(panel->rgbRedS, rgbSliderCallback, panel);

	to.red = 255;
	to.green = 0;
	to.blue = 0;

	image = RRenderGradient(141, 16, &from, &to, RGRD_HORIZONTAL);
	pixmap = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	if (pixmap)
		W_PaintText(W_VIEW(panel->rgbRedS), pixmap->pixmap, panel->font12,
			    2, 0, 100, WALeft, scrPtr->white, False, _("Red"), strlen(_("Red")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->rgbRedS, pixmap);
	WMReleasePixmap(pixmap);

	panel->rgbRedT = WMCreateTextField(panel->rgbFrm);
	WMResizeWidget(panel->rgbRedT, 40, 18);
	WMMoveWidget(panel->rgbRedT, 146, 13);
	WMSetTextFieldAlignment(panel->rgbRedT, WALeft);
	WMAddNotificationObserver(rgbTextFieldCallback, panel, WMTextDidEndEditingNotification, panel->rgbRedT);

	panel->rgbGreenS = WMCreateSlider(panel->rgbFrm);
	WMResizeWidget(panel->rgbGreenS, 141, 16);
	WMMoveWidget(panel->rgbGreenS, 2, 36);
	WMSetSliderMinValue(panel->rgbGreenS, 0);
	WMSetSliderMaxValue(panel->rgbGreenS, 255);
	WMSetSliderKnobThickness(panel->rgbGreenS, knobThickness);
	WMSetSliderAction(panel->rgbGreenS, rgbSliderCallback, panel);

	to.red = 0;
	to.green = 255;
	to.blue = 0;

	image = RRenderGradient(141, 16, &from, &to, RGRD_HORIZONTAL);
	pixmap = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	if (pixmap)
		W_PaintText(W_VIEW(panel->rgbGreenS), pixmap->pixmap, panel->font12,
			    2, 0, 100, WALeft, scrPtr->white, False, _("Green"), strlen(_("Green")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->rgbGreenS, pixmap);
	WMReleasePixmap(pixmap);

	panel->rgbGreenT = WMCreateTextField(panel->rgbFrm);
	WMResizeWidget(panel->rgbGreenT, 40, 18);
	WMMoveWidget(panel->rgbGreenT, 146, 35);
	WMSetTextFieldAlignment(panel->rgbGreenT, WALeft);
	WMAddNotificationObserver(rgbTextFieldCallback, panel, WMTextDidEndEditingNotification, panel->rgbGreenT);

	panel->rgbBlueS = WMCreateSlider(panel->rgbFrm);
	WMResizeWidget(panel->rgbBlueS, 141, 16);
	WMMoveWidget(panel->rgbBlueS, 2, 58);
	WMSetSliderMinValue(panel->rgbBlueS, 0);
	WMSetSliderMaxValue(panel->rgbBlueS, 255);
	WMSetSliderKnobThickness(panel->rgbBlueS, knobThickness);
	WMSetSliderAction(panel->rgbBlueS, rgbSliderCallback, panel);

	to.red = 0;
	to.green = 0;
	to.blue = 255;

	image = RRenderGradient(141, 16, &from, &to, RGRD_HORIZONTAL);
	pixmap = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	if (pixmap)
		W_PaintText(W_VIEW(panel->rgbBlueS), pixmap->pixmap, panel->font12,
			    2, 0, 100, WALeft, scrPtr->white, False, _("Blue"), strlen(_("Blue")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->rgbBlueS, pixmap);
	WMReleasePixmap(pixmap);

	panel->rgbBlueT = WMCreateTextField(panel->rgbFrm);
	WMResizeWidget(panel->rgbBlueT, 40, 18);
	WMMoveWidget(panel->rgbBlueT, 146, 57);
	WMSetTextFieldAlignment(panel->rgbBlueT, WALeft);
	WMAddNotificationObserver(rgbTextFieldCallback, panel, WMTextDidEndEditingNotification, panel->rgbBlueT);

	panel->rgbDecB = WMCreateButton(panel->rgbFrm, WBTRadio);
	WMSetButtonText(panel->rgbDecB, _("Decimal"));
	WMSetButtonSelected(panel->rgbDecB, 1);
	panel->rgbState = RGBdec;
	WMSetButtonAction(panel->rgbDecB, rgbDecToHex, panel);
	WMResizeWidget(panel->rgbDecB, PWIDTH - 8, 23);
	WMMoveWidget(panel->rgbDecB, 2, 81);

	panel->rgbHexB = WMCreateButton(panel->rgbFrm, WBTRadio);
	WMSetButtonText(panel->rgbHexB, _("Hexadecimal"));
	WMSetButtonAction(panel->rgbHexB, rgbDecToHex, panel);
	WMResizeWidget(panel->rgbHexB, PWIDTH - 8, 23);
	WMMoveWidget(panel->rgbHexB, 2, 104);

	WMGroupButtons(panel->rgbDecB, panel->rgbHexB);

	/* End of RGB Panel */

	/* Widgets for CMYK Panel */
	panel->cmykFrm = WMCreateFrame(panel->slidersFrm);
	WMSetFrameRelief(panel->cmykFrm, WRFlat);
	WMResizeWidget(panel->cmykFrm, PWIDTH - 8, PHEIGHT - 80 - 26 - 32);
	WMMoveWidget(panel->cmykFrm, 0, 34);

	panel->cmykMinL = WMCreateLabel(panel->cmykFrm);
	WMResizeWidget(panel->cmykMinL, 20, 10);
	WMMoveWidget(panel->cmykMinL, 2, 2);
	WMSetLabelText(panel->cmykMinL, "0");
	WMSetLabelTextAlignment(panel->cmykMinL, WALeft);
	WMSetLabelTextColor(panel->cmykMinL, textcolor);
	WMSetLabelFont(panel->cmykMinL, panel->font8);

	panel->cmykMaxL = WMCreateLabel(panel->cmykFrm);
	WMResizeWidget(panel->cmykMaxL, 40, 10);
	WMMoveWidget(panel->cmykMaxL, 104, 2);
	WMSetLabelText(panel->cmykMaxL, "100");
	WMSetLabelTextAlignment(panel->cmykMaxL, WARight);
	WMSetLabelTextColor(panel->cmykMaxL, textcolor);
	WMSetLabelFont(panel->cmykMaxL, panel->font8);

	panel->cmykCyanS = WMCreateSlider(panel->cmykFrm);
	WMResizeWidget(panel->cmykCyanS, 141, 16);
	WMMoveWidget(panel->cmykCyanS, 2, 14);
	WMSetSliderMinValue(panel->cmykCyanS, 0);
	WMSetSliderMaxValue(panel->cmykCyanS, 100);
	WMSetSliderKnobThickness(panel->cmykCyanS, knobThickness);
	WMSetSliderAction(panel->cmykCyanS, cmykSliderCallback, panel);

	from.red = 255;
	from.green = 255;
	from.blue = 255;

	to.red = 0;
	to.green = 255;
	to.blue = 255;

	image = RRenderGradient(141, 16, &from, &to, RGRD_HORIZONTAL);
	pixmap = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	if (pixmap)
		W_PaintText(W_VIEW(panel->cmykCyanS), pixmap->pixmap, panel->font12,
			    2, 0, 100, WALeft, scrPtr->black, False, _("Cyan"), strlen(_("Cyan")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->cmykCyanS, pixmap);
	WMReleasePixmap(pixmap);

	panel->cmykCyanT = WMCreateTextField(panel->cmykFrm);
	WMResizeWidget(panel->cmykCyanT, 40, 18);
	WMMoveWidget(panel->cmykCyanT, 146, 13);
	WMSetTextFieldAlignment(panel->cmykCyanT, WALeft);
	WMAddNotificationObserver(cmykTextFieldCallback, panel, WMTextDidEndEditingNotification, panel->cmykCyanT);

	panel->cmykMagentaS = WMCreateSlider(panel->cmykFrm);
	WMResizeWidget(panel->cmykMagentaS, 141, 16);
	WMMoveWidget(panel->cmykMagentaS, 2, 36);
	WMSetSliderMinValue(panel->cmykMagentaS, 0);
	WMSetSliderMaxValue(panel->cmykMagentaS, 100);
	WMSetSliderKnobThickness(panel->cmykMagentaS, knobThickness);
	WMSetSliderAction(panel->cmykMagentaS, cmykSliderCallback, panel);

	to.red = 255;
	to.green = 0;
	to.blue = 255;

	image = RRenderGradient(141, 16, &from, &to, RGRD_HORIZONTAL);
	pixmap = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	if (pixmap)
		W_PaintText(W_VIEW(panel->cmykMagentaS), pixmap->pixmap, panel->font12,
			    2, 0, 100, WALeft, scrPtr->black, False, _("Magenta"), strlen(_("Magenta")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->cmykMagentaS, pixmap);
	WMReleasePixmap(pixmap);

	panel->cmykMagentaT = WMCreateTextField(panel->cmykFrm);
	WMResizeWidget(panel->cmykMagentaT, 40, 18);
	WMMoveWidget(panel->cmykMagentaT, 146, 35);
	WMSetTextFieldAlignment(panel->cmykMagentaT, WALeft);
	WMAddNotificationObserver(cmykTextFieldCallback, panel,
				  WMTextDidEndEditingNotification, panel->cmykMagentaT);

	panel->cmykYellowS = WMCreateSlider(panel->cmykFrm);
	WMResizeWidget(panel->cmykYellowS, 141, 16);
	WMMoveWidget(panel->cmykYellowS, 2, 58);
	WMSetSliderMinValue(panel->cmykYellowS, 0);
	WMSetSliderMaxValue(panel->cmykYellowS, 100);
	WMSetSliderKnobThickness(panel->cmykYellowS, knobThickness);
	WMSetSliderAction(panel->cmykYellowS, cmykSliderCallback, panel);

	to.red = 255;
	to.green = 255;
	to.blue = 0;

	image = RRenderGradient(141, 16, &from, &to, RGRD_HORIZONTAL);
	pixmap = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	if (pixmap)
		W_PaintText(W_VIEW(panel->cmykYellowS), pixmap->pixmap, panel->font12,
			    2, 0, 100, WALeft, scrPtr->black, False, _("Yellow"), strlen(_("Yellow")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->cmykYellowS, pixmap);
	WMReleasePixmap(pixmap);

	panel->cmykYellowT = WMCreateTextField(panel->cmykFrm);
	WMResizeWidget(panel->cmykYellowT, 40, 18);
	WMMoveWidget(panel->cmykYellowT, 146, 57);
	WMSetTextFieldAlignment(panel->cmykYellowT, WALeft);
	WMAddNotificationObserver(cmykTextFieldCallback, panel,
				  WMTextDidEndEditingNotification, panel->cmykYellowT);

	panel->cmykBlackS = WMCreateSlider(panel->cmykFrm);
	WMResizeWidget(panel->cmykBlackS, 141, 16);
	WMMoveWidget(panel->cmykBlackS, 2, 80);
	WMSetSliderMinValue(panel->cmykBlackS, 0);
	WMSetSliderMaxValue(panel->cmykBlackS, 100);
	WMSetSliderValue(panel->cmykBlackS, 0);
	WMSetSliderKnobThickness(panel->cmykBlackS, knobThickness);
	WMSetSliderAction(panel->cmykBlackS, cmykSliderCallback, panel);

	to.red = 0;
	to.green = 0;
	to.blue = 0;

	image = RRenderGradient(141, 16, &from, &to, RGRD_HORIZONTAL);
	pixmap = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	if (pixmap)
		W_PaintText(W_VIEW(panel->cmykBlackS), pixmap->pixmap, panel->font12,
			    2, 0, 100, WALeft, scrPtr->black, False, _("Black"), strlen(_("Black")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->cmykBlackS, pixmap);
	WMReleasePixmap(pixmap);

	panel->cmykBlackT = WMCreateTextField(panel->cmykFrm);
	WMResizeWidget(panel->cmykBlackT, 40, 18);
	WMMoveWidget(panel->cmykBlackT, 146, 79);
	WMSetTextFieldAlignment(panel->cmykBlackT, WALeft);
	WMAddNotificationObserver(cmykTextFieldCallback, panel,
				  WMTextDidEndEditingNotification, panel->cmykBlackT);
	/* End of CMYK Panel */

	/* Widgets for HSB Panel */
	panel->hsbFrm = WMCreateFrame(panel->slidersFrm);
	WMSetFrameRelief(panel->hsbFrm, WRFlat);
	WMResizeWidget(panel->hsbFrm, PWIDTH - 8, PHEIGHT - 80 - 26 - 32);
	WMMoveWidget(panel->hsbFrm, 0, 34);

	panel->hsbHueS = WMCreateSlider(panel->hsbFrm);
	WMResizeWidget(panel->hsbHueS, 141, 16);
	WMMoveWidget(panel->hsbHueS, 2, 14);
	WMSetSliderMinValue(panel->hsbHueS, 0);
	WMSetSliderMaxValue(panel->hsbHueS, 359);
	WMSetSliderKnobThickness(panel->hsbHueS, knobThickness);
	WMSetSliderAction(panel->hsbHueS, hsbSliderCallback, panel);

	panel->hsbHueT = WMCreateTextField(panel->hsbFrm);
	WMResizeWidget(panel->hsbHueT, 40, 18);
	WMMoveWidget(panel->hsbHueT, 146, 13);
	WMSetTextFieldAlignment(panel->hsbHueT, WALeft);
	WMAddNotificationObserver(hsbTextFieldCallback, panel, WMTextDidEndEditingNotification, panel->hsbHueT);

	panel->hsbSaturationS = WMCreateSlider(panel->hsbFrm);
	WMResizeWidget(panel->hsbSaturationS, 141, 16);
	WMMoveWidget(panel->hsbSaturationS, 2, 36);
	WMSetSliderMinValue(panel->hsbSaturationS, 0);
	WMSetSliderMaxValue(panel->hsbSaturationS, 100);
	WMSetSliderKnobThickness(panel->hsbSaturationS, knobThickness);
	WMSetSliderAction(panel->hsbSaturationS, hsbSliderCallback, panel);

	panel->hsbSaturationT = WMCreateTextField(panel->hsbFrm);
	WMResizeWidget(panel->hsbSaturationT, 40, 18);
	WMMoveWidget(panel->hsbSaturationT, 146, 35);
	WMSetTextFieldAlignment(panel->hsbSaturationT, WALeft);
	WMAddNotificationObserver(hsbTextFieldCallback, panel,
				  WMTextDidEndEditingNotification, panel->hsbSaturationT);

	panel->hsbBrightnessS = WMCreateSlider(panel->hsbFrm);
	WMResizeWidget(panel->hsbBrightnessS, 141, 16);
	WMMoveWidget(panel->hsbBrightnessS, 2, 58);
	WMSetSliderMinValue(panel->hsbBrightnessS, 0);
	WMSetSliderMaxValue(panel->hsbBrightnessS, 100);
	WMSetSliderKnobThickness(panel->hsbBrightnessS, knobThickness);
	WMSetSliderAction(panel->hsbBrightnessS, hsbSliderCallback, panel);

	panel->hsbBrightnessT = WMCreateTextField(panel->hsbFrm);
	WMResizeWidget(panel->hsbBrightnessT, 40, 18);
	WMMoveWidget(panel->hsbBrightnessT, 146, 57);
	WMSetTextFieldAlignment(panel->hsbBrightnessT, WALeft);
	WMAddNotificationObserver(hsbTextFieldCallback, panel,
				  WMTextDidEndEditingNotification, panel->hsbBrightnessT);
	/* End of HSB Panel */

	WMReleaseColor(textcolor);

	/* Widgets for the CustomPalette Panel */
	panel->customPaletteFrm = WMCreateFrame(panel->win);
	WMSetFrameRelief(panel->customPaletteFrm, WRFlat);
	WMResizeWidget(panel->customPaletteFrm, PWIDTH - 8, PHEIGHT - 80 - 26);
	WMMoveWidget(panel->customPaletteFrm, 5, 80);

	panel->customPaletteHistoryBtn = WMCreatePopUpButton(panel->customPaletteFrm);
	WMAddPopUpButtonItem(panel->customPaletteHistoryBtn, _("Spectrum"));
	WMSetPopUpButtonSelectedItem(panel->customPaletteHistoryBtn,
				     WMGetPopUpButtonNumberOfItems(panel->customPaletteHistoryBtn) - 1);
	WMSetPopUpButtonAction(panel->customPaletteHistoryBtn, customPaletteHistoryCallback, panel);
	WMResizeWidget(panel->customPaletteHistoryBtn, PWIDTH - 8, 20);
	WMMoveWidget(panel->customPaletteHistoryBtn, 0, 0);

	panel->customPaletteContentFrm = WMCreateFrame(panel->customPaletteFrm);
	WMSetFrameRelief(panel->customPaletteContentFrm, WRSunken);
	WMResizeWidget(panel->customPaletteContentFrm, PWIDTH - 8, PHEIGHT - 156);
	WMMoveWidget(panel->customPaletteContentFrm, 0, 23);

	panel->customPaletteContentView = W_CreateView(W_VIEW(panel->customPaletteContentFrm));
	/* XXX Test if we can create a view */
	W_ResizeView(panel->customPaletteContentView, customPaletteWidth, customPaletteHeight);
	W_MoveView(panel->customPaletteContentView, 2, 2);

	/* Create event handler to handle expose/click events in CustomPalette */
	WMCreateEventHandler(panel->customPaletteContentView,
			     ButtonPressMask | ButtonReleaseMask | EnterWindowMask | LeaveWindowMask |
			     ButtonMotionMask, customPaletteHandleActionEvents, panel);

	WMCreateEventHandler(panel->customPaletteContentView, ExposureMask, customPaletteHandleEvents, panel);

	panel->customPaletteMenuBtn = WMCreatePopUpButton(panel->customPaletteFrm);
	WMSetPopUpButtonPullsDown(panel->customPaletteMenuBtn, 1);
	WMSetPopUpButtonText(panel->customPaletteMenuBtn, _("Palette"));
	WMSetPopUpButtonAction(panel->customPaletteMenuBtn, customPaletteMenuCallback, panel);
	WMResizeWidget(panel->customPaletteMenuBtn, PWIDTH - 8, 20);
	WMMoveWidget(panel->customPaletteMenuBtn, 0, PHEIGHT - 130);

	WMAddPopUpButtonItem(panel->customPaletteMenuBtn, _("New from File..."));
	WMAddPopUpButtonItem(panel->customPaletteMenuBtn, _("Rename..."));
	WMAddPopUpButtonItem(panel->customPaletteMenuBtn, _("Remove"));
	WMAddPopUpButtonItem(panel->customPaletteMenuBtn, _("Copy"));
	WMAddPopUpButtonItem(panel->customPaletteMenuBtn, _("New from Clipboard"));

	WMSetPopUpButtonItemEnabled(panel->customPaletteMenuBtn, CPmenuRename, 0);
	WMSetPopUpButtonItemEnabled(panel->customPaletteMenuBtn, CPmenuRemove, 0);
	WMSetPopUpButtonItemEnabled(panel->customPaletteMenuBtn, CPmenuCopy, 0);
	WMSetPopUpButtonItemEnabled(panel->customPaletteMenuBtn, CPmenuNewFromClipboard, 0);

	customRenderSpectrum(panel);
	panel->currentPalette = 0;
	panel->palx = customPaletteWidth / 2;
	panel->paly = customPaletteHeight / 2;

	/* Widgets for the ColorList Panel */
	panel->colorListFrm = WMCreateFrame(panel->win);
	WMSetFrameRelief(panel->colorListFrm, WRFlat);
	WMResizeWidget(panel->colorListFrm, PWIDTH - 8, PHEIGHT - 80 - 26);
	WMMoveWidget(panel->colorListFrm, 5, 80);

	panel->colorListHistoryBtn = WMCreatePopUpButton(panel->colorListFrm);
	WMAddPopUpButtonItem(panel->colorListHistoryBtn, _("X11-Colors"));
	WMSetPopUpButtonSelectedItem(panel->colorListHistoryBtn,
				     WMGetPopUpButtonNumberOfItems(panel->colorListHistoryBtn) - 1);
	/*  WMSetPopUpButtonAction(panel->colorListHistoryBtn,
	 *  colorListHistoryCallback, panel); */
	WMResizeWidget(panel->colorListHistoryBtn, PWIDTH - 8, 20);
	WMMoveWidget(panel->colorListHistoryBtn, 0, 0);

	panel->colorListContentLst = WMCreateList(panel->colorListFrm);
	WMSetListAction(panel->colorListContentLst, colorListSelect, panel);
	WMSetListUserDrawProc(panel->colorListContentLst, colorListPaintItem);
	WMResizeWidget(panel->colorListContentLst, PWIDTH - 8, PHEIGHT - 156);
	WMMoveWidget(panel->colorListContentLst, 0, 23);
	WMHangData(panel->colorListContentLst, panel);

	panel->colorListColorMenuBtn = WMCreatePopUpButton(panel->colorListFrm);
	WMSetPopUpButtonPullsDown(panel->colorListColorMenuBtn, 1);
	WMSetPopUpButtonText(panel->colorListColorMenuBtn, _("Color"));
	WMSetPopUpButtonAction(panel->colorListColorMenuBtn, colorListColorMenuCallback, panel);
	WMResizeWidget(panel->colorListColorMenuBtn, (PWIDTH - 16) / 2, 20);
	WMMoveWidget(panel->colorListColorMenuBtn, 0, PHEIGHT - 130);

	WMAddPopUpButtonItem(panel->colorListColorMenuBtn, _("Add..."));
	WMAddPopUpButtonItem(panel->colorListColorMenuBtn, _("Rename..."));
	WMAddPopUpButtonItem(panel->colorListColorMenuBtn, _("Remove"));

	WMSetPopUpButtonItemEnabled(panel->colorListColorMenuBtn, CLmenuAdd, 0);
	WMSetPopUpButtonItemEnabled(panel->colorListColorMenuBtn, CLmenuRename, 0);
	WMSetPopUpButtonItemEnabled(panel->colorListColorMenuBtn, CLmenuRemove, 0);

	panel->colorListListMenuBtn = WMCreatePopUpButton(panel->colorListFrm);
	WMSetPopUpButtonPullsDown(panel->colorListListMenuBtn, 1);
	WMSetPopUpButtonText(panel->colorListListMenuBtn, _("List"));
	WMSetPopUpButtonAction(panel->colorListListMenuBtn, colorListListMenuCallback, panel);
	WMResizeWidget(panel->colorListListMenuBtn, (PWIDTH - 16) / 2, 20);
	WMMoveWidget(panel->colorListListMenuBtn, (PWIDTH - 16) / 2 + 8, PHEIGHT - 130);

	WMAddPopUpButtonItem(panel->colorListListMenuBtn, _("New..."));
	WMAddPopUpButtonItem(panel->colorListListMenuBtn, _("Rename..."));
	WMAddPopUpButtonItem(panel->colorListListMenuBtn, _("Remove"));

	WMSetPopUpButtonItemEnabled(panel->colorListListMenuBtn, CLmenuAdd, 0);
	WMSetPopUpButtonItemEnabled(panel->colorListListMenuBtn, CLmenuRename, 0);
	WMSetPopUpButtonItemEnabled(panel->colorListListMenuBtn, CLmenuRemove, 0);

	WMRealizeWidget(panel->win);
	WMMapSubwidgets(panel->win);

	WMMapSubwidgets(panel->wheelFrm);
	WMMapSubwidgets(panel->slidersFrm);
	WMMapSubwidgets(panel->grayFrm);
	WMMapSubwidgets(panel->rgbFrm);
	WMMapSubwidgets(panel->cmykFrm);
	WMMapSubwidgets(panel->hsbFrm);
	WMMapSubwidgets(panel->customPaletteFrm);
	WMMapSubwidgets(panel->customPaletteContentFrm);
	WMMapSubwidgets(panel->colorListFrm);

	/* Pixmap to indicate selection positions
	 * wheelframe MUST be mapped.
	 */
	panel->selectionImg = XCreatePixmap(scrPtr->display, WMWidgetXID(panel->win), 4, 4, scrPtr->depth);
	XFillRectangle(scrPtr->display, panel->selectionImg, bgc, 0, 0, 4, 4);
	XFillRectangle(scrPtr->display, panel->selectionImg, wgc, 1, 1, 2, 2);

	readConfiguration(panel);
	readXColors(panel);

	return panel;
}

WMColorPanel *WMGetColorPanel(WMScreen * scrPtr)
{
	WMColorPanel *panel;

	if (scrPtr->sharedColorPanel)
		return scrPtr->sharedColorPanel;

	panel = makeColorPanel(scrPtr, "colorPanel");

	scrPtr->sharedColorPanel = panel;

	return panel;
}

void WMFreeColorPanel(WMColorPanel * panel)
{
	W_Screen *scr;

	if (!panel)
		return;

	scr = WMWidgetScreen(panel->win);
	if (panel == scr->sharedColorPanel) {
		scr->sharedColorPanel = NULL;
	}

	WMRemoveNotificationObserver(panel);
	WMUnmapWidget(panel->win);

	/* fonts */
	WMReleaseFont(panel->font8);
	WMReleaseFont(panel->font12);

	/* pixmaps */
	wheelDestroyMatrix(panel->wheelMtrx);
	if (panel->wheelImg)
		XFreePixmap(scr->display, panel->wheelImg);
	if (panel->selectionImg)
		XFreePixmap(scr->display, panel->selectionImg);
	if (panel->selectionBackImg)
		XFreePixmap(scr->display, panel->selectionBackImg);
	RReleaseImage(panel->customPaletteImg);

	/* structs */
	if (panel->lastBrowseDir)
		wfree(panel->lastBrowseDir);
	if (panel->configurationPath)
		wfree(panel->configurationPath);

	WMDestroyWidget(panel->win);

	wfree(panel);
}

void WMCloseColorPanel(WMColorPanel * panel)
{
	WMFreeColorPanel(panel);
}

void WMShowColorPanel(WMColorPanel * panel)
{
	WMScreen *scr = WMWidgetScreen(panel->win);
	WMColor *white = WMWhiteColor(scr);

	if (panel->color.set == cpNone)
		WMSetColorPanelColor(panel, white);
	WMReleaseColor(white);

	if (panel->mode != WMWheelModeColorPanel)
		WMPerformButtonClick(panel->wheelBtn);

	WMMapWidget(panel->win);
}

static void closeWindowCallback(WMWidget * w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	WMCloseColorPanel(panel);
}

static void readConfiguration(W_ColorPanel * panel)
{
	/* XXX Doesn't take care of "invalid" files */

	DIR *dPtr;
	struct dirent *dp;
	struct stat stat_buf;
	int item;

	if (stat(panel->configurationPath, &stat_buf) != 0) {
		if (mkdir(panel->configurationPath, S_IRWXU | S_IRGRP | S_IROTH | S_IXGRP | S_IXOTH) != 0) {
			werror(_("Color Panel: Could not create directory %s needed"
				    " to store configurations"), panel->configurationPath);
			WMSetPopUpButtonEnabled(panel->customPaletteMenuBtn, False);
			WMSetPopUpButtonEnabled(panel->colorListColorMenuBtn, False);
			WMSetPopUpButtonEnabled(panel->colorListListMenuBtn, False);
			WMRunAlertPanel(WMWidgetScreen(panel->win), panel->win,
					_("File Error"),
					_("Could not create ColorPanel configuration directory"),
					_("OK"), NULL, NULL);
		}
		return;
	}

	if (!(dPtr = opendir(panel->configurationPath))) {
		wwarning("%s: %s", _("Color Panel: Could not find file"), panel->configurationPath);
		return;
	}

	while ((dp = readdir(dPtr)) != NULL) {
		unsigned int perm_mask;
		char *path = wstrconcat(panel->configurationPath,
					dp->d_name);

		if (dp->d_name[0] != '.') {
			item = WMGetPopUpButtonNumberOfItems(panel->customPaletteHistoryBtn);
			WMAddPopUpButtonItem(panel->customPaletteHistoryBtn, dp->d_name);

			perm_mask = (access(path, R_OK) == 0);
			WMSetPopUpButtonItemEnabled(panel->customPaletteHistoryBtn, item, perm_mask);
		}
		wfree(path);
	}
	closedir(dPtr);
}

static void readXColors(W_ColorPanel * panel)
{
	WMListItem *item;
	const RGBColor *entry;

	for (entry = rgbColors; entry->name != NULL; entry++) {
		item = WMAddListItem(panel->colorListContentLst, entry->name);
		item->clientData = (void *)&(entry->color);
	}
}

void WMSetColorPanelPickerMode(WMColorPanel * panel, WMColorPanelMode mode)
{
	W_Screen *scr = WMWidgetScreen(panel->win);

	if (mode != WMWheelModeColorPanel) {
		WMUnmapWidget(panel->wheelFrm);
		if (panel->selectionBackImg) {
			XFreePixmap(WMWidgetScreen(panel->win)->display, panel->selectionBackImg);
			panel->selectionBackImg = None;
		}
	}
	if (mode != WMGrayModeColorPanel)
		WMUnmapWidget(panel->grayFrm);
	if (mode != WMRGBModeColorPanel)
		WMUnmapWidget(panel->rgbFrm);
	if (mode != WMCMYKModeColorPanel)
		WMUnmapWidget(panel->cmykFrm);
	if (mode != WMHSBModeColorPanel)
		WMUnmapWidget(panel->hsbFrm);
	if (mode != WMCustomPaletteModeColorPanel) {
		WMUnmapWidget(panel->customPaletteFrm);
		if (panel->selectionBackImg) {
			XFreePixmap(WMWidgetScreen(panel->win)->display, panel->selectionBackImg);
			panel->selectionBackImg = None;
		}
	}
	if (mode != WMColorListModeColorPanel)
		WMUnmapWidget(panel->colorListFrm);
	if ((mode != WMGrayModeColorPanel) && (mode != WMRGBModeColorPanel) &&
	    (mode != WMCMYKModeColorPanel) && (mode != WMHSBModeColorPanel))
		WMUnmapWidget(panel->slidersFrm);
	else
		panel->slidersmode = mode;

	if (mode == WMWheelModeColorPanel) {
		WMMapWidget(panel->wheelFrm);
		WMSetButtonSelected(panel->wheelBtn, True);
		if (panel->lastChanged != WMWheelModeColorPanel)
			wheelInit(panel);
		wheelRender(panel);
		wheelPaint(panel);
	} else if (mode == WMGrayModeColorPanel) {
		WMMapWidget(panel->slidersFrm);
		WMSetButtonSelected(panel->slidersBtn, True);
		WMMapWidget(panel->grayFrm);
		WMSetButtonSelected(panel->grayBtn, True);
		WMSetButtonImage(panel->slidersBtn, scr->grayIcon);
		if (panel->lastChanged != WMGrayModeColorPanel)
			grayInit(panel);
	} else if (mode == WMRGBModeColorPanel) {
		WMMapWidget(panel->slidersFrm);
		WMSetButtonSelected(panel->slidersBtn, True);
		WMMapWidget(panel->rgbFrm);
		WMSetButtonSelected(panel->rgbBtn, True);
		WMSetButtonImage(panel->slidersBtn, scr->rgbIcon);
		if (panel->lastChanged != WMRGBModeColorPanel)
			rgbInit(panel);
	} else if (mode == WMCMYKModeColorPanel) {
		WMMapWidget(panel->slidersFrm);
		WMSetButtonSelected(panel->slidersBtn, True);
		WMMapWidget(panel->cmykFrm);
		WMSetButtonSelected(panel->cmykBtn, True);
		WMSetButtonImage(panel->slidersBtn, scr->cmykIcon);
		if (panel->lastChanged != WMCMYKModeColorPanel)
			cmykInit(panel);
	} else if (mode == WMHSBModeColorPanel) {
		WMMapWidget(panel->slidersFrm);
		WMSetButtonSelected(panel->slidersBtn, True);
		WMMapWidget(panel->hsbFrm);
		WMSetButtonSelected(panel->hsbBtn, True);
		WMSetButtonImage(panel->slidersBtn, scr->hsbIcon);
		if (panel->lastChanged != WMHSBModeColorPanel)
			hsbInit(panel);
	} else if (mode == WMCustomPaletteModeColorPanel) {
		WMMapWidget(panel->customPaletteFrm);
		WMSetButtonSelected(panel->customPaletteBtn, True);
		customSetPalette(panel);
	} else if (mode == WMColorListModeColorPanel) {
		WMMapWidget(panel->colorListFrm);
		WMSetButtonSelected(panel->colorListBtn, True);
	}

	panel->mode = mode;
}

WMColor *WMGetColorPanelColor(WMColorPanel * panel)
{
	return WMGetColorWellColor(panel->colorWell);
}

void WMSetColorPanelColor(WMColorPanel * panel, WMColor * color)
{
	WMSetColorWellColor(panel->colorWell, color);

	panel->color.rgb.red = color->color.red >> 8;
	panel->color.rgb.green = color->color.green >> 8;
	panel->color.rgb.blue = color->color.blue >> 8;
	panel->color.set = cpRGB;

	if (panel->mode == panel->lastChanged)
		panel->lastChanged = 0;

	WMSetColorPanelPickerMode(panel, panel->mode);
}

static void updateSwatch(WMColorPanel * panel, CPColor color)
{
	WMScreen *scr = WMWidgetScreen(panel->win);
	WMColor *wellcolor;

	if (color.set != cpRGB)
		convertCPColor(&color);

	panel->color = color;

	wellcolor = WMCreateRGBColor(scr, color.rgb.red << 8, color.rgb.green << 8, color.rgb.blue << 8, True);

	WMSetColorWellColor(panel->colorWell, wellcolor);
	WMReleaseColor(wellcolor);

	if (!panel->flags.dragging || panel->flags.continuous) {
		if (panel->action)
			(*panel->action) (panel, panel->clientData);

		WMPostNotificationName(WMColorPanelColorChangedNotification, panel, NULL);
	}
}

static void modeButtonCallback(WMWidget * w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) (data);

	if (w == panel->wheelBtn)
		WMSetColorPanelPickerMode(panel, WMWheelModeColorPanel);
	else if (w == panel->slidersBtn)
		WMSetColorPanelPickerMode(panel, panel->slidersmode);
	else if (w == panel->customPaletteBtn)
		WMSetColorPanelPickerMode(panel, WMCustomPaletteModeColorPanel);
	else if (w == panel->colorListBtn)
		WMSetColorPanelPickerMode(panel, WMColorListModeColorPanel);
	else if (w == panel->grayBtn)
		WMSetColorPanelPickerMode(panel, WMGrayModeColorPanel);
	else if (w == panel->rgbBtn)
		WMSetColorPanelPickerMode(panel, WMRGBModeColorPanel);
	else if (w == panel->cmykBtn)
		WMSetColorPanelPickerMode(panel, WMCMYKModeColorPanel);
	else if (w == panel->hsbBtn)
		WMSetColorPanelPickerMode(panel, WMHSBModeColorPanel);
}

/******************  Magnifying Cursor Functions *******************/

static XImage *magnifyGetImage(WMScreen * scr, XImage * image, int x, int y, int w, int h)
{
	int x0 = 0, y0 = 0, w0 = w, h0 = h;
	const int displayWidth = DisplayWidth(scr->display, scr->screen),
	    displayHeight = DisplayHeight(scr->display, scr->screen);

	if (!(image && image->data)) {
		/* The image in panel->magnifyGlass->image does not exist yet.
		 * Grab one from the screen (not beyond) and use it from now on.
		 */
		if (!(image = XGetImage(scr->display, scr->rootWin,
					x - Cursor_x_hot, y - Cursor_y_hot, w, h, AllPlanes, ZPixmap)))
			wwarning(_("Color Panel: X failed request"));

		return image;
	}

	/* Coordinate correction for back pixmap
	 * if magnifying glass is at screen-borders
	 */

	/* Figure 1: Shifting of rectangle-to-grab at top/left screen borders
	 * Hatched area is beyond screen border.
	 *
	 * |<-Cursor_x_hot->|
	 *  ________________|_____
	 * |/ / / / / / /|  |     |
	 * | / / / / / / |(x,y)   |
	 * |/_/_/_/_/_/_/|________|
	 * |<----x0----->|<--w0-->|
	 *               0
	 */

	/* Figure 2: Shifting of rectangle-to-grab at bottom/right
	 * screen borders
	 * Hatched area is beyond screen border
	 *
	 * |<-Cursor_x_hot->|
	 *  ________________|_______________
	 * |                |  | / / / / / /|
	 * |              (x,y)|/ / / / / / |
	 * |___________________|_/_/_/_/_/_/|
	 * |<-------w0-------->|            |
	 * |<---------------w--|----------->|
	 * |                   |
	 * x0                  Displaywidth-1
	 */

	if (x < Cursor_x_hot) {	/* see fig. 1 */
		x0 = Cursor_x_hot - x;
		w0 = w - x0;
	}

	if (displayWidth - 1 < x - Cursor_x_hot + w) {	/* see fig. 2 */
		w0 = (displayWidth) - (x - Cursor_x_hot);
	}

	if (y < Cursor_y_hot) {	/* see fig. 1 */
		y0 = Cursor_y_hot - y;
		h0 = h - y0;
	}

	if (displayHeight - 1 < y - Cursor_y_hot + h) {	/* see fig. 2 */
		h0 = (displayHeight) - (y - Cursor_y_hot);
	}
	/* end of coordinate correction */

	/* Grab an image from the screen, clipped if necessary,
	 * and put it in the existing panel->magnifyGlass->image
	 * with the corresponding clipping offset.
	 */
	if (!XGetSubImage(scr->display, scr->rootWin,
			  x - Cursor_x_hot + x0, y - Cursor_y_hot + y0, w0, h0, AllPlanes, ZPixmap, image, x0, y0))
		wwarning(_("Color Panel: X failed request"));

	return NULL;
}

static void magnifyGetImageStored(WMColorPanel * panel, int x1, int y1, int x2, int y2)
{
	/* (x1, y1) = topleft corner of existing rectangle
	 * (x2, y2) = topleft corner of new position
	 */

	W_Screen *scr = WMWidgetScreen(panel->win);
	int xa = 0, ya = 0, xb = 0, yb = 0;
	int width, height;
	const int dx = abs(x2 - x1), dy = abs(y2 - y1);
	XImage *image;
	const int x_min = Cursor_x_hot,
	    y_min = Cursor_y_hot,
	    x_max = DisplayWidth(scr->display, scr->screen) - 1 -
	    (Cursor_mask_width - Cursor_x_hot),
	    y_max = DisplayHeight(scr->display, scr->screen) - 1 - (Cursor_mask_height - Cursor_y_hot);

	if ((dx == 0) && (dy == 0) && panel->magnifyGlass->image)
		return;		/* No movement */

	if (x1 < x2)
		xa = dx;
	else
		xb = dx;

	if (y1 < y2)
		ya = dy;
	else
		yb = dy;

	width = Cursor_mask_width - dx;
	height = Cursor_mask_height - dy;

	/* If the traversed distance is larger than the size of the magnifying
	 * glass contents, there is no need to do dirty rectangles. A whole new
	 * rectangle can be grabbed (unless that rectangle falls partially
	 * off screen).
	 * Destroying the image and setting it to NULL will achieve that later on.
	 *
	 * Of course, grabbing an XImage beyond the borders of the screen will
	 * cause trouble, this is considdered a special case. Part of the screen
	 * is grabbed, but there is no need for dirty rectangles.
	 */
	if ((width <= 0) || (height <= 0)) {
		if ((x2 >= x_min) && (y2 >= y_min) && (x2 <= x_max) && (y2 <= y_max)) {
			if (panel->magnifyGlass->image)
				XDestroyImage(panel->magnifyGlass->image);
			panel->magnifyGlass->image = NULL;
		}
	} else {
		if (panel->magnifyGlass->image) {
			/* Get dirty rectangle from panel->magnifyGlass->image */
			panel->magnifyGlass->dirtyRect =
			    XSubImage(panel->magnifyGlass->image, xa, ya, width, height);
			if (!panel->magnifyGlass->dirtyRect) {
				wwarning(_("Color Panel: X failed request"));
				return;	/* X returned a NULL from XSubImage */
			}
		}
	}

	/* Get image from screen */
	image = magnifyGetImage(scr, panel->magnifyGlass->image, x2, y2, Cursor_mask_width, Cursor_mask_height);
	if (image) {		/* Only reassign if a *new* image was grabbed */
		panel->magnifyGlass->image = image;
		return;
	}

	/* Copy previously stored rectangle on covered part of image */
	if (panel->magnifyGlass->image && panel->magnifyGlass->dirtyRect) {
		int old_height;

		/* "width" and "height" are used as coordinates here,
		 * and run from [0...width-1] and [0...height-1] respectively.
		 */
		width--;
		height--;
		old_height = height;

		for (; width >= 0; width--)
			for (height = old_height; height >= 0; height--)
				XPutPixel(panel->magnifyGlass->image, xb + width, yb + height,
					  XGetPixel(panel->magnifyGlass->dirtyRect, width, height));
		XDestroyImage(panel->magnifyGlass->dirtyRect);
		panel->magnifyGlass->dirtyRect = NULL;
	}

	return;
}

static Pixmap magnifyCreatePixmap(WMColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	int u, v;
#ifndef USE_XSHAPE
	Pixmap pixmap;
#endif
	unsigned long color;

	if (!panel->magnifyGlass->image)
		return None;

	if (!panel->magnifyGlass->magPix)
		return None;

	/*
	 * Copy an area of only 5x5 pixels from the center of the image.
	 */
	for (u = 0; u < 5; u++) {
		for (v = 0; v < 5; v++) {
			color = XGetPixel(panel->magnifyGlass->image, u + 9, v + 9);

			XSetForeground(scr->display, scr->copyGC, color);

			if ((u == 2) && (v == 2))	/* (2,2) is center pixel (unmagn.) */
				panel->magnifyGlass->color = ulongToRColor(scr, color);

			/* The center square must eventually be centered around the
			 * hotspot. The image needs shifting to achieve this. The amount of
			 * shifting is (Cursor_mask_width/2 - 2 * square_size) = 11-10 = 1
			 *  _ _ _ _ _
			 * |_|_|_|_|_|
			 *      ^------- center of center square == Cursor_x_hot
			 */
			XFillRectangle(scr->display, panel->magnifyGlass->magPix,
				       scr->copyGC,
				       u * 5 + (u == 0 ? 0 : -1), v * 5 + (v == 0 ? 0 : -1),
				       (u == 0 ? 4 : 5), (v == 0 ? 4 : 5));
		}
	}

#ifdef USE_XSHAPE
	return panel->magnifyGlass->magPix;
#else
	pixmap = XCreatePixmap(scr->display, W_DRAWABLE(scr), Cursor_mask_width, Cursor_mask_height, scr->depth);
	if (!pixmap)
		return None;

	XPutImage(scr->display, pixmap, scr->copyGC, panel->magnifyGlass->image,
		  0, 0, 0, 0, Cursor_mask_width, Cursor_mask_height);

	/* Copy the magnified pixmap, with the clip mask, to background pixmap */
	XCopyArea(scr->display, panel->magnifyGlass->magPix, pixmap,
		  scr->clipGC, 0, 0, Cursor_mask_width, Cursor_mask_height, 0, 0);
	/* (2,2) puts center pixel on center of glass */

	return pixmap;
#endif

}

static WMView *magnifyCreateView(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	WMView *magView;

	magView = W_CreateTopView(scr);
	if (!magView)
		return NULL;

	magView->self = panel->win;
	magView->flags.topLevel = 1;
	magView->attribFlags |= CWOverrideRedirect | CWSaveUnder;
	magView->attribs.override_redirect = True;
	magView->attribs.save_under = True;

	W_ResizeView(magView, Cursor_mask_width, Cursor_mask_height);

	W_RealizeView(magView);

	return magView;
}

static Cursor magnifyGrabPointer(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	Pixmap magPixmap, magPixmap2;
	Cursor magCursor;
	XColor fgColor = { 0, 0, 0, 0, DoRed | DoGreen | DoBlue, 0 };
	XColor bgColor = { 0, 0xbf00, 0xa000, 0x5000, DoRed | DoGreen | DoBlue, 0 };

	/* Cursor creation stuff */
	magPixmap = XCreatePixmapFromBitmapData(scr->display, W_DRAWABLE(scr),
						(char *)Cursor_bits, Cursor_width, Cursor_height, 1, 0, 1);
	magPixmap2 = XCreatePixmapFromBitmapData(scr->display, W_DRAWABLE(scr),
						 (char *)Cursor_shape_bits, Cursor_width, Cursor_height, 1, 0, 1);

	magCursor = XCreatePixmapCursor(scr->display, magPixmap, magPixmap2,
					&fgColor, &bgColor, Cursor_x_hot, Cursor_y_hot);

	XFreePixmap(scr->display, magPixmap);
	XFreePixmap(scr->display, magPixmap2);

	XRecolorCursor(scr->display, magCursor, &fgColor, &bgColor);

	/* Set up Pointer */
	XGrabPointer(scr->display, panel->magnifyGlass->view->window, True,
		     PointerMotionMask | ButtonPressMask,
		     GrabModeAsync, GrabModeAsync, scr->rootWin, magCursor, CurrentTime);

	return magCursor;
}

static WMPoint magnifyInitialize(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	int x, y, u, v;
	unsigned int mask;
	Pixmap pixmap, clip_mask;
	WMPoint point;
	Window root_return, child_return;

	clip_mask = XCreatePixmapFromBitmapData(scr->display, W_DRAWABLE(scr),
						(char *)Cursor_mask_bits, Cursor_mask_width, Cursor_mask_height,
						1, 0, 1);
	panel->magnifyGlass->magPix = XCreatePixmap(scr->display, W_DRAWABLE(scr),
						    5 * 5 - 1, 5 * 5 - 1, scr->depth);

	XQueryPointer(scr->display, scr->rootWin, &root_return, &child_return, &x, &y, &u, &v, &mask);

	panel->magnifyGlass->image = NULL;

	/* Clipmask to make magnified view-contents circular */
#ifdef USE_XSHAPE
	XShapeCombineMask(scr->display, WMViewXID(panel->magnifyGlass->view),
			  ShapeBounding, 0, 0, clip_mask, ShapeSet);
#else
	/* Clip circle in glass cursor */
	XSetClipMask(scr->display, scr->clipGC, clip_mask);
	XSetClipOrigin(scr->display, scr->clipGC, 0, 0);
#endif

	XFreePixmap(scr->display, clip_mask);

	/* Draw initial magnifying glass contents */
	magnifyGetImageStored(panel, x, y, x, y);

	pixmap = magnifyCreatePixmap(panel);
	XSetWindowBackgroundPixmap(scr->display, WMViewXID(panel->magnifyGlass->view), pixmap);
	XClearWindow(scr->display, WMViewXID(panel->magnifyGlass->view));
	XFlush(scr->display);

#ifndef USE_XSHAPE
	XFreePixmap(scr->display, pixmap);
#endif

	point.x = x;
	point.y = y;

	return point;
}

static void magnifyPutCursor(WMWidget * w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) (data);
	W_Screen *scr = WMWidgetScreen(panel->win);
	Cursor magCursor;
	Pixmap pixmap;
	XEvent event;
	WMPoint initialPosition;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	/* Destroy wheelBackImg, so it'll update properly */
	if (panel->selectionBackImg) {
		XFreePixmap(WMWidgetScreen(panel->win)->display, panel->selectionBackImg);
		panel->selectionBackImg = None;
	}

	/* Create magnifying glass */
	panel->magnifyGlass = wmalloc(sizeof(MovingView));
	panel->magnifyGlass->view = magnifyCreateView(panel);
	if (!panel->magnifyGlass->view)
		return;

	initialPosition = magnifyInitialize(panel);
	panel->magnifyGlass->x = initialPosition.x;
	panel->magnifyGlass->y = initialPosition.y;

	W_MoveView(panel->magnifyGlass->view,
		   panel->magnifyGlass->x - Cursor_x_hot, panel->magnifyGlass->y - Cursor_y_hot);
	W_MapView(panel->magnifyGlass->view);

	magCursor = magnifyGrabPointer(panel);

	while (panel->magnifyGlass->image) {
		WMNextEvent(scr->display, &event);

		/* Pack motion events */
		while (XCheckTypedEvent(scr->display, MotionNotify, &event)) {
		}

		switch (event.type) {
		case ButtonPress:
			XDestroyImage(panel->magnifyGlass->image);
			panel->magnifyGlass->image = NULL;

			if (event.xbutton.button == Button1) {
				panel->color.rgb = panel->magnifyGlass->color;
				panel->color.set = cpRGB;
				updateSwatch(panel, panel->color);
			}
			switch (panel->mode) {
			case WMWheelModeColorPanel:
				wheelInit(panel);
				wheelRender(panel);
				wheelPaint(panel);
				break;
			case WMGrayModeColorPanel:
				grayInit(panel);
				break;
			case WMRGBModeColorPanel:
				rgbInit(panel);
				break;
			case WMCMYKModeColorPanel:
				cmykInit(panel);
				break;
			case WMHSBModeColorPanel:
				hsbInit(panel);
				break;
			default:
				break;
			}
			panel->lastChanged = panel->mode;

			WMSetButtonSelected(panel->magnifyBtn, False);
			break;

		case MotionNotify:
			while (XPending(event.xmotion.display)) {
				XEvent ev;
				XPeekEvent(event.xmotion.display, &ev);
				if (ev.type == MotionNotify)
					XNextEvent(event.xmotion.display, &event);
				else
					break;
			}

			/* Get a "dirty rectangle" */
			magnifyGetImageStored(panel,
					      panel->magnifyGlass->x, panel->magnifyGlass->y,
					      event.xmotion.x_root, event.xmotion.y_root);

			/* Update coordinates */
			panel->magnifyGlass->x = event.xmotion.x_root;
			panel->magnifyGlass->y = event.xmotion.y_root;

			/* Move view */
			W_MoveView(panel->magnifyGlass->view,
				   panel->magnifyGlass->x - Cursor_x_hot, panel->magnifyGlass->y - Cursor_y_hot);

			/* Put new image (with magn.) in view */
			pixmap = magnifyCreatePixmap(panel);
			if (pixmap != None) {
				/* Change the window background */
				XSetWindowBackgroundPixmap(scr->display,
							   WMViewXID(panel->magnifyGlass->view), pixmap);
				/* Force an Expose (handled by X) */
				XClearWindow(scr->display, WMViewXID(panel->magnifyGlass->view));
				/* Synchronize the event queue, so the Expose is handled NOW */
				XFlush(scr->display);
#ifndef USE_XSHAPE
				XFreePixmap(scr->display, pixmap);
#endif
			}
			break;

			/* Try XQueryPointer for this !!! It returns windows that the pointer
			 * is over. Note: We found this solving the invisible donkey cap bug
			 */
#if 0				/* As it is impossible to make this work in all cases,
				 * we consider it confusing. Therefore we disabled it.
				 */
		case FocusOut:	/* fall through */
		case FocusIn:
			/*
			 * Color Panel window (panel->win) lost or received focus.
			 * We need to update the pixmap in the magnifying glass.
			 *
			 * BUG Doesn't work with focus switches between two windows
			 * if none of them is the color panel.
			 */
			XUngrabPointer(scr->display, CurrentTime);
			W_UnmapView(panel->magnifyGlass->view);

			magnifyInitialize(panel);

			W_MapView(panel->magnifyGlass->view);
			XGrabPointer(scr->display, panel->magnifyGlass->view->window,
				     True, PointerMotionMask | ButtonPressMask,
				     GrabModeAsync, GrabModeAsync, scr->rootWin, magCursor, CurrentTime);
			break;
#endif
		default:
			WMHandleEvent(&event);
			break;
		}		/* of switch */
	}

	XUngrabPointer(scr->display, CurrentTime);
	XFreeCursor(scr->display, magCursor);

	XFreePixmap(scr->display, panel->magnifyGlass->magPix);
	panel->magnifyGlass->magPix = None;

	W_UnmapView(panel->magnifyGlass->view);
	W_DestroyView(panel->magnifyGlass->view);
	panel->magnifyGlass->view = NULL;

	wfree(panel->magnifyGlass);
}

/******************  ColorWheel Functions  ************************/

static wheelMatrix *wheelCreateMatrix(unsigned int width, unsigned int height)
{
	wheelMatrix *matrix = NULL;
	int i;

	assert((width > 0) && (height > 0));

	matrix = wmalloc(sizeof(wheelMatrix));
	matrix->width = width;
	matrix->height = height;

	for (i = 0; i < 3; i++) {
		matrix->data[i] = wmalloc(width * height * sizeof(unsigned char));
	}

	return matrix;
}

static void wheelDestroyMatrix(wheelMatrix * matrix)
{
	int i;

	if (!matrix)
		return;

	for (i = 0; i < 3; i++) {
		if (matrix->data[i])
			wfree(matrix->data[i]);
	}
	wfree(matrix);
}

static void wheelInitMatrix(W_ColorPanel * panel)
{
	int i;
	int x, y;
	unsigned char *rp, *gp, *bp;
	CPColor cpColor;
	long ofs[4];
	int xcor, ycor;
	unsigned short sat;
	int dhue[4];
	const int cw_halfsize = (colorWheelSize + 4) / 2,
	    cw_sqsize = (colorWheelSize + 4) * (colorWheelSize + 4), uchar_shift = getShift(sizeof(unsigned char));

	if (!panel->wheelMtrx)
		return;

	cpColor.hsv.value = 255;
	cpColor.set = cpHSV;

	ofs[0] = -1;
	ofs[1] = -(colorWheelSize + 4);

	/* offsets are counterclockwise (in triangles).
	 *
	 *     ofs[0] ---->
	 *      _______________________________________
	 * [1] |_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|  o
	 *  s  |_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|  f
	 *  f  |_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|  s
	 *  o  | | | | | | | | | | | | | | | | | | | | | [3]
	 *
	 *                                  <---- ofs[2]
	 *       ____
	 *      |\  /| <-- triangles
	 *      | \/ |
	 *      | /\ |
	 *      |/__\|
	 */

	for (y = 0; y < cw_halfsize; y++) {
		for (x = y; x < (colorWheelSize + 4 - y); x++) {
			/* (xcor, ycor) is (x,y) relative to center of matrix */
			xcor = 2 * x - 4 - colorWheelSize;
			ycor = 2 * y - 4 - colorWheelSize;

			/* RColor.saturation is unsigned char and will wrap after 255 */
			sat = rint(255.0 * sqrt(xcor * xcor + ycor * ycor) / colorWheelSize);

			cpColor.hsv.saturation = (unsigned char)sat;

			ofs[0]++;	/* top quarter of matrix */
			ofs[1] += colorWheelSize + 4;	/* left quarter */
			ofs[2] = cw_sqsize - 1 - ofs[0];	/* bottom quarter */
			ofs[3] = cw_sqsize - 1 - ofs[1];	/* right quarter */

			if (sat < 256) {
				if (xcor != 0)
					dhue[0] = rint(atan((double)ycor / (double)xcor) *
						       (180.0 / WM_PI)) + (xcor < 0 ? 180.0 : 0.0);
				else
					dhue[0] = 270;

				dhue[0] = 360 - dhue[0];	/* Reverse direction of ColorWheel */
				dhue[1] = 270 - dhue[0] + (dhue[0] > 270 ? 360 : 0);
				dhue[2] = dhue[0] - 180 + (dhue[0] < 180 ? 360 : 0);
				dhue[3] = 90 - dhue[0] + (dhue[0] > 90 ? 360 : 0);

				for (i = 0; i < 4; i++) {
					rp = panel->wheelMtrx->data[0] + (ofs[i] << uchar_shift);
					gp = panel->wheelMtrx->data[1] + (ofs[i] << uchar_shift);
					bp = panel->wheelMtrx->data[2] + (ofs[i] << uchar_shift);

					cpColor.hsv.hue = dhue[i];
					convertCPColor(&cpColor);

					*rp = (unsigned char)(cpColor.rgb.red);
					*gp = (unsigned char)(cpColor.rgb.green);
					*bp = (unsigned char)(cpColor.rgb.blue);
				}
			} else {
				for (i = 0; i < 4; i++) {
					rp = panel->wheelMtrx->data[0] + (ofs[i] << uchar_shift);
					gp = panel->wheelMtrx->data[1] + (ofs[i] << uchar_shift);
					bp = panel->wheelMtrx->data[2] + (ofs[i] << uchar_shift);

					*rp = (unsigned char)0;
					*gp = (unsigned char)0;
					*bp = (unsigned char)0;
				}
			}
		}

		ofs[0] += 2 * y + 1;
		ofs[1] += 1 - (colorWheelSize + 4) * (colorWheelSize + 4 - 1 - 2 * y);
	}
}

static void wheelCalculateValues(W_ColorPanel * panel, int maxvalue)
{
	unsigned int i;
	unsigned int v;

	for (i = 0; i < 256; i++) {
		/* We divide by 128 in advance, and check whether that number divides
		 * by 2 properly. If not, we add one to round the number correctly
		 */
		v = (i * maxvalue) >> 7;
		panel->wheelMtrx->values[i] = (unsigned char)((v >> 1) + (v & 0x01));
	}
}

static void wheelRender(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	int x, y;
	RImage *image;
	unsigned char *ptr;
	RColor gray;
	unsigned long ofs = 0;
	/*unsigned char     shift = getShift(sizeof(unsigned char)); */

	image = RCreateImage(colorWheelSize + 4, colorWheelSize + 4, True);
	if (!image) {
		wwarning(_("Color Panel: Could not allocate memory"));
		return;
	}

	ptr = image->data;

	/* TODO Make this transparent istead of gray */
	gray.red = gray.blue = 0xae;
	gray.green = 0xaa;

	for (y = 0; y < colorWheelSize + 4; y++) {
		for (x = 0; x < colorWheelSize + 4; x++) {
			if (wheelInsideColorWheel(panel, ofs)) {
				*(ptr++) =
				    (unsigned char)(panel->wheelMtrx->values[panel->wheelMtrx->data[0][ofs]]);
				*(ptr++) =
				    (unsigned char)(panel->wheelMtrx->values[panel->wheelMtrx->data[1][ofs]]);
				*(ptr++) =
				    (unsigned char)(panel->wheelMtrx->values[panel->wheelMtrx->data[2][ofs]]);
				*(ptr++) = 0;
			} else {
				*(ptr++) = (unsigned char)(gray.red);
				*(ptr++) = (unsigned char)(gray.green);
				*(ptr++) = (unsigned char)(gray.blue);
				*(ptr++) = 255;
			}
			ofs++;
		}
	}

	if (panel->wheelImg)
		XFreePixmap(scr->display, panel->wheelImg);

	RConvertImage(scr->rcontext, image, &panel->wheelImg);
	RReleaseImage(image);

	/* Check if backimage exists. If it doesn't, allocate and fill it */
	if (!panel->selectionBackImg) {
		panel->selectionBackImg = XCreatePixmap(scr->display,
							W_VIEW(panel->wheelFrm)->window, 4, 4, scr->depth);
		XCopyArea(scr->display, panel->wheelImg, panel->selectionBackImg,
			  scr->copyGC, panel->colx - 2, panel->coly - 2, 4, 4, 0, 0);
		/* -2 is hot spot correction */
	}
}

static Bool wheelInsideColorWheel(W_ColorPanel * panel, unsigned long ofs)
{
	return ((panel->wheelMtrx->data[0][ofs] != 0) &&
		(panel->wheelMtrx->data[1][ofs] != 0) && (panel->wheelMtrx->data[2][ofs] != 0));
}

static void wheelPaint(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);

	XCopyArea(scr->display, panel->wheelImg, panel->wheelView->window,
		  scr->copyGC, 0, 0, colorWheelSize + 4, colorWheelSize + 4, 0, 0);

	/* Draw selection image */
	XCopyArea(scr->display, panel->selectionImg, panel->wheelView->window,
		  scr->copyGC, 0, 0, 4, 4, panel->colx - 2, panel->coly - 2);
}

static void wheelHandleEvents(XEvent * event, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;

	switch (event->type) {
	case Expose:
		if (event->xexpose.count != 0)	/* TODO Improve */
			break;
		wheelPaint(panel);
		break;
	}
}

static void wheelHandleActionEvents(XEvent * event, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;

	switch (event->type) {
	case ButtonPress:
		if (getPickerPart(panel, event->xbutton.x, event->xbutton.y) == COLORWHEEL_PART) {

			panel->lastChanged = WMWheelModeColorPanel;
			panel->flags.dragging = 1;

			wheelPositionSelection(panel, event->xbutton.x, event->xbutton.y);
		}
		break;

	case ButtonRelease:
		panel->flags.dragging = 0;
		if (!panel->flags.continuous) {
			if (panel->action)
				(*panel->action) (panel, panel->clientData);
		}
		break;

	case MotionNotify:
		if (panel->flags.dragging) {
			if (getPickerPart(panel, event->xmotion.x, event->xmotion.y) == COLORWHEEL_PART) {
				wheelPositionSelection(panel, event->xmotion.x, event->xmotion.y);
			} else
				wheelPositionSelectionOutBounds(panel, event->xmotion.x, event->xmotion.y);
		}
		break;
	}
}

static int getPickerPart(W_ColorPanel * panel, int x, int y)
{
	int lx, ly;
	unsigned long ofs;

	lx = x;
	ly = y;

	if (panel->mode == WMWheelModeColorPanel) {
		if ((lx >= 2) && (lx <= 2 + colorWheelSize) && (ly >= 2) && (ly <= 2 + colorWheelSize)) {

			ofs = ly * panel->wheelMtrx->width + lx;

			if (wheelInsideColorWheel(panel, ofs))
				return COLORWHEEL_PART;
		}
	}

	if (panel->mode == WMCustomPaletteModeColorPanel) {
		if ((lx >= 2) && (lx < customPaletteWidth - 2) && (ly >= 2) && (ly < customPaletteHeight - 2)) {
			return CUSTOMPALETTE_PART;
		}
	}

	return 0;
}

static void wheelBrightnessSliderCallback(WMWidget * w, void *data)
{
	int value;

	W_ColorPanel *panel = (W_ColorPanel *) data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	value = 255 - WMGetSliderValue(panel->wheelBrightnessS);

	wheelCalculateValues(panel, value);

	if (panel->color.set == cpRGB) {
		convertCPColor(&panel->color);
		panel->color.set = cpHSV;
	}

	panel->color.hsv.value = value;

	wheelRender(panel);
	wheelPaint(panel);
	wheelUpdateSelection(panel);
}

static void wheelUpdateSelection(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);

	updateSwatch(panel, panel->color);
	panel->lastChanged = WMWheelModeColorPanel;

	/* Redraw color selector (and make a backup of the part it will cover) */
	XCopyArea(scr->display, panel->wheelImg, panel->selectionBackImg,
		  scr->copyGC, panel->colx - 2, panel->coly - 2, 4, 4, 0, 0);
	/* "-2" is correction for hotspot location */
	XCopyArea(scr->display, panel->selectionImg, panel->wheelView->window,
		  scr->copyGC, 0, 0, 4, 4, panel->colx - 2, panel->coly - 2);
	/* see above */
}

static void wheelUndrawSelection(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);

	XCopyArea(scr->display, panel->selectionBackImg, panel->wheelView->window,
		  scr->copyGC, 0, 0, 4, 4, panel->colx - 2, panel->coly - 2);
	/* see above */
}

static void wheelPositionSelection(W_ColorPanel * panel, int x, int y)
{
	unsigned long ofs = (y * panel->wheelMtrx->width) + x;

	panel->color.rgb.red = panel->wheelMtrx->values[panel->wheelMtrx->data[0][ofs]];

	panel->color.rgb.green = panel->wheelMtrx->values[panel->wheelMtrx->data[1][ofs]];

	panel->color.rgb.blue = panel->wheelMtrx->values[panel->wheelMtrx->data[2][ofs]];
	panel->color.set = cpRGB;

	wheelUndrawSelection(panel);

	panel->colx = x;
	panel->coly = y;

	wheelUpdateSelection(panel);
	wheelUpdateBrightnessGradientFromLocation(panel);
}

static void wheelPositionSelectionOutBounds(W_ColorPanel * panel, int x, int y)
{
	int hue;
	int xcor, ycor;
	CPColor cpColor;

	xcor = x * 2 - colorWheelSize - 4;
	ycor = y * 2 - colorWheelSize - 4;

	panel->color.hsv.saturation = 255;
	panel->color.hsv.value = 255 - WMGetSliderValue(panel->wheelBrightnessS);

	if (xcor != 0)
		hue = rint(atan(-(double)ycor / (double)xcor) * (180.0 / WM_PI));
	else {
		if (ycor < 0)
			hue = 90;
		else
			hue = 270;
	}

	if (xcor < 0)
		hue += 180;

	if ((xcor > 0) && (ycor > 0))
		hue += 360;

	panel->color.hsv.hue = hue;
	panel->color.set = cpHSV;
	convertCPColor(&panel->color);

	wheelUndrawSelection(panel);

	panel->colx = 2 + rint((colorWheelSize * (1.0 + cos(panel->color.hsv.hue * (WM_PI / 180.0)))) / 2.0);
	/* "+2" because of "colorWheelSize + 4" */
	panel->coly = 2 + rint((colorWheelSize * (1.0 + sin(-panel->color.hsv.hue * (WM_PI / 180.0)))) / 2.0);

	wheelUpdateSelection(panel);
	cpColor = panel->color;
	wheelUpdateBrightnessGradient(panel, cpColor);
}

static void wheelUpdateBrightnessGradientFromLocation(W_ColorPanel * panel)
{
	CPColor from;
	unsigned long ofs;

	ofs = panel->coly * panel->wheelMtrx->width + panel->colx;

	from.rgb.red = panel->wheelMtrx->data[0][ofs];
	from.rgb.green = panel->wheelMtrx->data[1][ofs];
	from.rgb.blue = panel->wheelMtrx->data[2][ofs];
	from.set = cpRGB;

	wheelUpdateBrightnessGradient(panel, from);
}

static void wheelUpdateBrightnessGradient(W_ColorPanel * panel, CPColor topColor)
{
	RColor to;
	RImage *sliderImg;
	WMPixmap *sliderPxmp;

	to.red = to.green = to.blue = 0;

	if (topColor.set == cpHSV)
		convertCPColor(&topColor);

	sliderImg = RRenderGradient(16, 153, &(topColor.rgb), &to, RGRD_VERTICAL);
	sliderPxmp = WMCreatePixmapFromRImage(WMWidgetScreen(panel->win), sliderImg, 0);
	RReleaseImage(sliderImg);
	WMSetSliderImage(panel->wheelBrightnessS, sliderPxmp);
	WMReleasePixmap(sliderPxmp);
}

/****************** Grayscale Panel Functions ***************/

static void grayBrightnessSliderCallback(WMWidget * w, void *data)
{
	CPColor cpColor;
	int value;
	char tmp[4];
	W_ColorPanel *panel = (W_ColorPanel *) data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	value = WMGetSliderValue(panel->grayBrightnessS);

	sprintf(tmp, "%d", value);

	WMSetTextFieldText(panel->grayBrightnessT, tmp);
	cpColor.rgb.red = cpColor.rgb.green = cpColor.rgb.blue = rint(2.55 * value);
	cpColor.set = cpRGB;

	updateSwatch(panel, cpColor);
	panel->lastChanged = WMGrayModeColorPanel;
}

static void grayPresetButtonCallback(WMWidget * w, void *data)
{
	CPColor cpColor;
	char tmp[4];
	int value;
	int i = 0;
	W_ColorPanel *panel = (W_ColorPanel *) data;

	while (i < 7) {
		if (w == panel->grayPresetBtn[i])
			break;
		i++;
	}

	value = rint((100.0 * i) / 6.0);
	sprintf(tmp, "%d", value);

	WMSetTextFieldText(panel->grayBrightnessT, tmp);
	cpColor.rgb.red = cpColor.rgb.green = cpColor.rgb.blue = rint((255.0 * i) / 6.0);
	cpColor.set = cpRGB;

	WMSetSliderValue(panel->grayBrightnessS, rint((100.0 * i) / 6.0));

	updateSwatch(panel, cpColor);
	panel->lastChanged = WMGrayModeColorPanel;
}

static void grayBrightnessTextFieldCallback(void *observerData, WMNotification * notification)
{
	CPColor cpColor;
	char tmp[4];
	int value;
	W_ColorPanel *panel = (W_ColorPanel *) observerData;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) notification;

	value = get_textfield_as_integer(panel->grayBrightnessT);
	if (value > 100)
		value = 100;
	if (value < 0)
		value = 0;

	sprintf(tmp, "%d", value);
	WMSetTextFieldText(panel->grayBrightnessT, tmp);
	WMSetSliderValue(panel->grayBrightnessS, value);

	cpColor.rgb.red = cpColor.rgb.green = cpColor.rgb.blue = rint((255.0 * value) / 100.0);
	cpColor.set = cpRGB;

	updateSwatch(panel, cpColor);
	panel->lastChanged = WMGrayModeColorPanel;
}

/******************* RGB Panel Functions *****************/

void rgbIntToChar(W_ColorPanel *panel, int *value)
{
	char tmp[4];
	const char *format;

	switch (panel->rgbState) {
	case RGBdec:
		format = "%d";
		break;
	case RGBhex:
		format = "%0X";
		break;
	}

	sprintf(tmp, format, value[0]);
	WMSetTextFieldText(panel->rgbRedT, tmp);
	sprintf(tmp, format, value[1]);
	WMSetTextFieldText(panel->rgbGreenT, tmp);
	sprintf(tmp, format, value[2]);
	WMSetTextFieldText(panel->rgbBlueT, tmp);
}

int *rgbCharToInt(W_ColorPanel *panel)
{
	int base = 0;
	static int value[3];
	char *str;

	switch (panel->rgbState) {
	case RGBdec:
		base = 10;
		break;
	case RGBhex:
		base = 16;
		break;
	}

	str = WMGetTextFieldText(panel->rgbRedT);
	value[0] = strtol(str, NULL, base);
	wfree(str);

	str = WMGetTextFieldText(panel->rgbGreenT);
	value[1] = strtol(str, NULL, base);
	wfree(str);

	str = WMGetTextFieldText(panel->rgbBlueT);
	value[2] = strtol(str, NULL, base);
	wfree(str);

	return value;
}

static void rgbSliderCallback(WMWidget * w, void *data)
{
	CPColor cpColor;
	int value[3];
	W_ColorPanel *panel = (W_ColorPanel *) data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	value[0] = WMGetSliderValue(panel->rgbRedS);
	value[1] = WMGetSliderValue(panel->rgbGreenS);
	value[2] = WMGetSliderValue(panel->rgbBlueS);

	rgbIntToChar(panel, value);

	cpColor.rgb.red = value[0];
	cpColor.rgb.green = value[1];
	cpColor.rgb.blue = value[2];
	cpColor.set = cpRGB;

	updateSwatch(panel, cpColor);
	panel->lastChanged = WMRGBModeColorPanel;
}

static void rgbTextFieldCallback(void *observerData, WMNotification * notification)
{
	CPColor cpColor;
	int *value;
	int n;
	W_ColorPanel *panel = (W_ColorPanel *) observerData;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) notification;

	value = rgbCharToInt(panel);

	for (n = 0; n < 3; n++) {
		if (value[n] > 255)
			value[n] = 255;
		if (value[n] < 0)
			value[n] = 0;
	}

	rgbIntToChar(panel, value);

	WMSetSliderValue(panel->rgbRedS, value[0]);
	WMSetSliderValue(panel->rgbGreenS, value[1]);
	WMSetSliderValue(panel->rgbBlueS, value[2]);

	cpColor.rgb.red = value[0];
	cpColor.rgb.green = value[1];
	cpColor.rgb.blue = value[2];
	cpColor.set = cpRGB;

	updateSwatch(panel, cpColor);
	panel->lastChanged = WMRGBModeColorPanel;
}

static void rgbDecToHex(WMWidget *w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;
	int *value;

	(void) w;

	switch (panel->rgbState) {
	case RGBhex:
		if (WMGetButtonSelected(panel->rgbDecB)) {
			WMSetLabelText(panel->rgbMaxL, "255");
			WMRedisplayWidget(panel->rgbMaxL);
			value = rgbCharToInt(panel);
			panel->rgbState = RGBdec;
			rgbIntToChar(panel, value);
		}
		break;

	case RGBdec:
		if (WMGetButtonSelected(panel->rgbHexB)) {
			WMSetLabelText(panel->rgbMaxL, "FF");
			WMRedisplayWidget(panel->rgbMaxL);
			value = rgbCharToInt(panel);
			panel->rgbState = RGBhex;
			rgbIntToChar(panel, value);
		}
		break;
	}
}

/******************* CMYK Panel Functions *****************/

static void cmykSliderCallback(WMWidget * w, void *data)
{
	CPColor cpColor;
	int value[4];
	char tmp[4];
	W_ColorPanel *panel = (W_ColorPanel *) data;
	double scale;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	value[0] = WMGetSliderValue(panel->cmykCyanS);
	value[1] = WMGetSliderValue(panel->cmykMagentaS);
	value[2] = WMGetSliderValue(panel->cmykYellowS);
	value[3] = WMGetSliderValue(panel->cmykBlackS);

	sprintf(tmp, "%d", value[0]);
	WMSetTextFieldText(panel->cmykCyanT, tmp);
	sprintf(tmp, "%d", value[1]);
	WMSetTextFieldText(panel->cmykMagentaT, tmp);
	sprintf(tmp, "%d", value[2]);
	WMSetTextFieldText(panel->cmykYellowT, tmp);
	sprintf(tmp, "%d", value[3]);
	WMSetTextFieldText(panel->cmykBlackT, tmp);

	scale = 2.55 * (1.0 - (value[3] / 100.0));
	cpColor.rgb.red = rint((100.0 - value[0]) * scale);
	cpColor.rgb.green = rint((100.0 - value[1]) * scale);
	cpColor.rgb.blue = rint((100.0 - value[2]) * scale);
	cpColor.set = cpRGB;

	updateSwatch(panel, cpColor);
	panel->lastChanged = WMCMYKModeColorPanel;
}

static void cmykTextFieldCallback(void *observerData, WMNotification * notification)
{
	CPColor cpColor;
	int value[4];
	char tmp[4];
	int n;
	double scale;
	W_ColorPanel *panel = (W_ColorPanel *) observerData;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) notification;

	value[0] = get_textfield_as_integer(panel->cmykCyanT);
	value[1] = get_textfield_as_integer(panel->cmykMagentaT);
	value[2] = get_textfield_as_integer(panel->cmykYellowT);
	value[3] = get_textfield_as_integer(panel->cmykBlackT);

	for (n = 0; n < 4; n++) {
		if (value[n] > 100)
			value[n] = 100;
		if (value[n] < 0)
			value[n] = 0;
	}

	sprintf(tmp, "%d", value[0]);
	WMSetTextFieldText(panel->cmykCyanT, tmp);

	sprintf(tmp, "%d", value[1]);
	WMSetTextFieldText(panel->cmykMagentaT, tmp);

	sprintf(tmp, "%d", value[2]);
	WMSetTextFieldText(panel->cmykYellowT, tmp);

	sprintf(tmp, "%d", value[3]);
	WMSetTextFieldText(panel->cmykBlackT, tmp);

	WMSetSliderValue(panel->cmykCyanS, value[0]);
	WMSetSliderValue(panel->cmykMagentaS, value[1]);
	WMSetSliderValue(panel->cmykYellowS, value[2]);
	WMSetSliderValue(panel->cmykBlackS, value[3]);

	scale = 2.55 * (1.0 - (value[3] / 100.0));
	cpColor.rgb.red = rint((100.0 - value[0]) * scale);
	cpColor.rgb.green = rint((100.0 - value[1]) * scale);
	cpColor.rgb.blue = rint((100.0 - value[2]) * scale);
	cpColor.set = cpRGB;

	updateSwatch(panel, cpColor);
	panel->lastChanged = WMCMYKModeColorPanel;
}

/********************** HSB Panel Functions ***********************/

static void hsbSliderCallback(WMWidget * w, void *data)
{
	CPColor cpColor;
	int value[3];
	char tmp[4];
	W_ColorPanel *panel = (W_ColorPanel *) data;

	value[0] = WMGetSliderValue(panel->hsbHueS);
	value[1] = WMGetSliderValue(panel->hsbSaturationS);
	value[2] = WMGetSliderValue(panel->hsbBrightnessS);

	sprintf(tmp, "%d", value[0]);
	WMSetTextFieldText(panel->hsbHueT, tmp);
	sprintf(tmp, "%d", value[1]);
	WMSetTextFieldText(panel->hsbSaturationT, tmp);
	sprintf(tmp, "%d", value[2]);
	WMSetTextFieldText(panel->hsbBrightnessT, tmp);

	cpColor.hsv.hue = value[0];
	cpColor.hsv.saturation = value[1] * 2.55;
	cpColor.hsv.value = value[2] * 2.55;
	cpColor.set = cpHSV;

	convertCPColor(&cpColor);

	panel->lastChanged = WMHSBModeColorPanel;
	updateSwatch(panel, cpColor);

	if (w != panel->hsbBrightnessS)
		hsbUpdateBrightnessGradient(panel);
	if (w != panel->hsbSaturationS)
		hsbUpdateSaturationGradient(panel);
	if (w != panel->hsbHueS)
		hsbUpdateHueGradient(panel);
}

static void hsbTextFieldCallback(void *observerData, WMNotification * notification)
{
	CPColor cpColor;
	int value[3];
	char tmp[4];
	int n;
	W_ColorPanel *panel = (W_ColorPanel *) observerData;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) notification;

	value[0] = get_textfield_as_integer(panel->hsbHueT);
	value[1] = get_textfield_as_integer(panel->hsbSaturationT);
	value[2] = get_textfield_as_integer(panel->hsbBrightnessT);

	if (value[0] > 359)
		value[0] = 359;
	if (value[0] < 0)
		value[0] = 0;

	for (n = 1; n < 3; n++) {
		if (value[n] > 100)
			value[n] = 100;
		if (value[n] < 0)
			value[n] = 0;
	}

	sprintf(tmp, "%d", value[0]);
	WMSetTextFieldText(panel->hsbHueT, tmp);
	sprintf(tmp, "%d", value[1]);
	WMSetTextFieldText(panel->hsbSaturationT, tmp);
	sprintf(tmp, "%d", value[2]);
	WMSetTextFieldText(panel->hsbBrightnessT, tmp);

	WMSetSliderValue(panel->hsbHueS, value[0]);
	WMSetSliderValue(panel->hsbSaturationS, value[1]);
	WMSetSliderValue(panel->hsbBrightnessS, value[2]);

	cpColor.hsv.hue = value[0];
	cpColor.hsv.saturation = value[1] * 2.55;
	cpColor.hsv.value = value[2] * 2.55;
	cpColor.set = cpHSV;

	convertCPColor(&cpColor);

	panel->lastChanged = WMHSBModeColorPanel;
	updateSwatch(panel, cpColor);

	hsbUpdateBrightnessGradient(panel);
	hsbUpdateSaturationGradient(panel);
	hsbUpdateHueGradient(panel);
}

static void hsbUpdateBrightnessGradient(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	RColor from;
	CPColor to;
	RImage *sliderImg;
	WMPixmap *sliderPxmp;

	from.red = from.green = from.blue = 0;
	to.hsv = panel->color.hsv;
	to.hsv.value = 255;
	to.set = cpHSV;

	convertCPColor(&to);

	sliderImg = RRenderGradient(141, 16, &from, &(to.rgb), RGRD_HORIZONTAL);
	sliderPxmp = WMCreatePixmapFromRImage(scr, sliderImg, 0);
	RReleaseImage(sliderImg);

	if (sliderPxmp)
		W_PaintText(W_VIEW(panel->hsbBrightnessS), sliderPxmp->pixmap,
			    panel->font12, 2, 0, 100, WALeft, scr->white,
			    False, _("Brightness"), strlen(_("Brightness")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->hsbBrightnessS, sliderPxmp);
	WMReleasePixmap(sliderPxmp);
}

static void hsbUpdateSaturationGradient(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	CPColor from;
	CPColor to;
	RImage *sliderImg;
	WMPixmap *sliderPxmp;

	from.hsv = panel->color.hsv;
	from.hsv.saturation = 0;
	from.set = cpHSV;
	convertCPColor(&from);

	to.hsv = panel->color.hsv;
	to.hsv.saturation = 255;
	to.set = cpHSV;
	convertCPColor(&to);

	sliderImg = RRenderGradient(141, 16, &(from.rgb), &(to.rgb), RGRD_HORIZONTAL);
	sliderPxmp = WMCreatePixmapFromRImage(scr, sliderImg, 0);
	RReleaseImage(sliderImg);

	if (sliderPxmp)
		W_PaintText(W_VIEW(panel->hsbSaturationS), sliderPxmp->pixmap,
			    panel->font12, 2, 0, 100, WALeft,
			    from.hsv.value < 128 ? scr->white : scr->black, False,
			    _("Saturation"), strlen(_("Saturation")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->hsbSaturationS, sliderPxmp);
	WMReleasePixmap(sliderPxmp);
}

static void hsbUpdateHueGradient(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	RColor **colors = NULL;
	RHSVColor hsvcolor;
	RImage *sliderImg;
	WMPixmap *sliderPxmp;
	int i;

	hsvcolor = panel->color.hsv;

	colors = wmalloc(sizeof(RColor *) * (8));
	for (i = 0; i < 7; i++) {
		hsvcolor.hue = (360 * i) / 6;
		colors[i] = wmalloc(sizeof(RColor));
		RHSVtoRGB(&hsvcolor, colors[i]);
	}
	colors[7] = NULL;

	sliderImg = RRenderMultiGradient(141, 16, colors, RGRD_HORIZONTAL);
	sliderPxmp = WMCreatePixmapFromRImage(scr, sliderImg, 0);
	RReleaseImage(sliderImg);

	if (sliderPxmp)
		W_PaintText(W_VIEW(panel->hsbHueS), sliderPxmp->pixmap,
			    panel->font12, 2, 0, 100, WALeft,
			    hsvcolor.value < 128 ? scr->white : scr->black, False, _("Hue"), strlen(_("Hue")));
	else
		wwarning(_("Color Panel: Could not allocate memory"));

	WMSetSliderImage(panel->hsbHueS, sliderPxmp);
	WMReleasePixmap(sliderPxmp);

	for (i = 0; i < 7; i++)
		wfree(colors[i]);

	wfree(colors);
}

/*************** Custom Palette Functions ****************/

static void customRenderSpectrum(W_ColorPanel * panel)
{
	RImage *spectrum;
	int x, y;
	unsigned char *ptr;
	CPColor cpColor;

	spectrum = RCreateImage(SPECTRUM_WIDTH, SPECTRUM_HEIGHT, False);

	ptr = spectrum->data;

	for (y = 0; y < SPECTRUM_HEIGHT; y++) {
		cpColor.hsv.hue = y;
		cpColor.hsv.saturation = 0;
		cpColor.hsv.value = 255;
		cpColor.set = cpHSV;

		for (x = 0; x < SPECTRUM_WIDTH; x++) {
			convertCPColor(&cpColor);

			*(ptr++) = (unsigned char)cpColor.rgb.red;
			*(ptr++) = (unsigned char)cpColor.rgb.green;
			*(ptr++) = (unsigned char)cpColor.rgb.blue;

			if (x < (SPECTRUM_WIDTH / 2))
				cpColor.hsv.saturation++;

			if (x > (SPECTRUM_WIDTH / 2))
				cpColor.hsv.value--;
		}
	}
	if (panel->customPaletteImg) {
		RReleaseImage(panel->customPaletteImg);
		panel->customPaletteImg = NULL;
	}
	panel->customPaletteImg = spectrum;
}

static void customSetPalette(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	RImage *scaledImg;
	Pixmap image;

	image = XCreatePixmap(scr->display, W_DRAWABLE(scr), customPaletteWidth, customPaletteHeight, scr->depth);
	scaledImg = RScaleImage(panel->customPaletteImg, customPaletteWidth, customPaletteHeight);
	RConvertImage(scr->rcontext, scaledImg, &image);
	RReleaseImage(scaledImg);

	XCopyArea(scr->display, image, panel->customPaletteContentView->window,
		  scr->copyGC, 0, 0, customPaletteWidth, customPaletteHeight, 0, 0);

	/* Check backimage exists. If it doesn't, allocate and fill it */
	if (!panel->selectionBackImg) {
		panel->selectionBackImg = XCreatePixmap(scr->display,
							panel->customPaletteContentView->window, 4, 4, scr->depth);
	}

	XCopyArea(scr->display, image, panel->selectionBackImg, scr->copyGC,
		  panel->palx - 2, panel->paly - 2, 4, 4, 0, 0);
	XCopyArea(scr->display, panel->selectionImg,
		  panel->customPaletteContentView->window, scr->copyGC, 0, 0, 4, 4,
		  panel->palx - 2, panel->paly - 2);
	XFreePixmap(scr->display, image);

	panel->palXRatio = (double)(panel->customPaletteImg->width) / (double)(customPaletteWidth);
	panel->palYRatio = (double)(panel->customPaletteImg->height) / (double)(customPaletteHeight);
}

static void customPalettePositionSelection(W_ColorPanel * panel, int x, int y)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	unsigned long ofs;

	/* undraw selection */
	XCopyArea(scr->display, panel->selectionBackImg,
		  panel->customPaletteContentView->window, scr->copyGC, 0, 0, 4, 4,
		  panel->palx - 2, panel->paly - 2);

	panel->palx = x;
	panel->paly = y;

	ofs = (rint(x * panel->palXRatio) + rint(y * panel->palYRatio) * panel->customPaletteImg->width) * 3;

	panel->color.rgb.red = panel->customPaletteImg->data[ofs];
	panel->color.rgb.green = panel->customPaletteImg->data[ofs + 1];
	panel->color.rgb.blue = panel->customPaletteImg->data[ofs + 2];
	panel->color.set = cpRGB;

	updateSwatch(panel, panel->color);
	panel->lastChanged = WMCustomPaletteModeColorPanel;

	/* Redraw color selector (and make a backup of the part it will cover) */
	XCopyArea(scr->display, panel->customPaletteContentView->window, panel->selectionBackImg, scr->copyGC, panel->palx - 2, panel->paly - 2, 4, 4, 0, 0);	/* "-2" is correction for hotspot location */
	XCopyArea(scr->display, panel->selectionImg, panel->customPaletteContentView->window, scr->copyGC, 0, 0, 4, 4, panel->palx - 2, panel->paly - 2);	/* see above */
}

static void customPalettePositionSelectionOutBounds(W_ColorPanel * panel, int x, int y)
{
	if (x < 2)
		x = 2;
	if (y < 2)
		y = 2;
	if (x >= customPaletteWidth)
		x = customPaletteWidth - 2;
	if (y >= customPaletteHeight)
		y = customPaletteHeight - 2;

	customPalettePositionSelection(panel, x, y);
}

static void customPaletteHandleEvents(XEvent * event, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;

	switch (event->type) {
	case Expose:
		if (event->xexpose.count != 0)	/* TODO Improve. */
			break;
		customSetPalette(panel);
		break;
	}
}

static void customPaletteHandleActionEvents(XEvent * event, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;
	int x, y;

	switch (event->type) {
	case ButtonPress:
		x = event->xbutton.x;
		y = event->xbutton.y;

		if (getPickerPart(panel, x, y) == CUSTOMPALETTE_PART) {
			panel->flags.dragging = 1;
			customPalettePositionSelection(panel, x, y);
		}
		break;

	case ButtonRelease:
		panel->flags.dragging = 0;
		if (!panel->flags.continuous) {
			if (panel->action)
				(*panel->action) (panel, panel->clientData);
		}
		break;

	case MotionNotify:
		x = event->xmotion.x;
		y = event->xmotion.y;

		if (panel->flags.dragging) {
			if (getPickerPart(panel, x, y) == CUSTOMPALETTE_PART) {
				customPalettePositionSelection(panel, x, y);
			} else
				customPalettePositionSelectionOutBounds(panel, x, y);
		}
		break;
	}
}

static void customPaletteMenuCallback(WMWidget * w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;
	int item = WMGetPopUpButtonSelectedItem(panel->customPaletteMenuBtn);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	switch (item) {
	case CPmenuNewFromFile:
		customPaletteMenuNewFromFile(panel);
		break;
	case CPmenuRename:
		customPaletteMenuRename(panel);
		break;
	case CPmenuRemove:
		customPaletteMenuRemove(panel);
		break;
	case CPmenuCopy:
		break;
	case CPmenuNewFromClipboard:
		break;
	}
}

static void customPaletteMenuNewFromFile(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	WMOpenPanel *browseP;
	char *filepath;
	char *filename = NULL;
	char *spath;
	char *tmp;
	int i;
	RImage *tmpImg = NULL;

	if ((!panel->lastBrowseDir) || (strcmp(panel->lastBrowseDir, "\0") == 0))
		spath = wexpandpath(wgethomedir());
	else
		spath = wexpandpath(panel->lastBrowseDir);

	browseP = WMGetOpenPanel(scr);
	WMSetFilePanelCanChooseDirectories(browseP, 0);
	WMSetFilePanelCanChooseFiles(browseP, 1);

	/* Get a filename */
	if (WMRunModalFilePanelForDirectory(browseP, panel->win, spath,
					    _("Open Palette"), RSupportedFileFormats())) {
		filepath = WMGetFilePanelFileName(browseP);

		/* Get seperation position between path and filename */
		i = strrchr(filepath, '/') - filepath + 1;
		if (i > strlen(filepath))
			i = strlen(filepath);

		/* Store last browsed path */
		if (panel->lastBrowseDir)
			wfree(panel->lastBrowseDir);
		panel->lastBrowseDir = wmalloc((i + 1) * sizeof(char));
		strncpy(panel->lastBrowseDir, filepath, i);
		panel->lastBrowseDir[i] = '\0';

		/* Get filename from path */
		filename = wstrdup(filepath + i);

		/* Check for duplicate files, and rename it if there are any */
		tmp = wstrconcat(panel->configurationPath, filename);
		while (access(tmp, F_OK) == 0) {
			char *newName;

			wfree(tmp);

			newName = generateNewFilename(filename);
			wfree(filename);
			filename = newName;

			tmp = wstrconcat(panel->configurationPath, filename);
		}
		wfree(tmp);

		/* Copy image to $(gnustepdir)/Library/Colors/ &
		 * Add filename to history menu */
		if (wcopy_file(panel->configurationPath, filepath, filename) == 0) {

			/* filepath is a "local" path now the file has been copied */
			wfree(filepath);
			filepath = wstrconcat(panel->configurationPath, filename);

			/* load the image & add menu entries */
			tmpImg = RLoadImage(scr->rcontext, filepath, 0);
			if (tmpImg) {
				if (panel->customPaletteImg)
					RReleaseImage(panel->customPaletteImg);
				panel->customPaletteImg = tmpImg;

				customSetPalette(panel);
				WMAddPopUpButtonItem(panel->customPaletteHistoryBtn, filename);

				panel->currentPalette =
				    WMGetPopUpButtonNumberOfItems(panel->customPaletteHistoryBtn) - 1;

				WMSetPopUpButtonSelectedItem(panel->customPaletteHistoryBtn,
							     panel->currentPalette);
			}
		} else {
			tmp = wstrconcat(panel->configurationPath, filename);

			i = remove(tmp);	/* Delete the file, it doesn't belong here */
			WMRunAlertPanel(scr, panel->win, _("File Error"),
					_("Invalid file format !"), _("OK"), NULL, NULL);
			if (i != 0) {
				werror(_("can't remove file %s"), tmp);
				WMRunAlertPanel(scr, panel->win, _("File Error"),
						_("Couldn't remove file from Configuration Directory !"),
						_("OK"), NULL, NULL);
			}
			wfree(tmp);
		}
		wfree(filepath);
		wfree(filename);
	}
	WMFreeFilePanel(browseP);

	wfree(spath);
}

static void customPaletteMenuRename(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	char *toName = NULL;
	char *fromName;
	char *toPath, *fromPath;
	int item;
	int index;

	item = WMGetPopUpButtonSelectedItem(panel->customPaletteHistoryBtn);
	fromName = WMGetPopUpButtonItem(panel->customPaletteHistoryBtn, item);

	toName = WMRunInputPanel(scr, panel->win, _("Rename"), _("Rename palette to:"),
				 fromName, _("OK"), _("Cancel"));

	if (toName) {

		/* As some people do certain stupid things... */
		if (strcmp(toName, fromName) == 0) {
			wfree(toName);
			return;
		}

		/* For normal people */
		fromPath = wstrconcat(panel->configurationPath, fromName);
		toPath = wstrconcat(panel->configurationPath, toName);

		if (access(toPath, F_OK) == 0) {
			/* Careful, this palette exists already */
			if (WMRunAlertPanel(scr, panel->win, _("Warning"),
					    _("Palette already exists !\n\nOverwrite ?"), _("No"), _("Yes"),
					    NULL) == 1) {
				/* "No" = 0, "Yes" = 1 */
				int items = WMGetPopUpButtonNumberOfItems(panel->customPaletteHistoryBtn);

				remove(toPath);

				/* Remove from History list too */
				index = 1;
				while ((index < items)
				       &&
				       (strcmp(WMGetPopUpButtonItem(panel->customPaletteHistoryBtn, index), toName)
					!= 0))
					index++;

				if (index < items) {
					WMRemovePopUpButtonItem(panel->customPaletteHistoryBtn, index);
					if (index < item)
						item--;
				}

			} else {
				wfree(fromPath);
				wfree(toName);
				wfree(toPath);

				return;
			}
		}

		if (rename(fromPath, toPath) != 0)
			werror(_("Couldn't rename palette %s to %s"), fromName, toName);
		else {
			WMRemovePopUpButtonItem(panel->customPaletteHistoryBtn, item);
			WMInsertPopUpButtonItem(panel->customPaletteHistoryBtn, item, toName);

			WMSetPopUpButtonSelectedItem(panel->customPaletteHistoryBtn, item);
		}
		wfree(fromPath);
		wfree(toPath);
		wfree(toName);
	}
}

static void customPaletteMenuRemove(W_ColorPanel * panel)
{
	W_Screen *scr = WMWidgetScreen(panel->win);
	char *text;
	char *tmp;
	int choice;
	int item;

	item = WMGetPopUpButtonSelectedItem(panel->customPaletteHistoryBtn);

	tmp = wstrconcat(_("This will permanently remove the palette "),
			 WMGetPopUpButtonItem(panel->customPaletteHistoryBtn, item));
	text = wstrconcat(tmp, _(".\n\nAre you sure you want to remove this palette ?"));
	wfree(tmp);

	choice = WMRunAlertPanel(scr, panel->win, _("Remove"), text, _("Yes"), _("No"), NULL);
	/* returns 0 (= "Yes") or 1 (="No") */
	wfree(text);

	if (choice == 0) {

		tmp = wstrconcat(panel->configurationPath,
				 WMGetPopUpButtonItem(panel->customPaletteHistoryBtn, item));

		if (remove(tmp) == 0) {
			/* item-1 always exists */
			WMSetPopUpButtonSelectedItem(panel->customPaletteHistoryBtn, item - 1);

			customPaletteHistoryCallback(panel->customPaletteHistoryBtn, panel);
			customSetPalette(panel);

			WMRemovePopUpButtonItem(panel->customPaletteHistoryBtn, item);

		} else {
			werror(_("Couldn't remove palette %s"), tmp);
		}

		wfree(tmp);
	}
}

static void customPaletteHistoryCallback(WMWidget * w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;
	W_Screen *scr = WMWidgetScreen(panel->win);
	int item;
	char *filename;
	RImage *tmp = NULL;
	unsigned char perm_mask;

	item = WMGetPopUpButtonSelectedItem(panel->customPaletteHistoryBtn);
	if (item == panel->currentPalette)
		return;

	if (item == 0) {
		customRenderSpectrum(panel);

		WMSetPopUpButtonItemEnabled(panel->customPaletteMenuBtn, CPmenuRename, False);
		WMSetPopUpButtonItemEnabled(panel->customPaletteMenuBtn, CPmenuRemove, False);
	} else {
		/* Load file from configpath */
		filename = wstrconcat(panel->configurationPath,
				      WMGetPopUpButtonItem(panel->customPaletteHistoryBtn, item));

		/* If the file corresponding to the item does not exist,
		 * remove it from the history list and select the next one.
		 */
		perm_mask = (access(filename, F_OK) == 0);
		if (!perm_mask) {
			/* File does not exist */
			wfree(filename);
			WMSetPopUpButtonSelectedItem(panel->customPaletteHistoryBtn, item - 1);
			WMRemovePopUpButtonItem(panel->customPaletteHistoryBtn, item);
			customPaletteHistoryCallback(w, data);
			return;
		}

		/* Get the image */
		tmp = RLoadImage(scr->rcontext, filename, 0);
		if (tmp) {
			if (panel->customPaletteImg) {
				RReleaseImage(panel->customPaletteImg);
				panel->customPaletteImg = NULL;
			}
			panel->customPaletteImg = tmp;
		}

		/* If the image is not writable, don't allow removing/renaming */
		perm_mask = (access(filename, W_OK) == 0);
		WMSetPopUpButtonItemEnabled(panel->customPaletteMenuBtn, CPmenuRename, perm_mask);
		WMSetPopUpButtonItemEnabled(panel->customPaletteMenuBtn, CPmenuRemove, perm_mask);

		wfree(filename);
	}
	customSetPalette(panel);

	panel->currentPalette = item;
}

/************************* ColorList Panel Functions **********************/

static void colorListPaintItem(WMList * lPtr, int index, Drawable d, char *text, int state, WMRect * rect)
{
	WMScreen *scr = WMWidgetScreen(lPtr);
	Display *dpy = WMScreenDisplay(scr);
	WMView *view = W_VIEW(lPtr);
	RColor *color = (RColor *) WMGetListItem(lPtr, index)->clientData;
	W_ColorPanel *panel = WMGetHangedData(lPtr);
	int width, height, x, y;
	WMColor *fillColor;

	width = rect->size.width;
	height = rect->size.height;
	x = rect->pos.x;
	y = rect->pos.y;

	if (state & WLDSSelected)
		XFillRectangle(dpy, d, WMColorGC(scr->white), x, y, width, height);
	else
		XFillRectangle(dpy, d, WMColorGC(view->backColor), x, y, width, height);

	fillColor = WMCreateRGBColor(scr, color->red << 8, color->green << 8, color->blue << 8, True);

	XFillRectangle(dpy, d, WMColorGC(fillColor), x, y, 15, height);
	WMReleaseColor(fillColor);

	WMDrawString(scr, d, scr->black, panel->font12, x + 18, y, text, strlen(text));
}

static void colorListSelect(WMWidget * w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;
	CPColor cpColor;

	cpColor.rgb = *((RColor *) WMGetListSelectedItem(w)->clientData);
	cpColor.set = cpRGB;

	panel->lastChanged = WMColorListModeColorPanel;
	updateSwatch(panel, cpColor);
}

static void colorListColorMenuCallback(WMWidget * w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;
	int item = WMGetPopUpButtonSelectedItem(panel->colorListColorMenuBtn);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	switch (item) {
	case CLmenuAdd:
		break;
	case CLmenuRename:
		break;
	case CLmenuRemove:
		break;
	}
}

static void colorListListMenuCallback(WMWidget * w, void *data)
{
	W_ColorPanel *panel = (W_ColorPanel *) data;
	int item = WMGetPopUpButtonSelectedItem(panel->colorListListMenuBtn);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	switch (item) {
	case CLmenuAdd:
		break;
	case CLmenuRename:
		break;
	case CLmenuRemove:
		break;
	}
}

/*************** Panel Initialisation Functions *****************/

static void wheelInit(W_ColorPanel * panel)
{
	CPColor cpColor;

	if (panel->color.set != cpHSV)
		convertCPColor(&panel->color);

	WMSetSliderValue(panel->wheelBrightnessS, 255 - panel->color.hsv.value);

	panel->colx = 2 + rint((colorWheelSize / 2.0) *
			       (1 + (panel->color.hsv.saturation / 255.0) *
				cos(panel->color.hsv.hue * WM_PI / 180.0)));
	panel->coly = 2 + rint((colorWheelSize / 2.0) *
			       (1 + (panel->color.hsv.saturation / 255.0) *
				sin(-panel->color.hsv.hue * WM_PI / 180.0)));

	wheelCalculateValues(panel, panel->color.hsv.value);

	cpColor = panel->color;
	cpColor.hsv.value = 255;
	cpColor.set = cpHSV;
	wheelUpdateBrightnessGradient(panel, cpColor);
}

static void grayInit(W_ColorPanel * panel)
{
	int value;
	char tmp[4];

	if (panel->color.set != cpHSV)
		convertCPColor(&panel->color);

	value = rint(panel->color.hsv.value / 2.55);
	WMSetSliderValue(panel->grayBrightnessS, value);

	sprintf(tmp, "%d", value);
	WMSetTextFieldText(panel->grayBrightnessT, tmp);
}

static void rgbInit(W_ColorPanel * panel)
{
	char tmp[4];
	const char *format;

	if (panel->color.set != cpRGB)
		convertCPColor(&panel->color);

	WMSetSliderValue(panel->rgbRedS, panel->color.rgb.red);
	WMSetSliderValue(panel->rgbGreenS, panel->color.rgb.green);
	WMSetSliderValue(panel->rgbBlueS, panel->color.rgb.blue);

	switch (panel->rgbState) {
	case RGBdec:
		format = "%d";
		break;
	case RGBhex:
		format = "%0X";
		break;
	}

	sprintf(tmp, format, panel->color.rgb.red);
	WMSetTextFieldText(panel->rgbRedT, tmp);
	sprintf(tmp, format, panel->color.rgb.green);
	WMSetTextFieldText(panel->rgbGreenT, tmp);
	sprintf(tmp, format, panel->color.rgb.blue);
	WMSetTextFieldText(panel->rgbBlueT, tmp);
}

static void cmykInit(W_ColorPanel * panel)
{
	int value[3];
	char tmp[4];

	if (panel->color.set != cpRGB)
		convertCPColor(&panel->color);

	value[0] = rint((255 - panel->color.rgb.red) / 2.55);
	value[1] = rint((255 - panel->color.rgb.green) / 2.55);
	value[2] = rint((255 - panel->color.rgb.blue) / 2.55);

	WMSetSliderValue(panel->cmykCyanS, value[0]);
	WMSetSliderValue(panel->cmykMagentaS, value[1]);
	WMSetSliderValue(panel->cmykYellowS, value[2]);
	WMSetSliderValue(panel->cmykBlackS, 0);

	sprintf(tmp, "%d", value[0]);
	WMSetTextFieldText(panel->cmykCyanT, tmp);
	sprintf(tmp, "%d", value[1]);
	WMSetTextFieldText(panel->cmykMagentaT, tmp);
	sprintf(tmp, "%d", value[2]);
	WMSetTextFieldText(panel->cmykYellowT, tmp);
	WMSetTextFieldText(panel->cmykBlackT, "0");
}

static void hsbInit(W_ColorPanel * panel)
{
	int value[3];
	char tmp[4];

	if (panel->color.set != cpHSV)
		convertCPColor(&panel->color);

	value[0] = panel->color.hsv.hue;
	value[1] = rint(panel->color.hsv.saturation / 2.55);
	value[2] = rint(panel->color.hsv.value / 2.55);

	WMSetSliderValue(panel->hsbHueS, value[0]);
	WMSetSliderValue(panel->hsbSaturationS, value[1]);
	WMSetSliderValue(panel->hsbBrightnessS, value[2]);

	sprintf(tmp, "%d", value[0]);
	WMSetTextFieldText(panel->hsbHueT, tmp);
	sprintf(tmp, "%d", value[1]);
	WMSetTextFieldText(panel->hsbSaturationT, tmp);
	sprintf(tmp, "%d", value[2]);
	WMSetTextFieldText(panel->hsbBrightnessT, tmp);

	hsbUpdateBrightnessGradient(panel);
	hsbUpdateSaturationGradient(panel);
	hsbUpdateHueGradient(panel);
}

/************************** Common utility functions ************************/

static char *generateNewFilename(const char *curName)
{
	int n;
	char c;
	int baseLen;
	const char *ptr;
	char *newName;

	assert(curName);

	ptr = curName;

	if (((ptr = strrchr(ptr, '{')) == 0) || sscanf(ptr, "{%i}%c", &n, &c) != 1)
		return wstrconcat(curName, " {1}");

	baseLen = ptr - curName - 1;

	newName = wmalloc(baseLen + 16);
	strncpy(newName, curName, baseLen);

	snprintf(&newName[baseLen], 16, " {%i}", n + 1);

	return newName;
}

static void convertCPColor(CPColor * color)
{
	unsigned short old_hue = 0;

	switch (color->set) {
	case cpNone:
		wwarning(_("Color Panel: Color unspecified"));
		return;
	case cpRGB:
		old_hue = color->hsv.hue;
		RRGBtoHSV(&(color->rgb), &(color->hsv));

		/* In black the hue is undefined, and may change by conversion
		 * Same for white. */
		if (((color->rgb.red == 0) &&
		     (color->rgb.green == 0) &&
		     (color->rgb.blue == 0)) ||
		    ((color->rgb.red == 0) && (color->rgb.green == 0) && (color->rgb.blue == 255))
		    )
			color->hsv.hue = old_hue;
		break;
	case cpHSV:
		RHSVtoRGB(&(color->hsv), &(color->rgb));
		break;
	}
}

static RColor ulongToRColor(WMScreen * scr, unsigned long value)
{
	RColor color;
	XColor *xcolor = NULL;

	xcolor = wmalloc(sizeof(XColor));
	xcolor->pixel = value;
	XQueryColor(scr->display, scr->rcontext->cmap, xcolor);

	color.red = xcolor->red >> 8;
	color.green = xcolor->green >> 8;
	color.blue = xcolor->blue >> 8;
	color.alpha = 0;

	wfree(xcolor);

	return color;
}

static unsigned char getShift(unsigned char value)
{
	unsigned char i = -1;

	if (value == 0)
		return 0;

	while (value) {
		value >>= 1;
		i++;
	}

	return i;
}
