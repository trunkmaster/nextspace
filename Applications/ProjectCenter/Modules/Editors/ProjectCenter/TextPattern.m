/*
    TextPattern.m

    Implementation of operations on text patterns for the
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

#import "TextPattern.h"

#import <Foundation/NSBundle.h>
#import <Foundation/NSScanner.h>
#import <Foundation/NSException.h>

static void
FreeTextPatternItem (TextPatternItem *item)
{
  if (item->type == MultipleCharactersTextPatternItem)
    {
      free (item->data.multiChar.characters);
    }

  free (item);
}

static TextPatternItem *
ParseTextPatternItem (NSString *string, unsigned int *index)
{
  unsigned int i = *index, n = [string length];
  TextPatternItem * newItem;
  unichar c;

  newItem = (TextPatternItem *) calloc(1, sizeof (TextPatternItem));

  c = [string characterAtIndex: i];
  i++;
  switch (c)
    {
      case '[':
        {
          unichar * buf = NULL;
          unsigned int nChars = 0;

          for (; i < n; i++)
            {
              unichar c = [string characterAtIndex: i];

              // handle escapes
              if (c == '\\')
                {
                  if (i + 1 >= n)
                    {
                      NSLog(_(@"Text pattern item parse error in text "
                        @"pattern \"%@\" at index %i: unexpected end of "
			      @"pattern. Escape sequence expected."), string, i);

                      free (buf);
                      free (newItem);

                      return NULL;
                    }

                  i++;
                  c = [string characterAtIndex: i];
                }
              else if (c == ']')
                {
                  i++;
                  break;
                }

              nChars++;
              buf = (unichar *) realloc(buf, sizeof (unichar) * nChars);
              buf[nChars - 1] = c;
            }

          if (i == n)
            {
              NSLog(_(@"Text pattern item parse error in text pattern "
                @"\"%@\" at index %i: unexpected end of character class."),
                string, i);

              free (buf);
              free (newItem);

              return NULL;
            }

          newItem->type = MultipleCharactersTextPatternItem;
          newItem->data.multiChar.nCharacters = nChars;
          newItem->data.multiChar.characters = buf;
        }
        break;
      case '.':
        newItem->type = AnyCharacterTextPatternItem;
        break;
      case '<':
        newItem->type = BeginningOfWordTextPatternItem;
        break;
      case '>':
        newItem->type = EndingOfWordTextPatternItem;
        break;
      case '^':
        newItem->type = BeginningOfLineTextPatternItem;
        break;
      case '$':
        newItem->type = EndingOfLineTextPatternItem;
        break;
      case '\\':
        if (i >= n)
          {
            NSLog(_(@"Text pattern item parse error in text pattern "
              @"\"%@\" at index %i: unexpected end of pattern. Escape "
		    @"sequence expected."), string, i);

            free (newItem);
            return NULL;
          }
        c = [string characterAtIndex: i];
        i++;

      default:
        newItem->type = SingleCharacterTextPatternItem;
        newItem->data.singleChar = c;
        break;
    }

  // is there trailing cardinality indication?
  if (i < n)
    {
      c = [string characterAtIndex: i];
      i++;

      switch (c)
        {
          case '{':
            {
              NSScanner * scanner;
              int value;

              if (newItem->type != SingleCharacterTextPatternItem &&
                  newItem->type != MultipleCharactersTextPatternItem &&
                  newItem->type != AnyCharacterTextPatternItem)
                {
                  NSLog(_(@"Text pattern item parse error in text pattern "
                    @"\"%@\" at index %i: no cardinality indication in "
                    @"'<', '>', '^' or '$' allowed."), string, i);

                  FreeTextPatternItem(newItem);

                  return NULL;
                }

              scanner = [NSScanner scannerWithString: string];

              [scanner setScanLocation: i];
              if (![scanner scanInt: &value])
                {
                  NSLog(_(@"Text pattern item parse error in text pattern "
                    @"\"%@\" at index %li: integer expected."), string,
			(long int)[scanner scanLocation]);

                  FreeTextPatternItem(newItem);

                  return NULL;
                }
              newItem->minCount = newItem->maxCount = value;
              i = [scanner scanLocation];
              if (i + 1 >= n)
                {
                  NSLog(_(@"Text pattern item parse error in text pattern "
                    @"\"%@\": unexpected end of pattern, '}' or ',' "
                    @"expected."), string);

                  FreeTextPatternItem(newItem);

                  return NULL;
                }
              c = [string characterAtIndex: i];
              if (c == ',')
                {
                  [scanner setScanLocation: i + 1];
                  if (![scanner scanInt: &value])
                    {
                      NSLog(_(@"Text pattern item parser error in text "
                        @"pattern \"%@\" at index %li: integer expected."),
			    string, (long int)[scanner scanLocation]);
    
                      FreeTextPatternItem(newItem);

                      return NULL;
                    }
                  newItem->maxCount = value;
                  i = [scanner scanLocation];
                }
              if (i >= n)
                {
                  NSLog(_(@"Text pattern item parse error in text pattern "
                    @"\"%@\": unexpected end of pattern, '}' expected."),
                    string);

                  FreeTextPatternItem(newItem);

                  return NULL;
                }
              c = [string characterAtIndex: i];
              i++;
              if (c != '}')
                {
                  NSLog(_(@"Text pattern item parse error in text pattern "
                    @"\"%@\" at index %i: '}' expected."), string, i);

                  FreeTextPatternItem(newItem);

                  return NULL;
                }
            }
            break;
          // no cardinality indication - the next character is part of
          // the next text pattern
          case '*':
            newItem->minCount = 0;
            newItem->maxCount = 0x7fffffff;
            break;
          case '?':
            newItem->minCount = 0;
            newItem->maxCount = 1;
            break;
          default:
            i--;
            newItem->minCount = newItem->maxCount = 1;
            break;
        }
    }
  else
    {
      newItem->minCount = newItem->maxCount = 1;
    }

  *index = i;

  return newItem;
}

#if 0
// not used
static void
DescribeTextPatternItem(TextPatternItem *item)
{
  switch (item->type)
    {
    case SingleCharacterTextPatternItem:
      NSLog(@"  type: single char, value: '%c', min: %i, max: %i",
        item->data.singleChar,
        item->minCount,
        item->maxCount);
      break;
    case MultipleCharactersTextPatternItem:
      NSLog(@"  type: multi char, value: '%@', min: %i, max: %i",
        [NSString stringWithCharacters: item->data.multiChar.characters
                                length: item->data.multiChar.nCharacters],
        item->minCount, item->maxCount);
      break;
    case BeginningOfWordTextPatternItem:
      NSLog(@"  type: beginning of word");
      break;
    case EndingOfWordTextPatternItem:
      NSLog(@"  type: ending of word");
      break;
    case AnyCharacterTextPatternItem:
      NSLog(@"  type: any character, min: %i, max: %i",
        item->minCount, item->maxCount);
      break;
    case BeginningOfLineTextPatternItem:
      NSLog(@"  type: beginning of line");
      break;
    case EndingOfLineTextPatternItem:
      NSLog(@"  type: ending of line");
      break;
    }
}
#endif

TextPattern *
CompileTextPattern (NSString *string)
{
  TextPattern * pattern;
  unsigned int i, n;

  pattern = (TextPattern *) calloc(1, sizeof(TextPattern));

  ASSIGN(pattern->string, string);

  for (i = 0, n = [string length]; i < n;)
    {
      TextPatternItem * item;

      item = ParseTextPatternItem(string, &i);
      if (item == NULL)
        {
          FreeTextPattern (pattern);

          return NULL;
        }

       // enlarge the pattern buffer
      pattern->nItems++;
      pattern->items = (TextPatternItem **) realloc(pattern->items,
        pattern->nItems * sizeof(TextPatternItem *));
      pattern->items[pattern->nItems - 1] = item;
    }

  return pattern;
}

void
FreeTextPattern (TextPattern *pattern)
{
  unsigned int i;

  for (i = 0; i < pattern->nItems; i++)
    {
      FreeTextPatternItem(pattern->items[i]);
    }

  free(pattern->items);

  TEST_RELEASE(pattern->string);

  free(pattern);
}

static inline BOOL
IsMemberOfCharacterClass(unichar c, unichar *charClass, unsigned int n)
{
  unsigned int i;

  for (i = 0; i < n; i++)
    {
      if (charClass[i] == c)
        {
          return YES;
        }
    }

  return NO;
}

/**
 * Returns YES if the passed character argument is an alphanumeric
 * character, and NO if it isn't.
 */
static inline BOOL
my_isalnum (unichar c)
{
  if ((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9'))
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

static inline BOOL
CheckTextPatternItemPresence(TextPatternItem *item,
                             unichar *string,
                             unsigned int stringLength,
                             unsigned int *offset)
{
  switch (item->type)
    {
    case SingleCharacterTextPatternItem:
      {
        unsigned int i;
        unsigned int n;

         // read characters while they are equal to our letter
        for (n = 0, i = *offset;
             i < stringLength && n < item->maxCount;
             i++, n++)
          {
            if (string[i] != item->data.singleChar)
              {
                break;
              }
          }

        if (n >= item->minCount)
          {
            *offset = i;
            return YES;
          }
        else
          {
            return NO;
          }
      }
      break;
    case MultipleCharactersTextPatternItem:
      {
        unsigned int i;
        unsigned int n;

        for (n = 0, i = *offset;
             i < stringLength && n < item->maxCount;
             i++, n++)
          {
            if (!IsMemberOfCharacterClass(string[i],
                                          item->data.multiChar.characters,
                                          item->data.multiChar.nCharacters))
              {
                break;
              }
          }

        if (n >= item->minCount)
          {
            *offset = i;
            return YES;
          }
        else
          {
            return NO;
          }
      }
      break;
    case AnyCharacterTextPatternItem:
      {
        unsigned int i, n;

        for (i = *offset, n = 0; n < item->minCount; i++, n++)
          {
            if (i >= stringLength)
              {
                return NO;
              }
          }

        *offset = i;
        return YES;
      }
      break;
    case BeginningOfWordTextPatternItem:
      {
        unsigned int i = *offset;

        if (i >= stringLength)
          {
            return NO;
          }

        if (i > 0)
          {
            if (my_isalnum(string[i - 1]))
              {
                return NO;
              }
            else
              {
                return YES;
              }
          }
        else
          {
            return YES;
          }
      }
      break;
    case EndingOfWordTextPatternItem:
      {
        unsigned int i = *offset;

        if (i >= stringLength)
          {
            return YES;
          }

        if (!my_isalnum(string[i]))
          {
            return YES;
          }
        else
          {
            return NO;
          }
      }
      break;
    case BeginningOfLineTextPatternItem:
      {
        unsigned int i = *offset;

        if (i > 0)
          {
            return (string[i - 1] == '\n' || string[i - 1] == '\r');
          }
        else
          {
            return YES;
          }
      }
      break;
    case EndingOfLineTextPatternItem:
      {
        unsigned int i = *offset;

        if (i + 1 < stringLength)
          {
            return (string[i + 1] == '\n' || string[i + 1] == '\r');
          }
        else
          {
            return YES;
          }
      }
      break;
    }

/*  [NSException raise: NSInternalInconsistencyException
              format: _(@"Unknown text pattern item type %i encountered."),
    item->type];*/

  return NO;
}

unsigned int
CheckTextPatternPresenceInString(TextPattern *pattern,
                                 unichar *string,
                                 unsigned int stringLength,
                                 unsigned int index)
{
  unsigned int i, off;

  off = index;

  for (i = 0; i < pattern->nItems; i++)
    {
      if (!CheckTextPatternItemPresence(pattern->items[i],
                                        string,
                                        stringLength,
                                        &off))
        {
          break;
        }
    }

  if (i == pattern->nItems)
    {
      return off - index;
    }
  else
    {
      return 0;
    }
}

unichar *PermissibleCharactersAtPatternBeginning(TextPattern *pattern)
{
  unsigned int i;

  for (i = 0; i < pattern->nItems; i++)
    {
      switch(pattern->items[i]->type)
        {
        case SingleCharacterTextPatternItem:
          {
            unichar * buf;

            buf = malloc(2 * sizeof(unichar));
            buf[0] = pattern->items[i]->data.singleChar;
            buf[1] = 0;

            return buf;
          }
        case MultipleCharactersTextPatternItem:
          {
            unichar * buf;
            unsigned int n = pattern->items[i]->data.multiChar.nCharacters + 1;

            buf = malloc(n * sizeof(unichar));
            memcpy(buf, pattern->items[i]->data.multiChar.characters, n *
              sizeof(unichar));
            buf[n - 1] = 0;

            return buf;
          }
        case AnyCharacterTextPatternItem:
          return (unichar *) -1;

        default: break;
        }
    }

  return NULL;
}
