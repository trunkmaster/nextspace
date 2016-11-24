
#include "WINGsP.h"

typedef struct W_Button {
	W_Class widgetClass;
	WMView *view;

	char *caption;

	char *altCaption;

	WMFont *font;

	WMColor *textColor;
	WMColor *altTextColor;
	WMColor *disTextColor;

	W_Pixmap *image;
	W_Pixmap *altImage;
	W_Pixmap *tsImage;

	W_Pixmap *dimage;

	void *clientData;
	WMAction *action;

	int tag;

	int groupIndex;

	float periodicDelay;
	float periodicInterval;

	WMHandlerID *timer;	/* for continuous mode */

	struct {
		WMButtonType type:4;
		WMImagePosition imagePosition:4;
		WMAlignment alignment:2;

		unsigned int selected:2;

		unsigned int enabled:1;

		unsigned int dimsWhenDisabled:1;

		unsigned int bordered:1;

		unsigned int springLoaded:1;

		unsigned int pushIn:1;	/* change relief while pushed */

		unsigned int pushLight:1;	/* highlight while pushed */

		unsigned int pushChange:1;	/* change caption while pushed */

		unsigned int stateLight:1;	/* state indicated by highlight */

		unsigned int stateChange:1;	/* state indicated by caption change */

		unsigned int statePush:1;	/* state indicated by relief */

		unsigned int continuous:1;	/* continually perform action */

		unsigned int prevSelected:1;

		unsigned int pushed:1;

		unsigned int wasPushed:1;

		unsigned int redrawPending:1;

		unsigned int addedObserver:1;
	} flags;
} Button;

#define DEFAULT_BUTTON_WIDTH	60
#define DEFAULT_BUTTON_HEIGHT	24
#define DEFAULT_BUTTON_ALIGNMENT	WACenter
#define DEFAULT_BUTTON_IS_BORDERED	True

#define DEFAULT_RADIO_WIDTH	100
#define DEFAULT_RADIO_HEIGHT	20
#define DEFAULT_RADIO_ALIGNMENT	WALeft
#define DEFAULT_RADIO_IMAGE_POSITION	WIPLeft
#define DEFAULT_RADIO_TEXT	"Radio"

#define DEFAULT_SWITCH_WIDTH	100
#define DEFAULT_SWITCH_HEIGHT	20
#define DEFAULT_SWITCH_ALIGNMENT	WALeft
#define DEFAULT_SWITCH_IMAGE_POSITION	WIPLeft
#define DEFAULT_SWITCH_TEXT	"Switch"

static void destroyButton(Button * bPtr);
static void paintButton(Button * bPtr);

static void handleEvents(XEvent * event, void *data);
static void handleActionEvents(XEvent * event, void *data);

static char *WMPushedRadioNotification = "WMPushedRadioNotification";


WMButton *WMCreateCustomButton(WMWidget * parent, int behaviourMask)
{
	Button *bPtr;

	bPtr = wmalloc(sizeof(Button));

	bPtr->widgetClass = WC_Button;

	bPtr->view = W_CreateView(W_VIEW(parent));
	if (!bPtr->view) {
		wfree(bPtr);
		return NULL;
	}
	bPtr->view->self = bPtr;

	bPtr->flags.type = 0;

	bPtr->flags.springLoaded = (behaviourMask & WBBSpringLoadedMask) != 0;
	bPtr->flags.pushIn = (behaviourMask & WBBPushInMask) != 0;
	bPtr->flags.pushChange = (behaviourMask & WBBPushChangeMask) != 0;
	bPtr->flags.pushLight = (behaviourMask & WBBPushLightMask) != 0;
	bPtr->flags.stateLight = (behaviourMask & WBBStateLightMask) != 0;
	bPtr->flags.stateChange = (behaviourMask & WBBStateChangeMask) != 0;
	bPtr->flags.statePush = (behaviourMask & WBBStatePushMask) != 0;

	W_ResizeView(bPtr->view, DEFAULT_BUTTON_WIDTH, DEFAULT_BUTTON_HEIGHT);
	bPtr->flags.alignment = DEFAULT_BUTTON_ALIGNMENT;
	bPtr->flags.bordered = DEFAULT_BUTTON_IS_BORDERED;

	bPtr->flags.enabled = 1;
	bPtr->flags.dimsWhenDisabled = 1;

	WMCreateEventHandler(bPtr->view, ExposureMask | StructureNotifyMask, handleEvents, bPtr);

	WMCreateEventHandler(bPtr->view, ButtonPressMask | ButtonReleaseMask
			     | EnterWindowMask | LeaveWindowMask, handleActionEvents, bPtr);

	W_ResizeView(bPtr->view, DEFAULT_BUTTON_WIDTH, DEFAULT_BUTTON_HEIGHT);
	bPtr->flags.alignment = DEFAULT_BUTTON_ALIGNMENT;
	bPtr->flags.bordered = DEFAULT_BUTTON_IS_BORDERED;

	return bPtr;
}

WMButton *WMCreateButton(WMWidget * parent, WMButtonType type)
{
	W_Screen *scrPtr = W_VIEW(parent)->screen;
	Button *bPtr;

	switch (type) {
	case WBTMomentaryPush:
		bPtr = WMCreateCustomButton(parent, WBBSpringLoadedMask | WBBPushInMask | WBBPushLightMask);
		break;

	case WBTMomentaryChange:
		bPtr = WMCreateCustomButton(parent, WBBSpringLoadedMask | WBBPushChangeMask);
		break;

	case WBTPushOnPushOff:
		bPtr = WMCreateCustomButton(parent, WBBPushInMask | WBBStatePushMask | WBBStateLightMask);
		break;

	case WBTToggle:
		bPtr = WMCreateCustomButton(parent, WBBPushInMask | WBBStateChangeMask | WBBStatePushMask);
		break;

	case WBTOnOff:
		bPtr = WMCreateCustomButton(parent, WBBStateLightMask);
		break;

	case WBTSwitch:
		bPtr = WMCreateCustomButton(parent, WBBStateChangeMask);
		bPtr->flags.bordered = 0;
		bPtr->image = WMRetainPixmap(scrPtr->checkButtonImageOff);
		bPtr->altImage = WMRetainPixmap(scrPtr->checkButtonImageOn);
		break;

	case WBTRadio:
		bPtr = WMCreateCustomButton(parent, WBBStateChangeMask);
		bPtr->flags.bordered = 0;
		bPtr->image = WMRetainPixmap(scrPtr->radioButtonImageOff);
		bPtr->altImage = WMRetainPixmap(scrPtr->radioButtonImageOn);
		break;

	case WBTTriState:
		bPtr = WMCreateCustomButton(parent, WBBStateChangeMask);
		bPtr->flags.bordered = 0;
		bPtr->image = WMRetainPixmap(scrPtr->tristateButtonImageOff);
		bPtr->altImage = WMRetainPixmap(scrPtr->tristateButtonImageOn);
		bPtr->tsImage = WMRetainPixmap(scrPtr->tristateButtonImageTri);
		break;

	default:
	case WBTMomentaryLight:
		bPtr = WMCreateCustomButton(parent, WBBSpringLoadedMask | WBBPushLightMask);
		bPtr->flags.bordered = 1;
		break;
	}

	bPtr->flags.type = type;

	if (type == WBTRadio) {
		W_ResizeView(bPtr->view, DEFAULT_RADIO_WIDTH, DEFAULT_RADIO_HEIGHT);
		WMSetButtonText(bPtr, DEFAULT_RADIO_TEXT);
		bPtr->flags.alignment = DEFAULT_RADIO_ALIGNMENT;
		bPtr->flags.imagePosition = DEFAULT_RADIO_IMAGE_POSITION;
	} else if (type == WBTSwitch || type == WBTTriState) {
		W_ResizeView(bPtr->view, DEFAULT_SWITCH_WIDTH, DEFAULT_SWITCH_HEIGHT);
		WMSetButtonText(bPtr, DEFAULT_SWITCH_TEXT);
		bPtr->flags.alignment = DEFAULT_SWITCH_ALIGNMENT;
		bPtr->flags.imagePosition = DEFAULT_SWITCH_IMAGE_POSITION;
	}

	return bPtr;
}

static void updateDisabledMask(WMButton * bPtr)
{
	WMScreen *scr = WMWidgetScreen(bPtr);
	Display *dpy = scr->display;

	if (bPtr->image) {
		XGCValues gcv;

		if (bPtr->dimage->mask) {
			XFreePixmap(dpy, bPtr->dimage->mask);
			bPtr->dimage->mask = None;
		}

		if (bPtr->flags.dimsWhenDisabled) {
			bPtr->dimage->mask = XCreatePixmap(dpy, scr->stipple,
							   bPtr->dimage->width, bPtr->dimage->height, 1);

			XSetForeground(dpy, scr->monoGC, 0);
			XFillRectangle(dpy, bPtr->dimage->mask, scr->monoGC, 0, 0,
				       bPtr->dimage->width, bPtr->dimage->height);

			gcv.foreground = 1;
			gcv.background = 0;
			gcv.stipple = scr->stipple;
			gcv.fill_style = FillStippled;
			gcv.clip_mask = bPtr->image->mask;
			gcv.clip_x_origin = 0;
			gcv.clip_y_origin = 0;

			XChangeGC(dpy, scr->monoGC, GCForeground | GCBackground | GCStipple
				  | GCFillStyle | GCClipMask | GCClipXOrigin | GCClipYOrigin, &gcv);

			XFillRectangle(dpy, bPtr->dimage->mask, scr->monoGC, 0, 0,
				       bPtr->dimage->width, bPtr->dimage->height);

			gcv.fill_style = FillSolid;
			gcv.clip_mask = None;
			XChangeGC(dpy, scr->monoGC, GCFillStyle | GCClipMask, &gcv);
		}
	}
}

void WMSetButtonImageDefault(WMButton * bPtr)
{
	WMSetButtonImage(bPtr, WMWidgetScreen(bPtr)->buttonArrow);
	WMSetButtonAltImage(bPtr, WMWidgetScreen(bPtr)->pushedButtonArrow);
}

void WMSetButtonImage(WMButton * bPtr, WMPixmap * image)
{
	if (bPtr->image != NULL)
		WMReleasePixmap(bPtr->image);
	bPtr->image = WMRetainPixmap(image);

	if (bPtr->dimage) {
		bPtr->dimage->pixmap = None;
		WMReleasePixmap(bPtr->dimage);
		bPtr->dimage = NULL;
	}

	if (image) {
		bPtr->dimage = WMCreatePixmapFromXPixmaps(WMWidgetScreen(bPtr),
							  image->pixmap, None,
							  image->width, image->height, image->depth);
		updateDisabledMask(bPtr);
	}

	if (bPtr->view->flags.realized) {
		paintButton(bPtr);
	}
}

void WMSetButtonAltImage(WMButton * bPtr, WMPixmap * image)
{
	if (bPtr->altImage != NULL)
		WMReleasePixmap(bPtr->altImage);
	bPtr->altImage = WMRetainPixmap(image);

	if (bPtr->view->flags.realized) {
		paintButton(bPtr);
	}
}

void WMSetButtonImagePosition(WMButton * bPtr, WMImagePosition position)
{
	bPtr->flags.imagePosition = position;

	if (bPtr->view->flags.realized) {
		paintButton(bPtr);
	}
}

void WMSetButtonTextAlignment(WMButton * bPtr, WMAlignment alignment)
{
	bPtr->flags.alignment = alignment;

	if (bPtr->view->flags.realized) {
		paintButton(bPtr);
	}
}

void WMSetButtonText(WMButton * bPtr, const char *text)
{
	if (bPtr->caption)
		wfree(bPtr->caption);

	if (text != NULL) {
		bPtr->caption = wstrdup(text);
	} else {
		bPtr->caption = NULL;
	}

	if (bPtr->view->flags.realized) {
		paintButton(bPtr);
	}
}

const char *WMGetButtonText(WMButton *bPtr)
{
	return bPtr->caption;
}

void WMSetButtonAltText(WMButton * bPtr, const char *text)
{
	if (bPtr->altCaption)
		wfree(bPtr->altCaption);

	if (text != NULL) {
		bPtr->altCaption = wstrdup(text);
	} else {
		bPtr->altCaption = NULL;
	}

	if (bPtr->view->flags.realized) {
		paintButton(bPtr);
	}
}

void WMSetButtonTextColor(WMButton * bPtr, WMColor * color)
{
	if (bPtr->textColor)
		WMReleaseColor(bPtr->textColor);

	bPtr->textColor = WMRetainColor(color);
}

void WMSetButtonAltTextColor(WMButton * bPtr, WMColor * color)
{
	if (bPtr->altTextColor)
		WMReleaseColor(bPtr->altTextColor);

	bPtr->altTextColor = WMRetainColor(color);
}

void WMSetButtonDisabledTextColor(WMButton * bPtr, WMColor * color)
{
	if (bPtr->disTextColor)
		WMReleaseColor(bPtr->disTextColor);

	bPtr->disTextColor = WMRetainColor(color);
}

void WMSetButtonSelected(WMButton * bPtr, int isSelected)
{
	if ((bPtr->flags.type == WBTTriState) && (isSelected < 0))
		bPtr->flags.selected = 2;
	else
		bPtr->flags.selected = isSelected ? 1 : 0;

	if (bPtr->view->flags.realized) {
		paintButton(bPtr);
	}
	if (bPtr->groupIndex > 0)
		WMPostNotificationName(WMPushedRadioNotification, bPtr, NULL);
}

int WMGetButtonSelected(WMButton * bPtr)
{
	CHECK_CLASS(bPtr, WC_Button);

	if ((bPtr->flags.type == WBTTriState) && (bPtr->flags.selected == 2))
		return -1;

	return bPtr->flags.selected;
}

void WMSetButtonBordered(WMButton * bPtr, int isBordered)
{
	bPtr->flags.bordered = isBordered;

	if (bPtr->view->flags.realized) {
		paintButton(bPtr);
	}
}

void WMSetButtonFont(WMButton * bPtr, WMFont * font)
{
	if (bPtr->font)
		WMReleaseFont(bPtr->font);

	bPtr->font = WMRetainFont(font);
}

void WMSetButtonEnabled(WMButton * bPtr, Bool flag)
{
	bPtr->flags.enabled = ((flag == 0) ? 0 : 1);

	if (bPtr->view->flags.mapped) {
		paintButton(bPtr);
	}
}

int WMGetButtonEnabled(WMButton * bPtr)
{
	CHECK_CLASS(bPtr, WC_Button);

	return bPtr->flags.enabled;
}

void WMSetButtonImageDimsWhenDisabled(WMButton * bPtr, Bool flag)
{
	bPtr->flags.dimsWhenDisabled = ((flag == 0) ? 0 : 1);

	updateDisabledMask(bPtr);
}

void WMSetButtonTag(WMButton * bPtr, int tag)
{
	bPtr->tag = tag;
}

void WMPerformButtonClick(WMButton * bPtr)
{
	CHECK_CLASS(bPtr, WC_Button);

	if (!bPtr->flags.enabled)
		return;

	bPtr->flags.pushed = 1;
	bPtr->flags.selected = 1;

	if (bPtr->view->flags.mapped) {
		paintButton(bPtr);
		XFlush(WMScreenDisplay(WMWidgetScreen(bPtr)));
		wusleep(20000);
	}

	bPtr->flags.pushed = 0;

	if (bPtr->groupIndex > 0) {
		WMPostNotificationName(WMPushedRadioNotification, bPtr, NULL);
	}

	if (bPtr->action)
		(*bPtr->action) (bPtr, bPtr->clientData);

	if (bPtr->view->flags.mapped)
		paintButton(bPtr);
}

void WMSetButtonAction(WMButton * bPtr, WMAction * action, void *clientData)
{
	CHECK_CLASS(bPtr, WC_Button);

	bPtr->action = action;

	bPtr->clientData = clientData;
}

static void radioPushObserver(void *observerData, WMNotification * notification)
{
	WMButton *bPtr = (WMButton *) observerData;
	WMButton *pushedButton = (WMButton *) WMGetNotificationObject(notification);

	if (bPtr != pushedButton && pushedButton->groupIndex == bPtr->groupIndex && bPtr->groupIndex != 0) {
		if (bPtr->flags.selected) {
			bPtr->flags.selected = 0;
			paintButton(bPtr);
		}
	}
}

void WMGroupButtons(WMButton * bPtr, WMButton * newMember)
{
	static int tagIndex = 0;

	CHECK_CLASS(bPtr, WC_Button);
	CHECK_CLASS(newMember, WC_Button);

	if (!bPtr->flags.addedObserver) {
		WMAddNotificationObserver(radioPushObserver, bPtr, WMPushedRadioNotification, NULL);
		bPtr->flags.addedObserver = 1;
	}
	if (!newMember->flags.addedObserver) {
		WMAddNotificationObserver(radioPushObserver, newMember, WMPushedRadioNotification, NULL);
		newMember->flags.addedObserver = 1;
	}

	if (bPtr->groupIndex == 0) {
		bPtr->groupIndex = ++tagIndex;
	}
	newMember->groupIndex = bPtr->groupIndex;
}

void WMSetButtonContinuous(WMButton * bPtr, Bool flag)
{
	bPtr->flags.continuous = ((flag == 0) ? 0 : 1);
	if (bPtr->timer) {
		WMDeleteTimerHandler(bPtr->timer);
		bPtr->timer = NULL;
	}
}

void WMSetButtonPeriodicDelay(WMButton * bPtr, float delay, float interval)
{
	bPtr->periodicInterval = interval;
	bPtr->periodicDelay = delay;
}

static void paintButton(Button * bPtr)
{
	W_Screen *scrPtr = bPtr->view->screen;
	WMReliefType relief;
	int offset;
	char *caption;
	WMPixmap *image;
	WMColor *textColor;
	WMColor *backColor;

	backColor = NULL;
	caption = bPtr->caption;

	if (bPtr->flags.enabled) {
		textColor = (bPtr->textColor != NULL ? bPtr->textColor : scrPtr->black);
	} else {
		textColor = (bPtr->disTextColor != NULL ? bPtr->disTextColor : scrPtr->darkGray);
	}

	if (bPtr->flags.enabled || !bPtr->dimage)
		image = bPtr->image;
	else
		image = bPtr->dimage;
	offset = 0;
	if (bPtr->flags.bordered)
		relief = WRRaised;
	else
		relief = WRFlat;

	if (bPtr->flags.selected) {
		if (bPtr->flags.stateLight) {
			backColor = scrPtr->white;
			textColor = scrPtr->black;
		}

		if (bPtr->flags.stateChange) {
			if (bPtr->altCaption)
				caption = bPtr->altCaption;
			if (bPtr->flags.selected == 2)
				image = bPtr->tsImage;
			else if (bPtr->altImage)
				image = bPtr->altImage;
			if (bPtr->altTextColor)
				textColor = bPtr->altTextColor;
		}

		if (bPtr->flags.statePush && bPtr->flags.bordered) {
			relief = WRSunken;
			offset = 1;
		}
	}

	if (bPtr->flags.pushed) {
		if (bPtr->flags.pushIn) {
			relief = WRPushed;
			offset = 1;
		}
		if (bPtr->flags.pushLight) {
			backColor = scrPtr->white;
			textColor = scrPtr->black;
		}

		if (bPtr->flags.pushChange) {
			if (bPtr->altCaption)
				caption = bPtr->altCaption;
			if (bPtr->altImage)
				image = bPtr->altImage;
			if (bPtr->altTextColor)
				textColor = bPtr->altTextColor;
		}
	}

	W_PaintTextAndImage(bPtr->view, True, textColor,
			    (bPtr->font != NULL ? bPtr->font : scrPtr->normalFont),
			    relief, caption, bPtr->flags.alignment, image,
			    bPtr->flags.imagePosition, backColor, offset);
}

static void handleEvents(XEvent * event, void *data)
{
	Button *bPtr = (Button *) data;

	CHECK_CLASS(data, WC_Button);

	switch (event->type) {
	case Expose:
		if (event->xexpose.count != 0)
			break;
		paintButton(bPtr);
		break;

	case DestroyNotify:
		destroyButton(bPtr);
		break;
	}
}

static void autoRepeat(void *data)
{
	Button *bPtr = (Button *) data;

	if (bPtr->action && bPtr->flags.pushed)
		(*bPtr->action) (bPtr, bPtr->clientData);

	bPtr->timer = WMAddTimerHandler((int)(bPtr->periodicInterval * 1000), autoRepeat, bPtr);
}

static void handleActionEvents(XEvent * event, void *data)
{
	Button *bPtr = (Button *) data;
	int doclick = 0, dopaint = 0;

	CHECK_CLASS(data, WC_Button);

	if (!bPtr->flags.enabled)
		return;

	switch (event->type) {
	case EnterNotify:
		if (bPtr->groupIndex == 0) {
			bPtr->flags.pushed = bPtr->flags.wasPushed;
			if (bPtr->flags.pushed) {
				bPtr->flags.selected = !bPtr->flags.prevSelected;
				dopaint = 1;
			}
		}
		break;

	case LeaveNotify:
		if (bPtr->groupIndex == 0) {
			bPtr->flags.wasPushed = bPtr->flags.pushed;
			if (bPtr->flags.pushed) {
				bPtr->flags.selected = bPtr->flags.prevSelected;
				dopaint = 1;
			}
			bPtr->flags.pushed = 0;
		}
		break;

	case ButtonPress:
		if (event->xbutton.button == Button1) {
			static const unsigned int next_state[4] = { [0] = 1, [1] = 2, [2] = 0 };

			bPtr->flags.prevSelected = bPtr->flags.selected;
			bPtr->flags.wasPushed = 0;
			bPtr->flags.pushed = 1;
			if (bPtr->groupIndex > 0) {
				bPtr->flags.selected = 1;
				dopaint = 1;
				break;
			}
			if (bPtr->flags.type == WBTTriState)
				bPtr->flags.selected = next_state[bPtr->flags.selected];
			else
				bPtr->flags.selected = !bPtr->flags.selected;
			dopaint = 1;

			if (bPtr->flags.continuous && !bPtr->timer) {
				bPtr->timer = WMAddTimerHandler((int)(bPtr->periodicDelay * 1000),
								autoRepeat, bPtr);
			}
		}
		break;

	case ButtonRelease:
		if (event->xbutton.button == Button1) {
			if (bPtr->flags.pushed) {
				if (bPtr->groupIndex == 0 || (bPtr->flags.selected && bPtr->groupIndex > 0))
					doclick = 1;
				dopaint = 1;
				if (bPtr->flags.springLoaded) {
					bPtr->flags.selected = bPtr->flags.prevSelected;
				}
			}
			bPtr->flags.pushed = 0;
		}
		if (bPtr->timer) {
			WMDeleteTimerHandler(bPtr->timer);
			bPtr->timer = NULL;
		}
		break;
	}

	if (dopaint)
		paintButton(bPtr);

	if (doclick) {
		if (bPtr->flags.selected && bPtr->groupIndex > 0) {
			WMPostNotificationName(WMPushedRadioNotification, bPtr, NULL);
		}

		if (bPtr->action)
			(*bPtr->action) (bPtr, bPtr->clientData);
	}
}

static void destroyButton(Button * bPtr)
{
	if (bPtr->flags.addedObserver) {
		WMRemoveNotificationObserver(bPtr);
	}

	if (bPtr->timer)
		WMDeleteTimerHandler(bPtr->timer);

	if (bPtr->font)
		WMReleaseFont(bPtr->font);

	if (bPtr->caption)
		wfree(bPtr->caption);

	if (bPtr->altCaption)
		wfree(bPtr->altCaption);

	if (bPtr->textColor)
		WMReleaseColor(bPtr->textColor);

	if (bPtr->altTextColor)
		WMReleaseColor(bPtr->altTextColor);

	if (bPtr->disTextColor)
		WMReleaseColor(bPtr->disTextColor);

	if (bPtr->image)
		WMReleasePixmap(bPtr->image);

	if (bPtr->dimage) {
		/* yuck.. kluge */
		bPtr->dimage->pixmap = None;

		WMReleasePixmap(bPtr->dimage);
	}
	if (bPtr->altImage)
		WMReleasePixmap(bPtr->altImage);

	if (bPtr->tsImage)
		WMReleasePixmap(bPtr->tsImage);

	wfree(bPtr);
}
