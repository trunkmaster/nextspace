/** @class NXIconLabel
    @brief The label used in icons.

    @author Saso Kiselkov, Sergii Stoian
*/

#import <AppKit/NSTextView.h>

@class NXIcon, NSScrollView;

@interface NXIconLabel : NSTextView
{
  NSString *oldString;
  NSString *oldString1;

  NXIcon   *icon;

  id iconLabelDelegate;
}

// Designated initializer.
- initWithFrame:(NSRect) frame
	   icon:(NXIcon *)icon;

// Tells the receiver to adjust it's frame to fit into its superview.
- (void)adjustFrame;

// Sets the delegate to whom delegate messages are passed.
- (void)setIconLabelDelegate:aDelegate;
// Returns the delegate.
- iconLabelDelegate;

 /// Returns the icon which owns the receiver.
- (NXIcon *)icon;

@end

@protocol NXIconLabelDelegate

- (void)   iconLabel:(NXIconLabel *)anIconLabel
 didChangeStringFrom:(NSString *)oldLabelString
                  to:(NSString *)newLabelString;


@end
