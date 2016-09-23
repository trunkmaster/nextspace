/** @class NXDefaults

    Reading/writing preferences (separate .ospl file for each app in
    OpenStep style).

    @author Sergii Stioan
 */

#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
 
@interface NXDefaults : NSObject
{
  NSString            *filePath;
  NSMutableDictionary *defaultsDict;
}

+ (NXDefaults *)systemDefaults;
+ (NXDefaults *)userDefaults;

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
