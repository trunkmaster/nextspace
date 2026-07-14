#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSString.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSNull.h>
#import "ObjectTesting.h"

@interface Observer : NSObject
{
  NSInteger count;
  NSInteger kvoCount;
}
- (NSInteger)count;
- (NSInteger)kvoCount;
- (void)notified:(NSNotification *)n;
@end

@implementation Observer
- (NSInteger)count
{
  return count;
}
- (NSInteger)kvoCount
{
  return kvoCount;
}
- (void)notified:(NSNotification *)n
{
  count++;
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  id old = [change objectForKey:NSKeyValueChangeOldKey];
  id new = [ change objectForKey : NSKeyValueChangeNewKey ];
  NSKeyValueChange kind =
    [[change objectForKey:NSKeyValueChangeKindKey] intValue];
  id isPrior = [change objectForKey:NSKeyValueChangeNotificationIsPriorKey];

  NSLog(@"KVO: %@: old = %@, new = %@, kind = %ld, isPrior = %@",
        keyPath, old, new, kind, isPrior);

  if ([keyPath isEqualToString:@"Test Suite Bool"])
    {
      switch (kvoCount)
        {
          case 0: // Initial
          {
            PASS_EQUAL(
              new, [NSNull null],
              "KVO: Initial setting of 'Test Suite Bool' has new = null");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Bool' is of kind "
                 "NSKeyValueChangeSetting (initial)");
            break;
          }
          case 3: // Prior to [defs setBool:YES forKey:@"Test Suite Bool"];
          {
            PASS_EQUAL(
              old, [NSNull null],
              "KVO: First setting of 'Test Suite Bool' has old = null (prior)");
            PASS(new == nil,
                 "KVO: First setting of 'Test Suite Bool' has no new (prior)");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Bool' is of kind "
                 "NSKeyValueChangeSetting (prior)");
            PASS_EQUAL(isPrior, [NSNumber numberWithBool:YES],
                       "KVO: notification for 'Test Suite Bool' is prior");
            break;
          }
          case 4: // [defs setBool:YES forKey:@"Test Suite Bool"];
          {
            PASS_EQUAL(
              old, [NSNull null],
              "KVO: First setting of 'Test Suite Bool' has old = null");
            PASS([new isKindOfClass:[ NSNumber class ]],
                 "KVO: New value for 'Test Suite Bool' has NSNumber");
            PASS(YES == [new boolValue],
                 "KVO: new value for 'Test Suite Bool' is YES");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Bool' is of kind "
                 "NSKeyValueChangeSetting");
            break;
          }
          case 9: // Prior to [defs removeObjectForKey:@"Test Suite Bool"];
          {
            PASS([old isKindOfClass:[NSNumber class]],
                 "KVO: First setting of 'Test Suite Bool' has old NSNumber");
            PASS(YES == [old boolValue],
                 "KVO: old value for 'Test Suite Bool' is YES");
            PASS(new == nil,
                 "KVO: First setting of 'Test Suite Bool' has no new");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Bool' is of kind "
                 "NSKeyValueChangeSetting");
            PASS_EQUAL(isPrior, [NSNumber numberWithBool:YES],
                       "KVO: notification for 'Test Suite Bool' is prior");
            break;
          }
          case 10: // [defs removeObjectForKey:@"Test Suite Bool"];
          {
            PASS([old isKindOfClass:[NSNumber class]],
                 "KVO: First setting of 'Test Suite Bool' has old NSNumber");
            PASS(YES == [old boolValue],
                 "KVO: old value for 'Test Suite Bool' is YES");
            PASS_EQUAL(
              new, [NSNull null],
              "KVO: First setting of 'Test Suite Bool' has new = null");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Bool' is of kind "
                 "NSKeyValueChangeSetting");
            break;
          }
          default: {
            PASS(NO, "KVO: unexpected count for 'Test Suite Bool'");
            break;
          }
        }
    }
  else if ([keyPath isEqualToString:@"Test Suite Int"])
    {
      switch (kvoCount)
        {
          case 1: // Initial
          {
            PASS_EQUAL(
              new, [NSNull null],
              "KVO: Initial setting of 'Test Suite Int' has new = null");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Int' is of kind "
                 "NSKeyValueChangeSetting (initial)");
            break;
          }
          case 5: // Prior to [defs setInteger:34 forKey:@"Test
                  // Suite Int"];
          {
            PASS_EQUAL(old, [NSNull null],
                       "KVO: First setting of 'Test Suite Int' has old = null");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Int' is of kind "
                 "NSKeyValueChangeSetting");
            PASS_EQUAL(isPrior, [NSNumber numberWithBool:YES],
                       "KVO: notification for 'Test Suite Int' is prior");
            break;
          }
          case 6: // [defs setInteger:34 forKey:@"Test Suite Int"];
          {
            PASS_EQUAL(
              old, [NSNull null],
              "KVO: Second setting of 'Test Suite Int' has old = null");
            PASS([new isKindOfClass:[ NSNumber class ]],
                 "KVO: New value for 'Test Suite Int' has NSNumber");
            PASS(34 == [new intValue],
                 "KVO: new value for 'Test Suite Int' is 34");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Int' is of kind "
                 "NSKeyValueChangeSetting");
            break;
          }
          case 11: // Prior to [defs setObject:nil
                   // forKey:@"Test Suite Int"];
          {
            PASS([old isKindOfClass:[NSNumber class]],
                 "KVO: First setting of 'Test Suite Int' has old NSNumber");
            PASS(34 == [old intValue],
                 "KVO: old value for 'Test Suite Int' is 34");
            PASS(new == nil,
                 "KVO: First setting of 'Test Suite Int' has no new");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Int' is of kind "
                 "NSKeyValueChangeSetting");
            PASS_EQUAL(isPrior, [NSNumber numberWithBool:YES],
                       "KVO: notification for 'Test Suite Int' is prior");
            break;
          }
          case 12: // [defs setObject:nil forKey:@"Test Suite Int"];
          {
            PASS([old isKindOfClass:[NSNumber class]],
                 "KVO: First setting of 'Test Suite Int' has old NSNumber");
            PASS(34 == [old intValue],
                 "KVO: old value for 'Test Suite Int' is 34");
            PASS_EQUAL(new, [NSNull null],
                       "KVO: First setting of 'Test Suite Int' has new = null");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Int' is of kind "
                 "NSKeyValueChangeSetting");
            break;
          }
          default: {
            PASS(NO, "KVO: unexpected count for 'Test Suite Int'");
            break;
          }
        }
    }
  else if ([keyPath isEqualToString:@"Test Suite Str"])
    {
      switch (kvoCount)
        {
          case 2: // Initial
          {
            PASS_EQUAL(
              new, [NSNull null],
              "KVO: Initial setting of 'Test Suite Str' has new = null");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Str' is of kind "
                 "NSKeyValueChangeSetting (initial)");
            break;
          }
          case 7: // Prior to [defs setObject:@"SetString"
                  // forKey:@"Test Suite Str"];
          {
            PASS_EQUAL(old, [NSNull null],
                       "KVO: First setting of 'Test Suite Str' has old = null");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Str' is of kind "
                 "NSKeyValueChangeSetting");
            PASS_EQUAL(isPrior, [NSNumber numberWithBool:YES],
                       "KVO: notification for 'Test Suite Str' is prior");
            break;
          }
          case 8: // [defs setObject:@"SetString"
                  // forKey:@"Test Suite Str"];
          {
            PASS_EQUAL(
              old, [NSNull null],
              "KVO: Second setting of 'Test Suite Str' has old = null");
            PASS([new isKindOfClass:[ NSString class ]],
                 "KVO: New value for 'Test Suite Str' has NSString");
            PASS([new isEqual:@"SetString"],
                 "KVO: new value for 'Test Suite Str' is 'SetString'");
            PASS(kind == NSKeyValueChangeSetting,
                 "KVO: notification for 'Test Suite Str' is of kind "
                 "NSKeyValueChangeSetting");
            break;
          }
          default: {
            PASS(NO, "KVO: unexpected count for 'Test Suite Str'");
            break;
          }
        }
    }
  kvoCount++;
}
@end

int
main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  Observer          *obs = [[Observer new] autorelease];
  NSUserDefaults    *defs;

  defs = [NSUserDefaults standardUserDefaults];
  PASS(defs != nil && [defs isKindOfClass:[NSUserDefaults class]],
       "NSUserDefaults understands +standardUserDefaults");

  /* Reset the defaults */
  [defs removeObjectForKey:@"Test Suite Bool"];
  [defs removeObjectForKey:@"Test Suite Int"];
  [defs removeObjectForKey:@"Test Suite Str"];

  [[NSNotificationCenter defaultCenter]
    addObserver:obs
       selector:@selector(notified:)
           name:NSUserDefaultsDidChangeNotification
         object:nil];

  [defs addObserver:obs
         forKeyPath:@"Test Suite Bool"
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                    | NSKeyValueObservingOptionPrior
                    | NSKeyValueObservingOptionInitial
            context:NULL];

  [defs addObserver:obs
         forKeyPath:@"Test Suite Int"
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                    | NSKeyValueObservingOptionPrior
                    | NSKeyValueObservingOptionInitial
            context:NULL];

  [defs addObserver:obs
         forKeyPath:@"Test Suite Str"
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                    | NSKeyValueObservingOptionPrior
                    | NSKeyValueObservingOptionInitial
            context:NULL];
  PASS([obs kvoCount] == 3, "KVO: initial count is 3");

  [defs setBool:YES forKey:@"Test Suite Bool"];
  PASS([defs boolForKey:@"Test Suite Bool"],
       "NSUserDefaults can set/get a BOOL");
  PASS([[defs objectForKey:@"Test Suite Bool"] isKindOfClass:[NSNumber class]],
       "NSUserDefaults returns NSNumber for a BOOL");

  PASS([obs count] == 1, "setting a boolean causes notification");
  PASS([obs kvoCount] == 5, "KVO: setting boolean caused 2 notifications");

  [defs setInteger:34 forKey:@"Test Suite Int"];
  PASS([defs integerForKey:@"Test Suite Int"] == 34,
       "NSUserDefaults can set/get an int");
  PASS([[defs objectForKey:@"Test Suite Int"] isKindOfClass:[NSNumber class]],
       "NSUserDefaults returns NSNumber for an int");

  PASS([obs count] == 2, "setting an integer causes notification");
  PASS([obs kvoCount] == 7, "KVO: setting integer caused 2 notifications");

  [defs setObject:@"SetString" forKey:@"Test Suite Str"];
  PASS([[defs stringForKey:@"Test Suite Str"] isEqual:@"SetString"],
       "NSUserDefaults can set/get a string");
  PASS([[defs objectForKey:@"Test Suite Str"] isKindOfClass:[NSString class]],
       "NSUserDefaults returns NSString for a string");

  PASS([obs count] == 3, "setting a string causes notification");
  PASS([obs kvoCount] == 9, "KVO: setting integer caused 2 notifications");

  [defs removeObjectForKey:@"Test Suite Bool"];
  PASS(nil == [defs objectForKey:@"Test Suite Bool"],
       "NSUserDefaults can use -removeObjectForKey: to remove a bool");

  PASS([obs count] == 4, "removing a key causes notification");
  PASS([obs kvoCount] == 11, "KVO: removing bool caused 2 notifications");

  [defs setObject:nil forKey:@"Test Suite Int"];
  PASS(nil == [defs objectForKey:@"Test Suite Int"],
       "NSUserDefaults can use -setObject:forKey: to remove an int");

  PASS([obs count] == 5, "setting nil object causes notification");
  PASS([obs kvoCount] == 13, "KVO: removing int caused 2 notifications");

  [defs setObject:@"SetString" forKey:@"Test Suite Str"];
  PASS([[defs objectForKey:@"Test Suite Str"] isKindOfClass:[NSString class]],
       "NSUserDefaults returns NSString for an updated string");

  PASS([obs count] == 6, "setting a string causes notification");
  
  [defs setObject:nil forKey:@"Test Suite Int"];
  PASS([obs count] == 7, "setting nil object twice causes notification");

  [defs removeObserver:obs forKeyPath:@"Test Suite Bool" context:NULL];
  [defs removeObserver:obs forKeyPath:@"Test Suite Int" context:NULL];
  [defs removeObserver:obs forKeyPath:@"Test Suite Str" context:NULL];

  [arp release];
  arp = nil;
  return 0;
}
