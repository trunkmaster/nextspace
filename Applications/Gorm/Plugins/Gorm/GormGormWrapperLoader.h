/* GormNibWrapperLoader
 *
 *
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2006
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
 */

#ifndef GORM_GORMWRAPPERLOADER
#define GORM_GORMWRAPPERLOADER

#include <GormCore/GormCore.h>

@class NSMutableArray, NSString;

@interface GormGormWrapperLoader : GormWrapperLoader
{
  NSMutableArray *_repairLog;
  id message;
  id textField;
  id panel;
}
@end

#endif
