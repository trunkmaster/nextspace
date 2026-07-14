/* GormObjectEditor.m
 *
 * Copyright (C) 1999,2002,2003,2004,2005 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2002,2003,2004,2005
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

#import <AppKit/AppKit.h>
#import <InterfaceBuilder/InterfaceBuilder.h>

#import "GormPrivate.h"
#import "GormObjectEditor.h"
#import "GormFunctions.h"
#import "GormDocument.h"
#import "GormClassManager.h"
#import "GormAbstractDelegate.h"

@implementation NSObject (GormObjectAdditions)
/*
 * Method to return the image that should be used to display objects within
 * the matrix containing the objects in a document.
 */
- (NSImage*) imageForViewer
{
  static NSImage       *image = nil;
  GormAbstractDelegate *delegate = (GormAbstractDelegate *)[NSApp delegate];

  if (image == nil && [delegate isInTool] == NO)
    {
      NSBundle	*bundle = [NSBundle bundleForClass: [self class]];
      NSString *path = [bundle pathForImageResource: @"GormUnknown"]; 
      image = [[NSImage alloc] initWithContentsOfFile: path];
    }

  return image;
}

- (NSString*) inspectorClassName
{
  return @"GormObjectInspector";
}

- (NSString*) connectInspectorClassName
{
  return @"GormConnectionInspector";
}

- (NSString*) sizeInspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (NSString*) helpInspectorClassName
{
  return @"GormNotApplicableInspector";
}

- (NSString*) classInspectorClassName
{
  return @"GormCustomClassInspector";
}

- (NSString*) editorClassName
{
  return @"GormObjectEditor";
}

@end

@implementation NSView (GormObjectAdditions)
- (NSString*) helpInspectorClassName
{
  return @"GormHelpInspector";
}
@end

@implementation	GormObjectEditor

static NSMapTable	*docMap = 0;

+ (void) initialize
{
  if (self == [GormObjectEditor class])
    {
      docMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
				NSNonRetainedObjectMapValueCallBacks, 
				2); 
    }
}

+ (id) editorForDocument: (id<IBDocuments>)aDocument
{
  id	editor = NSMapGet(docMap, (void*)aDocument);

  if (editor == nil)
    {
      editor = [[self alloc] initWithObject: nil inDocument: aDocument];
      AUTORELEASE(editor);
    }
  return editor;
}

+ (void) setEditor: (id)editor
       forDocument: (id<IBDocuments>)aDocument
{
  NSMapInsert(docMap, (void*)aDocument, (void*)editor);
}

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  return ([[(GormDocument *)document allManagedPboardTypes] firstObjectCommonWithArray: types] != nil);
}

- (void) pasteInSelection
{
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  NSString *type = [[(GormDocument *)document allManagedPboardTypes] firstObjectCommonWithArray: [pb types]];

  if(type != nil)
    {
      // paste the object in.
      [document pasteType: type
		fromPasteboard: pb
		parent: nil];
    }
}

- (void) copySelection
{
  NSArray *sel = [self selection];
  if([sel count] > 0)
    {
      NSString *type = nil;
      id obj = [sel objectAtIndex: 0];

      if([obj isKindOfClass: [NSWindow class]])
	{
	  type = IBWindowPboardType;
 	}
      else if([obj isKindOfClass: [NSView class]])
	{
	  type = IBViewPboardType;
	}
      else
	{
	  type = IBObjectPboardType;
	}

      [document copyObjects: sel
		type: type
		toPasteboard: [NSPasteboard generalPasteboard]];
    }
}

- (void) deleteSelection
{
  if (selected != nil
      && [[document nameForObject: selected] isEqualToString: @"NSOwner"] == NO
      && [[document nameForObject: selected] isEqualToString: @"NSFirst"] == NO)
    {
      if ([selected isKindOfClass: [NSMenu class]] &&
	  [[document nameForObject: selected] isEqual: @"NSMenu"] == YES)
	{
	  NSString *title = _(@"Removing Main Menu");
	  NSString *msg = _(@"Are you sure you want to do this?");
	  NSInteger retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);
	  
	  // if the user *really* wants to delete the menu, do it.
	  if(retval != NSAlertDefaultReturn)
	    return;
	}

      [document detachObject: selected];
      if ([selected isKindOfClass: [NSWindow class]] == YES)
	{
	  NSArray *subviews = allSubviews([(NSWindow *)selected contentView]);
	  [document detachObjects: subviews];
	  [selected close];
	}
      
      if ([selected isKindOfClass: [NSMenu class]] == YES)
	{
	  NSArray *items = findAll( selected );
	  NSEnumerator *en = [items objectEnumerator];
	  id obj = nil;
	  
	  while((obj = [en nextObject]) != nil)
	    {
	      [document detachObject: obj];
	    }
	}
      
      [objects removeObjectIdenticalTo: selected];
      [self selectObjects: [NSArray array]];
      [self refreshCells];
    }
}

/*
 *	Dragging source protocol implementation
 */
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f
{
}

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>)sender
{
  NSArray   *pbTypes = nil;
  
  // Get the resource manager first, if nil don't bother calling the rest...
  dragPb = [sender draggingPasteboard];
  pbTypes = [dragPb types];
  
  if ([pbTypes containsObject: GormLinkPboardType] == YES)
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
  if (dragType == GormLinkPboardType)
    {
      NSPoint	loc = [sender draggingLocation];
      NSInteger	r, c;
      int	pos;
      id	obj = nil;
      id        delegate = [NSApp delegate];
      
      loc = [self convertPoint: loc fromView: nil];
      [self getRow: &r column: &c forPoint: loc];
      pos = r * [self numberOfColumns] + c;
      if (pos >= 0 && pos < [objects count])
	{
	  obj = [objects objectAtIndex: pos];
	}
      if (obj == [delegate connectSource])
	{
	  return NSDragOperationNone;	/* Can't drag an object onto itsself */
	}

      [delegate displayConnectionBetween: [delegate connectSource] and: obj];
      if (obj != nil)
	{
	  return NSDragOperationLink;
	}

      return NSDragOperationNone;
    }

  return NSDragOperationNone;
}


/**
 * Used for autoscrolling when you connect IBActions.
 * FIXME: Maybye there is a better way to do it.
*/
- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    if (dragType == GormLinkPboardType)
      {
	NSRect documentVisibleRect;
	NSRect documentRect;
	NSPoint	loc = [sender draggingLocation];

	loc = [self convertPoint:loc fromView:nil];
	documentVisibleRect = [(NSClipView *)[self superview] documentVisibleRect];
	documentRect = [(NSClipView *)[self superview] documentRect];
	
	/* Down */
	if ( (loc.y >= documentVisibleRect.size.height) 
	     && ( ! NSEqualRects(documentVisibleRect,documentRect) ) ) 
	  {
	    loc.x = 0;
	    loc.y = documentRect.origin.y + [self cellSize].height;
	    [(NSClipView*) [self superview] scrollToPoint:loc];
	  } 
	/* up */
	else if ( (loc.y + 10 >= documentVisibleRect.origin.y ) 
		  && ( ! NSEqualRects(documentVisibleRect,documentRect) ) ) 
	{
	  loc.x = 0;
	  loc.y = documentRect.origin.y - [self cellSize].height; 
	  [(NSClipView*) [self superview] scrollToPoint:loc];
	}

      }
}

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)flag
{
  return NSDragOperationLink;
}

- (void) drawSelection
{
}

- (void) handleNotification: (NSNotification*)aNotification
{
  NSString *name = [aNotification name];

  if([name isEqual: GormResizeCellNotification])
    {
      NSDebugLog(@"Received notification");
      [self setCellSize: defaultCellSize()];
    }
}

/*
 *	Initialisation - register to receive DnD with our own types.
 */
- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument
{
  id	old = NSMapGet(docMap, (void*)aDocument);

  if (old != nil)
    {
      RELEASE(self);
      self = RETAIN(old);
      [self addObject: anObject];
      return self;
    }

  self = [super initWithObject: anObject inDocument: aDocument];
  if (self != nil)
    {
      NSButtonCell	*proto;
      NSColor *color = [NSColor colorWithCalibratedRed: 0.850980 
                                green: 0.737255
                                blue: 0.576471
                                alpha: 0.0 ];

      document = aDocument;
      
      [self registerForDraggedTypes:[NSArray arrayWithObject:GormLinkPboardType]];
      [self setAutosizesCells: NO];
      [self setCellSize: defaultCellSize()];
      [self setIntercellSpacing: NSMakeSize(8,8)];
      [self setAutoresizingMask: NSViewMinYMargin|NSViewWidthSizable];
      [self setMode: NSRadioModeMatrix];
      /*
       * Send mouse click actions to self, so we can handle selection.
       */
      [self setAction: @selector(changeSelection:)];
      [self setDoubleAction: @selector(raiseSelection:)];
      [self setTarget: self];

      // set the background color.
      [self setBackgroundColor: color];

      objects = [[NSMutableArray alloc] init];
      proto = [[NSButtonCell alloc] init];
      [proto setBordered: NO];
      [proto setAlignment: NSCenterTextAlignment];
      [proto setImagePosition: NSImageAbove];
      [proto setSelectable: NO];
      [proto setEditable: NO];
      [self setPrototype: proto];
      RELEASE(proto);
      [self setEditor: self
	    forDocument: aDocument];
      [self addObject: anObject];

      // set up the notification...
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(handleNotification:)
	name: GormResizeCellNotification
	object: nil];

      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(handleNotification:)
	name: IBResourceManagerRegistryDidChangeNotification
	object: nil];
    }
  return self;
}

- (void) willCloseDocument: (NSNotification *)aNotification
{
  NSMapRemove(docMap,document);
  [super willCloseDocument: aNotification];
}

- (void) close
{
  [super close];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  NSMapRemove(docMap,document);
}

- (void) makeSelectionVisible: (BOOL)flag
{
  if (flag == YES && selected != nil)
    {
      unsigned	pos = [objects indexOfObjectIdenticalTo: selected];
      int	r = pos / [self numberOfColumns];
      int	c = pos % [self numberOfColumns];

      [self selectCellAtRow: r column: c];
    }
  else
    {
      [self deselectAllCells];
    }
  [self displayIfNeeded];
  [[self window] flushWindow];
}

- (void) mouseDown: (NSEvent*)theEvent
{
  if ([theEvent modifierFlags] & NSControlKeyMask)
    {
      NSPoint	loc = [theEvent locationInWindow];
      NSString	*name;
      NSInteger	r = 0, c = 0;
      int	pos = 0;
      id	obj = nil;

      loc = [self convertPoint: loc fromView: nil];
      [self getRow: &r column: &c forPoint: loc];
      pos = r * [self numberOfColumns] + c;
      if (pos >= 0 && pos < [objects count])
	{
	  obj = [objects objectAtIndex: pos];
	}
      if (obj != nil && obj != selected)
	{
	  [self selectObjects: [NSArray arrayWithObject: obj]];
	  [self makeSelectionVisible: YES];
	}
      name = [document nameForObject: obj];
      if ([name isEqualToString: @"NSFirst"] == NO && name != nil)
	{
	  NSPasteboard	*pb;

	  pb = [NSPasteboard pasteboardWithName: NSDragPboard];
	  [pb declareTypes: [NSArray arrayWithObject: GormLinkPboardType]
		     owner: self];
	  [pb setString: name forType: GormLinkPboardType];
	  [[NSApp delegate] displayConnectionBetween: obj and: nil];
	  [[NSApp delegate] startConnecting];

	  [self dragImage: [[NSApp delegate] linkImage]
		       at: loc
		   offset: NSZeroSize
		    event: theEvent
	       pasteboard: pb
		   source: self
		slideBack: YES];
	  [self makeSelectionVisible: YES];
	  return;
	}
    }

  [super mouseDown: theEvent];
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  if (dragType == GormLinkPboardType)
    {
      NSPoint	loc = [sender draggingLocation];
      NSInteger	r, c;
      int	pos;
      id	obj = nil;

      loc = [self convertPoint: loc fromView: nil];
      [self getRow: &r column: &c forPoint: loc];
      pos = r * [self numberOfColumns] + c;
      if (pos >= 0 && pos < [objects count])
	{
	  obj = [objects objectAtIndex: pos];
	}
      if (obj == nil)
	{
	  return NO;
	}
      else
	{
	  [[NSApp delegate] displayConnectionBetween: [NSApp connectSource] and: obj];
	  [[NSApp delegate] startConnecting];
	  return YES;
	}
    }
  else
    {
      NSLog(@"Drop with unrecognized type!");
      return NO;
    }
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>)sender
{
  /*
   * Tell the source that we will accept the drop if we can.
   */
  if (dragType == GormLinkPboardType)
    {
      NSPoint	loc = [sender draggingLocation];
      NSInteger	r, c;
      int	pos;
      id	obj = nil;

      loc = [self convertPoint: loc fromView: nil];
      [self getRow: &r column: &c forPoint: loc];
      pos = r * [self numberOfColumns] + c;
      if (pos >= 0 && pos < [objects count])
	{
	  obj = [objects objectAtIndex: pos];
	}
      if (obj != nil)
	{
	  return YES;
	}
    }
  return NO;
}

- (id) raiseSelection: (id)sender
{
  id	obj = [self changeSelection: sender];
  id	e;

  if(obj != nil)
    {
      e = [document editorForObject: obj create: YES];
      [e orderFront];
      [e resetObject: obj];
    }

  return self;
}

- (void) resetObject: (id)anObject
{
  NSString		*name = [document nameForObject: anObject];
  GormInspectorsManager	*mgr = [(id<GormAppDelegate>)[NSApp delegate] inspectorsManager];

  if ([name isEqual: @"NSOwner"] == YES)
    {
      [mgr setClassInspector];
    }
  if ([name isEqual: @"NSFirst"] == YES)
    {
      [mgr setClassInspector];
    }
}

- (void) addObject:(id)anObject
{
  [super addObject:anObject];
  /* we need to do this for palettes which can drop top level objects */
  [(GormDocument *)document changeToViewWithTag:0];
}


@end


