/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2017 Free Software Foundation

   Author: Philippe C.D. Robert <probert@siggraph.org>
           Riccardo Mottola

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

#ifndef _PROJECTTYPE_H
#define _PROJECTTYPE_H

/*
  Description: A ProjectType is used to create a project of a certain type. 
               With this approach this procedure can be implemented as a bundle 
 	       and therefore PC remains open for future extensions!

               Options are used to further customize types.
*/

#import <Foundation/Foundation.h>

@class PCProject;

static NSString* const PCProjectInterfaceGorm = @"GormInterface";
static NSString* const PCProjectInterfaceRenaissance = @"RenaissanceInterface";

@protocol ProjectType

- (PCProject *)createProjectAt:(NSString *)path withOption:(NSString *)option;

@end

#endif
