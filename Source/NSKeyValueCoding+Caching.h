/** Key-Value Coding Safe Caching Support
   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by:  Hugo Melder <hugo@algoriddim.com>
   Created: August 2024

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

/**
 * It turns out that valueForKey: is a very expensive operation, and a major
 * bottleneck for Key-Value Observing and other operations such as sorting
 * an array by key.
 *
 * The accessor search patterns for Key-Value observing are discussed in the
 * Apple Key-Value Coding Programming Guide. The return value may be
 * encapuslated into an NSNumber or NSValue object, depending on the Objective-C
 * type encoding of the return value. This means that once valueForKey: found an
 * existing accessor, the Objective-C type encoding of the accessor is
 * retrieved. We then go through a huge switch case to determine the right way
 * to invoke the IMP and potentially encapsulate the return type. The resulting
 * object is then returned.
 * The algorithm for setValue:ForKey: is similar.
 *
 * We can speed this up by caching the IMP of the accessor in a hash table.
 * However, without proper versioning, this quickly becomes very dangerous.
 * The user might exchange implementations, or add new ones expecting the
 * search pattern invariant to still hold. If we clamp onto an IMP, this
 * invariant no longer holds.
 *
 * We will make use of libobjc2's safe caching to avoid this.
 *
 * Note that the caching is opaque. You will only need to redirect all
 * valueForKey: calls to the function below.
 */

#import "Foundation/NSString.h"
#import "GSPrivate.h"

id
valueForKeyWithCaching(id obj, NSString *aKey) GS_ATTRIB_PRIVATE;
