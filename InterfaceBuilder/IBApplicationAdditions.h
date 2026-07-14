/* IBApplicationAdditions.h
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

#ifndef INCLUDED_IBAPPLICATIONADDITIONS_H
#define INCLUDED_IBAPPLICATIONADDITIONS_H

#include <InterfaceBuilder/IBDocuments.h>
#include <InterfaceBuilder/IBEditors.h>
#include <InterfaceBuilder/IBSystem.h>

IB_EXTERN NSString *IBWillBeginTestingInterfaceNotification;
IB_EXTERN NSString *IBDidBeginTestingInterfaceNotification;
IB_EXTERN NSString *IBWillEndTestingInterfaceNotification;
IB_EXTERN NSString *IBDidEndTestingInterfaceNotification;

@protocol IB <NSObject>
/**
 * Returns the document which is currently being edited.
 */
- (id<IBDocuments>) activeDocument;

/**
 * Returns YES, if the reciever is in testing mode.
 */
- (BOOL) isTestingInterface;

/**
 * Returns the current selection owner.
 */
- (id<IBSelectionOwners>) selectionOwner;

/**
 * Returns the current selection from the current selection
 * owner.
 */
- (id) selectedObject;

/**
 * Returns the document which contains this object.
 */
- (id<IBDocuments>) documentForObject: (id)object;
@end

@interface NSApplication (GormSpecific)
/**
 * Image to be displayed with making a link.
 */
- (NSImage *) linkImage;

/**
 * Start the connection process.
 */
- (void) startConnecting;
@end

#endif
