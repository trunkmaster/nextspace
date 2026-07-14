/* GormFunctions.h
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004
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

#ifndef	INCLUDED_GormFunctions_h
#define	INCLUDED_GormFunctions_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// find all subitems for the given items...
void findAllWithArray(id item, NSMutableArray *array);

// find all sub items for the selections...
NSArray* findAllSubmenus(NSArray *array);

// find all items in the menu...
NSArray* findAll(NSMenu *menu);

// all subviews for the view provided
void subviewsForView(NSView *view, NSMutableArray *array);

// all subviews
NSArray *allSubviews(NSView *view);

// cut the file label to the appropriate length...
NSString *cutFileLabelText(NSString *filename, id label, NSInteger length);

// get the cell size for all editors
NSSize defaultCellSize();

// color from string
NSColor *colorFromDict(NSDictionary *colorString);

// color to string
NSDictionary *colorToDict(NSColor *color);

// get the list of images...
NSArray *systemImagesList();

// get the list of images...
NSArray *systemSoundsList();

// compute the gorm version
int appVersion(long a, long b, long c);

// prompt for a class name.  Used mainly for gmodel loading...
NSString *promptForClassName(NSString *title, NSArray *classes);

// format an identifier..
NSString *identifierString(NSString *str);

// format an action..
NSString *formatAction(NSString *action);

// format an outlet
NSString *formatOutlet(NSString *outlet);

// get information about class.
NSArray *_GSObjCMethodNamesForClass(Class class, BOOL collect);

NSArray *_GSObjCVariableNames(Class class, BOOL collect);

NSRect minimalContainerFrame(NSArray *views);
#endif
