//=============================================================================
// Workspace Manager: FileViewer path view implementation
//=============================================================================

#import <AppKit/AppKit.h>

#import <NXAppKit/NXIcon.h>
#import <NXAppKit/NXIconLabel.h>

#import "FileViewer.h"
#import "PathIcon.h"
#import "PathView.h"
#import "PathViewScroller.h"

@implementation PathView

- (void)dealloc
{
  TEST_RELEASE(path);
  TEST_RELEASE(files);
  TEST_RELEASE(multipleSelection);
  TEST_RELEASE(iconDragTypes);

  [super dealloc];
}

// - initWithFrame:(NSRect)r 
- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer
{
  // PathViewScroller *scroller;
  // NSScrollView     *sv;

  self = [super initWithFrame:r];

  _owner = fileViewer;

  // sv = [self enclosingScrollView];
  // scroller = [[PathViewScroller new] autorelease];
  // [scroller setDelegate:self];
  // [sv setHorizontalScroller:scroller];
  // [sv setHasHorizontalScroller:YES];
  // [sv setBackgroundColor:[NSColor windowBackgroundColor]];
  
  [self setTarget:self];
  [self setDelegate:self];
  // [self setAction:@selector(iconClicked:)];
  [self setDoubleAction:@selector(iconDoubleClicked:)];
  [self setDragAction:@selector(pathViewIconDragged:event:)];
  // [self registerForDraggedTypes:@[NSFilenamesPboardType]];
  [self setIconDragTypes:@[NSFilenamesPboardType]];
  
 // -adjustToFitIcons will be called
  autoAdjustsToFitIcons = YES; 
  // path view frame will be set inside -adjustToFitIcons
  adjustsToFillEnclosingScrollView = NO;
  fillWithHoleWhenRemovingIcon = NO;
  // NXIconView will not try to create multirow view
  isSlotsTallFixed = YES;
  slotsTall = 1;

  selectable = YES;
  allowsMultipleSelection = NO;
  allowsArrowsSelection = NO;
  allowsAlphanumericSelection = NO;

  arrowImage = [[NSImage alloc]
    initByReferencingFile:[[NSBundle bundleForClass:[self class]]
	  pathForResource:@"RightArrow" ofType: @"tiff"]];

  multiImage = [[NSImage alloc]
    initByReferencingFile:[[NSBundle bundleForClass:[self class]]
	  pathForResource:@"MultipleSelection" ofType: @"tiff"]];

  multipleSelection = [[PathIcon alloc] init];
  [multipleSelection setIconImage:multiImage];
  [multipleSelection setLabelString:@"Multiple items"];
  [multipleSelection setEditable:NO];
  
  path = nil;
  files = nil;

  target = self;
  action = @selector(changePath:);

  return self;
}

- (void)drawRect:(NSRect)r
{
  unsigned int i, n;

//  NSLog(@"drawRect of PathView at origin: %.0f, %.0f with size: %.0f x %.0f", 
//	r.origin.x, r.origin.y, r.size.width, r.size.height);

  for (i=1, n = [icons count]; i<n; i++)
    {
      NSPoint p;
      
      p = NSMakePoint((i * slotSize.width) - ([arrowImage size].width + 5),
		      slotSize.height/2);
      
      p.x = floorf(p.x);
      p.y = floorf(p.y);
      [arrowImage compositeToPoint:p
			 operation:NSCompositeSourceOver];
    }

  [super drawRect:r];
}

- (void)displayDirectory:(NSString *)aPath andFiles:(NSArray *)aFiles
{
  NSUInteger length;
  NSUInteger componentsCount = [[aPath pathComponents] count];
  NSUInteger i, n;
  NSUInteger lii; // last icon index in array of icons
  PathIcon   *_icon;
  NSString   *_path = @"";

  if (delegate == nil)
    {
      NSLog(@"PathView: attempt to set path without a delegate "
	      @"assigned to define the icons to use.");

      return;
    }

  length = [aPath length];

  // Remove a trailing "/" character from 'aPath'
  if (length > 1 && [aPath characterAtIndex:length-1] == '/')
    {
      aPath = [aPath substringToIndex:length-1];
    }

  // NSLog(@"[PathView] displayDirectory:%@(%i) andFiles:%@", 
  //       aPath, [[aPath pathComponents] count], aFiles);

  // NSLog(@"1. [PathView] icons count: %i components: %i", 
  //       [icons count], componentsCount);

  if ([icons count] > [self slotsWide])
    {
      NSLog(@"WARNING!!! # of icons > slotsWide! PathView must have 1 row!");
    }

  // Always clear last time selection
  // [[icons lastObject] deselect:nil];
  // [[icons lastObject] setEditable:NO];

  // Remove trailing icons
  lii = componentsCount;
  if ([aFiles count] > 0)
    {
      lii++;
    }

  for (n=[icons count], i=lii; i<n; i++)
    {
      PathIcon *itr = nil;

      // NSLog(@"[PathView] remove icon [%@] in slot: %i(%i)", 
      //       [icons lastObject], i, [icons count]);
      //      [self removeIconInSlot:NXMakeIconSlot(i,0)];
      itr = [icons lastObject];
      [self removeIcon:itr];
    }
  if ([icons lastObject] == multipleSelection)
    {
      // to avoid setting attributes by file selection
      [self removeIcon:multipleSelection];
    }

  // NSLog(@"2. [PathView] icons count: %i components: %i", 
  //       [icons count], componentsCount);

  // Set icons for path of "folders"
  // If path == aPath only file selection changed (see below).
  if (![path isEqualToString:aPath])
    {
      NSArray *pathComponents = [aPath pathComponents];

      ASSIGN(path, aPath);

      for (i=0; i<componentsCount; i++)
	{
	  NSString *component = [pathComponents objectAtIndex:i];

	  _path = [_path stringByAppendingPathComponent:component];

	  if (i < [icons count])
	    {
	      _icon = [icons objectAtIndex:i];
	    }
	  else
	    {
	      // NSLog(@"[PathView] creating new icon with path: %@ (%i,0)",
              //       _path, i);
	      _icon = [[PathIcon new] autorelease];
	      [_icon setLabelString:@"-"];
	      [_icon registerForDraggedTypes:iconDragTypes];
	      [self setSlotsWide:i+1];
	      [self putIcon:_icon intoSlot:NXMakeIconSlot(i, 0)];
	    }
	  [_icon deselect:nil];
      	  [_icon setEditable:NO];
	  [_icon setIconImage:[self imageForIconAtPath:_path]];
	  [_icon setPaths:[_owner absolutePathsForPaths:@[_path]]];
	}
    }

  // files == nil also make sense later
  ASSIGN(files, aFiles);

  // Set icon for file or files
  if (files != nil && [files count] > 0)
    {
      i = componentsCount;

      if ([files count] == 1)
	{
	  _path = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
	  if ([icons count] > i)
	    {
	      _icon = [icons objectAtIndex:i];
	    }
	  else
	    {
	      // NSLog(@"[PathView] creating new icon with path: %@", _path);
	      _icon = [[PathIcon new] autorelease];
	      [_icon setLabelString:@"-"];
	      [_icon registerForDraggedTypes:iconDragTypes];
	      [self setSlotsWide:i+1];
	      [self putIcon:_icon intoSlot:NXMakeIconSlot(i, 0)];
	    }
	  [_icon deselect:nil];
      	  [_icon setEditable:NO];
          [_icon setIconImage:[self imageForIconAtPath:_path]];
	  [_icon setPaths:[_owner absolutePathsForPaths:@[_path]]];
	}
      else
	{
	  NSEnumerator   *e = [files objectEnumerator];
	  NSString       *file;
	  NSMutableArray *relPaths = [[NSMutableArray new] autorelease];
          NXIcon         *icon;

	  while((file = [e nextObject]))
	    {
	      _path = [path stringByAppendingPathComponent:file];
	      [relPaths addObject:_path];
	    }

	  if ([icons indexOfObjectIdenticalTo:multipleSelection] == NSNotFound) 
	    {
	      [self setSlotsWide:i+1];
	      [self putIcon:multipleSelection intoSlot:NXMakeIconSlot(i,0)];
	    }
	  [multipleSelection setPaths:[_owner absolutePathsForPaths:relPaths]];
	}
    }

  // First icon
  [[icons objectAtIndex:0] setEditable:NO];

  // Last icon
  _icon = [icons lastObject];
  if ([icons count] > 1 && _icon != multipleSelection)
    {
      [_icon setEditable:YES];
    }
  
  // Update last icon in case of contents or attributes changes
  if ([aFiles count] == 1)
    {
      _path = [aPath stringByAppendingPathComponent:[aFiles objectAtIndex:0]];
      [_icon setIconImage:[self imageForIconAtPath:_path]];
    }

  [self selectIcons:[NSSet setWithObject:_icon]];

  [[_icon label] setIconLabelDelegate:delegate];

  // Setting delegate for icons performed in setPathViewPath:selection
/*  [icons makeObjectsPerform:@selector(setDelegate:)
		 withObject:delegate];*/
}

- (NSString *)path
{
  return path;
}

- (NSArray *)files
{
  return files;
}

// Called by dispatcher (FileViewer-displayPath:...) according to 
// the viewer (Browser) columns position
- (void)setNumberOfEmptyColumns:(NSInteger)num
{
  NSInteger iconsNum = [icons count];
  NSInteger width = [self slotsWide];
  NSInteger emptiesNum = width - iconsNum;

  // NSLog(@"[Pathview setNumberOfEmptyColumns] icons count: %i slots wide: %i # of empty: %i", 
  //       iconsNum, width, num);
  if (emptiesNum != num)
    {
      [self setSlotsWide:iconsNum + num];
    }
}

- (NSInteger)numberOfEmptyColumns
{
  return [self slotsWide] - [icons count];
}

- (void)iconClicked:sender
{
  NSArray  *iconPaths;
  NSString *newPath = @"";

  [super iconClicked:sender];

  // if (![delegate respondsToSelector:@selector(pathView:didChangePathTo:)])
  //   {
  //     return;
  //   }

  // do not select the last icon
  if ([icons lastObject] == sender) {
    return;
  }

  iconPaths = [self pathsForIcon:sender];
  if ([iconPaths count] > 1) {
    //      NSLog(@"[PathView:iconClicked:] icon with multiple paths clicked!");
    return;
  }
  newPath = [iconPaths objectAtIndex:0];

//  NSLog(@"[PathView] iconClicked with path: %@", newPath);

  // [delegate pathView:self didChangePathTo:newPath];
  [_owner displayPath:newPath selection:nil sender:self];
}

- (void)iconDoubleClicked:sender
{
  // only allow the last icon to be double-clicked
  if ([icons lastObject] == sender)
    {
      [_owner open:sender];
    }
}

- (NSArray *)pathsForIcon:(NXIcon *)icon
{
  NSUInteger idx = [icons indexOfObjectIdenticalTo:icon];

  if (idx == NSNotFound)
    return nil;

  if ([files count] > 0 && icon == [icons lastObject])
    {
      NSMutableArray *array = [NSMutableArray array];
      NSEnumerator   *e = [files objectEnumerator];
      NSString       *filename;

      while ((filename = [e nextObject]) != nil)
	{
	  [array addObject:[path stringByAppendingPathComponent:filename]];
	}

      return [[array copy] autorelease];
    }
  else
    {
      NSString     *newPath = @"";
      NSEnumerator *pathEnum = [[path pathComponents] objectEnumerator];
      NSEnumerator *iconEnum = [icons objectEnumerator];

      do {
        newPath = [newPath stringByAppendingPathComponent:[pathEnum nextObject]];
      }
      while ([iconEnum nextObject] != icon);

      return [NSArray arrayWithObject:newPath];
    }
}

- (void)setIconDragTypes:(NSArray *)types
{
  ASSIGN(iconDragTypes, types);

  [icons makeObjectsPerform:@selector(unregisterDraggedTypes)];
  [icons makeObjectsPerform:@selector(registerForDraggedTypes:)
		 withObject:iconDragTypes];

  // this is no dragging destination
  [multipleSelection unregisterDraggedTypes];
}

- (NSArray *)iconDragTypes
{
  return iconDragTypes;
}

- (void)mouseDown:(NSEvent *)ev
{
  // Do nothing. It prevents icons deselection.
}

- (BOOL)acceptsFirstResponder
{
  // It prevents first responder stealing.
  return NO;
}

//=============================================================================
// PathView (from FileViewer)
//=============================================================================

// - (void)configurePathView
// {
//   PathViewScroller *scroller;
//   NSScrollView     *sv;

//   sv = [pathView enclosingScrollView];
//   scroller = [[PathViewScroller new] autorelease];
//   [scroller setDelegate:self];
//   [sv setHorizontalScroller:scroller];
//   [sv setHasHorizontalScroller:YES];
//   [sv setBackgroundColor:[NSColor windowBackgroundColor]];

//   [pathView setTarget:self];
//   [pathView setDelegate:self];
//   [pathView setDragAction:@selector(pathViewIconDragged:event:)];
//   [pathView setDoubleAction:@selector(open:)];
//   [pathView setIconDragTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
// }

- (void)setPath:(NSString *)relativePath
      selection:(NSArray *)filenames
{
  PathIcon    *pathIcon;
  NXIconLabel *pathIconLabel;

  [self displayDirectory:relativePath andFiles:filenames];
  [self scrollPoint:NSMakePoint([self frame].size.width, 0)];

//  NSLog(@"PathView icons=%i path components=%i", 
//	[pathViewIcons count], [[relativePath pathComponents] count]);

  // Last icon
  pathIcon = [[self icons] lastObject];
  // Using [viewer keyView] leads to segfault if 'keyView' changed (reloaded)
  // on the fly
  [pathIcon setNextKeyView:[[_owner viewer] view]];

  // Last icon label
  pathIconLabel = [pathIcon label];
  [pathIconLabel setNextKeyView:[[_owner viewer] view]];

  [icons makeObjectsPerform:@selector(setDelegate:)
                 withObject:self];
}

// --- PathView delegate

- (void)pathViewIconDragged:sender event:(NSEvent *)ev
{
  NSArray      *paths;
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSRect       iconFrame = [sender frame];
  NSPoint      iconLocation = iconFrame.origin;

  draggedSource = self;
  draggedIcon = [sender retain];

  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  if ([icons lastObject] != sender) {
    [sender setSelected:NO];
  }

  paths = [draggedIcon paths];
  draggingSourceMask = [_owner draggingSourceOperationMaskForPaths:paths];

  [pb declareTypes:@[NSFilenamesPboardType] owner:nil];
  [pb setPropertyList:paths forType:NSFilenamesPboardType];

  [self dragImage:[sender iconImage]
               at:iconLocation //[ev locationInWindow]
           offset:NSZeroSize
            event:ev
       pasteboard:pb
           source:draggedSource
        slideBack:YES];
}

- (NSImage *)imageForIconAtPath:(NSString *)aPath
{
  NSString *fullPath = [[_owner rootPath] stringByAppendingPathComponent:aPath];
  //  NSLog(@"[FileViewer] imageForIconAtPath: %@", aPath);
  fullPath = [[_owner rootPath] stringByAppendingPathComponent:aPath];
  return [[NSApp delegate] iconForFile:fullPath];
}

- (void)syncEmptyColumns
{
  NSUInteger numEmptyCols = 0;
  id<Viewer> viewer = [_owner viewer];
  NSArray    *selection = [_owner selection];

  // Set empty columns to PathView
  numEmptyCols = [viewer numberOfEmptyColumns];

  NSDebugLLog(@"FilViewer", @"pathViewSyncEmptyColumns: selection: %@",
              selection);

  // Browser has empty columns and file(s) selected
  if (selection && [selection count] >= 1 && numEmptyCols > 0) {
    numEmptyCols--;
  }
  [self setNumberOfEmptyColumns:numEmptyCols];
}

//=============================================================================
// Scroller delegate
//=============================================================================

// Called when user drag scroller's knob
- (void)constrainScroller:(NSScroller *)aScroller
{
  NSUInteger num = slotsWide - [[_owner viewer] columnCount];
  CGFloat    v;
  NSRect     visibleRect, superRect;

  NSLog(@"[FileViewer -contrainScroller] PathView # of icons: %lu",
        [icons count]);

  if (num == 0) {
    v = 0.0;
    [aScroller setFloatValue:0.0 knobProportion:1.0];
  }
  else {
    v = rintf(num * [aScroller floatValue]) / num;
    [aScroller setFloatValue:v];
  }

  superRect = [[self superview] frame];
  visibleRect = NSMakeRect(([self frame].size.width - superRect.size.width) * v,
                           0, superRect.size.width, 0);
  [self scrollRectToVisible:visibleRect];
}

// Called whenver user click on PathView's scrollbar
- (void)trackScroller:(NSScroller *)aScroller
{
  id<Viewer> viewer = [_owner viewer];
  CGFloat    scrollerValue = [aScroller floatValue];
  CGFloat    rangeStart;

  // NSLog(@"0. [FileViewer] document visible rect: %@",
  //       NSStringFromRect([scrollView documentVisibleRect]));
  // NSLog(@"0. [FileViewer] document rect: %@",
  //       NSStringFromRect([pathView frame]));
  // NSLog(@"0. [FileViewer] scroll view rect: %@",
  //       NSStringFromRect([scrollView frame]));

  rangeStart = rintf((slotsWide - [viewer columnCount]) * scrollerValue);

  // NSLog(@"1. [FileViewer] trackScroller: value %f proportion: %f," 
  //       @"scrolled to range: %0.f - %lu", 
  //       sValue, [aScroller knobProportion], 
  //       rangeStart, viewerColumnCount);

  // Update viewer display
  [viewer scrollToRange:NSMakeRange(rangeStart, [viewer columnCount])];

  // Synchronize positions of icons in PathView and columns 
  // in BrowserViewer
  if (files != nil && [files count] > 0) { // file selected
    if (slotsWide - (slotsWide * scrollerValue) <= 1.0) {
      // scrolled maximum to the right 
      // scroller value close to 1.0 (e.g. 0.98)
      [viewer setNumberOfEmptyColumns:1];
    }
    else {
      [self syncEmptyColumns];
    }
  }
  else {
    [self syncEmptyColumns];
  }

  // Set keyboard focus to last visible column
  [viewer becomeFirstResponder];

  /*  NSLog(@"2. [FileViewer] trackScroller: value %f proportion: %f," 
        @"scrolled to range: %0.f - %i", 
	[aScroller floatValue], [aScroller knobProportion], 
        rangeStart, viewerColumnCount);

  NSLog(@"3. [FileViewer] PathView slotsWide = %i, viewerColumnCount = %i", 
	[pathView slotsWide], viewerColumnCount);*/
}


@end
