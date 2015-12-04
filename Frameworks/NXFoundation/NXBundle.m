
#import "NXBundle.h"

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
//--- Searching and registering
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
  NSArray        *pathList;
  NSMutableArray *bundlePaths = [NSMutableArray new];

  // ~/Applications, /Applications, /usr/NexSpace/Apps
  pathList = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,
                                                 NSAllDomainsMask, YES);
  NSLog(@"Searching for bundles in: %@", pathList);
  for (NSString *path in pathList)
    {
      [bundlePaths addObjectsFromArray:[self bundlePathsOfType:fileExtension
                                                        atPath:path]];
    }

  // ~/Library, /Library, /usr/NextSpace
  pathList = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                 NSAllDomainsMask, YES);
  NSLog(@"Searching for bundles in: %@", pathList);
  for (NSString *path in pathList)
    {
      [bundlePaths addObjectsFromArray:[self bundlePathsOfType:fileExtension
                                                        atPath:path]];
    }
  
  return bundlePaths;
}

// Returned dictionary contains:
//  (NSString *)              (NSDictionary *)
// "full path to the bundle" = {bundle.registry contents}
- (NSDictionary *)registerBundlesOfType:(NSString *)fileExtension
                                 atPath:(NSString *)dirPath
{
  NSArray             *bundlePathsList; // list of dirs to check for registry
  NSMutableDictionary *bundlesRegistry; // gathered registries of all bundles
  NSString            *brFile;        // path to file with registry information
  NSDictionary        *brContent;    // content of one registry file

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

//-----------------------------------------------------------------------------
//--- Validating and loading
//-----------------------------------------------------------------------------

// TODO
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
