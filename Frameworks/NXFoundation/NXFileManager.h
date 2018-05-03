/** @class NXFileManager
    @class NSFileManager extensions
    
    File meta information (attributes, file type description...).

    @author Sergii Stoian
 */

#import <Foundation/NSString.h>
 
@class NSString, NSObject;

// Utility functions
NSString *NXIntersectionPath(NSString *aPath, NSString *bPath);

typedef enum {
  NXSortByName = 0, // by name only, folders mixed with files
  NXSortByKind = 1, // folders first + NXSortByName
  NXSortByType = 2, // file extention + NXSortByKind
  NXSortByDate = 3, // + NXSortByName
  NXSortBySize = 4, // + NXSortByName
  NXSortByOwner = 5 // + NXSortByName
} NXSortType;

// Preferences used by File Viewer, NSOpenPanel and NSSavePanel
extern NSString *SortFilesBy;
extern NSString *ShowHiddenFiles;

@interface NXFileManager : NSObject
{
}

+ (NXFileManager *)sharedManager;

- (BOOL)isShowHiddenFiles;
- (void)setShowHiddenFiles:(BOOL)yn;
- (NXSortType)sortFilesBy;
- (void)setSortFilesBy:(NXSortType)type;

- (NSArray *)sortedDirectoryContentsAtPath:(NSString *)path;

- (NSArray *)directoryContentsAtPath:(NSString *)path
                             forPath:(NSString *)targetPath
                          showHidden:(BOOL)showHidden;
- (NSArray *)directoryContentsAtPath:(NSString *)path
                             forPath:(NSString *)targetPath
                            sortedBy:(NXSortType)sortType
                          showHidden:(BOOL)showHidden;

// libmagic
- (NSString *)mimeTypeForFile:(NSString *)fullPath;
- (NSString *)mimeEncodingForFile:(NSString *)fullPath;
- (NSString *)descriptionForFile:(NSString *)fullPath;

@end
