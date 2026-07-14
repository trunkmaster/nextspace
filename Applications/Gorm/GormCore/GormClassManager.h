/* GormClassManager.h
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

#ifndef INCLUDED_GormClassManager_h
#define INCLUDED_GormClassManager_h

#import <InterfaceBuilder/InterfaceBuilder.h>

// The custom classes and category arrays will hold only those things which 
// will be persisted to the .classes file.   Since the overall list of classes will 
// not change it seems that the only thing that we should save is the "delta" 
// that being the custom classes.   Once loaded they can be "merged" in with the 
// list of base classes, in gui, to form the full list of classes.
@interface GormClassManager : NSObject
{
  NSMutableDictionary	*_classInformation;
  NSMutableArray        *_customClasses;
  NSMutableDictionary   *_customClassMap;
  NSMutableArray        *_categoryClasses;
  id                     _document;
}

- (id) initWithDocument: (id)aDocument;

/* Managing actions and outlets */
- (void) addAction: (NSString *)anAction forObject: (id)anObject;
- (void) addOutlet: (NSString *)anOutlet forObject: (id)anObject;
- (NSArray *) allActionsForClassNamed: (NSString *)className;
- (NSArray *) allActionsForObject: (id)anObject;
- (NSArray *) extraActionsForObject: (id)anObject;
- (NSArray *) allOutletsForClassNamed: (NSString *)className;
- (NSArray *) allOutletsForObject: (id)anObject;
- (NSArray *) extraOutletsForObject: (id)anObject;
- (NSArray *) allClassNames;
- (void) removeAction: (NSString *)anAction forObject: (id)anObject;
- (void) removeOutlet: (NSString *)anOutlet forObject: (id)anObject;
- (void) removeAction: (NSString *)anAction fromClassNamed: (NSString *)anObject;
- (void) removeOutlet: (NSString *)anOutlet fromClassNamed: (NSString *)anObject;
- (void) addOutlet: (NSString *)anOutlet forClassNamed: (NSString *)className;
- (void) addAction: (NSString *)anAction forClassNamed: (NSString *)className;
- (void) addActions: (NSArray *)actions forClassNamed: (NSString *)className;
- (void) addOutlets: (NSArray *)outlets forClassNamed: (NSString *)className;
- (NSString *) addNewActionToClassNamed: (NSString *)name;
- (NSString *) addNewOutletToClassNamed: (NSString *)name;
- (void) replaceAction: (NSString *)oldAction withAction: (NSString *)newAction forClassNamed: (NSString *)className;
- (void) replaceOutlet: (NSString *)oldOutlet withOutlet: (NSString *)newOutlet forClassNamed: (NSString *)className;

/* Managing classes and subclasses */
- (BOOL) renameClassNamed: (NSString *)oldName newName: (NSString *)name;
- (void) removeClassNamed: (NSString *)className;
- (NSString *) addClassWithSuperClassName: (NSString *)name;
- (NSArray *) subClassesOf: (NSString *)superclass;
- (NSArray *) allSubclassesOf: (NSString *)superClass;
- (NSArray *) customSubClassesOf: (NSString *)superclass;
- (NSArray *) allCustomSubclassesOf: (NSString *)superclass;
- (NSArray *) allCustomClassNames;
- (BOOL) addClassNamed: (NSString *)className
   withSuperClassNamed: (NSString *)superClassName
	   withActions: (NSArray *)actions
           withOutlets: (NSArray *)outlets;
- (BOOL) addClassNamed: (NSString *)class_name
   withSuperClassNamed: (NSString *)super_class_name
	   withActions: (NSArray *)_actions
	   withOutlets: (NSArray *)_outlets
              isCustom: (BOOL) isCustom;
- (BOOL) setSuperClassNamed: (NSString *)superclass
	      forClassNamed: (NSString *)subclass;
- (NSString *)parentOfClass: (NSString *)aClass;
- (NSString *) superClassNameForClassNamed: (NSString *)className;
- (BOOL) isSuperclass: (NSString *)superclass
	linkedToClass: (NSString *)subclass;
- (NSDictionary *) dictionaryForClassNamed: (NSString *)className;
- (NSString *) uniqueClassNameFrom: (NSString *)name;
- (BOOL) isRootClass: (NSString *)className;
- (BOOL) outletExists: (NSString *)outlet
         onClassNamed: (NSString *)className;
- (BOOL) actionExists: (NSString *)action
         onClassNamed: (NSString *)className;

/* Managing custom classes */
- (BOOL) isCustomClass: (NSString *)className;
- (BOOL) isNonCustomClass: (NSString *)className;
- (BOOL) isCategoryForClass: (NSString *)className;
- (BOOL) isKnownClass: (NSString *)className;
- (BOOL) isAction: (NSString *)actionName ofClass: (NSString *)className;
- (BOOL) isOutlet: (NSString *)outletName ofClass: (NSString *)className;
- (NSArray *) allSuperClassesOf: (NSString *)className;
- (BOOL) canInstantiateClassNamed: (NSString *)className;
- (NSString *) customClassForObject: (id)object;
- (NSString *) customClassForName: (NSString *)name;
- (void) setCustomClass: (NSString *)className
                forName: (NSString *)name;
- (void) removeCustomClassForName: (NSString *)name;
- (NSMutableDictionary *) customClassMap;
- (void) setCustomClassMap: (NSMutableDictionary *)dict;
- (BOOL) isCustomClassMapEmpty;
- (NSString *) nonCustomSuperClassOf: (NSString *)className;
- (BOOL) isAction: (NSString *)actionName  onCategoryForClassNamed: (NSString *)className;
- (NSString *) classNameForObject: (id)object;
- (NSString *) findClassByName: (NSString *)name;
- (NSDictionary *) classInformation;
- (NSDictionary *) customClassInformation;

/* Parsing and creating classes */
- (BOOL) makeSourceAndHeaderFilesForClass: (NSString *)className
				 withName: (NSString *)sourcePath
				      and: (NSString *)headerPath;
- (BOOL) parseHeader: (NSString *)headerPath;

/* Loading and saving */
- (BOOL) saveToFile: (NSString *)path;
- (NSData *) data;
- (NSData *) nibData;
- (BOOL) loadFromFile: (NSString *)path;
- (BOOL) loadCustomClasses: (NSString *)path;
- (BOOL) loadCustomClassesWithData: (NSData *)data;
- (BOOL) loadCustomClassesWithDict: (NSDictionary *)dict;
- (BOOL) loadNibFormatCustomClassesWithData: (NSData *)data;
- (BOOL) loadNibFormatCustomClassesWithDict: (NSDictionary *)dict;

@end

#endif
