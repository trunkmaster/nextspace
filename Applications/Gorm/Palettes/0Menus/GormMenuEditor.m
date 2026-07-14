/* GormMenuEditor.m
 *
 * Copyright (C) 2000 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	2000
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

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>
#include <GormCore/GormCore.h>

/*
 * This method will allow us to check if the menu is
 * open, so that it can be conditionally closed.
 */
@interface NSMenu (GormMenuEditorAdditions)
- (BOOL) isVisible;
@end

@implementation NSMenu (GormMenuEditorAdditions)
- (BOOL) isVisible
{
  return [[self window] isVisible];
}
@end



@interface	GormMenuEditor : NSMenuView <IBEditors, IBSelectionOwners>
{
  id<IBDocuments>	document;
  NSMenu		*edited;
  id			original;
  NSMenuView		*rep;
  NSMutableArray	*selection;
  id			subeditor;
  BOOL			isLinkSource;
  BOOL			isClosed;
  NSPasteboard		*dragPb;
  NSString		*dragType;
}

- (BOOL) acceptsTypeFromArray: (NSArray*)types;
- (BOOL) activate;
- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument;
- (void) close;
- (void) closeSubeditors;
- (void) copySelection;
- (void) deactivate;
- (void) deleteSelection;
- (id<IBDocuments>) document;
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f;
- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)flag;
- (id) editedObject;
- (void) makeSelectionVisible: (BOOL)flag;
- (id<IBEditors>) openSubeditorForObject: (id)anObject;
- (void) orderFront;
- (void) pasteInSelection;
- (void) resetObject: (id)anObject;
- (void) selectObjects: (NSArray*)objects;
- (void) validateEditing;
- (BOOL) wantsSelection;
- (NSWindow*) window;

@end

@interface      GormMenuEditor (Private)
- (NSEvent *) editTextField: view withEvent: (NSEvent *)theEvent;
@end

@implementation	GormMenuEditor

- (BOOL) acceptsFirstMouse: (NSEvent*)theEvent
{
  return YES;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Argh - encoding menu editor"];
}

/*
 *	Intercepting events in the view and handling them
 */
- (NSView*) hitTest: (NSPoint)loc
{
  /*
   * We grab all events in the window.
   */
  if ([super hitTest: loc] != nil)
    {
      return self;
    }
  return nil;
}

- (BOOL) resignFirstResponder
{
  return NO;
}

- (void) rightMouseDown: (NSEvent*)theEvent
{
  // Do nothing.  We want to ignore when the right mouse button is pressed.
}

- (void) mouseDown: (NSEvent*)theEvent
{
  NSPoint	loc = [theEvent locationInWindow];
  NSView	*hit = [super hitTest: loc];
  
  [[self window] makeMainWindow];
  [[self window] makeFirstResponder: self];

  if (hit == rep)
    {
      int	pos = [rep indexOfItemAtPoint: loc];

      if (pos >= 0)
	{
	  NSMenuItem	*item = (NSMenuItem *)[edited itemAtIndex: pos];

	  if ([theEvent clickCount] == 2)
	    {
	      id cell;
	      NSTextField *tf;
	      NSRect frame;
	      [self makeSelectionVisible: NO];
	      [self selectObjects: [NSArray array]];
	      cell = [rep menuItemCellForItemAtIndex: pos];
	      tf = [[NSTextField alloc] initWithFrame: [self bounds]];
	      frame = (NSRect)[cell titleRectForBounds:
					     [rep rectOfItemAtIndex: pos]];
	      NSDebugLog(@"cell %@ (%@)", cell, [cell stringValue]);
	      frame.origin.y += 3;
  	      frame.size.height -= 5;
	      frame.origin.x += 1;
	      frame.size.width += 3;

	      [tf setFrame: frame];
	      [tf setEditable: YES];
	      [tf setBezeled: NO];
	      [tf setBordered: NO];
	      [self addSubview: tf];
	      [tf setStringValue: [[cell menuItem] title]];
	      [self editTextField: tf
		    withEvent: theEvent];
	      [[cell menuItem] setTitle: [tf stringValue]];
	      [tf removeFromSuperview];
	      RELEASE(tf);
	      return;
	    }

	  [self makeSelectionVisible: NO];
	  if ([theEvent modifierFlags] & NSShiftKeyMask)
	    {
	      NSMutableArray	*array;

	      array = [NSMutableArray arrayWithArray: selection];
	      if ([array containsObject: item] == YES)
		{
		  [array removeObject: item];
		}
	      else
		{
		  [array addObject: item];
		}
	      [self selectObjects: array];
	      [self makeSelectionVisible: YES];
	      return;
	    }

	  [self selectObjects: [NSArray arrayWithObject: item]];
	  if ([theEvent modifierFlags] & NSControlKeyMask)
	    {
	      NSPoint	dragPoint = [theEvent locationInWindow];
	      NSPasteboard	*pb;
	      NSString	*name = [document nameForObject: item];

	      pb = [NSPasteboard pasteboardWithName: NSDragPboard];
	      [pb declareTypes:
		[NSArray arrayWithObject: GormLinkPboardType]
			 owner: self];
	      [pb setString: name forType: GormLinkPboardType];
	      [[NSApp delegate] displayConnectionBetween: item and: nil];
	      [[NSApp delegate] startConnecting];

	      isLinkSource = YES;
	      [self dragImage: [[NSApp delegate] linkImage]
			   at: dragPoint
		       offset: NSZeroSize
			event: theEvent
		   pasteboard: pb
		       source: self
		    slideBack: YES];
	      isLinkSource = NO;
	    }
	  else
	    {
	      NSDate		*future = [NSDate distantFuture];
	      unsigned		eventMask;
	      NSEvent		*e;
	      NSEventType	eType;
	      BOOL		acceptsMouseMoved;
	      NSRect		frame = [rep innerRect];
	      float		maxMouse = NSMaxY(frame);
	      float		minMouse = NSMinY(frame);
	      NSPoint		lastPoint = loc;
	      NSPoint		point = loc;
	      NSRect		lastRect = [rep rectOfItemAtIndex: pos];
	      id		cell = [rep menuItemCellForItemAtIndex: pos];
	      int		newPos;

	      eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask
		| NSMouseMovedMask | NSPeriodicMask;
	      [[self window] setAcceptsMouseMovedEvents: YES];

	      /*
	       * Save window state info.
	       */
	      acceptsMouseMoved = [[self window] acceptsMouseMovedEvents];
	      [rep lockFocus];
	    
	      /*
	       * Track mouse movements until left mouse up.
	       * While we keep track of all mouse movements,
	       * we only act on a movement when a periodic
	       * event arives (every 20th of a second)
	       * in order to avoid excessive amounts of drawing.
	       */
	      [NSEvent startPeriodicEventsAfterDelay: 0.1 withPeriod: 0.05];
	      e = [NSApp nextEventMatchingMask: eventMask
				     untilDate: future
					inMode: NSEventTrackingRunLoopMode
				       dequeue: YES];
	      eType = [e type];
	      while (eType != NSLeftMouseUp)
		{
		  if (eType != NSPeriodic)
		    {
		      point = [e locationInWindow];
		    }
		  else if (NSEqualPoints(point, lastPoint) == NO)
		    {
		      /*
		       * Limit mouse movement.
		       */
		      point.x = NSMinX(frame);
		      if (point.y < minMouse)
			point.y = minMouse;
		      if (point.y > maxMouse)
			point.y = maxMouse;

		      if (NSEqualPoints(point, lastPoint) == NO)
			{
			  [[self window] disableFlushWindow];

			  /*
			   * Redraw cells under area being changed.
			   */
			  [rep drawRect: lastRect];

			  /*
			   * Update location.
			   */
			  lastRect.origin.y += point.y - lastPoint.y;
			  lastPoint = point;

			  /*
			   * Draw highlighted item being moved.
			   */
			  [cell highlight: YES withFrame: lastRect inView: rep];
			  [cell setHighlighted: NO];

			  /*
			   * Flush any drawing performed for this event.
			   */
			  [[self window] enableFlushWindow];
			  [[self window] flushWindow];
			}
		    }
		  e = [NSApp nextEventMatchingMask: eventMask
					 untilDate: future
					    inMode: NSEventTrackingRunLoopMode
					   dequeue: YES];
		  eType = [e type];
		}
	      [NSEvent stopPeriodicEvents];

	      [rep drawRect: lastRect];
	      [rep unlockFocus];
	      newPos = [rep indexOfItemAtPoint: point];
	      if (newPos < pos)
		{
		  NSMenuItem	*item = (NSMenuItem *)[edited itemAtIndex: pos];

		  RETAIN(item);
		  if (newPos < 0)
		    newPos = 0;
		  [edited removeItemAtIndex: pos];
		  [edited insertItem: item atIndex: newPos];
		  RELEASE(item);
		}
	      else if (newPos > pos)
		{
		  NSMenuItem	*item = (NSMenuItem *)[edited itemAtIndex: pos];

		  RETAIN(item);
		  [edited removeItemAtIndex: pos];
		  [edited insertItem: item atIndex: newPos];
		  RELEASE(item);
		}
	      [edited sizeToFit];
	      [edited display];
	      /*
	       * Restore state to what it was on entry.
	       */
	      [[self window] setAcceptsMouseMovedEvents: acceptsMouseMoved];
	    }
	  [self makeSelectionVisible: YES];
	}
    }
  else
    {
      /*
       * The mouse down wasn't over the menu items, so we just let the menu
       * handle it - but make sure the menu is selected in the editor first.
       */
      [[document parentEditorForEditor: self] selectObjects:
						[NSArray arrayWithObject: edited]];
      [hit mouseDown: theEvent];
    }
}

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  /*
   * A menu editor can accept menu items pasted in to it.
   */
  return [types containsObject: IBMenuPboardType];
}

- (BOOL) activate
{
  if (original == nil)
    {
      NSWindow		*w;
      NSEnumerator	*enumerator;
      NSView		*sub;
      NSMenuItem	*item;

      //
      // Swap ourselves in as a replacement for the original window
      // content view.
      //
      w = [rep window];
      original = RETAIN([w contentView]);
      [self setFrame: [original frame]];
      enumerator = [[original subviews] objectEnumerator];
      while ((sub = [enumerator nextObject]) != nil)
	{
	  [self addSubview: sub];
	}

      [w setContentView: self];

      //
      // Line up submenu with parent menu.
      //
      item = [document parentOfObject: edited];
      if (item != nil && [item isKindOfClass: [NSMenuItem class]])
	{
	  NSMenu	*parent = [document parentOfObject: item];
	  NSRect	frame = [[[parent menuRepresentation] window] frame];
	  NSPoint	tl;

	  tl = frame.origin;
	  tl.x += frame.size.width;
	  tl.y += frame.size.height;
	  
	  // if it's the main menu, display it when activated, otherwise don't.
	  if([[document nameForObject: edited] isEqual: @"NSMenu"])
	    {
	      [edited sizeToFit];
	      [[[edited menuRepresentation] window] setFrameTopLeftPoint: tl];
	    }
	}      
      return NO;
    }
  return YES;
}

- (void) close
{
  isClosed = YES;
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  if ([(id<IB>)[NSApp delegate] selectionOwner] == self)
    {
      [document resignSelectionForEditor: self];
    }

  [self closeSubeditors];
  [self deactivate];

  // if it's visible, close it.
  if([edited isVisible])
    {
      [edited close];
    }

  [document editor: self didCloseForObject: edited];
}

- (void) closeSubeditors
{
  if (subeditor != nil)
    {
      [subeditor close];
      DESTROY(subeditor);
    }
}

- (void) copySelection
{
  if ([selection count] > 0)
    {
      [document copyObjects: selection
		       type: IBMenuPboardType
	       toPasteboard: [NSPasteboard generalPasteboard]];
    }
}

- (void) deactivate
{
  if (original != nil)
    {
      NSEnumerator	*enumerator;
      NSView		*sub;

      RETAIN(self);
      /*
       * Swap ourselves out and the original window content view in.
       */
      [self makeSelectionVisible: NO];
      [original setFrame: [self frame]];
      [[rep window] setContentView: original];
      enumerator = [[self subviews] objectEnumerator];
      while ((sub = [enumerator nextObject]) != nil)
	{
	  [original addSubview: sub];
	}
      DESTROY(original);
      RELEASE(self);
    }
}

- (void) dealloc
{
  if (isClosed == NO)
    {
      [self close];
    }

  RELEASE(edited);
  RELEASE(selection);
  RELEASE(subeditor);
  [super dealloc];
}

- (void) deleteSelection
{
  if ([selection count] > 0)
    {
      NSArray	*s = [NSArray arrayWithArray: selection];
      NSEnumerator	*e = [s objectEnumerator];
      NSMenuItem	*i;
      NSArray       *d = nil;
     
      [self makeSelectionVisible: NO];
      [self selectObjects: [NSArray array]];
      
      // find all relavent objects.  Remove them from the nameTable.
      d = findAllSubmenus( s );
      [document detachObjects: d];
	  
      // remove the items from the menu...
      while ((i = [e nextObject]) != nil && [edited numberOfItems] > 0)
	{
	  [edited removeItem: i];
	}
      [edited sizeToFit];
      [edited display];
    }
}

/*
 *	Dragging source protocol implementation
 */
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f
{
  /*
   * FIXME - handle this.
   * Notification that a drag failed/succeeded.
   */
}

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)flag
{
  if (isLinkSource == YES)
    return NSDragOperationLink;
  else
    return NSDragOperationCopy;
}

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>)sender
{
  NSArray	*types;

  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  if ([types containsObject: IBMenuPboardType] == YES)
    {
      dragType = IBMenuPboardType;
    }
  else if ([types containsObject: GormLinkPboardType] == YES)
    {
      dragType = GormLinkPboardType;
    }
  else
    {
      dragType = nil;
    }
  return [self draggingUpdated: sender];
}

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>)sender
{
  if (dragType == IBMenuPboardType)
    {
      return NSDragOperationCopy;
    }
  else if (dragType == GormLinkPboardType)
    {
      NSPoint	loc = [sender draggingLocation];
      int	pos = [rep indexOfItemAtPoint: loc];
      id	item = nil;

      if (pos >= 0)
	{
	  item = [edited itemAtIndex: pos];
	}
      if (item == [[NSApp delegate] connectSource])
	{
	  item = nil;
	}
      [[NSApp delegate] displayConnectionBetween: [[NSApp delegate] connectSource] and: item];
      return NSDragOperationLink;
    }
  else
    {
      return 0;
    }
}

- (void)  draggingExited: (id<NSDraggingInfo>)sender
{
  if (dragType == GormLinkPboardType)
    {
      [[NSApp delegate] displayConnectionBetween: [[NSApp delegate] connectSource] 
	     and: nil];
    }
}


- (void) drawSelection
{
}

- (id<IBDocuments>) document
{
  return document;
}

- (id) editedObject
{
  return edited;
}

// find all subitems for the given items...
void _attachAllSubmenus(id menu, NSArray *items, id document)
{
  NSEnumerator *e = [items objectEnumerator];
  NSString *name = [document nameForObject: menu];
  id i = nil;
  
  // if it's the main menu, display it... otherwise..
  if([name isEqual: @"NSMenu"])
    {
      [menu display];
    }

  while((i = [e nextObject]) != nil)
    {
      [document attachObject: i toParent: menu];
      if([i hasSubmenu])
	{
	  id submenu = [i submenu];
	  NSArray *submenuItems = [submenu itemArray];
	  
	  [submenu setSupermenu: menu];
	  [document attachObject: submenu toParent: i];
	  _attachAllSubmenus(submenu, submenuItems, document);
	}
    }
}

void _attachAll(NSMenu *menu, id document)
{
  NSArray *items = [menu itemArray];
  _attachAllSubmenus(menu, items, document);
}

- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument
{
  self = [super init];
  if(self != nil)
    {
      document = aDocument;
      ASSIGN(edited, anObject);
      selection = [[NSMutableArray alloc] init];
      rep = [edited menuRepresentation];
      
      /*
       * Permit views and connections to be dragged in to the window.
       */
      [self registerForDraggedTypes: [NSArray arrayWithObjects:
						IBMenuPboardType, GormLinkPboardType, nil]];
      
      /*
       * Make sure that all our menu items are attached in the document.
       */
      _attachAll(edited, document);
    }

  return self;
}

- (void) makeSelectionVisible: (BOOL)flag
{
  if (flag == NO)
    {
      if ([selection count] > 0)
	{
	  NSEnumerator	*enumerator = [selection objectEnumerator];
	  NSMenuItem	*item;

	  [[self window] disableFlushWindow];
	  [rep lockFocus];
	  while ((item = [enumerator nextObject]) != nil)
	    {
	      int	pos = [edited indexOfItem: item];
	      id	cell = [rep menuItemCellForItemAtIndex: pos];
	      NSRect	rect = [rep rectOfItemAtIndex: pos];
	      
	      [cell highlight: NO withFrame: rect inView: rep];
	    }
	  [rep unlockFocus];
	  [[self window] enableFlushWindow];
	  [[self window] flushWindowIfNeeded];
	}
    }
  else
    {
      if ([selection count] > 0)
	{
	  NSEnumerator	*enumerator = [selection objectEnumerator];
	  NSMenuItem	*item;

	  [[self window] disableFlushWindow];
	  [rep lockFocus];
	  while ((item = [enumerator nextObject]) != nil)
	    {
	      int	pos = [edited indexOfItem: item];
	      id	cell = [rep menuItemCellForItemAtIndex: pos];
	      NSRect	rect = [rep rectOfItemAtIndex: pos];
	      
	      [cell highlight: YES withFrame: rect inView: rep];
	    }
	  [rep unlockFocus];
	  [[self window] enableFlushWindow];
	  [[self window] flushWindowIfNeeded];
	}
    }
}

- (id<IBEditors>) openSubeditorForObject: (id)anObject
{
  return nil;
}

- (void) orderFront
{
  [[edited window] orderFront: self];
}

- (void) pasteInSelection
{
  NSPasteboard	*pb = [NSPasteboard generalPasteboard];
  NSArray	*items;
  NSEnumerator	*enumerator;
  NSMenuItem	*item;

  /*
   * Ask the document to get the copied items from the pasteboard and add
   * them to it's collection of known objects.
   */
  items = [document pasteType: IBMenuPboardType
	       fromPasteboard: pb
		       parent: edited];
  
  enumerator = [items objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      if ([edited _ownedByPopUp])
	{
	  [item setOnStateImage: nil];
	  [item setMixedStateImage: nil];
	}
      [edited addItem: item];
    }
  [edited sizeToFit];
  [edited display];
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  NSRect	f = [rep frame];

  if (dragType == IBMenuPboardType)
    {
      NSPoint		loc = [sender draggedImageLocation];
      NSArray		*items;
      NSEnumerator	*enumerator;
      NSMenuItem	*item;
      int		pos;

      /*
       * Adjust location so that it lies within horizontal bounds, and so that
       * it appears about half an item higher than it is.  That way, we treat
       * a drop in the lower half of an item as an insertion below it, and a
       * drop in the upper half as an insertion above it.
       */
      if (loc.x < NSMinX(f))
	loc.x = NSMinX(f);
      if (loc.x > NSMaxX(f))
	loc.x = NSMaxX(f);
      loc.y += 10;
      pos = [rep indexOfItemAtPoint: loc] + 1;

      [self makeSelectionVisible: NO];
      /*
       * Ask the document to get the dragged views from the pasteboard and add
       * them to it's collection of known objects.
       */
      items = [document pasteType: IBMenuPboardType
		   fromPasteboard: dragPb
			   parent: edited];

      // Test to see if the first item is a menu, if so reject the drag.  If the
      // first item is a menu item, accept it.
      if([items count] > 0)
	{
	  id itemZero = [items objectAtIndex: 0];
	  if([itemZero isKindOfClass: [NSMenu class]])
	    {
	      return NO;
	    }
	}

      // enumerate through the items and add them.
      enumerator = [items objectEnumerator];
      while ((item = [enumerator nextObject]) != nil)
	{
	  if ([edited _ownedByPopUp])
	    {
	      NSDebugLog(@"owned by popup");
	      [item setOnStateImage: nil];
	      [item setMixedStateImage: nil];

	      // if the item has a submenu, reject the drag.
	      if([item hasSubmenu])
		{
		  return NO;
		}
	    }
	  else
	    NSDebugLog(@"not owned by popup");
	  [edited insertItem: item atIndex: pos++];
	}
      [edited sizeToFit];
      [edited display];
      [self selectObjects: items];
      [self makeSelectionVisible: YES];
    }
  else if (dragType == GormLinkPboardType)
    {
      NSPoint	loc = [sender draggingLocation];
      int	pos = [rep indexOfItemAtPoint: loc];

      NSDebugLog(@"Link at index: %d (%@)", pos, NSStringFromPoint(loc));
      if (pos >= 0)
	{
	  id	item = [edited itemAtIndex: pos];

	  [[NSApp delegate] displayConnectionBetween: [[NSApp delegate] connectSource] and: item];
	  [[NSApp delegate] startConnecting];
	}
    }
  else
    {
      NSDebugLog(@"Drop with unrecognized type (%@)!", dragType);
      dragType = nil;
      return NO;
    }
  dragType = nil;
  return YES;
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>)sender
{
  /*
   * Tell the source that we will accept the drop if we can.
   */
  if (dragType == IBMenuPboardType)
    {
      /*
       * We can accept menus dropped anywhere.
       */
      return YES;
    }
  else if (dragType == GormLinkPboardType)
    {
      /*
       * We can accept a link dropped on any of our items.
       */
      return YES;
    }
  return NO;
}

/*
 * Return the rectangle in which an objects link status will be displayed.
 */
- (NSRect) rectForObject: (id)anObject
{
  int		pos = [edited indexOfItem: anObject];
  NSRect	rect;

  if (pos >= 0)
    {
      rect = [rep rectOfItemAtIndex: pos];
      rect = [rep convertRect: rect toView: nil];
    }
  else
    {
      rect = [self frame];
    }
  return rect;
}

- (void) resetObject: (id)anObject
{
  [[self window] makeKeyAndOrderFront: self];
}

- (void) selectObjects: (NSArray*)anArray
{
  if ([anArray isEqual: selection] == NO)
    {
      NSUInteger	count;
      NSMenuItem	*item;

      [selection removeAllObjects];
      NSDebugLog(@"selectObjects %@ %@", selection, anArray);
      [selection addObjectsFromArray: anArray];

      count = [selection count];

      /*
       * We can only select items in our menu - discard others.
       */
      while (count-- > 0)
	{
	  id	o = [selection objectAtIndex: count];

	  if ([edited indexOfItem: o] == NSNotFound)
	    {
	      [selection removeObjectAtIndex: count];
	    }
	}
      item = [selection lastObject];
      if ([selection count] != 1 || [item hasSubmenu] == NO)
	{
	  [self closeSubeditors];
	}
      else
	{
	  NSMenu	*menu;
	  id<IBEditors>	editor;

	  /*
	   * A single item with a submenu is selected -
	   * Make sure the submenu is registered in the document and
	   * open an editor for it  Close any existing subeditor.
	   */
	  menu = [item submenu];
	  if ([document containsObject: menu] == NO)
	    {
	      [document attachObject: menu toParent: item];
	    }
	  editor = [document editorForObject: menu create: YES];
	  if (subeditor != nil && subeditor != editor)
	    {
	      [self closeSubeditors];
	    }
	  [menu display];
	  [[item submenu] display];
	  [editor orderFront];
	  [editor activate];
	  ASSIGN(subeditor, editor);
	}
    }

  /*
   * Now we must let the document (and hence the rest of the app) know
   * about our new selection.  If there is nothing in it, make sure
   * that our edited window is selected instead.
   */
  if ([selection count] > 0)
    {
      [document setSelectionFromEditor: self];
    }

  /*
  else
    {
      id ed = nil;
      //GormObjectEditor	*ed;

      ed = [GormObjectEditor editorForDocument: document];
      [ed selectObjects: [NSArray arrayWithObject: edited]];
    }
  */
}

- (NSArray*) selection
{
  return [NSArray arrayWithArray: selection];
}

- (NSUInteger) selectionCount
{
  return [selection count];
}

- (void) validateEditing
{
}

- (BOOL) wantsSelection
{
  /*
   * We only want to be the selection owner if we are active (have been
   * swapped for the windows original content view) and if we have some
   * object selected.
   */
  if (original == nil)
    return NO;
  if ([selection count] == 0)
    return NO;
  return YES;
}

- (NSWindow*) window
{
  return [super window];
}
@end

static BOOL done_editing;

@implementation GormMenuEditor (EditingAdditions)
- (void) handleNotification: (NSNotification*)aNotification
{
  NSString	*name = [aNotification name];
  if ([name isEqual: NSControlTextDidEndEditingNotification] == YES)
    {
      done_editing = YES;
      [document setSelectionFromEditor: self]; // Correction for Bug#11410
      // [self selectObjects: [NSArray arrayWithObject: edited]];
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

  [[self document] touch];
  
  return e;
}
@end
