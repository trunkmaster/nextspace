/* IBProjects.h
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef INCLUDED_IBPROJECTS_H
#define INCLUDED_IBPROJECTS_H

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

@class NSString, NSArray;

@protocol IBProjects <NSObject>

/**
 * Called to retrieve the application icon to be used for the 
 * interface/language combination.
 */
- (id) applicationIconForInterfaceStyle: (NSInterfaceStyle)style 
                             inLanguage: (NSString *)lang;

/**
 * Returns YES, if the file is in the given path.
 */
- (BOOL) containsFileAtPath: (NSString *)path;

/**
 * Returns an array containing the list of files of that filetype
 * in the project.
 */
- (NSArray *) filesForFileType: (NSString *)type;

/**
 * Returns YES, if child is a child of the reciever.
 */
- (BOOL) isAncestorOfProject: (id<IBProjects>) child;

/**
 * Returns YES, if parent is a parent of the receiver.
 */
- (BOOL) isDescendantOfProject: (id<IBProjects>) parent;

/**
 * Is there currently a connection to the project.
 */
- (BOOL) isLive;

/**
 * Returns the language for the file at the given path.
 */
- (NSString *) languageForFileAtPath: (NSString *)path;

/**
 * Returns the nib for the interface/style combination.
 */
- (id) mainNibFileForInterfaceStyle: (NSInterfaceStyle)style
                         inLanguage: (NSString *)lang;

/**
 * Locates and returns the location of filename within the
 * receiver.
 */
- (NSString *) pathForFilename: (NSString *)filename;

/**
 * Returns the full path for the project directory.
 */
- (NSString *) projectDirectory;

/**
 * Returns the project manager object.
 */
- (id) projectManager;

/**
 * The name of the project.
 */
- (NSString *) projectName;

/**
 * The topmost project in the project hierarchy containing the receiver.
 */
- (id<IBProjects>) rootProject;

/**
 * Any and all direct subjects of this project.
 */
- (NSArray *) subprojects;

/**
 * The project which is the direct parent of the receiver.
 */
- (id<IBProjects>) superproject;

@end
#endif
