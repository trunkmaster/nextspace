#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

#import "Testing.h"

#if defined(__has_extension) && __has_extension(blocks)

BOOL testEnumerateSimpleLines() {
  NSString *testString = @"First line\nSecond line\nThird line";
  NSMutableArray *collectedLines = [NSMutableArray array];
  NSArray *expectedLines = @[@"First line", @"Second line", @"Third line"];

  [testString enumerateLinesUsingBlock: ^(NSString *line, BOOL *stop) {
    [collectedLines addObject: line];
  }];

  return [collectedLines isEqualToArray: expectedLines];
}

BOOL testEnumerateCRLFLines() {
  NSString *testString = @"First line\r\nSecond line\r\nThird line";
  NSMutableArray *collectedLines = [NSMutableArray array];
  NSArray *expectedLines = @[@"First line", @"Second line", @"Third line"];

  [testString enumerateLinesUsingBlock: ^(NSString *line, BOOL *stop) {
    [collectedLines addObject: line];
  }];

  return [collectedLines isEqualToArray: expectedLines];
}

BOOL testStopEarly() {
  NSString *testString = @"First line\nSecond line\nThird line";
  __block int lineCount = 0;

  [testString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    lineCount++;
    if ([line isEqualToString:@"Second line"]) {
      *stop = YES;
    }
  }];

  return lineCount == 2; // Should stop after the second line
}

BOOL testEmptyString() {
  NSString *testString = @"";
  __block BOOL blockCalled = NO;

  [testString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    blockCalled = YES;
  }];

  return !blockCalled; // Block should not be called
}

BOOL testSingleLineNoBreaks() {
  NSString *testString = @"Single line without line breaks";
  __block NSString *receivedLine = nil;

  [testString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    receivedLine = line;
  }];

  return [receivedLine isEqualToString:testString];
}

int main() {
  NSAutoreleasePool *arp = [NSAutoreleasePool new];

  PASS(testEnumerateSimpleLines(), "Should enumerate all lines correctly.");
  PASS(testEnumerateCRLFLines(), "Should enumerate all CRLF lines correctly.");
  PASS(testStopEarly(), "Should stop enumeration early as directed.");
  PASS(testEmptyString(), "Should not call block for empty string.");
  PASS(testSingleLineNoBreaks(), "Should handle single line without line breaks correctly.");

  [arp release];
  return 0;
}

#else

int main (int argc, const char * argv[])
{
  return 0;
}

#endif