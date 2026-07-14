/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2005-2014 Free Software Foundation

   Authors: Serg Stoyan

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

#ifndef _CodeEditor_h_
#define _CodeEditor_h_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@protocol CodeEditor <NSObject>

// ===========================================================================
// ==== Initialization
// ===========================================================================
- (void)setParser:(id)parser;

// Usually delegate is PCEditorManager or PCEditorManager
- (id)openFileAtPath:(NSString *)filePath
       editorManager:(id)editorManager
	    editable:(BOOL)editable;

- (void)show;
- (void)setWindowed:(BOOL)yn;
- (BOOL)isWindowed;

// ===========================================================================
// ==== Accessor methods
// ===========================================================================
- (id)editorManager;

- (NSWindow *)editorWindow;
- (NSView *)editorView;
- (NSView *)componentView;

- (NSString *)path;
- (void)setPath:(NSString *)path;

- (NSString *)categoryPath;
- (void)setCategoryPath:(NSString *)path;

- (BOOL)isEdited;
- (void)setIsEdited:(BOOL)yn;

- (NSImage *)fileIcon;

// Returns class or method names
- (NSArray *)browserItemsForItem:(NSString *)item;

// ===========================================================================
// ==== Object managment
// ===========================================================================
- (BOOL)saveFileIfNeeded;
- (BOOL)saveFile;
- (BOOL)saveFileTo:(NSString *)path;
- (BOOL)revertFileToSaved;
- (BOOL)closeFile:(id)sender save:(BOOL)save;
- (BOOL)close:(id)sender;
   
// ===========================================================================
// ==== Parser and scrolling
// ===========================================================================

- (void)fileStructureItemSelected:(NSString *)item;
- (void)scrollToLineNumber:(NSUInteger)lineNumber;

@end

#endif
