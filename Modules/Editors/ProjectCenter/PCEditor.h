/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2002-2021 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan
	    Riccardo Mottola

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <AppKit/AppKit.h>

#import <Protocols/CodeEditor.h>
#import <Protocols/CodeParser.h>

#import <ProjectCenter/PCProjectEditor.h>

@class PCEditorView;

@interface PCEditor : NSObject <CodeEditor>
{
  id              _editorManager;

  NSTextField     *_extStatusField;
  PCEditorView    *_extEditorView;
  NSTextField     *_intStatusField;
  PCEditorView    *_intEditorView;
  NSTextStorage   *_storage;
  NSMutableString *_path;
  NSString        *_categoryPath;
  NSWindow        *_window;
  NSView          *_containerView;

  BOOL            _isEdited;
  BOOL            _isEditable;
  BOOL            _isWindowed;
  BOOL            _isExternal;
  NSDate          *_lastSaveDate;

  // Search
  NSView          *goToLineView;
  NSView          *quickFindView;

  // Parser
  id<CodeParser>  aParser;
  NSArray         *parserClasses;
  NSArray         *parserMethods;

  // Syntax highlighter (used in PCEditorView)
  BOOL            _highlightSyntax;

  // Default text attributes (not syntax) and open/close brackets
  // highlighting ([],{},())
  NSFont  *defaultFont;
  NSFont  *highlightFont;

  NSColor *textColor;
  NSColor *highlightColor;
  NSColor *backgroundColor;
  NSColor *readOnlyColor;
  NSColor *textBackgroundColor;

  // location of the highlighted delimiter characters
  // NSNotFound means not set
  NSUInteger  highlighted_chars[2];
  
  // This is used to protect that -textViewDidChangeSelection: invocations
  // don't do anything when the text view changing, because this causes
  // further changes to the text view and infinite recursive invocations
  // of this method.
  BOOL editorTextViewIsPressingKey;

  // Slightly delay drawing of highlit parentheses
  NSTimer *phlTimer;

  // keep one undo manager for the editor
  NSUndoManager *undoManager;

  // optimize line status calculations
  NSTimer *lsTimer;
}

- (BOOL)editorShouldClose;

// ===========================================================================
// ==== Window delegate
// ===========================================================================
- (BOOL)windowShouldClose:(id)sender;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignKey:(NSNotification *)aNotification;

// ===========================================================================
// ==== TextView (_intEditorView, _extEditorView) delegate
// ===========================================================================
- (void)textDidChange:(NSNotification *)aNotification;
- (void)textViewDidChangeSelection:(NSNotification *)notification;
- (void)editorTextViewWillPressKey:sender;
- (void)editorTextViewDidPressKey:sender;

- (BOOL)becomeFirstResponder:(PCEditorView *)view;
- (BOOL)resignFirstResponder:(PCEditorView *)view;

// ===========================================================================
// ==== Parser and scrolling and Line Status
// ===========================================================================

- (void)fileStructureItemSelected:(NSString *)item;  // CodeEditor protocol
- (void)scrollToClassName:(NSString *)className;
- (void)scrollToMethodName:(NSString *)methodName;
- (void)scrollToLineNumber:(NSUInteger)lineNumber; // CodeEditor protocol

- (void)computeCurrentLineFromTimer: (NSTimer *)timer;
- (void)computeCurrentLine: (NSTextView *)editorView;

@end

@interface PCEditor (UInterface)

- (void)_createWindow;
- (void)_createInternalView;
- (PCEditorView *)_createEditorViewWithFrame:(NSRect)fr;

@end

@interface PCEditor (Menu)

- (void)pipeOutputOfCommand:(NSString *)command;
// Find
- (void)findNext:sender;
- (void)findPrevious:sender;
- (void)jumpToSelection:sender;

@end

@interface PCEditor (Parenthesis)

- (void)unhighlightCharacter: (NSTextView *)editorView;
- (void)highlightCharacterPair: (NSTextView *)editorView;
- (void)computeNewParenthesisNesting: (NSTextView *)editorView;

@end
