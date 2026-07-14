/**
   NSKVOInternal.h

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

/* This Key Value Observing Implementation is tied to libobjc2 */

#import "Foundation/NSObject.h"
#import "Foundation/NSString.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSException.h"

#import "GSPrivate.h"

#if defined(__OBJC2__)

#import "GSPThread.h"

#define NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath)                               \
  do                                                                           \
    {                                                                          \
      [NSException                                                             \
         raise: NSInvalidArgumentException                                     \
        format: @"-[%s %s] is not supported. Key path: %@",                    \
               object_getClassName(self), sel_getName(_cmd), keyPath];         \
  } while (false)

@class _NSKVOKeypathObserver;

@interface _NSKVOKeyObserver : NSObject
- (instancetype)initWithObject:(id)object
               keypathObserver:(_NSKVOKeypathObserver *)keypathObserver
                           key:(NSString *)key
                 restOfKeypath:(NSString *)restOfKeypath
             affectedObservers:(NSArray *)affectedObservers;
@property (nonatomic, retain) _NSKVOKeypathObserver *keypathObserver;
@property (nonatomic, retain) _NSKVOKeyObserver     *restOfKeypathObserver;
@property (nonatomic, retain) NSArray               *dependentObservers;
@property (nonatomic, assign) id                     object;
@property (nonatomic, copy) NSString                *key;
@property (nonatomic, copy) NSString                *restOfKeypath;
@property (nonatomic, retain) NSArray               *affectedObservers;
@property (nonatomic, assign) BOOL                   root;
@property (nonatomic, readonly) BOOL                 isRemoved;
@end

@interface _NSKVOKeypathObserver : NSObject
- (instancetype)initWithObject:(id)object
                      observer:(id)observer
                       keyPath:(NSString *)keypath
                       options:(NSKeyValueObservingOptions)options
                       context:(void *)context;
@property (nonatomic, assign) id                         object;
@property (nonatomic, assign) id                         observer;
@property (nonatomic, copy) NSString                    *keypath;
@property (nonatomic, assign) NSKeyValueObservingOptions options;
@property (nonatomic, assign) void                      *context;

@property (atomic, retain) NSMutableDictionary *pendingChange;
@end

@interface _NSKVOObservationInfo : NSObject
{
  NSMutableDictionary<NSString *, NSMutableArray<_NSKVOKeyObserver *> *>
                           *_keyObserverMap;
  NSInteger                 _dependencyDepth;
  NSMutableSet<NSString *> *_existingDependentKeys;
  gs_mutex_t                _lock;
}
- (instancetype)init;
- (NSArray *)observersForKey:(NSString *)key;
- (void)addObserver:(_NSKVOKeyObserver *)observer;
@end

// From NSKVOSwizzling
void
_NSKVOEnsureKeyWillNotify(id object, NSString *key) GS_ATTRIB_PRIVATE;

#endif

/* Implementation in NSKVOSupport.m for ObjC2 and NSKeyValueObserving
 * respectively
 */
@interface
NSObject (NSKeyValueObservingPrivate)
- (Class)_underlyingClass;
- (void)_notifyObserversOfChangeForKey:(NSString *)key
                              oldValue:(id)oldValue
                              newValue:(id)newValue;
@end
