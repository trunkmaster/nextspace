/* GormClassEditor.m
 *
 * Copyright (C) 1999, 2003 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2003
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

#include "GormClassEditor.h"
#include "GormClassManager.h"
#include "GormFunctions.h"
#include "GormDocument.h"
#include "GormProtocol.h"
#include "GormPrivate.h"

NSString *GormClassPboardType = @"GormClassPboardType";
NSString *GormSwitchViewPreferencesNotification = @"GormSwitchViewPreferencesNotification";
NSImage *outlineImage = nil;
NSImage *browserImage = nil;

@interface GormOutlineView (PrivateMethods)
- (void) _addNewActionToObject: (id)item;
- (void) _addNewOutletToObject: (id)item;
@end

@interface GormClassEditor (PrivateMethods)
- (void) browserClick: (id)sender;
- (void) toggleView: (id) sender;
- (void) switchViewToDefault;
- (void) handleNotification: (NSNotification *)notification;
@end

@implementation	GormClassEditor

+ (void) initialize
{
  if(self == [GormClassEditor class])
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      NSString *path = nil;

      path = [bundle pathForImageResource: @"outlineView"];
      outlineImage = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"browserView"];
      browserImage = [[NSImage alloc] initWithContentsOfFile: path];
    }
}

- (GormClassEditor*) initWithDocument: (GormDocument*)doc
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];

      if([bundle loadNibNamed: @"GormClassEditor" owner: self topLevelObjects: NULL])
	{
	  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
	  NSRect		 scrollRect = [classesView frame]; //  = {{0, 0}, {340, 188}};
	  NSRect		 mainRect = NSMakeRect(20,0,scrollRect.size.width-20,
						       scrollRect.size.height); 
	  NSColor *color = [NSColor colorWithCalibratedRed: 0.850980 
                                    green: 0.737255
                                    blue: 0.576471
                                    alpha: 1.0 ];
	  NSTableColumn         *tableColumn;

	  // setup the view...
	  [self setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
	  [self setFrame: [mainView frame]];
	  [self addSubview: mainView];
	  
	  // set up the scroll view.
	  scrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
	  [scrollView setHasVerticalScroller: YES];
	  [scrollView setHasHorizontalScroller: NO];
	  [scrollView setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
	  [scrollView setBorderType: NSBezelBorder];
	  
	  // allocate the outline view.
	  outlineView = [[GormOutlineView alloc] init];
	  [outlineView setFrame: scrollRect];
	  [outlineView setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
	  [scrollView setDocumentView: outlineView];
	  // [outlineView sizeToFit];
	  RELEASE(outlineView);
	  	  
	  // weak connections...
	  document = doc; 
	  classManager = [doc classManager];
	  
	  // set up the outline view...
	  [outlineView setDataSource: self];
	  [outlineView setDelegate: self];
	  
	  [outlineView setAutoresizesAllColumnsToFit: YES];
	  [outlineView setAllowsColumnResizing: NO];
	  [outlineView setDrawsGrid: NO];
	  [outlineView setIndentationMarkerFollowsCell: YES];
	  [outlineView setAutoresizesOutlineColumn: YES];
	  [outlineView setIndentationPerLevel: 10];
	  [outlineView setAttributeOffset: 30];
	  [outlineView setRowHeight: 18];
	  [outlineView setMenu: [(id<GormAppDelegate>)[NSApp delegate] classMenu]]; 
	  [outlineView setBackgroundColor: color];
	  
	  // add the table columns...
	  tableColumn = [(NSTableColumn *)[NSTableColumn alloc] initWithIdentifier: @"classes"];
	  [[tableColumn headerCell] setStringValue: _(@"Classes")];
	  [tableColumn setMinWidth: 190];
	  [tableColumn setResizable: YES];
	  [tableColumn setEditable: YES];
	  [outlineView addTableColumn: tableColumn];     
	  [outlineView setOutlineTableColumn: tableColumn];
	  RELEASE(tableColumn);
	  
	  tableColumn = [(NSTableColumn *)[NSTableColumn alloc] initWithIdentifier: @"outlets"];
	  [[tableColumn headerCell] setStringValue: _(@"Outlet")];
	  [tableColumn setWidth: 50]; 
	  [tableColumn setResizable: NO];
	  [tableColumn setEditable: NO];
	  [outlineView addTableColumn: tableColumn];
	  [outlineView setOutletColumn: tableColumn];
	  RELEASE(tableColumn);
	  
	  tableColumn = [(NSTableColumn *)[NSTableColumn alloc] initWithIdentifier: @"actions"];
	  [[tableColumn headerCell] setStringValue: _(@"Action")];
	  [tableColumn setWidth: 50]; 
	  [tableColumn setResizable: NO];
	  [tableColumn setEditable: NO];
	  [outlineView addTableColumn: tableColumn];
	  [outlineView setActionColumn: tableColumn];
	  RELEASE(tableColumn); 
	  
	  // expand all of the items in the classesView...
	  // [outlineView expandItem: @"NSObject"];
	  [outlineView setFrame: scrollRect];
	  
	  // allocate the NSBrowser view.
	  browserView = [[NSBrowser alloc] initWithFrame: mainRect];
	  [browserView setRefusesFirstResponder:YES];
	  [browserView setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
	  [browserView setTitled:NO];
	  [browserView setMaxVisibleColumns:3];
	  [browserView setSeparatesColumns:NO];
	  [browserView setAllowsMultipleSelection:YES];
	  [browserView setDelegate:self];
	  [browserView setTarget:self];
	  [browserView setAction: @selector(browserClick:)];
	  // [browserView setDoubleAction: nil]; // @selector(doubleClick:)];
	  [browserView setRefusesFirstResponder:YES];
	  [browserView loadColumnZero];
	  
	  // observe certain notifications...
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: GormSwitchViewPreferencesNotification
	      object: nil];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: GormDidAddClassNotification
	      object: nil];
	  
	  // kludge to prevent it from having resize issues.
	  [classesView setContentView: scrollView];
	  [classesView sizeToFit];
	  
	  // switch...
	  [self switchViewToDefault]; 
	}
      else
	{
	  return nil;
	}
    }
  return self;
}
  
+ (GormClassEditor*) classEditorForDocument: (GormDocument*)doc
{
  return AUTORELEASE([(GormClassEditor *)[self alloc] initWithDocument: doc]);
}

- (void) toggleView: (id) sender
{
  id contentView = [classesView contentView];
  if(contentView == browserView)
    {
      NSRect rect = [classesView frame];
      [classesView setContentView: scrollView];
      [outlineView setFrame: rect];
      [outlineView sizeToFit];
      [viewToggle setImage: browserImage];
    }
  else if(contentView == scrollView)
    {
      [classesView setContentView: browserView];
      [viewToggle setImage: outlineImage];
    }

  [self setSelectedClassName: selectedClass];
}

- (void) switchViewToDefault
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *viewType = [ud stringForKey: @"ClassViewType"];

  if([viewType isEqual: @"Outline"] || viewType == nil)
    {
      NSRect rect = [classesView frame];
      [classesView setContentView: scrollView];
      [outlineView setFrame: rect];
      [outlineView sizeToFit];
      [viewToggle setImage: browserImage];
    }
  else if([viewType isEqual: @"Browser"])
    {
      [classesView setContentView: browserView];
      [viewToggle setImage: outlineImage];
    }

  [self setSelectedClassName: selectedClass];
}

- (void) handleNotification: (NSNotification *)notification
{
  if([[notification name] isEqualToString: GormSwitchViewPreferencesNotification])
    {
      [self switchViewToDefault];
    }
}

- (void) browserClick: (id)sender
{
  NSString *className = [[sender selectedCell] stringValue];
  ASSIGN(selectedClass, className);
  [document setSelectionFromEditor: (id)self];
}

- (void) dealloc
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver: self];
  RELEASE(scrollView);
  RELEASE(browserView);
  RELEASE(selectedClass);
  [super dealloc];
}

- (void) setSelectedClassName: (NSString*)cn
{
  [self selectClass: cn];
}

- (NSString *)selectedClassName
{
  id className = nil;

  NS_DURING
    {
      if([classesView contentView] == scrollView)
	{
	  NSInteger row =  [outlineView selectedRow];	  
	  if ( row == -1 ) 
	    {
	      row = 0;
	    }

	  className = [outlineView itemAtRow: row];	  
	  if ([className isKindOfClass: [GormOutletActionHolder class]])
	    {
	      className = [outlineView itemBeingEdited];
	    }
	}
      else if([classesView contentView] == browserView)
	{
	  className = [[browserView selectedCell] stringValue];
	}
    }
  NS_HANDLER
    {
      NSLog(@"%@",[localException reason]);
    }
  NS_ENDHANDLER;

  return className;
}

- (void) selectClass: (NSString *)className
{
  [self selectClass: className editClass: YES];
}

// class selection...
- (void) selectClass: (NSString *)className editClass: (BOOL)flag
{
  NS_DURING
    {
      NSString	 *currentClass = nil;
      NSArray	 *classes, *subclasses;
      NSMutableArray *subClassesArray = [NSMutableArray array];
      NSEnumerator	 *en;
      int		 row = 0;
      NSInteger            col = 0;
      
      if ( ( className != nil )  
	   && ( [className isEqual: @"CustomView"] == NO )
	   && ( [className isEqual: @"GormSound"] == NO ) 
	   && ( [className isEqual: @"GormImage"] == NO ) 
	   && ( [outlineView isEditing] == NO ) ) 
	{
	  classes = [classManager allSuperClassesOf: className]; 
	  en = [classes objectEnumerator];
	  // open the items...
	  while ((currentClass = [en nextObject]) != nil)
	    {
	      [outlineView expandItem: currentClass];
	    }
	  
	  // select the item in the outline view...
	  row = [outlineView rowForItem: className];
	  if (row != -1) 
	    {
	      [outlineView selectRow: row byExtendingSelection: NO];
	      [outlineView scrollRowToVisible: row];
	    }
	  
	  // select class in browser...
	  subClassesArray = [NSMutableArray arrayWithArray: [classManager allSuperClassesOf: className]];
	  if ((subClassesArray != nil && [subClassesArray count] != 0) ||
	      [classManager isRootClass: className] == YES)
	    {
	      [subClassesArray addObject: className]; // include in the list.
	      
	      // Get the super class position in the browser.  Passing "nil" to subClassesOf causes it
	      // to get all of the root classes.
	      col = 0;
	      row = [[classManager subClassesOf: nil] indexOfObject: [subClassesArray objectAtIndex: 0]];
	      
	      // reset the enumerator...
	      currentClass = nil;
	      [browserView reloadColumn:col];  
	      
	      // if row is not NSNotFound, then we found something.
	      if(row != -1)
		{
		  [browserView selectRow: row inColumn: col];
		  en = [subClassesArray objectEnumerator];
		  [en nextObject]; // skip the first one.
		  while((currentClass = [en nextObject]) != nil)
		    {
		      NSString *prevClass = [[browserView selectedCellInColumn: col] stringValue];
		      subclasses = [classManager subClassesOf: prevClass];
		      row = [subclasses indexOfObject: currentClass];
		      col++;
		      [browserView selectRow:row inColumn:col];
		    }
		}
	      
	      ASSIGN(selectedClass, className);
	      
	      if(flag)
		{
		  // set the editor...
		  [document setSelectionFromEditor: (id)self];
		}
	    }
	}
    }
  NS_HANDLER
    {
      NSDebugLog(@"%@",[localException reason]);
    }
  NS_ENDHANDLER;
}

- (void) selectClassWithObject: (id)obj 
{
  [self selectClassWithObject: obj editClass: YES];
}

- (void) selectClassWithObject: (id)object editClass: (BOOL)flag
{
  id obj = object;
  NSString *customClass = nil;

  // if it's a scrollview focus on it's contents.
  if([obj isKindOfClass: [NSScrollView class]])
    {
      id newobj = nil;
      newobj = [obj documentView];
      if(newobj != nil)
	{
	  obj = newobj;
	}
    }
  
  // check for a custom class.
  customClass = [classManager customClassForObject: obj];
  if(customClass != nil)
    {
      [self selectClass: customClass editClass: flag];
    }
  else if ([obj respondsToSelector: @selector(className)])
    { 
      [self selectClass: [obj className] editClass: flag];
    }
}

- (BOOL) currentSelectionIsClass
{  
  BOOL result = NO;

  if([classesView contentView] == scrollView)
    {
      NSInteger i = [outlineView selectedRow];
      
      if (i >= 0 && i <= ([outlineView numberOfRows] - 1))
	{
	  NS_DURING
	    {
	      id object = [outlineView itemAtRow: i];
	      if([object isKindOfClass: [NSString class]])
		{
		  result = YES;
		}
	    }
	  NS_HANDLER
	    {
	      NSLog(@"%@",[localException reason]);
	    }
	  NS_ENDHANDLER;
	}
    }
  else if([classesView contentView] == browserView)
    {
      result = YES;
    }

  return result;
}

- (void) editClass
{
  int	row = [outlineView selectedRow];

  if (row >= 0)
    {
      ASSIGN(selectedClass, [self selectedClassName]);
      [document setSelectionFromEditor: (id)self];
    }
}

//--- IBSelectionOwners protocol ---
- (NSUInteger) selectionCount
{
  return ([outlineView selectedRow] == -1)?0:1;
}

- (NSArray*) selection
{
  // when asked for a selection, it returns a class proxy
  if (selectedClass != nil) 
    {
      NSArray		*array;
      GormClassProxy	*classProxy;
      NSString          *sc = [NSString stringWithString: selectedClass];

      classProxy = [[GormClassProxy alloc] initWithClassName: sc];
      array = [NSArray arrayWithObject: classProxy];
      RELEASE(classProxy);
      return array;
    } 
  else
    {
      return [NSArray array];
    }
}

- (void) drawSelection
{
}

- (void) makeSelectionVisible: (BOOL)flag
{
}

- (void) selectObjects: (NSArray*)objects
{
  id obj = [objects objectAtIndex: 0];
  [self selectClassWithObject: obj];
}

- (void) deleteSelection
{
  id anitem;
  NSInteger i = [outlineView selectedRow];
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  
  // if no selection, then return.
  if (i == -1)
    {
      return;
    }

  // get the item, and catch the exception, if there's a problem.
  if([classesView contentView] == outlineView)
    {
      NS_DURING
	{
	  anitem = [outlineView itemAtRow: i];
	}
      NS_HANDLER
	{
	  anitem = nil;
	}
      NS_ENDHANDLER;
    }
  else
    {
      anitem = [[browserView selectedCell] stringValue];
    }

  if(anitem == nil)
    return;
  
  if ([anitem isKindOfClass: [GormOutletActionHolder class]])
    {
      id itemBeingEdited = [outlineView itemBeingEdited];
      NSString *name = [anitem getName];

      // if the class being edited is a custom class or a category, 
      // then allow the deletion...
      if ([classManager isCustomClass: itemBeingEdited] ||
	  [classManager isAction: name onCategoryForClassNamed: itemBeingEdited])
	{
	  if ([outlineView editType] == Actions)
	    {
	      // if this action is an action on the class, not it's superclass
	      // allow the deletion...
	      if ([classManager isAction: name
			       ofClass: itemBeingEdited])
		{
		  BOOL removed = [document removeConnectionsWithLabel: name 
					   forClassNamed: itemBeingEdited
					   isAction: YES];
		  if (removed)
		    {
		      [classManager removeAction: name
				    fromClassNamed: itemBeingEdited];
		      [outlineView removeItemAtRow: i];
		      [nc postNotificationName: GormDidModifyClassNotification
			  object: classManager];
		    }
		}
	    }
	  else if ([outlineView editType] == Outlets)
	    {
	      // if this outlet is an outlet on the class, not it's superclass
	      // allow the deletion...
	      if ([classManager isOutlet: name
			       ofClass: itemBeingEdited])
		{
		  BOOL removed = [document removeConnectionsWithLabel: name 
					   forClassNamed: itemBeingEdited
					   isAction: NO];
		  if (removed)
		    {
		      [classManager removeOutlet: name
				    fromClassNamed: itemBeingEdited];
		      [outlineView removeItemAtRow: i];
		      [nc postNotificationName: GormDidModifyClassNotification
			  object: classManager];
		    }
		}
	    }
	}
    }
  else
    {
      NSArray *subclasses = [classManager subClassesOf: anitem];
      // if the class has no subclasses, then delete.
      if ([subclasses count] == 0)
	{
	  // if the class being edited is a custom class, then allow the deletion...
	  if ([classManager isCustomClass: anitem])
	    {
	      BOOL removed = [document removeConnectionsForClassNamed: anitem];
	      if (removed)
		{
		  [self copySelection];
		  [document removeAllInstancesOfClass: anitem];
		  [classManager removeClassNamed: anitem];
		  [self reloadData];
		  [nc postNotificationName: GormDidModifyClassNotification
		      object: classManager];
		  ASSIGN(selectedClass, (id)nil); // don't keep the class we're pointing to.
		}
	    }
	}
      else
	{
	  NSString *message = [NSString stringWithFormat: 
	    _(@"The class %@ has subclasses which must be removed"), anitem];
	  NSRunAlertPanel(_(@"Problem removing class"), 
			  message,
			  nil, nil, nil);
	}
    }    
}

- (void) copySelection
{
  if(selectedClass != nil)
    {
      if([selectedClass isEqual: @"FirstResponder"] == NO)
	{
	  NSPasteboard *pb = [NSPasteboard generalPasteboard];
	  NSMutableDictionary *dict = 
	    [NSMutableDictionary dictionaryWithObjectsAndKeys: [classManager dictionaryForClassNamed: selectedClass], 
				 selectedClass, nil];
	  id classPlist = [[dict description] propertyList];
	  
	  if(classPlist != nil)
	    {
	      [pb declareTypes: [NSArray arrayWithObject: GormClassPboardType] owner: self];
	      [pb setPropertyList: classPlist forType: GormClassPboardType];
	    }
	}
    }
}

- (void) pasteInSelection
{
  if(selectedClass != nil)
    {
      if([selectedClass isEqual: @"FirstResponder"] == NO)
	{
	  NSPasteboard *pb = [NSPasteboard generalPasteboard];
	  NSArray *types = [pb types];
	  
	  if([types containsObject: GormClassPboardType])
	    {
	      id classPlist = [pb propertyListForType: GormClassPboardType];
	      NSDictionary *classesDict = [NSDictionary dictionaryWithDictionary: classPlist];
	      id name = nil;
	      NSEnumerator *en = [classesDict keyEnumerator];
	      
	      while((name = [en nextObject]) != nil)
		{
		  NSDictionary *classDict = [classesDict objectForKey: name];
		  NSString *className = [classManager uniqueClassNameFrom: name];
		  BOOL added = [classManager addClassNamed: className
					     withSuperClassNamed: selectedClass
					     withActions: [classDict objectForKey: @"Actions"]
					     withOutlets: [classDict objectForKey: @"Outlets"]];
		  if(!added)
		    {
		      NSString *message = [NSString stringWithFormat: @"Addition of %@ with superclass %@ failed.", className,
						    selectedClass];
		      NSRunAlertPanel(_(@"Problem pasting class"),
				      message, nil, nil, nil);
		    }
		}
	    }
	}
      else
	{
	  NSRunAlertPanel(_(@"Problem pasting class"),
			  _(@"FirstResponder cannot have subclasses."), nil, nil, nil);
	}
    }
}


- (void) addAttributeToClass
{
  id edited = [outlineView itemBeingEdited];
  if ([outlineView isEditing] == YES)
    {
      if ([outlineView editType] == Actions)
	{
	  [outlineView _addNewActionToObject: edited];
	}
      if ([outlineView editType] == Outlets)
	{
	  if([classManager isCustomClass: edited])
	    {
	      [outlineView _addNewOutletToObject: edited];
	    }
	}
    }
}

- (void) reloadData
{
  [outlineView reloadData];
  [browserView loadColumnZero];
}

- (BOOL) isEditing
{
  return [outlineView isEditing];
}

/*
 *	Dragging source protocol implementation
 */
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f
{
  // no image.
}

// IBEditor protocol

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  return [types containsObject: NSFilenamesPboardType];
}

- (BOOL) activate
{
  return YES;
}

- (id) initWithObject: (id)anObject inDocument: (id/*<IBDocuments>*/)aDocument
{
  return [self initWithDocument: aDocument];
}

- (void) close
{
  // does nothing.
}

- (void) closeSubeditors
{
  // does nothing.
}

- (void) deactivate
{
  // does nothing.
}

- (id /*<IBDocuments>*/) document
{
  return document;
}

- (id) editedObject
{
  return selectedClass;
}

- (void) orderFront
{
  [[self window] orderFront: self];
}

- (id<IBEditors>) openSubeditorForObject: (id)object
{
  return nil;
}

- (void) resetObject: (id)anObject
{
  [outlineView reset];
  [outlineView expandItem: anObject];
  [outlineView collapseItem: anObject collapseChildren: YES];
}

- (BOOL) wantsSelection
{
  return NO;
}

- (void) validateEditing
{
  // does nothing.
}

- (NSWindow *) window
{
  return [super window];
}

- (NSArray *) fileTypes
{
  return [NSArray arrayWithObject: @"h"];
}

/**
 * Create a subclass from the selected subclass...
 */
- (id) createSubclass: (id)sender
{
  if (![outlineView isEditing])
    {
      NSString *itemSelected = [self selectedClassName];
      
      if(itemSelected != nil)
	{
	  NSString *newClassName;

	  newClassName = [classManager addClassWithSuperClassName:
					 itemSelected];
	  if(newClassName != nil)
	    {
	      NSInteger i = 0;
	      if([classesView contentView] == scrollView)
		{
		  [outlineView reloadData];
		  [outlineView expandItem: itemSelected];
		  i = [outlineView rowForItem: newClassName]; 
		  [outlineView selectRow: i byExtendingSelection: NO];
		  [outlineView scrollRowToVisible: i];
		}
	      else if([classesView contentView] == browserView)
		{
		  [self selectClass: newClassName editClass: NO];
		}
	    }
	  else
	    {
	      // inform the user of this error.
	      NSRunAlertPanel(_(@"Cannot instantiate"), 
			      _(@"FirstResponder cannot be instantiated."),
			      nil, nil, nil);
	    }
	}
    }
  return self;
}

/**
 * Create an instance of a given class.
 */
- (id) instantiateClass: (id)sender
{
  NSString *className = [self selectedClassName];
  NSString *theName = nil;
  
  theName = [document instantiateClassNamed: className];
  if (theName == nil)
    {
      return nil;
    }
  
  return self;
}

/**
 * Remove a class from the classes view
 */
- (id) removeClass: (id)sender
{
  [self deleteSelection];
  return self;
}

/**
 * Parse a header into the classes view.
 */
- (id) loadClass: (id)sender
{
  NSArray	*fileTypes = [NSArray arrayWithObjects: @"h", @"H", @"m", @"mm", nil];
  NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
  int		result;

  [oPanel setAllowsMultipleSelection: NO];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: nil
				   file: nil
				  types: fileTypes];
  if (result == NSOKButton)
    {
      NSString *filename = [oPanel filename];

      NS_DURING
	{
	  if(![classManager parseHeader: filename])
	    {
	      NSString *file = [filename lastPathComponent];
	      NSString *message = [NSString stringWithFormat: 
					      _(@"Unable to parse class in %@"),file];
	      NSRunAlertPanel(_(@"Problem parsing class"), 
			      message,
			      nil, nil, nil);
	    }
	  else
	    {
	      return self;
	    }
	}
      NS_HANDLER
	{
	  NSString *message = [localException reason];
	  NSRunAlertPanel(_(@"Problem parsing class"), 
			  message,
			  nil, nil, nil);
	}
      NS_ENDHANDLER;
    }

  return nil;
}

/**
 * Create the class files for the selected class.
 */
- (id) createClassFiles: (id)sender
{
  NSSavePanel		*sp;
  NSString              *className = [self selectedClassName];
  int			result;

  sp = [NSSavePanel savePanel];
  [sp setRequiredFileType: @"m"];
  [sp setTitle: _(@"Save source file as...")];
  if ([document fileName] == nil)
    {
      result = [sp runModalForDirectory: NSHomeDirectory() 
		   file: [className stringByAppendingPathExtension: @"m"]];
    }
  else
    {
      result = [sp runModalForDirectory: 
		     [[document fileName] stringByDeletingLastPathComponent]
		   file: [className stringByAppendingPathExtension: @"m"]];
    }

  if (result == NSOKButton)
    {
      NSString *sourceName = [sp filename];
      NSString *headerName;

      [sp setRequiredFileType: @"h"];
      [sp setTitle: _(@"Save header file as...")];
      result = [sp runModalForDirectory: 
		     [sourceName stringByDeletingLastPathComponent]
		   file: 
		     [[[sourceName lastPathComponent]
			stringByDeletingPathExtension] 
		       stringByAppendingString: @".h"]];
      if (result == NSOKButton)
	{
	  headerName = [sp filename];
	  NSDebugLog(@"Saving %@", className);
	  if (![classManager makeSourceAndHeaderFilesForClass: className
                                                     withName: sourceName
                                                          and: headerName])
	    {
	      NSRunAlertPanel(_(@"Alert"), 
			      _(@"Could not create the class's file"),
			      nil, nil, nil);
	    }
	  
	  return self;
	}
    }
  return nil;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  id object = [aNotification object];
  NSString *className = [classManager findClassByName: [object stringValue]];
  [self selectClass: className];
}

@end

@implementation GormClassEditor (NSOutlineViewDataSource)

// --- NSOutlineView dataSource ---
- (id)        outlineView: (NSOutlineView *)anOutlineView 
objectValueForTableColumn: (NSTableColumn *)aTableColumn 
	           byItem: item
{
  id identifier = [aTableColumn identifier];
  id className = item;
  
  if([item isKindOfClass: [GormOutletActionHolder class]])
    return item;

  if ([identifier isEqualToString: @"classes"])
    {
      return className;
    } 
  else if ([identifier isEqualToString: @"outlets"])
    {
      return [NSString stringWithFormat: @"%"PRIuPTR,
		       [[classManager allOutletsForClassNamed: className] count]];
    }
  else if ([identifier isEqualToString: @"actions"])
    {
      return [NSString stringWithFormat: @"%"PRIuPTR,
		       [[classManager allActionsForClassNamed: className] count]];
    }

  return @"";
}

- (void) outlineView: (NSOutlineView *)anOutlineView 
      setObjectValue: (id)anObject 
      forTableColumn: (NSTableColumn *)aTableColumn
	      byItem: (id)item
{
  GormOutlineView *gov = (GormOutlineView *)anOutlineView;

  // ignore object values which come in as nil...
  if(anObject == nil)
    return;

  if ([item isKindOfClass: [GormOutletActionHolder class]])
    {
      if (![anObject isEqualToString: @""] && 
	  ![anObject isEqualToString: [item getName]])
	{
	  NSString *name = [item getName];

	  // retain the name and add the action/outlet...
	  if ([gov editType] == Actions)
	    {
	      NSString *formattedAction = formatAction( (NSString *)anObject );
	      if (![classManager isAction: formattedAction 
				ofClass: [gov itemBeingEdited]])
		{
		  BOOL removed;

		  removed = [document removeConnectionsWithLabel: name
		    forClassNamed: [gov itemBeingEdited] isAction: YES];
		  if (removed)
		    {
		      [classManager replaceAction: name 
				    withAction: formattedAction 
				    forClassNamed: [gov itemBeingEdited]];
		      [(GormOutletActionHolder *)item setName: formattedAction];
		    }
		}
	      else
		{
		  NSString *message;

		  message = [NSString stringWithFormat: 
		    _(@"The class %@ already has an action named %@"),
		    [gov itemBeingEdited], formattedAction];

		  NSRunAlertPanel(_(@"Problem Adding Action"),
				  message, nil, nil, nil);
				  
		}
	    }
	  else if ([gov editType] == Outlets)
	    {
	      NSString *formattedOutlet = formatOutlet( (NSString *)anObject );
	      
	      if (![classManager isOutlet: formattedOutlet 
				  ofClass: [gov itemBeingEdited]])
		{
		  BOOL removed;

		  removed = [document removeConnectionsWithLabel: name
				      forClassNamed: [gov itemBeingEdited] 
				      isAction: NO];
		  if (removed)
		    {
		      [classManager replaceOutlet: name 
				    withOutlet: formattedOutlet 
				    forClassNamed: [gov itemBeingEdited]];
		      [(GormOutletActionHolder *)item setName: formattedOutlet];
		    }
		}
	      else
		{
		  NSString *message;

		  message = [NSString stringWithFormat: 
		    _(@"The class %@ already has an outlet named %@"),
		    [gov itemBeingEdited], formattedOutlet];
		  NSRunAlertPanel(_(@"Problem Adding Outlet"),
				  message, nil, nil, nil);
				  
		}
	    }
	}
    }
  else
    {
      if((![anObject isEqualToString: @""]) && 
	 (![anObject isEqualToString:item]))
	{
	  BOOL rename;

	  rename = [document renameConnectionsForClassNamed: item toName: anObject];
	  if (rename)
	    {
	      NSInteger row = 0;

	      [classManager renameClassNamed: item newName: anObject];
	      [gov reloadData];
	      row = [gov rowForItem: anObject];

	      // make sure that item is collapsed...
	      [gov expandItem: anObject];
	      [gov collapseItem: anObject];
	      
	      // scroll to the item..
	      [gov scrollRowToVisible: row];
	      [gov selectRow: row]; 
	    }
	}
    }

  [gov setNeedsDisplay: YES];
}

- (NSInteger) outlineView: (NSOutlineView *)anOutlineView 
   numberOfChildrenOfItem: (id)item
{
  NSArray *subclasses = [classManager subClassesOf: item];
  return [subclasses count];
}

- (BOOL) outlineView: (NSOutlineView *)anOutlineView 
    isItemExpandable: (id)item
{
  NSArray *subclasses = nil;
  if (item == nil)
    return YES;

  subclasses = [classManager subClassesOf: item];
  if ([subclasses count] > 0)
    return YES;

  return NO;
}

- (id) outlineView: (NSOutlineView *)anOutlineView 
	     child: (NSInteger)index
	    ofItem: (id)item
{
  NSArray *subclasses = [classManager subClassesOf: item];
  return [subclasses objectAtIndex: index];
}

// GormOutlineView data source methods...
- (NSArray *)outlineView: (NSOutlineView *)anOutlineView
	  actionsForItem: (id)item
{
  NSArray *actions = [classManager allActionsForClassNamed: item];
  return actions;
}

- (NSArray *)outlineView: (NSOutlineView *)anOutlineView
	  outletsForItem: (id)item
{
  NSArray *outlets = [classManager allOutletsForClassNamed: item];
  return outlets;
}

- (NSString *)outlineView: (NSOutlineView *)anOutlineView
     addNewActionForClass: (id)item
{
  // removed the restriction, since it's now possible to add
  // actions for kit classes.
  return [classManager addNewActionToClassNamed: item];
}

- (NSString *)outlineView: (NSOutlineView *)anOutlineView
     addNewOutletForClass: (id)item		 
{
  GormOutlineView *gov = (GormOutlineView *)anOutlineView;
  if (![classManager isCustomClass: [gov itemBeingEdited]])
    {
      return nil;
    }

  if([item isEqualToString: @"FirstResponder"])
	    return nil;

  return [classManager addNewOutletToClassNamed: item];
}

// Delegate methods
- (BOOL)  outlineView: (NSOutlineView *)outline
shouldEditTableColumn: (NSTableColumn *)tableColumn
		 item: (id)item
{
  BOOL result = NO;
  GormOutlineView *gov = (GormOutlineView *)outline;

  NSDebugLog(@"in the delegate %@", [tableColumn identifier]);
  if (tableColumn == [gov outlineTableColumn])
    {
      NSDebugLog(@"outline table col");
      if (![item isKindOfClass: [GormOutletActionHolder class]] &&
	  ![item isEqualToString: @"FirstResponder"])
	{
	  result = [classManager isCustomClass: item];
	  [self editClass];
	}
      else
	{
	  id itemBeingEdited = [gov itemBeingEdited];
	  if ([classManager isCustomClass: itemBeingEdited])
	    {
	      if ([gov editType] == Actions)
		{
		  result = [classManager isAction: [item getName]
					 ofClass: itemBeingEdited];
		}
	      else if ([gov editType] == Outlets)
		{
		  result = [classManager isOutlet: [item getName]
					 ofClass: itemBeingEdited];
		}	       
	    }
	  else if ([classManager isCategoryForClass: itemBeingEdited])
	    {
	      if ([gov editType] == Actions)
		{
		  result = [classManager isAction: [item getName]
					 ofClass: itemBeingEdited];
		}
	    }	    
	}
    }

  return result;
}

- (void) outlineViewSelectionDidChange: (NSNotification *)notification
{
  id object = [notification object];
  NSInteger row = [object selectedRow];

  if(row != -1)
    {
      NS_DURING
	{
	  id item = [object itemAtRow: [object selectedRow]];
	  if ([item isKindOfClass: [GormOutletActionHolder class]] == NO &&
	      [classesView contentView] == scrollView)
	    {
	      [self editClass];
	    }
	}
      NS_HANDLER
	{
	  NSLog(@"%@",[localException reason]);
	}
      NS_ENDHANDLER;
    }
}

@end // end of data source

@implementation GormClassEditor (NSBrowserDelegate)

- (void) browser:(NSBrowser *)sender createRowsForColumn: (NSInteger)column inMatrix: (NSMatrix *)matrix
{
  NSArray      *classes = nil;
  NSEnumerator *en = nil;
  NSString     *className = nil;
  NSInteger          i = 0;

  if (sender != browserView || !matrix || ![matrix isKindOfClass:[NSMatrix class]])
    {
      return;
    }

  if(column == 0)
    {
      classes = [classManager subClassesOf: nil];
    }
  else
    {
      className = [[sender selectedCellInColumn: column - 1] stringValue];
      classes = [classManager subClassesOf: className];
    }

  en = [classes objectEnumerator];
  for(i = 0; ((className = [en nextObject]) != nil); i++) 
    {
      id              cell;
      NSArray         *sub = [classManager subClassesOf: className];
      
      [matrix insertRow:i];
      cell = [matrix cellAtRow:i column:0];
      [cell setStringValue: className];
      [cell setLeaf: ([sub count] == 0)];
    }
}

@end

