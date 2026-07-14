/*
    SyntaxDefinition.h

    Implementation of the SyntaxDefinition class for the
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

#import "SyntaxDefinition.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSScanner.h>

#import <AppKit/NSColor.h>
#import <AppKit/NSTextStorage.h>

NSDictionary * ParseSyntaxGraphics(NSDictionary * specification)
{
  NSMutableDictionary * dict = [NSMutableDictionary dictionary];
  NSString * value;

  value = [specification objectForKey: @"ForegroundColor"];
  if (value != nil)
    {
      float r, g, b, a;
      NSScanner * scanner = [NSScanner scannerWithString: value];

      if ([scanner scanFloat: &r] && [scanner scanFloat: &g] &&
          [scanner scanFloat: &b])
        {
          if ([scanner scanFloat: &a] == NO)
            {
              a = 1.0;
            }

          [dict setObject: [NSColor colorWithCalibratedRed: r
                                                     green: g
                                                      blue: b
                                                     alpha: a]
                   forKey: @"ForegroundColor"];
        }
      else
        {
          NSLog(_(@"Invalid ForegroundColor specification \"%@\" found: "
                  @"the correct format is \"r g b [a]\" where each component"
                  @"is a real number in the range of 0.0 thru 1.0 inclusive, "
                  @"specifying the red, green, blue and alpha (optional) "
                  @"components of the desired color."), value);
        }
    }

  value = [specification objectForKey: @"BackgroundColor"];
  if (value != nil)
    {
      float r, g, b, a;
      NSScanner * scanner = [NSScanner scannerWithString: value];

      if ([scanner scanFloat: &r] && [scanner scanFloat: &g] &&
          [scanner scanFloat: &b])
        {
          if ([scanner scanFloat: &a] == NO)
            {
              a = 1.0;
            }

          [dict setObject: [NSColor colorWithCalibratedRed: r
                                                     green: g
                                                      blue: b
                                                     alpha: a]
                   forKey: @"BackgroundColor"];
        }
      else
        {
          NSLog(_(@"Invalid BackgroundColor specification \"%@\" found: "
                  @"the correct format is \"r g b [a]\" where each component"
                  @"is a real number in the range of 0.0 thru 1.0 inclusive, "
                  @"specifying the red, green, blue and alpha (optional) "
                  @"components of the desired color."), value);
        }
    }

  value = [specification objectForKey: @"Bold"];
  if (value != nil)
    {
      [dict setObject: [NSNumber numberWithBool: [value boolValue]]
               forKey: @"Bold"];
    }

  value = [specification objectForKey: @"Italic"];
  if (value != nil)
    {
      [dict setObject: [NSNumber numberWithBool: [value boolValue]]
               forKey: @"Italic"];
    }

  return [[dict copy] autorelease];
}

void
MarkTextPatternBeginningCharacters(TextPattern * pattern,
                                   char * buffer, unsigned int bufSize)
{
  unichar * chars = PermissibleCharactersAtPatternBeginning(pattern);

  if (chars == (unichar *) -1)
    {
      memset(buffer, 1, 128);
    }
  else if (chars != NULL)
    {
      unsigned int i;
      unichar c;

      for (i = 0; (c = chars[i]) != 0; i++)
        {
          if (c < bufSize)
            {
              buffer[c] = 1;
            }
        }

      free(chars);
    }
}

static NSDictionary * syntaxes = nil;
static NSMutableDictionary * syntaxDefinitions = nil;

@interface SyntaxDefinition (Private)

+ (void)loadSyntaxDefinitions;

@end

@implementation SyntaxDefinition (Private)

/**
 * Loads all syntax definition files and associates them in the
 * static global variable `syntaxes' with their respective
 * file types. The syntax definitions aren't compiled yet - they
 * are left in their pure format and are compiled on a per-use
 * basis.
 */
+ (void)loadSyntaxDefinitions
{
  NSMutableDictionary *dict;
  NSArray             *filePaths;
  NSString            *filePath;
  NSEnumerator        *e;
  NSBundle            *bundle;

  // FIXME: need better algorithm to locate syntax files. This is good
  // only for a quick'n'dirty implementation
  bundle = [NSBundle bundleForClass:NSClassFromString(@"PCEditor")];
  filePaths = [bundle pathsForResourcesOfType:@"syntax" inDirectory:nil];

  dict = [NSMutableDictionary dictionary];
  e = [filePaths objectEnumerator];
  while ((filePath = [e nextObject]) != nil)
    {
      NSDictionary * syntax;


      syntax = [NSDictionary dictionaryWithContentsOfFile: filePath];
      if (syntax != nil)
        {
          NSEnumerator * ee = [[syntax objectForKey: @"FileTypes"]
            objectEnumerator];
          NSString * fileType;

          while ((fileType = [ee nextObject]) != nil)
            {
              [dict setObject: [syntax objectForKey: @"Contexts"]
                       forKey: fileType];
            }
        }
    }

  ASSIGNCOPY(syntaxes, dict);
}

@end

@implementation SyntaxDefinition

+ (void)initialize
{
  if (syntaxes == nil)
    {
      [self loadSyntaxDefinitions];
      syntaxDefinitions = [NSMutableDictionary new];
    }
}

+ syntaxDefinitionForFileType:(NSString *)fileType
                  textStorage:(NSTextStorage *)aTextStorage
{
  SyntaxDefinition * def;

  def = [syntaxDefinitions objectForKey: fileType];
  if (def == nil)
    {
      NSArray * contexts = [syntaxes objectForKey: fileType];

      if (contexts != nil)
        {
          def = [[[SyntaxDefinition alloc]
            initWithContextList: contexts
                    textStorage: aTextStorage]
            autorelease];

          if (def != nil)
            {
              [syntaxDefinitions setObject: def forKey: fileType];
            }

          return def;
        }
      else
        {
          return nil;
        }
    }
  else
    {
      return def;
    }
}

- initWithContextList:(NSArray *)contexts
          textStorage:(NSTextStorage *)aTextStorage
{
  if ([self init])
    {
      NSUInteger i, n;
      NSMutableArray * contextGraphicsTmp = [NSMutableArray array],
                     * keywordGraphicsTmp = [NSMutableArray array];

      ASSIGN(textStorage, aTextStorage);

      // compile the syntax definition
      for (i = 0, n = [contexts count]; i < n; i++)
        {
          NSUInteger j, keywordCount, skipCount;
          NSDictionary * context = [contexts objectAtIndex: i];
          NSArray * ctxtKeywords, * skips;
          NSMutableArray * contextKeywordsGraphicsTmp;

          // context beginning/ending missing?
          if (([context objectForKey: @"Beginning"] == nil ||
               [context objectForKey: @"Ending"] == nil) &&
              i > 0)
            {
              NSLog(@"Syntax compilation error: context %" PRIuPTR "  missing "
                      @"beginning or ending symbol.", i);

              [self release];
              return nil;
            }

          // process context beginnings/endings
          if (i > 0)
            {
              contextBeginnings = realloc(contextBeginnings, i *
                sizeof(TextPattern *));
              contextBeginnings[i - 1] = CompileTextPattern([context
                objectForKey: @"Beginning"]);

              MarkTextPatternBeginningCharacters(contextBeginnings[i - 1],
                contextBeginningChars, sizeof(contextBeginningChars));

              contextEndings = realloc(contextEndings, i *
                sizeof(TextPattern *));
              contextEndings[i - 1] = CompileTextPattern([context
                objectForKey: @"Ending"]);
            }

          // process context skips
          contextSkipChars = realloc(contextSkipChars, (i + 1) *
            sizeof(char *));
          contextSkipChars[i] = calloc(128, sizeof(char));
          contextSkips = realloc(contextSkips, sizeof(TextPattern **) *
            (i + 1));
          contextSkips[i] = NULL;
          skips = [context objectForKey: @"ContextSkips"];
          for (j = 0, skipCount = [skips count]; j < skipCount; j++)
            {
              NSString * skip = [skips objectAtIndex: j];

              contextSkips[i] = realloc(contextSkips[i], (j + 1) *
                sizeof(TextPattern *));
              contextSkips[i][j] = CompileTextPattern(skip);
              MarkTextPatternBeginningCharacters(contextSkips[i][j],
                contextSkipChars[i], 128);
            }
          contextSkips[i] = realloc(contextSkips[i], (j + 1) *
            sizeof(TextPattern *));
          contextSkips[i][j] = NULL;

          // process context graphics
          [contextGraphicsTmp addObject: ParseSyntaxGraphics(context)];

          keywords = realloc(keywords, (i + 1) * sizeof(TextPattern **));
          keywords[i] = NULL;

          ctxtKeywords = [context objectForKey: @"Keywords"];
          contextKeywordsGraphicsTmp = [NSMutableArray arrayWithCapacity:
            [ctxtKeywords count]];

          // run through all keywords in the context
          for (j = 0, keywordCount = [ctxtKeywords count];
               j < keywordCount;
               j++)
            {
              NSDictionary * keyword = [ctxtKeywords objectAtIndex: j];
              NSString * keywordString = [keyword objectForKey: @"Pattern"];
              TextPattern * pattern;

              if (keywordString == nil)
                {
                  NSLog(_(@"Missing keyword pattern declaration "
                          @"in context %i keyword %i. Ignoring all the "
                          @"remaining of the keywords in this context."),
			  (int)i, (int)j);
                  break;
                }
              pattern = CompileTextPattern(keywordString);
              if (pattern == NULL)
                {
                  break;
                }

              keywords[i] = realloc(keywords[i],
                                    (j + 1) * sizeof(TextPattern *));
              keywords[i][j] = pattern;

              [contextKeywordsGraphicsTmp addObject:
                ParseSyntaxGraphics(keyword)];
            }

          // append a trailing NULL to terminate the list
          keywords[i] = realloc(keywords[i], (j + 1) * sizeof(TextPattern *));
          keywords[i][j] = NULL;

          [keywordGraphicsTmp addObject: [[contextKeywordsGraphicsTmp
            copy] autorelease]];
        }

      // terminate the keywords array by appending a trailing NULL pointer
      keywords = realloc(keywords, (i + 1) * sizeof(TextPattern **));
      keywords[i] = NULL;

      // begining and ending arrays don't include the default context!
      // Thus it is indexed by 'i' not 'i + 1'
      contextBeginnings = realloc(contextBeginnings, i *
        sizeof(TextPattern **));
      contextBeginnings[i - 1] = NULL;
      contextEndings = realloc(contextEndings, i * sizeof(TextPattern **));
      contextEndings[i - 1] = NULL;

      contextSkipChars = realloc(contextSkipChars, (i + 1) * sizeof(char *));
      contextSkipChars[i] = NULL;

      ASSIGNCOPY(contextGraphics, contextGraphicsTmp);
      ASSIGNCOPY(keywordGraphics, keywordGraphicsTmp);

      return self;
    }
  else
    {
      return nil;
    }
}

- (void) dealloc
{
  TextPattern * pattern;
  unsigned int i;
  TextPattern ** patternList;
  char * buf;

  // free context beginnings
  for (i = 0; (pattern = contextBeginnings[i]) != NULL; i++)
    {
      FreeTextPattern(pattern);
    }
  free(contextBeginnings);

  // free context endings
  for (i = 0; (pattern = contextEndings[i]) != NULL; i++)
    {
      FreeTextPattern(pattern);
    }
  free(contextEndings);

  // free context skip characters
  for (i = 0; (buf = contextSkipChars[i]) != NULL; i++)
    {
      free(buf);
    }
  free(contextSkipChars);

  // free context skips
  for (i = 0; (patternList = contextSkips[i]) != NULL; i++)
    {
      unsigned int j;

      for (j = 0; (pattern = patternList[j]) != NULL; j++)
        {
          FreeTextPattern(pattern);
        }
      free(patternList);
    }
  free(contextSkips);

  // free keywords
  for (i = 0; (patternList = keywords[i]) != NULL; i++)
    {
      unsigned int j;

      for (j = 0; (pattern = patternList[j]) != NULL; j++)
        {
          FreeTextPattern(pattern);
        }

      free(patternList);
    }
  free(keywords);

  TEST_RELEASE(textStorage);
  TEST_RELEASE(contextGraphics);
  TEST_RELEASE(keywordGraphics);

  [super dealloc];
}

/**
 * Returns a NULL pointer terminated list of context beginning symbols.
 */
- (TextPattern **)contextBeginnings
{
  return contextBeginnings;
}

- (const char *)contextBeginningCharacters
{
  return contextBeginningChars;
}

- (unsigned int)numberOfContextBeginningCharacters
{
  return sizeof(contextBeginningChars);
}

- (const char *)contextSkipCharactersForContext:(NSUInteger)ctxt
{
  return contextSkipChars[ctxt];
}

- (unsigned int)numberOfContextSkipCharactersForContext:(NSUInteger)ctxt
{
  return 128;
}

/**
 * Returns the context ending symbol for the context identified by `ctxt'.
 */
- (TextPattern *)contextEndingForContext:(NSUInteger)ctxt
{
  return contextEndings[ctxt];
}

- (TextPattern **)contextSkipsForContext:(NSUInteger)ctxt
{
  return contextSkips[ctxt];
}

- (NSColor *)foregroundColorForContext:(NSUInteger)context
{
  return [[contextGraphics
    objectAtIndex: context]
    objectForKey: @"ForegroundColor"];
}

- (NSColor *)backgroundColorForContext:(NSUInteger)context
{
  return [[contextGraphics
    objectAtIndex: context]
    objectForKey: @"BackgroundColor"];
}

- (BOOL)isItalicFontForContext:(NSUInteger)context
{
  return [[[contextGraphics
    objectAtIndex: context]
    objectForKey: @"Italic"]
    boolValue];
}

- (BOOL)isBoldFontForContext:(NSUInteger)context
{
  return [[[contextGraphics
    objectAtIndex: context]
    objectForKey: @"Bold"]
    boolValue];
}

/**
 * Returns a NULL pointer terminated list of text patterns representing
 * keywords to be matched inside context `context'.
 */
- (TextPattern **)keywordsInContext:(NSUInteger)context
{
  return keywords[context];
}

/**
 * Returns the color with which the keyword identified by `keyword'
 * in `contextName' should be colored. The argument `keyword' is the
 * index of the keyword in the array returned by -keywordsInContext:.
 */
- (NSColor *)foregroundColorForKeyword:(NSUInteger)keyword
			     inContext:(NSUInteger)context
{
  return [[[keywordGraphics objectAtIndex:context]
			    objectAtIndex:keyword]
			     objectForKey:@"ForegroundColor"];
}

- (NSColor *)backgroundColorForKeyword:(NSUInteger)keyword
			     inContext:(NSUInteger)context
{
  return [[[keywordGraphics objectAtIndex:context]
			    objectAtIndex:keyword]
			     objectForKey:@"BackgroundColor"];
}
- (BOOL)isItalicFontForKeyword:(NSUInteger)keyword
		     inContext:(NSUInteger)context
{
  return [[[[keywordGraphics objectAtIndex:context]
			     objectAtIndex:keyword]
			      objectForKey:@"Italic"]
			      boolValue];
}

/**
 * Returns YES if the font with which the keyword identified by `keyword'
 * should be bold and NO if it should be normal weigth.
 */
- (BOOL)isBoldFontForKeyword:(NSUInteger)keyword
       		   inContext:(NSUInteger)context
{
  return [[[[keywordGraphics objectAtIndex:context]
			     objectAtIndex:keyword]
			      objectForKey:@"Bold"]
			      boolValue];
}

@end
