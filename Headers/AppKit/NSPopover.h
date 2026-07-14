/*
   NSPopover.h

   The popover class

   Copyright (C) 2013 Free Software Foundation, Inc.

   Author:  Gregory Casamento <greg.casamento@gmail.com>
   Date: 2013

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/
#ifndef _GNUstep_H_NSPopover
#define _GNUstep_H_NSPopover

#import <Foundation/NSGeometry.h>
#import <AppKit/NSNibDeclarations.h>
#import <AppKit/NSResponder.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
/* Keys */
APPKIT_EXPORT NSString *NSPopoverCloseReasonKey;
APPKIT_EXPORT NSString *NSPopoverCloseReasonStandard;
APPKIT_EXPORT NSString *NSPopoverCloseReasonDetachToWindow;

/* Notifications */
APPKIT_EXPORT NSString *NSPopoverWillShowNotification;
APPKIT_EXPORT NSString *NSPopoverDidShowNotification;
APPKIT_EXPORT NSString *NSPopoverWillCloseNotification;
APPKIT_EXPORT NSString *NSPopoverDidCloseNotification;

/* Constants and enums */
enum {
   NSPopoverAppearanceMinimal = 0,
   NSPopoverAppearanceHUD = 1
};
typedef NSInteger NSPopoverAppearance;

enum {
   NSPopoverBehaviorApplicationDefined = 0,
   NSPopoverBehaviorTransient = 1,
   NSPopoverBehaviorSemitransient = 2
};
typedef NSInteger NSPopoverBehavior;

/* Forward declarations */
@class NSViewController, NSPanel, NSView, NSNotification;
@protocol NSPopoverDelegate;

/* Class */
APPKIT_EXPORT_CLASS
@interface NSPopover : NSResponder
{
  BOOL _animates;
  NSPopoverAppearance _appearance;
  NSPopoverBehavior _behavior;
  NSSize _contentSize;
  IBOutlet NSViewController *_contentViewController;
  id _delegate;
  NSRect _positioningRect;
  BOOL _shown;

  NSPanel *_realPanel;
}

/* Properties */
/**
 * Sets the animate flag.  If YES then the popover will animate when it appears or disappears.
 */
- (void)setAnimates:(BOOL)flag;

/**
 * Returns current value of the animate flag.
 */
- (BOOL)animates;

/** 
 * Sets ths appearance of the popover.  Minimal is the default.  HUD is not supported.
 */ 
- (void)setAppearance: (NSPopoverAppearance)value;

/**
 * Returns the current appearance setting.
 */
- (NSPopoverAppearance)appearance;

/**
 * Sets current popup behavior.  Valid settings are:
 * NSPopupBehaviorApplicationDefined, NSPopupBehaviorTransient, 
 * NSPopupBehaviorSemiTransient.
 */
- (void)setBehavior:(NSPopoverBehavior)value;

/**
 * Returns current behavior setting
 */
- (NSPopoverBehavior)behavior;

/**
 * Accepts an NSSize value for the current content size.
 */
- (void)setContentSize:(NSSize)value;

/**
 * Returns an NSSize representing the size of the NSPopover content view.
 */
- (NSSize)contentSize;

/**
 * Sets the contentViewController.  If in a storyboard this is automatically set
 * but if this is in a model that is NOT a storyboard (nib, xib, gorm, etc) then there must be
 * a model with the same name as the class name of the contentViewController.  Also,
 * This model must have the "view" outlet set to the view that will be shown
 * in the popup, if both of these conditions are not met, then the code will
 * throw an NSInternalInconsistency exception to report the issue back to the
 * user.
 */
- (void)setContentViewController:(NSViewController *)controller;

/**
 * Returns the current contentViewController.
 */
- (NSViewController *)contentViewController;

/**
 * Set delegate 
 */
- (void)setDelegate:(id)value;

/**
 * Return delegate
 */
- (id)delegate;

/**
 * Set relative position of the popup to the view it is associated with.
 */
- (void)setPositioningRect:(NSRect)value;

/**
 * Return the NSRect.
 */
- (NSRect)positioningRect;

/**
 * Is the popover being shown.
 */
- (BOOL)isShown;

/* Methods */

/**
 * Close the popover.
 */
- (void)close;

/**
 * Close the popover as an IBAction.
 */
- (IBAction)performClose:(id)sender;

/**
 * Show the popover relative to the specified rect on the edge specified.
 */
- (void)showRelativeToRect:(NSRect)positioningRect
		    ofView:(NSView *)positioningView 
	     preferredEdge:(NSRectEdge)preferredEdge;
@end

/* Delegate */
@protocol NSPopoverDelegate
#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#else
@end
@interface NSObject (NSPopoverDelegate)
#endif
- (NSWindow *)detachableWindowForPopover:(NSPopover *)popover;
- (void)popoverDidClose:(NSNotification *)notification;
- (void)popoverDidShow:(NSNotification *)notification;
- (BOOL)popoverShouldClose:(NSPopover *)popover;
- (void)popoverWillClose:(NSNotification *)notification;
- (void)popoverWillShow:(NSNotification *)notification;
@end

#endif
#endif
