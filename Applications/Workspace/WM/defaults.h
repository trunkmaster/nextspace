/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef __WORKSPACE_WM_DEFAULTS__
#define __WORKSPACE_WM_DEFAULTS__

#include <CoreFoundation/CoreFoundation.h>

#include "screen.h"
#include "window.h"

/* typedef struct WDDomain { */
/*   const char *domain_name; */
/*   WMPropList *dictionary; */
/*   const char *path; */
/*   time_t timestamp; */
/* } WDDomain; */
typedef struct WDDomain {
  CFStringRef            name;
  CFMutableDictionaryRef dictionary;
  CFURLRef               path;
  CFAbsoluteTime         timestamp;
} WDDomain;

void wDefaultsCheckDomain(const char *domain);
void wDefaultsCheckDomains(void *arg);

WDDomain *wDefaultsInitDomain(const char *domain, Bool requireDictionary);

void wReadDefaults(WScreen *scr, CFMutableDictionaryRef new_dict);
void wDefaultUpdateIcons(WScreen *scr);
void wReadStaticDefaults(CFDictionaryRef dict);
void wSaveDefaults(WScreen *scr);

#endif /* WMDEFAULTS_H_ */
