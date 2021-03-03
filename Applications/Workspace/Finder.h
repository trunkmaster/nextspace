/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014-2021 Sergii Stoian
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

#import <AppKit/AppKit.h>

#import "WMShelf.h"

@class FileViewer;

@interface Finder : NSObject
{
  FileViewer *fileViewer;
  
  WMShelf	*shelf;
  id		window;
  NSImage       *findButtonImage;
  id		findButton;
  id		findField;
  id		findScopeButton;
  id		statusField;
  id		resultList;
  id		resultsFound;
  id		resultIcon;
  id		iconPlace;

  NSOperationQueue *operationQ;
  NSMutableArray   *variantList;
  NSInteger        resultIndex;

  // Shelf
  NSSet *savedSelection;
}

- (id)initWithFileViewer:(FileViewer *)fv;
- (void)setFileViewer:(FileViewer *)fv;
  
- (void)activateWithString:(NSString *)searchString;
- (void)deactivate;
- (NSWindow *)window;

- (void)addResult:(NSString *)resultString;
- (void)finishFind;

@end

@interface Finder (Worker)
- (void)runWorkerWithPaths:(NSArray *)searchPaths
                expression:(NSRegularExpression *)regexp;
@end

@interface Finder (Shelf)
- (void)restoreShelf;
- (NSArray *)storableShelfSelection;
- (void)reconstructShelfSelection:(NSArray *)selectedSlots;
- (void)resignShelfSelection;
- (void)restoreShelfSelection;
@end
