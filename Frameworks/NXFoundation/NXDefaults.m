/** @class NXDefaults

    Reading/writing preferences (separate .ospl file for each app in
    OpenStep style).

    @author Sergii Stioan
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSValue.h>

#import "NXDefaults.h"

static NXDefaults *sharedSystemDefaults;
static NXDefaults *sharedUserDefaults;

@implementation NXDefaults

// --- Private
- (NSString *)fileNameInDomain:(NSSearchPathDomainMask)domain
{
  NSString *processName = [[NSProcessInfo processInfo] processName];
  NSArray  *searchPath;
  NSString *path;

  searchPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
						   domain, YES);
  path = [searchPath objectAtIndex:0];

  // Since GNUstep uses .plist (XML) for its defaults file we will use .ospl
  // for ours.
  return [NSString stringWithFormat:@"%@/Preferences/%@.ospl",
                   path, processName];
}

- (void)loadFromFile:(NSString *)filePath
{
  NSFileManager *fileManager = [NSFileManager defaultManager];

  if ([fileManager fileExistsAtPath:filePath])
    {
      defaultsDict = 
	[[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
    }
  else
    {
      defaultsDict = [NSMutableDictionary dictionaryWithCapacity:1];
      [defaultsDict retain];
    }
}

- (BOOL)synchronize
{
  return [defaultsDict writeToFile:fileName atomically:NO];
}
// --- End of Private

+ (NXDefaults *)systemDefaults
{
  if (sharedSystemDefaults == nil)
    {
      sharedSystemDefaults = [[NXDefaults alloc] initWithSystemDefaults];
    }

  return sharedSystemDefaults;
}

+ (NXDefaults *)userDefaults
{
  if (sharedUserDefaults == nil)
    {
      sharedUserDefaults = [[NXDefaults alloc] initWithUserDefaults];
    }

  return sharedUserDefaults;
}

- (NXDefaults *)initWithSystemDefaults
{
  self = [self init];

  fileName = [[self fileNameInDomain:NSSystemDomainMask] retain];
  [self loadFromFile:fileName];
  NSLog(@"NXDefaults: defaults loadedFromFile %@", fileName);

  return self;
}

- (NXDefaults *)initWithUserDefaults
{
  self = [self init];

  fileName = [[self fileNameInDomain:NSUserDomainMask] retain];
  [self loadFromFile:fileName];
  NSLog(@"NXDefaults: defaults loadedFromFile %@", fileName);

  return self;
}

- (void)dealloc
{
  [self synchronize];
  [defaultsDict release];
  [fileName release];

  [super dealloc];
}

- (id)objectForKey:(NSString *)key
{
  return [defaultsDict objectForKey:key];
}

- (void)setObject:(id)value forKey:(NSString *)key
{
  [defaultsDict setObject:value forKey:key];
  NSLog(@"NXDefaults setObject: %@", value);
  [self synchronize];
}

- (void)removeObjectForKey:(NSString *)key
{
  [defaultsDict removeObjectForKey:key];
  [self synchronize];
}

- (float)floatForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
		  || [obj isKindOfClass:[NSNumber class]]))
    {
      return [obj floatValue];
    }

  return 0.0;
}

- (void)setFloat:(float)value forKey:(NSString*)key
{
  NSNumber *n = [NSNumber numberWithFloat:value];

  [self setObject:n forKey:key];
}

- (NSInteger)integerForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
		  || [obj isKindOfClass:[NSNumber class]]))
    {
      return [obj integerValue];
    }

  return -1;
}

- (void)setInteger:(NSInteger)value 
            forKey:(NSString *)key
{
  NSNumber *n = [NSNumber numberWithInteger:value];

  [self setObject:n forKey:key];
}

- (BOOL)boolForKey:(NSString*)key
{
  id obj = [self objectForKey:key];

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
		  || [obj isKindOfClass:[NSNumber class]]))
    {
      return [obj boolValue];
    }

  return NO;
}

- (void)setBool:(BOOL)value forKey:(NSString*)key
{
  if (value == YES)
    {
      [self setObject:@"YES" forKey:key];
    }
  else
    {
      [self setObject:@"NO" forKey:key];
    }
}

@end
