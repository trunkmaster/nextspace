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
  [panel setDelegate:self];

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
  [filesView setAutoresizingMask:NSViewWidthSizable];

  // [panelIcon setImage:[NSImage imageNamed:@"recyclerFull"]];
  
  opQ = [[NSOperationQueue alloc] init];
  pathLoaderOp = nil;
}

- (void)dealloc
{
  if (pathLoaderOp) [pathLoaderOp release];
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
  [panelStatusField setStringValue:@""];
  [panelItemsCount setStringValue:@""];
  
  [filesView removeAllIcons];
  [panel makeKeyAndOrderFront:self];

  if (pathLoaderOp != nil) {
    [pathLoaderOp cancel];
    [pathLoaderOp release];
  }

  pathLoaderOp = [[PathLoader alloc] initWithIconView:filesView
                                               status:panelStatusField
                                                 path:recyclerPath
                                            selection:nil];
  [pathLoaderOp addObserver:self forKeyPath:@"isFinished" options:0 context:&self->itemsCount];
  [opQ addOperation:pathLoaderOp];
  
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
  // NSMutableArray	*icons;
  NSMutableSet		*selected = [[NSMutableSet new] autorelease];
  NSFileManager		*fm = [NSFileManager defaultManager];
  NXFileManager		*xfm = [NXFileManager sharedManager];
  NSArray		*items;
  NSString              *path;
  NXIcon                *anIcon;
  NSUInteger            slotsWide, x;

  // icons = [NSMutableArray array];

  NSLog(@"GCD: Begin path loading...");
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
  
  NSLog(@"GCD: End path loading...");
}

// -- NSOperation
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  NSLog(@"Observer of '%@' was called.", keyPath);
  [panelItemsCount setStringValue:[NSString stringWithFormat:@"%lu items",
                                            pathLoaderOp.itemsCount]];
}

@end

@implementation PathLoader

- (id)initWithIconView:(NXIconView *)view
                status:(NSTextField *)status
                  path:(NSString *)dirPath
             selection:(NSArray *)filenames
{
  if (self != nil) {
    iconView = view;
    statusField = status;
    directoryPath = dirPath;
    selectedFiles = filenames;
  }

  return self;
}

- (void)main
{
  NSString 		*filename;
  // NSMutableArray	*icons = [NSMutableArray array];
  NSMutableSet		*selected = [[NSMutableSet new] autorelease];
  // NSFileManager		*fm = [NSFileManager defaultManager];
  NXFileManager		*xfm = [NXFileManager sharedManager];
  NSArray		*items;
  NSString		*path;
  NXIcon		*anIcon;
  NSUInteger		slotsWide, x;

  [statusField performSelectorOnMainThread:@selector(setStringValue:)
                                withObject:@"Loading items list..."
                             waitUntilDone:YES];
  NSLog(@"Operation: Begin path loading...");
  
  items = [xfm directoryContentsAtPath:directoryPath
                               forPath:nil
                              sortedBy:[xfm sortFilesBy]
                            showHidden:YES];

  _itemsCount = [items count];
  
  x = 0;
  slotsWide = [iconView slotsWide];
  for (filename in items)
    {
      path = [directoryPath stringByAppendingPathComponent:filename];

      anIcon = [[NXIcon new] autorelease];
      [anIcon setLabelString:filename];
      [anIcon setIconImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
      [[anIcon label] setIconLabelDelegate:self];
      [anIcon setDelegate:self];
      [anIcon
        registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

      // if (![fm isReadableFileAtPath:path])
      //   [anIcon setDimmed:YES];
      
      if ([selectedFiles containsObject:filename])
        [selected addObject:anIcon];

      // [icons addObject:anIcon];      
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

  NSLog(@"Operation: End path loading...");
  [statusField performSelectorOnMainThread:@selector(setStringValue:)
                                withObject:@""
                             waitUntilDone:YES];
}

- (BOOL)isReady
{
  return YES;
}

@end
