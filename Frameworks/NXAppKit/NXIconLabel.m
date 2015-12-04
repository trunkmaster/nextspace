/** 
    @class NXIconLabel
    @brief The label used in icons.
    
    @author Saso Kiselkov, Sergii Stoian
*/

#include <math.h>
#import <AppKit/AppKit.h>

#import "NXIconLabel.h"
#import "NXIcon.h"

#define TEXT_PADDING 7.0

@implementation NXIconLabel

- (void)dealloc
{
  TEST_RELEASE(oldString);

  [super dealloc];
}

- initWithFrame:(NSRect)frame
	   icon:(NXIcon *)anIcon
{
  [super initWithFrame:frame];

  [self setDelegate:self];
  icon = anIcon;
  [self setAlignment:NSCenterTextAlignment];
  [self setTextContainerInset:NSMakeSize(0,0)];
  [self setVerticallyResizable:NO];

  return self;
}

- (void)textDidBeginEditing:(NSNotification*)notification
{
  DESTROY(oldString);
  oldString = [[self string] copy];
}

- (void)textDidChange:(NSNotification *)notif
{
  // [self adjustFrame];
}

- (void)textDidEndEditing:(NSNotification *)notif
{
  NSString *newString = [NSString stringWithString:[self string]];

  [self setSelectedRange:NSMakeRange(0,0)];

  if (oldString == nil || [oldString isEqualToString:newString])
    {
      return;
    }

  if ([iconLabelDelegate respondsToSelector:
	@selector(iconLabel:didChangeStringFrom:to:)])
    {
      oldString1 = [NSString stringWithString:oldString];

      DESTROY(oldString);
      oldString = [newString copy];
      [iconLabelDelegate iconLabel:self
	       didChangeStringFrom:oldString1
				to:newString];
    }
}

- (void)adjustFrame
{
  NSView *superview = [self superview];

  if (superview != nil)
    {
      float  stringWidth = [[self font] widthOfString:[self string]];
      NSRect frame = [self frame];
      NSRect superFrame = [superview frame];
      NSRect iconFrame = [icon frame];

     // NSLog(@"NXIconLabel: sizes: (%@)%.0fx%.0f (%@)%.0fx%.0f (%@)%.0fx%.0f",
     //        [superview className], 
     //        superFrame.size.width, superFrame.size.height,
     //        [icon className], 
     //        iconFrame.size.width, iconFrame.size.height,
     //        [self className], 
     //        frame.size.width, frame.size.height);

      // Y-position
      if ([superview isFlipped])
	{
	  frame.origin.y = 
	    roundf(iconFrame.origin.y + iconFrame.size.height);
	}
      else
	{
	  frame.origin.y = iconFrame.origin.y - frame.size.height;
	}

      // Width of label
      if (stringWidth == 0)
	{
	  // empty string?
	  frame.size.width = TEXT_PADDING;
	}
      else if ((stringWidth + (TEXT_PADDING * 2)) >= superFrame.size.width)
	{
	  frame.size.width = superFrame.size.width - 6; // FIXME:6?
	}
      else
	{
	  frame.size.width = stringWidth + (TEXT_PADDING * 2);
	}

      // X-position
      frame.origin.x = floorf([icon frame].origin.x) + 
	roundf(([icon frame].size.width - frame.size.width)/2);
      if (frame.origin.x < 0)
	{
	  frame.origin.x = 0;
	}
      else if (frame.origin.x + frame.size.width > superFrame.size.width - 5)
	{
	  frame.origin.x = superFrame.size.width - frame.size.width - 5;
	}

      [self setFrame:frame];
      // TODO: redraw only superview rectangle around icon
      [[self superview] setNeedsDisplay:YES];
    }
}

- (void)keyDown:(NSEvent *)ev
{
  if ([[ev characters] isEqualToString:@"\r"] || // Return
      [[ev characters] isEqualToString:@"\t"])   // Tab
    {
      [_window makeFirstResponder:[self nextKeyView]];
    }
  else
    {
      [super keyDown:ev];
    }

  [self adjustFrame];
}

- (NXIcon *)icon
{
  return icon;
}

- (void)setIconLabelDelegate:aDelegate
{
  iconLabelDelegate = aDelegate;
}

- iconLabelDelegate
{
  return iconLabelDelegate;
}

@end
