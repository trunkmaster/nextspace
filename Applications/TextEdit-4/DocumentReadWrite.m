/*
  DocumentReadWrite.m
  Copyright (c) 1995-1996, NeXT Software, Inc.
  All rights reserved.
  Author: Ali Ozer

  You may freely copy, distribute and reuse the code in this example.
  NeXT disclaims any warranty of any kind, expressed or implied,
  as to its fitness for any particular use.

  File I/O code... We define a few convenience methods on NSAttributedString as well.
*/

#import <AppKit/AppKit.h>
#import "Document.h"
#import "Preferences.h"
#import <sys/stat.h>

#define IgnoreRichText NO

#import <string.h>		// For memcmp()...

static const unsigned char	bigMarker[]		= {0xff, 0xfe};
static const unsigned char	littleMarker[]	= {0xfe, 0xff};
static const unsigned char	utf8Marker[]	= {0xef, 0xbb, 0xbf};
static const unsigned char	rtfHeader[]		= {'{', '\\', 'r', 't', 'f'};

@interface NSAttributedString (EditExtensions)

- (id) initWithRTF:(NSData *)data
          viewSize:(NSSize *)size
 hyphenationFactor:(float *)factor;

- (id) initWithRTFDFile: (NSString *)path
               viewSize:(NSSize *)size
      hyphenationFactor:(float *)factor;

- (BOOL) writeRTFDToFile: (NSString *)path
         updateFilenames: (BOOL)flag
                viewSize: (NSSize)size
       hyphenationFactor: (float)factor;

- (NSData *) RTFFromRange: (NSRange)range
                 viewSize: (NSSize)size
        hyphenationFactor: (float)factor;

@end
			
@implementation NSAttributedString (EditExtensions)
static float
defaultPadding (void)
{
  static float	padding = -1;

  if (padding < 0.0) {
    NSTextContainer	*container = [[NSTextContainer alloc] init];

    padding = [container lineFragmentPadding];
    [container release];
  }
  return padding;
}

- (id) initWithRTF:(NSData *)data
          viewSize:(NSSize *)size 
 hyphenationFactor:(float *)factor
{
  NSDictionary	*docAttrs;

  if ((self = [self initWithRTF: data documentAttributes: &docAttrs])) {
    NSValue		*value;
    NSNumber	*number;

    if (size && (value = [docAttrs objectForKey: @"PaperSize"])) {
      *size = [value sizeValue];

      /* The size has the 12 pt padding from old Edit; compensate for that... Note that we should really be getting the margins here! */
      if (size->width > 0 && size->height > 0)
        size->width = size->width - (6.0 * 2) + (defaultPadding () * 2);
    }

    if (factor && (number = [docAttrs objectForKey: @"HyphenationFactor"]))
      *factor = [number floatValue];
  }
  return self; 
}

- (id) initWithRTFDFile:(NSString *)path 
               viewSize:(NSSize *)size
      hyphenationFactor:(float *)factor
{
  NSDictionary	*docAttrs;

  if ((self = [self initWithPath: path documentAttributes: &docAttrs])) {
    NSValue		*value;
    NSNumber	*number;

    if (size && (value = [docAttrs objectForKey: @"PaperSize"])) {
      *size = [value sizeValue];

      // The size has the 12 pt padding from old Edit; compensate for that...
      // Note that we should really be getting the margins here!
      if (size->width > 0 && size->height > 0)
        size->width = size->width - (6.0 * 2) + (defaultPadding () * 2);
    }

    if (factor && (number = [docAttrs objectForKey:@"HyphenationFactor"]))
      *factor = [number floatValue];
  }
  return self;
}

- (BOOL) writeRTFDToFile:(NSString *)path
         updateFilenames:(BOOL)flag
                viewSize:(NSSize)size
       hyphenationFactor:(float)factor
{
  NSDictionary	*dict = [NSDictionary dictionaryWithObjectsAndKeys: [NSValue valueWithSize: NSMakeSize (size.width + (6.0 * 2) - (defaultPadding () * 2), size.height)], @"PaperSize", [NSNumber numberWithFloat: factor], @"HyphenationFactor", nil];
  NSFileWrapper	*wrapper = [self RTFDFileWrapperFromRange: NSMakeRange (0, [self length]) documentAttributes: dict];

  if (wrapper) {
    return [wrapper writeToFile: path atomically: YES updateFilenames: flag];
  } else {
    return NO;
  }
}

- (NSData *) RTFFromRange:(NSRange)range
                 viewSize:(NSSize)size
        hyphenationFactor:(float)factor
{
  NSDictionary	*dict = [NSDictionary dictionaryWithObjectsAndKeys: [NSValue valueWithSize: NSMakeSize (size.width + (6.0 * 2) - (defaultPadding () * 2), size.height)], @"PaperSize", [NSNumber numberWithFloat: factor], @"HyphenationFactor", nil];

  return [self RTFFromRange: range documentAttributes: dict];
}

@end


@implementation Document (ReadWrite)

/*
  -loadFromPath:encoding:

  Loads from the specified path, sets encoding and textStorage. Note that if
  the file looks like RTF or RTFD, this method will open the file in rich
  text mode, regardless of the setting of encoding.
*/
- (BOOL) loadFromPath:(NSString *)fileName encoding:(int)encoding
{
  NSData        *fileContentsAsData = nil;
  NSDictionary	*attrs;
  NSString      *extension = [fileName pathExtension];
  BOOL          success = NO;
  BOOL          isDirectory;
	
  if (!(attrs = [[NSFileManager defaultManager] fileAttributesAtPath: fileName traverseLink: YES]))
    return NO;

  isDirectory = [[attrs fileType] isEqualToString: NSFileTypeDirectory];

  if (isDirectory)
    {
      if (![@"rtfd" isEqual:extension])	// if directory, should be .rtfd
        return NO;
      encoding = RichTextWithGraphicsStringEncoding;
    }
  else if ([@"rtf" isEqual: extension] && !IgnoreRichText)
    { // file looks like RTF
      encoding = RichTextStringEncoding;
    }
  else if (encoding == UnknownStringEncoding)
    { // do some autodetection
      if ((fileContentsAsData = [[NSData alloc] initWithContentsOfFile: fileName]))
        {
          const unsigned char *bytes = [fileContentsAsData bytes];
          unsigned            len = [fileContentsAsData length];

          //  Unicode plain text files start with the Unicode BOM char;
          //  check for that first...
          if (((len & 1) == 0) && (len >= 2)
              && (!memcmp (bytes, bigMarker, 2)
                  || !memcmp (bytes, littleMarker, 2)))
            {
              encoding = NSUnicodeStringEncoding;
            }
          else if ((len > 2) && (!memcmp(bytes, utf8Marker, 3)))
            {
              encoding = NSUTF8StringEncoding;
            }
          else if (((len >= 6) && !memcmp(bytes, rtfHeader, 5)) && !IgnoreRichText)
            {
              encoding = RichTextStringEncoding;
            }

          if (encoding == UnknownStringEncoding)
            {
              encoding = [[Preferences objectForKey: PlainTextEncoding] intValue];
              if (encoding == UnknownStringEncoding)
                {
                  encoding = [NSString defaultCStringEncoding];
                }
            }
        }
      else
        {
          return NO;	/* File couldn't be opened, I guess */
        }
    }

  if (encoding == RichTextWithGraphicsStringEncoding)
    {
      NSSize         size = NSZeroSize;
      float          factor = 0.0;
      NSTextStorage  *newTextStorage = [[NSTextStorage alloc] initWithRTFDFile:fileName
                                                                      viewSize:&size
                                                             hyphenationFactor:&factor];

      if (newTextStorage)
        {
          [self setRichText:YES];
        
          if (size.width > 0 && size.height > 0 && ![self hasMultiplePages])
            [self setViewSize: size];

          [self setHyphenationFactor: factor];
          [[self layoutManager] replaceTextStorage: newTextStorage];
          [textStorage release];
          textStorage = newTextStorage;
          success = YES;
        }
    }
  else
    {
      if (!fileContentsAsData)
        fileContentsAsData = [[NSData alloc] initWithContentsOfFile:fileName];
      
      if (fileContentsAsData)
        {
          if (encoding == RichTextStringEncoding)
            {
              NSSize        size = NSZeroSize;
              float         factor = 0.0;
              NSTextStorage *newTextStorage = [[NSTextStorage alloc] initWithRTF:fileContentsAsData
                                                                        viewSize:&size
                                                               hyphenationFactor:&factor];

              if (newTextStorage)
                {
                  [self setRichText:YES];

                  if (size.width > 0 && size.height > 0 && ![self hasMultiplePages])
                    [self setViewSize:size];

                  [self setHyphenationFactor:factor];
                  [[self layoutManager] replaceTextStorage:newTextStorage];
                  [textStorage release];
                  textStorage = newTextStorage;
                  success = YES;
                }
            }
          else
            {
              NSString *fileContents = [[NSString alloc] initWithData:fileContentsAsData 
                                                             encoding:encoding];

              if (fileContents)
                {
                  [textStorage beginEditing];
                  [[textStorage mutableString] setString: fileContents];
                  [self setRichText: NO];
                  [textStorage endEditing];
                  [fileContents release];
                  encodingIfPlainText = encoding;
                  success = YES;
                }
            }
        }
    }
  [fileContentsAsData release];
  
  return success;
}

- (BOOL) saveToPath: (NSString *)fileName encoding: (int)encoding updateFilenames: (BOOL)updateFileNamesFlag
{
  NSFileManager	*fileManager = [NSFileManager defaultManager];
  NSDictionary	*curAttributes = [fileManager fileAttributesAtPath: fileName traverseLink: YES];
  NSString		*actualFileNameToSave = [fileName stringByResolvingSymlinksInPath];	// follow links to save
  BOOL			success = NO;

  if (curAttributes) {	// If not nil, the file exists...
    NSString	*backupFileName = [actualFileNameToSave stringByAppendingString: @"~"];

    if ([fileManager fileExistsAtPath: backupFileName]) {	// if there was a backup file, delete it
      [fileManager removeFileAtPath: backupFileName handler: nil];
    }

    // if user wants to keep backups, move the old file aside
    if (![[Preferences objectForKey: DeleteBackup] boolValue]) {
      [fileManager movePath: actualFileNameToSave toPath: backupFileName handler: nil];
    }
  }
	
  switch (encoding) {
  case RichTextWithGraphicsStringEncoding:
    success = [textStorage writeRTFDToFile: actualFileNameToSave updateFilenames: updateFileNamesFlag viewSize: [self viewSize] hyphenationFactor: [self hyphenationFactor]];
    break;

  case RichTextStringEncoding: {
    NSData	*data = [textStorage RTFFromRange: NSMakeRange (0, [textStorage length]) viewSize: [self viewSize] hyphenationFactor: [self hyphenationFactor]];
    success = data && [data writeToFile: actualFileNameToSave atomically: YES];
    break;
  }

  case NSUTF8StringEncoding: {
    NSMutableData	*bom = [NSMutableData dataWithBytes: &utf8Marker length: sizeof (utf8Marker)];
    NSData			*data = [[textStorage string] dataUsingEncoding: encoding];

    if (!data)
      break;

    [bom appendData: data];
    success = [bom writeToFile: actualFileNameToSave atomically: YES];
    break;
  }

  default: {
    NSData *data = [[textStorage string] dataUsingEncoding: encoding];

    success = data && [data writeToFile: actualFileNameToSave atomically: YES];
    break;
  }
  }

  /*
    Apply the original permissions to the new file. Also make it writable
    if needed.
  */
  if (success && curAttributes) {
    id	permissions = [curAttributes objectForKey: NSFilePosixPermissions];

    if (permissions) {
      if ([[Preferences objectForKey: SaveFilesWritable] boolValue]) {
        permissions = [NSNumber numberWithUnsignedLong: ([permissions unsignedLongValue] | 0200)];
      }

      [fileManager changeFileAttributes: [NSDictionary dictionaryWithObjectsAndKeys: permissions, NSFilePosixPermissions, nil] atPath: actualFileNameToSave];
    }
  }
  return success;
}

@end


/*
  2/21/95 aozer	Created for Edit II.
  4/11/95 aozer	Added some preliminary paper size support
  4/13/95 aozer	Permissions
  7/21/95 aozer	Follow links correctly for saving
  11/7/96 aozer	Read/write hyphenation factor in RTF files
*/
