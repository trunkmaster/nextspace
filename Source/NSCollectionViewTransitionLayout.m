/* Implementation of class NSCollectionViewTransitionLayout
   Copyright (C) 2021 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 30-05-2021

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

#import "AppKit/NSCollectionViewTransitionLayout.h"

@implementation NSCollectionViewTransitionLayout

- (CGFloat) transitionProgress
{
  return _transitionProgress;
}

- (void) setTransitionProgress: (CGFloat)transitionProgress
{
  _transitionProgress = transitionProgress;
}

- (NSCollectionViewLayout *) currentLayout
{
  return _currentLayout;
}

- (NSCollectionViewLayout *) nextLayout
{
  return _nextLayout;
}

// Designated initializer
- (instancetype) initWithCurrentLayout: (NSCollectionViewLayout *)currentLayout
                            nextLayout: (NSCollectionViewLayout *)nextLayout
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_currentLayout, currentLayout);
      ASSIGN(_nextLayout, nextLayout);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_currentLayout);
  RELEASE(_nextLayout);
  [super dealloc];
}

- (void) updateValue: (CGFloat)value forAnimatedKey: (NSCollectionViewTransitionLayoutAnimatedKey)key
{
  // not implemented...
}

- (CGFloat) valueForAnimatedKey: (NSCollectionViewTransitionLayoutAnimatedKey)key
{
  return 1.0;
}

@end
