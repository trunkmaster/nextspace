/** NSDate Private Interface
   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by: Hugo Melder <hugo@algoriddim.com>

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

#import <Foundation/NSDate.h>

#if defined(OBJC_SMALL_OBJECT_SHIFT) && (OBJC_SMALL_OBJECT_SHIFT == 3)
#define USE_SMALL_DATE 1
#define DATE_CONCRETE_CLASS_NAME GSSmallDate
#else
#define USE_SMALL_DATE 0
#define DATE_CONCRETE_CLASS_NAME NSGDate
#endif

@interface DATE_CONCRETE_CLASS_NAME : NSDate
#if USE_SMALL_DATE == 0
{
@public
  NSTimeInterval _seconds_since_ref;
}
#endif
@end