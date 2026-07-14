/* IBInspector.h
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

#ifndef INCLUDED_IBINSPECTOR_H
#define INCLUDED_IBINSPECTOR_H

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/IBObjectProtocol.h>

#define	IVH	388	/* Standard height of inspector view.	*/
#define	IVW	272	/* Standard width of inspector view.	*/
#define	IVB	40	/* Standard height of buttons area.	*/

// forward references
@class NSWindow;
@class NSButton;
@class NSString;
@class NSView;
@class NSNotification;

@interface IBInspector : NSObject
{
  id		object;
  NSWindow	*window;
  NSButton	*okButton;
  NSButton	*revertButton;
}

/**
 * Releases all the instance variables (apart from the window, which is
 * presumed to release itself when closed) and removes self as an observer
 * of notifications before destroying self.
 */
- (void) dealloc;

/** 
 * The first view to be selected in the inspector.
 */
- (NSView*) initialFirstResponder;

/**
 * The object being inspected.
 */
- (id) object;

/**
 * Action to take when user clicks the OK button
 */
- (void) ok: (id)sender;

/**
 * Inspector supplied button - the inspectors manager will position this
 * button for you.
 */
- (NSButton*) okButton;

/**
 * Action to take when user clicks the revert button
 */
- (void) revert: (id)sender;

/**
 * Inspector supplied button - the inspectors manager will position this
 * button for you.
 */
- (NSButton*) revertButton;

/**
 * Extension - not in NeXTstep - this message is sent to your inspector to
 * tell it to set its edited object and make any changes to its UI needed.
 */
- (void) setObject: (id)anObject;

/**
 * Used to take notice of textfields in inspector being updated.
 */
- (void) textDidBeginEditing: (NSNotification*)aNotification;

/**
 * Method to mark the inspector as needing saving (ok or revert).
 */
- (void) touch: (id)sender;

/**
 * If this method returns YES, the manager will partition off a section of
 * the inspector panel for display of 'ok' and 'revert' buttons, which
 * your inspector must supply.
 */
- (BOOL) wantsButtons;

/**
 * The window that the UI of the inspector exists in.
 */
- (NSWindow*) window;
@end

#endif

