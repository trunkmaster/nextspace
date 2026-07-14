/**
   kvoToMany.m

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

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.

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

#define BOXF(V) [NSNumber numberWithFloat: (V)]
#define BOXI(V) [NSNumber numberWithInteger: (V)]

#if defined(__OBJC2__)

@interface Observee : NSObject
{
  NSMutableArray *_bareArray;
  NSMutableArray *_manualNotificationArray;
  NSMutableArray *_kvcMediatedArray;
  NSMutableArray *_arrayWithHelpers;
  NSMutableSet   *_setWithHelpers;
  NSMutableSet   *_kvcMediatedSet;
  NSMutableSet   *_manualNotificationSet;
  NSSet          *_roSet;
}

- (NSArray *)manualNotificationArray;
- (NSSet *)setWithHelpers;

@end

typedef void (^ChangeCallback)(NSString *, id, NSDictionary *, void *);
typedef void (^PerformBlock)(Observee *);

#define CHANGE_CB                                                              \
  ^(NSString * keyPath, id object, NSDictionary * change, void *context)

@implementation Observee
- (instancetype)init
{
  self = [super init];
  if (self)
    {
      _bareArray = [NSMutableArray new];
      _manualNotificationArray = [NSMutableArray new];
      _kvcMediatedArray = [NSMutableArray new];
      _arrayWithHelpers = [NSMutableArray new];
      _setWithHelpers = [NSMutableSet new];
      _kvcMediatedSet = [NSMutableSet new];
      _manualNotificationSet = [NSMutableSet new];
    }
  return self;
}

- (void)dealloc
{
  [_bareArray release];
  [_manualNotificationArray release];
  [_kvcMediatedArray release];
  [_arrayWithHelpers release];
  [_setWithHelpers release];
  [_kvcMediatedSet release];
  [_manualNotificationSet release];
  [_roSet release];
  [super dealloc];
}

/* Used for testing NSKeyValueFastMutableSet which is used in
 * +[NSKeyValueMutableSet setForKey:ofObject:] */

- (NSSet *)proxySet
{
  return _kvcMediatedSet;
}

- (void)addProxySetObject:(id)obj
{
  [_kvcMediatedSet addObject:obj];
}

- (void)removeProxySetObject:(id)obj
{
  [_kvcMediatedSet removeObject:obj];
}

- (void)addProxySet:(NSSet *)set
{
  [_kvcMediatedSet unionSet:set];
}

- (void)removeProxySet:(NSSet *)set
{
  [_kvcMediatedSet minusSet:set];
}

/* Used for testing NSKeyValueSlowMutableSet which is used
 * when no add or remove method is available. */
- (NSSet *)proxyRoSet
{
  return _roSet;
}

- (void)setProxyRoSet:(NSSet *)set
{
  ASSIGN(_roSet, set);
}

- (void)addObjectToBareArray:(NSObject *)object
{
  [_bareArray addObject:object];
}

- (void)addObjectToManualArray:(NSObject *)object
{
  NSIndexSet *indexes =
    [NSIndexSet indexSetWithIndex:[_manualNotificationArray count]];
  [self willChange:NSKeyValueChangeInsertion
    valuesAtIndexes:indexes
             forKey:@"manualNotificationArray"];
  [_manualNotificationArray addObject:object];
  [self didChange:NSKeyValueChangeInsertion
    valuesAtIndexes:indexes
             forKey:@"manualNotificationArray"];
}

- (void)removeObjectFromManualArrayIndex:(NSUInteger)index
{
  NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:index];
  [self willChange:NSKeyValueChangeRemoval
    valuesAtIndexes:indexes
             forKey:@"manualNotificationArray"];
  [_manualNotificationArray removeObjectAtIndex:index];
  [self didChange:NSKeyValueChangeRemoval
    valuesAtIndexes:indexes
             forKey:@"manualNotificationArray"];
}

- (NSArray *)manualNotificationArray
{
  return _manualNotificationArray;
}

- (void)insertObject:(NSObject *)object
  inArrayWithHelpersAtIndex:(NSUInteger)index
{
  [_arrayWithHelpers insertObject:object atIndex:index];
}

- (void)removeObjectFromArrayWithHelpersAtIndex:(NSUInteger)index
{
  [_arrayWithHelpers removeObjectAtIndex:index];
}

- (NSSet *)setWithHelpers
{
  return _setWithHelpers;
}

- (void)addSetWithHelpersObject:(id)obj
{
  [_setWithHelpers addObject:obj];
}

- (void)removeSetWithHelpersObject:(id)obj
{
  [_setWithHelpers removeObject:obj];
}

- (void)addSetWithHelpers:(NSSet *)set
{
  [_setWithHelpers unionSet:set];
}

- (void)removeSetWithHelpers:(NSSet *)set
{
  [_setWithHelpers minusSet:set];
}

- (void)intersectSetWithHelpers:(NSSet *)set
{
  [_setWithHelpers intersectSet:set];
}

- (void)setSetWithHelpers:(NSSet *)set
{
  [_setWithHelpers setSet:set];
}

- (void)manualSetAddObject:(id)obj
{
  NSSet *set = [NSSet setWithObject:obj];
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueUnionSetMutation
                 usingObjects:set];
  [_manualNotificationSet addObject:obj];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueUnionSetMutation
                usingObjects:set];
}

- (void)manualSetRemoveObject:(id)obj
{
  NSSet *set = [NSSet setWithObject:obj];
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueMinusSetMutation
                 usingObjects:set];
  [_manualNotificationSet removeObject:obj];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueMinusSetMutation
                usingObjects:set];
}

- (void)manualUnionSet:(NSSet *)set
{
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueUnionSetMutation
                 usingObjects:set];
  [_manualNotificationSet unionSet:set];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueUnionSetMutation
                usingObjects:set];
}

- (void)manualMinusSet:(NSSet *)set
{
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueMinusSetMutation
                 usingObjects:set];
  [_manualNotificationSet minusSet:set];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueMinusSetMutation
                usingObjects:set];
}

- (void)manualIntersectSet:(NSSet *)set
{
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueIntersectSetMutation
                 usingObjects:set];
  [_manualNotificationSet intersectSet:set];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueIntersectSetMutation
                usingObjects:set];
}

- (void)manualSetSet:(NSSet *)set
{
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueSetSetMutation
                 usingObjects:set];
  [_manualNotificationSet setSet:set];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueSetSetMutation
                usingObjects:set];
}

@end

@interface TestObserver : NSObject
@property (nonatomic, strong)
  NSMutableArray<void (^)(NSString *, id, NSDictionary *, void *)> *callbacks;
@property (nonatomic) NSUInteger                                    hits;
@property (nonatomic) NSUInteger callbackIndex;
@end

@implementation TestObserver
- (instancetype)init
{
  self = [super init];
  if (self)
    {
      _callbacks = [NSMutableArray new];
      _hits = 0;
      _callbackIndex = 0;
    }
  return self;
}

- (void)dealloc
{
  [_callbacks release];
  [super dealloc];
}

- (void)performBlock:(void (^)(void))block
  andExpectChangeCallbacks:
    (NSArray<void (^)(NSString *, id, NSDictionary *, void *)> *)callbacks
{
  self.hits = 0;
  self.callbackIndex = 0;
  ASSIGN(_callbacks, callbacks);

  block();
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if (self.callbacks.count > 0)
    {
      void (^callback)(NSString *, id, NSDictionary *, void *)
        = self.callbacks[_callbackIndex];
      _callbackIndex = (_callbackIndex + 1) % [_callbacks count];
      callback(keyPath, object, change, context);
    }
  self.hits++;
}
@end

@interface                                  TestFacade : NSObject
@property (nonatomic, strong) Observee     *observee;
@property (nonatomic, strong) TestObserver *observer;
@end

@implementation TestFacade
+ (instancetype)newWithObservee:(Observee *)observee
{
  return [[TestFacade alloc] initWithObservee:observee];
}

- (instancetype)initWithObservee:(Observee *)observee
{
  self = [super init];
  if (self)
    {
      ASSIGN(_observee, observee);
      _observer = [TestObserver new];
    }
  return self;
}

- (void)dealloc
{
  [_observee release];
  [_observer release];
  [super dealloc];
}

- (void)performBlock:(void (^)(Observee *))block
  andExpectChangeCallbacks:
    (NSArray<void (^)(NSString *, id, NSDictionary *, void *)> *)callbacks
{
  @try
    {
      [_observer
                    performBlock:^{
                      block(_observee);
                    }
        andExpectChangeCallbacks:callbacks];
    }
  @catch (NSException *exception)
    {
      NSLog(@"Test failed with exception: %@", exception);
    }
}

- (void)observeKeyPath:(NSString *)keyPath
               withOptions:(NSKeyValueObservingOptions)options
           performingBlock:(void (^)(Observee *))block
  andExpectChangeCallbacks:
    (NSArray<void (^)(NSString *, id, NSDictionary *, void *)> *)callbacks
{
  [self
                performBlock:^(Observee *observee) {
                  [observee addObserver:self.observer
                             forKeyPath:keyPath
                                options:options
                                context:nil];
                  block(observee);
                  [observee removeObserver:self.observer forKeyPath:keyPath];
                }
    andExpectChangeCallbacks:callbacks];
}

- (NSUInteger)hits
{
  return [_observer hits];
}
@end

@interface                                 DummyObject : NSObject
@property (nonatomic, copy) NSString      *name;
@property (nonatomic, retain) DummyObject *sub;
@end

@implementation DummyObject
+ (instancetype)makeDummy
{
  DummyObject *ret = [[DummyObject new] autorelease];
  ret.name = @"Value";
  return ret;
}

- (void)dealloc
{
  [_name release];
  [_sub release];
  [super dealloc];
}

@end

static void
ToMany_NoNotificationOnBareArray()
{
  START_SET("ToMany_NoNotificationOnBareArray");

  Observee   *observee = [Observee new];
  TestFacade *facade = [TestFacade newWithObservee:observee];

  [facade observeKeyPath:@"bareArray"
                 withOptions:0
             performingBlock:^(Observee *observee) {
               [observee addObjectToBareArray:@"hello"];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      ^(NSString *keyPath, id object, NSDictionary *change,
        void *context) { // Any notification here is illegal.
        PASS(NO, "Any notification here is illegal.");
      }, nil]];
  PASS([facade hits] == 0, "No notifications were sent");

  [facade release];
  [observee release];

  END_SET("ToMany_NoNotificationOnBareArray");
}

static void
ToMany_NotifyingArray()
{
  START_SET("ToMany_NotifyingArray");

  ChangeCallback firstInsertCallback;
  ChangeCallback secondInsertCallback;
  ChangeCallback removalCallback;
  ChangeCallback illegalChangeNotification;

  /* Callback Setup */

  firstInsertCallback = CHANGE_CB
  {
    NSIndexSet *indexes;

    PASS_EQUAL(BOXI(NSKeyValueChangeInsertion), change[NSKeyValueChangeKindKey],
               "firstInsertCallback: Change is an insertion");

    indexes = change[NSKeyValueChangeIndexesKey];

    PASS(indexes != nil, "firstInsertCallback: Indexes are not nil");
    PASS([indexes firstIndex] == 0, "firstInsertCallback: Index is 0");

    if (![change[NSKeyValueChangeNotificationIsPriorKey] boolValue])
      {
        PASS_EQUAL(@"object1", [change[NSKeyValueChangeNewKey] objectAtIndex:0],
                   "firstInsertCallback: New object is 'object1'");
      }
  };

  secondInsertCallback = CHANGE_CB
  {
    NSIndexSet *indexes;

    // We should get an add on index 1 of "object2"
    PASS_EQUAL(BOXI(NSKeyValueChangeInsertion), change[NSKeyValueChangeKindKey],
               "secondInsertCallback: Change is an insertion");

    indexes = change[NSKeyValueChangeIndexesKey];

    PASS(indexes != nil, "secondInsertCallback: Indexes are not nil");
    PASS([indexes firstIndex] == 1, "secondInsertCallback: Index is 1");

    if (![change[NSKeyValueChangeNotificationIsPriorKey] boolValue])
      {
        PASS_EQUAL(@"object2", [change[NSKeyValueChangeNewKey] objectAtIndex:0],
                   "secondInsertCallback: New object is 'object2'");
      }
  };

  removalCallback = CHANGE_CB
  {
    NSIndexSet *indexes;

    PASS_EQUAL(BOXI(NSKeyValueChangeRemoval), change[NSKeyValueChangeKindKey],
               "removalCallback: Change is a removal");

    indexes = change[NSKeyValueChangeIndexesKey];

    PASS(indexes != nil, "removalCallback: Indexes are not nil");
    PASS([indexes firstIndex] == 0, "removalCallback: Index is 0");
    if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue])
      {
        PASS_EQUAL(@"object1", [change[NSKeyValueChangeOldKey] objectAtIndex:0],
                   "removalCallback: Old object is 'object1'");
      }
  };

  illegalChangeNotification
    = CHANGE_CB{PASS(NO, "illegalChangeNotification: was called")};

  /* Testing manually notifiying array (utilizes add and remove meths in
   * Observee) */

  Observee   *observee;
  TestFacade *facade;

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];

  // This test expects one change for each key; any more than that is a failure.
  [facade observeKeyPath:@"manualNotificationArray"
                 withOptions:NSKeyValueObservingOptionOld
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               [observee addObjectToManualArray:@"object1"];
               [observee addObjectToManualArray:@"object2"];
               [observee removeObjectFromManualArrayIndex:0];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      firstInsertCallback, secondInsertCallback, removalCallback,
      illegalChangeNotification, nil]];
  PASS([facade hits] == 3, "Three notifications were sent");

  [facade release];
  [observee release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];
  // This test expects two change notifications for each key; any more than that
  // is a failure.
  [facade observeKeyPath:@"manualNotificationArray"
                 withOptions:NSKeyValueObservingOptionPrior
                             | NSKeyValueObservingOptionOld
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               [observee addObjectToManualArray:@"object1"];
               [observee addObjectToManualArray:@"object2"];
               [observee removeObjectFromManualArrayIndex:0];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      firstInsertCallback, firstInsertCallback, secondInsertCallback,
      secondInsertCallback, removalCallback, removalCallback,
      illegalChangeNotification, nil]];

  PASS([facade hits] == 6, "Six notifications were sent");
  PASS_EQUAL(([NSArray arrayWithObjects: @"object2", nil]),
    [observee manualNotificationArray],
    "Final array is 'object2'");

  // This test expects one change notification: the initial one. Any more than
  // that is a failure.
  ChangeCallback initialNotificationCallback = CHANGE_CB
  {
    NSArray *expectedArray = [NSArray arrayWithObjects: @"object2", nil];
    PASS_EQUAL(expectedArray, change[NSKeyValueChangeNewKey],
      "Initial notification: New array is 'object2'");
    NSLog(@"Initial notification: New array is %@",
          change[NSKeyValueChangeNewKey]);
  };

  [facade observeKeyPath:@"manualNotificationArray"
                 withOptions:NSKeyValueObservingOptionInitial
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      initialNotificationCallback, illegalChangeNotification, nil
    ]];
  PASS([facade hits] == 1, "One notification was sent");

  /* Testing mediated array */
  [facade observeKeyPath:@"kvcMediatedArray"
                 withOptions:NSKeyValueObservingOptionOld
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               // This array is not assisted with setter functions and should go
               // through the get/mutate/set codepath.
               NSMutableArray *mediatedVersionOfArray =
                 [observee mutableArrayValueForKey:@"kvcMediatedArray"];
               [mediatedVersionOfArray addObject:@"object1"];
               [mediatedVersionOfArray addObject:@"object2"];
               [mediatedVersionOfArray removeObjectAtIndex:0];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      firstInsertCallback, secondInsertCallback, removalCallback,
      illegalChangeNotification, nil]];
  PASS([facade hits] == 3, "Three notifications were sent");

  [facade release];
  [observee release];

  /* Testing array with helpers */
  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];
  [facade observeKeyPath:@"arrayWithHelpers"
                 withOptions:NSKeyValueObservingOptionOld
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               // This array is assisted by setter functions, and should also
               // dispatch one notification per change.
               NSMutableArray *mediatedVersionOfArray =
                 [observee mutableArrayValueForKey:@"arrayWithHelpers"];
               [mediatedVersionOfArray addObject:@"object1"];
               [mediatedVersionOfArray addObject:@"object2"];
               [mediatedVersionOfArray removeObjectAtIndex:0];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      firstInsertCallback, secondInsertCallback, removalCallback,
      illegalChangeNotification, nil]];
  PASS([facade hits] == 3, "Three notifications were sent");

  [facade release];
  [observee release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];
  // In this test, we use the same arrayWithHelpers as above, but interact with
  // it manually.
  [facade observeKeyPath:@"arrayWithHelpers"
                 withOptions:NSKeyValueObservingOptionOld
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               // This array is assisted by setter functions, and should also
               // dispatch one notification per change.
               [observee insertObject:@"object1" inArrayWithHelpersAtIndex:0];
               [observee insertObject:@"object2" inArrayWithHelpersAtIndex:1];
               [observee removeObjectFromArrayWithHelpersAtIndex:0];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      firstInsertCallback, secondInsertCallback, removalCallback,
      illegalChangeNotification, nil]];
  PASS([facade hits] == 3, "Three notifications were sent");

  [facade release];
  [observee release];

  END_SET("ToMany_NotifyingArray");
}

static void
ToMany_KVCMediatedArrayWithHelpers_AggregateFunction()
{
  START_SET("ToMany_KVCMediatedArrayWithHelpers_AggregateFunction");

  ChangeCallback insertCallbackPost;
  ChangeCallback illegalChangeNotification;

  insertCallbackPost = CHANGE_CB
  {
    PASS(change[NSKeyValueChangeNotificationIsPriorKey] == nil, "Post change");
    PASS_EQUAL(BOXI(NSKeyValueChangeSetting), change[NSKeyValueChangeKindKey],
               "Change is a setting");
    PASS_EQUAL(BOXI(0), change[NSKeyValueChangeOldKey], "Old value is 0");
    PASS_EQUAL(BOXI(1), change[NSKeyValueChangeNewKey], "New value is 1");

    NSIndexSet *indexes = change[NSKeyValueChangeIndexesKey];
    PASS(indexes == nil, "Indexes are nil");
  };

  illegalChangeNotification = CHANGE_CB
  {
    PASS(NO, "illegalChangeNotification");
  };

  Observee   *observee = [Observee new];
  TestFacade *facade = [TestFacade newWithObservee:observee];
  [facade observeKeyPath:@"arrayWithHelpers.@count"
                 withOptions:NSKeyValueObservingOptionOld
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               // This array is assisted by setter functions, and should also
               // dispatch one notification per change.
               NSMutableArray *mediatedVersionOfArray =
                 [observee mutableArrayValueForKey:@"arrayWithHelpers"];
               [mediatedVersionOfArray addObject:@"object1"];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      insertCallbackPost, illegalChangeNotification, nil]];
  PASS([facade hits] == 1, "One notification was sent");

  [facade release];
  [observee release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];
  // In this test, we use the same arrayWithHelpers as above, but interact with
  // it manually.
  [facade observeKeyPath:@"arrayWithHelpers.@count"
                 withOptions:NSKeyValueObservingOptionOld
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               // This array is assisted by setter functions, and should also
               // dispatch one notification per change.
               [observee insertObject:@"object1" inArrayWithHelpersAtIndex:0];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      insertCallbackPost, illegalChangeNotification, nil]];
  PASS([facade hits] == 1, "One notification was sent");

  [facade release];
  [observee release];

  END_SET("ToMany_KVCMediatedArrayWithHelpers_AggregateFunction");
}

static void
ToMany_ToOne_ShouldDowngradeForOrderedObservation()
{
  START_SET("ToMany_ToOne_ShouldDowngradeForOrderedObservation");

  ChangeCallback insertCallbackPost;
  ChangeCallback illegalChangeNotification;

  insertCallbackPost = CHANGE_CB
  {
    PASS(change[NSKeyValueChangeNotificationIsPriorKey] == nil, "Post change");
    PASS_EQUAL(BOXI(NSKeyValueChangeSetting), change[NSKeyValueChangeKindKey],
               "Change is a setting");
    NSArray *expectedOld = [NSArray arrayWithObjects: @"Value", nil];
    PASS_EQUAL(expectedOld, change[NSKeyValueChangeOldKey],
               "Old value is correct");
    NSArray *expectedNew = [NSArray arrayWithObjects: @"Value", @"Value", nil];
    PASS_EQUAL(expectedNew, change[NSKeyValueChangeNewKey],
               "New value is correct");
    NSIndexSet *indexes = change[NSKeyValueChangeIndexesKey];
    PASS(indexes == nil, "Indexes are nil");
  };

  illegalChangeNotification = CHANGE_CB
  {
    PASS(NO, "illegalChangeNotification");
  };

  Observee *observee = [Observee new];
  [observee insertObject:[DummyObject makeDummy] inArrayWithHelpersAtIndex:0];

  TestFacade *facade = [TestFacade newWithObservee:observee];
  [facade observeKeyPath:@"arrayWithHelpers.name"
                 withOptions:NSKeyValueObservingOptionOld
                             | NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               // This array is assisted by setter functions, and should also
               // dispatch one notification per change.
               [observee insertObject:[DummyObject makeDummy]
                 inArrayWithHelpersAtIndex:0];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      insertCallbackPost, illegalChangeNotification, nil]];
  PASS([facade hits] == 1, "One notification was sent");

  [facade release];
  [observee release];

  END_SET("ToMany_ToOne_ShouldDowngradeForOrderedObservation");
}

static void
ObserverInformationShouldNotLeak()
{
  START_SET("ObserverInformationShouldNotLeak");

  ChangeCallback onlyNewCallback;
  ChangeCallback illegalChangeNotification;

  onlyNewCallback = CHANGE_CB
  {
    PASS(change[NSKeyValueChangeNewKey] != nil, "New key is not nil");
    PASS(change[NSKeyValueChangeOldKey] == nil, "Old key is nil");
  };

  illegalChangeNotification = CHANGE_CB
  {
    PASS(NO, "illegalChangeNotification");
  };

  Observee   *observee = [Observee new];
  TestFacade *firstFacade = [TestFacade newWithObservee:observee];
  [observee
    addObserver:firstFacade.observer
     forKeyPath:@"manualNotificationArray"
        options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
        context:nil];

  TestFacade *facade = [TestFacade newWithObservee:observee];
  [facade observeKeyPath:@"manualNotificationArray"
                 withOptions:NSKeyValueObservingOptionNew
             performingBlock:^(Observee *observee) {
               [observee addObjectToManualArray:@"object1"];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects: onlyNewCallback, illegalChangeNotification, nil]];

  [observee removeObserver:firstFacade.observer
                forKeyPath:@"manualNotificationArray"];

  PASS([facade hits] == 1, "One notification was sent");

  [facade release];
  [firstFacade release];
  [observee release];

  END_SET("ObserverInformationShouldNotLeak");
}

static void
NSArrayShouldNotBeObservable()
{
  START_SET("NSArrayShouldNotBeObservable");

  NSArray      *test = [NSArray arrayWithObjects: BOXI(1), BOXI(2), BOXI(3), nil];
  TestObserver *observer = [TestObserver new];
  PASS_EXCEPTION([test addObserver:observer
                        forKeyPath:@"count"
                           options:0
                           context:nil],
    (NSString*)nil,
    "NSArray is not observable");

  // These would throw anyways because there should be no observer for the key
  // path, but test anyways
  PASS_EXCEPTION([test removeObserver:observer forKeyPath:@"count"],
    (NSString*)nil,
    "Check removing non-existent observer");
  PASS_EXCEPTION([test removeObserver:observer forKeyPath:@"count" context:nil],
    (NSString*)nil,
                 "Check removing non-existent observer");

  [observer release];

  END_SET("NSArrayShouldNotBeObservable");
}

static void
NSArrayShouldThrowWhenTryingToObserveIndexesOutOfRange()
{
  START_SET("NSArrayShouldThrowWhenTryingToObserveIndexesOutOfRange");

  NSArray      *o1 = AUTORELEASE([Observee new]);
  NSArray      *o2 = AUTORELEASE([Observee new]);
  NSArray      *test = [NSArray arrayWithObjects: o1, o2, nil];
  TestObserver *observer = [TestObserver new];

  PASS_EXCEPTION([test addObserver:observer
                   toObjectsAtIndexes:[NSIndexSet indexSetWithIndex:4]
                           forKeyPath:@"bareArray"
                              options:0
                              context:nil],
    (NSString*)nil,
    "Observe index out of range");

  [observer release];

  END_SET("NSArrayShouldThrowWhenTryingToObserveIndexesOutOfRange");
}

static void
NSArrayObserveElements()
{
  START_SET("NSArrayObserveElements");

  Observee *observee1 = [Observee new];
  Observee *observee2 = [Observee new];
  Observee *observee3 = [Observee new];

  NSArray      *observeeArray = [NSArray arrayWithObjects: observee1, observee2, observee3, nil];
  TestObserver *observer = [TestObserver new];
  PASS_RUNS([observeeArray
                     addObserver:observer
              toObjectsAtIndexes:[NSIndexSet
                                   indexSetWithIndexesInRange:NSMakeRange(0, 2)]
                      forKeyPath:@"manualNotificationArray"
                         options:(NSKeyValueObservingOptionOld
                                  | NSKeyValueObservingOptionNew)
                         context:nil],
            "Observe first two elements");

  // First two elements in range for observation so observer will receive
  // changes
  [observeeArray[0] addObjectToManualArray:@"object1"];
  [observeeArray[0] addObjectToManualArray:@"object2"];
  PASS([observer hits] == 2, "First two elements in range for observation");

  [observeeArray[1] addObjectToManualArray:@"object1"];
  PASS([observer hits] == 3, "Second element in range for observation");

  // But the third element is not so observer will not receive changes
  [observeeArray[2] addObjectToManualArray:@"object1"];
  PASS([observer hits] == 3, "Third element not in range for observation");

  PASS_RUNS([observeeArray
                    removeObserver:observer
              fromObjectsAtIndexes:[NSIndexSet
                                     indexSetWithIndexesInRange:NSMakeRange(0,
                                                                            1)]
                        forKeyPath:@"manualNotificationArray"],
            "remove observer from first element");

  // Removed observer from first element, so modifying it will not report a
  // change
  [observeeArray[0] addObjectToManualArray:@"object3"];
  PASS([observer hits] == 3, "First element observer removed");

  // But the second element is still being observed
  [observeeArray[1] addObjectToManualArray:@"object2"];
  PASS([observer hits] == 4, "Second element still being observed");

  PASS_RUNS([observeeArray
                    removeObserver:observer
              fromObjectsAtIndexes:[NSIndexSet
                                     indexSetWithIndexesInRange:NSMakeRange(1,
                                                                            1)]
                        forKeyPath:@"manualNotificationArray"],
            "remove observer from second element");

  [observeeArray[1] addObjectToManualArray:@"object3"];
  PASS([observer hits] == 4, "Second element observer removed");

  [observer release];
  [observee1 release];
  [observee2 release];
  [observee3 release];

  END_SET("NSArrayObserveElements");
}

static void
NSSetShouldNotBeObservable()
{
  START_SET("NSSetShouldNotBeObservable");

  NSSet        *test = [NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil];
  TestObserver *observer = [TestObserver new];
  PASS_EXCEPTION([test addObserver:observer
                        forKeyPath:@"count"
                           options:0
                           context:nil],
    (NSString*)nil,
    "NSSet is not observable");

  // These would throw anyways because there should be no observer for the key
  // path, but test anyways
  PASS_EXCEPTION([test removeObserver:observer forKeyPath:@"count"],
    (NSString*)nil,
    "Check removing non-existent observer");
  PASS_EXCEPTION([test removeObserver:observer forKeyPath:@"count" context:nil],
    (NSString*)nil,
    "Check removing non-existent observer");

  [observer release];

  END_SET("NSSetShouldNotBeObservable");
}

static void
NSSetMutationMethods()
{
  START_SET("NSSetMutationMethods");

  __block BOOL setSetChanged = NO;

  // Union with @({@(1), @(2), @(3)}) to get @({@(1), @(2), @(3)})
  ChangeCallback unionCallback = CHANGE_CB
  {
    PASS_EQUAL(BOXI(NSKeyValueChangeInsertion), change[NSKeyValueChangeKindKey],
               "Union change is an insertion");
    NSSet *expected = [NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil];
    PASS_EQUAL(change[NSKeyValueChangeNewKey], expected,
               "Union new key is correct");
    PASS(change[NSKeyValueChangeOldKey] == nil, "Union old key is nil");
  };

  // Minus with @({@(1)}) to get @({@(2), @(3)})
  ChangeCallback minusCallback = CHANGE_CB
  {
    PASS_EQUAL(change[NSKeyValueChangeKindKey], BOXI(NSKeyValueChangeRemoval),
               "Minus change is a removal");
    PASS_EQUAL(change[NSKeyValueChangeOldKey], [NSSet setWithObject:BOXI(1)],
               "Minus old key is correct");
    PASS(change[NSKeyValueChangeNewKey] == nil, "Minus new key is nil");
  };

  // Add @(1) to @({@(2), @(3)}) to get @({@(1), @(2), @(3)})
  ChangeCallback addCallback = CHANGE_CB
  {
    PASS_EQUAL(BOXI(NSKeyValueChangeInsertion), change[NSKeyValueChangeKindKey],
               "Add change is an insertion");
    NSLog(@"Change %@", change);
    PASS_EQUAL([NSSet setWithObject:BOXI(1)], change[NSKeyValueChangeNewKey],
               "Add new key is correct");
    PASS(change[NSKeyValueChangeOldKey] == nil, "Add old key is nil");
  };

  // Remove @(1) from @({@(1), @(2), @(3)}) to get @({@(2), @(3)})
  ChangeCallback removeCallback = CHANGE_CB
  {
    PASS_EQUAL(BOXI(NSKeyValueChangeRemoval), change[NSKeyValueChangeKindKey],
               "Remove change is a removal");
    PASS_EQUAL([NSSet setWithObject:BOXI(1)], change[NSKeyValueChangeOldKey],
               "Remove old key is correct");
    PASS(change[NSKeyValueChangeNewKey] == nil, "Remove new key is nil");
  };

  // Intersect with @({@(2)}) to get @({2})
  ChangeCallback intersectCallback = CHANGE_CB
  {
    PASS_EQUAL(BOXI(NSKeyValueChangeRemoval), change[NSKeyValueChangeKindKey],
               "Intersect change is a removal");
    NSSet *expected = [NSSet setWithObject:BOXI(3)];
    PASS_EQUAL(expected, change[NSKeyValueChangeOldKey],
               "Intersect old key is correct");
    PASS(change[NSKeyValueChangeNewKey] == nil, "Intersect new key is nil");
  };

  // Set with @({@(3)}) to get @({@(3)})
  ChangeCallback setCallback = CHANGE_CB
  {
    if (setSetChanged)
      {
        PASS_EQUAL(BOXI(NSKeyValueChangeReplacement),
                   change[NSKeyValueChangeKindKey],
                   "Set change is a replacement");
        PASS_EQUAL([NSSet setWithObject:BOXI(2)], change[NSKeyValueChangeOldKey],
                   "Set old key is correct");
        PASS_EQUAL([NSSet setWithObject:BOXI(3)], change[NSKeyValueChangeNewKey],
                   "Set new key is correct");
      }
    // setXxx method is not automatically swizzled for observation
    else
      {
        PASS_EQUAL(BOXI(NSKeyValueChangeSetting), change[NSKeyValueChangeKindKey],
                   "Set change is a setting");
        PASS_EQUAL([NSSet setWithObject:BOXI(3)], change[NSKeyValueChangeOldKey],
                   "Set old key is correct");
        PASS_EQUAL([NSSet setWithObject:BOXI(3)], change[NSKeyValueChangeNewKey],
                   "Set new key is correct");
      }
  };

  ChangeCallback illegalChangeNotification = CHANGE_CB
  {
    PASS(NO, "illegalChangeNotification");
  };

  Observee   *observee = [Observee new];
  TestFacade *facade = [TestFacade newWithObservee:observee];

  [facade observeKeyPath:@"setWithHelpers"
                 withOptions:NSKeyValueObservingOptionNew
                             | NSKeyValueObservingOptionOld
             performingBlock:^(Observee *observee) {
               // This set is assisted by setter functions, and should also
               // dispatch one notification per change.
               [observee
                 addSetWithHelpers:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
               [observee removeSetWithHelpers:[NSSet setWithObject:BOXI(1)]];
               [observee addSetWithHelpersObject:BOXI(1)];
               [observee removeSetWithHelpersObject:BOXI(1)];
               [observee intersectSetWithHelpers:[NSSet setWithObject:BOXI(2)]];
               [observee setSetWithHelpers:[NSSet setWithObject:BOXI(3)]];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      unionCallback, minusCallback, addCallback, removeCallback,
      intersectCallback, setCallback, illegalChangeNotification, nil
    ]];
  PASS([facade hits] == 6, "All six notifications were sent (setWithHelpers)");

  setSetChanged = YES;

  [observee release];
  [facade release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];

  [facade observeKeyPath:@"kvcMediatedSet"
                 withOptions:NSKeyValueObservingOptionNew
                             | NSKeyValueObservingOptionOld
             performingBlock:^(Observee *observee) {
               // Proxy mutable set should dispatch one notification per change
               // The proxy set is a NSKeyValueIvarMutableSet
               NSMutableSet *proxySet =
                 [observee mutableSetValueForKey:@"kvcMediatedSet"];
               [proxySet unionSet:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
               [proxySet minusSet:[NSSet setWithObject:BOXI(1)]];
               [proxySet addObject:BOXI(1)];
               [proxySet removeObject:BOXI(1)];
               [proxySet intersectSet:[NSSet setWithObject:BOXI(2)]];
               [proxySet setSet:[NSSet setWithObject:BOXI(3)]];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      unionCallback, minusCallback, addCallback, removeCallback,
      intersectCallback, setCallback, illegalChangeNotification, nil]];
  PASS([facade hits] == 6, "All six notifications were sent (kvcMediatedSet)");

  [observee release];
  [facade release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];

  [facade observeKeyPath:@"manualNotificationSet"
                 withOptions:NSKeyValueObservingOptionNew
                             | NSKeyValueObservingOptionOld
             performingBlock:^(Observee *observee) {
               // Manually should dispatch one notification per change
               [observee manualUnionSet:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
               [observee manualMinusSet:[NSSet setWithObject:BOXI(1)]];
               [observee manualSetAddObject:BOXI(1)];
               [observee manualSetRemoveObject:BOXI(1)];
               [observee manualIntersectSet:[NSSet setWithObject:BOXI(2)]];
               [observee manualSetSet:[NSSet setWithObject:BOXI(3)]];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      unionCallback, minusCallback, addCallback, removeCallback,
      intersectCallback, setCallback, illegalChangeNotification, nil]];
  PASS([facade hits] == 6,
       "All six notifications were sent (manualNotificationSet)");

  /* Indirect proxy (add<key>Object, etc.) to test
   * NSKeyValueFastMutableSet */
  [facade observeKeyPath:@"proxySet"
                 withOptions:NSKeyValueObservingOptionNew
                             | NSKeyValueObservingOptionOld
             performingBlock:^(Observee *observee) {
               // Proxy mutable set should dispatch one notification per change
               // The proxy set is a NSKeyValueIvarMutableSet
               NSMutableSet *proxySet =
                 [observee mutableSetValueForKey:@"proxySet"];
               [proxySet unionSet:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
               [proxySet minusSet:[NSSet setWithObject:BOXI(1)]];
               [proxySet addObject:BOXI(1)];
               [proxySet removeObject:BOXI(1)];
               [proxySet intersectSet:[NSSet setWithObject:BOXI(2)]];
               [proxySet setSet:[NSSet setWithObject:BOXI(3)]];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      unionCallback, minusCallback, addCallback, removeCallback,
      intersectCallback, setCallback, illegalChangeNotification, nil]];
  PASS([facade hits] == 6, "All six notifications were sent (proxySet)");

  /* Indirect slow proxy via NSInvocation to test NSKeyValueSlowMutableSet */
  /* Indirect proxy (add<key>Object, etc.) to test
   * NSKeyValueFastMutableSet */
  [facade observeKeyPath:@"proxyRoSet"
                 withOptions:NSKeyValueObservingOptionNew
                             | NSKeyValueObservingOptionOld
             performingBlock:^(Observee *observee) {
               NSMutableSet *proxySet =
                 [observee mutableSetValueForKey:@"proxyRoSet"];
               [proxySet unionSet:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
               [proxySet minusSet:[NSSet setWithObject:BOXI(1)]];
               [proxySet addObject:BOXI(1)];
               [proxySet removeObject:BOXI(1)];
               [proxySet intersectSet:[NSSet setWithObject:BOXI(2)]];
               [proxySet setSet:[NSSet setWithObject:BOXI(3)]];
             }
    andExpectChangeCallbacks: [NSArray arrayWithObjects:
      unionCallback, minusCallback, addCallback, removeCallback,
      intersectCallback, setCallback, illegalChangeNotification, nil]];
  PASS([facade hits] == 6, "All six notifications were sent (proxySet)");

  [observee release];
  [facade release];

  END_SET("NSSetMutationMethods");
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  ToMany_NoNotificationOnBareArray();
  ToMany_NotifyingArray();
  ToMany_KVCMediatedArrayWithHelpers_AggregateFunction();

  ToMany_ToOne_ShouldDowngradeForOrderedObservation();
  ObserverInformationShouldNotLeak();

  // NSArrayShouldNotBeObservable();
  NSArrayShouldThrowWhenTryingToObserveIndexesOutOfRange();
  NSArrayObserveElements();

  NSSetShouldNotBeObservable();
  NSSetMutationMethods();

  DESTROY(pool);

  return 0;
}

#else

int
main(int argc, const char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  NSLog(@"This test requires an Objective-C 2.0 runtime and is not supported "
        @"on this platform.");

  DESTROY(pool);

  return 0;
}

#endif
