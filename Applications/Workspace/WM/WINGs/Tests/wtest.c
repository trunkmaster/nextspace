/*
 * WINGs test application
 */

#include <WINGs/WINGs.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * You need to define this function to link any program to WINGs.
 * (this is no longer required as there is a default abort handler in WINGs)
 * This will be called when the application will be terminated because
 * of a fatal error (only for memory allocation failures ATM).
 */
void wAbort()
{
	exit(1);
}

Display *dpy;

int windowCount = 0;

void closeAction(WMWidget * self, void *data)
{
	WMDestroyWidget(self);
	windowCount--;
	printf("window closed, window count = %d\n", windowCount);
	if (windowCount < 1)
		exit(0);
}

void testOpenFilePanel(WMScreen * scr)
{
	WMOpenPanel *panel;

	/* windowCount++; */

	/* get the shared Open File panel */
	panel = WMGetOpenPanel(scr);

	WMRunModalFilePanelForDirectory(panel, NULL, "/usr/local", NULL, NULL);

	/* free the panel to save some memory. Not needed otherwise. */
	WMFreeFilePanel(WMGetOpenPanel(scr));
}

void testFontPanel(WMScreen * scr)
{
	WMFontPanel *panel;

	/*windowCount++; */

	panel = WMGetFontPanel(scr);

	WMShowFontPanel(panel);

	/*WMFreeFontPanel(panel); */
}

void testFrame(WMScreen * scr)
{
	WMWindow *win;
	WMFrame *frame;
	int i;
	static char *titles[] = {
		"AboveTop",
		"AtTop",
		"BelowTop",
		"AboveBottom",
		"AtBottom",
		"BelowBottom"
	};
	static WMTitlePosition pos[] = {
		WTPAboveTop,
		WTPAtTop,
		WTPBelowTop,
		WTPAboveBottom,
		WTPAtBottom,
		WTPBelowBottom
	};

	windowCount++;

	win = WMCreateWindow(scr, "testFrame");
	WMSetWindowTitle(win, "Frame");
	WMSetWindowCloseAction(win, closeAction, NULL);
	WMResizeWidget(win, 400, 300);

	for (i = 0; i < 6; i++) {
		frame = WMCreateFrame(win);
		WMMoveWidget(frame, 8 + (i % 3) * 130, 8 + (i / 3) * 130);
		WMResizeWidget(frame, 120, 120);
		WMSetFrameTitle(frame, titles[i]);
		WMSetFrameTitlePosition(frame, pos[i]);
	}

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);

}

/*static void
 resizedWindow(void *self, WMNotification *notif)
 {
 WMView *view = (WMView*)WMGetNotificationObject(notif);
 WMSize size = WMGetViewSize(view);

 WMResizeWidget((WMWidget*)self, size.width, size.height);
 }*/

void testBox(WMScreen * scr)
{
	WMWindow *win;
	WMBox *box, *hbox;
	WMButton *btn;
	WMPopUpButton *pop;
	int i;

	windowCount++;

	win = WMCreateWindow(scr, "testBox");
	WMSetWindowTitle(win, "Box");
	WMSetWindowCloseAction(win, closeAction, NULL);
	WMResizeWidget(win, 400, 300);

	box = WMCreateBox(win);
	WMSetBoxBorderWidth(box, 5);
	WMSetViewExpandsToParent(WMWidgetView(box), 0, 0, 0, 0);

	/*WMSetBoxHorizontal(box, True); */
	for (i = 0; i < 4; i++) {
		btn = WMCreateCommandButton(box);
		WMSetButtonText(btn, "bla");
		WMMapWidget(btn);
		WMAddBoxSubview(box, WMWidgetView(btn), i & 1, True, 20, 0, 5);
	}

	pop = WMCreatePopUpButton(box);
	WMAddPopUpButtonItem(pop, "ewqeq");
	WMAddPopUpButtonItem(pop, "ewqeqrewrw");
	WMAddBoxSubview(box, WMWidgetView(pop), False, True, 20, 0, 5);
	WMMapWidget(pop);

	hbox = WMCreateBox(box);
	WMSetBoxHorizontal(hbox, True);
	WMAddBoxSubview(box, WMWidgetView(hbox), False, True, 24, 0, 0);
	WMMapWidget(hbox);

	for (i = 0; i < 4; i++) {
		btn = WMCreateCommandButton(hbox);
		WMSetButtonText(btn, "bla");
		WMMapWidget(btn);
		WMAddBoxSubview(hbox, WMWidgetView(btn), 1, True, 60, 0, i < 3 ? 5 : 0);
	}

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);

}

static void singleClick(WMWidget * self, void *data)
{
}

static void doubleClick(WMWidget * self, void *data)
{
	WMSelectAllListItems((WMList *) self);
}

static void listSelectionObserver(void *observer, WMNotification * notification)
{
	WMLabel *label = (WMLabel *) observer;
	WMList *lPtr = (WMList *) WMGetNotificationObject(notification);
	char buf[255];

	sprintf(buf, "Selected items: %d", WMGetArrayItemCount(WMGetListSelectedItems(lPtr)));
	WMSetLabelText(label, buf);
}

void testList(WMScreen * scr)
{
	WMWindow *win;
	WMList *list;
	WMList *mlist;
	WMLabel *label;
	WMLabel *mlabel;
	WMLabel *title;
	WMLabel *mtitle;
	char text[100];
	int i;

	windowCount++;

	win = WMCreateWindow(scr, "testList");
	WMResizeWidget(win, 370, 250);
	WMSetWindowTitle(win, "List");
	WMSetWindowCloseAction(win, closeAction, NULL);

	title = WMCreateLabel(win);
	WMResizeWidget(title, 150, 20);
	WMMoveWidget(title, 10, 10);
	WMSetLabelRelief(title, WRRidge);
	WMSetLabelText(title, "Single selection list");

	mtitle = WMCreateLabel(win);
	WMResizeWidget(mtitle, 150, 20);
	WMMoveWidget(mtitle, 210, 10);
	WMSetLabelRelief(mtitle, WRRidge);
	WMSetLabelText(mtitle, "Multiple selection list");

	list = WMCreateList(win);
	/*WMSetListAllowEmptySelection(list, True); */
	WMMoveWidget(list, 10, 40);
	for (i = 0; i < 105; i++) {
		sprintf(text, "Item %i", i);
		WMAddListItem(list, text);
	}
	mlist = WMCreateList(win);
	WMSetListAllowMultipleSelection(mlist, True);
	/*WMSetListAllowEmptySelection(mlist, True); */
	WMMoveWidget(mlist, 210, 40);
	for (i = 0; i < 135; i++) {
		sprintf(text, "Item %i", i);
		WMAddListItem(mlist, text);
	}

	label = WMCreateLabel(win);
	WMResizeWidget(label, 150, 40);
	WMMoveWidget(label, 10, 200);
	WMSetLabelRelief(label, WRRidge);
	WMSetLabelText(label, "Selected items: 0");

	mlabel = WMCreateLabel(win);
	WMResizeWidget(mlabel, 150, 40);
	WMMoveWidget(mlabel, 210, 200);
	WMSetLabelRelief(mlabel, WRRidge);
	WMSetLabelText(mlabel, "Selected items: 0");

	WMSetListAction(list, singleClick, label);
	WMSetListDoubleAction(list, doubleClick, label);
	WMSetListAction(mlist, singleClick, mlabel);
	WMSetListDoubleAction(mlist, doubleClick, mlabel);

	WMAddNotificationObserver(listSelectionObserver, label, WMListSelectionDidChangeNotification, list);
	WMAddNotificationObserver(listSelectionObserver, mlabel, WMListSelectionDidChangeNotification, mlist);

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);
}

void testButton(WMScreen * scr)
{
	WMWindow *win;
	int i;
	char *types[] = {
		"MomentaryPush",
		"PushOnPushOff",
		"Toggle",
		"Switch",
		"Radio",
		"MomentaryChange",
		"OnOff",
		"MomentaryLigh"
	};

	windowCount++;

	win = WMCreateWindow(scr, "testButton");
	WMResizeWidget(win, 300, 300);
	WMSetWindowTitle(win, "Buttons");

	WMSetWindowCloseAction(win, closeAction, NULL);

	for (i = 1; i < 9; i++) {
		WMButton *b;
		b = WMCreateButton(win, i);
		WMResizeWidget(b, 150, 24);
		WMMoveWidget(b, 20, i * 30);
		WMSetButtonText(b, types[i - 1]);
	}

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);
}

void testGradientButtons(WMScreen * scr)
{
	WMWindow *win;
	WMButton *btn;
	WMPixmap *pix1, *pix2;
	RImage *back;
	RColor light, dark;
	WMColor *color, *altColor;

	windowCount++;

	/* creates the top-level window */
	win = WMCreateWindow(scr, "testGradientButtons");
	WMSetWindowTitle(win, "Gradiented Button Demo");
	WMResizeWidget(win, 300, 200);

	WMSetWindowCloseAction(win, closeAction, NULL);

	light.red = 0x90;
	light.green = 0x85;
	light.blue = 0x90;
	dark.red = 0x35;
	dark.green = 0x30;
	dark.blue = 0x35;

	color = WMCreateRGBColor(scr, 0x5900, 0x5100, 0x5900, True);
	WMSetWidgetBackgroundColor(win, color);
	WMReleaseColor(color);

	back = RRenderGradient(60, 24, &dark, &light, RGRD_DIAGONAL);
	RBevelImage(back, RBEV_RAISED2);
	pix1 = WMCreatePixmapFromRImage(scr, back, 0);
	RReleaseImage(back);

	back = RRenderGradient(60, 24, &dark, &light, RGRD_DIAGONAL);
	RBevelImage(back, RBEV_SUNKEN);
	pix2 = WMCreatePixmapFromRImage(scr, back, 0);
	RReleaseImage(back);

	color = WMWhiteColor(scr);
	altColor = WMCreateNamedColor(scr, "red", True);

	btn = WMCreateButton(win, WBTMomentaryChange);
	WMResizeWidget(btn, 60, 24);
	WMMoveWidget(btn, 20, 100);
	WMSetButtonBordered(btn, False);
	WMSetButtonImagePosition(btn, WIPOverlaps);
	WMSetButtonImage(btn, pix1);
	WMSetButtonAltImage(btn, pix2);
	WMSetButtonText(btn, "Cool");
	WMSetButtonTextColor(btn, color);
	WMSetButtonAltTextColor(btn, altColor);

	WMSetBalloonTextForView("This is a cool button", WMWidgetView(btn));

	btn = WMCreateButton(win, WBTMomentaryChange);
	WMResizeWidget(btn, 60, 24);
	WMMoveWidget(btn, 90, 100);
	WMSetButtonBordered(btn, False);
	WMSetButtonImagePosition(btn, WIPOverlaps);
	WMSetButtonImage(btn, pix1);
	WMSetButtonAltImage(btn, pix2);
	WMSetButtonText(btn, "Button");
	WMSetButtonTextColor(btn, color);

	WMSetBalloonTextForView("Este é outro balão.", WMWidgetView(btn));

	WMReleaseColor(color);
	color = WMCreateNamedColor(scr, "orange", True);

	btn = WMCreateButton(win, WBTMomentaryChange);
	WMResizeWidget(btn, 60, 24);
	WMMoveWidget(btn, 160, 100);
	WMSetButtonBordered(btn, False);
	WMSetButtonImagePosition(btn, WIPOverlaps);
	WMSetButtonImage(btn, pix1);
	WMSetButtonAltImage(btn, pix2);
	WMSetButtonText(btn, "Test");
	WMSetButtonTextColor(btn, color);

	WMSetBalloonTextForView("This is yet another button.\nBut the balloon has 3 lines.\nYay!",
				WMWidgetView(btn));

	WMReleaseColor(color);
	WMReleaseColor(altColor);

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);
}

void testScrollView(WMScreen * scr)
{
	WMWindow *win;
	WMScrollView *sview;
	WMFrame *f;
	WMLabel *l;
	char buffer[128];
	int i;

	windowCount++;

	/* creates the top-level window */
	win = WMCreateWindow(scr, "testScroll");
	WMSetWindowTitle(win, "Scrollable View");

	WMSetWindowCloseAction(win, closeAction, NULL);

	/* set the window size */
	WMResizeWidget(win, 300, 300);

	/* creates a scrollable view inside the top-level window */
	sview = WMCreateScrollView(win);
	WMResizeWidget(sview, 200, 200);
	WMMoveWidget(sview, 30, 30);
	WMSetScrollViewRelief(sview, WRSunken);
	WMSetScrollViewHasVerticalScroller(sview, True);
	WMSetScrollViewHasHorizontalScroller(sview, True);

	/* create a frame with a bunch of labels */
	f = WMCreateFrame(win);
	WMResizeWidget(f, 400, 400);
	WMSetFrameRelief(f, WRFlat);

	for (i = 0; i < 20; i++) {
		l = WMCreateLabel(f);
		WMResizeWidget(l, 50, 18);
		WMMoveWidget(l, 10, 20 * i);
		sprintf(buffer, "Label %i", i);
		WMSetLabelText(l, buffer);
		WMSetLabelRelief(l, WRSimple);
	}
	WMMapSubwidgets(f);
	WMMapWidget(f);

	WMSetScrollViewContentView(sview, WMWidgetView(f));

	/* make the windows of the widgets be actually created */
	WMRealizeWidget(win);

	/* Map all child widgets of the top-level be mapped.
	 * You must call this for each container widget (like frames),
	 * even if they are childs of the top-level window.
	 */
	WMMapSubwidgets(win);

	/* map the top-level window */
	WMMapWidget(win);
}

void testColorWell(WMScreen * scr)
{
	WMWindow *win;
	WMColorWell *well1, *well2;

	windowCount++;

	win = WMCreateWindow(scr, "testColor");
	WMResizeWidget(win, 300, 300);
	WMSetWindowCloseAction(win, closeAction, NULL);

	well1 = WMCreateColorWell(win);
	WMResizeWidget(well1, 60, 40);
	WMMoveWidget(well1, 100, 100);
	WMSetColorWellColor(well1, WMCreateRGBColor(scr, 0x8888, 0, 0x1111, True));
	well2 = WMCreateColorWell(win);
	WMResizeWidget(well2, 60, 40);
	WMMoveWidget(well2, 200, 100);
	WMSetColorWellColor(well2, WMCreateRGBColor(scr, 0, 0, 0x8888, True));

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);
}

void testColorPanel(WMScreen * scr)
{
	WMColorPanel *panel = WMGetColorPanel(scr);

	/*if (colorname) {
	   startcolor = WMCreateNamedColor(scr, colorname, False);
	   WMSetColorPanelColor(panel, startcolor);
	   WMReleaseColor(startcolor);
	   } */

	WMShowColorPanel(panel);
}

void sliderCallback(WMWidget * w, void *data)
{
	printf("SLIDER == %i\n", WMGetSliderValue(w));
}

void testSlider(WMScreen * scr)
{
	WMWindow *win;
	WMSlider *s;

	windowCount++;

	win = WMCreateWindow(scr, "testSlider");
	WMResizeWidget(win, 300, 300);
	WMSetWindowTitle(win, "Sliders");

	WMSetWindowCloseAction(win, closeAction, NULL);

	s = WMCreateSlider(win);
	WMResizeWidget(s, 16, 100);
	WMMoveWidget(s, 100, 100);
	WMSetSliderKnobThickness(s, 8);
	WMSetSliderContinuous(s, False);
	WMSetSliderAction(s, sliderCallback, s);

	s = WMCreateSlider(win);
	WMResizeWidget(s, 100, 16);
	WMMoveWidget(s, 100, 10);
	WMSetSliderKnobThickness(s, 8);

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);
}

void testTextField(WMScreen * scr)
{
	WMWindow *win;
	WMTextField *field, *field2;

	windowCount++;

	win = WMCreateWindow(scr, "testTextField");
	WMResizeWidget(win, 400, 300);

	WMSetWindowCloseAction(win, closeAction, NULL);

	field = WMCreateTextField(win);
	WMResizeWidget(field, 200, 20);
	WMMoveWidget(field, 20, 20);
	WMSetTextFieldText(field, "the little \xc2\xa9 sign");

	field2 = WMCreateTextField(win);
	WMResizeWidget(field2, 200, 20);
	WMMoveWidget(field2, 20, 50);
	WMSetTextFieldAlignment(field2, WARight);

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);

}

void testText(WMScreen * scr)
{
	WMWindow *win;
	WMText *text;
	WMFont *font;
	void *tb;
	FILE *file = fopen("wm.html", "rb");

	windowCount++;

	win = WMCreateWindow(scr, "testText");
	WMResizeWidget(win, 500, 300);

	WMSetWindowCloseAction(win, closeAction, NULL);

	text = WMCreateText(win);
	WMResizeWidget(text, 480, 280);
	WMMoveWidget(text, 10, 10);
	WMSetTextHasVerticalScroller(text, True);
	WMSetTextEditable(text, False);
	WMSetTextIgnoresNewline(text, False);

#define FNAME "Verdana,sans serif:pixelsize=12"
#define MSG \
    "Window Maker is the GNU window manager for the " \
    "X Window System. It was designed to emulate the " \
    "look and feel of part of the NEXTSTEP(tm) GUI. It's " \
    "supposed to be relatively fast and small, feature " \
    "rich, easy to configure and easy to use, with a simple " \
    "and elegant appearance borrowed from NEXTSTEP(tm)."

	font = WMCreateFont(scr, FNAME ":autohint=false");
	WMSetTextDefaultFont(text, font);
	WMReleaseFont(font);

	if (0 && file) {
		char buf[1024];

		WMFreezeText(text);
		while (fgets(buf, 1023, file))
			WMAppendTextStream(text, buf);

		fclose(file);
		WMThawText(text);
	} else {
		WMAppendTextStream(text, "First paragraph has autohinting turned off, "
				   "while the second has it turned on:");
		WMAppendTextStream(text, "\n\n\n");
		WMAppendTextStream(text, MSG);
		WMAppendTextStream(text, "\n\n\n");
		font = WMCreateFont(scr, FNAME ":autohint=true");
		tb = WMCreateTextBlockWithText(text, MSG, font, WMBlackColor(scr), 0, strlen(MSG));
		WMAppendTextBlock(text, tb);
		WMReleaseFont(font);
	}

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);
}

void testProgressIndicator(WMScreen * scr)
{
	WMWindow *win;
	WMProgressIndicator *pPtr;

	windowCount++;

	win = WMCreateWindow(scr, "testProgressIndicator");
	WMResizeWidget(win, 292, 32);

	WMSetWindowCloseAction(win, closeAction, NULL);

	pPtr = WMCreateProgressIndicator(win);
	WMMoveWidget(pPtr, 8, 8);
	WMSetProgressIndicatorValue(pPtr, 75);

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);

}

void testPullDown(WMScreen * scr)
{
	WMWindow *win;
	WMPopUpButton *pop, *pop2;

	windowCount++;

	win = WMCreateWindow(scr, "pullDown");
	WMResizeWidget(win, 400, 300);

	WMSetWindowCloseAction(win, closeAction, NULL);

	pop = WMCreatePopUpButton(win);
	WMResizeWidget(pop, 100, 20);
	WMMoveWidget(pop, 50, 60);
	WMSetPopUpButtonPullsDown(pop, True);
	WMSetPopUpButtonText(pop, "Commands");
	WMAddPopUpButtonItem(pop, "Add");
	WMAddPopUpButtonItem(pop, "Remove");
	WMAddPopUpButtonItem(pop, "Check");
	WMAddPopUpButtonItem(pop, "Eat");

	pop2 = WMCreatePopUpButton(win);
	WMResizeWidget(pop2, 100, 20);
	WMMoveWidget(pop2, 200, 60);
	WMSetPopUpButtonText(pop2, "Select");
	WMAddPopUpButtonItem(pop2, "Apples");
	WMAddPopUpButtonItem(pop2, "Bananas");
	WMAddPopUpButtonItem(pop2, "Strawberries");
	WMAddPopUpButtonItem(pop2, "Blueberries");

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);

}

void testTabView(WMScreen * scr)
{
	WMWindow *win;
	WMTabView *tabv;
	WMTabViewItem *tab;
	WMFrame *frame;
	WMLabel *label;

	windowCount++;

	win = WMCreateWindow(scr, "testTabs");
	WMResizeWidget(win, 400, 300);

	WMSetWindowCloseAction(win, closeAction, NULL);

	tabv = WMCreateTabView(win);
	WMMoveWidget(tabv, 50, 50);
	WMResizeWidget(tabv, 300, 200);

	frame = WMCreateFrame(win);
	WMSetFrameRelief(frame, WRFlat);
	label = WMCreateLabel(frame);
	WMResizeWidget(label, 100, 100);
	WMSetLabelText(label, "Label 1");
	WMMapWidget(label);

	tab = WMCreateTabViewItemWithIdentifier(0);
	WMSetTabViewItemView(tab, WMWidgetView(frame));
	WMAddItemInTabView(tabv, tab);
	WMSetTabViewItemLabel(tab, "Instances");

	frame = WMCreateFrame(win);
	WMSetFrameRelief(frame, WRFlat);
	label = WMCreateLabel(frame);
	WMResizeWidget(label, 40, 50);
	WMSetLabelText(label, "Label 2");
	WMMapWidget(label);

	tab = WMCreateTabViewItemWithIdentifier(0);
	WMSetTabViewItemView(tab, WMWidgetView(frame));
	WMAddItemInTabView(tabv, tab);
	WMSetTabViewItemLabel(tab, "Classes");

	frame = WMCreateFrame(win);
	WMSetFrameRelief(frame, WRFlat);
	label = WMCreateLabel(frame);
	WMResizeWidget(label, 100, 100);
	WMMoveWidget(label, 60, 40);
	WMSetLabelText(label, "Label 3");
	WMMapWidget(label);

	tab = WMCreateTabViewItemWithIdentifier(0);
	WMSetTabViewItemView(tab, WMWidgetView(frame));
	WMAddItemInTabView(tabv, tab);
	WMSetTabViewItemLabel(tab, "Something");

	frame = WMCreateFrame(win);
	WMSetFrameRelief(frame, WRFlat);
	label = WMCreateLabel(frame);
	WMResizeWidget(label, 100, 100);
	WMMoveWidget(label, 160, 40);
	WMSetLabelText(label, "Label 4");
	WMMapWidget(label);

	tab = WMCreateTabViewItemWithIdentifier(0);
	WMSetTabViewItemView(tab, WMWidgetView(frame));
	WMAddItemInTabView(tabv, tab);
	WMSetTabViewItemLabel(tab, "Bla!");

	frame = WMCreateFrame(win);
	WMSetFrameRelief(frame, WRFlat);
	label = WMCreateLabel(frame);
	WMResizeWidget(label, 100, 100);
	WMMoveWidget(label, 160, 40);
	WMSetLabelText(label, "Label fjweqklrj qwl");
	WMMapWidget(label);
	tab = WMCreateTabViewItemWithIdentifier(0);
	WMSetTabViewItemView(tab, WMWidgetView(frame));
	WMAddItemInTabView(tabv, tab);
	WMSetTabViewItemLabel(tab, "Weee!");

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);
}

void splitViewConstrainProc(WMSplitView * sPtr, int indView, int *minSize, int *maxSize)
{
	switch (indView) {
	case 0:
		*minSize = 20;
		break;
	case 1:
		*minSize = 40;
		*maxSize = 80;
		break;
	case 2:
		*maxSize = 60;
		break;
	default:
		break;
	}
}

static void resizeSplitView(XEvent * event, void *data)
{
	WMSplitView *sPtr = (WMSplitView *) data;

	if (event->type == ConfigureNotify) {
		int width = event->xconfigure.width - 10;

		if (width < WMGetSplitViewDividerThickness(sPtr))
			width = WMGetSplitViewDividerThickness(sPtr);

		if (width != WMWidgetWidth(sPtr) || event->xconfigure.height != WMWidgetHeight(sPtr))
			WMResizeWidget(sPtr, width, event->xconfigure.height - 55);
	}
}

void appendSubviewButtonAction(WMWidget * self, void *data)
{
	WMSplitView *sPtr = (WMSplitView *) data;
	char buf[64];
	WMLabel *label = WMCreateLabel(sPtr);

	sprintf(buf, "Subview %d", WMGetSplitViewSubviewsCount(sPtr) + 1);
	WMSetLabelText(label, buf);
	WMSetLabelRelief(label, WRSunken);
	WMAddSplitViewSubview(sPtr, WMWidgetView(label));
	WMRealizeWidget(label);
	WMMapWidget(label);
}

void removeSubviewButtonAction(WMWidget * self, void *data)
{
	WMSplitView *sPtr = (WMSplitView *) data;
	int count = WMGetSplitViewSubviewsCount(sPtr);

	if (count > 2) {
		WMView *view = WMGetSplitViewSubviewAt(sPtr, count - 1);
		WMDestroyWidget(WMWidgetOfView(view));
		WMRemoveSplitViewSubviewAt(sPtr, count - 1);
	}
}

void orientationButtonAction(WMWidget * self, void *data)
{
	WMSplitView *sPtr = (WMSplitView *) data;
	WMSetSplitViewVertical(sPtr, !WMGetSplitViewVertical(sPtr));
}

void adjustSubviewsButtonAction(WMWidget * self, void *data)
{
	WMAdjustSplitViewSubviews((WMSplitView *) data);
}

void testSplitView(WMScreen * scr)
{
	WMWindow *win;
	WMSplitView *splitv1, *splitv2;
	WMFrame *frame;
	WMLabel *label;
	WMButton *button;

	windowCount++;

	win = WMCreateWindow(scr, "testTabs");
	WMResizeWidget(win, 300, 400);
	WMSetWindowCloseAction(win, closeAction, NULL);

	frame = WMCreateFrame(win);
	WMSetFrameRelief(frame, WRSunken);
	WMMoveWidget(frame, 5, 5);
	WMResizeWidget(frame, 290, 40);

	splitv1 = WMCreateSplitView(win);
	WMMoveWidget(splitv1, 5, 50);
	WMResizeWidget(splitv1, 290, 345);
	WMSetSplitViewConstrainProc(splitv1, splitViewConstrainProc);
	WMCreateEventHandler(WMWidgetView(win), StructureNotifyMask, resizeSplitView, splitv1);

	button = WMCreateCommandButton(frame);
	WMSetButtonText(button, "+");
	WMSetButtonAction(button, appendSubviewButtonAction, splitv1);
	WMMoveWidget(button, 10, 8);
	WMMapWidget(button);

	button = WMCreateCommandButton(frame);
	WMSetButtonText(button, "-");
	WMSetButtonAction(button, removeSubviewButtonAction, splitv1);
	WMMoveWidget(button, 80, 8);
	WMMapWidget(button);

	button = WMCreateCommandButton(frame);
	WMSetButtonText(button, "=");
	WMMoveWidget(button, 150, 8);
	WMSetButtonAction(button, adjustSubviewsButtonAction, splitv1);
	WMMapWidget(button);

	button = WMCreateCommandButton(frame);
	WMSetButtonText(button, "#");
	WMMoveWidget(button, 220, 8);
	WMSetButtonAction(button, orientationButtonAction, splitv1);
	WMMapWidget(button);

	label = WMCreateLabel(splitv1);
	WMSetLabelText(label, "Subview 1");
	WMSetLabelRelief(label, WRSunken);
	WMMapWidget(label);
	WMAddSplitViewSubview(splitv1, WMWidgetView(label));

	splitv2 = WMCreateSplitView(splitv1);
	WMResizeWidget(splitv2, 150, 150);
	WMSetSplitViewVertical(splitv2, True);

	label = WMCreateLabel(splitv2);
	WMSetLabelText(label, "Subview 2.1");
	WMSetLabelRelief(label, WRSunken);
	WMMapWidget(label);
	WMAddSplitViewSubview(splitv2, WMWidgetView(label));

	label = WMCreateLabel(splitv2);
	WMSetLabelText(label, "Subview 2.2");
	WMSetLabelRelief(label, WRSunken);
	WMMapWidget(label);
	WMAddSplitViewSubview(splitv2, WMWidgetView(label));

	label = WMCreateLabel(splitv2);
	WMSetLabelText(label, "Subview 2.3");
	WMSetLabelRelief(label, WRSunken);
	WMMapWidget(label);
	WMAddSplitViewSubview(splitv2, WMWidgetView(label));

	WMMapWidget(splitv2);
	WMAddSplitViewSubview(splitv1, WMWidgetView(splitv2));

	WMRealizeWidget(win);
	WMMapSubwidgets(win);
	WMMapWidget(win);
}

void testUD()
{
	WMUserDefaults *defs;
	char str[32];

	defs = WMGetStandardUserDefaults();

	sprintf(str, "TEST DATA");
	puts(str);
	WMSetUDStringForKey(defs, str, "testKey");
	puts(str);
}

int main(int argc, char **argv)
{
	WMScreen *scr;
	WMPixmap *pixmap;

	/* Initialize the application */
	WMInitializeApplication("Test@eqweq_ewq$eqw", &argc, argv);

	testUD();

	/*
	 * Open connection to the X display.
	 */
	dpy = XOpenDisplay("");

	if (!dpy) {
		puts("could not open display");
		exit(1);
	}

	/* This is used to disable buffering of X protocol requests.
	 * Do NOT use it unless when debugging. It will cause a major
	 * slowdown in your application
	 */
#if 0
	XSynchronize(dpy, True);
#endif
	/*
	 * Create screen descriptor.
	 */
	scr = WMCreateScreen(dpy, DefaultScreen(dpy));

	/*
	 * Loads the logo of the application.
	 */
	pixmap = WMCreatePixmapFromFile(scr, "logo.xpm");

	/*
	 * Makes the logo be used in standard dialog panels.
	 */
	if (pixmap) {
		WMSetApplicationIconPixmap(scr, pixmap);
		WMReleasePixmap(pixmap);
	}

	/*
	 * Do some test stuff.
	 *
	 * Put the testSomething() function you want to test here.
	 */

	testText(scr);
	testFontPanel(scr);

	testColorPanel(scr);

	testTextField(scr);

#if 0

	testBox(scr);
	testButton(scr);
	testColorPanel(scr);
	testColorWell(scr);
	testDragAndDrop(scr);
	testFrame(scr);
	testGradientButtons(scr);
	testList(scr);
	testOpenFilePanel(scr);
	testProgressIndicator(scr);
	testPullDown(scr);
	testScrollView(scr);
	testSlider(scr);
	testSplitView(scr);
	testTabView(scr);
	testTextField(scr);
#endif
	/*
	 * The main event loop.
	 *
	 */
	WMScreenMainLoop(scr);

	return 0;
}
