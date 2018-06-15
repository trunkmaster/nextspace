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
  TEST_RELEASE(_path);
  TEST_RELEASE(_files);
  TEST_RELEASE(_multiIcon);
  TEST_RELEASE(_iconDragTypes);

  [super dealloc];
}

// - initWithFrame:(NSRect)r 
- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer
{
  PathViewScroller *scroller;
  NSScrollView     *sv;

  self = [super initWithFrame:r];

  _owner = fileViewer;

  // Options
  allowsMultipleSelection = NO;
  allowsArrowsSelection = NO;
  allowsAlphanumericSelection = NO;
  autoAdjustsToFitIcons = YES; 
  adjustsToFillEnclosingScrollView = NO;
  fillWithHoleWhenRemovingIcon = NO;
  isSlotsTallFixed = YES;
  slotsTall = 1;

  sv = [self enclosingScrollView];
  scroller = [[PathViewScroller new] autorelease];
  [scroller setDelegate:self];
  [sv setHorizontalScroller:scroller];
  [sv setHasHorizontalScroller:YES];
  [sv setBackgroundColor:[NSColor windowBackgroundColor]];
  
  [self setDelegate:self];
  [self setTarget:self];
  [self setAction:@selector(iconClicked:)];
  [self setDoubleAction:@selector(iconDoubleClicked:)];
  [self setDragAction:@selector(pathViewIconDragged:event:)];
  [self registerForDraggedTypes:@[NSFilenamesPboardType]];

  ASSIGN(_iconDragTypes, @[NSFilenamesPboardType]);
  [icons makeObjectsPerform:@selector(unregisterDraggedTypes)];
  [icons makeObjectsPerform:@selector(registerForDraggedTypes:)
		 withObject:_iconDragTypes];
  
  _arrowImage = [[NSImage alloc]
    initByReferencingFile:[[NSBundle bundleForClass:[self class]]
	  pathForResource:@"RightArrow" ofType: @"tiff"]];

  _multiImage = [[NSImage alloc]
    initByReferencingFile:[[NSBundle bundleForClass:[self class]]
	  pathForResource:@"MultipleSelection" ofType: @"tiff"]];

  _multiIcon = [[PathIcon alloc] init];
  [_multiIcon setIconImage:_multiImage];
  [_multiIcon setLabelString:@"Multiple items"];
  [_multiIcon setEditable:NO];
  // this is not a dragging destination
  [_multiIcon unregisterDraggedTypes];

  return self;
}

- (void)drawRect:(NSRect)r
{
//  NSLog(@"drawRect of PathView at origin: %.0f, %.0f with size: %.0f x %.0f", 
//	r.origin.x, r.origin.y, r.size.width, r.size.height);

  for (unsigned int i=1, n = [icons count]; i<n; i++) {
    NSPoint p;
      
    p = NSMakePoint((i * slotSize.width) - ([_arrowImage size].width + 5),
                    slotSize.height/2);
      
    p.x = floorf(p.x);
    p.y = floorf(p.y);
    [_arrowImage compositeToPoint:p operation:NSCompositeSourceOver];
  }

  [super drawRect:r];
}

- (void)displayDirectory:(NSString *)aPath andFiles:(NSArray *)aFiles
{
  NSUInteger length;
  NSUInteger componentsCount = [[aPath pathComponents] count];
  NSUInteger i, n;
  NSUInteger lii; // last icon index in array of icons
  PathIcon   *icon;
  NSString   *path = @"";

  if (delegate == nil) {
    NSLog(@"PathView: attempt to set path without a delegate "
          @"assigned to define the icons to use.");
    return;
  }

  length = [aPath length];

  // Remove a trailing "/" character from 'aPath'
  if (length > 1 && [aPath characterAtIndex:length-1] == '/') {
    aPath = [aPath substringToIndex:length-1];
  }

  // NSLog(@"[PathView] displayDirectory:%@(%i) andFiles:%@", 
  //       aPath, [[aPath pathComponents] count], aFiles);

  // NSLog(@"1. [PathView] icons count: %i components: %i", 
  //       [icons count], componentsCount);

  if ([icons count] > [self slotsWide]) {
    NSLog(@"WARNING!!! # of icons > slotsWide! PathView must have 1 row!");
  }

  // Always clear last time selection
  // [[icons lastObject] deselect:nil];
  // [[icons lastObject] setEditable:NO];

  // Remove trailing icons
  lii = componentsCount;
  if ([aFiles count] > 0) {
    lii++;
  }

  for (n = [icons count], i = lii; i < n; i++) {
    PathIcon *itr = nil;

    // NSLog(@"[PathView] remove icon [%@] in slot: %i(%i)", 
    //       [icons lastObject], i, [icons count]);
    //      [self removeIconInSlot:NXMakeIconSlot(i,0)];
    itr = [icons lastObject];
    [self removeIcon:itr];
  }
  if ([icons lastObject] == _multiIcon) {
    // to avoid setting attributes by file selection
    [self removeIcon:_multiIcon];
  }

  // NSLog(@"2. [PathView] icons count: %i components: %i", 
  //       [icons count], componentsCount);

  // Set icons for path of "folders"
  if (![path isEqualToString:aPath]) {
    NSArray *pathComponents = [aPath pathComponents];

    ASSIGN(_path, aPath);

    for (i = 0; i < componentsCount; i++) {
      NSString *component = [pathComponents objectAtIndex:i];

      path = [path stringByAppendingPathComponent:component];

      if (i < [icons count]) {
        icon = [icons objectAtIndex:i];
      }
      else {
        NSLog(@"[PathView] creating new icon with path: %@ (%lu,0)", path, i);
        icon = [[PathIcon new] autorelease];
        [icon setLabelString:@"-"];
        [icon registerForDraggedTypes:_iconDragTypes];
        [self setSlotsWide:i+1];
        [self putIcon:icon intoSlot:NXMakeIconSlot(i, 0)];
      }
      [icon deselect:nil];
      [icon setEditable:NO];
      [icon setIconImage:[self imageForPath:path]];
      [icon setPaths:[_owner absolutePathsForPaths:@[path]]];
    }
  }

  // files == nil also make sense later
  ASSIGN(_files, aFiles);

  // Set icon for file or files
  if (_files != nil && [_files count] > 0) {
    i = componentsCount;

    if ([_files count] == 1) {
      path = [path stringByAppendingPathComponent:[_files objectAtIndex:0]];
      if ([icons count] > i) {
        icon = [icons objectAtIndex:i];
      }
      else {
        // NSLog(@"[PathView] creating new icon with path: %@", path);
        icon = [[PathIcon new] autorelease];
        [icon setLabelString:@"-"];
        [icon registerForDraggedTypes:_iconDragTypes];
        [self setSlotsWide:i+1];
        [self putIcon:icon intoSlot:NXMakeIconSlot(i, 0)];
      }
      [icon deselect:nil];
      [icon setEditable:NO];
      [icon setIconImage:[self imageForPath:path]];
      [icon setPaths:[_owner absolutePathsForPaths:@[path]]];
    }
    else {
      NSMutableArray *relPaths = [[NSMutableArray new] autorelease];

      for(NSString *file in _files) {
        path = [path stringByAppendingPathComponent:file];
        [relPaths addObject:path];
      }

      if ([icons indexOfObjectIdenticalTo:_multiIcon] == NSNotFound) {
        [self setSlotsWide:i + 1];
        [self putIcon:_multiIcon intoSlot:NXMakeIconSlot(i,0)];
      }
      [_multiIcon setPaths:[_owner absolutePathsForPaths:relPaths]];
    }
  }
 
  // First icon
  [[icons objectAtIndex:0] setEditable:NO];

  // Last icon
  icon = [icons lastObject];
  if ([icons count] > 1 && icon != _multiIcon) {
    [icon setEditable:YES];
  }
  
  // Update last icon in case of contents or attributes changes
  if ([aFiles count] == 1) {
    path = [aPath stringByAppendingPathComponent:[aFiles objectAtIndex:0]];
    [icon setIconImage:[self imageForPath:path]];
  }

  [self selectIcons:[NSSet setWithObject:icon]];

  [[icon label] setIconLabelDelegate:delegate];
  // Setting delegate for icons performed in setPath:selection
}

- (void)setPath:(NSString *)relativePath selection:(NSArray *)filenames
{
  PathIcon    *pathIcon;
  NXIconLabel *pathIconLabel;
  id<Viewer>  theViewer = [_owner viewer];

  [self displayDirectory:relativePath andFiles:filenames];
  [self scrollPoint:NSMakePoint([self frame].size.width, 0)];

//  NSLog(@"PathView icons=%i path components=%i", 
//	[pathViewIcons count], [[relativePath pathComponents] count]);

  // Last icon
  pathIcon = [icons lastObject];
  // Using [viewer keyView] leads to segfault if 'keyView' changed (reloaded)
  // on the fly
  [pathIcon setNextKeyView:[theViewer view]];

  // Last icon label
  pathIconLabel = [pathIcon label];
  [pathIconLabel setNextKeyView:[theViewer view]];

  [icons makeObjectsPerform:@selector(setDelegate:)
                 withObject:self];
}

- (NSImage *)imageForPath:(NSString *)aPath
{
  NSString *fullPath = [[_owner rootPath] stringByAppendingPathComponent:aPath];
  //  NSLog(@"[FileViewer] imageForIconAtPath: %@", aPath);
  fullPath = [[_owner rootPath] stringByAppendingPathComponent:aPath];
  return [[NSApp delegate] iconForFile:fullPath];
}

- (NSString *)path
{
  return _path;
}

- (NSArray *)files
{
  return _files;
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

- (void)iconClicked:sender
{
  NSArray *pathList;

  NSLog(@"[PathView] icon clicked, sender: %@ %@",
        [sender className], [self pathsForIcon:sender]);
  if ([sender isKindOfClass:[PathView class]]) {
    [super iconClicked:sender];
    return;
  }
  // do not unselect the last icon
  if ([icons lastObject] == sender) {
    return;
  }
  pathList = [self pathsForIcon:sender];
  if ([pathList count] > 1) {
    return;
  }
  [_owner displayPath:[pathList lastObject] selection:nil sender:self];
}

- (void)iconDoubleClicked:sender
{
  // only allow the last icon to be double-clicked
  if ([icons lastObject] == sender) {
    [_owner open:sender];
  }
  else {
    // double-click can be received by not last icon if PathView content
    // was scrolled between first and second click.
    [self selectIcons:[NSSet setWithObject:[icons lastObject]]];
  }
}

- (NSArray *)pathsForIcon:(NXIcon *)icon
{
  NSUInteger idx = [icons indexOfObjectIdenticalTo:icon];

  if (idx == NSNotFound) {
    return nil;
  }

  if ([_files count] > 0 && icon == [icons lastObject]) {
    NSMutableArray *array = [NSMutableArray array];

    for (NSString *filename in _files) {
      [array addObject:[_path stringByAppendingPathComponent:filename]];
    }
    return [[array copy] autorelease];
  }
  else {
    NSString     *newPath = @"";
    NSEnumerator *pathEnum = [[_path pathComponents] objectEnumerator];
    NSEnumerator *iconEnum = [icons objectEnumerator];

    do {
      newPath = [newPath stringByAppendingPathComponent:[pathEnum nextObject]];
    }
    while ([iconEnum nextObject] != icon);

    return [NSArray arrayWithObject:newPath];
  }
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
// NXIconView delegate
//=============================================================================
- (void)pathViewIconDragged:sender event:(NSEvent *)ev
{
  NSArray      *paths;
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSRect       iconFrame = [sender frame];
  NSPoint      iconLocation = iconFrame.origin;

  _dragSource = self;
  _dragIcon = [sender retain];

  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  if ([icons lastObject] != sender) {
    [sender setSelected:NO];
  }

  paths = [_dragIcon paths];
  _dragMask = [_owner draggingSourceOperationMaskForPaths:paths];

  [pb declareTypes:@[NSFilenamesPboardType] owner:nil];
  [pb setPropertyList:paths forType:NSFilenamesPboardType];

  [self dragImage:[_dragIcon iconImage]
               at:iconLocation //[ev locationInWindow]
           offset:NSZeroSize
            event:ev
       pasteboard:pb
           source:_dragSource
        slideBack:YES];
}

//=============================================================================
// Drag and drop
//=============================================================================
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  if (isLocal != NO) {
    return NSDragOperationCopy;
  }

  return _dragMask;
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
  if (_files != nil && [_files count] > 0) { // file selected
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
