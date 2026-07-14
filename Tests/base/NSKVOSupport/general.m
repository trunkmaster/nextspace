/**
   general.m


   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by: Hugo Melder <hugo@algoriddim.com>
   Date: June 2024

   Based on WinObjC KVO tests by Microsoft Corporation.

   This file is part of GNUStep-base

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/
/**
  Copyright (c) Microsoft. All rights reserved.

  This code is licensed under the MIT License (MIT).

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
*/

#import <Foundation/Foundation.h>
#import "Testing.h"

#define	BOXF(V)	[NSNumber numberWithFloat: (V)]
#define	BOXI(V)	[NSNumber numberWithInteger: (V)]
#define	MPAIR(K,V)\
 [NSMutableDictionary dictionaryWithObjectsAndKeys: V, K, nil]
#define BOXBOOL(V) [NSNumber numberWithBool: (V)]

#if defined (__OBJC2__)
#define FLAKY_ON_GCC_START
#define FLAKY_ON_GCC_END
#else
#define FLAKY_ON_GCC_START \
  testHopeful = YES;
#define FLAKY_ON_GCC_END \
  testHopeful = NO;
#endif

@interface TestKVOSelfObserver : NSObject
{
  id _dummy;
}
@end
@implementation TestKVOSelfObserver
- (id)init
{
  self = [super init];
  if (self)
    {
      [self addObserver:self forKeyPath:@"dummy" options:0 context:nil];
    }
  return self;
}
- (void)dealloc
{
  [self removeObserver:self forKeyPath:@"dummy"];
  DESTROY(_dummy);
  DEALLOC
}
@end

@interface TestKVOChange : NSObject {
  NSString *_keypath;
  id _object;
  NSDictionary *_info;
  void *_context;
}

- (NSString *)keypath;
- (void)setKeypath:(NSString *)newKeypath;

- (id)object;
- (void)setObject:(id)newObject;

- (NSDictionary *)info;
- (void)setInfo:(NSDictionary *)newInfo;

- (void *)context;
- (void)setContext:(void *)newContext;

@end

@implementation TestKVOChange
+ (id) changeWithKeypath: (NSString *)keypath
                  object: (id)object
                    info: (NSDictionary *)info
                 context: (void *)context
{
  TestKVOChange *change = [[[self alloc] init] autorelease];
  [change setKeypath: keypath];
  [change setObject: object];
  [change setInfo: info];
  [change setContext: context];
  return change;
}

- (void) dealloc
{
  DESTROY(_keypath);
  DESTROY(_object);
  DESTROY(_info);
  DEALLOC
}

- (NSString *) keypath
{
  return _keypath;
}

- (void) setKeypath: (NSString *)newKeypath
{
  if (_keypath != newKeypath)
    {
      [_keypath release];
      _keypath = [newKeypath copy];
    }
}

- (id) object
{
  return _object;
}

- (void) setObject: (id)newObject
{
  ASSIGN(_object, newObject);
}

- (NSDictionary *)info
{
  return _info;
}

- (void) setInfo: (NSDictionary *)newInfo
{
  if (newInfo != _info)
    {
      [_info release];
      _info = [newInfo copy];
    }
}

- (void *) context
{
  return _context;
}

- (void) setContext:(void *)newContext
{
  _context = newContext;
}

@end

@interface TestKVOObserver : NSObject
{
  NSMutableDictionary *_changedKeypaths;
  NSLock              *_lock;
}
- (void)observeValueForKeyPath:(NSString *)keypath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
- (NSSet *)changesForKeypath:(NSString *)keypath;
- (NSInteger)numberOfObservedChanges;
@end

@implementation TestKVOObserver
- (id)init
{
  self = [super init];
  if (self)
    {
      _changedKeypaths = [NSMutableDictionary new];
      _lock = [NSLock new];
    }
  return self;
}
- (void)observeValueForKeyPath:(NSString *)keypath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  {
    NSMutableSet *changeSet = [_changedKeypaths objectForKey:keypath];
    if (!changeSet)
      {
        changeSet = [NSMutableSet set];
        [_changedKeypaths setObject: changeSet forKey: keypath];
      }
    [changeSet addObject:[TestKVOChange changeWithKeypath:keypath
                                                   object:object
                                                     info:change
                                                  context:context]];
  }
}
- (NSSet *)changesForKeypath:(NSString *)keypath
{
  [_lock lock];
  NSSet *paths = [[_changedKeypaths objectForKey:keypath] copy]; 
  [_lock unlock];
  return AUTORELEASE(paths);
}
- (void)clear
{
  [_lock lock];
  [_changedKeypaths removeAllObjects];
  [_lock unlock];
}
- (NSInteger)numberOfObservedChanges
{
  [_lock lock];
  NSInteger accumulator = 0;
  for (NSString *keypath in [_changedKeypaths allKeys])
    {
      accumulator += [[_changedKeypaths objectForKey:keypath] count];
    }
  [_lock unlock];
  return accumulator;
}

- (void) dealloc
{
  [_lock release];
  [_changedKeypaths release];
  DEALLOC
}
@end

struct TestKVOStruct
{
  int a, b, c;
};

/*
@interface TestKVOObject : NSObject
{
  NSString *_internal_derivedObjectProperty;
  NSString *_internal_keyDerivedTwoTimes;
  int       _manuallyNotifyingIntegerProperty;
  int       _ivarWithoutSetter;
}

@property (nonatomic, retain) NSString *nonNotifyingObjectProperty;

@property (nonatomic, retain) NSString            *basicObjectProperty;
@property (nonatomic, assign) uint32_t             basicPodProperty;
@property (nonatomic, assign) struct TestKVOStruct structProperty;

// derivedObjectProperty is derived from basicObjectProperty.
@property (nonatomic, readonly) NSString *derivedObjectProperty;

@property (nonatomic, retain) TestKVOObject   *cascadableKey;
@property (nonatomic, readonly) TestKVOObject *derivedCascadableKey;

@property (nonatomic, retain) id recursiveDependent1;
@property (nonatomic, retain) id recursiveDependent2;

@property (nonatomic, retain) NSMutableDictionary *dictionaryProperty;

@property (nonatomic, retain) id     boolTrigger1;
@property (nonatomic, retain) id     boolTrigger2;
@property (nonatomic, readonly) bool dependsOnTwoKeys;

- (void)incrementManualIntegerProperty;
@end
*/

@interface TestKVOObject : NSObject {
  NSString *_internal_derivedObjectProperty;
  NSString *_internal_keyDerivedTwoTimes;
  int _manuallyNotifyingIntegerProperty;
  int _ivarWithoutSetter;

  NSString *_nonNotifyingObjectProperty;
  NSString *_basicObjectProperty;
  uint32_t _basicPodProperty;
  struct TestKVOStruct _structProperty;
  TestKVOObject *_cascadableKey;
  id _recursiveDependent1;
  id _recursiveDependent2;
  NSMutableDictionary *_dictionaryProperty;
  id _boolTrigger1;
  id _boolTrigger2;
}

- (NSString *)nonNotifyingObjectProperty;
- (void)setNonNotifyingObjectProperty:(NSString *)newValue;

- (NSString *)basicObjectProperty;
- (void)setBasicObjectProperty:(NSString *)newValue;

- (uint32_t)basicPodProperty;
- (void)setBasicPodProperty:(uint32_t)newValue;

- (struct TestKVOStruct)structProperty;
- (void)setStructProperty:(struct TestKVOStruct)newValue;

- (NSString *)derivedObjectProperty;

- (TestKVOObject *)cascadableKey;
- (void)setCascadableKey:(TestKVOObject *)newValue;

- (TestKVOObject *)derivedCascadableKey;

- (id)recursiveDependent1;
- (void)setRecursiveDependent1:(id)newValue;

- (id)recursiveDependent2;
- (void)setRecursiveDependent2:(id)newValue;

- (NSMutableDictionary *)dictionaryProperty;
- (void)setDictionaryProperty:(NSMutableDictionary *)newValue;

- (id)boolTrigger1;
- (void)setBoolTrigger1:(id)newValue;

- (id)boolTrigger2;
- (void)setBoolTrigger2:(id)newValue;

- (bool)dependsOnTwoKeys;

// This modifies the internal integer property and notifies about it.
- (void)incrementManualIntegerProperty;

@end


@implementation TestKVOObject
- (void)dealloc
{
  [_cascadableKey release];
  [_nonNotifyingObjectProperty release];
  [_basicObjectProperty release];
  [_recursiveDependent1 release];
  [_recursiveDependent2 release];
  [_dictionaryProperty release];
  [_boolTrigger1 release];
  [_boolTrigger2 release];

  DEALLOC
}

+ (NSSet *)keyPathsForValuesAffectingDerivedObjectProperty
{
  return [NSSet setWithObject:@"basicObjectProperty"];
}

+ (NSSet *)keyPathsForValuesAffectingRecursiveDependent1
{
  return [NSSet setWithObject:@"recursiveDependent2"];
}

+ (NSSet *)keyPathsForValuesAffectingRecursiveDependent2
{
  return [NSSet setWithObject:@"recursiveDependent1"];
}

+ (NSSet *)keyPathsForValuesAffectingDerivedCascadableKey
{
  return [NSSet setWithObject:@"cascadableKey"];
}

+ (NSSet *)keyPathsForValuesAffectingKeyDependentOnSubKeypath
{
  return [NSSet setWithObject:@"dictionaryProperty.subDictionary"];
}

+ (NSSet *)keyPathsForValuesAffectingKeyDerivedTwoTimes
{
  return [NSSet setWithObject:@"derivedObjectProperty"];
}

+ (NSSet *)keyPathsForValuesAffectingDependsOnTwoKeys
{
  return [NSSet setWithArray: [NSArray arrayWithObjects:
    @"boolTrigger1", @"boolTrigger2", nil] ];
}

+ (NSSet *)keyPathsForValuesAffectingDependsOnTwoSubKeys
{
  return [NSSet setWithArray: [NSArray arrayWithObjects:
    @"cascadableKey.boolTrigger1", @"cascadableKey.boolTrigger2", nil] ];
}

- (bool)dependsOnTwoKeys
{
  return _boolTrigger1 != nil && _boolTrigger2 != nil;
}

- (bool)dependsOnTwoSubKeys
{
  return _cascadableKey.boolTrigger1 != nil
         && _cascadableKey.boolTrigger2 != nil;
}

- (id)keyDependentOnSubKeypath
{
  return [_dictionaryProperty objectForKey:@"subDictionary"];
}

+ (BOOL)automaticallyNotifiesObserversOfManuallyNotifyingIntegerProperty
{
  return NO;
}

+ (BOOL)automaticallyNotifiesObserversOfNonNotifyingObjectProperty
{
  return NO;
}

- (NSString *)derivedObjectProperty
{
  return _internal_derivedObjectProperty;
}

- (void)setBasicObjectProperty:(NSString *)basicObjectProperty
{
  [_basicObjectProperty release];
  _basicObjectProperty = [basicObjectProperty retain];
  _internal_derivedObjectProperty =
    [NSString stringWithFormat:@"!!!%@!!!", _basicObjectProperty];
  _internal_keyDerivedTwoTimes =
    [NSString stringWithFormat:@"---%@---", [self derivedObjectProperty]];
}

- (NSString *)keyDerivedTwoTimes
{
  return _internal_keyDerivedTwoTimes;
}

- (TestKVOObject *)derivedCascadableKey
{
  return _cascadableKey;
}

- (void)incrementManualIntegerProperty
{
  [self willChangeValueForKey:@"manuallyNotifyingIntegerProperty"];
  _manuallyNotifyingIntegerProperty++;
  [self didChangeValueForKey:@"manuallyNotifyingIntegerProperty"];
}

// Accessors

- (NSString *)nonNotifyingObjectProperty {
    return _nonNotifyingObjectProperty;
}

- (void)setNonNotifyingObjectProperty:(NSString *)newValue {
    ASSIGN(_nonNotifyingObjectProperty, newValue);
}

- (NSString *)basicObjectProperty {
    return _basicObjectProperty;
}

- (uint32_t)basicPodProperty {
    return _basicPodProperty;
}

- (void)setBasicPodProperty:(uint32_t)newValue {
    _basicPodProperty = newValue;
}

- (struct TestKVOStruct)structProperty {
    return _structProperty;
}

- (void)setStructProperty:(struct TestKVOStruct)newValue {
    _structProperty = newValue;
}

- (TestKVOObject *)cascadableKey {
    return _cascadableKey;
}

- (void)setCascadableKey:(TestKVOObject *)newValue {
    ASSIGN(_cascadableKey, newValue);
}

- (id)recursiveDependent1 {
    return _recursiveDependent1;
}

- (void)setRecursiveDependent1:(id)newValue {
    ASSIGN(_recursiveDependent1, newValue);
}

- (id)recursiveDependent2 {
    return _recursiveDependent2;
}

- (void)setRecursiveDependent2:(id)newValue {
    ASSIGN(_recursiveDependent2, newValue);
}

- (NSMutableDictionary *)dictionaryProperty {
    return _dictionaryProperty;
}

- (void)setDictionaryProperty:(NSMutableDictionary *)newValue {
    ASSIGN(_dictionaryProperty, newValue);
}

- (id)boolTrigger1 {
    return _boolTrigger1;
}

- (void)setBoolTrigger1:(id)newValue {
    ASSIGN(_boolTrigger1, newValue);
}

- (id)boolTrigger2 {
    return _boolTrigger2;
}

- (void)setBoolTrigger2:(id)newValue {
    ASSIGN(_boolTrigger2, newValue);
}

@end

@interface                          TestKVOObject2 : NSObject
{
  float _someFloat;
}

@end
@implementation TestKVOObject2
- (float)someFloat
{
  return _someFloat;
}
- (void)setSomeFloat:(float)newValue
{
  _someFloat = newValue;
}
@end

static void
BasicChangeNotification()
{
  START_SET("BasicChangeNotification");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  observed.basicObjectProperty = @"Hello";

  PASS_EQUAL([[observer changesForKeypath:@"basicObjectProperty"] count], 1,
             "One change on basicObjectProperty should have fired.");
  PASS_EQUAL([[observer changesForKeypath:@"basicPodProperty"] count], 0,
             "Zero changes on basicPodProperty should have fired.");
  PASS_EQUAL([[observer changesForKeypath:@"derivedObjectProperty"] count], 0,
             "Zero changes on derivedObjectProperty should have fired.");

  PASS_EQUAL([[[observer changesForKeypath:@"basicObjectProperty"] anyObject]
               object],
             observed,
             "The notification object should match the observed object.");
  PASS_EQUAL(
    nil,
    [[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info]
      objectForKey:NSKeyValueChangeOldKey],
    "There should be no old value included in the change notification.");
  PASS_EQUAL(
    [[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info]
      objectForKey:NSKeyValueChangeNewKey],
    @"Hello",
    "The new value stored in the change notification should be Hello.");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"],
            "remove observer should not throw");

  FLAKY_ON_GCC_END
  END_SET("BasicChangeNotification");
}

static void
ExclusiveChangeNotification()
{
  START_SET("ExclusiveChangeNotification");

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];
  TestKVOObserver *observer2 = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed addObserver:observer2
             forKeyPath:@"basicPodProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];

  [observed setBasicObjectProperty:@"Hello"];
  [observed setBasicPodProperty:1];

  PASS_EQUAL([[observer changesForKeypath:@"basicObjectProperty"] count], 1,
             "One change on basicObjectProperty should have fired.");
  PASS_EQUAL(
    [[observer2 changesForKeypath:@"basicObjectProperty"] count], 0,
    "No changes on basicObjectProperty for second observer should have fired.");
  PASS_EQUAL([[observer2 changesForKeypath:@"basicPodProperty"] count], 1,
             "One change on basicPodProperty should have fired.");
  PASS_EQUAL(
    [[observer changesForKeypath:@"basicPodProperty"] count], 0,
    "No changes on basicPodProperty for first observer should have fired.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"],
            "remove observer should not throw");
  PASS_RUNS([observed removeObserver:observer2 forKeyPath:@"basicPodProperty"],
            "remove observer should not throw");

  END_SET("ExclusiveChangeNotification");
}

static void
ManualChangeNotification()
{
  START_SET("ManualChangeNotification");

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"manuallyNotifyingIntegerProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed incrementManualIntegerProperty];

  PASS_EQUAL(
    [[observer changesForKeypath:@"manuallyNotifyingIntegerProperty"] count], 1,
    "One change on manuallyNotifyingIntegerProperty should have fired.");
  PASS_EQUAL(
    [[[[observer changesForKeypath:@"manuallyNotifyingIntegerProperty"]
      anyObject] info] objectForKey:NSKeyValueChangeNewKey],
    BOXI(1),
    "The new value stored in the change notification should be a boxed 1.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"manuallyNotifyingIntegerProperty"],
            "remove observer should not throw");

  END_SET("ManualChangeNotification");
}

static void
BasicChangeCaptureOld()
{
  START_SET("BasicChangeCaptureOld");

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionOld
                context:NULL];
  observed.basicObjectProperty = @"Hello";

  PASS_EQUAL([[observer changesForKeypath:@"basicObjectProperty"] count], 1,
             "One change on basicObjectProperty should have fired.");

  PASS_EQUAL([[[[observer changesForKeypath:@"basicObjectProperty"] anyObject]
               info] objectForKey:NSKeyValueChangeOldKey],
             [NSNull null],
             "The old value stored in the change notification should be null.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"],
            "remove observer should not throw");

  END_SET("BasicChangeCaptureOld");
}

static void
CascadingNotificationWithEmptyLeaf()
{
  START_SET("CascadingNotificationWithEmptyLeaf");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed
    addObserver:observer
     forKeyPath:@"cascadableKey.basicObjectProperty"
        options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
        context:NULL];

  TestKVOObject *subObject = [[[TestKVOObject alloc] init] autorelease];
  subObject.basicObjectProperty = @"Hello";
  observed.cascadableKey = subObject;

  PASS_EQUAL(
    [[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] count],
    1, "One change on cascadableKey.basicObjectProperty should have fired.");

  PASS_EQUAL([[[[observer
               changesForKeypath:@"cascadableKey.basicObjectProperty"]
               anyObject] info] objectForKey:NSKeyValueChangeOldKey],
             [NSNull null],
             "The old value stored in the change notification should be null.");
  
    [observer clear];

  TestKVOObject *subObject2 = [[[TestKVOObject alloc] init] autorelease];
  subObject2.basicObjectProperty = @"Hello";
  observed.cascadableKey = subObject2;

  PASS_EQUAL(
    [[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] count],
    1,
    "A second change on cascadableKey.basicObjectProperty should have fired.");

  subObject.basicObjectProperty = @"Spurious?";

  PASS(2 !=
         [[observer changesForKeypath:@"cascadableKey.basicObjectProperty"]
           count],
       "A change to the detached subkey should not have triggered a spurious "
       "notification.");

  PASS_EQUAL(
    [[[[observer changesForKeypath:@"cascadableKey.basicObjectProperty"]
      anyObject] info] objectForKey:NSKeyValueChangeOldKey],
    @"Hello",
    "The old value stored in the change notification should be Hello.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.basicObjectProperty"],
            "remove observer should not throw");

  FLAKY_ON_GCC_END
  END_SET("CascadingNotificationWithEmptyLeaf");
}

static void
PriorNotification()
{
  START_SET("PriorNotification");

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed
    addObserver:observer
     forKeyPath:@"basicObjectProperty"
        options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionPrior)
        context:NULL];
  observed.basicObjectProperty = @"Hello";

  PASS_EQUAL(
    [[observer changesForKeypath:@"basicObjectProperty"] count], 2,
    "Two changes on basicObjectProperty should have fired (one prior change).");

  PASS_EQUAL(
    [[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info]
      objectForKey:NSKeyValueChangeOldKey],
    [NSNull null],
    "The old value stored in the change notification should be null or nil.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"],
            "remove observer should not throw");

  END_SET("PriorNotification");
}

static void
DependentKeyNotification()
{
  START_SET("DependentKeyNotification");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"derivedObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  observed.basicObjectProperty = @"Hello";

  NSSet *basicChanges = [observer changesForKeypath:@"basicObjectProperty"];
  NSSet *derivedChanges = [observer changesForKeypath:@"derivedObjectProperty"];

  PASS(nil != derivedChanges, "derivedChanges should not be nil.");

  PASS([basicChanges count] == 0,
            "No changes on basicObjectProperty should have fired (we did not "
            "register for it).");
  PASS([derivedChanges count] == 1, "One change on derivedObjectProperty should have fired.");
  
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"derivedObjectProperty"],
            "remove observer should not throw");

  derivedChanges = [observer changesForKeypath:@"derivedObjectProperty"];
  PASS(nil != derivedChanges, "derivedChanges should not be nil.");
  PASS_EQUAL([[[derivedChanges anyObject] info] objectForKey:NSKeyValueChangeNewKey],
             @"!!!Hello!!!",
             "The new value stored in the change notification should be "
             "!!!Hello!!! (the derived object).");

  FLAKY_ON_GCC_END
  END_SET("DependentKeyNotification");
}

static void
PODNotification()
{
  START_SET("PODNotification");

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicPodProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  observed.basicPodProperty = 10;

  PASS_EQUAL([[observer changesForKeypath:@"basicPodProperty"] count], 1,
             "One change on basicPodProperty should have fired.");

  PASS([[[[[observer changesForKeypath:@"basicPodProperty"] anyObject] info]
         objectForKey:NSKeyValueChangeNewKey] isKindOfClass:[NSNumber class]],
       "The new value stored in the change notification should be an NSNumber "
       "instance.");
  PASS_EQUAL(
    [[[[observer changesForKeypath:@"basicPodProperty"] anyObject] info]
      objectForKey:NSKeyValueChangeNewKey],
    BOXI(10),
    "The new value stored in the change notification should be a boxed 10.");

  PASS_RUNS([observed removeObserver:observer forKeyPath:@"basicPodProperty"],
            "remove observer should not throw");

  END_SET("PODNotification");
}

static void
StructNotification()
{ // Basic change notification on a struct type
  START_SET("StructNotification");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  PASS_EQUAL([[observer changesForKeypath:@"basicObjectProperty"] count], 0,
             "No changes on basicObjectProperty should have fired.");
  [observed addObserver:observer
             forKeyPath:@"structProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  struct TestKVOStruct structValue = {1, 2, 3};
  observed.structProperty = structValue;

  PASS_EQUAL([[observer changesForKeypath:@"structProperty"] count], 1,
             "One change on structProperty should have fired.");

  PASS(YES ==
         [[[[[observer changesForKeypath:@"structProperty"] anyObject] info]
           objectForKey:NSKeyValueChangeNewKey] isKindOfClass:[NSValue class]],
       "The new value stored in the change notification should be "
       "an NSValue instance.");
  PASS(strcmp([[[[[observer changesForKeypath:@"structProperty"] anyObject]
                info] objectForKey:NSKeyValueChangeNewKey] objCType],
              @encode(struct TestKVOStruct))
         == 0,
       "The new objc type stored in the change notification should have "
       "an objc type matching our Struct.");

  PASS_RUNS([observed removeObserver:observer forKeyPath:@"structProperty"],
            "remove observer should not throw");
  PASS_RUNS([pool release], "release should not throw");

  END_SET("StructNotification");
}

static void
DisabledNotification()
{ // No notification for non-notifying keypaths.
  START_SET("DisabledNotification");
  FLAKY_ON_GCC_START

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"nonNotifyingObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  observed.nonNotifyingObjectProperty = @"Whatever";

  NSSet *changes = [observer changesForKeypath:@"nonNotifyingObjectProperty"];

  PASS([changes count] == 0,
            "No changes on nonNotifyingObjectProperty should have fired.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"nonNotifyingObjectProperty"],
            "remove observer should not throw");
  PASS_RUNS([pool release], "release should not throw");

  FLAKY_ON_GCC_END
  END_SET("DisabledNotification");
}

static void
DisabledInitialNotification()
{ // Initial notification for non-notifying keypaths.
  START_SET("DisabledInitialNotification");
  FLAKY_ON_GCC_START

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"nonNotifyingObjectProperty"
                options:NSKeyValueObservingOptionInitial
                context:NULL];
  observed.nonNotifyingObjectProperty = @"Whatever";

  NSSet *changes = [observer changesForKeypath:@"nonNotifyingObjectProperty"];

  

  PASS(nil != changes, "changes should not be nil.");
  PASS([changes count] == 1,
            "An INITIAL notification for nonNotifyingObjectProperty should "
            "have fired.");

  PASS_EQUAL(BOXF(NSKeyValueChangeSetting),
             [[[changes anyObject] info] objectForKey:NSKeyValueChangeKindKey],
             "The change kind should be NSKeyValueChangeSetting.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"nonNotifyingObjectProperty"],
            "remove observer should not throw");
  PASS_RUNS([pool release], "release should not throw");

  FLAKY_ON_GCC_END
  END_SET("DisabledInitialNotification");
}

static void
SetValueForKeyIvarNotification()
{ // Notification of ivar change through setValue:forKey:
  START_SET("SetValueForKeyIvarNotification");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"ivarWithoutSetter"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed setValue:BOXI(1024) forKey:@"ivarWithoutSetter"];

  PASS_EQUAL([[observer changesForKeypath:@"ivarWithoutSetter"] count], 1,
             "One change on ivarWithoutSetter should have fired (using "
             "setValue:forKey:).");

  PASS_EQUAL(
    [[[[observer changesForKeypath:@"ivarWithoutSetter"] anyObject] info]
      objectForKey:NSKeyValueChangeNewKey],
    BOXI(1024),
    "The new value stored in the change notification should a boxed 1024.");

  PASS_RUNS([observed removeObserver:observer forKeyPath:@"ivarWithoutSetter"],
            "remove observer should not throw");
  PASS_RUNS([pool release], "release should not throw");

  END_SET("SetValueForKeyIvarNotification");
}

static void
DictionaryNotification()
{ // Basic notification on a dictionary, which does not have properties or
  // ivars.
  START_SET("DictionaryNotification");
  FLAKY_ON_GCC_START

  NSMutableDictionary *observed = [NSMutableDictionary dictionary];
  TestKVOObserver     *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed setObject:[[[TestKVOObject alloc] init] autorelease]
               forKey:@"subKey"];

  [observed addObserver:observer
             forKeyPath:@"arbitraryValue"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed addObserver:observer
             forKeyPath:@"subKey.basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];

  [observed setObject:@"Whatever" forKey:@"arbitraryValue"];
  [observed setValue:@"Whatever2" forKeyPath:@"arbitraryValue"];
  [observed setValue:@"Whatever2" forKeyPath:@"subKey.basicObjectProperty"];

  NSSet *changes = [observer changesForKeypath:@"arbitraryValue"];

  PASS(nil != changes, "changes should not be nil.");
  PASS([changes count] == 2,
    "On a NSMutableDictionary, a change notification for arbitraryValue.");

  changes = [observer changesForKeypath:@"subKey.basicObjectProperty"];
    
  PASS(nil != changes, "changes should not be nil.");
  PASS([changes count] == 1,
             "On a NSMutableDictionary, a change notification for "
             "subKey.basicObjectProperty.");

  PASS_RUNS([observed removeObserver:observer forKeyPath:@"arbitraryValue"],
            "remove observer should not throw");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"subKey.basicObjectProperty"],
            "remove observer should not throw");

  FLAKY_ON_GCC_END
  END_SET("DictionaryNotification");
}

static void
BasicDeregistration()
{ // Deregistration test
  START_SET("BasicDeregistration");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"
                             context:NULL],
            "remove observer should not throw");
  observed.basicObjectProperty = @"Hello";

  PASS_EQUAL([[observer changesForKeypath:@"basicObjectProperty"] count], 0,
             "No changes on basicObjectProperty should have fired.");

  TestKVOObject *subObject = [[[TestKVOObject alloc] init] autorelease];
  observed.cascadableKey = subObject;

  [observed addObserver:observer
             forKeyPath:@"cascadableKey.basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.basicObjectProperty"
                             context:NULL],
            "remove observer should not throw");

  subObject.basicObjectProperty = @"Hello";

  NSSet *changes = [observer changesForKeypath:@"cascadableKey.basicObjectProperty"];

  PASS([changes count] == 0, "No changes on cascadableKey.basicObjectProperty should have fired.");

  FLAKY_ON_GCC_END
  END_SET("BasicDeregistration");
}

static void
DerivedKeyOnSubpath1()
{
  START_SET("DerivedKeyOnSubpath1");

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];

  [observed addObserver:observer
             forKeyPath:@"cascadableKey.derivedObjectProperty.length"
                options:NSKeyValueObservingOptionNew
                context:NULL];

  TestKVOObject *subObject = [[TestKVOObject alloc] init];
  subObject.basicObjectProperty = @"Hello";
  observed.cascadableKey = subObject;

  NSSet *changes = [observer changesForKeypath:@"cascadableKey.derivedObjectProperty.length"];

  PASS(nil != changes, "changes should not be nil.");
  PASS([changes count] == 1, "One change on cascade.derived.length should have fired.");
  PASS_EQUAL(
    [[[changes anyObject] info] objectForKey:NSKeyValueChangeNewKey],
    BOXI(11),
    "The new value stored in the change notification should a boxed 11.");

  PASS_RUNS([observed
              removeObserver:observer
                  forKeyPath:@"cascadableKey.derivedObjectProperty.length"
                     context:NULL],
            "remove observer should not throw");

  [observer clear];

  subObject.basicObjectProperty = @"Whatever";

  PASS_EQUAL(
    [[observer changesForKeypath:@"cascadableKey.derivedObjectProperty.length"]
      count],
    0, "No additional changes on cascade.derived.length should have fired.");

  [subObject release];
  [observer release];
  [observed release];

  END_SET("DerivedKeyOnSubpath1");
}

static void
Subpath1()
{ // Test normally-nested observation and value replacement
  START_SET("Subpath1");

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];
  [observed addObserver:observer
             forKeyPath:@"cascadableKey.cascadableKey"
                options:0
                context:nil];

  TestKVOObject *child = [[TestKVOObject alloc] init];

  [observed setCascadableKey:child];
  [observed setCascadableKey:nil];

  PASS_EQUAL(2, [observer numberOfObservedChanges],
             "Two changes should have been observed.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.cascadableKey"],
            "remove observer should not throw");

  [child release];
  [observer release];
  [observed release];

  END_SET("Subpath1");
}

static void
SubpathSubpath()
{ // Test deeply-nested observation
  START_SET("SubpathSubpath");

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];
  [observed addObserver:observer
             forKeyPath:@"cascadableKey.cascadableKey.cascadableKey"
                options:0
                context:nil];

  TestKVOObject *child = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject *childChild = [[[TestKVOObject alloc] init] autorelease];

  observed.cascadableKey = child;
  observed.cascadableKey.cascadableKey = childChild;
  observed.cascadableKey.cascadableKey = nil;
  observed.cascadableKey = nil;

  PASS_EQUAL(4, [observer numberOfObservedChanges],
             "Four changes should have been observed.");

  PASS_RUNS([observed
              removeObserver:observer
                  forKeyPath:@"cascadableKey.cascadableKey.cascadableKey"],
            "remove observer should not throw");

  [observer release];
  [observed release];

  END_SET("SubpathSubpath");
}

static void
SubpathWithHeadReplacement()
{ // Test key value replacement and re-registration (1)
  START_SET("SubpathWithHeadReplacement");

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];

  TestKVOObject *child = [[[TestKVOObject alloc] init] autorelease];
  observed.cascadableKey = child;

  [observed addObserver:observer
             forKeyPath:@"cascadableKey.cascadableKey"
                options:0
                context:nil];

  [observed setCascadableKey:nil];

  PASS_EQUAL(1, [observer numberOfObservedChanges],
             "One change should have been observed.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.cascadableKey"],
            "remove observer should not throw");

  [observer release];
  [observed release];

  END_SET("SubpathWithHeadReplacement");
}

static void
SubpathWithTailAndHeadReplacement()
{ // Test key value replacement and re-registration (2)
  START_SET("SubpathWithTailAndHeadReplacement");

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];

  TestKVOObject *child = [[[TestKVOObject alloc] init] autorelease];
  observed.cascadableKey = child;

  TestKVOObject *childChild = [[[TestKVOObject alloc] init] autorelease];
  child.cascadableKey = childChild;

  [observed addObserver:observer
             forKeyPath:@"cascadableKey.cascadableKey.cascadableKey"
                options:0
                context:nil];

  observed.cascadableKey.cascadableKey = nil;
  observed.cascadableKey = nil;

  PASS_EQUAL(2, [observer numberOfObservedChanges],
             "Two changes should have been observed.");

  PASS_RUNS([observed
              removeObserver:observer
                  forKeyPath:@"cascadableKey.cascadableKey.cascadableKey"],
            "remove observer should not throw");

  [observer release];
  [observed release];

  END_SET("SubpathWithTailAndHeadReplacement");
}

static void
SubpathWithMultipleReplacement()
{ // Test key value replacement and re-registration (3)
  START_SET("SubpathWithMultipleReplacement");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];
  TestKVOObject   *child1 = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject   *child2 = [[[TestKVOObject alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"cascadableKey.cascadableKey"
                options:0
                context:nil];

  observed.cascadableKey = child1;

  observed.cascadableKey = child2;

  observed.cascadableKey = nil;

  PASS_EQUAL(3, [observer numberOfObservedChanges],
             "Three changes should have been observed.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.cascadableKey"],
            "remove observer should not throw");

  [observer release];
  [observed release];

  FLAKY_ON_GCC_END
  END_SET("SubpathWithMultipleReplacement");
}

static void
SubpathWithMultipleReplacement2()
{ // Test a more complex nested observation system
  START_SET("SubpathWithMultipleReplacement2");

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];
  TestKVOObject   *child1 = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject   *child2 = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject   *child3 = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject   *child4 = [[[TestKVOObject alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"cascadableKey.cascadableKey"
                options:0
                context:nil];

  observed.cascadableKey = child1;

  observed.cascadableKey = nil;

  observed.cascadableKey = child2;

  observed.cascadableKey = nil;

  observed.cascadableKey = child3;
  child3.cascadableKey = child4;

  observed.cascadableKey = nil;

  PASS_EQUAL(7, [observer numberOfObservedChanges],
             "Seven changes should have "
             "been observed.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.cascadableKey"],
            "remove observer should not throw");

  [observer release];
  [observed release];

  END_SET("SubpathWithMultipleReplacement2");
}

static void
SubpathsWithInitialNotification()
{ // Test initial observation on nested keys
  START_SET("SubpathsWithInitialNotification");

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];
  TestKVOObject   *child1 = [[[TestKVOObject alloc] init] autorelease];
  observed.cascadableKey = child1;

  [observed
    addObserver:observer
     forKeyPath:@"cascadableKey.basicObjectProperty"
        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
        context:nil];
  [observed
    addObserver:observer
     forKeyPath:@"cascadableKey.basicPodProperty"
        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
        context:nil];
  [observed
    addObserver:observer
     forKeyPath:@"cascadableKey.derivedObjectProperty"
        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
        context:nil];

  PASS_EQUAL(3, [observer numberOfObservedChanges],
             "Three changes should have "
             "been observed.");
  PASS_EQUAL([NSNull null],
             [[[[observer
               changesForKeypath:@"cascadableKey.basicObjectProperty"]
               anyObject] info] objectForKey:NSKeyValueChangeNewKey],
             "The initial value of basicObjectProperty should be nil.");
  PASS_EQUAL(BOXI(0),
             [[[[observer changesForKeypath:@"cascadableKey.basicPodProperty"]
               anyObject] info] objectForKey:NSKeyValueChangeNewKey],
             "The initial value of basicPodProperty should be 0.");
  PASS_EQUAL([NSNull null],
             [[[[observer
               changesForKeypath:@"cascadableKey.derivedObjectProperty"]
               anyObject] info] objectForKey:NSKeyValueChangeNewKey],
             "The initial value of derivedObjectProperty should be nil.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.basicObjectProperty"],
            "remove observer should not throw");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.basicPodProperty"],
            "remove observer should not throw");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.derivedObjectProperty"],
            "remove observer should not throw");

  END_SET("SubpathsWithInitialNotification");
}

static void
CyclicDependency()
{ // Make sure that dependency loops don't cause crashes.
  START_SET("CyclicDependency");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];
  PASS_RUNS([observed addObserver:observer
                       forKeyPath:@"recursiveDependent1"
                          options:1
                          context:nil],
            "add observer should not throw");
  PASS_RUNS([observed addObserver:observer
                       forKeyPath:@"recursiveDependent2"
                          options:1
                          context:nil],
            "add observer should not throw");
  observed.recursiveDependent1 = @"x";
  observed.recursiveDependent2 = @"y";
  PASS(4 == [observer numberOfObservedChanges],
             "Four changes should have "
             "been observed.");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"recursiveDependent1"],
            "remove observer should not throw");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"recursiveDependent2"],
            "remove observer should not throw");

  [observer release];
  [observed release];

  FLAKY_ON_GCC_END
  END_SET("CyclicDependency");
}

static void
ObserveAllProperties()
{
  START_SET("ObserveAllProperties");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = AUTORELEASE([[TestKVOObject alloc] init]);
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed addObserver:observer
             forKeyPath:@"basicPodProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed addObserver:observer
             forKeyPath:@"structProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed addObserver:observer
             forKeyPath:@"derivedObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed addObserver:observer
             forKeyPath:@"cascadableKey"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed addObserver:observer
             forKeyPath:@"cascadableKey.basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];

  struct TestKVOStruct s = {1, 2, 3};

  observed.basicObjectProperty = @"WHAT"; // 2 here
  observed.basicPodProperty = 10;         // 1
  observed.structProperty = s;

  TestKVOObject *subObject = [[[TestKVOObject alloc] init] autorelease];
  subObject.basicObjectProperty = @"Hello";
  observed.cascadableKey = subObject; // 2 here

  PASS([observer numberOfObservedChanges] == 6,
             "There should have been 6 observed changes on the observer.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"],
            "remove observer for keyPath basicObjectProperty should not throw");
  PASS_RUNS([observed removeObserver:observer forKeyPath:@"basicPodProperty"],
            "remove observer for keyPath basicPodProperty should not throw");
  PASS_RUNS([observed removeObserver:observer forKeyPath:@"structProperty"],
            "remove observer for keyPath structProperty should not throw");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"derivedObjectProperty"],
            "remove observer should not throw");
  PASS_RUNS([observed removeObserver:observer forKeyPath:@"cascadableKey"],
            "remove observer for keyPath cascadableKey should not throw");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.basicObjectProperty"],
            "remove observer for keyPath cascadableKey.basicObjectProperty "
            "should not throw");

  FLAKY_ON_GCC_END
  END_SET("ObserveAllProperties");
}

static void
RemoveWithoutContext()
{ // Test removal without specifying context.
  START_SET("RemoveWithoutContext");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[TestKVOObject alloc] init];
  TestKVOObserver *observer = [[TestKVOObserver alloc] init];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:(void *) (1)];
  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:(void *) (2)];

  PASS_RUNS(
    [observed removeObserver:observer forKeyPath:@"basicObjectProperty"],
    "removing observer forKeyPath=basicObjectProperty should not throw");

  observed.basicObjectProperty = @"";

  PASS([observer numberOfObservedChanges] == 1,
             "There should be only one change notification despite "
             "registering two with contexts.");

  PASS_RUNS(
    [observed removeObserver:observer forKeyPath:@"basicObjectProperty"],
    "removing observer forKeyPath=basicObjectProperty should not throw");

  [observer release];
  [observed release];

  FLAKY_ON_GCC_END
  END_SET("RemoveWithoutContext");
}

static void
RemoveWithDuplicateContext()
{ // Test adding duplicate contexts
  START_SET("RemoveWithDuplicateContext");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:(void *) (1)];
  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:(void *) (1)];

  observed.basicObjectProperty = @"";

  PASS([observer numberOfObservedChanges] == 2,
             "There should be two observed changes, despite the identical "
             "registration.");

  PASS_RUNS(
    [observed removeObserver:observer
                  forKeyPath:@"basicObjectProperty"
                     context:(void *) (1)],
    "removing observer forKeyPath=basicObjectProperty should not throw");

  observed.basicObjectProperty = @"";

  PASS([observer numberOfObservedChanges] == 3,
             "There should be one additional observed change; the removal "
             "should have only effected one.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"
                             context:(void *) (1)],
            "removing observer forKeyPath=basicObjectProperty does not throw");

  FLAKY_ON_GCC_END
  END_SET("RemoveWithDuplicateContext");
}

static void
RemoveOneOfTwoObservers()
{ // Test adding duplicate contexts
  START_SET("RemoveOneOfTwoObservers");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];
  TestKVOObserver *observer2 = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed addObserver:observer2
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];

  observed.basicObjectProperty = @"";

  PASS([observer numberOfObservedChanges] == 1,
             "There should be one observed change per observer.");
  PASS([observer2 numberOfObservedChanges] == 1,
             "There should be one observed change per observer.");

  PASS_RUNS([observed removeObserver:observer2
                          forKeyPath:@"basicObjectProperty"],
            "removing observer2 should not throw");

  observed.basicObjectProperty = @"";

  PASS([observer numberOfObservedChanges] == 2,
             "There should be one additional observed change; the removal "
             "should have only removed the second observer.");

  PASS([observer2 numberOfObservedChanges] == 1,
             "Observer2 should have only observed one change.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"],
            "removing observer should not throw");

  FLAKY_ON_GCC_END
  END_SET("RemoveOneOfTwoObservers");
}

static void
RemoveUnregistered()
{ // Test removing an urnegistered observer
  START_SET("RemoveUnregistered");
  FLAKY_ON_GCC_START

  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  PASS_EXCEPTION(
    [observed removeObserver:observer
                  forKeyPath:@"basicObjectProperty"
                     context:(void *) (1)],
    (NSString*)nil,
    "Removing an unregistered observer should throw an exception.")

  FLAKY_ON_GCC_END
  END_SET("RemoveUnregistered");
}

static void
SelfObservationDealloc()
{ // Test deallocation of an object that is its own observer
  TestKVOSelfObserver *observed = [[TestKVOSelfObserver alloc] init];
  PASS_RUNS([observed release], "deallocating self-observing object should not "
                                "throw");
}

static void
DeepSubpathWithCompleteTree()
{
  START_SET("DeepSubpathWithCompleteTree");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject2    *floatGuy = [[[TestKVOObject2 alloc] init] autorelease];
  floatGuy.someFloat = 1.234f;
  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject   *child = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];
  child.dictionaryProperty = [NSMutableDictionary
    dictionaryWithObjectsAndKeys:floatGuy, @"floatGuy", nil];
  observed.cascadableKey = child;
  [observed addObserver:observer
             forKeyPath:@"cascadableKey.dictionaryProperty.floatGuy.someFloat"
                options:0
                context:nil];
  observed.cascadableKey = child;
  PASS([observer numberOfObservedChanges] == 1,
             "One change should have "
             "been observed.");

  PASS_RUNS(
    [observed
      removeObserver:observer
          forKeyPath:@"cascadableKey.dictionaryProperty.floatGuy.someFloat"],
    "remove observer should not throw");
  PASS_RUNS([pool release], "release pool should not throw");

  END_SET("DeepSubpathWithCompleteTree");
}

static void
DeepSubpathWithIncompleteTree()
{
  START_SET("DeepSubpathWithIncompleteTree");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  // The same test as above, but testing nil value reconstitution to ensure that
  // the keypath is wired up properly.
  TestKVOObject   *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];
  [observed addObserver:observer
             forKeyPath:@"cascadableKey.dictionaryProperty.floatGuy.someFloat"
                options:0
                context:nil];

  TestKVOObject2 *floatGuy = [[[TestKVOObject2 alloc] init] autorelease];
  floatGuy.someFloat = 1.234f;
  TestKVOObject *child = [[[TestKVOObject alloc] init] autorelease];
  child.dictionaryProperty = [NSMutableDictionary
    dictionaryWithObjectsAndKeys:floatGuy, @"floatGuy", nil];

  observed.cascadableKey = child;
  observed.cascadableKey = child;

  PASS([observer numberOfObservedChanges] == 2,
             "Two changes should have "
             "been observed.");

  PASS_RUNS(
    [observed
      removeObserver:observer
          forKeyPath:@"cascadableKey.dictionaryProperty.floatGuy.someFloat"],
    "remove observer should not throw");
  PASS_RUNS([pool release], "release pool should not throw");

  END_SET("DeepSubpathWithIncompleteTree");
}

static void
SubpathOnDerivedKey()
{
  START_SET("SubpathOnDerivedKey");
  FLAKY_ON_GCC_START

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject     *child = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject     *child2 = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  observed.cascadableKey = child;
  child.dictionaryProperty =
    [NSMutableDictionary dictionaryWithDictionary:MPAIR(@"Key1" , @"Value1")];

  [observed addObserver:observer
             forKeyPath:@"derivedCascadableKey.dictionaryProperty.Key1"
                options:0
                context:nil];

  observed.cascadableKey = child2;
  child2.dictionaryProperty =
    [NSMutableDictionary dictionaryWithDictionary:MPAIR(@"Key1" , @"Value2")];

  PASS(2 == [observer numberOfObservedChanges],
             "Two changes should have "
             "been observed.");

  PASS_RUNS([observed
              removeObserver:observer
                  forKeyPath:@"derivedCascadableKey.dictionaryProperty.Key1"],
            "remove observer should not throw");
  PASS_RUNS([pool release], "release pool should not throw");

  FLAKY_ON_GCC_END
  END_SET("SubpathOnDerivedKey");
}

static void
SubpathWithDerivedKeyBasedOnSubpath()
{
  START_SET("SubpathWithDerivedKeyBasedOnSubpath");
  FLAKY_ON_GCC_START

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  // key dependent on sub keypath is dependent upon
  // dictionaryProperty.subDictionary
  NSMutableDictionary *mutableDictionary = MPAIR(
    @"subDictionary", MPAIR(@"floatGuy" , BOXF(1.234))
  );
  observed.dictionaryProperty = mutableDictionary;

  [observed addObserver:observer
             forKeyPath:@"keyDependentOnSubKeypath.floatGuy"
                options:0
                context:nil];

  [mutableDictionary setObject: MPAIR(@"floatGuy" , BOXF(3.456)) forKey: @"subDictionary"]; // 1 notification

  NSMutableDictionary *mutableDictionary2 = MPAIR(
    @"subDictionary", MPAIR(@"floatGuy" , BOXF(5.678))
  );

  observed.dictionaryProperty = mutableDictionary2; // 2nd notification

  [mutableDictionary2 setObject: MPAIR(@"floatGuy" , BOXF(7.890)) forKey: @"subDictionary"]; // 3rd notification

  PASS(3 == [observer numberOfObservedChanges],
             "Three changes should have "
             "been observed.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"keyDependentOnSubKeypath.floatGuy"],
            "remove observer should not throw");
  PASS_RUNS([pool release], "release pool should not throw");

  FLAKY_ON_GCC_END
  END_SET("SubpathWithDerivedKeyBasedOnSubpath");
}

static void
MultipleObservers()
{
  START_SET("MultipleObservers");
  FLAKY_ON_GCC_START

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];
  TestKVOObserver   *observer2 = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  observed.basicObjectProperty = @"Hello";

  PASS_EQUAL([[observer changesForKeypath:@"basicObjectProperty"] count], 1,
             "One change on basicObjectProperty should have fired.");
  PASS_EQUAL([[observer changesForKeypath:@"basicPodProperty"] count], 0,
             "Zero changes on basicPodProperty should have fired.");
  PASS_EQUAL([[observer2 changesForKeypath:@"basicObjectProperty"] count], 0,
             "Zero changes on basicObjectProperty should have fired (obs 2).");
  PASS_EQUAL([[observer2 changesForKeypath:@"basicPodProperty"] count], 0,
             "Zero changes on basicPodProperty should have fired (obs 2).");

  [observed addObserver:observer2
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  observed.basicObjectProperty = @"Goodbye";

  PASS_EQUAL([[observer changesForKeypath:@"basicObjectProperty"] count], 2,
             "Two changes on basicObjectProperty should have fired.");
  PASS_EQUAL([[observer changesForKeypath:@"basicPodProperty"] count], 0,
             "Zero changes on basicPodProperty should have fired.");
  PASS_EQUAL([[observer2 changesForKeypath:@"basicObjectProperty"] count], 1,
             "One change on basicObjectProperty should have fired (obs 2).");
  PASS_EQUAL([[observer2 changesForKeypath:@"basicPodProperty"] count], 0,
             "Zero changes on basicPodProperty should have fired (obs 2).");

  PASS_EQUAL([[[observer2 changesForKeypath:@"basicObjectProperty"] anyObject]
               object],
             observed,
             "The notification object should match the observed object.");
  PASS_EQUAL(
    nil,
    [[[[observer2 changesForKeypath:@"basicObjectProperty"] anyObject] info]
      objectForKey:NSKeyValueChangeOldKey],
    "There should be no old value included in the change notification.");
  PASS_EQUAL([[[[observer2 changesForKeypath:@"basicObjectProperty"] anyObject]
               info] objectForKey:NSKeyValueChangeNewKey],
             @"Goodbye", "The new value should be 'Goodbye'.");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"],
            "remove observer "
            "should not throw");
  PASS_RUNS([observed removeObserver:observer2
                          forKeyPath:@"basicObjectProperty"],
            "remove observer "
            "should not throw");

  PASS_RUNS([pool release], "release pool should not throw");

  FLAKY_ON_GCC_END
  END_SET("MultipleObservers");
}

static void
DerivedKeyDependentOnDerivedKey()
{
  START_SET("DerivedKeyDependentOnDerivedKey");
  FLAKY_ON_GCC_START

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  observed.basicObjectProperty = @"Hello";

  [observed addObserver:observer
             forKeyPath:@"keyDerivedTwoTimes"
                options:NSKeyValueObservingOptionNew
                context:nil];

  observed.basicObjectProperty = @"KVO";

  PASS(1 == [observer numberOfObservedChanges],
             "One change should have "
             "been observed.");
  PASS_EQUAL([[[[observer changesForKeypath:@"keyDerivedTwoTimes"] anyObject]
               info] objectForKey:NSKeyValueChangeNewKey],
             @"---!!!KVO!!!---", "The new value should be '---!!!KVO!!!---'.");

  [observer clear];

  observed.basicObjectProperty = @"$$$";

  PASS(1 == [observer numberOfObservedChanges],
             "One change should have "
             "been observed.");
  PASS_EQUAL([[[[observer changesForKeypath:@"keyDerivedTwoTimes"] anyObject]
               info] objectForKey:NSKeyValueChangeNewKey],
             @"---!!!$$$!!!---", "The new value should be '---!!!$$$!!!---'.");

  PASS_RUNS([observed removeObserver:observer forKeyPath:@"keyDerivedTwoTimes"],
            "remove observer "
            "should not throw");
  PASS_RUNS([pool release], "release pool should not throw");

  FLAKY_ON_GCC_END
  END_SET("DerivedKeyDependentOnDerivedKey");
}

static void
DerivedKeyDependentOnTwoKeys()
{
  START_SET("DerivedKeyDependentOnTwoKeys");
  FLAKY_ON_GCC_START

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"dependsOnTwoKeys"
                options:NSKeyValueObservingOptionNew
                context:nil];

  observed.boolTrigger1 = @"firstObject";

  PASS(1 == [observer numberOfObservedChanges],
             "One change should have "
             "been observed.");
  PASS_EQUAL(BOXBOOL(NO),
             [[[[observer changesForKeypath:@"dependsOnTwoKeys"] anyObject]
               info] objectForKey:NSKeyValueChangeNewKey],
             "The new value "
             "should be NO.");

  [observer clear];
  observed.boolTrigger2 = @"secondObject";

  PASS(1 == [observer numberOfObservedChanges],
             "One change should have been observed.");
  PASS_EQUAL(BOXBOOL(YES),
             [[[[observer changesForKeypath:@"dependsOnTwoKeys"] anyObject]
               info] objectForKey:NSKeyValueChangeNewKey],
             "The new value should be YES.");

  PASS_RUNS([observed removeObserver:observer forKeyPath:@"dependsOnTwoKeys"],
            "remove observer should not throw");
  PASS_RUNS([pool release], "release pool should not throw");

  FLAKY_ON_GCC_END
  END_SET("DerivedKeyDependentOnTwoKeys");
}

static void
DerivedKeyDependentOnTwoSubKeys()
{
  START_SET("DerivedKeyDependentOnTwoSubKeys");
  FLAKY_ON_GCC_START

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestKVOObject     *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject     *child = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObserver   *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed addObserver:observer
             forKeyPath:@"dependsOnTwoSubKeys"
                options:NSKeyValueObservingOptionNew
                context:nil];

  observed.cascadableKey = child;
  PASS(1 == [observer numberOfObservedChanges],
             "One change should have been observed.");
  PASS_EQUAL(BOXBOOL(NO),
             [[[[observer changesForKeypath:@"dependsOnTwoSubKeys"] anyObject]
               info] objectForKey:NSKeyValueChangeNewKey],
             "new value should be NO");

  [observer clear];
  child.boolTrigger1 = @"firstObject";

  PASS(1 == [observer numberOfObservedChanges],
             "One change should have been observed.");
  PASS_EQUAL(BOXBOOL(NO),
             [[[[observer changesForKeypath:@"dependsOnTwoSubKeys"] anyObject]
               info] objectForKey:NSKeyValueChangeNewKey],
             "new value should be NO");

  [observer clear];
  child.boolTrigger2 = @"secondObject";

  PASS(1 == [observer numberOfObservedChanges],
             "One change should have been observed.");
  PASS_EQUAL(BOXBOOL(YES),
             [[[[observer changesForKeypath:@"dependsOnTwoSubKeys"] anyObject]
               info] objectForKey:NSKeyValueChangeNewKey],
             "new value should be YES");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"dependsOnTwoSubKeys"],
            "remove observer should not throw");
  PASS_RUNS([pool release], "release pool should not throw");

  FLAKY_ON_GCC_END
  END_SET("DerivedKeyDependentOnTwoSubKeys");
}

static void
ObserverInfoShouldNotStompOthers()
{
  TestKVOObject *observed = [[[TestKVOObject alloc] init] autorelease];
  TestKVOObject *oldObj = [[[TestKVOObject alloc] init] autorelease];
  observed.cascadableKey = oldObj;
  observed.cascadableKey.basicObjectProperty = @"Original";
  TestKVOObserver *observer = [[[TestKVOObserver alloc] init] autorelease];

  [observed
    addObserver:observer
     forKeyPath:@"cascadableKey"
        options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
        context:nil];
  [observed
    addObserver:observer
     forKeyPath:@"cascadableKey.basicObjectProperty"
        options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
        context:nil];

  TestKVOObject *newObj = [[[TestKVOObject alloc] init] autorelease];
  newObj.basicObjectProperty = @"NewObj";
  observed.cascadableKey = newObj;

  NSDictionary *baseInfo =
    [[[observer changesForKeypath:@"cascadableKey"] anyObject] info];
  PASS(nil != baseInfo, "There should be a change notification.");
  PASS_EQUAL(oldObj, [baseInfo objectForKey: NSKeyValueChangeOldKey],
             "The old value should be the old object.");
  PASS_EQUAL(newObj, [baseInfo objectForKey: NSKeyValueChangeNewKey],
             "The new value should be the new object.");

  NSDictionary *subInfo = [[[observer
    changesForKeypath:@"cascadableKey.basicObjectProperty"] anyObject] info];
  PASS(nil != subInfo, "There should be a change notification.");
  PASS_EQUAL(@"Original", [subInfo objectForKey: NSKeyValueChangeOldKey],
             "The old value should be the old object's basicObjectProperty.");
  PASS_EQUAL(@"NewObj", [subInfo objectForKey: NSKeyValueChangeNewKey],
             "The new value should be the new object's basicObjectProperty.");

  PASS_RUNS([observed removeObserver:observer forKeyPath:@"cascadableKey"],
            "remove observer should not throw");
  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"cascadableKey.basicObjectProperty"],
            "remove observer should not throw");
}

static void
SetValueForKeyPropertyNotification()
{ // Notification through setValue:forKey: to make sure that we do
  // not get two notifications for the same change.
  START_SET("SetValueForKeyPropertyNotification");

  TestKVOObject   *observed = AUTORELEASE([TestKVOObject new]);
  TestKVOObserver *observer = AUTORELEASE([TestKVOObserver new]);

  [observed addObserver:observer
             forKeyPath:@"basicObjectProperty"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  [observed setValue:BOXI(1024) forKey:@"basicObjectProperty"];

  PASS_EQUAL([[observer changesForKeypath:@"basicObjectProperty"] count], 1,
             "ONLY one change on basicObjectProperty should have fired "
             "(using setValue:forKey: should not fire twice).");

  PASS_EQUAL(
    [[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info]
      objectForKey:NSKeyValueChangeNewKey],
    BOXI(1024),
    "The new value stored in the change notification should a boxed 1024.");

  PASS_RUNS([observed removeObserver:observer
                          forKeyPath:@"basicObjectProperty"],
            "remove observer does not throw");

  END_SET("SetValueForKeyPropertyNotification");
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];

  BasicChangeNotification();
  ExclusiveChangeNotification();
  ManualChangeNotification();
  BasicChangeCaptureOld();
  CascadingNotificationWithEmptyLeaf();
  PriorNotification();
  DependentKeyNotification();
  PODNotification();
  StructNotification();
  DisabledNotification();
  DisabledInitialNotification();
  SetValueForKeyIvarNotification();
  SetValueForKeyPropertyNotification();
  DictionaryNotification();
  BasicDeregistration();
  DerivedKeyOnSubpath1();
  Subpath1();
  SubpathSubpath();
  SubpathWithHeadReplacement();
  SubpathWithTailAndHeadReplacement();
  SubpathWithMultipleReplacement();
  SubpathWithMultipleReplacement2();
  SubpathsWithInitialNotification();
  CyclicDependency();
  ObserveAllProperties();
  RemoveWithoutContext();
  RemoveWithDuplicateContext();
  RemoveOneOfTwoObservers();
  RemoveUnregistered();
  SelfObservationDealloc();
  DeepSubpathWithCompleteTree();
  DeepSubpathWithIncompleteTree();
  SubpathOnDerivedKey();
  SubpathWithDerivedKeyBasedOnSubpath();
  MultipleObservers();
  DerivedKeyDependentOnDerivedKey();
  DerivedKeyDependentOnTwoKeys();
  DerivedKeyDependentOnTwoSubKeys();
  ObserverInfoShouldNotStompOthers();

  DESTROY(arp);
  return 0;
}
