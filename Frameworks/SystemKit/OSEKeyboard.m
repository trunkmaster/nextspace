/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
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

#import "OSEKeyboard.h"
#include <X11/XKBlib.h>
#include <X11/extensions/XKBrules.h>

NSString *OSEKeyboardInitialRepeat = @"KeyboardInitialKeyRepeat";
NSString *OSEKeyboardRepeatRate = @"KeyboardRepeatRate";
NSString *OSEKeyboardLayouts = @"KeyboardLayouts";
NSString *OSEKeyboardVariants = @"KeyboardVariants";
NSString *OSEKeyboardModel = @"KeyboardModel";
NSString *OSEKeyboardOptions = @"KeyboardOptions";
NSString *OSEKeyboardNumLockState = @"KeyboardNumLockState";

@implementation OSEKeyboard : NSObject

+ (void)configureWithDefaults:(NXTDefaults *)defs
{
  NSInteger	initialRepeat, repeatRate;
  OSEKeyboard	*keyb;
  NSArray	*layouts, *variants;

  keyb = [OSEKeyboard new];

  // Model
  [keyb setModel:[defs objectForKey:OSEKeyboardModel]];

  // Key Repeat
  if ((initialRepeat = [defs integerForKey:OSEKeyboardInitialRepeat]) < 0)
    initialRepeat = 0;
  if ((repeatRate = [defs integerForKey:OSEKeyboardRepeatRate]) < 0)
    repeatRate = 0;
  [keyb setInitialRepeat:initialRepeat rate:repeatRate];

  // Layouts and Modifiers
  layouts = [defs objectForKey:OSEKeyboardLayouts];
  if (!layouts || [layouts count] == 0) {
    layouts = [keyb layouts];
    variants = [keyb variants];
  }
  else {
    variants = [defs objectForKey:OSEKeyboardVariants];
  }
  [keyb setLayouts:layouts
          variants:variants
           options:[defs objectForKey:OSEKeyboardOptions]];

  // Numeric Keypad
  if ([[defs objectForKey:OSEKeyboardOptions] containsObject:@"numpad:mac"] == NO) {
    [keyb setNumLockState:[defs integerForKey:OSEKeyboardNumLockState]];
  }
  else {
    [keyb setNumLockState:0];
  }
  
  [keyb release];
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

// Reading XKB_BASE_LST. Default is '/usr/share/X11/xkb/rules/base.lst'.
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

  while ([scanner scanUpToString:@"\n" intoString:&lineString] == YES) {
    // New section start encountered
    if ([lineString characterAtIndex:0] == '!') {
      if ([[modeDict allKeys] count] > 0) {
        [dict setObject:[modeDict copy] forKey:sectionName];
        [modeDict removeAllObjects];
        [modeDict release];
        modeDict = [[NSMutableDictionary alloc] init];
      }
          
      sectionName = [lineString substringFromIndex:2];
    }
    else { // Parse line and add into 'modeDict' dictionary
      NSMutableArray	*lineComponents;
      NSString		*key;
      NSMutableString	*value = [[NSMutableString alloc] init];
      BOOL			add = NO;
          
      lineComponents = [[lineString componentsSeparatedByString:@" "]
                         mutableCopy];
      key = [lineComponents objectAtIndex:0];

      for (NSUInteger i = 1; i < [lineComponents count]; i++) {
        if (add == NO &&
            ![[lineComponents objectAtIndex:i] isEqualToString:@""]) {
          add = YES;
          [value appendFormat:@"%@", [lineComponents objectAtIndex:i]];
        }
        else if (add == YES) {
          [value appendFormat:@" %@", [lineComponents objectAtIndex:i]];
        }
      }

      if ([sectionName isEqualToString:@"variant"]) {
        [modeDict setObject:[self _parseVariantString:value] forKey:key];
      }
      else {
        [modeDict setObject:value forKey:key];
        [value release];
      }
      [lineComponents release];
    }
  }
  
  [dict setObject:[modeDict copy] forKey:sectionName];
  [modeDict removeAllObjects];
  [modeDict release];
  
  return [dict autorelease];
}

// Return 'Display' must be closed by caller
- (Display *)_getXkbVariables:(XkbRF_VarDefsRec *)var_defs
                         file:(char **)rules_file
{
  Display *dpy;

  dpy = XkbOpenDisplay(NULL, NULL, NULL, NULL, NULL, NULL);
  if (!XkbRF_GetNamesProp(dpy, rules_file, var_defs) || !rules_file)
    {
      NSLog(@"OSEKeyboard: error reading XKB properties!");
      XCloseDisplay(dpy);
      return NULL;
    }

  return dpy;
}

- (BOOL)_applyServerConfig:(XkbRF_VarDefsRec *)xkb_vars
                      file:(char *)file
                forDisplay:(Display *)dpy
{
  XkbComponentNamesRec	rnames;
  XkbRF_RulesPtr 	rules;
  XkbDescPtr		xkb;

  rules = XkbRF_Load("/usr/share/X11/xkb/rules/evdev", "C", True, True);
  if (rules != NULL) {
    XkbRF_GetComponents(rules, xkb_vars, &rnames);
    xkb = XkbGetKeyboardByName(dpy, XkbUseCoreKbd, &rnames,
                               XkbGBN_AllComponentsMask,
                               XkbGBN_AllComponentsMask &
                               (~XkbGBN_GeometryMask), True);
    if (!xkb) {
      NSLog(@"[OSEKeyboard] Fialed to load new keyboard description.");
      return NO;
    }
  }
  else {
    NSLog(@"[OSEKeyboard] Failed to load XKB rules!");
  }

  XkbRF_SetNamesProp(dpy, file, xkb_vars);
  XSync(dpy, False);

  return YES;
}

// Returned value is converted to dictionary XkbRF_VarDefsRec structure.
- (NSDictionary *)_serverConfig
{
  Display 		*dpy;
  char			*file = NULL;
  XkbRF_VarDefsRec	vd;
  NSMutableDictionary	*config;

  dpy = [self _getXkbVariables:&vd file:&file];
  if (dpy == NULL) {
    return nil;
  }
  XCloseDisplay(dpy);
  
  // NSLog(@"OSEKeyboard Model: '%s'; Layouts: '%s'; Variants: '%s' Options: '%s' Rules file: %s",
  //       vd.model, vd.layout, vd.variant, vd.options, file);

  config = [NSMutableDictionary dictionary];
  [config setObject:[NSString stringWithCString:(vd.layout != NULL) ? vd.layout : ""]
             forKey:OSEKeyboardLayouts];
  [config setObject:[NSString stringWithCString:(vd.variant != NULL) ? vd.variant : ""]
             forKey:OSEKeyboardVariants];
  [config setObject:[NSString stringWithCString:(vd.options != NULL) ? vd.options : ""]
             forKey:OSEKeyboardOptions];
  [config setObject:[NSString stringWithCString:(vd.model != NULL) ? vd.model : ""]
             forKey:OSEKeyboardModel];
  
  // [config writeToFile:@"/Users/me/Library/OSEKeyboard" atomically:YES];
  
  return config;
}

- (void)dealloc
{
  if (layoutDict)  [layoutDict release];
  if (modelDict)   [modelDict release];
  if (variantDict) [variantDict release];
  if (optionDict)  [optionDict release];

  [super dealloc];
}

//------------------------------------------------------------------------------
// Model
//------------------------------------------------------------------------------
- (NSDictionary *)modelList
{
  if (!modelDict) {
    modelDict = [[NSDictionary alloc]
                    initWithDictionary:[[self _xkbBaseListDictionary]
                                         objectForKey:@"model"]];
  }

  return modelDict;
}

- (NSString *)model
{
  return [[self _serverConfig] objectForKey:OSEKeyboardModel];
}

// TODO
- (BOOL)setModel:(NSString *)name
{
  Display          *dpy;
  char             *file = NULL;
  XkbRF_VarDefsRec xkb_vars;
  BOOL             success = NO;

  dpy = [self _getXkbVariables:&xkb_vars file:&file];
  if (dpy == NULL) {
    return NO;
  }
  if (name) {
    xkb_vars.model = strdup([name cString]);
  }
  success = [self _applyServerConfig:&xkb_vars file:file forDisplay:dpy];
  XCloseDisplay(dpy);

  return success;
}

- (void)setNumLockState:(NSInteger)state
{
  Display	*dpy = XOpenDisplay(NULL);
  XkbDescPtr	xkb;
  unsigned int	mask = 0;
  char		*modifier_atom;
  
  xkb = XkbGetKeyboard(dpy, XkbAllComponentsMask, XkbUseCoreKbd);
  if (!xkb || !xkb->names) {
    return;
  }
    
  for (int i = 0; i < XkbNumVirtualMods; i++) {
    modifier_atom = XGetAtomName(xkb->dpy, xkb->names->vmods[i]);
    if (modifier_atom != NULL && strcmp("NumLock", modifier_atom) == 0) {
      XkbVirtualModsToReal(xkb, 1 << i, &mask);
      break;
    }
  }
  XkbFreeKeyboard(xkb, 0, True);
  
  if(mask == 0) {
    return;
  }

  if (state > 0) {
    XkbLockModifiers(dpy, XkbUseCoreKbd, mask, mask);
  }
  else {
    XkbLockModifiers(dpy, XkbUseCoreKbd, mask, 0);
  }
  
  XCloseDisplay(dpy);
}

//------------------------------------------------------------------------------
// Layouts and options
//------------------------------------------------------------------------------

- (NSDictionary *)availableLayouts
{
  if (!layoutDict) {
    layoutDict = [[NSDictionary alloc]
                     initWithDictionary:[[self _xkbBaseListDictionary]
                                          objectForKey:@"layout"]];
  }

  return layoutDict;
}

- (NSString *)nameForLayout:(NSString *)layoutCode
{
  if (!layoutDict) {
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
  
  if (!variantDict) {
    variantDict = [[NSDictionary alloc]
                      initWithDictionary:[[self _xkbBaseListDictionary]
                                           objectForKey:@"variant"]];
  }

  variant = [variantDict objectForKey:variantCode];
  title = [variant objectForKey:@"Description"];
  if (!title) {
    title = [variant objectForKey:@"Language"];
  }

  return title;
}

// Return list of dictionaries with keys: Layout, Desc.
- (NSDictionary *)_variantListForKey:(NSString *)field
                              value:(NSString *)value
{
  NSMutableDictionary	*layoutVariants;
  NSDictionary		*variant;
    
  if (!variantDict) {
    variantDict = [[NSDictionary alloc]
                      initWithDictionary:[[self _xkbBaseListDictionary]
                                           objectForKey:@"variant"]];
  }

  layoutVariants = [[NSMutableDictionary alloc] init];
  for (NSString *key in [variantDict allKeys]) {
    variant = [variantDict objectForKey:key];
    if ([[variant objectForKey:field] isEqualToString:value]) {
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

- (NSArray *)layouts
{
  NSString *l = [[self _serverConfig] objectForKey:OSEKeyboardLayouts];

  if (l == nil || [l isEqualToString:@""]) {
    return [NSArray arrayWithObject:@"us"];
  }

  return [l componentsSeparatedByString:@","];
}

- (NSArray *)variants
{
  NSArray  *l = [self layouts];
  NSString *v = [[self _serverConfig] objectForKey:OSEKeyboardVariants];
  NSArray  *va = [v componentsSeparatedByString:@","];

  while ([l count] > [va count]) {
    va = [va arrayByAddingObject:@""];
  }

  return va;
}

- (NSArray *)options
{
  NSString	 *optString = [[self _serverConfig] objectForKey:OSEKeyboardOptions];
  NSMutableArray *optArray;
  NSArray	 *options;

  optArray = [[optString componentsSeparatedByString:@","] mutableCopy];

  for (unsigned int i = 0; i < [optArray count]; i++) {
    if ([[optArray objectAtIndex:i] isEqualToString:@""]) {
      [optArray removeObjectAtIndex:i];
    }
  }

  options = [NSArray arrayWithArray:optArray];
  [optArray release];
  
  return options;
}

- (void)addLayout:(NSString *)lCode variant:(NSString *)vCode
{
  NSMutableArray *layouts = [[self layouts] mutableCopy];
  NSMutableArray *variants = [[self variants] mutableCopy];

  if (vCode) {
    NSInteger lc = [layouts count];
    NSInteger vc = [variants count];
          
    for (int i = 0; i < (lc - vc); i++){
      [variants addObject:@""];
    }
    [variants addObject:vCode];
  }
  else {
    [variants addObject:@""];
  }
  [layouts addObject:lCode];

  // NSLog(@"[OSEKeyboard] addLayout new config: layouts: %@ variants: %@",
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
  for (lIndex = 0; lIndex < [layouts count]; lIndex++) {
    if ([[layouts objectAtIndex:lIndex] isEqualToString:lCode] &&
        (!vCode || [vCode isEqualToString:@""] ||
         [[variants objectAtIndex:lIndex] isEqualToString:vCode])) {
      break;
    }
  }
  [layouts removeObjectAtIndex:lIndex];
  if (lIndex < [variants count]) {
    [variants removeObjectAtIndex:lIndex];
  }
  
  [self setLayouts:layouts variants:variants options:nil];
  [layouts release];
  [variants release];
}

- (BOOL)setLayouts:(NSArray *)layouts
          variants:(NSArray *)variants
           options:(NSArray *)options
{
  Display          *dpy;
  char             *file = NULL;
  XkbRF_VarDefsRec xkb_vars;
  BOOL             success = NO;

  dpy = [self _getXkbVariables:&xkb_vars file:&file];
  if (dpy == NULL) {
    return NO;
  }

  if (layouts) {
    xkb_vars.layout = strdup([[layouts componentsJoinedByString:@","] cString]);
  }
  if (variants) {
    xkb_vars.variant = strdup([[variants componentsJoinedByString:@","] cString]);
  }
  if (options) {
    xkb_vars.options = strdup([[options componentsJoinedByString:@","] cString]);
  }
  
  success = [self _applyServerConfig:&xkb_vars file:NULL forDisplay:dpy];
  XCloseDisplay(dpy);
  
  return success;
}

//------------------------------------------------------------------------------
// Initial Repeat and Repeat Rate
//------------------------------------------------------------------------------

- (void)_setXKBRepeat:(NSInteger)repeat rate:(NSInteger)rate
{
  XkbDescPtr xkb = XkbAllocKeyboard();
  Display    *dpy = XOpenDisplay(NULL);

  if (!dpy) {
    NSLog(@"Can't open Display! This program must be run in X Window.");
    return;
  }
  if (!xkb) {
    NSLog(@"No X11 XKB extension found!");
    return;
  }
  
  XkbGetControls(dpy, XkbRepeatKeysMask, xkb);
  if (repeat) {
    xkb->ctrls->repeat_delay = (int)repeat;
  }
  if (rate) {
    xkb->ctrls->repeat_interval = (int)rate;
  }
  XkbSetControls(dpy, XkbRepeatKeysMask, xkb);
  
  XCloseDisplay(dpy);
}
- (XkbDescPtr)_xkbControls
{
  XkbDescPtr xkb = XkbAllocKeyboard();
  Display    *dpy = XOpenDisplay(NULL);

  if (!dpy) {
    NSLog(@"Can't open Display! This program must be run in X Window.");
    return NULL;
  }
  if (!xkb) {
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
