/* GormInspectorsManager.h
 *
 * Copyright (C) 1999, 2003 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2003
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

#ifndef INCLUDED_GormInspectorsManager_h
#define INCLUDED_GormInspectorsManager_h

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@class NSPanel;
@class NSMutableDictionary;
@class NSPopUpButton;
@class NSView;
@class NSBox;
@class IBInspector;

@interface GormInspectorsManager : IBInspectorManager
{
  IBOutlet NSPanel	 *panel;
  NSMutableDictionary	 *cache;
  IBOutlet NSPopUpButton *popup;
  IBOutlet NSBox	 *selectionView;
  IBOutlet NSBox         *inspectorView;
  NSView		 *buttonView;
  NSString		 *oldInspector;
  IBOutlet IBInspector	 *inspector;
  int			 current;
  BOOL			 hiddenDuringTest;
  NSRect                 origFrame;
}
- (NSPanel*) panel;
- (void) setClassInspector;
- (void) setCurrentInspector: (id)anObject;
- (void) updateSelection;
@end

#endif
