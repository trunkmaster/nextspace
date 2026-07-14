/** DLL entry routine
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

   Original Author:  Scott Christley <scottc@net-community.com>
   Created: 1996

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

#import "common.h"

#ifdef _MSC_VER
#define WINBOOL WinBOOL
#endif

/* Only if using Microsoft's tools and libraries */
#ifdef __MS_WIN32__
WINBOOL WINAPI _CRT_INIT(HINSTANCE hinstDLL, DWORD fdwReason,
			  LPVOID lpReserved);
#endif /* __MS_WIN32__ */

//
// DLL entry function for GNUstep Base Library
// This function gets called everytime a process/thread attaches to DLL
//
WINBOOL WINAPI
DllMain(HANDLE hInst, ULONG ul_reason_for_call,	LPVOID lpReserved)
{
  switch(ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    case DLL_PROCESS_DETACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
      {
#ifdef __MS_WIN32__
        // CRT_INIT must be called on DLL/thread attach and detach, although
        // first on attach and last on detach. Since we don't do anything else
        // in this method we can just always call it.
        if (!_CRT_INIT(hInst, ul_reason_for_call, lpReserved)) {
          return FALSE;
        }
#endif /* __MS_WIN32__ */
      }
      break;
    }

  return TRUE;
}
