#import <Foundation/Foundation.h>

#import "Testing.h"

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#if __has_feature(blocks)

BOOL
enumerateEmptySet()
{
  NSIndexSet	  *indexSet;
  BLOCK_SCOPE BOOL blockCalled;

  indexSet = [[NSIndexSet alloc] init];
  blockCalled = NO;

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    blockCalled = YES;
  }];

  [indexSet release];

  return !blockCalled; // PASS if the block is never called
}

BOOL
enumerateStopEarly()
{
  NSMutableIndexSet *indexSet;
  NSRange	     r1, r2;
  BLOCK_SCOPE int    blockCount;

  blockCount = 0;
  r1 = NSMakeRange(5, 10);
  r2 = NSMakeRange(20, 10);

  indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:r1];
  [indexSet addIndexesInRange:r2];

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    blockCount++;
    if (blockCount == 1)
      {
	*stop = YES;
      }
  }];

  [indexSet release];

  return (
    blockCount
    == 1); // PASS if the enumeration stops early after the first block call
}

BOOL
enumerateSingleRange()
{
  NSIndexSet	  *indexSet;
  NSRange	   testRange;
  BLOCK_SCOPE BOOL correctRange;

  testRange = NSMakeRange(5, 10);
  indexSet = [[NSIndexSet alloc] initWithIndexesInRange:testRange];
  correctRange = NO;

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    correctRange = (range.location == testRange.location
		    && range.length == testRange.length);
  }];

  [indexSet release];

  return correctRange; // PASS if the block is called with the correct range
}

BOOL
enumerateMultipleRanges()
{
  NSMutableIndexSet    *indexSet;
  NSRange		r1, r2;
  BLOCK_SCOPE NSInteger callCount;

  r1 = NSMakeRange(5, 5);
  r2 = NSMakeRange(15, 5);
  callCount = 0;

  indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:r1];
  [indexSet addIndexesInRange:r2];

  NSMutableArray *expectedRanges =
    [NSMutableArray arrayWithObjects:[NSValue valueWithRange:r1],
				     [NSValue valueWithRange:r2], nil];

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    [expectedRanges removeObject:[NSValue valueWithRange:range]];
    callCount++;
  }];

  [indexSet release];

  return (expectedRanges.count == 0
	  && callCount == 2); // PASS if all ranges are correctly enumerated
}

BOOL
testConsecutiveRanges()
{
  NSMutableIndexSet    *indexSet;
  NSRange		r1, r2;
  BLOCK_SCOPE BOOL	merged;
  BLOCK_SCOPE NSInteger callCount;

  r1 = NSMakeRange(20, 5);
  r2 = NSMakeRange(25, 5);
  callCount = 0;
  merged = NO;

  indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:r1];
  [indexSet addIndexesInRange:r2];

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    callCount++;
    if (callCount == 1 && range.location == 20 && range.length == 10)
      {
	merged = YES;
      }
  }];

  [indexSet release];

  return merged && (callCount == 1);
}

BOOL
testOverlappingRanges()
{
  NSMutableIndexSet    *indexSet;
  NSRange		r1, r2;
  BLOCK_SCOPE BOOL	merged;
  BLOCK_SCOPE NSInteger callCount;

  r1 = NSMakeRange(5, 5);
  r2 = NSMakeRange(8, 10);
  callCount = 0;
  merged = NO;

  indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:r1];
  [indexSet addIndexesInRange:r2];

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    callCount++;
    if (callCount == 1 && range.location == 5 && range.length == 13)
      {
	merged = YES;
      }
  }];

  [indexSet release];

  return merged && (callCount == 1); // Should only have one merged range
}

BOOL
testReverseOrderAddition()
{
  NSMutableIndexSet    *indexSet;
  NSRange		r1, r2;
  BLOCK_SCOPE BOOL	inOrder;
  BLOCK_SCOPE NSInteger lastLocation;

  r1 = NSMakeRange(30, 5);
  r2 = NSMakeRange(10, 5);
  lastLocation = 0;
  inOrder = YES;

  indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:r1];
  [indexSet addIndexesInRange:r2];

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    if (range.location < lastLocation)
      {
	inOrder = NO;
      }
    lastLocation = range.location;
  }];

  [indexSet release];

  return inOrder;
}

BOOL
testZeroLengthRange()
{
  NSIndexSet	  *indexSet;
  NSRange	   r1;
  BLOCK_SCOPE BOOL neverCalled;

  indexSet = [[NSIndexSet alloc] initWithIndexesInRange:(NSRange){30, 0}];
  neverCalled = YES;

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    neverCalled = NO;
  }];

  [indexSet release];

  return neverCalled; // Block should never be called
}

BOOL
testReverseOrderEnumerationMerge()
{
  NSMutableIndexSet    *indexSet;
  NSMutableArray       *expectedRanges;
  NSRange		r1, r2, r3;
  BLOCK_SCOPE NSInteger index;
  BLOCK_SCOPE BOOL	result;

  r1 = NSMakeRange(5, 5);
  r2 = NSMakeRange(20, 5);
  // Adding out of order to test sorting and reverse enumeration
  r3 = NSMakeRange(15, 5);

  index = 0;
  result = YES;

  expectedRanges =
    [NSMutableArray arrayWithObjects:[NSValue valueWithRange:(NSRange){15, 10}],
				     [NSValue valueWithRange:r1], nil];

  indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:r1];
  [indexSet addIndexesInRange:r2];
  [indexSet addIndexesInRange:r3];

  [indexSet enumerateRangesWithOptions:NSEnumerationReverse
			    usingBlock:^(NSRange range, BOOL *stop) {
			      NSRange expectedRange = [[expectedRanges
				objectAtIndex:index] rangeValue];
			      if (range.location != expectedRange.location
				  || range.length != expectedRange.length)
				{
				  result = NO;
				  *stop = YES;
				}
			      index++;
			    }];

  [indexSet release];

  return result
	 && (index ==
	     [expectedRanges count]); // Should match all in reverse order
}

BOOL
testOutOfRangeEnumeration()
{
  NSIndexSet	  *indexSet;
  NSRange	   r1;
  BLOCK_SCOPE BOOL neverCalled;

  r1 = (NSRange){NSNotFound, 1};
  neverCalled = YES;
  indexSet = [[NSIndexSet alloc] initWithIndexesInRange:(NSRange){1, 2}];

  [indexSet enumerateRangesInRange:r1
			   options:0
			usingBlock:^(NSRange range, BOOL *stop) {
			  neverCalled = NO;
			}];

  [indexSet release];

  return neverCalled;
}

BOOL
testInvalidRangeEnumeration()
{
  NSIndexSet	  *indexSet;
  NSRange	   r1;
  BLOCK_SCOPE BOOL neverCalled;

  r1 = (NSRange){20, 1};
  neverCalled = YES;
  indexSet = [[NSIndexSet alloc] initWithIndexesInRange:(NSRange){1, 2}];

  [indexSet enumerateRangesInRange:r1
			   options:0
			usingBlock:^(NSRange range, BOOL *stop) {
			  neverCalled = NO;
			}];

  [indexSet release];

  return neverCalled;
}

#endif

int
main(int argc, char *argv[])
{

  NSAutoreleasePool *arp = [NSAutoreleasePool new];

  START_SET("NSIndexSet BLOCKS")
#if __has_feature(blocks)
  PASS(enumerateEmptySet(),
       "Enumeration on an empty index set should not call the block.");
  PASS(enumerateSingleRange(),
       "Enumeration should correctly pass a single range.");
  PASS(enumerateMultipleRanges(),
       "Enumeration should correctly pass all ranges.");
  PASS(enumerateStopEarly(), "Enumeration should stop early when requested.");
  PASS(testOverlappingRanges(), "Correctly merge overlapping ranges.");
  PASS(testConsecutiveRanges(), "Correctly merge consecutive ranges.");
  PASS(testZeroLengthRange(), "Ignore zero length ranges.");
  PASS(testReverseOrderAddition(),
       "Maintain correct order after reverse addition.");
  PASS(testReverseOrderEnumerationMerge(),
       "Enumerate ranges in reverse order correctly.");
  PASS(testOutOfRangeEnumeration(), "Enumerate ranges with NSNotFound range");
  PASS(testInvalidRangeEnumeration(), "Enumerate ranges with invalid range");
#else
  SKIP("Blocks support unavailable")
#endif

  END_SET("NSIndexSet BLOCKS")

  [arp release];
  return 0;
}
