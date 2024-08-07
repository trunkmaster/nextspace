/*
 * Raster graphics library
 *
 * Copyright (c) 1997-2003 Alfredo K. Kojima
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

/*
 * Environment variables:
 *
 * WRASTER_GAMMA <rgamma>/<ggamma>/<bgamma>
 * gamma correction value. Must be  greater than 0
 * Only for PseudoColor visuals.
 *
 * Default:
 * WRASTER_GAMMA 1/1/1
 *
 *
 * If you want a specific value for a screen, append the screen number
 * preceded by a hash to the variable name as in
 * WRASTER_GAMMA#1
 * for screen number 1
 */

#ifndef __WRASTER_WRASTER_H__
#define __WRASTER_WRASTER_H__

/* version of the header for the library */
#define WRASTER_HEADER_VERSION 25

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#ifdef USE_XSHM
#include <X11/extensions/XShm.h>
#endif

/*
 * Define some macro to provide attributes for the compiler
 *
 * These attributes help producing better code and/or detecting bugs, however not all compiler
 * support them as they are not standard. Because we're a public API header, we can't count on
 * autoconf to detect them for us, so we use that #if mechanism and define an internal macro
 * appropriately. Please note that the macro are not considered being part of the public API.
 */
#if __GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 5)
#define __wrlib_deprecated(msg) __attribute__((deprecated(msg)))
#elif __GNUC__ >= 3
#define __wrlib_deprecated(msg) __attribute__((deprecated))
#else
#define __wrlib_deprecated(msg)
#endif

#if __GNUC__ >= 3
/* Apparently introduced in GCC 3.0.x */
/* Function returns newly allocated memory that does not alias any existing variable */
#define __wrlib_nonalias __attribute__((malloc))
#else
#define __wrlib_nonalias
#endif

#if __GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 3)
/* Apparently introduced in GCC 3.3.x */
/* The argument at index #i must not be NULL */
#define __wrlib_nonnull(...) __attribute__((nonnull(__VA_ARGS__)))
#else
#define __wrlib_nonnull(argidx)
#endif

#if __GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 4)
/* Apparently introduced in GCC 3.4.x */
/* The return value of this function *must* be checked/used */
#define __wrlib_useresult __attribute__((warn_unused_result))
#else
#define __wrlib_useresult
#endif

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/* RBestMatchRendering or RDitheredRendering */
#define RC_RenderMode (1 << 0)

/* number of colors per channel for colormap in PseudoColor mode */
#define RC_ColorsPerChannel (1 << 1)

/* do gamma correction */
#define RC_GammaCorrection (1 << 2)

/* visual id to use */
#define RC_VisualID (1 << 3)

/* shared memory usage */
#define RC_UseSharedMemory (1 << 4)

/* use default instead of best visual */
#define RC_DefaultVisual (1 << 5)

/* filter type for smoothed scaling */
#define RC_ScalingFilter (1 << 6)

/* standard colormap usage */
#define RC_StandardColormap (1 << 7)

/* image display modes */
typedef enum { RDitheredRendering = 0, RBestMatchRendering = 1 } RRenderingMode;

/* std colormap usage/creation modes */
typedef enum {
  RUseStdColormap, /* default: fallbacks to RIgnore if there is none defined */
  RCreateStdColormap,
  RIgnoreStdColormap
} RStdColormapMode;

/* smoothed scaling filter types */
typedef enum {
  RBoxFilter,
  RTriangleFilter,
  RBellFilter,
  RBSplineFilter,
  RLanczos3Filter,
  RMitchellFilter
} RScalingFilter;

typedef struct RContextAttributes {
  int flags;
  RRenderingMode render_mode;
  int colors_per_channel; /* for PseudoColor */
  float rgamma;           /* gamma correction for red, */
  float ggamma;           /* green, */
  float bgamma;           /* and blue */
  VisualID visualid;      /* visual ID to use */
  int use_shared_memory;  /* True of False */
  RScalingFilter scaling_filter;
  RStdColormapMode standard_colormap_mode; /* what to do with std cma */
} RContextAttributes;

/*
 * describes a screen in terms of depth, visual, number of colors
 * we can use, if we should do dithering, and what colors to use for
 * dithering.
 */
typedef struct RContext {
  Display *dpy;
  int screen_number;
  Colormap cmap;

  RContextAttributes *attribs;

  GC copy_gc;

  Visual *visual;
  int depth;
  Window drawable; /* window to pass for XCreatePixmap().*/
  /* generally = root */
  int vclass;

  unsigned long black;
  unsigned long white;

  int red_offset; /* only used in 24bpp */
  int green_offset;
  int blue_offset;

  /* only used for pseudocolor and grayscale */

  XStandardColormap *std_rgb_map;  /* standard RGB colormap */
  XStandardColormap *std_gray_map; /* standard grayscale colormap */

  int ncolors;           /* total number of colors we can use */
  XColor *colors;        /* internal colormap */
  unsigned long *pixels; /* RContext->colors[].pixel */

  struct {
    unsigned int use_shared_pixmap  : 1;
    unsigned int optimize_for_speed : 1 __wrlib_deprecated(
        "Flag optimize_for_speed in RContext is not used anymore "
        "and will be removed in future version, please do not use");
  } flags;
} RContext;

typedef struct RColor {
  unsigned char red;
  unsigned char green;
  unsigned char blue;
  unsigned char alpha;
} RColor;

typedef struct RHSVColor {
  unsigned short hue;       /* 0-359 */
  unsigned char saturation; /* 0-255 */
  unsigned char value;      /* 0-255 */
} RHSVColor;

typedef struct RPoint {
  int x, y;
} RPoint;

typedef struct RSegment {
  int x1, y1, x2, y2;
} RSegment;

/* image formats */
enum RImageFormat { RRGBFormat, RRGBAFormat };

/*
 * internal 24bit+alpha image representation
 */
typedef struct RImage {
  unsigned char *data; /* image data RGBA or RGB */
  int width, height;   /* size of the image */
  enum RImageFormat format;
  RColor background; /* background color */
  int refCount;
} RImage;

/*
 * internal wrapper for XImage. Used for shm abstraction
 */
typedef struct RXImage {
  XImage *image;

  /* Private data. Do not access */
#ifdef USE_XSHM
  XShmSegmentInfo info;
  char is_shared;
#endif
} RXImage;

/* note that not all operations are supported in all functions */
typedef enum {
  RClearOperation, /* clear with 0 */
  RCopyOperation,
  RNormalOperation, /* same as combine */
  RAddOperation,
  RSubtractOperation
} RPixelOperation;

typedef enum { RAbsoluteCoordinates = 0, RRelativeCoordinates = 1 } RCoordinatesMode;

enum { RSunkenBevel = -1, RNoBevel = 0, RRaisedBevel = 1 };
/* bw compat */
#define RBEV_SUNKEN RSunkenBevel
/* 1 pixel wide */
#define RBEV_RAISED RRaisedBevel
/* 1 pixel wide on top/left 2 on bottom/right */
#define RBEV_RAISED2 2
/* 2 pixel width */
#define RBEV_RAISED3 3

typedef enum {
  RHorizontalGradient = 2,
  RVerticalGradient = 3,
  RDiagonalGradient = 4
} RGradientStyle;
/* for backwards compatibility */
#define RGRD_HORIZONTAL RHorizontalGradient
#define RGRD_VERTICAL RVerticalGradient
#define RGRD_DIAGONAL RDiagonalGradient

/*
 * How an image can be flipped, for RFlipImage
 *
 * Values are actually bit-mask which can be OR'd
 */
#define RHorizontalFlip 0x0001
#define RVerticalFlip 0x0002

/* error codes */
#define RERR_NONE 0
#define RERR_OPEN 1         /* cant open file */
#define RERR_READ 2         /* error reading from file */
#define RERR_WRITE 3        /* error writing to file */
#define RERR_NOMEMORY 4     /* out of memory */
#define RERR_NOCOLOR 5      /* out of color cells */
#define RERR_BADIMAGEFILE 6 /* image file is corrupted or invalid */
#define RERR_BADFORMAT 7    /* image file format is unknown */
#define RERR_BADINDEX 8     /* no such image index in file */

#define RERR_BADVISUALID 16 /* invalid visual ID requested for context */
#define RERR_STDCMAPFAIL 17 /* failed to created std colormap */

#define RERR_XERROR 127   /* internal X error */
#define RERR_INTERNAL 128 /* should not happen */

/*
 * Cleaning before application exit
 */
void RShutdown(void);

/*
 * Returns a NULL terminated array of strings containing the
 * supported formats, such as: TIFF, XPM, PNG, JPEG, PPM, GIF
 * Do not free the returned data.
 */
char **RSupportedFileFormats(void) __wrlib_useresult;

char *RGetImageFileFormat(const char *file) __wrlib_useresult __wrlib_nonnull(1);

/*
 * Xlib contexts
 */
RContext *RCreateContext(Display *dpy, int screen_number,
                         const RContextAttributes *attribs) __wrlib_useresult __wrlib_nonalias
    __wrlib_nonnull(1);

void RDestroyContext(RContext *context);

Bool RGetClosestXColor(RContext *context, const RColor *color, XColor *retColor)
    __wrlib_nonnull(1, 2, 3);

/*
 * RImage creation
 */
RImage *RCreateImage(unsigned width, unsigned height, int alpha) __wrlib_useresult __wrlib_nonalias;

RImage *RCreateImageFromXImage(RContext *context, XImage *image,
                               XImage *mask) __wrlib_useresult __wrlib_nonalias
    __wrlib_nonnull(1, 2);

RImage *RCreateImageFromDrawable(RContext *context, Drawable drawable,
                                 Pixmap mask) __wrlib_useresult __wrlib_nonalias __wrlib_nonnull(1);

RImage *RLoadImage(RContext *context, const char *file,
                   int index) __wrlib_useresult __wrlib_nonalias __wrlib_nonnull(1, 2);

RImage *RRetainImage(RImage *image);

void RReleaseImage(RImage *image) __wrlib_nonnull(1);

RImage *RGetImageFromXPMData(RContext *context, char **xpmData) __wrlib_useresult __wrlib_nonalias
    __wrlib_nonnull(1, 2);

/*
 * RImage storing
 */
Bool RSaveImage(RImage *image, const char *filename, const char *format) __wrlib_nonnull(1, 2, 3);

Bool RSaveTitledImage(RImage *image, const char *filename, const char *format, char *title)
    __wrlib_nonnull(1, 2, 3);

/*
 * Area manipulation
 */
RImage *RCloneImage(RImage *image) __wrlib_useresult __wrlib_nonalias __wrlib_nonnull(1);

RImage *RGetSubImage(RImage *image, int x, int y, unsigned width,
                     unsigned height) __wrlib_useresult __wrlib_nonalias __wrlib_nonnull(1);

void RCombineImageWithColor(RImage *image, const RColor *color) __wrlib_nonnull(1, 2);

void RCombineImages(RImage *image, RImage *src) __wrlib_nonnull(1, 2);

void RCombineArea(RImage *image, RImage *src, int sx, int sy, unsigned width, unsigned height,
                  int dx, int dy) __wrlib_nonnull(1, 2);

void RCopyArea(RImage *image, RImage *src, int sx, int sy, unsigned width, unsigned height, int dx,
               int dy) __wrlib_nonnull(1, 2);

void RCombineImagesWithOpaqueness(RImage *image, RImage *src, int opaqueness) __wrlib_nonnull(1, 2);

void RCombineAreaWithOpaqueness(RImage *image, RImage *src, int sx, int sy, unsigned width,
                                unsigned height, int dx, int dy, int opaqueness)
    __wrlib_nonnull(1, 2);

void RCombineAlpha(unsigned char *d, unsigned char *s, int s_has_alpha, int width, int height,
                   int dwi, int swi, int opacity) __wrlib_nonnull(1, 2);

RImage *RScaleImage(RImage *image, unsigned new_width,
                    unsigned new_height) __wrlib_useresult __wrlib_nonalias;

RImage *RSmoothScaleImage(RImage *src, unsigned new_width,
                          unsigned new_height) __wrlib_useresult __wrlib_nonalias
    __wrlib_nonnull(1);

RImage *RRotateImage(RImage *image, float angle) __wrlib_useresult __wrlib_nonalias
    __wrlib_nonnull(1);

RImage *RFlipImage(RImage *image, int mode) __wrlib_useresult __wrlib_nonalias;

RImage *RMakeTiledImage(RImage *tile, unsigned width,
                        unsigned height) __wrlib_useresult __wrlib_nonalias __wrlib_nonnull(1);

RImage *RMakeCenteredImage(RImage *image, unsigned width, unsigned height,
                           const RColor *color) __wrlib_useresult __wrlib_nonalias
    __wrlib_nonnull(1, 4);

/*
 * Drawing
 */
Bool RGetPixel(RImage *image, int x, int y, RColor *color) __wrlib_nonnull(1, 4);

void RPutPixel(RImage *image, int x, int y, const RColor *color) __wrlib_nonnull(1, 4);

void ROperatePixel(RImage *image, RPixelOperation operation, int x, int y, const RColor *color)
    __wrlib_nonnull(1, 5);

void RPutPixels(RImage *image, const RPoint *points, int npoints, RCoordinatesMode mode,
                const RColor *color) __wrlib_nonnull(1, 2, 5);

void ROperatePixels(RImage *image, RPixelOperation operation, const RPoint *points, int npoints,
                    RCoordinatesMode mode, const RColor *color) __wrlib_nonnull(1, 3, 6);

int RDrawLine(RImage *image, int x0, int y0, int x1, int y1, const RColor *color)
    __wrlib_nonnull(1, 6);

int ROperateLine(RImage *image, RPixelOperation operation, int x0, int y0, int x1, int y1,
                 const RColor *color) __wrlib_nonnull(1, 7);

void RDrawLines(RImage *image, const RPoint *points, int npoints, RCoordinatesMode mode,
                const RColor *color) __wrlib_nonnull(1, 2, 5);

void ROperateLines(RImage *image, RPixelOperation operation, const RPoint *points, int npoints,
                   RCoordinatesMode mode, const RColor *color) __wrlib_nonnull(1, 3, 6);

void ROperateRectangle(RImage *image, RPixelOperation operation, int x0, int y0, int x1, int y1,
                       const RColor *color) __wrlib_nonnull(1, 7);

void RDrawSegments(RImage *image, const RSegment *segs, int nsegs, const RColor *color)
    __wrlib_nonnull(1, 2, 4);

void ROperateSegments(RImage *image, RPixelOperation operation, const RSegment *segs, int nsegs,
                      const RColor *color) __wrlib_nonnull(1, 3, 5);

/*
 * Color convertion
 */
void RRGBtoHSV(const RColor *color, RHSVColor *hsv) __wrlib_nonnull(1, 2);
void RHSVtoRGB(const RHSVColor *hsv, RColor *rgb) __wrlib_nonnull(1, 2);

/*
 * Painting
 */
void RClearImage(RImage *image, const RColor *color) __wrlib_nonnull(1, 2);

void RLightImage(RImage *image, const RColor *color) __wrlib_nonnull(1, 2);

void RFillImage(RImage *image, const RColor *color) __wrlib_nonnull(1, 2);

void RBevelImage(RImage *image, int bevel_type) __wrlib_nonnull(1);

RImage *RRenderGradient(unsigned width, unsigned height, const RColor *from, const RColor *to,
                        RGradientStyle style) __wrlib_nonalias __wrlib_useresult
    __wrlib_nonnull(3, 4);

RImage *RRenderMultiGradient(unsigned width, unsigned height, RColor **colors,
                             RGradientStyle style) __wrlib_nonalias __wrlib_useresult
    __wrlib_nonnull(3);

RImage *RRenderInterwovenGradient(unsigned width, unsigned height, RColor colors1[2],
                                  int thickness1, RColor colors2[2],
                                  int thickness2) __wrlib_nonalias __wrlib_useresult;

/*
 * Convertion into X Pixmaps
 */
int RConvertImage(RContext *context, RImage *image, Pixmap *pixmap) __wrlib_nonnull(1, 2, 3);

int RConvertImageMask(RContext *context, RImage *image, Pixmap *pixmap, Pixmap *mask, int threshold)
    __wrlib_nonnull(1, 2, 3, 4);

/*
 * misc. utilities
 */
RXImage *RCreateXImage(RContext *context, int depth, unsigned width,
                       unsigned height) __wrlib_nonalias __wrlib_useresult __wrlib_nonnull(1);

RXImage *RGetXImage(RContext *context, Drawable d, int x, int y, unsigned width,
                    unsigned height) __wrlib_nonalias __wrlib_useresult __wrlib_nonnull(1);

void RDestroyXImage(RContext *context, RXImage *ximage) __wrlib_nonnull(1, 2);

void RPutXImage(RContext *context, Drawable d, GC gc, RXImage *ximage, int src_x, int src_y,
                int dest_x, int dest_y, unsigned width, unsigned height) __wrlib_nonnull(1, 3);

/* do not free the returned string! */
const char *RMessageForError(int errorCode) __wrlib_useresult;

int RBlurImage(RImage *image);

/****** Global Variables *******/

extern int RErrorCode;

#ifdef __cplusplus
}
#endif /* __cplusplus */

/*
 * The definitions below are done for internal use only
 * We undef them so users of the library may not misuse them
 */
#undef __wrlib_deprecated
#undef __wrlib_nonalias
#undef __wrlib_nonnull
#undef __wrlib_useresult

#endif
