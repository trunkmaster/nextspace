/*
  Based on TextFinder from TextEdit application. Original copyright:
  --------------------------------------------------------------------
  Copyright (c) 1995-1996, NeXT Software, Inc.
  All rights reserved.
  Author: Ali Ozer

  You may freely copy, distribute and reuse the code in this example.
  NeXT disclaims any warranty of any kind, expressed or implied,
  as to its fitness for any particular use.
  --------------------------------------------------------------------
*/

#import <AppKit/AppKit.h>
#import "Controller.h"
#import "TerminalView.h"
#import "TerminalWindow.h"
#import "TerminalFinder.h"

@implementation TerminalFinder

- (id)init
{
  if (!(self = [super init]))
    return nil;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appDidActivate:)
                                               name:NSApplicationDidBecomeActiveNotification
                                             object:[NSApplication sharedApplication]];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(addWillDeactivate:)
                                               name:NSApplicationWillResignActiveNotification
                                             object:[NSApplication sharedApplication]];

  [self setFindString:@""];
  [self loadFindStringFromPasteboard];

  return self;
}

- (void)appDidActivate:(NSNotification *)notification
{
  [self loadFindStringFromPasteboard];
}

- (void)addWillDeactivate:(NSNotification *)notification
{
  [self loadFindStringToPasteboard];
}

- (void)loadFindStringFromPasteboard
{
  NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSFindPboard];

  if ([[pasteboard types] containsObject:NSStringPboardType]) {
    NSString *string = [pasteboard stringForType:NSStringPboardType];
    if (string && [string length]) {
      [self setFindString:string];
      findStringChangedSinceLastPasteboardUpdate = NO;
    }
  }
}

- (void)loadFindStringToPasteboard
{
  NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSFindPboard];

  if (findStringChangedSinceLastPasteboardUpdate) {
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteboard setString:[self findString] forType:NSStringPboardType];
    findStringChangedSinceLastPasteboardUpdate = NO;
  }
}

static id sharedFindObject = nil;

+ (id)sharedInstance
{
  if (!sharedFindObject) {
    sharedFindObject = [[self alloc] init];
  }
  return sharedFindObject;
}

- (void)loadUI
{
  if (!findTextField) {
    if (![NSBundle loadNibNamed:@"Find" owner:self]) {
      NSLog(@"Failed to load Find.gorm");
      NSBeep();
    }
    if (self == sharedFindObject) {
      [[findTextField window] setFrameAutosaveName:@"FindPanel"];
    }
  }
  [findTextField setStringValue:[self findString]];
  [statusField setStringValue:@""];
  [findPanel setDefaultButtonCell:[findNextButton cell]];
}

- (void)dealloc
{
  if (self != sharedFindObject) {
    [findString release];
    [super dealloc];
  }
}

- (NSString *)findString
{
  return findString;
}

- (void)setFindString:(NSString *)string
{
  if ([string isEqualToString:findString]) {
    return;
  }

  [findString release];
  findString = [string copy];

  if (findTextField) {
    [findTextField setStringValue:string];
    [findTextField selectText:nil];
  }

  findStringChangedSinceLastPasteboardUpdate = YES;
}

// - (NSTextView *)textObjectToSearchIn
// {
//   id	obj = [[NSApp mainWindow] firstResponder];

//   return (obj && [obj isKindOfClass:[NSTextView class]]) ? obj : nil;
// }

- (NSPanel *)findPanel
{
  if (!findPanel) {
    [self loadUI];
  }
  return findPanel;
}

/*
  The primitive for finding; this ends up setting the status field (and
  beeping if necessary)...
*/
- (BOOL)find:(BOOL)direction
{
  TerminalView *tView;

  tView = [[[NSApp delegate] terminalWindowForWindow:[NSApp mainWindow]] terminalView];

  NSLog(@"TerminalView: %@", tView);

  lastFindWasSuccessful = NO;

  if (tView) {
    NSString *textContents = [[tView stringRepresentation] copy];
    NSUInteger textLength;

    NSLog(@"Terminal contents length: %lu", [textContents length]);

    if (textContents && (textLength = [textContents length])) {
      NSRange range;
      unsigned int options = 0;

      if (direction == Backward) {
        options |= NSBackwardsSearch;
      }
      if ([ignoreCaseButton state]) {
        options |= NSCaseInsensitiveSearch;
      }
      range = [textContents findString:[self findString]
                         selectedRange:[tView selectedRange]
                               options:options
                                  wrap:YES];
      if (range.length) {
        [tView setSelectedRange:range];
        [tView scrollRangeToVisible:range];
        lastFindWasSuccessful = YES;
      }
    }
    [textContents release];
  }

  if (!lastFindWasSuccessful) {
    NSBeep();
    [statusField
        setStringValue:NSLocalizedStringFromTable(
                           @"Not found", @"FindPanel",
                           @"Status displayed in find panel when the find string is not found.")];
  } else {
    [statusField setStringValue:@""];
  }

  return lastFindWasSuccessful;
}

- (void)orderFrontFindPanel:(id)sender
{
  NSPanel *panel = [self findPanel];

  [self loadFindStringFromPasteboard];
  [findTextField selectText:nil];
  [panel makeKeyAndOrderFront:nil];
}

/**** Action methods for gadgets in the find panel;
      these should all end up setting or clearing the status field ****/

- (void)findNextAndOrderFindPanelOut:(id)sender
{
  [findNextButton performClick:nil];

  if (lastFindWasSuccessful) {
    [[self findPanel] orderOut:sender];
  } else {
    [findTextField selectText:nil];
  }
}

- (void)findNext:(id)sender
{
  // NSLog(@"Find Next");
  // findTextField should be set
  if (findTextField) {
    [self setFindString:[findTextField stringValue]];
  }
  [self find:Forward];
}

- (void)findPrevious:(id)sender
{
  // NSLog(@"Find Previous");
  // findTextField should be set
  if (findTextField) {
    [self setFindString:[findTextField stringValue]];
  }
  [self find:Backward];
}

@end

@implementation NSString (NSStringTextFinding)

- (NSRange)findString:(NSString *)string
        selectedRange:(NSRange)selectedRange
              options:(unsigned)options
                 wrap:(BOOL)wrap
{
  BOOL forwards = (options & NSBackwardsSearch) == 0;
  unsigned int length = [self length];
  NSRange searchRange, range;

  if (forwards) {
    searchRange.location = NSMaxRange(selectedRange);
    searchRange.length = length - searchRange.location;
    range = [self rangeOfString:string options:options range:searchRange];

    if ((range.length == 0) && wrap) { /* If not found look at the first part of the string */
      searchRange.location = 0;
      searchRange.length = selectedRange.location;
      range = [self rangeOfString:string options:options range:searchRange];
    }
  } else {
    searchRange.location = 0;
    searchRange.length = selectedRange.location;
    range = [self rangeOfString:string options:options range:searchRange];

    if ((range.length == 0) && wrap) {
      searchRange.location = NSMaxRange(selectedRange);
      searchRange.length = length - searchRange.location;
      range = [self rangeOfString:string options:options range:searchRange];
    }
  }
  return range;
}

@end
