/* GormWindowEditor.h
 *
 * Copyright (C) 1999,2004,2005 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004,2005
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

#ifndef INCLUDED_GormWindowEditor_h
#define INCLUDED_GormWindowEditor_h

#include <InterfaceBuilder/InterfaceBuilder.h>

#include <GormCore/GormViewWithContentViewEditor.h>

@class NSMutableArray, NSString, NSView, NSPasteboard;

@interface GormWindowEditor : GormViewWithContentViewEditor
{
  NSView                *edit_view;
  NSMutableArray	*subeditors;
  BOOL			isLinkSource;
  NSPasteboard		*dragPb;
  NSString		*dragType;
}
/**
 * Returns YES, if the reciever accepts any of the pasteboard items in types.
 */
- (BOOL) acceptsTypeFromArray: (NSArray*)types;

/**
 * Activates the editor
 */
- (BOOL) activate;

/**
 * Instantiate with anObject in the document aDocument.
 */
- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument;

/**
 * Change the font.
 */
- (void) changeFont: (id) sender;

/**
 * Close the editor.  This will also call the deactivate method.
 */
- (void) close;

/**
 * Close any and all editors which are subordinate to this one.
 */ 
- (void) closeSubeditors;

/**
 * Deactivate the editor.
 */ 
- (void) deactivate;

/**
 * Delete the current selection.
 */
- (void) deleteSelection;

/**
 * Return the document which the object the receiver is edited is located in.
 */
- (id<IBDocuments>) document;

/**
 * Call with success or failure of the drag operation.
 */ 
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f;

/**
 * Returns NSDragOperationNone.
 */
- (NSUInteger) draggingSourceOperationMaskForLocal: (BOOL)flag;

/**
 * Make current selection visible.
 */
- (void) makeSelectionVisible: (BOOL)flag;

- (id<IBEditors>) openSubeditorForObject: (id)anObject;

/**
 * Order the edited window to the front.
 */
- (void) orderFront;

/**
 * Paste from pasteboard.
 */
- (void) pasteInSelection;

/**
 * Reset object, redisplays the window.
 */
- (void) resetObject: (id)anObject;
@end

#endif
