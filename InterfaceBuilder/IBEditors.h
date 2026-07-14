/* IBEditors.h
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

#ifndef INCLUDED_IBEDITORS_H
#define INCLUDED_IBEDITORS_H

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/IBSystem.h>

// forward references
@class NSString;
@class NSArray;
@class NSWindow;

/*
 * Notification for editing and inspecting the objects etc.
 */
IB_EXTERN NSString *IBAttributesChangedNotification;
IB_EXTERN NSString *IBInspectorDidModifyObjectNotification;
IB_EXTERN NSString *IBSelectionChangedNotification;
IB_EXTERN NSString *IBClassNameChangedNotification;

/**
 * The IBSelectionOwners protocol defines the methods that a selection owner
 * must implement.
 */
@protocol IBSelectionOwners <NSObject>
/**
 * The number of currently selected objects.
 */
- (NSUInteger) selectionCount;

/**
 * Return the selection in an array.
 */
- (NSArray*) selection;

/**
 * Draw the selection.
 */
- (void) drawSelection;

/**
 * This method is used to draw or remove markup that identifies selected
 * objects within the object being edited.
 */
- (void) makeSelectionVisible: (BOOL)flag;

/**
 * This method changes the current selection to those objects in the array.
 */
- (void) selectObjects: (NSArray*)objects;

/**
 * This method places the current selection from the editor on the pasteboard.
 */
- (void) copySelection;

@end

/**
 * The IBEditors protocol defines the methods an editor must implement. 
 */
@protocol IBEditors <NSObject>
/**
 * Decide whether an editor can accept data from the pasteboard.
 */
- (BOOL) acceptsTypeFromArray: (NSArray*)types;

/**
 * Activate an editor - inserts it into the view hierarchy or whatever is
 * needed for the editor to be able to provide its functionality.
 * This method should be called by the document when an editor is created
 * or opened.  It should be safe to call repeatedly.
 */
- (BOOL) activate;

/**
 * Initializes the editor with object for the specified document.
 */
- (id) initWithObject: (id)anObject inDocument: (id/*<IBDocuments>*/)aDocument;

/**
 * Close an editor - this destroys the editor.  In this method the editor
 * should tell its document that it has been closed, so that the document
 * can remove all its references to the editor.
 */
- (void) close;

/**
 * Close all subeditors associated with this editor.
 */
- (void) closeSubeditors;

/**
 * Deactivate an editor - removes it from the view hierarchy so that objects
 * can be archived without including the editor.
 * This method should be called automatically by the 'close' method.
 * It should be safe to call repeatedly.
 */
- (void) deactivate;

/**
 * This method deletes all the objects in the current selection in the editor.
 */
- (void) deleteSelection;

/**
 * This method returns the document that owns the object that the editor edits.
 */
- (id /*<IBDocuments>*/) document;

/**
 * This method returns the object that the editor is editing.
 */
- (id) editedObject;

/**
 * This method is used to ensure that the editor is visible on screen.
 */
- (void) orderFront;

/**
 * Opens the subeditor for an object when the object being edited is
 * double clicked by the user.  If there is no sub-editor, return nil, otherwise
 * method will return the editor for the object.
 */
- (id<IBEditors>) openSubeditorForObject: (id)object;

/**
 * This method is used to add the contents of the pasteboard to the current
 * selection of objects within the editor.
 */
- (void) pasteInSelection;

/**
 * Redraws the edited object
 */
- (void) resetObject: (id)anObject;

/**
 * When an editor resigns the selection ownership, all editors are asked if
 * they want selection ownership, and the first one to return YES gets made
 * into the current selection owner.
 */
- (BOOL) wantsSelection;

/**
 * Causes the editor to select the text being edited in the current text
 * field.
 */
- (void) validateEditing;

/**
 * This returns the window in which the editor is drawn.
 */
- (NSWindow*) window;
@end

#endif
