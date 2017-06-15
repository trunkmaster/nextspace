/*
  Class:               NXAlert
  Inherits from:       NSObject
  Class descritopn:    This implementation of alert panel was created
                       in attempt to mimic the behaviour of OPENSTEP's one.
                       This behaviour can be described as following:
                       - panel width is not changing on autosizing;
                       - panel height is automatically changed but cannot be
                         more than half of screen;
                       - top edge of panel automatically placed on the center
                         of topmost 1/4 of screen height;
                       - panel brings application in front of other applications;
                       Such hard limits of panel resizing was set up to push
                       developers make some attention to desing of alert
                       panels conforming to "NeXT User Interface Guidelines".

  Copyright (C) 2016 Sergii Stoian

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
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <NXSystem/NXScreen.h>
#import "NXAlert.h"

@implementation NXAlert

//--- When GORM file cannot be used...
- (void)createPanel
{
  NSBox *horizontalLine;

  panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(100,100,360,193)
                                     styleMask:NSTitledWindowMask
                                       backing:NSBackingStoreRetained
                                         defer:NO];
  [panel setReleasedWhenClosed:YES];
  // [panel setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin
  //                             | NSViewWidthSizable)];
  
  icon = [[NSImageView alloc] initWithFrame:NSMakeRect(8,106,48,48)];
  [icon setAutoresizingMask:(NSViewMaxXMargin | NSViewMaxYMargin)];
  [icon setImage:[NSApp applicationIconImage]];
  [[panel contentView] addSubview:icon];
  [icon release];
  
  titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(64,119,289,22)];
  [titleField setAutoresizingMask:(NSViewMaxYMargin | NSViewWidthSizable)];
  [titleField setStringValue:@"Your attention needed"];
  [titleField setFont:[NSFont systemFontOfSize:20.0]];
  [titleField setEditable:NO];
  [titleField setSelectable:YES];
  [titleField setBezeled:NO];
  [titleField setBordered:NO];
  [[panel contentView] addSubview:titleField];
  [titleField release];

  horizontalLine = [[NSBox alloc] initWithFrame:NSMakeRect(-2,96,364,2)];
  [horizontalLine setTitlePosition:NSNoTitle];
  [[panel contentView] addSubview:horizontalLine];
  [horizontalLine release];
  
  messageField = [[NSTextField alloc] initWithFrame:NSMakeRect(8,56,344,17)];
  [messageField setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
  [messageField setStringValue:@"Do you really want to do something serious?"];
  [messageField setFont:[NSFont systemFontOfSize:14.0]];
  [messageField setEditable:NO];
  [messageField setSelectable:YES];
  [messageField setBezeled:NO];
  [messageField setBordered:NO];
  [[panel contentView] addSubview:messageField];
  [messageField release];
  
  defaultButton = [[NSButton alloc] initWithFrame:NSMakeRect(280,8,72,24)];
  [defaultButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
  [defaultButton setTarget:panel];
  [defaultButton setAction:@selector(performClose:)];
  [[panel contentView] addSubview:defaultButton];
  [defaultButton release];
  
  alternateButton = [[NSButton alloc] initWithFrame:NSMakeRect(203,8,72,24)];
  [alternateButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
  [alternateButton setTarget:panel];
  [alternateButton setAction:@selector(performClose:)];
  [[panel contentView] addSubview:alternateButton];
  [alternateButton release];
  
  otherButton = [[NSButton alloc] initWithFrame:NSMakeRect(126,8,72,24)];
  [otherButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
  [otherButton setTarget:panel];
  [otherButton setAction:@selector(performClose:)];
  [[panel contentView] addSubview:otherButton];
  [otherButton release];

  [panel setDefaultButtonCell:[defaultButton cell]];

  [self awakeFromNib];
}

- (void)setTitle:(NSString *)titleText
         message:(NSString *)messageText
       defaultBT:(NSString *)defaultText
     alternateBT:(NSString *)alternateText
         otherBT:(NSString *)otherText
{
  [titleField setStringValue:titleText];
  [defaultButton setTitle:defaultText];

  if (alternateText == nil)
    [alternateButton removeFromSuperview];
  else
    [alternateButton setTitle:alternateText];

  if (otherText == nil)
    [otherButton removeFromSuperview];
  else
    [otherButton setTitle:otherText];

  [messageField setStringValue:messageText];
  if ([messageText rangeOfString: @"\n"].location != NSNotFound)
    {
      [messageField setAlignment:NSLeftTextAlignment];
    }
  else
    {
      [messageField setAlignment:NSCenterTextAlignment];
    }
}

- (void)show
{
  [panel makeKeyAndOrderFront:self];
}

//--- Normal Altert Panel

- (id)initWithTitle:(NSString *)titleText
            message:(NSString *)messageText
      defaultButton:(NSString *)defaultText
    alternateButton:(NSString *)alternateText
        otherButton:(NSString *)otherText
{
  if ([super init] == nil)
    {
      return nil;
    }
  
  if (![NSBundle loadNibNamed:@"NXAlertPanel" owner:self])
    {
      NSLog(@"Cannot open NXAlertPanel model file!");
      return nil;
    }
  
  [titleField setStringValue:titleText];
  [icon setImage:[NSApp applicationIconImage]];
  
  [defaultButton setTitle:defaultText];
  buttons = [[NSMutableArray alloc] initWithObjects:defaultButton,nil];

  if (alternateText == nil)
    {
      [alternateButton removeFromSuperview];
    }
  else
    {
      [alternateButton setTitle:alternateText];
      [buttons addObect:alternateButton];
    }

  if (otherText == nil)
    {
      [otherButton removeFromSuperview];
    }
  else
    {
      [otherButton setTitle:otherText];
      [buttons addObect:otherButton];
    }

  [messageField setStringValue:messageText];

  return self;
}

- (void)awakeFromNib
{
  NSDictionary *selectedAttrs;
  NSText       *fieldEditor;
  
  [titleField setRefusesFirstResponder:YES];
  [messageField setRefusesFirstResponder:YES];
  
  selectedAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSColor controlLightHighlightColor],
                                NSBackgroundColorAttributeName,
                                nil];
  fieldEditor = [panel fieldEditor:YES forObject:messageField];
  [(NSTextView *)fieldEditor setSelectedTextAttributes:selectedAttrs];
}

- (void)dealloc
{
  [buttons release];
}

- (void)sizeToFit
{
  NSRect    panelFrame;
  NSRect    messageFrame;
  CGFloat   fieldWidth, textWidth;
  NSInteger linesNum;
  NSFont    *font = [messageField font];
  CGFloat   lineHeight = [font defaultLineHeightForFont] + 1;
  
  fieldWidth = [messageField bounds].size.width;
  textWidth = [font widthOfString:[messageField stringValue]];
  linesNum = (textWidth/fieldWidth);

  // Set height of panel to the minimum size
  panelFrame = [panel frame];
  panelFrame.size.height = 0;
  [panel setFrame:panelFrame display:NO];
  panelFrame = [panel frame];
  
  messageFrame = [messageField frame];
  messageFrame.origin.y -= lineHeight/2;
  messageFrame.size.height += lineHeight;
  [messageField setFrame:messageFrame];
  
  if (linesNum > 1)
    {
      [messageField setAlignment:NSLeftTextAlignment];
      
      panelFrame.size.height += (lineHeight * (linesNum - 1));
      [panel setFrame:panelFrame display:NO];
    }
  else
    {
      [messageField setAlignment:NSCenterTextAlignment];
    }
  
  // Buttons
  NSRect   aFrame, bFrame;
  NSSize   cSize;
  CGFloat  maxWidth = 0.0, buttonWidth;
  CGFloat  xShift;
  NSButton *button;

  for (int i = 0; i < [buttons count]; i++)
    {
      button = [buttons objectAtIndex:i];
      
      cSize = [[button cell] cellSize];
      if (cSize.width > maxWidth)
        {
          maxWidth = cSize.width;
        }
    }
  NSLog(@"Max button cell width = %f", maxWidth);

  for (int i = 0; i < [buttons count]; i++)
    {
      button = [buttons objectAtIndex:i];
      
      aFrame = [button frame];
      xShift = aFrame.size.width - maxWidth;
      aFrame.origin.x += xShift;
      aFrame.size.width = maxWidth;
      [button setFrame:aFrame];
    }
  
  // aFrame = [defaultButton frame];
  // [defaultButton sizeToFit];
  // bFrame = [defaultButton frame];
  // xShift = aFrame.size.width - bFrame.size.width;
  // aFrame.origin.x += xShift;
  // aFrame.size.width = bFrame.size.width;
  // [defaultButton setFrame:aFrame];

  // aFrame = [alternateButton frame];
  // [alternateButton sizeToFit];
  // bFrame = [alternateButton frame];
  // xShift = aFrame.size.width - bFrame.size.width;
  // aFrame.origin.x += xShift;
  // aFrame.size.width = bFrame.size.width;
  // [alternateButton setFrame:aFrame];

  // aFrame = [otherButton frame];
  // [otherButton sizeToFit];
  // bFrame = [otherButton frame];
  // xShift = aFrame.size.width - bFrame.size.width;
  // aFrame.origin.x += xShift;
  // aFrame.size.width = bFrame.size.width;
  // [otherButton setFrame:aFrame];
  
  // [alternateButton sizeToFit];
  // [otherButton sizeToFit];
}

- (NSInteger)runModal
{
  NSInteger result;
  NSSize  screenSize = [[NXScreen sharedScreen] sizeInPixels];
  NSPoint panelOrigin;
  
  [self sizeToFit];
  [panel center];

  // Place panel at top half of main display
  panelOrigin = [panel frame].origin;
  panelOrigin.y =
    (screenSize.height - screenSize.height/4) - [panel frame].size.height;
  [panel setFrameOrigin:panelOrigin];
  [panel makeFirstResponder:defaultButton];
  
  [panel makeKeyAndOrderFront:self];
  result = [NSApp runModalForWindow:panel];
  [panel orderOut:self];
  
  return result;
}

- (void)buttonPressed:(id)sender
{
  if ([NSApp modalWindow] != panel)
    {
      NSLog(@"NXAalert panel button pressed when not in modal loop.");
      return;
    }
  
  [NSApp stopModalWithCode:[sender tag]];
}

@end

NSInteger NXRunAlertPanel(NSString *title,
                          NSString *msg,
                          NSString *defaultButton,
                          NSString *alternateButton,
                          NSString *otherButton, ...)
{
  va_list    ap;
  NSString  *message;
  NXAlert   *alrtPanel;
  NSInteger result;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat:msg arguments:ap];
  va_end(ap);

  if (NSApp == nil)
    {
      // No NSApp ... not running in a gui application so just log.
      NSLog(@"%@", message);
      return NSAlertDefaultReturn;
    }
  
  if (defaultButton == nil)
    {
      defaultButton = @"OK";
    }

  alrtPanel = [[NXAlert alloc] initWithTitle:title
                                     message:message
                               defaultButton:defaultButton
                             alternateButton:alternateButton
                                 otherButton:otherButton];

  result = [alrtPanel runModal];
  [alrtPanel release];
  
  return result;
}
