/**
   NSKVOSwizzling.m

   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by: Hugo Melder <hugo@algoriddim.com>
   Date: June 2024

   Based on WinObjC KVO tests by Microsoft Corporation.

   This file is part of GNUStep-base

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/
/**
  Copyright (c) Microsoft. All rights reserved.

  This code is licensed under the MIT License (MIT).

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
*/

/* This Key Value Observing Implementation is tied to libobjc2 */

#pragma once

// Each OBJC_APPLY_*_TYPE_ENCODINGS macro expects a single argument: the name
// of a macro to apply for every type encoding. That macro should take the form
// #define name(ctype, objectiveCName, CapitalizedObjectiveCName,
// typeEncodingCharacter)

#if defined(_Bool)
#define OBJC_APPLY_BOOL_TYPE_ENCODING(_APPLY_TYPE_MACRO)                       \
  _APPLY_TYPE_MACRO(_Bool, bool, Bool, 'B')
#else
#define OBJC_APPLY_BOOL_TYPE_ENCODING(_APPLY_TYPE_MACRO) // Nothing
#endif

#define OBJC_APPLY_NUMERIC_TYPE_ENCODINGS(_APPLY_TYPE_MACRO)                   \
  _APPLY_TYPE_MACRO(double, double, Double, 'd')                               \
  _APPLY_TYPE_MACRO(float, float, Float, 'f')                                  \
  _APPLY_TYPE_MACRO(signed char, char, Char, 'c')                              \
  _APPLY_TYPE_MACRO(int, int, Int, 'i')                                        \
  _APPLY_TYPE_MACRO(short, short, Short, 's')                                  \
  _APPLY_TYPE_MACRO(long, long, Long, 'l')                                     \
  _APPLY_TYPE_MACRO(long long, longLong, LongLong, 'q')                        \
  _APPLY_TYPE_MACRO(unsigned char, unsignedChar, UnsignedChar, 'C')            \
  _APPLY_TYPE_MACRO(unsigned short, unsignedShort, UnsignedShort, 'S')         \
  _APPLY_TYPE_MACRO(unsigned int, unsignedInt, UnsignedInt, 'I')               \
  _APPLY_TYPE_MACRO(unsigned long, unsignedLong, UnsignedLong, 'L')            \
  _APPLY_TYPE_MACRO(unsigned long long, unsignedLongLong, UnsignedLongLong,    \
                    'Q')                                                       \
  OBJC_APPLY_BOOL_TYPE_ENCODING(_APPLY_TYPE_MACRO)

//APPLY_TYPE(__int128, int128, Int128, 't') \
//APPLY_TYPE(unsigned __int128, unsignedInt128, UnsignedInt128, 'T')

#define OBJC_APPLY_OBJECTIVEC_TYPE_ENCODINGS(_APPLY_TYPE_MACRO)                \
  _APPLY_TYPE_MACRO(id, object, Object, '@')                                   \
  _APPLY_TYPE_MACRO(Class, class, Pointer, '#')                                \
  _APPLY_TYPE_MACRO(SEL, selector, Pointer, ':')
#define OBJC_APPLY_POINTER_TYPE_ENCODINGS(_APPLY_TYPE_MACRO)                   \
  _APPLY_TYPE_MACRO(char *, cString, Pointer, '*')

#define OBJC_APPLY_ALL_TYPE_ENCODINGS(_APPLY_TYPE_MACRO)                       \
  OBJC_APPLY_NUMERIC_TYPE_ENCODINGS(_APPLY_TYPE_MACRO)                         \
  OBJC_APPLY_OBJECTIVEC_TYPE_ENCODINGS(_APPLY_TYPE_MACRO)                      \
  OBJC_APPLY_POINTER_TYPE_ENCODINGS(_APPLY_TYPE_MACRO)
