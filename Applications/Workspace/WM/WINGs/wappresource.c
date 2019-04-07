
#include <unistd.h>

#include "WINGsP.h"

#include <X11/Xutil.h>

#include "GNUstep.h"


void WMSetApplicationIconWindow(WMScreen * scr, Window window)
{
	scr->applicationIconWindow = window;

	if (scr->groupLeader) {
		XWMHints *hints;

		hints = XGetWMHints(scr->display, scr->groupLeader);
		hints->flags |= IconWindowHint;
		hints->icon_window = window;

		XSetWMHints(scr->display, scr->groupLeader, hints);
		XFree(hints);
	}
}

void WMSetApplicationIconImage(WMScreen * scr, RImage * image)
{
	WMPixmap *icon;

	if (scr->applicationIconImage == image)
		return;

	if (scr->applicationIconImage)
		RReleaseImage(scr->applicationIconImage);

	scr->applicationIconImage = RRetainImage(image);

	/* TODO: check whether we should set the pixmap only if there's none yet */
	if (image != NULL && (icon = WMCreatePixmapFromRImage(scr, image, 128)) != NULL) {
		WMSetApplicationIconPixmap(scr, icon);
		WMReleasePixmap(icon);
	}
}

RImage *WMGetApplicationIconImage(WMScreen * scr)
{
	return scr->applicationIconImage;
}

void WMSetApplicationIconPixmap(WMScreen * scr, WMPixmap * icon)
{
	if (scr->applicationIconPixmap == icon)
		return;

	if (scr->applicationIconPixmap)
		WMReleasePixmap(scr->applicationIconPixmap);

	scr->applicationIconPixmap = WMRetainPixmap(icon);

	if (scr->groupLeader) {
		XWMHints *hints;

		hints = XGetWMHints(scr->display, scr->groupLeader);
		hints->flags |= IconPixmapHint | IconMaskHint;
		hints->icon_pixmap = (icon != NULL ? icon->pixmap : None);
		hints->icon_mask = (icon != NULL ? icon->mask : None);

		XSetWMHints(scr->display, scr->groupLeader, hints);
		XFree(hints);
	}
}

WMPixmap *WMGetApplicationIconPixmap(WMScreen * scr)
{
	return scr->applicationIconPixmap;
}

WMPixmap *WMCreateApplicationIconBlendedPixmap(WMScreen * scr, const RColor * color)
{
	WMPixmap *pix;

	if (scr->applicationIconImage) {
		static const RColor gray = {
			/* red   */ 0xAE,
			/* green */ 0xAA,
			/* blue  */ 0xAE,
			/* alpha */ 0xFF
		};

		if (!color)
			color = &gray;

		pix = WMCreateBlendedPixmapFromRImage(scr, scr->applicationIconImage, color);
	} else {
		pix = NULL;
	}

	return pix;
}

void WMSetApplicationHasAppIcon(WMScreen * scr, Bool flag)
{
	scr->aflags.hasAppIcon = ((flag == 0) ? 0 : 1);
}

void W_InitApplication(WMScreen * scr)
{
	Window leader;
	XClassHint *classHint;
	XWMHints *hints;

	leader = XCreateSimpleWindow(scr->display, scr->rootWin, -1, -1, 1, 1, 0, 0, 0);

	if (!scr->aflags.simpleApplication) {
		classHint = XAllocClassHint();
		classHint->res_name = "groupLeader";
		classHint->res_class = WMApplication.applicationName;
		XSetClassHint(scr->display, leader, classHint);
		XFree(classHint);

		XSetCommand(scr->display, leader, WMApplication.argv, WMApplication.argc);

		hints = XAllocWMHints();

		hints->flags = WindowGroupHint;
		hints->window_group = leader;

		/* This code will never actually be reached, because to have
		 * scr->applicationIconPixmap set we need to have a screen first,
		 * but this function is called in the screen creation process.
		 * -Dan
		 */
		if (scr->applicationIconPixmap) {
			hints->flags |= IconPixmapHint;
			hints->icon_pixmap = scr->applicationIconPixmap->pixmap;
			if (scr->applicationIconPixmap->mask) {
				hints->flags |= IconMaskHint;
				hints->icon_mask = scr->applicationIconPixmap->mask;
			}
		}

		XSetWMHints(scr->display, leader, hints);

		XFree(hints);
	}
	scr->groupLeader = leader;
}
