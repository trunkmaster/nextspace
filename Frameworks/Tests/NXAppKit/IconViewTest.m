/* All Rights reserved */

#import <NXAppKit/NXIcon.h>
#import <NXAppKit/NXIconLabel.h>
#import <NXFoundation/NXFileManager.h>

#import "IconViewTest.h"

@implementation IconViewTest

- (id)init
{
  if (panel == nil)
    {
      if (![NSBundle loadNibNamed:@"IconView" owner:self])
        {
          NSLog(@"Error loading IconView.gorm!");
        }
    }
  
  recyclerPath = [NSHomeDirectory()
                     stringByAppendingPathComponent:@".Recycler"];
  [recyclerPath retain];
  
  return self;
}

- (void)awakeFromNib
{
  [panel setFrameAutosaveName:@"IconViewTest"];
  
  [panelView setHasHorizontalScroller:NO];
  [panelView setHasVerticalScroller:YES];
  
  filesView = [[NXIconView alloc]
                initWithFrame:[[panelView contentView] frame]];

  [filesView setDelegate:self];
  [filesView setTarget:self];
  [filesView setDoubleAction:@selector(open:)];
  [filesView setDragAction:@selector(iconDragged:event:)];
  [filesView setSendsDoubleActionOnReturn:YES];
  [filesView setAutoAdjustsToFitIcons:NO];
  
  [filesView
    registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

  [panelView setDocumentView:filesView];
  [filesView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

  // [panelIcon setImage:[NSImage imageNamed:@"recyclerFull"]];
  
  opQ = [[NSOperationQueue alloc] init];
  pathLoaderOp = nil;
}

- (void)dealloc
{
  [recyclerPath release];
  
  [super dealloc];
}

- (NSUInteger)itemsCount
{
  return itemsCount;
}

// #include <dispatch/dispatch.h>
// static dispatch_queue_t display_path_q;
- (void)show
{
  [panel makeKeyAndOrderFront:self];
  // [self displayPath:recyclerPath selection:nil];

  if (pathLoaderOp != nil)
    [pathLoaderOp cancel];

  pathLoaderOp = [[PathLoader alloc] initWithIconView:filesView
                                                 path:recyclerPath
                                            selection:nil];
  // [opQ addOperation:pathLoaderOp];
  [pathLoaderOp start];
  
  // if (!display_path_q)
  //   display_path_q = dispatch_queue_create("ns.test.nxappkit", NULL);
  
  // dispatch_async(display_path_q,
  //                ^{ [self displayPath:recyclerPath selection:nil]; });
}

// -- NXIconView delegate

- (void)displayPath:(NSString *)dirPath
          selection:(NSArray *)filenames
{
  NSString 		*filename;
  NSMutableArray	*icons;
  NSMutableSet		*selected = [[NSMutableSet new] autorelease];
  NSFileManager		*fm = [NSFileManager defaultManager];
  NXFileManager		*xfm = [NXFileManager sharedManager];
  NSArray		*items;
  NSString              *path;
  NXIcon                *anIcon;
  NSUInteger            slotsWide, x;

  icons = [NSMutableArray array];

  items = [xfm directoryContentsAtPath:dirPath
                               forPath:nil
                              sortedBy:[xfm sortFilesBy]
                            showHidden:YES];

  [panelItemsCount setStringValue:[NSString stringWithFormat:@"%lu items",
                                   [items count]]];

  slotsWide = [filesView slotsWide];
  x = 0;
  for (filename in items)
    {
      path = [dirPath stringByAppendingPathComponent:filename];

      anIcon = [[NXIcon new] autorelease];
      [anIcon setLabelString:filename];
      [[anIcon label] setIconLabelDelegate:self];
      [anIcon setIconImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
      [anIcon setDelegate:self];
      [anIcon
        registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

      // [icons addObject:anIcon];
      if (![fm isReadableFileAtPath:path])
        [anIcon setDimmed:YES];
      
      if ([filenames containsObject:filename])
        [selected addObject:anIcon];
      
      [filesView performSelectorOnMainThread:@selector(addIcon:)
                                  withObject:anIcon
                               waitUntilDone:YES];
      x++;
      if (x >= slotsWide)
        {
          [filesView performSelectorOnMainThread:@selector(adjustToFitIcons)
                                      withObject:nil
                                   waitUntilDone:YES];
          x = 0;
        }
    }

  // NSLog(@"Recycler: fill with %lu icons", [icons count]);
  // [filesView fillWithIcons:icons];
  
  if ([selected count] != 0)
    [filesView selectIcons:selected];
  else
    [filesView scrollPoint:NSZeroPoint];
}

@end

@implementation PathLoader

- (id)initWithIconView:(NXIconView *)view
                  path:(NSString *)dirPath
             selection:(NSArray *)filenames
{
  if (self != nil) {
    iconView = view;
    directoryPath = dirPath;
    selectedFiles = filenames;
  }

  return self;
}

- (void)main
{
  NSString 		*filename;
  NSMutableArray	*icons = [NSMutableArray array];
  NSMutableSet		*selected = [[NSMutableSet new] autorelease];
  NSFileManager		*fm = [NSFileManager defaultManager];
  NXFileManager		*xfm = [NXFileManager sharedManager];
  NSArray		*items;
  NSString		*path;
  NXIcon		*anIcon;
  NSUInteger		slotsWide, x;

// #pragma unused(icons)

  NSLog(@"Begin path loading...");
  
  items = [xfm directoryContentsAtPath:directoryPath
                               forPath:nil
                              sortedBy:[xfm sortFilesBy]
                            showHidden:YES];

  _itemsCount = [items count];

  slotsWide = [iconView slotsWide];
  x = 0;
  for (filename in items)
    {
      path = [directoryPath stringByAppendingPathComponent:filename];

      anIcon = [[NXIcon new] autorelease];
      [anIcon setLabelString:filename];
      [[anIcon label] setIconLabelDelegate:self];
      [anIcon setIconImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
      [anIcon setDelegate:self];
      [anIcon
        registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

      if (![fm isReadableFileAtPath:path])
        [anIcon setDimmed:YES];
      
      if ([selectedFiles containsObject:filename])
        [selected addObject:anIcon];
      
      [iconView performSelectorOnMainThread:@selector(addIcon:)
                                 withObject:anIcon
                              waitUntilDone:YES];
      x++;
      if (x >= slotsWide)
        {
          [iconView performSelectorOnMainThread:@selector(adjustToFitIcons)
                                     withObject:nil
                                  waitUntilDone:YES];
          x = 0;
        }
    }

  // NSLog(@"Recycler: fill with %lu icons", [icons count]);
  // [filesView fillWithIcons:icons];
  
  if ([selected count] != 0)
    [iconView selectIcons:selected];
  else
    [iconView scrollPoint:NSZeroPoint];
}

@end
