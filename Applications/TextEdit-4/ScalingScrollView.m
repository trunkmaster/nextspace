/*
		ScalingScrollView.m
		Copyright (c) 1995-1996, NeXT Software, Inc.
		All rights reserved.
		Author: Mike Ferris

		You may freely copy, distribute and reuse the code in this example.
		NeXT disclaims any warranty of any kind, expressed or implied,
		as to its fitness for any particular use.
*/

#import "ScalingScrollView.h"

#import <Foundation/Foundation.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSButtonCell.h>
#import <AppKit/NSFont.h>

/* For genstrings:
	NSLocalizedString(@"10%", @"Zoom popup entry")
	NSLocalizedString(@"25%", @"Zoom popup entry")
	NSLocalizedString(@"50%", @"Zoom popup entry")
	NSLocalizedString(@"75%", @"Zoom popup entry")
	NSLocalizedString(@"100%", @"Zoom popup entry")
	NSLocalizedString(@"128%", @"Zoom popup entry")
	NSLocalizedString(@"200%", @"Zoom popup entry")
	NSLocalizedString(@"400%", @"Zoom popup entry")
	NSLocalizedString(@"800%", @"Zoom popup entry")
	NSLocalizedString(@"1600%", @"Zoom popup entry")
*/
static NSString *_NSDefaultScaleMenuLabels[] = {/* @"Set...", */ @"10%", @"25%", @"50%", @"75%", @"100%", @"128%", @"200%", @"400%", @"800%", @"1600%"};
static float _NSDefaultScaleMenuFactors[] = {/* 0.0, */ 0.1, 0.25, 0.5, 0.75, 1.0, 1.28, 2.0, 4.0, 8.0, 16.0};
static unsigned _NSDefaultScaleMenuSelectedItemIndex = 4;
static float _NSButtonPadding = 1.0;
static float _NSScaleMenuFontSize = 10.0;

@implementation ScalingScrollView

- (id) initWithFrame: (NSRect)rect
{
	if ((self = [super initWithFrame: rect])) {
		scaleFactor = 1.0;
		// FIXME -- was in alex's version -- why?
		[self setHasHorizontalRuler: YES];
	}
	return self;
}

- (void) _makeScalePopUpButton
{
	if (_scalePopUpButton == nil) {
		unsigned int	cnt, numberOfDefaultItems = (sizeof(_NSDefaultScaleMenuLabels) / sizeof(NSString *));
#ifdef GNUSTEP
		id <NSMenuItem> curItem;
#else
		NSButtonCell	*curItem;
#endif

		// create it
		_scalePopUpButton = [[NSPopUpButton allocWithZone: [self zone]] initWithFrame: NSMakeRect (0.0, 0.0, 1.0, 1.0) pullsDown: NO];

		// fill it
		for (cnt = 0; cnt < numberOfDefaultItems; cnt++) {
			[_scalePopUpButton addItemWithTitle: NSLocalizedString (_NSDefaultScaleMenuLabels[cnt], nil)];
			curItem = [_scalePopUpButton itemAtIndex:cnt];

			if (_NSDefaultScaleMenuFactors[cnt] != 0.0) {
				[curItem setRepresentedObject: [NSNumber numberWithFloat: _NSDefaultScaleMenuFactors[cnt]]];
			}
		}
		[_scalePopUpButton selectItemAtIndex: _NSDefaultScaleMenuSelectedItemIndex];

		// hook it up
		[_scalePopUpButton setTarget: self];
		[_scalePopUpButton setAction: @selector(scalePopUpAction:)];

		// set a suitable font
		[_scalePopUpButton setFont: [NSFont systemFontOfSize: _NSScaleMenuFontSize]];

		// Make sure the popup is big enough to fit the cells.
		[_scalePopUpButton sizeToFit];

		// don't let it become first responder
		[_scalePopUpButton setRefusesFirstResponder: YES];

		// put it in the scrollview
		[self addSubview: _scalePopUpButton];
		[_scalePopUpButton release];
	}
}

- (void) tile
{
	// Let the superclass do most of the work.
	[super tile];

	if (![self hasHorizontalScroller]) {
		if (_scalePopUpButton) [_scalePopUpButton removeFromSuperview];
		_scalePopUpButton = nil;
	} else {
		NSScroller *horizScroller;
		NSRect horizScrollerFrame, buttonFrame, incrementLineFrame;
		
		if (!_scalePopUpButton) [self _makeScalePopUpButton];

		horizScroller = [self horizontalScroller];
		horizScrollerFrame = [horizScroller frame];
		incrementLineFrame = [horizScroller rectForPart:NSScrollerIncrementLine];
		buttonFrame = [_scalePopUpButton frame];

		// Now we'll just adjust the horizontal scroller size and set the button size and location.
		horizScrollerFrame.size.width = horizScrollerFrame.size.width - buttonFrame.size.width - _NSButtonPadding;
		[horizScroller setFrameSize:horizScrollerFrame.size];

		buttonFrame.origin.x = NSMaxX(horizScrollerFrame);
		buttonFrame.size.height = incrementLineFrame.size.height;
		buttonFrame.origin.y = horizScrollerFrame.origin.y + incrementLineFrame.origin.y;
		[_scalePopUpButton setFrame:buttonFrame];
	}
}

- (void) scalePopUpAction: (id)sender
{
#ifdef GNUSTEP
	NSNumber *selectedFactorObject = [[_scalePopUpButton selectedItem] representedObject];
#else
	NSNumber *selectedFactorObject = [[sender selectedCell] representedObject];
#endif
	
	if (selectedFactorObject == nil) {
		NSLog (@"Scale popup action: setting arbitrary zoom factors is not yet supported.");
		return;
	} else {
		[self setScaleFactor: [selectedFactorObject floatValue]];
	}
}

- (float) scaleFactor
{
	return scaleFactor;
}

- (void) setScaleFactor: (float)newScaleFactor
{
	if (scaleFactor != newScaleFactor) {
		NSSize curDocFrameSize, newDocBoundsSize;
		NSView *clipView = [[self documentView] superview];
		
		scaleFactor = newScaleFactor;
		
		// Get the frame.  The frame must stay the same.
		curDocFrameSize = [clipView frame].size;
		
		// The new bounds will be frame divided by scale factor
		newDocBoundsSize.width = curDocFrameSize.width / newScaleFactor;
		newDocBoundsSize.height = curDocFrameSize.height / newScaleFactor;
		
		[clipView setBoundsSize:newDocBoundsSize];
	}
}

- (void) setHasHorizontalScroller: (BOOL) flag
{
	if (!flag)
		[self setScaleFactor: 1.0];

	[super setHasHorizontalScroller: flag];
}

@end

/*

 12/94 mferris	Created
 3/4/95 aozer	Use in Edit; added ability to turn popup off/on
 5/4/95 aozer	Scale the clipview rather than the docview
 7/20/95 aozer	Made popup entries localizable

*/
