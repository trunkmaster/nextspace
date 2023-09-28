/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description: A special subclass of NSScroller to notify the file viewer when
//              it's scrolled.
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
