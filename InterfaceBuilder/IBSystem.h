/** 
    Platform specific definitions for externs
    Copyright (C) 2001 Free Software Foundation, Inc.

    Written by: Gregory John Casamento <greg_casamento@yahoo.com>
    Based on AppKitDefines.h by: Adam Fedor <fedor@gnu.org>
    Date: Dec, 2004
    
    This file is part of GNUstep.
    
    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.
    
    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library Lesser General Public License for more details.
    
    You should have received a copy of the GNU Library General Public
    License along with this library; if not, write to the Free
    Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, 
    MA 02111 USA.
*/ 

#ifndef IBSystem_INCLUDE
#define IBSystem_INCLUDE

#ifdef GNUSTEP_WITH_DLL 

#if BUILD_libInterfaceBuilder_DLL
# if defined(__MINGW32__)
  /* On Mingw, the compiler will export all symbols automatically, so
   * __declspec(dllexport) is not needed.
   */
#  define IB_EXTERN  extern
# else
#  define IB_EXTERN  __declspec(dllexport)
# endif
#else
#  define IB_EXTERN  extern __declspec(dllimport)
#endif

#else /* GNUSTEP_WITH[OUT]_DLL */

#  define IB_EXTERN extern

#endif

#endif /* IBSystem_INCLUDE */
