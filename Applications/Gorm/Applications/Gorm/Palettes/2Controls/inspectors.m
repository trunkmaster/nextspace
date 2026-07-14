/* inspectors - Various inspectors for control elements

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
              Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001
   
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

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormButtonAttributesInspector.h"
#include "GormStepperAttributesInspector.h"

@implementation	NSButton (IBObjectAdditions)
- (NSString*) editorClassName
{
  return @"GormButtonEditor";
}

- (NSString*) inspectorClassName
{
  return @"GormButtonAttributesInspector";
}
@end

@implementation	NSButtonCell (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormButtonCellAttributesInspector";
}
@end

@implementation	NSStepper (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormStepperAttributesInspector";
}
@end

@implementation	NSStepperCell (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormStepperCellAttributesInspector";
}
@end



