/* GormInspectorsManager.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999
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

#include "GormPrivate.h"
#include "GormImage.h"
#include "GormSound.h"


#define NUM_DEFAULT_INSPECTORS 5

@interface GormDummyInspector : IBInspector
{
    NSButton *button;
}
- (NSString *)title;
@end


@implementation GormDummyInspector
- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      if([bundle loadNibNamed: @"GormDummyInspector" owner: self topLevelObjects: NULL])
      {
	  [button setStringValue: [self title]];
      }
    }
  return self;
}

- (NSString *)title
{
  return nil;
}
@end;

/*
 *	The GormEmptyInspector is a placeholder for an empty selection.
 */
@interface GormEmptyInspector : GormDummyInspector
@end

@implementation GormEmptyInspector
- (NSString *)title
{
  return _(@"Empty Selection");
}
@end

/*
 *	The GormMultipleInspector is a placeholder for a multiple selection.
 */
@interface GormMultipleInspector : GormDummyInspector
@end

@implementation GormMultipleInspector
- (NSString *)title
{
  return _(@"Multiple Selection");
}
@end

/*
 *	The GormNotApplicableInspector is a uitility for odd objects.
 */
@interface GormNotApplicableInspector : GormDummyInspector
@end

@implementation GormNotApplicableInspector
- (NSString *)title
{
  return _(@"Not Applicable");
}
@end

@implementation GormInspectorsManager

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(oldInspector);
  RELEASE(cache);
  RELEASE(panel);
  [super dealloc];
}

- (void) handleNotification: (NSNotification*)aNotification
{
  NSString	*name = [aNotification name];

  if ([name isEqual: IBWillBeginTestingInterfaceNotification] == YES)
    {
      if ([panel isVisible] == YES)
	{
	  hiddenDuringTest = YES;
	  [panel orderOut: self];
	}
    }
  else if ([name isEqual: IBWillEndTestingInterfaceNotification] == YES)
    {
      if (hiddenDuringTest == YES)
	{
	  hiddenDuringTest = NO;
	  [panel orderFront: self];
	}
    }
}

- (id) init
{
  if((self = [super init]) != nil)
    {
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      
      if([NSBundle loadNibNamed: @"GormInspectorPanel" owner: self])
	{
	  // initialized the cache...
	  cache = [[NSMutableDictionary alloc] init];
	  
	  // set the name under which this panel saves it's dimensions.
	  [panel setFrameUsingName: @"Inspector"];
	  [panel setFrameAutosaveName: @"Inspector"];
	  
	  // reset current tag indicator.
	  current = -1;
	  
	  inspector = [[GormEmptyInspector alloc] init];
	  [cache setObject: inspector forKey: @"GormEmptyInspector"];
	  RELEASE(inspector);
	  inspector = [[GormMultipleInspector alloc] init];
	  [cache setObject: inspector forKey: @"GormMultipleInspector"];
	  DESTROY(inspector);
	  
	  [self setCurrentInspector: 0];
	  
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: IBWillBeginTestingInterfaceNotification
	      object: nil];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: IBWillEndTestingInterfaceNotification
	      object: nil];
	}
    }
  
  return self;
}

- (NSPanel*) panel
{
  return panel;
}

- (void) updateSelection
{
  if ([[NSApp delegate] isConnecting] == YES)
    {
      [popup selectItemAtIndex: 1];
      [popup setNeedsDisplay: YES];
      [panel makeKeyAndOrderFront: self];
      current = 1;
    }
  else if (current >= [popup numberOfItems])
    {
      current = 1;
    }
  [self setCurrentInspector: self];
}

- (void) setClassInspector
{
  current = 4;
  [self setCurrentInspector: self];
}

- (void) _addDefaultModes
{
  // remove all items... clear out current state
  [modes removeAllObjects];
  currentMode = nil;
  
  // Attributes inspector...
  [self addInspectorModeWithIdentifier: @"AttributesInspector"
	forObject: selectedObject
	localizedLabel: _(@"Attributes")
	inspectorClassName: [selectedObject inspectorClassName]
	ordering: 0.0];

  // Connection inspector...
  [self addInspectorModeWithIdentifier: @"ConnectionInspector"
	forObject: selectedObject
	localizedLabel: _(@"Connections")
	inspectorClassName: [selectedObject connectInspectorClassName]
	ordering: 1.0];

  // Size inspector...
  [self addInspectorModeWithIdentifier: @"SizeInspector"
	forObject: selectedObject
	localizedLabel: _(@"Size")
	inspectorClassName: [selectedObject sizeInspectorClassName]
	ordering: 2.0];

  // Help inspector...
  [self addInspectorModeWithIdentifier: @"HelpInspector"
	forObject: selectedObject
	localizedLabel: _(@"Help")
	inspectorClassName: [selectedObject helpInspectorClassName]
	ordering: 3.0];

  // Custom class inspector...
  [self addInspectorModeWithIdentifier: @"CustomClassInspector"
	forObject: selectedObject
	localizedLabel: _(@"Custom Class")
	inspectorClassName: [selectedObject classInspectorClassName]
	ordering: 4.0];
}

- (void) _refreshPopUp
{
  NSEnumerator *en = [modes objectEnumerator];
  NSInteger index = 0;
  id obj = nil;

  [[popup menu] setMenuChangedMessagesEnabled: NO];
  [popup removeAllItems];
  while((obj = [en nextObject]) != nil)
    {
      NSInteger tag = index + 1;
      NSMenuItem *item;
      [popup addItemWithTitle: [obj localizedLabel]];

      item = (NSMenuItem *)[popup itemAtIndex: index];
      [item setTarget: self];
      [item setAction: @selector(setCurrentInspector:)];
      [item setKeyEquivalent: [NSString stringWithFormat: @"%ld",(long)tag]];
      [item setTag: tag];
      index++;
    }
  [[popup menu] setMenuChangedMessagesEnabled: YES];
}

- (void) setCurrentInspector: (id)anObj
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSArray		*selection = [[(id<IB>)[NSApp delegate] selectionOwner] selection];
  unsigned		count = [selection count];
  id			obj = [selection lastObject];
  id<IBDocuments>	document = [(id<IB>)[NSApp delegate] activeDocument];
  NSView		*newView = nil;
  NSView		*oldView = nil;
  NSString		*newInspector = nil;
  NSInteger		tag = 0; 

  if (anObj != self)
    {
      tag = [anObj tag];
      current = ((tag > 0)?(tag - 1):tag);
    }

  // reset current under certain conditions.
  if(current < 0)
    {
      current = 0;
    }

  NSDebugLog(@"current %i",current);

  // refresh object.
  selectedObject = obj;
  
  // remove any items beyond the original items on the list..
  [self _addDefaultModes];
  
  // inform the world that the object is about to be inspected.
  [nc postNotificationName: IBWillInspectObjectNotification object: obj];
  
  // set key equivalent
  [self _refreshPopUp];
  
  if([modes count] == NUM_DEFAULT_INSPECTORS)
    {
      if(current > (NUM_DEFAULT_INSPECTORS - 1))
	{
	  current = 0;
	}
    }

  if (count == 0)
    {
      newInspector = @"GormEmptyInspector";
    }
  else if (count > 1)
    {
      newInspector = @"GormMultipleInspector";
    }
  else
    {
      currentMode = [modes objectAtIndex: current];
      newInspector = [currentMode inspectorClassName];
    }
  
  /*
   * Set panel title for the type of object being inspected.
   */
  if (selectedObject == nil)
    {
      [panel setTitle: _(@"Inspector")];
    }
  else if([selectedObject isKindOfClass: [GormClassProxy class]]) 
    {
      [panel setTitle: [NSString stringWithFormat: @"Class Edit Inspector:%@",
				 [selectedObject className]]];
    }
  else
    {
      NSString *newTitle = [selectedObject objectNameForInspectorTitle];
      NSString *objName = [document nameForObject: selectedObject];
      [panel setTitle: [NSString stringWithFormat:_(@"%@ (%@) Inspector"), newTitle,objName]];
    }

  if (newInspector == nil)
    {
      newInspector = @"GormNotApplicableInspector";
    }

  if ([oldInspector isEqual: newInspector] == NO)
    {
      id prevInspector = nil;

      /*
       * Return the inspector view to its original window and release the old
       * inspector.
       */
       if(inspector != nil)
	{
	  [[inspector okButton] removeFromSuperview];
	  [[inspector revertButton] removeFromSuperview];
	}

      ASSIGN(oldInspector, newInspector);
      prevInspector = inspector;
      inspector = [cache objectForKey: newInspector];
      if (inspector == nil)
	{
	  Class	c = NSClassFromString(newInspector);

	  inspector = [[c alloc] init];
	  /* Try to gracefully handle an inspector creation error */
	  while (inspector == nil && (obj = [obj superclass]) 
		 && current == 0)
	    {
	      NSDebugLog(@"Error loading %@ inspector", newInspector);
	      newInspector = [obj inspectorClassName];
	      inspector = [[NSClassFromString(newInspector) alloc] init];
	    }
	  [cache setObject: inspector forKey: newInspector];
	  RELEASE(inspector);
	}

      oldView = [inspectorView contentView];
      newView = [[inspector window] contentView];
      if (newView != nil && newView != oldView)
	{   
	  id     initialResponder = [[inspector window] initialFirstResponder];
	  NSView *outer = [panel contentView];
	  NSRect rect = [panel frame];
	  /*
	    We should compute the delta between the heights of the old inspector view 
	    and the new one. The delta will be used to compute the size of the inspector 
	    panel. Is is needed because subsequent changes of object selection lead to 
	    the cluttered inspector's UI otherwise.
	   */
	  CGFloat delta = [newView frame].size.height - [oldView frame].size.height;

          rect.size.height += delta;
          if (delta > 0)
            {
              rect.origin.y = [panel frame].origin.y - delta;
              [panel setFrame: rect display: YES];
            }
          rect.size.width = [panel minSize].width;
          [panel setMinSize: rect.size];

	  rect = [outer bounds];

	  /* Set initialFirstResponder */
	  if (buttonView != nil)
	    {
	      [buttonView removeFromSuperview];
	      buttonView = nil;
	    }

	  rect.size.height = [newView frame].size.height;
	  if ([inspector wantsButtons] == YES)
	    {
	      NSRect	buttonsRect;
	      NSRect	bRect = NSMakeRect(0, 0, 60, 20);
	      NSButton	*ok;
	      NSButton	*revert;

	      rect.size.height = [selectionView frame].origin.y;
	      buttonsRect = NSMakeRect(0,0,rect.size.width,IVB);
	      rect.origin.y += IVB;
	      rect.size.height -= (IVB + 3);

	      buttonView = [[NSView alloc] initWithFrame: buttonsRect];
	      [buttonView setAutoresizingMask: NSViewWidthSizable];
	      [outer addSubview: buttonView];
	      RELEASE(buttonView);

	      ok = [inspector okButton];
	      if (ok != nil)
		{
		  bRect = [ok frame];
		  bRect.origin.y = 10;
		  bRect.origin.x = buttonsRect.size.width-10-bRect.size.width;
		  [ok setFrame: bRect];
		  [buttonView addSubview: ok];
		}

	      revert = [inspector revertButton];
	      if (revert != nil)
		{
		  bRect = [revert frame];
	 	  bRect.origin.y = 10;
		  bRect.origin.x = 10;
		  [revert setFrame: bRect];
		  [buttonView addSubview: revert];
		}
	    }
	  else
	    {
	      rect.size.height = [newView frame].size.height;
	      [buttonView removeFromSuperview];
	    }

	  /*
	   * Make the inspector view the correct size for the viewable panel,
	   * and set the frame size for the new contents before adding them.
	   */
	  // [inspectorView setFrame: rect];
	  // rect.origin = NSZeroPoint;
	  // [newView setFrame: rect];
          
	  RETAIN(oldView);
	  [inspectorView setContentView: newView];
	  [[prevInspector window] setContentView: oldView];
	  [outer setNeedsDisplay: YES];
	  RELEASE(oldView);

	  /* Set the default First responder to the new View */
	  if ( initialResponder )
	    { 
	      [panel setInitialFirstResponder:initialResponder];
	    }
	}
    }

  // reset the popup..
  [popup selectItemAtIndex: current];

  // inspect the object.
  [inspector setObject: [currentMode object]];
}
@end
