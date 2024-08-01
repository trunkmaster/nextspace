/*  Window specific defaults
 *
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
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

#include "WM.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <strings.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

#include <wraster.h>

#include <core/util.h>
#include <core/log_utils.h>
#include <core/file_utils.h>
#include <core/string_utils.h>
#include "core/wuserdefaults.h"

#include "WM.h"
#include "window.h"
#include "window_attributes.h"
#include "appicon.h"
#include "screen.h"
#include "desktop.h"
#include "defaults.h"
#include "icon.h"

#include <Workspace+WM.h>

/* Icon for app without own icon. Bundled with NXAppKit. */
#define DEF_APP_ICON "NXUnknownApplication.tiff"

/* bit flags for the above window attributes */
#define WA_TITLEBAR            (1 << 0)
#define WA_RESIZABLE           (1 << 1)
#define WA_CLOSABLE            (1 << 2)
#define WA_MINIATURIZABLE      (1 << 3)
#define WA_BROKEN_CLOSE        (1 << 4)
#define WA_SHADEABLE           (1 << 5)
#define WA_FOCUSABLE           (1 << 6)
#define WA_OMNIPRESENT         (1 << 7)
#define WA_SKIP_WINDOW_LIST    (1 << 8)
#define WA_SKIP_SWITCHPANEL    (1 << 9)
#define WA_FLOATING            (1 << 10)
#define WA_IGNORE_KEYS         (1 << 11)
#define WA_IGNORE_MOUSE        (1 << 12)
#define WA_IGNORE_HIDE_OTHERS  (1 << 13)
#define WA_NOT_APPLICATION     (1 << 14)
#define WA_DONT_MOVE_OFF       (1 << 15)

#define APPLY_VAL(value, flag, attrib)   \
  if (value) {                           \
    attr->flag = getBool(attrib, value); \
    if (mask)                            \
      mask->flag = 1;                    \
  }

/* Local stuff */

/* type converters */
static int getBool(CFStringRef, CFTypeRef);
static const char *getString(CFStringRef, CFTypeRef);

/* keys */
static CFStringRef AIcon = CFSTR("Icon");
static CFStringRef ANoTitlebar = CFSTR("NoTitlebar");
static CFStringRef ANoResizebar = CFSTR("NoResizebar");
static CFStringRef ANoMiniaturizeButton = CFSTR("NoMiniaturizeButton");
static CFStringRef ANoMiniaturizable = CFSTR("NoMiniaturizable");
static CFStringRef ANoCloseButton = CFSTR("NoCloseButton");
static CFStringRef ANoBorder = CFSTR("NoBorder");
static CFStringRef ANoHideOthers = CFSTR("NoHideOthers");
static CFStringRef ANoMouseBindings = CFSTR("NoMouseBindings");
static CFStringRef ANoKeyBindings = CFSTR("NoKeyBindings");
static CFStringRef ANoAppIcon = CFSTR("NoAppIcon");
static CFStringRef AKeepOnTop = CFSTR("KeepOnTop");
static CFStringRef AKeepOnBottom = CFSTR("KeepOnBottom");
static CFStringRef AOmnipresent = CFSTR("Omnipresent");
static CFStringRef ASkipWindowList = CFSTR("SkipWindowList");
static CFStringRef ASkipSwitchPanel = CFSTR("SkipSwitchPanel");
static CFStringRef AKeepInsideScreen = CFSTR("KeepInsideScreen");
static CFStringRef AUnfocusable = CFSTR("Unfocusable");
static CFStringRef AAlwaysUserIcon = CFSTR("AlwaysUserIcon");
static CFStringRef AStartMiniaturized = CFSTR("StartMiniaturized");
static CFStringRef AStartHidden = CFSTR("StartHidden");
static CFStringRef AStartMaximized = CFSTR("StartMaximized");
static CFStringRef ADontSaveSession = CFSTR("DontSaveSession");
static CFStringRef AEmulateAppIcon = CFSTR("EmulateAppIcon");
static CFStringRef AFocusAcrossWorkspace = CFSTR("FocusAcrossWorkspace");
static CFStringRef AFullMaximize = CFSTR("FullMaximize");
static CFStringRef ASharedAppIcon = CFSTR("SharedAppIcon");
static CFStringRef AStartWorkspace = CFSTR("StartWorkspace");
static CFStringRef AnyWindow = CFSTR("*");
static CFStringRef No = CFSTR("No");

/* --------------------------- Local ----------------------- */

/* Returns the correct WMPropList, using instance+class or instance, or class, or default */
static CFTypeRef get_value(CFTypeRef dict_win, CFTypeRef dict_class, CFTypeRef dict_name,
                           CFTypeRef dict_any, CFStringRef option, CFTypeRef default_value,
                           Bool useGlobalDefault)
{
  CFTypeRef value;

  if (dict_win) {
    value = CFDictionaryGetValue(dict_win, option);
    if (value)
      return value;
  }

  if (dict_name) {
    value = CFDictionaryGetValue(dict_name, option);
    if (value)
      return value;
  }

  if (dict_class) {
    value = CFDictionaryGetValue(dict_class, option);
    if (value)
      return value;
  }

  if (!useGlobalDefault)
    return NULL;

  if (dict_any) {
    value = CFDictionaryGetValue(dict_any, option);
    if (value)
      return value;
  }

  return default_value;
}

static CFTypeRef get_value_from_instanceclass(const char *value)
{
  CFStringRef key;
  CFTypeRef val = NULL;

  if (!value)
    return NULL;

  key = CFStringCreateWithCString(kCFAllocatorDefault, value, kCFStringEncodingUTF8);

  if (w_global.domain.window_attrs->dictionary)
    val = key ? CFDictionaryGetValue(w_global.domain.window_attrs->dictionary, key) : NULL;

  if (key)
    CFRelease(key);

  return val;
}

static int getBool(CFStringRef key, CFTypeRef value)
{
  const char *val;

  if (CFGetTypeID(value) != CFStringGetTypeID()) {
    WMLogWarning(_("Wrong option format for key \"%s\". Should be %s."),
                 CFStringGetCStringPtr(key, kCFStringEncodingUTF8), "Boolean");
    return 0;
  }
  val = CFStringGetCStringPtr(value, kCFStringEncodingUTF8);

  if ((val[1] == '\0' &&
       (val[0] == 'y' || val[0] == 'Y' || val[0] == 'T' || val[0] == 't' || val[0] == '1')) ||
      (strcasecmp(val, "YES") == 0 || strcasecmp(val, "TRUE") == 0)) {
    return 1;
  } else if ((val[1] == '\0' && (val[0] == 'n' || val[0] == 'N' || val[0] == 'F' || val[0] == 'f' ||
                                 val[0] == '0')) ||
             (strcasecmp(val, "NO") == 0 || strcasecmp(val, "FALSE") == 0)) {
    return 0;
  } else {
    WMLogWarning(_("can't convert \"%s\" to boolean"), val);
    /* We return False if we can't convert to BOOLEAN.
     * This is because all options defaults to False.
     * -1 is not checked and thus is interpreted as True,
     * which is not good.*/
    return 0;
  }
}

/* WARNING: Do not free the value returned by this function!! */
static const char *getString(CFStringRef key, CFTypeRef value)
{
  if (CFGetTypeID(value) != CFStringGetTypeID()) {
    WMLogWarning(_("Wrong option format for key \"%s\". Should be %s."),
                 CFStringGetCStringPtr(key, kCFStringEncodingUTF8), "String");
    return NULL;
  }

  return CFStringGetCStringPtr(value, kCFStringEncodingUTF8);
}

/*
 *----------------------------------------------------------------------
 * wDefaultFillAttributes--
 * 	Retrieves attributes for the specified instance/class and
 * fills attr with it. Values that are actually defined are also
 * set in mask. If useGlobalDefault is True, the default for
 * all windows ("*") will be used for when no values are found
 * for that instance/class.
 *
 *----------------------------------------------------------------------
 */
void wDefaultFillAttributes(const char *instance, const char *class, WWindowAttributes *attr,
                            WWindowAttributes *mask, Bool useGlobalDefault)
{
  CFTypeRef value, dw, dc, dn, da;
  char *buffer;

  dw = dc = dn = da = NULL;

  if (class && instance) {
    buffer = wstrconcatdot(instance, class);
    dw = get_value_from_instanceclass(buffer);
    wfree(buffer);
  }

  dn = get_value_from_instanceclass(instance);
  dc = get_value_from_instanceclass(class);

  if ((w_global.domain.window_attrs->dictionary) && (useGlobalDefault))
    da = CFDictionaryGetValue(w_global.domain.window_attrs->dictionary, AnyWindow);

  /* get the data */
  value = get_value(dw, dc, dn, da, ANoTitlebar, No, useGlobalDefault);
  APPLY_VAL(value, no_titlebar, ANoTitlebar);

  value = get_value(dw, dc, dn, da, ANoResizebar, No, useGlobalDefault);
  APPLY_VAL(value, no_resizebar, ANoResizebar);

  value = get_value(dw, dc, dn, da, ANoMiniaturizeButton, No, useGlobalDefault);
  APPLY_VAL(value, no_miniaturize_button, ANoMiniaturizeButton);

  value = get_value(dw, dc, dn, da, ANoMiniaturizable, No, useGlobalDefault);
  APPLY_VAL(value, no_miniaturizable, ANoMiniaturizable);

  value = get_value(dw, dc, dn, da, ANoCloseButton, No, useGlobalDefault);
  APPLY_VAL(value, no_close_button, ANoCloseButton);

  value = get_value(dw, dc, dn, da, ANoBorder, No, useGlobalDefault);
  APPLY_VAL(value, no_border, ANoBorder);

  value = get_value(dw, dc, dn, da, ANoHideOthers, No, useGlobalDefault);
  APPLY_VAL(value, no_hide_others, ANoHideOthers);

  value = get_value(dw, dc, dn, da, ANoMouseBindings, No, useGlobalDefault);
  APPLY_VAL(value, no_bind_mouse, ANoMouseBindings);

  value = get_value(dw, dc, dn, da, ANoKeyBindings, No, useGlobalDefault);
  APPLY_VAL(value, no_bind_keys, ANoKeyBindings);

  value = get_value(dw, dc, dn, da, ANoAppIcon, No, useGlobalDefault);
  APPLY_VAL(value, no_appicon, ANoAppIcon);

  value = get_value(dw, dc, dn, da, ASharedAppIcon, No, useGlobalDefault);
  APPLY_VAL(value, shared_appicon, ASharedAppIcon);

  value = get_value(dw, dc, dn, da, AKeepOnTop, No, useGlobalDefault);
  APPLY_VAL(value, floating, AKeepOnTop);

  value = get_value(dw, dc, dn, da, AKeepOnBottom, No, useGlobalDefault);
  APPLY_VAL(value, sunken, AKeepOnBottom);

  value = get_value(dw, dc, dn, da, AOmnipresent, No, useGlobalDefault);
  APPLY_VAL(value, omnipresent, AOmnipresent);

  value = get_value(dw, dc, dn, da, ASkipWindowList, No, useGlobalDefault);
  APPLY_VAL(value, skip_window_list, ASkipWindowList);

  value = get_value(dw, dc, dn, da, ASkipSwitchPanel, No, useGlobalDefault);
  APPLY_VAL(value, skip_switchpanel, ASkipSwitchPanel);

  value = get_value(dw, dc, dn, da, AKeepInsideScreen, No, useGlobalDefault);
  APPLY_VAL(value, dont_move_off, AKeepInsideScreen);

  value = get_value(dw, dc, dn, da, AUnfocusable, No, useGlobalDefault);
  APPLY_VAL(value, no_focusable, AUnfocusable);

  value = get_value(dw, dc, dn, da, AAlwaysUserIcon, No, useGlobalDefault);
  APPLY_VAL(value, always_user_icon, AAlwaysUserIcon);

  value = get_value(dw, dc, dn, da, AStartMiniaturized, No, useGlobalDefault);
  APPLY_VAL(value, start_miniaturized, AStartMiniaturized);

  value = get_value(dw, dc, dn, da, AStartHidden, No, useGlobalDefault);
  APPLY_VAL(value, start_hidden, AStartHidden);

  value = get_value(dw, dc, dn, da, AStartMaximized, No, useGlobalDefault);
  APPLY_VAL(value, start_maximized, AStartMaximized);

  value = get_value(dw, dc, dn, da, ADontSaveSession, No, useGlobalDefault);
  APPLY_VAL(value, dont_save_session, ADontSaveSession);

  value = get_value(dw, dc, dn, da, AEmulateAppIcon, No, useGlobalDefault);
  APPLY_VAL(value, emulate_appicon, AEmulateAppIcon);

  value = get_value(dw, dc, dn, da, AFocusAcrossWorkspace, No, useGlobalDefault);
  APPLY_VAL(value, focus_across_wksp, AFocusAcrossWorkspace);

  value = get_value(dw, dc, dn, da, AFullMaximize, No, useGlobalDefault);
  APPLY_VAL(value, full_maximize, AFullMaximize);
}

static CFTypeRef get_generic_value(const char *instance, const char *class, CFStringRef option,
                                   Bool default_icon)
{
  CFTypeRef value, key, dict;

  value = NULL;

  /* Search the icon name using class and instance */
  if (class && instance) {
    key = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%s.%s"), instance, class);
    dict = CFDictionaryGetValue(w_global.domain.window_attrs->dictionary, key);
    CFRelease(key);

    if (dict) {
      value = CFDictionaryGetValue(dict, option);
    }
  }

  /* Search the icon name using instance */
  if (!value && instance) {
    key = CFStringCreateWithCString(kCFAllocatorDefault, instance, kCFStringEncodingUTF8);

    dict = CFDictionaryGetValue(w_global.domain.window_attrs->dictionary, key);
    CFRelease(key);

    if (dict) {
      value = CFDictionaryGetValue(dict, option);
    }
  }

  /* Search the icon name using class */
  if (!value && class) {
    key = CFStringCreateWithCString(kCFAllocatorDefault, class, kCFStringEncodingUTF8);

    dict = CFDictionaryGetValue(w_global.domain.window_attrs->dictionary, key);
    CFRelease(key);

    if (dict)
      value = CFDictionaryGetValue(dict, option);
  }

  /* Search the default icon name - See default_icon argument! */
  if (!value && default_icon) {
    /* AnyWindow is "*" - see wdefaults.c */
    dict = CFDictionaryGetValue(w_global.domain.window_attrs->dictionary, AnyWindow);

    if (dict)
      value = CFDictionaryGetValue(dict, option);
  }

  return value;
}

/* Get the file name of the image, using instance and class */
char *get_icon_filename(const char *winstance, const char *wclass, const char *command,
                        Bool default_icon)
{
  const char *file_name;
  char *file_path;

  /* Get the file name of the image, using instance and class */
  file_name = wDefaultGetIconFile(winstance, wclass, default_icon);

  /* Check if the file really exists in the disk */
  if (file_name)
    file_path = WMAbsolutePathForFile(wPreferences.image_paths, file_name);
  else
    file_path = NULL;

  /* If the specific icon filename is not found, and command is specified,
   * then include the .app icons and re-do the search. */
  if (!file_path && command) {
    wApplicationExtractDirPackIcon(command, winstance, wclass);
    file_name = wDefaultGetIconFile(winstance, wclass, False);

    if (file_name) {
      file_path = WMAbsolutePathForFile(wPreferences.image_paths, file_name);
      if (!file_path)
        WMLogWarning(_("icon \"%s\" doesn't exist, check your config files"), file_name);

      /* FIXME: Here, if file_path does not exist then the icon is still in the
       * "icon database" (w_global.domain.window_attr->dictionary), but the file
       * for the icon is no more on disk. Therefore, we should remove it from the
       * database. Is possible to do that using wDefaultChangeIcon() */
    }
  }

  /*
   * Don't wfree(file_name) because it is a direct pointer inside the icon
   * dictionary (w_global.domain.window_attr->dictionary) and not a result
   * allocated with wstrdup()
   */

  if (!file_path && default_icon)
    file_path = get_default_image_path();

  return file_path;
}

/* This function returns the image picture for the file_name file */
RImage *get_rimage_from_file(WScreen *scr, const char *file_name, int max_size)
{
  RImage *image = NULL;

  if (!file_name) {
    return NULL;
  }

  // image = RLoadImage(scr->rcontext, file_name, 0);
  image = WSLoadRasterImage(file_name);
  if (!image) {
    WMLogWarning(_("error loading image file \"%s\": %s"), file_name, RMessageForError(RErrorCode));
  }

  image = wIconValidateIconSize(image, max_size);

  return image;
}

/* This function returns the default icon's full path
 * If the path for an icon is not found, returns NULL */
char *get_default_image_path(void)
{
  char *path = NULL;
  const char *file = NULL;

  /* Get the default icon */
  file = wDefaultGetIconFile(NULL, NULL, True);
  if (file)
    path = WMAbsolutePathForFile(wPreferences.image_paths, file);
  else
    path = WMAbsolutePathForFile(wPreferences.image_paths, DEF_APP_ICON);

  return path;
}

/* This function creates the RImage using the default icon */
RImage *get_default_image(WScreen *scr)
{
  RImage *image = NULL;
  char *path = NULL;

  /* Get the filename full path */
  path = get_default_image_path();
  if (!path)
    return NULL;

  /* Get the default icon */
  image = get_rimage_from_file(scr, path, wPreferences.icon_size);
  if (!image)
    WMLogWarning(_("could not find default icon \"%s\""), path);

  /* Resize the icon to the wPreferences.icon_size size
   * usually this function will return early, because size is right */
  image = wIconValidateIconSize(image, wPreferences.icon_size);

  return image;
}

RImage *get_icon_image(WScreen *scr, const char *winstance, const char *wclass, int max_size)
{
  char *file_name = NULL;

  /* Get the file name of the image, using instance and class */
  file_name = get_icon_filename(winstance, wclass, NULL, True);

  return get_rimage_from_file(scr, file_name, max_size);
}

int wDefaultGetStartWorkspace(WScreen *scr, const char *instance, const char *class)
{
  CFTypeRef value;
  int w;
  const char *tmp;

  if (!w_global.domain.window_attrs->dictionary)
    return -1;

  value = get_generic_value(instance, class, AStartWorkspace, True);

  if (!value)
    return -1;

  tmp = getString(AStartWorkspace, value);

  if (!tmp || strlen(tmp) == 0)
    return -1;

  /* Get the workspace number for the workspace name */
  w = wGetDesktopNumber(scr, tmp);

  return w;
}

/* Get the name of the Icon File. If default_icon is True, then, default value included */
const char *wDefaultGetIconFile(const char *instance, const char *class, Bool default_icon)
{
  CFTypeRef value;
  const char *tmp;

  if (!w_global.domain.window_attrs || !w_global.domain.window_attrs->dictionary)
    return NULL;

  value = get_generic_value(instance, class, AIcon, default_icon);

  if (!value)
    return NULL;

  tmp = getString(AIcon, value);

  return tmp;
}

void wDefaultChangeIcon(const char *instance, const char *class, const char *file)
{
  WDDomain *db = w_global.domain.window_attrs;
  CFMutableDictionaryRef dict = db->dictionary;
  CFMutableDictionaryRef icon_entry = NULL;
  CFMutableDictionaryRef attrs = NULL;
  CFTypeRef icon_path, key, def_win, def_icon = NULL;
  unsigned same = 0;

  // WMWindowAttributes is empty
  if (!dict) {
    dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                     &kCFTypeDictionaryValueCallBacks);
    if (dict)
      db->dictionary = dict;
    else
      return;
  }

  // `key` definition
  if (instance && class) {
    char *buffer;

    buffer = wstrconcatdot(instance, class);
    key = CFStringCreateWithCString(kCFAllocatorDefault, buffer, kCFStringEncodingUTF8);
    wfree(buffer);
  } else if (instance) {
    key = CFStringCreateWithCString(kCFAllocatorDefault, instance, kCFStringEncodingUTF8);
  } else if (class) {
    key = CFStringCreateWithCString(kCFAllocatorDefault, class, kCFStringEncodingUTF8);
  } else {
    key = CFRetain(AnyWindow);
  }

  if (file) {
    icon_path = CFStringCreateWithCString(kCFAllocatorDefault, file, kCFStringEncodingUTF8);
    icon_entry = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                           &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(icon_entry, AIcon, icon_path);
    CFRelease(icon_path);

    // Determine if `file` is the same as for "*"
    def_win = CFDictionaryGetValue(dict, AnyWindow);
    if (def_win != NULL) {
      def_icon = CFDictionaryGetValue(def_win, AIcon);
      if (def_icon && !strcmp(CFStringGetCStringPtr(def_icon, kCFStringEncodingUTF8), file)) {
        same = 1;
      }
    }
  }

  // Get value from WMWindowAttributes
  {
    CFDictionaryRef def_attrs = CFDictionaryGetValue(dict, key);
    if (def_attrs) {
      attrs = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, def_attrs);
    }
  }

  if (attrs && CFGetTypeID(attrs) == CFDictionaryGetTypeID()) {
    if (icon_entry && !same) {
      WMUserDefaultsMerge(attrs, icon_entry);
      CFDictionarySetValue(dict, key, attrs);
    } else {
      CFDictionaryRemoveValue(attrs, AIcon);
    }
  } else if (icon_entry && !same) {
    CFDictionarySetValue(dict, key, icon_entry);
  }

  if (!wPreferences.flags.noupdates) {
    WMUserDefaultsWrite(db->dictionary, db->name);
  }

  if (attrs) {
    CFRelease(attrs);
  }
  if (icon_entry) {
    CFRelease(icon_entry);
  }
  CFRelease(key);
}

void wDefaultPurgeInfo(const char *instance, const char *class)
{
  CFStringRef key;
  CFDictionaryRef dict;

  key = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%s.%s"), instance, class);
  dict = CFDictionaryGetValue(w_global.domain.window_attrs->dictionary, key);

  if (dict) {
    CFDictionaryRemoveValue(w_global.domain.window_attrs->dictionary, key);
    WMUserDefaultsWrite(w_global.domain.window_attrs->dictionary, w_global.domain.window_attrs->name);
  }

  CFRelease(key);
}
