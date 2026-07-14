/* GormDocumentController.m
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
#include <InterfaceBuilder/InterfaceBuilder.h>

#include <GormCore/GormCore.h>

@interface GormGormWrapperLoader : GormWrapperLoader
{
  NSMutableArray *_repairLog;
  id _message;
  id _textField;
  id _panel;
}
@end

@interface NSWindow (Level)
- (int) windowLevel;
@end;

@implementation NSWindow (Level)
- (int) windowLevel
{
  return _windowLevel;
}
@end;

@implementation GormGormWrapperLoader
+ (NSString *) fileType
{
  return @"GSGormFileType";
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _repairLog = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_repairLog);
  [super dealloc];
}

- (void) _openMessagePanel: (NSString *) msg
{
  NSEnumerator *en = [_repairLog objectEnumerator];
  id m = nil;

  if ([NSBundle loadNibNamed: @"GormInconsistenciesPanel"
	       owner: self] == NO)
    {
      NSLog(@"Failed to open message panel...");
    }
  else
    {
      [_message setStringValue: msg];
      
      while((m = [en nextObject]) != nil)
	{
	  [_textField insertText: m];
	}

      [_panel orderFront: self];
    }

  [_repairLog removeAllObjects];
}

/** 
 * The sole purpose of this method is to clean up .gorm files from older
 * versions of Gorm which might have some dangling references.   This method
 * may be added to as time goes on to make sure that it's possible 
 * to repair old .gorm files.
 */
- (void) _repairFile
{
  NSEnumerator *en = [[[document nameTable] allKeys] objectEnumerator];
  NSString *key = nil;
  int errorCount = 0;
  NSString *errorMsg = nil;
  NSArray *connections = [document allConnectors];
  id con = nil;

  NSRunAlertPanel(_(@"Warning"), 
		  _(@"You are running with 'GormRepairFileOnLoad' set to YES."),
		  nil, nil, nil);

  /**
   * Iterate over all objects in nameTable.
   */
  [document deactivateEditors];
  while((key = [en nextObject]) != nil)
  {
    id obj = [[document nameTable] objectForKey: key];

    /*
     * Take care of any dangling menus...
     */
    if ([obj isKindOfClass: [NSMenu class]] && ![key isEqual: @"NSMenu"])
      {
	id sm = [obj supermenu];
	if (sm == nil)
	  {
	    NSArray *menus = findAll(obj);
	    [_repairLog addObject: 
			  [NSString stringWithFormat: @"ERROR ==> Found and removed a dangling menu %@, %@.\n",
				    obj, key]];
	    [document detachObjects: menus];
	    [document detachObject: obj];
	    
	    // Since the menu is a top level object, it is not retained by
	    // anything else.  When it was unarchived it was autoreleased, and
	    // the detach also does a release.  Unfortunately, this causes a
	    // crash, so this extra retain is only here to stave off the 
	    // release, so the autorelease can release the menu when it should.
	    RETAIN(obj); // extra retain to stave off autorelease...
	    errorCount++;
	  }
      }

    /*
     * If there is a view which is not associated with a name, give it one...
     */
    if ([obj isKindOfClass: [NSWindow class]])
      {
        NSWindow *w = (NSWindow *)obj;
	NSArray *allViews = allSubviews([obj contentView]);
	NSEnumerator *ven = [allViews objectEnumerator];
	id v = nil;

	if ([w windowLevel] != NSNormalWindowLevel)
	  {
	    [w setLevel: NSNormalWindowLevel];
	    [_repairLog addObject: 
			  [NSString stringWithFormat: 
				      @"ERROR ==> Found window %@ with an invalid level, correcting.\n", 
				    obj]];
	    errorCount++;
	  }
	
	while((v = [ven nextObject]) != nil)
	  {
	    NSString *name = nil;
            id target = nil;
            SEL action = NULL;
            BOOL isAction = NO;
            
	    // skip these...
	    if ([v isKindOfClass: [NSMatrix class]])
	      {
		[_repairLog addObject: @"INFO: Skipping NSMatrix view.\n"];
		continue;
	      }
	    else if ([v isKindOfClass: [NSScroller class]] &&
		    [[v superview] isKindOfClass: [NSTextView class]])
	      {
		[_repairLog addObject: @"INFO: Skipping NSScroller in an NSTextView.\n"];
		continue;
	      }
	    else if ([v isKindOfClass: [NSScroller class]] &&
		    [[v superview] isKindOfClass: [NSBrowser class]])
	      {
		[_repairLog addObject: @"INFO: Skipping NSScroller in an NSTextView.\n"];
		continue;
	      }
	    else if ([v isKindOfClass: [NSClipView class]] &&
		    [[v superview] isKindOfClass: [NSTextView class]])
	      {
		[_repairLog addObject: @"INFO: Skipping NSClipView in an NSTextView.\n"];
		continue;
	      }
	    else if ([v isKindOfClass: [NSClipView class]] &&
		    [[v superview] isKindOfClass: [NSBrowser class]])
	      {
		[_repairLog addObject: @"INFO: Skipping NSClipView in an NSTextView.\n"];
		continue;
	      }

	    if ((name = [document nameForObject: v]) == nil)
	      {
		[document attachObject: v toParent: [v superview]];
		name = [document nameForObject: v];
		[_repairLog addObject: 
			      [NSString stringWithFormat: 
					  @"ERROR ==> Found view %@ without an associated name, adding to the nametable as %@\n", 
					v, name]];
		if ([v respondsToSelector: @selector(stringValue)])
		  {
		    [_repairLog addObject: [NSString stringWithFormat: @"INFO: View string value is %@\n",[v stringValue]]];
		  }
		errorCount++;
	      }

            // Delete old target action settings if they are directly encoded.
            if ([v respondsToSelector: @selector(setTarget:)])
              {
                target = [v target];
                [v setTarget: nil]; // remove hard set targets or actions.
		[_repairLog addObject: [NSString stringWithFormat:
                                                          @"ERROR: Removing hard set target %@ on object %@.\n",
                                                                      target, name]];
                errorCount++;                
              }

            // delete action...
            if ([v respondsToSelector: @selector(setAction:)])
              {
                action = [v action];
                [v setAction: NULL]; // remove hard set targets or actions.
		[_repairLog addObject: [NSString stringWithFormat:
                                                          @"ERROR: Removing hard set action %@ on object %@.\n",
                                                 NSStringFromSelector(action),
                                                 name]];
		errorCount++;                
              }
            
            NSString *actionName = NSStringFromSelector(action);
            isAction = [actionName containsString: @":"];
            
            // create control connector...
            if (action != NULL && target != nil && isAction)
              {
                NSNibControlConnector *con = [[NSNibControlConnector alloc] init];
                [con setDestination: name];
                [con setLabel: actionName];
                [document addConnector: con];
                [document touch];
                
                [_repairLog addObject: [NSString stringWithFormat:
                                                          @"FIX: Creating outlet connection for %@ on %@.\n",
                                                 NSStringFromSelector(action),
                                                 name]];
                errorCount++;
              }

            // create outlet connector...
            if (action != NULL && target != nil && !isAction)
              {
                NSString *actionName = NSStringFromSelector(action);
                NSNibOutletConnector *con = [[NSNibOutletConnector alloc] init];
                [con setDestination: name];
                [con setLabel: actionName];
                [document addConnector: con];
                [document touch];
                
                [_repairLog addObject: [NSString stringWithFormat:
                                                          @"FIX: Creating control connection for %@ on %@.\n",
                                                 NSStringFromSelector(action),
                                                 name]];
                errorCount++;
              }

            
	    [_repairLog addObject: [NSString stringWithFormat: @"INFO: Checking view %@ with name %@\n", v, name]];
	  }
      }
  }
  [document reactivateEditors];
  
  /**
   * Iterate over all connections...  remove connections with nil sources.
   */
  en = [connections objectEnumerator];
  while((con = [en nextObject]) != nil)
    {
      id src = [con source];
      id dst = [con destination];
      if ([con isKindOfClass: [NSNibConnector class]])
	{
	  if (src == nil)
	    {
	      [_repairLog addObject: 
			    [NSString stringWithFormat: @"ERROR ==> Removing bad connector with nil source: %@\n",con]];
	      [document removeConnector: con];
	      errorCount++;
	    }
	  else if ([src isKindOfClass: [NSString class]])
	    {
	      id obj = [document objectForName: src];
	      if (obj == nil)
		{
		  [_repairLog addObject: 
				[NSString stringWithFormat: 
					    @"ERROR ==> Removing bad connector with source that is not in the nametable: %@\n",
					  con]];
		  [document removeConnector: con];
		  errorCount++;
		}
	    }
	  else if ([dst isKindOfClass: [NSString class]])
	    {
	      id obj = [document objectForName: dst];
	      if (obj == nil)
		{
		  [_repairLog addObject: 
				[NSString stringWithFormat: 
					    @"ERROR ==> Removing bad connector with destination that is not in the nametable: %@\n",
					  con]];
		  [document removeConnector: con];
		  errorCount++;
		}
	    }
	}
    }
  
  // report the number of errors...
  if (errorCount > 0)
    {
      errorMsg = [NSString stringWithFormat: @"%d inconsistencies were found, please save the file.",errorCount]; 
      [self _openMessagePanel: errorMsg];
      [document touch];
    }
}

/**
 * Private method.  Determines if the document contains an instance of a given
 * class or one of it's subclasses.
 */
- (BOOL) _containsKindOfClass: (Class)cls
{
  NSEnumerator *en = [[document nameTable] objectEnumerator];
  id obj = nil;
  while((obj = [en nextObject]) != nil)
    {
      if ([obj isKindOfClass: cls])
	{
	  return YES;
	}
    }
  return NO;
}

- (BOOL) loadFileWrapper: (NSFileWrapper *)wrapper withDocument: (GormDocument *) doc
{
  BOOL result = NO;

  NS_DURING
    {
      NSData		        *data = nil;
      NSData                    *classes = nil;
      NSUnarchiver		*u = nil;
      NSEnumerator		*enumerator = nil;
      id <IBConnectors>	         con = nil;
      NSString                  *ownerClass, *key = nil;
      BOOL                       repairFile = [[NSUserDefaults standardUserDefaults] 
						boolForKey: @"GormRepairFileOnLoad"];
      GormPalettesManager       *palettesManager = [(id<GormAppDelegate>)[NSApp delegate] palettesManager];
      NSDictionary              *substituteClasses = [palettesManager substituteClasses];
      NSEnumerator              *en = [substituteClasses keyEnumerator];
      NSString                  *subClassName = nil;
      NSUInteger           	version = NSNotFound;
      NSDictionary              *fileWrappers = nil;
      GSNibContainer            *container;
      NSArray                   *visible;
      NSArray                   *deferred;
      GormFilesOwner            *filesOwner;
      GormFirstResponder        *firstResponder;
      NSArray                   *objs;
      NSMutableArray            *connections;
      NSDictionary              *nt;
      id                        visObj;
      id                        defObj;

      if ([super loadFileWrapper: wrapper withDocument: doc])
	{
	  GormClassManager *classManager = [document classManager];

	  key = nil;
	  if ([wrapper isDirectory])
	    {
	      fileWrappers = [wrapper fileWrappers];
	      
	      enumerator = [fileWrappers keyEnumerator];
	      while((key = [enumerator nextObject]) != nil)
		{
		  NSFileWrapper *fw = [fileWrappers objectForKey: key];
		  if ([fw isRegularFile])
		    {
		      NSData *fileData = [fw regularFileContents];
		      if ([key isEqual: @"objects.gorm"])
			{
			  data = fileData;
			}
		      else if ([key isEqual: @"data.info"])
			{
			  [document setInfoData: fileData];
			}
		      else if ([key isEqual: @"data.classes"])
			{
			  classes = fileData;
			  
			  // load the custom classes...
			  if (![classManager loadCustomClassesWithData: classes]) 
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
	  else if ([wrapper isRegularFile]) // if it's a file...  here we need to handle legacy files.
	    {
	      NSString *classesFileName = [[[document documentPath] stringByDeletingPathExtension]
					    stringByAppendingPathExtension: @"classes"];

	      // dump the contents to the data section...
	      data = [wrapper regularFileContents];
	      classes = [NSData dataWithContentsOfFile: classesFileName];

	      // load the custom classes...
	      if (![classManager loadCustomClassesWithData: classes]) 
		{
		  NSRunAlertPanel(_(@"Problem Loading"), 
				  _(@"Could not open the associated classes file.\n"
				    @"You won't be able to edit connections on custom classes"), 
				  _(@"OK"), nil, nil);
		}
	    }

	  // check the data...
	  if (data == nil || classes == nil)
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
	      u = [[NSUnarchiver alloc] initForReadingWithData: data];
	      
	      /*
	       * Special internal classes
	       */ 
	      [u decodeClassName: @"GSNibItem" 
		 asClassName: @"GormObjectProxy"];
	      [u decodeClassName: @"GSCustomView" 
		 asClassName: @"GormCustomView"];
	      
	      /*
	       * Substitute any classes specified by the palettes...
	       */
	      while((subClassName = [en nextObject]) != nil)
		{
		  NSString *realClassName = [substituteClasses objectForKey: subClassName];
		  [u decodeClassName: realClassName 
		     asClassName: subClassName];
		}
	      
	      // turn off custom classes.
	      [GSClassSwapper setIsInInterfaceBuilder: YES]; 
	      container = [u decodeObject];
	      if (container == nil || [container isKindOfClass: [GSNibContainer class]] == NO)
		{
		  result = NO;
		}
	      else
		{
		  // turn on custom classes.
		  [GSClassSwapper setIsInInterfaceBuilder: NO]; 
		  
		  //
		  // Retrieve the custom class data and refresh the classes view...
		  //
		  [classManager setCustomClassMap: 
				  [NSMutableDictionary dictionaryWithDictionary: 
							 [container customClasses]]];
		  
		  //
		  // Get all of the visible objects...
		  //
		  visible = [container visibleWindows];
		  visObj = nil;
		  enumerator = [visible objectEnumerator];
		  while((visObj = [enumerator nextObject]) != nil)
		    {
		      [document setObject: visObj isVisibleAtLaunch: YES];
		    }
		  
		  //
		  // Get all of the deferred objects...
		  //
		  deferred = [container deferredWindows];
		  defObj = nil;
		  enumerator = [deferred objectEnumerator];
		  while((defObj = [enumerator nextObject]) != nil)
		    {
		      [document setObject: defObj isDeferred: YES];
		    }
		  
		  //
		  // In the newly loaded nib container, we change all the connectors
		  // to hold the objects rather than their names (using our own dummy
		  // object as the 'NSOwner'.
		  //
		  filesOwner = [document filesOwner];
		  firstResponder = [document firstResponder];
		  ownerClass = [[container nameTable] objectForKey: @"NSOwner"];
		  if (ownerClass)
		    {
		      [filesOwner setClassName: ownerClass];
		    }
		  [[container nameTable] setObject: filesOwner forKey: @"NSOwner"];
		  [[container nameTable] setObject: firstResponder forKey: @"NSFirst"];
		  
		  //
		  // Add entries...
		  //
		  [[document nameTable] addEntriesFromDictionary: [container nameTable]];
		  
		  //
		  // Add top level items...
		  //
		  objs = [[container topLevelObjects] allObjects];
		  [[document topLevelObjects] addObjectsFromArray: objs];
		  
		  //
		  // Add connections
		  //
		  connections = [document connections];
		  [connections addObjectsFromArray: [container connections]];
		  
		  /* Iterate over the contents of nameTable and create the connections */
		  nt = [document nameTable];
		  enumerator = [connections objectEnumerator];
		  while ((con = [enumerator nextObject]) != nil)
		    {
		      NSString  *name;
		      id        obj;
		      
		      name = (NSString*)[con source];
		      obj = [nt objectForKey: name];
		      [con setSource: obj];
		      name = (NSString*)[con destination];
		      obj = [nt objectForKey: name];
		      [con setDestination: obj];
		    }
		  
		  /*
		   * If the GSNibContainer version is 0, we need to add the top level objects
		   * to the list so that they can be properly processed.
		   */
		  version = [u versionForClassName: NSStringFromClass([GSNibContainer class])];
		  if (version == 0)
		    {
		      id obj;
		      NSEnumerator *en = [nt objectEnumerator];
		      
		      // get all of the GSNibItem subclasses which could be top level objects
		      while((obj = [en nextObject]) != nil)
			{
			  if ([obj isKindOfClass: [GSNibItem class]] &&
			     [obj isKindOfClass: [GSCustomView class]] == NO)
			    {
			      [[container topLevelObjects] addObject: obj];
			    }
			}
		      [document setOlderArchive: YES];
		    }
		  else if (version == 1)
		    {
		      // nothing else, just mark it as older...
		      [document setOlderArchive: YES];
		    }
		  
		  /*
		   * If the GSWindowTemplate version is 0, we need to let Gorm know that this is
		   * an older archive.  Also, if the window template is not in the archive we know
		   * it was made by an older version of Gorm.
		   */
		  version = [u versionForClassName: NSStringFromClass([GSWindowTemplate class])];
		  if (version == NSNotFound && [self _containsKindOfClass: [NSWindow class]])
		    {
		      [document setOlderArchive: YES];
		    }
		  
		  /* 
		   * Rebuild the mapping from object to name for the nameTable... 
		   */
		  [document rebuildObjToNameMapping];
		  
		  /*
		   * Repair the .gorm file, if needed.
		   */
		  if (repairFile)
		    {
		      [self _repairFile];
		    }
                  NSDebugLog(@"nameTable = %@",[container nameTable]);
		  
		  // awaken all elements after the load is completed.
		  enumerator = [nt keyEnumerator];
		  while ((key = [enumerator nextObject]) != nil)
		    {
		      id o = [nt objectForKey: key];
		      if ([o respondsToSelector: @selector(awakeFromDocument:)])
			{
			  [o awakeFromDocument: document];
			}
		    }
		  
		  // document opened...
		  [document setDocumentOpen: YES];
		  
		  // release the unarchiver..
		  RELEASE(u);
		  
		  // done...
		  result = YES;
		}
	    }
	}
    }
  NS_HANDLER
    {
      id delegate = [NSApp delegate];
      NSString *errorMessage = [NSString stringWithFormat: @"Failed to load file.  Exception: %@",[localException reason]];

      [delegate exceptionWhileLoadingModel: errorMessage];
      result = NO; 
    }
  NS_ENDHANDLER;

  // if we made it here, then it was a success....
  return result;
}
@end
