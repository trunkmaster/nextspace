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

/** @class NXTDefaults

    This is a light version of NSUserDefaults for use by NextSpace apps.
    Differences with NSUserDefaults are the following:
    - access to user-level applications' defaults provided by
      +userDefaults and -initWithUserDefaults methods
      (located in ~/Library/Preferences/.NextSpace/<name of the app>);
    - access to system-level applications' defaults - via
      +systemDefaults and -initWithSystemDefaults
      (located in /usr/NextSpace/Preferences/<name of the app>);
    - access to ~/Library/Preferences/.NextSpace/NXGobalDomain provided with
      +globalUserDefaults and -initGlobalUserDefaults methods;
    - file with defaults of any kind has no extension and stored in old
      OpenStep style;
    - all domains are persistent;
    - there's no method for defaults registration (no -registerDefaults method).

    User preferences are used by user controlled applications.
    System prefereences used by system controlled applications (like Login.app).

    If user defaults file has changed notification sent to NSNotificationCenter.
    If NXGlobalDomain has changed notification sent to NSDistributedNotificationCenter.

    @author Sergii Stioan
*/

#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSPathUtilities.h>

extern NSString* const NXUserDefaultsDidChangeNotification;
 
@interface NXTDefaults : NSObject
{
  NSString		*filePath;
  NSMutableDictionary	*defaultsDict;
  BOOL			isGlobal;
  BOOL			isSystem;
  NSTimer		*syncTimer;
}

+ (NXTDefaults *)systemDefaults;
+ (NXTDefaults *)userDefaults;
+ (NXTDefaults *)globalUserDefaults;

/** Returns preferences located in /usr/NextSpace/Preferences */
- (NXTDefaults *)initWithSystemDefaults;
/** Returns preferences located in ~/Library/Preferences/.NextSpace */
- (NXTDefaults *)initWithUserDefaults;
/** Returns global NextSpace preferences 
    ~/Library/Preferences/.NextSpace/NXGlobalDomain */
- (NXTDefaults *)initWithGlobalUserDefaults;

- (NXTDefaults *)initDefaultsWithPath:(NSSearchPathDomainMask)domainMask
                               domain:(NSString *)domainName;
  
- (NXTDefaults *)reload;
- (BOOL)synchronize;

- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value 
           forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;

- (float)floatForKey:(NSString *)key;
- (void)setFloat:(float)value 
          forKey:(NSString *)key;

- (NSInteger)integerForKey:(NSString *)key;
- (void)setInteger:(NSInteger)value 
            forKey:(NSString *)key;

- (BOOL)boolForKey:(NSString*)key;
- (void)setBool:(BOOL)value 
         forKey:(NSString*)key;

@end
