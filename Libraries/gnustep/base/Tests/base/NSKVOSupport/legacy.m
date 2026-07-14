#import <GNUstepBase/GNUstep.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSKeyValueObserving.h>

#import "Testing.h"

@interface Observee : NSObject
{
  NSString *_firstName;
  NSString *_middleName;
  NSString *_lastName;
}

- (NSString *) firstName;
- (void) setFirstName: (NSString *)name;

- (NSString *) middleName;
- (void) setMiddleName: (NSString *)name;

- (NSString *) lastName;
- (void) setLastName: (NSString *)name;

- (NSString *) shortFullName;
- (NSString *) fullName;

@end

@interface ObserveeMixed : Observee
{
  BOOL _trigger;
}

- (BOOL) trigger;
- (void) setTrigger: (BOOL) trigger;

@end

@implementation Observee

- (instancetype) init
{
  if ((self = [super init]) != nil)
    {
      _firstName = _middleName = _lastName = @"";
    }
  return self;
}

- (NSString *) firstName
{
  return _firstName;
}
- (void) setFirstName: (NSString *)name
{
  ASSIGN(_firstName, name);
}
- (NSString *) middleName
{
  return _middleName;
}
- (void) setMiddleName: (NSString *)name
{
  ASSIGN(_middleName, name);
}
- (NSString *) lastName
{
  return _lastName;
}
- (void) setLastName: (NSString *)name
{
  ASSIGN(_lastName, name);
}

- (NSString *) shortFullName
{
  return [NSString stringWithFormat: @"%@ %@", _firstName, _lastName];
}

- (NSString *) fullName
{
  return [NSString stringWithFormat: @"%@ %@ %@",
    _firstName, _middleName, _lastName];
}

@end

@implementation ObserveeMixed

- (BOOL) trigger
{
  return _trigger;
}
- (void) setTrigger: (BOOL) trigger
{
  _trigger = trigger;
}

// We expect this function to have priority over the legacy API
+ (NSSet *) keyPathsForValuesAffectingFullName
{
  return [NSSet setWithObject: @"trigger"];
}

@end

@interface Observer : NSObject
{
  @public
  NSString	*lastKeyPath;
  id 		lastObject;
  NSDictionary	*lastChange;
  int 		notificationCount;
}
@end

@implementation Observer

- (void) resetValues
{
  lastKeyPath = nil;
  lastObject = nil;
  lastChange = nil;
}

- (void) resetCounter
{
  notificationCount = 0;
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  notificationCount += 1;
  lastKeyPath = keyPath;
  lastObject = object;
  lastChange = change;
}

@end

void simpleDependency(void)
{
  Observer *o = [Observer new];
  Observee *e = [Observee new];

  NSArray *keys = [NSArray arrayWithObjects: @"firstName", @"lastName", nil];

  [Observee setKeys: keys
    triggerChangeNotificationsForDependentKey: @"fullName"];

  NSSet *s = [Observee keyPathsForValuesAffectingValueForKey: @"fullName"];
  NSSet *expectedSet = [NSSet setWithArray: keys];
  PASS_EQUAL(s, expectedSet, "'keyPathsForValuesAffectingValueForKey:' returns"
    " the correct values affecting 'fullName'")

  NSKeyValueObservingOptions opts
    = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;

  [e addObserver: o forKeyPath: @"fullName" options: opts context: NULL];

  [e setFirstName: @"Hey"];

  PASS_EQUAL(o->lastKeyPath, @"fullName", "last keypath is 'fullName'")
  PASS_EQUAL(o->lastObject, e, "last change object is correct")
  PASS(o->lastChange != nil, "last change is not nil")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeNewKey], @"Hey  ",
    "new entry in change dict correct")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeOldKey], @"  ",
    "old entry in change dict correct")
  PASS(o->notificationCount == 1, "notification count is 1")

  [e setMiddleName: @"Not"]; // no change notification

  [e setLastName: @"You"];
  PASS_EQUAL(o->lastKeyPath, @"fullName", "last keypath is 'fullName'")
  PASS_EQUAL(o->lastObject, e, "last change object is correct")
  PASS(o->lastChange != nil, "last change is not nil")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeNewKey],
    @"Hey Not You", "new entry in change dict correct")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeOldKey],
    @"Hey Not ", "old entry in change dict correct")
  PASS(o->notificationCount == 2, "notification count is 2")

  [e removeObserver: o forKeyPath: @"fullName"];

  RELEASE(o);
  RELEASE(e);
}

void registeringMultipleDependencies(void)
{
  Observer *o;
  Observee *e;
  NSArray *arr;
  NSSet *s;
  
  o = [Observer new];
  e = [Observee new];

  arr = [NSArray arrayWithObject: @"firstName"];
  [Observee setKeys:arr
    triggerChangeNotificationsForDependentKey: @"fullName"];
  s = [Observee keyPathsForValuesAffectingValueForKey: @"fullName"];
  PASS_EQUAL(s, [NSSet setWithArray: arr], "expecting 'firstName' as"
    " affecting key for 'fullName'")
    
  arr = [NSArray arrayWithObject: @"middleName"];
  [Observee setKeys: arr
    triggerChangeNotificationsForDependentKey: @"fullName"];
  s = [Observee keyPathsForValuesAffectingValueForKey: @"fullName"];
  PASS_EQUAL(s, [NSSet setWithArray: arr], "expecting 'middleName' as"
    " affecting key for 'fullName'")

  arr = [NSArray arrayWithObjects: @"firstName", @"lastName", nil];
  [Observee setKeys: arr
    triggerChangeNotificationsForDependentKey: @"shortFullName"];
  s = [Observee keyPathsForValuesAffectingValueForKey: @"shortFullName"];
  PASS_EQUAL(s, [NSSet setWithArray: arr], "expecting 'firstName' and"
    " 'lastName' as affecting key for 'fullName'")

  NSKeyValueObservingOptions opts
    = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;

  [e addObserver: o forKeyPath: @"fullName" options: opts context: NULL];

  [e setFirstName: @"Hey"];
  PASS(o->notificationCount == 0, "no change notification received when"
    " modifying firstName")

  [e setMiddleName: @"Not"];
  PASS_EQUAL(o->lastKeyPath, @"fullName", "last keypath is 'fullName'")
  PASS_EQUAL(o->lastObject, e, "last change object is correct")
  PASS(o->lastChange != nil, "last change is not nil")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeNewKey],
    @"Hey Not ", "new entry in change dict correct")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeOldKey],
    @"Hey  ", "old entry in change dict correct")
  PASS(o->notificationCount == 1, "change notification received when"
    " modifying middleName")

  [e setLastName: @"You"];
  PASS(o->notificationCount == 1, "no change notification received when"
    " modifying lastName")

  [e removeObserver: o forKeyPath: @"fullName"];
  [o resetCounter];
  [o resetValues];

  [e addObserver: o forKeyPath: @"shortFullName" options: opts context: NULL];

  [e setFirstName: @"Hello"];
  PASS_EQUAL(o->lastKeyPath, @"shortFullName",
    "last keypath is 'shortFullName'")
  PASS_EQUAL(o->lastObject, e, "last change object is correct")
  PASS(o->lastChange != nil, "last change is not nil")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeNewKey],
    @"Hello You", "new entry in change dict correct")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeOldKey],
    @"Hey You", "old entry in change dict correct")
  PASS(o->notificationCount == 1, "change notification received when"
    " modifying firstName")

  [e setMiddleName: @"Not"];
  PASS(o->notificationCount == 1, "no change notification received when"
    " modifying middleName")

  [o resetValues];

  [e setLastName: @"World"];
  PASS_EQUAL(o->lastKeyPath, @"shortFullName",
    "last keypath is 'shortFullName'")
  PASS_EQUAL(o->lastObject, e, "last change object is correct")
  PASS(o->lastChange != nil, "last change is not nil")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeNewKey],
    @"Hello World", "new entry in change dict correct")
  PASS_EQUAL([o->lastChange valueForKey: NSKeyValueChangeOldKey],
    @"Hello You", "old entry in change dict correct")
  PASS(o->notificationCount == 2, "change notification received when"
    " modifying lastName")

  [e removeObserver: o forKeyPath: @"shortFullName"];

  RELEASE(o);
  RELEASE(e);
}

void mixedLegacy(void)
{
  Observer *o = [Observer new];
  ObserveeMixed *e = [ObserveeMixed new];

  NSArray *keys = [NSArray arrayWithObjects: @"firstName", @"lastName", nil];

  [ObserveeMixed setKeys: keys
    triggerChangeNotificationsForDependentKey: @"fullName"];

  NSSet *s = [ObserveeMixed keyPathsForValuesAffectingValueForKey: @"fullName"];
  NSSet *expected = [NSSet setWithObject: @"trigger"];
  PASS_EQUAL(s, expected, "newer API has precedence over deprecated API")


  NSKeyValueObservingOptions opts
    = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;

  [e addObserver: o forKeyPath: @"fullName" options: opts context: NULL];

  // No trigger

  [e setFirstName: @"Hey"];
  [e setMiddleName: @"Not"];
  [e setLastName: @"You"];
  PASS(o->notificationCount == 0, "no change notification from either"
    " firstName, middleName, or lastName")

  // Trigger

  [e setTrigger: YES];
  PASS(o->notificationCount == 1, "change notification from trigger")

  [e removeObserver: o forKeyPath: @"fullName"];
  RELEASE(o);
  RELEASE(e);
}


int
main(int argc, char *argv[])
{
  START_SET("KVO Legacy Tests")

#if defined(__GNUC__)
  testHopeful = YES;
#endif

  simpleDependency();
  registeringMultipleDependencies();
  mixedLegacy();

#if defined(__GNUC__)
  testHopeful = YES;
#endif

  END_SET("KVO Legacy Tests")

  return 0;
}
