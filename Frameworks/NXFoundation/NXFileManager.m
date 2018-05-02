/** @class NXFileManager
    @class NSFileManager extensions
    
    File meta information (attributes, file type description...).

    @author Sergii Stoian
 */

#include <magic.h> // libmagic

#import <Foundation/NSDictionary.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSArray.h>

#import "NXDefaults.h"
#import "NXFileManager.h"

NSString *SortFileBy = @"NXSortFilesBy";
NSString *ShowHiddenFiles = @"NXShowHiddenFiles";

static NXFileManager *sharedManager;
static NSString      *dirPath;

NSString *NXIntersectionPath(NSString *aPath, NSString *bPath)
{
  NSString   *subPath = [[NSString new] autorelease];
  NSArray    *aPathComps = [aPath pathComponents];
  NSArray    *bPathComps = [bPath pathComponents];
  NSUInteger i, aCount, bCount, count;
  NSString   *tmpPathComp;

  aCount = [aPathComps count];
  bCount = [bPathComps count];
  count =  (aCount < bCount)  ? aCount : bCount;

  // find intersection between changed and selected paths
  for (i=0; i<count; i++)
    {
      tmpPathComp = [aPathComps objectAtIndex:i];
      if ([tmpPathComp isEqualToString:[bPathComps objectAtIndex:i]])
	{
	  subPath = [subPath stringByAppendingPathComponent:tmpPathComp];
	}
      else
	{
	  break;
	}
    }

  return subPath;
}

@implementation NSString (Sorting)

- (NSComparisonResult)byTypeCompare:(NSString *)string
{
  NSString *ext1 = [self pathExtension];
  NSString *ext2 = [string pathExtension];
  
  return [ext1 localizedCompare:ext2];
}

- (NSComparisonResult)byDateCompare:(NSString *)string
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSString      *path1 = [dirPath stringByAppendingPathComponent:self];
  NSDate        *date1 = [[fm fileAttributesAtPath:path1 traverseLink:NO]
                           fileCreationDate];
  
  NSString      *path2 = [dirPath stringByAppendingPathComponent:string];
  NSDate        *date2 = [[fm fileAttributesAtPath:path2 traverseLink:NO]
                           fileCreationDate];
  
  return [date1 compare:date2];
}

- (NSComparisonResult)bySizeCompare:(NSString *)string
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSString           *path1 = [dirPath stringByAppendingPathComponent:self];
  unsigned long long size1;
  NSString           *path2 = [dirPath stringByAppendingPathComponent:string];
  unsigned long long size2;

  size1 = [[fm fileAttributesAtPath:path1 traverseLink:NO] fileSize];
  size2 = [[fm fileAttributesAtPath:path2 traverseLink:NO] fileSize];

  if (size1 == size2)
    return NSOrderedSame;

  if (size1 > size2)
    return NSOrderedDescending;

  if (size1 < size2)
    return NSOrderedAscending;

  return NSOrderedSame;
}

- (NSComparisonResult)byOwnerCompare:(NSString *)string
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSString *path1 = [dirPath stringByAppendingPathComponent:self];
  NSString *owner1 = [[fm fileAttributesAtPath:path1 traverseLink:NO]
                       fileOwnerAccountName];
  NSString *path2 = [dirPath stringByAppendingPathComponent:string];
  NSString *owner2 = [[fm fileAttributesAtPath:path2 traverseLink:NO]
                       fileOwnerAccountName];
  
  return [owner1 localizedCompare:owner2];
}

@end

@implementation NXFileManager

// --- Private
// --- End of Private

+ (NXFileManager *)sharedManager
{
  if (sharedManager == nil)
    {
      sharedManager = [[NXFileManager alloc] init];
    }

  return sharedManager;
}

- (id)init
{
  self = [super init];

  return self;
}

- (void)dealloc
{
  [super dealloc];
}

// --- Preferences

- (BOOL)isShowHiddenFiles
{
  return NO;
}
- (void)setShowHiddenFiles:(BOOL)yn
{
}
- (NXSortType)sortFilesBy
{
  return NXSortByKind;
}
- (void)setSortFilesBy:(NXSortType)type
{
}


// --- Directory contents (obsolete)

- (void)sortArray:(NSMutableArray *)array
            start:(NSInteger)start // start index
            count:(NSInteger)count // elements count
{
  int i, last;

  if (count <= 1)
    return;

  // set pivot (center of an array) to first place (0)
  [array exchangeObjectAtIndex:0 withObjectAtIndex:count/2];
  i = start;
  last = 0;

  // Split
  for (i=1; i<count; i++)
    {
      if ([[array objectAtIndex:0] compare:[array objectAtIndex:0]]
          == NSOrderedAscending)
        {
          [array exchangeObjectAtIndex:++last withObjectAtIndex:i];
        }
    }

  // (?) restore pivot
  [array exchangeObjectAtIndex:0 withObjectAtIndex:last];

  // Recursive sort
  [self sortArray:array start:0 count:last];
  // of every splitted part
  [self sortArray:array start:last+1 count:count-last-1];
}

- (void)_getSortedDirContents:(NSMutableArray *)dirContents
	 	       atPath:(NSString *)absolutePath
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSEnumerator   *e = [dirContents objectEnumerator];
  NSMutableArray *dirs = [[NSMutableArray alloc] init];
  NSMutableArray *files = [[NSMutableArray alloc] init];
  NSString       *entry = nil;
  BOOL           isDir;

  while ((entry = [e nextObject]) != nil)
    {
      NSString *path = [absolutePath stringByAppendingPathComponent:entry];

      [fm fileExistsAtPath:path isDirectory:&isDir];
      if (isDir == YES)
	{
	  [dirs addObject:entry];
	}
      else
	{
	  [files addObject:entry];
	}
    }

  // Empty dirContents
  [dirContents removeAllObjects];

  // Add sorted directories
  [dirs sortUsingSelector:@selector(localizedCompare:)];
  [dirContents addObjectsFromArray:dirs];
  [dirs release];

  // Add sorted files
  [files sortUsingSelector:@selector(localizedCompare:)];
  [dirContents addObjectsFromArray:files];
  [files release];
}

- (NSArray *)sortedDirectoryContentsAtPath:(NSString *)path
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NXDefaults     *df = [NXDefaults userDefaults];
  NSUserDefaults *udf = [NSUserDefaults standardUserDefaults];
  NSMutableArray *dirContents;

  // return [fm directoryContentsAtPath:path];

  dirContents = [[fm directoryContentsAtPath:path] mutableCopy];

  NSLog(@"Dir contents sort START");
  // [self sortArray:dirContents start:0 count:[dirContents count]];
  [self _getSortedDirContents:dirContents atPath:path];
  NSLog(@"Dir contents sort END");
  
  return [dirContents autorelease];
  
  dirContents = [[fm directoryContentsAtPath:path] mutableCopy];

  if ([udf objectForKey:@"GSFileBrowserHideDotFiles"] == nil
      || [udf boolForKey:@"GSFileBrowserHideDotFiles"] == YES)
    {
      NSString *hiddenFilename;
      unsigned i, n;
      NSString *filename;

      hiddenFilename = [path stringByAppendingPathComponent:@".hidden"];
      if ([fm fileExistsAtPath:hiddenFilename])
	{
	  NSString     *h = [NSString stringWithContentsOfFile:hiddenFilename];
	  NSArray      *hidden = [h componentsSeparatedByString:@"\n"];
	  NSEnumerator *e = [hidden objectEnumerator];

	  while ((filename = [e nextObject]) != nil)
	    {
	      [dirContents removeObject:filename];
	    }
	}
      for (i = 0, n = [dirContents count]; i < n; i++)
	{
	  NSString *filename = [dirContents objectAtIndex:i];

	  if ([filename length] <= 0 || [filename hasPrefix:@"."])
	    {
	      [dirContents removeObjectAtIndex:i];
	      n--;
	      i--;
	    }
	}
    }

  // Sort the filenames
  [self _getSortedDirContents:dirContents atPath:path];

  return AUTORELEASE(dirContents);
}

// --- Directory contents

- (NSArray *)directoryContentsAtPath:(NSString *)path
                             forPath:(NSString *)targetPath
                          showHidden:(BOOL)showHidden
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSMutableArray *dirContents;

  dirContents = [[fm directoryContentsAtPath:path] mutableCopy];

  if (showHidden == NO)
    {
      NSString *hiddenFilename;
      unsigned i, n;
      NSString *filename;
      NSString *pathIntersection = NXIntersectionPath(path, targetPath);

      hiddenFilename = [path stringByAppendingPathComponent:@".hidden"];
      if ([fm fileExistsAtPath:hiddenFilename])
	{
	  NSString     *h = [NSString stringWithContentsOfFile:hiddenFilename];
	  NSArray      *hidden = [h componentsSeparatedByString:@"\n"];
	  NSEnumerator *e = [hidden objectEnumerator];

	  while ((filename = [e nextObject]) != nil)
	    {
              if (![targetPath
                     hasPrefix:[path stringByAppendingPathComponent:filename]])
                {
                  [dirContents removeObject:filename];
                }
	    }
	}
      for (i = 0, n = [dirContents count]; i < n; i++)
	{
	  NSString *filename = [dirContents objectAtIndex:i];

	  if ([filename length] <= 0 || [filename hasPrefix:@"."])
	    {
	      [dirContents removeObjectAtIndex:i];
	      n--;
	      i--;
	    }
	}
    }

  [dirContents sortUsingSelector:@selector(localizedCompare:)];
    
  return [dirContents autorelease];
}

- (NSArray *)directoryContentsAtPath:(NSString *)path
                             forPath:(NSString *)targetPath
                            sortedBy:(NXSortType)sortType
                          showHidden:(BOOL)showHidden
{
  
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSMutableArray *dirContents;
  SEL            compareSelector = 0;
  BOOL           foldersFirst = NO;

  dirPath = path;
  
  switch (sortType)
    {
    case NXSortByName:  // = 0
      compareSelector = @selector(localizedCompare:);
      break;
    case NXSortByKind:  // = 1
      compareSelector = @selector(localizedCompare:);
      foldersFirst = YES;
      break;
    case NXSortByType:  // = 2
      compareSelector = @selector(byTypeCompare:);
      foldersFirst = YES;
      break;
    case NXSortByDate:  // = 3
      compareSelector = @selector(byDateCompare:);
      break;
    case NXSortBySize:  // = 4
      compareSelector = @selector(bySizeCompare:);
      break;
    case NXSortByOwner: // = 5
      compareSelector = @selector(byOwnerCompare:);
      break;
    }

  dirContents = [[self directoryContentsAtPath:path
                                       forPath:targetPath
                                    showHidden:showHidden] mutableCopy];
  if (!dirContents)
    return nil;
  
  if (foldersFirst)
    {
      NSEnumerator   *e = [dirContents objectEnumerator];
      NSMutableArray *dirs = [[NSMutableArray alloc] init];
      NSMutableArray *files = [[NSMutableArray alloc] init];
      NSString       *entry = nil;
      NSDictionary   *fattrs;
      BOOL           isDir;
      NSString       *fp;

      while ((entry = [e nextObject]) != nil)
        {
          fp = [path stringByAppendingPathComponent:entry];
          fattrs = [fm fileAttributesAtPath:fp traverseLink:YES];

          if ([[fattrs fileType] isEqualToString:NSFileTypeDirectory])
          // if (isDir == YES)
            {
              [dirs addObject:entry];
            }
          else
            {
              [files addObject:entry];
            }
        }

      // Empty dirContents
      [dirContents removeAllObjects];

      // Add sorted directories
      [dirs sortUsingSelector:compareSelector];
      [dirContents addObjectsFromArray:dirs];
      [dirs release];

      // Add sorted files
      [files sortUsingSelector:compareSelector];
      [dirContents addObjectsFromArray:files];
      [files release];
    }
  else
    {
      [dirContents sortUsingSelector:compareSelector];
    }

  return AUTORELEASE(dirContents);
}

// --- Files
- (NSString *)mimeTypeForFile:(NSString *)fullPath
{
  magic_t    cookie;
  const char *mime_type;
  NSString   *mimeType;
  
  cookie = magic_open(MAGIC_MIME_TYPE);
  magic_load(cookie, NULL);

  mime_type = magic_file(cookie, [fullPath cString]);
  
  mimeType = [NSString stringWithCString:mime_type];

  magic_close(cookie);

  return mimeType;
}

- (NSString *)mimeEncodingForFile:(NSString *)fullPath
{
  magic_t    cookie;
  const char *mime_enc;
  NSString   *mimeEncoding;
  
  cookie = magic_open(MAGIC_MIME_ENCODING);
  magic_load(cookie, NULL);

  mime_enc = magic_file(cookie, [fullPath cString]);
  
  mimeEncoding = [NSString stringWithCString:mime_enc];

  magic_close(cookie);

  return mimeEncoding;
}

- (NSString *)descriptionForFile:(NSString *)fullPath
{
  magic_t    cookie;
  const char *description;
  NSString   *fileDescription;
  
  cookie = magic_open(MAGIC_NONE);
  magic_load(cookie, NULL);

  description = magic_file(cookie, [fullPath cString]);
  
  fileDescription = [NSString stringWithCString:description];
  
  magic_close(cookie);

  return fileDescription;
}

@end

/*@implementation NSFileManager (NX)

@end*/
