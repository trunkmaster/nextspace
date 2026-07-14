/*
 config.h.in

 Copyright (C) 2002 Free Software Foundation, Inc.

 Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
 Date: September 2002

 This file is part of the GNUstep Database Library.

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2 of the License, or (at your option) any later version.

 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Library General Public License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with this library; see the file COPYING.LIB.
 If not, write to the Free Software Foundation,
 31 Milk Street #960789 Boston, MA 02196 USA.
 */

#ifndef __config_h__
#define __config_h__

#ifndef GNUSTEP_BASE_MAJOR_VERSION		
#define GNUSTEP_BASE_MAJOR_VERSION		1
#define GNUSTEP_BASE_MINOR_VERSION		6
#define GNUSTEP_BASE_SUBMINOR_VERSION	0
#endif

/* Define if Foundation implements KeyValueCoding.  */
#define FOUNDATION_HAS_KVC 1

#ifndef HAVE_LIBC_H
#define HAVE_LIBC_H 1
#endif

#ifndef NeXT_RUNTIME
#define NeXT_RUNTIME 1
#endif

#ifndef NeXT_Foundation_LIBRARY
#define NeXT_Foundation_LIBRARY 1
#endif

#ifndef HAVE_WCHAR_H
#define HAVE_WCHAR_H 1
#endif

#ifndef HAVE_STRERROR
#define HAVE_STRERROR 1
#endif

#ifndef HAVE_LIBXML
#define HAVE_LIBXML 1
#endif

#ifndef HAVE_ICONV
#define HAVE_ICONV 1
#endif

#ifndef HAVE_INET_ATON
#define HAVE_INET_ATON 1
#endif

#ifndef RCS_ID
#define RCS_ID(name) \
static const char rcsId[] = name; \
static const char *__rcsId_hack() {__rcsId_hack(); return rcsId;}
#endif


#endif /* __config_h__ */
