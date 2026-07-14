#include "GNUstepBase/GSObjCRuntime.h"
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSGeometry.h>
#import <Foundation/NSArray.h>

#include "Testing.h"

/*
 * Testing key-value coding on accessors and instance variable
 * with all supported types.
 *
 * Please note that 'Class', `SEL`, unions, and pointer types are
 * not coding-compliant on macOS.
 */

typedef struct
{
  int   x;
  float y;
} MyStruct;

@interface ReturnTypes : NSObject
{
  signed char        _iChar;
  int                _iInt;
  short              _iShort;
  long               _iLong;
  long long          _iLongLong;
  unsigned char      _iUnsignedChar;
  unsigned int       _iUnsignedInt;
  unsigned short     _iUnsignedShort;
  unsigned long      _iUnsignedLong;
  unsigned long long _iUnsignedLongLong;
  float              _iFloat;
  double             _iDouble;
  bool               _iBool;
  // Not coding-compliant on macOS
  // const char *_iCharPtr;
  // int *_iIntPtr;
  // Class _iCls;
  // void *_iUnknownType; // Type encoding: ?
  // MyUnion _iMyUnion;
  id _iId;

  NSPoint _iNSPoint;
  NSRange _iNSRange;
  NSRect  _iNSRect;
  NSSize  _iNSSize;

  MyStruct _iMyStruct;
}

- (instancetype)init;

- (signed char)mChar;                    // Type encoding: c
- (int)mInt;                             // Type encoding: i
- (short)mShort;                         // Type encoding: s
- (long)mLong;                           // Type encoding: l
- (long long)mLongLong;                  // Type encoding: q
- (unsigned char)mUnsignedChar;          // Type encoding: C
- (unsigned int)mUnsignedInt;            // Type encoding: I
- (unsigned short)mUnsignedShort;        // Type encoding: S
- (unsigned long)mUnsignedLong;          // Type encoding: L
- (unsigned long long)mUnsignedLongLong; // Type encoding: Q
- (float)mFloat;                         // Type encoding: f
- (double)mDouble;                       // Type encoding: d
- (bool)mBool;                           // Type encoding: B
- (id)mId;                               // Type encoding: @

- (NSPoint)mNSPoint;
- (NSRange)mNSRange;
- (NSRect)mNSRect;
- (NSSize)mNSSize;

- (MyStruct)mMyStruct;
@end

@implementation ReturnTypes

- (void) dealloc
{
  RELEASE(_iId);
  DEALLOC
}

- (instancetype)init
{
  self = [super init];
  if (self)
    {
      MyStruct my = {.x = 42, .y = 3.14f};
      _iChar = SCHAR_MIN;
      _iShort = SHRT_MIN;
      _iInt = INT_MIN;
      _iLong = LONG_MIN;
      _iUnsignedChar = 0;
      _iUnsignedInt = 0;
      _iUnsignedShort = 0;
      _iUnsignedLong = 0;
      _iUnsignedLongLong = 0;
      _iFloat = 123.4f;
      _iDouble = 123.45678;
      _iBool = true;
      _iId = @"id";
      _iNSPoint = NSMakePoint(1.0, 2.0);
      _iNSRange = NSMakeRange(1, 2);
      _iNSRect = NSMakeRect(1.0, 2.0, 3.0, 4.0);
      _iNSSize = NSMakeSize(1.0, 2.0);
      _iMyStruct = my;
    }
  return self;
}

- (void)mVoid
{}

- (signed char)mChar
{
  return SCHAR_MAX;
}

- (short)mShort
{
  return SHRT_MAX;
}

- (int)mInt
{
  return INT_MAX;
}

- (long)mLong
{
  return LONG_MAX;
}

- (long long)mLongLong
{
  return LLONG_MAX;
}

- (unsigned char)mUnsignedChar
{
  return UCHAR_MAX;
}

- (unsigned int)mUnsignedInt
{
  return UINT_MAX;
}

- (unsigned short)mUnsignedShort
{
  return USHRT_MAX;
}

- (unsigned long)mUnsignedLong
{
  return ULONG_MAX;
}

- (unsigned long long)mUnsignedLongLong
{
  return ULLONG_MAX;
}

- (float)mFloat
{
  return 123.45f;
}

- (double)mDouble
{
  return 123.456789;
}

- (bool)mBool
{
  return true;
}

- (id)mId
{
  return @"id";
}

- (NSPoint)mNSPoint
{
  return NSMakePoint(1.0, 2.0);
}

- (NSRange)mNSRange
{
  return NSMakeRange(1, 2);
}

- (NSRect)mNSRect
{
  return NSMakeRect(1.0, 2.0, 3.0, 4.0);
}

- (NSSize)mNSSize
{
  return NSMakeSize(1.0, 2.0);
}

- (MyStruct)mMyStruct
{
  MyStruct s = {.x = 1, .y = 2.0};
  return s;
}

@end

static void
testAccessors(void)
{
  ReturnTypes *rt = [ReturnTypes new];

  NSPoint  p = NSMakePoint(1.0, 2.0);
  NSRange  r = NSMakeRange(1, 2);
  NSRect   re = NSMakeRect(1.0, 2.0, 3.0, 4.0);
  NSSize   s = NSMakeSize(1.0, 2.0);
  MyStruct ms = {.x = 1, .y = 2.0};

  START_SET("Accessors");

  PASS_EQUAL([rt valueForKey:@"mChar"], [NSNumber numberWithChar:SCHAR_MAX],
             "Accessor returns char");
  PASS_EQUAL([rt valueForKey:@"mInt"], [NSNumber numberWithInt:INT_MAX],
             "Accessor returns int");
  PASS_EQUAL([rt valueForKey:@"mShort"], [NSNumber numberWithShort:SHRT_MAX],
             "Accessor returns short");
  PASS_EQUAL([rt valueForKey:@"mLong"], [NSNumber numberWithLong:LONG_MAX],
             "Accessor returns long");
  PASS_EQUAL([rt valueForKey:@"mLongLong"],
             [NSNumber numberWithLongLong:LLONG_MAX],
             "Accessor returns long long");
  PASS_EQUAL([rt valueForKey:@"mUnsignedChar"],
             [NSNumber numberWithUnsignedChar:UCHAR_MAX],
             "Accessor returns unsigned char");
  PASS_EQUAL([rt valueForKey:@"mUnsignedInt"],
             [NSNumber numberWithUnsignedInt:UINT_MAX],
             "Accessor returns unsigned int");
  PASS_EQUAL([rt valueForKey:@"mUnsignedShort"],
             [NSNumber numberWithUnsignedShort:USHRT_MAX],
             "Accessor returns unsigned short");
  PASS_EQUAL([rt valueForKey:@"mUnsignedLong"],
             [NSNumber numberWithUnsignedLong:ULONG_MAX],
             "Accessor returns unsigned long");
  PASS_EQUAL([rt valueForKey:@"mUnsignedLongLong"],
             [NSNumber numberWithUnsignedLongLong:ULLONG_MAX],
             "Accessor returns unsigned long long");
  PASS_EQUAL([rt valueForKey:@"mFloat"], [NSNumber numberWithFloat:123.45f],
             "Accessor returns float");
  PASS_EQUAL([rt valueForKey:@"mDouble"],
             [NSNumber numberWithDouble:123.456789], "Accessor returns double");
  PASS_EQUAL([rt valueForKey:@"mBool"], [NSNumber numberWithBool:true],
             "Accessor returns bool");
  PASS_EQUAL([rt valueForKey:@"mId"], @"id", "Accessor returns id");
  PASS_EQUAL([rt valueForKey:@"mNSPoint"], [NSValue valueWithPoint:p],
             "Accessor returns NSPoint");
  PASS_EQUAL([rt valueForKey:@"mNSRange"], [NSValue valueWithRange:r],
             "Accessor returns NSRange");
  PASS_EQUAL([rt valueForKey:@"mNSRect"], [NSValue valueWithRect:re],
             "Accessor returns NSRect");
  PASS_EQUAL([rt valueForKey:@"mNSSize"], [NSValue valueWithSize:s],
             "Accessor returns NSSize");
  PASS_EQUAL([rt valueForKey:@"mMyStruct"],
             [NSValue valueWithBytes:&ms objCType:@encode(MyStruct)],
             "Accessor returns MyStruct");

  END_SET("Accessors");

  [rt release];
}

static void
testIvars(void)
{
  ReturnTypes *rt = [ReturnTypes new];

  NSPoint  p = NSMakePoint(1.0, 2.0);
  NSRange  r = NSMakeRange(1, 2);
  NSRect   re = NSMakeRect(1.0, 2.0, 3.0, 4.0);
  NSSize   s = NSMakeSize(1.0, 2.0);
  MyStruct ms = {.x = 42, .y = 3.14f};

  START_SET("Ivars");

  PASS_EQUAL([rt valueForKey:@"iChar"], [NSNumber numberWithChar:SCHAR_MIN],
             "Ivar returns char");
  PASS_EQUAL([rt valueForKey:@"iInt"], [NSNumber numberWithInt:INT_MIN],
             "Ivar returns int");
  PASS_EQUAL([rt valueForKey:@"iShort"], [NSNumber numberWithShort:SHRT_MIN],
             "Ivar returns short");
  PASS_EQUAL([rt valueForKey:@"iLong"], [NSNumber numberWithLong:LONG_MIN],
             "Ivar returns long");
  PASS_EQUAL([rt valueForKey:@"iUnsignedChar"],
             [NSNumber numberWithUnsignedChar:0], "Ivar returns unsigned char");
  PASS_EQUAL([rt valueForKey:@"iUnsignedInt"],
             [NSNumber numberWithUnsignedInt:0], "Ivar returns unsigned int");
  PASS_EQUAL([rt valueForKey:@"iUnsignedShort"],
             [NSNumber numberWithUnsignedShort:0],
             "Ivar returns unsigned short");
  PASS_EQUAL([rt valueForKey:@"iUnsignedLong"],
             [NSNumber numberWithUnsignedLong:0], "Ivar returns unsigned long");
  PASS_EQUAL([rt valueForKey:@"iUnsignedLongLong"],
             [NSNumber numberWithUnsignedLongLong:0],
             "Ivar returns unsigned long long");
  PASS_EQUAL([rt valueForKey:@"iFloat"], [NSNumber numberWithFloat:123.4f],
             "Ivar returns float");
  PASS_EQUAL([rt valueForKey:@"iDouble"], [NSNumber numberWithDouble:123.45678],
             "Ivar returns double");
  PASS_EQUAL([rt valueForKey:@"iBool"], [NSNumber numberWithBool:true],
             "Ivar returns bool");
  PASS_EQUAL([rt valueForKey:@"iId"], @"id", "Ivar returns id");
  PASS_EQUAL([rt valueForKey:@"iNSPoint"], [NSValue valueWithPoint:p],
             "Ivar returns NSPoint");
  PASS_EQUAL([rt valueForKey:@"iNSRange"], [NSValue valueWithRange:r],
             "Ivar returns NSRange");
  PASS_EQUAL([rt valueForKey:@"iNSRect"], [NSValue valueWithRect:re],
             "Ivar returns NSRect");
  PASS_EQUAL([rt valueForKey:@"iNSSize"], [NSValue valueWithSize:s],
             "Ivar returns NSSize");

  /* Welcome to another session of: Why GCC ObjC is a buggy mess.
   *
   * You'd expect that the type encoding of an ivar would be the same as @encode.
   *
   * Ivar var = class_getInstanceVariable([ReturnTypes class], "_iMyStruct");
   * const char *type = ivar_getTypeEncoding(var);
   * NSLog(@"Type encoding of iMyStruct: %s", type);
   *
   * So type should be equal to @encode(MyStruct) ({?=if})
   *
   * On GCC this is not the case. The type encoding of the ivar is {?="x"i"y"f}.
   * This leads to failure of the following test.
   *
   * So mark this as hopeful until we stop supporting buggy compilers.
   */
  testHopeful = YES;
  PASS_EQUAL([rt valueForKey:@"iMyStruct"],
             [NSValue valueWithBytes:&ms objCType:@encode(MyStruct)],
             "Ivar returns MyStruct");
  testHopeful = NO;
  END_SET("Ivars");

  [rt release];
}

int
main(int argc, char *argv[])
{
  testAccessors();
  testIvars();

  return 0;
}
