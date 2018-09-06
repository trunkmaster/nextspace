
#import <NXAppKit/NXIconView.h>

@class NSArray, NSString, NSImage;
@class PathIcon;
@class FileViewer;

#define PATH_VIEW_HEIGHT 76.0

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

- (void)setPath:(NSString *)relativePath selection:(NSArray *)filenames;
- (NSString *)path;
- (NSArray *)files;

- (NSUInteger)visibleColumnCount;
- (void)setNumberOfEmptyColumns:(NSInteger)num;
- (NSInteger)numberOfEmptyColumns;
- (void)syncEmptyColumns;

- (NSArray *)pathsForIcon:(NXIcon *)anIcon;

- (void)constrainScroller:(NSScroller *)aScroller;
- (void)trackScroller:(NSScroller *)aScroller;

@end
