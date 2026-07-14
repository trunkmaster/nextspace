/* IBResourceManager.m
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "IBResourceManager.h"
#include "IBObjectAdditions.h"
#include "IBPalette.h"

NSString *IBResourceManagerRegistryDidChangeNotification = @"IBResourceManagerRegistryDidChangeNotification";

static NSMapTable *_resourceManagers = NULL;

@implementation IBResourceManager : NSObject

/**
 * Create the resource manager table.
 */
+ (BOOL) _createTable
{
  if(_resourceManagers == NULL)
    {
      _resourceManagers = NSCreateMapTable(NSObjectMapKeyCallBacks,
					   NSObjectMapValueCallBacks, 
					   2);
    }

  return (_resourceManagers != NULL);
}

/**
 * Add a class to the resourceManager master list of classes.
 */
+ (void) _addClass: (Class)managerClass
{
  if([self _createTable])
    {
      NSMutableArray *list = NSMapGet(_resourceManagers, [NSNull null]);
      if(list == nil)
	{
	  list = [NSMutableArray array];
	  NSMapInsert(_resourceManagers, [NSNull null], list);
	}
      
      if([list containsObject: managerClass] == NO)
	{
	  [list addObject: managerClass];
	}
    }
}

+ (void) registerResourceManagerClass: (Class)managerClass
{
  [self _addClass: managerClass];

  // notify
  [[NSNotificationCenter defaultCenter] 
    postNotificationName: IBResourceManagerRegistryDidChangeNotification
    object: managerClass];
}

+ (void) registerResourceManagerClass: (Class)managerClass 
                        forFrameworks: (NSArray *)frameworks
{
  if([self _createTable])
    {
      NSMutableArray *list = nil;
      if(frameworks == nil)
	{
	  [self _addClass: managerClass];
	}
      else
	{
	  NSEnumerator *en = [frameworks objectEnumerator];
	  NSString *fw = nil;

	  // add it to all of the frameworks.
	  while((fw = [en nextObject]) != nil)
	    {
	      list = NSMapGet(_resourceManagers, fw);
	      if(list == nil)
		{
		  list = [NSMutableArray array];
		  NSMapInsert(_resourceManagers, fw, list);
		}
	      
	      if([list containsObject: managerClass] == NO)
		{
		  [list addObject: managerClass];
		}
	    }

	  // also add it to the master list.
	  [self _addClass: managerClass];
	}
      
      // notify 
      [[NSNotificationCenter defaultCenter] 
	postNotificationName: IBResourceManagerRegistryDidChangeNotification
	object: managerClass];
    }
}

+ (NSArray *) registeredResourceManagerClassesForFramework: (NSString *)framework
{
  return (NSArray *)(NSMapGet(_resourceManagers, ((framework == nil)?(void *)[NSNull null]:framework)));
}

- (BOOL) acceptsResourcesFromPasteboard: (NSPasteboard *)pboard
{
  NSArray *types = [pboard types];
  NSArray *resourcePbTypes = [self resourcePasteboardTypes]; 
  NSString *type = [types firstObjectCommonWithArray: resourcePbTypes];
  return (type != nil);
}

- (void) addResources: (NSArray *)resourceList
{
  [document attachObjects: resourceList toParent: nil];
}

- (void) addResourcesFromPasteboard: (NSPasteboard *)pboard
{
  NSArray *resourcePbTypes = [self resourcePasteboardTypes];
  NSString *type = nil;
  NSEnumerator *en = [resourcePbTypes objectEnumerator];

  while((type = [en nextObject]) != nil)
    {
      NSData *data = [pboard dataForType: type];
      if(data != nil)
	{
	  NS_DURING
	    {
	      id obj = [NSUnarchiver unarchiveObjectWithData: data];
	      if(obj != nil)
		{
		  // the object is an array of objects of this type.
		  [self addResources: obj];
		}
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Problem adding resource: %@",[localException reason]);
	    }
	  NS_ENDHANDLER;
	}
    }
}

- (void) application: (NSString *) appName didModifyFileAtPath: (NSString *)path
{
  // does nothing.
}

- (id<IBDocuments>) document
{
  return document;
}

- (id) initWithDocument: (id<IBDocuments>)doc
{
  if((self = [super init]) != nil)
    {
      document = doc; // weak connection.
    }
  return self;
}

/**
 * Deallocate the object.
 */
- (void) dealloc
{
  document = nil;
  [super dealloc];
}

- (BOOL) isReadOnly;
{
  return NO;
}

- (void) project: (id<IBProjects>)proj didAddFile: (id<IBProjectFiles>)file
{
}

- (void) project: (id<IBProjects>)proj didChangeLocalizationOfFile: (id<IBProjectFiles>)file
{
}

- (void) project: (id<IBProjects>)proj didRemoveFile: (id<IBProjectFiles>)file
{
  // does nothing in base implementation.
}

- (NSArray *) resourceFileTypes
{
  return nil;
}

- (NSArray *) resourcePasteboardTypes
{
  return [NSArray arrayWithObjects: IBObjectPboardType, nil];
}

- (NSArray *) resourcesForObjects: (NSArray *)objs;
{
  return nil;
}

- (void) writeToDocumentPath: (NSString *)path
{
  // does nothing in base implementation.
}

@end
