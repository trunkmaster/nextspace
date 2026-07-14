// 
// GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html
//
// Copyright (C) 2001-2020 Free Software Foundation
//
// Authors: Sergii Stoian
//          Riccardo Mottola
//
// Description: 
//
// This file is part of GNUstep.
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published 
// by the Free Software Foundation; either version 2 of the License, or 
// (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free Software 
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

#import <AppKit/NSColorSpace.h>

#import "PCEditorFSCPrefs.h"

// ----------------------------------------------------------------------------
// --- PCEditorFSCPrefsFontButton created to forward changeFont: message
// --- to PCEditorFSCPrefs class
// ----------------------------------------------------------------------------

@interface PCEditorFSCPrefsFontButton : NSButton
{
}
@end
@implementation PCEditorFSCPrefsFontButton

- (void)changeFont:(id)sender
{
  [[_cell target] changeFont:sender];
}

- (BOOL)resignFirstResponder
{
  [[NSFontPanel sharedFontPanel] close];
  return YES;
}

@end

@implementation PCEditorFSCPrefs

// ----------------------------------------------------------------------------
// --- Init and free
// ----------------------------------------------------------------------------

- (id)initWithPrefController:(id <PCPreferences>)aPrefs
{
  self = [super init];

  if ([NSBundle loadNibNamed:@"EditorFSCPrefs" owner:self] == NO)
    {
      NSLog(@"PCEditorFSCPrefs: error loading NIB file!");
    }

  prefs = aPrefs;
  currentEditorFont = nil;
  currentConsoleFixedFont = nil;

  RETAIN(editorFSCView);

  return self;
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog (@"PCEditorFSCPrefs: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(editorFSCView);

  [super dealloc];
}

- (void)awakeFromNib
{
  [editorFontButton setTarget:self];
  [editorFontField setAllowsEditingTextAttributes:YES];

  [consoleFixedFontButton setTarget:self];
  [consoleFixedFontField setAllowsEditingTextAttributes:YES];
}

// ----------------------------------------------------------------------------
// --- Utility methods
// ----------------------------------------------------------------------------

- (void)pickFont:(NSFont *)pickedFont
{
  NSFontManager *fontManager = [NSFontManager sharedFontManager];

  [fontManager setSelectedFont:pickedFont isMultiple:NO];
  [fontManager orderFrontFontPanel:self];
}

- (void)changeFont:(id)sender
{
  NSButton *button = (NSButton *)[[editorFSCView window] firstResponder];
  int      buttonTag;
  NSFont   *font;
  NSString *fontString;

  if (![button isKindOfClass:[NSButton class]])
    {
      return;
    }

  font = [sender convertFont:currentEditorFont];
  fontString = [NSString stringWithFormat:@"%@ %0.1f", 
	     [font fontName], [font pointSize]];

  buttonTag = [button tag];
  if (buttonTag == 0) // Editor font button
    {
      [editorFontField setStringValue:fontString];
      [editorFontField setFont:font];
      [prefs setString:[font fontName] forKey:EditorTextFont notify:YES];
      [prefs setFloat:[font pointSize] 
	       forKey:EditorTextFontSize
	       notify:YES];
    }
  else if (buttonTag == 1) // Console Fixed Font button
    {
      [consoleFixedFontField setStringValue:fontString];
      [consoleFixedFontField setFont:font];
      [prefs setString:[font fontName] forKey:ConsoleFixedFont notify:YES];
      [prefs setFloat:[font pointSize] 
	       forKey:ConsoleFixedFontSize
	       notify:YES];
    }
}



// ----------------------------------------------------------------------------
// --- Protocol
// ----------------------------------------------------------------------------
- (void)readPreferences
{
  NSString *fontName;
  float    fontSize;
  NSFont   *editorFont = [NSFont userFixedPitchFontOfSize:0.0];
  NSFont   *consoleFixedFont = [NSFont userFixedPitchFontOfSize:0.0];
  NSString *val;

  // Editor font
  fontName = [prefs stringForKey:EditorTextFont 
		    defaultValue:[editorFont fontName]];
  fontSize = [prefs floatForKey:EditorTextFontSize 
		   defaultValue:[editorFont pointSize]];
  currentEditorFont = [NSFont fontWithName:fontName size:fontSize];
  [editorFontField setStringValue:[NSString stringWithFormat:@"%@ %0.1f", 
    [currentEditorFont fontName], [currentEditorFont pointSize]]];
  [editorFontField setFont:currentEditorFont];

  // Console fixed font
  fontName = [prefs stringForKey:ConsoleFixedFont 
		    defaultValue:[consoleFixedFont fontName]];
  fontSize = [prefs floatForKey:ConsoleFixedFontSize
		   defaultValue:[consoleFixedFont pointSize]];
  currentConsoleFixedFont = [NSFont fontWithName:fontName size:fontSize];
  [consoleFixedFontField setStringValue:[NSString stringWithFormat:@"%@ %0.1f", 
    [currentConsoleFixedFont fontName], [currentConsoleFixedFont pointSize]]];
  [consoleFixedFontField setFont:currentConsoleFixedFont];

  // Editor window size
  val = [prefs stringForKey:EditorLines defaultValue:@"30"];
  [editorLinesField setStringValue:val];
  val = [prefs stringForKey:EditorColumns defaultValue:@"80"];
  [editorColumnsField setStringValue:val];

  // Colors
  currentForegroundColor = [prefs colorForKey:EditorForegroundColor defaultValue:[NSColor blackColor]];
  [foregroundColorWell setColor:currentForegroundColor];

  currentBackgroundColor = [prefs colorForKey:EditorBackgroundColor defaultValue:[NSColor colorWithCalibratedWhite:0.9 alpha:0]];
  [backgroundColorWell setColor:currentBackgroundColor];

  currentSelectionColor = [prefs colorForKey:EditorSelectionColor defaultValue:[NSColor darkGrayColor]];
  [selectionColorWell setColor:currentSelectionColor];
}

- (NSView *)view
{
  return editorFSCView;
}

// ----------------------------------------------------------------------------
// --- Actions
// ----------------------------------------------------------------------------

- (void)setEditorTextFont:(id)sender
{
  [[editorFSCView window] makeFirstResponder:editorFontButton];
  [self pickFont:currentEditorFont];
}

- (void)setConsoleFixedFont:(id)sender
{
  [[editorFSCView window] makeFirstResponder:consoleFixedFontButton];
  [self pickFont:currentConsoleFixedFont];
}

- (void)setEditorSize:(id)sender
{
  NSString *val;
  NSString *key;
  
  if (sender == editorLinesField)
    {
      key = EditorLines;
      val = [editorLinesField stringValue];
    }
  else // editorColumnsField
    {
      key = EditorColumns;
      val = [editorColumnsField stringValue];
    }

  [prefs setString:val forKey:key notify:YES];
}

- (void)setEditorColor:(id)sender
{
  NSColor  *color;
  NSString *key;

  if (sender == foregroundColorWell)
    {
      color = [foregroundColorWell color];
      key = EditorForegroundColor;
    }
  else if (sender == backgroundColorWell)
    {
      color = [backgroundColorWell color];
      key = EditorBackgroundColor;
    }
  else // selectionColorWell
    {
      color = [selectionColorWell color];
      key = EditorSelectionColor;
    }

  [prefs setColor:color forKey:key notify:YES];
}

@end

