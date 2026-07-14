#ifndef __INCLUDED_GormDocumentWindow_h
/* GormDocumentWindow.h
 *
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author:      Matt Rice <ratmice@gmail.com>
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

@interface GormDocumentWindow : NSWindow
{
  id _document;
  IBResourceManager *dragMgr;
}
- (void) setDocument:(id)document;
@end

#define __INCLUDED_GormDocumentWindow_h
#endif
