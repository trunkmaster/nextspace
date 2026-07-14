/* GormWrapperBuilder
 *
 * Copyright (C) 2006 Free Software Foundation, Inc.
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

#include <GNUstepGUI/GSGormLoading.h>

@interface GormDocument (BuilderAdditions)
- (void) prepareConnections;
- (void) resetConnections;
@end

@implementation GormDocument (BuilderAdditions)
/**
 * Start the process of archiving.
 */
- (void) prepareConnections
{
  NSEnumerator		*enumerator;
  id<IBConnectors>	con;
  id			obj;

  /*
   * Map all connector sources and destinations to their name strings.
   * Deactivate editors so they won't be archived.
   */

  enumerator = [connections objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      NSString	*name;
      obj = [con source];
      name = [self nameForObject: obj];
      [con setSource: name];
      obj = [con destination];
      name = [self nameForObject: obj];
      [con setDestination: name];
    }

  /*
   * Remove objects and connections that shouldn't be archived.
   */
  NSMapRemove(objToName, (void*)[nameTable objectForKey: @"NSOwner"]);
  [nameTable removeObjectForKey: @"NSOwner"];
  NSMapRemove(objToName, (void*)[nameTable objectForKey: @"NSFirst"]);
  [nameTable removeObjectForKey: @"NSFirst"];

  /* Add information about the NSOwner to the archive */
  NSMapInsert(objToName, (void*)[filesOwner className], (void*)@"NSOwner");
  [nameTable setObject: [filesOwner className] forKey: @"NSOwner"];

  /*
   * Set the appropriate profile so that we save the right versions of 
   * the classes for older GNUstep releases.
   */
  [filePrefsManager setClassVersions];
}

/**
 * Stop the archiving process.
 */
- (void) resetConnections
{
  NSEnumerator		*enumerator;
  id<IBConnectors>	con;
  id			obj;

  /*
   * Restore class versions.
   */
  [filePrefsManager restoreClassVersions];

  /*
   * Restore removed objects.
   */
  [nameTable setObject: filesOwner forKey: @"NSOwner"];
  NSMapInsert(objToName, (void*)filesOwner, (void*)@"NSOwner");

  [nameTable setObject: firstResponder forKey: @"NSFirst"];
  NSMapInsert(objToName, (void*)firstResponder, (void*)@"NSFirst");

  /*
   * Map all connector source and destination names to their objects.
   */
  enumerator = [connections objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      NSString	*name;
      name = (NSString*)[con source];
      obj = [self objectForName: name];
      [con setSource: obj];
      name = (NSString*)[con destination];
      obj = [self objectForName: name];
      [con setDestination: obj];
    }
}

@end

@interface GSNibContainer (BuilderAdditions)
- (id) initWithDocument: (GormDocument *)document;
@end;

@implementation GSNibContainer (BuilderAdditions)
- (id) initWithDocument: (GormDocument *)document
{
  if((self = [self init]) != nil)
    {
      NSDictionary          *custom = [[document classManager] customClassMap];

      // Create the container for the .gorm file...
      [topLevelObjects addObjectsFromArray: [[document topLevelObjects] allObjects]];
      [nameTable addEntriesFromDictionary: [document nameTable]];
      [connections addObjectsFromArray: [document connections]];
      [visibleWindows addObjectsFromArray: [[document visibleWindows] allObjects]];
      [deferredWindows addObjectsFromArray: [[document deferredWindows] allObjects]];
      [customClasses addEntriesFromDictionary: custom];
    }
  return self;
}
@end

@interface GormGormWrapperBuilder : GormWrapperBuilder
@end

@implementation GormGormWrapperBuilder
+ (NSString *) fileType
{
  return @"GSGormFileType";
}

/**
 * Private method which iterates through the list of custom classes and instructs 
 * the archiver to replace the actual object with template during the archiving 
 * process.
 */
- (void) _replaceObjectsWithTemplates: (NSArchiver *)archiver
{
  NSEnumerator *en = [[document nameTable] keyEnumerator];
  GormClassManager *classManager = [document classManager];
  GormFilePrefsManager *filePrefsManager = [document filePrefsManager];
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
	  template = [GSTemplateFactory templateForObject: object
					withClassName: customClass 
					withSuperClassName: superClass];
	}
      else if([object isKindOfClass: [NSWindow class]] 
	      && [filePrefsManager versionOfClass: @"GSWindowTemplate"] > 0)
	{
	  template = [GSTemplateFactory templateForObject: object
					withClassName: [object className]
					withSuperClassName: [object className]]; 
	  
	}

      // if the template has been created, replace the object with it.
      if(template != nil)
	{
	  // if the object is deferrable, then set the flag appropriately.
	  if([template respondsToSelector: @selector(setDeferFlag:)])
	    {
	      [template setDeferFlag: [document objectIsDeferred: object]];
	    }
	  
	  //  if the object can accept autoposition information
	  if([object respondsToSelector: @selector(autoPositionMask)])
	    {
	      int mask = [object autoPositionMask];
	      if([template respondsToSelector: @selector(setAutoPositionMask:)])
		{
		  [template setAutoPositionMask: mask];
		}
	    }

	  // replace the object with the template.
	  [archiver replaceObject: object withObject: template];
	}
    }
}

- (NSMutableDictionary *)buildFileWrapperDictionaryWithDocument: (GormDocument *)doc
{
  NSArchiver            *archiver = nil;
  NSMutableData         *archiverData = nil;
  NSString              *gormPath = @"objects.gorm";
  NSString              *classesPath = @"data.classes";
  NSString              *infoPath = @"data.info";
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
      GSNibContainer *container = nil;
      
      [document prepareConnections];
      container = [[GSNibContainer alloc] initWithDocument: document];

      /*
       * Set up archiving...
       */
      archiverData = [NSMutableData dataWithCapacity: 0];
      archiver = [[NSArchiver alloc] initForWritingWithMutableData: archiverData];
      
      /* 
       * Special gorm classes to their archive equivalents. 
       */
      [archiver encodeClassName: @"GormObjectProxy" 
		intoClassName: @"GSNibItem"];
      [archiver encodeClassName: @"GormCustomView"
		intoClassName: @"GSCustomView"];
      
      
      while((subClassName = [en nextObject]) != nil)
	{
	  NSString *realClassName = [substituteClasses objectForKey: subClassName];
	  [archiver encodeClassName: subClassName
		    intoClassName: realClassName];
	}
      
      /*
       * Initialize templates 
       */
      [self _replaceObjectsWithTemplates: archiver];
      [archiver encodeRootObject: container];
      RELEASE(archiver); // We're done with the archiver here..
      
      /* 
       * Add the gorm, info and classes files to the package.
       */
      fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: archiverData];
      [fileWrappers setObject: fileWrapper forKey: gormPath];
      RELEASE(fileWrapper);
      fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: [classManager data]];
      [fileWrappers setObject: fileWrapper forKey: classesPath];
      RELEASE(fileWrapper);
      fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: [filePrefsManager data]];
      [fileWrappers setObject: fileWrapper forKey: infoPath];
      RELEASE(fileWrapper);

      // release the container...
      RELEASE(container);
      [document resetConnections];
    }

  return fileWrappers;
}
@end
