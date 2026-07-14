/* IBInspectorManager.m
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

#include <Foundation/Foundation.h>

#include "IBInspectorManager.h"
#include "IBInspectorMode.h"

#include <math.h>

static IBInspectorManager *_sharedInspectorManager = nil;

/**
 * Notifications to be sent prior to the action described.
 */ 
NSString *IBWillInspectObjectNotification = 
    @"IBWillInspectObjectNotification";
NSString *IBWillInspectWithModeNotification = 
    @"IBWillInspectWithModeNotification"; 

@implementation IBInspectorManager

/**
 * Create a shared instance of the class for the application. 
 * If a subclass of IBInspectorManager uses this message it becomes
 * the shraredInspectorManager.
 */
+ (IBInspectorManager *) sharedInspectorManager
{
  if(_sharedInspectorManager == nil)
    {
      _sharedInspectorManager = [[self alloc] init];
    }
  return _sharedInspectorManager;
}

- (id) init
{
  if(_sharedInspectorManager == nil)
    {
      if((self = [super init]) != nil)
	{
	  // set the shared instance...
	  modes = [[NSMutableArray alloc] init];
	  _sharedInspectorManager = self;
	}
    }
  else
    {
      RELEASE(self);
      self = _sharedInspectorManager;
    }

  return self;
}

- (void) dealloc
{
  RELEASE(modes);
  [super dealloc];
}

/**
 * Add an inspector for a given mode.  This allows the addition
 * of inspectors for different aspects of the same object.
 */
- (void) addInspectorModeWithIdentifier: (NSString *)ident
                              forObject: (id)obj
                         localizedLabel: (NSString *)label
                     inspectorClassName: (NSString *)className
                               ordering: (float)ord
{
  IBInspectorMode *mode = [[IBInspectorMode alloc] 
			    initWithIdentifier: ident
			    forObject: obj
			    localizedLabel: label
			    inspectorClassName: className
			    ordering: ord];
  int position = 0;
  int count = [modes count];

  if(ord == -1)
    {
      position = count; // last
    }
  else
    {
      position = (int)ceil((double)ord);
      if(position > count)
	{
	  position = count;
	}
    }

  [modes insertObject: mode
	 atIndex: position];  
}

/**
 * Position in the inspector list that the "mode inspector"
 * appears.
 */
- (unsigned int) indexOfModeWithIdentifier: (NSString *)ident
{
  NSEnumerator *en = [modes objectEnumerator];
  int index = 0;
  id mode = nil;

  while((mode = [en nextObject]) != nil)
    {
      if([[mode identifier] isEqualToString: ident])
	{
	  break;
	}
      index++;
    }
  
  return index;
}
@end
