/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014-2021 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <Foundation/Foundation.h>

@protocol Viewer;

@interface ModuleLoader : NSObject
{
  NSArray *viewerBundles;
  NSDictionary *preferences;
}

+ shared;

- (id<Viewer>)viewerForType:(NSString *)viewerType;
- (id<Viewer>)preferredViewer;

// a dict - viewer name is key, viewer shortcut is value
- (NSDictionary *)menuViewerInfo;

// returns a dict with initialized preferences modules - the keys
// are the names of the modules, the values are the modules themselves
- (NSDictionary *)preferencesModules;

@end
