/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSDistributedNotificationCenter.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSDebug.h>

#import "NXTDefaults.h"

NSString* const NXUserDefaultsDidChangeNotification = @"NXUserDefaultsDidChangeNotification";

static NXTDefaults *sharedSystemDefaults;
static NXTDefaults *sharedUserDefaults;
static NXTDefaults *sharedGlobalUserDefaults;
static NSLock     *syncLock;

@implementation NXTDefaults

//-----------------------------------------------------------------------------
#pragma mark - Class methods
//-----------------------------------------------------------------------------

+ (NXTDefaults *)systemDefaults
{
  if (sharedSystemDefaults == nil) {
    sharedSystemDefaults = [[NXTDefaults alloc] initWithSystemDefaults];
  }
  return sharedSystemDefaults;
}

+ (NXTDefaults *)userDefaults
{
  if (sharedUserDefaults == nil) {
    sharedUserDefaults = [[NXTDefaults alloc] initWithUserDefaults];
  }
  return sharedUserDefaults;
}

+ (NXTDefaults *)globalUserDefaults
{
  if (sharedGlobalUserDefaults == nil) {
    sharedGlobalUserDefaults = [[NXTDefaults alloc] initWithGlobalUserDefaults];
  }
  return sharedGlobalUserDefaults;
}

//-----------------------------------------------------------------------------
#pragma mark - Init & dealloc
//-----------------------------------------------------------------------------

- (NXTDefaults *)initDefaultsWithPath:(NSSearchPathDomainMask)domainMask
                               domain:(NSString *)domainName
{
  NSArray	*searchPath;
  NSString	*pathFormat;
  NSString	*defsDir;
  NSFileManager	*fileManager = [NSFileManager defaultManager];
  NSDictionary  *attrs = nil;

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
  if (![fileManager fileExistsAtPath:defsDir]) {
    if (isSystem != NO) {
      attrs = @{NSFileGroupOwnerAccountName:@"wheel",
                NSFilePosixPermissions:[NSNumber numberWithShort:0775]};
    }
    [fileManager createDirectoryAtPath:defsDir
           withIntermediateDirectories:YES
                            attributes:attrs
                                 error:0];
  }

  [self reload];

  syncTimer = nil;
  syncLock = [NSLock new];

  return self;
}

// Located in /usr/NextSpace/Preferences
- (NXTDefaults *)initWithSystemDefaults
{
  isGlobal = NO;
  isSystem = YES;
  return [self initDefaultsWithPath:NSSystemDomainMask
                             domain:[[NSProcessInfo processInfo] processName]];
}

// Located in ~/Library/Preferences/.NextSpace
- (NXTDefaults *)initWithUserDefaults
{
  isGlobal = NO;
  isSystem = NO;
  return [self initDefaultsWithPath:NSUserDomainMask
                             domain:[[NSProcessInfo processInfo] processName]];
}

// Global NextSpace preferences located in
// ~/Library/Preferences/.NextSpace/NXGlobalDomain
- (NXTDefaults *)initWithGlobalUserDefaults
{
  isGlobal = YES;
  isSystem = NO;
  return [self initDefaultsWithPath:NSUserDomainMask
                             domain:@"NXGlobalDomain"];
}

- (void)dealloc
{
  NSLog(@"[NXTDefaults] - dealloc");
  [self synchronize];
  
  if (syncTimer) [syncTimer release];
  [defaultsDict release];
  [filePath release];
  [syncLock release];
  
  [super dealloc];
}

- (void)setChanged
{
  if (syncTimer == nil || ![syncTimer isValid]) {
    syncTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                 target:self
                                               selector:@selector(writeToDisk)
                                               userInfo:nil
                                                repeats:NO];
    [syncTimer retain];
    NSDebugLLog(@"NXTDefaults", @"[NXTDefaults] Timer scheduled!");
  }
}

- (NXTDefaults *)reload
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
  if ([syncLock tryLock] == NO)
    return NO;
  
  NSDebugLLog(@"NXTDefaults",
              @"[NXTDefaults] Waiting for defaults to be synchronized. %@ - %i",
              syncTimer, [syncTimer isValid]);
  if (syncTimer != nil && ([syncTimer isValid] != NO)) {
    [syncTimer fire];
  }
  NSDebugLLog(@"NXTDefaults", @"[NXTDefaults] synchronized!");
  
  [syncLock unlock];
  return YES;
}

// Writes in-memory dictionary to a file.
// On success, sends NXUserDefaultsDidChangeNotification.
// If isGlobal == YES sends this notification to all applications
// of current user.
- (void)writeToDisk
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSDictionary  *attrs = nil;
  
  NSDebugLLog(@"NXTDefaults", @"[NXTDefaults] write to file: %@", filePath);

  if ([fileManager fileExistsAtPath:filePath] == NO) {
    if (isSystem != NO) {
      attrs = @{NSFileGroupOwnerAccountName:@"wheel",
                NSFilePosixPermissions:[NSNumber numberWithShort:0664]};
    }
    [fileManager createFileAtPath:filePath
                         contents:nil
                       attributes:attrs];
  }
  
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
