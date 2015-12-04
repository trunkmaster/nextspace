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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#ifndef WMDEFAULTS_H_
#define WMDEFAULTS_H_

typedef struct WDDomain {
    char *domain_name;
    WMPropList *dictionary;
    char *path;
    time_t timestamp;
} WDDomain;

#if 0
WMPropList* wDefaultsInit(int screen_number);
#endif


WDDomain* wDefaultsInitDomain(char *domain, Bool requireDictionary);

void wDefaultsMergeGlobalMenus(WDDomain *menuDomain);

void wDefaultsDestroyDomain(WDDomain *domain);

void wReadDefaults(WScreen *scr, WMPropList *new_dict);

void wDefaultUpdateIcons(WScreen *scr);

void wReadStaticDefaults(WMPropList *dict);

void wDefaultsCheckDomains(void *screen);

void wSaveDefaults(WScreen *scr);

char *wDefaultGetIconFile(WScreen *scr, char *instance, char *class,
                          Bool noDefault);

RImage *wDefaultGetImage(WScreen *scr, char *winstance, char *wclass);

void wDefaultFillAttributes(WScreen *scr, char *instance, char *class,
                            WWindowAttributes *attr, WWindowAttributes *mask,
                            Bool useGlobalDefault);

int wDefaultGetStartWorkspace(WScreen *scr, char *instance, char *class);

void wDefaultChangeIcon(WScreen *scr, char *instance, char* class, char *file);

#endif /* WMDEFAULTS_H_ */

