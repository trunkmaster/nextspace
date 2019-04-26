/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2005 Saso Kiselkov
// Copyright (C) 2015-2019 Sergii Stoian
//     
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "PathViewScroller.h"

#import "math.h"

@class NSEvent;

@implementation PathViewScroller

- (void)trackKnob:(NSEvent *)ev
{
  [super trackKnob:ev];

  if ([delegate respondsToSelector:@selector(constrainScroller:)])
    {
      [delegate constrainScroller:self];
    }
  if ([delegate respondsToSelector:@selector(trackScroller:)])
    {
      [delegate trackScroller:self];
    }
}

- (void)trackScrollButtons:(NSEvent *)ev
{
  [super trackScrollButtons:ev];

  if ([delegate respondsToSelector:@selector(trackScroller:)])
    {
      [delegate trackScroller:self];
    }
}

- (void)setDelegate:aDelegate
{
  delegate = aDelegate;
}

- delegate
{
  return delegate;
}

@end
