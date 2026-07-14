/** Implementation of NSRegularExpression for GNUStep

   Copyright (C) 2010 Free Software Foundation, Inc.

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


#define	EXPOSE_NSRegularExpression_IVARS	1
#import "common.h"

#if GS_USE_ICU == 1
#if defined(HAVE_UNICODE_UREGEX_H)
#include <unicode/uregex.h>
#elif defined(HAVE_ICU_H)
#include <icu.h>
#endif

/* FIXME It would be nice to use autoconf for checking whether uregex_openUText
 * is defined.  However the naive check using AC_CHECK_FUNCS(uregex_openUText)
 * won't work because libicu internally renames all entry points with some cpp
 * magic.
 */
#if !defined(HAVE_UREGEX_OPENUTEXT)
#if U_ICU_VERSION_MAJOR_NUM > 4 || (U_ICU_VERSION_MAJOR_NUM == 4 && U_ICU_VERSION_MINOR_NUM >= 4) || defined(HAVE_ICU_H)
#define HAVE_UREGEX_OPENUTEXT 1
#endif
#endif

/* Until the uregex_replaceAllUText() and uregex_replaceFirstUText() work
 * without leaking memory, we can't use them :-(
 * Preoblem exists on Ubuntu in 2024 with icu-74.2
 */
#if defined(HAVE_UREGEX_OPENUTEXT)
#undef HAVE_UREGEX_OPENUTEXT
#endif

#define NSRegularExpressionWorks

#define GSREGEXTYPE URegularExpression
#import "GSICUString.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSRegularExpression.h"
#import "Foundation/NSTextCheckingResult.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSNotification.h"
#import "Foundation/FoundationErrors.h"
#import "Foundation/NSError.h"

typedef struct {
  GSRegexEnumerationCallback	h;	// The handler callback function
  void				*c;	// Context for this enumeration
} GSRegexContext;


/**
 * To be helpful, Apple decided to define a set of flags that mean exactly the
 * same thing as the URegexpFlags enum in libicu, but have different values.
 * This was completely stupid, but we probably have to live with it.  We could
 * in theory use the libicu values directly (that would be sensible), but that
 * would break any code that didn't correctly use the symbolic constants.
 */
uint32_t
NSRegularExpressionOptionsToURegexpFlags(NSRegularExpressionOptions opts)
{
  uint32_t flags = 0;

  if (opts & NSRegularExpressionCaseInsensitive)
    {
      flags |= UREGEX_CASE_INSENSITIVE;
    }
  if (opts & NSRegularExpressionAllowCommentsAndWhitespace)
    {
      flags |= UREGEX_COMMENTS;
    }
  if (opts & NSRegularExpressionIgnoreMetacharacters)
    {
      flags |= UREGEX_LITERAL;
    }
  if (opts & NSRegularExpressionDotMatchesLineSeparators)
    {
      flags |= UREGEX_DOTALL;
    }
  if (opts & NSRegularExpressionAnchorsMatchLines)
    {
      flags |= UREGEX_MULTILINE;
    }
  if (opts & NSRegularExpressionUseUnixLineSeparators)
    {
      flags |= UREGEX_UNIX_LINES;
    }
  if (opts & NSRegularExpressionUseUnicodeWordBoundaries)
    {
      flags |= UREGEX_UWORD;
    }
  return flags;
}

@implementation NSRegularExpression

/* Callback method to invoke a block
 */
static void
blockCallback(
  void *context, NSTextCheckingResult *match,
  NSMatchingFlags flags, BOOL *shouldStop)
{
  GSRegexBlock	block = (GSRegexBlock)context;

  if (block)
    {
      CALL_BLOCK(block, match, flags, shouldStop);
    }
}


+ (NSRegularExpression*) regularExpressionWithPattern: (NSString*)aPattern
                                              options: (NSRegularExpressionOptions)opts
                                                error: (NSError**)e
{
  NSRegularExpression   *r;

  r = [[self alloc] initWithPattern: aPattern
                            options: opts
                              error: e];
  return AUTORELEASE(r);
}


#if HAVE_UREGEX_OPENUTEXT
- (id) initWithPattern: (NSString*)aPattern
	       options: (NSRegularExpressionOptions)opts
		 error: (NSError**)e
{
  uint32_t	flags = NSRegularExpressionOptionsToURegexpFlags(opts);
  UText		p = UTEXT_INITIALIZER;
  UParseError	pe = {0};
  UErrorCode	s = 0;

  // Raise an NSInvalidArgumentException to match macOS behaviour.
  if (!aPattern)
    {
      NSException *exp;

      exp = [NSException exceptionWithName: NSInvalidArgumentException
                                    reason: @"nil argument"
      				  userInfo: nil];
      RELEASE(self);
      [exp raise];
    }

#if !__has_feature(blocks)
  GSOnceMLog(@"Warning: this implementation of NSRegularExpression uses"
    @" -enumerateMatchesInString:options:range:callback:context: as a"
    @" primitive method rather than the blocks-dependtent method used"
    @" by Apple.  If you must subclass NSRegularExpression, you must"
    @" bear that difference in mind");
#endif

  UTextInitWithNSString(&p, aPattern);
  regex = uregex_openUText(&p, flags, &pe, &s);
  utext_close(&p);
  if (U_FAILURE(s))
    {
      /* Match macOS behaviour if the pattern is invalid.
       * Example:
       *   Domain=NSCocoaErrorDomain
       *   Code=2048 "The value “<PATTERN>” is invalid."
       *   UserInfo={NSInvalidValue=<PATTERN>}
       */
      if (e)
        {
          NSDictionary  *userInfo;
          NSString      *description;

          description = [NSString
	    stringWithFormat: @"The value “%@” is invalid.", aPattern];

          userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            aPattern, @"NSInvalidValue",
            description, NSLocalizedDescriptionKey,
            nil];

          *e = [NSError errorWithDomain: NSCocoaErrorDomain
                                   code: NSFormattingError
                               userInfo: userInfo];
        }

      DESTROY(self);
      return self;
    }
  options = opts;
  return self;
}

- (BOOL) isEqual: (id)obj
{
  if ([obj isKindOfClass: [NSRegularExpression class]])
    {
      if (self == obj)
        {
          return YES;
        }
      else if (options != ((NSRegularExpression*)obj)->options)
        {
          return NO;
        }
      else
        {
          UErrorCode  myErr      = 0;
          UErrorCode  theirErr   = 0;
          const UText *myText    = uregex_patternUText(regex, &myErr);
          const UText *theirText =
           uregex_patternUText(((NSRegularExpression*)obj)->regex, &theirErr);
          if (U_FAILURE(myErr) != U_FAILURE(theirErr))
            {
              return NO;
            }
          else if (U_FAILURE(myErr) && U_FAILURE(theirErr))
            {
              return YES;
            }
          return utext_equals(myText, theirText);
        }
    }
  else
    {
      return [super isEqual: obj];
    }
}

- (NSString*) pattern
{
  UErrorCode	s = 0;
  UText		*t = uregex_patternUText(regex, &s);
  GSUTextString	*str = NULL;

  if (U_FAILURE(s))
    {
      return nil;
    }
  str = [GSUTextString new];
  utext_clone(&str->txt, t, FALSE, TRUE, &s);
  return AUTORELEASE(str);
}
#else
- (id) initWithPattern: (NSString*)aPattern
	       options: (NSRegularExpressionOptions)opts
		 error: (NSError**)e
{
  int32_t	length = [aPattern length];
  uint32_t	flags = NSRegularExpressionOptionsToURegexpFlags(opts);
  UParseError	pe = {0};
  UErrorCode	s = 0;
  TEMP_BUFFER(buffer, length);

#if !__has_feature(blocks)
  GSOnceMLog(@"Warning: this implementation of NSRegularExpression uses"
    @" -enumerateMatchesInString:options:range:callback:context: as a"
    @" primitive method rather than the blocks-dependtent method used"
    @" by Apple.  If you must subclass NSRegularExpression, you must"
    @" bear that difference in mind");
#endif

  // Raise an NSInvalidArgumentException to match macOS behaviour.
  if (!aPattern)
    {
      NSException *exp;

      exp = [NSException exceptionWithName: NSInvalidArgumentException
                                    reason: @"nil argument"
      				  userInfo: nil];
      RELEASE(self);
      [exp raise];
    }

  [aPattern getCharacters: buffer range: NSMakeRange(0, length)];
  regex = uregex_open(buffer, length, flags, &pe, &s);
  if (U_FAILURE(s))
    {
      /* Match macOS behaviour if the pattern is invalid.
       * Example:
       *   Domain=NSCocoaErrorDomain
       *   Code=2048 "The value “<PATTERN>” is invalid."
       *   UserInfo={NSInvalidValue=<PATTERN>}
       */
      if (e)
        {
          NSDictionary  *userInfo;
          NSString      *description;

          description = [NSString
	    stringWithFormat: @"The value “%@” is invalid.", aPattern];

          userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            aPattern, @"NSInvalidValue",
            description, NSLocalizedDescriptionKey,
            nil];

          *e = [NSError errorWithDomain: NSCocoaErrorDomain
                                   code: NSFormattingError
                               userInfo: userInfo];
        }

      DESTROY(self);
      return self;
    }
  options = opts;
  return self;
}

- (BOOL) isEqual: (id)obj
{
  if ([obj isKindOfClass: [NSRegularExpression class]])
    {
      if (self == obj)
        {
          return YES;
        }
      else if (options != ((NSRegularExpression*)obj)->options)
        {
          return NO;
        }
      else
        {
          UErrorCode  myErr      = 0;
          UErrorCode  theirErr   = 0;
          int32_t     myLen      = 0;
          int32_t     theirLen   = 0;
          const UChar *myText    = uregex_pattern(regex, &myLen, &myErr);
          const UChar *theirText = uregex_pattern(
                                     ((NSRegularExpression*)obj)->regex,
                                     &theirLen, &theirErr);
          if (U_FAILURE(myErr) != U_FAILURE(theirErr))
            {
              return NO;
            }
          else if (U_FAILURE(myErr) && U_FAILURE(theirErr))
            {
              return YES;
            }
          if (myLen != theirLen)
            {
              return NO;
            }
          return (0 == memcmp((const void*)myText, (const void*)theirText, myLen));
        }
    }
  else
    {
      return [super isEqual: obj];
    }
}



- (NSString*) pattern
{
  UErrorCode	s = 0;
  int32_t	length;
  const unichar *pattern = uregex_pattern(regex, &length, &s);

  if (U_FAILURE(s))
    {
      return nil;
    }
  return [NSString stringWithCharacters: pattern length: length];
}
#endif

- (NSUInteger) hash
{
  return [[self pattern] hash] ^ options;
}

static UBool
callback(const void *context, int32_t steps)
{
  BOOL			stop = NO;
  GSRegexContext	*c = (GSRegexContext*)context;

  if (NULL == c)
    {
      return FALSE;
    }
  (*c->h)(c->c, nil, NSMatchingProgress, &stop);

  return (stop ? FALSE : TRUE);
}


#define DEFAULT_WORK_LIMIT 1500
/**
 * The work limit specifies the number of iterations the matcher will do before
 * aborting an operation. This ensures that degenerate pattern/input
 * combinations don't send the application into what for all intents and
 * purposes seems like an infinite loop.
 */
static int32_t _workLimit = DEFAULT_WORK_LIMIT;

+ (void) _defaultsChanged: (NSNotification*)n
{
  NSUserDefaults        *defs = [NSUserDefaults standardUserDefaults];
  id                    value;
  int32_t               newLimit = DEFAULT_WORK_LIMIT;

  value = [defs objectForKey: @"GSRegularExpressionWorkLimit"];
  if ([value respondsToSelector: @selector(intValue)])
    {
      int32_t   v = [value intValue];

      if (v >= 0)
        {
          newLimit = v;
        }
    }
  _workLimit = newLimit;
}

+ (void) initialize
{
  if (self == [NSRegularExpression class])
    {
      [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector(_defaultsChanged:)
              name: NSUserDefaultsDidChangeNotification
            object: nil];
      [self _defaultsChanged: nil];
    }
}




/**
 * Sets up a libicu regex object for use.  Note: the documentation states that
 * NSRegularExpression must be thread safe.  To accomplish this, we store a
 * prototype URegularExpression in the object, and then clone it in each
 * method.  This is required because URegularExpression, unlike
 * NSRegularExpression, is stateful, and sharing this state between threads
 * would break concurrent calls.
 */
#if HAVE_UREGEX_OPENUTEXT
static URegularExpression *
setupRegex(URegularExpression *regex,
  NSString *string,
  UText *txt,
  NSMatchingOptions options,
  NSRange range,
  GSRegexContext *ctx)
{
  UErrorCode		s = 0;
  URegularExpression	*r = uregex_clone(regex, &s);

  if (options & NSMatchingReportProgress)
    {
      uregex_setMatchCallback(r, callback, ctx, &s);
      if (U_FAILURE(s)) NSLog(@"uregex_setMatchCallback() failed");
    }
  UTextInitWithNSString(txt, string);
  uregex_setUText(r, txt, &s);
  uregex_setRegion(r, range.location, range.location+range.length, &s);
  if (options & NSMatchingWithoutAnchoringBounds)
    {
      uregex_useAnchoringBounds(r, FALSE, &s);
    }
  if (options & NSMatchingWithTransparentBounds)
    {
      uregex_useTransparentBounds(r, TRUE, &s);
    }
  uregex_setTimeLimit(r, _workLimit, &s);
  if (U_FAILURE(s))
    {
      uregex_close(r);
      return NULL;
    }
  return r;
}
#else
static URegularExpression *
setupRegex(URegularExpression *regex,
  NSString *string,
  unichar *buffer,
  int32_t length,
  NSMatchingOptions options,
  NSRange range,
  GSRegexContext *ctx)
{
  UErrorCode		s = 0;
  URegularExpression	*r = uregex_clone(regex, &s);

  [string getCharacters: buffer range: NSMakeRange(0, length)];
  if (options & NSMatchingReportProgress)
    {
      uregex_setMatchCallback(r, callback, ctx, &s);
      if (U_FAILURE(s)) NSLog(@"uregex_setMatchCallback() failed");
    }
  uregex_setText(r, buffer, length, &s);
  uregex_setRegion(r, range.location, range.location+range.length, &s);
  if (options & NSMatchingWithoutAnchoringBounds)
    {
      uregex_useAnchoringBounds(r, FALSE, &s);
    }
  if (options & NSMatchingWithTransparentBounds)
    {
      uregex_useTransparentBounds(r, TRUE, &s);
    }
  uregex_setTimeLimit(r, _workLimit, &s);
  if (U_FAILURE(s))
    {
      uregex_close(r);
      return NULL;
    }
  return r;
}
#endif

static uint32_t
prepareResult(NSRegularExpression *regex,
  URegularExpression *r,
  NSRangePointer ranges,
  NSUInteger groups,
  UErrorCode *s)
{
  uint32_t	flags = 0;
  NSUInteger	i = 0;

  for (i = 0; i < groups; i++)
    {
      NSInteger start = uregex_start(r, i, s);
      NSInteger end = uregex_end(r, i, s);

      /* The ICU API defines -1 as not found. Convert to
       * NSNotFound if applicable.
       */
      if (start == -1)
        {
          start = NSNotFound;
        }
      if (end == -1)
        {
          end = NSNotFound;
        }

      if (end < start)
        {
          flags |= NSMatchingInternalError;
          end = start = NSNotFound;
        }
      ranges[i] = NSMakeRange(start, end-start);
    }
  if (uregex_hitEnd(r, s))
    {
      flags |= NSMatchingHitEnd;
    }
  if (uregex_requireEnd(r, s))
    {
      flags |= NSMatchingRequiredEnd;
    }
  if (0 != *s)
    {
      flags |= NSMatchingInternalError;
    }
  return flags;
}


#if HAVE_UREGEX_OPENUTEXT
- (void) enumerateMatchesInString: (NSString*)string
                          options: (NSMatchingOptions)opts
                            range: (NSRange)range
			 callback: (GSRegexEnumerationCallback)handler
			  context: (void*)context
{
  UErrorCode	        s = 0;
  UText		        txt = UTEXT_INITIALIZER;
  BOOL		        stop = NO;
  GSRegexContext	ctx = { handler, context };
  URegularExpression    *r = setupRegex(regex, string, &txt, opts, range, &ctx);
  NSUInteger	        groups = [self numberOfCaptureGroups] + 1;
  NSRange	        ranges[groups];

  // Should this throw some kind of exception?
  if (NULL == r)
    {
      return;
    }
  if (opts & NSMatchingAnchored)
    {
      if (uregex_lookingAt(r, -1, &s) && (0 == s))
	{
	  // FIXME: Factor all of this out into prepareResult()
	  uint32_t		flags;
	  NSTextCheckingResult *result;

	  flags = prepareResult(self, r, ranges, groups, &s);
	  result = (flags & NSMatchingInternalError) ? nil
            : [NSTextCheckingResult
	    regularExpressionCheckingResultWithRanges: ranges
						count: groups
				    regularExpression: self];
	  (*handler)(context, result, flags, &stop);
	}
    }
  else
    {
      while (!stop && uregex_findNext(r, &s) && (0 == s))
	{
	  uint32_t		flags;
	  NSTextCheckingResult	*result;

	  flags = prepareResult(self, r, ranges, groups, &s);
	  result = (flags & NSMatchingInternalError) ? nil
            : [NSTextCheckingResult
	    regularExpressionCheckingResultWithRanges: ranges
						count: groups
				    regularExpression: self];
	  (*handler)(context, result, flags, &stop);
	}
    }
  if (opts & NSMatchingCompleted)
    {
      (*handler)(context, nil, NSMatchingCompleted, &stop);
    }
  utext_close(&txt);
  uregex_close(r);
}
#else
- (void) enumerateMatchesInString: (NSString*)string
                          options: (NSMatchingOptions)opts
                            range: (NSRange)range
			 callback: (GSRegexEnumerationCallback)handler
			  context: (void*)context
{
  UErrorCode	        s = 0;
  BOOL		        stop = NO;
  int32_t	        length = [string length];
  URegularExpression    *r;
  NSUInteger	        groups = [self numberOfCaptureGroups] + 1;
  NSRange	        ranges[groups];
  GSRegexContext	ctx = { handler, context };
  TEMP_BUFFER(buffer, length);

  r = setupRegex(regex, string, buffer, length, opts, range, &ctx);

  // Should this throw some kind of exception?
  if (NULL == r)
    {
      return;
    }
  if (opts & NSMatchingAnchored)
    {
      if (uregex_lookingAt(r, -1, &s) && (0 == s))
	{
	  // FIXME: Factor all of this out into prepareResult()
	  uint32_t		flags;
	  NSTextCheckingResult *result;

	  flags = prepareResult(self, r, ranges, groups, &s);
	  result = (flags & NSMatchingInternalError) ? nil
            : [NSTextCheckingResult
	    regularExpressionCheckingResultWithRanges: ranges
						count: groups
				    regularExpression: self];
	  (*handler)(context, result, flags, &stop);
	}
    }
  else
    {
      while (!stop && uregex_findNext(r, &s) && (0 == s))
	{
	  uint32_t		flags;
	  NSTextCheckingResult	*result;

	  flags = prepareResult(self, r, ranges, groups, &s);
	  result = (flags & NSMatchingInternalError) ? nil
            : [NSTextCheckingResult
	    regularExpressionCheckingResultWithRanges: ranges
						count: groups
				    regularExpression: self];
	  (*handler)(context, result, flags, &stop);
	}
    }
  if (opts & NSMatchingCompleted)
    {
      (*handler)(context, nil, NSMatchingCompleted, &stop);
    }
  uregex_close(r);
}
#endif


- (void) enumerateMatchesInString: (NSString*)string
                          options: (NSMatchingOptions)opts
                            range: (NSRange)range
                       usingBlock: (GSRegexBlock)block
{
  [self enumerateMatchesInString: string
                         options: opts
                           range: range
			callback: blockCallback
			 context: (void*)block];
}


static void
countCallback(void *context, NSTextCheckingResult *match,
  NSMatchingFlags flags, BOOL *shouldStop)
{
  (*(NSUInteger*)context)++;
  *shouldStop = NO;
}

/* The remaining methods are all meant (by Apple) to be wrappers around
 * the primitive method that takes a block argument.  To avoid compiler
 * dependency we use the more portable GNUstep specific primitive.
 */
- (NSUInteger) numberOfMatchesInString: (NSString*)string
                               options: (NSMatchingOptions)opts
                                 range: (NSRange)range

{
  NSUInteger	count = 0;

  opts &= ~NSMatchingReportProgress;
  opts &= ~NSMatchingReportCompletion;

  [self enumerateMatchesInString: string
                         options: opts
                           range: range
			callback: countCallback
			 context: (void*)&count];
  return count;
}

static void
firstCallback(void *context, NSTextCheckingResult *match,
  NSMatchingFlags flags, BOOL *shouldStop)
{
  (*(NSTextCheckingResult**)context) = match;
  *shouldStop = YES;
}

- (NSTextCheckingResult*) firstMatchInString: (NSString*)string
                                     options: (NSMatchingOptions)opts
                                       range: (NSRange)range
{
  NSTextCheckingResult	*r = nil;

  opts &= ~NSMatchingReportProgress;
  opts &= ~NSMatchingReportCompletion;

  [self enumerateMatchesInString: string
			 options: opts
			   range: range
		        callback: firstCallback
			 context: (void*)&r];
  return r;
}

static void
arrayCallback(void *context, NSTextCheckingResult *match,
  NSMatchingFlags flags, BOOL *shouldStop)
{
  [((NSMutableArray*)context) addObject: match];
  *shouldStop = NO;
}

- (NSArray*) matchesInString: (NSString*)string
                     options:(NSMatchingOptions)opts
                       range:(NSRange)range
{
  NSMutableArray	*array = [NSMutableArray array];

  opts &= ~NSMatchingReportProgress;
  opts &= ~NSMatchingReportCompletion;

  [self enumerateMatchesInString: string
			 options: opts
			   range: range
		        callback: arrayCallback
			 context: (void*)array];
  return array;
}

static void
rangeCallback(void *context, NSTextCheckingResult *match,
  NSMatchingFlags flags, BOOL *shouldStop)
{
  *((NSRange*)context) = [match range];
  *shouldStop = YES;
}

- (NSRange) rangeOfFirstMatchInString: (NSString*)string
                              options: (NSMatchingOptions)opts
                                range: (NSRange)range
{
  NSRange	r = {NSNotFound, 0};

  opts &= ~NSMatchingReportProgress;
  opts &= ~NSMatchingReportCompletion;

  [self enumerateMatchesInString: string
			 options: opts
			   range: range
		        callback: rangeCallback
			 context: (void*)&r];
  return r;
}

#if HAVE_UREGEX_OPENUTEXT
- (NSUInteger) replaceMatchesInString: (NSMutableString*)string
                              options: (NSMatchingOptions)opts
                                range: (NSRange)range
                         withTemplate: (NSString*)template
{
  // FIXME: We're computing a value that is most likely ignored in an
  // expensive way.
  NSInteger	results = [self numberOfMatchesInString: string
						options: opts
						  range: range];
  UErrorCode	s = 0;
  UText		txt = UTEXT_INITIALIZER;
  UText		replacement = UTEXT_INITIALIZER;
  GSUTextString	*ret = [GSUTextString new];
  URegularExpression *r = setupRegex(regex, string, &txt, opts, range, 0);
  UText		*output = NULL;

  UTextInitWithNSString(&replacement, template);

  output = uregex_replaceAllUText(r, &replacement, NULL, &s);
  if (0 != s)
    {
      uregex_close(r);
      utext_close(&replacement);
      utext_close(&txt);
      DESTROY(ret);
      return 0;
    }
  utext_clone(&ret->txt, output, TRUE, TRUE, &s);
  [string setString: ret];
  RELEASE(ret);
  uregex_close(r);

  utext_close(&txt);
  utext_close(output);
  utext_close(&replacement);
  return results;
}

- (NSString*) stringByReplacingMatchesInString: (NSString*)string
                                       options: (NSMatchingOptions)opts
                                         range: (NSRange)range
                                  withTemplate: (NSString*)template
{
  UErrorCode	s = 0;
  UText		txt = UTEXT_INITIALIZER;
  UText		replacement = UTEXT_INITIALIZER;
  UText		*output = NULL;
  GSUTextString	*ret = [GSUTextString new];
  URegularExpression *r = setupRegex(regex, string, &txt, opts, range, 0);

  UTextInitWithNSString(&replacement, template);

  output = uregex_replaceAllUText(r, &replacement, NULL, &s);
  if (0 != s)
    {
      uregex_close(r);
      utext_close(&replacement);
      utext_close(&txt);
      DESTROY(ret);
      return nil;
    }
  utext_clone(&ret->txt, output, TRUE, TRUE, &s);
  uregex_close(r);

  utext_close(&txt);
  utext_close(output);
  utext_close(&replacement);
  return AUTORELEASE(ret);
}

- (NSString*) replacementStringForResult: (NSTextCheckingResult*)result
                                inString: (NSString*)string
                                  offset: (NSInteger)offset
                                template: (NSString*)template
{
  UErrorCode	s = 0;
  UText		txt = UTEXT_INITIALIZER;
  UText		replacement = UTEXT_INITIALIZER;
  UText		*output = NULL;
  GSUTextString	*ret = [GSUTextString new];
  NSRange	range = [result range];
  URegularExpression *r = setupRegex(regex,
				     [string substringWithRange: range],
				     &txt,
				     0,
				     NSMakeRange(0, range.length),
				     0);

  UTextInitWithNSString(&replacement, template);

  output = uregex_replaceFirstUText(r, &replacement, NULL, &s);
  if (0 != s)
    {
      uregex_close(r);
      utext_close(&replacement);
      utext_close(&txt);
      DESTROY(ret);
      return nil;
    }
  utext_clone(&ret->txt, output, TRUE, TRUE, &s);
  utext_close(output);
  uregex_close(r);
  utext_close(&txt);
  utext_close(&replacement);
  return AUTORELEASE(ret);
}
#else
- (NSUInteger) replaceMatchesInString: (NSMutableString*)string
                              options: (NSMatchingOptions)opts
                                range: (NSRange)range
                         withTemplate: (NSString*)template
{
  // FIXME: We're computing a value that is most likely ignored in an
  // expensive way.
  NSInteger	results = [self numberOfMatchesInString: string
						options: opts
						  range: range];
  if (results > 0)
    {
      UErrorCode	s = 0;
      uint32_t		length = [string length];
      uint32_t		replLength = [template length];
      unichar		replacement[replLength];
      int32_t		outLength;
      URegularExpression *r;
      TEMP_BUFFER(buffer, length);

      r = setupRegex(regex, string, buffer, length, opts, range, 0);
      [template getCharacters: replacement range: NSMakeRange(0, replLength)];

      outLength = uregex_replaceAll(r, replacement, replLength, NULL, 0, &s);
      if (0 == s || U_BUFFER_OVERFLOW_ERROR == s)
	{
          unichar	*output;

          s = 0;	// May have been set to a buffer overflow error

	  output = NSZoneMalloc(0, (outLength + 1) * sizeof(unichar));
	  uregex_replaceAll(r, replacement, replLength,
	    output, outLength + 1, &s);
	  if (0 == s)
	    {
	      NSString	*out;

	      out = [[NSString alloc] initWithCharactersNoCopy: output
							length: outLength
						  freeWhenDone: YES];
	      [string setString: out];
	      RELEASE(out);
	    }
	  else
	    {
	      NSZoneFree(0, output);
	      results = 0;
	    }
	}
      else
	{
	  results = 0;
	}
      uregex_close(r);
    }
  return results;
}

- (NSString*) stringByReplacingMatchesInString: (NSString*)string
                                       options: (NSMatchingOptions)opts
                                         range: (NSRange)range
                                  withTemplate: (NSString*)template
{
  UErrorCode	s = 0;
  uint32_t	length = [string length];
  URegularExpression *r;
  uint32_t	replLength = [template length];
  unichar	replacement[replLength];
  int32_t	outLength;
  NSString	*result = nil;
  TEMP_BUFFER(buffer, length);

  r = setupRegex(regex, string, buffer, length, opts, range, 0);
  [template getCharacters: replacement range: NSMakeRange(0, replLength)];

  outLength = uregex_replaceAll(r, replacement, replLength, NULL, 0, &s);
  if (0 == s || U_BUFFER_OVERFLOW_ERROR == s)
    {
      unichar	*output;

      s = 0;	// may have been set to a buffer overflow error

      output = NSZoneMalloc(0, (outLength + 1) * sizeof(unichar));
      uregex_replaceAll(r, replacement, replLength, output, outLength + 1, &s);
      if (0 == s)
	{
	  result = AUTORELEASE([[NSString alloc]
	    initWithCharactersNoCopy: output
	    length: outLength
	    freeWhenDone: YES]);
	}
      else
	{
	  NSZoneFree(0, output);
	}
    }

  uregex_close(r);
  return result;
}

- (NSString*) replacementStringForResult: (NSTextCheckingResult*)result
                                inString: (NSString*)string
                                  offset: (NSInteger)offset
                                template: (NSString*)template
{
  UErrorCode	s = 0;
  NSRange	range = [result range];
  URegularExpression *r;
  uint32_t	replLength = [template length];
  unichar	replacement[replLength];
  int32_t	outLength;
  NSString	*str = nil;
  TEMP_BUFFER(buffer, range.length);

  r = setupRegex(regex,
		 [string substringWithRange: range],
		 buffer,
		 range.length,
		 0,
		 NSMakeRange(0, range.length),
		 0);
  [template getCharacters: replacement range: NSMakeRange(0, replLength)];

  outLength = uregex_replaceFirst(r, replacement, replLength, NULL, 0, &s);
  if (0 == s || U_BUFFER_OVERFLOW_ERROR == s)
    {
      unichar	*output;

      s = 0;
      output = NSZoneMalloc(0, (outLength + 1) * sizeof(unichar));
      uregex_replaceFirst(r, replacement, replLength,
	output, outLength + 1, &s);
      if (0 == s)
	{
	  str = AUTORELEASE([[NSString alloc]
	    initWithCharactersNoCopy: output
	    length: outLength
	    freeWhenDone: YES]);
	}
      else
	{
	  NSZoneFree(0, output);
	}
    }
  uregex_close(r);
  return str;
}
#endif

+ (NSString*) escapedPatternForString: (NSString *)string
{
  /* https://unicode-org.github.io/icu/userguide/strings/regexp.html
   * Need to escape * ? + [ ( ) { } ^ $ | \ .
   */
  return [[NSRegularExpression 
    regularExpressionWithPattern: @"([*?+\\[(){}^$|\\\\.])" 
                         options: 0 
                           error: NULL]
    stringByReplacingMatchesInString: string
                             options: 0
                               range: NSMakeRange(0, [string length]) 
                        withTemplate: @"\\\\$1"
  ];
}

- (NSRegularExpressionOptions) options
{
  return options;
}

- (NSUInteger) numberOfCaptureGroups
{
  UErrorCode s = 0;
  return uregex_groupCount(regex, &s);
}

- (void) dealloc
{
  uregex_close(regex);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      [aCoder encodeInteger: options forKey: @"options"];
      [aCoder encodeObject: [self pattern] forKey: @"pattern"];
    }
  else
    {
      [aCoder encodeValueOfObjCType: @encode(NSRegularExpressionOptions)
				 at: &options];
      [aCoder encodeObject: [self pattern]];
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSString	*pattern;

  if ([aCoder allowsKeyedCoding])
    {
      options = [aCoder decodeIntegerForKey: @"options"];
      pattern = [aCoder decodeObjectForKey: @"pattern"];
    }
  else
    {
      [aCoder decodeValueOfObjCType: @encode(NSRegularExpressionOptions)
				 at: &options];
      pattern = [aCoder decodeObject];
    }
  return [self initWithPattern: pattern options: options error: NULL];
}

- (id) copyWithZone: (NSZone*)aZone
{
  NSRegularExpressionOptions	opts = options;
  UErrorCode			s = 0;
  URegularExpression		*r = uregex_clone(regex, &s);

  if (0 != s)
    {
      return nil;
    }

  self = [[self class] allocWithZone: aZone];
  if (nil == self)
    {
      return nil;
    }
  options = opts;
  regex = r;
  return self;
}
@end
#endif //GS_ICU == 1

#ifndef NSRegularExpressionWorks
#import "Foundation/NSRegularExpression.h"
#import "Foundation/NSZone.h"
#import "Foundation/NSException.h"
@implementation NSRegularExpression
+ (id)allocWithZone: (NSZone*)aZone
{
  [NSException raise: NSInvalidArgumentException
              format: @"NSRegularExpression requires ICU 4.4 or later"];
  return nil;
}
- (id) copyWithZone: (NSZone*)zone
{
  return nil;
}
- (void) encodeWithCoder: (NSCoder*)aCoder
{
}
- (id) initWithCoder: (NSCoder*)aCoder
{
  return nil;
}
@end
#endif
