/* GormShelfPref.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Gregory Casamento <greg_casamento@yahoo.com>
 * Date: February 2004
 *
 * This class is heavily based on work done by Enrico Sersale
 * on ShelfPref.m for GWorkspace.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef INCLUDED_GormPrefController_h
#define INCLUDED_GormPrefController_h

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

@interface GormPrefController : NSObject
{
  id panel;
  id popup;
  id prefBox;

  id _generalView;
  id _headersView;
  id _shelfView;
  id _colorsView;
  id _palettesView;
  id _pluginsView;
  id _guidelineView;
}

/**
 * Called when the popup is used to select a pref panel.
 */
- (void) popupAction: (id)sender;

/**
 * Return the preferences panel.
 */
- (id) panel;
@end

#endif
