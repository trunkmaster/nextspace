/*
 * magnify - a X utility for magnifying screen image
 *
 * 2000/5/21  Alfredo K. Kojima
 *
 * This program is in the Public Domain.
 */

#include <X11/Xproto.h>

#include <WINGs/WINGs.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/*
 * TODO:
 * - lens that shows where it's magnifying
 *
 *
 */

int refreshrate = 200;


typedef struct {
    Drawable d;
    XRectangle *rects;
    int rectP;
    unsigned long lastpixel;
    unsigned long *buffer;
    int width, height;
    int rwidth, rheight; 	       /* size of window in real pixels */
    int magfactor;
    int refreshrate;

    WMWindow *win;
    WMLabel *label;
    WMPixmap *pixmap;

    WMWindow *dlg;

    WMSlider *speed;
    WMSlider *magnify;
    WMButton *okB;
    WMButton *cancelB;
    WMButton *newB;

    int x, y;
    Bool frozen;
    Bool firstDraw;
    Bool markPointerHotspot;

    WMHandlerID tid;
} BufferData;



static BufferData *newWindow(int magfactor);


int windowCount = 0;

int rectBufferSize = 32;
Display *dpy, *vdpy;
WMScreen *scr;
unsigned int black;
WMColor *cursorColor1;
WMColor *cursorColor2;

#ifndef __GNUC__
#define inline
#endif


static BufferData*
makeBufferData(WMWindow *win, WMLabel *label, int width, int height,
               int magfactor)
{
    BufferData *data;

    data = wmalloc(sizeof(BufferData));

    data->rwidth = width;
    data->rheight = height;

    data->refreshrate = refreshrate;

    data->firstDraw = True;

    data->magfactor = magfactor;

    data->rects = wmalloc(sizeof(XRectangle)*rectBufferSize);
    data->rectP = 0;

    data->win = win;
    data->label = label;

    data->pixmap = WMCreatePixmap(scr, width, height,
                                  WMScreenDepth(scr), False);
    WMSetLabelImage(data->label, data->pixmap);

    data->d = WMGetPixmapXID(data->pixmap);

    data->frozen = False;

    width /= magfactor;
    height /= magfactor;
    data->buffer = wmalloc(sizeof(unsigned long)*width*height);
    memset(data->buffer, 0, width*height*sizeof(unsigned long));
    data->width = width;
    data->height = height;

    return data;
}


static void
resizeBufferData(BufferData *data, int width, int height, int magfactor)
{
    int w = width/magfactor;
    int h = height/magfactor;

    data->rwidth = width;
    data->rheight = height;
    data->firstDraw = True;
    data->magfactor = magfactor;
    data->buffer = wrealloc(data->buffer, sizeof(unsigned long)*w*h);
    data->width = w;
    data->height = h;
    memset(data->buffer, 0, w*h*sizeof(unsigned long));

    WMResizeWidget(data->label, width, height);

    WMReleasePixmap(data->pixmap);
    data->pixmap = WMCreatePixmap(scr, width, height, WMScreenDepth(scr),
                                  False);
    WMSetLabelImage(data->label, data->pixmap);

    data->d = WMGetPixmapXID(data->pixmap);
}


static int
drawpoint(BufferData *data, unsigned long pixel, int x, int y)
{
    static GC gc = NULL;
    Bool flush = (x < 0);

    if (!flush) {
        if (data->buffer[x+data->width*y] == pixel && !data->firstDraw)
            return 0;

        data->buffer[x+data->width*y] = pixel;
    }
    if (gc == NULL) {
        gc = XCreateGC(dpy, DefaultRootWindow(dpy), 0, NULL);
    }

    if (!flush && data->lastpixel == pixel && data->rectP < rectBufferSize) {
        data->rects[data->rectP].x = x*data->magfactor;
        data->rects[data->rectP].y = y*data->magfactor;
        data->rects[data->rectP].width = data->magfactor;
        data->rects[data->rectP].height = data->magfactor;
        data->rectP++;

        return 0;
    }
    XSetForeground(dpy, gc, data->lastpixel);
    XFillRectangles(dpy, data->d, gc, data->rects, data->rectP);
    data->rectP = 0;
    data->rects[data->rectP].x = x*data->magfactor;
    data->rects[data->rectP].y = y*data->magfactor;
    data->rects[data->rectP].width = data->magfactor;
    data->rects[data->rectP].height = data->magfactor;
    data->rectP++;

    data->lastpixel = pixel;

    return 1;
}


static inline unsigned long
getpix(XImage *image, int x, int y, int xoffs, int yoffs)
{
    if (x < xoffs || y < yoffs
        || x >= xoffs + image->width || y >= yoffs + image->height) {
        return black;
    }
    return XGetPixel(image, x-xoffs, y-yoffs);
}


static void
updateImage(BufferData *data, int rx, int ry)
{
    int gx, gy, gw, gh;
    int x, y;
    int xoffs, yoffs;
    int changedPixels = 0;
    XImage *image;

    gw = data->width;
    gh = data->height;

    gx = rx - gw/2;
    gy = ry - gh/2;

    xoffs = yoffs = 0;
    if (gx < 0) {
        xoffs = abs(gx);
        gw += gx;
        gx = 0;
    }
    if (gx + gw >= WidthOfScreen(DefaultScreenOfDisplay(vdpy))) {
        gw = WidthOfScreen(DefaultScreenOfDisplay(vdpy)) - gx;
    }
    if (gy < 0) {
        yoffs = abs(gy);
        gh += gy;
        gy = 0;
    }
    if (gy + gh >= HeightOfScreen(DefaultScreenOfDisplay(vdpy))) {
        gh = HeightOfScreen(DefaultScreenOfDisplay(vdpy)) - gy;
    }

    image = XGetImage(vdpy, DefaultRootWindow(vdpy), gx, gy, gw, gh,
                      AllPlanes, ZPixmap);


    for (y = 0; y < data->height; y++) {
        for (x = 0; x < data->width; x++) {
            unsigned long pixel;

            pixel = getpix(image, x, y, xoffs, yoffs);

            if (drawpoint(data, pixel, x, y))
                changedPixels++;
        }
    }
    /* flush the point cache */
    drawpoint(data, 0, -1, -1);

    XDestroyImage(image);

    if (data->markPointerHotspot && !data->frozen) {
        XRectangle rects[4];

        rects[0].x = (data->width/2 - 3)*data->magfactor;
        rects[0].y = (data->height/2)*data->magfactor;
        rects[0].width = 2*data->magfactor;
        rects[0].height = data->magfactor;

        rects[1].x = (data->width/2 + 2)*data->magfactor;
        rects[1].y = (data->height/2)*data->magfactor;
        rects[1].width = 2*data->magfactor;
        rects[1].height = data->magfactor;

        XFillRectangles(dpy, data->d, WMColorGC(cursorColor1), rects, 2);

        rects[2].y = (data->height/2 - 3)*data->magfactor;
        rects[2].x = (data->width/2)*data->magfactor;
        rects[2].height = 2*data->magfactor;
        rects[2].width = data->magfactor;

        rects[3].y = (data->height/2 + 2)*data->magfactor;
        rects[3].x = (data->width/2)*data->magfactor;
        rects[3].height = 2*data->magfactor;
        rects[3].width = data->magfactor;

        XFillRectangles(dpy, data->d, WMColorGC(cursorColor2), rects + 2, 2);
    }

    if (changedPixels > 0) {
        WMRedisplayWidget(data->label);
    }

    data->firstDraw = False;
}


static void
update(void *d)
{
    BufferData *data = (BufferData*)d;
    Window win;
    int rx, ry;
    int bla;
    unsigned ubla;


    if (data->frozen) {
        rx = data->x;
        ry = data->y;
    } else {
        XQueryPointer(dpy, DefaultRootWindow(dpy), &win, &win, &rx, &ry,
                      &bla, &bla, &ubla);
    }
    updateImage(data, rx, ry);

    data->tid = WMAddTimerHandler(data->refreshrate, update, data);
}


void resizedWindow(void *d, WMNotification *notif)
{
    BufferData *data = (BufferData*)d;
    WMView *view = (WMView*)WMGetNotificationObject(notif);
    WMSize size;

    size = WMGetViewSize(view);

    resizeBufferData(data, size.width, size.height, data->magfactor);
}



void closeWindow(WMWidget *w, void *d)
{
    BufferData *data = (BufferData*)d;

    windowCount--;
    if (windowCount == 0) {
        exit(0);
    } else {
        WMDeleteTimerHandler(data->tid);
        WMDestroyWidget(w);
        wfree(data->buffer);
        wfree(data->rects);
        WMReleasePixmap(data->pixmap);
        wfree(data);
    }
}


#if 0
static void
clickHandler(XEvent *event, void *d)
{
    BufferData *data = (BufferData*)d;

    data->win = WMCreateWindow(scr, "setup");
    WMSetWindowTitle(data->win, "Magnify Options");

    data->speed = WMCreateSlider(data->win);

    data->magnify = WMCreateSlider(data->win);



}
#endif


static void
keyHandler(XEvent *event, void *d)
{
    BufferData *data = (BufferData*)d;
    char buf[32];
    KeySym ks;
    WMView *view = WMWidgetView(data->win);
    WMSize size;

    size = WMGetViewSize(view);

    if (XLookupString(&event->xkey, buf, 31, &ks, NULL) > 0) {
        switch (buf[0]) {
        case 'n':
            newWindow(data->magfactor);
            break;
        case 'm':
            data->markPointerHotspot = !data->markPointerHotspot;
            break;
        case 'f':
        case ' ':
            data->frozen = !data->frozen;
            if (data->frozen) {
                data->x = event->xkey.x_root;
                data->y = event->xkey.y_root;
                sprintf(buf, "[Magnify %ix]", data->magfactor);
            } else {
                sprintf(buf, "Magnify %ix", data->magfactor);
            }
            WMSetWindowTitle(data->win, buf);
            break;
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            resizeBufferData(data, size.width, size.height, buf[0]-'0');
            if (data->frozen) {
                sprintf(buf, "[Magnify %ix]", data->magfactor);
            } else {
                sprintf(buf, "Magnify %ix", data->magfactor);
            }
            WMSetWindowTitle(data->win, buf);
            break;
        }
    }
}


static BufferData*
newWindow(int magfactor)
{
    WMWindow *win;
    WMLabel *label;
    BufferData *data;
    char buf[32];

    windowCount++;

    win = WMCreateWindow(scr, "magnify");
    WMResizeWidget(win, 300, 200);
    sprintf(buf, "Magnify %ix", magfactor);
    WMSetWindowTitle(win, buf);
    WMSetViewNotifySizeChanges(WMWidgetView(win), True);

    label = WMCreateLabel(win);
    WMResizeWidget(label, 300, 200);
    WMMoveWidget(label, 0, 0);
    WMSetLabelRelief(label, WRSunken);
    WMSetLabelImagePosition(label, WIPImageOnly);

    data = makeBufferData(win, label, 300, 200, magfactor);

    WMCreateEventHandler(WMWidgetView(win), KeyReleaseMask,
                         keyHandler, data);

    WMAddNotificationObserver(resizedWindow, data,
                              WMViewSizeDidChangeNotification,
                              WMWidgetView(win));

    WMRealizeWidget(win);

    WMMapSubwidgets(win);
    WMMapWidget(win);

    WMSetWindowCloseAction(win, closeWindow, data);
    data->tid = WMAddTimerHandler(refreshrate, update, data);

    return data;
}


int main(int argc, char **argv)
{
    BufferData *data;
    int i;
    char *display = "";
    char *vdisplay = NULL;
    int magfactor = 2;
#if 0
    WMButton *radio, *tradio;
#endif
    WMInitializeApplication("Magnify", &argc, argv);


    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-display")==0) {
            i++;
            if (i >= argc)
                goto help;
            display = argv[i];
        } else if (strcmp(argv[i], "-vdisplay")==0) {
            i++;
            if (i >= argc)
                goto help;
            vdisplay = argv[i];
        } else if (strcmp(argv[i], "-m")==0) {
            i++;
            if (i >= argc)
                goto help;
            magfactor = atoi(argv[i]);
            if (magfactor < 1 || magfactor > 32) {
                printf("%s:invalid magnification factor ``%s''\n", argv[0],
                       argv[i]);
                exit(1);
            }
        } else if (strcmp(argv[i], "-r")==0) {
            i++;
            if (i >= argc)
                goto help;
            refreshrate = atoi(argv[i]);
            if (refreshrate < 1) {
                printf("%s:invalid refresh rate ``%s''\n", argv[0], argv[i]);
                exit(1);
            }
        } else if (strcmp(argv[i], "-h")==0
                   || strcmp(argv[i], "--help")==0) {
            help:

                printf("Syntax: %s [options]\n",
                       argv[0]);
                puts("Options:");
                puts("  -display <display>	display that should be used");
                puts("  -m <number>		change magnification factor (default 2)");
                puts("  -r <number>		change refresh delay, in milliseconds (default 200)");
                puts("Keys:");
                puts("  1,2,3,4,5,6,7,8,9	change the magnification factor");
                puts("  <space>, f		freeze the 'camera', making it magnify only the current\n"
                     "			position");
                puts("  n			create a new window");
                puts("  m			show/hide the pointer hotspot mark");
                exit(0);
        }
    }

    dpy = XOpenDisplay(display);
    if (!dpy) {
        puts("couldnt open display");
        exit(1);
    }

    if (vdisplay) {
        vdpy = XOpenDisplay(vdisplay);
        if (!vdpy) {
            puts("couldnt open display to be viewed");
            exit(1);
        }
    } else {
        vdpy = dpy;
    }

    /* calculate how many rectangles we can send in a trip to the server */
    rectBufferSize = XMaxRequestSize(dpy) - 128;
    rectBufferSize /= sizeof(XRectangle);
    if (rectBufferSize < 1)
        rectBufferSize = 1;

    black = BlackPixel(dpy, DefaultScreen(dpy));

    scr = WMCreateScreen(dpy, 0);

    cursorColor1 = WMCreateNamedColor(scr, "#ff0000", False);
    cursorColor2 = WMCreateNamedColor(scr, "#00ff00", False);

    data = newWindow(magfactor);

    WMScreenMainLoop(scr);

    return 0;
}

