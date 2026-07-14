/* GormPrivate.m
 *
 * Copyright (C) 1999, 2003 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2003, 2004
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

// for templates...
#include <AppKit/AppKit.h>

#include <GNUstepBase/GSObjCRuntime.h>
#include <GNUstepGUI/GSNibLoading.h>

#include "GormPrivate.h"
#include "GormFontViewController.h"
#include "GormSetNameController.h"

NSString *GormToggleGuidelineNotification = @"GormToggleGuidelineNotification";
NSString *GormDidModifyClassNotification = @"GormDidModifyClassNotification";
NSString *GormDidAddClassNotification = @"GormDidAddClassNotification";
NSString *GormDidDeleteClassNotification = @"GormDidDeleteClassNotification";
NSString *GormWillDetachObjectFromDocumentNotification = @"GormWillDetachObjectFromDocumentNotification";
NSString *GormDidDetachObjectFromDocumentNotification = @"GormDidDetachObjectFromDocumentNotification";
NSString *GormResizeCellNotification = @"GormResizeCellNotification";

// Private, and soon to be deprecated, notification string...
NSString *GSInternalNibItemAddedNotification = @"_GSInternalNibItemAddedNotification";

// Define this as "NO" initially.  We only want to turn this on while loading or testing.
static BOOL _isInInterfaceBuilder = NO;

@class	InfoPanel;

// we had this include for grouping/ungrouping selectors
#include "GormViewWithContentViewEditor.h"

@implementation GSNibItem (GormAdditions)
- (id) initWithClassName: (NSString*)className frame: (NSRect)frame
{
  if((self = [super init]) != nil)
    {
      theClass = [className copy];
      theFrame = frame;
    }
  return self;
}

- (id) initWithClassName: (NSString*)className
{
  return [self initWithClassName: className 
	       frame: NSMakeRect(0,0,0,0)];
}

- (NSString*) className
{
  return theClass;
}
@end

@interface NSObject (GormPrivate)
+ (BOOL) canSubstituteForClass: (Class)origClass;
@end

@implementation NSObject (GormPrivate)

+ (BOOL) canSubstituteForClass: (Class)origClass
{
  if(self == origClass)
    {
      return YES;
    }
  else if([self isSubclassOfClass: origClass])
    {
      Class cls = self;
      while(cls != nil && cls != origClass)
	{
	  if(GSGetMethod(cls, @selector(initWithCoder:), YES, NO) != NULL &&
	     GSGetMethod(cls, @selector(encodeWithCoder:), YES, NO) != NULL)
	    {
	      return NO;
	    }
	  cls = GSObjCSuper(cls); // get super class
	}
      return YES;
    }

  return NO;
}

@end

@implementation GormObjectProxy
/*
 * Perhaps this would be better to have a dummy initProxyWithCoder
 * in GSNibItem class, so that we are not dependent on actual coding
 * order of the ivars ?
 */
- (id) initWithCoder: (NSCoder*)aCoder
{
  if([aCoder allowsKeyedCoding])
    {
      ASSIGN(theClass, [aCoder decodeObjectForKey: @"NSClassName"]);
      theFrame = NSZeroRect;
      return self;
    }
  else
    {
      NSUInteger version = [aCoder versionForClassName: 
			      NSStringFromClass([GSNibItem class])];
      NSInteger cv = [aCoder versionForClassName:
			 NSStringFromClass([GSNibContainer class])];

      if (version == NSNotFound)
	{
	  NSLog(@"no GSNibItem");
	  version = [aCoder versionForClassName: 
			      NSStringFromClass([GormObjectProxy class])];
	}
      
      // add to the top level items during unarchiving, if the container is old.
      if (cv == 0)
	{
	  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	  [nc postNotificationName: GSInternalNibItemAddedNotification
	      object: self];
	}

      if (version == 0)
	{
	  // do not decode super (it would try to morph into theClass ! )
	  [aCoder decodeValueOfObjCType: @encode(id) at: &theClass];
	  theFrame = [aCoder decodeRect];
	  RETAIN(theClass); // release in dealloc of GSNibItem... 
	  
	  return self; 
	}
      else if (version == 1)
	{
	  // do not decode super (it would try to morph into theClass ! )
	  [aCoder decodeValueOfObjCType: @encode(id) at: &theClass];
	  theFrame = [aCoder decodeRect];
	  [aCoder decodeValueOfObjCType: @encode(unsigned int) 
		  at: &autoresizingMask];  
	  RETAIN(theClass); // release in dealloc of GSNibItem... 
	  
	  return self; 
	}
      else
	{
	  NSLog(@"no initWithCoder for version %d", (int)version);
	  RELEASE(self);
	  return nil;
	}
    }
  return nil;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      [coder encodeObject: theClass 
	     forKey: @"NSClassName"];
    }
  else
    {
      [super encodeWithCoder: coder];
    }
}

- (NSString*) inspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (NSString*) classInspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (void) setClassName: (NSString *)className
{
  ASSIGNCOPY(theClass, className); 
}

- (NSImage *) imageForViewer
{
  NSImage *image = [super imageForViewer];
  if([theClass isEqual: @"NSFontManager"])
    {
      NSBundle	*bundle = [NSBundle bundleForClass: [self class]];
      NSString *path = [bundle pathForImageResource: @"GormFontManager"]; 
      image = [[NSImage alloc] initWithContentsOfFile: path];
    }
  return image;
}

- (NSString *) description
{
  NSString *desc = [super description];
  return [NSString stringWithFormat: @"<%@, className = %@>", desc, theClass];
}
@end

// define the class proxy...
@implementation GormClassProxy
- (id) initWithClassName: (NSString *)n
{
  self = [super init];
  if (self != nil)
    {
      if([n isKindOfClass: [NSString class]])
	{
	  // create a copy.
	  ASSIGNCOPY(name, n);
	}
      else
	{
	  NSLog(@"Attempt to add a class proxy with className = %@",n);
	}
    }
  return self;
}

- (void) dealloc
{
  RELEASE(name);
  [super dealloc];
}

- (NSString*) className
{
  return name;
}

- (NSString*) inspectorClassName
{
  return @"GormClassInspector";
}

- (NSString*) classInspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (NSString*) connectInspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (NSString*) sizeInspectorClassName
{
  return @"GormNotApplicableInspector";
}
@end

// custom class additions...
@implementation GSClassSwapper (GormCustomClassAdditions)
+ (void) setIsInInterfaceBuilder: (BOOL)flag
{
  _isInInterfaceBuilder = flag;
}

- (BOOL) isInInterfaceBuilder
{
  return _isInInterfaceBuilder;
}
@end

@implementation IBResourceManager (GormAdditions)
+ (void) registerForAllPboardTypes: (id)editor
			inDocument: (id)doc
{
  NSArray *allTypes = [doc allManagedPboardTypes];
  [editor registerForDraggedTypes: allTypes];
}
@end


