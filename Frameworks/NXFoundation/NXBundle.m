
#import "NXBundle.h"
#import "NXFileManager.h"

#import <Foundation/Foundation.h>

@implementation NXBundle

static NXBundle *shared = nil;

+ (id)shared
{
  if (shared == nil)
    {
      shared = [self new];
    }

  return shared;
}

//-----------------------------------------------------------------------------
//--- Generic bundles
//-----------------------------------------------------------------------------

// Returns list of bundles' absolute paths located in 'dirPath'.
// Search is recursive starting from 'dirPath'.
- (NSArray *)bundlePathsOfType:(NSString *)fileExtension
                        atPath:(NSString *)dirPath
{
  NSArray        *dirContent;
  NSString       *bFullPath = nil;
  NSMutableArray *bundlePathList = [NSMutableArray new];
  
  NSDirectoryEnumerator *dirEnum;
  NSString *bundleName;

  // Search in dirPath
  dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:dirPath];
  while ((bundleName = [dirEnum nextObject]))
    {
      if ([[bundleName pathExtension] isEqualToString:fileExtension])
	{
	  bFullPath = [NSString stringWithFormat:@"%@/%@", dirPath, bundleName];
          [bundlePathList addObject:bFullPath];
	}
    }
  
  return bundlePathList;
}

// Returns list of paths to bundles found in Library and Applications domains.
- (NSArray *)bundlePathsOfType:(NSString *)fileExtension
{
  NSArray        *libPathList;
  NSMutableArray *pathList = [NSMutableArray new];
  NSMutableArray *bundlePaths = [NSMutableArray new];
  NSString	 *intersection;
  BOOL           skip;

  // ~/Applications, /Applications, /usr/NexSpace/Apps
  [pathList
    addObjectsFromArray:NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,
                                                            NSAllDomainsMask, YES)];
  // ~/Library, /Library, /usr/NextSpace
  libPathList = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                    NSAllDomainsMask, YES);
  for (NSString *lPath in libPathList)
    {
      skip = NO;
      for (NSString *path in pathList)
        {
          intersection = NXIntersectionPath(path, lPath);
          if ([intersection isEqualToString:path])
            {
              skip = YES;
              break;
            }
          else if ([intersection isEqualToString:lPath])
            {
              [pathList replaceObjectAtIndex:[pathList indexOfObject:path]
                                  withObject:lPath];
              skip = YES;
              break;
            }
        }
      if (!skip)
        {
          [pathList addObject:lPath];
        }
    }
  
  NSLog(@"Searching for bundles in: %@", pathList);
  for (NSString *path in pathList)
    {
      [bundlePaths addObjectsFromArray:[self bundlePathsOfType:fileExtension
                                                        atPath:path]];
    }

  return bundlePaths;
}

//-----------------------------------------------------------------------------
//--- Bundles with Resources/bundle.registry file
//-----------------------------------------------------------------------------
// Returned dictionary contains:
//  (NSString *)              (NSDictionary *)
// "full path to the bundle" = {bundle.registry contents}
- (NSDictionary *)registerBundlesOfType:(NSString *)fileExtension
                                 atPath:(NSString *)dirPath
{
  NSArray             *bundlePathsList; // list of dirs to check for registry
  NSMutableDictionary *bundlesRegistry; // gathered registries of all bundles
  NSString            *brFile;          // path to file with registry information
  NSDictionary        *brContent;       // content of one registry file

  if (dirPath != nil)
    {
      bundlePathsList = [self bundlePathsOfType:fileExtension atPath:dirPath];
    }
  else
    {
      bundlePathsList = [self bundlePathsOfType:fileExtension];
    }
  
  NSLog(@"Bundles path list: %@", bundlePathsList);
  bundlesRegistry = [NSMutableDictionary new];
  
  for (NSString *bundlePath in bundlePathsList)
    {
      brFile = [NSBundle pathForResource:@"bundle"
                                  ofType:@"registry"
                             inDirectory:bundlePath];
      if (brFile)
        {
          brContent = [NSDictionary dictionaryWithContentsOfFile:brFile];
          [bundlesRegistry setObject:brContent forKey:bundlePath];
        }
    }

  return bundlesRegistry;
}

// Return array of paths to bundles sorted by 'priority' field in registry
// that is returned by -registerBundlesOftype:atPath
- (NSArray *)sortedBundlesPaths:(NSDictionary *)bundleRegistry
{
  NSArray *paths = [bundleRegistry allKeys];

  id sortByPriority = ^(NSString *path1, NSString *path2)
    {
      NSString *ps1, *ps2;
      NSNumber *p1, *p2;

      ps1 = [[bundleRegistry objectForKey:path1] objectForKey:@"priority"];
      if (!ps1) ps1 = @"1000";
      p1 = [NSNumber numberWithInt:[ps1 intValue]];
      
      ps2 = [[bundleRegistry objectForKey:path2] objectForKey:@"priority"];
      if (!ps2) ps2 = @"1000";
      p2 = [NSNumber numberWithInt:[ps2 intValue]];

      return [p1 compare:p2];
    };

  return [paths sortedArrayUsingComparator:sortByPriority];  
}

- (NSArray *)loadRegisteredBundles:(NSDictionary *)bundleRegistry
                              type:(NSString *)registryType
                          protocol:(Protocol *)aProtocol
{
  NSArray        *sortedBPaths = [self sortedBundlesPaths:bundleRegistry];
  NSString       *bType;
  NSString       *bExecutable;
  NSBundle       *bundle;
  Class          bClass;
  id             bClassObject;
  NSMutableArray *loadedBundles = [NSMutableArray new];

  for (NSString *bPath in sortedBPaths)
    {
      // Check type
      bType = [[bundleRegistry objectForKey:bPath] objectForKey:@"type"];
      if (![bType isEqualToString:registryType])
        {
          NSLog(@"Module \"%@\" according to bundle.registry"
                " is not '%@' module! Bundle loading was stopped.",
                bPath, registryType);
          continue;
        }

      // Load module
      if ((bundle = [NSBundle bundleWithPath:bPath]))
        {
          bExecutable = [[bundle infoDictionary] objectForKey:@"NSExecutable"];
          if (!bExecutable)
            {
              NSLog (@"Bundle `%@' has no executable!", bPath);
              continue;
            }
        }
      
      bClass = [bundle principalClass];

      // Check if bundle already loaded
      for (id b in loadedBundles)
        {
          if ([[b class] isKindOfClass:bClass])
            {
              NSLog(@"Module \"%@\" with principal class \"%@\" is "
                    "already loaded, skipping.", bPath, [b className]);
              continue;
            }
        }

      // Conforming to protocol check
      if (![bClass conformsToProtocol:aProtocol])
        {
          NSLog (@"Principal class '%@' of '%@' bundle does not conform to the "
                 "'%@' protocol.", NSStringFromClass(bClass), bPath,
                 NSStringFromProtocol(aProtocol));
          continue;
        }

      // Add bundle to the list
      bClassObject = [bClass new];
      [loadedBundles addObject:bClassObject];
      [bClassObject release];
    }

  return [loadedBundles autorelease];
}

//-----------------------------------------------------------------------------
//--- Validating and loading
//-----------------------------------------------------------------------------

- (NSArray *)loadBundlesOfType:(NSString *)fileType
                      protocol:(Protocol *)protocol
                   inDirectory:(NSString *)dir
{
  NSMutableArray *loadedBundles = [NSMutableArray new];
  NSArray        *dirContent;
  NSBundle       *bundle;

  dirContent = [self bundlePathsOfType:fileType atPath:dir];

  for (NSString *bundlePath in dirContent)
    {
      bundle = [NSBundle bundleWithPath:bundlePath];
      
      if ([[bundle principalClass] conformsToProtocol:protocol] == YES)
	{
	  [loadedBundles addObject:bundle];
	}
    }

  return loadedBundles;
}

@end
