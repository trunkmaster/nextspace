/* GormGuidelinePref.h
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2003, 2005
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

#ifndef INCLUDED_GormGuidelinePref_h
#define INCLUDED_GormGuidelinePref_h

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

@class NSWindow;

@interface GormGuidelinePref : NSObject
{
  NSWindow *window;
  id _view;
  id spacingSlider;
  id currentSpacing;
  id halfSpacing;
  id colorWell;
}
/**
 * View to show in prefs panel.
 */
- (NSView *) view;

/**
 * Called when the guidline preferences are changed.
 */
- (void)ok: (id)sender;

/**
 * Reset to defaults.
 */
- (void)reset: (id)sender;
@end

#endif
