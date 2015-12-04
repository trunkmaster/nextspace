/*
 * wmmenugen - Window Maker PropList menu generator
 *
 * Desktop Entry Specification parser functions
 *
 * Copyright (c) 2010. Tamas Tevesz <ice@extreme.hu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

/*
 * http://standards.freedesktop.org/desktop-entry-spec/desktop-entry-spec-1.1.html
 * http://standards.freedesktop.org/menu-spec/menu-spec-1.1.html
 *
 * We will only deal with Type == "Application" entries in [Desktop Entry]
 * groups. Since there is no passing of file name arguments or anything of
 * the sort to applications from the menu, execname is determined as follows:
 * - If `TryExec' is present, use that;
 * - else use `Exec' with any switches stripped
 *
 * Only the (first, though there should not be more than one) `Main Category'
 * is used to place the entry in a submenu.
 *
 * Basic validation of the .desktop file is done.
 */

#include <sys/types.h>
#include <sys/stat.h>

#include <ctype.h>
#include <ftw.h>
#if DEBUG
#include <errno.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "wmmenugen.h"

/* LocaleString match levels */
enum {
	MATCH_DEFAULT,
	MATCH_LANG,
	MATCH_LANG_MODIFIER,
	MATCH_LANG_COUNTRY,
	MATCH_LANG_COUNTRY_MODIFIER
};

typedef struct {
	char	*Name;		/* Name */				/* localestring */
	int	 MatchLevel;	/* LocaleString match type */		/* int */
	char	*TryExec;	/* TryExec */				/* string */
	char	*Exec;		/* Exec */				/* string */
	char	*Path;		/* Path */				/* string */
	int	 Flags;		/* Flags */
	char	*Category;	/* Categories (first item only) */	/* string */
} XDGMenuEntry;

static void  getKey(char **target, const char *line);
static void  getStringValue(char **target, const char *line);
static void  getLocalizedStringValue(char **target, const char *line, int *match_level);
static int   getBooleanValue(const char *line);
static void  getMenuHierarchyFor(char **xdgmenuspec);
static int   compare_matchlevel(int *current_level, const char *found_locale);
static Bool  xdg_to_wm(XDGMenuEntry **xdg, WMMenuEntry **wmentry);
static void init_xdg_storage(XDGMenuEntry **xdg);
static void init_wm_storage(WMMenuEntry **wm);


void parse_xdg(const char *file, cb_add_menu_entry *addWMMenuEntryCallback)
{
	FILE *fp;
	char buf[1024];
	char *p, *tmp, *key;
	WMMenuEntry *wm;
	XDGMenuEntry *xdg;
	int InGroup;

	fp = fopen(file, "r");
	if (!fp) {
#if DEBUG
		fprintf(stderr, "Error opening file %s: %s\n", file, strerror(errno));
#endif
		return;
	}

	xdg = (XDGMenuEntry *)wmalloc(sizeof(XDGMenuEntry));
	wm = (WMMenuEntry *)wmalloc(sizeof(WMMenuEntry));
	InGroup = 0;
	memset(buf, 0, sizeof(buf));

	while (fgets(buf, sizeof(buf), fp)) {

		p = buf;

		/* skip whitespaces */
		while (isspace(*p))
			p++;
		/* skip comments, empty lines */
		if (*p == '\r' || *p == '\n' || *p == '#') {
			memset(buf, 0, sizeof(buf));
			continue;
		}
		/* trim crlf */
		buf[strcspn(buf, "\r\n")] = '\0';
		if (strlen(buf) == 0)
			continue;

		if (strcmp(p, "[Desktop Entry]") == 0) {
			/* if currently processing a group, we've just hit the
			 * end of its definition, try processing it
			 */
			if (InGroup && xdg_to_wm(&xdg, &wm)) {
				(*addWMMenuEntryCallback)(wm);
			}
			init_xdg_storage(&xdg);
			init_wm_storage(&wm);
			InGroup = 1;
			/* start processing group */
			memset(buf, 0, sizeof(buf));
			continue;
		}

		if (!InGroup) {
			memset(buf, 0, sizeof(buf));
			continue;
		}

		getKey(&key, p);
		if (key == NULL) { /* not `key' = `value' */
			memset(buf, 0, sizeof(buf));
			continue;
		}

		if (strcmp(key, "Type") == 0) {
			getStringValue(&tmp, p);
			if (strcmp(tmp, "Application") != 0)
				InGroup = 0;	/* if not application, skip current group */
			wfree(tmp);
			tmp = NULL;
		} else if (strcmp(key, "Name") == 0) {
			getLocalizedStringValue(&xdg->Name, p, &xdg->MatchLevel);
		} else if (strcmp(key, "NoDisplay") == 0) {
			if (getBooleanValue(p))	/* if nodisplay, skip current group */
				InGroup = 0;
		} else if (strcmp(key, "Hidden") == 0) {
			if (getBooleanValue(p))
				InGroup = 0;	/* if hidden, skip current group */
		} else if (strcmp(key, "TryExec") == 0) {
			getStringValue(&xdg->TryExec, p);
		} else if (strcmp(key, "Exec") == 0) {
			getStringValue(&xdg->Exec, p);
		} else if (strcmp(key, "Path") == 0) {
			getStringValue(&xdg->Path, p);
		} else if (strcmp(key, "Terminal") == 0) {
			if (getBooleanValue(p))
				xdg->Flags |= F_TERMINAL;
		} else if (strcmp(key, "Categories") == 0) {
			getStringValue(&xdg->Category, p);
			getMenuHierarchyFor(&xdg->Category);
		}

		wfree(key);
		key = NULL;
	}

	fclose(fp);

	/* at the end of the file, might as well try to menuize what we have
	 * unless there was no group at all or it was marked as hidden
	 */
	if (InGroup && xdg_to_wm(&xdg, &wm))
		(*addWMMenuEntryCallback)(wm);

}


/* coerce an xdg entry type into a wm entry type
 */
static Bool xdg_to_wm(XDGMenuEntry **xdg, WMMenuEntry **wm)
{
	char *p;

	/* Exec or TryExec is mandatory */
	if (!((*xdg)->Exec || (*xdg)->TryExec))
		return False;

	/* if there's no Name, use the first word of Exec or TryExec
	 */
	if ((*xdg)->Name) {
		(*wm)->Name = (*xdg)->Name;
	} else  {
		if ((*xdg)->Exec)
			(*wm)->Name = wstrdup((*xdg)->Exec);
		else /* (*xdg)->TryExec */
			(*wm)->Name = wstrdup((*xdg)->TryExec);

		p = strchr((*wm)->Name, ' ');
		if (p)
			*p = '\0';
	}

	if ((*xdg)->Exec)
		(*wm)->CmdLine = (*xdg)->Exec;
	else					/* (*xdg)->TryExec */
		(*wm)->CmdLine = (*xdg)->TryExec;

	(*wm)->SubMenu = (*xdg)->Category;
	(*wm)->Flags = (*xdg)->Flags;

	return True;
}

/* (re-)initialize a XDGMenuEntry storage
 */
static void init_xdg_storage(XDGMenuEntry **xdg)
{

	if ((*xdg)->Name)
		wfree((*xdg)->Name);
	if ((*xdg)->TryExec)
		wfree((*xdg)->TryExec);
	if ((*xdg)->Exec)
		wfree((*xdg)->Exec);
	if ((*xdg)->Category)
		wfree((*xdg)->Category);
	if ((*xdg)->Path)
		wfree((*xdg)->Path);

	(*xdg)->Name = NULL;
	(*xdg)->TryExec = NULL;
	(*xdg)->Exec = NULL;
	(*xdg)->Category = NULL;
	(*xdg)->Path = NULL;
	(*xdg)->Flags = 0;
	(*xdg)->MatchLevel = -1;
}

/* (re-)initialize a WMMenuEntry storage
 */
static void init_wm_storage(WMMenuEntry **wm)
{
	(*wm)->Name = NULL;
	(*wm)->CmdLine = NULL;
	(*wm)->Flags = 0;
}

/* get a key from line. allocates target, which must be wfreed later */
static void getKey(char **target, const char *line)
{
	const char *p;
	int kstart, kend;

	p = line;

	if (strchr(p, '=') == NULL) {		/* not `key' = `value' */
		*target = NULL;
		return;
	}

	kstart = 0;

	/* skip whitespace */
	while (isspace(*(p + kstart)))
		kstart++;

	/* skip up until first whitespace or '[' (localestring) or '=' */
	kend = kstart + 1;
	while (*(p + kend) && !isspace(*(p + kend)) && *(p + kend) != '=' && *(p + kend) != '[')
		kend++;

	*target = wstrndup(p + kstart, kend - kstart);
}

/* get a string value from line. allocates target, which must be wfreed later. */
static void getStringValue(char **target, const char *line)
{
	const char *p;
	int kstart;

	p = line;
	kstart = 0;

	/* skip until after '=' */
	while (*(p + kstart) && *(p + kstart) != '=')
		kstart++;
	kstart++;

	/* skip whitespace */
	while (*(p + kstart) && isspace(*(p + kstart)))
		kstart++;

	*target = wstrdup(p + kstart);
}

/* get a localized string value from line. allocates target, which must be wfreed later.
 * matching is dependent on the current value of target as well as on the
 * level the current value is matched on. guts matching algorithm is in
 * compare_matchlevel().
 */
static void getLocalizedStringValue(char **target, const char *line, int *match_level)
{
	const char *p;
	char *locale;
	int kstart;
	int sqbstart, sqbend;

	p = line;
	kstart = 0;
	sqbstart = 0;
	sqbend = 0;
	locale = NULL;

	/* skip until after '=', mark if '[' and ']' is found */
	while (*(p + kstart) && *(p + kstart) != '=') {
		switch (*(p + kstart)) {
			case '[': sqbstart = kstart + 1;break;
			case ']': sqbend = kstart;	break;
			default	:			break;
		}
		kstart++;
	}
	kstart++;

	/* skip whitespace */
	while (isspace(*(p + kstart)))
		kstart++;

	if (sqbstart > 0 && sqbend > sqbstart)
		locale = wstrndup(p + sqbstart, sqbend - sqbstart);

	/* if there is no value yet and this is the default key, return */
	if (!*target && !locale) {
		*match_level = MATCH_DEFAULT;
		*target = wstrdup(p + kstart);
		return;
	}

	if (compare_matchlevel(match_level, locale)) {
		wfree(locale);
		*target = wstrdup(p + kstart);
		return;
	}

	return;
}

/* get a boolean value from line */
static Bool getBooleanValue(const char *line)
{
	char *p;
	int ret;

	getStringValue(&p, line);
	ret = strcmp(p, "true") == 0 ? True : False;
	wfree(p);

	return ret;
}

/* perform locale matching by implementing the algorithm specified in
 * xdg desktop entry specification, section "localized values for keys".
 */
static Bool compare_matchlevel(int *current_level, const char *found_locale)
{
	/* current key locale */
	char *key_lang, *key_ctry, *key_enc, *key_mod;

	parse_locale(found_locale, &key_lang, &key_ctry, &key_enc, &key_mod);

	if (env_lang && key_lang &&		/* Shortcut: if key and env languages don't match, */
	    strcmp(env_lang, key_lang) != 0)	/* don't even bother. This takes care of the great */
		return False;			/* majority of the cases without having to go through */
						/* the more theoretical parts of the spec'd algo. */

	if (!env_mod && key_mod)	/* If LC_MESSAGES does not have a MODIFIER field, */
		return False;		/* then no key with a modifier will be matched. */

	if (!env_ctry && key_ctry)	/* Similarly, if LC_MESSAGES does not have a COUNTRY field, */
		return False;		/* then no key with a country specified will be matched. */

	/* LC_MESSAGES value: lang_COUNTRY@MODIFIER */
	if (env_lang && env_ctry && env_mod) {		/* lang_COUNTRY@MODIFIER */
		if (key_lang && key_ctry && key_mod &&
		    strcmp(env_lang, key_lang) == 0 &&
		    strcmp(env_ctry, key_ctry) == 0 &&
		    strcmp(env_mod,  key_mod) == 0) {
			*current_level = MATCH_LANG_COUNTRY_MODIFIER;
			return True;
		} else if (key_lang && key_ctry &&	/* lang_COUNTRY */
		    strcmp(env_lang, key_lang) == 0 &&
		    strcmp(env_ctry, key_ctry) == 0 &&
		    *current_level < MATCH_LANG_COUNTRY) {
			*current_level = MATCH_LANG_COUNTRY;
			return True;
		} else if (key_lang && key_mod &&	/* lang@MODIFIER */
		    strcmp(env_lang, key_lang) == 0 &&
		    strcmp(env_mod,  key_mod) == 0 &&
		    *current_level < MATCH_LANG_MODIFIER) {
			*current_level = MATCH_LANG_MODIFIER;
			return True;
		} else if (key_lang &&			/* lang */
		    strcmp(env_lang, key_lang) == 0 &&
		    *current_level < MATCH_LANG) {
			*current_level = MATCH_LANG;
			return True;
		} else {
			return False;
		}
	}

	/* LC_MESSAGES value: lang_COUNTRY */
	if (env_lang && env_ctry) {			/* lang_COUNTRY */
		if (key_lang && key_ctry &&
		    strcmp(env_lang, key_lang) == 0 &&
		    strcmp(env_ctry, key_ctry) == 0 &&
		    *current_level < MATCH_LANG_COUNTRY) {
			*current_level = MATCH_LANG_COUNTRY;
			return True;
		} else if (key_lang &&			/* lang */
		    strcmp(env_lang, key_lang) == 0 &&
		    *current_level < MATCH_LANG) {
			*current_level = MATCH_LANG;
			return True;
		} else {
			return False;
		}
	}

	/* LC_MESSAGES value: lang@MODIFIER */
	if (env_lang && env_mod) {			/* lang@MODIFIER */
		if (key_lang && key_mod &&
		    strcmp(env_lang, key_lang) == 0 &&
		    strcmp(env_mod,  key_mod) == 0 &&
		    *current_level < MATCH_LANG_MODIFIER) {
			*current_level = MATCH_LANG_MODIFIER;
			return True;
		} else if (key_lang &&			/* lang */
		    strcmp(env_lang, key_lang) == 0 &&
		    *current_level < MATCH_LANG) {
			*current_level = MATCH_LANG;
			return True;
		} else {
			return False;
		}
	}

	/* LC_MESSAGES value: lang */
	if (env_lang) {					/* lang */
		if (key_lang &&
		    strcmp(env_lang, key_lang) == 0 &&
		    *current_level < MATCH_LANG) {
			*current_level = MATCH_LANG;
			return True;
		} else {
			return False;
		}
	}

	/* MATCH_DEFAULT is handled in getLocalizedStringValue */

	return False;
}

/* get the (first) xdg main category from a list of categories
 */
static void  getMenuHierarchyFor(char **xdgmenuspec)
{
	char *category, *p;
	char buf[1024];

	if (!*xdgmenuspec || !**xdgmenuspec)
		return;

	category = wstrdup(*xdgmenuspec);
	wfree(*xdgmenuspec);
	memset(buf, 0, sizeof(buf));

	p = strtok(category, ";");
	while (p) {		/* get a known category */
		if (strcmp(p, "AudioVideo") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Audio & Video"));
			break;
		} else if (strcmp(p, "Audio") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Audio"));
			break;
		} else if (strcmp(p, "Video") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Video"));
			break;
		} else if (strcmp(p, "Development") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Development"));
			break;
		} else if (strcmp(p, "Education") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Education"));
			break;
		} else if (strcmp(p, "Game") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Game"));
			break;
		} else if (strcmp(p, "Graphics") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Graphics"));
			break;
		} else if (strcmp(p, "Network") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Network"));
			break;
		} else if (strcmp(p, "Office") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Office"));
			break;
		} else if (strcmp(p, "Settings") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Settings"));
			break;
		} else if (strcmp(p, "System") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("System"));
			break;
		} else if (strcmp(p, "Utility") == 0) {
			snprintf(buf, sizeof(buf), "%s", _("Utility"));
			break;
		}
		p = strtok(NULL, ";");
	}


	if (!*buf)		/* come up with something if nothing found */
		snprintf(buf, sizeof(buf), "%s", _("Applications"));

	*xdgmenuspec = wstrdup(buf);
}
