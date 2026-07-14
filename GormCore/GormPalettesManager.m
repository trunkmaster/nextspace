/* GormPalettesManager.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2004
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

#include <GNUstepBase/GSObjCRuntime.h>

#include "GormPrivate.h"
#include "GormFunctions.h"

#define BUILTIN_PALETTES @"BuiltinPalettes"
#define USER_PALETTES    @"UserPalettes"

@interface GormPalettePanel : NSPanel
@end

@implementation	GormPalettePanel
@end

@interface GormPaletteView : NSView
{
  NSPasteboard	*dragPb;
}
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f;
- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)flag;
@end

@implementation	GormPaletteView

static NSImage	*dragImage = nil;
+ (void) initialize
{
  if (self == [GormPaletteView class])
    {
      // nothing to do...
    }
}

- (BOOL) acceptsFirstMouse: (NSEvent*)theEvent
{
  return YES;	/* Ensure we get initial mouse down event.	*/
}

/*
 *	Initialisation - register to receive DnD with our own types.
 */
- (id) initWithFrame: (NSRect)aFrame
{
  self = [super initWithFrame: aFrame];
  if (self != nil)
    {
      [self registerForDraggedTypes: [NSArray arrayWithObjects:
	IBCellPboardType, IBMenuPboardType, IBMenuCellPboardType,
	IBObjectPboardType, IBViewPboardType, IBWindowPboardType,
        IBFormatterPboardType,nil]];

      [self setAutoresizingMask: 
	      NSViewMinXMargin|NSViewMinYMargin|NSViewMaxXMargin|NSViewMaxYMargin];
    }
  return self;
}

- (void) dealloc
{
  DESTROY(dragPb);
  [super dealloc];
}

- (void) resizeWithOldSuperviewSize: (NSSize)oldSize
{
  NSSize newSize = [[self superview] frame].size;
  NSRect frame = [self frame];
  
  frame.origin.x -= floorf((oldSize.width - newSize.width) / 2);
  frame.origin.y -= floorf((oldSize.height - newSize.height) / 2);
  [self setFrameOrigin: frame.origin];
}

/*
 *	Dragging source protocol implementation
 */
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f
{
  NSString	*type = [[dragPb types] lastObject];

  /*
   * Windows and Menus are an exception to the normal DnD mechanism - 
   * we create them if they are dropped anywhere except back in the \
   * pallettes view ie. if they are dragged, but the drop fails.
   */
  if (f == NO && ([type isEqual: IBWindowPboardType] == YES || 
		  [type isEqual: IBMenuPboardType] == YES))
    {
      id<IBDocuments>	active = [(id<IB>)[NSApp delegate] activeDocument];

      if (active != nil)
	{
	  [active pasteType: type fromPasteboard: dragPb parent: nil];
	}
    }
}

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)flag
{
  return NSDragOperationCopy;
}

/*
 *	Dragging destination protocol implementation
 *
 *	We actually don't handle anything being dropped on the palette,
 *	but we pretend to accept drops from ourself, so that the drag
 *	session quietly terminates - and it looks like the drop has
 *	been successful - this stops windows being created when they are
 *	dropped back on the palette (a window is normally created if the
 *	dnd drop is refused).
 */
- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>)sender
{
  return NSDragOperationCopy;
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>)sender
{
  return YES;
}


/*
 *	Intercepting events in the view and handling them
 */
- (NSView*) hitTest: (NSPoint)loc
{
  /*
   * Stop the subviews receiving events - we grab them all.
   */
  if ([super hitTest: loc] != nil)
    return self;
  return nil;
}

- (void) mouseDown: (NSEvent*)theEvent
{
  NSPoint	dragPoint = [theEvent locationInWindow];
  NSWindow	*w = [self window];
  NSView	*view;
  GormDocument	*active = (GormDocument *)[(id<IB>)[NSApp delegate] activeDocument];
  NSRect	rect;
  NSString	*type;
  id		obj;
  NSPasteboard	*pb;
  NSImageRep	*rep;
  NSMenu        *menu;

  if ([self superview] != nil)
    {
      dragPoint = [[self superview] convertPoint: dragPoint fromView: nil];
    }
  view = [super hitTest: dragPoint];
  if (view == self || view == nil)
    {
      return;		// No subview to drag.
    }
  /* Make sure we're dragging the proper control and not a subview of a 
     control (like the contentView of an NSBox) */
  while (view != nil && [view superview] != self)
    view = [view superview];
  // this will always get the correct coordinates...
  rect = [[view superview] convertRect: [view frame] toView: nil];

  if (active == nil)
    {
      NSRunAlertPanel (nil, _(@"No document is currently active"), 
		       _(@"OK"), nil, nil);
      return;
    }

  RELEASE(dragImage);
  dragImage = [[NSImage alloc] init];
  [dragImage setSize: rect.size];
  rep = [[NSCachedImageRep alloc] initWithSize: rect.size
					 depth: [w depthLimit]
				      separate: YES
					 alpha: [w alphaValue]>0.0 ? YES : NO];
  [dragImage addRepresentation: rep];
  RELEASE(rep);

  /* Copy the contents of the clicked view from our window into the
   * cached image representation.
   * NB. We use lockFocusOnRepresentation: for this because it sets
   * up cached image representation information in the image, and if
   * that's not done before our copy, the image will overwrite our
   * copied data when asked to draw the representation.
   */
  [dragImage lockFocusOnRepresentation: rep];
  NSCopyBits([w gState], rect, NSZeroPoint);
  [dragImage unlockFocus];

  type = [IBPalette typeForView: view];
  obj = [IBPalette objectForView: view];
  pb = [NSPasteboard pasteboardWithName: NSDragPboard];
  ASSIGN(dragPb, pb);
  [active copyObject: obj type: type toPasteboard: pb];
  NSDebugLog(@"type: %@, obj: %@,", type, obj);

  menu = [active objectForName: @"NSMenu"];
  
  [self dragImage: dragImage
	       at: [view frame].origin
	   offset: NSMakeSize(0,0)
	    event: theEvent
       pasteboard: pb
	   source: self
	slideBack: ([type isEqual: IBWindowPboardType] || 
		    ([type isEqual: IBMenuPboardType] && menu == nil)) ? NO : YES];

  // Temporary fix for the art backend.  This is harmless, and
  // shouldn't effect users of xlib, but it's necessary for now
  // so that users can work.
  [self setNeedsDisplay: YES]; 
}
@end


@implementation GormPalettesManager

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(panel);
  RELEASE(bundles);
  RELEASE(palettes);
  RELEASE(importedClasses);
  RELEASE(importedImages);
  RELEASE(importedSounds);
  RELEASE(substituteClasses);
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
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSScrollView	 *scrollView;
  NSArray	 *array;
  NSRect	 contentRect = {{0, 0}, {272, 266}};
  NSRect	 selectionRect = {{0, 0}, {52, 52}};
  NSRect	 scrollRect = {{-2, 192}, {276, 76}};
  NSRect	 dragRect = {{0, 0}, {272, 200}};
  unsigned int	 style = NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray        *userPalettes = [defaults arrayForKey: USER_PALETTES];
  NSEnumerator   *en = nil;
  NSString       *paletteName = nil;
  
  panel = [[GormPalettePanel alloc] initWithContentRect: contentRect
				     styleMask: style
				       backing: NSBackingStoreRetained
					 defer: NO];
  [panel setTitle: _(@"Palettes")];
  [panel setMinSize: [panel frame].size];

  // allocate arrays and dictionaries.
  bundles = [[NSMutableArray alloc] init];
  palettes = [[NSMutableArray alloc] init];
  importedClasses = [[NSMutableDictionary alloc] init];
  importedImages = [[NSMutableArray alloc] init];
  importedSounds = [[NSMutableArray alloc] init];
  substituteClasses = [[NSMutableDictionary alloc] init];

  scrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
  [scrollView setHasHorizontalScroller: YES];
  [scrollView setHasVerticalScroller: NO];
  [scrollView setAutoresizingMask: NSViewMinYMargin | NSViewWidthSizable];
  [scrollView setBorderType: NSGrooveBorder];
  [[scrollView horizontalScroller] setArrowsPosition: NSScrollerArrowsNone];
  [scrollView setAutohidesScrollers: YES];

  selectionView = [[NSMatrix alloc] initWithFrame: selectionRect
					     mode: NSRadioModeMatrix
					cellClass: [NSButtonCell class]
				     numberOfRows: 1
				  numberOfColumns: 0];
  [selectionView setTarget: self];
  [selectionView setAction: @selector(setCurrentPalette:)];
  [selectionView setCellSize: NSMakeSize(52,52)];
  [selectionView setIntercellSpacing: NSMakeSize(15, 0)];
  [scrollView setDocumentView: selectionView];
  RELEASE(selectionView);
  [[panel contentView] addSubview: scrollView]; 
  RELEASE(scrollView);

  dragView = [[GormPaletteView alloc] initWithFrame: dragRect];
  [dragView setAutoresizingMask: 0];
  [[panel contentView] addSubview: dragView]; 
  RELEASE(dragView);

  [panel setFrameUsingName: @"Palettes"];
  [panel setFrameAutosaveName: @"Palettes"];
  current = -1;

  // Load the palettes...
  array = [[NSBundle mainBundle] pathsForResourcesOfType: @"palette"
					     inDirectory: nil];
  array = [array sortedArrayUsingSelector: @selector(compare:)];
  en = [array objectEnumerator];
  while ((paletteName = [en nextObject]) != nil)
    {
      NSDebugLog(@"Built-in palette name = %@", paletteName);
      [self loadPalette: paletteName];
    }

  // if we have any user palettes load them as well.
  en = [userPalettes objectEnumerator];
  while ((paletteName = [en nextObject]) != nil)
    {
      NSDebugLog(@"User palette name = %@", paletteName);
      [self loadPalette: paletteName];
    }

  /*
   * Select initial palette - this should be the standard controls palette.
   */
  [selectionView selectCellAtRow: 0 column: 2];
  [self setCurrentPalette: selectionView];

  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: IBWillBeginTestingInterfaceNotification
	   object: nil];
  
  [nc addObserver: self
	 selector: @selector(handleNotification:)
	     name: IBWillEndTestingInterfaceNotification
	   object: nil];

  return self;
}

- (BOOL) bundlePathIsLoaded: (NSString *)path
{
  int		col = 0;  
  NSBundle	*bundle;

  for (col = 0; col < [bundles count]; col++)
    {
      bundle = [bundles objectAtIndex: col];
      if ([path isEqualToString: [bundle bundlePath]] == YES)
	{
	  return YES;
	}
    }
  
  return NO;
}

- (BOOL) loadPalette: (NSString*)path
{
  NSBundle	*bundle;
  NSWindow	*window;
  Class		paletteClass;
  NSDictionary	*paletteInfo;
  NSString	*className;
  NSArray       *exportClasses;
  NSArray       *exportSounds;
  NSArray       *exportImages;
  NSDictionary  *subClasses;
  IBPalette	*palette;
  NSButtonCell	*cell;
  int		col;

  if([self bundlePathIsLoaded: path])
    {
      NSRunAlertPanel (nil, _(@"Palette has already been loaded"), 
		       _(@"OK"), nil, nil);
      return NO;
    }
  bundle = [NSBundle bundleWithPath: path]; 
  if (bundle == nil)
    {
      NSRunAlertPanel(nil, _(@"Could not load Palette"), 
		      _(@"OK"), nil, nil);
      return NO;
    }

  path = [bundle pathForResource: @"palette" ofType: @"table"];
  if (path == nil)
    {
      NSRunAlertPanel(nil, _(@"File 'palette.table' missing"),
		      _(@"OK"), nil, nil);
      return NO;
    }

  // attempt to load the palette table in either the strings or plist format.
  NS_DURING
    {
      paletteInfo = [[NSString stringWithContentsOfFile: path] propertyList];
      if (paletteInfo == nil)
	{
	  paletteInfo = [[NSString stringWithContentsOfFile: path] propertyListFromStringsFileFormat];
	  if(paletteInfo == nil)
	    {
	      NSRunAlertPanel(_(@"Problem Loading Palette"), 
			      _(@"Failed to load 'palette.table' using strings or property list format."),
			      _(@"OK"), 
			      nil, 
			      nil);
	      return NO;
	    }
	}
    }
  NS_HANDLER
    {
      NSString *message = [NSString stringWithFormat: 
				      _(@"Encountered exception %@ attempting to load 'palette.table'."),
				    [localException reason]];
      NSRunAlertPanel(_(@"Problem Loading Palette"), 
		      message,
		      _(@"OK"), 
		      nil, 
		      nil);
      return NO;
    }
  NS_ENDHANDLER

  className = [paletteInfo objectForKey: @"Class"];
  if (className == nil)
    {
      NSRunAlertPanel(nil, _(@"No palette class in 'palette.table'"),
		      _(@"OK"), nil, nil);
      return NO;
    }

  paletteClass = [bundle classNamed: className];
  if (paletteClass == 0)
    {
      NSRunAlertPanel (nil, _(@"Could not load palette class"), 
		       _(@"OK"), nil, nil);
      return NO;
    }

  palette = [[paletteClass alloc] init];
  if ([palette isKindOfClass: [IBPalette class]] == NO)
    {
      NSRunAlertPanel (nil, _(@"Palette contains wrong type of class"), 
		       _(@"OK"), nil, nil);
      RELEASE(palette);
      return NO;
    }

  // add to the bundles list...
  [bundles addObject: bundle];	

  exportClasses = [paletteInfo objectForKey: @"ExportClasses"];
  if(exportClasses != nil)
    {
      [self importClasses: exportClasses withDictionary: nil];
    }

  exportImages = [paletteInfo objectForKey: @"ExportImages"];
  if(exportImages != nil)
    {
      [self importImages: exportImages withBundle: bundle];
    }

  exportSounds = [paletteInfo objectForKey: @"ExportSounds"];
  if(exportSounds != nil)
    {
      [self importSounds: exportSounds withBundle: bundle];
    }

  subClasses = [paletteInfo objectForKey: @"SubstituteClasses"];
  if(subClasses != nil)
    {
      [substituteClasses addEntriesFromDictionary: subClasses];
    }

  [palette finishInstantiate];
  window = [palette originalWindow];
  [window setExcludedFromWindowsMenu: YES];

  // Resize the window appropriately so that we don't have issues
  // with scrolling.
  // if([window styleMask] & NSBorderlessWindowMask)
  //   {
  //     [window setFrame: NSMakeRect(0,0,272,160) display: NO];
  //   }
  // else
  //   {
  //     [window setFrame: NSMakeRect(0,0,272,224) display: NO];
  //   }

  [palettes addObject: palette];
  [selectionView addColumn];
  [[palette paletteIcon] setBackgroundColor: [selectionView backgroundColor]];
  col = [selectionView numberOfColumns] - 1;
  cell = [selectionView cellAtRow: 0 column: col];
  [cell setButtonType: NSOnOffButton];
  [cell setRefusesFirstResponder: YES];
  [cell setImage: [palette paletteIcon]];
  [selectionView sizeToCells];
  [selectionView selectCellAtRow: 0 column: col];
  [self setCurrentPalette: selectionView];
  RELEASE(palette);

  return YES;
}

- (id) openPalette: (id) sender
{
  NSArray	 *fileTypes = [NSArray arrayWithObject: @"palette"];
  NSOpenPanel	 *oPanel = [NSOpenPanel openPanel];
  int		 result;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray        *userPalettes = [defaults arrayForKey: USER_PALETTES];
  NSMutableArray *newUserPalettes = 
    (userPalettes == nil)?[NSMutableArray array]:[NSMutableArray arrayWithArray: userPalettes];

  [oPanel setAllowsMultipleSelection: YES];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: NSHomeDirectory()
				   file: nil
				  types: fileTypes];

  if (result == NSOKButton)
    {
      NSArray	*filesToOpen = [oPanel filenames];
      unsigned	count = [filesToOpen count];
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  NSString	*aFile = [filesToOpen objectAtIndex: i];

	  if([self bundlePathIsLoaded: aFile] == YES &&
	     [userPalettes containsObject: aFile] == NO)
	    {
	      // This is done here so that, if we try to reload a palette
	      // that has previously been deleted during this session that
	      // the palette manager won't fail, but it will simply add
	      // the palette back in.  If this returns NO, then we should
	      // flag a problem otherwise it's successful if the palette is
	      // already in the bundles array.  This is to address bug#15989.
	      [newUserPalettes addObject: aFile];
	    }
	  else if([self loadPalette: aFile] == NO)
	    {
	      return nil;
	    }
	  else
	    {
	      [newUserPalettes addObject: aFile];
	    }
	}

      // reset the defaults to include the new palette.
      [defaults setObject: newUserPalettes forKey: USER_PALETTES];
      return self;
    }

  return nil;
}

- (NSPanel*) panel
{
  return panel;
}

- (void) setCurrentPalette: (id)anObj
{
  NSView	*wv;
  NSView	*sv;
  NSEnumerator	*enumerator;

  if (current >= 0)
    {
      /*
       * Move the views in the drag view back to the content view of the
       * window they originally came from.
       */
      wv = [[[palettes objectAtIndex: current] originalWindow] contentView];
      enumerator = [[dragView subviews] objectEnumerator];
      while ((sv = [enumerator nextObject]) != nil)
	{
	  RETAIN(sv);
	  [sv removeFromSuperview];
	  [wv addSubview: sv];
	  RELEASE(sv);
	}
    }

  current = [anObj selectedColumn];
  if (current >= 0 && current < [palettes count])
    {
      id palette = [palettes objectAtIndex: current];

      /*
       * Set the window title to reflect the palette selection.
       */
      [panel setTitle: [[palette originalWindow] title]];

      /*
       * Move the views from their original window into our drag view.
       * Resize our drag view to the right size fitrst.
       */
      wv = [[palette originalWindow] contentView];
      if (wv)
        [dragView setFrameSize: [wv frame].size];
      enumerator = [[wv subviews] objectEnumerator];
      while ((sv = [enumerator nextObject]) != nil)
	{
	  RETAIN(sv);
	  [sv removeFromSuperview];
	  [dragView addSubview: sv];
	  RELEASE(sv);
	}
    }
  else
    {
      NSDebugLog(@"Bad palette selection - %d", (int)[anObj selectedColumn]);
      current = -1;
    }
  [dragView setNeedsDisplay: YES];
}

- (NSMutableArray *) actionsForClass: (Class) cls
{
  NSArray *methodArray = _GSObjCMethodNamesForClass(cls, NO);
  NSEnumerator *en = [methodArray objectEnumerator];
  NSMethodSignature *actionSig = [NSMethodSignature signatureWithObjCTypes: "v12@0:4@8"];
  NSMutableArray *actionsArray = [NSMutableArray array];
  NSString *methodName = nil;
  NSRange setRange = NSMakeRange(0,3);

  while((methodName = [en nextObject]) != nil)
    {
      SEL sel = NSSelectorFromString(methodName);
      NSMethodSignature *signature = [cls instanceMethodSignatureForSelector: sel];
      if([signature numberOfArguments] == 3)
	{
	  if([actionSig isEqual: signature] && NSEqualRanges([methodName rangeOfString: @"set"], setRange) == NO &&
	     [methodName isEqual: @"encodeWithCoder:"] == NO && [methodName isEqual: @"mouseDown:"] == NO)
	    {
	      [actionsArray addObject: methodName];
	    }
	}
    }
  
  return actionsArray;
}

- (NSMutableArray *) outletsForClass: (Class) cls
{
  NSArray *methodArray = _GSObjCMethodNamesForClass(cls, NO);
  NSEnumerator *en = [methodArray objectEnumerator];
  NSMethodSignature *outletSig = [NSMethodSignature signatureWithObjCTypes: "v12@0:4@8"];
  NSMutableArray *outletsArray = [NSMutableArray array];
  NSString *methodName = nil;
  NSRange setRange = NSMakeRange(0,3);

  while((methodName = [en nextObject]) != nil)
    {
      SEL sel = NSSelectorFromString(methodName);
      NSMethodSignature *signature = [cls instanceMethodSignatureForSelector: sel];
      if([signature numberOfArguments] == 3)
	{
	  if([outletSig isEqual: signature] && NSEqualRanges([methodName rangeOfString: @"set"], setRange) == YES &&
	     [methodName isEqual: @"encodeWithCoder:"] == NO && [methodName isEqual: @"mouseDown:"] == NO)
	    {
	      NSRange range = NSMakeRange(3,([methodName length] - 4));
	      NSString *outletMethod = [[methodName substringWithRange: range] lowercaseString];
	      if([methodArray containsObject: outletMethod])
		{
		  [outletsArray addObject: outletMethod];
		}
	    }
	}
    }
  
  return outletsArray;
}

- (void) importClasses: (NSArray *)classes withDictionary: (NSDictionary *)dict
{
  NSEnumerator *en = [classes objectEnumerator];
  id className = nil;
  NSMutableDictionary *masterDict = [NSMutableDictionary dictionary];

  // import the classes.
  while((className = [en nextObject]) != nil)
    {
      NSMutableDictionary *classDict = [NSMutableDictionary dictionary];      
      Class cls = NSClassFromString(className);
      Class supercls = [cls superclass];
      NSString *superClassName = NSStringFromClass(supercls);
      NSMutableArray *actions = [self actionsForClass: cls];
      NSMutableArray *outlets = [self outletsForClass: cls];
      
      // if the superclass is defined, set it.  if not, don't since
      // this might be a palette which adds a root class.
      if(superClassName != nil)
	{
	  [classDict setObject: superClassName forKey: @"Super"];
	}

      // set the action/outlet keys
      if(actions != nil)
	{
	  [classDict setObject: actions forKey: @"Actions"];
	}
      if(outlets != nil)
	{
	  [classDict setObject: outlets forKey: @"Outlets"];
	}

      [masterDict setObject: classDict forKey: className];
    }
  
  // override any elements needed, if it's present.
  if(dict != nil)
    {
      [masterDict addEntriesFromDictionary: dict];
    }
  
  // add the classes to the dictionary...
  [importedClasses addEntriesFromDictionary: masterDict];
}

- (NSDictionary *) importedClasses
{
  return importedClasses;
}

- (void) importImages: (NSArray *)images withBundle: (NSBundle *) bundle
{
  NSEnumerator *en = [images objectEnumerator];
  id name = nil;
  NSMutableArray *paths = [NSMutableArray array];

  while((name = [en nextObject]) != nil)
    {
      NSString *path = [bundle pathForImageResource: name];
      [paths addObject: path];
    }

  [importedImages addObjectsFromArray: paths];
}

- (NSArray *) importedImages
{
  return importedImages;
}

- (void) importSounds: (NSArray *)sounds withBundle: (NSBundle *) bundle
{
  NSEnumerator *en = [sounds objectEnumerator];
  id name = nil;
  NSMutableArray *paths = [NSMutableArray array];

  while((name = [en nextObject]) != nil)
    {
      NSString *path = [bundle pathForSoundResource: name];
      [paths addObject: path];
    }

  [importedSounds addObjectsFromArray: paths];
}

- (NSArray *) importedSounds
{
  return importedSounds;
}

- (NSDictionary *) substituteClasses
{
  return substituteClasses;
}
@end
