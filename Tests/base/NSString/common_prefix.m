#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSString *result;

  result = [@"abc" commonPrefixWithString:nil options:0];
  PASS_EQUAL(result, @"", "common prefix of some string with nil is empty string");

  result = [@"abc" commonPrefixWithString:@"abc" options:0];
  PASS_EQUAL(result, @"abc", "common prefix of identical strings is the entire string");

  result = [@"abc" commonPrefixWithString:@"abx" options:0];
  PASS_EQUAL(result, @"ab", "common prefix of 'abc' and 'abx' is 'ab'");

  result = [@"abc" commonPrefixWithString:@"def" options:0];
  PASS_EQUAL(result, @"", "common prefix of completely different strings is empty");

  result = [@"abc" commonPrefixWithString:@"" options:0];
  PASS_EQUAL(result, @"", "common prefix with an empty string is empty");

  result = [@"abc" commonPrefixWithString:@"a" options:0];
  PASS_EQUAL(result, @"a", "common prefix of 'abc' and 'a' is 'a'");

  result = [@"abc" commonPrefixWithString:@"aöç" options:0];
  PASS_EQUAL(result, @"a", "common prefix of 'abc' and 'aöç' is 'a'");

  result = [@"" commonPrefixWithString:@"abc" options:0];
  PASS_EQUAL(result, @"", "common prefix with an empty base string is empty");

  result = [@"abc" commonPrefixWithString:@"abcx" options:0];
  PASS_EQUAL(result, @"abc", "common prefix of 'abc' and 'abcx' is 'abc'");

  [arp drain];

  return 0;
}

