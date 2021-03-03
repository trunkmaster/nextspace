/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2018-2021 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

// Class Description
//
// Represents a Workspace Manager Shelf with icons in it.
//
// Fundamental characteristics of the WMShelf as a subclass of NXTIconView:
// - holds icons of applications and directories with retrievable and
//   restorable state;
// - can temporarily hold multi-selection icon;
// - icons can be moved around the Shelf;
// - dragging icon out removes icon from the Shelf;
// - no persistant visible selection of icons;
// - doesn't accept FirstResponder state.
//

#import <DesktopKit/NXTIconView.h>

@class FileViewer;
@class PathIcon;

@interface WMShelf : NXTIconView
{
  // Dragging
  NXTIconView *draggedSource;
  NSArray    *draggedPaths;
  PathIcon   *draggedIcon;
  NXTIconSlot lastSlotDragEntered;
  NXTIconSlot lastSlotDragExited;
  NSPoint    dragPoint;
  NSUInteger draggedMask;

  BOOL       isRootIconDragged;
}

- (PathIcon *)iconInSlot:(NXTIconSlot)slot;

- (void)checkIfContentsExist;
- (PathIcon *)createIconForPaths:(NSArray *)paths;

/** Instructs the shelf to reconstruct it's contents from the
    provided meta-information dictionary. */
- (void)reconstructFromRepresentation:(NSDictionary *)aDict;
/** Returns a dictionary representation of the shelf's contents, suitable
    to be stored in e.g. a file or the defaults database. */
- (NSDictionary *)storableRepresentation;

// --- Drag and Drop
- (BOOL)acceptsDragFromSource:(id)dSource
                    withPaths:(NSArray *)dPaths;

@end
