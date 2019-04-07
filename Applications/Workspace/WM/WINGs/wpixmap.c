
#include "WINGsP.h"

#include <wraster.h>

WMPixmap *WMRetainPixmap(WMPixmap * pixmap)
{
	if (pixmap)
		pixmap->refCount++;

	return pixmap;
}

void WMReleasePixmap(WMPixmap * pixmap)
{
	wassertr(pixmap != NULL);

	pixmap->refCount--;

	if (pixmap->refCount < 1) {
		if (pixmap->pixmap)
			XFreePixmap(pixmap->screen->display, pixmap->pixmap);
		if (pixmap->mask)
			XFreePixmap(pixmap->screen->display, pixmap->mask);
		wfree(pixmap);
	}
}

WMPixmap *WMCreatePixmap(WMScreen * scrPtr, int width, int height, int depth, Bool masked)
{
	WMPixmap *pixPtr;

	pixPtr = wmalloc(sizeof(WMPixmap));
	pixPtr->screen = scrPtr;
	pixPtr->width = width;
	pixPtr->height = height;
	pixPtr->depth = depth;
	pixPtr->refCount = 1;

	pixPtr->pixmap = XCreatePixmap(scrPtr->display, W_DRAWABLE(scrPtr), width, height, depth);
	if (masked) {
		pixPtr->mask = XCreatePixmap(scrPtr->display, W_DRAWABLE(scrPtr), width, height, 1);
	} else {
		pixPtr->mask = None;
	}

	return pixPtr;
}

WMPixmap *WMCreatePixmapFromXPixmaps(WMScreen * scrPtr, Pixmap pixmap, Pixmap mask,
				     int width, int height, int depth)
{
	WMPixmap *pixPtr;

	pixPtr = wmalloc(sizeof(WMPixmap));
	pixPtr->screen = scrPtr;
	pixPtr->pixmap = pixmap;
	pixPtr->mask = mask;
	pixPtr->width = width;
	pixPtr->height = height;
	pixPtr->depth = depth;
	pixPtr->refCount = 1;

	return pixPtr;
}

WMPixmap *WMCreatePixmapFromFile(WMScreen * scrPtr, const char *fileName)
{
	WMPixmap *pixPtr;
	RImage *image;

	image = RLoadImage(scrPtr->rcontext, fileName, 0);
	if (!image)
		return NULL;

	pixPtr = WMCreatePixmapFromRImage(scrPtr, image, 127);

	RReleaseImage(image);

	return pixPtr;
}

WMPixmap *WMCreatePixmapFromRImage(WMScreen * scrPtr, RImage * image, int threshold)
{
	WMPixmap *pixPtr;
	Pixmap pixmap, mask;

	if (image == NULL)
		return NULL;

	if (!RConvertImageMask(scrPtr->rcontext, image, &pixmap, &mask, threshold)) {
		return NULL;
	}

	pixPtr = wmalloc(sizeof(WMPixmap));
	pixPtr->screen = scrPtr;
	pixPtr->pixmap = pixmap;
	pixPtr->mask = mask;
	pixPtr->width = image->width;
	pixPtr->height = image->height;
	pixPtr->depth = scrPtr->depth;
	pixPtr->refCount = 1;

	return pixPtr;
}

WMPixmap *WMCreateBlendedPixmapFromRImage(WMScreen * scrPtr, RImage * image, const RColor * color)
{
	WMPixmap *pixPtr;
	RImage *copy;

	copy = RCloneImage(image);
	if (!copy)
		return NULL;

	RCombineImageWithColor(copy, color);
	pixPtr = WMCreatePixmapFromRImage(scrPtr, copy, 0);
	RReleaseImage(copy);

	return pixPtr;
}

WMPixmap *WMCreateBlendedPixmapFromFile(WMScreen * scrPtr, const char *fileName, const RColor * color)
{
	return WMCreateScaledBlendedPixmapFromFile(scrPtr, fileName, color, 0, 0);
}

WMPixmap *WMCreateScaledBlendedPixmapFromFile(WMScreen *scrPtr, const char *fileName, const RColor *color,
                                              unsigned int width, unsigned int height)
{
	WMPixmap *pixPtr;
	RImage *image;

	image = RLoadImage(scrPtr->rcontext, fileName, 0);
	if (!image)
		return NULL;

	/* scale it if needed to fit in the specified box */
	if ((width > 0) && (height > 0) && ((image->width > width) || (image->height > height))) {
		int new_width, new_height;
		RImage *new_image;

		new_width  = image->width;
		new_height = image->height;
		if (new_width > width) {
			new_width  = width;
			new_height = width * image->height / image->width;
		}
		if (new_height > height) {
			new_width  = height * image->width / image->height;
			new_height = height;
		}

		new_image = RScaleImage(image, new_width, new_height);
		RReleaseImage(image);
		image = new_image;
	}

	RCombineImageWithColor(image, color);
	pixPtr = WMCreatePixmapFromRImage(scrPtr, image, 0);
	RReleaseImage(image);

	return pixPtr;
}

WMPixmap *WMCreatePixmapFromXPMData(WMScreen * scrPtr, char **data)
{
	WMPixmap *pixPtr;
	RImage *image;

	image = RGetImageFromXPMData(scrPtr->rcontext, data);
	if (!image)
		return NULL;

	pixPtr = WMCreatePixmapFromRImage(scrPtr, image, 127);

	RReleaseImage(image);

	return pixPtr;
}

Pixmap WMGetPixmapXID(WMPixmap * pixmap)
{
	wassertrv(pixmap != NULL, None);

	return pixmap->pixmap;
}

Pixmap WMGetPixmapMaskXID(WMPixmap * pixmap)
{
	wassertrv(pixmap != NULL, None);

	return pixmap->mask;
}

WMSize WMGetPixmapSize(WMPixmap * pixmap)
{
	WMSize size = { 0, 0 };

	wassertrv(pixmap != NULL, size);

	size.width = pixmap->width;
	size.height = pixmap->height;

	return size;
}

WMPixmap *WMGetSystemPixmap(WMScreen * scr, int image)
{
	switch (image) {
	case WSIReturnArrow:
		return WMRetainPixmap(scr->buttonArrow);

	case WSIHighlightedReturnArrow:
		return WMRetainPixmap(scr->pushedButtonArrow);

	case WSIScrollerDimple:
		return WMRetainPixmap(scr->scrollerDimple);

	case WSIArrowLeft:
		return WMRetainPixmap(scr->leftArrow);

	case WSIHighlightedArrowLeft:
		return WMRetainPixmap(scr->hiLeftArrow);

	case WSIArrowRight:
		return WMRetainPixmap(scr->rightArrow);

	case WSIHighlightedArrowRight:
		return WMRetainPixmap(scr->hiRightArrow);

	case WSIArrowUp:
		return WMRetainPixmap(scr->upArrow);

	case WSIHighlightedArrowUp:
		return WMRetainPixmap(scr->hiUpArrow);

	case WSIArrowDown:
		return WMRetainPixmap(scr->downArrow);

	case WSIHighlightedArrowDown:
		return WMRetainPixmap(scr->hiDownArrow);

	case WSICheckMark:
		return WMRetainPixmap(scr->checkMark);

	default:
		return NULL;
	}
}

void WMDrawPixmap(WMPixmap * pixmap, Drawable d, int x, int y)
{
	WMScreen *scr = pixmap->screen;

	XSetClipMask(scr->display, scr->clipGC, pixmap->mask);
	XSetClipOrigin(scr->display, scr->clipGC, x, y);

	XCopyArea(scr->display, pixmap->pixmap, d, scr->clipGC, 0, 0, pixmap->width, pixmap->height, x, y);
}
