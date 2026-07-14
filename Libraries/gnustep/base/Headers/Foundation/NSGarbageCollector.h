/** Interface for NSGarbageCollector for GNUStep
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: Jan 2009
   
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

   AutogsdocSource: NSGarbageCollector.m

   */ 

#ifndef _NSGarbageCollector_h_GNUSTEP_BASE_INCLUDE
#define _NSGarbageCollector_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif


GS_EXPORT_CLASS
@interface NSGarbageCollector : NSObject 

/** Obsolete ... returns nil because garbage collection no longer exists.
 */
+ (id) defaultCollector;

/** Obsolete ... does nothing because garbage collection no longer exists.
 */
- (void) collectIfNeeded;

/** Obsolete ... does nothing because garbage collection no longer exists.
 */
- (void) collectExhaustively;

/** Obsolete ... does nothing because garbage collection no longer exists.
 */
- (void) disable;

/** Obsolete ... does nothing because garbage collection no longer exists.
 */
- (void) disableCollectorForPointer: (void *)ptr;

/** Obsolete ... does nothing because garbage collection no longer exists.
 */
- (void) enable;

/** Obsolete ... does nothing because garbage collection no longer exists.
 */
- (void) enableCollectorForPointer: (void *)ptr;      

/** Obsolete ... returns NO because garbage collection no longer exists.
 */
- (BOOL) isCollecting;

/** Obsolete ... returns NO because garbage collection no longer exists.
 */
- (BOOL) isEnabled;

/** Returns the default zone.
 */
- (NSZone*) zone;
@end

#if	defined(__cplusplus)
}
#endif

#endif
#endif
