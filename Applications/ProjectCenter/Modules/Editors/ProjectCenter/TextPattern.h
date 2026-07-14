/*
    TextPattern.h

    Declarations of data structures and functions for text pattern
    manipulation for the ProjectManager application.

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

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

typedef struct {
  enum {
    SingleCharacterTextPatternItem,
    MultipleCharactersTextPatternItem,
    AnyCharacterTextPatternItem,
    BeginningOfWordTextPatternItem,
    EndingOfWordTextPatternItem,
    BeginningOfLineTextPatternItem,
    EndingOfLineTextPatternItem
  } type;

  union {
    unichar singleChar;
    struct {
      unichar * characters;
      unsigned int nCharacters;
    } multiChar;
  } data;

  unsigned int minCount, maxCount;
} TextPatternItem;

typedef struct {
  NSString * string;

  TextPatternItem ** items;
  unsigned int nItems;
} TextPattern;

TextPattern *
CompileTextPattern (NSString * string);

void
FreeTextPattern (TextPattern * pattern);

static inline BOOL
TextPatternsEqual(TextPattern * pattern1, TextPattern * pattern2)
{
  return [pattern1->string isEqualToString: pattern2->string];
}

unsigned int
CheckTextPatternPresenceInString(TextPattern * pattern,
                                 unichar * string,
                                 unsigned int stringLength,
                                 unsigned int index);

unichar * PermissibleCharactersAtPatternBeginning(TextPattern * pattern);
