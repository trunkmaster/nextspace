/*
  PathViewScroller.h
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

#import <AppKit/NSScroller.h>

@interface PathViewScroller : NSScroller
{
  id delegate;
}

- (void)setDelegate:aDelegate;
- delegate;

@end

@protocol PathViewScrollerDelegate

- (void)constrainScroller:(NSScroller *)aScroller;

- (void)trackScroller:(NSScroller *)aScroller;

@end
