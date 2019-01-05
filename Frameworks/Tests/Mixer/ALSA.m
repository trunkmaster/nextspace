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
- (void)addElement:(ALSAElement *)element;
- (void)removeAllElements;
@end

@implementation ALSAElementsView
- (BOOL)isFlipped
{
  return YES;
}
- (void)addElement:(ALSAElement *)element
{
  NSRect laeFrame = [lastAddedElement frame];
  NSRect eFrame = [[element view] frame];

  if (lastAddedElement == nil) {
    laeFrame = NSMakeRect(0, -eFrame.size.height, eFrame.size.width, eFrame.size.height);
  }

  eFrame.origin.y = laeFrame.origin.y + laeFrame.size.height + 4;
  eFrame.origin.x = 8;
  eFrame.size.width = _frame.size.width - 16;
  [[element view] setFrame:eFrame];
  
  [super addSubview:[element view]];
  lastAddedElement = [element view];

  NSRect frame = [self frame];
  if (NSMaxY(eFrame) > frame.size.height) {
    frame.size.height = eFrame.origin.y + eFrame.size.height + 8;
    [self setFrame:frame];
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

- (void)awakeFromNib
{
  // struct card *first_card;
  // struct card *card;
  ALSACard    *alsaCard;

  [cardsList setRefusesFirstResponder:YES];
  [viewMode setRefusesFirstResponder:YES];
  
  [cardsList removeAllItems];

  for (int number = 0, err = 0; err >= 0 && number >= 0; err = snd_card_next(&number)) {
    alsaCard = [[ALSACard alloc] initWithNumber:number];
    if (alsaCard) {
      [cardsList addItemWithTitle:[alsaCard name]];
      [[cardsList itemWithTitle:[alsaCard name]] setRepresentedObject:alsaCard];
      [alsaCard release];
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
  [self selectCard:cardsList];
} 

- (void)showPanel
{
  if (window == nil) {
    [NSBundle loadNibNamed:@"ALSA" owner:self];
  }
  [window makeKeyAndOrderFront:self];
}

// --- Actions ---

- (void)showElementsForCard:(ALSACard *)card mode:(NSString *)mode
{
  [elementsView removeAllElements];

  for (ALSAElement *elem in [card controls]) {
    if ([mode isEqualToString:@"Playback"] && [elem isPlayback] != NO) {
      [elementsView addElement:elem];
      [elem refresh];
    }
    else if ([mode isEqualToString:@"Capture"] && [elem isPlayback] == NO) {
      [elementsView addElement:elem];
      [elem refresh];
    }
  }  
}

- (void)selectCard:(id)sender
{
  [self showElementsForCard:[[cardsList selectedItem] representedObject]
                       mode:[viewMode titleOfSelectedItem]];
}

- (void)selectViewMode:(id)sender
{
  [self showElementsForCard:[[cardsList selectedItem] representedObject]
                       mode:[viewMode titleOfSelectedItem]];
}


@end
