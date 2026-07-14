/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2021 Free Software Foundation

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _PCINFOCONTROLLER_H
#define _PCINFOCONTROLLER_H

#import <AppKit/AppKit.h>

@interface PCInfoController : NSObject
{
  id infoWindow;
  IBOutlet NSTextField* versionField;
  IBOutlet NSTextField* copyrightField;
  NSDictionary *infoDict;
}

- (id)init;
- (void)dealloc;

- (void)showInfoWindow:(id)sender;

@end

#endif
