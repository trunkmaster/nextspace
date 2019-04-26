/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description: FileViewer path view implementation
//
// Copyright (C) 2015-2019 Sergii Stoian
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

#import <NXAppKit/NXIconView.h>

@class NSArray, NSString, NSImage;
@class PathIcon;
@class FileViewer;

#define PATH_VIEW_HEIGHT 76.0

@interface PathView : NXIconView
{
  FileViewer *_owner;

  NSString *_path;
  NSArray  *_files;
  NSArray  *_iconDragTypes;
  PathIcon *_multiIcon;
  NSImage  *_multiImage;
  NSImage  *_arrowImage;
  
  // Dragging
  NXIconView *_dragSource;
  PathIcon   *_dragIcon;
  unsigned   _dragMask;
}

- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer;

- (void)setPath:(NSString *)relativePath selection:(NSArray *)filenames;
- (NSString *)path;
- (NSArray *)files;

- (NSUInteger)visibleColumnCount;
- (void)setNumberOfEmptyColumns:(NSInteger)num;
- (NSInteger)numberOfEmptyColumns;
- (void)syncEmptyColumns;

- (NSArray *)pathsForIcon:(NXIcon *)anIcon;

- (void)constrainScroller:(NSScroller *)aScroller;
- (void)trackScroller:(NSScroller *)aScroller;

@end
