/* GormAppDelegate.m
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg.casamento@gmail.com>
 * Date:	2023
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>

#import <AppKit/NSImage.h>
#import <AppKit/NSMenu.h>

#import "GormAppDelegate.h"
#import "GormLanguageViewController.h"

@interface GormDocument (Private)

- (NSMutableArray *) _collectAllObjects;

@end

@implementation GormAppDelegate

// App delegate...
- (BOOL)applicationShouldOpenUntitledFile: (NSApplication *)sender
{
  if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) ==
      NSWindows95InterfaceStyle)
    {
      return YES;
    }

  return NO;
}

- (void) applicationOpenUntitledFile: (NSApplication *)sender
{
  GormDocumentController *dc = [GormDocumentController sharedDocumentController];
  // open a new document and build an application type document by default...
  [dc newDocument: sender];
}


- (void) applicationDidFinishLaunching: (NSNotification *)n
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  if ( [defaults boolForKey: @"ShowInspectors"] )
    {
      [[[self inspectorsManager] panel] makeKeyAndOrderFront: self];
    }
  if ( [defaults boolForKey: @"ShowPalettes"] )
    {
      [[[self palettesManager] panel] makeKeyAndOrderFront: self];
    }
}

- (void) applicationWillTerminate: (NSNotification *)n
{
  [[NSUserDefaults standardUserDefaults]
    setBool: [[[self inspectorsManager] panel] isVisible]
    forKey: @"ShowInspectors"];
  [[NSUserDefaults standardUserDefaults]
    setBool: [[[self palettesManager] panel] isVisible]
    forKey: @"ShowPalettes"];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
  if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) ==
      NSWindows95InterfaceStyle)
    {
      GormDocumentController *docController;
      docController = [GormDocumentController sharedDocumentController];

      if ([[docController documents] count] > 0)
	{
	  return NO;
	}
      else
	{
	  return YES;
	}
    }

  return NO;
}


- (BOOL) validateMenuItem: (NSMenuItem*)item
{
  GormDocument	*active = (GormDocument*)[self activeDocument];
  SEL		action = [item action];
  GormClassManager *cm = nil;
  NSArray	*s = nil;

  // if we have an active document...
  if(active != nil)
    {
      cm = [active classManager];
      s = [_selectionOwner selection];
    }

  if(sel_isEqual(action, @selector(loadPalette:)))
    {
      return YES;
    }
  else if (sel_isEqual(action, @selector(close:))
      || sel_isEqual(action, @selector(miniaturize:)))
    {
      if (active == nil)
	{
	  return NO;
	}
    }
  else if (sel_isEqual(action, @selector(testInterface:)))
    {
      if (active == nil)
	{
	  return NO;
	}
    }
  else if (sel_isEqual(action, @selector(copy:)))
    {
      if ([s count] == 0)
	{
	  return NO;
	}
      else
	{
	  id	    o = [s objectAtIndex: 0];
	  NSString *n = [active nameForObject: o];
	  if ([n isEqual: @"NSOwner"] || [n isEqual: @"NSFirst"])
	    {
	      return NO;
	    }
	}

      return [_selectionOwner respondsToSelector: @selector(copySelection)];
    }
  else if (sel_isEqual(action, @selector(cut:)))
    {
      if ([s count] == 0)
	{
	  return NO;
	}
      else
	{
	  id	    o = [s objectAtIndex: 0];
	  NSString *n = [active nameForObject: o];
	  if ([n isEqual: @"NSOwner"] || [n isEqual: @"NSFirst"])
	    {
	      return NO;
	    }
	}

      return ([_selectionOwner respondsToSelector: @selector(copySelection)]
	&& [_selectionOwner respondsToSelector: @selector(deleteSelection)]);
    }
  else if (sel_isEqual(action, @selector(delete:)))
    {
      if ([s count] == 0)
	{
	  return NO;
	}
      else
	{
	  id	    o = [s objectAtIndex: 0];
	  NSString *n = [active nameForObject: o];
	  if ([n isEqual: @"NSOwner"] || [n isEqual: @"NSFirst"])
	    {
	      return NO;
	    }
	}

      return [_selectionOwner respondsToSelector: @selector(deleteSelection)];
    }
  else if (sel_isEqual(action, @selector(paste:)))
    {
      if ([s count] == 0)
	{
	  return NO;
	}
      else
	{
	  id	o = [s objectAtIndex: 0];
	  NSString *n = [active nameForObject: o];

	  if ([n isEqual: @"NSOwner"] || [n isEqual: @"NSFirst"])
	    {
	      return NO;
	    }
	}

      return [_selectionOwner respondsToSelector: @selector(pasteInSelection)];
    }
  else if (sel_isEqual(action, @selector(setName:)))
    {
      NSString	*n;
      id	o;

      if ([s count] == 0)
	{
	  return NO;
	}
      if ([s count] > 1)
	{
	  return NO;
	}
      o = [s objectAtIndex: 0];
      n = [active nameForObject: o];

      if ([n isEqual: @"NSOwner"] || [n isEqual: @"NSFirst"]
	|| [n isEqual: @"NSFont"] || [n isEqual: @"NSMenu"])
	{
	  return NO;
	}
      else if(![active isTopLevelObject: o])
	{
	  return NO;
	}
    }
  else if(sel_isEqual(action, @selector(createSubclass:)) ||
	  sel_isEqual(action, @selector(loadClass:)) ||
	  sel_isEqual(action, @selector(createClassFiles:)) ||
	  sel_isEqual(action, @selector(instantiateClass:)) ||
	  sel_isEqual(action, @selector(addAttributeToClass:)) ||
	  sel_isEqual(action, @selector(remove:)))
    {
      if(active == nil)
	{
	  return NO;
	}

      if(![active isEditingClasses])
	{
	  return NO;
	}

      if(sel_isEqual(action, @selector(createSubclass:)))
	{
	  NSArray *s = [_selectionOwner selection];
	  id o = nil;
	  NSString *name = nil;

	  if([s count] == 0 || [s count] > 1)
	    return NO;

	  o = [s objectAtIndex: 0];
	  name = [o className];

	  if([active classIsSelected] == NO)
	    {
	      return NO;
	    }

	  if([name isEqual: @"FirstResponder"])
	    return NO;
	}

      if(sel_isEqual(action, @selector(createClassFiles:)) ||
	 sel_isEqual(action, @selector(remove:)))
	{
	  id o = nil;
	  NSString *name = nil;

	  if ([s count] == 0)
	    {
	      return NO;
	    }
	  if ([s count] > 1)
	    {
	      return NO;
	    }

	  o = [s objectAtIndex: 0];
	  name = [o className];
	  if(![cm isCustomClass: name])
	    {
	      return NO;
	    }
	}

      if(sel_isEqual(action, @selector(instantiateClass:)))
	{
	  id o = nil;
	  NSString *name = nil;

	  if ([s count] == 0)
	    {
	      return NO;
	    }
	  if ([s count] > 1)
	    {
	      return NO;
	    }

	  if([active classIsSelected] == NO)
	    {
	      return NO;
	    }

	  o = [s objectAtIndex: 0];
	  name = [o className];
	  if(name != nil)
	    {
	      id cm = [self classManager];
	      return [cm canInstantiateClassNamed: name];
	    }
	}
    }
  else if(sel_isEqual(action, @selector(loadSound:)) ||
	  sel_isEqual(action, @selector(loadImage:)) ||
	  sel_isEqual(action, @selector(debug:)))
    {
      if(active == nil)
	{
	  return NO;
	}
    }

  return YES;
}


- (IBAction) stop: (id)sender
{
  if(_isTesting == NO)
    {
      // [super stop: sender];
    }
  else
    {
      [self endTesting: sender];
    }
}

- (IBAction) miniaturize: (id)sender
{
  NSWindow	*window = [(GormDocument *)[self activeDocument] window];

  [window miniaturize: self];
}

/** Info Menu Actions */
- (IBAction) preferencesPanel: (id) sender
{
  if(! _preferencesController)
    {
      _preferencesController =  [[GormPrefController alloc] init];
    }

  [[_preferencesController panel] makeKeyAndOrderFront:nil];
}

/** Document Menu Actions */
- (IBAction) close: (id)sender
{
  GormDocument  *document = (GormDocument *)[self activeDocument];
  if([document canCloseDocument])
    {
      [document close];
    }
}

- (IBAction) debug: (id) sender
{
  [[self activeDocument] performSelector: @selector(printAllEditors)];
}

- (IBAction) loadSound: (id) sender
{
  [(GormDocument *)[self activeDocument] openSound: sender];
}

- (IBAction) loadImage: (id) sender
{
  [(GormDocument *)[self activeDocument] openImage: sender];
}


/** Edit Menu Actions */

- (IBAction) copy: (id)sender
{
  if ([[_selectionOwner selection] count] == 0
      || [_selectionOwner respondsToSelector: @selector(copySelection)] == NO)
    return;

  if([self isConnecting])
    {
      [self stopConnecting];
    }

  [(id<IBSelectionOwners,IBEditors>)_selectionOwner copySelection];
}


- (IBAction) cut: (id)sender
{
  if ([[_selectionOwner selection] count] == 0
      || [_selectionOwner respondsToSelector: @selector(copySelection)] == NO
      || [_selectionOwner respondsToSelector: @selector(deleteSelection)] == NO)
    return;

  if([self isConnecting])
    {
      [self stopConnecting];
    }

  [(id<IBSelectionOwners,IBEditors>)_selectionOwner copySelection];
  [(id<IBSelectionOwners,IBEditors>)_selectionOwner deleteSelection];
}

- (IBAction) paste: (id)sender
{
  if ([_selectionOwner respondsToSelector: @selector(pasteInSelection)] == NO)
    return;

  if([self isConnecting])
    {
      [self stopConnecting];
    }

  [(id<IBSelectionOwners,IBEditors>)_selectionOwner pasteInSelection];
}


- (IBAction) delete: (id)sender
{
  if ([[_selectionOwner selection] count] == 0
    || [_selectionOwner respondsToSelector: @selector(deleteSelection)] == NO)
    return;

  if([self isConnecting])
    {
      [self stopConnecting];
    }

  [(id<IBSelectionOwners,IBEditors>)_selectionOwner deleteSelection];
}

- (IBAction) selectAll: (id)sender
{
  if ([[_selectionOwner selection] count] == 0
    || [_selectionOwner respondsToSelector: @selector(deleteSelection)] == NO)
    return;

  if([self isConnecting])
    {
      [self stopConnecting];
    }

  [(id<IBSelectionOwners,IBEditors>)_selectionOwner deleteSelection];
}

- (IBAction) selectAllItems: (id)sender
{
  return;
}

/** Grouping */

- (IBAction) groupSelectionInSplitView: (id)sender
{
  if ([[_selectionOwner selection] count] < 2
      || [_selectionOwner respondsToSelector: @selector(groupSelectionInSplitView)] == NO)
    return;

  [(GormGenericEditor *)_selectionOwner groupSelectionInSplitView];
}

- (IBAction) groupSelectionInBox: (id)sender
{
  if ([_selectionOwner respondsToSelector: @selector(groupSelectionInBox)] == NO)
    return;
  [(GormGenericEditor *)_selectionOwner groupSelectionInBox];
}

- (IBAction) groupSelectionInView: (id)sender
{
  if ([_selectionOwner respondsToSelector: @selector(groupSelectionInView)] == NO)
    return;
  [(GormGenericEditor *)_selectionOwner groupSelectionInView];
}

- (IBAction) groupSelectionInScrollView: (id)sender
{
  if ([_selectionOwner respondsToSelector: @selector(groupSelectionInScrollView)] == NO)
    return;
  [(GormGenericEditor *)_selectionOwner groupSelectionInScrollView];
}

- (IBAction) groupSelectionInMatrix: (id)sender
{
  if ([_selectionOwner respondsToSelector: @selector(groupSelectionInMatrix)] == NO)
    return;
  [(GormGenericEditor *)_selectionOwner groupSelectionInMatrix];
}

- (IBAction) ungroup: (id)sender
{
  // NSLog(@"ungroup: _selectionOwner %@", _selectionOwner);
  if ([_selectionOwner respondsToSelector: @selector(ungroup)] == NO)
    return;
  [(GormGenericEditor *)_selectionOwner ungroup];
}

/** Classes actions */

- (IBAction) createSubclass: (id)sender
{
  [(GormDocument *)[self activeDocument] createSubclass: sender];
}

- (IBAction) loadClass: (id)sender
{
  // Call the current document and create the class
  // descibed by the header
  [(GormDocument *)[self activeDocument] loadClass: sender];
}

- (IBAction) createClassFiles: (id)sender
{
  [(GormDocument *)[self activeDocument] createClassFiles: sender];
}

- (IBAction) instantiateClass: (id)sender
{
   [(GormDocument *)[self activeDocument] instantiateClass: sender];
}

- (IBAction) addAttributeToClass: (id)sender
{
  [(GormDocument *)[self activeDocument] addAttributeToClass: sender];
}

- (IBAction) remove: (id)sender
{
  [(GormDocument *)[self activeDocument] remove: sender];
}

/** Palettes Actions... */

- (IBAction) inspector: (id) sender
{
  [[[self inspectorsManager] panel] makeKeyAndOrderFront: self];
}

- (IBAction) palettes: (id) sender
{
  [[[self palettesManager] panel] makeKeyAndOrderFront: self];
}

- (IBAction) loadPalette: (id) sender
{
  [[self palettesManager] openPalette: sender];
}

// Translation
- (IBAction) importXLIFFDocument: (id)sender
{
  NSArray	*fileTypes = [NSArray arrayWithObjects: @"xliff", nil];
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
      GormDocument *doc = (GormDocument *)[self activeDocument];
      NSMutableArray *allObjects = [doc _collectAllObjects];
      NSString *filename = [oPanel filename];
      NSEnumerator *en = nil;
      id obj = nil;
      BOOL result = NO;
      
      NS_DURING
	{
	  GormXLIFFDocument *xd = [GormXLIFFDocument xliffWithGormDocument: doc];
	  result = [xd importXLIFFDocumentWithName: filename];
	}
      NS_HANDLER
	{
	  NSString *message = [localException reason];
	  NSRunAlertPanel(_(@"Problem loading XLIFF"),
			  message, nil, nil, nil);
	}
      NS_ENDHANDLER;

      // If actual translation was done, then refresh the objects...
      if (result == YES)
	{
	  [doc touch]; // mark the document as modified...
	  
	  // change to translated values.
	  en = [allObjects objectEnumerator];
	  while((obj = [en nextObject]) != nil)
	    {
	      if([obj isKindOfClass: [NSView class]])
		{
		  [obj setNeedsDisplay: YES];
		}
	      
	      // redisplay/flush, if the object is a window.
	      if([obj isKindOfClass: [NSWindow class]])
		{
		  NSWindow *w = (NSWindow *)obj;
		  [w setViewsNeedDisplay: YES];
		  [w disableFlushWindow];
		  [[w contentView] setNeedsDisplay: YES];
		  [[w contentView] displayIfNeeded];
		  [w enableFlushWindow];
		  [w flushWindowIfNeeded];
		}
	    }      
	}  
    }
}

- (IBAction) exportXLIFFDocument: (id)sender
{
  NSSavePanel *savePanel = [NSSavePanel savePanel];
  NSBundle *bundle = [NSBundle bundleForClass: [GormLanguageViewController class]];
  NSModalResponse result = 0;
  GormDocument *doc = (GormDocument *)[self activeDocument];

  if (doc != nil)
    {
      NSString *fn = [[doc fileURL] path];

      fn = [[fn lastPathComponent] stringByDeletingPathExtension];
      fn = [fn stringByAppendingPathExtension: @"xliff"];
      _vc = [[GormLanguageViewController alloc]
	      initWithNibName: @"GormLanguageViewController"
		       bundle: bundle];
      
      
      NSDebugLog(@"view = %@, _vc = %@", [_vc view], _vc);
      
      [savePanel setTitle: @"Export XLIFF"];
      [savePanel setAccessoryView: [_vc view]];
      [savePanel setDelegate: self];
      // [savePanel setURL: [NSURL fileURLWithPath: fn]];
		 
      result = [savePanel runModalForDirectory: nil
					  file: fn];
      if (NSModalResponseOK == result)
	{
	  NSString *filename = [[savePanel URL] path];
	  GormXLIFFDocument *xd = [GormXLIFFDocument xliffWithGormDocument: doc];
	  
	  [xd exportXLIFFDocumentWithName: filename
		       withSourceLanguage: [_vc sourceLanguageIdentifier]
			andTargetLanguage: [_vc targetLanguageIdentifier]];
	}
    }
}

- (NSString *) panel: (id)sender
 userEnteredFilename: (NSString *)filename
	   confirmed: (BOOL)flag
{
  if (flag == YES)
    {
      NSDebugLog(@"Writing the document... %@", filename);
    }
  else
    {
      NSDebugLog(@"%@ not saved", filename);
    }
  return filename;
}

/**
 * This method is used to translate all of the strings in the file from one language
 * into another.  This is helpful when attempting to translate an application for use
 * in different locales.
 */
- (IBAction) translate: (id)sender
{
  NSArray	*fileTypes = [NSArray arrayWithObjects: @"strings", nil];
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
      GormDocument *doc = (GormDocument *)[self activeDocument];
      NSMutableArray *allObjects = [doc _collectAllObjects];
      NSString *filename = [oPanel filename];
      NSEnumerator *en = nil;
      id obj = nil;

      NS_DURING
	{
	  [doc importStringsFromFile: filename];
	}
      NS_HANDLER
	{
	  NSString *message = [localException reason];
	  NSRunAlertPanel(_(@"Problem loading strings"),
			  message, nil, nil, nil);
	}
      NS_ENDHANDLER;

      [doc touch]; // mark the document as modified...
      
      // change to translated values.
      en = [allObjects objectEnumerator];
      while((obj = [en nextObject]) != nil)
	{
	  if([obj isKindOfClass: [NSView class]])
	    {
	      [obj setNeedsDisplay: YES];
	    }
	  
	  // redisplay/flush, if the object is a window.
	  if([obj isKindOfClass: [NSWindow class]])
	    {
	      NSWindow *w = (NSWindow *)obj;
	      [w setViewsNeedDisplay: YES];
	      [w disableFlushWindow];
	      [[w contentView] setNeedsDisplay: YES];
	      [[w contentView] displayIfNeeded];
	      [w enableFlushWindow];
	      [w flushWindowIfNeeded];
	    }
	}
    } 
}

/**
 * This method is used to export all strings in a document to a file for Language
 * translation.  This allows the user to see all of the strings which can be translated
 * and allows the user to provide a translateion for each of them.
 */
- (IBAction) exportStrings: (id)sender
{
  NSSavePanel	*sp = [NSSavePanel savePanel];
  int		result;

  [sp setRequiredFileType: @"strings"];
  [sp setTitle: _(@"Save strings file as...")];
  result = [sp runModalForDirectory: NSHomeDirectory()
	       file: nil];
  if (result == NSOKButton)
    {
      NSString *filename = [sp filename];
      GormDocument *doc = (GormDocument *)[self activeDocument];

      [doc exportStringsToFile: filename];
    } 
}

// Print
- (IBAction) print: (id) sender
{
  [[NSApp keyWindow] print: sender];
}

@end
