/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description: Browser viewer.
//
// Copyright (C) 2005 Saso Kiselkov
// Copyright (C) 2014-2019 Sergii Stoian
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

#include <AppKit/AppKit.h>

#import <Viewers/FileViewer.h>
#import <Viewers/Viewer.h>

@interface BrowserViewer : NSObject <Viewer>
{
  id bogusWindow;
  id view;

  FileViewer    *fileViewer;

  NSFileManager *fileManager;
  NSString      *rootPath;
  NSString      *currentPath;
  NSArray       *selection;

  NSRange displayedRange;

  CGFloat    columnWidth;
  NSUInteger columnCount;
  unsigned   numVerts;
}

- (NSArray*) selectedPaths;

- (void)reloadColumn:(NSUInteger)col;
- (void)reloadLastColumn;

- (void)doClick:(id)sender;
- (void)doDoubleClick:(id)sender;

@end
