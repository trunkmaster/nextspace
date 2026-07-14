/* GormViewEditor.m
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
 * Date:	2002
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormGenericEditor.h"
#include "GormViewEditor.h"
#include "GormViewWithSubviewsEditor.h"
#include "GormPlacementInfo.h"
#include "GormFunctions.h"
#include "GormViewWindow.h"
#include "GormViewKnobs.h"
#include "GormClassManager.h"
#include "GormDocument.h"

#include <math.h>
#include <stdlib.h>

@implementation GormPlacementInfo
@end

@implementation GormPlacementHint
- (float) position { return _position; }
- (float) start { return _start; }
- (float) end { return _end; }
- (NSRect) frame { return _frame; }
- (GormHintBorder) border { return _border; }
- (NSString *) description
{
  switch (_border)
    {
    case Left:
      return [NSString stringWithFormat: @"Left   %f (%f-%f)", 
		       _position, _start, _end];
    case Right:
      return [NSString stringWithFormat: @"Right  %f (%f-%f)", 
		       _position, _start, _end];
    case Top:
      return [NSString stringWithFormat: @"Top    %f (%f-%f)", 
		       _position, _start, _end];
    default:
      return [NSString stringWithFormat: @"Bottom %f (%f-%f)", 
		       _position, _start, _end];
    }
}
- (id) initWithBorder: (GormHintBorder) border
	     position: (float) position
	validityStart: (float) start
	  validityEnd: (float) end
		frame: (NSRect) frame
{
  _border = border;
  _start = start;
  _end = end;
  _position = position;
  _frame = frame;
  return self;
}

- (NSRect) rectWithHalfDistance: (int) halfHeight
{
  switch (_border)
    {
    case Top:
    case Bottom:
      return NSMakeRect(_start, _position - halfHeight, 
			_end - _start, 2 * halfHeight);
    case Left:
    case Right:
      return NSMakeRect(_position - halfHeight, _start, 
			2 * halfHeight, _end - _start);
    default:
      return NSZeroRect;
    }
}

- (int) distanceToFrame: (NSRect) frame
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSInteger guideSpacing = [userDefaults integerForKey: @"GuideSpacing"];
  NSInteger halfSpacing = guideSpacing / 2;
  NSRect rect = [self rectWithHalfDistance: (halfSpacing + 1)];

  if (NSIntersectsRect(frame, rect) == NO)
    return guideSpacing;
  switch (_border)
    {
    case Top:
      return (int) fabs (_position - NSMaxY(frame));
    case Bottom:
      return (int) fabs (_position - NSMinY(frame));
    case Left:
      return (int) fabs (_position - NSMinX(frame));
    case Right:
      return (int) fabs (_position - NSMaxX(frame));
    default:
      return guideSpacing;
    }
}
@end

static BOOL currently_displaying = NO;

@implementation	GormViewEditor

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Cannot encode a GormViewEditor."];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Cannot decode a GormViewEditor."];
  return nil;
}

- (id<IBDocuments>) document
{
  return document;
}


- (id) editedObject
{
  return _editedObject;
}


- (BOOL) activate
{
  if (activated == NO)
    {
      NSView *superview;
      NSString *name = [document nameForObject: _editedObject];
      GormClassManager *cm = [(GormDocument *)document classManager];

      // if the view window is not nil, it's a standalone view...
      if(viewWindow != nil)
	{
	  if([viewWindow view] != _editedObject)
	    {
	      [viewWindow setView: _editedObject];
	    }
	}

      superview = [_editedObject superview];

      [self setFrame: [_editedObject frame]];
      [self setBounds: [self frame]];

      [superview replaceSubview: _editedObject
		 with: self];
      [self setAutoresizingMask: NSViewMaxXMargin | NSViewMinYMargin];

      // we want autoresizing for standalone views...
      if(viewWindow == nil)
	{
	  [self setAutoresizesSubviews: NO];
	  [_editedObject setPostsFrameChangedNotifications: YES];
	}
      else
	{
	  [self setAutoresizesSubviews: YES];
	}
      
      [self addSubview: _editedObject];
      [self setToolTip: [NSString stringWithFormat: @"%@,%@",
				  name, 
				  [cm classNameForObject: _editedObject]]];
      
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(editedObjectFrameDidChange:)
	name: NSViewFrameDidChangeNotification
	object: _editedObject];

      [self setPostsFrameChangedNotifications: YES];
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(frameDidChange:)
	name: NSViewFrameDidChangeNotification
	object: self];

      parent = (GormViewWithSubviewsEditor *)[document parentEditorForEditor: self];
      if ([parent isKindOfClass: [GormViewEditor class]])
	{
	  [parent setNeedsDisplay: YES];
	}
      else
	{
	  [self setNeedsDisplay: YES];
	}

      activated = YES;

      return activated;
    }
  
  return NO;
}

- (id) parent
{
  return parent;
}

- (void) detachSubviews
{
  NSArray *subviews = allSubviews([self editedObject]);
  [document detachObjects: subviews];
}


- (void) close
{
  if (closed == NO)
    {
      [self deactivate];

      if(viewWindow != nil)
	{
	  [viewWindow close];
	}

      [document editor: self didCloseForObject: _editedObject];
      closed = YES;
    }
  else
    {
      NSDebugLog(@"%@ close but already closed", self);
    }
}

- (void) deactivate
{
  if (activated == YES)
    {
      NSView *superview = [self superview];

      [self removeSubview: _editedObject];
      [superview replaceSubview: self
		 with: _editedObject];

      [[NSNotificationCenter defaultCenter] removeObserver: self];

      // make sure the view isn't in the window after deactivation.
      if(viewWindow != nil)
	{
	  [_editedObject removeFromSuperview]; // WithoutNeedingDisplay];
	  [viewWindow orderOut: self];
	}

      activated = NO;
    }
}

- (void) dealloc
{
  if (closed == NO)
    [self close];

  [super dealloc];
}

- (id) initWithObject: (id)anObject 
	   inDocument: (id<IBDocuments>)aDocument
{
  NSMutableArray *draggedTypes;

  ASSIGN(_editedObject, (NSView*)anObject);

  if ((self = [super initWithFrame: [_editedObject frame]]) != nil)
    {
      // we do not retain the document...
      document = aDocument;
      
      draggedTypes = [NSMutableArray arrayWithObject: GormLinkPboardType];

      // in addition to the link, any other types accepted by dragging delegates.
      [draggedTypes addObjectsFromArray: [NSView acceptedViewResourcePasteboardTypes]]; 
      [self registerForDraggedTypes: draggedTypes];
      
      activated = NO;
      closed = NO;
      
      // if this window is nil when the editor is created, we know it's a
      // standalone view.
      if([anObject window] == nil && [anObject superview] == nil)
	{
	  NSDebugLog(@"#### Stand alone view: %@",_editedObject);
	  [document attachObject: _editedObject
		    toParent: nil];
	  // [document openEditorForObject: _editedObject];
	  viewWindow = [[GormViewWindow alloc] initWithView: _editedObject];
	}
    }

  return self;
}

- (void) editedObjectFrameDidChange: (id) sender
{
  NSArray *allViews = allSubviews(self);
  NSEnumerator *en = [allViews objectEnumerator];
  id v = nil;

  // Set all views under this view to not post changes...
  while((v = [en nextObject]) != nil)
    {
        [v setPostsFrameChangedNotifications:NO];
	[v setPostsBoundsChangedNotifications:NO];
    }
  
  // Set the frame and the bounds...
  [self setFrame: [_editedObject frame]];
  [self setBounds: [_editedObject frame]];

  // Reset all views to post changes as expected...
  en = [allViews objectEnumerator];
  while((v = [en nextObject]) != nil)
    {
      [v setPostsFrameChangedNotifications:YES];
      [v setPostsBoundsChangedNotifications:YES];
    }
}

- (void) frameDidChange: (id) sender
{
  [self setBounds: [self frame]];
  [_editedObject setFrame: [self frame]];
}

- (GormPlacementInfo *) initializeResizingInFrame: (NSView *)view
					 withKnob: (IBKnobPosition) knob
{
  GormPlacementInfo *gip;
  gip = [[GormPlacementInfo alloc] init];
    
  gip->resizingIn = view;
  gip->firstPass = YES;
  gip->hintInitialized = NO;
  gip->leftHints = nil;
  gip->rightHints = nil;
  gip->topHints = nil;
  gip->bottomHints = nil;
  gip->knob = knob;

  return gip;
}

- (void) _displayFrame: (NSRect) frame
     withPlacementInfo: (GormPlacementInfo*) gpi
{
  if (gpi->firstPass == NO)
    [gpi->resizingIn displayRect: gpi->oldRect];
  else
    gpi->firstPass = NO;
  
  GormShowFrameWithKnob(frame, gpi->knob);
  
  gpi->oldRect = GormExtBoundsForRect(frame);
  gpi->oldRect.origin.x--;
  gpi->oldRect.origin.y--;
  gpi->oldRect.size.width += 2;
  gpi->oldRect.size.height += 2;
}

- (void) _initializeHintWithInfo: (GormPlacementInfo*) gpi
{
  NSInteger i;
  NSArray *subviews = [[self superview] subviews];
  NSInteger count = [subviews count];
  NSView *v;
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSInteger guideSpacing = [userDefaults integerForKey: @"GuideSpacing"];
  NSInteger halfSpacing = guideSpacing / 2;

  gpi->lastLeftRect = NSZeroRect;
  gpi->lastRightRect = NSZeroRect;
  gpi->lastTopRect = NSZeroRect;
  gpi->lastBottomRect = NSZeroRect;
  gpi->hintInitialized = YES;
  gpi->leftHints = [[NSMutableArray alloc] initWithCapacity: 2 * count];
  gpi->rightHints = [[NSMutableArray alloc] initWithCapacity: 2 * count];
  gpi->topHints = [[NSMutableArray alloc] initWithCapacity: 2 * count];
  gpi->bottomHints = [[NSMutableArray alloc] initWithCapacity: 2 * count];

  [gpi->leftHints addObject: 
	       [[GormPlacementHint alloc]
		 initWithBorder: Left
		 position: NSMinX([[self superview] bounds])
		 validityStart: NSMinY([[self superview] bounds])
		 validityEnd: NSMaxY([[self superview] bounds])
		 frame: [[self superview] bounds]]];
  [gpi->leftHints addObject: 
	       [[GormPlacementHint alloc]
		 initWithBorder: Left
		 position: NSMinX([[self superview] bounds]) + guideSpacing
		 validityStart: NSMinY([[self superview] bounds])
		 validityEnd: NSMaxY([[self superview] bounds])
		 frame: [[self superview] bounds]]];

  [gpi->rightHints addObject: 
	       [[GormPlacementHint alloc]
		 initWithBorder: Right
		 position: NSMaxX([[self superview] bounds])
		 validityStart: NSMinY([[self superview] bounds])
		 validityEnd: NSMaxY([[self superview] bounds])
		 frame: [[self superview] bounds]]];
  [gpi->rightHints addObject: 
	       [[GormPlacementHint alloc]
		 initWithBorder: Right
		 position: NSMaxX([[self superview] bounds]) - guideSpacing
		 validityStart: NSMinY([[self superview] bounds])
		 validityEnd: NSMaxY([[self superview] bounds])
		 frame: [[self superview] bounds]]];

  [gpi->topHints addObject: 
	       [[GormPlacementHint alloc]
		 initWithBorder: Top
		 position: NSMaxY([[self superview] bounds])
		 validityStart: NSMinX([[self superview] bounds])
		 validityEnd: NSMaxX([[self superview] bounds])
		 frame: [[self superview] bounds]]];
  [gpi->topHints addObject: 
	       [[GormPlacementHint alloc]
		 initWithBorder: Top
		 position: NSMaxY([[self superview] bounds]) - guideSpacing
		 validityStart: NSMinX([[self superview] bounds])
		 validityEnd: NSMaxX([[self superview] bounds])
		 frame: [[self superview] bounds]]];

  [gpi->bottomHints addObject: 
	       [[GormPlacementHint alloc]
		 initWithBorder: Bottom
		 position: NSMinY([[self superview] bounds])
		 validityStart: NSMinX([[self superview] bounds])
		 validityEnd: NSMaxX([[self superview] bounds])
		 frame: [[self superview] bounds]]];
  [gpi->bottomHints addObject: 
	       [[GormPlacementHint alloc]
		 initWithBorder: Bottom
		 position: NSMinY([[self superview] bounds]) + guideSpacing
		 validityStart: NSMinX([[self superview] bounds])
		 validityEnd: NSMaxX([[self superview] bounds])
		 frame: [[self superview] bounds]]];

  for ( i = 0; i < count; i++ )
    {
      v = [subviews objectAtIndex: i];
      if (v == self)
	continue;
     
      [gpi->leftHints addObject: 
		   [[GormPlacementHint alloc]
		     initWithBorder: Left
		     position: NSMinX([v frame])
		     validityStart: NSMinY([[self superview] bounds])
		     validityEnd: NSMaxY([[self superview] bounds])
		     frame: [v frame]]];
      [gpi->leftHints addObject: 
		   [[GormPlacementHint alloc]
		     initWithBorder: Left
		     position: NSMaxX([v frame])
		     validityStart: NSMinY([v frame])
		     validityEnd: NSMaxY([v frame])
		     frame: [v frame]]];
      [gpi->leftHints addObject: 
		   [[GormPlacementHint alloc]
		     initWithBorder: Left
		     position: NSMaxX([v frame]) + halfSpacing
		     validityStart: NSMinY([v frame]) - guideSpacing
		     validityEnd: NSMaxY([v frame]) + guideSpacing
		     frame: [v frame]]];

      [gpi->rightHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Right
		      position: NSMaxX([v frame])
		      validityStart: NSMinY([[self superview] bounds])
		      validityEnd: NSMaxY([[self superview] bounds])
		 frame: [v frame]]];
      [gpi->rightHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Right
		      position: NSMinX([v frame])
		      validityStart: NSMinY([v frame])
		      validityEnd: NSMaxY([v frame])
		      frame: [v frame]]];
      [gpi->rightHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Right
		      position: NSMinX([v frame]) - halfSpacing
		      validityStart: NSMinY([v frame]) - guideSpacing
		      validityEnd: NSMaxY([v frame]) + guideSpacing
		      frame: [v frame]]];

      [gpi->topHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Top
		      position: NSMaxY([v frame])
		      validityStart: NSMinX([[self superview] bounds])
		      validityEnd: NSMaxX([[self superview] bounds])
		 frame: [v frame]]];
      [gpi->topHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Top
		      position: NSMinY([v frame])
		      validityStart: NSMinX([v frame])
		      validityEnd: NSMaxX([v frame])
		      frame: [v frame]]];
      [gpi->topHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Top
		      position: NSMinY([v frame]) - halfSpacing
		      validityStart: NSMinX([v frame]) - guideSpacing
		      validityEnd: NSMaxX([v frame]) + guideSpacing
		      frame: [v frame]]];

      [gpi->bottomHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Bottom
		      position: NSMinY([v frame])
		      validityStart: NSMinX([[self superview] bounds])
		      validityEnd: NSMaxX([[self superview] bounds])
		 frame: [v frame]]];
      [gpi->bottomHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Bottom
		      position: NSMaxY([v frame])
		      validityStart: NSMinX([v frame])
		      validityEnd: NSMaxX([v frame])
		      frame: [v frame]]];
      [gpi->bottomHints addObject: 
		    [[GormPlacementHint alloc]
		      initWithBorder: Bottom
		      position: NSMaxY([v frame]) + halfSpacing
		      validityStart: NSMinX([v frame]) - guideSpacing
		      validityEnd: NSMaxX([v frame]) + guideSpacing
		      frame: [v frame]]];
    }
}


#undef MIN
#undef MAX

#define MIN(a,b) (a>b?b:a)
#define MAX(a,b) (a>b?a:b)


- (void) _displayFrameWithHint: (NSRect) frame
	     withPlacementInfo: (GormPlacementInfo*)gpi
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSInteger guideSpacing = [userDefaults integerForKey: @"GuideSpacing"];
  NSInteger halfSpacing = guideSpacing / 2;
  float leftOfFrame = NSMinX(frame);
  float rightOfFrame = NSMaxX(frame);
  float topOfFrame = NSMaxY(frame);
  float bottomOfFrame = NSMinY(frame);
  NSInteger i;
  NSInteger count;
  NSInteger lastDistance;
  NSInteger minimum = guideSpacing;
  BOOL leftEmpty = YES;
  BOOL rightEmpty = YES;
  BOOL topEmpty = YES;
  BOOL bottomEmpty = YES;
  float bestLeftPosition = 0;
  float bestRightPosition = 0;
  float bestTopPosition = 0;
  float bestBottomPosition = 0;
  float leftStart = 0;
  float rightStart = 0;
  float topStart = 0;
  float bottomStart = 0;
  float leftEnd = 0;
  float rightEnd = 0;
  float topEnd = 0;
  float bottomEnd = 0;

  NSMutableArray *bests;
  if (gpi->hintInitialized == NO)
    {
      [self _initializeHintWithInfo: gpi];
    }

  {
    if (gpi->firstPass == NO)
      [gpi->resizingIn displayRect: gpi->oldRect];
    else
      gpi->firstPass = NO;
  }
  {
    [gpi->resizingIn setNeedsDisplayInRect: gpi->lastLeftRect];
    [[self window] displayIfNeeded];
    gpi->lastLeftRect = NSZeroRect;
  }
  {
    [gpi->resizingIn setNeedsDisplayInRect: gpi->lastRightRect];
    [[self window] displayIfNeeded];
    gpi->lastRightRect = NSZeroRect;
  }
  {
    [gpi->resizingIn setNeedsDisplayInRect: gpi->lastTopRect];
    [[self window] displayIfNeeded];
    gpi->lastTopRect = NSZeroRect;
  }
  {
    [gpi->resizingIn setNeedsDisplayInRect: gpi->lastBottomRect];
    [[self window] displayIfNeeded];
    gpi->lastBottomRect = NSZeroRect;
  }


  if (gpi->knob == IBTopLeftKnobPosition
      || gpi->knob == IBMiddleLeftKnobPosition
      || gpi->knob == IBBottomLeftKnobPosition)
  {
    bests = [NSMutableArray arrayWithCapacity: 4];
    minimum = (halfSpacing + 1);
    count = [gpi->leftHints count];
    for ( i = 0; i < count; i++ )
      {
	lastDistance = [[gpi->leftHints objectAtIndex: i] 
			 distanceToFrame: frame];
	if (lastDistance < minimum)
	  {
	    bests = [NSMutableArray arrayWithCapacity: 4];
	    [bests addObject: [gpi->leftHints objectAtIndex: i]];
	    minimum = lastDistance;
	    bestLeftPosition = [[gpi->leftHints objectAtIndex: i] position];
	    leftEmpty = NO;
	  }
	else if ((lastDistance == minimum) && (leftEmpty == NO)
		 && ([[gpi->leftHints objectAtIndex: i] position] == bestLeftPosition))
	  [bests addObject: [gpi->leftHints objectAtIndex: i]];
      }
    
    count = [bests count];
    if (count >= 1)
      {
	leftStart = NSMinY([[bests objectAtIndex: 0] frame]);
	leftEnd = NSMaxY([[bests objectAtIndex: 0] frame]);

	for ( i = 1; i < count; i++ )
	  {
	    leftStart = MIN(NSMinY([[bests objectAtIndex: i] frame]), leftStart);
	    leftEnd = MAX(NSMaxY([[bests objectAtIndex: i] frame]), leftEnd);
	  }
	leftOfFrame = bestLeftPosition;
      }
  }

  if (gpi->knob == IBTopRightKnobPosition
      || gpi->knob == IBMiddleRightKnobPosition
      || gpi->knob == IBBottomRightKnobPosition)
  {
    bests = [NSMutableArray arrayWithCapacity: 4];
    minimum = (halfSpacing + 1);
    count = [gpi->rightHints count];
    for ( i = 0; i < count; i++ )
      {
	lastDistance = [[gpi->rightHints objectAtIndex: i] 
			 distanceToFrame: frame];
	if (lastDistance < minimum)
	  {
	    bests = [NSMutableArray arrayWithCapacity: 4];
	    [bests addObject: [gpi->rightHints objectAtIndex: i]];
	    minimum = lastDistance;
	    bestRightPosition = [[gpi->rightHints objectAtIndex: i] position];
	    rightEmpty = NO;
	  }
	else if ((lastDistance == minimum) && (rightEmpty == NO)
		 && ([[gpi->rightHints objectAtIndex: i] position] == bestRightPosition))
	  [bests addObject: [gpi->rightHints objectAtIndex: i]];
      }
    
    count = [bests count];
    if (count >= 1)
      {
	rightStart = NSMinY([[bests objectAtIndex: 0] frame]);
	rightEnd = NSMaxY([[bests objectAtIndex: 0] frame]);

	for ( i = 1; i < count; i++ )
	  {
	    rightStart = MIN(NSMinY([[bests objectAtIndex: i] frame]), rightStart);
	    rightEnd = MAX(NSMaxY([[bests objectAtIndex: i] frame]), rightEnd);
	  }
	rightOfFrame = bestRightPosition;
      }
  }

  if (gpi->knob == IBTopRightKnobPosition
      || gpi->knob == IBTopLeftKnobPosition
      || gpi->knob == IBTopMiddleKnobPosition)
  {
    bests = [NSMutableArray arrayWithCapacity: 4];
    minimum = (halfSpacing + 1);
    count = [gpi->topHints count];
    for ( i = 0; i < count; i++ )
      {
	lastDistance = [[gpi->topHints objectAtIndex: i] 
			 distanceToFrame: frame];
	if (lastDistance < minimum)
	  {
	    bests = [NSMutableArray arrayWithCapacity: 4];
	    [bests addObject: [gpi->topHints objectAtIndex: i]];
	    minimum = lastDistance;
	    bestTopPosition = [[gpi->topHints objectAtIndex: i] position];
	    topEmpty = NO;
	  }
	else if ((lastDistance == minimum) && (topEmpty == NO)
		 && ([[gpi->topHints objectAtIndex: i] position] == bestTopPosition))
	  [bests addObject: [gpi->topHints objectAtIndex: i]];
      }
    
    count = [bests count];
    if (count >= 1)
      {
	topStart = NSMinX([[bests objectAtIndex: 0] frame]);
	topEnd = NSMaxX([[bests objectAtIndex: 0] frame]);
	for ( i = 1; i < count; i++ )
	  {
	    topStart = MIN(NSMinX([[bests objectAtIndex: i] frame]), topStart);
	    topEnd = MAX(NSMaxX([[bests objectAtIndex: i] frame]), topEnd);
	  }
	topOfFrame = bestTopPosition;
      }
  }

  if (gpi->knob == IBBottomRightKnobPosition
      || gpi->knob == IBBottomLeftKnobPosition
      || gpi->knob == IBBottomMiddleKnobPosition)
  {
    bests = [NSMutableArray arrayWithCapacity: 4];
    minimum = (halfSpacing + 1);
    count = [gpi->bottomHints count];
    for ( i = 0; i < count; i++ )
      {
	lastDistance = [[gpi->bottomHints objectAtIndex: i] 
			 distanceToFrame: frame];
	if (lastDistance < minimum)
	  {
	    bests = [NSMutableArray arrayWithCapacity: 4];
	    [bests addObject: [gpi->bottomHints objectAtIndex: i]];
	    minimum = lastDistance;
	    bestBottomPosition = [[gpi->bottomHints objectAtIndex: i] position];
	    bottomEmpty = NO;
	  }
	else if ((lastDistance == minimum) && (bottomEmpty == NO)
		 && ([[gpi->bottomHints objectAtIndex: i] position] == bestBottomPosition))
	  [bests addObject: [gpi->bottomHints objectAtIndex: i]];
      }
    
    count = [bests count];
    if (count >= 1)
      {
	bottomStart = NSMinX([[bests objectAtIndex: 0] frame]);
	bottomEnd = NSMaxX([[bests objectAtIndex: 0] frame]);
	for ( i = 1; i < count; i++ )
	  {
	    bottomStart = MIN(NSMinX([[bests objectAtIndex: i] frame]), bottomStart);
	    bottomEnd = MAX(NSMaxX([[bests objectAtIndex: i] frame]), bottomEnd);
	  }
	bottomOfFrame = bestBottomPosition;
      }
  }

  gpi->hintFrame = NSMakeRect (leftOfFrame, bottomOfFrame,
			  rightOfFrame - leftOfFrame,
			  topOfFrame - bottomOfFrame);
  {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSColor *aColor = colorFromDict([defaults objectForKey: @"GuideColor"]);
    
    // default to the right color...
    if(aColor == nil)
      {
	aColor = [NSColor redColor];
      }

    [aColor set];
    if (!leftEmpty)
      {
	leftStart = MIN(NSMinY(gpi->hintFrame), leftStart);
	leftEnd = MAX(NSMaxY(gpi->hintFrame), leftEnd);
	gpi->lastLeftRect = NSMakeRect(bestLeftPosition - 1, leftStart, 
				       2, leftEnd - leftStart);
	NSRectFill(gpi->lastLeftRect);
      }
    if (!rightEmpty)
      {
	rightStart = MIN(NSMinY(gpi->hintFrame), rightStart);
	rightEnd = MAX(NSMaxY(gpi->hintFrame), rightEnd);
	gpi->lastRightRect = NSMakeRect(bestRightPosition - 1, rightStart, 
					2, rightEnd - rightStart);
	NSRectFill(gpi->lastRightRect);
      }
    if (!topEmpty)
      {
	topStart = MIN(NSMinX(gpi->hintFrame), topStart);
	topEnd = MAX(NSMaxX(gpi->hintFrame), topEnd);
	gpi->lastTopRect = NSMakeRect(topStart, bestTopPosition - 1,
				      topEnd - topStart, 2);
	NSRectFill(gpi->lastTopRect);
      }
    if (!bottomEmpty)
      {
	bottomStart = MIN(NSMinX(gpi->hintFrame), bottomStart);
	bottomEnd = MAX(NSMaxX(gpi->hintFrame), bottomEnd);
	gpi->lastBottomRect = NSMakeRect(bottomStart, bestBottomPosition - 1, 
					 bottomEnd - bottomStart, 2);
	NSRectFill(gpi->lastBottomRect);
      }

  }

  GormShowFrameWithKnob(gpi->hintFrame, gpi->knob);
  gpi->oldRect = GormExtBoundsForRect(gpi->hintFrame);
  gpi->oldRect.origin.x--;
  gpi->oldRect.origin.y--;
  gpi->oldRect.size.width += 2;
  gpi->oldRect.size.height += 2;
}

- (void) updateResizingWithFrame: (NSRect) frame
			andEvent: (NSEvent *)theEvent
		andPlacementInfo: (GormPlacementInfo*) gpi
{
  if ([theEvent modifierFlags] & NSShiftKeyMask)
    {
      [self _displayFrame: frame
	    withPlacementInfo: gpi];
    }
  else
    [self _displayFrameWithHint: frame
	  withPlacementInfo: gpi];
}

- (void) validateFrame: (NSRect) frame
	     withEvent: (NSEvent *) theEvent
      andPlacementInfo: (GormPlacementInfo*)gpi
{
  if (gpi->leftHints)
    {
      RELEASE(gpi->leftHints);
      RELEASE(gpi->rightHints);
      [self setFrame: gpi->hintFrame];
    }
  else
    {
      [self setFrame: frame];
    }
}

- (NSRect) _displayMovingFrameWithHint: (NSRect) frame
		      andPlacementInfo: (GormPlacementInfo*)gpi
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSInteger guideSpacing = [userDefaults integerForKey: @"GuideSpacing"];
  NSInteger halfSpacing = guideSpacing / 2;
  float leftOfFrame = NSMinX(frame);
  float rightOfFrame = NSMaxX(frame);
  float topOfFrame = NSMaxY(frame);
  float bottomOfFrame = NSMinY(frame);
  float widthOfFrame = frame.size.width;
  float heightOfFrame = frame.size.height;
  NSInteger i;
  NSInteger count;
  NSInteger lastDistance;
  NSInteger minimum = guideSpacing;
  BOOL leftEmpty = YES;
  BOOL rightEmpty = YES;
  BOOL topEmpty = YES;
  BOOL bottomEmpty = YES;
  float leftStart = 0;
  float rightStart = 0;
  float topStart = 0;
  float bottomStart = 0;
  float leftEnd = 0;
  float rightEnd = 0;
  float topEnd = 0;
  float bottomEnd = 0;

  if (gpi->hintInitialized == NO)
    {
      [self _initializeHintWithInfo: gpi];
    }

  {
    [gpi->resizingIn setNeedsDisplayInRect: gpi->lastLeftRect];
    [[self window] displayIfNeeded];
    gpi->lastLeftRect = NSZeroRect;
  }
  {
    [gpi->resizingIn setNeedsDisplayInRect: gpi->lastRightRect];
    [[self window] displayIfNeeded];
    gpi->lastRightRect = NSZeroRect;
  }
  {
    [gpi->resizingIn setNeedsDisplayInRect: gpi->lastTopRect];
    [[self window] displayIfNeeded];
    gpi->lastTopRect = NSZeroRect;
  }
  {
    [gpi->resizingIn setNeedsDisplayInRect: gpi->lastBottomRect];
    [[self window] displayIfNeeded];
    gpi->lastBottomRect = NSZeroRect;
  }


  {
    BOOL empty = YES;
    float bestPosition = 0;
    NSMutableArray *leftBests;
    NSMutableArray *rightBests;
    minimum = (halfSpacing + 1);
    count = [gpi->leftHints count];

    leftBests = [NSMutableArray arrayWithCapacity: 4];
    for ( i = 0; i < count; i++ )
      {
	lastDistance = [[gpi->leftHints objectAtIndex: i] 
			 distanceToFrame: frame];
	if (lastDistance < minimum)
	  {
	    leftBests = [NSMutableArray arrayWithCapacity: 4];
	    [leftBests addObject: [gpi->leftHints objectAtIndex: i]];
	    minimum = lastDistance;
	    bestPosition = [[gpi->leftHints objectAtIndex: i] position];
	    empty = NO;
	  }
	else if ((lastDistance == minimum) && (empty == NO)
		 && ([[gpi->leftHints objectAtIndex: i] position] == bestPosition))
	  [leftBests addObject: [gpi->leftHints objectAtIndex: i]];
      }

    count = [gpi->rightHints count];
    rightBests = [NSMutableArray arrayWithCapacity: 4];
    for ( i = 0; i < count; i++ )
      {
	lastDistance = [[gpi->rightHints objectAtIndex: i] 
			 distanceToFrame: frame];
	if (lastDistance < minimum)
	  {
	    rightBests = [NSMutableArray arrayWithCapacity: 4];
	    leftBests = [NSMutableArray arrayWithCapacity: 4];
	    [rightBests addObject: [gpi->rightHints objectAtIndex: i]];
	    minimum = lastDistance;
	    bestPosition = [[gpi->rightHints objectAtIndex: i] position] 
	      - widthOfFrame;
	    empty = NO;
	  }
	else if ((lastDistance == minimum) && (empty == NO)
		 && ([[gpi->rightHints objectAtIndex: i] position] - bestPosition
		     == widthOfFrame))
	  [rightBests addObject: [gpi->rightHints objectAtIndex: i]];
      }
    
    count = [leftBests count];
    if (count >= 1)
      {
	float position;
	leftEmpty = NO;
	position = [[leftBests objectAtIndex: 0] position];
	
	leftStart = NSMinY([[leftBests objectAtIndex: 0] frame]);
	leftEnd = NSMaxY([[leftBests objectAtIndex: 0] frame]);
	for ( i = 1; i < count; i++ )
	  {
	    leftStart = MIN(NSMinY([[leftBests objectAtIndex: i] frame]), leftStart);
	    leftEnd = MAX(NSMaxY([[leftBests objectAtIndex: i] frame]), leftEnd);
	  }
	
	leftOfFrame = position;
	rightOfFrame = position + widthOfFrame;
      }

    count = [rightBests count];
    if (count >= 1)
      {
	float position;
	rightEmpty = NO;
	position = [[rightBests objectAtIndex: 0] position];
	
	rightStart = NSMinY([[rightBests objectAtIndex: 0] frame]);
	rightEnd = NSMaxY([[rightBests objectAtIndex: 0] frame]);
	for ( i = 1; i < count; i++ )
	  {
	    rightStart = MIN(NSMinY([[rightBests objectAtIndex: i] frame]), rightStart);
	    rightEnd = MAX(NSMaxY([[rightBests objectAtIndex: i] frame]), rightEnd);
	  }
	
	rightOfFrame = position;
	leftOfFrame = position - widthOfFrame;
      }
  }

  {
    BOOL empty = YES;
    float bestPosition = 0;
    NSMutableArray *bottomBests;
    NSMutableArray *topBests;
    minimum = (halfSpacing + 1);
    count = [gpi->bottomHints count];

    bottomBests = [NSMutableArray arrayWithCapacity: 4];
    for ( i = 0; i < count; i++ )
      {
	lastDistance = [[gpi->bottomHints objectAtIndex: i] 
			 distanceToFrame: frame];
	if (lastDistance < minimum)
	  {
	    bottomBests = [NSMutableArray arrayWithCapacity: 4];
	    [bottomBests addObject: [gpi->bottomHints objectAtIndex: i]];
	    minimum = lastDistance;
	    bestPosition = [[gpi->bottomHints objectAtIndex: i] position];
	    empty = NO;
	  }
	else if ((lastDistance == minimum) && (empty == NO)
		 && ([[gpi->bottomHints objectAtIndex: i] position] == bestPosition))
	  [bottomBests addObject: [gpi->bottomHints objectAtIndex: i]];
      }

    count = [gpi->topHints count];
    topBests = [NSMutableArray arrayWithCapacity: 4];
    for ( i = 0; i < count; i++ )
      {
	lastDistance = [[gpi->topHints objectAtIndex: i] 
			 distanceToFrame: frame];
	if (lastDistance < minimum)
	  {
	    topBests = [NSMutableArray arrayWithCapacity: 4];
	    bottomBests = [NSMutableArray arrayWithCapacity: 4];
	    [topBests addObject: [gpi->topHints objectAtIndex: i]];
	    minimum = lastDistance;
	    bestPosition = [[gpi->topHints objectAtIndex: i] position] 
	      - heightOfFrame;
	    empty = NO;
	  }
	else if (lastDistance == minimum && (empty == NO)
		 && ([[gpi->topHints objectAtIndex: i] position] - bestPosition
		     == heightOfFrame))
	  [topBests addObject: [gpi->topHints objectAtIndex: i]];
      }
    
    count = [bottomBests count];
    if (count >= 1)
      {
	float position;
	bottomEmpty = NO;
	position = [[bottomBests objectAtIndex: 0] position];
	
	bottomStart = NSMinX([[bottomBests objectAtIndex: 0] frame]);
	bottomEnd = NSMaxX([[bottomBests objectAtIndex: 0] frame]);
	for ( i = 1; i < count; i++ )
	  {
	    bottomStart = MIN(NSMinX([[bottomBests objectAtIndex: i] frame]), bottomStart);
	    bottomEnd = MAX(NSMaxX([[bottomBests objectAtIndex: i] frame]), bottomEnd);
	  }
	
	bottomOfFrame = position;
	topOfFrame = position + heightOfFrame;
      }

    count = [topBests count];
    if (count >= 1)
      {
	float position;
	topEmpty = NO;
	position = [[topBests objectAtIndex: 0] position];
	
	topStart = NSMinX([[topBests objectAtIndex: 0] frame]);
	topEnd = NSMaxX([[topBests objectAtIndex: 0] frame]);
	for ( i = 1; i < count; i++ )
	  {
	    topStart = MIN(NSMinX([[topBests objectAtIndex: i] frame]), topStart);
	    topEnd = MAX(NSMaxX([[topBests objectAtIndex: i] frame]), topEnd);
	  }
	
	topOfFrame = position;
	bottomOfFrame = position - heightOfFrame;
      }
  }

  gpi->hintFrame = NSMakeRect (leftOfFrame, bottomOfFrame,
		     rightOfFrame - leftOfFrame,
		     topOfFrame - bottomOfFrame);

  {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSColor *aColor = colorFromDict([defaults objectForKey: @"GuideColor"]);
    
    // default to the right color...
    if(aColor == nil)
      {
	aColor = [NSColor redColor];
      }

    [aColor set];
    if (!leftEmpty)
      {
	leftStart = MIN(NSMinY(gpi->hintFrame), leftStart);
	leftEnd = MAX(NSMaxY(gpi->hintFrame), leftEnd);
	gpi->lastLeftRect = NSMakeRect(leftOfFrame - 1, leftStart, 
				       2, leftEnd - leftStart);
	NSRectFill(gpi->lastLeftRect);
      }
    
    if (!rightEmpty)
      {
	rightStart = MIN(NSMinY(gpi->hintFrame), rightStart);
	rightEnd = MAX(NSMaxY(gpi->hintFrame), rightEnd);
	gpi->lastRightRect = NSMakeRect(rightOfFrame - 1, rightStart, 
					2, rightEnd - rightStart);
	NSRectFill(gpi->lastRightRect);
      }
    
    if (!topEmpty)
      {
	topStart = MIN(NSMinX(gpi->hintFrame), topStart);
	topEnd = MAX(NSMaxX(gpi->hintFrame), topEnd);
	gpi->lastTopRect = NSMakeRect(topStart, topOfFrame - 1, 
					 topEnd - topStart, 2);
	NSRectFill(gpi->lastTopRect);
      }

    if (!bottomEmpty)
      {
	bottomStart = MIN(NSMinX(gpi->hintFrame), bottomStart);
	bottomEnd = MAX(NSMaxX(gpi->hintFrame), bottomEnd);
	gpi->lastBottomRect = NSMakeRect(bottomStart, bottomOfFrame - 1, 
				      bottomEnd - bottomStart, 2);
	NSRectFill(gpi->lastBottomRect);
      }
  }

  return gpi->hintFrame;
}

- (NSView *)hitTest: (NSPoint)loc
{
  id result;
  result = [super hitTest: loc];
  
  if ((result != nil)
      && [result isKindOfClass: [GormViewEditor class]])
    {
      return result;
    }
  else if (result != nil)
    {
      return self;
    }
  return nil;
}


- (NSWindow*) windowAndRect: (NSRect *)rect forObject: (id) anObject
{
  if (anObject != _editedObject)
    {
      return nil;
    }
  else
    {
      *rect = [_editedObject convertRect:[_editedObject visibleRect]
			     toView: nil];
      return _window;
    }
}


- (void) startConnectingObject: (id) anObject
		     withEvent: (NSEvent *)theEvent
{
  NSPasteboard	*pb;
  NSString	*name = [document nameForObject: anObject];
  NSPoint	dragPoint = [theEvent locationInWindow];
  id            delegate = [NSApp delegate];
  
  if(name != nil)
    {
      pb = [NSPasteboard pasteboardWithName: NSDragPboard];
      [pb declareTypes: [NSArray arrayWithObject: GormLinkPboardType]
	  owner: self];
      [pb setString: name forType: GormLinkPboardType];
      [delegate displayConnectionBetween: anObject and: nil];
      [delegate startConnecting];
      
      [self dragImage: [delegate linkImage]
	    at: dragPoint
	    offset: NSZeroSize
	    event: theEvent
	    pasteboard: pb
	    source: self
	    slideBack: YES];
    }
}

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>)sender
{
  NSPasteboard	*dragPb;
  NSArray	*types;
  id            delegate = [NSApp delegate];
  
  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  if ([types containsObject: GormLinkPboardType] == YES)
    {
      [delegate displayConnectionBetween: [delegate connectSource] 
				     and: _editedObject];
      return NSDragOperationLink;
    }
  else if ([types firstObjectCommonWithArray: [NSView acceptedViewResourcePasteboardTypes]] != nil)
    {
      return NSDragOperationCopy;
    }
  else
    {
      return NSDragOperationNone;
    }
}

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>)sender
{
  return [self draggingEntered: sender];
}


- (void)  draggingExited: (id<NSDraggingInfo>)sender
{
  NSPasteboard	*dragPb;
  NSArray	*types;
  id            delegate = [NSApp delegate];

  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  if ([types containsObject: GormLinkPboardType] == YES)
    {
      [delegate displayConnectionBetween: [delegate connectSource] 
				     and: nil];
    }
  
}

- (void) mouseDown: (NSEvent*)theEvent
{
  if ([theEvent modifierFlags] & NSControlKeyMask)
    // start a action/outlet connection
    {

      // first we need to select ourself
      // to do so we need to find our first ancestor that can handle a selection
      NSView *view = [self superview];

      while ((view != nil)
	     && ([view respondsToSelector: @selector(selectObjects:)] == NO))
	{
	  view = [view superview];
	}

      if (view != nil)
	[(id)view selectObjects: [NSArray arrayWithObject: self]];
      
      // now we can start the connection process
      [self startConnectingObject: _editedObject
	    withEvent: theEvent];
    }
  else
    // just send the event to our parent
    {
      if (parent)
	{
	  // TODO: We should find a better test than this, but it will do
	  // for now...
	  if([parent isKindOfClass: [GormGenericEditor class]] == NO)
	    {
	      [parent mouseDown: theEvent];
	    }
	}
      else
	return [self noResponderFor: @selector(mouseDown:)];
    }
}

- (id) _selectDelegate: (id<NSDraggingInfo>)sender
{
  NSEnumerator *en = [[NSView registeredViewResourceDraggingDelegates] objectEnumerator];
  id delegate = nil;
  id selectedDelegate = nil;
  NSPasteboard *pb = [sender draggingPasteboard];
  NSPoint point = [sender draggingLocation];

  while((delegate = [en nextObject]) != nil)
    {
      if([delegate respondsToSelector: @selector(acceptsViewResourceFromPasteboard:forObject:atPoint:)])
	{
	  if([delegate acceptsViewResourceFromPasteboard: pb
		       forObject: _editedObject
		       atPoint: point])
	    {
	      selectedDelegate = delegate;
	      break;
	    }
	}
    }
  
  return selectedDelegate;
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>)sender
{
  NSPasteboard	*dragPb;
  NSArray	*types;
  
  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  if ([types containsObject: GormLinkPboardType] == YES)
    {
      return YES;
    }
  else if ([types firstObjectCommonWithArray: [NSView acceptedViewResourcePasteboardTypes]] != nil)
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  NSPasteboard	*dragPb;
  NSArray	*types;
  NSPoint       point = [sender draggingLocation];
  id            delegate = [NSApp delegate];
  id            viewDelegate = nil;
  
  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  
  if ([types containsObject: GormLinkPboardType])
    {
      [delegate displayConnectionBetween: [delegate connectSource] 
				     and: _editedObject];
      [delegate startConnecting];
    }
  else if ((viewDelegate = [self _selectDelegate: sender]) != nil)
    {
      if([viewDelegate respondsToSelector: @selector(shouldDrawConnectionFrame)])
	{
	  if([viewDelegate shouldDrawConnectionFrame])
	    {      
	      [delegate displayConnectionBetween: [delegate connectSource] 
					     and: _editedObject];      
	    }
	}

      if([viewDelegate respondsToSelector:
	     @selector(depositViewResourceFromPasteboard:onObject:atPoint:)])
	{
	  [viewDelegate depositViewResourceFromPasteboard: dragPb
		    onObject: _editedObject
		    atPoint: point];
	  
	  // refresh the selection...
	  [document setSelectionFromEditor: self];

	  // return success.
	  return YES;
	}
    }

  return NO;
}

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL) flag
{
  return NSDragOperationLink;
}


- (BOOL) wantsSelection
{
  return YES;
}

- (void) resetObject: (id)anObject
{
  NS_DURING
    {
      // display the view, if it's standalone.
      if(viewWindow != nil)
	{
	  [viewWindow orderFront: self];
	}
    }
  NS_HANDLER
    {
      NSLog(@"Exception while trying to display standalone view: %@",[localException reason]);
    }
  NS_ENDHANDLER
}

- (void) orderFront
{
  [[self window] orderFront: self];
}

- (NSWindow *) window
{
  return [super window];
}
/*
 *  Drawing additions
 */

- (void) postDraw: (NSRect) rect
{
  if (parent != nil)
    {
      if ([parent respondsToSelector: @selector(postDrawForView:)])
	{
	  [parent performSelector: @selector(postDrawForView:)
		       withObject: self];
	}
    }
}

- (void) drawRect: (NSRect) rect
{
  if (currently_displaying == NO)
    {
      [[self window] disableFlushWindow];
      currently_displaying = YES;
      [super drawRect: rect];
      [self lockFocus];
      [self postDraw: rect];
      [self unlockFocus];
      [[self window] enableFlushWindow];
      [[self window] flushWindow];
      currently_displaying = NO;
    }
  else
    {
      [super drawRect: rect];
      [self lockFocus];
      [self postDraw: rect];
      [self unlockFocus];
    }    
}

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  return NO;
}

- (NSArray*) selection
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: 1];

  // add self to the result...
  if ([self respondsToSelector: @selector(editedObject)])
    [result addObject: [self editedObject]];
  else
    [result addObject: self];

  return result;
}

- (void) makeSelectionVisible: (BOOL) value
{
}

- (BOOL) canBeOpened
{
  return NO;
}

- (BOOL) isOpened
{
  return NO;
}

- (void) setOpened: (BOOL) value
{
  if (value == YES)
    {
      [document setSelectionFromEditor: self];      
    }
  else
    {
      [self setNeedsDisplay: YES];
    }
}

// stubs for the remainder of the IBEditors protocol not implemented in this class.
- (void) deleteSelection
{
  // NSLog(@"deleteSelection should be defined in a subclass");
}

- (void) validateEditing
{
  // NSLog(@"validateEditing should be defined in a subclass");
}

- (void) pasteInSelection
{
  // NSLog(@"deleteSelection should be defined in a subclass");
}

- (id<IBEditors>) openSubeditorForObject: (id) object
{
  return nil;
}

- (void) closeSubeditors
{
  // NSLog(@"closeSubeditors should be defined in a subclass");
}
@end


@implementation GormViewEditor (ResponderAdditions)
- (BOOL) acceptsFirstMouse: (NSEvent*)theEvent
{
  return YES;
}

- (BOOL) acceptsFirstResponder
{
  return NO;
}
@end


static BOOL done_editing;

@implementation GormViewEditor (EditingAdditions)
- (void) handleNotification: (NSNotification*)aNotification
{
  NSString	*name = [aNotification name];
  if ([name isEqual: NSControlTextDidEndEditingNotification] == YES)
    {
      done_editing = YES;
      [[self document] touch];
    }
}

/* Edit a textfield. If it's not already editable, make it so, then
   edit it */
- (NSEvent *) editTextField: view withEvent: (NSEvent *)theEvent
{
  unsigned eventMask;
  BOOL wasEditable;
  BOOL didDrawBackground;
  NSTextField *editField;
  NSRect                 frame;
  NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];
  NSDate		*future = [NSDate distantFuture];
  NSEvent *e;
      
  editField = view;
  frame = [editField frame];

  wasEditable = [editField isEditable];
  [editField setEditable: YES];
  didDrawBackground = [editField drawsBackground];
  [editField setDrawsBackground: YES];

  [nc addObserver: self
         selector: @selector(handleNotification:)
             name: NSControlTextDidEndEditingNotification
           object: nil];

  /* Do some modal editing */
  [editField selectText: self];
  eventMask = NSLeftMouseDownMask |  NSLeftMouseUpMask  |
  NSKeyDownMask  |  NSKeyUpMask  | NSFlagsChangedMask;

  done_editing = NO;
  while (!done_editing)
    {
      NSEventType eType;
      e = [NSApp nextEventMatchingMask: eventMask
		 untilDate: future
		 inMode: NSEventTrackingRunLoopMode
		 dequeue: YES];
      eType = [e type];
      switch (eType)
	{
	case NSLeftMouseDown:
	  {
	    NSPoint dp =  [self convertPoint: [e locationInWindow]
				fromView: nil];
	    if (NSMouseInRect(dp, frame, NO) == NO)
	      {
		done_editing = YES;
		break;
	      }
	  }
	  [[editField currentEditor] mouseDown: e];
	  break;
	case NSLeftMouseUp:
	  [[editField currentEditor] mouseUp: e];
	  break;
	case NSLeftMouseDragged:
	  [[editField currentEditor] mouseDragged: e];
	  break;
	case NSKeyDown:
	  [[editField currentEditor] keyDown: e];
	  break;
	case NSKeyUp:
	  [[editField currentEditor] keyUp: e];
	  break;
	case NSFlagsChanged:
	  [[editField currentEditor] flagsChanged: e];
	  break;
	default:
	  NSLog(@"Internal Error: Unhandled event during editing: %@", e);
	  break;
	}
    }

  [editField setEditable: wasEditable];
  [editField setDrawsBackground: didDrawBackground];
  [nc removeObserver: self
                name: NSControlTextDidEndEditingNotification
              object: nil];

  [[editField currentEditor] resignFirstResponder];
  [self setNeedsDisplay: YES];

  return e;
}
@end
