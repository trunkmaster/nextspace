/** @class NXDefaults

    Reading/writing preferences (separate .ospl file for each app in
    OpenStep style).

    @author Sergii Stioan
 */

#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
 
@interface NXDefaults : NSObject
{
  NSString            *fileName;
  NSMutableDictionary *defaultsDict;
}

/** Returns preferences located in system directory 
    (e.g. /Library/Preferences)*/
+ (NXDefaults *)systemDefaults;
/** Returns preferences located in user home directory 
    (e.g. ~/Library/Preferences)*/
+ (NXDefaults *)userDefaults;

- (NXDefaults *)initWithSystemDefaults;
- (NXDefaults *)initWithUserDefaults;

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
