#import <AppKit/NSScrollView.h>

@class NSPopUpButton;

@interface ScalingScrollView : NSScrollView {
    NSPopUpButton *_scalePopUpButton;
    float scaleFactor;
}

- (void)scalePopUpAction:(id)sender;
- (void)_makeScalePopUpButton;
- (void)setScaleFactor:(float)factor;
- (float)scaleFactor;

@end
