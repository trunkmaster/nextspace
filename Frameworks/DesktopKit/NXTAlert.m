/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Description: Owner of alert panel
//
// Copyright (C) 2014-2019 Sergii Stoian
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

#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>
#import <NXSystem/NXMouse.h>
#import "NXTAlert.h"

@implementation NXTAlert

//--- When GORM file cannot be used...
- (void)createPanel
{
  NSBox *horizontalLine;
  
  NSLog(@"NXTAlert createPanel thread: %@ (main: %@)", [NSThread currentThread], [NSThread mainThread]);

  panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(100,100,360,193)
                                     styleMask:NSTitledWindowMask
                                       backing:NSBackingStoreRetained
                                         defer:NO];
  [panel setTitle:@""];
  [panel setMinSize:NSMakeSize(360, 193)];
  [panel setMaxSize:NSMakeSize(360, 10000)];
  [panel setReleasedWhenClosed:YES];
  
  icon = [[NSImageView alloc] initWithFrame:NSMakeRect(8,106,48,48)];
  [icon setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
  [icon setImage:[NSApp applicationIconImage]];
  [[panel contentView] addSubview:icon];
  [icon release];
  
  titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(64,119,289,22)];
  [titleField setAutoresizingMask:(NSViewMinYMargin | NSViewWidthSizable)];
  [titleField setStringValue:@"Alert"];
  [titleField setFont:[NSFont systemFontOfSize:20.0]];
  [titleField setDrawsBackground:NO];
  [titleField setEditable:NO];
  [titleField setSelectable:NO];
  [titleField setBezeled:NO];
  [titleField setBordered:NO];
  [[panel contentView] addSubview:titleField];
  [titleField release];

  horizontalLine = [[NSBox alloc] initWithFrame:NSMakeRect(-2,96,364,2)];
  [horizontalLine setAutoresizingMask:(NSViewMinYMargin | NSViewWidthSizable)];
  [horizontalLine setTitlePosition:NSNoTitle];
  [[panel contentView] addSubview:horizontalLine];
  [horizontalLine release];
  
  messageField = [[NSTextField alloc] initWithFrame:NSMakeRect(8,43,344,40)];
  [messageField setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
  [messageField setStringValue:@"Alert message."];
  [messageField setFont:[NSFont systemFontOfSize:14.0]];
  [messageField setDrawsBackground:NO];
  [messageField setEditable:NO];
  [messageField setSelectable:YES];
  [messageField setBezeled:NO];
  [messageField setBordered:NO];
  [[panel contentView] addSubview:messageField];
  [messageField release];
  
  defaultButton = [[NSButton alloc] initWithFrame:NSMakeRect(278,8,72,24)];
  [defaultButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
  [defaultButton setTarget:self];
  [defaultButton setAction:@selector(buttonPressed:)];
  [[panel contentView] addSubview:defaultButton];
  [defaultButton release];
  
  alternateButton = [[NSButton alloc] initWithFrame:NSMakeRect(201,8,72,24)];
  [alternateButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
  [alternateButton setTarget:self];
  [alternateButton setAction:@selector(buttonPressed:)];
  [[panel contentView] addSubview:alternateButton];
  [alternateButton release];
  
  otherButton = [[NSButton alloc] initWithFrame:NSMakeRect(124,8,72,24)];
  [otherButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
  [otherButton setTarget:self];
  [otherButton setAction:@selector(buttonPressed:)];
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

//--- Normal Altert Panel

- (id)initWithTitle:(NSString *)titleText
            message:(NSString *)messageText
      defaultButton:(NSString *)defaultText
    alternateButton:(NSString *)alternateText
        otherButton:(NSString *)otherText
{
  if ([super init] == nil) {
    return nil;
  }
  
  if (![NSBundle loadNibNamed:@"NXTAlertPanel" owner:self]) {
    NSLog(@"Cannot open NXTAlertPanel model file!");
    [self createPanel];
    if (!panel) {
      NSLog(@"Cannot create NXTAlertPanel!");
      return nil;
    }
  }
  
  [titleField setStringValue:titleText];
  [icon setImage:[NSApp applicationIconImage]];
  
  [defaultButton setTitle:defaultText];
  buttons = [[NSMutableArray alloc] initWithObjects:defaultButton,nil];

  if (alternateText == nil || [alternateText isEqualToString:@""]) {
    [alternateButton removeFromSuperview];
  }
  else {
    [alternateButton setTitle:alternateText];
    [buttons addObject:alternateButton];
  }

  if (otherText == nil || [otherText isEqualToString:@""]) {
    [otherButton removeFromSuperview];
  }
  else {
    [otherButton setTitle:otherText];
    [buttons addObject:otherButton];
  }

  [messageField setStringValue:messageText];

  maxButtonWidth = ([panel frame].size.width - 16 - 10) / 3;

  return self;
}

- (void)awakeFromNib
{
  NSDictionary *selectedAttrs;
  NSText       *fieldEditor;
  NSRect       panelFrame;

  panelFrame = [panel frame];
  panelFrame.size.height = [panel minSize].height;
  [panel setFrame:panelFrame display:NO];
  
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
  NSLog(@"NXTAlert: -dealloc");
  [buttons release];
  [super dealloc];
}

- (NSPanel *)panel
{
  return panel;
}

// --- Utility

- (CGFloat)numberOfLinesForText:(NSString *)text
                           font:(NSFont *)font
                          width:(CGFloat)viewWidth
{
  CGFloat	numberOfLines = .0, lineWidth;
  NSUInteger	stringLength, i;
  NSRange	lineRange;
  
  // Check for new line characters ('\n')
  stringLength = [text length];
  for (i = 0, numberOfLines = .0; i < stringLength; numberOfLines++)
    {
      lineRange = [text lineRangeForRange:NSMakeRange(i, 0)];
      i = NSMaxRange(lineRange);
      lineWidth = [font widthOfString:[text substringWithRange:lineRange]];
      numberOfLines += floorf(lineWidth / viewWidth);
    }
  
  // NSLog(@"NXTAlert: number of lines: %.2f", lines);
  
  return numberOfLines;
}

#define B_SPACING 5
#define B_OFFSET 8
- (void)arrangeButtons
{
  NSRect   aFrame, bFrame;
  NSSize   cSize;
  CGFloat  maxWidth = 0.0, buttonWidth;
  CGFloat  xShift;
  CGFloat  interButtonsOffset;
  CGFloat  panelEdgeOffset;
  NSButton *button;

  // Determine button with widest text
  for (int i = 0; i < [buttons count]; i++)
    {
      button = [buttons objectAtIndex:i];
      
      cSize = [[button cell] cellSize];
      if (cSize.width > maxWidth)
        {
          maxWidth = cSize.width;
          if (maxWidth > maxButtonWidth)
            {
              maxWidth = maxButtonWidth;
              break;
            }
        }
    }

  // Resize and reposition buttons
  for (int i = 0; i < [buttons count]; i++)
    {
      button = [buttons objectAtIndex:i];
      
      aFrame = [button frame];
      xShift = aFrame.size.width - maxWidth;
      aFrame.origin.x = panel.frame.size.width - (maxWidth + maxWidth*i);
      aFrame.origin.x -= (B_SPACING * i) + B_OFFSET;
      aFrame.size.width = maxWidth;
      [button setFrame:aFrame];
    }  
}

- (void)sizeToFitScreenSize:(NSSize)screenSize
{
  NSRect    panelFrame;
  NSRect    messageFrame;
  CGFloat   fieldWidth, textWidth;
  CGFloat   linesNum;
  NSFont    *font = [messageField font];
  CGFloat   lineHeight = [font defaultLineHeightForFont];

  fieldWidth = [messageField bounds].size.width;
  linesNum = [self numberOfLinesForText:[messageField stringValue]
                                   font:font
                                  width:fieldWidth];
  
  panelFrame = [panel frame];
  messageFrame = [messageField frame];
  if (linesNum > 1)
    {
      CGFloat newMessageHeight;
      
      panelFrame.size.height -= messageFrame.size.height;
      newMessageHeight = (lineHeight * linesNum);
      panelFrame.size.height += newMessageHeight;
      
      while (panelFrame.size.height > (screenSize.height*0.75) && [font pointSize] > 11.0)
        {
          font = [NSFont systemFontOfSize:[font pointSize] - 1.0];
          lineHeight = [font defaultLineHeightForFont] + 2;
          linesNum = [self numberOfLinesForText:[messageField stringValue]
                                           font:font
                                          width:fieldWidth];
          
          panelFrame.size.height -= newMessageHeight;
          newMessageHeight = (lineHeight * linesNum);
          panelFrame.size.height += newMessageHeight;
          
          [messageField setFont:font];
        }
      [messageField setAlignment:NSLeftTextAlignment];

      panelFrame.origin.y = (screenSize.height - panelFrame.size.height)/2;
    }
  else
    {
      messageFrame.origin.y = messageFrame.origin.y + (messageFrame.size.height/2 - lineHeight/2);
      messageFrame.size.height = lineHeight;
      [messageField setAlignment:NSCenterTextAlignment];
      
      panelFrame.origin.y =
        (screenSize.height - (screenSize.height/4)) - panelFrame.size.height;
    }

  // TODO: GNUstep back XGServer should be fixed to get real screen dimensions.
  // Screen size possibly was changed after application start.
  // GNUstep information about screen size is obsolete. Adopt origin.y to
  // GNUstep screen coordinates.
  NXScreen  *screen = [[NXScreen new] autorelease];
  NXMouse   *mouse = [[NXMouse new] autorelease];
  NXDisplay *display = [screen displayAtPoint:[mouse locationOnScreen]];

  if (display)
    {
      panelFrame.origin.x = display.frame.origin.x;
      panelFrame.origin.x += display.frame.size.width/2 - panelFrame.size.width/2;
      
      panelFrame.origin.y = screenSize.height - (display.frame.origin.y + display.frame.size.height);
      panelFrame.origin.y += (display.frame.size.height * 0.75) - panelFrame.size.height/2;
      // NSLog(@"NXTAlert: panel origin: %@", NSStringFromPoint(panelFrame.origin));
    }
  else
    {
      panelFrame.origin.y += [[panel screen] frame].size.height - screenSize.height;
      panelFrame.origin.x = (screenSize.width - panelFrame.size.width)/2;
    }
  
  [messageField setFrame:messageFrame];
  [panel setFrame:panelFrame display:NO];

  // Buttons
  [self arrangeButtons];
}

// --- Actions

- (void)show
{
  NXScreen *screen = [[NXScreen new] autorelease];

  [self sizeToFitScreenSize:[screen sizeInPixels]];
  [panel makeFirstResponder:defaultButton];
  [panel makeKeyAndOrderFront:self];
}

- (NSInteger)runModal
{
  NSInteger result;
  
  [self show];
  
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
  NXTAlert   *alert;
  NSInteger result;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat:msg arguments:ap];
  va_end(ap);

  if (NSApp == nil)
    {
      // No NSApp ... not running in a gui application so just log.
      NSLog(@"%@: %@", title, message);
      return NSAlertDefaultReturn;
    }
  
  if (defaultButton == nil) {
    defaultButton = @"OK";
  }

  alert = [[NXTAlert alloc] initWithTitle:title
                                 message:message
                           defaultButton:defaultButton
                         alternateButton:alternateButton
                             otherButton:otherButton];
  if (!alert) {
    NSLog(@"%@: %@", title, message);
    return NSAlertDefaultReturn;
  }

  result = [alert runModal];
  [alert release];
  
  return result;
}
