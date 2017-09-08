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

#include "ServicesParameterWindowController.h"

#include "autokeyviewchain.h"


@implementation TerminalServicesParameterWindowController


-(void) _cancel: (id)sender
{
  [NSApp stopModalWithCode: NSRunAbortedResponse];
}

-(void) _ok: (id)sender
{
  [NSApp stopModalWithCode: NSRunStoppedResponse];
}


- initWithCommandline: (NSString *)cmdline
          selectRange: (NSRange)r
              service: (NSString *)service_name
{
  NSWindow *win;

  win=[[NSPanel alloc] initWithContentRect: NSMakeRect(100,100,380,100)
                                 styleMask: NSTitledWindowMask|NSResizableWindowMask
                                   backing: NSBackingStoreRetained
                                     defer: YES];
  if (!(self=[super initWithWindow: win])) return nil;

  {
    GSVbox *vbox;

    vbox=[[GSVbox alloc] init];
    [vbox setBorder: 4];
    [vbox setDefaultMinYMargin: 4];

    {
      NSButton *b;
      GSHbox *hbox;

      hbox=[[GSHbox alloc] init];
      [hbox setDefaultMinXMargin: 4];
      [hbox setAutoresizingMask: NSViewMinXMargin];

      b=[[NSButton alloc] init];
      [b setTitle: _(@"Cancel")];
      [b setTarget: self];
      [b setAction: @selector(_cancel:)];
      [b sizeToFit];
      [hbox addView: b];
      [b release];

      b=[[NSButton alloc] init];
      [b setTitle: _(@"OK")];
      [b setKeyEquivalent: @"\r"];
      [b setTarget: self];
      [b setAction: @selector(_ok:)];
      [b sizeToFit];
      [hbox addView: b];
      [b release];

      [vbox addView: hbox  enablingYResizing: NO];
      [hbox release];
    }

    {
      NSTextField *f;

      tf_cmdline=f=[[NSTextField alloc] init];
      [f setAutoresizingMask: NSViewWidthSizable];
      [f sizeToFit];
      [f setStringValue: cmdline];
      [vbox addView: f  enablingYResizing: NO];
      DESTROY(f);

      f=[[NSTextField alloc] init];
      [f setAutoresizingMask: NSViewMaxXMargin];
      [f setStringValue: _(@"Command line:")];
      [f setEditable: NO];
      [f setDrawsBackground: NO];
      [f setBordered: NO];
      [f setBezeled: NO];
      [f setSelectable: NO];
      [f sizeToFit];
      [f setAutoresizingMask: 0];
      [vbox addView: f  enablingYResizing: NO];
      DESTROY(f);

      [tf_cmdline setTarget: self];
      [tf_cmdline setAction: @selector(_ok:)];
    }

    [win setContentView: vbox];
    [vbox release];
  }
  [win setDelegate: self];
  [win setTitle:
         [NSString stringWithFormat: _(@"Parameter for service %@"),
                   service_name]];

  [win autoSetupKeyViewChain];
  [win makeFirstResponder: tf_cmdline];
  /*	if (r.length)
	{
        NSText *t=[win fieldEditor: NO  forObject: tf_cmdline];
        printf("t=%@ r=%@\n",[t text],NSStringFromRange(r));
        [t setSelectedRange: r];
	}*/

  [win release];

  return self;
}


-(NSString *) _cmdline
{
  return [[[tf_cmdline stringValue] retain] autorelease];
}


+(NSString *) getCommandlineFrom: (NSString *)cmdline
                     selectRange: (NSRange)r
                         service: (NSString *)service_name
{
  TerminalServicesParameterWindowController *wc;
  NSString *s;
  int result;

  wc=[[self alloc] initWithCommandline: cmdline
                           selectRange: r
                               service: service_name];
  [wc showWindow: self];
  result=[NSApp runModalForWindow: [wc window]];
  s=[wc _cmdline];
  [wc close];
  DESTROY(wc);

  if (result==NSRunStoppedResponse)
    return s;
  else
    return nil;
}

@end

