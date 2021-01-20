/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
 *  Copyright (c) 2014 Window Maker Team
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

#include <wraster.h>

#include "WMcore.h"
#include "util.h"

#include "wpixmap.h"

WMPixmap *WMRetainPixmap(WMPixmap *pixmap)
{
  if (pixmap)
    pixmap->refCount++;

  return pixmap;
}

void WMReleasePixmap(WMPixmap *pixmap)
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

WMPixmap *WMCreatePixmap(WMScreen *scrPtr, int width, int height, int depth, Bool masked)
{
  WMPixmap *pixPtr;

  pixPtr = wmalloc(sizeof(WMPixmap));
  pixPtr->screen = scrPtr;
  pixPtr->width = width;
  pixPtr->height = height;
  pixPtr->depth = depth;
  pixPtr->refCount = 1;

  pixPtr->pixmap = XCreatePixmap(scrPtr->display, WMScreenDrawable(scrPtr), width, height, depth);
  if (masked) {
    pixPtr->mask = XCreatePixmap(scrPtr->display, WMScreenDrawable(scrPtr), width, height, 1);
  } else {
    pixPtr->mask = None;
  }

  return pixPtr;
}

WMPixmap *WMCreatePixmapFromXPixmaps(WMScreen *scrPtr, Pixmap pixmap, Pixmap mask,
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

/* Next 2 functions were located in widgets.c with name `makePixmap`.
   FIXME: not used/useful anymore. */
static
void renderPixmap(WMScreen *screen, Pixmap d, Pixmap mask, char **data, int width, int height)
{
  int x, y;
  GC whiteGC = WMColorGC(screen->white);
  GC blackGC = WMColorGC(screen->black);
  GC lightGC = WMColorGC(screen->gray);
  GC darkGC = WMColorGC(screen->darkGray);

  if (mask)
    XSetForeground(screen->display, screen->monoGC, 0);

  for (y = 0; y < height; y++) {
    for (x = 0; x < width; x++) {
      switch (data[y][x]) {
      case ' ':
      case 'w':
        XDrawPoint(screen->display, d, whiteGC, x, y);
        break;

      case '=':
        if (mask)
          XDrawPoint(screen->display, mask, screen->monoGC, x, y);

      case '.':
      case 'l':
        XDrawPoint(screen->display, d, lightGC, x, y);
        break;

      case '%':
      case 'd':
        XDrawPoint(screen->display, d, darkGC, x, y);
        break;

      case '#':
      case 'b':
      default:
        XDrawPoint(screen->display, d, blackGC, x, y);
        break;
      }
    }
  }
}
WMPixmap *WMCreatePixmapFromData(WMScreen *sPtr, char **data, int width, int height, int masked)
{
  Pixmap pixmap, mask = None;

  pixmap = XCreatePixmap(sPtr->display, WMScreenDrawable(sPtr), width, height, sPtr->depth);

  if (masked) {
    mask = XCreatePixmap(sPtr->display, WMScreenDrawable(sPtr), width, height, 1);
    XSetForeground(sPtr->display, sPtr->monoGC, 1);
    XFillRectangle(sPtr->display, mask, sPtr->monoGC, 0, 0, width, height);
  }

  renderPixmap(sPtr, pixmap, mask, data, width, height);

  return WMCreatePixmapFromXPixmaps(sPtr, pixmap, mask, width, height, sPtr->depth);
}

WMPixmap *WMCreatePixmapFromFile(WMScreen *scrPtr, const char *fileName)
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

WMPixmap *WMCreatePixmapFromRImage(WMScreen *scrPtr, RImage *image, int threshold)
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

WMPixmap *WMCreateBlendedPixmapFromRImage(WMScreen *scrPtr, RImage *image, const RColor *color)
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

WMPixmap *WMCreateBlendedPixmapFromFile(WMScreen *scrPtr, const char *fileName, const RColor *color)
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
      new_height = width *image->height / image->width;
    }
    if (new_height > height) {
      new_width  = height *image->width / image->height;
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

WMPixmap *WMCreatePixmapFromXPMData(WMScreen *scrPtr, char **data)
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

Pixmap WMGetPixmapXID(WMPixmap *pixmap)
{
  wassertrv(pixmap != NULL, None);

  return pixmap->pixmap;
}

Pixmap WMGetPixmapMaskXID(WMPixmap *pixmap)
{
  wassertrv(pixmap != NULL, None);

  return pixmap->mask;
}

WMSize WMGetPixmapSize(WMPixmap *pixmap)
{
  WMSize size = { 0, 0 };

  wassertrv(pixmap != NULL, size);

  size.width = pixmap->width;
  size.height = pixmap->height;

  return size;
}

void WMDrawPixmap(WMPixmap *pixmap, Drawable d, int x, int y)
{
  WMScreen *scr = pixmap->screen;

  XSetClipMask(scr->display, scr->clipGC, pixmap->mask);
  XSetClipOrigin(scr->display, scr->clipGC, x, y);

  XCopyArea(scr->display, pixmap->pixmap, d, scr->clipGC, 0, 0, pixmap->width, pixmap->height, x, y);
}
