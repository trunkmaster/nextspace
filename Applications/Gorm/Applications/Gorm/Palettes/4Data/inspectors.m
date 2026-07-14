/* inspectors - Various inspectors for data elements

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Date: Nov 2001   
   Author:  Gregory Casamento <greg_casamento@yahoo.com>
   Date: Nov 2003,2004,2005
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@implementation	NSTextView (IBObjectAdditions)

- (NSString*) sizeInspectorClassName
{
  return @"GormTextViewSizeInspector";
}

- (NSString*) inspectorClassName
{
  return @"GormTextViewAttributesInspector";
}

- (NSString*) editorClassName
{
  return @"GormTextViewEditor";
}

@end

@implementation	NSDateFormatter (IBObjectAdditions)

- (NSString*) inspectorClassName
{
  return @"GormDateFormatterAttributesInspector";
}

@end

@implementation	NSNumberFormatter (IBObjectAdditions)

- (NSString*) inspectorClassName
{
  return @"GormNumberFormatterAttributesInspector";
}

@end

/*
  IBObjectAdditions category
 */
@implementation	NSImageView (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormImageViewAttributesInspector";
}
@end

