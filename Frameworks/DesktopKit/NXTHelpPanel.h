/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Description: Standard panel for application help.
//
// Copyright (C) 2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//
#import <AppKit/NSApplication.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSSplitView.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSTextView.h>

@class NSString, NXTListView, NXTSplitView;

@interface NSApplication (NSApplicationHelpExtension)
- (void)orderFrontHelpPanel:(id)sender;
@end

typedef struct {
  NSUInteger index;
  NSRect     rect;
  NSString   *documentPath;
} NXTHelpHistory;

@interface NXTHelpPanel : NSPanel
{
  NSString       *_helpDirectory;
  NSString       *_helpFile; // Currently displayed document

  // Backtrack
  NXTHelpHistory *history;
  int            historyPosition;
  int            historyLength;

  // Table of contents
  NXTListView    *tocList;
  NSArray        *tocTitles;
  NSArray        *tocAttachments;
  NSUInteger     objectsPrologIndex;

  // Index
  NXTListView    *indexList;
  
  NSButton       *findBtn;
  NSButton       *indexBtn;
  NSButton       *backtrackBtn;
  NSTextField    *findField;
  NSTextField    *statusField;
  NXTSplitView   *splitView;
  NSScrollView   *scrollView;
  NSTextView     *articleView;
}

//
// --- Accessing the Help Panel
//
/** Creates, if necessary, and returns the NSHelpPanel object. */
+ (NXTHelpPanel *)sharedHelpPanel;
/** Creates, if necessary, and returns the NSHelpPanel object.
    If the panel is created, it loads the help directory specified by 
    helpDirectory. The help directory must reside in the main bundle. If a Help 
    panel already exists but has loaded a help directory other than 
    helpDirectory, a second panel will be created. */
+ (NXTHelpPanel *)sharedHelpPanelWithDirectory:(NSString *)helpDirectory;

//
// --- Managing the Contents
//
/** Initializes the panel to display the help text found in helpDirectory. 
    By default, the receiver looks for a directory named `Help`. */
+ (void)setHelpDirectory:(NSString *)helpDirectory;
/** Append additional help entries to the Help panel's table of contents. */
- (void)addSupplement:(NSString *)helpDirectory
               inPath:(NSString *)supplementPath;
/** Returns the absolute path of the help directory. */
- (NSString *)helpDirectory;
/** Returns the path of the currently loaded help file. */
- (NSString *)helpFile;

//
// --- Attaching Help to Objects
//
/** Associates the help file filename and markerName with `anObject`. */
+ (void)attachHelpFile:(NSString *)filename
            markerName:(NSString *)markerName
                    to:(id)anObject;
/** Removes any help information associated with anObject. */
+ (void)detachHelpFrom:(id)anObject;

//
// --- Showing Help
//
/** Causes the Help panel to display the help contained in filename.  
    If markerName is non-NULL, then the marker is sought in the file.  
    If found, it's scrolled into view and the text from the marker to the end of 
    the line is highlighted.  If the file is not a full path, then it's assumed 
    to be relative to the currently displayed help file. */
- (void)showFile:(NSString *)filename
        atMarker:(NSString *)markerName;
/** Causes the panel to display help attached to anObject. */
- (BOOL)showHelpAttachedTo:(id)anObject;

//
// --- Printing
//
/** Prints the currently displayed help text. */
- (void)print:(id)sender;

@end
