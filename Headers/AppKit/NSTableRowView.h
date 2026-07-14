/* Definition of class NSTableRowView
   Copyright (C) 2022 Free Software Foundation, Inc.

   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 03-09-2022

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#ifndef _NSTableRowView_h_GNUSTEP_GUI_INCLUDE
#define _NSTableRowView_h_GNUSTEP_GUI_INCLUDE

#import <AppKit/NSTableView.h>
#import <AppKit/NSCell.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

@interface NSTableRowView : NSView
{
  // Display style...
  BOOL _emphasized;
  NSBackgroundStyle _interiorBackgroundStyle;
  BOOL _floating;

  // Row selection...
  BOOL _selected;
  NSTableViewSelectionHighlightStyle _selectionHighlightStyle;

  // Drag and Drop...
  NSTableViewDraggingDestinationFeedbackStyle _draggingDestinationFeedbackStyle;
  CGFloat _indentationForDropOperation;
  BOOL _targetForDropOperation;

  // Row grouping...
  BOOL _groupRowStyle;
  NSInteger _numberOfColumns;

  // Overriding row view display characteristics...
  NSColor *_backgroundColor;

  BOOL _nextRowSelected;
  BOOL _previousRowSelected;
}

- (BOOL) isEmphasized;
- (void) setEmphasized: (BOOL)flag;

- (NSBackgroundStyle) interiorBackgroundStyle;

- (BOOL) isFloating;
- (void) setFloating: (BOOL)flag;

- (BOOL) isSelected;
- (void) setSelected: (BOOL)flag;

- (NSTableViewSelectionHighlightStyle) selectionHighlightStyle;
- (void) setSelectionHighlightStyle: (NSTableViewSelectionHighlightStyle) selectionHighlightStyle;

- (NSTableViewDraggingDestinationFeedbackStyle) draggingDestinationFeedbackStyle;
- (void) setTableViewDraggingDestinationFeedbackStyle: (NSTableViewDraggingDestinationFeedbackStyle) draggingDestinationFeedbackStyle;

- (CGFloat) indentationForDropOperation;
- (void) setIndentationForDropOperation: (CGFloat)indentationForDropOperation;

- (BOOL) targetForDropOperation;
- (void) setTargetForDropOperation: (BOOL)flag;

- (BOOL) groupRowStyle;
- (void) setGroupRowStyle: (BOOL)flag;

- (NSInteger) numberOfColumns;

- (NSColor *) backgroundColor;
- (void) setBackgroundColor: (NSColor *)color;

- (void) drawBackgroundInRect: (NSRect)dirtyRect;

- (void) drawDraggingDestinationFeedbackInRect: (NSRect)dirtyRect;

- (void) drawSelectionInRect: (NSRect)dirtyRect;

- (void) drawSeparatorInRect: (NSRect)dirtyRect;

- (id) viewAtColumn: (NSInteger)column;

- (BOOL) isNextRowSelected;
- (void) setNextRowSelected: (BOOL)flag;

- (BOOL) isPreviousRowSelected;
- (void) setPreviousRowSelected: (BOOL)flag;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSTableRowView_h_GNUSTEP_GUI_INCLUDE */
