/** @class NXDefaults

    This is a simplified version NSUserDefaults for use in NextSpace apps.
    From NSUserDefaults differences is the following:
    - access to user-level applications' defaults provided by
      +userDefaults and -initWithUserDefaults methods
      (located in ~/Library/Preferences/.NextSpace/<name of the app>);
    - access to system-level applications' defaults - via
      +systemDefaults and -initWithSystemDefaults
      (located in /usr/NextSpace/Preferences/<name of the app>);
    - access to ~/Library/Preferences/.NextSpace/NXGobalDomain via
      +globalUserDefaults and -initGlobalUserDefaults;
    - file with defaults of any kind has no extension and stored in old
      OpenStep style;
    - all domains are persistent;
    - there's not method of defaults registration (no -registerDefaults method).

    User preferences are used by user controlled applications.
    System prefereences used by system controlled applications (like Login.app).

    If user defaults file has changed notification sent to NSNotificationCenter.
    If NXGlobalDomain has changed notification sent to 
    NSDistributedNotificationCenter.

    It should be a better way to implement storing user defaults .NextSpace
    subdirectory and have notifications to all applications after changes while
    holding all generic functionality of NSUserDefaults.

    @author Sergii Stioan
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSDistributedNotificationCenter.h>
#import <Foundation/NSTimer.h>

#import <Foundation/NSUserDefaults.h>

#import "NXDefaults.h"

NSString* const NXUserDefaultsDidChangeNotification = @"NXUserDefaultsDidChangeNotification";

static NXDefaults *sharedSystemDefaults;
static NXDefaults *sharedUserDefaults;
static NXDefaults *sharedGlobalUserDefaults;

@implementation NXDefaults

//-----------------------------------------------------------------------------
#pragma mark - Class methods
//-----------------------------------------------------------------------------

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

+ (NXDefaults *)globalUserDefaults
{
  if (sharedGlobalUserDefaults == nil)
    {
      sharedGlobalUserDefaults = [[NXDefaults alloc] initWithGlobalUserDefaults];
    }

  return sharedGlobalUserDefaults;
}

//-----------------------------------------------------------------------------
#pragma mark - Init & dealloc
//-----------------------------------------------------------------------------

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
  isGlobal = NO;
  return [self initDefaultsWithPath:NSSystemDomainMask
                             domain:[[NSProcessInfo processInfo] processName]];
}

// Located in ~/Library/Preferences/.NextSpace
- (NXDefaults *)initWithUserDefaults
{
  isGlobal = NO;
  return [self initDefaultsWithPath:NSUserDomainMask
                             domain:[[NSProcessInfo processInfo] processName]];
}

// Global NextSpace preferences located in
// ~/Library/Preferences/.NextSpace/NXGlobalDomain
- (NXDefaults *)initWithGlobalUserDefaults
{
  isGlobal = YES;
  return [self initDefaultsWithPath:NSUserDomainMask
                             domain:@"NXGlobalDomain"];
}

- (void)dealloc
{
  // [self synchronize];
  [defaultsDict release];
  [filePath release];

  [super dealloc];
}

- (void)setChanged:(BOOL)yn
{
  isChanged = yn;

  if (syncTimer && ![syncTimer isValid])
    {
      syncTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                   target:self
                                                 selector:@selector(synchronize)
                                                 userInfo:nil
                                                  repeats:NO];
      [NSTimer setShouldCleanUp:YES];
    }
}

// Writes in-memory dictionary to file.
// On success sends NXUserDefaultsDidChangeNotification.
// If isGlobal == YES sends this notification to all applications of current user.
- (BOOL)synchronize
{
  if ([defaultsDict writeToFile:filePath atomically:NO] == YES)
    {
      if (isGlobal == YES)
        {
          [[NSDistributedNotificationCenter
             notificationCenterForType:NSLocalNotificationCenterType]
            postNotificationName:NXUserDefaultsDidChangeNotification
                          object:@"NXGlobalDomain"];
        }
      else
        {
          [[NSNotificationCenter defaultCenter]
            postNotificationName:NXUserDefaultsDidChangeNotification
                          object:self];
        }
      return YES;
    }

  return NO;
}

//-----------------------------------------------------------------------------
#pragma mark - Values
//-----------------------------------------------------------------------------

- (id)objectForKey:(NSString *)key
{
  return [defaultsDict objectForKey:key];
}

- (void)setObject:(id)value
           forKey:(NSString *)key
{
  [defaultsDict setObject:value forKey:key];
}

- (void)removeObjectForKey:(NSString *)key
{
  [defaultsDict removeObjectForKey:key];
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

- (void)setFloat:(float)value
          forKey:(NSString*)key
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

- (void)setBool:(BOOL)value
         forKey:(NSString*)key
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
