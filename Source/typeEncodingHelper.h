/** Type-Encoding Helper
   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by:  Hugo Melder <hugo@algoriddim.com>
   Created: August 2024

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef __TYPE_ENCODING_HELPER_H
#define __TYPE_ENCODING_HELPER_H

/*
* Type-encoding for known structs in Foundation and CoreGraphics.
* From macOS 14.4.1 23E224 arm64:

* @encoding(NSRect) -> {CGRect={CGPoint=dd}{CGSize=dd}}
* @encoding(CGRect) -> {CGRect={CGPoint=dd}{CGSize=dd}}
* @encoding(NSPoint) -> {CGPoint=dd}
* @encoding(CGPoint) -> {CGPoint=dd}
* @encoding(NSSize) -> {CGSize=dd}
* @encoding(CGSize) -> {CGSize=dd}
* @encoding(NSRange) -> {_NSRange=QQ}
* @encoding(CFRange) -> {?=qq}
* @encoding(NSEdgeInsets) -> {NSEdgeInsets=dddd}
*
* Note that NSRange and CFRange are not toll-free bridged.
* You cannot pass a CFRange to +[NSValue valueWithRange:]
* as type encoding is different.
*
* We cannot enforce this using static asserts, as @encode
* is not a constexpr. It is therefore checked in
* Tests/base/KVC/type_encoding.m
*/

static const char *CGPOINT_ENCODING_PREFIX = "{CGPoint=";
static const char *CGSIZE_ENCODING_PREFIX = "{CGSize=";
static const char *CGRECT_ENCODING_PREFIX = "{CGRect=";
static const char *NSINSETS_ENCODING_PREFIX __attribute__((used)) = "{NSEdgeInsets=";
static const char *NSRANGE_ENCODING_PREFIX = "{_NSRange=";

#define IS_CGPOINT_ENCODING(encoding) (strncmp(encoding, CGPOINT_ENCODING_PREFIX, strlen(CGPOINT_ENCODING_PREFIX)) == 0)
#define IS_CGSIZE_ENCODING(encoding) (strncmp(encoding, CGSIZE_ENCODING_PREFIX, strlen(CGSIZE_ENCODING_PREFIX)) == 0)
#define IS_CGRECT_ENCODING(encoding) (strncmp(encoding, CGRECT_ENCODING_PREFIX, strlen(CGRECT_ENCODING_PREFIX)) == 0)
#define IS_NSINSETS_ENCODING(encoding) (strncmp(encoding, NSINSETS_ENCODING_PREFIX, strlen(NSINSETS_ENCODING_PREFIX)) == 0)
#define IS_NSRANGE_ENCODING(encoding) (strncmp(encoding, NSRANGE_ENCODING_PREFIX, strlen(NSRANGE_ENCODING_PREFIX)) == 0)

#endif /* __TYPE_ENCODING_HELPER_H */
