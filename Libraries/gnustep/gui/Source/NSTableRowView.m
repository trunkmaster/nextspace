/* Implementation of class NSTableRowView
   Copyright (C) 2022 Free Software Foundation, Inc.

   By: Gregory John Casamento
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

#import "AppKit/NSTableRowView.h"

@implementation NSTableRowView

- (BOOL) isEmphasized
{
  return _emphasized;
}

- (void) setEmphasized: (BOOL)flag
{
  _emphasized = flag;
}

- (NSBackgroundStyle) interiorBackgroundStyle
{
  return _interiorBackgroundStyle;
}

- (BOOL) isFloating
{
  return _floating;
}

- (void) setFloating: (BOOL)flag
{
  _floating = flag;
}

- (BOOL) isSelected
{
  return _selected;
}

- (void) setSelected: (BOOL)flag
{
  _selected = flag;
}

- (NSTableViewSelectionHighlightStyle) selectionHighlightStyle
{
  return _selectionHighlightStyle;
}

- (void) setSelectionHighlightStyle: (NSTableViewSelectionHighlightStyle) selectionHighlightStyle
{
  _selectionHighlightStyle = selectionHighlightStyle;
}

- (NSTableViewDraggingDestinationFeedbackStyle) draggingDestinationFeedbackStyle
{
  return _draggingDestinationFeedbackStyle;
}

- (void) setTableViewDraggingDestinationFeedbackStyle: (NSTableViewDraggingDestinationFeedbackStyle) draggingDestinationFeedbackStyle
{
  _draggingDestinationFeedbackStyle = draggingDestinationFeedbackStyle;
}

- (CGFloat) indentationForDropOperation
{
  return _indentationForDropOperation;
}

- (void) setIndentationForDropOperation: (CGFloat)indentationForDropOperation
{
  _indentationForDropOperation = indentationForDropOperation;
}

- (BOOL) targetForDropOperation
{
  return _targetForDropOperation;
}

- (void) setTargetForDropOperation: (BOOL)flag
{
  _targetForDropOperation = flag;
}

- (BOOL) groupRowStyle
{
  return _groupRowStyle;
}

- (void) setGroupRowStyle: (BOOL)flag
{
  _groupRowStyle = flag;
}

- (NSInteger) numberOfColumns
{
  return 0;
}

- (NSColor *) backgroundColor
{
  return _backgroundColor;
}

- (void) setBackgroundColor: (NSColor *)color
{
  ASSIGN(_backgroundColor, color);
}

- (void) drawBackgroundInRect: (NSRect)dirtyRect
{
}

- (void) drawDraggingDestinationFeedbackInRect: (NSRect)dirtyRect
{
}

- (void) drawSelectionInRect: (NSRect)dirtyRect
{
}

- (void) drawSeparatorInRect: (NSRect)dirtyRect
{
}

- (id) viewAtColumn: (NSInteger)column
{
  return nil;
}

- (BOOL) isNextRowSelected
{
  return _nextRowSelected;
}

- (void) setNextRowSelected: (BOOL)flag
{
  _nextRowSelected = flag;
}

- (BOOL) isPreviousRowSelected
{
  return _previousRowSelected;
}

- (void) setPreviousRowSelected: (BOOL)flag
{
  _previousRowSelected = flag;
}

@end
