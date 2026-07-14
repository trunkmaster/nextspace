/* GormPrefs.h
*
* Copyright (C) 2019 Free Software Foundation, Inc.
*
* Author:  Lars Sonchocky-Helldorf
* Date:  01.11.19
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

#import <Foundation/Foundation.h>

#ifndef GNUSTEP
//! Project version number for GormPrefs.
FOUNDATION_EXPORT double GormPrefsVersionNumber;

//! Project version string for GormPrefs.
FOUNDATION_EXPORT const unsigned char GormPrefsVersionString[];
#endif

#ifndef INCLUDED_GORMPREFS_H
#define INCLUDED_GORMPREFS_H
 
#include <GormCore/GormGeneralPref.h>
#include <GormCore/GormGuidelinePref.h>
#include <GormCore/GormHeadersPref.h>
#include <GormCore/GormPalettesPref.h>
#include <GormCore/GormPluginsPref.h>
#include <GormCore/GormPrefController.h>
#include <GormCore/GormShelfPref.h>

#endif
