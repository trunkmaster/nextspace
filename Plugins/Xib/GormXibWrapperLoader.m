/* GormXibWrapperLoader
 *
 * Copyright (C) 2010, 2021 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2010, 2021
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

#include <GNUstepGUI/GSXibKeyedUnarchiver.h>
#include <GormCore/GormCore.h>

#include "GormXibWrapperLoader.h"

/*
 * This allows us to retrieve the customClasses from the XIB unarchiver.
 */
@interface NSKeyedUnarchiver (Private)
- (NSDictionary *) customClasses;
- (NSDictionary *) decoded;
@end

/*
 * Allow access to the method to instantiate the font manager
 */
@interface GormDocument (XibPluginPrivate)
- (void) _instantiateFontManager;
@end

/*
 * Xib loader...
 */
@implementation GormXibWrapperLoader

+ (NSString *) fileType
{
  return @"GSXibFileType";
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      _idToName = [[NSMutableDictionary alloc] init];
      _container = nil;
      _nibFilesOwner = nil;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_idToName);
  [super dealloc];
}

//
// This method returns the "real" object that should be used in gorm for either
// the custom object, its substitute, or a standin object such as file's owner
// or first responder.
//
- (id) _replaceProxyInstanceWithRealObject: (id)obj
			      classManager: (GormClassManager *)classManager
				    withID: (NSString *)theId
{
  id result = obj;
  
  if ([obj isKindOfClass: [NSCustomObject class]])
    {
      NSString *className = [obj className];
      if ([className isEqualToString: @"NSApplication"])
        {
          result = [document filesOwner];
	  [obj setRealObject: result];
        }
      else if ([className isEqualToString: @"FirstResponder"])
        {
          result = [document firstResponder];
	  [obj setRealObject: result];
        }
      else if ([className isEqualToString: @"NSFontManager"])
	{
	  [document _instantiateFontManager];
	  result = [document fontManager];
	  [obj setRealObject: result];
	}
      else
	{
	  result = [obj realObject];
	}
    } 
  else if (theId != nil)
    {
      id o = [_idToName objectForKey: theId];
      if (o != nil)
	{
	  result = o;
	}
      else
	{
	  result = [document firstResponder];
	}
    }
  else
    {
      NSDebugLog(@"### ID not provided and could not find name for object %@", obj);
    }
  
  return result;
}

//
// This method instantiates the custom class and inserts it into the document
// so that it can be referenced from elsewhere in the data.
//
- (void) _handleCustomClassWithObject: (id)obj
			 withDocument: (GormDocument *)doc
{
  if ([obj isKindOfClass: [NSCustomObject class]])
    {
      NSString *customClassName = [obj className];
      NSDictionary *customClassDict = [_customClasses objectForKey: customClassName];;
      NSString *theId = [customClassDict objectForKey: @"id"];
      NSString *parentClassName = [customClassDict objectForKey: @"parentClassName"];
      id realObject = [_decoded objectForKey: theId];
      NSString *theName = nil;
      GormClassManager *classManager = [doc classManager];
      
      // Set the file's owner correctly...
      if ([theId isEqualToString: @"-2"]) // The File's Owner node...
	{
	  [[doc filesOwner] setClassName: customClassName];
	  return;
	}
      
      // these are preset values
      if ([theId isEqualToString: @"-1"]
	  || [theId isEqualToString: @"-3"])
	{
	  return;
	}
      
      // Get the "real" object...
      realObject = [self _replaceProxyInstanceWithRealObject: realObject
						classManager: classManager
						      withID: theId];

      // Check that it has a name...
      NSDebugLog(@"realObject = %@", realObject);      
      if ([doc containsObject: realObject])
	{
	  theName = [doc nameForObject: realObject];
	  NSDebugLog(@"Found name = %@ for realObject = %@", theName, realObject);
	}
      else
	{
	  NSDebugLog(@"realObject = %@ has no name in document", realObject);
	}

      // If the parent class is "NSCustomObject" or it's derivatives...
      // then the parent is NSObject
      if ([parentClassName isEqualToString: @"NSCustomObject5"]
	  || [parentClassName isEqualToString: @"NSCustomObject"])
	{
	  parentClassName = @"NSObject";
	}

      // Add the custom class to the document
      NSDebugLog(@"Adding customClassName = %@ with parent className = %@", customClassName,
	    parentClassName);
      [classManager addClassNamed: customClassName
	      withSuperClassNamed: parentClassName
		      withActions: nil
		      withOutlets: nil
			 isCustom: YES];

      // If the name of the object does not exist, then create it...
      // the name not existing means the object is not attached or associated
      // with the document, so we must create it here since it is a
      // custom object.
      if (theName == nil)
	{
	  theName = [doc instantiateClassNamed: customClassName];
	}

      // Create a mapping between the name and the id. This way we can look
      // this up when needed later, if necessary.  It is not done in the above
      // if since the object might already have a name.
      if (theName != nil)
	{
	  [_idToName setObject: theName forKey: theId];
	}

      // Add the instantiated object to the NSCustomObject
      id instantiatedObject = [doc objectForName: theName];
      if (instantiatedObject != nil)
	{
	  [obj setRealObject: instantiatedObject];
	}
      else
	{
	  NSDebugLog(@"Instantiated object not found for %@", theName);
	}
    }
  else
    {
      NSDebugLog(@"%@ is not an instance of NSCustomObject", obj);
    }
}

- (BOOL) loadFileWrapper: (NSFileWrapper *)wrapper withDocument: (GormDocument *) doc
{
  BOOL result = NO;

  NS_DURING
    {
      GormPalettesManager       *palettesManager = [(id<GormAppDelegate>)[NSApp delegate] palettesManager];
      NSDictionary              *substituteClasses = [palettesManager substituteClasses];
      NSString                  *subClassName = nil;
      GormClassManager          *classManager = [doc classManager];

      document = doc; // make sure they are the same...
      if ([super loadFileWrapper: wrapper 
                    withDocument: doc] &&
	  [wrapper isDirectory] == NO)
	{
	  NSData *data = [wrapper regularFileContents];
	  id docFilesOwner;

	  // turn off custom classes...
	  [NSClassSwapper setIsInInterfaceBuilder: YES];	  
	  
	  // check the data...
	  if (data == nil) 
	    {
	      result = NO;
	    }
	  else
	    {
              NSEnumerator *en;
              NSKeyedUnarchiver *u; // using superclass for its interface.

	      //
	      // Create an unarchiver, and use it to unarchive the xib file while
	      // handling class replacement so that standard objects understood
	      // by the gui library are converted to their Gorm internal equivalents.
	      //
	      u = [GSXibKeyedUnarchiver unarchiverForReadingWithData: data];
	      [u setDelegate: self];
	      
	      //
	      // Special internal classes
	      // 
	      [u setClass: [GormCustomView class] 
		 forClassName: @"NSCustomView"];
	      [u setClass: [GormWindowTemplate class] 
		 forClassName: @"NSWindowTemplate"];
	      [u setClass: [GormNSWindow class] 
		 forClassName: @"NSWindow"];
              [u setClass: [IBUserDefinedRuntimeAttribute class]
                 forClassName: @"IBUserDefinedRuntimeAttribute5"];
	      
	      //
	      // Substitute any classes specified by the palettes...  Palettes can specify
	      // substitute classes to use in place of certain classes, among them is
	      // NSMenu, this is so that their standins can be automatically used.
	      //
	      en = [substituteClasses keyEnumerator];
	      while ((subClassName = [en nextObject]) != nil)
		{
		  NSString *realClassName = [substituteClasses objectForKey: subClassName];
		  Class substituteClass = NSClassFromString(subClassName);
		  [u setClass: substituteClass
		     forClassName: realClassName];
		}
	      
	      //
	      // decode
	      //
	      _container = [u decodeObjectForKey: @"IBDocument.Objects"];
	      if (_container == nil || [_container isKindOfClass: [IBObjectContainer class]] == NO)
		{
		  result = NO;
		}
	      else
		{
		  IBConnectionRecord *cr = nil;
                  NSArray *rootObjects = nil;
                  id xibFirstResponder = nil;

                  rootObjects = [u decodeObjectForKey: @"IBDocument.RootObjects"];
		  xibFirstResponder = [rootObjects objectAtIndex: 1];
		  docFilesOwner = [doc filesOwner];
		  _customClasses = [u customClasses];
		  _nibFilesOwner = [rootObjects objectAtIndex: 0];
		  _decoded = [u decoded];
		  
		  //
		  // set the current class on the File's owner...
		  //
		  if ([_nibFilesOwner isKindOfClass: [NSCustomObject class]])
		    {
		      [docFilesOwner setClassName: [_nibFilesOwner className]];	  
		    }
		  
		  //
		  // add root objects...
		  //
		  en = [rootObjects objectEnumerator];
                  id obj = nil;
		  while ((obj = [en nextObject]) != nil)
		    {
		      NSString *customClassName = nil;
		      NSString *objName = nil;
		      
		      // skip the file's owner, it is handled above...
		      if ((obj == _nibFilesOwner)
			  || (obj == xibFirstResponder))
                        {
                          continue;
                        }

                      //
                      // If it's NSApplication (most likely the File's Owner)
                      // skip it...
                      //
                      if ([obj isKindOfClass: [NSCustomObject class]])
                        {
                          if ([[obj className] isEqualToString: @"NSApplication"])
                            {
                              continue;
                            }

                          customClassName = [obj className];
                        }
                      
		      //
		      // if it's a window template, then replace it with an
                      // actual window.
		      //
                      id o = nil;
		      if ([obj isKindOfClass: [GormWindowTemplate class]])
			{
			  NSString *className = [obj className];
			  BOOL isDeferred = [obj isDeferred];
			  BOOL isVisible = YES;
                          
			  // make the object deferred/visible...
			  o = [obj nibInstantiate];
                          NSDebugLog(@"Decoding window as %@", o);
			  
			  [doc setObject: o isDeferred: isDeferred];
			  [doc setObject: o isVisibleAtLaunch: isVisible];

                          // Add to the document...			  
                          [doc attachObject: o
                                   toParent: nil];			  
			  
			  // record the custom class...
			  if ([classManager isCustomClass: className])
			    {
			      customClassName = className;
			    }
			}

		      // Handle custom classes
		      if ([rootObjects containsObject: obj] && obj != nil &&
                          [obj isKindOfClass: [GormWindowTemplate class]] == NO)
			{
                          NSDebugLog(@"obj = %@",obj);
			  if ([obj respondsToSelector: @selector(className)])
			    {
			      if ([obj isKindOfClass: [NSCustomObject class]])
				{
				  [self _handleCustomClassWithObject: obj
							withDocument: doc];
				  continue;
				}
			    }
			  
                          [doc attachObject: obj
				   toParent: nil];
                        }
                      
		      if (customClassName != nil)
			{
			  objName = [doc nameForObject: obj];
                          if (objName != nil)
                            {
                              [classManager setCustomClass: customClassName
                                                   forName: objName];
                            }
                        }
                    }
		  
		  /*
                   * add connections...
                   */
		  NSDebugLog(@"_idToName = %@", _idToName);
		  en = [_container connectionRecordEnumerator];
		  while ((cr = [en nextObject]) != nil)
		    {
		      IBConnection *conn = [cr connection];
                      
                      if ([conn respondsToSelector: @selector(nibConnector)])
                        {
                          NSNibConnector *o = [conn nibConnector];
                          
                          if (o != nil)
                            {
                              id dest = [o destination];
                              id src = [o source];

                              NSDebugLog(@"Initial connector = %@", o);
			      NSDebugLog(@"dest = %@, src = %@", dest, src);

			      // Replace files owner with the document files owner for loading...
                              dest = [self _replaceProxyInstanceWithRealObject: dest
								  classManager: classManager
									withID: nil];

                              src = [self _replaceProxyInstanceWithRealObject: src
								 classManager: classManager
								       withID: nil];
                              
			      NSString *destName = [document nameForObject: dest];
			      NSString *srcName = [document nameForObject: src];

			      NSDebugLog(@"destName = %@, srcName = %@", destName, srcName);

			      // Use tne names, since this is how connectors are
			      // stored in gorm until they are written out.
                              [o setDestination: dest];
                              [o setSource: src];

                              NSDebugLog(@"*** After connector update = %@", o);

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
				  
				  NSDebugLog(@"*** Action: label = %@ for src = %@, srcName = %@",
					     [o label], src, srcName);
				  
                                  [classManager addAction: [o label]
                                                forObject: src];

                                  // For control connectors these roles are reversed...
                                  [o setSource: dest];
                                  [o setDestination: src];
                                }
                              else if ([o isKindOfClass: [NSNibOutletConnector class]])
                                {
				  NSDebugLog(@"*** Outlet: label = %@ for src = %@, srcName = %@",
					[o label], src, srcName);

                                  [classManager addOutlet: [o label]
                                                forObject: src];
                                }
                              
                              // check src/dest for window template...
                              if ([src isKindOfClass: [NSWindowTemplate class]])
                                {
                                  id win = [src realObject];
                                  [o setSource: win];
                                }
                              
                              if ([dest isKindOfClass: [NSWindowTemplate class]])
                                {
                                  id win = [dest realObject];
                                  [o setDestination: win];
                                }
                              
                              // skip any help connectors...
                              if ([o isKindOfClass: [NSIBHelpConnector class]])
                                {
                                  continue;
                                }

                              [doc addConnector: o];
                            }
                        }
                    }
		  
		  // turn on custom classes.
		  [NSClassSwapper setIsInInterfaceBuilder: NO]; 
		  
		  // clear the changes, since we just loaded the document.
		  [doc updateChangeCount: NSChangeCleared];
		  
		  result = YES;
		}
	    }

	  NSArray *errors = [doc validate];
	  NSDebugLog(@"errors = %@", errors);
	  
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
  if ([obj isKindOfClass: [NSWindowTemplate class]])
    {
      GormClassManager *classManager = [document classManager];
      // Class clz;
      NSString *className = [obj className];
      
      if([classManager isCustomClass: className])
	{
	  className = [classManager nonCustomSuperClassOf: className];
	}
      // clz = [unarchiver classForClassName: className];
    }
  else if ([obj isKindOfClass: [NSMatrix class]])
    {
      if ([obj cellClass] == NULL)
	{
	  [obj setCellClass: [NSButtonCell class]];
	}
    }
  else if ([obj respondsToSelector: @selector(setTarget:)] &&
           [obj respondsToSelector: @selector(setAction:)] &&
           [obj isKindOfClass: [NSCell class]] == NO)
    {
      // blank the target/action for all objects.
      [obj setTarget: nil];
      [obj setAction: NULL];
    }
  return obj;
}
@end
