/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2001 Dan Pascu
 *  Copyright (c) 2014 Window Maker Team
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#ifndef __WORKSPACE_WM_LOG__
#define __WORKSPACE_WM_LOG__

#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFLogUtilities.h>

#include "config.h"

#ifdef HAVE_SYSLOG_H
#include <syslog.h>
void WMSyslogClose(void);
#endif

void WMLog(const char *func, const char *file, int line, int type, CFStringRef fmt, ...) __attribute__((format(CFString,5,6)));

#define WMLogInfo(fmt, args...) WMLog( __func__, __FILE__, __LINE__, kCFLogLevelInfo, CFSTR(fmt), ## args)
#define WMLogWarning(fmt, args...) WMLog( __func__, __FILE__, __LINE__, kCFLogLevelWarning, CFSTR(fmt), ## args)
#define WMLogError(fmt, args...) WMLog( __func__, __FILE__, __LINE__, kCFLogLevelError, CFSTR(fmt), ## args)
#define WMLogCritical(fmt, args...) WMLog( __func__, __FILE__, __LINE__, kCFLogLevelCritical, CFSTR(fmt), ## args)

#endif
