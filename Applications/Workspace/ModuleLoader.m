/*
   ModuleLoader.m
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

#import <NXFoundation/NXBundle.h>
#import <NXFoundation/NXDefaults.h>

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
  NXBundle *ld = [NXBundle shared];

  ASSIGN(viewerBundles,
         [ld loadBundlesOfType:@"viewer"
                      protocol:@protocol(Viewer)
                   inDirectory:[[NSBundle mainBundle] bundlePath]]);
}

- (void)loadPreferences
{
  NSArray             *bundles;
  NSBundle            *bndl;
  NSEnumerator        *e;
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  bundles = [[NXBundle shared]
              loadBundlesOfType:@"wsprefs"
                       protocol:@protocol(PrefsModule)
                    inDirectory:[[NSBundle mainBundle] bundlePath]];

  e = [bundles objectEnumerator];
  while ((bndl = [e nextObject]) != nil)
    {
      id <PrefsModule> module;

      module = [[[bndl principalClass] new] autorelease];
      [dict setObject:module forKey:[module moduleName]];
    }

  preferences = [dict copy];
}

@end

@implementation ModuleLoader

static ModuleLoader * shared = nil;

+ shared
{
  if (shared == nil) {
    shared = [self new];
  }
  return shared;
}

- (void) dealloc
{
  NSDebugLLog(@"ModuleLoader", @"ModuleLoader: dealloc");

  TEST_RELEASE(viewerBundles);
  TEST_RELEASE(preferences);

  [super dealloc];
}

- (id <Viewer>)viewerForType:(NSString *)viewerType
{
  Class      viewerClass;
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

- (id <Viewer>)preferredViewer
{
  NXDefaults  *df = [NXDefaults userDefaults];
  NSString    *preferredViewerType;
  id <Viewer> viewer;

  if (viewerBundles == nil)
    {
      [self loadViewers];
    }

  NSLog(@"Loaded viewers: %lu", [viewerBundles count]);

  if ([viewerBundles count] == 0)
    {
      return nil;
    }

  preferredViewerType = [df objectForKey: @"PreferredViewer"];
  viewer = [self viewerForType:preferredViewerType];
  if (preferredViewerType != nil && viewer != nil)
    {
      return viewer;
    }
  else
    {
      // no preferred viewer or preferred viewer not available - return
      // the first one available
      return [[[[viewerBundles objectAtIndex: 0] 
                 principalClass] new] autorelease];
    }

  return nil;
}

- (NSDictionary *)menuViewerInfo
{
  NSMutableDictionary * dict;
  NSEnumerator * e;
  NSBundle * bndl;

  if (viewerBundles == nil) {
    [self loadViewers];
  }

  dict = [NSMutableDictionary dictionary];
  e = [viewerBundles objectEnumerator];
  while ((bndl = [e nextObject]) != nil)
    {
      Class cls = [bndl principalClass];

      [dict setObject: [cls viewerShortcut]
               forKey: [cls viewerType]];
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
