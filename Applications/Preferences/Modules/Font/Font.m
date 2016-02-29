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

static NSMutableDictionary * defaultValues (void)
{
  static NSMutableDictionary *dict = nil;

  if (!dict)
    {
      dict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
	@"Helvetica",            @"NSFont",
	@"Helvetica",            @"NSLabelFont",
	@"Helvetica",            @"NSMenuFont",
	@"Helvetica",            @"NSMessageFont",
	@"Helvetica-Bold",       @"NSPaletteFont",
	@"Helvetica-Bold",       @"NSTitleBarFont",
	@"Helvetica",            @"NSToolTipsFont",
	@"Helvetica",            @"NSControlContentFont",
	@"Helvetica",            @"NSUserFont",
	@"DejaVuSansMono-Roman", @"NSUserFixedPitchFont",

	[NSString stringWithFormat: @"%g", 12.0],@"NSFontSize",
	[NSString stringWithFormat: @"%g", 12.0],@"NSLabelFontSize",
	[NSString stringWithFormat: @"%g", 12.0],@"NSMenuFontSize",
	[NSString stringWithFormat: @"%g", 12.0],@"NSMessageFontSize",
	[NSString stringWithFormat: @"%g", 12.0],@"NSPaletteFontSize",
	[NSString stringWithFormat: @"%g", 12.0],@"NSTitleBarFontSize",
	[NSString stringWithFormat: @"%g", 10.0],@"NSToolTipsFontSize",
	[NSString stringWithFormat: @"%g", 12.0],@"NSControlContentFontSize",
	[NSString stringWithFormat: @"%g", 12.0],@"NSUserFontSize",
	[NSString stringWithFormat: @"%g", 12.0],@"NSUserFixedPitchFontSize",

	@"NO", @"GSFontAntiAlias",
	@"NO", @"back-art-subpixel-text",
	nil];
    }
  return dict;
}

static NSArray * fontCategories (void)
{
  static NSArray *arr = nil;

  if (!arr)
    {
      arr = [[NSArray alloc] initWithObjects:
	@"Application Font",
	@"Label Font",
	@"Menu Font",
	@"Message Font",
	@"Palette Font",
	@"Title Bar Font",
	@"ToolTip Font",
	@"Control Content Font",
	@"User Font",
	@"User Fixed-Pitch Font",
	nil];
    }
  return arr;
}

static NSDictionary * fontCategoryNames (void)
{
  static NSDictionary *dict = nil;

  if (!dict)
    {
      dict = [[NSDictionary alloc] initWithObjectsAndKeys:
	@"NSFont", @"Application Font",
	@"NSLabelFont", @"Label Font",
	@"NSMenuFont", @"Menu Font",
	@"NSMessageFont", @"Message Font",
	@"NSPaletteFont", @"Palette Font",
	@"NSTitleBarFont", @"Title Bar Font",
	@"NSToolTipsFont", @"ToolTip Font",
	@"NSControlContentFont", @"Control Content Font",
	@"NSUserFont", @"User Font",
	@"NSUserFixedPitchFont", @"User Fixed-Pitch Font",
	nil];
    }
  return dict;
}

static BOOL
getBoolDefault (NSMutableDictionary *dict, NSString *name)
{
  NSString *str = [domain objectForKey: name];
  BOOL     num;

  if (!str)
    str = [defaultValues() objectForKey: name];

  num = [str hasPrefix: @"Y"];
  [dict setObject: (num ? @"YES" : @"NO") forKey: name];

  return num;
}

static NSString *
getStringDefault (NSMutableDictionary *dict, NSString *name)
{
  NSString *str = [domain objectForKey: name];

  if (!str)
    str = [defaultValues() objectForKey: name];

  [dict setObject: str forKey: name];

  return str;
}

static float
getFloatDefault (NSMutableDictionary *dict, NSString *name)
{
  NSString	*sNum = [domain objectForKey: name];

  if (!sNum)
    sNum =  [defaultValues() objectForKey: name];

  [dict setObject: sNum forKey: name];

  return [sNum floatValue];
}


static int
getIntDefault (NSMutableDictionary *dict, NSString *name)
{
  NSString	*sNum = [domain objectForKey: name];

  if (!sNum)
    sNum =  [defaultValues() objectForKey: name];

  [dict setObject: sNum forKey: name];

  return [sNum intValue];
}

- (void) updateUI
{
  NSString	*fontKey;
  NSString	*fontSizeKey;
  NSFont	*font;
  int		subpixel;

  fontKey = [fontCategoryNames() objectForKey: [fontCategoryPopUp titleOfSelectedItem]];
  if (!fontKey)
    { // no selected item, bail out
      [fontNameTextField setStringValue: @"No font (?!?!?)"];
      [fontExampleTextView setFont: [NSFont systemFontOfSize: 12.0]];
      [view setNeedsDisplay: YES];
      return;
    }

  fontSizeKey = [NSString stringWithFormat: @"%@Size", [fontCategoryNames() objectForKey: [fontCategoryPopUp titleOfSelectedItem]]];
  font = [NSFont fontWithName: getStringDefault(domain, fontKey) size: getFloatDefault(domain, fontSizeKey)];

  [fontNameTextField setStringValue: [NSString stringWithFormat: @"%@ %g point",
    [font displayName],
    [font pointSize]]];

  [fontExampleTextView setFont: font];

  [enableAntiAliasingButton setIntValue: getBoolDefault(domain, @"GSFontAntiAlias")];

  if ((subpixel = getIntDefault(domain, @"back-art-subpixel-text"))) {
      [enableSubpixelButton setIntValue: 1];
  }
  [subpixelModeButton setEnabled: (subpixel != 0)];

  if (subpixel == 2)
    [subpixelModeButton setIntValue: 1];

  [view setNeedsDisplay: YES];
}

@end	// Font (Private)

@implementation Font

- (id) init
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
      [window setContentView: NULL];
    }
  [window release];
  window = nil;

  // set up the popup
  [fontCategoryPopUp removeAllItems];
  [fontCategoryPopUp addItemsWithTitles: fontCategories()];
  [fontCategoryPopUp selectItemAtIndex: 0];

  [fontNameTextField setBackgroundColor: [NSColor controlColor]];
  [fontNameTextField setDrawsBackground: YES];

  [fontExampleScrollView setHasHorizontalScroller: NO];
  [fontExampleScrollView setHasVerticalScroller: YES];
  [fontExampleScrollView setBorderType: NSBezelBorder];

  if (!fontExampleTextView)
    {
      NSRect frame;

      frame.origin.x = frame.origin.y = 0;
      frame.size = [fontExampleScrollView contentSize];

      fontExampleTextView = [[NSTextView alloc] initWithFrame: frame];
      [fontExampleTextView setBackgroundColor: [NSColor controlColor]];
      [fontExampleTextView setEditable: NO];
      [fontExampleTextView setSelectable: NO];
      [fontExampleTextView setText:NSLocalizedStringFromTableInBundle (@"Example Text", @"Localizable", bundle, @"")];

      [fontExampleScrollView setDocumentView: fontExampleTextView];
    }

  [self updateUI];
}

- (void)dealloc
{
  NSLog(@"FontPrefs -dealloc");
  [image release];
  [super dealloc];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Fonts" owner:self])
        {
          NSLog (@"Font: Could not load nib \"Fonts\", aborting.");
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
- (IBAction) fontCategoryChanged: (id)sender
{
  [self updateUI];
}

- (IBAction) fontSetPushed: (id)sender
{
  NSString    *fontKey;
  NSString    *fontSizeKey;
  NSFont      *font;
//  NSFontPanel *fontPanel;
  NSFontManager *fontManager = [NSFontManager sharedFontManager];

  fontKey = [fontCategoryNames() 
                objectForKey:[fontCategoryPopUp titleOfSelectedItem]];
  fontSizeKey = [NSString stringWithFormat:@"%@Size", [fontCategoryNames() objectForKey:[fontCategoryPopUp titleOfSelectedItem]]];

  font = [NSFont fontWithName:getStringDefault(domain, fontKey)
			 size:getFloatDefault(domain, fontSizeKey)];

//  fontPanel = [NSFontPanel sharedFontPanel];
//  [fontPanel orderFront: self];
  [fontManager setSelectedFont:font isMultiple:NO];
  [fontManager orderFrontFontPanel:self];
}

- (IBAction) enableAntiAliasingChanged: (id)sender
{
  setBoolDefault([sender intValue], @"GSFontAntiAlias");
  [self updateUI];
}

- (IBAction) enableSubpixelChanged: (id)sender
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
- (void) changeFont: (id)sender
{
  NSString      *fontKey;
  NSString      *fontSizeKey;
//  NSFontManager *fontManager = (NSFontManager *)sender;
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFont        *font;

/*  NSLog(@">>>chageFont %@", sender);

  if (sender == nil)
    {
      NSLog(@"changeFont: sender == nil");
      return;
    }
  else if (![sender isKindOfClass:[NSFontManager class]])
    {
      NSLog(@"changeFont: sender != NSFontManager");
      return;
    }

  NSLog(@"changeFont: %@", [sender className]);*/

  font = [fontManager convertFont:[fontExampleTextView font]];

  fontKey = [fontCategoryNames() objectForKey: [fontCategoryPopUp titleOfSelectedItem]];
  fontSizeKey = [NSString stringWithFormat: @"%@Size", fontKey];

  setStringDefault([font fontName], fontKey);
  setFloatDefault([font pointSize], fontSizeKey);

  if ([fontKey isEqualToString: @"NSFont"])
    {
      // small
      fontKey = @"NSSmallFont";
      fontSizeKey = @"NSSmallFontSize";

      setStringDefault([font fontName], fontKey);
      setFloatDefault(rintf([font pointSize] * 0.75), fontSizeKey);

      // bold
      fontKey = @"NSBoldFont";
      fontSizeKey = @"NSBoldFontSize";

      font = [fontManager convertFont:font toHaveTrait:NSBoldFontMask];
      setStringDefault([font fontName], fontKey);
      setFloatDefault([font pointSize], fontSizeKey);
  }

  [self updateUI];
}

@end	// Font
