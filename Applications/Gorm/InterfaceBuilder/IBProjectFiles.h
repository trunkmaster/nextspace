/* IBProjectFiles.h
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2003
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

#ifndef INCLUDED_IBPROJECTFILES_H
#define INCLUDED_IBPROJECTFILES_H

#include <InterfaceBuilder/IBProjects.h>

@class NSString;

@protocol IBProjectFiles <NSObject>
/**
 * The file name.
 */
- (NSString *) fileName;

/**
 * The file type for this file.
 */
- (NSString *) fileType;

/**
 * Returns YES, if the file is localized, NO if it's simply in Resources.
 */
- (BOOL) isLocalized;

/**
 * The language 
 */
- (NSString *) language;

/**
 * The path for the file.
 */
- (NSString *) path;

/**
 * The project to which this file belongs.
 */
- (id<IBProjects>) project;
@end

#endif
