/* IBInspectorMode
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>

#include "IBInspectorMode.h"

/**
 * IBInspectorMode is an internal class in the InterfaceBuilder framework.
 */

@implementation IBInspectorMode
- (id) initWithIdentifier: (NSString *)ident
		forObject: (id)obj
	   localizedLabel: (NSString *)lab
       inspectorClassName: (NSString *)cn
		 ordering: (float)ord
{
  if((self = [super init]) != nil)
    {
      [self setIdentifier: ident];
      [self setObject: obj];
      [self setLocalizedLabel: lab];
      [self setInspectorClassName: cn];
      [self setOrdering: ord];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(identifier);
  // RELEASE(object);
  RELEASE(localizedLabel);
  RELEASE(inspectorClassName);
  [super dealloc];
}

- (void) setIdentifier: (NSString *)ident
{
  ASSIGN(identifier, ident);
}

- (NSString *) identifier
{
  return identifier;
}

- (void) setObject: (id)obj
{
  // don't retain the object, since we are not the owner.
  object = obj;
}

- (id) object
{
  return object;
}

- (void) setLocalizedLabel: (NSString *)lab
{
  ASSIGN(localizedLabel, lab);
}

- (NSString *) localizedLabel
{
  return localizedLabel;
}

- (void) setInspectorClassName: (NSString *)cn
{
  ASSIGN(inspectorClassName, cn);
}

- (NSString *) inspectorClassName
{
  return inspectorClassName;
}

- (void) setOrdering: (float)ord
{
  ordering = ord;
}

- (float) ordering
{
  return ordering;
}
@end
