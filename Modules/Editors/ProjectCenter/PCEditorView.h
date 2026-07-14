/*
    EditorTextView.h

    Interface declaration of the EditorTextView class for the
    ProjectManager application.

    Copyright (C) 2005-2021 Free Software Foundation
      Saso Kiselkov
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

#import <AppKit/NSTextView.h>

#import <Protocols/CodeEditorView.h>

@class NSColor;
@class PCEditor;
@class SyntaxHighlighter;
@class NSTimer;

@interface PCEditorView : NSTextView <CodeEditorView>
{
  PCEditor          *editor;
  SyntaxHighlighter *highlighter;
  NSTimer           *hlTimer;
}

+ (NSFont *)defaultEditorFont;
+ (NSFont *)defaultEditorBoldFont;
+ (NSFont *)defaultEditorItalicFont;
+ (NSFont *)defaultEditorBoldItalicFont;

- (NSFont *)editorFont;
- (NSFont *)editorBoldFont;
- (NSFont *)editorItalicFont;
- (NSFont *)editorBoldItalicFont;


- (void)setEditor:(NSObject <CodeEditor> *)anEditor;

- (void)createSyntaxHighlighterForFileType:(NSString *)fileType;

- (NSRect)selectionRect;

// =====
// CodeEditorView protocol
// =====
- (void)performGoToLinePanelAction:(id)sender;
- (void)goToLineNumber:(NSUInteger)lineNumber;

@end
