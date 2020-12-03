/* WUtil / userdefaults.h
 *
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef WUTIL_USERDEFAULTS_H
#define WUTIL_USERDEFAULTS_H

#include <WMcore/proplist.h>

typedef struct W_UserDefaults WMUserDefaults;

/*
 * This file is not part of WUtil public API
 *
 * It defines internal things for the user configuration handling functions
 */


/* Save user configuration, to be used when application exits only */
void w_save_defaults_changes(void);

/* don't free the returned string */
const char* wusergnusteppath(void);

/* Free the returned string when you no longer need it */
char* wdefaultspathfordomain(const char *domain);

WMUserDefaults* WMGetStandardUserDefaults(void);

WMUserDefaults* WMGetDefaultsFromPath(const char *path);

void WMSynchronizeUserDefaults(WMUserDefaults *database);

void WMSaveUserDefaults(WMUserDefaults *database);

void WMEnableUDPeriodicSynchronization(WMUserDefaults *database, Bool enable);

/* Returns a WMPropList array with all the keys in the user defaults database.
 * Free the array with WMReleasePropList() when no longer needed.
 * Keys in array are just retained references to the original keys */
WMPropList* WMGetUDKeys(WMUserDefaults *database);

WMPropList* WMGetUDObjectForKey(WMUserDefaults *database, const char *defaultName);

void WMSetUDObjectForKey(WMUserDefaults *database, WMPropList *object,
                         const char *defaultName);

void WMRemoveUDObjectForKey(WMUserDefaults *database, const char *defaultName);

/* Returns a reference. Do not free it! */
char* WMGetUDStringForKey(WMUserDefaults *database, const char *defaultName);

int WMGetUDIntegerForKey(WMUserDefaults *database, const char *defaultName);

float WMGetUDFloatForKey(WMUserDefaults *database, const char *defaultName);

Bool WMGetUDBoolForKey(WMUserDefaults *database, const char *defaultName);

void WMSetUDStringForKey(WMUserDefaults *database, const char *value,
                         const char *defaultName);

void WMSetUDIntegerForKey(WMUserDefaults *database, int value,
                          const char *defaultName);

void WMSetUDFloatForKey(WMUserDefaults *database, float value,
                        const char *defaultName);

void WMSetUDBoolForKey(WMUserDefaults *database, Bool value,
                       const char *defaultName);

WMPropList* WMGetUDSearchList(WMUserDefaults *database);

void WMSetUDSearchList(WMUserDefaults *database, WMPropList *list);

extern char *WMUserDefaultsDidChangeNotification;

#endif /* WUTIL_USERDEFAULTS_H */
