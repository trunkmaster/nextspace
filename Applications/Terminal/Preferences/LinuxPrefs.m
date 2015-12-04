/* All Rights reserved */

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


- (void)setDefault:(id)sender
{
  int i = [charsetBtn indexOfSelectedItem];
  if (cs_choices[i].name != nil)
    {
      [ud setObject:cs_choices[i].name forKey:CharacterSetKey];
    }
  else
    {
      [ud setObject:@"" forKey:CharacterSetKey];
    }
  [ud setBool:[handleMulticellBtn state] forKey:UseMultiCellGlyphsKey];

  [ud setBool:[escapeKeyBtn state] forKey:DoubleEscapeKey];
  [ud setBool:[commandKeyBtn state] forKey:CommandAsMetaKey];
  
  [ud synchronize];
  [Defaults readLinuxDefaults];
}
- (void)showDefault:(id)sender
{
  NSString *characterSet = [Defaults characterSet];
  int i;
  character_set_choice_t *c;
  for (i=0,c=cs_choices;c->name;i++,c++)
    {
      if (c->name &&
          [c->name caseInsensitiveCompare: characterSet] == NSOrderedSame)
        break;
    }
  [charsetBtn selectItemAtIndex:i];
  
  [handleMulticellBtn setState:([Defaults useMultiCellGlyphs] == YES)];

  [escapeKeyBtn setState:[Defaults doubleEscape]];
  [commandKeyBtn setState:[Defaults commandAsMeta]];
}
- (void)setWindow:(id)sender
{
  /* insert your code here */
}

@end
