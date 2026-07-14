/*
   GormMenuItemAttributesInspector.h

   Copyright (C) 1999-2005 Free Software Foundation, Inc.

   Author:  Richard frith-Macdonald (richard@brainstorm.co.uk>
   Date: 1999
   
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


#ifndef INCLUDED_GormMenuItemAttributesInspector_h_
#define INCLUDED_GormMenuItemAttributesInspector_h_

#include <InterfaceBuilder/InterfaceBuilder.h>

@class NSTextField, NSPopUpButton, NSMatrix;

@interface GormMenuItemAttributesInspector : IBInspector
{
  NSTextField	*titleText;
  NSTextField	*shortCut;
  NSTextField	*tagText;
  NSPopUpButton *keyPopup;
  NSMatrix	*keyType;
  id             altBtn;
  id             ctrlBtn;
  id             shiftBtn;
  id             cmdBtn;
  NSString      *upString;
  NSString      *dnString;
  NSString      *ltString;
  NSString      *rtString;
}
@end

#endif
