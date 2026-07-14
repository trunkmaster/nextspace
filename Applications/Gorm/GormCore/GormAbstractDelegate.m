/* GormAppDelegate.m
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg.casamento@gmail.com>
 * Date:	2023
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>

#import <AppKit/NSImage.h>
#import <AppKit/NSMenu.h>

#import "GormAbstractDelegate.h"
#import "GormDocument.h"
#import "GormDocumentController.h"
#import "GormFontViewController.h"
#import "GormFunctions.h"
#import "GormGenericEditor.h"
#import "GormPluginManager.h"
#import "GormPrefController.h"
#import "GormPrivate.h"
#import "GormSetNameController.h"

@implementation GormAbstractDelegate

/*
   GormAppDelegate
*/
- (id) init
{
  self = [super init];

  if (self != nil)
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
      NSNotificationCenter      *ndc = [NSDistributedNotificationCenter defaultCenter];
      NSBundle			*bundle = [NSBundle bundleForClass: [self class]];
      NSConnection              *conn = [NSConnection defaultConnection];
      NSString			*path = nil;

      if ([self isInTool] == NO)
	{
	  path = [bundle pathForImageResource: @"GormLinkImage"];
	  _linkImage = [[NSImage alloc] initWithContentsOfFile: path];
	  path = [bundle pathForImageResource: @"GormSourceTag"];
	  _sourceImage = [[NSImage alloc] initWithContentsOfFile: path];
	  path = [bundle pathForImageResource: @"GormTargetTag"];
	  _targetImage = [[NSImage alloc] initWithContentsOfFile: path];
	  path = [bundle pathForImageResource: @"Gorm"];
	  _gormImage = [[NSImage alloc] initWithContentsOfFile: path];
	  path = [bundle pathForImageResource: @"GormTesting"];
	  _testingImage = [[NSImage alloc] initWithContentsOfFile: path];
	}

      // Initialize ivars
      _isTesting = NO;
      
      // regular notifications...
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: IBSelectionChangedNotification
	  object: nil];
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: IBWillCloseDocumentNotification
	  object: nil];

      // distibuted notifications...
      [ndc addObserver: self
	   selector: @selector(handleNotification:)
	   name: @"GormAddClassNotification"
	   object: nil];
      [ndc addObserver: self
	   selector: @selector(handleNotification:)
	   name: @"GormDeleteClassNotification"
	   object: nil];
      [ndc addObserver: self
	   selector: @selector(handleNotification:)
	   name: @"GormParseClassNotification"
	   object: nil];

      /*
       * establish registration domain defaults from file.
       */
      path = [bundle pathForResource: @"Defaults" ofType: @"plist"];
      if (path != nil)
	{
	  NSDictionary	*dict;

	  dict = [NSDictionary dictionaryWithContentsOfFile: path];
	  if (dict != nil)
	    {
	      NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];

	      [defaults registerDefaults: dict];
	    }
	}

      /*
       * Make sure the palettes/plugins managers exist, so that the
       * editors and inspectors provided in the standard palettes
       * are available.
       */
      [self palettesManager];
      [self pluginManager];
      [GormDocumentController sharedDocumentController];

      /*
       * Start the server
       */
      if ([self isInTool] == NO)
	{
	  [conn setRootObject: self];
	  if([conn registerName: @"GormServer"] == NO)
	    {
	      NSLog(@"Could not register GormServer");
	    }
	}
    }
  
  return self;
}

- (void) dealloc
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

  [nc removeObserver: self];
  RELEASE(_inspectorsManager);
  RELEASE(_palettesManager);
  RELEASE(_classManager);
  [super dealloc];
}

// Handle all alerts here...

- (BOOL) shouldUpgradeOlderArchive
{
  NSInteger retval = NSRunAlertPanel(_(@"Compatibility Warning"), 
				     _(@"Saving will update this gorm to the latest version \n" 
				       @"which may not be compatible with some previous versions \n"
				       @"of GNUstep."),
				     _(@"Save"),
				     _(@"Don't Save"), nil, nil);

  return (retval == NSAlertDefaultReturn);
}

- (BOOL) shouldLoadNewerArchive
{
  NSInteger retval = NSRunAlertPanel(_(@"Gorm Build Mismatch"),
				     _(@"The file being loaded was created with a newer build, continue?"), 
				     _(@"OK"), 
				     _(@"Cancel"), 
				     nil,
				     nil);

  return (retval == NSAlertDefaultReturn);
}

- (BOOL) shouldBreakConnectionsForClassNamed: (NSString *)className
{
  NSInteger retval = -1;
  NSString *title = [NSString stringWithFormat: @"%@",_(@"Modifying Class")];
  NSString *msg;
  NSString *msgFormat = _(@"This will break all connections to "
                          @"actions/outlets to instances of class '%@' and it's subclasses.  Continue?");

  msg = [NSString stringWithFormat: msgFormat, className];

  // ask the user if he/she wants to continue...
  retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);

  return (retval == NSAlertDefaultReturn);
}

- (BOOL) shouldRenameConnectionsForClassNamed: (NSString *)className toClassName: (NSString *)newName
{
  NSInteger retval = -1;
  NSString *title = [NSString stringWithFormat: @"%@", _(@"Modifying Class")];
  NSString *msgFormat = _(@"Change class name '%@' to '%@'.  Continue?");
  NSString *msg = [NSString stringWithFormat: 
                              msgFormat,
			    className, newName];

  // ask the user if he/she wants to continue...
  retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);
  return (retval == NSAlertDefaultReturn);  
}

- (BOOL) shouldBreakConnectionsModifyingLabel: (NSString *)name isAction: (BOOL)action prompted: (BOOL)prompted
{
  NSString *title;
  NSString *msg;
  NSInteger retval = -1;
   
  if(prompted == NO)
    {
      title = [NSString stringWithFormat:
			  @"Modifying %@",(action==YES?@"Action":@"Outlet")];
      msg = [NSString stringWithFormat:
			_(@"This will break all connections to '%@'.  Continue?"), name];
      retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);
      // prompted = YES;
    }
  
  return (retval == NSAlertDefaultReturn);
}

- (void) couldNotParseClassAtPath: (NSString *)path
{
  NSString *file = [path lastPathComponent];
  NSString *message = [NSString stringWithFormat: 
				  _(@"Unable to parse class in %@"),file];
  NSRunAlertPanel(_(@"Problem parsing class"), 
		  message,
		  nil, nil, nil);
}

- (void) exceptionWhileParsingClass: (NSException *)localException
{
  NSString *message = [localException reason];
  NSRunAlertPanel(_(@"Problem parsing class"), 
		  message,
		  nil, nil, nil);
}

- (BOOL) shouldBreakConnectionsReparsingClass: (NSString *)className
{
   NSString *title = [NSString stringWithFormat: @"%@",
			       _(@"Reparsing Class")];
   NSString *messageFormat = _(@"This may break connections to "
			       @"actions/outlets to instances of class '%@' "
			       @"and it's subclasses.  Continue?"); 
   NSString *msg = [NSString stringWithFormat: messageFormat,
			     className];		      
   NSInteger retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);

   return (retval == NSAlertDefaultReturn);
}

// Gorm specific methods...
- (BOOL) isInTool
{
  return NO;
}

- (id<IBDocuments>) activeDocument
{
  return [[GormDocumentController sharedDocumentController] currentDocument];
}

- (GormClassManager*) classManager
{
  id document = [self activeDocument];

  if (document != nil) return [document classManager];

  /* kept in the case one want access to the classManager without document */
  else if (_classManager == nil)
    {
      _classManager = [[GormClassManager alloc] init];
    }
  return _classManager;

}

- (id) connectDestination
{
  return _connectDestination;
}

- (id) connectSource
{
  return _connectSource;
}

- (void) displayConnectionBetween: (id)source
			      and: (id)destination
{
  NSWindow	*window;
  NSRect	rect;


  if (source != _connectSource)
    {
      if (_connectSource != nil)
	{
	  window = [(GormDocument *)[self activeDocument] windowAndRect: &rect
				    forObject: _connectSource];
	  if (window != nil)
	    {
	      NSView	*view = [[window contentView] superview];

	      rect.origin.x --;
	      rect.size.width ++;

	      rect.size.height ++;

	      [window disableFlushWindow];
	      [view displayRect: rect];

	      [window enableFlushWindow];
	      [window flushWindow];
	    }
	}
      _connectSource = source;
    }
  if (destination != _connectDestination)
    {
      if (_connectDestination != nil)
	{
	  window = [(GormDocument *)[self activeDocument] windowAndRect: &rect
				    forObject: _connectDestination];
	  if (window != nil)
	    {
	      NSView	*view = [[window contentView] superview];

	      /*
	       * Erase image from old location.
	       */
	      rect.origin.x --;
	      rect.size.width ++;
	      rect.size.height ++;

	      [view lockFocus];
	      [view displayRect: rect];
	      [view unlockFocus];
	      [window flushWindow];
	    }
	}
      _connectDestination = destination;
    }
  if (_connectSource != nil)
    {
      window = [(GormDocument *)[self activeDocument] windowAndRect: &rect forObject: _connectSource];
      if (window != nil)
	{
	  NSView	*view = [[window contentView] superview];
	  NSRect        imageRect = rect;

	  imageRect.origin.x++;
	  //rect.size.width--;
	  //rect.size.height--;
	  [view lockFocus];
	  [[NSColor greenColor] set];
	  NSFrameRectWithWidth(rect, 1);

	  [_sourceImage compositeToPoint: imageRect.origin
			       operation: NSCompositeSourceOver];
	  [view unlockFocus];
	  [window flushWindow];
	}
    }
  if (_connectDestination != nil && _connectDestination == _connectSource)
    {
      window = [(GormDocument *)[self activeDocument] windowAndRect: &rect
				forObject: _connectDestination];
      if (window != nil)
	{
	  NSView	*view = [[window contentView] superview];
	  NSRect        imageRect = rect;

	  imageRect.origin.x += 3;
	  imageRect.origin.y += 2;
	  // rect.size.width -= 5;
	  // rect.size.height -= 5;
	  [view lockFocus];
	  [[NSColor purpleColor] set];
	  NSFrameRectWithWidth(rect, 1);

	  imageRect.origin.x += [_targetImage size].width;
	  [_targetImage compositeToPoint: imageRect.origin
			       operation: NSCompositeSourceOver];
	  [view unlockFocus];
	  [window flushWindow];
	}
    }
  else if (_connectDestination != nil)
    {
      window = [(GormDocument *)[self activeDocument] windowAndRect: &rect
				forObject: _connectDestination];
      if (window != nil)
	{
	  NSView	*view = [[window contentView] superview];
	  NSRect        imageRect = rect;

	  imageRect.origin.x++;
	  // rect.size.width--;
	  // rect.size.height--;
	  [view lockFocus];
	  [[NSColor purpleColor] set];
	  NSFrameRectWithWidth(rect, 1);

	  [_targetImage compositeToPoint: imageRect.origin
			       operation: NSCompositeSourceOver];
	  [view unlockFocus];
	  [window flushWindow];
	}
    }
}

- (IBAction) testInterface: (id)sender
{
  if (_isTesting == NO || [self isInTool])
    {
      // top level objects
      NS_DURING
	{
	  NSUserDefaults	*defaults;
	  NSNotificationCenter	*notifCenter = [NSNotificationCenter defaultCenter];
	  GormDocument		*activeDoc = (GormDocument*)[self activeDocument];
	  NSData		*data;
	  NSArchiver            *archiver;
	  NSEnumerator          *en;
	  NSDictionary          *substituteClasses = [_palettesManager substituteClasses];
	  NSString              *subClassName;
	  id                    obj;
	  id                    savedDelegate = [NSApp delegate];
	  NSMenu                *modelMenu = [activeDoc objectForName: @"NSMenu"];


	  // which windows were open when testing started...
	  _testingWindows = [[NSMutableArray alloc] init];
	  en = [[NSApp windows] objectEnumerator];
	  while((obj = [en nextObject]) != nil)
	    {
	      if([obj isVisible])
		{
		  [_testingWindows addObject: obj];
		  if ([activeDoc window] != obj)
		    {
		      [obj close]; // close the visible windows...
		    }
		}
	    }
	  
	  // set here, so that beginArchiving and endArchiving do not use templates.
	  _isTesting = YES;
	  // [NSApp setApplicationIconImage: _testingImage];

	  // Set up the dock tile...
	  _dockTile = [[NSDockTile alloc] init];
	  [_dockTile setShowsApplicationBadge: YES];
	  [_dockTile setBadgeLabel: @"Test!"];

	  // Encode palette classes with their equivalent substitutes
	  archiver = [[NSArchiver alloc] init];
	  [activeDoc deactivateEditors];
	  if ([self isInTool] == NO)
	    {
	      [archiver encodeClassName: @"GormCustomView"
			  intoClassName: @"GormTestCustomView"];

	      // substitute classes from palettes.
	      en = [substituteClasses keyEnumerator];
	      while((subClassName = [en nextObject]) != nil)
		{
		  NSString *realClassName = [substituteClasses objectForKey: subClassName];
		  
		  if([realClassName isEqualToString: @"NSTableView"] ||
		     [realClassName isEqualToString: @"NSOutlineView"] ||
		     [realClassName isEqualToString: @"NSBrowser"])
		    {
		      continue;
		    }
		  
		  [archiver encodeClassName: subClassName
			      intoClassName: realClassName];
		}
	    }

	  // do not allow custom classes during testing.
	  [GSClassSwapper setIsInInterfaceBuilder: YES];
	  [archiver encodeRootObject: activeDoc];
	  data = RETAIN([archiver archiverData]); // Released below...
	  [activeDoc reactivateEditors];
	  RELEASE(archiver);
	  [GSClassSwapper setIsInInterfaceBuilder: NO];

	  // signal the start of testing...
	  [notifCenter postNotificationName: IBWillBeginTestingInterfaceNotification
		       object: self];

	  if ([_selectionOwner conformsToProtocol: @protocol(IBEditors)] == YES)
	    {
	      [_selectionOwner makeSelectionVisible: NO];
	    }

	  defaults = [NSUserDefaults standardUserDefaults];
	  _menuLocations = [[defaults objectForKey: @"NSMenuLocations"] copy];
	  [defaults removeObjectForKey: @"NSMenuLocations"];
	  _servicesMenu = [NSApp servicesMenu];

	  _testContainer = [NSUnarchiver unarchiveObjectWithData: data];
	  if (_testContainer != nil)
	    {
	      NSMutableDictionary *nameTable = [_testContainer nameTable];
	      NSMenu *aMenu = [nameTable objectForKey: @"NSMenu"];

	      _mainMenu = [NSApp mainMenu]; // save the menu before testing...
	      [[NSApp mainMenu] close];
	      [NSApp setMainMenu: aMenu];
	      // initialize the context.
	      RETAIN(_testContainer);
	      _topObjects = [_testContainer topLevelObjects];

	      [nameTable removeObjectForKey: @"NSServicesMenu"];
	      [nameTable removeObjectForKey: @"NSWindowsMenu"];
	      [_testContainer awakeWithContext: nil];
	      [NSApp setDelegate: savedDelegate]; // makes sure the delegate isn't reset.

	      /*
	       * If the model didn't have a main menu, create one,
	       * otherwise, ensure that 'quit' ends testing mode.
	       */

	      SEL endSelector = NULL;

	      endSelector = @selector(deferredEndTesting:);
	      if ([self isInTool])
		{
		  endSelector = @selector(endTestingNow:);
		}
		    
	      
	      if (aMenu == nil)
		{
		  NSMenu	*testMenu;

		  testMenu = [[NSMenu alloc] initWithTitle: _(@"Test Menu (Gorm)")];
		  [testMenu addItemWithTitle: _(@"Quit Test")
			    action: endSelector
			    keyEquivalent: @"q"];
		  [NSApp setMainMenu: testMenu]; // released, when the menu is reset in endTesting.
		}
	      else
		{
		  NSMenu *testMenu = [NSApp mainMenu];
		  NSString  *newTitle = [[testMenu title] stringByAppendingString: @" (Gorm)"];
		  NSArray *items = findAll(testMenu);
		  NSEnumerator *en = [items objectEnumerator];
		  id item;
		  BOOL found = NO;

		  while((item = [en nextObject]) != nil)
		    {
		      if([item isKindOfClass: [NSMenuItem class]])
			{
			  SEL action = [item action];
			  if(sel_isEqual(action, @selector(terminate:)))
			    {
			      found = YES;
			      [item setTitle: _(@"Quit Test")];
			      [item setTarget: self];
			      [item setAction: endSelector];
			    }
			}
		    }

		  // releast the items...
		  RELEASE(items);

		  // set the menu up so that it's easy to tell we're testing and how to quit.
		  [testMenu setTitle: newTitle];
		  if(found == NO)
		    {
		      [testMenu addItemWithTitle: _(@"Quit Test")
					  action: endSelector
				   keyEquivalent: @"q"];
		    }
		}

	      [modelMenu close];
	      
	      // so we don't get the warning...
	      [NSApp setServicesMenu: nil];
	      [[NSApp mainMenu] display];
	      en = [[NSApp windows] objectEnumerator];
	      while((obj = [en nextObject]) != nil)
		{
		  if([obj isVisible])
		    {
		      [obj makeKeyAndOrderFront: self];
		    }
		}

	      // we're now in testing mode.
	      [notifCenter postNotificationName: IBDidBeginTestingInterfaceNotification
			   object: self];

	      [NSApp unhide: self];
	    }

	  RELEASE(data);
	}
      NS_HANDLER
	{
	  // reset the application after the error.
	  NSLog(@"Problem while testing interface: %@",
		[localException reason]);
	  NSRunAlertPanel(_(@"Problem While Testing Interface"),
			  [NSString stringWithFormat: @"Make sure connections are to appropriate objects.\n"
				    @"Exception: %@",
				    [localException reason]],
			  _(@"OK"), nil, nil);
	  [self endTesting: self];
	}
      NS_ENDHANDLER;
    }
}

- (IBAction) setName: (id)sender
{
  GormSetNameController *panel;
  int		returnPanel;
  NSTextField	*textField;
  NSArray	*selectionArray = [_selectionOwner selection];
  id		obj = [selectionArray objectAtIndex: 0];
  NSString	*name;

  if([(GormDocument *)[self activeDocument] isTopLevelObject: obj])
    {
      panel = [[GormSetNameController alloc] init];
      returnPanel = [panel runAsModal];
      textField = [panel textField];

      if (returnPanel == NSAlertDefaultReturn)
	{
	  name = [[textField stringValue] stringByTrimmingSpaces];
	  if (name != nil && [name isEqual: @""] == NO)
	    {
	      [[self activeDocument] setName: name forObject: obj];
	    }
	}
      RELEASE(panel);
    }
}

- (IBAction) guideline: (id) sender
{
  [[NSNotificationCenter defaultCenter] postNotificationName: GormToggleGuidelineNotification
					object:nil];
  if ( [_guideLineMenuItem tag] == 0 )
    {
      [_guideLineMenuItem setTitle:_(@"Turn GuideLine On")];
      [_guideLineMenuItem setTag:1];
    }
  else if ( [_guideLineMenuItem tag] == 1)
    {
      [_guideLineMenuItem setTitle:_(@"Turn GuideLine Off")];
      [_guideLineMenuItem setTag:0];
    }
}

- (IBAction) orderFrontFontPanel: (id) sender
{
  NSFontPanel *fontPanel = [NSFontPanel sharedFontPanel];
  GormFontViewController *gfvc =
    [GormFontViewController sharedGormFontViewController];
  [fontPanel setAccessoryView: [gfvc view]];
  [[NSFontManager sharedFontManager] orderFrontFontPanel: self];
}

/** Testing methods... */
- (IBAction) endTestingNow: (id)sender
{
  [NSApp terminate: self];
}

- (IBAction) deferredEndTesting: (id) sender
{
  [[NSRunLoop currentRunLoop]
    performSelector: @selector(endTesting:)
	     target: self
	   argument: nil
	      order: 5000
	      modes: [NSArray arrayWithObjects:
				NSDefaultRunLoopMode,
			      NSModalPanelRunLoopMode,
			      NSEventTrackingRunLoopMode, nil]];
}

- (IBAction) endTesting: (id)sender
{
  if (_isTesting)
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
      NSUserDefaults		*defaults;
      NSEnumerator		*e;
      id			val;

      [nc postNotificationName: IBWillEndTestingInterfaceNotification
			object: self];

      /*
       * Make sure windows will go away when the container is destroyed.
       */
      e = [_topObjects objectEnumerator];
      while ((val = [e nextObject]) != nil)
	{
	  if ([val isKindOfClass: [NSWindow class]] == YES)
	    {
	      [val close];
	    }
	}

      /*
       * Make sure any peripheral windows: font panels, etc. which are brought
       * up by the interface being tested are also closed.
       */
      e = [[NSApp windows] objectEnumerator];
      while ((val = [e nextObject]) != nil)
	{
	  if ([_testingWindows containsObject: val] == NO &&
	      [val isKindOfClass: [NSWindow class]] &&
	      [val isVisible])
	    {
	      [val orderOut: self];
	    }
	}

      // prevent saving of this, if the _menuLocations have not previously been set.
      if(_menuLocations != nil)
	{
	  defaults = [NSUserDefaults standardUserDefaults];
	  [defaults setObject: _menuLocations forKey: @"NSMenuLocations"];
	  DESTROY(_menuLocations);
	}

      // Restore windows and menus...
      [NSApp setMainMenu: _mainMenu];
      [NSApp setApplicationIconImage: _gormImage];
      [[NSApp mainMenu] display];

      RELEASE(_dockTile);
      
      e = [_testingWindows objectEnumerator];
      while ((val = [e nextObject]) != nil)
	{
	  [val orderFront: self];
	}

      NS_DURING
	{
	  [NSApp setServicesMenu: _servicesMenu];
	}
      NS_HANDLER
	{
	  NSDebugLog(@"Exception while setting services menu");
	}
      NS_ENDHANDLER

      _isTesting = NO;

      if ([_selectionOwner conformsToProtocol: @protocol(IBEditors)] == YES)
	{
	  [_selectionOwner makeSelectionVisible: YES];
	}
      [nc postNotificationName: IBDidEndTestingInterfaceNotification
			object: self];


      DESTROY(_testingWindows);

      // deallocate
      RELEASE(_testContainer);
    }
}

// end of menu actions...

- (void) handleNotification: (NSNotification*)notification
{
  NSString	*name = [notification name];
  id		obj = [notification object];

  if ([name isEqual: IBSelectionChangedNotification])
    {
      /*
       * If we are connecting - stop it - a change in selection must mean
       * that the connection process has ended.
       */
      if ([self isConnecting] == YES)
	{
	  [self stopConnecting];
	}
      [_selectionOwner makeSelectionVisible: NO];
      _selectionOwner = obj;
      [[self inspectorsManager] updateSelection];
    }
  else if ([name isEqual: IBWillCloseDocumentNotification])
    {
      _selectionOwner = nil;
    }
  else if ([name isEqual: @"GormAddClassNotification"])
    {
      id obj = [notification object];
      [self addClass: obj];
    }
  else if ([name isEqual: @"GormDeleteClassNotification"])
    {
      id obj = [notification object];
      [self deleteClass: obj];
    }
  else if ([name isEqual: @"GormParseClassNotification"])
    {
      NSString *pathToClass = (NSString *)[notification object];
      GormClassManager *cm = [(GormDocument *)[self activeDocument] classManager];
      [cm parseHeader: pathToClass];
    }
}

- (void) awakeFromNib
{
  // set the menu...
  _mainMenu = (NSMenu *)_gormMenu;
}

- (GormInspectorsManager*) inspectorsManager
{
  if (_inspectorsManager == nil)
    {
      _inspectorsManager = (GormInspectorsManager *)[GormInspectorsManager sharedInspectorManager];
    }
  return _inspectorsManager;
}

- (BOOL) isConnecting
{
  return _isConnecting;
}

- (BOOL) isTestingInterface
{
  return _isTesting;
}

- (void) setTestingInterface: (BOOL)testing
{
  _isTesting = testing;
}

- (NSImage*) linkImage
{
  return _linkImage;
}

- (GormPalettesManager*) palettesManager
{
  if (_palettesManager == nil)
    {
      _palettesManager = [[GormPalettesManager alloc] init];
    }
  return _palettesManager;
}

- (GormPluginManager*) pluginManager
{
  if (_pluginManager == nil)
    {
      _pluginManager = [[GormPluginManager alloc] init];
    }
  return _pluginManager;
}

- (id<IBSelectionOwners>) selectionOwner
{
  return (id<IBSelectionOwners>)_selectionOwner;
}

- (id) selectedObject
{
  return [[_selectionOwner selection] lastObject];
}

- (id<IBDocuments>) documentForObject: (id)object
{
  NSEnumerator *en = [[[GormDocumentController sharedDocumentController]
			documents]
		       objectEnumerator];
  id doc = nil;
  id result = nil;

  while((doc = [en nextObject]) != nil)
    {
      if([doc containsObject: object])
	{
	  result = doc;
	  break;
	}
    }

  return result;
}

- (void) startConnecting
{
  if (_isConnecting == YES)
    {
      return;
    }
  if (_connectSource == nil)
    {
      return;
    }
  if (_connectDestination
      && [[self activeDocument] containsObject: _connectDestination] == NO)
    {
      NSLog(@"Oops - _connectDestination not in active document");
      return;
    }
  if ([[self activeDocument] containsObject: _connectSource] == NO)
    {
      NSLog(@"Oops - _connectSource not in active document");
      return;
    }
  _isConnecting = YES;
  [[self inspectorsManager] updateSelection];
}

- (void) stopConnecting
{
  [self displayConnectionBetween: nil and: nil];
  _isConnecting = NO;
  _connectSource = nil;
  _connectDestination = nil;
}

- (NSMenu*) classMenu
{
  return _classMenu;
}

// Methods to support external apps adding and deleting
// classes from the current document...
- (void) addClass: (NSDictionary *) dict
{
  GormDocument *doc = (GormDocument *)[self activeDocument];
  GormClassManager *cm = [doc classManager];
  NSArray *outlets = [dict objectForKey: @"outlets"];
  NSArray *actions = [dict objectForKey: @"actions"];
  NSString *className = [dict objectForKey: @"className"];
  NSString *superClassName = [dict objectForKey: @"superClassName"];

  // If the class is known, delete it before proceeding.
  if([cm isKnownClass: className])
    {
      [cm removeClassNamed: className];
    }

  // Add the class to the class manager.
  [cm addClassNamed: className
      withSuperClassNamed: superClassName
      withActions: actions
      withOutlets: outlets];
}

- (void) deleteClass: (NSString *) className
{
  GormDocument *doc = (GormDocument *)[self activeDocument];
  GormClassManager *cm = [doc classManager];

  [cm removeClassNamed: className];
}

- (void) exceptionWhileLoadingModel: (NSString *)errorMessage
{
  NSRunAlertPanel(_(@"Exception"), 
		  errorMessage,
		  nil, nil, nil);  
}

@end
