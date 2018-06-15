
#import <NXAppKit/NXIconView.h>

@class NSArray, NSString, NSImage;
@class PathIcon;
@class FileViewer;

@interface PathView : NXIconView
{
  FileViewer *_owner;

  NSString *_path;
  NSArray  *_files;
  NSArray  *_iconDragTypes;
  PathIcon *_multiIcon;
  NSImage  *_multiImage;
  NSImage  *_arrowImage;
  
  // Dragging
  NXIconView *_dragSource;
  PathIcon   *_dragIcon;
  unsigned   _dragMask;
}

- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer;

- (void)displayDirectory:(NSString *)aPath andFiles:(NSArray *)aFiles;
- (void)setPath:(NSString *)relativePath selection:(NSArray *)filenames;
- (NSString *)path;
- (NSArray *)files;

- (void)setNumberOfEmptyColumns:(NSInteger)num;
- (NSInteger)numberOfEmptyColumns;
- (void)syncEmptyColumns;

- (NSArray *)pathsForIcon:(NXIcon *)anIcon;

- (void)constrainScroller:(NSScroller *)aScroller;
- (void)trackScroller:(NSScroller *)aScroller;

@end
