/* Copyright (C) 2023 Free Software Foundation, Inc.

   By: Benjamin Johnson
   Date: 19-3-2023
   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import "GSCSStrength.h"
#import "GSCSFloatComparator.h"

@implementation GSCSStrength

const float GSCSStrengthRequired = 1000;
const float GSCSStrengthStrong = 750;
const float GSCSStrengthMedium = 500;
const float GSCSStrengthWeak = 250;

- (instancetype) initWithName: (NSString *)name strength: (double)strength;
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_name, name);
      _strength = strength;
    }
  return self;
}

+ (instancetype) strengthRequired
{
  return AUTORELEASE([[GSCSStrength alloc] initWithName: @"<Required>" strength: GSCSStrengthRequired]);
}

+ (instancetype) strengthStrong
{
  return AUTORELEASE([[GSCSStrength alloc] initWithName: @"strong" strength: GSCSStrengthStrong]);
}

+ (instancetype) strengthMedium
{
  return AUTORELEASE([[GSCSStrength alloc] initWithName: @"medium" strength: GSCSStrengthMedium]);
}

+ (instancetype) strengthWeak
{
  return AUTORELEASE([[GSCSStrength alloc] initWithName: @"weak" strength: GSCSStrengthWeak]);
}

- (BOOL) isEqualToStrength: (GSCSStrength *)strength
{
  return [_name isEqual: [strength name]] &&
         [GSCSFloatComparator isApproxiatelyEqual: _strength
                                                b: [strength strength]];
}

- (BOOL) isEqual: (id)other
{
  if (other == nil)
    {
      return NO;
    }

  if (other == self)
    {
      return YES;
    }

  return [self isEqualToStrength: other];
}

- (BOOL) isRequired
{
  return [GSCSFloatComparator
      isApproxiatelyEqual: _strength
                        b: GSCSStrengthRequired];
}

- (double) strength
{
  return _strength;
}

- (NSString *) name
{
  return _name;
}

- (id) copyWithZone: (NSZone *)zone
{
  GSCSStrength *copy =
      [[[self class] allocWithZone: zone] initWithName: _name
                                              strength: _strength];

  return copy;
}

- (void) dealloc
{
  RELEASE(_name);
  [super dealloc];
}

@end
