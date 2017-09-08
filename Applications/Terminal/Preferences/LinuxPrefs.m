/*
  Copyright (C) 2015-2017 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#include "LinuxPrefs.h"

static NSString *characterSet;


typedef struct
{
  NSString *name;
  NSString *display_name;
} character_set_choice_t;

static character_set_choice_t cs_choices[]={
  {@"utf-8"             ,__(@"Unicode")},
  {@"iso-8859-1"        ,__(@"West Europe, Latin-1")},
  {@"iso-8859-2"        ,__(@"East Europe, Latin-2")},
  {@"big-5"             ,__(@"Traditional Chinese")},
  {nil                  ,__(@"Custom, leave unchanged")},
  {nil                  ,nil}
};

@implementation LinuxPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Linux Emulation";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Linux" owner:self];

  return self;
}

- (void)awakeFromNib
{
  int i;
  character_set_choice_t *c;

  [charsetBtn removeAllItems];
  for (i=0,c=cs_choices;c->display_name;i++,c++)
    {
      NSString *title;
      if (c->name)
        {
          title = [NSString stringWithFormat: @"%@ (%@)",
                            c->display_name,c->name];
        }
      else
        {
          title = c->display_name;
        }
      [charsetBtn addItemWithTitle:title];
    }
  [view retain];
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

- (void)_updateControls:(Defaults *)defs
{
  int i;
  character_set_choice_t *c;
  NSString *characterSet = [defs characterSet];
  
  for (i=0,c=cs_choices;c->name;i++,c++)
    {
      if (c->name &&
          [c->name caseInsensitiveCompare:characterSet] == NSOrderedSame)
        break;
    }
  [charsetBtn selectItemAtIndex:i];
  
  [handleMulticellBtn setState:([defs useMultiCellGlyphs] == YES)];

  [escapeKeyBtn setState:[defs doubleEscape]];
  [commandKeyBtn setState:[defs commandAsMeta]];
}

- (void)setDefault:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];
  int      i = [charsetBtn indexOfSelectedItem];
 
  if (cs_choices[i].name != nil)
    {
      [defs setCharacterSet:cs_choices[i].name];
    }
  else
    {
      [defs setCharacterSet:nil];
    }
  [defs setUseMultiCellGlyphs:[handleMulticellBtn state]];

  [defs setDoubleEscape:[escapeKeyBtn state]];
  [defs setCommandAsMeta:[commandKeyBtn state]];
  
  [defs synchronize];
}
- (void)showDefault:(id)sender
{
  [self _updateControls:[[Preferences shared] mainWindowPreferences]];
}

- (void)showWindow
{
  [self _updateControls:[[Preferences shared] mainWindowLivePreferences]];
}
// TODO
- (void)setWindow:(id)sender
{
  /* insert your code here */
}

@end
