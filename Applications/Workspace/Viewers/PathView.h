
#import <NXAppKit/NXIconView.h>

@class NSArray, NSString;
@class NSImage;

@class NXIcon, PathIcon;

@interface PathView : NXIconView
{
  NSString *path;
  NSArray  *files;
  NSArray  *iconDragTypes;
  PathIcon *multipleSelection;
  NSImage  *arrowImage;
  NSImage  *multiImage;
}

- (void)displayDirectory:(NSString *)aPath andFiles:(NSArray *)aFiles;

- (NSString *)path;
- (NSArray *)files;
- (void)setNumberOfEmptyColumns:(NSInteger)num;
- (NSInteger)numberOfEmptyColumns;

- (NSArray *)pathsForIcon:(NXIcon *)anIcon;

- (void)setIconDragTypes:(NSArray *)types;
- (NSArray *)iconDragTypes;

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

- (NSString *)pathView:(PathView *)aPathView
    labelForIconAtPath:(NSString *)aPath;

- (void)pathView:(PathView *)aPathView
 didChangePathTo:(NSString *)newPath;

- (NSArray *)absolutePathsForPaths:(NSArray *)relPaths;

@end
