/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2006-2014 Sergii Stoian
// Copyright (C) 2005 Saso Kiselkov
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "Copy.h"
#import "NSStringAdditions.h"

#include <sys/types.h>
#include <sys/stat.h>

#ifdef __FreeBSD__
#include <fcntl.h>    // for open(), O_RDONLY, O_WRONLY, etc.
#include <unistd.h>   // for close(), read(), write()
#endif

// --- Copy

void CleanUpAfterCopy(NSString *destDir, NSArray *files)
{
  NSString *file;
  NSString *filePath;
  NSEnumerator *e = [files objectEnumerator];
  NSFileManager *fm = [NSFileManager defaultManager];

  while ((file = [e nextObject]) != nil) {
    filePath = [destDir stringByAppendingPathComponent:file];
    if ([fm fileExistsAtPath:filePath]) {
      [fm removeItemAtPath:filePath error:NULL];
    }
  }
}

BOOL CopyOperation(NSString *sourceDir, NSArray *files, NSString *destDir, OperationType opType)
{
  NSEnumerator *e;
  NSString *file;
  BOOL opResult = YES;

  e = [files objectEnumerator];
  while (((file = [e nextObject]) != nil) && !isStopped && (opResult == YES)) {
    NSDebugLLog(@"Tools", @"Copy operation START");
    opResult = CopyFile(file, sourceDir, destDir, NO, opType);
    NSDebugLLog(@"Tools", @"Copy operation END");
  }

  // We received SIGTERM signal or 'Stop' command
  // Remove created duplicates and exit
  if (isStopped) {
    if (makeCleanupOnStop) {
      CleanUpAfterCopy(destDir, files);
    }
  }

  return opResult;
}

BOOL CopyDirectory(NSString *sourceDir, NSString *targetDir, NSDictionary *fileAttributes,
                   OperationType opType)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *contents;
  NSEnumerator *e;
  NSString *filename;
  BOOL dir;
  Communicator *comm = [Communicator shared];

  NSDebugLLog(@"Tools", @"Copy directory: %@ to %@", sourceDir, targetDir);
  [comm showProcessingFilename:nil
                  sourcePrefix:sourceDir
                  targetPrefix:targetDir
                 bytesAdvanced:[fileAttributes fileSize]
                 operationType:opType];

  if ([fm fileExistsAtPath:targetDir isDirectory:&dir]) {
    if (dir == NO) {
      ProblemSolution sol = [comm howToHandleProblem:FileExists];

      if (sol == SkipFile) {
        return NO;
      } else if (![fm removeFileAtPath:targetDir handler:nil]) {
        [comm howToHandleProblem:WriteError];
      }
    }
  } else if (![fm createDirectoryAtPath:targetDir attributes:nil]) {
    [comm howToHandleProblem:WriteError];
    return NO;
  }

  contents = [fm directoryContentsAtPath:sourceDir];
  if (contents == nil) {
    [comm howToHandleProblem:ReadError];
    return NO;
  }

  e = [contents objectEnumerator];
  while (((filename = [e nextObject]) != nil) && !isStopped) {
    CopyFile(filename, sourceDir, targetDir, NO, opType);
  }

  if (chmod([targetDir cString], [fileAttributes filePosixPermissions]) == -1) {
    [comm howToHandleProblem:AttributesUnchangeable argument:[NSString errnoDescription]];
  }

  return YES;
}

BOOL CopyRegular(NSString *sourceFile, NSString *targetFile, NSDictionary *fileAttributes,
                 OperationType opType)
{
  NSUInteger doneSize = 0;
  NSString *sourceDir = [sourceFile stringByDeletingLastPathComponent];
  NSString *targetDir = [targetFile stringByDeletingLastPathComponent];
  NSFileManager *fm = [NSFileManager defaultManager];
  Communicator *comm = [Communicator shared];

  if ([fm fileExistsAtPath:targetFile]) {
    ProblemSolution sol = [comm howToHandleProblem:FileExists];

    if (sol == SkipFile) {
      return NO;
    } else if (![fm removeFileAtPath:targetFile handler:nil]) {
      [comm howToHandleProblem:WriteError];
      return NO;
    }
  }

  if (![fm createFileAtPath:targetFile contents:nil attributes:nil]) {
    [comm howToHandleProblem:WriteError];
    return NO;
  }

  if ([fm fileExistsAtPath:targetFile] == NO) {
    if ([fm createFileAtPath:targetFile contents:nil attributes:nil] == NO) {
      return NO;
    }
  }

  {
    int read_fd, write_fd;
    ssize_t bytes_read = 1;
    size_t block_size = 64 * 1024;
    void *buf;

    read_fd = open([sourceFile cString], O_RDONLY);
    if (read_fd < 0) {
      [comm howToHandleProblem:ReadError];
      return NO;
    }
    write_fd = open([targetFile cString], O_WRONLY);
    if (write_fd < 0) {
      [comm howToHandleProblem:WriteError];
      close(read_fd);
      return NO;
    }
    buf = malloc(64 * 1024);

    while (!isStopped && bytes_read) {
      bytes_read = read(read_fd, buf, block_size);
      if (bytes_read > 0) {
        write(write_fd, buf, bytes_read);
      }
      doneSize += bytes_read;
      [comm showProcessingFilename:[sourceFile lastPathComponent]
                      sourcePrefix:sourceDir
                      targetPrefix:targetDir
                     bytesAdvanced:(NSUInteger)bytes_read
                     operationType:opType];
    }
    close(read_fd);
    close(write_fd);
    free(buf);
  }

  if (!isStopped) {
    int result = chmod([targetFile cString], [fileAttributes filePosixPermissions]);
    if (result == -1) {
      [comm howToHandleProblem:AttributesUnchangeable argument:[NSString errnoDescription]];
    }

    if (doneSize < [fileAttributes fileSize]) {
      [comm showProcessingFilename:[sourceFile lastPathComponent]
                      sourcePrefix:sourceDir
                      targetPrefix:targetDir
                     bytesAdvanced:[fileAttributes fileSize] - doneSize
                     operationType:opType];
    }
  }

  return YES;
}

BOOL CopySymbolicLink(NSString *sourceFile, NSString *targetFile, NSDictionary *fattrs,
                      OperationType opType)
{
  NSString *sourceDir = [sourceFile stringByDeletingLastPathComponent];
  NSString *targetDir = [targetFile stringByDeletingLastPathComponent];
  ProblemSolution s;
  NSFileManager *fm = [NSFileManager defaultManager];
  Communicator *comm = [Communicator shared];
  NSString *pathContent;

  NSDebugLLog(@"Tools", @"Copy symlink: %@ to: %@", sourceFile, targetFile);

  s = [comm howToHandleProblem:SymlinkEncountered];

  // Special case: symlink to current directortory found
  // Make new link to save the link
  pathContent = [fm pathContentOfSymbolicLinkAtPath:sourceFile];
  if ([pathContent isEqualToString:@"."] || [pathContent isEqualToString:@"./"] ||
      [pathContent isEqualToString:@"/."] || [pathContent isEqualToString:@"./."]) {
    s = NewLink;
  } else if (s == CopyOriginal && ![fm fileExistsAtPath:pathContent]) {
    NSString *message;

    message = [NSString stringWithFormat:@"Symlink target of %@ doesn't exist", sourceFile];
    s = [comm howToHandleProblem:SymlinkTargetNotExist argument:message];
  }

  if (s == CopyOriginal)  // "Copy" button - copy the original
  {
    return CopyFile([sourceFile lastPathComponent], sourceDir, targetDir, YES, opType);
  } else if (s == NewLink)  // "New Link" button - make new link
  {
    // pathContent = [fm pathContentOfSymbolicLinkAtPath:sourceFile];
    if (pathContent == nil) {
      [comm howToHandleProblem:ReadError];
      goto copySymlinkEnd;
    }

    // Check for existance of target
    if ([fm fileExistsAtPath:targetFile]) {
      ProblemSolution s;

      s = [comm howToHandleProblem:FileExists];
      if (s == SkipFile) {
        goto copySymlinkEnd;
      } else if (![fm removeFileAtPath:targetFile handler:nil]) {
        [comm howToHandleProblem:WriteError];
        goto copySymlinkEnd;
      }
    }

    if (![fm createSymbolicLinkAtPath:targetFile pathContent:pathContent]) {
      [comm howToHandleProblem:WriteError];
      goto copySymlinkEnd;
    }
  } else  // Skip
  {
    goto copySymlinkEnd;
  }

copySymlinkEnd:
  [comm showProcessingFilename:[sourceFile lastPathComponent]
                  sourcePrefix:sourceDir
                  targetPrefix:targetDir
                 bytesAdvanced:[fattrs fileSize]
                 operationType:opType];

  return YES;
}

BOOL CopyFile(NSString *filename, NSString *sourcePrefix, NSString *targetPrefix, BOOL traverseLink,
              OperationType opType)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *sourceFile;
  NSString *targetFile;
  NSDictionary *fattrs;
  NSString *fileType;
  Communicator *comm = [Communicator shared];

  sourceFile = [sourcePrefix stringByAppendingPathComponent:filename];
  targetFile = [targetPrefix stringByAppendingPathComponent:filename];
  fattrs = [fm fileAttributesAtPath:sourceFile traverseLink:traverseLink];

  NSDebugLLog(@"Tools", @"Copy filename: %@ %@ %@", filename, sourcePrefix, targetPrefix);
  [comm showProcessingFilename:filename
                  sourcePrefix:sourcePrefix
                  targetPrefix:targetPrefix
                 bytesAdvanced:0
                 operationType:opType];

  fileType = [fattrs fileType];
  if ([fileType isEqualToString:NSFileTypeSymbolicLink]) {
    return CopySymbolicLink(sourceFile, targetFile, fattrs, opType);
  } else if ([fileType isEqualToString:NSFileTypeDirectory]) {
    return CopyDirectory(sourceFile, targetFile, fattrs, opType);
  } else if ([fileType isEqualToString:NSFileTypeRegular]) {
    return CopyRegular(sourceFile, targetFile, fattrs, opType);
  } else if ([fileType isEqualToString:NSFileTypeSocket]) {
    [comm howToHandleProblem:UnknownFile argument:@"socket"];
    return NO;
  } else if ([fileType isEqualToString:NSFileTypeFifo]) {
    [comm howToHandleProblem:UnknownFile argument:@"fifo"];
    return NO;
  } else if ([fileType isEqualToString:NSFileTypeCharacterSpecial]) {
    [comm howToHandleProblem:UnknownFile argument:@"character special"];
    return NO;
  } else if ([fileType isEqualToString:NSFileTypeBlockSpecial]) {
    [comm howToHandleProblem:UnknownFile argument:@"block special"];
    return NO;
  } else {
    [comm howToHandleProblem:UnknownFile argument:nil];
    return NO;
  }
}

// --- Duplicate

void CleanUpAfterDuplicate(NSString *sourceDir, NSArray *files)
{
  NSString *file;
  NSString *fileDup;
  NSString *fileDupPath;
  NSEnumerator *e = [files objectEnumerator];
  NSFileManager *fm = [NSFileManager defaultManager];

  while ((file = [e nextObject]) != nil) {
    fileDup = [NSString stringWithFormat:@"CopyOf_%@", file];
    fileDupPath = [sourceDir stringByAppendingPathComponent:fileDup];
    if ([fm fileExistsAtPath:fileDupPath]) {
      [fm removeItemAtPath:fileDupPath error:NULL];
    }
  }
}

void DuplicateOperation(NSString *sourceDir, NSArray *files)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error = nil;
  NSEnumerator *e;
  NSString *file;
  Communicator *comm = [Communicator shared];

  NSDebugLLog(@"Tools", @"FileOperation: Duplicate %@, %@", sourceDir, files);

  // Normalize
  if (files == nil || ![files isKindOfClass:[NSArray class]] || [files count] <= 0) {
    files = [NSArray arrayWithObject:[sourceDir lastPathComponent]];
    sourceDir = [sourceDir stringByDeletingLastPathComponent];
  }

  // Proceed with duplicating...
  e = [files objectEnumerator];
  while (((file = [e nextObject]) != nil) && !isStopped) {
    DuplicateFile(file, sourceDir, NO);
  }

  // We received SIGTERM signal or 'Stop' command
  // Remove created duplicates and exit
  if (isStopped) {
    if (makeCleanupOnStop) {
      CleanUpAfterDuplicate(sourceDir, files);
    }
  }
}

BOOL DuplicateSymbolicLink(NSString *sourceFile, NSString *targetFile, NSDictionary *fattrs)
{
  NSString *sourceDir = [sourceFile stringByDeletingLastPathComponent];
  NSString *targetDir = [targetFile stringByDeletingLastPathComponent];
  ProblemSolution s;
  NSFileManager *fm = [NSFileManager defaultManager];
  Communicator *comm = [Communicator shared];
  NSString *linkOriginal;

  s = [comm howToHandleProblem:SymlinkEncountered];

  linkOriginal = [fm pathContentOfSymbolicLinkAtPath:sourceFile];
  if (linkOriginal == nil) {
    [comm howToHandleProblem:ReadError];
    goto copySymlinkEnd;
  }

  if (s == CopyOriginal)  // "Copy" button - copy the original
  {
    return DuplicateFile([sourceFile lastPathComponent], sourceDir, YES);
  } else if (s == NewLink)  // "New Link" button - make new link
  {
    // Check for existance of target
    if ([fm fileExistsAtPath:targetFile]) {
      ProblemSolution s;

      s = [comm howToHandleProblem:FileExists];
      if (s == SkipFile) {
        goto copySymlinkEnd;
      } else if (![fm removeFileAtPath:targetFile handler:nil]) {
        [comm howToHandleProblem:WriteError];
        goto copySymlinkEnd;
      }
    }

    if (![fm createSymbolicLinkAtPath:targetFile pathContent:linkOriginal]) {
      [comm howToHandleProblem:WriteError];
      goto copySymlinkEnd;
    }
  } else  // "Skip"
  {
    goto copySymlinkEnd;
  }

copySymlinkEnd:
  [comm showProcessingFilename:[sourceFile lastPathComponent]
                  sourcePrefix:sourceDir
                  targetPrefix:targetDir
                 bytesAdvanced:[fattrs fileSize]
                 operationType:DuplicateOp];
  return YES;
}

BOOL DuplicateFile(NSString *filename, NSString *sourcePrefix, BOOL traverseLink)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *message;
  NSString *sourceFile;
  NSString *targetFile;
  NSDictionary *fattrs;
  NSString *fileType;
  Communicator *comm = [Communicator shared];

  if (filename) {
    sourceFile = [sourcePrefix stringByAppendingPathComponent:filename];
    targetFile = [NSString stringWithFormat:@"CopyOf_%@", filename];
  } else {
    sourceFile = sourcePrefix;
    targetFile = [NSString stringWithFormat:@"CopyOf_%@", [sourcePrefix lastPathComponent]];
  }
  targetFile = [sourcePrefix stringByAppendingPathComponent:targetFile];
  fattrs = [fm fileAttributesAtPath:sourceFile traverseLink:traverseLink];

  NSDebugLLog(@"Tools", @"Duplcate file: %@ to %@", sourceFile, targetFile);

  [comm showProcessingFilename:filename
                  sourcePrefix:sourcePrefix
                  targetPrefix:sourcePrefix
                 bytesAdvanced:0
                 operationType:DuplicateOp];

  fileType = [fattrs fileType];
  if ([fileType isEqualToString:NSFileTypeSymbolicLink]) {
    return DuplicateSymbolicLink(sourceFile, targetFile, fattrs);
  } else if ([fileType isEqualToString:NSFileTypeDirectory]) {
    return CopyDirectory(sourceFile, targetFile, fattrs, DuplicateOp);
  } else if ([fileType isEqualToString:NSFileTypeRegular]) {
    return CopyRegular(sourceFile, targetFile, fattrs, DuplicateOp);
  } else if ([fileType isEqualToString:NSFileTypeSocket]) {
    [comm howToHandleProblem:UnknownFile argument:@"socket"];
    return NO;
  } else if ([fileType isEqualToString:NSFileTypeFifo]) {
    [comm howToHandleProblem:UnknownFile argument:@"fifo"];
    return NO;
  } else if ([fileType isEqualToString:NSFileTypeCharacterSpecial]) {
    [comm howToHandleProblem:UnknownFile argument:@"character special"];
    return NO;
  } else if ([fileType isEqualToString:NSFileTypeBlockSpecial]) {
    [comm howToHandleProblem:UnknownFile argument:@"block special"];
    return NO;
  } else {
    [comm howToHandleProblem:UnknownFile argument:nil];
    return NO;
  }
}
