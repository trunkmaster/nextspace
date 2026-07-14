/** Interface for NSGeometry routines for GNUStep
 * Copyright (C) 1995 Free Software Foundation, Inc.
 * 
 * Written by:  Adam Fedor <fedor@boulder.colorado.edu>
 * Date: 1995,199
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */ 

#ifndef __NSGeometry_h_GNUSTEP_BASE_INCLUDE
#define __NSGeometry_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>
#import	<CoreFoundation/CFCGTypes.h>

#ifdef __OBJC__
#import <objc/objc.h>
#import <Foundation/NSString.h>
#endif

#if	defined(__cplusplus)
extern "C" {
#endif

/**** Type, Constant, and Macro Definitions **********************************/

#ifndef MAX
#define MAX(a,b) \
       ({__typeof__(a) _MAX_a = (a); __typeof__(b) _MAX_b = (b);  \
         _MAX_a > _MAX_b ? _MAX_a : _MAX_b; })
#define	GS_DEFINED_MAX
#endif

#ifndef MIN
#define MIN(a,b) \
       ({__typeof__(a) _MIN_a = (a); __typeof__(b) _MIN_b = (b);  \
         _MIN_a < _MIN_b ? _MIN_a : _MIN_b; })
#define	GS_DEFINED_MIN
#endif

/**
<example>{
  CGFloat x;
  CGFloat y;
}</example>
 <p>Represents a 2-d cartesian position.</p> */
typedef struct CGPoint NSPoint;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/** Array of NSPoint structs. */
typedef NSPoint *NSPointArray;
/** Pointer to NSPoint struct. */
typedef NSPoint *NSPointPointer;
#endif

/**
<example>{
  CGFloat width;
  CGFloat height;
}</example>
 <p>Floating point rectangle size.</p> */
typedef struct CGSize NSSize;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/** Array of NSSize structs. */
typedef NSSize *NSSizeArray;
/** Pointer to NSSize struct. */
typedef NSSize *NSSizePointer;
#endif

/**
<example>{
  NSPoint origin;
  NSSize size;
}</example>

 <p>Rectangle.</p> */
typedef struct CGRect NSRect;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/** Array of NSRect structs. */
typedef NSRect *NSRectArray;
/** Pointer to NSRect struct. */
typedef NSRect *NSRectPointer;
#endif

typedef NS_ENUM(NSUInteger, NSRectEdge)
{
  NSMinXEdge = 0,
  NSMinYEdge = 1,
  NSMaxXEdge = 2,
  NSMaxYEdge = 3
};
/** Sides of a rectangle.
<example>
{
  NSMinXEdge,
  NSMinYEdge,
  NSMaxXEdge,
  NSMaxYEdge
}
</example>
 <p>NSRectEdge</p>*/
// typedef NSUInteger NSRectEdge;
/** A value representing the alignment process
<example>
{
  NSAlignMinXInward,
  NSAlignMinYInward,
  NSAlignMaxXInward,
  NSAlignMaxYInward,
  NSAlignWidthInward,
  NSAlignHeightInward,   
  NSAlignMinXOutward,
  NSAlignMinYOutward,
  NSAlignMaxXOutward,
  NSAlignMaxYOutward,
  NSAlignWidthOutward,
  NSAlignHeightOutward,
  NSAlignMinXNearest,
  NSAlignMinYNearest,
  NSAlignMaxXNearest,
  NSAlignMaxYNearest,
  NSAlignWidthNearest,
  NSAlignHeightNearest,
  NSAlignRectFlipped,
  NSAlignAllEdgesInward,
  NSAlignAllEdgesOutward,
  NSAlignAllEdgesNearest
}
</example>
 <p>NSAlignmentOptions</p>*/
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
typedef NS_ENUM(unsigned long long, NSAlignmentOptions) 
{
  NSAlignMinXInward = 1ULL << 0,
  NSAlignMinYInward = 1ULL << 1,
  NSAlignMaxXInward = 1ULL << 2,
  NSAlignMaxYInward = 1ULL << 3,
  NSAlignWidthInward = 1ULL << 4,
  NSAlignHeightInward = 1ULL << 5,    
  NSAlignMinXOutward = 1ULL << 8,
  NSAlignMinYOutward = 1ULL << 9,
  NSAlignMaxXOutward = 1ULL << 10,
  NSAlignMaxYOutward = 1ULL << 11,
  NSAlignWidthOutward = 1ULL << 12,
  NSAlignHeightOutward = 1ULL << 13,    
  NSAlignMinXNearest = 1ULL << 16,
  NSAlignMinYNearest = 1ULL << 17,
  NSAlignMaxXNearest = 1ULL << 18,
  NSAlignMaxYNearest = 1ULL << 19,
  NSAlignWidthNearest = 1ULL << 20,
  NSAlignHeightNearest = 1ULL << 21,    
  NSAlignRectFlipped = 1ULL << 63,
  NSAlignAllEdgesInward = NSAlignMinXInward
  | NSAlignMaxXInward
  | NSAlignMinYInward
  | NSAlignMaxYInward,
  NSAlignAllEdgesOutward = NSAlignMinXOutward
  | NSAlignMaxXOutward
  | NSAlignMinYOutward
  | NSAlignMaxYOutward,
  NSAlignAllEdgesNearest = NSAlignMinXNearest
  | NSAlignMaxXNearest
  | NSAlignMinYNearest
  | NSAlignMaxYNearest
};
#endif

/**
<example>{
  CGFloat top;
  CGFloat left;
  CGFloat bottom;
  CGFloat right;
}</example>

 <p>A description of the distance between the edges of two rectangles.</p> */
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
typedef struct NSEdgeInsets {
    CGFloat top;
    CGFloat left;
    CGFloat bottom;
    CGFloat right;
} NSEdgeInsets;
#endif

/** Point at 0,0 */
static const NSPoint NSZeroPoint __attribute__((unused)) = {0.0,0.0};
/** Zero-size rectangle at 0,0 */
static const NSRect NSZeroRect __attribute__((unused)) = {{0.0,0.0},{0.0,0.0}};
/** Zero size */
static const NSSize NSZeroSize __attribute__((unused)) = {0.0,0.0};

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
/** Zero edge insets **/
static const NSEdgeInsets NSEdgeInsetsZero __attribute__((unused))  = {0.0,0.0,0.0,0.0};
#endif

/**** Function Prototypes ****************************************************/

/*
 *	All but the most complex functions are declared static inline in this
 *	header file so that they are maximally efficient.  In order to provide
 *	true functions (for code modules that don't have this header) this
 *	header is included in NSGeometry.m where the functions are no longer
 *	declared inline.
 */
#ifdef	IN_NSGEOMETRY_M
#define	GS_GEOM_SCOPE	extern
#define GS_GEOM_ATTR	
#else
#define	GS_GEOM_SCOPE	static inline
#define GS_GEOM_ATTR	__attribute__((unused))
#endif

/** Create Basic Structures... **/

GS_GEOM_SCOPE NSPoint
NSMakePoint(CGFloat x, CGFloat y) GS_GEOM_ATTR;

/** Returns an NSPoint having x-coordinate X and y-coordinate Y. */
GS_GEOM_SCOPE NSPoint
NSMakePoint(CGFloat x, CGFloat y)
{
  NSPoint point;

  point.x = x;
  point.y = y;
  return point;
}

GS_GEOM_SCOPE NSSize
NSMakeSize(CGFloat w, CGFloat h) GS_GEOM_ATTR;

/** Returns an NSSize having width w and height h. */
GS_GEOM_SCOPE NSSize
NSMakeSize(CGFloat w, CGFloat h)
{
  NSSize size;

  size.width = w;
  size.height = h;
  return size;
}

GS_GEOM_SCOPE NSRect
NSMakeRect(CGFloat x, CGFloat y, CGFloat w, CGFloat h) GS_GEOM_ATTR;
    
/** Returns an NSRect having point of origin (x, y) and size {w, h}. */
GS_GEOM_SCOPE NSRect
NSMakeRect(CGFloat x, CGFloat y, CGFloat w, CGFloat h)
{
  NSRect rect;

  rect.origin.x = x;
  rect.origin.y = y;
  rect.size.width = w;
  rect.size.height = h;
  return rect;
}

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
GS_GEOM_SCOPE NSRect
NSRectFromCGRect(CGRect rect) GS_GEOM_ATTR;

/** Return an NSRect from CGRect.  **/
GS_GEOM_SCOPE NSRect
NSRectFromCGRect(CGRect rect)
{
  return (NSRect)rect;
}

GS_GEOM_SCOPE CGRect
NSRectToCGRect(NSRect rect) GS_GEOM_ATTR;

/** Return an CGRect from NSRect.  **/
GS_GEOM_SCOPE CGRect
NSRectToCGRect(NSRect rect)
{
  return (CGRect)rect;
}

GS_GEOM_SCOPE NSPoint
NSPointFromCGPoint(CGPoint point) GS_GEOM_ATTR;

/** Return an NSPoint from CGPoint  **/
GS_GEOM_SCOPE NSPoint
NSPointFromCGPoint(CGPoint point)
{
  return (NSPoint)point;
}

GS_GEOM_SCOPE CGPoint
NSPointToCGPoint(NSPoint point) GS_GEOM_ATTR;

/** Return an CGPoint from NSPoint  **/
GS_GEOM_SCOPE CGPoint
NSPointToCGPoint(NSPoint point)
{
  return (CGPoint)point;
}

GS_GEOM_SCOPE NSSize
NSSizeFromCGSize(CGSize size) GS_GEOM_ATTR;

/** Return an NSSize from CGSize  **/
GS_GEOM_SCOPE NSSize
NSSizeFromCGSize(CGSize size)
{
  return (NSSize)size;
}

GS_GEOM_SCOPE CGSize
NSSizeToCGSize(NSSize size) GS_GEOM_ATTR;

/** Return an CGSize from NSSize  **/
GS_GEOM_SCOPE CGSize
NSSizeToCGSize(NSSize size)
{
  return (CGSize)size;
}  
#endif
  
/** Constructs NSEdgeInsets. **/
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
GS_GEOM_SCOPE NSEdgeInsets
NSEdgeInsetsMake(CGFloat top, CGFloat left,
                 CGFloat bottom, CGFloat right) GS_GEOM_ATTR;

GS_GEOM_SCOPE NSEdgeInsets
NSEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right)
{
  NSEdgeInsets edgeInsets;

  edgeInsets.top = top;
  edgeInsets.left = left;
  edgeInsets.bottom = bottom;
  edgeInsets.right = right;

  return edgeInsets;
}

#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)
/** Compares two edge insets for equality. **/
GS_EXPORT BOOL
NSEdgeInsetsEqual(NSEdgeInsets e1, NSEdgeInsets e2);
#endif

#endif

/** Get a Rectangle's Coordinates... **/

GS_GEOM_SCOPE CGFloat
NSMaxX(NSRect aRect) GS_GEOM_ATTR;

/** Returns the greatest x-coordinate value still inside aRect. */
GS_GEOM_SCOPE CGFloat
NSMaxX(NSRect aRect)
{
  return aRect.origin.x + aRect.size.width;
}

GS_GEOM_SCOPE CGFloat
NSMaxY(NSRect aRect) GS_GEOM_ATTR;

/** Returns the greatest y-coordinate value still inside aRect. */
GS_GEOM_SCOPE CGFloat
NSMaxY(NSRect aRect)
{
  return aRect.origin.y + aRect.size.height;
}

GS_GEOM_SCOPE CGFloat
NSMidX(NSRect aRect) GS_GEOM_ATTR;

/** Returns the x-coordinate of aRect's middle point. */
GS_GEOM_SCOPE CGFloat
NSMidX(NSRect aRect)
{
  return aRect.origin.x + (aRect.size.width / 2.0);
}

GS_GEOM_SCOPE CGFloat
NSMidY(NSRect aRect) GS_GEOM_ATTR;

/** Returns the y-coordinate of aRect's middle point. */
GS_GEOM_SCOPE CGFloat
NSMidY(NSRect aRect)
{
  return aRect.origin.y + (aRect.size.height / 2.0);
}

GS_GEOM_SCOPE CGFloat
NSMinX(NSRect aRect) GS_GEOM_ATTR;

/** Returns the least x-coordinate value still inside aRect. */
GS_GEOM_SCOPE CGFloat
NSMinX(NSRect aRect)
{
  return aRect.origin.x;
}

GS_GEOM_SCOPE CGFloat
NSMinY(NSRect aRect) GS_GEOM_ATTR;

/** Returns the least y-coordinate value still inside aRect. */
GS_GEOM_SCOPE CGFloat
NSMinY(NSRect aRect)
{
  return aRect.origin.y;
}

GS_GEOM_SCOPE CGFloat
NSWidth(NSRect aRect) GS_GEOM_ATTR;

/** Returns aRect's width. */
GS_GEOM_SCOPE CGFloat
NSWidth(NSRect aRect)
{
  return aRect.size.width;
}

GS_GEOM_SCOPE CGFloat
NSHeight(NSRect aRect) GS_GEOM_ATTR;

/** Returns aRect's height. */
GS_GEOM_SCOPE CGFloat
NSHeight(NSRect aRect)
{
  return aRect.size.height;
}

GS_GEOM_SCOPE BOOL
NSIsEmptyRect(NSRect aRect) GS_GEOM_ATTR;

/** Returns 'YES' iff the area of aRect is zero (i.e., iff either
 * of aRect's width or height is negative or zero). */
GS_GEOM_SCOPE BOOL
NSIsEmptyRect(NSRect aRect)
{
  return ((NSWidth(aRect) > 0) && (NSHeight(aRect) > 0)) ? NO : YES;
}

/** Modify a Copy of a Rectangle... **/

GS_GEOM_SCOPE NSRect
NSOffsetRect(NSRect aRect, CGFloat dx, CGFloat dy) GS_GEOM_ATTR;

/** Returns the rectangle obtained by translating aRect
 * horizontally by dx and vertically by dy. */
GS_GEOM_SCOPE NSRect
NSOffsetRect(NSRect aRect, CGFloat dx, CGFloat dy)
{
  NSRect rect = aRect;

  rect.origin.x += dx;
  rect.origin.y += dy;
  return rect;
}

GS_GEOM_SCOPE NSRect
NSInsetRect(NSRect aRect, CGFloat dX, CGFloat dY) GS_GEOM_ATTR;

/** Returns the rectangle obtained by moving each of aRect's
 * horizontal sides inward by dy and each of aRect's vertical
 * sides inward by dx.<br />
 * NB. For MacOS-X compatability, this is permitted to return
 * a rectanglew with nagative width or height, strange as that seems.
 */
GS_GEOM_SCOPE NSRect
NSInsetRect(NSRect aRect, CGFloat dX, CGFloat dY)
{
  NSRect rect;

  rect = NSOffsetRect(aRect, dX, dY);
  rect.size.width -= (2 * dX);
  rect.size.height -= (2 * dY);
  return rect;
}

/** Divides aRect into two rectangles (namely slice and remainder) by
 * "cutting" aRect---parallel to, and a distance amount from the given edge
 * of aRect.  You may pass 0 in as either of slice or
 * remainder to avoid obtaining either of the created rectangles. */
GS_EXPORT void
NSDivideRect(NSRect aRect,
             NSRect *slice,
             NSRect *remainder,
             CGFloat amount,
             NSRectEdge edge);

/** Returns a rectangle obtained by expanding aRect minimally
 * so that all four of its defining components are integers. */
GS_EXPORT NSRect
NSIntegralRect(NSRect aRect);

/** Returns a rectangle obtained by expanding aRect minimally
 * so that all four of its defining components are integers, 
 * using the specified alignment options to control rounding behavior.  */
GS_EXPORT NSRect
NSIntegralRectWithOptions(NSRect aRect, NSAlignmentOptions options);

/** Compute a Third Rectangle from Two Rectangles... **/

GS_GEOM_SCOPE NSRect
NSUnionRect(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

/** Returns the smallest rectangle which contains both aRect
 * and bRect (modulo a set of measure zero).  If either of aRect
 * or bRect is an empty rectangle, then the other rectangle is
 * returned.  If both are empty, then the empty rectangle is returned. */
GS_GEOM_SCOPE NSRect
NSUnionRect(NSRect aRect, NSRect bRect)
{
  NSRect rect;

  if (NSIsEmptyRect(aRect) && NSIsEmptyRect(bRect))
    return NSMakeRect(0.0,0.0,0.0,0.0);
  else if (NSIsEmptyRect(aRect))
    return bRect;
  else if (NSIsEmptyRect(bRect))
    return aRect;

  rect = NSMakeRect(MIN(NSMinX(aRect), NSMinX(bRect)),
                    MIN(NSMinY(aRect), NSMinY(bRect)), 0.0, 0.0);

  rect = NSMakeRect(NSMinX(rect),
                    NSMinY(rect),
                    MAX(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(rect),
                    MAX(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(rect));

  return rect;
}

GS_GEOM_SCOPE NSRect
NSIntersectionRect(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

/** Returns the largest rectangle which lies in both aRect and
 * bRect.  If aRect and bRect have empty intersection (or, rather,
 * intersection of measure zero, since this includes having their
 * intersection be only a point or a line), then the empty
 * rectangle is returned. */
GS_GEOM_SCOPE NSRect
NSIntersectionRect (NSRect aRect, NSRect bRect)
{
  if (NSMaxX(aRect) <= NSMinX(bRect) || NSMaxX(bRect) <= NSMinX(aRect)
    || NSMaxY(aRect) <= NSMinY(bRect) || NSMaxY(bRect) <= NSMinY(aRect)) 
    {
      return NSMakeRect(0.0, 0.0, 0.0, 0.0);
    }
  else
    {
      NSRect    rect;

      if (NSMinX(aRect) <= NSMinX(bRect))
        rect.origin.x = bRect.origin.x;
      else
        rect.origin.x = aRect.origin.x;

      if (NSMinY(aRect) <= NSMinY(bRect))
        rect.origin.y = bRect.origin.y;
      else
        rect.origin.y = aRect.origin.y;

      if (NSMaxX(aRect) >= NSMaxX(bRect))
        rect.size.width = NSMaxX(bRect) - rect.origin.x;
      else
        rect.size.width = NSMaxX(aRect) - rect.origin.x;

      if (NSMaxY(aRect) >= NSMaxY(bRect))
        rect.size.height = NSMaxY(bRect) - rect.origin.y;
      else
        rect.size.height = NSMaxY(aRect) - rect.origin.y;

      return rect;
    }
}

/** Test geometric relationships... **/

/** Returns 'YES' iff aRect's and bRect's origin and size are the same. */
GS_EXPORT BOOL
NSEqualRects(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

/** Returns 'YES' iff aSize's and bSize's width and height are the same. */
GS_EXPORT BOOL
NSEqualSizes(NSSize aSize, NSSize bSize) GS_GEOM_ATTR;

/** Returns 'YES' iff aPoint's and bPoint's x- and y-coordinates
 * are the same. */
GS_EXPORT BOOL
NSEqualPoints(NSPoint aPoint, NSPoint bPoint) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped) GS_GEOM_ATTR;

/** Returns 'YES' iff aPoint is inside aRect. */ 
GS_GEOM_SCOPE BOOL
NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped)
{
  if (flipped)
    {
      return ((aPoint.x >= NSMinX(aRect))
        && (aPoint.y >= NSMinY(aRect))
        && (aPoint.x < NSMaxX(aRect))
        && (aPoint.y < NSMaxY(aRect))) ? YES : NO;
    }
  else
    {
      return ((aPoint.x >= NSMinX(aRect))
        && (aPoint.y > NSMinY(aRect))
        && (aPoint.x < NSMaxX(aRect))
        && (aPoint.y <= NSMaxY(aRect))) ? YES : NO;
    }
}

GS_GEOM_SCOPE BOOL
NSPointInRect(NSPoint aPoint, NSRect aRect) GS_GEOM_ATTR;

/** Just like 'NSMouseInRect(aPoint, aRect, YES)'. */
GS_GEOM_SCOPE BOOL
NSPointInRect(NSPoint aPoint, NSRect aRect)
{
  return NSMouseInRect(aPoint, aRect, YES);
}

GS_GEOM_SCOPE BOOL
NSContainsRect(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

/** Returns 'YES' iff aRect totally encloses bRect.  NOTE: For
 * this to be the case, aRect cannot be empty, nor can any side
 * of bRect go beyond any side of aRect. Note that this behavior
 * is different than the original OpenStep behavior, where the sides
 * of bRect could not touch aRect. */
GS_GEOM_SCOPE BOOL
NSContainsRect(NSRect aRect, NSRect bRect)
{
  return (!NSIsEmptyRect(bRect)
    && (NSMinX(aRect) <= NSMinX(bRect))
    && (NSMinY(aRect) <= NSMinY(bRect))
    && (NSMaxX(aRect) >= NSMaxX(bRect))
    && (NSMaxY(aRect) >= NSMaxY(bRect))) ? YES : NO;
}

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
GS_GEOM_SCOPE BOOL
NSIntersectsRect(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

/** Returns YES if aRect and bRect have non-zero intersection area
    (intersecting at a line or a point doesn't count). */
GS_GEOM_SCOPE BOOL
NSIntersectsRect(NSRect aRect, NSRect bRect)
{
  /* Note that intersecting at a line or a point doesn't count */
  return (NSMaxX(aRect) <= NSMinX(bRect)
    || NSMaxX(bRect) <= NSMinX(aRect)
    || NSMaxY(aRect) <= NSMinY(bRect)
    || NSMaxY(bRect) <= NSMinY(aRect)
    || NSIsEmptyRect(aRect)
    || NSIsEmptyRect(bRect)) ? NO : YES;
}
#endif

/** Get a String Representation... **/

#ifdef __OBJC__
/** Returns an NSString of the form "{x=X; y=Y}", where
 * X and Y are the x- and y-coordinates of aPoint, respectively. */
GS_EXPORT NSString *
NSStringFromPoint(NSPoint aPoint);

/** Returns an NSString of the form "{x=X; y=Y; width=W; height=H}",
 * where X, Y, W, and H are the x-coordinate, y-coordinate,
 * width, and height of aRect, respectively. */
GS_EXPORT NSString *
NSStringFromRect(NSRect aRect);

/** Returns an NSString of the form "{width=W; height=H}", where
 * W and H are the width and height of aSize, respectively. */
GS_EXPORT NSString *
NSStringFromSize(NSSize aSize);

/** Parses point from string of form "<code>{x=a; y=b}</code>". (0,0) returned
    if parsing fails. */
GS_EXPORT NSPoint	NSPointFromString(NSString* string);

/** Parses size from string of form "<code>{width=a; height=b}</code>". Size of
    0,0 returned if parsing fails. */
GS_EXPORT NSSize	NSSizeFromString(NSString* string);

/** Parses point from string of form "<code>{x=a; y=b; width=c;
    height=d}</code>".  Rectangle of 0 size at origin returned if parsing
    fails.
*/
GS_EXPORT NSRect	NSRectFromString(NSString* string);

#endif /* __OBJC__ */

#ifdef	GS_DEFINED_MAX
#undef	GS_DEFINED_MAX
#undef	MAX
#endif

#ifdef	GS_DEFINED_MIN
#undef	GS_DEFINED_MIN
#undef	MIN
#endif

#if	defined(__cplusplus)
}
#endif

#endif /* __NSGeometry_h_GNUSTEP_BASE_INCLUDE */
