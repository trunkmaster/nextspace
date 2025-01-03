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

#import <DesktopKit/NXTBundle.h>
#import <SystemKit/OSEDefaults.h>

#import "ModuleLoader.h"
#import "Viewers/Viewer.h"
#import "Preferences/PrefsModule.h"

@interface ModuleLoader (Private)
- (void)loadViewers;
- (void)loadPreferences;
@end

@implementation ModuleLoader (Private)

- (void)loadViewers
{
  NXTBundle *ld = [NXTBundle shared];

  ASSIGN(viewerBundles, [ld loadBundlesOfType:@"viewer"
                                     protocol:@protocol(Viewer)
                                  inDirectory:[[NSBundle mainBundle] bundlePath]]);
}

- (void)loadPreferences
{
  NSArray *bundles;
  NSBundle *bndl;
  NSEnumerator *e;
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  bundles = [[NXTBundle shared] loadBundlesOfType:@"wsprefs"
                                         protocol:@protocol(PrefsModule)
                                      inDirectory:[[NSBundle mainBundle] bundlePath]];

  e = [bundles objectEnumerator];
  while ((bndl = [e nextObject]) != nil) {
    id<PrefsModule> module;

    module = [[[bndl principalClass] new] autorelease];
    [dict setObject:module forKey:[module moduleName]];
  }

  preferences = [dict copy];
}

@end

@implementation ModuleLoader

static ModuleLoader *shared = nil;

+ shared
{
  if (shared == nil) {
    shared = [self new];
  }
  return shared;
}

- (void)dealloc
{
  NSDebugLLog(@"ModuleLoader", @"ModuleLoader: dealloc");

  TEST_RELEASE(viewerBundles);
  TEST_RELEASE(preferences);

  [super dealloc];
}

- (id<Viewer>)viewerForType:(NSString *)viewerType
{
  Class viewerClass;
  id<Viewer> viewer;

  if (viewerBundles == nil) {
    [self loadViewers];
  }

  for (NSBundle *bundle in viewerBundles) {
    viewerClass = [bundle principalClass];
    if ([[viewerClass viewerType] isEqualToString:viewerType]) {
      viewer = [[viewerClass alloc] init];
      break;
    }
  }

  return [viewer autorelease];
}

- (id<Viewer>)preferredViewer
{
  OSEDefaults *df = [OSEDefaults userDefaults];
  NSString *preferredViewerType;
  id<Viewer> viewer;

  if (viewerBundles == nil) {
    [self loadViewers];
  }

  NSLog(@"Loaded viewers: %lu", [viewerBundles count]);

  if ([viewerBundles count] == 0) {
    return nil;
  }

  preferredViewerType = [df objectForKey:@"PreferredViewer"];
  viewer = [self viewerForType:preferredViewerType];
  if (preferredViewerType != nil && viewer != nil) {
    return viewer;
  } else {
    // no preferred viewer or preferred viewer not available - return
    // the first one available
    return [[[[viewerBundles objectAtIndex:0] principalClass] new] autorelease];
  }

  return nil;
}

- (NSDictionary *)menuViewerInfo
{
  NSMutableDictionary *dict;
  NSEnumerator *e;
  NSBundle *bndl;

  if (viewerBundles == nil) {
    [self loadViewers];
  }

  dict = [NSMutableDictionary dictionary];
  e = [viewerBundles objectEnumerator];
  while ((bndl = [e nextObject]) != nil) {
    Class cls = [bndl principalClass];

    [dict setObject:[cls viewerShortcut] forKey:[cls viewerType]];
  }

  return [dict copy];
}

- (NSDictionary *)preferencesModules
{
  if (preferences == nil) {
    [self loadPreferences];
  }

  return preferences;
}

@end
