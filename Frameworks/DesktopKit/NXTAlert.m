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

#import <AppKit/AppKitExceptions.h>
#import <GNUstepGUI/GSDisplayServer.h>

#import <SystemKit/OSEDisplay.h>
#import <SystemKit/OSEMouse.h>
#import "NXTAlert.h"

#define BUTTONS_SPACING 5
#define BUTTONS_OFFSET 8
#define ICON_YARD_HEIGHT 64;

@implementation NXTAlert

//--- When GORM file cannot be used...
- (void)createPanel
{
  NSBox *horizontalLine;
  
  NSDebugLLog(@"NXTAlert",
              @"NXTAlert createPanel thread: %@ (main: %@)",
              [NSThread currentThread], [NSThread mainThread]);

  panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(100,100,360,193)
                                     styleMask:NSTitledWindowMask
                                       backing:NSBackingStoreRetained
                                         defer:NO];
  [panel setTitle:@""];
  [panel setMinSize:NSMakeSize(360, 193)];
  [panel setMaxSize:NSMakeSize(360, 10000)];
  [panel setReleasedWhenClosed:YES];
  
  icon = [[NSImageView alloc] initWithFrame:NSMakeRect(8,137,48,48)];
  [icon setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
  [icon setImage:[NSApp applicationIconImage]];
  [[panel contentView] addSubview:icon];
  [icon release];
  
  titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(64,150,289,22)];
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

  horizontalLine = [[NSBox alloc] initWithFrame:NSMakeRect(-2,126,364,2)];
  [horizontalLine setAutoresizingMask:(NSViewMinYMargin | NSViewWidthSizable)];
  [horizontalLine setTitlePosition:NSNoTitle];
  [[panel contentView] addSubview:horizontalLine];
  [horizontalLine release];
  
  messageView = [[NSTextView alloc] initWithFrame:NSMakeRect(8,43,344,71)];
  [messageView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
  [messageView setText:@"Alert message."];
  [messageView setFont:[NSFont systemFontOfSize:14.0]];
  [messageView setDrawsBackground:YES];
  [messageView setEditable:NO];
  [messageView setSelectable:YES];
  [messageView setAlignment:NSCenterTextAlignment];
  // [messageView setBezeled:NO];
  // [messageView setBordered:NO];
  [[panel contentView] addSubview:messageView];
  [messageView release];
  
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

  [messageView setString:messageText];
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
  [titleField setRefusesFirstResponder:YES];

  [icon setImage:[NSApp applicationIconImage]];
  [icon setRefusesFirstResponder:YES];

  [defaultButton setTitle:defaultText];
  [defaultButton setRefusesFirstResponder:YES];
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

  if (buttons.count > 1) {
    [panel makeFirstResponder:buttons[buttons.count-1]];
  }

  // Setup buttons focus ring
  NSButton *button;
  for (int i = 0; i < buttons.count; i++) {
    button = buttons[i];
    if (i + 1 == buttons.count) {  // last button
      [button setNextKeyView:buttons[0]];
    } else {
      [button setNextKeyView:buttons[i + 1]];
    }
  }

  [messageView setText:messageText];

  return self;
}

- (void)awakeFromNib
{
  NSDictionary *selectedAttrs;

  maxButtonWidth = ([panel frame].size.width - 16 - 10) / 3;
  minButtonWidth = [defaultButton frame].size.width;
  
  [panel setLevel:NSModalPanelWindowLevel];
  
  [titleField setRefusesFirstResponder:YES];
  
  [messageView setText:@"***"];
  [messageView setFont:[NSFont systemFontOfSize:14.0]];
  [messageView setDrawsBackground:NO];
  [messageView setEditable:NO];
  [messageView setSelectable:YES];
  [messageView setAlignment:NSCenterTextAlignment];
  [messageView setTextContainerInset:NSMakeSize(0,0)];
  
  selectedAttrs = @{NSBackgroundColorAttributeName:[NSColor controlLightHighlightColor]};
  [messageView setSelectedTextAttributes:selectedAttrs];

  systemScreen = [OSEScreen sharedScreen];
}

- (void)dealloc
{
  NSDebugLLog(@"Memory",@"NXTAlert: -dealloc");
  [buttons release];
  [super dealloc];
}

- (NSPanel *)panel
{
  return panel;
}

- (void)setAccessoryView:(NSView *)view
{
  if (accessoryView) {
    [accessoryView removeFromSuperview];
  }

  [[panel contentView] addSubview:view];
  accessoryView = view;

  [self sizeToFitScreen];
}

// --- Utility

- (NSRect)rectForView:(NSTextView *)view
{
  NSLayoutManager *layoutManager = [view layoutManager];
  NSRange         textRange = NSMakeRange(0, [[view text] length]);
  NSRect          *rectArray;
  NSUInteger      rectCount;
  NSRect          textRect = NSMakeRect(0,0,0,0);

  rectArray = [layoutManager rectArrayForCharacterRange:textRange
                           withinSelectedCharacterRange:textRange
                                        inTextContainer:[view textContainer]
                                              rectCount:&rectCount];
  // if (rectArray) {
    for (int i = 0; i < rectCount; i++) {
      textRect.size.height += rectArray[i].size.height;
    }
  // } else {
  //   textRect = [view frame];
  // }

  return textRect;
}

- (void)arrangeButtons
{
  NSRect   aFrame, bFrame;
  NSSize   cSize;
  CGFloat  maxWidth = 0.0, buttonWidth;
  CGFloat  interButtonsOffset;
  CGFloat  panelEdgeOffset;
  NSButton *button;

  // Determine button with widest text
  for (int i = 0; i < [buttons count]; i++) {
    button = [buttons objectAtIndex:i];
      
    cSize = [[button cell] cellSize];
    if (cSize.width > maxWidth) {
      maxWidth = cSize.width;
      if (maxWidth > maxButtonWidth) {
        maxWidth = maxButtonWidth;
        break;
      }
      else if (maxWidth < minButtonWidth) {
        maxWidth = minButtonWidth;
      }
    }
  }

  // Resize and reposition buttons
  for (int i = 0; i < [buttons count]; i++) {
    button = [buttons objectAtIndex:i];
      
    aFrame = [button frame];
    aFrame.origin.x = panel.frame.size.width - (maxWidth + maxWidth * i);
    aFrame.origin.x -= (BUTTONS_SPACING * i) + BUTTONS_OFFSET;
    aFrame.size.width = maxWidth;
    [button setFrame:aFrame];
  }
}

- (void)sizeToFitScreen
{
  [self sizeToFitScreenSize:[systemScreen sizeInPixels]];
}

- (void)sizeToFitScreenSize:(NSSize)screenSize
{
  NSRect  panelFrame = [panel frame];
  NSRect  messageFrame = [messageView frame];
  NSFont  *font = [messageView font];
  CGFloat emptyPanelHeight;
  CGFloat maxPanelHeight = screenSize.height - ICON_YARD_HEIGHT;
  NSRect textRect;

  // Panel without message view
  emptyPanelHeight = panelFrame.size.height - messageFrame.size.height;
  
  textRect = [self rectForView:messageView];

  if (textRect.size.height >= messageFrame.size.height) {
    [messageView setAlignment:NSLeftTextAlignment];
    panelFrame.size.height = emptyPanelHeight + textRect.size.height;
    while (panelFrame.size.height >= maxPanelHeight && [font pointSize] >= 11.0) {
      font = [NSFont systemFontOfSize:[font pointSize] - 1.0];
      [messageView setFont:font];
      textRect = [self rectForView:messageView];
      panelFrame.size.height = emptyPanelHeight + textRect.size.height;
    }
  }
  else {
    [messageView setAlignment:NSCenterTextAlignment];
  }
  
  // TODO: GNUstep back XGServer should be fixed to get real screen dimensions.
  // Screen size possibly was changed after application start.
  // GNUstep information about screen size is obsolete. Adopt origin.y to
  // GNUstep screen coordinates.
  OSEMouse   *mouse = [[OSEMouse new] autorelease];
  OSEDisplay *display = [systemScreen displayAtPoint:[mouse locationOnScreen]];

  if (display) {
    panelFrame.origin.x = display.frame.origin.x;
    panelFrame.origin.x += display.frame.size.width/2 - panelFrame.size.width/2;
      
    panelFrame.origin.y = screenSize.height -
      (display.frame.origin.y + display.frame.size.height);
    panelFrame.origin.y += (display.frame.size.height * 0.75) -
      panelFrame.size.height/2;
  }
  else {
    panelFrame.origin.y += [[panel screen] frame].size.height - screenSize.height;
    panelFrame.origin.x = (screenSize.width - panelFrame.size.width)/2;
  }

  // Accessory view
  if (accessoryView) {
    NSRect avFrame, mvFrame;
    NSButton *button = buttons[0];
    CGFloat additionalHeight;

    // Setup accessory view frame
    avFrame = accessoryView.frame;
    avFrame.size.width = panelFrame.size.width + 4;
    avFrame.origin.x = -2;
    avFrame.origin.y = button.frame.origin.y + button.frame.size.height + 10;
    [accessoryView setFrame:avFrame];

    // Enlarge panel height
    additionalHeight = avFrame.size.height + 10;
    panelFrame.size.height += additionalHeight;
    panelFrame.origin.y -= additionalHeight;

    // Move message view up
    mvFrame = messageView.frame;
    mvFrame.origin.y += additionalHeight;
    [messageView setFrame:mvFrame];
  }

  [panel setFrame:panelFrame display:NO];

  // Buttons
  [self arrangeButtons];
}

// --- Actions

- (NSInteger)runModalForWindow:(NSWindow *)theWindow
{
  NSModalSession theSession = 0;
  NSInteger code = NSRunContinuesResponse;
  NSEvent	*event;

  NSLog(@"NXTAlert-runModalForWindow");

  @try {
    NSDate *limit;
    GSDisplayServer *srv;
    BOOL done = NO;

    theSession = [NSApp beginModalSessionForWindow:theWindow];
    limit = [NSDate distantPast];
    // limit = [NSDate dateWithTimeIntervalSinceNow:0.5];
    srv = GSCurrentServer();

    while (code == NSRunContinuesResponse) {
      // limit = [NSDate dateWithTimeIntervalSinceNow:0.1];
      // Try to handle events for this session, discarding others.
      // code = [NSApp runModalSession:theSession];
      // if (code == NSRunContinuesResponse) {
        // Wait until there are more events to handle.
        event = DPSGetEvent(srv, NSAnyEventMask, limit, NSModalPanelRunLoopMode);
        if (event != nil) {
          NSWindow *eventWindow = [event window];

          if (eventWindow == theWindow || [eventWindow worksWhenModal] == YES /*||
              [event type] != NSPeriodic*/) {
            // [NSApp sendEvent:event];
            // [NSApp updateWindows];
            [eventWindow sendEvent:event];
            NSLog(@"NSSendEvent: %@", event);
            // if ([[NSApp windows] indexOfObjectIdenticalTo:theWindow] == NSNotFound ||
            //     ![theWindow isVisible]) {
            //   [NSApp stopModal];
            //   code = 0;
            // }
          }
        }

        // }
    }

    [NSApp endModalSession:theSession];
  } @catch (NSException *localException) {
    if (theSession != 0) {
      [NSApp endModalSession:theSession];
      [theWindow close];
    }
    if ([[localException name] isEqual:NSAbortModalException] == NO) {
      [localException raise];
    }
    code = NSRunAbortedResponse;
  }

  return code;
}

- (void)show
{
  [self sizeToFitScreen];
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


- (void)setButtonsTarget:(id)target
{
  for (NSButton *button in buttons) {
    [button setTarget:target];
  }
}
- (void)setButtonsAction:(SEL)action
{
  for (NSButton *button in buttons) {
    [button setAction:action];
  }
}

- (void)buttonPressed:(id)sender
{
  
  if ([NSApp modalWindow] != panel) {
    NSLog(@"NXAalert panel button pressed when not in modal loop.");
    return;
  }

  [NSApp stopModalWithCode:[sender tag]];
}

@end

NSInteger NXTRunAlertPanel(NSString *title,
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

  if (NSApp == nil) {
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
