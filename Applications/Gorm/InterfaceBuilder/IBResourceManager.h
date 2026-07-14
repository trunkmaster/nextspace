/* IBResourceManager.h
 *
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2005
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

#ifndef INCLUDED_IBRESOURCEMANAGER_H
#define INCLUDED_IBRESOURCEMANAGER_H

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/IBProjects.h>
#include <InterfaceBuilder/IBProjectFiles.h>
#include <InterfaceBuilder/IBDocuments.h>

@class NSString, NSPasteboard, NSMutableArray;

/**
 * Notification sent when a resource manager class is added to /removed from 
 * the registry.
 */
IB_EXTERN NSString *IBResourceManagerRegistryDidChangeNotification;

/** 
 * Enumerated type to allow specification of where the resource
 * lives.
 */
enum IBResourceLocation { 
  kNibResource = 0,
  kProjectResource,
  kPaletteResource,
  kSystemResource, 
  kUnknownResource 
};

@interface IBResourceManager : NSObject
{
  id<IBDocuments> document;
}

/**
 * Register the given class as a resource mananger.
 */
+ (void) registerResourceManagerClass: (Class)managerClass;

/**
 * Register the given class as a resource manager for the frameworks in the array.
 */ 
+ (void) registerResourceManagerClass: (Class)managerClass 
                        forFrameworks: (NSArray *)frameworks;

/**
 * Return an array of classes for the given framework.
 */
+ (NSArray *) registeredResourceManagerClassesForFramework: (NSString *)framework;

/**
 * Returns YES, if the pasteboard contains a type the resource  
 * manager can accept.
 */
- (BOOL) acceptsResourcesFromPasteboard: (NSPasteboard *)pboard;

/**
 * Add a resource.
 */
- (void) addResources: (NSArray *)resourceList;

/**
 * Add resoures from the pasteboard.  Invokes the 
 * acceptsResourcesFromPasteboard: method to determine 
 * if the resources will be added.
 */
- (void) addResourcesFromPasteboard: (NSPasteboard *)pboard;

/**
 * Called by an external application when a file owned by 
 * the GUI builder is modified.
 */
- (void) application: (NSString *) appName didModifyFileAtPath: (NSString *)path;

/**
 * Returns the document with which this resource manager is
 * associated.
 */
- (id<IBDocuments>) document;

/**
 * Instantiate the resource manager with the given 
 * document object.
 */
- (id) initWithDocument: (id<IBDocuments>)document;

/**
 * Returns YES, if this resource manager is non-modifiable.
 */
- (BOOL) isReadOnly;

/**
 * Called by an external application when the a file
 * is added.
 */
- (void) project: (id<IBProjects>)proj didAddFile: (id<IBProjectFiles>)file;

/**
 * Called by an external application when the a file
 * changes localization.
 */
- (void) project: (id<IBProjects>)proj didChangeLocalizationOfFile: (id<IBProjectFiles>)file;

/**
 * Called by an external application when a file
 * is removed.
 */
- (void) project: (id<IBProjects>)proj didRemoveFile: (id<IBProjectFiles>)file;

/**
 * Returns a list of resource file types this manager can accept.
 */
- (NSArray *) resourceFileTypes;

/**
 * Returns a list of pasteboard types this manager can accept.
 */
- (NSArray *) resourcePasteboardTypes;

/**
 * Returns the associated resources for the objects.
 */
- (NSArray *) resourcesForObjects: (NSArray *)objs;

/**
 * Writes a resource to the document path.
 */
- (void) writeToDocumentPath: (NSString *)path;
@end

#endif
