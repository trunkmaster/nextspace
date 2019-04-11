/*
  Class:               NXKeyboard
  Inherits from:       NSObject
  Class descritopn:    Keyboard configuration manipulation (type, rate, layouts)

  Copyright (C) 2017 Sergii Stoian <stoyan255@ukr.net>

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

#import "NXKeyboard.h"
#include <X11/XKBlib.h>
#include <X11/extensions/XKBrules.h>

NSString *InitialRepeat = @"NXKeyboardInitialKeyRepeat";
NSString *RepeatRate = @"NXKeyboardRepeatRate";
NSString *Layouts = @"NXKeyboardLayouts";
NSString *Variants = @"NXKeyboardVariants";
NSString *Model = @"NXKeyboardModel";
NSString *Options = @"NXKeyboardOptions";
NSString *NumLockState = @"NXKeyboardNumLockState";

@implementation NXKeyboard : NSObject

+ (void)configureWithDefaults:(NXDefaults *)defs
{
  NSInteger initialRepeat, repeatRate;
  NXKeyboard *keyb = [NXKeyboard new];

  // Key Repeat
  if ((initialRepeat = [defs integerForKey:InitialRepeat]) < 0)
    initialRepeat = 0;
  if ((repeatRate = [defs integerForKey:RepeatRate]) < 0)
    repeatRate = 0;
  [keyb setInitialRepeat:initialRepeat rate:repeatRate];

  // Layouts, Numeric Keypad, Modifiers
  [keyb setLayouts:[defs objectForKey:Layouts]
          variants:[defs objectForKey:Variants]
           options:[defs objectForKey:Options]];
  if ([[defs objectForKey:Options] containsObject:@"numpad:mac"] == NO)
    [keyb setNumLockState:[defs integerForKey:NumLockState]];
  else
    [keyb setNumLockState:0];
}

// Converts string like
// "us: English (US, alternative international)" into dictionary:
// {
//   Layout = us;
//   Language = English;
//   Description = "US, alternative international";
// }
- (NSDictionary *)_parseVariantString:(NSString *)value
{
  NSArray *comps;
  NSArray *layout;
  NSArray *language;
  NSArray *keys;
  NSMutableDictionary *dictionary;

  layout = [value componentsSeparatedByString:@": "];
  language = [[layout objectAtIndex:1] componentsSeparatedByString:@" ("];

  comps = [[NSArray arrayWithObject:[layout objectAtIndex:0]]
            arrayByAddingObjectsFromArray:language];

  // NSLog(@"Variant array: %@", comps);

  dictionary = [NSMutableDictionary dictionary];
  [dictionary setObject:[comps objectAtIndex:0] forKey:@"Layout"];
  if ([comps count] > 1)
    [dictionary setObject:[comps objectAtIndex:1] forKey:@"Language"];
  if ([comps count] > 2)
    [dictionary setObject:[[[comps objectAtIndex:2] componentsSeparatedByString:@")"] objectAtIndex:0]
                   forKey:@"Description"];
    
  return dictionary;
}

//
// Reading XKB_BASE_LST. Default is '/usr/share/X11/xkb/rules/base.lst'.
//
- (NSDictionary *)_xkbBaseListDictionary
{
  NSMutableDictionary	*dict = [[NSMutableDictionary alloc] init];
  NSMutableDictionary	*modeDict = [[NSMutableDictionary alloc] init];
  NSString		*baseLst;
  NSScanner		*scanner;
  NSString		*lineString = @" ";
  NSString		*sectionName;
  // NSString		*fileName;

  baseLst = [NSString stringWithContentsOfFile:XKB_BASE_LST];
  scanner = [NSScanner scannerWithString:baseLst];

  while ([scanner scanUpToString:@"\n" intoString:&lineString] == YES)
    {
      // New section start encountered
      if ([lineString characterAtIndex:0] == '!')
        {
          if ([[modeDict allKeys] count] > 0)
            {
              [dict setObject:[modeDict copy] forKey:sectionName];
              // fileName = [NSString
              //              stringWithFormat:@"/Users/me/Library/XKB_%@.list",
              //             sectionName];
              // [modeDict writeToFile:fileName atomically:YES];
              [modeDict removeAllObjects];
              [modeDict release];
              modeDict = [[NSMutableDictionary alloc] init];
            }
          
          sectionName = [lineString substringFromIndex:2];
          
          // NSLog(@"Keyboard: found section: %@", sectionName);
        }
      else
        { // Parse line and add into 'modeDict' dictionary
          NSMutableArray	*lineComponents;
          NSString		*key;
          NSMutableString	*value = [[NSMutableString alloc] init];
          BOOL			add = NO;
          
          lineComponents = [[lineString componentsSeparatedByString:@" "]
                             mutableCopy];
          key = [lineComponents objectAtIndex:0];

          for (NSUInteger i = 1; i < [lineComponents count]; i++)
            {
              if (add == NO &&
                  ![[lineComponents objectAtIndex:i] isEqualToString:@""])
                {
                  add = YES;
                  [value appendFormat:@"%@", [lineComponents objectAtIndex:i]];
                }
              else if (add == YES)
                [value appendFormat:@" %@", [lineComponents objectAtIndex:i]];
            }

          // homophonic = {
          //   Layout = ua;
          //   Description = "Ukrainian (homophonic)";
          // }
          if ([sectionName isEqualToString:@"variant"])
            {
              [modeDict setObject:[self _parseVariantString:value] forKey:key];
            }
          else
            {
              [modeDict setObject:value forKey:key];
              [value release];
            }
          
          [lineComponents release];
        }
    }
  
  [dict setObject:[modeDict copy] forKey:sectionName];
  // fileName = [NSString stringWithFormat:@"/Users/me/Library/XKB_%@.list",
  //                      sectionName];
  // [modeDict writeToFile:fileName atomically:YES];
  [modeDict removeAllObjects];
  [modeDict release];

  // [dict writeToFile:@"/Users/me/Library/Keyboards.list" atomically:YES];
  
  return [dict autorelease];
}

- (void)dealloc
{
  if (layoutDict)  [layoutDict release];
  if (modelDict)   [modelDict release];
  if (variantDict) [variantDict release];
  if (optionDict)  [optionDict release];

  [super dealloc];
}

- (NSDictionary *)modelList
{
  if (!modelDict)
    {
      modelDict = [[NSDictionary alloc]
                    initWithDictionary:[[self _xkbBaseListDictionary]
                                         objectForKey:@"model"]];
    }

  return modelDict;
}

- (NSString *)model
{
  return [serverConfig objectForKey:Model];
}

// TODO
- (void)setModel:(NSString *)name
{
}

- (void)setNumLockState:(NSInteger)state
{
  Display	*dpy = XOpenDisplay(NULL);
  XkbDescPtr	xkb;
  unsigned int	mask = 0;
  char		*modifier_atom;
  
  xkb = XkbGetKeyboard(dpy, XkbAllComponentsMask, XkbUseCoreKbd);
  if (!xkb || !xkb->names)
    return;
    
  for (int i = 0; i < XkbNumVirtualMods; i++)
    {
      modifier_atom = XGetAtomName(xkb->dpy, xkb->names->vmods[i]);
      if (modifier_atom != NULL && strcmp("NumLock", modifier_atom) == 0)
        {
          XkbVirtualModsToReal(xkb, 1 << i, &mask);
          break;
        }
    }
  XkbFreeKeyboard(xkb, 0, True);
  
  if(mask == 0)
    return;

  if (state > 0)
    XkbLockModifiers(dpy, XkbUseCoreKbd, mask, mask);
  else
    XkbLockModifiers(dpy, XkbUseCoreKbd, mask, 0);
  
  XCloseDisplay(dpy);
}

//------------------------------------------------------------------------------
// Layouts and options
//------------------------------------------------------------------------------

- (NSDictionary *)availableLayouts
{
  if (!layoutDict)
    {
      layoutDict = [[NSDictionary alloc]
                     initWithDictionary:[[self _xkbBaseListDictionary]
                                          objectForKey:@"layout"]];
    }

  return layoutDict;
}

- (NSString *)nameForLayout:(NSString *)layoutCode
{
  if (!layoutDict)
    {
      layoutDict = [[NSDictionary alloc]
                     initWithDictionary:[[self _xkbBaseListDictionary]
                                          objectForKey:@"layout"]];
    }

  return [layoutDict objectForKey:layoutCode];
}

- (NSString *)nameForVariant:(NSString *)variantCode
{
  NSDictionary	*variant;
  NSString	*title;
  
  if (!variantDict)
    {
      variantDict = [[NSDictionary alloc]
                      initWithDictionary:[[self _xkbBaseListDictionary]
                                           objectForKey:@"variant"]];
    }

  variant = [variantDict objectForKey:variantCode];
  title = [variant objectForKey:@"Description"];
  if (!title)
    title = [variant objectForKey:@"Language"];

  return title;
}

// Return list of dictionaries with keys: Layout, Desc.
- (NSDictionary *)_variantListForKey:(NSString *)field
                              value:(NSString *)value
{
  NSMutableDictionary	*layoutVariants;
  NSDictionary		*variant;
    
  if (!variantDict)
    {
      variantDict = [[NSDictionary alloc]
                      initWithDictionary:[[self _xkbBaseListDictionary]
                                           objectForKey:@"variant"]];
    }

  layoutVariants = [[NSMutableDictionary alloc] init];
  for (NSString *key in [variantDict allKeys])
    {
      variant = [variantDict objectForKey:key];
      if ([[variant objectForKey:field] isEqualToString:value])
        {
          [layoutVariants setObject:[self nameForVariant:key]
                             forKey:key];
        }
    }

  return [layoutVariants autorelease];
}

- (NSDictionary *)variantListForLayout:(NSString *)layout
{
  return [self _variantListForKey:@"Layout" value:layout];
}

- (NSDictionary *)variantListForLanguage:(NSString *)language
{
  return [self _variantListForKey:@"Language" value:language];
}

//
// Retrieving and changing XKB configuration
// 

// Return 'Display' must be closed by caller
- (Display *)_getXkbVariables:(XkbRF_VarDefsRec *)var_defs
                         file:(char **)rules_file
{
  Display *dpy;

  dpy = XkbOpenDisplay(NULL, NULL, NULL, NULL, NULL, NULL);
  if (!XkbRF_GetNamesProp(dpy, rules_file, var_defs) || !rules_file)
    {
      NSLog(@"NXKeyboard: error reading XKB properties!");
      XCloseDisplay(dpy);
      return NULL;
    }

  return dpy;
}

- (NSDictionary *)_serverConfig
{
  Display 		*dpy;
  char			*file = NULL;
  XkbRF_VarDefsRec	vd;
  NSMutableDictionary	*config;

  if ((dpy = [self _getXkbVariables:&vd file:&file]) == NULL)
    return nil;
  else
    XCloseDisplay(dpy);
  
  // NSLog(@"NXKeyboard Model: '%s'; Layouts: '%s'; Variants: '%s' Options: '%s' Rules file: %s",
  //       vd.model, vd.layout, vd.variant, vd.options, file);

  config = [NSMutableDictionary dictionary];
  [config setObject:[NSString stringWithCString:(vd.layout != NULL) ? vd.layout : ""]
             forKey:Layouts];
  [config setObject:[NSString stringWithCString:(vd.variant != NULL) ? vd.variant : ""]
             forKey:Variants];
  [config setObject:[NSString stringWithCString:(vd.options != NULL) ? vd.options : ""]
             forKey:Options];
  [config setObject:[NSString stringWithCString:(vd.model != NULL) ? vd.model : ""]
             forKey:Model];
  
  // [config writeToFile:@"/Users/me/Library/NXKeyboard" atomically:YES];
  
  return config;
}

- (BOOL)_applyServerConfig:(XkbRF_VarDefsRec)xkb_vars
                      file:(char *)file
                forDisplay:(Display *)dpy
{
  XkbComponentNamesRec	rnames;
  XkbRF_RulesPtr 	rules;
  XkbDescPtr		xkb;

  rules = XkbRF_Load("/usr/share/X11/xkb/rules/evdev", "C", True, True);
  if (rules != NULL)
    {
      XkbRF_GetComponents(rules, &xkb_vars, &rnames);
      xkb = XkbGetKeyboardByName(dpy, XkbUseCoreKbd, &rnames,
                                 XkbGBN_AllComponentsMask,
                                 XkbGBN_AllComponentsMask &
                                 (~XkbGBN_GeometryMask), True);
      if (!xkb)
        {
          NSLog(@"[NXKeyboard] Fialed to load new keyboard description.");
          return NO;
        }
    }
  else
    {
      NSLog(@"[NXKeyboard] Failed to load XKB rules!");
    }

  XkbRF_SetNamesProp(dpy, file, &xkb_vars);
  XSync(dpy, False);

  return YES;
}

- (NSArray *)layouts
{
  NSString *l = [[self _serverConfig] objectForKey:Layouts];

  return [l componentsSeparatedByString:@","];
}

- (NSArray *)variants
{
  NSArray  *l = [self layouts];
  NSString *v = [[self _serverConfig] objectForKey:Variants];
  NSArray  *va = [v componentsSeparatedByString:@","];

  while ([l count] > [va count])
    va = [va arrayByAddingObject:@""];

  return va;
}

- (NSArray *)options
{
  NSString	 *optString = [[self _serverConfig] objectForKey:Options];
  NSMutableArray *optArray;
  NSArray	 *options;

  optArray = [[optString componentsSeparatedByString:@","] mutableCopy];

  for (unsigned int i = 0; i < [optArray count]; i++)
    if ([[optArray objectAtIndex:i] isEqualToString:@""])
      [optArray removeObjectAtIndex:i];

  options = [NSArray arrayWithArray:optArray];
  [optArray release];
  
  return options;
}

- (void)addLayout:(NSString *)lCode variant:(NSString *)vCode
{
  NSMutableArray *layouts = [[self layouts] mutableCopy];
  NSMutableArray *variants = [[self variants] mutableCopy];

  if (vCode)
    {
      NSInteger lc = [layouts count];
      NSInteger vc = [variants count];
          
      for (int i = 0; i < (lc - vc); i++)
        [variants addObject:@""];
      
      [variants addObject:vCode];
    }
  else
    {
      [variants addObject:@""];
    }
  
  [layouts addObject:lCode];

  // NSLog(@"[NXKeyboard] addLayout new config: layouts: %@ variants: %@",
  //       layouts, variants);

  [self setLayouts:layouts variants:variants options:nil];
  [layouts release];
  [variants release];
}

- (void)removeLayout:(NSString *)lCode variant:(NSString *)vCode
{
  NSMutableArray *layouts = [[self layouts] mutableCopy];
  NSMutableArray *variants = [[self variants] mutableCopy];
  NSUInteger	 lIndex;

  lIndex = [layouts indexOfObject:lCode];
  for (lIndex = 0; lIndex < [layouts count]; lIndex++)
    {
      if ([[layouts objectAtIndex:lIndex] isEqualToString:lCode] &&
          (!vCode || [vCode isEqualToString:@""] ||
           [[variants objectAtIndex:lIndex] isEqualToString:vCode]))
        break;
    }
  [layouts removeObjectAtIndex:lIndex];
  if (lIndex < [variants count])
    [variants removeObjectAtIndex:lIndex];
  
  [self setLayouts:layouts variants:variants options:nil];
  [layouts release];
  [variants release];
}

// This will be used for keyboard initialization (Preferrences startup).
- (BOOL)setLayouts:(NSArray *)layouts
          variants:(NSArray *)variants
           options:(NSArray *)options
{
  Display		*dpy;
  char			*file = NULL;
  XkbRF_VarDefsRec	xkb_vars;
  BOOL			success = NO;

  if ((dpy = [self _getXkbVariables:&xkb_vars file:&file]) == NULL)
    return NO;

  if (layouts)
    {
      xkb_vars.layout =
        strdup([[layouts componentsJoinedByString:@","] cString]);
    }
  if (variants)
    {
      xkb_vars.variant =
        strdup([[variants componentsJoinedByString:@","] cString]);
    }
  if (options)
    {
      xkb_vars.options =
        strdup([[options componentsJoinedByString:@","] cString]);
    }

  success = [self _applyServerConfig:xkb_vars file:file forDisplay:dpy];

  XCloseDisplay(dpy);

  // Update cached configuration
  if (success == YES)
    {
      if (serverConfig) [serverConfig release];
      serverConfig = [[self _serverConfig] retain];
    }
  
  return success;
}

//------------------------------------------------------------------------------
// Initial Repeat and Repeat Rate
//------------------------------------------------------------------------------

- (void)_setXKBRepeat:(NSInteger)repeat rate:(NSInteger)rate
{
  XkbDescPtr xkb = XkbAllocKeyboard();
  Display    *dpy = XOpenDisplay(NULL);

  if (!dpy)
    {
      NSLog(@"Can't open Display! This program must be run in X Window.");
      return;
    }
  if (!xkb)
    {
      NSLog(@"No X11 XKB extension found!");
      return;
    }
  
  XkbGetControls(dpy, XkbRepeatKeysMask, xkb);
  if (repeat)
    xkb->ctrls->repeat_delay = (int)repeat;
  if (rate)
    xkb->ctrls->repeat_interval = (int)rate;
  XkbSetControls(dpy, XkbRepeatKeysMask, xkb);
  
  XCloseDisplay(dpy);
}
- (XkbDescPtr)_xkbControls
{
  XkbDescPtr xkb = XkbAllocKeyboard();
  Display    *dpy = XOpenDisplay(NULL);

  if (!dpy)
    {
      NSLog(@"Can't open Display! This program must be run in X Window.");
      return NULL;
    }
  if (!xkb)
    {
      NSLog(@"No X11 XKB extension found!");
      return NULL;
    }
  
  XkbGetControls(dpy, XkbRepeatKeysMask, xkb);
  XCloseDisplay(dpy);

  return xkb;
}

- (NSInteger)initialRepeat
{
  return [self _xkbControls]->ctrls->repeat_delay;
}
- (void)setInitialRepeat:(NSInteger)delay
{
  [self _setXKBRepeat:delay rate:0];
}
- (NSInteger)repeatRate
{
  return [self _xkbControls]->ctrls->repeat_interval;
}
- (void)setRepeatRate:(NSInteger)rate
{
  [self _setXKBRepeat:0 rate:rate];
}
- (void)setInitialRepeat:(NSInteger)delay rate:(NSInteger)rate
{
  [self _setXKBRepeat:delay rate:rate];
}

@end
