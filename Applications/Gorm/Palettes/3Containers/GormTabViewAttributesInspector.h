/*
  GormTabViewAttributesInspector.h

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: Aug 2001. 2003, 2004
   
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
/*
  July 2005 : Spilt inspector in separate classes.
  Always use ok: revert: methods
  Clean up
  Author : Fabien Vallon <fabien@sonappart.net>
*/


#ifndef	INCLUDED_GormTabViewAttributesInspector_h
#define	INCLUDED_GormTabViewAttributesInspector_h

#include <InterfaceBuilder/InterfaceBuilder.h>

@class NSButton;
@class NSForm;
@class NSMatrix;
@class NSStepper;
@class NSTextField;

@interface GormTabViewAttributesInspector : IBInspector
{
  NSMatrix *typeMatrix;
  int numberOfDisplayItem;
  NSButton *allowtruncate;
  NSTextField *numberOfItemsField;
  NSStepper *itemStepper;
  NSTextField *itemLabel;
  NSForm *itemIdentifier;
  NSButton *itemPrevious;
  NSButton *itemNext;
}
@end

#endif /* INCLUDED_GormTabViewAttributesInspector_h */
