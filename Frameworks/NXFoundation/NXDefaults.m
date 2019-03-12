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
#import <Foundation/NSRunLoop.h>

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
  NSArray	*searchPath;
  NSString	*pathFormat;
  NSString	*defsDir;
  NSFileManager	*fileManager = [NSFileManager defaultManager];

  self = [super init];

  searchPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
						   domainMask, YES);

  if (domainMask == NSUserDomainMask)
    pathFormat = @"%@/Preferences/.NextSpace/%@";
  else
    pathFormat = @"%@/Preferences/%@";

  filePath = [[NSString alloc] initWithFormat:pathFormat,
                    [searchPath objectAtIndex:0], domainName];

  // Create directories if needed
  defsDir = [filePath stringByDeletingLastPathComponent];
  if (![fileManager fileExistsAtPath:defsDir])
    {
      [fileManager createDirectoryAtPath:defsDir
             withIntermediateDirectories:YES
                              attributes:nil
                                   error:0];
    }

  [self reload];

  syncTimer = nil;

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
  if (isChanged)
    {
      [self synchronize];
    }
  if (syncTimer) [syncTimer release];
  [defaultsDict release];
  [filePath release];
  
  [super dealloc];
}

- (void)setChanged
{
  if (syncTimer == nil || ![syncTimer isValid])
    {
      syncTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                   target:self
                                                 selector:@selector(writeToDisk)
                                                 userInfo:nil
                                                  repeats:NO];
      [syncTimer retain];
    }
}

- (NXDefaults *)reload
{
  NSFileManager	*fileManager = [NSFileManager defaultManager];

  if (defaultsDict) {
    [defaultsDict release];
  }
  
  // Create or load defaults from file
  if ([fileManager fileExistsAtPath:filePath]) {
    defaultsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
  }
  else {
    defaultsDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [defaultsDict retain];
  }

  return self;
}

- (BOOL)synchronize
{
  NSLog(@"NXDefaults: Waiting for defaults to be synchronized.");
  while (syncTimer && ([syncTimer isValid] != NO)) {
    [[NSRunLoop currentRunLoop]
      runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
  }
  NSLog(@"NXDefaults: synchronized!");
  return YES;
}

// Writes in-memory dictionary to a file.
// On success, sends NXUserDefaultsDidChangeNotification.
// If isGlobal == YES sends this notification to all applications
// of current user.
- (void)writeToDisk
{
  NSLog(@"NXDefaults: write to file: %@", filePath);
  
  if ([defaultsDict writeToFile:filePath atomically:YES] == YES) {
    if (isGlobal == YES) {
      [[NSDistributedNotificationCenter
             notificationCenterForType:NSLocalNotificationCenterType]
            postNotificationName:NXUserDefaultsDidChangeNotification
                          object:@"NXGlobalDomain"];
    }
    else {
      [[NSNotificationCenter defaultCenter]
            postNotificationName:NXUserDefaultsDidChangeNotification
                          object:self];
    }

    if (syncTimer && [syncTimer isValid]) {
      [syncTimer invalidate];
    }
  }
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
  [self setChanged];
}

- (void)removeObjectForKey:(NSString *)key
{
  [defaultsDict removeObjectForKey:key];
  [self setChanged];
}

- (float)floatForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
		  || [obj isKindOfClass:[NSNumber class]])) {
    return [obj floatValue];
  }

  return 0.0;
}

- (void)setFloat:(float)value
          forKey:(NSString*)key
{
  [self setObject:[NSNumber numberWithFloat:value]
           forKey:key];
  [self setChanged];
}

- (NSInteger)integerForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
                     || [obj isKindOfClass:[NSNumber class]])) {
    return [obj integerValue];
  }

  return -1;
}

- (void)setInteger:(NSInteger)value
            forKey:(NSString *)key
{
  [self setObject:[NSNumber numberWithInteger:value]
           forKey:key];
  [self setChanged];
}

- (BOOL)boolForKey:(NSString*)key
{
  id obj = [self objectForKey:key];

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
                     || [obj isKindOfClass:[NSNumber class]])) {
    return [obj boolValue];
  }
  
  return NO;
}

- (void)setBool:(BOOL)value
         forKey:(NSString*)key
{
  if (value == YES) {
    [self setObject:@"YES" forKey:key];
  }
  else {
    [self setObject:@"NO" forKey:key];
  }
  [self setChanged];
}

@end
