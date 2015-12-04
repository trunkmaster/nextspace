/*
   ModuleLoader.h
   The module loader - a facility for simpler loading of extension modules.

   Copyright (C) 2005 Saso Kiselkov

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <Foundation/Foundation.h>

@protocol Viewer;

@interface ModuleLoader : NSObject
{
        NSArray * viewerBundles;
        NSDictionary * preferences;
}

+ shared;

- (id <Viewer>) viewerForType: (NSString *) viewerType;
- (id <Viewer>) preferredViewer;

 // a dict - viewer name is key, viewer shortcut is value
- (NSDictionary *) menuViewerInfo;

 // returns a dict with initialized preferences modules - the keys
 // are the names of the modules, the values are the modules themselves
- (NSDictionary *) preferencesModules;

@end
