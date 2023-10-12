/*
 * Copyright © 2003 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

/* Modified by Matthew Hawn. I don't know what to say here so follow what it
   says above. Not that I can really do anything about it
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <sys/poll.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include <getopt.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/extensions/Xcomposite.h>
#include <X11/extensions/Xdamage.h>
#include <X11/extensions/Xrender.h>
#include <X11/extensions/shape.h>

typedef struct _ignore {
  struct _ignore *next;
  unsigned long sequence;
} CMPIgnoreSequence;

typedef struct _win {
  struct _win *next;
  Window id;
  Pixmap pixmap;
  XWindowAttributes a;
  int mode;
  int damaged;
  Damage damage;
  Picture picture;
  Picture alphaPict;
  Picture shadowPict;
  XserverRegion borderSize;
  XserverRegion extents;
  Picture shadow;
  int shadow_dx;
  int shadow_dy;
  int shadow_width;
  int shadow_height;
  unsigned int opacity;
  Atom windowType;
  unsigned long damage_sequence; /* sequence when damage was created */
  Bool shaped;
  XRectangle shape_bounds;

  /* for drawing translucent windows */
  XserverRegion borderClip;
  struct _win *prev_trans;
} CMPWindow;

typedef struct _conv {
  int size;
  double *data;
} conv;

typedef struct _fade {
  struct _fade *next;
  Display *dpy;
  CMPWindow *w;
  double cur;
  double finish;
  double step;
  void (*callback)(Display *dpy, CMPWindow *w, Bool gone);
  Bool gone;
} CMPFade;

static Display *dpy;
static CMPWindow *list;
static CMPFade *fades;
static int scr;
static Window root;
static Picture rootPicture;
static Picture rootBuffer;
static Picture blackPicture;
static Picture transBlackPicture;
static Picture rootTile;
static XserverRegion allDamage;
static Bool clipChanged;
static Bool hasNamePixmap;
static int root_height, root_width;
static CMPIgnoreSequence *ignore_head, **ignore_tail = &ignore_head;
static int xfixes_event, xfixes_error;
static int damage_event, damage_error;
static int composite_event, composite_error;
static int render_event, render_error;
static int xshape_event, xshape_error;
static Bool synchronize;
static int composite_opcode;

/* find these once and be done with it */
static Atom opacityAtom;
static Atom winTypeAtom;
static Atom winDesktopAtom;
static Atom winDockAtom;
static Atom winToolbarAtom;
static Atom winMenuAtom;
static Atom winUtilAtom;
static Atom winSplashAtom;
static Atom winDialogAtom;
static Atom winNormalAtom;

/* opacity property name; sometime soon I'll write up an EWMH spec for it */
#define OPACITY_PROP "_NET_WM_WINDOW_OPACITY"

#define TRANSLUCENT 0xe0000000
#define OPAQUE 0xffffffff

static conv *gaussianMap;

#define WINDOW_SOLID 0
#define WINDOW_TRANS 1
#define WINDOW_ARGB 2

typedef enum _compMode {
  CompSimple,        /* looks like a regular X server */
  CompServerShadows, /* use window alpha for shadow; sharp, but precise */
  CompClientShadows, /* use window extents for shadow, blurred */
} CompMode;

static void determine_mode(Display *dpy, CMPWindow *w);

static double get_window_opacity_value(Display *dpy, CMPWindow *w, double def);

static unsigned int get_window_opacity_property(Display *dpy, CMPWindow *w, unsigned int def);

static XserverRegion window_extents_region(Display *dpy, CMPWindow *w);
static XserverRegion window_border_size(Display *dpy, CMPWindow *w);
    
static void wComposerDiscardEventIgnore(Display *dpy, unsigned long sequence);
static void wComposerSetEventIgnore(Display *dpy, unsigned long sequence);
static int wComposerShouldIgnoreEvent(Display *dpy, unsigned long sequence);

static CompMode compMode = CompSimple;

static int shadowRadius = 12;
static int shadowOffsetX = -15;
static int shadowOffsetY = -15;
static double shadowOpacity = .75;

static Bool fadeWindows = False;
static Bool fadeTrans = False;
static double fade_in_step = 0.028;
static double fade_out_step = 0.03;
static int fade_delta = 10;
static int fade_time = 0;
static Bool excludeDockShadows = False;
static Bool autoRedirect = False;

/* For shadow precomputation */
static int Gsize = -1;
static unsigned char *shadowCorner = NULL;
static unsigned char *shadowTop = NULL;

static int get_time_in_milliseconds(void)
{
  struct timeval tv;

  gettimeofday(&tv, NULL);
  return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

// ----------------------------------------------------------------------------------------------
// Fading
// ----------------------------------------------------------------------------------------------

static CMPFade *find_fade(CMPWindow *w)
{
  CMPFade *f;

  for (f = fades; f; f = f->next) {
    if (f->w == w) {
      return f;
    }
  }
  return NULL;
}

static void dequeue_fade(Display *dpy, CMPFade *f)
{
  CMPFade **prev;

  for (prev = &fades; *prev; prev = &(*prev)->next)
    if (*prev == f) {
      *prev = f->next;
      if (f->callback) {
        (*f->callback)(dpy, f->w, f->gone);
      }
      free(f);
      break;
    }
}

static void cleanup_fade(Display *dpy, CMPWindow *w)
{
  CMPFade *f = find_fade(w);
  if (f) {
    dequeue_fade(dpy, f);
  }
}

static void enqueue_fade(Display *dpy, CMPFade *f)
{
  if (!fades) {
    fade_time = get_time_in_milliseconds() + fade_delta;
  }
  f->next = fades;
  fades = f;
}

static void set_fade(Display *dpy, CMPWindow *w, double start, double finish, double step,
                     void (*callback)(Display *dpy, CMPWindow *w, Bool gone), Bool gone,
                     Bool exec_callback, Bool override)
{
  CMPFade *f;

  f = find_fade(w);
  if (!f) {
    f = malloc(sizeof(CMPFade));
    f->next = NULL;
    f->w = w;
    f->cur = start;
    enqueue_fade(dpy, f);
  } else if (!override) {
    return;
  } else {
    if (exec_callback) {
      if (f->callback) {
        (*f->callback)(dpy, f->w, f->gone);
      }
    }
  }

  if (finish < 0) {
    finish = 0;
  }
  if (finish > 1) {
    finish = 1;
  }
  f->finish = finish;
  if (f->cur < finish) {
    f->step = step;
  } else if (f->cur > finish) {
    f->step = -step;
  }
  f->callback = callback;
  f->gone = gone;
  w->opacity = f->cur * OPAQUE;
  determine_mode(dpy, w);
  if (w->shadow) {
    XRenderFreePicture(dpy, w->shadow);
    w->shadow = None;
    w->extents = window_extents_region(dpy, w);
  }
}

static int fade_timeout(void)
{
  int now;
  int delta;
  if (!fades) {
    return -1;
  }
  now = get_time_in_milliseconds();
  delta = fade_time - now;
  if (delta < 0) {
    delta = 0;
  }
  return delta;
}

static void run_fades(Display *dpy)
{
  int now = get_time_in_milliseconds();
  CMPFade *next = fades;
  int steps;
  Bool need_dequeue;

  if (fade_time - now > 0)
    return;
  steps = 1 + (now - fade_time) / fade_delta;

  while (next) {
    CMPFade *f = next;
    CMPWindow *w = f->w;
    next = f->next;
    f->cur += f->step * steps;
    if (f->cur >= 1) {
      f->cur = 1;
    } else if (f->cur < 0) {
      f->cur = 0;
    }
    w->opacity = f->cur * OPAQUE;
    need_dequeue = False;
    if (f->step > 0) {
      if (f->cur >= f->finish) {
        w->opacity = f->finish * OPAQUE;
        need_dequeue = True;
      }
    } else {
      if (f->cur <= f->finish) {
        w->opacity = f->finish * OPAQUE;
        need_dequeue = True;
      }
    }
    determine_mode(dpy, w);
    if (w->shadow) {
      XRenderFreePicture(dpy, w->shadow);
      w->shadow = None;
      w->extents = window_extents_region(dpy, w);
    }
    /* Must do this last as it might destroy f->w in callbacks */
    if (need_dequeue) {
      dequeue_fade(dpy, f);
    }
  }
  fade_time = now + fade_delta;
}

// ----------------------------------------------------------------------------------------------
// Gaussian blur
// ----------------------------------------------------------------------------------------------
static double gaussian(double r, double x, double y)
{
  return ((1 / (sqrt(2 * M_PI * r))) * exp((-(x * x + y * y)) / (2 * r * r)));
}

static conv *make_gaussian_map(Display *dpy, double r)
{
  conv *c;
  int size = ((int)ceil((r * 3)) + 1) & ~1;
  int center = size / 2;
  int x, y;
  double t;
  double g;

  c = malloc(sizeof(conv) + size * size * sizeof(double));
  c->size = size;
  c->data = (double *)(c + 1);
  t = 0.0;
  for (y = 0; y < size; y++)
    for (x = 0; x < size; x++) {
      g = gaussian(r, (double)(x - center), (double)(y - center));
      t += g;
      c->data[y * size + x] = g;
    }
  for (y = 0; y < size; y++) {
    for (x = 0; x < size; x++) {
      c->data[y * size + x] /= t;
    }
  }
  return c;
}

/*
 * A picture will help
 *
 *	-center   0                width  width+center
 *  -center +-----+-------------------+-----+
 *	    |     |                   |     |
 *	    |     |                   |     |
 *        0 +-----+-------------------+-----+
 *	    |     |                   |     |
 *	    |     |                   |     |
 *	    |     |                   |     |
 *   height +-----+-------------------+-----+
 *	    |     |                   |     |
 * height+  |     |                   |     |
 *  center  +-----+-------------------+-----+
 */

static unsigned char sum_gaussian(conv *map, double opacity, int x, int y, int width, int height)
{
  int fx, fy;
  double *g_line = map->data;
  int g_size = map->size;
  int center = g_size / 2;
  int fx_start, fx_end;
  int fy_start, fy_end;
  double v;

  /*
   * Compute set of filter values which are "in range",
   * that's the set with:
   *	0 <= x + (fx-center) && x + (fx-center) < width &&
   *  0 <= y + (fy-center) && y + (fy-center) < height
   *
   *  0 <= x + (fx - center)	x + fx - center < width
   *  center - x <= fx	fx < width + center - x
   */

  fx_start = center - x;
  if (fx_start < 0) {
    fx_start = 0;
  }
  fx_end = width + center - x;
  if (fx_end > g_size) {
    fx_end = g_size;
  }

  fy_start = center - y;
  if (fy_start < 0) {
    fy_start = 0;
  }
  fy_end = height + center - y;
  if (fy_end > g_size) {
    fy_end = g_size;
  }

  g_line = g_line + fy_start * g_size + fx_start;

  v = 0;
  for (fy = fy_start; fy < fy_end; fy++) {
    double *g_data = g_line;
    g_line += g_size;

    for (fx = fx_start; fx < fx_end; fx++) {
      v += *g_data++;
    }
  }
  if (v > 1) {
    v = 1;
  }

  return ((unsigned char)(v * opacity * 255.0));
}

/* precompute shadow corners and sides to save time for large windows */
static void presum_gaussian(conv *map)
{
  int center = map->size / 2;
  int opacity, x, y;

  Gsize = map->size;

  if (shadowCorner) {
    free(shadowCorner);
  }
  if (shadowTop) {
    free(shadowTop);
  }

  shadowCorner = malloc((Gsize + 1) * (Gsize + 1) * 26);
  shadowTop = malloc((Gsize + 1) * 26);

  for (x = 0; x <= Gsize; x++) {
    shadowTop[25 * (Gsize + 1) + x] =
        sum_gaussian(map, 1, x - center, center, Gsize * 2, Gsize * 2);
    for (opacity = 0; opacity < 25; opacity++) {
      shadowTop[opacity * (Gsize + 1) + x] = shadowTop[25 * (Gsize + 1) + x] * opacity / 25;
    }
    for (y = 0; y <= x; y++) {
      shadowCorner[25 * (Gsize + 1) * (Gsize + 1) + y * (Gsize + 1) + x] =
          sum_gaussian(map, 1, x - center, y - center, Gsize * 2, Gsize * 2);
      shadowCorner[25 * (Gsize + 1) * (Gsize + 1) + x * (Gsize + 1) + y] =
          shadowCorner[25 * (Gsize + 1) * (Gsize + 1) + y * (Gsize + 1) + x];
      for (opacity = 0; opacity < 25; opacity++) {
        shadowCorner[opacity * (Gsize + 1) * (Gsize + 1) + y * (Gsize + 1) + x] =
            shadowCorner[opacity * (Gsize + 1) * (Gsize + 1) + x * (Gsize + 1) + y] =
                shadowCorner[25 * (Gsize + 1) * (Gsize + 1) + y * (Gsize + 1) + x] * opacity / 25;
      }
    }
  }
}

// ----------------------------------------------------------------------------------------------
// Pictures and images
// ----------------------------------------------------------------------------------------------
static XImage *create_shadow_image(Display *dpy, double opacity, int width, int height)
{
  XImage *ximage;
  unsigned char *data;
  int gsize = gaussianMap->size;
  int ylimit, xlimit;
  int swidth = width + gsize;
  int sheight = height + gsize;
  int center = gsize / 2;
  int x, y;
  unsigned char d;
  int x_diff;
  int opacity_int = (int)(opacity * 25);
  data = malloc(swidth * sheight * sizeof(unsigned char));
  if (!data)
    return NULL;
  ximage = XCreateImage(dpy, DefaultVisual(dpy, DefaultScreen(dpy)), 8, ZPixmap, 0, (char *)data,
                        swidth, sheight, 8, swidth * sizeof(unsigned char));
  if (!ximage) {
    free(data);
    return NULL;
  }
  /*
   * Build the gaussian in sections
   */

  /*
   * center (fill the complete data array)
   */
  if (Gsize > 0)
    d = shadowTop[opacity_int * (Gsize + 1) + Gsize];
  else
    d = sum_gaussian(gaussianMap, opacity, center, center, width, height);
  memset(data, d, sheight * swidth);

  /*
   * corners
   */
  ylimit = gsize;
  if (ylimit > sheight / 2) {
    ylimit = (sheight + 1) / 2;
  }
  xlimit = gsize;
  if (xlimit > swidth / 2) {
    xlimit = (swidth + 1) / 2;
  }

  for (y = 0; y < ylimit; y++) {
    for (x = 0; x < xlimit; x++) {
      if (xlimit == Gsize && ylimit == Gsize) {
        d = shadowCorner[opacity_int * (Gsize + 1) * (Gsize + 1) + y * (Gsize + 1) + x];
      } else {
        d = sum_gaussian(gaussianMap, opacity, x - center, y - center, width, height);
      }
      data[y * swidth + x] = d;
      data[(sheight - y - 1) * swidth + x] = d;
      data[(sheight - y - 1) * swidth + (swidth - x - 1)] = d;
      data[y * swidth + (swidth - x - 1)] = d;
    }
  }
  /*
   * top/bottom
   */
  x_diff = swidth - (gsize * 2);
  if (x_diff > 0 && ylimit > 0) {
    for (y = 0; y < ylimit; y++) {
      if (ylimit == Gsize) {
        d = shadowTop[opacity_int * (Gsize + 1) + y];
      } else {
        d = sum_gaussian(gaussianMap, opacity, center, y - center, width, height);
      }
      memset(&data[y * swidth + gsize], d, x_diff);
      memset(&data[(sheight - y - 1) * swidth + gsize], d, x_diff);
    }
  }

  /*
   * sides
   */

  for (x = 0; x < xlimit; x++) {
    if (xlimit == Gsize) {
      d = shadowTop[opacity_int * (Gsize + 1) + x];
    } else {
      d = sum_gaussian(gaussianMap, opacity, x - center, center, width, height);
    }
    for (y = gsize; y < sheight - gsize; y++) {
      data[y * swidth + x] = d;
      data[y * swidth + (swidth - x - 1)] = d;
    }
  }

  return ximage;
}

static Picture create_shadow_picture(Display *dpy, double opacity, Picture alpha_pict,
                                            int width, int height, int *wp, int *hp)
{
  XImage *shadowImage;
  Pixmap shadowPixmap;
  Picture shadowPicture;
  GC gc;

  shadowImage = create_shadow_image(dpy, opacity, width, height);
  if (!shadowImage) {
    return None;
  }
  shadowPixmap = XCreatePixmap(dpy, root, shadowImage->width, shadowImage->height, 8);
  if (!shadowPixmap) {
    XDestroyImage(shadowImage);
    return None;
  }

  shadowPicture = XRenderCreatePicture(dpy, shadowPixmap,
                                       XRenderFindStandardFormat(dpy, PictStandardA8), 0, NULL);
  if (!shadowPicture) {
    XDestroyImage(shadowImage);
    XFreePixmap(dpy, shadowPixmap);
    return (Picture)None;
  }

  gc = XCreateGC(dpy, shadowPixmap, 0, NULL);
  if (!gc) {
    XDestroyImage(shadowImage);
    XFreePixmap(dpy, shadowPixmap);
    XRenderFreePicture(dpy, shadowPicture);
    return (Picture)None;
  }

  XPutImage(dpy, shadowPixmap, gc, shadowImage, 0, 0, 0, 0, shadowImage->width,
            shadowImage->height);
  *wp = shadowImage->width;
  *hp = shadowImage->height;
  XFreeGC(dpy, gc);
  XDestroyImage(shadowImage);
  XFreePixmap(dpy, shadowPixmap);
  return shadowPicture;
}

static Picture create_solid_picture(Display *dpy, Bool argb, double a, double r, double g, double b)
{
  Pixmap pixmap;
  Picture picture;
  XRenderPictureAttributes pa;
  XRenderColor c;
  XRenderPictFormat *pictureFormat;

  pixmap = XCreatePixmap(dpy, root, 1, 1, argb ? 32 : 8);
  if (!pixmap) {
    return None;
  }

  pa.repeat = True;
  pictureFormat = XRenderFindStandardFormat(dpy, argb ? PictStandardARGB32 : PictStandardA8);
  picture = XRenderCreatePicture(dpy, pixmap, pictureFormat, CPRepeat, &pa);
  if (!picture) {
    XFreePixmap(dpy, pixmap);
    return None;
  }

  c.alpha = a * 0xffff;
  c.red = r * 0xffff;
  c.green = g * 0xffff;
  c.blue = b * 0xffff;
  XRenderFillRectangle(dpy, PictOpSrc, picture, &c, 0, 0, 1, 1);
  XFreePixmap(dpy, pixmap);

  return picture;
}


static const char *backgroundProps[] = {
    "_XROOTPMAP_ID",
    "_XSETROOT_ID",
    NULL,
};

static Picture root_tile_picture(Display *dpy)
{
  Picture picture;
  Atom actual_type;
  Pixmap pixmap;
  int actual_format;
  unsigned long nitems;
  unsigned long bytes_after;
  unsigned char *prop;
  Bool fill;
  XRenderPictureAttributes pa;
  int p;

  pixmap = None;
  for (p = 0; backgroundProps[p]; p++) {
    if (XGetWindowProperty(dpy, root, XInternAtom(dpy, backgroundProps[p], False), 0, 4, False,
                           AnyPropertyType, &actual_type, &actual_format, &nitems, &bytes_after,
                           &prop) == Success &&
        actual_type == XInternAtom(dpy, "PIXMAP", False) && actual_format == 32 && nitems == 1) {
      memcpy(&pixmap, prop, 4);
      XFree(prop);
      fill = False;
      break;
    }
  }
  if (!pixmap) {
    pixmap = XCreatePixmap(dpy, root, 1, 1, DefaultDepth(dpy, scr));
    fill = True;
  }
  pa.repeat = True;
  picture = XRenderCreatePicture(dpy, pixmap, XRenderFindVisualFormat(dpy, DefaultVisual(dpy, scr)),
                                 CPRepeat, &pa);
  if (fill) {
    XRenderColor c;

    // c.red = c.green = c.blue = 0x8080;
    c.red = c.green = c.blue = 0x6363;
    c.alpha = 0xffff;
    XRenderFillRectangle(dpy, PictOpSrc, picture, &c, 0, 0, 1, 1);
  }
  return picture;
}

static void paint_root_window(Display *dpy)
{
  if (!rootTile) {
    rootTile = root_tile_picture(dpy);
  }

  XRenderComposite(dpy, PictOpSrc, rootTile, None, rootBuffer, 0, 0, 0, 0, 0, 0, root_width,
                   root_height);
}

static void paint_all(Display *dpy, XserverRegion region)
{
  CMPWindow *w;
  CMPWindow *t = NULL;

  if (!region) {
    XRectangle r;
    r.x = 0;
    r.y = 0;
    r.width = root_width;
    r.height = root_height;
    region = XFixesCreateRegion(dpy, &r, 1);
  }
  if (!rootBuffer) {
    Pixmap rootPixmap = XCreatePixmap(dpy, root, root_width, root_height, DefaultDepth(dpy, scr));
    rootBuffer = XRenderCreatePicture(
        dpy, rootPixmap, XRenderFindVisualFormat(dpy, DefaultVisual(dpy, scr)), 0, NULL);
    XFreePixmap(dpy, rootPixmap);
  }
  XFixesSetPictureClipRegion(dpy, rootPicture, 0, 0, region);
  for (w = list; w; w = w->next) {
    /* never painted, ignore it */
    if (!w->damaged) {
      continue;
    }
    /* if invisible, ignore it */
    if (w->a.x + w->a.width < 1 || w->a.y + w->a.height < 1 || w->a.x >= root_width ||
        w->a.y >= root_height) {
      continue;
    }
    if (!w->picture) {
      XRenderPictureAttributes pa;
      XRenderPictFormat *format;
      Drawable draw = w->id;

      if (hasNamePixmap && !w->pixmap) {
        w->pixmap = XCompositeNameWindowPixmap(dpy, w->id);
      }
      if (w->pixmap) {
        draw = w->pixmap;
      }
      format = XRenderFindVisualFormat(dpy, w->a.visual);
      pa.subwindow_mode = IncludeInferiors;
      w->picture = XRenderCreatePicture(dpy, draw, format, CPSubwindowMode, &pa);
    }
    if (clipChanged) {
      if (w->borderSize) {
        wComposerSetEventIgnore(dpy, NextRequest(dpy));
        XFixesDestroyRegion(dpy, w->borderSize);
        w->borderSize = None;
      }
      if (w->extents) {
        XFixesDestroyRegion(dpy, w->extents);
        w->extents = None;
      }
      if (w->borderClip) {
        XFixesDestroyRegion(dpy, w->borderClip);
        w->borderClip = None;
      }
    }
    if (!w->borderSize) {
      w->borderSize = window_border_size(dpy, w);
    }
    if (!w->extents) {
      w->extents = window_extents_region(dpy, w);
    }
    if (w->mode == WINDOW_SOLID) {
      int x, y, wid, hei;
      x = w->a.x;
      y = w->a.y;
      wid = w->a.width + w->a.border_width * 2;
      hei = w->a.height + w->a.border_width * 2;
      XFixesSetPictureClipRegion(dpy, rootBuffer, 0, 0, region);
      wComposerSetEventIgnore(dpy, NextRequest(dpy));
      XFixesSubtractRegion(dpy, region, region, w->borderSize);
      wComposerSetEventIgnore(dpy, NextRequest(dpy));
      XRenderComposite(dpy, PictOpSrc, w->picture, None, rootBuffer, 0, 0, 0, 0, x, y, wid, hei);
    }
    if (!w->borderClip) {
      w->borderClip = XFixesCreateRegion(dpy, NULL, 0);
      XFixesCopyRegion(dpy, w->borderClip, region);
    }
    w->prev_trans = t;
    t = w;
  }
  XFixesSetPictureClipRegion(dpy, rootBuffer, 0, 0, region);
  paint_root_window(dpy);
  for (w = t; w; w = w->prev_trans) {
    XFixesSetPictureClipRegion(dpy, rootBuffer, 0, 0, w->borderClip);
    switch (compMode) {
      case CompSimple:
        break;
      case CompServerShadows:
        /* dont' bother drawing shadows on desktop windows */
        if (w->windowType == winDesktopAtom)
          break;
        wComposerSetEventIgnore(dpy, NextRequest(dpy));
        if (w->opacity != OPAQUE && !w->shadowPict)
          w->shadowPict = create_solid_picture(dpy, True, (double)w->opacity / OPAQUE * 0.3, 0, 0, 0);
        XRenderComposite(dpy, PictOpOver, w->shadowPict ? w->shadowPict : transBlackPicture,
                         w->picture, rootBuffer, 0, 0, 0, 0, w->a.x + w->shadow_dx,
                         w->a.y + w->shadow_dy, w->shadow_width, w->shadow_height);
        break;
      case CompClientShadows:
        /* don't bother drawing shadows on desktop windows */
        if (w->shadow && w->windowType != winDesktopAtom) {
          XRenderComposite(dpy, PictOpOver, blackPicture, w->shadow, rootBuffer, 0, 0, 0, 0,
                           w->a.x + w->shadow_dx, w->a.y + w->shadow_dy, w->shadow_width,
                           w->shadow_height);
        }
        break;
    }
    if (w->opacity != OPAQUE && !w->alphaPict) {
      w->alphaPict = create_solid_picture(dpy, False, (double)w->opacity / OPAQUE, 0, 0, 0);
    }
    if (w->mode == WINDOW_TRANS) {
      int x, y, wid, hei;
      XFixesIntersectRegion(dpy, w->borderClip, w->borderClip, w->borderSize);
      XFixesSetPictureClipRegion(dpy, rootBuffer, 0, 0, w->borderClip);
      x = w->a.x;
      y = w->a.y;
      wid = w->a.width + w->a.border_width * 2;
      hei = w->a.height + w->a.border_width * 2;
      wComposerSetEventIgnore(dpy, NextRequest(dpy));
      XRenderComposite(dpy, PictOpOver, w->picture, w->alphaPict, rootBuffer, 0, 0, 0, 0, x, y, wid,
                       hei);
    } else if (w->mode == WINDOW_ARGB) {
      int x, y, wid, hei;
      XFixesIntersectRegion(dpy, w->borderClip, w->borderClip, w->borderSize);
      XFixesSetPictureClipRegion(dpy, rootBuffer, 0, 0, w->borderClip);
      x = w->a.x;
      y = w->a.y;
      wid = w->a.width + w->a.border_width * 2;
      hei = w->a.height + w->a.border_width * 2;
      wComposerSetEventIgnore(dpy, NextRequest(dpy));
      XRenderComposite(dpy, PictOpOver, w->picture, w->alphaPict, rootBuffer, 0, 0, 0, 0, x, y, wid,
                       hei);
    }
    XFixesDestroyRegion(dpy, w->borderClip);
    w->borderClip = None;
  }
  XFixesDestroyRegion(dpy, region);
  if (rootBuffer != rootPicture) {
    XFixesSetPictureClipRegion(dpy, rootBuffer, 0, 0, None);
    XRenderComposite(dpy, PictOpSrc, rootBuffer, None, rootPicture, 0, 0, 0, 0, 0, 0, root_width,
                     root_height);
  }
}

static void add_damage_region(Display *dpy, XserverRegion damage)
{
  if (allDamage) {
    XFixesUnionRegion(dpy, allDamage, allDamage, damage);
    XFixesDestroyRegion(dpy, damage);
  } else {
    allDamage = damage;
  }
}

// ----------------------------------------------------------------------------------------------
// Windows
// ----------------------------------------------------------------------------------------------
static CMPWindow *find_window(Display *dpy, Window id)
{
  CMPWindow *w;

  for (w = list; w; w = w->next) {
    if (w->id == id) {
      return w;
    }
  }
  return NULL;
}

static XserverRegion window_extents_region(Display *dpy, CMPWindow *w)
{
  XRectangle r;

  r.x = w->a.x;
  r.y = w->a.y;
  r.width = w->a.width + w->a.border_width * 2;
  r.height = w->a.height + w->a.border_width * 2;
  if (compMode != CompSimple && !(w->windowType == winDockAtom && excludeDockShadows)) {
    if (compMode == CompServerShadows || w->mode != WINDOW_ARGB) {
      XRectangle sr;

      if (compMode == CompServerShadows) {
        w->shadow_dx = 2;
        w->shadow_dy = 7;
        w->shadow_width = w->a.width;
        w->shadow_height = w->a.height;
      } else {
        w->shadow_dx = shadowOffsetX;
        w->shadow_dy = shadowOffsetY;
        if (!w->shadow) {
          double opacity = shadowOpacity;
          if (w->mode == WINDOW_TRANS) {
            opacity = opacity * ((double)w->opacity) / ((double)OPAQUE);
          }
          w->shadow = create_shadow_picture(dpy, opacity, w->alphaPict, w->a.width + w->a.border_width * 2,
                                     w->a.height + w->a.border_width * 2, &w->shadow_width,
                                     &w->shadow_height);
        }
      }
      sr.x = w->a.x + w->shadow_dx;
      sr.y = w->a.y + w->shadow_dy;
      sr.width = w->shadow_width;
      sr.height = w->shadow_height;
      if (sr.x < r.x) {
        r.width = (r.x + r.width) - sr.x;
        r.x = sr.x;
      }
      if (sr.y < r.y) {
        r.height = (r.y + r.height) - sr.y;
        r.y = sr.y;
      }
      if (sr.x + sr.width > r.x + r.width) {
        r.width = sr.x + sr.width - r.x;
      }
      if (sr.y + sr.height > r.y + r.height) {
        r.height = sr.y + sr.height - r.y;
      }
    }
  }
  return XFixesCreateRegion(dpy, &r, 1);
}

static XserverRegion window_border_size(Display *dpy, CMPWindow *w)
{
  XserverRegion border;
  /*
   * if window doesn't exist anymore,  this will generate an error
   * as well as not generate a region.  Perhaps a better XFixes
   * architecture would be to have a request that copies instead
   * of creates, that way you'd just end up with an empty region
   * instead of an invalid XID.
   */
  wComposerSetEventIgnore(dpy, NextRequest(dpy));
  border = XFixesCreateRegionFromWindow(dpy, w->id, WindowRegionBounding);
  /* translate this */
  wComposerSetEventIgnore(dpy, NextRequest(dpy));
  XFixesTranslateRegion(dpy, border, w->a.x + w->a.border_width, w->a.y + w->a.border_width);
  return border;
}

static void repair_window(Display *dpy, CMPWindow *w)
{
  XserverRegion parts;

  if (!w->damaged) {
    parts = window_extents_region(dpy, w);
    wComposerSetEventIgnore(dpy, NextRequest(dpy));
    XDamageSubtract(dpy, w->damage, None, None);
  } else {
    parts = XFixesCreateRegion(dpy, NULL, 0);
    wComposerSetEventIgnore(dpy, NextRequest(dpy));
    XDamageSubtract(dpy, w->damage, None, parts);
    XFixesTranslateRegion(dpy, parts, w->a.x + w->a.border_width, w->a.y + w->a.border_width);
    if (compMode == CompServerShadows) {
      XserverRegion o = XFixesCreateRegion(dpy, NULL, 0);
      XFixesCopyRegion(dpy, o, parts);
      XFixesTranslateRegion(dpy, o, w->shadow_dx, w->shadow_dy);
      XFixesUnionRegion(dpy, parts, parts, o);
      XFixesDestroyRegion(dpy, o);
    }
  }
  add_damage_region(dpy, parts);
  w->damaged = 1;
}

static void map_window(Display *dpy, Window id, unsigned long sequence, Bool doFade)
{
  CMPWindow *w = find_window(dpy, id);

  if (!w) {
    return;
  }
  w->a.map_state = IsViewable;

  /* This needs to be here or else we lose transparency messages */
  XSelectInput(dpy, id, PropertyChangeMask);

  /* This needs to be here since we don't get PropertyNotify when unmapped */
  w->opacity = get_window_opacity_property(dpy, w, OPAQUE);
  determine_mode(dpy, w);

  w->damaged = 0;

  if (doFade && fadeWindows) {
    set_fade(dpy, w, 0, get_window_opacity_value(dpy, w, 1.0), fade_in_step, NULL, False, True, True);
  }
}

static void finish_unmap_window(Display *dpy, CMPWindow *w)
{
  w->damaged = 0;
  if (w->extents != None) {
    add_damage_region(dpy, w->extents); /* destroys region */
    w->extents = None;
  }

  if (w->pixmap) {
    XFreePixmap(dpy, w->pixmap);
    w->pixmap = None;
  }

  if (w->picture) {
    wComposerSetEventIgnore(dpy, NextRequest(dpy));
    XRenderFreePicture(dpy, w->picture);
    w->picture = None;
  }

  /* don't care about properties anymore */
  wComposerSetEventIgnore(dpy, NextRequest(dpy));
  XSelectInput(dpy, w->id, 0);

  if (w->borderSize) {
    wComposerSetEventIgnore(dpy, NextRequest(dpy));
    XFixesDestroyRegion(dpy, w->borderSize);
    w->borderSize = None;
  }
  if (w->shadow) {
    XRenderFreePicture(dpy, w->shadow);
    w->shadow = None;
  }
  if (w->borderClip) {
    XFixesDestroyRegion(dpy, w->borderClip);
    w->borderClip = None;
  }

  clipChanged = True;
}

static void unmap_window_callback(Display *dpy, CMPWindow *w, Bool gone)
{
  finish_unmap_window(dpy, w);
}
static void unmap_window(Display *dpy, Window id, Bool doFade)
{
  CMPWindow *w = find_window(dpy, id);
  if (!w) {
    return;
  }
  w->a.map_state = IsUnmapped;
  if (w->pixmap && doFade && fadeWindows) {
    set_fade(dpy, w, w->opacity * 1.0 / OPAQUE, 0.0, fade_out_step, unmap_window_callback, False, False,
             True);
  } else {
    finish_unmap_window(dpy, w);
  }
}

/* Get the opacity prop from window
   not found: default
   otherwise the value
 */
static unsigned int get_window_opacity_property(Display *dpy, CMPWindow *w, unsigned int def)
{
  Atom actual;
  int format;
  unsigned long n, left;

  unsigned char *data;
  int result = XGetWindowProperty(dpy, w->id, opacityAtom, 0L, 1L, False, XA_CARDINAL, &actual,
                                  &format, &n, &left, &data);
  if (result == Success && data != NULL) {
    unsigned int i;
    memcpy(&i, data, sizeof(unsigned int));
    XFree((void *)data);
    return i;
  }
  return def;
}

/* Get the opacity property from the window in a percent format
   not found: default
   otherwise: the value
*/
static double get_window_opacity_value(Display *dpy, CMPWindow *w, double def)
{
  unsigned int opacity = get_window_opacity_property(dpy, w, (unsigned int)(OPAQUE * def));

  return opacity * 1.0 / OPAQUE;
}

/* determine mode for window all in one place.
   Future might check for menu flag and other cool things
*/

static Atom get_window_type_property(Display *dpy, Window w)
{
  Atom actual;
  int format;
  unsigned long n, left;

  unsigned char *data;
  int result = XGetWindowProperty(dpy, w, winTypeAtom, 0L, 1L, False, XA_ATOM, &actual, &format, &n,
                                  &left, &data);

  if (result == Success && data != (unsigned char *)None) {
    Atom a;
    memcpy(&a, data, sizeof(Atom));
    XFree((void *)data);
    return a;
  }
  return winNormalAtom;
}

static void determine_mode(Display *dpy, CMPWindow *w)
{
  int mode;
  XRenderPictFormat *format;

  /* if trans prop == -1 fall back on  previous tests*/

  if (w->alphaPict) {
    XRenderFreePicture(dpy, w->alphaPict);
    w->alphaPict = None;
  }
  if (w->shadowPict) {
    XRenderFreePicture(dpy, w->shadowPict);
    w->shadowPict = None;
  }

  if (w->a.class == InputOnly) {
    format = NULL;
  } else {
    format = XRenderFindVisualFormat(dpy, w->a.visual);
  }

  if (format && format->type == PictTypeDirect && format->direct.alphaMask) {
    mode = WINDOW_ARGB;
  } else if (w->opacity != OPAQUE) {
    mode = WINDOW_TRANS;
  } else {
    mode = WINDOW_SOLID;
  }
  w->mode = mode;
  if (w->extents) {
    XserverRegion damage;
    damage = XFixesCreateRegion(dpy, NULL, 0);
    XFixesCopyRegion(dpy, damage, w->extents);
    add_damage_region(dpy, damage);
  }
}

static Atom get_window_type(Display *dpy, Window w)
{
  Window root_return, parent_return;
  Window *children = NULL;
  unsigned int nchildren;
  Atom type;

  type = get_window_type_property(dpy, w);
  if (type != winNormalAtom)
    return type;

  if (!XQueryTree(dpy, w, &root_return, &parent_return, &children, &nchildren)) {
    /* XQueryTree failed. */
    if (children) {
      XFree((void *)children);
    }
    return winNormalAtom;
  }

  for (unsigned int i = 0; i < nchildren; i++) {
    type = get_window_type(dpy, children[i]);
    if (type != winNormalAtom) {
      return type;
    }
  }

  if (children)
    XFree((void *)children);

  return winNormalAtom;
}

static void add_window(Display *dpy, Window id, Window prev)
{
  CMPWindow *new = malloc(sizeof(CMPWindow));
  CMPWindow **p;

  if (!new)
    return;
  if (prev) {
    for (p = &list; *p; p = &(*p)->next) {
      if ((*p)->id == prev) {
        break;
      }
    }
  } else {
    p = &list;
  }
  new->id = id;
  wComposerSetEventIgnore(dpy, NextRequest(dpy));
  if (!XGetWindowAttributes(dpy, id, &new->a)) {
    free(new);
    return;
  }
  new->shaped = False;
  new->shape_bounds.x = new->a.x;
  new->shape_bounds.y = new->a.y;
  new->shape_bounds.width = new->a.width;
  new->shape_bounds.height = new->a.height;
  new->damaged = 0;
  new->pixmap = None;
  new->picture = None;
  if (new->a.class == InputOnly) {
    new->damage_sequence = 0;
    new->damage = None;
  } else {
    new->damage_sequence = NextRequest(dpy);
    new->damage = XDamageCreate(dpy, id, XDamageReportNonEmpty);
    XShapeSelectInput(dpy, id, ShapeNotifyMask);
  }
  new->alphaPict = None;
  new->shadowPict = None;
  new->borderSize = None;
  new->extents = None;
  new->shadow = None;
  new->shadow_dx = 0;
  new->shadow_dy = 0;
  new->shadow_width = 0;
  new->shadow_height = 0;
  new->opacity = OPAQUE;

  new->borderClip = None;
  new->prev_trans = NULL;

  new->windowType = get_window_type(dpy, new->id);

  new->next = *p;
  *p = new;
  if (new->a.map_state == IsViewable) {
    map_window(dpy, id, new->damage_sequence - 1, True);
  }
}

static void restack_window(Display *dpy, CMPWindow *w, Window new_above)
{
  Window old_above;

  if (w->next) {
    old_above = w->next->id;
  } else {
    old_above = None;
  }
  if (old_above != new_above) {
    CMPWindow **prev;

    /* unhook */
    for (prev = &list; *prev; prev = &(*prev)->next) {
      if ((*prev) == w) {
        break;
      }
    }
    *prev = w->next;

    /* rehook */
    for (prev = &list; *prev; prev = &(*prev)->next) {
      if ((*prev)->id == new_above) {
        break;
      }
    }
    w->next = *prev;
    *prev = w;
  }
}

static void configure_window(Display *dpy, XConfigureEvent *ce)
{
  CMPWindow *w = find_window(dpy, ce->window);
  XserverRegion damage = None;

  if (!w) {
    if (ce->window == root) {
      if (rootBuffer) {
        XRenderFreePicture(dpy, rootBuffer);
        rootBuffer = None;
      }
      root_width = ce->width;
      root_height = ce->height;
    }
    return;
  }
  damage = XFixesCreateRegion(dpy, NULL, 0);
  if (w->extents != None) {
    XFixesCopyRegion(dpy, damage, w->extents);
  }
  w->shape_bounds.x -= w->a.x;
  w->shape_bounds.y -= w->a.y;
  w->a.x = ce->x;
  w->a.y = ce->y;
  if (w->a.width != ce->width || w->a.height != ce->height) {
    if (w->pixmap) {
      XFreePixmap(dpy, w->pixmap);
      w->pixmap = None;
      if (w->picture) {
        XRenderFreePicture(dpy, w->picture);
        w->picture = None;
      }
    }
    if (w->shadow) {
      XRenderFreePicture(dpy, w->shadow);
      w->shadow = None;
    }
  }
  w->a.width = ce->width;
  w->a.height = ce->height;
  w->a.border_width = ce->border_width;
  w->a.override_redirect = ce->override_redirect;
  restack_window(dpy, w, ce->above);
  if (damage) {
    XserverRegion extents = window_extents_region(dpy, w);
    XFixesUnionRegion(dpy, damage, damage, extents);
    XFixesDestroyRegion(dpy, extents);
    add_damage_region(dpy, damage);
  }
  w->shape_bounds.x += w->a.x;
  w->shape_bounds.y += w->a.y;
  if (!w->shaped) {
    w->shape_bounds.width = w->a.width;
    w->shape_bounds.height = w->a.height;
  }

  clipChanged = True;
}

static void circulate_windows(Display *dpy, XCirculateEvent *ce)
{
  CMPWindow *w = find_window(dpy, ce->window);
  Window new_above;

  if (!w) {
    return;
  }
  if (ce->place == PlaceOnTop) {
    new_above = list->id;
  } else {
    new_above = None;
  }
  restack_window(dpy, w, new_above);
  clipChanged = True;
}

static void finish_destroy_window(Display *dpy, Window id, Bool gone)
{
  CMPWindow **prev, *w;

  for (prev = &list; (w = *prev); prev = &w->next) {
    if (w->id == id) {
      if (gone) {
        finish_unmap_window(dpy, w);
      }
      *prev = w->next;
      if (w->picture) {
        wComposerSetEventIgnore(dpy, NextRequest(dpy));
        XRenderFreePicture(dpy, w->picture);
        w->picture = None;
      }
      if (w->alphaPict) {
        XRenderFreePicture(dpy, w->alphaPict);
        w->alphaPict = None;
      }
      if (w->shadowPict) {
        XRenderFreePicture(dpy, w->shadowPict);
        w->shadowPict = None;
      }
      if (w->shadow) {
        XRenderFreePicture(dpy, w->shadow);
        w->shadow = None;
      }
      if (w->damage != None) {
        wComposerSetEventIgnore(dpy, NextRequest(dpy));
        XDamageDestroy(dpy, w->damage);
        w->damage = None;
      }
      cleanup_fade(dpy, w);
      free(w);
      break;
    }
  }
}

static void destroy_callback(Display *dpy, CMPWindow *w, Bool gone)
{
  finish_destroy_window(dpy, w->id, gone);
}

static void destroy_window(Display *dpy, Window id, Bool gone, Bool doFade)
{
  CMPWindow *w = find_window(dpy, id);
  if (w && w->pixmap && doFade && fadeWindows) {
    set_fade(dpy, w, w->opacity * 1.0 / OPAQUE, 0.0, fade_out_step, destroy_callback, gone, False,
             True);
  } else {
    finish_destroy_window(dpy, id, gone);
  }
}

// ----------------------------------------------------------------------------------------------
// Events
// ----------------------------------------------------------------------------------------------
static void wComposerDiscardEventIgnore(Display *dpy, unsigned long sequence)
{
  while (ignore_head) {
    if ((long)(sequence - ignore_head->sequence) > 0) {
      CMPIgnoreSequence *next = ignore_head->next;
      free(ignore_head);
      ignore_head = next;
      if (!ignore_head) {
        ignore_tail = &ignore_head;
      }
    } else {
      break;
    }
  }
}

static void wComposerSetEventIgnore(Display *dpy, unsigned long sequence)
{
  CMPIgnoreSequence *i = malloc(sizeof(CMPIgnoreSequence));

  if (!i) {
    return;
  }
  
  i->sequence = sequence;
  i->next = NULL;
  *ignore_tail = i;
  ignore_tail = &i->next;
}

static int wComposerShouldIgnoreEvent(Display *dpy, unsigned long sequence)
{
  wComposerDiscardEventIgnore(dpy, sequence);
  return ignore_head && ignore_head->sequence == sequence;
}

Bool wComposerErrorHandler(Display *dpy, XErrorEvent *ev)
{
  int o;
  const char *name = NULL;
  static char buffer[256];

  if (wComposerShouldIgnoreEvent(dpy, ev->serial)) {
    return True;
  }

  if (ev->request_code == composite_opcode && ev->minor_code == X_CompositeRedirectSubwindows) {
    fprintf(stderr, "Another composite manager is already running\n");
    return False;
  }

  o = ev->error_code - xfixes_error;
  switch (o) {
    case BadRegion:
      name = "BadRegion";
      break;
    default:
      break;
  }
  o = ev->error_code - damage_error;
  switch (o) {
    case BadDamage:
      name = "BadDamage";
      break;
    default:
      break;
  }
  o = ev->error_code - render_error;
  switch (o) {
    case BadPictFormat:
      name = "BadPictFormat";
      break;
    case BadPicture:
      name = "BadPicture";
      break;
    case BadPictOp:
      name = "BadPictOp";
      break;
    case BadGlyphSet:
      name = "BadGlyphSet";
      break;
    case BadGlyph:
      name = "BadGlyph";
      break;
    default:
      break;
  }

  if (name == NULL) {
    return False;
  } else {
    buffer[0] = '\0';
    XGetErrorText(dpy, ev->error_code, buffer, sizeof(buffer));
    name = buffer;

    fprintf(stderr, "error %d: %s request %d minor %d serial %lu\n", ev->error_code,
            (strlen(name) > 0) ? name : "unknown", ev->request_code, ev->minor_code, ev->serial);
  }

  return True;
}

static void wComposerProcessDamageEvent(Display *dpy, XDamageNotifyEvent *de)
{
  CMPWindow *w = find_window(dpy, de->drawable);

  if (!w) {
    return;
  }
  repair_window(dpy, w);
}

static void wComposerProcessShapeEvent(Display *dpy, XShapeEvent *se)
{
  CMPWindow *w = find_window(dpy, se->window);

  if (!w) {
    return;
  }
  if (se->kind == ShapeClip || se->kind == ShapeBounding) {
    XserverRegion region0;
    XserverRegion region1;

    clipChanged = True;

    region0 = XFixesCreateRegion(dpy, &w->shape_bounds, 1);

    if (se->shaped == True) {
      w->shaped = True;
      w->shape_bounds.x = w->a.x + se->x;
      w->shape_bounds.y = w->a.y + se->y;
      w->shape_bounds.width = se->width;
      w->shape_bounds.height = se->height;
    } else {
      w->shaped = False;
      w->shape_bounds.x = w->a.x;
      w->shape_bounds.y = w->a.y;
      w->shape_bounds.width = w->a.width;
      w->shape_bounds.height = w->a.height;
    }

    region1 = XFixesCreateRegion(dpy, &w->shape_bounds, 1);
    XFixesUnionRegion(dpy, region0, region0, region1);
    XFixesDestroyRegion(dpy, region1);

    /* ask for repaint of the old and new region */
    paint_all(dpy, region0);
  }
}

static XRectangle *expose_rects = NULL;
static int size_expose = 0;
static int n_expose = 0;
static int p;
void wComposerProcessEvent(Display *dpy, XEvent ev)
{
  if (!autoRedirect) {
    switch (ev.type) {
      case CreateNotify:
        add_window(dpy, ev.xcreatewindow.window, 0);
        break;
      case ConfigureNotify:
        configure_window(dpy, &ev.xconfigure);
        break;
      case DestroyNotify:
        destroy_window(dpy, ev.xdestroywindow.window, True, True);
        break;
      case MapNotify:
        map_window(dpy, ev.xmap.window, ev.xmap.serial, True);
        break;
      case UnmapNotify:
        unmap_window(dpy, ev.xunmap.window, True);
        break;
      case ReparentNotify:
        if (ev.xreparent.parent == root) {
          add_window(dpy, ev.xreparent.window, 0);
        } else {
          destroy_window(dpy, ev.xreparent.window, False, True);
        }
        break;
      case CirculateNotify:
        circulate_windows(dpy, &ev.xcirculate);
        break;
      case Expose:
        if (ev.xexpose.window == root) {
          int more = ev.xexpose.count + 1;
          if (n_expose == size_expose) {
            if (expose_rects) {
              expose_rects = realloc(expose_rects, (size_expose + more) * sizeof(XRectangle));
              size_expose += more;
            } else {
              expose_rects = malloc(more * sizeof(XRectangle));
              size_expose = more;
            }
          }
          expose_rects[n_expose].x = ev.xexpose.x;
          expose_rects[n_expose].y = ev.xexpose.y;
          expose_rects[n_expose].width = ev.xexpose.width;
          expose_rects[n_expose].height = ev.xexpose.height;
          n_expose++;
          if (ev.xexpose.count == 0) {
            add_damage_region(dpy, XFixesCreateRegion(dpy, expose_rects, n_expose));
            n_expose = 0;
          }
        }
        break;
      case PropertyNotify:
        for (p = 0; backgroundProps[p]; p++) {
          if (ev.xproperty.atom == XInternAtom(dpy, backgroundProps[p], False)) {
            if (rootTile) {
              XClearArea(dpy, root, 0, 0, 0, 0, True);
              XRenderFreePicture(dpy, rootTile);
              rootTile = None;
              break;
            }
          }
        }
        /* check if Trans property was changed */
        if (ev.xproperty.atom == opacityAtom) {
          /* reset mode and redraw window */
          CMPWindow *w = find_window(dpy, ev.xproperty.window);
          if (w) {
            if (fadeTrans) {
              double start, finish, step;
              start = w->opacity * 1.0 / OPAQUE;
              finish = get_window_opacity_value(dpy, w, 1.0);
              if (start > finish)
                step = fade_in_step;
              else
                step = fade_out_step;
              set_fade(dpy, w, start, finish, step, NULL, False, True, False);
            } else {
              w->opacity = get_window_opacity_property(dpy, w, OPAQUE);
              determine_mode(dpy, w);
              if (w->shadow) {
                XRenderFreePicture(dpy, w->shadow);
                w->shadow = None;
                w->extents = window_extents_region(dpy, w);
              }
            }
          }
        }
        break;
      default:
        if (ev.type == damage_event + XDamageNotify) {
          wComposerProcessDamageEvent(dpy, (XDamageNotifyEvent *)&ev);
        } else if (ev.type == xshape_event + ShapeNotify) {
          wComposerProcessShapeEvent(dpy, (XShapeEvent *)&ev);
        }
        break;
    }
  }
}

#include "core/log_utils.h"
void wComposerRunLoop()
{
  struct pollfd ufd;
  XEvent ev;
  // XRectangle *expose_rects = NULL;
  // int size_expose = 0;
  // int n_expose = 0;
  // int p;

  WMLogError("Composer: Entering runloop with X connection: %i", ConnectionNumber(dpy));

  ufd.fd = ConnectionNumber(dpy);
  ufd.events = POLLIN;
  if (!autoRedirect) {
    paint_all(dpy, None);
  }

  for (;;) {
    do {
      if (autoRedirect) {
        XFlush(dpy);
      }
      if (!QLength(dpy)) {
        if (poll(&ufd, 1, fade_timeout()) == 0) {
          run_fades(dpy);
          break;
        }
      }
      XNextEvent(dpy, &ev);
      if ((ev.type & 0x7f) != KeymapNotify) {
        wComposerDiscardEventIgnore(dpy, ev.xany.serial);
      }
      wComposerProcessEvent(dpy, ev);
      // if (!autoRedirect) {
      //   switch (ev.type) {
      //     case CreateNotify:
      //       wComposerAddWindow(dpy, ev.xcreatewindow.window, 0);
      //       break;
      //     case ConfigureNotify:
      //       wComposerConfigureWindow(dpy, &ev.xconfigure);
      //       break;
      //     case DestroyNotify:
      //       wComposerRemoveWindow(dpy, ev.xdestroywindow.window, True, True);
      //       break;
      //     case MapNotify:
      //       wComposerMapWindow(dpy, ev.xmap.window, ev.xmap.serial, True);
      //       break;
      //     case UnmapNotify:
      //       wComposerUnmapWindow(dpy, ev.xunmap.window, True);
      //       break;
      //     case ReparentNotify:
      //       if (ev.xreparent.parent == root) {
      //         wComposerAddWindow(dpy, ev.xreparent.window, 0);
      //       } else {
      //         wComposerRemoveWindow(dpy, ev.xreparent.window, False, True);
      //       }
      //       break;
      //     case CirculateNotify:
      //       circulate_win(dpy, &ev.xcirculate);
      //       break;
      //     case Expose:
      //       if (ev.xexpose.window == root) {
      //         int more = ev.xexpose.count + 1;
      //         if (n_expose == size_expose) {
      //           if (expose_rects) {
      //             expose_rects = realloc(expose_rects, (size_expose + more) * sizeof(XRectangle));
      //             size_expose += more;
      //           } else {
      //             expose_rects = malloc(more * sizeof(XRectangle));
      //             size_expose = more;
      //           }
      //         }
      //         expose_rects[n_expose].x = ev.xexpose.x;
      //         expose_rects[n_expose].y = ev.xexpose.y;
      //         expose_rects[n_expose].width = ev.xexpose.width;
      //         expose_rects[n_expose].height = ev.xexpose.height;
      //         n_expose++;
      //         if (ev.xexpose.count == 0) {
      //           expose_root(dpy, root, expose_rects, n_expose);
      //           n_expose = 0;
      //         }
      //       }
      //       break;
      //     case PropertyNotify:
      //       for (p = 0; backgroundProps[p]; p++) {
      //         if (ev.xproperty.atom == XInternAtom(dpy, backgroundProps[p], False)) {
      //           if (rootTile) {
      //             XClearArea(dpy, root, 0, 0, 0, 0, True);
      //             XRenderFreePicture(dpy, rootTile);
      //             rootTile = None;
      //             break;
      //           }
      //         }
      //       }
      //       /* check if Trans property was changed */
      //       if (ev.xproperty.atom == opacityAtom) {
      //         /* reset mode and redraw window */
      //         win *w = find_win(dpy, ev.xproperty.window);
      //         if (w) {
      //           if (fadeTrans) {
      //             double start, finish, step;
      //             start = w->opacity * 1.0 / OPAQUE;
      //             finish = get_opacity_percent(dpy, w, 1.0);
      //             if (start > finish)
      //               step = fade_in_step;
      //             else
      //               step = fade_out_step;
      //             set_fade(dpy, w, start, finish, step, NULL, False, True, False);
      //           } else {
      //             w->opacity = get_opacity_prop(dpy, w, OPAQUE);
      //             determine_mode(dpy, w);
      //             if (w->shadow) {
      //               XRenderFreePicture(dpy, w->shadow);
      //               w->shadow = None;
      //               w->extents = win_extents(dpy, w);
      //             }
      //           }
      //         }
      //       }
      //       break;
      //     default:
      //       if (ev.type == damage_event + XDamageNotify) {
      //         wComposerProcessDamageEvent(dpy, (XDamageNotifyEvent *)&ev);
      //       } else if (ev.type == xshape_event + ShapeNotify) {
      //         shape_win(dpy, (XShapeEvent *)&ev);
      //       }
      //       break;
      //   }
      // }
    } while (QLength(dpy));

    if (allDamage && !autoRedirect) {
      static int paint;
      paint_all(dpy, allDamage);
      paint++;
      XSync(dpy, False);
      allDamage = None;
      clipChanged = False;
    }
  }
}

//------------------------------------------------------------------------------------------------
// Composer intialization
//------------------------------------------------------------------------------------------------

static Bool wComposerRegister(Display *dpy)
{
  Window w;
  Atom a;
  static char net_wm_cm[] = "_NET_WM_CM_Sxx";

  snprintf(net_wm_cm, sizeof(net_wm_cm), "_NET_WM_CM_S%d", scr);
  a = XInternAtom(dpy, net_wm_cm, False);

  w = XGetSelectionOwner(dpy, a);
  if (w != None) {
    XTextProperty tp;
    char **strs;
    int count;
    Atom winNameAtom = XInternAtom(dpy, "_NET_WM_NAME", False);

    if (!XGetTextProperty(dpy, w, &tp, winNameAtom) && !XGetTextProperty(dpy, w, &tp, XA_WM_NAME)) {
      fprintf(stderr, "Another composite manager is already running (0x%lx)\n", (unsigned long)w);
      return False;
    }
    if (XmbTextPropertyToTextList(dpy, &tp, &strs, &count) == Success) {
      fprintf(stderr, "Another composite manager is already running (%s)\n", strs[0]);

      XFreeStringList(strs);
    }

    XFree(tp.value);

    return False;
  }

  w = XCreateSimpleWindow(dpy, RootWindow(dpy, scr), 0, 0, 1, 1, 0, None, None);

  Xutf8SetWMProperties(dpy, w, "xcompmgr", "xcompmgr", NULL, 0, NULL, NULL, NULL);

  XSetSelectionOwner(dpy, a, w, 0);

  return True;
}

static void wComposerAtomsCreate(Display *dpy)
{
  opacityAtom = XInternAtom(dpy, OPACITY_PROP, False);
  winTypeAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
  winDesktopAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DESKTOP", False);
  winDockAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);
  winToolbarAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_TOOLBAR", False);
  winMenuAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_MENU", False);
  winUtilAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_UTILITY", False);
  winSplashAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_SPLASH", False);
  winDialogAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DIALOG", False);
  winNormalAtom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_NORMAL", False);
}

static Bool wComposerExtensionsCheck(Display *dpy)
{
  // int composite_major, composite_minor;

  if (!XRenderQueryExtension(dpy, &render_event, &render_error)) {
    fprintf(stderr, "No render extension\n");
    return False;
  }
  if (!XQueryExtension(dpy, COMPOSITE_NAME, &composite_opcode, &composite_event,
                       &composite_error)) {
    fprintf(stderr, "No composite extension\n");
    return False;
  }
  // XCompositeQueryVersion(dpy, &composite_major, &composite_minor);
  hasNamePixmap = True;
  if (!XDamageQueryExtension(dpy, &damage_event, &damage_error)) {
    fprintf(stderr, "No Damage extension\n");
    return False;
  }
  if (!XFixesQueryExtension(dpy, &xfixes_event, &xfixes_error)) {
    fprintf(stderr, "No XFixes extension\n");
    return False;
  }
  if (!XShapeQueryExtension(dpy, &xshape_event, &xshape_error)) {
    fprintf(stderr, "No XShape extension\n");
    return False;
  }

  return True;
}

// int compose_main(int argc, char **argv)
// {
  // Specifies the time between steps in a fade in milliseconds. (default 10)
  //     case 'D':
  //       fade_delta = atoi(optarg);
  //       if (fade_delta < 1) {
  //         fade_delta = 10;
  //       }
  // Specifies the opacity change between steps while fading in. (default 0.028)
  //     case 'I':
  //       fade_in_step = atof(optarg);
  //       if (fade_in_step <= 0) {
  //         fade_in_step = 0.01;
  //       }
  // Specifies the opacity change between steps while fading out. (default 0.03)
  //     case 'O':
  //       fade_out_step = atof(optarg);
  //       if (fade_out_step <= 0) {
  //         fade_out_step = 0.01;
  //       }
  // Draw server-side shadows with sharp edges.
  //     case 's':
  //       compMode = CompServerShadows;
  // Draw client-side shadows with fuzzy edges.
  //     case 'c':
  //       compMode = CompClientShadows;
  // Avoid drawing shadows on dock/panel windows.
  //     case 'C':
  //       excludeDockShadows = True;
  // Normal client-side compositing with transparency support
  //     case 'n':
  //       compMode = CompSimple;
  // Fade windows in/out when opening/closing.
  //     case 'f':
  //       fadeWindows = True;
  // Fade windows during opacity changes.
  //     case 'F':
  //       fadeTrans = True;
  // Use automatic server-side compositing. Faster, but no special effects.
  //     case 'a':
  //       autoRedirect = True;
  // Enable synchronous operation (for debugging).
  //     case 'S':
  //       synchronize = True;
  // Specifies the blur radius for client-side shadows. (default 12)
  //     case 'r':
  //       shadowRadius = atoi(optarg);
  // Specifies the translucency for client-side shadows. (default .75)
  //     case 'o':
  //       shadowOpacity = atof(optarg);
  // Specifies the left offset for client-side shadows. (default -15)
  //     case 'l':
  //       shadowOffsetX = atoi(optarg);
  // Specifies the top offset for clinet-side shadows. (default -15)
  //     case 't':
  //       shadowOffsetY = atoi(optarg);
// }
Bool wComposerInitialize()
{
  // Display *dpy;
  char *display = NULL;
  Window root_return, parent_return;
  Window *children;
  unsigned int nchildren;
  XRenderPictureAttributes pa;

  // True - CompositeRedirectAutomatic
  // False - CompositeRedirectManual
  autoRedirect = False;
  // CompSimple - looks like a regular X server
  // CompServerShadows - use window alpha for shadow; sharp, but precise
  // CompClientShadows - use window extents for shadow, blurred
  compMode = CompSimple;

  dpy = XOpenDisplay(display);
  if (!dpy) {
    fprintf(stderr, "Can't open display\n");
    return False;
  }

  XSetErrorHandler(wComposerErrorHandler);

  if (synchronize) {
    XSynchronize(dpy, 1);
  }
  scr = DefaultScreen(dpy);
  root = RootWindow(dpy, scr);

  if (wComposerExtensionsCheck(dpy) == False) {
    return False;
  }

  if (wComposerRegister(dpy) == False) {
    return False;
  }

  wComposerAtomsCreate(dpy);

  pa.subwindow_mode = IncludeInferiors;

  if (compMode == CompClientShadows) {
    gaussianMap = make_gaussian_map(dpy, shadowRadius);
    presum_gaussian(gaussianMap);
  }

  root_width = DisplayWidth(dpy, scr);
  root_height = DisplayHeight(dpy, scr);

  rootPicture = XRenderCreatePicture(
      dpy, root, XRenderFindVisualFormat(dpy, DefaultVisual(dpy, scr)), CPSubwindowMode, &pa);
  blackPicture = create_solid_picture(dpy, True, 1, 0, 0, 0);
  if (compMode == CompServerShadows) {
    transBlackPicture = create_solid_picture(dpy, True, 0.3, 0, 0, 0);
  }
  allDamage = None;
  clipChanged = True;

  XGrabServer(dpy);
  if (autoRedirect) {
    XCompositeRedirectSubwindows(dpy, root, CompositeRedirectAutomatic);
  } else {
    XCompositeRedirectSubwindows(dpy, root, CompositeRedirectManual);
    XSelectInput(dpy, root,
                 SubstructureNotifyMask | ExposureMask | StructureNotifyMask | PropertyChangeMask);
    XShapeSelectInput(dpy, root, ShapeNotifyMask);
    XQueryTree(dpy, root, &root_return, &parent_return, &children, &nchildren);
    for (unsigned int i = 0; i < nchildren; i++)
      add_window(dpy, children[i], i ? children[i - 1] : None);
    XFree(children);
  }
  XUngrabServer(dpy);

  return True;
}
