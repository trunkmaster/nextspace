/* All Rights reserved */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class ALSAElementsView;

@interface ALSA : NSObject
{
  NSWindow          *window;
  NSPopUpButton	    *cardsList;
  NSPopUpButton	    *viewMode;
  
  NSScrollView     *elementsScroll;
  ALSAElementsView *elementsView;

  NSMutableArray   *elementsList; // FIXME: remove this and _enumerate* methods
}

- (void)showPanel;

@end
