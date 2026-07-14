/* GormNibWrapperLoader
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

#include "GormNibWrapperLoader.h"

@class GormNSWindow;

@implementation GormNibWrapperLoader
+ (NSString *) fileType
{
  return @"GSNibFileType";
}

- (NSDictionary *)defaultClassesDict
{
  NSString *defaultClassesString = @"{ IBClasses = ({CLASS = FirstResponder; LANGUAGE = ObjC; SUPERCLASS = NSObject; }); IBVersion = 1; }";
  return [defaultClassesString propertyList];
}

- (BOOL) isTopLevelObject: (id)obj
{
  NSMapTable *objects = [_container objects];
  id val = NSMapGet(objects,obj);
  BOOL result = NO;

  if(val == _nibFilesOwner || val == nil)
    {
      result = YES;
    }

  return result;
}

- (BOOL) loadFileWrapper: (NSFileWrapper *)wrapper withDocument: (GormDocument *) doc
{
  BOOL result = NO;

  NS_DURING
    {
      NSData		        *data = nil;
      NSData                    *classes = nil;
      NSKeyedUnarchiver		*u = nil;
      NSString                  *key = nil;
      GormPalettesManager       *palettesManager = [(id<GormAppDelegate>)[NSApp delegate] palettesManager];
      NSDictionary              *substituteClasses = [palettesManager substituteClasses];
      NSString                  *subClassName = nil;
      NSDictionary              *fileWrappers = nil;

      if ([super loadFileWrapper: wrapper withDocument: doc])
	{
	  GormClassManager *classManager = [document classManager];
	  id               docFilesOwner;
	  NSMapTable       *objects;
	  NSArray          *objs;
	  NSEnumerator     *en;
	  id               o;
	  NSMapTable       *classesTable;
	  NSArray          *classKeys;

	  // turn off custom classes...
	  [NSClassSwapper setIsInInterfaceBuilder: YES];	  

	  if([wrapper isDirectory])
	    {
	      key = nil;
	      fileWrappers = [wrapper fileWrappers];

	      en = [fileWrappers keyEnumerator];
	      while((key = [en nextObject]) != nil)
		{
		  NSFileWrapper *fw = [fileWrappers objectForKey: key];
		  if([fw isRegularFile])
		    {
		      NSData *fileData = [fw regularFileContents];
		      if([key isEqual: @"keyedobjects.nib"])
			{
			  data = fileData;
			}
		      else if([key isEqual: @"classes.nib"])
			{
			  classes = fileData;
			  
			  // load the custom classes...
			  if (![classManager loadNibFormatCustomClassesWithData: classes]) 
			    {
			      NSRunAlertPanel(_(@"Problem Loading"), 
					      _(@"Could not open the associated classes file.\n"
						@"You won't be able to edit connections on custom classes"), 
					      _(@"OK"), nil, nil);
			    }
			}
		    }
		}
	    }
	  else
	    {
	      data = [wrapper regularFileContents];
	      classes = nil; // (NSData *)0xdeadbeef;
	    }

	  // check the data...
	  if (data == nil)// || classes == nil)
	    {
	      result = NO;
	    }
	  else
	    {
	      /*
	       * Create an unarchiver, and use it to unarchive the gorm file while
	       * handling class replacement so that standard objects understood
	       * by the gui library are converted to their Gorm internal equivalents.
	       */

	      u = [[NSKeyedUnarchiver alloc] initForReadingWithData: data];
	      [u setDelegate: self];
	      
	      /*
	       * Special internal classes
	       */ 
	      [u setClass: [GormCustomView class] 
		 forClassName: @"NSCustomView"];
	      [u setClass: [GormWindowTemplate class] 
		 forClassName: @"NSWindowTemplate"];
	      [u setClass: [GormNSWindow class] 
		 forClassName: @"NSWindow"];
	      
	      /*
	       * Substitute any classes specified by the palettes...
	       */
	      en = [substituteClasses keyEnumerator];
	      while((subClassName = [en nextObject]) != nil)
		{
		  NSString *realClassName = [substituteClasses objectForKey: subClassName];
		  Class substituteClass = NSClassFromString(subClassName);
		  [u setClass: substituteClass
		     forClassName: realClassName];
		}
	      
	      //
	      // decode
	      //
	      _container = [u decodeObjectForKey: @"IB.objectdata"];
	      if (_container == nil || [_container isKindOfClass: [NSIBObjectData class]] == NO)
		{
		  result = NO;
		}
	      else
		{
		  _nibFilesOwner = [_container objectForName: @"File's Owner"];
		  
		  docFilesOwner = [document filesOwner];
		  objects = [_container names];
		  objs = NSAllMapTableKeys(objects);
		  en = [objs objectEnumerator];
		  o = nil;
		  
		  //
		  // set the current class on the File's owner...
		  //
		  if([_nibFilesOwner isKindOfClass: [NSCustomObject class]])
		    {
		      [docFilesOwner setClassName: [_nibFilesOwner className]];	  
		    }
		  
		  //
		  // add objects...
		  //
		  while((o = [en nextObject]) != nil)
		    {
		      id obj = o;
		      NSString *customClassName = nil;
		      NSString *objName = nil;
		      
		      // skip the file's owner, it is handled above...
		      if(o == _nibFilesOwner
			 || o == [document firstResponder])
			{
			  continue;
			}
		      
		      //
                      // If it's NSApplication (most likely the File's Owner)
                      // skip it...
                      //
                      if ([o isKindOfClass: [NSCustomObject class]])
                        {
                          if ([[o className] isEqualToString: @"NSApplication"])
                            {
                              continue;
                            }

                          customClassName = [o className];
                        }
                      
		      //
		      // if it's a window template, then replace it with an actual window.
		      //
		      if([o isKindOfClass: [NSWindowTemplate class]])
			{
			  NSString *className = [o className];
			  BOOL isDeferred = [o isDeferred];
			  BOOL isVisible = [[_container visibleWindows]
                                             containsObject: o];
			  
			  // make the object deferred/visible...
			  obj = [o nibInstantiate];
			  
			  [document setObject: obj isDeferred: isDeferred];
			  [document setObject: obj isVisibleAtLaunch: isVisible];

			  [document attachObject: obj
					toParent: nil];
			  
			  // record the custom class...
			  if([classManager isCustomClass: className])
			    {
			      customClassName = className;
			    }
			}

		      if([self isTopLevelObject: obj])
			{		  
			  [document attachObject: obj
                                        toParent: nil];
			}
		      
		      if(customClassName != nil)
			{
			  objName = [document nameForObject: obj];
			  [classManager setCustomClass: customClassName
                                               forName: objName];
			}
		    }
		  
		  //
		  // Add custom classes...
		  //
		  classesTable = [_container classes];
		  classKeys = NSAllMapTableKeys(classesTable);
		  en = [classKeys objectEnumerator];
		  while((o = [en nextObject]) != nil)
		    {
		      NSString *name = [document nameForObject: o];
		      NSString *customClass = NSMapGet(classesTable, o);
		      if(name != nil && customClass != nil)
			{
			  [classManager setCustomClass: customClass forName: name];
			}
		      else
			{
			  NSLog(@"Name %@ or class %@ for object %@ is nil.", name, customClass, o);
			}
		    }
		  
		  //
		  // add connections...
		  //
		  en = [[_container connections] objectEnumerator];
		  o = nil;
		  while((o = [en nextObject]) != nil)
		    {
		      id dest = [o destination];
		      id src = [o source];
		      
		      // NSLog(@"Connector: %@",o);
		      
		      if([o isKindOfClass: [NSNibControlConnector class]])
			{
			  NSString *tag = [o label];
			  NSRange colonRange = [tag rangeOfString: @":"];
			  NSUInteger location = colonRange.location;
			  
			  if(location == NSNotFound)
			    {
			      NSString *newTag = [NSString stringWithFormat: @"%@:",tag];
			      [o setLabel: (id)newTag];
			    }
			}
		      
		      if(dest == _nibFilesOwner)
			{
			  [o setDestination: [document filesOwner]];
			}
		      else if(dest == nil)
			{
			  [o setDestination: [document firstResponder]];
			}
		      
		      if(src == _nibFilesOwner)
			{
			  [o setSource: [document filesOwner]];
			}
		      else if(src == nil)
			{
			  [o setSource: [document firstResponder]];
			}
		      
		      // check src/dest for window template...
		      if([src isKindOfClass: [NSWindowTemplate class]])
			{
			  id win = [src realObject];
			  [o setSource: win];
			}
		      
		      if([dest isKindOfClass: [NSWindowTemplate class]])
			{
			  id win = [dest realObject];
			  [o setDestination: win];
			}
		      
		      // skip any help connectors...
		      if([o isKindOfClass: [NSIBHelpConnector class]])
			{
			  continue;
			}
		      [document addConnector: o];
		    }
		  
		  // turn on custom classes.
		  [NSClassSwapper setIsInInterfaceBuilder: NO]; 
		  
		  // clear the changes, since we just loaded the document.
		  [document updateChangeCount: NSChangeCleared];
		  
		  result = YES;
		}
	    }
	  [NSClassSwapper setIsInInterfaceBuilder: NO];      
	}
    }
  NS_HANDLER
    {
      NSRunAlertPanel(_(@"Problem Loading"), 
		      [NSString stringWithFormat: @"Failed to load file.  Exception: %@",[localException reason]], 
		      _(@"OK"), nil, nil);
      result = NO; 
    }
  NS_ENDHANDLER;

  // return the result.
  return result;
}

- (void) unarchiver: (NSKeyedUnarchiver *)unarchiver 
  willReplaceObject: (id)obj 
	 withObject: (id)newObj
{
  // Nothing for now...
}

- (id) unarchiver: (NSKeyedUnarchiver *)unarchiver didDecodeObject: (id)obj
{
  if([obj isKindOfClass: [NSWindowTemplate class]])
    {
      GormClassManager *classManager = [document classManager];
      Class clz ;
      NSString *className = [obj className];
      
      if([classManager isCustomClass: className])
	{
	  className = [classManager nonCustomSuperClassOf: className];
	}
      clz = [unarchiver classForClassName: className];
      [obj setBaseWindowClass: clz];
    }
  else if([obj respondsToSelector: @selector(setTarget:)] &&
	  [obj respondsToSelector: @selector(setAction:)] &&
	  [obj isKindOfClass: [NSCell class]] == NO)
    {
      // blank the target/action for all objects.
      [obj setTarget: nil];
      [obj setAction: NULL];
    }
  else if([obj isKindOfClass: [NSCustomObject class]])
    {
      GormObjectProxy *o = [[GormObjectProxy alloc] initWithClassName: [obj className]];
      obj = o; // replace the object if it's an NSCustomObject...
    }

  return obj;
}
@end
