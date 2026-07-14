/* IBInspectorManager.h
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004
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

#ifndef INCLUDED_IBINSPECTORMANAGER_H
#define INCLUDED_IBINSPECTORMANAGER_H

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/IBSystem.h>

@class NSString, NSMutableArray;

/**
 * Notifications to be sent prior to the action described.
 */ 
IB_EXTERN NSString *IBWillInspectObjectNotification;
IB_EXTERN NSString *IBWillInspectWithModeNotification;

@interface IBInspectorManager : NSObject
{
  NSMutableArray        *modes;
  id                    currentMode;
  id                    selectedObject;
}

/**
 * Create a shared instance of the class for the applicaiton.
 */
+ (IBInspectorManager *) sharedInspectorManager;

/**
 * Add an inspector for a given mode.  This allows the addition
 * of inspectors for different aspects of the same object.
 */
- (void) addInspectorModeWithIdentifier: (NSString *)ident
                              forObject: (id)obj
                         localizedLabel: (NSString *)label
                     inspectorClassName: (NSString *)className
                               ordering: (float)ord;

/**
 * Position in the inspector list that the "mode inspector"
 * appears.
 */
- (unsigned int) indexOfModeWithIdentifier: (NSString *)ident;
@end

#endif
