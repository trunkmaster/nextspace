/* 
   GormOutlineView.h

   The outline class.
   
   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: July 2002
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#ifndef INCLUDED_GormOutlineView_h
#define INCLUDED_GormOutlineView_h

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

@class NSTableColumn;
@class NSMenuItem;

typedef enum {None, Outlets, Actions} GSAttributeType;

@interface GormOutlineView : NSOutlineView
{
  float _attributeOffset;
  BOOL _isEditing;
  id _itemBeingEdited;
  NSTableColumn *_actionColumn;
  NSTableColumn *_outletColumn;
  GSAttributeType _edittype;
  NSMenuItem *_menuItem;
}

// Instance methods
- (float)attributeOffset;
- (void)setAttributeOffset: (float)offset;
- (id) itemBeingEdited;
- (void) setItemBeingEdited: (id)item;
- (BOOL) isEditing;
- (void) setIsEditing: (BOOL)flag;
- (NSTableColumn *)actionColumn;
- (void) setActionColumn: (NSTableColumn *)ac;
- (NSTableColumn *)outletColumn;
- (void) setOutletColumn: (NSTableColumn *)oc;
- (NSMenuItem *)menuItem;
- (void) setMenuItem: (NSMenuItem *)item;
- (GSAttributeType)editType;
- (void) removeItemAtRow: (int)row;
- (void) reset;
- (void) selectRow: (int)rowIndex;
@end /* interface of GormOutlineView */

// informal protocol to define necessary methods on
// GormOutlineView's data source to make information
// about the class which was selected...
@interface NSObject (GormOutlineViewDataSource)
- (NSArray *) outlineView: (GormOutlineView *)ov
           actionsForItem: (id)item;
- (NSArray *) outlineView: (GormOutlineView *)ov
           outletsForItem: (id)item;
- (void)outlineView: (NSOutlineView *)anOutlineView
	  addAction: (NSString *)action
           forClass: (id)item;
- (void)outlineView: (NSOutlineView *)anOutlineView
	  addOutlet: (NSString *)outlet
           forClass: (id)item;
- (NSString *)outlineView: (NSOutlineView *)anOutlineView
     addNewActionForClass: (id)item;
- (NSString *)outlineView: (NSOutlineView *)anOutlineView
     addNewOutletForClass: (id)item;
@end

@interface NSObject (GormOutlineViewDelegate)
- (BOOL) outlineView: (GormOutlineView *)ov
    shouldDeleteItem: (id)item;
@end

// a class to hold the outlet/actions so that the
// draw row method will know how to render them on
// the display...
@interface GormOutletActionHolder : NSObject
{
  NSString *_name;
}
- initWithName: (NSString *)name;
- (NSString *)getName;
- (void)setName: (NSString *)name;
@end
#endif /* _GNUstep_H_GormOutlineView */
