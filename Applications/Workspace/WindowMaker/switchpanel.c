/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2004 Alfredo K. Kojima
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#include "wconfig.h"

#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#include "WindowMaker.h"
#include "screen.h"
#include "wcore.h"
#include "framewin.h"
#include "window.h"
#include "defaults.h"
#include "switchpanel.h"
#include "funcs.h"
#include "xinerama.h"

#ifdef SHAPE
#include <X11/extensions/shape.h>

extern Bool wShapeSupported;
#endif


struct SwitchPanel {
    WScreen *scr;
    WMWindow *win;
    WMFrame *iconBox;
    
    WMArray *icons;
    WMArray *images;
    WMArray *windows;
    RImage *bg;
    int current;
    int firstVisible;
    int visibleCount;

    WMLabel *label;
    
    RImage *defIcon;
    
    RImage *tileTmp;
    RImage *tile;
    
    WMFont *font;
    WMColor *white;
};





extern WPreferences wPreferences;

#define BORDER_SPACE 10
#define ICON_SIZE 48
#define ICON_TILE_SIZE 64
#define LABEL_HEIGHT 25
#define SCREEN_BORDER_SPACING 2*20
#define SCROLL_STEPS (ICON_TILE_SIZE/2)

static int canReceiveFocus(WWindow *wwin)
{
  if (wwin->frame->workspace != wwin->screen_ptr->current_workspace)
    return 0;
  if (!wwin->flags.mapped)
  {
    if (!wwin->flags.shaded && !wwin->flags.miniaturized && !wwin->flags.hidden)
      return 0;
    else
      return -1;
  }
  if (WFLAGP(wwin, no_focusable))
    return 0;
  return 1;
}


static void changeImage(WSwitchPanel *panel, int idecks, int selected)
{
    WMFrame *icon = WMGetFromArray(panel->icons, idecks);
    RImage *image= WMGetFromArray(panel->images, idecks);

    if (!panel->bg && !panel->tile) {
        if (!selected)
          WMSetFrameRelief(icon, WRFlat);
    }

    if (image && icon) {
        RImage *back;
        int opaq= 255;
        RImage *tile;
        WMPoint pos;
        Pixmap p;

        if (canReceiveFocus(WMGetFromArray(panel->windows, idecks)) < 0)
          opaq= 50;

        pos= WMGetViewPosition(WMWidgetView(icon));
        back= panel->tileTmp;
        if (panel->bg)
          RCopyArea(back, panel->bg,
                    BORDER_SPACE+pos.x-panel->firstVisible*ICON_TILE_SIZE, BORDER_SPACE+pos.y,
                    back->width, back->height,
                    0, 0);
        else
        {
            RColor color;
            WMScreen *wscr= WMWidgetScreen(icon);
            color.red= 255;
            color.red = WMRedComponentOfColor(WMGrayColor(wscr))>>8;
            color.green = WMGreenComponentOfColor(WMGrayColor(wscr))>>8;
            color.blue = WMBlueComponentOfColor(WMGrayColor(wscr))>>8;
            RFillImage(back, &color);
        }
        if (selected)
        {
            tile= panel->tile;
            RCombineArea(back, tile, 0, 0, tile->width, tile->height,
                         (back->width - tile->width)/2, (back->height - tile->height)/2);
        }
        RCombineAreaWithOpaqueness(back, image, 0, 0, image->width, image->height,
                                   (back->width - image->width)/2, (back->height - image->height)/2,
                                   opaq);

        RConvertImage(panel->scr->rcontext, back, &p);
        XSetWindowBackgroundPixmap(dpy, WMWidgetXID(icon), p);
        XClearWindow(dpy, WMWidgetXID(icon));
        XFreePixmap(dpy, p);
    }

    if (!panel->bg && !panel->tile) {
        if (selected)
          WMSetFrameRelief(icon, WRSimple);
    }
}


static RImage *scaleDownIfNeeded(RImage *image)
{
    if (image && ((image->width - ICON_SIZE) > 2 || (image->height - ICON_SIZE) > 2)) {
        RImage *nimage;
        nimage= RScaleImage(image, ICON_SIZE, (image->height * ICON_SIZE / image->width));
        RReleaseImage(image);
        image= nimage;
    }
    return image;
}


static void addIconForWindow(WSwitchPanel *panel, WMWidget *parent, WWindow *wwin,
                             int x, int y)
{
    WMFrame *icon= WMCreateFrame(parent);
    RImage *image = NULL;

    WMSetFrameRelief(icon, WRFlat);
    WMResizeWidget(icon, ICON_TILE_SIZE, ICON_TILE_SIZE);
    WMMoveWidget(icon, x, y);
    
    if (!WFLAGP(wwin, always_user_icon) && wwin->net_icon_image)
      image = RRetainImage(wwin->net_icon_image);
    
    // Make this use a caching thing. When there are many windows,
    // it's very likely that most of them are instances of the same thing,
    // so caching them should get performance acceptable in these cases.
    if (!image)
      image = wDefaultGetImage(panel->scr, wwin->wm_instance, wwin->wm_class);
    
    if (!image && !panel->defIcon) {
        char *file = wDefaultGetIconFile(panel->scr, NULL, NULL, False);
        if (file) {
            char *path = FindImage(wPreferences.icon_path, file);
            if (path) {
                image = RLoadImage(panel->scr->rcontext, path, 0);
                wfree(path);
            }
        }
        if (image)
          panel->defIcon= scaleDownIfNeeded(image);
        image= NULL;
    }
    if (!image && panel->defIcon)
      image= RRetainImage(panel->defIcon);
    
    image= scaleDownIfNeeded(image);
    
    WMAddToArray(panel->images, image);
    WMAddToArray(panel->icons, icon);
}


static void scrollIcons(WSwitchPanel *panel, int delta)
{
    int nfirst= panel->firstVisible + delta;
    int i;
    int count= WMGetArrayItemCount(panel->windows);
//    int nx, ox;
//    struct timeval tv1, tv2;

    if (count <= panel->visibleCount)
      return;

    if (nfirst < 0)
      nfirst= 0;
    else if (nfirst >= count-panel->visibleCount)
      nfirst= count-panel->visibleCount;

    if (nfirst == panel->firstVisible)
      return;
/*
    ox = -panel->firstVisible * ICON_TILE_SIZE;
    nx = -nfirst * ICON_TILE_SIZE;
    for (i= 0; i < SCROLL_STEPS; i++) {
        unsigned int diff;
        gettimeofday(&tv1, NULL);
        WMMoveWidget(panel->iconBox, (nx*i + ox*(SCROLL_STEPS-i))/(SCROLL_STEPS-1), 0);
        XSync(dpy, False);
        gettimeofday(&tv2, NULL);
        diff = (tv2.tv_sec-tv1.tv_sec)*10000+(tv2.tv_usec-tv1.tv_usec)/100;
        if (diff < 200)
          wusleep(300-diff);
    }
 */    
    WMMoveWidget(panel->iconBox, -nfirst*ICON_TILE_SIZE, 0);

    panel->firstVisible= nfirst;
    
    for (i= panel->firstVisible; i < panel->firstVisible+panel->visibleCount; i++) {
        changeImage(panel, i, i == panel->current);
    }
}


/*
 * 0 1 2
 * 3 4 5
 * 6 7 8
 */
static RImage *assemblePuzzleImage(RImage **images, int width, int height)
{
    RImage *img= RCreateImage(width, height, 1);
    RImage *tmp;
    int tw, th;
    RColor color;
    if (!img)
      return NULL;

    color.red= 0;
    color.green= 0;
    color.blue= 0;
    color.alpha= 255;

    RFillImage(img, &color);

    tw= width-images[0]->width-images[2]->width;
    th= height-images[0]->height-images[6]->height;

    if (tw <= 0 || th <= 0) {
        //XXX
        return NULL;
    }

    /* top */
    if (tw > 0) {
        tmp= RSmoothScaleImage(images[1], tw, images[1]->height);
        RCopyArea(img, tmp, 0, 0, tmp->width, tmp->height,
                  images[0]->width, 0);
        RReleaseImage(tmp);
    }
    /* bottom */
    if (tw > 0) {
        tmp= RSmoothScaleImage(images[7], tw, images[7]->height);
        RCopyArea(img, tmp, 0, 0, tmp->width, tmp->height,
                  images[6]->width, height-images[6]->height);
        RReleaseImage(tmp);
    }
    /* left */
    if (th > 0) {
        tmp= RSmoothScaleImage(images[3], images[3]->width, th);
        RCopyArea(img, tmp, 0, 0, tmp->width, tmp->height,
                  0, images[0]->height);
        RReleaseImage(tmp);
    }
    /* right */
    if (th > 0) {
        tmp= RSmoothScaleImage(images[5], images[5]->width, th);
        RCopyArea(img, tmp, 0, 0, tmp->width, tmp->height,
                  width-images[5]->width, images[2]->height);
        RReleaseImage(tmp);
    }
    /* center */
    if (tw > 0 && th > 0) {
        tmp= RSmoothScaleImage(images[4], tw, th);
        RCopyArea(img, tmp, 0, 0, tmp->width, tmp->height,
                  images[0]->width, images[0]->height);
        RReleaseImage(tmp);
    }

    /* corners */
    RCopyArea(img, images[0], 0, 0, images[0]->width, images[0]->height,
              0, 0);

    RCopyArea(img, images[2], 0, 0, images[2]->width, images[2]->height,
              width-images[2]->width, 0);

    RCopyArea(img, images[6], 0, 0, images[6]->width, images[6]->height,
              0, height-images[6]->height);

    RCopyArea(img, images[8], 0, 0, images[8]->width, images[8]->height,
              width-images[8]->width, height-images[8]->height);

    return img;
}

static RImage *createBackImage(WScreen *scr, int width, int height)
{
    return assemblePuzzleImage(wPreferences.swbackImage, width, height);
}


static RImage *getTile(WSwitchPanel *panel)
{
    RImage *stile;

    if (!wPreferences.swtileImage)
        return NULL;

    stile = RScaleImage(wPreferences.swtileImage, ICON_TILE_SIZE, ICON_TILE_SIZE);
    if (!stile)
        return wPreferences.swtileImage;
    
    return stile;
}


static void
drawTitle(WSwitchPanel *panel, int idecks, char *title)
{
    char *ntitle;
    int width= WMWidgetWidth(panel->win);
    int x;

    if (title)
        ntitle= ShrinkString(panel->font, title, width-2*BORDER_SPACE);
    else
        ntitle= NULL;

    if (panel->bg) {
        if (ntitle) {
            if (strcmp(ntitle, title)!=0)
              x= BORDER_SPACE;
            else
            {
                int w= WMWidthOfString(panel->font, ntitle, strlen(ntitle));
            
                x= BORDER_SPACE+(idecks-panel->firstVisible)*ICON_TILE_SIZE + ICON_TILE_SIZE/2 - w/2;
                if (x < BORDER_SPACE)
                    x= BORDER_SPACE;
                else if (x + w > width-BORDER_SPACE)
                    x= width-BORDER_SPACE-w;
            }
        }       
        XClearWindow(dpy, WMWidgetXID(panel->win));
        if (ntitle)
            WMDrawString(panel->scr->wmscreen, 
                         WMWidgetXID(panel->win),
                         panel->white, panel->font,
                         x, WMWidgetHeight(panel->win) - BORDER_SPACE - LABEL_HEIGHT + WMFontHeight(panel->font)/2,
                         ntitle, strlen(ntitle));
    } else {
        if (ntitle)
            WMSetLabelText(panel->label, ntitle);
    }
    if (ntitle)
        free(ntitle);
}



static WMArray *makeWindowListArray(WScreen *scr, WWindow *curwin, int workspace,
                                    int include_unmapped)
{
    WMArray *windows= WMCreateArray(10);
    int fl;
    WWindow *wwin;

    for (fl= 0; fl < 2; fl++) {
        for (wwin= curwin; wwin; wwin= wwin->prev) {
            if (((!fl && canReceiveFocus(wwin) > 0) || (fl && canReceiveFocus(wwin) < 0)) &&
                (!WFLAGP(wwin, skip_window_list) || wwin->flags.internal_window) &&
                (wwin->flags.mapped || include_unmapped)) {
                WMAddToArray(windows, wwin);
            }
        }
        wwin = curwin;
        /* start over from the beginning of the list */
        while (wwin->next)
          wwin = wwin->next;
        
        for (wwin= curwin; wwin && wwin != curwin; wwin= wwin->prev) {
            if (((!fl && canReceiveFocus(wwin) > 0) || (fl && canReceiveFocus(wwin) < 0)) &&
                (!WFLAGP(wwin, skip_window_list) || wwin->flags.internal_window) &&
                (wwin->flags.mapped || include_unmapped)) {
                WMAddToArray(windows, wwin);
            }
        }
    }

    return windows;
}





WSwitchPanel *wInitSwitchPanel(WScreen *scr, WWindow *curwin, int workspace)
{
    WWindow *wwin;
    WSwitchPanel *panel= wmalloc(sizeof(WSwitchPanel));
    WMFrame *viewport;
    int i;
    int width, height;
    int iconsThatFitCount;
    int count;
    WMRect rect;
    rect= wGetRectForHead(scr, wGetHeadForPointerLocation(scr));

    memset(panel, 0, sizeof(WSwitchPanel));

    panel->scr= scr;

    panel->windows= makeWindowListArray(scr, curwin, workspace,
                                        wPreferences.swtileImage!=0);
    count= WMGetArrayItemCount(panel->windows);
    
    if (count == 0) {
        WMFreeArray(panel->windows);
        wfree(panel);
        return NULL;
    }

    width= ICON_TILE_SIZE*count;
    iconsThatFitCount= count;

    if (width > rect.size.width) {
        iconsThatFitCount = (WMScreenWidth(scr->wmscreen)-SCREEN_BORDER_SPACING)/ICON_TILE_SIZE;
        width= iconsThatFitCount*ICON_TILE_SIZE;
    }
    
    panel->visibleCount= iconsThatFitCount;

    if (!wPreferences.swtileImage)
        return panel;

    height= LABEL_HEIGHT + ICON_TILE_SIZE;

    panel->tileTmp= RCreateImage(ICON_TILE_SIZE, ICON_TILE_SIZE, 1);
    panel->tile= getTile(panel);
    if (panel->tile && wPreferences.swbackImage[8]) {
        panel->bg= createBackImage(scr, width+2*BORDER_SPACE, height+2*BORDER_SPACE);
    }
    if (!panel->tileTmp || !panel->tile) {
        if (panel->bg)
          RReleaseImage(panel->bg);
        panel->bg= NULL;
        if (panel->tile)
          RReleaseImage(panel->tile);
        panel->tile= NULL;
        if (panel->tileTmp)
          RReleaseImage(panel->tileTmp);
        panel->tileTmp= NULL;
    }

    panel->white= WMWhiteColor(scr->wmscreen);
    panel->font= WMBoldSystemFontOfSize(scr->wmscreen, 12);
    panel->icons= WMCreateArray(count);
    panel->images= WMCreateArray(count);

    panel->win = WMCreateWindow(scr->wmscreen, "");

    if (!panel->bg) {
        WMFrame *frame = WMCreateFrame(panel->win);
        WMSetFrameRelief(frame, WRSimple);
        WMSetViewExpandsToParent(WMWidgetView(frame), 0, 0, 0, 0);
        
        panel->label = WMCreateLabel(panel->win);
        WMResizeWidget(panel->label, width, LABEL_HEIGHT);
        WMMoveWidget(panel->label, BORDER_SPACE, BORDER_SPACE+ICON_TILE_SIZE+5);
        WMSetLabelRelief(panel->label, WRSimple);
        WMSetWidgetBackgroundColor(panel->label, WMDarkGrayColor(scr->wmscreen));
        WMSetLabelFont(panel->label, panel->font);
        WMSetLabelTextColor(panel->label, panel->white);
        
        height+= 5;
    }
    
    WMResizeWidget(panel->win, width + 2*BORDER_SPACE, height + 2*BORDER_SPACE);
    
    viewport= WMCreateFrame(panel->win);
    WMResizeWidget(viewport, width, ICON_TILE_SIZE);
    WMMoveWidget(viewport, BORDER_SPACE, BORDER_SPACE);
    WMSetFrameRelief(viewport, WRFlat);
    
    panel->iconBox= WMCreateFrame(viewport);
    WMMoveWidget(panel->iconBox, 0, 0);
    WMResizeWidget(panel->iconBox, ICON_TILE_SIZE*count, ICON_TILE_SIZE);
    WMSetFrameRelief(panel->iconBox, WRFlat);
    
    WM_ITERATE_ARRAY(panel->windows, wwin, i) {
        addIconForWindow(panel, panel->iconBox, wwin, i*ICON_TILE_SIZE, 0);
    }

    WMMapSubwidgets(panel->win);
    WMRealizeWidget(panel->win);
    
    WM_ITERATE_ARRAY(panel->windows, wwin, i) {
        changeImage(panel, i, 0);
    }
    
    if (panel->bg) {
        Pixmap pixmap, mask;

        RConvertImageMask(scr->rcontext, panel->bg, &pixmap, &mask, 250);

        XSetWindowBackgroundPixmap(dpy, WMWidgetXID(panel->win), pixmap);

#ifdef SHAPE
        if (mask && wShapeSupported)
          XShapeCombineMask(dpy, WMWidgetXID(panel->win),
                            ShapeBounding, 0, 0, mask, ShapeSet);
#endif
        
        if (pixmap)
          XFreePixmap(dpy, pixmap);
        if (mask)
          XFreePixmap(dpy, mask);
    }

    {
        WMPoint center;
        center= wGetPointToCenterRectInHead(scr, wGetHeadForPointerLocation(scr),
                                            width+2*BORDER_SPACE, height+2*BORDER_SPACE);
        WMMoveWidget(panel->win, center.x, center.y);
    }

    panel->current= WMGetFirstInArray(panel->windows, curwin);
    if (panel->current >= 0)
        changeImage(panel, panel->current, 1);

    WMMapWidget(panel->win);

    return panel;
}


void wSwitchPanelDestroy(WSwitchPanel *panel)
{
    int i;
    RImage *image;
    
    if (panel->win)
      WMUnmapWidget(panel->win);

    if (panel->images) {
        WM_ITERATE_ARRAY(panel->images, image, i) {
            if (image)
              RReleaseImage(image);
        }
        WMFreeArray(panel->images);
    }
    if (panel->win)
      WMDestroyWidget(panel->win);
    if (panel->icons)
      WMFreeArray(panel->icons);
    WMFreeArray(panel->windows);
    if (panel->defIcon)
      RReleaseImage(panel->defIcon);
    if (panel->tile)
      RReleaseImage(panel->tile);
    if (panel->tileTmp)
      RReleaseImage(panel->tileTmp);
    if (panel->bg)
      RReleaseImage(panel->bg);
    if (panel->font)
      WMReleaseFont(panel->font);
    wfree(panel);
}


WWindow *wSwitchPanelSelectNext(WSwitchPanel *panel, int back)
{
    WWindow *wwin;
    int count = WMGetArrayItemCount(panel->windows);
    
    if (count == 0)
      return NULL;
    
    if (panel->win)
      changeImage(panel, panel->current, 0);
    
    if (back)
      panel->current--;
    else
      panel->current++;

    wwin = WMGetFromArray(panel->windows, (count+panel->current)%count);

    if (back)
    {
        if (panel->current < 0)
          scrollIcons(panel, count);
        else if (panel->current < panel->firstVisible)
          scrollIcons(panel, -1);
    }
    else
    {
        if (panel->current >= count)
          scrollIcons(panel, -count);
        else if (panel->current - panel->firstVisible >= panel->visibleCount)
          scrollIcons(panel, 1);
    }

    panel->current= (count+panel->current)%count;

    if (panel->win) {
        drawTitle(panel, panel->current, wwin->frame->title);

        changeImage(panel, panel->current, 1);
    }

    return wwin;
}


WWindow *wSwitchPanelSelectFirst(WSwitchPanel *panel, int back)
{
    WWindow *wwin;
    int count = WMGetArrayItemCount(panel->windows);

    if (count == 0)
      return NULL;

    if (panel->win)
      changeImage(panel, panel->current, 0);
    
    if (back) {
        panel->current = count-1;
        scrollIcons(panel, count);
    } else {
        panel->current = 0;
        scrollIcons(panel, -count);
    }
    
    wwin = WMGetFromArray(panel->windows, panel->current);
    
    if (panel->win) {
        drawTitle(panel, panel->current, wwin->frame->title);

        changeImage(panel, panel->current, 1);
    }
    return wwin;
}


WWindow *wSwitchPanelHandleEvent(WSwitchPanel *panel, XEvent *event)
{
    WMFrame *icon;
    int i;
    int focus= -1;
    
    if (!panel->win)
      return NULL;

 /*   if (event->type == LeaveNotify) {
        if (event->xcrossing.window == WMWidgetXID(panel->win))
            focus= 0;
    } else*/ if (event->type == MotionNotify) {

        WM_ITERATE_ARRAY(panel->icons, icon, i) {
            if (WMWidgetXID(icon) == event->xmotion.window) {
                focus= i;
                break;
            }
        }
    }  
    if (focus >= 0 && panel->current != focus) {
        WWindow *wwin;
            
        changeImage(panel, panel->current, 0);
        changeImage(panel, focus, 1);
        panel->current= focus;
            
        wwin= WMGetFromArray(panel->windows, focus);
            
        drawTitle(panel, panel->current, wwin->frame->title);
            
        return wwin;
    }

    return NULL;
}


Window wSwitchPanelGetWindow(WSwitchPanel *swpanel)
{
    if (!swpanel->win)
      return None;
    return WMWidgetXID(swpanel->win);
}
