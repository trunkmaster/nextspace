/* GormWrapperBuilder
 *
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2006
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include <GNUstepGUI/GSNibLoading.h>

// allow access to a private category...
@interface NSIBObjectData (BuilderAdditions)
- (id) initWithDocument: (GormDocument *)document;
@end;

@implementation NSIBObjectData (BuilderAdditions)
- (id) initWithDocument: (GormDocument *)document
{
  if((self = [self init]) != nil)
    {
      NSArray *cons = [document connections];
      NSDictionary *customClasses = [[document classManager] customClassMap];
      NSArray *keys = [customClasses allKeys];
      NSEnumerator *en = [cons objectEnumerator];
      id o = nil;
      id owner = [document objectForName: @"NSOwner"];
      unsigned int oid = 1;
      
      // Create the container for the .nib file...
      ASSIGN(_root, owner);
      NSMapInsert(_names, owner, @"File's Owner");
      NSMapInsert(_oids, owner, [[NSNumber alloc] initWithUnsignedInt: oid++]);
      ASSIGN(_framework, @"IBCocoaFramework");
      [_topLevelObjects addObjectsFromArray: [[document topLevelObjects] allObjects]];
      [_visibleWindows addObjectsFromArray: [[document visibleWindows] allObjects]];

      // fill in objects and connections....
      while((o = [en nextObject]) != nil)
	{
	  NSNumber *currOid = [NSNumber numberWithUnsignedInt: oid++];
	  // NSString *currOid = [NSString stringWithFormat: @"%d", oid++];
	   
	  if ([o isMemberOfClass: [NSNibConnector class]])
	    {
	      id src = [o source];
	      id dst = [o destination];
	      NSString *name = nil;

	      // 
	      if (src != nil)
		{
		  name = [document nameForObject: src];
		}
	      else
		{
		  continue;
		}

	      if ([name isEqual: @"NSOwner"])
		{
		  name = @"File's Owner";
		}
	      if ([name isEqual: @"NSMenu"])
		{
		  name = @"MainMenu";
		}
	      else if ([name isEqual: @"NSFirst"])
		{
		  // skip it...
		  continue;
		}

	      if (dst == nil)
		{
		  NSLog(@"==> WARNING: value for object %@ is %@ in objects map.", src, dst);
		}
              else
                {
                  NSMapInsert(_objects, src, dst);
                }

	      if (name == nil)
		{
		  NSLog(@"==> WARNING: value for object %@ is %@ in names map.", src, name);
                }
              else
                {
                  NSMapInsert(_names, src, name);
                }

	      if (currOid == nil)
		{
		  NSLog(@"==> WARNING: value for object %@ is %@ in oids map.", src, currOid);
		}
              else
                {
                  NSMapInsert(_oids, src, currOid);
                }
	    }
	  else
	    {
	      [_connections addObject: o];
	      NSMapInsert(_oids, o, currOid);
	    }
	}

      // set the next oid...
      _nextOid = oid;

      // custom classes...
      en = [keys objectEnumerator];
      while((o = [en nextObject]) != nil)
	{
	  id obj = [document objectForName: o];
	  NSString *className = [customClasses objectForKey: o];
	  NSMapInsert(_classes, obj, className);
	}
    }
  return self;
}
@end

@interface GSNibTemplateFactory : NSObject
+ (id) templateForObject: (id)object
	   withClassName: (NSString *)customClass 
      withSuperClassName: (NSString *)superClass
	    withDocument: (GormDocument *)document;
@end

@implementation GSNibTemplateFactory
+ (id) templateForObject: (id)object
	   withClassName: (NSString *)customClass 
      withSuperClassName: (NSString *)superClass
	    withDocument: (GormDocument *)document
{
  id template = nil;
  if([object isKindOfClass: [NSWindow class]])
    {
      BOOL isDeferred = [document objectIsDeferred: object];
      BOOL isVisible = [document objectIsVisibleAtLaunch: object];
      BOOL wantsToBeColor = YES;
      int  autoPositionMask = 0;

      template = [[NSWindowTemplate alloc] initWithWindow: object
					   className: customClass
					   isDeferred: isDeferred
					   isOneShot: [object isOneShot]
					   isVisible: isVisible
					   wantsToBeColor: wantsToBeColor
					   autoPositionMask: autoPositionMask];
    }
  else if([object isKindOfClass: [NSText class]])
    {
      template = [[NSTextTemplate alloc] initWithObject: object
					     className: customClass];
    }
  else if([object isKindOfClass: [NSTextView class]])
    {
      template = [[NSTextViewTemplate alloc] initWithObject: object
					     className: customClass];
    }
  else if([object isKindOfClass: [NSView class]])
    {
      template = [[NSViewTemplate alloc] initWithObject: object
					 className: customClass];
    }
  else
    {
      template = [[NSClassSwapper alloc] initWithObject: object
					 withClassName: customClass
					 originalClassName: superClass];
    }

  return template;
}
@end


@interface GormNibWrapperBuilder : GormWrapperBuilder
{
  NSMapTable *_objectMap;
  NSIBObjectData *_container;
}
@end

@implementation GormNibWrapperBuilder
+ (NSString *) fileType
{
  return @"GSNibFileType";
}

- (id) init
{
  if((self = [super init]) != nil)
    {
      _objectMap = NSCreateMapTableWithZone(NSObjectMapKeyCallBacks,
					    NSObjectMapValueCallBacks, 
					    128, 
					    [self zone]);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_container);
  NSFreeMapTable(_objectMap);
  [super dealloc];
}

/**
 * Private method which iterates through the list of custom classes and instructs 
 * the archiver to replace the actual object with template during the archiving 
 * process.
 */
- (void) _replaceObjectsWithTemplates: (NSKeyedArchiver *)archiver
{
  NSEnumerator *en = [[document nameTable] keyEnumerator];
  GormClassManager *classManager = [document classManager];
  // GormFilePrefsManager *filePrefsManager = [document filePrefsManager];
  id key = nil;

  // loop through all custom objects and windows
  while((key = [en nextObject]) != nil)
    {
      id customClass = [classManager customClassForName: key];
      id object = [document objectForName: key];
      id template = nil;
      if(customClass != nil)
	{
	  NSString *superClass = [classManager nonCustomSuperClassOf: customClass];
	  template = [GSNibTemplateFactory templateForObject: object
					   withClassName: customClass 
					   withSuperClassName: superClass
	                                   withDocument: document];
	}
      else if([object isKindOfClass: [NSWindow class]])
	{
	  template = [GSNibTemplateFactory templateForObject: object
					   withClassName: [object className]
					   withSuperClassName: [object className]
					   withDocument: document]; 
	  
	}

      // if the template has been created, replace the object with it.
      if(template != nil)
	{
	  /*  NOT YET IMPLEMENTED *
	  //  if the object can accept autoposition information
	  if([object respondsToSelector: @selector(autoPositionMask)])
	    {
	      int mask = [object autoPositionMask];
	      if([template respondsToSelector: @selector(setAutoPositionMask:)])
		{
		  [template setAutoPositionMask: mask];
		}
	    }
	  */

	  // replace the object with the template.
	  NSMapInsert(_objectMap, object, template);
	}
    }
}

- (id) archiver: (NSKeyedArchiver *)archiver willEncodeObject: (id) object
{
  id replacementObject = NSMapGet(_objectMap,object);
  id o = object;

  if([o isKindOfClass: [GormFirstResponder class]])
    {
      o = nil;
    }
  else if(replacementObject != nil)
    {
      o = replacementObject;
    }
  
  return o;
}

- (NSArray *) openItems
{
  NSMapTable *oids = [_container oids];
  NSMutableArray *openItems = [NSMutableArray array];
  NSEnumerator *en = [[_container visibleWindows] objectEnumerator];
  id menu = [document objectForName: @"NSMenu"];
  id obj = nil;

  // Get the open items, so that IB displays the same windows that Gorm had open when it
  // saved....
  while((obj = [en nextObject]) != nil)
    {
      if([obj isVisible])
	{
	  NSNumber *windowOid = NSMapGet(oids, obj);
	  [openItems addObject: windowOid];
	}
    }

  // add the menu...
  if(menu != nil)
    {
      NSNumber *menuOid = NSMapGet(oids,menu);
      [openItems addObject: menuOid];
    }

  return openItems;
}

- (NSMutableDictionary *)buildFileWrapperDictionaryWithDocument: (GormDocument *)doc
{
  NSKeyedArchiver       *archiver = nil;
  NSMutableData         *archiverData = nil;
  NSString              *nibPath = @"keyedobjects.nib";
  NSString              *classesPath = @"classes.nib";
  NSString              *infoPath = @"info.nib";
  GormPalettesManager   *palettesManager = [(id<GormAppDelegate>)[NSApp delegate] palettesManager];
  NSDictionary          *substituteClasses = [palettesManager substituteClasses];
  NSEnumerator          *en = [substituteClasses keyEnumerator];
  NSString              *subClassName = nil;
  NSFileWrapper         *fileWrapper = nil;
  NSMutableDictionary   *fileWrappers = [super buildFileWrapperDictionaryWithDocument: doc];

  if(fileWrappers)
    {
      GormClassManager *classManager = [document classManager];
      GormFilePrefsManager *filePrefsManager = [document filePrefsManager];

      // instantiate the container.
      _container = [[NSIBObjectData alloc] initWithDocument: document];      

      /*
       * Set up archiving...
       */
      archiverData = [NSMutableData dataWithCapacity: 10240];
      archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData: archiverData];
      [archiver setDelegate: self];

      /* 
       * Special gorm classes to their archive equivalents. 
       */
      [archiver setClassName: @"NSCustomObject"
		forClass: [GormObjectProxy class]];
      [archiver setClassName: @"NSCustomView"
		forClass: [GormCustomView class]];
      [archiver setClassName: @"NSCustomObject"
		forClass: [GormFilesOwner class]];
      
      
      while((subClassName = [en nextObject]) != nil)
	{
	  NSString *realClassName = [substituteClasses objectForKey: subClassName];
	  Class subClass = NSClassFromString(subClassName);
	  [archiver setClassName: realClassName
		    forClass: subClass];
	}
      
      /*
       * Initialize templates 
       */
      [self _replaceObjectsWithTemplates: archiver];
      [archiver setOutputFormat: NSPropertyListXMLFormat_v1_0]; // force XML output for now....
      [archiver encodeObject: _container forKey: @"IB.objectdata"];
      [archiver finishEncoding];
      RELEASE(archiver); // We're done with the archiver here..
      
      /* 
       * Add the gorm, info and classes files to the package.
       */
      fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: archiverData];
      [fileWrappers setObject: fileWrapper forKey: nibPath];
      RELEASE(fileWrapper);
      fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: [classManager nibData]];
      [fileWrappers setObject: fileWrapper forKey: classesPath];
      RELEASE(fileWrapper);
      fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: 
					     [filePrefsManager nibDataWithOpenItems: [self openItems]]];
      [fileWrappers setObject: fileWrapper forKey: infoPath];
      RELEASE(fileWrapper);
    }

  return fileWrappers;
}
@end
