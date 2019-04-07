
#include "WINGsP.h"

#include <X11/keysym.h>
#include <stdint.h>

static void alertPanelOnClick(WMWidget * self, void *clientData)
{
	WMAlertPanel *panel = clientData;

	WMBreakModalLoop(WMWidgetScreen(self));
	if (self == panel->defBtn) {
		panel->result = WAPRDefault;
	} else if (self == panel->othBtn) {
		panel->result = WAPROther;
	} else if (self == panel->altBtn) {
		panel->result = WAPRAlternate;
	}
}

static void handleKeyPress(XEvent * event, void *clientData)
{
	WMAlertPanel *panel = (WMAlertPanel *) clientData;
	KeySym ksym;

	XLookupString(&event->xkey, NULL, 0, &ksym, NULL);

	if (ksym == XK_Return && panel->defBtn) {
		WMPerformButtonClick(panel->defBtn);
	} else if (ksym == XK_Escape) {
		if (panel->altBtn || panel->othBtn) {
			WMPerformButtonClick(panel->othBtn ? panel->othBtn : panel->altBtn);
		} else {
			panel->result = WAPRDefault;
			WMBreakModalLoop(WMWidgetScreen(panel->win));
		}
	}
}

int
WMRunAlertPanel(WMScreen * scrPtr, WMWindow * owner,
		const char *title, const char *msg, const char *defaultButton, const char *alternateButton, const char *otherButton)
{
	WMAlertPanel *panel;
	int tmp;

	panel = WMCreateAlertPanel(scrPtr, owner, title, msg, defaultButton, alternateButton, otherButton);

	{
		int px, py;
		WMView *view = WMWidgetView(panel->win);

		if (owner) {
			WMView *oview = WMWidgetView(owner);
			WMPoint pt = WMGetViewScreenPosition(oview);

			px = (W_VIEW_WIDTH(oview) - W_VIEW_WIDTH(view)) / 2;
			py = (W_VIEW_HEIGHT(oview) - W_VIEW_HEIGHT(view)) / 2;

			px += pt.x;
			py += pt.y;
		} else {
			px = (W_VIEW_WIDTH(scrPtr->rootView) - W_VIEW_WIDTH(view)) / 2;
			py = (W_VIEW_HEIGHT(scrPtr->rootView) - W_VIEW_HEIGHT(view)) / 2;
		}
		WMSetWindowInitialPosition(panel->win, px, py);
	}

	WMMapWidget(panel->win);

	WMRunModalLoop(scrPtr, W_VIEW(panel->win));

	tmp = panel->result;

	WMDestroyAlertPanel(panel);

	return tmp;
}

void WMDestroyAlertPanel(WMAlertPanel * panel)
{
	WMUnmapWidget(panel->win);
	WMDestroyWidget(panel->win);
	wfree(panel);
}

WMAlertPanel *WMCreateAlertPanel(WMScreen * scrPtr, WMWindow * owner,
				 const char *title, const char *msg, const char *defaultButton,
				 const char *alternateButton, const char *otherButton)
{
	WMAlertPanel *panel;
	int dw = 0, aw = 0, ow = 0, w;
	WMBox *hbox;
	WMPixmap *icon;

	panel = wmalloc(sizeof(WMAlertPanel));

	if (owner) {
		panel->win = WMCreatePanelWithStyleForWindow(owner, "alertPanel", WMTitledWindowMask);
	} else {
		panel->win = WMCreateWindowWithStyle(scrPtr, "alertPanel", WMTitledWindowMask);
	}

	WMSetWindowInitialPosition(panel->win,
				   (scrPtr->rootView->size.width - WMWidgetWidth(panel->win)) / 2,
				   (scrPtr->rootView->size.height - WMWidgetHeight(panel->win)) / 2);

	WMSetWindowTitle(panel->win, "");

	panel->vbox = WMCreateBox(panel->win);
	WMSetViewExpandsToParent(WMWidgetView(panel->vbox), 0, 0, 0, 0);
	WMSetBoxHorizontal(panel->vbox, False);
	WMMapWidget(panel->vbox);

	hbox = WMCreateBox(panel->vbox);
	WMSetBoxBorderWidth(hbox, 5);
	WMSetBoxHorizontal(hbox, True);
	WMMapWidget(hbox);
	WMAddBoxSubview(panel->vbox, WMWidgetView(hbox), False, True, 74, 0, 5);

	panel->iLbl = WMCreateLabel(hbox);
	WMSetLabelImagePosition(panel->iLbl, WIPImageOnly);
	WMMapWidget(panel->iLbl);
	WMAddBoxSubview(hbox, WMWidgetView(panel->iLbl), False, True, 64, 0, 10);
	icon = WMCreateApplicationIconBlendedPixmap(scrPtr, (RColor *) NULL);
	if (icon) {
		WMSetLabelImage(panel->iLbl, icon);
		WMReleasePixmap(icon);
	} else {
		WMSetLabelImage(panel->iLbl, scrPtr->applicationIconPixmap);
	}

	if (title) {
		WMFont *largeFont;

		largeFont = WMBoldSystemFontOfSize(scrPtr, 24);

		panel->tLbl = WMCreateLabel(hbox);
		WMMapWidget(panel->tLbl);
		WMAddBoxSubview(hbox, WMWidgetView(panel->tLbl), True, True, 64, 0, 0);
		WMSetLabelText(panel->tLbl, title);
		WMSetLabelTextAlignment(panel->tLbl, WALeft);
		WMSetLabelFont(panel->tLbl, largeFont);

		WMReleaseFont(largeFont);
	}

	/* create divider line */

	panel->line = WMCreateFrame(panel->win);
	WMMapWidget(panel->line);
	WMAddBoxSubview(panel->vbox, WMWidgetView(panel->line), False, True, 2, 2, 5);
	WMSetFrameRelief(panel->line, WRGroove);

	if (msg) {
		panel->mLbl = WMCreateLabel(panel->vbox);
		WMSetLabelWraps(panel->mLbl, True);
		WMMapWidget(panel->mLbl);
		WMAddBoxSubview(panel->vbox, WMWidgetView(panel->mLbl), True, True,
				WMFontHeight(scrPtr->normalFont) * 4, 0, 5);
		WMSetLabelText(panel->mLbl, msg);
		WMSetLabelTextAlignment(panel->mLbl, WACenter);
	}

	panel->hbox = WMCreateBox(panel->vbox);
	WMSetBoxBorderWidth(panel->hbox, 10);
	WMSetBoxHorizontal(panel->hbox, True);
	WMMapWidget(panel->hbox);
	WMAddBoxSubview(panel->vbox, WMWidgetView(panel->hbox), False, True, 44, 0, 0);

	/* create buttons */
	if (otherButton)
		ow = WMWidthOfString(scrPtr->normalFont, otherButton, strlen(otherButton));

	if (alternateButton)
		aw = WMWidthOfString(scrPtr->normalFont, alternateButton, strlen(alternateButton));

	if (defaultButton)
		dw = WMWidthOfString(scrPtr->normalFont, defaultButton, strlen(defaultButton));

	dw = dw + (scrPtr->buttonArrow ? scrPtr->buttonArrow->width : 0);

	aw += 30;
	ow += 30;
	dw += 30;

	w = WMAX(dw, WMAX(aw, ow));
	if ((w + 10) * 3 < 400) {
		aw = w;
		ow = w;
		dw = w;
	} else {
		int t;

		t = 400 - 40 - aw - ow - dw;
		aw += t / 3;
		ow += t / 3;
		dw += t / 3;
	}

	if (defaultButton) {
		panel->defBtn = WMCreateCommandButton(panel->hbox);
		WMSetButtonAction(panel->defBtn, alertPanelOnClick, panel);
		WMAddBoxSubviewAtEnd(panel->hbox, WMWidgetView(panel->defBtn), False, True, dw, 0, 0);
		WMSetButtonText(panel->defBtn, defaultButton);
		WMSetButtonImage(panel->defBtn, scrPtr->buttonArrow);
		WMSetButtonAltImage(panel->defBtn, scrPtr->pushedButtonArrow);
		WMSetButtonImagePosition(panel->defBtn, WIPRight);
	}
	if (alternateButton) {
		panel->altBtn = WMCreateCommandButton(panel->hbox);
		WMAddBoxSubviewAtEnd(panel->hbox, WMWidgetView(panel->altBtn), False, True, aw, 0, 5);
		WMSetButtonAction(panel->altBtn, alertPanelOnClick, panel);
		WMSetButtonText(panel->altBtn, alternateButton);
	}
	if (otherButton) {
		panel->othBtn = WMCreateCommandButton(panel->hbox);
		WMSetButtonAction(panel->othBtn, alertPanelOnClick, panel);
		WMAddBoxSubviewAtEnd(panel->hbox, WMWidgetView(panel->othBtn), False, True, ow, 0, 5);
		WMSetButtonText(panel->othBtn, otherButton);
	}

	WMMapSubwidgets(panel->hbox);

	WMCreateEventHandler(W_VIEW(panel->win), KeyPressMask, handleKeyPress, panel);

	WMRealizeWidget(panel->win);
	WMMapSubwidgets(panel->win);

	return panel;
}

static void inputBoxOnClick(WMWidget * self, void *clientData)
{
	WMInputPanel *panel = clientData;

	WMBreakModalLoop(WMWidgetScreen(self));
	if (self == panel->defBtn) {
		panel->result = WAPRDefault;
	} else if (self == panel->altBtn) {
		panel->result = WAPRAlternate;
	}
}

static void handleKeyPress2(XEvent * event, void *clientData)
{
	WMInputPanel *panel = (WMInputPanel *) clientData;
	KeySym ksym;

	XLookupString(&event->xkey, NULL, 0, &ksym, NULL);

	if (ksym == XK_Return && panel->defBtn) {
		WMPerformButtonClick(panel->defBtn);
	} else if (ksym == XK_Escape) {
		if (panel->altBtn) {
			WMPerformButtonClick(panel->altBtn);
		} else {
			/*           printf("got esc\n"); */
			WMBreakModalLoop(WMWidgetScreen(panel->win));
			panel->result = WAPRDefault;
		}
	}
}

char *WMRunInputPanel(WMScreen * scrPtr, WMWindow * owner, const char *title,
		      const char *msg, const char *defaultText, const char *okButton, const char *cancelButton)
{
	WMInputPanel *panel;
	char *tmp;

	panel = WMCreateInputPanel(scrPtr, owner, title, msg, defaultText, okButton, cancelButton);

	{
		int px, py;
		WMView *view = WMWidgetView(panel->win);

		if (owner) {
			WMView *oview = WMWidgetView(owner);
			WMPoint pt = WMGetViewScreenPosition(oview);

			px = (W_VIEW_WIDTH(oview) - W_VIEW_WIDTH(view)) / 2;
			py = (W_VIEW_HEIGHT(oview) - W_VIEW_HEIGHT(view)) / 2;

			px += pt.x;
			py += pt.y;
		} else {
			px = (W_VIEW_WIDTH(scrPtr->rootView) - W_VIEW_WIDTH(view)) / 2;
			py = (W_VIEW_HEIGHT(scrPtr->rootView) - W_VIEW_HEIGHT(view)) / 2;
		}
		WMSetWindowInitialPosition(panel->win, px, py);
	}

	WMMapWidget(panel->win);

	WMRunModalLoop(scrPtr, W_VIEW(panel->win));

	if (panel->result == WAPRDefault)
		tmp = WMGetTextFieldText(panel->text);
	else
		tmp = NULL;

	WMDestroyInputPanel(panel);

	return tmp;
}

void WMDestroyInputPanel(WMInputPanel * panel)
{
	WMRemoveNotificationObserver(panel);
	WMUnmapWidget(panel->win);
	WMDestroyWidget(panel->win);
	wfree(panel);
}

static void endedEditingObserver(void *observerData, WMNotification * notification)
{
	WMInputPanel *panel = (WMInputPanel *) observerData;

	switch ((uintptr_t)WMGetNotificationClientData(notification)) {
	case WMReturnTextMovement:
		if (panel->defBtn)
			WMPerformButtonClick(panel->defBtn);
		break;
	case WMEscapeTextMovement:
		if (panel->altBtn)
			WMPerformButtonClick(panel->altBtn);
		else {
			WMBreakModalLoop(WMWidgetScreen(panel->win));
			panel->result = WAPRDefault;
		}
		break;
	default:
		break;
	}
}

WMInputPanel *WMCreateInputPanel(WMScreen * scrPtr, WMWindow * owner, const char *title, const char *msg,
				 const char *defaultText, const char *okButton, const char *cancelButton)
{
	WMInputPanel *panel;
	int x, dw = 0, aw = 0, w;

	panel = wmalloc(sizeof(WMInputPanel));

	if (owner)
		panel->win = WMCreatePanelWithStyleForWindow(owner, "inputPanel", WMTitledWindowMask);
	else
		panel->win = WMCreateWindowWithStyle(scrPtr, "inputPanel", WMTitledWindowMask);
	WMSetWindowTitle(panel->win, "");

	WMResizeWidget(panel->win, 320, 160);

	if (title) {
		WMFont *largeFont;

		largeFont = WMBoldSystemFontOfSize(scrPtr, 24);

		panel->tLbl = WMCreateLabel(panel->win);
		WMMoveWidget(panel->tLbl, 20, 16);
		WMResizeWidget(panel->tLbl, 320 - 40, WMFontHeight(largeFont) + 4);
		WMSetLabelText(panel->tLbl, title);
		WMSetLabelTextAlignment(panel->tLbl, WALeft);
		WMSetLabelFont(panel->tLbl, largeFont);

		WMReleaseFont(largeFont);
	}

	if (msg) {
		panel->mLbl = WMCreateLabel(panel->win);
		WMMoveWidget(panel->mLbl, 20, 50);
		WMResizeWidget(panel->mLbl, 320 - 40, WMFontHeight(scrPtr->normalFont) * 2);
		WMSetLabelText(panel->mLbl, msg);
		WMSetLabelTextAlignment(panel->mLbl, WALeft);
	}

	panel->text = WMCreateTextField(panel->win);
	WMMoveWidget(panel->text, 20, 85);
	WMResizeWidget(panel->text, 320 - 40, WMWidgetHeight(panel->text));
	WMSetTextFieldText(panel->text, defaultText);

	WMAddNotificationObserver(endedEditingObserver, panel, WMTextDidEndEditingNotification, panel->text);

	/* create buttons */
	if (cancelButton)
		aw = WMWidthOfString(scrPtr->normalFont, cancelButton, strlen(cancelButton));

	if (okButton)
		dw = WMWidthOfString(scrPtr->normalFont, okButton, strlen(okButton));

	w = dw + (scrPtr->buttonArrow ? scrPtr->buttonArrow->width : 0);
	if (aw > w)
		w = aw;

	w += 30;
	x = 310;

	if (okButton) {
		x -= w + 10;

		panel->defBtn = WMCreateCustomButton(panel->win, WBBPushInMask
						     | WBBPushChangeMask | WBBPushLightMask);
		WMSetButtonAction(panel->defBtn, inputBoxOnClick, panel);
		WMMoveWidget(panel->defBtn, x, 124);
		WMResizeWidget(panel->defBtn, w, 24);
		WMSetButtonText(panel->defBtn, okButton);
		WMSetButtonImage(panel->defBtn, scrPtr->buttonArrow);
		WMSetButtonAltImage(panel->defBtn, scrPtr->pushedButtonArrow);
		WMSetButtonImagePosition(panel->defBtn, WIPRight);
	}
	if (cancelButton) {
		x -= w + 10;

		panel->altBtn = WMCreateCommandButton(panel->win);
		WMSetButtonAction(panel->altBtn, inputBoxOnClick, panel);
		WMMoveWidget(panel->altBtn, x, 124);
		WMResizeWidget(panel->altBtn, w, 24);
		WMSetButtonText(panel->altBtn, cancelButton);
	}

	WMCreateEventHandler(W_VIEW(panel->win), KeyPressMask, handleKeyPress2, panel);

	WMRealizeWidget(panel->win);
	WMMapSubwidgets(panel->win);

	WMSetFocusToWidget(panel->text);

	return panel;
}

static void handleKeyPress3(XEvent * event, void *clientData)
{
	WMGenericPanel *panel = (WMGenericPanel *) clientData;
	KeySym ksym;

	XLookupString(&event->xkey, NULL, 0, &ksym, NULL);

	if (ksym == XK_Return && panel->defBtn) {
		WMPerformButtonClick(panel->defBtn);
	} else if (ksym == XK_Escape) {
		if (panel->altBtn) {
			WMPerformButtonClick(panel->altBtn);
		} else {
			panel->result = WAPRDefault;
			WMBreakModalLoop(WMWidgetScreen(panel->win));
		}
	}
}

void WMDestroyGenericPanel(WMGenericPanel * panel)
{
	WMUnmapWidget(panel->win);
	WMDestroyWidget(panel->win);
	wfree(panel);
}

WMGenericPanel *WMCreateGenericPanel(WMScreen * scrPtr, WMWindow * owner,
				     const char *title, const char *defaultButton, const char *alternateButton)
{
	WMGenericPanel *panel;
	int dw = 0, aw = 0, w;
	WMBox *hbox;
	WMPixmap *icon;

	panel = wmalloc(sizeof(WMGenericPanel));

	if (owner) {
		panel->win = WMCreatePanelWithStyleForWindow(owner, "genericPanel", WMTitledWindowMask);
	} else {
		panel->win = WMCreateWindowWithStyle(scrPtr, "genericPanel", WMTitledWindowMask);
	}

	WMSetWindowInitialPosition(panel->win,
				   (scrPtr->rootView->size.width - WMWidgetWidth(panel->win)) / 2,
				   (scrPtr->rootView->size.height - WMWidgetHeight(panel->win)) / 2);

	WMSetWindowTitle(panel->win, "");

	panel->vbox = WMCreateBox(panel->win);
	WMSetViewExpandsToParent(WMWidgetView(panel->vbox), 0, 0, 0, 0);
	WMSetBoxHorizontal(panel->vbox, False);
	WMMapWidget(panel->vbox);

	hbox = WMCreateBox(panel->vbox);
	WMSetBoxBorderWidth(hbox, 5);
	WMSetBoxHorizontal(hbox, True);
	WMMapWidget(hbox);
	WMAddBoxSubview(panel->vbox, WMWidgetView(hbox), False, True, 74, 0, 5);

	panel->iLbl = WMCreateLabel(hbox);
	WMSetLabelImagePosition(panel->iLbl, WIPImageOnly);
	WMMapWidget(panel->iLbl);
	WMAddBoxSubview(hbox, WMWidgetView(panel->iLbl), False, True, 64, 0, 10);
	icon = WMCreateApplicationIconBlendedPixmap(scrPtr, (RColor *) NULL);
	if (icon) {
		WMSetLabelImage(panel->iLbl, icon);
		WMReleasePixmap(icon);
	} else {
		WMSetLabelImage(panel->iLbl, scrPtr->applicationIconPixmap);
	}

	if (title) {
		WMFont *largeFont;

		largeFont = WMBoldSystemFontOfSize(scrPtr, 24);

		panel->tLbl = WMCreateLabel(hbox);
		WMMapWidget(panel->tLbl);
		WMAddBoxSubview(hbox, WMWidgetView(panel->tLbl), True, True, 64, 0, 0);
		WMSetLabelText(panel->tLbl, title);
		WMSetLabelTextAlignment(panel->tLbl, WALeft);
		WMSetLabelFont(panel->tLbl, largeFont);

		WMReleaseFont(largeFont);
	}

	/* create divider line */

	panel->line = WMCreateFrame(panel->vbox);
	WMMapWidget(panel->line);
	WMAddBoxSubview(panel->vbox, WMWidgetView(panel->line), False, True, 2, 2, 5);
	WMSetFrameRelief(panel->line, WRGroove);

	panel->content = WMCreateFrame(panel->vbox);
	WMMapWidget(panel->content);
	WMAddBoxSubview(panel->vbox, WMWidgetView(panel->content), True, True, 50, 0, 5);
	WMSetFrameRelief(panel->content, WRFlat);

	hbox = WMCreateBox(panel->vbox);
	WMSetBoxBorderWidth(hbox, 10);
	WMSetBoxHorizontal(hbox, True);
	WMMapWidget(hbox);
	WMAddBoxSubview(panel->vbox, WMWidgetView(hbox), False, True, 44, 0, 0);

	/* create buttons */
	if (defaultButton)
		dw = WMWidthOfString(scrPtr->normalFont, defaultButton, strlen(defaultButton));

	if (alternateButton)
		aw = WMWidthOfString(scrPtr->normalFont, alternateButton, strlen(alternateButton));

	dw = dw + (scrPtr->buttonArrow ? scrPtr->buttonArrow->width : 0);

	aw += 30;
	dw += 30;

	w = WMAX(dw, aw);
	if ((w + 10) * 2 < 400) {
		dw = w;
	} else {
		int t;

		t = 400 - 40 - aw - dw;
		dw += t / 2;
	}

	if (defaultButton) {
		panel->defBtn = WMCreateCommandButton(hbox);
		WMSetButtonAction(panel->defBtn, alertPanelOnClick, panel);
		WMAddBoxSubviewAtEnd(hbox, WMWidgetView(panel->defBtn), False, True, dw, 0, 0);
		WMSetButtonText(panel->defBtn, defaultButton);
		WMSetButtonImage(panel->defBtn, scrPtr->buttonArrow);
		WMSetButtonAltImage(panel->defBtn, scrPtr->pushedButtonArrow);
		WMSetButtonImagePosition(panel->defBtn, WIPRight);
	}

	WMMapSubwidgets(hbox);

	WMCreateEventHandler(W_VIEW(panel->win), KeyPressMask, handleKeyPress3, panel);

	WMRealizeWidget(panel->win);
	WMMapSubwidgets(panel->win);

	return panel;
}
