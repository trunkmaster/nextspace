/*
    PCEditorView.m

    Implementation of the PCEditorView class for the
    ProjectManager application.

    Copyright (C) 2005-2021 Free Software Foundation
      Saso Kiselkov
      Serg Stoyan
      Riccardo Mottola

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

#import "PCEditorView.h"

#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSArchiver.h>

#import <AppKit/PSOperators.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSCursor.h>
#import <AppKit/NSLayoutManager.h>
#import <AppKit/NSFont.h>

#import <ctype.h>

#import <ProjectCenter/PCProjectManager.h>

#import "PCEditor.h"
#import "SyntaxHighlighter.h"
#import "LineJumper.h"
#import "Modules/Preferences/EditorFSC/PCEditorFSCPrefs.h"

#define SYNTAX_HL_DELAY 0.05

/**
 * Computes the indenting offset of the last line before the passed
 * start offset containg text in the passed string, e.g.
 *
 * ComputeIndentingOffset(@"  Hello World", 12) = 2
 * ComputeIndentingOffset(@"    Try this one out\n"
 *                        @"      ", 27) = 4
 *
 * @argument string The string in which to do the computation.
 * @argument start The start offset from which to start looking backwards.
 * @return The ammount of spaces the last line containing text is offset
 *      from it's start.
 */
static int ComputeIndentingOffset(NSString * string, NSUInteger start)
{
  SEL sel = @selector(characterAtIndex:);
  unichar (* charAtIndex)(NSString *, SEL, unsigned int) =
    (unichar (*)(NSString *, SEL, unsigned int))
    [string methodForSelector: sel];
  unichar c;
  int firstCharOffset = -1;
  int offset;
  int startOffsetFromLineStart = -1;

  for (offset = start - 1; offset >= 0; offset--)
    {
      c = charAtIndex(string, sel, offset);

      if (c == '\n')
        {
          if (startOffsetFromLineStart < 0)
            {
              startOffsetFromLineStart = start - offset - 1;
            }

          if (firstCharOffset >= 0)
            {
              firstCharOffset = firstCharOffset - offset - 1;
              break;
            }
        }
      else if (!isspace(c))
        {
          firstCharOffset = offset;
        }
    }

  return firstCharOffset >= 0 ? firstCharOffset : 0;

/*  if (firstCharOffset >= 0)
    {
      // if the indenting of the current line is lower than the indenting
      // of the previous actual line, we return the lower indenting
      if (startOffsetFromLineStart >= 0 &&
        startOffsetFromLineStart < firstCharOffset)
        {
          return startOffsetFromLineStart;
        }
      // otherwise we return the actual indenting, so that any excess
      // space is trimmed and the lines are aligned according the last
      // indenting level
      else
        {
          return firstCharOffset;
        }
    }
   else
    {
      return 0;
    }*/
}

@interface PCEditorView (Private)

- (void)insertSpaceFillAlignedAtTabsOfSize:(unsigned int)tabSize;
- (void)performIndentation;

@end

@implementation PCEditorView (Private)

/**
 * Makes the receiver insert as many spaces at the current insertion
 * location as are required to reach the nearest tab-character boundary.
 *
 * @argument tabSize Specifies how many spaces represent one tab.
 */
- (void)insertSpaceFillAlignedAtTabsOfSize:(unsigned int)tabSize
{
  char buf[tabSize];
  NSString * string = [self string];
  unsigned int lineLength;
  SEL sel = @selector(characterAtIndex:);
  unichar (* charAtIndex)(NSString*, SEL, unsigned int) =
    (unichar (*)(NSString*, SEL, unsigned int))
    [string methodForSelector: sel];
  int i;
  int skip;

  // computes the length of the current line
  for (i = [self selectedRange].location - 1, lineLength = 0;
       i >= 0;
       i--, lineLength++)
    {
      if (charAtIndex(string, sel, i) == '\n')
        {
          break;
        }
    }

  skip = tabSize - (lineLength % tabSize);
  if (skip == 0)
    {
      skip = tabSize;
    }

  memset(buf, ' ', skip);
  [super insertText: [NSString stringWithCString: buf length: skip]];
}

// Go backward to first '\n' char or start of file
- (NSInteger)lineStartIndexForIndex:(NSInteger)index forString:(NSString *)string
{
  NSInteger line_start;

  // Get line start index moving from index backwards
  for (line_start = index;line_start > 0;line_start--)
    {
      if ([string characterAtIndex:line_start] == '\n' &&
	  line_start != index)
	{
	  line_start++;
	  break;
	}
    }

  return line_start > index ? index : line_start;
}

- (NSInteger)lineEndIndexForIndex:(NSInteger)index forString:(NSString *)string
{
  NSInteger line_end;
  NSInteger string_length = [string length];

  // Get line start index moving from index backwards
  for (line_end = index;line_end < string_length;line_end++)
    {
      if ([string characterAtIndex:line_end] == '\n')
	{
	  break;
	}
    }

  return line_end < string_length ? line_end : string_length;
}

- (NSInteger)previousLineStartIndexForIndex:(NSInteger)index forString:(NSString *)string
{
  NSInteger cur_line_start;
  NSInteger prev_line_start;

  cur_line_start = [self lineStartIndexForIndex:index forString:string];
  prev_line_start = [self lineStartIndexForIndex:cur_line_start-1
 				       forString:string];

  return prev_line_start;
}

- (NSInteger)nextLineStartIndexForIndex:(NSInteger)index forString:(NSString *)string
{
  NSInteger cur_line_end;
  NSInteger next_line_start;
  NSInteger string_length = [string length];

  cur_line_end = [self lineEndIndexForIndex:index forString:string];
  next_line_start = cur_line_end + 1;

  if (next_line_start < string_length)
    {
      return next_line_start;
    }
  else
    {
      return string_length;
    }
}

- (unichar)firstCharOfLineForIndex:(NSInteger)index forString:(NSString *)string
{
  NSInteger line_start = [self lineStartIndexForIndex:index forString:string];
  NSInteger i;
  unichar c;

  c = 0;
  // Get leading whitespaces range
  for (i = line_start; i >= 0; i++)
    {
      c = [string characterAtIndex:i];
      if (!isspace(c))
	{
	  break;
	}
    }

  fprintf(stderr, "First char: %c\n", c);

  return c;
}

- (unichar)firstCharOfPrevLineForIndex:(NSInteger)index forString:(NSString *)string
{
  NSInteger line_start = [self previousLineStartIndexForIndex:index 
						   forString:string];

  return [self firstCharOfLineForIndex:line_start forString:string];
}

- (void)performIndentation
{
  NSString  *string = [self string];
  NSInteger location;
  NSInteger line_start;
  NSInteger offset;
  unichar   c, plfc, clfc;
  NSRange   wsRange;
  NSMutableString *indentString;
  NSCharacterSet  *wsCharSet = [NSCharacterSet whitespaceCharacterSet];
  NSInteger i;
//  int point;

  location = [self selectedRange].location;

//  point = [self nextLineStartIndexForIndex:location forString:string];
//  [self setSelectedRange:NSMakeRange(point, 0)];

  clfc = [self firstCharOfLineForIndex:location forString:string];
  plfc = [self firstCharOfPrevLineForIndex:location forString:string];

  // Get leading whitespaces range
  line_start = [self lineStartIndexForIndex:location forString:string];
  for (offset = line_start; offset >= 0; offset++)
    {
      c = [string characterAtIndex:offset];
      if (![wsCharSet characterIsMember:c])
	{
	  wsRange = NSMakeRange(line_start, offset-line_start);
	  break;
	}
    }

  // Get indent
  line_start = [self previousLineStartIndexForIndex:location forString:string];
  for (offset = line_start; offset >= 0; offset++)
    {
      c = [string characterAtIndex:offset];
      if (![wsCharSet characterIsMember:c])
	{
	  offset = offset - line_start;
	  NSLog(@"offset: %li", offset);
	  break;
	}
    }

  NSLog (@"clfc: %c plfc: %c", clfc, plfc);
  if (plfc == '{' || clfc == '{')
    {
      offset += 2;
    }
  else if (clfc == '}' && plfc != '{')
    {
      offset -= 2; 
    }

  // Get offset from BOL of previous line
//  offset = ComputeIndentingOffset([self string], line_start-1);
  NSLog(@"Indent offset: %li", offset);

  // Replace current line whitespaces with new ones
  indentString = [[NSMutableString alloc] initWithString:@""];
  for (i = offset; i > 0; i--)
    {
      [indentString appendString:@" "];
    }

  if ([self shouldChangeTextInRange:wsRange
		  replacementString:indentString])
    [[self textStorage] replaceCharactersInRange:wsRange 
				      withString:indentString];

/*  if (location > line_start + offset)
    {
      point = location - offset;
    }
  else
    {
      point = location;
    }
  [self setSelectedRange:NSMakeRange(point, 0)];*/

  [indentString release];
}

@end

@implementation PCEditorView

+ (NSFont *)defaultEditorFont
{
  NSFont         *font = nil;

  font = [NSFont userFixedPitchFontOfSize:0];
  return font;
}

+ (NSFont *)defaultEditorBoldFont
{
  NSFont *font = [self defaultEditorFont];

  return [[NSFontManager sharedFontManager] convertFont:font
                                            toHaveTrait:NSBoldFontMask];
}

+ (NSFont *)defaultEditorItalicFont
{
  NSFont *font = [self defaultEditorFont];

  return [[NSFontManager sharedFontManager] convertFont:font
                                            toHaveTrait:NSItalicFontMask];
}

+ (NSFont *)defaultEditorBoldItalicFont
{
  NSFont *font = [self defaultEditorFont];

  return [[NSFontManager sharedFontManager] convertFont:font
                                            toHaveTrait:NSBoldFontMask |
                                                        NSItalicFontMask];
}

- (NSFont *)editorFont
{
  id <PCPreferences> prefs;
  NSString          *fontName;
  CGFloat            fontSize;
  NSFont            *font = nil;

  prefs = [[[editor editorManager] projectManager] prefController];

  fontName = [prefs stringForKey:EditorTextFont];
  fontSize = [prefs floatForKey:EditorTextFontSize];

  font = [NSFont fontWithName:fontName size:fontSize];
  if (font == nil)
    font = [NSFont userFixedPitchFontOfSize:0]; 

  return font;
}

- (NSFont *)editorBoldFont
{
  NSFont *font = [self editorFont];

  return [[NSFontManager sharedFontManager] convertFont:font
                                            toHaveTrait:NSBoldFontMask];
}

- (NSFont *)editorItalicFont
{
  NSFont *font = [self editorFont];

  return [[NSFontManager sharedFontManager] convertFont:font
                                            toHaveTrait:NSItalicFontMask];
}

- (NSFont *)editorBoldItalicFont
{
  NSFont *font = [self editorFont];

  return [[NSFontManager sharedFontManager] convertFont:font
                                            toHaveTrait:NSBoldFontMask |
                                                        NSItalicFontMask];
}

// ---
- (BOOL)becomeFirstResponder
{
  return [editor becomeFirstResponder:self];
}

- (BOOL)resignFirstResponder
{
  return [editor resignFirstResponder:self];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}
// ---

- (void)dealloc
{
  TEST_RELEASE(highlighter);

  [super dealloc];
}

- (void)setEditor:(NSObject <CodeEditor> *)anEditor
{
  editor = (PCEditor *)anEditor;
}

- (NSObject <CodeEditor> *)editor
{
  return editor;
}

- (void)drawRect:(NSRect)r
{
  if (highlighter)
    {
      NSRange drawnRange;
      NSValue *timerInfo;

      drawnRange = [[self layoutManager] 
	glyphRangeForBoundingRect:r inTextContainer:[self textContainer]];
      drawnRange = [[self layoutManager] characterRangeForGlyphRange:drawnRange
                                                    actualGlyphRange:NULL];

      timerInfo = [NSValue valueWithRange:drawnRange];

      if (nil != hlTimer)
	{
	  [hlTimer invalidate];
	  hlTimer = nil;
	}

      hlTimer = [NSTimer scheduledTimerWithTimeInterval:SYNTAX_HL_DELAY
						 target:self
					       selector:@selector(highlightRangeFromTimer:)
					       userInfo:timerInfo
						repeats:NO];
    }

  [super drawRect:r];
}

- (void)highlightRangeFromTimer:(NSTimer *)t
{
  NSRange range;

  range = [(NSValue *)[t userInfo] rangeValue];
  hlTimer = nil;
  [highlighter highlightRange:range];
}

- (void)createSyntaxHighlighterForFileType:(NSString *)fileType
{
  ASSIGN(highlighter, 
	 [[[SyntaxHighlighter alloc] initWithFileType:fileType
					  textStorage:[self textStorage]]
					  autorelease]);
  [highlighter setNormalFont: [self editorFont]];
  [highlighter setBoldFont: [self editorBoldFont]];
  [highlighter setItalicFont: [self editorItalicFont]];
  [highlighter setBoldItalicFont: [self editorBoldItalicFont]];
}

- (void) cancelOperation: (id)sender
{
  // ignore ESC char
}

- (void) insertNewline: (id)sender
{
  NSInteger location = [self selectedRange].location;
  int  offset = ComputeIndentingOffset([self string], location);
  char buf[offset+2];

  buf[0] = '\n';
  memset(&buf[1], ' ', offset);
  buf[offset+1] = '\0';

  // let's use UTF8 to be on the safe side
  [self insertText: [NSString stringWithCString: buf
				       encoding: NSUTF8StringEncoding]];
}

- (void) insertTab: (id)sender
{
  [self performIndentation];
}

/* This extra change tracking is required in order to inform the document
 * that the text is changing _before_ it actually changes. This is required
 * so that the document can un-highlight any highlit characters before the
 * change occurs and after the change recompute any new highlighting.
 */
- (void)keyDown:(NSEvent *)ev
{
  [editor editorTextViewWillPressKey:self];
  [super keyDown:ev];
  [editor editorTextViewDidPressKey:self];
}

- (void)paste:sender
{
  [editor editorTextViewWillPressKey:self];
  [super paste:sender];
  [editor editorTextViewDidPressKey:self];
}

- (void)mouseDown:(NSEvent *)ev
{
  [editor editorTextViewWillPressKey:self];
  [super mouseDown:ev];
  [editor editorTextViewDidPressKey:self];
}

- (NSRect)selectionRect
{
  return _insertionPointRect;
}

- (BOOL)usesFindPanel
{
  return YES;
}

- (void)performGoToLinePanelAction:(id)sender
{
  LineJumper *lj;

  lj = [LineJumper sharedInstance];
  [lj orderFrontLinePanel:self];
}

- (void)goToLineNumber:(NSUInteger)lineNumber
{
  NSUInteger   offset;
  NSUInteger   i;
  NSString     *line;
  NSEnumerator *e;
  NSArray      *lines;
  NSRange      range;

  lines = [[self string] componentsSeparatedByString: @"\n"];
  e = [lines objectEnumerator];

  for (offset = 0, i = 1;
       (line = [e nextObject]) != nil && i < lineNumber;
       i++, offset += [line length] + 1);

  if (line != nil)
    {
      range = NSMakeRange(offset, [line length]);
    }
  else
    {
      range = NSMakeRange([[self string] length], 0);
    }
  [self setSelectedRange:range];
  [self scrollRangeToVisible:range];
}

@end
