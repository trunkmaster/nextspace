
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormGuidelinePref.h"

@implementation GormGuidelinePref

- (id) init
{
  if((self = [super init]) != nil)
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      int spacing = [defaults integerForKey: @"GuideSpacing"];
      NSColor *aColor = colorFromDict([defaults objectForKey: @"GuideColor"]);

      // default the color to something, if nothing is returned.
      if(aColor == nil)
	{
	  aColor = [NSColor redColor];
	}

      if ( [NSBundle loadNibNamed:@"GormPrefGuideline" owner:self] == NO )
	{
	  NSLog(@"Can not load bundle GormPrefGuideline");
	  return nil;
	} 

      [colorWell setColor: aColor];
      [spacingSlider setIntValue: spacing];
      [currentSpacing setIntValue: spacing];
      [halfSpacing setIntValue: spacing/2];

      _view =  [[window contentView] retain];
    }
  return self;
}

- (void) dealloc
{
  TEST_RELEASE(_view);
  [super dealloc];
}

-(NSView *) view
{
  return _view;
}

- (void) ok: (id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if(sender == spacingSlider)
    {
      int spacing = [spacingSlider intValue]; 

      [currentSpacing setIntValue: spacing];
      [halfSpacing setIntValue: spacing/2];
      [defaults setInteger: spacing 
		    forKey: @"GuideSpacing"];
    }
  else if(sender == colorWell)
    {
      NSColor *color = [colorWell color];
      [defaults setObject: colorToDict(color) 
		   forKey: @"GuideColor"];
    }
}

- (void) reset: (id)sender
{
  [spacingSlider setIntValue: 10];
  [colorWell setColor: [NSColor redColor]];

  [self ok: spacingSlider];
  [self ok: colorWell];
}

@end
