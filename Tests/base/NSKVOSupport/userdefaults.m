#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSKeyValueObserving.h>

#import <Testing.h>

/* NSUserDefaults KeyValueObserving Tests
 *
 * Behaviour was validated on macOS 15.0.1 (24A348)
 */

@interface Observer : NSObject
{
@public
  NSInteger     called;
  NSString     *lastKeyPath;
  id            lastObject;
  NSDictionary *lastChange;
}
@end

@implementation Observer

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  called++;
  ASSIGN(lastKeyPath, keyPath);
  ASSIGN(lastObject, object);
  ASSIGN(lastChange, change);
}

- (void)dealloc
{
  RELEASE(lastKeyPath);
  RELEASE(lastObject);
  RELEASE(lastChange);
  [super dealloc];
}

@end

// NSUserDefaults Domain Search List:
// NSArgumentDomain
// Application Domain
// NSGlobalDomain
// NSRegistrationDomain
//
// Terminology:
// - Entry: An entry is a key value pair.
// - Object and Value: both used interchangeably in the NSUserDefaults API to
// describe the value associated with a given key.
//
// Note that -removeObjectForKey: and -setObject:ForKey: emit only a
// KVO notification when the value has actually changed, meaning
// -objectForKey: would return a different value than before.
//
// Example:
// Assume that a key with the same value is registered in both NSArgumentDomain
// and the application domain. If we remove the value with -removeObjectForKey:,
// we set the value for the key in the application domain to nil, but we stil
// have an entry in the NSArgumentDomain. Thus -objectForKey will return the
// same value as before and no change notification is emitted.
int
main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
  Observer       *obs = [Observer new];
  NSString       *key1 = @"key1";
  NSString       *value1 = @"value1";
  NSString       *key2 = @"key2";
  NSString       *value2 = @"value2";
  NSString       *value2Alt = @"value2Alt";

  [defs addObserver:obs
         forKeyPath:key1
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
            context:NULL];
  [defs addObserver:obs
         forKeyPath:key2
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
            context:NULL];

  // Check if we receive KVO notifications when setting default key in the
  // standard application domain
  [defs setObject:value1 forKey:key1];
  PASS(obs->called == 1, "KVO notification received");
  PASS(obs->lastObject != nil, "object is not nil");
  PASS(obs->lastChange != nil, "change is not nil");
  PASS_EQUAL([obs->lastChange objectForKey:@"kind"],
             [NSNumber numberWithInteger:1], "value for 'kind' is 1");
  PASS_EQUAL([obs->lastChange objectForKey:@"old"], [NSNull null],
             "value for 'old' is [NSNull null]");
  PASS_EQUAL([obs->lastChange objectForKey:@"new"], value1,
             "value for 'new' is 'value1'");

  [defs removeObjectForKey:key1];
  PASS(obs->called == 2, "KVO notification received");
  PASS(obs->lastObject != nil, "object is not nil");
  PASS(obs->lastChange != nil, "change is not nil");
  PASS_EQUAL([obs->lastChange objectForKey:@"kind"],
             [NSNumber numberWithInteger:1], "value for 'kind' is 1");
  PASS_EQUAL([obs->lastChange objectForKey:@"old"], value1,
             "value for 'old' is value1");
  PASS_EQUAL([obs->lastChange objectForKey:@"new"], [NSNull null],
             "value for 'new' is [NSNull null]");

  // Test setting two different values for the same key in application domain
  // and registration domain. When removing the value in the application domain,
  // the value for 'new' in the change dictionary is not nil, but rather the
  // value from the registration domain.
  [defs setObject:value2 forKey:key2];
  PASS(obs->called == 3, "KVO notification received");
  PASS(obs->lastObject != nil, "object is not nil");
  PASS(obs->lastChange != nil, "change is not nil");
  PASS_EQUAL([obs->lastChange objectForKey:@"kind"],
             [NSNumber numberWithInteger:1], "value for 'kind' is 1");
  PASS_EQUAL([obs->lastChange objectForKey:@"old"], [NSNull null],
             "value for 'old' is [NSNull null]");
  PASS_EQUAL([obs->lastChange objectForKey:@"new"], value2,
             "value for 'new' is 'value2'");

  // Set default key in registration domain that is _different_ to the key
  // registered in the application domain. This will trigger a change
  // notification, when the entry is removed from the application domain.
  NSDictionary *registrationDict = [NSDictionary dictionaryWithObject:value2Alt
                                                               forKey:key2];
  [defs registerDefaults:registrationDict];

  [defs removeObjectForKey:key2];
  PASS(obs->called == 4, "KVO notification received");
  PASS(obs->lastObject != nil, "object is not nil");
  PASS(obs->lastChange != nil, "change is not nil");
  PASS_EQUAL([obs->lastChange objectForKey:@"kind"],
             [NSNumber numberWithInteger:1], "value for 'kind' is 1");
  PASS_EQUAL([obs->lastChange objectForKey:@"old"], value2,
             "value for 'old' is value2");
  // this must not be null in this case
  PASS_EQUAL([obs->lastChange objectForKey:@"new"], value2Alt,
             "value for 'new' is 'value2Alt'");

  // Set default key in registration domain that is _equal_ to the key
  // registered in the application domain. This will _not_ trigger a change
  // notification, when the entry is removed from the application domain.
  registrationDict = [NSDictionary dictionaryWithObject:value1 forKey:key1];
  [defs registerDefaults:registrationDict];

   // Does not emit a KVO notification as value is not changed
  [defs setObject:value1 forKey:key1]; 
  PASS(obs->called == 4,
       "KVO notification was not emitted as other domain has the same entry");

  // Remove the entry from the application domain.
  [defs removeObjectForKey:key1];
  PASS(obs->called == 4,
       "KVO notification was not emitted as other domain has the same entry");

  [defs removeObserver:obs forKeyPath:key1];
  [defs removeObserver:obs forKeyPath:key2];

  [pool drain];
  [obs release];
  
  return 0;
}
