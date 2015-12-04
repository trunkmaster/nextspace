/*
   The icons viewer.

   Copyright (C) 2005 Saso Kiselkov

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/AppKit.h>

#import <Protocols/FileViewer.h>
#import <Protocols/FileSystemInterface.h>
#import <Protocols/Viewer.h>

@class XSIconView, XSIcon, XSIconLabel;

@interface IconsViewer : NSObject <Viewer>
{
  XSIconView   *iconView;
  NSScrollView *view;

  NSString     *currentPath;
  NSArray      *selection;

  id <FileSystemInterface> iface;
  id <FileViewer> owner;

  unsigned int draggingSourceMask;
}

- init;

- (void)dealloc;

- (void)open:(id)sender;

- (void)iconDragged:(id)sender event:(NSEvent *)ev;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
					       icon:(XSIcon *)sender;

 // icon dragging destination
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
			   icon:(XSIcon *)ic;
- (void)draggingExited:(id <NSDraggingInfo>)sender
		  icon:(XSIcon *)icon;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
			   icon:(XSIcon *)anIcon;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
			icon:(XSIcon *)anIcon;

 // icon view dragging destination
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
		       iconView:(XSIconView *)iv;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
                       iconView:(XSIconView *)iconView;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
		    iconView:(XSIconView *)iconView;

- (void)iconSlotWidthChanged:(NSNotification *)notif;

- (void)   iconLabel:(XSIconLabel *)iconLabel
 didChangeStringFrom:(NSString *)oldName
                  to:(NSString *)newName;

@end
