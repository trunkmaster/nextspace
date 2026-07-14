/*
   Copyright (C) 2006 Free SoftwareFoundation, Inc.

   Written by: David Ayers <d.ayers@inode.at>
   Date: March 2006

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

/*
Testing of Various Byte Order Markers.
*/

#import "Testing.h"
#import <Foundation/Foundation.h>

int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSString *file=@"utf8bom.txt";
  NSString *contents;
  NSData *data;

  contents = [NSString stringWithContentsOfFile: file];
  PASS([contents hasPrefix: @"This"], "stringWithContentsOfFile: UTF-8 BOM");

  data = [NSData dataWithContentsOfFile: file];
  contents = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
  PASS([contents hasPrefix: @"This"], "initWithData:encoding: UTF-8 BOM");

  data = [@"a" dataUsingEncoding: NSUTF8StringEncoding];
  PASS([data length] == 1, "utf8 no bom")
  data = [@"a" dataUsingEncoding: NSUnicodeStringEncoding];
  PASS([data length] == 4, "unicode has bom")
  data = [@"a" dataUsingEncoding: NSUTF16BigEndianStringEncoding];
  PASS([data length] == 2, "utf16 big endian no bom")
  data = [@"a" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  PASS([data length] == 2, "utf16 little endian no bom")
  data = [@"a" dataUsingEncoding: NSUTF16StringEncoding];
  PASS([data length] == 4, "utf16 has bom")
  data = [@"a" dataUsingEncoding: NSUTF32BigEndianStringEncoding];
  PASS([data length] == 4, "utf32 big endian no bom")
  data = [@"a" dataUsingEncoding: NSUTF32LittleEndianStringEncoding];
  PASS([data length] == 4, "utf32 little endian no bom")
  data = [@"a" dataUsingEncoding: NSUTF32StringEncoding];
  PASS([data length] == 8, "utf32 has bom")

  data = [@"" dataUsingEncoding: NSUTF8StringEncoding];
  PASS([data length] == 0, "utf8 empty no bom")
  data = [@"" dataUsingEncoding: NSUnicodeStringEncoding];
  PASS([data length] == 2, "unicode empty has bom")
  data = [@"" dataUsingEncoding: NSUTF16BigEndianStringEncoding];
  PASS([data length] == 0, "utf16 big endian empty no bom")
  data = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  PASS([data length] == 0, "utf16 little endian empty no bom")
  data = [@"" dataUsingEncoding: NSUTF16StringEncoding];
  PASS([data length] == 2, "utf16 empty has bom")
  data = [@"" dataUsingEncoding: NSUTF32BigEndianStringEncoding];
  PASS([data length] == 0, "utf32 big endian empty no bom")
  data = [@"" dataUsingEncoding: NSUTF32LittleEndianStringEncoding];
  PASS([data length] == 0, "utf32 little endian empty no bom")
  data = [@"" dataUsingEncoding: NSUTF32StringEncoding];
  PASS([data length] == 4, "utf32 empty has bom")

  [pool release];
  return 0;
}

