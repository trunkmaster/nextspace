/*
    SyntaxHighlighter.h

    Interface declaration of the SyntaxHighlighter class for the
    ProjectManager application.

    Copyright (C) 2005  Saso Kiselkov
                  2020  Riccardo Mottola

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
#import <Foundation/NSRange.h>
#import <Foundation/NSCharacterSet.h>

@class NSNotification,
       NSDictionary,
       NSMutableDictionary,
       NSString,
       NSTextStorage;

@class NSFont;

@class SyntaxDefinition;

@interface SyntaxHighlighter : NSObject
{
  NSTextStorage    *textStorage;
  SyntaxDefinition *syntax;

  NSFont *normalFont;
  NSFont *boldFont;
  NSFont *italicFont;
  NSFont *boldItalicFont;

  NSUInteger lastProcessedContextIndex;

  NSRange delayedProcessedRange;
  BOOL    didBeginEditing;
}

- initWithFileType:(NSString *)fileType
       textStorage:(NSTextStorage *)aStorage;

- (void)setNormalFont:(NSFont *)f;
- (void)setBoldFont:(NSFont *)f;
- (void)setItalicFont:(NSFont *)f;
- (void)setBoldItalicFont:(NSFont *)f;

- (void)highlightRange:(NSRange)r;

- (void)textStorageWillProcessEditing:(NSNotification *)notif;

@end
