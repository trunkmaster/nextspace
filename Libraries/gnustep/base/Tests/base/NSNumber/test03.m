#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDecimalNumber.h>

int main()
{
  START_SET("GSDecimalCompare")

  NSDecimalNumber *n1;
  NSDecimalNumber *n2;
  NSComparisonResult result;

  // Test comparing positive numbers
  n1 = [NSDecimalNumber decimalNumberWithString:@"0.05" locale:nil];
  n2 = [NSDecimalNumber decimalNumberWithString:@"0.10" locale:nil];
  result = [n1 compare:n2];
  PASS(result == NSOrderedAscending, "0.05 < 0.10");

  // Test comparing negative numbers
  n1 = [NSDecimalNumber decimalNumberWithString:@"-0.10" locale:nil];
  n2 = [NSDecimalNumber decimalNumberWithString:@"-0.05" locale:nil];
  result = [n1 compare:n2];
  PASS(result == NSOrderedAscending, "-0.10 < -0.05");

  // Test comparing a positive and a negative number
  n1 = [NSDecimalNumber decimalNumberWithString:@"-0.10" locale:nil];
  n2 = [NSDecimalNumber decimalNumberWithString:@"0.10" locale:nil];
  result = [n1 compare:n2];
  PASS(result == NSOrderedAscending, "-0.10 < 0.10");

  // Test comparing zeros
  n1 = [NSDecimalNumber decimalNumberWithString:@"0.00" locale:nil];
  n2 = [NSDecimalNumber decimalNumberWithString:@"0.00" locale:nil];
  result = [n1 compare:n2];
  PASS(result == NSOrderedSame, "0.00 == 0.00");

  // Test comparing zero with a positive number
  n1 = [NSDecimalNumber decimalNumberWithString:@"0.00" locale:nil];
  n2 = [NSDecimalNumber decimalNumberWithString:@"0.02" locale:nil];
  result = [n1 compare:n2];
  PASS(result == NSOrderedAscending, "0.00 < 0.02");

  // Test comparing zero with a negative number
  n1 = [NSDecimalNumber decimalNumberWithString:@"-0.02" locale:nil];
  n2 = [NSDecimalNumber decimalNumberWithString:@"0.00" locale:nil];
  result = [n1 compare:n2];
  PASS(result == NSOrderedAscending, "-0.02 < 0.00");

  // Add more test cases as needed to cover edge cases and other scenarios

  END_SET("GSDecimalCompare")

  return 0;
}

