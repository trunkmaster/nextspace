/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2004 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _PCProjectBrowser_h_
#define _PCProjectBrowser_h_

#import <AppKit/AppKit.h>

extern NSString *PCBrowserDidSetPathNotification;

@class PCProject;

@interface PCProjectBrowser : NSObject
{
  PCProject *project;
  NSBrowser *browser;
}

// ============================================================================
// ==== Intialization & deallocation
// ============================================================================

- (id)initWithProject:(PCProject *)aProject;
- (void)dealloc;

// ============================================================================
// ==== Accessory methods
// ============================================================================
- (NSView *)view;

// Returns nil if multiple files selected
- (NSString *)nameOfSelectedFile;
- (NSString *)pathToSelectedFile;

// Returns nil if multiple categories selected
- (NSString *)nameOfSelectedCategory;
- (NSString *)pathToSelectedCategory;
- (NSString *)pathFromSelectedCategory;

- (NSString *)nameOfSelectedRootCategory;

// Returns nil if multiple category selected
- (NSArray *)selectedFiles;

- (NSString *)path;
- (BOOL)setPath:(NSString *)path;
- (void)reloadLastColumnAndNotify:(BOOL)yn;
- (void)reloadLastColumnAndSelectFile:(NSString *)file;

// ============================================================================
// ==== Actions
// ============================================================================
- (void)click:(id)sender;
- (void)doubleClick:(id)sender;

// ============================================================================
// ==== Notifications
// ============================================================================
- (void)projectDictDidChange:(NSNotification *)aNotif;

@end

@interface PCProjectBrowser (ProjectBrowserDelegate)

- (void)browser:(NSBrowser *)sender createRowsForColumn:(NSInteger)column 
                                               inMatrix:(NSMatrix *)matrix;

@end

#endif
