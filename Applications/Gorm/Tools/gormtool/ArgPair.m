/* AppDelegate.m
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg.casamento@gmail.com>
 * Date:	2023
 *
 * This file is part of GNUstep.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */

#import <Foundation/NSString.h>

#import "ArgPair.h"

@implementation ArgPair

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _argument = nil;
      _value = nil;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_argument);
  RELEASE(_value);

  [super dealloc];
}

- (void) setArgument: (NSString *)arg
{
  ASSIGN(_argument, arg);
}

- (NSString *) argument
{
  return _argument;
}

- (void) setValue: (NSString *)val
{
  ASSIGN(_value, val);
}

- (NSString *) value
{
  return _value;
}

- (id) copyWithZone: (NSZone *)z
{
  id obj = [[[self class] allocWithZone: z] init];

  [obj setArgument: _argument];
  [obj setValue: _value];

  return obj;
}

@end
