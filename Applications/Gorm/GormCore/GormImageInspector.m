/* All rights reserved */

#include <AppKit/AppKit.h>

#include "GormImageInspector.h"
#include "GormPrivate.h"
#include "GormImage.h"

@implementation GormImageInspector
+ (void) initialize
{
  if (self == [GormImageInspector class])
    {
    }
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      // load the gui...
      if (![bundle loadNibNamed: @"GormImageInspector"
			  owner: self
		topLevelObjects: NULL])
	{
	  NSLog(@"Could not open gorm GormImageInspector");
	  return nil;
	}
      else
	{
	  [[NSNotificationCenter defaultCenter] 
	    addObserver: self
	    selector: @selector(handleNotification:)
	    name: IBSelectionChangedNotification
	    object: nil];
	}
    }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [super dealloc];
}

- (void) handleNotification: (NSNotification*)aNotification
{
}

- (void) setObject: (id)anObject
{
  NSImage *image = [anObject normalImage];
  NSSize size = [image size];

  [super setObject: anObject];
  [imageView setImageAlignment: NSImageAlignCenter];
  [imageView setImageFrameStyle: NSImageFrameGrayBezel];
  [imageView setImageScaling: NSScaleNone];
  [imageView setImage: [anObject image]];
  [name setStringValue: [image name]];
  [width setDoubleValue: size.width];
  [height setDoubleValue: size.height];
}
@end
