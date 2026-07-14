/* IBViewResourceDragging.h
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2003
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

#ifndef INCLUDED_IBVIEWRESOURCEDRAGGING_H
#define INCLUDED_IBVIEWRESOURCEDRAGGING_H

#include <AppKit/AppKit.h>

@class NSPasteboard;

/**
 * Protocol describing those methods needed to accept resources.
 */
@protocol IBViewResourceDraggingDelegates

/**
 * Ask if the view accepts the object.
 */
- (BOOL) acceptsViewResourceFromPasteboard: (NSPasteboard *)pb
                                 forObject: (id)obj
                                   atPoint: (NSPoint)p;

/**
 * Perform the action of depositing the object.
 */
- (void) depositViewResourceFromPasteboard: (NSPasteboard *)pb
                                  onObject: (id)obj
                                   atPoint: (NSPoint)p;

/**
 * Should we draw the connection frame when the resource is
 * dragged in?
 */
- (BOOL) shouldDrawConnectionFrame;

/**
 * Types of resources accepted by this view.
 */
- (NSArray *)viewResourcePasteboardTypes;

@end

/**
 * Informal protocol on NSView.
 */
@interface NSView (IBViewResourceDraggingDelegates)

/**
 * Types accepted by the view.
 */
+ (NSArray *) acceptedViewResourcePasteboardTypes;

/**
 * Return the list of registered delegates.
 */
+ (NSArray *) registeredViewResourceDraggingDelegates;

/**
 * Register a delegate.
 */
+ (void) registerViewResourceDraggingDelegate: (id<IBViewResourceDraggingDelegates>)delegate;

/**
 * Remove a previously registered delegate.
 */
+ (void) unregisterViewResourceDraggingDelegate: (id<IBViewResourceDraggingDelegates>)delegate;

@end
#endif
