#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSValue.h>

#import "Testing.h"

// For ivars: _<key>, _is<Key>, <key>, or is<Key>, in that order.
// For methods: get<Key>, <key>, is<Key>, or _<key> in that order.
@interface SearchOrder : NSObject
{
  long long _longLong;
  long long _isLongLong;
  long long longLong;
  long long isLongLong;

  unsigned char _isUnsignedChar;
  unsigned char unsignedChar;
  unsigned char isUnsignedChar;

  unsigned int unsignedInt;
  unsigned int isUnsignedInt;

  unsigned long isUnsignedLong;
}

- (instancetype)init;

- (signed char)getChar;
- (signed char)char;
- (signed char)isChar;
- (signed char)_char;

- (int)int;
- (int)isInt;
- (int)_int;

- (short)isShort;
- (short)_short;

- (long)_long;

@end

@implementation SearchOrder

- (instancetype)init
{
  self = [super init];

  if (self)
    {
      _longLong = LLONG_MAX;
      _isLongLong = LLONG_MAX - 1;
      longLong = LLONG_MAX - 2;
      isLongLong = LLONG_MAX - 3;

      _isUnsignedChar = UCHAR_MAX;
      unsignedChar = UCHAR_MAX - 1;
      isUnsignedChar = UCHAR_MAX - 2;

      unsignedInt = UINT_MAX;
      isUnsignedInt = UINT_MAX - 1;

      isUnsignedLong = ULONG_MAX;
    }

  return self;
}

- (signed char)getChar
{
  return SCHAR_MAX;
}
- (signed char)char
{
  return SCHAR_MAX - 1;
}
- (signed char)isChar
{
  return SCHAR_MAX - 2;
}
- (signed char)_char
{
  return SCHAR_MAX - 3;
}

- (int)int
{
  return INT_MAX;
}
- (int)isInt
{
  return INT_MAX - 1;
}
- (int)_int
{
  return INT_MAX - 2;
}

- (short)isShort
{
  return SHRT_MAX;
}
- (short)_short
{
  return SHRT_MAX - 1;
}

- (long)_long
{
  return LONG_MAX;
}

@end

@interface SearchOrderNoIvarAccess : NSObject
{
  bool _boolVal;
  bool _isBoolVal;
  bool boolVal;
  bool isBoolVal;
}

@end

@implementation SearchOrderNoIvarAccess

+ (BOOL)accessInstanceVariablesDirectly
{
  return NO;
}

@end

static void
testSearchOrder(void)
{
  SearchOrder *so = [SearchOrder new];

  START_SET("Search Order");

  PASS_EQUAL([so valueForKey:@"char"], [NSNumber numberWithChar:SCHAR_MAX],
             "get<Key> is used when available");
  PASS_EQUAL([so valueForKey:@"int"], [NSNumber numberWithInt:INT_MAX],
             "<key> is used when get<Key> is not available");
  PASS_EQUAL([so valueForKey:@"short"], [NSNumber numberWithShort:SHRT_MAX],
             "is<Key> is used when get<Key> and <key> is not available");
  PASS_EQUAL(
    [so valueForKey:@"long"], [NSNumber numberWithLong:LONG_MAX],
    "_<key> is used when get<Key>, <key>, and is<Key> is not available");
  PASS_EQUAL(
    [so valueForKey:@"longLong"], [NSNumber numberWithLongLong:LLONG_MAX],
    "_<key> ivar is used when get<Key>, <key>, and is<Key> is not available");
  PASS_EQUAL(
    [so valueForKey:@"unsignedChar"],
    [NSNumber numberWithUnsignedChar:UCHAR_MAX],
    "_is<Key> ivar is used when get<Key>, <key>, and is<Key> is not available");
  PASS_EQUAL(
    [so valueForKey:@"unsignedInt"], [NSNumber numberWithUnsignedInt:UINT_MAX],
    "<key> ivar is used when get<Key>, <key>, and is<Key> is not available");
  PASS_EQUAL(
    [so valueForKey:@"unsignedLong"],
    [NSNumber numberWithUnsignedLong:ULONG_MAX],
    "is<Key> ivar is used when get<Key>, <key>, and is<Key> is not available");

  END_SET("Search Order");

  [so release];
}

static void
testIvarAccess(void)
{
  SearchOrderNoIvarAccess *so = [SearchOrderNoIvarAccess new];

  START_SET("Search Order Ivar Access");

  PASS_EXCEPTION([so valueForKey:@"boolVal"], NSUndefinedKeyException,
                 "Does not return protected ivar");

  END_SET("Search Order Ivar Access");

  [so release];
}

int
main(int argc, char *argv[])
{
  testSearchOrder();
  testIvarAccess();
  return 0;
}
