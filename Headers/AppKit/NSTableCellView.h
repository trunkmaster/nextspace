/* Definition of class NSTableCellView
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

#ifndef _NSTableCellView_h_GNUSTEP_GUI_INCLUDE
#define _NSTableCellView_h_GNUSTEP_GUI_INCLUDE

#import <AppKit/NSView.h>
#import <AppKit/NSCell.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSNibDeclarations.h>
#import <AppKit/AppKitDefines.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSNibDeclarations.h>

#import <AppKit/AppKitDefines.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSImageView, NSTextField, NSArray;

APPKIT_EXPORT_CLASS    
@interface NSTableCellView : NSView
{
  id _objectValue;
  IBOutlet NSImageView *_imageView;
  IBOutlet NSTextField *_textField;
  NSArray *_draggingImageComponents;

  NSBackgroundStyle _backgroundStyle;
  NSTableViewRowSizeStyle _rowSizeStyle;
}

- (id) objectValue;
- (void) setObjectValue: (id)objectValue;

- (NSImageView *) imageView;
- (void) setImageView: (NSImageView *)imageView;

- (NSTextField *) textField;
- (void) setTextField: (NSTextField *)textField;

- (NSBackgroundStyle) backgroundStyle;
- (void) setBackgroundStyle: (NSBackgroundStyle)backgroundStyle;

- (NSTableViewRowSizeStyle) rowSizeStyle;
- (void) setRowSizeStyle: (NSTableViewRowSizeStyle) rowSizeStyle;

- (NSArray *) draggingImageComponents;
- (void) setDraggingImageComponents: (NSArray *)draggingImageComponents;  
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSTableCellView_h_GNUSTEP_GUI_INCLUDE */
