#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

#if defined(__has_extension) && __has_extension(blocks)

void
testMutationAffectingSubsequentCall()
{
  NSMutableString *mutableString;
  NSMutableArray  *results;
  NSArray	  *expectedResults;
  NSRange	   range;

  BOOL		     correctResults;
  BOOL		     correctCallCount;
  __block NSUInteger callCount = 0;

  mutableString = [NSMutableString stringWithString: @"Hello World"];
  results = [NSMutableArray array];
  range = NSMakeRange(0, mutableString.length);
  expectedResults = @[ @"Hello", @"World" ];

  [mutableString
    enumerateSubstringsInRange: range
		       options: NSStringEnumerationByWords
		    usingBlock: ^(NSString *substring, NSRange substringRange,
				 NSRange enclosingRange, BOOL *stop) {
		      [results addObject: substring];
		      callCount++;

		      if ([substring isEqualToString: @"Hello"])
			{
			  // Simulate a mutation that affects subsequent
			  // enumeration "Hello " is changed to "Hello"
			  [mutableString
			    deleteCharactersInRange: NSMakeRange(
						      substringRange.location
							+ substringRange.length,
						      1)];
			  *stop = YES;
			}
		    }];

  [mutableString
    enumerateSubstringsInRange: NSMakeRange(5, mutableString.length - 5)
		       options: NSStringEnumerationByWords
		    usingBlock: ^(NSString *substring, NSRange substringRange,
				 NSRange enclosingRange, BOOL *stop) {
		      [results addObject: substring];
		    }];

  correctResults = [results isEqualToArray: expectedResults];
  correctCallCount = (callCount == 1); // Ensure only one call before stopping

  PASS(correctResults && correctCallCount,
       "Enumeration should adjust correctly after string mutation and handle "
       "subsequent calls appropriately.");
}

void
testBasicFunctionality()
{
  NSString	 *string;
  NSMutableArray *results;
  NSArray *expected;
  NSRange	  range;
  BOOL		  result;

  string = @"Hello World";
  results = [NSMutableArray array];
  range = NSMakeRange(0, string.length);
  expected = @[ @"Hello", @"World" ];

  [string
    enumerateSubstringsInRange: range
		       options: NSStringEnumerationByWords
		    usingBlock: ^(NSString *substring, NSRange substringRange,
				 NSRange enclosingRange, BOOL *stop) {
		      [results addObject: substring];
		    }];

  PASS_EQUAL(results, expected, "Should correctly enumerate words.");
}

void
testEmptyRange()
{
  NSString	 *string;
  NSMutableArray *results;
  NSRange	  range;

  string = @"Hello World";
  results = [NSMutableArray array];
  range = NSMakeRange(0, 0);

  [string
    enumerateSubstringsInRange: range
		       options: NSStringEnumerationByWords
		    usingBlock: ^(NSString *substring, NSRange substringRange,
				 NSRange enclosingRange, BOOL *stop) {
		      [results addObject: substring];
		    }];

  PASS(results.count == 0,
       "No substrings should be enumerated for an empty range.");
}

void testLocationOffset() {
  NSString *string;
  NSMutableArray *results;
  NSArray *expected;
  NSRange range;
  
  string = @"Hello World Continued";
  results = [NSMutableArray array];
  range = NSMakeRange(6, [string length] - 6);
  expected = @[ @"World", @"Continued"];

  [string
    enumerateSubstringsInRange: range
           options: NSStringEnumerationByWords
        usingBlock: ^(NSString *substring, NSRange substringRange,
         NSRange enclosingRange, BOOL *stop) {
          [results addObject: substring];
        }];

  PASS_EQUAL(results, expected, "Should correctly enumerate words with location offset.");
}

void
testStoppingEnumeration()
{
  NSString	 *string;
  NSMutableArray *results;
  NSRange	  range;

  string = @"Hello World";
  results = [NSMutableArray array];
  range = NSMakeRange(0, [string length]);

  __block BOOL didStop = NO;

  [string
    enumerateSubstringsInRange: range
		       options: NSStringEnumerationByWords
		    usingBlock: ^(NSString *substring, NSRange substringRange,
				 NSRange enclosingRange, BOOL *stop) {
		      if ([substring isEqualToString: @"Hello"])
			{
			  *stop = YES;
			  didStop = YES;
			}
		      [results addObject: substring];
		    }];

  PASS(didStop && [results count] == 1 && [results[0] isEqualToString: @"Hello"],
       "Enumeration should stop after 'Hello'.");
}

int
main(int argc, const char *argv[])
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  START_SET("Enumerate substrings by lines");

  NSString	    *s1 = @"Line 1\nLine 2";
  __block NSUInteger currentIteration = 0;
  [s1
    enumerateSubstringsInRange: (NSRange){.location = 0, .length = [s1 length]}
		       options: NSStringEnumerationByLines
		    usingBlock: ^(NSString *substring, NSRange substringRange,
				 NSRange enclosingRange, BOOL *stop) {
		      // *stop = YES;
		      if (currentIteration == 0)
			PASS([substring isEqual: @"Line 1"],
			     "First line of \"Line 1\\nLine 2\" is \"Line 1\"");
		      if (currentIteration == 1)
			PASS(
			  [substring isEqual: @"Line 2"],
			  "Second line of \"Line 1\\nLine 2\" is \"Line 2\"");
		      currentIteration++;
		    }];
  PASS(currentIteration == 2,
       "There are only two lines in \"Line 1\\nLine 2\"");
  END_SET("Enumerate substrings by lines");

  START_SET("Enumerate substrings by paragraphs");

  NSString	    *s1 = @"Paragraph 1\nParagraph 2";
  __block NSUInteger currentIteration = 0;
  [s1 enumerateSubstringsInRange: (NSRange){.location = 0, .length = [s1 length]}
			 options: NSStringEnumerationByParagraphs
		      usingBlock: ^(NSString *substring, NSRange substringRange,
				   NSRange enclosingRange, BOOL *stop) {
			// *stop = YES;
			if (currentIteration == 0)
			  PASS([substring isEqual: @"Paragraph 1"],
			       "First paragraph of \"Paragraph 1\\nParagraph "
			       "2\" is \"Paragraph 1\"");
			if (currentIteration == 1)
			  PASS([substring isEqual: @"Paragraph 2"],
			       "Second paragraph of \"Paragraph 1\\nParagraph "
			       "2\" is \"Paragraph 2\"");
			currentIteration++;
		      }];
  PASS(currentIteration == 2,
       "There are only two paragraphs in \"Paragraph 1\\nParagraph 2\"");
  END_SET("Enumerate substrings by paragraphs");

  START_SET("Enumerate substrings by words");

  testBasicFunctionality();
  testEmptyRange();
  testLocationOffset();
  testStoppingEnumeration();
  testMutationAffectingSubsequentCall();

  NSString	    *s1 = @"Word1 word2.";
  __block NSUInteger currentIteration = 0;
  [s1 enumerateSubstringsInRange: (NSRange){.location = 0, .length = [s1 length]}
			 options: NSStringEnumerationByWords
		      usingBlock: ^(NSString *substring, NSRange substringRange,
				   NSRange enclosingRange, BOOL *stop) {
			// *stop = YES;
			if (currentIteration == 0)
			  PASS([substring isEqual: @"Word1"],
			       "First word of \"Word1 word2.\" is \"Word1\"");
			if (currentIteration == 1)
			  PASS([substring isEqual: @"word2"],
			       "Second word of \"Word1 word2.\" is \"word2\"");
			currentIteration++;
		      }];
  PASS(currentIteration == 2, "There are only two words in \"Word1 word2.\"");
  END_SET("Enumerate substrings by words");

  START_SET("Enumerate substrings by sentences");

  NSString	    *s1 = @"Sentence 1. Sentence 2.";
  __block NSUInteger currentIteration = 0;
  [s1 enumerateSubstringsInRange: (NSRange){.location = 0, .length = [s1 length]}
			 options: NSStringEnumerationBySentences
		      usingBlock: ^(NSString *substring, NSRange substringRange,
				   NSRange enclosingRange, BOOL *stop) {
			// *stop = YES;
			if (currentIteration == 0)
			  PASS([substring isEqual: @"Sentence 1. "],
			       "First sentence of \"Sentence 1. Sentence 2.\" "
			       "is \"Sentence 1. \"");
			if (currentIteration == 1)
			  PASS([substring isEqual: @"Sentence 2."],
			       "Second sentence of \"Sentence 1. Sentence 2.\" "
			       "is \"Sentence 2.\"");
			currentIteration++;
		      }];
  PASS(currentIteration == 2,
       "There are only two sentences in \"Sentence 1. Sentence 2.");
  END_SET("Enumerate substrings by sentences");

  [pool drain];

  return 0;
}
#else
int
main(int argc, const char *argv[])
{
  return 0;
}
#endif
