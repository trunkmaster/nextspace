/*
   PathViewScroller.m
   A special subclass of NSScroller to notify the file viewer when
   it's scrolled.

   Copyright (C) 2005 Saso Kiselkov

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

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
