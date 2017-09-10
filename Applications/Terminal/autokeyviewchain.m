/*
  copyright 2002 Alexander Malmberg <alexander@malmberg.org>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#include <Foundation/NSObject.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>

#include "autokeyviewchain.h"


@implementation NSWindow (autokeyviewchain)

-(void) autoSetupKeyViewChain
{
  NSView *v=[self contentView];

  [self setInitialFirstResponder: [v autoSetupKeyViewChain: nil]];

  /*	{
        NSView *v=[self initialFirstResponder];
        printf("window %p initial=%p\n",self,v);
        for (;v;v=[v nextKeyView])
        {
        printf("   '%@'\n",v);
        }
	}*/
}

@end


/* just to get rid of warnings */
#include <AppKit/NSScrollView.h>
#include <AppKit/NSClipView.h>

@implementation NSView (autokeyviewchain)

-(NSView *) autoSetupKeyViewChain: (NSView *) next
{
  if ([self acceptsFirstResponder])
    {
      [self setNextKeyView: next];
      next=self;
    }

  /* use NSScrollView to get rid of warning */
  if ([self respondsToSelector: @selector(documentView)])
    next=[[(NSScrollView *)self documentView] autoSetupKeyViewChain: next];
  else if ([self respondsToSelector: @selector(contentView)])
    next=[[(NSScrollView *)self contentView] autoSetupKeyViewChain: next];

  return next;
}

@end


#include <GNUstepGUI/GSTable.h>

@implementation GSTable (autokeyviewchain)

-(NSView *) autoSetupKeyViewChain: (NSView *) next
{
  int i,j;
  NSView *v;

  for (i=0;i<_numberOfRows;i++)
    {
      for (j=_numberOfColumns-1;j>=0;j--)
        {
          if (_jails[i*_numberOfColumns+j])
            {
              v=[[(NSView *)_jails[i*_numberOfColumns+j] subviews] objectAtIndex: 0];
              next=[v autoSetupKeyViewChain: next];
            }
        }
    }
  return next;
}

@end

