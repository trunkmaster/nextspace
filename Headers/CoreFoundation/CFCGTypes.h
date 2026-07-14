/** CFCGTypes.h - CoreFoundation header file for CG types
   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by:  Hugo Melder <hugo@algoriddim.com>
   Created: October 2024

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef _CFCGTypes_h_GNUSTEP_BASE_INCLUDE
#define _CFCGTypes_h_GNUSTEP_BASE_INCLUDE

#include <float.h>
#include <stdint.h>

#define CF_DEFINES_CG_TYPES

#if defined __has_attribute
# if __has_attribute(objc_boxable)
#  define CF_BOXABLE __attribute__((objc_boxable))
# else
#  define CF_BOXABLE
# endif
#else
# define CF_BOXABLE
#endif

 #if (defined(__LP64__) && __LP64__) || defined(_WIN64)
 # define CGFLOAT_TYPE double
 # define CGFLOAT_IS_DOUBLE 1
 # define CGFLOAT_MIN DBL_MIN
 # define CGFLOAT_MAX DBL_MAX
 # define CGFLOAT_EPSILON DBL_EPSILON
 #else
 # define CGFLOAT_TYPE float
 # define CGFLOAT_IS_DOUBLE 0
 # define CGFLOAT_MIN FLT_MIN
 # define CGFLOAT_MAX FLT_MAX
 # define CGFLOAT_EPSILON FLT_EPSILON
 #endif

typedef CGFLOAT_TYPE CGFloat;
#define CGFLOAT_DEFINED 1

struct
CGPoint {
    CGFloat x;
    CGFloat y;
};
typedef struct CF_BOXABLE CGPoint CGPoint;

struct CGSize {
    CGFloat width;
    CGFloat height;
};
typedef struct CF_BOXABLE CGSize CGSize;

#define CGVECTOR_DEFINED 1

struct CGVector {
    CGFloat dx;
    CGFloat dy;
};
typedef struct CF_BOXABLE CGVector CGVector;

struct CGRect {
    CGPoint origin;
    CGSize size;
};
typedef struct CF_BOXABLE CGRect CGRect;

enum
{
  CGRectMinXEdge = 0,
  CGRectMinYEdge = 1,
  CGRectMaxXEdge = 2,
  CGRectMaxYEdge = 3
};

typedef struct CGAffineTransform CGAffineTransform;

struct CGAffineTransform {
    CGFloat a, b, c, d;
    CGFloat tx, ty;
};

#define CF_DEFINES_CGAFFINETRANSFORMCOMPONENTS

/*                      |------------------ CGAffineTransformComponents ----------------|
 *
 *      | a  b  0 |     | sx  0  0 |   |  1  0  0 |   | cos(t)  sin(t)  0 |   | 1  0  0 |
 *      | c  d  0 |  =  |  0 sy  0 | * | sh  1  0 | * |-sin(t)  cos(t)  0 | * | 0  1  0 |
 *      | tx ty 1 |     |  0  0  1 |   |  0  0  1 |   |   0       0     1 |   | tx ty 1 |
 *  CGAffineTransform      scale           shear            rotation          translation
 */
typedef struct CGAffineTransformComponents CGAffineTransformComponents;

struct CGAffineTransformComponents {

    /* Scale factors in X and Y dimensions. Negative values indicate flipping along that axis. */
    CGSize      scale;

    /* Shear distortion along the horizontal axis. A value of 0 means no shear. */
    CGFloat     horizontalShear;

    /* Rotation angle in radians around the origin. Sign convention may vary
     * based on the coordinate system used. */
    CGFloat     rotation;

    /* Translation or displacement along the X and Y axes. */
    CGVector    translation;
};


#endif // _CFCGTypes_h_GNUSTEP_BASE_INCLUDE
