/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description: An NXTIcon subclass that implements file operations.
//              PathIcon holds information about object(file, dir) path. Set
//              with setPath: method and saved in 'paths' ivar. Any other
//              optional information (e.g. device for mount point, application,
//              special file attributes) set with setInfo: method and saved in
//              'info' ivar.
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

#import <DesktopKit/DesktopKit.h>

#import <DesktopKit/NXTIcon.h>

@protocol NSDraggingInfo;

@interface PathIcon : NXTIcon
{
  NSArray             *paths;
  NSDictionary        *info;

  unsigned int  draggingMask;
  BOOL          doubleClickPassesClick;
}

// Metainformation getters and setters
- (void)setPaths:(NSArray *)newPaths;
- (NSArray *)paths;
- (void)setInfo:(NSDictionary *)anInfo;
- (NSDictionary *)info;

// Define behaviour of double click.
- (void)setDoubleClickPassesClick:(BOOL)isPass;
- (BOOL)isDoubleClickPassesClick;

// NSDraggingDestination
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end
