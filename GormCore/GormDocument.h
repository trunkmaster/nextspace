/* GormDocument.h
 *
 * Copyright (C) 1999, 2003 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2003
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

#ifndef INCLUDED_GormDocument_h
#define INCLUDED_GormDocument_h

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include <GNUstepGUI/GSNibContainer.h>

@class GormClassManager, GormClassEditor, GormObjectProxy, GormFilesOwner, 
  GormFilePrefsManager, GormDocumentWindow, GormObjectViewController;

/*
 * Trivial classes for connections from objects to their editors, and from
 * child editors to their parents.  This does nothing special, but we can
 * use the fact that it's a different class to search for it in the connections
 * array.
 */
@interface	GormObjectToEditor : NSNibConnector
@end

@interface	GormEditorToParent : NSNibConnector
@end

/*
 * Each document has a GormFirstResponder object that is used as a placeholder
 * for the first responder at any instant.
 */
@interface GormFirstResponder : NSObject
{
}
@end

@interface GormDocument : NSDocument <IBDocuments, GSNibContainer, NSCoding, NSXMLParserDelegate> 
{
  GormClassManager      *classManager;
  GormFilesOwner	*filesOwner;
  GormFirstResponder	*firstResponder;
  GormObjectProxy       *fontManager;
  NSMapTable		*objToName;
  GormDocumentWindow	*window;
  NSBox                 *selectionBox;
  NSScrollView		*scrollView;
  NSScrollView          *classesScrollView;
  NSScrollView          *soundsScrollView;
  NSScrollView          *imagesScrollView;
  id                    classesView;
  id			objectsView;
  id			soundsView;
  id			imagesView;
  BOOL			isActive;
  BOOL                  isDocumentOpen;
  NSMenu		*savedMenu;
  NSMenuItem		*quitItem;		/* Replaced during test-mode */
  NSMutableArray	*savedEditors;
  NSMutableArray	*hidden;
  NSMutableArray        *openEditors;
  NSToolbar             *toolbar;
  id                    lastEditor;
  BOOL                  isOlderArchive;
  id                    filePrefsView;
  GormFilePrefsManager  *filePrefsManager;
  NSWindow              *filePrefsWindow;
  NSMutableArray        *resourceManagers;
  NSData                *infoData;   /* data.info contents */
  NSMutableArray        *images;     /* temporary storage for images. */             
  NSMutableArray        *sounds;     /* temporary storage for sounds. */
  NSFileWrapper         *scmWrapper;

  // container data structures
  NSMutableDictionary   *nameTable;
  NSMutableArray        *connections;
  NSMutableSet          *topLevelObjects;
  NSMutableSet          *visibleWindows;
  NSMutableSet          *deferredWindows;

  // Controllers...
  GormObjectViewController *objectViewController;
}

/* Handle notifications */

/**
 * Handle all notifications.   Checks the value of [aNotification name]
 * against the set of notifications this class responds to and takes
 * appropriate action.
 */
- (void) handleNotification: (NSNotification*)aNotification;

/* Document management */

/**
 * Returns YES, if document is active.
 */
- (BOOL) isActive;

/**
 * Return YES, if anObject is visible at launch time.
 */
- (BOOL) objectIsVisibleAtLaunch: (id)anObject;


/**
 * Return YES, if anObject is deferred.
 */
- (BOOL) objectIsDeferred: (id)anObject;

/**
 * Retrieve all objects which have parent as thier parent.  If flag is YES,
 * then retrieve the entire graph of objects starting with the parent.
 */
- (NSArray *) retrieveObjectsForParent: (id)parent recursively: (BOOL)flag;

/**
 * Marks this document as the currently active document.  The active document is
 * the one being edited by the user.
 */
- (void) setDocumentActive: (BOOL)flag;

/**
 * Add object to the visible at launch list.
 */
- (void) setObject: (id)anObject isVisibleAtLaunch: (BOOL)flag;

/**
 * Add object to the defferred list.
 */
- (void) setObject: (id)anObject isDeferred: (BOOL)flag;

/**
 * The document window.
 */
- (NSWindow*) window;

/**
 * Returns YES, if obj is a top level object.
 */
- (BOOL) isTopLevelObject: (id)obj;

/**
 * Forces the closing of all editors in the document.
 */
- (void) closeAllEditors;

/**
 * Create resource manager instances for all registered classes.
 */
- (void) createResourceManagers;

/**
 * The list of all resource managers.
 */
- (NSArray *) resourceManagers;

/**
 * Get the resource manager which handles the content on pboard.
 */
- (IBResourceManager *) resourceManagerForPasteboard: (NSPasteboard *)pboard;

/**
 * Switch to the top level editor responsible for a given type.  This allows the
 * document in the view to switch to the view which is appropriate for the resource
 * being dragged in.
 */
- (void) changeToTopLevelEditorAcceptingTypes: (NSArray *)types 
                                  andFileType: (NSString *)fileType;

/**
 * Switches to the view using the specified tag.  
 * They are 0=objects, 1=images, 2=sounds, 3=classes, 4=file prefs.
 */
- (void) changeToViewWithTag: (int)tag;

/**
 * returns the view using the specified tag.  
 * They are 0=objects, 1=images, 2=sounds, 3=classes, 4=file prefs.
 */
- (NSView *)viewWithTag:(int)tag;

/**
 * Returns all pasteboard types registered for with the IBResourceManager.
 */
- (NSArray *) allManagedPboardTypes;

/**
 * Open the editor for anObject, with parent object.
 */
- (id<IBEditors>) openEditorForObject: (id)anObject
                     withParentObject: (id)parentObj;

/* Language translation */
/**
 * Load a given file into the reciever using `filename'.
 */
- (void) importStringsFromFile: (NSString *)filename;

/**
 * Export the strings from receiver to the file indicated by 'filename'.
 */
- (void) exportStringsToFile: (NSString *)filename;

/* Managing classes */
/**
 * Shared class manager
 */
- (GormClassManager*) classManager;

/**
 * Create a subclass of the selected class
 */
- (id) createSubclass: (id)sender;

/**
 * Instantiate the selected class
 */
- (id) instantiateClass: (id)sender;

/**
 * Instantiate the class specified by the parameter className and
 * returns the reference name within the document
 */ 
- (NSString *) instantiateClassNamed: (NSString *)className;

/**
 * Generate the class files for the selected class
 */
- (id) createClassFiles: (id)sender;

/**
 * Add attribute to class
 */
- (id) addAttributeToClass: (id)sender;

/**
 * Remove the selected class
 */
- (id) remove: (id)sender;

/**
 * Select class named className
 */
- (void) selectClass: (NSString *)className;

/**
 * Select class named className and edit it if flag is YES
 */
- (void) selectClass: (NSString *)className editClass: (BOOL)flag;

/**
 * Returns YES if a class is selected in the view
 */ 
- (BOOL) classIsSelected;

/**
 * Removes all instances of class named classNamed
 */
- (void) removeAllInstancesOfClass: (NSString *)classNamed;

/* Sound & Image support */

/**
 * Open a sound and load it into the document.
 */
- (id) openSound: (id)sender;

/**
 * Open an image and copy it into the document.
 */
- (id) openImage: (id)sender;

/* Connections */

/**
 *
 */
- (NSMutableArray *) connections;

/**
 * Build our reverse mapping information and other initialisation
 */
- (void) rebuildObjToNameMapping;

/**
 * Removes all connections given action or outlet with the specified label 
 * (paramter name) class name (parameter className). 
 */
- (BOOL) removeConnectionsWithLabel: (NSString *)name
                      forClassNamed: (NSString *)className
                           isAction: (BOOL)action;
/**
 * Remove all connections to any and all instances of className.
 */
- (BOOL) removeConnectionsForClassNamed: (NSString *)name;

/**
 * Rename connections connected to an instance of on class to another.
 */
- (BOOL) renameConnectionsForClassNamed: (NSString *)name 
                                 toName: (NSString *)newName;

/**
 * Refresh all connections to any and all instances of className.  Checks if
 * the class has the action/outlet present and deletes it, if it doesn't.
 */
- (void) refreshConnectionsForClassNamed: (NSString *)className;

/* class loading */

/**
 * Load a class into the document.
 */
- (id) loadClass: (id)sender;

/*** services/windows menus... ***/

/**
 * Set the services menu.
 */
- (void) setServicesMenu: (NSMenu *)menu;

/**
 * Returns the services menu for the document.
 */
- (NSMenu *) servicesMenu;

/**
 * Set the font menu.
 */
- (void) setFontMenu: (NSMenu *)menu;

/**
 * Returns the font menu for the document.
 */
- (NSMenu *) fontMenu;

/**
 * Sets the windows menu.
 */
- (void) setWindowsMenu: (NSMenu *)menu;

/**
 * Returns the menu which will be the windows menu for the document.
 */
- (NSMenu *) windowsMenu;

/**
 * Sets the recent documents menu.
 */
- (void) setRecentDocumentsMenu: (NSMenu *)menu;

/**
 * Returns the menu which will be the recent documents menu for the document.
 */
- (NSMenu *) recentDocumentsMenu;

/*** first responder/font manager ***/

/**
 * Returns stand-in object for fontManager.
 */
- (id) fontManager;

/**
 * Returns stand-in object for firstResponder
 */
- (id) firstResponder;

/* Layout */

/**
 * Arrages selected objects based on the either in front of or in
 * back of the view stack.
 */ 
- (void) arrangeSelectedObjects: (id)sender;

/**
 * Aligns selected objects on a given axis.
 */
- (void) alignSelectedObjects: (id)sender;

/** 
 * WindowAndRect:forObject: is called by Gorm to determine where it should
 * draw selection markup
 */
- (NSWindow*) windowAndRect: (NSRect*)r forObject: (id)object;

/**
 * Save the SCM directory.
 */
- (void) setSCMWrapper: (NSFileWrapper *) wrapper;

/**
 * Save the SCM directory.
 */
- (NSFileWrapper *) scmWrapper;

/**
 * Images
 */
- (NSArray *) images;

/**
 * Sounds
 */
- (NSArray *) sounds;

/**
 * Images
 */
- (void) setImages: (NSArray *) imgs;

/**
 * Sounds
 */
- (void) setSounds: (NSArray *) snds;

/**
 * File's Owner
 */
- (GormFilesOwner *) filesOwner;

/**
 * File preferences.
 */
- (GormFilePrefsManager *) filePrefsManager;

/**
 * Windows visible at launch...
 */ 
- (NSSet *) visibleWindows;

/**
 * Windows deferred.
 */ 
- (NSSet *) deferredWindows;

/**
 * Set the document open flag.
 */
- (void) setDocumentOpen: (BOOL) flag;

/**
 * Return the document open flag.
 */
- (BOOL) isDocumentOpen;

/**
 * Set the file info for this document.
 */
- (void) setInfoData: (NSData *)data;

/**
 * return the file info.
 */
- (NSData *) infoData;

/**
 * Set the "older archive" flag.
 */ 
- (void) setOlderArchive: (BOOL)flag;

/**
 * Return YES if this is an older archive.
 */
- (BOOL) isOlderArchive;

/**
 * Deactivate the editors for archiving..
 */
- (void) deactivateEditors;

/**
 * Reactivate all of the editors...
 */
- (void) reactivateEditors;

/**
 * Returns the name for the object...
 */ 
- (NSString*) nameForObject: (id)anObject;

/**
 * Returns the object for name.
 */
- (id) objectForName: (NSString*)name;

/**
 * Returns all names for all objects known to Gorm.
 */
- (NSArray *) objects;

/**
 * Add aConnector to the set of connectors in this document.
 */ 
- (void) addConnector: (id<IBConnectors>)aConnector;

/**
 * Returns a set containing the top level objects for this document.
 */
- (NSMutableSet *) topLevelObjects;

/**
 * Returns an array of issues. If document is valid the array should be empty.
 */
- (NSArray *) validate;

@end

@interface GormDocument (MenuValidation)
/**
 * Returns YES if the document is editing instance/objects.
 */
- (BOOL) isEditingObjects;

/**
 * Returns YES if the document is editing images.
 */
- (BOOL) isEditingImages;

/**
 * Returns YES if the document is editing sounds.
 */
- (BOOL) isEditingSounds;

/**
 * Returns YES if the document is editing classes.
 */
- (BOOL) isEditingClasses;

@end

@interface GormDocument (Metadata) <NSOutlineViewDataSource>
@end

#endif
