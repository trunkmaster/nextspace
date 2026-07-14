/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2002-2021 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan
	    Riccardo Mottola

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import "PCEditor.h"
#import "PCEditorView.h"

#import <Protocols/Preferences.h>
#import "Modules/Preferences/EditorFSC/PCEditorFSCPrefs.h"
#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCLogController.h>

#import <AppKit/NSFont.h>

#define PARENTHESIS_HL_DELAY     0.1
#define STATUS_LINE_UPDATE_DELAY 0.1

@implementation PCEditor (UInterface)

- (void)_createWindow
{
  NSScrollView    *_extScrollView;
  unsigned int style;
  NSRect       winContentRect;
  NSRect       rect;
  float        windowWidth;
  NSView       *containerView;

//  PCLogInfo(self, @"[_createWindow]");

  style = NSTitledWindowMask
        | NSClosableWindowMask
        | NSMiniaturizableWindowMask
        | NSResizableWindowMask;


  windowWidth = [[NSFont userFixedPitchFontOfSize:0.0] widthOfString:@"A"];
  windowWidth *= 80;
  windowWidth += 35;
  rect = NSMakeRect(0,0,windowWidth,320);

  _window = [[NSWindow alloc] initWithContentRect:rect
					styleMask:style
					  backing:NSBackingStoreBuffered
					    defer:YES];
  [_window setReleasedWhenClosed:NO];
  [_window setMinSize:NSMakeSize(512,320)];
  [_window setDelegate:self];
  [_window center];
  winContentRect = [[_window contentView] frame];
  
  // Scroll view
  _extScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,16,windowWidth,320-16)];
  [_extScrollView setHasHorizontalScroller:NO];
  [_extScrollView setHasVerticalScroller:YES];
  [_extScrollView setAutoresizingMask: (NSViewWidthSizable|NSViewHeightSizable)];
  rect = [[_extScrollView contentView] frame];

  // Text view in ScrollView
  _extEditorView = [self _createEditorViewWithFrame:rect];
  [_extScrollView setDocumentView:_extEditorView];
  RELEASE(_extEditorView);

  // Status Line
  _extStatusField = [[NSTextField alloc] initWithFrame: NSMakeRect(20, 0, winContentRect.size.width, 15)];
  [_extStatusField setBezeled:NO];
  [_extStatusField setEditable:NO];
  [_extStatusField setSelectable:NO];
  [_extStatusField setDrawsBackground:NO];
  [_extStatusField setAutoresizingMask: NSViewWidthSizable];
  [_extStatusField setFont:[NSFont userFixedPitchFontOfSize:10.0]];

  // Container of Scroll + Status Field
  containerView = [[NSView alloc] initWithFrame:winContentRect];
  [containerView setAutoresizingMask: (NSViewWidthSizable|NSViewHeightSizable)];
  [containerView addSubview:_extStatusField];
  [containerView addSubview:_extScrollView];
  RELEASE(_extScrollView);
  RELEASE(_extStatusField);

  // Include scroll view
  [_window setContentView:containerView];
  [_window makeFirstResponder:_extEditorView];
  RELEASE(containerView);

  // Honor "edited" state
  [_window setDocumentEdited:_isEdited];
}

- (void)_createInternalView
{
  NSScrollView    *_intScrollView;
  NSRect contRect = NSMakeRect(0,0,512,320);
  NSRect rect;

  // Scroll view
  _intScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,16,512,320-16)];
  [_intScrollView setHasHorizontalScroller:NO];
  [_intScrollView setHasVerticalScroller:YES];
  [_intScrollView setBorderType:NSBezelBorder];
  [_intScrollView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
  rect = [[_intScrollView contentView] frame];

  // Text view
  _intEditorView = [self _createEditorViewWithFrame:rect];

  // Status Line
  _intStatusField = [[NSTextField alloc] initWithFrame:NSMakeRect(20,0,512,15)];
  [_intStatusField setBezeled:NO];
  [_intStatusField setEditable:NO];
  [_intStatusField setSelectable:NO];
  [_intStatusField setDrawsBackground:NO];
  [_intStatusField setAutoresizingMask: NSViewWidthSizable];
  [_intStatusField setFont:[NSFont userFixedPitchFontOfSize:10.0]];

  // Container of Scroll + Status field
  _containerView = [[NSView alloc] initWithFrame:contRect];
  [_containerView setAutoresizingMask: (NSViewWidthSizable|NSViewHeightSizable)];
  [_containerView addSubview:_intStatusField];
  [_containerView addSubview:_intScrollView];
  RELEASE(_intStatusField);
  RELEASE(_intScrollView);

  /*
   * Setting up ext view / scroll view / window
   */
  [_intScrollView setDocumentView:_intEditorView];
  RELEASE(_intEditorView);
}

- (PCEditorView *)_createEditorViewWithFrame:(NSRect)fr
{
  PCEditorView       *ev = nil;
  NSTextContainer    *tc = nil;
  NSLayoutManager    *lm = nil;
  NSColor            *bSelCol = nil;
  NSColor            *tSelCol = nil;
  id <PCPreferences>  prefs;
  NSDictionary       *selAttributes;

  /*
   * setting up the objects needed to manage the view but using the
   * shared textStorage.
   */

  lm = [[NSLayoutManager alloc] init];
  tc = [[NSTextContainer alloc] initWithContainerSize:fr.size];
  [lm addTextContainer:tc];
  RELEASE(tc);

  [_storage addLayoutManager:lm];
  RELEASE(lm);

  ev = [[PCEditorView alloc] initWithFrame:fr textContainer:tc];
  [ev setBackgroundColor:textBackgroundColor];
  [ev setTextColor:textColor];
  [ev setEditor:self];
  if (_highlightSyntax)
    {
      [ev createSyntaxHighlighterForFileType:[_path pathExtension]];
      [[ev textStorage] setFont:[ev editorFont]];
    }

  [ev setMinSize:NSMakeSize(0, 0)];
  [ev setMaxSize:NSMakeSize(1e7, 1e7)];
  [ev setRichText:YES];
  [ev setUsesFindPanel: YES];
  [ev setVerticallyResizable:YES];
  [ev setHorizontallyResizable:NO];
  [ev setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [ev setTextContainerInset:NSMakeSize(5, 5)];
  [[ev textContainer] setWidthTracksTextView:YES];

  [[ev textContainer] setContainerSize:NSMakeSize(fr.size.width, 1e7)];

  [ev setEditable:_isEditable];

  prefs = [[_editorManager projectManager] prefController];
  bSelCol = [prefs colorForKey:EditorSelectionColor defaultValue:[NSColor blackColor]];
  bSelCol = [bSelCol colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
  tSelCol = [NSColor colorWithCalibratedRed: 1.0 - [bSelCol redComponent]
				      green: 1.0 - [bSelCol greenComponent]
				       blue: 1.0 - [bSelCol blueComponent]
				      alpha: [bSelCol alphaComponent]];
  selAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
				  bSelCol, NSBackgroundColorAttributeName,
				tSelCol, NSForegroundColorAttributeName,
				nil];
  [ev setSelectedTextAttributes:selAttributes];
  [ev turnOffLigatures:self];

  // Activate undo
  [ev setAllowsUndo: YES];

  [ev setDelegate:self];

  [[NSNotificationCenter defaultCenter]
    addObserver:self 
       selector:@selector(textDidChange:)
	   name:NSTextDidChangeNotification
	 object:ev];

  return ev;
}

@end

@implementation PCEditor

// ===========================================================================
// ==== Initialization
// ===========================================================================

- (id)init
{
  if ((self = [super init]))
    {
      _extEditorView = nil;
      _intEditorView = nil;
      _storage = nil;
      _categoryPath = nil;
      _window = nil;

      _isEdited = NO;
      _isWindowed = NO;
      _isExternal = YES;

      _highlightSyntax = YES;

      ASSIGN(defaultFont, [PCEditorView defaultEditorFont]);
      ASSIGN(highlightFont, [PCEditorView defaultEditorFont]);
      ASSIGN(highlightColor, [NSColor greenColor]);
      ASSIGN(textColor, [NSColor blackColor]);
      ASSIGN(backgroundColor, [NSColor whiteColor]);
      ASSIGN(readOnlyColor, [NSColor lightGrayColor]);

      highlighted_chars[0] = NSNotFound;
      highlighted_chars[1] = NSNotFound;

      undoManager = [[NSUndoManager alloc] init];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog(@"PCEditor: %@ dealloc", [_path lastPathComponent]);
#endif

  [_extEditorView setEditor: nil];
  [_window setDelegate: nil];


  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_window close];

  // _window is setReleasedWhenClosed:YES
  RELEASE(_path);
  RELEASE(_categoryPath);
  RELEASE(_storage);
  RELEASE(_window);

//  RELEASE(parserClasses);
  RELEASE(parserMethods);
  RELEASE(aParser);

  RELEASE(defaultFont);
  RELEASE(highlightFont);
  RELEASE(textColor);
  RELEASE(backgroundColor);
  RELEASE(readOnlyColor);

  RELEASE(undoManager);

  RELEASE(_lastSaveDate);

  [super dealloc];
}

// --- Protocol
- (void)setParser:(id)parser
{
//  NSLog(@"RC aParser:%i parser:%i", 
//	[aParser retainCount], [parser retainCount]);
  ASSIGN(aParser, parser);
//  NSLog(@"RC aParser:%i parser:%i", 
//	[aParser retainCount], [parser retainCount]);
}

- (id)openFileAtPath:(NSString *)filePath
       editorManager:(id)editorManager
	    editable:(BOOL)editable
{
  NSString            *text;
  NSAttributedString  *attributedString = [NSAttributedString alloc];
  NSMutableDictionary *attributes = [NSMutableDictionary new];
  NSFont              *font;
  id <PCPreferences>  prefs;
  NSFileManager       *fm;

  // Inform about future file opening
  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCEditorWillOpenNotification
		  object:self];

  _editorManager = editorManager;
  _path = [filePath copy];
  _isEditable = editable;
  prefs = [[_editorManager projectManager] prefController];

  // Prepare
  font = [NSFont userFixedPitchFontOfSize:0.0];
  if (editable)
    {
      NSColor *col;

      col = [prefs colorForKey:EditorBackgroundColor defaultValue:backgroundColor];
      textBackgroundColor = col;
    }
  else
    {
      textBackgroundColor = readOnlyColor;
    }

  ASSIGN(textColor, [prefs colorForKey:EditorForegroundColor defaultValue:textColor]);

  [attributes setObject:font forKey:NSFontAttributeName];
  [attributes setObject:textBackgroundColor forKey:NSBackgroundColorAttributeName];
  [attributes setObject:textColor forKey:NSForegroundColorAttributeName];
  [attributes setObject:[NSNumber numberWithInt: 0] // disable ligatures
		 forKey:NSLigatureAttributeName];

  text  = [NSString stringWithContentsOfFile:_path];
  attributedString = [attributedString initWithString:text attributes:attributes];
  [attributes release];

  _storage = [[NSTextStorage alloc] init];
  [_storage setAttributedString:attributedString];
  RELEASE(attributedString);

  fm = [NSFileManager defaultManager];
  ASSIGN(_lastSaveDate, [[fm fileAttributesAtPath:_path traverseLink:NO] fileModificationDate]);

//  [self _createInternalView];
/*  if (categoryPath) // category == nil if we're non project editor
    {
      NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

      if (![[ud objectForKey:SeparateEditor] isEqualToString:@"YES"])
	{
	  [self _createInternalView];
	}
    }*/

  // File open was finished
  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCEditorDidOpenNotification
		  object:self];

  return self;
}

- (id)openExternalEditor:(NSString *)editor
	 	withPath:(NSString *)file
	   editorManager:(id)aDelegate
{
  NSTask         *editorTask = nil;
  NSArray        *ea = nil;
  NSMutableArray *args = nil;
  NSString       *app = nil;

  if (!(self = [super init]))
    {
      return nil;
    }

  _editorManager = aDelegate;
  _path = [file copy];

  // Task
  ea = [editor componentsSeparatedByString:@" "];
  args = [NSMutableArray arrayWithArray:ea];
  app = [ea objectAtIndex:0];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector (externalEditorDidClose:)
           name:NSTaskDidTerminateNotification
         object:nil];

  editorTask = [[NSTask alloc] init];
  [editorTask setLaunchPath:app];
  [args removeObjectAtIndex:0];
  [args addObject:file];
  [editorTask setArguments:args];
  
  [editorTask launch];
//  AUTORELEASE(editorTask);

  // Inform about file opening
  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCEditorDidOpenNotification
                  object:self];

  return self;
}
// --- Protocol End

- (void)externalEditorDidClose:(NSNotification *)aNotif
{
  NSString *path = [[[aNotif object] arguments] lastObject];

  if (![path isEqualToString:_path])
    {
      NSLog(@"external editor task terminated");
      return;
    }
    
  NSLog(@"Our Editor task terminated");

  // Inform about closing
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCEditorDidCloseNotification
                  object:self];
}

// ===========================================================================
// ==== CodeEditor protocol
// ===========================================================================

// --- Accessor methods

- (id)editorManager
{
  return _editorManager;
}

- (NSWindow *)editorWindow
{
  return _window;
}

- (NSView *)editorView 
{
  if (!_containerView)
    {
      [self _createInternalView];
    }
  return _intEditorView;
}

- (NSView *)componentView
{
  if (!_containerView)
    {
      [self _createInternalView];
    }
  return _containerView;
}

- (NSString *)path
{
  return _path;
}

- (void)setPath:(NSString *)path
{
  NSMutableDictionary *notifDict = [[NSMutableDictionary dictionary] retain];

  // Prepare notification object
  [notifDict setObject:self forKey:@"Editor"];
  [notifDict setObject:_path forKey:@"OldFile"];
  [notifDict setObject:path forKey:@"NewFile"];

  // Set path
  [_path autorelease];
  _path = [path copy];

  // Post notification
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCEditorDidChangeFileNameNotification
                  object:notifDict];

  [notifDict autorelease];
}

- (NSString *)categoryPath
{
  return _categoryPath;
}

- (void)setCategoryPath:(NSString *)path
{
  [_categoryPath autorelease];
  _categoryPath = [path copy];
}

- (BOOL)isEdited
{
  return _isEdited;
}

- (void)setIsEdited:(BOOL)yn
{
  if (_window)
    {
      [_window setDocumentEdited:yn];
    }
  _isEdited = yn;
}

- (NSImage *)fileIcon
{
  NSString *fileExtension = [[_path lastPathComponent] uppercaseString];
  NSString *imageName = nil;
  NSString *imagePath = nil;
  NSBundle *bundle = nil;
  NSImage  *image = nil;

  fileExtension = [[[_path lastPathComponent] pathExtension] uppercaseString];
  if (_isEdited)
    {
      imageName = [NSString stringWithFormat:@"File%@H", fileExtension];
    }
  else
    {
      imageName = [NSString stringWithFormat:@"File%@", fileExtension];
    }

  bundle = [NSBundle bundleForClass:NSClassFromString(@"PCEditor")];

  imagePath = [bundle pathForResource:imageName ofType:@"tiff"];
  if (imagePath)
    {
      image = [[NSImage alloc] initWithContentsOfFile:imagePath];
    }
  else
    {
      NSLog(@"no image for %@", imageName);
    }
  return AUTORELEASE(image);
}

- (NSArray *)_methodsForClass:(NSString *)className
{
  NSEnumerator   *enumerator;
  NSDictionary   *method;
  NSDictionary   *class;
  NSMutableArray *items = [NSMutableArray array];
  NSRange        classRange;
  NSRange        methodRange;

  ASSIGN(parserClasses, [aParser classNames]);
  ASSIGN(parserMethods, [aParser methodNames]);

  enumerator = [parserClasses objectEnumerator];
  while ((class = [enumerator nextObject]))
    {
      if ([[class objectForKey:@"ClassName"] isEqualToString:className])
      {
	classRange = NSRangeFromString([class objectForKey:@"ClassBodyRange"]);
	break;
      }
    }

  methodRange = NSMakeRange(0, 0);
  enumerator = [parserMethods objectEnumerator];
  while ((method = [enumerator nextObject]))
    {
      //      NSLog(@"Method> %@", method);
      methodRange = NSRangeFromString([method objectForKey:@"MethodBodyRange"]);
      if (NSIntersectionRange(classRange, methodRange).length != 0)
	{
	  [items addObject:[method objectForKey:@"MethodName"]];
	}
    }

  return items;
}

- (NSArray *)browserItemsForItem:(NSString *)item
{
  NSEnumerator   *enumerator;
//  NSDictionary   *method;
  NSDictionary   *class;
  NSMutableArray *items = [NSMutableArray array];
  
  NSLog(@"PCEditor: asked for browser items for: %@", item);

  [aParser setString:[_storage string]];

  // If item is .m or .h file show class list
  if ([[item pathExtension] isEqualToString:@"m"] || [[item pathExtension] isEqualToString:@"mm"]
      || [[item pathExtension] isEqualToString:@"h"])
    {
      ASSIGN(parserClasses, [aParser classNames]);

      enumerator = [parserClasses objectEnumerator];
      while ((class = [enumerator nextObject]))
	{
	  NSLog(@"Class> %@", class);
	  [items addObject:[class objectForKey:@"ClassName"]];
	}
    }

  // If item starts with "@" show method list
  if ([[item substringToIndex:1] isEqualToString:@"@"])
    {
/*      ASSIGN(parserMethods, [aParser methodNames]);

      enumerator = [parserMethods objectEnumerator];
      while ((method = [enumerator nextObject]))
	{
	  //      NSLog(@"Method> %@", method);
	  [items addObject:[method objectForKey:@"MethodName"]];
	}*/
      return [self _methodsForClass:item];
    }

  return items;
}

- (void)show
{
  if (_isWindowed)
    {
      [_window makeKeyAndOrderFront:nil];
    }
}

- (void)setWindowed:(BOOL)yn
{
  if ( (yn && _isWindowed) || (!yn && !_isWindowed) )
    {
      return;
    }

  if (yn && !_isWindowed)
    {
      [self _createWindow];
      [_window setTitle:[NSString stringWithFormat: @"%@",
      [_path stringByAbbreviatingWithTildeInPath]]];
    }
  else if (!yn && _isWindowed)
    {
      [_window close];
    }

  _isWindowed = yn;
}

- (BOOL)isWindowed
{
  return _isWindowed;
}

// --- Object managment

- (BOOL)saveFileIfNeeded
{
  if ((_isEdited))
    {
      return [self saveFile];
    }

  return YES;
}

- (BOOL)saveFile
{
  BOOL           saved = NO;
  NSFileManager  *fm;
  NSDate         *fileModDate;

  if (_isEdited == NO)
    {
      return YES;
    }

  fm = [NSFileManager defaultManager];

  fileModDate = [[fm fileAttributesAtPath:_path traverseLink:NO] fileModificationDate];
  // Check if the file was ever written and its time is the same as the current file modification date
  if (!(_lastSaveDate && [fileModDate isEqualToDate:_lastSaveDate]))
    {
      NSInteger choice;

      PCLogInfo(self, @"File modified externally. %@ - %@", _lastSaveDate, fileModDate);
      choice = NSRunAlertPanel(@"Overwrite File?",
			       @"File %@ was modified externally. Overwrite?",
			       @"Cancel", @"Reload", @"Proceed", [_path lastPathComponent]);
      if (choice == NSAlertDefaultReturn)
	{
	  return NO;
	}
      else if (choice == NSAlertAlternateReturn)
	{
	  if ([self revertFileToSaved] == YES)
	    return NO;
	  NSLog(@"reload failed");
	  return NO;
	}
    }
    
  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCEditorWillSaveNotification
		  object:self];

  saved = [[_storage string] writeToFile:_path atomically:YES];
 
  if (saved == YES)
    {
      [self setIsEdited:NO];

      // re-read date just saved
      ASSIGN(_lastSaveDate, [[fm fileAttributesAtPath:_path traverseLink:NO] fileModificationDate]);
      // Send the notification to Gorm...
      if([[_path pathExtension] isEqual: @"h"])
	{
	  [[NSDistributedNotificationCenter defaultCenter]
	    postNotificationName: @"GormParseClassNotification"
			  object: _path];
	}

      [[NSNotificationCenter defaultCenter]
	postNotificationName:PCEditorDidSaveNotification
	  	      object:self];
    }
  else
    {
      NSRunAlertPanel(@"Save File",
		      @"Couldn't save file '%@'!",
		      @"OK", nil, nil, [_path lastPathComponent]);
    }

  return saved;
}

- (BOOL)saveFileTo:(NSString *)path
{
  return [[_storage string] writeToFile:path atomically:YES];
}

- (BOOL)revertFileToSaved
{
  NSString           *text = [NSString stringWithContentsOfFile:_path];
  NSAttributedString *as = nil;
  NSDictionary       *at = nil;
  NSFont             *ft = nil;
  NSFileManager      *fm;

  if (_isEdited == NO)
    {
      return YES;
    }

  if (NSAlertDefaultReturn !=
      NSRunAlertPanel(@"Revert",
		      @"%@ has been modified.  "
		      @"Are you sure you want to undo changes?",
		      @"Revert", @"Cancel", nil,
		      [_path lastPathComponent]))
      {
	return NO;
      }

  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCEditorWillRevertNotification
		  object:self];

  // This is temporary
  ft = [NSFont userFixedPitchFontOfSize:0.0];
  at = [NSDictionary dictionaryWithObjectsAndKeys:
		       ft, NSFontAttributeName,
			 [NSNumber numberWithInt: 0], NSLigatureAttributeName,
		     nil];

  as = [[NSAttributedString alloc] initWithString:text attributes:at];

  [self setIsEdited:NO];

  // Operate on the text storage!
  [_storage setAttributedString:as];
  RELEASE(as);

  [_intEditorView setNeedsDisplay:YES];
  [_extEditorView setNeedsDisplay:YES];

  fm = [NSFileManager defaultManager];
  ASSIGN(_lastSaveDate, [[fm fileAttributesAtPath:_path traverseLink:NO] fileModificationDate]);
  
  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCEditorDidRevertNotification
		  object:self];
		  
  return YES;
}

// FIXME: Do we really need this method?
- (BOOL)closeFile:(id)sender save:(BOOL)save
{
  if (save == YES)
    {
      [self saveFileIfNeeded];
    }

  // Close window first if visible
  if (_isWindowed && [_window isVisible] && (sender != _window))
    {
      [_window close];
    }

  // Inform about closing
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCEditorDidCloseNotification
		  object:self];

  return YES;
}

- (BOOL)close:(id)sender
{
  if ([self editorShouldClose] == YES)
    {
      // Close window first if visible
      if (_isWindowed && [_window isVisible] && (sender != _window))
	{
	  [_window close];
	}

      // Inform about closing
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:PCEditorDidCloseNotification
	              object:self];

      return YES;
    }

  return NO;
}

- (BOOL)editorShouldClose
{
  if (_isEdited)
    {
      int ret;

      if (_isWindowed && [_window isVisible])
	{
	  [_window makeKeyAndOrderFront:self];
	}

      ret = NSRunAlertPanel(@"Close File",
			    @"File %@ has been modified. Save?",
			    @"Save and Close", @"Don't save", @"Cancel", 
			    [_path lastPathComponent]);
      switch (ret)
	{
	case NSAlertDefaultReturn: // Save And Close
	  if ([self saveFile] == NO)
	    {
	      return NO;
	    }
	  break;

	case NSAlertAlternateReturn: // Don't save
	  break;

	case NSAlertOtherReturn: // Cancel
	  return NO;
	  break;
	}

      [self setIsEdited:NO];
    }

  return YES;
}

// ===========================================================================
// ==== Window delegate
// ===========================================================================

- (BOOL)windowShouldClose:(id)sender
{
  if ([sender isEqual:_window])
    {
      if (_containerView) 
	{
	  // Just close if this file also displayed in int view
	  _isWindowed = NO;
	  return YES;
	}
      else
	{
    	  return [self close:sender];
	}
    }

  return NO;
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
/*  if ([[aNotification object] isEqual:_window] && [_window isVisible])
    {
      [_window makeFirstResponder:_extEditorView];
    }*/
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
/*  if ([[aNotification object] isEqual:_window] && [_window isVisible])
    {
      [_window makeFirstResponder:_extEditorView];
    }*/
  [self resignFirstResponder:_extEditorView];
}


- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
  return undoManager;
}


// ===========================================================================
// ==== TextView (_intEditorView, _extEditorView) delegate
// ===========================================================================

- (void)textDidChange:(NSNotification *)aNotification
{
  id object = [aNotification object];

  if ([object isKindOfClass:[PCEditorView class]]
      && (object == _intEditorView || object == _extEditorView))
    {
      if (_isEdited == NO)
	{
	  [[NSNotificationCenter defaultCenter]
	    postNotificationName:PCEditorWillChangeNotification
			  object:self];

	  [self setIsEdited:YES];
	  
	  [[NSNotificationCenter defaultCenter]
	    postNotificationName:PCEditorDidChangeNotification
			  object:self];
	}
    }
}

- (NSRange)textView:(NSTextView *)textView
willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange
   toCharacterRange:(NSRange)newSelectedCharRange
{
  NSDebugLog(@"Will change selection from %@ to %@", NSStringFromRange(oldSelectedCharRange), NSStringFromRange(newSelectedCharRange));

  if (editorTextViewIsPressingKey == NO)
    {
      // unhighlight also invalidates old locations
      if (textView == _intEditorView || textView == _extEditorView)
	[self unhighlightCharacter: textView];
    }

  return newSelectedCharRange;
}

- (void)textViewDidChangeSelection:(NSNotification *)notification
{
  id object;

  object = [notification object];

  NSDebugLog(@"received textViewDidChangeSelection notification");
  // calculate current line
  if ([object isKindOfClass:[NSTextView class]])
    {
      if (nil != lsTimer)
	{
	  [lsTimer invalidate];
	  lsTimer = nil;
	}

      lsTimer = [NSTimer scheduledTimerWithTimeInterval:STATUS_LINE_UPDATE_DELAY
						 target:self
					       selector:@selector(computeCurrentLineFromTimer:)
					       userInfo:object
						repeats:NO];
    }
}

- (void)editorTextViewWillPressKey:sender
{
  editorTextViewIsPressingKey = YES;

  if (sender == _intEditorView || sender == _extEditorView)
    [self unhighlightCharacter: sender];
  else
    NSLog(@"PCEditor: unexpected sender");
}

- (void)editorTextViewDidPressKey:sender
{
  if (sender == _intEditorView || sender == _extEditorView)
    {
      if (nil != phlTimer)
	{
	  [phlTimer invalidate];
	  phlTimer = nil;
	}

      phlTimer = [NSTimer scheduledTimerWithTimeInterval:PARENTHESIS_HL_DELAY
						  target:self
						selector:@selector(computeNewParenthesisNestingFromTimer:)
						userInfo:sender
						 repeats:NO];
    }
  else
    NSLog(@"PCEditor: unexpected sender");

  editorTextViewIsPressingKey = NO;
}

- (BOOL)becomeFirstResponder:(PCEditorView *)view
{
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCEditorDidBecomeActiveNotification
		  object:self];

  return YES;
}

- (BOOL)resignFirstResponder:(PCEditorView *)view
{
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCEditorDidResignActiveNotification
		  object:self];

  return YES;
}


// ===========================================================================
// ==== Parser and scrolling and Line Status
// ===========================================================================

// === Scrolling

- (void)fileStructureItemSelected:(NSString *)item
{
  NSString *firstSymbol;

  NSLog(@"[PCEditor] selected file structure item: %@", item);

  firstSymbol = [item substringToIndex:1];
  if ([firstSymbol isEqualToString:@"@"])      // class selected
    {
      [self scrollToClassName:item];
    }
  else if ([firstSymbol isEqualToString:@"-"]  // method selected
	|| [firstSymbol isEqualToString:@"+"])
    {
      [self scrollToMethodName:item];
    }
}

- (void)scrollToClassName:(NSString *)className
{
  NSEnumerator   *enumerator = nil;
  NSDictionary   *class = nil;
  NSRange        classNameRange;

  NSLog(@"SCROLL to class: \"%@\"", className);

  classNameRange = NSMakeRange(0, 0);
  enumerator = [parserClasses objectEnumerator];
  while ((class = [enumerator nextObject]))
    {
      if ([[class objectForKey:@"ClassName"] isEqualToString:className])
	{
	  classNameRange = 
	    NSRangeFromString([class objectForKey:@"ClassNameRange"]);
	  break;
	}
    }

  NSLog(@"classNameRange: %@", NSStringFromRange(classNameRange));
  if (classNameRange.length != 0)
    {
      [_intEditorView setSelectedRange:classNameRange];
      [_intEditorView scrollRangeToVisible:classNameRange];
    }
}

- (void)scrollToMethodName:(NSString *)methodName
{
  NSEnumerator   *enumerator = nil;
  NSDictionary   *method = nil;
  NSRange        methodNameRange;

  NSLog(@"SCROLL to method: \"%@\"", methodName);

  methodNameRange = NSMakeRange(0, 0);
  enumerator = [parserMethods objectEnumerator];
  while ((method = [enumerator nextObject]))
    {
      if ([[method objectForKey:@"MethodName"] isEqualToString:methodName])
	{
	  methodNameRange = 
	    NSRangeFromString([method objectForKey:@"MethodNameRange"]);
	  break;
	}
    }

  NSLog(@"methodNameRange: %@", NSStringFromRange(methodNameRange));
  if (methodNameRange.length != 0)
    {
      [_intEditorView setSelectedRange:methodNameRange];
      [_intEditorView scrollRangeToVisible:methodNameRange];
    }
}

- (void)scrollToLineNumber:(NSUInteger)lineNumber
{
  [_intEditorView goToLineNumber:lineNumber];
  [_extEditorView goToLineNumber:lineNumber];
  [_intEditorView centerSelectionInVisibleArea: self];
  [_extEditorView centerSelectionInVisibleArea: self];
}

- (void)computeCurrentLineFromTimer: (NSTimer *)timer
{
  lsTimer = nil;
  [self computeCurrentLine:[timer userInfo]];
}

- (void)computeCurrentLine: (NSTextView *)editorView
{
  NSTextView *tv = editorView;
  NSString *str = [tv string];
  NSRange selection;
  NSUInteger selLine = NSNotFound;

  // for speed reasons we cache [NSString characterAtIndex:index]
  SEL charAtIndexSel = @selector(characterAtIndex:);
  unichar (*charAtIndexFunc)(NSString *, SEL, NSUInteger);
  charAtIndexFunc = (unichar (*)())[str methodForSelector:charAtIndexSel]; 

  selection = [tv selectedRange];
  // now we calculate given the selection the line count, splitting on \n
  // calling lineRangeForRange / paragraphForRange does the same thing
  // we want to avoid to scan the string twice
  {
    NSUInteger i;
    unichar ch;
    NSUInteger nlCount;

    nlCount = 0;
    for (i = 0; i < selection.location; i++)
      {
	// ch = [str characterAtIndex:i];
	ch = (*charAtIndexFunc)(str, charAtIndexSel, i);
	if (ch == (unichar)0x000A) // new line
	  nlCount++;
      }

    selLine = nlCount + 1;
  }

  if (selLine != NSNotFound)
    {
      [_intStatusField setStringValue: [NSString stringWithFormat:@"%u", (unsigned)selLine]];
      [_extStatusField setStringValue: [NSString stringWithFormat:@"%u", (unsigned)selLine]];
    }
}

@end

// ===========================================================================
// ==== Menu actions
// ===========================================================================
@implementation PCEditor (Menu)

- (void)pipeOutputOfCommand:(NSString *)command
{
  NSTask * task;
  NSPipe * inPipe, * outPipe;
  NSString * inString, * outString;
  NSFileHandle * inputHandle;

  inString = [[_intEditorView string] substringWithRange:
    [_intEditorView selectedRange]];
  inPipe = [NSPipe pipe];
  outPipe = [NSPipe pipe];

  task = [[NSTask new] autorelease];

  [task setLaunchPath: @"/bin/sh"];
  [task setArguments: [NSArray arrayWithObjects: @"-c", command, nil]];
  [task setStandardInput: inPipe];
  [task setStandardOutput: outPipe];
  [task setStandardError: outPipe];

  inputHandle = [inPipe fileHandleForWriting];

  [task launch];
  [inputHandle writeData: [inString
    dataUsingEncoding: NSUTF8StringEncoding]];
  [inputHandle closeFile];
  [task waitUntilExit];
  outString = [[[NSString alloc]
    initWithData: [[outPipe fileHandleForReading] availableData]
        encoding: NSUTF8StringEncoding]
    autorelease];
  if ([task terminationStatus] != 0)
    {
      if (NSRunAlertPanel(_(@"Error running command"),
        _(@"The command returned with a non-zero exit status"
          @" -- aborting pipe.\n"
          @"Do you want to see the command's output?\n"),
        _(@"No"), _(@"Yes"), nil) == NSAlertAlternateReturn)
        {
          NSRunAlertPanel(_(@"The command's output"),
            outString, nil, nil, nil);
        }
    }
  else
    {
      [_intEditorView replaceCharactersInRange:[_intEditorView selectedRange]
                              withString:outString];
      [self textDidChange: nil];
    }
}

- (void)findNext:sender
{
//  [[TextFinder sharedInstance] findNext:self];
}

- (void)findPrevious:sender
{
//  [[TextFinder sharedInstance] findPrevious:self];
}

- (void)jumpToSelection:sender
{
  [_intEditorView scrollRangeToVisible:[_intEditorView selectedRange]];
}

@end

// ===========================================================================
// ==== Parenthesis highlighting
// ===========================================================================

/**
 * Checks whether a character is a delimiter.
 *
 * This function checks whether `character' is a delimiter character,
 * (i.e. one of "(", ")", "[", "]", "{", "}") and returns YES if it
 * is and NO if it isn't. Additionaly, if `character' is a delimiter,
 * `oppositeDelimiter' is set to a string denoting it's opposite
 * delimiter and `searchBackwards' is set to YES if the opposite
 * delimiter is located before the checked delimiter character, or
 * to NO if it is located after the delimiter character.
 */
static inline BOOL CheckDelimiter(unichar character,
                                  unichar * oppositeDelimiter,
                                  BOOL * searchBackwards)
{
  if (character == '(')
    {
      *oppositeDelimiter = ')';
      *searchBackwards = NO;

      return YES;
    }
  else if (character == ')')
    {
      *oppositeDelimiter = '(';
      *searchBackwards = YES;

      return YES;
    }
  else if (character == '[')
    {
      *oppositeDelimiter = ']';
      *searchBackwards = NO;

      return YES;
    }
  else if (character == ']')
    {
      *oppositeDelimiter = '[';
      *searchBackwards = YES;

      return YES;
    }
  else if (character == '{')
    {
      *oppositeDelimiter = '}';
      *searchBackwards = NO;

      return YES;
    }
  else if (character == '}')
    {
      *oppositeDelimiter = '{';
      *searchBackwards = YES;

      return YES;
    }
  else
    {
      return NO;
    }
}

/**
 * Attempts to find a delimiter in a certain string around a certain location.
 *
 * Attempts to locate `delimiter' in `string', starting at
 * location `startLocation' a searching forwards (backwards if
 * searchBackwards = YES) at most 1000 characters. The argument
 * `oppositeDelimiter' denotes what is considered to be the opposite
 * delimiter of the one being search for, so that nested delimiters
 * are ignored correctly.
 *
 * @return The location of the delimiter if it is found, or NSNotFound
 *      if it isn't.
 */
NSUInteger FindDelimiterInString(NSString * string,
                                 unichar delimiter,
                                 unichar oppositeDelimiter,
                                 NSUInteger startLocation,
                                 BOOL searchBackwards)
{
  NSUInteger i;
  NSUInteger length;
  unichar (*charAtIndex)(id, SEL, NSUInteger);
  SEL sel = @selector(characterAtIndex:);
  int nesting = 1;

  charAtIndex = (unichar (*)(id, SEL, NSUInteger)) [string
    methodForSelector: sel];

  if (searchBackwards)
    {
      if (startLocation < 1000)
        length = startLocation;
      else
        length = 1000;

      for (i=1; i <= length; i++)
        {
          unichar c;

          c = charAtIndex(string, sel, startLocation - i);
          if (c == delimiter)
            nesting--;
          else if (c == oppositeDelimiter)
            nesting++;

          if (nesting == 0)
            break;
        }

      if (i > length)
        return NSNotFound;
      else
        return startLocation - i;
    }
  else
    {
      if ([string length] < startLocation + 1000)
        length = [string length] - startLocation;
      else
        length = 1000;

      for (i=1; i < length; i++)
        {
          unichar c;

          c = charAtIndex(string, sel, startLocation + i);
          if (c == delimiter)
            nesting--;
          else if (c == oppositeDelimiter)
            nesting++;

          if (nesting == 0)
            break;
        }

      if (i == length)
        return NSNotFound;
      else
        return startLocation + i;
    }
}

@implementation PCEditor (Parenthesis)

- (void)unhighlightCharacter: (NSTextView *)editorView
{
  unsigned      i;
  NSTextStorage *textStorage = [editorView textStorage];

  [textStorage beginEditing];

  for (i = 0; i < 2; i++)
    {
      if (highlighted_chars[i] == NSNotFound)
	continue;

      NSRange       r = NSMakeRange(highlighted_chars[i], 1);

      [textStorage addAttribute:NSBackgroundColorAttributeName
			  value:textBackgroundColor
			  range:r];

      highlighted_chars[i] = NSNotFound;
    }

  [textStorage endEditing];
}

- (void)highlightCharacterPair:(NSTextView *)editorView
{
  unsigned i;
  NSTextStorage *textStorage = [editorView textStorage];

  [textStorage beginEditing];

  for (i = 0; i < 2; i++)
    {
      if (highlighted_chars[i] == NSNotFound)
	continue;

      NSRange       r = NSMakeRange(highlighted_chars[i], 1);

      NSAssert(textStorage, @"textstorage can't be nil");

      [textStorage addAttribute:NSBackgroundColorAttributeName
                          value:highlightColor
                          range:r];

    }
  [textStorage endEditing];
}

- (void)computeNewParenthesisNestingFromTimer:(NSTimer *)timer
{
  phlTimer = nil;
  [self computeNewParenthesisNesting:[timer userInfo]];
}

- (void)computeNewParenthesisNesting: (NSTextView *)editorView
{
  NSRange  selectedRange;
  NSString *myString;

  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DontTrackNesting"])
    {
      return;
    }

  NSAssert(editorView, @"computeNewParenthesis: editorView is nil");
  selectedRange = [editorView selectedRange];

  // make sure we un-highlit a previously highlit delimiter
  // should normally be already un-highlit by will change notif.
  [self unhighlightCharacter :editorView];

  // if we have a character at the selected location, check
  // to see if it is a delimiter character
  myString = [editorView string];
  if (selectedRange.length <= 1 && [myString length] > selectedRange.location)
    {
      unichar c;
      unichar oppositeDelimiter = 0;
      BOOL    searchBackwards = NO;

      c = [myString characterAtIndex:selectedRange.location];

      // if it is, search for the opposite delimiter in a range
      // of at most 1000 characters around it in either forward
      // or backward direction (depends on the kind of delimiter
      // we're searching for).
      if (CheckDelimiter(c, &oppositeDelimiter, &searchBackwards))
        {
          NSUInteger result;

          result = FindDelimiterInString(myString,
                                         oppositeDelimiter,
                                         c,
                                         selectedRange.location,
                                         searchBackwards);

          // and in case a delimiter is found, highlight it
          if (result != NSNotFound)
            {
	      highlighted_chars[0] = selectedRange.location;
	      highlighted_chars[1] = result;
	      [self highlightCharacterPair :editorView];
            }
        }
    }
}

@end

