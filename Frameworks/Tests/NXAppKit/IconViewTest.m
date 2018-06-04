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
  
  [filesView
    registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

  [panelView setDocumentView:filesView];
  // [filesView setFrame:NSMakeRect(0, 0,
  //                                [[panelView contentView] frame].size.width,
  //                                0)];
  [filesView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

  // [panelIcon setImage:[NSImage imageNamed:@"recyclerFull"]];
}

- (void)show
{
  [panel makeKeyAndOrderFront:self];
  [self displayPath:recyclerPath selection:nil];
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

  icons = [NSMutableArray array];

  items = [xfm directoryContentsAtPath:dirPath
                               forPath:nil
                              sortedBy:[xfm sortFilesBy]
                            showHidden:YES];

  [panelItemsCount setStringValue:[NSString stringWithFormat:@"%lu items",
                                   [items count]]];
  
  for (filename in items)
    {
      NSString *path = [dirPath stringByAppendingPathComponent:filename];
      NXIcon   *anIcon;

      anIcon = [[NXIcon new] autorelease];
      [anIcon setLabelString:filename];
      [anIcon setIconImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
      [anIcon setDelegate:self];
      [anIcon
        registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
      [[anIcon label] setIconLabelDelegate:self];

      [icons addObject:anIcon];
      if (![fm isReadableFileAtPath:path])
        [anIcon setDimmed:YES];
      
      if ([filenames containsObject:filename])
        [selected addObject:anIcon];
    }

  NSLog(@"Recycler: fill with %lu icons", [icons count]);
  [filesView fillWithIcons:icons];
  
  if ([selected count] != 0)
    [filesView selectIcons:selected];
  else
    [filesView scrollPoint:NSZeroPoint];
}

@end
