/* screen.c - screen management
 *
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#ifdef SHAPE
#include <X11/extensions/shape.h>
#endif

#include <wraster/wraster.h>

#include "WindowMaker.h"
#include "def_pixmaps.h"
#include "screen.h"
#include "texture.h"
#include "pixmap.h"
#include "menu.h"
#include "funcs.h"
#include "actions.h"
#include "properties.h"
#include "dock.h"
#include "resources.h"
#include "workspace.h"
#include "session.h"
#include "balloon.h"
#include "geomview.h"
#ifdef NETWM_HINTS
# include "wmspec.h"
#endif

#include "xinerama.h"

#include <WINGs/WUtil.h>

#include "defaults.h"


#ifdef LITE
#define EVENT_MASK (LeaveWindowMask|EnterWindowMask|PropertyChangeMask\
    |SubstructureNotifyMask|PointerMotionMask \
    |SubstructureRedirectMask|KeyPressMask|KeyReleaseMask)
#else
#define EVENT_MASK (LeaveWindowMask|EnterWindowMask|PropertyChangeMask\
    |SubstructureNotifyMask|PointerMotionMask \
    |SubstructureRedirectMask|ButtonPressMask|ButtonReleaseMask\
    |KeyPressMask|KeyReleaseMask)
#endif

/**** Global variables ****/

extern Cursor wCursor[WCUR_LAST];
extern WPreferences wPreferences;
extern Atom _XA_WINDOWMAKER_STATE;
extern Atom _XA_WINDOWMAKER_NOTICEBOARD;


extern int wScreenCount;

extern WDDomain *WDWindowMaker;


/**** Local ****/

#define STIPPLE_WIDTH 2
#define STIPPLE_HEIGHT 2
static char STIPPLE_DATA[] = {0x02, 0x01};

static int CantManageScreen = 0;

static WMPropList *dApplications = NULL;
static WMPropList *dWorkspace;
static WMPropList *dDock;
static WMPropList *dClip;


static void
make_keys()
{
    if (dApplications!=NULL)
        return;

    dApplications = WMCreatePLString("Applications");
    dWorkspace = WMCreatePLString("Workspace");
    dDock = WMCreatePLString("Dock");
    dClip = WMCreatePLString("Clip");
}


/*
 *----------------------------------------------------------------------
 * alreadyRunningError--
 * 	X error handler used to catch errors when trying to do
 * XSelectInput() on the root window. These errors probably mean that
 * there already is some other window manager running.
 *
 * Returns:
 * 	Nothing, unless something really evil happens...
 *
 * Side effects:
 * 	CantManageScreen is set to 1;
 *----------------------------------------------------------------------
 */
static int
alreadyRunningError(Display *dpy, XErrorEvent *error)
{
    CantManageScreen = 1;
    return -1;
}


/*
 *----------------------------------------------------------------------
 * allocButtonPixmaps--
 * 	Allocate pixmaps used on window operation buttons (those in the
 * titlebar). The pixmaps are linked to the program. If XPM is supported
 * XPM pixmaps are used otherwise, equivalent bitmaps are used.
 *
 * Returns:
 * 	Nothing
 *
 * Side effects:
 * 	Allocates shared pixmaps for the screen. These pixmaps should
 * not be freed by anybody.
 *----------------------------------------------------------------------
 */
static void
allocButtonPixmaps(WScreen *scr)
{
    WPixmap *pix;

    /* create predefined pixmaps */
    pix = wPixmapCreateFromXPMData(scr, PRED_CLOSE_XPM);
    if (pix)
        pix->shared = 1;
    scr->b_pixmaps[WBUT_CLOSE] = pix;

    pix = wPixmapCreateFromXPMData(scr, PRED_BROKEN_CLOSE_XPM);
    if (pix)
        pix->shared = 1;
    scr->b_pixmaps[WBUT_BROKENCLOSE] = pix;

    pix = wPixmapCreateFromXPMData(scr, PRED_ICONIFY_XPM);
    if (pix)
        pix->shared = 1;
    scr->b_pixmaps[WBUT_ICONIFY] = pix;

    pix = wPixmapCreateFromXPMData(scr, PRED_KILL_XPM);
    if (pix)
        pix->shared = 1;
    scr->b_pixmaps[WBUT_KILL] = pix;
}


static void
draw_dot(WScreen *scr, Drawable d, int x, int y, GC gc)
{
    XSetForeground(dpy, gc, scr->black_pixel);
    XDrawLine(dpy, d, gc, x, y, x+1, y);
    XDrawPoint(dpy, d, gc, x, y+1);
    XSetForeground(dpy, gc, scr->white_pixel);
    XDrawLine(dpy, d, gc, x+2, y, x+2, y+1);
    XDrawPoint(dpy, d, gc, x+1, y+1);
}


static WPixmap*
make3Dots(WScreen *scr)
{
    WPixmap *wpix;
    GC gc2, gc;
    XGCValues gcv;
    Pixmap pix, mask;

    gc = scr->copy_gc;
    pix = XCreatePixmap(dpy, scr->w_win, wPreferences.icon_size,
                        wPreferences.icon_size,	scr->w_depth);
    XSetForeground(dpy, gc, scr->black_pixel);
    XFillRectangle(dpy, pix, gc, 0, 0, wPreferences.icon_size,
                   wPreferences.icon_size);
    XSetForeground(dpy, gc, scr->white_pixel);
    draw_dot(scr, pix, 4, wPreferences.icon_size-6, gc);
    draw_dot(scr, pix, 9, wPreferences.icon_size-6, gc);
    draw_dot(scr, pix, 14, wPreferences.icon_size-6, gc);

    mask = XCreatePixmap(dpy, scr->w_win, wPreferences.icon_size,
                         wPreferences.icon_size, 1);
    gcv.foreground = 0;
    gcv.graphics_exposures = False;
    gc2 = XCreateGC(dpy, mask, GCForeground|GCGraphicsExposures, &gcv);
    XFillRectangle(dpy, mask, gc2, 0, 0, wPreferences.icon_size,
                   wPreferences.icon_size);
    XSetForeground(dpy, gc2, 1);
    XFillRectangle(dpy, mask, gc2, 4, wPreferences.icon_size-6, 3, 2);
    XFillRectangle(dpy, mask, gc2, 9, wPreferences.icon_size-6, 3, 2);
    XFillRectangle(dpy, mask, gc2, 14, wPreferences.icon_size-6, 3, 2);

    XFreeGC(dpy, gc2);

    wpix = wPixmapCreate(scr, pix, mask);
    wpix->shared = 1;

    return wpix;
}


static void
allocGCs(WScreen *scr)
{
    XGCValues gcv;
    XColor color;
    int gcm;

    scr->stipple_bitmap =
        XCreateBitmapFromData(dpy, scr->w_win, STIPPLE_DATA, STIPPLE_WIDTH,
                              STIPPLE_HEIGHT);

    gcv.stipple = scr->stipple_bitmap;
    gcv.foreground = scr->white_pixel;
    gcv.fill_style = FillStippled;
    gcv.graphics_exposures = False;
    gcm = GCForeground|GCStipple|GCFillStyle|GCGraphicsExposures;
    scr->stipple_gc = XCreateGC(dpy, scr->w_win, gcm, &gcv);


    /* selected icon border GCs */
    gcv.function    = GXcopy;
    gcv.foreground  = scr->white_pixel;
    gcv.background  = scr->black_pixel;
    gcv.line_width  = 1;
    gcv.line_style  = LineDoubleDash;
    gcv.fill_style  = FillSolid;
    gcv.dash_offset = 0;
    gcv.dashes      = 4;
    gcv.graphics_exposures = False;

    gcm = GCFunction | GCGraphicsExposures;
    gcm |= GCForeground | GCBackground;
    gcm |= GCLineWidth | GCLineStyle;
    gcm |= GCFillStyle;
    gcm |= GCDashOffset | GCDashList;

    scr->icon_select_gc = XCreateGC(dpy, scr->w_win, gcm, &gcv);

    scr->menu_title_color[0] = WMRetainColor(scr->white);

    /* don't retain scr->black here because we may alter its alpha */
    scr->mtext_color = WMCreateRGBColor(scr->wmscreen, 0, 0, 0, True);
    scr->dtext_color = WMCreateRGBColor(scr->wmscreen, 0, 0, 0, True);

    /* frame GC */
    wGetColor(scr, DEF_FRAME_COLOR, &color);
    gcv.function = GXxor;
    /* this will raise the probability of the XORed color being different
     * of the original color in PseudoColor when not all color cells are
     * initialized */
    if (DefaultVisual(dpy, scr->screen)->class==PseudoColor)
        gcv.plane_mask = (1<<(scr->depth-1))|1;
    else
        gcv.plane_mask = AllPlanes;
    gcv.foreground = color.pixel;
    if (gcv.foreground == 0)
        gcv.foreground = 1;
    gcv.line_width = DEF_FRAME_THICKNESS;
    gcv.subwindow_mode = IncludeInferiors;
    gcv.graphics_exposures = False;
    scr->frame_gc = XCreateGC(dpy, scr->root_win, GCForeground|GCGraphicsExposures
                              |GCFunction|GCSubwindowMode|GCLineWidth
                              |GCPlaneMask, &gcv);

    /* line GC */
    gcv.foreground = color.pixel;

    if (gcv.foreground == 0)
        /* XOR:ing with a zero is not going to be of much use, so
         in that case, we somewhat arbitrarily xor with 17 instead. */
        gcv.foreground = 17;

    gcv.function = GXxor;
    gcv.subwindow_mode = IncludeInferiors;
    gcv.line_width = 1;
    gcv.cap_style = CapRound;
    gcv.graphics_exposures = False;
    gcm = GCForeground|GCFunction|GCSubwindowMode|GCLineWidth|GCCapStyle
        |GCGraphicsExposures;
    scr->line_gc = XCreateGC(dpy, scr->root_win, gcm, &gcv);

    scr->line_pixel = gcv.foreground;

    /* copy GC */
    gcv.foreground = scr->white_pixel;
    gcv.background = scr->black_pixel;
    gcv.graphics_exposures = False;
    scr->copy_gc = XCreateGC(dpy, scr->w_win, GCForeground|GCBackground
                             |GCGraphicsExposures, &gcv);

    /* misc drawing GC */
    gcv.graphics_exposures = False;
    gcm = GCGraphicsExposures;
    scr->draw_gc = XCreateGC(dpy, scr->w_win, gcm, &gcv);

    assert (scr->stipple_bitmap!=None);


    /* mono GC */
    scr->mono_gc = XCreateGC(dpy, scr->stipple_bitmap, gcm, &gcv);
}



static void
createPixmaps(WScreen *scr)
{
    WPixmap *pix;
    RImage *image;

    /* load pixmaps */
    pix = wPixmapCreateFromXBMData(scr, (char*)MENU_RADIO_INDICATOR_XBM_DATA,
                                   (char*)MENU_RADIO_INDICATOR_XBM_DATA,
                                   MENU_RADIO_INDICATOR_XBM_SIZE,
                                   MENU_RADIO_INDICATOR_XBM_SIZE,
                                   scr->black_pixel, scr->white_pixel);
    if (pix!=NULL)
        pix->shared = 1;
    scr->menu_radio_indicator = pix;


    pix = wPixmapCreateFromXBMData(scr, (char*)MENU_CHECK_INDICATOR_XBM_DATA,
                                   (char*)MENU_CHECK_INDICATOR_XBM_DATA,
                                   MENU_CHECK_INDICATOR_XBM_SIZE,
                                   MENU_CHECK_INDICATOR_XBM_SIZE,
                                   scr->black_pixel, scr->white_pixel);
    if (pix!=NULL)
        pix->shared = 1;
    scr->menu_check_indicator = pix;

    pix = wPixmapCreateFromXBMData(scr, (char*)MENU_MINI_INDICATOR_XBM_DATA,
                                   (char*)MENU_MINI_INDICATOR_XBM_DATA,
                                   MENU_MINI_INDICATOR_XBM_SIZE,
                                   MENU_MINI_INDICATOR_XBM_SIZE,
                                   scr->black_pixel, scr->white_pixel);
    if (pix!=NULL)
        pix->shared = 1;
    scr->menu_mini_indicator = pix;

    pix = wPixmapCreateFromXBMData(scr, (char*)MENU_HIDE_INDICATOR_XBM_DATA,
                                   (char*)MENU_HIDE_INDICATOR_XBM_DATA,
                                   MENU_HIDE_INDICATOR_XBM_SIZE,
                                   MENU_HIDE_INDICATOR_XBM_SIZE,
                                   scr->black_pixel, scr->white_pixel);
    if (pix!=NULL)
        pix->shared = 1;
    scr->menu_hide_indicator = pix;

    pix = wPixmapCreateFromXBMData(scr, (char*)MENU_SHADE_INDICATOR_XBM_DATA,
                                   (char*)MENU_SHADE_INDICATOR_XBM_DATA,
                                   MENU_SHADE_INDICATOR_XBM_SIZE,
                                   MENU_SHADE_INDICATOR_XBM_SIZE,
                                   scr->black_pixel, scr->white_pixel);
    if (pix!=NULL)
        pix->shared = 1;
    scr->menu_shade_indicator = pix;


    image = wDefaultGetImage(scr, "Logo", "WMPanel");

    if (!image) {
        wwarning(_("could not load logo image for panels: %s"),
                 RMessageForError(RErrorCode));
    } else {
        WMSetApplicationIconImage(scr->wmscreen, image);
        RReleaseImage(image);
    }

    scr->dock_dots = make3Dots(scr);

    /* titlebar button pixmaps */
    allocButtonPixmaps(scr);
}


/*
 *----------------------------------------------------------------------
 * createInternalWindows--
 * 	Creates some windows used internally by the program. One to
 * receive input focus when no other window can get it and another
 * to display window geometry information during window resize/move.
 *
 * Returns:
 * 	Nothing
 *
 * Side effects:
 * 	Windows are created and some colors are allocated for the
 * window background.
 *----------------------------------------------------------------------
 */
static void
createInternalWindows(WScreen *scr)
{
    int vmask;
    XSetWindowAttributes attribs;

    /* InputOnly window to get the focus when no other window can get it */
    vmask = CWEventMask|CWOverrideRedirect;
    attribs.event_mask = KeyPressMask|FocusChangeMask;
    attribs.override_redirect = True;
    scr->no_focus_win=XCreateWindow(dpy,scr->root_win,-10, -10, 4, 4, 0, 0,
                                    InputOnly,CopyFromParent, vmask, &attribs);
    XSelectInput(dpy, scr->no_focus_win, KeyPressMask|KeyReleaseMask);
    XMapWindow(dpy, scr->no_focus_win);

    XSetInputFocus(dpy, scr->no_focus_win, RevertToParent, CurrentTime);

    /* shadow window for dock buttons */
    vmask = CWBorderPixel|CWBackPixmap|CWBackPixel|CWCursor|CWSaveUnder|CWOverrideRedirect;
    attribs.border_pixel = scr->black_pixel;
    attribs.save_under = True;
    attribs.override_redirect = True;
    attribs.background_pixmap = None;
    attribs.background_pixel = scr->white_pixel;
    attribs.cursor = wCursor[WCUR_DEFAULT];
    vmask |= CWColormap;
    attribs.colormap = scr->w_colormap;
    scr->dock_shadow =
        XCreateWindow(dpy, scr->root_win, 0, 0, wPreferences.icon_size,
                      wPreferences.icon_size, 0, scr->w_depth, CopyFromParent,
                      scr->w_visual, vmask, &attribs);

    /* workspace name balloon for clip */
    vmask = CWBackPixel|CWSaveUnder|CWOverrideRedirect|CWColormap
        |CWBorderPixel;
    attribs.save_under = True;
    attribs.override_redirect = True;
    attribs.colormap = scr->w_colormap;
    attribs.background_pixel = scr->icon_back_texture->normal.pixel;
    attribs.border_pixel = 0; /* do not care */
    scr->clip_balloon =
        XCreateWindow(dpy, scr->root_win, 0, 0, 10, 10, 0, scr->w_depth,
                      CopyFromParent, scr->w_visual, vmask, &attribs);


    /* workspace name */
    vmask = CWBackPixel|CWSaveUnder|CWOverrideRedirect|CWColormap
        |CWBorderPixel;
    attribs.save_under = True;
    attribs.override_redirect = True;
    attribs.colormap = scr->w_colormap;
    attribs.background_pixel = scr->icon_back_texture->normal.pixel;
    attribs.border_pixel = 0; /* do not care */
    scr->workspace_name =
        XCreateWindow(dpy, scr->root_win, 0, 0, 10, 10, 0, scr->w_depth,
                      CopyFromParent, scr->w_visual, vmask, &attribs);

    /*
     * If the window is clicked without having ButtonPress selected, the
     * resulting event will have event.xbutton.window == root.
     */
    XSelectInput(dpy, scr->clip_balloon, ButtonPressMask);
}


#if 0
static Bool
aquireManagerSelection(WScreen *scr)
{
    char buffer[32];
    XEvent ev;
    Time timestamp;

    snprintf(buffer, sizeof(buffer), "WM_S%i", scr->screen);
    scr->managerAtom = XInternAtom(dpy, buffer, False);

    /* for race-conditions... */
    XGrabServer(dpy);

    /* if there is another manager running, don't try to replace it
     * (for now, at least) */
    if (XGetSelectionOwner(dpy, scr->managerAtom) != None) {
        XUngrabServer(dpy);
        return False;
    }

    /* become the manager for this screen */

    scr->managerWindow = XCreateSimpleWindow(dpy, scr->root_win, 0, 0, 1, 1,
                                             0, 0, 0);

    XSelectInput(dpy, scr->managerWindow, PropertyChangeMask);
    /* get a timestamp */
    XChangeProperty(dpy, scr->managerWindow, scr->managerAtom,
                    XA_INTEGER, 32, PropModeAppend, NULL, 0);
    while (1) {
        XWindowEvent(dpy, scr->managerWindow, &ev);
        if (ev.type == PropertyNotify) {
            timestamp = ev.xproperty.time;
            break;
        }
    }
    XSelectInput(dpy, scr->managerWindow, NoEvents);
    XDeleteProperty(dpy, scr->managerWindow, scr->managerAtom);

    XSetSelectionOwner(dpy, scr->managerAtom, scr->managerWindow, CurrentTime);

    XUngrabServer(dpy);

    /* announce our arrival */

    ev.xclient.type = ClientMessage;
    ev.xclient.message_type = XInternAtom(dpy, "MANAGER", False);
    ev.xclient.destination = scr->root_win;
    ev.xclient.format = 32;
    ev.xclient.data.l[0] = timestamp;
    ev.xclient.data.l[1] = scr->managerAtom;
    ev.xclient.data.l[2] = scr->managerWindow;
    ev.xclient.data.l[3] = 0;
    ev.xclient.data.l[4] = 0;

    XSendEvent(dpy, scr->root_win, False, StructureNotify, &ev);
    XSync(dpy, False);

    return True;
}
#endif

/*
 *----------------------------------------------------------------------
 * wScreenInit--
 * 	Initializes the window manager for the given screen and
 * allocates a WScreen descriptor for it. Many resources are allocated
 * for the screen and the root window is setup appropriately.
 *
 * Returns:
 * 	The WScreen descriptor for the screen.
 *
 * Side effects:
 * 	Many resources are allocated and the IconSize property is
 * set on the root window.
 *	The program can be aborted if some fatal error occurs.
 *
 * TODO: User specifiable visual.
 *----------------------------------------------------------------------
 */
WScreen*
wScreenInit(int screen_number)
{
    WScreen *scr;
    XIconSize icon_size[1];
    RContextAttributes rattr;
    extern int wVisualID;
    long event_mask;
    XErrorHandler oldHandler;
    int i;

    scr = wmalloc(sizeof(WScreen));
    memset(scr, 0, sizeof(WScreen));

    scr->stacking_list = WMCreateTreeBag();

    /* initialize globals */
    scr->screen = screen_number;
    scr->root_win = RootWindow(dpy, screen_number);
    scr->depth = DefaultDepth(dpy, screen_number);
    scr->colormap = DefaultColormap(dpy, screen_number);

    scr->scr_width = WidthOfScreen(ScreenOfDisplay(dpy, screen_number));
    scr->scr_height = HeightOfScreen(ScreenOfDisplay(dpy, screen_number));

    wInitXinerama(scr);

    scr->usableArea = (WArea *)wmalloc(sizeof(WArea)*wXineramaHeads(scr));
    scr->totalUsableArea = (WArea *)wmalloc(sizeof(WArea)*wXineramaHeads(scr));

    for (i=0; i<wXineramaHeads(scr); ++i) {
        WMRect rect = wGetRectForHead(scr, i);
        scr->usableArea[i].x1 = scr->totalUsableArea[i].x1 = rect.pos.x;
        scr->usableArea[i].y1 = scr->totalUsableArea[i].y1 = rect.pos.y;
        scr->usableArea[i].x2 = scr->totalUsableArea[i].x2 = rect.pos.x + rect.size.width;
        scr->usableArea[i].y2 = scr->totalUsableArea[i].y2 = rect.pos.y + rect.size.height;
    }

    scr->fakeGroupLeaders = WMCreateArray(16);

#if 0
    if (!aquireManagerSelection(scr)) {
        wfree(scr);

        return NULL;
    }
#endif
    CantManageScreen = 0;
    oldHandler = XSetErrorHandler((XErrorHandler)alreadyRunningError);

    event_mask = EVENT_MASK;

//    if (wPreferences.disable_root_mouse) {
        event_mask &= ~(ButtonPressMask|ButtonReleaseMask);
//    }

    XSelectInput(dpy, scr->root_win, event_mask);

    XSync(dpy, False);
    XSetErrorHandler(oldHandler);

    if (CantManageScreen) {
        wfree(scr);
        return NULL;
    }

    XDefineCursor(dpy, scr->root_win, wCursor[WCUR_ROOT]);

    /* screen descriptor for raster graphic library */
    rattr.flags = RC_RenderMode | RC_ColorsPerChannel | RC_StandardColormap;
    rattr.render_mode = wPreferences.no_dithering
        ? RBestMatchRendering
        : RDitheredRendering;

    /* if the std colormap stuff works ok, this will be ignored */
    rattr.colors_per_channel = wPreferences.cmap_size;
    if (rattr.colors_per_channel<2)
        rattr.colors_per_channel = 2;


    /* will only be accounted for in PseudoColor */
    if (wPreferences.flags.create_stdcmap) {
        rattr.standard_colormap_mode = RCreateStdColormap;
    } else {
        rattr.standard_colormap_mode = RUseStdColormap;
    }

    if (wVisualID>=0) {
        rattr.flags |= RC_VisualID;
        rattr.visualid = wVisualID;
    }

    scr->rcontext = RCreateContext(dpy, screen_number, &rattr);

    if (!scr->rcontext && RErrorCode == RERR_STDCMAPFAIL) {
        wwarning(RMessageForError(RErrorCode));

        rattr.flags &= ~RC_StandardColormap;
        rattr.standard_colormap_mode = RUseStdColormap;

        scr->rcontext = RCreateContext(dpy, screen_number, &rattr);
    }

    if (!scr->rcontext) {
        wwarning(_("could not initialize graphics library context: %s"),
                 RMessageForError(RErrorCode));
        wAbort(False);
    } else {
        char **formats;
        int i = 0;

        formats = RSupportedFileFormats();
        if (formats) {
            for (i=0; formats[i]!=NULL; i++) {
                if (strcmp(formats[i], "TIFF")==0) {
                    scr->flags.supports_tiff = 1;
                    break;
                }
            }
        }
    }

    scr->w_win = scr->rcontext->drawable;
    scr->w_visual = scr->rcontext->visual;
    scr->w_depth = scr->rcontext->depth;
    scr->w_colormap = scr->rcontext->cmap;

    /* create screen descriptor for WINGs */
    scr->wmscreen = WMCreateScreenWithRContext(dpy, screen_number,
                                               scr->rcontext);

    if (!scr->wmscreen) {
        wfatal(_("could not initialize WINGs widget set"));
        return NULL;
    }

    scr->black    = WMBlackColor(scr->wmscreen);
    scr->white    = WMWhiteColor(scr->wmscreen);
    scr->gray     = WMGrayColor(scr->wmscreen);
    scr->darkGray = WMDarkGrayColor(scr->wmscreen);

    scr->black_pixel = WMColorPixel(scr->black); /*scr->rcontext->black;*/
    scr->white_pixel = WMColorPixel(scr->white); /*scr->rcontext->white;*/
    scr->light_pixel = WMColorPixel(scr->gray);
    scr->dark_pixel  = WMColorPixel(scr->darkGray);

    {
        XColor xcol;
        /* frame boder color */
        wGetColor(scr, FRAME_BORDER_COLOR, &xcol);
        scr->frame_border_pixel = xcol.pixel;
    }

    /* create GCs with default values */
    allocGCs(scr);

    /* for our window manager info notice board. Need to
     * create before reading the defaults, because it will be used there.
     */
    scr->info_window = XCreateSimpleWindow(dpy, scr->root_win, 0, 0, 10, 10,
                                           0, 0, 0);

    /* read defaults for this screen */
    wReadDefaults(scr, WDWindowMaker->dictionary);

    createInternalWindows(scr);

#ifdef NETWM_HINTS
    wNETWMInitStuff(scr);
#endif

    /* create initial workspace */
    wWorkspaceNew(scr);

    /* create shared pixmaps */
    createPixmaps(scr);

    /* set icon sizes we can accept from clients */
    icon_size[0].min_width = 8;
    icon_size[0].min_height = 8;
    icon_size[0].max_width = wPreferences.icon_size-4;
    icon_size[0].max_height = wPreferences.icon_size-4;
    icon_size[0].width_inc = 1;
    icon_size[0].height_inc = 1;
    XSetIconSizes(dpy, scr->root_win, icon_size, 1);

    /* setup WindowMaker protocols property in the root window*/
    PropSetWMakerProtocols(scr->root_win);

    /* setup our noticeboard */
    XChangeProperty(dpy, scr->info_window, _XA_WINDOWMAKER_NOTICEBOARD,
                    XA_WINDOW, 32, PropModeReplace,
                    (unsigned char*)&scr->info_window, 1);
    XChangeProperty(dpy, scr->root_win, _XA_WINDOWMAKER_NOTICEBOARD,
                    XA_WINDOW, 32, PropModeReplace,
                    (unsigned char*)&scr->info_window, 1);


#ifdef BALLOON_TEXT
    /* initialize balloon text stuff */
    wBalloonInitialize(scr);
#endif

    scr->info_text_font = WMBoldSystemFontOfSize(scr->wmscreen, 12);

    scr->tech_draw_font = XLoadQueryFont(dpy, "-adobe-helvetica-bold-r-*-*-12-*-*-*-*-*-*-*");
    if (!scr->tech_draw_font)
        scr->tech_draw_font = XLoadQueryFont(dpy, "fixed");

    scr->gview = WCreateGeometryView(scr->wmscreen);
    WMRealizeWidget(scr->gview);

    wScreenUpdateUsableArea(scr);

    return scr;
}


void
wScreenUpdateUsableArea(WScreen *scr)
{
    /*
     * scr->totalUsableArea[] will become the usableArea used for Windowplacement,
     * scr->usableArea[] will be used for iconplacement, hence no iconyard nor
     * border.
     */

    int i;
    unsigned long best_area = 0, tmp_area;
    WArea area;
    int dock_head = scr->xine_info.primary_head;

    if (scr->dock) {
        WMRect rect;
        rect.pos.x = scr->dock->x_pos;
        rect.pos.y = scr->dock->y_pos;
        rect.size.width  = wPreferences.icon_size;
        rect.size.height = wPreferences.icon_size;
        dock_head = wGetHeadForRect(scr, rect);
    }

    for (i=0; i<wXineramaHeads(scr); ++i) {
        WMRect rect = wGetRectForHead(scr, i);
        scr->totalUsableArea[i].x1 = rect.pos.x;
        scr->totalUsableArea[i].y1 = rect.pos.y;
        scr->totalUsableArea[i].x2 = rect.pos.x + rect.size.width;
        scr->totalUsableArea[i].y2 = rect.pos.y + rect.size.height;

        if (scr->dock && dock_head==i &&
            (!scr->dock->lowered || wPreferences.no_window_over_dock)) {
            int offset = wPreferences.icon_size + DOCK_EXTRA_SPACE;

            if (scr->dock->on_right_side) {
                scr->totalUsableArea[i].x2 -= offset;
            } else {
                scr->totalUsableArea[i].x1 += offset;
            }
        }

#ifdef NETWM_HINTS
        {
            WArea area;
            if (wNETWMGetUsableArea(scr, i, &area)) {
                scr->totalUsableArea[i].x1 = WMAX(scr->totalUsableArea[i].x1, area.x1);
                scr->totalUsableArea[i].y1 = WMAX(scr->totalUsableArea[i].y1, area.y1);
                scr->totalUsableArea[i].x2 = WMIN(scr->totalUsableArea[i].x2, area.x2);
                scr->totalUsableArea[i].y2 = WMIN(scr->totalUsableArea[i].y2, area.y2);
            }
        }
#endif

        scr->usableArea[i] = scr->totalUsableArea[i];

#if 0
        printf("usableArea[%d]: %d %d %d %d\n", i,
               scr->usableArea[i].x1, scr->usableArea[i].x2,
               scr->usableArea[i].y1, scr->usableArea[i].y2);
#endif

        if (wPreferences.no_window_over_icons) {
            if (wPreferences.icon_yard & IY_VERT) {
                if (wPreferences.icon_yard & IY_RIGHT) {
                    scr->totalUsableArea[i].x2 -= wPreferences.icon_size;
                } else {
                    scr->totalUsableArea[i].x1 += wPreferences.icon_size;
                }
            } else {
                if (wPreferences.icon_yard & IY_TOP) {
                    scr->totalUsableArea[i].y1 += wPreferences.icon_size;
                } else {
                    scr->totalUsableArea[i].y2 -= wPreferences.icon_size;
                }
            }
        }

        if (scr->totalUsableArea[i].x2 - scr->totalUsableArea[i].x1 < rect.size.width/2) {
            scr->totalUsableArea[i].x1 = rect.pos.x;
            scr->totalUsableArea[i].x2 = rect.pos.x + rect.size.width;
        }

        if (scr->totalUsableArea[i].y2 - scr->totalUsableArea[i].y1 < rect.size.height/2) {
            scr->totalUsableArea[i].y1 = rect.pos.y;
            scr->totalUsableArea[i].y2 = rect.pos.y + rect.size.height;
        }

        tmp_area = (scr->totalUsableArea[i].x2 - scr->totalUsableArea[i].x1) *
            (scr->totalUsableArea[i].y2 - scr->totalUsableArea[i].y1);

        if (tmp_area > best_area) {
            best_area = tmp_area;
            area = scr->totalUsableArea[i];
        }

        {
            unsigned size = wPreferences.workspace_border_size;
            unsigned position = wPreferences.workspace_border_position;

            if (size>0 && position!=WB_NONE) {
                if (position & WB_LEFTRIGHT) {
                    scr->totalUsableArea[i].x1 += size;
                    scr->totalUsableArea[i].x2 -= size;
                }
                if (position & WB_TOPBOTTOM) {
                    scr->totalUsableArea[i].y1 += size;
                    scr->totalUsableArea[i].y2 -= size;
                }
            }
        }
    }

#ifdef NETWM_HINTS
    wNETWMUpdateWorkarea(scr, area);
#endif

    if (wPreferences.auto_arrange_icons) {
        wArrangeIcons(scr, True);
    }
}

#if 0
void
wScreenUpdateUsableArea(WScreen *scr)
{
    scr->totalUsableArea = scr->usableArea;

    if (scr->dock && (!scr->dock->lowered
                      || wPreferences.no_window_over_dock)) {

        int offset = wPreferences.icon_size + DOCK_EXTRA_SPACE;

        if (scr->dock->on_right_side) {
            scr->totalUsableArea.x2 = WMIN(scr->totalUsableArea.x2,
                                           scr->scr_width - offset);
        } else {
            scr->totalUsableArea.x1 = WMAX(scr->totalUsableArea.x1, offset);
        }
    }

    if (wPreferences.no_window_over_icons) {
        if (wPreferences.icon_yard & IY_VERT) {

            if (!(wPreferences.icon_yard & IY_RIGHT)) {
                scr->totalUsableArea.x1 += wPreferences.icon_size;
            } else {
                scr->totalUsableArea.x2 -= wPreferences.icon_size;
            }
        } else {

            if (wPreferences.icon_yard & IY_TOP) {
                scr->totalUsableArea.y1 += wPreferences.icon_size;
            } else {
                scr->totalUsableArea.y2 -= wPreferences.icon_size;
            }
        }
    }

#ifdef NETWM_HINTS
    {
        WArea area;
        if (wNETWMGetUsableArea(scr, &area)) {
            scr->totalUsableArea.x1 = WMAX(scr->totalUsableArea.x1, area.x1);
            scr->totalUsableArea.y1 = WMAX(scr->totalUsableArea.y1, area.y1);
            scr->totalUsableArea.x2 = WMIN(scr->totalUsableArea.x2, area.x2);
            scr->totalUsableArea.y2 = WMIN(scr->totalUsableArea.y2, area.y2);
        }
    }
#endif

    if (scr->totalUsableArea.x2 - scr->totalUsableArea.x1 < scr->scr_width/2) {
        scr->totalUsableArea.x2 = scr->usableArea.x2;
        scr->totalUsableArea.x1 = scr->usableArea.x1;
    }
    if (scr->totalUsableArea.y2 - scr->totalUsableArea.y1 < scr->scr_height/2) {
        scr->totalUsableArea.y2 = scr->usableArea.y2;
        scr->totalUsableArea.y1 = scr->usableArea.y1;
    }

#ifdef NETWM_HINTS
    wNETWMUpdateWorkarea(scr);
#endif

    {
        unsigned size = wPreferences.workspace_border_size;
        unsigned position = wPreferences.workspace_border_position;

        if (size>0 && position!=WB_NONE) {
            if (position & WB_LEFTRIGHT) {
                scr->totalUsableArea.x1 += size;
                scr->totalUsableArea.x2 -= size;
            }
            if (position & WB_TOPBOTTOM) {
                scr->totalUsableArea.y1 += size;
                scr->totalUsableArea.y2 -= size;
            }
        }
    }

    if (wPreferences.auto_arrange_icons) {
        wArrangeIcons(scr, True);
    }
}
#endif


void
wScreenRestoreState(WScreen *scr)
{
    WMPropList *state;
    char *path;


#ifndef LITE
    OpenRootMenu(scr, -10000, -10000, False);
    wMenuUnmap(scr->root_menu);
#endif

    make_keys();

    if (wScreenCount == 1) {
        path = wdefaultspathfordomain("WMState");
    } else {
        char buf[16];
        snprintf(buf, sizeof(buf), "WMState.%i", scr->screen);
        path = wdefaultspathfordomain(buf);
    }
    scr->session_state = WMReadPropListFromFile(path);
    wfree(path);
    if (!scr->session_state && wScreenCount>1) {
        path = wdefaultspathfordomain("WMState");
        scr->session_state = WMReadPropListFromFile(path);
        wfree(path);
    }

    if (!scr->session_state) {
        scr->session_state = WMCreatePLDictionary(NULL, NULL);
    }

    if (!wPreferences.flags.nodock) {
        state = WMGetFromPLDictionary(scr->session_state, dDock);
        scr->dock = wDockRestoreState(scr, state, WM_DOCK);
    }

    if (!wPreferences.flags.noclip) {
        state = WMGetFromPLDictionary(scr->session_state, dClip);
        scr->clip_icon = wClipRestoreState(scr, state);
    }

    wWorkspaceRestoreState(scr);

    wScreenUpdateUsableArea(scr);
}


void
wScreenSaveState(WScreen *scr)
{
    WWindow *wwin;
    char *str;
    WMPropList *old_state, *foo;

    make_keys();

    /* save state of windows */
    wwin = scr->focused_window;
    while (wwin) {
        wWindowSaveState(wwin);
        wwin = wwin->prev;
    }


    if (wPreferences.flags.noupdates)
        return;


    old_state = scr->session_state;
    scr->session_state = WMCreatePLDictionary(NULL, NULL);

    WMPLSetCaseSensitive(True);

    /* save dock state to file */
    if (!wPreferences.flags.nodock) {
        wDockSaveState(scr, old_state);
    } else {
        if ((foo = WMGetFromPLDictionary(old_state, dDock))!=NULL) {
            WMPutInPLDictionary(scr->session_state, dDock, foo);
        }
    }
    if (!wPreferences.flags.noclip) {
        wClipSaveState(scr);
    } else {
        if ((foo = WMGetFromPLDictionary(old_state, dClip))!=NULL) {
            WMPutInPLDictionary(scr->session_state, dClip, foo);
        }
    }

    wWorkspaceSaveState(scr, old_state);

    if (wPreferences.save_session_on_exit) {
        wSessionSaveState(scr);
    } else {
        if ((foo = WMGetFromPLDictionary(old_state, dApplications))!=NULL) {
            WMPutInPLDictionary(scr->session_state, dApplications, foo);
        }
        if ((foo = WMGetFromPLDictionary(old_state, dWorkspace))!=NULL) {
            WMPutInPLDictionary(scr->session_state, dWorkspace, foo);
        }
    }

    /* clean up */
    WMPLSetCaseSensitive(False);

    wMenuSaveState(scr);

    if (wScreenCount == 1) {
        str = wdefaultspathfordomain("WMState");
    } else {
        char buf[16];
        snprintf(buf, sizeof(buf), "WMState.%i", scr->screen);
        str = wdefaultspathfordomain(buf);
    }
    if (!WMWritePropListToFile(scr->session_state, str, True)) {
        wsyserror(_("could not save session state in %s"), str);
    }
    wfree(str);
    WMReleasePropList(old_state);
}



int
wScreenBringInside(WScreen *scr, int *x, int *y, int width, int height)
{
    int moved = 0;
    int tol_w, tol_h;
    /*
     * With respect to the head that contains most of the window.
     */
    int sx1, sy1, sx2, sy2;

    WMRect rect;
    int head, flags;

    rect.pos.x = *x;
    rect.pos.y = *y;
    rect.size.width = width;
    rect.size.height = height;

    head = wGetRectPlacementInfo(scr, rect, &flags);
    rect = wGetRectForHead(scr, head);

    sx1 = rect.pos.x;
    sy1 = rect.pos.y;
    sx2 = sx1 + rect.size.width;
    sy2 = sy1 + rect.size.height;

#if 0 /* NOTE: gives funky group movement */
    if (flags & XFLAG_MULTIPLE) {
        /*
         * since we span multiple heads, pull window totaly inside
         */
        if (*x < sx1)
            *x = sx1, moved = 1;
        else if (*x + width > sx2)
            *x = sx2 - width, moved = 1;

        if (*y < sy1)
            *y = sy1, moved = 1;
        else if (*y + height > sy2)
            *y = sy2 - height, moved = 1;

        return moved;
    }
#endif

    if (width > 20)
        tol_w = width/2;
    else
        tol_w = 20;

    if (height > 20)
        tol_h = height/2;
    else
        tol_h = 20;

    if (*x + width < sx1 + 10)
        *x = sx1 - tol_w, moved = 1;
    else if (*x >= sx2 - 10)
        *x = sx2 - tol_w - 1, moved = 1;

    if (*y < sy1 - height + 10)
        *y = sy1 - tol_h, moved = 1;
    else if (*y >= sy2 - 10)
        *y = sy2 - tol_h - 1, moved = 1;

    return moved;
}



int
wScreenKeepInside(WScreen *scr, int *x, int *y, int width, int height)
{
    int moved = 0;
    int sx1, sy1, sx2, sy2;
    WMRect rect;
    int head;

    rect.pos.x = *x;
    rect.pos.y = *y;
    rect.size.width = width;
    rect.size.height = height;

    head = wGetHeadForRect(scr, rect);
    rect = wGetRectForHead(scr, head);

    sx1 = rect.pos.x;
    sy1 = rect.pos.y;
    sx2 = sx1 + rect.size.width;
    sy2 = sy1 + rect.size.height;

    if (*x < sx1)
        *x = sx1, moved = 1;
    else if (*x + width > sx2)
        *x = sx2 - width, moved = 1;

    if (*y < sy1)
        *y = sy1, moved = 1;
    else if (*y + height > sy2)
        *y = sy2 - height, moved = 1;

    return moved;
}


