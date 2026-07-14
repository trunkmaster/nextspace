/* GormClassManager.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2002
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

#import <Foundation/Foundation.h>

#import <InterfaceBuilder/InterfaceBuilder.h>
#import <GormObjCHeaderParser/GormObjCHeaderParser.h>

#import "GormPrivate.h"
#import "GormCustomView.h"
#import "GormDocument.h"
#import "GormFilesOwner.h"
#import "GormPalettesManager.h"
#import "GormAbstractDelegate.h"

/**
 * Just a few definitions to start things out.  To increase efficiency,
 * so that Gorm doesn't need to constantly derive the method list for
 * each class, it is necessary to cache some information.  Here is the
 * way it works.
 *
 * Actions = All actions on that class, excluding superclass methods.
 * AllActions = All actions on that class including superclass methods.
 * ExtraActions = All actions added during this session.
 *
 * Outlets = All actions on that class, excluding superclass methods.
 * AllOutlets = All actions on that class including superclass methods.
 * ExtraOutlets = All actions added during this session.
 */

/** Private methods not accesible from outside */
@interface GormClassManager (Private)
- (NSMutableDictionary*) classInfoForClassName: (NSString*)className;
- (NSMutableDictionary*) classInfoForObject: (id)anObject;
- (void) touch;
- (void) convertDictionary: (NSMutableDictionary *)dict;
@end

@interface NSMutableArray (Private)
- (void) mergeObject: (id)object;
- (void) mergeObjectsFromArray: (NSArray *)array;
@end

@implementation NSMutableArray (Private)
- (void) mergeObject: (id)object
{
  if ([self containsObject: object] == NO)
    {
      [self addObject: object];
      [self sortUsingSelector: @selector(compare:)];
    }
}

- (void) mergeObjectsFromArray: (NSArray *)array
{
  id            obj = nil;

  if(array != nil)
    {
      NSEnumerator	*enumerator = [array objectEnumerator];
      while ((obj = [enumerator nextObject]) != nil)
	{
	  [self mergeObject: obj];
	}	  
    }
}
@end

@implementation GormClassManager

- (id) initWithDocument: (id)aDocument
{
  self = [super init];
  if (self != nil)
    {
      NSBundle			*bundle = [NSBundle bundleForClass: [self class]];
      NSString			*path;

      _document = aDocument;  // the _document retains us, this is for convenience

      path = [bundle pathForResource: @"ClassInformation" ofType: @"plist"];
      if (path == nil)
	{
	  NSLog(@"ClassInformation.plist missing from resources");
	}
      else
	{
	  GormPalettesManager *palettesManager = [(id<GormAppDelegate>)[NSApp delegate] palettesManager];
	  NSDictionary *importedClasses = [palettesManager importedClasses];
	  NSEnumerator *en = [importedClasses objectEnumerator];
	  NSDictionary *description = nil;
   
	  // load the classes, initialize the custom class array and map..
	  if([self loadFromFile: path])
	    {
	      NSMutableDictionary *classDict = [_classInformation objectForKey: @"FirstResponder"];
	      NSMutableArray *firstResponderActions = [classDict objectForKey: @"Actions"];

	      _customClasses = [[NSMutableArray alloc] initWithCapacity: 1];
	      _customClassMap = [[NSMutableDictionary alloc] initWithCapacity: 10]; 
	      _categoryClasses = [[NSMutableArray alloc] initWithCapacity: 1];
	      
	      // add the imported classes to the class information list...
	      [_classInformation addEntriesFromDictionary: importedClasses];
	      
	      // add all of the actions to the FirstResponder
	      while((description = [en nextObject]) != nil)
		{
		  NSArray *actions = [description objectForKey: @"Actions"];
		  NSEnumerator *aen = [actions objectEnumerator];
		  NSString *actionName = nil;
		  
		  // add the actions to the first responder...
		  while((actionName = [aen nextObject]) != nil)
		    {
		      if(![firstResponderActions containsObject: actionName])
			{
			  [firstResponderActions addObject: [actionName copy]];
			}
		    }
		}
	      
	      // incorporate the added actions into the list and sort.
	      [self allActionsForClassNamed: @"FirstResponder"]; 
	    }
	}
    }
  
  return self;
}

- (void) touch
{
  [[NSNotificationCenter defaultCenter] 
    postNotificationName: GormDidModifyClassNotification
    object: self];

  [_document touch];
}

- (void) convertDictionary: (NSMutableDictionary *)dict
{
  [dict removeObjectsForKeys: [_classInformation allKeys]];
}

- (NSString *) uniqueClassNameFrom: (NSString *)name
{
  NSString *search = [NSString stringWithString: name];
  NSInteger i = 1;

  while([_classInformation objectForKey: search])
    {
      search = [name stringByAppendingString: [NSString stringWithFormat: @"%ld",(long)i++]];
    }

  return search;
}

- (NSString *) addClassWithSuperClassName: (NSString*)name
{
  if (([self isRootClass: name] || [_classInformation objectForKey: name] != nil)
      && [name isEqual: @"FirstResponder"] == NO)
    {
      NSMutableDictionary	*classInfo;
      NSMutableArray		*outlets;
      NSMutableArray		*actions;
      NSString			*className = [self uniqueClassNameFrom: @"NewClass"];

      classInfo = [[NSMutableDictionary alloc] initWithCapacity: 3];
      outlets = [[NSMutableArray alloc] initWithCapacity: 0];
      actions = [[NSMutableArray alloc] initWithCapacity: 0];

      [classInfo setObject: outlets forKey: @"Outlets"];
      [classInfo setObject: actions forKey: @"Actions"];
      [classInfo setObject: name forKey: @"Super"];

      [_classInformation setObject: classInfo forKey: className];
      [_customClasses addObject: className];

      [self touch];

      [[NSNotificationCenter defaultCenter] 
	postNotificationName: GormDidAddClassNotification
	object: self];

      return className;
    }

  return nil;
}

- (NSString *) addNewActionToClassNamed: (NSString *)name
{
  NSArray *combined = [self allActionsForClassNamed: name];
  NSString *newAction = @"newAction";
  NSString *search = [newAction stringByAppendingString: @":"];
  NSString *new = nil; 
  NSInteger i = 1;

  while ([combined containsObject: search])
    {
      new = [newAction stringByAppendingFormat: @"%ld", (long)i++];
      search = [new stringByAppendingString: @":"];
    }

  [self addAction: search forClassNamed: name];
  return search;
}

- (NSString *) addNewOutletToClassNamed: (NSString *)name
{
  NSArray *combined = [self allOutletsForClassNamed: name];
  NSString *newOutlet = @"newOutlet";
  NSString *new = newOutlet;
  NSInteger i = 1;

  while ([combined containsObject: new])
    {
      new = [newOutlet stringByAppendingFormat: @"%ld", (long)i++];
    }

  [self addOutlet: new forClassNamed: name];
  return new;
}

- (BOOL) addClassNamed: (NSString *)className
   withSuperClassNamed: (NSString *)superClassName
	   withActions: (NSArray *)actions
	   withOutlets: (NSArray *)outlets
{
  return [self addClassNamed: className
	       withSuperClassNamed: superClassName
	       withActions: actions
	       withOutlets: outlets
	       isCustom: YES];
}

- (BOOL) addClassNamed: (NSString *)className
   withSuperClassNamed: (NSString *)superClassName
	   withActions: (NSArray *)actions
	   withOutlets: (NSArray *)outlets
	      isCustom: (BOOL) isCustom
{
  BOOL result = NO;
  NSString *classNameCopy = [NSString stringWithString: className];
  NSString *superClassNameCopy = (superClassName != nil)?[NSString stringWithString: superClassName]:nil;
  NSMutableArray *actionsCopy = (actions != nil)?[NSMutableArray arrayWithArray: actions]:[NSMutableArray array];
  NSMutableArray *outletsCopy = (outlets != nil)?[NSMutableArray arrayWithArray: outlets]:[NSMutableArray array];

  // We make an autoreleased copy of all of the inputs.  This prevents changes
  // to the original objects from reflecting here. GJC

  if ([self isRootClass: superClassNameCopy] ||
      ([_classInformation objectForKey: superClassNameCopy] != nil &&
       [superClassNameCopy isEqualToString: @"FirstResponder"] == NO))
    {
      NSMutableDictionary	*classInfo;

      if (![_classInformation objectForKey: classNameCopy])
	{
	  NSEnumerator *e = [actionsCopy objectEnumerator];
	  id action = nil;
	  NSArray *superActions = [self allActionsForClassNamed: superClassNameCopy];
	  NSArray *superOutlets = [self allOutletsForClassNamed: superClassNameCopy];

	  [self touch];
	  classInfo = [[NSMutableDictionary alloc] initWithCapacity: 3];

	  // if an outlet/action is defined on the superclass before this
	  // class is added, the superclass' entry takes precedence.
	  [actionsCopy removeObjectsInArray: superActions];
	  [outletsCopy removeObjectsInArray: superOutlets];
	  
	  [classInfo setObject: outletsCopy forKey: @"Outlets"];
	  [classInfo setObject: actionsCopy forKey: @"Actions"];
	  if(superClassNameCopy != nil)
	    {
	      [classInfo setObject: superClassNameCopy forKey: @"Super"];
	    }
	  [_classInformation setObject: classInfo forKey: classNameCopy];
	  
	  // if it's a custom class add it to the list.
	  if(isCustom)
	    {
	      [_customClasses addObject: classNameCopy];
	    }

	  // copy all actions from the class imported to the first responder
	  while((action = [e nextObject]))
	    {
	      [self addAction: action forClassNamed: @"FirstResponder"];
	    }

	  result = YES;

	  // post the notification
	  [[NSNotificationCenter defaultCenter] 
	    postNotificationName: GormDidAddClassNotification
	    object: self];
	}
      else
	{
	  NSDebugLog(@"Class already exists");
	  result = NO;
	}
    }

  return result;
}

- (void) addAction: (NSString *)anAction forObject: (id)anObject
{
  [self addAction: anAction forClassNamed: [anObject className]];
}

- (void) addAction: (NSString *)action forClassNamed: (NSString *)className
{
  NSMutableDictionary *info = [_classInformation objectForKey: className]; 
  NSMutableArray *extraActions = [info objectForKey: @"ExtraActions"];
  NSMutableArray *allActions = [info objectForKey: @"AllActions"];
  NSString *anAction = [action copy];
  NSArray *subClasses = [self allSubclassesOf: className];
  NSEnumerator *en = [subClasses objectEnumerator];
  NSString *subclassName = nil;

  if (action == nil
      || className == nil)
    {
      NSLog(@"Attempt to add nil action = %@ or className = %@ to class manager", action, className);
      return;
    }
  
  // check all
  if ([allActions containsObject: anAction])
    {
      return;
    }
  
  if ([self isNonCustomClass: className])
    {
      if([_categoryClasses containsObject: className] == NO)
	{
	  [_categoryClasses addObject: className];
	}
    }
  
  if (extraActions == nil)
    {
      extraActions = [[NSMutableArray alloc] initWithCapacity: 1];
      [info setObject: extraActions forKey: @"ExtraActions"];
    }
  
  [extraActions mergeObject: anAction];
  [allActions mergeObject: anAction];

  if(![className isEqualToString: @"FirstResponder"]) 
    {
      [self addAction: anAction forClassNamed: @"FirstResponder"];
    }
  
  while((subclassName = [en nextObject]) != nil)
    {      
      NSDictionary *subInfo = [_classInformation objectForKey: subclassName];
      NSMutableArray *subAll = [subInfo objectForKey: @"AllActions"];
      [subAll mergeObject: anAction];
    }
  
  [self touch];
}

- (void) addOutlet: (NSString *)outlet forObject: (id)anObject
{
  [self addOutlet: outlet forClassNamed: [anObject className]];
}

- (void) addOutlet: (NSString *)outlet forClassNamed: (NSString *)className 
{
  NSMutableDictionary *info = [_classInformation objectForKey: className]; 
  NSMutableArray *extraOutlets = [info objectForKey: @"ExtraOutlets"];
  NSMutableArray *allOutlets = [info objectForKey: @"AllOutlets"];
  NSString *anOutlet = [outlet copy];
  NSArray *subClasses = [self allSubclassesOf: className];
  NSEnumerator *en = [subClasses objectEnumerator];
  NSString *subclassName = nil;
  
  // check all 
  if ([allOutlets containsObject: anOutlet])
    {
      return;
    }
  
  if (extraOutlets == nil)
    {
      extraOutlets = [[NSMutableArray alloc] initWithCapacity: 1];
      [info setObject: extraOutlets forKey: @"ExtraOutlets"];
    }
  
  [extraOutlets mergeObject: anOutlet];
  [allOutlets mergeObject: anOutlet];
  
  while((subclassName = [en nextObject]) != nil)
    {
      NSDictionary *subInfo = [_classInformation objectForKey: subclassName];
      NSMutableArray *subAll = [subInfo objectForKey: @"AllOutlets"];
      [subAll mergeObject: anOutlet];
    }
  
  [self touch];
}

- (void) replaceAction: (NSString *)oldAction
	    withAction: (NSString *)aNewAction
	 forClassNamed: (NSString *)className
{
  NSMutableDictionary *info = [_classInformation objectForKey: className]; 
  NSMutableArray *extraActions = [info objectForKey: @"ExtraActions"];
  NSMutableArray *actions = [info objectForKey: @"Actions"];
  NSMutableArray *allActions = [info objectForKey: @"AllActions"];
  NSString *newAction = AUTORELEASE([aNewAction copy]);
  NSEnumerator *en = [[self subClassesOf: className] objectEnumerator];
  NSString *subclassName = nil;

  if ([allActions containsObject: newAction]
    || [extraActions containsObject: newAction])
    {
      return;
    }

  // replace the action in the appropriate places.
  if ([extraActions containsObject: oldAction])
    {
      NSInteger extra_index = [extraActions indexOfObject: oldAction];
      [extraActions replaceObjectAtIndex: extra_index withObject: newAction];
    }

  if ([actions containsObject: oldAction])
    {
      NSInteger actions_index = [actions indexOfObject: oldAction];
      [actions replaceObjectAtIndex: actions_index withObject: newAction];
    }

  if ([allActions containsObject: oldAction])
    {
      NSInteger all_index = [allActions indexOfObject: oldAction];
      [allActions replaceObjectAtIndex: all_index withObject: newAction];
    }

  [self touch];

  // add the action to all of the subclasses, in the "AllActions" section...
  while((subclassName = [en nextObject]) != nil)
    {
      [self replaceAction: oldAction withAction: newAction forClassNamed: subclassName];
    }

  if(![className isEqualToString: @"FirstResponder"]) 
    {
      [self replaceAction: oldAction withAction: newAction forClassNamed: @"FirstResponder"];
    }
}

- (void) replaceOutlet: (NSString *)oldOutlet
	    withOutlet: (NSString *)aNewOutlet
	 forClassNamed: (NSString *)className
{
  NSMutableDictionary *info = [_classInformation objectForKey: className]; 
  NSMutableArray *extraOutlets = [info objectForKey: @"ExtraOutlets"];
  NSMutableArray *outlets = [info objectForKey: @"Outlets"];
  NSMutableArray *allOutlets = [info objectForKey: @"AllOutlets"];
  NSString *newOutlet = AUTORELEASE([aNewOutlet copy]);
  NSEnumerator *en = [[self subClassesOf: className] objectEnumerator];
  NSString *subclassName = nil;
      
  if ([allOutlets containsObject: newOutlet]
    || [extraOutlets containsObject: newOutlet])
    {
      return;
    }

  // replace outlets in appropriate places...
  if ([extraOutlets containsObject: oldOutlet])
    {
      NSInteger extraIndex = [extraOutlets indexOfObject: oldOutlet];
      [extraOutlets replaceObjectAtIndex: extraIndex withObject: newOutlet];
    }

  if ([outlets containsObject: oldOutlet])
    {
      NSInteger outletsIndex = [outlets indexOfObject: oldOutlet];
      [outlets replaceObjectAtIndex: outletsIndex withObject: newOutlet];
    }

  if ([allOutlets containsObject: oldOutlet])
    {
      NSInteger allIndex = [allOutlets indexOfObject: oldOutlet];
      [allOutlets replaceObjectAtIndex: allIndex withObject: newOutlet];
    }

  [self touch];

  // add the action to all of the subclasses, in the "AllActions" section...
  while((subclassName = [en nextObject]) != nil)
    {
      [self replaceOutlet: oldOutlet withOutlet: newOutlet forClassNamed: subclassName];
    }
}

- (void) removeAction: (NSString *)anAction forObject: (id)anObject
{
  [self removeAction: anAction fromClassNamed: [anObject className]];
}

- (void) removeAction: (NSString *)anAction
       fromClassNamed: (NSString *)className
{
  NSMutableDictionary	*info = [_classInformation objectForKey: className];
  NSMutableArray	*extraActions = [info objectForKey: @"ExtraActions"];
  NSMutableArray        *allActions = [info objectForKey: @"AllActions"];
  NSEnumerator *en = [[self subClassesOf: className] objectEnumerator];
  NSString *subclassName = nil;

  if ([extraActions containsObject: anAction] == YES || 
      [allActions containsObject: anAction] == YES)
    {
      NSString	*superName = [info objectForKey: @"Super"];

      if (superName != nil)
	{
	  NSArray	*superActions;

	  /*
	   * If this action is new in this class (ie not overriding an
	   * action in a parent) then we remove it from the list of all
	   * actions that the object responds to.
	   */
	  superActions = [self allActionsForClassNamed: superName];
	  if ([superActions containsObject: anAction] == NO)
	    {
	      NSMutableArray	*array = [info objectForKey: @"AllActions"];
	      NSMutableArray    *actions = [info objectForKey: @"Actions"];
	      [array removeObject: anAction];
	      [actions removeObject: anAction];
	    }
	}
      else
	{
	  NSMutableArray *array = [info objectForKey: @"AllActions"];
	  NSMutableArray *actions = [info objectForKey: @"Actions"];
	  [array removeObject: anAction];
	  [actions removeObject: anAction];
	}

      [extraActions removeObject: anAction];
      [self touch];
    }

  if([_categoryClasses containsObject: className] && [extraActions count] == 0)
    {
      [_categoryClasses removeObject: className];
    }

  if(![className isEqualToString: @"FirstResponder"]) 
    {
      [self removeAction: anAction fromClassNamed: @"FirstResponder"];
    }

  while((subclassName = [en nextObject]) != nil)
    {
      [self removeAction: anAction fromClassNamed: subclassName];
    }
}

- (void) removeOutlet: (NSString *)anOutlet forObject: (id)anObject
{
  [self removeOutlet: anOutlet fromClassNamed: [anObject className]];
}

- (void) removeOutlet: (NSString *)anOutlet fromClassNamed: (NSString *)className
{
  NSMutableDictionary	*info = [_classInformation objectForKey: className];
  NSMutableArray	*extraOutlets = [info objectForKey: @"ExtraOutlets"];
  NSMutableArray	*allOutlets = [info objectForKey: @"AllOutlets"];
  NSEnumerator *en = [[self subClassesOf: className] objectEnumerator];
  NSString *subclassName = nil;

  if ([extraOutlets containsObject: anOutlet] == YES
    || [allOutlets containsObject: anOutlet] == YES)
    {
      NSString	*superName = [info objectForKey: @"Super"];

      if (superName != nil)
	{
	  NSArray	*superOutlets;

	  // remove the outlet from the other arrays...
	  superOutlets = [self allOutletsForClassNamed: superName];
	  if ([superOutlets containsObject: anOutlet] == NO)
	    {
	      NSMutableArray	*array = [info objectForKey: @"AllOutlets"];
	      NSMutableArray    *actions = [info objectForKey: @"Outlets"];
	      [array removeObject: anOutlet];
	      [actions removeObject: anOutlet];
	    }
	}
      else
	{
	  NSMutableArray *array = [info objectForKey: @"AllOutlets"];
	  NSMutableArray *actions = [info objectForKey: @"Outlets"];
	  [array removeObject: anOutlet];
	  [actions removeObject: anOutlet];
	}

      [extraOutlets removeObject: anOutlet];
      [self touch];
    }

  while((subclassName = [en nextObject]) != nil)
    {
      [self removeOutlet: anOutlet fromClassNamed: subclassName];
    }
}


- (NSArray *) allActionsForObject: (id)obj
{
  NSString	*className;
  NSArray	*actions;
  Class		 theClass = [obj class];
  NSString      *customClassName = [self customClassForObject: obj];
  
  NSDebugLog(@"** ACTIONS");
  NSDebugLog(@"Object: %@",obj);
  NSDebugLog(@"Custom class: %@",customClassName);
  if (customClassName != nil)
    {
      // if the object has been mapped to a custom class, then
      // get the information for it.
      className = customClassName;
    }
  else if (theClass == [GormFirstResponder class])
    {
      className = @"FirstResponder";
    }
  else if (theClass == [GormFilesOwner class])
    {
      className = [(GormFilesOwner*)obj className];
    }
  else if ([obj isKindOfClass: [GSNibItem class]] == YES)
    {
      // this adds support for custom objects
      className = [obj className];
    }
  else if ([obj isKindOfClass: [GormClassProxy class]] == YES)
    {
      // this adds support for class proxies
      className = [obj className];
    }
  else if ([obj isKindOfClass: [GormCustomView class]] == YES)
    {
      // this adds support for custom views
      className = [obj className];
    }
  else
    {
      className = NSStringFromClass(theClass);
    }
  if (className == nil)
    {
      // NSLog(@"attempt to get actions for non-existent class (%@)",	
      //	[obj class]);
      return nil;
    }

  actions = [self allActionsForClassNamed: className];
  while (actions == nil && (theClass = class_getSuperclass(theClass)) != nil
    && theClass != [NSObject class])
    {
      className = NSStringFromClass(theClass);
      actions = [self allActionsForClassNamed: className];
    }

  NSDebugLog(@"class=%@ actions=%@",className,actions);
  return actions;
}

- (NSArray *) allActionsForClassNamed: (NSString *)className
{
  NSMutableDictionary	*info = [_classInformation objectForKey: className];

  if (info != nil)
    {
      NSMutableArray	*allActions = [info objectForKey: @"AllActions"];

      if (allActions == nil)
	{
	  NSString	*superName = [info objectForKey: @"Super"];
	  NSArray	*actions = [info objectForKey: @"Actions"];
	  NSArray       *extraActions = [info objectForKey: @"ExtraActions"];
	  NSArray	*superActions;

	  if (superName == nil || [className isEqual: @"FirstResponder"])
	    {
	      superActions = nil;
	    }
	  else
	    {
	      superActions = [self allActionsForClassNamed: superName];
	    }

	  if (superActions == nil)
	    {
	      if (actions == nil)
		{
		  allActions = [[NSMutableArray alloc] init];
		}
	      else
		{
		  allActions = [actions mutableCopy];
		}

	      [allActions mergeObjectsFromArray: extraActions]; 
	    }
	  else
	    {
	      allActions = [superActions mutableCopy];
	      [allActions mergeObjectsFromArray: actions];
	      [allActions mergeObjectsFromArray: extraActions];
	    }

	  [info setObject: allActions forKey: @"AllActions"];
	  RELEASE(allActions);
	}
      return AUTORELEASE([allActions copy]);
    }
  return nil;
}

- (NSArray *) allCustomClassNames
{
  // return [_customClassMap allKeys];
  return _customClasses;
}

- (NSArray *) allClassNames
{
  return [[_classInformation allKeys] sortedArrayUsingSelector: @selector(compare:)];
}

- (NSArray *) allOutletsForObject: (id)obj
{
  NSString	*className;
  NSArray	*outlets;
  Class		theClass = [obj class];
  NSString      *customClassName = [self customClassForObject: obj];

  if (customClassName != nil)
    {
      // if the object has been mapped to a custom class, then
      // get the information for it.
      className = customClassName; 
    }
  else if (theClass == [GormFirstResponder class])
    {
      return nil;
    }
  else if (theClass == [GormFilesOwner class])
    {
      className = [(GormFilesOwner*)obj className];
    }
  else if ([obj isKindOfClass: [GSNibItem class]] == YES)
    {
      // this adds support for custom objects
      className = [(id)obj className];
    }
  else if ([obj isKindOfClass: [GormClassProxy class]] == YES)
    {
      // this adds support for class proxies
      className = [(id)obj className];
    }
  else if ([obj isKindOfClass: [GormCustomView class]] == YES)
    {
      // this adds support for custom views
      className = [(id)obj className];
    }
  else
    {
      className = NSStringFromClass(theClass);
    }

  if (className == nil)
    {
      NSLog(@"attempt to get outlets for non-existent class (%@)",
      	[obj class]);
      return nil;
    }

  outlets = [self allOutletsForClassNamed: className];
  while (outlets == nil && (theClass = class_getSuperclass(theClass)) != nil
    && theClass != [NSObject class])
    {
      className = NSStringFromClass(theClass);
      outlets = [self allOutletsForClassNamed: className];
    }
  return outlets;
}

- (NSArray *) allOutletsForClassNamed: (NSString *)className;
{
  NSMutableDictionary	*info = [_classInformation objectForKey: className];

  if (info != nil)
    {
      NSMutableArray	*allOutlets = [info objectForKey: @"AllOutlets"];

      if (allOutlets == nil)
	{
	  NSString	*superName = [info objectForKey: @"Super"];
	  NSArray	*outlets = [info objectForKey: @"Outlets"];
	  NSArray       *extraOutlets = [info objectForKey: @"ExtraOutlets"];
	  NSArray	*superOutlets;

	  if (superName == nil)
	    {
	      superOutlets = nil;
	    }
	  else
	    {
	      superOutlets = [self allOutletsForClassNamed: superName];
	    }

	  if (superOutlets == nil)
	    {
	      if (outlets == nil)
		{
		  allOutlets = [[NSMutableArray alloc] init];
		}
	      else
		{
		  allOutlets = [outlets mutableCopy];
		}

	      [allOutlets mergeObjectsFromArray: extraOutlets]; 
	    }
	  else
	    {
	      allOutlets = [superOutlets mutableCopy];
	      [allOutlets mergeObjectsFromArray: outlets];
	      [allOutlets mergeObjectsFromArray: extraOutlets];
	    }

	  [info setObject: allOutlets forKey: @"AllOutlets"];
	  RELEASE(allOutlets);
	}
      return AUTORELEASE([allOutlets copy]);
    }
  return nil;
}

- (NSMutableDictionary*) classInfoForClassName: (NSString *)className
{
  NSMutableDictionary	*info;

  info = [_classInformation objectForKey: className];
  if (info == nil)
    {
      Class	theClass = NSClassFromString(className);

      if (theClass != nil)
	{
	  theClass = class_getSuperclass(theClass);
	  if (theClass != nil && theClass != [NSObject class])
	    {
	      NSString			*name;
	      NSMutableDictionary	*dict;

	      name = NSStringFromClass(theClass);
	      dict = [self classInfoForClassName: name];
	      if (dict != nil)
		{
		  id	o;

		  info = [[NSMutableDictionary alloc] initWithCapacity: 3];
		  [info setObject: name forKey: @"Super"];
		  o = [[self allActionsForClassNamed: name] mutableCopy];
		  [info setObject: o forKey: @"AllActions"];
		  o = [[self allOutletsForClassNamed: name] mutableCopy];
		  [info setObject: o forKey: @"AllOutlets"];
		  [_classInformation setObject: info forKey: className];
		}
	    }
	}
    }
  return info;
}

- (NSMutableDictionary*) classInfoForObject: (id)obj
{
  NSString		*className;
  Class			theClass = [obj class];

  if (theClass == [GormFilesOwner class])
    {
      className = [(GormFilesOwner*)obj className];
    }
  else if ([obj isKindOfClass: [GSNibItem class]] == YES)
    {
      // this adds support for custom objects
      className = [(id)obj className];
    }
  else if ([obj isKindOfClass: [GormClassProxy class]] == YES)
    {
      // this adds support for class proxies
      className = [(id)obj className];
    }
  else if ([obj isKindOfClass: [GormCustomView class]] == YES)
    {
      // this adds support for custom views
      className = [(id)obj className];
    }
  else
    {
      className = NSStringFromClass(theClass);
    }

  if (className == nil)
    {
      NSLog(@"attempt to get outlets for non-existent class (%@)",
      	[obj class]);
      return nil;
    }
  return [self classInfoForClassName: className];
}

- (BOOL) actionExists: (NSString *)action
	 onClassNamed: (NSString *)className
{
  NSArray *actions = [self allActionsForClassNamed: className];
  return [actions containsObject: action];
}

- (BOOL) outletExists: (NSString *)outlet
	 onClassNamed: (NSString *)className
{
  NSArray *outlets = [self allOutletsForClassNamed: className];
  return [outlets containsObject: outlet];
}

- (void) dealloc
{
  RELEASE(_classInformation);
  RELEASE(_customClassMap);
  [super dealloc];
}

- (NSArray *) extraActionsForObject: (id)anObject
{
  NSMutableDictionary	*info = [self classInfoForObject: anObject];

  return [info objectForKey: @"ExtraActions"];
}

- (NSArray *) extraOutletsForObject: (id)anObject
{
  NSMutableDictionary	*info = [self classInfoForObject: anObject];

  return [info objectForKey: @"ExtraOutlets"];
}

- (void) allSubclassesOf: (NSString *)superclass
      referenceClassList: (NSArray *)classList
	       intoArray: (NSMutableArray *)array
{
  NSEnumerator *cen   = [classList objectEnumerator];
  id object = nil;

  while ((object = [cen nextObject]))
    {
      NSDictionary *dictForClass = [_classInformation objectForKey: object];
      NSString *superClassName = [dictForClass objectForKey: @"Super"];
      if ([superClassName isEqual: superclass] || 
	  (superClassName == nil && superclass == nil))
	{
	  [array addObject: object];
	  [self allSubclassesOf: object
		referenceClassList: classList
		intoArray: array];
	}
    }
}

- (NSArray *) allSubclassesOf: (NSString *)superClass
{
  NSMutableArray *array = [NSMutableArray array];
  
  [self allSubclassesOf: superClass
	referenceClassList: [_classInformation allKeys]
	intoArray: array];

  return [array sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
}

- (NSArray *) allCustomSubclassesOf: (NSString *)superClass
{
  NSMutableArray *array = [NSMutableArray array];
  
  [self allSubclassesOf: superClass
	referenceClassList: _customClasses
	intoArray: array];

  return [array sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
}

- (NSArray *) customSubClassesOf: (NSString *)superclass
{
  NSEnumerator *cen   = [_customClasses objectEnumerator];
  id object = nil;
  NSMutableArray *subclasses = [NSMutableArray array];

  while ((object = [cen nextObject]))
    {
      NSDictionary *dictForClass = [_classInformation objectForKey: object];

      if ([[dictForClass objectForKey: @"Super"] isEqual: superclass])
	{
	  [subclasses addObject: object];
	}
    }
      
  return subclasses;
}

- (NSArray *) subClassesOf: (NSString *)superclass
{
  NSArray *allClasses = [_classInformation allKeys];
  NSEnumerator *cen   = [allClasses objectEnumerator];
  id object = nil;
  NSMutableArray *subclasses = [NSMutableArray array];

  while ((object = [cen nextObject]))
    {
      NSDictionary *dictForClass = [_classInformation objectForKey: object];
      NSString *superClassName = [dictForClass objectForKey: @"Super"];
      if ([superClassName isEqual: superclass] || 
	  (superClassName == nil && superclass == nil))
	{  
	  [subclasses addObject: object];
	}
    }
      
  return [subclasses sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
}

- (void) removeClassNamed: (NSString *)className
{
  if ([_customClasses containsObject: className])
    {
      NSEnumerator *en = [_customClassMap keyEnumerator];
      id object = nil;
      id owner = nil;

      [_customClasses removeObject: className];
      
      while((object = [en nextObject]) != nil)
	{
	  id customClassName = [_customClassMap objectForKey: object];
	  if(customClassName != nil)
	    {
	      if([className isEqualToString: customClassName])
		{
		  NSDebugLog(@"Deleting object -> customClass association %@ -> %@",object,customClassName);
		  [_customClassMap removeObjectForKey: object];
		}
	    }
	}

      // get the owner and reset the class name to NSApplication.
      owner = [_document objectForName: @"NSOwner"];
      if([className isEqual: [owner className]])
	{
	  [owner setClassName: @"NSApplication"];
	}
    }

  [_classInformation removeObjectForKey: className];
  [self touch];

  [[NSNotificationCenter defaultCenter] 
    postNotificationName: GormDidDeleteClassNotification
    object: self];
}

- (BOOL) renameClassNamed: (NSString *)oldName newName: (NSString *)newName
{
  id classInfo = [_classInformation objectForKey: oldName];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSString *name = [newName copy];

  NSDebugLog(@"Old name %@, new name %@",oldName,name);

  if (classInfo != nil && [_classInformation objectForKey: name] == nil)
    {
      NSUInteger index = 0;
      NSArray *subclasses = [self subClassesOf: oldName];

      RETAIN(classInfo); // prevent loss of the information...
      [_classInformation removeObjectForKey: oldName];
      [_classInformation setObject: classInfo forKey: name];
      RELEASE(classInfo); // release our hold on it.

      if ((index = [_customClasses indexOfObject: oldName]) != NSNotFound)
	{
	  NSEnumerator *en = [_customClassMap keyEnumerator];
	  NSEnumerator *cen = [subclasses objectEnumerator];
	  id sc = nil;
	  id object = nil;

	  NSDebugLog(@"replacing object with %@, %@",name, _customClasses);
	  [_customClasses replaceObjectAtIndex: index withObject: name];
	  NSDebugLog(@"replaced object with %@, %@",name, _customClasses);

	  // show the class map before...
	  NSDebugLog(@"_customClassMap = %@",_customClassMap);
	  while((object = [en nextObject]) != nil)
	    {
	      id customClassName = [_customClassMap objectForKey: object];
	      if(customClassName != nil)
		{
		  if([oldName isEqualToString: customClassName])
		    {
		      NSDebugLog(@"Replacing object -> customClass association %@ -> %@",object,customClassName);
		      [_customClassMap setObject: name forKey: object];
		    }
		}
	    }
	  NSDebugLog(@"New _customClassMap = %@",_customClassMap); // and after

	  // Iterate over the list of subclasses and replace their referece with the new
	  // name.
	  while((sc = [cen nextObject]) != nil)
	    {
	      [self setSuperClassNamed: name
		    forClassNamed: sc];
	    }

	  [self touch];
	}
      else
	NSLog(@"customClass not found %@",oldName);

      [nc postNotificationName: IBClassNameChangedNotification object: self];
      return YES;
    }
  else return NO;
}

- (NSString *)parentOfClass: (NSString *)aClass
{
  NSDictionary *dictForClass = [_classInformation objectForKey: aClass];
  return [dictForClass objectForKey: @"Super"];
}

- (NSData *) nibData
{
  NSMutableDictionary	*dict = nil;
  NSMutableArray        *classes = nil;
  NSEnumerator		*enumerator = nil;
  NSMutableArray        *cats = [NSMutableArray arrayWithArray: _categoryClasses];
  id			name = nil;

  // save all custom classes....
  dict = [NSMutableDictionary dictionary];
  [dict setObject: @"1" forKey: @"IBVersion"];
  classes = [NSMutableArray array];

  // build IBClasses...
  enumerator = [_customClasses objectEnumerator];
  while ((name = [enumerator nextObject]) != nil)
    {
      NSDictionary		*classInfo;
      NSMutableDictionary	*newInfo;
      id			obj;
      id                        extraObj;

      // get the info...
      classInfo = [_classInformation objectForKey: name];

      newInfo = [[NSMutableDictionary alloc] init];
      [newInfo setObject: name forKey: @"CLASS"];

      // superclass...
      obj = [classInfo objectForKey: @"Super"];
      if (obj != nil)
	{
	  [newInfo setObject: obj forKey: @"SUPERCLASS"];
	}

      // outlets...
      obj = [classInfo objectForKey: @"Outlets"];
      extraObj = [classInfo objectForKey: @"ExtraOutlets"];
      if (obj && extraObj)
	{
	  obj = [obj arrayByAddingObjectsFromArray: extraObj];
	}
      else if (extraObj)
	{
	  obj = extraObj;
	}
      if (obj != nil && [obj count] > 0)
	{
	  NSMutableDictionary *outletDict = [NSMutableDictionary dictionary];
	  NSEnumerator *oen = [obj objectEnumerator];
	  id outlet = nil;

	  while((outlet = [oen nextObject]) != nil)
	    {
	      [outletDict setObject: @"id" forKey: outlet];
	    }

	  [newInfo setObject: outletDict forKey: @"OUTLETS"];
	}

      // actions...
      obj = [classInfo objectForKey: @"Actions"];
      extraObj = [classInfo objectForKey: @"ExtraActions"];
      if (obj && extraObj)
	{
	  obj = [obj arrayByAddingObjectsFromArray: extraObj];
	}
      else if (extraObj)
	{
	  obj = extraObj;
	}
      if (obj != nil && [obj count] > 0)
	{	  
	  NSMutableDictionary *actionDict = [NSMutableDictionary dictionary];
	  NSEnumerator *aen = [obj objectEnumerator];
	  id action = nil;

	  while((action = [aen nextObject]) != nil)
	    {
	      NSString *actionName = nil;
	      NSScanner *scanner = [NSScanner scannerWithString: action]; 
	      
	      if ([scanner scanUpToString: @":" intoString: &actionName])
          [actionDict setObject: @"id" forKey: actionName];
	    }

	  [newInfo setObject: actionDict forKey: @"ACTIONS"];
	}
      
      [newInfo setObject: @"ObjC" forKey: @"LANGUAGE"];

      [classes addObject: newInfo];
    }

  // Save all categories on existing, non-custom classes....
  // Always save the FirstResponder....
  if([cats containsObject: @"FirstResponder"] == NO)
    {
      [cats addObject: @"FirstResponder"];
    }
  enumerator = [cats objectEnumerator];
  while((name = [enumerator nextObject]) != nil)
    {
      NSDictionary  *classInfo;
      NSMutableDictionary  *newInfo;
      id obj;

      // get the info...
      classInfo = [_classInformation objectForKey: name];
      newInfo = [NSMutableDictionary dictionary];
      [newInfo setObject: name forKey: @"CLASS"];

      // superclass...
      obj = [classInfo objectForKey: @"Super"];
      if (obj != nil)
	{
	  [newInfo setObject: obj forKey: @"SUPERCLASS"];
	}

      // actions...
      obj = [classInfo objectForKey: @"ExtraActions"];
      if (obj != nil && [obj count] > 0)
	{
	  NSMutableDictionary *actionDict = [NSMutableDictionary dictionary];
	  NSEnumerator *aen = [obj objectEnumerator];
	  id action = nil;

	  while((action = [aen nextObject]) != nil)
	    {
	      NSString *actionName = nil;
	      NSScanner *scanner = [NSScanner scannerWithString: action]; 
	      
	      if ([scanner scanUpToString: @":" intoString: &actionName])
          [actionDict setObject: @"id" forKey: actionName];
	    }

	  [newInfo setObject: actionDict forKey: @"ACTIONS"];
	}
      
      [newInfo setObject: @"ObjC" forKey: @"LANGUAGE"];

      [classes addObject: newInfo];
    }

  [dict setObject: classes forKey: @"IBClasses"];

  return [NSPropertyListSerialization dataFromPropertyList: dict 
				      format: NSPropertyListOpenStepFormat
				      errorDescription: NULL];
}

- (NSData *) data
{
  NSMutableDictionary	*ci = nil;
  NSEnumerator		*enumerator = nil;
  id			key = nil;

  // save all custom classes....
  ci = [NSMutableDictionary dictionary];
  enumerator = [_customClasses objectEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      NSDictionary		*classInfo;
      NSMutableDictionary	*newInfo;
      id			obj;
      id                        extraObj;

      // get the info...
      classInfo = [_classInformation objectForKey: key];
      newInfo = [[NSMutableDictionary alloc] init];
      [ci setObject: newInfo forKey: key];

      // superclass...
      obj = [classInfo objectForKey: @"Super"];
      if (obj != nil)
	{
	  [newInfo setObject: obj forKey: @"Super"];
	}

      // outlets...
      obj = [classInfo objectForKey: @"Outlets"];
      extraObj = [classInfo objectForKey: @"ExtraOutlets"];
      if (obj && extraObj)
	{
	  obj = [obj arrayByAddingObjectsFromArray: extraObj];
	}
      else if (extraObj)
	{
	  obj = extraObj;
	}
      if (obj != nil)
	{
	  [newInfo setObject: obj forKey: @"Outlets"];
	}

      // actions...
      obj = [classInfo objectForKey: @"Actions"];
      extraObj = [classInfo objectForKey: @"ExtraActions"];
      if (obj && extraObj)
	{
	  obj = [obj arrayByAddingObjectsFromArray: extraObj];
	}
      else if (extraObj)
	{
	  obj = extraObj;
	}
      if (obj != nil)
	{
	  [newInfo setObject: obj forKey: @"Actions"];
	}
    }

  // save all categories on existing, non-custom classes....
  enumerator = [_categoryClasses objectEnumerator];
  while((key = [enumerator nextObject]) != nil)
    {
      NSDictionary  *classInfo;
      NSMutableDictionary  *newInfo;
      id obj;

      // get the info...
      classInfo = [_classInformation objectForKey: key];
      newInfo = [NSMutableDictionary dictionary];
      [ci setObject: newInfo forKey: key];

      // superclass...
      obj = [classInfo objectForKey: @"Super"];
      if (obj != nil)
	{
	  [newInfo setObject: obj forKey: @"Super"];
	}

      // actions...
      obj = [classInfo objectForKey: @"ExtraActions"];
      if (obj != nil)
	{
	  [newInfo setObject: obj forKey: @"Actions"];
	}
    }

  // add the extras...
  [ci setObject: @"Do NOT change this file, Gorm maintains it"
      forKey: @"## Comment"];

  return [NSPropertyListSerialization dataFromPropertyList: ci 
				      format: NSPropertyListOpenStepFormat
				      errorDescription: NULL];
}

- (BOOL) saveToFile: (NSString *)path
{
  return [[self data] writeToFile: path atomically: YES];
}

- (BOOL) loadFromFile: (NSString *)path
{
  NSDictionary 	        *dict;
  NSEnumerator		*enumerator;
  NSString		*key;

  NSDebugLog(@"Load from file %@",path);

  dict = [NSDictionary dictionaryWithContentsOfFile: path];
  if (dict == nil)
    {
      NSLog(@"Could not load classes dictionary");
      return NO;
    }

  /*
   * Convert property-list data into a mutable structure.
   */
  ASSIGN(_classInformation, [[NSMutableDictionary alloc] init]);

  // iterate over all entries..
  enumerator = [dict keyEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      NSDictionary	    *classInfo = [dict objectForKey: key];
      NSMutableDictionary   *newInfo;
      id		    obj;
      
      newInfo = [[NSMutableDictionary alloc] init];
      
      [_classInformation setObject: newInfo forKey: key];
      
      // superclass
      obj = [classInfo objectForKey: @"Super"];
      if (obj != nil)
	{
	  [newInfo setObject: obj forKey: @"Super"];
	}
      
      // outlets
      obj = [classInfo objectForKey: @"Outlets"];
      if (obj != nil)
	{
	  obj = [obj mutableCopy];
	  [obj sortUsingSelector: @selector(compare:)];
	  [newInfo setObject: obj forKey: @"Outlets"];
	  RELEASE(obj);
	}
      
      // actions
      obj = [classInfo objectForKey: @"Actions"];
      if (obj != nil)
	{
	  obj = [obj mutableCopy];
	  [obj sortUsingSelector: @selector(compare:)];
	  [newInfo setObject: obj forKey: @"Actions"];
	  RELEASE(obj);
	}
    }
  return YES;
}

- (BOOL) loadNibFormatCustomClassesWithDict: (NSDictionary *)dict
{
  NSArray *classes = [dict objectForKey: @"IBClasses"];
  NSEnumerator *en = [classes objectEnumerator];
  BOOL result = NO;
  id cls = nil;

  // If there are no classes to add, return gracefully.
  if([classes count] == 0)
    {
      return YES;
    }

  while((cls = [en nextObject]) != nil)
    {
      NSString *className = [cls objectForKey: @"CLASS"];
      NSString *superClass = [cls objectForKey: @"SUPERCLASS"];
      NSDictionary *actionDict = [cls objectForKey: @"ACTIONS"];
      NSDictionary *outletDict = [cls objectForKey: @"OUTLETS"];
      NSMutableArray *actions = [NSMutableArray array];
      NSArray *outlets = [outletDict allKeys];
      NSEnumerator *aen = [actionDict keyEnumerator];
      id action = nil;

      //
      // Convert action format.
      //
      while((action = [aen nextObject]) != nil)
	{
	  NSString *aname = [action stringByAppendingString: @":"];
	  [actions addObject: aname];
	}

      //
      // If the class is known, add the actions/outlets, if it's
      // not, then add all of the information.
      //
      if([self isKnownClass: className])
	{
	  [self addActions: actions forClassNamed: className];
	  [self addOutlets: outlets forClassNamed: className];
	  result = YES;
	}
      else
	{
	  result = [self addClassNamed: className
			 withSuperClassNamed: superClass
			 withActions: actions
			 withOutlets: outlets];
	}
    }

  return result;
}

- (BOOL) loadNibFormatCustomClassesWithData: (NSData *)data
{
  NSString *dictString = AUTORELEASE([[NSString alloc] initWithData: data encoding: NSASCIIStringEncoding]);
  NSDictionary *dict = [dictString propertyList];
  return [self loadNibFormatCustomClassesWithDict: dict];
}

// this method will load the custom classes and merge them with the
// Class information loaded at initialization time.
- (BOOL) loadCustomClasses: (NSString *)path
{
  NSMutableDictionary  *dict;
  BOOL result = NO;

  NSDebugLog(@"Load custom classes from file %@",path);

  dict = [NSMutableDictionary dictionaryWithContentsOfFile: path];
  if (dict == nil)
    {
      NSLog(@"Could not load custom classes dictionary");
      return NO;
    }

  if (_classInformation == nil)
    {
      NSLog(@"Default classes file not loaded");
      return NO;
    }
  
  if([path isEqualToString: @"data.classes"])
    {
      result = [self loadCustomClassesWithDict: dict];
    }
  else if([path isEqualToString: @"classes.nib"])
    {
      result = [self loadNibFormatCustomClassesWithDict: dict];
    }
  return result;
}

- (BOOL) loadCustomClassesWithData: (NSData *)data
{
  NSString *dictString = AUTORELEASE([[NSString alloc] initWithData: data encoding: NSASCIIStringEncoding]);
  NSDictionary *dict = [dictString propertyList];
  return [self loadCustomClassesWithDict: dict];
}

- (BOOL) loadCustomClassesWithDict: (NSDictionary *)dict
{
  NSEnumerator *en = nil;
  id            key = nil; 

  // Iterate over the set of classes, if it's in the _classInformation 
  // list, it's a category, if it's not it's a custom class.
  en = [dict keyEnumerator];
  while((key = [en nextObject]) != nil)
    {
      id class_dict = [dict objectForKey: key];

      // Class information is always a dictionary, other information, such as 
      // comments or version numbers, will appear as strings.
      if([class_dict isKindOfClass: [NSDictionary class]])
	{
	  NSMutableDictionary *classDict = (NSMutableDictionary *)class_dict;
	  NSMutableDictionary *info = [_classInformation objectForKey: key]; 
	  if(info == nil)
	    {
	      [_customClasses addObject: key];
	      [_classInformation setObject: classDict forKey: key];
	    }
	  else
	    {
	      NSMutableArray *actions = [classDict objectForKey: @"Actions"];
	      NSMutableArray *origActions = [info objectForKey: @"Actions"];
	      NSMutableArray *allActions = nil;
	      
	      // remove any duplicate actions...
	      if(origActions != nil)
		{
		  allActions = [NSMutableArray arrayWithArray: origActions];
		  
		  [actions removeObjectsInArray: origActions];
		  [allActions addObjectsFromArray: actions];
		  [info setObject: allActions forKey: @"AllActions"];
		}
	      
	      // if there are any action methods left after the process above,
	      // add it, otherwise don't.
	      if([actions count] > 0)
		{
		  [_categoryClasses addObject: key];
		  [info setObject: actions forKey: @"ExtraActions"];
		}
	    }
	}
    }

  return YES;
}

- (BOOL) isCustomClass: (NSString *)className
{
  return ([_customClasses indexOfObject: className] != NSNotFound); 
}

- (BOOL) isNonCustomClass: (NSString *)className
{
  return !([self isCustomClass: className]); 
}

- (BOOL) isCategoryForClass: (NSString *)className
{
  return ([_categoryClasses indexOfObject: className] != NSNotFound); 
}

- (BOOL) isAction: (NSString *)actionName onCategoryForClassNamed: (NSString *)className
{
  NSDictionary *info = [_classInformation objectForKey: className];
  BOOL result = NO;

  if([self isCategoryForClass: className])
    {
      if(info != nil)
	{
	  NSArray *extra = [info objectForKey: @"ExtraActions"];
	  if(extra != nil)
	    {
	      result = [extra containsObject: actionName];
	    }
	}
    }

  return result;
}

- (BOOL) isKnownClass: (NSString *)className
{
  return ([_classInformation objectForKey: className] != nil);
}

- (BOOL) setSuperClassNamed: (NSString *)superclass
	      forClassNamed: (NSString *)subclass
{
  NSArray *cn = [self allClassNames];

  if (superclass != nil 
      && subclass != nil 
      && [cn containsObject: subclass]
      && ([cn containsObject: superclass] || [self isRootClass: superclass])
      && [self isSuperclass: subclass linkedToClass: superclass] == NO)
    {
      NSMutableDictionary	*info;

      info = [_classInformation objectForKey: subclass];
      if (info != nil)
	{
	  // remove actions/outlets inherited from superclasses...
	  [info removeObjectForKey: @"AllActions"];
	  [info removeObjectForKey: @"AllOutlets"];

	  // change the parent of the class...
	  [info setObject: superclass forKey: @"Super"];

	  // recalculate the actions/outlets...
	  [self allActionsForClassNamed: subclass];
	  [self allOutletsForClassNamed: subclass];
	  
	  // return success.
	  return YES;
	}
      else
	{
	  return NO;
	}
    }

  return NO;
}

- (NSString *) superClassNameForClassNamed: (NSString *)className
{
  NSMutableDictionary	*info = [_classInformation objectForKey: className];
  NSString		*superName = nil;

  if (info != nil)
    {
      superName = [info objectForKey: @"Super"];
    }

  return superName;
}

- (BOOL) isSuperclass: (NSString *)superclass linkedToClass: (NSString *)subclass
{
  NSString *ssclass;

  if (superclass == nil || subclass == nil)
    {
      return NO;
    }

  ssclass = [self superClassNameForClassNamed: subclass];
  if ([superclass isEqualToString: ssclass])
    {
      return YES;
    }

  return [self isSuperclass: superclass linkedToClass: ssclass];
}

- (NSDictionary *) dictionaryForClassNamed: (NSString *)className
{
  NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary: [_classInformation objectForKey: className]];

  if(info != nil)
    {
      [info removeObjectForKey: @"AllActions"];
      [info removeObjectForKey: @"AllOutlets"];
    }

  return info;
}


/*
 *  create .m & .h files for a class
 */
- (BOOL) makeSourceAndHeaderFilesForClass: (NSString *)className 
				 withName: (NSString *)sourcePath
				      and: (NSString *)headerPath
{
  NSMutableString	*headerFile;
  NSMutableString	*sourceFile;
  NSData		*headerData;
  NSData		*sourceData;
  NSMutableArray	*outlets;
  NSMutableArray	*actions;
  NSString		*actionName;
  int			i;
  int			n;
  NSDictionary          *classInfo = [_classInformation objectForKey: className];

  headerFile = [NSMutableString stringWithCapacity: 200];
  sourceFile = [NSMutableString stringWithCapacity: 200];

  // add all outlets and actions for the current class to the list...
  outlets = [[classInfo objectForKey: @"Outlets"] mutableCopy];
  [outlets addObjectsFromArray: [classInfo objectForKey: @"ExtraOutlets"]]; 
  actions = [[classInfo objectForKey: @"Actions"] mutableCopy]; 
  [actions addObjectsFromArray: [classInfo objectForKey: @"ExtraActions"]]; 
  
  // header file comments...
  [headerFile appendString: @"/* All rights reserved */\n\n"];
  [sourceFile appendString: @"/* All rights reserved */\n\n"];
  [headerFile appendString: [NSString stringWithFormat: @"#ifndef %@_H_INCLUDE\n", className]];
  [headerFile appendString: [NSString stringWithFormat: @"#define %@_H_INCLUDE\n\n", className]];
  [headerFile appendString: @"#import <AppKit/AppKit.h>\n\n"];
  if ([[headerPath stringByDeletingLastPathComponent]
    isEqualToString: [sourcePath stringByDeletingLastPathComponent]])
    {
      [sourceFile appendFormat: @"#import \"%@\"\n\n", 
	[headerPath lastPathComponent]];
    }
  else
    {
      [sourceFile appendFormat: @"#import \"%@\"\n\n", 
	headerPath];      
    }
  [headerFile appendFormat: @"@interface %@ : %@\n{\n", className,
	      [self superClassNameForClassNamed: className]];
  [sourceFile appendFormat: @"@implementation %@\n\n", className];
  
  n = [outlets count]; 
  for (i = 0; i < n; i++)
    {
      [headerFile appendFormat: @"  IBOutlet id %@;\n", [outlets objectAtIndex: i]];
    }
  [headerFile appendFormat: @"}\n\n"];

  n = [actions count]; 
  for (i = 0; i < n; i++)
    {
      actionName = [actions objectAtIndex: i];
      [headerFile appendFormat: @"- (IBAction) %@ (id)sender;\n", actionName];
      [sourceFile appendFormat:
	@"- (IBAction) %@ (id)sender\n"
	@"{\n"
	@"}\n"
	@"\n"
	, [actions objectAtIndex: i]];
    }
  [headerFile appendFormat: @"\n@end\n\n"];
  [headerFile appendString: [NSString stringWithFormat: @"#endif // %@_H_INCLUDE\n", className]];
  [sourceFile appendFormat: @"@end\n"];

  headerData = [headerFile dataUsingEncoding:
    [NSString defaultCStringEncoding]];
  sourceData = [sourceFile dataUsingEncoding:
    [NSString defaultCStringEncoding]];

  [headerData writeToFile: headerPath atomically: NO];

  [[NSDistributedNotificationCenter defaultCenter]
    postNotificationName: @"GormCreateFileNotification"
    object: headerPath];

  [sourceData writeToFile: sourcePath atomically: NO];

  [[NSDistributedNotificationCenter defaultCenter]
    postNotificationName: @"GormCreateFileNotification"
    object: sourcePath];

  return YES;
}

- (BOOL) parseHeader: (NSString *)headerPath
{
  OCHeaderParser *ochp = [[OCHeaderParser alloc] initWithContentsOfFile: headerPath];
  BOOL result = NO;
  
  if(ochp != nil)
    {
      result = [ochp parse];
      if(result)
	{
	  NSArray *classes = [ochp classes];
	  NSEnumerator *en = [classes objectEnumerator];
	  OCClass *cls = nil;
	  
	  while((cls = (OCClass *)[en nextObject]) != nil)
	    {
	      NSArray *methods = [cls methods];
	      NSArray *ivars = [cls ivars];
	      NSArray *properties = [cls properties];
	      NSString *superClass = [cls superClassName]; // == nil) ? @"NSObject":[cls superClassName];
	      NSString *className = [cls className];
	      NSEnumerator *ien = [ivars objectEnumerator];
	      NSEnumerator *men = [methods objectEnumerator];
	      NSEnumerator *pen = [properties objectEnumerator];
	      OCMethod *method = nil;
	      OCIVar *ivar = nil;
	      OCProperty *property = nil;
	      NSMutableArray *actions = [NSMutableArray array];
	      NSMutableArray *outlets = [NSMutableArray array];
	      
	      // skip it, if it's category...  for now.  TODO: make categories work...
	      while((method = (OCMethod *)[men nextObject]) != nil)
		{
		  if([method isAction])
		    {
		      [actions addObject: [method name]];
		    }
		}
	      
	      while((ivar = (OCIVar *)[ien nextObject]) != nil)
		{
		  if([ivar isOutlet])
		    {
		      [outlets addObject: [ivar name]];
		    }
		}
	      
	      while((property = (OCProperty *)[pen nextObject]) != nil)
		{
		  if([property isOutlet])
		    {
		      [outlets addObject: [property name]];
		    }
		}

	      NSLog(@"outlets = %@", outlets);
	      
	      if(([self isKnownClass: superClass] || superClass == nil) && 
		 [cls isCategory] == NO)
		{
		  if([self isKnownClass: className])
		    {
		      id<GormAppDelegate> delegate = (id<GormAppDelegate>)[NSApp delegate];		      
		      BOOL result = [delegate shouldBreakConnectionsReparsingClass: className];
		      
		      if (result == YES)
			{
			  // get the owner and reset the class name to NSApplication.
			  GormFilesOwner *owner = [_document objectForName: @"NSOwner"];
			  NSString *ownerClassName = [owner className];

			  // Retain this, in case we're dealing with the NSOwner...
			  RETAIN(ownerClassName);

			  // delete the class..
			  [self removeClassNamed: className];
			  
			  // re-add it.
			  [self addClassNamed: className
				withSuperClassNamed: superClass
				withActions: actions
				withOutlets: outlets];
			  
			  // Set the owner back to the class name, if needed.
			  if([className isEqualToString: ownerClassName])
			    {
			      [owner setClassName: className];
			    }
			  
			  // refresh the connections.
			  [_document refreshConnectionsForClassNamed: className];
			  
			  // Release the owner classname...
			  RELEASE(ownerClassName);
			}
		    }
		  else
		    {
		      [self addClassNamed: className
			    withSuperClassNamed: superClass
			    withActions: actions
			    withOutlets: outlets];	 
		    }
		}
	      else if([cls isCategory])
		{
		  if ([self isKnownClass: className])
		    {
		      [self addActions: actions forClassNamed: className];
		      [self addActions: outlets forClassNamed: className];
		    }
		  else
		    {
		      [self addClassNamed: className
			    withSuperClassNamed: @"NSObject"
			      withActions: actions
			      withOutlets: outlets];
		    }
		}
	      else if(superClass != nil && [self isKnownClass: superClass] == NO)
		{
		  result = NO;
		  RELEASE(ochp);
		  [NSException raise: NSGenericException
			       format: @"The superclass %@ of class %@ is not known, please parse it.",
			       superClass, className];
		}
	    }
	}
    }

  RELEASE(ochp);
  return result;
}

- (BOOL) isAction: (NSString *)name ofClass: (NSString *)className
{
  BOOL result = NO;
  NSDictionary *classInfo = [_classInformation objectForKey: className];
  
  if (classInfo != nil)
    {
      NSArray *array = [classInfo objectForKey: @"Actions"];
      NSArray *extra_array = [classInfo objectForKey: @"ExtraActions"];
      NSMutableArray *combined = [NSMutableArray array];

      [combined addObjectsFromArray: array];
      [combined addObjectsFromArray: extra_array];
      result = ([combined indexOfObject: name] != NSNotFound);
    }

  return result;
}

- (BOOL) isOutlet: (NSString *)name ofClass: (NSString *)className
{
  BOOL result = NO;
  NSDictionary *classInfo = [_classInformation objectForKey: className];
  
  if (classInfo != nil)
    {
      NSArray *array = [classInfo objectForKey: @"Outlets"];
      NSArray *extra_array = [classInfo objectForKey: @"ExtraOutlets"];
      NSMutableArray *combined = [NSMutableArray array];

      [combined addObjectsFromArray: array];
      [combined addObjectsFromArray: extra_array];
      result = ([combined indexOfObject: name] != NSNotFound);
    }

  return result;
}

// custom class support...
- (NSString *) customClassForName: (NSString *)name
{
  NSString *result = [_customClassMap objectForKey: name];
  return result;
}

- (NSString *) customClassForObject: (id)object
{
  NSString *name = [_document nameForObject: object];
  NSString *result = [self customClassForName: name];
  NSDebugLog(@"in customClassForObject: object = %@, name = %@, result = %@, _customClassMap = %@",
	     object, name, result, _customClassMap);
  return result;
}

- (NSString *) classNameForObject: (id)object
{
  NSString *className = [self customClassForObject: object];
  if(className == nil)
    {
      className = [object className];
    }
  return className;
}

- (void) setCustomClass: (NSString *)className
                forName: (NSString *)name
{
  [_customClassMap setObject: className forKey: name];
}

- (void) removeCustomClassForName: (NSString *)name
{
  [_customClassMap removeObjectForKey: name];
}

- (NSMutableDictionary *) customClassMap
{
  return _customClassMap;
}

- (void) setCustomClassMap: (NSMutableDictionary *)dict
{
  // copy the dictionary..
  NSDebugLog(@"dictionary = %@",dict);
  ASSIGN(_customClassMap, [dict mutableCopy]);
  RETAIN(_customClassMap); // released in dealloc
}

- (BOOL) isCustomClassMapEmpty
{
  return ([_customClassMap count] == 0);
}

- (BOOL) isRootClass: (NSString *)className
{
  return ([self superClassNameForClassNamed: className] == nil);
}

- (NSString *) nonCustomSuperClassOf: (NSString *)className
{
  NSString *result = className;
  
  if(![self isCustomClass: className] && ![self isRootClass: className])
    {
      result = [self superClassNameForClassNamed: result];
    }
  else
    {
      // iterate up the chain until a non-custom superclass is found...
      while ([self isCustomClass: result])
	{
	  NSDebugLog(@"result = %@",result);
	  result = [self superClassNameForClassNamed: result];
	}
    }

  return result;
}

- (NSArray *) allSuperClassesOf: (NSString *)className
{
  NSMutableArray *classes = [NSMutableArray array];

  while (![self isRootClass: className] && className != nil)
    {
      NSDictionary *dict = [self classInfoForClassName: className];
      if(dict != nil)
	{
	  className = [dict objectForKey: @"Super"];
	  if(className != nil)
	    {
	      [classes insertObject: className atIndex: 0];
	    }
	}
      else
	{
	  NSLog(@"Unable to find class named (%@), check that all palettes properly export classes to Gorm.",className);
	  break;
	}
    }

  return classes; 
}

- (void) addActions: (NSArray *)actions forClassNamed: (NSString *)className
{
  id action = nil;
  NSEnumerator *e = [actions objectEnumerator];
  while((action = [e nextObject]))
    {
      [self addAction: action forClassNamed: className];
    }
}

- (void) addOutlets: (NSArray *)outlets forClassNamed: (NSString *)className
{
  id action = nil;
  NSEnumerator *e = [outlets objectEnumerator];
  while((action = [e nextObject]))
    {
      [self addOutlet: action forClassNamed: className];
    }
}

// There are some classes which can't be instantiated directly
// in Gorm.  These are they.. (GJC)
- (BOOL) canInstantiateClassNamed: (NSString *)className
{
  if([self isSuperclass: @"NSApplication" linkedToClass: className] || 
     [className isEqualToString: @"NSApplication"])
    {
      return NO;
    }
  else if([self isSuperclass: @"NSCell" linkedToClass: className] || 
	  [className isEqualToString: @"NSCell"])
    {
      return NO;
    }
  else if([className isEqualToString: @"NSDocument"])
    {
      return NO;
    }
  else if([className isEqualToString: @"NSDocumentController"])
    {
      return NO;
    }
  else if([className isEqualToString: @"NSFontManager"])
    {
      return NO;
    }
  else if([className isEqualToString: @"NSHelpManager"])
    {
      return NO;
    }
  else if([className isEqualToString: @"NSImage"])
    {
      return NO;
    }
  else if([self isSuperclass: @"NSMenuItem" linkedToClass: className] || 
	  [className isEqualToString: @"NSMenuItem"])
    {
      return NO;
    }
  else if([className isEqualToString: @"NSResponder"])
    {
      return NO;
    }
  else if([self isSuperclass: @"NSSound" linkedToClass: className] || 
	  [className isEqualToString: @"NSSound"])
    {
      return NO;
    }
  else if([self isSuperclass: @"NSTableColumn" linkedToClass: className] || 
	  [className isEqualToString: @"NSTableColumn"])
    {
      return NO;
    }
  else if([self isSuperclass: @"NSTableViewItem" linkedToClass: className] || 
	  [className isEqualToString: @"NSTableViewItem"])
    {
      return NO;
    }
  else if([self isSuperclass: @"NSView" linkedToClass: className] || 
	  [className isEqualToString: @"NSView"])
    {
      return NO;
    }
  else if([self isSuperclass: @"NSWindow" linkedToClass: className] || 
	  [className isEqualToString: @"NSWindow"])
    {
      return NO;
    }
  else if([self isSuperclass: @"FirstResponder" linkedToClass: className] || 
	  [className isEqualToString: @"FirstResponder"])
    {
      // special case, FirstResponder.
      return NO;
    }
  
  return YES;
}

- (NSString *) findClassByName: (NSString *)name
{
  NSArray *classNames = [self allClassNames];
  NSEnumerator *en = [classNames objectEnumerator];
  NSString *className = nil;
  NSInteger namelen = [name length];

  while((className = [en nextObject]) != nil)
    {
      NSInteger classlen = [className length];
      if(namelen < classlen)
	{
	  NSComparisonResult result = 
	    [className compare: name
		       options: NSCaseInsensitiveSearch
		       range: ((NSRange){0, namelen})];
	  if(result == NSOrderedSame)
	    {
	      break;
	    }
	}
      else if(namelen == classlen)
	{
	  if([className caseInsensitiveCompare: name] == NSOrderedSame)
	    {
	      break;
	    }
	} 
    }

  return className;
}

- (NSDictionary *) classInformation
{
  return _classInformation;
}

- (NSDictionary *) customClassInformation
{
  NSEnumerator *en = [_customClasses objectEnumerator];
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  NSString *name = nil;

  while ((name = [en nextObject]) != nil)
    {
      NSDictionary *o = [_classInformation objectForKey: name];
      [result setObject: o forKey: name];
    }

  return result;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpointer-to-int-cast"
- (NSString *) description
{
  return [NSString stringWithFormat: @"<%s: %lx> = %@",
 		   GSClassNameFromObject(self), 
		   (unsigned long)self,
 		   _customClassMap];
}
#pragma GCC diagnostic pop

/** Helpful for debugging */
- (NSString *) dumpClassInformation
{
  return [_classInformation description];
}

@end
