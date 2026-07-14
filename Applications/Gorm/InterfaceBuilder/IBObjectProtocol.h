/* IBObjectAdditions.h
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

#ifndef INCLUDED_IBOBJECTPROTOCOL_H
#define INCLUDED_IBOBJECTPROTOCOL_H

#include <InterfaceBuilder/IBDocuments.h>

@protocol IBObjectProtocol
/**
 * Returns YES, if receiver can be displayed in 
 * the custom custom class inspector as a potential
 * class which can be switched to by the receiver.
 */
+ (BOOL)canSubstituteForClass: (Class)origClass;

/**
 * Called immediate after loading the document into
 * the interface editor application.
 */
- (void)awakeFromDocument: (id <IBDocuments>)doc;

/**
 * Returns the NSImage to be used to represent an object
 * of the receiver's class in the editor.
 */
- (NSImage *)imageForViewer;

/**
 * Label for the receiver in the model.
 */
- (NSString *)nibLabel: (NSString *)objectName;

/**
 * Title to display in the inspector.
 */
- (NSString *)objectNameForInspectorTitle;

/**
 * Name of attributes inspector class.
 */
- (NSString*) inspectorClassName;

/**
 * Name of connection inspector class.
 */
- (NSString*) connectInspectorClassName;

/**
 * Name of size inspector.
 */
- (NSString*) sizeInspectorClassName;

/**
 * Name of help inspector.
 */ 
- (NSString*) helpInspectorClassName;

/**
 * Name of class inspector.
 */
- (NSString*) classInspectorClassName;

/**
 * Name of the editor for the receiver.
 */
- (NSString*) editorClassName;

/**
 * List of properties not compatible with interface app.
 */
- (NSArray*) ibIncompatibleProperties;
@end

#endif
