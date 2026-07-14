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

#ifndef INCLUDED_GormNumberFormatterAttributesInspector_h
#define INCLUDED_GormNumberFormatterAttributesInspector_h

#include <InterfaceBuilder/InterfaceBuilder.h>

@interface GormNumberFormatterAttributesInspector : IBInspector
{
  IBOutlet id addThousandSeparatorSwitch;
  IBOutlet id commaPointSwitch;
  IBOutlet id formatForm;
  IBOutlet id formatTable;
  IBOutlet id negativeRedSwitch;
  IBOutlet id detachButton;
  IBOutlet id localizeSwitch;
  IBOutlet id positiveField;
  IBOutlet id negativeField;
  IBOutlet id zeroField;
}
@end

#endif
