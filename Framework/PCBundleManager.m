/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2004 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan

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

// TODO: Finish support for third party bundles.
//       It involves support for user defined bundle directories
//       through preferences. Now supported are:
//       - PC application resource dir
//         (GNUSTEP_SYSTEM_APPS/ProjectCenter.app/Resources)
//       - GNUSTEP_SYSTEM_LIBRARY/Bundles/ProjectCenter
//         (NSApplicationSupportDirectory)

#import <ProjectCenter/PCBundleManager.h>
#import <ProjectCenter/PCDefines.h>

#import <ProjectCenter/PCLogController.h>

@implementation PCBundleManager

//----------------------------------------------------------------------------
// Init and free methods
//----------------------------------------------------------------------------

- (id)init
{
  if ((self = [super init]))
    {
      loadedBundles = [[NSMutableDictionary alloc] init];
      bundlesInfo = [[NSMutableDictionary alloc] init];
    }

  return self;
}

- (void)dealloc
{
  RELEASE(loadedBundles);
  RELEASE(bundlesInfo);

  [super dealloc];
}

//
- (NSString *)resourcePath
{
  NSString *path = [[NSBundle mainBundle] resourcePath];

  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) 
    {
      [NSException raise:@"PCBundleManagerPathException" 
	          format:@"ProjectCenter installed incorrectly"];
      return nil;
    }

  return path;
}

// --- Handling of bundles' Info.table dictionaries without actual
// --- bundles loading

// bundlesInfo is a dictionary. key/value pair is the following:
//  (NSString *)              (NSDictionary *)
// "full path of a bundle" = "Info.table contents"
- (NSDictionary *)infoForBundlesType:(NSString *)extension
{
  NSArray             *bundles;
  NSEnumerator        *enumerator;
  NSString            *bundlePath;
  NSString            *infoTablePath;
  NSDictionary        *infoTable;
  NSMutableDictionary *reqBundlesInfo;

  reqBundlesInfo = [NSMutableDictionary dictionary];
  bundles = [NSBundle pathsForResourcesOfType:extension 
                                  inDirectory:[self resourcePath]];
  enumerator = [bundles objectEnumerator];

  while ((bundlePath = [enumerator nextObject]))
    {
      infoTablePath = [NSString 
	stringWithFormat:@"%@/Resources/Info.table", bundlePath];
      // TODO: fill 'reqBundlesInfo' with element from 'bundlesInfo' if
      // exists
      infoTable = [NSDictionary dictionaryWithContentsOfFile:infoTablePath];
      [reqBundlesInfo setObject:infoTable forKey:bundlePath];
      [bundlesInfo setObject:infoTable forKey:bundlePath];
    }

  return reqBundlesInfo;
}

// Key value can be checked against NSString and NSArray values only.
- (NSDictionary *)infoForBundleType:(NSString *)extension
			    keyName:(NSString *)key
			keyContains:(NSString *)value
{
  NSDictionary *reqBundlesInfo;
  NSEnumerator *enumerator;
  NSString     *bundlePath;
  id           keyValue;
  NSDictionary *infoTable;

  if (extension == nil)
    {
      return nil;
    }

  reqBundlesInfo = [self infoForBundlesType:extension];
  enumerator = [[reqBundlesInfo allKeys] objectEnumerator];

  infoTable = nil;
  while ((bundlePath = [enumerator nextObject]))
    {
      infoTable = [reqBundlesInfo objectForKey:bundlePath];

      if (key == nil || value == nil)
	{
	  break;
	}

      keyValue = [infoTable objectForKey:key];

      if ([keyValue isKindOfClass:[NSString class]] &&
	  [keyValue isEqualToString:value])
	{
	  break;
	}
      else if ([keyValue isKindOfClass:[NSArray class]] &&
	       [keyValue containsObject:value])
	{
	  break;
	}
      else
	{
	  infoTable = nil;
	}
    }

  return infoTable;
}

- (NSDictionary *)infoForBundleName:(NSString *)name
			       type:(NSString *)type
{
  NSDictionary *reqBundlesInfo = [self infoForBundlesType:type];
  NSEnumerator *enumerator = [[reqBundlesInfo allKeys] objectEnumerator];
  NSString     *bundlePath;
  NSDictionary *infoTable;

  infoTable = nil;
  while ((bundlePath = [enumerator nextObject]))
    {
      infoTable = [reqBundlesInfo objectForKey:bundlePath];
      if ([[infoTable objectForKey:@"Name"] isEqualToString:name])
	{
	  break;
	}
      else
	{
	  infoTable = nil;
	}
    }

  return infoTable;
}

- (NSString *)classNameForBundleType:(NSString*)type 
			    fileName:(NSString *)fileName
{
  NSString     *fileExtension = [fileName pathExtension];
  NSDictionary *infoTable = nil;
  NSString     *className = nil;

  infoTable = [self infoForBundleType:type
			      keyName:@"FileTypes"
			  keyContains:fileExtension];

  className = [infoTable objectForKey:@"PrincipalClassName"];

  return className;
}

- (NSString *)bundlePathWithName:(NSString *)bundleName
{
  NSArray      *bundlePaths = nil;
  NSString     *bundleFullPath = nil;
  NSEnumerator *enumerator = nil;

  // Search for bundle full path in bundlesInfo dictionary
  bundlePaths = [bundlesInfo allKeys];
  enumerator = [bundlePaths objectEnumerator];

//  NSLog(@"Bundle fullpath method #1: %@", 
//	[[self resourcePath] stringByAppendingPathComponent:bundleName]);

  while ((bundleFullPath = [enumerator nextObject]))
    {
      if ([[bundleFullPath lastPathComponent] isEqualToString:bundleName])
	{
	  break;
	}
    }

//  NSLog(@"Bundle fullpath method #2: %@", bundleFullPath);

  return bundleFullPath;
}

// --- Invokes loading of bundle

- (id)objectForClassName:(NSString *)className
	      bundleType:(NSString *)bundleExtension
		protocol:(Protocol *)proto
{
  Class objectClass;

  if (!className)
    {
      NSLog(@"Bundle for class called with empty className");
      return nil;
    }

  if ([self bundleOfType:bundleExtension withClassName:className] == nil)
    {
      NSLog(@"Bundle for class %@ NOT FOUND!", className);
      return nil;
    }

  objectClass = NSClassFromString(className);

  if (proto != nil && ![objectClass conformsToProtocol:proto])
    {
      [NSException raise:NOT_A_PROJECT_TYPE_EXCEPTION 
	          format:@"%@ does not conform to protocol!", className];
      return nil;
    }

  return [[objectClass alloc] init];
}

- (id)objectForBundleWithName:(NSString *)name
			 type:(NSString *)extension
		     protocol:(Protocol *)proto
{
  NSDictionary *infoTable;
  NSString     *className;

  infoTable = [self infoForBundleName:name type:extension];
  className = [infoTable objectForKey:@"PrincipalClassName"];

  return [self objectForClassName:className 
		       bundleType:extension
			 protocol:proto];
}

- (id)objectForBundleType:(NSString *)extension
		 protocol:(Protocol *)proto
		 fileName:(NSString *)fileName
{
  NSString     *className;

  className = [self classNameForBundleType:extension fileName:fileName];

  return [self objectForClassName:className 
		       bundleType:extension
			 protocol:proto];
}

// --- Bundle loading

- (NSBundle *)bundleOfType:(NSString *)type
	     withClassName:(NSString *)className
{
  NSArray      *bundlePaths = nil;
  NSString     *bundleFullPath = nil;
  NSDictionary *infoTable = nil;
  NSEnumerator *enumerator = nil;
  NSString     *bundleName = nil;
  NSString     *principalClass;

  // Search for bundle full path in bundlesInfo dictionary
  bundlePaths = [bundlesInfo allKeys];
  enumerator = [bundlePaths objectEnumerator];
  
  while ((bundleFullPath = [enumerator nextObject]))
    {

      if ([[bundleFullPath pathExtension] isEqualToString:type])
	{
	  infoTable = [bundlesInfo objectForKey:bundleFullPath];
	  principalClass = [infoTable objectForKey:@"PrincipalClassName"];
	  if ([className isEqualToString:principalClass])
	    {
	      break;
	    }
	}
    }

//  NSLog(@"bundleForClassName: %@ path %@", className, bundleFullPath);

  // Extract from full bundle path it's name and extension
  bundleName = [bundleFullPath lastPathComponent];
  if (![self loadBundleIfNeededWithName:bundleName])
    {
      return nil;
    }

  return [loadedBundles objectForKey:bundleFullPath];
}

- (BOOL)loadBundleIfNeededWithName:(NSString *)bundleName
{
  NSString *bundleFullPath = [self bundlePathWithName:bundleName];

  // Check if bundle allready loaded
  if ([[loadedBundles allKeys] containsObject:bundleFullPath] == NO)
    {
      return [self loadBundleWithFullPath:bundleFullPath];
    }
  
  return YES;
}

- (void)loadBundlesWithExtension:(NSString *)extension
{
  NSEnumerator	*enumerator;
  NSFileManager	*fileManager = [NSFileManager defaultManager];
  BOOL 		isDir;
  NSString      *path = [self resourcePath];

  if (path)
    {
      [self loadBundlesAtPath:path withExtension:extension];
    }
 
  // Load third party bundles
  enumerator = [NSSearchPathForDirectoriesInDomains
		 (NSApplicationSupportDirectory, NSAllDomainsMask, YES) 
		 objectEnumerator];
  while ((path = [enumerator nextObject]) != nil)
    {
      path = [path stringByAppendingPathComponent:@"ProjectCenter"];

      if ([fileManager fileExistsAtPath:path isDirectory:&isDir] && isDir)
	{
	  PCLogInfo(self, @"Loading bundles at %@", path);
	  [self loadBundlesAtPath:path withExtension:extension];
	}
    }
}

- (void)loadBundlesAtPath:(NSString *)path withExtension:(NSString *)extension
{
  NSEnumerator *enumerator;
  NSString     *bundleName;
  NSArray      *dir;

  dir = [[NSFileManager defaultManager] directoryContentsAtPath:path];
  enumerator = [dir objectEnumerator];

  while ((bundleName = [enumerator nextObject]))
    {
      if ([[bundleName pathExtension] isEqualToString:extension]) 
	{
	  NSString *fullPath = nil;

	  fullPath = [NSString stringWithFormat:@"%@/%@", path, bundleName];

	  [self loadBundleWithFullPath:fullPath];
	}
    }
}

- (BOOL)loadBundleWithFullPath:(NSString *)path
{
  NSBundle *bundle = nil;

  if ((bundle = [NSBundle bundleWithPath:path]) && [bundle load])
    {
      [loadedBundles setObject:bundle forKey:path];

      PCLogInfo(self, @"Bundle %@ successfully loaded!", path);
    }
  else 
    {
      NSRunAlertPanel(@"Load Bundle",
		      @"Could not load bundle %@!",
		      @"OK", nil, nil, path);
      return NO;
    }

  return YES;
}

- (NSDictionary *)loadedBundles
{
  return loadedBundles;
}

@end
