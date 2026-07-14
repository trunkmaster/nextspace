#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

  static void callback(void *context, NSTextCheckingResult *match,
    NSMatchingFlags flags, BOOL *stop)
  {
    if (match)
      {
        (*(NSInteger*)context)++;
      }
    else
      {
	NSLog(@"FLAGS: %lu", (unsigned long)flags);
      }
  }

int main(void)
{
  START_SET("NSRegularExpression + callbacks")

#if !(__APPLE__ || GS_USE_ICU)
    SKIP("NSRegularExpression not built, please install libicu")
#else
  NSString 		*sourceText;
  NSRegularExpression 	*simpleRegex;
  NSRange 		sourceRange;
  NSArray 		*simpleMatches;
  NSUInteger		matchCount = 0;

  // load source file containing some text repeated 1000 times
  sourceText = [NSString stringWithContentsOfFile: @"bigSource.txt"];
  simpleRegex = [NSRegularExpression regularExpressionWithPattern: @"ABC"
							  options: 0
							    error: NULL];

  sourceRange = NSMakeRange(0, [sourceText length] - 1);
  // matchesInString:... uses enumerateMatchesInString:... without any callbacks
  simpleMatches = [simpleRegex matchesInString: sourceText
				       options: 0
					 range: sourceRange];

  // NSLog(@"Simple matches: %ld", [simpleMatches count]);
  PASS([simpleMatches count] == 1000, "1000 matches");

# ifndef __has_feature
# define __has_feature(x) 0
# endif
# if __has_feature(blocks)

  // call enumerateMatchesInString:... directly, with block
  __block NSInteger blockCount = 0;
  [simpleRegex enumerateMatchesInString: sourceText
				options: NSMatchingReportProgress
				  range: NSMakeRange(0, [sourceText length] - 1)
                             usingBlock:
    ^(NSTextCheckingResult * result, NSMatchingFlags flags, BOOL *stop)
      {
        if (result)
	  {
	    blockCount++;
	  }
	else
	  {
	    NSLog(@"FLAGS: %lu", (unsigned long)flags);
	  }
      }];

//  NSLog(@"Number of matches: %ld", blockCount);
  PASS(blockCount == 1000, "enumerate with block has same count");
# endif

#endif

#if     defined(GNUSTEP_BASE_LIBRARY)

  [simpleRegex enumerateMatchesInString: sourceText
				options: NSMatchingReportProgress
				  range: NSMakeRange(0, [sourceText length] - 1)
			       callback: callback
				context: (void*)&matchCount];
//  NSLog(@"Number of matches: %ld", matchCount);
  PASS(matchCount == 1000, "enumerate with callback has same count");
#endif

  END_SET("NSRegularExpression + callbacks")
  return 0;
}
