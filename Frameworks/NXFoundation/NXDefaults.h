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
    If NXGlobalDomain has changed notification sent to NSDistributedNotificationCenter.

    @author Sergii Stioan
*/

#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

extern NSString* const NXUserDefaultsDidChangeNotification;
 
@interface NXDefaults : NSObject
{
  NSString		*filePath;
  NSMutableDictionary	*defaultsDict;
  BOOL			isGlobal;
  
  BOOL			isChanged;
  NSTimer		*syncTimer;
}

+ (NXDefaults *)systemDefaults;
+ (NXDefaults *)userDefaults;
+ (NXDefaults *)globalUserDefaults;

/** Returns preferences located in /usr/NextSpace/Preferences */
- (NXDefaults *)initWithSystemDefaults;
/** Returns preferences located in /usr/NextSpace/Preferences/.NextSpace */
- (NXDefaults *)initWithUserDefaults;
/** Returns global NextSpace preferences 
    ~/Library/Preferences/.NextSpace/NXGlobalDomain */
- (NXDefaults *)initWithGlobalUserDefaults;

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
