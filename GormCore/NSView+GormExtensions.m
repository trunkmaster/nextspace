/* NSView+GormExtensions.m
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2004
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "NSView+GormExtensions.h"

static Ivar subviews_ivar(void)
{
  static Ivar iv;
  if (iv == NULL)
    {
      iv = class_getInstanceVariable([NSView class], "_sub_views");
      NSCAssert(iv, @"Unable to get NSView's _sub_views instance variable");
    }
  return iv;
}


@implementation NSView (GormExtensions)
/**
 * All superviews of this view
 */
- (NSArray *) superviews
{
  NSMutableArray *result = [NSMutableArray array];
  NSView *currentView = nil; 
 
  for(currentView = self; currentView != nil; 
      currentView = [currentView superview])
    {
      [result addObject: currentView];
    }

  return result;
}

/**
 * Checks for a superview of a give class.
 */
- (BOOL) hasSuperviewKindOfClass: (Class)cls
{
  NSEnumerator *en = [[self superviews] objectEnumerator];
  NSView *v = nil;
  BOOL result = NO;

  while(((v = [en nextObject]) != nil) && 
	result == NO)
    {
      result = [v isKindOfClass: cls];
    }

  return result;
}

/**
 * Moves the specified subview to the end of the list, so it's displayed
 * in front of the other views.
 */
- (void) moveViewToFront: (NSView *)sv
{
  NSDebugLog(@"move to front %@", sv);
  NSMutableArray *sub_views = object_getIvar(self, subviews_ivar());
  if([sub_views containsObject: sv])
    {
      RETAIN(sv); // make sure it doesn't deallocate the view.
      [sub_views removeObject: sv];
      [sub_views addObject: sv]; // add it to the end.
      RELEASE(sv);
    }
}

/**
 * Moves the specified subview to the beginning of the list, so it's 
 * displayed behind all of the other views.
 */
- (void) moveViewToBack: (NSView *)sv
{
  NSDebugLog(@"move to back %@", sv);
  NSMutableArray *sub_views = object_getIvar(self, subviews_ivar());
  if([sub_views containsObject: sv])
    {
      RETAIN(sv); // make sure it doesn't deallocate the view.
      [sub_views removeObject: sv];
      if([sub_views count] > 0)
	{
	  [sub_views insertObject: sv 
		      atIndex: 0]; // add it to the end.
	}
      else
	{
	  [sub_views addObject: sv];
	}
      RELEASE(sv);
    }
}
@end

/**
 * Registry of delegates.  This allows the implementation of the protocol
 * to select from the list of delegates to determine which one should be called.
 */
static NSMutableArray *_registeredViewResourceDraggingDelegates = nil;

/**
 * IBViewResourceDraggingDelegates implementation.  These methods
 * make it possible to declare types in palettes and dynamically select the
 * appropriate delegate to handle the addition of an object to the document.
 */
@implementation NSView (IBViewResourceDraggingDelegates)

/**
 * Types accepted by the view.
 */
+ (NSArray *) acceptedViewResourcePasteboardTypes
{
  NSMutableArray *result = nil;
  if([_registeredViewResourceDraggingDelegates count] > 0)
    {
      NSEnumerator *en = [_registeredViewResourceDraggingDelegates objectEnumerator];
      id delegate = nil;
      result = [NSMutableArray array];

      while((delegate = [en nextObject]) != nil)
	{
	  if([delegate respondsToSelector: @selector(viewResourcePasteboardTypes)])
	    {
	      [result addObjectsFromArray: [delegate viewResourcePasteboardTypes]];
	    }
	}
    }
  return result;
}

/**
 * Return the list of registered delegates.
 */
+ (NSArray *) registeredViewResourceDraggingDelegates
{
  return _registeredViewResourceDraggingDelegates;
}

/**
 * Register a delegate.
 */
+ (void) registerViewResourceDraggingDelegate: (id<IBViewResourceDraggingDelegates>)delegate
{
  if(_registeredViewResourceDraggingDelegates == nil)
    {
      _registeredViewResourceDraggingDelegates = [[NSMutableArray alloc] init];
    }

  [_registeredViewResourceDraggingDelegates addObject: delegate];
}

/**
 * Remove a previously registered delegate.
 */
+ (void) unregisterViewResourceDraggingDelegate: (id<IBViewResourceDraggingDelegates>)delegate
{
  if(_registeredViewResourceDraggingDelegates != nil)
    {
      [_registeredViewResourceDraggingDelegates removeObject: delegate];
    }
}

@end
