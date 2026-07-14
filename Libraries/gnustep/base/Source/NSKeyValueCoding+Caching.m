/** Key-Value Coding Safe Caching Support.
   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by:  Hugo Melder <hugo@algoriddim.com>
   Created: August 2024

   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import <objc/runtime.h>
#import <objc/encoding.h>
#import <objc/slot.h>

#import "common.h" // for likely and unlikely
#import "typeEncodingHelper.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSInvocation.h"
#import "NSKeyValueCoding+Caching.h"


struct _KVCCacheSlot
{
  Class cls;
  SEL         selector;
  const char *types;
  uintptr_t hash;
  // The slot version returned by objc_get_slot2.
  // Set to zero when this is caching an ivar lookup
  uint64_t version;
  // If selector is zero, we cache the ivar offset,
  // otherwise the IMP of the accessor.
  // Use the corresponding get functions below.
  union
  {
    IMP      imp;
    intptr_t offset;
    // Just for readability when checking for emptyness
    intptr_t contents;
  };
  id (*get)(struct _KVCCacheSlot *, id);
};

static inline uintptr_t
_KVCCacheSlotHash(const void *ptr)
{
  struct _KVCCacheSlot *a = (struct _KVCCacheSlot *) ptr;
  return (uintptr_t) a->cls ^ (uintptr_t) a->hash;
}

static inline BOOL
_KVCCacheSlotEqual(const void *ptr1, const void *ptr2)
{
  struct _KVCCacheSlot *a = (struct _KVCCacheSlot *) ptr1;
  struct _KVCCacheSlot *b = (struct _KVCCacheSlot *) ptr2;

  return a->cls == b->cls && a->hash == b->hash;
}

void inline _KVCCacheSlotRelease(const void *ptr)
{
  free((struct _KVCCacheSlot *) ptr);
}

// We only need a hash table not a map
#define GSI_MAP_HAS_VALUE 0
#define GSI_MAP_RETAIN_KEY(M, X)
#define GSI_MAP_RELEASE_KEY(M, X) (_KVCCacheSlotRelease(X.ptr))
#define GSI_MAP_HASH(M, X) (_KVCCacheSlotHash(X.ptr))
#define GSI_MAP_EQUAL(M, X, Y) (_KVCCacheSlotEqual(X.ptr, Y.ptr))
#define GSI_MAP_KTYPES GSUNION_PTR
#import "GNUstepBase/GSIMap.h"
#import "GSPThread.h"

/*
 * Templating for poor people:
 * We need to call IMP with the correct function signature and box
 * the return value accordingly.
 */
#define KVC_CACHE_FUNC(_type, _fnname, _cls, _meth)                            \
  static id _fnname(struct _KVCCacheSlot *slot, id obj)                        \
  {                                                                            \
    _type val = ((_type(*)(id, SEL)) slot->imp)(obj, slot->selector);          \
    return [_cls _meth:val];                                                   \
  }
#define KVC_CACHE_IVAR_FUNC(_type, _fnname, _cls, _meth)                       \
  static id _fnname##ForIvar(struct _KVCCacheSlot *slot, id obj)               \
  {                                                                            \
    _type val = *(_type *) ((char *) obj + slot->offset);                      \
    return [_cls _meth:val];                                                   \
  }

#define CACHE_NSNUMBER_GEN_FUNCS(_type, _fnname, _numberMethName)              \
  KVC_CACHE_FUNC(_type, _fnname, NSNumber, numberWith##_numberMethName)        \
  KVC_CACHE_IVAR_FUNC(_type, _fnname, NSNumber, numberWith##_numberMethName)

#define CACHE_NSVALUE_GEN_FUNCS(_type, _fnname, _valueMethName)                \
  KVC_CACHE_FUNC(_type, _fnname, NSValue, valueWith##_valueMethName)           \
  KVC_CACHE_IVAR_FUNC(_type, _fnname, NSValue, valueWith##_valueMethName)

// Ignore the alignment warning when casting the obj + offset address
// to the proper type.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-align"

CACHE_NSNUMBER_GEN_FUNCS(char, _getBoxedChar, Char);
CACHE_NSNUMBER_GEN_FUNCS(int, _getBoxedInt, Int);
CACHE_NSNUMBER_GEN_FUNCS(short, _getBoxedShort, Short);
CACHE_NSNUMBER_GEN_FUNCS(long, _getBoxedLong, Long);
CACHE_NSNUMBER_GEN_FUNCS(long long, _getBoxedLongLong, LongLong);
CACHE_NSNUMBER_GEN_FUNCS(unsigned char, _getBoxedUnsignedChar, UnsignedChar);
CACHE_NSNUMBER_GEN_FUNCS(unsigned int, _getBoxedUnsignedInt, UnsignedInt);
CACHE_NSNUMBER_GEN_FUNCS(unsigned short, _getBoxedUnsignedShort, UnsignedShort);
CACHE_NSNUMBER_GEN_FUNCS(unsigned long, _getBoxedUnsignedLong, UnsignedLong);
CACHE_NSNUMBER_GEN_FUNCS(unsigned long long, _getBoxedUnsignedLongLong,
                         UnsignedLongLong);
CACHE_NSNUMBER_GEN_FUNCS(float, _getBoxedFloat, Float);
CACHE_NSNUMBER_GEN_FUNCS(double, _getBoxedDouble, Double);
CACHE_NSNUMBER_GEN_FUNCS(bool, _getBoxedBool, Bool);

CACHE_NSVALUE_GEN_FUNCS(NSPoint, _getBoxedNSPoint, Point);
CACHE_NSVALUE_GEN_FUNCS(NSRange, _getBoxedNSRange, Range);
CACHE_NSVALUE_GEN_FUNCS(NSRect, _getBoxedNSRect, Rect);
CACHE_NSVALUE_GEN_FUNCS(NSSize, _getBoxedNSSize, Size);

static id
_getBoxedId(struct _KVCCacheSlot *slot, id obj)
{
  id val = ((id(*)(id, SEL)) slot->imp)(obj, slot->selector);
  return val;
}
static id
_getBoxedIdForIvar(struct _KVCCacheSlot *slot, id obj)
{
  id val = *(id *) ((char *) obj + slot->offset);
  return val;
}
static id
_getBoxedClass(struct _KVCCacheSlot *slot, id obj)
{
  Class val = ((Class(*)(id, SEL)) slot->imp)(obj, slot->selector);
  return val;
}
static id
_getBoxedClassForIvar(struct _KVCCacheSlot *slot, id obj)
{
  Class val = *(Class *) ((char *) obj + slot->offset);
  return val;
}

// TODO: This can be optimised and is still very expensive
static id
_getBoxedStruct(struct _KVCCacheSlot *slot, id obj)
{
  NSInvocation      *inv;
  const char	    *types = slot->types;
  NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes: types];
  size_t            retSize = [sig methodReturnLength];
  char 		    ret[retSize];

  inv = [NSInvocation invocationWithMethodSignature: sig];
  [inv setSelector: slot->selector];
  [inv invokeWithTarget: obj];
  [inv getReturnValue: ret];

  return [NSValue valueWithBytes:ret objCType:[sig methodReturnType]];
}
static id
_getBoxedStructForIvar(struct _KVCCacheSlot *slot, id obj)
{
  const char *end = objc_skip_typespec(slot->types);
  size_t      length = end - slot->types;
  char        returnType[length + 1];
  memcpy(returnType, slot->types, length);
  returnType[length] = '\0';

  return [NSValue valueWithBytes:((char *) obj + slot->offset)
                        objCType:returnType];
}

#pragma clang diagnostic pop

static struct _KVCCacheSlot
_getBoxedBlockForIVar(NSString *key, Ivar ivar)
{
  const char          *encoding = ivar_getTypeEncoding(ivar);
  struct _KVCCacheSlot slot = {};
  // Return a zeroed out slot.  It is the caller's responsibility to call
  // valueForUndefinedKey:
  if (unlikely(encoding == NULL))
    {
      return slot;
    }

  slot.offset = ivar_getOffset(ivar);
  slot.types = encoding;
  // Get the current objc_method_cache_version as we do not explicitly
  // request a new slot when looking up ivars.
  slot.version = objc_method_cache_version;

  switch (encoding[0])
    {
      case '@': {
        slot.get = _getBoxedIdForIvar;
        return slot;
      }
      case 'B': {
        slot.get = _getBoxedBoolForIvar;
        return slot;
      }
      case 'l': {
        slot.get = _getBoxedLongForIvar;
        return slot;
      }
      case 'f': {
        slot.get = _getBoxedFloatForIvar;
        return slot;
      }
      case 'd': {
        slot.get = _getBoxedDoubleForIvar;
        return slot;
      }
      case 'i': {
        slot.get = _getBoxedIntForIvar;
        return slot;
      }
      case 'I': {
        slot.get = _getBoxedUnsignedIntForIvar;
        return slot;
      }
      case 'L': {
        slot.get = _getBoxedUnsignedLongForIvar;
        return slot;
      }
      case 'q': {
        slot.get = _getBoxedLongLongForIvar;
        return slot;
      }
      case 'Q': {
        slot.get = _getBoxedUnsignedLongLongForIvar;
        return slot;
      }
      case 'c': {
        slot.get = _getBoxedCharForIvar;
        return slot;
      }
      case 's': {
        slot.get = _getBoxedShortForIvar;
        return slot;
      }
      case 'C': {
        slot.get = _getBoxedUnsignedCharForIvar;
        return slot;
      }
      case 'S': {
        slot.get = _getBoxedUnsignedShortForIvar;
        return slot;
      }
      case '#': {
        slot.get = _getBoxedClassForIvar;
        return slot;
      }
      case '{': {
        if (IS_NSRANGE_ENCODING(encoding))
          {
            slot.get = _getBoxedNSRangeForIvar;
            return slot;
          }
        else if (IS_CGRECT_ENCODING(encoding))
          {
            slot.get = _getBoxedNSRectForIvar;
            return slot;
          }
        else if (IS_CGPOINT_ENCODING(encoding))
          {
            slot.get = _getBoxedNSPointForIvar;
            return slot;
          }
        else if (IS_CGSIZE_ENCODING(encoding))
          {
            slot.get = _getBoxedNSSizeForIvar;
            return slot;
          }

        slot.get = _getBoxedStructForIvar;
        return slot;
      }
    default:
      slot.contents = 0;
      return slot;
    }
}

static struct _KVCCacheSlot
_getBoxedBlockForMethod(NSString *key, Method method, SEL sel, uint64_t version)
{
  const char          *encoding = method_getTypeEncoding(method);
  struct _KVCCacheSlot slot = {};
  if (unlikely(encoding == NULL))
    {
      // Return a zeroed out slot.  It is the caller's responsibility to call
      // valueForUndefinedKey: or parse unknown structs (when type encoding
      // starts with '{')
      return slot;
    }

  slot.imp = method_getImplementation(method);
  slot.selector = sel;
  slot.types = encoding;
  slot.version = version;

  // TODO: Move most commonly used types up the switch statement
  switch (encoding[0])
    {
      case '@': {
        slot.get = _getBoxedId;
        return slot;
      }
      case 'B': {
        slot.get = _getBoxedBool;
        return slot;
      }
      case 'l': {
        slot.get = _getBoxedLong;
        return slot;
      }
      case 'f': {
        slot.get = _getBoxedFloat;
        return slot;
      }
      case 'd': {
        slot.get = _getBoxedDouble;
        return slot;
      }
      case 'i': {
        slot.get = _getBoxedInt;
        return slot;
      }
      case 'I': {
        slot.get = _getBoxedUnsignedInt;
        return slot;
      }
      case 'L': {
        slot.get = _getBoxedUnsignedLong;
        return slot;
      }
      case 'q': {
        slot.get = _getBoxedLongLong;
        return slot;
      }
      case 'Q': {
        slot.get = _getBoxedUnsignedLongLong;
        return slot;
      }
      case 'c': {
        slot.get = _getBoxedChar;
        return slot;
      }
      case 's': {
        slot.get = _getBoxedShort;
        return slot;
      }
      case 'C': {
        slot.get = _getBoxedUnsignedChar;
        return slot;
      }
      case 'S': {
        slot.get = _getBoxedUnsignedShort;
        return slot;
      }
      case '#': {
        slot.get = _getBoxedClass;
        return slot;
      }
      case '{': {
        if (IS_NSRANGE_ENCODING(encoding))
          {
            slot.get = _getBoxedNSRange;
            return slot;
          }
        else if (IS_CGRECT_ENCODING(encoding))
          {
            slot.get = _getBoxedNSRect;
            return slot;
          }
        else if (IS_CGPOINT_ENCODING(encoding))
          {
            slot.get = _getBoxedNSPoint;
            return slot;
          }
        else if (IS_CGSIZE_ENCODING(encoding))
          {
            slot.get = _getBoxedNSSize;
            return slot;
          }

        slot.get = _getBoxedStruct;
        return slot;
      }
    default:
      slot.contents = 0;
      return slot;
    }
}

// libobjc2 does not offer an API for recursively looking up a slot with
// just the class and a selector.
// The behaviour of this function is similar to that of class_getInstanceMethod
// and recurses into the super classes. Additionally, we ask the class, if it
// can resolve the instance method dynamically by calling -[NSObject
// resolveInstanceMethod:].
//
// objc_slot2 has the same struct layout as objc_method.
static Method _Nullable _class_getMethodRecursive(Class aClass, SEL aSelector,
                                           uint64_t *version)
{
  struct objc_slot2 *slot;

  if (0 == aClass)
    {
      return NULL;
    }

  if (0 == aSelector)
    {
      return NULL;
    }

  // Do a dtable lookup to find out which class the method comes from.
  slot = objc_get_slot2(aClass, aSelector, version);
  if (NULL != slot)
    {
      return (Method) slot;
    }

  // Ask if class is able to dynamically register this method
  if ([aClass resolveInstanceMethod:aSelector])
    {
      return (Method) _class_getMethodRecursive(aClass, aSelector, version);
    }

  // Recurse into super classes
  return (Method) _class_getMethodRecursive(class_getSuperclass(aClass),
                                            aSelector, version);
}

static struct _KVCCacheSlot
ValueForKeyLookup(Class cls, NSObject *self, NSString *boxedKey,
                  const char *key, unsigned size)
{
  const char          *name;
  char                 buf[size + 5];
  char                 lo;
  char                 hi;
  SEL                  sel = 0;
  Method               meth = NULL;
  uint64_t             version = 0;
  struct _KVCCacheSlot slot = {};

  if (unlikely(size == 0))
    {
      return slot;
    }

  memcpy(buf, "_get", 4);
  memcpy(&buf[4], key, size);
  buf[size + 4] = '\0';
  lo = buf[4];
  hi = islower(lo) ? toupper(lo) : lo;
  buf[4] = hi;

  // 1.1 Check if the _get<key> accessor method exists
  name = &buf[1]; // getKey
  sel = sel_registerName(name);
  if ((meth = _class_getMethodRecursive(cls, sel, &version)) != NULL)
    {
      return _getBoxedBlockForMethod(boxedKey, meth, sel, version);
    }

  // 1.2 Check if the <key> accessor method exists
  buf[4] = lo;
  name = &buf[4]; // key
  sel = sel_registerName(name);
  if ((meth = _class_getMethodRecursive(cls, sel, &version)) != NULL)
    {
      return _getBoxedBlockForMethod(boxedKey, meth, sel, version);
    }

  // 1.3 Check if the is<key> accessor method exists
  buf[2] = 'i';
  buf[3] = 's';
  buf[4] = hi;
  name = &buf[2]; // isKey
  sel = sel_registerName(name);
  if ((meth = _class_getMethodRecursive(cls, sel, &version)) != NULL)
    {
      return _getBoxedBlockForMethod(boxedKey, meth, sel, version);
    }

  // 1.4 Check if the _<key> accessor method exists. Otherwise check
  // if we are allowed to access the instance variables directly.
  buf[3] = '_';
  buf[4] = lo;
  name = &buf[3]; // _key
  sel = sel_registerName(name);
  if ((meth = _class_getMethodRecursive(cls, sel, &version)) != NULL)
    {
      return _getBoxedBlockForMethod(boxedKey, meth, sel, version);
    }

  // Step 2. and 3. (NSArray and NSSet accessors) are implemented
  // in the respective classes.

  // 4. Last try: Ivar access
  if ([cls accessInstanceVariablesDirectly] == YES)
    {
      // 4.1 Check if the _<key> ivar exists
      Ivar ivar = class_getInstanceVariable(cls, name);
      if (ivar != NULL)
        { // _key
          return _getBoxedBlockForIVar(boxedKey, ivar);
        }

      // 4.2 Check if the _is<Key> ivar exists
      buf[1] = '_';
      buf[2] = 'i';
      buf[3] = 's';
      buf[4] = hi;
      name = &buf[1]; // _isKey
      ivar = class_getInstanceVariable(cls, name);
      if (ivar != NULL)
        {
          return _getBoxedBlockForIVar(boxedKey, ivar);
        }

      // 4.3 Check if the <key> ivar exists
      buf[4] = lo;
      name = &buf[4]; // key
      ivar = class_getInstanceVariable(cls, name);
      if (ivar != NULL)
        {
          return _getBoxedBlockForIVar(boxedKey, ivar);
        }

      // 4.4 Check if the is<Key> ivar exists
      buf[4] = hi;
      name = &buf[2]; // isKey
      ivar = class_getInstanceVariable(cls, name);
      if (ivar != NULL)
        {
          return _getBoxedBlockForIVar(boxedKey, ivar);
        }
    }

  return slot;
}

id
valueForKeyWithCaching(id obj, NSString *aKey)
{
  struct _KVCCacheSlot *cachedSlot = NULL;
  GSIMapNode            node = NULL;
  static GSIMapTable_t  cacheTable = {};
  static gs_mutex_t     cacheTableLock = GS_MUTEX_INIT_STATIC;

  Class cls = object_getClass(obj);
  // Fill out the required fields for hashing
  struct _KVCCacheSlot slot = {.cls = cls, .hash = [aKey hash]};

  GS_MUTEX_LOCK(cacheTableLock);
  if (cacheTable.zone == 0)
    {
      // TODO: Tweak initial capacity
      GSIMapInitWithZoneAndCapacity(&cacheTable, NSDefaultMallocZone(), 64);
    }
  node = GSIMapNodeForKey(&cacheTable, (GSIMapKey) (void *) &slot);
  GS_MUTEX_UNLOCK(cacheTableLock);

  if (node == NULL)
    {
      // Lookup the getter
      slot
        = ValueForKeyLookup(cls, obj, aKey, [aKey UTF8String], [aKey length]);
      if (slot.contents != 0)
        {
          slot.cls = cls;
          slot.hash = [aKey hash];

          // Copy slot to heap
          cachedSlot
            = (struct _KVCCacheSlot *) malloc(sizeof(struct _KVCCacheSlot));
          memcpy(cachedSlot, &slot, sizeof(struct _KVCCacheSlot));

          GS_MUTEX_LOCK(cacheTableLock);
          node = GSIMapAddKey(&cacheTable, (GSIMapKey) (void *) cachedSlot);
          GS_MUTEX_UNLOCK(cacheTableLock);
        }
      else
        {
          return [obj valueForUndefinedKey:aKey];
        }
    }
  cachedSlot = node->key.ptr;

  // Check if a new method was registered. If this is the case,
  // the objc_method_cache_version was incremented and we need to update the
  // cache.
  if (objc_method_cache_version != cachedSlot->version)
    {
      // Lookup the getter
      // TODO: We can optimise this by supplying a hint (return type etc.)
      // as it is unlikely, that the return type has changed.
      slot
        = ValueForKeyLookup(cls, obj, aKey, [aKey UTF8String], [aKey length]);

      // Update entry
      GS_MUTEX_LOCK(cacheTableLock);
      memcpy(cachedSlot, &slot, sizeof(struct _KVCCacheSlot));
      GS_MUTEX_UNLOCK(cacheTableLock);
    }

  return cachedSlot->get(cachedSlot, obj);
}
