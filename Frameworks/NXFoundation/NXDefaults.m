/** @class NXDefaults

    Reading/writing NextSpace preferences (separate file for each app, 
    OpenStep style, no file name extension).
    User preferences files located in ~/Library/Preferences/.NextSpace.
    System preferences files located in /usr/NextSpace/Library/Preferences.

    User preferences are used by user controlled applications.
    System prefereences used by system controlled applications (like Login.app).

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

- (NXDefaults *)initDefaultsWithPath:(NSSearchPathDomainMask)domainMask
                              domain:(NSString *)domainName
{
  NSArray  *searchPath;
  NSString *pathFormat;

  self = [super init];

  searchPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
						   domainMask, YES);

  if (domainMask == NSUserDomainMask)
    pathFormat = @"%@/Preferences/.NextSpace/%@";
  else
    pathFormat = @"%@/Preferences/%@";
  
  filePath = [[NSString alloc] initWithFormat:pathFormat,
                    [searchPath objectAtIndex:0], domainName];
  
  {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:filePath])
      {
        defaultsDict = 
          [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        NSLog(@"NXDefaults: defaults loaded from file %@", filePath);
      }
    else
      {
        defaultsDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [defaultsDict retain];
        NSLog(@"NXDefaults: defaults created for file %@", filePath);
      }
  }
  

  return self;
}

// Located in /usr/NextSpace/Preferences
- (NXDefaults *)initWithSystemDefaults
{
  self = [self init];

  [self initDefaultsWithPath:NSSystemDomainMask
                      domain:[[NSProcessInfo processInfo] processName]];
  
  return self;
}

// Located in ~/Library/Preferences/.NextSpace
- (NXDefaults *)initWithUserDefaults
{
  self = [super init];

  [self initDefaultsWithPath:NSUserDomainMask
                      domain:[[NSProcessInfo processInfo] processName]];

  return self;
}

// Global NextSpace preferences located in
// ~/Library/Preferences/.NextSpace/NXGlobalDomain
- (NXDefaults *)initWithGlobalUserDefaults
{
  self = [super init];

  [self initDefaultsWithPath:NSUserDomainMask
                      domain:@"NXGlobalDomain"];

  return self;
}

- (void)dealloc
{
  [self synchronize];
  [defaultsDict release];
  [filePath release];

  [super dealloc];
}

- (BOOL)synchronize
{
  return [defaultsDict writeToFile:filePath atomically:NO];
}

- (id)objectForKey:(NSString *)key
{
  return [defaultsDict objectForKey:key];
}

- (void)setObject:(id)value forKey:(NSString *)key
{
  [defaultsDict setObject:value forKey:key];
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
  [self synchronize];
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

- (void)setInteger:(NSInteger)value forKey:(NSString *)key
{
  NSNumber *n = [NSNumber numberWithInteger:value];

  [self setObject:n forKey:key];
  [self synchronize];
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
  [self synchronize];
}

@end
