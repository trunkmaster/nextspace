/* GormClassEditor.h
 *
 * Copyright (C) 1999, 2003, 2005 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2003, 2005
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

#ifndef INCLUDED_GormClassEditor_h
#define INCLUDED_GormClassEditor_h

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include <GormCore/GormOutlineView.h>

@class NSString, NSArray, GormDocument, GormClassManager, NSBrowser;

extern NSString *GormClassPboardType;
extern NSString *GormSwitchViewPreferencesNotification;

@interface GormClassEditor : NSView <IBEditors, IBSelectionOwners>
{
  GormDocument          *document;
  GormClassManager      *classManager;
  NSString              *selectedClass;
  NSScrollView          *scrollView;
  GormOutlineView       *outlineView;
  NSBrowser             *browserView;
  id                     classesView;
  id                     mainView;
  id                     viewToggle;
}
- (GormClassEditor*) initWithDocument: (GormDocument*)doc;
+ (GormClassEditor*) classEditorForDocument: (GormDocument*)doc;
- (void) setSelectedClassName: (NSString*)cn;
- (NSString *) selectedClassName;
- (void) selectClassWithObject: (id)obj editClass: (BOOL)flag;
- (void) selectClassWithObject: (id)obj;
- (void) selectClass: (NSString *)className editClass: (BOOL)flag;
- (void) selectClass: (NSString *)className;
- (BOOL) currentSelectionIsClass;
- (void) editClass;
// - (void) createSubclass;
- (void) addAttributeToClass;
- (void) deleteSelection;
- (NSArray *) fileTypes;

- (void) reloadData;
- (BOOL) isEditing;

- (id) instantiateClass: (id)sender;
- (id) createSubclass: (id)sender;
- (id) loadClass: (id)sender;
- (id) createClassFiles: (id)sender;
- (id) removeClass: (id)sender;
@end

#endif
