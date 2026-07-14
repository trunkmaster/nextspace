 /*
   NSTreeController.m

   The tree controller class.

   Copyright (C) 2012, 2024 Free Software Foundation, Inc.

   Author:  Gregory Casamento <greg.casamento@gmail.com>
   Date: 2012, 2024

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#import <Foundation/NSArchiver.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSIndexPath.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSString.h>
#import <Foundation/NSSortDescriptor.h>

#import "AppKit/NSOutlineView.h"
#import "AppKit/NSKeyValueBinding.h"
#import "AppKit/NSTreeController.h"
#import "AppKit/NSTreeNode.h"

#import "GSBindingHelpers.h"
#import "GSFastEnumeration.h"
#import "GSControllerTreeProxy.h"

@implementation NSTreeController

+ (void) initialize
{
  if (self == [NSTreeController class])
    {
      [self exposeBinding: NSContentArrayBinding];
      [self exposeBinding: NSContentBinding];
      [self exposeBinding: NSSelectionIndexPathsBinding];
      [self setKeys: [NSArray arrayWithObjects: NSContentBinding, NSContentObjectBinding, nil]
	    triggerChangeNotificationsForDependentKey: @"arrangedObjects"];
    }
}

- (void) _initDefaults
{
  _childrenKeyPath = nil;
  _countKeyPath = nil;
  _leafKeyPath = nil;
  _sortDescriptors = nil;
  _selection_index_paths = [[NSMutableArray alloc] init];

  _canInsert = YES;
  _canInsertChild = YES;
  _canAddChild = YES;

  [self setObjectClass: [NSMutableDictionary class]];
}

- (id) initWithContent: (id)content
{
  if ((self = [super initWithContent: content]) != nil)
    {
      [self _initDefaults];
    }

  return self;
}

- (id) init
{
  NSMutableArray *array = [[NSMutableArray alloc] init];

  self = [self initWithContent: array];
  RELEASE(array);

  return self;
}

- (void) dealloc
{
  RELEASE(_childrenKeyPath);
  RELEASE(_countKeyPath);
  RELEASE(_leafKeyPath);
  RELEASE(_sortDescriptors);
  RELEASE(_arranged_objects);
  RELEASE(_selection_index_paths);
  
  [super dealloc];
}

- (BOOL) addSelectionIndexPaths: (NSArray *)indexPaths
{
  BOOL f = [self commitEditing];

  if (YES == f)
    {
      [_selection_index_paths addObjectsFromArray: indexPaths];
    }

  return f;
}

- (BOOL) alwaysUsesMultipleValuesMarker
{
  return _alwaysUsesMultipleValuesMarker;
}

- (BOOL) avoidsEmptySelection
{
  return _avoidsEmptySelection;
}

- (BOOL) canAddChild
{
  return _canAddChild;
}

- (BOOL) canInsert
{
  return _canInsert;
}

- (BOOL) canInsertChild
{
  return _canInsertChild;
}

- (BOOL) preservesSelection
{
  return _preservesSelection;
}

- (BOOL) selectsInsertedObjects
{
  return _selectsInsertedObjects;
}

- (BOOL) setSelectionIndexPath: (NSIndexPath *)indexPath
{
  BOOL f = [self commitEditing];

  if (YES == f)
    {
      NSMutableArray *mutable_index_paths = [NSMutableArray arrayWithObject: indexPath];
      ASSIGN(_selection_index_paths, mutable_index_paths);      
    }

  return f;
}

- (BOOL) setSelectionIndexPaths: (NSArray *)indexPaths
{
  BOOL f = [self commitEditing];

  if (YES == f)
    {
      NSMutableArray *mutable_index_paths = [NSMutableArray arrayWithArray: indexPaths];
      ASSIGN(_selection_index_paths, mutable_index_paths);
    }

  return f;
}

- (NSTreeNode *) arrangedObjects
{
  if (_arranged_objects == nil)
    {
      [self rearrangeObjects];
    }
  return _arranged_objects;
}

- (void) rearrangeObjects
{
  [self willChangeValueForKey: @"arrangedObjects"];
  DESTROY(_arranged_objects);

  if ([_content isKindOfClass: [NSArray class]])
    {
      _arranged_objects = [[GSControllerTreeProxy alloc] initWithContent: _content
							  withController: self];
    }

  [self didChangeValueForKey: @"arrangedObjects"];
}

- (id) _objectAtIndexPath: (NSIndexPath *)indexPath
{
  NSUInteger length = [indexPath length];
  NSUInteger pos = 0;
  NSMutableArray *children = [_arranged_objects mutableChildNodes];
  NSUInteger lastIndex = 0;
  id obj = nil;

  for (pos = 0; pos < length - 1; pos++)
    {
      NSUInteger i = [indexPath indexAtPosition: pos];
      id node = [children objectAtIndex: i];

      children = [node valueForKeyPath: _childrenKeyPath];
    }

  lastIndex = [indexPath indexAtPosition: length - 1];
  obj = [children objectAtIndex: lastIndex];

  return obj;
}

- (NSArray *) selectedObjects
{
  NSMutableArray *selectedObjects = [NSMutableArray array];

  FOR_IN(NSIndexPath*, path, _selection_index_paths)
    {
      id obj = [self _objectAtIndexPath: path];
      [selectedObjects addObject: obj];
    }
  END_FOR_IN(_selection_index_paths);

  return selectedObjects;
}

- (NSIndexPath *) selectionIndexPath
{
  if ([_selection_index_paths count] > 0)
    {
      return [_selection_index_paths objectAtIndex: 0];
    }
  return nil;
}

- (NSArray *) selectionIndexPaths
{
  return [_selection_index_paths copy];
}

- (NSArray *) sortDescriptors
{
  return [_sortDescriptors copy];
}

- (NSString *) childrenKeyPath
{
  return _childrenKeyPath;
}

- (NSString *) countKeyPath
{
  return _countKeyPath;
}

- (NSString *) leafKeyPath
{
  return _leafKeyPath;
}

- (IBAction) add: (id)sender
{
  NSIndexPath *p = [NSIndexPath indexPathWithIndex: 0];
  id newObject = [self newObject];
  [self insertObject: newObject atArrangedObjectIndexPath: p];
  RELEASE(newObject);
}

- (IBAction) addChild: (id)sender
{
  NSIndexPath *p = [self selectionIndexPath];
  id newObject = [self newObject];

  if (p != nil)
    {
      [self insertObject: newObject atArrangedObjectIndexPath: p];
      RELEASE(newObject);
    }
}

- (IBAction) remove: (id)sender
{
  if ([self canRemove]
      && [self countKeyPath] == nil)
    {
      if ([_selection_index_paths count] > 0)
	{
	  NSIndexPath *p = [self selectionIndexPath];
	  [self removeObjectAtArrangedObjectIndexPath: p];
	}
    }
}

- (IBAction) insertChild: (id)sender
{
  [self addChild: sender];
}

- (void) insertObject: (id)object atArrangedObjectIndexPath: (NSIndexPath *)indexPath
{
  if ([self canAddChild]
      && [self countKeyPath] == nil)
    {
      NSUInteger length = [indexPath length];
      NSUInteger pos = 0;
      NSMutableArray *children = [_arranged_objects mutableChildNodes];

      for (pos = 0; pos < length - 1; pos++)
	{
	  NSUInteger i = [indexPath indexAtPosition: pos];
	  id node = [children objectAtIndex: i];

	  children = [node valueForKeyPath: _childrenKeyPath];
	}

      [children addObject: object];

      [self rearrangeObjects];
    }
}

- (void) insertObjects: (NSArray *)objects atArrangedObjectIndexPaths: (NSArray *)indexPaths
{
  if ([self canAddChild]
      && [self countKeyPath] == nil)
    {
      if ([objects count] != [indexPaths count])
	{
	  return;
	}
      else
	{
	  NSUInteger i = 0;

	  FOR_IN(id, object, objects)
	    {
	      NSIndexPath *indexPath = [indexPaths objectAtIndex: i];

	      [self insertObject: object atArrangedObjectIndexPath: indexPath];
	      i++;
	    }
	  END_FOR_IN(objects);
	}
    }
}

- (IBAction) insert: (id)sender
{
  [self addChild: sender];
}

- (void) removeObjectAtArrangedObjectIndexPath: (NSIndexPath *)indexPath
{
  NSUInteger length = [indexPath length];
  NSUInteger pos = 0;
  NSMutableArray *children = [_arranged_objects mutableChildNodes];
  NSUInteger lastIndex = 0;

  for (pos = 0; pos < length - 1; pos++)
    {
      NSUInteger i = [indexPath indexAtPosition: pos];
      id node = [children objectAtIndex: i];

      children = [node valueForKeyPath: _childrenKeyPath];
    }

  lastIndex = [indexPath indexAtPosition: length - 1];
  [children removeObjectAtIndex: lastIndex];
  [self rearrangeObjects];
}

- (void) removeObjectsAtArrangedObjectIndexPaths: (NSArray *)indexPaths
{
  FOR_IN(NSIndexPath*, indexPath, indexPaths)
    {
      [self removeObjectAtArrangedObjectIndexPath: indexPath];
    }
  END_FOR_IN(indexPaths);
}

- (void) removeSelectionIndexPaths: (NSArray *)indexPaths
{
  [self removeObjectsAtArrangedObjectIndexPaths: indexPaths];
}

- (void) setAlwaysUsesMultipleValuesMarker: (BOOL)flag
{
  _alwaysUsesMultipleValuesMarker = flag;
}

- (void) setAvoidsEmptySelection: (BOOL)flag
{
  _avoidsEmptySelection = flag;
}

- (void) setChildrenKeyPath: (NSString *)path
{
  ASSIGN(_childrenKeyPath, path);
}

- (void) setContent: (id)content
{
  [super setContent: content];
  [self rearrangeObjects];
}

- (void) setCountKeyPath: (NSString *)path
{
  ASSIGN(_countKeyPath, path);
}

- (void) setLeafKeyPath: (NSString *)key
{
  ASSIGN(_leafKeyPath, key);
}

- (void) setPreservesSelection: (BOOL)flag
{
  _preservesSelection = flag;
}

- (void) setSelectsInsertedObjects: (BOOL)flag
{
  _selectsInsertedObjects = flag;
}

- (void) setSortDescriptors: (NSArray *)descriptors
{
  ASSIGN(_sortDescriptors, descriptors);
}

- (NSString *) childrenKeyPathForNode: (NSTreeNode *)node
{
  return _childrenKeyPath;
}

- (NSString *) countKeyPathForNode: (NSTreeNode *)node
{
  return _countKeyPath;
}

- (NSString *) leafKeyPathForNode: (NSTreeNode *)node
{
  return _leafKeyPath;
}

- (void) moveNode: (NSTreeNode *)node toIndexPath: (NSIndexPath *)indexPath
{
  // FIXME
}

- (void) moveNodes: (NSArray *)nodes toIndexPath: (NSIndexPath *)startingIndexPath
{
  // FIXME
}

- (NSArray *) selectedNodes
{
  // FIXME
  return [self selectedObjects];
}


- (void) bind: (NSString *)binding
     toObject: (id)anObject
  withKeyPath: (NSString *)keyPath
      options: (NSDictionary *)options
{
  if ([binding isEqual: NSContentArrayBinding])
    {
      GSKeyValueBinding *kvb;

      [self unbind: binding];
      kvb = [[GSKeyValueBinding alloc] initWithBinding: @"content"
					      withName: binding
					      toObject: anObject
					   withKeyPath: keyPath
					       options: options
					    fromObject: self];
      // The binding will be retained in the binding table
      RELEASE(kvb);
    }
  else
    {
      [super bind: binding
	 toObject: anObject
      withKeyPath: keyPath
	  options: options];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];

  if (self != nil)
    {
      [self _initDefaults]; // set up default values...
      if ([coder allowsKeyedCoding])
	{
	  // These names do not stick to convention.  Usually it would be
	  // NS* or NSTreeController* so they must be overriden in
	  // GSXib5KeyedUnarchver.
	  if ([coder containsValueForKey: @"NSTreeContentChildrenKey"])
	    {
	      [self setChildrenKeyPath:
		      [coder decodeObjectForKey: @"NSTreeContentChildrenKey"]];
	    }
	  if ([coder containsValueForKey: @"NSTreeContentCountKey"])
	    {
	      [self setCountKeyPath:
		      [coder decodeObjectForKey: @"NSTreeContentCountKey"]];
	    }
	  if ([coder containsValueForKey: @"NSTreeContentLeafKey"])
	    {
	      [self setLeafKeyPath:
		      [coder decodeObjectForKey: @"NSTreeContentLeafKey"]];
	    }

	  // Since we don't inherit from NSArrayController these are decoded here
	  // as well.
	  if ([coder containsValueForKey: @"NSAvoidsEmptySelection"])
	    {
	      [self setAvoidsEmptySelection:
		    [coder decodeBoolForKey: @"NSAvoidsEmptySelection"]];
	    }
	  if ([coder containsValueForKey: @"NSPreservesSelection"])
	    {
	      [self setPreservesSelection:
		      [coder decodeBoolForKey: @"NSPreservesSelection"]];
	    }
	  if ([coder containsValueForKey: @"NSSelectsInsertedObjects"])
	    {
	      [self setSelectsInsertedObjects:
		      [coder decodeBoolForKey: @"NSSelectsInsertedObjects"]];
	    }
	}
    }
  else
    {
      id obj = nil;
      BOOL f = NO;

      obj = [coder decodeObject];
      [self setChildrenKeyPath: obj];
      obj = [coder decodeObject];
      [self setCountKeyPath: obj];
      obj = [coder decodeObject];
      [self setLeafKeyPath: obj];

      [coder decodeValueOfObjCType: @encode(BOOL)
				at: &f];
      [self setAvoidsEmptySelection: f];
      [coder decodeValueOfObjCType: @encode(BOOL)
				at: &f];
      [self setPreservesSelection: f];
      [coder decodeValueOfObjCType: @encode(BOOL)
				at: &f];
      [self setSelectsInsertedObjects: f];
    }

  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _childrenKeyPath
		   forKey: @"NSTreeContentChildrenKey"];
      [coder encodeObject: _countKeyPath
		   forKey: @"NSTreeContentCountKey"];
      [coder encodeObject: _leafKeyPath
		   forKey: @"NSTreeContentLeafKey"];


      [coder encodeBool: _avoidsEmptySelection
		 forKey: @"NSAvoidsEmptySelection"];
      [coder encodeBool: _preservesSelection
		 forKey: @"NSPreservesSelection"];
      [coder encodeBool: _selectsInsertedObjects
		 forKey: @"NSSelectsInsertedObjects"];
    }
  else
    {
      id obj = nil;
      BOOL f = NO;

      obj = [self childrenKeyPath];
      [coder encodeObject: obj];
      obj = [self countKeyPath];
      [coder encodeObject: obj];
      obj = [self leafKeyPath];
      [coder encodeObject: obj];

      f = [self avoidsEmptySelection];
      [coder encodeValueOfObjCType: @encode(BOOL)
				at: &f];
      f = [self preservesSelection];
      [coder encodeValueOfObjCType: @encode(BOOL)
				at: &f];
      f = [self selectsInsertedObjects];
      [coder encodeValueOfObjCType: @encode(BOOL)
				at: &f];
    }
}

- (id) copyWithZone: (NSZone *)zone
{
  id copy = [[NSTreeController allocWithZone: zone] initWithContent: [self content]];

  if (copy != nil)
    {
      [copy setChildrenKeyPath: [self childrenKeyPath]];
      [copy setCountKeyPath: [self countKeyPath]];
      [copy setLeafKeyPath: [self leafKeyPath]];

      [copy setAvoidsEmptySelection: [self avoidsEmptySelection]];
      [copy setPreservesSelection: [self preservesSelection]];
      [copy setSelectsInsertedObjects: [self selectsInsertedObjects]];
    }

  return copy;
}

@end
