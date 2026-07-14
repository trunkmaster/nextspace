/* IBDocuments.h
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2003
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef INCLUDED_IBDOCUMENTS_H
#define INCLUDED_IBDOCUMENTS_H

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/IBEditors.h>
#include <InterfaceBuilder/IBConnectors.h>
#include <InterfaceBuilder/IBSystem.h>

IB_EXTERN NSString *IBDidOpenDocumentNotification;
IB_EXTERN NSString *IBWillSaveDocumentNotification;
IB_EXTERN NSString *IBDidSaveDocumentNotification;
IB_EXTERN NSString *IBWillCloseDocumentNotification;

@protocol IBDocuments <NSObject>
/**
 * Add a connection
 */
- (void) addConnector: (id<IBConnectors>)aConnector;

/**
 * Returns an array containing all connections for the receiver.
 */
- (NSArray*) allConnectors;

/**
 * Attach object to document with a specified name.  Pass nil to
 * aName to have Gorm assign a name to it.  (GS extension)
 */ 
- (void) attachObject: (id)anObject toParent: (id)aParent withName: (NSString *)aName;

/**
 * Attaches an object to the document and makes the association
 * with the parent.
 */
- (void) attachObject: (id)anObject toParent: (id)aParent;

/**
 * Iterates over anArray and attaches all objects in it to the
 * receiver with aParent as the parent.
 */
- (void) attachObjects: (NSArray*)anArray toParent: (id)aParent;

/**
 * Returns an autoreleased array containing all connections for
 * the given destination.
 */ 
- (NSArray*) connectorsForDestination: (id)destination;

/** 
 * Returns an autoreleased array containing all connectors of
 * the given class for the destination. 
 */
- (NSArray*) connectorsForDestination: (id)destination
			      ofClass: (Class)aConnectorClass;
/**
 * Returns an autoreleased array containing all connections for
 * the given source.
 */
- (NSArray*) connectorsForSource: (id)source;

/**
 * Returns an autoreleased array containing all connectors of the
 * given class for the source.
 */
- (NSArray*) connectorsForSource: (id)source
			 ofClass: (Class)aConnectorClass;

/**
 * Returns YES, if the receiver contains anObject.
 */
- (BOOL) containsObject: (id)anObject;

/**
 * Returns YES, if the receiver contains an object with the given name
 * and parent.
 */
- (BOOL) containsObjectWithName: (NSString*)aName forParent: (id)parent;

/** 
 * Copies anObject to the pasteboard with the aType.
 */
- (BOOL) copyObject: (id)anObject
	       type: (NSString*)aType
       toPasteboard: (NSPasteboard*)aPasteboard;

/**
 * Copues an array of objects to aPasteboard with aType.
 */
- (BOOL) copyObjects: (NSArray*)anArray
		type: (NSString*)aType
	toPasteboard: (NSPasteboard*)aPasteboard;

/** 
 * Detaches anObject from the receiver.
 */
- (void) detachObject: (id)anObject;

/**
 * Detaches an object from the receiver, closes editor if asked.  GNUstep extension.
 */
- (void) detachObject: (id)anObject closeEditor: (BOOL)close_editor;

/**
 * Detaches an array of objects from the receiver.
 */
- (void) detachObjects: (NSArray*)anArray;

/**
 * Detaches an array of objects from the receiver. Closes editor if asked. GNUstep extension.
 */
- (void) detachObjects: (id)anObject closeEditors: (BOOL)close_editor;

/**
 * The path of the file which represents the document.
 */
- (NSString*) documentPath;

/**
 * Called when an editor is closed.
 */
- (void) editor: (id<IBEditors>)anEditor didCloseForObject: (id)anObject;

/**
 * Returns the associated editor for anObject, if flag is YES, it will
 * create an instance of the editor class if one does not already exist
 * for the given object.
 */
- (id<IBEditors>) editorForObject: (id)anObject
			   create: (BOOL)flag;

/**
 * Returns the associated subeditor for anObject, if flag is YES, it will
 * create an instance of the editor.
 */
- (id<IBEditors>) editorForObject: (id)anObject
			 inEditor: (id<IBEditors>)anEditor
			   create: (BOOL)flag;

/**
 * Returns the name associated with the object.
 */
- (NSString*) nameForObject: (id)anObject;

/** 
 * Returns the object for the given aName.
 */
- (id) objectForName: (NSString*)aName;

/**
 * Returns all objects in the receiver's name table.
 */
- (NSArray*) objects;

/**
 * Creates an editor, if necessary using editorForObject:create:, opens it
 * and brings the window containing the editor to the front.
 */
- (id<IBEditors>) openEditorForObject: (id)anObject;

/**
 * Returns the parent of the given editor.
 */
- (id<IBEditors, IBSelectionOwners>) parentEditorForEditor: (id<IBEditors>)anEditor;

/**
 * Return the parent of anObject.  The File's Owner is the root object in the
 * hierarchy, if anObject's parent is the Files's Owner, this method should return
 * nil.
 */
- (id) parentOfObject: (id)anObject;

/**
 * Pastes the given type from the aPasteboard.
 */
- (NSArray*) pasteType: (NSString*)aType
	fromPasteboard: (NSPasteboard*)aPasteboard
		parent: (id)parent;

/** 
 * Remove aConnector from the receiver.
 */
- (void) removeConnector: (id<IBConnectors>)aConnector;

/**
 * The current editor wants to give up the selection, this method iterates
 * over all editors and determines if any editors will take over the selection.
 * If one is found it is activated.
 */
- (void) resignSelectionForEditor: (id<IBEditors>)editor;

/**
 * Set aName for object in the receiver.  This replaces any name the object
 * may have previously had.
 */
- (void) setName: (NSString*)aName forObject: (id)object;

/**
 * Sets the currently selected object from the given editor.
 */
- (void) setSelectionFromEditor: (id<IBEditors>)anEditor;

/**
 * Mark document as having been changed.	
 */
- (void) touch;		

////  PRIVATE
/**
 * Returns a string with the name of the class for the given object.
 */

- (NSString *) classForObject: (id)obj;
- (NSArray *) actionsOfClass: (NSString *)className;
- (NSArray *) outletsOfClass: (NSString *)className;

@end

#endif
