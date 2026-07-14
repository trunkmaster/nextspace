/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2004-2017 Free Software Foundation

   Authors: Serg Stoyan
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

#ifndef _PCAggregateProject_h
#define _PCAggregateProject_h

#import <AppKit/AppKit.h>
#import <ProjectCenter/PCProject.h>
#import <Protocols/ProjectType.h>

@class PCMakefileFactory;

@interface PCAggregateProject : PCProject <ProjectType>
{
  IBOutlet NSBox      *projectAttributesView;

  NSMutableDictionary *infoDict;
}

//----------------------------------------------------------------------------
// Init and free
//----------------------------------------------------------------------------

- (id)init;
- (void)dealloc;

- (PCProject *)createProjectAt:(NSString *)path withOption:projOption;

@end

@interface PCAggregateProject (GeneratedFiles)

- (BOOL)writeMakefile;
- (void)appendHead:(PCMakefileFactory *)mff;
- (void)appendTail:(PCMakefileFactory *)mff;

@end

@interface PCAggregateProject (Inspector)

- (NSView *)projectAttributesView;
- (void)updateInspectorValues:(NSNotification *)aNotif;

@end

#endif
