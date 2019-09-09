/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Description: Standard panel for application help.
//
// Copyright (C) 2019 Sergii Stoian
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
#import "NXTHelpPanel.h"

@implementation NXTHelpPanel : NSPanel

+ (NSHelpPanel *)sharedHelpPanel
{
  NSLLog(@"Not implemented");
  return nil;
}
+ (NSHelpPanel *)sharedHelpPanelWithDirectory:(NSString *)helpDirectory
{
  NSLLog(@"Not implemented");
  NSString           *fileName;
  NSAttributedString *attrString;
  NSString           *text;
  NSRange            range;
  NSDictionary       *attrs;
  id                 attachment;

  // `helpDirectory`/TOC.rtf
  fileName = [NSString stringWithCString:@"TOC.rtf"];

  attrString = [[NSAttributedString alloc]
                   initWithRTF:[NSData dataWithContentsOfFile:fileName]
                 documentAttributes:NULL];
  text = [attrString string];
    
  for (int i = 0; i < [text length]; i++) {
    attrs = [attrString attributesAtIndex:i effectiveRange:&range];
    // NSLog(@"[%d] %@ - (%@)", i, attrs, NSStringFromRange(range));
    if ((attachment = [attrs objectForKey:@"NSAttachment"]) != nil) {
      // attrs = [string attributesAtIndex:++i effectiveRange:&range];
      range = [text lineRangeForRange:range];
      range.location++;
      range.length -= 2;
      NSLog(@"%@ -> %@",
            [text substringWithRange:range],
            [attachment fileName]);
    }
    i = range.location + range.length;
  }
  
  return nil;
}

// --- Managing the Contents

+ (void)setHelpDirectory:(NSString *)helpDirectory
{
  NSLLog(@"Not implemented");
}

- (void)addSupplement:(NSString *)helpDirectory
               inPath:(NSString *)supplementPath
{
  NSLLog(@"Not implemented");
}

- (NSString *)helpDirectory
{
  NSLLog(@"Not implemented");
  return nil;
}

- (NSString *)helpFile
{
  NSLLog(@"Not implemented");
  return nil;
}


// --- Attaching Help to Objects

+ (void)attachHelpFile:(NSString *)filename
            markerName:(NSString *)markerName
                    to:(id)anObject
{
  NSLLog(@"Not implemented");
}

+ (void)detachHelpFrom:(id)anObject
{
  NSLLog(@"Not implemented");
}

// --- Showing Help

- (void)showFile:(NSString *)filename
        atMarker:(NSString *)markerName
{
  NSLLog(@"Not implemented");
}

- (BOOL)showHelpAttachedTo:(id)anObject
{
  NSLLog(@"Not implemented");
  return NO;
}

// --- Printing 
- (void)print:(id)sender
{
  NSLLog(@"Not implemented");
}

@end
