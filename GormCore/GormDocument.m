/* GormDocument.m
 *
 * This class contains Gorm specific implementation of the IBDocuments
 * protocol plus additional methods which are useful for managing the
 * contents of the document.
 *
 * Copyright (C) 1999,2002,2003,2004,2005,2020,
 *               2021 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2002,2003,2004,2005,2020,2021
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import <InterfaceBuilder/InterfaceBuilder.h>

#import <GNUstepGUI/GSGormLoading.h>

#import "GormPrivate.h"
#import "GormClassManager.h"
#import "GormCustomView.h"
#import "GormOutlineView.h"
#import "GormFunctions.h"
#import "GormFilePrefsManager.h"
#import "GormViewWindow.h"
#import "NSView+GormExtensions.h"
#import "GormSound.h"
#import "GormImage.h"
#import "GormResourceManager.h"
#import "GormClassEditor.h"
#import "GormSoundEditor.h"
#import "GormImageEditor.h"
#import "GormObjectEditor.h"
#import "GormWrapperBuilder.h"
#import "GormWrapperLoader.h"
#import "GormDocumentWindow.h"
#import "GormDocumentController.h"
#import "GormXLIFFDocument.h"
#import "GormObjectViewController.h"

@interface NSObject (GormNSCoding)
@end

@implementation NSObject (GormNSCoding)

- (instancetype) initWithCoder: (NSCoder *)coder
{
  return [self init];
}

- (void) encodeWithCoder: (NSCoder *)coder
{
}

@end

@interface GormDisplayCell : NSButtonCell
@end

@implementation	GormDisplayCell
- (void) setShowsFirstResponder: (BOOL)flag
{
  [super setShowsFirstResponder: NO];	// Never show ugly frame round button
}
@end

@interface NSDocument (GormPrivate)
- (NSWindow *) _docWindow;
@end

@implementation NSDocument (GormPrivate)
- (NSWindow *) _docWindow
{
  static Ivar iv;
  if (!iv)
    {
      iv = class_getInstanceVariable([NSDocument class], "_window");
      NSAssert(iv, @"Unable to find _window ivar in NSDocument class");
    }
  return object_getIvar(self, iv);
}
@end

@implementation	GormFirstResponder

- (NSImage*) imageForViewer
{
  static NSImage	*image = nil;

  if (image == nil)
    {
      NSBundle	*bundle = [NSBundle bundleForClass: [self class]];
      NSString	*path = [bundle pathForImageResource: @"GormFirstResponder"];

      image = [[NSImage alloc] initWithContentsOfFile: path];
    }
  return image;
}

- (NSString*) inspectorClassName
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

- (NSString*) classInspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (NSString*) className
{
  return @"FirstResponder";
}
@end

//
// Implementation of trivial classes.
//
@implementation	GormObjectToEditor
@end

@implementation	GormEditorToParent
@end


@implementation GormDocument

static NSImage	*objectsImage = nil;
static NSImage	*imagesImage = nil;
static NSImage	*soundsImage = nil;
static NSImage	*classesImage = nil;
static NSImage  *fileImage = nil;

/**
 * Initialize the class.
 */ 
+ (void) initialize
{
  if (self == [GormDocument class])
    {
      NSBundle	*bundle;
      NSString	*path;

      bundle = [NSBundle bundleForClass: [self class]];
      path = [bundle pathForImageResource: @"GormObject"];
      if (path != nil)
	{
	  objectsImage = [[NSImage alloc] initWithContentsOfFile: path];
	}
      path = [bundle pathForImageResource: @"GormImage"];
      if (path != nil)
	{
	  imagesImage = [[NSImage alloc] initWithContentsOfFile: path];
	}
      path = [bundle pathForImageResource: @"GormSound"];
      if (path != nil)
	{
	  soundsImage = [[NSImage alloc] initWithContentsOfFile: path];
	}
      path = [bundle pathForImageResource: @"GormClass"];
      if (path != nil)
	{
	  classesImage = [[NSImage alloc] initWithContentsOfFile: path];
	}
      path = [bundle pathForImageResource: @"GormFile"];
      if (path != nil)
	{
	  fileImage = [[NSImage alloc] initWithContentsOfFile: path];
	}

      // register the resource managers...
      [IBResourceManager registerResourceManagerClass: 
			   [IBResourceManager class]];
      [IBResourceManager registerResourceManagerClass: 
			   [GormResourceManager class]];
      [self setVersion: GNUSTEP_NIB_VERSION];
    }
}

/**
 * Initialize the new GormDocument object.
 */
- (id) init 
{
  self = [super init];
  if (self != nil)
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      id delegate = [NSApp delegate];
      
      // initialize...
      openEditors = [[NSMutableArray alloc] init];
      classManager = [(GormClassManager *)[GormClassManager alloc] initWithDocument: self]; 
      
      /*
       * NB. We must retain the map values (object names) as the nameTable
       * may not hold identical name objects, but merely equal strings.
       */
      objToName = NSCreateMapTableWithZone(NSObjectMapKeyCallBacks,
					   NSObjectMapValueCallBacks, 128, [self zone]);
      
      // for saving the editors when the gorm file is persisted.
      savedEditors = [[NSMutableArray alloc] init];	  
      
      // observe certain notifications...
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: IBClassNameChangedNotification
	  object: classManager];
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: IBInspectorDidModifyObjectNotification
	  object: classManager];
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: GormDidModifyClassNotification
	  object: classManager];
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: GormDidAddClassNotification
	  object: classManager];
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: IBWillBeginTestingInterfaceNotification
	  object: nil];
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: IBWillEndTestingInterfaceNotification
	  object: nil];
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: IBResourceManagerRegistryDidChangeNotification
	  object: nil];
      
      // load resource managers
      [self createResourceManagers];
      
      /*
       * Set up container data....
       */      
      nameTable = [[NSMutableDictionary alloc] init];
      connections = [[NSMutableArray alloc] init];
      topLevelObjects = [[NSMutableSet alloc] init];
      visibleWindows = [[NSMutableSet alloc] init];
      deferredWindows = [[NSMutableSet alloc] init];

      filesOwner = [[GormFilesOwner alloc] init];
      [self setName: @"NSOwner" forObject: filesOwner];
      firstResponder = [[GormFirstResponder alloc] init];
      [self setName: @"NSFirst" forObject: firstResponder];
      
      // preload headers...
      if ([defaults boolForKey: @"PreloadHeaders"])
	{
	  NSArray *headerList = [defaults arrayForKey: @"HeaderList"];
	  NSEnumerator *en = [headerList objectEnumerator];
	  id obj = nil;
	  
	  while ((obj = [en nextObject]) != nil)
	    {
	      NSString *header = (NSString *)obj;
	      
	      NSDebugLog(@"Preloading %@", header);
	      NS_DURING
		{
		  if(![classManager parseHeader: header])
		    {
		      [delegate couldNotParseClassAtPath: header];
		    }
		}
	      NS_HANDLER
		{
		  [delegate exceptionWhileParsingClass: localException];
		}
	      NS_ENDHANDLER;
	    }
	}
      
      // are we upgrading an archive?
      isOlderArchive = NO;
      
      // document is open...
      isDocumentOpen = YES;
    }
  return self;
}

/**
 * Perform any additional setup which needs to happen.
 */
- (void) awakeFromNib
{
  NSRect                scrollRect = {{0, 0}, {340, 188}};
  NSRect                mainRect = {{20, 0}, {320, 188}};
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSMenu                *mainMenu = nil;
  NSEnumerator          *en = nil; 
  id                    o = nil;
  NSOutlineView         *outlineView = [[NSOutlineView alloc] init];
  
  // get the window and cache it...
  window = (GormDocumentWindow *)[self _docWindow];
  [IBResourceManager registerForAllPboardTypes:window
	  			inDocument:self];
  [window setDocument: self];
  
  // set up the toolbar...
  toolbar = [(NSToolbar *)[NSToolbar alloc] initWithIdentifier: @"GormToolbar"];
  [toolbar setAllowsUserCustomization: NO];
  // [toolbar setSizeMode: NSToolbarSizeModeSmall];
  [toolbar setDelegate: self];
  [window setToolbar: toolbar];
  RELEASE(toolbar);
  [toolbar setSelectedItemIdentifier: @"ObjectsItem"]; // set initial selection.

  // set up notifications for window.
  [nc addObserver: self
      selector: @selector(handleNotification:)
      name: NSWindowWillCloseNotification
      object: window];
  [nc addObserver: self
      selector: @selector(handleNotification:)
      name: NSWindowDidBecomeKeyNotification
      object: window];
  [nc addObserver: self
      selector: @selector(handleNotification:)
      name: NSWindowWillMiniaturizeNotification
      object: window];
  [nc addObserver: self
      selector: @selector(handleNotification:)
      name: NSWindowDidDeminiaturizeNotification
      object: window];

  // objects...
  NSScrollView *outlineScrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
  NSTableColumn *tbo  = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"objects"]); 
  NSTableColumn *tbc  = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"destination"]); 
  NSTableColumn *tbs  = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"source"]); 
  NSTableColumn *tbcl = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"class"]);
  NSTableColumn *tbv  = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier: @"version"]);

  // Titles
  [tbo setTitle: @"Objects"];
  [tbc setTitle: @"Destination"];
  [tbs setTitle: @"Source"];
  [tbcl setTitle: @"Class"];
  [tbv setTitle: @"Version"];

  // Set up the outline view...
  [outlineView setDrawsGrid: NO];
  [outlineView setOutlineTableColumn: tbo];
  [outlineView addTableColumn: tbo];
  [outlineView addTableColumn: tbcl];
  [outlineView addTableColumn: tbv];  
  [outlineView addTableColumn: tbc];
  [outlineView addTableColumn: tbs];
  [outlineScrollView setHasVerticalScroller: YES];
  [outlineScrollView setHasHorizontalScroller: YES];
  [outlineScrollView setAutoresizingMask:
		       NSViewHeightSizable|NSViewWidthSizable];
  [outlineScrollView setBorderType: NSBezelBorder];

  // Configure the scrollview...
  mainRect.origin = NSMakePoint(0,0);
  scrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
  [scrollView setHasVerticalScroller: YES];
  [scrollView setHasHorizontalScroller: YES];
  [scrollView setAutoresizingMask:
		NSViewHeightSizable|NSViewWidthSizable];
  [scrollView setBorderType: NSBezelBorder];

  objectViewController = [[GormObjectViewController alloc] initWithNibName: @"GormObjectOutlineView"
								    bundle: [NSBundle bundleForClass: [self class]]];
  [objectViewController setDocument: self];
  NSDebugLog(@"objectViewController = %@, view = %@", objectViewController, [objectViewController view]);
  
  objectsView = [[GormObjectEditor alloc] initWithObject: nil
					  inDocument: self];
  [objectsView setFrame: mainRect];
  [objectsView setAutoresizingMask:
		 NSViewHeightSizable|NSViewWidthSizable];
  [scrollView setDocumentView: objectsView];
  RELEASE(objectsView);
  
  [objectViewController setIconView: scrollView];
  RELEASE(scrollView);

  [outlineScrollView setDocumentView: outlineView];
  [objectViewController setOutlineView: outlineScrollView];
  [outlineView setDataSource: self];
  [objectViewController reloadOutlineView];
  
  RELEASE(outlineView);
  
  [[objectViewController view] setAutoresizingMask:
				 NSViewHeightSizable|NSViewWidthSizable];
  [objectViewController resetDisplayView: scrollView];

  // images...
  mainRect.origin = NSMakePoint(0,0);
  imagesScrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
  [imagesScrollView setHasVerticalScroller: YES];
  [imagesScrollView setHasHorizontalScroller: YES];
  [imagesScrollView setAutoresizingMask:
		      NSViewHeightSizable|NSViewWidthSizable];
  [imagesScrollView setBorderType: NSBezelBorder];
  
  imagesView = [[GormImageEditor alloc] initWithObject: nil
					inDocument: self];
  [imagesView setFrame: mainRect];
  [imagesView setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
  [imagesScrollView setDocumentView: imagesView];
  RELEASE(imagesView);
  
  // sounds...
  mainRect.origin = NSMakePoint(0,0);
  soundsScrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
  [soundsScrollView setHasVerticalScroller: YES];
  [soundsScrollView setHasHorizontalScroller: YES];
  [soundsScrollView setAutoresizingMask:
		      NSViewHeightSizable|NSViewWidthSizable];
  [soundsScrollView setBorderType: NSBezelBorder];
  
  soundsView = [[GormSoundEditor alloc] initWithObject: nil
					inDocument: self];
  [soundsView setFrame: mainRect];
  [soundsView setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
  [soundsScrollView setDocumentView: soundsView];
  RELEASE(soundsView);
  
  /* classes view */
  mainRect.origin = NSMakePoint(0,0);
  classesView = [(GormClassEditor *)[GormClassEditor alloc] initWithDocument: self];
  // [classesView setFrame: mainRect];
  
  /*
   * Set the objects view as the initial view the user's see on startup.
   */
  [selectionBox setContentView: [objectViewController view]]; //scrollView];

  // add to the objects view...
  [objectsView addObject: filesOwner];
  [objectsView addObject: firstResponder];
  
  /*
   * Set image for this miniwindow.
   */
  [window setMiniwindowImage: [(id)filesOwner imageForViewer]];	  
  hidden = [[NSMutableArray alloc] init];

  // reposition the loaded menu appropriately...
  mainMenu = [nameTable objectForKey: @"NSMenu"];
  if(mainMenu != nil)
    {
      NSRect frame = [window frame];
      NSPoint origin = frame.origin;
      NSRect screen = [[NSScreen mainScreen] frame];
      
      // account for the height of the menu we're loading.
      origin.y = (screen.size.height - 100);
      
      // place the main menu appropriately...
      [[mainMenu window] setFrameTopLeftPoint: origin];
    }
  
  // load the file preferences....
  if(infoData != nil)
    {
      if([filePrefsManager loadFromData: infoData])
	{
	  NSInteger version = [filePrefsManager version];
	  NSInteger currentVersion = [GormFilePrefsManager currentVersion];
	  id delegate = [NSApp delegate];
	  
	  if(version > currentVersion)
	    {
	      BOOL result = [delegate shouldLoadNewerArchive];
	      if (result == NO)
		{
		  [self close];
		}	      
	    }
	  DESTROY(infoData);
	}
      else
	{
	  NSLog(@"Loading gorm without data.info file.  Default settings will be assumed.");
	}
    }

  // load the images and sounds...
  en = [images objectEnumerator];
  while((o = [en nextObject]) != nil)
    {
      [imagesView addObject: o];
    }
  DESTROY(images);

  en = [images objectEnumerator];
  while((o = [en nextObject]) != nil)
    {
      [soundsView addObject: o];
    }
  DESTROY(sounds);

  //
  // Retain the file prefs view...
  //
  RETAIN(filePrefsView);

  //
  // All of the entries in the items array are "top level items" 
  // which should be visible in the object's view. 
  //
  en = [topLevelObjects objectEnumerator];
  while((o = [en nextObject]) != nil)
    {
      [objectsView addObject: o];
    }

  // set the file type in the prefs manager...
  [filePrefsManager setFileTypeName: [self fileType]];  
}

/**
 * Add aConnector to the set of connectors in this document.
 */
- (void) addConnector: (id<IBConnectors>)aConnector
{
  if ([connections indexOfObjectIdenticalTo: aConnector] == NSNotFound)
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

      [nc postNotificationName: IBWillAddConnectorNotification
			object: aConnector];

      [connections addObject: aConnector];
      [self touch]; // make sure the doc is marked as modified...

      [nc postNotificationName: IBDidAddConnectorNotification
			object: aConnector];
    }
}

/**
 * Returns all connectors.
 */
- (NSArray*) allConnectors
{
  return [NSArray arrayWithArray: connections];
}

/**
 * Creates the proxy font manager.
 */
- (void) _instantiateFontManager
{
  if (fontManager != nil)
    {
      return;
    }
  else
    {
      GSNibItem *item = nil;
      NSMenu *fontMenu = nil;
      
      item = [[GormObjectProxy alloc] initWithClassName: @"NSFontManager"];
      
      [self setName: @"NSFont" forObject: item];
      [self attachObject: item toParent: nil];
      RELEASE(item);
      
      // set the holder in the document.
      fontManager = (GormObjectProxy *)item;
      [self changeToViewWithTag: 0];
      
      // Add the connection to the menu from the font manager, if the NSFontMenu exists...
      fontMenu = [self fontMenu];
      if (fontMenu != nil)
	{
	  NSNibOutletConnector *con = [[NSNibOutletConnector alloc] init];
	  [con setSource: item];
	  [con setDestination: fontMenu];
	  [con setLabel: @"menu"];
	  [self addConnector: con];
	}
    }
}

/**
 * Attach anObject to the document with aParent specifying the name.  To allow
 * Gorm to generate the name pass in nil for aName parameter
 */
- (void) attachObject: (id)anObject toParent: (id)aParent withName: (NSString *)aName
{
  NSArray *old;
  BOOL newObject = NO;

  // Modify the document whenever something is added...
  [self touch];

  /*
   * Create a connector that links this object to its parent.
   * A nil parent is the root of the hierarchy so we use a dummy object for it.
   */
  if (aParent == nil)
    {
      aParent = filesOwner;
    }

  old = [self connectorsForSource: anObject ofClass: [NSNibConnector class]];
  if ([old count] > 0)
    {
      [[old objectAtIndex: 0] setDestination: aParent];
    }
  else
    {
      NSNibConnector	*con = [[NSNibConnector alloc] init];

      [con setSource: anObject];
      [con setDestination: aParent];
      [self addConnector: (id<IBConnectors>)con];
      RELEASE(con);
    }

  /*
   * Make sure that there is a name for this object.
   */
  if ([self nameForObject: anObject] == nil)
    {
      newObject = YES;
      [self setName: aName forObject: anObject];
    }

  /*
   * Add top-level objects to objectsView and open their editors.
   */
  if ([anObject isKindOfClass: [NSWindow class]] ||
      [anObject isKindOfClass: [GSNibItem class]])
    {
      [objectsView addObject: anObject];
      [topLevelObjects addObject: anObject];
      if ([anObject isKindOfClass: [NSWindow class]])
	{
	  NSWindow *win = (NSWindow *)anObject;
	  NSView *contentView = [win contentView];
	  NSArray *subviews = [contentView subviews];

	  // Turn off the release when closed flag, add the content view.
	  [anObject setReleasedWhenClosed: NO];
	  [self attachObject: contentView
		    toParent: anObject];

	  // Add all subviews from the window, if any.
          [self attachObjects: subviews toParent: win];
	}
      [[self openEditorForObject: anObject] activate];
    }
  /*
   * Determine what should be a top level object.
   */
  else if((aParent == filesOwner || aParent == nil) &&
	  [anObject isKindOfClass: [NSMenu class]] == NO)
    {
      if([anObject isKindOfClass: [NSObject class]] &&
	 [anObject isKindOfClass: [NSView class]] == NO)
	{
	  [objectsView addObject: anObject];
	  [topLevelObjects addObject: anObject];
	}
      else if([anObject isKindOfClass: [NSView class]] && [anObject superview] == nil)
	{
	  [objectsView addObject: anObject];
	  [topLevelObjects addObject: anObject];
	}
    }
  /*
   * Check if it's a font manager.
   */
  else if([anObject isKindOfClass: [NSFontManager class]])
    {
      // If someone tries to attach a font manager, we must attach
      // the proxy instead.
      [self _instantiateFontManager];
    }

  /*
   * Add the menu items from the popup.
   */
  else if([anObject isKindOfClass: [NSPopUpButton class]])
    {
      NSPopUpButton *button = (NSPopUpButton *)anObject;

      // add all of the items in the popup..
      [self attachObjects: [button itemArray] toParent: button];
    }
  /*
   * Add the menu item.
   */
  else if([anObject isKindOfClass: [NSMenuItem class]])
    {
      NSMenu *menu = [(NSMenuItem *)anObject submenu]; 
      if(menu != nil)
	{
	  [self attachObject: menu toParent: anObject];
	}
    }
  /*
   * Add the current menu and any submenus.
   */
  else if ([anObject isKindOfClass: [NSMenu class]])
    {
      BOOL isMainMenu = NO;
      NSMenu *menu = (NSMenu *)anObject;

      // If there is no main menu and a menu gets added, it
      // will become the main menu.
      if([self objectForName: @"NSMenu"] == nil)
	{
          [self setName: @"NSMenu" forObject: menu];
	  [objectsView addObject: menu];
	  [topLevelObjects addObject: menu];
	  isMainMenu = YES;
	}
      else
	{
	  if([[menu title] isEqual: @"Services"] && [self servicesMenu] == nil)
	    {
	      [self setServicesMenu: menu];
	    }
	  else if([[menu title] isEqual: @"Windows"] && [self windowsMenu] == nil)
	    {
	      [self setWindowsMenu: menu];
	    }
	  else if([[menu title] isEqual: @"Open Recent"] && [self recentDocumentsMenu] == nil)
	    {
	      [self setRecentDocumentsMenu: menu];
	    }
	  if([[menu title] isEqual: @"Font"] && [self fontMenu] == nil)
	    {
	      [self setFontMenu: menu];
	    }
	  // if it doesn't have a supermenu and it's owned by the file's owner, then it's a top level menu....
	  else if([menu supermenu] == nil && aParent == filesOwner)
	    {
	      [objectsView addObject: menu];
	      [topLevelObjects addObject: menu];
	      isMainMenu = NO;
	    }
	}

      // add all of the items in the menu.
      [self attachObjects: [menu itemArray] toParent: menu];
      
      // activate the editor...
      [[self openEditorForObject: menu] activate];

      // If it's the main menu... locate it appropriately...
      if(isMainMenu && [self isActive])
	{
	  NSRect frame = [[self window] frame];
	  NSPoint origin = frame.origin;
	  NSRect screen = [[NSScreen mainScreen] frame];

	  origin.y = (screen.size.height - 100);

	  // Place the main menu appropriately...
	  [[menu window] setFrameTopLeftPoint: origin];
	}
    }
  /*
   * If this a scrollview, it is interesting to add its contentview.
   */
  else if (([anObject isKindOfClass: [NSScrollView class]])
	   && ([(NSScrollView *)anObject documentView] != nil))
    {
      if ([[anObject documentView] isKindOfClass: 
				    [NSTableView class]])
	{
	  id tv = [anObject documentView];

	  [self attachObject: tv toParent: anObject];
	  
          [self attachObjects: [tv tableColumns] toParent: tv];
	}
      else // if ([[anObject documentView] isKindOfClass: [NSTextView class]])
	{
	  [self attachObject: [anObject documentView] toParent: anObject];
	}
    }
  /*
   * If it's a tab view, then we want the tab items.
   */
  else if ([anObject isKindOfClass: [NSTabView class]])
    {
      [self attachObjects: [anObject tabViewItems] toParent: anObject];
    }
  /*
   * If it's a tab view item, then we attach the view.
   */
  else if ([anObject isKindOfClass: [NSTabViewItem class]])
    {
      NSTabViewItem *ti = (NSTabViewItem *)anObject; 
      id v = [ti view];
      [self attachObject: v toParent: ti];
    }
  /*
   * If it's a matrix, add the elements of the matrix.
   */
  else if ([anObject isKindOfClass: [NSMatrix class]])
    {
      // add all of the cells....
      if ([[anObject cells] count] > 0) // && [anObject prototype] != nil)
        {
          [self attachObjects: [anObject cells] toParent: anObject];
        }

      if ([anObject prototype] != nil)
        {
          [self attachObject: [anObject prototype] toParent: anObject];
        }
    }
  /*
   * If it's a simple NSView, add it and all of it's subviews.
   */
  else if ([anObject isKindOfClass: [NSView class]])
    {
      NSView *view = (NSView *)anObject;

      // Add all subviews from the window, if any.
      [self attachObjects: [view subviews] toParent: view];
    }
  /*
   * Add columns to document hierarchy...
   */
  else if ([anObject isKindOfClass: [NSTableView class]]) // this should include outline view
    {
      NSTableView *tblView = (NSTableView *)anObject;
      NSArray *cols = [tblView tableColumns];

      [self attachObjects: cols toParent: tblView];
    }
  else if ([anObject isKindOfClass: [NSSplitView class]])
    {
      NSSplitView *sp = (NSSplitView *)anObject;
      [self attachObjects: [sp subviews] toParent: sp];
    }
  
  /* 
   * Detect and add any connection the object might have.
   * This is done so that any palette items which have predefined connections will be
   * shown in the connections list.
   */
  if([anObject respondsToSelector: @selector(action)]  &&
     [anObject respondsToSelector: @selector(target)]  &&
     newObject)
    {
      SEL sel = [anObject action];

      if(sel != NULL)
	{
	  NSString *label = NSStringFromSelector(sel);
	  id source = anObject;
	  NSNibControlConnector *con = [[NSNibControlConnector alloc] init];
	  id destination = [(NSControl *)anObject target];
	  NSArray *sourceConnections = [self connectorsForSource: source];

	  // if it's a menu item we want to connect it to it's parent...
	  if([anObject isKindOfClass: [NSMenuItem class]] && 
	     [label isEqual: @"submenuAction:"])
	    {
	      destination = aParent;
	    }
	  
	  // if the connection needs to be made with the font manager, replace
	  // it with our proxy object and proceed with creating the connection.
	  if((destination == nil || destination == [NSFontManager sharedFontManager]) && 
	     [classManager isAction: label ofClass: @"NSFontManager"])
	    {
	      if(!fontManager)
		{
		  // initialize font manager...
		  [self _instantiateFontManager];
		}
	      
	      // set the destination...
	      destination = fontManager;
	    }

	  // if the destination is still nil, back off to the first responder.
	  if(destination == nil)
	    {
	      destination = firstResponder;
	    }

	  // build the connection
	  [con setSource: source];
	  [con setDestination: destination];
	  [con setLabel: label];
	  
	  // don't duplicate the connection if it already exists.
	  // if([sourceConnections indexOfObjectIdenticalTo: con] == NSNotFound)
	  if([sourceConnections containsObject: con] == NO)
	    {
	      // add it to our connections set.
	      [self addConnector: (id<IBConnectors>)con];
	    }

	  // destroy the connection in the object to
	  // prevent any conflict.   The connections are restored when the 
	  // .gorm is loaded, so there's no need for it anymore.
	  [anObject setTarget: nil];
	  [anObject setAction: NULL];

	  // release the connection.
	  RELEASE(con);
	}
    }

  /*
   * Attach the cell of an item to the document so that it has a name and
   * can be addressed.  Do this last so that all other considerations are taken care
   * of prior to adding the cell to the document.
   */
  if ([anObject respondsToSelector: @selector(cell)])
    {
      [self openEditorForObject: [anObject cell]
	       withParentObject: anObject];
      [self attachObject: [anObject cell] toParent: anObject];
    }
}

/**
 * Attach an object to parent object in document letting Gorm generate the name
 */ 
- (void) attachObject: (id)object toParent: (id)parent
{
  [self attachObject: object
            toParent: parent
            withName: nil];
}

/**
 * Attach an object to parent object in document letting Gorm generate the name
 * this method will add a top level object.
 */ 
- (void) attachObject: (id)object
{
  [self attachObject: object
            toParent: nil
            withName: nil];
}

/**
 * Attach all objects in anArray to the document with aParent.
 */
- (void) attachObjects: (NSArray*)anArray toParent: (id)aParent
{
  NSEnumerator	*enumerator = [anArray objectEnumerator];
  NSObject	*obj;

  while ((obj = [enumerator nextObject]) != nil)
    {
      [self attachObject: obj toParent: aParent];
    }
}

- (void) changeToViewWithTag: (int)tag
{
  switch (tag)
    {
    case 0: // objects
      {
	[selectionBox setContentView: [objectViewController view]]; //scrollView];
	[toolbar setSelectedItemIdentifier: @"ObjectsItem"];
	if (![[NSApp delegate] isConnecting])
	  [self setSelectionFromEditor: objectsView];
      }
      break;
    case 1: // images
      {
	[selectionBox setContentView: imagesScrollView];
	[toolbar setSelectedItemIdentifier: @"ImagesItem"];
	[self setSelectionFromEditor: imagesView];
      }
      break;
    case 2: // sounds
      {
	[selectionBox setContentView: soundsScrollView];
	[toolbar setSelectedItemIdentifier: @"SoundsItem"];
	[self setSelectionFromEditor: soundsView];
      }
      break;
    case 3: // classes
      {
	NSArray *selection =  [[(id<IB>)[NSApp delegate] selectionOwner] selection];
	[selectionBox setContentView: classesView];
	
	// if something is selected, in the object view.
	// show the equivalent class in the classes view.
	if ([selection count] > 0)
	  {
	    id obj = [selection objectAtIndex: 0];
	    [classesView selectClassWithObject: obj];
	  }
	[toolbar setSelectedItemIdentifier: @"ClassesItem"];
	[self setSelectionFromEditor: classesView];
      }
      break;
    case 4: // file prefs
      {
	[toolbar setSelectedItemIdentifier: @"FileItem"];
	[selectionBox setContentView: filePrefsView];
      }
      break;
    }
}

- (NSView *) viewWithTag:(int)tag
{
  switch (tag)
    {
      case 0: // objects
	return objectsView;
      case 1: // images
	return imagesView;
      case 2: // sounds
	return soundsView;
      case 3: // classes
	return classesView;
      case 4: // file prefs
        return filePrefsView;
      default: 
        return nil;
    }
}

- (void) changeToTopLevelEditorAcceptingTypes: (NSArray *)types
				  andFileType: (NSString *)fileType
{
  // NSToolbar *toolbar = [_window toolbar];
  if([objectsView acceptsTypeFromArray: types] &&
     fileType == nil)
    {
      [self changeToViewWithTag: 0];
    }
  else if([imagesView acceptsTypeFromArray: types] &&
	  [[imagesView fileTypes] containsObject: fileType])
    {
      [self changeToViewWithTag: 1];
    }
  else if([soundsView acceptsTypeFromArray: types] &&
	  [[soundsView fileTypes] containsObject: fileType])
    {
      [self changeToViewWithTag: 2];
    }
  else if([classesView acceptsTypeFromArray: types] &&
	  [[classesView fileTypes] containsObject: fileType])
    {
      [self changeToViewWithTag: 3];
    }
}

/**
 * Change the view in the document window.
 */
- (void) changeView: (id)sender
{
  [self changeToViewWithTag: [sender tag]];
}

/**
 * The class manager.
 */ 
- (GormClassManager*) classManager
{
  return classManager;
}

/**
 * Returns all connectors to destination.
 */
- (NSArray*) connectorsForDestination: (id)destination
{
  return [self connectorsForDestination: destination ofClass: 0];
}

/**
 * Returns all connectors to destination of class aConnectorClass.
 */
- (NSArray*) connectorsForDestination: (id)destination
                              ofClass: (Class)aConnectorClass
{
  NSMutableArray	*array = [NSMutableArray arrayWithCapacity: 16];
  NSEnumerator		*enumerator = [connections objectEnumerator];
  id<IBConnectors>	c;

  while ((c = [enumerator nextObject]) != nil)
    {
      if ([c destination] == destination
	&& (aConnectorClass == 0 || aConnectorClass == [c class]))
	{
	  [array addObject: c];
	}
    }
  return array;
}

/**
 * Returns all connectors to source.
 */
- (NSArray*) connectorsForSource: (id)source
{
  return [self connectorsForSource: source ofClass: 0];
}

/**
 * Returns all connectors to a given source where the 
 * connectors are of aConnectorClass.
 */
- (NSArray*) connectorsForSource: (id)source
			 ofClass: (Class)aConnectorClass
{
  NSMutableArray	*array = [NSMutableArray arrayWithCapacity: 16];
  NSEnumerator		*enumerator = [connections objectEnumerator];
  id<IBConnectors>	c;

  while ((c = [enumerator nextObject]) != nil)
    {
      if ([c source] == source
	&& (aConnectorClass == 0 || aConnectorClass == [c class]))
	{
	  [array addObject: c];
	}
    }
  return array;
}

/**
 * Returns YES, if the document contains anObject.
 */
- (BOOL) containsObject: (id)anObject
{
  if ([self nameForObject: anObject] == nil)
    {
      return NO;
    }
  return YES;
}

/**
 * Returns YES, if the document contains an object with aName and
 * parent.
 */
- (BOOL) containsObjectWithName: (NSString*)aName forParent: (id)parent
{
  id	obj = [nameTable objectForKey: aName];

  if (obj == nil)
    {
      return NO;
    }
  return YES; 
}

/**
 * Copy anObject to aPasteboard using aType.  Returns YES, if
 * successful.
 */
- (BOOL) copyObject: (id)anObject
               type: (NSString*)aType
       toPasteboard: (NSPasteboard*)aPasteboard
{
  return [self copyObjects: [NSArray arrayWithObject: anObject]
		      type: aType
	      toPasteboard: aPasteboard];
}

/**
 * Copy all objects in anArray to aPasteboard using aType.  Returns YES,
 * if successful.
 */
- (BOOL) copyObjects: (NSArray*)anArray
                type: (NSString*)aType
        toPasteboard: (NSPasteboard*)aPasteboard
{
  NSEnumerator	*enumerator;
  NSMutableSet	*editorSet;
  id<IBEditors>	obj;
  NSMutableData	*data;
  NSArchiver    *archiver;

  /*
   * Remove all editors from the selected objects before archiving
   * and restore them afterwards.
   */
  editorSet = [[NSMutableSet alloc] init];
  enumerator = [anArray objectEnumerator];
  while ((obj = [enumerator nextObject]) != nil)
    {
      id editor = [self editorForObject: obj create: NO];
      if (editor != nil)
	{
	  [editorSet addObject: editor];
	  [editor deactivate];
	}

      // Windows are a special case.  Check the content view and see if it's an active editor.
      /**
      if([obj isKindOfClass: [NSWindow class]])
	{
	  id contentView = [obj contentView];
	  if([contentView conformsToProtocol: @protocol(IBEditors)])
	    {
	      [contentView deactivate];
	      [editorSet addObject: contentView];
	    }
	}
      */
    }

  // encode the data
  data = [NSMutableData dataWithCapacity: 0];
  archiver = [[NSArchiver alloc] initForWritingWithMutableData: data];
  [archiver encodeClassName: @"GormCustomView" 
	    intoClassName: @"GSCustomView"];
  [archiver encodeRootObject: anArray];

  // reactivate
  enumerator = [editorSet objectEnumerator];
  while ((obj = [enumerator nextObject]) != nil)
    {
      [obj activate];
    }
  RELEASE(editorSet);

  [aPasteboard declareTypes: [NSArray arrayWithObject: aType]
		      owner: self];
  return [aPasteboard setData: data forType: aType];
}

/**
 * The given pasteboard chaned ownership.
 */
- (void) pasteboardChangedOwner: (NSPasteboard *)sender
{
  NSDebugLog(@"Owner changed for %@", sender);
}

/**
 * Dealloc all things owned by a GormDocument object.
 */
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  ASSIGN(lastEditor, (id)nil);
  // [filePrefsWindow close];

  // Get rid of the selection box.
  // [selectionBox removeFromSuperviewWithoutNeedingDisplay];
  
  RELEASE(classManager);
  RELEASE(filePrefsManager);
  RELEASE(filePrefsView);
  RELEASE(hidden);

  if (objToName != 0)
    {
      NSFreeMapTable(objToName);
    }

  RELEASE(scrollView);
  RELEASE(classesView);
  RELEASE(soundsScrollView);
  RELEASE(imagesScrollView);
  
  // RELEASE(filePrefsWindow); // FIXME: Causes NIB to crash...
  RELEASE(resourceManagers);

  RELEASE(nameTable);
  RELEASE(connections);
  RELEASE(topLevelObjects);
  RELEASE(visibleWindows);
  RELEASE(deferredWindows);
  DESTROY(savedEditors);
  DESTROY(openEditors);

  TEST_RELEASE(scmWrapper);
  [super dealloc];
}

/**
 * Pull all objects which are under the given parent, into array.
 */
- (void) _retrieveObjectsForParent: (id)parent
			 intoArray: (NSMutableArray *)array
		       recursively: (BOOL)flag
{
  NSArray *cons = [self connectorsForDestination: parent
			ofClass: [NSNibConnector class]];
  NSEnumerator *en = [cons objectEnumerator];
  id con = nil;

  while((con = [en nextObject]) != nil)
    {
      id obj = [con source];
      if(obj != nil)
	{
	  [array addObject: obj];
	  if(flag)
	    {
	      [self _retrieveObjectsForParent: obj intoArray: array recursively: flag];
	    }
	}
    }
}

/**
 * Pull all of the objects which are under a given parent.  Returns an 
 * autoreleased array.
 */
- (NSArray *) retrieveObjectsForParent: (id)parent recursively: (BOOL)flag
{
  NSMutableArray *result = [NSMutableArray array];

  // If parent is nil, use file's owner.
  if(parent == nil)
    {
      parent = filesOwner;
    }

  [self _retrieveObjectsForParent: parent intoArray: result recursively: flag];
  return result;
}

/**
 * Detach anObject from the document.  Optionally close the editor
 */
- (void) detachObject: (id)anObject closeEditor: (BOOL)close_editor
{
  if([self containsObject: anObject])
    {
      NSString	       *name = RETAIN([self nameForObject: anObject]); // released at end of method...
      unsigned	       count;
      NSArray          *objs = [self retrieveObjectsForParent: anObject recursively: NO];
      id               editor = [self editorForObject: anObject create: NO];
      id               parent = [self parentEditorForEditor: editor];
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

      RETAIN(anObject); // prevent release of object during notifications...
      [nc postNotificationName: GormWillDetachObjectFromDocumentNotification
                        object: anObject
                      userInfo: nil];
      
      // close the editor...
      if (close_editor)
        {
          [editor close];
        }
      
      if([parent respondsToSelector: @selector(selectObjects:)])
	{
	  [parent selectObjects: [NSArray array]];
	}

      count = [connections count];
      while (count-- > 0)
	{
	  id<IBConnectors> con = [connections objectAtIndex: count];
	  
	  if ([con destination] == anObject || [con source] == anObject)
	    {
	      [connections removeObjectAtIndex: count];
	    }
	}
      
      // if the font manager is being reset, zero out the instance variable.
      if([name isEqual: @"NSFont"])
	{
	  fontManager = nil;
	}
      
      if ([anObject isKindOfClass: [NSWindow class]] 
	  || [anObject isKindOfClass: [NSMenu class]] 
	  || [topLevelObjects containsObject: anObject])
	{
	  [objectsView removeObject: anObject];
	}
      
      // if it's in the top level items array, remove it.
      if([topLevelObjects containsObject: anObject])
	{
	  [topLevelObjects removeObject: anObject];
	}
      
      // eliminate it from being the windows/services menu, if it's being detached.
      if ([anObject isKindOfClass: [NSMenu class]])
	{
	  if([self windowsMenu] == anObject)
	    {
	      [self setWindowsMenu: nil];
	    }
	  else if([self servicesMenu] == anObject)
	    {
	      [self setServicesMenu: nil];
	    }
	  else if([self recentDocumentsMenu] == anObject)
	    {
	      [self setRecentDocumentsMenu: nil];
	    }
	}
      
      /*
       * Make sure this window isn't in the list of objects to be made visible
       * on nib loading.
       */
      if([anObject isKindOfClass: [NSWindow class]])
	{
	  [self setObject: anObject isVisibleAtLaunch: NO];
	}
      
      // some objects are given a name, some are not.  The only ones we need
      // to worry about are those that have names.
      if(name != nil)
	{
	  // remove from custom class map...
	  NSDebugLog(@"Delete from custom class map -> %@",name);
	  [classManager removeCustomClassForName: name];
	  if([anObject isKindOfClass: [NSScrollView class]])
	    {
	      NSView *subview = [anObject documentView];
	      NSString *objName = [self nameForObject: subview];
	      NSDebugLog(@"Delete from custom class map -> %@",objName);
	      [classManager removeCustomClassForName: objName];
	    }
	  else if([anObject isKindOfClass: [NSWindow class]])
	    {
	      [anObject setReleasedWhenClosed: YES];
	      [anObject close];
	    }

	  // make certain it's not displayed, if it's being detached.
	  if([anObject isKindOfClass: [NSView class]])
	    {
	      [anObject removeFromSuperview];
	    }

	  [nameTable removeObjectForKey: name];
	  
	  // free...
	  NSMapRemove(objToName, (void*)anObject);
	}
      
      // iterate over the list and remove any subordinate objects.
      [self detachObjects: objs closeEditors: close_editor];

      if (close_editor)
        {
          [self setSelectionFromEditor: nil]; // clear the selection.
        }
      
      RELEASE(name); // retained at beginning of method...
      [self touch]; // set the document as modified

      [nc postNotificationName: GormDidDetachObjectFromDocumentNotification
                        object: anObject
                      userInfo: nil];
      RELEASE(anObject); // release since notifications are done.
    }
}

/**
 * Detach object from document.
 */ 
- (void) detachObject: (id)object
{
  [self detachObject: object closeEditor: YES];
}

/**
 * Detach every object in anArray from the document.  Optionally closing editors.
 */
- (void) detachObjects: (/* NSArray* */ id)anArray closeEditors: (BOOL)close_editors
{
  NSEnumerator  *enumerator = [anArray objectEnumerator];
  NSObject      *obj;

  while ((obj = [enumerator nextObject]) != nil)
    {
      [self detachObject: obj closeEditor: close_editors];
    }
}

/** 
 * Detach all objects in array from the document.
 */
- (void) detachObjects: (NSArray *)array
{
  [self detachObjects: array closeEditors: YES];
}

/**
 * The path to where the .gorm file is saved.
 */
- (NSString*) documentPath
{
  return [self fileName];
}

/**
 * Create a subclass of the currently selected class in the classes view.
 */
- (id) createSubclass: (id)sender
{
  return [classesView createSubclass: sender];
}

/**
 * Add an outlet/action to the classes view.
 */
- (id) addAttributeToClass: (id)sender
{
  [classesView addAttributeToClass];
  return self;
}

/**
 * Create an instance of a given class.
 */
- (id) instantiateClass: (id)sender
{
  return [classesView instantiateClass: sender];
}

/**
 * Instantiate the class specified by the parameter className
 */ 
- (NSString *) instantiateClassNamed: (NSString *)className
{
  NSString *theName = nil;
  GSNibItem *item = nil;

  if([className isEqualToString: @"FirstResponder"])
    {
      return nil;
    }

  if([classManager canInstantiateClassNamed: className] == NO)
    {
      return nil;
    }

  if([classManager isSuperclass: @"NSView" linkedToClass: className] ||
     [className isEqualToString: @"NSView"])
    {
      Class cls;
      BOOL isCustom = [classManager isCustomClass: className];
      id instance;

      // Replace with NON custom class, since we don't have the compiled version
      // of the custom class available to us in Gorm.
      if(isCustom)
	{
	  className = [classManager nonCustomSuperClassOf: className];
	}
      
      // instantiate the object or it's substitute...
      cls = NSClassFromString(className);
      if([cls respondsToSelector: @selector(allocSubstitute)])
	{
	  instance = [cls allocSubstitute];
	}
      else
	{
	  instance = [cls alloc];
	}
      
      // give it some initial dimensions...
      if([instance respondsToSelector: @selector(initWithFrame:)])
	{
	  instance = [instance initWithFrame: NSMakeRect(10,10,380,280)];
	}
      else
	{
	  instance = [instance init];
	}
      
      // add it to the top level objects...
      [self attachObject: instance toParent: nil];
      
      // we want to record if it's custom or not and act appropriately...
      if(isCustom)
	{
	  theName = [self nameForObject: instance];
	  [classManager setCustomClass: className
			forName: theName];
	}

      [self changeToViewWithTag: 0];
      NSDebugLog(@"Instantiate NSView subclass %@",className);	      
    }
  else
    {
      item = [[GormObjectProxy alloc] initWithClassName: className];
      [self attachObject: item toParent: nil];      
      [self changeToViewWithTag: 0];
      theName = [self nameForObject: item];
    }

  return theName;
}

/**
 * Remove a class from the classes view
 */
- (id) remove: (id)sender
{
  return [classesView removeClass: sender];
}

/**
 * Parse a header into the classes view.
 */
- (id) loadClass: (id)sender
{
  return [classesView loadClass: sender];
}

/**
 * Create the class files for the selected class.
 */
- (id) createClassFiles: (id)sender
{
  return [classesView createClassFiles: sender];
}

/**
 * Close anEditor for anObject.
 */ 
- (void) editor: (id<IBEditors>)anEditor didCloseForObject: (id)anObject
{
  NSArray		*links;

  /*
   * If there is a link from this editor to a parent, remove it.
   */
  links = [self connectorsForSource: anEditor
			    ofClass: [GormEditorToParent class]];
  NSAssert([links count] < 2, NSInternalInconsistencyException);
  if ([links count] == 1)
    {
      [connections removeObjectIdenticalTo: [links objectAtIndex: 0]];
    }

  /*
   * Remove the connection linking the object to this editor
   */
  links = [self connectorsForSource: anObject
			    ofClass: [GormObjectToEditor class]];
  NSAssert([links count] < 2, NSInternalInconsistencyException);
  if ([links count] == 1)
    {
      [connections removeObjectIdenticalTo: [links objectAtIndex: 0]];
    }

  /*
   * Add to the master list of editors for this document
   */
  [openEditors removeObjectIdenticalTo: anEditor];

  /*
   * Make sure that this editor is not the selection owner.
   */
  if ([(id<IB>)[NSApp delegate] selectionOwner] == 
      (id<IBSelectionOwners>)anEditor)
    {
      [self resignSelectionForEditor: anEditor];
    }
}

/**
 * Returns an editor for anObject, if flag is YES, it creates a new
 * editor, if one doesn't currently exist.
 */
- (id<IBEditors>) editorForObject: (id)anObject
                           create: (BOOL)flag
{
  return [self editorForObject: anObject inEditor: nil create: flag];
}

/**
 * Returns the editor for anObject, in the editor anEditor.  If flag is
 * YES, an editor is created if one doesn't already exist.
 */
- (id<IBEditors>) editorForObject: (id)anObject
                         inEditor: (id<IBEditors>)anEditor
                           create: (BOOL)flag
{
  NSArray	*links;

  /*
   * Look up the editor links for the object to see if it already has an
   * editor.  If it does return it, otherwise create a new editor and a
   * link to it if the flag is set.
   */
  links = [self connectorsForSource: anObject
			    ofClass: [GormObjectToEditor class]];
  if ([links count] == 0 && flag)
    {
      Class		eClass = NSClassFromString([anObject editorClassName]);
      id<IBEditors>	editor;
      id<IBConnectors>	link;

      editor = [[eClass alloc] initWithObject: anObject inDocument: self];
      link = AUTORELEASE([[GormObjectToEditor alloc] init]);
      [link setSource: anObject];
      [link setDestination: editor];
      [connections addObject: link];
      
      if(![openEditors containsObject: editor] && editor != nil)
	{
	  [openEditors addObject: editor];
	}

      if (anEditor == nil)
	{
	  /*
	   * By default all editors are owned by the top-level editor of
	   * the document.
           */
	  anEditor = objectsView;
	}
      
      if (anEditor != editor)
	{
	  /*
	   * Link to the parent of the editor.
	   */
	  link = AUTORELEASE([[GormEditorToParent alloc] init]);
	  [link setSource: editor];
	  [link setDestination: anEditor];
	  [connections addObject: link];
	}
      else
	{
	  NSDebugLog(@"WARNING anEditor = editor");
	}

      [editor activate];
      RELEASE((NSObject *)editor);

      return editor;
    }
  else if ([links count] == 0)
    {
      return nil;
    }
  else
    {
      [(id<IBEditors>)[[links lastObject] destination] activate];
      return [[links lastObject] destination];
    }
}

/**
 * Forces the closing of all editors in the document.
 */
- (void) closeAllEditors
{
  NSEnumerator		*enumerator;
  id<IBConnectors>	con;
  NSMutableArray        *editors = [NSMutableArray array];

  // remove the editor connections from the connection array...
  enumerator = [connections objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      if ([con isKindOfClass: [GormObjectToEditor class]])
	{
	  [editors addObject: con];
	}
      else if ([con isKindOfClass: [GormEditorToParent class]])
	{
	  [editors addObject: con];
	}
    }
  [connections removeObjectsInArray: editors];
  [editors removeAllObjects];

  // Close all of the editors & get all of the objects out.
  // copy the array, since the close method calls editor:didCloseForObject:
  // and would effect the array during the execution of 
  // makeObjectsPerformSelector:.
  [editors addObjectsFromArray: openEditors];
  [editors makeObjectsPerformSelector: @selector(close)]; 
  [openEditors removeAllObjects];
  [editors removeAllObjects];
}

static void _real_close(GormDocument *self,
			NSEnumerator *enumerator)
{
  id                obj;
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  while ((obj = [enumerator nextObject]) != nil)
    {
      if ([obj isKindOfClass: [NSWindow class]])
        {
          [obj setReleasedWhenClosed: YES];
          [obj close];
        }
    }

  // deactivate the document...
  [self setDocumentActive: NO];
  [self closeAllEditors]; // shut down all of the editors..
  [nc postNotificationName: IBWillCloseDocumentNotification object: self];
  [nc removeObserver: self]; // stop listening to all notifications.
}

/**
 * Close the document and all windows associated.  Mark this document as closed.
 */
- (void) close
{
  isDocumentOpen = NO; 
  _real_close(self, [nameTable objectEnumerator]);
  [super close];
}

/**
 * Handle all notifications.   Checks the value of [aNotification name]
 * against the set of notifications this class responds to and takes
 * appropriate action.
 */
- (void) handleNotification: (NSNotification*)aNotification
{
  NSString *name = [aNotification name];

  if ([name isEqual: NSWindowWillCloseNotification] && isDocumentOpen)
    {
      _real_close(self, [nameTable objectEnumerator]);
      isDocumentOpen = NO;
    }
  else if ([name isEqual: NSWindowDidBecomeKeyNotification] && isDocumentOpen)
    {
      [self setDocumentActive: YES];
    }
  else if ([name isEqual: NSWindowWillMiniaturizeNotification] && isDocumentOpen)
    {
      [self setDocumentActive: NO];
    }
  else if ([name isEqual: NSWindowDidDeminiaturizeNotification] && isDocumentOpen)
    {
      [self setDocumentActive: YES];
    }
  else if ([name isEqual: IBWillBeginTestingInterfaceNotification] && isDocumentOpen)
    {
      id delegate = [NSApp delegate];
      if ([delegate activeDocument] == self && [delegate isInTool] == NO)
	{
	  NSEnumerator	*enumerator;
	  id		obj;

	  if ([[self window] isVisible])
	    {
	      [hidden addObject: [self window]];
	      [[self window] setExcludedFromWindowsMenu: YES];
	      [[self window] orderOut: self];
	    }

	  if ([delegate respondsToSelector: @selector(mainMenu)])
	    {
	      [[delegate mainMenu] close]; // close the menu during test...
	    }
	  
	  enumerator = [nameTable objectEnumerator];
	  while ((obj = [enumerator nextObject]) != nil)
	    {
	      if ([obj isKindOfClass: [NSMenu class]])
		{
		  if ([[obj window] isVisible])
		    {
		      [hidden addObject: obj];
		      [obj close];
		    }
		}
	      else if ([obj isKindOfClass: [NSWindow class]])
		{
		  if ([obj isVisible])
		    {
		      [hidden addObject: obj];
		      [obj orderOut: self];
		    }
		}
	    }
	}
    }
  else if ([name isEqual: IBWillEndTestingInterfaceNotification] && isDocumentOpen)
    {
      if ([hidden count] > 0)
	{
	  NSEnumerator	*enumerator;
	  id		obj;

          [[[NSApp delegate] mainMenu] display]; // bring the menu back...
          
	  enumerator = [hidden objectEnumerator];
	  while ((obj = [enumerator nextObject]) != nil)
	    {
	      if ([obj isKindOfClass: [NSMenu class]])
		{
		  [obj display];
		}
	      else if ([obj isKindOfClass: [NSWindow class]])
		{
		  [obj orderFront: self];
		}
	    }
	  [hidden removeAllObjects];
	  [[self window] setExcludedFromWindowsMenu: NO];
	}
    }
  else if ([name isEqual: IBClassNameChangedNotification] && isDocumentOpen)
    {
      [classesView reloadData];
      [self setSelectionFromEditor: nil];
      [self touch];
    }
  else if ([name isEqual: IBInspectorDidModifyObjectNotification] && isDocumentOpen)
    {
      [classesView reloadData];
      [self touch];
    }
  else if (([name isEqual: GormDidModifyClassNotification] ||
	    [name isEqual: GormDidDeleteClassNotification]) && isDocumentOpen)
    {
      if ([classesView isEditing] == NO) 
	{
	  [classesView reloadData];
	  [self touch];
	}
    }
  else if ([name isEqual: GormDidAddClassNotification] && isDocumentOpen)
    {
      NSArray *customClasses = [classManager allCustomClassNames];
      NSString *newClass = [customClasses lastObject];

      // go to the class which was just loaded in the classes view...
      [classesView reloadData];
      [self changeToViewWithTag: 3];

      if(newClass != nil)
	{
	  [classesView selectClass: newClass];
	}
    }
  else if([name isEqual: IBResourceManagerRegistryDidChangeNotification] && isDocumentOpen)
    {
      if(resourceManagers != nil)
	{
	  Class cls = [aNotification object];
	  id mgr = [(IBResourceManager *)[cls alloc] initWithDocument: self];
	  [resourceManagers addObject: mgr];
  	  [IBResourceManager registerForAllPboardTypes:window
	  			inDocument:self];
	}
    }
}

/**
 * Returns YES, if document is active.
 */
- (BOOL) isActive
{
  return isActive;
}

/**
 * Returns the name for anObject.
 */
- (NSString*) nameForObject: (id)anObject
{
  return (NSString*)NSMapGet(objToName, (void*)anObject);
}

/**
 * Returns the object for name.
 */
- (id) objectForName: (NSString*)name
{
  return [nameTable objectForKey: name];
}

/**
 * Returns all objects in the document.
 */
- (NSArray*) objects
{
  return [nameTable allValues];
}

/**
 * Returns YES, if the current select on the classes view is a class.
 */
- (BOOL) classIsSelected
{
  return [classesView currentSelectionIsClass];
}

/**
 * Remove all instances of a given class.
 */
- (void) removeAllInstancesOfClass: (NSString *)className
{
  NSMutableArray *removedObjects = [NSMutableArray array];
  NSEnumerator *en = [[self objects] objectEnumerator];
  id object = nil;

  // locate objects for removal
  while((object = [en nextObject]) != nil)
    {
      NSString *clsForObj = [classManager classNameForObject: object];
      if([className isEqual: clsForObj])
	{
	  [removedObjects addObject: object];
	}
    }

  // remove the objects
  [self detachObjects: removedObjects];
}

/**
 * Select a class in the classes view
 */
- (void) selectClass: (NSString *)className
{
  [classesView selectClass: className];
}

/**
 * Select a class in the classes view
 */
- (void) selectClass: (NSString *)className editClass: (BOOL)flag
{
  [classesView selectClass: className editClass: flag];
}

/**
 * Build our reverse mapping information and other initialisation
 */
- (void) rebuildObjToNameMapping
{
  NSEnumerator  *enumerator;
  NSString	*name;

  NSDebugLog(@"------ Rebuilding object to name mapping...");

  NSResetMapTable(objToName);
  NSMapInsert(objToName, (void*)filesOwner, (void*)@"NSOwner");
  NSMapInsert(objToName, (void*)firstResponder, (void*)@"NSFirst");
  enumerator = [[nameTable allKeys] objectEnumerator];
  while ((name = [enumerator nextObject]) != nil)
    {
      id obj = [nameTable objectForKey: name];
      
      NSDebugLog(@"%@ --> %@",name, obj);

      NSMapInsert(objToName, (void*)obj, (void*)name);
      if (([obj isKindOfClass: [NSMenu class]] && [name isEqual: @"NSMenu"]) ||
	  [obj isKindOfClass: [NSWindow class]])
	{
	  [[self openEditorForObject: obj] activate];
	}
    }

  NSDebugLog(@"------ Done rebuilding object to name mapping...");
}

/**
 * Open the editor for anObject, with parent object.
 */
- (id<IBEditors>) openEditorForObject: (id)anObject
		     withParentObject: (id)parentObj
{
  BOOL f = ([anObject isKindOfClass: [NSCell class]] == NO);
  id<IBEditors> pe = [self editorForObject: parentObj create: NO];
  id<IBEditors>	e = [self editorForObject: anObject inEditor: pe create: f];
  id<IBEditors> p = (parentObj == nil) ? [self parentEditorForEditor: e] : pe;
  
  if (p != nil && p != objectsView)
    {
      [self openEditorForObject: [p editedObject]];
    }

  // prevent bringing front of menus before they've been properly sized.
  if([anObject isKindOfClass: [NSMenu class]] == NO) 
    {
      [e orderFront];
      [[e window] makeKeyAndOrderFront: self];
    }

  return e;
}

/**
 * Open the editor for anObject.
 */
- (id<IBEditors>) openEditorForObject: (id)anObject
{
  return [self openEditorForObject: anObject withParentObject: nil];
}

/**
 * Return the parent editor for anEditor.
 */
- (id<IBEditors, IBSelectionOwners>) parentEditorForEditor: (id<IBEditors>)anEditor
{
  NSArray		*links;
  GormObjectToEditor	*con;

  links = [self connectorsForSource: anEditor
			    ofClass: [GormEditorToParent class]];
  con = [links lastObject];
  return [con destination];
}

/**
 * Return the parent of anObject.  The File's Owner is the root object in the
 * hierarchy, if anObject's parent is the Files's Owner, this method should return
 * nil.
 */
- (id) parentOfObject: (id)anObject
{
  NSArray		*old;
  id<IBConnectors>	con;

  old = [self connectorsForSource: anObject ofClass: [NSNibConnector class]];
  con = [old lastObject];
  if ([con destination] != filesOwner && [con destination] != firstResponder)
    {
      return [con destination];
    }
  return nil;
}

/**
 * Paste objects of aType into the document from aPasteboard 
 * with parent as the parent of the objects.
 */
- (NSArray*) pasteType: (NSString*)aType
        fromPasteboard: (NSPasteboard*)aPasteboard
                parent: (id)parent
{
  NSData	*data;
  NSArray	*objects;
  NSEnumerator	*enumerator;
  NSPoint	filePoint;
  NSPoint	screenPoint;
  NSUnarchiver *u;

  data = [aPasteboard dataForType: aType];
  if (data == nil)
    {
      NSDebugLog(@"Pasteboard %@ doesn't contain data of %@", aPasteboard, aType);
      return nil;
    }
  u = AUTORELEASE([[NSUnarchiver alloc] initForReadingWithData: data]);
  [u decodeClassName: @"GSCustomView" 
     asClassName: @"GormCustomView"];
  objects = [u decodeObject];
  enumerator = [objects objectEnumerator];
  filePoint = [[self window] mouseLocationOutsideOfEventStream];
  screenPoint = [[self window] convertBaseToScreen: filePoint];

  /*
   * Windows and panels are a special case - for a multiple window paste,
   * the windows need to be positioned so they are not on top of each other.
   */
  if ([aType isEqualToString: IBWindowPboardType])
    {
      NSWindow	*win;

      while ((win = [enumerator nextObject]) != nil)
	{
	  [win setFrameTopLeftPoint: screenPoint];
	  screenPoint.x += 10;
	  screenPoint.y -= 10;
	}
    }
  else if([aType isEqualToString: IBViewPboardType]) 
    {
      NSEnumerator *enumerator = [objects objectEnumerator];
      NSRect frame;
      id obj;

      while ((obj = [enumerator nextObject]) != nil)
      {
	// check to see if the object has a frame.  If so, then
	// modify it.  If not, simply iterate to the next object
	if([obj respondsToSelector: @selector(frame)]
	   && [obj respondsToSelector: @selector(setFrame:)])
	  {
	    frame = [obj frame];
	    frame.origin.x -= 6;
	    frame.origin.y -= 6;
	    [obj setFrame: frame];
	    RETAIN(obj);
	  }
      } 
    }

  // attach the objects to the parent and touch the document.
  [self attachObjects: objects toParent: parent];
  [self touch];

  return objects;
}

/**
 * Remove aConnector from the connections array and send the
 * notifications.
 */
- (void) removeConnector: (id<IBConnectors>)aConnector
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  
  RETAIN(aConnector); // prevent it from being dealloc'd until the notification is done.

  // issue pre notification..
  [nc postNotificationName: IBWillRemoveConnectorNotification
                    object: aConnector];
  
  // mark the document as changed.
  [self touch];
  
  [connections removeObjectIdenticalTo: aConnector];
  
  // issue post notification..
  [nc postNotificationName: IBDidRemoveConnectorNotification
                    object: aConnector];
  
  RELEASE(aConnector); // NOW we can dealloc it.
}

/**
 * The editor wants to give up the selection.  Go through all the known
 * editors (with links in the connections array) and try to find one
 * that wants to take over the selection.  Activate whatever editor we
 * find (if any).
 */
- (void) resignSelectionForEditor: (id<IBEditors>)editor
{
  NSEnumerator		*enumerator = [connections objectEnumerator];
  Class			editClass = [GormObjectToEditor class];
  id<IBConnectors>	c;

  while ((c = [enumerator nextObject]) != nil)
    {
      if ([c class] == editClass)
	{
	  id<IBEditors>	e = [c destination];

	  if (e != editor && [e wantsSelection])
	    {
	      [e activate];
	      [self setSelectionFromEditor: e];
	      return;
	    }
	}
    }
  /*
   * No editor available to take the selection - set a nil owner.
   */
  [self setSelectionFromEditor: nil];
}

/**
 * Set aName for object in the document.  If aName is nil,
 * a name is automatically created for object.
 */
- (void) setName: (NSString*)aName forObject: (id)object
{
  id		       oldObject = nil;
  NSString	      *oldName = nil;
  NSMutableDictionary *cc = [classManager customClassMap];
  NSString            *className = nil;

  if (object == nil)
    {
      NSDebugLog(@"Attempt to set name for nil object");
      return;
    }

  if (aName == nil)
    {
      /*
       * No name given - so we must generate one unless we already have one.
       */
      oldName = [self nameForObject: object];
      if (oldName == nil)
	{
	  NSString	*base;
	  unsigned	i = 0;

	  /*
	   * Generate a sensible name for the object based on its class.
	   */
	  if ([object isKindOfClass: [GSNibItem class]])
	    {
	      // use the actual class name for proxies
	      base = [(id)object className];
	    }
	  else
	    {
	      base = NSStringFromClass([object class]);
	    }

	  // pare down the name, if we're generating it.
	  if ([base hasPrefix: @"Gorm"])
	    {
	      base = [base substringFromIndex: 4];
	    }
	  if ([base hasPrefix: @"NS"] || [base hasPrefix: @"GS"])
	    {
	      base = [base substringFromIndex: 2];
	    }

	  aName = [base stringByAppendingFormat: @"(%u)", i];
	  while ([nameTable objectForKey: aName] != nil)
	    {
	      aName = [base stringByAppendingFormat: @"(%u)", ++i];
	    }
	}
      else
	{
	  return; /* Already named ... nothing to do */
	}
    }
  else // user supplied a name...
    {
      oldObject = [nameTable objectForKey: aName];
      if (oldObject != nil)
	{
	  NSDebugLog(@"Attempt to re-use name '%@'", aName);
	  return;
	}
      oldName = [self nameForObject: object];
      if (oldName != nil)
	{
	  if ([oldName isEqual: aName])
	    {
	      return; /* Already have this name ... nothing to do */
	    }
	  [nameTable removeObjectForKey: oldName];
	  NSMapRemove(objToName, (void*)object);
	}
    }

  // add it to the dictionary.
  [nameTable setObject: object forKey: aName];
  NSMapInsert(objToName, (void*)object, (void*)aName);
  if (oldName != nil)
    {
      RETAIN(oldName); // hold on to this temporarily...
      [nameTable removeObjectForKey: oldName];
    }
  if ([objectsView containsObject: object])
    {
      [objectsView refreshCells];
    }

  // check the custom classes map and replace the appropriate
  // object, if a mapping exists.
  if (cc != nil)
    {
      className = [cc objectForKey: oldName];
      if (className != nil)
	{
          RETAIN(className);
	  [cc removeObjectForKey: oldName];
	  [cc setObject: className forKey: aName]; 
	  RELEASE(className);
	}
    }

  // release oldName, if we get to this point.
  if(oldName != nil)
    {
      RELEASE(oldName);
    }

  // touch the document...
  [self touch];
}

/**
 * Add object to the visible at launch list.
 */
- (void) setObject: (id)anObject isVisibleAtLaunch: (BOOL)flag
{
  if (flag)
    {
      [visibleWindows addObject: anObject];
    }
  else
    {
      [visibleWindows removeObject: anObject];
    }
}

/**
 * Return YES, if anObject is visible at launch time.
 */
- (BOOL) objectIsVisibleAtLaunch: (id)anObject
{
  return [visibleWindows containsObject: anObject];
}

/**
 * Add anObject to the deferred list.
 */
- (void) setObject: (id)anObject isDeferred: (BOOL)flag
{
  if (flag)
    {
      [deferredWindows addObject: anObject];
    }
  else
    {
      [deferredWindows removeObject: anObject];
    }
}

/**
 * Return YES, if the anObject is in the deferred list.
 */
- (BOOL) objectIsDeferred: (id)anObject
{
  return [deferredWindows containsObject: anObject];
}

// windows / services menus...

/**
 * Set the windows menu.
 */
- (void) setWindowsMenu: (NSMenu *)anObject 
{
  if(anObject != nil)
    {
      [nameTable setObject: anObject forKey: @"NSWindowsMenu"];
    }
  else
    {
      [nameTable removeObjectForKey: @"NSWindowsMenu"];
    }
}

/**
 * return the windows menu.
 */ 
- (NSMenu *) windowsMenu
{
  return [nameTable objectForKey: @"NSWindowsMenu"];
}

/**
 * Set the object that will be the services menu in the app.
 */
- (void) setServicesMenu: (NSMenu *)anObject
{
  if(anObject != nil)
    {
      [nameTable setObject: anObject forKey: @"NSServicesMenu"];
    }
  else
    {
      [nameTable removeObjectForKey: @"NSServicesMenu"];
    }
}

/**
 * Return the object that will be the services menu.
 */
- (NSMenu *) servicesMenu
{
  return [nameTable objectForKey: @"NSServicesMenu"];
}

/**
 * Set the object that will be the font menu in the app.
 */
- (void) setFontMenu: (NSMenu *)anObject
{
  if(anObject != nil)
    {
      [nameTable setObject: anObject forKey: @"NSFontMenu"];
    }
  else
    {
      [nameTable removeObjectForKey: @"NSFontMenu"];
    }
}

/**
 * Return the object that will be the services menu.
 */
- (NSMenu *) fontMenu
{
  return [nameTable objectForKey: @"NSFontMenu"];
}

/**
 * Set the menu that will be the recent documents menu in the app.
 */
- (void) setRecentDocumentsMenu: (NSMenu *)anObject 
{
  if(anObject != nil)
    {
      [nameTable setObject: anObject forKey: @"NSRecentDocumentsMenu"];
    }
  else
    {
      [nameTable removeObjectForKey: @"NSRecentDocumentsMenu"];
    }
}

/**
 * Return the object that will be the receent documents menu.
 */ 
- (NSMenu *) recentDocumentsMenu
{
  return [nameTable objectForKey: @"NSRecentDocumentsMenu"];
}

/**
 * Marks this document as the currently active document.  The active document is
 * the one being edited by the user.
 */
- (void) setDocumentActive: (BOOL)flag
{
  if (flag != isActive && isDocumentOpen)
    {
      NSEnumerator	*enumerator;
      id		obj;

      // stop all connection activities.
      [(id<GormAppDelegate>)[NSApp delegate] stopConnecting];

      enumerator = [nameTable objectEnumerator];
      if (flag)
	{
	  GormDocument *document = (GormDocument*)[(id<IB>)[NSApp delegate] activeDocument];

	  // set the current document active and unset the old one.
	  [document setDocumentActive: NO];
	  isActive = YES;

	  // display everything.
	  while ((obj = [enumerator nextObject]) != nil)
	    {
	      NSString *name = [document nameForObject: obj];
	      if ([obj isKindOfClass: [NSWindow class]])
		{
		  [obj orderFront: self];
		}
	      else if ([obj isKindOfClass: [NSMenu class]] && 
		       [name isEqual: @"NSMenu"])
		{
		  [obj display];
		}
	    }

	  //
	  // Reset the selection to the current selection held by the current
	  // selection owner of this document when the document becomes active.
	  // This allows the app to switch to the correct inspector when the new
	  // document is selected.
	  //
	  [self setSelectionFromEditor: lastEditor];
	}
      else
	{
	  isActive = NO;
	  while ((obj = [enumerator nextObject]) != nil)
	    {
	      if ([obj isKindOfClass: [NSWindow class]])
		{
		  [obj orderOut: self];
		}
	      else if ([obj isKindOfClass: [NSMenu class]]  &&
		       [[self nameForObject: obj] isEqual: @"NSMenu"])
		{
		  [obj close];
		}
	    }
	  [self setSelectionFromEditor: nil];
	}
    }
}

/**
 * Sets the current selection from the given editor.  This method
 * causes the inspector to refresh with the proper object.
 */
- (void) setSelectionFromEditor: (id<IBEditors>)anEditor
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

  NSDebugLog(@"setSelectionFromEditor %@", anEditor);
  ASSIGN(lastEditor, anEditor);
  [(id<GormAppDelegate>)[NSApp delegate] stopConnecting]; // cease any connection
  if ([(NSObject *)anEditor respondsToSelector: @selector(window)])
    {
      [[anEditor window] makeKeyWindow];
      [[anEditor window] makeFirstResponder: (id)anEditor];
    }
  [nc postNotificationName: IBSelectionChangedNotification
		    object: anEditor];
}

/**
 * Mark the document as modified.
 */
- (void) touch
{
  [objectViewController reloadOutlineView];
  [self updateChangeCount: NSChangeDone];
}

/**
 * Returns the window and the rect r for object.
 */
- (NSWindow*) windowAndRect: (NSRect*)r forObject: (id)object
{
  /*
   * Get the window and rectangle for which link markup should be drawn.
   */
  if ([objectsView containsObject: object])
    {
      /*
       * objects that exist in the document objects view must have their link
       * markup drawn there, so we ask the view for the required rectangle.
       */
      *r = [objectsView rectForObject: object];
      return [objectsView window];
    }
  else if ([object isKindOfClass: [NSMenuItem class]])
    {
      NSArray	*links;
      NSMenu	*menu;
      id	editor;

      /*
       * Menu items must have their markup drawn in the window of the
       * editor of the parent menu.
       */
      links = [self connectorsForSource: object
				ofClass: [NSNibConnector class]];
      menu = [[links lastObject] destination];
      editor = [self editorForObject: menu create: NO];
      *r = [editor rectForObject: object];
      return [editor window];
    }
  else if ([object isKindOfClass: [NSView class]])
    {
      /*
       * Normal view objects just get link markup drawn on them.
       */
      id temp = object;
      id editor = [self editorForObject: temp create: NO];
      
      while ((temp != nil) && (editor == nil))
	{
	  temp = [temp superview];
	  editor = [self editorForObject: temp create: NO];
	}

      if (temp == nil)
	{
	  *r = [object convertRect: [object bounds] toView: nil];
	}
      else if ([editor respondsToSelector: 
			 @selector(windowAndRect:forObject:)])
	{
	  return [editor windowAndRect: r forObject: object];
	}
    }
  else if ([object isKindOfClass: [NSTableColumn class]])
    {
      NSTableView *tv = (NSTableView *)[[(NSTableColumn*)object dataCell] controlView];
      NSTableHeaderView *th =  [tv headerView];
      NSUInteger index;

      if (th == nil || tv == nil)
	{
	  NSDebugLog(@"fail 1 %@ %@ %@", [(NSTableColumn*)object headerCell], th, tv);
	  *r = NSZeroRect;
	  return nil;
	}
      
      index = [[tv tableColumns] indexOfObject: object];

      if (index == NSNotFound)
	{
	  NSDebugLog(@"fail 2");
	  *r = NSZeroRect;
	  return nil;
	}
      
      *r = [th convertRect: [th headerRectOfColumn: index]
	       toView: nil];
      return [th window];
    }
  else if([object isKindOfClass: [NSCell class]])
    {
      NSCell *cell = object;
      NSView *control = [cell controlView];

      if ([control isKindOfClass: [NSMatrix class]])
        {
          NSInteger row, col;
          NSMatrix *matrix = (NSMatrix *)control;

          if ([matrix getRow: &row column: &col ofCell: cell])
            {
              NSRect cellFrame = [matrix cellFrameAtRow: row column: col];
              *r = [control convertRect: cellFrame toView: nil];
              return [control window];
            }
        }
    }

  // if we get here, then it wasn't any of the above.
  *r = NSZeroRect;
  return nil;
}

/**
 * The document window.
 */
- (NSWindow*) window
{
  NSWindowController *winController = [[self windowControllers] objectAtIndex: 0];
  return [winController window];
}

/**
 * Removes all connections given action or outlet with the specified label 
 * (paramter name) class name (parameter className). 
 */
- (BOOL) removeConnectionsWithLabel: (NSString *)name
		      forClassNamed: (NSString *)className
			   isAction: (BOOL)action
{
  NSEnumerator *en = [connections objectEnumerator];
  NSMutableArray *removedConnections = [NSMutableArray array];
  id<IBConnectors> c = nil;
  BOOL removed = YES;
  BOOL prompted = NO;
  id delegate = [NSApp delegate];
  
  // find connectors to be removed.
  while ((c = [en nextObject]) != nil)
    {
      id proxy = nil;
      NSString *proxyClass = nil;
      NSString *label = [c label];

      if(label == nil)
	continue;

      if (action)
	{
	  if (![label hasSuffix: @":"]) 
	    continue;

	  if (![classManager isAction: label ofClass: className])
	    continue;

	  proxy = [c destination];
	}
      else
	{
	  if ([label hasSuffix: @":"]) 
	    continue;

	  if (![classManager isOutlet: label ofClass: className])
	    continue;

	  proxy = [c source];
	}
      
      // get the class for the current connectors object
      proxyClass = [proxy className];

      if ([label isEqualToString: name] && ([proxyClass isEqualToString: className] ||
	  [classManager isSuperclass: className linkedToClass: proxyClass]))
	{
	  removed = [delegate shouldBreakConnectionsModifyingLabel: name
							  isAction: action
							  prompted: prompted];
	  if (removed)
	    {
	      [removedConnections addObject: c];
	      break;
	    }
	}
    }

  // actually remove the connections.
  if(removed)
    {
      en = [removedConnections objectEnumerator];
      while((c = [en nextObject]) != nil)
	{
	  [self removeConnector: c];
	}
    }

  // done...
  NSDebugLog(@"Removed references to %@ on %@", name, className);
  return removed;
}

/**
 * Remove all connections to any and all instances of className.
 */
- (BOOL) removeConnectionsForClassNamed: (NSString *)className
{
  NSEnumerator *en = nil; 
  id<IBConnectors> c = nil;
  id delegate = [NSApp delegate];
  BOOL removed = [delegate shouldBreakConnectionsForClassNamed: className];
  
  // remove all.
  if(removed)
    {
      NSMutableArray *removedConnections = [NSMutableArray array];

      // first find all of the connections...
      en = [connections objectEnumerator];
      while ((c = [en nextObject]) != nil)
	{
	  NSString *srcClass = [[c source] className];
	  NSString *dstClass = [[c destination] className];

	  if ([srcClass isEqualToString: className] ||
	      [classManager isSuperclass: className linkedToClass: srcClass] ||
	      [dstClass isEqualToString: className] ||
	      [classManager isSuperclass: className linkedToClass: dstClass])
	    {
	      [removedConnections addObject: c];
	    }
	}

      // then remove them.
      en = [removedConnections objectEnumerator];
      while((c = [en nextObject]) != nil)
	{
	  [self removeConnector: c];
	}
    }
  
  // done...
  NSDebugLog(@"Removed references to actions/outlets for objects of %@",
    className);
  return removed;
}

/**
 * Refresh all connections to any and all instances of className.  Checks if
 * the class has the action/outlet present and deletes it, if it doesn't.
 */
- (void) refreshConnectionsForClassNamed: (NSString *)className
{
  NSEnumerator *en = [connections objectEnumerator];
  NSMutableArray *removedConnections = [NSMutableArray array];
  id<IBConnectors> c = nil;
  
  // first find all of the connections...
  while ((c = [en nextObject]) != nil)
    {
      NSString *srcClass = [[c source] className];
      NSString *dstClass = [[c destination] className];
      NSString *label = [c label];
      
      if ([srcClass isEqualToString: className] ||
	  [classManager isSuperclass: className 
			linkedToClass: srcClass])
	{
	  if([c isKindOfClass: [NSNibOutletConnector class]])
	    {
	      if([classManager outletExists: label onClassNamed: className] == NO)
		{
		  [removedConnections addObject: c];
		}
	    }	      
	}
      else if([dstClass isEqualToString: className] ||
	      [classManager isSuperclass: className 
			    linkedToClass: dstClass])
	{
	  if([c isKindOfClass: [NSNibControlConnector class]])
	    {
	      if([classManager actionExists: label onClassNamed: className] == NO)
		{
		  [removedConnections addObject: c];
		}
	    }
	}
    }
  
  // then remove them.
  en = [removedConnections objectEnumerator];
  while((c = [en nextObject]) != nil)
    {
      [self removeConnector: c];
    }
}

/**
 * Rename connections connected to an instance of on class to another.
 */
- (BOOL) renameConnectionsForClassNamed: (NSString *)className
				 toName: (NSString *)newName
{
  NSEnumerator *en = [connections objectEnumerator];
  id<IBConnectors> c = nil;
  id delegate = [NSApp delegate];
  BOOL renamed = [delegate shouldRenameConnectionsForClassNamed: className
						    toClassName: newName];

  // remove all.
  if(renamed)
    {
      while ((c = [en nextObject]) != nil)
	{
	  id source = [c source];
	  id destination = [c destination];
	  
	  // check both...
	  if ([[[c source] className] isEqualToString: className])
	    {
	      [source setClassName: newName];
	      NSDebugLog(@"Found matching source");
	    }
	  else if ([[[c destination] className] isEqualToString: className])
	    {
	      [destination setClassName: newName];
	      NSDebugLog(@"Found matching destination");
	    }
	}
    }

  // done...
  NSDebugLog(@"Changed references to actions/outlets for objects of %@", className);
  return renamed;
}


/**
 * Print out all editors for debugging purposes.
 */
- (void) printAllEditors
{
  NSMutableSet *set = [NSMutableSet setWithCapacity: 16];
  NSEnumerator *enumerator = [connections objectEnumerator];
  id<IBConnectors> c;

  while ((c = [enumerator nextObject]) != nil)
    {
      if ([GormObjectToEditor class] == [c class])
	{
	  [set addObject: [c destination]];
	}
    }

  NSLog(@"all editors %@", set);
}

/**
 * Open a sound and load it into the document.
 */
- (id) openSound: (id)sender
{
  NSArray	*fileTypes = [NSSound soundUnfilteredFileTypes]; 
  NSArray	*filenames;
  NSString	*filename;
  NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
  int		result;
  int		i;

  [oPanel setAllowsMultipleSelection: YES];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: nil
				   file: nil
				  types: fileTypes];
  if (result == NSOKButton)
    {
      filenames = [oPanel filenames];
      for (i=0; i<[filenames count]; i++)
      {
        filename = [filenames objectAtIndex:i];
        NSDebugLog(@"Loading sound file: %@",filenames);
        [soundsView addObject: [GormSound soundForPath: filename]];
      }
      return self;
    }

  return nil;
}

/**
 * Open an image and copy it into the document.
 */
- (id) openImage: (id)sender
{
  NSArray	*fileTypes = [NSImage imageFileTypes]; 
  NSArray	*filenames;
  NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
  NSString	*filename;
  int		result;
  int		i;

  [oPanel setAllowsMultipleSelection: YES];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: nil
				   file: nil
				  types: fileTypes];
  if (result == NSOKButton)
    {
      filenames = [oPanel filenames];
      for (i=0; i<[filenames count]; i++)
      {
        filename = [filenames objectAtIndex:i];
        NSDebugLog(@"Loading image file: %@",filename);
        [imagesView addObject: [GormImage imageForPath: filename]];
      }
      return self;
    }

  return nil;
}

/**
 * Return a text description of the document.
 */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpointer-to-int-cast"
- (NSString *) description
{
  return [NSString stringWithFormat: @"<%s: %lx> = <<name table: %@, connections: %@>>",
		   GSClassNameFromObject(self), 
		   (unsigned long)self,
		   nameTable, connections];
}
#pragma GCC diagnostic pop

/**
 * Returns YES, if obj is a top level object.
 */
- (BOOL) isTopLevelObject: (id)obj
{
  return [topLevelObjects containsObject: obj];
}

/**
 * Return first responder stand in.
 */
- (id) firstResponder
{
  return firstResponder;
}

/**
 * Return font manager stand in.
 */
- (id) fontManager
{
  return fontManager;
}

/**
 * Create resource manager instances for all registered classes.
 */
- (void) createResourceManagers
{
  NSArray *resourceClasses = [IBResourceManager registeredResourceManagerClassesForFramework: nil];
  NSEnumerator *en = [resourceClasses objectEnumerator];
  Class cls = nil;
  
  if(resourceManagers != nil)
    {
      // refresh...
      DESTROY(resourceManagers);
    }
  
  resourceManagers = [[NSMutableArray alloc] init];
  while((cls = [en nextObject]) != nil)
    {
      id mgr = AUTORELEASE([(IBResourceManager *)[cls alloc] initWithDocument: self]);
      [resourceManagers addObject: mgr];
    }
}

/**
 * The list of all resource managers.
 */
- (NSArray *) resourceManagers
{
  return resourceManagers;
}

/**
 * Get the resource manager which handles the content on pboard.
 */
- (IBResourceManager *) resourceManagerForPasteboard: (NSPasteboard *)pboard
{
  NSEnumerator *en = [resourceManagers objectEnumerator];
  IBResourceManager *mgr = nil, *result = nil;
  
  while((mgr = [en nextObject]) != nil)
    {
      if([mgr acceptsResourcesFromPasteboard: pboard])
	{
	  result = mgr;
	  break;
	}
    }

  return result;
}

/**
 * Get all pasteboard types managed by the resource manager.
 */
- (NSArray *) allManagedPboardTypes
{
  NSMutableArray *allTypes = [[NSMutableArray alloc] initWithObjects: NSFilenamesPboardType,
						     GormLinkPboardType, 
						     nil];
  NSArray *mgrs = [self resourceManagers];
  NSEnumerator *en = [mgrs objectEnumerator];
  IBResourceManager *mgr = nil;
  
  AUTORELEASE(allTypes);

  while((mgr = [en nextObject]) != nil)
    {
      NSArray *pbTypes = [mgr resourcePasteboardTypes];
      [allTypes addObjectsFromArray: pbTypes]; 
    }
  
  return allTypes;
}

/**
 * This method collects all of the objects in the document.
 */
- (NSMutableArray *) _collectAllObjects
{
  NSMutableArray *allObjects = [NSMutableArray arrayWithArray: [topLevelObjects allObjects]];
  NSEnumerator *en = [topLevelObjects objectEnumerator];
  NSMutableArray *removeObjects = [NSMutableArray array];
  id obj = nil;
  
  // collect all subviews/menus/etc.
  while((obj = [en nextObject]) != nil)
    {
      if([obj isKindOfClass: [NSWindow class]])
	{
	  NSMutableArray *views = [NSMutableArray array];
	  NSEnumerator *ven = [views objectEnumerator];
	  id vobj = nil;
	  
	  subviewsForView([(NSWindow *)obj contentView], views);
	  [allObjects addObjectsFromArray: views];
	  
	  while((vobj = [ven nextObject]))
	    {
	      if([vobj isKindOfClass: [GormCustomView class]])
		{
		  [removeObjects addObject: vobj];
		}
	      else if([vobj isKindOfClass: [NSMatrix class]])
		{
		  [allObjects addObjectsFromArray: [vobj cells]];
		}
	      else if([vobj isKindOfClass: [NSPopUpButton class]])
		{
		  [allObjects addObjectsFromArray: [vobj itemArray]];
		}
	      else if([vobj isKindOfClass: [NSTabView class]])
		{
		  [allObjects addObjectsFromArray: [vobj tabViewItems]];
		}
	    }
	}
      else if([obj isKindOfClass: [NSMenu class]])
	{
	  [allObjects addObjectsFromArray: findAll(obj)];
	}
    }

  // take out objects which shouldn't be considered.
  [allObjects removeObjectsInArray: removeObjects];

  return allObjects;
}

- (void) importStringsFromFile: (NSString *)filename
{
  NSMutableArray *allObjects = [self _collectAllObjects];
  NSDictionary *dictionary = nil;
  NSEnumerator *en = nil;
  id obj = nil;
  
  dictionary = [[NSString stringWithContentsOfFile: filename] propertyListFromStringsFileFormat];
    
  // change to translated values.
  en = [allObjects objectEnumerator];
  while((obj = [en nextObject]) != nil)
    {
      NSString *translation = nil; 
      
      if([obj respondsToSelector: @selector(setTitle:)] &&
	 [obj respondsToSelector: @selector(title)])
	{
	  translation = [dictionary objectForKey: [obj title]];
	  if(translation != nil)
	    {
	      [obj setTitle: translation];
	    }
	}
      else if([obj respondsToSelector: @selector(setStringValue:)] &&
	      [obj respondsToSelector: @selector(stringValue)])
	{
	  translation = [dictionary objectForKey: [obj stringValue]];
	  if(translation != nil)
	    {
	      [obj setStringValue: translation];
	    }
	}
      else if([obj respondsToSelector: @selector(setLabel:)] &&
	      [obj respondsToSelector: @selector(label)])
	{
	  translation = [dictionary objectForKey: [obj label]];
	  if(translation != nil)
	    {
	      [obj setLabel: translation];
	    }
	}
    }
}

- (void) exportStringsToFile: (NSString *)filename
{
  NSMutableArray *allObjects = [self _collectAllObjects];
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  NSEnumerator *en = [allObjects objectEnumerator];
  id obj = nil;
  BOOL touched = NO;
  
  // change to translated values.
  while((obj = [en nextObject]) != nil)
    {
      NSString *string = nil;
      if([obj respondsToSelector: @selector(setTitle:)] &&
	 [obj respondsToSelector: @selector(title)])
	{
	  string = [obj title];
	}
      else if([obj respondsToSelector: @selector(setStringValue:)] &&
	      [obj respondsToSelector: @selector(stringValue)])
	{
	  string = [obj stringValue];
	}
      else if([obj respondsToSelector: @selector(setLabel:)] &&
	      [obj respondsToSelector: @selector(label)])
	{
	  string = [obj label];
	}
      
      if(string != nil)
	{
	  [dictionary setObject: string forKey: string];
	  touched = YES;
	}
    }
  
  if(touched)
    {
      NSString *stringToWrite =
	@"/* TRANSLATORS: Make sure to quote all translated strings if\n"
	@"   they contain spaces or non-ASCII characters.  */\n\n";
      
      stringToWrite = [stringToWrite stringByAppendingString:
				       [dictionary descriptionInStringsFileFormat]];
      [stringToWrite writeToFile: filename atomically: YES];
    }
}

/**
 * Arrange views in front or in back of one another.
 */
- (void) arrangeSelectedObjects: (id)sender
{
  NSArray *selection =  [[(id<IB>)[NSApp delegate] selectionOwner] selection];
  NSInteger tag = [sender tag];
  NSEnumerator *en = [selection objectEnumerator];
  id v = nil;

  while((v = [en nextObject]) != nil)
    {
      if([v isKindOfClass: [NSView class]])
	{
	  id editor = [self editorForObject: v create: NO];
	  if([editor respondsToSelector: @selector(superview)])
	    {
	      id superview = [editor superview];
	      if(tag == 0) // bring to front...
		{ 
		  [superview moveViewToFront: editor];
		}
	      else if(tag == 1) // send to back
		{
		  [superview moveViewToBack: editor];
		}
	      [superview setNeedsDisplay: YES];
	    }
	}
    }
}

/**
 * Align objects to center, left, right, top, bottom.
 */
- (void) alignSelectedObjects: (id)sender
{
  NSArray *selection =  [[(id<IB>)[NSApp delegate] selectionOwner] selection];
  NSInteger tag = [sender tag];
  NSEnumerator *en = [selection objectEnumerator];
  id v = nil;
  id prev = nil;

  // Mark the document modified.
  [self touch];

  // Iterate over all in the selection and align them...
  while((v = [en nextObject]) != nil)
    {
      if([v isKindOfClass: [NSView class]])
	{
	  id editor = [self editorForObject: v create: NO];
	  if(prev != nil)
	    {
	      NSRect r = [prev frame];
	      NSRect e = [editor frame];
	      if(tag == 0) // center vertically
		{
		  float center = (r.origin.x + (r.size.width / 2));
		  e.origin.x = (center - (e.size.width / 2));
		}
	      else if(tag == 1) // center horizontally
		{
		  float center = (r.origin.y + (r.size.height / 2));		  
		  e.origin.y = (center - (e.size.height / 2));  
		}
	      else if(tag == 2) // align left
		{
		  e.origin.x = r.origin.x;
		}	      
	      else if(tag == 3) // align right
		{
		  float right = (r.origin.x + r.size.width);
		  e.origin.x = (right - e.size.width);
		}	      
	      else if(tag == 4) // align top
		{
		  float top = (r.origin.y + r.size.height);
		  e.origin.y = (top - e.size.height);
		}
	      else if(tag == 5) // align bottom
		{
		  e.origin.y = r.origin.y;
		}

	      [editor setFrame: e];
	      [[editor superview] setNeedsDisplay: YES];
	    }
	  prev = editor;
	} 
    }	      
}

/**
 * The window nib for the document class...
 */
- (NSString *) windowNibName
{
  return @"GormDocument";
}

/**
 * Call the builder and create the file wrapper to save the appropriate format.
 */
- (NSFileWrapper *)fileWrapperRepresentationOfType: (NSString *)type
{
  id<GormWrapperBuilder> builder = [[GormWrapperBuilderFactory sharedWrapperBuilderFactory]
				     wrapperBuilderForType: type];
  NSFileWrapper *result = nil;
  id delegate = [NSApp delegate];

  /*
   * Warn the user, if we are about to upgrade the package.
   */
  if(isOlderArchive && [filePrefsManager isLatest])
    {
      BOOL result = [delegate shouldUpgradeOlderArchive];

      if (result == YES)
	{
	  // we're saving anyway... set to new value.
	  isOlderArchive = NO;
	}
      else
	{
	  return nil;
	}
    }

  /*
   * Notify the world that we are saving...
   */
  [[NSNotificationCenter defaultCenter]
    postNotificationName: IBWillSaveDocumentNotification
    object: self];

  // build the archive...
  [self deactivateEditors];
  result = [builder buildFileWrapperWithDocument: self];
  [self reactivateEditors];
  if(result)
    {
      /*
       * This is the last thing we should do...
       */
      [[NSNotificationCenter defaultCenter]
	postNotificationName: IBDidSaveDocumentNotification
	object: self];
    }
  
  return result;
}


- (BOOL)loadFileWrapperRepresentation: (NSFileWrapper *)wrapper ofType: (NSString *)type
{
  id<GormWrapperLoader> loader = [[GormWrapperLoaderFactory sharedWrapperLoaderFactory]
				   wrapperLoaderForType: type];
  BOOL result = [loader loadFileWrapper: wrapper withDocument: self];

  if(result)
    {
      // this is the last thing we should do...
      [[NSNotificationCenter defaultCenter]
	postNotificationName: IBDidOpenDocumentNotification
	object: self];

      // make sure that the newly loaded document does not 
      // mark itself as modified.
      [self updateChangeCount: NSChangeCleared];
    }
  
  return result;
}

- (BOOL) keepBackupFile
{
  return ([[NSUserDefaults standardUserDefaults]
	    integerForKey: @"BackupFile"] == 1);
}

- (NSString *)displayName
{
  if ([self fileName] != nil)
    {
      return [[self fileName] lastPathComponent];
    }
  else
    {
      return [super displayName];
    }
}

/**
 * All of the objects and corresponding names.
 */ 
- (NSMutableDictionary *) nameTable
{
  return nameTable;
}

/**
 * All of the connections...
 */ 
- (NSMutableArray *) connections
{
  return connections;
}

/**
 * All top level objects.
 */ 
- (NSMutableSet *) topLevelObjects
{
  return topLevelObjects;
}

/**
 * All windows marked, visible at launch.
 */
- (NSSet *) visibleWindows
{
  return visibleWindows;
}

/**
 * All windows marked, deferred.
 */
- (NSSet *) deferredWindows
{
  return deferredWindows;
}

- (NSFileWrapper *) scmWrapper
{
  return scmWrapper;
}

- (void) setSCMWrapper: (NSFileWrapper *)wrapper
{
  ASSIGN(scmWrapper, wrapper);
}

/**
 * Images
 */
- (NSArray *) images
{
  return [imagesView objects];
}

/**
 * Sounds
 */
- (NSArray *) sounds
{
  return [soundsView objects];
}

/**
 * Sounds
 */
- (void) setSounds: (NSArray *)snds
{
  ASSIGN(sounds,[snds mutableCopy]);
}

/**
 * Images
 */
- (void) setImages: (NSArray *)imgs
{
  ASSIGN(images,[imgs mutableCopy]);
}

/**
 * File's owner...
 */
- (GormFilesOwner *) filesOwner
{
  return filesOwner;
}

/**
 * Gorm file prefs manager.
 */ 
- (GormFilePrefsManager *) filePrefsManager
{
  return filePrefsManager;
}

- (void) setDocumentOpen: (BOOL) flag
{
  isDocumentOpen = flag;
}

- (BOOL) isDocumentOpen
{
  return isDocumentOpen;
}

- (void) setInfoData: (NSData *)data
{
  ASSIGN(infoData, data);
}

- (NSData *) infoData
{
  return infoData;
}

- (void) setOlderArchive: (BOOL)flag
{
  isOlderArchive = flag;
}

- (BOOL) isOlderArchive
{
  return isOlderArchive;
}

//
// Encoding is here for testing the interface.  This allows
// Gorm to encode the interface and then run it like a regular
// app.  It needs to act like a container in order to do this.
//
- (void) encodeWithCoder: (NSCoder *)coder
{
  [coder encodeObject: topLevelObjects];
  [coder encodeObject: nameTable];
  [coder encodeObject: visibleWindows];
  [coder encodeObject: connections];
}

- (id) initWithCoder: (NSCoder *)coder
{
  ASSIGN(topLevelObjects, [coder decodeObject]);
  ASSIGN(nameTable, [coder decodeObject]);
  ASSIGN(visibleWindows, [coder decodeObject]);
  ASSIGN(connections, [coder decodeObject]);
  
  return self;
}
  
- (void) awakeWithContext: (NSDictionary *)context
{
  NSEnumerator *en = [connections objectEnumerator];
  id o = nil;
  
  while((o = [en nextObject]) != nil)
    {
      id val = nil;

      if ([o destination] == firstResponder)
	{
	  val = nil;
	}
      else
	{
	  val = [nameTable objectForKey: [o destination]];
	}

      if ([[o label] isEqualToString: @"terminate:"])
	{
	  [o setLabel: @"deferredEndTesting:"];
	}
      
      [o setDestination: val];
      [o establishConnection];
    }

  en = [visibleWindows objectEnumerator];
  o = nil;
  while((o = [en nextObject]) != nil)
    {
      [o orderFront: self];
    }
}
/* End of testInterface support code */

/**
 * Deactivate the editors for archiving..
 */
- (void) deactivateEditors
{
  NSEnumerator		*enumerator;
  id<IBConnectors>	con;

  /*
   * Map all connector sources and destinations to their name strings.
   * Deactivate editors so they won't be archived.
   */

  enumerator = [connections objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      if ([con isKindOfClass: [GormObjectToEditor class]])
	{
	  [savedEditors addObject: con];
	  [[con destination] deactivate];
	}
      else if ([con isKindOfClass: [GormEditorToParent class]])
	{
	  [savedEditors addObject: con];
	}
    }
  [connections removeObjectsInArray: savedEditors];
}

/**
 * Reactivate all of the editors...
 */
- (void) reactivateEditors
{
  NSEnumerator		*enumerator;
  id<IBConnectors>	con;

  /*
   * Restore editor links and reactivate the editors.
   */
  [connections addObjectsFromArray: savedEditors];
  enumerator = [savedEditors objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      if ([[con source] isKindOfClass: [NSView class]] == NO)
	[(id<IBEditors>)[con destination] activate];
    }
  [savedEditors removeAllObjects];
}

- (void) setFileType: (NSString *)type
{
  [super setFileType: type];
  [filePrefsManager setFileTypeName: type];
}

- (BOOL) revertToContentsOfURL: (NSURL *)url
                        ofType: (NSString *)type
                         error: (NSError **)error
{
  GormDocumentController *dc = [NSDocumentController sharedDocumentController];
  
  // [dc performSelector:@selector(openDocumentWithContentsOfURL:) withObject:url afterDelay:2];
  [self close];
  [dc openDocumentWithContentsOfURL:url];

  return YES;
}

//// PRIVATE METHODS...

- (NSString *) classForObject: (id)obj
{
  return [classManager classNameForObject: obj];
}

- (NSArray *) actionsOfClass: (NSString *)className
{
  return [classManager allActionsForClassNamed: className]; 
}

- (NSArray *) outletsOfClass: (NSString *)className
{
  return [classManager allOutletsForClassNamed: className]; 
}

//// Document Validation

- (NSArray *) validate
{
  NSMutableArray *results = [NSMutableArray array];
  NSEnumerator *en = [topLevelObjects objectEnumerator];
  id o = nil;

  NSLog(@"Validating topLevelObjects: %@", topLevelObjects);
  while ((o = [en nextObject]) != nil)
    {
      // check the type of o...
      if ([o isKindOfClass: [NSWindow class]]
	  || [o isKindOfClass: [NSMenu class]]
	  || [o isKindOfClass: [NSView class]]
	  || [o isKindOfClass: [GormObjectProxy class]])
	{
	  continue;
	}
      else
	{
	  NSString *className = NSStringFromClass([o class]);
	  NSString *error = [NSString stringWithFormat: @"%@ has an invalid class of type %@", o, className];

	  [results addObject: error];
	}
    }

  return results;
}

@end

@implementation GormDocument (MenuValidation)
- (BOOL) isEditingObjects
{
  return ([selectionBox contentView] == scrollView);
}

- (BOOL) isEditingImages
{
  return ([selectionBox contentView] == imagesScrollView);
}

- (BOOL) isEditingSounds
{
  return ([selectionBox contentView] == soundsScrollView);
}

- (BOOL) isEditingClasses
{
  return ([selectionBox contentView] == classesView);
}
@end

@implementation GormDocument (NSToolbarDelegate)

- (NSToolbarItem*)toolbar: (NSToolbar*)toolbar
    itemForItemIdentifier: (NSString*)itemIdentifier
willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *toolbarItem = AUTORELEASE([[NSToolbarItem alloc]
					     initWithItemIdentifier: itemIdentifier]);

  if([itemIdentifier isEqual: @"ObjectsItem"])
    {
      [toolbarItem setLabel: @"Objects"];
      [toolbarItem setImage: objectsImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 0];
    }
  else if([itemIdentifier isEqual: @"ImagesItem"])
    {
      [toolbarItem setLabel: @"Images"];
      [toolbarItem setImage: imagesImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 1];
    }
  else if([itemIdentifier isEqual: @"SoundsItem"])
    {
      [toolbarItem setLabel: @"Sounds"];
      [toolbarItem setImage: soundsImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 2];
    }
  else if([itemIdentifier isEqual: @"ClassesItem"])
    {
      [toolbarItem setLabel: @"Classes"];
      [toolbarItem setImage: classesImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 3];
    }
  else if([itemIdentifier isEqual: @"FileItem"])
    {
      [toolbarItem setLabel: @"File"];
      [toolbarItem setImage: fileImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 4];
    }

  return toolbarItem;
}

- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*)toolbar
{
  return [NSArray arrayWithObjects: @"ObjectsItem", 
		  @"ImagesItem", 
		  @"SoundsItem", 
		  @"ClassesItem", 
		  @"FileItem", 
		  nil];
}

- (NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar*)toolbar
{ 
  return [NSArray arrayWithObjects: @"ObjectsItem", 
		  @"ImagesItem", 
		  @"SoundsItem", 
		  @"ClassesItem", 
		  @"FileItem",
		  nil];
}

- (NSArray*) toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{ 
  return [NSArray arrayWithObjects: @"ObjectsItem", 
		  @"ImagesItem", 
		  @"SoundsItem", 
		  @"ClassesItem", 
		  @"FileItem",
		  nil];
}
@end

@implementation GormDocument (Metadata)

// Core methods..

- (id) outlineView: (NSOutlineView *)ov
	     child: (NSInteger)index
	    ofItem: (id)item
{
  id result = nil;

  if ([objectViewController editor] == NO)
    [self deactivateEditors];

  NSDebugLog(@"index = %ld, item = %@", index, item);
  if (item == nil)
    {
     result = [[topLevelObjects allObjects] objectAtIndex: index];
    }
  else if ([item isKindOfClass: [NSWindow class]])
    {
      result = [item contentView];
    }
  else if ([item isKindOfClass: [NSView class]])
    {
      result = [[item subviews] objectAtIndex: index];
    }
  else if ([item isKindOfClass: [NSMenu class]])
    {
      result = [item itemAtIndex: index];
    }
  else if ([item isKindOfClass: [NSMenuItem class]])
    {
      result = [item submenu];
    }
  NSDebugLog(@"result = %@", result);
  if ([objectViewController editor] == NO)
    [self reactivateEditors];
  
  return result;
}

- (BOOL) outlineView: (NSOutlineView *)ov
    isItemExpandable: (id)item
{
  BOOL f = NO;
  
  if ([objectViewController editor] == NO)
    [self deactivateEditors];
  if (item == nil)
    {
      f = [topLevelObjects count] > 0;
    }
  else if ([item isKindOfClass: [NSWindow class]])
    {
      f = [item contentView] != nil;
    }
  else if ([item isKindOfClass: [NSView class]])
    {
      f = [[item subviews] count] > 0; 
    }  
  else if ([item isKindOfClass: [NSMenu class]])
    {
      f = [item numberOfItems] > 0; 
    }
  else if ([item isKindOfClass: [NSMenuItem class]])
    {
      f = [item hasSubmenu];
    }
  if ([objectViewController editor] == NO)
    [self reactivateEditors];
  
  NSDebugLog(@"f = %d",f);
  return f;
}

- (NSInteger) outlineView: (NSOutlineView *)ov
   numberOfChildrenOfItem: (id)item
{
  NSInteger c = 0;
  
  if ([objectViewController editor] == NO)
    [self deactivateEditors];
  if (item == nil)
    {
      c = [topLevelObjects count];
    }
  else if ([item isKindOfClass: [NSWindow class]])
    {
      c = 1; // We are only counting the contentView...
    }
  else if ([item isKindOfClass: [NSView class]])
    {
      c = [[item subviews] count]; 
    }
  else if ([item isKindOfClass: [NSMenu class]])
    {
      c = [item numberOfItems]; 
    }
  else if ([item isKindOfClass: [NSMenuItem class]])
    {
      c = 1; // one submenu...
    }
  if ([objectViewController editor] == NO)
    [self reactivateEditors];
  
  NSDebugLog(@"c = %ld", c);
  return c;
}

- (id) outlineView: (NSOutlineView *)ov
       objectValueForTableColumn: (NSTableColumn *)tableColumn
       byItem: (id)item
{
  id value = nil;
  NSString *className = [classManager classNameForObject: item];
  NSString *name = [self nameForObject: item];
  NSUInteger version = 0;
  
  if ([objectViewController editor] == NO)
    [self deactivateEditors];
  if ([[tableColumn identifier] isEqualToString: @"objects"])
    {
      NSString *title = @"";

      if ([item respondsToSelector: @selector(title)])
	{
	  title = [item title];
	  value = [NSString stringWithFormat: @"%@ : %@",
			    (title != nil && ![title isEqualToString: @""]) ? title : @"*Untitled*",
		       (name != nil) ? name : @"*Unnamed*"];
	}
      else
	{
	  value = [NSString stringWithFormat: @"%@", (name != nil)?name:@"*Unnamed*"];
	}
    }
  else if ([[tableColumn identifier] isEqualToString: @"class"])
    {
      value = className;
    }
  else if ([[tableColumn identifier] isEqualToString: @"version"])
    {
      value = [NSNumber numberWithInteger: version];
    }
  else if ([[tableColumn identifier] isEqualToString: @"destination"])
    {
      NSArray *c = [self connectorsForDestination: item];
      value = [NSNumber numberWithInteger: [c count]];
    }
  else if ([[tableColumn identifier] isEqualToString: @"source"])
    {
      NSArray *c = [self connectorsForSource: item];
      value = [NSNumber numberWithInteger: [c count]];
    }
  if ([objectViewController editor] == NO)
    [self reactivateEditors];
  
  return value;
}

// Other methods...

- (BOOL) outlineView: (NSOutlineView *)ov
	  acceptDrop: (id<NSDraggingInfo>)info
		item: (id)item
	  childIndex: (NSInteger)index
{
  return NO;
}

- (id) outlineView: (NSOutlineView *)ov
       itemForPersistentObject: (id)obj
{
  return nil;
}

- (id) outlineView: (NSOutlineView *)ov
       persistentObjectForItem: (id)item
{
  return nil;
}

- (NSArray *) outlineView: (NSOutlineView *)ov
          namesOfPromisedFilesDroppedAtDestination: (NSURL *)dropDestination
	  forDraggedItems: (NSArray *)items
{
  return nil;
}

- (void) outlineView: (NSOutlineView *)ov
      setObjectValue: (id)value
      forTableColumn: (NSTableColumn *)tc
	      byItem: (id)item
{
}

- (void) outlineView: (NSOutlineView *)ov
         sortDescriptorsDidChange: (NSArray *)oldDescriptors
{
}

- (void) outlineView: (NSOutlineView *)ov
	  writeItems: (NSArray *)items
	toPasteboard: (NSPasteboard *)pb
{
}

- (NSDragOperation) outlineView: (NSOutlineView *)ov
		   validateDrop: (id<NSDraggingInfo>)info
		   proposedItem: (id)item
	     proposedChildIndex: (NSInteger)index
{
  return 0;
}

@end
