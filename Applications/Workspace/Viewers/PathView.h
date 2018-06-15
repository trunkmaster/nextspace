
#import <NXAppKit/NXIconView.h>

@class NSArray, NSString, NSImage;
@class PathIcon;
@class FileViewer;

@interface PathView : NXIconView
{
  FileViewer *_owner;

  NSString *path;
  NSArray  *files;
  NSArray  *iconDragTypes;
  PathIcon *multipleSelection;
  NSImage  *arrowImage;
  NSImage  *multiImage;
  
  // Dragging
  NXIconView *draggedSource;
  PathIcon   *draggedIcon;
  unsigned   draggingSourceMask;
}

- initWithFrame:(NSRect)r owner:(FileViewer *)fileViewer;

- (void)displayDirectory:(NSString *)aPath andFiles:(NSArray *)aFiles;

- (NSString *)path;
- (NSArray *)files;
- (void)setNumberOfEmptyColumns:(NSInteger)num;
- (NSInteger)numberOfEmptyColumns;
- (NSArray *)pathsForIcon:(NXIcon *)anIcon;
- (void)setIconDragTypes:(NSArray *)types;
- (NSArray *)iconDragTypes;

- (void)setPath:(NSString *)relativePath
      selection:(NSArray *)filenames;
- (void)syncEmptyColumns;

- (void)constrainScroller:(NSScroller *)aScroller;
- (void)trackScroller:(NSScroller *)aScroller;

@end

// All paths are relative to path file viewer opened with.
// Example:
//  - file viewer opened as folder viewer rooted at path '/Users/me'
//  - path view calling delegate method
//    pathView:imageForIconAtPath:@"/Library/Preferences" means that
//    file viewer must return icon for folder '/Users/me/Library/Prefernces'
@protocol XSPathViewDelegate

- (NSImage *)pathView:(PathView *)aPathView
   imageForIconAtPath:(NSString *)aPath;

- (void)pathView:(PathView *)aPathView
 didChangePathTo:(NSString *)newPath;

- (NSArray *)absolutePathsForPaths:(NSArray *)relPaths;

@end
