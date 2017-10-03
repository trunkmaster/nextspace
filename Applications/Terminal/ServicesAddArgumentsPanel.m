/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSBundle.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSPanel.h>
#include <AppKit/NSButton.h>
#include <GNUstepGUI/GSVbox.h>
#include <GNUstepGUI/GSHbox.h>

#include "ServicesAddArgumentsPanel.h"

#include "autokeyviewchain.h"


@implementation ServicesAddArgumentsPanel

- initWithCommandline:(NSString *)cmdline
          selectRange:(NSRange)r
              service:(NSString *)service_name
{
  if (addArgsPanel == nil)
    {
      if ([NSBundle loadNibNamed:@"AddArguments" owner:self] == NO)
        {
          NSLog(@"Error loading NIB AddArguments");
          return nil;
        }
    }
}

- (void)awakeFromNib
{
}

- (void)cancel:(id)sender
{
  [NSApp stopModalWithCode:NSRunAbortedResponse];
}

- (void)ok:(id)sender
{
  [NSApp stopModalWithCode:NSRunStoppedResponse];
}

- (NSString *)cmdline
{
  return [[[commandField stringValue] retain] autorelease];
}

+ (NSString *)getCommandlineFrom:(NSString *)cmdline
                     selectRange:(NSRange)r
                         service:(NSString *)service_name
{
  ServicesAddArgumentsPanel *panel;
  NSString *s;
  int result;

  panel = [[self alloc] initWithCommandline:cmdline
                                selectRange:r
                                    service:service_name];
  [panel showWindow:self];
  result = [NSApp runModalForWindow:[panel window]];
  s = [panel _cmdline];
  [panel close];
  DESTROY(panel);

  if (result == NSRunStoppedResponse)
    return s;
  else
    return nil;
}

@end

