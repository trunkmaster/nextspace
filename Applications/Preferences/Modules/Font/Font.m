/*
	Font.m

	Controller class for this bundle

	Author: Sir Raorn <raorn@binec.ru>
	Date:	10 Aug 2002

	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License as
	published by the Free Software Foundation; either version 2 of
	the License, or (at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

	See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public
	License along with this program; if not, write to:

		Free Software Foundation, Inc.
		59 Temple Place - Suite 330
		Boston, MA  02111-1307, USA
*/
#import <math.h>

#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSData.h>

#import <AppKit/NSImage.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSTextView.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontPanel.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSOpenPanel.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSAttributedString.h>

#import "Font.h"

@interface Font (Private)

- (void) updateUI;

@end

@implementation Font (Private)

static NSBundle		   *bundle = nil;
static NSUserDefaults      *defaults = nil;
static NSMutableDictionary *domain = nil;

#define setBoolDefault(aBool,name) \
	[domain setObject:(aBool)?@"YES":@"NO" forKey:(name)]; \
	[defaults setPersistentDomain:domain forName:NSGlobalDomain]; \
	[defaults synchronize];

#define setIntDefault(anInt,name) \
	[domain setObject:[NSString stringWithFormat:@"%d", (anInt)] forKey:(name)]; \
	[defaults setPersistentDomain:domain forName:NSGlobalDomain]; \
	[defaults synchronize];

#define setFloatDefault(aFloat,name) \
	[domain setObject:[NSString stringWithFormat:@"%g", (aFloat)] forKey:(name)]; \
	[defaults setPersistentDomain:domain forName:NSGlobalDomain]; \
	[defaults synchronize];

#define setStringDefault(string,name) \
	[domain setObject:(string) forKey:(name)]; \
	[defaults setPersistentDomain:domain forName:NSGlobalDomain]; \
	[defaults synchronize];

// + userFontOfSize:		[Application Font]	<NSUserFont>
// + userFixedPitchFontOfSize: 	[Fixed Pitch Font]	<NSUserFixedPitchFont>
// + systemFontOfSize:	       	[System Font]		<NSFont>
// + boldSystemFontOfSize:     	[Bold System Font]	<NSBoldFont>
// ========================== MACOSX, GS_API_LATEST ===========================
// + toolTipsFontOfSize:	[System Font:11]	<NSToolTipsFont>
// + menuFontOfSize:		[System Font]		<NSMenuFont>
// + messageFontOfSize:		[System Font:14]	<NSMessageFont>
// + controlContentFontOfSize:	[System Font]		<NSControlContentFont>
// + labelFontOfSize:		[System Font]		<NSLabelFont>
// + titleBarFontOfSize:	[Bold System Font]	<NSTitleBarFont>
// + menuBarFontOfSize:		[Bold System Font]	<NSMenuBarFont>
// + paletteFontOfSize:		[Bold System Font]	<NSPaletteFont>
// ========================== MACOSX, GS_API_LATEST ===========================

static NSMutableDictionary *defaultValues(void)
{
  static NSMutableDictionary *dict = nil;

  if (!dict)
    {
      dict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
	@"Helvetica",		@"NSFont",
	@"Helvetica",		@"NSLabelFont",
	@"Helvetica",		@"NSMenuFont",
	@"Helvetica",		@"NSMessageFont",
	@"Helvetica-Bold",	@"NSPaletteFont",
	@"Helvetica-Bold",	@"NSTitleBarFont",
	@"Helvetica",		@"NSToolTipsFont",
	@"Helvetica",		@"NSControlContentFont",
	@"Helvetica",		@"NSUserFont",
	@"Terminus",		@"NSUserFixedPitchFont",

	[NSString stringWithFormat:@"%g", 12.0],@"NSFontSize",
	[NSString stringWithFormat:@"%g", 12.0],@"NSLabelFontSize",
	[NSString stringWithFormat:@"%g", 12.0],@"NSMenuFontSize",
	[NSString stringWithFormat:@"%g", 12.0],@"NSMessageFontSize",
	[NSString stringWithFormat:@"%g", 12.0],@"NSPaletteFontSize",
	[NSString stringWithFormat:@"%g", 12.0],@"NSTitleBarFontSize",
	[NSString stringWithFormat:@"%g", 11.0],@"NSToolTipsFontSize",
	[NSString stringWithFormat:@"%g", 12.0],@"NSControlContentFontSize",
	[NSString stringWithFormat:@"%g", 12.0],@"NSUserFontSize",
	[NSString stringWithFormat:@"%g", 12.0],@"NSUserFixedPitchFontSize",

	@"NO", @"GSFontAntiAlias",
	@"NO", @"back-art-subpixel-text",
	nil];
    }
  return dict;
}

static NSDictionary *fontCategories(void)
{
  static NSDictionary *dict = nil;

  if (!dict)
    {
      dict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   @"NSUserFont", @"Application Font",
                                   @"NSUserFixedPitchFont", @"Fixed Pitch Font",
                                   @"NSFont", @"System Font",
                                   @"NSBoldFont", @"Bold System Font",
                                   @"NSToolTipsFont", @"Tool Tips Font",
                                   nil];
    }
  return dict;
}

static BOOL getBoolDefault(NSMutableDictionary *dict, NSString *name)
{
  NSString *str = [domain objectForKey: name];
  BOOL     num;

  if (!str)
    str = [defaultValues() objectForKey: name];

  num = [str hasPrefix: @"Y"];
  [dict setObject: (num ? @"YES" : @"NO") forKey: name];

  return num;
}

static NSString *getStringDefault(NSMutableDictionary *dict, NSString *name)
{
  NSString *str = [domain objectForKey: name];

  if (!str)
    str = [defaultValues() objectForKey: name];

  [dict setObject: str forKey: name];

  return str;
}

static float getFloatDefault(NSMutableDictionary *dict, NSString *name)
{
  NSString	*sNum = [domain objectForKey: name];

  if (!sNum)
    sNum =  [defaultValues() objectForKey: name];

  [dict setObject: sNum forKey: name];

  return [sNum floatValue];
}


static int getIntDefault(NSMutableDictionary *dict, NSString *name)
{
  NSString	*sNum = [domain objectForKey: name];

  if (!sNum)
    sNum =  [defaultValues() objectForKey: name];

  [dict setObject: sNum forKey: name];

  return [sNum intValue];
}

- (void)updateUI
{
  NSString	*fontKey;
  NSString	*fontSizeKey;
  NSFont	*font, *boldFont;
  int		subpixel;

  fontKey = [fontCategories()
                objectForKey:[fontCategoryPopUp titleOfSelectedItem]];
  if (!fontKey)
    { // no selected item, bail out
      [fontNameTextField setStringValue:@"Unable to determine font type."];
      [fontExampleTextView setFont:[NSFont systemFontOfSize:12.0]];
      [view setNeedsDisplay:YES];
      return;
    }

  fontSizeKey = [NSString stringWithFormat:@"%@Size", fontKey];
  font = [NSFont fontWithName:getStringDefault(domain, fontKey)
                         size:getFloatDefault(domain, fontSizeKey)];
  boldFont = [[NSFontManager sharedFontManager] convertFont:font
                                                toHaveTrait:NSBoldFontMask];

  //
  [fontNameTextField setFont:font];
  [fontNameTextField setStringValue:[NSString stringWithFormat: @"%@ %g point",
                                              [font displayName],
                                              [font pointSize]]];

  //
  [fontExampleTextView setFont:font];
  [fontExampleTextView setFont:boldFont
                         range:NSMakeRange([normalExampleString length],
                                           [boldExampleString length]+1)];

  //
  [enableAntiAliasingButton
    setIntValue:getBoolDefault(domain,@"GSFontAntiAlias")];

  // if ((subpixel = getIntDefault(domain,@"back-art-subpixel-text")))
  //   {
  //     [enableSubpixelButton setIntValue:1];
  //   }
  // [subpixelModeButton setEnabled:(subpixel != 0)];

  // if (subpixel == 2)
  //   [subpixelModeButton setIntValue:1];

  [view setNeedsDisplay:YES];
}

@end	// Font (Private)

@implementation Font

- (id)init
{
  NSString *imagePath;
  
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];
  
  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource:@"FontPreferences" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
 
  return self;
}

- (void)awakeFromNib
{
  if (!view)
    {
      view = [[window contentView] retain];
      [view removeFromSuperview];
    }
  [window release];
  window = nil;

  exampleString = NSLocalizedStringFromTableInBundle(@"Example Text",
                                                     @"Localizable",
                                                     bundle, @"");
  normalExampleString = [[NSString alloc] initWithFormat:@"Normal:\n%@",
                                          exampleString];
  boldExampleString = [[NSString alloc] initWithFormat:@"Bold:\n%@",
                                        exampleString];
  
  [fontExampleTextView setText:[NSString stringWithFormat:@"%@\n%@",
                                         normalExampleString,
                                         boldExampleString]];
  // [fontExampleTextView
  //     readRTFDFromFile:[bundle pathForResource:@"ExampleText" ofType:@"rtf"]];

  [self updateUI];
}

- (void)dealloc
{
  NSLog(@"FontPrefs -dealloc");
  [image release];
  [normalExampleString release];
  [boldExampleString release];
  [super dealloc];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Fonts" owner:self])
        {
          NSLog(@"Font: Could not load nib \"Fonts\", aborting.");
          return nil;
        }
    }
  return view;
}

- (NSString *)buttonCaption
{
  return NSLocalizedStringFromTableInBundle(@"Font Preferences", 
					    @"Localizable", bundle, @"");
}

- (NSImage *)buttonImage
{
  // NSLog(@"Font preferences image: %@ path: %@", image, imagePath);

  return AUTORELEASE(image);
}

/*
   Action methods
*/
- (IBAction)fontCategoryChanged:(id)sender
{
  [self updateUI];
}

- (IBAction)setFont:(id)sender
{
  NSString      *fontKey;
  NSString      *fontSizeKey;
  NSFont        *font;
  NSFontManager *fontManager;
  NSFontPanel   *fontPanel;

  fontKey = [fontCategories() 
                objectForKey:[fontCategoryPopUp titleOfSelectedItem]];
  fontSizeKey = [NSString stringWithFormat:@"%@Size", fontKey];
  
  font = [NSFont fontWithName:getStringDefault(domain, fontKey)
			 size:getFloatDefault(domain, fontSizeKey)];

  fontManager = [NSFontManager sharedFontManager];
  fontPanel = [fontManager fontPanel:YES];
  [fontPanel setDelegate:self];
  [fontManager setSelectedFont:font isMultiple:NO];
  [fontPanel makeKeyAndOrderFront:self];
}

- (IBAction)enableAntiAliasingChanged:(id)sender
{
  setBoolDefault([sender intValue], @"GSFontAntiAlias");
  setIntDefault(0, @"back-art-subpixel-text");
  
  [self updateUI];
}

// UNUSED
- (IBAction)enableSubpixelChanged:(id)sender
{
  int	subpixel = 0;

  if ([enableSubpixelButton state])
    {
      subpixel++;
      [subpixelModeButton setEnabled: YES];
      if ([subpixelModeButton state])
	{
	  subpixel++;
	}
    }

  setIntDefault(subpixel, @"back-art-subpixel-text");
  [self updateUI];
}

/*
   Class methods
*/
- (void)changeFont:(id)sender
{
  NSString      *fontName, *fontKey;
  CGFloat       fontSize;
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFont        *font;

  font = [fontManager convertFont:[fontExampleTextView font]];
  fontName = [font fontName];
  fontSize = [font pointSize];
  fontKey = [fontCategories()
                objectForKey:[fontCategoryPopUp titleOfSelectedItem]];

  if ([fontKey isEqualToString:@"NSUserFont"]) // Application
    {
      // NSUserFont, NSUserFontSize=12
      setStringDefault(fontName, @"NSUserFont");
      setFloatDefault(fontSize, @"NSUserFontSize");
    }
  else if ([fontKey isEqualToString:@"NSUserFixedPitchFont"]) // Fixed Pitch
    {
      // NSUserFixedPitchFont, NSUserFixedPitchFontSize
      setStringDefault(fontName, @"NSUserFixedPitchFont");
      setFloatDefault(fontSize, @"NSUserFixedPitchFontSize");
    }
  else if ([fontKey isEqualToString:@"NSFont"]) // System
    {
      // NSFont, NSFontSize=12
      setStringDefault(fontName, @"NSFont");
      setFloatDefault(fontSize, @"NSFontSize");
      // NSMenuFont, NSMenuFontSize=12
      setStringDefault(fontName, @"NSMenuFont");
      setFloatDefault(fontSize, @"NSMenuFontSize");
      // NSMessageFont, NSMessageFontSize = NSFontSize+2
      setStringDefault(fontName, @"NSMessageFont");
      setFloatDefault(fontSize+2.0, @"NSMessageFontSize");
      // NSControlContentFont, NSControlContentFontSize=12
      setStringDefault(fontName, @"NSControlContentFont");
      setFloatDefault(fontSize, @"NSControlContentFontSize");
      // NSLabelFont, NSLabelFontSize=12
      setStringDefault(fontName, @"NSLabelFont");
      setFloatDefault(fontSize, @"NSLabelFontSize");
      // NSMiniFontSize=9, NSSmallFontSize=11
      setFloatDefault(9.0, @"NSMiniFontSize");
      setFloatDefault(11.0, @"NSSmallFontSize");
    }
  else if ([fontKey isEqualToString:@"NSBoldFont"]) // Bold System
    {
      // NSBoldFont, NSBoldFontSize=12
      setStringDefault(fontName, @"NSBoldFont");
      setFloatDefault(fontSize, @"NSBoldFontSize");
      // NSTitleBarFont, NSTitleBarFontSize=12
      setStringDefault(fontName, @"NSTitleBarFont");
      setFloatDefault(fontSize, @"NSTitleBarFontSize");
      // NSMenuBarFont
      setStringDefault(fontName, @"NSMenuBarFont");
      // NSPaletteFont, NSPaletteFontSize=12
      setStringDefault(fontName, @"NSPaletteFont");
      setFloatDefault(fontSize, @"NSPaletteFontSize");
    }
  else if ([fontKey isEqualToString:@"NSToolTipsFont"]) // Tool Tips
    {
      // NSToolTipsFont, NSToolTipsFontSize=11
      setStringDefault(fontName, @"NSToolTipsFont");
      setFloatDefault(fontSize, @"NSToolTipsFontSize");
    }

  [self updateUI];
}

@end	// Font
