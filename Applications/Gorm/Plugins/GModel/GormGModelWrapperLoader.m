/* GModelDecoder
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author: Adam Fedor <fedor@gnu.org>
 * Date:   2002
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

#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include <GNUstepGUI/GMArchiver.h>
#include <GNUstepGUI/IMLoading.h>
#include <GNUstepGUI/IMCustomObject.h>
#include <GNUstepGUI/GSDisplayServer.h>

#include "GormGModelWrapperLoader.h"

static Class gmodel_class(NSString *className);

static id gormNibOwner;
static id gormRealObject;
static BOOL gormFileOwnerDecoded;

@interface NSWindow (GormPrivate)
- (void) gmSetStyleMask: (unsigned int)mask;
@end

@implementation NSWindow (GormPrivate)
// private method to change the Window style mask on the fly
- (void) gmSetStyleMask: (unsigned int)mask
{
   _styleMask = mask;
   [GSServerForWindow(self) stylewindow: mask : [self windowNumber]];
}
@end

@interface NSWindow (GormNSWindowPrivate)
- (unsigned int) _styleMask;
@end

@interface GModelApplication : NSObject
{
  id _mainMenu;
  id _windowMenu;
  id _delegate;
  NSArray *_windows;
}

+ (id)createObjectForModelUnarchiver:(GMUnarchiver*)unarchiver;
- (id)initWithModelUnarchiver:(GMUnarchiver*)unarchiver;

- mainMenu;
- windowMenu;
- delegate;
- (NSArray *) windows;

@end

@implementation GModelApplication

- (id)initWithModelUnarchiver:(GMUnarchiver*)unarchiver
{
  NSEnumerator *enumerator;
  NSWindow *win;

  _mainMenu = [unarchiver decodeObjectWithName:@"mainMenu"];

  _windows = [unarchiver decodeObjectWithName:@"windows"];
  enumerator = [_windows objectEnumerator];
  while ((win = [enumerator nextObject]) != nil)
    {
      /* Fix up window frames */
      if ([win styleMask] == NSBorderlessWindowMask)
	{
	  NSLog(@"Fixing borderless window %@", win);
	  [win gmSetStyleMask: NSTitledWindowMask];
	}

      /* Fix up the background color */
      [win setBackgroundColor: [NSColor windowBackgroundColor]];
    }

  _delegate = [unarchiver decodeObjectWithName:@"delegate"];

  return self;
}

- (NSArray *) windows
{
  return _windows;
}

- mainMenu
{
  return _mainMenu;
}

- windowMenu
{
  return _windowMenu;
}

- delegate
{
  return _delegate;
}

+ (id)createObjectForModelUnarchiver:(GMUnarchiver*)unarchiver
{
  return AUTORELEASE([[GModelApplication alloc] init]);
}

@end

@interface GModelMenuTemplate : NSObject
{
  NSString *menuClassName;
  id realObject;
}

+ (id)createObjectForModelUnarchiver:(GMUnarchiver*)unarchiver;
- (id)initWithModelUnarchiver:(GMUnarchiver*)unarchiver;
@end

@implementation GModelMenuTemplate
- (id)initWithModelUnarchiver:(GMUnarchiver*)unarchiver
{
  menuClassName = [unarchiver decodeObjectWithName:@"menuClassName"];
  realObject = [unarchiver decodeObjectWithName: @"realObject"];
  // RELEASE(self);
  return realObject;
}

+ (id)createObjectForModelUnarchiver:(GMUnarchiver*)unarchiver
{
  return AUTORELEASE([[GModelMenuTemplate alloc] init]);
}
@end

@implementation GormObjectProxy (GModel)
+ (id)createObjectForModelUnarchiver:(GMUnarchiver*)unarchiver
{
  return AUTORELEASE([[self alloc] init]);
}

- (id)initWithModelUnarchiver: (GMUnarchiver*)unarchiver
{
  // id extension;
  id realObject;

  theClass = RETAIN([unarchiver decodeStringWithName: @"className"]);
  // extension = [unarchiver decodeObjectWithName: @"extension"];
  realObject = [unarchiver decodeObjectWithName: @"realObject"];

  //real = [unarchiver representationForName: @"realObject" isLabeled: &label];
  if (!gormFileOwnerDecoded || 
      [realObject isKindOfClass: [GModelApplication class]]) 
    {
      gormFileOwnerDecoded = YES;
      gormNibOwner = self;
      gormRealObject = realObject;
    }  
  return self;
}
@end


@implementation GormCustomView (GModel)
+ (id)createObjectForModelUnarchiver:(GMUnarchiver*)unarchiver
{
  return AUTORELEASE([[self alloc] initWithFrame: NSMakeRect(0,0,10,10)]);
}

- (id)initWithModelUnarchiver:(GMUnarchiver*)unarchiver
{
  NSString *cn;
  id realObject;
  // id extension;

  cn = [unarchiver decodeStringWithName: @"className"];
  // extension = [unarchiver decodeObjectWithName: @"extension"];
  realObject = [unarchiver decodeObjectWithName: @"realObject"];
  [self setFrame: [unarchiver decodeRectWithName: @"frame"]];
  [self setClassName: cn];

  if (!gormFileOwnerDecoded) 
    {
      gormFileOwnerDecoded = YES;
      gormNibOwner = self;
      gormRealObject = realObject;
   }
  
  return self;
}
@end

@interface GormDocument (GModelLoaderAdditions)
- (void) defineClass: (id)className inFile: (NSString *)path;
- (id) connectionObjectForObject: object;
- (NSDictionary *) processModel: (NSMutableDictionary *)model
			 inPath: (NSString *)path;
@end

@implementation GormDocument (GModelLoaderAdditions)
/* Try to define a possibly custom class that's in the gmodel
   file. This is not information that is contained in the file
   itself. For instance, we don't even know what the superclass
   is, and at best, we could search the connections to see what
   outlets and actions are used.
*/
- (void) defineClass: (id)className inFile: (NSString *)path
{
  int result;
  NSString *header;
  NSFileManager *mgr;
  NSRange notFound = NSMakeRange(NSNotFound, 0);

  if ([classManager isKnownClass: className])
    return;
  
  /* Can we parse a header in this directory? */
  mgr = [NSFileManager defaultManager];
  path = [path stringByDeletingLastPathComponent];
  header = [path stringByAppendingPathComponent: className];
  header = [header stringByAppendingPathExtension: @"h"];
  if ([mgr fileExistsAtPath: header])
    {
      result = 
	NSRunAlertPanel(_(@"GModel Loading"),
			_(@"Parse %@ to define unknown class %@?"),
			_(@"Yes"), _(@"No"), _(@"Choose File"),
			header, className, nil);
    }
  else
    {
      result = 
	NSRunAlertPanel(_(@"GModel Loading"),
			_(@"Unknown class %@. Parse header file to define?"),
			_(@"Yes"), _(@"No, Choose Superclass"), nil,
			className, nil);
      if (result == NSAlertDefaultReturn)
	result = NSAlertOtherReturn;
    }
  if (result == NSAlertOtherReturn)
    {
      NSOpenPanel *opanel = [NSOpenPanel openPanel];
      NSArray	  *fileTypes = [NSArray arrayWithObjects: @"h", @"H", nil];
      result = [opanel runModalForDirectory: path
		       file: nil
		      types: fileTypes];
      if (result == NSOKButton)
	{
	  header = [opanel filename];
	  result = NSAlertDefaultReturn;
	}
    }

  // make a guess and warn the user
  if (result != NSAlertDefaultReturn)
    {
      NSString *superClass = promptForClassName([NSString stringWithFormat: @"Superclass: %@",className],
						[classManager allClassNames]);
      BOOL added = NO;
      
      // cheesy attempt to determine superclass..
      if(superClass == nil)
	{
	  if([className isEqual: @"GormCustomView"])
	    {
	      superClass = @"NSView";
	    }
	  else if(NSEqualRanges(notFound,[className rangeOfString: @"Window"]) == NO)
	    {
	      superClass = @"NSWindow"; 
	    }
	  else if(NSEqualRanges(notFound,[className rangeOfString: @"Panel"]) == NO)
	    {
	      superClass = @"NSPanel";
	    }
	  else
	    {
	      superClass = @"NSObject";
	    }
	}

      added = [classManager addClassNamed: className
			    withSuperClassNamed: superClass
			    withActions: [NSMutableArray array]
			    withOutlets: [NSMutableArray array]];

      // inform the user...
      if(added)
	{
	  NSLog(@"Added class %@ with superclass of %@.", className, superClass);
	}
      else
	{
	  NSLog(@"Failed to add class %@ with superclass of %@.", className, superClass);
	}
    }
  else
    {
      NS_DURING
	{
	  if(![classManager parseHeader: header])
	    {
	      NSString *file = [header lastPathComponent];
	      NSString *message = [NSString stringWithFormat: 
					      _(@"Unable to parse class in %@"),file];
	      NSRunAlertPanel(_(@"Problem parsing class"), 
			      message,
			      nil, nil, nil);
	    }
	}
      NS_HANDLER
	{
	  NSString *message = [localException reason];
	  NSRunAlertPanel(_(@"Problem parsing class"), 
			  message,
			  nil, nil, nil);
	}
      NS_ENDHANDLER;
    }
}

/* Replace the proxy with the real object if necessary and make sure there
   is a name for the connection object */
- (id) connectionObjectForObject: object
{
  if (object == nil)
    return nil;
  if (object == gormNibOwner)
    object = filesOwner;
  else
    [self setName: nil forObject: object];
  return object;
}

- (NSDictionary *) processModel: (NSMutableDictionary *)model
			 inPath: (NSString *)path
{
  NSMutableDictionary *customMap = nil;
  NSEnumerator *en = [model keyEnumerator];
  NSMutableArray *deleted = [NSMutableArray array];
  id key;

  NSLog(@"Processing model...");
  while((key = [en nextObject]) != nil)
    {
      NSDictionary *obj = [model objectForKey: key];
      if(obj != nil)
	{
	  if([obj isKindOfClass: [NSDictionary class]])
	    {
	      NSString *objIsa = [(NSMutableDictionary *)obj objectForKey: @"isa"];
	      Class cls = NSClassFromString(objIsa);
	      
	      if(cls == nil)
		{
		  // Remove this class.  It's not defined on GNUstep and it's generally
		  // useless.
		  if([objIsa isEqual: @"NSNextStepFrame"])
		    {
		      NSString *subviewsKey = [obj objectForKey: @"subviews"];
		      NSDictionary *subviews = [model objectForKey: subviewsKey];
		      NSArray *elements = [subviews objectForKey: @"elements"];
		      NSEnumerator *subViewEnum = [elements objectEnumerator];
		      NSString *svkey = nil;
		      
		      while((svkey = [subViewEnum nextObject]) != nil)
			{
			  [deleted addObject: svkey];
			}
		      
		      [deleted addObject: key];
		      [deleted addObject: subviewsKey];
		      continue;
		    }
		  
		  if([objIsa isEqual: @"NSImageCacheView"])
		    {
		      // this is eliminated in the NSNextStepFrame section above.
		      continue;
		    }
 
		  if([classManager isKnownClass: objIsa] == NO &&
		     [objIsa isEqual: @"IMControlConnector"] == NO &&
		     [objIsa isEqual: @"IMOutletConnector"] == NO &&
		     [objIsa isEqual: @"IMCustomObject"] == NO &&
		     [objIsa isEqual: @"IMCustomView"] == NO)
		    {
		      NSString *superClass;
		      
		      NSLog(@"%@ is not a known class",objIsa);
		      [self defineClass: objIsa inFile: path];
		      superClass = [classManager superClassNameForClassNamed: objIsa];
		      [(NSMutableDictionary *)obj setObject: superClass forKey: @"isa"];
		    }
		}
	    }
	}
    }

  // remove objects marked for deletion the model.
  en = [deleted objectEnumerator];
  while((key = [en nextObject]) != nil)
    {
      [model removeObjectForKey: key];
    }
  
  return customMap;
}
@end

@implementation GormGModelWrapperLoader
+ (NSString *) fileType
{
  return @"GSGModelFileType";
}

/* importing of legacy gmodel files.*/
- (BOOL) loadFileWrapper: (NSFileWrapper *)wrapper withDocument: (GormDocument *) doc
{
  id obj, con;
  id unarchiver;
  id decoded;
  NSEnumerator *enumerator;
  NSArray *gmobjects;
  NSArray *gmconnections;
  Class u = gmodel_class(@"GMUnarchiver");
  NSString *delegateClass = nil;
  NSData *data = [wrapper regularFileContents];
  NSString *dictString = AUTORELEASE([[NSString alloc] initWithData: data 
						       encoding: NSASCIIStringEncoding]);
  NSMutableDictionary *model = [NSMutableDictionary dictionaryWithDictionary: 
						      [dictString propertyList]];
  NSString *path = [[wrapper filename] stringByDeletingLastPathComponent];

  gormNibOwner = nil;
  gormRealObject = nil;
  gormFileOwnerDecoded = NO;
  /* GModel classes */
  [u decodeClassName: @"NSApplication"     asClassName: @"GModelApplication"];
  [u decodeClassName: @"IMCustomView"      asClassName: @"GormCustomView"];
  [u decodeClassName: @"IMCustomObject"    asClassName: @"GormObjectProxy"];
  /* Gorm classes */
  [u decodeClassName: @"NSMenu"            asClassName: @"GormNSMenu"];
  [u decodeClassName: @"NSWindow"          asClassName: @"GormNSWindow"];
  [u decodeClassName: @"NSPanel"           asClassName: @"GormNSPanel"];
  [u decodeClassName: @"NSBrowser"         asClassName: @"GormNSBrowser"];
  [u decodeClassName: @"NSTableView"       asClassName: @"GormNSTableView"];
  [u decodeClassName: @"NSOutlineView"     asClassName: @"GormNSOutlineView"];
  [u decodeClassName: @"NSPopUpButton"     asClassName: @"GormNSPopUpButton"];
  [u decodeClassName: @"NSPopUpButtonCell" asClassName: @"GormNSPopUpButtonCell"];
  [u decodeClassName: @"NSOutlineView"     asClassName: @"GormNSOutlineView"];
  [u decodeClassName: @"NSMenuTemplate"    asClassName: @"GModelMenuTemplate"];
  [u decodeClassName: @"NSCStringText"     asClassName: @"NSText"];

  // process the model to take care of any custom classes...
  [doc processModel: model inPath: path];
  
  // initialize with the property list...
  unarchiver = [[u alloc] initForReadingWithPropertyList: [[model description] propertyList]];
  if (!unarchiver)
    {
      return NO;
    }
  
  NS_DURING
    {
      decoded = [unarchiver decodeObjectWithName:@"RootObject"];
    }
  NS_HANDLER
    {
      NSRunAlertPanel(_(@"GModel Loading"), [localException reason], 
		      @"Ok", nil, nil);
      return NO;
    }
  NS_ENDHANDLER
  gmobjects = [decoded performSelector: @selector(objects)];
  gmconnections = [decoded performSelector: @selector(connections)];
  
  if (gormNibOwner)
    {
      [doc defineClass: [gormNibOwner className] inFile: path];
      [[document filesOwner] setClassName: [gormNibOwner className]];
    }

  /*
   * Now we merge the objects from the gmodel into our own data
   * structures.
   */
  enumerator = [gmobjects objectEnumerator];
  while ((obj = [enumerator nextObject]))
    {
      if (obj != gormNibOwner)
	{
	  [doc attachObject: obj toParent: nil];
	}

      if([obj isKindOfClass: [GormObjectProxy class]])
	{
	  if([[obj className] isEqual: @"NSFontManager"])
	    {
	      // if it's the font manager, take care of it...
	      [doc setName: @"NSFont" forObject: obj];
	      [doc attachObject: obj toParent: nil];
	    }
	  else 
	    {
	      NSLog(@"processing... %@",[obj className]);
	      [doc defineClass: [obj className] inFile: path];
	    }
	} 
    }

  // build connections...
  enumerator = [gmconnections objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      NSNibConnector *newcon;
      id source, dest;

      source = [doc connectionObjectForObject: [con source]];
      dest   = [doc connectionObjectForObject: [con destination]];
      NSDebugLog(@"connector = %@",con);
      if ([[con className] isEqual: @"IMOutletConnector"]) // We don't link the gmodel library at compile time...
	{
	  newcon = AUTORELEASE([[NSNibOutletConnector alloc] init]);
	  if(![[doc classManager] isOutlet: [con label] 
				  ofClass: [source className]])
	    {
	      [[doc classManager] addOutlet: [con label] 
				  forClassNamed: [source className]];
	    }

	  if([[source className] isEqual: @"NSApplication"])
	    {
	      delegateClass = [dest className];
	    }
	}
      else
	{
	  NSString *className = (dest == nil)?(NSString *)@"FirstResponder":(NSString *)[dest className];
	  newcon = AUTORELEASE([[NSNibControlConnector alloc] init]);
	  
	  if(![[doc classManager] isAction: [con label] 
				  ofClass: className])
	    {
	      [[doc classManager] addAction: [con label] 
				  forClassNamed: className];
	    }	  
	}
      
      NSDebugLog(@"conn = %@  source = %@ dest = %@ label = %@, src name = %@ dest name = %@", newcon, source, dest, 
		 [con label], [source className], [dest className]);
      [newcon setSource: source];
      [newcon setDestination: (dest != nil)?dest:[doc firstResponder]];
      [newcon setLabel: [con label]];
      [[doc connections] addObject: newcon];
    }

  // make sure that all of the actions on the application's delegate object are also added to FirstResponder.
  enumerator = [[doc connections] objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      if([con isKindOfClass: [NSNibControlConnector class]])
	{
	  id dest = [con destination];
	  if([[dest className] isEqual: delegateClass])
	    {
	      if(![[doc classManager] isAction: [con label] 
				      ofClass: @"FirstResponder"])
		{
		  [[doc classManager] addAction: [con label] 
				      forClassNamed: @"FirstResponder"];
		} 
	    }
	}
    }

  if ([gormRealObject isKindOfClass: [GModelApplication class]])
    {
      if([gormRealObject respondsToSelector: @selector(windows)])
	{
	  enumerator = [[gormRealObject windows] objectEnumerator];
	  while ((obj = [enumerator nextObject]))
	    {
	      if([obj isKindOfClass: [NSWindow class]])
		{
		  if([obj _styleMask] == 0)
		    {
		      // Skip borderless window.  Borderless windows are 
		      // sometimes used as temporary objects in nib files, 
		      // they will show up unless eliminated.
		      continue; 
		    }
		}
	      
	      [doc attachObject: obj toParent: nil];
	    }
	  
	  if([gormRealObject respondsToSelector: @selector(mainMenu)])
	    {
	      if ([(GModelApplication *)gormRealObject mainMenu])
		{
		  [doc attachObject: [(GModelApplication *)gormRealObject mainMenu] toParent: nil];
		}
	    }
	}
      
    }
  else if(gormRealObject != nil)
    {
      // Here we need to addClass:... (outlets, actions).  */
      [doc defineClass: [gormRealObject className] inFile: path];
    }
  else
    {
      NSLog(@"Don't understand real object %@", gormRealObject);
    }

  [doc rebuildObjToNameMapping];

  // clear the changes, since we just loaded the document.
  [document updateChangeCount: NSChangeCleared];

  return YES;
}
@end

static 
Class gmodel_class(NSString *className)
{
  static Class gmclass = Nil;

  if (gmclass == Nil)
    {
      NSBundle	*theBundle;
      NSEnumerator *benum;
      NSString	*path;

      /* Find the bundle */
      benum = [NSStandardLibraryPaths() objectEnumerator];
      while ((path = [benum nextObject]))
	{
	  path = [path stringByAppendingPathComponent: @"Bundles"];
	  path = [path stringByAppendingPathComponent: @"libgmodel.bundle"];
	  if ([[NSFileManager defaultManager] fileExistsAtPath: path])
	    break;
	  path = nil;
	}
      NSCAssert(path != nil, @"Unable to load gmodel bundle");
      NSDebugLog(@"Loading gmodel from %@", path);

      theBundle = [NSBundle bundleWithPath: path];
      NSCAssert(theBundle != nil, @"Can't init gmodel bundle");
      gmclass = [theBundle classNamed: className];
      NSCAssert(gmclass, @"Can't load gmodel bundle");
    }
  return gmclass;
}
