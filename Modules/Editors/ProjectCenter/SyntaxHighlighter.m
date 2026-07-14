/*
    SyntaxHighlighter.m

    Implementation of the SyntaxHighlighter class for the
    ProjectManager application.

    Copyright (C) 2005  Saso Kiselkov

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#import "SyntaxHighlighter.h"

#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLock.h>

#import <AppKit/NSTextStorage.h>
#import <AppKit/NSAttributedString.h>

#import "PCEditorView.h"
#import "SyntaxDefinition.h"

static NSString * const KeywordsNotFixedAttributeName = @"KNF";
static NSString * const ContextAttributeName = @"C";

static inline BOOL
my_isspace(unichar c)
{
  if (c == ' ' || c == '\t' || c == '\f')
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

/**
 * This function looks ahead and after `startRange' in `string' and
 * tries to return the range of a whitespace delimited word at the
 * specified range. E.g. string = @"abc def ghi" and startRange = {5, 1},
 * then {4, 3} is returned, because the word "def" lies within the range.
 * Please note that even when the range points to a whitespace area
 * (e.g. string = @"abc def" and startRange = {3, 1}), the lookup
 * will occur and not return `not found' (e.g. in the above example it
 * would return {0, 7}). When the range is also surrounded by whitespace
 * (e.g. @"   " and startRange = {1, 1}) the startRange itself is returned.
 */
static NSRange
RangeOfWordInString(NSString * string, NSRange startRange)
{
  SEL sel = @selector(characterAtIndex:);
  unichar (*characterAtIndex)(id, SEL, unsigned int) = 
    (unichar (*)(id, SEL, unsigned int)) [string methodForSelector: sel];
  NSInteger ahead, after;
  NSUInteger length = [string length];

  for (ahead = 1; ahead <= (NSInteger) startRange.location; ahead++)
    {
      if (my_isspace(characterAtIndex(string,
                                      sel,
                                      startRange.location - ahead)))
        {
          break;
        }
    }
  ahead--;

  for (after = 0; (after + NSMaxRange(startRange)) < length; after++)
    {
      if (my_isspace(characterAtIndex(string,
                                      sel,
                                      (after + NSMaxRange(startRange)))))
        {
          break;
        }
    }

  {
    NSUInteger start = startRange.location - ahead;
    NSUInteger length = startRange.length + ahead + after;

    if (start > 0)
      {
        start--;
        length++;
      }
    if (length + 1 < length)
      {
        length++;
      }

    return NSMakeRange(start, length);
  }
}

@interface SyntaxHighlighter (Private)

- (void) fixUpContextsInRange: (NSRange) r;

- (void) fixUpKeywordsInRange: (NSRange) r;
- (void) lazilyFixUpKeywordsInRange: (NSRange) r;

- (void) assignGraphicalAttributesOfContext: (NSUInteger) context
                                    toRange: (NSRange) r;

- (void) assignGraphicalAttributesOfKeyword: (NSUInteger) keyword
                                  inContext: (NSUInteger) context
                                    toRange: (NSRange) r;

- (NSUInteger) contextBeforeRange: (NSRange) r;
- (NSUInteger) contextAfterRange: (NSRange) r;
- (NSUInteger) contextAtEndOfRange: (NSRange) r;

- (void) beginEditingIfNeeded;
- (void) endEditingIfNeeded;

@end

@implementation SyntaxHighlighter (Private)

/**
 * Fixes up the contexts inside the text storage in range `r'. A context
 * is recognized by the "Context" attribute which holds the number of
 * the context. This method also applies graphical attributes of the
 * corresponding contexts to the context ranges.
 */
- (void) fixUpContextsInRange: (NSRange) r
{
  TextPattern ** beginnings = [syntax contextBeginnings];
  const char * beginningChars = [syntax contextBeginningCharacters];
  unsigned numBeginningChars = [syntax numberOfContextBeginningCharacters];

  NSUInteger i;
  unichar * string;
  NSUInteger context;

  string = (unichar *) malloc(r.length * sizeof(unichar));
  [[textStorage string] getCharacters: string range: r];

  i = 0;
  context = [self contextBeforeRange: r];
  while (i < r.length)
    {
       // marks the beginning of the currently processed range
      unsigned int mark = i;

      // default context - look for beginning symbols
      if (context == 0)
        {
          NSUInteger j = 0;
          TextPattern * pattern = NULL;
          NSRange ctxtRange;
          NSInteger l = 0;
          TextPattern ** skips = [syntax contextSkipsForContext: 0];
          const char * skipChars = [syntax contextSkipCharactersForContext: 0];
          unsigned int numSkipChars = [syntax
            numberOfContextSkipCharactersForContext: 0];

          for (;i < r.length; i++)
            {
              unichar c = string[i];

              // Optimize - look into the skip characters array if the
              // character could be the beginning of a skip sequence.
              // If not, don't perform skip sequence recognition at all.
              if (c < numSkipChars && skipChars[c])
                {
                  for (j = 0; (pattern = skips[j]) != NULL; j++)
                    {
                      l = CheckTextPatternPresenceInString(pattern,
                                                           string,
                                                           r.length,
                                                           i);
                      if (l > 0)
                        {
                          break;
                        }
                    }

                  if (l > 0)
                    {
                      i += l - 1;
                      continue;
                    }
                }

              // optimize - skip unneeded characters
              if (c < numBeginningChars && !beginningChars[c])
                {
                  continue;
                }

              for (j = 0; (pattern = beginnings[j]) != NULL; j++)
                {
                  l = CheckTextPatternPresenceInString(pattern, string,
                                                       r.length, i);
                  if (l > 0)
                    {
                      break;
                    }
                }

              if (l > 0)
                {
                  break;
                }
            }

          // non-default contexts begin with number 1, not zero
          j++;

          ctxtRange = NSMakeRange(r.location + mark, i - mark);
          if (ctxtRange.length > 0)
            {
              // add an attribute telling the context into the text storage
              [textStorage addAttribute: ContextAttributeName
                                  value: [NSNumber numberWithInt: 0]
                                  range: ctxtRange];
              [self assignGraphicalAttributesOfContext: 0 toRange: ctxtRange];
            }

          ctxtRange = NSMakeRange(r.location + i, l);
          if (ctxtRange.length > 0)
            {
              [textStorage addAttribute: ContextAttributeName
                                  value: [NSNumber numberWithInt: j]
                                  range: ctxtRange];
              [self assignGraphicalAttributesOfContext: j
                                               toRange: ctxtRange];
            }
          i += l;

          // switch to the found context again
          context = j;
        }
      // specific context - look for it's terminator, but skip it's
      // exceptions
      else
        {
          NSInteger l = 0;
          TextPattern * ending = [syntax contextEndingForContext: context - 1];
          NSRange ctxtRange;
          TextPattern ** skips = [syntax contextSkipsForContext: context];
          const char * skipChars = [syntax contextSkipCharactersForContext:
            context];
          NSUInteger numSkipChars = [syntax
            numberOfContextSkipCharactersForContext: context];

          for (;i < r.length; i++)
            {
              unichar c = string[i];

              if (c < numSkipChars && skipChars[c])
                {
                  unsigned int j;
                  TextPattern * pattern;

                  for (j = 0; (pattern = skips[j]) != NULL; j++)
                    {
                      l = CheckTextPatternPresenceInString(pattern, string,
                                                           r.length, i);
                      if (l > 0)
                        {
                          break;
                        }
                    }

                  if (l > 0)
                    {
                      i += l - 1;
                      continue;
                    }
                }

              l = CheckTextPatternPresenceInString(ending, string,
                                                   r.length, i);
              if (l > 0)
                {
                  break;
                }
            }

          ctxtRange = NSMakeRange(r.location + mark, i - mark);
          if (ctxtRange.length > 0)
            {
              // add an attribute telling the context into the
              // text storage
              [textStorage addAttribute: ContextAttributeName
                                  value: [NSNumber numberWithInteger: context]
                                  range: ctxtRange];
              [self assignGraphicalAttributesOfContext: context
                                               toRange: ctxtRange];
            }

          ctxtRange = NSMakeRange(r.location + i, l);
          if (ctxtRange.length > 0)
            {
              [textStorage addAttribute: ContextAttributeName
                                  value: [NSNumber numberWithInteger: 0]
                                  range: ctxtRange];
              [self assignGraphicalAttributesOfContext: context
                                               toRange: ctxtRange];
            }
          i += l;

          // switch to the default context again
          context = 0;
        }
    }

  free(string);
}

- (void) fixUpKeywordsInRange: (NSRange) r
{
  unichar * string;
  NSUInteger i;

  string = malloc(r.length * sizeof(unichar));
  [[textStorage string] getCharacters: string range: r];

  for (i = 0; i < r.length;)
    {
      NSRange contextRange;
      TextPattern ** patterns;
      NSInteger context;

      context = [[textStorage attribute: ContextAttributeName
                                atIndex: i + r.location
                         effectiveRange: &contextRange] integerValue];

      contextRange = NSIntersectionRange(r, contextRange);
      contextRange.location -= r.location;

      patterns = [syntax keywordsInContext: context];

      while (i < NSMaxRange(contextRange))
        {
          unichar c = string[i];
          NSUInteger l = 0;
          NSUInteger j;
          TextPattern * pattern;

          // skip whitespace - it can't start a keyword
          if (my_isspace(c) || c == '\r' || c == '\n')
            {
              i++;
              continue;
            }

          for (j = 0; (pattern = patterns[j]) != NULL; j++)
            {
              l = CheckTextPatternPresenceInString(pattern,
                                                   string,
                                                   r.length,
                                                   i);
              if (l > 0)
                {
                  break;
                }
            }

          // found a pattern?
          if (pattern != NULL)
            {
              NSRange keywordRange = NSMakeRange(i + r.location, l);

              [self assignGraphicalAttributesOfKeyword: j
                                             inContext: context
                                               toRange: keywordRange];
              i += l;
            }
          else
            {
              i++;
            }
        }
    }

  free(string);
}

- (void) lazilyFixUpKeywordsInRange: (NSRange) r
{
  NSUInteger i;
  BOOL localDidBeginEditing = NO;

  for (i = r.location; i < NSMaxRange(r);)
    {
      NSRange effectiveRange;

      // locate non-fixed areas and fix them up
      if ([textStorage attribute: KeywordsNotFixedAttributeName
                         atIndex: i
           longestEffectiveRange: &effectiveRange
                         inRange: r] != nil)
        {
          if (localDidBeginEditing == NO)
            {
              localDidBeginEditing = YES;
              [textStorage beginEditing];
            }
          effectiveRange = NSIntersectionRange(effectiveRange, r);
          [self fixUpKeywordsInRange: effectiveRange];
          [textStorage removeAttribute: KeywordsNotFixedAttributeName
                                 range: effectiveRange];
          i += effectiveRange.length;
        }

      // skip over fixed areas
      else
        {
          i += effectiveRange.length;
        }
    }

  if (localDidBeginEditing == YES)
    {
      [textStorage endEditing];
    }
}

- (void) assignGraphicalAttributesOfContext: (NSUInteger) ctxt
                                    toRange: (NSRange) r
{
  BOOL bold, italic;
  NSColor * color;

  color = [syntax foregroundColorForContext: ctxt];
  if (color != nil)
    {
      [textStorage addAttribute: NSForegroundColorAttributeName
                          value: color
                          range: r];
    }
  else
    {
      [textStorage removeAttribute: NSForegroundColorAttributeName range: r];
    }

  color = [syntax backgroundColorForContext: ctxt];
  if (color != nil)
    {
      [textStorage addAttribute: NSBackgroundColorAttributeName
                          value: color
                          range: r];
    }
  else
    {
      [textStorage removeAttribute: NSBackgroundColorAttributeName range: r];
    }

  bold = [syntax isBoldFontForContext: ctxt];
  italic = [syntax isItalicFontForContext: ctxt];
  if (bold && italic)
    {
      [textStorage addAttribute: NSFontAttributeName
                          value: boldItalicFont
                          range: r];
    }
  else if (bold)
    {
      [textStorage addAttribute: NSFontAttributeName
                          value: boldFont
                          range: r];
    }
  else if (italic)
    {
      [textStorage addAttribute: NSFontAttributeName
                          value: italicFont
                          range: r];
    }
  else
    {
      [textStorage addAttribute: NSFontAttributeName
                          value: normalFont
                          range: r];
    }
}

- (void) assignGraphicalAttributesOfKeyword: (NSUInteger) keyword
                                  inContext: (NSUInteger) context
                                    toRange: (NSRange) r
{
  BOOL bold, italic;
  NSColor * color;

  color = [syntax foregroundColorForKeyword: keyword inContext: context];
  if (color != nil)
    {
      [textStorage addAttribute: NSForegroundColorAttributeName
                          value: color
                          range: r];
    }
  else
    {
      color = [syntax foregroundColorForContext: context];

      if (color != nil)
        {
          [textStorage addAttribute: NSForegroundColorAttributeName
                              value: color
                              range: r];
        }
      else
        {
          [textStorage removeAttribute: NSForegroundColorAttributeName
                                 range: r];
        }
    }

  color = [syntax backgroundColorForKeyword: keyword inContext: context];
  if (color != nil)
    {
      [textStorage addAttribute: NSBackgroundColorAttributeName
                          value: color
                          range: r];
    }
  else
    {
      color = [syntax backgroundColorForContext: context];

      if (color != nil)
        {
          [textStorage addAttribute: NSBackgroundColorAttributeName
                              value: color
                              range: r];
        }
      else
        {
          [textStorage removeAttribute: NSBackgroundColorAttributeName
                                 range: r];
        }
    }

  bold = [syntax isBoldFontForKeyword: keyword inContext: context];
  italic = [syntax isItalicFontForKeyword: keyword inContext: context];
  if (bold && italic)
    {
      [textStorage addAttribute: NSFontAttributeName
                          value: boldItalicFont
                          range: r];
    }
  else if (bold)
    {
      [textStorage addAttribute: NSFontAttributeName
                          value: boldFont
                          range: r];
    }
  else if (italic)
    {
      [textStorage addAttribute: NSFontAttributeName
                          value: italicFont
                          range: r];
    }
  else
    {
      [textStorage addAttribute: NSFontAttributeName
                          value: normalFont
                          range: r];
    }
}

- (NSUInteger) contextBeforeRange: (NSRange) r
{
  NSRange tmp;

  if (r.location == 0)
    {
      return 0;
    }
  else
    {
      return [[textStorage attribute: ContextAttributeName
                             atIndex: r.location - 1
                      effectiveRange: &tmp] intValue];
    }
}

- (NSUInteger) contextAfterRange: (NSRange) r
{
  NSRange tmp;
  NSUInteger i;
  NSUInteger length;

  i = NSMaxRange(r);
  length = [textStorage length];

  if (length == 0)
    {
      return 0;
    }
  else if (i < length)
    {
      return [[textStorage attribute: ContextAttributeName
                             atIndex: i
                      effectiveRange: &tmp] intValue];
    }
  else
    {
      return 0;
    }
}

- (NSUInteger) contextAtEndOfRange: (NSRange) r
{
  NSRange tmp;
  NSInteger i = (int) NSMaxRange(r) - 1;

  if (i < 0)
    {
      return 0;
    }
  else
    {
      return [[textStorage attribute: ContextAttributeName
                             atIndex: i
                      effectiveRange: &tmp] integerValue];
    }
}

- (void) beginEditingIfNeeded
{
  if (didBeginEditing == NO)
    {
      didBeginEditing = YES;
      [textStorage beginEditing];
    }
}

- (void) endEditingIfNeeded
{
  if (didBeginEditing == YES)
    {
      didBeginEditing = NO;
      [textStorage endEditing];
    }
}

@end

@implementation SyntaxHighlighter

- initWithFileType:(NSString *)fileType
       textStorage:(NSTextStorage *)aStorage
{
  if ([self init])
    {
      NSRange r;

      ASSIGN(textStorage, aStorage);
      ASSIGN(syntax, [SyntaxDefinition
        syntaxDefinitionForFileType:fileType textStorage:textStorage]);

      // no syntax definition - no highlighting possible
      if (syntax == nil)
        {
          [self release];
          return nil;
        }

      // mark all of the text storage as requiring keyword fixing
      r = NSMakeRange(0, [textStorage length]);
      [textStorage addAttribute: KeywordsNotFixedAttributeName
                          value: [NSNull null]
                          range: r];

      [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector(textStorageWillProcessEditing:)
               name: NSTextStorageWillProcessEditingNotification
             object: textStorage];

      ASSIGN(normalFont, [PCEditorView defaultEditorFont]);
      ASSIGN(boldFont, [PCEditorView defaultEditorBoldFont]);
      ASSIGN(italicFont, [PCEditorView defaultEditorItalicFont]);
      ASSIGN(boldItalicFont, [PCEditorView defaultEditorBoldItalicFont]);

      return self;
    }
  else
    {
      return nil;
    }
}

- (void)setNormalFont:(NSFont *)f
{
  ASSIGN(normalFont, f);
}

- (void)setBoldFont:(NSFont *)f
{
  ASSIGN(boldFont, f);
}

- (void)setItalicFont:(NSFont *)f
{
  ASSIGN(italicFont, f);
}

- (void)setBoldItalicFont:(NSFont *)f
{
  ASSIGN(boldItalicFont, f);
}


- (void) dealloc
{
  NSDebugLLog(@"SyntaxHighlighter", @"SyntaxHighlighter: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver: self];

  TEST_RELEASE(textStorage);
  TEST_RELEASE(syntax);
  TEST_RELEASE(normalFont);
  TEST_RELEASE(boldFont);
  TEST_RELEASE(italicFont);
  TEST_RELEASE(boldItalicFont);

  [super dealloc];
}

- (void) highlightRange: (NSRange) r
{
  if (delayedProcessedRange.length > 0)
    {
      [self beginEditingIfNeeded];
      [self fixUpContextsInRange: delayedProcessedRange];
      [self fixUpKeywordsInRange: delayedProcessedRange];

      if ([self contextAtEndOfRange: delayedProcessedRange] !=
          [self contextAfterRange: delayedProcessedRange])
        {
          NSRange invalidatedRange;

          lastProcessedContextIndex = NSMaxRange(delayedProcessedRange);

          invalidatedRange = NSMakeRange(NSMaxRange(delayedProcessedRange),
            [textStorage length] - NSMaxRange(delayedProcessedRange));
          [textStorage addAttribute: KeywordsNotFixedAttributeName
                              value: [NSNull null]
                              range: invalidatedRange];
        }
    }
  else
    {
      if (delayedProcessedRange.location > 0 &&
        [self contextBeforeRange: delayedProcessedRange] !=
        [self contextAfterRange: delayedProcessedRange])
        {
          NSRange invalidatedRange;

          lastProcessedContextIndex = NSMaxRange(delayedProcessedRange);

          [self beginEditingIfNeeded];

          invalidatedRange = NSMakeRange(NSMaxRange(delayedProcessedRange),
            [textStorage length] - NSMaxRange(delayedProcessedRange));
          [textStorage addAttribute: KeywordsNotFixedAttributeName
                              value: [NSNull null]
                              range: invalidatedRange];
        }
    }

  delayedProcessedRange = NSMakeRange(0, 0);

  r = RangeOfWordInString([textStorage string], r);

  // need to fixup contexts?
  if (NSMaxRange(r) > lastProcessedContextIndex)
    {
      NSRange fixupRange;

      fixupRange = NSMakeRange(lastProcessedContextIndex,
                               NSMaxRange(r) - lastProcessedContextIndex);

      [self beginEditingIfNeeded];
      [self fixUpContextsInRange: fixupRange];

      lastProcessedContextIndex = NSMaxRange(r);
    }

  [self lazilyFixUpKeywordsInRange: r];

  [self endEditingIfNeeded];
}

- (void) textStorageWillProcessEditing: (NSNotification *) notif
{
  if ([textStorage editedMask] & NSTextStorageEditedCharacters)
    {
      NSRange editedRange = [textStorage editedRange];

      delayedProcessedRange = RangeOfWordInString([textStorage string],
                                                  editedRange);

      if (lastProcessedContextIndex > editedRange.location)
        {
          lastProcessedContextIndex += [textStorage changeInLength];
        }
    }
}

@end
