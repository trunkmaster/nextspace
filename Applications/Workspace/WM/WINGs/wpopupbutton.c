
#include "WINGsP.h"

typedef struct W_PopUpButton {
	W_Class widgetClass;
	WMView *view;

	void *clientData;
	WMAction *action;

	char *caption;

	WMArray *items;

	short selectedItemIndex;

	short highlightedItem;

	WMView *menuView;	/* override redirect popup menu */

	WMHandlerID timer;	/* for autoscroll */

	 /**/ int scrollStartY;	/* for autoscroll */

	struct {
		unsigned int pullsDown:1;

		unsigned int configured:1;

		unsigned int insideMenu:1;

		unsigned int enabled:1;

	} flags;
} PopUpButton;

#define MENU_BLINK_DELAY	60000
#define MENU_BLINK_COUNT	2

#define SCROLL_DELAY		10

#define DEFAULT_WIDTH	60
#define DEFAULT_HEIGHT 	20
#define DEFAULT_CAPTION	""

static void destroyPopUpButton(PopUpButton * bPtr);
static void paintPopUpButton(PopUpButton * bPtr);

static void handleEvents(XEvent * event, void *data);
static void handleActionEvents(XEvent * event, void *data);

static void resizeMenu(PopUpButton * bPtr);

WMPopUpButton *WMCreatePopUpButton(WMWidget * parent)
{
	PopUpButton *bPtr;
	W_Screen *scr = W_VIEW(parent)->screen;

	bPtr = wmalloc(sizeof(PopUpButton));

	bPtr->widgetClass = WC_PopUpButton;

	bPtr->view = W_CreateView(W_VIEW(parent));
	if (!bPtr->view) {
		wfree(bPtr);
		return NULL;
	}
	bPtr->view->self = bPtr;

	WMCreateEventHandler(bPtr->view, ExposureMask | StructureNotifyMask
			     | ClientMessageMask, handleEvents, bPtr);

	W_ResizeView(bPtr->view, DEFAULT_WIDTH, DEFAULT_HEIGHT);
	bPtr->caption = wstrdup(DEFAULT_CAPTION);

	WMCreateEventHandler(bPtr->view, ButtonPressMask | ButtonReleaseMask, handleActionEvents, bPtr);

	bPtr->flags.enabled = 1;

	bPtr->items = WMCreateArrayWithDestructor(4, (WMFreeDataProc *) WMDestroyMenuItem);

	bPtr->selectedItemIndex = -1;

	bPtr->menuView = W_CreateUnmanagedTopView(scr);

	W_ResizeView(bPtr->menuView, bPtr->view->size.width, 1);

	WMCreateEventHandler(bPtr->menuView, ButtonPressMask | ButtonReleaseMask
			     | EnterWindowMask | LeaveWindowMask | ButtonMotionMask
			     | ExposureMask, handleActionEvents, bPtr);

	return bPtr;
}

void WMSetPopUpButtonAction(WMPopUpButton * bPtr, WMAction * action, void *clientData)
{
	CHECK_CLASS(bPtr, WC_PopUpButton);

	bPtr->action = action;

	bPtr->clientData = clientData;
}

WMMenuItem *WMAddPopUpButtonItem(WMPopUpButton * bPtr, const char *title)
{
	WMMenuItem *item;

	CHECK_CLASS(bPtr, WC_PopUpButton);

	item = WMCreateMenuItem();
	WMSetMenuItemTitle(item, title);

	WMAddToArray(bPtr->items, item);

	if (bPtr->menuView && bPtr->menuView->flags.realized)
		resizeMenu(bPtr);

	return item;
}

WMMenuItem *WMInsertPopUpButtonItem(WMPopUpButton * bPtr, int index, const char *title)
{
	WMMenuItem *item;

	CHECK_CLASS(bPtr, WC_PopUpButton);

	item = WMCreateMenuItem();
	WMSetMenuItemTitle(item, title);

	WMInsertInArray(bPtr->items, index, item);

	/* if there is an selected item, update it's index to match the new
	 * position */
	if (index < bPtr->selectedItemIndex)
		bPtr->selectedItemIndex++;

	if (bPtr->menuView && bPtr->menuView->flags.realized)
		resizeMenu(bPtr);

	return item;
}

void WMRemovePopUpButtonItem(WMPopUpButton * bPtr, int index)
{
	CHECK_CLASS(bPtr, WC_PopUpButton);

	wassertr(index >= 0 && index < WMGetArrayItemCount(bPtr->items));

	WMDeleteFromArray(bPtr->items, index);

	if (bPtr->selectedItemIndex >= 0 && !bPtr->flags.pullsDown) {
		if (index < bPtr->selectedItemIndex)
			bPtr->selectedItemIndex--;
		else if (index == bPtr->selectedItemIndex) {
			/* reselect first item if the removed item is the
			 * selected one */
			bPtr->selectedItemIndex = 0;
			if (bPtr->view->flags.mapped)
				paintPopUpButton(bPtr);
		}
	}

	if (bPtr->menuView && bPtr->menuView->flags.realized)
		resizeMenu(bPtr);
}

void WMSetPopUpButtonEnabled(WMPopUpButton * bPtr, Bool flag)
{
	bPtr->flags.enabled = ((flag == 0) ? 0 : 1);
	if (bPtr->view->flags.mapped)
		paintPopUpButton(bPtr);
}

Bool WMGetPopUpButtonEnabled(WMPopUpButton * bPtr)
{
	return bPtr->flags.enabled;
}

void WMSetPopUpButtonSelectedItem(WMPopUpButton * bPtr, int index)
{

	wassertr(index < WMGetArrayItemCount(bPtr->items));

	/* if (index >= WMGetArrayCount(bPtr->items))
	   index = -1; */

	bPtr->selectedItemIndex = index;

	if (bPtr->view->flags.mapped)
		paintPopUpButton(bPtr);
}

int WMGetPopUpButtonSelectedItem(WMPopUpButton * bPtr)
{
	if (!bPtr->flags.pullsDown && bPtr->selectedItemIndex < 0)
		return -1;
	else
		return bPtr->selectedItemIndex;
}

void WMSetPopUpButtonText(WMPopUpButton * bPtr, const char *text)
{
	if (bPtr->caption)
		wfree(bPtr->caption);
	if (text)
		bPtr->caption = wstrdup(text);
	else
		bPtr->caption = NULL;
	if (bPtr->view->flags.realized) {
		if (bPtr->flags.pullsDown || bPtr->selectedItemIndex < 0) {
			paintPopUpButton(bPtr);
		}
	}
}

void WMSetPopUpButtonItemEnabled(WMPopUpButton * bPtr, int index, Bool flag)
{
	WMSetMenuItemEnabled(WMGetFromArray(bPtr->items, index), (flag ? 1 : 0));
}

Bool WMGetPopUpButtonItemEnabled(WMPopUpButton * bPtr, int index)
{
	return WMGetMenuItemEnabled(WMGetFromArray(bPtr->items, index));
}

void WMSetPopUpButtonPullsDown(WMPopUpButton * bPtr, Bool flag)
{
	bPtr->flags.pullsDown = ((flag == 0) ? 0 : 1);
	if (flag) {
		bPtr->selectedItemIndex = -1;
	}

	if (bPtr->view->flags.mapped)
		paintPopUpButton(bPtr);
}

int WMGetPopUpButtonNumberOfItems(WMPopUpButton * bPtr)
{
	return WMGetArrayItemCount(bPtr->items);
}

char *WMGetPopUpButtonItem(WMPopUpButton * bPtr, int index)
{
	if (index >= WMGetArrayItemCount(bPtr->items) || index < 0)
		return NULL;

	return WMGetMenuItemTitle(WMGetFromArray(bPtr->items, index));
}

WMMenuItem *WMGetPopUpButtonMenuItem(WMPopUpButton * bPtr, int index)
{
	return WMGetFromArray(bPtr->items, index);
}

static void paintPopUpButton(PopUpButton * bPtr)
{
	W_Screen *scr = bPtr->view->screen;
	char *caption;
	Pixmap pixmap;

	if (bPtr->flags.pullsDown) {
		caption = bPtr->caption;
	} else {
		if (bPtr->selectedItemIndex < 0) {
			/* if no item selected, show the caption */
			caption = bPtr->caption;
		} else {
			caption = WMGetPopUpButtonItem(bPtr, bPtr->selectedItemIndex);
		}
	}

	pixmap = XCreatePixmap(scr->display, bPtr->view->window,
			       bPtr->view->size.width, bPtr->view->size.height, scr->depth);
	XFillRectangle(scr->display, pixmap, WMColorGC(scr->gray), 0, 0,
		       bPtr->view->size.width, bPtr->view->size.height);

	W_DrawRelief(scr, pixmap, 0, 0, bPtr->view->size.width, bPtr->view->size.height, WRRaised);

	if (caption) {
		W_PaintText(bPtr->view, pixmap, scr->normalFont, 6,
			    (bPtr->view->size.height - WMFontHeight(scr->normalFont)) / 2,
			    bPtr->view->size.width, WALeft,
			    bPtr->flags.enabled ? scr->black : scr->darkGray, False, caption, strlen(caption));
	}

	if (bPtr->flags.pullsDown) {
		XCopyArea(scr->display, scr->pullDownIndicator->pixmap,
			  pixmap, scr->copyGC, 0, 0, scr->pullDownIndicator->width,
			  scr->pullDownIndicator->height,
			  bPtr->view->size.width - scr->pullDownIndicator->width - 4,
			  (bPtr->view->size.height - scr->pullDownIndicator->height) / 2);
	} else {
		int x, y;

		x = bPtr->view->size.width - scr->popUpIndicator->width - 4;
		y = (bPtr->view->size.height - scr->popUpIndicator->height) / 2;

		XSetClipOrigin(scr->display, scr->clipGC, x, y);
		XSetClipMask(scr->display, scr->clipGC, scr->popUpIndicator->mask);
		XCopyArea(scr->display, scr->popUpIndicator->pixmap, pixmap,
			  scr->clipGC, 0, 0, scr->popUpIndicator->width, scr->popUpIndicator->height, x, y);
	}

	XCopyArea(scr->display, pixmap, bPtr->view->window, scr->copyGC, 0, 0,
		  bPtr->view->size.width, bPtr->view->size.height, 0, 0);

	XFreePixmap(scr->display, pixmap);
}

static void handleEvents(XEvent * event, void *data)
{
	PopUpButton *bPtr = (PopUpButton *) data;

	CHECK_CLASS(data, WC_PopUpButton);

	switch (event->type) {
	case Expose:
		if (event->xexpose.count != 0)
			break;
		paintPopUpButton(bPtr);
		break;

	case DestroyNotify:
		destroyPopUpButton(bPtr);
		break;
	}
}

static void paintMenuEntry(PopUpButton * bPtr, int index, int highlight)
{
	W_Screen *scr = bPtr->view->screen;
	int yo;
	int width, itemHeight, itemCount;
	char *title;

	itemCount = WMGetArrayItemCount(bPtr->items);
	if (index < 0 || index >= itemCount)
		return;

	itemHeight = bPtr->view->size.height;
	width = bPtr->view->size.width;
	yo = (itemHeight - WMFontHeight(scr->normalFont)) / 2;

	if (!highlight) {
		XClearArea(scr->display, bPtr->menuView->window, 0, index * itemHeight, width, itemHeight, False);
		return;
	}

	XFillRectangle(scr->display, bPtr->menuView->window, WMColorGC(scr->white),
		       1, index * itemHeight + 1, width - 3, itemHeight - 3);

	title = WMGetPopUpButtonItem(bPtr, index);

	W_DrawRelief(scr, bPtr->menuView->window, 0, index * itemHeight, width, itemHeight, WRRaised);

	W_PaintText(bPtr->menuView, bPtr->menuView->window, scr->normalFont, 6,
		    index * itemHeight + yo, width, WALeft, scr->black, False, title, strlen(title));

	if (!bPtr->flags.pullsDown && index == bPtr->selectedItemIndex) {
		XCopyArea(scr->display, scr->popUpIndicator->pixmap,
			  bPtr->menuView->window, scr->copyGC, 0, 0,
			  scr->popUpIndicator->width, scr->popUpIndicator->height,
			  width - scr->popUpIndicator->width - 4,
			  index * itemHeight + (itemHeight - scr->popUpIndicator->height) / 2);
	}
}

static Pixmap makeMenuPixmap(PopUpButton * bPtr)
{
	Pixmap pixmap;
	W_Screen *scr = bPtr->view->screen;
	WMMenuItem *item;
	WMArrayIterator iter;
	int yo, i;
	int width, height, itemHeight;

	itemHeight = bPtr->view->size.height;
	width = bPtr->view->size.width;
	height = itemHeight * WMGetArrayItemCount(bPtr->items);
	yo = (itemHeight - WMFontHeight(scr->normalFont)) / 2;

	pixmap = XCreatePixmap(scr->display, bPtr->view->window, width, height, scr->depth);

	XFillRectangle(scr->display, pixmap, WMColorGC(scr->gray), 0, 0, width, height);

	i = 0;
	WM_ITERATE_ARRAY(bPtr->items, item, iter) {
		WMColor *color;
		char *text;

		text = WMGetMenuItemTitle(item);

		W_DrawRelief(scr, pixmap, 0, i * itemHeight, width, itemHeight, WRRaised);

		if (!WMGetMenuItemEnabled(item))
			color = scr->darkGray;
		else
			color = scr->black;

		W_PaintText(bPtr->menuView, pixmap, scr->normalFont, 6,
			    i * itemHeight + yo, width, WALeft, color, False, text, strlen(text));

		if (!bPtr->flags.pullsDown && i == bPtr->selectedItemIndex) {
			XCopyArea(scr->display, scr->popUpIndicator->pixmap, pixmap,
				  scr->copyGC, 0, 0, scr->popUpIndicator->width,
				  scr->popUpIndicator->height,
				  width - scr->popUpIndicator->width - 4,
				  i * itemHeight + (itemHeight - scr->popUpIndicator->height) / 2);
		}

		i++;
	}

	return pixmap;
}

static void resizeMenu(PopUpButton * bPtr)
{
	int height;

	height = WMGetArrayItemCount(bPtr->items) * bPtr->view->size.height;
	if (height > 0)
		W_ResizeView(bPtr->menuView, bPtr->view->size.width, height);
}

static void popUpMenu(PopUpButton * bPtr)
{
	W_Screen *scr = bPtr->view->screen;
	Window dummyW;
	int x, y;

	if (!bPtr->flags.enabled)
		return;

	if (!bPtr->menuView->flags.realized) {
		W_RealizeView(bPtr->menuView);
		resizeMenu(bPtr);
	}

	if (WMGetArrayItemCount(bPtr->items) < 1)
		return;

	XTranslateCoordinates(scr->display, bPtr->view->window, scr->rootWin, 0, 0, &x, &y, &dummyW);

	if (bPtr->flags.pullsDown) {
		y += bPtr->view->size.height;
	} else {
		y -= bPtr->view->size.height * bPtr->selectedItemIndex;
	}
	W_MoveView(bPtr->menuView, x, y);

	XSetWindowBackgroundPixmap(scr->display, bPtr->menuView->window, makeMenuPixmap(bPtr));
	XClearWindow(scr->display, bPtr->menuView->window);

	if (W_VIEW_WIDTH(bPtr->menuView) != W_VIEW_WIDTH(bPtr->view))
		resizeMenu(bPtr);

	W_MapView(bPtr->menuView);

	bPtr->highlightedItem = 0;
	if (!bPtr->flags.pullsDown && bPtr->selectedItemIndex < 0)
		paintMenuEntry(bPtr, bPtr->selectedItemIndex, True);
}

static void popDownMenu(PopUpButton * bPtr)
{
	W_UnmapView(bPtr->menuView);
}

static void autoScroll(void *data)
{
	PopUpButton *bPtr = (PopUpButton *) data;
	int scrHeight = WMWidgetScreen(bPtr)->rootView->size.height;
	int repeat = 0;
	int dy = 0;

	if (bPtr->scrollStartY >= scrHeight - 1
	    && bPtr->menuView->pos.y + bPtr->menuView->size.height >= scrHeight - 1) {
		repeat = 1;

		if (bPtr->menuView->pos.y + bPtr->menuView->size.height - 5 <= scrHeight - 1) {
			dy = scrHeight - 1 - (bPtr->menuView->pos.y + bPtr->menuView->size.height);
		} else
			dy = -5;

	} else if (bPtr->scrollStartY <= 1 && bPtr->menuView->pos.y < 1) {
		repeat = 1;

		if (bPtr->menuView->pos.y + 5 > 1)
			dy = 1 - bPtr->menuView->pos.y;
		else
			dy = 5;
	}

	if (repeat) {
		int oldItem;

		W_MoveView(bPtr->menuView, bPtr->menuView->pos.x, bPtr->menuView->pos.y + dy);

		oldItem = bPtr->highlightedItem;
		bPtr->highlightedItem = (bPtr->scrollStartY - bPtr->menuView->pos.y)
		    / bPtr->view->size.height;

		if (oldItem != bPtr->highlightedItem) {
			WMMenuItem *item;

			paintMenuEntry(bPtr, oldItem, False);

			if (bPtr->highlightedItem >= 0 && bPtr->highlightedItem < WMGetArrayItemCount(bPtr->items)) {
				item = WMGetPopUpButtonMenuItem(bPtr, bPtr->highlightedItem);
				paintMenuEntry(bPtr, bPtr->highlightedItem, WMGetMenuItemEnabled(item));
			} else {
				bPtr->highlightedItem = -1;
			}
		}

		bPtr->timer = WMAddTimerHandler(SCROLL_DELAY, autoScroll, bPtr);
	} else {
		bPtr->timer = NULL;
	}
}

static void wheelScrollUp(PopUpButton * bPtr)
{
	int testIndex = bPtr->selectedItemIndex - 1;

	while (testIndex >= 0 && !WMGetPopUpButtonItemEnabled(bPtr, testIndex))
		testIndex--;
	if (testIndex != -1) {
		WMSetPopUpButtonSelectedItem(bPtr, testIndex);
		if (bPtr->action)
			(*bPtr->action) (bPtr, bPtr->clientData);
	}
}

static void wheelScrollDown(PopUpButton * bPtr)
{
	int itemCount = WMGetArrayItemCount(bPtr->items);
	int testIndex = bPtr->selectedItemIndex + 1;

	while (testIndex < itemCount && !WMGetPopUpButtonItemEnabled(bPtr, testIndex))
		testIndex++;
	if (testIndex != itemCount) {
		WMSetPopUpButtonSelectedItem(bPtr, testIndex);
		if (bPtr->action)
			(*bPtr->action) (bPtr, bPtr->clientData);
	}
}

static void handleActionEvents(XEvent * event, void *data)
{
	PopUpButton *bPtr = (PopUpButton *) data;
	int oldItem;
	int scrHeight = WMWidgetScreen(bPtr)->rootView->size.height;

	CHECK_CLASS(data, WC_PopUpButton);

	if (WMGetArrayItemCount(bPtr->items) < 1)
		return;

	switch (event->type) {
		/* called for menuView */
	case Expose:
		paintMenuEntry(bPtr, bPtr->highlightedItem, True);
		break;

	case LeaveNotify:
		bPtr->flags.insideMenu = 0;
		if (bPtr->menuView->flags.mapped)
			paintMenuEntry(bPtr, bPtr->highlightedItem, False);
		bPtr->highlightedItem = -1;
		break;

	case EnterNotify:
		bPtr->flags.insideMenu = 1;
		break;

	case MotionNotify:
		if (bPtr->flags.insideMenu) {
			oldItem = bPtr->highlightedItem;
			bPtr->highlightedItem = event->xmotion.y / bPtr->view->size.height;
			if (oldItem != bPtr->highlightedItem) {
				WMMenuItem *item;

				paintMenuEntry(bPtr, oldItem, False);
				if (bPtr->highlightedItem >= 0 &&
				    bPtr->highlightedItem < WMGetArrayItemCount(bPtr->items)) {
					item = WMGetPopUpButtonMenuItem(bPtr, bPtr->highlightedItem);
					paintMenuEntry(bPtr, bPtr->highlightedItem, WMGetMenuItemEnabled(item));
				} else {
					bPtr->highlightedItem = -1;
				}

			}

			if (event->xmotion.y_root >= scrHeight - 1 || event->xmotion.y_root <= 1) {
				bPtr->scrollStartY = event->xmotion.y_root;
				if (!bPtr->timer)
					autoScroll(bPtr);
			} else if (bPtr->timer) {
				WMDeleteTimerHandler(bPtr->timer);
				bPtr->timer = NULL;
			}
		}
		break;

		/* called for bPtr->view */
	case ButtonPress:
		if (!bPtr->flags.enabled)
			break;

		if (event->xbutton.button == WINGsConfiguration.mouseWheelUp) {
			if (!bPtr->menuView->flags.mapped && !bPtr->flags.pullsDown) {
				wheelScrollUp(bPtr);
			}
			break;
		} else if (event->xbutton.button == WINGsConfiguration.mouseWheelDown) {
			if (!bPtr->menuView->flags.mapped && !bPtr->flags.pullsDown) {
				wheelScrollDown(bPtr);
			}
			break;
		}
		popUpMenu(bPtr);
		if (!bPtr->flags.pullsDown) {
			bPtr->highlightedItem = bPtr->selectedItemIndex;
			bPtr->flags.insideMenu = 1;
		} else {
			bPtr->highlightedItem = -1;
			bPtr->flags.insideMenu = 0;
		}
		XGrabPointer(bPtr->view->screen->display, bPtr->menuView->window,
			     False, ButtonReleaseMask | ButtonMotionMask | EnterWindowMask
			     | LeaveWindowMask, GrabModeAsync, GrabModeAsync, None, None, CurrentTime);
		break;

	case ButtonRelease:
		if (event->xbutton.button == WINGsConfiguration.mouseWheelUp ||
		    event->xbutton.button == WINGsConfiguration.mouseWheelDown) {
			break;
		}
		XUngrabPointer(bPtr->view->screen->display, event->xbutton.time);
		if (!bPtr->flags.pullsDown)
			popDownMenu(bPtr);

		if (bPtr->timer) {
			WMDeleteTimerHandler(bPtr->timer);
			bPtr->timer = NULL;
		}

		if (bPtr->flags.insideMenu && bPtr->highlightedItem >= 0) {
			WMMenuItem *item;

			item = WMGetPopUpButtonMenuItem(bPtr, bPtr->highlightedItem);

			if (WMGetMenuItemEnabled(item)) {
				int i;
				WMSetPopUpButtonSelectedItem(bPtr, bPtr->highlightedItem);

				if (bPtr->flags.pullsDown) {
					for (i = 0; i < MENU_BLINK_COUNT; i++) {
						paintMenuEntry(bPtr, bPtr->highlightedItem, False);
						XSync(bPtr->view->screen->display, 0);
						wusleep(MENU_BLINK_DELAY);
						paintMenuEntry(bPtr, bPtr->highlightedItem, True);
						XSync(bPtr->view->screen->display, 0);
						wusleep(MENU_BLINK_DELAY);
					}
				}
				paintMenuEntry(bPtr, bPtr->highlightedItem, False);
				popDownMenu(bPtr);
				if (bPtr->action)
					(*bPtr->action) (bPtr, bPtr->clientData);
			}
		}
		if (bPtr->menuView->flags.mapped)
			popDownMenu(bPtr);
		break;
	}
}

static void destroyPopUpButton(PopUpButton * bPtr)
{
	if (bPtr->timer) {
		WMDeleteTimerHandler(bPtr->timer);
	}

	WMFreeArray(bPtr->items);

	if (bPtr->caption)
		wfree(bPtr->caption);

	/* have to destroy explicitly because the popup is a toplevel */
	W_DestroyView(bPtr->menuView);

	wfree(bPtr);
}
