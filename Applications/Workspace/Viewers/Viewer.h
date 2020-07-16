/* -*- mode: objc -*- */
//
// Project: Workspace viewer module protocol.
//
// Description: Workspace viewer module protocol.
//
// Copyright (C) 2005 Saso Kiselkov
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

@class NSView, NSString, NSArray;

@class FileViewer;

#import <Foundation/NSObject.h>

@protocol Viewer <NSObject>

+ (NSString *)viewerType;
 // viewers without a shortcut should return @"", not `nil'
+ (NSString *)viewerShortcut;

- (NSView *)view;
- (NSView *)keyView;

- (void)setOwner:(FileViewer *)owner;
- (void)setRootPath:(NSString *)rootPath;
- (NSString *)fullPath;
- (NSArray *)selectedPaths;

- (CGFloat)columnWidth;
- (void)setColumnWidth:(CGFloat)width;
- (NSUInteger)columnCount;
- (void)setColumnCount:(NSUInteger)num;
- (void)setNumberOfEmptyColumns:(NSInteger)num;
- (NSInteger)numberOfEmptyColumns;

//-----------------------------------------------------------------------------
// Actions
//-----------------------------------------------------------------------------
- (void)displayPath:(NSString *)dirPath
	  selection:(NSArray *)filenames;

- (void)reloadPathWithSelection:(NSString *)selection; // Reload contents of selected directory
- (void)reloadPath:(NSString *)reloadPath;

- (void)scrollToRange:(NSRange)range;

- (BOOL)becomeFirstResponder;

//-----------------------------------------------------------------------------
// Events
//-----------------------------------------------------------------------------
- (void)currentSelectionRenamedTo:(NSString *)newName;

@end
