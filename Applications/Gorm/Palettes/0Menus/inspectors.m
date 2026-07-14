/* inspectors.m
 *
 * This file defines the mapping between objects and thier editors/inspectors.
 *
 * Copyright (C) 2000 Free Software Foundation, Inc.
 * 
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2005
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@implementation	NSMenu (IBObjectAdditions)

- (NSString*) inspectorClassName
{
  return @"GormMenuAttributesInspector";
}

- (NSString*) editorClassName
{
  return @"GormMenuEditor";
}

/*
 * Method to return the image that should be used to display menus within
 * the matrix containing the objects in a document.
 */
- (NSImage*) imageForViewer
{
  static NSImage	*image = nil;
  if (image == nil)
    {
      NSBundle	*bundle = [NSBundle mainBundle];
      NSString	*path = [bundle pathForImageResource: @"GormMenu"];

      image = [[NSImage alloc] initWithContentsOfFile: path];
    }
  return image;
}

@end

@implementation	NSMenuItem (IBObjectAdditions)

- (NSString*) inspectorClassName
{
  return @"GormMenuItemAttributesInspector";
}

@end
