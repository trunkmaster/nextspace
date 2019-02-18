/*
   Project: Mixer

   Copyright (C) 2019 Sergii Stoian

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

#import <alsa/asoundlib.h>

#import "ALSA.h"
#import "ALSACard.h"
#import "ALSAElement.h"

@interface ALSAElementsView : NSView
{
  NSView *lastAddedElement;
}
- (void)addElement:(NSView *)view;
- (void)removeAllElements;
@end

@implementation ALSAElementsView
- (BOOL)isFlipped
{
  return YES;
}
- (void)addElement:(NSView *)view
{
  NSRect laeFrame = [lastAddedElement frame];
  NSRect eFrame = [view frame];
  NSSize winMinSize = [[self window] minSize];

  if (lastAddedElement == nil) {
    laeFrame = NSMakeRect(0, -eFrame.size.height, eFrame.size.width, eFrame.size.height);
  }

  eFrame.origin.y = laeFrame.origin.y + laeFrame.size.height;
  eFrame.origin.x = 8;
  eFrame.size.width = _frame.size.width - 16;
  [view setFrame:eFrame];
  
  [super addSubview:view];
  lastAddedElement = view;

  NSRect frame = [self frame];
  frame.size.height = eFrame.origin.y + eFrame.size.height;
  [self setFrame:frame];

  frame = [[self window] frame];
  frame.size.height = 108 + eFrame.origin.y + eFrame.size.height;
  if (frame.size.height > winMinSize.height) {
    [[self window] setMaxSize:frame.size];
  }
}
- (void)removeAllElements
{
  NSRect frame = [self frame];
  
  [[self subviews] makeObjectsPerform:@selector(removeFromSuperview)];
  frame.size.height = [lastAddedElement frame].size.height + 16;
  [self setFrame:frame];
  lastAddedElement = nil;
}
@end

@implementation ALSA

- (void)dealloc
{
  if (window) {
    [window close];
  }

  [super dealloc];
}

- (void)awakeFromNib
{
  ALSACard *alsaCard;
  NSString *cardName;

  // Prepare `No Controls` view
  [noControlsBox retain];
  [noControlsBox removeFromSuperview];
  [noControlsWindow release];

  [cardsList setRefusesFirstResponder:YES];
  [viewMode setRefusesFirstResponder:YES];
  
  [cardsList removeAllItems];

  // number == -1 creates ALSACard with `default` ALSA sound device
  for (int number = -1, err = 0;;) {
    alsaCard = [[ALSACard alloc] initWithNumber:number];
    if (alsaCard) {
      cardName = [alsaCard name];
      [cardsList addItemWithTitle:cardName];
      [[cardsList itemWithTitle:cardName] setRepresentedObject:alsaCard];
      [alsaCard enterEventLoop];
      [alsaCard release];

      err = snd_card_next(&number);
      if (err < 0 || number < 0)
        break;
    }
  }
    
  elementsScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(-2,-2,402,536)];
  [elementsScroll setHasVerticalScroller:YES];
  [elementsScroll setHasHorizontalScroller:NO];
  [elementsScroll setBorderType:NSBezelBorder];
  [elementsScroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [[window contentView] addSubview:elementsScroll];

  elementsView = [[ALSAElementsView alloc]
                   initWithFrame:[elementsScroll documentVisibleRect]];
  [elementsScroll setDocumentView:elementsView];

  [cardsList selectItemAtIndex:0];
  currentCard = [[cardsList itemAtIndex:0] representedObject];

  [self showElementsForCard:currentCard mode:[[viewMode selectedItem] tag]];
}

- (void)showPanel
{
  if (window == nil) {
    [NSBundle loadNibNamed:@"ALSA" owner:self];
  }
  [window makeKeyAndOrderFront:self];
}

// --- Actions ---

- (void)showElementsForCard:(ALSACard *)card mode:(ALSAViewMode)mode
{
  int elementsCount = 0;

  [currentCard pauseEventLoop];
  
  [elementsView removeAllElements];

  [card handleEvents:YES];
  
  for (ALSAElement *elem in [card controls]) {
    elementsCount++;
    if (mode == MixerControlsPlayback && [elem isPlayback] != NO) {
      [elementsView addElement:[elem view]];
    }
    else if (mode == MixerControlsCapture && [elem isCapture] != NO) {
      [elementsView addElement:[elem view]];
    }
    else if (mode == MixerControlsOption && [elem isOption] != NO) {
      [elementsView addElement:[elem view]];
    }
    else {
      elementsCount--;
    }
  }

  if (elementsCount == 0) {
    NSString *message = @"No Controls";
    
    if (mode == MixerControlsPlayback) {
      message = [NSString stringWithFormat:@"No Playback controls for `%@`",
                          [card name]];
    }
    else if (mode == MixerControlsCapture) {
      message = [NSString stringWithFormat:@"No Capture controls for `%@`",
                          [card name]];
    }
    else if (mode == MixerControlsOption) {
      message = [NSString stringWithFormat:@"No Options for `%@`",
                          [card name]];
    }
    
    [noControlsField setStringValue:message];
    [elementsView addElement:noControlsBox];
  }
  
  NSRect frame = [window frame];
  if (frame.size.height > [window maxSize].height) {
    frame.origin.y += frame.size.height - [window maxSize].height;
    frame.size = [window maxSize];
    [window setFrame:frame display:YES];
  }
  else {
    frame.origin.y -= [window maxSize].height - frame.size.height;
    frame.size = [window maxSize];
    [window setFrame:frame display:YES];
  }
  
  [card resumeEventLoop];
  currentCard = card;
}

- (void)selectCard:(id)sender
{
  // [currentCard pauseEventLoop];
  
  [self showElementsForCard:[[cardsList selectedItem] representedObject]
                       mode:[[viewMode selectedItem] tag]];
}

- (void)selectViewMode:(id)sender
{
  [self showElementsForCard:[[cardsList selectedItem] representedObject]
                       mode:[[viewMode selectedItem] tag]];
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  ALSACard *card;

  if (sender != window) {
    return NO;
  }

  for (NSMenuItem *item in [cardsList itemArray]) {
    card = [item representedObject];
    [card quitEventLoop];
  }
  [elementsView removeAllElements];
  [cardsList removeAllItems];

  return YES;
}

@end
