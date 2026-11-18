/*
  Preferences.m
  Copyright (c) 1995-1996, NeXT Software, Inc.
  All rights reserved.
  Author: Ali Ozer

  You may freely copy, distribute and reuse the code in this example.
  NeXT disclaims any warranty of any kind, expressed or implied,
  as to its fitness for any particular use.

  Preferences controller for Edit...

  To add new defaults search for one of the existing keys. Some keys have
  UI, others don't; use one similar to the one you're adding.

  displayedValues is a mirror of the UI. These are committed by copying
  these values to curValues.

  This module allows for UI where there is or there isn't an OK button.
  If you wish to have an OK button, connect OK to ok:, Revert to revert:,
  and don't call commitDisplayedValues from the various action messages.
*/

#import "Preferences.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

static NSDictionary *defaultValues (void)
{
  static NSDictionary *dict = nil;
  if (!dict) {
    dict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               [NSNumber numberWithBool:YES], DeleteBackup, 
                               [NSNumber numberWithBool:NO], SaveFilesWritable, 
                               [NSNumber numberWithBool:YES], RichText, 
                               [NSNumber numberWithBool:NO], ShowPageBreaks,
                               [NSNumber numberWithBool:NO], OpenPanelFollowsMainWindow,
				[NSNumber numberWithInt:80], WindowWidth, 
				[NSNumber numberWithInt:30], WindowHeight, 
				[NSNumber numberWithInt:UnknownStringEncoding], PlainTextEncoding,
				[NSNumber numberWithInt:8], TabWidth,
				[NSNumber numberWithInt:100000], ForegroundLayoutToIndex,		
                       [NSFont userFixedPitchFontOfSize:0.0], PlainTextFont, 
                                 [NSFont userFontOfSize:0.0], RichTextFont, 
                                 nil];
  }
  return dict;
}

@implementation Preferences

static Preferences *sharedInstance = nil;

+ (id)objectForKey:(id)key
{
  return [[[self sharedInstance] preferences] objectForKey:key];
}

+ (void)saveDefaults
{
  if (sharedInstance) {
    [Preferences savePreferencesToDefaults:[sharedInstance preferences]];
  }
}

+ (Preferences *)sharedInstance
{
  return sharedInstance ? sharedInstance : [[self alloc] init];
}

- (id)init
{
  if (sharedInstance) {
    [self dealloc];
  } 
  else {
    [super init];
    curValues = [[[self class] preferencesFromDefaults] copy];
    [self discardDisplayedValues];
    sharedInstance = self;
  }
  return sharedInstance;
}

- (void)dealloc
{
  [super dealloc];
}

- (NSDictionary *)preferences
{
  return curValues;
}

- (void)showPanel:(id)sender
{
  if (!richTextFontNameField) {
    if (![NSBundle loadNibNamed:@"Preferences" owner:self]) {
      NSLog(@"Failed to load Preferences.nib");
      NSBeep();
      return;
    }
    [[richTextFontNameField window] setExcludedFromWindowsMenu:YES];
    [[richTextFontNameField window] setMenu:nil];
    [self updateUI];
    [[richTextFontNameField window] center];
  }
  [[richTextFontNameField window] makeKeyAndOrderFront:nil];
}

- (void)awakeFromNib
{
  [deleteBackupMatrix setRefusesFirstResponder:YES];
  [saveFilesWritableButton setRefusesFirstResponder:YES];
  [richTextMatrix setRefusesFirstResponder:YES];
  [richTextFontNameField setRefusesFirstResponder:YES];
  [plainTextFontNameField setRefusesFirstResponder:YES];
  [plainTextEncodingPopup setRefusesFirstResponder:YES];
}

static void showFontInField(NSFont *font, NSTextField *field)
{
  NSString *fontName = @"";
  
  if (font) {
    fontName = [NSString stringWithFormat:@"%@ %g",
                         [font fontName], [font pointSize]];
  }
  
  [field setStringValue:fontName];
}

- (void)updateUI
{
  showFontInField([displayedValues objectForKey:RichTextFont], richTextFontNameField);
  showFontInField ([displayedValues objectForKey:PlainTextFont], plainTextFontNameField);
  [deleteBackupMatrix selectCellWithTag:[[displayedValues objectForKey:DeleteBackup] boolValue] ? 1 : 0];
  [saveFilesWritableButton setState: [[displayedValues objectForKey: SaveFilesWritable] boolValue]];
  [richTextMatrix selectCellWithTag: [[displayedValues objectForKey: RichText] boolValue] ? 1 : 0];
  [showPageBreaksButton setState: [[displayedValues objectForKey: ShowPageBreaks] boolValue]];

  [windowWidthField setIntValue: [[displayedValues objectForKey: WindowWidth] intValue]];
  [windowHeightField setIntValue: [[displayedValues objectForKey: WindowHeight] intValue]];

  SetUpEncodingPopupButton(plainTextEncodingPopup, [[displayedValues objectForKey:PlainTextEncoding] intValue], YES);
}

/* Gets everything from UI except for fonts... */
- (void)miscChanged:(id)sender
{
  static NSNumber	*yes = nil;
  static NSNumber	*no = nil;
  int			anInt;
	
  if (!yes) {
    yes = [[NSNumber alloc] initWithBool:YES];
    no = [[NSNumber alloc] initWithBool:NO];
  }

  [displayedValues setObject:([[deleteBackupMatrix selectedCell] tag] ? yes : no)
                      forKey:DeleteBackup];
  [displayedValues setObject:([[richTextMatrix selectedCell] tag] ? yes : no)
                      forKey:RichText];
  [displayedValues setObject:([saveFilesWritableButton state] ? yes : no)
                      forKey:SaveFilesWritable];
  [displayedValues setObject:([showPageBreaksButton state] ? yes : no)
                      forKey:ShowPageBreaks];
  [displayedValues setObject:[NSNumber numberWithInt:[[plainTextEncodingPopup selectedItem] tag]]
                      forKey:PlainTextEncoding];

  anInt = [windowWidthField intValue];
  if (anInt < 1 || anInt > 10000) {
    anInt = [[displayedValues objectForKey:WindowWidth] intValue];
    if (anInt < 1 || anInt > 10000)
      anInt = [[defaultValues() objectForKey:WindowWidth] intValue];
    [windowWidthField setIntValue:anInt];
  } else {
    [displayedValues setObject:[NSNumber numberWithInt:anInt]
                        forKey:WindowWidth];
  }

  anInt = [windowHeightField intValue];
  if (anInt < 1 || anInt > 10000) {
    anInt = [[displayedValues objectForKey:WindowHeight] intValue];
    if (anInt < 1 || anInt > 10000)
      anInt = [[defaultValues() objectForKey:WindowHeight] intValue];
    [windowHeightField setIntValue:[[displayedValues objectForKey:WindowHeight] intValue]];
  } else {
    [displayedValues setObject:[NSNumber numberWithInt:anInt]
                        forKey:WindowHeight];
  }

  [self commitDisplayedValues];
}

/**** Font changing code ****/

static BOOL changingRTFFont = NO;

- (void)changeRichTextFont:(id)sender
{
  changingRTFFont = YES;
  [[NSFontManager sharedFontManager] setDelegate:self];
  [[richTextFontNameField window] makeFirstResponder:[richTextFontNameField window]];
  [[NSFontManager sharedFontManager] setSelectedFont:[curValues objectForKey:RichTextFont] isMultiple:NO];
  [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (void)changePlainTextFont:(id)sender
{
  changingRTFFont = NO;
  [[NSFontManager sharedFontManager] setDelegate:self];
  [[richTextFontNameField window] makeFirstResponder:[richTextFontNameField window]];
  [[NSFontManager sharedFontManager] setSelectedFont:[curValues objectForKey:PlainTextFont] isMultiple:NO];
  [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (void)changeFont:(id)fontManager
{
  if (changingRTFFont) {
    [displayedValues setObject:[fontManager convertFont:[curValues objectForKey:RichTextFont]]
                        forKey:RichTextFont];
    showFontInField ([displayedValues objectForKey: RichTextFont], richTextFontNameField);
  } else {
    [displayedValues setObject:[fontManager convertFont:[curValues objectForKey:PlainTextFont]]
                        forKey:PlainTextFont];
    showFontInField ([displayedValues objectForKey: PlainTextFont], plainTextFontNameField);
  }
  [self commitDisplayedValues];

	[[NSFontPanel sharedFontPanel] orderOut:self];
}

/**** Commit/revert etc ****/

- (void)commitDisplayedValues
{
  if (curValues != displayedValues) {
    [curValues release];
    curValues = [displayedValues copy];
  }
}

- (void)discardDisplayedValues
{
  if (curValues != displayedValues) {
    [displayedValues release];
    displayedValues = [curValues mutableCopy];
    [self updateUI];
  }
}

- (void)ok:(id)sender
{
  [self commitDisplayedValues];
  [Preferences saveDefaults];
}

- (void)revertToDefault:(id)sender
{
  curValues = [defaultValues() copy];
  [self discardDisplayedValues];
}

- (void)revert:(id)sender
{
  [self discardDisplayedValues];
}

/**** Code to deal with defaults ****/
   
#define getBoolDefault(name) \
  {NSString *str = [defaults stringForKey:name]; \
	  [dict setObject:str ? [NSNumber numberWithBool:[str hasPrefix:@"Y"]] : [defaultValues() objectForKey:name] forKey:name];}

#define getIntDefault(name) \
  {NSString *str = [defaults stringForKey:name]; \
	  [dict setObject:str ? [NSNumber numberWithInt:[str intValue]] : [defaultValues() objectForKey:name] forKey:name];}

+ (NSDictionary *) preferencesFromDefaults
{
	NSUserDefaults		*defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary	*dict = [NSMutableDictionary dictionaryWithCapacity: 10];

	getBoolDefault (RichText);
	getBoolDefault (DeleteBackup);
	getBoolDefault (ShowPageBreaks);
	getBoolDefault (SaveFilesWritable);
	getBoolDefault (OpenPanelFollowsMainWindow);
	getIntDefault (WindowWidth);
	getIntDefault (WindowHeight);
	getIntDefault (PlainTextEncoding);
	getIntDefault (TabWidth);
	getIntDefault (ForegroundLayoutToIndex);
	[dict setObject: [NSFont userFontOfSize: 0.0] forKey: RichTextFont];
	[dict setObject: [NSFont userFixedPitchFontOfSize: 0.0] forKey: PlainTextFont];

	return dict;
}

#define setBoolDefault(name) \
  {if ([[defaultValues() objectForKey:name] isEqual:[dict objectForKey:name]]) [defaults removeObjectForKey:name]; else [defaults setBool:[[dict objectForKey:name] boolValue] forKey:name];}

#define setIntDefault(name) \
  {if ([[defaultValues() objectForKey:name] isEqual:[dict objectForKey:name]]) [defaults removeObjectForKey:name]; else [defaults setInteger:[[dict objectForKey:name] intValue] forKey:name];}

+ (void) savePreferencesToDefaults: (NSDictionary *)dict
{
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];

	setBoolDefault (RichText);
	setBoolDefault (DeleteBackup);
	setBoolDefault (ShowPageBreaks);
	setBoolDefault (SaveFilesWritable);
	setBoolDefault (OpenPanelFollowsMainWindow);
	setIntDefault (WindowWidth);
	setIntDefault (WindowHeight);
	setIntDefault (PlainTextEncoding);
	setIntDefault (TabWidth);
	setIntDefault (ForegroundLayoutToIndex);
	if (![[dict objectForKey: RichTextFont] isEqual: [NSFont userFontOfSize: 0.0]])
		[NSFont setUserFont: [dict objectForKey: RichTextFont]];
	if (![[dict objectForKey: PlainTextFont] isEqual: [NSFont userFixedPitchFontOfSize: 0.0]])
		[NSFont setUserFixedPitchFont: [dict objectForKey: PlainTextFont]];

        [defaults synchronize];
}

@end

/*

10/24/95 aozer	Created.

*/
